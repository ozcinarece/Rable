# RAPOR — Tarım GLB Bağlama: İlk Üçlü (tarim-glb-2)

assets/models/crops/ altına gelen 4 dokulu Meshy modeli (pumpkin,
pumpkin_decor, korotu_flower, earth_apple) tarim-2'nin hazır
kancalarına bağlandı. golden_wheat ve mist_mushroom dosyası yok —
placeholder'ları fallback kuralıyla aynen sürüyor.

## Ölçek ve oturma

Kural gereği ölçek **import Root Scale** ile (node scale yok):

| Model | Doğal boy (ölçüldü) | Hedef boy | root_scale |
|---|---|---|---|
| pumpkin | 0.617 | 0.55 (iri — kişiliği) | 0.8911 |
| earth_apple | 0.662 | 0.38 | 0.5739 |
| korotu_flower | 1.000 | 0.45 | 0.4500 |
| pumpkin_decor | 0.617 | PLACE_MODELS h=0.32 | 1.0 |

- Hepsi **Y-up** geldi; Root Rotation gerekmedi.
- Hedef boy + gömme tabloları `tarim_balance.gd`'de (CROP_GLB_BOY /
  CROP_GLB_GOM). Toprak tümsekli üçü zemine 1.5–2 cm gömük oturuyor —
  tümsek kenarı çim/tarla ile buluşuyor, havada durmuyor.
- **Fide evresi**: olgun modelin %50'si (FIDE_ORAN — mevcut kural).
  Kare (a)'da buğday çubuklarının yanındaki küçük kabak fide örneği.
  Üç üründe de aynı yoldan çalışıyor (tek kod yolu).
- Olgun evre gerçek modeli doğrudan kullanır; filiz evresi ortak
  yeşil filiz olarak kaldı.

## Korotu gece parlaması

Meshy modeli gerçek bir **emissive doku** ile geldi (çiçek çanağı
bölgesi). `_tame_meshy_materials` Meshy'nin beyaz-parlama tuzağına
karşı emission'u kapatır; korotu için doku kanalı korunarak soluk
turkuaz tonla (KOROTU_EMISSION) yeniden açıldı. Gece güçlenmesi
`_update_water_night`'ın TEK gece kaynağından: gündüz enerji 0.25,
gece 1.6 (KOROTU_GLB_ENERJI_*). Kare (b) gece kanıtı. YALNIZ gece
büyüme kuralı (night_grow tick) veride — dokunulmadı.

## pumpkin_decor

PLACE_MODELS'e girdi (h 0.32, davranışsız salt dekor, solid değil,
hp 20) — kabak hasadının %30 şansla düşürdüğü Süs Kabağı artık elde
tutulup yere yerleştirilebiliyor. Kare (d) kamp içinde.

## Doku/boyut etkisi (görev şartı)

Dokular 2048² JPEG ×4 katman geldi — **1024²'ye indirilip GLB yeniden
paketlendi** (Godot scene import'unda gömülü doku için boyut sınırı
parametresi yok; GLB binary'si Python'la yeniden yazıldı, geometri
bit-bit aynı):

| Dosya | Gelen | Şimdi |
|---|---|---|
| earth_apple.glb | 4.6 MB | 0.45 MB |
| korotu_flower.glb | 4.9 MB | 0.47 MB |
| pumpkin.glb | 3.6 MB | 0.34 MB |
| pumpkin_decor.glb | 3.6 MB | 0.34 MB |
| **Toplam** | **16.7 MB** | **1.6 MB** |

VRAM: doku başına 2048² → 1024² = ~4'te 1 (mip'lerle model başına
~21 MB → ~5.3 MB ham RGB eşdeğeri; web'de indirme boyutu da aynı
oranda düştü). Üçgen sayıları zaten mobil dostu: 973–1075/model.
1024'te mobil ekranda görsel fark yok (kareler 1024'lü hali).

## Doğrulama

- FARMTEST2 yeşil (büyüme kuralları GLB'lerden bağımsız sürüyor).
- Tam hızlı test HATA-YOK; ekran kareleri xvfb + opengl3'te çekildi.

## Kareler (görev teslimi)

- (a) `tarimglb_a_gunduz.png` — 6'lı tarla: 3 gerçek model olgun +
  2 placeholder (buğday/mantar) + 1 kabak fidesi (%50).
- (b) `tarimglb_b_gece.png` — korotu gece parlarken, yakın.
- (c) `tarimglb_c_hasat.png` — kabak hasadı sonrası: hücre boş,
  düşen ürünler yerde.
- (d) `tarimglb_d_dekor.png` — pumpkin_decor kamp içinde.
- (e) `tarimglb_e_vitrin.png` — karakter olgun kabağın yanında
  (diz boyu ölçek kanıtı); korotu + toprak elması arkada.

## Notlar / emanetler

- golden_wheat.glb ve mist_mushroom.glb geldiğinde: dosyayı koymak +
  .import'a root_scale yazmak yeterli (kanca ve fallback hazır).
- pumpkin_decor.glb, pumpkin.glb'nin birebir kopyası (md5 aynı) —
  ileride farklı bir süs varyantı gelirse dosyayı değiştirmek yeter.
- İlk import GLB yanına dokuları .jpg olarak çıkarıyor (Godot
  embedded_image_handling) — 1024'lük çıkarılmış kopyalar depoda.
