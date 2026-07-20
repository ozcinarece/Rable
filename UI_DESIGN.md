# UI/UX TASARIM SİSTEMİ — Survival Sandbox (Godot 4)

Referans estetik: Longvinter. Anahtar kelimeler: pastel, yumuşak, tombul,
sıcak, "şeker gibi". Bu doküman oyundaki TÜM arayüzlerin tek doğruluk
kaynağıdır. Her UI işi bu dile uymak zorundadır.

## 0. TASARIM FELSEFESİ

- Arayüz bir "el işi defter / piknik" hissi verir: krem kağıt paneller,
  koyu kahve mürekkep, şeker renkli vurgular.
- Hiçbir yerde sert köşe, saf siyah, saf beyaz, neon renk YOK.
- Her etkileşim küçük ve yumuşak bir geri bildirim verir (minik pop,
  yumuşak vurgu). Ağır, hızlı, sarsıcı animasyon YOK.
- Mobil öncelikli: her dokunulabilir öğe parmak dostu.

## 1. RENK PALETİ (kesin hex kodları)

### Zemin ve panel
- panel_cream:      #F6EDD6   (ana panel zemini — krem kağıt)
- panel_cream_dark: #EDE0C3   (panel içi ikincil alan, slot ızgara zemini)
- panel_shadow:     #00000022 (panel altı yumuşak gölge, 8px offset)
- overlay_dim:      #2B1F1466 (panel açıkken oyun ekranı karartması)

### Metin ve çizgi
- ink_dark:   #4A3728  (ana metin, başlıklar — koyu kahve, siyah DEĞİL)
- ink_soft:   #8A7660  (ikincil metin, açıklamalar)
- ink_faint:  #C4B49A  (pasif/kapalı metin)

### Başlık sekmesi (Longvinter "Backpack" etiketi gibi)
- tab_bg:   #4A3728  (koyu kahve)
- tab_text: #F6EDD6  (krem)

### Kategori vurgu renkleri (slot arkaplan daireleri)
Her item kategorisinin KENDİ pastel dairesi olur — Longvinter'daki
turuncu/yeşil/mor daireler gibi. Kategori → renk eşleşmesi SABİT:
- resource (hammadde):  #A8D8A0  (çimen yeşili pastel)
- tool (alet):          #F5B971  (bal turuncusu)
- weapon (silah):       #F09090  (mercan pembe-kırmızı)
- station (istasyon):   #C9A87C  (ahşap bej)
- trap (tuzak):         #B9A0E8  (lavanta moru)
- structure (yapı):     #9FC5E8  (gökyüzü mavisi)
- farming (tarım):      #D6E8A0  (fıstık yeşili)
- engineering (müh.):   #A0D8D8  (nane-turkuaz)
- special/nadir:        #E8C4F0 + minik yıldız parıltısı (öz vb.)

### Durum renkleri
- success/olumlu:  #7BC47F  (yeterli malzeme, açık düğüm)
- danger/olumsuz:  #E07A5F  (yetersiz malzeme, hasar — pastel tuğla,
  agresif kırmızı DEĞİL)
- warning/gece:    #E8B84A  (gece uyarısı, süre azalıyor)
- research/bilgi:  #8FB8DE  (araştırma vurgusu)

## 2. FORM DİLİ

- Panel köşe yarıçapı: 24px. Slot/kart köşe: 16px. Buton köşe: 999px
  (tam hap/pill) veya 16px.
- Paneller: panel_cream zemin + 3px panel_cream_dark iç kenar çizgisi
  YERİNE dışa 8px yumuşak gölge (StyleBoxFlat shadow). Kalın kontur yok.
- Başlık: panelin SOL ÜSTÜNDEN hafif taşan koyu kahve pill sekme
  (Longvinter "Backpack" gibi). Panel içinde başlık tekrarlanmaz.
- Slotlar: kare değil YUVARLAK arkaplan dairesi (kategori rengi) +
  üstünde ikon. Daire çapı slot boyutunun ~%85'i.
- Butonlar: dolgulu pill. Ana eylem = ink_dark zemin + krem metin.
  İkincil eylem = panel_cream_dark zemin + ink_dark metin.
