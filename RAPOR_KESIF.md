# RAPOR — KEŞİF VE KOR YOLU (Bölüm 16, branch: kesif)

Altı aşama tek pakette: halka+sis+ışık kapısı, kor taşları, sefer/kamp
+ Ocak simülasyonu, uyuyanlar, uzak tehditler, ödüller+kayıt+performans.
TÜM sayılar `scripts/kesif_balance.gd`'de — kod dokunmadan ayarlanır.

## KEŞİF TARAMASI — TODO KANCALARI (görevin istediği liste)

Görev "mevcut TODO kancalarını tara" dedi. Bulgu: **anılan kancaların
hiçbiri kodda yoktu.** `is_banked`, "alev rengi sayacı", "hikâye katman
tetikleri 3-11" için tek iz `farming.gd:99`'daki "IŞIK KURALI BURAYA
GELECEK (hikaye fazı)" yorumuydu. Ön okuma listesindeki **HIKAYE.md ve
YARATIK_SISTEMI.md repoda yok** (BASE_SAVUNMA.md var). Bu görev o
kancaları İLK KEZ yarattı; hikâye fazı geldiğinde bağlanacaklar:

| Kanca | Nerede | Ne bekliyor |
|---|---|---|
| Alev rengi ilerlemesi | `_update_alev_rengi()` — Ocak ışığı sarı→kor kızılı | HIKAYE 7 tam eğrisi |
| Nefes (Harla/Közle) | `set_ocak_nefes()` + `NEFES_CARPAN` + kayıt | HIKAYE 9 + UI seçimi |
| Taş bilgisi düğümleri | `tas_bilgisi_1..3` (1./3./5. ana taşta belirir) | günlük/yazıt içeriği |
| Mühür Çağı bonusu | `muhur_bonusu_aktif()` + `YANC_SABAH_CARPAN` | sabah ekonomisi işi (14.9) |
| Ana Ocak ön koşulu | `ana_ocak_hazir()` (6 ana taş) | final fazı |
| yanB günlük sayfaları | yakma ödülünde yorum | HIKAYE.md |
| Işık kuralı (tarım) | farming.gd yorumu — dokunulmadı | hikaye fazı |

## 16.1-16.2 HALKA + SİS + IŞIK KAPISI

- Halka = Ocak'tan Öklid mesafe; sınırlar `RING_R = [16, 30, 46]`
  (128×128 haritada sıkışık — **gerçek genişletme harita-master işi**,
  yarıçaplar o gün SADECE veriden değişir).
- Sis: halka başına `[0, .25, .6, 1.0]`; gereken ışık `[—, K1 meşale,
  K2 kor feneri, K3 köz kabı]` — envanterden okunur.
- **Kapı = karanlık, duvar değil:** eksik ışıkla vinyet büyür
  (`VINYET_ACIK_BASI` 0.55/kademe, tavan 0.92 — ekran hiç tam kapanmaz),
  hedefleme yalnız ÖN hücreye iner, kamp kurulamaz, uyuyanlar
  fark edilmez. Girmek serbest.
- Görsel (mobil): HUD vinyet dokusu + tam ekran renk soğuması + oyuncuyu
  izleyen TEK yarı saydam alçak sis düzlemi. Parçacık yok.
- Tarifler CANLI katalogda: `cam` (kum 2+kömür 1, ocakta), `kor_feneri`
  (cam 2+bakır 1+ip 1), `koz_kabi` (bakır 2+cam 1). **Sapma:** 16.1
  "bakır külçe/metal parça" der; canlı katalogda ikisi de yok — pompa/
  vana emsaline uyularak `bakir` kullanıldı (muhafazakâr, geri alınır).
- Araştırma: `fener_dugumu` (gizli; ilk cam toplanınca belirir) →
  `koz_kabi_dugumu`. Cam+bakır zinciri gerçek kapı: fırın+madencilik.

## 16.3 KOR TAŞLARI

- 6 ana taş Ocak'tan **yay** çizer (açı/yarıçap veri: `TAS_ANA`),
  3 yan taş sapmış noktalarda. Hücre spiral aramayla en yakın
  yürünebilir karaya oturur; taşlar kalıcı engel.
- Yakma bedeli: **1 yol koru** + artan öz (`TAS_BEDEL`: 1,1,2,2,3,3).
  Halka 2+ taşlarına köz kabı ŞART (`KOZ_SART_HALKA`); Halka 1 için
  meşale koru taşır. Yol koru Ocak'a dokununca alınır.
- Yanan taş: **kalıcı** sis temizliği (r=11, `_temiz_bolgeler`),
  canlanma parçacıkları, araştırmaya taş bilgisi, gece sertleşmesi
  (+%8/ana taş — HIKAYE 8 görünürlük bedeli), alev rengi ilerler.
