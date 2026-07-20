extends Node3D
## 3D dunya - Asama B1+B2 baslangici.
##
## - ASCII haritadan MultiMesh blok zemin + yer tutucu agac/kaya/cali
## - SABIT acili, oyuncuyu yumusakca takip eden kamera (aci degismez)
## - Kamera ayari: "Kamera" butonuyla acilan panelde yakinlik/aci
##   kaydiricilari + iki parmakla yakinlastirma (pinch)
## - Toplama: dokun ya da aksiyon butonu; 2D ile ayni vurus/dusurme
##   mantigi (balta/kazma bonusu eldeyken), cali yeniden buyur
## - Su kenarinda suya dokun: su ic (susuzluk)
##
## Oyun mantigi autoload'larda; HUD 3D ustunde 2D katman.

const MapData = preload("res://scripts/map_data.gd")
const Player3DScript = preload("res://scripts/player3d.gd")
const Items = preload("res://scripts/items.gd")

## Zemin turleri: renk + ust yuzeyin yuksekligi (0 = yuruyus seviyesi)
const GROUND_DEFS := {
	".": {"color": Color(0.46, 0.73, 0.36), "top": 0.0, "solid": false},
	"d": {"color": Color(0.60, 0.44, 0.29), "top": -0.02, "solid": false},
	"s": {"color": Color(0.91, 0.83, 0.58), "top": -0.02, "solid": false},
	"~": {"color": Color(0.32, 0.60, 0.88), "top": -0.14, "solid": true},
	"o": {"color": Color(0.33, 0.26, 0.20), "top": -0.25, "solid": true},
}

## Toplanabilir nesneler (2D'deki degerlerle ayni)
const OBJECT_DEFS := {
	"T": {"drops": {"odun": 3, "yaprak": 2}, "hits": 3,
			"tool": {"item": "balta", "hits": 1}},
	"#": {"drops": {"tas": 2}, "hits": 4,
			"tool": {"item": "kazma", "hits": 2}},
	"m": {"drops": {"meyve": 2}, "hits": 1, "becomes": "n"},
}
const REGROW_SECONDS := 60.0
const CAM_BASE_DIST := 9.2
const SETTINGS_PATH := "user://cam3d.json"

var _ground_char: Dictionary = {}  # hucre -> zemin karakteri
var _objects: Dictionary = {}      # hucre -> "T"/"#"/"m"/"n"
var _object_hits: Dictionary = {}  # hucre -> alinan vurus
var _regrow: Dictionary = {}       # bos cali -> kalan sure
var _object_nodes: Array = []      # nesne MultiMesh dugumleri (rebuild icin)
var _solid_cells: Dictionary = {}
var _map_w: int = 0
var _map_h: int = 0
var _spawn_cell := Vector2i(5, 5)
var _held_item: String = ""

# Kamera ayarlari (kaydedilir)
var cam_distance: float = 1.0  # yakinlik carpani
var cam_pitch: float = 52.0    # bakis acisi (derece)

var player: Node3D
var camera: Camera3D
var hud: CanvasLayer

var _zoom_slider: HSlider
var _pitch_slider: HSlider
var _touches: Dictionary = {}
var _pinch_last: float = -1.0

func _ready() -> void:
	_load_settings()
	_build_environment()
	_build_world()
	_spawn_player()
	# Mevcut 2D arayuz 3D'nin ustunde aynen calisir (autoload tabanli)
	hud = load("res://scenes/HUD.tscn").instantiate()
	add_child(hud)
	hud.action_pressed.connect(_on_action_pressed)
	hud.hold_requested.connect(_on_hold_requested)
	_build_camera_ui()

func _process(delta: float) -> void:
	# Kamera: SADECE konum takip eder, aci sabit kalir
	var target := player.position + _camera_offset()
	camera.position = camera.position.lerp(target, minf(1.0, 6.0 * delta))
	hud.set_action_state(_compute_action_state())
	_tick_regrow(delta)
	# Eldeki esya envanterden ciktiysa birak
	if _held_item != "" and Inventory.get_count(_held_item) <= 0:
		_on_hold_requested("")

func is_walkable(cell: Vector2i) -> bool:
	if cell.x < 1 or cell.y < 1 or cell.x >= _map_w - 1 or cell.y >= _map_h - 1:
		return false
	return not _solid_cells.has(cell)

# --- Kamera -------------------------------------------------------------

func _camera_offset() -> Vector3:
	var pitch := deg_to_rad(cam_pitch)
	return Vector3(0, sin(pitch), cos(pitch)) * (CAM_BASE_DIST * cam_distance)

