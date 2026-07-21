extends Node3D
## 3D dunya - Asama B1+B2 baslangici.
##
## - ASCII haritadan MultiMesh blok zemin + yer tutucu agac/kaya/cali
## - SABIT acili, oyuncuyu yumusakca takip eden kamera (aci degismez)
## - Kamera ayari: "Kamera" butonuyla acilan panelde yakinlik/aci
##   kaydiricilari + iki parmakla yakinlastirma (pinch)
## - Toplama: dokun ya da aksiyon butonu; 2D ile ayni vurus/dusurme
##   mantigi (balta/kazma bonusu eldeyken), cali yeniden buyur
## - Su kenarinda suya dokun: su ic (susuzluk)
##
## Oyun mantigi autoload'larda; HUD 3D ustunde 2D katman.

const MapData = preload("res://scripts/map_data.gd")
const Player3DScript = preload("res://scripts/player3d.gd")
const Items = preload("res://scripts/items.gd")

## Zemin turleri: renk + ust yuzey yuksekligi. "speckled": true olan
## turler icin benekli doku CALISMA ANINDA kodla uretilir (dosya
## iceri aktarma boru hattina bagimlilik yok - her platformda calisir).
# Renkler kasitli koyu: parlak isikta ekranda referanstaki tona oturur
const GROUND_DEFS := {
	".": {"color": Color(0.29, 0.53, 0.21), "top": 0.0, "solid": false, "speckled": true},
	"d": {"color": Color(0.47, 0.33, 0.20), "top": -0.02, "solid": false, "speckled": true},
	"s": {"color": Color(0.80, 0.66, 0.40), "top": -0.02, "solid": false, "speckled": true},
	"~": {"color": Color(0.17, 0.42, 0.72), "top": -0.14, "solid": true, "water": true},
	"o": {"color": Color(0.30, 0.23, 0.17), "top": -0.25, "solid": true},
	# Yuksek plato: cikilmaz manzara (falez yamaclari taslasir)
	"h": {"color": Color(0.31, 0.55, 0.23), "top": 1.1, "solid": true},
}

## Toplanabilir nesneler (2D'deki degerlerle ayni).
## "vanish_regrow": toplaninca kaybolur, bir sure sonra ayni yerde biter.
const OBJECT_DEFS := {
	"T": {"drops": {"odun": 3, "yaprak": 2}, "hits": 3,
			"tool": {"item": "balta", "hits": 1}},
	"#": {"drops": {"tas": 2}, "hits": 4,
			"tool": {"item": "kazma", "hits": 2}},
	"m": {"drops": {"meyve": 2}, "hits": 1, "becomes": "n"},
	"cicek": {"drops": {"cicek": 1}, "hits": 1, "vanish_regrow": true},
	"mantar": {"drops": {"mantar": 1}, "hits": 1, "vanish_regrow": true},
}

## Tas turleri (kullanici secimi): iki normal gorunum + komurlu + altinli.
## Hucreye gore deterministik dagilir; kazma hepsinde 2 vurusa dusurur.
const STONE_VARIANTS := [
	{"model": "quat2_rock02", "h": 0.95, "drops": {"tas": 2}, "hits": 4},
	{"model": "quat2_rock05", "h": 0.95, "drops": {"tas": 2}, "hits": 4},
	{"model": "quat2_rock03", "h": 0.80, "drops": {"tas": 1, "komur": 2}, "hits": 4},
	{"model": "quat2_rock07", "h": 0.90, "drops": {"tas": 1, "altin": 1}, "hits": 5},
]
const REGROW_SECONDS := 60.0
const CAM_BASE_DIST := 12.5  # genis bakis (Longvinter benzeri olcek)
const SETTINGS_PATH := "user://cam3d.json"

# Doga modelleri (CC0, Quaternius). Hucreye gore deterministik secilir:
# orman cesitli ama her acilista ayni gorunur.
const NATURE_PATH := "res://assets/models/nature/%s.glb"
## Orman: kullanici secimi - A1 yesil yaprakli agac paketi
const TREE_HEIGHT := 3.1
## Karakter secenekleri (Gorunum paneli).
## "Yuvarlak" olanlar kendi tasarimimiz (kod ile insa: kose yok,
## kure kafa + kapsul govde; spec = ten/tisort/pantolon renkleri).
## Mini'ler Kenney paketi (blok stil). Ayni olcek = aksesuarlar ortak.
const CHARACTER_OPTIONS := [
	["Sarışın", "res://assets/models/characters/quat_sarisin.glb"],
	["Matt", "res://assets/models/characters/quat_matt.glb"],
	["Asker", "res://assets/models/characters/quat_asker.glb"],
	["Sam", "res://assets/models/characters/quat_sam.glb"],
	["Yuvarlak Mavi", "custom:f2c29b/4fa7d8/5b6b8c"],
	["Yuvarlak Yeşil", "custom:e8b48d/6abf69/6b5b4a"],
	["Yuvarlak Pembe", "custom:f5cba7/ef8fb0/7a6f8f"],
	["Yuvarlak Sarı", "custom:d9a06b/f2c14e/4f5d75"],
	["Yuvarlak Kırmızı", "custom:c98a5e/d95f5f/3f4a5f"],
	["Yuvarlak Mor", "custom:f2c29b/9b7fd4/44506b"],
	["Erkek A", "res://assets/models/characters/mini/character-male-a.glb"],
	["Erkek B", "res://assets/models/characters/mini/character-male-b.glb"],
	["Erkek C", "res://assets/models/characters/mini/character-male-c.glb"],
	["Erkek D", "res://assets/models/characters/mini/character-male-d.glb"],
	["Erkek E", "res://assets/models/characters/mini/character-male-e.glb"],
	["Erkek F", "res://assets/models/characters/mini/character-male-f.glb"],
	["Kadın A", "res://assets/models/characters/mini/character-female-a.glb"],
	["Kadın B", "res://assets/models/characters/mini/character-female-b.glb"],
	["Kadın C", "res://assets/models/characters/mini/character-female-c.glb"],
	["Kadın D", "res://assets/models/characters/mini/character-female-d.glb"],
	["Kadın E", "res://assets/models/characters/mini/character-female-e.glb"],
	["Kadın F", "res://assets/models/characters/mini/character-female-f.glb"],
]

## Sapka secenekleri (player3d kod ile insa eder)
const HAT_OPTIONS := [
	["Yok", "yok"],
	["Hasır Şapka", "hasir"],
	["Bere", "bere"],
	["Kasket", "kasket"],
	["Taç", "tac"],
	["Parti", "parti"],
	["Çiçek Tacı", "cicek"],
]

## Yuz aksesuarlari (mini paketinden hazir modeller)
const FACE_OPTIONS := [
	["Yok", ""],
	["Gözlük", "res://assets/models/characters/mini/aid-glasses.glb"],
	["Güneş Gözlüğü", "res://assets/models/characters/mini/aid-sunglasses.glb"],
	["Maske", "res://assets/models/characters/mini/aid-mask.glb"],
]

## Sac stilleri (kendi tasarimimiz, player3d insa eder) + renkler
const HAIR_STYLES := [
	["Model Saçı", ""],
	["Küt", "kut"],
	["Sivri", "sivri"],
	["Topuz", "topuz"],
	["Uzun", "uzun"],
]
const HAIR_COLORS := [
	Color(0.13, 0.12, 0.14),  # siyah
	Color(0.35, 0.22, 0.12),  # kahve
	Color(0.55, 0.35, 0.18),  # kumral
	Color(0.92, 0.78, 0.35),  # sari
	Color(0.75, 0.30, 0.15),  # kizil
	Color(0.92, 0.92, 0.95),  # beyaz
	Color(0.95, 0.55, 0.75),  # pembe
	Color(0.35, 0.55, 0.90),  # mavi
]
# Cim hucrelerine serpistirilen sus otlari (engel degil, toplanmaz):
# Quaternius ot paketi (quat2_grass01), cocuklari ayri varyantlardir

var _ground_char: Dictionary = {}  # hucre -> zemin karakteri
var _objects: Dictionary = {}      # hucre -> "T"/"#"/"m"/"n"
var _object_hits: Dictionary = {}  # hucre -> alinan vurus
var _regrow: Dictionary = {}       # hucre -> yeniden bitmeye kalan sure
var _regrow_type: Dictionary = {}  # hucre -> bitince donusecegi nesne
var _object_nodes: Array = []      # nesne MultiMesh dugumleri (rebuild icin)
var _mesh_cache: Dictionary = {}   # model adi -> Mesh (GLB'den bir kez cikarilir)
var _solid_cells: Dictionary = {}
var _map_w: int = 0
var _map_h: int = 0
var _spawn_cell := Vector2i(5, 5)
var _held_item: String = ""

