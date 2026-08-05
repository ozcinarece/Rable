# RAPOR — Korotu Işık Sistemi (korotu-isik) + golden_wheat bağlama

Korotu artık HAKİKİ ışık kaynağı — hikâyedeki rolü (ışık bitkisi,
fenerlerin yakıtı) oyunda görünür. Tüm sayılar `tarim_balance.gd` +
`perf_balance.gd`'de.

## İki katmanlı ışık

- **EMISSION**: modelin Meshy emissive dokusu kanal olarak kullanılıyor
  — harita yalnız çiçek çanını kaplıyor, sap/yaprak haritada karanlık:
  sızma YOK (kare kanıtı: çan parlar, gövde yeşil kalır). Ton #7FEFE0
  soluk turkuaz (KOROTU_EMISSION). Gündüz 0.4 (fark edilir, bağırmaz),
  gece 1.5 (~3.75x — görev bandı 3-4x). Gece kaynağı tek:
  `_update_water_night` faz değişiminde seçimi tazeler.
- **GERÇEK IŞIK**: her OLGUN korotu'ya gölgesiz OmniLight3D —
  turkuaz-beyaz (0.72,0.97,0.93), menzil 2.5 hücre (Ocak 6.0 /
  meşale 4.5'ten belirgin küçük: bu bir bitki, fener değil), enerji
  gündüz 0 (görünmez), gece 0.85. Gölge KAPALI (mobil kuralı).
- **NEFES**: emission + ışık enerjisi 4 sn'lik sinüsle ±%15 soluk
  alıp veriyor — meşalenin hızlı-titrek ateşinden farklı, sakin
  "canlı organizma" ritmi (`_korotu_process`, her kare; kayıt listesi
  0.5 sn'de bir taranır).

## Evre ve durum kuralları

- Filiz: ortak yeşil filiz (ışıksız). Fide: emission x0.35 (iyice
  soluk), ışık YOK. Işık OLGUNLUKTA doğar — "hasat zamanı = parlama
  zamanı" görsel sinyali.
- Hasat: ürün düğümüyle birlikte OmniLight de gider, hücre karanlığa
  döner (kare 3a/3b aynı açı). Oyuncu ikilemi: hasat mı, fener olarak
  mı bıraksın?
- Yere düşen `korotu_cicek` hafif ışıyan yuvarlak gövde taşır
  (0.45 — ilk deneme 0.9 küre gibi bağırıyordu, kare ile kısıldı).
  Envanter ikonu 2D olduğundan dokunuş yer eşyasında.

## Performans sigortaları

- Aynı anda en fazla **8 OmniLight** (KOROTU_ISIK_MAX): fazlası
  varsa oyuncuya EN YAKIN 8'i yanar, gerisi yalnız emission
  (0.5 sn'lik tarama; 12'lik test tarlasında görsel kanıt kare 1).
- Kalite **Düşük**: OmniLight tamamen kapalı (perf_balance
  `korotu_isik=false`), emission kalır — gece yine görünür (mobil
  sigortası).
- **FPS ölçümü (dürüst not)**: yerel tek ölçüm ortamı xvfb + llvmpipe
  yazılım rasterizer'ı — 12 korotu gece sahnesinde ışıklı da
  emission-only da 1.5 FPS (CPU'ya boğulu; fark ölçüm eşiğinin
  altında). Yani yerel kanıt "8 ışık yazılım rasterizer'da bile ek
  yük göstermedi"; gerçek GPU farkı mobil cihaz ölçümü ister
  (perf aşama 3'ün cihaz turuna not düşüldü). Sigortalar (max 8 +
  Düşük'te kapalı) bu belirsizliğe karşı zaten devrede.

## Sistem çarpışmaları (≥2 sistem kuralı)

- **YARATIK**: ışığı yanan korotu hücreleri `_pos_in_light`'a girdi —
  Işık Kuramı aynı kural setinden işler: %10 yavaşlama (LIGHT_SLOW)
  + çatlak ışıması sönmesi (EMISSION_LIGHT_DIM). Kare 2: yaratık
  halkada, çatlakları sönük.
- **SU**: korotu `warm_lights`'a BİLEREK girmedi — o dizi sıcak
  turuncu yansıma (Ocak/meşale); korotu soğuk ışık. Sudaki turkuaz
  yansıma için `cool_lights` TODO kancası koda not edildi.

## golden_wheat bağlama (ek görev)

- Hücre kompozisyonu doğrulandı: tek GLB'de ~10 ayrık dik sap + koyu
  taban, TEK mesh (taban ayrı parça DEĞİL — gizleme seçeneği yok;
  görsel kontrolde taban tarla karosuyla uyumlu çıktı, kaldı).
- Y-up geldi; doğal boy 0.553 = hedef bandın içi → root_scale 1.0.
  Taban 2 cm gömük. Hücrede rastgele Y-rotasyon (CROP_GLB_YROT —
  kompozisyon yönsüz, tekdüzelik kırılır; evre geçişinde yeniden
  seçilir).
- Fide: %50 ölçek + FIDE_YESIL_TON (0.72,1.0,0.62) albedo kayması —
  genç başak yeşili (kare: buğday gündüz, sağda fideler).
- Doku 2048→1024: dosya 6.5 MB → 0.65 MB; 1525 üçgen. VRAM model
  başına ~4'te 1 (diğer ürünlerle aynı işlem).

## Kareler

1. `korotu_1_gece_tarla.png` — 12 olgun korotu gece; zemine düşen
   turkuaz ışık havuzları (en yakın 8 yanık).
2. `korotu_2_yaratik.png` — yaratık ışık alanında: çatlak ışıması
   sönük (yavaşlama aynı kuralın parçası).
3. `korotu_3a/3b_hasat_once/sonra.png` — aynı açı: hasatla ışığın
   sönüşü, hücre karanlığa döner.
4. `bugday_1_gunduz.png` — olgun sıra + yeşil tonlu fideler.
5. `bugday_2_altin_saat.png` — erken akşam (dusk %20). Not: gün
   eğrisi dusk'ı lavanta geceye lerp'liyor; daha koyu altın anahtar
   istenirse _SKY_KEYS'e ara "golden" anahtarı ayrı küçük görev.

## Emanetler

- cool_lights su yansıması (TODO kanca koda işli).
- Fener yakıtı ekonomisi (korotu → fener) ayrı görev — bu görev
  yalnız ışık kimliğini kurdu.
- Mobil cihazda 8-ışık FPS doğrulaması (perf aşama 3 turuna eklendi).
