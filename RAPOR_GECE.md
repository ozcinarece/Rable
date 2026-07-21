# GÜNDÜZ/GECE DÖNGÜSÜ — Uygulama Raporu

Otonom mod. Branch: `gunduz-gece` (kayit-sistemi üstüne). Yaratık kodu YOK —
yalnız sinyal kancaları bırakıldı.

## Karar: TimeManager = mevcut DayNight autoload'u genişletildi
Ayrı bir "TimeManager" autoload'u yaratmak yerine, mevcut **DayNight**
autoload'u dört fazlı zaman yöneticisine dönüştürüldü. Gerekçe: DayNight zaten
kayıt (SaveManager), HUD ve 2D world.gd'ye bağlı; paralel bir sınıf bunları
çatallar. Geriye uyum API'si (day, is_night, elapsed, DAY/NIGHT_SECONDS,
sleep_to_morning, load_state) korundu → hiçbir şey bozulmadı.

## Aşama 1 — Zaman sistemi
Dört faz: **dawn → day → dusk → night → (yeni gün) dawn**. Süreler
`TimeBalance`'ta. Sinyaller: `dawn_started` / `day_started` / `dusk_started` /
`night_started` / `changed`. Yardımcılar: `day_fraction()` (0..1, güneş açısı),
`phase_progress()`, `cycle_time()`, `time_until_night()`. Kayıt: `to_save_data`
faz tabanlı ({day, phase, elapsed}) — SaveManager zaten DayNight'ı topluyordu;
round-trip testinde saat korunur.

## Aşama 2 — Görsel döngü
`_update_daylight()` her kare çalışır; faz sınırı renk/enerji **anahtarları**
`phase_progress` ile YUMUŞAK harmanlanır (anlık atlama yok):
| Faz sınırı | Güneş rengi | Güneş E | Ambient | Gök üst | Gök ufuk |
|---|---|---|---|---|---|
| dawn (şafak, dim→) | (0.62,0.55,0.72) | 0.38 | 0.36 | (0.24,0.26,0.42) | (0.72,0.55,0.52) |
| day (sabah/gündüz) | (1.0,0.90,0.74) | 1.00 | 0.66 | (0.48,0.70,0.95) | (0.98,0.90,0.76) |
| dusk (geç gündüz) | (1.0,0.95,0.85) | 1.05 | 0.72 | (0.44,0.69,0.94) | (0.95,0.93,0.82) |
| night (lavanta-lacivert) | (0.52,0.52,0.78) | 0.30 | 0.32 | (0.16,0.18,0.34) | (0.40,0.34,0.52) |
Her faz KENDİ başından SONRAKİ fazın başına lerp eder (dawn→day→dusk→night→
dawn). Gece **zifiri değil** (okunur, UI_DESIGN gece paleti). Güneş gün boyu
süpürür (gölgeler kayar). WorldEnvironment ambient + ProceduralSky ufuk/üst
renkleri de eğriyle geçer. Gece kenar **vinyeti** `nightness` ile yumuşak
(çok hafif lavanta, tavan 0.34 alfa). Meşale/Ocak ışıkları (mevcut bütçe)
gece anlam kazanır.
**Performans:** gölge mesafesi 40 m (değişmedi); gece enerjisi düşük →
gölgeler zaten sönük; per-kare maliyet birkaç renk lerp'i (ucuz).

## Aşama 3 — HUD ve ritim
- **Gün/saat pill'i:** "Gün N" + güneş/ay noktası + **gün içi ilerleme**
  (minik dolum, `day_fraction`).
- **Geceye son 1 dk** (`time_until_night ≤ NIGHT_WARN_LEAD`): pill warning
  rengi + yumuşak nabız + tek satır **"Gece yaklaşıyor"** (2 sn).
- **Gece başı:** ortada **"Gece N"** pill'i 2 sn. ("— Geliyorlar" YARATIKLAR
  gelince eklenecek — şimdilik sadece "Gece N").
