# RAPOR — TAŞ YOL (serpinti modeli)

Karo tabanlı yol **devre dışı**, yerine `stone_scatter_a` serpinti modeli.
Branch: `tas-yol-scatter`.

## NEDEN MODEL DEĞİŞTİ

Karo hücreyi **tam** dolduruyordu: her yol hücresi bir kare leke. İzgara
kenarını üç katman dekorla (kenar karosu + karo üstü yosun/ot + komşu
çime saçılma) kırmaya çalıştık, tepeden bakışta yine geri geliyordu.
Serpinti modeli sorunu kaynağından çözüyor — hücrenin **içi** boşluklu,
aralardan zemin çimi görünüyor, "kenar çizgisi" diye bir şey oluşmuyor.

Karo sistemi **silinmedi, kapatıldı**: `road_tiles.gd::TILE_MODE_ON =
false`. Geri dönmek için o bayrağı `true`, `road_scatter.gd::SCATTER_ON`
değerini `false` yapmak yeterli.

## MODEL — ÖLÇÜLDÜ (tahmin değil)

`stone_scatter_a.glb`, glTF POSITION min/max'tan okundu:

| Eksen | Min | Max | Boy |
|---|---|---|---|
| X | −0,4648 | 0,4648 | **0,930** |
| Y | −0,5000 | 0,5000 | **1,000** |
| Z | −0,0518 | 0,0515 | **0,103** |

En ince eksen **Z** → model **Z-up** (Meshy standardı), görevde
öngörüldüğü gibi. Proje `.import` dosyalarını repoda tutmuyor (CI'da
üretiliyor), bu yüzden Root Rotation/Root Scale karşılığı **kodda**:

- **Root Rotation X: −90** → `RoadScatter.MODEL_Z_UP = true`, kod
  `Basis().rotated(Vector3.RIGHT, -PI/2)` uyguluyor. Yatırma sonrası
  ayak izi 0,930 × 1,000, kalınlık dünya Y'sinde 0,103 m.
- **Root Scale** → AABB'den normalize: `k = 1,0 / 1,000 = **1,00**`.
  Model zaten tam bir hücre boyunda gelmiş.

## YÜKSEKLİK (pazarlıksız şart)

- Taş üstleri çim seviyesinin **2,5 cm üstünde** (`TOP_ABOVE = 0.025`),
  gövde gömülü, gölge **cast + receive AÇIK**.
- **Hiçbir eksende yassılaştırma yok**: modelin 10,3 cm kalınlığı
  ölçekten sonra da korunuyor.
- Bu göz kararına bırakılmadı: `SCATTERTEST` (hızlı CI, her push)
  ölçülen ince ekseni `MODEL_Z_UP` ayarıyla karşılaştırıyor, ölçek
  sonrası kalınlığı ve dışarıda kalan payı basıyor; **kalınlık 5 cm
  altına düşerse veya çıkıntı 1,5 cm altına inerse CI kırmızı yanıyor.**

Ölçülen son değer: `kalinlik=0.103m disarida=0.025m`.

## İKİ TUR — İLK KARENİN SÖYLEDİKLERİ

Görev "ilk commit'te tek hücre koy, yandan doğrula, sonra devam et"
diyordu; iki görsel CI turu koştu ve ilk tur üç şeyi düzeltti:

| Sorun (1. tur karesi) | Kök neden | Düzeltme |
|---|---|---|
| Tepeden bakışta yol **dama tahtası** gibi noktalı | 0,90–1,10 ölçekte her hücrenin öbeği ayrı bir ada; komşuya değmiyor | Taban ölçek **1,08–1,32** + **derz dolgusu** |
| Taşlar fazla açık ve soğuk (leylak-beyaz) | Doku neredeyse beyaz; #B5ACA0 çarpanı yetmiyor | Ton **~#9A9084** |
| Kaçak taş kocaman | `path_stone` 1 m çapında yassı disk; 0,35–0,55 ölçekte tabak gibi | **0,20–0,32** |

**Derz dolgusu** ızgarayı asıl kıran şey: iki yol hücresinin ortak
kenarının **ortasına** küçük bir öbek daha konuyor. Köşe dolgusu işe
yaramazdı — 1 hücre genişliğindeki yolda komşuluk kenar üzerinden
oluyor, köşe hiç oluşmuyor. Ölçülen: 76 hücreye karşı **91 derz öğesi**.

## VERİ DOSYASI — `scripts/road_scatter.gd`

Tüm sayılar burada; kodda sabit yok.

