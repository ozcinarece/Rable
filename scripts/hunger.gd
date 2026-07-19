extends Node
## Aclik sistemi - autoload (singleton).
## Deger zamanla azalir; sifira inince oyuncu yavaslar (olum M5'te,
## can sistemiyle birlikte gelecek). Meyve yiyerek doldurulur.

signal changed

const MAX_VALUE: float = 100.0
## Saniyede azalma miktari (0.25 -> yaklasik 6.5 dakikada tukeniyor)
const DECAY_PER_SECOND: float = 0.25

var value: float = MAX_VALUE

func _process(delta: float) -> void:
	var old := int(value)
	value = maxf(0.0, value - DECAY_PER_SECOND * delta)
	if int(value) != old:
		changed.emit()

## Aclik sifirda mi? (oyuncu yavaslar)
func is_starving() -> bool:
	return value <= 0.0

func eat(amount: float) -> void:
	value = minf(MAX_VALUE, value + amount)
	changed.emit()

func reset() -> void:
	value = MAX_VALUE
	changed.emit()
