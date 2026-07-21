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

## Saldiri butonu (12.1): sadece elde silahken gorunur. press = kisa
## dokunma (tek saldiri); hold_started/hold_released = basili tut (nisan)
signal attack_pressed
signal attack_hold_started
signal attack_hold_released

## Sandik paneli: esya tasima istegi (to_chest: true = sandiga koy)
signal chest_transfer_requested(item_id: String, to_chest: bool)
## 14.1 hizli aktarim: "Tümünü Koy"/"Tümünü Al" (to_chest: true = koy)
signal chest_transfer_all_requested(to_chest: bool)
## Bos sandigi sokme istegi
signal chest_dismantle_requested
## Panel X ile kapatildi (World acik sandik kaydini temizler)
signal chest_closed

## Tasima modu acildi/kapandi (Tasi butonu)
signal move_toggled(enabled: bool)

## Envanterden bir esyayi eline alma istegi (bos string = birak)
signal hold_requested(item_id: String)

## YASAM: yeme istegi (world3d ~1 sn tuketme eylemi olarak calistirir)
signal eat_requested(food_id: String)

## YAPI SISTEMI (13.2): yerlestirme modu istekleri
signal place_requested(item_id: String)  # envanterde "Yerleştir"
signal place_confirm                      # ONAYLA
signal place_rotate                       # DÖNDÜR 90°
signal place_cancel                       # İPTAL

## Envanter slotu panel disina suruklendi: esya yere birakilsin
signal drop_item_requested(slot_index: int)

const Items = preload("res://scripts/items.gd")
const Recipes = preload("res://scripts/recipes.gd")
const UiSlotScript = preload("res://scripts/ui_slot.gd")
const UIColors = preload("res://scripts/ui_colors.gd")

const ICON_FIST := preload("res://assets/ui/fist.png")
const ICON_GATHER := preload("res://assets/ui/axe.png")
const ICON_BUILD := preload("res://assets/ui/hammer.png")
const ICON_DIG := preload("res://assets/ui/shovel.png")
const ICON_MOVE := preload("res://assets/ui/move.png")
const ICON_SPEAR := preload("res://assets/ui/spear.png")
const ICON_CLOSE := preload("res://assets/ui/close_x.png")

## Baglam-duyarli ana buton ikonlari (12.1): eylem turu -> doku.
## Yer tutucu (UI_DESIGN placeholder kurali); eksikse fist'e duser.
const ACTION_ICONS := {
	"chop": preload("res://assets/ui/axe.png"),
	"mine": preload("res://assets/ui/pick.png"),
	"dig": preload("res://assets/ui/shovel.png"),
	"pile": preload("res://assets/ui/shovel.png"),
	"fill": preload("res://assets/ui/fill.png"),
	"pour": preload("res://assets/ui/pour.png"),
	"harvest": preload("res://assets/ui/grab.png"),
	"grab": preload("res://assets/ui/grab.png"),
	"repair": preload("res://assets/ui/hammer.png"),
	"open": preload("res://assets/ui/open.png"),
	"attack": preload("res://assets/ui/attack.png"),
	"spear": preload("res://assets/ui/spear.png"),
	"fist": preload("res://assets/ui/fist.png"),
}

@onready var action_button: Button = $ActionButton
@onready var attack_button: Button = $AttackButton
@onready var move_button: Button = $MoveButton
@onready var reset_button: Button = $ResetButton
@onready var stats_box: VBoxContainer = $StatsPanel/HBox
@onready var day_pill: PanelContainer = $DayPill
@onready var day_dot: Panel = $DayPill/HBox/SunDot
@onready var day_label: Label = $DayPill/HBox/DayText
@onready var research_button: Button = $ResearchButton
@onready var research_root: Control = $ResearchRoot

# Durum barlari (kalp/mide/damla) - _build_stats kurar (UI_DESIGN 4.1)
var eat_button: Button
var _heart_bar: ProgressBar
var _stomach_bar: ProgressBar
var _drop_bar: ProgressBar

@onready var inventory_button: Button = $InventoryButton
@onready var inventory_root: Control = $InventoryRoot
@onready var inventory_close: Button = $InventoryRoot/InventoryPanel/VBox/TopRow/CloseButton
@onready var inventory_grid: GridContainer = $InventoryRoot/InventoryPanel/VBox/Slots
@onready var item_name_label: Label = $InventoryRoot/InventoryPanel/VBox/InfoStrip/InfoBox/ItemName
@onready var item_desc_label: Label = $InventoryRoot/InventoryPanel/VBox/InfoStrip/InfoBox/ItemDesc
@onready var panel_eat_button: Button = $InventoryRoot/InventoryPanel/VBox/InfoStrip/InfoBox/ButtonRow/PanelEatButton
@onready var hold_button: Button = $InventoryRoot/InventoryPanel/VBox/InfoStrip/InfoBox/ButtonRow/HoldButton
@onready var drop_button: Button = $InventoryRoot/InventoryPanel/VBox/InfoStrip/InfoBox/ButtonRow/DropButton
@onready var capacity_label: Label = $InventoryRoot/InventoryPanel/VBox/CapacityRow/CapacityLabel

@onready var hotbar_box: HBoxContainer = $HotbarStrip/HotBar
@onready var hotbar_strip: PanelContainer = $HotbarStrip