# Kamera + gorunum ayarlari (kaydedilir)
var cam_distance: float = 1.0  # yakinlik carpani
var cam_pitch: float = 52.0    # bakis acisi (derece)
var character_path: String = "custom:f2c29b/4fa7d8/5b6b8c"  # varsayilan: yuvarlak
var hat_id: String = "yok"
var face_path: String = ""
var hair_style: String = ""
var hair_color: Color = Color(0.35, 0.22, 0.12)

var player: Node3D
var camera: Camera3D
var hud: CanvasLayer

var _zoom_slider: HSlider
var _pitch_slider: HSlider
var _touches: Dictionary = {}
var _pinch_last: float = -1.0

func _ready() -> void:
	_load_settings()
	_build_environment()
	_build_world()
	_spawn_player()
	# Mevcut 2D arayuz 3D'nin ustunde aynen calisir (autoload tabanli)
	hud = load("res://scenes/HUD.tscn").instantiate()
	add_child(hud)
	hud.action_pressed.connect(_on_action_pressed)
	hud.hold_requested.connect(_on_hold_requested)
	_build_camera_ui()
	# CI ekran goruntusu modu: birkac saniye sonra kare kaydet ve cik
	if OS.has_environment("RABLE_SCREENSHOT"):
		_setup_screenshot(OS.get_environment("RABLE_SCREENSHOT"))

func _setup_screenshot(save_path: String) -> void:
	# Vitrin: ornek gorunum, kamera OYUN VARSAYILANINDA
	# (referansla olcek karsilastirmasi icin)
	player.set_character("custom:f2c29b/4fa7d8/5b6b8c")
	player.set_hair("kut", Color(0.35, 0.22, 0.12))
	player.set_hat("yok")
	await get_tree().create_timer(4.0).timeout
	_snap(save_path)
	# Ikinci kare: kusbakisi tum ada (teshis icin)
	_cam_locked = true
	camera.position = Vector3(_map_w / 2.0, 42.0, _map_h / 2.0 + 12.0)
	camera.rotation_degrees = Vector3(-74, 0, 0)
	await get_tree().create_timer(1.0).timeout
	_snap(save_path.replace(".png", "_wide.png"))
	# Aday vitrinleri: kategori basina bir kare (kullanici secimi icin)
	for f in SHOWCASE_FRAMES.size():
		var frame: Dictionary = SHOWCASE_FRAMES[f]
		var base := Vector3(60.0 + float(f) * 80.0, 30.0, 0.0)
		_build_showcase_frame(frame["rows"], base)
		camera.position = base + Vector3(frame["cam"][0], frame["cam"][1], frame["cam"][2])
		camera.rotation_degrees = Vector3(frame["pitch"], 0, 0)
		await get_tree().create_timer(1.2).timeout
		_snap(save_path.replace(".png", String(frame["suffix"]) + ".png"))
	# Tema ornek sayfasi (Turkce karakter testi dahil)
	var theme_layer := _build_theme_test()
	await get_tree().create_timer(0.6).timeout
	_snap(save_path.replace(".png", "_tema.png"))
	theme_layer.queue_free()  # envanter karesini kapatmasin
	# Envanter paneli acik + ilk esya secili (UI Adim 2)
	hud.inventory_button.button_pressed = true
	if not hud._inv_slots.is_empty():
		hud._on_slot_tapped(hud._inv_slots[0])
	await get_tree().create_timer(0.8).timeout
	_snap(save_path.replace(".png", "_envanter.png"))
	# Uretim paneli acik (UI Adim 3)
	hud.inventory_button.button_pressed = false
	hud.craft_button.button_pressed = true
	await get_tree().create_timer(0.8).timeout
	_snap(save_path.replace(".png", "_uretim.png"))
	# Son kare: arastirma agaci (UI Adim 5) - ornek malzemeyle
	hud.craft_button.button_pressed = false
	Inventory.add_item("stick", 5)
	Inventory.add_item("pebble", 3)
	Inventory.add_item("clay", 1)  # gizli dugum tetiklensin ("???")
	hud.research_button.button_pressed = true
	if hud.research_root.has_method("_show_info"):
		hud.research_root._show_info("stone_tools")
	await get_tree().create_timer(0.8).timeout
	_snap(save_path.replace(".png", "_arastirma.png"))
	get_tree().quit()

# Tema test sayfasi: paneller, sekme, butonlar, kategori daireleri.
# Sadece CI ekran goruntusu modunda kurulur.
func _build_theme_test() -> CanvasLayer:
	var UIColors := preload("res://scripts/ui_colors.gd")
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var root := PanelContainer.new()
	root.theme = load("res://theme_main.tres")
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.custom_minimum_size = Vector2(640, 0)
	layer.add_child(root)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	root.add_child(box)
	var tab := PanelContainer.new()
	tab.theme_type_variation = "TitleTab"
	tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(tab)
	var tab_label := Label.new()
	tab_label.theme_type_variation = "TitleTabLabel"
	tab_label.text = "Sırt Çantası"
	tab.add_child(tab_label)
	var header := Label.new()
	header.theme_type_variation = "HeaderLabel"
	header.text = "Şeker Gibi Başlık — ĞÜŞİÖÇ ğüşıöç"
	box.add_child(header)
	var body := Label.new()
	body.text = "Gövde metni 18px: Çalışma Masası yanında üretim açılır."
	box.add_child(body)
	var subtle := Label.new()
	subtle.theme_type_variation = "SubtleLabel"
	subtle.text = "İkincil açıklama 15px — ink_soft renkte, sakin."
	box.add_child(subtle)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var primary := Button.new()
	primary.theme_type_variation = "PrimaryButton"
	primary.text = "Üret"
	buttons.add_child(primary)
	var secondary := Button.new()
	secondary.text = "Vazgeç"
	buttons.add_child(secondary)
	var disabled_btn := Button.new()
	disabled_btn.text = "Kilitli"
	disabled_btn.disabled = true
	buttons.add_child(disabled_btn)
	# Kategori daireleri (pastel paleti tek bakista dogrulamak icin)
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 8)
	box.add_child(dots)
	for cat in UIColors.CATEGORY_COLORS:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(36, 36)
		var sb := StyleBoxFlat.new()
		sb.bg_color = UIColors.CATEGORY_COLORS[cat]
		sb.set_corner_radius_all(999)
		dot.add_theme_stylebox_override("panel", sb)
		dots.add_child(dot)
	return layer

