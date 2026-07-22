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

## R1: Ayarlar menusu acildi/kapandi — World Kamera/Gorunum panelini gosterir
signal settings_toggled(open: bool)

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
const TimeBalance = preload("res://scripts/time_balance.gd")

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
@onready var cards_box: HFlowContainer = $CraftRoot/CraftPanel/HBox/RightBox/Body/Scroll/Cards
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
	# R6: "Ye" HUD butonu YOK — yeme akisi ana buton / envanter pill'i.
	# R1: "Yeni Oyun" artik HUD'da durmaz -> Ayarlar menusune tasinir
	# (_build_settings_menu). reset_button, Ayarlar toggle'ina donusturulur.

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
	_setup_backdrop()   # R0: panel acikken oyun ekrani karartilir + HUD gizlenir
	_build_slots()
	_build_lock_chip()  # R0: kilitli slotlar tek kompakt cip olur
	_build_info_strip() # R3: envanter ORTAK alt bilgi bandi (yeniden kullanilir)
	_build_dock()           # R1: sag kenar dikey dock (canta/uretim/arastirma)
	_build_settings_menu()  # R1: Ayarlar menusu (Yeni Oyun + Kamera/Gorunum)
	_style_action_buttons() # R2: ana/saldiri butonlari + baglam etiketi
	_build_category_buttons()
	_build_craft_detail()  # R4: uretim alt detay bandi (ORTAK bilesen)
	_rebuild_cards()
	_refresh()
	_update_health()
	_update_day_label()
	_update_hunger()

func _process(_delta: float) -> void:
	_update_day_pulse()
	# gunduz/gece: gece kenar vinyeti gecişi YUMUŞAK (nightness eğrisi; çok hafif
	# lavanta, UI_DESIGN 4.5). Gün/saat pill ilerlemesi de her kare akar.
	if _vignette != null:
		_vignette.modulate.a = _nightness() * 0.34
	_update_day_progress()
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

# R3: envanter ALTTAN yukari kayan panel (bottom-sheet); yatayda ortalanmis
# genis panel (sag serit iptal). Kayma dikey (asagidan yukari).
func _on_inventory_toggled(pressed: bool) -> void:
	if pressed:
		craft_button.button_pressed = false
		research_button.button_pressed = false
		reset_button.button_pressed = false
		close_chest()
		chest_closed.emit()
		_refresh()
	else:
		_inv_first = false  # ilk acilis bitti -> ogretici metin bir daha yok
	if _inv_tween != null:
		_inv_tween.kill()
	_inv_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var rise := get_viewport().get_visible_rect().size.y  # ekran disina in/cik
	if pressed:
		inventory_root.visible = true
		inventory_root.position.y += rise  # ekranin altindan basla
		_inv_tween.tween_property(inventory_root, "position:y",
				inventory_root.position.y - rise, 0.25)
	else:
		_picked_slot = null
		_inv_tween.tween_property(inventory_root, "position:y",
				inventory_root.position.y + rise, 0.22)
		_inv_tween.tween_callback(func():
			inventory_root.visible = false
			inventory_root.position.y -= rise)
	_update_backdrop()

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
	_update_backdrop()

func _on_research_toggled(pressed: bool) -> void:
	if pressed:
		inventory_button.button_pressed = false
		craft_button.button_pressed = false
		close_chest()
		chest_closed.emit()
		research_root.open()
	else:
		research_root.close()
	_update_backdrop()

# --- R0: Panel overlay_dim + HUD gizleme --------------------------------
# Panel acikken oyun ekrani karartilir (odak) ve HUD oyun ogeleri gizlenir
# (Gun pill'inin panel basligiyla cakismasi da boyle cozulur). overlay,
# aktif panelin ALTINA, diger her seyin USTUNE alinir.
var _overlay: ColorRect

func _setup_backdrop() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "PanelOverlay"
	_overlay.color = UIColors.OVERLAY_DIM
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # arka plana dokunmayi engelle
	_overlay.visible = false
	add_child(_overlay)

# Panel acik mi? (toggle butonlari + sandik durumu)
func _any_panel_open() -> bool:
	return inventory_button.button_pressed or craft_button.button_pressed \
			or research_button.button_pressed or chest_panel.visible \
			or (_settings_panel != null and _settings_panel.visible)

