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

## Su carpani (11.2): World, oyuncu yuzulur hucredeyken bunu dusurur.
## Yaratik davranisi (tirmanamama vb.) 11.6 ile gelecek.
var water_factor: float = 1.0

## Eylem carpani (12.3): alet sallarken hareket yavaslar (World okur).
var action_factor: float = 1.0

const ToolProfiles = preload("res://scripts/tool_profiles.gd")

## Eldeki alet gorseli (test bulgusu #2): esya id -> prosedurel govde turu.
## GLB yoksa bu ture gore basit low-poly placeholder uretilir. Legacy CI
## anahtarlari (spear/knife/club/sword/bow/sling) da desteklenir.
const TOOL_KIND := {
	"balta": "axe", "kazma": "pick", "kurek": "shovel", "bicak": "knife",
	"cekic": "hammer", "mizrak": "spear", "kilic": "sword", "sopa": "club",
	"yay": "bow", "sapan": "sling", "kova": "bucket", "kova_dolu": "bucket",
	# CI / eski anahtarlar
	"spear": "spear", "knife": "knife", "club": "club", "sword": "sword",
	"bow": "bow", "sling": "sling",
}

## Esya id -> assets/models/tools/ altindaki gercek GLB dosya adi (uzantisiz).
## Bu id'ler icin hazir Kenney modeli var; digerleri prosedurele duser.
const TOOL_GLB := {
	"balta": "tool-axe", "kazma": "tool-pickaxe", "kurek": "tool-shovel",
	"cekic": "tool-hammer", "kova": "bucket", "kova_dolu": "bucket",
}

## STIL: esya id -> TAM yol override (test/ altindaki yeni Meshy modelleri).
## Doldurulmussa tools/ placeholder yerine bu kullanilir.
const TOOL_GLB_OVERRIDE := {
	"balta": "res://assets/models/test/axe.glb",
}

## ELLE AYARLANAN ALET KAVRAMASI (veri; render'a bakip ayarlanir).
##  axis   : aletin uzun ekseni (0=X,1=Y,2=Z). axe.glb olculdu -> Y (1).
##  grip   : elin hizalanacagi nokta; 0 = eksenin MIN ucu, 1 = MAX ucu.
##           "en asagi sapini tut" => sapin oldugu uca yakin deger.
##  rot_deg: aleti elde dogru yone cevirmek icin donme (derece).
##  extra  : son ince ayar ofseti (metre, dunya).
## Kullanici "biraz yukari / dondur" derse bu sayilari degistiririz.
const TOOL_HOLD := {
	# scale>0: SABIT ~scale m boy (skinned el kemigi telafisini atla). grip:
	# 0=alt uc(Y min), 1=ust uc. TEST: ortadan tut + sabit 0.5m -> balta gorunur mu.
	# rot_deg: el kemigi yoneliminden HESAPLANDI (handdbg) -> balta dik dursun
	# (kafa yukari, bicak one). grip 0.12 = sapin en dibi.
	"balta": {"axis": 1, "grip": 0.12, "scale": 0.6, "rot_deg": Vector3(11.2, 60.4, -125.4),
			"extra": Vector3(0, 0, 0)},
}

## STIL: esya id -> karakterin GOVDE saldiri animasyonu (character_animated).
## Alete ozel: balta kilic kesigi, kazma cekic savurmasi. Karakter o animasyona
## sahip degilse otomatik bulunan _anim_attack'e duser.
const TOOL_ATTACK_ANIM := {
	"balta": "Right_Hand_Sword_Slash",
	"kazma": "Heavy_Hammer_Swing",
}

## Alet eylemi sirasinda aletin baglandigi doner pivot (ToolPivot).
## _tool_attach el kemigine yapisir; pivot onun icinde donerek uc fazli
## sallanmayi olusturur. Model pivot'un cocugudur.
var _tool_pivot: Node3D
var _swinging: bool = false
var _exerting_move: bool = false  # kosarak hareket (yasam: efor carpani)
signal swing_finished  # bir sonraki eylem/kombo icin (Asama 4 kilic)

