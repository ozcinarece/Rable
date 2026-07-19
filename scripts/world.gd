extends Node2D
## Oyun dunyasini kuran script.
## Zemin (cim/toprak) tile'larini kod ile olusturup TileMap'e yerlestirir,
## boylece Godot editorunde elle tile boyamaya gerek kalmaz.
##
## Ileride buraya crafting, gece/gunduz dongusu, kazma gibi sistemler
## World sahnesine yeni child node / script olarak eklenebilir;
## bu script sadece zemin ve oyuncunun baslangic konumundan sorumludur.

const TILE_SIZE: int = 32
const MAP_WIDTH: int = 24   # tile sayisi (yatay)
const MAP_HEIGHT: int = 18  # tile sayisi (dikey)

const GRASS_SOURCE_ID: int = 0
const DIRT_SOURCE_ID: int = 1

@onready var ground_tile_map: TileMap = $GroundTileMap
@onready var player: CharacterBody2D = $Player

func _ready() -> void:
	ground_tile_map.tile_set = _build_tile_set()
	_generate_ground()
	_center_player()

# Grass ve dirt placeholder tile'larini iceren bir TileSet kaynagi olusturur.
func _build_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var grass_source := TileSetAtlasSource.new()
	grass_source.texture = load("res://assets/tiles/grass.png")
	grass_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	grass_source.create_tile(Vector2i(0, 0))
	tile_set.add_source(grass_source, GRASS_SOURCE_ID)

	var dirt_source := TileSetAtlasSource.new()
	dirt_source.texture = load("res://assets/tiles/dirt.png")
	dirt_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	dirt_source.create_tile(Vector2i(0, 0))
	tile_set.add_source(dirt_source, DIRT_SOURCE_ID)

	return tile_set

# Zemini cim ile doldurur, gorsel cesitlilik icin sabit bir desende toprak serpistirir.
func _generate_ground() -> void:
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var source_id := GRASS_SOURCE_ID
			if (x * 3 + y * 5) % 17 == 0:
				source_id = DIRT_SOURCE_ID
			ground_tile_map.set_cell(0, Vector2i(x, y), source_id, Vector2i(0, 0))

# Oyuncuyu haritanin ortasina yerlestirir.
func _center_player() -> void:
	var center_tile := Vector2i(MAP_WIDTH / 2, MAP_HEIGHT / 2)
	player.position = ground_tile_map.map_to_local(center_tile)
