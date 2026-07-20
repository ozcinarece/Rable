extends Node3D
## 3D oyuncu - Asama B1 yer tutucusu: sevimli kapsul + sapka.
## Hareket ayni 2D'deki gibi: parmagi basip surukle (sanal joystick)
## veya klavye (WASD/ok). Carpisma, fizik motoru yerine dunyanin
## izgara kontroluyle yapilir (basit ve mobilde ucuz).
## B4'te yerini animasyonlu gercek karakter modeli alacak.

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

func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.24
	capsule.height = 0.85
	body.mesh = capsule
	body.position = Vector3(0, 0.46, 0)
	body.material_override = _flat_material(Color(0.93, 0.52, 0.40))
	_visual.add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.19
	head_mesh.height = 0.38
	head.mesh = head_mesh
	head.position = Vector3(0, 0.98, 0)
	head.material_override = _flat_material(Color(0.98, 0.85, 0.70))
	_visual.add_child(head)

	var hat := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.16
	cone.height = 0.24
	hat.mesh = cone
	hat.position = Vector3(0, 1.2, 0)
	hat.material_override = _flat_material(Color(0.98, 0.62, 0.22))
	_visual.add_child(hat)

func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material

func _physics_process(delta: float) -> void:
	var dir := _get_input_direction()
	if dir == Vector2.ZERO:
		return
	facing = dir
	_try_move(Vector3(dir.x, 0, dir.y) * SPEED * delta)
	# Yuruyus yonune yumusakca don
	var target_angle := atan2(-dir.x, -dir.y)
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
