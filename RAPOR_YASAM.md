# CAN + AÇLIK + YEMEK DÖNGÜSÜ — Uygulama Raporu

Otonom mod. Branch: `hayatta-kalma` (base-fonksiyonlari üstüne).
Kaynaklar: GAME_DESIGN.md (yiyecekler), UI_DESIGN.md 4.1/4.5, BASE_SAVUNMA.md
(Ocak pişirme, yatak set_spawn). Yaratık kodu YOK.

## Kararlar (muhafazakâr; gerekçeli)

- **Health/Hunger autoload'ları KORUNDU; PlayerStats onların ÜSTÜNDE
  koordinatör.** Doküman "tek merkezi script" istiyor. Health/Hunger/Thirst
  autoload'ları HUD'a, kayda ve birçok yere bağlı (Health.damage zırh mantığı,
  save/load). Bunları söküp tek sınıfa gömmek riskli (regresyon). Karar:
  **mantık ve TÜM sayılar tek yerde** (`player_stats.gd` + `survival_balance.gd`);
  Health/Hunger sadece **değer + sinyal deposu** oldu (Hunger'ın self-decay'i
  kaldırıldı, PlayerStats sürüyor). Böylece "tek merkez" + "kod içinde sabit
  yok" sağlanır, mevcut UI/kayıt bozulmaz.
- **berry = mevcut `meyve`.** Oyun Türkçe id'ler kullanıyor (meyve). GAME_DESIGN
  İngilizce id (berry) — eşleştirildi. `cig_et`=raw_meat, `pismis_et`=cooked_meat
  yeni eklendi.
- **`cig_et` (çiğ et) kaynağı = hayvan (yaratık fazı).** Şu an dünyada hayvan
  yok. Pişirme tarifi + yeme + bulantı sistemi HAZIR ve CI ile doğrulandı;
  çiğ etin dünya kaynağı yaratık göreviyle gelecek. **`meyve` ile can/açlık/
  ölüm döngüsü ŞİMDİ tam oynanabilir.**
- **Efor = koşma + alet sallama** (`player.is_exerting()`). Açlık eforla
  %25 hızlanır (tek çarpan, veri).
- **Ölüm TÜM sıfır-can durumlarını kapsar** (açlık erimesi VEYA savaş):
  `_tick_health` her kare `Health<=0` kontrolü + `Health.died` sinyali bağlı.
- **Envanter ölümde KORUNUR** (v1). `DROP_ITEMS_ON_DEATH` denge verisinde
  kapalı bayrak — ileride açılabilir.
- **Pişirme = mevcut tarif/istasyon sistemi.** Yeni sistem icat edilmedi:
  `crafting.gd` istasyon kapısı genelleştirildi (`"ocak"`→`near_hearth`,
  diğerleri→`near_station`). "Kamp ateşi ve Ocak" → şimdilik **Ocak** pişirme
  istasyonu (mevcut yapı); ayrı kamp ateşi cook-station'ı ileride eklenebilir.
- **Yeme = ALET_SISTEMI eylem çerçevesi.** ~1 sn "tüketme" pozu (üç faz),
  hareket yavaşlar, etki strike anında. Tam "iptal" yerine hareket-devam
  (sadeleştirme).

## Aşama aşama ne yapıldı

**Aşama 1 — Temel istatistikler.** `survival_balance.gd` (TÜM sayılar).
`player_stats.gd` autoload: açlık azalır (efor 1.25x + bulantı 2x), eşik<30
uyarı sinyali (HUD nabız), açlık 0→can erir, açlık>70→can yenilenir. Hunger
self-decay kaldırıldı. `player.is_exerting()`, world3d effort bağlama +
`respawn_player`. HUD barları zaten gerçek veriye bağlıydı; açlık warning nabzı
+ Ye butonu edible'a göre + reset.

**Aşama 2 — Yeme.** `cig_et`/`pismis_et` item+ikon. Doyma değerleri veride.
HUD "Ye" (hızlı + bilgi şeridi) → `eat_requested`. world3d `_try_eat`:
1 adet düşer → ~1 sn tüketme pozu (hareket yavaşlar) → strike'ta doyma + pop.
Çiğ et %20 mide bulantısı (5 sn açlık 2x).

**Aşama 3 — Pişirme.** "Pişirme" kategorisi + `pismis_et` tarifi (cig_et→,
station "ocak"). `crafting.gd` istasyon kapısı genelleştirildi. HUD kartı
"Ocak yanında ✓/gerekli" gösterir. Bıçak "yemek hazırlama" TODO.

**Aşama 4 — Ölüm ve doğuş.** Can 0 → kısa kararma (HUD siyah geçiş) → yatak
doğuş noktası (set_spawn) ya da harita başı; can 50 / açlık 50. Envanter korunur.
Ölüm sayacı `death_count` (kayıt/yükleme). `Health.died` bağlı (combat de).