## Efor sarfi (yasam sistemi): kosma veya alet sallamasi. world3d okur ->
## PlayerStats.effort. Aclik eforla daha hizli azalir.
func is_exerting() -> bool:
	return _exerting_move or _swinging

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
		"2H_Axe", "Mug", "Mage_Hat", "Spellbook", "Spellbook_open",
		# Quaternius karakterlerinin gomulu alet/silahlari
		"Axe", "Gun", "NurbsPath.001", "Revolver", "Revolver_Small",
		"Sniper", "Sniper_2", "Pistol", "SMG", "GrenadeLauncher",
		"ShortCannon", "Shotgun", "RocketLauncher", "AK", "Shovel",
		"Knife_1", "Knife_2"]

const CustomCharScript = preload("res://scripts/custom_character.gd")

var _anim: AnimationPlayer
var _custom_char: CustomCharScript  # "custom:" karakterlerde dolu
var _current_anim: String = ""
var _model_scale: float = 1.0
var _raw_height: float = 0.67  # modelin ham boyu (aksesuar olcek referansi)
var _model_root: Node3D    # aktif karakter modeli
var _tool_attach: Node3D   # eldeki aletin baglandigi nokta (olcek=1 ayna)
var _head_attach: Node3D   # sapka/gozluk baglanma noktasi (olcek=1 ayna)
var _tool_src: Node3D      # el kemigi kaynagi (aynaya kopyalanir)
var _head_src: Node3D      # kafa kemigi kaynagi (aynaya kopyalanir)
var _held_tool_path: String = ""  # karakter degisince yeniden takmak icin
var _hat_id: String = ""
var _face_path: String = ""
var _hair_style: String = ""  # "" = modelin kendi saci
var _hair_color := Color(0.25, 0.18, 0.12)
# Pakete gore degisen animasyon adlari (otomatik bulunur)
var _anim_idle: String = ""
var _anim_walk: String = ""
var _anim_run: String = ""
var _anim_attack: String = ""  # saldiri/savurma animasyonu (varsa, tek sefer)

# STIL: skinned karakter olcek duzeltmesi. Bazi Meshy/Mixanimate modeller
# Armature'da 0.01 gibi olcek tasir; mesh yerel AABB'si (1.7 m) dogru gorunse
# de POZLANMIS iskelet minicik render eder. Bir kare bekleyip kemik dunya
# pozlarindan GERCEK boyu olcup yeniden olcekleriz (yalniz cok sapan modeller).
var _rescale_skel: Skeleton3D = null
var _rescale_model: Node3D = null
var _rescale_wait: int = 0

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
	_tool_src = null
	_head_src = null
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
	# ONCE paketle gelen silah/aksesuar gorselleri kapat (sade gorunum) -
	# olcek hesabi bu propplara takilmasin (orn. Sam'in elindeki balta)
	for weapon_name in EMBEDDED_WEAPONS:
		var weapon := model.find_child(weapon_name, true, false)
		if weapon != null and weapon is Node3D:
			(weapon as Node3D).visible = false
	# OLCEK: "_scaled" modeller ONCEDEN dogru boya gomulmustur (GLB icinde
	# Armature olcegi Blender-Apply gibi bakilmistir) -> KODDA olceklenmez,
	# node 1.0 kalir (tool-attach gercek metrede -> balta sapindan oturur).
	# Diger (ham) Meshy modellerde Armature 0.01 tasidigi icin AABB gercek boyu
	# yansitmaz; onlarda AABB + kemik-pozu (_fix_skinned_scale) ile olceklenir.
	var prescaled := model_path.contains("_scaled")
	if not prescaled:
		var vis_aabb := _visual_aabb(model, Transform3D.IDENTITY)
		if vis_aabb.size.y > 0.01:
			_raw_height = vis_aabb.size.y
			_model_scale = TARGET_HEIGHT / _raw_height
			model.scale = Vector3(_model_scale, _model_scale, _model_scale)
	# Alet baglama noktasi: sag el kemigi (yoksa govde onunde yedek nokta).
	# Kemik baglantilari iskelet olcegini tasiyabilir; bu yuzden gorseller
	# dogrudan kemige degil, olcegi 1 olan AYNA dugumlere takilir
	# (_process her kare kemigin konum/donusunu aynaya kopyalar).
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	if skeleton == null:
		skeleton = model.find_child("*Skeleton*", true, false)
	_tool_src = null
	_head_src = null
	if skeleton != null:
		var bone_idx := _find_hand_bone(skeleton)
		if bone_idx != -1:
			var attach := BoneAttachment3D.new()
			skeleton.add_child(attach)
			attach.bone_name = skeleton.get_bone_name(bone_idx)
			_tool_src = attach
			_tool_attach = Node3D.new()
			_visual.add_child(_tool_attach)
	if _tool_attach == null:
		_tool_attach = Node3D.new()
		_tool_attach.position = Vector3(0.28, 0.75, 0.18)
		_visual.add_child(_tool_attach)
	# Sapka/gozluk baglanma noktasi: kafa kemigi (yine ayna uzerinden)
	_head_attach = null
	if skeleton != null:
		for i in skeleton.get_bone_count():
			if skeleton.get_bone_name(i).to_lower().contains("head"):
				var head_att := BoneAttachment3D.new()
				skeleton.add_child(head_att)
				head_att.bone_name = skeleton.get_bone_name(i)
				_head_src = head_att
				_head_attach = Node3D.new()
				_visual.add_child(_head_attach)
				break
	if _head_attach == null:
		_head_attach = Node3D.new()
		_head_attach.position = Vector3(0, TARGET_HEIGHT * 0.85, 0)
		_visual.add_child(_head_attach)
	_sync_attach_mirrors()
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
	# Skinned modelde gercek boyu kemik pozlarindan dogrula (bir kare sonra);
	# Armature 0.01 gibi olcekler mesh AABB'siyle yakalanamaz. ONCEDEN gomulu
	# ("_scaled") modellerde gerek yok (zaten dogru boyda, node 1.0).
	if skeleton != null and not prescaled:
		_rescale_skel = skeleton
		_rescale_model = model
		_rescale_wait = 2

