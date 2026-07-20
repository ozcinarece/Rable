extends CanvasLayer
## Oyun arayuzu (Go-Go Town tarzi krem/pastel):
##   - Sol ust: canta butonu (envanter paneli) + anahtar butonu (uretim)
##   - Alt orta: 8 gozluk hizli erisim cubugu (dokun -> eline al)
##   - Sag ust: aclik/can barlari, gun etiketi; sag alt: aksiyon + tasi
##   - Envanter paneli: kare slotlar, surukle-birak, panel disina
##     birakinca esya yere dusur
##   - Uretim paneli: kategori sekmeleri + arama, kart izgarasi,
##     sagda detay (adet sec + uret), zamanli uretim kuyrugu cubugu

## Sag alttaki aksiyon butonuna basilinca yayinlanir.
signal action_pressed

## Sandik paneli: esya tasima istegi (to_chest: true = sandiga koy)
signal chest_transfer_requested(item_id: String, to_chest: bool)
## Bos sandigi sokme istegi
signal chest_dismantle_requested
## Panel X ile kapatildi (World acik sandik kaydini temizler)
signal chest_closed

## Tasima modu acildi/kapandi (Tasi butonu)
signal move_toggled(enabled: bool)

## Envanterden bir esyayi eline alma istegi (bos string = birak)
signal hold_requested(item_id: String)

## Envanter slotu panel disina suruklendi: esya yere birakilsin
signal drop_item_requested(slot_index: int)

const Items = preload("res://scripts/items.gd")
const Recipes = preload("res://scripts/recipes.gd")
const UiSlotScript = preload("res://scripts/ui_slot.gd")

const ICON_FIST := preload("res://assets/ui/fist.png")
const ICON_GATHER := preload("res://assets/ui/axe.png")
const ICON_BUILD := preload("res://assets/ui/hammer.png")
const ICON_DIG := preload("res://assets/ui/shovel.png")
const ICON_MOVE := preload("res://assets/ui/move.png")
const ICON_SPEAR := preload("res://assets/ui/spear.png")
const ICON_CLOSE := preload("res://assets/ui/close_x.png")

@onready var action_button: Button = $ActionButton
@onready var move_button: Button = $MoveButton
@onready var reset_button: Button = $ResetButton
@onready var stats_box: HBoxContainer = $StatsPanel/HBox
@onready var day_label: Label = $DayLabel

# Ikonlu durum gostergeleri (kalp/mide/damla) - _build_stats kurar
var eat_button: Button
var _heart_bar: TextureProgressBar
var _heart_label: Label
var _stomach_bar: TextureProgressBar
var _stomach_label: Label
var _drop_bar: TextureProgressBar
var _drop_label: Label

@onready var inventory_button: Button = $InventoryButton
@onready var inventory_panel: PanelContainer = $InventoryPanel
@onready var inventory_title: Label = $InventoryPanel/VBox/TitleRow/Title
@onready var inventory_close: Button = $InventoryPanel/VBox/TitleRow/CloseButton
@onready var panel_hotbar_row: HBoxContainer = $InventoryPanel/VBox/HotbarRow
@onready var inventory_grid: GridContainer = $InventoryPanel/VBox/Slots
@onready var inventory_detail: Label = $InventoryPanel/VBox/Detail
@onready var panel_eat_button: Button = $InventoryPanel/VBox/ButtonRow/PanelEatButton
@onready var hold_button: Button = $InventoryPanel/VBox/ButtonRow/HoldButton

@onready var hotbar_box: HBoxContainer = $HotBar

@onready var craft_button: Button = $CraftButton
@onready var craft_mini_bar: ProgressBar = $CraftMiniBar
@onready var craft_panel: PanelContainer = $CraftPanel
@onready var craft_close: Button = $CraftPanel/VBox/TitleRow/CloseButton
@onready var cat_box: HBoxContainer = $CraftPanel/VBox/FilterRow/CatBox
@onready var search_edit: LineEdit = $CraftPanel/VBox/FilterRow/Search
@onready var cards_grid: GridContainer = $CraftPanel/VBox/Body/Scroll/Cards
@onready var detail_box: VBoxContainer = $CraftPanel/VBox/Body/DetailBox
@onready var queue_row: HBoxContainer = $CraftPanel/VBox/QueueRow
@onready var queue_label: Label = $CraftPanel/VBox/QueueRow/QueueLabel
@onready var queue_bar: ProgressBar = $CraftPanel/VBox/QueueRow/QueueBar

