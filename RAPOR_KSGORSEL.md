# RAPOR — Kazı ve Su Görsel Kalite Turu (branch: `kazi-su-gorsel`)

Tarih: 2026-07-25 · Kapsam: **yalnız görsel katman**. Kazı derinliği
`dig_rules`/`world3d`'de, su seviyesi `water_sim`'de — ikisinin de
**mantığına dokunulmadı**. Bu tur o veriyi okuyup "nasıl görünsün"
sorusunu cevaplıyor.

Tüm renk ve eşik değerleri tek dosyada: **`scripts/dig_water_visual.gd`**.

---

## Yöntem kararı: shader değil, vertex verisi

Mobil önceliği gereği her maddede önce veri tabanlı çözüm arandı. Hücre
derinliği ve su seviyesi zaten elimizde olduğu için renk farkları arazi
ve su mesh'inin **vertex rengine** yazılıyor: ek çizim çağrısı yok, ek
doku yok, ışık hesabı yok.

Bu, su tarafında shader'ı **hafifletti**: B1/B2/B4 önceden fragment
shader'ında hesaplanıyordu (iki renk karışımı + smoothstep'li köpük),
şimdi mesh üretiminde bir kez hesaplanıp `COLOR`'a yazılıyor. Shader'da
kalan tek iş dalga (vertex) ve parıltı (yalnız Yüksek kademede).

---

## A. KAZI

| # | Ne yapıldı | Değerler |
|---|---|---|
| A1 | Kenar yığını: kazılmış hücrenin kazılmamış komşusu kabarıyor + üstüne serpinti | 5–8 cm (hücreye göre değişken), %40 serpinti |
| A2 | Duvar eğimi + derinde basamak | 10°, basamak derinlik 3'ten sonra, +0.18 bant |
| A3 | Katman renkleri | 1 humus `#4D3821` · 2 alt toprak `#856149` · 3 taş `#75706A` · 4 kaya `#575452` |
| A4 | Derinlik karartması | çarpan 1.0 → **0.42** (depth 4) |
| A5 | Ağız sarkması: çukura eğik çim | %50, 28° eğim, 20 cm |
| A6 | Taban serpintisi | hücre başına 0–2; depth ≤2 toprak öbeği, >2 taş kıymığı |

**A2 notu:** duvar eğimi için sert 0/1 adım yerine **dar** bir smoothstep
bandı kullanıldı. Bant bilerek dar tutuldu — bu kod yolunda daha önce
smoothstep denenip geri alınmış ("mesh köşeleri 1/res aralıklarla
örnekleniyor, geniş bant bulanık leke veriyor" notu duruyor). 10°,
0.18'lik banda denk geliyor ve bulanma eşiğinin altında.

**A1 notu:** yığının kendisi arazi yüksekliğinde (`_rim_cells` →
`_cell_props`), serpinti ayrı MultiMesh. Kabarma miktarı hücreye göre
deterministik değişiyor; düz bir set değil, doğal bir yığın.

---

## B. SU

| # | Ne yapıldı | Değerler |
|---|---|---|
| B1 | Derinlik rengi (rampa, tek düz renk değil) | 0.00 m turkuaz-yeşil `#8CD1B8` · 0.45 m mavi `#4294BD` · 1.10 m lacivert `#17336B` |
| B2 | Sığlık/köpük bandı | kıyıya 0.16 m kalana kadar, %34 beyazımsı |
| B3 | Dalga | iki sinüs, genlik 1.8 cm, hız 0.35 |
| B4 | Saydamlık | alpha 0.55 (sığ) → 0.94 (0.9 m ve derini) |
| B5 | Parıltı | %6 yoğunluk; gündüz soğuk beyaz, gece sıcak ton |
| B6 | Kenar geçişi: ıslak kıyı şeridi | kara rengi ×0.72, 1 hücre içeri |

Derinlik **araziden** metre cinsinden ölçülüyor, hücre zikzağı oluşmuyor.
`_wet_cells` bir kez hesaplanıp tabloya yazılıyor — `_cell_props` çok sık
çağrıldığı için orada komşu taraması yapmak pahalı olurdu (aynı kalıp
`_edge_blend`'de de kullanılmıştı).

---

## C. Performans / kalite kademesi

| Kademe | Dalga | Parıltı | Serpinti |
|---|---|---|---|
| Düşük | **kapalı** | **kapalı** | %40 |
| Orta | açık | kapalı | %70 |
| Yüksek | açık | açık | %100 |

Kademe shader uniform'larına bağlı (`_apply_water_tier`); Ayarlar'dan
değişince yeniden uygulanıyor. Düşük'te `wave_amp = 0` ve
`sparkle_amt = 0` — ikisi de tamamen kapalı, dallanma bile yok.

---

## Yol boyunca düşülen tuzak — ve CI katmanlamasının ilk gerçek işi

B commit'inde shader'ı değiştiren betik `s.index()` ile **ilk** eşleşmeyi
buldu; o da **deniz** shader'ıydı (`_water_material`). Kesit deniz
shader'ının başından göl materyaline kadar uzandı ve arada duran
`var _lake_mat` ile `func _lake_material()` tanımlarını sildi. Sonuç:
`world3d.gd` parse hatası, oyun hiç yüklenmedi.

Bunu **hızlı CI katmanı yakaladı** (`_lake_mat not declared`, iki koşu
kırmızı). Ağır koşu ise 480 sn tavanında yandı ve **tek bir kare
üretmedi** — commit adımı "değişiklik yok" dedi. Yani katmanlama
olmasaydı hata ancak boş kare klasöründen anlaşılacaktı. Aynı gün
kurulan parse kontrolü ilk gerçek işini böyle gördü.

Düzeltme: deniz materyali orijinal haline döndü, göl shader'ı yalnız
`_lake_material` içine uygulandı.

---

## Açık kalan: önce/sonra kareleri

**Bu rapor karesiz.** Görev "aynı hendek + aynı gölet, gündüz ve gece"
karşılaştırması istiyor; bunun için kazılmış bir hendeğe ve göle
kilitlenen **ayrı bir kamera geçişi** gerekiyor — mevcut `3d_kazi.png`
kamp genel görünümü, hendek yakın planı değil.

"Önce" tarafı için yeni bir koşuya gerek yok: `tas-yol-fix` dalındaki
`docs/screens/3d_kazi.png` bu turdan önceki hâli taşıyor, referans o.
Eksik olan "sonra" tarafının doğru kadrajı. Sıradaki adım bu kamera
geçişini eklemek (hendek yakın plan + göl kıyısı, gündüz ve gece) ve
tabloyu kareyle kapatmak.
