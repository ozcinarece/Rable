extends Button
## Kare envanter/hizli erisim slotu.
##
## - Dokunma: normal buton sinyali (pressed) - HUD dinler
## - Surukle: _get_drag_data ile esyayi tasir (parmakla basili tutup cek)
## - Birakma: _drop_data ile drop_received sinyali yayinlar
## - Panel disina birakma: DRAG_END bildirimi + basarisiz drop ->
##   dropped_to_ground sinyali (World esyayi yere birakir)
##
## kind: "inv" (envanter slotu) | "hotbar" (hizli erisim atamasi)

signal drop_received(data: Dictionary)
signal dropped_to_ground(data: Dictionary)

const LOCK_TEX := preload("res://assets/ui/lock.png")
const Items = preload("res://scripts/items.gd")

var kind: String = "inv"
var index: int = 0
var item_id: String = ""
var item_count: int = 0
var locked: bool = false
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

var _icon_rect: TextureRect
var _count_label: Label
var _dragging: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(56, 56)
	_icon_rect = TextureRect.new()
	_icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon_rect.offset_left = 8
	_icon_rect.offset_top = 8
	_icon_rect.offset_right = -8
	_icon_rect.offset_bottom = -8
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_rect)
	_count_label = Label.new()
	_count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_count_label.offset_left = -34
	_count_label.offset_top = -26
	_count_label.offset_right = -5
	_count_label.offset_bottom = -3
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.add_theme_font_size_override("font_size", 15)
	_count_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	_count_label.add_theme_constant_override("outline_size", 4)
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count_label)
	_apply_content()

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
	if locked:
		_icon_rect.texture = LOCK_TEX
		_icon_rect.modulate = Color(1, 1, 1, 0.55)
		_count_label.text = ""
		return
	_icon_rect.modulate = Color.WHITE
	if item_id == "":
		_icon_rect.texture = null
		_count_label.text = ""
		return
	_icon_rect.texture = load(Items.ITEMS[item_id]["icon"])
	_count_label.text = str(item_count) if item_count > 1 else ""
	# Hotbar atamasi olup envanterde kalmamis esya soluk gorunur
	if kind == "hotbar" and item_count <= 0:
		_icon_rect.modulate = Color(1, 1, 1, 0.35)
		_count_label.text = ""

# Secili (eldeki) slotun ustune turuncu cerceve cizer
func _draw() -> void:
	if selected:
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)),
				Color(0.98, 0.62, 0.22), false, 3.0)

# --- Surukle & birak ----------------------------------------------------

func _get_drag_data(_pos: Vector2) -> Variant:
	if locked or item_id == "":
		return null
	if kind == "hotbar" and item_count <= 0:
		return null
	_dragging = true
	var preview := TextureRect.new()
	preview.texture = _icon_rect.texture
	preview.custom_minimum_size = Vector2(44, 44)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = Color(1, 1, 1, 0.85)
	set_drag_preview(preview)
	return {"kind": kind, "index": index, "id": item_id, "count": item_count}

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("kind") and not locked

func _drop_data(_pos: Vector2, data: Variant) -> void:
	drop_received.emit(data)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _dragging:
		_dragging = false
		# Hicbir slot kabul etmediyse: envanter esyasi yere birakilir
		if not is_drag_successful() and kind == "inv":
			dropped_to_ground.emit({"kind": kind, "index": index,
					"id": item_id, "count": item_count})