func _snap(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("kare kaydedildi: ", path)

# --- Aday vitrinleri ------------------------------------------------------
# Quaternius (CC0) modelleri kategorilere ayrilmis etiketli siralar halinde
# sergilenir. Sira 0 kameradan en uzaktadir. "h": hedef yukseklik (m),
# "gap": yan yana aralik. Etiketler: A=agac, K=kaya, O=ot, C=cicek, M=mantar.
const SHOWCASE_FRAMES: Array = [
	{"suffix": "_agac", "cam": [0.0, 4.4, 14.0], "pitch": -12.0, "rows": [
		{"h": 2.4, "gap": 2.8, "items": [
			{"label": "A1", "model": "quat2_tree01"},
			{"label": "A2", "model": "quat2_tree02"},
			{"label": "A3", "model": "quat2_tree03"},
			{"label": "A4", "model": "quat2_tree04"},
			{"label": "A5", "model": "quat2_tree05"},
			{"label": "A6", "model": "quat2_tree06"}]},
		{"h": 2.4, "gap": 2.8, "items": [
			{"label": "A7", "model": "quat2_tree07"},
			{"label": "A8", "model": "quat2_tree08"},
			{"label": "A9", "model": "quat2_tree09"},
			{"label": "A10", "model": "quat2_tree10"},
			{"label": "A11", "model": "quat2_tree11"},
			{"label": "A12", "model": "quat2_tree12"}]},
	]},
	{"suffix": "_kaya", "cam": [0.0, 2.9, 10.5], "pitch": -14.0, "rows": [
		{"h": 1.1, "gap": 2.2, "items": [
			{"label": "K1", "model": "quat2_rock01"},
			{"label": "K2", "model": "quat2_rock02"},
			{"label": "K3", "model": "quat2_rock03"},
			{"label": "K4", "model": "quat2_rock04"},
			{"label": "K5", "model": "quat2_rock05"},
			{"label": "K6", "model": "quat2_rock06"},
			{"label": "K7", "model": "quat2_rock07"}]},
	]},
	{"suffix": "_bitki", "cam": [0.0, 2.4, 7.8], "pitch": -16.0, "rows": [
		{"h": 0.7, "gap": 1.6, "items": [
			{"label": "O1", "model": "quat2_grass01"},
			{"label": "O2", "model": "quat2_grass02"},
			{"label": "O3", "model": "quat2_grass03"},
			{"label": "O4", "model": "quat2_grass04"}]},
		{"h": 0.6, "gap": 1.6, "items": [
			{"label": "C1", "model": "quat2_flower01"},
			{"label": "C2", "model": "quat2_flower02"},
			{"label": "M1", "model": "quat2_mush01"},
			{"label": "M2", "model": "quat2_mush02"}]},
	]},
	{"suffix": "_karakter", "cam": [0.0, 1.8, 5.4], "pitch": -10.0, "rows": [
		{"h": 1.4, "gap": 1.5, "items": [
			{"label": "1", "model": "res://assets/models/characters/quat_sarisin.glb"},
			{"label": "2", "model": "res://assets/models/characters/quat_matt.glb"},
			{"label": "3", "model": "res://assets/models/characters/quat_asker.glb"},
			{"label": "4", "model": "res://assets/models/characters/quat_sam.glb"}]},
	]},
	{"suffix": "_alet", "cam": [0.0, 3.0, 10.8], "pitch": -15.0, "rows": [
		{"h": 0.9, "gap": 1.4, "by": "long", "items": [
			{"label": "S1", "model": "res://assets/models/tools/tool-axe.glb"},
			{"label": "S2", "model": "res://assets/models/tools/tool-pickaxe.glb"},
			{"label": "S3", "model": "res://assets/models/tools/tool-shovel.glb"},
			{"label": "S4", "model": "res://assets/models/tools/tool-hammer.glb"},
			{"label": "S5", "model": "res://assets/models/tools/tool-hoe.glb"}]},
		{"h": 1.4, "gap": 1.9, "by": "long", "items": [
			{"label": "T1", "model": "res://assets/models/tools/workbench.glb"},
			{"label": "T2", "model": "res://assets/models/tools/workbench-anvil.glb"},
			{"label": "T3", "model": "res://assets/models/tools/workbench-grind.glb"},
			{"label": "T4", "model": "quat_table"}]},
		{"h": 0.9, "gap": 1.4, "by": "long", "items": [
			{"label": "R1", "model": "res://assets/models/tools/resource-wood.glb"},
			{"label": "R2", "model": "res://assets/models/tools/resource-planks.glb"},
			{"label": "R3", "model": "res://assets/models/tools/resource-stone.glb"},
			{"label": "R4", "model": "res://assets/models/tools/tree-log-small.glb"},
			{"label": "R5", "model": "res://assets/models/tools/campfire-pit.glb"}]},
	]},
]

func _build_showcase_frame(rows: Array, base: Vector3) -> void:
	var root := Node3D.new()
	root.position = base
	add_child(root)
	var floor_inst := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(34, 18)
	floor_inst.mesh = floor_mesh
	floor_inst.position = Vector3(0, 0, 2.0)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.32, 0.55, 0.24)
	fm.roughness = 1.0
	floor_inst.material_override = fm
	root.add_child(floor_inst)
	for r in rows.size():
		var row: Dictionary = rows[r]
		var items: Array = row["items"]
		var gap: float = row["gap"]
		var h: float = row["h"]
		var z := float(r) * 2.8
		for i in items.size():
			var x := (float(i) - float(items.size() - 1) / 2.0) * gap
			var holder := Node3D.new()
			holder.position = Vector3(x, 0, z)
			root.add_child(holder)
			var model_id := String(items[i]["model"])
			var model_path := model_id if model_id.begins_with("res://") \
					else NATURE_PATH % model_id
			var scene: Node3D = load(model_path).instantiate()
			holder.add_child(scene)
			# Karakter paketlerinin gomulu silah/aletleri vitrinde de gizli
			for weapon_name in Player3DScript.EMBEDDED_WEAPONS:
				var weapon := scene.find_child(weapon_name, true, false)
				if weapon != null and weapon is Node3D:
					(weapon as Node3D).visible = false
			var aabb := _scene_aabb(scene)
			# "by": "long" -> yassi/genis modeller (masa, kalas) en uzun
			# eksenlerine gore olceklenir, yoksa devasa gorunurler
			var basis_size := aabb.get_longest_axis_size() \
					if String(row.get("by", "")) == "long" else aabb.size.y
			if basis_size > 0.01:
				var s := h / basis_size
				scene.scale = Vector3(s, s, s)
				scene.position = Vector3(-aabb.get_center().x * s, -aabb.position.y * s,
						-aabb.get_center().z * s)
			var label := Label3D.new()
			label.text = String(items[i]["label"])
			label.font_size = 72
			label.modulate = Color(0.08, 0.08, 0.08)
			label.outline_size = 14
			label.outline_modulate = Color(1, 1, 1)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position = Vector3(x, h + 0.35, z)
			root.add_child(label)

# Sahnedeki GORUNUR MeshInstance3D'lerin birlesik sinir kutusu (kok
# uzayinda). Gizlenen parcalar (orn. karakterlerin sakli silahlari)
# hesaba katilmaz - yoksa vitrin olcekleri sapitir.
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

var _cam_locked := false  # teshis kareleri icin takibi durdurur

func _process(delta: float) -> void:
	# Kamera: SADECE konum takip eder, aci sabit kalir
	if not _cam_locked:
		var target := player.position + _camera_offset()
		camera.position = camera.position.lerp(target, minf(1.0, 6.0 * delta))
	hud.set_action_state(_compute_action_state())
	_tick_regrow(delta)
	# Eldeki esya envanterden ciktiysa birak
	if _held_item != "" and Inventory.get_count(_held_item) <= 0:
		_on_hold_requested("")

func is_walkable(cell: Vector2i) -> bool:
	if cell.x < 1 or cell.y < 1 or cell.x >= _map_w - 1 or cell.y >= _map_h - 1:
		return false
	return not _solid_cells.has(cell)

# --- Kamera -------------------------------------------------------------

func _camera_offset() -> Vector3:
	var pitch := deg_to_rad(cam_pitch)
	return Vector3(0, sin(pitch), cos(pitch)) * (CAM_BASE_DIST * cam_distance)

func _apply_camera_angle() -> void:
	camera.rotation_degrees = Vector3(-cam_pitch, 0, 0)

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		cam_distance = clampf(float(parsed.get("zoom", 1.0)), 0.55, 1.7)
		cam_pitch = clampf(float(parsed.get("pitch", 52.0)), 35.0, 68.0)
		# v3 gecisi: karakter secimi sifirlandi (Sam denemesi geri alindi);
		# v>=3 kayitlardaki secimler aynen korunur
		if int(parsed.get("v", 1)) >= 3:
			var saved_char := String(parsed.get("character", character_path))
			if saved_char.begins_with("custom:") or ResourceLoader.exists(saved_char):
				character_path = saved_char
		hat_id = String(parsed.get("hat", hat_id))
		face_path = String(parsed.get("face", face_path))
		hair_style = String(parsed.get("hair", hair_style))
		hair_color = Color.from_string(String(parsed.get("hair_color", "")), hair_color)

func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"v": 3, "zoom": cam_distance,
				"pitch": cam_pitch, "character": character_path,
				"hat": hat_id, "face": face_path,
				"hair": hair_style, "hair_color": "#" + hair_color.to_html(false)}))

# Iki parmakla yakinlastirma (pinch); oyuncu hareketi 1. parmakta kalir
func _unhandled_input(event: InputEvent) -> void:
	# ARASTIRMA TESTI (yalnizca klavyeli ortam: masaustu/web).
	# F9: durum dokumu; F10: stone_tools dugumunu bedava malzemeyle ac
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			Research.debug_print_state()
		elif event.keycode == KEY_F10:
			Research.debug_research("stone_tools")
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
			if _pinch_last > 0.0:
				_save_settings()
			_pinch_last = -1.0
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.has(0) and _touches.has(1):
			var dist: float = _touches[0].distance_to(_touches[1])
			if _pinch_last > 0.0 and dist > 1.0:
				cam_distance = clampf(cam_distance * (_pinch_last / dist), 0.55, 1.7)
				if _zoom_slider != null:
					_zoom_slider.set_value_no_signal(cam_distance)
			_pinch_last = dist

