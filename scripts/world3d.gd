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

## Zemin turleri: renk + ust yuzey yuksekligi. "speckled": true olan
## turler icin benekli doku CALISMA ANINDA kodla uretilir (dosya
## iceri aktarma boru hattina bagimlilik yok - her platformda calisir).
const GROUND_DEFS := {
	".": {"color": Color(0.46, 0.73, 0.36), "top": 0.0, "solid": false, "speckled": true},
	"d": {"color": Color(0.60, 0.44, 0.29), "top": -0.02, "solid": false, "speckled": true},
	"s": {"color": Color(0.91, 0.83, 0.58), "top": -0.02, "solid": false, "speckled": true},
	"~": {"color": Color(0.30, 0.58, 0.88), "top": -0.14, "solid": true, "water": true},
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

# Kenney Nature Kit modelleri (CC0). Hucreye gore deterministik secilir:
# orman cesitli ama her acilista ayni gorunur.
const NATURE_PATH := "res://assets/models/nature/%s.glb"
## Orman stilleri: Gorunum panelinden secilir, aninda uygulanir
const FOREST_STYLES := {
	"karisik": {"label": "Karışık", "models": ["tree_default", "tree_oak",
			"tree_fat", "tree_pineRoundA", "tree_pineRoundC", "tree_simple"]},
	"cam": {"label": "Çam Ormanı", "models": ["tree_pineRoundA",
			"tree_pineRoundB", "tree_pineRoundC", "tree_pineRoundD",
			"tree_pineTallA", "tree_pineTallB"]},
	"yaprakli": {"label": "Yapraklı", "models": ["tree_detailed", "tree_oak",
			"tree_default", "tree_thin"]},
	"ince": {"label": "İnce Uzun", "models": ["tree_thin", "tree_tall",
			"tree_pineTallA_detailed", "tree_pineTallB_detailed"]},
}
## Karakter secenekleri (Gorunum paneli): Mini ailesi - 12 govde/kiyafet.
## Tek govde tipi = tum aksesuarlar herkese tam oturur.
const CHARACTER_OPTIONS := [
	["Erkek A", "res://assets/models/characters/mini/character-male-a.glb"],
	["Erkek B", "res://assets/models/characters/mini/character-male-b.glb"],
	["Erkek C", "res://assets/models/characters/mini/character-male-c.glb"],
	["Erkek D", "res://assets/models/characters/mini/character-male-d.glb"],
	["Erkek E", "res://assets/models/characters/mini/character-male-e.glb"],
	["Erkek F", "res://assets/models/characters/mini/character-male-f.glb"],
	["Kadın A", "res://assets/models/characters/mini/character-female-a.glb"],
	["Kadın B", "res://assets/models/characters/mini/character-female-b.glb"],
	["Kadın C", "res://assets/models/characters/mini/character-female-c.glb"],
	["Kadın D", "res://assets/models/characters/mini/character-female-d.glb"],
	["Kadın E", "res://assets/models/characters/mini/character-female-e.glb"],
	["Kadın F", "res://assets/models/characters/mini/character-female-f.glb"],
]

## Sapka secenekleri (player3d kod ile insa eder)
const HAT_OPTIONS := [
	["Yok", "yok"],
	["Hasır Şapka", "hasir"],
	["Bere", "bere"],
	["Kasket", "kasket"],
	["Taç", "tac"],
	["Parti", "parti"],
	["Çiçek Tacı", "cicek"],
]

## Yuz aksesuarlari (mini paketinden hazir modeller)
const FACE_OPTIONS := [
	["Yok", ""],
	["Gözlük", "res://assets/models/characters/mini/aid-glasses.glb"],
	["Güneş Gözlüğü", "res://assets/models/characters/mini/aid-sunglasses.glb"],
	["Maske", "res://assets/models/characters/mini/aid-mask.glb"],
]
const STONE_MODELS: Array[String] = ["rock_largeA", "rock_tallA",
		"stone_tallB", "rock_largeB"]
const BUSH_FULL_MODEL := "plant_bushDetailed"
const BUSH_EMPTY_MODEL := "plant_bushSmall"
# Cim hucrelerine serpistirilen susler (engel degil, toplanmaz).
# Ot modelleri listede birkac kez: cimenlik agirlikli olsun
const DECOR_MODELS: Array[String] = ["grass_leafs", "grass_large",
		"grass_leafsLarge", "grass_leafs", "flower_redA", "flower_yellowA",
		"grass_large", "flower_purpleA", "grass_leafs", "mushroom_red"]

var _ground_char: Dictionary = {}  # hucre -> zemin karakteri
var _objects: Dictionary = {}      # hucre -> "T"/"#"/"m"/"n"
var _object_hits: Dictionary = {}  # hucre -> alinan vurus
var _regrow: Dictionary = {}       # bos cali -> kalan sure
var _object_nodes: Array = []      # nesne MultiMesh dugumleri (rebuild icin)
var _mesh_cache: Dictionary = {}   # model adi -> Mesh (GLB'den bir kez cikarilir)
var _solid_cells: Dictionary = {}
var _map_w: int = 0
var _map_h: int = 0
var _spawn_cell := Vector2i(5, 5)
var _held_item: String = ""

# Kamera + gorunum ayarlari (kaydedilir)
var cam_distance: float = 1.0  # yakinlik carpani
var cam_pitch: float = 52.0    # bakis acisi (derece)
var character_path: String = "res://assets/models/characters/mini/character-male-a.glb"
var forest_style: String = "karisik"
var hat_id: String = "yok"
var face_path: String = ""

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
	# CI ekran goruntusu modu: birkac saniye sonra kare kaydet ve cik
	if OS.has_environment("RABLE_SCREENSHOT"):
		_setup_screenshot(OS.get_environment("RABLE_SCREENSHOT"))

func _setup_screenshot(save_path: String) -> void:
	var timer := get_tree().create_timer(4.0)
	timer.timeout.connect(func():
		var img := get_viewport().get_texture().get_image()
		img.save_png(save_path)
		print("ekran goruntusu kaydedildi: ", save_path)
		get_tree().quit())

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
		var saved_char := String(parsed.get("character", character_path))
		if ResourceLoader.exists(saved_char):
			character_path = saved_char
		var saved_forest := String(parsed.get("forest", forest_style))
		if FOREST_STYLES.has(saved_forest):
			forest_style = saved_forest
		hat_id = String(parsed.get("hat", hat_id))
		face_path = String(parsed.get("face", face_path))

func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"zoom": cam_distance,
				"pitch": cam_pitch, "character": character_path,
				"forest": forest_style, "hat": hat_id, "face": face_path}))

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

