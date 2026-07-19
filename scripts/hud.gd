extends CanvasLayer
## Ekranin sol ustundeki kaynak sayaclari + alttaki insa cubugu +
## sag alttaki ikonlu aksiyon butonu.
##
## Aksiyon butonunun ikonu duruma gore degisir (World her kare bildirir):
##   "idle"   -> yumruk (el bos, yakinda toplanacak bir sey yok)
##   "gather" -> balta  (yakinda toplanabilir agac/tas/duvar var)
##   "build"  -> cekic  (insa modu acik)

## Insa modu degistiginde yayinlanir; recipe_id bos ise mod kapali demektir.
signal build_toggled(recipe_id: String)

## Sag alttaki aksiyon butonuna basilinca yayinlanir.
signal action_pressed

const ICON_FIST := preload("res://assets/ui/fist.png")
const ICON_GATHER := preload("res://assets/ui/axe.png")
const ICON_BUILD := preload("res://assets/ui/hammer.png")

@onready var wood_label: Label = $Panel/HBox/WoodLabel
@onready var stone_label: Label = $Panel/HBox/StoneLabel
@onready var wood_wall_button: Button = $BuildBar/HBox/WoodWallButton
@onready var stone_wall_button: Button = $BuildBar/HBox/StoneWallButton
@onready var action_button: Button = $ActionButton

var _action_state: String = "idle"

func _ready() -> void:
	Inventory.changed.connect(_refresh)
	wood_wall_button.toggled.connect(_on_build_button_toggled.bind("ahsap_duvar", wood_wall_button))
	stone_wall_button.toggled.connect(_on_build_button_toggled.bind("tas_duvar", stone_wall_button))
	action_button.pressed.connect(func(): action_pressed.emit())
	action_button.icon = ICON_FIST
	_refresh()

func _refresh() -> void:
	wood_label.text = str(Inventory.get_count("odun"))
	stone_label.text = str(Inventory.get_count("tas"))

## World tarafindan cagrilir; ikon sadece durum degisince guncellenir.
func set_action_state(state: String) -> void:
	if state == _action_state:
		return
	_action_state = state
	match state:
		"gather":
			action_button.icon = ICON_GATHER
		"build":
			action_button.icon = ICON_BUILD
		_:
			action_button.icon = ICON_FIST

func _on_build_button_toggled(pressed: bool, recipe_id: String, button: Button) -> void:
	if pressed:
		# Ayni anda tek tarif secili olabilir: digerini sessizce kapat
		for other in [wood_wall_button, stone_wall_button]:
			if other != button and other.button_pressed:
				other.set_pressed_no_signal(false)
		build_toggled.emit(recipe_id)
	else:
		build_toggled.emit("")
