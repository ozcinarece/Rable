extends CharacterBody2D
## Basit 8 yonlu top-down oyuncu hareketi.
## Klavye (WASD + ok tuslari) ve dokunmatik (parmagi surukleme) ile calisir.
## Ileride envanter, kazma gibi sistemler bu script'e dokunmadan
## ayri script'ler olarak eklenebilir (ornegin ayri bir Inventory.gd).

@export var speed: float = 200.0  # piksel / saniye

# Dokunmatik kontrol icin: parmagin ilk bastigi nokta ve su anki konumu.
# Parmak-surukleme, basit bir "sanal joystick" gibi davranir:
# parmagi bastigin yerden ne kadar uzaklastirirsan o yone o kadar hizli gidersin.
var _touch_start_position: Vector2 = Vector2.ZERO
var _touch_current_position: Vector2 = Vector2.ZERO
var _is_touching: bool = false

func _physics_process(_delta: float) -> void:
	var direction := _get_input_direction()
	velocity = direction * speed
	move_and_slide()

# Klavye veya dokunmatik girdisinden -1..1 araliginda bir yon vektoru uretir.
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
	const DEAD_ZONE: float = 10.0  # kucuk parmak titremelerini yok say
	if offset.length() <= DEAD_ZONE:
		return Vector2.ZERO
	return offset.normalized()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_is_touching = true
			_touch_start_position = event.position
			_touch_current_position = event.position
		else:
			_is_touching = false
	elif event is InputEventScreenDrag:
		_touch_current_position = event.position
