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
const MapGen = preload("res://scripts/map_gen.gd")       # harita-v2: noise ureteci
const MapBalance = preload("res://scripts/map_balance.gd")
const TimeBalance = preload("res://scripts/time_balance.gd")  # gunduz/gece
const Player3DScript = preload("res://scripts/player3d.gd")
const DigRules = preload("res://scripts/dig_rules.gd")
const WaterRules = preload("res://scripts/water_rules.gd")
const WaterSim = preload("res://scripts/water_sim.gd")
const ToolProfiles = preload("res://scripts/tool_profiles.gd")
const HittableDummy = preload("res://scripts/hittable_dummy.gd")
const StructureManager = preload("res://scripts/structure_manager.gd")
const EngBalance = preload("res://scripts/engineering_balance.gd")
const Recipes = preload("res://scripts/recipes.gd")
const Items = preload("res://scripts/items.gd")
const ChestStore = preload("res://scripts/inventory.gd")  # 14.1 sandik deposu

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
## Yerlestirilebilir yapilar (B3): model + hedef boyut + katilik.
## "long" varsa en uzun eksene gore olceklenir (duvar/zemin hucreyi doldursun)
# YAPI SISTEMI (Bolum 13): her yapinin yerlestirme + durum verisi TEK burada.
#   behavior: wall/station/door/bed/trap/floor/torch/tent (ozel mantik anahtari)
#   max_hp:   take_hit dayanikligi (13.4)
#   rotatable:yon 0/90/180/270 (13.2 dondur)
#   on_water/in_pit: 13.3 gecerlilik istisnalari (varsayilan false)
const PLACE_MODELS := {
	"tezgah": {"model": "res://assets/models/tools/workbench.glb",
			"h": 0.85, "solid": true, "behavior": "station", "max_hp": 120},
	"arastirma_masasi": {"model": "res://assets/models/nature/quat_table.glb",
			"h": 0.8, "solid": true, "long": 1.0,
			"behavior": "station", "max_hp": 120},
	"sandik": {"model": "res://assets/models/tools/chest.glb",
			"h": 0.55, "solid": true, "behavior": "station", "max_hp": 60},
	"ocak": {"model": "res://assets/models/tools/campfire-pit.glb",
			"h": 0.9, "solid": true, "behavior": "hearth", "max_hp": 400},
	"platform": {"model": "platform", "h": 1.5, "solid": false,
			"behavior": "platform", "max_hp": 100, "rotatable": true},
	"kamp_evi": {"model": "res://assets/models/tools/tent.glb",
			"extra": "res://assets/models/tools/tent-canvas.glb",
			"h": 1.3, "solid": true, "behavior": "tent", "max_hp": 200},
	"ahsap_duvar": {"model": "res://assets/models/tools/fence.glb",
			"h": 0.9, "solid": true, "long": 1.0,
			"behavior": "wall", "max_hp": 80, "rotatable": true},
	"tas_duvar": {"model": "res://assets/models/tools/fence-fortified.glb",
			"h": 0.95, "solid": true, "long": 1.0,
			"behavior": "wall", "max_hp": 160, "rotatable": true},
	"kapi": {"model": "res://assets/models/tools/fence-doorway.glb",
			"h": 1.0, "solid": false, "long": 1.0,
			"behavior": "door", "max_hp": 80, "rotatable": true},
	"yatak": {"model": "res://assets/models/tools/bedroll.glb",
			"h": 0.25, "solid": false, "long": 0.9,
			"behavior": "bed", "max_hp": 80, "rotatable": true},
	"tuzak": {"model": "res://assets/models/tools/box-open.glb",
			"h": 0.35, "solid": false,
			"behavior": "trap", "max_hp": 30, "in_pit": true},
	"zemin": {"model": "res://assets/models/tools/floor.glb",
			"h": 0.08, "solid": false, "long": 1.0,
			"behavior": "floor", "max_hp": 40},
	"mesale": {"model": "res://assets/models/tools/campfire-stand.glb",
			"h": 0.7, "solid": false,
			"behavior": "torch", "max_hp": 30},
	# MUHENDISLIK 11.5: merdiven — kazilmis cukura (pit_only) konur, kenara
	# yaslanir (rotatable = hangi kenar). Cukurdan cikis saglar (can_step).
	"merdiven": {"model": "ladder", "h": 1.0, "solid": false,
			"behavior": "ladder", "max_hp": 40,
			"rotatable": true, "in_pit": true, "pit_only": true},
	# MUHENDISLIK 11.9: cukur kazigi — kazilmis hucre TABANINA (in_pit +
	# pit_only). Dusen oyuncuya kucuk hasar; yaratik hapsi/hasari take_hit
	# kancalariyla hazir (davranis kodu YOK).
	"kazik": {"model": "spikes", "h": 0.5, "solid": false,
			"behavior": "spikes", "max_hp": 40,
			"in_pit": true, "pit_only": true},
	# MUHENDISLIK 11.8: boru — zemine ya da cukura konur; komsu borularla
	# otomatik baglanir (gorsel maskeden turer). Su aktarim grafi.
	"boru": {"model": "pipe", "h": 0.3, "solid": false,
			"behavior": "pipe", "max_hp": 40, "in_pit": true},
	# 11.8 pompa: hatta yukari akis saglar (yukseklik kuralini asar).
	"pompa": {"model": "pump", "h": 0.6, "solid": false,
			"behavior": "pump", "max_hp": 60, "in_pit": true},
	# 11.8 vana: hatta ac/kapa; kapaliyken transfer durur.
	"vana": {"model": "valve", "h": 0.5, "solid": false,
			"behavior": "valve", "max_hp": 40, "in_pit": true},
}

const REGROW_SECONDS := 60.0
const CAM_BASE_DIST := 12.5  # genis bakis (Longvinter benzeri olcek)
# harita-v2 Asama 2: uzak varsayilan (genis dunya hissi). Zoom carpani:
#   en yakin = mevcut yakinlik (0.55), varsayilan = orta nokta (1.375),
#   en uzak = ~1.6x varsayilan (2.2). Pinch/tekerlek bu araligi kullanir.
const CAM_ZOOM_MIN := 0.55
const CAM_ZOOM_DEFAULT := 1.375
const CAM_ZOOM_MAX := 2.2
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
# KAZI MODULU (11.1): hucre derinligi. Pozitif = kazilmis (1-4),
# negatif = toprak yigini yukseltisi (-1/-2). Gorsel TAMAMEN bu veriden
# turer (_cell_props); su modeli (11.2) _water_level'i okuyacak.
var _depth: Dictionary = {}        # hucre -> int (-2..4)
# SU MODELI (11.2): hucre basina su sutunu (seviye cinsinden) ve
# flood-fill'den cikan havuzlar [{cells, capacity, volume, surface}].
# Yalnizca _recompute_water() yazar; gorsel bu veriden turer.
var _water_level: Dictionary = {}  # hucre -> float su sutunu (0 = kuru)
var _pools: Array = []             # guncel havuz listesi
var _placed: Dictionary = {}       # hucre -> yerlestirilen yapi id'si
var _placed_nodes: Dictionary = {} # hucre -> yapi gorseli (Node3D)
# YAPI SISTEMI (Bolum 13): yapi ornekleri meta (yon/hp/durum). _placed id'yi,
# bu ise per-instance veriyi tutar (sidecar; mevcut sistem korunur).
var _structures = StructureManager.new()
var _chests: Dictionary = {}       # sandik hucresi -> Inventory ornegi (14.1 depo)
var _move_mode: bool = false       # Tasi butonu: yapiyi geri alma modu
var _open_chest := Vector2i(-999, -999)
# BASE (Bolum 14)
var _home_bed := Vector2i(-999, -999)   # 14.2 aktif dogus noktasi (son yatak)
var _hearth_cell := Vector2i(-999, -999) # 14.3 tek aktif ocak
var _hearth_light: OmniLight3D = null    # ocagin oncelikli (butcesiz) isigi
var _platform_cells: Dictionary = {}     # 14.4 platform hucresi -> true (yukseklik)
var _ground_items: Array = []      # yere birakilanlar [{cell,id,count,node}]
# ALET SISTEMI (Bolum 12)
var _dummies: Dictionary = {}      # test kuklalari: hucre -> {node, hp, ...}
# YAPI YERLESTIRME MODU (13.2)
var _place_mode: bool = false
var _place_item: String = ""
var _place_rot: int = 0
var _place_cell := Vector2i(-999, -999)
var _ghost: Node3D
var _ghost_valid: bool = false
var _ghost_needs_tint: bool = true
var _torch_lights: Dictionary = {}  # hucre -> OmniLight3D (13.5 mesale)
const MAX_TORCHES := 8              # ayni anda aktif isik butcesi (mobil)
var _target_ring: MeshInstance3D   # paylasilan hedef vurgu halkasi
var _projectiles: Array = []       # ucan mermiler [{node, vel, ...}]
var _aiming: bool = false          # menzilli silah nisan modu aktif mi
var _aim_charge: float = 0.0       # yay/sapan gerdirme orani (0..1)
var _aim_guide: MeshInstance3D     # nisan yay/cizgi gostergesi
var _station_timer: float = 0.0
var _regrow: Dictionary = {}       # hucre -> yeniden bitmeye kalan sure
var _regrow_type: Dictionary = {}  # hucre -> bitince donusecegi nesne
var _object_nodes: Array = []      # nesne MultiMesh dugumleri (rebuild icin)
var _mesh_cache: Dictionary = {}   # model adi -> Mesh (GLB'den bir kez cikarilir)
var _solid_cells: Dictionary = {}
var _map_w: int = 0
var _map_h: int = 0
var _map_seed: int = MapBalance.SEED_DEFAULT  # harita-v2 (sabit; aynı harita)
var _clay_cells: Dictionary = {}   # kil-işaretli kum hücreleri (kürek kaynağı)
var _base_objects: Dictionary = {} # kayit-sistemi: seed tabanı (diff için)
var _spawn_cell := Vector2i(5, 5)
var _held_item: String = ""

# KALICILIK (3D): dunya durumu (kazi/su/yapi/nesne) + hayatta kalma
# autoload'lari periyodik ve arka plana alininca kaydedilir. Arastirma
# kendi dosyasina yazar (research.json), buraya dahil degil.
const SAVE3D_PATH := "user://save3d.json"
const AUTOSAVE_INTERVAL := 120.0  # kayit-sistemi: her 2 dk otomatik kayit
var _dirty: bool = false       # son kayittan beri degisiklik oldu mu
var _autosave_timer: float = 0.0
var _loading: bool = false     # yukleme sirasinda autosave/kirlilik bastir

# Kamera + gorunum ayarlari (kaydedilir)
var cam_distance: float = CAM_ZOOM_DEFAULT  # yakinlik carpani (uzak varsayilan)
var cam_pitch: float = 52.0    # bakis acisi (derece)
var character_path: String = "custom:f2c29b/4fa7d8/5b6b8c"  # varsayilan: yuvarlak
var hat_id: String = "yok"
var face_path: String = ""
var hair_style: String = ""
var hair_color: Color = Color(0.35, 0.22, 0.12)

var player: Node3D
var camera: Camera3D
var hud: CanvasLayer
# gunduz/gece görsel döngü referansları
var _sun: DirectionalLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial

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
	hud.attack_pressed.connect(_on_attack_pressed)
	hud.attack_hold_started.connect(_on_attack_hold_started)
	hud.attack_hold_released.connect(_on_attack_hold_released)
	hud.place_requested.connect(_enter_place_mode)
	hud.place_confirm.connect(_place_confirm)
	hud.place_rotate.connect(_place_rotate)
	hud.place_cancel.connect(_exit_place_mode)
	hud.hold_requested.connect(_on_hold_requested)
	hud.move_toggled.connect(func(on: bool): _move_mode = on)
	hud.drop_item_requested.connect(_on_drop_item)
	hud.eat_requested.connect(_on_eat_requested)
	# YASAM cila: cig et bulantisi geri bildirimi (UI_DESIGN 4.5 dili)
	PlayerStats.nausea_started.connect(func():
		_spawn_floating_text(_player_cell(), "Midem bulandı", Color(0.7, 0.85, 0.5)))
	PlayerStats.player_died.connect(func(_c: int): _play_sfx("death"))
	hud.chest_transfer_requested.connect(_on_chest_transfer)
	hud.chest_transfer_all_requested.connect(_on_chest_transfer_all)
	hud.chest_dismantle_requested.connect(_on_chest_dismantle)
	hud.chest_closed.connect(func(): _open_chest = Vector2i(-999, -999))
	_build_camera_ui()
	# kayit-sistemi: SaveManager bu sahneyi (dünya durumu) kaydeder/yükler.
	SaveManager.world = self
	# Açılışta kayıt varsa "Devam Et / Yeni Oyun" seçimi; yoksa taze dünya
	# (zaten kuruldu). CI modunda atlanır ki sahneler hep temiz başlasın.
	if not OS.has_environment("RABLE_SCREENSHOT") and SaveManager.has_save():
		_show_start_menu()
	# CI ekran goruntusu modu: birkac saniye sonra kare kaydet ve cik
	if OS.has_environment("RABLE_SCREENSHOT"):
		_setup_screenshot(OS.get_environment("RABLE_SCREENSHOT"))

func _setup_screenshot(save_path: String) -> void:
	# harita-v2 MAPTEST: uretim istatistikleri (128x128 + su/agac/kaya/kil/dogus)
	var water_n := 0
	for c: Vector2i in _ground_char:
		if _ground_char[c] == "~":
			water_n += 1
	var tree_n := 0
	var rock_n := 0
	for c: Vector2i in _objects:
		if _objects[c] == "T":
			tree_n += 1
		elif _objects[c] == "#":
			rock_n += 1
	print("MAPTEST: boyut=%dx%d su=%d agac=%d kaya=%d kil=%d dogus=%s zemin=%s" % [
		_map_w, _map_h, water_n, tree_n, rock_n, _clay_cells.size(),
		str(_spawn_cell), _ground_char.get(_spawn_cell, "?")])
	print("CAMTEST: zoom_var=%.3f min=%.2f max=%.2f" % [
		cam_distance, CAM_ZOOM_MIN, CAM_ZOOM_MAX])
	# Vitrin: ornek gorunum, kamera OYUN VARSAYILANINDA
	# (referansla olcek karsilastirmasi icin)
	player.set_character("custom:f2c29b/4fa7d8/5b6b8c")
	player.set_hair("kut", Color(0.35, 0.22, 0.12))
	player.set_hat("yok")
	await get_tree().create_timer(4.0).timeout
	_snap(save_path)
	# Ikinci kare: kusbakisi tum ada (teshis icin)
	_cam_locked = true
	# harita-v2: kusbakisi tum 128x128 adayi kapsar (yukseklik boyutla olcekli)
	camera.position = Vector3(_map_w / 2.0, _map_w * 0.85,
			_map_h / 2.0 + _map_w * 0.22)
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
	# Son kare: gece vinyeti + "Geliyorlar..." pili (UI Adim 6)
	hud.research_button.button_pressed = false
	# Kamera vitrin studyosundan oyuncuya doner
	_apply_camera_angle()
	camera.position = player.position + _camera_offset()
	DayNight.phase = "night"; DayNight.elapsed = 120.0
	DayNight.is_night = true
	DayNight.night_started.emit()
	DayNight.changed.emit()
	await get_tree().create_timer(1.6).timeout
	_snap(save_path.replace(".png", "_gece.png"))
	# Son kare: B3 yerlestirme ornekleri (tezgah/masa/sandik/duvar/cadir)
	DayNight.phase = "day"; DayNight.elapsed = 200.0
	DayNight.is_night = false
	DayNight.day_started.emit()
	DayNight.changed.emit()
	var pc := _player_cell()
	for pair in [["tezgah", Vector2i(1, 0)], ["arastirma_masasi", Vector2i(1, 1)],
			["sandik", Vector2i(0, 1)], ["ahsap_duvar", Vector2i(-1, 0)],
			["ahsap_duvar", Vector2i(-1, 1)], ["kapi", Vector2i(-1, -1)],
			["kamp_evi", Vector2i(2, -1)]]:
		var pcell: Vector2i = pc + pair[1]
		if _ground_char.get(pcell, "") in [".", "d", "s"] \
				and not _objects.has(pcell) and not _placed.has(pcell):
			_set_placed(pcell, pair[0])
	await get_tree().create_timer(1.0).timeout
	_snap(save_path.replace(".png", "_b3.png"))
	# Son kare: KAZI MODULU - derinlik merdiveni (1..4) + toprak tumsekleri
	var kc := _player_cell() + Vector2i(-4, 0)
	for k in 4:
		var dcell := kc + Vector2i(0, -k)
		if _diggable(dcell):
			_depth[dcell] = k + 1
	for k in 2:
		var mcell := kc + Vector2i(-2, -k)
		if _diggable(mcell):
			_depth[mcell] = -(k + 1)
	_build_terrain()
	_build_decor(_decor_cells)
	await get_tree().create_timer(1.0).timeout
	_snap(save_path.replace(".png", "_kazi.png"))
	# Teshis karesi: kazi bolgesine tepeden yakin bakis
	camera.position = Vector3(float(kc.x) + 0.5, 10.0, float(kc.y) + 2.5)
	camera.rotation_degrees = Vector3(-78, 0, 0)
	await get_tree().create_timer(0.6).timeout
	_snap(save_path.replace(".png", "_kazi2.png"))
	# SU MODELI karesi (11.2): merdiven cukuruna 6 birim su - bilesik
	# kaplar geregi derin hucreler dolar, sig basamak kuru kalir
	_recompute_water()
	add_water(kc + Vector2i(0, -3), 6.0)
	await get_tree().create_timer(0.8).timeout
	_snap(save_path.replace(".png", "_su.png"))
	# Ayni havuz yandan/oyun acisina yakin bakisla (kopuk + yansima)
	camera.position = Vector3(float(kc.x) + 3.5, 4.0, float(kc.y) + 1.5)
	camera.look_at(Vector3(float(kc.x) + 0.5, -0.8, float(kc.y) - 1.5))
	await get_tree().create_timer(0.6).timeout
	_snap(save_path.replace(".png", "_su2.png"))
	# ALET SISTEMI (Bolum 12): sallanma yolunu calistir (crash yakala)
	_held_item = "kurek"
	player.set_held_tool("kurek")
	_perform_tool_action(_describe_target(kc + Vector2i(1, 0)))
	print("SWINGTEST: ok swinging=%s" % str(player.is_swinging()))
	await get_tree().create_timer(0.6).timeout
	_snap(save_path.replace(".png", "_alet_swing.png"))
	# TEST KUKLASI + yakin dovus (Asama 4): kukla kur, sopa ile vur
	var apc := _player_cell()
	var dcell := apc + Vector2i(1, 0)
	if not _dummies.has(dcell) and not _objects.has(dcell):
		_spawn_dummy(dcell)
	_held_item = "sopa"
	player.set_held_tool("sopa")
	player.facing = Vector2(1, 0)
	await get_tree().create_timer(0.2).timeout
	_on_attack_pressed()
	await get_tree().create_timer(0.5).timeout
	camera.position = _cell_center(dcell) + Vector3(-1.5, 2.0, 2.8)
	camera.look_at(_cell_center(dcell) + Vector3(0, 0.7, 0))
	await get_tree().create_timer(0.4).timeout
	_snap(save_path.replace(".png", "_dovus.png"))
	if _dummies.has(dcell):
		print("DUMMYTEST: hp=%d/%d" % [_dummies[dcell].hp, HittableDummy.MAX_HP])
	# MENZILLI (Asama 5): mizrak firlat, uzaktaki kuklaya carpsin
	var fcell := apc + Vector2i(4, 0)
	if not _dummies.has(fcell) and not _objects.has(fcell):
		_spawn_dummy(fcell)
	Inventory.add_item("mizrak", 1)
	_held_item = "mizrak"
	player.set_held_tool("mizrak")
	player.facing = Vector2(1, 0)
	_aim_charge = 1.0
	_launch_projectile("spear", Vector3(1, 0, 0), 11.0, 2.2, -12.0, 30,
			"mizrak", 1.0)
	print("RANGEDTEST: projectiles=%d" % _projectiles.size())
	await get_tree().create_timer(0.8).timeout
	_snap(save_path.replace(".png", "_menzil.png"))
	# YAPI YERLESTIRME (Asama 2/3): hayalet + onayla + hasar/yikim
	Inventory.reset()  # onceki testler envanteri doldurmus olabilir (yer ac)
	Inventory.add_item("ahsap_duvar", 3)
	player.facing = Vector2(0, 1)
	_on_hold_requested("")
	var ppc := _player_cell()
	var tcell := ppc + Vector2i(0, 1)
	# Hedef hucreyi garanti bos yap (CI'da _b3 yapilariyla dolu olmasin)
	_objects.erase(tcell); _dummies.erase(tcell); _depth.erase(tcell)
	_water_level.erase(tcell)
	if _placed.has(tcell):
		_remove_placed(tcell)
	_ground_char[tcell] = "."
	_solid_cells.erase(tcell)
	_enter_place_mode("ahsap_duvar")
	print("ENTERDBG: pm=%s ghost=%s ctrl=%s ppc=%s tcell=%s face=%s reason=%s" % [
		str(_place_mode), str(_ghost != null),
		str(hud._place_controls.visible), str(ppc), str(tcell),
		str(player.facing), str(_place_valid(tcell))])
	_cam_locked = true
	camera.position = _cell_center(ppc) + Vector3(0, 3.2, 4.0)
	camera.look_at(_cell_center(tcell) + Vector3(0, 0.4, 0))
	await get_tree().create_timer(0.5).timeout
	_snap(save_path.replace(".png", "_yapi_hayalet.png"))
	print("PLACEUI: controls=%s action=%s valid=%s pcell=%s" % [
		str(hud._place_controls.visible), str(hud.action_button.visible),
		str(_ghost_valid), str(_place_cell)])
	_place_confirm()
	await get_tree().create_timer(0.4).timeout
	_snap(save_path.replace(".png", "_yapi.png"))
	print("PLACETEST: placed=%d" % _placed.size())
	# Asama 3: duvara vur -> hasarli (egik) gorunum, sonra yikim
	if _placed.has(tcell):
		for i in 3:
			_structure_take_hit(tcell, 20, Vector3(0, 0, 1))  # 60/80 -> damaged
		await get_tree().create_timer(0.3).timeout
		_snap(save_path.replace(".png", "_yapi_hasar.png"))
		print("HASARTEST: hp_ratio=%.2f placed=%d" % [
			_structures.hp_ratio(tcell), _placed.size()])
		for i in 3:
			_structure_take_hit(tcell, 20, Vector3(0, 0, 1))  # yikim
		print("YIKIMTEST: placed=%d (duvar %s)" % [_placed.size(),
			"yikildi" if not _placed.has(tcell) else "duruyor"])
	_exit_place_mode()
	# Asama 4: mesale isigi + kapi ac/kapa
	var lcell := ppc + Vector2i(-1, 0)
	if not _placed.has(lcell) and not _objects.has(lcell):
		_ground_char[lcell] = "."; _solid_cells.erase(lcell)
		_set_placed(lcell, "mesale")
	var dcell2 := ppc + Vector2i(1, 0)
	_objects.erase(dcell2); _dummies.erase(dcell2)
	if _placed.has(dcell2):
		_remove_placed(dcell2)
	_ground_char[dcell2] = "."
	_set_placed(dcell2, "kapi")
	var closed_solid := _solid_cells.has(dcell2)
	_toggle_door(dcell2)
	print("DOORTEST: kapali_kati=%s acik_kati=%s" % [
		str(closed_solid), str(_solid_cells.has(dcell2))])
	DayNight.phase = "night"; DayNight.elapsed = 120.0
	DayNight.is_night = true
	DayNight.night_started.emit()
	camera.position = _cell_center(ppc) + Vector3(0, 3.0, 4.0)
	camera.look_at(_cell_center(ppc) + Vector3(0, 0.3, 0))
	await get_tree().create_timer(0.6).timeout
	_snap(save_path.replace(".png", "_yapi_isik.png"))
	# #1: YERE DUSEN ESYA gorseli (kategori renkli low-poly + suzulme/donme)
	Inventory.reset()
	DayNight.phase = "day"; DayNight.elapsed = 200.0
	DayNight.is_night = false
	DayNight.day_started.emit()
	var gpc := _player_cell()
	_add_ground_item(gpc + Vector2i(0, 1), "odun", 3)   # kutu, kahve
	_add_ground_item(gpc + Vector2i(1, 1), "tas", 2)    # kutu, gri
	_add_ground_item(gpc + Vector2i(-1, 1), "meyve", 1) # kure, kirmizi
	_scatter_drops(gpc + Vector2i(0, 2), {"kalas": 2, "altin": 1})  # saci
	_tick_ground_items(0.25)
	# En az 5 (bu blogun ekledigi); yikim/hasat sacilari fazladan ekleyebilir.
	print("GROUNDTEST: yer_esyasi=%d (min 5)" % _ground_items.size())
	var picked := _try_pickup_ground(gpc + Vector2i(0, 1))
	print("PICKTEST: topla=%s kalan=%d" % [str(picked), _ground_items.size()])
	_cam_locked = true
	camera.position = _cell_center(gpc) + Vector3(0, 2.8, 3.4)
	camera.look_at(_cell_center(gpc + Vector2i(0, 1)) + Vector3(0, 0.1, 0))
	await get_tree().create_timer(0.4).timeout
	_snap(save_path.replace(".png", "_yer_esya.png"))
	await _run_base_selftest(save_path)  # BASE (Bolum 14): sandik/yatak/ocak/platform
	await _run_survival_selftest(save_path)  # YASAM: can/aclik/yeme/pisirme/olum
	_run_time_selftest()  # gunduz/gece: faz + uyku kurali
	_run_muhendislik_selftest()  # MUHENDISLIK: merdiven tirmanma kurali
	_run_save_load_selftest()
	get_tree().quit()