@onready var chest_panel: PanelContainer = $ChestPanel
@onready var chest_title: Label = $ChestPanel/VBox/TitleRow/Title
@onready var chest_close_button: Button = $ChestPanel/VBox/TitleRow/CloseButton
@onready var chest_rows: VBoxContainer = $ChestPanel/VBox/Scroll/Rows
@onready var chest_dismantle_button: Button = $ChestPanel/VBox/DismantleButton

var _selected_item: String = ""   # envanter panelinde secili esya
var _held_item: String = ""       # World bildirir (vurgu + detay icin)
var _action_state: String = "idle"

var _inv_slots: Array = []        # 16 UiSlot (envanter izgarasi)
var _panel_hotbar_slots: Array = []  # paneldeki 8 hotbar gozu
var _mini_hotbar_slots: Array = []   # ekran altindaki 8 hotbar gozu

var _selected_recipe: String = "" # uretim panelinde secili tarif
var _craft_qty: int = 1
var _current_cat: String = "tumu"
var _recipe_cards: Dictionary = {}  # recipe_id -> kart butonu
var _cat_buttons: Dictionary = {}   # kategori -> buton

# Uretim detay kutusu referanslari (bir kez kurulur)
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_desc: Label
var _detail_station: Label
var _detail_costs: VBoxContainer
var _detail_time: Label
var _qty_label: Label
var _craft_go_button: Button

func _ready() -> void:
	Inventory.changed.connect(_refresh)
	Crafting.station_changed.connect(_update_cards)
	Crafting.queue_changed.connect(_update_cards)
	Hunger.changed.connect(_update_hunger)
	Thirst.changed.connect(_update_thirst)
	Health.changed.connect(_update_health)
	DayNight.changed.connect(_update_day_label)
	action_button.pressed.connect(func(): action_pressed.emit())
	action_button.icon = ICON_FIST
	move_button.icon = ICON_MOVE
	move_button.toggled.connect(func(pressed: bool): move_toggled.emit(pressed))
	_build_stats()
	eat_button.pressed.connect(_on_eat_pressed)
	reset_button.pressed.connect(_on_reset_pressed)

	inventory_button.toggled.connect(_on_inventory_toggled)
	inventory_close.icon = ICON_CLOSE
	inventory_close.pressed.connect(func(): inventory_button.button_pressed = false)
	panel_eat_button.pressed.connect(_on_eat_pressed)
	hold_button.pressed.connect(_on_hold_pressed)

	craft_button.toggled.connect(_on_craft_toggled)
	craft_close.icon = ICON_CLOSE
	craft_close.pressed.connect(func(): craft_button.button_pressed = false)
	search_edit.text_changed.connect(func(_t: String): _rebuild_cards())

	chest_close_button.icon = ICON_CLOSE
	chest_close_button.pressed.connect(func():
		close_chest()
		chest_closed.emit())
	chest_dismantle_button.pressed.connect(func(): chest_dismantle_requested.emit())
	chest_panel.visible = false

	_apply_ui_theme()
	_setup_damage_flash()
	_build_slots()
	_build_category_buttons()
	_build_detail_box()
	_rebuild_cards()
	_refresh()
	_update_health()
	_update_day_label()
	_update_hunger()

func _process(_delta: float) -> void:
	# Uretim kuyrugu ilerlemesi (her kare akici dolsun)
	var progress := Crafting.get_progress()
	var busy := progress >= 0.0
	craft_mini_bar.visible = busy
	queue_row.visible = busy
	if busy:
		craft_mini_bar.value = progress
		queue_bar.value = progress
		var entry: Dictionary = Crafting.queue[0]
		var text := "Üretiliyor: %s (%d kaldı)" % [
			Items.display_name(entry["id"]), Crafting.get_total_remaining()]
		if Crafting.blocked:
			text = "Envanter dolu! Yer aç..."
		queue_label.text = text

# --- Paneller ac/kapat --------------------------------------------------

func _on_inventory_toggled(pressed: bool) -> void:
	inventory_panel.visible = pressed
	if pressed:
		craft_button.button_pressed = false
		close_chest()
		chest_closed.emit()
		_refresh()

func _on_craft_toggled(pressed: bool) -> void:
	craft_panel.visible = pressed
	if pressed:
		inventory_button.button_pressed = false
		close_chest()
		chest_closed.emit()
		_update_cards()

