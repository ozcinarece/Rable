# RAPOR — Açılış Sahnesi: Gün 0 + Gün 1 (acilis-sahnesi)

Dikey dilimin kapısı: yeni oyuncu oyuna siyah ekrandan uyanıp iki gün
içinde "Ocağı yak → yiyecek bul → kampı araştır → balta yap" zincirinden
geçiyor. Tüm süreler/metinler `scripts/acilis_balance.gd`'de — kod
içinde tek sayı yok, görev metinleri birebir.

## Akış

**Gün 0 — "Doğum"**: siyah ekran + "Gün 0" (2 sn) → gece kampına 2 sn
fade → HUD tamamen gizli (barlar, hotbar, gün çipi, Ayarlar, çanta,
fener — sadece dünya) → karakter balonu "Neredeyim?" (3 sn) → sağdan
kayan to-do kartı "🔥 Ocağı yak" → oyuncu SÖNÜK ocağa dokunur (hedefleme
"Dokun" verir) → 1 sn duraklama → alev canlanır, ocak ışığı 3 sn'de
büyür + kıvılcım parçacıkları → fısıltı "…geldin." (4 sn, G-01 hikaye
bayrağı kayda girer; panel sonraki görevde) → to-do ✓ animasyonu →
2 sn sonra siyah → Gün 1.

**Gün 1 — "Açlık ve emek"**: "Gün 1" etiketi → sabah kampına fade →
HUD geri gelir ama BARLAR YOK → 5 sn sonra mide gurultusu ses kancası
(`stomach_growl`, dosya gelince çalar) + açlık barı SOLDAN KAYARAK
doğar (%60, nabız animasyonu) → to-do "🫐 Yiyecek bul (0/3)" (kamp
çevresine 5 berry çalısı garantili) → 3 yiyecekte ✓ → "🔍 Kampı
araştır" (kulübe/kuyu/masa parıltısı) → masaya dokununca NOT DEFTERİ
paneli: *"Sayfaların çoğu yanmış. Arka kapakta aceleyle çizilmiş iki
tarif: Balta (2 dal, 1 taş, 1 ip) — Kazma (2 dal, 2 taş)."* → kapatınca
balta+kazma tarifleri AÇILIR (o ana dek `Crafting.acilis_kilit` ikisini
de kilitler; üretim 0 verir) → "🪓 Balta yap" (yerde 4 dal + 3 taş +
kulübe önünde 1 ip garantili) → balta üretilince ✓ → "Artık hazırsın."
(3 sn) → kart kaybolur, normal oyun.

## Barlar ihtiyaçla doğar

Açılış modunda üç bar da gizli başlar; her biri ilk İHTİYAÇTA soldan
kayma + nabızla belirir: mide Gün 1 gurultusunda, kalp ilk hasarda
(`Health.changed` < %100), damla susuzluk ilk kez %50'nin
(`SUSUZLUK_DOGUM_ESIK`) altına düşünce. Normal/hızlı oyunda hepsi
baştan görünür — davranış değişmez.

## Geliştirici girişi (EK KURAL)

- **Debug build (F5)**: varsayılan HIZLI BAŞLAT — açılış tamamen
  atlanır: Gün 1 sabahı, kamp ocağı YANIK, balta+kazma tarifleri açık,
  açlık %80, to-do yok. Bugünkü test akışıyla birebir aynı.
- **`--acilis` argümanı**: debug'da da sinematiği zorlar
  (`godot --path . -- --acilis` ya da editörde çalıştırma argümanı).
  Ayarlar > geliştirici'ye "Açılışı oynat" butonu İLERİDE eklenebilir;
  şimdilik argüman aynı işi görüyor (panel altyapısı ayrı görev).
- **Release build**: açılış varsayılan; `DEBUG_HIZLI_BASLAT` yalnız
  debug'da okunur.
- **Test ortamı** (`RABLE_SCREENSHOT`): her zaman hızlı yol — CI ve
  ekran turu akışları hiç değişmedi.

## Kayıt kuralları

Save'e `acilis: {durum, adim, g01}` paketi girer. Kayıt yüklemede
sinematik OYNAMAZ; Gün 0 yarım kaldıysa (durum ≤ 0) baştan başlar,
Gün 1 zinciri kaldığı adımdan sürer (to-do metni + kilitler + bar
görünürlüğü adıma göre geri kurulur).

## SLICETEST

Hızlı test zincirinin SONUNDA (oyun durumunu bilinçli bozduğu için):

- **Mod 1 (hızlı başlat)**: test ortamında sinematik seçilmediği,
  to-do/siyah ekran OLMADIĞI, ocağın yanık, kilidin boş, açlığın %80
  olduğu doğrulanır.
- **Mod 2 (sinematik)**: süreler `TEST_SURE_CARPAN` (0.02) ile
  kısaltılıp zincir baştan sona simüle edilir: Gün 0 kurulumu → tarif
  kilidi (`max_craftable("balta")==0`) → ocak dokunuşu → Gün 1 geçişi
  (gün=1, açlık %60, mide barı doğdu, G-01 bayrağı) → 3 meyve → defter
  → kilit açıldı → balta → kapanış (durum=2, kart kayboldu).

Son koşu: `SLICETEST: hizli(aclik=80 todo=false) sinematik(g01=true
durum=2) hata=0`. CI önemli-satır süzgecine `SLICETEST` eklendi.

## Yol boyu bulunan ve düzeltilen iki gizli bug

1. **`_fell_melt` freed-instance**: devrilme tweeni world3d'ye
   bağlıydı; ağaç görseli dışarıdan silinince (FELLTEST temizliği)
   tween her karede serbest kalmış pivot'lu lambda çağırıp motor
   hatası basıyordu — SLICETEST koşuyu uzatınca koşu başına 6 satırdan
   1122'ye çıktı. Tween pivot'a bağlandı (pivot ölünce tween ölür) +
   `_fell_melt`'e `is_instance_valid` koruması.
2. **HUD gizleme listesi**: ilk kare denemesi listede var olmayan
   düğüm adları olduğunu gösterdi (gün çipi, Ayarlar, çanta Gün 0'da
   ekranda kalıyordu) — gerçek üyelerle değiştirildi; to-do kartı da
   sağ kenardan dışarı büyüyordu, içeri alındı.

## Kareler (960x540, xvfb + opengl3, geçici RABLE_ACILIS_ONLY kısayolu)

1. `acilis_1_gun0.png` — kapkaranlık gece kampı, sönük ocak, HUD yok,
   sağda "🔥 Ocağı yak" kartı.
2. `acilis_2_alev.png` — dokunuş sonrası: alev canlanmış, ışık halkası
   büyürken, altta "…geldin." fısıltısı.
3. `acilis_3_gun1.png` — sabah, HUD geri, SADECE açlık barı (sol alt),
   to-do "🫐 Yiyecek bul (0/3)".
4. `acilis_4_defter.png` — not defteri paneli, görev metni birebir.

## Bilinen sınırlar / emanetler

- `stomach_growl` ses dosyası yok — kanca hazır, dosya gelince çalar.
- G-01 "geldin" yalnız bayrak (`g01_bayrak`); hikaye kayıtları paneli
  sonraki görev.
- Ayarlar > geliştirici "Açılışı oynat" butonu: `--acilis` argümanı
  şimdilik aynı işi görüyor; panel geldiğinde tek satır bağlanır.
- `SAVELOAD: FAIL` satırı (slots[3].count 7 vs 99) bu daldan ÖNCE de
  vardı (eski loglarla doğrulandı) — ayrı konu, backlog'a not düşüldü.
