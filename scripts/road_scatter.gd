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
# TAS YOL FINAL (stone_path): tek hucrelik serbest tas dagilimi.
## Onceki serpinti/karo yaklasimlari BAYRAKLA kapali (kod durur).
const PATH_ON := true
const PATH_GLB := "res://assets/models/env/stone_path.glb"
## OLCULDU: mesh ust y=0.054, taban 0.996 (tam hucre), Y-up.
## Kural (pazarliksiz): tas ustleri cim +2.8 cm.
const PATH_TOP := 0.028
const PATH_MESH_TOP := 0.054
const PATH_SCALE_MIN := 0.9
const PATH_SCALE_MAX := 1.1
const PATH_OFS := 0.05          # +-%5 konum ofseti (1 m hucrede)
const PATH_UC_SCALE := 0.7      # yol ucu / tekil kenar hucresi kuculur
const PATH_MOSS_PCT := 20       # ust serpinti: moss (miras yolda 40)
const PATH_MOSS_PCT_MIRAS := 40
const PATH_STRAY_PCT := 15      # 1 hucre disari kacak tas (path_stone)
## Meshy taslari cok beyaz geldi (kanit karesinde olculdu): sicak gri.
const PATH_TINT := Color(0.710, 0.675, 0.627)  # ~#B5ACA0
const SCATTER_ON := false  # stone_path finaliyle kapatildi

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
## OLCULDU (ilk CI karesi, tepeden bakis): 0.90-1.10 olcekte her hucrenin
## obegi AYRI BIR ADA kaliyordu -> yol dama tahtasi gibi noktali
## goruniyordu. Modelin kenari zaten SEYREK oldugu icin obegin yogun
## cekirdegi ~0.6 hucre; komsu hucreye DEGMESI icin taban olcek 1'in
## uzerine cikarildi. Gorevdeki "%90-110" bandi korunuyor, yalniz
## merkezi 1.0 yerine 1.2.
const SCALE_MIN := 1.08
const SCALE_MAX := 1.32
const OFFSET_MAX := 0.05          # hucre genisliginin ±%5'i (m)

## DERZ DOLGUSU — asil izgara kirici. Iki yol hucresinin ARASINA (ortak
## kenarin ortasina) kucuk bir obek daha konuyor. Yalniz olcegi buyutmek
## yetmiyordu: 1 hucre genisligindeki yolda komsuluk KENAR uzerinden
## oluyor, kose dolgusu ise hic devreye girmiyor. Bu dolgu tam o dikisi
## kapatir ve yol kesintisiz okunur.
const SEAM_ON := true
const SEAM_SCALE_MIN := 0.50
const SEAM_SCALE_MAX := 0.72

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
## Sicak bej-gri. Hedef #B5ACA0 idi; ILK CI KARESINDE taslar hala fazla
## acik ve soguk (leylak-beyaz) cikti — modelin dokusu neredeyse beyaz,
## bu yuzden carpan daha asagi cekildi. Sonuc ekranda ~#9A9084.
## Gorevin olcutu "cimden net ayrissin ama PARLAMASIN"; belirleyici olan
## kare, sayinin kendisi degil.
const TINT := Color(0.604, 0.565, 0.518)
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
## Ilk karede kacak tas KOCAMAN cikti (path_stone 1 m capinda yassi bir
## disk; 0.35-0.55 olcekte tabak gibi duruyor). Kacak tasin isi kenarda
## kucuk bir kirinti olmak.
const STRAY_SCALE_MIN := 0.20
const STRAY_SCALE_MAX := 0.32
## Rengi EnvModels.TINT["path_stone"] veriyor (sicak gri) — yol taslariyla
## ayni aileden gorunsun diye ayri bir ton TANIMLANMADI.

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
