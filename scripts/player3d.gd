extends Node3D
## 3D oyuncu - KayKit Rogue modeli (CC0): zirhsiz, gunluk kiyafetli
## "normal" karakter; yurume/bekleme animasyonlu. Eline alinan alet
## (balta/kazma vs.) sag el kemigine (handslot.r) takilir.
## Hareket ayni 2D'deki gibi: parmagi basip surukle (sanal joystick)
## veya klavye (WASD/ok). Carpisma, fizik motoru yerine dunyanin
## izgara kontroluyle yapilir (basit ve mobilde ucuz).

## Kisa dokunusta ekran konumuyla yayinlanir (World hucreye cevirir)
signal world_tapped(screen_pos: Vector2)

const SPEED: float = 3.6          # yurume hizi (hucre/metre / saniye)
const RUN_SPEED: float = 5.8      # kosma hizi
const RUN_DRAG_PX: float = 110.0  # parmak bu kadar uzaga cekilirse kosar
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

const DEFAULT_MODEL := "res://assets/models/characters/Rogue.glb"
const TARGET_HEIGHT: float = 1.35  # karakterin dunya icindeki boyu (metre)
## Karakter paketleriyle gelen gomulu silah/aksesuar gorselleri (gizlenir)
const EMBEDDED_WEAPONS: Array[String] = ["Knife", "Knife_Offhand",
		"1H_Crossbow", "2H_Crossbow", "Throwable", "Rogue_Cape",
		"1H_Sword", "2H_Sword", "1H_Sword_Offhand", "Badge_Shield",
		"Round_Shield", "Rectangle_Shield", "Spike_Shield", "1H_Axe",
		"2H_Axe", "Mug", "Mage_Hat", "Spellbook", "Spellbook_open"]

const CustomCharScript = preload("res://scripts/custom_character.gd")

var _anim: AnimationPlayer
var _custom_char: CustomCharScript  # "custom:" karakterlerde dolu
var _current_anim: String = ""
var _model_scale: float = 1.0
var _raw_height: float = 0.67  # modelin ham boyu (aksesuar olcek referansi)
var _model_root: Node3D    # aktif karakter modeli
var _tool_attach: Node3D   # eldeki aletin baglandigi nokta
var _head_attach: Node3D   # sapka/gozluk baglanma noktasi (kafa kemigi)
var _held_tool_path: String = ""  # karakter degisince yeniden takmak icin
var _hat_id: String = ""
var _face_path: String = ""
var _hair_style: String = ""  # "" = modelin kendi saci
var _hair_color := Color(0.25, 0.18, 0.12)
# Pakete gore degisen animasyon adlari (otomatik bulunur)
var _anim_idle: String = ""
var _anim_walk: String = ""
var _anim_run: String = ""

func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	set_character(DEFAULT_MODEL)

