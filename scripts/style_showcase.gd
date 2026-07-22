extends Node3D
## STIL VITRIN (Bolum 17) — assets/models/test/ altindaki TUM .glb dosyalarini
## OYUNUN GERCEK gorsel kosullarinda (ayni WorldEnvironment + DirectionalLight +
## kamera acisi/zoom + gercek cim materyali) yan yana dizer. Oyuncu karakteri
## (1.35 m) olcek referansi olarak solda durur. Her modelin altinda dosya adi +
## uygulanan olcek carpani etiketi. Gunduz/Gece anahtari (gece bir mesale isigi).
##
## ANA OYUNU BOZMAZ: bu ayri bir sahnedir. Editorden calistir — bkz.
## RAPOR_STIL.md "Vitrin nasil calistirilir".

const CustomCharScript = preload("res://scripts/custom_character.gd")

const TEST_DIR := "res://assets/models/test/"
const PLAYER_H := 1.35            # player3d.TARGET_HEIGHT — olcek referansi (metre)
const DISPLAY_H := 2.2            # her model bu yukseklige normalize edilir (gorunur)
const SPACING := 2.8             # modeller/referans arasi mesafe (metre)

# Kamera: world3d ile AYNI his (pitch 52, fov 45, uzaklik CAM_BASE_DIST*zoom)
const CAM_PITCH := 52.0
const CAM_FOV := 45.0
const CAM_DIST := 12.5 * 1.375   # CAM_BASE_DIST * CAM_ZOOM_DEFAULT

# --- Gunduz/gece paletleri (world3d _build_environment + _SKY_KEYS ile ayni) ---
const DAY := {
	"sun_col": Color(1.0, 0.96, 0.88), "sun_energy": 1.05, "ambient": 0.75,
	"sky_top": Color(0.44, 0.69, 0.94), "sky_hor": Color(0.95, 0.93, 0.82),
}
const NIGHT := {
	"sun_col": Color(0.52, 0.52, 0.78), "sun_energy": 0.30, "ambient": 0.42,
	"sky_top": Color(0.16, 0.18, 0.34), "sky_hor": Color(0.40, 0.34, 0.52),
}

var _sun: DirectionalLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _torch: OmniLight3D
var _is_night := false
var _toggle_btn: Button
var _row_center_x := 0.0
var _t := 0.0

func _ready() -> void:
	_build_environment()
	var models := _scan_models()
	_build_ground(models.size())
	_build_reference()          # oyuncu karakteri (1.35 m)
	_lay_out(models)
	_build_torch()
	_build_camera()
	_build_ui(models)
	_apply_daynight()

# --- Ortam (oyunla birebir) --------------------------------------------
func _build_environment() -> void:
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sky_top_color = DAY["sky_top"]
	_sky_mat.sky_horizon_color = DAY["sky_hor"]
	_sky_mat.ground_bottom_color = Color(0.55, 0.72, 0.55)
	_sky_mat.ground_horizon_color = Color(0.92, 0.90, 0.78)
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = DAY["ambient"]
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-52, -32, 0)
	_sun.light_color = DAY["sun_col"]
	_sun.light_energy = DAY["sun_energy"]
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 40.0
	_sun.shadow_blur = 0.6
	add_child(_sun)

# --- Gercek cim zemini (world3d _terrain_mat + grass rengi) -------------
func _build_ground(n: int) -> void:
	var plane := PlaneMesh.new()
	var w := maxf(16.0, SPACING * (n + 3))
	plane.size = Vector2(w, 14.0)
	plane.subdivide_width = int(w)
	plane.subdivide_depth = 14
	var inst := MeshInstance3D.new()
	inst.mesh = plane
	inst.position = Vector3(SPACING * (n + 1) / 2.0, 0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.29, 0.53, 0.21)  # oyundaki cim "." rengi
	mat.roughness = 1.0
	mat.albedo_texture = _make_speckle()
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	inst.material_override = mat
	add_child(inst)

func _make_speckle() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	img.fill(Color(0.97, 0.97, 0.97))
	for i in 110:
		var px := rng.randi_range(0, size - 1)
		var py := rng.randi_range(0, size - 1)
		var tone := 0.86 + rng.randf() * 0.24
		img.set_pixel(px, py, Color(tone, tone, tone))
		img.set_pixel((px + 1) % size, py, Color(tone, tone, tone))
	return ImageTexture.create_from_image(img)

# --- Oyuncu karakteri: olcek referansi (1.35 m) ------------------------
func _build_reference() -> void:
	var holder := Node3D.new()
	holder.position = Vector3(0, 0, 0)
	add_child(holder)
	var char_node := CustomCharScript.new()
	char_node.setup_from_spec("f2c29b/4fa7d8/5b6b8c")
	# custom_character 0.67 ham olcekte kurulur; oyundaki gibi 1.35 m'ye getir
	var s := PLAYER_H / 0.67
	char_node.scale = Vector3(s, s, s)
	holder.add_child(char_node)
	_label(holder, "OYUNCU\n1.35 m (referans)", Color(1, 1, 0.7))

