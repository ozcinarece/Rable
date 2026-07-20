extends Area2D
## Yere birakilmis esya: kucuk zipla(yan) ikon.
## Oyuncu ustunden gecince World toplar (body_entered'i World dinler).

var item_id: String = ""
var count: int = 1
var retry_cooldown: float = 0.0  # "envanter dolu" mesaj tekrarini sinirlar

func setup(id: String, amount: int, icon_path: String) -> void:
	item_id = id
	count = amount
	var sprite := Sprite2D.new()
	sprite.texture = load(icon_path)
	sprite.scale = Vector2(0.65, 0.65)
	add_child(sprite)
	# Tatli bir sekilde yerinde salinir
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "position:y", -4.0, 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position:y", 0.0, 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # oyuncu katmani
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)

func _process(delta: float) -> void:
	retry_cooldown = maxf(0.0, retry_cooldown - delta)