@onready var craft_button: Button = $CraftButton
@onready var craft_mini_bar: ProgressBar = $CraftMiniBar
@onready var craft_root: Control = $CraftRoot
@onready var craft_panel: PanelContainer = $CraftRoot/CraftPanel
@onready var craft_close: Button = $CraftRoot/CraftPanel/HBox/RightBox/TopRow/CloseButton
@onready var cat_box: VBoxContainer = $CraftRoot/CraftPanel/HBox/CatColumn
@onready var search_edit: LineEdit = $CraftRoot/CraftPanel/HBox/RightBox/TopRow/Search
@onready var cards_box: VBoxContainer = $CraftRoot/CraftPanel/HBox/RightBox/Body/Scroll/Cards
@onready var queue_row: HBoxContainer = $CraftRoot/CraftPanel/HBox/RightBox/QueueRow
@onready var queue_label: Label = $CraftRoot/CraftPanel/HBox/RightBox/QueueRow/QueueLabel
@onready var queue_bar: ProgressBar = $CraftRoot/CraftPanel/HBox/RightBox/QueueRow/QueueBar

@onready var chest_panel: PanelContainer = $ChestPanel
@onready var chest_title: Label = $ChestPanel/VBox/TitleRow/Title
@onready var chest_close_button: Button = $ChestPanel/VBox/TitleRow/CloseButton
@onready var chest_rows: VBoxContainer = $ChestPanel/VBox/Scroll/Rows
@onready var chest_dismantle_button: Button = $ChestPanel/VBox/DismantleButton

var _selected_item: String = ""   # envanter panelinde secili esya
var _selected_slot: int = -1      # secili envanter slotunun indeksi
var _picked_slot: UiSlotScript = null  # tasima icin secilen slot (dokun-tasi)
var _held_item: String = ""       # World bildirir (vurgu + detay icin)
var _action_state: String = "idle"

var _inv_slots: Array = []        # 16 UiSlot (envanter izgarasi)
var _mini_hotbar_slots: Array = []   # ekran altindaki 8 hotbar gozu

var _current_cat: String = "tumu"
var _recipe_cards: Dictionary = {}  # recipe_id -> kart bilgileri (dict)
var _cat_buttons: Dictionary = {}   # kategori -> buton

# Eski oyun kategorileri -> UI kategori renk anahtari
const CAT_COLOR_KEY := {"malzeme": "resource", "alet": "tool",
		"savas": "weapon", "yapi": "structure", "tarim": "farming",
		"pisirme": "resource"}

func _ready() -> void:
	Inventory.changed.connect(_refresh)
	Crafting.station_changed.connect(_update_cards)
	Crafting.queue_changed.connect(_update_cards)
	Hunger.changed.connect(_update_hunger)
	Thirst.changed.connect(_update_thirst)
	Health.changed.connect(_update_health)
	# YASAM: aclik esigi uyarisi -> mide barinda warning nabzi (UI_DESIGN 4.1)
	PlayerStats.hunger_warning.connect(_on_hunger_warning)
	PlayerStats.hunger_recovered.connect(_on_hunger_recovered)
	DayNight.changed.connect(_update_day_label)
	action_button.pressed.connect(func():
		_pop_button(action_button)
		action_pressed.emit())
	action_button.icon = ICON_FIST
	# Saldiri butonu: kisa dokunma = saldiri; basili tut = nisan (menzilli)
	attack_button.icon = ACTION_ICONS["attack"]
	attack_button.visible = false
	attack_button.button_down.connect(_on_attack_down)
	attack_button.button_up.connect(_on_attack_up)
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
	drop_button.pressed.connect(_on_drop_pressed)
	_build_place_ui()

	craft_button.toggled.connect(_on_craft_toggled)
	research_button.toggled.connect(_on_research_toggled)
	research_root.closed.connect(func(): research_button.set_pressed_no_signal(false))
	craft_close.icon = ICON_CLOSE
	craft_close.pressed.connect(func(): craft_button.button_pressed = false)
	search_edit.text_changed.connect(func(_t: String): _rebuild_cards())

	chest_close_button.icon = ICON_CLOSE
	chest_close_button.pressed.connect(func():
		close_chest()
		chest_closed.emit())
	chest_dismantle_button.pressed.connect(func(): chest_dismantle_requested.emit())
	chest_panel.visible = false

	# theme_main.tres tum ust duzey Control'lere uygulanir (UI_DESIGN 6)
	var main_theme: Theme = load("res://theme_main.tres")
	for child in get_children():
		if child is Control:
			(child as Control).theme = main_theme
	_setup_damage_flash()
	_setup_night_fx()
	_build_slots()
	_build_category_buttons()
	_rebuild_cards()
	_refresh()
	_update_health()
	_update_day_label()
	_update_hunger()

func _process(_delta: float) -> void:
	_update_day_pulse()
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

# Envanter paneli sagdan kayarak girer/cikar (0.25sn ease-out)
var _inv_tween: Tween

