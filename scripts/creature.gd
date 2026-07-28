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

# --- MODEL/ANIMASYON durumu (yaratik-gece) -------------------------------
var daze: float = 0.0            # dogma sersemligi: bu sure AI islemez
var _anim: AnimationPlayer = null
var _walk_anim: String = ""
var _glb_mats: Array = []        # emission kontrolu icin kopya materyaller
var _moving: bool = false
var _night_on: bool = false
var _in_light: bool = false

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

## Model yolu cozumleyici. Tabloda yol assets/models/creatures/ altini
## gosteriyor ama modeller GitHub web arayuzunden cogunlukla
## assets/models/test/ altina yukleniyor. Ikisine de bakiliyor: dosya
## hangi klasordeyse oradan alinir, yoksa "" doner (proseduerel govde).
func _resolve_glb(yol: String) -> String:
	if yol == "":
		return ""
	if ResourceLoader.exists(yol):
		return yol
	var alt := "res://assets/models/test/" + yol.get_file()
	return alt if ResourceLoader.exists(alt) else ""

## Tum MeshInstance3D'lerin birlesik AABB'si — verilen kok dugumun
## UZAYINDA. Mesh'in ham AABB'si YETMEZ: rig'li GLB'lerde Armature 0.01
## olcekle geliyor (creature_2'de olculdu) ve ham AABB'yle hesaplanan
## olcek yaratigi toz zerresine cevirdi. Ara dugum donusumlerini katarak
## olculuyor.
func _aabb_of(node: Node) -> AABB:
	var out := AABB()
	var ilk := true
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var n: Node3D = mi
		while n != null and n != node:
			xf = n.transform * xf
			n = n.get_parent() as Node3D
		var a := xf * mi.mesh.get_aabb()
		if ilk:
			out = a
			ilk = false
		else:
			out = out.merge(a)
	return out

func _build_visual() -> void:
	_body = Node3D.new()
	add_child(_body)
	var scl := float(Balance.stat(type, "scale", 1.0))
	# GLB varsa yükle, yoksa prosedürel low-poly. Yol artık TABLODAN
	# geliyor (Balance.TYPES[...].glb) — dosya adı kodda sabit değil,
	# YARATIKLAR.csv'deki satırla aynı yeri gösteriyor.
	var glb := _resolve_glb(String(Balance.stat(type, "glb", "")))
	if glb != "":
		var inst: Node3D = load(glb).instantiate()
		var iskeletli: bool = not inst.find_children(
				"*", "Skeleton3D", true, false).is_empty()
		if iskeletli:
			# ISKELETLI MODELDE AABB YALAN SOYLER (olculdu, iki yonde):
			# dugum-compose AABB 0.017 dedi -> hesaplanan olcek yaratigi
			# 70 m'lik deve cevirdi; mesh-uzayi AABB 1.7 der; GERCEK
			# render (1 m referans kuple xvfb'de cekildi) ~1.05 m.
			# Iskelette olcek TABLODAN gelir, origin zaten ayakta.
			inst.scale = Vector3.ONE * scl
		else:
			# Rig'siz modelde boy AABB'den OLCULUR: tabloda target_h
			# varsa olcek hesaplanir (tahmin degil).
			var ab := _aabb_of(inst)
			var hedef_boy := float(Balance.stat(type, "target_h", 0.0))
			if hedef_boy > 0.0 and ab.size.y > 0.001:
				scl = hedef_boy / ab.size.y
				inst.scale = Vector3.ONE * scl
			else:
				inst.scale = Vector3.ONE * scl
			# MERKEZLI MODEL TUZAGI: Meshy modelleri origin'i GOVDE
			# MERKEZINDE veriyor (olculdu: creature_normal Y [-0.5..0.5]).
			# AABB'nin alt kenari kadar yukari kaldiriliyor.
			if ab.size.y > 0.001:
				inst.position.y = -ab.position.y * scl
		_body.add_child(inst)
		_setup_glb_anim(inst)
		_setup_glb_emission(inst)
		# TEK PARLAK GOZ kimligi GLB'de de yasar: kucuk soguk isik —
		# gece govde siluet kaliyordu (2. kare turu dersi), isiksiz
		# yaratik karanlikta okunmuyor. set_simplified uzakta kapatir.
		var eye_col2: Color = Balance.EYE_COLOR
		if String(Balance.stat(type, "eye", "turkuaz")) == "mor":
			eye_col2 = Balance.EYE_COLOR_ALT
		var boyy := float(Balance.stat(type, "target_h", 1.0))
		var glow2 := OmniLight3D.new()
		glow2.light_color = eye_col2
		glow2.light_energy = 0.9
		glow2.omni_range = 2.2
		glow2.position = Vector3(0, boyy * 0.7, 0.25)
		glow2.shadow_enabled = false
		_body.add_child(glow2)
		_eye_light = glow2
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

