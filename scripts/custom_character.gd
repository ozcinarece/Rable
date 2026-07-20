extends Node3D
## "Yuvarlak" karakter - Claude tasarimi, tamamen kod ile insa edilir.
## Kose yok: kure kafa, kapsul govde/kol/bacak, minik yuz.
## Renkler (ten/tisort/pantolon) spec ile secilir; animasyonlar
## proseduraldir (yururken kol-bacak salinimi, dururken nefes).
## Mini karakterlerle ayni olcekte (0.67) insa edilir ki sapka/sac/
## gozluk aksesuarlari birebir uysun.

## player3d ayarlar: "idle" / "walk" / "run"
var motion: String = "idle"

var hand_attach: Node3D  # sag el (alet takma noktasi)
var head_attach: Node3D  # kafa (sapka/sac/gozluk noktasi)

var _t: float = 0.0
var _body: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D

## spec: "tenhex/tisorthex/pantolonhex" (orn. "f2c29b/4fa7d8/5b6b8c")
func setup_from_spec(spec: String) -> void:
	var parts := spec.split("/")
	var skin := Color.from_string(parts[0] if parts.size() > 0 else "", Color(0.95, 0.76, 0.61))
	var shirt := Color.from_string(parts[1] if parts.size() > 1 else "", Color(0.31, 0.65, 0.85))
	var pants := Color.from_string(parts[2] if parts.size() > 2 else "", Color(0.36, 0.42, 0.55))
	_build(skin, shirt, pants)

func _build(skin: Color, shirt: Color, pants: Color) -> void:
	# Bacaklar: kalcadan sallanan kapsuller (koke bagli)
	_leg_l = _limb(self, Vector3(-0.055, 0.17, 0), 0.05, 0.17, pants)
	_leg_r = _limb(self, Vector3(0.055, 0.17, 0), 0.05, 0.17, pants)
	# Ayaklar: yuvarlak minik toplar
	_add_ball(_leg_l, Vector3(0, -0.16, 0.02), 0.055, pants.darkened(0.3))
	_add_ball(_leg_r, Vector3(0, -0.16, 0.02), 0.055, pants.darkened(0.3))

	# Govde: tombul kapsul (kollar ve kafa govdeyle birlikte salinir)
	_body = Node3D.new()
	add_child(_body)
	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.115
	torso_mesh.height = 0.32
	torso.mesh = torso_mesh
	torso.position = Vector3(0, 0.28, 0)
	torso.material_override = _mat(shirt)
	_body.add_child(torso)

	# Kollar: omuzdan sallanan kapsuller (govdeye bagli)
	_arm_l = _limb(_body, Vector3(-0.135, 0.37, 0), 0.042, 0.16, shirt)
	_arm_r = _limb(_body, Vector3(0.135, 0.37, 0), 0.042, 0.16, shirt)
	# Eller: ten rengi minik toplar
	_add_ball(_arm_l, Vector3(0, -0.155, 0), 0.045, skin)
	_add_ball(_arm_r, Vector3(0, -0.155, 0), 0.045, skin)

	# Sag ele alet baglama noktasi
	hand_attach = Node3D.new()
	hand_attach.position = Vector3(0, -0.155, 0.02)
	_arm_r.add_child(hand_attach)

	# Kafa: buyuk yumusak kure
	_head = Node3D.new()
	_head.position = Vector3(0, 0.42, 0)
	_body.add_child(_head)
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.155
	head_mesh.height = 0.29
	var head_inst := MeshInstance3D.new()
	head_inst.mesh = head_mesh
	head_inst.position = Vector3(0, 0.11, 0)
	head_inst.material_override = _mat(skin)
	_head.add_child(head_inst)

	# Yuz: mini karakterler gibi SADE ve yuze yapisik (disari firlamaz):
	# kucuk oval gozler + ayni kosede minik isilti + hafif yanak + minik agiz
	for side in [-1.0, 1.0]:
		# Goz: kucuk dikey oval, yuze yapisik (z'de yassi)
		var eye := SphereMesh.new()
		eye.radius = 0.016
		eye.height = 0.044
		var eye_inst := MeshInstance3D.new()
		eye_inst.mesh = eye
		eye_inst.position = Vector3(side * 0.048, 0.10, 0.148)
		eye_inst.scale = Vector3(1, 1, 0.35)
		eye_inst.material_override = _mat(Color(0.13, 0.11, 0.12))
		_head.add_child(eye_inst)
		# Isilti: iki gozde de ayni kosede tek minik nokta
		var glint := SphereMesh.new()
		glint.radius = 0.005
		glint.height = 0.01
		var glint_inst := MeshInstance3D.new()
		glint_inst.mesh = glint
		glint_inst.position = Vector3(side * 0.048 + 0.006, 0.112, 0.155)
		glint_inst.material_override = _mat(Color(0.99, 0.99, 0.99))
		_head.add_child(glint_inst)
		# Yanak: soluk pembe, yassi, iyice yanda
		var cheek := SphereMesh.new()
		cheek.radius = 0.02
		cheek.height = 0.028
		var cheek_inst := MeshInstance3D.new()
		cheek_inst.mesh = cheek
		cheek_inst.position = Vector3(side * 0.094, 0.058, 0.122)
		cheek_inst.scale = Vector3(1.2, 1, 0.35)
		cheek_inst.material_override = _mat(Color(0.99, 0.74, 0.70))
		_head.add_child(cheek_inst)
	# Agiz: ortada, asagida, minicik koyu oval (yuze yapisik)
	var mouth := SphereMesh.new()
	mouth.radius = 0.013
	mouth.height = 0.018
	var mouth_inst := MeshInstance3D.new()
	mouth_inst.mesh = mouth
	mouth_inst.position = Vector3(0, 0.048, 0.150)
	mouth_inst.scale = Vector3(1.4, 1, 0.35)
	mouth_inst.material_override = _mat(Color(0.42, 0.20, 0.18))
	_head.add_child(mouth_inst)

	# Sapka/sac/gozluk noktasi: kafa tabaninda (mini ile ayni cerceve)
	head_attach = Node3D.new()
	head_attach.position = Vector3(0, 0.02, 0)
	_head.add_child(head_attach)

