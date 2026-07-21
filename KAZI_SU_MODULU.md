# BÖLÜM 11 — KAZI VE SU MODÜLÜ (Tasarım Kaydı)

Bu bölüm GAME_DESIGN.md'nin devamıdır. Oyunun imza modülü: kazma + su +
savunma tek sistemde. AŞAMALI uygulanır — her aşamanın başında durum
etiketi var. Claude Code'a görev verilirken SADECE ilgili aşama işaret
edilir; sonraki aşamalar tasarım kaydıdır, erken uygulanmaz.

Durum etiketleri: [SIRADA] uygulanacak ilk iş · [PLANLI] sırası gelince ·
[FİKİR] v1 kapsamı dışı, ileride değerlendirilecek

---

## 11.1 ÇEKİRDEK MODEL — KADEMELİ DERİNLİK  [SIRADA]

- Dünya blok/grid tabanlı (3D'de de grid: her zemin hücresinin depth
  değeri var, 0-4).
- Kürek her vuruşta 1 seviye derinleştirir. Kazılan hücre envantere
  "toprak" (dirt) item'ı verir.
- Alet kademesi derinlik sınırı koyar:
  taş kürek → max 2 · demir kürek → max 3 · çelik kürek → max 4
- Seviye 3'ten sonra toprak biter, KAYA başlar → kürek değil KAZMA
  gerekir (derinlik, araştırma ağacına bağlanır).

### Derinlik seviyeleri ve yaratık davranışı
| Seviye | İsim | Yaratık | Oyuncu |
|---|---|---|---|
| 1 | Oyuk | %30 yavaşlar | Rahat girer çıkar |
| 2 | Çukur | Düşer, ~3 sn tırmanır (savunmasız) | Zıplayıp çıkar |
| 3 | Hendek | ~6 sn tırmanış; TIRMANICI tip 2 sn'de çıkar | Rampa/merdiven ister |
| 4 | Uçurum | Normal yaratık çıkamaz, sadece tırmanıcı | Düşme hasarı var |

### Tırmanıcı yaratık (denge anahtarı)  [SIRADA — yaratık sistemiyle birlikte]
- İlk geceler: sadece normal yaratıklar → kuru çukur yeterli savunma.
- İlerleyen geceler: dalgaya tırmanıcılar karışır → kuru çukur artık
  yavaşlatır ama DURDURMAZ → oyuncu suya yönlendirilir.
- Kural: SU DOLU hücrede hiçbir yaratık tırmanamaz.

## 11.2 SU MODELİ — HACİM ESASLI  [PLANLI — çekirdekten sonra]

- Çukur hacmi = hücre sayısı × derinlik. 1 kova = 1 birim su.
  (1 hücrelik seviye-2 çukur = 2 kova; 10 hücrelik seviye-3 hendek =
  30 kova → elle doldurmak kasten zahmetli, boru+pompa bunun ödülü.)
- Bağlı (bitişik kazılmış) hücreler TEK HAVUZ gibi davranır: su seviyesi
  aralarında eşitlenir.
- Su seviyesi ≥ hücre derinliğinin yarısı ise: yaratık yüzer → %70
  yavaşlama + tırmanamama. Dolu hendek = gerçek sur.
- Gerçek akışkan simülasyonu YOK — hücre bazlı hacim + mantıksal
  transfer (mobil performansı).

## 11.3 TOPRAK YIĞMA (kazmanın tersi)  [PLANLI — çekirdekle birlikte kolay]

- Toprak item'ı boş/düz hücreye dökülür → seviye +1 yükselir (max +2).
- Hendek + arkasına toprak sur kombinasyonunu mümkün kılar; kazılan
  toprak çöpe gitmez. Tek mekanik, iki yön.

## 11.4 DERİNLİK = KAYNAK  [PLANLI — çekirdekle birlikte]

- Seviye 1: kil şansı artar · Seviye 2: bol taş · Seviye 3-4: kömür ve
  cevher damarları.
- Kazı modülü hem savunma hem madencilik motivasyonuna hizmet eder.

## 11.5 RAMPA / MERDİVEN  [PLANLI]

- Odun merdiven çukur kenarına yerleştirilir; oyuncu iner-çıkar.
- DİKKAT mekaniği: gece merdiven çekilmezse YARATIKLAR DA KULLANIR.
  ("Kapıyı kilitledin mi?" gerilimi — bilinçli tasarım.)

## 11.6 BALIK GÖLETİ  [FİKİR]

- 6+ hücrelik, yeterince dolu su birikintisine zamanla balık gelir.
- Mızrağın balık avlama işlevi devreye girer → yenilenebilir yiyecek.
- Oyuncunun kazdığı çukurun ekosisteme dönüşmesi ("benim eserim" anı).

## 11.7 SULAMA BAĞLANTISI  [PLANLI — tarım modülüyle birlikte]

- Tarlaya bitişik su hücresi tarlayı otomatik "sulanmış" sayar.
- Sulama borusuna alternatif: akıllı kazılmış kanal da çözümdür
  (mühendis oyuncuya ikinci yol).

## 11.8 VANA + HENDEK = KALE KAPISI  [FİKİR — boru sisteminden sonra]

- Hendek gündüz boş tutulur (serbest geçiş), gece vana açılır → dolar.
- Geç oyunun günlük ritüeli / "kale kapısı" anı.

## 11.9 ÇUKUR + KAZIK KOMBOSU  [PLANLI — tuzaklarla birlikte]

- Çukur dibine sivri kazık yerleştirilebilir: düşen yaratık hem
  hapsolur hem hasar alır. pit_trap'in organik büyümüş hali.

## 11.10 YUVA AĞZI  [FİKİR — riskli/lezzetli, v1'e KOYMA]

- Seviye 4 kazıda nadiren "yuva ağzı" açılır: gece o delikten de
  yaratık sızar. Kapatmak için taşla doldurmak gerekir.
- Derin kazmanın ödülü cevher, bedeli risk. Oyuna "derinlik korkusu"
  katar. Denge testi ister.

---

## UYGULAMA SIRASI (özet yol haritası)

1. [SIRADA] 11.1 çekirdek: derinlik seviyeli kazı + toprak item'ı +
   alet kademesi sınırı + 11.3 toprak yığma + 11.4 derinlik kaynakları
2. Yaratık sistemine tırmanma davranışı + tırmanıcı tip (11.1 tablosu)
3. 11.2 su modeli (kova → havuz → yüzme yavaşlaması)
4. 11.5 merdiven, 11.9 çukur+kazık, 11.7 sulama bağlantısı
5. Boru/pompa/vana entegrasyonu → 11.8
6. Değerlendirme rafı: 11.6 gölet, 11.10 yuva ağzı

Her aşama için Claude Code görevi ayrı yazılacak; bu dosya tasarımın
tek doğruluk kaynağıdır. Yeni fikirler bu dosyaya [FİKİR] etiketiyle
eklenir, silinmez.