func _update_backdrop() -> void:
	if _overlay == null:
		return
	var open := _any_panel_open()
	_overlay.visible = open
	if open:
		move_child(_overlay, get_child_count() - 1)
		# Yalnizca GERCEKTEN acik olan tek paneli overlay'in ustune al.
		var top: Control = null
		if chest_panel.visible:
			top = chest_panel
		elif inventory_button.button_pressed:
			top = inventory_root
		elif craft_button.button_pressed:
			top = craft_root
		elif research_button.button_pressed:
			top = research_root
		if top != null:
			move_child(top, get_child_count() - 1)
	# Oyun HUD ogeleri panel acikken gizlenir, kapaninca geri gelir.
	for node in _hud_game_nodes():
		if node != null:
			node.visible = not open
	if not open:
		attack_button.visible = _ctx_weapon  # kosullu geri gelir

# Panel acikken gizlenecek "oyun eylemi" HUD ogeleri (attack ayri yonetilir).
func _hud_game_nodes() -> Array:
	return [get_node_or_null("Dock"), reset_button,
			hotbar_strip, action_button, move_button, day_pill,
			get_node_or_null("StatsPanel")]

# --- R0: Kilit cipi (izgara sonunda tek kompakt cip) --------------------
var _lock_chip: PanelContainer
var _lock_chip_label: Label

func _build_lock_chip() -> void:
	var vbox := inventory_grid.get_parent()
	_lock_chip = PanelContainer.new()
	_lock_chip.theme_type_variation = "InnerPanel"
	_lock_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_lock_chip.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_lock_chip.add_child(row)
	var lock_icon := TextureRect.new()
	lock_icon.texture = load("res://assets/ui/lock.png")
	lock_icon.custom_minimum_size = Vector2(18, 18)
	lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock_icon.modulate = Color(1, 1, 1, 0.7)
	row.add_child(lock_icon)
	_lock_chip_label = Label.new()
	_lock_chip_label.theme_type_variation = "SubtleLabel"
	row.add_child(_lock_chip_label)
	vbox.add_child(_lock_chip)
	vbox.move_child(_lock_chip, inventory_grid.get_index() + 1)

# --- R3: Envanter ORTAK alt bilgi bandi (yeniden kullanilabilir bilesen) -
const UiInfoStrip = preload("res://scripts/ui_info_strip.gd")
var _info: UiInfoStrip       # ORTAK alt bilgi bandi bileseni
var _inv_first := true       # "Bir esyaya dokun..." yalniz ilk acilista

func _build_info_strip() -> void:
	var old_info: Control = $InventoryRoot/InventoryPanel/VBox/InfoStrip
	old_info.visible = false  # eski dikey bilgi kutusu -> yeni bant ile degisir
	var inv_vbox := old_info.get_parent()
	var at := old_info.get_index()
	# Izgara ile band arasi bosluk -> band panelin ALTINA yaslanir
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inv_vbox.add_child(spacer)
	inv_vbox.move_child(spacer, at)
	_info = UiInfoStrip.new()
	inv_vbox.add_child(_info)
	inv_vbox.move_child(_info, at + 1)

# --- R1: Sag kenar dikey DOCK (canta / uretim / arastirma) --------------
# Dagitik beyaz daireler yerine TEK dikey dock: kategori renkli DOLGULU
# 68px daire + %65 dolduran koyu kahve ikon + altinda 12px mini etiket.

func _build_dock() -> void:
	var theme := load("res://theme_main.tres")
	# Arastirma butonuna ikon ver (arastirma masasi item ikonu — anlamli)
	research_button.icon = load("res://assets/items/arastirma_masasi.png")
	research_button.text = ""
	var dock := VBoxContainer.new()
	dock.name = "Dock"
	dock.theme = theme
	dock.anchor_left = 1.0
	dock.anchor_right = 1.0
	dock.anchor_top = 0.44   # dikey ortanin biraz altindan basla (basparmak)
	dock.anchor_bottom = 0.44
	dock.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	dock.grow_vertical = Control.GROW_DIRECTION_END
	dock.offset_left = -84
	dock.offset_right = -16
	dock.add_theme_constant_override("separation", 12)
	add_child(dock)
	var entries := [
		[inventory_button, "Çanta", UIColors.category_color("tool")],
		[craft_button, "Üretim", UIColors.category_color("station")],
		[research_button, "Araştırma", UIColors.RESEARCH],
	]
	for e in entries:
		var btn: Button = e[0]
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 3)
		entry.alignment = BoxContainer.ALIGNMENT_CENTER
		var p := btn.get_parent()
		if p != null:
			p.remove_child(btn)
		_style_dock_button(btn, e[2])
		entry.add_child(btn)
		var lbl := Label.new()
		lbl.text = e[1]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", UIColors.INK_DARK)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		entry.add_child(lbl)
		dock.add_child(entry)