## Karakter modelini degistirir (Gorunum panelinden secilir).
## "custom:ten/tisort/pantolon" = kendi yuvarlak karakterimiz;
## diger yollar GLB modeli (olcek/animasyon/el kemigi otomatik tanir).
func set_character(model_path: String) -> void:
	if not model_path.begins_with("custom:") and not ResourceLoader.exists(model_path):
		return
	if _model_root != null:
		_model_root.queue_free()
		_model_root = null
	_tool_attach = null
	_head_attach = null
	_anim = null
	_custom_char = null
	_current_anim = ""

	if model_path.begins_with("custom:"):
		var custom: CustomCharScript = CustomCharScript.new()
		custom.setup_from_spec(model_path.substr(7))
		_visual.add_child(custom)
		_model_root = custom
		_custom_char = custom
		_raw_height = 0.67  # mini olcekte insa edildi (aksesuar uyumu)
		_model_scale = TARGET_HEIGHT / _raw_height
		custom.scale = Vector3(_model_scale, _model_scale, _model_scale)
		_tool_attach = custom.hand_attach
		_head_attach = custom.head_attach
		_anim_idle = "idle"
		_anim_walk = "walk"
		_anim_run = "run"
		set_held_tool(_held_tool_path)
		set_hat(_hat_id)
		set_face(_face_path)
		set_hair(_hair_style, _hair_color)
		return

	var model: Node3D = load(model_path).instantiate()
	_visual.add_child(model)
	_model_root = model
	# Model hangi olcekte gelirse gelsin boyunu TARGET_HEIGHT'a getir
	var mesh_node := _find_mesh_instance(model)
	if mesh_node != null:
		var height: float = mesh_node.get_aabb().size.y
		if height > 0.01:
			_raw_height = height
			_model_scale = TARGET_HEIGHT / height
			model.scale = Vector3(_model_scale, _model_scale, _model_scale)
	# Paketle gelen silah/aksesuar gorselleri kapansin (sade gorunum)
	for weapon_name in EMBEDDED_WEAPONS:
		var weapon := model.find_child(weapon_name, true, false)
		if weapon != null and weapon is Node3D:
			(weapon as Node3D).visible = false
	# Alet baglama noktasi: sag el kemigi (yoksa govde onunde yedek nokta)
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	if skeleton == null:
		skeleton = model.find_child("*Skeleton*", true, false)
	if skeleton != null:
		var bone_idx := _find_hand_bone(skeleton)
		if bone_idx != -1:
			var attach := BoneAttachment3D.new()
			skeleton.add_child(attach)
			attach.bone_name = skeleton.get_bone_name(bone_idx)
			_tool_attach = attach
	if _tool_attach == null:
		_tool_attach = Node3D.new()
		_tool_attach.position = Vector3(0.28, 0.75, 0.18)
		_visual.add_child(_tool_attach)
	# Sapka/gozluk baglanma noktasi: kafa kemigi
	_head_attach = null
	if skeleton != null:
		for i in skeleton.get_bone_count():
			if skeleton.get_bone_name(i).to_lower().contains("head"):
				var head_att := BoneAttachment3D.new()
				skeleton.add_child(head_att)
				head_att.bone_name = skeleton.get_bone_name(i)
				_head_attach = head_att
				break
	if _head_attach == null:
		_head_attach = Node3D.new()
		_head_attach.position = Vector3(0, _raw_height * 0.85, 0)
		model.add_child(_head_attach)
	# Animasyonlari otomatik bul (paketlerde adlar degisir) ve dongulet
	_anim = model.find_child("AnimationPlayer", true, false)
	_detect_animations()
	if _anim_idle != "":
		_play(_anim_idle)
	# Eldeki alet ve aksesuarlar yeni karaktere de takilsin
	set_held_tool(_held_tool_path)
	set_hat(_hat_id)
	set_face(_face_path)
	set_hair(_hair_style, _hair_color)

# Sag el kemigini bulur: once "handslot", sonra "hand", sonra "arm"
# (Kenney mini karakterlerde el kemigi yok, "arm-right" var)
func _find_hand_bone(skeleton: Skeleton3D) -> int:
	var best_hand := -1
	var best_arm := -1
	for i in skeleton.get_bone_count():
		var lower := skeleton.get_bone_name(i).to_lower()
		var right := lower.ends_with(".r") or lower.ends_with("_r") \
				or lower.contains("right")
		if not right:
			continue
		if lower.contains("handslot"):
			return i
		if lower.contains("hand") and best_hand == -1:
			best_hand = i
		if lower.contains("arm") and best_arm == -1:
			best_arm = i
	return best_hand if best_hand != -1 else best_arm