## MUHENDISLIK self-test — Asama 1 merdiven (11.5): derin cukurdan (depth>=3)
## merdivensiz cikilamaz; sig cukur (1-2) serbest; merdiven konunca cikilir.
func _run_muhendislik_selftest() -> void:
	var deep := Vector2i(40, 40)
	var shallow := Vector2i(41, 40)
	var out := Vector2i(40, 41)
	_depth[deep] = 3
	_depth[shallow] = 1
	# depth 3 cukurdan cikis (out depth 0) merdivensiz KAPALI
	var no_ladder := can_step(deep, out)
	# sig cukur (depth 1) -> serbest
	var shallow_free := can_step(shallow, out)
	# merdiveni cukura koy -> cikis ACIK
	_placed[deep] = "merdiven"
	var with_ladder := can_step(deep, out)
	_placed.erase(deep)
	_depth.erase(deep); _depth.erase(shallow)
	print("LADDERTEST: derin_merdivensiz=%s sig_serbest=%s merdivenli=%s ok=%s" % [
		str(no_ladder), str(shallow_free), str(with_ladder),
		str(no_ladder == false and shallow_free == true and with_ladder == true)])
	# 11.9 kazik: kazikli cukura giren oyuncu bir kez hasar alir + hook.
	var spit := Vector2i(43, 40)
	_depth[spit] = 2
	_placed[spit] = "kazik"
	var hook_dmg := spike_damage(spit)
	Health.value = 100.0
	var saved_pos: Vector3 = player.position
	player.position = _cell_center(spit)
	_last_spike_cell = Vector2i(-999, -999)
	_tick_spike_hit()
	var after := Health.value
	player.position = saved_pos
	_placed.erase(spit); _depth.erase(spit)
	Health.value = 100.0; Health.changed.emit()
	print("SPIKETEST: hook_hasar=%d can100->%.0f hook_ok=%s hasar_ok=%s" % [
		hook_dmg, after, str(hook_dmg == EngBalance.SPIKE_FALL_DAMAGE),
		str(after < 100.0)])
	# 11.8 boru: DOWN transfer akar; UP (yukari) pompasiz akmaz (yukseklik).
	var down_ok := _pipe_scenario(1, 3)          # kaynak yuksek -> hedef alcak
	var up_blocked := not _pipe_scenario(3, 1)   # kaynak alcak -> hedef yuksek
	print("PIPETEST: down_akar=%s up_engel=%s ok=%s" % [
		str(down_ok), str(up_blocked), str(down_ok and up_blocked)])
	# 11.8 pompa: yukari akitir (yukseklik kuralini asar).
	var pump_up := _pipe_scenario(3, 1, true)
	# 11.8 vana: kapali durdurur, acik gecirir (down hatta).
	var valve_closed := not _pipe_scenario(1, 3, false, 0)
	var valve_open := _pipe_scenario(1, 3, false, 1)
	print("PUMPTEST: pompa_yukari=%s ok=%s" % [str(pump_up), str(pump_up)])
	print("VALVETEST: kapali_durur=%s acik_gecirir=%s ok=%s" % [
		str(valve_closed), str(valve_open), str(valve_closed and valve_open)])

## gunduz/gece self-test: faz/gün-oranı + uyku kuralı (ilk 3 gece).
func _run_time_selftest() -> void:
	DayNight.reset()
	DayNight.phase = "day"; DayNight.elapsed = 0.0; DayNight.is_night = false
	var frac_day := DayNight.day_fraction()
	DayNight.phase = "night"; DayNight.elapsed = 120.0; DayNight.is_night = true
	var frac_night := DayNight.day_fraction()
	print("TIMETEST: faz=%s frac_gunduz=%.2f frac_gece=%.2f gece_mi=%s" % [
		DayNight.phase, frac_day, frac_night, str(DayNight.is_night)])
	# Uyku kuralı: 2. gece uyunur -> gün 3; 5. gece uyunmaz
	DayNight.reset(); DayNight.day = 2
	DayNight.phase = "night"; DayNight.is_night = true
	var can2 := DayNight.day <= TimeBalance.SLEEP_MAX_NIGHT
	DayNight.sleep_to_morning()
	var slept_day := DayNight.day
	DayNight.day = 5; DayNight.phase = "night"; DayNight.is_night = true
	var can5 := DayNight.day <= TimeBalance.SLEEP_MAX_NIGHT
	print("SLEEPTEST: gece2_uyunur=%s uyudu->gun=%d gece5_uyunur=%s" % [
		str(can2), slept_day, str(can5)])
	# Kayıt/yükleme testine temiz, deterministik saat bırak
	DayNight.reset(); DayNight.day = 3
	DayNight.phase = "day"; DayNight.elapsed = 100.0; DayNight.is_night = false

## YASAM self-test: yeme doyma, açlık->can erimesi, ölüm+doğuş+envanter,
## pişirme istasyon kapısı. CI log'unda EAT/STARVE/DEATH/COOK satırları.
func _run_survival_selftest(save_path: String) -> void:
	# Yeme -> doyma uygulanir
	Inventory.reset()
	Hunger.value = 50.0
	var before := int(Hunger.value)
	PlayerStats.apply_food("meyve")  # +12
	print("EATTEST: aclik %d->%d edible(meyve=%s odun=%s)" % [
		before, int(Hunger.value), str(PlayerStats.is_edible("meyve")),
		str(PlayerStats.is_edible("odun"))])
	# Açlık 0 -> can erir
	Hunger.value = 0.0
	Health.value = 100.0
	for i in 20:
		PlayerStats._tick_health(0.1)
	print("STARVETEST: aclik0 can=%.1f (100'den dusmeli)" % Health.value)
	# Can 0 -> ölüm + doğuş; envanter KORUNUR
	Inventory.add_item("kalas", 5)
	var inv_before := Inventory.get_count("kalas")
	var dc := PlayerStats.death_count
	Health.value = 0.0
	PlayerStats._tick_health(0.1)
	print("DEATHTEST: sayac %d->%d can=%.0f aclik=%.0f envanter_korundu=%s" % [
		dc, PlayerStats.death_count, Health.value, Hunger.value,
		str(Inventory.get_count("kalas") == inv_before)])
	# Pişirme: ocak yakınlık kapısı
	Inventory.reset()
	Inventory.add_item("cig_et", 2)
	Crafting.near_hearth = false
	var n0 := Crafting.max_craftable("pismis_et")
	Crafting.near_hearth = true
	var n1 := Crafting.max_craftable("pismis_et")
	print("COOKTEST: ocaksiz=%d ocakli=%d" % [n0, n1])
	Crafting.near_hearth = false
	# Kare: düşük açlık/can (uyarı nabzı + vinyet görünsün)
	Hunger.value = 20.0; Hunger.changed.emit()
	Health.value = 22.0; Health.changed.emit()
	PlayerStats.hunger_warning.emit()
	await get_tree().create_timer(0.4).timeout
	_snap(save_path.replace(".png", "_yasam.png"))
	Hunger.value = 80.0; Health.value = 100.0  # sonraki testler icin toparla

## BASE (Bolum 14 A kismi) self-test: dort yapiyi kurar, davranislari dogrular
## ve _base.png karesini alir. CI log'unda CHEST/BED/HEARTH/PLATFORM satirlari.
func _run_base_selftest(save_path: String) -> void:
	Inventory.reset()
	DayNight.is_night = false
	var bpc := _player_cell()
	# Temiz calisma alani (yapilar/nesneler/su kaldir)
	for oy in range(-3, 4):
		for ox in range(-3, 4):
			var c := bpc + Vector2i(ox, oy)
			_objects.erase(c); _dummies.erase(c); _depth.erase(c)
			_water_level.erase(c); _solid_cells.erase(c)
			if _placed.has(c):
				_release_structure_cell(c)
			_ground_char[c] = "."
	# --- 14.1 SANDIK: doldur, dolu iken sokulmez, yikilinca sacilir ---
	var chest_cell := bpc + Vector2i(2, 0)
	_set_placed(chest_cell, "sandik")
	var store = _chests[chest_cell]
	store.add_item("odun", 10)
	store.add_item("tas", 5)
	print("CHESTTEST: dolu_slot=%d odun=%d bos=%s" % [
		store.get_used_slots(), store.get_count("odun"),
		str(_chest_is_empty(chest_cell))])
	_remove_placed(chest_cell)  # dolu -> reddedilmeli
	print("CHESTLOCK: dolu_sandik_duruyor=%s" % str(_placed.has(chest_cell)))
	var gi_before := _ground_items.size()
	_destroy_structure(chest_cell)  # yikim -> icerik yere sacilir
	print("CHESTSPILL: sacildi=%s (%d->%d)" % [
		str(_ground_items.size() > gi_before), gi_before, _ground_items.size()])
	# --- 14.2 YATAK: yerlestirince aktif dogus noktasi ---
	var bed_cell := bpc + Vector2i(-2, 0)
	_set_placed(bed_cell, "yatak")
	print("BEDTEST: home=%s eslesti=%s" % [
		str(get_spawn()), str(get_spawn() == bed_cell)])
	# --- 14.3 OCAK: tek aktif + oncelikli isik ---
	var hearth_cell := bpc + Vector2i(0, -2)
	_set_placed(hearth_cell, "ocak")
	print("HEARTHTEST: hearth=%s aktif_isik=%s" % [
		str(get_hearth()),
		str(_hearth_light != null and _hearth_light.visible)])
	# --- 14.4 PLATFORM: uzerine cik (yukseklik) + menzilli atis ---
	var plat_cell := bpc + Vector2i(0, 2)
	_set_placed(plat_cell, "platform")
	var base_y := ground_height(float(bpc.x) + 0.5, float(bpc.y) + 0.5)
	var plat_y := ground_height(float(plat_cell.x) + 0.5, float(plat_cell.y) + 0.5)
	print("PLATFORMTEST: yukseklik_farki=%.2f (beklenen ~1.5)" % (plat_y - base_y))
	player.position = _cell_center(plat_cell)
	player.facing = Vector2(1, 0)
	_launch_projectile("spear", Vector3(1, 0, 0), 11.0, 2.2, -12.0, 30, "mizrak", 1.0)
	print("PLATFORMSHOT: projectiles=%d oyuncu_y=%.2f" % [
		_projectiles.size(), player.position.y])
	# Kare: base'i genis acidan goster
	_cam_locked = true
	camera.position = _cell_center(bpc) + Vector3(5.0, 4.5, 6.0)
	camera.look_at(_cell_center(bpc) + Vector3(0, 0.5, 0))
	await get_tree().create_timer(0.5).timeout
	_snap(save_path.replace(".png", "_base.png"))

# kayit-sistemi Aşama 4: save -> bellegi boz -> load -> TEKRAR save; iki JSON
# anlamsal (sırasız) DERİN eşleşmeli. Eşleşmezse ilk farklı yol yazdırılır.
func _run_save_load_selftest() -> void:
	# 1) Zengin durum: kazi + yapi + dolu sandik + arastirma dugumu
	var pc := _player_cell()
	var tcell := pc + Vector2i(2, 0)
	if _diggable(tcell):
		_held_item = "tezgah"
		Inventory.add_item("tezgah", 1)
		_try_place(tcell)
	Research.unlocked["stone_tools"] = true   # arastirma kayit kapsaminda
	# 2) save1 (dosya icerigini oku)
	SaveManager.save()
	var json1 := FileAccess.get_file_as_string(SaveManager.SAVE3D_PATH)
	# 3) Bellegi boz (yukleme gercekten dosyadan mi?)
	_depth.clear(); _water_level.clear(); _placed.clear()
	for n in _placed_nodes.values():
		n.queue_free()
	_placed_nodes.clear(); _clear_chests(); _objects.clear()
	Inventory.load_save({}); Health.value = 1.0; Hunger.value = 1.0
	Research.unlocked.erase("stone_tools")
	# 4) Yukle
	SaveManager.load_game()
	# 5) TEKRAR save + derin karsilastir (sirasiz)
	SaveManager.save()
	var json2 := FileAccess.get_file_as_string(SaveManager.SAVE3D_PATH)
	var d1: Variant = JSON.parse_string(json1)
	var d2: Variant = JSON.parse_string(json2)
	var diff := _first_diff(d1, d2, "")
	print("SAVELOAD: %s bytes=%d research_ok=%s inv_odun=%d" % [
		"PASS" if diff == "" else "FAIL", json1.length(),
		str(Research.unlocked.has("stone_tools")), Inventory.get_count("odun")])
	if diff != "":
		print("SAVELOAD_MISMATCH: %s" % diff)

## İki JSON değerini sırasız (deep) karşılaştırır; ilk farklı yolu döndürür
## ("" = eşit). Sözlük anahtar sırası önemsiz.
func _first_diff(a: Variant, b: Variant, path: String) -> String:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return "%s: dict boyut %d!=%d" % [path, a.size(), b.size()]
		for k in a:
			if not b.has(k):
				return "%s.%s: eksik" % [path, str(k)]
			var sub := _first_diff(a[k], b[k], "%s.%s" % [path, str(k)])
			if sub != "":
				return sub
		return ""
	if a is Array and b is Array:
		if a.size() != b.size():
			return "%s: dizi boyut %d!=%d" % [path, a.size(), b.size()]
		for i in a.size():
			var sub := _first_diff(a[i], b[i], "%s[%d]" % [path, i])
			if sub != "":
				return sub
		return ""
	if typeof(a) == TYPE_FLOAT or typeof(b) == TYPE_FLOAT:
		if absf(float(a) - float(b)) > 0.0001:
			return "%s: %s != %s" % [path, str(a), str(b)]
		return ""
	if a != b:
		return "%s: %s != %s" % [path, str(a), str(b)]
	return ""

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
	if _place_mode:
		_update_ghost()  # 13.2: hayalet onizleme onde takip eder
	else:
		_update_targeting()  # 12.1/12.2: baglam ikonu + hedef vurgusu
	if not _projectiles.is_empty():
		_tick_projectiles(delta)
	if _aiming:
		_tick_aim(delta)
	if not _torch_lights.is_empty():
		_update_torches(delta)  # 13.5 isik butcesi + flicker
	if _hearth_light != null and is_instance_valid(_hearth_light) \
			and _hearth_light.visible:
		# 14.3 ocak: butcesiz, her zaman yanan; hafif canli titresim
		var ht := Time.get_ticks_msec() / 1000.0
		_hearth_light.light_energy = 3.0 * (0.9 + 0.1 * sin(ht * 8.0))
	_tick_regrow(delta)
	_update_daylight()  # gunduz/gece: güneş/gökyüzü/ambient eğrisi (yumuşak)
	# YASAM: kosma/alet eforu -> aclik daha hizli azalir (PlayerStats okur)
	PlayerStats.exerting = player.is_exerting()
	_tick_spike_hit()  # 11.9: kazikli cukura giren oyuncuya bir kez hasar
	_tick_water_network(delta)  # 11.8: boru agi mantiksal su transferi
	if not _ground_items.is_empty():
		_tick_ground_items(delta)  # #1: suzulme + donme
	_station_timer += delta
	if _station_timer >= 0.25:
		_station_timer = 0.0
		_update_station_proximity()
	# Eldeki esya envanterden ciktiysa birak
	if _held_item != "" and Inventory.get_count(_held_item) <= 0:
		_on_hold_requested("")
	# Otomatik kayit: her 2 dk'da bir (yalnizca degisiklik olduysa)
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		if _dirty:
			SaveManager.save()

# Uygulama arka plana alininca / kapatilinca son durumu kaydet.
# Android'de KRITIK: kullanici oyundan cikinca APPLICATION_PAUSED gelir
# (telefonlarda oyun boyle "kapanir"). Cikista da kaydeder.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _map_w > 0 and not OS.has_environment("RABLE_SCREENSHOT"):
			SaveManager.save()

func is_walkable(cell: Vector2i) -> bool:
	if cell.x < 1 or cell.y < 1 or cell.x >= _map_w - 1 or cell.y >= _map_h - 1:
		return false
	return not _solid_cells.has(cell)

## 11.5 MERDIVEN KURALI: from->to adimina izin var mi? Derin cukurdan
## (depth >= LADDER_DEEP_MIN) daha sig bir hucreye CIKMAK ancak merdiven
## erisimi varsa mumkun (1-2 serbest). player3d._try_move buraya danisir.
func can_step(from: Vector2i, to: Vector2i) -> bool:
	var df := int(_depth.get(from, 0))
	var dt := int(_depth.get(to, 0))
	if df >= EngBalance.LADDER_DEEP_MIN and dt < df:
		return _has_ladder_access(from)
	return true