# 68px kategori renkli dolgulu daire + %68 dolduran koyu kahve ikon.
func _style_dock_button(btn: Button, color: Color) -> void:
	btn.custom_minimum_size = Vector2(68, 68)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	btn.text = ""
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(999)
	sb.content_margin_left = 11  # 68-2*11=46 -> ikon %68 (>=%65 kurali)
	sb.content_margin_right = 11
	sb.content_margin_top = 11
	sb.content_margin_bottom = 11
	for st in ["normal", "hover", "pressed", "disabled"]:
		btn.add_theme_stylebox_override(st, sb)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
			"icon_disabled_color"]:
		btn.add_theme_color_override(c, UIColors.INK_DARK)

# --- R1: Ayarlar (Duraklat) menusu --------------------------------------
# "Yeni Oyun" (yanlislikla basilirsa oyun silinir!) ve Kamera/Gorunum debug
# butonlari HUD'dan cikar; buraya toplanir. reset_button -> "Ayarlar" toggle.
var _settings_panel: PanelContainer
var _newgame_button: Button
var _reset_confirm := false

func _build_settings_menu() -> void:
	reset_button.text = "Ayarlar"
	reset_button.toggle_mode = true
	reset_button.add_theme_font_size_override("font_size", 16)
	reset_button.toggled.connect(_on_settings_toggled)
	_settings_panel = PanelContainer.new()
	_settings_panel.theme = load("res://theme_main.tres")
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.custom_minimum_size = Vector2(360, 0)
	_settings_panel.visible = false
	add_child(_settings_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	_settings_panel.add_child(vb)
	var header := Label.new()
	header.text = "Ayarlar"
	header.theme_type_variation = "HeaderLabel"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(header)
	var hint := Label.new()
	hint.theme_type_variation = "SubtleLabel"
	hint.text = "Kamera ve Görünüm ayarları sol kenarda görünür."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
	_newgame_button = Button.new()
	_newgame_button.theme_type_variation = "PrimaryButton"
	_newgame_button.text = "Yeni Oyun (kaydı siler)"
	_newgame_button.pressed.connect(_on_newgame_pressed)
	vb.add_child(_newgame_button)
	var close := Button.new()
	close.text = "Kapat"
	close.pressed.connect(func(): reset_button.button_pressed = false)
	vb.add_child(close)

func _on_settings_toggled(pressed: bool) -> void:
	if pressed:
		inventory_button.button_pressed = false
		craft_button.button_pressed = false
		research_button.button_pressed = false
		close_chest()
		chest_closed.emit()
	_settings_panel.visible = pressed
	_reset_confirm = false
	if _newgame_button != null:
		_newgame_button.text = "Yeni Oyun (kaydı siler)"
	settings_toggled.emit(pressed)  # World Kamera/Gorunum panelini ac/kapa
	_update_backdrop()

# Yanlislikla silmeyi onlemek icin iki adimli onay.
func _on_newgame_pressed() -> void:
	if not _reset_confirm:
		_reset_confirm = true
		_newgame_button.text = "Emin misin? (tekrar bas)"
		return
	_on_reset_pressed()

# --- R2: Ana eylem + saldiri butonlari ----------------------------------
# Baglam ikon -> butonun ICINDE alt mini etiket (Kes/Kaz/Topla/Aç/Ye...).
const CTX_LABELS := {
	"chop": "Kes", "mine": "Kaz", "dig": "Kaz", "pile": "Yığ",
	"fill": "Doldur", "pour": "Dök", "harvest": "Topla", "grab": "Al",
	"repair": "Onar", "open": "Aç", "attack": "Vur", "spear": "Sapla",
	"fist": "",
}
var _action_label: Label

func _style_action_buttons() -> void:
	# ANA BUTON (96px): dolgulu ink_dark daire + BUYUK baglam ikonu (krem) +
	# icte alt mini etiket. "+"/nisan placeholder'i KALDIRILDI.
	action_button.offset_left = -120
	action_button.offset_right = -24
	action_button.offset_top = -192
	action_button.offset_bottom = -96
	_fill_circle_button(action_button, UIColors.INK_DARK, UIColors.PANEL_CREAM, 14)
	action_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	_action_label = Label.new()
	_action_label.add_theme_color_override("font_color", UIColors.PANEL_CREAM)
	_action_label.add_theme_font_size_override("font_size", 16)
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_action_label.offset_top = -28
	_action_label.offset_bottom = -6
	_action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_button.add_child(_action_label)
	# SALDIRI (72px): danger pastel dolgu + kilic (koyu) + "Saldır"
	attack_button.offset_left = -108
	attack_button.offset_right = -36
	attack_button.offset_top = -280
	attack_button.offset_bottom = -208
	_fill_circle_button(attack_button, UIColors.DANGER, UIColors.INK_DARK, 12)
	attack_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	var atk_label := Label.new()
	atk_label.text = "Saldır"
	atk_label.add_theme_color_override("font_color", UIColors.INK_DARK)
	atk_label.add_theme_font_size_override("font_size", 14)
	atk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	atk_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	atk_label.offset_top = -24
	atk_label.offset_bottom = -5
	atk_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attack_button.add_child(atk_label)
	# TASI (yapi geri-alma modu): sag-alt kumeden CIKAR -> sol-alt kompakt
	# pill (islev korunur; sag altta yalniz ana+saldiri kalir).
	move_button.anchor_left = 0.0
	move_button.anchor_right = 0.0
	move_button.anchor_top = 1.0
	move_button.anchor_bottom = 1.0
	move_button.offset_left = 16
	move_button.offset_right = 120
	move_button.offset_top = -232
	move_button.offset_bottom = -188
	move_button.text = "Taşı"
	move_button.add_theme_font_size_override("font_size", 16)

# Dolgulu daire buton (ana/saldiri): tek stylebox tum durumlar + ikon rengi.
func _fill_circle_button(btn: Button, bg: Color, icon_col: Color, margin: float) -> void:
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(999)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	for st in ["normal", "hover", "pressed", "disabled"]:
		btn.add_theme_stylebox_override(st, sb)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
			"icon_disabled_color"]:
		btn.add_theme_color_override(c, icon_col)

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
		# R0: kilitli slotlar tek tek CIZILMEZ; izgaradan gizlenir, kilit
		# bilgisi izgara sonundaki tek cipte yasar.
		slot.visible = i < capacity
		slot.set_locked(false)
		var content = Inventory.slots[i]
		if content == null:
			slot.set_content("", 0)
		else:
			slot.set_content(content["id"], content["count"])
	# Kilit cipi: "+N slot (deri canta ile)" — yalnizca kilitli varsa.
	if _lock_chip != null:
		var locked_count: int = _inv_slots.size() - capacity
		_lock_chip.visible = locked_count > 0
		if locked_count > 0:
			_lock_chip_label.text = "+%d slot (deri çanta ile)" % locked_count
	capacity_label.text = "%d/%d" % [Inventory.get_used_slots(), capacity]
	_refresh_hotbar(_mini_hotbar_slots)
	_update_detail()
	_update_cards()
	_update_hunger()