# Gorunur mesh'lerin BIRIKIMLI donusumlerle birlesik sinir kutusu
# (iskelet dugumundeki 100x gibi olcekler dahil edilir)
func _visual_aabb(node: Node, xform: Transform3D) -> AABB:
	var result := AABB()
	var found := false
	var t := xform
	if node is Node3D:
		if not (node as Node3D).visible:
			return AABB()
		t = xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result = t * (node as MeshInstance3D).get_aabb()
		found = true
	for child in node.get_children():
		var sub := _visual_aabb(child, t)
		if sub.size != Vector3.ZERO or sub.position != Vector3.ZERO:
			result = result.merge(sub) if found else sub
			found = true
	return result

# Kemik kaynaklarinin konum/donusunu olcek-1 aynalara kopyalar
# (iskeletteki dev olcekler aksesuarlara bulasmaz)
# TESHIS (yalniz screenshot): el kemiginin karakter-govde cercevesindeki
# yonelimini yazar. Baltanin uzun ekseni (yerel +Y) elde hangi dunya yonune
# gidiyor -> rot_deg'i buradan hesaplariz.
func debug_hand_orientation() -> void:
	if _tool_src == null:
		print("HANDDBG: el kemigi yok"); return
	var pb := global_transform.basis.orthonormalized()
	var hb := _tool_src.global_transform.basis.orthonormalized()
	var rel := pb.inverse() * hb  # el ekseni, karakter cercevesinde
	var line := "handX=(%.3f,%.3f,%.3f) handY=(%.3f,%.3f,%.3f) handZ=(%.3f,%.3f,%.3f)" % [
		rel.x.x, rel.x.y, rel.x.z, rel.y.x, rel.y.y, rel.y.z, rel.z.x, rel.z.y, rel.z.z]
	print("HANDDBG: " + line)
	# Log tail-30'da kaybolmasin diye dosyaya da yaz (screenshot commit'i alir).
	var f := FileAccess.open("res://docs/screens/handdbg.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(line + "\n")
		f.close()

func _sync_attach_mirrors() -> void:
	if _tool_src != null and _tool_attach != null:
		var gt := _tool_src.global_transform
		_tool_attach.global_transform = Transform3D(gt.basis.orthonormalized(), gt.origin)
	if _head_src != null and _head_attach != null:
		var gt2 := _head_src.global_transform
		_head_attach.global_transform = Transform3D(gt2.basis.orthonormalized(), gt2.origin)

# Dugumun dunya olcegi (aksesuar boylarini normalize etmek icin)
func _node_world_scale(n: Node3D) -> float:
	if n == null or not n.is_inside_tree():
		return 1.0
	return maxf(n.global_transform.basis.get_scale().x, 0.0001)

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
		# On kol (bilek) ust koldan iyi tutma noktasidir (Quaternius rigi)
		if (lower.contains("lowerarm") or lower.contains("forearm")) and best_hand == -1:
			best_hand = i
		if lower.contains("arm") and best_arm == -1:
			best_arm = i
	return best_hand if best_hand != -1 else best_arm

# Idle/yurume/kosma animasyonlarini ada gore esnek bulur
func _detect_animations() -> void:
	_anim_idle = ""
	_anim_walk = ""
	_anim_run = ""
	_anim_attack = ""
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
		# Saldiri/savurma: hammer/swing/slash/attack/chop/axe
		if _anim_attack == "" and (lower.contains("swing") or lower.contains("slash") \
				or lower.contains("attack") or lower.contains("chop") \
				or lower.contains("hammer")):
			_anim_attack = anim_name
	# Tercih: tam adlar varsa onlari kullan (KayKit)
	for pair in [["Idle", "idle"], ["Walking_A", "walk"], ["Running_A", "run"]]:
		if _anim.has_animation(pair[0]):
			match pair[1]:
				"idle": _anim_idle = pair[0]
				"walk": _anim_walk = pair[0]
				"run": _anim_run = pair[0]
	if _anim_run == "":
		_anim_run = _anim_walk
	if _anim_walk == "":
		_anim_walk = _anim_run  # bazi paketlerde Walk yok (orn. Asker)
	# STIL: idle animasyonu olmayan modeller (orn. Meshy character_animated —
	# Walking/Running var, idle yok) T-poza dusmesin diye idle=walk yedegi.
	if _anim_idle == "":
		_anim_idle = _anim_walk
	for anim_name in [_anim_idle, _anim_walk, _anim_run]:
		if anim_name != "" and _anim.has_animation(anim_name):
			_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	# Saldiri animasyonu TEK SEFER oynar (donmez)
	if _anim_attack != "" and _anim.has_animation(_anim_attack):
		_anim.get_animation(_anim_attack).loop_mode = Animation.LOOP_NONE

## Eldeki aletin 3D modelini ele takar; bos yol = eli bosalt.
## "spear" ozel degeri: pakette mizrak yok, basit bir tane insa edilir.
func set_held_tool(model_path: String) -> void:
	_held_tool_path = model_path
	_swinging = false
	_tool_pivot = null
	if _tool_attach == null:
		return
	for child in _tool_attach.get_children():
		child.queue_free()
	# ToolPivot: fazlar bunu dondurur; model onun cocugu. Bos elde bile
	# olusturulur ki yumruk sallamasi (fist) animasyonu oynayabilsin.
	_tool_pivot = Node3D.new()
	_tool_pivot.name = "ToolPivot"
	_tool_attach.add_child(_tool_pivot)
	if model_path == "":
		return
	# GORSEL SECIMI (test bulgusu #2): once gercek GLB (ileride Meshy),
	# yoksa PROSEDUREL low-poly placeholder (UI ikon placeholder kuralinin
	# 3D karsiligi). Legacy anahtarlar (spear/knife/...) da desteklenir.
	var visual: Node3D = null
	var glb := String(TOOL_GLB_OVERRIDE.get(model_path, ""))
	if glb == "":
		glb = "res://assets/models/tools/%s.glb" % String(TOOL_GLB.get(model_path, model_path))
	if ResourceLoader.exists(glb):
		visual = load(glb).instantiate()
	else:
		var kind := String(TOOL_KIND.get(model_path, ""))
		if kind == "":
			return  # gorseli olmayan esya (toprak, dolu kova vb.)
		visual = _make_tool(kind, _tool_head_color(model_path))
	_tool_pivot.add_child(visual)
	# ~0.5 m dunya boyu (baglanti dunya olcegi ne olursa olsun); TUM
	# alt mesh'leri kapsayan AABB ile olcekle (tek mesh'e bakma)
	var aabb := _scene_aabb(visual)
	var size := aabb.get_longest_axis_size()
	if size > 0.01:
		var s := 0.5 / (size * _node_world_scale(_tool_attach))
		# KAVRAMA (veri tabanli, TOOL_HOLD). scale>0 verilirse _node_world_scale
		# telafisi ATLANIR ve SABIT yerel olcek kullanilir (skinned rig'de o
		# telafi baltayi minik yapiyordu). El noktasi + donme ELLE ayarlanir.
		if TOOL_HOLD.has(model_path):
			var cfg: Dictionary = TOOL_HOLD[model_path]
			var fixed: float = float(cfg.get("scale", 0.0))
			if fixed > 0.0:
				s = fixed / size  # sabit ~fixed m boy (telafi yok)
			visual.scale = Vector3(s, s, s)
			visual.rotation_degrees = cfg.get("rot_deg", Vector3.ZERO)
			var sz := aabb.size
			var li: int = int(cfg.get("axis", 1))  # aletin uzun ekseni (balta=Y)
			var frac: float = float(cfg.get("grip", 0.5))  # 0=MIN uc,1=MAX uc
			var g := aabb.get_center()
			g[li] = aabb.position[li] + frac * sz[li]
			var basis := Basis.from_euler(visual.rotation)
			visual.position = -(basis * (g * s)) + cfg.get("extra", Vector3.ZERO)
		else:
			visual.scale = Vector3(s, s, s)

## Uc fazli alet sallamasi (12.3). Profil pozlarini Tween ile oynatir;
## strike aninda on_strike cagrilir (ETKI orada uygulanir, buton aninda
## DEGIL). Zaten sallaniyorsa false doner (spam korumasi). tier: sure
## kirpma kademesi. combo_second: kilic ikinci kesigi (ters yon).
func play_swing(profile: Dictionary, on_strike: Callable,
		tier: int = 0, combo_second: bool = false) -> bool:
	if _swinging or _tool_pivot == null:
		return false
	_swinging = true
	action_factor = 0.6  # eylem sirasinda %40 yavasla
	var f: float = ToolProfiles.tier_factor(tier)
	var windup: float = maxf(0.03, float(profile.get("windup", 0.14)) * f)
	var strike: float = maxf(0.03, float(profile.get("strike", 0.10)))
	var recover: float = maxf(0.03, float(profile.get("recover", 0.20)) * f)
	if combo_second:
		recover = 0.12
	# STIL: karakterin GOVDE saldiri animasyonu (varsa) savurmaya uydurulur —
	# tek sefer oynar, sallanma boyunca. Hareket animasyonu bu sirada bastirilir
	# (_physics_process _swinging'e bakar). Iskeletsiz/animasyonsuz karakterlerde
	# _anim_attack bostur -> yalniz proseduel alet savurmasi calisir (eskisi gibi).
	# Alete ozel animasyon (balta->slash, kazma->hammer); yoksa otomatik bulunan
	var atk := String(TOOL_ATTACK_ANIM.get(_held_tool_path, ""))
	if _anim == null or not _anim.has_animation(atk):
		atk = _anim_attack
	if _anim != null and atk != "" and _anim.has_animation(atk):
		var total: float = windup + strike + recover
		var alen: float = _anim.get_animation(atk).length
		var spd: float = (alen / total) if total > 0.05 and alen > 0.05 else 1.0
		_anim.get_animation(atk).loop_mode = Animation.LOOP_NONE
		_anim.play(atk, 0.05, spd)
		_current_anim = atk
	var rest: Vector3 = profile.get("rest", Vector3.ZERO)
	var wind: Vector3 = profile.get("wind", Vector3.ZERO)
	var hit: Vector3 = profile.get("hit", Vector3.ZERO)
	var push_z: float = float(profile.get("push_z", 0.0))
	if combo_second:
		# Ikinci kesik ters yon: yatay bileseni aynala
		wind = Vector3(wind.x, -wind.y, -wind.z)
		hit = Vector3(hit.x, -hit.y, -hit.z)
	_tool_pivot.rotation_degrees = rest
	_tool_pivot.position = Vector3.ZERO
	var tw := create_tween()
	# HAZIRLIK: geri cekil
	tw.tween_property(_tool_pivot, "rotation_degrees", wind, windup) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# VURUS: hizli in; bitiminde ETKI
	tw.tween_property(_tool_pivot, "rotation_degrees", hit, strike) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if push_z > 0.001:
		tw.parallel().tween_property(_tool_pivot, "position:z", push_z, strike) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if on_strike.is_valid():
			on_strike.call())
	# TOPARLANMA: dinlenmeye don
	tw.tween_property(_tool_pivot, "rotation_degrees", rest, recover) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if push_z > 0.001:
		tw.parallel().tween_property(_tool_pivot, "position:z", 0.0, recover)
	tw.tween_callback(func():
		_swinging = false
		action_factor = 1.0
		swing_finished.emit())
	return true

