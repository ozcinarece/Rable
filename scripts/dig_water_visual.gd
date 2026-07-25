extends RefCounted
## KAZI + SU GORSEL VERISI — tum renkler, esikler ve olasiliklar burada.
## Mekanik YOK: kazi derinligi dig_rules/world3d'de, su seviyesi
## water_sim'de hesaplaniyor. Bu dosya yalniz "o veri nasil GORUNSUN"
## sorusuna cevap verir.
##
## MOBIL ONCELIK: shader yerine VERI TABANLI cozum. Hucre derinligi ve
## su seviyesi zaten elimizde; renk/yukseklik farki arazi mesh'inin
## VERTEX RENGIYLE veriliyor -> ek cizim cagrisi yok, ek doku yok,
## isik hesabi yok. Bedava.

# =======================================================================
# A. KAZI
# =======================================================================

## A3. KATMAN RENKLERI — derinlige gore duvar/taban rengi.
## Gecisler NET okunmali: ust serit koyu bitkisel toprak, orta acik
## toprak, 3-4 tas grisi.
const WALL_COLORS := {
	1: Color(0.30, 0.22, 0.13),   # bitkisel toprak (koyu, humuslu)
	2: Color(0.52, 0.38, 0.24),   # alt toprak (acik, killi)
	3: Color(0.46, 0.44, 0.41),   # tas basliyor
	4: Color(0.34, 0.33, 0.32),   # kaya
}
## Derinlik verisi yoksa (0) ya da 4'un altindaysa en yakin katman.
static func wall_color(depth: int) -> Color:
	var d: int = clampi(depth, 1, 4)
	return WALL_COLORS[d]

## A4. DERINLIK KARARTMASI — taban ve alt duvarlar derinlikle koyulasir.
## Vertex renginde carpan; isik hesabi DEGIL (bedava).
## depth 1 -> 1.0 (dokunma), depth 4 -> DARKEN_MIN ("dibi gorunmuyor").
const DARKEN_MIN := 0.42
static func depth_darken(depth: int) -> float:
	var d: float = clampf(float(depth), 0.0, 4.0)
	return lerpf(1.0, DARKEN_MIN, d / 4.0)

## A1. KENAR YIGINI — kazilan hucrenin cevresine alcak toprak seti.
## "Toprak nereye gitti" sorusunun gorsel cevabi.
const RIM_RISE_MIN := 0.05      # m, kenar hucresinin dis kenarinda kabarma
const RIM_RISE_MAX := 0.08
const RIM_SCATTER_CHANCE := 40  # % soil_clump / pebble_cluster serpintisi

## A2. DUVAR EGIMI — duvarlar tam dikey degil, ustte disa acilir.
## Derece; hucre basina yatay kayma = tan(egim) * derinlik adimi.
const WALL_SLOPE_DEG := 10.0
## Derinlik 3-4'te bir ara BASAMAK (kucuk cikinti): hem dogal, hem
## "buradan tirmanilir" okumasi.
const STEP_AT_DEPTH := 3
const STEP_WIDTH := 0.18        # m, basamagin ice dogru genisligi

## A5. AGIZ SARKMASI — kenar hucrelerine cim, cukurun ICINE dogru egik.
## Keskin sinir cizgisini kiran asil sey bu.
const MOUTH_TUFT_CHANCE := 50   # %
const MOUTH_TUFT_TILT_DEG := 28.0  # cukura dogru egim
const MOUTH_TUFT_SPAN := 0.20

## A6. TABAN SERPINTISI — sigda toprak obegi, derinde tas kiymigi.
const FLOOR_SCATTER_MAX := 2    # hucre basina 0..2
const FLOOR_SHALLOW_MAX_DEPTH := 2  # bu derinlige kadar toprak, sonrasi tas
const FLOOR_SOIL := "soil_clump"
const FLOOR_ROCK := "rock_shard"

# =======================================================================
# B. SU
# =======================================================================

