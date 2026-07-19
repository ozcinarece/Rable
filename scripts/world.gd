extends Node2D
## Oyun dunyasi - 3/4 perspektif (Animal Crossing / Stardew tarzi).
##
## Iki katman:
##   1. Zemin (GroundTileMap): cim/toprak/kum/su/cukur - duz tile'lar.
##      Su ve cukur carpismalidir (gecilemez).
##   2. Nesneler (YSort altinda): agac/kaya/duvar/yapilar - her biri
##      32x64 gorselli, Y-sirali sprite. Ekranda asagida olan one
##      cizilir; oyuncu agacin arkasindan gecince tepenin arkasinda
##      kalir. Nesnelerin carpismasi hucre tabaninda 30x30 kutudur.
##
## Kaynak toplama, insa, kazma, sandik ve kayit islerini de yonetir.

const TILE_SIZE: int = 32
const MapData = preload("res://scripts/map_data.gd")
const Recipes = preload("res://scripts/recipes.gd")
const Items = preload("res://scripts/items.gd")

const HARVEST_REACH_TILES: int = 1
const REGROW_SECONDS: float = 60.0
const SAVE_INTERVAL: float = 8.0
const NO_CELL := Vector2i(-999, -999)

# Zemin tanimlari. "dig": kurekle kazilabilir, verdigi esya.
const GROUND_DEFS: Dictionary = {
	".": {"texture": "res://assets/tiles/grass.png", "solid": false, "dig": {"toprak": 1}},
	"d": {"texture": "res://assets/tiles/dirt.png", "solid": false, "dig": {"toprak": 1}},
	"s": {"texture": "res://assets/tiles/sand.png", "solid": false, "dig": {"kum": 1}},
	"~": {"texture": "res://assets/tiles/water.png", "solid": true},
	"o": {"texture": "res://assets/tiles/cukur.png", "solid": true},
}

# Nesne tanimlari (hepsi engeldir).
#   drops/hits/tool: toplama; becomes_object: toplaninca donusecegi nesne
#   ground_becomes: toplaninca altindaki zemini degistirir (kaya -> toprak)
const OBJECT_DEFS: Dictionary = {
	"T": {"texture": "res://assets/tiles/tree.png",
			"drops": {"odun": 3, "yaprak": 2}, "hits": 3,
			"tool": {"item": "balta", "hits": 1}},
	"#": {"texture": "res://assets/tiles/stone.png",
			"drops": {"tas": 2}, "hits": 4,
			"tool": {"item": "kazma", "hits": 2}, "ground_becomes": "d"},
	"W": {"texture": "res://assets/tiles/wood_wall.png",
			"drops": {"kalas": 2}, "hits": 2},
	"K": {"texture": "res://assets/tiles/stone_wall.png",
			"drops": {"tas": 2}, "hits": 3},
	"B": {"texture": "res://assets/tiles/tezgah.png",
			"drops": {"kalas": 4, "cubuk": 2}, "hits": 2},
	"E": {"texture": "res://assets/tiles/ev.png",
			"drops": {"kalas": 6, "ip": 2, "yaprak": 4}, "hits": 3},
	"m": {"texture": "res://assets/tiles/bush_full.png",
			"drops": {"meyve": 2}, "hits": 1, "becomes_object": "n"},
	"n": {"texture": "res://assets/tiles/bush_empty.png"},
	"S": {"texture": "res://assets/tiles/sandik.png"},
}

@onready var ground_tile_map: TileMap = $GroundTileMap
@onready var ysort: Node2D = $YSort
@onready var player: CharacterBody2D = $YSort/Player
@onready var hud: CanvasLayer = $HUD