- İkon yoksa placeholder: kategori rengine boyalı yuvarlak + item adının
  ilk 2 harfi (örn. "Od" = odun). ASLA gri kare kullanma.

## 3. TİPOGRAFİ

- Font: "Baloo 2" (Google Fonts — yuvarlak, tombul, TÜRKÇE karakter
  desteği tam: ş, ğ, ı, ö, ü, ç MUTLAKA test edilecek).
- Alternatif: "Nunito" (daha sakin). İkisinden biri projeye .ttf olarak
  eklenir, Godot Theme'de default font yapılır.
- Boyut ölçeği (mobil): başlık 28, panel başlık sekmesi 22, gövde 18,
  küçük etiket 15, stack sayısı 16 (bold, ikonun sağ altında, üzeri
  minik krem rozet içinde).
- ASLA ince (light) kesim kullanma; Regular ve Bold/SemiBold yeter.

## 4. BİLEŞENLER

### 4.1 HUD (oyun içi kalıcı arayüz)
- Sol üst: gün sayacı + saat — küçük krem pill içinde "Gün 4" + minik
  güneş/ay ikonu. Gece yaklaşınca (son 1 dk) pill warning rengine
  yumuşakça geçer ve hafifçe nabız atar (scale 1.0→1.04, 1sn döngü).
- Alt orta: hotbar — 5 slot, yatay, krem şerit üstünde yuvarlak slotlar.
  Seçili slot: hafif büyür (1.12x) + altına minik nokta.
- Sol alt: can + açlık — kalp ve but ikonlu iki kısa bar, pastel dolgu
  (can: danger pasteli, açlık: tool turuncusu), koyu kahve ince çerçeve.
- Sağ üst: buton grubu (envanter, craft, araştırma) — dikey ikon
  pill'leri, Longvinter'daki sol yan sekmeler gibi. 64px dokunma alanı.
- HUD öğeleri yarı saydam DEĞİL — hepsi opak krem, oyun alanından net
  ayrışır.

### 4.2 Envanter paneli
- Ekranın sağından yumuşakça kayarak girer (0.25sn, ease-out).
- "Sırt Çantası" koyu kahve başlık sekmesi.
- 4 sütun slot ızgarası, slotlar arası 12px boşluk.
- Slot: kategori rengi daire + ikon + sağ altta stack rozeti.
- Boş slot: panel_cream_dark soluk daire (davetkâr ama sessiz).
- Slota DOKUN: seçilir, panelin altında item bilgi şeridi açılır
  (ad + kısa açıklama + varsa "Kullan/At" pill butonları).
- Doluluk göstergesi: panel altında ince şerit "18/20" + minik çanta
  ikonu.

### 4.3 Üretim (craft) paneli
- Sol kenarda dikey KATEGORİ sekmeleri: her kategori kendi renginde
  yuvarlak ikon pill'i (aletler, yapılar, tuzaklar, tarım...). Aktif
  sekme sağa doğru hafif taşar + tam opak; pasifler %70 opak.
- Sağda tarif listesi: her tarif bir yatay KART (krem, 16px köşe):
  solda sonuç ikonu (kategori dairesiyle), ortada ad + malzeme listesi,
  sağda "Üret" pill butonu.
- Malzeme listesi: her malzeme "ikon + 3/5" formatında; yeterliyse
  success renginde, yetersizse danger renginde (renk körlüğü için
  yetersizlere ek olarak minik ünlem rozeti).
- Üretilemeyen tarif kartı: %60 opak + Üret butonu pasif (ama kart
  görünür kalır — hedef göstermek motivasyondur).
- İstasyon gereken tarifte: kartta minik istasyon ikonu + "Fırın
  yanında" etiketi; istasyon uzaktaysa bu etiket warning renginde.
- Üretim BAŞARILI animasyonu: sonuç ikonu karttan hotbara doğru minik
  bir yay çizerek uçar (0.4sn) + slot minik pop yapar. Ses: yumuşak
  "pık" (placeholder).