# --- Slotlarin kurulumu -------------------------------------------------

func _build_slots() -> void:
	# Envanter izgarasi: 16 sabit slot (canta yoksa sondakiler kilitli)
	for i in Inventory.TOTAL_SLOTS:
		var slot := _make_slot("inv", i)
		slot.dropped_to_ground.connect(_on_dropped_to_ground)
		inventory_grid.add_child(slot)
		_inv_slots.append(slot)
	# Paneldeki hizli erisim sirasi
	for i in Inventory.HOTBAR_SIZE:
		var slot := _make_slot("hotbar", i)
		panel_hotbar_row.add_child(slot)
		_panel_hotbar_slots.append(slot)
	# Ekran altindaki hizli erisim cubugu
	for i in Inventory.HOTBAR_SIZE:
		var slot := _make_slot("hotbar", i)
		hotbar_box.add_child(slot)
		_mini_hotbar_slots.append(slot)

func _make_slot(kind: String, index: int) -> UiSlotScript:
	var slot: UiSlotScript = UiSlotScript.new()
	slot.kind = kind
	slot.index = index
	slot.pressed.connect(_on_slot_tapped.bind(slot))
	slot.drop_received.connect(_on_slot_drop.bind(slot))
	return slot

# --- Slot etkilesimleri -------------------------------------------------

func _on_slot_tapped(slot: UiSlotScript) -> void:
	if slot.kind == "hotbar":
		# Hizli erisim: dokununca eline al / birak
		if slot.item_id == "" or slot.item_count <= 0:
			return
		hold_requested.emit("" if _held_item == slot.item_id else slot.item_id)
	else:
		if slot.item_id == "":
			return
		_selected_item = slot.item_id
		_update_detail()

func _on_slot_drop(data: Dictionary, target: UiSlotScript) -> void:
	if target.kind == "inv":
		if data["kind"] == "inv":
			Inventory.move_slot(data["index"], target.index)
		else:
			# Hotbar atamasi envantere geri suruklendi: atamayi kaldir
			Inventory.set_hotbar(data["index"], "")
	else:
		if data["kind"] == "inv":
			Inventory.set_hotbar(target.index, data["id"])
		else:
			Inventory.swap_hotbar(data["index"], target.index)

func _on_dropped_to_ground(data: Dictionary) -> void:
	drop_item_requested.emit(data["index"])

# --- Icerik yenileme ----------------------------------------------------

func _refresh() -> void:
	var capacity := Inventory.get_slot_count()
	for i in _inv_slots.size():
		var slot: UiSlotScript = _inv_slots[i]
		var content = Inventory.slots[i]
		if content == null:
			slot.set_content("", 0)
			slot.set_locked(i >= capacity)
		else:
			slot.set_locked(false)
			slot.set_content(content["id"], content["count"])
	inventory_title.text = "Envanter (%d/%d)" % [Inventory.get_used_slots(), capacity]
	_refresh_hotbar(_panel_hotbar_slots)
	_refresh_hotbar(_mini_hotbar_slots)
	_update_detail()
	_update_cards()
	_update_hunger()

func _refresh_hotbar(slot_list: Array) -> void:
	for i in slot_list.size():
		var slot: UiSlotScript = slot_list[i]
		if i >= Inventory.HOTBAR_UNLOCKED:
			slot.set_locked(true)
			continue
		slot.set_locked(false)
		var id: String = Inventory.hotbar[i]
		slot.set_content(id, Inventory.get_count(id) if id != "" else 0)
		slot.selected = id != "" and id == _held_item

func _update_detail() -> void:
	if _selected_item == "" or Inventory.get_count(_selected_item) <= 0:
		inventory_detail.text = "Bir esyaya dokun: detayi burada gorunur. " + \
				"Esyalari surukleyip tasi; panel disina birakirsan yere duser."
		panel_eat_button.visible = false
		hold_button.visible = false
		return
	inventory_detail.text = "%s x%d - %s" % [
		Items.display_name(_selected_item),
		Inventory.get_count(_selected_item),
		Items.description(_selected_item),
	]
	panel_eat_button.visible = _selected_item == "meyve"
	hold_button.visible = true
	hold_button.text = "Bırak" if _held_item == _selected_item else "Eline Al"

func _on_hold_pressed() -> void:
	if _selected_item == "":
		return
	hold_requested.emit("" if _held_item == _selected_item else _selected_item)