- Görsel borç: taş = koyu silindir + yanınca kor emissive
  (`kor_tasi.glb` gelirse aynı kancadan takılır).

## 16.4 SEFER + KAMP + OCAK SİMÜLASYONU

- Yol koru yere konunca **mini kamp ateşi**: ışık çemberi + pişirme
  istasyonu + **kayıt noktası** (koyunca otomatik kayıt). Işık
  kapısında kamp kurulamaz.
- **SAVUNMA PUANI FORMÜLÜ** (görevin istediği döküm):
  `puan = Σ(yapı_hp × ağırlık) + su_hendeği_hücresi × 3`
  Ağırlıklar: ahşap duvar .10, taş duvar .14, kapı .08, tuzak .20,
  kazık .15, platform .06, meşale .04. Alan: Ocak çevresi r=10.
  `dalga = gece × 6 × sertleşme × nefes(harla 1.0 / közle 0.65)`
  `hasar = max(0, dalga − puan × 0.8)` — hasar önce en dıştaki
  savunma yapılarını yer (gerçekten hp düşer/yıkılır), artan Ocak'a.
- Sonuç **sabah raporu paneli** (kapatana kadar durur): "Ocak dayandı…"
  / "Ocak hasarlı! Eve dön."
- Ateşli kamp gecesi: %60 şansla 2-4 yaratık çekimi. Ateşsiz: görünmez
  ama üşürsün — şafakta −8 hp, −12 açlık (Harla/Közle ikilemi).

## 16.5 UYUYANLAR (stealth)

- 5 küme × 3-5 taşlaşmış Külgezer, Halka 2+, küme ortasında öz yığını
  (risk gönüllü). Yavaş yürüyüş güvenli; **koşmak/alet sallamak,
  kazma-kesme-kazı gürültüsü (r=5), üstlerine yürümek, PARLAK ışık
  (K2+, kısık değil)** uyandırır: gözler ışır + "Kabuk çatlıyor..."
  → 1.5 sn → heykeller gerçek yaratığa dönüşür.
- 12 hücre uzaklaşınca sağ kalanlar yeniden taşlaşır; hepsi öldüyse
  küme boş kalır. **Feneri Kıs butonu** (yalnız K2+ ışıkta görünür):
  kısıkken vinyet biraz büyür ama uyandırmazsın.
- HUD nabzı: yaklaştıkça ekran kenarında ince kırmızı kalp atışı.
- Kayıtta uyanık küme "uyuyor" yazılır — kayıt-yükle stealth kaçışı
  olmasın (muhafazakâr, bilinçli).

## 16.6 UZAK TEHDİTLER

Üçü de mevcut AI iskeletinin varyantı (stat + "uzak" metası; take_hit/
öz aynen). `first_night = 999`: gece dalgası havuzuna GİRMEZLER —
bunlar bölge tehdidi, base baskını değil; oyuncuyu hedeflerler.

- **Sis Sürüsü** (H2+): 3-5'li, hp 3, hızlı. **Fener Avcısı** (H2+):
  yalnız parlak ışık varken doğar; ışık kısılınca erir — ışık
  yönetiminin düşmanı. **Çatlak Dev** (H3): hp 60, struct_mult 4.
- **Kül Fırtınası** (H3): görüş zorla kapanır (vinyet .95; kamp
  ateşi/Ocak yanında yarıya iner), 35 sn, en sık 150 sn'de bir.
- **Damar Çatlağı** (H3): 6 ışık sızan yarık; 7 hücre içindeki ortam
  yaratığı yarığa yönelir — akıllı oyuncu tuzak olarak kullanır.
- Ortam doğurucu 12 sn'de bir zar atar; temizlenmiş bölge Yuva
  kurallarına döner (doğurucu sussar). Uzaklaşan ortam yaratığı erir.

## 16.7 ÖDÜLLER

- Ana taşlar: temizlik + taş bilgisi + alev rengi + günlük (hikâye borcu).
- yanA: fener/köz düğümleri BEDAVA açılır ("eski usta tarifleri"nin
  bugünkü dürüst hali; ikisi de açıksa öz). yanB: öz ×8 (+sayfalar
  hikâye borcu). yanC: KALICI sabah ekonomisi +%10 —
  `muhur_bonusu_aktif()` taş durumundan türetilir, ayrı kayıt yok.

## KAYIT

"kesif" paketi (dünya kaydında): taş hücre+yanık durumu, uyuyan küme
boş/uyuyor, fener kısık, nefes. Sis/halka/temiz bölgeler taş
durumundan türetilir. `_recompute_solids` taşları engel sayar.
Bilinen sınır: sefer gecesi ortasında çıkılırsa sabah raporu kaybolur
(rapor türetilmiş veridir, tehlikeli değil).

