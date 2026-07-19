extends CanvasLayer
## Ekranin sol ustundeki kaynak sayaclari + alttaki insa cubugu.
##
## Kaynak sayaclari Inventory'nin "changed" sinyalini dinler.
## Insa butonlari toggle mantigiyla calisir: birine basinca digeri
## kapanir ve "build_toggled" sinyaliyle secilen tarif World'e bildirilir.
## Buton kapaninca bos string gonderilir (insa modu kapali).

## Insa modu degistiginde yayinlanir; recipe_id bos ise mod kapali demektir.
signal build_toggled(recipe_id: String)

@onready var wood_label: Label = $Panel/HBox/WoodLabel
@onready var stone_label: Label = $Panel/HBox/StoneLabel
@onready var wood_wall_button: Button = $BuildBar/HBox/WoodWallButton
@onready var stone_wall_button: Button = $BuildBar/HBox/StoneWallButton

func _ready() -> void:
	Inventory.changed.connect(_refresh)
	wood_wall_button.toggled.connect(_on_build_button_toggled.bind("ahsap_duvar", wood_wall_button))
	stone_wall_button.toggled.connect(_on_build_button_toggled.bind("tas_duvar", stone_wall_button))
	_refresh()

func _refresh() -> void:
	wood_label.text = str(Inventory.get_count("odun"))
	stone_label.text = str(Inventory.get_count("tas"))

func _on_build_button_toggled(pressed: bool, recipe_id: String, button: Button) -> void:
	if pressed:
		# Ayni anda tek tarif secili olabilir: digerini sessizce kapat
		for other in [wood_wall_button, stone_wall_button]:
			if other != button and other.button_pressed:
				other.set_pressed_no_signal(false)
		build_toggled.emit(recipe_id)
	else:
		build_toggled.emit("")