# Ayar panelleri: sol kenarda "Kamera" ve "Görünüm" butonlari.
# Kamera: yakinlik/aci. Gorunum: karakter secimi + orman stili.
func _build_camera_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)

	var button := Button.new()
	button.text = "Kamera"
	button.toggle_mode = true
	button.position = Vector2(12, 190)
	button.size = Vector2(120, 46)
	button.add_theme_font_size_override("font_size", 18)
	layer.add_child(button)

	var look_button := Button.new()
	look_button.text = "Görünüm"
	look_button.toggle_mode = true
	look_button.position = Vector2(12, 244)
	look_button.size = Vector2(120, 46)
	look_button.add_theme_font_size_override("font_size", 18)
	layer.add_child(look_button)

	var panel := PanelContainer.new()
	panel.visible = false
	panel.position = Vector2(144, 190)
	panel.custom_minimum_size = Vector2(320, 0)
	layer.add_child(panel)
	button.toggled.connect(func(pressed: bool):
		panel.visible = pressed
		if pressed:
			look_button.button_pressed = false
		else:
			_save_settings())

	_build_look_panel(layer, look_button, button)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var zoom_label := Label.new()
	zoom_label.text = "Yakınlık"
	zoom_label.add_theme_font_size_override("font_size", 16)
	box.add_child(zoom_label)
	_zoom_slider = HSlider.new()
	_zoom_slider.min_value = 0.55
	_zoom_slider.max_value = 1.7
	_zoom_slider.step = 0.01
	_zoom_slider.value = cam_distance
	_zoom_slider.custom_minimum_size = Vector2(0, 36)
	_zoom_slider.value_changed.connect(func(v: float): cam_distance = v)
	box.add_child(_zoom_slider)

	var pitch_label := Label.new()
	pitch_label.text = "Açı (yatay <-> tepeden)"
	pitch_label.add_theme_font_size_override("font_size", 16)
	box.add_child(pitch_label)
	_pitch_slider = HSlider.new()
	_pitch_slider.min_value = 35.0
	_pitch_slider.max_value = 68.0
	_pitch_slider.step = 0.5
	_pitch_slider.value = cam_pitch
	_pitch_slider.custom_minimum_size = Vector2(0, 36)
	_pitch_slider.value_changed.connect(func(v: float):
		cam_pitch = v
		_apply_camera_angle())
	box.add_child(_pitch_slider)

# Gorunum paneli: karakter listesi + orman stili (secim aninda uygulanir)
func _build_look_panel(layer: CanvasLayer, look_button: Button, cam_button: Button) -> void:
	var panel := PanelContainer.new()
	panel.visible = false
	panel.position = Vector2(144, 100)
	panel.custom_minimum_size = Vector2(360, 0)
	layer.add_child(panel)
	look_button.toggled.connect(func(pressed: bool):
		panel.visible = pressed
		if pressed:
			cam_button.button_pressed = false
		else:
			_save_settings())

	# Tum icerik tek kaydirilabilir kolonda (panel ekrana sigsin)
	var outer := ScrollContainer.new()
	outer.custom_minimum_size = Vector2(360, 560)
	panel.add_child(outer)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	outer.add_child(box)

	var char_label := Label.new()
	char_label.text = "Karakter"
	char_label.add_theme_font_size_override("font_size", 17)
	box.add_child(char_label)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)

	var char_group := ButtonGroup.new()
	for option in CHARACTER_OPTIONS:
		var b := Button.new()
		b.text = option[0]
		b.toggle_mode = true
		b.button_group = char_group
		b.custom_minimum_size = Vector2(108, 42)
		b.add_theme_font_size_override("font_size", 15)
		b.button_pressed = option[1] == character_path
		var path: String = option[1]
		b.toggled.connect(func(pressed: bool):
			if pressed:
				character_path = path
				player.set_character(path)
				_save_settings())
		grid.add_child(b)

	# Sapka secimi
	var hat_label := Label.new()
	hat_label.text = "Şapka"
	hat_label.add_theme_font_size_override("font_size", 17)
	box.add_child(hat_label)
	var hat_grid := GridContainer.new()
	hat_grid.columns = 4
	hat_grid.add_theme_constant_override("h_separation", 6)
	hat_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(hat_grid)
	var hat_group := ButtonGroup.new()
	for option in HAT_OPTIONS:
		var hb := Button.new()
		hb.text = option[0]
		hb.toggle_mode = true
		hb.button_group = hat_group
		hb.add_theme_font_size_override("font_size", 13)
		hb.button_pressed = option[1] == hat_id
		var hid: String = option[1]
		hb.toggled.connect(func(pressed: bool):
			if pressed:
				hat_id = hid
				player.set_hat(hid)
				_save_settings())
		hat_grid.add_child(hb)

	# Sac: stil + renk (kendi tasarimimiz; renk aninda uygulanir)
	var hair_label := Label.new()
	hair_label.text = "Saç"
	hair_label.add_theme_font_size_override("font_size", 17)
	box.add_child(hair_label)
	var hair_grid := GridContainer.new()
	hair_grid.columns = 3
	hair_grid.add_theme_constant_override("h_separation", 6)
	hair_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(hair_grid)
	var hair_group := ButtonGroup.new()
	for option in HAIR_STYLES:
		var hsb := Button.new()
		hsb.text = option[0]
		hsb.toggle_mode = true
		hsb.button_group = hair_group
		hsb.add_theme_font_size_override("font_size", 13)
		hsb.button_pressed = option[1] == hair_style
		var style_id: String = option[1]
		hsb.toggled.connect(func(pressed: bool):
			if pressed:
				hair_style = style_id
				player.set_hair(hair_style, hair_color)
				_save_settings())
		hair_grid.add_child(hsb)
	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 5)
	box.add_child(color_row)
	var color_group := ButtonGroup.new()
	for c in HAIR_COLORS:
		var cb := Button.new()
		cb.toggle_mode = true
		cb.button_group = color_group
		cb.custom_minimum_size = Vector2(36, 36)
		var swatch := StyleBoxFlat.new()
		swatch.bg_color = c
		swatch.set_corner_radius_all(8)
		cb.add_theme_stylebox_override("normal", swatch)
		var pressed_swatch := StyleBoxFlat.new()
		pressed_swatch.bg_color = c
		pressed_swatch.set_corner_radius_all(8)
		pressed_swatch.border_color = Color.WHITE
		pressed_swatch.set_border_width_all(3)
		cb.add_theme_stylebox_override("pressed", pressed_swatch)
		cb.add_theme_stylebox_override("hover", swatch)
		cb.button_pressed = c.is_equal_approx(hair_color)
		var picked: Color = c
		cb.toggled.connect(func(pressed: bool):
			if pressed:
				hair_color = picked
				player.set_hair(hair_style, hair_color)
				_save_settings())
		color_row.add_child(cb)

	# Yuz aksesuari secimi
	var face_label := Label.new()
	face_label.text = "Yüz"
	face_label.add_theme_font_size_override("font_size", 17)
	box.add_child(face_label)
	var face_row := GridContainer.new()
	face_row.columns = 4
	face_row.add_theme_constant_override("h_separation", 6)
	box.add_child(face_row)
	var face_group := ButtonGroup.new()
	for option in FACE_OPTIONS:
		var fb2 := Button.new()
		fb2.text = option[0]
		fb2.toggle_mode = true
		fb2.button_group = face_group
		fb2.add_theme_font_size_override("font_size", 13)
		fb2.button_pressed = option[1] == face_path
		var fpath: String = option[1]
		fb2.toggled.connect(func(pressed: bool):
			if pressed:
				face_path = fpath
				player.set_face(fpath)
				_save_settings())
		face_row.add_child(fb2)

# --- Ortam: gokyuzu + gunes ---------------------------------------------

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.44, 0.69, 0.94)
	sky_mat.sky_horizon_color = Color(0.95, 0.93, 0.82)
	sky_mat.ground_bottom_color = Color(0.55, 0.72, 0.55)
	sky_mat.ground_horizon_color = Color(0.92, 0.90, 0.78)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -32, 0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	camera.fov = 45.0
	add_child(camera)
	_apply_camera_angle()

# --- Dunya kurulumu -----------------------------------------------------

func _build_world() -> void:
	var rows: Array[String] = MapData.MAP
	_map_h = rows.size()
	_map_w = rows[0].length()

	var ground_cells: Dictionary = {}
	for ch in GROUND_DEFS:
		ground_cells[ch] = []

	for y in _map_h:
		for x in _map_w:
			var cell := Vector2i(x, y)
			var ch := rows[y][x]
			var ground := "."
			match ch:
				"P":
					_spawn_cell = cell
				"T", "#", "m":
					_objects[cell] = ch
					_solid_cells[cell] = true
				_:
					if GROUND_DEFS.has(ch):
						ground = ch
			_ground_char[cell] = ground
			if GROUND_DEFS[ground]["solid"]:
				_solid_cells[cell] = true
			ground_cells[ground].append(cell)

	# Toplanabilir cicek ve mantarlar: bos cim hucrelerine serpistirilir
	# (dekordan ONCE atanir ki dekor dolu hucreleri atlasin)
	for cell in ground_cells["."]:
		if _objects.has(cell) or cell == _spawn_cell:
			continue
		var h := absi(cell.x * 57731 + cell.y * 86243) % 100
		if h < 4:
			_objects[cell] = "cicek"
		elif h < 7:
			_objects[cell] = "mantar"

	_build_terrain()
	_build_sea()
	_build_lake_surface()
	_build_sea_rocks()
	_build_decor(ground_cells["."] + ground_cells["h"])
	_rebuild_objects()

