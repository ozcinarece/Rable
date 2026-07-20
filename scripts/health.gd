extends Node
## Oyuncu can sistemi - autoload (singleton).
## Zirh/sapka envanterdeyken gelen hasari azaltir (giyilen esya mantigi).
## Can sifira inince "died" yayinlanir; World oyuncuyu kampta diriltir.

signal changed
signal died

const MAX_VALUE: float = 100.0

var value: float = MAX_VALUE

func damage(amount: float) -> void:
	var multiplier := 1.0
	if Inventory.get_count("zirh") > 0:
		multiplier *= 0.6   # zirh: %40 hasar azaltma
	if Inventory.get_count("sapka") > 0:
		multiplier *= 0.85  # sapka: %15 hasar azaltma
	value = maxf(0.0, value - amount * multiplier)
	changed.emit()
	if value <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	value = minf(MAX_VALUE, value + amount)
	changed.emit()

func reset() -> void:
	value = MAX_VALUE
	changed.emit()
