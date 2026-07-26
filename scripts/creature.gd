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

## GECE DALGASI (minimal) — davranis DURUMU. Mantik world3d'de (bu dosya
## VARLIK), ama sayaclar yaratigin uzerinde yasar.
var attack_cd: float = 0.0   # oyuncuya saldiri beklemesi
var struct_cd: float = 0.0   # yapiya vurus beklemesi
var stuck_time: float = 0.0  # kac saniyedir ilerleyemiyor
var side_time: float = 0.0   # kalan yana kayma suresi
var side_sign: float = 1.0   # hangi yana kayiyor (+1/-1)

# --- YOL BULMA DURUMU (Asama 2) ----------------------------------------
## A* ile bulunan hucre yolu; yaratik dugum dugum izler. Her karede
## yeniden aranmaz (REPATH_SECONDS) — arama pahali, hedef yavas.
var path: Array = []
var path_goal := Vector2i(-999, -999)  # yolun hesaplandigi hedef hucre
var repath_cd: float = 0.0             # yeniden planlamaya kalan sure

var _body: Node3D
var _mat: StandardMaterial3D
var _eye_light: OmniLight3D
var _simplified: bool = false

func setup(creature_type: String, hp_mult: float = 1.0) -> void:
	type = creature_type
	max_hp = maxi(1, int(round(float(Balance.stat(type, "hp", 10)) * hp_mult)))
	hp = max_hp
	speed = float(Balance.stat(type, "speed", 2.0))
	damage = int(Balance.stat(type, "damage", 6))
	essence = int(Balance.stat(type, "essence", 1))
	_build_visual()

## Yol bulmanin okudugu yetenekler. Tabloda yazmayan yetenek = false.
## world.creature_break_cost bunlara bakarak ayni engele farkli maliyet
## verir: tirmanici duvari asar, yuzucu suyu gecer.
func traits() -> Dictionary:
	return {
		"climb": bool(Balance.stat(type, "climb", false)),
		"swim": bool(Balance.stat(type, "swim", false)),
	}

func _build_visual() -> void:
	_body = Node3D.new()
	add_child(_body)
	var scl := float(Balance.stat(type, "scale", 1.0))
	# GLB varsa yükle, yoksa prosedürel low-poly. Yol artık TABLODAN
	# geliyor (Balance.TYPES[...].glb) — dosya adı kodda sabit değil,
	# YARATIKLAR.csv'deki satırla aynı yeri gösteriyor.
	var glb := String(Balance.stat(type, "glb", ""))
	if glb != "" and ResourceLoader.exists(glb):
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
	_eye_light = glow

func cell() -> Vector2i:
	return Vector2i(floori(position.x), floori(position.z))

func is_alive() -> bool:
	return alive

# --- GECE DALGASI yardimcilari (world3d cagirir) -------------------------

## MOBIL PERF: uzaktaki yaratikta goz isigini kapat (en pahali parca).
## Ayni degerle tekrar cagirmak bedavadir (durum korunur).
func set_simplified(on: bool) -> void:
	if on == _simplified:
		return
	_simplified = on
	if _eye_light != null:
		_eye_light.visible = not on

## Gittigi yone donsun (govde yalpasi yok — ucuz).
func face_direction(dir: Vector3) -> void:
	if _body == null or dir.length() < 0.01:
		return
	_body.rotation.y = atan2(dir.x, dir.z)

## Vurus/atilim hissi: kisa one hamle, sonra geri (saldiri geri bildirimi).
func lunge(dir: Vector3) -> void:
	if _body == null:
		return
	var d := dir.normalized() * 0.18
	var tw := create_tween()
	tw.tween_property(_body, "position:x", d.x, 0.08)
	tw.parallel().tween_property(_body, "position:z", d.z, 0.08)
	tw.tween_property(_body, "position:x", 0.0, 0.12)
	tw.parallel().tween_property(_body, "position:z", 0.0, 0.12)

## SAFAK: olmeden erir (oz DUSURMEZ — gunesten kacti, oldurulmedi).
func melt(seconds: float) -> void:
	if not alive:
		return
	alive = false
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

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