# Kiyi/deniz kayalari: ada cevresine serpistirilmis gri kayalar
# (yari batik adaciklar - referans gorunumun imzasi)
func _build_sea_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260720
	var rock_models := ["rock_smallA", "rock_smallB", "rock_largeA",
			"stone_smallE", "rock_smallF"]
	var groups: Dictionary = {}
	for i in 46:
		# Harita sinirinin disinda, kiyiya yakin bir halka
		var angle := rng.randf() * TAU
		var ring := 2.0 + rng.randf() * 9.0
		var cx := _map_w / 2.0
		var cz := _map_h / 2.0
		var rx := cx + cos(angle) * (_map_w / 2.0 + ring)
		var rz := cz + sin(angle) * (_map_h / 2.0 + ring)
		var model: String = rock_models[rng.randi() % rock_models.size()]
		if not groups.has(model):
			groups[model] = []
		var scale := 1.2 + rng.randf() * 2.2
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(scale, scale, scale))
		groups[model].append(Transform3D(basis, Vector3(rx, -0.24, rz)))
	for model in groups:
		add_child(_make_model_multimesh(model, groups[model]))

# --- Purussuz arazi -----------------------------------------------------
# Kare bloklar yerine TEK yumusak ortu: yukseklik ve renk komsu hucreler
# arasinda harmanlanir. Gol kiyilari merdiven degil dogal kavis olur;
# su hucreleri cukurlasir, deniz duzlemi iclerini doldurur (kumsal suya
# egimle iner).

func _cell_props(cx: int, cy: int) -> Array:
	if cx < 0 or cy < 0 or cx >= _map_w or cy >= _map_h:
		return [-1.0, Color(0.72, 0.60, 0.38)]  # harita disi: denize inen yamac
	var ch: String = _ground_char.get(Vector2i(cx, cy), ".")
	var def: Dictionary = GROUND_DEFS[ch]
	if ch == "~":
		# Golun dibi kumlu; su yuzeyini deniz duzlemi saglar
		return [-0.40, Color(0.62, 0.54, 0.36)]
	if ch == "o":
		return [-0.30, def["color"]]
	if ch == "h":
		return [1.1, def["color"]]
	# Duz alanlar hafif dalgali: dogal tepecik hissi (yumusak fonksiyon)
	var roll := sin(cx * 0.37) * cos(cy * 0.29) * 0.07 \
			+ sin(cx * 0.15 + cy * 0.42) * 0.05
	return [roll, def["color"]]

# Bir dunya noktasinda yukseklik+renk (4 komsu hucrenin harmani)
func _sample_terrain(x: float, z: float) -> Array:
	var cx := x - 0.5
	var cz := z - 0.5
	var i0 := floori(cx)
	var j0 := floori(cz)
	var fx := cx - float(i0)
	var fz := cz - float(j0)
	var height := 0.0
	var col := Color(0, 0, 0)
	for dj in 2:
		for di in 2:
			var wgt := (fx if di == 1 else 1.0 - fx) * (fz if dj == 1 else 1.0 - fz)
			var props := _cell_props(i0 + di, j0 + dj)
			height += float(props[0]) * wgt
			col += Color(props[1]) * wgt
	return [height, col]

var _terrain_node: MeshInstance3D  # kazma sonrasi yeniden kurmak icin

func _build_terrain() -> void:
	if _terrain_node != null:
		_terrain_node.queue_free()
	var res := 4  # hucre basina 4x4 yama (0.25 m) - falez kenari keskin cikar
	var vw := _map_w * res
	var vh := _map_h * res
	# 1. gecis: yukseklik + ham renk izgarasi
	var hgt: Array = []
	var raw: Array = []
	for j in vh + 1:
		var row_h := PackedFloat32Array()
		var row_c: Array = []
		for i in vw + 1:
			var s := _sample_terrain(float(i) / float(res), float(j) / float(res))
			row_h.append(float(s[0]))
			row_c.append(s[1])
		hgt.append(row_h)
		raw.append(row_c)
	# 2. gecis: diklik izgaradan olculur (0.5 m mesafedeki komsu farki),
	# renkler falez/gecis kusagina gore boyanir
	var cols: Array = []
	for j in vh + 1:
		var row: Array = []
		for i in vw + 1:
			var height: float = hgt[j][i]
			var c: Color = raw[j][i]
			var steep := 0.0
			for off: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
				var ni: int = clampi(i + off.x, 0, vw)
				var nj: int = clampi(j + off.y, 0, vh)
				steep = maxf(steep, absf(hgt[nj][ni] - height))
			if steep > 0.40:
				# Falez: net yatay katmanlar (bulanik gri yerine kaya seritleri)
				var layer := int(floorf((height + 8.0) * 5.0))
				var band := 0.30 if layer % 2 == 0 else 0.70
				band += sin(float(i) * 0.9 + float(j) * 0.7) * 0.10
				c = Color(0.33, 0.29, 0.24).lerp(
						Color(0.49, 0.43, 0.35), clampf(band, 0.0, 1.0))
			elif steep > 0.26:
				# Cim -> kaya arasinda dar toprak kusagi (yesil falezden akmasin)
				c = c.lerp(Color(0.40, 0.34, 0.25), (steep - 0.26) / 0.14 * 0.85)
			# Organik his: renkte deterministik minik oynama
			var n := sin(float(i) * 12.9898 + float(j) * 78.233) * 0.035
			row.append(Color(c.r * (1.0 + n), c.g * (1.0 + n), c.b * (1.0 + n)))
		cols.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 1.0 / float(res)
	for j in vh:
		for i in vw:
			for tri in [[Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i, j + 1)],
					[Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]]:
				for v: Vector2i in tri:
					st.set_color(cols[v.y][v.x])
					st.add_vertex(Vector3(float(v.x) * step, hgt[v.y][v.x], float(v.y) * step))
	st.generate_normals()
	var inst := MeshInstance3D.new()
	inst.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.albedo_texture = _make_neutral_speckle()
	# Ucgen UV'si yerine dunya-uzayi doku: dik yamaclarda cizgi cizgi akmaz
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(0.5, 0.5, 0.5)
	inst.material_override = material
	add_child(inst)
	_terrain_node = inst

# Notr benek dokusu: koyu/acik gri noktalar, renkleri carparak dokular
var _neutral_speckle: ImageTexture

func _make_neutral_speckle() -> ImageTexture:
	if _neutral_speckle != null:
		return _neutral_speckle
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	img.fill(Color(0.97, 0.97, 0.97))
	for i in 110:
		var px := rng.randi_range(0, size - 1)
		var py := rng.randi_range(0, size - 1)
		var tone := 0.86 + rng.randf() * 0.24
		var c := Color(tone, tone, tone)
		img.set_pixel(px, py, c)
		img.set_pixel((px + 1) % size, py, c)
	_neutral_speckle = ImageTexture.create_from_image(img)
	return _neutral_speckle

# Harita bir ada: cevresini ufka kadar dalgali deniz sarar.
# Deniz 4 SERIT halinde sadece haritanin DISINI kaplar: harita icinde
# su duzlemi olmadigi icin kazilan cukurlar denizle dolmaz (gollerin
# kendi yuzeyi var). Seritler kiyi cizgisini kapatmak icin harita
# sinirindan 1 hucre iceri tasar (kenar hucreleri kazilamaz zaten).
func _build_sea() -> void:
	var m := 160.0
	var strips := [
		# [boyut, merkez]  kuzey / guney / bati / dogu
		[Vector2(_map_w + 2.0 * m, m + 1.0),
				Vector3(_map_w / 2.0, -0.17, (1.0 - m) / 2.0)],
		[Vector2(_map_w + 2.0 * m, m + 1.0),
				Vector3(_map_w / 2.0, -0.17, _map_h + (m - 1.0) / 2.0)],
		[Vector2(m + 1.0, _map_h - 2.0),
				Vector3((1.0 - m) / 2.0, -0.17, _map_h / 2.0)],
		[Vector2(m + 1.0, _map_h - 2.0),
				Vector3(_map_w + (m - 1.0) / 2.0, -0.17, _map_h / 2.0)],
	]
	for s in strips:
		var plane := PlaneMesh.new()
		plane.size = s[0]
		plane.subdivide_width = maxi(8, int(s[0].x / 4.0))
		plane.subdivide_depth = maxi(8, int(s[0].y / 4.0))
		var sea := MeshInstance3D.new()
		sea.mesh = plane
		sea.material_override = _water_material()
		sea.position = s[1]
		add_child(sea)

# Dalgali su malzemesi (deniz + harita ici su ayni gorunum)
var _water_mat: ShaderMaterial

