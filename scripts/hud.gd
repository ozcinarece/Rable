extends CanvasLayer
## Ekranin sol ustundeki kaynak sayaclari.
## Inventory'nin "changed" sinyalini dinler ve sayilari gunceller;
## baska hicbir sistemle dogrudan bagi yoktur.

@onready var wood_label: Label = $Panel/HBox/WoodLabel
@onready var stone_label: Label = $Panel/HBox/StoneLabel

func _ready() -> void:
	Inventory.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	wood_label.text = str(Inventory.get_count("odun"))
	stone_label.text = str(Inventory.get_count("tas"))
