extends Node
## ARASTIRMA AGACI - autoload (GAME_DESIGN.md Bolum 9).
##
## Dugum formati: id -> {branch, prereq, cost {esya: adet}, unlocks [tarif],
##                       hidden, reveal_trigger_item}
## - branch: "aletler" | "insaat" | "istasyonlar" | "muhendislik"
## - prereq "": kok dugum. cost {}: bedava.
## - hidden dugumler reveal_trigger_item ilk toplandiginda "???" olarak
##   belirir (revealed), arastirilana kadar tarifleri kilitlidir.
##
## MANTIK: can_research/do_research envanterle konusur. Crafting.can_craft
## is_recipe_unlocked()'a sorar: bir tarif HERHANGI bir dugumun unlocks
## listesindeyse yalnizca o dugum acildiginda uretilebilir; hicbir dugumde
## gecmeyen tarifler (mevcut Turkce id'li eski tarifler dahil) serbesttir -
## boylece yasayan oyun bozulmaz, yeni katalog kademeli devreye girer.
##
## Kayit: kendi dosyasina yazar (user://research.json); "Yeni Oyun"da
## reset() cagrilir.

signal changed

const SAVE_PATH := "user://research.json"

## NOT: research_table kok dugume eklendi (dokumanda yok) - masa
## uretilemezse agacin geri kalani acilamazdi (tavuk-yumurta).
## hunting_tools ve basic_traps dokumandaki "tam liste veri dosyasinda
## genisletilir" notuna dayanarak eklendi.
const NODES: Dictionary = {
	"research_basics": {"branch": "istasyonlar", "prereq": "", "cost": {},
			"unlocks": ["club", "campfire", "rope", "research_table"],
			"hidden": false},
	"stone_tools": {"branch": "aletler", "prereq": "research_basics",
			"cost": {"stick": 5, "pebble": 3},
			"unlocks": ["stone_axe", "stone_pickaxe"], "hidden": false},
	"hunting_tools": {"branch": "aletler", "prereq": "stone_tools",
			"cost": {"stick": 4, "rope": 2},
			"unlocks": ["spear", "sling", "stone_knife"], "hidden": false},
	"basic_building": {"branch": "insaat", "prereq": "research_basics",
			"cost": {"wood": 8},
			"unlocks": ["wood_wall", "wood_door", "fence"], "hidden": false},
	"basic_traps": {"branch": "insaat", "prereq": "basic_building",
			"cost": {"wood": 6, "rope": 2},
			"unlocks": ["spikes", "pit_trap", "trip_alarm"], "hidden": false},
	"workbench_node": {"branch": "istasyonlar", "prereq": "research_basics",
			"cost": {"wood": 6}, "unlocks": ["workbench"], "hidden": false},
	"furnace_node": {"branch": "istasyonlar", "prereq": "workbench_node",
			"cost": {"stone": 10, "clay": 4},
			"unlocks": ["furnace"], "hidden": false},  # K2 KAVSAGI
	"farming_basics": {"branch": "muhendislik", "prereq": "workbench_node",
			"cost": {"wood": 4, "stone": 2},
			"unlocks": ["hoe", "watering_pot"], "hidden": false},
	"brick_making": {"branch": "istasyonlar", "prereq": "furnace_node",
			"cost": {"clay": 6}, "unlocks": ["brick", "brick_wall"],
			"hidden": true, "reveal_trigger_item": "clay"},
	"essence_tech": {"branch": "insaat", "prereq": "furnace_node",
			"cost": {"essence": 2, "glass": 2},
			"unlocks": ["essence_lamp", "fire_trench"],
			"hidden": true, "reveal_trigger_item": "essence"},
}

var unlocked: Dictionary = {}  # node_id -> true
var revealed: Dictionary = {}  # gizli node_id -> true (gorunur oldu)

# Tarif -> onu aciklayan dugum(ler). Bir dugumde gecmeyen tarif serbesttir.
var _governed: Dictionary = {}

func _ready() -> void:
	for node_id in NODES:
		for recipe_id in NODES[node_id]["unlocks"]:
			if not _governed.has(recipe_id):
				_governed[recipe_id] = []
			_governed[recipe_id].append(node_id)
	_load()
	# Kok dugum her zaman acik
	unlocked["research_basics"] = true

