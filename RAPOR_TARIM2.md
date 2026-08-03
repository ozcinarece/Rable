# TARIM-2 — 6 Ürün + Mutfak (tarim-2)

## ÜRÜNLER (tablo tarim_balance.CROPS'a birebir işlendi)
berry 2 gece / elma 3 (bozulmaz bayrağı ileriye) / altınbaş 4 (ÇİĞ
YENMEZ — FOOD_SATIATION'da bilerek yok) / kabak 5 (%30 süs kabağı
bonusu) / korotu 3 (YALNIZ GECE) / sis mantarı 2 (SULAMASIZ+TARLASIZ).
Tohum iadeleri ürün başına (%50-70). Evre sayısı nights+1; görsel
3 kovaya iner (filiz ortak / fide konisi / olgun ürüne özel).

## BÜYÜME KURALLARI (farming.gd)
- `night_tick` (gece başında world3d çağırır): yalnız night_grow
  ürünleri ilerletir. Gündüz/şafak tick'i korotuyu ATLAR — FARMTEST2
  iki yönü de doğrular.
- `no_water`: `_advance` islaklık şartı aramaz (mantar).
- `plant_free`: tarla gerektirmeyen ekim; gölge kuralı world3d'de
  (ağaç dibi 1 hücre; iç mekan TODO — ev-cati dalı rafta). Hasatta
  hücre plot bırakmaz (temiz zemine döner).

## GÖRSELLER
Olgun evrede GLB kancası (assets/models/crops/ — DOSYA-BEKLER:
earth_apple/golden_wheat/pumpkin/pumpkin_decor/korotu_flower/
mist_mushroom); gelene kadar kimlikli placeholder: elma kahve
yumrular, buğday sarı başak demeti, kabak turuncu küre, korotu
turkuaz EMISSION çiçek (gece parlar), mantar gri şapkalar.

## TOHUM EDİNİMİ (köprü kanallar)
- berry: yabani çalı %50 (mevcut kural).
- elma+buğday: kamp mirası — devrik sandık söküm buluntusuna 2'şer
  tohum (ilk oyunda erişilebilir).
- kabak/korotu/mantar: yakılan her ANA kor taşı çevresine sıralı 1
  nadir tohum (kesif_balance.KOR_TAS_TOHUM; derin keşif loot
  tablosuna taşıma TODO'su ile).

## MUTFAK
Un (2 altınbaş, TAŞ DİBEK) / Ekmek (2 un, +45) / Köz Çorbası (1
kabak + 1 su, +35, GECE BOYU buff) / Mantarlı Güveç (mantar+et+su,
+50) / Korlu Lokma (un+korotu, +25, 3 dk hız 1.3x). Su "dolu kova"
ile girer, boş kova çıktıda GERİ verilir (kap kaybolmaz). TAŞ DİBEK:
3 taş, tezgahta üretilir, araştırma farming_basics; tek işlevi
öğütme (Crafting.near_dibek istasyon kapısı); prosedürel çanak+havan
eli görseli (GLB kancası dosya-bekler).

## BUFF ÇERÇEVESİ (PlayerStats — yeni)
buffs sözlüğü: süreli (sn) ya da GECE-BOYU (-1; şafakta
end_night_buffs). Yemek adı = buff adı (apply_food otomatik tetikler).
- Korlu Lokma: speed_mult() → player3d hız çarpanı.
- Köz Çorbası: sis direnci (ışık açığı affı + vinyet 0.25x, fırtına
  istisnası üstün) + oyuncu çevresi ışık halkası (yarıçap/enerji
  veride) + HUD rozeti (aktif buff adları, buffs_changed'e bağlı).

## DOĞRULAMA
FARMTEST2 (hızlı CI): urunler=ok korotu_gece=true mantar=true
mantar_temiz=true hiz=true corba=true safak=true. Kareler (yerel
gerçek-oyun + ağır CI): 3d_tarim2_urunler (6 olgun ürün + dibek),
3d_tarim2_corba_gece (ışık halkası + rozet + parlayan korotu).
NOT: ürün karesi kadrajı kayalık alana denk geldi — okunur; tarla
fonunda çekim modeller gelince tazelenir.
