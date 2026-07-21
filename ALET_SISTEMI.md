# BÖLÜM 12 — ALET VE SİLAH SİSTEMİ (Etkileşim + Animasyon)

GAME_DESIGN.md doküman ailesinin parçası. Oyuncunun dünyayla tüm fiziksel
teması bu modülden geçer: butonlar, hedefleme, alet eylemleri, silah
hareketleri, animasyon ve his (juice). Yaratıklar EN SON geleceği için
tüm saldırı mekanikleri TEST KUKLASI ile doğrulanır (12.7).

---

## 12.1 GİRDİ MODELİ (mobil öncelikli)

- Sol alt: hareket joystick'i (mevcut).
- Sağ alt: ANA BUTON (büyük, 96px dokunma alanı) — BAĞLAMA DUYARLI:
  ikonu ve işlevi "elindeki alet + baktığın hedef" ikilisinden türer.
  | Elde | Hedef | Buton | Eylem |
  |---|---|---|---|
  | Balta | Ağaç | kes ikonu | Ağaç kesme |
  | Kazma | Kaya/cevher | kaz ikonu | Madencilik |
  | Kürek | Zemin hücresi | kaz ikonu | Kazı (Bölüm 11) |
  | Toprak (item) | Kazılmış/düz hücre | dök ikonu | Yığma |
  | Kova boş | Su hücresi | doldur ikonu | Kova doldurma |
  | Kova dolu | Kazılmış hücre | dök ikonu | Su dökme |
  | Bıçak | Çalı/leş | topla ikonu | Lif/deri |
  | Çekiç | Yapı | tamir/sök ikonu | 12.4'e bak |
  | Herhangi | İstasyon | aç ikonu | İstasyon UI |
  | Herhangi | Yerde item | al ikonu | Toplama |
  | Silah | (hedefsiz de) | saldırı ikonu | Saldırı |
- SALDIRI BUTONU: ana butonun HEMEN ÜSTÜNDE, biraz küçük (72px).
  SADECE elde silah varken görünür (yumuşak fade). Silah yokken alan
  boş — ekran sade kalır.
- Geçerli eylem yokken ana buton soluk (ink_faint) + elindeki aletin
  varsayılan "boşa sallama" eylemi (isabet yoksa hafif whoosh).
- Klavye test eşlemesi: ana buton = E, saldırı = Sol tık.

## 12.2 HEDEFLEME

- Karakterin baktığı yönde kısa menzilli seçim: önünde ~1.6 birim,
  ~90° koni içindeki en yakın etkileşilebilir (ağaç, kaya, hücre,
  istasyon, item, kukla).
- Seçili hedef VURGULANIR: yumuşak kontur/halka, UI_DESIGN success
  renginde; geçersiz hedefte (örn. taş kürek + derin kaya) warning
  rengi + ana butonda kilit rozeti.
- Hücre hedefleme (kürek/kova): karakterin önündeki hücre; dokunmatikte
  isteğe bağlı doğrudan hücreye dokunma da geçerli (mevcut kazı
  etkileşimiyle uyumlu kalın).

## 12.3 EYLEM ÇERÇEVESİ — PROFİL VERİSİ (sistemin kalbi)

Her alet eylemi üç fazlı: HAZIRLIK (windup) → VURUŞ (strike) →
TOPARLANMA (recover). ETKİ (hasar/kazı/toplama) daima VURUŞ anında
uygulanır, buton anında DEĞİL.

Profil verisi (data dosyasında, alet başına):
{ windup, strike, recover (sn), arc_tipi, arc_derece, menzil, etki }

| Alet/Silah | windup | strike | recover | Hareket tarifi |
|---|---|---|---|---|
| Balta | 0.18 | 0.10 | 0.22 | Omuzdan çapraz iniş (sağ üst→sol alt, ~110°) |
| Kazma | 0.22 | 0.10 | 0.26 | Tepeden dikey iniş (~120°), vuruşta minik duraksama |
| Kürek | 0.16 | 0.12 | 0.22 | Öne-aşağı saplama + geriye kaldırıp savurma (toprak fırlatma hissi) |
| Bıçak | 0.08 | 0.06 | 0.12 | Kısa hızlı yatay kesik (~60°) — en seri alet |
| Çekiç | 0.20 | 0.10 | 0.30 | Yandan yatay vuruş (~90°), vuruşta hedef yapıda sarsıntı |
| Sopa | 0.16 | 0.10 | 0.24 | Yatay savurma (~100°) |
| Mızrak (dürtme) | 0.14 | 0.08 | 0.20 | İleri doğru saplama (dönme yok, z-ekseni itiş ~0.7 birim) |
| Kılıç | 0.12 | 0.10 | 0.18 | Yatay kesik (~130°); PEŞ PEŞE basışta 2'li kombo: ters yöne ikinci kesik (recover 0.12'ye düşer) |

- Animasyon PROSEDÜREL: alet, karakter elindeki ToolPivot node'una
  bağlı; fazlar Tween ile pivot rotasyonu/pozisyonu olarak oynatılır.
  El ile animasyon dosyası YOK (karakter GLB rig'i gelirse gövde
  animasyonu sonradan üstüne bindirilecek — bağlantı noktası bırak).