func _on_inventory_toggled(pressed: bool) -> void:
	if pressed:
		craft_button.button_pressed = false
		research_button.button_pressed = false
		close_chest()
		chest_closed.emit()
		_refresh()
	if _inv_tween != null:
		_inv_tween.kill()
	_inv_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var width := inventory_root.size.x + 24.0
	if pressed:
		inventory_root.visible = true
		inventory_root.position.x += width  # disaridan basla
		_inv_tween.tween_property(inventory_root, "position:x",
				inventory_root.position.x - width, 0.25)
	else:
		_picked_slot = null
		_inv_tween.tween_property(inventory_root, "position:x",
				inventory_root.position.x + width, 0.22)
		_inv_tween.tween_callback(func():
			inventory_root.visible = false
			inventory_root.position.x -= width)

# Uretim paneli yumusak scale ile acilir (0.96 -> 1.0, UI_DESIGN 4.5)
var _craft_tween: Tween

func _on_craft_toggled(pressed: bool) -> void:
	if pressed:
		inventory_button.button_pressed = false
		research_button.button_pressed = false
		close_chest()
		chest_closed.emit()
		_update_cards()
	if _craft_tween != null:
		_craft_tween.kill()
	craft_root.pivot_offset = craft_root.size / 2.0
	_craft_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if pressed:
		craft_root.visible = true
		craft_root.scale = Vector2.ONE * 0.96
		craft_root.modulate.a = 0.0
		_craft_tween.tween_property(craft_root, "scale", Vector2.ONE, 0.22)
		_craft_tween.parallel().tween_property(craft_root, "modulate:a", 1.0, 0.18)
	else:
		_craft_tween.tween_property(craft_root, "modulate:a", 0.0, 0.15)
		_craft_tween.tween_callback(func(): craft_root.visible = false)

func _on_research_toggled(pressed: bool) -> void:
	if pressed:
		inventory_button.button_pressed = false
		craft_button.button_pressed = false
		close_chest()
		chest_closed.emit()
		research_root.open()
	else:
		research_root.close()

# --- Slotlarin kurulumu -------------------------------------------------

func _build_slots() -> void:
	# Envanter izgarasi: 16 sabit slot (canta yoksa sondakiler kilitli)
	for i in Inventory.TOTAL_SLOTS:
		var slot := _make_slot("inv", i)
		inventory_grid.add_child(slot)
		_inv_slots.append(slot)
	# Ekran altindaki hizli erisim seridi: 5 gozluk (UI_DESIGN 4.1)
	for i in 5:
		var slot := _make_slot("hotbar", i)
		hotbar_box.add_child(slot)
		_mini_hotbar_slots.append(slot)

func _make_slot(kind: String, index: int) -> UiSlotScript:
	var slot: UiSlotScript = UiSlotScript.new()
	slot.kind = kind
	slot.index = index
	slot.pressed.connect(_on_slot_tapped.bind(slot))
	return slot

# --- Slot etkilesimleri ---------------------------------------------------
# Dokun-sec-dokun-yerlestir (UI_DESIGN 5): ilk dokunus esyayi secer
# (bilgi seridi acilir + tasima moduna girer), ikinci dokunus hedef
# slota tasir/atar. Ayni slota tekrar dokunmak secimi birakir.

func _on_slot_tapped(slot: UiSlotScript) -> void:
	# Tasima modundaysak: bu dokunus HEDEF secimidir
	if _picked_slot != null and slot != _picked_slot:
		_perform_move(_picked_slot, slot)
		_clear_pick()
		return
	if slot == _picked_slot:
		_clear_pick()
		return
	if slot.kind == "hotbar":
		# Hizli erisim: panel kapaliyken dokununca eline al / birak
		if slot.item_id == "" or slot.item_count <= 0:
			return
		hold_requested.emit("" if _held_item == slot.item_id else slot.item_id)
		return
	if slot.item_id == "":
		return
	# Sec: bilgi seridi + tasima modu
	_selected_item = slot.item_id
	_selected_slot = slot.index
	_picked_slot = slot
	slot.picked = true
	_update_detail()

func _perform_move(from: UiSlotScript, target: UiSlotScript) -> void:
	if target.locked:
		return
	if from.kind == "inv" and target.kind == "inv":
		Inventory.move_slot(from.index, target.index)
	elif from.kind == "inv" and target.kind == "hotbar":
		Inventory.set_hotbar(target.index, from.item_id)
	elif from.kind == "hotbar" and target.kind == "hotbar":
		Inventory.swap_hotbar(from.index, target.index)
	else:
		# Hotbar atamasi envanter slotuna tasindi: atamayi kaldir
		Inventory.set_hotbar(from.index, "")

func _clear_pick() -> void:
	if _picked_slot != null:
		_picked_slot.picked = false
	_picked_slot = null

func _on_drop_pressed() -> void:
	if _selected_slot >= 0 and _selected_item != "":
		drop_item_requested.emit(_selected_slot)
		_clear_pick()

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
	capacity_label.text = "%d/%d" % [Inventory.get_used_slots(), capacity]
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
		var is_sel: bool = id != "" and id == _held_item
		slot.selected = is_sel
		# Secili slot hafif buyur (UI_DESIGN 4.1)
		slot.pivot_offset = slot.size / 2.0
		slot.scale = Vector2.ONE * (1.12 if is_sel else 1.0)

