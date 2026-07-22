extends RefCounted
## GDD VERI KATMANI - Tarif katalogu (GAME_DESIGN.md Bolum 2-8).
##
## Format: id -> {"result": esya, "count": adet, "materials": {id: adet},
##                "station": ""|istasyon_id}
## station "" = elde uretilir. Yeni tarif eklemek icin GAME_DESIGN.md'ye
## yaz, buraya ayni kaliba bir kayit ekle (id genelde sonucla ayni).
##
## TASLAK NOTU: GDD alet TARIFLERINI acikca vermiyor (sadece kademeleri).
## Asagidaki alet tarifleri kalibi izleyen taslaklardir; denge testi
## sonrasi GAME_DESIGN.md'ye islenip burasi guncellenecek. Ayni sekilde
## "fire_trench" tarifindeki cakmaktasi henuz katalogda olmadigi icin
## yerine stone kondu, eritme tariflerine yakit olarak coal eklendi
## (yakit sistemi ileriki milestone'da ayrisabilir).

const RECIPES: Dictionary = {
	# --- Ara urunler / ozel ---------------------------------------------
	"rope": {"result": "rope", "count": 1,
			"materials": {"fiber": 3}, "station": ""},
	"cooked_meat": {"result": "cooked_meat", "count": 1,
			"materials": {"raw_meat": 1}, "station": "campfire"},
	# --- Eritme (firin cagi) ----------------------------------------------
	"copper_ingot": {"result": "copper_ingot", "count": 1,
			"materials": {"copper_ore": 1, "coal": 1}, "station": "furnace"},
	"brick": {"result": "brick", "count": 1,
			"materials": {"clay": 2, "coal": 1}, "station": "furnace"},
	"glass": {"result": "glass", "count": 1,
			"materials": {"sand": 2, "coal": 1}, "station": "furnace"},
	"iron_ingot": {"result": "iron_ingot", "count": 1,
			"materials": {"iron_ore": 1, "coal": 1}, "station": "furnace"},
	"steel": {"result": "steel", "count": 1,
			"materials": {"iron_ingot": 1, "coal": 2}, "station": "blast_furnace"},
	"metal_part": {"result": "metal_part", "count": 1,
			"materials": {"iron_ingot": 1}, "station": "anvil"},
	# --- Aletler (taslak tarifler; kalip: sap + kademe malzemesi) ---------
	"stone_axe": {"result": "stone_axe", "count": 1,
			"materials": {"stick": 2, "stone": 3, "rope": 1}, "station": "workbench"},
	"stone_pickaxe": {"result": "stone_pickaxe", "count": 1,
			"materials": {"stick": 2, "stone": 3, "rope": 1}, "station": "workbench"},
	"stone_shovel": {"result": "stone_shovel", "count": 1,
			"materials": {"stick": 2, "stone": 2, "rope": 1}, "station": "workbench"},
	"stone_knife": {"result": "stone_knife", "count": 1,
			"materials": {"stick": 1, "stone": 2, "rope": 1}, "station": "workbench"},
	"stone_hammer": {"result": "stone_hammer", "count": 1,
			"materials": {"stick": 2, "stone": 3, "rope": 1}, "station": "workbench"},
	"copper_axe": {"result": "copper_axe", "count": 1,
			"materials": {"stick": 2, "copper_ingot": 2}, "station": "workbench"},
	"copper_pickaxe": {"result": "copper_pickaxe", "count": 1,
			"materials": {"stick": 2, "copper_ingot": 2}, "station": "workbench"},
	"copper_shovel": {"result": "copper_shovel", "count": 1,
			"materials": {"stick": 2, "copper_ingot": 2}, "station": "workbench"},
	"copper_knife": {"result": "copper_knife", "count": 1,
			"materials": {"stick": 1, "copper_ingot": 2}, "station": "workbench"},
	"copper_hammer": {"result": "copper_hammer", "count": 1,
			"materials": {"stick": 2, "copper_ingot": 2}, "station": "workbench"},
	"iron_axe": {"result": "iron_axe", "count": 1,
			"materials": {"stick": 2, "iron_ingot": 2}, "station": "anvil"},
	"iron_pickaxe": {"result": "iron_pickaxe", "count": 1,
			"materials": {"stick": 2, "iron_ingot": 2}, "station": "anvil"},
	"iron_shovel": {"result": "iron_shovel", "count": 1,
			"materials": {"stick": 2, "iron_ingot": 2}, "station": "anvil"},
	"iron_knife": {"result": "iron_knife", "count": 1,
			"materials": {"stick": 1, "iron_ingot": 2}, "station": "anvil"},
	"iron_hammer": {"result": "iron_hammer", "count": 1,
			"materials": {"stick": 2, "iron_ingot": 2}, "station": "anvil"},
	"steel_axe": {"result": "steel_axe", "count": 1,
			"materials": {"stick": 2, "steel": 2}, "station": "anvil"},
	"steel_pickaxe": {"result": "steel_pickaxe", "count": 1,
			"materials": {"stick": 2, "steel": 2}, "station": "anvil"},
	"steel_shovel": {"result": "steel_shovel", "count": 1,
			"materials": {"stick": 2, "steel": 2}, "station": "anvil"},
	"steel_knife": {"result": "steel_knife", "count": 1,
			"materials": {"stick": 1, "steel": 2}, "station": "anvil"},
	"steel_hammer": {"result": "steel_hammer", "count": 1,
			"materials": {"stick": 2, "steel": 2}, "station": "anvil"},
	# --- Silahlar (GDD tarifleri) -------------------------------------------
	"club": {"result": "club", "count": 1,
			"materials": {"stick": 2, "rope": 1}, "station": ""},
	"spear": {"result": "spear", "count": 1,
			"materials": {"stick": 2, "stone": 1, "rope": 1}, "station": "workbench"},
	"sling": {"result": "sling", "count": 1,
			"materials": {"rope": 2, "hide": 1}, "station": "workbench"},
	"bow": {"result": "bow", "count": 1,
			"materials": {"wood": 3, "rope": 2}, "station": "workbench"},
	"arrow": {"result": "arrow", "count": 4,
			"materials": {"stick": 1, "fiber": 1, "pebble": 1}, "station": "workbench"},
	"steel_sword": {"result": "steel_sword", "count": 1,
			"materials": {"steel": 2, "wood": 1, "hide": 1}, "station": "anvil"},
	# --- Istasyonlar (GDD tarifleri) ------------------------------------------
	"campfire": {"result": "campfire", "count": 1,
			"materials": {"stick": 5, "pebble": 3}, "station": ""},
	"workbench": {"result": "workbench", "count": 1,
			"materials": {"wood": 8}, "station": ""},
	"research_table": {"result": "research_table", "count": 1,
			"materials": {"wood": 6, "stone": 4, "rope": 2}, "station": ""},
	"furnace": {"result": "furnace", "count": 1,
			"materials": {"stone": 10, "clay": 4}, "station": "workbench"},
	"tannery": {"result": "tannery", "count": 1,
			"materials": {"wood": 6, "hide": 4}, "station": "workbench"},
	"anvil": {"result": "anvil", "count": 1,
			"materials": {"iron_ingot": 4}, "station": "workbench"},
	"blast_furnace": {"result": "blast_furnace", "count": 1,
			"materials": {"brick": 12, "metal_part": 4}, "station": "workbench"},
	# --- Tuzaklar (GDD tarifleri; moat esya degil, tarifsiz) --------------------
	"spikes": {"result": "spikes", "count": 1,
			"materials": {"wood": 4, "rope": 2}, "station": "workbench"},
	"pit_trap": {"result": "pit_trap", "count": 1,
			"materials": {"stick": 6}, "station": ""},
	"trip_alarm": {"result": "trip_alarm", "count": 1,
			"materials": {"rope": 2, "stone": 1}, "station": ""},
	"log_crusher": {"result": "log_crusher", "count": 1,
			"materials": {"wood": 2, "rope": 4, "metal_part": 1}, "station": "workbench"},
	"fire_trench": {"result": "fire_trench", "count": 1,
			"materials": {"brick": 4, "coal": 2, "stone": 1}, "station": "workbench"},
	"essence_lamp": {"result": "essence_lamp", "count": 1,
			"materials": {"glass": 2, "essence": 3}, "station": "workbench"},
	# --- Yapilar (GDD tarifleri) ---------------------------------------------
	"wood_wall": {"result": "wood_wall", "count": 1,
			"materials": {"wood": 4}, "station": "workbench"},
	"wood_door": {"result": "wood_door", "count": 1,
			"materials": {"wood": 6}, "station": "workbench"},
	"fence": {"result": "fence", "count": 1,
			"materials": {"wood": 2, "rope": 1}, "station": "workbench"},
	"stone_wall": {"result": "stone_wall", "count": 1,
			"materials": {"stone": 4}, "station": "workbench"},
	"brick_wall": {"result": "brick_wall", "count": 1,
			"materials": {"brick": 4}, "station": "workbench"},
	"window": {"result": "window", "count": 1,
			"materials": {"wood": 2, "glass": 1}, "station": "workbench"},
	"steel_door": {"result": "steel_door", "count": 1,
			"materials": {"steel": 2, "metal_part": 1}, "station": "anvil"},
	"torch": {"result": "torch", "count": 2,
			"materials": {"stick": 1, "coal": 1}, "station": ""},
	# Cati (Ev/Cati paketi): "Cati Ustaligi" (roof_mastery) dugumu acar
	"wood_roof": {"result": "wood_roof", "count": 1,
			"materials": {"wood": 4}, "station": "workbench"},
	"brick_roof": {"result": "brick_roof", "count": 1,
			"materials": {"brick": 3}, "station": "workbench"},
	# --- Tarim (GDD tarifleri) ---------------------------------------------------
	"hoe": {"result": "hoe", "count": 1,
			"materials": {"stick": 2, "stone": 2, "rope": 1}, "station": "workbench"},
	"watering_pot": {"result": "watering_pot", "count": 1,
			"materials": {"clay": 3}, "station": "furnace"},
	"compost_bin": {"result": "compost_bin", "count": 1,
			"materials": {"wood": 6, "rope": 2}, "station": "workbench"},
	"scarecrow": {"result": "scarecrow", "count": 1,
			"materials": {"stick": 4, "hide": 1, "fiber": 2}, "station": "workbench"},
	"irrigation_pipe": {"result": "irrigation_pipe", "count": 1,
			"materials": {"metal_part": 2}, "station": "anvil"},
	# --- Muhendislik + su (GDD tarifleri) ----------------------------------------
	"bucket": {"result": "bucket", "count": 1,
			"materials": {"wood": 4, "rope": 1}, "station": "workbench"},
	"metal_bucket": {"result": "metal_bucket", "count": 1,
			"materials": {"metal_part": 2}, "station": "anvil"},
	"pipe": {"result": "pipe", "count": 1,
			"materials": {"metal_part": 1}, "station": "anvil"},
	"pump": {"result": "pump", "count": 1,
			"materials": {"metal_part": 3, "copper_ingot": 1}, "station": "anvil"},
	"valve": {"result": "valve", "count": 1,
			"materials": {"metal_part": 1}, "station": "anvil"},
}

static func has_recipe(id: String) -> bool:
	return RECIPES.has(id)

static func get_recipe(id: String) -> Dictionary:
	return RECIPES.get(id, {})

## Bir istasyonda uretilebilen tariflerin listesi ("" = elde)
static func recipes_for_station(station: String) -> Array[String]:
	var out: Array[String] = []
	for id in RECIPES:
		if RECIPES[id]["station"] == station:
			out.append(id)
	return out