## --- Sorgular -----------------------------------------------------------

func is_unlocked(node_id: String) -> bool:
	return unlocked.has(node_id)

## Dugum agacda su an GORUNUR mu? (gizliyse tetiklenmis olmali)
func is_visible(node_id: String) -> bool:
	if not NODES.has(node_id):
		return false
	if not NODES[node_id].get("hidden", false):
		return true
	return revealed.has(node_id) or unlocked.has(node_id)

## Bu tarif su an craftlanabilir mi (arastirma acisindan)?
func is_recipe_unlocked(recipe_id: String) -> bool:
	if not _governed.has(recipe_id):
		return true  # hicbir dugume bagli degil: serbest (eski tarifler)
	for node_id in _governed[recipe_id]:
		if unlocked.has(node_id):
			return true
	return false

func can_research(node_id: String) -> bool:
	if not NODES.has(node_id) or unlocked.has(node_id):
		return false
	if not is_visible(node_id):
		return false
	var node: Dictionary = NODES[node_id]
	var prereq: String = node["prereq"]
	if prereq != "" and not unlocked.has(prereq):
		return false
	var cost: Dictionary = node["cost"]
	for item_id in cost:
		if Inventory.get_count(item_id) < cost[item_id]:
			return false
	return true

## --- Islemler -------------------------------------------------------------

## Dugumu satin al: maliyeti envanterden dus, tarifleri ac.
## (Arastirma Masasi yakinlik sarti UI milestone'unda eklenecek.)
func do_research(node_id: String) -> bool:
	if not can_research(node_id):
		return false
	var cost: Dictionary = NODES[node_id]["cost"]
	for item_id in cost:
		Inventory.remove_item(item_id, cost[item_id])
	unlocked[node_id] = true
	_save()
	changed.emit()
	return true

## Envantere yeni esya girdiginde cagrilir: gizli dugumleri tetikler
func notify_item_collected(item_id: String) -> void:
	var any_new := false
	for node_id in NODES:
		var node: Dictionary = NODES[node_id]
		if node.get("hidden", false) and not revealed.has(node_id) \
				and node.get("reveal_trigger_item", "") == item_id:
			revealed[node_id] = true
			any_new = true
	if any_new:
		_save()
		changed.emit()

func reset() -> void:
	unlocked = {"research_basics": true}
	revealed = {}
	_save()
	changed.emit()

## --- Test / hata ayiklama --------------------------------------------------

## Dugumun maliyetini bedava verip arastirir (denemek icin).
## Ornek: Research.debug_research("stone_tools")
func debug_research(node_id: String) -> bool:
	if not NODES.has(node_id):
		push_warning("Bilinmeyen dugum: " + node_id)
		return false
	for item_id in NODES[node_id]["cost"]:
		Inventory.add_item(item_id, NODES[node_id]["cost"][item_id])
	var ok := do_research(node_id)
	print("[Research] %s -> %s | acik dugumler: %s"
			% [node_id, "ACILDI" if ok else "ACILAMADI", unlocked.keys()])
	return ok

func debug_print_state() -> void:
	print("[Research] acik: ", unlocked.keys())
	print("[Research] gorunen gizli: ", revealed.keys())
	for node_id in NODES:
		print("  %s%s | arastirilabilir: %s" % [node_id,
				" (gizli)" if NODES[node_id].get("hidden", false) else "",
				can_research(node_id)])

## --- Kayit ------------------------------------------------------------------
## Tek çatı (SaveManager) için veri tabanlı çift. Eski research.json self-save
## korunur (anlık kalıcılık); yüklemede tek kaynak SaveManager verisidir.

func to_save_data() -> Dictionary:
	return {"unlocked": unlocked.keys(), "revealed": revealed.keys()}

func from_save_data(data: Dictionary) -> void:
	unlocked.clear()
	revealed.clear()
	for node_id in data.get("unlocked", []):
		unlocked[String(node_id)] = true
	for node_id in data.get("revealed", []):
		revealed[String(node_id)] = true
	changed.emit()

func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({
			"unlocked": unlocked.keys(), "revealed": revealed.keys()}))

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		for node_id in parsed.get("unlocked", []):
			unlocked[node_id] = true
		for node_id in parsed.get("revealed", []):
			revealed[node_id] = true
