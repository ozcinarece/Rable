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

## Tasima modu acildi/kapandi (Tasi butonu)
signal move_toggled(enabled: bool)

## Envanterden bir esyayi eline alma istegi (bos string = birak)
signal hold_requested(item_id: String)

const Items = preload("res://scripts/items.gd")
const Recipes = preload("res://scripts/recipes.gd")

const ICON_FIST := preload("res://assets/ui/fist.png")
const ICON_GATHER := preload("res://assets/ui/axe.png")
const ICON_BUILD := preload("res://assets/ui/hammer.png")
const ICON_DIG := preload("res://assets/ui/shovel.png")
const ICON_MOVE := preload("res://assets/ui/move.png")
const ICON_SPEAR := preload("res://assets/ui/spear.png")

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
@onready var move_button: Button = $MoveButton
@onready var hold_button: Button = $InventoryPanel/VBox/HoldButton
@onready var inventory_button: Button = $InventoryButton
@onready var inventory_panel: PanelContainer = $InventoryPanel
@onready var inventory_title: Label = $InventoryPanel/VBox/TitleRow/Title
@onready var inventory_slots: GridContainer = $InventoryPanel/VBox/Slots
@onready var inventory_detail: Label = $InventoryPanel/VBox/Detail
@onready var panel_eat_button: Button = $InventoryPanel/VBox/PanelEatButton
@onready var chest_title: Label = $ChestPanel/VBox/TitleRow/Title
@onready var health_bar: ProgressBar = $HealthPanel/HBox/HealthBar
@onready var day_label: Label = $DayLabel

var _selected_item: String = ""
var _held_item: String = ""  # World bildirir; detay butonunun metni icin

var _action_state: String = "idle"
var _craft_buttons: Dictionary = {}  # recipe_id -> Uret butonu
var _build_buttons: Dictionary = {}  # recipe_id -> insa toggle butonu

func _ready() -> void:
	Inventory.changed.connect(_refresh)
	Crafting.station_changed.connect(_update_craft_buttons)
	Hunger.changed.connect(_update_hunger)
	Health.changed.connect(_update_health)
	DayNight.changed.connect(_update_day_label)
	_update_health()
	_update_day_label()
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
	move_button.icon = ICON_MOVE
	move_button.toggled.connect(_on_move_toggled)
	hold_button.pressed.connect(_on_hold_pressed)
	inventory_button.toggled.connect(func(pressed: bool):
		inventory_panel.visible = pressed
		if pressed:
			_rebuild_inventory_panel())
	$InventoryPanel/VBox/TitleRow/CloseButton.pressed.connect(func():
		inventory_button.button_pressed = false)
	panel_eat_button.pressed.connect(_on_eat_pressed)
	_apply_ui_theme()
	_setup_damage_flash()
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
		hold_button.visible = false
		return
	inventory_detail.text = "%s x%d - %s" % [
		Items.display_name(_selected_item),
		Inventory.get_count(_selected_item),
		Items.description(_selected_item),
	]
	panel_eat_button.visible = _selected_item == "meyve"
	hold_button.visible = Items.HOLDABLE.has(_selected_item)
	hold_button.text = "Bırak" if _held_item == _selected_item else "Eline Al"

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
	Health.reset()
	DayNight.reset()
	get_tree().reload_current_scene()

# --- Gorsel tema ----------------------------------------------------------

# Go-Go Town tarzi krem/pastel tema: yuvarlak koseli krem kartlar,
# koyu kahve yazi, turuncu vurgu. Tema ust seviye Control'lere atanir;
# sonradan eklenen cocuklar (tarif satirlari, slotlar) otomatik miras alir.
const COL_CREAM := Color(0.99, 0.96, 0.89)
const COL_CREAM_LIGHT := Color(1.0, 0.99, 0.95)
const COL_BROWN := Color(0.33, 0.24, 0.16)
const COL_BROWN_SOFT := Color(0.85, 0.78, 0.66)
const COL_ORANGE := Color(0.98, 0.62, 0.22)

