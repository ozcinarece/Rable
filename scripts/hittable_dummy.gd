extends Node3D
## TEST KUKLASI (ALET_SISTEMI.md 12.7). Silah testlerinin hedefi.
##
## take_hit(damage, knockback_dir) ARAYUZU burada tanimlanir; yaratiklar
## geldiginde AYNI imzayi kullanacak (12.5 sinir). Bu dosya yaratik
## davranisi DEGIL — sadece vurulan, sarsilan, devrilip yenilenen kukla.

signal died

const MAX_HP := 40

var hp := MAX_HP
var _alive := true
var _body: Node3D
var _bar_fill: MeshInstance3D
var _bar_bg: MeshInstance3D
var _home := Vector3.ZERO

func _ready() -> void:
	_home = position
	_build_visual()
	_build_health_bar()

func _build_visual() -> void:
	_body = Node3D.new()
	add_child(_body)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.80, 0.62, 0.42)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.38, 0.22)
	# Direk govde
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.09; pm.bottom_radius = 0.11; pm.height = 0.9
	post.mesh = pm; post.material_override = wood
	post.position = Vector3(0, 0.45, 0)
	_body.add_child(post)
	# Kollar (yatay cubuk)
	var arms := MeshInstance3D.new()
	var am := BoxMesh.new(); am.size = Vector3(0.7, 0.08, 0.08)
	arms.mesh = am; arms.material_override = wood
	arms.position = Vector3(0, 0.72, 0)
	_body.add_child(arms)
	# Kafa (bez torba)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new(); hm.radius = 0.16; hm.height = 0.32
	head.mesh = hm; head.material_override = cloth
	head.position = Vector3(0, 1.0, 0)
	_body.add_child(head)
	# Govde gobek
	var torso := MeshInstance3D.new()
	var tm := SphereMesh.new(); tm.radius = 0.2; tm.height = 0.44
	torso.mesh = tm; torso.material_override = cloth
	torso.position = Vector3(0, 0.62, 0)
	_body.add_child(torso)

func _build_health_bar() -> void:
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.15, 0.12, 0.10)
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.no_depth_test = true
	_bar_bg = MeshInstance3D.new()
	var bgq := QuadMesh.new(); bgq.size = Vector2(0.62, 0.10)
	_bar_bg.mesh = bgq; _bar_bg.material_override = bg_mat
	_bar_bg.position = Vector3(0, 1.35, 0)
	add_child(_bar_bg)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = Color(0.45, 0.80, 0.42)
	fill_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fill_mat.no_depth_test = true
	_bar_fill = MeshInstance3D.new()
	var fq := QuadMesh.new(); fq.size = Vector2(0.58, 0.06)
	_bar_fill.mesh = fq; _bar_fill.material_override = fill_mat
	_bar_fill.position = Vector3(0, 1.35, 0.001)
	add_child(_bar_fill)
	_bar_bg.visible = false
	_bar_fill.visible = false

## VURULABILIR ARAYUZ (12.5). Yaratiklar da bunu saglayacak.
func take_hit(damage: int, knockback_dir: Vector3) -> void:
	if not _alive:
		return
	hp = maxi(0, hp - damage)
	_show_bar()
	_update_bar()
	_react(knockback_dir)
	if hp <= 0:
		_topple()

func _update_bar() -> void:
	var ratio := float(hp) / float(MAX_HP)
	_bar_fill.scale.x = maxf(0.001, ratio)
	# Sola hizala: olcek merkezden oldugu icin kaydir
	_bar_fill.position.x = -0.29 * (1.0 - ratio)
	var mat := _bar_fill.material_override as StandardMaterial3D
	if mat != null:
		mat.albedo_color = Color(0.85, 0.35, 0.30) if ratio < 0.35 \
				else Color(0.45, 0.80, 0.42)

func _show_bar() -> void:
	_bar_bg.visible = true
	_bar_fill.visible = true

## Sarsilma + knockback (his kalibrasyonu buradan — 12.7)
func _react(knockback_dir: Vector3) -> void:
	var tw := create_tween()
	# Vurus yonune kucuk egilme + geri
	var push: Vector3 = knockback_dir.normalized() * 0.12
	tw.tween_property(_body, "position", push, 0.05) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_body, "position", Vector3.ZERO, 0.18) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# Hafif olcek jiggle
	var tw2 := create_tween()
	tw2.tween_property(_body, "scale", Vector3(1.12, 0.9, 1.12), 0.05)
	tw2.tween_property(_body, "scale", Vector3.ONE, 0.18) \
			.set_trans(Tween.TRANS_ELASTIC)

## Devrilir, 3 sn sonra yenilenir (12.7)
func _topple() -> void:
	_alive = false
	died.emit()
	_bar_bg.visible = false
	_bar_fill.visible = false
	var tw := create_tween()
	tw.tween_property(_body, "rotation_degrees:x", -85.0, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	get_tree().create_timer(3.0).timeout.connect(_respawn)

func _respawn() -> void:
	if not is_instance_valid(self):
		return
	hp = MAX_HP
	_alive = true
	_body.rotation_degrees = Vector3.ZERO
	_body.position = Vector3.ZERO
	_body.scale = Vector3.ONE
	_update_bar()
	_bar_bg.visible = false
	_bar_fill.visible = false

func is_alive() -> bool:
	return _alive
