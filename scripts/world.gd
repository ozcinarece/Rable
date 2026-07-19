extends Node2D
## Oyun dunyasini scripts/map_data.gd icindeki ASCII haritadan kurar;
## kaynak toplama ve insa (duvar yerlestirme) islerini yonetir.
##
## Sorumluluklari:
##   1. Tile gorselleri + carpismalari iceren TileSet'i kod ile olusturmak
##   2. ASCII haritayi okuyup TileMap'e dosemek
##   3. Oyuncuyu P noktasina yerlestirmek, kamerayi sinirlamak
##   4. Dokunma/aksiyon butonu isleme: insa modu acikken duvar
##      yerlestirir, degilken yakindaki agac/tas/duvari toplar
##
## Tarifler scripts/recipes.gd'de, envanter Inventory autoload'unda -
## bu dosya sadece "dunya" ile ilgilenir.

const TILE_SIZE: int = 32
const MapData = preload("res://scripts/map_data.gd")
const Recipes = preload("res://scripts/recipes.gd")
const Items = preload("res://scripts/items.gd")

## Oyuncu en fazla kac tile uzakligi etkileyebilir (1 = komsu tile'lar)
const HARVEST_REACH_TILES: int = 1

# Harita karakteri -> tile tanimi.
#   solid:   true ise carpisma kutusu eklenir (uzerinden yurunemez)
#   drops:   toplandiginda/sokuldugunde envantere eklenecek kaynaklar
#   becomes: toplandiktan sonra tile'in donusecegi karakter
#            (insa edilmis duvarlarda bunun yerine altindaki zemin geri gelir)
#   hits:    kac vurusta toplanacagi (yazilmazsa 1; buyuk/sert seyler fazla)
const TILE_DEFS: Dictionary = {
	".": {"texture": "res://assets/tiles/grass.png", "solid": false},
	"d": {"texture": "res://assets/tiles/dirt.png", "solid": false},
	"s": {"texture": "res://assets/tiles/sand.png", "solid": false},
	"~": {"texture": "res://assets/tiles/water.png", "solid": true},
	"#": {"texture": "res://assets/tiles/stone.png", "solid": true,
			"drops": {"tas": 2}, "becomes": "d", "hits": 4},
	"T": {"texture": "res://assets/tiles/tree.png", "solid": true,
			"drops": {"odun": 3, "yaprak": 2}, "becomes": ".", "hits": 3},
	# Insa edilebilir yapilar (sokulunce maliyeti tamamen iade edilir)
	"W": {"texture": "res://assets/tiles/wood_wall.png", "solid": true,
			"drops": {"odun": 2}, "becomes": ".", "hits": 2},
	"K": {"texture": "res://assets/tiles/stone_wall.png", "solid": true,
			"drops": {"tas": 2}, "becomes": ".", "hits": 3},
}

@onready var ground_tile_map: TileMap = $GroundTileMap
@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD

var _char_to_source_id: Dictionary = {}
var _cell_char: Dictionary = {}    # hucre -> o hucredeki harita karakteri
var _floor_under: Dictionary = {}  # hucre -> insa edilen duvarin altindaki zemin
var _cell_damage: Dictionary = {}  # hucre -> su ana kadar yedigi vurus sayisi
var _selected_recipe_id: String = ""
var _map_width: int = 0
var _map_height: int = 0

func _ready() -> void:
	ground_tile_map.tile_set = _build_tile_set()
	_build_map_from_ascii()
	player.world_tapped.connect(_on_player_world_tapped)
	hud.build_toggled.connect(_on_build_toggled)
	hud.action_pressed.connect(_on_action_pressed)

func _process(_delta: float) -> void:
	# Aksiyon butonunun ikonunu duruma gore guncelle
	# (yumruk = bos, balta = yakinda toplanabilir sey var, cekic = insa modu)
	hud.set_action_state(_compute_action_state())

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

		# ONEMLI: kaynak once TileSet'e eklenmeli, carpisma ondan sonra
		# tanimlanmali. Aksi halde tile henuz fizik katmanini bilmedigi
		# icin carpisma sessizce eklenmez (her seyin uzerinden yurunurdu).
		tile_set.add_source(source, next_id)

		if def["solid"]:
			var tile_data: TileData = source.get_tile_data(Vector2i(0, 0), 0)
			tile_data.add_collision_polygon(0)
			var h := TILE_SIZE / 2.0
			tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h),
			]))

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

# --- Girdi isleme ------------------------------------------------------

func _on_build_toggled(recipe_id: String) -> void:
	_selected_recipe_id = recipe_id

# Haritaya dokununca: insa modundaysa yerlestir, degilse topla.
func _on_player_world_tapped(world_pos: Vector2) -> void:
	var cell := ground_tile_map.local_to_map(ground_tile_map.to_local(world_pos))
	var player_cell := _get_player_cell()

	var diff := (cell - player_cell).abs()
	if maxi(diff.x, diff.y) > HARVEST_REACH_TILES:
		return

	if _selected_recipe_id != "":
		_try_place(cell, player_cell)
	else:
		_try_harvest(cell)