func is_swinging() -> bool:
	return _swinging

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
	# Aksesuarlar 0.67 birimlik mini kafaya gore cizildi; hedef dunya
	# boyutu sabittir. Baglanma noktasinin dunya olcegine bolerek her
	# karakterde ayni gercek boyut elde edilir.
	return (TARGET_HEIGHT / 0.67) / _node_world_scale(_head_attach)

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
	# Taban: kafayi saran BUYUK yumusak kubbe - silueti tek parca,
	# ustune eklenenler hafif dalgalar (yumru yumru gorunmez)
	var dome := SphereMesh.new()
	dome.radius = 0.183
	dome.height = 0.20
	dome.is_hemisphere = true
	hair.add_child(_hat_part(dome, color, Vector3(0, 0.115, -0.012)))
	# Percemler: kubbeye GOMULU, sadece alt kenari hafif taramali
	for i in 5:
		var a := deg_to_rad(-50.0 + 25.0 * i)
		var bang := SphereMesh.new()
		bang.radius = 0.036
		bang.height = 0.06
		hair.add_child(_hat_part(bang, color,
				Vector3(sin(a) * 0.138, 0.142, cos(a) * 0.138 - 0.008)))
	# Yan tutamlar: kubbeye gomulu, kulaklari yumusakca ortier
	var side_lock := SphereMesh.new()
	side_lock.radius = 0.052
	side_lock.height = 0.10
	hair.add_child(_hat_part(side_lock, color, Vector3(0.142, 0.10, -0.01)))
	hair.add_child(_hat_part(side_lock, color, Vector3(-0.142, 0.10, -0.01)))
	# Ense dolgusu (kubbeyle butunlesik)
	var nape := SphereMesh.new()
	nape.radius = 0.11
	nape.height = 0.16
	hair.add_child(_hat_part(nape, color, Vector3(0, 0.095, -0.085)))
	# Tepe dalgasi: TEK genis, iyice gomulu kabarti (dogal hacim)
	var lobe := SphereMesh.new()
	lobe.radius = 0.135
	lobe.height = 0.16
	hair.add_child(_hat_part(lobe, color, Vector3(0.025, 0.19, 0.0)))
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