var _ground_source_id: Dictionary = {}   # zemin karakteri -> tileset source id
var _ground_char: Dictionary = {}        # hucre -> zemin karakteri
var _object_char: Dictionary = {}        # hucre -> nesne karakteri (yoksa yok)
var _object_nodes: Dictionary = {}       # hucre -> StaticBody2D
var _cell_damage: Dictionary = {}
var _regrow: Dictionary = {}
var _chests: Dictionary = {}
var _open_chest: Vector2i = NO_CELL
var _selected_recipe_id: String = ""
var _dig_mode: bool = false
var _respawn_cell: Vector2i = Vector2i.ZERO
var _save_timer: float = 0.0
var _map_width: int = 0
var _map_height: int = 0

func _ready() -> void:
	ground_tile_map.tile_set = _build_ground_tile_set()
	_build_map_from_ascii()
	_load_game()
	player.world_tapped.connect(_on_player_world_tapped)
	hud.build_toggled.connect(_on_build_toggled)
	hud.action_pressed.connect(_on_action_pressed)
	hud.chest_transfer_requested.connect(_on_chest_transfer)
	hud.chest_dismantle_requested.connect(_on_chest_dismantle)
	hud.chest_closed.connect(func(): _open_chest = NO_CELL)
	hud.dig_toggled.connect(func(enabled: bool): _dig_mode = enabled)

func _process(delta: float) -> void:
	hud.set_action_state(_compute_action_state())
	Crafting.near_station = _is_near_object("B")
	if _open_chest != NO_CELL:
		var diff := (_open_chest - _get_player_cell()).abs()
		if maxi(diff.x, diff.y) > 1:
			_close_chest()
	_tick_regrow(delta)
	_save_timer += delta
	if _save_timer >= SAVE_INTERVAL:
		_save_timer = 0.0
		_save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()

# --- Kurulum -----------------------------------------------------------

func _build_ground_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_physics_layer()
	var next_id := 0
	for ch in GROUND_DEFS:
		var def: Dictionary = GROUND_DEFS[ch]
		var source := TileSetAtlasSource.new()
		source.texture = load(def["texture"])
		source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		source.create_tile(Vector2i(0, 0))
		tile_set.add_source(source, next_id)
		if def["solid"]:
			var tile_data: TileData = source.get_tile_data(Vector2i(0, 0), 0)
			tile_data.add_collision_polygon(0)
			var half := TILE_SIZE / 2.0
			tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-half, -half), Vector2(half, -half),
				Vector2(half, half), Vector2(-half, half),
			]))
		_ground_source_id[ch] = next_id
		next_id += 1
	return tile_set

func _build_map_from_ascii() -> void:
	var rows: Array[String] = MapData.MAP
	_map_height = rows.size()
	_map_width = rows[0].length()
	for y in rows.size():
		var row := rows[y]
		for x in row.length():
			var cell := Vector2i(x, y)
			var ch := row[x]
			if ch == "P":
				player.position = ground_tile_map.map_to_local(cell)
				_respawn_cell = cell
				ch = "."
			if OBJECT_DEFS.has(ch):
				_set_ground(cell, ".")
				_set_object(cell, ch)
			elif GROUND_DEFS.has(ch):
				_set_ground(cell, ch)
			else:
				_set_ground(cell, ".")
	_apply_camera_limits()

func _apply_camera_limits() -> void:
	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = _map_width * TILE_SIZE
	camera.limit_bottom = _map_height * TILE_SIZE

# --- Katman erisimi ----------------------------------------------------

func _set_ground(cell: Vector2i, ch: String) -> void:
	_ground_char[cell] = ch
	ground_tile_map.set_cell(0, cell, _ground_source_id[ch], Vector2i(0, 0))

# ch bos string ise nesneyi kaldirir.
func _set_object(cell: Vector2i, ch: String) -> void:
	if _object_nodes.has(cell):
		_object_nodes[cell].queue_free()
		_object_nodes.erase(cell)
	_object_char.erase(cell)
	_regrow.erase(cell)
	if ch == "":
		return
	_object_char[cell] = ch
	var body := StaticBody2D.new()
	body.position = ground_tile_map.map_to_local(cell)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 30)
	shape.shape = rect
	body.add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = load(OBJECT_DEFS[ch]["texture"])
	sprite.offset = Vector2(0, -16)  # 32x64 gorselin tabani hucreye oturur
	body.add_child(sprite)
	ysort.add_child(body)
	_object_nodes[cell] = body
	if ch == "n":
		_regrow[cell] = REGROW_SECONDS