func _refresh_hotbar(slot_list: Array) -> void:
	# R7: hotbar HEP 5 kullanilabilir slot; kilit ikonu yok (kilit yalniz
	# envanterde, R0 cipinde yasar).
	for i in slot_list.size():
		var slot: UiSlotScript = slot_list[i]
		slot.set_locked(false)
		var id: String = Inventory.hotbar[i] if i < Inventory.hotbar.size() else ""
		slot.set_content(id, Inventory.get_count(id) if id != "" else 0)
		var is_sel: bool = id != "" and id == _held_item
		slot.selected = is_sel
		# Secili slot 1.15x + alt nokta (ui_slot ciziyor)
		slot.pivot_offset = slot.size / 2.0
		slot.scale = Vector2.ONE * (1.15 if is_sel else 1.0)

# R3: secili esyayi ORTAK bilgi bandinda goster (ikon+ad+tek satir+pill'ler).
func _update_detail() -> void:
	if _info == null:
		return
	if _selected_item == "" or Inventory.get_count(_selected_item) <= 0:
		# Ogretici metin yalniz ilk acilista (sonra kisa yonlendirme).
		_info.set_placeholder("Bir eşyaya dokun: bilgisi burada görünür." \
				if _inv_first else "Bir eşya seç.")
		return
	var icon_tex: Texture2D = null
	var ipath := String(Items.ITEMS.get(_selected_item, {}).get("icon", ""))
	if ipath != "" and ResourceLoader.exists(ipath):
		icon_tex = load(ipath)
	var title := "%s ×%d" % [Items.display_name(_selected_item),
			Inventory.get_count(_selected_item)]
	_info.show_item(icon_tex, title, Items.description(_selected_item),
			UIColors.item_color(_selected_item))
	# Eylem pill'leri: Ye (yenebilir) / Kuşan-Bırak / Yerleştir / At
	var pills: Array = []
	if PlayerStats.is_edible(_selected_item):
		pills.append({"text": "Ye", "primary": true, "on": _on_eat_pressed})
	pills.append({"text": "Bırak" if _held_item == _selected_item else "Kuşan",
			"primary": true, "on": _on_hold_pressed})
	if Items.PLACEABLE.has(_selected_item):
		pills.append({"text": "Yerleştir", "primary": true, "on": _on_place_pill})
	pills.append({"text": "At", "on": _on_drop_pressed})
	_info.set_pills(pills)

