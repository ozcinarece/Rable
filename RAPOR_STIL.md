# RAPOR_STIL — Stil Vitrin Sahnesi + pine_tree bağlama

Branch: `stil-vitrin` · Bölüm 17 · `main`'in güncelinden (pine_tree.glb dahil).

Bu tur: (1) `assets/models/test/` altındaki tüm GLB'leri oyunun gerçek
ışığında yan yana dizen **vitrin sahnesi**, (2) `pine_tree.glb`'yi ağaç
sistemine bağlama **altyapısı** + ölçüm, (3) gelecek GLB kancalarının
doğrulanması.

---

## ⚠️ KRİTİK BULGU — pine_tree.glb şu haliyle oyuna uygun DEĞİL

`assets/models/test/pine_tree.glb` ölçümü (GLB doğrudan ayrıştırıldı):

| Ölçü | Değer | Yorum |
|---|---|---|
| Dosya boyutu | **9.0 MB** | Tek ağaç için çok büyük |
| Üçgen | **524.480** | Tek ağaç yarım milyon üçgen |
| Vertex | 262.216 | — |
| Materyal | **0 (YOK)** | Dokusuz/materyalsiz → oyunda beyaz/ışıksız görünür |
| Doku | 0 | — |
| Ham AABB | 1.06 × **1.90** × 1.12 birim | Yükseklik 1.90 |

