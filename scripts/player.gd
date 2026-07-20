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

## Oyuncunun son baktigi yon. Aksiyon butonu hangi hucreyi
## hedefleyecegini bundan hesaplar; sprite de buna gore secilir.
var facing: Vector2 = Vector2.DOWN

# 3/4 perspektif yon gorselleri, her yon icin 2 kareli yurume animasyonu
# (sol = sag gorselinin aynasi)
const TEXTURES := {
	"down": [preload("res://assets/player/player_down_0.png"), preload("res://assets/player/player_down_1.png")],
	"up": [preload("res://assets/player/player_up_0.png"), preload("res://assets/player/player_up_1.png")],
	"side": [preload("res://assets/player/player_side_0.png"), preload("res://assets/player/player_side_1.png")],
}
const WALK_FRAME_TIME: float = 0.18

@onready var sprite: Sprite2D = $Sprite2D

var _held_sprite: Sprite2D  # eline alinan aletin gorseli
var _walk_timer: float = 0.0
var _walk_frame: int = 0
var _touch_start_position: Vector2 = Vector2.ZERO
var _touch_current_position: Vector2 = Vector2.ZERO
var _touch_start_time: float = 0.0
var _is_touching: bool = false

func _ready() -> void:
	# Top-down oyun: yercekimi/zemin mantigi olmayan serbest hareket modu
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_held_sprite = Sprite2D.new()
	_held_sprite.visible = false
	_held_sprite.scale = Vector2(0.8, 0.8)
	add_child(_held_sprite)
	_update_sprite()

## Eline alinan esyanin ikonunu gosterir; bos yol = eli bos.
func set_held_item(icon_path: String) -> void:
	if icon_path == "":
		_held_sprite.visible = false
		return
	var tex: Texture2D = load(icon_path)
	_held_sprite.texture = tex
	# Yapi gorselleri (32x64) elde kucuk gorunsun
	_held_sprite.scale = Vector2(0.45, 0.45) if tex.get_height() > 40 else Vector2(0.8, 0.8)
	_held_sprite.visible = true
	_update_sprite()

func _physics_process(delta: float) -> void:
	var direction := _get_input_direction()
	if direction != Vector2.ZERO:
		facing = direction
		# Yurume animasyonu: iki kare arasinda gidip gel
		_walk_timer += delta
		if _walk_timer >= WALK_FRAME_TIME:
			_walk_timer = 0.0
			_walk_frame = 1 - _walk_frame
		_update_sprite()
	elif _walk_frame != 0:
		_walk_frame = 0
		_walk_timer = 0.0
		_update_sprite()
	# Aclik/susuzluk sifirsa oyuncu yavaslar (ikisi birden: iyice yavas)
	var slow := 1.0
	if Hunger.is_starving():
		slow *= 0.5
	if Thirst.is_dehydrated():
		slow *= 0.6
	velocity = direction * speed * slow
	move_and_slide()

# Baktigi yone gore dogru gorseli secer (sola bakarken yan gorsel aynalanir)
func _update_sprite() -> void:
	var kind := "down"
	if absf(facing.x) > absf(facing.y):
		kind = "side"
		sprite.flip_h = facing.x < 0
	elif facing.y < 0:
		kind = "up"
		sprite.flip_h = false
	else:
		sprite.flip_h = false
	sprite.texture = TEXTURES[kind][_walk_frame]
	# Eldeki alet, bakilan tarafta dursun
	if _held_sprite != null:
		_held_sprite.position = Vector2(-13.0 if facing.x < 0 else 13.0, -8.0)

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
			if not _is_touching:
				return  # basma olayini arayuz (HUD butonu) yutmus; birakmayi isleme
			_is_touching = false
			var duration := Time.get_ticks_msec() / 1000.0 - _touch_start_time
			var drift := _touch_current_position.distance_to(_touch_start_position)
			if duration <= TAP_MAX_DURATION and drift <= TAP_MAX_DRIFT:
				world_tapped.emit(_screen_to_world(event.position))
	elif event is InputEventScreenDrag:
		_touch_current_position = event.position
	elif event is InputEventMouseButton:
		# Dokunmatikten uretilen sahte fare olaylarini yok say - dokunma
		# zaten yukaridaki ScreenTouch dalinda isleniyor (cift islem olmasin).
		# (Bu emulasyon acik kalmali cunku HUD butonlari ona ihtiyac duyuyor.)
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		# Masaustunde test icin: gercek sol tik da dokunma sayilir
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			world_tapped.emit(get_global_mouse_position())

# Ekran koordinatini (dokunma) dunya koordinatina cevirir;
# kameranin konumu ve zoom'u otomatik hesaba katilir.
func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos
