# BÖLÜM 14 — BASE FONKSİYONLARI VE SAVUNMA STRATEJİSİ

Doküman ailesinin parçası. İki kısımdır:
- A KISMI [SIRADA]: şimdi kodlanacak dört base yapısı (sandık, yatak,
  ocak, platform) — sondaki otonom görev bunları uygular.
- B KISMI [PLANLI]: savunma stratejisinin tasarım kaydı — YARATIK
  SİSTEMİYLE birlikte kodlanacak, şimdi KOD YAZILMAYACAK. Yaratık
  görevine başlanırken bu kısım zorunlu okumadır.

Temel ilke: base building'in stratejik olması, yaratıkların SEÇİM
yapmasına bağlıdır. Yaratıklar en ucuz yolu arar → oyuncu zayıf noktayı
bilerek bırakıp ölüm hunisi kurar. Bu doküman o oyunu mümkün kılar.

---

## A KISMI — ŞİMDİ UYGULANACAK YAPILAR

### 14.1 SANDIK (chest)  [SIRADA]
- Tarif: 8 wood + 1 rope (workbench). Kategori: structure, placeable.
  hp: 60. max_stack: 4 (taşınabilir item olarak).
- Kendi envanteri: 16 slot (oyuncu envanteriyle AYNI slot/stack
  altyapısını kullan — kod tekrarı yok, Inventory sınıfı örneklenir).
- Etkileşim: ana buton "aç" bağlamı → ÇİFT PANEL UI: solda sandık,
  sağda oyuncu envanteri (UI_DESIGN 4.2 diliyle iki krem panel yan
  yana; mobilde alt alta da olabilir — ekrana göre karar ver).
  Aktarım: dokun-seç-dokun (UI_DESIGN 5 kuralı). Panel üstünde iki
  hızlı buton: "Tümünü koy" (eşleşen stack'leri sandığa) / "Tümünü al".
- Yıkılırsa (hp 0): içindeki TÜM item'lar yere saçılır (dünya item
  sistemi) — kayıp yok ama dağınıklık cezası.
- Çekiçle sökme: içi BOŞSA sökülür; doluysa reddet + "önce boşalt"
  geri bildirimi (item duplikasyon/kayıp riskini sıfırlar).
- Kayıt taslağına (13.6) sandık içerikleri dahil edilir.

### 14.2 YATAK (bed)  [SIRADA]
- Tarif: 6 wood + 3 hide (workbench). structure, placeable. hp: 80.
- İşlev 1 — DOĞUŞ NOKTASI: yerleştirilen son yatak aktif doğuş
  noktasıdır (yenisi öncekini devralır; aktif yatakta minik işaret).
  Ölüm sistemi henüz yoksa: oyunun başlangıç konumu olarak bağla +
  ölüm geldiğinde kullanılacak set_spawn() arayüzünü hazırla.
- İşlev 2 — UYKU: TODO, gündüz/gece sistemiyle gelecek. Tasarım notu
  (o güne): ilk 2-3 gece uyunabilir (yeni oyuncuya nefes), sonrası
  "yaratıklar yaklaşıyor" — gece atlama kapanır; gece ana meydan
  okumadır, iptal edilemez.
- Etkileşim şimdilik: "burayı ev yap" onay pop'u (doğuş noktası ata).

### 14.3 OCAK (hearth)  [SIRADA — rolü B kısmında büyüyecek]
- Tarif: 8 stone + 4 clay + 2 wood (workbench). structure, placeable.
  hp: 400 (en dayanıklı yapı — kalp kolay kırılmamalı).
- Aynı anda TEK aktif Ocak (yenisi yerleştirilirken uyarı + eskisi
  pasifleşir).
- Görsel: büyük, sıcak, canlı ateşli merkez yapı — kamp ateşinin
  "abisi". Işık: meşale bütçesinden BAĞIMSIZ, her zaman yanan öncelikli
  ışık (base'in kalbi hissi).
- Şimdilik işlev: kamp ateşi gibi pişirme istasyonu sayılır + geniş
  ışık. [PLANLI] işlevleri (B kısmı): gece yaratık hedefi, sabah
  bonusu kaynağı. get_hearth() sorgusu global erişilebilir olsun —
  yaratık sistemi bunu kullanacak.

### 14.4 SAVUNMA PLATFORMU (platform)  [SIRADA]
- Tarif: 6 wood + 2 rope (workbench). structure, placeable. hp: 100.
- Üstüne ÇIKILABİLİR yapı (~1.5 birim yükseklik, entegre basamak/
  rampa tarafı — yerleştirmede döndürerek basamak yönü seçilir).
- Oyuncu üstündeyken: tüm menzilli eylemler serbest (yay, sapan,
  mızrak fırlatma) — hedefleme yüksekten aşağıyı görür. Kuklayla test:
  platformdan ok atışı.
- Duvar bitişiğine yerleştirilebilir (sur arkası atış pozisyonu —
  hedeflenen kullanım). Toprak yükseltisinin (11.3) üstüne de kurulur
  → çift yükseklik mümkün, ama en fazla bu (uçan kale yok).
- İnişte düşme hasarı yok (1.5 birim güvenli).

---

## B KISMI — SAVUNMA STRATEJİSİ  [PLANLI — YARATIKLARLA KODLANACAK]

### 14.5 Maliyet bazlı yol bulma (stratejinin motoru)
Yaratık, hedefe giden yolu HÜCRE GEÇİŞ MALİYETİ toplamıyla seçer
(A* benzeri; grid zaten var). Taslak maliyet tablosu (denge verisi):
| Hücre içeriği | Geçiş maliyeti |
|---|---|
| Boş zemin | 1 |
| Yükselti (+1/+2) | 3 / 6 |
| Çit | 5 |
| Ahşap duvar | 10 |
| Taş duvar | 18 |
| Tuğla sur | 26 |
| Çelik kapı | 40 |
| Kuru çukur (depth 2-3) | 8-14 (tırmanıcıya yarısı) |
| SU DOLU hendek | 35 (tırmanıcı dahil) |
| Kazıklı hücre | 12 + hasar bedeli |
- Yapı hücresinin maliyeti = kırma süresi tahmini (hp / yaratık
  hasarı) ile orantılı → güçlü duvar "pahalı yol"dur.
- SONUÇ: yaratıklar zayıf noktaya akar. Oyuncunun bilinçli bıraktığı
  açıklık = huni. Bu davranış ÖĞRETİLMEZ, keşfedilir.
- Performans: yol hesapları dalga başında + yapı değişiminde; her
  karede değil.

### 14.6 Hedef seçimi (aggro)
Öncelik sırası: (1) yakın menzildeki oyuncu → (2) yolunu fiziken
kapatan yapı (kır-geç) → (3) OCAK (varsayılan gece hedefi).
- ÖZ LAMBASI: menzilindeki yaratıkların hedefini KENDİNE çeker
  (oyuncu kontrollü mıknatıs — huniye yönlendirme aracı). Kırılırsa
  çekim biter, özler kaybolur (GAME_DESIGN 5).
- Ocak hasar alırsa/yıkılırsa bedel: sabah bonusu iptali + (denge
  testine göre) araştırma malzemesi kaybı. "Kaçarak geceyi atlatma"
  taktiği böylece kapanır: base'i savunmak mecburiyettir.

### 14.7 Yaratık tipleri (katmanlı savunmayı zorlar)
| Tip | Özellik | Oyuncuyu zorladığı katman |
|---|---|---|
| Normal | Standart | Duvar yeter |
| Tırmanıcı | Kuru çukurdan 2 sn'de çıkar | Su ister |
| Kırıcı | Yapı hedefler, duvara 3x hasar | Huni + tamir ritmi |
| Hızlı | 2x hız, düşük can | Tuzak zamanlaması, ok isabeti |
Gece kademelerine karışım (taslak): 1-3 normal · 4-6 +tırmanıcı ·
7-9 +kırıcı · 10+ +hızlı ve karışık dalgalar. Denge veride tutulur.

### 14.8 Tuzak tetiklenmeleri
GAME_DESIGN Bölüm 5 + KAZI_SU 11.9 davranışları bu fazda kodlanır:
kazık (temas hasarı+yavaş, 3 tetikte kırılır), ezici kütük (kapı önü,
yeniden kurulum), alev hendeği (kanal hasarı, gece başına kömür),
çukur hapsi (sabah öz hasadı). Hepsi take_hit/etki arayüzleriyle.

### 14.9 Denge ilkeleri (kod değil, pusula)
- Her savunma katmanının bir zaafı olmalı; tek "kusursuz dizilim"
  varsa tasarım hatasıdır — yaratık karışımı onu kırmalı.
- Sabah ödülü (gece ekonomisi) Ocak üzerinden verilir: hasarsız gece
  → Ocak'tan bonus. Savunma yatırımı böylece ekonomiye döner.
- İlk 3 gece bilerek kolay: oyuncu huni fikrini keşfedecek alanı
  bulmalı, cezalandırılmamalı.