# Idle/yurume/kosma animasyonlarini ada gore esnek bulur
func _detect_animations() -> void:
	_anim_idle = ""
	_anim_walk = ""
	_anim_run = ""
	if _anim == null:
		return
	for anim_name in _anim.get_animation_list():
		var lower := String(anim_name).to_lower()
		if _anim_idle == "" and lower.contains("idle"):
			_anim_idle = anim_name
		if _anim_walk == "" and lower.contains("walk") \
				and not lower.contains("back"):
			_anim_walk = anim_name
		if _anim_run == "" and (lower.contains("run") or lower.contains("sprint")):
			_anim_run = anim_name
	# Tercih: tam adlar varsa onlari kullan (KayKit)
	for pair in [["Idle", "idle"], ["Walking_A", "walk"], ["Running_A", "run"]]:
		if _anim.has_animation(pair[0]):
			match pair[1]:
				"idle": _anim_idle = pair[0]
				"walk": _anim_walk = pair[0]
				"run": _anim_run = pair[0]
	if _anim_run == "":
		_anim_run = _anim_walk
	for anim_name in [_anim_idle, _anim_walk, _anim_run]:
		if anim_name != "" and _anim.has_animation(anim_name):
			_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR

## Eldeki aletin 3D modelini ele takar; bos yol = eli bosalt.
## "spear" ozel degeri: pakette mizrak yok, basit bir tane insa edilir.
func set_held_tool(model_path: String) -> void:
	_held_tool_path = model_path
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

# --- Aksesuarlar (sapka + yuz) ------------------------------------------

## Sapka takar ("yok" veya "" = cikar). Sapkalar kod ile insa edilir;
## mini kafa olcusune gore tasarlanmistir, diger boylara olceklenir.
func set_hat(hat_id: String) -> void:
	_hat_id = hat_id
	if _head_attach == null:
		return
	for child in _head_attach.get_children():
		if String(child.name).begins_with("Hat"):
			child.queue_free()
	if hat_id == "" or hat_id == "yok":
		return
	var hat := _make_hat(hat_id)
	hat.name = "Hat"
	var f := _acc_scale()
	hat.scale = Vector3(f, f, f)
	_head_attach.add_child(hat)

## Yuz aksesuari takar: gozluk/maske GLB yolu ("" = cikar).
## Modeller mini kafa pivotuna gore hizali gelir (ayni paketten).
func set_face(model_path: String) -> void:
	_face_path = model_path
	if _head_attach == null:
		return
	for child in _head_attach.get_children():
		if String(child.name).begins_with("Face"):
			child.queue_free()
	if model_path == "" or not ResourceLoader.exists(model_path):
		return
	var inst: Node3D = load(model_path).instantiate()
	inst.name = "Face"
	var f := _acc_scale()
	inst.scale = Vector3(f, f, f)
	_head_attach.add_child(inst)

# Aksesuarlar mini boyuna (0.67) gore tasarlandi; baska govdede olcekle
func _acc_scale() -> float:
	return _raw_height / 0.67

## Sac takar: stil ("" = modelin kendi saci) + renk. Kendi tasarimimiz
## olan sac modelleri kafanin ustune giydirilir; stil ve renk serbest.
func set_hair(style: String, color: Color) -> void:
	_hair_style = style
	_hair_color = color
	if _head_attach == null:
		return
	for child in _head_attach.get_children():
		if String(child.name).begins_with("Hair"):
			child.queue_free()
	if style == "" or style == "yok":
		return
	var hair := _make_hair(style, color)
	hair.name = "Hair"
	var f := _acc_scale()
	hair.scale = Vector3(f, f, f)
	_head_attach.add_child(hair)