| Alan | Değer | Not |
|---|---|---|
| `TOP_ABOVE` | 0.025 | taş üstü çimin üstünde (m) |
| `CAST_SHADOW` | true | hacmi okutan şey |
| `SCALE_MIN/MAX` | 1.08 / 1.32 | hücre başına ölçek |
| `OFFSET_MAX` | 0.05 | ±%5 konum oynaması (m) |
| `YAW_STEPS` | 4 | 90°'lik dönüş |
| `SEAM_SCALE_MIN/MAX` | 0.50 / 0.72 | derz dolgusu |
| `END_RUN` / `END_SCALE` | 3 / 0.70 | uç rampası |
| `END_OFFSET_EXTRA` | 0.10 | uçta ek konum oynaması |
| `TINT` | #9A9084 | sıcak bej-gri |
| `TINT_JITTER` | 0.05 | hücre başına ±%5 ton |
| `MOSS_CHANCE_YENI/MIRAS` | 20 / 40 | taş üstü yosun (%) |
| `EDGE_TUFT_CHANCE` | 35 | kenar hücresinde çim tutamı (%) |
| `STRAY_CHANCE` | 15 | 1 hücre dışına kaçak taş (%) |
| `TIER` | düşük: yosun+kaçak KAPALI | mobil |

Ton oynaması **MultiMesh örnek rengiyle** veriliyor
(`vertex_color_use_as_albedo`) — ek çizim çağrısı yok.

## UÇ KURALI — "dağılarak biter"

Terminal hücreler (4-yön komşusu ≤1) BFS ile bulunuyor, oradan geriye
`END_RUN`=3 hücre boyunca ölçek 0,70'e iniyor ve konum oynaması artıyor.
Yani yol **tek karede kesilmiyor**. Kampın güneyde yarıda biten kolu bu
kurala kendiliğinden giriyor — kamp yolları zaten aynı veriyi
(`_path_cells`) beslediği için ayrı bir geçiş kodu gerekmedi. Ölçülen:
**5 uç hücre**.

## ZEMİN — TOPRAK BOYAMA YOK (doğrulandı)

Karelerde yolun altında kahverengi bir bant görünüyor ve "toprak şerit
eklenmiş" gibi duruyor. **Yoldan gelmiyor**: `_cell_props` yol hücresinin
zemin rengine dokunmuyor (o kod önceki turda zaten kaldırılmıştı), bant
arazinin kendi toprak lekesi. Göz kararına bırakmamak için ROADTEST artık
yol hücrelerinin zemin karakteri dağılımını basıyor:

```
yol_zemin={ ".": 51, "d": 24 }
```

51 hücre çim, 24 hücre arazinin kendi toprağı — yolun boyadığı hücre 0.

## ÖLÇÜLEN SON DURUM

```
ROADTEST: model=serpinti hucre=76 (miras=65 yeni=10) kenar=73
serpinti_hucre=76 derz=91 uc_hucre=5 tutam=21 kacak_tas=17
ornek_toplam=202 kalinlik=0.103m disarida=0.025m olcek=1.08-1.32
tint=#9a9084 jitter=%5 yol_zemin={ ".": 51, "d": 24 }
moss_glb=false karo_modu=false
```

**MultiMesh**: 76 yol hücresi + 91 derz + 17 kaçak + 21 tutam =
**toplam 202 örnek, 3 çizim çağrısı** (taş / tutam / kaçak taş).

### FPS

CI yazılım rasterizasyonuyla koştuğu için FPS orada **1.0'a sabitli** —
ölçüm olarak anlamsız, bu yüzden önce/sonra FPS tablosu **verilmiyor**.
Dürüst karşılaştırma çizim çağrısı üzerinden: karo modelinde tür başına
bir MultiMesh (karo a/b/c + kenar + yosun + iki tutam + üç saçılma türü)
= **9'a kadar** çizim çağrısı; serpinti modelinde **3**.

## EKSİK KALANLAR — açıkça

1. **`tas_yol_konsept.html` repoda yok.** Proje kökünde de başka yerde de
   bulunamadı; commit geçmişinde hiç eklenmemiş. Bu yüzden görevdeki
   **(c) "aynı kare konseptle yan yana"** karesi **üretilmedi**. Diğer
   kareler (a/b/d) alındı. Dosya gelirse yan yana kare ayrıca çıkarılır.
2. **`moss_patch.glb` hâlâ yok.** Yosun kuralı yazıldı ve ölçülüyor
   (`moss_glb=false`) ama çizilecek model olmadığı için **hiç yosun
   görünmüyor**. Düz yeşil disk fallback'i bilerek kapalı: karede nilüfer
   yaprağı gibi duruyordu. Model gelince kod değişikliği olmadan devreye
   girer.

## KARELER

| Dosya | Ne |
|---|---|
| `docs/screens/3d_yol_tek_yandan.png` | (a) tek hücre yandan — yükseklik kanıtı |
| `docs/screens/3d_yol.png` | (b) kıvrımlı yol, orta mesafe |
| `docs/screens/3d_yol_tepe.png` | tepeden — ızgara kalmadı mı |
| `docs/screens/3d_yol_genis.png` | (d) kamp geneli, gündüz |
| `docs/screens/3d_yol_genis_gece.png` | (d) kamp geneli, gece |
| `docs/screens/3d_yol_gece.png` | yakın kare, gece (taş parlıyor mu) |