## World bildirir: eldeki esya degisti (vurgu + buton metni guncellenir)
func set_held_item(item_id: String) -> void:
	_held_item = item_id
	_refresh_hotbar(_panel_hotbar_slots)
	_refresh_hotbar(_mini_hotbar_slots)
	_update_detail()

# --- Can / aclik / susuzluk gostergeleri --------------------------------

# Sag ustteki ikonlu gostergeler: kalp (can), mide (aclik), damla (su).
# Ikonun ici degerle orantili dolar; ikona dokununca altinda "50/100"
# gibi sayi acilir/kapanir.
func _build_stats() -> void:
	var heart := _make_stat_widget("kalp")
	_heart_bar = heart[0]
	_heart_label = heart[1]
	var stomach := _make_stat_widget("mide")
	_stomach_bar = stomach[0]
	_stomach_label = stomach[1]
	var drop := _make_stat_widget("damla")
	_drop_bar = drop[0]
	_drop_label = drop[1]
	eat_button = Button.new()
	eat_button.text = "Ye"
	eat_button.add_theme_font_size_override("font_size", 20)
	eat_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	stats_box.add_child(eat_button)
	_update_thirst()

# Tek gosterge: alttan dolan ikon + gizli deger etiketi. [bar, label] doner.
func _make_stat_widget(icon_name: String) -> Array:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var bar := TextureProgressBar.new()
	bar.texture_under = load("res://assets/ui/%s_bos.png" % icon_name)
	bar.texture_progress = load("res://assets/ui/%s_dolu.png" % icon_name)
	bar.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	bar.max_value = 100.0
	bar.value = 100.0
	bar.custom_minimum_size = Vector2(48, 48)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var label := Label.new()
	label.visible = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	bar.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			label.visible = not label.visible)
	box.add_child(bar)
	box.add_child(label)
	stats_box.add_child(box)
	return [bar, label]

func _update_hunger() -> void:
	if _stomach_bar == null:
		return
	_stomach_bar.value = Hunger.value
	_stomach_label.text = "%d/100" % int(Hunger.value)
	eat_button.disabled = Inventory.get_count("meyve") <= 0 or Hunger.value >= Hunger.MAX_VALUE

func _update_thirst() -> void:
	if _drop_bar == null:
		return
	_drop_bar.value = Thirst.value
	_drop_label.text = "%d/100" % int(Thirst.value)

func _on_eat_pressed() -> void:
	if Inventory.remove_item("meyve", 1):
		Hunger.eat(25.0)

# Kayitli oyunu silip sifirdan baslar.
func _on_reset_pressed() -> void:
	SaveManager.delete_save()
	Inventory.reset()
	Crafting.reset()
	Hunger.reset()
	Thirst.reset()
	Health.reset()
	DayNight.reset()
	get_tree().reload_current_scene()

func _update_health() -> void:
	if _heart_bar != null:
		_heart_bar.value = Health.value
		_heart_label.text = "%d/100" % int(Health.value)
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

# --- Uretim paneli ------------------------------------------------------

func _build_category_buttons() -> void:
	var group := ButtonGroup.new()
	var cats := {"tumu": "Tümü"}
	cats.merge(Recipes.CATEGORIES)
	for cat_id in cats:
		var button := Button.new()
		button.text = cats[cat_id]
		button.toggle_mode = true
		button.button_group = group
		button.add_theme_font_size_override("font_size", 17)
		button.button_pressed = cat_id == _current_cat
		button.toggled.connect(func(pressed: bool):
			if pressed:
				_current_cat = cat_id
				_rebuild_cards())
		cat_box.add_child(button)
		_cat_buttons[cat_id] = button

# Kart izgarasini filtreye gore yeniden kurar.
func _rebuild_cards() -> void:
	for child in cards_grid.get_children():
		child.queue_free()
	_recipe_cards.clear()
	var group := ButtonGroup.new()
	var query := search_edit.text.strip_edges().to_lower()
	for recipe_id in Recipes.CRAFT_RECIPES:
		var recipe: Dictionary = Recipes.CRAFT_RECIPES[recipe_id]
		if _current_cat != "tumu" and recipe["category"] != _current_cat:
			continue
		if query != "" and not Items.display_name(recipe_id).to_lower().contains(query):
			continue
		var card := _make_recipe_card(recipe_id, recipe, group)
		cards_grid.add_child(card)
		_recipe_cards[recipe_id] = card
	# Secili tarif filtreyle kaybolduysa secimi koru ama detayda goster
	_update_cards()

