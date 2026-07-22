extends Node3D
## YARATIK (BÖLÜM 15.1) — placeholder prosedürel görsel: soğuk palet
## (mor-gri gövde) + TEK parlak göz (turkuaz/mor ışıma). "Sevimli dünyada
## ürkütücü misafir": korku detaydan değil renk+ışık+kalabalıktan.
##
## take_hit(damage, dir) KUKLA İLE AYNI arayüz (12.5) → tüm silahlar gün-1'de
## çalışır. AI/dalga/çevre davranışı DIŞARIDA (world3d/wave); bu dosya VARLIK.
## assets/models/creatures/ altında GLB varsa yüklenir (Meshy hattı hazır).

const Balance = preload("res://scripts/creature_balance.gd")

signal died(cell: Vector2i, essence_item: String, essence_count: int)

var type: String = "normal"
var hp: int = 10
var max_hp: int = 10
var speed: float = 2.0
var damage: int = 6
var essence: int = 1
var alive: bool = true

var _body: Node3D
var _mat: StandardMaterial3D

func setup(creature_type: String, hp_mult: float = 1.0) -> void:
	type = creature_type
	max_hp = maxi(1, int(round(float(Balance.stat(type, "hp", 10)) * hp_mult)))
	hp = max_hp
	speed = float(Balance.stat(type, "speed", 2.0))
	damage = int(Balance.stat(type, "damage", 6))
	essence = int(Balance.stat(type, "essence", 1))
	_build_visual()

func _build_visual() -> void:
	_body = Node3D.new()
	add_child(_body)
	var scl := float(Balance.stat(type, "scale", 1.0))
	# GLB varsa yükle (ileride Meshy), yoksa prosedürel low-poly.
	var glb := "res://assets/models/creatures/%s.glb" % type
	if ResourceLoader.exists(glb):
		var inst: Node3D = load(glb).instantiate()
		inst.scale = Vector3.ONE * scl
		_body.add_child(inst)
		return
	# Gövde: yuvarlak küre, soğuk mor-gri
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.28 * scl; sm.height = 0.56 * scl
	body.mesh = sm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Balance.BODY_COLOR_2 if type == "kirici" else Balance.BODY_COLOR
	_mat.roughness = 0.85
	body.material_override = _mat
	body.position = Vector3(0, 0.32 * scl, 0)
	_body.add_child(body)
	# Tek parlak göz (emissive) + dar göz ışığı (gece hissi)
	var eye_col: Color = Balance.EYE_COLOR
	if String(Balance.stat(type, "eye", "turkuaz")) == "mor":
		eye_col = Balance.EYE_COLOR_ALT
	var eye := MeshInstance3D.new()
	var em := SphereMesh.new(); em.radius = 0.09 * scl; em.height = 0.18 * scl
	eye.mesh = em
	var emat := StandardMaterial3D.new()
	emat.albedo_color = eye_col
	emat.emission_enabled = true
	emat.emission = eye_col
	emat.emission_energy_multiplier = 2.5
	eye.material_override = emat
	eye.position = Vector3(0, 0.42 * scl, 0.22 * scl)
	_body.add_child(eye)
	var glow := OmniLight3D.new()
	glow.light_color = eye_col
	glow.light_energy = 0.8
	glow.omni_range = 1.6
	glow.position = Vector3(0, 0.42 * scl, 0.24 * scl)
	glow.shadow_enabled = false
	_body.add_child(glow)

func cell() -> Vector2i:
	return Vector2i(floori(position.x), floori(position.z))

func is_alive() -> bool:
	return alive

## VURULABİLİR ARAYÜZ (kukla ile AYNI): can, sarsılma, hasar flaşı, ölüm.
func take_hit(dmg: int, knockback_dir: Vector3) -> void:
	if not alive:
		return
	hp = maxi(0, hp - dmg)
	_flash()
	_knock(knockback_dir)
	if hp <= 0:
		_die()

func _flash() -> void:
	if _mat == null:
		return
	var base := _mat.albedo_color
	_mat.albedo_color = Color(1, 1, 1)
	var tw := create_tween()
	tw.tween_interval(0.06)
	tw.tween_callback(func():
		if _mat != null:
			_mat.albedo_color = base)

func _knock(dir: Vector3) -> void:
	if _body == null:
		return
	var push := dir.normalized() * 0.14
	var tw := create_tween()
	tw.tween_property(_body, "position:x", push.x, 0.05)
	tw.parallel().tween_property(_body, "position:z", push.z, 0.05)
	tw.tween_property(_body, "position:x", 0.0, 0.16).set_trans(Tween.TRANS_ELASTIC)
	tw.parallel().tween_property(_body, "position:z", 0.0, 0.16)

## Ölüm (15.1): küçük dağılma + ÖZ düşürür (world dinler). Sonra yok olur.
func _die() -> void:
	if not alive:
		return
	alive = false
	died.emit(cell(), Balance.ESSENCE_ITEM, essence)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.08, 0.08, 0.08), 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