### 4.4 Araştırma ağacı paneli
- TAM EKRAN panel (bu, oyunun "büyük" ekranı — özel hissettir).
- Zemin: panel_cream üzerine ÇOK soluk nokta deseni (el işi kağıt hissi).
- 4 dal yatay şeritler halinde, her şeridin başında dal adı + dal
  renginde ikon pill (Aletler=turuncu, Savunma=lavanta,
  İstasyonlar=bej, Mühendislik=turkuaz).
- Düğüm kartı: yuvarlak köşeli kare kart, ortada ikon dairesi, altında
  ad. Durumlar:
  - AÇILMIŞ: tam renk + minik yeşil onay rozeti köşede.
  - AÇILABİLİR: tam renk + altında maliyet şeridi (ikon+sayı,
    yeterlilik renkleriyle) + kart çok hafif parlar (nabız).
  - KİLİTLİ (önkoşul eksik): gri-bej desatüre + minik kilit ikonu.
  - GİZLİ: kart yerine "???" yazılı soluk kart + soru işareti.
- Düğümler arası bağlantı: yumuşak KAVİSLİ çizgiler (dik açı değil),
  ink_faint renkte; açılmış yol success renginde kalınlaşır.
- Düğüme dokun: alt bilgi şeridi açılır (ne açıyor + maliyet +
  "Araştır" pill butonu). Buton sadece Araştırma Masası yakındayken
  aktif; uzaktaysa "Araştırma masasına git" etiketi.
- ARAŞTIRMA TAMAMLANDI animasyonu: düğümden 6-8 minik pastel konfeti/
  yıldız fışkırır (0.6sn), bağlantı çizgisi success rengine akar.
  Bu oyunun en ödüllendirici anı — cimri davranma ama abartma.

### 4.5 Genel geri bildirimler
- Toplama: item ikonu karakterden envanter butonuna minik yay çizerek
  uçar + "+" rozeti.
- Yetersiz malzemeyle Üret'e basınca: kart yatayda 2 kez minik sallanır
  (shake 4px) + eksik malzemeler kısa parlar. Ceza hissi değil,
  "şuna bak" hissi.
- Gece başlangıcı: ekran kenarlarında yumuşak lavanta-lacivert vinyet +
  üstte "Gece 4 — Geliyorlar..." pill'i 2sn görünür.
- Tüm panel aç/kapa: 0.2-0.25sn, ease-out, kayma veya yumuşak
  scale (0.96→1.0). ASLA anında aç/kapa yok.

## 5. MOBİL UX KURALLARI

- Minimum dokunma hedefi: 64x64 px (slotlar dahil).
- Tek elle erişim: sık kullanılan butonlar (hotbar, panel butonları)
  ekranın ALT yarısında veya sağ kenarında.
- Sürükle-bırak YERİNE dokun-seç-dokun-yerleştir modeli (mobilde daha
  güvenilir). Sürükleme sadece harita kaydırmada.
- Paneller ekranın en fazla %85'ini kaplar — oyun dünyası her zaman
  ucundan görünür (bağlam hissi).
- Safe area (çentik/yuvarlak köşe) payı: tüm HUD kenarlardan 16px içeride.

## 6. GODOT UYGULAMA KURALLARI (kritik)

- TÜM stiller tek bir Theme resource'ta (theme_main.tres) toplanır:
  StyleBoxFlat'ler (köşe, gölge, dolgu), renkler, fontlar. Node'lara
  TEK TEK stil verme — her şey Theme'den gelsin ki tek yerden
  değişebilsin.
- Renkler bir autoload/const script'te de tanımlı olsun (UIColors.gd)
  — kodda hex tekrarı YASAK.
- Kategori→renk eşleşmesi item database'deki kategori alanından otomatik
  okunsun (yeni kategori = tek satır ekleme).
- Animasyonlar Tween ile; her panel kendi aç/kapa fonksiyonunu
  (open()/close()) taşır.
- Tüm UI Control node'ları ile, anchor tabanlı — farklı ekran
  oranlarında (16:9, 19.5:9, tablet 4:3) bozulmadan çalışacak.
  Proje stretch ayarı: canvas_items + expand.
- İkonlar assets/icons/ klasöründen yüklenir; dosya yoksa Bölüm 2'deki
  placeholder (renkli daire + 2 harf) otomatik devreye girer.
