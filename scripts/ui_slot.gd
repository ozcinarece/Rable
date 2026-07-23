extends Button
## Yuvarlak envanter/hizli erisim slotu (UI_DESIGN.md Bolum 2 + 4.2).
##
## - Arkaplan: kategori renginde pastel DAIRE (bos slot: soluk krem daire)
## - Ikon dairenin ustunde; ikon dosyasi yoksa placeholder = daire +
##   esya adinin ilk 2 harfi (asla gri kare yok)
## - Stack rozeti: sag altta minik krem pill icinde bold sayi
## - Surukleme YOK: dokun-sec-dokun-yerlestir (HUD yonetir).
##   "picked" = tasima icin secilmis (koyu kahve halka ile vurgulanir)
##
## kind: "inv" (envanter slotu) | "hotbar" (hizli erisim atamasi)

const LOCK_TEX := preload("res://assets/ui/lock.png")
const Items = preload("res://scripts/items.gd")
const UIColors = preload("res://scripts/ui_colors.gd")

# R0: 64px slotta ikon kenar payi (kucuk = daha dolu ikon, >=%65 kural).
const ICON_INSET := 10.0

var kind: String = "inv"
var index: int = 0
var item_id: String = ""
var item_count: int = 0
var locked: bool = false
var selected: bool = false:  # eldeki esya (hotbar vurgusu)
	set(value):
		selected = value
		queue_redraw()
var picked: bool = false:    # tasima icin secildi (dokun-tasi modeli)
	set(value):
		picked = value
		queue_redraw()

var _icon_rect: TextureRect
var _letters: Label       # ikon dosyasi olmayan esyalar icin 2 harf
var _badge: PanelContainer
var _badge_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)  # mobil dokunma hedefi
	flat = true  # buton zemini yok; gorunum tamamen _draw'daki daire
	add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	# R0 IKON DOLULUK: ikon kabin (slot) en az %65'ini doldurur.
	# 64px slotta ~10px kenar payi -> ikon ~44px (%69). "Koca daire
	# icinde minik ikon" YASAK.
	_icon_rect = TextureRect.new()
	_icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon_rect.offset_left = ICON_INSET
	_icon_rect.offset_top = ICON_INSET
	_icon_rect.offset_right = -ICON_INSET
	_icon_rect.offset_bottom = -ICON_INSET
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_rect)

	_letters = Label.new()
	_letters.set_anchors_preset(Control.PRESET_FULL_RECT)
	_letters.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letters.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_letters.add_theme_font_size_override("font_size", 20)
	_letters.add_theme_color_override("font_color", UIColors.INK_DARK)
	_letters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_letters)

	# Stack rozeti: minik krem pill + bold sayi
	_badge = PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = UIColors.PANEL_CREAM
	badge_style.set_corner_radius_all(999)
	badge_style.content_margin_left = 7
	badge_style.content_margin_right = 7
	badge_style.content_margin_top = 0
	badge_style.content_margin_bottom = 1
	_badge.add_theme_stylebox_override("panel", badge_style)
	_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_badge.offset_right = -1.0
	_badge.offset_bottom = -1.0
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badge)
	_badge_label = Label.new()
	_badge_label.add_theme_font_size_override("font_size", 16)
	_badge_label.add_theme_color_override("font_color", UIColors.INK_DARK)
	_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.add_child(_badge_label)
	# ENVANTER-MOCKUP: dokunus geri bildirimi — basista %92'ye kuculur
	button_down.connect(_on_press_down)
	button_up.connect(_on_press_up)
	_apply_content()

func _on_press_down() -> void:
	pivot_offset = size / 2.0
	scale = Vector2.ONE * 0.92

func _on_press_up() -> void:
	# Hotbar'da secili slot 1.15x buyuk yasar (R7); ona geri don
	var base := 1.15 if (kind == "hotbar" and selected) else 1.0
	scale = Vector2.ONE * base

## Slot icerigini gunceller (bos icin id="").
func set_content(id: String, count: int) -> void:
	item_id = id
	item_count = count
	_apply_content()

func set_locked(value: bool) -> void:
	locked = value
	disabled = value
	_apply_content()

func _apply_content() -> void:
	if _icon_rect == null:
		return
	_letters.text = ""
	_badge.visible = false
	if locked:
		_icon_rect.texture = LOCK_TEX
		_icon_rect.modulate = Color(1, 1, 1, 0.45)
		queue_redraw()
		return
	_icon_rect.modulate = Color.WHITE
	if item_id == "":
		_icon_rect.texture = null
		queue_redraw()
		return
	# Ikon: dosya varsa goster; yoksa esya adinin ilk 2 harfi
	var icon_path := String(Items.ITEMS.get(item_id, {}).get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		_icon_rect.texture = load(icon_path)
	else:
		_icon_rect.texture = null
		_letters.text = Items.display_name(item_id).substr(0, 2)
	_badge.visible = item_count > 1
	_badge_label.text = str(item_count)
	# Hotbar atamasi olup envanterde kalmamis esya soluk gorunur
	if kind == "hotbar" and item_count <= 0:
		_icon_rect.modulate = Color(1, 1, 1, 0.35)
		_badge.visible = false
	queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) * 0.425  # capin ~%85'i
	# Arkaplan dairesi
	var bg := UIColors.PANEL_CREAM_DARK
	if locked:
		bg = UIColors.PANEL_CREAM_DARK.lerp(UIColors.PANEL_CREAM, 0.5)
	elif item_id != "":
		bg = UIColors.item_color(item_id)
	draw_circle(center, radius, bg)
	# Eldeki esya (hotbar): koyu kahve ince halka + ALT NOKTA (R7/UI_DESIGN 4.1)
	if selected:
		draw_arc(center, radius + 2.0, 0, TAU, 40, UIColors.INK_DARK, 3.0, true)
		draw_circle(Vector2(center.x, size.y - 3.0), 3.5, UIColors.INK_DARK)
	# Tasima icin secildi: CIFT HALKA vurgusu (mockup .sel: koyu ic halka +
	# yumusak dis halka)
	if picked:
		draw_arc(center, radius + 4.0, 0, TAU, 48, UIColors.INK_DARK, 4.0, true)
		draw_arc(center, radius + 8.0, 0, TAU, 48,
				Color(UIColors.INK_DARK, 0.13), 4.0, true)
