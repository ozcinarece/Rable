extends Control
## Mockup imza ogesi: DIKISLI DERI TUTAMAC (panel ust orta).
## backpack_ui_mockup.html .handle: 84x12 tan kapsul + ust/alt kesik dikis.

const UIColors = preload("res://scripts/ui_colors.gd")
const W := 84.0
const H := 12.0
const STITCH := Color("#F6EDD6E6")  # krem, ~%90

func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	# Deri kapsul
	var rect := Rect2(Vector2.ZERO, Vector2(W, H))
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIColors.CATEGORY_COLORS["station"]  # #C9A87C deri tonu
	sb.set_corner_radius_all(99)
	draw_style_box(sb, rect)
	# Kesik dikisler (inset: 3px dikey, 8px yatay)
	draw_dashed_line(Vector2(8, 3), Vector2(W - 8, 3), STITCH, 2.0, 4.0)
	draw_dashed_line(Vector2(8, H - 3), Vector2(W - 8, H - 3), STITCH, 2.0, 4.0)