func _tick_regrow(delta: float) -> void:
	var ready_cells: Array[Vector2i] = []
	for cell in _regrow:
		_regrow[cell] -= delta
		if _regrow[cell] <= 0.0:
			ready_cells.append(cell)
	for cell in ready_cells:
		_set_object(cell, "m")

# --- Girdi isleme ------------------------------------------------------

func _on_build_toggled(recipe_id: String) -> void:
	_selected_recipe_id = recipe_id

func _on_player_world_tapped(world_pos: Vector2) -> void:
	var cell := ground_tile_map.local_to_map(ground_tile_map.to_local(world_pos))
	var player_cell := _get_player_cell()
	var diff := (cell - player_cell).abs()
	if maxi(diff.x, diff.y) > HARVEST_REACH_TILES:
		return
	if _dig_mode:
		_try_dig(cell)
	elif _selected_recipe_id != "":
		_try_place(cell, player_cell)
	elif _object_char.get(cell, "") == "S":
		_open_chest = cell
		hud.show_chest(_chests.get(cell, {}))
	else:
		_try_harvest(cell)

func _on_action_pressed() -> void:
	var player_cell := _get_player_cell()
	var facing_offset := Vector2i(player.facing.round())
	if facing_offset == Vector2i.ZERO:
		facing_offset = Vector2i(0, 1)
	if _dig_mode:
		_try_dig(player_cell + facing_offset)
		return
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

# --- Insa / toplama / kazma --------------------------------------------

func _try_place(cell: Vector2i, player_cell: Vector2i) -> bool:
	if not _is_editable_cell(cell):
		return false
	if cell == player_cell:
		return false

	var recipe: Dictionary = Recipes.BUILD_RECIPES[_selected_recipe_id]
	var ground: String = _ground_char.get(cell, "")

	if recipe.has("place_on"):
		# Ozel hedefli tarif (Doldur: sadece cukura)
		if ground != recipe["place_on"] or _object_char.has(cell):
			return false
	else:
		# Normal yapi: bos, yurunebilir zemine
		if _object_char.has(cell):
			return false
		if ground == "" or GROUND_DEFS[ground]["solid"]:
			return false

	var cost: Dictionary = recipe["cost"]
	for item_id in cost:
		if Inventory.get_count(item_id) < cost[item_id]:
			return false
	for item_id in cost:
		Inventory.remove_item(item_id, cost[item_id])

	if recipe.has("place_on"):
		_set_ground(cell, recipe["tile"])
	else:
		_set_object(cell, recipe["tile"])
		if recipe["tile"] == "E":
			_respawn_cell = cell
			_spawn_floating_text(cell, "Kamp kuruldu!", Color(0.75, 0.9, 1.0))
	return true

func _try_harvest(cell: Vector2i) -> bool:
	if not _is_editable_cell(cell):
		return false
	var ch: String = _object_char.get(cell, "")
	if ch == "" or not OBJECT_DEFS[ch].has("drops"):
		return false

	var def: Dictionary = OBJECT_DEFS[ch]
	var hits_needed: int = def.get("hits", 1)
	if def.has("tool") and Inventory.get_count(def["tool"]["item"]) > 0:
		hits_needed = def["tool"]["hits"]
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

	if def.has("becomes_object"):
		_set_object(cell, def["becomes_object"])
	else:
		_set_object(cell, "")
		if def.has("ground_becomes"):
			_set_ground(cell, def["ground_becomes"])
	return true

