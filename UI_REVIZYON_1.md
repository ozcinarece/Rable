# UI REVİZYON 1 — TEŞHİS VE DÜZELTMELER

UI_DESIGN.md'nin ÜZERİNE gelen revizyon dokümanıdır; çelişki olursa BU
dosya kazanır. Mevcut uygulamanın ekran görüntüsü teşhisleri ve
ölçülebilir düzeltme kuralları. Genel ilke: SORUN TARZ DEĞİL, ORAN VE
YERLEŞİM. Krem/pastel dil kalıyor; oranlar, yoğunluk ve konumlar
değişiyor.

## R0 — GENEL ORAN KURALLARI (her şeye uygulanır)

- İKON DOLULUK KURALI: bir buton/slot içindeki ikon, kabın EN AZ
  %65'ini doldurur. "Koca daire içinde minik ikon" YASAK.
- Boş krem daire = tanımsız buton = hata. Her butonun ya net bir ikonu
  ya da kısa etiketi olur; ikisi de yoksa buton kaldırılır.
- KIRPILMIŞ METİN YASAK: "Tü", "Ma", "Al" gibi kesilmiş etiketler
  olamaz. Sığmıyorsa tam kelime + daha küçük font YA DA ikon+tooltip.
- Panel açıkken arka plan overlay_dim ile KARARIR ve HUD öğeleri gizlenir.
- Kilitli slot gürültüsü: kilitli slotlar tek tek çizilmez; ızgaranın
  sonunda TEK kompakt çip: "🔒 +8 slot (deri çanta ile)".

## R1 — SAĞ KENAR BUTONLARI (dock)
Hepsi TEK dikey DOCK'ta: sağ kenar, dikey ortanın altı, 12px aralık.
68px kategori renkli DOLGULU daire + %65 koyu kahve ikon + 12px mini
etiket. "Yeni Oyun" ve Kamera/Görünüm debug butonları HUD'dan çıkar →
Ayarlar menüsüne.

## R2 — ANA EYLEM + SALDIRI BUTONLARI
Ana buton 96px dolgulu ink_dark daire + büyük bağlam ikonu + içte mini
etiket. "+"/nişan kaldırılır. Saldırı 72px danger pastel + kılıç +
"Saldır", sadece silahken. Sağ altta başka şey yok.

## R3 — ENVANTER (bottom-sheet / orta panel)
Alttan kayan bottom-sheet (dikeyde) veya ortalanmış geniş panel
(yatayda). 64px slot, alt sabit bilgi şeridi (solda ikon, ortada ad+
açıklama, sağda eylem pill'leri). İlk açılışta öğretici metin bir kez.

## R4 — ÜRETİM (ızgara + detay bandı)
Tarifler 88px kart ızgarası; karta dokun → alt detay bandı (malzeme,
istasyon, tek Üret). Sol dikey renkli sekmeler (ikon esas). Küçük arama.

## R5 — ARAŞTIRMA
Düğüm ikonu %65 doluluk; maliyet düğüm içinde çip; alt bilgi bandı
(ikon+açtıkları+maliyet+Araştır).

## R6 — HUD CAN/AÇLIK/SU + YE
Kutu kaldırılır; 3 çıplak bar (140x14, 8px, solda 20px ikon). Bar
değişiminde 0.3sn nabız. "YE" HUD butonu tamamen kaldırılır.

## R7 — HOTBAR
64px slot, ikon %65, seçili 1.15x + alt nokta. Kilitli slot ikonları
kaldırılır (kilit yalnız envanterde).

---
Bu dosya CLAUDE Code otonom görevinin girdisidir; uygulama RAPOR_UI.md'de.
