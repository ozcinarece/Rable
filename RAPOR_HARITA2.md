# RAPOR — HARİTA BOYAMA v2 (geri bildirim turu)

Beş başlık: su silme bugı, kumsal, yükseklik katmanı, zoom/pan, canlı
önizleme. Branch: `harita-boyama-v2`.

## 1. SU SİLME — kök sebep ve çözüm

**Kök sebep doğrulandı, ama iki katmanlıydı:**

1. Silgi maskeyi "boş"a çeviriyor; boş = "prosedürel karar versin"
   demek ve üreteç oraya **yine göl koyuyor**. (Görevdeki hipotez.)
2. Daha derin: **hiçbir sınıf karayı zorlamıyordu.** `_cell_for`
   çayır/açıklık kuralları yalnız ağaç/kaya/platoya dokunuyordu —
   gölün üstüne çayır boyamak da suyu silmiyordu. Yani suyu silmenin
   *hiçbir* yolu yoktu.

**Çözüm — KARA ZORLAMA:** su ve kum dışındaki her sınıf (çayır,
açıklık, sık orman, kayalık, rezerv) artık önce suyu **ve** kıyı
kumunu karaya çevirir, sonra kendi kuralını uygular.

**Silgi ayrımı (rehbere de yazıldı):**
- **Silgi** = "burayı prosedürele bırak" → üreteç gölü geri koyar.
- **Çayır (veya başka kara sınıfı)** = "burası **kesin kara**".

Ayrıca **Tümünü Temizle** butonu eklendi — onay diyaloğuyla, aktif
katmanı boşaltır (Geri Al çalışır).

## 2. KUMSAL

- Palete **Kum** (#E8D5A3) eklendi: elle kumsal boyanır; su dahil her
  şeyi kuma çevirir (göl kenarını doldurmak da mümkün).
- **Otomatik bant:** maskeyle yeni açılan su hücrelerinin çevresine
  kum bandı. Genişlik üretecin kendi kıyı sabitinden türetiliyor
  (`MapBalance.SHORE_WIDTH` — **tek kaynak**, ikinci bir "kıyı
  genişliği" tanımlanmadı) ve hücre başına ±1 oynuyor (düz şerit
  olmasın). Bant yalnız çim/toprağı kuma çevirir; elle boyanan kum
  bunun üstüne genişletme olarak biner.
- Üretecin kendi gölü kendi kumunu koymaya devam ediyor (o yol hiç
  değişmedi) — çakışma yok.

## 3. YÜKSEKLİK KATMANI

İkinci maske: `data/height_mask.png` (gri tonları; ressamda ayrı
sekme). Üç kademe fırçası: Alçak / Normal / Tepe.

**Muhafazakâr dönüştürücü (görevin izin verdiği karar) ve gerekçesi:**

| Kademe | Oyundaki karşılığı |
|---|---|
| Tepe | `"h"` — **mevcut plato sistemi**: falez kenarları, arazi rengi, katılık hazır |
| Normal | plato yasağı — `"h"` varsa düzlenir |
| Alçak | **bugün Normal ile aynı** (aşağıda) |

- **Kazı uyumu çatışması çıktı ve muhafazakâr çözüldü:** "yükseltilmiş
  ama kazılabilir zemin" bugünkü arazide yok — plato (`"h"`) katıdır
  (üstüne çıkılmaz/kazılmaz). Bunu taklit etmek için kazı sisteminin
  `depth=-2` başlangıcı denenebilirdi ama o yol kazı yığınını
  **kahverengi tümsek** olarak çizer ve kayıt deltalarıyla çatışırdı.
  Karar: tepe = plato; gerçek çıkılabilir/kazılabilir teras ayrı bir
  arazi projesi. **Maske formatı 3 kademeyi şimdiden saklıyor** — o
  proje gelince veri hazır, boyadıkların geçerli kalır.
- Tepe suya/kuma binmez (falez suya girmesin); doğuş koruması ve kenar
  kuşağı burada da geçerli; kenarlar aynı domain warp ile organik.

## 4. ZOOM / KAYDIRMA

- **Tekerlek** = imlece kilitli zoom (1×–24×), **orta tuş** veya
  **boşluk+sürükle** = pan. Tuval **ve** 2D önizleme aynı kamerayı
  paylaşır — birinde gezinince ikisi birden kayar (karşılaştırma
  kolay). Zoom seviyesi köşede yazar.
- Harita boyutu koddan okunur (`base_rows.size()`): **büyütme projesi
  geldiğinde araç kendiliğinden uyar**, sabit 128 varsayımı yok
  (görevin istediği hazırlık; boyut değiştirme bu turda yok).

## 5. CANLI ÖNİZLEME

- **2D:** v1'de de sürükleme *sırasında* güncelleniyordu (karede bir);
  ölçüldü: 128×128 apply ~5-10 ms — algılanan gecikmenin asıl sebebi
  önizlemenin küçük ve ayrı kadrajda olmasıydı. v2'de önizleme tuvalle
  **aynı kamerada** (zoom/pan paylaşımlı) — darbe nereye vurduysa
  ikisinde de aynı yerde ve anında görünüyor.
- **3D otomatik:** yeni onay kutusu — fırça **bırakıldığında** düşük
  çözünürlüklü (320px) hızlı 3D güncelleme; "3D Önizle" butonu tam
  kalite (640px) olarak duruyor. Üst üste tetiklenme korumalı.
- **İşaretler:** doğuş/kamp noktası (kırmızı halka+artı) ve 8 hücrelik
  ızgara — ikisi de aç/kapa.

## DOĞRULAMA

**MASKTEST v2** (hızlı CI, her push) eski dört kontrole beş yenisini
ekledi — "göl boya → sil → çayıra çevir" zincirinin otomatik hâli:

- gölün üstüne çayır → blob çekirdeğinde **su kalmadı** (kara zorlama),
- silgi/boş maske → göl **geri geldi** (fallback aynı — silgi ayrımının
  kanıtı),
- maske gölünün çevresinde **otomatik kum bandı** oluştu,
- kum sınıfı boyandığı yeri **"s"** yaptı,
- tepe kademesi **"h"** üretti, normal kademe mevcut platoyu **düzledi**.

**Görsel doğrulama:** dal CI'sinde örnek maskelerle (göl + çayırla
kesilmiş göl kenarı + kum şeridi + tepe blobu) üç kare çekildi:
`3d_maske_kusbakisi.png` (tüm harita), `3d_maske_tepe.png` (falez
kenarları), `3d_maske_kumsal.png` (kıyı bandı). Örnek maskeler main'e
**girmedi** — oyun hâlâ tam prosedürel; ilk gerçek maske senin
fırçandan çıkacak.

