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

## B1. RENK MODELI — UC DUZ BANT (gradyan YOK).
## Referans Longvinter: parlak, doygun, DUZ renk bantlari. Gercekci
## derinlik gradyani DEGIL. Bantlar arasi gecis SERT (stilize kademe).
## Esikler metre cinsinden su derinligi.
const BAND_SHALLOW_MAX := 0.18   # m — bu altinda sig
const BAND_MID_MAX := 0.55       # m — bu altinda orta, ustu derin
const WATER_SHALLOW := Color(0.498, 0.831, 0.847)  # #7FD4D8 acik turkuaz
const WATER_MID := Color(0.353, 0.663, 0.902)      # #5AA9E6 canli mavi
const WATER_DEEP := Color(0.231, 0.490, 0.769)     # #3B7DC4 koyu ama MAVI
## Derin renk ASLA gri/siyaha inmez — bu bilincli: onceki turda
## lacivert-siyaha yaklasan bir rampa vardi ve su "camur" gorunuyordu.

static func water_color(depth_m: float) -> Color:
	var d: float = maxf(0.0, depth_m)
	if d < BAND_SHALLOW_MAX:
		return WATER_SHALLOW
	if d < BAND_MID_MAX:
		return WATER_MID
	return WATER_DEEP

## B3. KIYI KOPUGU — karaya komsu su kenarinda dar, kirik-beyaz bant.
## Referanstaki EN BELIRGIN detay. Hucrenin ~%20'si genisliginde,
## kenar boyunca hafif duzensiz (hash ile esik oynatiliyor).
const FOAM_COLOR := Color(0.918, 0.969, 0.969)   # #EAF7F7
const FOAM_DEPTH := 0.09          # m — bu sigliktan az yer kopuk
const FOAM_JITTER := 0.035        # m — esigin duzensizlik payi

## B4. SAYDAMLIK — sigda hafif saydam, derinde opak.
const WATER_ALPHA_SHALLOW := 0.80
const WATER_ALPHA_DEEP := 1.0

static func water_alpha(depth_m: float) -> float:
	return WATER_ALPHA_SHALLOW if depth_m < BAND_SHALLOW_MAX else WATER_ALPHA_DEEP

## B4. PARILTI — yuzeyde seyrek kucuk beyaz lekeler, yavas yanip sonme.
## Kalite Dusuk'te kapali.
const SPARKLE_AMT := 0.22
const SPARKLE_SPEED := 0.5

## B5. HAREKET — cok dusuk genlikli yavas dalga (iki sinus).
## "Jole" olursa genlik yariya iner; 1.2 cm bilincli olarak dusuk.
const WAVE_AMP := 0.012
const WAVE_SPEED := 0.30

## Gece: Ocak/mesale isiginin sicak yansimasi — bant renklerine hafif
## sicak ton karisimi (shader uniform'u, gunduz 0).
const NIGHT_WARM := Color(1.0, 0.72, 0.42)
const NIGHT_WARM_MIX := 0.16

## B6. KIYI SERPINTISI — su kenarindaki KARA hucrelerine tas/cakil.
const SHORE_SCATTER_CHANCE := 35   # %

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
