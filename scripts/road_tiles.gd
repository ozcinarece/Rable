extends RefCounted
## TAS YOL KAROLARI — auto-tiling verisi ve olasiliklari.
## YALNIZ GORSEL/veri; yol hucresinin kendisi world3d'de `_path_cells`.
##
## OLCULDU (glTF POSITION min/max): uc karonun da tabani tam 1.0 x 1.0,
## kalinlik Z'de ~0.10. Yani karolar XY duzleminde modellenmis (dik
## duruyorlar) — planting_mound'daki durumun aynisi. Zemine yatirmak icin
## X'te -90 derece. Taban zaten hucre boyunda oldugu icin ek olcek yok;
## yine de kod AABB'den normalize eder (model degisirse bozulmasin).

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
## yuzey, altina giren hicbir sey cizilmiyor; "cim kenarinin ustune
## tasmasi" ayri bir geometri degil.
## Dogrusu: karo govdesi zemine GOMULUR, yalnizca ust yuzu bu kadar
## DISARIDA kalir. Ince bir dilim gorundugu icin karo yere basmis
## hissi verir, kaldirim tasi gibi yukselmez.
const TOP_ABOVE := 0.02

# --- KENAR ERIMESI ------------------------------------------------------
## Karo ustune cikan bitki (yol kenari hucrelerinde).
const EDGE_MOSS_CHANCE := 50    # % moss_patch
const EDGE_TUFT_CHANCE := 40    # % grass_tuft
## Yol kenarindaki ot, acik cimdeki serpintiden KUCUK olmali: taslarin
## arasindan cikan filiz, cim obegi degil (ilk karede kocaman ve neon
## yesil ciktı).
const EDGE_TUFT_SPAN := 0.18

## Komsu CIM hucrelerine sacilma: izgaranin duz sinirini kirar. Kosegen
## yollarda merdiven gorunumunu yok eden asil sey bu sacilmadir.
const SPILL_D1_CHANCE := 35     # 1 hucre uzak
const SPILL_D2_CHANCE := 12     # 2 hucre uzak
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
const TILE_TINT := Color(0.60, 0.57, 0.52)
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
