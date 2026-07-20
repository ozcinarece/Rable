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
const Items = preload("res://scripts/items.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const PARTICLE_TEX := preload("res://assets/ui/particle.png")
const BuildPreviewScript = preload("res://scripts/build_preview.gd")
const GroundItemScript = preload("res://scripts/ground_item.gd")

const HARVEST_REACH_TILES: int = 1
const REGROW_SECONDS: float = 60.0
const SAVE_INTERVAL: float = 8.0
const NO_CELL := Vector2i(-999, -999)

# Zemin tanimlari. "dig": kurekle kazilabilir, verdigi esya.
const GROUND_DEFS: Dictionary = {
	".": {"texture": "res://assets/tiles/grass.png", "solid": false, "dig": {"toprak": 1}},
	"d": {"texture": "res://assets/tiles/dirt.png", "solid": false, "dig": {"toprak": 1}},
	"s": {"texture": "res://assets/tiles/sand.png", "solid": false, "dig": {"kum": 1}},
	"~": {"texture": "res://assets/tiles/water_anim.png", "solid": true},
	"o": {"texture": "res://assets/tiles/cukur.png", "solid": true},
	# Ahsap doseme: evin zemini; kazilirsa zemin esyasi iade edilir
	"f": {"texture": "res://assets/tiles/zemin.png", "solid": false,
			"dig": {"zemin": 1}, "dig_to": "d"},
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
	# Yapilar sokulunce kendi ESYASINI dusurur (tekrar yerlestirilebilir)
	"W": {"texture": "res://assets/tiles/wood_wall.png",
			"drops": {"ahsap_duvar": 1}, "hits": 2},
	"K": {"texture": "res://assets/tiles/stone_wall.png",
			"drops": {"tas_duvar": 1}, "hits": 3},
	"B": {"texture": "res://assets/tiles/tezgah.png",
			"drops": {"tezgah": 1}, "hits": 2},
	"E": {"texture": "res://assets/tiles/ev.png",
			"drops": {"kamp_evi": 1}, "hits": 3},
	"m": {"texture": "res://assets/tiles/bush_full.png",
			"drops": {"meyve": 2}, "hits": 1, "becomes_object": "n"},
	"n": {"texture": "res://assets/tiles/bush_empty.png"},
	"S": {"texture": "res://assets/tiles/sandik.png"},
	# Diken tuzagi: carpismasiz (yaratiklar ustunden gecer ve hasar alir)
	"Z": {"texture": "res://assets/tiles/tuzak.png", "no_collision": true,
			"drops": {"tuzak": 1}, "hits": 1},
	# Kapi: oyuncu gecer, yaratik gecemez (carpisma katmani 2)
	"D": {"texture": "res://assets/tiles/kapi.png", "enemy_only_collision": true,
			"drops": {"kapi": 1}, "hits": 2},
	# Yatak: yeniden dogma noktasi; gece dokununca sabaha uyunur
	"Y": {"texture": "res://assets/tiles/yatak.png",
			"drops": {"yatak": 1}, "hits": 2},
	# Ekin asamalari (carpismasiz): c (filiz) -> g (gelisen) -> r (olgun)
	# NOT: kayit formati hucre basina tek karakter kullanir
	"c": {"texture": "res://assets/tiles/ekin1.png", "no_collision": true,
			"drops": {"tohum": 1}, "hits": 1},
	"g": {"texture": "res://assets/tiles/ekin2.png", "no_collision": true,
			"drops": {"tohum": 1}, "hits": 1},
	"r": {"texture": "res://assets/tiles/ekin3.png", "no_collision": true,
			"drops": {"meyve": 3, "tohum": 1}, "hits": 1},
}

const GROWTH_SECONDS: float = 75.0  # ekinin her asamasinin suresi (sulu: yarisi)

const TRAP_DAMAGE: int = 15
const TRAP_MAX_USES: int = 5
const ATTACK_RANGE: float = 56.0  # oyuncunun vurus menzili (piksel)

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
var _held_item: String = ""       # oyuncunun eline aldigi esya
var _move_mode: bool = false      # tasima modu (HUD'daki Tasi butonu)
var _move_source: Vector2i = NO_CELL  # tasinmak uzere secilen yapinin hucresi
var _respawn_cell: Vector2i = Vector2i.ZERO
var _save_timer: float = 0.0
var _map_width: int = 0
var _map_height: int = 0
var _enemies: Array = []           # sahnedeki yaratiklar
var _trap_uses: Dictionary = {}    # tuzak hucresi -> kalan kullanim
var _crops: Dictionary = {}        # ekin hucresi -> asamaya kalan sure
var _night_tint: CanvasModulate
var _preview: BuildPreviewScript  # grid + yerlestirme onizlemesi
var _ground_items: Array = []  # yere birakilmis esyalar (Area2D)

func _ready() -> void:
	ground_tile_map.tile_set = _build_ground_tile_set()
	_build_map_from_ascii()
	_load_game()
	player.world_tapped.connect(_on_player_world_tapped)
	hud.action_pressed.connect(_on_action_pressed)
	hud.drop_item_requested.connect(_on_drop_item_requested)
	hud.chest_transfer_requested.connect(_on_chest_transfer)
	hud.chest_dismantle_requested.connect(_on_chest_dismantle)
	hud.chest_closed.connect(func(): _open_chest = NO_CELL)
	hud.move_toggled.connect(_on_move_toggled)
	hud.hold_requested.connect(_on_hold_requested)
	_preview = BuildPreviewScript.new()
	add_child(_preview)
	move_child(_preview, 1)  # GroundTileMap'in hemen ustune cizilsin
	# Gece karartmasi (HUD'i etkilemez, sadece dunyayi)
	_night_tint = CanvasModulate.new()
	_night_tint.color = Color.WHITE
	add_child(_night_tint)
	DayNight.night_started.connect(_on_night_started)
	DayNight.day_started.connect(_on_day_started)
	Health.died.connect(_on_player_died)
	if DayNight.is_night:
		_night_tint.color = Color(0.42, 0.46, 0.66)
		_spawn_wave()

func _process(delta: float) -> void:
	hud.set_action_state(_compute_action_state())
	_update_build_preview()
	Crafting.near_station = _is_near_object("B")
	if _open_chest != NO_CELL:
		var diff := (_open_chest - _get_player_cell()).abs()
		if maxi(diff.x, diff.y) > 1:
			_close_chest()
	# Eldeki alet envanterden ciktiysa (sandiga kondu vb.) eli bosalt
	if _held_item != "" and Inventory.get_count(_held_item) <= 0:
		_on_hold_requested("")
	_tick_regrow(delta)
	_tick_crops(delta)
	_tick_traps()
	_tick_ground_items()
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
		if ch == "~":
			# Su: 4 kareli dalga animasyonu (kareler atlasda yan yana)
			source.texture = load("res://assets/tiles/water_anim.png")
			source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
			source.create_tile(Vector2i(0, 0))
			source.set_tile_animation_frames_count(Vector2i(0, 0), 4)
			for frame in 4:
				source.set_tile_animation_frame_duration(Vector2i(0, 0), frame, 0.3)
		else:
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
	_crops.erase(cell)
	if ch == "":
		return
	_object_char[cell] = ch
	var body := StaticBody2D.new()
	body.position = ground_tile_map.map_to_local(cell)
	if not OBJECT_DEFS[ch].get("no_collision", false):
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(30, 30)
		shape.shape = rect
		body.add_child(shape)
		if OBJECT_DEFS[ch].get("enemy_only_collision", false):
			body.collision_layer = 2  # oyuncu gecer, yaratik takilir
	var sprite := Sprite2D.new()
	sprite.texture = load(OBJECT_DEFS[ch]["texture"])
	sprite.offset = Vector2(0, -16)  # 32x64 gorselin tabani hucreye oturur
	body.add_child(sprite)
	ysort.add_child(body)
	_object_nodes[cell] = body
	if ch == "n":
		_regrow[cell] = REGROW_SECONDS
	elif ch == "c" or ch == "g":
		_crops[cell] = GROWTH_SECONDS

func _tick_regrow(delta: float) -> void:
	var ready_cells: Array[Vector2i] = []
	for cell in _regrow:
		_regrow[cell] -= delta
		if _regrow[cell] <= 0.0:
			ready_cells.append(cell)
	for cell in ready_cells:
		_set_object(cell, "m")

# Ekinleri buyutur; 4 komsusunda su varsa 2 kat hizli.
func _tick_crops(delta: float) -> void:
	var ready_cells: Array[Vector2i] = []
	for cell in _crops:
		var speed := 1.0
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if _ground_char.get(cell + offset, "") == "~":
				speed = 2.0
				break
		_crops[cell] -= delta * speed
		if _crops[cell] <= 0.0:
			ready_cells.append(cell)
	for cell in ready_cells:
		var ch: String = _object_char.get(cell, "")
		if ch == "c":
			_set_object(cell, "g")
		elif ch == "g":
			_set_object(cell, "r")
			_spawn_floating_text(cell, "Ekin olgunlasti!", Color(0.8, 1.0, 0.7))

# --- Girdi isleme ------------------------------------------------------

func _on_player_world_tapped(world_pos: Vector2) -> void:
	var cell := ground_tile_map.local_to_map(ground_tile_map.to_local(world_pos))
	var player_cell := _get_player_cell()
	var diff := (cell - player_cell).abs()
	if maxi(diff.x, diff.y) > HARVEST_REACH_TILES:
		return
	if _move_mode:
		_handle_move_tap(cell, player_cell)
	elif _object_char.get(cell, "") == "S":
		_open_chest = cell
		hud.show_chest(_chests.get(cell, {}))
	elif _object_char.get(cell, "") == "Y":
		_try_sleep(cell)
	elif _try_attack(world_pos):
		pass  # yakindaki yaratiga vuruldu
	elif _ground_char.get(cell, "") == "~" and not _object_char.has(cell):
		Thirst.drink()
		_spawn_floating_text(cell, "Su içtin!", Color(0.6, 0.85, 1.0))
	elif _can_place_held(cell, player_cell):
		_try_place_held(cell, player_cell)
	elif _held_item == "kurek" and not _object_char.has(cell):
		_try_dig(cell)
	else:
		_try_harvest(cell)

func _on_action_pressed() -> void:
	var player_cell := _get_player_cell()
	var facing_offset := Vector2i(player.facing.round())
	if facing_offset == Vector2i.ZERO:
		facing_offset = Vector2i(0, 1)
	if _move_mode:
		_handle_move_tap(player_cell + facing_offset, player_cell)
		return
	if _try_attack(player.global_position):
		return
	if _held_item == "kurek" and _try_dig(player_cell + facing_offset):
		return
	if _try_place_held(player_cell + facing_offset, player_cell):
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

# Eldeki esya bu hucreye yerlestirilebilir/uygulanabilir mi?
# Yapilar bos yurunebilir zemine; tohum topraga; toprak cukura.
func _can_place_held(cell: Vector2i, player_cell: Vector2i) -> bool:
	if _held_item == "" or Inventory.get_count(_held_item) <= 0:
		return false
	if not _is_editable_cell(cell) or cell == player_cell:
		return false
	var ground: String = _ground_char.get(cell, "")
	if _held_item == "tohum":
		return ground == "d" and not _object_char.has(cell)
	if _held_item == "toprak":
		return ground == "o" and not _object_char.has(cell)
	var tile: String = Items.PLACEABLE.get(_held_item, "")
	if tile == "" or _object_char.has(cell):
		return false
	if ground == "" or GROUND_DEFS[ground]["solid"]:
		return false
	if tile == "f" and ground == "f":
		return false  # ayni zemine tekrar doseme olmaz
	return true

func _try_place_held(cell: Vector2i, player_cell: Vector2i) -> bool:
	if not _can_place_held(cell, player_cell):
		return false
	Inventory.remove_item(_held_item, 1)
	if _held_item == "tohum":
		_set_object(cell, "c")
		return true
	if _held_item == "toprak":
		_set_ground(cell, "d")
		return true
	var tile: String = Items.PLACEABLE[_held_item]
	if GROUND_DEFS.has(tile):
		_set_ground(cell, tile)
	else:
		_set_object(cell, tile)
		if tile == "E" or tile == "Y":
			_respawn_cell = cell
			_spawn_floating_text(cell, "Yeniden dogma noktasi!", Color(0.75, 0.9, 1.0))
	return true

func _try_harvest(cell: Vector2i) -> bool:
	if not _is_editable_cell(cell):
		return false
	var ch: String = _object_char.get(cell, "")
	if ch == "" or not OBJECT_DEFS[ch].has("drops"):
		return false

	var def: Dictionary = OBJECT_DEFS[ch]
	var hits_needed: int = def.get("hits", 1)
	if def.has("tool") and _held_item == def["tool"]["item"]:
		hits_needed = def["tool"]["hits"]
	var damage: int = _cell_damage.get(cell, 0) + 1
	if damage < hits_needed:
		_cell_damage[cell] = damage
		_spawn_floating_text(cell, "%d/%d" % [damage, hits_needed], Color(1.0, 0.95, 0.6))
		return true
	if not Inventory.can_add_all(def["drops"]):
		_spawn_floating_text(cell, "Envanter dolu!", Color(1, 0.6, 0.6))
		return false
	_cell_damage.erase(cell)

	var gained: PackedStringArray = []
	for item_id in def["drops"]:
		Inventory.add_item(item_id, def["drops"][item_id])
		gained.append("+%d %s" % [def["drops"][item_id], Items.display_name(item_id)])
	_spawn_floating_text(cell, " ".join(gained), Color(0.7, 1.0, 0.7))
	_spawn_burst(cell, Color(0.6, 0.9, 0.5))

	if def.has("becomes_object"):
		_set_object(cell, def["becomes_object"])
	else:
		_set_object(cell, "")
		if def.has("ground_becomes"):
			_set_ground(cell, def["ground_becomes"])
	return true

func _can_dig(cell: Vector2i) -> bool:
	if not _is_editable_cell(cell):
		return false
	if _object_char.has(cell):
		return false  # ustunde nesne varken kazilamaz
	var ground: String = _ground_char.get(cell, "")
	if ground == "" or not GROUND_DEFS[ground].has("dig"):
		return false
	return _held_item == "kurek"

func _try_dig(cell: Vector2i) -> bool:
	if not _can_dig(cell):
		return false
	var ground: String = _ground_char.get(cell, "")
	var dig_drops: Dictionary = GROUND_DEFS[ground]["dig"]
	if not Inventory.can_add_all(dig_drops):
		_spawn_floating_text(cell, "Envanter dolu!", Color(1, 0.6, 0.6))
		return false

	var gained: PackedStringArray = []
	for item_id in dig_drops:
		Inventory.add_item(item_id, dig_drops[item_id])
		gained.append("+%d %s" % [dig_drops[item_id], Items.display_name(item_id)])
	_spawn_floating_text(cell, " ".join(gained), Color(0.9, 0.8, 0.6))
	_spawn_burst(cell, Color(0.62, 0.45, 0.28))
	var new_ground: String = GROUND_DEFS[ground].get("dig_to", "o")
	_set_ground(cell, new_ground)
	if new_ground == "o":
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

# --- Eline alma / tasima -------------------------------------------------

## Verilen esyayi eline alir; bos string eli bosaltir.
func _on_hold_requested(item_id: String) -> void:
	if item_id != "" and Inventory.get_count(item_id) <= 0:
		return
	_held_item = item_id
	player.set_held_item("" if item_id == "" else Items.ITEMS[item_id]["icon"])
	hud.set_held_item(item_id)

## Tasinabilir yapilar (dogal seyler tasinamaz)
const MOVABLE: Array[String] = ["W", "K", "B", "E", "S", "Z", "D", "Y"]

func _on_move_toggled(enabled: bool) -> void:
	_move_mode = enabled
	if not enabled and _move_source != NO_CELL:
		# Bekleyen secim iptal: yari saydamligi kaldir
		if _object_nodes.has(_move_source):
			_object_nodes[_move_source].modulate = Color.WHITE
		_move_source = NO_CELL

# Tasinan yapi bu hucreye birakilabilir mi?
func _can_drop_move(cell: Vector2i, player_cell: Vector2i) -> bool:
	if not _is_editable_cell(cell) or cell == player_cell:
		return false
	if _object_char.has(cell):
		return false
	var ground: String = _ground_char.get(cell, "")
	return ground != "" and not GROUND_DEFS[ground]["solid"]

# Grid ve hedef hucre onizlemesini gunceller (her kare).
func _update_build_preview() -> void:
	var player_cell := _get_player_cell()
	var placing := _is_holding_placeable()
	var active := _move_mode or placing or _held_item == "kurek"
	_preview.grid_visible = active
	_preview.center_cell = player_cell
	var facing_offset := Vector2i(player.facing.round())
	if facing_offset == Vector2i.ZERO:
		facing_offset = Vector2i(0, 1)
	var target := player_cell + facing_offset
	if placing:
		_preview.preview_cell = target
		_preview.preview_ok = _can_place_held(target, player_cell)
	elif _held_item == "kurek":
		_preview.preview_cell = target
		_preview.preview_ok = _can_dig(target)
	elif _move_mode and _move_source != NO_CELL:
		_preview.preview_cell = target
		_preview.preview_ok = _can_drop_move(target, player_cell)
	else:
		_preview.preview_cell = Vector2i(-999, -999)
	_preview.queue_redraw()

# Eldeki esya yerlestirilebilir bir sey mi? (yapi / tohum / toprak)
func _is_holding_placeable() -> bool:
	return _held_item != "" and (Items.PLACEABLE.has(_held_item)
			or _held_item == "tohum" or _held_item == "toprak")

# Tasima modunda dokunma: once yapiyi sec, sonra bos zemine birak.
func _handle_move_tap(cell: Vector2i, player_cell: Vector2i) -> void:
	if _move_source == NO_CELL:
		# Secim: tasinabilir bir yapiya dokun
		var ch: String = _object_char.get(cell, "")
		if ch == "" or not MOVABLE.has(ch) or not _is_editable_cell(cell):
			return
		_move_source = cell
		_object_nodes[cell].modulate = Color(1, 1, 1, 0.5)
		_spawn_floating_text(cell, "Seçildi - boş zemine dokun", Color(0.8, 0.9, 1.0))
		return
	if cell == _move_source:
		return
	if not _can_drop_move(cell, player_cell):
		return

	var moving_ch: String = _object_char.get(_move_source, "")
	var source := _move_source
	_move_source = NO_CELL
	_set_object(source, "")
	_set_object(cell, moving_ch)
	# Sandik iceriden tasinir, ev respawn noktasini beraberinde goturur
	if moving_ch == "S" and _chests.has(source):
		_chests[cell] = _chests[source]
		_chests.erase(source)
	if moving_ch == "E" and _respawn_cell == source:
		_respawn_cell = cell
	_spawn_floating_text(cell, "Taşındı", Color(0.8, 1.0, 0.8))

# --- Gece / savas --------------------------------------------------------

func _on_night_started() -> void:
	create_tween().tween_property(_night_tint, "color", Color(0.42, 0.46, 0.66), 3.0)
	_spawn_wave()

func _on_day_started() -> void:
	create_tween().tween_property(_night_tint, "color", Color.WHITE, 3.0)
	# Gun dogunca kalan yaratiklar yok olur
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_enemies.clear()

# Gece dalgasi: gun sayisina gore artan sayida yaratik, harita
# kenarlarina yakin yurunebilir hucrelerde dogar.
func _spawn_wave() -> void:
	var count := mini(2 + DayNight.day, 10)
	for i in count:
		var cell := _find_spawn_cell()
		if cell == NO_CELL:
			continue
		var enemy = EnemyScript.new()
		enemy.target = player
		enemy.position = ground_tile_map.map_to_local(cell)
		ysort.add_child(enemy)
		_enemies.append(enemy)
	_spawn_floating_text(_get_player_cell(), "Gece coktu... %d yaratik!" % count, Color(1, 0.6, 1))

# Kenarlara yakin, bos ve yurunebilir bir dogum hucresi arar.
func _find_spawn_cell() -> Vector2i:
	for attempt in 40:
		var edge := randi() % 4
		var x: int
		var y: int
		match edge:
			0: x = 1 + randi() % (_map_width - 2); y = 1 + randi() % 3
			1: x = 1 + randi() % (_map_width - 2); y = _map_height - 2 - randi() % 3
			2: x = 1 + randi() % 3; y = 1 + randi() % (_map_height - 2)
			_: x = _map_width - 2 - randi() % 3; y = 1 + randi() % (_map_height - 2)
		var cell := Vector2i(x, y)
		if _object_char.has(cell):
			continue
		var ground: String = _ground_char.get(cell, "")
		if ground == "" or GROUND_DEFS[ground]["solid"]:
			continue
		return cell
	return NO_CELL

# Hedef noktaya yakin bir yaratik varsa vurur; vurus yapildiysa true.
func _try_attack(world_pos: Vector2) -> bool:
	var best = null
	var best_distance := 40.0
	for enemy in _enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(player.global_position) > ATTACK_RANGE:
			continue  # oyuncunun menzili disinda
		var d: float = enemy.global_position.distance_to(world_pos)
		if d < best_distance:
			best_distance = d
			best = enemy
	if best == null:
		return false
	var damage := 30 if _held_item == "mizrak" else 10
	if best.hurt(damage, player.global_position):
		_kill_enemy(best)
	return true

func _kill_enemy(enemy) -> void:
	var cell := ground_tile_map.local_to_map(ground_tile_map.to_local(enemy.global_position))
	_spawn_floating_text(cell, "Yok oldu!", Color(1, 0.8, 1))
	_spawn_burst(cell, Color(0.7, 0.4, 0.85))
	_enemies.erase(enemy)
	enemy.queue_free()

# Tuzak hucresindeki yaratiklara hasar verir; tuzak 5 kullanimda kirilir.
func _tick_traps() -> void:
	for enemy in _enemies.duplicate():
		if not is_instance_valid(enemy):
			_enemies.erase(enemy)
			continue
		var cell := ground_tile_map.local_to_map(ground_tile_map.to_local(enemy.global_position))
		if _object_char.get(cell, "") != "Z":
			continue
		if enemy.trap_cooldown > 0.0:
			continue
		enemy.trap_cooldown = 0.5
		if enemy.hurt(TRAP_DAMAGE, enemy.global_position + Vector2(randf() - 0.5, 1)):
			_kill_enemy(enemy)
		_trap_uses[cell] = int(_trap_uses.get(cell, 0)) + 1
		if _trap_uses[cell] >= TRAP_MAX_USES:
			_trap_uses.erase(cell)
			_set_object(cell, "")
			_spawn_floating_text(cell, "Tuzak kirildi", Color(1, 0.8, 0.6))

# Yatak: gece dokununca sabaha uyur, biraz can yeniler.
func _try_sleep(cell: Vector2i) -> void:
	if not DayNight.is_night:
		_spawn_floating_text(cell, "Sadece gece uyuyabilirsin", Color(0.9, 0.9, 0.7))
		return
	DayNight.sleep_to_morning()
	Health.heal(30.0)
	_spawn_floating_text(cell, "Sabah oldu!", Color(1, 0.95, 0.6))

# Olum: kampta yeniden dogus
func _on_player_died() -> void:
	player.global_position = ground_tile_map.map_to_local(_respawn_cell)
	Health.reset()
	Hunger.eat(25.0)
	Thirst.drink()
	_spawn_floating_text(_respawn_cell, "Bayıldın! Kampta uyandın.", Color(1, 0.7, 0.7))

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
		if not Inventory.can_add(item_id, amount):
			hud.show_chest(chest, "Envanter dolu!")
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
	if not Inventory.can_add("sandik", 1):
		hud.show_chest({}, "Envanter dolu!")
		return
	var cell := _open_chest
	_close_chest()
	_chests.erase(cell)
	Inventory.add_item("sandik", 1)
	_set_object(cell, "")

# --- Yere birakilan esyalar ---------------------------------------------

## HUD bildirir: envanter slotu panel disina suruklendi -> esya yere.
func _on_drop_item_requested(slot_index: int) -> void:
	var content: Dictionary = Inventory.clear_slot(slot_index)
	if content.is_empty():
		return
	var facing := player.facing.normalized()
	if facing == Vector2.ZERO:
		facing = Vector2.DOWN
	var pos := player.global_position + facing * 30.0
	_spawn_ground_item(pos, content["id"], content["count"])
	_spawn_floating_text(_get_player_cell(), "Yere birakildi", Color(0.9, 0.85, 0.7))

func _spawn_ground_item(pos: Vector2, item_id: String, count: int) -> void:
	var area = GroundItemScript.new()
	area.position = pos
	ysort.add_child(area)
	area.setup(item_id, count, Items.ITEMS[item_id]["icon"])
	area.retry_cooldown = 1.0  # yeni birakilan esya hemen geri toplanmasin
	_ground_items.append(area)

# Oyuncu yerdeki esyanin ustundeyse toplar (envanterde yer varsa).
# Her kare cagrilir; envanter doluysa kisa araliklarla yeniden dener.
func _tick_ground_items() -> void:
	for area in _ground_items.duplicate():
		if not is_instance_valid(area):
			_ground_items.erase(area)
			continue
		if area.retry_cooldown > 0.0 or not area.overlaps_body(player):
			continue
		if not Inventory.can_add(area.item_id, area.count):
			area.retry_cooldown = 1.5
			_spawn_floating_text(_get_player_cell(), "Envanter dolu!", Color(1, 0.6, 0.6))
			continue
		Inventory.add_item(area.item_id, area.count)
		_spawn_floating_text(_get_player_cell(), "+%d %s" % [area.count,
				Items.display_name(area.item_id)], Color(0.7, 1.0, 0.7))
		_ground_items.erase(area)
		area.queue_free()

# --- Yardimcilar -------------------------------------------------------

func _compute_action_state() -> String:
	if _move_mode:
		return "move"
	for enemy in _enemies:
		if is_instance_valid(enemy) \
				and enemy.global_position.distance_to(player.global_position) <= ATTACK_RANGE:
			return "attack_spear" if _held_item == "mizrak" else "attack"
	if _is_holding_placeable():
		return "build"
	if _held_item == "kurek":
		return "dig"
	var player_cell := _get_player_cell()
	for oy in [-1, 0, 1]:
		for ox in [-1, 0, 1]:
			if ox == 0 and oy == 0:
				continue
			var ch: String = _object_char.get(player_cell + Vector2i(ox, oy), "")
			if ch != "" and OBJECT_DEFS[ch].has("drops"):
				return "gather"
	return "idle"

# Kisa parcacik patlamasi (toplama/vurma geri bildirimi)
func _spawn_burst(cell: Vector2i, color: Color) -> void:
	var center := ground_tile_map.map_to_local(cell)
	for i in 6:
		var bit := Sprite2D.new()
		bit.texture = PARTICLE_TEX
		bit.modulate = color
		bit.position = center
		bit.z_index = 90
		add_child(bit)
		var target := center + Vector2.RIGHT.rotated(randf() * TAU) * (10.0 + randf() * 16.0)
		var tween := create_tween()
		tween.tween_property(bit, "position", target, 0.35)
		tween.parallel().tween_property(bit, "modulate:a", 0.0, 0.35)
		tween.tween_callback(bit.queue_free)

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

	var ground_item_data: Array = []
	for area in _ground_items:
		if is_instance_valid(area):
			ground_item_data.append({"x": area.position.x, "y": area.position.y,
					"id": area.item_id, "count": area.count})

	SaveManager.save_data({
		"version": 3,
		"w": _map_width,
		"h": _map_height,
		"ground_rows": ground_rows,
		"object_rows": object_rows,
		"chests": chest_data,
		"inventory_v3": Inventory.to_save(),
		"craft_queue": Crafting.to_save(),
		"ground_items": ground_item_data,
		"hunger": Hunger.value,
		"thirst": Thirst.value,
		"respawn": [_respawn_cell.x, _respawn_cell.y],
		"player": [player.global_position.x, player.global_position.y],
		"held": _held_item,
		"day": DayNight.day,
		"is_night": DayNight.is_night,
		"cycle_elapsed": DayNight.elapsed,
		"hp": Health.value,
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

	if data.has("inventory_v3"):
		Inventory.load_save(data["inventory_v3"])
	else:
		# Eski kayit: {"esya": adet} sozlugunden slotlari doldur
		Inventory.load_from_dict(data.get("inventory", {}))
	Crafting.load_save(data.get("craft_queue", []))
	for entry in data.get("ground_items", []):
		if entry is Dictionary and Items.ITEMS.has(entry.get("id", "")):
			_spawn_ground_item(Vector2(float(entry["x"]), float(entry["y"])),
					String(entry["id"]), int(entry["count"]))
	Hunger.value = float(data.get("hunger", Hunger.MAX_VALUE))
	Hunger.changed.emit()
	Thirst.value = float(data.get("thirst", Thirst.MAX_VALUE))
	Thirst.changed.emit()

	var respawn: Array = data.get("respawn", [])
	if respawn.size() == 2:
		_respawn_cell = Vector2i(int(respawn[0]), int(respawn[1]))
	var pos: Array = data.get("player", [])
	if pos.size() == 2:
		player.global_position = Vector2(float(pos[0]), float(pos[1]))
	var held: String = data.get("held", "")
	if held != "" and Inventory.get_count(held) > 0:
		_on_hold_requested(held)
	DayNight.load_state(int(data.get("day", 1)), bool(data.get("is_night", false)),
			float(data.get("cycle_elapsed", 0.0)))
	Health.value = float(data.get("hp", Health.MAX_VALUE))
	Health.changed.emit()