func _is_ladder(cell: Vector2i) -> bool:
	return _placed.get(cell, "") == "merdiven"

## Merdiven bu hucrede mi (veya izinliyse 4-komsusunda mi)?
func _has_ladder_access(cell: Vector2i) -> bool:
	if _is_ladder(cell):
		return true
	if EngBalance.LADDER_ADJACENT_OK:
		for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(0, 1), Vector2i(0, -1)]:
			if _is_ladder(cell + n):
				return true
	return false

# --- 11.9 Cukur kazigi --------------------------------------------------
func _is_spikes(cell: Vector2i) -> bool:
	return _placed.get(cell, "") == "kazik"

## Yaratik kancasi (B kismi): bu hucredeki kazigin verdigi hasar. Yaratik
## sistemi dusen/hapsolan yaratiga bunu uygulayacak — davranis kodu YOK.
func spike_damage(cell: Vector2i) -> int:
	return EngBalance.SPIKE_FALL_DAMAGE if _is_spikes(cell) else 0

## Oyuncu kazikli hucreye girince BIR KEZ hasar; cikinca sifirlanir.
var _last_spike_cell := Vector2i(-999, -999)
func _tick_spike_hit() -> void:
	var pc := _player_cell()
	if _is_spikes(pc):
		if pc != _last_spike_cell:
			_last_spike_cell = pc
			Health.damage(float(EngBalance.SPIKE_FALL_DAMAGE))
			_spawn_floating_text(pc, "-%d" % EngBalance.SPIKE_FALL_DAMAGE,
					Color(1, 0.5, 0.4))
	else:
		_last_spike_cell = Vector2i(-999, -999)

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
		cam_distance = clampf(float(parsed.get("zoom", CAM_ZOOM_DEFAULT)),
				CAM_ZOOM_MIN, CAM_ZOOM_MAX)
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

# --- 3D dunya kalicilik (kazi/su/yapi/nesne + hayatta kalma) ---------------
# Vector2i anahtarli sozlukleri JSON'a "x,y" -> deger olarak yazar.

func _cells_to_json(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for cell: Vector2i in d:
		out["%d,%d" % [cell.x, cell.y]] = d[cell]
	return out

func _key_to_cell(key: String) -> Vector2i:
	var parts := key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

## kayit-sistemi: SAHNE durumunu (dünya) döndürür. Autoload'lar (envanter/
## can/gün...) SaveManager tarafından AYRI toplanır — burada YOK. Nesneler
## seed tabanına göre DIFF olarak yazılır (dosya küçük). SaveManager çağırır.
func to_save_data() -> Dictionary:
	if _map_w == 0:
		return {}
	var chest_json: Dictionary = {}
	for cell: Vector2i in _chests:
		# 14.1: depo Inventory ornegi -> slots/hotbar (to_save)
		chest_json["%d,%d" % [cell.x, cell.y]] = _chests[cell].to_save()
	var ground_json: Array = []
	for entry in _ground_items:
		ground_json.append({"x": entry["cell"].x, "y": entry["cell"].y,
				"id": entry["id"], "count": entry["count"]})
	var dummy_json: Array = []
	for cell: Vector2i in _dummies:
		dummy_json.append([cell.x, cell.y])
	# Nesne DIFF: taban(seed) ile fark. removed=tabanda vardı yok oldu (kesim);
	# changed=şimdi tabandan farklı (yeniden büyüme/kütük vb. + tabanda olmayan).
	var obj_removed: Array = []
	for cell: Vector2i in _base_objects:
		if not _objects.has(cell):
			obj_removed.append("%d,%d" % [cell.x, cell.y])
	var obj_changed: Dictionary = {}
	for cell: Vector2i in _objects:
		if String(_base_objects.get(cell, "")) != String(_objects[cell]):
			obj_changed["%d,%d" % [cell.x, cell.y]] = _objects[cell]
	_dirty = false
	return {
		"seed": _map_seed, "w": _map_w, "h": _map_h,
		"depth": _cells_to_json(_depth),
		"water": _cells_to_json(_water_level),
		"obj_removed": obj_removed,
		"obj_changed": obj_changed,
		"object_hits": _cells_to_json(_object_hits),
		"regrow": _cells_to_json(_regrow),
		"regrow_type": _cells_to_json(_regrow_type),
		"placed": _cells_to_json(_placed),
		"structures": _structures.to_save_data(),  # 13.6: yon/hp/durum
		"chests": chest_json,
		"ground_items": ground_json,
		"dummies": dummy_json,
		"player": [player.position.x, player.position.z],
		"held": _held_item,
		"home_bed": [_home_bed.x, _home_bed.y],  # 14.2 aktif dogus noktasi
	}

## kayit-sistemi: SAHNE durumunu (dünya) geri yükler. SaveManager çağırır;
## envanter/can/gün AYRI yüklenir (bu fonksiyon onlara dokunmaz — eldeki alet
## yeniden takılırken envanterin ZATEN yüklü olması gerekir, sıra SaveManager'da).
## Harita boyutu uyuşmazsa false (eski kayıt reddi). Nesneler: taban + DIFF.
func from_save_data(data: Dictionary) -> bool:
	if int(data.get("w", 0)) != _map_w or int(data.get("h", 0)) != _map_h:
		return false
	_loading = true
	# Kazi + su
	_depth.clear()
	for key in data.get("depth", {}):
		_depth[_key_to_cell(key)] = int(data["depth"][key])
	_water_level.clear()
	for key in data.get("water", {}):
		_water_level[_key_to_cell(key)] = float(data["water"][key])
	# Nesneler: seed tabanından başla, DIFF uygula (removed sil, changed yaz)
	_objects = _base_objects.duplicate()
	for key in data.get("obj_removed", []):
		_objects.erase(_key_to_cell(String(key)))
	for key in data.get("obj_changed", {}):
		_objects[_key_to_cell(key)] = String(data["obj_changed"][key])
	_object_hits.clear()
	for key in data.get("object_hits", {}):
		_object_hits[_key_to_cell(key)] = int(data["object_hits"][key])
	_regrow.clear()
	for key in data.get("regrow", {}):
		_regrow[_key_to_cell(key)] = float(data["regrow"][key])
	_regrow_type.clear()
	for key in data.get("regrow_type", {}):
		_regrow_type[_key_to_cell(key)] = String(data["regrow_type"][key])
	# Yerlestirilmis yapilar (dugumleri kur), sonra sandik icerikleri
	for cell in _placed_nodes.values():
		cell.queue_free()
	_placed.clear()
	_placed_nodes.clear()
	_clear_chests()          # 14.1 depo dugumlerini serbest birak
	_platform_cells.clear()  # 14.4 _set_placed yeniden dolduracak
	_hearth_cell = Vector2i(-999, -999)
	_hearth_light = null
	# 14.2 aktif dogus noktasi (yatak _loading iken set_spawn cagirmaz)
	var hb: Array = data.get("home_bed", [-999, -999])
	_home_bed = Vector2i(int(hb[0]), int(hb[1])) if hb.size() == 2 \
			else Vector2i(-999, -999)
	# 13.6: yapi metasini (yon/hp) once yukle ki _set_placed korusun; eski
	# kayitlarda "structures" yoksa _set_placed tam-can yeni ornek uretir
	_structures.from_save_data(data.get("structures", []))
	for key in data.get("placed", {}):
		var item_id := String(data["placed"][key])
		if PLACE_MODELS.has(item_id):
			_set_placed(_key_to_cell(key), item_id)  # sandik icin bos depo kurar
	# 14.1: sandik iceriklerini mevcut depolara yukle (yeni format=slots dict;
	# eski format=duz {esya:adet} -> load_from_dict ile geriye uyumlu)
	for key in data.get("chests", {}):
		var cell := _key_to_cell(key)
		if not _chests.has(cell):
			_chests[cell] = _new_chest_store()
		var saved = data["chests"][key]
		if saved is Dictionary and saved.has("slots"):
			_chests[cell].load_save(saved)
		elif saved is Dictionary:
			var flat: Dictionary = {}
			for item_id in saved:
				flat[item_id] = int(saved[item_id])
			_chests[cell].load_from_dict(flat)
	# Yerdeki esyalar: ONCE mevcut olanlari temizle (yukleme EKLEMEZ, YERINE
	# koyar; yoksa _add_ground_item ayni id'yi istifler -> reload'da adet katlanir)
	for entry in _ground_items:
		var gn: Variant = entry.get("node", null)
		if gn != null and is_instance_valid(gn):
			(gn as Node).queue_free()
	_ground_items.clear()
	for entry in data.get("ground_items", []):
		if entry is Dictionary and Items.ITEMS.has(entry.get("id", "")):
			_add_ground_item(Vector2i(int(entry["x"]), int(entry["y"])),
					String(entry["id"]), int(entry["count"]))
	# Test kuklalari (12.7)
	for cell in _dummies.values():
		if is_instance_valid(cell):
			cell.queue_free()
	_dummies.clear()
	for entry in data.get("dummies", []):
		if entry is Array and entry.size() == 2:
			_spawn_dummy(Vector2i(int(entry[0]), int(entry[1])))
	# Katilik ve gorseli sifirdan tut
	_recompute_solids()
	_build_terrain()
	_recompute_water()
	_build_decor(_decor_cells)
	_rebuild_objects()
	# Oyuncu konumu (envanter/can/gün SaveManager tarafından ZATEN yüklendi)
	var ppos = data.get("player", null)
	if ppos is Array and ppos.size() == 2:
		player.position = Vector3(float(ppos[0]),
				player.position.y, float(ppos[1]))
		camera.position = player.position + _camera_offset()
	# Eldeki alet gecerliyse tekrar tak (envanter yuklu olmali — sira dogru)
	var held := String(data.get("held", ""))
	if held != "" and Inventory.get_count(held) > 0:
		_on_hold_requested(held)
	_loading = false
	return true

# --- kayit-sistemi Aşama 3: Açılış "Devam Et / Yeni Oyun" ekranı -----------
## Kayıt varsa gösterilir. Dünya arkada zaten TAZE kuruldu; "Devam Et" kaydı
## yükler, "Yeni Oyun" onay sonrası eski kaydı siler (taze dünya kalır).
func _show_start_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.theme = load("res://theme_main.tres")
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(360, 0)
	layer.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "Kayıtlı oyun bulundu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vb.add_child(title)
	var cont := _pill_button("Devam Et")
	cont.pressed.connect(func():
		SaveManager.load_game()
		layer.queue_free())
	vb.add_child(cont)
	var neu := _pill_button("Yeni Oyun")
	neu.pressed.connect(func(): _confirm_new_game(vb, layer))
	vb.add_child(neu)

## Yeni Oyun onayı: eski kaydın üstüne yazmadan ÖNCE sorar (veri kaybı önlemi).
func _confirm_new_game(vb: VBoxContainer, layer: CanvasLayer) -> void:
	for c in vb.get_children():
		c.queue_free()
	var q := Label.new()
	q.text = "Eski kayıt silinecek. Emin misin?"
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.add_theme_font_size_override("font_size", 20)
	vb.add_child(q)
	var yes := _pill_button("Evet, yeni oyun")
	yes.pressed.connect(func():
		SaveManager.delete_save()
		Inventory.reset(); Research.reset(); Crafting.reset()
		Hunger.reset(); Thirst.reset(); Health.reset()
		PlayerStats.reset(); DayNight.reset()
		layer.queue_free())
	vb.add_child(yes)
	var no := _pill_button("Vazgeç")
	no.pressed.connect(func():
		layer.queue_free()
		_show_start_menu())
	vb.add_child(no)

func _pill_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(0, 48)
	return b

## _solid_cells'i sifirdan kurar: zemin (su/tepe) + kati nesneler + yapilar.
## Yukleme sonrasi ve durum bozulmasin diye tek kaynaktan turetilir.
func _recompute_solids() -> void:
	_solid_cells.clear()
	for cell: Vector2i in _ground_char:
		var g: String = _ground_char[cell]
		if GROUND_DEFS.has(g) and GROUND_DEFS[g].get("solid", false):
			_solid_cells[cell] = true
	for cell: Vector2i in _objects:
		# Cicek/mantar yurunebilir; agac/kaya/cali engeldir
		if not (String(_objects[cell]) in ["cicek", "mantar"]):
			_solid_cells[cell] = true
	for cell: Vector2i in _placed:
		var item_id: String = _placed[cell]
		if PLACE_MODELS.has(item_id) and PLACE_MODELS[item_id].get("solid", false):
			_solid_cells[cell] = true
	for cell: Vector2i in _dummies:
		_solid_cells[cell] = true  # kukla engeldir

# Iki parmakla yakinlastirma (pinch); oyuncu hareketi 1. parmakta kalir
func _unhandled_input(event: InputEvent) -> void:
	# ARASTIRMA TESTI (yalnizca klavyeli ortam: masaustu/web).
	# F9: durum dokumu; F10: stone_tools dugumunu bedava malzemeyle ac
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			Research.debug_print_state()
		elif event.keycode == KEY_F10:
			Research.debug_research("stone_tools")
		# YAPI YERLESTIRME klavye testi (13.2): R dondur, Esc iptal
		elif _place_mode and event.keycode == KEY_R:
			_place_rotate()
		elif _place_mode and event.keycode == KEY_ESCAPE:
			_exit_place_mode()
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
				cam_distance = clampf(cam_distance * (_pinch_last / dist),
						CAM_ZOOM_MIN, CAM_ZOOM_MAX)
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
	_zoom_slider.min_value = CAM_ZOOM_MIN
	_zoom_slider.max_value = CAM_ZOOM_MAX
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
	_env = env            # gunduz/gece: ambient + gokyuzu eğriyle degisir
	_sky_mat = sky_mat

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -32, 0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	# Golge haritasi kamera menziline daraltilir: uzak/yuksek agac
	# golgeleri dev bulanik leke olmasin (netlik dramatik artar)
	sun.directional_shadow_max_distance = 40.0
	sun.shadow_blur = 0.6
	add_child(sun)
	_sun = sun
	_update_daylight()    # ilk kareyi dogru tonla

	camera = Camera3D.new()
	camera.fov = 45.0
	add_child(camera)
	_apply_camera_angle()

# gunduz/gece Asama 2: faz sınırı renk/enerji anahtarları. Her faz KENDİ
# başından SONRAKİ fazın başına harmanlanır (phase_progress ile). Gece zifiri
# DEĞİL — okunur lavanta-lacivert (UI_DESIGN gece paleti).
# Alanlar: [gunes_renk, gunes_enerji, ambient_enerji, gok_ust, gok_ufuk]
const _SKY_KEYS := {
	"dawn":  [Color(0.62, 0.55, 0.72), 0.38, 0.36,
			Color(0.24, 0.26, 0.42), Color(0.72, 0.55, 0.52)],   # şafak (dim→)
	"day":   [Color(1.0, 0.90, 0.74), 1.0, 0.66,
			Color(0.48, 0.70, 0.95), Color(0.98, 0.90, 0.76)],   # sabah/gündüz
	"dusk":  [Color(1.0, 0.95, 0.85), 1.05, 0.72,
			Color(0.44, 0.69, 0.94), Color(0.95, 0.93, 0.82)],   # geç gündüz
	"night": [Color(0.52, 0.52, 0.78), 0.30, 0.32,
			Color(0.16, 0.18, 0.34), Color(0.40, 0.34, 0.52)],   # gece (lavanta)
}
const _PHASE_NEXT := {"dawn": "day", "day": "dusk", "dusk": "night", "night": "dawn"}

## Şu anki faz + ilerlemeye göre ışık/gökyüzü tonlarını yumuşakça geçirir.
func _update_daylight() -> void:
	if _sun == null:
		return
	var a: Array = _SKY_KEYS[DayNight.phase]
	var b: Array = _SKY_KEYS[_PHASE_NEXT[DayNight.phase]]
	var t: float = DayNight.phase_progress()
	_sun.light_color = (a[0] as Color).lerp(b[0], t)
	_sun.light_energy = lerpf(a[1], b[1], t)
	if _env != null:
		_env.ambient_light_energy = lerpf(a[2], b[2], t)
	if _sky_mat != null:
		_sky_mat.sky_top_color = (a[3] as Color).lerp(b[3], t)
		_sky_mat.sky_horizon_color = (a[4] as Color).lerp(b[4], t)
	# Güneş süpürmesi: gölgeler gün boyu kayar; gece açısı alçalır
	var frac := DayNight.day_fraction()
	_sun.rotation_degrees = Vector3(-50.0 + 24.0 * cos(frac * TAU),
			-32.0 + 70.0 * frac, 0.0)

# --- Dunya kurulumu -----------------------------------------------------

func _build_world() -> void:
	# harita-v2: taban harita noise ile üretilir (aynı seed = aynı harita).
	# Kayıt taban haritayı yazmaz; delta (kazı/nesne/yapı) yazar — bu yüzden
	# seed sabit ki reload'da taban aynı çıksın.
	var rows: Array[String] = MapGen.generate(_map_seed)
	_map_h = rows.size()
	_map_w = rows[0].length()
	_clay_cells.clear()

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
				"T":
					# AGAC SEYRELTME: 1 hucre = en fazla 1 agac; komsuda (8-yon)
					# zaten agac varsa bu hucre zemin kalir (min 1 bos hucre)
					if not _tree_neighbor(cell):
						_objects[cell] = ch
						_solid_cells[cell] = true
				"#", "m":
					_objects[cell] = ch
					_solid_cells[cell] = true
				"k":
					# Kil-işaretli kum (kürek kaynağı): zemin kum gibi kazılır,
					# görsel işaret + kazıda garanti kil (aşağıda).
					ground = "s"
					_clay_cells[cell] = true
				"o":
					# Eski ikili cukur: kazi modulunde depth=2 cukura donusur
					ground = "d"
					_depth[cell] = 2
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

	# kayit-sistemi: taban nesne anlik goruntusu (seed'den uretilen ilk durum).
	# Kayitta yalniz bundan FARKLI hucreler yazilir (dosya kucuk kalir).
	_base_objects = _objects.duplicate()

	_recompute_water()  # 11.2: haritadaki hazir cukurlar havuz olur (kuru)
	_build_terrain()
	_build_sea()
	_build_lake_surface()
	_build_sea_rocks()
	_build_decor(ground_cells["."] + ground_cells["h"])
	_rebuild_objects()
	_build_ground_markers()  # harita-v2: kil işaretleri + yüzey cevher ipuçları

## harita-v2: kil-işaretli kum hücrelerine kil-rengi yassı yama (kürek ipucu)
## + birkaç kaya öbeğinin yanına bakır-tonlu yüzey cevher ipucu. İkisi de
## MultiMesh (ucuz). Görsel; mekanik kazıda (kil garanti) _try_dig'te.
func _build_ground_markers() -> void:
	# --- Kil yamaları ---
	if not _clay_cells.is_empty():
		var disc := CylinderMesh.new()
		disc.top_radius = 0.34
		disc.bottom_radius = 0.34
		disc.height = 0.04
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = disc
		mm.instance_count = _clay_cells.size()
		var i := 0
		for cell: Vector2i in _clay_cells:
			mm.set_instance_transform(i,
					Transform3D(Basis(), _cell_center(cell) + Vector3(0, 0.03, 0)))
			i += 1
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color(0.58, 0.44, 0.30)
		cmat.roughness = 1.0
		inst.material_override = cmat
		add_child(inst)
	# --- Yüzey cevher ipuçları (birkaç kaya öbeği yanında) ---
	var rock_cells: Array = []
	for cell: Vector2i in _objects:
		if _objects[cell] == "#":
			rock_cells.append(cell)
	rock_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x * 100000 + a.y < b.x * 100000 + b.y)
	var hints: Array = []
	var want: int = MapBalance.ORE_HINT_CLUSTERS
	if not rock_cells.is_empty() and want > 0:
		var stride: int = maxi(1, rock_cells.size() / want)
		var idx := 0
		while idx < rock_cells.size() and hints.size() < want:
			var rc: Vector2i = rock_cells[idx]
			# Komşu yürünür hücreye ipucu koy
			for off: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
					Vector2i(0, -1)]:
				var hc := rc + off
				if is_walkable(hc) and not _objects.has(hc):
					hints.append(hc)
					break
			idx += stride
	if not hints.is_empty():
		var pebble := SphereMesh.new()
		pebble.radius = 0.16
		pebble.height = 0.24
		var mm2 := MultiMesh.new()
		mm2.transform_format = MultiMesh.TRANSFORM_3D
		mm2.mesh = pebble
		mm2.instance_count = hints.size()
		for j in hints.size():
			mm2.set_instance_transform(j,
					Transform3D(Basis(), _cell_center(hints[j]) + Vector3(0, 0.12, 0)))
		var inst2 := MultiMeshInstance3D.new()
		inst2.multimesh = mm2
		var omat := StandardMaterial3D.new()
		omat.albedo_color = Color(0.72, 0.45, 0.28)  # bakır tonu
		omat.metallic = 0.4
		omat.roughness = 0.6
		inst2.material_override = omat
		add_child(inst2)

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
	if ch == "h":
		return [1.1, def["color"]]
	# Duz alanlar hafif dalgali: dogal tepecik hissi (yumusak fonksiyon)
	var roll := sin(cx * 0.37) * cos(cy * 0.29) * 0.07 \
			+ sin(cx * 0.15 + cy * 0.42) * 0.05
	# KAZI (11.1/11.3): derinlik veriden dusulur, yigin veriden eklenir.
	# Kenar duvarlari harmanli arazi + falez boyamasindan kendiliginden
	# olusur; derin katman kaya rengine doner.
	var d: int = _depth.get(Vector2i(cx, cy), 0)
	if d != 0:
		var col: Color = def["color"]
		if d >= 3:
			col = Color(0.42, 0.39, 0.34)   # kaya katmani
		elif d > 0:
			col = Color(0.44, 0.31, 0.20)   # kazilmis toprak
		else:
			col = Color(0.47, 0.34, 0.22)   # toprak tumsegi
		return [roll - float(d) * DigRules.DEPTH_STEP, col]
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
	# KAZI OKUNABILIRLIGI: derinligi FARKLI hucreler arasinda gecis
	# keskinlesir (cukur/tumsek = low-poly blok duvarlar); dogal arazi
	# yumusak harmanini korur. Renk gecisi her yerde dar bantta.
	var sharp := false
	var dmin := 99
	var dmax := -99
	for dj in 2:
		for di in 2:
			var dd: int = _depth.get(Vector2i(i0 + di, j0 + dj), 0)
			dmin = mini(dmin, dd)
			dmax = maxi(dmax, dd)
	sharp = dmin != dmax
	# SERT ADIM (smoothstep degil): mesh koseleri 1/res araliklarla
	# ornekleniyor; smoothstep bandina denk gelen kose %50 karisik deger
	# alir ve GPU bunu iki quad boyunca dogrusal yayar = bulanik leke.
	# Sert adimda her kose ya A ya B degerini alir; gecis tek quad'a siner.
	var hfx := (0.0 if fx < 0.5 else 1.0) if sharp else fx
	var hfz := (0.0 if fz < 0.5 else 1.0) if sharp else fz
	var cfx := (0.0 if fx < 0.5 else 1.0) if sharp else smoothstep(0.2, 0.8, fx)
	var cfz := (0.0 if fz < 0.5 else 1.0) if sharp else smoothstep(0.2, 0.8, fz)
	for dj in 2:
		for di in 2:
			var wgt := (hfx if di == 1 else 1.0 - hfx) * (hfz if dj == 1 else 1.0 - hfz)
			var cwgt := (cfx if di == 1 else 1.0 - cfx) * (cfz if dj == 1 else 1.0 - cfz)
			var props := _cell_props(i0 + di, j0 + dj)
			height += float(props[0]) * wgt
			col += Color(props[1]) * cwgt
	return [height, col]

