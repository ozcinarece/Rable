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
const EnvModels = preload("res://scripts/env_models.gd")
const DigWaterVisual = preload("res://scripts/dig_water_visual.gd")
const WaterRules = preload("res://scripts/water_rules.gd")
const WaterSim = preload("res://scripts/water_sim.gd")
const ToolProfiles = preload("res://scripts/tool_profiles.gd")
const HittableDummy = preload("res://scripts/hittable_dummy.gd")
const StructureManager = preload("res://scripts/structure_manager.gd")
const EngBalance = preload("res://scripts/engineering_balance.gd")
const HudScript = preload("res://scripts/hud.gd")
const CreatureScript = preload("res://scripts/creature.gd")
const CreatureBalance = preload("res://scripts/creature_balance.gd")
const CreatureAI = preload("res://scripts/creature_ai.gd")
const FenceBalance = preload("res://scripts/fence_balance.gd")
const FellBalance = preload("res://scripts/fell_balance.gd")
const Recipes = preload("res://scripts/recipes.gd")
const Items = preload("res://scripts/items.gd")
const ChestStore = preload("res://scripts/inventory.gd")  # 14.1 sandik deposu
const TestMode = preload("res://scripts/test_mode.gd")
const KesifBalance = preload("res://scripts/kesif_balance.gd")  # Bolum 16

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
const TarimBalance = preload("res://scripts/tarim_balance.gd")

const PLACE_MODELS := {
	# Kullanicinin Meshy tezgahi (test/workbench.glb; olculdu 1.0x0.64x0.66).
	# h 0.85 karaktere gore buyuk kaciyordu -> 0.6 (genislik ~0.94 hucre).
	"tezgah": {"model": "res://assets/models/test/workbench.glb",
			"h": 0.6, "solid": true, "behavior": "station", "max_hp": 120},
	"arastirma_masasi": {"model": "res://assets/models/nature/quat_table.glb",
			"h": 0.8, "solid": true, "long": 1.0,
			"behavior": "station", "max_hp": 120},
	"sandik": {"model": "res://assets/models/test/storege_box.glb",
			"h": 0.55, "solid": true, "behavior": "station", "max_hp": 60},
	# OCAK = ancient_heart. Onceki model campfire-pit.glb (odun yigini)
	# idi; Ocak artik gecenin merkezi -- yaratiklar HER ZAMAN ona
	# yuruyor, yani bir kamp atesinden fazlasi olmali.
	# OLCULDU: 1.000 x 0.326 x 0.959 -> model zaten Y-up, dondurme yok.
	# "long" 1.0: en uzun eksen tam 1 hucre. "h" ile olceklenseydi
	# (0.38 / 0.326 = 1.17) ayak izi hucreyi tasardi. Boylece kendi
	# oranini koruyor: 1 m eninde, 33 cm yuksekliginde alcak tas kalp.
	# tint: Meshy dokulari "isik pismis" ve emissive 1,1,1 ile geliyor
	# (beyaz parlama tuzagi). _tame_meshy_materials isimayi kapatir;
	# ton hafif tutuldu, ilk kareden sonra ayarlanabilir.
	"ocak": {"model": "res://assets/models/test/ancient_heart.glb",
			"long": 1.0, "h": 0.33, "solid": true, "behavior": "hearth",
			"max_hp": 400, "tint": Color(0.86, 0.84, 0.86)},
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
	# CIT (cit-sistemi): KENAR-bazli tek istisna — hucreyi degil iki
	# hucre arasindaki kenari kaplar. behavior "fence" tum akislari
	# (gecerlilik/hayalet/yerlestirme) kenar koduna saptirir; max_hp
	# ve olcekler fence_balance.gd'de.
	"cit": {"model": "res://assets/models/test/fence_rail.glb",
			"h": 0.3, "solid": false, "behavior": "fence", "max_hp": 40},
	# CIT-FIX: yerlestirme artik TEK DIREK diker (yonsuz, KOSEYE).
	# Ray ayri: iki diregi dokunarak bagla (fence_balance.RAY_COST).
	"cit_diregi": {"model": "res://assets/models/test/fence_post.glb",
			"h": 0.75, "solid": false, "behavior": "fence_post", "max_hp": 40},
	"mesale": {"model": "res://assets/models/tools/campfire-stand.glb",
			"h": 0.7, "solid": false,
			"behavior": "torch", "max_hp": 30},
	# KESIF 16.4: yol koru yere konunca MINI KAMP ATESI olur (isik cemberi
	# + pisirme + kayit noktasi). Yerlestirme isik kapisina tabidir.
	"yol_koru": {"model": "res://assets/models/tools/campfire-pit.glb",
			"h": 0.5, "solid": false,
			"behavior": "sefer_atesi", "max_hp": 20},
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
var _creatures: Array = []         # BÖLÜM 15: aktif yaratik ornekleri (creature.gd)
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
# --- KALITE + FPS overlay (mobil perf) ---------------------------------
const PerfBalance = preload("res://scripts/perf_balance.gd")
const QUALITY_PATH := "user://quality.txt"  # secilen kademe kaydedilir
var _quality_tier: String = PerfBalance.DEFAULT_TIER
var _max_torches: int = MAX_TORCHES  # kalite ile degisir
var _perf_layer: CanvasLayer
var _perf_label: Label
var _perf_on: bool = false
var _perf_acc: float = 0.0
var _perf_fps: Array = []
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
var _cam_layer: CanvasLayer      # R1: Kamera/Gorunum debug UI'si (Ayarlar'dan acilir)
var cam_distance: float = CAM_ZOOM_DEFAULT  # yakinlik carpani (uzak varsayilan)
var cam_pitch: float = 52.0    # bakis acisi (derece)
var character_path: String = "res://assets/models/test/character_animated_2.glb"  # rigli animasyonlu Meshy (skinned olcek fix'li)
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
	# GRIP AYAR MODU (debug): HUD butonlari -> oyuncunun canli grip ofseti
	hud.grip_nudge_requested.connect(_on_grip_nudge)
	hud.grip_rotate_requested.connect(_on_grip_rotate)
	hud.grip_reset_requested.connect(_on_grip_reset)
	hud.grip_save_requested.connect(_on_grip_save)
	hud.grip_move_requested.connect(_on_grip_move)
	hud.grip_tuner_opened.connect(func(): hud.set_grip_status(player.grip_status()))
	# YERLESIM EDITORU (gelistirici araci). Sinyaller yalniz debug
	# build'de yayinlanir; yayin surumunde anahtar hic olusturulmuyor.
	hud.editor_toggled.connect(editor_set_enabled)
	hud.editor_tool_selected.connect(editor_set_tool)
	hud.editor_item_selected.connect(editor_set_item)
	hud.editor_rotate_requested.connect(editor_rotate)
	hud.editor_scale_changed.connect(editor_set_olcek)
	hud.editor_undo_requested.connect(editor_undo)
	hud.editor_export_requested.connect(editor_disa_aktar)
	hud.editor_load_requested.connect(editor_yukle)
	hud.editor_eraser_toggled.connect(editor_set_firca_silgi)
	hud.settings_toggled.connect(func(o: bool): _cam_layer.visible = o)
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
	# TARIM (tarim-3d): veri->gorsel koprusu + gun surucusu (once bitisik-su
	# otomatigi, sonra buyume tick'i — sira world3d'de, belirsizlik yok)
	Farming.plot_changed.connect(_on_plot_changed)
	DayNight.dawn_started.connect(_on_farm_dawn)
	DayNight.dawn_started.connect(_on_kesif_dawn)  # 16.4 sefer sabahi
	hud.fener_kisik_toggled.connect(set_fener_kisik)  # 16.5 stealth
	# GECE DALGASI (minimal): kanca artik BOS degil — gece dogur, safakta erit.
	DayNight.night_started.connect(_on_night_started)
	DayNight.dawn_started.connect(_on_dawn_clear_creatures)
	hud.perf_overlay_toggled.connect(_on_perf_overlay_toggled)
	hud.quality_changed.connect(_on_quality_changed)
	_build_camera_ui()
	_build_perf_overlay()
	_load_quality()
	apply_quality(_quality_tier)
	# kayit-sistemi: SaveManager bu sahneyi (dünya durumu) kaydeder/yükler.
	SaveManager.world = self
	# Açılışta kayıt varsa "Devam Et / Yeni Oyun" seçimi; yoksa taze dünya
	# (zaten kuruldu). CI modunda atlanır ki sahneler hep temiz başlasın.
	# BOYAMA ARACI 3D ONIZLEMESI: harita ressami bu sahneyi SubViewport
	# icinde acar. Menu/HUD yok, kayit yuklenmez (taze uretim — maske
	# yeni kaydedildi, onu gormek istiyoruz), kamera tepeden.
	if OS.has_environment("RABLE_MASK_PREVIEW"):
		hud.visible = false
		DayNight.jump_to_day()
		_cam_locked = true
		var ctr := _cell_center(Vector2i(_map_w / 2, _map_h / 2))
		camera.position = ctr + Vector3(0.0, 120.0, 0.5)
		camera.look_at(ctr)
		return
	if not OS.has_environment("RABLE_SCREENSHOT") and SaveManager.has_save():
		_show_start_menu()
	# CI ekran goruntusu modu: birkac saniye sonra kare kaydet ve cik
	if OS.has_environment("RABLE_SCREENSHOT"):
		_setup_screenshot(OS.get_environment("RABLE_SCREENSHOT"))

# GERCEK dokunus gonderir (basma+birakma). Buton sinyalleri kodla degil
# giris zinciriyle tetiklenir — cihazdaki tiklama sorunlarini CI'da yakalar.
func _tap_at(pos: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = pos
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().create_timer(0.1).timeout
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = pos
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().create_timer(0.4).timeout

func _run_click_tests(save_path: String) -> void:
	var lines := PackedStringArray()
	# 1) Canta: dock butonuna dokun -> acilmali; X'e dokun -> kapanmali
	await _tap_at(hud.inventory_button.get_global_rect().get_center())
	var inv_acildi: bool = hud.inventory_button.button_pressed
	_snap(save_path.replace(".png", "_click_env.png"))
	await _tap_at(hud.inventory_close.get_global_rect().get_center())
	var inv_kapandi: bool = not hud.inventory_button.button_pressed
	lines.append("envanter: acildi=%s kapandi=%s" % [inv_acildi, inv_kapandi])
	# 2) Uretim: ayni akis
	await _tap_at(hud.craft_button.get_global_rect().get_center())
	var cr_acildi: bool = hud.craft_button.button_pressed
	_snap(save_path.replace(".png", "_click_uretim.png"))
	await _tap_at(hud.craft_close.get_global_rect().get_center())
	var cr_kapandi: bool = not hud.craft_button.button_pressed
	lines.append("uretim: acildi=%s kapandi=%s" % [cr_acildi, cr_kapandi])
	# 3) Arastirma: ac + kapat (research_root kendi X'i)
	await _tap_at(hud.research_button.get_global_rect().get_center())
	var ar_acildi: bool = hud.research_button.button_pressed
	await _tap_at(hud.research_button.get_global_rect().get_center())
	# dock gizliyken ayni noktaya dokunus bosa gider; X uzerinden kapat
	if hud.research_button.button_pressed:
		var rx: Node = hud.research_root.find_child("CloseButton", true, false)
		if rx != null and rx is Control:
			await _tap_at((rx as Control).get_global_rect().get_center())
	var ar_kapandi: bool = not hud.research_button.button_pressed
	lines.append("arastirma: acildi=%s kapandi=%s" % [ar_acildi, ar_kapandi])
	# 4) Ayarlar: ac + panel icindeki "Kapat" ile kapat
	await _tap_at(hud.reset_button.get_global_rect().get_center())
	var ay_acildi: bool = hud.reset_button.button_pressed
	_snap(save_path.replace(".png", "_click_ayarlar.png"))
	var kapat_pos := Vector2.ZERO
	if hud._settings_panel != null:
		for b in hud._settings_panel.find_children("*", "Button", true, false):
			if (b as Button).text == "Kapat":
				kapat_pos = (b as Control).get_global_rect().get_center()
				await _tap_at(kapat_pos)
				break
	_snap(save_path.replace(".png", "_click_ayarlar2.png"))
	var ay_kapandi: bool = not hud.reset_button.button_pressed
	lines.append("ayarlar: acildi=%s kapandi=%s kapat_pos=%s" % [
			ay_acildi, ay_kapandi, str(kapat_pos)])
	var out := "\n".join(lines) + "\n"
	print("CLICKTEST:\n" + out)
	var f := FileAccess.open("res://docs/screens/clicktest.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(out)
		f.close()

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
	# --- TEST KATMANI ---------------------------------------------------
	# "hizli": yalniz MANTIK testleri; ekran goruntusu, vitrin, bekleme
	# YOK. Gercek --headless'te (xvfb'siz, OpenGL'siz) kosar ve saniyeler
	# icinde biter -> her push'ta calistirilabilir.
	# "tam" (varsayilan): butun gorsel akis (kareler + vitrin + sondalar).
	# Ayrim CI is akisinda RABLE_TEST_LEVEL ile veriliyor.
	if OS.get_environment("RABLE_TEST_LEVEL") == "hizli":
		_run_fast_tests()
		return
	# STIL: animasyonlu Meshy karakteri — skinned olcek fix'i (_fix_skinned_scale)
	# Armature 0.01 olcegini kemik pozlarindan duzeltir.
	player.set_character("res://assets/models/test/character_animated_2.glb")
	player.set_held_tool("balta")  # yeni axe.glb elde gorunsun
	await get_tree().create_timer(4.0).timeout
	_snap(save_path)
	# MASKE KARELERI (v2 dogrulamasi): maske dosyasi varsa kusbakisi +
	# tepe falezi + kumsal yakin karesi. Maske main'e commit'LENMEZ —
	# bu kareler yalniz ornekli dalda cekilir; dosya yoksa blok atlanir.
	if MapMask.load_image() != null:
		_cam_locked = true
		var mk_ctr := _cell_center(Vector2i(_map_w / 2, _map_h / 2))
		camera.position = mk_ctr + Vector3(0.0, 120.0, 0.5)
		camera.look_at(mk_ctr)
		await get_tree().create_timer(0.8).timeout
		_snap(save_path.replace(".png", "_maske_kusbakisi.png"))
		var mk_tepe := _cell_center(Vector2i(104, 104))
		camera.position = mk_tepe + Vector3(-8.0, 7.0, 10.0)
		camera.look_at(mk_tepe)
		await get_tree().create_timer(0.7).timeout
		_snap(save_path.replace(".png", "_maske_tepe.png"))
		var mk_kum := _cell_center(Vector2i(100, 30))
		camera.position = mk_kum + Vector3(-6.0, 6.0, 9.0)
		camera.look_at(mk_kum)
		await get_tree().create_timer(0.7).timeout
		_snap(save_path.replace(".png", "_maske_kumsal.png"))
		_cam_locked = false
	await _run_tree_frames(save_path)
	await _run_kesif_frames(save_path)  # Bolum 16: tas/uyuyan/sis/damar
	await _run_su_frames(save_path)  # SU V1: golet/gece-isik/hendek/kanal
	await _run_cim_frames(save_path)  # CIM V1: ruzgar/ezme/gece uyum
	# CLICKTEST EN BASTA (180sn oyun sinirina takilmasin diye): GERCEK
	# dokunus simulasyonu — "menuler acilmiyor/kapanmiyor" sinifi cihaz
	# hatalarini CI'da yakalar.
	await _run_click_tests(save_path)
	# TESHIS: baltayi elde YAKINDAN gor (kavrama ayari icin). Kamerayi el
	# hizasina, yandan yaklastir; sonra normal kareler icin geri alinir.
	_cam_locked = true
	player.debug_hand_orientation()  # HANDDBG: el kemigi yonelimi (log)
	var _hand_focus := player.position + Vector3(0.0, 0.75, 0.0)
	# Baltayi 4 acidan yakin cek (on/sag/arka/sol) -> ele oturma teshisi
	var _angs := [["_balta", Vector3(0, 0.6, 2.3)], ["_balta_sag", Vector3(2.3, 0.6, 0.2)],
			["_balta_arka", Vector3(0.2, 0.9, -2.3)], ["_balta_sol", Vector3(-2.3, 0.6, 0.2)]]
	for a in _angs:
		camera.position = player.position + a[1]
		camera.look_at(_hand_focus)
		await get_tree().create_timer(0.35).timeout
		_snap(save_path.replace(".png", String(a[0]) + ".png"))
	# Yeni GLB aletler: kazma + kurek yakin cekim (on + sag).
	# HUD (hotbar) alet ucunu kapatiyordu -> cekim boyunca gizle.
	hud.visible = false
	for tf in [["kazma", "_kazma"], ["kurek", "_kurek"],
			["sulama_kabi", "_sulamakabi"], ["capa", "_capa"]]:
		player.set_held_tool(String(tf[0]))
		player.set_grip_marker(true)  # tutus isareti (set_held_tool temizler -> sonra tak)
		await get_tree().create_timer(0.4).timeout
		camera.position = player.position + Vector3(0, 0.6, 2.3)
		camera.look_at(_hand_focus)
		await get_tree().create_timer(0.3).timeout
		if String(tf[0]) == "sulama_kabi":
			# tam cekim aninda baglanti bazi (rot_deg dunya hedefinden hesaplanir)
			player.debug_attach_world("res://docs/screens/attachdbg.txt")
		_snap(save_path.replace(".png", String(tf[1]) + "_on.png"))
		camera.position = player.position + Vector3(2.3, 0.6, 0.2)
		camera.look_at(_hand_focus)
		await get_tree().create_timer(0.3).timeout
		_snap(save_path.replace(".png", String(tf[1]) + "_sag.png"))
	player.set_held_tool("balta")
	# Tezgah GLB yakin cekim: oyuncunun onune koy
	var tzc := _player_cell() + Vector2i(0, 2)
	if _ground_char.get(tzc, "") in [".", "d", "s"] and not _objects.has(tzc) \
			and not _placed.has(tzc):
		_set_placed(tzc, "tezgah")
	camera.position = Vector3(float(tzc.x) + 0.5 - 1.6, 1.5, float(tzc.y) + 0.5 + 1.6)
	camera.look_at(Vector3(float(tzc.x) + 0.5, 0.35, float(tzc.y) + 0.5))
	await get_tree().create_timer(0.5).timeout
	_snap(save_path.replace(".png", "_tezgah.png"))
	player.set_grip_marker(false)
	# FARMTEST (tarim-3d): tarla ac -> ek -> sula -> 2 gun -> olgun ->
	# hasat -> bos tarla 3 gunde cime doner. Safak dogrudan cagrilir.
	var fc2 := _player_cell() + Vector2i(-3, 2)
	var f_till := _till_valid(fc2) and Farming.till_cell(fc2)
	Inventory.add_item("tohum", 1)
	_try_plant(fc2)
	var f_ekildi: bool = String(Farming.plots.get(fc2, {}).get("crop_id", "")) == "berry_bush"
	Farming.fill_watering_can()
	Farming.water(fc2)
	_on_farm_dawn()  # gun 1: evre 0->1
	Farming.water(fc2)
	_on_farm_dawn()  # gun 2: evre 1->2 (olgun)
	var f_olgun: bool = Farming.can_harvest(fc2)
	_try_crop_harvest(fc2)
	var f_bos: bool = String(Farming.plots.get(fc2, {}).get("crop_id", "x")) == ""
	for fdk in 3:
		_on_farm_dawn()  # bakimsiz tarla cime donsun
	var f_cim: bool = not Farming.plots.has(fc2)
	# kayit cifti: to/from sonrasi birebir mi (hizli kontrol)
	Farming.till_cell(fc2)
	var f_save := Farming.to_save_data()
	Farming.from_save_data(f_save)
	var f_kayit: bool = Farming.plots.has(fc2)
	print("FARMTEST: till=%s ekildi=%s olgun=%s hasat_bos=%s cim=%s kayit=%s" % [
		str(f_till), str(f_ekildi), str(f_olgun), str(f_bos), str(f_cim), str(f_kayit)])
	# Gorsel kare: 3 evre yan yana (_tarim.png)
	var fbase := _player_cell() + Vector2i(2, 2)
	for fk in 3:
		var fcell := fbase + Vector2i(fk, 0)
		if _till_valid(fcell):
			Farming.till_cell(fcell)
			Farming.plant(fcell, "berry_bush")
			Farming.plots[fcell].stage = fk
			_on_plot_changed(fcell)
	Farming.water_free(fbase)  # islak zemin rengi de karede gorunsun
	camera.position = Vector3(float(fbase.x) + 1.5 - 1.2, 1.7, float(fbase.y) + 0.5 + 2.2)
	camera.look_at(Vector3(float(fbase.x) + 1.5, 0.15, float(fbase.y) + 0.5))
	await get_tree().create_timer(0.5).timeout
	_snap(save_path.replace(".png", "_tarim.png"))
	# YENI OZELLIK KARELERI ONE ALINDI: tur CI zaman butcesini asinca
	# sondaki kareler hic cekilmiyordu (agac-kesim turunda olculdu —
	# kesim kareleri bos kaldi). Yeni is her zaman butcenin basinda.
	await _run_fell_frames(save_path)
	await _run_fence_frames(save_path)
	await _run_road_test(save_path)
	await _run_camp_test(save_path)
	await _run_env_showcase(save_path)
	await _run_perf_probe(save_path)
	await _run_night_test(save_path)
	hud.visible = true
	# GRIP PANELI karesi: yeni "ekran yonu" satiri eklendi; panelin ekrandan
	# tasmadigini gormek icin (daha once Ayarlar'da tam bu hata yasandi).
	player.set_held_tool("kurek")
	hud._on_grip_tuner_toggled(true)
	await get_tree().create_timer(0.4).timeout
	_snap(save_path.replace(".png", "_grip_panel.png"))
	hud._on_grip_tuner_toggled(false)
	player.set_held_tool("balta")
	# Ikinci kare: kusbakisi tum ada (teshis icin)
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
	_run_creature_selftest()     # YARATIK: varlik + take_hit + oz + melee
	_run_save_load_selftest()
	get_tree().quit()

## YOL BULMA TESTI (Asama 2) — kare gerektirmez, hizli katmanda kosar.
## Uc sey sinaniyor:
##  1) Bos alanda yol en kisa (Manhattan) uzunlukta mi?
##  2) Araya DUVAR orunce yaratik DOLASIYOR mu (yol duvardan gecmiyor,
##     uzunluk artiyor)?
##  3) Dolasmak cok uzunsa KIRIYOR mu (yol duvarin ustunden geciyor)?
## Ucuncusu kritik: "kir ya da dolas" karari ayri bir mantik degil,
## maliyet karsilastirmasinin sonucu — testi de oyle yaziyoruz.
func _run_ai_path_test() -> void:
	var a := Vector2i(20, 20)
	var b := Vector2i(28, 20)
	# 1) Bos alan: hucreleri temizle
	for y in range(18, 23):
		for x in range(19, 30):
			_solid_cells.erase(Vector2i(x, y))
			_objects.erase(Vector2i(x, y))
			_placed.erase(Vector2i(x, y))
	var p1 := CreatureAI.find_path(self, a, b)
	var duz_ok: bool = p1.size() == 8

	# 2) KISA duvar: dolasmak ucuz -> yol duvardan GECMEMELI
	for y in range(19, 22):
		var c := Vector2i(24, y)
		_objects[c] = "#"
		_solid_cells[c] = true
	var p2 := CreatureAI.find_path(self, a, b)
	var kisa_duvar_gecti := false
	for c: Vector2i in p2:
		if _objects.has(c):
			kisa_duvar_gecti = true
	var dolasti: bool = not kisa_duvar_gecti and p2.size() > p1.size()

	# 3) UZUN duvar: dolasmak pahali -> yol duvari KIRMALI
	for y in range(5, 40):
		var c2 := Vector2i(24, y)
		_objects[c2] = "#"
		_solid_cells[c2] = true
	var p3 := CreatureAI.find_path(self, a, b)
	var kirdi := false
	for c3: Vector2i in p3:
		if _objects.has(c3):
			kirdi = true

	# Temizlik: test dunyayi bozmasin
	for y in range(5, 40):
		var c4 := Vector2i(24, y)
		_objects.erase(c4)
		_solid_cells.erase(c4)

	var line := ("AITEST: duz=%d/8 (%s) kisa_duvar=%d dolasti=%s "
			+ "uzun_duvar=%d kirdi=%s") % [
		p1.size(), str(duz_ok), p2.size(), str(dolasti), p3.size(), str(kirdi)]
	print(line)
	if not duz_ok:
		push_error("AI: bos alanda yol en kisa degil")
	if not dolasti:
		push_error("AI: kisa duvari dolasmasi gerekirdi")
	if not kirdi:
		push_error("AI: uzun duvari kirmasi gerekirdi")

## SU RENK TESTI — kirmizi bug'in tekrarini yakalamak icin.
## Bug sozdizimi hatasi DEGILDI: mesh yazici ile shader'in sozlesmesi
## ayrisinca kod parse-temiz kaldi ama ekran cop cizdi. O yuzden burada
## sozdizimi degil DEGER kontrol ediliyor: her bantta beklenen renk
## uretiliyor mu, ve kirmizi kanal yesil/maviyi geciyor mu (gecerse
## "derinlik R kanalina yaziliyor" hatasi geri gelmis demektir).
func _run_water_color_test() -> void:
	var ornek := [
		{"ad": "kopuk", "d": 0.03},
		{"ad": "sig", "d": 0.14},
		{"ad": "orta", "d": 0.35},
		{"ad": "derin", "d": 0.90},
	]
	var satir := "WATERCOLORTEST:"
	var kirmizi_baskin := false
	for e: Dictionary in ornek:
		var c: Color
		if DigWaterVisual.SU_SHADER_V1:
			# v1 SOZLESME: vertex COLOR artik VERIDIR (r=derinlik!) —
			# kirmizi-baskinlik EKRAN rengiyle olculur: shader bant
			# hesabinin CPU replikasi (v1_band_color). Encoder + replika
			# + shader tek sozlesme; biri kayarsa bu satir kirmizi yanar.
			var enc := DigWaterVisual.v1_encode(float(e["d"]))
			if enc.g >= DigWaterVisual.V1_FOAM_ESIK:
				c = DigWaterVisual.V1_FOAM_COLOR
				c.a = 1.0
			else:
				c = DigWaterVisual.v1_band_color(enc.r)
				c.a = lerpf(DigWaterVisual.V1_ALPHA_SIG,
						DigWaterVisual.V1_ALPHA_DERIN, enc.r)
		else:
			c = _water_rgba(float(e["d"]), 10.0, 10.0)
		satir += " %s(%.2fm)=#%s a=%.2f" % [
			String(e["ad"]), float(e["d"]), c.to_html(false), c.a]
		# Su MAVI/TURKUAZ ailesinde: kirmizi asla mavinin onune gecmemeli
		if c.r > c.b + 0.02:
			kirmizi_baskin = true
	satir += " kirmizi_baskin=%s v1=%s" % [str(kirmizi_baskin),
			str(DigWaterVisual.SU_SHADER_V1)]
	print(satir)
	if kirmizi_baskin:
		push_error("SU RENGI BOZUK: kirmizi kanal maviyi geciyor")

## YARATIK TIPLERI TESTI — "cesitlilik" tek bir veri tablosuna baglandi;
## test de o tabloyu dogruluyor:
##  1) Her tipin alani tam mi, GLB dosyasi var mi (yoksa proseduerel
##     govde cizilir — eksik model HATA DEGIL, raporlanacak durum).
##  2) YETENEK yol bulmaya GERCEKTEN ulasiyor mu: ayni engelde yuzucu
##     suyu geciyor mu, tirmanici duvari asiyor mu, normal geciyor mu.
##     Bu onemli: yetenekleri tabloya yazmak kolay, davranisa BAGLAMAK
##     zor — kopukluk sessizce olusur.
##  3) Dalga karisimi: gece 1 sadece normal, acildigi gece yeni tip
##     mutlaka var, ozel oran yariyi gecmiyor.
func _run_creature_type_test() -> void:
	var eksik_glb: Array = []
	var alan_eksik: Array = []
	for t: String in CreatureBalance.TYPES:
		var d: Dictionary = CreatureBalance.TYPES[t]
		for k: String in ["hp", "speed", "damage", "essence", "first_night", "glb"]:
			if not d.has(k):
				alan_eksik.append("%s.%s" % [t, k])
		# Modeller GitHub web arayuzunden cogunlukla assets/models/test/
		# altina yukleniyor; creature.gd ikisine de bakiyor, test de oyle.
		var g := String(d.get("glb", ""))
		var alt := "res://assets/models/test/" + g.get_file()
		if g == "" or not (ResourceLoader.exists(g) or ResourceLoader.exists(alt)):
			eksik_glb.append(t)

	# 2) Yetenek -> yol bulma baglantisi. Sag tarafa gecmek icin TEK
	# kapi birakiliyor: kapi su ise yalniz yuzucu, duvar ise tirmanici
	# ucuz gecer.
	var a := Vector2i(40, 40)
	var b := Vector2i(46, 40)
	for y in range(37, 44):
		for x in range(39, 48):
			var c := Vector2i(x, y)
			_solid_cells.erase(c)
			_objects.erase(c)
			_placed.erase(c)
			_depth.erase(c)
			_water_level.erase(c)
	# Tam boydan SU seridi (dolasilamaz: ya gecilir ya gecilmez).
	# Sutunun eski hali saklaniyor: test dunyayi kalici bozmasin
	# (ayni oturumda kayit/yukleme testi de kosuyor).
	var eski_kati: Dictionary = {}
	var eski_derinlik: Dictionary = {}
	var eski_su: Dictionary = {}
	for y in range(0, _map_h):
		var wc := Vector2i(43, y)
		eski_kati[wc] = _solid_cells.has(wc)
		eski_derinlik[wc] = _depth.get(wc, 0)
		eski_su[wc] = _water_level.get(wc, 0.0)
		_solid_cells[wc] = true
		_depth[wc] = 2
		_water_level[wc] = 2.0
	# Butce dolunca A* KISMI yol dondugu icin "yol uzunlugu" yeterli
	# olcut degil: hedefe VARDI MI diye bakiliyor.
	var pn: Array = CreatureAI.find_path(self, a, b, {})
	var py: Array = CreatureAI.find_path(self, a, b, {"swim": true})
	var su_normal: int = pn.size()
	var su_yuzucu: int = py.size()
	var yuzucu_gecti: bool = not py.is_empty() and py[py.size() - 1] == b
	var normal_gecemedi: bool = pn.is_empty() or pn[pn.size() - 1] != b
	for y in range(0, _map_h):
		var wc2 := Vector2i(43, y)
		if not bool(eski_kati[wc2]):
			_solid_cells.erase(wc2)
		if int(eski_derinlik[wc2]) > 0:
			_depth[wc2] = int(eski_derinlik[wc2])
		else:
			_depth.erase(wc2)
		if float(eski_su[wc2]) > 0.0:
			_water_level[wc2] = float(eski_su[wc2])
		else:
			_water_level.erase(wc2)
	# KISA duvar (3 hucre): dolasmak MUMKUN. Normal dolasir (uzun yol),
	# tirmanici ustunden gecer (kisa yol). Fark yolun UZUNLUGUNDA
	# gorunur — yetenek gercekten maliyeti degistiriyor mu, olcut bu.
	for y in range(39, 42):
		var dc := Vector2i(43, y)
		_solid_cells[dc] = true
		_placed[dc] = "duvar"
	var duvar_normal: int = CreatureAI.find_path(self, a, b, {}).size()
	var duvar_tirman: int = CreatureAI.find_path(self, a, b, {"climb": true}).size()
	var ikisi_de_gecti: bool = duvar_normal > 0 and duvar_tirman > 0
	for y in range(39, 42):
		var dc2 := Vector2i(43, y)
		_solid_cells.erase(dc2)
		_placed.erase(dc2)

	# 3) Dalga karisimi
	var g1: Array = CreatureBalance.wave_mix(1, 6)
	var g1_hepsi_normal := true
	for t1: String in g1:
		if t1 != "normal":
			g1_hepsi_normal = false
	var karisim_ok := true
	for gece: int in [4, 5, 7, 10]:
		var say: int = CreatureBalance.min_wave_count(gece)
		var mix: Array = CreatureBalance.wave_mix(gece, say)
		var ozel := 0
		var yeni_var := false
		for t2: String in mix:
			if t2 != "normal":
				ozel += 1
			if int(CreatureBalance.stat(t2, "first_night", 1)) == gece:
				yeni_var = true
		if not yeni_var:
			karisim_ok = false
		if float(ozel) > float(say) * CreatureBalance.MIX_SPECIAL_MAX:
			karisim_ok = false

	print(("YARATIKTIP: tip=%d alan_eksik=%s glb_eksik=%s "
			+ "su(normal=%d yuzucu=%d) duvar(normal=%d tirmanici=%d) "
			+ "gece1_normal=%s karisim_ok=%s") % [
		CreatureBalance.TYPES.size(), str(alan_eksik), str(eksik_glb),
		su_normal, su_yuzucu, duvar_normal, duvar_tirman,
		str(g1_hepsi_normal), str(karisim_ok)])
	if not alan_eksik.is_empty():
		push_error("YARATIK TABLOSU EKSIK: %s" % str(alan_eksik))
	if not yuzucu_gecti or not normal_gecemedi:
		push_error("YUZME yetenegi yol bulmaya baglanmamis")
	if not ikisi_de_gecti or duvar_tirman >= duvar_normal:
		push_error("TIRMANMA yetenegi yol bulmaya baglanmamis")
	if not g1_hepsi_normal or not karisim_ok:
		push_error("DALGA KARISIMI kurallara uymuyor")

## YARATIGA VURABILME TESTI — oyunda bildirilen hatanin bekcisi.
## HATA: yumruk ve balta ToolProfiles'ta is_weapon=false oldugu icin
## saldiri butonu hic cikmiyordu, ana buton da yaratigi hedef saymiyordu;
## yani elde silah yoksa yaratiga vurmanin YOLU YOKTU. CREATURETEST bunu
## kacirmisti cunku elimize "kilic" verip DOGRUDAN _apply_hitbox
## cagiriyordu — oyuncunun gercekte bastigi yolu (hedef secimi) hic
## denemiyordu. Test artik o yoldan geciyor.
func _run_creature_combat_test() -> void:
	_clear_creatures()
	var pc := _player_cell()
	player.facing = Vector2(0, 1)
	var sonuc: Array = []
	var hepsi_vurdu := true
	for elde: String in ["", "balta", "kazma", "sopa"]:
		_clear_creatures()
		_held_item = elde
		var cr = spawn_creature(pc + Vector2i(0, 1), "normal")
		var hp0: int = cr.hp
		# Oyuncunun bastigi yol: hedef sec -> eylemi uygula.
		var t := _acquire_target()
		var hedef_ok: bool = String(t["type"]) == "creature"
		if hedef_ok:
			_apply_strike(String(t["kind"]), t["cell"])
		var verilen: int = hp0 - int(cr.hp)
		sonuc.append("%s(hedef=%s hasar=%d)" % [
			("yumruk" if elde == "" else elde), str(hedef_ok), verilen])
		if not hedef_ok or verilen <= 0:
			hepsi_vurdu = false
	# USTUNE BINEN yaratik: temas menzili 0.9 m, yani saldiran yaratik
	# senin hucrende olabilir. Komsu tarama onu kacirirdi.
	_clear_creatures()
	_held_item = ""
	var cr2 = spawn_creature(pc, "normal")
	var t2 := _acquire_target()
	var ustundeki_ok: bool = String(t2["type"]) == "creature"
	_clear_creatures()

	# OCAK YOKSA hedef: kamp merkezi (oyuncu DEGIL).
	var eski_ocak := _hearth_cell
	_hearth_cell = Vector2i(-999, -999)
	var ocaksiz_hedef := _hearth_cell
	if ocaksiz_hedef == Vector2i(-999, -999):
		ocaksiz_hedef = _camp_at("ocak")
	var kamp_hedefi: bool = ocaksiz_hedef != Vector2i(-999, -999)
	_hearth_cell = eski_ocak

	print("SAVASTEST: %s ustundeki=%s ocaksiz_kamp_hedefi=%s" % [
		" ".join(sonuc), str(ustundeki_ok), str(kamp_hedefi)])
	if not hepsi_vurdu:
		push_error("YARATIGA VURULAMIYOR: elde silah yokken hedef secilmiyor")
	if not ustundeki_ok:
		push_error("Ustune binen yaratik hedeflenemiyor")
	if not kamp_hedefi:
		push_error("Ocak yokken yaratiklarin gidecegi yer tanimsiz")

## YOL SERPINTISI OLCU TESTI — "yukseklik pazarliksiz" sartinin SAYISAL
## kaniti. Ekran goruntusu gozle bakmak icin; bu test yassilastirmayi
## rakamla yakalar. Modelin kalinligi olculur, dunya olcegine cevrilir ve
## zeminden ne kadar disarida kaldigi yazilir.
func _run_road_scatter_test() -> void:
	var mesh := _road_scatter_mesh()
	if mesh == null:
		print("SCATTERTEST: model YOK (%s)" % RoadScatter.MODEL_PATH)
		push_error("stone_scatter_a.glb bulunamadi")
		return
	var aabb := mesh.get_aabb()
	var span: float = maxf(aabb.size.x, aabb.size.y) if RoadScatter.MODEL_Z_UP \
			else maxf(aabb.size.x, aabb.size.z)
	var k: float = RoadScatter.CELL_SPAN / span
	var kalinlik: float = (aabb.size.z if RoadScatter.MODEL_Z_UP else aabb.size.y) * k
	var disarida: float = RoadScatter.TOP_ABOVE
	var gomulu: float = kalinlik - disarida
	# Z-up dogrulamasi: en INCE eksen hangisi? Model Z-up ise Z olmali.
	var en_ince := "x"
	if aabb.size.y < aabb.size.x and aabb.size.y <= aabb.size.z:
		en_ince = "y"
	elif aabb.size.z < aabb.size.x and aabb.size.z <= aabb.size.y:
		en_ince = "z"
	var z_up_dogru: bool = (en_ince == "z") == RoadScatter.MODEL_Z_UP
	print(("SCATTERTEST: aabb=%.3fx%.3fx%.3f en_ince=%s z_up_ayari=%s(%s) "
			+ "k=%.3f kalinlik=%.3fm disarida=%.3fm gomulu=%.3fm golge=%s") % [
		aabb.size.x, aabb.size.y, aabb.size.z, en_ince,
		str(RoadScatter.MODEL_Z_UP), str(z_up_dogru), k, kalinlik,
		disarida, gomulu, str(RoadScatter.CAST_SHADOW)])
	if not z_up_dogru:
		push_error("Model yonu yanlis: MODEL_Z_UP ile olculen ince eksen uyusmuyor")
	# Yassilastirma yasagi: kalinlik olcekten sonra da korunmali.
	if kalinlik < 0.05:
		push_error("Tas kalinligi 5 cm'nin altina dustu — ezilmis leke riski")
	if disarida < 0.015:
		push_error("Taslar zemine gomuldu (disarida < 1.5 cm)")

## KAMP PREFAB TESTI — "sahne -> oyun" hattinin bekcisi.
##  1) Prefab yukleniyor mu, beklenen ogeler tam mi (adetleriyle).
##  2) Kayit defteri (_camp_items) sahnedeki dugum konumlarindan mi
##     geliyor — yani F5 ESDEGERI: dugumu BELLEKTE tasiyip kaydin
##     degistigini dogruluyoruz. Editorde tasi-F5 akisinin kanitladigi
##     sey tam olarak bu (konum sahneden okunuyor, koddan degil).
func _run_camp_prefab_test() -> void:
	var bekle := {"ocak": 1, "hut": 1, "well": 1, "masa": 1,
			"sandik": 1, "kabak": 1, "mesale": 4, "tarla": 4}
	var eksik: Array = []
	for id: String in bekle:
		var n: int = _camp_items.get(id, []).size()
		if n != int(bekle[id]):
			eksik.append("%s=%d/%d" % [id, n, int(bekle[id])])
	# F5 esdegeri: sahneyi ac, DevrikSandik'i +2 hucre tasi, kaydi
	# yeniden topla — off (2,0) kaymis olmali.
	var tasima_ok := false
	if ResourceLoader.exists(CAMP_SCENE):
		var root: Node3D = (load(CAMP_SCENE) as PackedScene).instantiate()
		var once: Dictionary = {}
		_camp_collect(root, root, once)
		var eski: Vector2i = Vector2i(once.get("sandik", [{}])[0].get("off", Vector2i.ZERO))
		for ch in root.get_children():
			if ch is Node3D and ch.has_meta("oge") 					and String(ch.get_meta("oge")) == "sandik":
				(ch as Node3D).position.x += 2.0
		var sonra: Dictionary = {}
		_camp_collect(root, root, sonra)
		var yeni: Vector2i = Vector2i(sonra.get("sandik", [{}])[0].get("off", Vector2i.ZERO))
		tasima_ok = (yeni - eski) == Vector2i(2, 0)
		root.free()
	print("PREFABTEST: oge_eksik=%s tasima_yansidi=%s spawn=%s hut=%s" % [
		str(eksik), str(tasima_ok), str(_spawn_cell), str(_camp_at("hut"))])
	if not eksik.is_empty():
		push_error("KAMP PREFABI EKSIK: %s" % str(eksik))
	if not tasima_ok:
		push_error("Prefabta tasinan dugum kayda yansimadi (sahne->oyun hatti kopuk)")

## MASKTEST — "maskede gol boya -> oyunda gol orada mi" zincirinin
## otomatik hali. Dunya durumuna DOKUNMAZ: uretec + maske gecisi saf
## fonksiyon oldugu icin dogrudan cagrilir.
##  1) Ornekle: 128x128 cayir maskesi + (90..110, 20..40) SU blobu.
##  2) Blobun ICI (warp payi kadar iceri cekilmis) su olmali.
##  3) Blobtan uzak bir nokta uretecin dedigi gibi kalmali (fallback).
##  4) ORGANIKLIK: keskin cizilen kenar birebir kopyalanMAMALI —
##     kenar seridinde en az bir hucre kare sinirdan sapmali.
func _run_mask_test() -> void:
	var rows: Array[String] = MapGen.generate(MapBalance.SEED_DEFAULT)
	var n := rows.size()
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(MapMask.COLORS["cayir"]))
	for y in range(20, 41):
		for x in range(90, 111):
			img.set_pixel(x, y, Color(MapMask.COLORS["su"]))
	var rows2 := MapMask.apply_img(rows, img, MapBalance.SEED_DEFAULT)
	# 2) blob ici su mu (kenardan 3 hucre iceri: warp payi)
	var ic_su := 0
	var ic_top := 0
	for y in range(24, 37):
		for x in range(94, 107):
			ic_top += 1
			if rows2[y][x] == "~":
				ic_su += 1
	var ic_oran := float(ic_su) / maxf(1.0, float(ic_top))
	# 3) uzak nokta: uretecin dedigi kalmis mi (cayir kurallari yumusak;
	# birebir esitlik yerine SU OLMAMASI ve serbest siniflarin
	# degismemesi olculuyor)
	var uzak_su := 0
	for y in range(80, 100):
		for x in range(20, 40):
			if rows2[y][x] == "~" and rows[y][x] != "~":
				uzak_su += 1
	# 4) organiklik: blob kenar seridinde (x=88..92 dikey serit) sonuc,
	# keskin kare sinirdan en az bir hucrede sapmali
	var sapma := 0
	for y in range(20, 41):
		for x in range(88, 93):
			var kare_ici: bool = x >= 90
			var su_mu: bool = rows2[y][x] == "~"
			if su_mu != kare_ici:
				sapma += 1
	# fallback: maske yokken apply dokunmuyor mu (dosya repoda yok)
	var ayni := true
	var rows3 := MapMask.apply(rows, MapBalance.SEED_DEFAULT)
	for y in n:
		if rows3[y] != rows[y]:
			ayni = false
			break
	var mask_var := ResourceLoader.exists(MapMask.PATH)
	# --- v2: KARA ZORLAMA — golun ustune cayir boya, su GITMELI ---
	# (silginin gidermedigi bug: silgi=serbest -> uretec golu geri koyar;
	# cozum acik kara sinifi. Testte golu uretecten buluyoruz.)
	var gol := Vector2i(-1, -1)
	for y in range(4, n - 4):
		if gol.x != -1:
			break
		for x in range(4, n - 4):
			if rows[y][x] == "~":
				gol = Vector2i(x, y)
				break
	var img2 := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in range(maxi(1, gol.y - 8), mini(n - 1, gol.y + 9)):
		for x in range(maxi(1, gol.x - 8), mini(n - 1, gol.x + 9)):
			img2.set_pixel(x, y, Color(MapMask.COLORS["cayir"]))
	var rows_k := MapMask.apply_img(rows, img2, MapBalance.SEED_DEFAULT)
	var kalan_su := 0
	for y in range(maxi(1, gol.y - 4), mini(n - 1, gol.y + 5)):
		for x in range(maxi(1, gol.x - 4), mini(n - 1, gol.x + 5)):
			if rows_k[y][x] == "~":
				kalan_su += 1
	# --- v2: OTOMATIK KIYI BANDI — maske golunun cevresinde kum ---
	var bant_kum := 0
	for y in range(16, 45):
		for x in range(86, 115):
			if rows2[y][x] == "s" and rows[y][x] != "s":
				bant_kum += 1
	# --- v2: KUM sinifi elle kumsal boyar ---
	var img3 := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in range(50, 61):
		for x in range(8, 19):
			img3.set_pixel(x, y, Color(MapMask.COLORS["kum"]))
	var rows_s := MapMask.apply_img(rows, img3, MapBalance.SEED_DEFAULT)
	var elle_kum := 0
	for y in range(53, 58):
		for x in range(11, 16):
			if rows_s[y][x] == "s":
				elle_kum += 1
	# --- v2: YUKSEKLIK — tepe blobu "h" uretmeli, normal platoyu silmeli ---
	var himg := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in range(96, 113):
		for x in range(96, 113):
			himg.set_pixel(x, y, Color(MapMask.H_TEPE))
	# mevcut bir plato hucresi bul, ustune "normal" boya
	var plato := Vector2i(-1, -1)
	for y in range(4, n - 4):
		if plato.x != -1:
			break
		for x in range(4, n - 4):
			if rows[y][x] == "h":
				plato = Vector2i(x, y)
				break
	if plato.x != -1:
		for y in range(maxi(1, plato.y - 5), mini(n - 1, plato.y + 6)):
			for x in range(maxi(1, plato.x - 5), mini(n - 1, plato.x + 6)):
				himg.set_pixel(x, y, Color(MapMask.H_NORMAL))
	var rows_h := MapMask.apply_height_img(rows, himg, MapBalance.SEED_DEFAULT)
	var tepe_h := 0
	for y in range(100, 109):
		for x in range(100, 109):
			if rows_h[y][x] == "h":
				tepe_h += 1
	var plato_kaldi := false
	if plato.x != -1:
		for y in range(maxi(1, plato.y - 2), mini(n - 1, plato.y + 3)):
			for x in range(maxi(1, plato.x - 2), mini(n - 1, plato.x + 3)):
				if rows_h[y][x] == "h":
					plato_kaldi = true

	print(("MASKTEST: ic_su=%.0f%% uzak_yeni_su=%d kenar_sapma=%d "
			+ "fallback_ayni=%s(mask_dosyasi=%s) cayir_sonrasi_su=%d "
			+ "bant_kum=%d elle_kum=%d/25 tepe_h=%d/81 plato_duzeldi=%s") % [
		ic_oran * 100.0, uzak_su, sapma, str(ayni), str(mask_var),
		kalan_su, bant_kum, elle_kum, tepe_h, str(not plato_kaldi)])
	if ic_oran < 0.9:
		push_error("MASKE: boyanan gol oyuna gecmedi (ic %.0f%%)" % (ic_oran * 100.0))
	if uzak_su > 0:
		push_error("MASKE: boyanmayan bolgeye su sizdi")
	if sapma == 0:
		push_error("MASKE: kenar birebir kopyalandi — organiklik calismiyor")
	if not mask_var and not ayni:
		push_error("MASKE: dosya yokken fallback davranisi bozuk")
	if kalan_su > 0:
		push_error("MASKE v2: cayir golu KARAYA ceviremedi (su silme bugu geri)")
	if bant_kum < 8:
		push_error("MASKE v2: otomatik kiyi kum bandi olusmadi")
	if elle_kum < 20:
		push_error("MASKE v2: kum sinifi kumsal boyamiyor")
	if tepe_h < 60:
		push_error("MASKE v2: tepe kademesi plato uretmedi")
	if plato.x != -1 and plato_kaldi:
		push_error("MASKE v2: normal kademesi mevcut platoyu duzlemedi")

## AGAC SETI TESTI (agac-degisim): yeni modeller devrede mi, karisim
## 60/40 mi, poligon butcesi ne, MultiMesh dogru mu.
func _run_tree_test() -> void:
	var dosyalar: Array = []
	for e: Dictionary in TREE_SET:
		dosyalar.append("%s=%s" % [String(e["path"]).get_file(),
				"VAR" if _tree_yol_coz(String(e["path"])) != "" else "YOK"])
	var pool := _tree_set_pool()
	var ucgen: Array = []
	for e: Dictionary in pool:
		var m: Mesh = e["mesh"]
		ucgen.append(m.get_faces().size() / 3)
	# Gercek haritadaki dagilim (agirlikli secimin kaniti)
	var dag: Array = []
	var toplam_ornek := 0
	for idx in _tree_group_counts:
		toplam_ornek += int(_tree_group_counts[idx])
	for idx in _tree_group_counts:
		dag.append("%s=%d(%%%.0f)" % [str(idx), int(_tree_group_counts[idx]),
				float(_tree_group_counts[idx]) / maxf(1.0, float(toplam_ornek)) * 100.0])
	var yeni_set_aktif: bool = _tree_yol_coz(String(TREE_SET[0]["path"])) != "" \
			or _tree_yol_coz(String(TREE_SET[1]["path"])) != ""
	print("TREETEST: %s yeni_set=%s varyant=%d ucgen=%s dagilim=[%s] ornek=%d" % [
		" ".join(dosyalar), str(yeni_set_aktif), pool.size(), str(ucgen),
		" ".join(dag), toplam_ornek])
	if pool.is_empty():
		push_error("AGAC: havuz bos — fallback da yuklenemedi")
	if toplam_ornek == 0:
		push_error("AGAC: haritada hic agac cizilmedi")
	# Karisim kontrolu artik VERIDEN: her varyantin payi TREE_SET
	# agirligindan +-10 puan bandinda olmali (eski 60/40 sabitti;
	# agac-kesim turunde set 45/35/20'ye genisledi).
	if pool.size() == TREE_SET.size():
		var toplam_agirlik := 0
		for e: Dictionary in TREE_SET:
			toplam_agirlik += int(e["agirlik"])
		for i in TREE_SET.size():
			var pay: float = float(_tree_group_counts.get(i, 0)) \
					/ maxf(1.0, float(toplam_ornek))
			var hedef: float = float(TREE_SET[i]["agirlik"]) \
					/ maxf(1.0, float(toplam_agirlik))
			if absf(pay - hedef) > 0.10:
				push_error("AGAC: karisim veriden sapti (varyant %d %%%.0f, hedef %%%.0f)" % [
						i, pay * 100.0, hedef * 100.0])

## AGAC KARELERI: orman geneli + tek agac yakin, gunduz + gece.
func _run_tree_frames(save_path: String) -> void:
	# En yogun orman hucresi (komsu sayisi max) ve tek basina bir agac
	var yogun := Vector2i(-999, -999)
	var yogun_n := -1
	var tek := Vector2i(-999, -999)
	for c: Vector2i in _objects:
		if _objects[c] != "T":
			continue
		var nn := _tree_neighbor_count(c)
		if nn > yogun_n:
			yogun_n = nn
			yogun = c
		if nn == 0 and tek == Vector2i(-999, -999):
			tek = c
	if yogun == Vector2i(-999, -999):
		return
	if tek == Vector2i(-999, -999):
		tek = yogun
	_cam_locked = true
	var op := _cell_center(yogun)
	camera.position = op + Vector3(-6.0, 5.5, 8.0)
	camera.look_at(op + Vector3(0, 1.2, 0))
	await get_tree().create_timer(0.7).timeout
	_snap(save_path.replace(".png", "_agac_orman.png"))
	var tp := _cell_center(tek)
	camera.position = tp + Vector3(-2.2, 2.2, 3.2)
	camera.look_at(tp + Vector3(0, 1.4, 0))
	await get_tree().create_timer(0.7).timeout
	_snap(save_path.replace(".png", "_agac_tek.png"))
	DayNight.jump_to_night()
	_clear_creatures()
	await get_tree().create_timer(0.9).timeout
	_snap(save_path.replace(".png", "_agac_tek_gece.png"))
	camera.position = op + Vector3(-6.0, 5.5, 8.0)
	camera.look_at(op + Vector3(0, 1.2, 0))
	await get_tree().create_timer(0.7).timeout
	_snap(save_path.replace(".png", "_agac_orman_gece.png"))
	DayNight.jump_to_day()
	await get_tree().create_timer(0.4).timeout
	_cam_locked = false

## HIZLI KATMAN: kare almayan, beklemesiz mantik testleri. Bunlar
## --headless'te de kosar; agir gorsel akisin hicbir parcasina dokunmaz.
## Kapsam BILEREK dar: harita uretimi, kamera, zaman, muhendislik,
## yaratik, kayit/yukleme. Kazi/su/tarim/UI testleri kare alma ve
## bekleme ile ic ice oldugu icin AGIR katmanda kaldi (bkz. RAPOR_CI).
func _run_fast_tests() -> void:
	_run_ai_path_test()
	_run_creature_type_test()
	_run_creature_combat_test()
	_run_road_scatter_test()
	_run_editor_test()
	_run_camp_prefab_test()
	_run_mask_test()
	_run_tree_test()
	_run_water_color_test()
	_run_time_selftest()
	_run_muhendislik_selftest()
	_run_creature_selftest()
	_run_kesif_test()
	_run_kor_test()
	_run_sefer_test()
	_run_uyuyan_test()
	_run_uzak_test()
	_run_cim_test()
	_run_night_logic_test()
	_run_fence_test()
	_run_fell_test()
	_run_yol_test()
	_run_kesif_perf()
	_run_save_load_selftest()
	print("FASTTESTS: bitti")
	get_tree().quit()

## YARATIK self-test (Asama 1): spawn -> take_hit hasar -> melee _apply_hitbox
## yaratiga ulasir -> oldur -> oz duser. Tum silahlar ayni take_hit'i kullanir.
func _run_creature_selftest() -> void:
	_clear_creatures()
	var cc := Vector2i(52, 52)
	var cr = spawn_creature(cc, "normal")
	# MODEL BAGLAMA KANITI (yaratik-gece): rig'li creature_2 gercekten mi
	# yuklendi, yurume klibi bulundu mu, boy dogru mu? Model yoksa
	# placeholder'a duser — o zaman anim bos gorunur (bilincli fallback).
	# Iskeletli modelde AABB'den boy okunamiyor (creature.gd gerekce) —
	# olcek tablodan basilir; rig'siz modelde AABB boyu olculur.
	var iskelet: bool = cr._body != null and not cr._body.find_children(
			"*", "Skeleton3D", true, false).is_empty()
	var boy: float = -1.0
	if not iskelet and cr._body != null:
		for mi: MeshInstance3D in cr._body.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh != null:
				boy = maxf(boy, mi.mesh.get_aabb().size.y \
						* mi.global_transform.basis.get_scale().y)
	print("CREATUREMODEL: anim='%s' klip_sayisi=%d iskelet=%s olcek=%.2f boy=%.2f mat=%d" % [
			cr._walk_anim,
			(cr._anim.get_animation_list().size() if cr._anim != null else 0),
			str(iskelet), float(CreatureBalance.stat("normal", "scale", 1.0)),
			boy, cr._glb_mats.size()])
	if cr._walk_anim == "" and cr._anim != null:
		push_error("CREATURE: rig var ama yurume klibi bulunamadi")
	var hp0: int = cr.hp
	cr.take_hit(3, Vector3.FORWARD)
	var dmg_ok: bool = cr.hp == hp0 - 3
	# Melee _apply_hitbox yaratiga ulasiyor mu? (oyuncuyu yaratiga baktir)
	var pc := _player_cell()
	player.facing = Vector2(0, 1)
	cr.position = _cell_center(pc + Vector2i(0, 1))
	_held_item = "kilic"
	var before2: int = cr.hp
	_apply_hitbox(pc + Vector2i(0, 1))
	var melee_ok: bool = cr.hp < before2
	# Oldur -> oz duser
	var kill_cell: Vector2i = cr.cell()
	cr.take_hit(cr.hp, Vector3.FORWARD)
	var dead_ok: bool = not cr.is_alive()
	var essence_ok: bool = _ground_item_at(kill_cell) != -1
	# Temizle (dusen oz item + yaratiklar; SAVELOAD'a temiz birak)
	var gi := _ground_item_at(kill_cell)
	if gi != -1:
		var gn = _ground_items[gi].get("node")
		if gn != null and is_instance_valid(gn):
			gn.queue_free()
		_ground_items.remove_at(gi)
	_clear_creatures()
	_held_item = ""
	print("CREATURETEST: hasar=%s melee=%s oldu=%s oz_dustu=%s ok=%s" % [
		str(dmg_ok), str(melee_ok), str(dead_ok), str(essence_ok),
		str(dmg_ok and melee_ok and dead_ok and essence_ok)])

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
	# 11.7 sulama: boruyla dolan havuz bitisik tarlayi sular (has_adjacent_water).
	var wc := Vector2i(48, 48)
	_depth[wc] = 2
	_water_level[wc] = 2.0
	_recompute_water()
	var irrig := has_adjacent_water(Vector2i(49, 48))
	_depth.erase(wc); _water_level.erase(wc); _recompute_water()
	print("IRRIGTEST: dolu_havuz_komsu_sulanir=%s" % str(irrig))
	# Kayit: muhendislik yapilari + vana durumu _structures ile round-trip.
	var vc := Vector2i(45, 45)
	_structures.place(vc, "vana", 0, 40); _structures.set_open(vc, false)
	_structures.place(Vector2i(46, 45), "merdiven", 90, 40)
	_structures.place(Vector2i(47, 45), "kazik", 0, 40)
	var sd := _structures.to_save_data()
	var sm2 = StructureManager.new()
	sm2.from_save_data(sd)
	var valve_ok: bool = String(sm2.get_inst(vc).get("id", "")) == "vana" \
			and sm2.is_open(vc) == false
	var lad_ok: bool = String(sm2.get_inst(Vector2i(46, 45)).get("id", "")) == "merdiven"
	var spk_ok: bool = String(sm2.get_inst(Vector2i(47, 45)).get("id", "")) == "kazik"
	_structures.remove(vc)
	_structures.remove(Vector2i(46, 45))
	_structures.remove(Vector2i(47, 45))
	print("SAVEMUH: vana_kapali=%s merdiven=%s kazik=%s ok=%s" % [
		str(valve_ok), str(lad_ok), str(spk_ok),
		str(valve_ok and lad_ok and spk_ok)])

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
	_clear_fences()
	for n in _placed_nodes.values():
		n.queue_free()
	_placed_nodes.clear(); _clear_chests(); _objects.clear()
	Farming.from_save_data({})  # tarim-3d: yeni oyunda tarlalar sifirlanir
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
	if _perf_on:
		_update_perf_overlay(delta)
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
	# CIM SHADER V1: oyuncu ezmesi — tek uniform, her kare (sozlesme).
	# quality 0'da guncelleme de atlanir (_cim_ezme_on bayragi).
	if _cim_ezme_on and _cim_mat != null:
		_cim_mat.set_shader_parameter("player_pos", player.position)
		if _cicek_mat != null:
			_cicek_mat.set_shader_parameter("player_pos", player.position)
	# YASAM: kosma/alet eforu -> aclik daha hizli azalir (PlayerStats okur)
	PlayerStats.exerting = player.is_exerting()
	_tick_spike_hit()  # 11.9: kazikli cukura giren oyuncuya bir kez hasar
	_tick_water_network(delta)  # 11.8: boru agi mantiksal su transferi
	if not _ground_items.is_empty():
		_tick_ground_items(delta)  # #1: suzulme + donme
	_tick_creatures(delta)  # GECE DALGASI: hedefe git / yapiyi kir / saldir
	_station_timer += delta
	if _station_timer >= 0.25:
		_station_timer = 0.0
		_update_station_proximity()
	# KESIF (16.1-16.2): oyuncunun halkasi + isigi -> sis/vinyet/kapi
	_kesif_timer += delta
	if _kesif_timer >= 0.2:
		_kesif_timer = 0.0
		_update_kesif()
		_tick_uyuyanlar(0.2)  # 16.5: uyanma/gecikme/yeniden uyuma/nabiz
		_tick_uzak_tehditler(0.2)  # 16.6: ortam dogurucu + firtina + avci
	# Eldeki esya envanterden ciktiysa birak
	if _held_item != "" and Inventory.get_count(_held_item) <= 0:
		_on_hold_requested("")
	# Otomatik kayit: her 2 dk'da bir (yalnizca degisiklik olduysa)
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		# EDITOR: kayit KAPALI (gorev 4 -- editor degisiklikleri normal
		# oyun kaydina yazilmaz). Cikista dunya kayittan yeniden yuklenir.
		if _dirty and not _editor_on \
				and not OS.has_environment("RABLE_MASK_PREVIEW"):
			SaveManager.save()

# Uygulama arka plana alininca / kapatilinca son durumu kaydet.
# Android'de KRITIK: kullanici oyundan cikinca APPLICATION_PAUSED gelir
# (telefonlarda oyun boyle "kapanir"). Cikista da kaydeder.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _map_w > 0 and not OS.has_environment("RABLE_SCREENSHOT") \
				and not _editor_on \
				and not OS.has_environment("RABLE_MASK_PREVIEW"):
			SaveManager.save()

func is_walkable(cell: Vector2i) -> bool:
	if cell.x < 1 or cell.y < 1 or cell.x >= _map_w - 1 or cell.y >= _map_h - 1:
		return false
	return not _solid_cells.has(cell)

## YOL BULMA MALIYETI (Asama 2): yurunemeyen bir hucreye girmenin
## bedeli. Kirilabilir engel (yapi/agac/kaya) yola KAPALI degil, sadece
## PAHALI — boylece "dolas mi, kir mi" karari ayri bir mantik degil,
## maliyet karsilastirmasinin dogal sonucu oluyor.
## Kirilamaz olanlar (harita kenari, su, plato) gercekten kapali.
## traits: {"climb": bool, "swim": bool} — yaratigin yetenekleri.
## Ayni engel farkli yaratik icin farkli maliyet: TIRMANICI duvari asar
## (ucuz), YUZUCU suyu gecebilir, digerleri icin ikisi de duvar.
func creature_break_cost(cell: Vector2i, traits: Dictionary = {}) -> int:
	if cell.x < 1 or cell.y < 1 or cell.x >= _map_w - 1 or cell.y >= _map_h - 1:
		return CreatureBalance.BLOCK_IMPASSABLE
	# SU: yuzucu gecer (yavas), digerleri icin duvar
	if is_swimmable(cell):
		return CreatureBalance.SWIM_COST if bool(traits.get("swim", false)) \
				else CreatureBalance.BLOCK_IMPASSABLE
	# Oyuncunun yapisi ya da toplanabilir nesne
	if _placed.has(cell) or _objects.has(cell):
		# TIRMANICI asar: kirmak yerine ustunden gecer, maliyet dusuk
		return CreatureBalance.CLIMB_COST if bool(traits.get("climb", false)) \
				else CreatureBalance.BREAK_COST
	# Yuksek plato / diger kati arazi: tirmanici bile gecemez
	return CreatureBalance.BLOCK_IMPASSABLE

## 11.5 MERDIVEN KURALI: from->to adimina izin var mi? Derin cukurdan
## (depth >= LADDER_DEEP_MIN) daha sig bir hucreye CIKMAK ancak merdiven
## erisimi varsa mumkun (1-2 serbest). player3d._try_move buraya danisir.
# --- CIT SISTEMI (kenar-bazli yapi katmani) -------------------------------
## Cit HUCRE degil KENAR kaplar. Anahtar Vector3i(x, y, eksen):
##   eksen 0 = (x,y) hucresinin KUZEY kenari (üstteki komsuyla arasi)
##   eksen 1 = (x,y) hucresinin BATI kenari (soldaki komsuyla arasi)
## Guney/dogu kenarlari komsu hucrenin kuzey/bati kenari olarak yazilir —
## boylece her fiziksel kenarin TEK anahtari olur (cift kayit imkansiz).
var _fences: Dictionary = {}      # kenar -> {"hp": int}
var _fence_nodes: Dictionary = {} # kenar -> ray holder (Node3D)
var _fence_posts: Dictionary = {} # kose Vector2i -> {"node", "n"} (paylasimli)

## Iki 4-komsu hucre arasindaki kenarin kanonik anahtari.
## Komsu degillerse gecersiz anahtar doner.
func _edge_between(a: Vector2i, b: Vector2i) -> Vector3i:
	var d := b - a
	if d == Vector2i(0, -1):
		return Vector3i(a.x, a.y, 0)
	if d == Vector2i(0, 1):
		return Vector3i(b.x, b.y, 0)
	if d == Vector2i(-1, 0):
		return Vector3i(a.x, a.y, 1)
	if d == Vector2i(1, 0):
		return Vector3i(b.x, b.y, 1)
	return Vector3i(-999, -999, -999)

## a'dan b'ye gecis citle kapali mi? (iki yon de ayni kenari bulur)
func fence_blocked(a: Vector2i, b: Vector2i) -> bool:
	var e := _edge_between(a, b)
	return e.z != -999 and _fences.has(e)

## Kenarin iki KOSE noktasi (izgara koseleri; dunya x-z duzleminde).
func _edge_corners(e: Vector3i) -> Array:
	if e.z == 0:  # kuzey kenari: X boyunca, z = e.y
		return [Vector2i(e.x, e.y), Vector2i(e.x + 1, e.y)]
	return [Vector2i(e.x, e.y), Vector2i(e.x, e.y + 1)]  # bati: Z boyunca

func _edge_mid(e: Vector3i) -> Vector3:
	var m := Vector2(float(e.x) + (0.5 if e.z == 0 else 0.0),
			float(e.y) + (0.0 if e.z == 0 else 0.5))
	return Vector3(m.x, ground_height(m.x, m.y), m.y)

## Kenara cit kur (kayittan gelirken hp korunur).
func _set_fence(e: Vector3i, hp: int = -1) -> void:
	if _fences.has(e):
		return
	_fences[e] = {"hp": (hp if hp > 0 else FenceBalance.MAX_HP)}
	# RAY: X'i kenara esnetilir (TEK istisna — gerekce fence_balance),
	# kesit ayri olceklenir ki uzarken kalinlasmasin.
	var holder := Node3D.new()
	var ray: Node3D = load(FenceBalance.RAIL_GLB).instantiate()
	ray.scale = Vector3(FenceBalance.RAIL_LEN_X, FenceBalance.RAIL_SECTION,
			FenceBalance.RAIL_SECTION)
	ray.position.y = FenceBalance.RAIL_Y
	_tame_meshy_materials(ray, FenceBalance.TINT)
	holder.add_child(ray)
	holder.position = _edge_mid(e)
	if e.z == 1:
		holder.rotation_degrees.y = 90.0  # ray modeli X-uzun; bati kenari Z-uzun
	add_child(holder)
	_fence_nodes[e] = holder
	# CIT-FIX: direkler artik BAGIMSIZ varliklar (kullanici diker).
	# Ray kurulurken eksik uc tamamlanir — eski kayitlar/testler icin
	# gecis uyumu (mesh-bake yolu; node scale yok).
	for c: Vector2i in _edge_corners(e):
		if not _fence_posts.has(c):
			_place_post(c)
	_update_fence_protection(e)

## Kenardan citi kaldir; paylasilan direkler sayac sifirlaninca gider.
func _remove_fence(e: Vector3i) -> void:
	if not _fences.has(e):
		return
	_fences.erase(e)
	var node: Node3D = _fence_nodes.get(e, null)
	if node != null and is_instance_valid(node):
		node.queue_free()
	_fence_nodes.erase(e)
	# CIT-FIX: ray sokulunce DIREKLER KALIR (yeniden baglanabilir).
	_update_fence_protection(e)

func _clear_fences() -> void:
	for e: Vector3i in _fence_nodes:
		var n: Node3D = _fence_nodes[e]
		if n != null and is_instance_valid(n):
			n.queue_free()
	for c: Vector2i in _fence_posts:
		var pn: Node3D = _fence_posts[c]["node"]
		if pn != null and is_instance_valid(pn):
			pn.queue_free()
	_fences.clear()
	_fence_nodes.clear()
	_fence_posts.clear()

## Cite hasar (yaratik vurusu). Kirilinca kenar acilir — dogal gedik.
func _fence_take_hit(e: Vector3i, damage: int, dir: Vector3) -> void:
	if not _fences.has(e):
		return
	_fences[e]["hp"] = int(_fences[e]["hp"]) - damage
	var node: Node3D = _fence_nodes.get(e, null)
	if node != null and is_instance_valid(node):
		var base: Vector3 = node.position
		var tw := create_tween()
		tw.tween_property(node, "position", base + dir.normalized() * 0.05, 0.05)
		tw.tween_property(node, "position", base, 0.14)
	_spawn_particles(_edge_mid(e) + Vector3(0, 0.5, 0),
			Color(0.62, 0.48, 0.32), 5)
	if int(_fences[e]["hp"]) <= 0:
		_spawn_particles(_edge_mid(e) + Vector3(0, 0.4, 0),
				Color(0.55, 0.42, 0.30), 10)
		_remove_fence(e)
	_dirty = true

## Yaratik yol maliyeti (kenar): citsiz 0; citli kenar PAHALI ama acik
## (kir-ya-da-dolas karari hucre engelleriyle ayni dilde). Tirmanici
## alcak citi kolay asar.
func creature_edge_cost(a: Vector2i, b: Vector2i, traits: Dictionary = {}) -> int:
	if not fence_blocked(a, b):
		return 0
	return FenceBalance.EDGE_COST_CLIMB if bool(traits.get("climb", false)) 			else FenceBalance.EDGE_COST

# --- Tarla korumasi (gorev 5: FIKIR -> uygulandi) -------------------------
## 4 kenari da citli hucre "korunakli". Simdilik VERI BAYRAGI: tarla
## sistemine yazilir; ileride kus/zararli sistemi gelirse hazir.
func fence_protected(cell: Vector2i) -> bool:
	for n: Vector2i in [Vector2i(0, -1), Vector2i(0, 1),
			Vector2i(-1, 0), Vector2i(1, 0)]:
		if not fence_blocked(cell, cell + n):
			return false
	return true

## Degisen kenarin IKI komsu hucresi icin koruma bayragini tazele.
func _update_fence_protection(e: Vector3i) -> void:
	var cells: Array = []
	if e.z == 0:
		cells = [Vector2i(e.x, e.y), Vector2i(e.x, e.y - 1)]
	else:
		cells = [Vector2i(e.x, e.y), Vector2i(e.x - 1, e.y)]
	for c: Vector2i in cells:
		if Farming.plots.has(c):
			Farming.plots[c]["korunakli"] = fence_protected(c)

## Oyuncunun bakisina gore hedef kenar: oyuncu hucresi ile hedef hucre
## 4-komsuysa aradaki kenar; degilse hedefin oyuncuya donuk kenari.
func _fence_edge_for(cell: Vector2i) -> Vector3i:
	var pc := _player_cell()
	var e := _edge_between(pc, cell)
	if e.z != -999:
		return e
	var d := cell - pc
	var yon := Vector2i(0, signi(d.y)) if absi(d.y) >= absi(d.x) 			else Vector2i(signi(d.x), 0)
	if yon == Vector2i.ZERO:
		yon = Vector2i(0, 1)
	return _edge_between(cell, cell - yon)

## Cit yerlestirme (hem place-mode onayi hem dokunma akisi buraya gelir).
func _place_fence_at(cell: Vector2i) -> bool:
	# CIT-FIX: eski "kenara direk+ray cifti" yolu BAYRAKLA KAPALI
	# (gorev: kod silinmez). Eski "cit" esyasi olan yonlendirilir.
	if not FenceBalance.EDGE_PLACEMENT:
		_spawn_floating_text(cell, "Artık direk dikiliyor — Çit Direği yap",
				Color(1, 0.85, 0.5))
		return false
	var e := _fence_edge_for(cell)
	if e.z == -999 or _fences.has(e):
		_spawn_floating_text(cell, "Orada çit var", Color(1, 0.6, 0.6))
		return false
	if e.x < 1 or e.y < 1 or e.x >= _map_w - 1 or e.y >= _map_h - 1:
		return false
	if not (_ground_char.get(cell, "") in [".", "d", "s"]):
		return false
	if not Inventory.remove_item("cit", 1):
		return false
	_set_fence(e)
	_spawn_particles(_edge_mid(e) + Vector3(0, 0.2, 0),
			Color(0.72, 0.66, 0.52), 6)
	_play_sfx("place")
	_spawn_floating_text(cell, "Çit kuruldu", Color(0.8, 1.0, 0.8))
	_dirty = true
	return true

## Oyuncu yakininda, 3x3 cevresi nesnesiz/yapisiz acik hucre bul
## (testler ve kare sahneleri icin ortak arac).
func _find_open_cell(clearance: int = 1, r_min: int = 5, r_max: int = 18) -> Vector2i:
	var pc := _player_cell()
	for r in range(r_min, r_max):
		for aci in range(0, 360, 20):
			var c := pc + Vector2i(int(round(cos(deg_to_rad(aci)) * r)),
					int(round(sin(deg_to_rad(aci)) * r)))
			if c.x < 3 or c.y < 3 or c.x >= _map_w - 3 or c.y >= _map_h - 3:
				continue
			if not (_ground_char.get(c, "") in [".", "d", "s"]):
				continue
			var acik := true
			for oy in range(-clearance, clearance + 1):
				for ox in range(-clearance, clearance + 1):
					var cc := c + Vector2i(ox, oy)
					if _objects.has(cc) or _placed.has(cc) 							or not (_ground_char.get(cc, "") in [".", "d", "s"]):
						acik = false
						break
				if not acik:
					break
			if acik:
				return c
	return Vector2i(-999, -999)

## Agir CI kareleri (cit-fix): tek direk / iki-dokunus baglama vurgusu /
## 4-yonlu birlesim / tarla cevrili final (kapi boslugu — iki ucta direk).
func _run_fence_frames(save_path: String) -> void:
	var m := _find_open_cell(2, 6, 20)
	if m == Vector2i(-999, -999):
		return
	_cam_locked = true
	var eski_poz: Vector3 = player.position
	var mc := _cell_center(m)
	# KARE A: TEK DIREK — karakter yaninda boy kontrolu (bel hedefi)
	player.position = mc + Vector3(1.0, 0, 0.4)
	var c0 := Vector2i(m.x, m.y)
	_place_post(c0)
	camera.position = Vector3(float(c0.x), 0, float(c0.y)) \
			+ Vector3(-1.8, 1.4, 2.4)
	camera.look_at(Vector3(float(c0.x), 0.5, float(c0.y)))
	await get_tree().create_timer(0.4).timeout
	_snap(save_path.replace(".png", "_cit_direk.png"))
	# KARE B: IKI-DOKUNUS — secili direk buyur + komsu aday isareti
	_place_post(c0 + Vector2i(1, 0))
	_cit_post_tapped(c0)
	await get_tree().create_timer(0.3).timeout
	_snap(save_path.replace(".png", "_cit_baglama.png"))
	Inventory.add_item("cubuk", 24)
	_cit_post_tapped(c0 + Vector2i(1, 0))  # ikinci dokunus: baglar
	# KARE C: 4-YONLU BIRLESIM (+ sekli)
	var jc := c0 + Vector2i(3, 0)
	_place_post(jc)
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(0, 1), Vector2i(0, -1)]:
		_place_post(jc + d)
		_cit_bagla(jc, jc + d, false)
	camera.position = Vector3(float(jc.x), 0, float(jc.y)) \
			+ Vector3(-2.2, 2.4, 3.0)
	camera.look_at(Vector3(float(jc.x), 0.3, float(jc.y)))
	await get_tree().create_timer(0.4).timeout
	_snap(save_path.replace(".png", "_cit_birlesim.png"))
	# KARE D: 3x3 tarla + cevre citi + KAPI BOSLUGU (guney orta bos)
	var t := _find_open_cell(2, 10, 26)
	if t != Vector2i(-999, -999):
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				var c := t + Vector2i(ox, oy)
				if _till_valid(c):
					Farming.till_cell(c)
					_on_plot_changed(c)
		if Farming.plots.has(t):
			Farming.plant(t, "berry_bush")
			Farming.plots[t].stage = 2
			_on_plot_changed(t)
		for i in range(-1, 2):
			_set_fence(Vector3i(t.x + i, t.y - 1, 0))
			if i != 0:
				_set_fence(Vector3i(t.x + i, t.y + 2, 0))
			_set_fence(Vector3i(t.x - 1, t.y + i, 1))
			_set_fence(Vector3i(t.x + 2, t.y + i, 1))
		var tp := _cell_center(t)
		camera.position = tp + Vector3(-3.2, 3.4, 4.6)
		camera.look_at(tp + Vector3(0, 0.2, 0))
		await get_tree().create_timer(0.5).timeout
		_snap(save_path.replace(".png", "_cit_tarla.png"))
	player.position = eski_poz
	camera.position = player.position + _camera_offset()
	_cam_locked = false

## FENCETEST (hizli CI, cit-fix): tek direk + OTOMATIK RAY YOK +
## dokunarak baglama (bedel/malzemesiz-ipucu) + sokme iadesi (%50) +
## 4-yon birlesim + yaratik kirilabilirligi + direk boyu (bel).
func _run_fence_test() -> void:
	_clear_creatures()
	var k := _find_open_cell(2, 5, 22)
	if k == Vector2i(-999, -999):
		push_error("FENCE: test icin acik hucre yok")
		return
	var eski_poz: Vector3 = player.position
	player.position = _cell_center(k)
	# 1) TEK DIREK: esya akisiyla (envanter duser, ray GELMEZ).
	# CI envanteri onceki testlerden DOLU olabilir — eklenebildiyse tam
	# akis, eklenemediyse cekirdek yol olculur (add sessiz basarisiz).
	Inventory.add_item("cit_diregi", 1)
	var stok := Inventory.get_count("cit_diregi")
	var f0 := _fences.size()
	var eski_item := _held_item
	_held_item = "cit_diregi"
	var direk_ok: bool
	if stok >= 1:
		direk_ok = _place_direk_at(k) \
				and Inventory.get_count("cit_diregi") == stok - 1
	else:
		direk_ok = _place_post(_nearest_corner(k))
	_held_item = eski_item
	var c0 := _nearest_corner(k)
	var koseler: Array = [c0, c0 + Vector2i(1, 0),
			c0 + Vector2i(0, 1), c0 + Vector2i(1, 1)]
	for c: Vector2i in koseler:
		_place_post(c)
	# 2) OTOMATIK RAY YOK: 4 komsu direk dikildi, ray gelmedi
	var oto_yok: bool = _fences.size() == f0
	# 3) MALZEMESIZ baglanamaz
	var eldeki := Inventory.get_count("cubuk")
	if eldeki > 0:
		Inventory.remove_item("cubuk", eldeki)
	var malzeme_ok: bool = not _cit_bagla(c0, c0 + Vector2i(1, 0))
	# 4) 3 kenari elle bagla, 1 acik (kapi); bedel duser
	Inventory.add_item("cubuk", 12)
	var oncesi := Inventory.get_count("cubuk")
	var b1 := _cit_bagla(koseler[0], koseler[1])
	var b2 := _cit_bagla(koseler[1], koseler[3])
	var b3 := _cit_bagla(koseler[3], koseler[2])
	var bedel: int = 3 * int(FenceBalance.RAY_COST["cubuk"])
	var bagla_ok: bool = b1 and b2 and b3 \
			and Inventory.get_count("cubuk") == oncesi - bedel \
			and _fences.size() == f0 + 3
	# 5) SOKME: %50 iade, direkler kalir
	var sok_oncesi := Inventory.get_count("cubuk")
	_cit_ray_sok(_edge_of_corners(koseler[0], koseler[1]))
	var iade_ok: bool = Inventory.get_count("cubuk") \
			== sok_oncesi + int(FenceBalance.RAY_IADE["cubuk"]) \
			and _fences.size() == f0 + 2 and _fence_posts.has(koseler[0])
	# 6) 4-YON BIRLESIM serbest
	var m := _find_open_cell(2, 8, 26)
	var birlesim := 0
	Inventory.add_item("cubuk", 8)  # 4 bag x RAY_COST butcesi
	if m != Vector2i(-999, -999):
		var mcn := Vector2i(m.x, m.y)
		_place_post(mcn)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(0, 1), Vector2i(0, -1)]:
			_place_post(mcn + d)
			_cit_bagla(mcn, mcn + d)
		birlesim = _post_bond_count(mcn)
	# 7) KIRILMA korunur: kapali yaratik rayi kirar
	player.position = _cell_center(k + Vector2i(24, 0))
	var kafes_h := _find_open_cell(1, 12, 30)
	var kirilma_ok := false
	if kafes_h != Vector2i(-999, -999):
		spawn_creature(kafes_h, "normal")
		var kafes: Array = []
		for n: Vector2i in [Vector2i(0, -1), Vector2i(0, 1),
				Vector2i(-1, 0), Vector2i(1, 0)]:
			var e := _edge_between(kafes_h, kafes_h + n)
			if not _fences.has(e):
				_set_fence(e)
			kafes.append(e)
		var hp0 := 0
		for e: Vector3i in kafes:
			if _fences.has(e):
				hp0 += int(_fences[e]["hp"])
		for i in 120:
			_tick_creatures(0.05)
		var hp1 := 0
		for e: Vector3i in kafes:
			if _fences.has(e):
				hp1 += int(_fences[e]["hp"])
		kirilma_ok = hp1 < hp0
	_clear_creatures()
	# 8) OLCEK: bake edilen direk mesh'inden boy OLCUMU (bel hedefi)
	var boy := 0.0
	var meshler := _tree_model_yukle(FenceBalance.POST_GLB, FenceBalance.POST_H)
	if not meshler.is_empty():
		boy = (meshler[0] as Mesh).get_aabb().size.y
	var olcek_ok: bool = absf(boy - FenceBalance.POST_H) < 0.03
	if not direk_ok:
		push_error("FENCE: tek direk yerlestirme akisi bozuk")
	if not oto_yok:
		push_error("FENCE: ray KENDILIGINDEN geldi (otomatik baglama acik!)")
	if not malzeme_ok:
		push_error("FENCE: malzemesiz baglama engellenmedi")
	if not bagla_ok:
		push_error("FENCE: dokunarak baglama/bedel bozuk")
	if not iade_ok:
		push_error("FENCE: sokme iadesi bozuk")
	if birlesim != 4:
		push_error("FENCE: 4-yon birlesim serbest degil (%d)" % birlesim)
	if not kirilma_ok:
		push_error("FENCE: yaratik citi kirmiyor")
	if not olcek_ok:
		push_error("FENCE: direk boyu hedefte degil (%.2f)" % boy)
	print("FENCETEST: direk=%s oto_yok=%s malzeme=%s bagla=%s iade=%s birlesim=%d kirilma=%s boy=%.2f" % [
			str(direk_ok), str(oto_yok), str(malzeme_ok), str(bagla_ok),
			str(iade_ok), birlesim, str(kirilma_ok), boy])
	_clear_fences()
	player.position = eski_poz

## Agir CI kare dizisi (agac-kesim): sallanma -> devrilme -> toz ->
## odun sacilmasi. Zamanlama fell_balance suralerinden.
func _run_fell_frames(save_path: String) -> void:
	var k := _find_open_cell(2, 6, 22)
	if k == Vector2i(-999, -999):
		return
	_cam_locked = true
	var eski_item := _held_item
	var eski_poz: Vector3 = player.position
	_objects[k] = "T"
	_solid_cells[k] = true
	_rebuild_objects()
	player.position = _cell_center(k + Vector2i(0, 2))
	_held_item = "balta"
	var kp := _cell_center(k)
	# Kamera yandan: devrilme yayi (kuzeye dusecek) karede kalsin
	camera.position = kp + Vector3(-4.2, 2.6, -1.2)
	camera.look_at(kp + Vector3(0, 1.2, -1.0))
	_try_harvest(k)
	await get_tree().create_timer(0.12).timeout
	_snap(save_path.replace(".png", "_kesim_sallanma.png"))
	await get_tree().create_timer(0.85).timeout   # devrilmenin ortasi
	_snap(save_path.replace(".png", "_kesim_devrilme.png"))
	await get_tree().create_timer(0.5).timeout    # carpma + toz ani
	_snap(save_path.replace(".png", "_kesim_toz.png"))
	await get_tree().create_timer(1.1).timeout    # erime bitti, odunlar yerde
	camera.position = kp + Vector3(-2.6, 3.0, 2.2)
	camera.look_at(kp + Vector3(0, 0.2, -1.2))
	await get_tree().create_timer(0.3).timeout
	_snap(save_path.replace(".png", "_kesim_odun.png"))
	player.position = eski_poz
	_held_item = eski_item
	camera.position = player.position + _camera_offset()
	_cam_locked = false

## FELLTEST (hizli CI, agac-kesim): son baltada agac devrilir (hucre
## ANINDA acilir — carpisma kapali), es zamanli 5 devrilme (kuyruk yok),
## odunlar govde hattina dagilir ve mevcut sistemle toplanir.
## Zaman tabanli gorseller agir CI karelerinde; burada mantik olculur.
func _run_fell_test() -> void:
	var k := _find_open_cell(2, 5, 22)
	if k == Vector2i(-999, -999):
		push_error("FELL: test icin acik hucre yok")
		return
	var eski_item := _held_item
	var eski_poz: Vector3 = player.position
	player.position = _cell_center(k + Vector2i(0, 2))
	_held_item = "balta"
	_objects[k] = "T"
	_solid_cells[k] = true
	_rebuild_objects()
	var f0 := _fells.size()
	_try_harvest(k)  # balta: tek vurus (tool hits 1)
	var devrildi: bool = _fells.size() == f0 + 1
	var acik: bool = not _objects.has(k) and is_walkable(k)
	# ODUN HATTI: erimeyi bekletmeden dogrudan bitir (zaman agir CI'da)
	var oncesi := Inventory.get_count("odun")
	var toplam_odun := 0
	var hat_ok := false
	if devrildi:
		var kayit: Dictionary = _fells[-1]
		_fell_finish(kayit)
		var hucreler: Array = kayit.get("hucreler", [])
		hat_ok = hucreler.size() >= FellBalance.LOG_MIN 				and hucreler.size() <= FellBalance.LOG_MAX
		for h: Vector2i in hucreler:
			var gi := _ground_item_at(h)
			if gi != -1 and String(_ground_items[gi]["id"]) == "odun":
				toplam_odun += int(_ground_items[gi]["count"])
				_try_pickup_ground(h)  # mevcut toplama sistemi
	var odun_ok: bool = toplam_odun == 3  # T dususu: odun 3 (OBJECT_DEFS)
	var toplandi: bool = Inventory.get_count("odun") == oncesi + toplam_odun
	# ES ZAMANLILIK: 5 agac ayni anda devrilebilmeli (kuyruk yok)
	var stres0 := _fells.size()
	var stres_hucreler: Array = []
	for i in 5:
		var c := _find_open_cell(1, 5 + i, 24)
		if c == Vector2i(-999, -999) or _objects.has(c):
			continue
		_objects[c] = "T"
		_solid_cells[c] = true
		stres_hucreler.append(c)
	_rebuild_objects()
	for c: Vector2i in stres_hucreler:
		player.position = _cell_center(c + Vector2i(0, 2))
		_try_harvest(c)
	var eszamanli: int = _fells.size() - stres0
	var stres_ok: bool = eszamanli == stres_hucreler.size() and eszamanli >= 3
	if not devrildi:
		push_error("FELL: son baltada devrilme baslamadi")
	if not acik:
		push_error("FELL: devrilen agacin hucresi acilmadi (takilma riski)")
	if not hat_ok:
		push_error("FELL: odun hatti yigin sayisi bantta degil")
	if not odun_ok:
		push_error("FELL: odun sayisi yanlis (%d, beklenen 3)" % toplam_odun)
	if not toplandi:
		push_error("FELL: odunlar mevcut sistemle toplanamadi")
	if not stres_ok:
		push_error("FELL: es zamanli devrilme kuyruklandi (%d/%d)" % [
				eszamanli, stres_hucreler.size()])
	print("FELLTEST: devrildi=%s acik=%s hat=%s odun=%d toplandi=%s eszamanli=%d" % [
			str(devrildi), str(acik), str(hat_ok), toplam_odun,
			str(toplandi), eszamanli])
	# Temizlik: kalan devrilme kopyalarini ve odunlari kaldir
	for kayit2: Dictionary in _fells.duplicate():
		_fell_finish(kayit2)
		var pv: Node3D = kayit2["pivot"]
		if pv != null and is_instance_valid(pv):
			pv.queue_free()
	_fells.clear()
	for i in range(_ground_items.size() - 1, -1, -1):
		if String(_ground_items[i]["id"]) in ["odun", "yaprak"]:
			var gn: Variant = _ground_items[i].get("node", null)
			if gn != null and is_instance_valid(gn):
				(gn as Node).queue_free()
			_ground_items.remove_at(i)
	player.position = eski_poz
	_held_item = eski_item

# --- CIT-FIX: tek direk yerlestirme + dokunarak ray baglama ---------------
## Secili direk (iki-dokunus akisi). (-999,-999) = secim yok.
var _bind_sel := Vector2i(-999, -999)

## Hucrenin oyuncuya en yakin kosesi (direk yerlesim hedefi).
func _nearest_corner(cell: Vector2i) -> Vector2i:
	var pp := player.position
	var en := Vector2i(cell.x, cell.y)
	var mes := 9e9
	for oy in [0, 1]:
		for ox in [0, 1]:
			var c := Vector2i(cell.x + ox, cell.y + oy)
			var dd := Vector2(pp.x - float(c.x), pp.z - float(c.y)).length()
			if dd < mes:
				mes = dd
				en = c
	return en

## Iki KOMSU kose arasindaki kenar (komsu degilse gecersiz).
func _edge_of_corners(a: Vector2i, b: Vector2i) -> Vector3i:
	var d := b - a
	if d == Vector2i(1, 0):
		return Vector3i(a.x, a.y, 0)
	if d == Vector2i(-1, 0):
		return Vector3i(b.x, b.y, 0)
	if d == Vector2i(0, 1):
		return Vector3i(a.x, a.y, 1)
	if d == Vector2i(0, -1):
		return Vector3i(b.x, b.y, 1)
	return Vector3i(-999, -999, -999)

## Bir diregin kac yonu bagli (0..4). T ve + birlesimler serbest.
func _post_bond_count(c: Vector2i) -> int:
	var n := 0
	for e: Vector3i in [Vector3i(c.x, c.y, 0), Vector3i(c.x - 1, c.y, 0),
			Vector3i(c.x, c.y, 1), Vector3i(c.x, c.y - 1, 1)]:
		if _fences.has(e):
			n += 1
	return n

## Kose noktasina TEK DIREK diker. Gorsel mesh-bake hattindan (node
## scale YOK — agaclarla ayni normalize; gorev sarti).
func _place_post(c: Vector2i) -> bool:
	if _fence_posts.has(c):
		return false
	if c.x < 1 or c.y < 1 or c.x >= _map_w - 1 or c.y >= _map_h - 1:
		return false
	var meshler := _tree_model_yukle(FenceBalance.POST_GLB, FenceBalance.POST_H)
	if meshler.is_empty():
		return false
	var mi := MeshInstance3D.new()
	mi.mesh = meshler[0]
	mi.position = Vector3(float(c.x),
			ground_height(float(c.x), float(c.y)), float(c.y))
	add_child(mi)
	_fence_posts[c] = {"node": mi, "n": 0}
	# OTOMATIK BAGLAMA KAPALI (gorev: ray yalniz kullanici istegiyle).
	# Kod korunuyor — bayrak acilirsa <2 bagli komsulara kendisi baglar.
	if FenceBalance.AUTO_BAGLAMA:
		_auto_baglama_dene(c)
	return true

## [BAYRAKLA KAPALI] Yeni direk dikilince <2 bagli komsulara ray dener.
func _auto_baglama_dene(c: Vector2i) -> void:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(0, 1), Vector2i(0, -1)]:
		var k := c + d
		if _fence_posts.has(k) and _post_bond_count(k) < 2:
			_cit_bagla(c, k, false)

## "Cit Diregi" esyasi: TEK DIREK diker (yonsuz, koseye).
func _place_direk_at(cell: Vector2i) -> bool:
	var c := _nearest_corner(cell)
	if _fence_posts.has(c):
		_spawn_floating_text(cell, "Orada direk var", Color(1, 0.6, 0.6))
		return false
	if not (_ground_char.get(cell, "") in [".", "d", "s"]):
		return false
	if not Inventory.remove_item("cit_diregi", 1):
		return false
	if not _place_post(c):
		Inventory.add_item("cit_diregi", 1)
		return false
	_play_sfx("place")
	_spawn_floating_text(cell, "Direk dikildi", Color(0.8, 1.0, 0.8))
	_dirty = true
	return true

## Iki komsu diregi rayla baglar. Bedel RAY_COST (yoksa ipucu).
func _cit_bagla(a: Vector2i, b: Vector2i, sesli: bool = true) -> bool:
	var e := _edge_of_corners(a, b)
	if e.z == -999 or _fences.has(e):
		return false
	if not _fence_posts.has(a) or not _fence_posts.has(b):
		return false
	if not _cit_bedel_dus():
		if sesli:
			_spawn_floating_text(Vector2i(a.x, a.y),
					_cit_bedel_metni() + " gerek", Color(1, 0.6, 0.6))
		return false
	_set_fence(e)
	if sesli:
		_play_sfx("place")
		_spawn_particles(_edge_mid(e) + Vector3(0, 0.3, 0),
				Color(0.72, 0.66, 0.52), 5)
	_dirty = true
	return true

func _cit_bedel_dus() -> bool:
	for id in FenceBalance.RAY_COST:
		if Inventory.get_count(String(id)) < int(FenceBalance.RAY_COST[id]):
			return false
	for id in FenceBalance.RAY_COST:
		Inventory.remove_item(String(id), int(FenceBalance.RAY_COST[id]))
	return true

func _cit_bedel_metni() -> String:
	var parca: PackedStringArray = []
	for id in FenceBalance.RAY_COST:
		parca.append("%d %s" % [int(FenceBalance.RAY_COST[id]),
				Items.display_name(String(id))])
	return " + ".join(parca)

## Ray sokme: %50 iade (veride) — kenar acilir, DIREKLER KALIR.
func _cit_ray_sok(e: Vector3i) -> void:
	if not _fences.has(e):
		return
	_remove_fence(e)
	for id in FenceBalance.RAY_IADE:
		Inventory.add_item(String(id), int(FenceBalance.RAY_IADE[id]))
	_spawn_floating_text(Vector2i(e.x, e.y), "Ray söküldü (iade)",
			Color(0.9, 0.9, 0.7))
	_dirty = true

## Bakilan hucreye gore cit hedefi: secim aktifken direk oncelikli
## (ikinci dokunus), degilse once ray (Sok), sonra direk (Bagla).
func _cit_target() -> Dictionary:
	var fc := _facing_cell()
	var pp := player.position
	var kose := Vector2i(-999, -999)
	var kmes := 9e9
	for oy in [0, 1]:
		for ox in [0, 1]:
			var c := Vector2i(fc.x + ox, fc.y + oy)
			if not _fence_posts.has(c):
				continue
			var dd := Vector2(pp.x - float(c.x), pp.z - float(c.y)).length()
			if dd < kmes:
				kmes = dd
				kose = c
	var ekenar := Vector3i(-999, -999, -999)
	for n: Vector2i in [Vector2i(0, -1), Vector2i(0, 1),
			Vector2i(-1, 0), Vector2i(1, 0)]:
		var e := _edge_between(fc, fc + n)
		if e.z != -999 and _fences.has(e):
			ekenar = e
			break
	if _bind_sel != Vector2i(-999, -999) and kose != Vector2i(-999, -999):
		return {"type": "citdirek", "cell": fc, "corner": kose,
				"icon": "hammer", "valid": true, "kind": "none"}
	if ekenar.z != -999:
		return {"type": "citray", "cell": fc, "edge": ekenar,
				"icon": "grab", "valid": true, "kind": "none"}
	if kose != Vector2i(-999, -999):
		return {"type": "citdirek", "cell": fc, "corner": kose,
				"icon": "hammer", "valid": true, "kind": "none"}
	return {"type": "none", "cell": fc, "icon": "fist",
			"valid": false, "kind": "none"}

## Direge dokunuldu: sec ya da (secim varken komsuya) BAGLA.
func _cit_post_tapped(c: Vector2i) -> void:
	if _bind_sel == Vector2i(-999, -999):
		_bind_sel = c
		_cit_sel_vurgula(c, true)
		_spawn_floating_text(Vector2i(c.x, c.y),
				"Bağla: komşu direğe dokun", Color(0.8, 0.95, 1.0))
		return
	if _bind_sel == c:
		_cit_sel_vurgula(_bind_sel, false)
		_bind_sel = Vector2i(-999, -999)
		return
	if (c - _bind_sel).length() == 1.0:
		if _cit_bagla(_bind_sel, c):
			_spawn_floating_text(Vector2i(c.x, c.y), "Bağlandı",
					Color(0.7, 1.0, 0.7))
		_cit_sel_vurgula(_bind_sel, false)
		_bind_sel = Vector2i(-999, -999)
		return
	_cit_sel_vurgula(_bind_sel, false)
	_bind_sel = c
	_cit_sel_vurgula(c, true)
	_spawn_floating_text(Vector2i(c.x, c.y),
			"Bağla: komşu direğe dokun", Color(0.8, 0.95, 1.0))

## Secili direk vurgusu: hafif buyume + bos komsu yonlere aday isareti.
func _cit_sel_vurgula(c: Vector2i, on: bool) -> void:
	if not _fence_posts.has(c):
		return
	var node: Node3D = _fence_posts[c]["node"]
	if node == null or not is_instance_valid(node):
		return
	var tw := create_tween()
	tw.tween_property(node, "scale",
			Vector3(1.18, 1.18, 1.18) if on else Vector3.ONE, 0.12)
	if on:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(0, 1), Vector2i(0, -1)]:
			var k := c + d
			if _fence_posts.has(k) \
					and not _fences.has(_edge_of_corners(c, k)):
				_spawn_particles(Vector3(float(k.x), ground_height(
						float(k.x), float(k.y)) + 0.5, float(k.y)),
						Color(0.5, 0.9, 1.0), 5)
## YOLTEST (hizli CI, tas-yol): hucre doseme (MultiMesh ornek sayisi) +
## donus cesitliligi + uc kurali (kucuk olcek) + firca entegrasyonu
## (lay_road -> _build_road ayni gorsel yol).
func _run_yol_test() -> void:
	var eski_yol := _path_cells.duplicate()
	_path_cells.clear()
	var k := _find_open_cell(2, 6, 24)
	if k == Vector2i(-999, -999):
		push_error("YOL: acik hucre yok")
		_path_cells = eski_yol
		return
	for i in 6:  # kisa serit + tek uc
		lay_road(k + Vector2i(i, 0), "yeni")
	_build_road()
	var mesh_ok := _path_mesh() != null
	# Ornek sayisi: yol MultiMesh'i doseli hucre kadar ornek icermeli
	var ornek := 0
	for n in _road_nodes:
		if n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh.mesh == _path_mesh():
			ornek = (n as MultiMeshInstance3D).multimesh.instance_count
	var dosendi: bool = ornek == _path_cells.size()
	# Donus cesitliligi: hash yaw'lari arasinda en az 2 farkli deger
	var yawlar: Dictionary = {}
	for cell: Vector2i in _path_cells:
		yawlar[int(RoadScatter.hash01(cell.x, cell.y, 601) * 4.0) % 4] = true
	var donus_ok: bool = yawlar.size() >= 2
	# Uc kurali: uc hucrenin olcegi ic hucreden kucuk (hash bagimsiz kural)
	var uc_ok := RoadScatter.PATH_UC_SCALE < 1.0
	if not mesh_ok:
		push_error("YOL: stone_path mesh yuklenemedi")
	if not dosendi:
		push_error("YOL: doseme eksik (%d ornek / %d hucre)" % [
				ornek, _path_cells.size()])
	if not donus_ok:
		push_error("YOL: donus cesitliligi yok")
	print("YOLTEST: mesh=%s ornek=%d hucre=%d donus=%d uc_olcek=%.2f" % [
			str(mesh_ok), ornek, _path_cells.size(), yawlar.size(),
			RoadScatter.PATH_UC_SCALE])
	_path_cells = eski_yol
	_build_road()

func _fences_to_save() -> Array:
	var out: Array = []
	for e: Vector3i in _fences:
		out.append([e.x, e.y, e.z, int(_fences[e]["hp"])])
	return out

func _posts_to_save() -> Array:
	var out: Array = []
	for c: Vector2i in _fence_posts:
		out.append([c.x, c.y])
	return out

func can_step(from: Vector2i, to: Vector2i) -> bool:
	# CIT: kenari citli gecis kapali (oyuncu icin de — dogal gecit
	# birakilan kenardan dolasilir).
	if fence_blocked(from, to):
		return false
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
		"fences": _fences_to_save(),  # cit-sistemi: kenar + hp
		"fence_posts": _posts_to_save(),  # cit-fix: bagimsiz direkler
		"structures": _structures.to_save_data(),  # 13.6: yon/hp/durum
		"chests": chest_json,
		"ground_items": ground_json,
		"dummies": dummy_json,
		"player": [player.position.x, player.position.z],
		"held": _held_item,
		"home_bed": [_home_bed.x, _home_bed.y],  # 14.2 aktif dogus noktasi
		"farming": Farming.to_save_data(),  # tarim-3d: tarla/evre/islaklik/kap
		"kesif": _kesif_to_save(),  # Bolum 16: tas durumlari + fener
	}

## KESIF kayit paketi: yalniz DURUM yazilir (konumlar deterministik ama
## algoritma degisirse eski kayit bozulmasin diye hucre de saklanir).
func _kesif_to_save() -> Dictionary:
	var taslar: Array = []
	for id: String in _kor_taslari:
		var t: Dictionary = _kor_taslari[id]
		taslar.append({"id": id, "x": Vector2i(t["cell"]).x,
				"y": Vector2i(t["cell"]).y, "yanik": bool(t["yanik"])})
	return {"taslar": taslar, "fener_kisik": _fener_kisik,
			"nefes": _ocak_nefes, "uyuyanlar": _uyuyan_to_save()}

func _kesif_from_save(data: Dictionary) -> void:
	if data.is_empty():
		return
	_fener_kisik = bool(data.get("fener_kisik", false))
	var nefes := String(data.get("nefes", "harla"))
	if KesifBalance.NEFES_CARPAN.has(nefes):
		_ocak_nefes = nefes
	for kayit in data.get("taslar", []):
		var id := String(kayit.get("id", ""))
		if not _kor_taslari.has(id):
			continue
		# Konum kayittan (algoritma kaysa bile oyuncunun gordugu tas yerinde)
		var cell := Vector2i(int(kayit.get("x", 0)), int(kayit.get("y", 0)))
		if cell != Vector2i(_kor_taslari[id]["cell"]):
			_solid_cells.erase(Vector2i(_kor_taslari[id]["cell"]))
			_kor_taslari[id]["cell"] = cell
			_solid_cells[cell] = true
			if _kor_tas_gorseller.has(id) and is_instance_valid(_kor_tas_gorseller[id]):
				_kor_tas_gorseller[id].position = _cell_center(cell) + Vector3(0, 0.62, 0)
		_kor_taslari[id]["yanik"] = bool(kayit.get("yanik", false))
		if _kor_tas_gorseller.has(id) and is_instance_valid(_kor_tas_gorseller[id]):
			_kor_tas_isima(_kor_tas_gorseller[id], bool(_kor_taslari[id]["yanik"]))
	_rebuild_temiz_bolgeler()
	_uyuyan_from_save(data.get("uyuyanlar", []))
	_update_alev_rengi()
	_son_vinyet = -1.0

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
	Farming.from_save_data(data.get("farming", {}))  # tarim-3d (yoksa temiz)
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
	_clear_fences()
	for pj in data.get("fence_posts", []):
		_place_post(Vector2i(int(pj[0]), int(pj[1])))
	for fj in data.get("fences", []):
		_set_fence(Vector3i(int(fj[0]), int(fj[1]), int(fj[2])), int(fj[3]))
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
	_kesif_from_save(data.get("kesif", {}))  # Bolum 16: tas/fener durumu
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
	b.custom_minimum_size = Vector2(0, 56)
	b.theme_type_variation = "PrimaryButton"  # gorunur + genis dokunma alani
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.focus_mode = Control.FOCUS_ALL
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
	# KESIF 16.3: kor taslari kalici engel (yanik/yanmamis farketmez)
	for id: String in _kor_taslari:
		_solid_cells[Vector2i(_kor_taslari[id]["cell"])] = true

# Iki parmakla yakinlastirma (pinch); oyuncu hareketi 1. parmakta kalir
func _unhandled_input(event: InputEvent) -> void:
	# ARASTIRMA TESTI (yalnizca klavyeli ortam: masaustu/web).
	# F9: durum dokumu; F10: stone_tools dugumunu bedava malzemeyle ac
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			Research.debug_print_state()
		elif event.keycode == KEY_F10:
			Research.debug_research("stone_tools")
		# BÖLÜM 15 debug: K = onunde bir yaratik spawn et (elle test)
		elif event.keycode == KEY_K:
			var fo := Vector2i(player.facing.round())
			if fo == Vector2i.ZERO:
				fo = Vector2i(0, 1)
			spawn_creature(_player_cell() + fo * 2, "normal")
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
			# Firca vurusu bitti: bir sonraki surukleme ayni hucreleri
			# yeniden isleyebilsin.
			_editor_firca_dokunulan.clear()
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		# EDITOR YOL FIRCASI: basili tut-suruk -> gecilen hucrelere yol.
		# Tek parmakla (ikinci parmak varsa o pinch'tir, firca calismaz).
		if _editor_on and _editor_tool == LayoutEditor.ARAC_YOL \
				and _touches.size() == 1:
			var bc := _screen_to_cell(event.position)
			if bc != Vector2i(-999, -999):
				_editor_yol(bc, true)
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
	# R1: Kamera/Gorunum debug butonlari artik HUD'da surekli durmaz;
	# yalnizca HUD Ayarlar menusu acikken gorunur (settings_toggled).
	_cam_layer = CanvasLayer.new()
	# BUGFIX: HUD (layer 3) Ayarlar overlay'i bu paneli yutuyordu -> HUD'un
	# ustune al (4) ki Ayarlar acikken Kamera kontrolleri tiklanabilsin.
	_cam_layer.layer = 4
	_cam_layer.visible = false
	add_child(_cam_layer)
	var layer := _cam_layer

	var button := Button.new()
	button.text = "Kamera"
	button.toggle_mode = true
	button.button_pressed = true  # Ayarlar acilinca panel dogrudan gorunur
	button.position = Vector2(12, 190)
	button.size = Vector2(120, 46)
	button.add_theme_font_size_override("font_size", 18)
	layer.add_child(button)

	# NOT: "Görünüm" (karakter/orman stili) paneli kullanici istegiyle kaldirildi.

	var panel := PanelContainer.new()
	panel.visible = true
	panel.position = Vector2(144, 190)
	panel.custom_minimum_size = Vector2(320, 0)
	layer.add_child(panel)
	button.toggled.connect(func(pressed: bool):
		panel.visible = pressed
		if not pressed:
			_save_settings())

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
	# golgeleri dev bulanik leke olmasin (netlik dramatik artar).
	# MOBIL PERF: 40 -> 22 m; golge alani kucuk = golge gecisi ucuz.
	sun.directional_shadow_max_distance = 22.0
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
	_update_water_night()  # gece sicak yansimasi (ucuz tek setter)

# --- Dunya kurulumu -----------------------------------------------------

func _build_world() -> void:
	# harita-v2: taban harita noise ile üretilir (aynı seed = aynı harita).
	# Kayıt taban haritayı yazmaz; delta (kazı/nesne/yapı) yazar — bu yüzden
	# seed sabit ki reload'da taban aynı çıksın.
	var rows: Array[String] = MapGen.generate(_map_seed)
	# HARITA MASKESI: data/map_mask.png varsa uretime rehber olur
	# (elle boyanan biyomlar + noise kenar organikligi). Dosya yoksa
	# bu satir hicbir sey degistirmez — tam-proseduerel fallback.
	rows = MapMask.apply(rows, _map_seed)
	# YUKSEKLIK MASKESI (v2): tepe/duzlik katmani (data/height_mask.png).
	# Biyomdan SONRA biner: tepe boyanan yer ormanin ustune de gelebilir.
	rows = MapMask.apply_height(rows, _map_seed)
	_fog_img = MapMask.load_fog_image()  # sis katmani (yoksa null: halka fallback)
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
					# AGAC OBEK: komsuda MAX_TREE_NEIGHBORS'a kadar agaca izin
					# (orman havasi); daha fazlasi olursa hucre zemin kalir
					# (yurunebilir bosluk). Bkz. _tree_neighbor_count.
					if _tree_neighbor_count(cell) <= MAX_TREE_NEIGHBORS:
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

	# YOL IZI + SPAWN KAMPI arazi asamasi. Yollar kamptan tureidigi icin
	# _path_cells kamptan ONCE temizlenir; kamp kendi seritlerini ekler.
	# Kamp planlamasi taban anlik goruntusundan ONCE calismali, yoksa kayit
	# "kamptaki agaclar silinmis" diye delta yazar ve her yuklemede
	# agaclar kulubenin icinde geri belirirdi.
	_path_cells.clear()
	_camp_plan()
	# Kenar harmani kamptan SONRA: kamp plato hucrelerini duz cime
	# cevirdigi icin harman guncel zemin karakterlerini gormeli.
	_build_edge_blend()
	_build_wet_cells()  # B6: islak kiyi seridi (arazi kurulmadan once)

	# kayit-sistemi: taban nesne anlik goruntusu (seed'den uretilen ilk durum).
	# Kayitta yalniz bundan FARKLI hucreler yazilir (dosya kucuk kalir).
	_base_objects = _objects.duplicate()

	_recompute_water()  # 11.2: haritadaki hazir cukurlar havuz olur (kuru)
	_build_terrain()
	_build_road()
	_build_sea()
	_build_lake_surface()
	_build_sea_rocks()
	_build_decor(ground_cells["."] + ground_cells["h"])
	_rebuild_objects()
	_build_rim_cells()   # A1: kenar yigini (arazi ornegi bunu okur)
	_build_dig_decor()   # A5 + A6: kazi agzi ve tabani
	_build_spawn_camp()  # kamp dekoru (nesneler kurulduktan sonra)
	_kamp_duzenini_uygula()  # data/camp_layout.json VARSA uzerine kurar
	_build_ground_markers()  # harita-v2: kil işaretleri + yüzey cevher ipuçları
	_place_kor_taslari()  # KESIF 16.3: Ocak belli olduktan sonra yay yerlesimi
	_place_uyuyanlar()   # KESIF 16.5: sis kusagi kumeleri (taslardan sonra)
	_place_damar_catlaklari()  # KESIF 16.6: H3 isik sizan yariklar

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


# --- ZEMIN GECIS BANDI (kenar harmani) ----------------------------------
# Toprak/cim/kum yamalarinin sinirlari hucre cozunurlugunde KESKIN KARE
# cikiyordu. Iki katmanli cozum:
#   1) map_gen esige ince gurultu ekler -> sinirin SEKLI organik olur.
#   2) Burada sinir hucrelerinin RENGI komsu ortalamasina cekilir ->
#      cizgi tek renk atlamasi yerine gecis bandi olur (%30 bir komsu
#      farkliysa, %60 uc-dort komsu farkliysa).
# Su ("~") harman disi: cim<->su karisimi camur yesili verir, kiyiyi
# kum zaten yumusatiyor.
const EDGE_BLEND_MIN := 0.30
const EDGE_BLEND_MAX := 0.60
const EDGE_NB: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1)]
var _edge_blend: Dictionary = {}   # cell -> harmanlanmis Color

## B6: suya komsu kara hucreleri (islak serit). Bir kez hesaplanir.
var _wet_cells: Dictionary = {}
## A1: kazilmis hucrenin KAZILMAMIS komsusu -> kenar yigini yuksekligi.
## "Toprak nereye gitti" sorusunun gorsel cevabi: cikan toprak cukurun
## cevresine alcak bir set olarak yigilmis gorunuyor.
var _rim_cells: Dictionary = {}   # cell -> kabarma (m)

func _build_rim_cells() -> void:
	_rim_cells.clear()
	for cell: Vector2i in _depth:
		if int(_depth[cell]) <= 0:
			continue
		for d: Vector2i in EDGE_NB:
			var nb := cell + d
			if int(_depth.get(nb, 0)) != 0 or _rim_cells.has(nb):
				continue
			if String(_ground_char.get(nb, "")) == "~":
				continue
			# Yukseklik hucreye gore deterministik degisir: duz bir set
			# degil, dogal bir toprak yigini.
			var t: float = DigWaterVisual.hash01(nb.x, nb.y, 601)
			_rim_cells[nb] = lerpf(DigWaterVisual.RIM_RISE_MIN,
					DigWaterVisual.RIM_RISE_MAX, t)

func _build_wet_cells() -> void:
	_wet_cells.clear()
	var r: int = DigWaterVisual.WET_BAND_CELLS
	for cell: Vector2i in _ground_char:
		if String(_ground_char[cell]) == "~":
			continue
		var wet := false
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx == 0 and dy == 0:
					continue
				if String(_ground_char.get(cell + Vector2i(dx, dy), "")) == "~":
					wet = true
					break
			if wet:
				break
		if wet:
			_wet_cells[cell] = true

func _build_edge_blend() -> void:
	_edge_blend.clear()
	for cell: Vector2i in _ground_char:
		var ch: String = _ground_char[cell]
		if ch == "~":
			continue
		var base: Color = GROUND_DEFS[ch]["color"]
		var mix := Color(0, 0, 0)
		var diff := 0
		for d: Vector2i in EDGE_NB:
			var nch: String = String(_ground_char.get(cell + d, ch))
			if nch == ch or nch == "~":
				continue
			mix += Color(GROUND_DEFS[nch]["color"])
			diff += 1
		if diff == 0:
			continue
		mix = mix / float(diff)
		var t: float = EDGE_BLEND_MIN + (EDGE_BLEND_MAX - EDGE_BLEND_MIN) \
				* (float(diff - 1) / 3.0)
		_edge_blend[cell] = base.lerp(mix, t)

## Hucrenin zemin rengi: sinirdaysa gecis bandi rengi, degilse taban renk.
func _ground_color(cell: Vector2i, def: Dictionary) -> Color:
	if _edge_blend.has(cell):
		var c: Color = _edge_blend[cell]
		return c
	var base: Color = def["color"]
	return base

func _cell_props(cx: int, cy: int) -> Array:
	if cx < 0 or cy < 0 or cx >= _map_w or cy >= _map_h:
		return [-1.0, Color(0.72, 0.60, 0.38)]  # harita disi: denize inen yamac
	var ch: String = _ground_char.get(Vector2i(cx, cy), ".")
	var def: Dictionary = GROUND_DEFS[ch]
	if ch == "~":
		# Golun dibi kumlu; su yuzeyini deniz duzlemi saglar
		return [-0.40, Color(0.62, 0.54, 0.36)]
	if ch == "h":
		return [1.1, _ground_color(Vector2i(cx, cy), def)]
	# Duz alanlar hafif dalgali: dogal tepecik hissi (yumusak fonksiyon)
	var roll := sin(cx * 0.37) * cos(cy * 0.29) * 0.07 \
			+ sin(cx * 0.15 + cy * 0.42) * 0.05
	# KAZI (11.1/11.3): derinlik veriden dusulur, yigin veriden eklenir.
	# Kenar duvarlari harmanli arazi + falez boyamasindan kendiliginden
	# olusur; derin katman kaya rengine doner.
	var d: int = _depth.get(Vector2i(cx, cy), 0)
	if d != 0:
		# A3 KATMAN RENKLERI + A4 DERINLIK KARARTMASI.
		# Once uc kaba kademe vardi (>=3 tas, >0 toprak); gecisler
		# okunmuyordu. Simdi her derinligin kendi rengi var (bitkisel
		# toprak -> alt toprak -> tas -> kaya) ve uzerine derinlikle
		# artan bir KARARTMA carpani biniyor.
		# Karartma vertex renginde, isik hesabi DEGIL: bedava ve mobil
		# dostu (gorevin "veri tabanli cozum" sarti). depth 4'te 0.42
		# carpaniyla "dibi gorunmuyor" hissi olusuyor.
		if d > 0:
			var col: Color = DigWaterVisual.wall_color(d)
			var k: float = DigWaterVisual.depth_darken(d)
			return [roll - float(d) * DigRules.DEPTH_STEP,
					Color(col.r * k, col.g * k, col.b * k)]
		# d < 0: kazilan toprak geri yigilmis tumsek (karartma yok)
		return [roll - float(d) * DigRules.DEPTH_STEP,
				Color(0.47, 0.34, 0.22)]
	# YOL: zemin RENGI DEGISTIRILMIYOR. Once yolun altina koyu bir toprak
	# halesi konuyordu; karolarin cevresinde kirli/bulanik bir leke
	# yapiyordu ve "yol dagilmis" gorunumunu besliyordu. Kenar gecisini
	# artik karonun ustune binen cim sagliyor (bkz. _build_road).
	# TARIM: surulu tarla rengi (veri Farming'de; GROUND char EKLENMEDI —
	# kayit/uretec varsayimlari bozulmasin). Islakken koyulasir.
	var fplot: Variant = Farming.plots.get(Vector2i(cx, cy))
	if fplot != null:
		var fcol: Color = TarimBalance.TILLED_WET_COLOR \
				if bool(fplot.get("watered_today", false)) else TarimBalance.TILLED_COLOR
		return [roll + TarimBalance.TILLED_TOP, fcol]
	# B6 ISLAK KIYI SERIDI: suya komsu KARA hucresi koyulasir (islak
	# kum/toprak). Su ile kara arasindaki keskin dikey duvar boylece
	# yumusuyor — kiyi "kesilmis" degil "islanmis" okunuyor.
	# _edge_blend gibi onceden hesaplanmis bir tabloya bakiyor, komsu
	# taramasi HER ORNEKTE degil bir kez yapiliyor (_cell_props cok
	# sik cagriliyor).
	# A1 KENAR YIGINI: cukur kenarindaki kazilmamis hucre hafifce kabarir
	if _rim_cells.has(Vector2i(cx, cy)):
		roll += float(_rim_cells[Vector2i(cx, cy)])
	var gcol := _ground_color(Vector2i(cx, cy), def)
	if _wet_cells.has(Vector2i(cx, cy)):
		var w := DigWaterVisual.WET_DARKEN
		gcol = Color(gcol.r * w, gcol.g * w, gcol.b * w)
	return [roll, gcol]

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
	# A2 DUVAR EGIMI: duvar tam dikey degil, ustte hafifce disa acilir.
	# Sert adim (0/1) yerine DAR bir smoothstep bandi kullaniliyor; bandin
	# genisligi egim aciligindan turuyor. Bant cok genis olursa kazi
	# okunakliligi bozulur ("bulanik leke" tuzagi, bkz. asagidaki yorum),
	# o yuzden dar tutuldu.
	# BASAMAK: derinlik STEP_AT_DEPTH'i gectiginde bandin ortasina kucuk
	# bir duzluk giriyor -> duvarda bir cikinti olusuyor. Hem dogal
	# duruyor hem "buradan tirmanilir" okumasi veriyor.
	var slope_w: float = tan(deg_to_rad(DigWaterVisual.WALL_SLOPE_DEG))
	var band: float = clampf(slope_w, 0.05, 0.30)
	var stepped: bool = sharp and dmax >= DigWaterVisual.STEP_AT_DEPTH
	if stepped:
		band = clampf(band + DigWaterVisual.STEP_WIDTH, 0.05, 0.45)
	var hfx := (smoothstep(0.5 - band, 0.5 + band, fx) if sharp else fx)
	var hfz := (smoothstep(0.5 - band, 0.5 + band, fz) if sharp else fz)
	# Renk gecisi normalde dar bantta (0.2..0.8) tutuluyor ki dokular
	# bulanmasin; ama zemin TURU degisen sinirda bu dar bant merdiveni
	# gorunur birakiyordu -> orada tam hucre genisliginde yumusatilir.
	var soft := _edge_blend.has(Vector2i(i0, j0)) \
			or _edge_blend.has(Vector2i(i0 + 1, j0)) \
			or _edge_blend.has(Vector2i(i0, j0 + 1)) \
			or _edge_blend.has(Vector2i(i0 + 1, j0 + 1))
	var cband_lo: float = 0.0 if soft else 0.2
	var cband_hi: float = 1.0 if soft else 0.8
	var cfx := (0.0 if fx < 0.5 else 1.0) if sharp \
			else smoothstep(cband_lo, cband_hi, fx)
	var cfz := (0.0 if fz < 0.5 else 1.0) if sharp \
			else smoothstep(cband_lo, cband_hi, fz)
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
	_build_rim_cells()   # A1: kenar yigini (arazi ornegi bunu okur)
	_build_dig_decor()   # A5 + A6: kazi agzi ve tabani
	_rebuild_objects()


# --- KAZI DEKORU (A5 agiz sarkmasi + A6 taban serpintisi) ---------------
# Kazi MANTIGINA dokunmuyor: yalnizca _depth verisini okuyup uzerine
# gorsel koyuyor. Kazi sonrasi chunk yenilemesiyle birlikte yeniden
# kurulur (deterministik hash -> ayni cukur ayni serpintiyi alir).
var _dig_decor_nodes: Array = []

func _build_dig_decor() -> void:
	for n in _dig_decor_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_dig_decor_nodes.clear()
	if _depth.is_empty():
		return
	var mult: float = float(DigWaterVisual.tier_of(_quality_tier)["scatter"])
	var mouth: Array = []
	var soil: Array = []
	var rock: Array = []
	var pebble: Array = []
	var shore_stone: Array = []
	for cell: Vector2i in _depth:
		var d: int = int(_depth[cell])
		if d <= 0:
			continue
		# --- A6 TABAN SERPINTISI: hucre basina 0..2 parca ---
		# Sigda toprak obegi, derinde tas kiymigi.
		var n_items: int = int(DigWaterVisual.hash01(cell.x, cell.y, 501)
				* float(DigWaterVisual.FLOOR_SCATTER_MAX + 1) * mult)
		var deep: bool = d > DigWaterVisual.FLOOR_SHALLOW_MAX_DEPTH
		for k in n_items:
			var salt := 503 + k * 7
			var ox: float = (DigWaterVisual.hash01(cell.x, cell.y, salt) - 0.5) * 0.6
			var oz: float = (DigWaterVisual.hash01(cell.x, cell.y, salt + 1) - 0.5) * 0.6
			var rr: float = DigWaterVisual.hash01(cell.x, cell.y, salt + 2) * TAU
			var sc: float = 0.75 + DigWaterVisual.hash01(cell.x, cell.y, salt + 3) * 0.5
			var b := Basis().rotated(Vector3.UP, rr).scaled(Vector3(sc, sc, sc))
			var t := Transform3D(b, _cell_center(cell) + Vector3(ox, 0.0, oz))
			if deep:
				rock.append(t)
			else:
				soil.append(t)
		# --- A5 AGIZ SARKMASI: kenar hucrelerine cukura EGIK cim ---
		# Kenar = kazilmis hucrenin KAZILMAMIS komsusu. Cim cukurun
		# agzindan iceri sarkar; keskin sinir cizgisini kiran sey bu.
		for dd: Vector2i in EDGE_NB:
			var nb := cell + dd
			if int(_depth.get(nb, 0)) > 0:
				continue
			if String(_ground_char.get(nb, "")) == "~" or _objects.has(nb):
				continue
			if DigWaterVisual.hash01(nb.x, nb.y, 511) * 100.0 \
					>= float(DigWaterVisual.MOUTH_TUFT_CHANCE) * mult:
				continue
			# Cukura dogru egim: tutam kenardan iceri sarkar
			var tilt := deg_to_rad(DigWaterVisual.MOUTH_TUFT_TILT_DEG)
			var axis := Vector3(float(dd.y), 0.0, -float(dd.x))
			if axis.length() < 0.01:
				continue
			var eb := Basis(axis.normalized(), tilt)
			eb = eb.rotated(Vector3.UP,
					DigWaterVisual.hash01(nb.x, nb.y, 513) * 0.6)
			var off := Vector3(float(-dd.x) * 0.34, 0.0, float(-dd.y) * 0.34)
			mouth.append(Transform3D(eb, _cell_center(nb) + off))
	# --- B6 KIYI SERPINTISI: su kenarindaki KARA hucrelerine tas ---
	# Referansta kiyida taslar var ve su-kara sinirini yumusatiyor.
	# _wet_cells zaten "suya komsu kara" listesi (islak serit icin
	# hesaplaniyordu), ayni tabloyu okuyoruz.
	for wc: Vector2i in _wet_cells:
		if _objects.has(wc) or _placed.has(wc) or _path_cells.has(wc):
			continue
		if DigWaterVisual.hash01(wc.x, wc.y, 711) * 100.0 \
				>= float(DigWaterVisual.SHORE_SCATTER_CHANCE) * mult:
			continue
		var wox: float = (DigWaterVisual.hash01(wc.x, wc.y, 713) - 0.5) * 0.6
		var woz: float = (DigWaterVisual.hash01(wc.x, wc.y, 715) - 0.5) * 0.6
		var wrr: float = DigWaterVisual.hash01(wc.x, wc.y, 717) * TAU
		var wsc: float = 0.8 + DigWaterVisual.hash01(wc.x, wc.y, 719) * 0.4
		var wb := Basis().rotated(Vector3.UP, wrr).scaled(Vector3(wsc, wsc, wsc))
		var wt := Transform3D(wb, _cell_center(wc) + Vector3(wox, 0.0, woz))
		if DigWaterVisual.hash01(wc.x, wc.y, 721) < 0.5:
			pebble.append(wt)
		else:
			shore_stone.append(wt)

	# --- A1 KENAR YIGINI SERPINTISI: setin uzerine toprak/cakil ---
	# Yiginin kendisi arazi yuksekliginde (_rim_cells); burada uzerine
	# %40 serpinti biniyor ki kabarma "renk lekesi" degil "yigin" okunsun.
	for rc: Vector2i in _rim_cells:
		if DigWaterVisual.hash01(rc.x, rc.y, 621) * 100.0 \
				>= float(DigWaterVisual.RIM_SCATTER_CHANCE) * mult:
			continue
		var rox: float = (DigWaterVisual.hash01(rc.x, rc.y, 623) - 0.5) * 0.5
		var roz: float = (DigWaterVisual.hash01(rc.x, rc.y, 625) - 0.5) * 0.5
		var rrr: float = DigWaterVisual.hash01(rc.x, rc.y, 627) * TAU
		var rsc: float = 0.8 + DigWaterVisual.hash01(rc.x, rc.y, 629) * 0.4
		var rb := Basis().rotated(Vector3.UP, rrr).scaled(Vector3(rsc, rsc, rsc))
		var rt := Transform3D(rb, _cell_center(rc) + Vector3(rox, 0.0, roz))
		if DigWaterVisual.hash01(rc.x, rc.y, 631) < 0.5:
			soil.append(rt)
		else:
			pebble.append(rt)
	for pair in [["soil_clump", soil], ["rock_shard", rock],
			["pebble_cluster", pebble], ["path_stone", shore_stone]]:
		var list: Array = pair[1]
		if list.is_empty():
			continue
		var node := _env_scatter_node(String(pair[0]), list)
		if node != null:
			add_child(node)
			_dig_decor_nodes.append(node)
	if not mouth.is_empty():
		var mn := _env_scatter_node("grass_tuft", mouth,
				DigWaterVisual.MOUTH_TUFT_SPAN)
		if mn != null:
			add_child(mn)
			_dig_decor_nodes.append(mn)

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
	_lake_cells_list = lake_cells.keys()  # sicak isik siralamasi icin
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if DigWaterVisual.SU_SHADER_V1:
		# CUSTOM0 = akis yonu (sozlesme); golde durgun (0,0)
		st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
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
					# Derinlik ARAZIDEN olculur: kopuk/kiyi, su cizgisinin
					# dogal kavisini izler (hucre zikzaki olmaz).
					var dm := maxf(0.0, LAKE_Y - ground_height(p.x, p.y))
					if DigWaterVisual.SU_SHADER_V1:
						# SOZLESME: COLOR=(derinlik,kiyi,akis), UV=dunya/olcek,
						# CUSTOM0=akis yonu. Renk hesabi ARTIK SHADER'DA.
						st.set_color(DigWaterVisual.v1_encode(dm))
						st.set_uv(Vector2(p.x, p.y) / DigWaterVisual.V1_UV_OLCEK)
						st.set_custom(0, Color(0, 0, 0, 0))
					else:
						st.set_color(_water_rgba(dm, p.x, p.y))
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

## SU VERTEX RENGI — bant rengi + kopuk + opaklik, RGBA olarak mesh'e
## pisirilir. Shader yalnizca COLOR'i okur.
##
## KIRMIZI BUG'IN KOK SEBEBI BURASIYDI: bu fonksiyon bir "geri alma"
## sirasinda kayboldu ama shader'in yeni hali (ALBEDO = COLOR.rgb)
## kaldi. Mesh derinligi KIRMIZI kanala yaziyordu (Color(d, 0, 0)),
## shader onu albedo sanip cizdi -> derinlestikce kirmiziya kayan su.
## Mesh yazici ile shader TEK BIR SOZLESME; biri degisip digeri
## degismeyince kod parse-temiz kalir ama ekranda cop cikar.
## Iki su yuzeyi de (gol + kazilmis havuz) artik BU fonksiyonu
## kullaniyor; ikisi ayri yerde yaziyordu, biri guncellenmisti.
func _water_rgba(depth_m: float, wx: float, wz: float) -> Color:
	var d: float = maxf(0.0, depth_m)
	# Kopuk esigi kenar boyunca hafif duzensiz olsun
	var jit: float = (DigWaterVisual.hash01(int(wx * 7.0), int(wz * 7.0), 701)
			- 0.5) * 2.0 * DigWaterVisual.FOAM_JITTER
	if d < DigWaterVisual.FOAM_DEPTH + jit:
		var f := DigWaterVisual.FOAM_COLOR
		return Color(f.r, f.g, f.b, 1.0)
	var c := DigWaterVisual.water_color(d)
	return Color(c.r, c.g, c.b, DigWaterVisual.water_alpha(d))

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
var _lake_cells_list: Array = []   # gol hucreleri (sicak isik mesafesi icin)
var _flow_dirs: Dictionary = {}    # hucre -> {dir: Vector2, t: ms} (boru akisi)

func _lake_material() -> ShaderMaterial:
	if _lake_mat != null:
		return _lake_mat
	if DigWaterVisual.SU_SHADER_V1:
		# SU SHADER V1: dosyadan (assets/models/env/water.gdshader).
		# Mesh sozlesmesi v1_encode'da; noise CI dahil kodla uretilir
		# (dosya dokusu yok — her platformda ayni).
		_lake_mat = ShaderMaterial.new()
		_lake_mat.shader = load("res://assets/models/env/water.gdshader")
		_lake_mat.set_shader_parameter("noise_tex", _ortak_noise_tex())
		_apply_water_tier()
		_update_water_warm_lights()
		return _lake_mat
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
// LONGVINTER SU: parlak, doygun, DUZ renk bantlari. Renk/kopuk/opaklik
// mesh uretiminde vertex rengine pisirilmis (bkz. _water_rgba) — burada
// gradyan hesabi YOK, COLOR oldugu gibi cizilir. Shader'in tek isi:
// hafif kipirti, seyrek parilti, gecede sicak ton.
uniform float wave_amp = 0.012;
uniform float wave_speed = 0.30;
uniform float sparkle_amt = 0.0;    // 0 = kapali (Dusuk kademe)
uniform float sparkle_speed = 0.5;
uniform float night_mix = 0.0;      // 0 gunduz, >0 gece sicak yansima
uniform vec3 night_warm = vec3(1.0, 0.72, 0.42);
void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Iki sinus, dusuk genlik, yavas: "hafif kipirdayan gol".
	VERTEX.y += (sin(TIME * wave_speed + wp.x * 0.9)
			+ sin(TIME * wave_speed * 1.7 + wp.z * 1.7)) * wave_amp * 0.5;
}
void fragment() {
	vec3 col = COLOR.rgb;
	// Gece: bant renklerine hafif sicak ton (Ocak/mesale yansimasi)
	col = mix(col, col * night_warm, night_mix);
	// Seyrek kucuk parilti lekeleri, yavas yanip sonme
	if (sparkle_amt > 0.0) {
		vec3 wp2 = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float g = sin(wp2.x * 9.1) * sin(wp2.z * 7.7);
		float blink = 0.5 + 0.5 * sin(TIME * sparkle_speed + wp2.x + wp2.z);
		col += vec3(smoothstep(0.965, 1.0, g) * sparkle_amt * blink);
	}
	ALBEDO = col;
	ALPHA = COLOR.a;
	ROUGHNESS = 0.15;
	SPECULAR = 0.7;
}
"""
	_lake_mat = ShaderMaterial.new()
	_lake_mat.shader = shader
	_apply_water_tier()
	return _lake_mat

## C: kalite kademesi -> su efektleri. Dusuk'te dalga ve parilti KAPALI.
## Ayarlar'dan kademe degisince de cagrilir (apply_quality).
func _apply_water_tier() -> void:
	if _lake_mat == null:
		return
	if DigWaterVisual.SU_SHADER_V1:
		# v1: tek anahtar — Dusuk kademede hareket/parilti/fresnel kapali
		# (quality=0: yalniz bant+kopuk; shader sozlesmesi).
		var t2 := DigWaterVisual.tier_of(_quality_tier)
		_lake_mat.set_shader_parameter("quality",
				1 if bool(t2["wave"]) else 0)
		_update_water_night()
		return
	var t := DigWaterVisual.tier_of(_quality_tier)
	var wave_on: bool = bool(t["wave"])
	var sparkle_on: bool = bool(t["sparkle"])
	_lake_mat.set_shader_parameter("wave_amp",
			DigWaterVisual.WAVE_AMP if wave_on else 0.0)
	_lake_mat.set_shader_parameter("wave_speed", DigWaterVisual.WAVE_SPEED)
	_lake_mat.set_shader_parameter("sparkle_speed", DigWaterVisual.SPARKLE_SPEED)
	_lake_mat.set_shader_parameter("sparkle_amt",
			DigWaterVisual.SPARKLE_AMT if sparkle_on else 0.0)
	_lake_mat.set_shader_parameter("night_warm",
			Vector3(DigWaterVisual.NIGHT_WARM.r, DigWaterVisual.NIGHT_WARM.g,
					DigWaterVisual.NIGHT_WARM.b))
	_update_water_night()

## Gece bandi: Ocak/mesale isiginin sicak yansimasi. Gunes supurmesiyle
## ayni yerden guncelleniyor (kare basina tek setter, ucuz).
func _update_water_night() -> void:
	var night: bool = DayNight.phase in ["night", "dusk"]
	var karisim: float = DigWaterVisual.NIGHT_WARM_MIX if night else 0.0
	if _lake_mat != null:
		_lake_mat.set_shader_parameter("night_mix", karisim)
	# CIM SHADER V1: gece tonu SU ILE AYNI KAYNAKTAN (sozlesme sarti)
	if _cim_mat != null:
		_cim_mat.set_shader_parameter("night_mix", karisim)
	if _cicek_mat != null:
		_cicek_mat.set_shader_parameter("night_mix", karisim)
	# YARATIK catlak isimasi da AYNI gece kaynagindan yanar/soner
	# (su/cim/yaratik tek kaynak sozlesmesi; faz degisince, her kare degil).
	for cr in _creatures:
		if is_instance_valid(cr) and cr.has_method("set_night"):
			cr.set_night(night)

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
		if _camp_field.has(cell):
			continue  # terk edilmis tarlanin sirtlari cimle kaplanmasin
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
		var node := _make_mesh_multimesh(pool[idx], groups[idx], false,
				_cim_material(pool))
		add_child(node)
		_decor_nodes.append(node)
	_build_env_scatter(grass_cells)

# --- YOL HUCRELERI ------------------------------------------------------
# Yol bir ZEMIN TURU: hucre -> yas ("miras" | "yeni"). Zemin rengini
# _cell_props okur; uzerine dosenen tas karolari asagidaki yol sistemi
# kurar (_build_road).
var _path_cells: Dictionary = {}   # cell -> yas (String)
var _path_nodes: Array = []        # (eski tas serpintisi; perf sondasi okur)

## KAVISLI yol: guneye ilerlerken sinuzoidal x kaymasi. Kosegen/egri
## gecislerde izgara merdiveni en cok burada goze batar; kenar erimesinin
## sinandigi yer de burasi.
func _add_road_curve(from: Vector2i, steps: int, width: int,
		age: String) -> void:
	# TEK YONLU kavis (ceyrek daire). Ilk denemede sin(t*PI*1.4) kullanildi:
	# egri gidip GERI donunce yol kendi uzerine kivrilip karede catallanmis
	# bir "lambda" gibi gorundu. Monoton kavis okunakli.
	for i in steps:
		var t := float(i) / maxf(1.0, float(steps - 1))
		var off := int(round(sin(t * PI * 0.5) * 5.0))
		var c := from + Vector2i(off, i)
		if c.x < 1 or c.y < 1 or c.x >= _map_w - 1 or c.y >= _map_h - 1:
			break
		for w in width:
			lay_road(c + Vector2i(w, 0), age)
		# Kaymanin atladigi hucreyi doldur ki yolda delik kalmasin
		if i > 0:
			var prev := int(round(sin((float(i - 1) / maxf(1.0, float(steps - 1)))
					* PI * 0.5) * 5.0))
			var step := 1 if off > prev else -1
			var x := prev
			while x != off:
				x += step
				for w in width:
					lay_road(Vector2i(from.x + x + w, c.y), age)

## Bir noktadan verilen yonde `len` hucrelik yol seridi tanimlar.
## width: serit genisligi (2+ olunca kenar karolari devreye girer).
func _add_path_strip(from: Vector2i, dir: Vector2i, len_cells: int,
		age: String = "miras", width: int = 1) -> void:
	var perp := Vector2i(-dir.y, dir.x)
	for i in range(1, len_cells + 1):
		var c := from + dir * i
		if c.x < 1 or c.y < 1 or c.x >= _map_w - 1 or c.y >= _map_h - 1:
			break
		for w in width:
			lay_road(c + perp * w, age)

# --- TAS YOL SISTEMI (auto-tiling + kenar erimesi) ----------------------
# Yol hucresi bir ZEMIN TURUDUR: _path_cells[cell] = yas ("miras"|"yeni").
# Uzerine 1x1 tas karo doseniyor; karo varyanti (a/b/c) ve 90'lik donusu
# hucreden deterministik hash ile secilir -> harita yeniden kurulunca
# desen degismez.
#
# KENAR ERIMESI, sistemin can alici yeri. Izgaraya dosenmis kare karolar
# kenarda MERDIVEN gibi gorunur (ozellikle kosegen yolda). Uc katman:
#   1) Komsusunda yol OLMAYAN hucre road_tile_edge kullanir, kirik tarafi
#      disa donuk. (Tam bir tarafi acikken; iki+ tarafi acik dar yolda
#      tek karoyla iki kenar birden kirilamaz -> normal varyant + agir
#      dekor. Aciklama RAPOR'da.)
#   2) Kenar hucrelerinin USTUNE yosun lekesi + ot tutami.
#   3) KOMSU CIM hucrelerine sacilma (1 hucre %35, 2 hucre %12). Duz
#      sinir cizgisini asil kiran budur; karo hizasi disina tastigi icin
#      goz "izgara" gormez.
const RoadTiles = preload("res://scripts/road_tiles.gd")
const RoadScatter = preload("res://scripts/road_scatter.gd")
const MapMask = preload("res://scripts/map_mask.gd")

const ROAD_NB: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0),
		Vector2i(0, 1), Vector2i(-1, 0)]   # K, D, G, B (yaw 0/90/180/270)

var _road_nodes: Array = []        # karo + dekor MultiMesh'leri
var _road_edge_used := 0           # ROADTEST: kac hucrede kenar karosu
var _road_edge_covered := 0        # ROADTEST: karo kenarina cim BINEN hucre
var _road_joint_deco := 0          # ROADTEST: derz dekoru alan hucre
var _road_spill: Dictionary = {}   # cim hucresi -> true (serpinti cakismasin)

## Bir hucre yol mu?
func is_road(cell: Vector2i) -> bool:
	return _path_cells.has(cell)

## Yol dose (yas: "miras" = harita mirasi, "yeni" = oyuncunun dosedigi).
## Gorsel sistem ikisini FARKLI cizer (yosun yogunlugu), boylece eski/yeni
## ayrimi hicbir arayuz olmadan gorselden okunur.
func lay_road(cell: Vector2i, age: String = "yeni") -> void:
	if cell.x < 1 or cell.y < 1 or cell.x >= _map_w - 1 or cell.y >= _map_h - 1:
		return
	# Yol yalniz duz, yurunebilir zemine doseniyor: suya girmez, plato
	# ustune tirmanmaz (karo yamaca oturmaz, havada kalirdi).
	if not String(_ground_char.get(cell, "")) in [".", "d", "s"]:
		return
	_path_cells[cell] = age
	# Yolun ORTASINDA agac/kaya duramaz. (Ilk karede kavisli yol ormanin
	# icinden gectigi icin agaclar karolarin ustunde bitiyordu.)
	_objects.erase(cell)
	_solid_cells.erase(cell)

## Karonun -90 X yatirmasi + Y donusu birlesik temel.
func _road_basis(yaw_deg: float, scale_v: float) -> Basis:
	var b := Basis().rotated(Vector3.RIGHT, -PI * 0.5)  # XY duzleminden zemine
	b = Basis().rotated(Vector3.UP, deg_to_rad(yaw_deg)) * b
	return b.scaled(Vector3(scale_v, scale_v, scale_v))

## Yol cizimi. IKI MODEL var, ayni veriyi (_path_cells) okuyorlar:
##   SERPINTI (aktif)  — road_scatter.gd, stone_scatter_a.glb
##   KARO (kapali)     — road_tiles.gd, road_tile_a/b/c.glb
## Karo modeli silinmedi, bayrakla kapatildi (geri donus sigortasi).
func _build_road() -> void:
	for n in _road_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_road_nodes.clear()
	_road_spill.clear()
	if _path_cells.is_empty():
		return
	# TAS YOL FINAL: stone_path scatter (tek hucre, zemin CIM kalir).
	# Onceki iki yaklasim bayrakla kapali (geri donus sigortasi).
	if RoadScatter.PATH_ON:
		_build_road_path()
		return
	if RoadScatter.SCATTER_ON:
		_build_road_scatter()
		return
	if RoadTiles.TILE_MODE_ON:
		_build_road_tiles()

## TAS YOL FINAL: her yol hucresine stone_path (rastgele 0/90/180/270 +
## %90-110 olcek + ±%5 ofset). Zemin boyanmaz — cim aralardan gorunur.
## Yol UCU / tekil kenar (yol komsusu <= 1): %70 olcek — "yol dagilarak
## biter". Taslarin %30'unu gizleme MUMKUN DEGIL: model TEK mesh geldi
## (olculdu, alt-node yok) — gorev izniyle yalniz olcek kucultme (RAPOR).
## Ust serpinti: moss %20 (miras %40); 1 dis hucreye %15 kacak tas.
## Dusuk kalitede moss + kacak kapali. TEK MultiMesh (golge ACIK).
var _path_mesh_cache: Mesh = null

func _path_mesh() -> Mesh:
	if _path_mesh_cache != null:
		return _path_mesh_cache
	if not ResourceLoader.exists(RoadScatter.PATH_GLB):
		return null
	var inst: Node3D = load(RoadScatter.PATH_GLB).instantiate()
	var mesh := _find_mesh(inst)
	inst.queue_free()
	if mesh == null:
		return null
	# Sicak gri carpan: Meshy taslari cok beyaz (kanit karesi) —
	# yuzey materyalleri BIR KEZ kopyalanip tonlanir.
	mesh = mesh.duplicate()
	for sf in mesh.get_surface_count():
		var m := mesh.surface_get_material(sf)
		if m is BaseMaterial3D:
			var k: BaseMaterial3D = m.duplicate()
			k.albedo_color = k.albedo_color * RoadScatter.PATH_TINT
			mesh.surface_set_material(sf, k)
	_path_mesh_cache = mesh
	return mesh

func _build_road_path() -> void:
	var mesh := _path_mesh()
	if mesh == null:
		return
	var t := PerfBalance.tier(_quality_tier)
	var yuksek: bool = bool(t.get("shadow", true))
	var xforms: Array = []
	var moss: Array = []
	var stray: Array = []
	for cell: Vector2i in _path_cells:
		var age := String(_path_cells[cell])
		# yol komsusu sayisi: uc/tekil hucre tespiti
		var komsu := 0
		for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(0, 1), Vector2i(0, -1)]:
			if _path_cells.has(cell + n):
				komsu += 1
		var h1 := RoadScatter.hash01(cell.x, cell.y, 601)
		var h2 := RoadScatter.hash01(cell.x, cell.y, 607)
		var sc: float = RoadScatter.PATH_SCALE_MIN + h2 \
				* (RoadScatter.PATH_SCALE_MAX - RoadScatter.PATH_SCALE_MIN)
		if komsu <= 1:
			sc *= RoadScatter.PATH_UC_SCALE  # uc kurali: dagilarak biter
		var yaw := float(int(h1 * 4.0) % 4) * 90.0
		var ox: float = (RoadScatter.hash01(cell.x, cell.y, 613) - 0.5) \
				* 2.0 * RoadScatter.PATH_OFS
		var oz: float = (RoadScatter.hash01(cell.x, cell.y, 617) - 0.5) \
				* 2.0 * RoadScatter.PATH_OFS
		var pos := _cell_center(cell) + Vector3(ox,
				RoadScatter.PATH_TOP - RoadScatter.PATH_MESH_TOP * sc, oz)
		var b := Basis().rotated(Vector3.UP, deg_to_rad(yaw)) \
				.scaled(Vector3(sc, sc, sc))
		xforms.append(Transform3D(b, pos))
		if not yuksek:
			continue  # Dusuk kademe: moss + kacak yok (mobil)
		var moss_pct: int = RoadScatter.PATH_MOSS_PCT_MIRAS \
				if age == "miras" else RoadScatter.PATH_MOSS_PCT
		if RoadScatter.hash01(cell.x, cell.y, 619) * 100.0 < float(moss_pct):
			moss.append(Transform3D(Basis().rotated(Vector3.UP,
					RoadScatter.hash01(cell.x, cell.y, 621) * TAU),
					_cell_center(cell) + Vector3(0, 0.02, 0)))
		for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(0, 1), Vector2i(0, -1)]:
			var g := cell + n
			if _path_cells.has(g) or not is_walkable(g):
				continue
			if RoadScatter.hash01(g.x, g.y, 631) * 100.0 \
					< float(RoadScatter.PATH_STRAY_PCT) * 0.25:
				stray.append(Transform3D(Basis().rotated(Vector3.UP,
						RoadScatter.hash01(g.x, g.y, 633) * TAU) \
						.scaled(Vector3(0.6, 0.6, 0.6)),
						_cell_center(g)))
	if xforms.is_empty():
		return
	# Golge ACIK (gorev kurali: cast/receive) — tek MultiMesh.
	var node := _make_mesh_multimesh(mesh, xforms, true)
	add_child(node)
	_road_nodes.append(node)
	if not moss.is_empty():
		var mn := _road_moss_node(moss)
		if mn != null:
			add_child(mn)
			_road_nodes.append(mn)
	if not stray.is_empty():
		var sn := _env_scatter_node("path_stone", stray)
		if sn != null:
			add_child(sn)
			_road_nodes.append(sn)

func _build_road_tiles() -> void:
	var mult: float = float(EnvModels.SCATTER_TIER_MULT.get(_quality_tier, 1.0))
	var has_edge: bool = RoadTiles.has_model("road_tile_edge")
	# tur -> Array[Transform3D]
	var tiles: Dictionary = {}
	_road_edge_used = 0
	_road_edge_covered = 0
	_road_joint_deco = 0
	var moss: Array = []
	var tufts: Array = []
	var joint_tufts: Array = []
	var spill: Dictionary = {"path_stone": [], "path_stone_mossy": [],
			"pebble_cluster": []}

	for cell: Vector2i in _path_cells:
		var age := String(_path_cells[cell])
		# --- Acik kenarlar (yol OLMAYAN komsular) ---
		var open_dirs: Array[int] = []
		for i in ROAD_NB.size():
			if not _path_cells.has(cell + ROAD_NB[i]):
				open_dirs.append(i)
		# --- Karo secimi ---
		var id: String
		var yaw: float
		if open_dirs.size() == 1 and has_edge:
			# KENAR KAROSU: kirik taraf disa donuk
			id = "road_tile_edge"
			yaw = float(open_dirs[0]) * 90.0
			_road_edge_used += 1
		else:
			var vi := int(RoadTiles.hash01(cell.x, cell.y, 301) * 3.0) % 3
			id = RoadTiles.VARIANTS[vi]
			yaw = float(int(RoadTiles.hash01(cell.x, cell.y, 307) * 4.0) % 4) * 90.0
		if not tiles.has(id):
			tiles[id] = []
		var pos := _cell_center(cell)
		tiles[id].append(Transform3D(_road_basis(yaw, 1.0), pos))

		# --- 2a) DERZ ARALIGI: her yol hucresinde karo YUZEYINDE ---
		if RoadTiles.hash01(cell.x, cell.y, 341) * 100.0 \
				< float(RoadTiles.JOINT_TUFT_CHANCE) * mult:
			joint_tufts.append(_road_face_xform(cell, 343))
			_road_joint_deco += 1
		var jm: float = float(RoadTiles.JOINT_MOSS_CHANCE) \
				* RoadTiles.moss_density(age) * mult
		if RoadTiles.hash01(cell.x, cell.y, 347) * 100.0 < jm:
			moss.append(_road_face_xform(cell, 349))

		if open_dirs.is_empty():
			continue   # ic hucre: kenar dekoru yok

		# --- 2b) KENAR: cim karonun USTUNE biner, kenar cizgisini kirar ---
		# KALITE CARPANI UYGULANMAZ. Bu bir dekor degil, GECISIN KENDISI:
		# yol-cim sinirindaki net cizgiyi kiran tek sey bu. Kademe carpani
		# (orta = 0.7) uygulandiginda ortme %60 yerine %47'ye dusuyordu ve
		# tepeden bakista duz karo kenarlari geri geliyordu. Dusuk
		# kademede zaten daha az yol hucresi gorunuyor; asil tasarruf
		# derz dekoru ve sacilmada (onlar mult'a bagli).
		if RoadTiles.hash01(cell.x, cell.y, 317) * 100.0 \
				< float(RoadTiles.EDGE_OVERLAP_CHANCE):
			tufts.append(_road_edge_xform(cell, open_dirs, 319, 0.0))
			_road_edge_covered += 1

		# --- 3) Komsu CIM hucrelerine sacilma ---
		var mossy_pct := RoadTiles.mossy_chance(age)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var d: int = maxi(absi(dx), absi(dy))
				if d == 0:
					continue
				var g := cell + Vector2i(dx, dy)
				if _path_cells.has(g) or _road_spill.has(g):
					continue
				if not _road_spill_ok(g):
					continue
				var chance: float = float(RoadTiles.SPILL_D1_CHANCE if d == 1
						else RoadTiles.SPILL_D2_CHANCE) * mult
				if RoadTiles.hash01(g.x, g.y, 401) * 100.0 >= chance:
					continue
				_road_spill[g] = true
				var sid := "pebble_cluster"
				if RoadTiles.hash01(g.x, g.y, 409) < 0.5:
					sid = "path_stone_mossy" \
							if RoadTiles.hash01(g.x, g.y, 411) * 100.0 < float(mossy_pct) \
							else "path_stone"
				var rr: float = RoadTiles.hash01(g.x, g.y, 413) * TAU
				var sc: float = RoadTiles.SPILL_SCALE_MIN \
						+ RoadTiles.hash01(g.x, g.y, 419) \
						* (RoadTiles.SPILL_SCALE_MAX - RoadTiles.SPILL_SCALE_MIN)
				var ox: float = (RoadTiles.hash01(g.x, g.y, 421) - 0.5) * 0.6
				var oz: float = (RoadTiles.hash01(g.x, g.y, 431) - 0.5) * 0.6
				var b := Basis().rotated(Vector3.UP, rr).scaled(Vector3(sc, sc, sc))
				spill[sid].append(Transform3D(b,
						_cell_center(g) + Vector3(ox, 0.0, oz)))

	# --- Dugumler: tur basina TEK MultiMesh ---
	for id: String in tiles:
		var node := _road_tile_node(id, tiles[id])
		if node != null:
			add_child(node)
			_road_nodes.append(node)
	if not moss.is_empty():
		var mn := _road_moss_node(moss)
		if mn != null:
			add_child(mn)
			_road_nodes.append(mn)
	if not tufts.is_empty():
		# Kenar otu acik cimdekinden KUCUK (taslarin arasindan cikan filiz)
		var tn := _env_scatter_node("grass_tuft", tufts, RoadTiles.EDGE_TUFT_SPAN)
		if tn != null:
			add_child(tn)
			_road_nodes.append(tn)
	if not joint_tufts.is_empty():
		var jn := _env_scatter_node("grass_tuft", joint_tufts,
				RoadTiles.JOINT_TUFT_SPAN)
		if jn != null:
			add_child(jn)
			_road_nodes.append(jn)
	for sid: String in spill:
		var list: Array = spill[sid]
		if list.is_empty():
			continue
		var sn := _env_scatter_node(sid, list)
		if sn != null:
			add_child(sn)
			_road_nodes.append(sn)

# --- SERPINTI MODELI ----------------------------------------------------
## Hucrenin kac 4-yon komsusu yol? (0-4)
func _road_nb_count(cell: Vector2i) -> int:
	var n := 0
	for d: Vector2i in ROAD_NB:
		if _path_cells.has(cell + d):
			n += 1
	return n

## Her yol hucresi icin "terminale uzaklik" (hucre). Terminal = 4-yon
## komsusu 1 ya da 0 olan hucre, yani yolun bittigi yer. Uc kuralinin
## SON HUCREYE degil son BIRKAC hucreye uygulanmasi bunun icin: yol
## tek karede degil, birkac hucrede dagilarak bitmeli.
func _road_end_dist() -> Dictionary:
	var dist: Dictionary = {}
	var kuyruk: Array = []
	for cell: Vector2i in _path_cells:
		if _road_nb_count(cell) <= 1:
			dist[cell] = 0
			kuyruk.append(cell)
	var i := 0
	while i < kuyruk.size():
		var c: Vector2i = kuyruk[i]
		i += 1
		var nd: int = int(dist[c]) + 1
		if nd > RoadScatter.END_RUN:
			continue
		for d: Vector2i in ROAD_NB:
			var g: Vector2i = c + d
			if not _path_cells.has(g) or dist.has(g):
				continue
			dist[g] = nd
			kuyruk.append(g)
	return dist

var _road_scatter_cells := 0   # ROADTEST
var _road_end_cells := 0
var _road_stray_cells := 0
var _road_tuft_cells := 0
var _road_seam_count := 0   # derz dolgusu ornek sayisi

func _build_road_scatter() -> void:
	var tier: Dictionary = RoadScatter.tier_of(_quality_tier)
	var end_dist := _road_end_dist()
	var tas: Array = []          # Transform3D
	var tonlar: Array = []       # her ornegin renk carpani
	var moss: Array = []
	var tufts: Array = []
	var stray: Array = []
	_road_scatter_cells = 0
	_road_end_cells = 0
	_road_stray_cells = 0
	_road_tuft_cells = 0
	_road_seam_count = 0

	for cell: Vector2i in _path_cells:
		var age := String(_path_cells[cell])
		var open_dirs: Array[int] = []
		for i in ROAD_NB.size():
			if not _path_cells.has(cell + ROAD_NB[i]):
				open_dirs.append(i)

		# --- Hucre basina varyasyon: donus + olcek + konum ---
		var yaw: float = float(int(RoadScatter.hash01(cell.x, cell.y, 501)
				* float(RoadScatter.YAW_STEPS)) % RoadScatter.YAW_STEPS) * 90.0
		var sc: float = RoadScatter.SCALE_MIN \
				+ RoadScatter.hash01(cell.x, cell.y, 503) \
				* (RoadScatter.SCALE_MAX - RoadScatter.SCALE_MIN)
		var off: float = RoadScatter.OFFSET_MAX
		# UC RAMPASI: terminale yakin hucreler kucultulur ve daha cok
		# oynatilir -> yol tek hamlede kesilmez, dagilarak biter.
		if end_dist.has(cell):
			var t: float = float(int(end_dist[cell])) / float(RoadScatter.END_RUN)
			sc *= lerpf(RoadScatter.END_SCALE, 1.0, clampf(t, 0.0, 1.0))
			off += RoadScatter.END_OFFSET_EXTRA * (1.0 - clampf(t, 0.0, 1.0))
			if int(end_dist[cell]) == 0:
				_road_end_cells += 1
		var ox: float = (RoadScatter.hash01(cell.x, cell.y, 507) - 0.5) * 2.0 * off
		var oz: float = (RoadScatter.hash01(cell.x, cell.y, 509) - 0.5) * 2.0 * off
		tas.append(Transform3D(Basis().rotated(Vector3.UP, deg_to_rad(yaw))
				.scaled(Vector3(sc, sc, sc)),
				_cell_center(cell) + Vector3(ox, 0.0, oz)))
		# Ton oynamasi: ±%5, hucreden deterministik.
		var j: float = 1.0 + (RoadScatter.hash01(cell.x, cell.y, 511) - 0.5) \
				* 2.0 * RoadScatter.TINT_JITTER
		tonlar.append(Color(j, j, j))
		_road_scatter_cells += 1

		# --- DERZ DOLGUSU: iki yol hucresinin ARASINA kucuk obek ---
		# Izgarayi asil kiran sey bu. Yalniz olcek buyutmek yetmiyordu:
		# 1 hucre genisligindeki yolda komsuluk KENAR uzerinden oluyor,
		# iki hucrenin tam ortasi bos kaliyor ve tepeden bakista yol
		# noktali bir dizi gibi goruluyordu.
		if RoadScatter.SEAM_ON:
			for sd: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				if not _path_cells.has(cell + sd):
					continue
				var mid := _cell_center(cell) \
						+ Vector3(float(sd.x) * 0.5, 0.0, float(sd.y) * 0.5)
				var sy: float = float(int(RoadScatter.hash01(cell.x, cell.y,
						561 + sd.x) * 4.0) % 4) * 90.0
				var ss2: float = RoadScatter.SEAM_SCALE_MIN \
						+ RoadScatter.hash01(cell.x, cell.y, 563 + sd.y) \
						* (RoadScatter.SEAM_SCALE_MAX - RoadScatter.SEAM_SCALE_MIN)
				tas.append(Transform3D(
						Basis().rotated(Vector3.UP, deg_to_rad(sy))
						.scaled(Vector3(ss2, ss2, ss2)), mid))
				var j2: float = 1.0 + (RoadScatter.hash01(cell.x, cell.y, 567)
						- 0.5) * 2.0 * RoadScatter.TINT_JITTER
				tonlar.append(Color(j2, j2, j2))
				_road_seam_count += 1

		# --- Taslarin USTUNE yosun ---
		if bool(tier.get("moss", true)) \
				and RoadScatter.hash01(cell.x, cell.y, 521) * 100.0 \
				< float(RoadScatter.moss_chance(age)):
			moss.append(_road_face_xform(cell, 523))

		if open_dirs.is_empty():
			continue

		# --- Kenar hucresi: 0-1 cim tutami, TAS KENARINA bitisik ---
		# Yolun ICINE ot konmuyor: zemin cimi zaten aralardan goruluyor.
		var tc: float = float(RoadScatter.EDGE_TUFT_CHANCE) \
				* float(tier.get("tuft", 1.0))
		if RoadScatter.hash01(cell.x, cell.y, 531) * 100.0 < tc:
			tufts.append(_road_edge_xform(cell, open_dirs, 533, 0.0))
			_road_tuft_cells += 1

		# --- 1 hucre disina kacak tas ---
		if not bool(tier.get("stray", true)):
			continue
		for i in open_dirs:
			var g: Vector2i = cell + ROAD_NB[i]
			if _road_spill.has(g) or not _road_spill_ok(g):
				continue
			if RoadScatter.hash01(g.x, g.y, 541) * 100.0 \
					>= float(RoadScatter.STRAY_CHANCE):
				continue
			_road_spill[g] = true
			var ss: float = RoadScatter.STRAY_SCALE_MIN \
					+ RoadScatter.hash01(g.x, g.y, 543) \
					* (RoadScatter.STRAY_SCALE_MAX - RoadScatter.STRAY_SCALE_MIN)
			var rr: float = RoadScatter.hash01(g.x, g.y, 547) * TAU
			var gx: float = (RoadScatter.hash01(g.x, g.y, 549) - 0.5) * 0.5
			var gz: float = (RoadScatter.hash01(g.x, g.y, 551) - 0.5) * 0.5
			stray.append(Transform3D(
					Basis().rotated(Vector3.UP, rr).scaled(Vector3(ss, ss, ss)),
					_cell_center(g) + Vector3(gx, 0.0, gz)))
			_road_stray_cells += 1

	var sn := _road_scatter_node(tas, tonlar)
	if sn != null:
		add_child(sn)
		_road_nodes.append(sn)
	if not moss.is_empty():
		var mn := _road_moss_node(moss)
		if mn != null:
			add_child(mn)
			_road_nodes.append(mn)
	if not tufts.is_empty():
		var tn := _env_scatter_node("grass_tuft", tufts,
				RoadScatter.EDGE_TUFT_SPAN)
		if tn != null:
			add_child(tn)
			_road_nodes.append(tn)
	if not stray.is_empty():
		var yn := _env_scatter_node("path_stone", stray)
		if yn != null:
			add_child(yn)
			_road_nodes.append(yn)

## Serpinti MultiMesh'i.
## YUKSEKLIK KURALI burada uygulaniyor: model Z-up geldigi icin X'te -90
## yatiriliyor, boylece modelin KALINLIGI dunya Y'sine geciyor. Ust yuz
## TOP_ABOVE kadar disarida kalacak sekilde asagi kaydiriliyor. Hicbir
## eksende yassilastirma YOK — "zemine ezilmis leke" tam olarak bundan
## kacinmak icin yasak.
func _road_scatter_node(list: Array, tonlar: Array) -> Node3D:
	if list.is_empty():
		return null
	var mesh := _road_scatter_mesh()
	if mesh == null:
		return null
	var aabb := mesh.get_aabb()
	# Z-up model: ayak izi XY, kalinlik Z. Yatirma sonrasi Y = eski Z.
	var span: float = maxf(0.001, maxf(aabb.size.x, aabb.size.y)) \
			if RoadScatter.MODEL_Z_UP \
			else maxf(0.001, maxf(aabb.size.x, aabb.size.z))
	var k: float = RoadScatter.CELL_SPAN / span
	# Yatirma sonrasi ust yuzun model-uzayindaki yeri
	var top: float = (aabb.position.z + aabb.size.z) if RoadScatter.MODEL_Z_UP \
			else (aabb.position.y + aabb.size.y)
	var yatir := Basis()
	if RoadScatter.MODEL_Z_UP:
		yatir = Basis().rotated(Vector3.RIGHT, -PI * 0.5)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true          # instance_count'tan ONCE acilmali
	mm.mesh = mesh
	mm.instance_count = list.size()
	for i in list.size():
		var t: Transform3D = list[i]
		var s: float = t.basis.get_scale().x * k
		var b: Basis = Basis().rotated(Vector3.UP, t.basis.get_euler().y) * yatir
		b = b.scaled(Vector3(s, s, s))
		var y: float = RoadScatter.TOP_ABOVE - top * s
		mm.set_instance_transform(i, Transform3D(b, t.origin + Vector3(0, y, 0)))
		var tc: Color = tonlar[i]
		mm.set_instance_color(i, tc)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			if RoadScatter.CAST_SHADOW \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

var _scatter_mesh_cache: Mesh = null

func _road_scatter_mesh() -> Mesh:
	if _scatter_mesh_cache != null:
		return _scatter_mesh_cache
	if not ResourceLoader.exists(RoadScatter.MODEL_PATH):
		return null
	var scene: Node = load(RoadScatter.MODEL_PATH).instantiate()
	_tame_meshy_materials(scene, RoadScatter.TINT)
	for mi2: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if mi2.mesh == null:
			continue
		_scatter_mesh_cache = mi2.mesh
		# GLTF materyali surface_override'da durur; MultiMesh yalniz
		# MESH'i kullanir -> tasinmazsa taslar BEMBEYAZ cikar.
		if _scatter_mesh_cache is ArrayMesh:
			for si in _scatter_mesh_cache.get_surface_count():
				var sm := mi2.get_active_material(si)
				if sm is StandardMaterial3D:
					var m: StandardMaterial3D = sm
					# Hucre basina ton oynamasi ornek RENGIYLE veriliyor;
					# materyalin onu albedoya carpmasi icin sart.
					m.vertex_color_use_as_albedo = true
					(_scatter_mesh_cache as ArrayMesh).surface_set_material(si, m)
		break
	scene.queue_free()
	return _scatter_mesh_cache

## Sacilma yalnizca YURUNEBILIR, bos zemine (cim/toprak/kum) duser.
func _road_spill_ok(g: Vector2i) -> bool:
	if _objects.has(g) or _placed.has(g):
		return false
	if int(_depth.get(g, 0)) != 0:
		return false
	return String(_ground_char.get(g, "")) in [".", "d", "s"]

## Kenar dekorunu hucrenin ACIK tarafina dogru kaydirir (yosun/ot tam
## kenarda ciksin, ortada degil — "aralardan cikan ot" hissi).
func _road_edge_xform(cell: Vector2i, open_dirs: Array[int], salt: int,
		span: float) -> Transform3D:
	var d: Vector2i = ROAD_NB[open_dirs[int(RoadTiles.hash01(cell.x, cell.y, salt)
			* float(open_dirs.size())) % open_dirs.size()]]
	var jitter: float = (RoadTiles.hash01(cell.x, cell.y, salt + 1) - 0.5) * 0.5
	# 0.38 disariya dogruydu (ot cimde bitiyordu). 0.30: tutam karonun
	# KENARINDA, govdesi karonun USTUNDE kaliyor — istenen "cim karoya
	# biniyor" etkisi bu.
	var off := Vector3(float(d.x) * 0.30 + (0.0 if d.x != 0 else jitter), 0.0,
			float(d.y) * 0.30 + (0.0 if d.y != 0 else jitter))
	var sc: float = 0.75 + RoadTiles.hash01(cell.x, cell.y, salt + 2) * 0.5
	var b := Basis().rotated(Vector3.UP,
			RoadTiles.hash01(cell.x, cell.y, salt + 3) * TAU)
	b = b.scaled(Vector3(sc, sc, sc))
	# Karo ustune otursun: SINK kadar asagi degil, karo yuzeyinde
	return Transform3D(b, _cell_center(cell) + off + Vector3(0, 0.01, 0))

## Derz dekoru: karonun YUZEYINDE serbest konum (kenara bagli degil).
func _road_face_xform(cell: Vector2i, salt: int) -> Transform3D:
	var ox: float = (RoadTiles.hash01(cell.x, cell.y, salt) - 0.5) * 0.7
	var oz: float = (RoadTiles.hash01(cell.x, cell.y, salt + 1) - 0.5) * 0.7
	var sc: float = 0.7 + RoadTiles.hash01(cell.x, cell.y, salt + 2) * 0.6
	var b := Basis().rotated(Vector3.UP,
			RoadTiles.hash01(cell.x, cell.y, salt + 3) * TAU)
	b = b.scaled(Vector3(sc, sc, sc))
	# Karo ust yuzunun uzerinde
	return Transform3D(b, _cell_center(cell)
			+ Vector3(ox, RoadTiles.TOP_ABOVE, oz))

## Karo MultiMesh'i: KOK olcegi hucreye normalize, ust yuzu cim
## seviyesinin SINK kadar ALTINA oturur (gomuk yol).
var _road_mesh_cache: Dictionary = {}

func _road_tile_node(id: String, list: Array) -> Node3D:
	var mesh := _road_mesh(id)
	if mesh == null:
		return null
	var aabb := mesh.get_aabb()
	# Model XY duzleminde: hucre genisligi X, kalinlik Z (yatirma sonrasi Y)
	var span: float = maxf(0.001, maxf(aabb.size.x, aabb.size.y))
	var k: float = RoadTiles.TILE_SPAN / span
	var thick: float = aabb.size.z * k
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = list.size()
	for i in list.size():
		var t: Transform3D = list[i]
		var b: Basis = t.basis.scaled(Vector3(k, k, k))
		# Yatirma sonrasi kalinlik Y'de ve karo merkezli: govde zemine
		# gomulur, ust yuzu TOP_ABOVE kadar disarida kalir.
		var y: float = RoadTiles.TOP_ABOVE - thick * 0.5
		mm.set_instance_transform(i, Transform3D(b, t.origin + Vector3(0, y, 0)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	# Derz golgeleri hacmi okutan sey: yol karolarinda golge ACIK.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			if RoadTiles.TILE_SHADOWS else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _road_mesh(id: String) -> Mesh:
	if _road_mesh_cache.has(id):
		return _road_mesh_cache[id]
	var glb := RoadTiles.path_of(id)
	if glb == "" or not ResourceLoader.exists(glb):
		return null
	var scene: Node = load(glb).instantiate()
	_tame_meshy_materials(scene, RoadTiles.TILE_TINT)
	var mesh: Mesh = null
	for mi2: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if mi2.mesh == null:
			continue
		mesh = mi2.mesh
		# GLTF materyali cogu zaman surface_override'da durur; MultiMesh
		# yalniz MESH'i kullanir -> tasinmazsa karo BEMBEYAZ cikar.
		if mesh is ArrayMesh:
			for si in mesh.get_surface_count():
				var sm := mi2.get_active_material(si)
				if sm != null:
					(mesh as ArrayMesh).surface_set_material(si, sm)
		break
	scene.queue_free()
	_road_mesh_cache[id] = mesh
	return mesh

## Yosun lekesi: moss_patch GLB'si repoda YOK -> yassi proseduerel disk
## (palet: yaprak adacayi). Dosya gelince otomatik ona gecer.
var _moss_mesh: Mesh = null

func _road_moss_mesh() -> Mesh:
	if _moss_mesh != null:
		return _moss_mesh
	if RoadTiles.has_model("moss_patch"):
		var scene: Node = load(RoadTiles.path_of("moss_patch")).instantiate()
		_tame_meshy_materials(scene, Color.WHITE)
		for mi2: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			if mi2.mesh == null:
				continue
			_moss_mesh = mi2.mesh
			if _moss_mesh is ArrayMesh:
				for si in _moss_mesh.get_surface_count():
					var sm := mi2.get_active_material(si)
					if sm != null:
						(_moss_mesh as ArrayMesh).surface_set_material(si, sm)
			break
		scene.queue_free()
	# Fallback KAPALI: duz yesil disk karede nilufer yapragi gibi duruyor.
	# Gercek moss_patch.glb gelene kadar yosun cizilmez.
	return _moss_mesh

func _road_moss_node(list: Array) -> Node3D:
	var mesh := _road_moss_mesh()
	if mesh == null:
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

# --- SPAWN KAMPI (gorsel-tur / Gorev Eki) --------------------------------
# Mockup'taki "Duvarli Kamp + Kulube" duzeninin YIPRANMIS hali. Iskelet
# mockup'la ayni: ocak merkezde, kulube kuzeybatida, tarla doguda, kuyu
# tarlanin kuzeyinde, uretim kosesi guneybatida, yollar ocaktan dort yone.
# DUVAR / HENDEK / HUNI YOK — onlar oyuncunun ileride kendi insa hedefi.
#
# HEPSI DEKOR: hicbiri _set_placed'den gecmez, _structures'a yazilmaz,
# kayda girmez, etkilesim vermez (gorevin "MEKANIK YOK" sarti). Ocak sonuk,
# masa/sandik devrik, mesaleler yanmiyor — oyuncu kampi kendi canlandiracak.
# Tek fiziksel etki: kulube ve kuyu hucreleri _solid_cells'e girer, yoksa
# oyuncu duvarin icinden gecerdi (arazi carpismasi, mekanik degil).
# YERLESIM ARTIK PREFAB'TA: scenes/prefabs/camp_start.tscn. Kod koordinat
# TASIMAZ — her ogenin yeri/donusu sahnedeki dugumden okunur (Godot
# editorunde elle tasi, F5, oyunda ayni yerde). Dugumler SABIT YOLLA
# degil meta ile bulunur: her ogede metadata/oge = "ocak"|"hut"|... var,
# yani dugumleri yeniden adlandirmak/gruplamak hicbir seyi bozmaz.
# YOL HUCRELERI sahneye girmez (ayri sistem, CAMP_ROADS asagida).
const CAMP_SCENE := "res://scenes/prefabs/camp_start.tscn"
## Yol uzunluklari (hucre). Guney yolu kampi ASAR ve yolun ortasinda biter:
## "buradan bir yere gidiliyordu" hissi (mockup'taki ana giris aksi).
const CAMP_ROADS := [
	{"dir": Vector2i(0, -1), "len": 5},
	{"dir": Vector2i(1, 0), "len": 6},
	{"dir": Vector2i(-1, 0), "len": 6},
	{"dir": Vector2i(0, 1), "len": 13},
]
## KAMP ACIKLIGI (iki kademe): CLEAR_R icinde agac/kaya HIC yok — kamp
## nefes alsin; CLEAR_R..FADE_R arasi seyrek (ormana yumusak gecis, sert
## bir "agac duvari" cizgisi olusmasin).
const CAMP_CLEAR_R := 8     # bu yaricapta agac/kaya SIFIR
const CAMP_FADE_R := 12     # bu yaricapa kadar seyrek (CLEAR_R'den sonra)
const CAMP_FADE_KEEP := 45  # gecis halkasinda agac/kayanin ~%45'i kalir
const CAMP_RADIUS := CAMP_FADE_R  # serpinti yogunlastirma + kamp hucre kumesi
const CAMP_SCATTER_BOOST := 2.0  # kamp icinde dal/kuru ot yogunlugu carpani
const EDGE_SCATTER_BOOST := 1.7  # zemin yamasi sinirinda serpinti carpani

var _camp_center := Vector2i(-999, -999)
var _camp_cells: Dictionary = {}   # kamp yaricapi (serpinti yogunlugu icin)
var _camp_field: Dictionary = {}   # tarla dekor hucreleri -> true
var _camp_nodes: Array = []        # kamp dekor dugumleri
## Tarla dekoru hucre basina: oyuncu o hucreyi GERCEKTEN capalarsa dekor
## silinir, yoksa terk edilmis sirt ile gercek tarla ust uste binerdi.
var _camp_field_nodes: Dictionary = {}  # cell -> Array[Node3D]

func _camp_register_field_node(cell: Vector2i, node: Node3D) -> void:
	if not _camp_field_nodes.has(cell):
		_camp_field_nodes[cell] = []
	var list: Array = _camp_field_nodes[cell]
	list.append(node)

func _camp_clear_field_decor(cell: Vector2i) -> void:
	if not _camp_field_nodes.has(cell):
		return
	var list: Array = _camp_field_nodes[cell]
	for n in list:
		if is_instance_valid(n):
			n.queue_free()
	_camp_field_nodes.erase(cell)

## Prefabtan okunan ogeler: id -> Array[{off: Vector2i, yaw: float}]
var _camp_items: Dictionary = {}

func _camp_at(key: String) -> Vector2i:
	if _camp_center == Vector2i(-999, -999):
		return _camp_center
	var list: Array = _camp_items.get(key, [])
	if list.is_empty():
		return _camp_center   # prefabta yoksa merkez (guvenli varsayilan)
	return _camp_center + Vector2i(list[0]["off"])

func _camp_yaw(key: String) -> float:
	var list: Array = _camp_items.get(key, [])
	return float(list[0]["yaw"]) if not list.is_empty() else 0.0

## Coklu ogeler (mesale, tarla): mutlak hucre listesi.
func _camp_cells_of(key: String) -> Array:
	var out: Array = []
	for it: Dictionary in _camp_items.get(key, []):
		out.append(_camp_center + Vector2i(it["off"]))
	return out

## Prefabi BELLEKTE acar, ogeleri toplar, sahneyi serbest birakir.
## Sahne oyuna EKLENMEZ: gorseller mevcut prop hattiyla (ton/olcek/devrik
## durus) kurulur; prefab yalniz YERLESIM verisi. Boylece editor onizlemesi
## ile oyun gorseli ayrisamaz — ikisi de ayni konumdan beslenir.
func _camp_load_items() -> void:
	_camp_items.clear()
	if not ResourceLoader.exists(CAMP_SCENE):
		push_error("Kamp prefabi bulunamadi: " + CAMP_SCENE)
		return
	var root: Node3D = (load(CAMP_SCENE) as PackedScene).instantiate()
	_camp_collect(root, root, _camp_items)
	root.free()

## Ic ice dugumler (Tarla/Tumsek1) icin koke gore birlesik donusum.
func _prefab_xform(node: Node3D, root: Node3D) -> Transform3D:
	var t := node.transform
	var pn := node.get_parent()
	while pn != null and pn != root and pn is Node3D:
		t = (pn as Node3D).transform * t
		pn = pn.get_parent()
	return t

func _camp_collect(node: Node, root: Node3D, out: Dictionary) -> void:
	for ch in node.get_children():
		if ch is Node3D and (ch as Node3D).has_meta("oge"):
			var t := _prefab_xform(ch as Node3D, root)
			var id := String((ch as Node3D).get_meta("oge"))
			if not out.has(id):
				out[id] = []
			out[id].append({
				"off": Vector2i(roundi(t.origin.x), roundi(t.origin.z)),
				"yaw": rad_to_deg(t.basis.get_euler().y),
			})
		_camp_collect(ch, root, out)

## ARAZI ASAMASI: _build_terrain'den ONCE calisir. Nesne temizligi, yollar,
## kuru kanal derinligi ve dogus hucresi burada belirlenir.
func _camp_plan() -> void:
	_camp_center = _spawn_cell
	_camp_load_items()   # yerlesim prefabtan (scenes/prefabs/camp_start.tscn)
	_camp_cells.clear()
	_camp_field.clear()
	# 1) Kamp acikligi. Ic daire (CLEAR_R) tamamen bosaltilir; disindaki
	#    halkada (FADE_R'ye kadar) agaclarin bir kismi kalir ki ormana
	#    gecis sert bir cizgi olmasin.
	for dy in range(-CAMP_FADE_R, CAMP_FADE_R + 1):
		for dx in range(-CAMP_FADE_R, CAMP_FADE_R + 1):
			var r2 := dx * dx + dy * dy
			if r2 > CAMP_FADE_R * CAMP_FADE_R:
				continue
			var c := _camp_center + Vector2i(dx, dy)
			_camp_cells[c] = true
			if not _objects.has(c):
				continue
			if r2 > CAMP_CLEAR_R * CAMP_CLEAR_R:
				# Gecis halkasi: seyrelt (yapi ayak izinde istisna yok)
				var keep: bool = int(EnvModels.hash01(c.x, c.y, 401) * 100.0) \
						< CAMP_FADE_KEEP
				if keep and not _camp_build_footprint(c):
					continue
			_objects.erase(c)
			_solid_cells.erase(c)
	# 1b) YUKSELTIYI DUZLE: kampin dibindeki yuksek plato ("h") kare
	#     kenarli falez duvarlariyla kampa bitisiyordu (kullanici karari:
	#     "suradaki yukseltiye gerek yok"). Kamp halkasi icindeki plato
	#     hucreleri duz cime cevrilir; boylece kamp cevresi tek duzlemde
	#     kalir ve arazi renk harmani da duz zemin uzerinden hesaplanir.
	for cell: Vector2i in _camp_cells:
		if String(_ground_char.get(cell, ".")) != "h":
			continue
		_ground_char[cell] = "."
		_solid_cells.erase(cell)
	# 2) Yollar: ocaktan dort yone asinmis serit.
	var hearth := _camp_at("ocak")
	for r: Dictionary in CAMP_ROADS:
		var rd: Vector2i = r["dir"]
		_add_path_strip(hearth, rd, int(r["len"]))
	lay_road(hearth, "miras")
	# KIVRIMLI ANA YOL: kampin guney aksindan cikip kavis cizerek
	# uzaklasir. Auto-tiling ve kenar erimesi ancak GENIS ve EGRI bir
	# yolda okunur — dar duz seritte her hucrenin iki yani birden acik
	# oldugu icin kenar karosu hic devreye girmez (bkz. RAPOR).
	# Genislik EN FAZLA 2 (kullanici karari: 3 hucre kalin yama gibi
	# duruyordu). Yol bir HAT; kalinlik degil kavis okunmali.
	_add_road_curve(hearth + Vector2i(0, 6), 18, 2, "miras")
	# OYUNCUNUN DOSEDIGI kisa yeni yol: ayni sistem, yosun neredeyse yok.
	# Eski/yeni farki tek bir arayuz olmadan gorselden okunur.
	_add_path_strip(hearth + Vector2i(2, 2), Vector2i(1, 0), 5, "yeni", 2)
	# 3) Tarla (2x2). Bati kenarindaki "kuru kanal" KALDIRILDI: kazi
	#    derinligi arazide kare kenarli bir BLOK YUKSELTI uretiyordu
	#    (kose kose, dogal degil) ve dekoratif degeri yoktu.
	# Tarla hucreleri prefabtaki Tumsek dugumlerinden (2x2 varsayimi yok:
	# sahneye tumsek ekle/cikar, tarla ona gore buyur/kuculur).
	for fc: Vector2i in _camp_cells_of("tarla"):
		_camp_field[fc] = true
	# 4) Dogus: kulubenin ONUNDE (kapi guneye bakiyor).
	_spawn_cell = _camp_at("hut") + Vector2i(0, 2)
	_objects.erase(_spawn_cell)
	_solid_cells.erase(_spawn_cell)

## Kamp yapilarinin ayak izi (agac/kaya kesinlikle temizlenir).
func _camp_build_footprint(c: Vector2i) -> bool:
	for id: String in _camp_items:
		var r := 2 if id == "hut" else 1
		for it: Dictionary in _camp_items[id]:
			var p: Vector2i = _camp_center + Vector2i(it["off"])
			if absi(c.x - p.x) <= r and absi(c.y - p.y) <= r:
				return true
	return false

## GORSEL ASAMA: _rebuild_objects'ten SONRA calisir (dekor dugumleri).
func _build_spawn_camp() -> void:
	for n in _camp_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_camp_nodes.clear()
	_camp_field_nodes.clear()
	if _camp_center == Vector2i(-999, -999):
		return
	# TUM konum/donusler prefabtan (_camp_items). Kod yalniz "hangi id
	# nasil cizilir" bilgisini tasir; NEREDE oldugunu sahne soyler.
	# Ocak — SONUK (ates yok; _activate_hearth cagrilmaz)
	_camp_prop_structure("ocak", _camp_at("ocak"), _camp_yaw("ocak"), false)
	# Yikik kulube: 3x3 ayak izi kati, guney-orta hucre kapi (giris)
	var hut := _camp_at("hut")
	_camp_prop_env("ruined_hut", hut, _camp_yaw("hut"))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 1:
				continue  # kapi
			_solid_cells[hut + Vector2i(dx, dy)] = true
	# Kuyu
	var well := _camp_at("well")
	_camp_prop_env("ruined_well", well, _camp_yaw("well"))
	_solid_cells[well] = true
	# Terk edilmis tarla: her hucrede sirt + uzerinde solmus bitki
	var fi := 0
	for cell: Vector2i in _camp_field:
		_camp_prop_mound(cell)
		if fi % 4 != 3:  # bir hucre bos (bitki tamamen olmus)
			_camp_prop_withered(cell)
		fi += 1
	_camp_prop_pumpkin(_camp_at("kabak"))
	# Uretim kosesi: solmus/devrik arastirma masasi + devrik bos sandik.
	# TEZGAH YOK — ilk tezgahi oyuncu kuracak (mockup'taki bosluk kasitli).
	_camp_prop_structure("arastirma_masasi", _camp_at("masa"), _camp_yaw("masa"), true)
	_camp_prop_structure("sandik", _camp_at("sandik"), _camp_yaw("sandik"), true)
	# Sonuk mesale direkleri (isik EKLENMEZ)
	for mc: Vector2i in _camp_cells_of("mesale"):
		_camp_prop_structure("mesale", mc, 0.0, false)

## Mevcut yapi gorselini DEKOR olarak koyar (veri yok, etkilesim yok).
## tilt=true ise devrik/yipranmis durus (13.4'teki hasarli goruntunun aynisi).
func _camp_prop_structure(item_id: String, cell: Vector2i, yaw: float,
		tilt: bool) -> void:
	if _placed.has(cell):
		return  # oyuncu oraya bir sey koyduysa dekor cizilmez
	var holder := _build_structure_visual(item_id)
	holder.position = _cell_center(cell)
	holder.rotation_degrees.y = yaw
	if tilt:
		holder.rotation_degrees.z = 14.0
		holder.position.y -= 0.06
	add_child(holder)
	_camp_nodes.append(holder)

## GLB propu (kulube/kuyu): olcek KOK dugume verilir (node scale YASAK
## dersi: ic dugumlere dokunulmaz), hedef YUKSEKLIGE normalize edilir.
func _camp_prop_env(id: String, cell: Vector2i, yaw: float) -> void:
	var glb := EnvModels.path_of(id)
	if not ResourceLoader.exists(glb):
		return
	var root := Node3D.new()
	var inst: Node3D = load(glb).instantiate()
	root.add_child(inst)
	_tame_meshy_materials(inst, EnvModels.tint_of(id))
	var aabb := _scene_aabb(inst)
	if aabb.size.y > 0.01:
		var s: float = EnvModels.scale_of(id) / aabb.size.y
		inst.scale = Vector3(s, s, s)
		inst.position.y = -aabb.position.y * s
	root.position = _cell_center(cell)
	root.rotation_degrees.y = yaw
	add_child(root)
	_camp_nodes.append(root)

## Terk edilmis tarlanin sirti (bos surulu tarla gostergesiyle ayni model).
func _camp_prop_mound(cell: Vector2i) -> void:
	var node := _build_mound_from(MOUND_EMPTY)
	if node == null:
		return
	node.position = _cell_center(cell)
	add_child(node)
	_camp_nodes.append(node)
	_camp_register_field_node(cell, node)

## Solmus bitki: genc ekin modeli, kurumus tonda ve kucuk.
## Hoyuk 0.42 m'ye inince 26 cm bitki hoyukten BUYUK kaldi ve onu ortuyordu
## (kamp tarla karesinde hoyuk yerine yesil yumak gorunuyordu) -> 15 cm.
const CAMP_WITHER_TINT := Color(0.52, 0.44, 0.26)
const CAMP_WITHER_H := 0.15

func _camp_prop_withered(cell: Vector2i) -> void:
	var glb := "res://assets/models/test/small_young_berry.glb"
	if not ResourceLoader.exists(glb):
		return
	var root := Node3D.new()
	var inst: Node3D = load(glb).instantiate()
	root.add_child(inst)
	_tame_meshy_materials(inst, CAMP_WITHER_TINT)
	var aabb := _scene_aabb(inst)
	if aabb.size.y > 0.01:
		var s: float = CAMP_WITHER_H / aabb.size.y
		inst.scale = Vector3(s, s, s)
		inst.position.y = -aabb.position.y * s
	root.position = _cell_center(cell) + Vector3(0.0, 0.04, 0.0)
	root.rotation_degrees = Vector3(0.0, float(cell.x * 47 % 360), 9.0)
	add_child(root)
	_camp_nodes.append(root)
	_camp_register_field_node(cell, root)

## Dekoratif kabak: kabak GLB'si YOK -> proseduerel (yassi kure + sap),
## duz renk paletiyle uyumlu sicak turuncu.
func _camp_prop_pumpkin(cell: Vector2i) -> void:
	var root := Node3D.new()
	var body := SphereMesh.new()
	body.radius = 0.22
	body.height = 0.34
	body.radial_segments = 10
	body.rings = 5
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.78, 0.44, 0.18)
	bm.roughness = 0.9
	body.material = bm
	var bi := MeshInstance3D.new()
	bi.mesh = body
	bi.position.y = 0.17
	root.add_child(bi)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.03
	stem.bottom_radius = 0.045
	stem.height = 0.12
	var smat := StandardMaterial3D.new()
	smat.albedo_color = EnvModels.FALLBACK_LEAF
	smat.roughness = 0.95
	stem.material = smat
	var si := MeshInstance3D.new()
	si.mesh = stem
	si.position.y = 0.38
	root.add_child(si)
	root.position = _cell_center(cell)
	add_child(root)
	_camp_nodes.append(root)



# --- PERF SONDASI (gorsel-tur once/sonra) --------------------------------
# "Once/sonra FPS" icin AYNI karede iki olcum: bu dalin ekledigi her sey
# (serpinti + yol taslari + kamp dekoru) ACIK ve KAPALI. Ayri bir main
# kosusuna gerek kalmiyor, olcum ayni donanim/ayni kare uzerinde.
func _perf_sample(frames: int) -> Dictionary:
	var fps_sum := 0.0
	var draw_sum := 0.0
	for i in frames:
		await get_tree().process_frame
		fps_sum += Performance.get_monitor(Performance.TIME_FPS)
		draw_sum += Performance.get_monitor(
				Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return {"fps": fps_sum / maxf(1.0, float(frames)),
			"draw": draw_sum / maxf(1.0, float(frames))}

func _perf_set_visual(on: bool) -> void:
	for arr: Array in [_env_scatter_nodes, _path_nodes, _road_nodes, _camp_nodes]:
		for n in arr:
			if is_instance_valid(n) and n is Node3D:
				(n as Node3D).visible = on

func _run_perf_probe(save_path: String) -> void:
	var ctr := _cell_center(_camp_center)
	camera.position = ctr + Vector3(0.0, 9.0, 11.0)
	camera.look_at(ctr)
	await get_tree().create_timer(0.5).timeout
	# ORNEK SAYISI KUCUK OLMALI: CI sanal ekranda ~1 FPS ile koser, yani
	# her ornek ~1 SANIYE. 45+45 ornek tek basina ~90 sn yiyip vitrin
	# karelerini butce disina itmisti. Cizim cagrisi kare kare sabit
	# oldugu icin 8 ornek yeterli.
	_perf_set_visual(false)
	var before: Dictionary = await _perf_sample(8)
	_perf_set_visual(true)
	var after: Dictionary = await _perf_sample(8)
	var line := ("PERFTEST: kamp kamerasi | ONCE fps=%.1f draw=%.0f | "
			+ "SONRA fps=%.1f draw=%.0f | serpinti_dugum=%d yol_dugum=%d "
			+ "kamp_dugum=%d yol_karo_dugum=%d") % [
		float(before["fps"]), float(before["draw"]),
		float(after["fps"]), float(after["draw"]),
		_env_scatter_nodes.size(), _path_nodes.size(), _camp_nodes.size(),
		_road_nodes.size()]
	print(line)
	var f := FileAccess.open("res://docs/screens/perftest.txt", FileAccess.WRITE)
	if f != null:
		f.store_line(line)
		f.close()


# --- ROADTEST: tas yol sistemi dogrulamasi -------------------------------
# Sistem SALT GORSEL: test de gorsel dogruluga bakar. SERPINTI modelinde
# olculen sey karo hizasi degil, "yol okunuyor mu + kenar cizgisi var mi":
#   - hucre basina tek serpinti ornegi doseniyor mu
#   - uc rampasi calisti mi (terminal hucrelerde kucuk olcek)
#   - kenar hucrelerinde 0-1 cim tutami, disariya kacak tas
#   - miras/yeni yosun farki
func _run_road_test(save_path: String) -> void:
	var miras := 0
	var yeni := 0
	for cell: Vector2i in _path_cells:
		if String(_path_cells[cell]) == "yeni":
			yeni += 1
		else:
			miras += 1
	var kenar := 0
	for cell: Vector2i in _path_cells:
		var open_n := 0
		for d: Vector2i in ROAD_NB:
			if not _path_cells.has(cell + d):
				open_n += 1
		if open_n > 0:
			kenar += 1
	var ornek := 0
	for n in _road_nodes:
		if not is_instance_valid(n) or not (n is MultiMeshInstance3D):
			continue
		var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
		if mm == null:
			continue
		ornek += mm.instance_count
	var moss_var: bool = RoadTiles.has_model("moss_patch")
	# ZEMIN KONTROLU (gorev 1): yol hucresinde zemin CIM kalmali, toprak
	# boyama/serit OLMAMALI. Gozle bakmak yaniltir — ilk karede yolun
	# altinda kahverengi bir bant vardi ama olculdugunde o bandin YOLDAN
	# GELMEDIGI, arazinin kendi toprak lekesi oldugu goruldu. Sayi:
	# yol hucrelerinin zemin karakteri dagilimi.
	var zemin: Dictionary = {}
	for cell: Vector2i in _path_cells:
		var gch := String(_ground_char.get(cell, "?"))
		zemin[gch] = int(zemin.get(gch, 0)) + 1
	# Model olculeri (yukseklik kaniti rakamla)
	var kalinlik := 0.0
	var mesh := _road_scatter_mesh()
	if mesh != null:
		var ab := mesh.get_aabb()
		var sp: float = maxf(ab.size.x, ab.size.y)
		kalinlik = ab.size.z * (RoadScatter.CELL_SPAN / maxf(0.001, sp))

	# --- (a) TEK HUCRE YANDAN: yukseklik kaniti ---
	# Kamera neredeyse zemin hizasinda: taslarin zeminden ciktigi
	# gorulmezse gorev sarti saglanmamis demektir.
	var tek := _road_lone_cell()
	var tp := _cell_center(tek)
	_cam_locked = true
	camera.position = tp + Vector3(0.0, 0.22, 1.6)
	camera.look_at(tp + Vector3(0.0, 0.03, 0.0))
	await get_tree().create_timer(0.7).timeout
	_snap(save_path.replace(".png", "_yol_tek_yandan.png"))

	# --- (b) KAVISLI YOL, ORTA MESAFE ---
	var focus := _camp_center + Vector2i(2, 12)
	var fp := _cell_center(focus)
	camera.position = fp + Vector3(-3.2, 2.6, 4.2)
	camera.look_at(fp + Vector3(0.5, 0.0, 0.0))
	await get_tree().create_timer(0.7).timeout
	_snap(save_path.replace(".png", "_yol.png"))
	# Tepeden: yol ile cim arasinda net cizgi kalmamali ama yol okunmali
	camera.position = fp + Vector3(0.0, 9.0, 0.01)
	camera.look_at(fp)
	await get_tree().create_timer(0.7).timeout
	_snap(save_path.replace(".png", "_yol_tepe.png"))

	# --- (d) KAMP GENEL: gunduz + gece ---
	var cp := _cell_center(_camp_center)
	camera.position = cp + Vector3(2.0, 14.0, 20.0)
	camera.look_at(_cell_center(_camp_center + Vector2i(1, 9)))
	await get_tree().create_timer(0.7).timeout
	_snap(save_path.replace(".png", "_yol_genis.png"))
	DayNight.jump_to_night()
	_clear_creatures()
	await get_tree().create_timer(0.9).timeout
	_snap(save_path.replace(".png", "_yol_genis_gece.png"))
	# Gece yakin kare: tas rengi gece de parlamiyor mu
	camera.position = fp + Vector3(-3.2, 2.6, 4.2)
	camera.look_at(fp + Vector3(0.5, 0.0, 0.0))
	await get_tree().create_timer(0.9).timeout
	_snap(save_path.replace(".png", "_yol_gece.png"))
	DayNight.jump_to_day()
	await get_tree().create_timer(0.4).timeout

	var line := ("ROADTEST: model=serpinti hucre=%d (miras=%d yeni=%d) "
			+ "kenar=%d serpinti_hucre=%d derz=%d uc_hucre=%d tutam=%d "
			+ "kacak_tas=%d ornek_toplam=%d kalinlik=%.3fm disarida=%.3fm "
			+ "olcek=%.2f-%.2f tint=#%s jitter=%%%.0f "
			+ "yol_zemin=%s moss_glb=%s karo_modu=%s") % [
		_path_cells.size(), miras, yeni, kenar,
		_road_scatter_cells, _road_seam_count, _road_end_cells,
		_road_tuft_cells, _road_stray_cells, ornek, kalinlik,
		RoadScatter.TOP_ABOVE, RoadScatter.SCALE_MIN, RoadScatter.SCALE_MAX,
		RoadScatter.TINT.to_html(false), RoadScatter.TINT_JITTER * 100.0,
		str(zemin), str(moss_var), str(RoadTiles.TILE_MODE_ON)]
	print(line)
	var f := FileAccess.open("res://docs/screens/roadtest.txt", FileAccess.WRITE)
	if f != null:
		f.store_line(line)
		f.close()

## Yukseklik karesi icin haritanin bos bir yerine TEK yol hucresi koyar.
## Tek hucre bilerek: komsusu olmadigi icin uc kuralina girer ve hem
## yuksekligi hem uc olcegini ayni karede gosterir.
func _road_lone_cell() -> Vector2i:
	var c := _camp_center + Vector2i(9, 9)
	for i in 40:
		var t := c + Vector2i(i % 7, i / 7)
		if String(_ground_char.get(t, "")) in [".", "d"] \
				and not _objects.has(t) and not _placed.has(t) \
				and not _path_cells.has(t):
			lay_road(t, "yeni")
			_build_road()
			return t
	lay_road(c, "yeni")
	_build_road()
	return c

# --- VITRIN: yeni cevre/yapi modelleri (gorsel-tur Asama 1 dogrulamasi) ---
# Dokuz model, OYUNDAKI GERCEK olcegiyle (EnvModels.SCALE) yan yana. Amac:
# "yuklendi mi / dogru boyda mi / dokusu geldi mi" sorularini tek karede
# gormek. Gunduz + gece iki kare (gece karesinde beyaz cikan model hemen
# belli olur; ilk turda yol taslari boyle yakalandi).
const ENV_SHOWCASE := [
	{"id": "ruined_hut", "x": -9.0},
	{"id": "repaired_hut", "x": -4.5},
	{"id": "ruined_well", "x": -0.5},
	{"id": "planting_mound", "x": 2.0},
	{"id": "path_stone", "x": 3.6},
	{"id": "path_stone_mossy", "x": 4.8},
	{"id": "grass_tuft", "x": 6.0},
	{"id": "pebble_cluster", "x": 7.0},
	{"id": "twig_debris", "x": 8.0},
]

func _run_env_showcase(save_path: String) -> void:
	var base := Vector3(460.0, 30.0, 0.0)
	var root := Node3D.new()
	root.position = base
	add_child(root)
	var floor_inst := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(34, 18)
	floor_inst.mesh = floor_mesh
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.32, 0.55, 0.24)
	fm.roughness = 1.0
	floor_inst.material_override = fm
	root.add_child(floor_inst)
	var eksik: Array[String] = []
	for entry: Dictionary in ENV_SHOWCASE:
		var id := String(entry["id"])
		var glb := EnvModels.path_of(id)
		if not ResourceLoader.exists(glb):
			eksik.append(id)
			continue
		var holder := Node3D.new()
		holder.position = Vector3(float(entry["x"]), 0.0, 0.0)
		root.add_child(holder)
		var scene: Node3D = load(glb).instantiate()
		holder.add_child(scene)
		# Hoyuk oyunda AYRI yoldan kuruluyor (toprak tonu + ezme + taban
		# genisligine gore olcek). Vitrin de ayni degerleri kullanmali,
		# yoksa "vitrinde beyaz kubbe, oyunda kahve sirt" gibi yaniltir.
		var is_mound: bool = id == "planting_mound"
		_tame_meshy_materials(scene,
				MOUND_TINT if is_mound else EnvModels.tint_of(id))
		var aabb := _scene_aabb(scene)
		var sy := 1.0
		var s := 1.0
		if is_mound:
			var span: float = maxf(aabb.size.x, aabb.size.z)
			if span > 0.01:
				s = MOUND_FOOTPRINT / span
				sy = MOUND_FLATTEN
		elif aabb.size.y > 0.01:
			s = EnvModels.scale_of(id) / aabb.size.y
		# KOK olcegi (ic dugume dokunulmaz) — oyundaki ile AYNI hesap
		scene.scale = Vector3(s, s * sy, s)
		scene.position = Vector3(-aabb.get_center().x * s, -aabb.position.y * s * sy,
				-aabb.get_center().z * s)
		var label := Label3D.new()
		label.text = "%s\n%.2f m" % [id, EnvModels.scale_of(id)]
		label.font_size = 48
		label.pixel_size = 0.004
		label.position = Vector3(0, 0.15, 0.9)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		holder.add_child(label)
	camera.position = base + Vector3(-1.0, 4.2, 14.5)
	camera.rotation_degrees = Vector3(-12, 0, 0)
	await get_tree().create_timer(1.0).timeout
	_snap(save_path.replace(".png", "_vitrin_env.png"))
	# Gece karesi (ayni aci); dalga vitrin karesinde gereksiz
	DayNight.jump_to_night()
	_clear_creatures()
	await get_tree().create_timer(1.0).timeout
	_snap(save_path.replace(".png", "_vitrin_env_gece.png"))
	DayNight.jump_to_day()
	await get_tree().create_timer(0.4).timeout
	root.queue_free()
	print("VITRIN_ENV: model=%d eksik=%s" % [ENV_SHOWCASE.size(), str(eksik)])

# --- KAMPTEST: spawn kampi yerlesim dogrulamasi --------------------------
# Kamp SALT GORSEL oldugu icin test de gorsel/yerlesim dogruluguna bakar:
# parcalar yerinde mi, dogus kulubenin onunde ve yurunebilir mi, yollar
# ocaktan cikiyor mu, ates/isik GERCEKTEN sonuk mu (mekanik sizmadi mi).
func _run_camp_test(save_path: String) -> void:
	var c := _camp_center
	var hut := _camp_at("hut")
	var kapi := hut + Vector2i(0, 1)
	# 1) Dogus: kulubenin onunde, yurunebilir
	var dogus_on: bool = _spawn_cell == hut + Vector2i(0, 2)
	var dogus_bos: bool = not _solid_cells.has(_spawn_cell) \
			and not _objects.has(_spawn_cell)
	# 2) Kulube kati, kapi acik
	var kulube_kati: bool = _solid_cells.has(hut)
	var kapi_acik: bool = not _solid_cells.has(kapi)
	# 3) Yollar: dort yonde de yol hucresi var mi
	var yol_yon := 0
	for r: Dictionary in CAMP_ROADS:
		var rd: Vector2i = r["dir"]
		if _path_cells.has(c + rd * 2):
			yol_yon += 1
	# 4) MEKANIK SIZMASI YOK: aktif ocak yok, mesale isigi yok, kamp
	#    parcalarindan hicbiri _placed/_structures'a yazilmadi
	var ocak_yanmiyor: bool = get_hearth() == Vector2i(-999, -999)
	var isik_yok: bool = _torch_lights.is_empty()
	var veri_temiz := true
	for key: String in ["ocak", "masa", "sandik", "well"]:
		if _placed.has(_camp_at(key)):
			veri_temiz = false
	for mc: Vector2i in _camp_cells_of("mesale"):
		if _placed.has(mc):
			veri_temiz = false
	# 5) Tarla: 4 hucre dekor
	var tarla := _camp_field.size()
	var tl := _camp_cells_of("tarla")
	var f: Vector2i = tl[0] if not tl.is_empty() else c
	# 6) Kamp acikligi: IC DAIRE tamamen bos mu, gecis halkasi seyrek mi
	var ic_dolu := 0
	var dolu := 0
	for cell: Vector2i in _camp_cells:
		if not _objects.has(cell):
			continue
		dolu += 1
		var dc := cell - c
		if dc.x * dc.x + dc.y * dc.y <= CAMP_CLEAR_R * CAMP_CLEAR_R:
			ic_dolu += 1
	var aciklik_bos: bool = ic_dolu == 0
	var doluluk: float = float(dolu) / maxf(1.0, float(_camp_cells.size())) * 100.0

	# Kareler: mockup acisiyla genis kamp + tarla yakin plani
	var ctr := _cell_center(c)
	camera.position = ctr + Vector3(0.0, 15.0, 17.0)
	camera.look_at(ctr)
	await get_tree().create_timer(0.8).timeout
	_snap(save_path.replace(".png", "_kamp.png"))
	var fc := _cell_center(f) + Vector3(0.5, 0.0, 0.5)
	camera.position = fc + Vector3(-2.6, 2.0, 3.0)
	camera.look_at(fc + Vector3(0, 0.2, 0))
	await get_tree().create_timer(0.6).timeout
	_snap(save_path.replace(".png", "_kamp_tarla.png"))
	# Gece: sonuk kampin gece hali (mesaleler yanmiyor — kasitli).
	# Dalga hemen temizlenir: bu kare ISIK karesi, yaratik testi degil —
	# yaratiklarin her karede islemesi CI butcesini yiyordu.
	DayNight.jump_to_night()
	_clear_creatures()
	camera.position = ctr + Vector3(0.0, 15.0, 17.0)
	camera.look_at(ctr)
	await get_tree().create_timer(0.8).timeout
	_snap(save_path.replace(".png", "_kamp_gece.png"))
	DayNight.jump_to_day()
	await get_tree().create_timer(0.4).timeout

	var line := ("KAMPTEST: merkez=%s dogus_on=%s dogus_bos=%s kulube_kati=%s "
			+ "kapi_acik=%s yol_yon=%d/4 ocak_yanmiyor=%s isik_yok=%s "
			+ "veri_temiz=%s tarla=%d aciklik_bos=%s halka_dolu=%%%.0f") % [
		str(c), str(dogus_on), str(dogus_bos), str(kulube_kati), str(kapi_acik),
		yol_yon, str(ocak_yanmiyor), str(isik_yok), str(veri_temiz),
		tarla, str(aciklik_bos), doluluk]
	print(line)
	var fh := FileAccess.open("res://docs/screens/kamptest.txt", FileAccess.WRITE)
	if fh != null:
		fh.store_line(line)
		fh.close()

# --- CEVRE SERPINTISI (grass_tuft / pebble_cluster / twig_debris) ---------
# Kullanicinin GLB'leri; TUR BASINA TEK MultiMesh (3 ek cizim cagrisi).
# Yogunluk KALITE KADEMESINE bagli (dusuk telefonda seyrelir).
# Baglam kurali basit: cimde ot tutami, su/kaya kenarinda cakil, agac
# dibinde dal. Konum/donme/olcek deterministik hash -> yeniden kurulunca
# ayni yerde kalir.
var _env_scatter_nodes: Array = []  # gorsel-tur serpintisi (perf olcumu)

func _build_env_scatter(grass_cells: Array) -> void:
	_env_scatter_nodes.clear()
	var mult: float = float(EnvModels.SCATTER_TIER_MULT.get(_quality_tier, 1.0))
	var groups: Dictionary = {"pebble_cluster": [], "twig_debris": []}
	for cell: Vector2i in grass_cells:
		if _objects.has(cell) or cell == _spawn_cell:
			continue
		if int(_depth.get(cell, 0)) != 0 or Farming.plots.has(cell):
			continue
		if _camp_field.has(cell):
			continue  # tarla sirtlarinin ustune ot bitmez
		var id := _scatter_kind_for(cell)
		if id == "":
			continue
		# KAMP ICI: terk edilmislik hissi icin dal/kuru ot YOGUN (mockup'taki
		# dagilmis cop). Cakil kampta seyrek kalir (temiz zemin havasi olmasin
		# ama tas coplugu da olmasin).
		var camp_boost: float = 1.0
		if _camp_cells.has(cell):
			camp_boost = CAMP_SCATTER_BOOST if id != "pebble_cluster" else 1.0
		# ZEMIN SINIRI: yama kenarina fazladan serpinti — cizgiyi kirar
		# (renk harmani sinirin kendisini, serpinti siluetini yumusatir).
		if _edge_blend.has(cell):
			camp_boost *= EDGE_SCATTER_BOOST
		var roll := int(EnvModels.hash01(cell.x, cell.y, 101) * 100.0)
		var chance: int = int(float(_scatter_chance(id)) * mult * camp_boost)
		if roll >= chance:
			continue
		var rr: float = EnvModels.hash01(cell.x, cell.y, 103)
		var rs: float = EnvModels.hash01(cell.x, cell.y, 107)
		var ox: float = (EnvModels.hash01(cell.x, cell.y, 109) - 0.5) * 2.0
		var oz: float = (EnvModels.hash01(cell.x, cell.y, 113) - 0.5) * 2.0
		var sc: float = EnvModels.SCATTER_SCALE_MIN + rs \
				* (EnvModels.SCATTER_SCALE_MAX - EnvModels.SCATTER_SCALE_MIN)
		var off := Vector3(ox * EnvModels.SCATTER_OFFSET, 0.0,
				oz * EnvModels.SCATTER_OFFSET)
		var basis := Basis().rotated(Vector3.UP, rr * TAU).scaled(Vector3(sc, sc, sc))
		groups[id].append(Transform3D(basis, _cell_center(cell) + off))
	for id: String in groups:
		var list: Array = groups[id]
		if list.is_empty():
			continue
		var node := _env_scatter_node(id, list)
		if node == null:
			continue
		add_child(node)
		_decor_nodes.append(node)  # dekorla ayni omur (yeniden kurulumda silinir)
		_env_scatter_nodes.append(node)  # perf olcumu icin ayri liste

## Hucre baglamina gore serpinti turu ("" = serpinti yok).
func _scatter_kind_for(cell: Vector2i) -> String:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := cell + Vector2i(dx, dy)
			var o := String(_objects.get(n, ""))
			if o == "T":
				return "twig_debris"      # agac dibi: dal parcasi
			if o == "#":
				return "pebble_cluster"   # kaya kenari: cakil
			if is_swimmable(n):
				return "pebble_cluster"   # su kenari: cakil
	# ACIK CIMDE SERPINTI YOK: parlak yesil ot tutami cim uzerinde
	# "yapistirilmis" duruyordu (kullanici karari, kaldirildi). Cakil ve
	# dal baglama kurallariyla duruyor; ot tutami modeli vitrinde.
	return ""

func _scatter_chance(id: String) -> int:
	match id:
		"pebble_cluster": return EnvModels.CHANCE_PEBBLE
		"twig_debris": return EnvModels.CHANCE_TWIG
		_: return EnvModels.CHANCE_TUFT

## Model + olcek onbellegi; GLB yoksa proseduerel fallback (gorev sarti).
var _env_mesh_cache: Dictionary = {}

func _env_scatter_node(id: String, list: Array,
		override_span: float = 0.0) -> Node3D:
	var mesh := _env_mesh(id)
	if mesh == null:
		return null
	var target: float = override_span if override_span > 0.0 \
			else EnvModels.scale_of(id)
	var aabb := mesh.get_aabb()
	var span: float = maxf(0.001, maxf(aabb.size.x, aabb.size.z))
	var k: float = target / span            # KOK olcegi (ic dugum yok)
	var bottom: float = aabb.position.y     # zemine oturma telafisi
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = list.size()
	for i in list.size():
		var t: Transform3D = list[i]
		var s := t.basis.get_scale().x * k
		var b := Basis().rotated(Vector3.UP, t.basis.get_euler().y).scaled(
				Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(b,
				t.origin + Vector3(0.0, -bottom * s, 0.0)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _env_mesh(id: String) -> Mesh:
	if _env_mesh_cache.has(id):
		return _env_mesh_cache[id]
	var mesh: Mesh = null
	var glb := EnvModels.path_of(id)
	if glb != "" and ResourceLoader.exists(glb):
		var scene: Node = load(glb).instantiate()
		_tame_meshy_materials(scene, EnvModels.tint_of(id))  # isima kapali + ton
		for mi2: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			if mi2.mesh == null:
				continue
			mesh = mi2.mesh
			# ONEMLI: GLTF import'u materyali cogu zaman MeshInstance3D'nin
			# surface_override'ina koyuyor. MultiMesh yalniz MESH'i kullanir;
			# materyali mesh'e TASIMAZSAK model BEMBEYAZ cikar (ilk CI
			# karesinde yol taslari boyle ciktı). Aktif materyali mesh'e yaz.
			if mesh is ArrayMesh:
				for si in mesh.get_surface_count():
					var sm2 := mi2.get_active_material(si)
					if sm2 != null:
						(mesh as ArrayMesh).surface_set_material(si, sm2)
			break
		scene.queue_free()
	if mesh == null:
		# FALLBACK (doku/model yoksa): duz renk basit sekil
		var mat := StandardMaterial3D.new()
		mat.roughness = 0.95
		var sm := SphereMesh.new()
		sm.radial_segments = 6
		sm.rings = 3
		sm.radius = 0.5
		sm.height = 1.0
		match id:
			"pebble_cluster": mat.albedo_color = EnvModels.FALLBACK_STONE
			"twig_debris": mat.albedo_color = EnvModels.FALLBACK_WOOD
			_: mat.albedo_color = EnvModels.FALLBACK_LEAF
		sm.material = mat
		mesh = sm
	_env_mesh_cache[id] = mesh
	return mesh

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

## STIL (Bolum 17): agac gorsellerini bir veya BIRDEN COK GLB ile degistir.
## Liste bos degilse tum modeller havuza girer ve _build_trees hucreleri
## hash ile havuz varyantlarina dagitir -> orman KARISIK gorunur. Bos liste
## = Quaternius cam paketi (varsayilan). Sadece MESH degisir; kesme/hucre
## kurali AYNI. Modeller dokulu + decimate (pinetree1 ~5.2k, pinetree2 ~4.4k
## ucgen). (bkz. RAPOR_STIL.md)
const TREE_MODEL_OVERRIDES: Array[String] = [
	"res://assets/models/test/pinetree1.glb",
	"res://assets/models/test/pinetree2.glb",
]

# --- AGAC DEGISIM (agac-degisim dali) ------------------------------------
## YENI SET: iki boylu karisim. Dosya(lar) henuz repoda YOKSA eski
## pinetree1/2 havuzuna duser — eski model SILINMEDI (fallback + ileride
## sis bolgesi varyanti / Retexture adayi). Dosyalar assets/models/env/
## altina dusunce kod degisikligi olmadan devreye girer (TREETEST izler).
## Kullanici dosya adini netlestirdi: pinetree.glb (buyuk agac).
## Kucuk boy dosyasi gelirse 60/40 karisim; gelmezse %100 buyuk.
const TREE_SET := [
	# agac-kesim turu: kullanicinin yukledigi _new modeller esas set.
	# Eski pinetree.glb dusuk agirlikla cesni olarak kaldi.
	{"path": "res://assets/models/test/pinetree_new.glb",
			"agirlik": 45, "boy": 3.1},
	{"path": "res://assets/models/test/polytree_new.glb",
			"agirlik": 35, "boy": 2.7},
	{"path": "res://assets/models/env/pinetree.glb",
			"agirlik": 20, "boy": 3.1},
]
## Ornek basina olcek bandi (gorev: %70-130). DIKKAT: _cell_variance'a
## DOKUNULMADI — o tas/cali/cicekle ortak; bandi orada genisletmek
## kayalari da sisirirdi. Agaca ozel varyans asagida.
const TREE_SCALE_MIN := 0.7
const TREE_SCALE_MAX := 1.3

func _tree_pool() -> Array:
	var out: Array = []
	if not TREE_MODEL_OVERRIDES.is_empty():
		for m: String in TREE_MODEL_OVERRIDES:
			out += _model_pool(m, TREE_HEIGHT)
		return out
	for m: String in TREE_MODELS:
		out += _model_pool(m, TREE_HEIGHT)
	return out

## Agirlikli havuz: [{mesh, agirlik}]. Yeni set dosyalari varsa onlar,
## yoksa eski havuz esit agirlikla.
func _tree_set_pool() -> Array:
	var out: Array = []
	for e: Dictionary in TREE_SET:
		var pth := _tree_yol_coz(String(e["path"]))
		if pth == "":
			continue
		for m in _tree_model_yukle(pth, float(e["boy"])):
			out.append({"mesh": m, "agirlik": int(e["agirlik"])})
	if not out.is_empty():
		return out
	for m in _tree_pool():
		out.append({"mesh": m, "agirlik": 1})
	return out

## Klasor esnekligi (yaratik modelleriyle ayni kalip): once tablodaki
## yol, yoksa assets/models/test/ — GitHub web yuklemeleri cogunlukla
## oraya dusuyor. Dosya hicbirinde yoksa "".
func _tree_yol_coz(yol: String) -> String:
	if ResourceLoader.exists(yol):
		return yol
	var alt := "res://assets/models/test/" + yol.get_file()
	return alt if ResourceLoader.exists(alt) else ""

## Yeni agac GLB yukleyici: Meshy Z-UP tespiti + duzeltmesi.
## OLCEK KURALI: node scale kullanilmiyor — mesh, hedef BOYA gore
## AABB'den normalize edilip TEK ArrayMesh'e pisiriliyor (mevcut
## _merged_node_mesh hatti; karakter 1 birim referans).
func _tree_model_yukle(pth: String, boy: float) -> Array:
	var key := "agac:" + pth + ":" + str(boy)
	if _pool_cache.has(key):
		return _pool_cache[key]
	var inst: Node3D = load(pth).instantiate()
	var holder := Node3D.new()
	holder.add_child(inst)
	var ab := _scene_aabb(holder)
	# Yatik (Z-up) geldiyse dikelt: derinlik boydan belirgin buyukse
	# model yatiyor demektir (yol taslarinda ayni durum olculmustu).
	if ab.size.z > ab.size.y * 1.4:
		inst.rotation_degrees.x = -90.0
	var pool: Array = [_merged_node_mesh(holder, boy)]
	holder.free()
	_pool_cache[key] = pool
	return pool

## Agaca ozel ornek varyansi: rastgele Y-donus + %70-130 olcek
## (deterministik: ayni hucre hep ayni agac).
func _tree_variance(cell: Vector2i) -> Basis:
	var a := EnvModels.hash01(cell.x, cell.y, 977) * TAU
	var sc := TREE_SCALE_MIN + EnvModels.hash01(cell.x, cell.y, 983) \
			* (TREE_SCALE_MAX - TREE_SCALE_MIN)
	return Basis(Vector3.UP, a).scaled(Vector3(sc, sc, sc))

## STIL: orman havasi icin obekli sikligi kontrol eder. Eskiden 8-komsuda
## TEK agac varsa bile hucre bos kalirdi (satranc tahtasi maks yogunluk).
## Artik en fazla MAX_TREE_NEIGHBORS komsuya izin var -> obekler olusur ama
## bir hucre 4+ agacla sarilinca bos kalir (yurunebilir bosluklar korunur).
## MapBalance forest-noise'u zaten obekleri belirledigi icin sonuc "bolum
## bolum sik orman + acikliklar" olur.
const MAX_TREE_NEIGHBORS := 2
func _tree_neighbor_count(cell: Vector2i) -> int:
	var c := 0
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			if _objects.get(cell + Vector2i(dx, dy), "") == "T":
				c += 1
	return c

# --- AGAC KESIM SAHNESI (agac-kesim) --------------------------------------
## Aktif devrilmeler. Kayit: {pivot, mi, cell, yon, drops, boy, bitti}
## KUYRUK YOK: her devrilme bagimsiz tween zinciri — ayni anda 5 agac
## devrilebilir (FELLTEST stres olcumu).
var _fells: Array = []

## Hucredeki agacin MultiMesh'te kullanilan mesh+duruusunu AYNI hash
## mantigiyla yeniden hesaplar (tekil animasyonlu kopya icin).
func _tree_instance_for(cell: Vector2i) -> Dictionary:
	var pool := _tree_set_pool()
	var toplam := 0
	for e: Dictionary in pool:
		toplam += int(e["agirlik"])
	var r := int(EnvModels.hash01(cell.x, cell.y, 991) * float(toplam))
	var idx := 0
	for i in pool.size():
		r -= int(pool[i]["agirlik"])
		if r < 0:
			idx = i
			break
	return {"mesh": pool[idx]["mesh"], "basis": _tree_variance(cell)}

## Son baltada: agac oyuncudan UZAGA devrilir (ustune dusmesin).
## Zincir: kararsizlik sallanmasi -> ease-in devrilme -> carpma
## (toz+yaprak+sarsinti+thud) -> bekleme -> erime (odunlar sacilir).
func _fell_tree(cell: Vector2i, drops: Dictionary) -> void:
	var inst := _tree_instance_for(cell)
	var merkez := _cell_center(cell)
	var yon3: Vector3 = merkez - player.position
	yon3.y = 0.0
	var yon := yon3.normalized() if yon3.length() > 0.01 else Vector3.FORWARD
	var pivot := Node3D.new()  # govde DIBINDEN donsun: pivot zeminde
	pivot.position = merkez
	var mi := MeshInstance3D.new()
	mi.mesh = inst["mesh"]
	mi.transform = Transform3D(inst["basis"], Vector3.ZERO)
	pivot.add_child(mi)
	add_child(pivot)
	var boy: float = (inst["mesh"] as Mesh).get_aabb().size.y 			* (inst["basis"] as Basis).get_scale().y
	var kayit := {"pivot": pivot, "mi": mi, "cell": cell, "yon": yon,
			"drops": drops, "boy": boy, "bitti": false}
	_fells.append(kayit)
	var eksen := Vector3.UP.cross(yon).normalized()
	var setang := func(a: float) -> void:
		if is_instance_valid(pivot):
			pivot.basis = Basis(eksen, deg_to_rad(a))
	var w := FellBalance.WOBBLE_DEG
	var tw := create_tween()
	# 1) kararsizlik: once hafif GERI, sonra one salinim
	tw.tween_method(setang, 0.0, -w, FellBalance.WOBBLE_SECONDS * 0.5)
	tw.tween_method(setang, -w, w * 0.5, FellBalance.WOBBLE_SECONDS * 0.5)
	# 2) hizlanan devrilme (ease-in: yavas baslar, carparken hizli)
	tw.tween_method(setang, w * 0.5, FellBalance.FALL_END_DEG,
			FellBalance.FALL_SECONDS) 			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_fell_impact.bind(kayit))
	tw.tween_interval(FellBalance.LINGER_SECONDS)
	tw.tween_callback(_fell_melt.bind(kayit))

## Carpma ani: govde hatti boyunca toz + tacta yaprak + sarsinti + ses.
func _fell_impact(kayit: Dictionary) -> void:
	var merkez := _cell_center(kayit["cell"])
	var yon: Vector3 = kayit["yon"]
	var boy: float = kayit["boy"]
	# Parcacik butcesi kalite kademesinden (gorev: FPS kurali)
	var t := PerfBalance.tier(_quality_tier)
	var yuksek: bool = bool(t.get("shadow", true))
	var adet: int = FellBalance.DUST_COUNT_HIGH if yuksek 			else FellBalance.DUST_COUNT_LOW
	for f in [0.35, 0.7, 1.0]:
		_spawn_particles(merkez + yon * boy * f + Vector3(0, 0.15, 0),
				FellBalance.DUST_COLOR, adet)
	_spawn_particles(merkez + yon * boy * 0.85 + Vector3(0, 0.4, 0),
			FellBalance.LEAF_COLOR, adet)
	_play_sfx("thud")  # gumleme kancasi (ses dosyasi gelince calar)
	# COK KISA ekran sarsintisi — Dusuk kademede KAPALI (mobil kurali).
	# v_offset kamera konum kontrolunden bagimsiz: takip kodunu bozmaz.
	if yuksek and camera != null:
		var ctw := create_tween()
		ctw.tween_property(camera, "v_offset", -FellBalance.SHAKE_V,
				FellBalance.SHAKE_SECONDS * 0.3)
		ctw.tween_property(camera, "v_offset", FellBalance.SHAKE_V * 0.5,
				FellBalance.SHAKE_SECONDS * 0.35)
		ctw.tween_property(camera, "v_offset", 0.0,
				FellBalance.SHAKE_SECONDS * 0.35)

## Erime: odunlar SACILIR + govde alpha-fade ile kuculup gomulur.
func _fell_melt(kayit: Dictionary) -> void:
	_fell_finish(kayit)
	var mi: MeshInstance3D = kayit["mi"]
	var pivot: Node3D = kayit["pivot"]
	if mi == null or not is_instance_valid(mi):
		return
	# Alpha fade: mesh materyalleri PAYLASIMLI (MultiMesh ile ortak) —
	# yalniz bu kopya icin yuzey override kopyalari acilir.
	var mats: Array = []
	for sf in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(sf)
		if m is BaseMaterial3D:
			var k: BaseMaterial3D = m.duplicate()
			k.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mi.set_surface_override_material(sf, k)
			mats.append(k)
	var seta := func(a: float) -> void:
		for m2: BaseMaterial3D in mats:
			m2.albedo_color.a = a
	var tw := create_tween()
	tw.tween_method(seta, 1.0, 0.0, FellBalance.MELT_SECONDS)
	tw.parallel().tween_property(pivot, "scale",
			Vector3(0.88, 0.88, 0.88), FellBalance.MELT_SECONDS)
	tw.parallel().tween_property(pivot, "position:y",
			pivot.position.y - 0.12, FellBalance.MELT_SECONDS)
	tw.tween_callback(func():
		if is_instance_valid(pivot):
			pivot.queue_free()
		_fells.erase(kayit))

## Odun dususu: govde HATTINA dizilir (tek noktaya yigilmaz) + tacta
## yaprak. Toplama mevcut ground_item sistemiyle.
func _fell_finish(kayit: Dictionary) -> void:
	if bool(kayit.get("bitti", false)):
		return
	kayit["bitti"] = true
	var cell: Vector2i = kayit["cell"]
	var merkez := _cell_center(cell)
	var yon: Vector3 = kayit["yon"]
	var boy: float = kayit["boy"]
	var drops: Dictionary = kayit["drops"]
	var odun: int = int(drops.get("odun", 0))
	var yigin: int = clampi(odun, FellBalance.LOG_MIN, FellBalance.LOG_MAX)
	yigin = mini(yigin, maxi(1, odun))
	var kalan := odun
	var hucreler: Array = []
	for i in yigin:
		var f := float(i + 1) / float(yigin)
		var pos := merkez + yon * boy * f
		var hucre := Vector2i(floori(pos.x), floori(pos.z))
		hucre.x = clampi(hucre.x, 1, _map_w - 2)
		hucre.y = clampi(hucre.y, 1, _map_h - 2)
		var adet := int(ceil(float(kalan) / float(yigin - i)))
		kalan -= adet
		if adet > 0:
			_add_ground_item(hucre, "odun", adet)
			hucreler.append(hucre)
			# zipla-yayil: yeni dusen odun kisa pop yapar
			if not _ground_items.is_empty():
				var gn: Variant = _ground_items[-1].get("node", null)
				if gn != null and is_instance_valid(gn):
					(gn as Node3D).scale = Vector3(0.4, 0.4, 0.4)
					var ptw := create_tween()
					ptw.tween_property(gn, "scale", Vector3.ONE, 0.25) 							.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# yaprak vb. diger dususler tacin dustugu hucreye
	for item_id in drops:
		if String(item_id) == "odun":
			continue
		var tac := merkez + yon * boy
		_add_ground_item(Vector2i(clampi(floori(tac.x), 1, _map_w - 2),
				clampi(floori(tac.z), 1, _map_h - 2)),
				String(item_id), int(drops[item_id]))
	var gained: PackedStringArray = []
	for item_id in drops:
		gained.append("+%d %s" % [int(drops[item_id]),
				Items.display_name(String(item_id))])
	_spawn_floating_text(cell, " ".join(gained), Color(0.7, 1.0, 0.7))
	kayit["hucreler"] = hucreler

var _tree_group_counts: Dictionary = {}   # TREETEST: varyant -> ornek sayisi

func _build_trees(cells: Array[Vector2i]) -> void:
	var pool := _tree_set_pool()
	var toplam := 0
	for e: Dictionary in pool:
		toplam += int(e["agirlik"])
	var groups: Dictionary = {}
	_tree_group_counts.clear()
	for cell in cells:
		# AGIRLIKLI secim (60/40): hucreden deterministik hash, agirlik
		# araligina dusen varyanti alir. Eski esit-bolusum %50/50'ydi.
		var r := int(EnvModels.hash01(cell.x, cell.y, 991) * float(toplam))
		var idx := 0
		for i in pool.size():
			r -= int(pool[i]["agirlik"])
			if r < 0:
				idx = i
				break
		if not groups.has(idx):
			groups[idx] = []
		groups[idx].append(Transform3D(_tree_variance(cell), _cell_center(cell)))
		_tree_group_counts[idx] = int(_tree_group_counts.get(idx, 0)) + 1
	for idx in groups:
		# MOBIL PERF: yogun orman golge yansitmaz (golge gecisi tum agaclari
		# ikinci kez cizerdi — en pahali kalem). Agaclar isik ALIR ama GOLGE
		# ATMAZ; AC/Longvinter stili. Buyuk FPS kazanci, sik ormani korur.
		# MULTIMESH DOGRULAMASI: varyant basina TEK MultiMesh (TREETEST'te
		# dugum sayisi olarak olculuyor).
		_keep(_make_mesh_multimesh(pool[idx]["mesh"], groups[idx], false))

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
		_keep(_make_mesh_multimesh(pool[key.y], groups[key], false))  # mobil: golge yok

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
	# CIM SHADER V1: cicek saplari ayni shader'in dusuk-ruzgar kopyasini
	# alir (baslar savrulmasin). Mantar UYGULANMADI: sapka/govde dikey
	# gradyanla bozulur ve mantar sallanmamali — RAPOR'da gerekceli.
	var mat: Material = _cicek_material() if kind == "cicek" else null
	for idx in groups:
		_keep(_make_mesh_multimesh(pool[idx], groups[idx], false, mat))

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
			_keep(_make_mesh_multimesh(_bush_game_mesh(v, true), _bush_transforms(f), false))
		if not e.is_empty():
			_keep(_make_mesh_multimesh(_bush_game_mesh(v, false), _bush_transforms(e), false))

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

## STIL: model bir kisa ad ("tree_pineDefaultA") ya da tam yol
## ("res://.../pine_tree.glb") olabilir. Boylece test/ altindaki modeller de
## dogaya kopyalanmadan baglanabilir.
func _nature_path(model: String) -> String:
	if model.begins_with("res://") or model.ends_with(".glb"):
		return model
	return NATURE_PATH % model

func _model_pool(model: String, target_h: float) -> Array:
	var key := model + ":" + str(target_h)
	if _pool_cache.has(key):
		return _pool_cache[key]
	var scene: Node3D = load(_nature_path(model)).instantiate()
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
		shadows := true, mat: Material = null) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	if mat != null:
		# CIM SHADER V1: override MMI duzeyinde — TEK draw call korunur
		node.material_override = mat
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
	# EDITOR: tum dunya dokunuslari editore gider. Mesafe siniri YOK —
	# uzaga yerlestirebilmek editorun asil isi (oyunda 1 hucre sinir var).
	if _editor_on:
		var ec := _screen_to_cell(screen_pos)
		if ec != Vector2i(-999, -999):
			_editor_tap(ec)
		return
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
					# SU SHADER V1: hedef hucre "akan" isaretlenir (yon
					# borudan hucreye). Mesh seviye degisiminde zaten
					# yeniden kurulur; isaret orada okunur.
					_flow_dirs[tc] = {"dir": Vector2(tc - pc).normalized(),
							"t": Time.get_ticks_msec()}
					add_water(tc, taken)
					# Asama 5 cila: akis varken hedefte minik su parildamasi.
					_spawn_particles(_cell_center(tc) + Vector3(0, 0.25, 0),
							Color(0.45, 0.65, 0.92), 3)
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
	if DigWaterVisual.SU_SHADER_V1:
		st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
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
				# Akis verisi: boru transferi bu hucreye TAZE su bastiysa
				# akan cizilir (yon transferden; _flow_dirs'i tick yazar).
				var akis := 0.0
				var akis_yon := Vector2.ZERO
				if DigWaterVisual.SU_SHADER_V1 and _flow_dirs.has(c):
					var kayit: Dictionary = _flow_dirs[c]
					if Time.get_ticks_msec() - int(kayit["t"]) \
							< DigWaterVisual.V1_AKIS_TAZE_MS:
						akis = 0.8
						akis_yon = Vector2(kayit["dir"])
					else:
						_flow_dirs.erase(c)
				for tri in [[Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1)],
						[Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]]:
					for p: Vector2 in tri:
						st.set_normal(Vector3.UP)
						var dm: float = maxf(0.0, surface_y
								- float(_sample_terrain(p.x, p.y)[0]))
						if DigWaterVisual.SU_SHADER_V1:
							st.set_color(DigWaterVisual.v1_encode(dm, akis))
							st.set_uv(Vector2(p.x, p.y) / DigWaterVisual.V1_UV_OLCEK)
							st.set_custom(0, Color(akis_yon.x, akis_yon.y, 0, 0))
						else:
							st.set_color(_water_rgba(dm, p.x, p.y))
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
	# CIT: hucre degil KENAR yerlesimi — kendi akisi.
	if _held_item == "cit":
		return _place_fence_at(cell)
	if _held_item == "cit_diregi":
		return _place_direk_at(cell)
	if _placed.has(cell) or _objects.has(cell) or cell == _player_cell():
		return false
	# KESIF 16.1/16.4: yetersiz isikla siste KAMP KURULAMAZ (kapi kurali).
	if _held_item == "yol_koru" and not kesif_kamp_izni():
		_spawn_floating_text(cell, "Cok karanlik — kamp kurulamaz",
				Color(1, 0.6, 0.4))
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
	elif behavior == "sefer_atesi":
		# KESIF 16.4: mini isik cemberi + KAYIT NOKTASI (yerlestirme aninda)
		_add_torch_light(cell, holder)
		if not _loading and not _editor_on \
				and not OS.has_environment("RABLE_MASK_PREVIEW"):
			SaveManager.save()
			_spawn_floating_text(cell, "Kamp kuruldu — kayit alindi",
					Color(1, 0.85, 0.5))
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
	# Yapiya ton verildiyse uygula (ornek: sonuk ocak koyu yanmis odun).
	# _tame_meshy_materials materyali KOPYALAR -> paylasilan kaynakta ton
	# birikmesi olmaz, ayni model bir daha kurulunca daha koyu cikmaz.
	if def.has("tint"):
		var tint: Color = def["tint"]
		_tame_meshy_materials(bundle, tint)
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
	_update_water_warm_lights()  # SU V1: isik listesi degisti
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
	# CIT: hayalet hucre merkezine degil KENARA oturur (oyuncuya donuk
	# kenar — yerlestirme de ayni kenari secer, ne gorursen onu alirsin).
	if _place_item == "cit":
		var fe := _fence_edge_for(cell)
		if fe.z != -999:
			_ghost.position = _edge_mid(fe) + Vector3(0, FenceBalance.RAIL_Y, 0)
			_ghost.rotation_degrees.y = 90.0 if fe.z == 1 else 0.0
	# CIT-FIX: direk hayaleti oyuncuya en yakin KOSEYE oturur.
	if _place_item == "cit_diregi":
		var kc := _nearest_corner(cell)
		_ghost.position = Vector3(float(kc.x),
				ground_height(float(kc.x), float(kc.y)), float(kc.y))
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
	# CIT: kural kenara bakar — hucre dolulugu onemsiz (kenar bos +
	# zemin turu yeter; tarlanin kenarina cit tam da boyle cekilir).
	if String(def.get("behavior", "")) == "fence_post":
		var kc := _nearest_corner(cell)
		if _fence_posts.has(kc):
			return {"valid": false, "reason": "direk var"}
		if not (_ground_char.get(cell, "") in [".", "d", "s"]):
			return {"valid": false, "reason": "zemin"}
		return {"valid": true, "reason": ""}
	if String(def.get("behavior", "")) == "fence":
		var fe := _fence_edge_for(cell)
		if fe.z == -999 or _fences.has(fe):
			return {"valid": false, "reason": "çit var"}
		if not (_ground_char.get(cell, "") in [".", "d", "s"]):
			return {"valid": false, "reason": "zemin"}
		return {"valid": true, "reason": ""}
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
	# CIT: kenar akisi (envanteri _place_fence_at duser)
	if _place_item == "cit":
		if _place_fence_at(cell) and Inventory.get_count("cit") <= 0:
			_exit_place_mode()
		return
	if _place_item == "cit_diregi":
		if _place_direk_at(cell) and Inventory.get_count("cit_diregi") <= 0:
			_exit_place_mode()
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
	# CIHAZ HATASI ("tezgahin yanindayim ama uzaktasin diyor"): yaricap 3x3
	# idi. Oyuncu carpisma yaricapi yuzunden tezgaha 1 hucreden fazla
	# yaklasamiyor; kose/capraz duruslarda hucre farki 2'ye cikip kapi
	# kapaniyordu. 5x5 (+-2) ile "yanindayim" hissi ile kod ortusuyor.
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			match _placed.get(pc + Vector2i(dx, dy), ""):
				"tezgah":
					near_bench = true
				"arastirma_masasi":
					near_res = true
				"ocak":
					near_hearth = true  # 14.3 pisirme istasyonu (arayuz)
				"yol_koru":
					near_hearth = true  # KESIF 16.4: kampta yemek pisirilir
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
	_update_water_warm_lights()  # SU V1: Ocak sudaki sicak yansimaya girer

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
	var node := _ground_item_visual(item_id, count)
	var base_y := 0.35
	node.position = _cell_center(cell) + Vector3(0, base_y, 0)
	add_child(node)
	_ground_items.append({"cell": cell, "id": item_id, "count": count,
			"node": node, "base_y": base_y, "phase": randf() * TAU})

## Kategori rengine gore basit low-poly govde (kutu; yenilebilir/yuvarlaklar
## kure). Ikon dokusu YOK — uzaktan net, ucuz, "dunya objesi" hissi.
func _ground_item_visual(item_id: String, count: int = 1) -> Node3D:
	var root := Node3D.new()
	# ODUN: gercek wood_log modeli (agac-kesim). 2+ odunlu yiginda %30
	# cift-log varyanti — wood_log_pair.glb DOSYA-BEKLER (yoksa tek).
	if item_id == "odun" and ResourceLoader.exists(FellBalance.LOG_GLB):
		var yol := FellBalance.LOG_GLB
		if count >= 2 and randf() < FellBalance.LOG_PAIR_CHANCE 				and ResourceLoader.exists(FellBalance.LOG_PAIR_GLB):
			yol = FellBalance.LOG_PAIR_GLB
		var log_inst: Node3D = load(yol).instantiate()
		log_inst.scale = Vector3.ONE * FellBalance.LOG_LEN
		log_inst.rotation.y = randf() * TAU  # hafif rastgele durus
		root.add_child(log_inst)
		return root
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
	# KESIF 16.1: yetersiz isikla siste genis tarama KAPANIR — yalniz on
	# hucre. "Hedefleme mesafesi duser" kapisinin hucre-tabanli karsiligi.
	if _isik_acik > 0 and KesifBalance.KISITLI_HEDEFLEME:
		return [_facing_cell()]
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
# --- TARIM (tarim-3d): dunya tarafi ---------------------------------------
## Tarla acilabilir mi: duz + kazilmamis + bos + susuz cim/toprak hucresi
func _till_valid(cell: Vector2i) -> bool:
	return int(_depth.get(cell, 0)) == 0 \
			and String(_ground_char.get(cell, "")) in [".", "d"] \
			and not _objects.has(cell) and not _placed.has(cell) \
			and not Farming.plots.has(cell) and not is_water_source(cell) \
			and pool_at(cell) < 0 and _ground_item_at(cell) == -1 \
			and cell != _player_cell()

func _try_till(cell: Vector2i) -> void:
	if not _till_valid(cell):
		_spawn_floating_text(cell, "Buraya tarla olmaz", Color(1, 0.85, 0.6))
		return
	if Farming.till_cell(cell):
		_play_sfx(String(TarimBalance.SFX["till"]))
		_spawn_floating_text(cell, "Tarla açıldı", Color(0.8, 1.0, 0.8))

func _try_plant(cell: Vector2i) -> void:
	var check: Dictionary = Farming.can_plant(cell, "berry_bush")
	if not bool(check.ok):
		_spawn_floating_text(cell, String(check.reason), Color(1, 0.85, 0.6))
		return
	if Inventory.get_count("tohum") <= 0:
		_spawn_floating_text(cell, "Tohum yok", Color(1, 0.85, 0.6))
		return
	if Farming.plant(cell, "berry_bush"):
		Inventory.remove_item("tohum", 1)
		_play_sfx(String(TarimBalance.SFX["plant"]))
		_spawn_floating_text(cell, "Ekildi", Color(0.8, 1.0, 0.8))

func _try_fill_can() -> void:
	Farming.fill_watering_can()
	_play_sfx(String(TarimBalance.SFX["fill"]))
	_spawn_floating_text(_player_cell(), "Kap doldu (%d)" % \
			TarimBalance.WATERING_CAN_USES, Color(0.6, 0.85, 1.0))

func _try_water_plot(cell: Vector2i) -> void:
	var check: Dictionary = Farming.can_water(cell)
	if not bool(check.ok):
		_spawn_floating_text(cell, String(check.reason), Color(1, 0.85, 0.6))
		return
	if Farming.water(cell):
		_play_sfx(String(TarimBalance.SFX["water"]))
		_spawn_floating_text(cell, "Sulandı (kap: %d)" % \
				Farming.watering_can_left, Color(0.6, 0.85, 1.0))

func _try_crop_harvest(cell: Vector2i) -> void:
	var crop: Dictionary = Farming.harvest_clear(cell)
	if crop.is_empty():
		return
	# Urun YERE SACILIR (loot hissi) + tohum iade sansi
	var n := randi_range(int(crop.yield_min), int(crop.yield_max))
	var drops := {String(crop.yield_item): n}
	if randf() < TarimBalance.SEED_RETURN_CHANCE:
		drops[String(crop.seed_item)] = int(drops.get(String(crop.seed_item), 0)) + 1
	_scatter_drops(cell, drops)
	_play_sfx(String(TarimBalance.SFX["harvest"]))
	_spawn_floating_text(cell, "Hasat!", Color(0.8, 1.0, 0.8))

## Safak surucusu: ONCE bitisik-su otomatigi (kanal kaz -> tarla kendini
## sular; 11.7 kancasi BAGLANDI), SONRA buyume tick'i.
func _on_farm_dawn() -> void:
	for cell: Vector2i in Farming.plots.keys():
		if has_adjacent_water(cell):
			Farming.water_free(cell)
	Farming.day_tick()

## Veri->gorsel koprusu: zemin parcasi + bitki dugumu yenilenir
var _crop_nodes: Dictionary = {}  # cell -> Node3D

func _on_plot_changed(cell: Vector2i) -> void:
	_refresh_terrain_at(cell)
	_update_mound_node(cell)
	_update_crop_node(cell)

# --- TARLA HOYUGU (planting_mound) ---------------------------------------
## Capalanan her tarlaya kullanicinin GLB'si konur; iki model SIRA ILE
## kullanilir (1. tarla A, 2. tarla B, 3. A ...). Sira "kacinci tarla
## acildigi"ndan gelir (Farming.plots ekleme sirasi), boylece kayit/yukleme
## sonrasi da AYNI kalir — ayrica veri saklamaya gerek yok.
var _mound_nodes: Dictionary = {}  # cell -> Node3D

## OLCULDU: planting_mound DIK modellenmis (Z kalinligi 0.14) -> yatirmak
## icin X'te -90. planting_mound2 zaten yatik (Y ince) -> donme yok.
const MOUND_GLB := [
	{"path": "res://assets/models/test/planting_mound.glb",
			"rot_deg": Vector3(-90, 0, 0)},
	{"path": "res://assets/models/test/planting_mound2.glb",
			"rot_deg": Vector3.ZERO},
]
## BOS surulu tarla gostergesi (gorsel-tur): ekim yapilmamis hucrede bu
## model durur, EKILINCE KAYBOLUR, hasattan sonra geri gelir. Ekili
## hucrede yerini yukaridaki yatak modelleri alir (sira ile).
const MOUND_EMPTY := {"path": "res://assets/models/crops/planting_mound.glb",
		"rot_deg": Vector3.ZERO}
## Hoyuk hucrenin TAMAMINI kaplamamali: "icine tohum ekilecek" olcekte
## kucuk bir toprak yuvasi (0.92 -> 0.42; hucrenin ~%42'si).
const MOUND_FOOTPRINT := 0.42  # taban genisligi (m)
## Meshy hoyugu neredeyse BEYAZ geliyordu (kamp karesinde 4 beyaz kubbe).
## Toprak tonuna cekilir.
## (0.50/0.39/0.29 pembeye caliyordu; toprak kahvesine cekildi.)
const MOUND_TINT := Color(0.44, 0.34, 0.23)
## Model kubbe gibi sisman; 0.92 m tabanda ~45 cm boy cikiyor — surulmus
## bir sirt icin cok yuksek. Kok dugumde Y ezilir.
## (Karakterdeki "node scale yasak" dersi SKINNED modellerin IC dugumleri
## icindi; bu prop skinned degil, ezme guvenli.)
const MOUND_FLATTEN := 0.55

func _update_mound_node(cell: Vector2i) -> void:
	_camp_clear_field_decor(cell)  # kamp dekoru gercek tarlaya yer birakir
	if _mound_nodes.has(cell):
		_mound_nodes[cell].queue_free()
		_mound_nodes.erase(cell)
	if not Farming.plots.has(cell):
		return
	var plot: Variant = Farming.plots.get(cell)
	var empty: bool = plot == null or String(plot.get("crop_id", "")) == ""
	var node: Node3D
	if empty:
		node = _build_mound_from(MOUND_EMPTY)
	else:
		var order: int = Farming.plots.keys().find(cell)
		node = _build_mound_visual(maxi(0, order) % MOUND_GLB.size())
	if node == null:
		return
	var h := float(_cell_props(cell.x, cell.y)[0])
	node.position = Vector3(float(cell.x) + 0.5, h, float(cell.y) + 0.5)
	add_child(node)
	_mound_nodes[cell] = node

func _build_mound_visual(variant: int) -> Node3D:
	return _build_mound_from(MOUND_GLB[variant])

## Ortak kurucu: GLB'yi yukler, KOK dugumune olcek verir (ic dugumlere
## dokunmaz), hucreye sigdirir ve zemine oturtur.
func _build_mound_from(cfg: Dictionary) -> Node3D:
	var glb: String = String(cfg["path"])
	if not ResourceLoader.exists(glb):
		return null
	var root := Node3D.new()
	var inst: Node3D = load(glb).instantiate()
	inst.rotation_degrees = cfg.get("rot_deg", Vector3.ZERO)
	root.add_child(inst)
	_tame_meshy_materials(inst, MOUND_TINT)  # isima kapali + toprak tonu
	# Tabani hucreye sigdir + zemine otur (donme SONRASI olculur)
	var aabb := _scene_aabb(inst)
	var span: float = maxf(aabb.size.x, aabb.size.z)
	if span > 0.01:
		var s: float = MOUND_FOOTPRINT / span
		inst.scale = Vector3(s, s * MOUND_FLATTEN, s)
		inst.position.y = -aabb.position.y * s * MOUND_FLATTEN
	return root

func _update_crop_node(cell: Vector2i) -> void:
	if _crop_nodes.has(cell):
		_crop_nodes[cell].queue_free()
		_crop_nodes.erase(cell)
	var plot: Variant = Farming.plots.get(cell)
	if plot == null or String(plot.crop_id) == "":
		return
	var node := _build_crop_visual(String(plot.crop_id), int(plot.stage))
	var h := float(_cell_props(cell.x, cell.y)[0])
	node.position = Vector3(float(cell.x) + 0.5, h, float(cell.y) + 0.5)
	add_child(node)
	_crop_nodes[cell] = node

## Evre gorseli: kullanicinin Meshy GLB'leri (CROP_STAGE_GLB) varsa onlar
## (boy CROP_STAGE_H'ye normalize edilir, zemine oturtulur); yoksa
## proseduerel placeholder (filiz->fide->meyveli cali).
const CROP_STAGE_GLB := {
	"berry_bush": ["res://assets/models/test/tiny_plant.glb",
			"res://assets/models/test/small_young_berry.glb",
			"res://assets/models/test/mature_berry.glb"],
}
const CROP_STAGE_H := [0.22, 0.40, 0.60]  # hedef boylar (m)

func _build_crop_visual(crop_id: String, stage: int) -> Node3D:
	var root := Node3D.new()
	var paths: Array = CROP_STAGE_GLB.get(crop_id, [])
	var glb: String = String(paths[stage]) if stage < paths.size() else ""
	if glb != "" and ResourceLoader.exists(glb):
		var inst: Node3D = load(glb).instantiate()
		root.add_child(inst)
		_tame_meshy_materials(inst, TarimBalance.CROP_TINT)  # isima kapali + ton
		var aabb := _scene_aabb(inst)
		if aabb.size.y > 0.01:
			var s: float = CROP_STAGE_H[mini(stage, CROP_STAGE_H.size() - 1)] \
					/ aabb.size.y
			inst.scale = Vector3(s, s, s)
			inst.position.y = -aabb.position.y * s  # zemine otur
	else:
		var green := Color(0.32, 0.62, 0.28)
		if stage == 0:
			root.add_child(_crop_part(_crop_cyl(0.03, 0.12), green,
					Vector3(0, 0.06, 0)))
		elif stage == 1:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.14
			cone.height = 0.32
			root.add_child(_crop_part(cone, green.darkened(0.1),
					Vector3(0, 0.16, 0)))
		else:
			var bush := SphereMesh.new()
			bush.radius = 0.26
			bush.height = 0.44
			root.add_child(_crop_part(bush, green.darkened(0.2),
					Vector3(0, 0.26, 0)))
			for k in 3:
				var berry := SphereMesh.new()
				berry.radius = 0.045
				berry.height = 0.09
				var ang := TAU * float(k) / 3.0
				root.add_child(_crop_part(berry, Color(0.78, 0.20, 0.30),
						Vector3(cos(ang) * 0.18, 0.30 + float(k % 2) * 0.08,
						sin(ang) * 0.18)))
	# Olgun evrede hafif salinim (hasat cagrisi) — GLB/proseduerel farketmez
	var crop_def: Dictionary = TarimBalance.CROPS.get(crop_id, {})
	if stage >= int(crop_def.get("stages", 3)) - 1:
		var tw := create_tween().set_loops()
		tw.tween_property(root, "rotation:z", 0.05, 1.1) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(root, "rotation:z", -0.05, 1.1) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return root

func _crop_cyl(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	return m

## Meshy GLB'leri emissive (isima) haritasiyla gelir -> sahne isigini
## dinlemeyip PARLAK gorunur. Isima kapatilir, puruzluluk toparlanir.
func _tame_meshy_materials(root: Node, tint: Color = Color.WHITE) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat is StandardMaterial3D:
				var m: StandardMaterial3D = mat.duplicate()
				m.emission_enabled = false
				m.emission_energy_multiplier = 0.0
				m.metallic = 0.0
				m.roughness = maxf(m.roughness, 0.75)
				m.albedo_color = m.albedo_color * tint
				mi.set_surface_override_material(i, m)

func _crop_part(mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mi.material_override = mat
	return mi

func _describe_target(cell: Vector2i) -> Dictionary:
	var held := _held_item
	# BOLUM 15: YARATIK — her seyin ONUNDE, elde NE OLURSA OLSUN vurulur.
	# BUG (oyunda bildirildi): yumruk ve balta ToolProfiles'ta
	# is_weapon=false oldugu icin saldiri butonu HIC cikmiyordu; ana
	# buton da yaratigi taniyordu, yani yaratiga vurmanin YOLU YOKTU.
	# Yerdeki esyanin bile ustunde: dovus sirasinda ayagina dusen ozu
	# toplamaya calismak, yaratigi doverken yapilacak son sey.
	if _creature_near(cell) != null:
		return {"type": "creature", "cell": cell, "icon": "attack",
				"valid": true, "kind": "attack"}
	# Yerdeki esya: elde ne olursa olsun toplanir
	if _ground_item_at(cell) != -1:
		return {"type": "ground", "cell": cell, "icon": "grab",
				"valid": true, "kind": "grab"}
	# KESIF 16.3: yakilmamis kor tasi -> yakma etkilesimi
	var kor_id := _kor_tas_at(cell)
	if kor_id != "" and not bool(_kor_taslari[kor_id]["yanik"]):
		return {"type": "kortasi", "cell": cell, "icon": "open",
				"valid": true, "kind": "open", "kor_id": kor_id}
	# KESIF 16.3: Ocak'a dokun -> yol koru al (tasima kabi varsa)
	if cell == get_hearth() and Inventory.get_count("yol_koru") < 1:
		return {"type": "yolkoru", "cell": cell, "icon": "open",
				"valid": true, "kind": "open"}
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
	# TARIM baglamlari (tarim-3d). Oncelik: olgun hasat (her elde) >
	# elde-ozel eylemler (capa/tohum/sulama kabi).
	if Farming.can_harvest(cell) and not ToolProfiles.is_weapon(held):
		return {"type": "crop", "cell": cell, "icon": "crop",
				"valid": true, "kind": "crop_harvest"}
	if held == "capa":
		return {"type": "till", "cell": cell, "icon": "till",
				"valid": _till_valid(cell), "kind": "till"}
	if held == "tohum" and Farming.plots.has(cell):
		return {"type": "plant", "cell": cell, "icon": "plant",
				"valid": bool(Farming.can_plant(cell, "berry_bush").ok),
				"kind": "plant"}
	if held == "sulama_kabi":
		if is_water_source(cell) or pool_at(cell) >= 0:
			return {"type": "fillcan", "cell": cell, "icon": "fill",
					"valid": true, "kind": "fill_can"}
		if Farming.plots.has(cell):
			return {"type": "water", "cell": cell, "icon": "water",
					"valid": bool(Farming.can_water(cell).ok), "kind": "water"}
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
	# YARATIK taramasi ayri ve ONCE: komsu hucrelerin yani sira OYUNCUNUN
	# KENDI hucresi de dahil. Temas menzili 0.9 m, yani saldiran yaratik
	# cogu zaman senin ustunde duruyor; yalniz komsulara bakan tarama tam
	# da vurman gereken anda onu kaciriyordu.
	var yaratik_hucreleri: Array = _candidate_cells()
	yaratik_hucreleri.append(_player_cell())
	for cell: Vector2i in yaratik_hucreleri:
		if _creature_near(cell) != null:
			return {"type": "creature", "cell": cell, "icon": "attack",
					"valid": true, "kind": "attack"}
	for cell: Vector2i in _candidate_cells():
		var d := _describe_target(cell)
		if d["type"] != "none":
			return d
	# CIT-FIX: direk/ray hedefleri (dusuk oncelik; silahtan once).
	var ct := _cit_target()
	if String(ct["type"]) != "none":
		return ct
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
		"kortasi":
			_try_burn_kor_tas(String(t.get("kor_id", "")))
			return
		"yolkoru":
			_take_yol_koru()
			return
		"station":
			_interact_station(cell, String(t.get("placed", "")))
			return
		"door":
			_toggle_door(cell)
			return
		"citdirek":
			_cit_post_tapped(Vector2i(t["corner"]))
			return
		"citray":
			_cit_ray_sok(Vector3i(t["edge"]))
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
	# KESIF 16.5: kazma/kesme/kazi GURULTUDUR — yakin uyuyanlari uyandirir.
	if kind in ["chop", "harvest", "mine", "dig"]:
		_uyuyan_gurultu(cell)
	match kind:
		"chop", "harvest", "mine":
			_try_harvest(cell)
		"dig":
			_try_dig(cell)
		"till":
			_try_till(cell)
		"plant":
			_try_plant(cell)
		"fill_can":
			_try_fill_can()
		"water":
			_try_water_plot(cell)
		"crop_harvest":
			_try_crop_harvest(cell)
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
		# BÖLÜM 15: yaratik carpismasi (menzilli silahlar da yaratigi vurur)
		var hit_dummy := false
		for cr in _creatures:
			if not is_instance_valid(cr) or not cr.is_alive():
				continue
			if Vector2(new_pos.x - cr.position.x, new_pos.z - cr.position.z).length() < 0.5 \
					and new_pos.y > 0.1 and new_pos.y < 1.4:
				cr.take_hit(int(pr["damage"]), vel.normalized())
				_spawn_particles(new_pos, Color(0.95, 0.9, 0.7), 5)
				hit_dummy = true
				break
		if hit_dummy:
			_land_projectile(pr)
			continue
		# Kukla carpismasi (xz yakinlik + yukseklik araligi)
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
		# BÖLÜM 15: yaratik (kukla ile AYNI take_hit) — oncelikli hedef.
		var cr := _creature_near(c)
		if cr != null:
			cr.take_hit(dmg, kdir)
			_spawn_particles(_cell_center(c) + Vector3(0, 0.5, 0),
					Color(0.95, 0.9, 0.7), 5)
			_hit_stop(0.5, 0.05)
			_play_sfx(String(prof.get("hit_sfx", "")))
			return
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

# --- BÖLÜM 15: YARATIK VARLIĞI (Asama 1) ---------------------------------
## Bir yaratik olusturur (konum + tip + gece can carpani). died -> oz duser.
## Doner: creature node (debug/test). AI/dalga dis sistemde (Asama 2-3).
func spawn_creature(cell: Vector2i, ctype: String = "normal",
		hp_mult: float = 1.0) -> Node3D:
	var cr = CreatureScript.new()
	cr.setup(ctype, hp_mult)
	cr.position = _cell_center(cell)
	cr.died.connect(_on_creature_died)
	add_child(cr)
	_creatures.append(cr)
	cr.set_night(DayNight.phase in ["night", "dusk"])  # isima gece kaynagi
	_spawn_particles(cr.position + Vector3(0, 0.4, 0), CreatureBalance.EYE_COLOR, 6)
	return cr

## Yaratik oldu (15.1): oz dunya item'i duser + dagilma efekti.
func _on_creature_died(cell: Vector2i, essence_item: String, essence_count: int) -> void:
	_spawn_particles(_cell_center(cell) + Vector3(0, 0.5, 0),
			CreatureBalance.BODY_COLOR, 8)
	if essence_count > 0:
		_add_ground_item(cell, essence_item, essence_count)
	_creatures = _creatures.filter(func(c): return is_instance_valid(c) and c.is_alive())

## Vurus hedefi: verilen hucre merkezine YAKIN canli yaratik (yoksa null).
func _creature_near(cell: Vector2i) -> Node3D:
	var center := _cell_center(cell)
	for cr in _creatures:
		if not is_instance_valid(cr) or not cr.is_alive():
			continue
		if Vector2(cr.position.x - center.x, cr.position.z - center.z).length() < 0.75:
			return cr
	return null

## NIGHTTEST (hizli CI, yaratik-gece): kare almayan gece mantigi —
## dogus HALKASI mesafeleri + sayi egrisi + daze + duvari KIRMA +
## isik alani sorgusu + safak temizligi. Basarisizlik push_error
## (CI kirmizi yakar).
func _run_night_logic_test() -> void:
	_clear_creatures()
	# Ocak garanti: halka merkezi ve hedef belli olsun
	var hc := get_hearth()
	if hc == Vector2i(-999, -999):
		var occ := _player_cell() + Vector2i(0, 3)
		if _ground_char.get(occ, "") in [".", "d", "s"] and not _objects.has(occ) \
				and not _placed.has(occ):
			_set_placed(occ, "ocak")
			hc = get_hearth()
	var merkez := hc if hc != Vector2i(-999, -999) else _player_cell()
	# GECE 3 senaryosu: egri 2+1*(3-1)=4 (MIN_* verisi)
	var beklenen: int = CreatureBalance.min_wave_count(3)
	_spawn_night_wave(3)
	var dogan := _live_creature_count()
	var d_min := 9999.0
	var d_max := 0.0
	var daze_ok := dogan > 0
	for cr in _creatures:
		if not is_instance_valid(cr):
			continue
		var d := Vector2(cr.cell() - merkez).length()
		d_min = minf(d_min, d)
		d_max = maxf(d_max, d)
		if cr.daze <= 0.0:
			daze_ok = false
	# Halka bandi: relax daralmasi 8'e kadar iner; ustte RING_MAX + pay
	var halka_ok: bool = dogan > 0 and d_min >= 8.0 \
			and d_max <= float(CreatureBalance.SPAWN_RING_MAX) + 2.0
	# DUVARI KIRMA: Ocak'i 8 duvarla cevir -> her yol duvardan gecer.
	# Yaratigi 3 hucre oteye koy, tick'le; bir duvarin cani azalmali.
	_clear_creatures()
	var duvarlar: Array = []
	if merkez != Vector2i(-999, -999):
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				if ox == 0 and oy == 0:
					continue
				var w := merkez + Vector2i(ox, oy)
				if _ground_char.get(w, "") in [".", "d", "s"] \
						and not _objects.has(w) and not _placed.has(w):
					_set_placed(w, "ahsap_duvar")
					duvarlar.append(w)
	var duvar_ok := false
	if not duvarlar.is_empty():
		# Oyuncu testte AGGRO menziline girmesin (hedef Ocak kalsin):
		# gecici olarak uzaga isinla, sonra geri getir.
		var eski_poz: Vector3 = player.position
		player.position = _cell_center(merkez + Vector2i(30, 0))
		var cw = spawn_creature(merkez + Vector2i(0, -3), "normal")
		cw.daze = 0.0
		var hp0 := 0
		for w: Vector2i in duvarlar:
			hp0 += int(_structures.get_inst(w).get("hp", 0))
		for i in 120:  # ~6 sn (struct vurus araligi 0.9 sn -> birkac vurus)
			_tick_creatures(0.05)
		var hp1 := 0
		for w: Vector2i in duvarlar:
			hp1 += int(_structures.get_inst(w).get("hp", 0))
		duvar_ok = hp1 < hp0
		player.position = eski_poz
	# ISIK ALANI: yanan Ocak'in dibinde true, 20 hucre otede false
	var isik_ok: bool = merkez != Vector2i(-999, -999) \
			and _pos_in_light(_cell_center(merkez)) \
			and not _pos_in_light(_cell_center(merkez + Vector2i(20, 0)))
	# SAFAK: temizlik (oz dusurmeden erirler)
	_on_dawn_clear_creatures()
	var kalan := _live_creature_count()
	if not halka_ok:
		push_error("NIGHT: dogus halkasi disinda (%.1f..%.1f)" % [d_min, d_max])
	if dogan != beklenen:
		push_error("NIGHT: sayi egrisi tutmadi (beklenen %d, dogan %d)" % [
				beklenen, dogan])
	if not daze_ok:
		push_error("NIGHT: dogma sersemligi (daze) baslamadi")
	if not duvar_ok:
		push_error("NIGHT: cevrili Ocak'a giden yaratik duvara vurmadi")
	if not isik_ok:
		push_error("NIGHT: isik alani sorgusu yanlis")
	if kalan != 0:
		push_error("NIGHT: safak temizligi kalan birakti (%d)" % kalan)
	print("NIGHTTEST: beklenen=%d dogan=%d halka=%.1f-%.1f daze=%s duvar=%s isik=%s safak_kalan=%d" % [
			beklenen, dogan, d_min, d_max, str(daze_ok), str(duvar_ok),
			str(isik_ok), kalan])
	# Temizlik: duvarlar kalksin (SAVELOAD dunyayi oldugu gibi olcer)
	for w: Vector2i in duvarlar:
		_release_structure_cell(w)
	_clear_creatures()

## NIGHTTEST (CI): gece tetikle -> dogdular mi, Ocak'a YAKLASIYORLAR mi,
## safakta temizlendi mi. Sonuc docs/screens/nighttest.txt + log.
func _run_night_test(save_path: String) -> void:
	_clear_creatures()
	# Ocak yoksa oyuncunun yanina koy (hedef secimi test edilebilsin)
	var hc := get_hearth()
	if hc == Vector2i(-999, -999):
		var occ := _player_cell() + Vector2i(0, 3)
		if _ground_char.get(occ, "") in [".", "d", "s"] and not _objects.has(occ) \
				and not _placed.has(occ):
			_set_placed(occ, "ocak")
			hc = get_hearth()
	# GECE GORUNUMU: kareler gece isiginda okunmali (catlak isimasi da).
	# night_started EMIT EDILMEZ (cift dalga olurdu) — faz elle kurulur.
	# elapsed=0 SART: 120 verilince phase_progress 0.5 oldu ve isiklar
	# safak renklerine harmanlandi (2. tur kareleri pembe/gunduz cikti).
	DayNight.phase = "night"
	DayNight.is_night = true
	DayNight.elapsed = 0.0
	_update_daylight()
	# ISIK OTURSUN: 5. tur dersi — kurulumdan hemen sonra cekilen kare
	# hala gunduz gibi cikiyor (gecis ~1.5 sn'de oturuyor); dogma karesi
	# de gece isiginda olsun diye beklenir.
	await get_tree().create_timer(1.5).timeout
	var night_no: int = DayNight.day
	_on_night_started()
	var spawned := _live_creature_count()
	var beklenen: int = CreatureBalance.min_wave_count(night_no)
	# Ocak'a olan TOPLAM uzaklik azaliyor mu? (hedefe ilerleme kaniti —
	# yalniz dalga yaratiklari, sahneleme henuz yok)
	var target_pos := _cell_center(hc) if hc != Vector2i(-999, -999) \
			else player.position
	var d0 := _creatures_total_dist(target_pos)
	for i in 40:  # ~40 kare ilerlet
		_tick_creatures(0.05)
	var d1 := _creatures_total_dist(target_pos)
	var yaklasti: bool = d1 < d0 - 0.01
	# --- KARE SAHNESI (2. tur dersi): dalga BILEREK sisli/agacli yerde
	# doguyor, kamera agac tacina gomuldu (4 kare de yesil duvar cikti).
	# Kareler icin AYNI dogum yolundan (spawn_creature + birth + ayni
	# parcaciklar) kamp yakininda 2-hucre cevresi NESNESIZ bir acik
	# hucrede kucuk bir suru sahnelenir; dalga sayilari NIGHTTEST'te.
	var sahne := Vector2i(-999, -999)
	var pcell := _player_cell()
	for r in range(6, 16):
		if sahne != Vector2i(-999, -999):
			break
		for aci in range(0, 360, 20):
			var c := pcell + Vector2i(int(round(cos(deg_to_rad(aci)) * r)),
					int(round(sin(deg_to_rad(aci)) * r)))
			if c.x < 3 or c.y < 3 or c.x >= _map_w - 3 or c.y >= _map_h - 3:
				continue
			if not is_walkable(c):
				continue
			var acik := true
			for oy in range(-2, 3):
				for ox in range(-2, 3):
					if _objects.has(c + Vector2i(ox, oy)):
						acik = false
						break
				if not acik:
					break
			if acik:
				sahne = c
				break
	if sahne != Vector2i(-999, -999):
		var suru: Array = []
		for off: Vector2i in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(-1, 1)]:
			var c2 := sahne + off
			if is_walkable(c2):
				var sc = spawn_creature(c2, "normal")
				sc.birth(CreatureBalance.BIRTH_SECONDS)
				var dp: Vector3 = sc.position + Vector3(0, 0.15, 0)
				_spawn_particles(dp, CreatureBalance.BIRTH_ASH_COLOR, 12)
				_spawn_particles(dp, CreatureBalance.BIRTH_SHELL_COLOR, 7)
				suru.append(sc)
		if not suru.is_empty():
			var oncu: Node3D = suru[0]
			# KARE 1: DOGMA — govde YARI CIKMISKEN (birth: 0.35 sn duman,
			# sonra 0.65 sn yukselme; 0.6'da yaklasik yari boyda)
			camera.position = oncu.position + Vector3(-1.6, 1.5, 2.2)
			camera.look_at(oncu.position + Vector3(0, 0.3, 0))
			await get_tree().create_timer(0.55).timeout
			# Ilk dumanin omru (0.5 sn) snap'e yetismiyordu — kul bulutu
			# tam kare aninda tazelenir (dogrulma dumani karede gorunsun).
			_spawn_particles(oncu.position + Vector3(0, 0.3, 0),
					CreatureBalance.BIRTH_ASH_COLOR, 10)
			await get_tree().create_timer(0.15).timeout
			_snap(save_path.replace(".png", "_gece_dogma.png"))
			# KARE 2: SURU Ocak'a yururken — arkadan, yakin kadraj
			await get_tree().create_timer(0.6).timeout  # dogrulma bitsin
			for i in 30:
				_tick_creatures(0.05)
			if is_instance_valid(oncu):
				var yon: Vector3 = (target_pos - oncu.position)
				yon.y = 0.0
				yon = yon.normalized() if yon.length() > 0.01 else Vector3.FORWARD
				camera.position = oncu.position - yon * 3.2 + Vector3(0, 2.4, 0)
				camera.look_at(oncu.position + yon * 1.5 + Vector3(0, 0.4, 0))
				await get_tree().create_timer(0.4).timeout
				_snap(save_path.replace(".png", "_gece_yaratik.png"))
			# KARE 3: MESALE ISIGINDA — yavaslar + catlak isimasi soner
			if is_instance_valid(oncu):
				var mcell: Vector2i = oncu.cell() + Vector2i(1, 0)
				if _ground_char.get(mcell, "") in [".", "d", "s"] \
						and not _objects.has(mcell) and not _placed.has(mcell):
					_set_placed(mcell, "mesale")
				for i in 10:
					_tick_creatures(0.05)  # isik algisi ve sonme otursun
				camera.position = oncu.position + Vector3(-2.0, 2.0, 2.8)
				camera.look_at(oncu.position + Vector3(0, 0.5, 0))
				await get_tree().create_timer(0.35).timeout
				_snap(save_path.replace(".png", "_gece_mesale.png"))
	# SAFAK + KARE 4: 2 sn kul erimesinin ortasi (kucule kucule dagilma)
	_on_dawn_clear_creatures()
	await get_tree().create_timer(0.8).timeout
	_snap(save_path.replace(".png", "_gece_erime.png"))
	await get_tree().create_timer(1.5).timeout
	var kalan := _live_creature_count()
	var line := "NIGHTTEST: gece=%d beklenen=%d dogan=%d ocak=%s yaklasti=%s safak_kalan=%d" % [
		night_no, beklenen, spawned, str(hc != Vector2i(-999, -999)),
		str(yaklasti), kalan]
	print(line)
	var f := FileAccess.open("res://docs/screens/nighttest.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(line + "\n")
		f.close()
	# Gunduze don: akistaki sonraki kareler gunduz isiginda cekilir
	DayNight.phase = "day"
	DayNight.is_night = false
	DayNight.elapsed = 0.0
	_update_daylight()

## Tum canli yaratiklarin verilen noktaya toplam uzakligi (test olcusu).
func _creatures_total_dist(target: Vector3) -> float:
	var total := 0.0
	for cr in _creatures:
		if is_instance_valid(cr) and cr.is_alive():
			total += Vector2(cr.position.x - target.x,
					cr.position.z - target.z).length()
	return total

# --- GECE DALGASI — MİNİMAL (yaratik-gece) -------------------------------
# Kapsam: gece basinda TEK grup dogar, duz cizgide hedefe gider, onune cikan
# YAPIYI kirar, oyuncuya temasta vurur, safakta erir. A* / tip karisimi /
# tuzak tetiklenmesi / oz harcama KAPSAM DISI (sonraki turlar).
# Tum sayilar CreatureBalance'in MIN_* blogunda.

var _night_wave_active: bool = false
var _night_damage_taken: bool = false  # sabah ozeti icin (hasarsiz gece mi)

## Gece basladi: o gecenin kademesine gore tek grup dogur.
## KESIF 16.4: oyuncu Ocak'tan uzaksa (sefer) base dalgasi SIMULE edilir
## (gercek zamanli cift sahne yok — mobil); oyuncunun yanina yalniz
## atesli kampin cektigi kucuk karsilasma gelir.
func _on_night_started() -> void:
	_night_wave_active = true
	_night_damage_taken = false
	var hc := get_hearth()
	var uzak: bool = hc != Vector2i(-999, -999) \
			and Vector2(_player_cell() - hc).length() > KesifBalance.SEFER_UZAK_R
	_sefer_gecesi = uzak
	if uzak:
		var sonuc := _sefer_dalga_simule(DayNight.day)
		_sabah_raporu = String(sonuc["rapor"])
		_kamp_gecesi_karsilasma(DayNight.day)
	else:
		_spawn_night_wave(DayNight.day)

## O gecenin yaratiklarini dogus halkasindan dogurur (_pick_spawn_cell).
func _spawn_night_wave(night: int) -> void:
	var want: int = CreatureBalance.min_wave_count(night)
	# KESIF 16.3 gece sertlesmesi: yakilan ana tas basina dalga buyur
	# (HIKAYE 8 gorunurluk bedeli — cemberi buyutmenin karsiligi).
	want = int(round(float(want)
			* KesifBalance.gece_sertlesme(_yanik_ana_sayisi())))
	var room: int = CreatureBalance.MIN_MAX_ACTIVE - _live_creature_count()
	want = mini(want, maxi(0, room))
	var hp_mult: float = CreatureBalance.night_hp_mult(night)
	# Tip karisimi VERIDEN geliyor (CreatureBalance.wave_mix): hangi tipin
	# hangi geceden itibaren cikacagi TYPES.first_night'ta yaziyor, burada
	# hicbir tip adi gecmiyor.
	var mix: Array = CreatureBalance.wave_mix(night, want)
	var made := 0
	var sayim: Dictionary = {}
	for i in want:
		var cell := _pick_spawn_cell()
		if cell == Vector2i(-999, -999):
			break
		var tip: String = String(mix[i]) if i < mix.size() else "normal"
		var cr = spawn_creature(cell, tip, hp_mult)
		# TOPRAKTAN DOGRULMA: govde gomuk baslar, kul-duman + kabuk
		# parcaciklariyla 1 sn'de dogrulur; bu surece AI islemez (daze).
		cr.birth(CreatureBalance.BIRTH_SECONDS)
		var dp: Vector3 = cr.position + Vector3(0, 0.15, 0)
		_spawn_particles(dp, CreatureBalance.BIRTH_ASH_COLOR, 12)
		_spawn_particles(dp, CreatureBalance.BIRTH_SHELL_COLOR, 7)
		sayim[tip] = int(sayim.get(tip, 0)) + 1
		made += 1
	print("NIGHTWAVE: gece=%d istenen=%d dogan=%d aktif=%d karisim=%s" % [
		night, want, made, _live_creature_count(), str(sayim)])

## DOGUS HALKASI (yaratik-gece): kenardan DEGIL — Ocak (yoksa oyuncu)
## merkezli halkada, sisli/ormanlik yonler AGIRLIKLI rastgele nokta.
## Oyuncunun gorus alaninda (frustum) dogmaz. Aday bulunamazsa halka
## denemeler ilerledikce daralir; en son eski kenar banti son care.
func _pick_spawn_cell() -> Vector2i:
	var pc := _player_cell()
	var hc := get_hearth()
	var merkez := hc
	if merkez == Vector2i(-999, -999):
		merkez = _camp_at("ocak")
	if merkez == Vector2i(-999, -999):
		merkez = pc
	var adaylar: Array = []      # {cell, puan}
	var toplam_puan := 0.0
	for attempt in CreatureBalance.SPAWN_TRIES:
		var relax: float = float(attempt) / float(CreatureBalance.SPAWN_TRIES)
		# Halka daralmasi: bulamadikca ic yaricap dusurulur (kucuk/kapali
		# haritada hic dogmamasindansa biraz yakin dogsun).
		var r_min: float = lerpf(float(CreatureBalance.SPAWN_RING_MIN), 8.0, relax)
		var r_max: float = float(CreatureBalance.SPAWN_RING_MAX)
		var aci: float = randf() * TAU
		var r: float = randf_range(r_min, r_max)
		var cell := Vector2i(merkez.x + int(round(cos(aci) * r)),
				merkez.y + int(round(sin(aci) * r)))
		if cell.x < 1 or cell.y < 1 or cell.x >= _map_w - 1 or cell.y >= _map_h - 1:
			continue
		if not is_walkable(cell):
			continue
		var min_p: float = float(CreatureBalance.SPAWN_MIN_DIST_PLAYER) * (1.0 - relax)
		if Vector2(cell - pc).length() < min_p:
			continue
		# GOZ ONUNDE BELIRME YASAK: kamera bu noktayi goruyorsa atla.
		if camera != null and camera.is_position_in_frustum(
				_cell_center(cell) + Vector3(0, 0.6, 0)):
			continue
		# Agirlik: sisli yer cazip (karanliktan gelirler), agac dibi cazip.
		var puan: float = 1.0 \
				+ maxf(0.0, _sis_at_cell(cell)) * CreatureBalance.SPAWN_FOG_BONUS
		for komsu in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if String(_objects.get(cell + komsu, "")) == "T":
				puan += CreatureBalance.SPAWN_TREE_BONUS
				break
		adaylar.append({"cell": cell, "puan": puan})
		toplam_puan += puan
		if adaylar.size() >= CreatureBalance.SPAWN_CANDIDATES:
			break
	if not adaylar.is_empty():
		var sec: float = randf() * toplam_puan
		for a: Dictionary in adaylar:
			sec -= float(a["puan"])
			if sec <= 0.0:
				return Vector2i(a["cell"])
		return Vector2i(adaylar[-1]["cell"])
	# SON CARE: eski kenar banti (halka tamamen kapaliysa gece bos gecmesin)
	for attempt in CreatureBalance.SPAWN_TRIES:
		var cell := _random_edge_cell(CreatureBalance.SPAWN_EDGE_MARGIN)
		if is_walkable(cell) and Vector2(cell - pc).length() \
				>= float(CreatureBalance.SPAWN_MIN_DIST_PLAYER) * 0.5:
			return cell
	return Vector2i(-999, -999)

## Haritanin dort kenarindan birinde, ic bantta rastgele hucre.
func _random_edge_cell(margin: int) -> Vector2i:
	var band: int = maxi(1, margin)
	var xmax: int = maxi(1, _map_w - 2)
	var ymax: int = maxi(1, _map_h - 2)
	var side := randi() % 4
	if side == 0:   # ust kenar
		return Vector2i(randi_range(1, xmax), randi_range(1, band))
	if side == 1:   # alt kenar
		return Vector2i(randi_range(1, xmax), randi_range(maxi(1, ymax - band), ymax))
	if side == 2:   # sol kenar
		return Vector2i(randi_range(1, band), randi_range(1, ymax))
	return Vector2i(randi_range(maxi(1, xmax - band), xmax), randi_range(1, ymax))

func _live_creature_count() -> int:
	var n := 0
	for cr in _creatures:
		if is_instance_valid(cr) and cr.is_alive():
			n += 1
	return n

## Her kare: hedefe DUZ git, engelde vur, temasta saldir, takilirsa yana kay.
func _tick_creatures(delta: float) -> void:
	if _creatures.is_empty():
		return
	var ppos := player.position
	var hearth := get_hearth()
	for cr in _creatures:
		if not is_instance_valid(cr) or not cr.is_alive():
			continue
		_tick_one_creature(cr, delta, ppos, hearth)

## NOT: `cr` BILEREK tipsiz — `cr: Node3D` yazilirsa attack_cd/lunge/cell
## gibi creature.gd uyeleri Node3D'de bulunamaz ve TUM dosya parse hatasi
## verir (ayni tuzaga bir kez dusuldu).
func _tick_one_creature(cr, delta: float, ppos: Vector3,
		hearth: Vector2i) -> void:
	# UZAKTAKILERI BASITLESTIR (mobil): goz isigi kapanir.
	var dist_to_player: float = Vector2(cr.position.x - ppos.x,
			cr.position.z - ppos.z).length()
	cr.set_simplified(dist_to_player > CreatureBalance.FAR_SIMPLIFY_DIST)
	# DOGMA SERSEMLIGI (yaratik-gece): topraktan dogrulurken AI islemez —
	# efekt okunur, yaratik "yerden cikip" sonra yurumeye baslar.
	if cr.daze > 0.0:
		cr.daze -= delta
		cr.set_moving(false)
		return
	# HEDEF (yaratik-gece kurali): OYUNCU MENZILDEYSE oyuncu, degilse
	# Ocak. Gecmis: once "yakinsa kovala" vardi, oyuncu pesinde kampi
	# unutuyorlardi; sonra "hep Ocak" yapildi. Yeni kural ikisinin
	# ortasi — SINIRLI kovalamaca: AGGRO_RANGE icindeki oyuncu hedef
	# olur ama menzilden cikinca yaratik BIRAKIP Ocak'a doner (bitmeyen
	# takip geri gelmez; yoluna cikan oyuncu da gormezden gelinmez).
	# OCAK YOKSA kamp merkezindeki ocak isaretine yurunur: gecenin derdi
	# ilk geceden itibaren BIR YERI korumak.
	var hedef_hucre := hearth
	if hedef_hucre == Vector2i(-999, -999):
		# Prefabtaki Ocak isareti: kamp merkezinden farkli bir yere
		# tasinirsa yaratiklar YENI yerine yurur (isaret yoksa merkez).
		hedef_hucre = _camp_at("ocak")
	var target := _cell_center(hedef_hucre) if hedef_hucre != Vector2i(-999, -999) \
			else ppos
	if dist_to_player <= CreatureBalance.AGGRO_RANGE:
		target = ppos
	# KESIF 16.6: ortam yaratiklari base'e YURUMEZ — dert oyuncudur.
	# Damar catlagi yakindaysa isiga cekilir (dogal oz lambasi: akilli
	# oyuncu tuzak olarak kullanir).
	if cr.has_meta("uzak"):
		target = ppos
		var damar := _damar_yakin(Vector2i(int(cr.position.x), int(cr.position.z)))
		if damar != Vector2i(-999, -999):
			target = _cell_center(damar)
	# Oyuncu YOLA GIRDIYSE yine de vurur: bu bir hedef degisimi degil,
	# temas tepkisi. Olmasaydi yaratik seni doverken bile umursamaz
	# gorunurdu.
	var target_is_player: bool = dist_to_player <= CreatureBalance.CONTACT_RANGE
	# OYUNCUYA TEMAS: menzildeyse vur (bekleme suresiyle).
	cr.attack_cd = maxf(0.0, cr.attack_cd - delta)
	if target_is_player and dist_to_player <= CreatureBalance.CONTACT_RANGE:
		if cr.attack_cd <= 0.0:
			cr.attack_cd = CreatureBalance.ATTACK_COOLDOWN
			var dmg: float = float(cr.damage) \
					* CreatureBalance.night_damage_mult(DayNight.day)
			Health.damage(dmg)
			_night_damage_taken = true
			cr.lunge(Vector3(ppos.x - cr.position.x, 0.0, ppos.z - cr.position.z))
		cr.set_moving(false)
		return
	# --- YOL BULMA (Asama 2) --------------------------------------------
	# Once duz cizgi vardi; engelde yana kayiyordu, yani duvar dolasamiyor
	# ve onunde sikisiyordu. Artik A* ile hucre yolu cikariliyor ve
	# yaratik yolun bir sonraki DUGUMUNE yoneliyor.
	var goal := Vector2i(floori(target.x), floori(target.z))
	cr.repath_cd = maxf(0.0, cr.repath_cd - delta)
	# Yeniden planlama: sure dolduysa YA DA hedef belirgin kaydiysa.
	# Ikincisi olmadan oyuncu kosarak uzaklasinca yaratik eski yolu
	# takip edip aptal gorunurdu.
	var goal_shift: int = absi(goal.x - cr.path_goal.x) \
			+ absi(goal.y - cr.path_goal.y)
	if cr.repath_cd <= 0.0 or cr.path.is_empty() \
			or goal_shift >= CreatureBalance.REPATH_TARGET_SHIFT:
		cr.repath_cd = CreatureBalance.REPATH_SECONDS
		cr.path_goal = goal
		cr.path = CreatureAI.find_path(self, cr.cell(), goal, cr.traits())
	# Ulasilan dugumleri yoldan dus
	while not cr.path.is_empty() and Vector2i(cr.path[0]) == cr.cell():
		cr.path.remove_at(0)
	# Yol varsa bir sonraki dugume, yoksa hedefe dogru (son care)
	var aim := target
	if not cr.path.is_empty():
		var nc: Vector2i = cr.path[0]
		aim = Vector3(float(nc.x) + 0.5, cr.position.y, float(nc.y) + 0.5)
	var dir := Vector3(aim.x - cr.position.x, 0.0, aim.z - cr.position.z)
	if dir.length() < 0.01:
		cr.set_moving(false)
		return
	dir = dir.normalized()
	var speed: float = cr.speed
	# ISIK TEPKISI (Isik Kurami'nin gorunur hali): Ocak/mesale isiginda
	# %10 yavaslar + catlak isimasi soner (emission kismasi creature'da).
	var isikta := _pos_in_light(cr.position)
	cr.set_in_light(isikta)
	if isikta:
		speed *= CreatureBalance.LIGHT_SLOW
	if cr.side_time > 0.0:
		cr.side_time -= delta
		dir = Vector3(-dir.z, 0.0, dir.x) * cr.side_sign
		speed *= CreatureBalance.STUCK_SIDE_SPEED
	# YETENEKLER burada da okunuyor. Yol bulmaya baglamak YETMIYOR:
	# A* yuzucuyu sudan gecirse bile hareket kodu "yurunemez" deyip
	# durdurursa yaratik suyun kiyisinda takilir kalir. Iki taraf ayni
	# yetenegi okumali.
	var yet: Dictionary = cr.traits()
	var yuzucu: bool = bool(yet.get("swim", false))
	var tirmanici: bool = bool(yet.get("climb", false))
	# `cr` tipsiz -> cr.position Variant; ACIK tip sart (yoksa parse hatasi).
	var next_pos: Vector3 = cr.position + dir * speed * delta
	var next_cell := Vector2i(floori(next_pos.x), floori(next_pos.z))
	# ONUNE ENGEL CIKTI MI? Yol zaten kirilabilir engelleri PAHALI sayip
	# gecerli buluyor; yani buraya gelmek "yol beni bilerek duvarin
	# ustunden gecirdi" demek. Dur ve vur.
	# CIT KENARI (cit-sistemi): gecis kenardan kapaliysa once cite bak.
	# Tirmanici alcak citi ASAR (yavaslayarak); digerleri durup KIRAR —
	# citin cani az, birkac vurusta gedik acilir.
	if next_cell != cr.cell() and fence_blocked(cr.cell(), next_cell):
		if tirmanici:
			speed *= CreatureBalance.CLIMB_SLOW
			next_pos = cr.position + dir * speed * delta
			next_cell = Vector2i(floori(next_pos.x), floori(next_pos.z))
		else:
			cr.struct_cd = maxf(0.0, cr.struct_cd - delta)
			if cr.struct_cd <= 0.0:
				cr.struct_cd = CreatureBalance.STRUCT_ATTACK_COOLDOWN
				var smc: int = int(CreatureBalance.stat(
						String(cr.type), "struct_mult", 1))
				_fence_take_hit(_edge_between(cr.cell(), next_cell),
						CreatureBalance.STRUCT_DAMAGE * smc, dir)
				cr.lunge(dir)
			_bump_stuck(cr, delta)
			return
	if next_cell != cr.cell() and not is_walkable(next_cell):
		var yapi: bool = _placed.has(next_cell) or _objects.has(next_cell)
		# GECEBILEN TIP: kirmaz, gecer — ama yavaslayarak (bedava degil).
		if yuzucu and is_swimmable(next_cell):
			speed *= CreatureBalance.SWIM_SLOW
			next_pos = cr.position + dir * speed * delta
		elif tirmanici and yapi:
			speed *= CreatureBalance.CLIMB_SLOW
			next_pos = cr.position + dir * speed * delta
		else:
			cr.struct_cd = maxf(0.0, cr.struct_cd - delta)
			if yapi:
				if cr.struct_cd <= 0.0:
					cr.struct_cd = CreatureBalance.STRUCT_ATTACK_COOLDOWN
					# KIRICI yapiya cok daha sert vurur (struct_mult).
					var sm: int = int(CreatureBalance.stat(
							String(cr.type), "struct_mult", 1))
					_structure_take_hit(next_cell,
							CreatureBalance.STRUCT_DAMAGE * sm, dir)
					cr.lunge(dir)
			_bump_stuck(cr, delta)
			cr.set_moving(false)
			return
	var before: Vector3 = cr.position
	cr.position = Vector3(next_pos.x,
			ground_height(next_pos.x, next_pos.z), next_pos.z)
	var adim: float = Vector2(cr.position.x - before.x,
			cr.position.z - before.z).length()
	if adim < CreatureBalance.STEP_EPSILON:
		_bump_stuck(cr, delta)
	else:
		cr.stuck_time = 0.0
	# ANIMASYON SENKRONU: klip yalniz GERCEKTEN ilerlerken oynar (kayma yok).
	cr.set_moving(adim >= CreatureBalance.STEP_EPSILON)
	cr.face_direction(dir)

## Nokta yanan Ocak ya da bir mesalenin isik alaninda mi? (yaratik-gece)
## Mesale sayisi kucuk (sozluk), yaratik <= 12 — kare basi maliyet onemsiz.
func _pos_in_light(pos: Vector3) -> bool:
	var hc := get_hearth()
	if hc != Vector2i(-999, -999) and _hearth_light != null \
			and is_instance_valid(_hearth_light) and _hearth_light.visible:
		var hp := _cell_center(hc)
		if Vector2(pos.x - hp.x, pos.z - hp.z).length() \
				<= CreatureBalance.LIGHT_RANGE_HEARTH:
			return true
	for c: Vector2i in _torch_lights:
		var l = _torch_lights[c]
		if l == null or not is_instance_valid(l) or not l.visible:
			continue
		var tp := _cell_center(c)
		if Vector2(pos.x - tp.x, pos.z - tp.z).length() \
				<= CreatureBalance.LIGHT_RANGE_TORCH:
			return true
	return false

## Ilerleyemedi: sayaci isle, esigi gecince bir sure YANA kay (A* yerine).
func _bump_stuck(cr, delta: float) -> void:
	cr.stuck_time += delta
	if cr.stuck_time >= CreatureBalance.STUCK_SECONDS:
		cr.stuck_time = 0.0
		cr.side_time = CreatureBalance.STUCK_SIDE_SECONDS
		cr.side_sign = 1.0 if randf() < 0.5 else -1.0

## Safak: gece bitti, kalan yaratiklar erir; sabah pili.
func _on_dawn_clear_creatures() -> void:
	var left := _live_creature_count()
	for cr in _creatures:
		if is_instance_valid(cr) and cr.is_alive():
			# KUL OLUP DAGILMA: gri kul bulutu + govde 2 sn'de erir.
			# OZ DUSMEZ (oz yalniz oldurulunce — melt bunu garantiler).
			_spawn_particles(cr.position + Vector3(0, 0.5, 0),
					CreatureBalance.BIRTH_ASH_COLOR, 10)
			cr.melt(CreatureBalance.DAWN_MELT_SECONDS)
	_creatures.clear()
	if _night_wave_active:
		_night_wave_active = false
		var night: int = maxi(1, DayNight.day - 1)
		if hud != null:
			hud.flash_pill("Gece %d atlatıldı" % night)
		print("NIGHTCLEAR: gece=%d kalan=%d hasar_aldi=%s" % [
			night, left, str(_night_damage_taken)])

## Tum yaratiklari temizle (reset/reload/safak temizligi ortak yol).
func _clear_creatures() -> void:
	for cr in _creatures:
		if is_instance_valid(cr):
			cr.queue_free()
	_creatures.clear()

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

# --- KALITE KADEMESI + FPS OVERLAY (mobil perf) ------------------------

## Grafik kalitesini uygular: gunes golgesi ac/kapa + menzil + atlas
## cozunurlugu + mesale isik butcesi. Ayarlar'dan secilir; user://'ye kaydedilir.
	_update_water_warm_lights()  # SU V1: yeni sicak isik
func apply_quality(tier: String) -> void:
	if not PerfBalance.TIERS.has(tier):
		tier = PerfBalance.DEFAULT_TIER
	_quality_tier = tier
	var t := PerfBalance.tier(tier)
	_max_torches = int(t["max_torches"])
	if _sun != null and is_instance_valid(_sun):
		_sun.shadow_enabled = bool(t["dir_shadow"])
		_sun.directional_shadow_max_distance = float(t["dir_shadow_dist"])
	RenderingServer.directional_shadow_atlas_set_size(int(t["dir_shadow_size"]), true)

func _on_quality_changed(tier: String) -> void:
	_apply_water_tier()  # C: Dusuk'te dalga/parilti kapansin
	_apply_cim_tier()    # CIM V1: ruzgar/ezme kademesi
	apply_quality(tier)
	_save_quality()

func _save_quality() -> void:
	var f := FileAccess.open(QUALITY_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(_quality_tier)
		f.close()

func _load_quality() -> void:
	if not FileAccess.file_exists(QUALITY_PATH):
		return
	var f := FileAccess.open(QUALITY_PATH, FileAccess.READ)
	if f != null:
		var t := f.get_as_text().strip_edges()
		f.close()
		if PerfBalance.TIERS.has(t):
			_quality_tier = t

func _build_perf_overlay() -> void:
	_perf_layer = CanvasLayer.new()
	_perf_layer.layer = 3
	_perf_layer.visible = false
	add_child(_perf_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(10, 10)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.07, 0.10, 0.66)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", st)
	_perf_layer.add_child(panel)
	_perf_label = Label.new()
	_perf_label.add_theme_font_size_override("font_size", 16)
	_perf_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	_perf_label.text = "FPS…"
	panel.add_child(_perf_label)

func _on_perf_overlay_toggled(on: bool) -> void:
	_perf_on = on
	if _perf_layer != null:
		_perf_layer.visible = on
	if on:
		_perf_acc = 999.0
		_perf_fps.clear()

func _update_perf_overlay(delta: float) -> void:
	_perf_fps.append(Performance.get_monitor(Performance.TIME_FPS))
	if _perf_fps.size() > 30:
		_perf_fps.pop_front()
	_perf_acc += delta
	if _perf_acc < 0.25:
		return
	_perf_acc = 0.0
	var fps := 0.0
	for v in _perf_fps:
		fps += v
	fps /= maxf(1.0, _perf_fps.size())
	var frame_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var draw := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_perf_label.text = "FPS %d\nframe %.1f ms\ndraw %d\nkalite: %s" % [
		int(round(fps)), frame_ms, draw,
		PerfBalance.tier_val(_quality_tier, "label", _quality_tier)]

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
		if i < _max_torches:
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
	# AGAC KESIM SAHNESI (agac-kesim): son vurusta agac ANINDA yok olmaz —
	# oyuncudan uzaga DEVRILIR, odunlar govde hattina sacilir. Carpismasi
	# hemen ACILIR (MultiMesh orneği silinir, animasyonlu kopya carpissiz).
	if ch == "T":
		_objects.erase(cell)
		_solid_cells.erase(cell)
		_rebuild_objects()
		_hit_stop(0.55, 0.05)
		_fell_tree(cell, drops)
		_dirty = true
		return true
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

## GRIP AYAR MODU (debug): HUD butonlarini oyuncunun canli grip ofsetine
## baglar; her degisiklikten sonra durum paneline geri yazilir.
func _on_grip_nudge(axis: int, delta: float) -> void:
	player.grip_nudge(axis, delta)
	hud.set_grip_status(player.grip_status())

func _on_grip_rotate(axis: int, deg: float) -> void:
	player.grip_rotate(axis, deg)
	hud.set_grip_status(player.grip_status())

## EKRAN YONU: kameraya gore yukari/asagi/sag/sol -> dunya vektoru.
## Kurek gibi capraz modellenen aletlerde X/Y/Z el cercevesinde kaldigi
## icin gozle eslesmiyordu; bu butonlar GORDUGUN yonde kaydirir.
func _on_grip_move(dir_id: String) -> void:
	var right: Vector3 = camera.global_transform.basis.x
	right.y = 0.0
	if right.length() < 0.001:
		right = Vector3.RIGHT
	right = right.normalized()
	var world := Vector3.ZERO
	match dir_id:
		"yukari": world = Vector3.UP
		"asagi": world = Vector3.DOWN
		"sag": world = right
		"sol": world = -right
	# NOT: `hud` CanvasLayer olarak tipli -> hud.GRIP_STEP_M static hata verir;
	# sabit script kaynagindan okunur (tek dogruluk kaynagi korunur).
	player.grip_nudge_world(world, HudScript.GRIP_STEP_M)
	hud.set_grip_status(player.grip_status())

func _on_grip_reset() -> void:
	player.grip_reset()
	hud.set_grip_status(player.grip_status())

func _on_grip_save() -> void:
	# NOT: `:=` KULLANMA — player untyped oldugundan donus tipi cikarilamaz
	# ve TUM world3d.gd "Parse error" ile yuklenmez (oyun sessizce acilmaz).
	var line: String = player.grip_save()
	hud.set_grip_status(player.grip_status())
	hud.show_grip_code(line)

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

# =======================================================================
# YERLESIM EDITORU (gelistirici araci)
# =======================================================================
# Amaç: kampi/yollari OYUN ICINDE elle duzenleyip sonucu bir veri
# dosyasina aktarmak; dunya uretimi o dosyayi okuyup baslangic kampini
# ondan kurmak.
#
# UC KURAL, uculu de bilincli:
#  1) YALNIZ DEBUG. Anahtar hud.gd'de OS.is_debug_build() / TestMode
#     kapisinin ardinda; yayin surumunde hic olusturulmuyor.
#  2) OYUN MANTIGINA DOKUNMAZ. Editor mevcut yerlestirme sistemini
#     (_place_valid / _set_placed / lay_road) OLDUGU GIBI kullanir;
#     tek atlanan sey MALZEME MALIYETI. Boylece editorde gecerli olan
#     yerlesim oyunda da gecerli — iki ayri kural seti olusmuyor.
#  3) KAYDA YAZMAZ. Editor acikken otomatik kayit durur; cikista dunya
#     kayittan yeniden yuklenir. Yani editorde yaptigin hicbir sey
#     oyun kaydina sizmaz (gorev 4).
const LayoutEditor = preload("res://scripts/layout_editor.gd")

var _editor_on: bool = false
var _editor_tool: String = LayoutEditor.ARAC_YERLESTIR
var _editor_kat: String = "yapi"
var _editor_item: String = "ocak"
var _editor_rot: int = 0
var _editor_olcek: float = 1.0
## Editorde konulan ogeler: hucre -> kayit sozlugu. Disa aktarim bunu yazar.
var _editor_ogeler: Dictionary = {}
## Geri al yigini: son UNDO_MAX islem.
var _editor_undo: Array = []
var _editor_sel := Vector2i(-999, -999)
var _editor_ring: Node3D = null
## Editor oncesi zaman durumu (cikista geri verilir)
var _editor_eski_proc: int = Node.PROCESS_MODE_INHERIT

func editor_aktif() -> bool:
	return _editor_on

## Editor modunu ac/kapa.
func editor_set_enabled(on: bool) -> void:
	if on == _editor_on:
		return
	_editor_on = on
	if on:
		# Zaman DONUK: gece gelmesin, aclik/susuzluk islemesin, yaratik
		# olmasin. Isik onizlemesi icin gunduz/gece butonlari calisiyor
		# (DayNight.jump_to_* islem dongusunden bagimsiz).
		_editor_eski_proc = DayNight.process_mode
		DayNight.process_mode = Node.PROCESS_MODE_DISABLED
		Thirst.process_mode = Node.PROCESS_MODE_DISABLED
		_clear_creatures()
		_exit_place_mode()
		_editor_ogeler.clear()
		_editor_undo.clear()
		_editor_sel = Vector2i(-999, -999)
		hud.set_editor_mode(true)
		hud.set_editor_status("Editör açık — zaman donuk, kayıt kapalı")
	else:
		DayNight.process_mode = _editor_eski_proc
		Thirst.process_mode = Node.PROCESS_MODE_INHERIT
		_editor_temizle_halka()
		hud.set_editor_mode(false)
		# Editor degisiklikleri oyuna SIZMASIN: dunya kayittan yeniden
		# yuklenir. Kayit yoksa (yeni oyun) sahne oldugu gibi kalir —
		# zaten kaydedilmedigi icin bir sonraki acilista temiz baslar.
		if SaveManager.has_save():
			SaveManager.load_game()

## Arac secimi (HUD cubugu cagirir).
func editor_set_tool(arac: String) -> void:
	_editor_tool = arac
	_editor_sel = Vector2i(-999, -999)
	_editor_temizle_halka()
	hud.set_editor_status("Araç: %s" % String(LayoutEditor.ARAC_ADI.get(arac, arac)))

## YERLESTIR listesinden oge secimi.
func editor_set_item(kat: String, id: String) -> void:
	_editor_kat = kat
	_editor_item = id
	_editor_rot = 0
	_editor_olcek = 1.0
	_editor_tool = LayoutEditor.ARAC_YERLESTIR
	# Hayalet onizleme: yalniz YAPI kategorisinde mevcut sistem kullanilir
	# (dekor/yol/tarla tek hucrelik, hayalete gerek yok — hedef halkasi
	# zaten hucreyi gosteriyor).
	if kat == "yapi" and PLACE_MODELS.has(id):
		_place_mode = true
		_place_item = id
		_place_rot = 0
		_build_ghost()
		hud.set_place_mode(false)   # oyun icindeki Onayla/Iptal cubugu YOK
	else:
		_exit_place_mode()
	hud.set_editor_status("Seçili: %s" % id)

func editor_rotate() -> void:
	_editor_rot = (_editor_rot + 90) % 360
	if _place_mode and _ghost != null:
		_place_rot = _editor_rot
		_ghost.rotation_degrees.y = float(_editor_rot)
	# Secili oge varsa onu dondur
	if _editor_sel != Vector2i(-999, -999):
		_editor_dondur(_editor_sel)
	hud.set_editor_status("Dönüş: %d°" % _editor_rot)

func editor_set_olcek(v: float) -> void:
	_editor_olcek = clampf(v, LayoutEditor.OLCEK_MIN, LayoutEditor.OLCEK_MAX)
	if _editor_sel != Vector2i(-999, -999):
		var kayit: Dictionary = _editor_ogeler.get(_editor_sel, {})
		# Olcek YALNIZ dekor ogelerinde: yapilar hucreye oturuyor,
		# olcekleri degisirse carpisma ile gorsel ayrisir.
		if String(kayit.get("tur", "")) == "dekor":
			kayit["olcek"] = _editor_olcek
			_editor_ogeler[_editor_sel] = kayit
			_editor_dekor_ciz(_editor_sel, kayit)
	hud.set_editor_status("Ölçek: %%%d" % int(_editor_olcek * 100.0))

# --- Editor dokunus yonlendirmesi ---------------------------------------
## Editor acikken TUM dunya dokunuslari buraya gelir (mesafe siniri YOK:
## oyuncunun yanina gitmeden uzaga da koyabilmek editorun asil isi).
func _editor_tap(cell: Vector2i) -> void:
	match _editor_tool:
		LayoutEditor.ARAC_YERLESTIR:
			_editor_koy(cell)
		LayoutEditor.ARAC_SEC:
			_editor_sec(cell)
		LayoutEditor.ARAC_SIL:
			_editor_sil(cell)
		LayoutEditor.ARAC_YOL:
			_editor_yol(cell, false)

## YERLESTIR. Gecerlilik OYUNUN kurallariyla (_place_valid) kontrol edilir;
## yalniz maliyet atlanir. Ayni hucreye iki yapi konamaz (gorev 4).
func _editor_koy(cell: Vector2i) -> void:
	match _editor_kat:
		"yapi":
			if not PLACE_MODELS.has(_editor_item):
				return
			var eski_item := _place_item
			_place_item = _editor_item          # _place_valid bunu okur
			var v := _place_valid(cell)
			_place_item = eski_item
			if not bool(v["valid"]):
				_spawn_floating_text(cell, "Olmaz: %s" % String(v["reason"]),
						Color(1, 0.6, 0.6))
				return
			_set_placed(cell, _editor_item, _editor_rot)
			_place_pop(cell)
			_editor_kaydet(cell, "yapi", _editor_item, _editor_rot, 1.0)
		"yol":
			if is_road(cell):
				return
			lay_road(cell, "miras")
			_build_road()
			_editor_kaydet(cell, "yol", "yol_hucresi", 0, 1.0)
		"dekor":
			if _editor_ogeler.has(cell):
				return
			var kayit := {"tur": "dekor", "id": _editor_item,
					"rot": _editor_rot, "olcek": _editor_olcek}
			_editor_ogeler[cell] = kayit
			_editor_dekor_ciz(cell, kayit)
			_editor_undo_ekle({"is": "ekle", "hucre": cell})
		"tarla":
			if Farming.plots.has(cell) or not _till_valid(cell):
				return
			_try_till(cell)
			_editor_kaydet(cell, "tarla", "tarla_hucresi", 0, 1.0)

func _editor_kaydet(cell: Vector2i, tur: String, id: String,
		rot: int, olcek: float) -> void:
	_editor_ogeler[cell] = {"tur": tur, "id": id, "rot": rot, "olcek": olcek}
	_editor_undo_ekle({"is": "ekle", "hucre": cell})
	hud.set_editor_status("%s kondu (%d,%d) — toplam %d" % [
			id, cell.x, cell.y, _editor_ogeler.size()])

## SEC/TASI: ilk dokunus secer, ikinci dokunus SECILIYI o hucreye tasir.
func _editor_sec(cell: Vector2i) -> void:
	if _editor_sel == Vector2i(-999, -999):
		if not _editor_ogeler.has(cell) and not _placed.has(cell):
			return
		_editor_sel = cell
		_editor_halka_goster(cell)
		var k: Dictionary = _editor_ogeler.get(cell, {})
		hud.set_editor_status("Seçili: %s — hedefe dokun taşı" % String(
				k.get("id", _placed.get(cell, "?"))))
		hud.set_editor_scale_enabled(String(k.get("tur", "")) == "dekor")
		return
	if cell == _editor_sel:
		_editor_sel = Vector2i(-999, -999)
		_editor_temizle_halka()
		return
	_editor_tasi(_editor_sel, cell)

func _editor_tasi(from: Vector2i, to: Vector2i) -> void:
	var kayit: Dictionary = _editor_ogeler.get(from, {})
	var tur := String(kayit.get("tur", "yapi" if _placed.has(from) else ""))
	if tur == "":
		return
	var id := String(kayit.get("id", _placed.get(from, "")))
	# Hedef gecerli mi? Yapida oyunun kendi kurali, digerinde bosluk.
	if tur == "yapi":
		var eski := _place_item
		_place_item = id
		var v := _place_valid(to)
		_place_item = eski
		if not bool(v["valid"]):
			_spawn_floating_text(to, "Olmaz: %s" % String(v["reason"]),
					Color(1, 0.6, 0.6))
			return
	elif _editor_ogeler.has(to):
		return
	_editor_undo_ekle({"is": "tasi", "hucre": to, "eski": from,
			"kayit": kayit.duplicate()})
	_editor_kaldir(from, false)
	_editor_ogeler[to] = kayit
	match tur:
		"yapi":
			_set_placed(to, id, int(kayit.get("rot", 0)))
		"yol":
			lay_road(to, "miras")
			_build_road()
		"dekor":
			_editor_dekor_ciz(to, kayit)
		"tarla":
			_try_till(to)
	_editor_sel = to
	_editor_halka_goster(to)

## SIL — onay yok, geri-al var (gorev 2).
func _editor_sil(cell: Vector2i) -> void:
	if not _editor_ogeler.has(cell) and not _placed.has(cell) and not is_road(cell):
		return
	var kayit: Dictionary = _editor_ogeler.get(cell, {}).duplicate()
	if kayit.is_empty() and _placed.has(cell):
		kayit = {"tur": "yapi", "id": String(_placed[cell]),
				"rot": _structures.rotation_of(cell), "olcek": 1.0}
	if kayit.is_empty() and is_road(cell):
		kayit = {"tur": "yol", "id": "yol_hucresi", "rot": 0, "olcek": 1.0}
	_editor_undo_ekle({"is": "sil", "hucre": cell, "kayit": kayit})
	_editor_kaldir(cell, true)
	hud.set_editor_status("Silindi (%d,%d)" % [cell.x, cell.y])

## Hucredeki editor ogesini sahneden kaldirir (undo yigina DOKUNMAZ).
func _editor_kaldir(cell: Vector2i, kayittan_da: bool) -> void:
	if _placed.has(cell):
		_remove_placed(cell)
	if is_road(cell):
		_path_cells.erase(cell)
		_build_road()
	if Farming.plots.has(cell):
		Farming.plots.erase(cell)
		Farming.plot_changed.emit(cell)   # zemin/bitki dugumu yenilensin
	_editor_dekor_sil(cell)
	if kayittan_da:
		_editor_ogeler.erase(cell)
	else:
		_editor_ogeler.erase(cell)

func _editor_dondur(cell: Vector2i) -> void:
	var kayit: Dictionary = _editor_ogeler.get(cell, {})
	if kayit.is_empty():
		return
	kayit["rot"] = _editor_rot
	_editor_ogeler[cell] = kayit
	if String(kayit["tur"]) == "yapi" and _placed.has(cell):
		var node: Node3D = _placed_nodes.get(cell, null)
		if node != null:
			node.rotation_degrees.y = float(_editor_rot)
		var inst: Dictionary = _structures.get_inst(cell)
		if not inst.is_empty():
			inst["rot"] = _editor_rot
	elif String(kayit["tur"]) == "dekor":
		_editor_dekor_ciz(cell, kayit)

# --- Editor dekoru (tek tek dugum) --------------------------------------
## Editor dekoru MultiMesh DEGIL, tek tek Node3D: elle tasinabilmesi,
## dondurulebilmesi ve olceklenebilmesi gerekiyor. Sayilari onlarca
## mertebesinde oldugu icin bu maliyet kabul edilebilir; DUNYA
## uretimindeki serpinti hala MultiMesh (editor ciktisi dosyaya yazilip
## dunya kurulumunda toplu cizilecek).
var _editor_dekor_nodes: Dictionary = {}   # hucre -> Node3D

func _editor_dekor_ciz(cell: Vector2i, kayit: Dictionary) -> void:
	_editor_dekor_sil(cell)
	var id := String(kayit.get("id", ""))
	var mesh := _env_mesh(id)
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var aabb := mesh.get_aabb()
	var span: float = maxf(0.001, maxf(aabb.size.x, aabb.size.z))
	var k: float = EnvModels.scale_of(id) / span * float(kayit.get("olcek", 1.0))
	mi.scale = Vector3.ONE * k
	mi.rotation_degrees.y = float(kayit.get("rot", 0))
	mi.position = _cell_center(cell) + Vector3(0.0, -aabb.position.y * k, 0.0)
	add_child(mi)
	_editor_dekor_nodes[cell] = mi

func _editor_dekor_sil(cell: Vector2i) -> void:
	var n: Node = _editor_dekor_nodes.get(cell, null)
	if n != null and is_instance_valid(n):
		n.queue_free()
	_editor_dekor_nodes.erase(cell)

# --- Secim halkasi ------------------------------------------------------
func _editor_halka_goster(cell: Vector2i) -> void:
	_editor_temizle_halka()
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.50
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.98, 0.82, 0.30)
	m.emission_enabled = true
	m.emission = Color(0.98, 0.82, 0.30)
	m.emission_energy_multiplier = 1.4
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.position = _cell_center(cell) + Vector3(0, 0.06, 0)
	add_child(mi)
	_editor_ring = mi

func _editor_temizle_halka() -> void:
	if _editor_ring != null and is_instance_valid(_editor_ring):
		_editor_ring.queue_free()
	_editor_ring = null

# --- Yol fircasi --------------------------------------------------------
var _editor_firca_silgi: bool = false
var _editor_firca_dokunulan: Dictionary = {}

func editor_set_firca_silgi(on: bool) -> void:
	_editor_firca_silgi = on
	hud.set_editor_status("Fırça: %s" % ("silgi" if on else "döşe"))

## Firca hucresi. Surukleme sirasinda ayni hucre defalarca gelir; tekrar
## isleme alinmaz (yoksa geri-al yigini tek surukleyisle dolardi).
func _editor_yol(cell: Vector2i, surukleme: bool) -> void:
	if surukleme and _editor_firca_dokunulan.has(cell):
		return
	_editor_firca_dokunulan[cell] = true
	if _editor_firca_silgi:
		if not is_road(cell):
			return
		_editor_undo_ekle({"is": "sil", "hucre": cell,
				"kayit": {"tur": "yol", "id": "yol_hucresi", "rot": 0, "olcek": 1.0}})
		_path_cells.erase(cell)
		_editor_ogeler.erase(cell)
	else:
		if is_road(cell):
			return
		lay_road(cell, "miras")
		_editor_ogeler[cell] = {"tur": "yol", "id": "yol_hucresi",
				"rot": 0, "olcek": 1.0}
		_editor_undo_ekle({"is": "ekle", "hucre": cell})
	# Uc kurallari (kuculme rampasi) _build_road icinde OTOMATIK: firca
	# yalniz hucre ekler/cikarir, "uc" hesabini yol sistemi kendi yapar.
	_build_road()

# --- Geri al ------------------------------------------------------------
func _editor_undo_ekle(kayit: Dictionary) -> void:
	_editor_undo.append(kayit)
	while _editor_undo.size() > LayoutEditor.UNDO_MAX:
		_editor_undo.pop_front()

func editor_undo() -> void:
	if _editor_undo.is_empty():
		hud.set_editor_status("Geri alınacak işlem yok")
		return
	var son: Dictionary = _editor_undo.pop_back()
	var cell: Vector2i = son["hucre"]
	match String(son["is"]):
		"ekle":
			_editor_kaldir(cell, true)
		"sil":
			_editor_geri_koy(cell, son["kayit"])
		"tasi":
			var eski: Vector2i = son["eski"]
			_editor_kaldir(cell, true)
			_editor_geri_koy(eski, son["kayit"])
	_editor_sel = Vector2i(-999, -999)
	_editor_temizle_halka()
	hud.set_editor_status("Geri alındı (%d kaldı)" % _editor_undo.size())

func _editor_geri_koy(cell: Vector2i, kayit: Dictionary) -> void:
	if kayit.is_empty():
		return
	_editor_ogeler[cell] = kayit
	match String(kayit.get("tur", "")):
		"yapi":
			_set_placed(cell, String(kayit["id"]), int(kayit.get("rot", 0)))
		"yol":
			lay_road(cell, "miras")
			_build_road()
		"dekor":
			_editor_dekor_ciz(cell, kayit)
		"tarla":
			_try_till(cell)

# --- Disa aktar / yukle -------------------------------------------------
## Sahnedeki TUM editor ogelerini user://camp_layout.json'a yazar.
## Hucreler KAMP MERKEZINE GORE ofset: kamp merkezi tohuma bagli oldugu
## icin mutlak hucre yazmak duzeni tek tohuma hapsederdi.
func editor_disa_aktar() -> void:
	var duzen := LayoutEditor.bos_duzen()
	var merkez := _camp_center if _camp_center != Vector2i(-999, -999) \
			else _player_cell()
	duzen["merkez_not"] = ("Hucreler kamp merkezine GORE ofsettir; "
			+ "disa aktarim aninda merkez (%d,%d) idi.") % [merkez.x, merkez.y]
	var liste: Array = []
	for cell: Vector2i in _editor_ogeler:
		var k: Dictionary = _editor_ogeler[cell]
		liste.append(LayoutEditor.oge(String(k.get("tur", "")),
				String(k.get("id", "")), cell - merkez,
				int(k.get("rot", 0)), float(k.get("olcek", 1.0))))
	duzen["ogeler"] = liste
	if LayoutEditor.yaz(LayoutEditor.USER_PATH, duzen):
		hud.set_editor_status("Dışa aktarıldı: %d öğe -> %s" % [
				liste.size(), LayoutEditor.USER_PATH])
		print("EDITOR: disa aktarildi ogeler=%d dosya=%s" % [
				liste.size(), ProjectSettings.globalize_path(
						LayoutEditor.USER_PATH)])
	else:
		hud.set_editor_status("Dışa aktarma BAŞARISIZ (dosya açılamadı)")

## Var olan duzeni acip uzerinde duzenleme (once user://, yoksa res://).
func editor_yukle() -> void:
	var duzen := LayoutEditor.oku(LayoutEditor.USER_PATH)
	if duzen.is_empty():
		duzen = LayoutEditor.oku(LayoutEditor.RES_PATH)
	if duzen.is_empty():
		hud.set_editor_status("Yüklenecek düzen yok")
		return
	# Sahnedeki editor ogelerini temizle, dosyadakini kur
	for cell: Vector2i in _editor_ogeler.keys():
		_editor_kaldir(cell, true)
	_editor_ogeler.clear()
	_editor_undo.clear()
	var merkez := _camp_center if _camp_center != Vector2i(-999, -999) \
			else _player_cell()
	var n := _duzen_uygula(duzen, merkez, true)
	hud.set_editor_status("Yüklendi: %d öğe" % n)

## Bir duzeni dunyaya kurar. editor_katmani=true ise ogeler editor
## listesine de yazilir (uzerinde duzenleme yapilabilsin).
## Doner: kurulan oge sayisi.
func _duzen_uygula(duzen: Dictionary, merkez: Vector2i,
		editor_katmani: bool) -> int:
	var n := 0
	for o: Dictionary in duzen.get("ogeler", []):
		var cell: Vector2i = merkez + LayoutEditor.ofset_of(o)
		if cell.x < 1 or cell.y < 1 or cell.x >= _map_w - 1 or cell.y >= _map_h - 1:
			continue
		var tur := String(o.get("tur", ""))
		var id := String(o.get("id", ""))
		var rot := int(o.get("rot", 0))
		var olcek := float(o.get("olcek", 1.0))
		match tur:
			"yapi":
				if not PLACE_MODELS.has(id) or _placed.has(cell):
					continue
				_set_placed(cell, id, rot)
			"yol":
				lay_road(cell, "miras")
			"dekor":
				var kayit := {"tur": "dekor", "id": id, "rot": rot,
						"olcek": olcek}
				_editor_dekor_ciz(cell, kayit)
			"tarla":
				if _till_valid(cell):
					Farming.till_cell(cell)
			_:
				continue
		if editor_katmani:
			_editor_ogeler[cell] = {"tur": tur, "id": id, "rot": rot,
					"olcek": olcek}
		n += 1
	_build_road()
	return n

## DUNYA URETIMI KANCASI: res://data/camp_layout.json VARSA baslangic
## kampi ONDAN kurulur. Dosya yoksa hicbir sey olmaz ve kodlanmis kamp
## (_build_spawn_camp) tek basina kalir — yani fallback SILINMEDI,
## dosya opsiyonel bir KATMAN.
##
## Sira onemli: kodlanmis kamp once kurulur, duzen dosyasi USTUNE biner.
## Boylece dosyada olmayan seyler (kulube, kuyu, tarla dekoru) yerinde
## kalir; dosyada olanlar da eklenir.
var _duzen_oge_sayisi := 0   # EDITORTEST okur

func _kamp_duzenini_uygula() -> void:
	_duzen_oge_sayisi = 0
	var duzen := LayoutEditor.oyun_duzeni()
	if duzen.is_empty():
		return
	if _camp_center == Vector2i(-999, -999):
		return
	_duzen_oge_sayisi = _duzen_uygula(duzen, _camp_center, false)
	print("KAMPDUZEN: %s okundu, %d oge kuruldu (merkez %d,%d)" % [
			LayoutEditor.RES_PATH, _duzen_oge_sayisi,
			_camp_center.x, _camp_center.y])

# --- EDITORTEST ---------------------------------------------------------
## Gorevdeki dogrulama zinciri, kod tarafinda: editorde kamp kur ->
## disa aktar -> dosyayi oku -> TEMIZ dunyaya uygula -> AYNI MI.
## Ekran goruntusu degil SAYI ile karsilastiriliyor; "birebir kuruldu mu"
## sorusunun cevabi goz karari olmamali.
##
## Neden yeni oyun acmiyor: yeni oyun acmak sahneyi bastan kuruyor ve
## test icinde beklemeye zorluyor. Bunun yerine ayni sahnede ogeler
## kaldirilip duzen dosyasindan yeniden kuruluyor — okunan sey ayni:
## "disa aktarilan dosya, dunyayi ayni hale getiriyor mu".
func _run_editor_test() -> void:
	var merkez := _camp_center if _camp_center != Vector2i(-999, -999) \
			else _player_cell()
	# 1) Editorde birkac oge kur (dogrudan editor katmanina, UI'siz)
	_editor_ogeler.clear()
	_editor_undo.clear()
	var kuruldu := 0
	var plan := [
		{"tur": "yapi", "id": "sandik", "ofs": Vector2i(3, 3)},
		{"tur": "yapi", "id": "yatak", "ofs": Vector2i(4, 3)},
		{"tur": "yol", "id": "yol_hucresi", "ofs": Vector2i(3, 4)},
		{"tur": "yol", "id": "yol_hucresi", "ofs": Vector2i(3, 5)},
		{"tur": "dekor", "id": "grass_tuft", "ofs": Vector2i(5, 3)},
	]
	for p: Dictionary in plan:
		var c: Vector2i = merkez + Vector2i(p["ofs"])
		# Hucreyi temizle ki test arazinin rastgele dolulugundan
		# etkilenmesin (dogrulanan sey EDITOR, harita degil).
		_objects.erase(c)
		_placed.erase(c)
		_solid_cells.erase(c)
		_editor_kat = String(p["tur"])
		_editor_item = String(p["id"])
		_editor_rot = 90
		_editor_koy(c)
		if _editor_ogeler.has(c):
			kuruldu += 1
	# 2) Geri al: son islem geri gelmeli
	var once := _editor_ogeler.size()
	editor_undo()
	var undo_ok: bool = _editor_ogeler.size() == once - 1
	# 3) Disa aktar
	editor_disa_aktar()
	var yazildi := LayoutEditor.oku(LayoutEditor.USER_PATH)
	var yazildi_n: int = yazildi.get("ogeler", []).size()
	# 4) Sahneden hepsini kaldir, dosyadan yeniden kur
	var beklenen: Array = []
	for cell: Vector2i in _editor_ogeler:
		var k: Dictionary = _editor_ogeler[cell]
		beklenen.append("%s:%s@%d,%d" % [String(k["tur"]), String(k["id"]),
				cell.x - merkez.x, cell.y - merkez.y])
	beklenen.sort()
	for cell: Vector2i in _editor_ogeler.keys():
		_editor_kaldir(cell, true)
	_editor_ogeler.clear()
	var n := _duzen_uygula(yazildi, merkez, true)
	var kuruldu_liste: Array = []
	for cell: Vector2i in _editor_ogeler:
		var k2: Dictionary = _editor_ogeler[cell]
		kuruldu_liste.append("%s:%s@%d,%d" % [String(k2["tur"]),
				String(k2["id"]), cell.x - merkez.x, cell.y - merkez.y])
	kuruldu_liste.sort()
	var birebir: bool = beklenen == kuruldu_liste
	# 5) Temizlik: test dunyayi kalici bozmasin
	for cell: Vector2i in _editor_ogeler.keys():
		_editor_kaldir(cell, true)
	_editor_ogeler.clear()
	_editor_undo.clear()

	var line := ("EDITORTEST: kuruldu=%d/%d undo_ok=%s disa_aktarilan=%d "
			+ "geri_kurulan=%d birebir=%s kayit_kapali=%s") % [
		kuruldu, plan.size(), str(undo_ok), yazildi_n, n, str(birebir),
		str(not _editor_on)]
	print(line)
	if kuruldu != plan.size():
		push_error("EDITOR: ogelerin hepsi kurulamadi")
	if not undo_ok:
		push_error("EDITOR: geri al calismadi")
	if yazildi_n == 0:
		push_error("EDITOR: disa aktarim bos")
	if not birebir:
		push_error("EDITOR: dosyadan kurulan duzen orijinaliyle AYNI DEGIL")

# =========================================================================
# KESIF (Bolum 16) — halka + sis + isik kapisi altyapisi (Asama 1)
# =========================================================================
# Kapsam: hucrenin halkasi, oyuncunun tasidigi isik, ikisinin farki
# (isik acigi) ve bunun uc etkisi: vinyet/soguma (HUD), hedefleme
# daralmasi (_candidate_cells) ve kamp izni (Asama 3 okur). Sis gorseli
# mobil dostu: ekran vinyeti + oyuncuyu izleyen tek alcak sis duzlemi.
# TUM sayilar kesif_balance.gd'de.

var _kesif_timer: float = 0.0
var _sis_yogun: float = 0.0        # oyuncunun bulundugu hucrede sis (0..1)
var _isik_acik: int = 0            # eksik isik kademesi (0 = kapi acik)
var _fener_kisik: bool = false     # 16.5 stealth: parlak/kisik
var _sis_duzlem: MeshInstance3D = null
var _sis_duzlem_mat: StandardMaterial3D = null
var _son_vinyet: float = -1.0      # HUD'a yalniz degisince yaz
var _fener_ui_son: bool = false    # fener butonu gorunurluk onbellegi
## Kor tasi temizligi (Asama 2 dolduracak): [{cell: Vector2i, r: float}]
var _temiz_bolgeler: Array = []
var _fog_img: Image = null      # data/fog_mask.png (varsa; harita-master)

## Hucrenin halkasi (0=Yuva .. 3=Derin Sis). Merkez: Ocak, yoksa dogus.
func get_ring(cell: Vector2i) -> int:
	var merkez := get_hearth()
	if merkez == Vector2i(-999, -999):
		merkez = _spawn_cell
	return KesifBalance.ring_of(cell, merkez)

## Hucredeki etkin sis: once kalici temizlik (16.2), sonra SIS MASKESI
## (data/fog_mask.png — harita-master tasarim katmani), o da yoksa
## halka fallback'i. Maske ile halkalar ayni merkeze hizali uretiliyor;
## elle boyanirsa maske kazanir (tasarim niyeti bu).
func _sis_at_cell(cell: Vector2i) -> float:
	for b in _temiz_bolgeler:
		if Vector2(cell - Vector2i(b["cell"])).length() <= float(b["r"]):
			return 0.0
	if _fog_img != null:
		var v := MapMask.fog_at(_fog_img, cell)
		if v >= 0.0:
			return v
	return KesifBalance.sis_yogunluk(get_ring(cell))

## Yetersiz isikla siste miyiz? (hedefleme + kamp + uyuyan tespiti okur)
func _sis_kisitli() -> bool:
	return _isik_acik > 0

## Kamp kurulabilir mi (16.1: yetersiz isikta KURULAMAZ). Asama 3 okur.
func kesif_kamp_izni() -> bool:
	if not KesifBalance.KAMP_ISIK_SART:
		return true
	return not _sis_kisitli()

func set_fener_kisik(on: bool) -> void:
	_fener_kisik = on
	_son_vinyet = -1.0  # vinyet degisti, HUD'i zorla tazele

## 0.2 sn'de bir: oyuncunun halkasi/isigi -> HUD vinyeti + sis duzlemi.
func _update_kesif() -> void:
	var pc := _player_cell()
	_sis_yogun = _sis_at_cell(pc)
	var isik: int = KesifBalance.tasinan_isik(Inventory)
	if _sis_yogun <= 0.0:
		_isik_acik = 0
	else:
		_isik_acik = KesifBalance.isik_acigi(get_ring(pc), isik)
	var gorunur: bool = isik >= 2
	if gorunur != _fener_ui_son:
		_fener_ui_son = gorunur
		hud.set_fener_gorunur(gorunur)
	var v: float = KesifBalance.vinyet(_sis_yogun, _isik_acik,
			_fener_kisik and isik >= 2)
	# KESIF 16.6 Kul Firtinasi: gorus zorla kapanir; siginakta yari.
	if _firtina_kalan > 0.0:
		v = KesifBalance.FIRTINA_VINYET
		if _firtina_siginakta():
			v *= 0.5
	if absf(v - _son_vinyet) > 0.01:
		_son_vinyet = v
		hud.set_sis(v, KesifBalance.soguk(_sis_yogun))
	_update_sis_duzlem()

## Oyuncuyu izleyen tek yari-seffaf duzlem: "alcak sis" (16.2 gorseli).
func _update_sis_duzlem() -> void:
	if _sis_yogun <= 0.0:
		if _sis_duzlem != null:
			_sis_duzlem.visible = false
		return
	if _sis_duzlem == null:
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(KesifBalance.SIS_DUZLEM_BOYUT,
				KesifBalance.SIS_DUZLEM_BOYUT)
		_sis_duzlem_mat = StandardMaterial3D.new()
		_sis_duzlem_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_sis_duzlem_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_sis_duzlem_mat.albedo_color = KesifBalance.SIS_RENK
		_sis_duzlem_mat.no_depth_test = false
		_sis_duzlem = MeshInstance3D.new()
		_sis_duzlem.mesh = mesh
		_sis_duzlem.material_override = _sis_duzlem_mat
		_sis_duzlem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_sis_duzlem)
	_sis_duzlem.visible = true
	var c := KesifBalance.SIS_RENK
	c.a = KesifBalance.SIS_DUZLEM_ALFA * _sis_yogun
	_sis_duzlem_mat.albedo_color = c
	_sis_duzlem.position = Vector3(player.position.x,
			KesifBalance.SIS_DUZLEM_YUKSEK, player.position.z)

## KESIFTEST (hizli CI): halka matematigi, isik kademesi, kapi etkileri,
## tarif/dugum varligi. Sayilar degisirse test degil VERI guncellenir.
func _run_kesif_test() -> void:
	var merkez := Vector2i(64, 64)
	var h0: int = KesifBalance.ring_of(merkez, merkez)
	var h1: int = KesifBalance.ring_of(merkez + Vector2i(20, 0), merkez)
	var h2: int = KesifBalance.ring_of(merkez + Vector2i(40, 0), merkez)
	var h3: int = KesifBalance.ring_of(merkez + Vector2i(60, 0), merkez)
	if [h0, h1, h2, h3] != [0, 1, 2, 3]:
		push_error("KESIF: halka matematigi bozuk: %s" % str([h0, h1, h2, h3]))
	# Isik kademesi: envantere gecici esya ekle/cikar (deterministik fark).
	var eski := {}
	for tier in KesifBalance.ISIK_ESYA:
		var id: String = String(KesifBalance.ISIK_ESYA[tier])
		eski[id] = Inventory.get_count(id)
		if eski[id] > 0:
			Inventory.remove_item(id, eski[id])
	var t0: int = KesifBalance.tasinan_isik(Inventory)
	Inventory.add_item("mesale", 1)
	var t1: int = KesifBalance.tasinan_isik(Inventory)
	Inventory.add_item("kor_feneri", 1)
	var t2: int = KesifBalance.tasinan_isik(Inventory)
	Inventory.add_item("koz_kabi", 1)
	var t3: int = KesifBalance.tasinan_isik(Inventory)
	Inventory.remove_item("mesale", 1)
	Inventory.remove_item("kor_feneri", 1)
	Inventory.remove_item("koz_kabi", 1)
	for id in eski:
		if eski[id] > 0:
			Inventory.add_item(id, eski[id])
	if [t0, t1, t2, t3] != [0, 1, 2, 3]:
		push_error("KESIF: isik kademesi bozuk: %s" % str([t0, t1, t2, t3]))
	# Kapi etkileri: aciksiz vinyet hafif, acikli agir, sissiz sifir.
	var v_yok: float = KesifBalance.vinyet(0.0, 2, false)
	var v_hafif: float = KesifBalance.vinyet(0.6, 0, false)
	var v_agir: float = KesifBalance.vinyet(0.6, 2, false)
	if v_yok != 0.0 or v_agir <= v_hafif:
		push_error("KESIF: vinyet egrisi bozuk (%.2f/%.2f/%.2f)"
				% [v_yok, v_hafif, v_agir])
	# Tarifler + dugumler yerinde mi (canli katalog).
	var tarif_ok: bool = Recipes.CRAFT_RECIPES.has("cam") \
			and Recipes.CRAFT_RECIPES.has("kor_feneri") \
			and Recipes.CRAFT_RECIPES.has("koz_kabi")
	var dugum_ok: bool = Research.NODES.has("fener_dugumu") \
			and Research.NODES.has("koz_kabi_dugumu")
	if not tarif_ok:
		push_error("KESIF: isik tarifleri katalogda eksik")
	if not dugum_ok:
		push_error("KESIF: arastirma dugumleri eksik")
	# Temiz bolge sis'i sifirlar (Asama 2'nin okuyacagi mekanizma).
	_temiz_bolgeler = [{"cell": Vector2i(5, 5), "r": 4.0}]
	var sis_temiz: float = _sis_at_cell(Vector2i(6, 5))
	_temiz_bolgeler = []
	if sis_temiz != 0.0:
		push_error("KESIF: temiz bolge sisi sifirlamiyor")
	print("KESIFTEST: halka=%s isik=%s vinyet=%.2f/%.2f/%.2f tarif=%s dugum=%s temiz_ok=%s" % [
			str([h0, h1, h2, h3]), str([t0, t1, t2, t3]),
			v_yok, v_hafif, v_agir, str(tarif_ok), str(dugum_ok),
			str(sis_temiz == 0.0)])

# =========================================================================
# KESIF Asama 2 (16.3) — KOR TASLARI
# =========================================================================
# 6 ana tas Ocak'tan disari yay cizer (KesifBalance.TAS_ANA), 3 yan tas
# sapmis noktalarda. Yerlesim deterministik: aci+yaricap veriden, hucre
# en yakin yurunebilir karaya oturtulur (spiral arama). Yakma bedeli
# 1 yol_koru + artan oz; Halka 2+ taslari koz_kabi sart (tasiyici).
# Yakilan tas: KALICI sis temizligi + arastirmaya "tas bilgisi" +
# gece sertlesme carpani + Ocak alev rengi ilerlemesi (HIKAYE 7 kancasi).

var _kor_taslari: Dictionary = {}   # id -> {cell, yanik, halka}
var _kor_tas_gorseller: Dictionary = {}  # id -> MeshInstance3D

## Dunya kurulunca cagrilir (kamp sonrasi): taslari yerlestir.
func _place_kor_taslari() -> void:
	for g in _kor_tas_gorseller.values():
		if is_instance_valid(g):
			g.queue_free()
	_kor_taslari.clear()
	_kor_tas_gorseller.clear()
	var merkez := get_hearth()
	if merkez == Vector2i(-999, -999):
		merkez = _spawn_cell
	for i in KesifBalance.TAS_ANA.size():
		var t: Dictionary = KesifBalance.TAS_ANA[i]
		_kor_tas_kur("ana%d" % (i + 1), merkez,
				float(t["aci"]), float(t["r"]))
	for id: String in KesifBalance.TAS_YAN:
		var t: Dictionary = KesifBalance.TAS_YAN[id]
		_kor_tas_kur(id, merkez, float(t["aci"]), float(t["r"]))

func _kor_tas_kur(id: String, merkez: Vector2i, aci: float, r: float) -> void:
	var rad := deg_to_rad(aci)
	var hedef := merkez + Vector2i(roundi(cos(rad) * r), roundi(sin(rad) * r))
	var cell := _kor_tas_yer_bul(hedef)
	if cell == Vector2i(-999, -999):
		print("KORTAS: %s icin yer yok (hedef %s)" % [id, str(hedef)])
		return
	_kor_taslari[id] = {"cell": cell, "yanik": false,
			"halka": get_ring(cell)}
	_solid_cells[cell] = true
	_kor_tas_gorseller[id] = _kor_tas_gorsel_kur(id, cell)

## Hedefin cevresinde yurunebilir, bos, kuru hucre ara (buyuyen halka).
func _kor_tas_yer_bul(hedef: Vector2i) -> Vector2i:
	for ring in 9:
		for oy in range(-ring, ring + 1):
			for ox in range(-ring, ring + 1):
				if maxi(absi(ox), absi(oy)) != ring:
					continue
				var c := hedef + Vector2i(ox, oy)
				if c.x < 1 or c.y < 1 or c.x >= _map_w - 1 or c.y >= _map_h - 1:
					continue
				if not is_walkable(c) or _placed.has(c) or _objects.has(c):
					continue
				return c
	return Vector2i(-999, -999)

## Placeholder gorsel: koyu tas silindiri + yanikken kor rengi isima.
## Model gelirse (kor_tasi.glb) ayni kancadan takilir — kod degismez.
func _kor_tas_gorsel_kur(id: String, cell: Vector2i) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.30
	mesh.bottom_radius = 0.44
	mesh.height = 1.25
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 0.23, 0.30)
	mat.roughness = 0.9
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = _cell_center(cell) + Vector3(0, 0.62, 0)
	add_child(mi)
	if bool(_kor_taslari[id]["yanik"]):
		_kor_tas_isima(mi, true)
	return mi

func _kor_tas_isima(mi: MeshInstance3D, yanik: bool) -> void:
	var mat := mi.material_override as StandardMaterial3D
	if mat == null:
		return
	if yanik:
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.45, 0.16)
		mat.emission_energy_multiplier = 1.4
		mat.albedo_color = Color(0.34, 0.28, 0.30)
	else:
		mat.emission_enabled = false

## Bu hucrede (yakilmamis) kor tasi var mi? -> id ya da ""
func _kor_tas_at(cell: Vector2i) -> String:
	for id: String in _kor_taslari:
		if Vector2i(_kor_taslari[id]["cell"]) == cell:
			return id
	return ""

func _yanik_ana_sayisi() -> int:
	var n := 0
	for id: String in _kor_taslari:
		if id.begins_with("ana") and bool(_kor_taslari[id]["yanik"]):
			n += 1
	return n

## Yanik taslardan kalici temiz bolgeleri yeniden kur (yukleme + yakma).
func _rebuild_temiz_bolgeler() -> void:
	_temiz_bolgeler.clear()
	for id: String in _kor_taslari:
		if bool(_kor_taslari[id]["yanik"]):
			_temiz_bolgeler.append({
				"cell": Vector2i(_kor_taslari[id]["cell"]),
				"r": KesifBalance.TEMIZ_R})

## Yakma denemesi: bedel + tasiyici kurali. Basarida KALICI etkiler.
func _try_burn_kor_tas(id: String) -> bool:
	if not _kor_taslari.has(id) or bool(_kor_taslari[id]["yanik"]):
		return false
	if Inventory.get_count("yol_koru") < 1:
		_spawn_floating_text(Vector2i(_kor_taslari[id]["cell"]),
				"Yol koru gerek (Ocak'tan al)", Color(1, 0.6, 0.4))
		return false
	if int(_kor_taslari[id]["halka"]) >= KesifBalance.KOZ_SART_HALKA \
			and Inventory.get_count("koz_kabi") < 1:
		_spawn_floating_text(Vector2i(_kor_taslari[id]["cell"]),
				"Bu uzaklige koz kabi gerek", Color(1, 0.6, 0.4))
		return false
	var bedel: Dictionary = KesifBalance.tas_bedel(id)
	for item_id: String in bedel:
		if Inventory.get_count(item_id) < int(bedel[item_id]):
			_spawn_floating_text(Vector2i(_kor_taslari[id]["cell"]),
					"Eksik: %s x%d" % [Items.display_name(item_id),
					int(bedel[item_id])], Color(1, 0.6, 0.4))
			return false
	Inventory.remove_item("yol_koru", 1)
	for item_id: String in bedel:
		Inventory.remove_item(item_id, int(bedel[item_id]))
	_kor_taslari[id]["yanik"] = true
	_rebuild_temiz_bolgeler()
	var cell := Vector2i(_kor_taslari[id]["cell"])
	if _kor_tas_gorseller.has(id) and is_instance_valid(_kor_tas_gorseller[id]):
		_kor_tas_isima(_kor_tas_gorseller[id], true)
	# Canlanma: sicak parcacik patlamasi + yazi. Sis o bolgede kalici gitti.
	_spawn_particles(_cell_center(cell) + Vector3(0, 1.0, 0),
			Color(1.0, 0.55, 0.2), 14)
	_spawn_floating_text(cell, "Kor tasi yandi — bolge canlandi", Color(1, 0.8, 0.4))
	# Arastirma: tas bilgisi dugumleri kademeli belirir (1./3./5. ana tas).
	var yanik := _yanik_ana_sayisi()
	if yanik >= 1:
		Research.reveal_node("tas_bilgisi_1")
	if yanik >= 3:
		Research.reveal_node("tas_bilgisi_2")
	if yanik >= 5:
		Research.reveal_node("tas_bilgisi_3")
	# 16.7 YAN TAS ODULLERI (opsiyonel yol: %100'cu oyuncu odullenir)
	if id == "yanA":
		var acilan := 0
		for dugum: String in KesifBalance.YANA_BEDAVA_DUGUMLER:
			if not Research.unlocked.has(dugum):
				Research.revealed[dugum] = true
				Research.unlocked[dugum] = true
				acilan += 1
		if acilan > 0:
			Research._save()
			Research.changed.emit()
			_spawn_floating_text(cell, "Eski usta tarifleri cozuldu",
					Color(0.7, 0.95, 1.0))
		else:
			Inventory.add_item("oz", KesifBalance.YANA_YEDEK_OZ)
			_spawn_floating_text(cell, "Ustanin zulasi: oz", Color(0.7, 0.95, 1.0))
	elif id == "yanB":
		# Gunluk sayfalari hikaye borcu (HIKAYE.md gelince): simdilik depo.
		Inventory.add_item("oz", KesifBalance.YANB_OZ)
		_spawn_floating_text(cell, "Buyuk oz deposu!", Color(0.7, 0.95, 1.0))
	elif id == "yanC":
		_spawn_floating_text(cell, "Muhur Cagi bonusu: sabah ekonomisi +%10",
				Color(0.7, 0.95, 1.0))
	_update_alev_rengi()
	_son_vinyet = -1.0  # sis durumu degisti; HUD tazelensin
	_dirty = true
	return true

## HIKAYE 7 alev rengi ilerlemesi: yakilan ana tas sayisi Ocak aleyvinin
## rengini sicak sariden derin kor kizilina tasir (gorunur ilerleme).
func _update_alev_rengi() -> void:
	if _hearth_light == null or not is_instance_valid(_hearth_light):
		return
	var t := float(_yanik_ana_sayisi()) / float(KesifBalance.TAS_ANA.size())
	_hearth_light.light_color = Color(1.0, 0.66, 0.32).lerp(
			Color(1.0, 0.42, 0.18), t)

## Ana Ocak on kosulu (16.3): 6 ana tasin hepsi yanik mi? (final fazi okur)
func ana_ocak_hazir() -> bool:
	return _yanik_ana_sayisi() >= KesifBalance.TAS_ANA.size()

## Ocak'tan yol koru alma: koz kabi ya da (basit koz) mesale sart.
func _take_yol_koru() -> void:
	if Inventory.get_count("koz_kabi") < 1 and Inventory.get_count("mesale") < 1:
		_spawn_floating_text(get_hearth(), "Koru tasiyacak kap yok", Color(1, 0.6, 0.4))
		return
	Inventory.add_item("yol_koru", 1)
	_spawn_floating_text(get_hearth(), "Yol koru alindi", Color(1, 0.8, 0.4))
	_dirty = true

## KORTEST (hizli CI): yerlesim sayisi + yakma zinciri + temizlik + carpan.
func _run_kor_test() -> void:
	var ana := 0
	var yan := 0
	for id: String in _kor_taslari:
		if id.begins_with("ana"):
			ana += 1
		else:
			yan += 1
	if ana < KesifBalance.TAS_ANA.size():
		push_error("KOR: ana tas eksik yerlesti (%d/%d)"
				% [ana, KesifBalance.TAS_ANA.size()])
	# Yakma zinciri (ana1, Halka 1: koz kabi sart degil ama mesale koru tasir)
	var id1 := "ana1"
	var ok := false
	var sis_sonra := -1.0
	var carpan0: float = KesifBalance.gece_sertlesme(_yanik_ana_sayisi())
	if _kor_taslari.has(id1):
		var eski_yanik: bool = bool(_kor_taslari[id1]["yanik"])
		Inventory.add_item("yol_koru", 1)
		var bedel: Dictionary = KesifBalance.tas_bedel(id1)
		for item_id: String in bedel:
			Inventory.add_item(item_id, int(bedel[item_id]))
		ok = _try_burn_kor_tas(id1)
		sis_sonra = _sis_at_cell(Vector2i(_kor_taslari[id1]["cell"]))
		# Temizlik: testi izinsiz kalici yapma — durumu geri sar.
		_kor_taslari[id1]["yanik"] = eski_yanik
		_rebuild_temiz_bolgeler()
		if _kor_tas_gorseller.has(id1) and is_instance_valid(_kor_tas_gorseller[id1]):
			_kor_tas_isima(_kor_tas_gorseller[id1], eski_yanik)
	var carpan1: float = KesifBalance.gece_sertlesme(1)
	if not ok:
		push_error("KOR: yakma zinciri basarisiz")
	if ok and sis_sonra != 0.0:
		push_error("KOR: yakilan tasin bolgesi temizlenmedi (sis=%.2f)" % sis_sonra)
	if carpan1 <= carpan0 and carpan0 == 1.0:
		push_error("KOR: gece sertlesme carpani artmiyor")
	print("KORTEST: ana=%d yan=%d yakma=%s temiz=%s carpan=%.2f->%.2f" % [
			ana, yan, str(ok), str(sis_sonra == 0.0), carpan0, carpan1])

# =========================================================================
# KESIF Asama 3 (16.4) — SEFER, KAMP, OCAK SIMULASYONU
# =========================================================================
# Sefer = gece basinda Ocak'tan SEFER_UZAK_R'den uzak olmak. O gece:
# - Base dalgasi SIMULE edilir: savunma puani vs dalga gucu (formul
#   kesif_balance.gd basliginda). Hasar once savunma yapilarini yer,
#   artani Ocak'a gecer. Sonuc sabah raporu olarak HUD'a.
# - Oyuncunun yaninda atesli kamp (placed yol_koru) varsa kucuk cekim
#   karsilasmasi dogar (2-4 yaratik — dalga degil).
# - Ates yoksa: gorunmezsin ama ussursun — safakta hafif hp/aclik cezasi.

var _sefer_gecesi: bool = false
var _sabah_raporu: String = ""
var _ocak_nefes: String = "harla"  # HIKAYE 9 kancasi: "kozle" = saklan modu

## Nefes secimi (UI hikaye fazinda; API + kayit hazir).
func set_ocak_nefes(mode: String) -> void:
	if KesifBalance.NEFES_CARPAN.has(mode):
		_ocak_nefes = mode
		_dirty = true

## Savunma puani: Ocak cevresi SAVUNMA_R icindeki yapilar + su hendegi.
func _savunma_puani() -> float:
	var hc := get_hearth()
	if hc == Vector2i(-999, -999):
		return 0.0
	var puan := 0.0
	for cell: Vector2i in _placed:
		if Vector2(cell - hc).length() > KesifBalance.SAVUNMA_R:
			continue
		var id: String = _placed[cell]
		if not KesifBalance.SAVUNMA_AGIRLIK.has(id):
			continue
		var max_hp: int = int(PLACE_MODELS.get(id, {}).get("max_hp", 100))
		var hp: float = _structures.hp_ratio(cell) * float(max_hp)
		puan += hp * float(KesifBalance.SAVUNMA_AGIRLIK[id])
	var r := int(ceil(KesifBalance.SAVUNMA_R))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := hc + Vector2i(dx, dy)
			if Vector2(c - hc).length() > KesifBalance.SAVUNMA_R:
				continue
			# Su hendegi: kazilmis + su dolu hucre
			if int(_depth.get(c, 0)) > 0 and float(_water_level.get(c, 0.0)) > 0.2:
				puan += KesifBalance.SU_PUAN
	return puan

## Gece dalgasini SIMULE et (oyuncu uzakta). Hasari gercekten uygular;
## sonucu rapor metniyle dondurur. {rapor: String, hasar: float}
func _sefer_dalga_simule(night: int) -> Dictionary:
	var savunma := _savunma_puani()
	var dalga: float = KesifBalance.dalga_gucu(night, _yanik_ana_sayisi(),
			_ocak_nefes)
	var hasar: float = maxf(0.0,
			dalga - savunma * KesifBalance.SAVUNMA_ETKI)
	var rapor := ""
	if hasar <= 0.0:
		rapor = "Ocak dayandi — savunma gece boyunca tuttu."
	else:
		# Hasar puanini Ocak'a yakin savunma yapilarindan duserek harca;
		# yapi kalmazsa artani Ocak yer.
		var kalan: float = hasar * KesifBalance.HASAR_YAPI_CARPAN
		var hc := get_hearth()
		var hedefler: Array = []
		for cell: Vector2i in _placed:
			if cell != hc and KesifBalance.SAVUNMA_AGIRLIK.has(String(_placed[cell])) \
					and Vector2(cell - hc).length() <= KesifBalance.SAVUNMA_R:
				hedefler.append(cell)
		hedefler.sort_custom(func(a, b):
			return Vector2(a - hc).length() > Vector2(b - hc).length())
		var kirilan := 0
		var hasarli := 0
		for cell: Vector2i in hedefler:
			if kalan <= 0.0:
				break
			var id: String = _placed[cell]
			var max_hp: int = int(PLACE_MODELS.get(id, {}).get("max_hp", 100))
			var hp: float = _structures.hp_ratio(cell) * float(max_hp)
			var vur: float = minf(kalan, hp)
			kalan -= vur
			_structure_take_hit(cell, int(ceil(vur)), Vector3.FORWARD)
			if vur >= hp:
				kirilan += 1
			else:
				hasarli += 1
		if kalan > 0.0 and _placed.has(hc):
			_structure_take_hit(hc, int(ceil(kalan)), Vector3.FORWARD)
			rapor = "Ocak hasarli! Eve don."
		elif kirilan > 0:
			rapor = "Ocak dayandi — %d yapi yikildi, %d hasar aldi." % [kirilan, hasarli]
		else:
			rapor = "Ocak dayandi — savunma hasar aldi (%d yapi)." % hasarli
	print("SEFERSIM: gece=%d savunma=%.1f dalga=%.1f hasar=%.1f nefes=%s" % [
			night, savunma, dalga, hasar, _ocak_nefes])
	return {"rapor": rapor, "hasar": hasar}

## Oyuncunun yakininda yanik kamp atesi var mi (placed yol_koru)?
func _kamp_atesi_yakinimda() -> bool:
	var pc := _player_cell()
	for cell: Vector2i in _placed:
		if String(_placed[cell]) == "yol_koru" \
				and Vector2(cell - pc).length() <= KesifBalance.KAMP_YAKIN_R:
			return true
	return false

## Kamp gecesi cekimi (16.4): ates yaniyorsa 2-4 yaratik oyuncunun
## cevresinde dogar (dalga DEGIL — kamp isiginin bedeli).
func _kamp_gecesi_karsilasma(night: int) -> void:
	if not _kamp_atesi_yakinimda():
		return  # atessiz gece: gorunmezsin (bedeli sabah)
	var zar := DigWaterVisual.hash01(_player_cell().x, _player_cell().y, night * 31)
	if zar > KesifBalance.KAMP_KARSILASMA_SANS:
		return
	var n: int = KesifBalance.KAMP_KARSILASMA_MIN + int(
			DigWaterVisual.hash01(night, 7, 13) * float(KesifBalance.KAMP_KARSILASMA_MAX
			- KesifBalance.KAMP_KARSILASMA_MIN + 1))
	n = clampi(n, KesifBalance.KAMP_KARSILASMA_MIN, KesifBalance.KAMP_KARSILASMA_MAX)
	var pc := _player_cell()
	var made := 0
	for i in 24:
		if made >= n:
			break
		var aci := TAU * DigWaterVisual.hash01(i, night, 77)
		var cell := pc + Vector2i(roundi(cos(aci) * 8.0), roundi(sin(aci) * 8.0))
		if cell.x < 1 or cell.y < 1 or cell.x >= _map_w - 1 or cell.y >= _map_h - 1:
			continue
		if not is_walkable(cell):
			continue
		spawn_creature(cell, "normal", CreatureBalance.night_hp_mult(night))
		made += 1
	if made > 0 and hud != null:
		hud.flash_pill("Ates dikkat cekti...")
	print("KAMPGECE: gece=%d dogan=%d ates=%s" % [night, made, "true"])

## Safak (sefer tarafi): atessiz gece cezasi + sabah raporu.
func _on_kesif_dawn() -> void:
	if not _sefer_gecesi:
		return
	_sefer_gecesi = false
	if not _kamp_atesi_yakinimda():
		Health.damage(KesifBalance.ATESSIZ_HP_CEZA)
		Hunger.value = maxf(0.0, Hunger.value - KesifBalance.ATESSIZ_ACLIK_CEZA)
		Hunger.changed.emit()
		if hud != null:
			hud.flash_pill("Soguk bir gece gecirdin")
	if _sabah_raporu != "" and hud != null:
		hud.show_sabah_raporu(_sabah_raporu)
	_sabah_raporu = ""

## SEFERTEST (hizli CI): formul yonleri + kamp izni kapisi + rapor uretimi.
func _run_sefer_test() -> void:
	var d_harla: float = KesifBalance.dalga_gucu(3, 0, "harla")
	var d_kozle: float = KesifBalance.dalga_gucu(3, 0, "kozle")
	var d_sert: float = KesifBalance.dalga_gucu(3, 4, "harla")
	if d_kozle >= d_harla:
		push_error("SEFER: kozle indirimi calismiyor")
	if d_sert <= d_harla:
		push_error("SEFER: tas sertlesmesi dalgaya yansimiyor")
	var savunma := _savunma_puani()
	var sonuc := _sefer_dalga_simule(1)
	if String(sonuc["rapor"]) == "":
		push_error("SEFER: sabah raporu bos")
	# Kamp izni kapisi: isik acigi varken kapali, yokken acik.
	var eski_acik := _isik_acik
	_isik_acik = 2
	var kapali: bool = not kesif_kamp_izni()
	_isik_acik = 0
	var acik: bool = kesif_kamp_izni()
	_isik_acik = eski_acik
	if not kapali or not acik:
		push_error("SEFER: kamp isik kapisi calismiyor")
	print("SEFERTEST: dalga=%.1f/%.1f/%.1f savunma=%.1f rapor='%s' kapi=%s" % [
			d_harla, d_kozle, d_sert, savunma,
			String(sonuc["rapor"]), str(kapali and acik)])

# =========================================================================
# KESIF Asama 4 (16.5) — UYUYANLAR (tas kesilmis Kulgezer kumeleri)
# =========================================================================
# Sis kusaklarinda (Halka 2+) gunduz tasllasmis kumeler. Aralarinda YAVAS
# yurumek guvenli; kosmak/alet sallamak (is_exerting), yakin gurultu
# (kazma/kesme/kazi) ya da PARLAK isik (K2+, kisik degil) kumeyi uyandirir:
# kabuk catlar (goz isimasi + uyari) -> UYANMA_GECIKME sonra saldiri.
# Oyuncu YENIDEN_UYKU_R disina cikinca uyananlar geri tasllasir (takinti
# yok). Kume ortasinda odul (16.5 risk-odul dengesi). Sayilar veri dosyasinda.

## kume: {merkez, uyeler: [Vector2i], durum: uyuyor|uyaniyor|uyanik|bos,
##        sayac: float, yaratiklar: [Node3D]}
var _uyuyan_kumeler: Array = []
var _uyuyan_gorseller: Dictionary = {}  # "kumeIdx:uyeIdx" -> MeshInstance3D
var _nabiz_son: float = -1.0

func _place_uyuyanlar() -> void:
	for g in _uyuyan_gorseller.values():
		if is_instance_valid(g):
			g.queue_free()
	_uyuyan_gorseller.clear()
	_uyuyan_kumeler.clear()
	var merkez := get_hearth()
	if merkez == Vector2i(-999, -999):
		merkez = _spawn_cell
	var kurulan := 0
	# Deterministik yerlesim: aci taramasi, Halka 2+ yurunebilir merkezler.
	for i in 40:
		if kurulan >= KesifBalance.UYUYAN_KUME_SAYI:
			break
		var aci := TAU * DigWaterVisual.hash01(i, 3, 555)
		var r := 34.0 + DigWaterVisual.hash01(i, 5, 556) * 24.0
		var aday := merkez + Vector2i(roundi(cos(aci) * r), roundi(sin(aci) * r))
		aday = _kor_tas_yer_bul(aday)  # ayni spiral: yurunebilir bos hucre
		if aday == Vector2i(-999, -999):
			continue
		if get_ring(aday) < KesifBalance.UYUYAN_HALKA_MIN:
			continue
		var cakisti := false
		for k in _uyuyan_kumeler:
			if Vector2(aday - Vector2i(k["merkez"])).length() < 10.0:
				cakisti = true
				break
		if cakisti:
			continue
		_uyuyan_kume_kur(aday)
		kurulan += 1

func _uyuyan_kume_kur(merkez: Vector2i) -> void:
	var n: int = KesifBalance.UYUYAN_KUME_MIN + int(
			DigWaterVisual.hash01(merkez.x, merkez.y, 557)
			* float(KesifBalance.UYUYAN_KUME_MAX - KesifBalance.UYUYAN_KUME_MIN + 1))
	n = clampi(n, KesifBalance.UYUYAN_KUME_MIN, KesifBalance.UYUYAN_KUME_MAX)
	var uyeler: Array = []
	for j in 16:
		if uyeler.size() >= n:
			break
		var oa := TAU * DigWaterVisual.hash01(merkez.x + j, merkez.y, 558)
		var od := 1.0 + DigWaterVisual.hash01(merkez.x, merkez.y + j, 559) * 1.8
		var c := merkez + Vector2i(roundi(cos(oa) * od), roundi(sin(oa) * od))
		if c == merkez or not is_walkable(c) or c in uyeler:
			continue
		uyeler.append(c)
	if uyeler.is_empty():
		return
	var idx := _uyuyan_kumeler.size()
	_uyuyan_kumeler.append({"merkez": merkez, "uyeler": uyeler,
			"durum": "uyuyor", "sayac": 0.0, "yaratiklar": []})
	for j in uyeler.size():
		_uyuyan_gorseller["%d:%d" % [idx, j]] = _uyuyan_gorsel_kur(
				Vector2i(uyeler[j]), false)
	# Kume ortasi odul: yerde oz yigini (toplamak = kumenin icine girmek)
	for item_id: String in KesifBalance.UYUYAN_ODUL:
		_add_ground_item(merkez, item_id, int(KesifBalance.UYUYAN_ODUL[item_id]))

## Tasllasmis Kulgezer: govde yaratik paletinin grileri, goz SONUK.
## Uyanirken gozler isir (emission) — "kabuk catlamasi" gorseli.
func _uyuyan_gorsel_kur(cell: Vector2i, gozler: bool) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.45, 0.50)
	mat.roughness = 1.0
	if gozler:
		mat.emission_enabled = true
		mat.emission = CreatureBalance.EYE_COLOR
		mat.emission_energy_multiplier = 1.2
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = _cell_center(cell) + Vector3(0, 0.45, 0)
	# Hafif one egik durus: "cokmus kabuk" hissi (donuk heykel)
	mi.rotation_degrees.x = 12.0 * (DigWaterVisual.hash01(cell.x, cell.y, 560) - 0.5)
	add_child(mi)
	return mi

## Gurultu kancasi (_apply_strike cagirir): kazma/kesme/kazi sesi.
func _uyuyan_gurultu(cell: Vector2i) -> void:
	for i in _uyuyan_kumeler.size():
		var k: Dictionary = _uyuyan_kumeler[i]
		if String(k["durum"]) != "uyuyor":
			continue
		if Vector2(cell - Vector2i(k["merkez"])).length() \
				<= KesifBalance.UYANMA_GURULTU_R:
			_uyuyan_uyandir(i)

## Kume uyanma baslangici: gozler isir, gecikme sayaci kurulur.
func _uyuyan_uyandir(idx: int) -> void:
	var k: Dictionary = _uyuyan_kumeler[idx]
	if String(k["durum"]) != "uyuyor":
		return
	k["durum"] = "uyaniyor"
	k["sayac"] = KesifBalance.UYANMA_GECIKME
	for j in Array(k["uyeler"]).size():
		var g = _uyuyan_gorseller.get("%d:%d" % [idx, j])
		if g != null and is_instance_valid(g):
			var mat := (g as MeshInstance3D).material_override as StandardMaterial3D
			mat.emission_enabled = true
			mat.emission = CreatureBalance.EYE_COLOR
			mat.emission_energy_multiplier = 1.6
	if hud != null:
		hud.flash_pill("Kabuk catliyor...")

## Kesif dongusunden (0.2 sn) cagrilir: uyanma kosullari + gecikme +
## yeniden uyuma + HUD nabzi.
func _tick_uyuyanlar(delta: float) -> void:
	if _uyuyan_kumeler.is_empty():
		return
	var pc := _player_cell()
	var isik: int = KesifBalance.tasinan_isik(Inventory)
	var parlak: bool = isik >= KesifBalance.PARLAK_UYANDIRIR_ISIK \
			and not _fener_kisik
	var en_yakin := 1e9
	for i in _uyuyan_kumeler.size():
		var k: Dictionary = _uyuyan_kumeler[i]
		var durum := String(k["durum"])
		if durum == "bos":
			continue
		var d := Vector2(pc - Vector2i(k["merkez"])).length()
		if durum != "uyanik":
			en_yakin = minf(en_yakin, d)
		match durum:
			"uyuyor":
				if d <= KesifBalance.UYANMA_R and (parlak or player.is_exerting()):
					_uyuyan_uyandir(i)
				elif d <= KesifBalance.UYANMA_CARPMA_R:
					_uyuyan_uyandir(i)  # ustlerine yurudun: carpma
			"uyaniyor":
				k["sayac"] = float(k["sayac"]) - delta
				if float(k["sayac"]) <= 0.0:
					_uyuyan_saldiri(i)
			"uyanik":
				if d > KesifBalance.YENIDEN_UYKU_R:
					_uyuyan_yeniden_uyut(i)
	# HUD nabzi: uyuyan (uyanik olmayan) en yakin kumeye yaklastikca artar.
	var nabiz := 0.0
	if en_yakin < KesifBalance.NABIZ_R:
		nabiz = clampf(1.0 - en_yakin / KesifBalance.NABIZ_R, 0.0, 1.0)
	if absf(nabiz - _nabiz_son) > 0.03:
		_nabiz_son = nabiz
		if hud != null:
			hud.set_nabiz(nabiz)

## Gecikme doldu: heykeller gercek yaratiklara donusur.
func _uyuyan_saldiri(idx: int) -> void:
	var k: Dictionary = _uyuyan_kumeler[idx]
	k["durum"] = "uyanik"
	var yaratiklar: Array = []
	for j in Array(k["uyeler"]).size():
		var g = _uyuyan_gorseller.get("%d:%d" % [idx, j])
		if g != null and is_instance_valid(g):
			g.visible = false
		var cr = spawn_creature(Vector2i(k["uyeler"][j]), "normal", 1.0)
		yaratiklar.append(cr)
	k["yaratiklar"] = yaratiklar

## Oyuncu menzilden cikti: sag kalan yaratiklar geri tasllasir. Hepsi
## olduyse kume BOS kalir (odul zaten ortadaydi — risk alindi, kazanildi).
func _uyuyan_yeniden_uyut(idx: int) -> void:
	var k: Dictionary = _uyuyan_kumeler[idx]
	var sag := 0
	for cr in Array(k["yaratiklar"]):
		if is_instance_valid(cr) and cr.is_alive():
			sag += 1
			cr.queue_free()
			_creatures.erase(cr)
	k["yaratiklar"] = []
	if sag == 0:
		k["durum"] = "bos"
		return
	k["durum"] = "uyuyor"
	k["sayac"] = 0.0
	for j in Array(k["uyeler"]).size():
		var g = _uyuyan_gorseller.get("%d:%d" % [idx, j])
		if g != null and is_instance_valid(g):
			g.visible = true
			var mat := (g as MeshInstance3D).material_override as StandardMaterial3D
			mat.emission_enabled = false

## Kayit: kume durumlari (bos/uyuyor); uyaniklar kayitta uyuyor sayilir
## (kayit anini stealth kacisina cevirme — muhafazakar).
func _uyuyan_to_save() -> Array:
	var out: Array = []
	for k in _uyuyan_kumeler:
		out.append({"x": Vector2i(k["merkez"]).x, "y": Vector2i(k["merkez"]).y,
				"bos": String(k["durum"]) == "bos"})
	return out

func _uyuyan_from_save(liste: Array) -> void:
	for kayit in liste:
		var m := Vector2i(int(kayit.get("x", 0)), int(kayit.get("y", 0)))
		for i in _uyuyan_kumeler.size():
			var k: Dictionary = _uyuyan_kumeler[i]
			if Vector2i(k["merkez"]) == m and bool(kayit.get("bos", false)):
				k["durum"] = "bos"
				for j in Array(k["uyeler"]).size():
					var g = _uyuyan_gorseller.get("%d:%d" % [i, j])
					if g != null and is_instance_valid(g):
						g.visible = false

## UYUTEST (hizli CI): yerlesim + uyandirma zinciri + yeniden uyuma.
func _run_uyuyan_test() -> void:
	var kume_n := _uyuyan_kumeler.size()
	if kume_n == 0:
		push_error("UYUYAN: hic kume yerlesmedi")
		print("UYUTEST: kume=0")
		return
	var k: Dictionary = _uyuyan_kumeler[0]
	var uye_n: int = Array(k["uyeler"]).size()
	_uyuyan_uyandir(0)
	var uyaniyor: bool = String(k["durum"]) == "uyaniyor"
	_uyuyan_saldiri(0)
	var dogan: int = Array(k["yaratiklar"]).size()
	_uyuyan_yeniden_uyut(0)
	var geri: bool = String(k["durum"]) == "uyuyor"
	if not uyaniyor or dogan != uye_n or not geri:
		push_error("UYUYAN: uyanma zinciri bozuk (%s/%d-%d/%s)"
				% [str(uyaniyor), dogan, uye_n, str(geri)])
	# Gurultu: merkeze vurunca uyanmali
	_uyuyan_gurultu(Vector2i(k["merkez"]))
	var gurultu_ok: bool = String(k["durum"]) == "uyaniyor"
	# Temizle: uyuyan durumuna geri dondur
	k["durum"] = "uyuyor"
	k["sayac"] = 0.0
	for j in uye_n:
		var g = _uyuyan_gorseller.get("0:%d" % j)
		if g != null and is_instance_valid(g):
			g.visible = true
			var mat := (g as MeshInstance3D).material_override as StandardMaterial3D
			mat.emission_enabled = false
	print("UYUTEST: kume=%d uye=%d uyanma=%s dogan=%d yeniden_uyku=%s gurultu=%s" % [
			kume_n, uye_n, str(uyaniyor), dogan, str(geri), str(gurultu_ok)])

# =========================================================================
# KESIF Asama 5 (16.6) — UZAK TEHDITLER (halka bazli, dalga DEGIL)
# =========================================================================
# Sisli halkalarda "gunduz guvenli" kurali KIRILIR (16.2): ortam
# dogurucu UZAK_TIK_ARALIK'ta bir zar atar. Sis Surusu (H2+), Fener
# Avcisi (H2+, YALNIZ parlak isik varken; isik kisilinca ilgisini
# yitirir), Catlak Dev (H3). Cevresel: Kul Firtinasi (H3, gorus kapanir,
# siginak ara) + Damar Catlagi (H3, isik sizan yarik yaratik ceker —
# akilli oyuncu tuzak olarak kullanir). Hepsi mevcut AI iskeletinin
# varyanti (stat + "uzak" metasi); take_hit/oz aynen calisir.

var _uzak_timer: float = 0.0
var _uzak_yaratiklar: Array = []
var _firtina_kalan: float = 0.0
var _firtina_bekleme: float = 0.0
var _damar_catlaklari: Array = []   # [Vector2i]
var _damar_gorseller: Array = []

func _place_damar_catlaklari() -> void:
	for g in _damar_gorseller:
		if is_instance_valid(g):
			g.queue_free()
	_damar_gorseller.clear()
	_damar_catlaklari.clear()
	var merkez := get_hearth()
	if merkez == Vector2i(-999, -999):
		merkez = _spawn_cell
	for i in 30:
		if _damar_catlaklari.size() >= KesifBalance.DAMAR_SAYI:
			break
		var aci := TAU * DigWaterVisual.hash01(i, 9, 661)
		var r := 48.0 + DigWaterVisual.hash01(i, 11, 662) * 14.0
		var aday := merkez + Vector2i(roundi(cos(aci) * r), roundi(sin(aci) * r))
		aday = _kor_tas_yer_bul(aday)
		if aday == Vector2i(-999, -999) or get_ring(aday) < 3:
			continue
		if aday in _damar_catlaklari:
			continue
		_damar_catlaklari.append(aday)
		# Gorsel: zeminde isik sizan yarik (yassi emissive serit)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.4, 0.05,
				0.22 + DigWaterVisual.hash01(aday.x, aday.y, 663) * 0.2)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.15, 0.12, 0.18)
		mat.emission_enabled = true
		mat.emission = Color(0.4, 0.9, 0.9)
		mat.emission_energy_multiplier = 1.1
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = _cell_center(aday) + Vector3(0, 0.04, 0)
		mi.rotation_degrees.y = 360.0 * DigWaterVisual.hash01(aday.x, aday.y, 664)
		add_child(mi)
		_damar_gorseller.append(mi)

## Yaratiga en yakin cekim catlagi (yoksa gecersiz hucre).
func _damar_yakin(cell: Vector2i) -> Vector2i:
	for c: Vector2i in _damar_catlaklari:
		if Vector2(cell - c).length() <= KesifBalance.DAMAR_CEKIM_R:
			return c
	return Vector2i(-999, -999)

## Ortam dogurucu tik'i (kesif dongusu cagirir, UZAK_TIK_ARALIK'ta bir).
func _tick_uzak_tehditler(delta: float) -> void:
	# Firtina saatleri
	_firtina_bekleme = maxf(0.0, _firtina_bekleme - delta)
	if _firtina_kalan > 0.0:
		_firtina_kalan = maxf(0.0, _firtina_kalan - delta)
		if _firtina_kalan <= 0.0:
			_son_vinyet = -1.0
			if hud != null:
				hud.flash_pill("Firtina dindi")
	# Uzaklasan ortam yaratiklarini temizle (dert oyuncunun pesinde
	# surunmek degil, BOLGENIN tekinsizligi).
	var pc := _player_cell()
	for cr in _uzak_yaratiklar.duplicate():
		if not is_instance_valid(cr) or not cr.is_alive():
			_uzak_yaratiklar.erase(cr)
			continue
		var d := Vector2(cr.position.x - float(pc.x) - 0.5,
				cr.position.z - float(pc.y) - 0.5).length()
		if d > KesifBalance.UZAK_DESPAWN_R:
			cr.melt(0.6)
			_creatures.erase(cr)
			_uzak_yaratiklar.erase(cr)
	# Fener Avcisi ilgi kaybi: parlak isik yoksa erir (isik yonetimi ODULU)
	var parlak: bool = KesifBalance.tasinan_isik(Inventory) \
			>= KesifBalance.PARLAK_UYANDIRIR_ISIK and not _fener_kisik
	if not parlak and not _kamp_atesi_yakinimda():
		for cr in _uzak_yaratiklar.duplicate():
			if is_instance_valid(cr) and String(cr.type) == "fener_avcisi":
				cr.melt(0.8)
				_creatures.erase(cr)
				_uzak_yaratiklar.erase(cr)
	# Zar zamani mi?
	_uzak_timer += delta
	if _uzak_timer < KesifBalance.UZAK_TIK_ARALIK:
		return
	_uzak_timer = 0.0
	var ring := get_ring(pc)
	if ring < 2 or _sis_at_cell(pc) <= 0.0:
		return  # temizlenmis bolge Yuva kurallarina doner (16.2)
	if _uzak_yaratiklar.size() >= KesifBalance.UZAK_MAX_AKTIF:
		return
	var tohum: int = pc.x * 131 + pc.y * 17 + int(Time.get_ticks_msec() / 1000)
	var zar := DigWaterVisual.hash01(tohum, ring, 665)
	if zar < KesifBalance.SURU_SANS:
		var n: int = KesifBalance.SURU_MIN + int(
				DigWaterVisual.hash01(tohum, 3, 666)
				* float(KesifBalance.SURU_MAX - KesifBalance.SURU_MIN + 1))
		for i in n:
			_uzak_dogur(pc, "sis_surusu", i)
	if parlak and DigWaterVisual.hash01(tohum, 5, 667) < KesifBalance.AVCI_SANS:
		_uzak_dogur(pc, "fener_avcisi", 9)
	if ring >= 3:
		if DigWaterVisual.hash01(tohum, 7, 668) < KesifBalance.DEV_SANS:
			_uzak_dogur(pc, "catlak_dev", 12)
		if _firtina_kalan <= 0.0 and _firtina_bekleme <= 0.0 \
				and DigWaterVisual.hash01(tohum, 8, 669) < KesifBalance.FIRTINA_SANS:
			_firtina_kalan = KesifBalance.FIRTINA_SURE
			_firtina_bekleme = KesifBalance.FIRTINA_BEKLEME
			_son_vinyet = -1.0
			if hud != null:
				hud.flash_pill("Kul firtinasi! Siginak bul")
			# Firtinada uyuyanlar homurdanir (16.6): nabiz hissi
			if hud != null:
				hud.set_nabiz(0.5)

func _uzak_dogur(pc: Vector2i, tip: String, salt: int) -> void:
	if _uzak_yaratiklar.size() >= KesifBalance.UZAK_MAX_AKTIF:
		return
	for i in 12:
		var aci := TAU * DigWaterVisual.hash01(pc.x + salt, pc.y + i, 670)
		var cell := pc + Vector2i(
				roundi(cos(aci) * KesifBalance.UZAK_SPAWN_R),
				roundi(sin(aci) * KesifBalance.UZAK_SPAWN_R))
		if cell.x < 1 or cell.y < 1 or cell.x >= _map_w - 1 or cell.y >= _map_h - 1:
			continue
		if not is_walkable(cell):
			continue
		var cr = spawn_creature(cell, tip, 1.0)
		cr.set_meta("uzak", true)
		_uzak_yaratiklar.append(cr)
		return

## Firtina siginagi: kamp atesi ya da Ocak yakini.
func _firtina_siginakta() -> bool:
	var pc := _player_cell()
	var hc := get_hearth()
	if hc != Vector2i(-999, -999) \
			and Vector2(pc - hc).length() <= KesifBalance.FIRTINA_SIGINAK_R:
		return true
	return _kamp_atesi_yakinimda()

## UZAKTEST (hizli CI): tip verileri + dogurucu + avci isik kurali +
## damar yerlesimi + firtina vinyeti.
func _run_uzak_test() -> void:
	var tip_ok: bool = CreatureBalance.TYPES.has("sis_surusu") \
			and CreatureBalance.TYPES.has("fener_avcisi") \
			and CreatureBalance.TYPES.has("catlak_dev")
	if not tip_ok:
		push_error("UZAK: tehdit tipleri CreatureBalance'ta eksik")
	# Dalga havuzuna sizmamalilar (first_night 999)
	var havuz: Array = CreatureBalance.unlocked_types(50)
	var sizinti: bool = "sis_surusu" in havuz or "fener_avcisi" in havuz \
			or "catlak_dev" in havuz
	if sizinti:
		push_error("UZAK: uzak tehdit gece dalgasi havuzuna sizdi")
	# Dogurucu: zorla dogur -> uzak metasi + canli
	var onceki: int = _uzak_yaratiklar.size()
	_uzak_dogur(Vector2i(64, 64), "sis_surusu", 1)
	var dogdu: bool = _uzak_yaratiklar.size() == onceki + 1
	if dogdu:
		var cr = _uzak_yaratiklar[-1]
		if not cr.has_meta("uzak"):
			push_error("UZAK: ortam yaratiginda 'uzak' metasi yok")
		cr.queue_free()
		_creatures.erase(cr)
		_uzak_yaratiklar.erase(cr)
	else:
		push_error("UZAK: ortam dogurucu calismiyor")
	var damar_n := _damar_catlaklari.size()
	var firtina_v: float = KesifBalance.FIRTINA_VINYET
	if firtina_v < 0.9:
		push_error("UZAK: firtina vinyeti gorusu kapatmiyor")
	print("UZAKTEST: tipler=%s havuz_temiz=%s dogum=%s damar=%d firtina_v=%.2f" % [
			str(tip_ok), str(not sizinti), str(dogdu), damar_n, firtina_v])

# =========================================================================
# KESIF Asama 6 (16.7-16.8) — odul sorgusu + performans + gorsel kanit
# =========================================================================

## Muhur Cagi kalici bonusu (16.7 yanC): sabah ekonomisi isi geldiginde
## carpani buradan okur (KesifBalance.YANC_SABAH_CARPAN). Tas durumundan
## TURETILIR — ayri kayit alani yok, bozulacak ikinci gercek yok.
func muhur_bonusu_aktif() -> bool:
	return _kor_taslari.has("yanC") and bool(_kor_taslari["yanC"]["yanik"])

## KESIFPERF (hizli CI): sis/simulasyon maliyetinin DURUST olcumu.
## CI yazilim rasterizasyonunda FPS anlamsiz; anlamli olan: (1) kesif
## dongusunun CPU suresi, (2) dalga simulasyonunun CPU suresi, (3) bolum
## 16'nin sahneye ekledigi dugum sayisi. Mobil butcesi bunlardan okunur.
func _run_kesif_perf() -> void:
	var t0 := Time.get_ticks_usec()
	for i in 100:
		_update_kesif()
	var kesif_us := (Time.get_ticks_usec() - t0) / 100.0
	t0 = Time.get_ticks_usec()
	for i in 20:
		_savunma_puani()
	var savunma_us := (Time.get_ticks_usec() - t0) / 20.0
	var dugum := _kor_tas_gorseller.size() + _uyuyan_gorseller.size() \
			+ _damar_gorseller.size() + (1 if _sis_duzlem != null else 0)
	# Butce bekcisi: kesif dongusu karede degil 0.2 sn'de bir kosar;
	# yine de tek cagri 2 ms'yi asarsa mobilde hissedilir — kirmizi.
	if kesif_us > 2000.0:
		push_error("KESIFPERF: kesif dongusu cok pahali (%.0f us)" % kesif_us)
	if savunma_us > 5000.0:
		push_error("KESIFPERF: savunma puani cok pahali (%.0f us)" % savunma_us)
	print("KESIFPERF: kesif_dongusu=%.0fus savunma_puani=%.0fus ek_dugum=%d" % [
			kesif_us, savunma_us, dugum])

## Agir CI kareleri: kor tasi yakin, uyuyan kumesi, sisli halka vinyeti
## (oyuncu isiksiz Halka 2'de), damar catlagi. Oyuncu konumu geri sarilir.
func _run_kesif_frames(save_path: String) -> void:
	_cam_locked = true
	var eski_poz := player.position
	# KADRAJ DERSI (ilk turdan): yakin-alcak kamera engebeli arazide
	# yamacin icine gomuluyor (tas/damar kareleri bos cikti). Yuksek ve
	# geriden bak — tepe olsa da hedef gorunur.
	var dbg: Array = []
	# 1) Kor tasi (ana1) — neredeyse kus bakisi: arada agac kalmasin
	if _kor_taslari.has("ana1"):
		var tc := Vector2i(_kor_taslari["ana1"]["cell"])
		var tp := _cell_center(tc)
		camera.position = tp + Vector3(0.6, 7.5, 3.2)
		camera.look_at(tp + Vector3(0, 0.6, 0))
		var g = _kor_tas_gorseller.get("ana1")
		dbg.append("tas ana1 cell=%s gorsel=%s poz=%s visible=%s" % [
				str(tc), str(g != null and is_instance_valid(g)),
				str(g.position) if g != null and is_instance_valid(g) else "-",
				str(g.visible) if g != null and is_instance_valid(g) else "-"])
		await get_tree().create_timer(0.7).timeout
		_snap(save_path.replace(".png", "_kesif_tas.png"))
	# 2) Uyuyan kumesi
	if not _uyuyan_kumeler.is_empty():
		var mp := _cell_center(Vector2i(_uyuyan_kumeler[0]["merkez"]))
		camera.position = mp + Vector3(-3.5, 3.2, 4.5)
		camera.look_at(mp + Vector3(0, 0.5, 0))
		await get_tree().create_timer(0.7).timeout
		_snap(save_path.replace(".png", "_kesif_uyuyan.png"))
	# 3) Sis vinyeti: oyuncu Halka 2'de ISIKSIZ olmali. CI turu envantere
	# fener/koz kabi da veriyor (ilk turda kapi hic kapanmadi) — isik
	# esyalarini gecici cikar, kareyi al, geri ver.
	var merkez := get_hearth()
	if merkez == Vector2i(-999, -999):
		merkez = _spawn_cell
	var hedef := _kor_tas_yer_bul(merkez + Vector2i(38, 0))
	if hedef != Vector2i(-999, -999):
		var isik_stash := {}
		for tier in KesifBalance.ISIK_ESYA:
			var iid: String = String(KesifBalance.ISIK_ESYA[tier])
			isik_stash[iid] = Inventory.get_count(iid)
			if isik_stash[iid] > 0:
				Inventory.remove_item(iid, isik_stash[iid])
		player.position = _cell_center(hedef)
		camera.position = player.position + _camera_offset()
		_update_kesif()  # zamanlayiciyi bekleme: kapi etkisi hemen
		var pc2 := _player_cell()
		dbg.append("sis hedef=%s pc=%s halka=%d sis=%.2f isik=%d acik=%d son_vinyet=%.2f" % [
				str(hedef), str(pc2), get_ring(pc2), _sis_at_cell(pc2),
				KesifBalance.tasinan_isik(Inventory), _isik_acik, _son_vinyet])
		if hud != null:
			var sv = hud.get("_sis_vinyet")
			dbg.append("hud sis_vinyet=%s alpha=%s" % [
					str(sv != null),
					str(sv.modulate.a) if sv != null else "-"])
		await get_tree().create_timer(0.8).timeout
		_snap(save_path.replace(".png", "_kesif_sis.png"))
		for iid in isik_stash:
			if isik_stash[iid] > 0:
				Inventory.add_item(iid, isik_stash[iid])
	# 4) Damar catlagi — kus bakisina yakin. Ilk catlak calilarin altinda
	# kalabiliyor (3. tur dersi): cevresi EN BOS catlagi sec.
	if not _damar_catlaklari.is_empty():
		var dc := Vector2i(_damar_catlaklari[0])
		var en_az := 999
		for aday: Vector2i in _damar_catlaklari:
			var n := 0
			for oy in range(-2, 3):
				for ox in range(-2, 3):
					if _objects.has(aday + Vector2i(ox, oy)):
						n += 1
			if n < en_az:
				en_az = n
				dc = aday
		var dp := _cell_center(dc)
		camera.position = dp + Vector3(0.3, 8.0, 2.0)
		camera.look_at(dp)
		dbg.append("damar cell=%s gorsel_n=%d" % [str(dc), _damar_gorseller.size()])
		await get_tree().create_timer(0.7).timeout
		_snap(save_path.replace(".png", "_kesif_damar.png"))
	player.position = eski_poz
	camera.position = player.position + _camera_offset()
	_update_kesif()
	# Teshis dokumu: agir CI auto-commit'iyle repoya gelir (attachdbg kalibi)
	var f := FileAccess.open("res://docs/screens/kesifdbg.txt", FileAccess.WRITE)
	if f != null:
		for satir in dbg:
			f.store_line(String(satir))
		f.close()
	await get_tree().create_timer(0.4).timeout
	_cam_locked = false

# =========================================================================
# SU SHADER V1 (su-shader-v1) — sicak isiklar + gorsel kanit kareleri
# =========================================================================

## Sudaki sicak yansima isiklari: aktif Ocak + mesaleler/sefer atesleri
## icinden SUYA en yakin 4'u. HER KARede DEGIL: yalniz isik degisiminde
## cagrilir (_activate_hearth / _add_torch_light / yapi sokumu) —
## sozlesmenin performans sarti.
func _update_water_warm_lights() -> void:
	if not DigWaterVisual.SU_SHADER_V1 or _lake_mat == null:
		return
	var adaylar: Array = []
	var hc := get_hearth()
	if hc != Vector2i(-999, -999):
		adaylar.append(hc)
	for c: Vector2i in _torch_lights:
		adaylar.append(c)
	var skorlu: Array = []
	for c: Vector2i in adaylar:
		var en := 1e9
		for w: Vector2i in _lake_cells_list:
			en = minf(en, Vector2(c - w).length())
			if en <= 1.5:
				break
		if en > 1.5:
			for w2 in _water_level:
				en = minf(en, Vector2(c - Vector2i(w2)).length())
		if en <= 12.0:
			skorlu.append({"c": c, "d": en})
	skorlu.sort_custom(func(a, b): return float(a["d"]) < float(b["d"]))
	var isiklar := PackedVector3Array()
	var n: int = mini(4, skorlu.size())
	for i in n:
		isiklar.append(_cell_center(Vector2i(skorlu[i]["c"])))
	while isiklar.size() < 4:
		isiklar.append(Vector3.ZERO)
	_lake_mat.set_shader_parameter("warm_lights", isiklar)
	_lake_mat.set_shader_parameter("warm_light_count", n)

## Agir CI kareleri: golet gunduz / gece (kiyida sicak isik!) / su dolu
## hendek / akan kanal. Kazi GERCEK yoldan yapilir (kurek + _try_dig) —
## dogrudan _depth yazmak terrain'i guncellemez, su yuzeyi arazinin
## altinda kalirdi (yol karolarindan ogrenilen tuzak).
func _run_su_frames(save_path: String) -> void:
	if _lake_cells_list.is_empty():
		return
	_cam_locked = true
	var eski_poz := player.position
	var eski_el := _held_item
	# Gol kiyisi: komsusu kara olan ilk gol hucresi
	var kiyi := Vector2i(-999, -999)
	var kara := Vector2i(-999, -999)
	for w: Vector2i in _lake_cells_list:
		for nn: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var k := w + nn
			if is_walkable(k) and not _placed.has(k) and not _objects.has(k):
				kiyi = w
				kara = k
				break
		if kiyi != Vector2i(-999, -999):
			break
	if kiyi == Vector2i(-999, -999):
		_cam_locked = false
		return
	var kp := _cell_center(kiyi)
	# 1) GOLET GUNDUZ
	camera.position = kp + Vector3(-4.0, 4.5, 6.0)
	camera.look_at(kp)
	await get_tree().create_timer(0.9).timeout
	_snap(save_path.replace(".png", "_su_golet.png"))
	# 2) GECE + KIYIDA SICAK ISIK: kiyiya mesale (gorevdeki "Ocak kiyisinda"
	# niyeti sicak yansima; Ocak'i tasimak kamp merkezini bozacagi icin
	# ayni sicak-isik yolunu kullanan mesale konur — RAPOR'da gerekceli).
	_set_placed(kara, "mesale")
	_update_water_warm_lights()
	DayNight.jump_to_night()
	_clear_creatures()
	await get_tree().create_timer(1.0).timeout
	_snap(save_path.replace(".png", "_su_golet_gece.png"))
	DayNight.jump_to_day()
	_release_structure_cell(kara)
	if _placed_nodes.has(kara):
		(_placed_nodes[kara] as Node3D).queue_free()
		_placed_nodes.erase(kara)
	# 3) SU DOLU HENDEK: kamptan uzakta temiz zemin, gercek kazi + su dok
	var merkez := get_hearth()
	if merkez == Vector2i(-999, -999):
		merkez = _spawn_cell
	var hendek := _kor_tas_yer_bul(merkez + Vector2i(10, 8))
	if hendek != Vector2i(-999, -999):
		Inventory.add_item("kurek", 1)
		_on_hold_requested("kurek")
		_try_dig(hendek)
		_try_dig(hendek)
		add_water(hendek, 1.6)
		var hp2 := _cell_center(hendek)
		camera.position = hp2 + Vector3(-2.2, 2.6, 3.2)
		camera.look_at(hp2)
		await get_tree().create_timer(0.8).timeout
		_snap(save_path.replace(".png", "_su_hendek.png"))
	# 4) AKAN KANAL: 4 hucre kanal + akis isareti (+x). Akis VERISI oyunda
	# boru transferinden gelir (_transfer_in_component yazar); karede ayni
	# veri yolu elle beslenir — shader'in akis cizimi kanitlanir.
	var k0 := _kor_tas_yer_bul(merkez + Vector2i(-12, 9))
	if k0 != Vector2i(-999, -999):
		var kanal: Array = []
		for i in 4:
			var c2 := k0 + Vector2i(i, 0)
			if is_walkable(c2) and not _placed.has(c2) and not _objects.has(c2):
				kanal.append(c2)
		if kanal.size() >= 3:
			for c2: Vector2i in kanal:
				_try_dig(c2)
				_flow_dirs[c2] = {"dir": Vector2(1, 0),
						"t": Time.get_ticks_msec()}
			add_water(kanal[0], 1.2 * kanal.size())
			var cp := _cell_center(Vector2i(kanal[1]))
			camera.position = cp + Vector3(-1.5, 2.4, 3.4)
			camera.look_at(cp)
			await get_tree().create_timer(0.8).timeout
			_snap(save_path.replace(".png", "_su_kanal.png"))
	# Toparla
	if eski_el != "":
		_on_hold_requested(eski_el)
	player.position = eski_poz
	camera.position = player.position + _camera_offset()
	await get_tree().create_timer(0.4).timeout
	_cam_locked = false

# =========================================================================
# CIM SHADER V1 (cim-shader) — materyaller + kalite + test + kareler
# =========================================================================
# grass.gdshader sus otu MultiMesh'lerine (material_override, MMI
# duzeyinde: TEK draw call korunur) + ciceklere dusuk-ruzgar kopyasi.
# noise_tex ve night_mix SU ILE AYNI kaynaktan (sozlesme sarti).

var _cim_mat: ShaderMaterial
var _cicek_mat: ShaderMaterial
var _cim_ezme_on: bool = true      # quality 0'da player_pos seti atlanir
var _ortak_noise: NoiseTexture2D   # su + cim paylasir (bellek)

## Su ve cimin paylastigi seamless noise (bir kez uretilir).
func _ortak_noise_tex() -> NoiseTexture2D:
	if _ortak_noise != null:
		return _ortak_noise
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.012
	_ortak_noise = NoiseTexture2D.new()
	_ortak_noise.noise = fn
	_ortak_noise.seamless = true
	_ortak_noise.width = 256
	_ortak_noise.height = 256
	return _ortak_noise

## Cim materyali. blade_height SOZLESME geregi OLCULUR: havuzdaki
## mesh'lerin en yuksek AABB'si (Root Scale sonrasi gercek boy).
func _cim_material(pool: Array = []) -> ShaderMaterial:
	if not DigWaterVisual.CIM_SHADER_V1:
		return null
	if _cim_mat != null:
		return _cim_mat
	_cim_mat = ShaderMaterial.new()
	_cim_mat.shader = load("res://assets/models/env/grass.gdshader")
	var boy := 0.30
	for m: Mesh in pool:
		boy = maxf(boy, m.get_aabb().size.y)
	_cim_mat.set_shader_parameter("blade_height", boy)
	_cim_mat.set_shader_parameter("noise_tex", _ortak_noise_tex())
	_apply_cim_tier()
	return _cim_mat

## Cicek kopyasi: ayni shader, dusuk ruzgar + pembe uc (baslar savrulmaz).
func _cicek_material() -> ShaderMaterial:
	if not DigWaterVisual.CIM_SHADER_V1:
		return null
	if _cicek_mat != null:
		return _cicek_mat
	_cicek_mat = ShaderMaterial.new()
	_cicek_mat.shader = load("res://assets/models/env/grass.gdshader")
	_cicek_mat.set_shader_parameter("noise_tex", _ortak_noise_tex())
	_cicek_mat.set_shader_parameter("wind_strength",
			DigWaterVisual.CIM_CICEK_WIND)
	_cicek_mat.set_shader_parameter("color_tip", DigWaterVisual.CIM_CICEK_TIP)
	_cicek_mat.set_shader_parameter("color_base", DigWaterVisual.CIM_CICEK_BASE)
	_cicek_mat.set_shader_parameter("blade_height", 0.30)
	_apply_cim_tier()
	return _cicek_mat

## Kalite kademesi -> cim quality uniform'u. Dusuk'te ruzgar/ezme kapali
## VE player_pos guncellemesi de atlanir (sozlesme: "quality 0'da
## guncelleme de atlansin").
func _apply_cim_tier() -> void:
	var t := DigWaterVisual.tier_of(_quality_tier)
	var q: int = 1 if bool(t["wave"]) else 0
	_cim_ezme_on = q > 0
	if _cim_mat != null:
		_cim_mat.set_shader_parameter("quality", q)
	if _cicek_mat != null:
		_cicek_mat.set_shader_parameter("quality", q)

## CIMTEST (hizli CI): materyal atamasi + TEK draw call korunumu +
## blade_height olcumu + kaynak paylasimi.
func _run_cim_test() -> void:
	var mmi_n := 0
	var shaderli := 0
	var ornek_toplam := 0
	for node in _decor_nodes:
		# Cakil/dal serpintisi de _decor_nodes'ta yasar ama BILEREK
		# shadersiz (tas/dal sallanmamali). Ilk halde onlar da sayilip
		# "2/3 shadersiz" hatasi uretiyordu — ve CI'nin push_error agi
		# delik oldugu icin (asagida, ci-fast.yml) yesil kalmisti.
		if _env_scatter_nodes.has(node):
			continue
		if node is MultiMeshInstance3D:
			mmi_n += 1
			ornek_toplam += (node as MultiMeshInstance3D).multimesh.instance_count
			if (node as MultiMeshInstance3D).material_override is ShaderMaterial:
				shaderli += 1
	var boy: float = -1.0
	var paylasim := false
	if _cim_mat != null:
		boy = float(_cim_mat.get_shader_parameter("blade_height"))
		paylasim = _cim_mat.get_shader_parameter("noise_tex") \
				== (_lake_mat.get_shader_parameter("noise_tex")
				if _lake_mat != null else null)
	if DigWaterVisual.CIM_SHADER_V1 and shaderli != mmi_n:
		push_error("CIM: %d/%d sus otu MMI'si shadersiz kaldi"
				% [mmi_n - shaderli, mmi_n])
	if DigWaterVisual.CIM_SHADER_V1 and (boy < 0.05 or boy > 2.0):
		push_error("CIM: blade_height olcumu sacma (%.2f)" % boy)
	print("CIMTEST: mmi=%d shaderli=%d ornek=%d blade_height=%.2f noise_paylasim=%s cicek=%s" % [
			mmi_n, shaderli, ornek_toplam, boy, str(paylasim),
			str(_cicek_mat != null)])

## Agir CI kareleri: cayir gunduz (ruzgar: 1 sn arayla IKI kare — statik
## goruntude hareket ancak farkla kanitlanir; gif borcu RAPOR'da),
## karakter cim icinde (ezme), gece (su+cim ton uyumu tek karede).
func _run_cim_frames(save_path: String) -> void:
	if _decor_cells.is_empty():
		return
	_cam_locked = true
	var eski_poz := player.position
	# _decor_cells TUM cim hucreleri; tutam yalniz hash<20 olanlarda
	# (_build_decor filtresiyle AYNI kural) — bos hucreye kadraj olmasin.
	var hedef := Vector2i(-999, -999)
	for c: Vector2i in _decor_cells:
		if absi(c.x * 92821 + c.y * 68917) % 100 >= 20:
			continue
		# 3. tur dersi: agac dibindeki tutam kadraji agacla kapatiyor —
		# 2 hucre cevresi nesnesiz (agac/kaya/cali) tutam sec.
		var acik := true
		for oy in range(-2, 3):
			for ox in range(-2, 3):
				if _objects.has(c + Vector2i(ox, oy)):
					acik = false
					break
			if not acik:
				break
		if acik:
			hedef = c
			break
	if hedef == Vector2i(-999, -999):
		_cam_locked = false
		return
	var hp := _cell_center(hedef)
	camera.position = hp + Vector3(-2.5, 2.2, 3.5)
	camera.look_at(hp + Vector3(0, 0.2, 0))
	await get_tree().create_timer(0.8).timeout
	_snap(save_path.replace(".png", "_cim_ruzgar_a.png"))
	await get_tree().create_timer(1.0).timeout
	_snap(save_path.replace(".png", "_cim_ruzgar_b.png"))
	# Ezme: oyuncu cimin icine
	player.position = hp
	camera.position = hp + Vector3(-1.6, 2.6, 3.0)
	camera.look_at(hp + Vector3(0, 0.3, 0))
	await get_tree().create_timer(0.6).timeout
	_snap(save_path.replace(".png", "_cim_ezme.png"))
	# Gece: gol kiyisinda cim — su+cim ton uyumu tek karede
	if not _lake_cells_list.is_empty():
		var kiyi := Vector2i(-999, -999)
		for w: Vector2i in _lake_cells_list:
			for c: Vector2i in _decor_cells:
				if Vector2(c - w).length() <= 3.0:
					kiyi = w
					break
			if kiyi != Vector2i(-999, -999):
				break
		if kiyi != Vector2i(-999, -999):
			var kp := _cell_center(kiyi)
			DayNight.jump_to_night()
			_clear_creatures()
			camera.position = kp + Vector3(-3.0, 2.8, 4.0)
			camera.look_at(kp)
			await get_tree().create_timer(1.0).timeout
			_snap(save_path.replace(".png", "_cim_su_gece.png"))
			DayNight.jump_to_day()
	player.position = eski_poz
	camera.position = player.position + _camera_offset()
	await get_tree().create_timer(0.4).timeout
	_cam_locked = false