# Ayar panelleri: sol kenarda "Kamera" ve "Görünüm" butonlari.
# Kamera: yakinlik/aci. Gorunum: karakter secimi + orman stili.
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

	var look_button := Button.new()
	look_button.text = "Görünüm"
	look_button.toggle_mode = true
	look_button.position = Vector2(12, 244)
	look_button.size = Vector2(120, 46)
	look_button.add_theme_font_size_override("font_size", 18)
	layer.add_child(look_button)

	var panel := PanelContainer.new()
	panel.visible = false
	panel.position = Vector2(144, 190)
	panel.custom_minimum_size = Vector2(320, 0)
	layer.add_child(panel)
	button.toggled.connect(func(pressed: bool):
		panel.visible = pressed
		if pressed:
			look_button.button_pressed = false
		else:
			_save_settings())

	_build_look_panel(layer, look_button, button)

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

# Gorunum paneli: karakter listesi + orman stili (secim aninda uygulanir)
func _build_look_panel(layer: CanvasLayer, look_button: Button, cam_button: Button) -> void:
	var panel := PanelContainer.new()
	panel.visible = false
	panel.position = Vector2(144, 100)
	panel.custom_minimum_size = Vector2(360, 0)
	layer.add_child(panel)
	look_button.toggled.connect(func(pressed: bool):
		panel.visible = pressed
		if pressed:
			cam_button.button_pressed = false
		else:
			_save_settings())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var char_label := Label.new()
	char_label.text = "Karakter"
	char_label.add_theme_font_size_override("font_size", 17)
	box.add_child(char_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 170)
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)

	var char_group := ButtonGroup.new()
	for option in CHARACTER_OPTIONS:
		var b := Button.new()
		b.text = option[0]
		b.toggle_mode = true
		b.button_group = char_group
		b.custom_minimum_size = Vector2(108, 42)
		b.add_theme_font_size_override("font_size", 15)
		b.button_pressed = option[1] == character_path
		var path: String = option[1]
		b.toggled.connect(func(pressed: bool):
			if pressed:
				character_path = path
				player.set_character(path)
				_save_settings())
		grid.add_child(b)

	# Sapka secimi
	var hat_label := Label.new()
	hat_label.text = "Şapka"
	hat_label.add_theme_font_size_override("font_size", 17)
	box.add_child(hat_label)
	var hat_grid := GridContainer.new()
	hat_grid.columns = 4
	hat_grid.add_theme_constant_override("h_separation", 6)
	hat_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(hat_grid)
	var hat_group := ButtonGroup.new()
	for option in HAT_OPTIONS:
		var hb := Button.new()
		hb.text = option[0]
		hb.toggle_mode = true
		hb.button_group = hat_group
		hb.add_theme_font_size_override("font_size", 13)
		hb.button_pressed = option[1] == hat_id
		var hid: String = option[1]
		hb.toggled.connect(func(pressed: bool):
			if pressed:
				hat_id = hid
				player.set_hat(hid)
				_save_settings())
		hat_grid.add_child(hb)

	# Yuz aksesuari secimi
	var face_label := Label.new()
	face_label.text = "Yüz"
	face_label.add_theme_font_size_override("font_size", 17)
	box.add_child(face_label)
	var face_row := GridContainer.new()
	face_row.columns = 4
	face_row.add_theme_constant_override("h_separation", 6)
	box.add_child(face_row)
	var face_group := ButtonGroup.new()
	for option in FACE_OPTIONS:
		var fb2 := Button.new()
		fb2.text = option[0]
		fb2.toggle_mode = true
		fb2.button_group = face_group
		fb2.add_theme_font_size_override("font_size", 13)
		fb2.button_pressed = option[1] == face_path
		var fpath: String = option[1]
		fb2.toggled.connect(func(pressed: bool):
			if pressed:
				face_path = fpath
				player.set_face(fpath)
				_save_settings())
		face_row.add_child(fb2)

	var forest_label := Label.new()
	forest_label.text = "Orman Stili"
	forest_label.add_theme_font_size_override("font_size", 17)
	box.add_child(forest_label)

	var forest_row := HBoxContainer.new()
	forest_row.add_theme_constant_override("separation", 6)
	box.add_child(forest_row)
	var forest_group := ButtonGroup.new()
	for style_id in FOREST_STYLES:
		var fb := Button.new()
		fb.text = FOREST_STYLES[style_id]["label"]
		fb.toggle_mode = true
		fb.button_group = forest_group
		fb.add_theme_font_size_override("font_size", 14)
		fb.button_pressed = style_id == forest_style
		var sid: String = style_id
		fb.toggled.connect(func(pressed: bool):
			if pressed:
				forest_style = sid
				_rebuild_objects()
				_save_settings())
		forest_row.add_child(fb)

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
		var node := _make_multimesh(box, def["color"], transforms, def.get("water", false))
		if def.get("speckled", false):
			var mat: StandardMaterial3D = node.material_override
			mat.albedo_texture = _make_speckle_texture(def["color"])
			mat.albedo_color = Color.WHITE
		add_child(node)

	_build_sea()
	_build_decor(ground_cells["."])
	_rebuild_objects()