func _apply_camera_angle() -> void:
	camera.rotation_degrees = Vector3(-cam_pitch, 0, 0)

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		cam_distance = clampf(float(parsed.get("zoom", 1.0)), 0.55, 1.7)
		cam_pitch = clampf(float(parsed.get("pitch", 52.0)), 35.0, 68.0)

func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"zoom": cam_distance, "pitch": cam_pitch}))

# Iki parmakla yakinlastirma (pinch); oyuncu hareketi 1. parmakta kalir
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
			if _pinch_last > 0.0:
				_save_settings()
			_pinch_last = -1.0
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.has(0) and _touches.has(1):
			var dist: float = _touches[0].distance_to(_touches[1])
			if _pinch_last > 0.0 and dist > 1.0:
				cam_distance = clampf(cam_distance * (_pinch_last / dist), 0.55, 1.7)
				if _zoom_slider != null:
					_zoom_slider.set_value_no_signal(cam_distance)
			_pinch_last = dist

# Kamera ayar paneli: sol kenarda "Kamera" butonu -> yakinlik/aci
func _build_camera_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)

	var button := Button.new()
	button.text = "Kamera"
	button.toggle_mode = true
	button.position = Vector2(12, 190)
	button.size = Vector2(120, 46)
	button.add_theme_font_size_override("font_size", 18)
	layer.add_child(button)

	var panel := PanelContainer.new()
	panel.visible = false
	panel.position = Vector2(12, 244)
	panel.custom_minimum_size = Vector2(320, 0)
	layer.add_child(panel)
	button.toggled.connect(func(pressed: bool):
		panel.visible = pressed
		if not pressed:
			_save_settings())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var zoom_label := Label.new()
	zoom_label.text = "Yakınlık"
	zoom_label.add_theme_font_size_override("font_size", 16)
	box.add_child(zoom_label)
	_zoom_slider = HSlider.new()
	_zoom_slider.min_value = 0.55
	_zoom_slider.max_value = 1.7
	_zoom_slider.step = 0.01
	_zoom_slider.value = cam_distance
	_zoom_slider.custom_minimum_size = Vector2(0, 36)
	_zoom_slider.value_changed.connect(func(v: float): cam_distance = v)
	box.add_child(_zoom_slider)

	var pitch_label := Label.new()
	pitch_label.text = "Açı (yatay <-> tepeden)"
	pitch_label.add_theme_font_size_override("font_size", 16)
	box.add_child(pitch_label)
	_pitch_slider = HSlider.new()
	_pitch_slider.min_value = 35.0
	_pitch_slider.max_value = 68.0
	_pitch_slider.step = 0.5
	_pitch_slider.value = cam_pitch
	_pitch_slider.custom_minimum_size = Vector2(0, 36)
	_pitch_slider.value_changed.connect(func(v: float):
		cam_pitch = v
		_apply_camera_angle())
	box.add_child(_pitch_slider)

# --- Ortam: gokyuzu + gunes ---------------------------------------------

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.44, 0.69, 0.94)
	sky_mat.sky_horizon_color = Color(0.95, 0.93, 0.82)
	sky_mat.ground_bottom_color = Color(0.55, 0.72, 0.55)
	sky_mat.ground_horizon_color = Color(0.92, 0.90, 0.78)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.1
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -32, 0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	camera.fov = 45.0
	add_child(camera)
	_apply_camera_angle()

# --- Dunya kurulumu -----------------------------------------------------

func _build_world() -> void:
	var rows: Array[String] = MapData.MAP
	_map_h = rows.size()
	_map_w = rows[0].length()

	var ground_cells: Dictionary = {}
	for ch in GROUND_DEFS:
		ground_cells[ch] = []

	for y in _map_h:
		for x in _map_w:
			var cell := Vector2i(x, y)
			var ch := rows[y][x]
			var ground := "."
			match ch:
				"P":
					_spawn_cell = cell
				"T", "#", "m":
					_objects[cell] = ch
					_solid_cells[cell] = true
				_:
					if GROUND_DEFS.has(ch):
						ground = ch
			_ground_char[cell] = ground
			if GROUND_DEFS[ground]["solid"]:
				_solid_cells[cell] = true
			ground_cells[ground].append(cell)

	# Zemin bloklari: tur basina tek MultiMesh (tek cizim cagrisi)
	for ch in ground_cells:
		var cells: Array = ground_cells[ch]
		if cells.is_empty():
			continue
		var def: Dictionary = GROUND_DEFS[ch]
		var box := BoxMesh.new()
		box.size = Vector3(1, 0.5, 1)
		var transforms: Array[Transform3D] = []
		for cell in cells:
			transforms.append(Transform3D(Basis.IDENTITY,
					_cell_center(cell) + Vector3(0, float(def["top"]) - 0.25, 0)))
		add_child(_make_multimesh(box, def["color"], transforms, ch == "~"))

	_rebuild_objects()

func _cell_center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x + 0.5, 0, cell.y + 0.5)

# Nesne gorsellerini bastan kurar (toplama sonrasi cagrilir).
# Tur basina birkac MultiMesh: yuzlerce nesne, ~10 cizim cagrisi.
func _rebuild_objects() -> void:
	for node in _object_nodes:
		node.queue_free()
	_object_nodes.clear()

	var trees: Array[Vector2i] = []
	var stones: Array[Vector2i] = []
	var bushes_full: Array[Vector2i] = []
	var bushes_empty: Array[Vector2i] = []
	for cell in _objects:
		match _objects[cell]:
			"T": trees.append(cell)
			"#": stones.append(cell)
			"m": bushes_full.append(cell)
			"n": bushes_empty.append(cell)

	_build_trees(trees)
	_build_stones(stones)
	_build_bushes(bushes_full, bushes_empty)

func _build_trees(cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.11
	trunk.bottom_radius = 0.14
	trunk.height = 0.6
	var leaf_low := SphereMesh.new()
	leaf_low.radius = 0.48
	leaf_low.height = 0.8
	var leaf_top := SphereMesh.new()
	leaf_top.radius = 0.32
	leaf_top.height = 0.55

	var trunk_t: Array[Transform3D] = []
	var low_t: Array[Transform3D] = []
	var top_t: Array[Transform3D] = []
	for cell in cells:
		var base := _cell_center(cell)
		var rot := _cell_variance(cell)
		trunk_t.append(Transform3D(rot, base + Vector3(0, 0.3, 0)))
		low_t.append(Transform3D(rot, base + Vector3(0, 0.85, 0)))
		top_t.append(Transform3D(rot, base + Vector3(0, 1.25, 0)))
	_keep(_make_multimesh(trunk, Color(0.48, 0.34, 0.22), trunk_t))
	_keep(_make_multimesh(leaf_low, Color(0.36, 0.65, 0.33), low_t))
	_keep(_make_multimesh(leaf_top, Color(0.45, 0.74, 0.38), top_t))

func _build_stones(cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	var rock := SphereMesh.new()
	rock.radius = 0.42
	rock.height = 0.55
	var transforms: Array[Transform3D] = []
	for cell in cells:
		transforms.append(Transform3D(_cell_variance(cell),
				_cell_center(cell) + Vector3(0, 0.16, 0)))
	_keep(_make_multimesh(rock, Color(0.62, 0.63, 0.66), transforms))

func _build_bushes(full: Array[Vector2i], empty: Array[Vector2i]) -> void:
	if not full.is_empty():
		var bush := SphereMesh.new()
		bush.radius = 0.36
		bush.height = 0.55
		var berry := SphereMesh.new()
		berry.radius = 0.06
		berry.height = 0.12
		var bush_t: Array[Transform3D] = []
		var berry_t: Array[Transform3D] = []
		for cell in full:
			var base := _cell_center(cell)
			bush_t.append(Transform3D(_cell_variance(cell), base + Vector3(0, 0.2, 0)))
			berry_t.append(Transform3D(Basis.IDENTITY, base + Vector3(0.14, 0.38, 0.12)))
			berry_t.append(Transform3D(Basis.IDENTITY, base + Vector3(-0.12, 0.32, -0.08)))
		_keep(_make_multimesh(bush, Color(0.32, 0.60, 0.30), bush_t))
		_keep(_make_multimesh(berry, Color(0.90, 0.30, 0.35), berry_t))
	if not empty.is_empty():
		var bush2 := SphereMesh.new()
		bush2.radius = 0.28
		bush2.height = 0.42
		var t2: Array[Transform3D] = []
		for cell in empty:
			t2.append(Transform3D(_cell_variance(cell), _cell_center(cell) + Vector3(0, 0.16, 0)))
		_keep(_make_multimesh(bush2, Color(0.30, 0.45, 0.26), t2))

func _keep(node: MultiMeshInstance3D) -> void:
	add_child(node)
	_object_nodes.append(node)

# Hucreye bagli deterministik minik dondurme/olcek farki (organik gorunum)
func _cell_variance(cell: Vector2i) -> Basis:
	var seed_val := float(cell.x * 73 + cell.y * 131)
	var angle := sin(seed_val) * PI
	var scale := 0.9 + 0.2 * absf(sin(seed_val * 1.7))
	return Basis(Vector3.UP, angle).scaled(Vector3(scale, scale, scale))

func _make_multimesh(mesh: Mesh, color: Color, transforms: Array, water := false) -> MultiMeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	if water:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = 0.85
		material.roughness = 0.15
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = material
	return node

# --- Oyuncu -------------------------------------------------------------

func _spawn_player() -> void:
	player = Player3DScript.new()
	player.world = self
	player.position = _cell_center(_spawn_cell)
	add_child(player)
	player.world_tapped.connect(_on_world_tapped)
	camera.position = player.position + _camera_offset()

func _player_cell() -> Vector2i:
	return Vector2i(floori(player.position.x), floori(player.position.z))

# --- Etkilesim ----------------------------------------------------------

## Ekrandaki dokunusu zemin duzlemine (y=0) izdusurup hucre bulur.
func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return Vector2i(-999, -999)
	var t := -from.y / dir.y
	if t < 0.0:
		return Vector2i(-999, -999)
	var hit := from + dir * t
	return Vector2i(floori(hit.x), floori(hit.z))

func _on_world_tapped(screen_pos: Vector2) -> void:
	var cell := _screen_to_cell(screen_pos)
	var pc := _player_cell()
	var diff := (cell - pc).abs()
	if maxi(diff.x, diff.y) > 1:
		return
	if _ground_char.get(cell, "") == "~" and not _objects.has(cell):
		Thirst.drink()
		_spawn_floating_text(cell, "Su içtin!", Color(0.6, 0.85, 1.0))
		return
	_try_harvest(cell)

func _on_action_pressed() -> void:
	var pc := _player_cell()
	var facing_offset := Vector2i(player.facing.round())
	if facing_offset == Vector2i.ZERO:
		facing_offset = Vector2i(0, 1)
	var offsets: Array[Vector2i] = [facing_offset]
	for oy in [-1, 0, 1]:
		for ox in [-1, 0, 1]:
			var o := Vector2i(ox, oy)
			if o != Vector2i.ZERO and o != facing_offset:
				offsets.append(o)
	for o in offsets:
		if _try_harvest(pc + o):
			return

func _try_harvest(cell: Vector2i) -> bool:
	var ch: String = _objects.get(cell, "")
	if ch == "" or not OBJECT_DEFS.has(ch):
		return false
	var def: Dictionary = OBJECT_DEFS[ch]
	var hits_needed: int = def.get("hits", 1)
	if def.has("tool") and _held_item == def["tool"]["item"]:
		hits_needed = def["tool"]["hits"]
	var damage: int = int(_object_hits.get(cell, 0)) + 1
	if damage < hits_needed:
		_object_hits[cell] = damage
		_spawn_floating_text(cell, "%d/%d" % [damage, hits_needed], Color(1.0, 0.95, 0.6))
		return true
	if not Inventory.can_add_all(def["drops"]):
		_spawn_floating_text(cell, "Envanter dolu!", Color(1, 0.6, 0.6))
		return false
	_object_hits.erase(cell)
	var gained: PackedStringArray = []
	for item_id in def["drops"]:
		Inventory.add_item(item_id, def["drops"][item_id])
		gained.append("+%d %s" % [def["drops"][item_id], Items.display_name(item_id)])
	_spawn_floating_text(cell, " ".join(gained), Color(0.7, 1.0, 0.7))
	if def.has("becomes"):
		_objects[cell] = def["becomes"]
		_regrow[cell] = REGROW_SECONDS
	else:
		_objects.erase(cell)
		_solid_cells.erase(cell)
	_rebuild_objects()
	return true

func _tick_regrow(delta: float) -> void:
	var ready_cells: Array[Vector2i] = []
	for cell in _regrow:
		_regrow[cell] -= delta
		if _regrow[cell] <= 0.0:
			ready_cells.append(cell)
	if ready_cells.is_empty():
		return
	for cell in ready_cells:
		_regrow.erase(cell)
		_objects[cell] = "m"
	_rebuild_objects()

func _on_hold_requested(item_id: String) -> void:
	if item_id != "" and Inventory.get_count(item_id) <= 0:
		return
	_held_item = item_id
	hud.set_held_item(item_id)

func _compute_action_state() -> String:
	var pc := _player_cell()
	for oy in [-1, 0, 1]:
		for ox in [-1, 0, 1]:
			if ox == 0 and oy == 0:
				continue
			var ch: String = _objects.get(pc + Vector2i(ox, oy), "")
			if ch != "" and OBJECT_DEFS.has(ch):
				return "gather"
	return "idle"

# Yukari suzulup kaybolan 3D yazi (toplama geri bildirimi)
func _spawn_floating_text(cell: Vector2i, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.outline_size = 10
	label.no_depth_test = true
	label.position = _cell_center(cell) + Vector3(0, 1.2, 0)
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y + 0.8, 0.7)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7)
	tween.tween_callback(label.queue_free)