func _update_detail() -> void:
	if _selected_item == "" or Inventory.get_count(_selected_item) <= 0:
		item_name_label.text = ""
		item_desc_label.text = "Bir eşyaya dokun: bilgisi burada görünür. " + \
				"Seçtikten sonra başka bir slota dokunarak taşıyabilirsin."
		panel_eat_button.visible = false
		hold_button.visible = false
		drop_button.visible = false
		if place_button != null:
			place_button.visible = false
		return
	item_name_label.text = "%s ×%d" % [Items.display_name(_selected_item),
			Inventory.get_count(_selected_item)]
	item_desc_label.text = Items.description(_selected_item)
	panel_eat_button.visible = PlayerStats.is_edible(_selected_item)
	hold_button.visible = true
	drop_button.visible = true
	if place_button != null:
		place_button.visible = Items.PLACEABLE.has(_selected_item)
	hold_button.text = "Bırak" if _held_item == _selected_item else "Eline Al"

func _on_hold_pressed() -> void:
	if _selected_item == "":
		return
	hold_requested.emit("" if _held_item == _selected_item else _selected_item)

# --- YAPI SISTEMI yerlestirme arayuzu (13.2) ------------------------------
var place_button: Button
var _place_controls: HBoxContainer
var _place_confirm_btn: Button

func _build_place_ui() -> void:
	# Envanter bilgi seridine "Yerleştir" butonu (yerlestirilebilir item'da)
	place_button = Button.new()
	place_button.text = "Yerleştir"
	place_button.theme_type_variation = "PrimaryButton"
	place_button.visible = false
	place_button.pressed.connect(func():
		if _selected_item != "":
			inventory_button.button_pressed = false  # paneli kapat
			place_requested.emit(_selected_item))
	drop_button.get_parent().add_child(place_button)
	# Yerlestirme modu butonlari (ONAYLA / DÖNDÜR / İPTAL) — sag alt
	_place_controls = HBoxContainer.new()
	_place_controls.add_theme_constant_override("separation", 12)
	_place_controls.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_place_controls.offset_left = -360
	_place_controls.offset_top = -96
	_place_controls.offset_right = -16
	_place_controls.offset_bottom = -24
	_place_controls.grow_horizontal = 0
	_place_controls.grow_vertical = 0
	_place_controls.visible = false
	add_child(_place_controls)
	var rotate_btn := Button.new()
	rotate_btn.text = "Döndür"
	rotate_btn.theme_type_variation = "PrimaryButton"
	rotate_btn.pressed.connect(func(): place_rotate.emit())
	var cancel_btn := Button.new()
	cancel_btn.text = "İptal"
	cancel_btn.theme_type_variation = "PrimaryButton"
	cancel_btn.pressed.connect(func(): place_cancel.emit())
	_place_confirm_btn = Button.new()
	_place_confirm_btn.text = "Onayla"
	_place_confirm_btn.theme_type_variation = "PrimaryButton"
	_place_confirm_btn.custom_minimum_size = Vector2(120, 64)
	_place_confirm_btn.pressed.connect(func(): place_confirm.emit())
	_place_controls.add_child(cancel_btn)
	_place_controls.add_child(rotate_btn)
	_place_controls.add_child(_place_confirm_btn)

## World cagirir: yerlestirme modu ac/kapa (normal butonlar gizlenir).
func set_place_mode(on: bool) -> void:
	_place_controls.visible = on
	action_button.visible = not on
	move_button.visible = not on
	if on:
		attack_button.visible = false

## World bildirir: eldeki esya degisti (vurgu + buton metni guncellenir)
func set_held_item(item_id: String) -> void:
	_held_item = item_id
	_refresh_hotbar(_mini_hotbar_slots)
	_update_detail()

# --- Can / aclik / susuzluk gostergeleri --------------------------------

# Sag ustteki ikonlu gostergeler: kalp (can), mide (aclik), damla (su).
# Ikonun ici degerle orantili dolar; ikona dokununca altinda "50/100"
# gibi sayi acilir/kapanir.
func _build_stats() -> void:
	_heart_bar = _make_stat_bar("kalp", UIColors.DANGER)
	_stomach_bar = _make_stat_bar("mide", UIColors.category_color("tool"))
	_drop_bar = _make_stat_bar("damla", Color("#9FC5E8"))
	eat_button = Button.new()
	eat_button.text = "Ye"
	eat_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	stats_box.add_child(eat_button)
	_update_thirst()