# Benekli zemin dokusu: kod ile uretilir (dosya yok, iceri aktarma yok).
# Ana renk + acik/koyu benekler; cim icin ince ot cizgileri de eklenir.
var _speckle_cache: Dictionary = {}

func _make_speckle_texture(base: Color) -> ImageTexture:
	if _speckle_cache.has(base):
		return _speckle_cache[base]
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345  # deterministik: her acilista ayni gorunum
	for y in size:
		for x in size:
			var wave := 1.0 + sin(x * 0.35 + y * 0.21) * cos(y * 0.4 - x * 0.13) * 0.05
			img.set_pixel(x, y, Color(base.r * wave, base.g * wave, base.b * wave))
	# Acik ve koyu benekler
	for i in 90:
		var px := rng.randi_range(0, size - 1)
		var py := rng.randi_range(0, size - 1)
		var tone := 0.86 + rng.randf() * 0.30  # 0.86..1.16
		var speck := Color(base.r * tone, base.g * tone, base.b * tone)
		img.set_pixel(px, py, speck)
		img.set_pixel((px + 1) % size, py, speck)
		img.set_pixel(px, (py + 1) % size, speck)
	# Cim icin kisa dikey ot cizgileri (yesil agirlikli renklerde)
	if base.g > base.r and base.g > base.b:
		for i in 70:
			var gx := rng.randi_range(0, size - 1)
			var gy := rng.randi_range(2, size - 1)
			var blade := Color(base.r * 1.18, base.g * 1.16, base.b * 1.12)
			for k in rng.randi_range(2, 4):
				img.set_pixel(gx, (gy - k + size) % size, blade)
	var tex := ImageTexture.create_from_image(img)
	_speckle_cache[base] = tex
	return tex