# Arazi 8x8 hucrelik PARCALAR halinde kurulur: kazi yalnizca ilgili
# parcalari yeniden uretir (tum haritayi degil - mobil performansi).
const CHUNK_CELLS := 16  # harita-v2: 16x16 hucre/parca (128x128'de 8x8=64 parca)
var _terrain_chunks: Dictionary = {}  # parca koordinati -> MeshInstance3D
var _terrain_material: StandardMaterial3D

func _build_terrain() -> void:
	for key in _terrain_chunks:
		_terrain_chunks[key].queue_free()
	_terrain_chunks.clear()
	for cj in ceili(float(_map_h) / CHUNK_CELLS):
		for ci in ceili(float(_map_w) / CHUNK_CELLS):
			_build_chunk(Vector2i(ci, cj))

func _terrain_mat() -> StandardMaterial3D:
	if _terrain_material == null:
		_terrain_material = StandardMaterial3D.new()
		_terrain_material.vertex_color_use_as_albedo = true
		_terrain_material.roughness = 1.0
		_terrain_material.albedo_texture = _make_neutral_speckle()
		# Dunya-uzayi doku: dik yamaclarda cizgi cizgi akmaz
		_terrain_material.uv1_triplanar = true
		_terrain_material.uv1_scale = Vector3(0.5, 0.5, 0.5)
	return _terrain_material

func _build_chunk(ck: Vector2i) -> void:
	if _terrain_chunks.has(ck):
		_terrain_chunks[ck].queue_free()
		_terrain_chunks.erase(ck)
	var x0 := ck.x * CHUNK_CELLS
	var y0 := ck.y * CHUNK_CELLS
	var x1 := mini(x0 + CHUNK_CELLS, _map_w)
	var y1 := mini(y0 + CHUNK_CELLS, _map_h)
	if x0 >= x1 or y0 >= y1:
		return
	var res := 4  # hucre basina 4x4 yama (0.25 m)
	# Kazi iceren (ya da 1 hucre komsulugunda kazi olan) parcalar iki kat
	# cozunurluk alir: blok duvar gecisi 1/8 hucreye siner, dik ve net durur.
	# Komsuluk payi sayesinde sinirdaki iki parca ayni cozunurlukte kalir
	# (farkli cozunurluk = kenar catlagi riski).
	for cj in range(y0 - 1, y1 + 1):
		for ci in range(x0 - 1, x1 + 1):
			if _depth.get(Vector2i(ci, cj), 0) != 0:
				res = 8
	var vw := (x1 - x0) * res
	var vh := (y1 - y0) * res
	var step := 1.0 / float(res)
	# Kose noktalari: yukseklik + renk. Diklik dunya orneklemesiyle
	# olculur ki parca sinirlarinda falez boyama tutarli kalsin.
	var pts: Array = []
	var cols: Array = []
	for j in vh + 1:
		var row_p := PackedVector3Array()
		var row_c: Array = []
		for i in vw + 1:
			var x := float(x0) + float(i) * step
			var z := float(y0) + float(j) * step
			var s := _sample_terrain(x, z)
			var height := float(s[0])
			var c: Color = s[1]
			var steep := maxf(
					absf(float(_sample_terrain(x + 0.5, z)[0]) - height),
					absf(float(_sample_terrain(x, z + 0.5)[0]) - height))
			steep = maxf(steep, absf(float(_sample_terrain(x - 0.5, z)[0]) - height))
			steep = maxf(steep, absf(float(_sample_terrain(x, z - 0.5)[0]) - height))
			# Kazilmis/yigilmis hucre VE komsulugunda falez boyamasi yok:
			# cukur duvari katman rengini korur, cevre cimde leke halkasi
			# olusmaz (okunabilirlik)
			var dug := false
			for ndy in range(-1, 2):
				for ndx in range(-1, 2):
					if _depth.get(Vector2i(floori(x) + ndx, floori(z) + ndy), 0) != 0:
						dug = true
			if dug:
				pass
			elif steep > 0.40:
				# Falez: net yatay katmanlar
				var layer := int(floorf((height + 8.0) * 5.0))
				var band := 0.30 if layer % 2 == 0 else 0.70
				band += sin(x * 3.6 + z * 2.8) * 0.10
				c = Color(0.33, 0.29, 0.24).lerp(
						Color(0.49, 0.43, 0.35), clampf(band, 0.0, 1.0))
			elif steep > 0.26:
				# Cim -> kaya arasi dar toprak kusagi
				c = c.lerp(Color(0.40, 0.34, 0.25), (steep - 0.26) / 0.14 * 0.85)
			# Organik his: deterministik minik renk oynamasi
			var n := sin(x * 51.9592 + z * 313.0) * 0.035
			row_p.append(Vector3(x, height, z))
			row_c.append(Color(c.r * (1.0 + n), c.g * (1.0 + n), c.b * (1.0 + n)))
		pts.append(row_p)
		cols.append(row_c)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in vh:
		for i in vw:
			for tri in [[Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i, j + 1)],
					[Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]]:
				for v: Vector2i in tri:
					st.set_color(cols[v.y][v.x])
					st.add_vertex(pts[v.y][v.x])
	st.generate_normals()
	var inst := MeshInstance3D.new()
	inst.mesh = st.commit()
	inst.material_override = _terrain_mat()
	add_child(inst)
	_terrain_chunks[ck] = inst

## Bir hucre degisince yalnizca etkilenen parcalari yeniden kurar
## (harman + diklik ornekleme yaricapi nedeniyle 2 hucre pay birakilir)
func _refresh_terrain_at(cell: Vector2i) -> void:
	var touched: Dictionary = {}
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var c := cell + Vector2i(dx, dy)
			if c.x < 0 or c.y < 0 or c.x >= _map_w or c.y >= _map_h:
				continue
			touched[Vector2i(floori(c.x / float(CHUNK_CELLS)),
					floori(c.y / float(CHUNK_CELLS)))] = true
	for ck in touched:
		_build_chunk(ck)
	_build_decor(_decor_cells)
	_rebuild_objects()

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
		if int(_depth.get(cell, 0)) != 0:
			continue  # kazilmis/yigilmis hucrede sus otu olmaz
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

## Bir dunya noktasindaki arazi yuksekligi (oyuncu ve nesneler icin).
## 14.4: platform hucresinde deck ust yuzu (arazi + PLATFORM_HEIGHT) doner —
## oyuncu platformun ustunde durur (menzilli atis yuksekten). Dusme hasari yok.
func ground_height(x: float, z: float) -> float:
	var base := float(_sample_terrain(x, z)[0])
	if not _platform_cells.is_empty():
		var cell := Vector2i(floori(x), floori(z))
		if _platform_cells.has(cell):
			return base + PLATFORM_HEIGHT
	return base

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
## Agac havuzu: TEK-AGAC cam modelleri (Kenney tree_pine*). Onceki
## quat2_tree02 bir GRUP mesh'iydi (4-5 cam tek mesh) -> her hucrede
## kume gorunuyordu; her biri tek agac olan cam varyantlariyla degistirildi.
const TREE_MODELS: Array[String] = ["tree_pineDefaultA", "tree_pineDefaultB",
	"tree_pineRoundA", "tree_pineTallA", "tree_pineRoundC"]

func _tree_pool() -> Array:
	var out: Array = []
	for m: String in TREE_MODELS:
		out += _model_pool(m, TREE_HEIGHT)
	return out