# Tek durum satiri: ikon + pastel dolgulu kisa bar (UI_DESIGN 4.1)
func _make_stat_bar(icon_name: String, fill_color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/ui/%s_dolu.png" % icon_name)
	icon.custom_minimum_size = Vector2(26, 26)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(150, 20)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = UIColors.PANEL_CREAM_DARK
	bg.set_corner_radius_all(999)
	bg.border_color = UIColors.INK_DARK
	bg.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(999)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	stats_box.add_child(row)
	return bar

func _update_hunger() -> void:
	if _stomach_bar == null:
		return
	_stomach_bar.value = Hunger.value
	# Yenebilir bir sey var mi? (SurvivalBalance uzerinden — tek kaynak)
	eat_button.disabled = not _has_edible() or Hunger.value >= Hunger.MAX_VALUE

## Envanterde yenebilir (edible) bir esya var mi? (Ye butonu icin)
func _has_edible() -> bool:
	for item_id in Inventory.slots:
		if item_id != null and PlayerStats.is_edible(String(item_id["id"])):
			return true
	return false

var _hunger_pulse: Tween

## Aclik esigin altina dustu: mide barinda uyari nabzi (UI_DESIGN 4.1).
func _on_hunger_warning() -> void:
	if _stomach_bar == null or (_hunger_pulse != null and _hunger_pulse.is_valid()):
		return
	_hunger_pulse = create_tween().set_loops()
	_hunger_pulse.tween_property(_stomach_bar, "modulate", UIColors.WARNING, 0.5)
	_hunger_pulse.tween_property(_stomach_bar, "modulate", Color.WHITE, 0.5)

func _on_hunger_recovered() -> void:
	if _hunger_pulse != null and _hunger_pulse.is_valid():
		_hunger_pulse.kill()
	_hunger_pulse = null
	if _stomach_bar != null:
		_stomach_bar.modulate = Color.WHITE

func _update_thirst() -> void:
	if _drop_bar == null:
		return
	_drop_bar.value = Thirst.value

## Ye: secili esya yenebilirse onu, degilse envanterdeki ilk yiyecegi ye.
## Yeme world3d'de ~1 sn'lik tuketme eylemi olarak calisir (eat_requested).
func _on_eat_pressed() -> void:
	var food := ""
	if _selected_item != "" and PlayerStats.is_edible(_selected_item) \
			and Inventory.get_count(_selected_item) > 0:
		food = _selected_item
	else:
		for slot in Inventory.slots:
			if slot != null and PlayerStats.is_edible(String(slot["id"])):
				food = String(slot["id"])
				break
	if food != "":
		eat_requested.emit(food)

# Kayitli oyunu silip sifirdan baslar.
func _on_reset_pressed() -> void:
	SaveManager.delete_save()
	Inventory.reset()
	Research.reset()
	Crafting.reset()
	Hunger.reset()
	Thirst.reset()
	Health.reset()
	PlayerStats.reset()
	DayNight.reset()
	get_tree().reload_current_scene()

func _update_health() -> void:
	if _heart_bar != null:
		_heart_bar.value = Health.value
	if _damage_flash != null and Health.value < _prev_hp:
		_damage_flash.color.a = 0.3
		create_tween().tween_property(_damage_flash, "color:a", 0.0, 0.4)
	_prev_hp = Health.value

func _update_day_label() -> void:
	day_label.text = "Gün %d" % DayNight.day
	var dot := StyleBoxFlat.new()
	dot.set_corner_radius_all(999)
	# Gunes = sicak sari; ay = lavanta (UI_DESIGN 4.1)
	dot.bg_color = Color("#B9A0E8") if DayNight.is_night else UIColors.WARNING
	day_dot.add_theme_stylebox_override("panel", dot)

# Gece yaklasiyor uyarisi: son 60 sn'de pill nabiz atar (1sn dongu)
var _day_pulse: Tween
var _pulsing := false

func _update_day_pulse() -> void:
	var closing: bool = not DayNight.is_night \
			and DayNight.DAY_SECONDS - DayNight.elapsed <= 60.0
	if closing == _pulsing:
		return
	_pulsing = closing
	day_pill.pivot_offset = day_pill.size / 2.0
	if closing:
		_day_pulse = create_tween().set_loops()
		_day_pulse.tween_property(day_pill, "scale", Vector2.ONE * 1.04, 0.5)
		_day_pulse.tween_property(day_pill, "scale", Vector2.ONE, 0.5)
		day_pill.modulate = Color(1.0, 0.86, 0.55)
	else:
		if _day_pulse != null:
			_day_pulse.kill()
		day_pill.scale = Vector2.ONE
		day_pill.modulate = Color.WHITE

# --- Uretim paneli ------------------------------------------------------

func _build_category_buttons() -> void:
	var group := ButtonGroup.new()
	var cats := {"tumu": "Tümü"}
	cats.merge(Recipes.CATEGORIES)
	for cat_id in cats:
		var color: Color = UIColors.INK_FAINT
		if CAT_COLOR_KEY.has(cat_id):
			color = UIColors.category_color(CAT_COLOR_KEY[cat_id])
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(64, 64)
		button.text = String(cats[cat_id]).substr(0, 2)
		button.tooltip_text = String(cats[cat_id])
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(999)
		for state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, sb)
		for cname in ["font_color", "font_pressed_color", "font_hover_color"]:
			button.add_theme_color_override(cname, UIColors.INK_DARK)
		button.button_pressed = cat_id == _current_cat
		_apply_cat_state(button, cat_id == _current_cat)
		var cid: String = cat_id
		button.toggled.connect(func(pressed: bool):
			_apply_cat_state(button, pressed)
			if pressed:
				_current_cat = cid
				_rebuild_cards())
		cat_box.add_child(button)
		_cat_buttons[cat_id] = button

# Aktif sekme tam opak + hafif buyuk; pasifler %70 opak (UI_DESIGN 4.3)
func _apply_cat_state(button: Button, active: bool) -> void:
	button.modulate.a = 1.0 if active else 0.7
	button.pivot_offset = button.custom_minimum_size / 2.0
	button.scale = Vector2.ONE * (1.08 if active else 1.0)

