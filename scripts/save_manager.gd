extends Node
## KAYIT YÖNETİCİSİ (autoload) — TEK ÇATI. Her sistemin to_save_data()/
## from_save_data() çiftini TOPLAR/DAĞITIR; kendi merkezi dev serileştirmesi
## YOK. JSON, user:// dizini, tek slot. "version" alanı + migration kancası.
## Android'de user:// uygulamanın özel klasörü (oyun silinmedikçe kayıt durur).

const SAVE_PATH: String = "user://save.json"        # 2D legacy (world.gd)
const SAVE3D_PATH: String = "user://save3d.json"    # TEK ÇATI birleşik kayıt
const RESEARCH_LEGACY: String = "user://research.json"
const SAVE_VERSION: int = 1

signal saved  # HUD "kaydedildi" işareti için

var world: Node = null  # world3d kendini kaydeder/yükler (sahne durumu)

# --- 2D legacy API (dokunulmadı; eski world.gd kullanır) --------------------

func save_data(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Kayit yazilamadi: " + str(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data))
	file.close()

func load_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}

# --- TEK ÇATI (3D) birleşik kayıt -------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE3D_PATH)

## Tüm sistemlerin durumunu toplar ve tek dosyaya yazar. Başarı: true.
func save() -> bool:
	if world == null or not world.has_method("to_save_data"):
		return false
	var world_data: Dictionary = world.to_save_data()
	if world_data.is_empty():
		return false  # dünya henüz hazır değil
	var data := {
		"version": SAVE_VERSION,
		"world": world_data,
		"inventory": Inventory.to_save(),
		"crafting": Crafting.to_save(),
		"research": Research.to_save_data(),
		"health": Health.to_save_data(),
		"hunger": Hunger.to_save_data(),
		"thirst": Thirst.to_save_data(),
		"player_stats": PlayerStats.to_save_data(),
		"daynight": DayNight.to_save_data(),
	}
	var file := FileAccess.open(SAVE3D_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Kayit yazilamadi: " + str(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	saved.emit()
	return true

## Kaydı okur, gerekirse migrate eder, her sisteme dağıtır. Başarı: true.
## Sıra önemli: autoload'lar ÖNCE (dünya, eldeki aleti envanterden doğrular),
## sahne EN SON.
func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE3D_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return false
	var data: Dictionary = _migrate(parsed)
	if int(data.get("version", 0)) != SAVE_VERSION:
		return false  # tanımsız/eski sürüm -> yeni oyun
	Inventory.load_save(data.get("inventory", {}))
	Crafting.load_save(data.get("crafting", []))
	Research.from_save_data(data.get("research", {}))
	Health.from_save_data(data.get("health", {}))
	Hunger.from_save_data(data.get("hunger", {}))
	Thirst.from_save_data(data.get("thirst", {}))
	PlayerStats.from_save_data(data.get("player_stats", {}))
	DayNight.from_save_data(data.get("daynight", {}))
	if world != null and world.has_method("from_save_data"):
		return world.from_save_data(data.get("world", {}))
	return true

## Sürümler arası geçiş kancası. Şimdilik v1 tek sürüm. İleride:
##   if v < 2: data = _v1_to_v2(data)  ... gibi zincir.
func _migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("version", 0))
	if v == SAVE_VERSION:
		return data
	# Bilinmeyen/eski sürüm: olduğu gibi döner; load_game reddeder (yeni oyun).
	return data

func delete_save() -> void:
	for path in [SAVE_PATH, SAVE3D_PATH, RESEARCH_LEGACY]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
