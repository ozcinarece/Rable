extends CharacterBody2D
## Basit 8 yonlu top-down oyuncu hareketi + dokunma (tap) algilama.
##
## Hareket: klavye (WASD + ok tuslari) veya parmagi basip surukleme
## (basit bir "sanal joystick" gibi calisir).
##
## Etkilesim: kisa bir dokunus (parmak kaydirmadan hemen cekilirse)
## "world_tapped" sinyalini yayinlar; World bu sinyali dinleyip
## dokunulan tile'da kaynak toplama vb. islemleri yapar.
## Boylece oyuncu scripti dunya hakkinda hicbir sey bilmek zorunda kalmaz.

## Kisa dokunusta, dokunulan noktanin dunya koordinatiyla yayinlanir.
signal world_tapped(world_pos: Vector2)

@export var speed: float = 200.0  # piksel / saniye

const TAP_MAX_DURATION: float = 0.25  # saniye - bundan uzunsa tap sayilmaz
const TAP_MAX_DRIFT: float = 12.0     # piksel - bundan fazla kaydiysa tap sayilmaz
const DRAG_DEAD_ZONE: float = 10.0    # kucuk parmak titremelerini yok say

var _touch_start_position: Vector2 = Vector2.ZERO
var _touch_current_position: Vector2 = Vector2.ZERO
var _touch_start_time: float = 0.0
var _is_touching: bool = false

func _physics_process(_delta: float) -> void:
	velocity = _get_input_direction() * speed
	move_and_slide()

func _get_input_direction() -> Vector2:
	if _is_touching:
		return _get_touch_direction()
	return _get_keyboard_direction()

func _get_keyboard_direction() -> Vector2:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1
	return direction.normalized()

func _get_touch_direction() -> Vector2:
	var offset := _touch_current_position - _touch_start_position
	if offset.length() <= DRAG_DEAD_ZONE:
		return Vector2.ZERO
	return offset.normalized()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_is_touching = true
			_touch_start_position = event.position
			_touch_current_position = event.position
			_touch_start_time = Time.get_ticks_msec() / 1000.0
		else:
			_is_touching = false
			var duration := Time.get_ticks_msec() / 1000.0 - _touch_start_time
			var drift := _touch_current_position.distance_to(_touch_start_position)
			if duration <= TAP_MAX_DURATION and drift <= TAP_MAX_DRIFT:
				world_tapped.emit(_screen_to_world(event.position))
	elif event is InputEventScreenDrag:
		_touch_current_position = event.position
	elif event is InputEventMouseButton:
		# Masaustunde test icin: sol tik da dokunma sayilir
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			world_tapped.emit(get_global_mouse_position())

# Ekran koordinatini (dokunma) dunya koordinatina cevirir;
# kameranin konumu ve zoom'u otomatik hesaba katilir.
func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos
