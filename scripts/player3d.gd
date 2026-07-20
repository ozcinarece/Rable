extends Node3D
## 3D oyuncu - KayKit Rogue modeli (CC0): zirhsiz, gunluk kiyafetli
## "normal" karakter; yurume/bekleme animasyonlu. Eline alinan alet
## (balta/kazma vs.) sag el kemigine (handslot.r) takilir.
## Hareket ayni 2D'deki gibi: parmagi basip surukle (sanal joystick)
## veya klavye (WASD/ok). Carpisma, fizik motoru yerine dunyanin
## izgara kontroluyle yapilir (basit ve mobilde ucuz).

## Kisa dokunusta ekran konumuyla yayinlanir (World hucreye cevirir)
signal world_tapped(screen_pos: Vector2)

const SPEED: float = 3.6          # hucre (metre) / saniye
const DRAG_DEAD_ZONE: float = 10.0
const TAP_MAX_DURATION: float = 0.25
const TAP_MAX_DRIFT: float = 12.0
const BODY_RADIUS: float = 0.27   # duvarlara bu kadar yaklasabilir

var world: Node3D  # world3d atar; is_walkable(cell) saglar
var facing := Vector2(0, 1)  # son yuruyus yonu (aksiyon butonu hedefi)

var _visual: Node3D
var _is_touching := false
var _touch_start := Vector2.ZERO
var _touch_current := Vector2.ZERO
var _touch_start_time := 0.0

const MODEL_PATH := "res://assets/models/characters/Rogue.glb"
const TARGET_HEIGHT: float = 1.35  # karakterin dunya icindeki boyu (metre)
## Karakter paketiyle gelen gomulu silahlar (normal gorunum icin gizlenir)
const EMBEDDED_WEAPONS: Array[String] = ["Knife", "Knife_Offhand",
		"1H_Crossbow", "2H_Crossbow", "Throwable", "Rogue_Cape"]

var _anim: AnimationPlayer
var _current_anim: String = ""
var _model_scale: float = 1.0
var _tool_attach: Node3D  # eldeki aletin baglandigi nokta

func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)

	var model: Node3D = load(MODEL_PATH).instantiate()
	_visual.add_child(model)
	# Model hangi olcekte gelirse gelsin boyunu TARGET_HEIGHT'a getir
	var mesh_node := _find_mesh_instance(model)
	if mesh_node != null:
		var height: float = mesh_node.get_aabb().size.y
		if height > 0.01:
			_model_scale = TARGET_HEIGHT / height
			model.scale = Vector3(_model_scale, _model_scale, _model_scale)
	# Paketle gelen silah/pelerin gorselleri kapansin (koylu gorunumu)
	for weapon_name in EMBEDDED_WEAPONS:
		var weapon := model.find_child(weapon_name, true, false)
		if weapon != null and weapon is Node3D:
			(weapon as Node3D).visible = false
	# Alet baglama noktasi: sag el kemigi (yoksa govde onunde yedek nokta)
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	if skeleton == null:
		skeleton = model.find_child("*Skeleton*", true, false)
	if skeleton != null:
		for bone_name in ["handslot.r", "handslot_r", "hand.r", "hand_r"]:
			if skeleton.find_bone(bone_name) != -1:
				var attach := BoneAttachment3D.new()
				skeleton.add_child(attach)
				attach.bone_name = bone_name
				_tool_attach = attach
				break
	if _tool_attach == null:
		_tool_attach = Node3D.new()
		_tool_attach.position = Vector3(0.28, 0.75, 0.18)
		_visual.add_child(_tool_attach)
	# Animasyonlar gltf'ten donguye alinmadan gelir; elle donguletiyoruz
	_anim = model.find_child("AnimationPlayer", true, false)
	if _anim != null:
		for anim_name in ["Idle", "Walking_A", "Running_A"]:
			if _anim.has_animation(anim_name):
				_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		_play("Idle")

## Eldeki aletin 3D modelini ele takar; bos yol = eli bosalt.
## "spear" ozel degeri: pakette mizrak yok, basit bir tane insa edilir.
func set_held_tool(model_path: String) -> void:
	if _tool_attach == null:
		return
	for child in _tool_attach.get_children():
		child.queue_free()
	if model_path == "":
		return
	if model_path == "spear":
		_tool_attach.add_child(_make_spear())
		return
	if not ResourceLoader.exists(model_path):
		return
	var tool_model: Node3D = load(model_path).instantiate()
	_tool_attach.add_child(tool_model)
	# Alet gercek boyutta ~0.5 m gorunsun (iskelet olcegini telafi et)
	var mesh_node := _find_mesh_instance(tool_model)
	if mesh_node != null:
		var size: float = mesh_node.get_aabb().get_longest_axis_size()
		if size > 0.01 and _model_scale > 0.001:
			var s := 0.5 / (size * _model_scale)
			tool_model.scale = Vector3(s, s, s)

# Basit mizrak: ahsap sap + gri sivri uc (elde ~0.9 m gorunur)
func _make_spear() -> Node3D:
	var spear := Node3D.new()
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.02
	shaft_mesh.bottom_radius = 0.02
	shaft_mesh.height = 0.75
	shaft.mesh = shaft_mesh
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.38, 0.22)
	shaft.material_override = wood
	spear.add_child(shaft)
	var tip := MeshInstance3D.new()
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.0
	tip_mesh.bottom_radius = 0.045
	tip_mesh.height = 0.16
	tip.mesh = tip_mesh
	tip.position = Vector3(0, 0.45, 0)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.72, 0.74, 0.78)
	tip.material_override = metal
	spear.add_child(tip)
	# Iskelet olcegini telafi et
	if _model_scale > 0.001:
		var s := 1.0 / _model_scale
		spear.scale = Vector3(s, s, s)
	return spear

func _play(anim_name: String) -> void:
	if _anim == null or _current_anim == anim_name:
		return
	if not _anim.has_animation(anim_name):
		return
	_current_anim = anim_name
	_anim.play(anim_name, 0.2)  # 0.2 sn yumusak gecis

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null

func _physics_process(delta: float) -> void:
	var dir := _get_input_direction()
	if dir == Vector2.ZERO:
		_play("Idle")
		return
	facing = dir
	_play("Walking_A")
	_try_move(Vector3(dir.x, 0, dir.y) * SPEED * delta)
	# Yuruyus yonune yumusakca don (model +Z yonune bakar)
	var target_angle := atan2(dir.x, dir.y)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, target_angle, 12.0 * delta)

# Eksenleri ayri dener: duvara surtununce diger eksende kaymaya devam
func _try_move(offset: Vector3) -> void:
	var pos := position
	var next_x := pos + Vector3(offset.x, 0, 0)
	if _pos_walkable(next_x):
		pos = next_x
	var next_z := pos + Vector3(0, 0, offset.z)
	if _pos_walkable(next_z):
		pos = next_z
	position = pos

# Govde yaricapi kadar 4 noktadan izgara kontrolu
func _pos_walkable(pos: Vector3) -> bool:
	for off in [Vector2(BODY_RADIUS, 0), Vector2(-BODY_RADIUS, 0),
			Vector2(0, BODY_RADIUS), Vector2(0, -BODY_RADIUS)]:
		var cell := Vector2i(floori(pos.x + off.x), floori(pos.z + off.y))
		if not world.is_walkable(cell):
			return false
	return true

# --- Girdi (2D oyuncuyla ayni desen) ------------------------------------

func _get_input_direction() -> Vector2:
	if _is_touching:
		var offset := _touch_current - _touch_start
		if offset.length() <= DRAG_DEAD_ZONE:
			return Vector2.ZERO
		return offset.normalized()
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	return dir.normalized()

func _unhandled_input(event: InputEvent) -> void:
	# Sadece ilk parmak hareket ettirir (2. parmak kamera yakinlastirma)
	if event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			_is_touching = true
			_touch_start = event.position
			_touch_current = event.position
			_touch_start_time = Time.get_ticks_msec() / 1000.0
		else:
			if not _is_touching:
				return  # basma olayini arayuz yutmus; birakmayi isleme
			_is_touching = false
			var duration := Time.get_ticks_msec() / 1000.0 - _touch_start_time
			var drift := _touch_current.distance_to(_touch_start)
			if duration <= TAP_MAX_DURATION and drift <= TAP_MAX_DRIFT:
				world_tapped.emit(event.position)
	elif event is InputEventScreenDrag and event.index == 0:
		_touch_current = event.position
	elif event is InputEventMouseButton:
		# Dokunmatikten uretilen sahte fare olaylarini yok say
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		# Masaustunde test: gercek sol tik da dokunma sayilir
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			world_tapped.emit(event.position)
