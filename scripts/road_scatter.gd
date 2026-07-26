extends RefCounted
## TAS YOL — SERPINTI MODELI (stone_scatter_a).
##
## ONCEKI MODEL (karo tabanli, road_tiles.gd) DEVRE DISI. Karo yaklasimi
## hucre basina TAM DOLU bir kare kapatiyordu; izgara kenari her turlu
## dekorla kirilmaya calisilsa da tepeden bakista geri geliyordu ve yol
## "dosenmis kaldirim" gibi duruyordu. Serpinti modeli sorunu kaynagindan
## cozuyor: hucrenin ICI zaten bosluklu -> aralardan ZEMIN CIMI gorunuyor,
## kenar cizgisi diye bir sey olusmuyor.
##
## Karo sistemi SILINMEDI, bayrakla kapatildi (road_tiles.TILE_MODE_ON).
##
## OLCUM (GLB'den okundu, tahmin degil):
##   stone_scatter_a  X[-0.4648..0.4648]=0.930  Y[-0.5..0.5]=1.000
##                    Z[-0.0518..0.0515]=0.103
##   -> ince eksen Z, yani model Z-UP (Meshy standardi). Kaynak dosyaya
##      dokunmadan kod tarafinda X:-90 dondurulur (proje .import
##      dosyalarini repoda tutmuyor, CI'da uretiliyor).
##   -> donusten sonra ayak izi 0.930 x 1.000, KALINLIK 0.103 m.
##   -> 1 hucreye oturtmak icin kok olcegi k = 1.0 / 1.000 = 1.00
##      (model zaten tam hucre boyunda gelmis).

## Ana anahtar. false yapilirsa eski karo sistemi geri doner.
const SCATTER_ON := true

const MODEL_ID := "stone_scatter_a"
const MODEL_PATH := "res://assets/models/env/stone_scatter_a.glb"
## Model Z-up geldi (olculdu): zemine yatirmak icin X ekseninde -90.
const MODEL_Z_UP := true
## Hedef ayak izi (m). 1 hucre = 1 m.
const CELL_SPAN := 1.0

# =======================================================================
# YUKSEKLIK — PAZARLIKSIZ
# =======================================================================
## Tas USTLERI cim seviyesinin bu kadar USTUNDE kalir (m).
## Govde gomulur; disarida kalan kisim bu deger. Zemine EZILMIS duz leke
## olmamasinin sarti: modelin kendi kalinligi (0.103 m) korunur, hicbir
## eksende yassilastirma YOK — yalnizca Y'de asagi kaydirilir.
const TOP_ABOVE := 0.025
## Golge: hacmi okutan sey. Serpinti tas TEK gorsel katman oldugu icin
## golgesiz halde zemine cizilmis desen gibi duruyor.
const CAST_SHADOW := true

# =======================================================================
# HUCRE BASINA VARYASYON — tekrar hissini kirar
# =======================================================================
const YAW_STEPS := 4              # 0/90/180/270
const SCALE_MIN := 0.90
const SCALE_MAX := 1.10
const OFFSET_MAX := 0.05          # hucre geniskiginin ±%5'i (m)

# =======================================================================
# UC HUCRELER — yol "dagilarak biter"
# =======================================================================
## Terminalden bu kadar hucre geriye kadar kuculme rampasi uygulanir.
## (Gorevdeki "guney kolun son 2-3 hucresi" bu rampayla saglanir.)
const END_RUN := 3
## Terminal hucrede olcek carpani; rampa boyunca 1.0'a dogru acilir.
const END_SCALE := 0.70
## Uc hucrelerde EK konum oynamasi (m) — hiza bozulsun, yol dagilsin.
const END_OFFSET_EXTRA := 0.10

# =======================================================================
# RENK — model cok beyaz/soguk geldi
# =======================================================================
## Sicak bej-gri (#B5ACA0). Albedo CARPANI olarak uygulanir.
const TINT := Color(0.710, 0.675, 0.627)
## Hucre basina ±%5 ton oynamasi: MultiMesh ornek RENGI ile, ek cizim
## cagrisi YOK (materyalde vertex_color_use_as_albedo aciliyor).
const TINT_JITTER := 0.05

# =======================================================================
# DOKU ZENGINLIGI — az ve oz
# =======================================================================
## Taslarin USTUNE yosun lekesi.
const MOSS_CHANCE_YENI := 20      # %
const MOSS_CHANCE_MIRAS := 40     # %
## Cim tutami YALNIZ kenar hucrelerinde, hucre basina 0-1, tas kenarina
## bitisik. Yol ICINE ot EKLENMEZ: zemin cimi aralardan zaten goruluyor.
const EDGE_TUFT_CHANCE := 35      # %
const EDGE_TUFT_SPAN := 0.18      # m — acik cimdekinden kucuk filiz
## Yolun 1 hucre DISINA kacak tas. Fazlasi dagitiklik yapiyor (onceki
## turun dersi: 2 hucreye de sacilinca yol "dokulmus" gorunuyordu).
const STRAY_CHANCE := 15          # %
const STRAY_SCALE_MIN := 0.35
const STRAY_SCALE_MAX := 0.55

# =======================================================================
# KALITE KADEMESI (mobil)
# =======================================================================
## Dusuk'te yosun ve kacak tas KAPALI — yol taslari kalir, yol okunur.
const TIER := {
	"dusuk": {"moss": false, "stray": false, "tuft": 0.5},
	"orta": {"moss": true, "stray": true, "tuft": 0.8},
	"yuksek": {"moss": true, "stray": true, "tuft": 1.0},
}

static func tier_of(name: String) -> Dictionary:
	return TIER.get(name, TIER["yuksek"])

static func moss_chance(age: String) -> int:
	return MOSS_CHANCE_MIRAS if age == "miras" else MOSS_CHANCE_YENI

## Deterministik 0..1 gurultu — harita yeniden kurulunca desen degismesin.
static func hash01(x: int, y: int, salt: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	return float(absi(h) % 100003) / 100003.0