func _try_dig(cell: Vector2i) -> bool:
	if not _is_editable_cell(cell):
		return false
	if _object_char.has(cell):
		return false  # ustunde nesne varken kazilamaz
	var ground: String = _ground_char.get(cell, "")
	if ground == "" or not GROUND_DEFS[ground].has("dig"):
		return false
	if Inventory.get_count("kurek") <= 0:
		_spawn_floating_text(cell, "Kürek gerekli! (Tezgahta üret)", Color(1, 0.7, 0.6))
		return false

	var dig_drops: Dictionary = GROUND_DEFS[ground]["dig"]
	var gained: PackedStringArray = []
	for item_id in dig_drops:
		Inventory.add_item(item_id, dig_drops[item_id])
		gained.append("+%d %s" % [dig_drops[item_id], Items.display_name(item_id)])
	_spawn_floating_text(cell, " ".join(gained), Color(0.9, 0.8, 0.6))
	_set_ground(cell, "o")
	_maybe_flood(cell)
	return true

# Yeni cukur suya komsuysa su, bagli tum cukurlara yayilir (kanal!).
func _maybe_flood(start_cell: Vector2i) -> void:
	var touches_water := false
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _ground_char.get(start_cell + offset, "") == "~":
			touches_water = true
			break
	if not touches_water:
		return
	var queue: Array[Vector2i] = [start_cell]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if _ground_char.get(cell, "") != "o":
			continue
		_set_ground(cell, "~")
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if _ground_char.get(cell + offset, "") == "o":
				queue.append(cell + offset)

# --- Sandik ------------------------------------------------------------

func _close_chest() -> void:
	_open_chest = NO_CELL
	hud.close_chest()

func _on_chest_transfer(item_id: String, to_chest: bool) -> void:
	if _open_chest == NO_CELL:
		return
	var chest: Dictionary = _chests.get(_open_chest, {})
	if to_chest:
		var amount := Inventory.get_count(item_id)
		if amount <= 0:
			return
		Inventory.remove_item(item_id, amount)
		chest[item_id] = int(chest.get(item_id, 0)) + amount
	else:
		var amount: int = int(chest.get(item_id, 0))
		if amount <= 0:
			return
		chest.erase(item_id)
		Inventory.add_item(item_id, amount)
	_chests[_open_chest] = chest
	hud.show_chest(chest)

func _on_chest_dismantle() -> void:
	if _open_chest == NO_CELL:
		return
	if not _chests.get(_open_chest, {}).is_empty():
		return
	var cell := _open_chest
	_close_chest()
	_chests.erase(cell)
	var cost: Dictionary = Recipes.BUILD_RECIPES["sandik"]["cost"]
	for item_id in cost:
		Inventory.add_item(item_id, cost[item_id])
	_set_object(cell, "")

# --- Yardimcilar -------------------------------------------------------

func _compute_action_state() -> String:
	if _dig_mode:
		return "dig"
	if _selected_recipe_id != "":
		return "build"
	var player_cell := _get_player_cell()
	for oy in [-1, 0, 1]:
		for ox in [-1, 0, 1]:
			if ox == 0 and oy == 0:
				continue
			var ch: String = _object_char.get(player_cell + Vector2i(ox, oy), "")
			if ch != "" and OBJECT_DEFS[ch].has("drops"):
				return "gather"
	return "idle"

func _spawn_floating_text(cell: Vector2i, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.z_index = 100
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	label.position = ground_tile_map.map_to_local(cell) + Vector2(-14, -34)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 16.0, 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)

func _is_editable_cell(cell: Vector2i) -> bool:
	return cell.x > 0 and cell.y > 0 \
		and cell.x < _map_width - 1 and cell.y < _map_height - 1

func _is_near_object(target_ch: String) -> bool:
	var player_cell := _get_player_cell()
	for oy in [-1, 0, 1]:
		for ox in [-1, 0, 1]:
			if ox == 0 and oy == 0:
				continue
			if _object_char.get(player_cell + Vector2i(ox, oy), "") == target_ch:
				return true
	return false

