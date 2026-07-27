# HARİTA MASTER PLANI — Aşama 1 TESLİM (makro tasarım maskeleri)

Görev KESIF.md yokken durmuştu; KESIF.md artık repoda (keşif paketiyle
geldi) — plan kaldığı yerden başladı. Bu teslim **Aşama 1**: üç makro
maske üretildi ve oyuna bağlandı. Ressamın okuduğu formatta —
**elle düzenlemen esas akış**, aşağıda rehberi var.

## ÜRETİLEN MASKELER (data/)

| Dosya | İçerik |
|---|---|
| `map_mask.png` | Biyom tasarımı (7 sınıf; merkez SEED kampı ≈ 59,62) |
| `height_mask.png` | H3 plato yayları — falez kenarlı, sınırlı geçişli |
| `fog_mask.png` | Sis yoğunluğu (gri: 0/64/150/235 — halkalarla hizalı) |

Tasarım (16.1 halkaları, keşif sistemiyle AYNI merkez ve yarıçaplar):

- **Merkez (R0):** bej kamp açıklığı; çevresi serbest kuşak (üreteç
  karışımı — dağınık ağaç/taş/berry oradan gelir).
- **H1:** çayır benekleri + öğretici göl (kamp yakını) + 1. harabe
  alanı (bej leke). Sefer öğretisi: yarım günlük tur.
- **H2:** SIK ORMAN kuşağı — geçitler 4 radyal koridora daraltıldı
  (-120°/-30°/60°/150°); sazlık (doğu gölü kum şeridiyle), yan taş A
  rezervi, 2. harabe.
- **H3:** kayalık lekeler + `height_mask` plato yayları (kuzey ve
  güneydoğu; geçit boşlukları doğal darboğaz), damar çatlağı vadisi
  (güney gri koridor), yan taş B-C.
- **Rezervler (mor):** 6 ana kor taşı alanı — `kesif_balance.TAS_ANA`
  açılarıyla BİREBİR aynı yay + 3 yan taş + **Ana Ocak** (60°, r=76 —
  en uç, zifiri bölge) + **göl adası ve kırık köprü** (batı gölü:
  ada çayırı + ortası kırık kum köprüsü).

## SİS KATMANI OYUNA BAĞLANDI

`MapMask.load_fog_image()/fog_at()` + `world3d._sis_at_cell` artık
önce KALICI temizliğe (yanan kor taşı), sonra **fog_mask.png**'ye,
o yoksa halka fallback'ine bakar. Maske sınırı dışı = zifir (kenar
kuşağı hep sisli). Yakılan taş maskeden bağımsız temizler — "çemberi
büyüt" hissi maskeyle çelişmez.

## AŞAMA 0 KARARI (boyut/chunk) — BİLİNÇLİ ERTELEME

16.8 "H3 = 2-3 gece yürüyüş" ister; 128×128'de mesafeler sıkışık.
Büyütme kararı chunk/LOD ölçümü ister ve maskeler piksel=hücre eşli
(büyütünce yeniden boyanır). Sıra bilinçli ters çevrildi: önce
TASARIM DİLİ otursun (bu teslim; sen ressamda düzenleyip onayla),
sonra boyut/chunk ölçüm dilimi gelsin — onaylı tasarım büyük tuvale
bir kez taşınır. Ölçüm planı: 192/256 üretim süresi + örnek sayıları
+ cihaz FPS; chunk ancak ölçüm gerektirirse.

## SENİN DÜZENLEME REHBERİN

1. `git pull` → ressamı aç (F6). **Biyom** sekmesi = map_mask
   (7 renk fırçası), **Yükseklik** sekmesi = height_mask (Tepe/Normal).
   Alt çubukta "kaynak: kayıtlı maske" yazmalı — o artık BU tasarım.
2. Sis katmanının ressam sekmesi HENÜZ YOK (borç, aşağıda) —
   fog_mask.png'yi şimdilik herhangi bir resim editöründe düzenle
   (gri tonlar: koyu=zifir, siyah=açık; 128×128, 1px=1hücre).
3. Kaydet → oyunda **Yeni Oyun** (maske tabanı değiştirir; mevcut
   kayıt eski dünyasında kalır).
4. Mor rezervleri taşırsan kor taşları OTOMATİK taşınmaz (taş
   yerleşimi kesif_balance açı/yarıçapından) — mor lekeler şimdilik
   görsel plan işareti; taş-maske eşlemesi POI aşamasının işi.

## KALAN AŞAMALAR (borç listesi)

- **Aşama 0:** boyut ölçümü + büyütme/chunk kararı (tasarım onayından sonra).
- **Aşama 2:** ring_balance verileri kesif_balance'ta VAR (get_ring,
  sertleşme, halka tehditleri) — dalga çarpanı bağlı; kaynak kademesi
  (H2 bakır yüzeyde / H3 demir) henüz değil.
- **Aşama 3 POI:** harabe/anıtlık/mağara ağzı/kırık köprü GÖRSELLERİ
  + mor rezerv→taş konumu eşlemesi; Kül Ormanı materyali.
- **Aşama 4:** sis görseli keşiften hazır (vinyet+soğuma+düzlem);
  fog_mask ressam sekmesi eksik.
- **Aşama 5:** etiketli kuşbakışı plan görseli + RINGTEST/POI sayaçları.
