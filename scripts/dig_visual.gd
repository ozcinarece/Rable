extends RefCounted
## KAZI GÖRSEL VERİSİ — çukur duvarı katmanları, ağız pahı, serpinti.
## Yalnız GÖRSEL: kazı mantığı (derinlik, kil, kurallar) DigRules'ta ve
## world3d._try_dig'te; bu dosya hiçbirini etkilemez.
##
## Renkler zemin/UI paletiyle aynı aileden (sıcak toprak → soğuk taş).

# --- Duvar katmanları (yüzeyin KAÇ METRE altında olduğuna göre) ----------
## Üst şerit: çim kökü geçişi — çimden toprağa yumuşak devir.
const BAND_TOP_DEPTH := 0.16          # bu derinliğe kadar kök şeridi
const BAND_TOP_COLOR := Color(0.36, 0.34, 0.20)
## Orta: nemli kazılmış toprak.
const BAND_MID_DEPTH := 0.85          # bu derinliğe kadar toprak
const BAND_MID_COLOR := Color(0.44, 0.31, 0.20)
## Derin (depth 3-4): taş grisi.
const BAND_DEEP_COLOR := Color(0.42, 0.39, 0.34)
## Katman geçişlerinin yumuşaklığı (m). 0 = keskin şerit.
const BAND_BLEND := 0.10

# --- Ağız pahı (chamfer) -------------------------------------------------
## Çukur ağzındaki köşe kadar sert durmasın: kenar tepe noktası bu kadar
## metre aşağı çekilir (YALNIZ görsel mesh; oyun yüksekliği değişmez).
const RIM_CHAMFER := 0.07

# --- Ağız çevresi çim püskülü -------------------------------------------
## Kazı ağzına komşu hücrelerde püskül çıkma şansı (mevcut dekor sistemi).
const RIM_TUFT_CHANCE := 0.30

# --- Serpinti (soil_clump / rock_shard) ----------------------------------
## Kullanıcı GLB'leri buraya gelecek; yoksa prosedürel fallback kullanılır.
const SCATTER_SHALLOW_GLB := "res://assets/models/env/soil_clump.glb"
const SCATTER_DEEP_GLB := "res://assets/models/env/rock_shard.glb"
## Bu derinlikten itibaren taş kıymığı serpilir (altında toprak öbeği).
const SCATTER_DEEP_FROM := 3
## Hücre başına serpinti adedi (0..MAX, deterministik hash ile).
const SCATTER_MAX_PER_CELL := 2
## Parça boyu (m) ve rastgele boy oynaması.
const SCATTER_SIZE := 0.13
const SCATTER_SIZE_JITTER := 0.35
## Fallback renkleri (GLB yokken).
const CLUMP_COLOR := Color(0.40, 0.28, 0.18)
const SHARD_COLOR := Color(0.46, 0.44, 0.40)

## Yüzeyin `below` metre altındaki duvar rengi (katmanlar harmanlı).
static func wall_color(below: float) -> Color:
	if below <= BAND_TOP_DEPTH:
		return BAND_TOP_COLOR
	if below <= BAND_TOP_DEPTH + BAND_BLEND:
		var t := (below - BAND_TOP_DEPTH) / BAND_BLEND
		return BAND_TOP_COLOR.lerp(BAND_MID_COLOR, t)
	if below <= BAND_MID_DEPTH:
		return BAND_MID_COLOR
	if below <= BAND_MID_DEPTH + BAND_BLEND:
		var t2 := (below - BAND_MID_DEPTH) / BAND_BLEND
		return BAND_MID_COLOR.lerp(BAND_DEEP_COLOR, t2)
	return BAND_DEEP_COLOR

## Deterministik 0..1 gürültü (aynı hücre hep aynı serpintiyi alsın —
## chunk yeniden kurulunca taşlar yer değiştirmesin).
static func hash01(x: int, y: int, salt: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	return float(absi(h) % 100003) / 100003.0