## B1. DERINLIK RENGI (en kritik) — su rengi SU SEVIYESI + ZEMIN
## DERINLIGI verisinden hesaplanir. TEK DUZ RENK YASAK.
## Anahtar = etkin su derinligi (m); ara degerler lerp'lenir.
const WATER_RAMP := [
	{"d": 0.00, "c": Color(0.55, 0.82, 0.72)},  # sig: acik turkuaz-yesil
	{"d": 0.45, "c": Color(0.26, 0.58, 0.74)},  # orta: mavi
	{"d": 1.10, "c": Color(0.09, 0.20, 0.42)},  # derin: koyu lacivert
]

static func water_color(depth_m: float) -> Color:
	var d: float = maxf(0.0, depth_m)
	for i in range(WATER_RAMP.size() - 1):
		var a: Dictionary = WATER_RAMP[i]
		var b: Dictionary = WATER_RAMP[i + 1]
		if d <= float(b["d"]):
			var t: float = (d - float(a["d"])) \
					/ maxf(0.001, float(b["d"]) - float(a["d"]))
			return Color(a["c"]).lerp(Color(b["c"]), clampf(t, 0.0, 1.0))
	return Color(WATER_RAMP[WATER_RAMP.size() - 1]["c"])

## B4. SAYDAMLIK — derinlikle artan opaklik; sigda zemin belli belirsiz
## secilir.
const WATER_ALPHA_SHALLOW := 0.55
const WATER_ALPHA_DEEP := 0.94
const WATER_ALPHA_FULL_DEPTH := 0.9   # m, bu derinlikte tam opak sayilir

static func water_alpha(depth_m: float) -> float:
	var t: float = clampf(depth_m / WATER_ALPHA_FULL_DEPTH, 0.0, 1.0)
	return lerpf(WATER_ALPHA_SHALLOW, WATER_ALPHA_DEEP, t)

## B2. SIGLIK/KOPUK BANDI — karaya komsu su hucrelerinin KENAR
## vertexleri aydinlatilir; kiyi cizgisi boylece yumusar.
const SHORE_LIGHTEN := 0.34     # kenar vertex'inde beyaza dogru harman
const SHORE_FOAM_TINT := Color(0.88, 0.95, 0.95)

## B6. KENAR GECISI — kara tarafinda islak zemin seridi: su komsusu olan
## kara hucresinin o kenari koyulasir (islak kum/toprak).
const WET_DARKEN := 0.72        # kara rengi carpani
const WET_BAND_CELLS := 1       # kac hucre iceri

## B3. HAREKET — cok hafif dalga. Iki sinus, DUSUK genlik, YAVAS.
## "Titresen jole" degil, "hafif kipirdayan gol".
const WAVE_AMP := 0.018         # m
const WAVE_FREQ_A := 0.9
const WAVE_FREQ_B := 1.7
const WAVE_SPEED := 0.35

## B5. PARILTI — yuzeyde seyrek parilti noktalari. Gunes yonune gore
## gunduz soguk beyaz, gece Ocak/mesale isiginda sicak ton.
const SPARKLE_CHANCE := 6       # % su hucresi basina
const SPARKLE_DAY := Color(1.0, 1.0, 0.96)
const SPARKLE_NIGHT := Color(1.0, 0.74, 0.42)
const SPARKLE_SIZE := 0.12

# =======================================================================
# C. KALITE KADEMESI
# =======================================================================
## Dusuk'te: dalga KAPALI, parilti KAPALI, serpinti %40.
const TIER := {
	"dusuk": {"wave": false, "sparkle": false, "scatter": 0.40},
	"orta": {"wave": true, "sparkle": false, "scatter": 0.70},
	"yuksek": {"wave": true, "sparkle": true, "scatter": 1.0},
}

static func tier_of(name: String) -> Dictionary:
	return TIER.get(name, TIER["yuksek"])

## Deterministik 0..1 gurultu (chunk yeniden kurulunca desen degismesin).
static func hash01(x: int, y: int, salt: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	return float(absi(h) % 100003) / 100003.0