- **Sabah:** "Gün N" pill'i + **`_morning_reward()` BOŞ kanca** (B kısmı
  hasarsız gece → Ocak bonusu bağlayacak — TODO).

## Aşama 4 — Uyku (BASE_SAVUNMA 14.2)
Yatak **gece** → kararma (yumuşak siyah geçiş, sabah kararma ALTINDA uygulanır)
→ sabaha atla (+gün) + hafif iyileş (can +20, açlık +15). **Kural:** yalnız ilk
`SLEEP_MAX_NIGHT`=3 gece uyunur; 4. gece ve sonrası **"Uyuyamazsın..."**.
Gündüz yatak = **doğuş noktası atar** (14.2 "ev yap"); gündüz uyku yok.

## DENGE SAYILARI (`scripts/time_balance.gd`, elle oyna)
| Sabit | Değer | Anlam |
|---|---|---|
| DAWN_SECONDS | 45 | şafak geçişi (sn) |
| DAY_SECONDS | 600 | gündüz (10 dk) |
| DUSK_SECONDS | 45 | akşam geçişi |
| NIGHT_SECONDS | 240 | gece (4 dk) |
| CYCLE_SECONDS | 930 | tam gün (~15.5 dk) |
| NIGHT_WARN_LEAD | 60 | geceye son N sn uyarı |
| NIGHT_PILL_SECONDS | 2 | "Gece N" pill süresi |
| SLEEP_MAX_NIGHT | 3 | uyunabilir gece sayısı |
| SLEEP_HEAL_HEALTH | 20 | uykuda can |
| SLEEP_HEAL_HUNGER | 15 | uykuda açlık |

## YARATIK SİSTEMİNE BIRAKILAN KANCALAR (B kısmı — kod YOK)
- **`DayNight.night_started`** → gece yaratık dalgası buraya bağlanacak.
- **`DayNight.dawn_started`** → sabah; hasarsız gece kontrolü.
- **`Hud._morning_reward()`** → BOŞ; Ocak sabah bonusu (BASE_SAVUNMA 14.9).
- **Gece pill'i** "Gece N" → "Gece N — Geliyorlar..." (yaratık metni) genişler.
- **`DayNight.get_hearth`** (base'te hazır) + `is_night` → gece hedefi.

## CI doğrulaması
`TIMETEST: faz + gün-oranı (gündüz<gece frac) + gece_mi`, `SLEEPTEST:
gece2_uyunur=true → uyudu gün=3 → gece5_uyunur=false`, `SAVELOAD: PASS`
(saat=phase+elapsed round-trip korunur). Kareler: `3d_gece.png` (gece
lavanta tonu), `3d.png` (gündüz).

## TEST SENARYOSU (senin için)
1. **Tam gün döngüsü izle:** güneş döner, renkler şafak turuncu → öğle parlak
   → akşam amber → gece lavanta-lacivert (yumuşak, zifiri değil). Pill "Gün N"
   dolum bar ilerler.
2. **Geceye son 1 dk:** pill sararır + nabız + "Gece yaklaşıyor". Gece başında
   ortada "Gece N".
3. **Gece meşale/Ocak yak:** ışıklar belirginleşir; kenar hafif lavanta vinyet.
4. **Uyu (ilk 3 gece):** yatağa gece dokun → kararma → "Sabah oldu!" +gün +can/
   açlık. Pill "Gün N".
5. **4. gece uyuma reddi:** 4. gecede yatağa dokun → "Uyuyamazsın...".
6. **Gündüz yatak:** dokun → "Ev burası oldu" (doğuş noktası; uyku yok).
7. **Kaydet-yükle:** kapat-aç → **saat/faz ve gün** korunur (Devam Et).

## Bilinen sınırlar / TODO
- **Sabah bonusu** boş kanca (Ocak/B kısmı).
- **"Geliyorlar" metni** ve gece dalgası yaratık göreviyle.
- **Güneş açısı** basit süpürme (gerçek gökyüzü güneş diski hareketi değil).
- **2D world.gd** eski DayNight API'siyle çalışmaya devam eder (dokunulmadı).
