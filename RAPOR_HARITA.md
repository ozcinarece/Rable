# HARİTA YENİDEN ÜRETİMİ + KAMERA — Uygulama Raporu

Otonom mod. Branch: `harita-v2` (hayatta-kalma üstüne). Kapsam: 128×128 noise
haritası + kamera uzaklığı. Yaratık kodu yok.

## Adım 0 — Keşif bulguları (önemli)
- **Arazi ZATEN chunk'lıydı.** `_build_terrain` → `_build_chunk(ck)` (tek parça
  mesh) + `_refresh_terrain_at(cell)` (yalnız etkilenen parçaları yeniden kurar).
  Yani "sadece ilgili chunk yeniden üretilir" mevcut sistemdi. `CHUNK_CELLS`
  8→**16** yapıldı (128×128'de 8×8=64 parça).
- **Taban harita kayda YAZILMIYOR.** Kayıt yalnız delta (kazı `depth`, `objects`,
  `placed`, su…) yazar; `_ground_char` kaydedilmez. Yükleme başlangıçta
  `_build_world()` çağırır, sonra deltaları bindirir. **Sonuç kararı:** taban
  harita her build'de aynı çıkmalı → **seed SABİT** (`MapBalance.SEED_DEFAULT`).
  Random-per-newgame istenirse seed'i kaydedip yükleme öncesi okumak gerekir
  (bilinçli olarak ertelendi — bkz. TODO).
- Harita ASCII string dizisiydi (`MapData.MAP`, 40×25 elle çizili). Doküman
  formatı korundu: üreteç de **aynı formatta `Array[String]`** döndürür,
  `_build_world` değişmeden tüketir.

## Kararlar (muhafazakâr; gerekçeli)
- **Üreteç = FastNoiseLite (Godot yerleşik), seed'li.** Ayrı noise'lar:
  toprak lekesi, plato, orman, göl kıyısı. `RandomNumberGenerator(seed)` kaya
  öbekleri + ağaç/çalı serpme. Aynı seed → aynı harita.
- **Düz PackedByteArray tampon (idx=y*n+x).** `Array[PackedByteArray]` içinde
  `grid[y][x]=v` KALICI DEĞİL (packed dizi kopya-üzerine-yazma GDScript tuzağı)
  — tek boyutlu tampon + elle indeksleme ile aşıldı.
- **Performans = chunk + frustum culling.** 64 ayrı parça mesh'i olduğundan
  Godot ekran dışı parçaları otomatik eler; her karede yalnız **görünür** birkaç
  parça çizilir (tüm 128×128 değil). Nesneler (ağaç/kaya) MultiMesh (tür başına
  1 çizim). Kazıda yalnız o hücrenin parçası (+2 hücre pay) yeniden kurulur.
- **Kil kaynağı:** `"k"` char = kil-işaretli kum → zemin "s" (kürek kazar) +
  görsel yama (kil-rengi disk MultiMesh) + **kazıda garanti +1 kil**
  (`_clay_cells`, `_try_dig`). Cevher ipucu: birkaç kaya öbeği yanına bakır-tonlu
  yüzey pebble (görsel; derin kazı/madencilik mekaniği mevcut sistemde).
- **Doğuş:** merkeze en yakın düz çim/toprak hücresi; çevresi
  `SPAWN_CLEAR_RADIUS` kadar temizlenir (ağaçsız güvenli açıklık). Göl köşede
  → keşif mesafesi.
- **Ağaç seyreltme** önceki düzeltmeyle tutarlı: üreteç yoğun orman koyar,
  `_build_world`'ün `_tree_neighbor` kuralı (1 hücre=max 1 ağaç, min 1 boş
  komşu) inceltir.
- **Kamera:** çarpan aralığı `[0.55, 2.2]`, varsayılan **1.375** (orta nokta,
  geniş dünya). En yakın = eski yakınlık (0.55), en uzak ≈ 1.6×varsayılan.
  Pinch + slider korunur; tüm sayılar sabitlere bağlı.

