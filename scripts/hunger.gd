extends Node
## Aclik sistemi - autoload (singleton). DEGER + SINYAL deposu.
## Azalma/esik/olum mantigi ve TUM sayilar artik PlayerStats +
## SurvivalBalance'ta (tek merkez, kod icinde sabit yok). Burada self-decay
## YOK — PlayerStats surer. Yiyecekle doldurulur.

signal changed

const MAX_VALUE: float = 100.0

var value: float = MAX_VALUE

## Aclik sifirda mi? (can erimesi PlayerStats'ta)
func is_starving() -> bool:
	return value <= 0.0

func eat(amount: float) -> void:
	value = minf(MAX_VALUE, value + amount)
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
