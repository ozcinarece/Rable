extends Node
## Gece/gunduz dongusu - autoload (singleton).
## Gunduz DAY_SECONDS surer, gece NIGHT_SECONDS. Gece basladiginda
## dusman dalgasi dogar (World dinler), gun dogunca kalanlar yok olur.

signal night_started
signal day_started
signal changed  # gun sayaci / faz etiketi guncellensin diye

const DAY_SECONDS: float = 180.0
const NIGHT_SECONDS: float = 75.0

var day: int = 1
var is_night: bool = false
var elapsed: float = 0.0

func _process(delta: float) -> void:
	elapsed += delta
	if not is_night and elapsed >= DAY_SECONDS:
		elapsed = 0.0
		is_night = true
		night_started.emit()
		changed.emit()
	elif is_night and elapsed >= NIGHT_SECONDS:
		elapsed = 0.0
		is_night = false
		day += 1
		day_started.emit()
		changed.emit()

## Yatakta uyuyunca geceyi atlar, sabah olur.
func sleep_to_morning() -> void:
	if not is_night:
		return
	elapsed = 0.0
	is_night = false
	day += 1
	day_started.emit()
	changed.emit()

## Kayittan yukleme
func load_state(new_day: int, new_is_night: bool, new_elapsed: float) -> void:
	day = maxi(1, new_day)
	is_night = new_is_night
	elapsed = new_elapsed
	changed.emit()

func reset() -> void:
	day = 1
	is_night = false
	elapsed = 0.0
	changed.emit()