# Sagdaki aksiyon butonu: oyuncunun baktigi yondeki hucreyi hedefler.
# Toplama modunda bakilan hucrede toplanacak bir sey yoksa diger
# komsu hucreler de denenir (telefonda nisan almayi kolaylastirir).
func _on_action_pressed() -> void:
	var player_cell := _get_player_cell()
	var facing_offset := Vector2i(player.facing.round())
	if facing_offset == Vector2i.ZERO:
		facing_offset = Vector2i(0, 1)

	if _selected_recipe_id != "":
		_try_place(player_cell + facing_offset, player_cell)
		return

	var offsets: Array[Vector2i] = [facing_offset]
	for oy in [-1, 0, 1]:
		for ox in [-1, 0, 1]:
			var o := Vector2i(ox, oy)
			if o != Vector2i.ZERO and o != facing_offset:
				offsets.append(o)
	for o in offsets:
		if _try_harvest(player_cell + o):
			return

# --- Insa ve toplama ---------------------------------------------------

# Secili tarifi hedef hucreye yerlestirmeyi dener.
func _try_place(cell: Vector2i, player_cell: Vector2i) -> bool:
	if not _is_editable_cell(cell):
		return false
	if cell == player_cell:
		return false  # oyuncu kendini duvarin icine hapsedemesin

	var ch: String = _cell_char.get(cell, "")
	if ch == "" or TILE_DEFS[ch]["solid"]:
		return false  # sadece yurunebilir zemine insa edilebilir

	var recipe: Dictionary = Recipes.BUILD_RECIPES[_selected_recipe_id]
	var cost: Dictionary = recipe["cost"]

	# Once tum maliyeti karsilayabildigimizden emin ol, sonra harca
	for item_id in cost:
		if Inventory.get_count(item_id) < cost[item_id]:
			return false
	for item_id in cost:
		Inventory.remove_item(item_id, cost[item_id])

	_floor_under[cell] = ch  # sokulurse ayni zemin geri gelsin
	_set_cell_char(cell, recipe["tile"])
	return true

# Hedef hucreye bir vurus yapar; yeterince vurulduysa toplar.
func _try_harvest(cell: Vector2i) -> bool:
	if not _is_editable_cell(cell):
		return false

	var ch: String = _cell_char.get(cell, "")
	if ch == "" or not TILE_DEFS[ch].has("drops"):
		return false

	var def: Dictionary = TILE_DEFS[ch]

	# Coklu vurus: buyuk/sert seyler tek vurusta dusmez
	var hits_needed: int = def.get("hits", 1)
	var damage: int = _cell_damage.get(cell, 0) + 1
	if damage < hits_needed:
		_cell_damage[cell] = damage
		_spawn_floating_text(cell, "%d/%d" % [damage, hits_needed], Color(1.0, 0.95, 0.6))
		return true
	_cell_damage.erase(cell)

	var gained: PackedStringArray = []
	for item_id in def["drops"]:
		Inventory.add_item(item_id, def["drops"][item_id])
		gained.append("+%d %s" % [def["drops"][item_id], Items.display_name(item_id)])
	_spawn_floating_text(cell, " ".join(gained), Color(0.7, 1.0, 0.7))

	# Insa edilmis bir yapiysa altindaki zemini geri getir,
	# dogal bir seyse (agac/tas) tanimdaki "becomes" karakterine donus
	var new_ch: String = def["becomes"]
	if _floor_under.has(cell):
		new_ch = _floor_under[cell]
		_floor_under.erase(cell)
	_set_cell_char(cell, new_ch)
	return true

# --- Yardimcilar -------------------------------------------------------

# Aksiyon butonunun hangi ikonu gosterecegini belirler.
func _compute_action_state() -> String:
	if _selected_recipe_id != "":
		return "build"
	var player_cell := _get_player_cell()
	for oy in [-1, 0, 1]:
		for ox in [-1, 0, 1]:
			if ox == 0 and oy == 0:
				continue
			var cell := player_cell + Vector2i(ox, oy)
			if not _is_editable_cell(cell):
				continue
			var ch: String = _cell_char.get(cell, "")
			if ch != "" and TILE_DEFS[ch].has("drops"):
				return "gather"
	return "idle"

# Bir hucrenin ustunde kisa sure yukari sekip solan bir yazi gosterir
# (vurus sayaci "1/3" veya kazanilan kaynak "+3 odun" icin).
func _spawn_floating_text(cell: Vector2i, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.z_index = 100
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	label.position = ground_tile_map.map_to_local(cell) + Vector2(-14, -30)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 16.0, 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)

# Harita icinde ve en dis kenar (yikilamaz sinir duvarlari) disinda mi?
func _is_editable_cell(cell: Vector2i) -> bool:
	return cell.x > 0 and cell.y > 0 \
		and cell.x < _map_width - 1 and cell.y < _map_height - 1

func _get_player_cell() -> Vector2i:
	return ground_tile_map.local_to_map(ground_tile_map.to_local(player.global_position))

# Bir hucrenin karakterini gunceller ve gorselini doser
func _set_cell_char(cell: Vector2i, ch: String) -> void:
	_cell_char[cell] = ch
	ground_tile_map.set_cell(0, cell, _char_to_source_id[ch], Vector2i(0, 0))