## Hucrenin 8-komsulugunda zaten agac (T) var mi? (spawn seyreltme)
func _tree_neighbor(cell: Vector2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			if _objects.get(cell + Vector2i(dx, dy), "") == "T":
				return true
	return false

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
	player.set_held_tool("")  # ToolPivot olussun (yumruk sallamasi icin)
	player.world_tapped.connect(_on_world_tapped)
	PlayerStats.world = self  # yasam: olum -> respawn_player cagrisi icin
	camera.position = player.position + _camera_offset()

func _player_cell() -> Vector2i:
	return Vector2i(floori(player.position.x), floori(player.position.z))

# --- gunduz/gece Asama 4: Uyku (BASE_SAVUNMA 14.2) --------------------------
## Yatak etkileşimi: gece "Uyu", gündüz "ev yap" (14.2 doğuş noktası).
func _use_bed(cell: Vector2i) -> void:
	if DayNight.is_night:
		_try_sleep(cell)
	else:
		# Gündüz uyumak yok (14.2 + gece görevi): yatak gündüz doğuş noktası atar.
		set_spawn(cell)

## Uyku kuralı: yalnız ilk SLEEP_MAX_NIGHT gece. Sonrası "Uyuyamazsın..."
## (gerekçe metni yaratıklarla netleşecek). Kararma → sabaha atla + hafif iyileş.
func _try_sleep(cell: Vector2i) -> void:
	if DayNight.day > TimeBalance.SLEEP_MAX_NIGHT:
		_spawn_floating_text(cell, "Uyuyamazsın...", Color(1, 0.9, 0.6))
		return
	var apply := func():
		DayNight.sleep_to_morning()
		Health.heal(TimeBalance.SLEEP_HEAL_HEALTH)
		Hunger.value = minf(Hunger.MAX_VALUE,
				Hunger.value + TimeBalance.SLEEP_HEAL_HUNGER)
		Hunger.changed.emit()
		_spawn_floating_text(_player_cell(), "Sabah oldu!", Color(0.8, 1.0, 0.85))
	if hud != null and hud.has_method("play_sleep_fade"):
		hud.play_sleep_fade(apply)  # kararma altında sabah uygulanır
	else:
		apply.call()

## YASAM (Asama 4): olumden sonra dogus. Ev yatagi (set_spawn) varsa orada,
## yoksa dunya baslangic hucresinde. PlayerStats can/aclik'i ayrica sifirlar.
## Kararma/cila Asama 5'te. Envanter KORUNUR (Balance.DROP_ITEMS_ON_DEATH).
func respawn_player() -> void:
	var cell := _respawn_cell()
	player.position = _cell_center(cell)
	camera.position = player.position + _camera_offset()
	_spawn_floating_text(cell, "Yeniden doğdun", Color(0.8, 1.0, 0.9))
	_dirty = true

# --- YASAM: yeme (Asama 2) ---------------------------------------------------
## ~1 sn'lik tuketme pozu (ALET_SISTEMI uc-faz cercevesi); eli agza goturur.
## Toplam sure ~SurvivalBalance.EAT_DURATION; ETKI strike aninda uygulanir.
const _CONSUME_PROFILE := {
	"windup": 0.30, "strike": 0.20, "recover": 0.50,
	"rest": Vector3(0, 0, 0), "wind": Vector3(-48, 0, 0),
	"hit": Vector3(-18, 0, 0), "push_z": 0.0,
}

func _on_eat_requested(food_id: String) -> void:
	_try_eat(food_id)

## Yiyecegi tuketir: ONCE 1 adet duser, ~1 sn eylem oynar (hareket yavaslar),
## bitince doyma uygulanir (+ cig et %20 bulanti). Zaten eylem varsa reddeder.
func _try_eat(food_id: String) -> bool:
	if not PlayerStats.is_edible(food_id) or Inventory.get_count(food_id) <= 0:
		return false
	if player.is_swinging():
		return false
	if not Inventory.remove_item(food_id, 1):
		return false
	var cell := _player_cell()
	var apply := func():
		PlayerStats.apply_food(food_id)
		_spawn_floating_text(cell, "+%d doyma" % int(PlayerStats.satiation_of(food_id)),
				Color(0.8, 1.0, 0.7))
		_spawn_particles(player.position + Vector3(0, 1.0, 0), Color(0.9, 0.85, 0.6), 4)
		_play_sfx("eat")
	var started: bool = player.play_swing(_CONSUME_PROFILE, apply)
	if not started:
		apply.call()  # eylem baslamadiysa etkiyi hemen uygula (item kaybolmasin)
	return true

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
	# Yerlestirme modunda dunya dokunuslari yok sayilir (Onayla butonu kurar)
	if _place_mode:
		return
	var cell := _screen_to_cell(screen_pos)
	var pc := _player_cell()
	var diff := (cell - pc).abs()
	if maxi(diff.x, diff.y) > 1:
		return
	if _ground_char.get(cell, "") == "~" and not _objects.has(cell):
		# Elde bos kova varsa icmek yerine doldur (11.2 -> 12.3 cercevesi)
		if _held_item == "kova":
			_perform_tool_action(_describe_target(cell))
			return
		Thirst.drink()
		_spawn_floating_text(cell, "Su içtin!", Color(0.6, 0.85, 1.0))
		return
	# Tasima modu: yerlestirilmis yapiyi geri al
	if _move_mode and _placed.has(cell):
		_remove_placed(cell)
		return
	# Yerlestirilmis yapiya dokunma etkilesimleri
	match _placed.get(cell, ""):
		"sandik":
			_open_chest_at(cell)
			return
		"arastirma_masasi":
			hud.research_button.button_pressed = true
			return
		"yatak":
			_use_bed(cell)
			return
		"vana":
			_toggle_valve(cell)
			return
	# Yere birakilmis esya varsa topla
	if _try_pickup_ground(cell):
		return
	# Elde yerlestirilebilir yapi: yere kur
	if PLACE_MODELS.has(_held_item) and _try_place(cell):
		return
	# Test kuklasi yerlestirme (12.7)
	if _held_item == "kukla" and _try_place_dummy(cell):
		return
	# ALET EYLEMLERI (12.3 cercevesi): kazi/yigma/su/hasat artik tek
	# noktadan (uc fazli sallanma) gecer; ETKI strike aninda uygulanir.
	# Kazi/kova davranisi AYNI, sadece animasyonla sarmalandi.
	var desc := _describe_target(cell)
	if desc["type"] != "none":
		_perform_tool_action(desc)
	else:
		# Bos hedefte alet varsa bosa sallama (whoosh); yoksa hasat dene
		if _held_item != "" and ToolProfiles.PROFILES.has(_held_item):
			_perform_tool_action(desc)
		else:
			_try_harvest(cell)

# --- Kazi modulu (KAZI_SU_MODULU.md 11.1 + 11.3 + 11.4) --------------------
# Kazi SADECE hucre verisini (_depth) degistirir; gorunum _cell_props
# uzerinden veriden turer. Su modeli (11.2) _water_level'i okuyacak.
# TODO(11.1-tirmanma): derin cukurdan cikamama/yavaslamaca cezasi
# yaratik tirmanma sistemiyle birlikte gelecek; simdilik oyuncu her
# derinlige girip cikabilir.

# Hucre kazilabilir/yigilabilir bir zemin mi? (nesnesiz cim/toprak/kum)
func _diggable(cell: Vector2i) -> bool:
	if cell == _player_cell() or cell == _spawn_cell:
		return false
	if _objects.has(cell) or _placed.has(cell):
		return false
	if cell.x < 1 or cell.y < 1 or cell.x >= _map_w - 1 or cell.y >= _map_h - 1:
		return false
	return _ground_char.get(cell, "") in [".", "d", "s"]

func _try_dig(cell: Vector2i) -> bool:
	if not _diggable(cell):
		return false
	var d: int = _depth.get(cell, 0)
	if d >= 4:
		_spawn_floating_text(cell, "Daha derin kazılamaz", Color(1, 0.9, 0.6))
		return true
	var is_rock: bool = d >= DigRules.ROCK_DEPTH
	if is_rock:
		# Kaya katmani: kazma gerekir (11.1)
		if not DigRules.PICKAXE_LIMITS.has(_held_item):
			_spawn_floating_text(cell, "Kaya katmanı — kazma gerek", Color(1, 0.9, 0.6))
			return true
		if d >= int(DigRules.PICKAXE_LIMITS[_held_item]):
			_spawn_floating_text(cell, "Daha derine demir kazma gerek", Color(1, 0.9, 0.6))
			return true
	else:
		# Toprak katmani: kurek gerekir
		if not DigRules.SHOVEL_LIMITS.has(_held_item):
			_spawn_floating_text(cell, "Toprak katmanı — kürek kullan", Color(1, 0.9, 0.6))
			return true
		if d >= int(DigRules.SHOVEL_LIMITS[_held_item]):
			_spawn_floating_text(cell, "Daha derine demir kürek gerek", Color(1, 0.9, 0.6))
			return true
	# Temel dusus: toprak katmani toprak, kaya katmani tas verir.
	# Ek dususler derinlige gore veri tablosundan (11.4).
	var new_depth := d + 1
	var drops: Dictionary = {"tas": 1} if is_rock else {"toprak": 1}
	var bonus := DigRules.roll_loot(new_depth)
	for item_id in bonus:
		drops[item_id] = int(drops.get(item_id, 0)) + int(bonus[item_id])
	# harita-v2: kil-işaretli hücre kazılınca garanti +1 kil (kürek kaynağı)
	if _clay_cells.has(cell):
		drops["kil"] = int(drops.get("kil", 0)) + 1
	if not Inventory.can_add_all(drops):
		_spawn_floating_text(cell, "Envanter dolu!", Color(1, 0.6, 0.6))
		return true
	_depth[cell] = new_depth
	_recompute_water()  # 11.2: komsu havuza baglandiysa su yayilir
	Inventory.add_all(drops)
	var gained: PackedStringArray = []
	var fly_from := camera.unproject_position(_cell_center(cell) + Vector3(0, 0.5, 0))
	for item_id in drops:
		gained.append("+%d %s" % [drops[item_id], Items.display_name(item_id)])
		if hud != null and hud.has_method("fly_pickup"):
			hud.fly_pickup(item_id, fly_from)
	_spawn_floating_text(cell, " ".join(gained), Color(0.9, 0.8, 0.6))
	# 12.6 his: toprak/tas partikulu (kazi rengine gore)
	_spawn_particles(_cell_center(cell) + Vector3(0, 0.3, 0),
			Color(0.5, 0.5, 0.55) if is_rock else Color(0.55, 0.40, 0.25), 6)
	_refresh_terrain_at(cell)
	_dirty = true
	return true

## Toprak yigma (11.3): cukuru doldurur ya da duz zemini yukseltir
func _try_pile(cell: Vector2i) -> bool:
	if not _diggable(cell):
		return false
	var d: int = _depth.get(cell, 0)
	if d <= -DigRules.MAX_RAISE:
		_spawn_floating_text(cell, "Daha fazla yükseltilemez", Color(1, 0.9, 0.6))
		return true
	if not Inventory.remove_item("toprak", 1):
		return false
	if d - 1 == 0:
		_depth.erase(cell)
	else:
		_depth[cell] = d - 1
	_recompute_water()  # 11.2: kapasite dustu; tasan su yok olur
	_spawn_floating_text(cell, "Toprak döküldü", Color(0.85, 0.95, 0.7))
	_refresh_terrain_at(cell)
	_dirty = true
	return true

# --- Su modeli (KAZI_SU_MODULU.md 11.2) ------------------------------------
# Havuzlar her arazi/su degisikliginde SIFIRDAN cozulur (kare basina
# maliyet yok). Mevcut su hucre bazinda korunur; kapasiteyi asan su
# yok olur (basit kural). Bolunme/birlesme flood-fill'den bedava cikar.

func _recompute_water() -> void:
	var pools := WaterSim.compute_pools(_depth)
	var new_levels: Dictionary = {}
	_pools = []
	for pool in pools:
		var vol := 0.0
		for c in pool["cells"]:
			vol += float(_water_level.get(c, 0.0))
		vol = minf(vol, float(pool["capacity"]))
		var surface := WaterSim.solve_surface(pool["cells"], _depth, vol)
		var dist := WaterSim.distribute(pool["cells"], _depth, surface)
		for c in dist:
			if float(dist[c]) > 0.0:
				new_levels[c] = dist[c]
		pool["volume"] = vol
		pool["surface"] = surface
		_pools.append(pool)
	_water_level = new_levels
	_update_water_visuals()

## Hucrenin bagli oldugu havuzun indeksi (-1: havuz yok).
## Boru sistemi (11.8) ayni kapiyi kullanacak.
func pool_at(cell: Vector2i) -> int:
	for i in _pools.size():
		if (_pools[i]["cells"] as Array).has(cell):
			return i
	return -1

## Gol hucresi: sonsuz su kaynagi (11.2 / 11.8 pompa girisi)
func is_water_source(cell: Vector2i) -> bool:
	return _ground_char.get(cell, "") == "~"

## Hucre "yuzulur" mu? Su sutunu derinligin en az yarisi (11.2 hazirlik).
# TODO(yaratik-11.6): yuzulur hucrede tirmanma yok + %70 yavaslamayi
# yaratiklar da kullanacak; simdilik tek davranis oyuncu yavaslamasi.
func is_swimmable(cell: Vector2i) -> bool:
	var d := int(_depth.get(cell, 0))
	if d < 1:
		return false
	return float(_water_level.get(cell, 0.0)) >= float(d) * WaterRules.SWIM_MIN_RATIO

## Komsu hucrede su var mi? (11.7 sulama tarimin kapisi)
func has_adjacent_water(cell: Vector2i) -> bool:
	for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c := cell + n
		if is_water_source(c) or float(_water_level.get(c, 0.0)) > 0.0:
			return true
	return false

## Su ekleme kapisi (kova doker, ileride boru basar).
## Kabul edilen miktari doner; havuz yoksa/doluysa 0.
func add_water(cell: Vector2i, amount: float) -> float:
	var pi := pool_at(cell)
	if pi < 0:
		return 0.0
	var pool: Dictionary = _pools[pi]
	var accepted := minf(amount, float(pool["capacity"]) - float(pool["volume"]))
	if accepted <= 0.0:
		return 0.0
	var target: Vector2i = pool["cells"][0]
	_water_level[target] = float(_water_level.get(target, 0.0)) + accepted
	_recompute_water()
	_dirty = true
	return accepted

## Su cekme kapisi (kova alir, ileride boru emer). Alinan miktari doner;
## gol hucresi sonsuz kaynak oldugundan isteneni her zaman verir.
func take_water(cell: Vector2i, amount: float) -> float:
	if is_water_source(cell):
		return amount
	var pi := pool_at(cell)
	if pi < 0:
		return 0.0
	var pool: Dictionary = _pools[pi]
	var taken := minf(amount, float(pool["volume"]))
	if taken <= 0.0:
		return 0.0
	var left := taken
	for c in pool["cells"]:
		if left <= 0.0:
			break
		var w := float(_water_level.get(c, 0.0))
		var cut := minf(w, left)
		if cut > 0.0:
			_water_level[c] = w - cut
			left -= cut
	_recompute_water()
	_dirty = true
	return taken

# --- Boru agi (11.8): mantiksal su transferi -------------------------------
# Su FIZIKSEL akmaz; bagli+aktif hatta NET_TICK_SECONDS'ta bir kaynaktan
# hedefe hacim tasinir (mevcut add_water/take_water kapilari). Yukseklik
# kurali: kaynak yuksekligi >= hedef; yukari tasima POMPA ister (Asama 4).
var _net_timer := 0.0

func _tick_water_network(delta: float) -> void:
	if not _has_any_pipe():
		return
	_net_timer += delta
	if _net_timer < EngBalance.NET_TICK_SECONDS:
		return
	var amount := EngBalance.PIPE_TRANSFER_PER_SEC * _net_timer
	_net_timer = 0.0
	for comp in _pipe_components():
		_transfer_in_component(comp, amount)

func _has_any_pipe() -> bool:
	for c in _placed:
		if _is_pipe_like(c):
			return true
	return false

## Bagli boru/pompa/vana hucrelerinin flood-fill bilesenleri.
func _pipe_components() -> Array:
	var seen: Dictionary = {}
	var comps: Array = []
	for c: Vector2i in _placed.keys():
		if not _is_pipe_like(c) or seen.has(c):
			continue
		var stack: Array = [c]
		seen[c] = true
		var cells: Array = []
		while not stack.is_empty():
			var x: Vector2i = stack.pop_back()
			cells.append(x)
			for n in _PIPE_DIRS:
				var nc: Vector2i = x + n
				if _is_pipe_like(nc) and not seen.has(nc):
					seen[nc] = true
					stack.append(nc)
		comps.append(cells)
	return comps

## Hucre "yuksekligi": su ancak asagi/ayni seviyeye akar (buyuk = yuksek).
func _cell_elevation(cell: Vector2i) -> float:
	if is_water_source(cell):
		return float(GROUND_DEFS["~"]["top"])
	return -float(int(_depth.get(cell, 0))) * DigRules.DEPTH_STEP

## Bir bilesende TEK transfer: en yuksek kaynaktan uygun (daha alcak/esit)
## hedefe. Bilesende POMPA varsa yukseklik kurali asilir (yukari akar); KAPALI
## VANA varsa hattan transfer durur.
func _transfer_in_component(cells: Array, amount: float) -> void:
	# 11.8 vana: bilesende kapali vana varsa transfer durur.
	for c: Vector2i in cells:
		if _placed.get(c, "") == "vana" and not _structures.is_open(c):
			return
	# 11.8 pompa: bilesende pompa varsa yukari akis serbest.
	var has_pump := false
	for c: Vector2i in cells:
		if _placed.get(c, "") == "pompa":
			has_pump = true
			break
	# En yuksek kaynagi bul (gol veya dolu havuz, bir boruya komsu).
	var src_cell := Vector2i(-999, -999)
	var src_elev := -999.0
	var src_pool := -3
	for pc: Vector2i in cells:
		for n in _PIPE_DIRS:
			var wc: Vector2i = pc + n
			if is_water_source(wc) or float(_water_level.get(wc, 0.0)) > 0.01:
				var e := _cell_elevation(wc)
				if e > src_elev:
					src_elev = e
					src_cell = wc
					src_pool = pool_at(wc)
	if src_cell.x == -999:
		return
	# Hedef: bilesene komsu, bos kapasiteli KAZILMIS havuz (kaynaktan farkli).
	for pc: Vector2i in cells:
		for n in _PIPE_DIRS:
			var tc: Vector2i = pc + n
			if int(_depth.get(tc, 0)) < 1:
				continue
			var tpool := pool_at(tc)
			if tpool < 0 or tpool == src_pool:
				continue
			if float(_pools[tpool]["volume"]) >= float(_pools[tpool]["capacity"]) - 0.001:
				continue
			if src_elev >= _cell_elevation(tc) or has_pump:
				var taken := take_water(src_cell, amount)
				if taken > 0.0:
					add_water(tc, taken)
				return  # bilesen basina tik'te tek transfer

## 11.8 Vana ac/kapa: dokununca cevrilir. El carki 45° doner (gorsel ipucu)
## + gicirti ses KANCASI (mevcut ses; ozel gicirti TODO). Kapali = transfer dur.
func _toggle_valve(cell: Vector2i) -> void:
	if _placed.get(cell, "") != "vana":
		return
	var now := not _structures.is_open(cell)
	_structures.set_open(cell, now)
	_refresh_pipe_visual(cell)
	_play_sfx("place")  # gicirti ses kancasi (ozel ses ileride)
	_spawn_floating_text(cell, "Vana açık" if now else "Vana kapalı",
			Color(0.85, 0.95, 0.7))
	_dirty = true

func _pool_volume_at(cell: Vector2i) -> float:
	var pi := pool_at(cell)
	return float(_pools[pi]["volume"]) if pi >= 0 else 0.0

## CI: kaynak(src_depth) havuzu doldur, hedef(tgt_depth) havuza boruyla bagla,
## bir transfer tik'i calistir; hedef su kazandi mi? (temizler)
func _pipe_scenario(src_depth: int, tgt_depth: int, with_pump: bool = false,
		valve_state: int = -1) -> bool:
	var a := Vector2i(30, 30)
	var b := Vector2i(30, 34)
	var mid := Vector2i(30, 32)
	var pipes := [Vector2i(30, 31), mid, Vector2i(30, 33)]
	_depth[a] = src_depth
	_depth[b] = tgt_depth
	for p: Vector2i in pipes:
		_placed[p] = "boru"
	if with_pump:
		_placed[mid] = "pompa"
	if valve_state >= 0:
		_placed[mid] = "vana"
		_structures.place(mid, "vana", 0, 40)
		_structures.set_open(mid, valve_state == 1)
	_water_level[a] = float(src_depth)
	_recompute_water()
	var before := _pool_volume_at(b)
	for comp in _pipe_components():
		_transfer_in_component(comp, 5.0)
	var after := _pool_volume_at(b)
	_depth.erase(a); _depth.erase(b)
	for p: Vector2i in pipes:
		_placed.erase(p)
	_placed.erase(mid)
	_structures.remove(mid)
	_water_level.erase(a); _water_level.erase(b)
	_recompute_water()
	return after > before + 0.01

# --- Su gorseli (11.2): havuz basina TEK duz yuzey --------------------------
# Golun sakin su shader'iyla AYNI dil (COLOR.r = yerel derinlik: sig/derin
# rengi + kiyi kopugu bedavaya gelir). Havuzlar kucuk oldugundan yuzey her
# degisimde yeniden kurulur; seviye 0.3 sn tween ile yumusak iner/kalkar.
var _pool_surface_nodes: Dictionary = {}  # havuz anahtari -> {node, tween}

func _update_water_visuals() -> void:
	var keep: Dictionary = {}
	for pool in _pools:
		var wet: Dictionary = {}
		for c in pool["cells"]:
			if float(_water_level.get(c, 0.0)) > 0.001:
				wet[c] = true
		if wet.is_empty():
			continue
		# Kararli kimlik: havuzun en kucuk hucresi (tween surekliligi icin
		# ayni havuz seviye degisiminde ayni dugumu kullanir)
		var key: Vector2i = pool["cells"][0]
		for c in pool["cells"]:
			if c.y < key.y or (c.y == key.y and c.x < key.x):
				key = c
		# Duz yuzey kotu: islak hucrelerin (taban + su sutunu) ortalamasi;
		# agiz hizasinda tasmasin diye 2 cm asagida durur
		var sum_y := 0.0
		for c in wet:
			sum_y += float(_cell_props(c.x, c.y)[0]) \
					+ float(_water_level[c]) * DigRules.DEPTH_STEP
		var surface_y := sum_y / float(wet.size()) - 0.02
		keep[key] = true
		var entry: Dictionary = _pool_surface_nodes.get(key, {})
		if entry.is_empty():
			var node := MeshInstance3D.new()
			node.material_override = _lake_material()
			node.position = Vector3(0, surface_y - 0.12, 0)  # dipten dogar
			add_child(node)
			entry = {"node": node, "tween": null}
			_pool_surface_nodes[key] = entry
		var inst: MeshInstance3D = entry["node"]
		inst.mesh = _build_pool_mesh(wet, surface_y)
		if entry["tween"] != null and (entry["tween"] as Tween).is_valid():
			(entry["tween"] as Tween).kill()
		var tw := create_tween()
		tw.tween_property(inst, "position:y", surface_y, 0.3) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		entry["tween"] = tw
	for key in _pool_surface_nodes.keys():
		if not keep.has(key):
			(_pool_surface_nodes[key]["node"] as MeshInstance3D).queue_free()
			_pool_surface_nodes.erase(key)

## Islak hucrelerin ustunu orten duz karolar (yerel y=0; dugum kotu tasir).
## Islak komsusu olmayan kenarlar duvarin icine hafif tasar ki kenar
## cizgisi/aralik gorunmesin.
func _build_pool_mesh(wet: Dictionary, surface_y: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var res := 4
	var step := 1.0 / float(res)
	for c: Vector2i in wet:
		for j in res:
			for i in res:
				var x0 := float(c.x) + float(i) * step
				var z0 := float(c.y) + float(j) * step
				var x1 := x0 + step
				var z1 := z0 + step
				if i == 0 and not wet.has(c + Vector2i(-1, 0)):
					x0 -= 0.03
				if i == res - 1 and not wet.has(c + Vector2i(1, 0)):
					x1 += 0.03
				if j == 0 and not wet.has(c + Vector2i(0, -1)):
					z0 -= 0.03
				if j == res - 1 and not wet.has(c + Vector2i(0, 1)):
					z1 += 0.03
				for tri in [[Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1)],
						[Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]]:
					for p: Vector2 in tri:
						st.set_normal(Vector3.UP)
						var d := clampf((surface_y
								- float(_sample_terrain(p.x, p.y)[0])) / 0.22, 0.0, 1.0)
						st.set_color(Color(d, 0, 0))
						st.add_vertex(Vector3(p.x, 0.0, p.y))
	return st.commit()

# --- Kova etkilesimleri (11.2) ---------------------------------------------

## Eldeki esyayi baskasiyla degistirir (kova <-> dolu kova)
func _swap_held(from_id: String, to_id: String) -> bool:
	if not Inventory.remove_item(from_id, 1):
		return false
	Inventory.add_all({to_id: 1})
	_on_hold_requested(to_id)
	return true

## Bos kova ile su al: gol (sonsuz) ya da yeterli sulu havuz
func _try_scoop(cell: Vector2i) -> bool:
	var source := is_water_source(cell)
	var pi := pool_at(cell)
	if not source and pi < 0:
		return false
	if not source and float(_pools[pi]["volume"]) < WaterRules.BUCKET_UNITS:
		_spawn_floating_text(cell, "Yeterli su yok", Color(1, 0.9, 0.6))
		return true
	take_water(cell, WaterRules.BUCKET_UNITS)
	if _swap_held("kova", "kova_dolu"):
		_spawn_floating_text(cell, "Kova doldu", Color(0.6, 0.85, 1.0))
	return true

## Dolu kova ile su dok: yalnizca kazilmis cukura (depth >= 1)
func _try_pour(cell: Vector2i) -> bool:
	if int(_depth.get(cell, 0)) < 1:
		if _diggable(cell):
			_spawn_floating_text(cell, "Su tutacak bir çukur gerek", Color(1, 0.9, 0.6))
			return true
		return false
	if add_water(cell, WaterRules.BUCKET_UNITS) <= 0.0:
		_spawn_floating_text(cell, "Çukur ağzına kadar dolu", Color(1, 0.9, 0.6))
		return true
	if _swap_held("kova_dolu", "kova"):
		_spawn_floating_text(cell, "Su döküldü", Color(0.6, 0.85, 1.0))
	return true

# --- Yapi yerlestirme (B3) ------------------------------------------------

func _try_place(cell: Vector2i) -> bool:
	if _placed.has(cell) or _objects.has(cell) or cell == _player_cell():
		return false
	if cell.x < 1 or cell.y < 1 or cell.x >= _map_w - 1 or cell.y >= _map_h - 1:
		return false
	if not (_ground_char.get(cell, "") in [".", "d", "s"]):
		return false
	if not Inventory.remove_item(_held_item, 1):
		return false
	_set_placed(cell, _held_item)
	_spawn_floating_text(cell, Items.display_name(_placed[cell]) + " kuruldu",
			Color(0.8, 1.0, 0.8))
	_dirty = true
	return true

func _set_placed(cell: Vector2i, item_id: String, rot: int = 0) -> void:
	_placed[cell] = item_id
	var def: Dictionary = PLACE_MODELS[item_id]
	if def["solid"]:
		_solid_cells[cell] = true
	# 13.1: ornek metasini kaydet (yon/hp/durum). Zaten kayitliysa (yukleme)
	# korunur; degilse tam can ile yeni ornek olustur.
	if not _structures.has(cell):
		_structures.place(cell, item_id, rot, int(def.get("max_hp", 100)))
	var holder := _build_structure_visual(item_id)
	holder.position = _cell_center(cell)
	holder.rotation_degrees.y = float(_structures.rotation_of(cell))
	add_child(holder)
	_placed_nodes[cell] = holder
	# Kayittan gelen hasarli yapi egik gorunsun (13.4)
	if _structures.hp_ratio(cell) < 0.5:
		_apply_damaged_look(cell)
	if item_id == "sandik" and not _chests.has(cell):
		_chests[cell] = _new_chest_store()  # 14.1 bos 16-slot depo
	# 13.5 + 14.x ozel davranislar
	var behavior := String(def.get("behavior", ""))
	if behavior == "door":
		var is_open: bool = _structures.is_open(cell)
		if is_open:
			_solid_cells.erase(cell)
			holder.rotation_degrees.y = float(_structures.rotation_of(cell)) + 90.0
		else:
			_solid_cells[cell] = true  # kapali kapi katidir
	elif behavior == "torch":
		_add_torch_light(cell, holder)
	elif behavior == "hearth":
		_activate_hearth(cell, holder)   # 14.3 tek aktif ocak + oncelikli isik
	elif behavior == "platform":
		_platform_cells[cell] = true     # 14.4 uzerine cikilir (yukseklik)
	elif behavior == "bed" and not _loading:
		set_spawn(cell)                  # 14.2 son yatak = aktif dogus noktasi
	elif behavior in ["pipe", "pump", "valve"]:
		# 11.8: komsu borularla otomatik baglan (kendi + komsu gorselleri).
		# Vana varsayilan durumu place()'te open=false (= VALVE_DEFAULT_OPEN);
		# kayittan gelen durum korunur (_structures.has ile place atlanir).
		_refresh_pipe_neighborhood(cell)

## Bir yapinin olcekli 3D gorselini (holder+bundle) origin'de kurar; konum/
## donme cagirana kalir. Hem yerlestirme hem hayalet onizleme kullanir.
func _build_structure_visual(item_id: String) -> Node3D:
	var def: Dictionary = PLACE_MODELS[item_id]
	# 14.4 platform: GLB yok, prosedurel (deck 1.5 birim + ayaklar + basamak).
	# ground_height ile eslesir; oyuncu deck ustunde durur.
	if item_id == "platform":
		return _build_platform_visual()
	if item_id == "merdiven":
		return _build_ladder_visual()
	if item_id == "kazik":
		return _build_spikes_visual()
	if item_id == "boru":
		return _build_pipe_visual(15)  # hayalet: tam hac (gercek maske yerlesince)
	if item_id == "pompa":
		return _build_pump_visual(15)
	if item_id == "vana":
		return _build_valve_visual(15, false)
	var holder := Node3D.new()
	var bundle := Node3D.new()
	holder.add_child(bundle)
	bundle.add_child(load(def["model"]).instantiate())
	if def.has("extra"):
		bundle.add_child(load(def["extra"]).instantiate())
	var aabb := _scene_aabb(bundle)
	var by_long: bool = def.has("long")
	var basis_size: float = aabb.get_longest_axis_size() if by_long else aabb.size.y
	var target: float = def["long"] if by_long else def["h"]
	if basis_size > 0.01:
		var s: float = target / basis_size
		bundle.scale = Vector3.ONE * s
		bundle.position = Vector3(-aabb.get_center().x * s, -aabb.position.y * s,
				-aabb.get_center().z * s)
	return holder

## 14.4 Savunma platformu: ~1.5 birim yuksek, uzerine cikilir deck + 4 ayak +
## bir kenarda basamak (holder donunce basamak yonu secilir). Prosedurel;
## boyut ground_height ile eslesir (deck ust yuzu local y=1.5).
const PLATFORM_HEIGHT := 1.5
func _build_platform_visual() -> Node3D:
	var holder := Node3D.new()
	var wood := Color(0.58, 0.40, 0.24)
	var wood_d := Color(0.44, 0.30, 0.18)
	var top := PLATFORM_HEIGHT
	# Deck (ust dosseme)
	var deck := MeshInstance3D.new()
	var dm := BoxMesh.new(); dm.size = Vector3(0.92, 0.16, 0.92)
	deck.mesh = dm
	deck.position = Vector3(0, top - 0.08, 0)
	deck.material_override = _flat_mat(wood)
	holder.add_child(deck)
	# 4 ayak
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var leg := MeshInstance3D.new()
			var lm := BoxMesh.new(); lm.size = Vector3(0.12, top - 0.16, 0.12)
			leg.mesh = lm
			leg.position = Vector3(sx * 0.36, (top - 0.16) * 0.5, sz * 0.36)
			leg.material_override = _flat_mat(wood_d)
			holder.add_child(leg)
	# Basamaklar: +z kenarinda 3 kademe (holder rotasyonu yonu belirler)
	for i in 3:
		var step := MeshInstance3D.new()
		var sm := BoxMesh.new(); sm.size = Vector3(0.7, 0.16, 0.26)
		step.mesh = sm
		var h := top - (i + 1) * (top / 4.0)
		step.position = Vector3(0, h - 0.08, 0.5 + i * 0.24)
		step.material_override = _flat_mat(wood if i % 2 == 0 else wood_d)
		holder.add_child(step)
	return holder

## 11.5 Merdiven: cukur tabanindan yukselen iki ray + basamaklar (prosedurel).
## +z kenara yaslanir; holder rotasyonu hangi kenar oldugunu secer.
func _build_ladder_visual() -> Node3D:
	var holder := Node3D.new()
	var wood := Color(0.60, 0.42, 0.24)
	var woodd := Color(0.45, 0.31, 0.18)
	var top := 1.3
	var zedge := 0.36
	for sx in [-1, 1]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new(); rm.size = Vector3(0.08, top, 0.08)
		rail.mesh = rm
		rail.position = Vector3(sx * 0.18, top * 0.5, zedge)
		rail.material_override = _flat_mat(wood)
		holder.add_child(rail)
	var y := 0.16
	while y < top:
		var rung := MeshInstance3D.new()
		var gm := BoxMesh.new(); gm.size = Vector3(0.44, 0.06, 0.06)
		rung.mesh = gm
		rung.position = Vector3(0, y, zedge)
		rung.material_override = _flat_mat(woodd)
		holder.add_child(rung)
		y += 0.22
	return holder

## 11.9 Cukur kazigi: cukur tabanindan yukselen sivri koniler (prosedurel).
func _build_spikes_visual() -> Node3D:
	var holder := Node3D.new()
	var steel := Color(0.55, 0.57, 0.62)
	var h: float = EngBalance.SPIKE_VISUAL_HEIGHT
	for sx in [-0.25, 0.05, 0.28]:
		for sz in [-0.22, 0.18]:
			var spike := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 0.08
			cm.height = h
			cm.radial_segments = 5
			spike.mesh = cm
			spike.position = Vector3(sx, h * 0.5, sz)
			spike.material_override = _flat_mat(steel)
			holder.add_child(spike)
	return holder

## 11.8 Boru gorseli: merkez kup + acik yonlere kollar (maskeden turer;
## duz/dirsek/T/hac otomatik cikar). bit: 1=+x 2=-x 4=+z 8=-z.
const _PIPE_DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const _PIPE_BITS := [1, 2, 4, 8]

func _build_pipe_visual(mask: int) -> Node3D:
	var holder := Node3D.new()
	var col := Color(0.47, 0.59, 0.69)
	var y := 0.17
	var hub := MeshInstance3D.new()
	var hm := BoxMesh.new(); hm.size = Vector3(0.22, 0.22, 0.22)
	hub.mesh = hm; hub.position = Vector3(0, y, 0)
	hub.material_override = _flat_mat(col)
	holder.add_child(hub)
	var arms := [
		[1, Vector3(0.31, y, 0), Vector3(0.4, 0.15, 0.15)],
		[2, Vector3(-0.31, y, 0), Vector3(0.4, 0.15, 0.15)],
		[4, Vector3(0, y, 0.31), Vector3(0.15, 0.15, 0.4)],
		[8, Vector3(0, y, -0.31), Vector3(0.15, 0.15, 0.4)]]
	for a in arms:
		if mask & int(a[0]):
			var arm := MeshInstance3D.new()
			var am := BoxMesh.new(); am.size = a[2]
			arm.mesh = am; arm.position = a[1]
			arm.material_override = _flat_mat(col)
			holder.add_child(arm)
	return holder

## Boru agi elemani mi? (boru/pompa/vana — hepsi hatta baglanir)
func _is_pipe_like(cell: Vector2i) -> bool:
	return _placed.get(cell, "") in ["boru", "pompa", "vana"]

func _pipe_mask(cell: Vector2i) -> int:
	var m := 0
	for i in 4:
		if _is_pipe_like(cell + _PIPE_DIRS[i]):
			m |= _PIPE_BITS[i]
	return m

## Boru/pompa/vana gorselini komsuluk maskesine gore YENIDEN kurar.
func _refresh_pipe_visual(cell: Vector2i) -> void:
	if not _is_pipe_like(cell):
		return
	var old: Node3D = _placed_nodes.get(cell, null)
	if old != null and is_instance_valid(old):
		old.queue_free()
	var id: String = _placed[cell]
	var node: Node3D
	if id == "pompa":
		node = _build_pump_visual(_pipe_mask(cell))
	elif id == "vana":
		node = _build_valve_visual(_pipe_mask(cell), _structures.is_open(cell))
	else:
		node = _build_pipe_visual(_pipe_mask(cell))
	node.position = _cell_center(cell)
	add_child(node)
	_placed_nodes[cell] = node

func _refresh_pipe_neighborhood(cell: Vector2i) -> void:
	_refresh_pipe_visual(cell)
	for n in _PIPE_DIRS:
		_refresh_pipe_visual(cell + n)

## 11.8 Pompa gorseli: boru maskesi + turkuaz govde + kol.
func _build_pump_visual(mask: int) -> Node3D:
	var holder := _build_pipe_visual(mask)
	var teal := Color(0.35, 0.72, 0.72)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.3, 0.4, 0.3)
	body.mesh = bm; body.position = Vector3(0, 0.44, 0)
	body.material_override = _flat_mat(teal)
	holder.add_child(body)
	var lever := MeshInstance3D.new()
	var lm := BoxMesh.new(); lm.size = Vector3(0.36, 0.06, 0.06)
	lever.mesh = lm; lever.position = Vector3(0, 0.66, 0)
	lever.material_override = _flat_mat(Color(0.28, 0.5, 0.5))
	holder.add_child(lever)
	return holder