# Kart listesini filtreye gore yeniden kurar.
func _rebuild_cards() -> void:
	for child in cards_box.get_children():
		child.queue_free()
	_recipe_cards.clear()
	var query := search_edit.text.strip_edges().to_lower()
	for recipe_id in Recipes.CRAFT_RECIPES:
		var recipe: Dictionary = Recipes.CRAFT_RECIPES[recipe_id]
		if _current_cat != "tumu" and recipe["category"] != _current_cat:
			continue
		if query != "" and not Items.display_name(recipe_id).to_lower().contains(query):
			continue
		cards_box.add_child(_make_recipe_card(recipe_id, recipe))
	_update_cards()

# Yatay tarif karti (UI_DESIGN 4.3):
# [kategori dairesi + ikon] [ad, malzemeler, istasyon] [Uret pill]
func _make_recipe_card(recipe_id: String, recipe: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var circle := Panel.new()
	circle.custom_minimum_size = Vector2(56, 56)
	circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIColors.category_color(
			CAT_COLOR_KEY.get(recipe["category"], "resource"))
	sb.set_corner_radius_all(999)
	circle.add_theme_stylebox_override("panel", sb)
	row.add_child(circle)
	var icon := TextureRect.new()
	icon.texture = load(Items.ITEMS[recipe_id]["icon"])
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 10
	icon.offset_top = 10
	icon.offset_right = -10
	icon.offset_bottom = -10
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	circle.add_child(icon)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 2)
	row.add_child(mid)
	var name_label := Label.new()
	var out_count: int = recipe["output"][recipe_id]
	name_label.text = Items.display_name(recipe_id) + \
			(" ×%d" % out_count if out_count > 1 else "")
	name_label.theme_type_variation = "BadgeLabel"
	mid.add_child(name_label)
	var mats_row := HBoxContainer.new()
	mats_row.add_theme_constant_override("separation", 10)
	mid.add_child(mats_row)
	var mats: Array = []
	for item_id in recipe["cost"]:
		var mat_box := HBoxContainer.new()
		mat_box.add_theme_constant_override("separation", 3)
		var mat_icon := TextureRect.new()
		mat_icon.texture = load(Items.ITEMS[item_id]["icon"])
		mat_icon.custom_minimum_size = Vector2(20, 20)
		mat_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mat_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mat_box.add_child(mat_icon)
		var mat_label := Label.new()
		mat_label.add_theme_font_size_override("font_size", 15)
		mat_box.add_child(mat_label)
		# Renk korlugu icin: yetersiz malzemede minik unlem rozeti
		var warn := Label.new()
		warn.text = "!"
		warn.theme_type_variation = "BadgeLabel"
		warn.add_theme_color_override("font_color", UIColors.DANGER)
		warn.visible = false
		mat_box.add_child(warn)
		mats_row.add_child(mat_box)
		mats.append({"id": item_id, "need": recipe["cost"][item_id],
				"label": mat_label, "warn": warn})
	var station_label := Label.new()
	station_label.theme_type_variation = "SubtleLabel"
	station_label.visible = recipe["station"] != ""
	mid.add_child(station_label)

	var craft_btn := Button.new()
	craft_btn.theme_type_variation = "PrimaryButton"
	craft_btn.text = "Üret"
	craft_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	craft_btn.pressed.connect(func(): _on_card_craft(recipe_id, craft_btn))
	row.add_child(craft_btn)

	card.gui_input.connect(func(event: InputEvent):
		if (event is InputEventMouseButton and event.pressed) \
				or (event is InputEventScreenTouch and event.pressed):
			if Crafting.max_craftable(recipe_id) < 1:
				_shake_card(recipe_id))
	_recipe_cards[recipe_id] = {"card": card, "button": craft_btn,
			"mats": mats, "station": station_label}
	return card

func _on_card_craft(recipe_id: String, from_button: Control) -> void:
	if Crafting.enqueue(recipe_id, 1):
		_fly_to_hotbar(recipe_id, from_button.get_global_rect().get_center())

# Uretim geri bildirimi: sonuc ikonu karttan hotbara minik yay cizerek
# ucar (0.4sn) + hotbar minik pop yapar (UI_DESIGN 4.3)
func _fly_to_hotbar(recipe_id: String, from_pos: Vector2) -> void:
	var target := hotbar_box.get_global_rect().get_center()
	for slot in _mini_hotbar_slots:
		if slot.item_id == recipe_id:
			target = slot.get_global_rect().get_center()
			break
	var fly := TextureRect.new()
	fly.texture = load(Items.ITEMS[recipe_id]["icon"])
	fly.custom_minimum_size = Vector2(36, 36)
	fly.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fly.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly.position = from_pos - Vector2(18, 18)
	add_child(fly)
	var mid_point := (from_pos + target) / 2.0 + Vector2(0, -90.0)
	var curve := func(t: float):
		var a := from_pos.lerp(mid_point, t)
		var b := mid_point.lerp(target, t)
		fly.position = a.lerp(b, t) - Vector2(18, 18)
	var tween := create_tween()
	tween.tween_method(curve, 0.0, 1.0, 0.4)
	tween.tween_callback(func():
		fly.queue_free()
		_pop_hotbar())

func _pop_hotbar() -> void:
	hotbar_box.pivot_offset = hotbar_box.size / 2.0
	var tween := create_tween()
	tween.tween_property(hotbar_box, "scale", Vector2.ONE * 1.08, 0.08)
	tween.tween_property(hotbar_box, "scale", Vector2.ONE, 0.12)

