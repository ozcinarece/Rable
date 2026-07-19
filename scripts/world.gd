extends Node2D
## Oyun dunyasini scripts/map_data.gd icindeki ASCII haritadan kurar;
## kaynak toplama ve insa (duvar yerlestirme) islerini yonetir.
##
## Sorumluluklari:
##   1. Tile gorselleri + carpismalari iceren TileSet'i kod ile olusturmak
##   2. ASCII haritayi okuyup TileMap'e dosemek
##   3. Oyuncuyu P noktasina yerlestirmek, kamerayi sinirlamak
##   4. Dokunma isleme: insa modu acikken duvar yerlestirir,
##      degilken yanindaki agac/tas/duvari toplar
##
## Tarifler scripts/recipes.gd'de, envanter Inventory autoload'unda -
## bu dosya sadece "dunya" ile ilgilenir.

const TILE_SIZE: int = 32
const MapData = preload("res://scripts/map_data.gd")
const Recipes = preload("res://scripts/recipes.gd")

## Oyuncu en fazla kac tile uzakligi etkileyebilir (1 = komsu tile'lar)
const HARVEST_REACH_TILES: int = 1

# Harita karakteri -> tile tanimi.
#   solid:   true ise carpisma kutusu eklenir (uzerinden yurunemez)
#   drops:   toplandiginda/sokuldugunde envantere eklenecek kaynaklar
#   becomes: toplandiktan sonra tile'in donusecegi karakter
#            (insa edilmis duvarlarda bunun yerine altindaki zemin geri gelir)
const TILE_DEFS: Dictionary = {
	".": {"texture": "res://assets/tiles/grass.png", "solid": false},
	"d": {"texture": "res://assets/tiles/dirt.png", "solid": false},
	"s": {"texture": "res://assets/tiles/sand.png", "solid": false},
	"~": {"texture": "res://assets/tiles/water.png", "solid": true},
	"#": {"texture": "res://assets/tiles/stone.png", "solid": true,
			"drops": {"tas": 2}, "becomes": "d"},
	"T": {"texture": "res://assets/tiles/tree.png", "solid": true,
			"drops": {"odun": 3}, "becomes": "."},
	# Insa edilebilir yapilar (sokulunce maliyeti tamamen iade edilir)
	"W": {"texture": "res://assets/tiles/wood_wall.png", "solid": true,
			"drops": {"odun": 2}, "becomes": "."},
	"K": {"texture": "res://assets/tiles/stone_wall.png", "solid": true,
			"drops": {"tas": 2}, "becomes": "."},
}

@onready var ground_tile_map: TileMap = $GroundTileMap
@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD

var _char_to_source_id: Dictionary = {}
var _cell_char: Dictionary = {}    # hucre -> o hucredeki harita karakteri
var _floor_under: Dictionary = {}  # hucre -> insa edilen duvarin altindaki zemin
var _selected_recipe_id: String = ""
var _map_width: int = 0
var _map_height: int = 0

func _ready() -> void:
	ground_tile_map.tile_set = _build_tile_set()
	_build_map_from_ascii()
	player.world_tapped.connect(_on_player_world_tapped)
	hud.build_toggled.connect(_on_build_toggled)

# --- Kurulum -----------------------------------------------------------

func _build_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_physics_layer()

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

# --- Dokunma isleme ----------------------------------------------------

func _on_build_toggled(recipe_id: String) -> void:
	_selected_recipe_id = recipe_id

func _on_player_world_tapped(world_pos: Vector2) -> void:
	var cell := ground_tile_map.local_to_map(ground_tile_map.to_local(world_pos))
	var player_cell := ground_tile_map.local_to_map(ground_tile_map.to_local(player.global_position))

	# Erisim kontrolu: sadece oyuncunun yanindaki tile'lar etkilenebilir
	var diff := (cell - player_cell).abs()
	if maxi(diff.x, diff.y) > HARVEST_REACH_TILES:
		return

	# Haritanin en dis kenari (sinir duvarlari) hicbir sekilde degistirilemez
	if cell.x <= 0 or cell.y <= 0 or cell.x >= _map_width - 1 or cell.y >= _map_height - 1:
		return

	if _selected_recipe_id != "":
		_try_place(cell, player_cell)
	else:
		_try_harvest(cell)

# Insa modu: secili tarifi dokunulan zemine yerlestirmeyi dener.
func _try_place(cell: Vector2i, player_cell: Vector2i) -> void:
	if cell == player_cell:
		return  # oyuncu kendini duvarin icine hapsedemesin

	var ch: String = _cell_char.get(cell, "")
	if ch == "" or TILE_DEFS[ch]["solid"]:
		return  # sadece yurunebilir zemine insa edilebilir

	var recipe: Dictionary = Recipes.RECIPES[_selected_recipe_id]
	var cost: Dictionary = recipe["cost"]

	# Once tum maliyeti karsilayabildigimizden emin ol, sonra harca
	for item_id in cost:
		if Inventory.get_count(item_id) < cost[item_id]:
			return
	for item_id in cost:
		Inventory.remove_item(item_id, cost[item_id])

	_floor_under[cell] = ch  # sokulurse ayni zemin geri gelsin
	_set_cell_char(cell, recipe["tile"])

# Normal mod: dokunulan tile toplanabilirse toplar.
func _try_harvest(cell: Vector2i) -> void:
	var ch: String = _cell_char.get(cell, "")
	if ch == "" or not TILE_DEFS[ch].has("drops"):
		return

	var def: Dictionary = TILE_DEFS[ch]
	for item_id in def["drops"]:
		Inventory.add_item(item_id, def["drops"][item_id])

	# Insa edilmis bir yapiysa altindaki zemini geri getir,
	# dogal bir seyse (agac/tas) tanimdaki "becomes" karakterine donus
	var new_ch: String = def["becomes"]
	if _floor_under.has(cell):
		new_ch = _floor_under[cell]
		_floor_under.erase(cell)
	_set_cell_char(cell, new_ch)

# Bir hucrenin karakterini gunceller ve gorselini doser
func _set_cell_char(cell: Vector2i, ch: String) -> void:
	_cell_char[cell] = ch
	ground_tile_map.set_cell(0, cell, _char_to_source_id[ch], Vector2i(0, 0))