# Harita bir ada: cevresini ufka kadar dalgali deniz sarar.
func _build_sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(_map_w + 160, _map_h + 160)
	plane.subdivide_width = 72
	plane.subdivide_depth = 72
	var sea := MeshInstance3D.new()
	sea.mesh = plane
	sea.material_override = _water_material()
	sea.position = Vector3(_map_w / 2.0, -0.14, _map_h / 2.0)
	add_child(sea)

# Dalgali su malzemesi (deniz + harita ici su ayni gorunum)
var _water_mat: ShaderMaterial

func _water_material() -> ShaderMaterial:
	if _water_mat != null:
		return _water_mat
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
uniform vec4 col : source_color = vec4(0.24, 0.55, 0.86, 0.88);
void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * 1.6 + wp.x * 0.9 + wp.z * 0.7) * 0.05
			+ cos(TIME * 1.1 + wp.z * 1.3) * 0.03;
}
void fragment() {
	ALBEDO = col.rgb;
	ALPHA = col.a;
	ROUGHNESS = 0.45;
	SPECULAR = 0.2;
}
"""
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = shader
	return _water_mat

# Bos cim hucrelerinin bir kismina cicek/ot/mantar serpistirir (sus).
func _build_decor(grass_cells: Array) -> void:
	var groups: Dictionary = {}  # model -> Array[Transform3D]
	for cell in grass_cells:
		if _objects.has(cell) or cell == _spawn_cell:
			continue
		var h := absi(cell.x * 92821 + cell.y * 68917) % 100
		if h >= 18:
			continue  # ~her 6 hucreden biri suslenir
		var model: String = DECOR_MODELS[h % DECOR_MODELS.size()]
		if not groups.has(model):
			groups[model] = []
		# Hucre icinde hafif kaydirma: izgara hissi kirilsin
		var off := Vector3(sin(cell.x * 12.9) * 0.25, 0, cos(cell.y * 7.7) * 0.25)
		groups[model].append(Transform3D(_cell_variance(cell), _cell_center(cell) + off))
	for model in groups:
		add_child(_make_model_multimesh(model, groups[model]))

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

# Agaclar: hucreye gore model secilir (secili orman stilinden),
# model basina tek MultiMesh. Olcek buyuk: insanin 2-2.5 kati boy
func _build_trees(cells: Array[Vector2i]) -> void:
	var models: Array = FOREST_STYLES[forest_style]["models"]
	var groups: Dictionary = {}
	for cell in cells:
		var model: String = models[absi(cell.x * 31 + cell.y * 57) % models.size()]
		if not groups.has(model):
			groups[model] = []
		groups[model].append(Transform3D(_cell_variance(cell).scaled(Vector3(2.1, 2.1, 2.1)),
				_cell_center(cell)))
	for model in groups:
		_keep(_make_model_multimesh(model, groups[model]))

func _build_stones(cells: Array[Vector2i]) -> void:
	var groups: Dictionary = {}
	for cell in cells:
		var model: String = STONE_MODELS[absi(cell.x * 17 + cell.y * 43) % STONE_MODELS.size()]
		if not groups.has(model):
			groups[model] = []
		groups[model].append(Transform3D(_cell_variance(cell), _cell_center(cell)))
	for model in groups:
		_keep(_make_model_multimesh(model, groups[model]))

func _build_bushes(full: Array[Vector2i], empty: Array[Vector2i]) -> void:
	if not full.is_empty():
		var bush_t: Array[Transform3D] = []
		var berry_t: Array[Transform3D] = []
		var berry := SphereMesh.new()
		berry.radius = 0.05
		berry.height = 0.1
		for cell in full:
			var base := _cell_center(cell)
			bush_t.append(Transform3D(_cell_variance(cell).scaled(Vector3(1.3, 1.3, 1.3)), base))
			# Meyveler: cali ustunde iki kirmizi minik kure (dolu isareti)
			berry_t.append(Transform3D(Basis.IDENTITY, base + Vector3(0.13, 0.42, 0.10)))
			berry_t.append(Transform3D(Basis.IDENTITY, base + Vector3(-0.11, 0.36, -0.07)))
		_keep(_make_model_multimesh(BUSH_FULL_MODEL, bush_t))
		_keep(_make_multimesh(berry, Color(0.90, 0.28, 0.33), berry_t))
	if not empty.is_empty():
		var t2: Array[Transform3D] = []
		for cell in empty:
			t2.append(Transform3D(_cell_variance(cell), _cell_center(cell)))
		_keep(_make_model_multimesh(BUSH_EMPTY_MODEL, t2))

func _keep(node: MultiMeshInstance3D) -> void:
	add_child(node)
	_object_nodes.append(node)

# GLB modelinden Mesh cikarir (bir kez; sonrasi onbellekten).
# Kenney doga modelleri tek mesh'tir; materyaller mesh'in icinde gelir.
func _find_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			return mi.mesh
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null

func _model_mesh(model: String) -> Mesh:
	if _mesh_cache.has(model):
		return _mesh_cache[model]
	var scene: Node = load(NATURE_PATH % model).instantiate()
	var mesh := _find_mesh(scene)
	scene.free()
	_mesh_cache[model] = mesh
	return mesh

func _make_model_multimesh(model: String, transforms: Array) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = _model_mesh(model)
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	return node

# Hucreye bagli deterministik minik dondurme/olcek farki (organik gorunum)
func _cell_variance(cell: Vector2i) -> Basis:
	var seed_val := float(cell.x * 73 + cell.y * 131)
	var angle := sin(seed_val) * PI
	var scale := 0.9 + 0.2 * absf(sin(seed_val * 1.7))
	return Basis(Vector3.UP, angle).scaled(Vector3(scale, scale, scale))

func _make_multimesh(mesh: Mesh, color: Color, transforms: Array, water := false) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	if water:
		# Harita ici su, denizle ayni dalgali malzemeyi kullanir
		node.material_override = _water_material()
	else:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 1.0
		node.material_override = material
	return node

# --- Oyuncu -------------------------------------------------------------

func _spawn_player() -> void:
	player = Player3DScript.new()
	player.world = self
	player.position = _cell_center(_spawn_cell)
	add_child(player)
	player.set_character(character_path)  # kayitli secim
	player.set_hat(hat_id)
	player.set_face(face_path)
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

## Eline alinan aletin 3D modeli (Kenney Survival Kit)
const TOOL_MODELS := {
	"balta": "res://assets/models/tools/tool-axe.glb",
	"kazma": "res://assets/models/tools/tool-pickaxe.glb",
	"kurek": "res://assets/models/tools/tool-shovel.glb",
	"mizrak": "spear",  # ozel: player3d basit mizrak insa eder
}

func _on_hold_requested(item_id: String) -> void:
	if item_id != "" and Inventory.get_count(item_id) <= 0:
		return
	_held_item = item_id
	hud.set_held_item(item_id)
	player.set_held_tool(TOOL_MODELS.get(item_id, ""))

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
