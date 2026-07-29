# RAPOR — ÇİM SHADER V1 ENTEGRASYONU (branch: cim-shader)

`assets/models/env/grass.gdshader` süs otu MultiMesh'lerine bağlandı;
çiçekler aynı shader'ın düşük-rüzgâr kopyasını aldı. Taban bilinçli
olarak `su-shader-v1` dalı: sözleşme noise_tex ve night_mix'in su ile
AYNI kaynaktan paylaşılmasını istiyor (o iş henüz main'de değil —
bu dal merge edilirken su da birlikte gelir). Geri dönüş:
`DigWaterVisual.CIM_SHADER_V1 = false`.

## SÖZLEŞME UYGULAMASI

| Madde | Uygulama |
|---|---|
| MultiMesh materyali | `material_override` MMI düzeyinde — TEK draw call korunur (CIMTEST sayar) |
| blade_height ölç-gir | koddan ÖLÇÜLÜR: havuz mesh'lerinin AABB yüksekliği (Root Scale sonrası gerçek boy) |
| player_pos her kare | `_process`'te tek uniform seti; **quality 0'da set de atlanır** (`_cim_ezme_on`) |
| night_mix aynı kaynak | `_update_water_night` su+çim+çiçeği AYNI değerle günceller |
| noise_tex paylaşımı | `_ortak_noise_tex()` — su ve çim aynı NoiseTexture2D örneğini kullanır (bellek) |
| quality | kalite kademesinden: Düşük=0 (rüzgâr+ezme kapalı), Orta/Yüksek=1 |

## ÇİÇEK / MİNİ BİTKİ KARARI

- **Çiçek**: aynı shader'ın kopyası — `wind_strength 0.03` (başlar
  savrulmaz, sözleşme notu) + yumuşak pembe uç / sap yeşili gradyanı.
  Takas: GLB'nin taç yaprak dokusu yerine stilize gradyan; tek satırla
  eski hale döner.
- **Mantar**: UYGULANMADI — şapka/gövde dikey gradyanla bozulur ve
  mantar rüzgârda sallanmamalı. Eski materyalinde kaldı.
- Kazı ağzı çim sarkmaları (A5) ayrı sistem, dokunulmadı (borç:
  istenirse aynı materyal bağlanabilir).

## 4.7 DERLEME

Shader olduğu gibi derlendi — su shader'ındaki `CUSTOM0` sınıfı bir
hata YOK (varying'ler baştan doğru). Değişiklik yapılmadı.

## FPS ÖNCE/SONRA (çayırlık, telefon profili)

Draw call SAYISI DEĞİŞMEDİ: süs otu zaten havuz başına tek MultiMesh
idi; override MMI düzeyinde (CIMTEST `mmi=shaderli` eşitliğini ve
örnek sayısını basar — önce/sonra aynı). Maliyet farkı vertex başına
rüzgâr matematiği (~%20 hücre süslü, tutam başına düşük vertex) +
kare başına 1-2 uniform seti. Düşük kademede shader eski davranışa
kapanır VE player_pos seti de atlanır. Telefon ölçümü: Ayarlar → FPS,
çayırda Düşük↔Yüksek karşılaştır — fark hissedilirse wind pahası
veriden kısılır (`wind_strength`/`quality` eşiği).

## KARELER (ağır CI)

- `3d_cim_ruzgar_a/_b.png`: AYNI kadraj 1 sn arayla — statik karede
  rüzgâr ancak iki karenin FARKIYLA kanıtlanır (uçların yer
  değiştirmesi). GIF/video CI boru hattında yok — borç; telefonda
  gözle görülür.
- `3d_cim_ezme.png`: karakter çimin içinde — çevresindeki tutamlar
  dışa yatık.
- `3d_cim_su_gece.png`: göl kıyısında çim, gece — su+çim gece tonu
  AYNI night_mix kaynağından, uyum tek karede.

## KAPANIŞTA BULUNAN İKİ GERÇEK HATA (düzeltildi)

1. **CI'nin push_error ağı delikti.** Godot 4.7 `push_error`'u
   "USER ERROR:" değil `ERROR: <mesaj>` + `at: push_error (...)`
   olarak basıyor (yerelde 4.7-stable ile ölçüldü). ci-fast.yml yalnız
   "USER ERROR" aradığı için CIMTEST'in gerçekten ateşlenen bir değer
   hatası CI'da YEŞİL kalmıştı. Desene `at: push_error` eklendi —
   artık tüm değer testlerinin (WATERCOLORTEST dahil) hatası CI'yı
   kırmızı yakar.
2. **CIMTEST yanlış sayıyordu.** Çakıl/dal serpintisi MMI'ları da
   `_decor_nodes`'ta yaşıyor ve bilerek shadersiz (taş/dal
   sallanmamalı); test onları da sayıp "2/3 shadersiz" diyordu.
   Sayım süs otuna daraltıldı: `mmi=1 shaderli=1 ornek=1890`.
   Materyal ataması baştan beri doğruydu — hata testin kapsamındaydı.

