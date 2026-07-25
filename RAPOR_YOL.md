# RAPOR — Taş Yol Sistemi (branch: `tas-yol`)

Tarih: 2026-07-25 · Kapsam: auto-tiling taş yol + kenar erimesi.
Yalnız görsel/veri; yolun yürüme, hız veya yol bulma etkisi **yok**.

---

## 1. Yol bir zemin türü

`_path_cells[hücre] = yaş` (`"miras"` | `"yeni"`). Zemin rengini
`_cell_props` okur; üzerine döşenen karoları `_build_road()` kurar.
Yol döşemenin tek kapısı `lay_road(hücre, yaş)`:

- Harita sınırının dışına, **suya** ve **platoya** döşemez (karo yamaca
  oturmaz, havada kalırdı).
- Hücredeki ağaç/kayayı temizler. Bu, taban anlık görüntüsünden **önce**
  çalıştığı için kayıt "ağaç silinmiş" deltası yazmıyor.

**Karo seçimi** hücreden deterministik hash ile: varyant `a`/`b`/`c` +
0/90/180/270 dönüş. Harita yeniden kurulunca desen değişmez.

**Ölçüldü:** üç karonun da tabanı tam `1.0 × 1.0`, kalınlık Z'de ~0.10.
Yani karolar **XY düzleminde** modellenmiş (dik duruyorlar) —
`planting_mound`'daki durumun aynısı. Zemine yatırmak için kök düğümde
X'te **−90°**. Taban zaten hücre boyunda olduğu için ek ölçek yok; kod
yine de AABB'den normalize ediyor ki model değişirse bozulmasın.

### Gömük yol — ilk denemede karolar hiç görünmedi

Görev "karo çim seviyesinin 2-3 cm **altına** otursun" diyordu. Bunu
karonun **üst yüzünü** 2.5 cm aşağı koyarak uyguladım ve karolar
tamamen kayboldu. Sebep: arazi kesintisiz bir yüzey, altına giren hiçbir
şey çizilmiyor; "çim kenarının yolun üstüne taşması" da ayrı bir geometri
değil, o his karonun **ince görünmesinden** geliyor.

Doğrusu: karo **gövdesi** zemine gömülür, yalnızca üst yüzü `TOP_ABOVE`
(2 cm) dışarıda kalır. İnce bir dilim göründüğü için karo yere basmış
durur, kaldırım taşı gibi yükselmez.

---

## 2. Kenar erimesi — üç katman

Izgaraya döşenmiş kare karolar kenarda merdiven gibi görünür. Üç katman:

1. **Kenar karosu.** Komşusunda yol olmayan hücre `road_tile_edge`
   kullanır, kırık tarafı dışa dönük (yaw = açık yönün indeksi × 90°).
   *Kural:* yalnızca **tam bir tarafı** açıkken. İki+ tarafı açık dar
   yolda tek karoyla iki kenar birden kırılamaz; orada normal varyant +
   ağır dekor devreye girer. Bu yüzden gösteri yolu **3 hücre geniş**
   yapıldı — 2'de her hücrenin en az iki yanı açık kalıyor, iç karo hiç
   oluşmuyor ve auto-tiling'in yarısı sınanmıyordu.