# --- GLB ANIMASYON + ISIMA kurulumu (yaratik-gece) ------------------------

## Rig'li modelin AnimationPlayer'ini bul, yurume klibini coz.
## Klip adi tabloda (ANIM_WALK); import adi degisirse "walk" geceni ara.
func _setup_glb_anim(inst: Node3D) -> void:
	var players := inst.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_anim = players[0]
	var adlar := _anim.get_animation_list()
	for a in adlar:
		if String(a).contains(Balance.ANIM_WALK):
			_walk_anim = String(a)
			break
	if _walk_anim == "" :
		for a in adlar:
			if String(a).to_lower().contains("walk"):
				_walk_anim = String(a)
				break
	# Idle klibi yok: dururken klip DURUR (ilk karede bekler).
	if _walk_anim != "":
		var klip := _anim.get_animation(_walk_anim)
		if klip != null:
			klip.loop_mode = Animation.LOOP_LINEAR  # yurudukce donsun
		_anim.play(_walk_anim)
		_anim.pause()

## Emission kontrolu: paylasilmis GLB materyallerini KOPYALAYIP surface
## override'a koy — bir yaratigin isiga girmesi digerlerini sondurmesin.
func _setup_glb_emission(inst: Node3D) -> void:
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m is BaseMaterial3D:
				var kopya: BaseMaterial3D = m.duplicate()
				kopya.emission_enabled = true
				mi.set_surface_override_material(s, kopya)
				_glb_mats.append(kopya)
	_update_emission()

## Catlak isimasi: gece parlar, isik alaninda soner (Isik Kurami gorseli).
## Gece kaynagi su/cim ailesiyle AYNI (_update_water_night cagirir).
func _update_emission() -> void:
	if _glb_mats.is_empty():
		return
	var enerji: float = Balance.EMISSION_NIGHT if _night_on else Balance.EMISSION_DAY
	if _in_light:
		enerji *= Balance.EMISSION_LIGHT_DIM
	for m: BaseMaterial3D in _glb_mats:
		m.emission_energy_multiplier = enerji

func set_night(on: bool) -> void:
	if on == _night_on:
		return
	_night_on = on
	_update_emission()

func set_in_light(on: bool) -> void:
	if on == _in_light:
		return
	_in_light = on
	_update_emission()

## Hareket durumu: yuruyunce klip HIZLA SENKRON oynar (kayma yok),
## durunca 0.15 sn yumusaklikla durur. Rig yoksa sessizce yok sayilir.
func set_moving(on: bool) -> void:
	if _anim == null or _walk_anim == "":
		return
	if on == _moving:
		return
	_moving = on
	if on:
		_anim.speed_scale = speed / maxf(Balance.ANIM_WALK_REF_SPEED, 0.01)
		_anim.play(_walk_anim, Balance.ANIM_BLEND)
	else:
		_anim.pause()

## DOGMA (yaratik-gece): topraktan dogrulma — govde gomuk baslar,
## `seconds` icinde yukselir; bu surece AI islemez (daze).
func birth(seconds: float) -> void:
	if _body == null:
		return
	daze = seconds
	var boy := 0.9 * float(Balance.stat(type, "target_h",
			float(Balance.stat(type, "scale", 1.0)) * 0.6))
	_body.position.y = -boy
	var tw := create_tween()
	tw.tween_interval(seconds * 0.35)  # once kul-duman gorunsun
	tw.tween_property(_body, "position:y", 0.0, seconds * 0.65) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

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
	# MOBIL PERF (yaratik-gece): uzakta iskelet animasyonu da durur —
	# rig'li modelde en pahali kalem bu.
	if _anim != null and _walk_anim != "":
		if on:
			_anim.pause()
		elif _moving:
			_anim.play(_walk_anim, Balance.ANIM_BLEND)

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

## SAFAK: olmeden KUL OLUP erir (oz DUSURMEZ — gunesten kacti,
## oldurulmedi). Isima gunesle birlikte soner, govde kule cokup dagilir.
func melt(seconds: float) -> void:
	if not alive:
		return
	alive = false
	for m: BaseMaterial3D in _glb_mats:
		m.emission_energy_multiplier = 0.0  # catlaklar once soner
	if _eye_light != null:
		_eye_light.visible = false
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
	# GLB modelde flaş EMISSION uzerinden (albedo dokudan geliyor).
	if not _glb_mats.is_empty():
		for m: BaseMaterial3D in _glb_mats:
			m.emission_energy_multiplier = 5.0
		var twg := create_tween()
		twg.tween_interval(0.06)
		twg.tween_callback(_update_emission)  # normal duzeye don
		return
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
