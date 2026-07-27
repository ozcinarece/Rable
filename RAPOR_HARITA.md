# RAPOR — HARİTA BOYAMA ARACI (maske sistemi + ressam)

İki parça: dünya üretimine rehber olan **maske sistemi** ve o maskeyi
çizmek için **masaüstü boyama aracı**. Branch: `harita-boyama`.
(Bu dosyanın altında önceki turun raporu duruyor: harita-v2 / üreteç.)

## PARÇA 1 — MASKE SİSTEMİ

**Dosya:** `res://data/map_mask.png` (1 piksel = 1 hücre, 128×128).
**Veri:** `scripts/map_mask.gd` — renk sözlüğü, eşikler, yoğunluklar;
kodda başka yerde renk tanımı yok.

| Renk | Sınıf | Oyundaki etkisi |
|---|---|---|
| Mavi #3B7DC4 | Su | hücre göl olur |
| Koyu yeşil #1E5B2E | Sık orman | boş çim/toprak %55 ağaç |
| Açık yeşil #7FBF4D | Çayır | ağaçların %94'ü kalkar, kaya/plato düzlenir |
| Gri #8A8A8A | Kayalık | boş hücre %14 kaya, orman seyrelir |
| Bej #D9C79A | Açıklık | tüm engeller kalkar, düz çim |
| Mor #8E5AC8 | Rezerv | engelsiz boş alan (gelecek içerik için) |

**Nasıl biniyor:** `MapGen.generate()` normal koşuyor; maske **sonradan
bir geçiş** olarak uygulanıyor (`MapMask.apply`). Dosya yoksa oyun
*birebir* eski davranışta — fallback bedava, üretecin içine dokunulmadı.
Repo şu an maske **içermiyor**: bugün oyunda hiçbir şey değişmedi; ilk
maskeyi sen kaydedip commit'lediğinde devreye girecek.

**Kenar organikliği (görev şartı):** maske pikseli doğrudan okunmaz —
örnekleme noktası iki ayrı noise ile ±2,5 hücre kaydırılır (domain
warp). Çizilen keskin kare kenar oyuna saçaklı geçer, birebir
kopyalanmaz. MASKTEST bunu ölçüyor (aşağıda).

**Korumalar:** kenar kumsal halkası, doğuş işareti ve doğuşun 6 hücre
çevresi maske **dinlemez** — doğuşa su/orman boyansa oyun açılamaz hâle
gelirdi. Palet dışı her renk ve saydam piksel "serbest"tir: üreteç ne
dediyse o kalır (yalnız istediğin bölgeyi boyaman yeterli).

## PARÇA 2 — BOYAMA ARACI

`scenes/tools/map_painter.tscn` — Godot'ta aç, **F6** (Run Current
Scene). Editör eklentisi değil, normal sahne. Fare öncelikli, pencere
yeniden boyutlanabilir.

- **Sol:** tuval. 6 büyük renkli buton (hex girme yok), Fırça / Silgi /
  Kova, boyut kaydırıcısı (1–14), Geri Al (10 adım), Kaydet, Yükle.
  Kova **sınıf** doldurur (piksel eşitliği değil — PNG yumuşatması
  renkleri milim oynatabilir, aynı bölge yine tek bölge sayılır).
- **Sağ üst:** canlı 2D biyom önizlemesi — maske + noise'un **birleşik**
  sonucu, her fırça darbesinde güncellenir (karede bir; sürükleme
  akıcı kalır).
- **Sağ alt:** **3D Önizle** butonu — önce kaydeder, sonra gerçek oyun
  sahnesini bir SubViewport içinde kurup tepeden bir kare alır ve
  sahneyi boşaltır. Pahalı olduğu için butonla (görev şartı). Bu modda
  (`RABLE_MASK_PREVIEW`) kayıt yükleme/menü/HUD kapalı ve oyun kaydına
  **asla yazılmaz**.