**Aşama 5 — Cila.** Yeme/bulantı floating text (UI_DESIGN 4.5); açlık eşiği
nabzı; düşük-can **çok hafif** kırmızı vinyet (0 canda ~0.12 alfa, mobilde
rahatsız etmez); ölüm/yeme ses kancaları (`_play_sfx`, dosya yoksa sessiz).
CI self-test + `3d_yasam.png` karesi.

## DENGE VERİSİ — TÜM SAYILAR (`scripts/survival_balance.gd`, elle oyna)
| Sabit | Değer | Anlam |
|---|---|---|
| HUNGER_MAX | 100 | açlık tavanı |
| HUNGER_DECAY_PER_SEC | 0.21 | ~8 dk'da 100→0 (dinlenirken) |
| EFFORT_HUNGER_MULT | 1.25 | koşma/kazı açlığı %25 hızlandırır |
| HUNGER_WARN_THRESHOLD | 30 | altında "acıktın" uyarısı (nabız) |
| HEALTH_MAX | 100 | can tavanı |
| STARVE_HEALTH_LOSS_PER_SEC | 0.5 | açlık 0 iken saniyede can erir |
| REGEN_HUNGER_THRESHOLD | 70 | üstünde can yenilenir |
| HEALTH_REGEN_PER_SEC | 1.0 | iyi beslenince saniyede +can |
| RESPAWN_HEALTH | 50 | doğuşta can |
| RESPAWN_HUNGER | 50 | doğuşta açlık |
| DROP_ITEMS_ON_DEATH | false | ölümde eşya düşürme (kapalı) |
| FOOD_SATIATION.meyve | 12 | berry doyma |
| FOOD_SATIATION.mantar | 10 | mantar doyma |
| FOOD_SATIATION.cig_et | 15 | çiğ et doyma |
| FOOD_SATIATION.pismis_et | 40 | pişmiş et doyma |
| NAUSEA_CHANCE | 0.20 | çiğ et bulantı şansı |
| NAUSEA_DURATION | 5.0 | bulantı süresi (sn) |
| NAUSEA_HUNGER_MULT | 2.0 | bulantıda açlık çarpanı |
| EAT_DURATION | 1.0 | yeme eylemi süresi (sn) |

## CI doğrulaması (self-test)
`EATTEST` (doyma + edible), `STARVETEST` (açlık0→can düşer),
`DEATHTEST` (sayaç++, can/açlık 50, envanter korundu), `COOKTEST`
(ocaksız=0 / ocaklı=2). `3d_yasam.png` düşük bar + vinyet.

## SENİN İÇİN TEST SENARYOSU (sırayla)
1. **Aç kal:** bir süre oyna (koş → daha hızlı acıkır). Açlık **30 altına**
   inince mide barı **uyarı nabzı** atar.
2. **Açlık 0:** açlık sıfırlanınca **can erimeye** başlar (kalp barı düşer,
   ekranda **çok hafif kırmızı vinyet**).
3. **Berry ye:** envanterde meyveye dokun → **Ye** → ~1 sn yeme (hareket
   yavaşlar) → açlık +12, "+12 doyma" pop.
4. **İyi beslen:** açlık **70 üstüne** çıkınca can **yavaşça yenilenir**.
5. **(Yaratık fazından sonra) Çiğ et ye** → bazen "Midem bulandı" (5 sn açlık
   2x hızlı) — pişmiş et yemeye teşvik.
6. **Ocak kur, yanına git** → craft panelinde **Pişirme** sekmesi; **cig_et →
   pismis_et** tarifi "Ocak yanında ✓". Pişir, ye → açlık +40.
7. **Öl:** açlığı sıfırda tut, can bitene kadar bekle → **kısa kararma** →
   **yatakta** (yoksa harita başında) yeniden doğ, can 50 / açlık 50.
   **Envanterin durur** (eşya kaybı yok).
8. **Yeni yatak** yap → doğuş noktası oraya taşınır (base sisteminden).
9. **Oyunu kapat-aç** → can/açlık ve **ölüm sayısı** korunur.

## Bilinen sorunlar / TODO'lar
- **Çiğ et dünya kaynağı yok** (hayvan = yaratık fazı). Yeme/bulantı/pişirme
  hazır; `cig_et` şimdilik yalnız CI/geliştirici yoluyla elde edilir.
- **Yeme tam "iptal edilebilir" değil** — eylem başlayınca tamamlanır (hareket
  yavaş devam eder). Gerçek iptal ileride.
- **Kamp ateşi ayrı cook-station değil** — pişirme Ocak'ta. Meşale ışık-only.
- **Uyku/gece atlama sınırı** (ilk 2-3 gece) hâlâ TODO (gündüz/gece + yaratık).
- **Susuzluk (Thirst)** bu görevin dışında — kendi self-decay'iyle çalışmaya
  devam ediyor (dokunulmadı).
- **Bıçak "yemek hazırlama"** tarif çeşidi artınca bağlanacak (recipes'te
  TODO işaretli).