## Alet kademesine gore bas rengi (#2): sap hep ahsap, bas kademe rengi.
## Su an tek kademe (tas) var; ust kademe id'leri (bakir_/demir_/celik_)
## geldiginde otomatik cozulur. Bilinmeyen -> tas grisi.
func _tool_head_color(id: String) -> Color:
	if id.begins_with("celik") or id.ends_with("celik"):
		return Color(0.62, 0.68, 0.78)   # celik: mavi-gri
	if id.begins_with("demir") or id.ends_with("demir"):
		return Color(0.78, 0.80, 0.83)   # demir: acik gri
	if id.begins_with("bakir") or id.ends_with("bakir"):
		return Color(0.78, 0.50, 0.30)   # bakir: turuncu-kahve
	return Color(0.55, 0.56, 0.60)       # tas: gri (varsayilan)

## Kenney kitinde olmayan alet/silahlarin basit prosedurel low-poly
## placeholder'lari (#2). Sap = ahsap kahvesi, bas = kademe rengi (head).
## Boyut set_held_tool'da AABB ile ~0.5 m'ye normalize edilir (burada
## olcek telafisi YOK — GLB yolu ile ayni normalizasyon).
func _make_tool(kind: String, head: Color) -> Node3D:
	var root := Node3D.new()
	var wood := Color(0.55, 0.38, 0.22)
	match kind:
		"axe":
			root.add_child(_hat_part(_cyl(0.02, 0.022, 0.5), wood, Vector3(0, 0.1, 0)))
			var hm := BoxMesh.new(); hm.size = Vector3(0.14, 0.12, 0.03)
			root.add_child(_hat_part(hm, head, Vector3(0.06, 0.33, 0)))
		"pick":
			root.add_child(_hat_part(_cyl(0.02, 0.022, 0.5), wood, Vector3(0, 0.1, 0)))
			var pm := BoxMesh.new(); pm.size = Vector3(0.36, 0.03, 0.03)
			root.add_child(_hat_part(pm, head, Vector3(0, 0.35, 0), Vector3(0, 0, 18)))
		"shovel":
			root.add_child(_hat_part(_cyl(0.02, 0.022, 0.5), wood, Vector3(0, 0.1, 0)))
			var sb := BoxMesh.new(); sb.size = Vector3(0.13, 0.16, 0.02)
			root.add_child(_hat_part(sb, head, Vector3(0, 0.4, 0)))
		"hammer":
			root.add_child(_hat_part(_cyl(0.02, 0.022, 0.5), wood, Vector3(0, 0.1, 0)))
			var hb := BoxMesh.new(); hb.size = Vector3(0.13, 0.08, 0.08)
			root.add_child(_hat_part(hb, head, Vector3(0, 0.35, 0)))
		"knife":
			var kb := BoxMesh.new(); kb.size = Vector3(0.03, 0.22, 0.008)
			root.add_child(_hat_part(kb, head, Vector3(0, 0.14, 0)))
			root.add_child(_hat_part(_cyl(0.018, 0.018, 0.10), wood, Vector3.ZERO))
		"sword":
			var wb := BoxMesh.new(); wb.size = Vector3(0.05, 0.55, 0.012)
			root.add_child(_hat_part(wb, head, Vector3(0, 0.32, 0)))
			var gb := BoxMesh.new(); gb.size = Vector3(0.18, 0.03, 0.03)
			root.add_child(_hat_part(gb, head, Vector3(0, 0.05, 0)))
			root.add_child(_hat_part(_cyl(0.02, 0.02, 0.12), wood, Vector3(0, -0.04, 0)))
		"club":
			root.add_child(_hat_part(_cyl(0.035, 0.02, 0.55), wood, Vector3(0, 0.12, 0)))
		"spear":
			root.add_child(_hat_part(_cyl(0.02, 0.02, 0.75), wood, Vector3.ZERO))
			root.add_child(_hat_part(_cyl(0.0, 0.045, 0.16), head, Vector3(0, 0.45, 0)))
		"bow":
			var tm := TorusMesh.new(); tm.inner_radius = 0.24; tm.outer_radius = 0.27
			tm.rings = 6; tm.ring_segments = 12
			root.add_child(_hat_part(tm, wood, Vector3.ZERO, Vector3(0, 90, 0)))
			root.add_child(_hat_part(_cyl(0.004, 0.004, 0.5), head, Vector3.ZERO))
		"sling":
			root.add_child(_hat_part(_cyl(0.015, 0.015, 0.16), wood, Vector3.ZERO))
			var slm := SphereMesh.new(); slm.radius = 0.04; slm.height = 0.06
			root.add_child(_hat_part(slm, wood, Vector3(0, -0.12, 0)))
		"bucket":
			root.add_child(_hat_part(_cyl(0.10, 0.08, 0.16), head, Vector3(0, 0.08, 0)))
	return root