## 11.8 Vana gorseli: boru maskesi + kirmizi el carki (acikken 45° cevrik).
func _build_valve_visual(mask: int, open: bool) -> Node3D:
	var holder := _build_pipe_visual(mask)
	var red := Color(0.82, 0.35, 0.30)
	var stem := MeshInstance3D.new()
	var stm := BoxMesh.new(); stm.size = Vector3(0.06, 0.22, 0.06)
	stem.mesh = stm; stem.position = Vector3(0, 0.28, 0)
	stem.material_override = _flat_mat(Color(0.5, 0.5, 0.55))
	holder.add_child(stem)
	var wheel := Node3D.new()
	wheel.name = "ValveWheel"
	wheel.position = Vector3(0, 0.4, 0)
	for i in 4:
		var seg := MeshInstance3D.new()
		var sm := BoxMesh.new(); sm.size = Vector3(0.3, 0.05, 0.05)
		seg.mesh = sm
		seg.rotation.y = TAU * float(i) / 4.0
		seg.material_override = _flat_mat(red)
		wheel.add_child(seg)
	wheel.rotation.y = deg_to_rad(45.0) if open else 0.0
	holder.add_child(wheel)
	return holder

func _flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m

func _remove_placed(cell: Vector2i) -> void:
	var item_id: String = _placed[cell]
	# 14.1: dolu sandik sokulmez (item kaybi/duplikasyon riskini sifirla)
	if item_id == "sandik" and not _chest_is_empty(cell):
		_spawn_floating_text(cell, "Önce sandığı boşalt!", Color(1, 0.6, 0.6))
		return
	if not Inventory.can_add_all({item_id: 1}):
		_spawn_floating_text(cell, "Envanter dolu!", Color(1, 0.6, 0.6))
		return
	Inventory.add_item(item_id, 1)
	_release_structure_cell(cell)
	_spawn_floating_text(cell, "Geri alındı", Color(0.95, 0.9, 0.7))
	_dirty = true

## Bir yapi hucresinin TUM kayitlarini temizler (sokme + yikim ortak yol).
## Sandik deposu/ocak isigi/platform yuksekligi burada birakilir.
func _release_structure_cell(cell: Vector2i) -> void:
	_placed.erase(cell)
	_structures.remove(cell)
	_torch_lights.erase(cell)
	_solid_cells.erase(cell)
	_platform_cells.erase(cell)
	if _chests.has(cell):
		var store = _chests[cell]
		if store != null and is_instance_valid(store):
			store.queue_free()
		_chests.erase(cell)
	if cell == _hearth_cell:
		_hearth_cell = Vector2i(-999, -999)
		_hearth_light = null  # dugumle birlikte free edilir (holder cocugu)
	if _placed_nodes.has(cell):
		_placed_nodes[cell].queue_free()
		_placed_nodes.erase(cell)
	# 11.8: boru agindan cikan hucre -> komsu boru gorsellerini tazele.
	for n in _PIPE_DIRS:
		_refresh_pipe_visual(cell + n)

# --- YAPI YERLESTIRME MODU (YAPI_SISTEMI.md 13.2 + 13.3) -------------------
const _PLACE_OK := Color(0.42, 0.80, 0.42)
const _PLACE_BAD := Color(0.88, 0.36, 0.32)

func _enter_place_mode(item_id: String) -> void:
	if not PLACE_MODELS.has(item_id) or Inventory.get_count(item_id) <= 0:
		return
	_exit_place_mode()  # varsa oncekini kapat
	_place_mode = true
	_place_item = item_id
	_place_rot = 0
	_build_ghost()
	if _target_ring != null:
		_target_ring.visible = false
	hud.set_place_mode(true)

func _exit_place_mode() -> void:
	_place_mode = false
	_place_item = ""
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	hud.set_place_mode(false)

func _build_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
	_ghost = _build_structure_visual(_place_item)
	_ghost_needs_tint = true
	# Neden rozeti (13.3): gecersizken hayaletin ustunde kisa etiket
	var label := Label3D.new()
	label.name = "GhostReason"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 32
	label.outline_size = 8
	label.position = Vector3(0, 1.2, 0)
	label.modulate = _PLACE_BAD
	_ghost.add_child(label)
	add_child(_ghost)

## Hayaleti onde takip ettirir + gecerlilik rengini/rozetini gunceller.
func _update_ghost() -> void:
	if _ghost == null:
		return
	var cell := _facing_cell()
	_place_cell = cell
	_ghost.position = _cell_center(cell)
	_ghost.rotation_degrees.y = float(_place_rot)
	var v := _place_valid(cell)
	var nv := bool(v["valid"])
	# Boyamayi yalnizca gecerlilik degisince yenile (kare basi materyal
	# ayirmaktan kacin — mobil)
	if nv != _ghost_valid or _ghost_needs_tint:
		_ghost_valid = nv
		_ghost_needs_tint = false
		_tint_node(_ghost, _PLACE_OK if nv else _PLACE_BAD, 0.55)
	var label := _ghost.get_node_or_null("GhostReason")
	if label != null:
		label.text = "" if nv else String(v["reason"])

## Hucre yerlestirme icin gecerli mi? {valid, reason} (13.3 kurallari)
func _place_valid(cell: Vector2i) -> Dictionary:
	var def: Dictionary = PLACE_MODELS[_place_item]
	if cell.x < 1 or cell.y < 1 or cell.x >= _map_w - 1 or cell.y >= _map_h - 1:
		return {"valid": false, "reason": "sınır"}
	if _placed.has(cell) or _objects.has(cell) or _dummies.has(cell):
		return {"valid": false, "reason": "dolu"}
	if cell == _player_cell():
		return {"valid": false, "reason": "meşgul"}
	# Su hucresi (gol) ya da havuz suyu
	if _ground_char.get(cell, "") == "~" or float(_water_level.get(cell, 0.0)) > 0.0:
		if not bool(def.get("on_water", false)):
			return {"valid": false, "reason": "su"}
	# Kazilmis cukur (depth>=1): trap disi gecersiz; tumsek (depth<0) gecerli
	if int(_depth.get(cell, 0)) >= 1 and not bool(def.get("in_pit", false)):
		return {"valid": false, "reason": "çukur"}
	# 11.5/11.9: pit_only yapilar (merdiven/kazik) YALNIZ kazilmis cukura konur
	if bool(def.get("pit_only", false)) and int(_depth.get(cell, 0)) < 1:
		return {"valid": false, "reason": "çukur gerek"}
	# Zemin turu: cim/toprak/kum uzerine (su/tepe degil)
	if not (_ground_char.get(cell, "") in [".", "d", "s"]):
		return {"valid": false, "reason": "zemin"}
	return {"valid": true, "reason": ""}

func _place_rotate() -> void:
	if not _place_mode:
		return
	_place_rot = (_place_rot + 90) % 360
	if _ghost != null:
		_ghost.rotation_degrees.y = float(_place_rot)

func _place_confirm() -> void:
	if not _place_mode:
		return
	var cell := _place_cell
	if not _ghost_valid:
		hud.shake_action_button()
		_spawn_floating_text(cell, "Buraya olmaz", Color(1, 0.6, 0.6))
		return
	if not Inventory.remove_item(_place_item, 1):
		_exit_place_mode()
		return
	_set_placed(cell, _place_item, _place_rot)
	_place_pop(cell)  # 13.2 pop animasyonu
	# 13.5 cila: yerlesme tozu + ses kancasi
	_spawn_particles(_cell_center(cell) + Vector3(0, 0.15, 0),
			Color(0.72, 0.66, 0.52), 7)
	_play_sfx("place")
	_spawn_floating_text(cell, Items.display_name(_place_item) + " kuruldu",
			Color(0.8, 1.0, 0.8))
	_dirty = true
	# Seri dizme: item bitince modu kapat
	if Inventory.get_count(_place_item) <= 0:
		_exit_place_mode()

## Yerlesme pop animasyonu (Asama 5'te toz partikulu eklenir)
func _place_pop(cell: Vector2i) -> void:
	var node: Node3D = _placed_nodes.get(cell, null)
	if node == null:
		return
	node.scale = Vector3(0.6, 0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Bir dugumun (ve alt mesh'lerinin) yari saydam duz renge boyanmasi
## (hayalet gorunum). material_override ile GLB materyallerini gecici gizler.
func _tint_node(node: Node, color: Color, alpha: float) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(color.r, color.g, color.b, alpha)
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_tint_node(child, color, alpha)

# Oyuncu 3x3 cevresindeki istasyonlara gore uretim/arastirma yakinligi
func _update_station_proximity() -> void:
	var pc := _player_cell()
	var near_bench := false
	var near_res := false
	var near_hearth := false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			match _placed.get(pc + Vector2i(dx, dy), ""):
				"tezgah":
					near_bench = true
				"arastirma_masasi":
					near_res = true
				"ocak":
					near_hearth = true  # 14.3 pisirme istasyonu (arayuz)
	Crafting.near_station = near_bench
	Crafting.near_research = near_res
	Crafting.near_hearth = near_hearth
	# SU MODELI (11.2): yuzulur hucrede oyuncu yavaslar (tek placeholder)
	player.water_factor = WaterRules.SWIM_SPEED_FACTOR if is_swimmable(pc) else 1.0

# --- Sandik ------------------------------------------------------------------

# --- 14.1 Sandik deposu (oyuncu envanteriyle AYNI slot/stack altyapisi) ------

## Bos bir 16-slot depo (Inventory ornegi) olusturur ve agaca ekler.
## container_mode = baslangic seti verilmez. In-tree oldugu icin add/remove
## ve changed sinyali sorunsuz calisir.
func _new_chest_store() -> Node:
	var store := ChestStore.new()
	store.container_mode = true
	add_child(store)
	return store

## UI icin depoyu {esya: adet} gorunumune cevirir (HUD dict bekler).
func _chest_display(cell: Vector2i) -> Dictionary:
	var out: Dictionary = {}
	var store = _chests.get(cell, null)
	if store == null:
		return out
	for item_id: String in Items.ITEMS:
		var c: int = store.get_count(item_id)
		if c > 0:
			out[item_id] = c
	return out

func _chest_is_empty(cell: Vector2i) -> bool:
	var store = _chests.get(cell, null)
	return store == null or store.get_used_slots() == 0

## Tum sandik depolarini serbest birak (yeni oyun / yukleme oncesi).
func _clear_chests() -> void:
	for store in _chests.values():
		if store != null and is_instance_valid(store):
			store.queue_free()
	_chests.clear()

func _open_chest_at(cell: Vector2i) -> void:
	_open_chest = cell
	hud.show_chest(_chest_display(cell))

func _on_chest_transfer(item_id: String, to_chest: bool) -> void:
	if not _chests.has(_open_chest):
		return
	var store = _chests[_open_chest]
	if to_chest:
		# Envanterdeki tum yigini sandiga; sigmazsa sigan kadar
		var count: int = Inventory.get_count(item_id)
		var moved := 0
		while moved < count and store.add_item(item_id, 1):
			Inventory.remove_item(item_id, 1)
			moved += 1
		if moved < count:
			hud.show_chest(_chest_display(_open_chest), "Sandık dolu!")
			_dirty = true
			return
	else:
		# Sandiktaki tum yigini envantere; sigmazsa sigan kadar
		var have: int = store.get_count(item_id)
		var moved := 0
		while moved < have and Inventory.add_item(item_id, 1):
			store.remove_item(item_id, 1)
			moved += 1
		if moved == 0:
			hud.show_chest(_chest_display(_open_chest), "Envanter dolu!")
			return
	_dirty = true
	hud.show_chest(_chest_display(_open_chest))

## "Tümünü Koy" / "Tümünü Al" hizli butonlari (14.1).
func _on_chest_transfer_all(to_chest: bool) -> void:
	if not _chests.has(_open_chest):
		return
	var store = _chests[_open_chest]
	var full := false
	if to_chest:
		for item_id: String in Items.ITEMS:
			var count: int = Inventory.get_count(item_id)
			for i in count:
				if store.add_item(item_id, 1):
					Inventory.remove_item(item_id, 1)
				else:
					full = true
					break
	else:
		for item_id: String in Items.ITEMS:
			var have: int = store.get_count(item_id)
			for i in have:
				if Inventory.add_item(item_id, 1):
					store.remove_item(item_id, 1)
				else:
					full = true
					break
	_dirty = true
	var msg := ""
	if full:
		msg = "Sandık dolu!" if to_chest else "Envanter dolu!"
	hud.show_chest(_chest_display(_open_chest), msg)

func _on_chest_dismantle() -> void:
	if _chests.has(_open_chest) and _chest_is_empty(_open_chest):
		var cell := _open_chest
		hud.close_chest()
		_open_chest = Vector2i(-999, -999)
		_remove_placed(cell)

# --- 14.2 Dogus noktasi (yatak) ----------------------------------------------

## Aktif dogus noktasini ayarlar (son yerlestirilen yatak devralir). Olum
## sistemi gelince _respawn_cell() bunu kullanacak; simdilik arayuz + isaret.
func set_spawn(cell: Vector2i) -> void:
	_home_bed = cell
	_spawn_floating_text(cell, "Ev burası oldu", Color(0.8, 1.0, 0.85))

func get_spawn() -> Vector2i:
	return _home_bed

## Olumden sonra (ileride) donulecek hucre: ev yatagi varsa orasi, yoksa
## dunya dogus hucresi. Arayuz hazir; olum sistemi B/yaratik fazinda baglanir.
func _respawn_cell() -> Vector2i:
	return _home_bed if _home_bed != Vector2i(-999, -999) else _spawn_cell

# --- 14.3 Ocak (hearth) ------------------------------------------------------

## Yeni ocagi aktif yapar; onceki ocak pasiflesir (tek aktif kural). Isik
## mesale butcesinden BAGIMSIZ, her zaman yanar (base'in kalbi).
func _activate_hearth(cell: Vector2i, holder: Node3D) -> void:
	# Onceki aktif ocak varsa pasiflesir (isigi soner, ama yapi durur)
	if _hearth_cell != Vector2i(-999, -999) and _hearth_cell != cell \
			and _placed.has(_hearth_cell):
		if _hearth_light != null and is_instance_valid(_hearth_light):
			_hearth_light.visible = false
		_spawn_floating_text(cell, "Yeni ocak aktif (eski pasif)", Color(1, 0.9, 0.6))
	_hearth_cell = cell
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.66, 0.32)
	light.light_energy = 3.0
	light.omni_range = 7.5           # genis: base'in kalbi
	light.position = Vector3(0, 1.0, 0)
	light.shadow_enabled = false
	holder.add_child(light)
	_hearth_light = light

## Global sorgu (14.3): yaratik sistemi (B kismi) gece hedefi icin kullanacak.
## Aktif ocak yoksa gecersiz hucre doner.
func get_hearth() -> Vector2i:
	return _hearth_cell

# --- Yere birakilan esyalar ---------------------------------------------------

func _on_drop_item(slot_index: int) -> void:
	var content = Inventory.slots[slot_index]
	if content == null:
		return
	var pc := _player_cell()
	var target := pc
	for off in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var c: Vector2i = pc + off
		if is_walkable(c) and not _placed.has(c) and _ground_item_at(c) == -1:
			target = c
			break
	if target == pc:
		return  # bos komsu hucre yok
	Inventory.clear_slot(slot_index)
	_add_ground_item(target, String(content["id"]), int(content["count"]))
	_spawn_floating_text(target, "Yere bırakıldı", Color(0.95, 0.9, 0.7))
	_dirty = true

## Dunyada ayni anda durabilecek yer-esyasi siniri (performans + kalabalik).
## Dolunca en eski esya silinir (kaybolur).
const GROUND_ITEM_LIMIT: int = 100

## Yere bir esya yigini koyar; hem birakma, hem agac/kaya/yikim sacisi, hem
## de yuklemede kullanilir (#1: hepsi TEK sistem). Gorsel = kategori renkli
## low-poly kutu/kure; suzulme + yavas donme animasyonu (_tick_ground_items).
## Ayni id zaten o hucredeyse istiflenir (yeni node yok).
func _add_ground_item(cell: Vector2i, item_id: String, count: int) -> void:
	var existing := _ground_item_at(cell)
	if existing != -1 and String(_ground_items[existing]["id"]) == item_id:
		_ground_items[existing]["count"] = \
				int(_ground_items[existing]["count"]) + count
		return
	# ~100 sinir: en eskiyi at (dunya cop yigini olmasin)
	while _ground_items.size() >= GROUND_ITEM_LIMIT:
		var oldest: Dictionary = _ground_items[0]
		var on: Variant = oldest.get("node", null)
		if on != null and is_instance_valid(on):
			(on as Node).queue_free()
		_ground_items.remove_at(0)
	var node := _ground_item_visual(item_id)
	var base_y := 0.35
	node.position = _cell_center(cell) + Vector3(0, base_y, 0)
	add_child(node)
	_ground_items.append({"cell": cell, "id": item_id, "count": count,
			"node": node, "base_y": base_y, "phase": randf() * TAU})

## Kategori rengine gore basit low-poly govde (kutu; yenilebilir/yuvarlaklar
## kure). Ikon dokusu YOK — uzaktan net, ucuz, "dunya objesi" hissi.
func _ground_item_visual(item_id: String) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	if _item_is_round(item_id):
		var sm := SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.24
		mi.mesh = sm
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.2, 0.2, 0.2)
		mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _item_category_color(item_id)
	mat.roughness = 0.7
	mi.material_override = mat
	root.add_child(mi)
	return root