func _water_material() -> ShaderMaterial:
	if _water_mat != null:
		return _water_mat
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
// Opak su: seffaflik siralama sorunlari (beyaz ucgen artiklari) olmaz
uniform vec4 col : source_color = vec4(0.13, 0.36, 0.66, 1.0);
void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * 1.6 + wp.x * 0.9 + wp.z * 0.7) * 0.05
			+ cos(TIME * 1.1 + wp.z * 1.3) * 0.03;
}
void fragment() {
	vec3 wp2 = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Suda gezinen beyaz isilti seritleri (Longvinter dalgalari)
	float band = sin(wp2.x * 0.9 + TIME * 0.5) * sin(wp2.z * 1.4 - TIME * 0.35)
			* sin((wp2.x + wp2.z) * 0.35 + TIME * 0.22);
	float foam = smoothstep(0.86, 0.97, band);
	ALBEDO = mix(col.rgb, vec3(0.94, 0.97, 1.0), foam * 0.75);
	ROUGHNESS = 0.45;
	SPECULAR = 0.2;
}
"""
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = shader
	return _water_mat

# --- Gol yuzeyi ----------------------------------------------------------
# Deniz duzlemi (-0.17) golleri dolduruyordu ama deniz izgarasi cok seyrek
# oldugundan kucuk gol alaninda dalga okunmuyordu. Goller icin "~"
# hucrelerini (kenar payiyla) orten ayri ince izgara kurulur; kendi
# shader'i daha sik ve hizli dalgalanir. MeshInstance3D oldugu icin
# shader sorunsuz calisir (MultiMesh kisiti yok).
const LAKE_Y := -0.15

func _build_lake_surface() -> void:
	var lake_cells: Dictionary = {}
	for cell in _ground_char:
		if _ground_char[cell] == "~":
			lake_cells[cell] = true
	if lake_cells.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var res := 4  # 0.25 m karolar: kiyi kopugu bandi puruzsuz olsun
	var step := 1.0 / float(res)
	var quads := 0
	for j in _map_h * res:
		for i in _map_w * res:
			var x0 := float(i) * step
			var z0 := float(j) * step
			if not _near_lake(lake_cells, x0 + step * 0.5, z0 + step * 0.5):
				continue
			for tri in [[Vector2(x0, z0), Vector2(x0 + step, z0), Vector2(x0, z0 + step)],
					[Vector2(x0 + step, z0), Vector2(x0 + step, z0 + step), Vector2(x0, z0 + step)]]:
				for p: Vector2 in tri:
					st.set_normal(Vector3.UP)
					# Su derinligi kose rengine islenir: shader bununla
					# sig/derin rengi ve kiyi kopugunu cizer (derinlik
					# dokusu gerektirmez - telefon GL'inde garantili).
					# Derinlik ARAZIDEN olculur: kopuk, su cizgisinin
					# dogal kavisini izler (hucre zikzaki olmaz)
					st.set_color(Color(_shore_depth(p.x, p.y), 0, 0))
					st.add_vertex(Vector3(p.x, LAKE_Y, p.y))
			quads += 1
	if quads == 0:
		return
	var inst := MeshInstance3D.new()
	inst.mesh = st.commit()
	inst.material_override = _lake_material()
	add_child(inst)

# Noktadaki su derinligi: 0 (su cizgisi) .. 1 (dip). Arazi yuksekliginden
# hesaplanir, boylece kiyi kopugu gercek kiyi kavisini izler.
func _shore_depth(x: float, z: float) -> float:
	return clampf((LAKE_Y - ground_height(x, z)) / 0.22, 0.0, 1.0)

# Nokta bir gol hucresine (kiyi payi dahil) yakin mi? Su yuzeyi kiyida
# arazinin altina girsin diye karolar hucre sinirindan biraz tasar.
func _near_lake(lake_cells: Dictionary, x: float, z: float) -> bool:
	var ci := floori(x)
	var cj := floori(z)
	for dj in range(-1, 2):
		for di in range(-1, 2):
			var cell := Vector2i(ci + di, cj + dj)
			if not lake_cells.has(cell):
				continue
			var nx := clampf(x, float(cell.x), float(cell.x) + 1.0)
			var nz := clampf(z, float(cell.y), float(cell.y) + 1.0)
			# Genis pay: su duzlemi su cizgisini her yerde gecsin (fazlasi
			# arazinin altinda kalir, gorunmez)
			if Vector2(x - nx, z - nz).length() <= 0.6:
				return true
	return false

var _lake_mat: ShaderMaterial

func _lake_material() -> ShaderMaterial:
	if _lake_mat != null:
		return _lake_mat
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
// SAKIN gol (Longvinter usulu): duz, temiz su malzemesi. Abartili
// dalga/kopuk yok - sadece kiyida ince bir kopuk cizgisi, cok hafif
// salinim ve gunes parlamasi icin puruzsuz yuzey. Derinlik COLOR.r'de.
uniform vec4 deep_col : source_color = vec4(0.15, 0.38, 0.62, 1.0);
uniform vec4 shallow_col : source_color = vec4(0.25, 0.55, 0.72, 1.0);
void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Cok hafif salinim: su oldugu belli olsun, dalga hissi olmasin
	VERTEX.y += sin(TIME * 1.1 + wp.x * 1.6 + wp.z * 1.2) * 0.008;
}
void fragment() {
	vec3 wp2 = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float depth = COLOR.r;
	vec3 col = mix(shallow_col.rgb, deep_col.rgb, smoothstep(0.05, 0.85, depth));
	// Kiyida INCE, yavas nefes alan kopuk cizgisi
	float wobble = sin(wp2.x * 3.1 + wp2.z * 2.6 + TIME * 0.7) * 0.02;
	float foam_edge = smoothstep(0.14, 0.05, depth + wobble);
	col = mix(col, vec3(0.93, 0.97, 1.0), foam_edge * 0.6);
	// Gunes yansimasi icin hafif yuzey kirisikligi (gorunmez ama
	// parlamayi canli tutar)
	NORMAL = normalize(NORMAL + vec3(sin(wp2.x * 2.2 + TIME * 0.6) * 0.02,
			0.0, cos(wp2.z * 1.9 + TIME * 0.5) * 0.02));
	ALBEDO = col;
	ROUGHNESS = 0.12;
	SPECULAR = 0.65;
}
"""
	_lake_mat = ShaderMaterial.new()
	_lake_mat.shader = shader
	return _lake_mat

# Bos cim hucrelerinin bir kismina sus otu serpistirir (toplanmaz).
var _decor_nodes: Array = []
var _decor_cells: Array = []

func _build_decor(grass_cells: Array) -> void:
	for node in _decor_nodes:
		node.queue_free()
	_decor_nodes.clear()
	_decor_cells = grass_cells
	var pool := _model_pool("quat2_grass01", 0.30)
	var groups: Dictionary = {}  # havuz indeksi -> Array[Transform3D]
	for cell in grass_cells:
		if _objects.has(cell) or cell == _spawn_cell:
			continue
		if _ground_char.get(cell, ".") == "o":
			continue  # kazilmis cukurda sus otu olmaz
		var h := absi(cell.x * 92821 + cell.y * 68917) % 100
		if h >= 20:
			continue  # ~her 5 hucreden biri suslenir
		var idx := h % pool.size()
		if not groups.has(idx):
			groups[idx] = []
		# Hucre icinde hafif kaydirma: izgara hissi kirilsin
		var off := Vector3(sin(cell.x * 12.9) * 0.25, 0, cos(cell.y * 7.7) * 0.25)
		groups[idx].append(Transform3D(_cell_variance(cell), _cell_center(cell) + off))
	for idx in groups:
		var node := _make_mesh_multimesh(pool[idx], groups[idx], false)
		add_child(node)
		_decor_nodes.append(node)

## Bir dunya noktasindaki arazi yuksekligi (oyuncu ve nesneler icin)
func ground_height(x: float, z: float) -> float:
	return float(_sample_terrain(x, z)[0])

func _cell_center(cell: Vector2i) -> Vector3:
	var x := cell.x + 0.5
	var z := cell.y + 0.5
	return Vector3(x, ground_height(x, z), z)

# Nesne gorsellerini bastan kurar (toplama sonrasi cagrilir).
# Tur basina birkac MultiMesh: yuzlerce nesne, ~10 cizim cagrisi.
func _rebuild_objects() -> void:
	for node in _object_nodes:
		node.queue_free()
	_object_nodes.clear()

	var trees: Array[Vector2i] = []
	var stones: Array[Vector2i] = []
	var bushes_full: Array[Vector2i] = []
	var bushes_empty: Array[Vector2i] = []
	var flowers: Array[Vector2i] = []
	var mushrooms: Array[Vector2i] = []
	for cell in _objects:
		match _objects[cell]:
			"T": trees.append(cell)
			"#": stones.append(cell)
			"m": bushes_full.append(cell)
			"n": bushes_empty.append(cell)
			"cicek": flowers.append(cell)
			"mantar": mushrooms.append(cell)

	_build_trees(trees)
	_build_stones(stones)
	_build_bushes(bushes_full, bushes_empty)
	_build_pickups(flowers, "cicek")
	_build_pickups(mushrooms, "mantar")