# Sac: gercek "kesim" gibi sekilli tasarimlar. Duz kubbe tas gibi
# durdugu icin her stilde percemler (kakul), yan tutamlar, tepe
# lobeleri ve minik tepe tutami var - tas gorunumunu bunlar kirar.
func _make_hair(style: String, color: Color) -> Node3D:
	var hair := Node3D.new()
	# Taban: kafayi saran alcak kep (tek basina degil, uzeri sekillenir)
	var dome := SphereMesh.new()
	dome.radius = 0.175
	dome.height = 0.17
	dome.is_hemisphere = true
	hair.add_child(_hat_part(dome, color, Vector3(0, 0.12, -0.015)))
	# Percemler: alinda 5 yuvarlak tutamlik kakul sirasi
	for i in 5:
		var a := deg_to_rad(-52.0 + 26.0 * i)
		var bang := SphereMesh.new()
		bang.radius = 0.048
		bang.height = 0.075
		hair.add_child(_hat_part(bang, color,
				Vector3(sin(a) * 0.145, 0.135, cos(a) * 0.145 - 0.005)))
	# Yan tutamlar: kulak ustlerini ortier
	var side_lock := SphereMesh.new()
	side_lock.radius = 0.06
	side_lock.height = 0.11
	hair.add_child(_hat_part(side_lock, color, Vector3(0.15, 0.105, 0.0)))
	hair.add_child(_hat_part(side_lock, color, Vector3(-0.15, 0.105, 0.0)))
	# Ense dolgusu
	var nape := SphereMesh.new()
	nape.radius = 0.115
	nape.height = 0.17
	hair.add_child(_hat_part(nape, color, Vector3(0, 0.10, -0.095)))
	# Tepe lobeleri: kubbenin duzlugunu kiran hacim yumrulari
	var lobe_a := SphereMesh.new()
	lobe_a.radius = 0.105
	lobe_a.height = 0.15
	hair.add_child(_hat_part(lobe_a, color, Vector3(0.065, 0.205, 0.03)))
	var lobe_b := SphereMesh.new()
	lobe_b.radius = 0.095
	lobe_b.height = 0.14
	hair.add_child(_hat_part(lobe_b, color, Vector3(-0.06, 0.21, -0.045)))
	# Tepe tutami: hafif yatik minik ahoge
	var tuft := CapsuleMesh.new()
	tuft.radius = 0.022
	tuft.height = 0.10
	hair.add_child(_hat_part(tuft, color, Vector3(0.02, 0.285, 0.02),
			Vector3(18, 0, -28)))
	match style:
		"kut":
			pass  # sekilli kisa kesim (taban set yeterli)
		"sivri":
			# Disari yatik sivri tutamlar (dagilmis dinamik gorunum)
			for i in 6:
				var angle := TAU * i / 6.0 + 0.3
				var spike := CylinderMesh.new()
				spike.top_radius = 0.0
				spike.bottom_radius = 0.042
				spike.height = 0.12
				hair.add_child(_hat_part(spike, color,
						Vector3(cos(angle) * 0.10, 0.26, sin(angle) * 0.10 - 0.01),
						Vector3(sin(angle) * 32.0, 0, -cos(angle) * 32.0)))
		"topuz":
			var bun := SphereMesh.new()
			bun.radius = 0.085
			bun.height = 0.15
			hair.add_child(_hat_part(bun, color, Vector3(0, 0.275, -0.11)))
			var band := TorusMesh.new()
			band.inner_radius = 0.05
			band.outer_radius = 0.075
			hair.add_child(_hat_part(band, color.darkened(0.35),
					Vector3(0, 0.235, -0.115), Vector3(60, 0, 0)))
		"uzun":
			# Omuzlara sarkan yumusak tutamlar (hafif disa yatik)
			var lock := CapsuleMesh.new()
			lock.radius = 0.05
			lock.height = 0.30
			hair.add_child(_hat_part(lock, color, Vector3(0.15, 0.03, -0.02),
					Vector3(0, 0, -8)))
			hair.add_child(_hat_part(lock, color, Vector3(-0.15, 0.03, -0.02),
					Vector3(0, 0, 8)))
			var back_lock := CapsuleMesh.new()
			back_lock.radius = 0.08
			back_lock.height = 0.34
			hair.add_child(_hat_part(back_lock, color, Vector3(0, 0.02, -0.125),
					Vector3(6, 0, 0)))
	return hair