## Esya kategorisi -> renk (yer-esyasi govdesi). Kaba gruplar; bilinmeyen
## notr kahve-gri.
func _item_category_color(item_id: String) -> Color:
	match item_id:
		"odun", "kalas", "cubuk", "yaprak", "tohum":
			return Color(0.55, 0.38, 0.22)          # ahsap/bitki: kahve
		"tas", "cakil", "kil", "kum", "toprak":
			return Color(0.55, 0.56, 0.60)          # tas/toprak: gri
		"komur":
			return Color(0.18, 0.18, 0.20)          # komur: koyu
		"altin":
			return Color(0.85, 0.70, 0.25)          # altin: sari
		"bakir":
			return Color(0.78, 0.50, 0.30)          # bakir: turuncu-kahve
		"meyve", "cicek":
			return Color(0.85, 0.30, 0.35)          # yiyecek/cicek: kirmizi
		"mantar":
			return Color(0.80, 0.72, 0.60)          # mantar: bej
		"ip":
			return Color(0.80, 0.75, 0.55)          # ip: acik bej
		_:
			return Color(0.62, 0.55, 0.45)          # varsayilan

## Yuvarlak govde alan (kure) esyalar: yiyecek/toplanabilir.
func _item_is_round(item_id: String) -> bool:
	return item_id in ["meyve", "mantar", "altin", "bakir", "cakil"]

## Dususleri hucre cevresine sacar (agac/kaya hasadi + yikim ayni sistem #1).
## Her (id,adet) merkeze yakin, mumkunse bos bir yer-esyasi hucresine konur.
func _scatter_drops(center: Vector2i, drops: Dictionary) -> void:
	for item_id: String in drops:
		_add_ground_item(_free_scatter_cell(center), item_id, int(drops[item_id]))

## Merkeze en yakin, uzerinde yer-esyasi olmayan hucre (spiral); yoksa merkez.
func _free_scatter_cell(center: Vector2i) -> Vector2i:
	if _ground_item_at(center) == -1:
		return center
	for off: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1),
			Vector2i(-1, -1)]:
		if _ground_item_at(center + off) == -1:
			return center + off
	return center

var _ground_anim_t: float = 0.0

## Yer-esyalarini suzer (yukari-asagi) + yavasca dondurur. Her esya kendi
## fazinda (senkron degil).
func _tick_ground_items(_delta: float) -> void:
	_ground_anim_t += _delta
	for entry in _ground_items:
		var n: Variant = entry.get("node", null)
		if n == null or not is_instance_valid(n):
			continue
		var node: Node3D = n
		var ph: float = float(entry.get("phase", 0.0))
		var by: float = float(entry.get("base_y", 0.35))
		node.position.y = by + sin(_ground_anim_t * 2.0 + ph) * 0.06
		node.rotation.y = wrapf(_ground_anim_t * 1.1 + ph, 0.0, TAU)

func _ground_item_at(cell: Vector2i) -> int:
	for i in _ground_items.size():
		if _ground_items[i]["cell"] == cell:
			return i
	return -1

func _try_pickup_ground(cell: Vector2i) -> bool:
	var idx := _ground_item_at(cell)
	if idx == -1:
		return false
	var entry: Dictionary = _ground_items[idx]
	if not Inventory.can_add_all({entry["id"]: entry["count"]}):
		_spawn_floating_text(cell, "Envanter dolu!", Color(1, 0.6, 0.6))
		return true
	Inventory.add_all({entry["id"]: entry["count"]})
	if hud != null and hud.has_method("fly_pickup"):
		hud.fly_pickup(entry["id"],
				camera.unproject_position(_cell_center(cell) + Vector3(0, 0.5, 0)))
	# Toplama pop'u: kucuk partikul patlamasi (his)
	_spawn_particles(_cell_center(cell) + Vector3(0, 0.4, 0),
			_item_category_color(String(entry["id"])), 5)
	var pn: Variant = entry.get("node", null)
	if pn != null and is_instance_valid(pn):
		(pn as Node).queue_free()
	_ground_items.remove_at(idx)
	_dirty = true
	return true

# --- HEDEFLEME (12.2) + BAGLAM BUTONU (12.1) -------------------------------

## Oyuncunun onunde ~90 derece koni: baktigi hucre once, sonra komsular.
func _candidate_cells() -> Array:
	var pc := _player_cell()
	var fo := Vector2i(player.facing.round())
	if fo == Vector2i.ZERO:
		fo = Vector2i(0, 1)
	var front := pc + fo
	var cells: Array = [front]
	for oy in [-1, 0, 1]:
		for ox in [-1, 0, 1]:
			var o := Vector2i(ox, oy)
			var c := pc + o
			if o != Vector2i.ZERO and c != front:
				cells.append(c)
	return cells

func _facing_cell() -> Vector2i:
	var fo := Vector2i(player.facing.round())
	if fo == Vector2i.ZERO:
		fo = Vector2i(0, 1)
	return _player_cell() + fo

## Kazi hucresi su anki aletle isleve uygun mu? (kilit rozeti icin)
func _dig_valid(cell: Vector2i, tool: String) -> bool:
	var d := int(_depth.get(cell, 0))
	if d >= 4:
		return false
	if d >= DigRules.ROCK_DEPTH:
		return DigRules.PICKAXE_LIMITS.has(tool) \
				and d < int(DigRules.PICKAXE_LIMITS[tool])
	return DigRules.SHOVEL_LIMITS.has(tool) \
			and d < int(DigRules.SHOVEL_LIMITS[tool])

## Bir hucrenin elde tutulan esyaya gore eylem tanimi (12.1 tablosu).
## {type, cell, icon, valid, kind, [placed]}
func _describe_target(cell: Vector2i) -> Dictionary:
	var held := _held_item
	# Yerdeki esya: elde ne olursa olsun toplanir
	if _ground_item_at(cell) != -1:
		return {"type": "ground", "cell": cell, "icon": "grab",
				"valid": true, "kind": "grab"}
	# Cekic elde + yerlestirilmis yapi: SOKME (12.4). Istasyon acmadan once.
	var placed := String(_placed.get(cell, ""))
	if held == "cekic" and placed != "":
		# Hasarli yapi -> TAMIR; saglam yapi -> SÖKME (13.4)
		if _structures.hp_ratio(cell) < 0.999:
			return {"type": "repair", "cell": cell, "icon": "repair",
					"valid": true, "kind": "repair"}
		return {"type": "dismantle", "cell": cell, "icon": "repair",
				"valid": true, "kind": "dismantle"}
	# KAPI (13.5): dokununca ac/kapa (cekic disi elde)
	if placed == "kapi":
		return {"type": "door", "cell": cell, "icon": "open",
				"valid": true, "kind": "door"}
	# Yerlestirilmis istasyon/etkilesim
	if placed in ["sandik", "arastirma_masasi", "yatak"]:
		return {"type": "station", "cell": cell, "icon": "open",
				"valid": true, "kind": "open", "placed": placed}
	# Test kuklasi (Asama 4)
	if _dummies.has(cell):
		return {"type": "dummy", "cell": cell, "icon": "attack",
				"valid": true, "kind": "attack"}
	# Silah elde: dunya nesnesi hedeflenmez (agac kesilmez) — saldiri
	if ToolProfiles.is_weapon(held):
		return {"type": "none", "cell": cell, "icon": "attack",
				"valid": false, "kind": "attack"}
	# Nesneler (agac/kaya/cali/cicek/mantar)
	var obj := String(_objects.get(cell, ""))
	if obj != "" and OBJECT_DEFS.has(obj):
		if obj == "T":
			return {"type": "tree", "cell": cell, "icon": "chop",
					"valid": true, "kind": "chop"}
		if obj == "#":
			return {"type": "rock", "cell": cell, "icon": "mine",
					"valid": held == "kazma", "kind": "mine"}
		# Cali/cicek/mantar: hasat (bicak daha iyi ama el de toplar)
		return {"type": "plant", "cell": cell, "icon": "harvest",
				"valid": true, "kind": "harvest"}
	# Hucre bazli: kova/kurek/toprak
	if held == "kova" and (is_water_source(cell) or pool_at(cell) >= 0):
		return {"type": "scoop", "cell": cell, "icon": "fill",
				"valid": true, "kind": "scoop"}
	if held == "kova_dolu":
		return {"type": "pour", "cell": cell, "icon": "pour",
				"valid": int(_depth.get(cell, 0)) >= 1, "kind": "pour"}
	if held == "toprak" and _diggable(cell):
		return {"type": "pile", "cell": cell, "icon": "pile",
				"valid": true, "kind": "pile"}
	if (DigRules.SHOVEL_LIMITS.has(held) or DigRules.PICKAXE_LIMITS.has(held)) \
			and _diggable(cell):
		return {"type": "dig", "cell": cell, "icon": "dig",
				"valid": _dig_valid(cell, held), "kind": "dig"}
	return {"type": "none", "cell": cell, "icon": "fist",
			"valid": false, "kind": "none"}

## Bakis konisindeki en oncelikli hedef (yoksa silahsa saldiri / bos).
func _acquire_target() -> Dictionary:
	for cell: Vector2i in _candidate_cells():
		var d := _describe_target(cell)
		if d["type"] != "none":
			return d
	var fc := _facing_cell()
	if ToolProfiles.is_weapon(_held_item):
		return {"type": "attack", "cell": fc, "icon": "attack",
				"valid": true, "kind": "attack"}
	return {"type": "none", "cell": fc, "icon": "fist",
			"valid": false, "kind": "none"}

## Ana butonun bagalam ikonu + hedef vurgusu (her karede _process'ten).
func _update_targeting() -> void:
	var t := _acquire_target()
	hud.set_action_context(String(t["icon"]), bool(t["valid"]),
			ToolProfiles.is_weapon(_held_item))
	_update_target_highlight(t)

func _on_action_pressed() -> void:
	_perform_tool_action(_acquire_target())

## Bir hedef tanimina gore eylemi baslatir. Anlik etkilesimler (istasyon/
## toplama) dogrudan; alet eylemleri uc fazli sallanmayla (etki=strike).
func _perform_tool_action(t: Dictionary) -> void:
	var cell: Vector2i = t["cell"]
	match String(t["type"]):
		"ground":
			_try_pickup_ground(cell)
			return
		"station":
			_interact_station(cell, String(t.get("placed", "")))
			return
		"door":
			_toggle_door(cell)
			return
	if player.is_swinging():
		return
	var kind := String(t.get("kind", "none"))
	var prof := ToolProfiles.get_profile(_held_item)
	var started: bool = player.play_swing(prof,
			func(): _apply_strike(kind, cell))
	if started:
		_play_sfx(String(prof.get("swing_sfx", "")))  # 12.6 ses kancasi
	if started and not bool(t.get("valid", true)):
		hud.shake_action_button()

## Strike aninda cagrilir: gercek oyun etkisi burada uygulanir (12.3).
func _apply_strike(kind: String, cell: Vector2i) -> void:
	match kind:
		"chop", "harvest", "mine":
			_try_harvest(cell)
		"dig":
			_try_dig(cell)
		"pile":
			_try_pile(cell)
		"scoop":
			_try_scoop(cell)
		"pour":
			_try_pour(cell)
		"dismantle":
			if _placed.has(cell):
				_remove_placed(cell)  # cekic: malzeme %100 iade (12.4)
		"repair":
			_structure_repair(cell)  # cekic: vurus basina +hp (13.4)
		"attack":
			_melee_hit(cell)
		_:
			pass  # bosa sallama (whoosh) — etki yok

## Yerlestirilmis yapiyla etkilesim (tap match'inin ortak yolu).
func _interact_station(cell: Vector2i, placed: String) -> void:
	match placed:
		"sandik":
			_open_chest_at(cell)
		"arastirma_masasi":
			hud.research_button.button_pressed = true
		"yatak":
			_use_bed(cell)

# --- Hedef vurgusu (12.2): paylasilan halka, her kare hedefe tasinir ------
const _HL_OK := Color(0.42, 0.78, 0.40)     # UI success
const _HL_WARN := Color(0.93, 0.62, 0.26)   # UI warning

func _update_target_highlight(t: Dictionary) -> void:
	if _target_ring == null:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.40
		torus.outer_radius = 0.50
		torus.rings = 6
		torus.ring_segments = 20
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = _HL_OK
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		torus.material = mat
		_target_ring = MeshInstance3D.new()
		_target_ring.mesh = torus
		_target_ring.rotation_degrees = Vector3(90, 0, 0)  # yere yatir
		add_child(_target_ring)
	var typ := String(t["type"])
	# Hedefsiz (bos / saldiri) durumunda halka gizli — ekran sade kalsin
	if typ == "none" or typ == "attack":
		_target_ring.visible = false
		return
	_target_ring.visible = true
	_target_ring.position = _cell_center(Vector2i(t["cell"])) + Vector3(0, 0.06, 0)
	var col: Color = _HL_OK if bool(t.get("valid", true)) else _HL_WARN
	col.a = 0.85
	var mat2 := _target_ring.mesh.material as StandardMaterial3D
	if mat2 != null:
		mat2.albedo_color = col

# --- HIS / JUICE (12.6) — hepsi hafif, mobil dostu ------------------------

## Vurus durmasi: isabetli vuruşta cok kisa oyun hizi dususu (agirlik).
## Gercek zamanli timer (time_scale'den bagimsiz) ile geri alinir.
func _hit_stop(amount: float = 0.5, dur: float = 0.05) -> void:
	Engine.time_scale = amount
	var t := get_tree().create_timer(dur, true, false, true)
	t.timeout.connect(func(): Engine.time_scale = 1.0)

## Ses kancasi: assets/sfx/<name>.(ogg|wav) varsa calar, yoksa SESSIZ gecer
## (placeholder — dosya eklenince otomatik devreye girer, hata vermez).
func _play_sfx(name: String) -> void:
	if name == "":
		return
	for ext in [".ogg", ".wav"]:
		var path: String = "res://assets/sfx/" + name + ext
		if ResourceLoader.exists(path):
			var pl := AudioStreamPlayer.new()
			pl.stream = load(path)
			add_child(pl)
			pl.play()
			pl.finished.connect(func(): pl.queue_free())
			return

## Nesne turune gore partikul rengi (odun/tas/bitki)
func _object_particle_color(ch: String) -> Color:
	match ch:
		"T": return Color(0.52, 0.36, 0.20)   # odun kiymigi
		"#": return Color(0.52, 0.52, 0.56)   # tas
		"cicek", "mantar", "m", "n": return Color(0.42, 0.70, 0.34)
	return Color(0.6, 0.5, 0.4)

## Bir hucrede kucuk parcacik patlamasi. Renk malzemeye gore (odun kahve,
## tas gri, toprak toprak). Kendini birkac saniyede siler.
func _spawn_particles(pos: Vector3, color: Color, count: int = 5) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.amount = count
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 55.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, -6.0, 0)
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.08
	p.color = color
	add_child(p)
	get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free())

## Kivilcim (yanlis alet — tink). Kucuk parlak beyaz-sari patlama.
func _spark_burst(cell: Vector2i) -> void:
	_spawn_particles(_cell_center(cell) + Vector3(0, 0.5, 0),
			Color(1.0, 0.95, 0.6), 4)

# --- Yakin dovus (12.5) — hitbox stub; Asama 4'te doldurulur --------------
## strike aninda onundeki hitbox: kukla + kirilabilir nesne. Yaratik YOK;
## take_hit(damage, knockback_dir) arayuzu onlarin kapisi.
func _melee_hit(cell: Vector2i) -> void:
	_apply_hitbox(cell)

# --- Menzilli silahlar (12.5): mizrak firlatma / sapan / yay ---------------
# Nisan: saldiri butonu basili tutulunca _aiming acilir; yay gerdirme
# (_aim_charge 0->1) hiz+hasari olceklendirir. Birakinca mermi firlar.

## Her kare nisan gostergesini gunceller; yay icin gerdirme dolar.
func _tick_aim(delta: float) -> void:
	var kind := ToolProfiles.ranged_kind(_held_item)
	if kind == "bow":
		_aim_charge = minf(1.0, _aim_charge + delta)  # 0-1 sn dolum
	else:
		_aim_charge = 1.0
	if _aim_guide == null:
		var m := CylinderMesh.new()
		m.top_radius = 0.03; m.bottom_radius = 0.03; m.height = 1.0
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1, 1, 1, 0.35)
		m.material = mat
		_aim_guide = MeshInstance3D.new()
		_aim_guide.mesh = m
		add_child(_aim_guide)
	_aim_guide.visible = true
	var fo: Vector2 = player.facing.normalized()
	if fo == Vector2.ZERO:
		fo = Vector2(0, 1)
	var fwd := Vector3(fo.x, 0, fo.y)
	var length := 1.2 + _aim_charge * 1.8
	var origin := player.position + Vector3(0, 0.7, 0)
	_aim_guide.position = origin + fwd * (length * 0.5)
	_aim_guide.scale = Vector3(1, length, 1)
	# Cizgiyi ileri yonde yatir (silindir +Y ekseni -> fwd'a dondur)
	_aim_guide.look_at(origin + fwd, Vector3.UP)
	_aim_guide.rotate_object_local(Vector3(1, 0, 0), deg_to_rad(90))
	# Gerdirme son %20'sinde hafif titreme (yay)
	var mat2 := _aim_guide.mesh.material as StandardMaterial3D
	if mat2 != null:
		var a := 0.3 + _aim_charge * 0.45
		mat2.albedo_color = Color(1, 0.95, 0.7, a)

## Ucan mermileri ilerletir; yere/kuklaya carpinca saplar (12.5).
func _tick_projectiles(delta: float) -> void:
	var still_alive: Array = []
	for pr in _projectiles:
		var node: Node3D = pr["node"]
		if not is_instance_valid(node):
			continue
		# Vector3 deger tipi: dict icinde .y'yi dogrudan degistirmek
		# kopya uzerinde calisir; yerel degiskenle guncelleyip geri yaz.
		var vel: Vector3 = pr["vel"]
		vel.y += float(pr["gravity"]) * delta
		pr["vel"] = vel
		var new_pos: Vector3 = node.position + vel * delta
		node.position = new_pos
		# Ekseni etrafinda hafif donme + ucus yonune bakis
		node.rotate_object_local(Vector3(0, 1, 0), 12.0 * delta)
		pr["life"] = float(pr["life"]) - delta
		# Kukla carpismasi (xz yakinlik + yukseklik araligi)
		var hit_dummy := false
		for c: Vector2i in _dummies:
			var dc := _cell_center(c)
			if Vector2(new_pos.x - dc.x, new_pos.z - dc.z).length() < 0.5 \
					and new_pos.y > 0.2 and new_pos.y < 1.4:
				var dmy = _dummies[c]
				if is_instance_valid(dmy) and dmy.is_alive():
					dmy.take_hit(int(pr["damage"]), vel.normalized())
					_spawn_particles(new_pos, Color(0.95, 0.9, 0.7), 5)
					hit_dummy = true
					break
		var landed := new_pos.y <= ground_height(new_pos.x, new_pos.z) + 0.05
		if hit_dummy or landed or float(pr["life"]) <= 0.0:
			_land_projectile(pr)
		else:
			still_alive.append(pr)
	_projectiles = still_alive