# Tek tarif karti: ikon + ad + maliyet ikonlari (dokun -> detay)
func _make_recipe_card(recipe_id: String, recipe: Dictionary, group: ButtonGroup) -> Button:
	var card := Button.new()
	card.toggle_mode = true
	card.button_group = group
	card.custom_minimum_size = Vector2(128, 128)
	card.button_pressed = recipe_id == _selected_recipe
	card.toggled.connect(func(pressed: bool):
		if pressed:
			_select_recipe(recipe_id))

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 8
	box.offset_bottom = -8
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	var icon := TextureRect.new()
	icon.texture = load(Items.ITEMS[recipe_id]["icon"])
	icon.custom_minimum_size = Vector2(0, 52)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var name_label := Label.new()
	name_label.text = Items.display_name(recipe_id)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)

	var cost_row := HBoxContainer.new()
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 4)
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item_id in recipe["cost"]:
		var cost_icon := TextureRect.new()
		cost_icon.texture = load(Items.ITEMS[item_id]["icon"])
		cost_icon.custom_minimum_size = Vector2(18, 18)
		cost_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cost_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cost_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_row.add_child(cost_icon)
		var cost_label := Label.new()
		cost_label.text = str(recipe["cost"][item_id])
		cost_label.add_theme_font_size_override("font_size", 14)
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_row.add_child(cost_label)
	box.add_child(cost_row)
	return card

# Sag detay kutusunu bir kez kurar.
func _build_detail_box() -> void:
	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(0, 56)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_box.add_child(_detail_icon)

	_detail_name = Label.new()
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_name.add_theme_font_size_override("font_size", 22)
	detail_box.add_child(_detail_name)

	_detail_desc = Label.new()
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.add_theme_font_size_override("font_size", 15)
	detail_box.add_child(_detail_desc)

	_detail_station = Label.new()
	_detail_station.add_theme_font_size_override("font_size", 15)
	detail_box.add_child(_detail_station)

	_detail_costs = VBoxContainer.new()
	_detail_costs.add_theme_constant_override("separation", 2)
	detail_box.add_child(_detail_costs)

	_detail_time = Label.new()
	_detail_time.add_theme_font_size_override("font_size", 15)
	detail_box.add_child(_detail_time)

	# Adet secimi: [-] [x1] [+] [Max]
	var qty_row := HBoxContainer.new()
	qty_row.alignment = BoxContainer.ALIGNMENT_CENTER
	qty_row.add_theme_constant_override("separation", 8)
	var minus := Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(44, 44)
	minus.pressed.connect(func(): _set_qty(_craft_qty - 1))
	qty_row.add_child(minus)
	_qty_label = Label.new()
	_qty_label.text = "x1"
	_qty_label.custom_minimum_size = Vector2(50, 0)
	_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qty_label.add_theme_font_size_override("font_size", 22)
	qty_row.add_child(_qty_label)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(44, 44)
	plus.pressed.connect(func(): _set_qty(_craft_qty + 1))
	qty_row.add_child(plus)
	var maxb := Button.new()
	maxb.text = "Max"
	maxb.custom_minimum_size = Vector2(0, 44)
	maxb.pressed.connect(func():
		if _selected_recipe != "":
			_set_qty(Crafting.max_craftable(_selected_recipe)))
	qty_row.add_child(maxb)
	detail_box.add_child(qty_row)

	_craft_go_button = Button.new()
	_craft_go_button.text = "Üret"
	_craft_go_button.custom_minimum_size = Vector2(0, 52)
	_craft_go_button.add_theme_font_size_override("font_size", 22)
	_craft_go_button.pressed.connect(_on_craft_go)
	detail_box.add_child(_craft_go_button)

	_update_detail_box()

func _select_recipe(recipe_id: String) -> void:
	_selected_recipe = recipe_id
	_craft_qty = 1
	_update_detail_box()

func _set_qty(value: int) -> void:
	var cap := 99
	if _selected_recipe != "":
		cap = maxi(1, Crafting.max_craftable(_selected_recipe))
	_craft_qty = clampi(value, 1, cap)
	_update_detail_box()

func _on_craft_go() -> void:
	if _selected_recipe == "":
		return
	if Crafting.enqueue(_selected_recipe, _craft_qty):
		_craft_qty = 1
	_update_detail_box()