func _on_place_pill() -> void:
	if _selected_item != "":
		inventory_button.button_pressed = false  # paneli kapat
		place_requested.emit(_selected_item)

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
# R6: sol alt CIPLAK barlar (kutu YOK). StatsPanel zemini saydam yapilir;
# 3 kompakt bar (140x14) + solda 20px ikon + ince koyu kontur. "Ye" HUD
# butonu TAMAMEN KALDIRILDI (yeme akisi ana buton / envanter pill'i).
func _build_stats() -> void:
	# Panel zeminini kaldir: dunya arkada gorunur (hafif golgeyle okunur).
	var stats_panel := get_node_or_null("StatsPanel")
	if stats_panel != null:
		(stats_panel as Control).add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_heart_bar = _make_stat_bar("kalp", UIColors.DANGER)
	_stomach_bar = _make_stat_bar("mide", UIColors.category_color("tool"))
	_drop_bar = _make_stat_bar("damla", Color("#9FC5E8"))
	_update_thirst()

# Tek CIPLAK durum bari: 20px ikon + 140x14 pastel dolgulu bar (ince kontur).
func _make_stat_bar(icon_name: String, fill_color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/ui/%s_dolu.png" % icon_name)
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(140, 14)
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

# R6: bar degisiminde (hasar/yeme) 0.3 sn nabiz — kutu olmadan da dikkat ceker.
func _pulse_stat_bar(bar: ProgressBar) -> void:
	if bar == null:
		return
	bar.pivot_offset = bar.size / 2.0
	var tw := create_tween()
	tw.tween_property(bar, "scale", Vector2.ONE * 1.12, 0.15)
	tw.tween_property(bar, "scale", Vector2.ONE, 0.15)

func _update_hunger() -> void:
	if _stomach_bar == null:
		return
	# R6: aclik ARTISINDA (yeme) bar nabiz atar (kutu yok, dikkat cekmek icin).
	if Hunger.value > _prev_hunger + 0.5:
		_pulse_stat_bar(_stomach_bar)
	_prev_hunger = Hunger.value
	_stomach_bar.value = Hunger.value

var _prev_hunger: float = 100.0

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
		if Health.value < _prev_hp:
			_pulse_stat_bar(_heart_bar)  # R6: hasarda can bari nabiz atar
	if _damage_flash != null and Health.value < _prev_hp:
		_damage_flash.color.a = 0.3
		create_tween().tween_property(_damage_flash, "color:a", 0.0, 0.4)
	# YASAM cila: dusuk canda ÇOK hafif kirmizi vinyet (mobilde rahatsiz etmez).
	# <30 canda basar, 0'da en fazla ~0.12 alfa.
	if _low_hp_vignette != null:
		var lo: float = clampf((30.0 - Health.value) / 30.0, 0.0, 1.0)
		_low_hp_vignette.color.a = lo * 0.12
	_prev_hp = Health.value

func _update_day_label() -> void:
	day_label.text = "Gün %d" % DayNight.day
	var dot := StyleBoxFlat.new()
	dot.set_corner_radius_all(999)
	# Gunes = sicak sari; ay = lavanta (UI_DESIGN 4.1)
	dot.bg_color = Color("#B9A0E8") if DayNight.is_night else UIColors.WARNING
	day_dot.add_theme_stylebox_override("panel", dot)

# Geceye son 1 dk: pill warning rengi + yumuşak nabız + tek satır uyarı
var _day_pulse: Tween
var _pulsing := false
var _day_progress: ProgressBar

func _update_day_pulse() -> void:
	var tun := DayNight.time_until_night()
	var closing: bool = tun > 0.0 and tun <= TimeBalance.NIGHT_WARN_LEAD
	if closing == _pulsing:
		return
	_pulsing = closing
	day_pill.pivot_offset = day_pill.size / 2.0
	if closing:
		_day_pulse = create_tween().set_loops()
		_day_pulse.tween_property(day_pill, "scale", Vector2.ONE * 1.04, 0.5)
		_day_pulse.tween_property(day_pill, "scale", Vector2.ONE, 0.5)
		day_pill.modulate = Color(1.0, 0.86, 0.55)
		_flash_night_pill("Gece yaklaşıyor")  # tek satır uyarı (2 sn)
	else:
		if _day_pulse != null:
			_day_pulse.kill()
		day_pill.scale = Vector2.ONE
		day_pill.modulate = Color.WHITE

## Gün içi ilerleme (pill'de minik dolum bar; her kare akar).
func _update_day_progress() -> void:
	if _day_progress == null:
		if day_label == null or day_label.get_parent() == null:
			return
		_day_progress = ProgressBar.new()
		_day_progress.max_value = 1.0
		_day_progress.show_percentage = false
		_day_progress.custom_minimum_size = Vector2(42, 6)
		_day_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		day_label.get_parent().add_child(_day_progress)
	_day_progress.value = DayNight.day_fraction()

## "Gece"lik oranı (0 gündüz .. 1 zifiri gece); vinyet + geçiş yumuşaklığı.
func _nightness() -> float:
	match DayNight.phase:
		"night": return 1.0
		"dusk": return DayNight.phase_progress()
		"dawn": return 1.0 - DayNight.phase_progress()
		_: return 0.0

## Ortadaki pill'de kısa (2 sn) tek satır bilgi.
func _flash_night_pill(text: String) -> void:
	if _night_pill == null:
		return
	_night_pill_label.text = text
	_night_pill.visible = true
	_night_pill.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_night_pill, "modulate:a", 1.0, 0.3)
	tw.tween_interval(TimeBalance.NIGHT_PILL_SECONDS)
	tw.tween_property(_night_pill, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): _night_pill.visible = false)

