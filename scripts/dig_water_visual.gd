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
## OLCULDU: gol yuzeyi LAKE_Y = -0.15, gol dibi -0.40 -> EN DERIN NOKTA
## yalnizca 0.25 m. Ilk esikler (0.18 / 0.55) gercek dunyaya gore
## secilmisti ve "derin" bandi ULASILAMAZ kaliyordu; gol tek duz acik
## cyan gorunuyordu. Esikler gercek derinlik araligina olceklendi.
const BAND_SHALLOW_MAX := 0.08   # m — bu altinda sig
const BAND_MID_MAX := 0.17       # m — bu altinda orta, ustu derin
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
## Kopuk bandi da ayni olcege cekildi: 0.09 m gercek gol derinliginin
## ucte biriydi, kiyi halkasi kocaman cikiyordu.
const FOAM_DEPTH := 0.035         # m — bu sigliktan az yer kopuk
const FOAM_JITTER := 0.012        # m — esigin duzensizlik payi

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


# =======================================================================
# C2. SU SHADER V1 (assets/models/env/water.gdshader) — VERI SOZLESMESI
# =======================================================================
## V2 NOTU (su-shader-v2): shader dosyasi v2'ye guncellendi — vertex'te
## 3 yonlu gercek dalga (wave_amplitude/frequency/time_scale uniform'lari,
## sayilar SHADER varsayilanlarinda: prototipten 0.09/1.9/1.45) ve dalga
## egiminin fragment normaline katilmasi eklendi. MESH SOZLESMESI
## (COLOR/UV/CUSTOM0 + asagidaki sabitler) DEGISMEDI; bant renkleri de
## ayni, WATERCOLORTEST replikasi gecerli. CUSTOM0 fragment'ta okunamaz
## (4.7) — v_flow_dir varying duzeltmesi v2'ye de tasindi.
## Bayrak: false -> eski yol birebir geri (CPU-pisirme _water_rgba +
## world3d icindeki eski satir-ici shader). Gorev sarti: geri donulebilir.
const SU_SHADER_V1 := true
## COLOR.r = derinlik_m / V1_DEEP_M (0..1). Test derinlikleri bantlara
## guvenli oturur: 0.14m->0.23 sig, 0.35m->0.58 orta, 0.90m->1.0 derin.
const V1_DEEP_M := 0.60
## COLOR.g = 1 - derinlik_m / V1_SHORE_M (eski kiyi rampasiyla ayni olcek).
const V1_SHORE_M := 0.22
## UV = dunya xz / bu deger (desen hucre yereli DEGIL, sozlesme geregi).
const V1_UV_OLCEK := 8.0
## Kopuk replikasi esigi: shore_f bunun ustundeyse kopuk bolgesi.
## v2.1: foam_width 0.35 -> 0.16 (ince bant) — esik shore_f olceginde
## 1 - foam_width. Kopuk artik foam_break ile kesikli oldugundan replika
## "kopuk BOLGESI" der, "her pikselde kopuk" demez.
const V1_FOAM_ESIK := 0.84
const V1_FOAM_COLOR := Color(0.918, 0.969, 0.969)
## Shader bant sabitlerinin BIREBIR kopyasi (water.gdshader varsayilanlari).
## Ikisi TEK SOZLESME: shader degisirse burasi da degisir, WATERCOLORTEST
## kirmizi yanar — kirmizi-su sinifinin v1 sigortasi.
const V1_SHALLOW := Color(0.498, 0.831, 0.847)
const V1_MID := Color(0.353, 0.663, 0.902)
const V1_DEEP := Color(0.231, 0.490, 0.769)
const V1_BAND1 := 0.33
const V1_BAND2 := 0.66
const V1_BAND_SOFT := 0.03
const V1_ALPHA_SIG := 0.72
const V1_ALPHA_DERIN := 0.94
## Akis isareti tazeligi (ms): boru transferi bu suredir olduysa hucre
## "akan" cizilir (mesh zaten seviye degisiminde yeniden kurulur).
const V1_AKIS_TAZE_MS := 4000

static func v1_encode(depth_m: float, flow: float = 0.0) -> Color:
	return Color(clampf(depth_m / V1_DEEP_M, 0.0, 1.0),
			clampf(1.0 - depth_m / V1_SHORE_M, 0.0, 1.0),
			clampf(flow, 0.0, 1.0), 1.0)