2. **Karo üstü bitki.** Kenar hücrelerine %50 yosun + %40 ot tutamı,
   hücrenin **açık tarafına** kaydırılmış (ortada değil — "araladan
   çıkan ot" hissi). Kenar otu açık çimdekinden küçük: 34 → **18 cm**,
   taşların arasından çıkan filiz olmalı, çim öbeği değil.
3. **Komşu çime saçılma.** 1 hücre uzağa %35, 2 hücre uzağa %12
   olasılıkla `path_stone` / `pebble_cluster`, rastgele dönüş ve
   %80–120 ölçekle. **Izgaranın düz sınırını asıl kıran budur** — karo
   hizasının dışına taştığı için göz "ızgara" görmüyor. Saçılma yalnız
   boş, kazılmamış, yürünebilir zemine düşer.

---

## 3. Yosun dağılımı: eski/yeni ayrımı

| | Yosunlu taş varyantı | Yosun yoğunluğu |
|---|---|---|
| **Miras** yol (haritadan gelen) | %40 | 1.0× |
| **Yeni** yol (oyuncunun döşediği) | %5 | 0.15× |

Fark hiçbir arayüz olmadan görselden okunuyor. Kampın kuzeydoğusuna
kısa bir "yeni" yol döşendi ki iki durum aynı karede karşılaştırılabilsin.

**Açık nokta:** oyuncunun yol döşemesi için henüz **arayüz/tarif yok**.
`lay_road(hücre, "yeni")` API'si hazır ve çalışıyor; ona bağlanacak
yerleştirme modu + tarif ayrı bir iş. Bu turda "yeni yol" verisi
doğrudan dünya kurulumunda üretiliyor ki görsel fark kanıtlanabilsin.

---

## 4. Performans

Hepsi MultiMesh: karo türü başına bir düğüm (en çok 4), yosun bir, ot
bir, saçılma türü başına bir. Yoğunluk kalite kademesine bağlı
(`SCATTER_TIER_MULT`; düşük telefonda %35'e iner).

```
PERFTEST: ONCE draw=152 | SONRA draw=212 ... yol_karo_dugum=7
ROADTEST: hucre=72 (miras=62 yeni=10) kenar=71 tek_acik=15
          karo_ornek=133 sacilma=39 edge_glb=false moss_glb=false
```

**FPS rakamı verilmedi, çünkü dürüst değil:** CI sanal ekranda yazılım
rasterleştirme ile koşuyor, ölçüm önce de sonra da 1.0'a sabitleniyor.
Çizim çağrısı donanımdan bağımsız olduğu için ölçüt o. Gerçek FPS
telefonda Ayarlar'daki overlay ile yol üstünde/dışında karşılaştırılmalı.

---

## 5. Eksik assetler

Kod ikisini de `ResourceLoader` ile arıyor; dosya repoya girdiği an
kendiliğinden devreye giriyor, kod değişikliği gerekmiyor.

- **`road_tile_edge.glb` yok.** Kenar hücreleri şimdilik normal varyantla
  çiziliyor; kenar erimesini 2. ve 3. katman taşıyor. `edge_glb=false`
  ROADTEST'te görünüyor.
- **`moss_patch` yok.** Prosedürel yassı disk denendi ve karede **nilüfer
  yaprağı** gibi durdu (düz yeşil çokgen, zemine yapıştırılmış). Düz renk
  fallback bu model için uygun değil → yosun, gerçek model gelene kadar
  **hiç çizilmiyor**. Yosunlu *taş varyantı* (`path_stone_mossy`) zaten
  var ve eski/yeni farkını taşıyor.

---

## 6. Ekran görüntüleri

- `docs/screens/3d_yol.png` — kıvrımlı yolun kenar geçişi, yakın kare.
- `docs/screens/3d_yol_genis.png` — kavisin tamamı + kampla bağlantısı.

## 7. Yol boyunca düşülen tuzaklar

- Karonun üst yüzünü zeminin altına koymak (yukarıda) — karolar görünmez.
- Kavis `sin(t·π·1.4)` ile çizilince yol gidip **geri** dönüyor, karede
  çatallanmış bir "lambda" gibi görünüyordu. Monoton çeyrek daire
  (`sin(t·π/2)`) okunaklı bir kavis veriyor.
- Kavisli yol ormanın içinden geçtiği için ilk karede **ağaçlar
  karoların üstünde** bitiyordu; `lay_road` artık hücreyi boşaltıyor.
- Karo tonu 0.74 çarpanıyla hâlâ çok açıktı (Meshy'nin bilinen "ışık
  pişmiş" albedo'su) → 0.60.
