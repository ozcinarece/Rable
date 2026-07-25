# RAPOR — Görsel Yerleştirme Turu (branch: `gorsel-tur`)

Tarih: 2026-07-25 · Kapsam: **yalnız görsel bağlama**. Onarım mekaniği,
etkileşim ve yeni sistem YOK — bu raporun her satırı bu sınırın içinde.

---

## 1. Gelen 9 model ve nereye bağlandı

| Model | Dosya | Oyundaki yeri | Root Scale (hedef) |
|---|---|---|---|
| `planting_mound` | `assets/models/crops/` | Boş sürülü tarla göstergesi + kamptaki terk edilmiş tarla | **0.92 m taban** (yükseklik değil) |
| `grass_tuft` | `assets/models/env/` | Açık çim serpintisi | 0.33 m |
| `pebble_cluster` | `assets/models/env/` | Kaya/su kenarı serpintisi | 0.18 m |
| `twig_debris` | `assets/models/env/` | Ağaç dibi serpintisi | 0.40 m |
| `path_stone` | `assets/models/env/` | Aşınmış yol taşı | 0.45 m |
| `path_stone_mossy` | `assets/models/env/` | Yol taşı yosunlu varyantı (%40) | 0.45 m |
| `ruined_hut` | `assets/models/structures/` | Spawn kampı, kuzeybatı | 2.80 m |
| `repaired_hut` | `assets/models/structures/` | **Yalnız debug**: yıkık kopyanın yanında karşılaştırma | 2.80 m |
| `ruined_well` | `assets/models/structures/` | Spawn kampı, tarlanın kuzeyinde | 1.20 m |

**Ölçek yöntemi:** her modelde ölçek GLB'nin **kök düğümüne** verildi; iç
düğümlere (Armature vb.) dokunulmadı — karakterde rig'i bozan hata oydu.
Ölçek değerleri `scripts/env_models.gd` içindeki `SCALE` tablosunda tek
yerde duruyor.

*Tek istisna, gerekçesiyle:* `planting_mound` 0.92 m tabanda ~45 cm boy
veriyordu; sürülmüş bir sırt için bu çok yüksek. Kök düğümde Y **%55'e
ezildi** (`MOUND_FLATTEN`). Yasak olan, skinned modelin **iç** düğümlerini
ölçeklemekti; bu prop skinned değil, kökte ezme güvenli.

---

## 2. Doku/renk: üç ayrı sorun, üç ayrı çözüm

Meshy modelleri sahneye ilk konduğunda **beyaz ya da "ışık pişmiş" açık**
çıktı. Üç farklı kök neden vardı, hepsi ayrı ayrı görüldü ve düzeltildi:

1. **Materyal mesh'te değil, MeshInstance3D'de.** Godot'nun GLTF import'u
   materyali çoğu zaman `surface_override_material`'a koyuyor. MultiMesh
   yalnız MESH'i kullanır → model **bembeyaz** çizilir. Çözüm: serpinti
   mesh'i hazırlanırken `get_active_material(i)` mesh'e taşınıyor
   (`_env_mesh`).
2. **Albedo zaten neredeyse beyaz.** Ton çarpanı tablosu (`EnvModels.TINT`)
   eklendi. İlk değerler (0.80) yetmedi; taşlarda 0.5–0.56'ya sertleştirildi.
   Höyük ayrı yoldan kurulduğu için ayrı sabiti var (`MOUND_TINT`).