## GÜNCEL KULLANIM REHBERİ (v2)

1. **Aç:** `scenes/tools/map_painter.tscn` → F6. Üstte iki sekme:
   **Biyom** ve **Yükseklik**. Gezinme: tekerlek=zoom, orta
   tuş/boşluk+sürükle=kaydır (iki panel birlikte hareket eder).
2. **Su ekle/sil:** su eklemek = mavi boya. Su silmek = **Silgi
   DEĞİL** — silgi "üreteç karar versin" demektir ve üreteç gölü geri
   koyar. Suyu silmek için üstüne **Çayır** (ya da başka kara sınıfı)
   boya: "burası kesin kara". Kumsal için **Kum** — su kenarlarına
   otomatik bant zaten gelir, elle kum onu genişletir.
3. **Tepe çiz:** Yükseklik sekmesi → **Tepe** fırçası. Kenarlar oyunda
   falezli plato olur (üstüne çıkılmaz — bilinçli, rapora bak).
   **Normal** fırçası mevcut tepeleri düzler. *Alçak bugün Normal ile
   aynı davranır* (veri saklanıyor, dönüştürücüsü ileride).
4. **Gör ve kaydet:** sağ panel her darbede güncellenir; "3D otomatik"
   açıksa fırçayı bırakınca hızlı 3D de gelir. **💾 Kaydet** iki
   katmanı birden yazar → oyunda **Yeni Oyun**.
5. **Sınırlar:** doğuş çevresi (kırmızı işaret, 6 hücre) ve harita
   kenarı maske dinlemez; **Tümünü Temizle** aktif katmanı prosedürele
   döndürür (onaylı, geri alınabilir); yol/kamp yerleşimi bu aracın
   işi değil.