**Neden sorun:** Orman yüzlerce ağaç çizer. MultiMesh mesh'i paylaştığı için
**çizim çağrısı sayısı artmaz** (aşağıda) ama GPU her kare
`524k × ağaç_sayısı` üçgen işler. ~200 ağaçta bu **~105 milyon üçgen/kare** —
mobilde (ve hatta web build'de) oynanamaz. Ayrıca materyal olmadığı için
görsel de bozuk (beyaz kütle) olur. Yani "sadece görsel değişir" bile
sağlanamaz; görsel **kötüleşir**.

**Karar (senin "sorun varsa şimdilik uygulama" kuralın):** Bağlama
altyapısını kurdum ama **varsayılanı placeholder çam paketinde bıraktım.**
Model hazır olduğunda tek satırla açılır (aşağıda). Bu, oyunu ve performans
turunu korur.

**Hedef (bir sonraki Meshy/retopo üretimi için):**
- Üçgen: **≤ 2.000–4.000** (decimate/retopo). Kenney/Quaternius çam ~300–800
  üçgen — referans o bant.
- **Materyal + doku bake** (albedo en azından). Şu an hiç yok.
- Yükseklik ~1.9 birim gelmiş; ağaç sistemi zaten `TREE_HEIGHT=3.1`'e
  normalize ediyor, yani ölçek sorun değil — **sadece poligon + doku.**

---

## 1. Vitrin sahnesi — `scenes/style_showcase.tscn`

`scripts/style_showcase.gd` (yeni) tek başına çalışan bir `Node3D` sahnesi
kurar. **Ana oyuna dokunmaz** (World3D.tscn değişmedi).

**Özellikler:**
- `assets/models/test/` **otomatik taranır** (`DirAccess`); tüm `.glb`'ler
  alfabetik dizilir. Yeni model eklersen kod değişmeden görünür.
- **Oyunun gerçek koşulları:** aynı `WorldEnvironment` (gökyüzü + ambient),
  aynı `DirectionalLight3D` (rot -52/-32, renk 1.0/0.96/0.88, enerji 1.05,
  gölge 40 m), aynı kamera (pitch 52°, FOV 45, uzaklık 12.5×1.375), zeminde
  oyunun **gerçek çim materyali** (grass rengi 0.29/0.53/0.21 + speckle doku
  + triplanar).
- **Ölçek referansı:** solda oyuncu karakteri (`custom_character.gd`) **1.35 m**
  (oyundaki `TARGET_HEIGHT`). Her modelin altında billboard etiket:
  `dosya_adı · ham y=Xm · ×çarpan`.
- **Gündüz/Gece:** sağ üstteki **buton** (mobil dokunma) veya **Boşluk** tuşu.
  Gece: sun gece paletine döner + yanına **meşale ışığı** (turuncu OmniLight,
  gölgesiz, hafif titresim) — oyundaki gece hissiyle birebir.

### Ölçek çarpanları (Meshy tutarlılık verisi)

Vitrin her modeli **DISPLAY_H = 2.2 birim** yüksekliğe normalize eder;
çarpan = `2.2 / ham_yükseklik`. Bu çarpan, sonraki üretimlerde Meshy
ölçeğini kalibre etmek için kıymetli.

| Model | Ham AABB (b) | Ham yükseklik | Vitrin ×(→2.2) | Ağaç sistemi ×(→3.1) |
|---|---|---|---|---|
| pine_tree.glb | 1.06 × 1.90 × 1.12 | 1.90 | ×1.158 | ×1.632 |

> Yeni modeller eklendikçe bu tabloyu vitrindeki etiketlerden okuyup
> güncelle (ya da bana söyle, GLB'den ayrıştırıp eklerim).

### Vitrin nasıl çalıştırılır (editörden)

1. Godot editöründe projeyi aç.
2. **FileSystem** panelinde `scenes/style_showcase.tscn`'e çift tıkla (açılır).
3. Sağ üstteki **"Play Scene"** düğmesine bas (klavye: **F6** / Mac: **⌘+R**
   değil — F6 "sahneyi oynat"). Ana sahne (World3D) yerine SADECE bu sahne
   çalışır; oyunun kaydı/dünyası etkilenmez.
4. Sahnede: **Boşluk** ya da sağ üst **buton** ile gündüz↔gece.
5. Kapatmak için pencereyi kapat (F8) — oyun dosyaları olduğu gibi kalır.

> Not: Vitrini telefonda denemek istersen ayrı bir export gerekir; şimdilik
> masaüstü editörden judge etmek en pratiği. İstersen "ana sahneyi geçici
> style_showcase yap → APK al" adımını da yazabilirim.

---

## 2. pine_tree oyun-içi bağlama (altyapı kuruldu, varsayılan kapalı)

Ağaç sistemi **zaten** istediğin ucuz numaraları içeriyordu; yeniden
yazmaya gerek olmadı:

- ✅ **MultiMesh** batching (`_build_trees` → `_make_mesh_multimesh`): tür
  başına tek çizim çağrısı, yüzlerce ağaç.
- ✅ **Y-rotasyon + %90–110 ölçek** çeşitliliği zaten var:
  `_cell_variance()` → `Basis(UP, açı).scaled(0.9..1.1)`. "Tek modelle doğal
  orman" numarası hazırdı.
- ✅ Kesme davranışı / hücre kuralları ağaç **mesh'inden bağımsız** (obje
  haritası `"T"` + `_try_chop`); mesh değişse de devrilme + kesim
  partikülleri aynen çalışır.

**Eklenen bağlama kancası** (`scripts/world3d.gd`):
- `_model_pool` artık **tam yol** da kabul ediyor (`_nature_path`): test/
  altındaki modeller doğaya kopyalanmadan bağlanabilir.
- `const TREE_MODEL_OVERRIDE := ""` — boşken varsayılan Quaternius çam
  paketi. Tek GLB'ye geçmek için:
  ```gdscript
  const TREE_MODEL_OVERRIDE := "res://assets/models/test/pine_tree.glb"
  ```
  Tek satır. Kesme/hücre kuralı değişmez, sadece mesh değişir.

**Şu an KAPALI** çünkü yukarıdaki kritik bulgu (524k üçgen + materyalsiz).
Decimate + doku gelince aç.

### Çizim çağrısı / FPS — önce/sonra (dürüst durum)

- **Çizim çağrısı etkisi: ~NÖTR.** Ağaçlar zaten MultiMesh; mesh'i değiştirmek
  çizim çağrısı **sayısını** değiştirmez (havuz varyantı başına 1). Yani
  senin "sorun varsa MultiMesh öner" maddesi bu durumda geçersiz — **zaten
  MultiMesh.** Gerçek darboğaz **çizim çağrısı değil, üçgen/vertex hacmi.**
- **FPS önce/sonra sayısal ölçümü:** oyun-içi FPS/draw overlay'i
  **`performans` dalında** (henüz `main`'e merge edilmedi). Bu dal ondan
  bağımsız olduğu için burada sayısal FPS veremiyorum — **dürüst sınır bu.**
  Yapısal tahmin kesin: 524k×N üçgen ≈ 100M+ üçgen/kare = oynanamaz.
- **Ölçüm planı (perf overlay merge olunca):** `TREE_MODEL_OVERRIDE`'ı aç →
  Ayarlar → "Performans göstergesi" → ormanda dur, `draw` ve `frame_ms`/FPS
  oku → kapat, tekrar oku. `draw` neredeyse aynı, `frame_ms`/GPU süresi
  patlar → decimate ihtiyacını sayıyla doğrular. (Perf turunda bu senaryoyu
  probe'a da ekleyebilirim.)

---

## 3. Gelecek GLB kancaları — "şu adla atarsan otomatik bağlanır"

Mevcut kancalar zaten güçlü. Doğrulama:

| Model dosyası (bu yola/adla at) | Otomatik bağlanır mı? | Kanca |
|---|---|---|
| `assets/models/creatures/normal.glb` | ✅ **Evet, kod hazır** | `creature.gd`: `res://assets/models/creatures/%s.glb % type` — dosya varsa yükler, yoksa prosedürel placeholder. Tipler: `normal`, `tirmanici`, `kirici`, `hizli`. |
| `assets/models/creatures/tirmanici.glb` (vb.) | ✅ Evet | aynı kanca; her yaratık tipi kendi adıyla. |
| `assets/models/tools/chest.glb` | ✅ **Zaten var + bağlı** | `PLACE_MODELS["sandik"]["model"]`. Dosyayı üzerine yazarsan görsel güncellenir. |
| `assets/models/tools/campfire-pit.glb` (ocak) | ✅ Zaten var + bağlı | `PLACE_MODELS["ocak"]["model"]`. |
| **`furnace.glb`** | ⚠️ **Dedike yapı YOK** | Oyunda "furnace/fırın" adında yapı yok. Ocak `campfire-pit.glb` kullanıyor. Fırını bağlamak için ya `PLACE_MODELS["ocak"]["model"]`'i `furnace.glb`'ye çevir, ya da yeni bir "firin" item'ı tanımla (oyun tasarımı kararı — model gelmeden dokunmadım). |

**Kural:** Creature ve chest kancaları hazır — **doğru ad/yola atman
yeterli, kod değişmez.** Furnace için önce bir yapı kararı gerekiyor; onu
sana bıraktım (model gelince tek satır / kısa item tanımı).

Not: `assets/models/creatures/` klasörü henüz yok; ilk GLB'yi atınca oluşur
(git boş klasör tutmaz). Kanca yol kontrolünü `ResourceLoader.exists` ile
yaptığı için klasör yokken de güvenli — placeholder devrede kalır.

---

## Özet
- **Vitrin sahnesi:** hazır, oyunun gerçek ışığında, otomatik tarama, ölçek
  referanslı, gündüz/gece. Editörden F6 ile çalıştır.
- **pine_tree:** bağlama altyapısı hazır ama **524k üçgen + materyalsiz**
  olduğu için varsayılan kapalı. Decimate (~2-4k) + doku bake edilince tek
  satırla açılır.
- **Gelecek kancalar:** creature + chest hazır (doğru adla at, otomatik);
  furnace için yapı kararı bekliyor.
- **Değişmeyen:** kesme davranışı, hücre kuralları, ana oyun sahnesi.