# --- Uretim paneli ------------------------------------------------------

# R4: sol dikey 56px kategori sekmeleri — kategori RENKLI dolgulu daire +
# ikon (etiket KIRPILMAZ; isim tooltip + detay bandinda). "Tümü" ayri durur.
func _build_category_buttons() -> void:
	var group := ButtonGroup.new()
	var cats := {"tumu": "Tümü"}
	cats.merge(Recipes.CATEGORIES)
	for cat_id in cats:
		var color: Color = UIColors.category_color("resource")
		if CAT_COLOR_KEY.has(cat_id):
			color = UIColors.category_color(CAT_COLOR_KEY[cat_id])
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.tooltip_text = String(cats[cat_id])
		button.icon = _category_icon(cat_id)
		_style_cat_button(button, color)
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

# 56px kategori sekmesi: renkli dolgulu daire + %65+ dolduran koyu kahve ikon.
func _style_cat_button(button: Button, color: Color) -> void:
	button.custom_minimum_size = Vector2(56, 56)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.text = ""
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(999)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, sb)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for cn in ["icon_normal_color", "icon_hover_color", "icon_pressed_color",
			"icon_disabled_color"]:
		button.add_theme_color_override(cn, UIColors.INK_DARK)

# Kategoriyi temsil eden ikon: o kategorideki ilk tarifin cikti ikonu.
func _category_icon(cat_id: String) -> Texture2D:
	if cat_id != "tumu":
		for rid in Recipes.CRAFT_RECIPES:
			if Recipes.CRAFT_RECIPES[rid]["category"] == cat_id:
				var p := String(Items.ITEMS.get(rid, {}).get("icon", ""))
				if p != "" and ResourceLoader.exists(p):
					return load(p)
	return load("res://assets/ui/wrench.png")

# Aktif sekme tam opak + hafif buyuk; pasifler %65 opak (UI_DESIGN 4.3)
func _apply_cat_state(button: Button, active: bool) -> void:
	button.modulate.a = 1.0 if active else 0.65
	button.pivot_offset = button.custom_minimum_size / 2.0
	button.scale = Vector2.ONE * (1.08 if active else 1.0)

# R4: kart izgarasi (88px kare kart: ikon %65 + altinda ad). Kart faded
# durumu + eksik-malzeme rozeti _update_cards'ta tazelenir.
func _rebuild_cards() -> void:
	for child in cards_box.get_children():
		child.queue_free()
	_recipe_cards.clear()
	var query := search_edit.text.strip_edges().to_lower()
	var still := false
	for recipe_id in Recipes.CRAFT_RECIPES:
		var recipe: Dictionary = Recipes.CRAFT_RECIPES[recipe_id]
		if _current_cat != "tumu" and recipe["category"] != _current_cat:
			continue
		if query != "" and not Items.display_name(recipe_id).to_lower().contains(query):
			continue
		cards_box.add_child(_make_recipe_card(recipe_id, recipe))
		if recipe_id == _sel_recipe:
			still = true
	if not still:
		_sel_recipe = ""
	_update_cards()