3. **Emission açık.** `_tame_meshy_materials` ışımayı kapatıp metallic'i
   0, roughness'ı ≥0.75 yapıyor ve albedo'yu ton çarpanıyla çarpıyor.
   Materyali **kopyalayıp** override olarak yazıyor → paylaşılan kaynakta
   ton birikmesi (her instantiate'te bir kez daha karartma) olmuyor.

**Düz renk fallback** (görevdeki palet: yaprak adaçayı / taş sıcak gri /
ahşap kahve) `EnvModels.FALLBACK_*` olarak duruyor ve GLB yüklenemezse
devreye giriyor. **Kullanılmadı** — dokuz modelin dokusu da geldi. Tek
prosedürel parça dekoratif kabak (aşağıda).

---

## 3. Oyun içi yerleştirme

- **Tarla göstergesi:** ekilmemiş sürülü hücrede `crops/planting_mound`
  durur, **ekilince kaybolur**, hasattan sonra geri gelir. Ekili hücrede
  yerini sırayla iki yatak model (`test/planting_mound`,
  `planting_mound2`) alır.
- **Çevre serpintisi:** tür başına **tek MultiMesh** (3 ek çizim çağrısı).
  Bağlam kuralı basit: açık çimde ot tutamı, kaya/su kenarında çakıl,
  ağaç dibinde dal. Konum/dönme/ölçek deterministik hash → dekor yeniden
  kurulunca otlar yer değiştirmez. Yoğunluk kalite kademesine bağlı
  (düşük telefonda %35'e iner).
- **Yol:** zemine soluk toprak lekesi (`_cell_props` okur) + üzerine taş
  serpintisi; %30 taş eksik (aşınmışlık), %40 yosunlu varyant.

---

## 4. Spawn kampı (Görev Eki)

Mockup'taki "Duvarlı Kamp + Kulübe" düzeninin **yıpranmış** hali. İskelet
mockup'la aynı; **duvar/hendek/huni YOK** — onlar oyuncunun ileride kendi
inşa hedefi.

Ocak merkezde (0,0) ve **sönük**. Yıkık kulübe KB (−5,−4), 3×3 ayak izi
katı, güney-orta hücre kapı. Terk edilmiş 2×2 tarla D (+5,−1): dört sırt,
üçünün üstünde solmuş bitki, batı kenarında 1 hücrelik **kuru** kanal
(derinlik 1, su yok). Kuyu (+5,−3). Üretim köşesi GB: devrik araştırma
masası (−5,+3) + devrik boş sandık (−4,+4) — **tezgâh yok**, ilk tezgâhı
oyuncu kuracak. Ocaktan dört yöne aşınmış yol; güney yolu kampı aşıp
yolun ortasında biter. Dört sönük meşale direği yol üstünde. Tarla
kenarında bir dekoratif kabak.

**Kampın tamamı DEKOR.** Hiçbir parça `_set_placed`'den geçmez,
`_structures`'a yazılmaz, kayda girmez, etkileşim vermez. Tek fiziksel
etki: kulübe ve kuyu hücreleri `_solid_cells`'e girer — yoksa oyuncu
duvarın içinden geçerdi (arazi çarpışması, mekanik değil).

Doğuş kulübenin önünde. Kamp yarıçapındaki (7 hücre) ağaç/kayanın ~%86'sı
temizlenir, serpinti kamp içinde 2× yoğunlaşır (terk edilmişlik).

**Kayıt tuzağı:** kamp planlaması `_base_objects` anlık görüntüsünden
**önce** çalışmak zorunda. Sonra çalışsaydı kayıt "kamptaki ağaçlar
silinmiş" diye delta yazar, her yüklemede ağaçlar kulübenin içinde geri
belirirdi.

---

## 5. Doğrulama

**KAMPTEST** (`docs/screens/kamptest.txt`, her CI koşusunda):

```
KAMPTEST: merkez=(64, 64) dogus_on=true dogus_bos=true kulube_kati=true
kapi_acik=true yol_yon=4/4 ocak_yanmiyor=true isik_yok=true
veri_temiz=true tarla=4 kanal=true dolu=%1
```

`ocak_yanmiyor` / `isik_yok` / `veri_temiz` üçlüsü kasıtlı: kampın
mekaniğe **sızmadığını** her koşuda kanıtlıyor.

**Ekran görüntüleri** (`docs/screens/`): `3d_kamp.png` (mockup açısıyla
geniş kamp), `3d_kamp_gece.png` (aynı açı, gece — meşaleler yanmıyor),
`3d_kamp_tarla.png` (tarla + höyük yakın plan), `3d_vitrin_env.png` /
`3d_vitrin_env_gece.png` (dokuz model gerçek ölçeğiyle, gündüz + gece).

---

## 6. Performans

**PERFTEST** aynı karede iki ölçüm alır: bu dalın eklediği her şey
(serpinti + yol taşları + kamp dekoru) **kapalı** ve **açık**. Ayrı bir
main koşusuna gerek kalmıyor — ölçüm aynı donanımda, aynı karede.

```
PERFTEST: kamp kamerasi | ONCE draw=154 | SONRA draw=212
          serpinti_dugum=3 yol_dugum=2 kamp_dugum=18
```

**+58 çizim çağrısı**, bunun 5'i serpinti/yol MultiMesh'i (harita
genelinde sabit), kalanı kampın 18 GLB propu (yalnız spawn bölgesinde).

**FPS rakamı verilmedi, çünkü dürüst değil:** CI sanal ekranda yazılım
rasterleştirme ile koşuyor, FPS ölçümü 1.0'a sabitleniyor (önce de sonra
da). Gerçek FPS ancak cihazda anlamlı — Ayarlar'daki FPS overlay'i
telefonda kamp içinde/dışında karşılaştırılmalı. Çizim çağrısı ise
donanımdan bağımsız, o yüzden ölçüt olarak o kullanıldı.

Aynı sebep bir tuzak da doğurdu: sonda ilk halinde 45+45 kare örnekliyordu;
CI'da her kare ~1 saniye sürdüğü için tek başına ~90 sn yiyip vitrin
karelerini bütçe dışına itti. Çizim çağrısı kare kare sabit olduğundan
örnek sayısı 8'e indirildi ve sonda vitrinden **sonraya** alındı — bütçe
kesilirse önce ölçüm düşsün, kareler değil.

---

## 7. Açık kalan / karar bekleyen

- **Yol taşları beğenilmedi** (kullanıcı bildirdi, model değişecek). Ton
  şu an sıcak griye sert çekilmiş durumda; yeni model gelince
  `EnvModels.TINT` içindeki iki satır yeniden ayarlanmalı.
- **Dekoratif kabak prosedürel:** kabak GLB'si yok, yassı küre + sap ile
  çizildi (paletle uyumlu sıcak turuncu). Model gelirse tek satırda
  değişir.
- **Solmuş bitki** genç ekin modelinin kurutulmuş tonu; ayrı "solmuş"
  modeli gelirse yerine geçebilir.
- **CI bütçesi 300 → 480 sn** çıkarıldı: kamp + vitrin kareleri eklenince
  oyun tam 300 sn'de kesiliyordu (kamp gece karesi ve vitrin kareleri hiç
  üretilemedi).
