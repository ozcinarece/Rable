extends RefCounted
## TAS YOL KAROLARI — auto-tiling verisi ve olasiliklari.
## YALNIZ GORSEL/veri; yol hucresinin kendisi world3d'de `_path_cells`.
##
## OLCULDU (glTF POSITION min/max): uc karonun da tabani tam 1.0 x 1.0,
## kalinlik Z'de ~0.10. Yani karolar XY duzleminde modellenmis (dik
## duruyorlar) — planting_mound'daki durumun aynisi. Zemine yatirmak icin
## X'te -90 derece. Taban zaten hucre boyunda oldugu icin ek olcek yok;
## yine de kod AABB'den normalize eder (model degisirse bozulmasin).

## DEVRE DISI — bu sistem artik cizilmiyor. Yerine SERPINTI modeli geldi
## (road_scatter.gd + stone_scatter_a.glb). Sebep: karo hucreyi TAM
## dolduruyor, yani her yol hucresi bir kare leke; izgara kenari uc katman
## dekorla kirilmaya calisildi ama tepeden bakista geri geliyordu.
## Serpinti modelinde hucrenin ICI bosluklu, aralardan zemin cimi
## goruluyor ve "kenar cizgisi" diye bir sey olusmuyor.
##
## SILINMEDI, KAPATILDI: geri donus sigortasi. true yapmak + road_scatter
## .SCATTER_ON'u false yapmak eski gorunumu aynen geri getirir.
const TILE_MODE_ON := false

const PATHS := {
	"road_tile_a": "res://assets/models/test/road_tile_a.glb",
	"road_tile_b": "res://assets/models/test/road_tile_b.glb",
	"road_tile_c": "res://assets/models/test/road_tile_c.glb",
	# HENUZ REPODA YOK — dosya gelince otomatik devreye girer, yoksa
	# kenar hucreleri normal varyantla cizilir (asagida FALLBACK notu).
	"road_tile_edge": "res://assets/models/test/road_tile_edge.glb",
	# HENUZ REPODA YOK — yoksa proseduerel yassi yosun lekesi kullanilir.
	"moss_patch": "res://assets/models/env/moss_patch.glb",
}

const VARIANTS: Array[String] = ["road_tile_a", "road_tile_b", "road_tile_c"]

## Karo hedef genisligi (hucre = 1 birim). Karo hucreyi TAM doldurmali,
## yoksa aralarindan cim sizar ve izgara gorunur.
const TILE_SPAN := 1.0

## GOMUK YOL. DIKKAT — ilk denemede karonun UST YUZU zeminin 2.5 cm
## ALTINA konuldu ve karolar TAMAMEN gorunmez oldu: arazi kesintisiz bir
## yuzey, altina giren hicbir sey cizilmiyor.
## Sonra 2 cm'ye cikarildi ama bu sefer karolar zemine EZILMIS gorundu:
## levha kabartisi ve derz golgeleri kayboldu, yol duz gri lekeye dondu.
## Simdi karo govdesi gomulu, UST YUZU 3.5 cm disarida — kabarti ve
## derzler golge aliyor, ama kaldirim tasi gibi de yukselmiyor.
const TOP_ABOVE := 0.035
## Karo GOLGE ALIP VERSIN: derz golgeleri hacmi okutan sey. MultiMesh'te
## golge varsayilan olarak kapaliydi (mobil butcesi); yol icin aciyoruz —
## yol hucre sayisi sinirli, maliyeti serpintininki gibi degil.
const TILE_SHADOWS := true

# --- KENAR ERIMESI ------------------------------------------------------
# YONTEM DEGISTI. Once kenari koyu bir TOPRAK HALESIYLE yumusatmayi
# denedik (zemin renk lekesi); yol kirli ve bulanik gorundu, hale
# kaldirildi. Dogru yontem: cim karonun USTUNE BINSIN — silueti kiran
# sey golge degil, karonun kenarini ortan gercek bitki.

## Kenar hucresinde cim karonun UZERINE biner (kenar cizgisini kirar).
const EDGE_OVERLAP_CHANCE := 60   # % grass_tuft, karo kenarinda
## Derz araligindan cikan bitki — HER yol hucresinde, karo yuzeyinde.
const JOINT_TUFT_CHANCE := 30     # % grass_tuft
const JOINT_MOSS_CHANCE := 25     # % moss_patch (miras yolda daha yogun)
## Yol otu, acik cimdeki serpintiden KUCUK: taslarin arasindan cikan
## filiz, cim obegi degil (ilk karede kocaman ve neon yesil ciktı).
const EDGE_TUFT_SPAN := 0.18
const JOINT_TUFT_SPAN := 0.13

## Komsu CIM hucrelerine sacilma. AZALTILDI: onceki degerler "yol
## dagilmis" gorunumu veriyordu; istenen "yol eskimis". Yalniz 1 hucre.
const SPILL_D1_CHANCE := 20     # 1 hucre uzak
const SPILL_D2_CHANCE := 0      # 2 hucre: kapali
const SPILL_SCALE_MIN := 0.8
const SPILL_SCALE_MAX := 1.2

## Sacilan model havuzu (yol kenarindan kopmus tas + cakil).
const SPILL_MODELS: Array[String] = ["path_stone", "pebble_cluster"]

# --- YOSUN DAGILIMI (eski/yeni ayrimi gorselden okunsun) ----------------
## MIRAS yol: uzun sure once dosenmis, aralari yosun tutmus.
## YENI yol: oyuncunun az once dosedigi, neredeyse temiz.
const MOSSY_MIRAS := 40         # % yosunlu tas varyanti + yogun yosun
const MOSSY_YENI := 5
## Miras yolda yosun lekesi yogunluk carpani (EDGE_MOSS_CHANCE uzerine).
const MOSS_DENSITY_MIRAS := 1.0
const MOSS_DENSITY_YENI := 0.15

## Karo tonu: Meshy dokusu acik geliyor (ayni tuzak), sicak griye cekilir.
## 0.60 gri-yesil zeminle ayni tona dusuyordu; bej-griye cekildi:
## cimden ayrisir ama parlamaz.
const TILE_TINT := Color(0.78, 0.72, 0.62)
const TILE_TINT_MOSSY := Color(0.64, 0.70, 0.56)
## moss_patch GLB'si repoda YOK. Proseduerel yassi disk denendi ve
## KARELERDE NILUFER YAPRAGI gibi durdu (duz yesil cokgen, zemine
## yapistirilmis). Duz renk fallback bu model icin uygun degil ->
## yosun, GERCEK model gelene kadar hic cizilmiyor.
const MOSS_FALLBACK_ON := false

static func path_of(id: String) -> String:
	return String(PATHS.get(id, ""))

static func has_model(id: String) -> bool:
	var p := path_of(id)
	return p != "" and ResourceLoader.exists(p)

## Yolun yasina gore yosunlu varyant olasiligi (%).
static func mossy_chance(age: String) -> int:
	return MOSSY_YENI if age == "yeni" else MOSSY_MIRAS

static func moss_density(age: String) -> float:
	return MOSS_DENSITY_YENI if age == "yeni" else MOSS_DENSITY_MIRAS

## Deterministik 0..1 gurultu (yol yeniden kurulunca karolar degismesin).
static func hash01(x: int, y: int, salt: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	return float(absi(h) % 100003) / 100003.0