# 88px kare tarif karti: kategori dairesi + %65 ikon + altinda ad + eksik rozeti.
func _make_recipe_card(recipe_id: String, recipe: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	card.custom_minimum_size = Vector2(88, 88)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 3)
	card.add_child(v)

	var circle := Panel.new()
	circle.custom_minimum_size = Vector2(50, 50)
	circle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIColors.category_color(
			CAT_COLOR_KEY.get(recipe["category"], "resource"))
	sb.set_corner_radius_all(999)
	circle.add_theme_stylebox_override("panel", sb)
	var icon := TextureRect.new()
	icon.texture = load(Items.ITEMS[recipe_id]["icon"])
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 8
	icon.offset_top = 8
	icon.offset_right = -8
	icon.offset_bottom = -8
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.add_child(icon)
	v.add_child(circle)

	var name_label := Label.new()
	name_label.text = Items.display_name(recipe_id)
	name_label.theme_type_variation = "SubtleLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.custom_minimum_size = Vector2(84, 0)
	v.add_child(name_label)

	# Eksik malzeme sayisi rozeti (sag ust; danger)
	var badge := PanelContainer.new()
	var bstyle := StyleBoxFlat.new()
	bstyle.bg_color = UIColors.DANGER
	bstyle.set_corner_radius_all(999)
	bstyle.content_margin_left = 8
	bstyle.content_margin_right = 8
	bstyle.content_margin_top = 0
	bstyle.content_margin_bottom = 1
	badge.add_theme_stylebox_override("panel", bstyle)
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.visible = false
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_label := Label.new()
	badge_label.add_theme_font_size_override("font_size", 14)
	badge_label.add_theme_color_override("font_color", UIColors.PANEL_CREAM)
	badge.add_child(badge_label)
	card.add_child(badge)

	card.gui_input.connect(func(event: InputEvent):
		if (event is InputEventMouseButton and event.pressed) \
				or (event is InputEventScreenTouch and event.pressed):
			_select_recipe(recipe_id))
	_recipe_cards[recipe_id] = {"card": card, "badge": badge, "badge_label": badge_label}
	return card

func _select_recipe(recipe_id: String) -> void:
	_sel_recipe = recipe_id
	_update_craft_detail()

# R4: alt detay bandi (ORTAK bilesen) — buyuk ikon + ad + malzeme cipleri
# (3/5 yesil-kirmizi) + istasyon durumu + TEK "Üret".
var _sel_recipe := ""
var _craft_info: UiInfoStrip

func _build_craft_detail() -> void:
	_craft_info = UiInfoStrip.new()
	var rightbox: VBoxContainer = $CraftRoot/CraftPanel/HBox/RightBox
	rightbox.add_child(_craft_info)
	rightbox.move_child(_craft_info, queue_row.get_index())  # kuyrugun ustune
	_update_craft_detail()

func _update_craft_detail() -> void:
	if _craft_info == null:
		return
	if _sel_recipe == "" or not Recipes.CRAFT_RECIPES.has(_sel_recipe):
		_craft_info.set_placeholder("Bir tarif seç: malzemeler ve Üret burada.")
		return
	var recipe: Dictionary = Recipes.CRAFT_RECIPES[_sel_recipe]
	var out_count: int = recipe["output"][_sel_recipe]
	var title := Items.display_name(_sel_recipe) + \
			(" ×%d" % out_count if out_count > 1 else "")
	_craft_info.show_item(load(Items.ITEMS[_sel_recipe]["icon"]), title, "",
			UIColors.category_color(CAT_COLOR_KEY.get(recipe["category"], "resource")))
	var chips: Array = []
	for item_id in recipe["cost"]:
		var have := Inventory.get_count(item_id)
		var need: int = recipe["cost"][item_id]
		var col: Color = UIColors.SUCCESS.darkened(0.25) if have >= need else UIColors.DANGER
		chips.append({"text": "%d/%d" % [have, need], "color": col,
				"icon": load(Items.ITEMS[item_id]["icon"])})
	if recipe["station"] != "":
		var is_hearth: bool = recipe["station"] == "ocak"
		var near: bool = Crafting.near_hearth if is_hearth else Crafting.near_station
		var st_name: String = "Ocak" if is_hearth else "Tezgah"
		var st_text: String = "%s yanında ✓" % st_name if near \
				else "%s gerekli — yanında değilsin" % st_name
		chips.append({"text": st_text, "color": UIColors.SUCCESS.darkened(0.25) if near \
				else UIColors.WARNING.darkened(0.3)})
	_craft_info.set_chips(chips)
	_craft_info.set_pills([{"text": "Üret", "primary": true, "on": _on_detail_craft}])

