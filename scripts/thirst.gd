extends Node
## Susuzluk sistemi - autoload (singleton).
## Deger zamanla azalir; sifira inince oyuncu yavaslar (aclikla
## birlesirse iyice yavaslar). Su kenarinda suya dokununca icilir.

signal changed

const MAX_VALUE: float = 100.0
## Saniyede azalma miktari (acliktan biraz hizli: su daha kritik)
const DECAY_PER_SECOND: float = 0.3
const DRINK_AMOUNT: float = 35.0

var value: float = MAX_VALUE

func _process(delta: float) -> void:
	var old := int(value)
	value = maxf(0.0, value - DECAY_PER_SECOND * delta)
	if int(value) != old:
		changed.emit()

## Susuzluk sifirda mi? (oyuncu yavaslar)
func is_dehydrated() -> bool:
	return value <= 0.0

func drink() -> void:
	value = minf(MAX_VALUE, value + DRINK_AMOUNT)
	changed.emit()

func reset() -> void:
	value = MAX_VALUE
	changed.emit()

## Tek çatı (SaveManager) serileştirme.
func to_save_data() -> Dictionary:
	return {"value": value}

func from_save_data(data: Dictionary) -> void:
	value = clampf(float(data.get("value", value)), 0.0, MAX_VALUE)
	changed.emit()