Aynı koşuda görülen ayrı bulgu (bu dalın işi değil): `cam.png`,
`kor_feneri.png`, `koz_kabi.png` ikon dosyaları yok — keşif
paketinin eşyaları ikonsuz ("Resource file not found"). Meshy/ikon
üretiminde sıraya alınmalı.

---

# ÇİM YOĞUNLUK TURU (cim-yogunluk — "web'de çim prototipteki gibi değil")

## TEŞHİS

Shader doğru çalışıyordu ama yalnız SEYREK süs otunda koşuyordu:
her 5 çayır hücresinden 1'ine tek Meshy öbeği (~1890 tutam). Prototip
görünümü SIK ince yaprak tarlası — çayırın geri kalanı düz yeşil
zemin olarak kalıyordu.

## ÇÖZÜM: ÇİM TARLASI KATMANI

- Prosedürel yaprak tutamı: çapraz 3 daralan quad (12 vertex), renk
  shader'ın kök→uç gradyanından — mesh'te renk yok.
- Her uygun çayır hücresine 8 tutam (sayılar DigWaterVisual C3:
  CIM_FIELD_*; ilk deneme 3/hücre + 0.09 genişlik SEYREK kaldı —
  üstten bakan kamerada dikey yaprak az piksel kaplıyor; 8/hücre +
  0.14 genişlik lab A/B ile seçildi). Toplam ~75k tutam.
- 16x16 hücre chunk'ları = ayrı MultiMesh (frustum culling; tek dev
  MM her kare 900k vertex çizerdi). Materyal/mesh ortak — ekranda
  ~4-9 draw call.
- ARTIMLI kurulum: _build_decor her kazı/zemin değişiminde çağrılır;
  chunk başına uygunluk imzası tutulur, yalnız imzası değişen chunk
  yeniden kurulur (75k transform'u her kazıda kurmak takılma yapardı).
- Hariç tutulan hücreler: nesneli, kazılı, kamp tarlası, yol, yapı.
- Düşük kademe: tarla TAMAMEN gizli (statik çim sözleşmesi + telefon
  bütçesi); süs otu serpintisi Düşük'te de kalır.
- Rüzgâr/ezme/gece/kalite otomatik: AYNI paylaşılan _cim_material.

## DOĞRULAMA

CIMTEST genişledi: tarla_chunk=64 tarla_ornek=75328
tarla_dusuk_gizli=true + ortak materyal denetimi. Kareler yerel
xvfb gerçek-oyun koşusundan: gündüz çayır artık yoğun yaprak tarlası;
gece karesinde çayır+su aynı night_mix ile kararıyor. Kadraj seçimi
düzeltildi (önce çevresi ±3 tamamen çayır hücre aranır — ilk tur kıyı
toprağına düşmüştü).
