extends Node2D
## Insa/kazma/tasima modunda oyuncunun cevresine grid cizgileri ve
## hedef hucreye yesil/kirmizi yerlestirme onizlemesi cizer.
## World her kare alanlari gunceller ve queue_redraw cagirir.

const TILE: int = 32
const GRID_RADIUS: int = 5  # oyuncunun cevresinde kac hucrelik grid

var grid_visible: bool = false
var center_cell: Vector2i = Vector2i.ZERO
var preview_cell: Vector2i = Vector2i(-999, -999)
var preview_ok: bool = true

func _draw() -> void:
	if not grid_visible:
		return
	# Grid cizgileri (yari saydam beyaz)
	var line_color := Color(1, 1, 1, 0.14)
	var origin := Vector2((center_cell.x - GRID_RADIUS) * TILE, (center_cell.y - GRID_RADIUS) * TILE)
	var span := (GRID_RADIUS * 2 + 1) * TILE
	for i in GRID_RADIUS * 2 + 2:
		var offset := i * TILE
		draw_line(origin + Vector2(offset, 0), origin + Vector2(offset, span), line_color, 1.0)
		draw_line(origin + Vector2(0, offset), origin + Vector2(span, offset), line_color, 1.0)
	# Hedef hucre vurgusu
	if preview_cell.x <= -900:
		return
	var pos := Vector2(preview_cell.x * TILE, preview_cell.y * TILE)
	var fill := Color(0.35, 0.9, 0.45, 0.35) if preview_ok else Color(0.95, 0.35, 0.3, 0.4)
	var border := Color(0.25, 0.8, 0.35, 0.95) if preview_ok else Color(0.9, 0.25, 0.2, 0.95)
	draw_rect(Rect2(pos, Vector2(TILE, TILE)), fill, true)
	draw_rect(Rect2(pos + Vector2(1, 1), Vector2(TILE - 2, TILE - 2)), border, false, 2.0)