# Eklemli uzuv: pivot ustte (omuz/kalca), kapsul asagi sarkar
func _limb(parent: Node3D, pivot: Vector3, radius: float, length: float, color: Color) -> Node3D:
	var joint := Node3D.new()
	joint.position = pivot
	parent.add_child(joint)
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = length + radius * 2.0
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = Vector3(0, -length / 2.0, 0)
	inst.material_override = _mat(color)
	joint.add_child(inst)
	return joint

func _add_ball(parent: Node3D, pos: Vector3, radius: float, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	inst.material_override = _mat(color)
	parent.add_child(inst)

func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material

# Prosedurel animasyon: kol-bacak salinimi + nefes/zipla
func _process(delta: float) -> void:
	var freq := 0.0
	var amp := 0.0
	match motion:
		"walk":
			freq = 9.0
			amp = 0.55
		"run":
			freq = 13.0
			amp = 0.85
	_t += delta * (freq if freq > 0.0 else 2.0)
	if freq > 0.0:
		var swing := sin(_t) * amp
		_leg_l.rotation.x = swing
		_leg_r.rotation.x = -swing
		_arm_l.rotation.x = -swing * 0.8
		_arm_r.rotation.x = swing * 0.8
		_body.position.y = absf(sin(_t)) * 0.018
		_body.rotation.x = -0.06 if motion == "run" else 0.0
	else:
		# Bekleme: hafif nefes ve kollar sakin
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, 0.0, 10.0 * delta)
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, 0.0, 10.0 * delta)
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, 0.0, 10.0 * delta)
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, 0.0, 10.0 * delta)
		_body.rotation.x = 0.0
		_body.position.y = sin(_t) * 0.006