func _on_detail_craft() -> void:
	if _sel_recipe == "":
		return
	if Crafting.max_craftable(_sel_recipe) < 1:
		return  # yetersiz — cipler zaten kirmizi
	if Crafting.enqueue(_sel_recipe, 1):
		_fly_to_hotbar(_sel_recipe, _craft_info.get_global_rect().get_center())

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
	DayNight.dawn_started.connect(_on_day_fx)  # yeni gün (sabah) — "Gün N"

## Gece başında "Gece N" pill'i (2 sn). ("— Geliyorlar" YARATIKLAR gelince
## eklenecek; şimdilik sadece "Gece N". Vinyet artık _process'te yumuşak.)
func _on_night_fx() -> void:
	_flash_night_pill("Gece %d" % DayNight.day)

## Sabah: "Gün N" belirir + sabah bonusu kancası (B kısmı Ocak'a bağlayacak).
func _on_day_fx() -> void:
	_flash_night_pill("Gün %d" % DayNight.day)
	_morning_reward()

## [PLANLI] Sabah ödülü kancası — BOŞ. Yaratık/B kısmı hasarsız gece → Ocak
## bonusu olarak dolduracak (BASE_SAVUNMA 14.9). Şimdilik hiçbir şey yapmaz.
func _morning_reward() -> void:
	pass

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

# R4: kartlarin faded durumu + eksik malzeme rozeti; detay bandi da tazelenir.
func _update_cards() -> void:
	for recipe_id in _recipe_cards:
		var refs: Dictionary = _recipe_cards[recipe_id]
		var recipe: Dictionary = Recipes.CRAFT_RECIPES[recipe_id]
		var can := Crafting.max_craftable(recipe_id) >= 1
		# Craftlanamayan kart %55 soluk (hedef gostermek motivasyondur)
		refs["card"].modulate.a = 1.0 if can else 0.55
		var missing := 0
		for item_id in recipe["cost"]:
			if Inventory.get_count(item_id) < int(recipe["cost"][item_id]):
				missing += 1
		refs["badge"].visible = missing > 0
		if missing > 0:
			refs["badge_label"].text = str(missing)
	if craft_root.visible and _sel_recipe != "":
		_update_craft_detail()

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
	# kayit-sistemi: kayit aninda kosede minik "kaydedildi" isareti
	_save_label = Label.new()
	_save_label.text = "✓ Kaydedildi"
	_save_label.add_theme_font_size_override("font_size", 20)
	_save_label.modulate = Color(1, 1, 1, 0.0)
	_save_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_save_label.position = Vector2(-190, 96)
	_save_label.add_theme_color_override("font_color", Color(0.5, 0.75, 0.5))
	add_child(_save_label)
	SaveManager.saved.connect(_on_saved)

var _save_label: Label

## Kayit aninda 0.5 sn görünüp sönen "kaydedildi" işareti (UI_DESIGN 4.5).
func _on_saved() -> void:
	if _save_label == null:
		return
	_save_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(_save_label, "modulate:a", 0.0, 0.4)
	# YASAM: dusuk-can vinyeti (cok hafif kirmizi, kenar hissi icin dunyanin
	# ustunde ama panellerin altinda)
	_low_hp_vignette = ColorRect.new()
	_low_hp_vignette.color = Color(0.6, 0.05, 0.05, 0.0)
	_low_hp_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_low_hp_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_low_hp_vignette)
	move_child(_low_hp_vignette, 1)  # damage_flash'in hemen ustu, panel alti

var _death_fade: ColorRect
var _low_hp_vignette: ColorRect

## gunduz/gece Asama 4: Uyku kararması. Siyaha yumuşak geçer, TEPEDE on_peak
## (sabah uygulanır — kararma altında), sonra açılır.
func play_sleep_fade(on_peak: Callable) -> void:
	if _death_fade == null:
		on_peak.call()
		return
	_death_fade.color.a = 0.0
	var tw := create_tween()
	tw.tween_property(_death_fade, "color:a", 1.0, 0.5)
	tw.tween_callback(on_peak)
	tw.tween_interval(0.35)
	tw.tween_property(_death_fade, "color:a", 0.0, 0.6)

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
	_update_backdrop()

func close_chest() -> void:
	chest_panel.visible = false
	_update_backdrop()

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
		# R2: butonun ICINDE alt mini etiket (Kes/Kaz/Topla/Aç...)
		if _action_label != null:
			_action_label.text = CTX_LABELS.get(icon_name, "")
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