## DENGE VERİSİ (`scripts/map_balance.gd`, elle oyna)
| Sabit | Değer | Anlam |
|---|---|---|
| MAP_SIZE | 128 | harita kenarı (hücre) |
| SEED_DEFAULT | 20260721 | harita tohumu (değiştir=yeni harita) |
| DIRT_SCALE / DIRT_THRESHOLD | 0.05 / 0.34 | toprak leke frekansı / eşik |
| HILL_SCALE / HILL_THRESHOLD | 0.035 / 0.60 | plato frekansı / eşik |
| LAKE_CENTER | (0.24, 0.76) | göl köşe konumu (normalize) |
| LAKE_RADIUS / EDGE_JITTER | 20 / 8 | göl yarıçapı / kıyı düzensizliği |
| SHORE_WIDTH | 3 | kum kıyı genişliği |
| CLAY_CHANCE | 0.22 | kum hücresinde kil işareti şansı |
| ROCK_CLUSTERS | 16 | kaya öbek sayısı |
| ROCK_CLUSTER_MIN/MAX | 3 / 6 | öbek başına kaya |
| ORE_HINT_CLUSTERS | 5 | yüzey cevher ipucu sayısı |
| FOREST_SCALE / THRESHOLD | 0.045 / 0.58 | orman frekansı / alan eşiği |
| FOREST_DENSITY | 0.55 | orman içi ağaç şansı |
| SPARSE_TREE_CHANCE | 0.015 | açıklıkta seyrek ağaç |
| BUSH_CHANCE | 0.006 | çim hücresinde çalı şansı |
| SPAWN_CLEAR_RADIUS | 4 | doğuş çevresi temiz yarıçap |
| CAM_ZOOM_MIN/DEFAULT/MAX | 0.55 / 1.375 / 2.2 | kamera zoom çarpanı |

## Performans notu
- Terrain: 64 parça (16×16 hücre, hücre başına 4×4 yama). **Frustum culling**
  sayesinde her karede yalnız görünür ~4-9 parça render edilir (~50-75k üçgen),
  128×128'in tamamı değil. Uzak zoom'da bile görünür parça sayısı sınırlı →
  kare hızı korunur (bkz. `3d_wide.png`, `3d.png`). Gerçek cihaz FPS ölçümü
  kullanıcıya bırakıldı; tri bütçesi mobil için güvenli aralıkta.
- Kazı hitch'i: `_refresh_terrain_at` yalnız 1-4 parçayı yeniden kurar; ancak
  `_rebuild_objects`/`_build_decor`'u da çağırır (tüm ağaç/dekor multimesh'i).
  128×128'de bu tek kazıda kısa bir yeniden-kurma; nadir olduğundan kabul
  edildi (ileride nesne rebuild'i parça-yerel yapılabilir — TODO).

## CI doğrulaması
`MAPTEST: boyut=128x128 su=… agac=… kaya=… kil=… dogus=… zemin=.` (doğuş çim/
toprak üstünde), `CAMTEST: zoom=1.375 min=0.55 max=2.2`. `3d_wide.png` tüm yeni
adayı, `3d.png` oyun kamerasının yeni geniş varsayılanını gösterir. Base/yaşam
self-test'leri (SAVELOAD dahil) yeni haritada da geçer.

## SENİN İÇİN TEST SENARYOSU (sırayla)
1. **Yeni haritada doğ:** açık, ağaçsız düz alanda başlarsın (güvenli açıklık).
2. **Su kıyısını bul:** bir köşede göl; kıyısında kum şeridi.
3. **Kum/kil topla:** kumda **kil-rengi yamalar** (görsel); kürekle kaz →
   garanti kil düşer.
4. **Kaya öbeğinde kaz/kır:** dağınık kaya öbekleri (kazma); birkaçının yanında
   **bakır-tonlu yüzey ipucu**.
5. **Ormanda ağaç kes:** öbekli orman alanları + seyrek tekiller; her ağaç ayrı
   (bitişik değil).
6. **Uzak zoom'da gez:** pinch (ya da slider) ile en uzağa çık → **geniş dünya**
   görünümü, karakter küçük; akıcı kalmalı (chunk culling).
7. **Kapat-aç:** aynı harita (sabit seed) + kazdıkların/kurduğun yapılar yerinde.

## Bilinen sorunlar / TODO'lar
- **Seed sabit** (aynı harita her yeni oyun). Random-per-newgame: taban harita
  kaydedilmediğinden seed'i kayda yazıp `_build_world` öncesi okumak gerek
  (mimari değişiklik — ertelendi). Şimdilik `SEED_DEFAULT`'u değiştirerek yeni
  harita alınır.
- **Eski kayıtlar (40×25)** boyut farkından reddedilir (yeni oyun başlar) —
  harita boyutu köklü değişti, beklenen davranış.
- **Kazıda nesne rebuild'i** parça-yerel değil (tüm multimesh). Nadir olduğu
  için kabul; ileride optimize edilebilir.
- **Cevher ipucu** yalnız görsel; yüzeyden cevher toplama mekaniği yok (derin
  kazı/taş kırma mevcut kaynak yolu).
- **Tekerlek zoom'u** mobil-öncelikli olduğundan yok; pinch + slider var
  ("tekerlek korunur" = mevcut zoom bozulmadı).