## PERFORMANS (KESIFPERF — hızlı CI'da her push)

CI yazılım rasterizasyonunda FPS sabit; dürüst metrikler: keşif
döngüsünün CPU süresi (0.2 sn'de bir koşar; bekçi: >2 ms kırmızı),
dalga simülasyonu süresi (gecede BİR kez; bekçi >5 ms) ve Bölüm 16'nın
eklediği düğüm sayısı (~35: 9 taş + ~20 heykel + 6 yarık + 1 sis
düzlemi — hepsi gölgesiz, MultiMesh gerektirmeyecek kadar az).
Güncel sayılar CI logundaki `KESIFPERF:` satırında.

## TEST SENARYOSU (görevin istediği akış — elle oynama rehberi)

1. Meşalesiz/fenersiz Halka 2'ye yürü (kamptan ~35 hücre): ekran
   kenarları kapanır, hedefleme yalnız öne iner, "kamp kurulamaz".
2. Kum topla (göl kenarı) → ocakta cam pişir → cam envanterde:
   araştırmada "???" fener düğümü belirir → bakırla araştır →
   tezgahta kor feneri üret. Halka 2'de görüş açılır.
3. Uyuyan kümesine YAVAŞ yaklaş (nabız başlar) → yanından geç →
   güvenli. Koşarak dön → gözler ışır, 1.5 sn sonra saldırı → kaç
   (12 hücre) → yeniden taşlaşırlar.
4. Ocak'a dokun (meşale/köz kabıyla) → yol koru al → ana taş 1'e git
   → öz bedelini öde → yak → bölge kalıcı canlanır, gece dalgası
   %8 sertleşir, Ocak alevi kızıllaşır.
5. `set_ocak_nefes("kozle")` (UI hikâye fazında) → uzağa sefer →
   gece: sabah raporu paneli. Kamp ateşi yak → gece 2-4 çekim
   karşılaşması; ateşsiz gece → sabah −8 hp/−12 açlık.
6. Fener parlakken Halka 2'de bekle → Fener Avcısı gelebilir →
   feneri kıs → ilgisini yitirip erir.
7. Halka 3'te dolaş: Kül Fırtınası görüşü kapatır (kamp ateşine
   sığın: yarıya iner); damar çatlağı yakınına yaratık çek →
   yarığa yönelirler.

Otomatik hali: KESIFTEST + KORTEST + SEFERTEST + UYUTEST + UZAKTEST +
KESIFPERF her push'ta koşar (ci-fast logda satırları görünür).

## GÖRSEL DOĞRULAMA (ağır CI kareleri, docs/screens/)

- `3d_kesif_tas.png`: ana1 kor taşı (koyu silindir) kuş bakışı — NET.
- `3d_kesif_uyuyan.png`: taşlaşmış küme + ortadaki ödül — NET.
- `3d_kesif_sis.png`: ışıksız Halka 2 — **ışık kapısı görünür**: ekran
  kenarları karanlıkla kapanıyor, merkez açık (piksel kanıtı: kenar
  ortası su 60/93/147 → 58/76/105; ilk vinyet dokusu yalnız köşeleri
  kapatıyordu, piksel ölçümüyle yakalanıp genişletildi).
- `3d_kesif_damar.png`: kadraj borcu — çatlak bitki örtüsü altında
  kalabiliyor (varlık kanıtı kesifdbg.txt: 6 görsel). Kare seçimi
  "çevresi en boş çatlak"a çevrildi; bir sonraki ağır koşuda tazelenir.
- `docs/screens/kesifdbg.txt`: her ağır koşuda taş/sis/damar değer
  dökümü (ucuz teşhis kanalı).

## BİLİNEN SORUNLAR / BORÇLAR

- Görsel borç: taş/heykel/yarık placeholder geometri (GLB kancaları
  hazır: kor_tasi, creature_sis_surusu/fener_avcisi/catlak_dev).
- Çatlak Dev'in "kabuğundan ışık sızması" placeholder gövdede yok.
- Nefes seçimi UI'sız (API+kayıt hazır); sabah ekonomisi çarpanı
  okuyucusunu bekliyor (Yaratık Aşama 6).
- Kül Fırtınası "sığınak" tanımı kamp ateşi/Ocak yakını — iç mekan
  tespiti (ev-cati) main'e gelince `is_indoor` da sığınak sayılmalı.
- Halka mesafeleri 128 haritada sıkışık (16.8'in "2-3 gece yürüyüş"
  hissi yok) — harita-master Aşama 0 büyütünce yalnız RING_R değişir.
- HIKAYE.md/YARATIK_SISTEMI.md hâlâ repoda yok; yukarıdaki kanca
  tablosu onları bekliyor.
