extends Node2D
## Oyun dunyasini scripts/map_data.gd icindeki ASCII haritadan kurar
## ve kaynak toplamayi yonetir.
##
## Sorumluluklari:
##   1. Tile gorselleri + carpismalari iceren TileSet'i kod ile olusturmak
##   2. ASCII haritayi okuyup TileMap'e dosemek
##   3. Oyuncuyu haritadaki P noktasina yerlestirmek, kamerayi sinirlamak
##   4. Oyuncunun dokundugu tile'da kaynak toplama (agac -> odun vb.)
##
## Ileride prosedurel harita uretimine gecerken sadece MAP verisinin
## geldigi yer degisecek; buradaki doseme/toplama mantigi ayni kalacak.

const TILE_SIZE: int = 32
const MapData = preload("res://scripts/map_data.gd")

## Oyuncu en fazla kac tile uzaktaki bir seyi toplayabilir (1 = komsu tile'lar)
const HARVEST_REACH_TILES: int = 1

# Harita karakteri -> tile tanimi.
#   solid:   true ise carpisma kutusu eklenir (uzerinden yurunemez)
#   drops:   toplandiginda envantere eklenecek kaynaklar
#   becomes: toplandiktan sonra tile'in donusecegi karakter
const TILE_DEFS: Dictionary = {
	".": {"texture": "res://assets/tiles/grass.png", "solid": false},
	"d": {"texture": "res://assets/tiles/dirt.png", "solid": false},
	"s": {"texture": "res://assets/tiles/sand.png", "solid": false},
	"~": {"texture": "res://assets/tiles/water.png", "solid": true},
	"#": {"texture": "res://assets/tiles/stone.png", "solid": true,
			"drops": {"tas": 2}, "becomes": "d"},
	"T": {"texture": "res://assets/tiles/tree.png", "solid": true,
			"drops": {"odun": 3}, "becomes": "."},
}

@onready var ground_tile_map: TileMap = $GroundTileMap
@onready var player: CharacterBody2D = $Player

var _char_to_source_id: Dictionary = {}
var _cell_char: Dictionary = {}  # Vector2i hucre -> o hucredeki harita karakteri
var _map_width: int = 0
var _map_height: int = 0

func _ready() -> void:
	ground_tile_map.tile_set = _build_tile_set()
	_build_map_from_ascii()
	player.world_tapped.connect(_on_player_world_tapped)

# --- Kurulum -----------------------------------------------------------

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

func _build_map_from_ascii() -> void:
	var rows: Array[String] = MapData.MAP
	_map_height = rows.size()
	_map_width = rows[0].length()

	for y in rows.size():
		var row := rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == "P":
				player.position = ground_tile_map.map_to_local(Vector2i(x, y))
				ch = "."
			if not TILE_DEFS.has(ch):
				ch = "."
			_set_cell_char(Vector2i(x, y), ch)

	_apply_camera_limits()

func _apply_camera_limits() -> void:
	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = _map_width * TILE_SIZE
	camera.limit_bottom = _map_height * TILE_SIZE

# --- Kaynak toplama ----------------------------------------------------

func _on_player_world_tapped(world_pos: Vector2) -> void:
	var cell := ground_tile_map.local_to_map(ground_tile_map.to_local(world_pos))
	var player_cell := ground_tile_map.local_to_map(ground_tile_map.to_local(player.global_position))

	# Erisim kontrolu: sadece oyuncunun yanindaki tile'lar toplanabilir
	var diff := (cell - player_cell).abs()
	if maxi(diff.x, diff.y) > HARVEST_REACH_TILES:
		return

	# Haritanin en dis kenari (sinir duvarlari) yikilamaz
	if cell.x <= 0 or cell.y <= 0 or cell.x >= _map_width - 1 or cell.y >= _map_height - 1:
		return

	var ch: String = _cell_char.get(cell, "")
	if ch == "" or not TILE_DEFS[ch].has("drops"):
		return

	# Kaynaklari envantere ekle, tile'i donustur
	var def: Dictionary = TILE_DEFS[ch]
	for item_id in def["drops"]:
		Inventory.add_item(item_id, def["drops"][item_id])
	_set_cell_char(cell, def["becomes"])

# Bir hucrenin karakterini gunceller ve gorselini doser
func _set_cell_char(cell: Vector2i, ch: String) -> void:
	_cell_char[cell] = ch
	ground_tile_map.set_cell(0, cell, _char_to_source_id[ch], Vector2i(0, 0))
