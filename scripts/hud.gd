extends CanvasLayer
## Oyun arayuzu:
##   - Sol ust: dinamik envanter cubugu (sahip olunan esyalar otomatik)
##   - Sol alt: "Uretim" butonu + tarif paneli
##   - Alt orta: insa cubugu
##   - Sag alt: ikonlu aksiyon butonu (yumruk/balta/cekic)

## Insa modu degistiginde yayinlanir; recipe_id bos ise mod kapali demektir.
signal build_toggled(recipe_id: String)

## Sag alttaki aksiyon butonuna basilinca yayinlanir.
signal action_pressed

const Items = preload("res://scripts/items.gd")
const Recipes = preload("res://scripts/recipes.gd")

const ICON_FIST := preload("res://assets/ui/fist.png")
const ICON_GATHER := preload("res://assets/ui/axe.png")
const ICON_BUILD := preload("res://assets/ui/hammer.png")

@onready var inventory_box: HBoxContainer = $Panel/HBox
@onready var wood_wall_button: Button = $BuildBar/HBox/WoodWallButton
@onready var stone_wall_button: Button = $BuildBar/HBox/StoneWallButton
@onready var action_button: Button = $ActionButton
@onready var craft_button: Button = $CraftButton
@onready var craft_panel: PanelContainer = $CraftPanel
@onready var craft_rows: VBoxContainer = $CraftPanel/VBox/Rows

var _action_state: String = "idle"
var _craft_buttons: Dictionary = {}  # recipe_id -> Uret butonu (durum guncelleme icin)

func _ready() -> void:
	Inventory.changed.connect(_refresh)
	wood_wall_button.toggled.connect(_on_build_button_toggled.bind("ahsap_duvar", wood_wall_button))
	stone_wall_button.toggled.connect(_on_build_button_toggled.bind("tas_duvar", stone_wall_button))
	action_button.pressed.connect(func(): action_pressed.emit())
	action_button.icon = ICON_FIST
	craft_button.toggled.connect(func(pressed: bool): craft_panel.visible = pressed)
	craft_panel.visible = false
	_build_craft_panel()
	_refresh()

# --- Envanter cubugu ----------------------------------------------------

func _refresh() -> void:
	_rebuild_inventory_bar()
	_update_craft_buttons()

# Sadece sahip olunan esyalari, items.gd'deki sirayla gosterir.
func _rebuild_inventory_bar() -> void:
	for child in inventory_box.get_children():
		child.queue_free()
	for item_id in Items.ITEMS:
		var count := Inventory.get_count(item_id)
		if count <= 0:
			continue
		var icon := TextureRect.new()
		icon.texture = load(Items.ITEMS[item_id]["icon"])
		icon.custom_minimum_size = Vector2(34, 34)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		inventory_box.add_child(icon)
		var label := Label.new()
		label.text = str(count)
		label.add_theme_font_size_override("font_size", 26)
		inventory_box.add_child(label)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(10, 0)
		inventory_box.add_child(spacer)

# --- Uretim paneli ------------------------------------------------------

# Panel satirlarini tariflerden bir kez kurar.
func _build_craft_panel() -> void:
	for recipe_id in Recipes.CRAFT_RECIPES:
		var recipe: Dictionary = Recipes.CRAFT_RECIPES[recipe_id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var out_id: String = recipe["output"].keys()[0]
		var icon := TextureRect.new()
		icon.texture = load(Items.ITEMS[out_id]["icon"])
		icon.custom_minimum_size = Vector2(34, 34)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)

		var label := Label.new()
		label.text = _recipe_text(recipe)
		label.add_theme_font_size_override("font_size", 22)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var craft := Button.new()
		craft.text = "Üret"
		craft.add_theme_font_size_override("font_size", 22)
		craft.pressed.connect(func(): Crafting.craft(recipe_id))
		row.add_child(craft)
		_craft_buttons[recipe_id] = craft

		craft_rows.add_child(row)

# "Kalas x2  (1 Odun)" gibi bir tarif metni uretir.
func _recipe_text(recipe: Dictionary) -> String:
	var outs: PackedStringArray = []
	for item_id in recipe["output"]:
		outs.append("%s x%d" % [Items.display_name(item_id), recipe["output"][item_id]])
	var costs: PackedStringArray = []
	for item_id in recipe["cost"]:
		costs.append("%d %s" % [recipe["cost"][item_id], Items.display_name(item_id)])
	return "%s  (%s)" % [" ".join(outs), ", ".join(costs)]

# Kaynagi yetmeyen tariflerin Uret butonunu soluk/pasif yapar.
func _update_craft_buttons() -> void:
	for recipe_id in _craft_buttons:
		_craft_buttons[recipe_id].disabled = not Crafting.can_craft(recipe_id)

# --- Aksiyon butonu -----------------------------------------------------

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

# --- Insa cubugu --------------------------------------------------------

func _on_build_button_toggled(pressed: bool, recipe_id: String, button: Button) -> void:
	if pressed:
		# Ayni anda tek tarif secili olabilir: digerini sessizce kapat
		for other in [wood_wall_button, stone_wall_button]:
			if other != button and other.button_pressed:
				other.set_pressed_no_signal(false)
		build_toggled.emit(recipe_id)
	else:
		build_toggled.emit("")