## Bir Node3D altindaki tum mesh'leri kapsayan AABB (local uzayda). Alet
## gorselini el boyutuna normalize etmek icin (set_held_tool). world3d ile
## ayni mantik.
func _scene_aabb(node: Node, xform: Transform3D = Transform3D.IDENTITY) -> AABB:
	var result := AABB()
	var found := false
	var t := xform
	if node is Node3D:
		if not (node as Node3D).visible:
			return AABB()
		t = xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result = t * (node as MeshInstance3D).mesh.get_aabb()
		found = true
	for child in node.get_children():
		var sub := _scene_aabb(child, t)
		if sub.size != Vector3.ZERO or sub.position != Vector3.ZERO:
			result = result.merge(sub) if found else sub
			found = true
	return result

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

func _process(_delta: float) -> void:
	# Kemik aynalarini her kare guncelle (animasyonla birlikte tasinir)
	_sync_attach_mirrors()
	if _rescale_wait > 0:
		_rescale_wait -= 1
		if _rescale_wait == 0:
			_fix_skinned_scale()

## Iskeletli karakterin GERCEK render boyunu kemik dunya pozlarindan olcup,
## hedeften cok saparsa (armature 0.01 gibi) yeniden olcekler. Normal boyda
## olan karakterlere (Rogue/Quaternius) dokunmaz — sadece asiri sapmayi duzeltir.
func _fix_skinned_scale() -> void:
	var skel := _rescale_skel
	var model := _rescale_model
	_rescale_skel = null
	_rescale_model = null
	if skel == null or not is_instance_valid(skel) or model == null \
			or not is_instance_valid(model):
		return
	var mn := INF
	var mx := -INF
	for i in skel.get_bone_count():
		var wy: float = (skel.global_transform * skel.get_bone_global_pose(i).origin).y
		mn = minf(mn, wy)
		mx = maxf(mx, wy)
	var h := mx - mn  # kemiklerin dunya-uzayi Y boyu (~gercek render boyu)
	if h <= 0.0001:
		return
	# Kemik boyu gercek boydan biraz kisa (bas/ayak payi) -> ~1.12 faktor.
	# Sadece hedefin yarisindan kucuk / iki katindan buyuk olursa duzelt.
	if h < TARGET_HEIGHT * 0.5 or h > TARGET_HEIGHT * 2.0:
		var s: float = model.scale.y * (TARGET_HEIGHT / 1.12) / h
		if s > 0.0001:
			model.scale = Vector3(s, s, s)
			_model_scale = s
			set_held_tool(_held_tool_path)  # alet olcegini yeni boya gore yenile

