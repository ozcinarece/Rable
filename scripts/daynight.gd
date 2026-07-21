extends Node
## GÜNDÜZ/GECE DÖNGÜSÜ (TimeManager) - autoload. Dört fazlı: dawn → day →
## dusk → night → (yeni gün) dawn. Süreler TimeBalance'ta. Yaratık sistemi
## ileride night_started'a bağlanacak (KANCA HAZIR — kod yok).
##
## Geriye uyum: eski API (day, is_night, elapsed, DAY/NIGHT_SECONDS,
## sleep_to_morning, load_state) korunur ki 2D world.gd + kayıt bozulmasın.

const Balance = preload("res://scripts/time_balance.gd")

signal dawn_started   # yeni gün başladı (şafak) — sabah bonusu kancası burada
signal day_started    # tam gündüz
signal dusk_started   # akşam geçişi
signal night_started  # gece — [PLANLI] yaratık dalgası buraya bağlanacak
signal changed        # HUD güncellemesi (gün/saat/faz)

# Geriye uyum sabitleri (HUD/2D bunlara bakıyor olabilir)
const DAY_SECONDS: float = Balance.DAY_SECONDS
const NIGHT_SECONDS: float = Balance.NIGHT_SECONDS

var day: int = 1
var phase: String = "day"    # "dawn" | "day" | "dusk" | "night"
var elapsed: float = 0.0     # İÇİNDE bulunulan fazda geçen süre (geriye uyum)
var is_night: bool = false   # phase == "night" (geriye uyum)

func _process(delta: float) -> void:
	elapsed += delta
	var dur := _phase_dur(phase)
	if elapsed >= dur:
		elapsed -= dur
		_advance_phase()
		changed.emit()  # yalnız faz değişiminde (HUD ilerlemeyi kendi izler)

func _phase_dur(p: String) -> float:
	match p:
		"dawn": return Balance.DAWN_SECONDS
		"day": return Balance.DAY_SECONDS
		"dusk": return Balance.DUSK_SECONDS
		_: return Balance.NIGHT_SECONDS

func _advance_phase() -> void:
	match phase:
		"dawn":
			phase = "day"
			day_started.emit()
		"day":
			phase = "dusk"
			dusk_started.emit()
		"dusk":
			phase = "night"
			is_night = true
			night_started.emit()
		_:  # night -> yeni gün (şafak)
			phase = "dawn"
			is_night = false
			day += 1
			dawn_started.emit()

## Döngü içindeki mutlak zaman (dawn başı = 0). Güneş açısı/HUD ilerlemesi.
func cycle_time() -> float:
	var base := 0.0
	match phase:
		"day": base = Balance.DAWN_SECONDS
		"dusk": base = Balance.DAWN_SECONDS + Balance.DAY_SECONDS
		"night": base = Balance.DAWN_SECONDS + Balance.DAY_SECONDS + Balance.DUSK_SECONDS
	return base + elapsed

## 0..1 tam döngü boyunca (güneş dönüşü / gökyüzü eğrisi).
func day_fraction() -> float:
	return clampf(cycle_time() / Balance.CYCLE_SECONDS, 0.0, 1.0)

## Şu anki fazın 0..1 ilerlemesi (renk/enerji harmanı için).
func phase_progress() -> float:
	var dur := _phase_dur(phase)
	return clampf(elapsed / maxf(0.01, dur), 0.0, 1.0)

## Geceye kalan süre (gündüz/akşamda). Gece/şafakta 0. HUD "gece yaklaşıyor".
func time_until_night() -> float:
	match phase:
		"day": return (Balance.DAY_SECONDS - elapsed) + Balance.DUSK_SECONDS
		"dusk": return Balance.DUSK_SECONDS - elapsed
		_: return 0.0

## Yatakta uyuyunca sabaha (gündüz başına) atlar. Gün +1.
func sleep_to_morning() -> void:
	phase = "day"
	elapsed = 0.0
	is_night = false
	day += 1
	dawn_started.emit()
	day_started.emit()
	changed.emit()

## Kayittan yukleme (geriye uyum imzası): is_night -> faz.
func load_state(new_day: int, new_is_night: bool, new_elapsed: float) -> void:
	day = maxi(1, new_day)
	is_night = new_is_night
	phase = "night" if new_is_night else "day"
	elapsed = new_elapsed
	changed.emit()

## Tek çatı (SaveManager) serileştirme: gün + faz + faz-içi süre.
func to_save_data() -> Dictionary:
	return {"day": day, "phase": phase, "elapsed": elapsed}

func from_save_data(data: Dictionary) -> void:
	day = maxi(1, int(data.get("day", day)))
	phase = String(data.get("phase", "night" if bool(data.get("is_night", false)) else "day"))
	elapsed = float(data.get("elapsed", 0.0))
	is_night = phase == "night"
	changed.emit()

func reset() -> void:
	day = 1
	phase = "day"
	elapsed = 0.0
	is_night = false
	changed.emit()