- **İlk açılış:** kayıtlı maske varsa o; yoksa **mevcut haritanın
  yaklaşık çevirisi** (üreteç çıktısı sınıf renklerine indirgenir, 3×3
  çoğunluk süzgeciyle lekeleştirilir — boş sayfa yok). Oyun seed'i
  sabit (`SEED_DEFAULT`) olduğu için çeviri oynadığın haritanın kendisi.

## DOĞRULAMA — MASKTEST (hızlı CI, her push)

"Maskede göl boya-kaydet → F5 → göl orada mı" zincirinin otomatik hâli.
Bellekte 128×128 çayır maskesi + (90..110, 20..40) su blobu üretilir,
gerçek üreteç çıktısına uygulanır:

- blob içi (warp payı kadar içeri çekilmiş) ≥ %90 su hücresi,
- boyanmayan uzak bölgeye **yeni su sızmamış**,
- kenar şeridinde sonuç, çizilen keskin kare sınırdan **en az bir
  hücre sapmış** (organiklik gerçekten çalışıyor),
- maske dosyası yokken `apply` çıktıyı **hiç değiştirmemiş** (fallback).

Dördü de `push_error` ile CI'yı kırmızı yakar.

## KULLANIM REHBERİ (5 madde)

1. **Aç:** Godot'ta FileSystem → `scenes/tools/map_painter.tscn` → çift
   tıkla → **F6** ("Run Current Scene"). Sol tarafta mevcut haritanın
   maske çevirisi hazır gelir.
2. **Boya:** üstten renk seç, boyutu ayarla, tuvale sürükleyerek çiz.
   Büyük alan için **Kova**; yanlışları **Silgi** ile serbest bırak
   (silinen yer prosedürele döner) ya da **Geri Al** (10 adım).
3. **Sonucu gör:** sağdaki canlı önizleme her darbede güncellenir —
   gördüğün şey maske+noise birleşimi, yani oyunun kuracağı biyom
   haritası. Emin olmak için **3D Önizle** (birkaç saniye, kuşbakışı
   gerçek dünya).
4. **Kaydet ve oyna:** **💾 Kaydet** → `data/map_mask.png` yazılır →
   oyuna dön, **Yeni Oyun** başlat (maske dünya *üretiminde* okunur;
   mevcut kayıtlı dünyayı değiştirmez). Kalıcı olsun istiyorsan
   `data/map_mask.png`'yi commit'le — CI ve web sürümü de o haritayla
   üretir.
5. **Sınırlar:** doğuş çevresi (6 hücre) ve harita kenarı maske
   dinlemez; renkleri araç butonlarından seç (dış araçta boyarsan
   palet dışı renkler "serbest" sayılır — hata değil, o bölge
   prosedürel kalır); maske yol/kamp yerleşimine karışmaz — kamp
   `camp_start.tscn`'de, yol oyun içi editörde.

---

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
| DIRT_SCALE / DIRT_THRESHOLD | 0.05 / 0.62 | toprak leke frekansı / eşik (yüksek=azınlık) |
| HILL_SCALE / HILL_THRESHOLD | 0.035 / 0.72 | plato frekansı / eşik (seyrek plato) |
| LAKE_CENTER | (0.24, 0.76) | göl köşe konumu (normalize) |
| LAKE_RADIUS / EDGE_JITTER | 20 / 8 | göl yarıçapı / kıyı düzensizliği |
| SHORE_WIDTH | 3 | kum kıyı genişliği |
| CLAY_CHANCE | 0.22 | kum hücresinde kil işareti şansı |
| ROCK_CLUSTERS | 16 | kaya öbek sayısı |
| ROCK_CLUSTER_MIN/MAX | 3 / 6 | öbek başına kaya |
| ORE_HINT_CLUSTERS | 5 | yüzey cevher ipucu sayısı |
| FOREST_SCALE / THRESHOLD | 0.045 / 0.62 | orman frekansı / alan eşiği |
| FOREST_DENSITY | 0.50 | orman içi ağaç şansı |
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
