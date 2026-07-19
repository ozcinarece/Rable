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
#   tool:    dogru alet envanterdeyse vurus sayisi dusurulur
const TILE_DEFS: Dictionary = {
	".": {"texture": "res://assets/tiles/grass.png", "solid": false},
	"d": {"texture": "res://assets/tiles/dirt.png", "solid": false},
	"s": {"texture": "res://assets/tiles/sand.png", "solid": false},
	"~": {"texture": "res://assets/tiles/water.png", "solid": true},
	"#": {"texture": "res://assets/tiles/stone.png", "solid": true,
			"drops": {"tas": 2}, "becomes": "d", "hits": 4,
			"tool": {"item": "kazma", "hits": 2}},
	"T": {"texture": "res://assets/tiles/tree.png", "solid": true,
			"drops": {"odun": 3, "yaprak": 2}, "becomes": ".", "hits": 3,
			"tool": {"item": "balta", "hits": 1}},
	# Insa edilebilir yapilar (sokulunce maliyeti tamamen iade edilir)
	"W": {"texture": "res://assets/tiles/wood_wall.png", "solid": true,
			"drops": {"kalas": 2}, "becomes": ".", "hits": 2},
	"K": {"texture": "res://assets/tiles/stone_wall.png", "solid": true,
			"drops": {"tas": 2}, "becomes": ".", "hits": 3},
	"B": {"texture": "res://assets/tiles/tezgah.png", "solid": true,
			"drops": {"kalas": 4, "cubuk": 2}, "becomes": ".", "hits": 2},
	"E": {"texture": "res://assets/tiles/ev.png", "solid": true,
			"drops": {"kalas": 6, "ip": 2, "yaprak": 4}, "becomes": ".", "hits": 3},
	# Meyve calisi: toplaninca bos caliya donusur, bir sure sonra yeniden buyur
	"m": {"texture": "res://assets/tiles/bush_full.png", "solid": true,
			"drops": {"meyve": 2}, "becomes": "n", "hits": 1},
	"n": {"texture": "res://assets/tiles/bush_empty.png", "solid": true},
	# Sandik: vurusla toplanamaz (esya kaybi olmasin); dokununca acilir,
	# sokme islemi sadece bos sandikta, panelin icindeki Sok butonuyla
	"S": {"texture": "res://assets/tiles/sandik.png", "solid": true},
}

## Bos calinin yeniden meyve vermesi icin gecen sure (saniye)
const REGROW_SECONDS: float = 60.0
## Otomatik kayit araligi (saniye)
const SAVE_INTERVAL: float = 8.0

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
var _respawn_cell: Vector2i = Vector2i.ZERO  # olum gelince (M5) burada dogacak
var _regrow: Dictionary = {}  # bos cali hucresi -> yeniden buyumeye kalan sure
var _save_timer: float = 0.0

## Sandik icerikleri: hucre -> {esya: adet}. Acik sandigin hucresi
## _open_chest'te tutulur; oyuncu uzaklasinca panel kapanir.
const NO_CELL := Vector2i(-999, -999)
var _chests: Dictionary = {}
var _open_chest: Vector2i = NO_CELL

func _ready() -> void:
	ground_tile_map.tile_set = _build_tile_set()
	_build_map_from_ascii()
	_load_game()
	player.world_tapped.connect(_on_player_world_tapped)
	hud.build_toggled.connect(_on_build_toggled)
	hud.action_pressed.connect(_on_action_pressed)
	hud.chest_transfer_requested.connect(_on_chest_transfer)
	hud.chest_dismantle_requested.connect(_on_chest_dismantle)
	hud.chest_closed.connect(func(): _open_chest = NO_CELL)

func _process(delta: float) -> void:
	# Aksiyon butonunun ikonunu duruma gore guncelle
	# (yumruk = bos, balta = yakinda toplanabilir sey var, cekic = insa modu)
	hud.set_action_state(_compute_action_state())
	# Tezgah tarifleri sadece tezgahin yanindayken uretilebilir
	Crafting.near_station = _is_near_tile("B")
	# Acik sandiktan uzaklasildiysa paneli kapat
	if _open_chest != NO_CELL:
		var diff := (_open_chest - _get_player_cell()).abs()
		if maxi(diff.x, diff.y) > 1:
			_close_chest()
	_tick_regrow(delta)
	# Otomatik kayit
	_save_timer += delta
	if _save_timer >= SAVE_INTERVAL:
		_save_timer = 0.0
		_save_game()

# Uygulama arka plana alinirken / kapanirken hemen kaydet
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()