## Dunyadan toplama geri bildirimi: esya ikonu karakterden envanter
## butonuna minik yay cizerek ucar + "+" rozeti (UI_DESIGN 4.5)
func fly_pickup(item_id: String, from_screen: Vector2) -> void:
	if not Items.ITEMS.has(item_id):
		return
	var fly := Control.new()
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = load(Items.ITEMS[item_id]["icon"])
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly.add_child(icon)
	var plus := Label.new()
	plus.text = "+"
	plus.theme_type_variation = "BadgeLabel"
	plus.position = Vector2(26, -10)
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly.add_child(plus)
	fly.position = from_screen - Vector2(16, 16)
	add_child(fly)
	var target := inventory_button.get_global_rect().get_center()
	var mid_point := (from_screen + target) / 2.0 + Vector2(0, -70.0)
	var curve := func(t: float):
		var a := from_screen.lerp(mid_point, t)
		var b := mid_point.lerp(target, t)
		fly.position = a.lerp(b, t) - Vector2(16, 16)
	var tween := create_tween()
	tween.tween_method(curve, 0.0, 1.0, 0.45)
	tween.tween_callback(func():
		fly.queue_free()
		inventory_button.pivot_offset = inventory_button.size / 2.0
		var pop := create_tween()
		pop.tween_property(inventory_button, "scale", Vector2.ONE * 1.12, 0.08)
		pop.tween_property(inventory_button, "scale", Vector2.ONE, 0.12))

# Yetersiz malzemeyle karta dokununca: yatay minik sallanma + eksik
# malzemeler kisa parlar. Ceza degil, "suna bak" hissi (UI_DESIGN 4.5)
func _shake_card(recipe_id: String) -> void:
	var refs: Dictionary = _recipe_cards.get(recipe_id, {})
	if refs.is_empty():
		return
	var card: Control = refs["card"]
	var base_x: float = card.position.x
	var tween := create_tween()
	for offset in [4.0, -4.0, 4.0, -4.0, 0.0]:
		tween.tween_property(card, "position:x", base_x + offset, 0.05)
	for mat in refs["mats"]:
		if mat["warn"].visible:
			var warn: Label = mat["warn"]
			warn.pivot_offset = warn.size / 2.0
			var flash := create_tween()
			flash.tween_property(warn, "scale", Vector2.ONE * 1.5, 0.12)
			flash.tween_property(warn, "scale", Vector2.ONE, 0.15)

# --- Gece efektleri (UI_DESIGN 4.5) ---------------------------------------

var _vignette: TextureRect
var _night_pill: PanelContainer
var _night_pill_label: Label

func _setup_night_fx() -> void:
	_vignette = TextureRect.new()
	_vignette.texture = _make_vignette_texture()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	add_child(_vignette)
	move_child(_vignette, 1)  # panellerin altinda, dunyanin ustunde
	_night_pill = PanelContainer.new()
	_night_pill.theme = load("res://theme_main.tres")
	_night_pill.theme_type_variation = "TitleTab"
	_night_pill.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_night_pill.offset_top = 20.0
	_night_pill.offset_left = -140.0
	_night_pill.offset_right = 140.0
	_night_pill.visible = false
	add_child(_night_pill)
	_night_pill_label = Label.new()
	_night_pill_label.theme_type_variation = "TitleTabLabel"
	_night_pill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_night_pill.add_child(_night_pill_label)
	DayNight.night_started.connect(_on_night_fx)
	DayNight.day_started.connect(_on_day_fx)

func _on_night_fx() -> void:
	create_tween().tween_property(_vignette, "modulate:a", 0.45, 1.2)
	_night_pill_label.text = "Gece %d — Geliyorlar..." % DayNight.day
	_night_pill.visible = true
	_night_pill.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_night_pill, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.0)
	tween.tween_property(_night_pill, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): _night_pill.visible = false)

func _on_day_fx() -> void:
	create_tween().tween_property(_vignette, "modulate:a", 0.0, 1.2)

# Kenarlardan iceri yumusak lavanta-lacivert vinyet dokusu
func _make_vignette_texture() -> ImageTexture:
	var w := 240
	var h := 135
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var col := Color("#3A2E5C")
	for y in h:
		for x in w:
			var nx := (float(x) / w - 0.5) * 2.0
			var ny := (float(y) / h - 0.5) * 2.0
			var d := sqrt(nx * nx + ny * ny)
			var a: float = clampf((d - 0.62) / 0.55, 0.0, 1.0)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, pow(a, 1.6)))
	return ImageTexture.create_from_image(img)

# Kartlarin yeterlilik/istasyon durumunu tazeler (envanter degisiminde)
func _update_cards() -> void:
	for recipe_id in _recipe_cards:
		var refs: Dictionary = _recipe_cards[recipe_id]
		var recipe: Dictionary = Recipes.CRAFT_RECIPES[recipe_id]
		var can := Crafting.max_craftable(recipe_id) >= 1
		refs["card"].modulate.a = 1.0 if can else 0.6
		refs["button"].disabled = not can
		for mat in refs["mats"]:
			var have := Inventory.get_count(mat["id"])
			var enough: bool = have >= int(mat["need"])
			mat["label"].text = "%d/%d" % [have, mat["need"]]
			mat["label"].add_theme_color_override("font_color",
					UIColors.SUCCESS.darkened(0.25) if enough else UIColors.DANGER)
			mat["warn"].visible = not enough
		if recipe["station"] != "":
			# Istasyon adi + yakinlik: ocak (pisirme) ya da tezgah
			var is_hearth: bool = recipe["station"] == "ocak"
			var near: bool = Crafting.near_hearth if is_hearth else Crafting.near_station
			var st_name: String = "Ocak" if is_hearth else "Tezgah"
			refs["station"].text = "%s yanında ✓" % st_name if near \
					else "%s gerekli — yanında değilsin" % st_name
			refs["station"].add_theme_color_override("font_color",
					UIColors.SUCCESS.darkened(0.25) if near \
					else UIColors.WARNING.darkened(0.3))