static func _sstep(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

## Shader renk bandinin CPU replikasi — WATERCOLORTEST bunu dogrular.
static func v1_band_color(depth_f: float) -> Color:
	var col := V1_SHALLOW
	col = col.lerp(V1_MID,
			_sstep(V1_BAND1 - V1_BAND_SOFT, V1_BAND1 + V1_BAND_SOFT, depth_f))
	col = col.lerp(V1_DEEP,
			_sstep(V1_BAND2 - V1_BAND_SOFT, V1_BAND2 + V1_BAND_SOFT, depth_f))
	return col


# =======================================================================
# C3. CIM SHADER V1 (assets/models/env/grass.gdshader)
# =======================================================================
## Bayrak: false -> sus otu/cicek eski GLB materyalleriyle cizilir.
const CIM_SHADER_V1 := true
## Cicek kopyasi: baslar savrulmasin (sozlesme notu) — dusuk ruzgar.
const CIM_CICEK_WIND := 0.03
const CIM_CICEK_TIP := Color(0.85, 0.55, 0.70)      # yumusak pembe uc
const CIM_CICEK_BASE := Color(0.373, 0.478, 0.322)  # sap yesili (ayni kok)

## CIM V2 (cim-v2): PROTOTIP TARZI YAPRAK CAYIRI — referans
## assets/models/prototips/cim_prototip.html. Her yaprak 3 vertex'lik
## sivri ucgen (tutam/yelpaze modeli YOK); dagilim noise ile KUMELI.
## Eski tutam yaklasimi bayrakla kapali (geri donulebilir).
const CIM_TUTAM_ON := false     # eski sus otu obek serpintisi (Meshy)
const CIM_FIELD_ON := true
const CIM_V2_MEAN := 68.0       # hucre basina ORTALAMA yaprak (Yuksek;
	# 2x deneyi (kullanici istegi): yavaslarsa geri almak tek satir
	# prototip 6000 yaprak / 196 m2 ~= 30; telefon FPS ayar noktasi)
const CIM_V2_H_MIN := 0.09      # yaprak boyu bandi (10x deneyi: %50 kisaldi)
const CIM_V2_H_MAX := 0.16
const CIM_V2_W_MIN := 0.03      # taban genisligi bandi (boyla orantili kuculdu)
const CIM_V2_W_MAX := 0.055
## Kumeli yogunluk: value-noise carpani (bazi alan sik, bazi seyrek).
const CIM_V2_NOISE_SCALE := 0.16
const CIM_V2_DENS_MIN := 0.35
const CIM_V2_DENS_MAX := 1.65
## Kalite kademesi yogunluk kesri (gorev sarti); Dusuk ayrica statik
## (quality=0 — ruzgar/ezme kapali, _apply_cim_tier).
const CIM_V2_TIER_FRAC := {"dusuk": 0.3, "orta": 0.6, "yuksek": 1.0}
## Mesafe eleme: her chunk'ta yapraklarin YARISI ayri MM'de ve
## visibility_range ile bu mesafeden sonra cizilmez — uzak chunk'ta
## yogunluk kendiliginden yariya iner (kare basina kod yok).
const CIM_V2_FAR_M := 24.0
## Shader baslangiclari (prototipte begenilen; titresim shader'da sabit
## 0.25): wind 0.12 / speed 0.35 / gust 0.25 / bend 1.1.
const CIM_V2_WIND := 0.12
const CIM_V2_WIND_SPEED := 0.35
const CIM_V2_GUST := 0.25
const CIM_V2_BEND_R := 1.1
const CIM_V2_BLADE_H := 0.16    # blade_height uniform = mesh referans boyu
## 10x DENEYI (kullanici istegi): yaprak sayisi mesh ICINE gomulerek
## katlanir — instance basina tek ucgen degil MIKRO-TUTAM (asagidaki
## kadar yaprak). Kurulum suresi/instance sayisi DEGISMEZ (636k),
## gorunen yaprak 10 katina cikar; bedeli GPU vertex yuku (10x).
const CIM_V2_MESH_BLADES := 10
const CIM_V2_MESH_SPREAD := 0.30  # mikro-tutam yayilim yaricapi (m)
## Chunk = iki MultiMesh (yakin yari + uzak yari); 16x16 hucre chunk'lar
## frustum culling'e girer.
const CIM_FIELD_CHUNK := 16

## Kumeli 0..1 yogunluk: hash01 uzerine bilinear value-noise (ucuz,
## deterministik — chunk yeniden kurulunca desen degismez).
static func cim_density01(x: int, y: int) -> float:
	var fx := float(x) * CIM_V2_NOISE_SCALE
	var fy := float(y) * CIM_V2_NOISE_SCALE
	var ix := floori(fx)
	var iy := floori(fy)
	var tx := fx - float(ix)
	var ty := fy - float(iy)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var na := hash01(ix, iy, 907)
	var nb := hash01(ix + 1, iy, 907)
	var nc := hash01(ix, iy + 1, 907)
	var nd := hash01(ix + 1, iy + 1, 907)
	return lerpf(lerpf(na, nb, tx), lerpf(nc, nd, tx), ty)