func _apply_ui_theme() -> void:
	var theme := Theme.new()

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COL_CREAM
	panel_style.set_corner_radius_all(16)
	panel_style.border_color = COL_BROWN_SOFT
	panel_style.set_border_width_all(2)
	panel_style.shadow_color = Color(0.2, 0.12, 0.05, 0.25)
	panel_style.shadow_size = 5
	panel_style.shadow_offset = Vector2(0, 3)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	var button_style := StyleBoxFlat.new()
	button_style.bg_color = COL_CREAM_LIGHT
	button_style.set_corner_radius_all(12)
	button_style.border_color = COL_BROWN_SOFT
	button_style.set_border_width_all(2)
	button_style.shadow_color = Color(0.2, 0.12, 0.05, 0.2)
	button_style.shadow_size = 3
	button_style.shadow_offset = Vector2(0, 2)
	button_style.content_margin_left = 12
	button_style.content_margin_right = 12
	button_style.content_margin_top = 6
	button_style.content_margin_bottom = 6
	theme.set_stylebox("normal", "Button", button_style)

	# Basili/secili: turuncu dolgu + beyaz yazi (Go-Go Town vurgusu)
	var pressed_style := button_style.duplicate()
	pressed_style.bg_color = COL_ORANGE
	pressed_style.border_color = Color(0.85, 0.48, 0.12)
	theme.set_stylebox("pressed", "Button", pressed_style)
	theme.set_stylebox("hover", "Button", pressed_style)

	var disabled_style := button_style.duplicate()
	disabled_style.bg_color = Color(0.93, 0.89, 0.81, 0.8)
	disabled_style.shadow_size = 0
	theme.set_stylebox("disabled", "Button", disabled_style)

	# Yazi renkleri: krem zeminde koyu kahve
	theme.set_color("font_color", "Button", COL_BROWN)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(0.33, 0.24, 0.16, 0.4))
	theme.set_color("font_color", "Label", COL_BROWN)

	# Hap seklinde bar govdesi (aclik/can ortak arka plan)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.88, 0.82, 0.71)
	bar_bg.set_corner_radius_all(9)
	bar_bg.border_color = COL_BROWN_SOFT
	bar_bg.set_border_width_all(1)
	theme.set_stylebox("background", "ProgressBar", bar_bg)

	for child in get_children():
		if child is Control:
			child.theme = theme

	# Insa cubugu turuncu serit olsun (temadaki krem kartin ustune)
	var build_style: StyleBoxFlat = panel_style.duplicate()
	build_style.bg_color = COL_ORANGE
	build_style.border_color = Color(0.85, 0.48, 0.12)
	$BuildBar.add_theme_stylebox_override("panel", build_style)

	# Bar dolgulari: aclik turuncu, can kirmizi (hap seklinde)
	hunger_bar.add_theme_stylebox_override("fill", _make_bar_fill(Color(0.98, 0.65, 0.25)))
	health_bar.add_theme_stylebox_override("fill", _make_bar_fill(Color(0.92, 0.32, 0.32)))

	# Gun etiketi panel disinda, dunyanin ustunde: beyaz + golge kalsin
	day_label.add_theme_color_override("font_color", Color.WHITE)
	day_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	day_label.add_theme_constant_override("shadow_offset_y", 2)

func _make_bar_fill(color: Color) -> StyleBoxFlat:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(9)
	return fill

# Hasar alininca ekran kenarlarinda kirmizi flas.
var _damage_flash: ColorRect
var _prev_hp: float = 100.0

func _setup_damage_flash() -> void:
	_damage_flash = ColorRect.new()
	_damage_flash.color = Color(0.9, 0.1, 0.1, 0.0)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_damage_flash)
	move_child(_damage_flash, 0)  # panellerin altinda kalsin
	_prev_hp = Health.value

# --- Can ve gun gostergesi ------------------------------------------------

func _update_health() -> void:
	health_bar.value = Health.value
	if _damage_flash != null and Health.value < _prev_hp:
		_damage_flash.color.a = 0.3
		create_tween().tween_property(_damage_flash, "color:a", 0.0, 0.4)
	_prev_hp = Health.value

func _update_day_label() -> void:
	if DayNight.is_night:
		day_label.text = "Gün %d - GECE!" % DayNight.day
		day_label.modulate = Color(1, 0.75, 1)
	else:
		day_label.text = "Gün %d - Gündüz" % DayNight.day
		day_label.modulate = Color.WHITE

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
		if move_button.button_pressed:
			move_button.set_pressed_no_signal(false)
			move_toggled.emit(false)
		build_toggled.emit(recipe_id)
	else:
		build_toggled.emit("")

# Tasima modu acilinca insa secimini kapat (tek mod aktif olabilir)
func _on_move_toggled(pressed: bool) -> void:
	if pressed:
		for other_id in _build_buttons:
			var other: Button = _build_buttons[other_id]
			if other.button_pressed:
				other.set_pressed_no_signal(false)
		build_toggled.emit("")
	move_toggled.emit(pressed)

# --- Eline alma ---------------------------------------------------------

func _on_hold_pressed() -> void:
	if _selected_item == "":
		return
	# Zaten eldeyse birak, degilse eline al
	hold_requested.emit("" if _held_item == _selected_item else _selected_item)

## World bildirir: eldeki esya degisti (buton metni guncellenir)
func set_held_item(item_id: String) -> void:
	_held_item = item_id
	_update_detail()

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
		"move":
			action_button.icon = ICON_MOVE
		"attack_spear":
			action_button.icon = ICON_SPEAR
		"attack":
			action_button.icon = ICON_FIST
		_:
			action_button.icon = ICON_FIST
