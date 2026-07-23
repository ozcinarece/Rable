extends Control
## Mockup imza dokusu: zeminde COK SOLUK nokta izgarasi
## (backpack_ui_mockup.html: radial-gradient 1px, 14px aralik, ~%2 siyah).
## PanelContainer icine tam-boy overlay olarak eklenir; girdiyi yutmaz.

const STEP := 14.0
const DOT_R := 1.0
const DOT_COLOR := Color(0, 0, 0, 0.024)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var nx := int(size.x / STEP) + 1
	var ny := int(size.y / STEP) + 1
	for iy in ny:
		for ix in nx:
			draw_circle(Vector2(ix * STEP + STEP * 0.5, iy * STEP + STEP * 0.5),
					DOT_R, DOT_COLOR)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
