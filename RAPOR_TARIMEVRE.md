# RAPOR — Tarım Evre Seti: Toplu Bağlama (tarim-evre)

5 yeni model bağlandı; evre zinciri standardı artık 5 üründe tam:
filiz (ortak tiny_plant) → stage2 (GERÇEK model) → olgun. "%50 ölçek"
hilesi stage2'si olan ürünlerde emekli (kod fallback olarak duruyor —
berry ve gelecekteki modelsiz ürünler için). Berry'ye dokunulmadı
(revizyon bekliyor).

## Ölçekler (ölçüldü — Root Scale ile, node scale yok)

| Model | Doğal boy | Hedef | root_scale | Olgunun %'si |
|---|---|---|---|---|
| pumpkin_stage2 | 0.483 | 0.36 | 0.7447 | %65 |
| earth_apple_stage2 | 0.529 | 0.25 | 0.4723 | %66 |
| korotu_stage2 | 0.582 | 0.29 | 0.4983 | %64 |
| mist_mushroom (OLGUN) | 0.996 | 0.35 | 0.3514 | — |
| mist_mushroom_stage2 | 0.497 | 0.22 | 0.4426 | %63 |

Hepsi Y-up; döndürme gerekmedi. Tümsekli modeller 1-2 cm gömük.

## Rotasyon kararları (model model)

- golden_wheat: 0/90/180/270 (kare taban — kullanıcı kuralı, önceden).
- pumpkin, earth_apple, korotu, mist_mushroom: SERBEST rotasyon
  (yuvarlak tümsek/küme — karo hizası derdi yok; CROP_GLB_SERBEST_ROT).

## Evre geçişi: 0.3 sn çapraz solma

Büyüme geçişinde eski görsel erirken yenisi belirir (EVRE_GECIS_SN,
transparency tween'leri düğümlere bağlı). Yalnız İKİ görsel de varken
oynar: ekim/kayıt yükleme/hasat anlık kalır (hasat kendi animasyonunu
oynuyor). Not: "buğday görevindeki kural" olarak anılan çapraz solma
kodda YOKTU — bu görevle eklendi ve tüm ürünlere uygulanıyor.

## Korotu stage2 (özel)

Tomurcuk emission'u fide kuralından: enerji ×0.35 (gündüz 0.14 /
gece 0.53 — "çok soluk sızıntı"), sızıntının YERİ modelin kendi
emissive dokusundan (dikişler). OmniLight YOK — tam ışık olgunlukta
doğar (korotu-isik kuralı; o sistem main'de, entegrasyon otomatik).
Gece karesi b2: tomurcuk sızıntısı vs olgun parlama farkı.

## Mantar eşleşme kontrolü (görev şüphesi)

Ölçümle doğrulandı: `mist_mushroom` 0.81×1.00×0.79 (BOY baskın —
üç boylu gelişkin küme = OLGUN ✓), `mist_mushroom_stage2`
1.0×0.50×1.0 (basık-yaygın minik kapalı şapkalar = STAGE2 ✓).
Karede de kompozisyon doğru çıktı — DOSYA ADLARI DOĞRU, takas
GEREKMEDİ. Olgun placeholder (tepsili beyaz mantarlar) emekli.

## Doku/boyut

5 dosya 2048→1024: toplam ham 20.7 MB → 2.3 MB. crops/ klasörü
şimdi 18 MB (görev "40+ MB" demişti — küçültmeler sonrası değil,
ham girişlerin toplamıydı). Kalan şişkinlik: planting_mound.glb
4.7 MB hâlâ 2048'lik (backlog'daki ayrı küçük iş). Ürün GLB'lerinin
tamamı 0.34-0.97 MB bandında; bellek model başına ~5.3 MB ham RGB
eşdeğeri (4×1024²+mip).

## Kareler

- (a) `evre_a_gunduz.png` — 5 ürün × 3 evre aile fotoğrafı (sütun=ürün,
  satır=evre), gündüz oyun açısı.
- (b) `evre_b_gece.png` + `evre_b2_korotu_yakin.png` — aynı düzen gece;
  korotu tomurcuk sızıntısı ile olgun parlama yan yana.
- (c) `evre_gecis.gif` — buğday fide→olgun çapraz solma (yavaşlatılmış
  çekim, 8 kare).

FARMTEST2 + SLICETEST + tam hızlı test yeşil.
