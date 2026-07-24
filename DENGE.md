# DENGE DÖKÜMÜ — Hayatta Kalma + Tarım Sabitleri

Salt-okunur denetim. Kaynak dosyalar: `scripts/survival_balance.gd`,
`scripts/hunger.gd`, `scripts/thirst.gd`, `scripts/health.gd`,
`scripts/tarim_balance.gd`. Kod DEĞİŞTİRİLMEDİ.

**Dönüşüm tabanı** (`scripts/time_balance.gd`): bir tam gün =
45 (şafak) + 600 (gündüz) + 45 (akşam) + 240 (gece) = **930 gerçek saniye
= 15,5 gerçek dakika**. Bu dökümde "1 oyun saati" = günün 1/24'ü =
**38,75 gerçek saniye**. Tüm "kaç saat idare eder" hesapları bu tabana göre.

## TABLO

| Sistem | Parametre | Değer | Birim | Dosya:satır | Tasarım notu |
|---|---|---|---|---|---|
| Açlık | HUNGER_MAX | 100.0 | puan | survival_balance.gd:7 | Bar kapasitesi. Tam bar = 12,3 oyun saati (yarım günden biraz fazla). |
| Açlık | HUNGER_DECAY_PER_SEC | 0.21 | puan/sn | survival_balance.gd:9 | Tok karın dinlenirken ~7,9 gerçek dakikada tamamen acıkır. |
| Açlık | EFFORT_HUNGER_MULT | 1.25 | çarpan | survival_balance.gd:11 | Koşarken/kazarken bar 6,3 dakikada biter — efor günlük yemek ihtiyacını 195 → 244 puana çıkarır. |
| Açlık | HUNGER_WARN_THRESHOLD | 30.0 | puan | survival_balance.gd:13 | "Acıktın" uyarısı açlık bitmeden ~2,4 gerçek dakika önce gelir; yemek bulmaya yeter. |
| Can | HEALTH_MAX | 100.0 | puan | survival_balance.gd:16 | Zırhsız oyuncu 100 hasar taşır. |
| Can | STARVE_HEALTH_LOSS_PER_SEC | 0.5 | puan/sn | survival_balance.gd:18 | Açlık sıfırlandıktan sonra ölüme 200 sn (3,3 dk) var — panik değil, uyarı süresi. |
| Can | REGEN_HUNGER_THRESHOLD | 70.0 | puan | survival_balance.gd:20 | İyileşme yalnız barın üst %30'unda; "tok ol ki iyileş" kuralı. |
| Can | HEALTH_REGEN_PER_SEC | 1.0 | puan/sn | survival_balance.gd:22 | Tok gezerken sıfırdan tam cana 100 sn (2,6 oyun saati). Yemek = ilaç. |
| Ölüm | RESPAWN_HEALTH | 50.0 | puan | survival_balance.gd:25 | Yarım canla dirilme; arka arkaya ölüm zinciri riskli. |
| Ölüm | RESPAWN_HUNGER | 50.0 | puan | survival_balance.gd:26 | Dirilince ~6,2 oyun saatlik yemek kalır; hemen yeme baskısı yok. |
| Ölüm | DROP_ITEMS_ON_DEATH | false | bayrak | survival_balance.gd:28 | v1'de envanter korunur — ölüm zaman kaybı, ilerleme kaybı değil. |
| Yeme | FOOD_SATIATION["meyve"] | 12.0 | puan | survival_balance.gd:33 | 1,5 oyun saati idare eder. Yalnız meyveyle yaşamak günde ~16 meyve ister. |
| Yeme | FOOD_SATIATION["mantar"] | 10.0 | puan | survival_balance.gd:34 | 1,2 oyun saati; en zayıf yiyecek — günde ~20 adet. Ara atıştırmalık. |
| Yeme | FOOD_SATIATION["cig_et"] | 15.0 | puan | survival_balance.gd:35 | 1,8 oyun saati. Meyveden %25 iyi ama %20 bulantı riski taşır. |
| Yeme | FOOD_SATIATION["pismis_et"] | 40.0 | puan | survival_balance.gd:36 | 4,9 oyun saati — günde ~5 adet yeter. Pişirmek eti 2,7 katına çıkarır; ocağın asıl gerekçesi bu. |
| Yeme | RAW_MEAT_IDS | ["cig_et"] | liste | survival_balance.gd:40 | Bulantı riski taşıyan tek yiyecek listesi. |
| Yeme | NAUSEA_CHANCE | 0.20 | olasılık | survival_balance.gd:41 | Beş çiğ etten birinde bulantı. |
| Yeme | NAUSEA_DURATION | 5.0 | sn | survival_balance.gd:42 | Ceza yalnız 5 saniye sürer → net kayıp ~1,1 puan. Pratikte caydırıcı DEĞİL; çiğ et yemek hâlâ kârlı. |
| Yeme | NAUSEA_HUNGER_MULT | 2.0 | çarpan | survival_balance.gd:43 | Bulantı sırasında açlık iki kat hızlı erir. |
| Yeme | EAT_DURATION | 1.0 | sn | survival_balance.gd:45 | Yeme animasyonu 1 sn; savaş ortasında yemek neredeyse bedava. |
| Açlık (depo) | MAX_VALUE | 100.0 | puan | hunger.gd:9 | SurvivalBalance.HUNGER_MAX ile ÇİFT tanım. İkisi de 100; biri değişirse sessizce tutarsız kalır. |
| Susuzluk | MAX_VALUE | 100.0 | puan | thirst.gd:8 | Bar kapasitesi. |
| Susuzluk | DECAY_PER_SECOND | 0.3 | puan/sn | thirst.gd:10 | Tam bar 5,6 gerçek dakika = 8,6 oyun saati. Su, açlıktan %43 hızlı biter — asıl baskı susuzluk. |
| Susuzluk | DRINK_AMOUNT | 35.0 | puan | thirst.gd:11 | Bir yudum 3 oyun saati; bir günü çıkarmak ~8 yudum ister (su kenarına 8 gidiş). |
| Can (depo) | MAX_VALUE | 100.0 | puan | health.gd:9 | SurvivalBalance.HEALTH_MAX ile ÇİFT tanım (yukarıdaki açlıkla aynı sorun). |
| Zırh | zırh hasar çarpanı | 0.6 | çarpan | health.gd:16 | Envanterde zırh varken %40 az hasar. SABİT KOD İÇİNDE — denge dosyasında değil. |
| Zırh | şapka hasar çarpanı | 0.85 | çarpan | health.gd:18 | %15 az hasar. Zırh+şapka birlikte 0,51 → gelen hasar neredeyse yarıya iner. |
| Tarım | TILLED_DECAY_DAYS | 3 | gün | tarim_balance.gd:7 | Boş tarla 3 günde (46,5 gerçek dakika) çime döner. Ekmeyi unutmak affediliyor. |
| Tarım | SEED_RETURN_CHANCE | 0.6 | olasılık | tarim_balance.gd:9 | Hasatta %60 tohum iadesi → tarla uzun vadede küçülür, tohum bulmak gerekir (kendi kendine katlanmaz). |
| Tarım | WATERING_CAN_USES | 4 | kullanım | tarim_balance.gd:11 | Bir dolumla 4 tarla sulanır; 5+ tarlada su kenarına gidiş gerekir. |
| Tarım | CROPS.berry_bush.stages | 3 | evre | tarim_balance.gd:19 | Filiz → fide → olgun. Her evre bir sulanmış şafak ister → ekimden hasada 2 gün = 31 gerçek dakika. |
| Tarım | CROPS.berry_bush.seed_item | "tohum" | eşya id | tarim_balance.gd:18 | Ekilen eşya (Türkçe katalog id'si). |
| Tarım | CROPS.berry_bush.yield_item | "meyve" | eşya id | tarim_balance.gd:20 | Hasat çıktısı; doyma değeri 12 puan (yukarıda). |
| Tarım | CROPS.berry_bush.yield_min | 2 | adet | tarim_balance.gd:21 | En kötü hasat 24 doyma puanı = günlük ihtiyacın %12'si. |
| Tarım | CROPS.berry_bush.yield_max | 3 | adet | tarim_balance.gd:21 | En iyi hasat 36 puan = günlük ihtiyacın %18'i. Tek tarla kimseyi doyurmaz; 6-8 tarla ister. |
| Tarım | TILLED_COLOR | (0.36, 0.24, 0.13) | renk | tarim_balance.gd:26 | Sürülü kuru toprak rengi. |
| Tarım | TILLED_WET_COLOR | (0.25, 0.165, 0.10) | renk | tarim_balance.gd:27 | Sulanmış toprak (belirgin koyu) — sulandı mı sorusunun görsel cevabı. |
| Tarım | TILLED_TOP | -0.03 | metre | tarim_balance.gd:28 | Tarla zeminden 3 cm çukur; hafif kabartma hissi. |
| Tarım | CROP_TINT | (0.62, 0.70, 0.56) | çarpan | tarim_balance.gd:32 | Meshy bitki dokuları çok açık geliyor; albedo bu çarpanla sahne paletine çekiliyor. 1.0 = dokunma. |
| Tarım | SFX | 5 kanca | sözlük | tarim_balance.gd:35 | Ses ADLARI hazır, çalar YOK — veri şimdilik atıl. |

## ÖZET: BİR OYUN GÜNÜ NE İSTİYOR

Bir tam gün 930 gerçek saniye (15,5 dk) ve açlık saniyede 0,21 eridiği için
**gün başına 195 doyma puanı** gerekiyor; sürekli koşup kazan biri için
**244 puan**.

- **Öğün sayısı:** Bir "öğün" = uyarı eşiğinden (30) tam bara (100) çıkmak =
  70 puan. Buna göre **günde ~3 öğün** (dinlenirken 2,8; eforda 3,5).
- **Susuzluk daha sık:** Bir yudum 35 puan, gün 279 puan istiyor →
  **günde ~8 yudum**. Yani su, yemekten iki kat sık ilgi istiyor;
  oyunun asıl ritmi su kenarına gidiş-geliş üzerine kurulu.

**Hangi yiyecek kaç oyun saati idare eder** (24 saatlik gün varsayımıyla):

| Yiyecek | Doyma | İdare süresi | Günde kaç adet |
|---|---|---|---|
| Pişmiş et | 40 | **4,9 saat** | ~5 |
| Çiğ et | 15 | 1,8 saat | ~13 |
| Meyve | 12 | 1,5 saat | ~16 |
| Mantar | 10 | 1,2 saat | ~20 |
| (tam bar) | 100 | 12,3 saat | — |
| (bir yudum su) | 35 | 3,0 saat | ~8 |

Okunuşu: **pişmiş et tek başına günü çıkarabilen tek yiyecek** (5 adet =
1 gün). Toplayıcılıkla yaşamak günde 16-20 parça ister, yani neredeyse
sürekli toplama. Tarım ise şu an zayıf: bir berry hasadı (2-3 meyve)
günlük ihtiyacın ancak **%12-18'i**, üstelik 2 gün ve düzenli sulama
istiyor — kendine yeten bir tarla için 6-8 parsel gerekiyor.

## DENETİM NOTLARI (kod değiştirilmedi)

1. **Çift MAX tanımı:** `HUNGER_MAX`/`HEALTH_MAX` hem `survival_balance.gd`
   hem `hunger.gd`/`health.gd` içinde 100 olarak duruyor. Şu an tutarlı ama
   tek yerden değişmez.
2. **Zırh sayıları koda gömülü:** `health.gd:16,18` içindeki 0.6 ve 0.85
   denge dosyasında değil; "kod içinde sabit YOK" kuralının tek istisnası.
3. **Susuzluk kendi süresini kendi işletiyor:** `thirst.gd` kendi
   `_process`'inde eriyor ve `DECAY_PER_SECOND` orada tanımlı; açlıkta
   olduğu gibi efor çarpanı, uyarı eşiği veya cana bağlanma YOK.
   Susuzluk sıfırlansa bile ölüm gelmiyor.
4. **Susuzluk/açlık yavaşlatması 3D'de yok:** `player.gd:81-84` (2D)
   açlıkta 0,5 ve susuzlukta 0,6 hız çarpanı uyguluyor; `player3d.gd`
   içinde karşılığı yok. 3D'de aç/susuz kalmanın tek somut sonucu açlık
   üzerinden gelen can erimesi.
5. **Bulantı cezası neredeyse yok:** 5 sn × 0,21 × (2−1) = **1,1 puan**.
   Çiğ eti caydırması beklenen mekanik pratikte etkisiz.