# Kart soluklugu (uretilemeyenler) + detay kutusunu gunceller.
func _update_cards() -> void:
	for recipe_id in _recipe_cards:
		var can := Crafting.max_craftable(recipe_id) >= 1
		_recipe_cards[recipe_id].modulate = Color.WHITE if can else Color(1, 1, 1, 0.55)
	_update_detail_box()

func _update_detail_box() -> void:
	if _detail_name == null:
		return
	if _selected_recipe == "":
		_detail_icon.texture = null
		_detail_name.text = "Bir tarif seç"
		_detail_desc.text = "Soldan bir karta dokun; adet seçip üretime başla."
		_detail_station.text = ""
		_detail_time.text = ""
		_qty_label.text = ""
		_craft_go_button.disabled = true
		for child in _detail_costs.get_children():
			child.queue_free()
		return
	var recipe: Dictionary = Recipes.CRAFT_RECIPES[_selected_recipe]
	_detail_icon.texture = load(Items.ITEMS[_selected_recipe]["icon"])
	var out_count: int = recipe["output"][_selected_recipe]
	_detail_name.text = Items.display_name(_selected_recipe) + \
			(" x%d" % out_count if out_count > 1 else "")
	_detail_desc.text = Items.description(_selected_recipe)
	if recipe["station"] != "":
		_detail_station.text = "Tezgah gerekli" + \
				("" if Crafting.near_station else " - yanında değilsin!")
		_detail_station.add_theme_color_override("font_color",
				Color(0.2, 0.55, 0.25) if Crafting.near_station else Color(0.8, 0.25, 0.2))
	else:
		_detail_station.text = ""
	# Malzeme listesi: "ikon Ad  3/2" (eldeki/gereken)
	for child in _detail_costs.get_children():
		child.queue_free()
	for item_id in recipe["cost"]:
		var need: int = recipe["cost"][item_id] * _craft_qty
		var have := Inventory.get_count(item_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var icon := TextureRect.new()
		icon.texture = load(Items.ITEMS[item_id]["icon"])
		icon.custom_minimum_size = Vector2(22, 22)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var label := Label.new()
		label.text = "%s  %d/%d" % [Items.display_name(item_id), have, need]
		label.add_theme_font_size_override("font_size", 16)
		if have < need:
			label.add_theme_color_override("font_color", Color(0.8, 0.25, 0.2))
		row.add_child(label)
		_detail_costs.add_child(row)
	_detail_time.text = "Süre: %.1f sn / adet" % float(recipe["time"])
	_qty_label.text = "x%d" % _craft_qty
	_craft_go_button.disabled = Crafting.max_craftable(_selected_recipe) < 1

# --- Gorsel tema ----------------------------------------------------------

# Go-Go Town tarzi krem/pastel tema: yuvarlak koseli krem kartlar,
# koyu kahve yazi, turuncu vurgu. Tema ust seviye Control'lere atanir;
# sonradan eklenen cocuklar (kartlar, slotlar) otomatik miras alir.
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

	# Arama kutusu da krem gorunsun
	var edit_style: StyleBoxFlat = button_style.duplicate()
	edit_style.bg_color = Color.WHITE
	edit_style.shadow_size = 0
	theme.set_stylebox("normal", "LineEdit", edit_style)
	theme.set_color("font_color", "LineEdit", COL_BROWN)

	# Hap seklinde bar govdesi (aclik/can/uretim ortak arka plan)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.88, 0.82, 0.71)
	bar_bg.set_corner_radius_all(9)
	bar_bg.border_color = COL_BROWN_SOFT
	bar_bg.set_border_width_all(1)
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	# Varsayilan bar dolgusu turuncu (uretim cubuklari)
	theme.set_stylebox("fill", "ProgressBar", _make_bar_fill(COL_ORANGE))

	for child in get_children():
		if child is Control:
			child.theme = theme

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

# --- Sandik paneli ------------------------------------------------------

## World tarafindan cagrilir: paneli verilen icerikle (yeniden) cizer.
## message: baslikta gosterilecek kisa uyari (orn. "Envanter dolu!")
func show_chest(contents: Dictionary, message: String = "") -> void:
	chest_title.text = "Sandık" if message == "" else "Sandık - %s" % message
	chest_panel.visible = true
	inventory_button.button_pressed = false
	craft_button.button_pressed = false
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
	label.modulate = Color(0.85, 0.6, 0.3)
	chest_rows.add_child(label)

func _add_chest_note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.modulate = Color(0.6, 0.55, 0.5)
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