func _get_player_cell() -> Vector2i:
	return ground_tile_map.local_to_map(ground_tile_map.to_local(player.global_position))

# --- Kayit / yukleme ---------------------------------------------------

func _save_game() -> void:
	var ground_rows: PackedStringArray = []
	var object_rows: PackedStringArray = []
	for y in _map_height:
		var g_row := ""
		var o_row := ""
		for x in _map_width:
			g_row += _ground_char.get(Vector2i(x, y), ".")
			o_row += _object_char.get(Vector2i(x, y), "-")
		ground_rows.append(g_row)
		object_rows.append(o_row)

	var chest_data: Dictionary = {}
	for cell in _chests:
		chest_data["%d,%d" % [cell.x, cell.y]] = _chests[cell]

	SaveManager.save_data({
		"version": 2,
		"w": _map_width,
		"h": _map_height,
		"ground_rows": ground_rows,
		"object_rows": object_rows,
		"chests": chest_data,
		"inventory": Inventory.items,
		"hunger": Hunger.value,
		"respawn": [_respawn_cell.x, _respawn_cell.y],
		"player": [player.global_position.x, player.global_position.y],
	})

func _load_game() -> void:
	var data := SaveManager.load_data()
	if data.is_empty():
		return
	if int(data.get("w", 0)) != _map_width or int(data.get("h", 0)) != _map_height:
		return

	if int(data.get("version", 1)) >= 2:
		var g_rows: Array = data.get("ground_rows", [])
		var o_rows: Array = data.get("object_rows", [])
		for y in g_rows.size():
			for x in g_rows[y].length():
				var cell := Vector2i(x, y)
				var g_ch: String = g_rows[y][x]
				if GROUND_DEFS.has(g_ch) and _ground_char.get(cell, "") != g_ch:
					_set_ground(cell, g_ch)
				var o_ch: String = o_rows[y][x]
				if o_ch == "-":
					if _object_char.has(cell):
						_set_object(cell, "")
				elif OBJECT_DEFS.has(o_ch) and _object_char.get(cell, "") != o_ch:
					_set_object(cell, o_ch)
	else:
		# Eski (v1) kayit: tek katmanli satirlari ikiye ayir
		var rows: Array = data.get("rows", [])
		for y in rows.size():
			for x in rows[y].length():
				var cell := Vector2i(x, y)
				var ch: String = rows[y][x]
				if OBJECT_DEFS.has(ch):
					if _object_char.get(cell, "") != ch:
						_set_object(cell, ch)
				elif GROUND_DEFS.has(ch):
					if _object_char.has(cell):
						_set_object(cell, "")
					if _ground_char.get(cell, "") != ch:
						_set_ground(cell, ch)
		# v1'de yapilarin altindaki zemin floor_under'da tutuluyordu
		for key in data.get("floor_under", {}):
			var parts: PackedStringArray = key.split(",")
			var cell := Vector2i(int(parts[0]), int(parts[1]))
			var g_ch: String = data["floor_under"][key]
			if GROUND_DEFS.has(g_ch):
				_set_ground(cell, g_ch)

	for key in data.get("chests", {}):
		var parts: PackedStringArray = key.split(",")
		var contents: Dictionary = {}
		for item_id in data["chests"][key]:
			contents[item_id] = int(data["chests"][key][item_id])
		_chests[Vector2i(int(parts[0]), int(parts[1]))] = contents

	Inventory.set_items(data.get("inventory", {}))
	Hunger.value = float(data.get("hunger", Hunger.MAX_VALUE))
	Hunger.changed.emit()

	var respawn: Array = data.get("respawn", [])
	if respawn.size() == 2:
		_respawn_cell = Vector2i(int(respawn[0]), int(respawn[1]))
	var pos: Array = data.get("player", [])
	if pos.size() == 2:
		player.global_position = Vector2(float(pos[0]), float(pos[1]))
