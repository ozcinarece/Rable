# RAPOR — Hasat Animasyonu: "Sallan, Fırla, Uç" (hasat-anim)

Hasat artık anlık değil; ~0.9 sn'lik üç aşamalı sunum. MANTIK
DEĞİŞMEDİ: verim/tohum iadesi/bonus aynı satırlarda duruyor; hızlı
test katmanı (RABLE_TEST_LEVEL=hizli) determinizm için eski anlık
yolu kullanıyor. Oyuncu animasyon boyunca BLOKLANMAZ (async akış;
uçuş hedefi her karede yeniden örneklenir — yürürken emilir). Tüm
süreler/eğriler `hasat_anim_balance.gd`'de.

## Aşamalar

1. **SALLAN (0.15 sn)**: bitki kökünden 2 kez sağa-sola, sönümlü
   (±8°, sönüm 0.55). Çok parçalı modellerde kompozisyon birlikte.
2. **FIRLA + POP (0.3 sn)**: her item rastgele yönde parabol
   (tepe 0.6 m, mesafe 0.5-1 hücre, havada 1 tur dönüş, tek sekme);
   bitki %115 şişip ease-in ile %0'a çöker ("pop"); 4-6 yaprak
   kırpığı (bitki renginde) + toprak pufu; tümsek plot_changed'den
   geri gelir.
3. **UÇ (0.4 sn)**: yerde 0.25 sn bekleyip oyuncuya kavisle uçar,
   item başına 0.05 sn ardışık ritim. Emilişte: envanter + HUD sayaç
   zıplaması (fly_pickup) + minik parçacık pop + `harvest_pop` sfx
   kancası (dosya-bekler). Envanter doluysa item mevcut yer-eşyası
   sistemine düşer (kayıp yok). Mıknatıs notu: oyunda otomatik
   mıknatıs YOKTU (toplama dokunuşla) — UÇ aşaması hasat ürünleri
   için bu boşluğu kavis eğrisiyle dolduruyor; ileride genel mıknatıs
   gelirse aynı eğriye bağlanır.

## Ürün kişilikleri (veride)

- **KABAK**: fırlamaz — yerinde tombul squash zıplaması, oyuncuya
  1.6x yavaş uçar (ağırlık hissi).
- **KOROTU**: fırlama anında OmniLight söner (korotu-isik kuralı,
  tarama tazelenir) + 2-3 turkuaz veda zerresi yukarı süzülüp erir.
- **BUĞDAY**: sap-sap dalga (0.03 sn) kancası DOSYA-BEKLER — v2
  modeli TEK mesh olduğundan sap başına animasyon mümkün değil;
  ayrık sap düğümlü model gelirse `KISILIK.golden_wheat.sap_dalga_sn`
  bağlanır. Şimdilik buğday genel akışı kullanıyor.

## Kurallar

- Çoklu hasat çakışmaz: her hücre kendi async akışını yerel durumla
  oynar (paylaşılan sayaç yok).
- Kalite Düşük: parçacıklar kapalı (perf tier "particles") + süreler
  yarıya (DUSUK_SURE_CARPAN 0.5).
- Tween disiplinli: hepsi ilgili düğüme bağlı — düğüm silinirse tween
  ölür (devrilme-tweeni dersinin uygulaması).

## Stres testi (dürüst not)

6 hücre eş zamanlı hasat, llvmpipe yazılım rasterizer'da: 0.6 FPS
(sahne tabanı ~1.5). Yazılım rasterizer parçacık + 12 uçan item'ı
CPU'da çiziyor — GPU'lu cihazda bu yük önemsiz beklenir ama mobil
doğrulama perf aşama 3 cihaz turunda. Kalite Düşük sigortası
(parçacıksız + yarı süre) şimdiden devrede.

## Teslimler

- `hasat_uclu.gif` — berry → kabak → buğday ardışık hasat (50 kare,
  yavaşlatılmış çekim: Engine.time_scale ile animasyon gerçek kare
  hızından bağımsız örneklendi).
- `korotu_sonus.gif` + `korotu_sonus_oncesi/sonrasi.png` — gece:
  ışığın sönüşü + veda zerreleri.
- `hasat_stres.png` — 6'lı eş zamanlı hasat anı.

FARMTEST2 + tam hızlı test yeşil (anlık yol determinizmi korunuyor).