func _physics_process(delta: float) -> void:
	var dir := _get_input_direction()
	if dir == Vector2.ZERO:
		_exerting_move = false
		if not _swinging:  # saldiri animasyonunu ezme
			_play(_anim_idle)
		return
	facing = dir
	# Kosma: parmagi uzaga cek (veya klavyede Shift)
	var running := _wants_run()
	_exerting_move = running  # efor: kosma aclik carpanini artirir (yasam)
	if not _swinging:  # saldiri animasyonunu ezme
		_play(_anim_run if running else _anim_walk)
	var speed := (RUN_SPEED if running else SPEED) * water_factor * action_factor
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
	# 11.5 merdiven kurali: derin cukurdan cikis merdiven ister (can_step).
	var cur := Vector2i(floori(pos.x), floori(pos.z))
	var next_x := pos + Vector3(offset.x, 0, 0)
	var cx := Vector2i(floori(next_x.x), floori(next_x.z))
	if _pos_walkable(next_x) and world.can_step(cur, cx):
		pos = next_x
	var next_z := pos + Vector3(0, 0, offset.z)
	var cz := Vector2i(floori(next_z.x), floori(next_z.z))
	if _pos_walkable(next_z) and world.can_step(cur, cz):
		pos = next_z
	# Araziyi takip et: tepecikte yuksel, kumsalda alcal
	pos.y = world.ground_height(pos.x, pos.z)
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