# Agaclar: tree02 cam paketi (kullanici secimi) - hafif, duz renkli
# modeller; paketteki her cam ayri varyant. Boylar normalize.
func _tree_pool() -> Array:
	return _model_pool("quat2_tree02", TREE_HEIGHT)

func _build_trees(cells: Array[Vector2i]) -> void:
	var pool := _tree_pool()
	var groups: Dictionary = {}
	for cell in cells:
		var idx := absi(cell.x * 31 + cell.y * 57) % pool.size()
		if not groups.has(idx):
			groups[idx] = []
		groups[idx].append(Transform3D(_cell_variance(cell), _cell_center(cell)))
	for idx in groups:
		_keep(_make_mesh_multimesh(pool[idx], groups[idx]))

# Hucrenin tas turu: %60 normal (iki gorunum), %30 komur, %10 altin
func _stone_variant(cell: Vector2i) -> int:
	var h := absi(cell.x * 41 + cell.y * 89) % 10
	if h < 3:
		return 0
	if h < 6:
		return 1
	return 2 if h < 9 else 3

func _build_stones(cells: Array[Vector2i]) -> void:
	var groups: Dictionary = {}  # Vector2i(tur, havuz indeksi) -> transformlar
	for cell in cells:
		var v := _stone_variant(cell)
		var pool: Array = _model_pool(STONE_VARIANTS[v]["model"], STONE_VARIANTS[v]["h"])
		var key := Vector2i(v, absi(cell.x * 17 + cell.y * 43) % pool.size())
		if not groups.has(key):
			groups[key] = []
		groups[key].append(Transform3D(_cell_variance(cell), _cell_center(cell)))
	for key in groups:
		var pool: Array = _model_pool(STONE_VARIANTS[key.x]["model"], STONE_VARIANTS[key.x]["h"])
		_keep(_make_mesh_multimesh(pool[key.y], groups[key]))

# Toplanabilir cicek/mantar gorselleri
func _pickup_pool(kind: String) -> Array:
	if kind == "cicek":
		return _model_pool("quat2_flower02", 0.45) + _model_pool("quat2_flower01", 0.35)
	return _model_pool("quat2_mush02", 0.35)

func _build_pickups(cells: Array[Vector2i], kind: String) -> void:
	if cells.is_empty():
		return
	var pool := _pickup_pool(kind)
	var groups: Dictionary = {}
	for cell in cells:
		var idx := absi(cell.x * 23 + cell.y * 71) % pool.size()
		if not groups.has(idx):
			groups[idx] = []
		groups[idx].append(Transform3D(_cell_variance(cell), _cell_center(cell)))
	for idx in groups:
		_keep(_make_mesh_multimesh(pool[idx], groups[idx], false))

func _build_bushes(full: Array[Vector2i], empty: Array[Vector2i]) -> void:
	for v in BUSH_VARIANTS.size():
		var f: Array = []
		var e: Array = []
		for cell in full:
			if _bush_variant(cell) == v:
				f.append(cell)
		for cell in empty:
			if _bush_variant(cell) == v:
				e.append(cell)
		if not f.is_empty():
			_keep(_make_mesh_multimesh(_bush_game_mesh(v, true), _bush_transforms(f)))
		if not e.is_empty():
			_keep(_make_mesh_multimesh(_bush_game_mesh(v, false), _bush_transforms(e)))

# Her cali hucresi iki secilen turden birine baglanir (deterministik:
# toplayip yeniden buyuyunce ayni tur kalir)
func _bush_variant(cell: Vector2i) -> int:
	return absi(cell.x * 53 + cell.y * 97) % BUSH_VARIANTS.size()

func _bush_transforms(cells: Array) -> Array:
	var t: Array = []
	for cell: Vector2i in cells:
		t.append(Transform3D(_cell_variance(cell), _cell_center(cell)))
	return t

# --- Oyun calilari: Quaternius modelleri ----------------------------------
# Kullanicinin sectigi iki tur: cicekli pofuduk + kizil. Dolu cali canli
# renkli; toplanmis cali ayni modelin kucultulmus, soluk halidir.
const BUSH_VARIANTS: Array[String] = ["quat_bushFlowers", "quat_bushRed"]

var _bush_game_cache: Dictionary = {}

func _bush_game_mesh(variant: int, full: bool) -> ArrayMesh:
	var key := variant * 2 + (1 if full else 0)
	if _bush_game_cache.has(key):
		return _bush_game_cache[key]
	var mesh := _merged_scene_mesh(NATURE_PATH % BUSH_VARIANTS[variant],
			0.85 if full else 0.60)
	if not full:
		# Toplanmis: soluk/donuk ton (dokulu materyalde albedo carpani)
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			if mat is BaseMaterial3D:
				var dull: BaseMaterial3D = mat.duplicate()
				dull.albedo_color = dull.albedo_color * Color(0.58, 0.62, 0.52, 1.0)
				mesh.surface_set_material(i, dull)
	_bush_game_cache[key] = mesh
	return mesh

# GLB sahnesindeki TUM yuzeyleri tek ArrayMesh'te birlestirir (MultiMesh
# tek mesh ister; cok parcali modeller boylece eksiksiz kalir).
# Sonuc normalize: taban y=0, yukseklik target_h, yatayda merkezli.
func _merged_scene_mesh(path: String, target_h: float) -> ArrayMesh:
	var scene: Node3D = load(path).instantiate()
	var mesh := _merged_node_mesh(scene, target_h)
	scene.free()
	return mesh

func _merged_node_mesh(node: Node, target_h: float) -> ArrayMesh:
	var aabb := _scene_aabb(node)
	var s := target_h / maxf(aabb.size.y, 0.01)
	var norm := Transform3D(Basis.IDENTITY.scaled(Vector3(s, s, s)),
			Vector3(-aabb.get_center().x * s, -aabb.position.y * s,
					-aabb.get_center().z * s))
	var result := ArrayMesh.new()
	_merge_into(node, norm, result)
	return result

# "Paket" GLB'ler (tek dosyada birden cok agac/kaya) icin varyant havuzu:
# mesh tasiyan her ust duzey cocuk ayri, normalize edilmis bir mesh olur.
# Tek parcali modellerde havuz tek elemanlidir.
var _pool_cache: Dictionary = {}

func _model_pool(model: String, target_h: float) -> Array:
	var key := model + ":" + str(target_h)
	if _pool_cache.has(key):
		return _pool_cache[key]
	var scene: Node3D = load(NATURE_PATH % model).instantiate()
	var parts: Array = []
	for child in scene.get_children():
		if _scene_aabb(child).size.y > 0.001:
			parts.append(child)
	var pool: Array = []
	if parts.size() <= 1:
		pool.append(_merged_node_mesh(scene, target_h))
	else:
		for part in parts:
			pool.append(_merged_node_mesh(part, target_h))
	scene.free()
	_pool_cache[key] = pool
	return pool

func _merge_into(node: Node, xform: Transform3D, result: ArrayMesh) -> void:
	var t := xform
	if node is Node3D:
		t = xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var m: Mesh = (node as MeshInstance3D).mesh
		for i in m.get_surface_count():
			var st := SurfaceTool.new()
			st.append_from(m, i, t)
			var mat := m.surface_get_material(i)
			if mat != null:
				st.set_material(mat)
			st.commit(result)
	for child in node.get_children():
		_merge_into(child, t, result)

func _make_mesh_multimesh(mesh: Mesh, transforms: Array,
		shadows := true) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	if not shadows:
		# Kucuk bitki ortusu golge cizmesin: telefonda bedava hiz
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _keep(node: MultiMeshInstance3D) -> void:
	add_child(node)
	_object_nodes.append(node)

# GLB modelinden Mesh cikarir (bir kez; sonrasi onbellekten).
# Kenney doga modelleri tek mesh'tir; materyaller mesh'in icinde gelir.
func _find_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			return mi.mesh
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null

func _model_mesh(model: String) -> Mesh:
	if _mesh_cache.has(model):
		return _mesh_cache[model]
	var scene: Node = load(NATURE_PATH % model).instantiate()
	var mesh := _find_mesh(scene)
	scene.free()
	# Renk duzeltme: Kenney'nin camgobegi yesilleri gercek orman
	# yesiline cevrilir (mavi kanali kisilir). Kahve govdeler ve
	# kirmizi/sari cicekler etkilenmez (yesil baskin olanlar duzeltilir).
	if mesh != null:
		mesh = mesh.duplicate()
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			if mat is BaseMaterial3D:
				var fixed: BaseMaterial3D = mat.duplicate()
				var c := fixed.albedo_color
				if c.g > c.r and c.b > c.r:
					fixed.albedo_color = Color(c.r * 1.05, c.g * 0.88, c.b * 0.40, c.a)
				fixed.roughness = 1.0
				mesh.surface_set_material(i, fixed)
	_mesh_cache[model] = mesh
	return mesh

