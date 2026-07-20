extends CharacterBody2D
## Gece yaratigi: oyuncuya dogru yurur, degdiginde hasar verir.
## Duvarlar/hendekler onu fiziksel olarak durdurur - savunmanin amaci bu.
## World tarafindan gece dogar, gun dogunca yok edilir.

const SPEED: float = 70.0
const CONTACT_RANGE: float = 22.0
const CONTACT_DAMAGE: float = 10.0
const CONTACT_COOLDOWN: float = 0.8

const TEX := preload("res://assets/player/yaratik.png")

var target: Node2D = null   # oyuncu (World atar)
var hp: int = 30
var trap_cooldown: float = 0.0  # tuzak hasar araligi (World kullanir)

var _sprite: Sprite2D
var _attack_cooldown: float = 0.0

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_mask = 3  # katman 1 (dunya) + katman 2 (kapilar)
	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	_sprite.offset = Vector2(0, -8)
	add_child(_sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	add_child(shape)

func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	trap_cooldown = maxf(0.0, trap_cooldown - delta)
	if target == null:
		return
	var to_player := target.global_position - global_position
	velocity = to_player.normalized() * SPEED
	move_and_slide()
	_sprite.flip_h = to_player.x < 0
	if to_player.length() < CONTACT_RANGE and _attack_cooldown <= 0.0:
		_attack_cooldown = CONTACT_COOLDOWN
		Health.damage(CONTACT_DAMAGE)

## Hasar alir; true donerse oldu. from: geri tepme yonu icin vuran nokta.
func hurt(amount: int, from: Vector2) -> bool:
	hp -= amount
	var away := global_position - from
	if away.length() > 0.5:
		global_position += away.normalized() * 12.0
	modulate = Color(1, 0.5, 0.5)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	return hp <= 0
