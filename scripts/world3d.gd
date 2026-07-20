extends Node3D
## 3D dunya - Asama B1: iskelet.
##
## Go-Go Town / Animal Crossing hedefine giden ilk adim: ayni ASCII
## harita, minik 3D bloklardan zemin, yer tutucu agac/kaya/cali
## sekilleri, capraz yukaridan bakan kamera ve dokunmatik hareket.
## Performans icin her seyi MultiMesh ile ciziyoruz (tur basina tek
## cizim cagrisi). B2'de yer tutucular gercek low-poly modellerle
## degisecek.
##
## Oyun mantigi (envanter/uretim/aclik...) autoload'larda yasiyor ve
## aynen calisiyor; HUD 3D'nin ustune 2D katman olarak biniyor.

const MapData = preload("res://scripts/map_data.gd")
const Player3DScript = preload("res://scripts/player3d.gd")

## Zemin turleri: renk + ust yuzeyin yuksekligi (metre; 0 = yuruyus seviyesi)
const GROUND_DEFS := {
	".": {"color": Color(0.46, 0.73, 0.36), "top": 0.0, "solid": false},
	"d": {"color": Color(0.60, 0.44, 0.29), "top": -0.02, "solid": false},
	"s": {"color": Color(0.91, 0.83, 0.58), "top": -0.02, "solid": false},
	"~": {"color": Color(0.32, 0.60, 0.88), "top": -0.14, "solid": true},
	"o": {"color": Color(0.33, 0.26, 0.20), "top": -0.25, "solid": true},
}

const CAM_OFFSET := Vector3(0.0, 7.4, 5.6)  # AC tarzi capraz bakis

var _solid_cells: Dictionary = {}  # Vector2i -> true (su/cukur/nesne)
var _map_w: int = 0
var _map_h: int = 0
var _spawn_cell := Vector2i(5, 5)

var player: Node3D
var camera: Camera3D

func _ready() -> void:
	_build_environment()
	_build_world()
	_spawn_player()
	# Mevcut 2D arayuz 3D'nin ustunde aynen calisir (autoload tabanli)
	add_child(load("res://scenes/HUD.tscn").instantiate())

func _process(delta: float) -> void:
	# Kamera oyuncuyu yumusakca takip eder
	var target := player.position + CAM_OFFSET
	camera.position = camera.position.lerp(target, minf(1.0, 6.0 * delta))
	camera.look_at(player.position + Vector3(0, 0.4, 0))

## Oyuncu hareketi bu izgara kontrolunu kullanir (fizik motoru yok:
## basit, ongorulebilir ve mobilde ucuz)
func is_walkable(cell: Vector2i) -> bool:
	if cell.x < 1 or cell.y < 1 or cell.x >= _map_w - 1 or cell.y >= _map_h - 1:
		return false
	return not _solid_cells.has(cell)

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

# --- Dunya kurulumu -----------------------------------------------------

func _build_world() -> void:
	var rows: Array[String] = MapData.MAP
	_map_h = rows.size()
	_map_w = rows[0].length()

	# Zemin hucrelerini ture gore topla; nesne konumlarini ayir
	var ground_cells: Dictionary = {}  # tur -> Array[Vector2i]
	for ch in GROUND_DEFS:
		ground_cells[ch] = []
	var trees: Array[Vector2i] = []
	var stones: Array[Vector2i] = []
	var bushes: Array[Vector2i] = []

	for y in _map_h:
		for x in _map_w:
			var cell := Vector2i(x, y)
			var ch := rows[y][x]
			var ground := "."
			match ch:
				"P":
					_spawn_cell = cell
				"T":
					trees.append(cell)
					_solid_cells[cell] = true
				"#":
					stones.append(cell)
					_solid_cells[cell] = true
				"m":
					bushes.append(cell)
					_solid_cells[cell] = true
				_:
					if GROUND_DEFS.has(ch):
						ground = ch
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
		_add_multimesh(box, def["color"], transforms, ch == "~")

	_build_trees(trees)
	_build_stones(stones)
	_build_bushes(bushes)

func _cell_center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x + 0.5, 0, cell.y + 0.5)

# Yer tutucu agac: silindir govde + iki kure yaprak katmani
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
	_add_multimesh(trunk, Color(0.48, 0.34, 0.22), trunk_t)
	_add_multimesh(leaf_low, Color(0.36, 0.65, 0.33), low_t)
	_add_multimesh(leaf_top, Color(0.45, 0.74, 0.38), top_t)

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
	_add_multimesh(rock, Color(0.62, 0.63, 0.66), transforms)

func _build_bushes(cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	var bush := SphereMesh.new()
	bush.radius = 0.36
	bush.height = 0.55
	var berry := SphereMesh.new()
	berry.radius = 0.06
	berry.height = 0.12
	var bush_t: Array[Transform3D] = []
	var berry_t: Array[Transform3D] = []
	for cell in cells:
		var base := _cell_center(cell)
		bush_t.append(Transform3D(_cell_variance(cell), base + Vector3(0, 0.2, 0)))
		berry_t.append(Transform3D(Basis.IDENTITY, base + Vector3(0.14, 0.38, 0.12)))
		berry_t.append(Transform3D(Basis.IDENTITY, base + Vector3(-0.12, 0.32, -0.08)))
	_add_multimesh(bush, Color(0.32, 0.60, 0.30), bush_t)
	_add_multimesh(berry, Color(0.90, 0.30, 0.35), berry_t)

# Hucreye bagli deterministik minik dondurme/olcek farki (organik gorunum)
func _cell_variance(cell: Vector2i) -> Basis:
	var seed_val := float(cell.x * 73 + cell.y * 131)
	var angle := sin(seed_val) * PI
	var scale := 0.9 + 0.2 * absf(sin(seed_val * 1.7))
	return Basis(Vector3.UP, angle).scaled(Vector3(scale, scale, scale))

func _add_multimesh(mesh: Mesh, color: Color, transforms: Array, water := false) -> void:
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
	add_child(node)

# --- Oyuncu -------------------------------------------------------------

func _spawn_player() -> void:
	player = Player3DScript.new()
	player.world = self
	player.position = _cell_center(_spawn_cell)
	add_child(player)
	camera.position = player.position + CAM_OFFSET
	camera.look_at(player.position)