# --- Modelleri tara + diz ----------------------------------------------
func _scan_models() -> Array:
	var out: Array = []
	var d := DirAccess.open(TEST_DIR)
	if d == null:
		push_warning("STIL VITRIN: %s acilamadi" % TEST_DIR)
		return out
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if not d.current_is_dir() and fn.to_lower().ends_with(".glb"):
			out.append(fn)
		fn = d.get_next()
	d.list_dir_end()
	out.sort()
	return out

func _lay_out(models: Array) -> void:
	for i in models.size():
		var fn: String = models[i]
		var x := SPACING * (i + 1)
		var holder := Node3D.new()
		holder.position = Vector3(x, 0, 0)
		add_child(holder)
		var packed := load(TEST_DIR + fn) as PackedScene
		if packed == null:
			_label(holder, "%s\n(YUKLENEMEDI)" % fn, Color(1, 0.5, 0.5))
			continue
		var inst: Node3D = packed.instantiate()
		var aabb := _aabb_of(inst)
		var raw_h := maxf(aabb.size.y, 0.001)
		var mult := DISPLAY_H / raw_h
		inst.scale = Vector3(mult, mult, mult)
		# Tabani y=0'a otur, yatayda ortala (oyundaki normalize ile ayni)
		inst.position = Vector3(-aabb.get_center().x * mult,
				-aabb.position.y * mult, -aabb.get_center().z * mult)
		holder.add_child(inst)
		_label(holder, "%s\nham y=%.2fm  ×%.3f" % [fn, raw_h, mult],
				Color(0.85, 1.0, 0.85))
	_row_center_x = SPACING * (models.size() + 1) / 2.0

## Model altina bakan billboard etiket.
func _label(parent: Node3D, text: String, col: Color) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 48
	lbl.pixel_size = 0.004
	lbl.modulate = col
	lbl.outline_size = 12
	lbl.outline_modulate = Color(0, 0, 0, 0.8)
	lbl.position = Vector3(0, -0.35, 0.2)
	lbl.no_depth_test = false
	parent.add_child(lbl)

## Bir dugum agacinin birlesik AABB'si (yerel uzayda).
func _aabb_of(root: Node3D) -> AABB:
	var acc := {"a": AABB(), "has": false}
	_collect_aabb(root, Transform3D.IDENTITY, acc)
	return acc["a"]

func _collect_aabb(node: Node, t: Transform3D, acc: Dictionary) -> void:
	var lt := t
	if node is Node3D:
		lt = t * (node as Node3D).transform
	if node is VisualInstance3D:
		var wa: AABB = lt * (node as VisualInstance3D).get_aabb()
		if acc["has"]:
			acc["a"] = (acc["a"] as AABB).merge(wa)
		else:
			acc["a"] = wa
			acc["has"] = true
	for c in node.get_children():
		_collect_aabb(c, lt, acc)

# --- Mesale (gece) ------------------------------------------------------
func _build_torch() -> void:
	_torch = OmniLight3D.new()
	_torch.light_color = Color(1.0, 0.62, 0.28)
	_torch.light_energy = 2.2
	_torch.omni_range = 5.5
	_torch.shadow_enabled = false
	_torch.position = Vector3(SPACING, 1.4, 1.2)  # ilk modelin yaninda
	_torch.visible = false
	add_child(_torch)

# --- Kamera (oyun acisi/zoom) ------------------------------------------
func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.fov = CAM_FOV
	var p := deg_to_rad(CAM_PITCH)
	var dist := maxf(CAM_DIST, _row_center_x * 1.15)
	var target := Vector3(_row_center_x, DISPLAY_H * 0.45, 0)
	cam.position = target + Vector3(0, sin(p), cos(p)) * dist
	cam.rotation_degrees = Vector3(-CAM_PITCH, 0, 0)
	cam.current = true
	add_child(cam)

# --- UI: mobil dokunma butonu + baslik + klavye ------------------------
func _build_ui(models: Array) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.position = Vector2(16, 12)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.text = "STIL VITRIN — %d model  (Boşluk / buton: Gündüz-Gece)" % models.size()
	layer.add_child(title)
	_toggle_btn = Button.new()
	_toggle_btn.text = "🌙 Gece"
	_toggle_btn.position = Vector2(16, 48)
	_toggle_btn.size = Vector2(150, 54)
	_toggle_btn.add_theme_font_size_override("font_size", 20)
	_toggle_btn.pressed.connect(_toggle_daynight)
	layer.add_child(_toggle_btn)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_SPACE:
			_toggle_daynight()

func _toggle_daynight() -> void:
	_is_night = not _is_night
	_apply_daynight()

func _apply_daynight() -> void:
	var p := NIGHT if _is_night else DAY
	_sun.light_color = p["sun_col"]
	_sun.light_energy = p["sun_energy"]
	_env.ambient_light_energy = p["ambient"]
	_sky_mat.sky_top_color = p["sky_top"]
	_sky_mat.sky_horizon_color = p["sky_hor"]
	_torch.visible = _is_night
	if _toggle_btn != null:
		_toggle_btn.text = "☀ Gündüz" if _is_night else "🌙 Gece"

func _process(delta: float) -> void:
	# Gece mesale titresimi (oyundaki his)
	if _is_night and _torch != null:
		_t += delta
		_torch.light_energy = 2.2 * (0.86 + 0.14 * sin(_t * 11.0))