- Eylem sırasında hareket %40 yavaşlar; yeni eylem, recover bitmeden
  başlayamaz (spam koruması). Kılıç kombosu tek istisna.
- Alet kademesi (taş→çelik) süreleri kısaltır: her kademe windup+recover
  toplamından %8 kırpar (profil verisinde çarpan).

## 12.4 ALET ÖZEL MANTIKLARI

- BALTA: ağaç canı (örn. 4 vuruş taş baltayla); her vuruşta odun parçası
  partikülü, son vuruşta ağaç devrilir (basit rotasyon tween + yere
  batma), odun item'ları saçılır. Çelik balta: tek vuruş kuralı.
- KAZMA: kaya/cevher canı; kademe-cevher kilidi (GAME_DESIGN alet→kaynak
  tablosu). Yanlış kademede vuruş: "tink" geri sekmesi + kıvılcım, hasar 0.
- KÜREK: Bölüm 11 kazı/yığma eylemlerini bu çerçeveye BAĞLA (etki anı =
  strike). 3x3 (demir özelliği) vuruşta komşu hücreleri de işler.
- BIÇAK: çalıdan lif 2x; leşten deri; vuruş değil "hasat" eylemi (kısa
  kesik + toplama pop'u).
- ÇEKİÇ: 3 modlu — hedef sağlam yapı: SÖKME (basılı tut 0.8 sn, halka
  dolum göstergesi, malzeme %100 iade); hasarlı yapı: TAMİR (vuruş
  başına can+, malzeme düşer); inşa modu ayrı sistem (mevcut yerleştirme
  neyse ona dokunma).
- KOVA: doldur/dök — Bölüm 11.2 eylemlerini bu çerçeveye bağla
  (windup kısa 0.10, "şlop" anı strike'ta).

## 12.5 SİLAH ÖZEL HAREKETLERİ

- MIZRAK FIRLATMA: saldırı butonuna BASILI TUT (>0.25 sn) → nişan modu:
  karakter önüne soluk yay/çizgi göstergesi; bırakınca fırlar. Uçuş:
  parabolik, uçarken kendi ekseninde hafif döner; saplandığı yerde
  titreşir; YERDE KALIR, üzerine gidip alınır (kaybolmaz). İsabette
  dürtmeden %50 fazla hasar.
- MIZRAK BALIK: su hücresine nişan alınmış fırlatma/dürtme → balık
  sistemi geldiğinde bağlanacak (TODO işaretle, kod yazma).
- SAPAN: basılı tut → karakter üstünde dönme animasyonu (pivot dairesel
  tween, hızlanan vınlama); bırak → çakıl (pebble) düz-hafif eğimli
  mermi. Mühimmat envanterden düşer, yoksa buton soluk + çakıl ikonu.
- YAY: basılı tut → GERDİRME: 0-1 sn dolum (yay pivotu gerilir, hafif
  titreme son %20'de); bırak → ok. Gerdirme oranı hız+hasarı ölçekler
  (min %30 güçle bile atar). Ok: düz mermi + yerçekimi az; saplandığı
  yerden %60 şansla geri toplanır. Mühimmat: arrow.
- KILIÇ: 12.3'teki 2'li kombo; ikinci kesikte küçük ileri adım (0.3
  birim) — saldırıya yön hissi.
- HASAR/VURUŞ ALANI: strike fazında karakter önünde kısa yay/kutu
  hitbox aktifleşir (silaha göre menzil profil verisinden). Şimdilik
  hedefler: TEST KUKLASI + kırılabilir nesneler. Yaratık koduna
  DOKUNMA — hitbox'ın "vurulabilir" arayüzü (take_hit(damage,
  knockback_dir)) yaratıklar geldiğinde aynen kullanılacak.

## 12.6 HİS (JUICE) — hepsi hafif, mobil dostu

- VURUŞ DURMASI: isabetli vuruşta 0.04-0.05 sn oyun hızı düşüşü
  (Engine.time_scale kısa tween) — ağırlık hissi.
- Hedef tepkisi: vurulan ağaç/kaya/kukla 0.1 sn sarsılır (scale/rot
  jiggle) + malzeme partikülü (odun kıymığı=kahve, taş=gri, toprak=
  toprak rengi; 4-6 parçacık, ucuz CPUParticles).
- Ekran sarsıntısı YOK (mobilde mide bulandırır) — sadece ağır çekiç
  sökmede 2px'lik tek titreşim.
- Ses kancaları: her profilde swing_sfx / hit_sfx / break_sfx alanı
  (placeholder ses; dosya yoksa sessiz geç, hata verme).
- Buton geri bildirimi: ana buton basışta 0.9 scale pop; geçersiz
  eylemde yatay minik sallanma (UI_DESIGN 4.5 diliyle uyumlu).

## 12.7 TEST KUKLASI

- Craftlanabilir "Kukla" (test amaçlı: 4 wood + 2 fiber, workbench):
  vurulunca can barı gösterir, take_hit arayüzünü kullanır, 0 canda
  devrilir ve 3 sn sonra yenilenir. Yaratıklar gelene kadar tüm silah
  testlerinin hedefi. Sallanma/knockback tepkisi verir — his ayarı
  bununla kalibre edilir.
