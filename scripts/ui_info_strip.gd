extends PanelContainer
## R3 BILGI SERIDI — envanter/uretim/arastirma panellerinde ORTAK alt bant.
## TEK bilesen (UI_REVIZYON_1 R3): solda buyuk ikon dairesi, ortada ad + TEK
## SATIR aciklama (uzun metin "..." ile kirpilir), sagda eylem pill'leri.
## Kullanim:
##   var strip := preload("res://scripts/ui_info_strip.gd").new()
##   strip.show_item(icon_tex, "Odun", "Yakacak ve yapi malzemesi", circle_col)
##   strip.set_pills([{"text": "Ye", "primary": true, "on": Callable(...)}])
##   strip.set_placeholder("Bir eşya seç")   # secim yokken

const UIColors = preload("res://scripts/ui_colors.gd")
const ICON_INSET := 11.0

var _circle: Panel
var _circle_style: StyleBoxFlat
var _icon: TextureRect
var _name: Label
var _desc: Label
var _pills: HBoxContainer

func _init() -> void:
	theme_type_variation = "InnerPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)

	# Sol: buyuk ikon dairesi (kategori rengi)
	_circle = Panel.new()
	_circle.custom_minimum_size = Vector2(64, 64)
	_circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_circle_style = StyleBoxFlat.new()
	_circle_style.bg_color = UIColors.PANEL_CREAM_DARK
	_circle_style.set_corner_radius_all(999)
	_circle.add_theme_stylebox_override("panel", _circle_style)
	_icon = TextureRect.new()
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = ICON_INSET
	_icon.offset_top = ICON_INSET
	_icon.offset_right = -ICON_INSET
	_icon.offset_bottom = -ICON_INSET
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_circle.add_child(_icon)
	row.add_child(_circle)

	# Orta: ad + tek satir aciklama (uzun -> "...")
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_theme_constant_override("separation", 2)
	row.add_child(mid)
	_name = Label.new()
	_name.theme_type_variation = "BadgeLabel"
	mid.add_child(_name)
	_desc = Label.new()
	_desc.theme_type_variation = "SubtleLabel"
	_desc.clip_text = true
	_desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_desc.max_lines_visible = 1
	mid.add_child(_desc)

	# Sag: eylem pill'leri
	_pills = HBoxContainer.new()
	_pills.add_theme_constant_override("separation", 10)
	_pills.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_pills)

## Secili esyayi goster: ikon + ad + tek satir aciklama + kategori dairesi.
func show_item(icon_tex: Texture2D, name_text: String, desc_text: String,
		circle_color: Color) -> void:
	_icon.texture = icon_tex
	_icon.visible = icon_tex != null
	_name.text = name_text
	_desc.text = desc_text
	_circle_style.bg_color = circle_color

## Secim yokken: kisa yonlendirme metni, ikon bos, notr daire.
func set_placeholder(text: String) -> void:
	_icon.texture = null
	_name.text = ""
	_desc.text = text
	_circle_style.bg_color = UIColors.PANEL_CREAM_DARK
	clear_pills()

## Eylem pill'leri: [{text, primary(bool), on(Callable), danger(bool)}].
func set_pills(pills: Array) -> void:
	clear_pills()
	for p: Dictionary in pills:
		var btn := Button.new()
		btn.text = String(p.get("text", ""))
		if bool(p.get("primary", false)):
			btn.theme_type_variation = "PrimaryButton"
		btn.custom_minimum_size = Vector2(0, 44)
		var cb: Callable = p.get("on", Callable())
		if cb.is_valid():
			btn.pressed.connect(cb)
		_pills.add_child(btn)

func clear_pills() -> void:
	for c in _pills.get_children():
		c.queue_free()
