extends CanvasLayer
## Oyun arayuzu:
##   - Sol ust: dinamik envanter cubugu (sahip olunan esyalar otomatik)
##   - Sol alt: "Uretim" butonu + tarif paneli
##   - Alt orta: insa cubugu (BUILD_RECIPES'ten dinamik uretilir)
##   - Sag alt: ikonlu aksiyon butonu (yumruk/balta/cekic)

## Insa modu degistiginde yayinlanir; recipe_id bos ise mod kapali demektir.
signal build_toggled(recipe_id: String)

## Sag alttaki aksiyon butonuna basilinca yayinlanir.
signal action_pressed

## Sandik paneli: esya tasima istegi (to_chest: true = sandiga koy)
signal chest_transfer_requested(item_id: String, to_chest: bool)
## Bos sandigi sokme istegi
signal chest_dismantle_requested
## Panel Kapat butonuyla kapatildi (World acik sandik kaydini temizler)
signal chest_closed

## Kazma modu acildi/kapandi (kurek butonu)
signal dig_toggled(enabled: bool)

const Items = preload("res://scripts/items.gd")
const Recipes = preload("res://scripts/recipes.gd")

const ICON_FIST := preload("res://assets/ui/fist.png")
const ICON_GATHER := preload("res://assets/ui/axe.png")
const ICON_BUILD := preload("res://assets/ui/hammer.png")
const ICON_DIG := preload("res://assets/ui/shovel.png")

@onready var inventory_box: HBoxContainer = $Panel/HBox
@onready var build_box: HBoxContainer = $BuildBar/HBox
@onready var action_button: Button = $ActionButton
@onready var craft_button: Button = $CraftButton
@onready var craft_panel: PanelContainer = $CraftPanel
@onready var craft_rows: VBoxContainer = $CraftPanel/VBox/Rows
@onready var hunger_bar: ProgressBar = $HungerPanel/HBox/HungerBar
@onready var eat_button: Button = $HungerPanel/HBox/EatButton
@onready var reset_button: Button = $ResetButton
@onready var chest_panel: PanelContainer = $ChestPanel
@onready var chest_rows: VBoxContainer = $ChestPanel/VBox/Scroll/Rows
@onready var chest_close_button: Button = $ChestPanel/VBox/TitleRow/CloseButton
@onready var chest_dismantle_button: Button = $ChestPanel/VBox/DismantleButton
@onready var dig_button: Button = $DigButton
@onready var inventory_button: Button = $InventoryButton
@onready var inventory_panel: PanelContainer = $InventoryPanel
@onready var inventory_title: Label = $InventoryPanel/VBox/TitleRow/Title
@onready var inventory_slots: GridContainer = $InventoryPanel/VBox/Slots
@onready var inventory_detail: Label = $InventoryPanel/VBox/Detail
@onready var panel_eat_button: Button = $InventoryPanel/VBox/PanelEatButton
@onready var chest_title: Label = $ChestPanel/VBox/TitleRow/Title

var _selected_item: String = ""

var _action_state: String = "idle"
var _craft_buttons: Dictionary = {}  # recipe_id -> Uret butonu
var _build_buttons: Dictionary = {}  # recipe_id -> insa toggle butonu