func _make_model_multimesh(model: String, transforms: Array) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = _model_mesh(model)
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	return node

# Hucreye bagli deterministik minik dondurme/olcek farki (organik gorunum)
func _cell_variance(cell: Vector2i) -> Basis:
	var seed_val := float(cell.x * 73 + cell.y * 131)
	var angle := sin(seed_val) * PI
	var scale := 0.9 + 0.2 * absf(sin(seed_val * 1.7))
	return Basis(Vector3.UP, angle).scaled(Vector3(scale, scale, scale))

func _make_multimesh(mesh: Mesh, color: Color, transforms: Array, water := false) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if water:
		# Gol hucreleri: duz parlak mavi (dalga shader'i MultiMesh'te
		# derlenemiyor ve beyaz dusuyordu; shader sadece denizde)
		material.roughness = 0.25
	else:
		material.roughness = 1.0
	node.material_override = material
	return node

# --- Oyuncu -------------------------------------------------------------

func _spawn_player() -> void:
	player = Player3DScript.new()
	player.world = self
	player.position = _cell_center(_spawn_cell)
	add_child(player)
	player.set_character(character_path)  # kayitli secim
	player.set_hat(hat_id)
	player.set_face(face_path)
	player.set_hair(hair_style, hair_color)
	player.world_tapped.connect(_on_world_tapped)
	camera.position = player.position + _camera_offset()

func _player_cell() -> Vector2i:
	return Vector2i(floori(player.position.x), floori(player.position.z))

# --- Etkilesim ----------------------------------------------------------

## Ekrandaki dokunusu zemin duzlemine (y=0) izdusurup hucre bulur.
func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return Vector2i(-999, -999)
	var t := -from.y / dir.y
	if t < 0.0:
		return Vector2i(-999, -999)
	var hit := from + dir * t
	return Vector2i(floori(hit.x), floori(hit.z))

func _on_world_tapped(screen_pos: Vector2) -> void:
	var cell := _screen_to_cell(screen_pos)
	var pc := _player_cell()
	var diff := (cell - pc).abs()
	if maxi(diff.x, diff.y) > 1:
		return
	if _ground_char.get(cell, "") == "~" and not _objects.has(cell):
		Thirst.drink()
		_spawn_floating_text(cell, "Su içtin!", Color(0.6, 0.85, 1.0))
		return
	# Kurek eldeyken bos zemine dokun: cukur kaz (stratejik engel + toprak)
	if _held_item == "kurek" and _can_dig(cell):
		_dig_pit(cell)
		return
	# Toprak eldeyken cukura dokun: doldur
	if _held_item == "toprak" and _ground_char.get(cell, "") == "o":
		_fill_pit(cell)
		return
	_try_harvest(cell)

# --- Cukur kazma / doldurma ----------------------------------------------
# Cukur ("o") gecilmez: oyuncu ve (B3'te gelecek) yaratiklar uzerinden
# yuruyemez. Kazi toprak verir; toprakla geri doldurulur.

func _can_dig(cell: Vector2i) -> bool:
	if cell == _player_cell() or cell == _spawn_cell:
		return false
	if _objects.has(cell):
		return false
	if cell.x < 1 or cell.y < 1 or cell.x >= _map_w - 1 or cell.y >= _map_h - 1:
		return false
	return _ground_char.get(cell, "") in [".", "d", "s"]

func _dig_pit(cell: Vector2i) -> void:
	if not Inventory.can_add_all({"toprak": 1}):
		_spawn_floating_text(cell, "Envanter dolu!", Color(1, 0.6, 0.6))
		return
	_ground_char[cell] = "o"
	_solid_cells[cell] = true
	Inventory.add_item("toprak", 1)
	_spawn_floating_text(cell, "+1 Toprak", Color(0.9, 0.75, 0.55))
	_refresh_terrain()

func _fill_pit(cell: Vector2i) -> void:
	if not Inventory.remove_item("toprak", 1):
		return
	_ground_char[cell] = "."
	_solid_cells.erase(cell)
	_spawn_floating_text(cell, "Çukur dolduruldu", Color(0.8, 1.0, 0.8))
	_refresh_terrain()

# Zemin degisince arazi ortusu, susler ve nesne yukseklikleri tazelenir
func _refresh_terrain() -> void:
	_build_terrain()
	_build_decor(_decor_cells)
	_rebuild_objects()

func _on_action_pressed() -> void:
	var pc := _player_cell()
	var facing_offset := Vector2i(player.facing.round())
	if facing_offset == Vector2i.ZERO:
		facing_offset = Vector2i(0, 1)
	var offsets: Array[Vector2i] = [facing_offset]
	for oy in [-1, 0, 1]:
		for ox in [-1, 0, 1]:
			var o := Vector2i(ox, oy)
			if o != Vector2i.ZERO and o != facing_offset:
				offsets.append(o)
	for o in offsets:
		if _try_harvest(pc + o):
			return

func _try_harvest(cell: Vector2i) -> bool:
	var ch: String = _objects.get(cell, "")
	if ch == "" or not OBJECT_DEFS.has(ch):
		return false
	var def: Dictionary = OBJECT_DEFS[ch]
	if ch == "#":
		# Tas turune gore dusen esya degisir (normal/komur/altin)
		var v := _stone_variant(cell)
		def = {"drops": STONE_VARIANTS[v]["drops"], "hits": STONE_VARIANTS[v]["hits"],
				"tool": {"item": "kazma", "hits": 2}}
	var hits_needed: int = def.get("hits", 1)
	if def.has("tool") and _held_item == def["tool"]["item"]:
		hits_needed = def["tool"]["hits"]
	var damage: int = int(_object_hits.get(cell, 0)) + 1
	if damage < hits_needed:
		_object_hits[cell] = damage
		_spawn_floating_text(cell, "%d/%d" % [damage, hits_needed], Color(1.0, 0.95, 0.6))
		return true
	if not Inventory.can_add_all(def["drops"]):
		_spawn_floating_text(cell, "Envanter dolu!", Color(1, 0.6, 0.6))
		return false
	_object_hits.erase(cell)
	var gained: PackedStringArray = []
	for item_id in def["drops"]:
		Inventory.add_item(item_id, def["drops"][item_id])
		gained.append("+%d %s" % [def["drops"][item_id], Items.display_name(item_id)])
	_spawn_floating_text(cell, " ".join(gained), Color(0.7, 1.0, 0.7))
	if def.has("becomes"):
		_objects[cell] = def["becomes"]
		_regrow[cell] = REGROW_SECONDS
		_regrow_type[cell] = ch
	elif def.get("vanish_regrow", false):
		# Cicek/mantar: kaybolur, bir sure sonra ayni yerde yeniden biter
		_objects.erase(cell)
		_regrow[cell] = REGROW_SECONDS * 2.0
		_regrow_type[cell] = ch
	else:
		_objects.erase(cell)
		_solid_cells.erase(cell)
	_rebuild_objects()
	return true

func _tick_regrow(delta: float) -> void:
	var ready_cells: Array[Vector2i] = []
	for cell in _regrow:
		_regrow[cell] -= delta
		if _regrow[cell] <= 0.0:
			ready_cells.append(cell)
	if ready_cells.is_empty():
		return
	for cell in ready_cells:
		_regrow.erase(cell)
		_objects[cell] = _regrow_type.get(cell, "m")
		_regrow_type.erase(cell)
	_rebuild_objects()

## Eline alinan aletin 3D modeli (Kenney Survival Kit)
const TOOL_MODELS := {
	"balta": "res://assets/models/tools/tool-axe.glb",
	"kazma": "res://assets/models/tools/tool-pickaxe.glb",
	"kurek": "res://assets/models/tools/tool-shovel.glb",
	"mizrak": "spear",  # ozel: player3d basit mizrak insa eder
}

func _on_hold_requested(item_id: String) -> void:
	if item_id != "" and Inventory.get_count(item_id) <= 0:
		return
	_held_item = item_id
	hud.set_held_item(item_id)
	player.set_held_tool(TOOL_MODELS.get(item_id, ""))

func _compute_action_state() -> String:
	var pc := _player_cell()
	for oy in [-1, 0, 1]:
		for ox in [-1, 0, 1]:
			if ox == 0 and oy == 0:
				continue
			var ch: String = _objects.get(pc + Vector2i(ox, oy), "")
			if ch != "" and OBJECT_DEFS.has(ch):
				return "gather"
	return "idle"

# Yukari suzulup kaybolan 3D yazi (toplama geri bildirimi)
func _spawn_floating_text(cell: Vector2i, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.outline_size = 10
	label.no_depth_test = true
	label.position = _cell_center(cell) + Vector3(0, 1.2, 0)
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y + 0.8, 0.7)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7)
	tween.tween_callback(label.queue_free)
