extends Node2D
## Oyun dunyasini scripts/map_data.gd icindeki ASCII haritadan kurar.
##
## Sorumluluklari:
##   1. Tile gorselleri + carpismalari iceren TileSet'i kod ile olusturmak
##   2. ASCII haritayi okuyup TileMap'e dosemek
##   3. Oyuncuyu haritadaki P noktasina yerlestirmek
##   4. Kamerayi harita sinirlarina kilitlemek
##
## Ileride prosedurel harita uretimine gecerken sadece MAP verisinin
## geldigi yer degisecek; buradaki doseme mantigi ayni kalacak.

const TILE_SIZE: int = 32
const MapData = preload("res://scripts/map_data.gd")

# Harita karakteri -> tile tanimi.
# "solid" true olan tile'lara carpisma kutusu eklenir (uzerinden yurunemez).
const TILE_DEFS: Dictionary = {
	".": {"texture": "res://assets/tiles/grass.png", "solid": false},
	"d": {"texture": "res://assets/tiles/dirt.png", "solid": false},
	"s": {"texture": "res://assets/tiles/sand.png", "solid": false},
	"~": {"texture": "res://assets/tiles/water.png", "solid": true},
	"#": {"texture": "res://assets/tiles/stone.png", "solid": true},
	"T": {"texture": "res://assets/tiles/tree.png", "solid": true},
}

@onready var ground_tile_map: TileMap = $GroundTileMap
@onready var player: CharacterBody2D = $Player

# Hangi karakterin TileSet'te hangi source id'ye karsilik geldigini tutar
var _char_to_source_id: Dictionary = {}

func _ready() -> void:
	ground_tile_map.tile_set = _build_tile_set()
	_build_map_from_ascii()

# Tum tile turlerini (gorsel + gerekiyorsa carpisma) iceren TileSet olusturur.
func _build_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_physics_layer()  # engel tile'larin carpisma katmani

	var next_id := 0
	for ch in TILE_DEFS:
		var def: Dictionary = TILE_DEFS[ch]
		var source := TileSetAtlasSource.new()
		source.texture = load(def["texture"])
		source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		source.create_tile(Vector2i(0, 0))

		if def["solid"]:
			# Tile'in tamamini kaplayan kare bir carpisma poligonu ekle
			var tile_data: TileData = source.get_tile_data(Vector2i(0, 0), 0)
			tile_data.add_collision_polygon(0)
			var h := TILE_SIZE / 2.0
			tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h),
			]))

		tile_set.add_source(source, next_id)
		_char_to_source_id[ch] = next_id
		next_id += 1

	return tile_set

# ASCII haritayi satir satir okuyup tile'lari doser.
func _build_map_from_ascii() -> void:
	var rows: Array[String] = MapData.MAP
	for y in rows.size():
		var row := rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == "P":
				# Oyuncunun baslangic noktasi; zeminine cim doselenir
				player.position = ground_tile_map.map_to_local(Vector2i(x, y))
				ch = "."
			if not TILE_DEFS.has(ch):
				ch = "."  # bilinmeyen karakter olursa cime dus
			ground_tile_map.set_cell(0, Vector2i(x, y), _char_to_source_id[ch], Vector2i(0, 0))

	_apply_camera_limits(rows[0].length(), rows.size())

# Kamerayi harita disini gostermeyecek sekilde sinirlar.
func _apply_camera_limits(map_width_tiles: int, map_height_tiles: int) -> void:
	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = map_width_tiles * TILE_SIZE
	camera.limit_bottom = map_height_tiles * TILE_SIZE