# --- Gorsel tema ----------------------------------------------------------

# Go-Go Town tarzi krem/pastel tema: yuvarlak koseli krem kartlar,
# koyu kahve yazi, turuncu vurgu. Tema ust seviye Control'lere atanir;
# sonradan eklenen cocuklar (kartlar, slotlar) otomatik miras alir.
# Eski kod-ici tema kaldirildi: TUM stiller theme_main.tres'ten gelir
# (UI_DESIGN 6). Yalnizca panel disinda dunyanin ustunde duran gun
# etiketi okunabilirlik icin ozel golgeli kalir (_ready'de ayarlanir).

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
	# YASAM (Asama 4): olum kararmasi (her seyin ustunde, kisa siyah gecis)
	_death_fade = ColorRect.new()
	_death_fade.color = Color(0, 0, 0, 0.0)
	_death_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_death_fade)  # en ustte (panelleri de kapatir)
	PlayerStats.player_died.connect(_on_player_died)

var _death_fade: ColorRect

## Olum: kisa kararma (respawn_player kararmanin altinda isinlar).
func _on_player_died(_count: int) -> void:
	if _death_fade == null:
		return
	_death_fade.color.a = 1.0  # aninda siyah: isinlanmayi gizler
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(_death_fade, "color:a", 0.0, 0.7)

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

	# 14.1 hizli butonlar: Tümünü Koy / Tümünü Al
	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 10)
	var put_all := Button.new()
	put_all.text = "Tümünü Koy"
	put_all.add_theme_font_size_override("font_size", 20)
	put_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	put_all.pressed.connect(func(): chest_transfer_all_requested.emit(true))
	quick.add_child(put_all)
	var take_all := Button.new()
	take_all.text = "Tümünü Al"
	take_all.add_theme_font_size_override("font_size", 20)
	take_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	take_all.pressed.connect(func(): chest_transfer_all_requested.emit(false))
	quick.add_child(take_all)
	chest_rows.add_child(quick)

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

## Baglam-duyarli ana buton durumu (12.1). World her karede cagirir;
## icon/solukluk yalnizca degisince yenilenir. icon_name ACTION_ICONS
## anahtari; valid=false ise buton solar (ink_faint); weapon=true ise
## saldiri butonu gorunur.
var _ctx_icon := ""
var _ctx_valid := true
var _ctx_weapon := false

func set_action_context(icon_name: String, valid: bool, weapon: bool) -> void:
	if icon_name != _ctx_icon:
		_ctx_icon = icon_name
		action_button.icon = ACTION_ICONS.get(icon_name, ICON_FIST)
	if valid != _ctx_valid:
		_ctx_valid = valid
		action_button.modulate = Color(1, 1, 1, 1) if valid \
				else Color(1, 1, 1, 0.45)
	if weapon != _ctx_weapon:
		_ctx_weapon = weapon
		_fade_attack_button(weapon)

## Geriye donuk: eski cagri noktasi kalirsa bozulmasin
func set_action_state(state: String) -> void:
	set_action_context(state, true, false)

func _fade_attack_button(show: bool) -> void:
	var tw := create_tween()
	if show:
		attack_button.visible = true
		attack_button.modulate.a = 0.0
		tw.tween_property(attack_button, "modulate:a", 1.0, 0.18)
	else:
		tw.tween_property(attack_button, "modulate:a", 0.0, 0.15)
		tw.tween_callback(func(): attack_button.visible = false)

# --- Saldiri butonu basili-tut algilama (12.5 nisan modu) ---------------
var _attack_hold_timer: SceneTreeTimer
var _attack_is_hold := false

func _on_attack_down() -> void:
	_pop_button(attack_button)
	_attack_is_hold = false
	_attack_hold_timer = get_tree().create_timer(0.25)
	_attack_hold_timer.timeout.connect(func():
		_attack_is_hold = true
		attack_hold_started.emit())

func _on_attack_up() -> void:
	if _attack_is_hold:
		attack_hold_released.emit()
	else:
		attack_pressed.emit()
	_attack_is_hold = false

## Buton basis geri bildirimi (12.6): 0.9 scale pop.
func _pop_button(btn: Control) -> void:
	btn.pivot_offset = btn.size * 0.5
	btn.scale = Vector2(0.9, 0.9)
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE, 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Gecersiz eylem geri bildirimi (12.6): yatay minik sallanma.
func shake_action_button() -> void:
	var base := action_button.position.x
	var tw := create_tween()
	for dx in [-6.0, 6.0, -4.0, 4.0, 0.0]:
		tw.tween_property(action_button, "position:x", base + dx, 0.05)