func _ready() -> void:
	Inventory.changed.connect(_refresh)
	Crafting.station_changed.connect(_update_craft_buttons)
	Hunger.changed.connect(_update_hunger)
	action_button.pressed.connect(func(): action_pressed.emit())
	action_button.icon = ICON_FIST
	craft_button.toggled.connect(func(pressed: bool): craft_panel.visible = pressed)
	craft_panel.visible = false
	eat_button.pressed.connect(_on_eat_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	chest_close_button.pressed.connect(func():
		close_chest()
		chest_closed.emit())
	chest_dismantle_button.pressed.connect(func(): chest_dismantle_requested.emit())
	chest_panel.visible = false
	dig_button.icon = ICON_DIG
	dig_button.toggled.connect(_on_dig_toggled)
	inventory_button.toggled.connect(func(pressed: bool):
		inventory_panel.visible = pressed
		if pressed:
			_rebuild_inventory_panel())
	$InventoryPanel/VBox/TitleRow/CloseButton.pressed.connect(func():
		inventory_button.button_pressed = false)
	panel_eat_button.pressed.connect(_on_eat_pressed)
	_build_build_bar()
	_build_craft_panel()
	_refresh()
	_update_hunger()

# --- Envanter cubugu ----------------------------------------------------

func _refresh() -> void:
	_rebuild_inventory_bar()
	_update_craft_buttons()
	_update_hunger()
	if inventory_panel.visible:
		_rebuild_inventory_panel()

# --- Envanter paneli ----------------------------------------------------

# Slot izgarasini yeniden kurar: dolu slotlar esya butonu, boslar gri kutu.
func _rebuild_inventory_panel() -> void:
	inventory_title.text = "Envanter (%d/%d slot)" % [Inventory.get_used_slots(), Inventory.get_slot_count()]
	for child in inventory_slots.get_children():
		child.queue_free()
	for item_id in Items.ITEMS:
		var count := Inventory.get_count(item_id)
		if count <= 0:
			continue
		var slot := Button.new()
		slot.icon = load(Items.ITEMS[item_id]["icon"])
		slot.text = "x%d" % count
		slot.custom_minimum_size = Vector2(120, 52)
		slot.add_theme_font_size_override("font_size", 20)
		slot.pressed.connect(_on_slot_pressed.bind(item_id))
		inventory_slots.add_child(slot)
	for i in Inventory.get_slot_count() - Inventory.get_used_slots():
		var empty := Button.new()
		empty.disabled = true
		empty.custom_minimum_size = Vector2(120, 52)
		inventory_slots.add_child(empty)
	_update_detail()

func _on_slot_pressed(item_id: String) -> void:
	_selected_item = item_id
	_update_detail()

func _update_detail() -> void:
	if _selected_item == "" or Inventory.get_count(_selected_item) <= 0:
		inventory_detail.text = "Bir esyaya dokun: detayi burada gorunur. Yigin limiti: %d." % Inventory.STACK_MAX
		panel_eat_button.visible = false
		return
	inventory_detail.text = "%s x%d - %s" % [
		Items.display_name(_selected_item),
		Inventory.get_count(_selected_item),
		Items.description(_selected_item),
	]
	panel_eat_button.visible = _selected_item == "meyve"

# --- Aclik --------------------------------------------------------------

func _update_hunger() -> void:
	hunger_bar.value = Hunger.value
	# Aclik kritik seviyedeyse bari kirmiziya bogar
	hunger_bar.modulate = Color(1, 0.45, 0.45) if Hunger.value <= 25.0 else Color.WHITE
	# Meyve varsa ve aclik tam degilse Ye butonu aktif
	eat_button.disabled = Inventory.get_count("meyve") <= 0 or Hunger.value >= Hunger.MAX_VALUE

func _on_eat_pressed() -> void:
	if Inventory.remove_item("meyve", 1):
		Hunger.eat(25.0)

# Kayitli oyunu silip sifirdan baslar.
func _on_reset_pressed() -> void:
	SaveManager.delete_save()
	Inventory.reset()
	Hunger.reset()
	get_tree().reload_current_scene()

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

# --- Insa cubugu (dinamik) ----------------------------------------------

func _build_build_bar() -> void:
	for recipe_id in Recipes.BUILD_RECIPES:
		var recipe: Dictionary = Recipes.BUILD_RECIPES[recipe_id]
		var button := Button.new()
		button.toggle_mode = true
		button.icon = load(recipe["icon"])
		button.text = "%s (%s)" % [recipe["name"], _cost_text(recipe["cost"])]
		button.add_theme_font_size_override("font_size", 18)
		button.toggled.connect(_on_build_button_toggled.bind(recipe_id, button))
		build_box.add_child(button)
		_build_buttons[recipe_id] = button

func _on_build_button_toggled(pressed: bool, recipe_id: String, button: Button) -> void:
	if pressed:
		# Ayni anda tek mod aktif olabilir: diger insa butonlarini ve
		# kazma modunu sessizce kapat
		for other_id in _build_buttons:
			var other: Button = _build_buttons[other_id]
			if other != button and other.button_pressed:
				other.set_pressed_no_signal(false)
		if dig_button.button_pressed:
			dig_button.set_pressed_no_signal(false)
			dig_toggled.emit(false)
		build_toggled.emit(recipe_id)
	else:
		build_toggled.emit("")

# Kazma modu acilinca insa secimini kapat (tek mod aktif olabilir)
func _on_dig_toggled(pressed: bool) -> void:
	if pressed:
		for other_id in _build_buttons:
			var other: Button = _build_buttons[other_id]
			if other.button_pressed:
				other.set_pressed_no_signal(false)
		build_toggled.emit("")
	dig_toggled.emit(pressed)

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

# "Balta x1  (2 Çubuk, 1 İp, 1 Taş) [Tezgah]" gibi bir tarif metni uretir.
func _recipe_text(recipe: Dictionary) -> String:
	var outs: PackedStringArray = []
	for item_id in recipe["output"]:
		outs.append("%s x%d" % [Items.display_name(item_id), recipe["output"][item_id]])
	var text := "%s  (%s)" % [" ".join(outs), _cost_text(recipe["cost"])]
	if recipe["station"] != "":
		text += "  [Tezgah]"
	return text

func _cost_text(cost: Dictionary) -> String:
	var costs: PackedStringArray = []
	for item_id in cost:
		costs.append("%d %s" % [cost[item_id], Items.display_name(item_id)])
	return ", ".join(costs)

# Uretilemeyen tariflerin (kaynak yok / tezgah uzak) butonunu pasif yapar.
func _update_craft_buttons() -> void:
	for recipe_id in _craft_buttons:
		_craft_buttons[recipe_id].disabled = not Crafting.can_craft(recipe_id)

# --- Sandik paneli ------------------------------------------------------

## World tarafindan cagrilir: paneli verilen icerikle (yeniden) cizer.
## message: baslikta gosterilecek kisa uyari (orn. "Envanter dolu!")
func show_chest(contents: Dictionary, message: String = "") -> void:
	chest_title.text = "Sandık" if message == "" else "Sandık - %s" % message
	chest_panel.visible = true
	for child in chest_rows.get_children():
		child.queue_free()

	_add_chest_section_title("Sandıktakiler:")
	if contents.is_empty():
		_add_chest_note("(boş)")
	for item_id in contents:
		_add_chest_row(item_id, contents[item_id], "Al", false)

	_add_chest_section_title("Envanterin:")
	var has_any := false
	for item_id in Items.ITEMS:
		var count := Inventory.get_count(item_id)
		if count <= 0:
			continue
		has_any = true
		_add_chest_row(item_id, count, "Koy", true)
	if not has_any:
		_add_chest_note("(boş)")

	chest_dismantle_button.disabled = not contents.is_empty()

func close_chest() -> void:
	chest_panel.visible = false

func _add_chest_section_title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.modulate = Color(1, 1, 0.75)
	chest_rows.add_child(label)

func _add_chest_note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.modulate = Color(0.8, 0.8, 0.8)
	chest_rows.add_child(label)

# Tek esya satiri: ikon + "Ad x adet" + tasima butonu (tum yigini tasir)
func _add_chest_row(item_id: String, count: int, button_text: String, to_chest: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var icon := TextureRect.new()
	icon.texture = load(Items.ITEMS[item_id]["icon"])
	icon.custom_minimum_size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var label := Label.new()
	label.text = "%s x%d" % [Items.display_name(item_id), count]
	label.add_theme_font_size_override("font_size", 20)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var move := Button.new()
	move.text = button_text
	move.add_theme_font_size_override("font_size", 20)
	move.pressed.connect(func(): chest_transfer_requested.emit(item_id, to_chest))
	row.add_child(move)

	chest_rows.add_child(row)

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
		"dig":
			action_button.icon = ICON_DIG
		_:
			action_button.icon = ICON_FIST