# Bos calilarin sayacini isletir; suresi dolan yeniden meyve verir
func _tick_regrow(delta: float) -> void:
	var ready_cells: Array[Vector2i] = []
	for cell in _regrow:
		_regrow[cell] -= delta
		if _regrow[cell] <= 0.0:
			ready_cells.append(cell)
	for cell in ready_cells:
		_set_cell_char(cell, "m")

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
				_respawn_cell = Vector2i(x, y)
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
	elif _cell_char.get(cell, "") == "S":
		# Sandiga dokununca depolama paneli acilir
		_open_chest = cell
		hud.show_chest(_chests.get(cell, {}))
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

	# Kamp evi dikildiyse yeniden dogma noktasi artik burasi
	if recipe["tile"] == "E":
		_respawn_cell = cell
		_spawn_floating_text(cell, "Kamp kuruldu!", Color(0.75, 0.9, 1.0))
	return true

# Hedef hucreye bir vurus yapar; yeterince vurulduysa toplar.
func _try_harvest(cell: Vector2i) -> bool:
	if not _is_editable_cell(cell):
		return false

	var ch: String = _cell_char.get(cell, "")
	if ch == "" or not TILE_DEFS[ch].has("drops"):
		return false

	var def: Dictionary = TILE_DEFS[ch]

	# Coklu vurus: buyuk/sert seyler tek vurusta dusmez.
	# Dogru alet envanterdeyse cok daha az vurus yeter.
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

	# Insa edilmis bir yapiysa altindaki zemini geri getir,
	# dogal bir seyse (agac/tas) tanimdaki "becomes" karakterine donus
	var new_ch: String = def["becomes"]
	if _floor_under.has(cell):
		new_ch = _floor_under[cell]
		_floor_under.erase(cell)
	_set_cell_char(cell, new_ch)
	return true

# --- Sandik ------------------------------------------------------------

func _close_chest() -> void:
	_open_chest = NO_CELL
	hud.close_chest()

# Bir esyanin tum yiginini envanterden sandiga (veya tersine) tasir.
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
	hud.show_chest(chest)  # paneli guncel icerikle yeniden ciz

# Bos sandigi soker ve maliyetini iade eder.
func _on_chest_dismantle() -> void:
	if _open_chest == NO_CELL:
		return
	if not _chests.get(_open_chest, {}).is_empty():
		return  # ici dolu sandik sokulemez (esya kaybi olmasin)
	var cell := _open_chest
	_close_chest()
	_chests.erase(cell)
	var cost: Dictionary = Recipes.BUILD_RECIPES["sandik"]["cost"]
	for item_id in cost:
		Inventory.add_item(item_id, cost[item_id])
	var new_ch: String = "."
	if _floor_under.has(cell):
		new_ch = _floor_under[cell]
		_floor_under.erase(cell)
	_set_cell_char(cell, new_ch)

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

# Oyuncunun 8 komsusundan herhangi biri verilen karakter mi?
func _is_near_tile(target_ch: String) -> bool:
	var player_cell := _get_player_cell()
	for oy in [-1, 0, 1]:
		for ox in [-1, 0, 1]:
			if ox == 0 and oy == 0:
				continue
			if _cell_char.get(player_cell + Vector2i(ox, oy), "") == target_ch:
				return true
	return false

func _get_player_cell() -> Vector2i:
	return ground_tile_map.local_to_map(ground_tile_map.to_local(player.global_position))

# Bir hucrenin karakterini gunceller ve gorselini doser
func _set_cell_char(cell: Vector2i, ch: String) -> void:
	_cell_char[cell] = ch
	ground_tile_map.set_cell(0, cell, _char_to_source_id[ch], Vector2i(0, 0))
	# Bos cali olusunca yeniden buyume sayaci baslat
	if ch == "n":
		_regrow[cell] = REGROW_SECONDS
	elif _regrow.has(cell):
		_regrow.erase(cell)

# --- Kayit / yukleme ---------------------------------------------------

func _save_game() -> void:
	var rows: PackedStringArray = []
	for y in _map_height:
		var row := ""
		for x in _map_width:
			row += _cell_char.get(Vector2i(x, y), ".")
		rows.append(row)

	var floor_data: Dictionary = {}
	for cell in _floor_under:
		floor_data["%d,%d" % [cell.x, cell.y]] = _floor_under[cell]

	var chest_data: Dictionary = {}
	for cell in _chests:
		chest_data["%d,%d" % [cell.x, cell.y]] = _chests[cell]

	SaveManager.save_data({
		"version": 1,
		"w": _map_width,
		"h": _map_height,
		"rows": rows,
		"floor_under": floor_data,
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
	# Harita boyutu degistiyse (guncelleme sonrasi) eski kaydi yok say
	if int(data.get("w", 0)) != _map_width or int(data.get("h", 0)) != _map_height:
		return

	var rows: Array = data.get("rows", [])
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if TILE_DEFS.has(ch) and _cell_char.get(Vector2i(x, y), "") != ch:
				_set_cell_char(Vector2i(x, y), ch)

	for key in data.get("floor_under", {}):
		var parts: PackedStringArray = key.split(",")
		_floor_under[Vector2i(int(parts[0]), int(parts[1]))] = data["floor_under"][key]

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