func _make_hat(hat_id: String) -> Node3D:
	var hat := Node3D.new()
	match hat_id:
		"hasir":
			# Genis kenarli hasir sapka
			hat.add_child(_hat_part(_cyl(0.26, 0.26, 0.025), Color(0.89, 0.78, 0.45), Vector3(0, 0.20, 0)))
			hat.add_child(_hat_part(_cyl(0.13, 0.15, 0.1), Color(0.92, 0.82, 0.50), Vector3(0, 0.26, 0)))
			hat.add_child(_hat_part(_cyl(0.155, 0.155, 0.03), Color(0.55, 0.38, 0.22), Vector3(0, 0.225, 0)))
		"bere":
			var dome := SphereMesh.new()
			dome.radius = 0.17
			dome.height = 0.2
			hat.add_child(_hat_part(dome, Color(0.85, 0.28, 0.32), Vector3(0, 0.23, 0)))
			var pom := SphereMesh.new()
			pom.radius = 0.045
			pom.height = 0.09
			hat.add_child(_hat_part(pom, Color(0.98, 0.96, 0.92), Vector3(0, 0.34, 0)))
		"kasket":
			var top := SphereMesh.new()
			top.radius = 0.16
			top.height = 0.19
			hat.add_child(_hat_part(top, Color(0.28, 0.48, 0.78), Vector3(0, 0.22, 0)))
			var visor := BoxMesh.new()
			visor.size = Vector3(0.2, 0.02, 0.13)
			hat.add_child(_hat_part(visor, Color(0.22, 0.38, 0.62), Vector3(0, 0.21, 0.17)))
		"tac":
			hat.add_child(_hat_part(_cyl(0.14, 0.14, 0.07), Color(0.95, 0.78, 0.25), Vector3(0, 0.24, 0)))
			for i in 4:
				var spike := CylinderMesh.new()
				spike.top_radius = 0.0
				spike.bottom_radius = 0.03
				spike.height = 0.07
				var angle := TAU * i / 4.0
				hat.add_child(_hat_part(spike, Color(0.95, 0.78, 0.25),
						Vector3(cos(angle) * 0.11, 0.31, sin(angle) * 0.11)))
		"parti":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.11
			cone.height = 0.26
			hat.add_child(_hat_part(cone, Color(0.95, 0.45, 0.70), Vector3(0, 0.33, 0)))
			var pom2 := SphereMesh.new()
			pom2.radius = 0.035
			pom2.height = 0.07
			hat.add_child(_hat_part(pom2, Color(0.98, 0.9, 0.3), Vector3(0, 0.47, 0)))
		"cicek":
			hat.add_child(_hat_part(_cyl(0.16, 0.16, 0.035), Color(0.38, 0.62, 0.30), Vector3(0, 0.22, 0)))
			var petal_colors := [Color(0.95, 0.5, 0.6), Color(0.98, 0.85, 0.35),
					Color(0.75, 0.55, 0.9), Color(0.95, 0.5, 0.6), Color(0.98, 0.85, 0.35)]
			for i in 5:
				var flower := SphereMesh.new()
				flower.radius = 0.035
				flower.height = 0.07
				var angle := TAU * i / 5.0
				hat.add_child(_hat_part(flower, petal_colors[i],
						Vector3(cos(angle) * 0.15, 0.235, sin(angle) * 0.15)))
	return hat

func _cyl(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	return mesh

func _hat_part(mesh: Mesh, color: Color, pos: Vector3,
		rot_degrees: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = pos
	part.rotation_degrees = rot_degrees
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	part.material_override = material
	return part

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
	if anim_name == "" or _current_anim == anim_name:
		return
	if _custom_char != null:
		_current_anim = anim_name
		_custom_char.motion = anim_name  # prosedurel animasyon
		return
	if _anim == null or not _anim.has_animation(anim_name):
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
		_play(_anim_idle)
		return
	facing = dir
	# Kosma: parmagi uzaga cek (veya klavyede Shift)
	var running := _wants_run()
	_play(_anim_run if running else _anim_walk)
	var speed := RUN_SPEED if running else SPEED
	_try_move(Vector3(dir.x, 0, dir.y) * speed * delta)
	# Yuruyus yonune yumusakca don (model +Z yonune bakar)
	var target_angle := atan2(dir.x, dir.y)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, target_angle, 12.0 * delta)

func _wants_run() -> bool:
	if _is_touching:
		return (_touch_current - _touch_start).length() >= RUN_DRAG_PX
	return Input.is_key_pressed(KEY_SHIFT)

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