## Mermi konar: saplanabilen tur yerde item olur (mizrak %100, ok %60).
func _land_projectile(pr: Dictionary) -> void:
	var node: Node3D = pr["node"]
	var recover: String = String(pr.get("recover_item", ""))
	var chance := float(pr.get("recover_chance", 0.0))
	if is_instance_valid(node):
		var cell := Vector2i(floori(node.position.x), floori(node.position.z))
		if recover != "" and randf() <= chance and _ground_item_at(cell) == -1 \
				and not _dummies.has(cell):
			_add_ground_item(cell, recover, 1)
		node.queue_free()

## Strike aninda onundeki hitbox (12.5): menzil boyunca ilk vurulabilir
## hedefe take_hit uygular. Su an hedef = TEST KUKLASI (12.7). Yaratiklar
## ayni take_hit imzasiyla otomatik dahil olacak — bu fonksiyon degismez.
func _apply_hitbox(cell: Vector2i) -> void:
	var prof := ToolProfiles.get_profile(_held_item)
	var dmg := int(prof.get("damage", 4))
	var reach := int(prof.get("reach", 1))
	var pc := _player_cell()
	var fo := Vector2i(player.facing.round())
	if fo == Vector2i.ZERO:
		fo = Vector2i(0, 1)
	var kdir := Vector3(float(fo.x), 0, float(fo.y)).normalized()
	# Once dogrudan hedeflenen hucre (saldiri butonu kuklaya bakiyorsa),
	# sonra menzil boyunca tarama
	var scan: Array = [cell]
	for r in range(1, reach + 1):
		scan.append(pc + fo * r)
	for c: Vector2i in scan:
		var d = _dummies.get(c, null)
		if d != null and is_instance_valid(d) and d.is_alive():
			d.take_hit(dmg, kdir)
			_spawn_particles(_cell_center(c) + Vector3(0, 0.7, 0),
					Color(0.95, 0.9, 0.7), 5)
			_hit_stop(0.5, 0.05)  # 12.6 vurus durmasi
			_play_sfx(String(prof.get("hit_sfx", "")))
			return
		# Yapilar da take_hit alir (13.4): yaratiklar da ayni yolu kullanacak
		if _placed.has(c) and _structures.has(c):
			_structure_take_hit(c, dmg, kdir)
			_hit_stop(0.5, 0.05)
			_play_sfx(String(prof.get("hit_sfx", "")))
			return

# --- YAPI DURUMLARI: take_hit / hasar / yikim / tamir (13.4) ---------------
## Yapiya hasar uygula (yaratiklar geldiginde ayni fonksiyonu cagiracak).
func _structure_take_hit(cell: Vector2i, damage: int, dir: Vector3) -> void:
	var state := _structures.apply_damage(cell, damage)
	# Sarsinti + malzeme partikulu (12.6 juice dili)
	_structure_shake(cell, dir)
	_spawn_particles(_cell_center(cell) + Vector3(0, 0.6, 0),
			Color(0.55, 0.42, 0.30), 5)
	if state == "destroyed":
		_destroy_structure(cell)
	elif state == "damaged":
		_apply_damaged_look(cell)
	_dirty = true

## Vurus tepkisi: yapi gorseli kisa sure sarsilir.
func _structure_shake(cell: Vector2i, dir: Vector3) -> void:
	var node: Node3D = _placed_nodes.get(cell, null)
	if node == null:
		return
	var base: Vector3 = node.position
	var tw := create_tween()
	tw.tween_property(node, "position", base + dir.normalized() * 0.06, 0.05)
	tw.tween_property(node, "position", base, 0.16) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## hp<%50 gorunumu: hafif egim (13.4). Renk tonu GLB'de zor oldugundan
## egim + hafif alcalma ile "hasarli" hissi verilir.
func _apply_damaged_look(cell: Vector2i) -> void:
	var node: Node3D = _placed_nodes.get(cell, null)
	if node == null:
		return
	node.rotation_degrees.z = 7.0
	node.position.y = _cell_center(cell).y - 0.04

## hp 0: yapi yikilir, malzemenin %25'i yere sacilir, hucre bosalir (13.4).
func _destroy_structure(cell: Vector2i) -> void:
	var item_id := String(_placed.get(cell, ""))
	# Malzemenin %25'i (tarif maliyetinden) yere dusuruluru
	var cost: Dictionary = Recipes.CRAFT_RECIPES.get(item_id, {}).get("cost", {})
	var drops: Dictionary = {}
	for mat in cost:
		var n := int(floor(float(cost[mat]) * 0.25))
		if n > 0:
			drops[mat] = n
	# 14.1: sandik yikilirsa ICINDEKI TUM item'lar yere sacilir (kayip yok)
	if item_id == "sandik" and _chests.has(cell):
		var store = _chests[cell]
		for spill_id: String in Items.ITEMS:
			var have: int = store.get_count(spill_id)
			if have > 0:
				var st := _first_free_neighbor(cell)
				if st == Vector2i(-999, -999):
					st = cell
				_add_ground_item(st, spill_id, have)
	# Yapiyi kaldir (iade yok — yikim). _release_structure_cell sandik deposunu,
	# ocak isigini, platform yuksekligini de temizler.
	_release_structure_cell(cell)
	_spawn_particles(_cell_center(cell) + Vector3(0, 0.5, 0),
			Color(0.5, 0.4, 0.3), 10)
	_play_sfx("break")  # 13.5 cila: yikim sesi (dosya yoksa sessiz)
	_spawn_floating_text(cell, "Yıkıldı!", Color(1, 0.6, 0.5))
	# Enkaz: komsu bos hucrelere sacilir
	for mat in drops:
		var t := _first_free_neighbor(cell)
		if t != Vector2i(-999, -999):
			_add_ground_item(t, mat, drops[mat])
	_dirty = true

## Cekic tamiri: vurus basina +hp, tarifin en ucuz malzemesinden 1 duser.
func _structure_repair(cell: Vector2i) -> void:
	if not _structures.has(cell):
		return
	if _structures.hp_ratio(cell) >= 0.999:
		_spawn_floating_text(cell, "Zaten sağlam", Color(0.8, 1, 0.8))
		return
	var item_id := String(_placed.get(cell, ""))
	var cost: Dictionary = Recipes.CRAFT_RECIPES.get(item_id, {}).get("cost", {})
	var mat := _cheapest_material(cost)
	if mat != "" and Inventory.get_count(mat) <= 0:
		_spawn_floating_text(cell, "%s gerek" % Items.display_name(mat),
				Color(1, 0.9, 0.6))
		return
	if mat != "":
		Inventory.remove_item(mat, 1)
	var inst: Dictionary = _structures.get_inst(cell)
	var full := _structures.apply_repair(cell, maxi(1, int(inst.get("max_hp", 100)) / 4))
	# Gorunumu tazele (egim/alcalmayi geri al saglamsa)
	var node: Node3D = _placed_nodes.get(cell, null)
	if node != null and full:
		node.rotation_degrees.z = 0.0
		node.position.y = _cell_center(cell).y
	_spawn_particles(_cell_center(cell) + Vector3(0, 0.6, 0),
			Color(0.7, 0.9, 0.7), 4)
	_spawn_floating_text(cell, "Tamir edildi" if full else "Tamir...",
			Color(0.8, 1, 0.8))
	_dirty = true

func _cheapest_material(cost: Dictionary) -> String:
	var best := ""
	var best_n := 999999
	for mat in cost:
		if int(cost[mat]) < best_n:
			best_n = int(cost[mat])
			best = String(mat)
	return best

func _first_free_neighbor(cell: Vector2i) -> Vector2i:
	for off: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1),
			Vector2i(-1, 1), Vector2i(0, 0)]:
		var c := cell + off
		if is_walkable(c) and not _placed.has(c) and _ground_item_at(c) == -1:
			return c
	return Vector2i(-999, -999)

# --- KAPI (13.5): ac/kapa; acikken gecilir+donuk, kapaliyken kati -----------
func _toggle_door(cell: Vector2i) -> void:
	if not _structures.has(cell):
		return
	var open := not _structures.is_open(cell)
	_structures.set_open(cell, open)
	if open:
		_solid_cells.erase(cell)
	else:
		_solid_cells[cell] = true
	var node: Node3D = _placed_nodes.get(cell, null)
	if node != null:
		var base := float(_structures.rotation_of(cell))
		var tw := create_tween()
		tw.tween_property(node, "rotation_degrees:y",
				base + (90.0 if open else 0.0), 0.2) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_play_sfx("door")  # gicirti (dosya yoksa sessiz)
	_spawn_floating_text(cell, "Açıldı" if open else "Kapandı",
			Color(0.9, 0.9, 0.7))
	_dirty = true

# --- MESALE (13.5): sicak OmniLight3D + flicker + isik butcesi --------------
func _add_torch_light(cell: Vector2i, holder: Node3D) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.28)
	light.light_energy = 2.2
	light.omni_range = 4.5
	light.position = Vector3(0, 0.8, 0)
	light.shadow_enabled = false  # mobil butce
	holder.add_child(light)
	_torch_lights[cell] = light

## Isik butcesi + flicker (13.5): oyuncuya en yakin MAX_TORCHES yanar,
## fazlasi soner (yapi durur). Her kare hafif titresim.
func _update_torches(delta: float) -> void:
	if _torch_lights.is_empty():
		return
	# Gecersiz dugumleri temizle
	var cells: Array = []
	for c: Vector2i in _torch_lights:
		if is_instance_valid(_torch_lights[c]):
			cells.append(c)
	# Oyuncuya uzakliga gore sirala; en yakin MAX_TORCHES aktif
	var pp := player.position
	cells.sort_custom(func(a, b):
		return _cell_center(a).distance_squared_to(pp) \
				< _cell_center(b).distance_squared_to(pp))
	var t := Time.get_ticks_msec() / 1000.0
	for i in cells.size():
		var light: OmniLight3D = _torch_lights[cells[i]]
		if i < MAX_TORCHES:
			light.visible = true
			# Flicker: enerjiyi hafifce oynat (hucreye gore faz)
			var phase := float(cells[i].x * 7 + cells[i].y * 13)
			light.light_energy = 2.2 * (0.86 + 0.14 * sin(t * 11.0 + phase))
		else:
			light.visible = false

## Kukla yerlestir (12.7): elde "kukla" ile bos hucreye dokun.
func _try_place_dummy(cell: Vector2i) -> bool:
	if _dummies.has(cell) or _placed.has(cell) or _objects.has(cell):
		return false
	if cell == _player_cell():
		return false
	if not (_ground_char.get(cell, "") in [".", "d", "s"]):
		return false
	if not Inventory.remove_item("kukla", 1):
		return false
	_spawn_dummy(cell)
	_spawn_floating_text(cell, "Kukla kuruldu", Color(0.8, 1.0, 0.8))
	_dirty = true
	return true

func _spawn_dummy(cell: Vector2i) -> void:
	var dummy := HittableDummy.new()
	dummy.position = _cell_center(cell)
	add_child(dummy)
	_dummies[cell] = dummy
	_solid_cells[cell] = true

# --- Saldiri butonu (12.1/12.5) -------------------------------------------
var _combo_flip: bool = false        # kilic 2'li kombo yon degistirici
var _last_attack_ms: int = 0

func _on_attack_pressed() -> void:
	if player.is_swinging():
		return
	var prof := ToolProfiles.get_profile(_held_item)
	var target := _acquire_target()
	var cell: Vector2i = target["cell"] if target["type"] == "dummy" \
			else _facing_cell()
	# KILIC 2'li kombo (12.3/12.5): pes pese basista ters yon + ileri adim
	var combo := false
	if bool(prof.get("combo", false)):
		var now := Time.get_ticks_msec()
		if now - _last_attack_ms < 700:
			_combo_flip = not _combo_flip
			combo = _combo_flip
		else:
			_combo_flip = false
		_last_attack_ms = now
	var did: bool = player.play_swing(prof, func(): _melee_hit(cell), 0, combo)
	if did and combo:
		# Ikinci kesikte kucuk ileri adim — saldiriya yon hissi
		var fo := Vector2i(player.facing.round())
		if fo == Vector2i.ZERO:
			fo = Vector2i(0, 1)
		var step := Vector3(float(fo.x), 0, float(fo.y)).normalized() * 0.3
		var tw := create_tween()
		tw.tween_property(player, "position", player.position + step, 0.12)

func _on_attack_hold_started() -> void:
	# Menzilli silahsa nisan modu (Asama 5); degilse normal saldiri gibi
	if ToolProfiles.ranged_kind(_held_item) == "":
		return
	_begin_aim()

func _on_attack_hold_released() -> void:
	if _aiming:
		_release_aim()
	elif ToolProfiles.ranged_kind(_held_item) == "":
		# Menzilsiz silahta uzun basis da normal saldiri yapsin
		_on_attack_pressed()

## Nisan modunu ac (basili tut). Muhimmat gerekiyorsa yoklugunu simdi
## kontrol etmeyiz — birakinca kontrol edilir (gerdirme hissi kalsin).
func _begin_aim() -> void:
	if player.is_swinging():
		return
	_aiming = true
	_aim_charge = 0.0

## Birak: mermiyi firlat (mizrak/cakil/ok). Muhimmat yoksa iptal.
func _release_aim() -> void:
	_aiming = false
	if _aim_guide != null:
		_aim_guide.visible = false
	var kind := ToolProfiles.ranged_kind(_held_item)
	var prof := ToolProfiles.get_profile(_held_item)
	var fo: Vector2 = player.facing.normalized()
	if fo == Vector2.ZERO:
		fo = Vector2(0, 1)
	var fwd := Vector3(fo.x, 0, fo.y)
	var charge := _aim_charge
	match kind:
		"spear":
			# Mizrak firlat: elden dus, havada ucup saplan, yerden alinir.
			# Isabette durtmeden %50 fazla hasar.
			if not Inventory.remove_item("mizrak", 1):
				return
			if Inventory.get_count("mizrak") <= 0:
				_on_hold_requested("")
			var dmg := int(round(float(prof.get("damage", 20)) * 1.5))
			_launch_projectile("spear", fwd, 11.0, 2.2, -12.0, dmg,
					"mizrak", 1.0)
		"sling":
			if Inventory.get_count("cakil") <= 0:
				_spawn_floating_text(_player_cell(), "Çakıl yok",
						Color(1, 0.9, 0.6))
				return
			Inventory.remove_item("cakil", 1)
			_launch_projectile("pebble", fwd, 15.0, 1.2, -12.0,
					int(prof.get("damage", 6)), "", 0.0)
		"bow":
			if Inventory.get_count("ok") <= 0:
				_spawn_floating_text(_player_cell(), "Ok yok",
						Color(1, 0.9, 0.6))
				return
			Inventory.remove_item("ok", 1)
			# Gerdirme orani hiz+hasari olcekler (min %30 guc)
			var power := lerpf(0.3, 1.0, charge)
			var speed := lerpf(9.0, 20.0, charge)
			var dmg2 := int(round(float(prof.get("damage", 10)) * (0.5 + power)))
			_launch_projectile("arrow", fwd, speed, 1.4, -5.0, dmg2,
					"ok", 0.6)
	# Firlatma "yay/sapan sallama" hissi icin kisa bir sallanma da oynat
	player.play_swing(prof, func(): pass)

## Bir mermi olustur ve ucusa birak.
func _launch_projectile(kind: String, fwd: Vector3, speed: float,
		up: float, gravity: float, damage: int, recover_item: String,
		recover_chance: float) -> void:
	var node := _make_projectile(kind)
	node.position = player.position + Vector3(0, 0.8, 0) + fwd * 0.4
	add_child(node)
	_projectiles.append({
		"node": node,
		"vel": fwd.normalized() * speed + Vector3(0, up, 0),
		"gravity": gravity,
		"damage": damage,
		"life": 4.0,
		"recover_item": recover_item,
		"recover_chance": recover_chance,
	})

## Basit mermi modelleri (mizrak/ok/cakil).
func _make_projectile(kind: String) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	match kind:
		"pebble":
			var sm := SphereMesh.new(); sm.radius = 0.06; sm.height = 0.12
			mi.mesh = sm; mat.albedo_color = Color(0.5, 0.5, 0.55)
		"arrow":
			var cm := CylinderMesh.new(); cm.top_radius = 0.015
			cm.bottom_radius = 0.015; cm.height = 0.5
			mi.mesh = cm; mat.albedo_color = Color(0.55, 0.38, 0.22)
			mi.rotation_degrees = Vector3(90, 0, 0)
		_:  # spear
			var cm2 := CylinderMesh.new(); cm2.top_radius = 0.02
			cm2.bottom_radius = 0.02; cm2.height = 0.7
			mi.mesh = cm2; mat.albedo_color = Color(0.6, 0.42, 0.26)
			mi.rotation_degrees = Vector3(90, 0, 0)
	mi.material_override = mat
	root.add_child(mi)
	return root

func _try_harvest(cell: Vector2i) -> bool:
	var ch: String = _objects.get(cell, "")
	if ch == "" or not OBJECT_DEFS.has(ch):
		return false
	var def: Dictionary = OBJECT_DEFS[ch]
	if ch == "#":
		# KAZMA KILIDI (12.4): kayaya yalniz kazma isler. Yanlis aletle
		# vurus "tink" geri sekmesi verir, hasar 0.
		if _held_item != "kazma":
			_spawn_floating_text(cell, "Tink! — kazma gerek", Color(0.8, 0.85, 0.9))
			_spark_burst(cell)
			return true
		# Tas turune gore dusen esya degisir (normal/komur/altin)
		var v := _stone_variant(cell)
		def = {"drops": STONE_VARIANTS[v]["drops"], "hits": STONE_VARIANTS[v]["hits"],
				"tool": {"item": "kazma", "hits": 2}}
	var hits_needed: int = def.get("hits", 1)
	if def.has("tool") and _held_item == def["tool"]["item"]:
		hits_needed = def["tool"]["hits"]
	# BICAK (12.4): bitkileri hizli hasat eder (profil zaten hizli); tek
	# vurusta biter (hits 1'e iner) — "hasat" hissi
	if _held_item == "bicak" and ch in ["cicek", "mantar", "m"]:
		hits_needed = 1
	var damage: int = int(_object_hits.get(cell, 0)) + 1
	# 12.6 his: her vuruşta malzeme partikulu + isabet sesi
	_spawn_particles(_cell_center(cell) + Vector3(0, 0.5, 0),
			_object_particle_color(ch), 5)
	_play_sfx(String(def.get("hit_sfx", "")) if def.has("hit_sfx") else "")
	if damage < hits_needed:
		_object_hits[cell] = damage
		_spawn_floating_text(cell, "%d/%d" % [damage, hits_needed], Color(1.0, 0.95, 0.6))
		return true
	# BICAK 2x hasat verimi (12.4): bitkilerde dususlerini ikiye katla
	var mult := 2 if (_held_item == "bicak" and ch in ["cicek", "mantar", "m"]) else 1
	var drops: Dictionary = {}
	for item_id in def["drops"]:
		drops[item_id] = int(def["drops"][item_id]) * mult
	_object_hits.erase(cell)
	# #1: agac/kaya dususleri artik ENVANTERE ucmaz — yere sacilir (yikimla
	# ayni sistem). Oyuncu "al" ile toplar. Envanter dolu olsa da hasat olur;
	# esyalar yerde bekler. Klasik survival dongusu (kes -> topla).
	_scatter_drops(cell, drops)
	var gained: PackedStringArray = []
	for item_id in drops:
		gained.append("+%d %s" % [drops[item_id], Items.display_name(item_id)])
	_spawn_floating_text(cell, " ".join(gained), Color(0.7, 1.0, 0.7))
	# 12.6 his: kirilma aninda vurus durmasi + buyuk partikul patlamasi
	_hit_stop(0.55, 0.05)
	_spawn_particles(_cell_center(cell) + Vector3(0, 0.6, 0),
			_object_particle_color(ch), 9)
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
	_dirty = true
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
		_solid_cells[cell] = true
		_regrow_type.erase(cell)
	_rebuild_objects()
	_dirty = true

func _on_hold_requested(item_id: String) -> void:
	if item_id != "" and Inventory.get_count(item_id) <= 0:
		return
	_held_item = item_id
	hud.set_held_item(item_id)
	# #2: esya id'sini dogrudan ver — player3d GLB varsa yukler, yoksa
	# prosedurel low-poly placeholder uretir (kademe rengiyle).
	player.set_held_tool(item_id)
	if not _loading:
		_dirty = true

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
