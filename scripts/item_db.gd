extends RefCounted
## GDD VERI KATMANI - Esya katalogu (GAME_DESIGN.md Bolum 1-8).
##
## Yeni esya eklemek icin: GAME_DESIGN.md'ye satir ekle, sonra buraya
## ayni id ile bir kayit ekle. Ikon: assets/items/<id>.png varsa o
## kullanilir, yoksa placeholder (icon() yardimcisi halleder).
##
## NOT: "water" bilerek YOK - GDD geregi esya degil hacimdir (kova ile
## tasinir); su sistemi ileriki milestone.
## NOT: "moat" (su hendegi) esya degil mekaniktir (kazi + su), listede yok.

const PLACEHOLDER_ICON := "res://assets/items/placeholder.png"

## Kategoriler: resource, tool, weapon, station, trap, structure,
## farming, engineering
const CATEGORIES: Array[String] = ["resource", "tool", "weapon", "station",
		"trap", "structure", "farming", "engineering"]

## Alet kademeleri (dusukten yukseye)
const TIER_ORDER: Array[String] = ["stone", "copper", "iron", "steel"]

const ITEMS: Dictionary = {
	# --- Katman 0: elle toplanir -----------------------------------------
	"stick": {"name": "Dal", "max_stack": 64, "category": "resource", "tier": 0},
	"pebble": {"name": "Çakıl Taşı", "max_stack": 64, "category": "resource", "tier": 0},
	"fiber": {"name": "Bitki Lifi", "max_stack": 64, "category": "resource", "tier": 0},
	"clay": {"name": "Kil", "max_stack": 64, "category": "resource", "tier": 0},
	"berry": {"name": "Yaban Meyvesi", "max_stack": 32, "category": "resource", "tier": 0},
	# --- Katman 1: tas aletlerle ------------------------------------------
	"wood": {"name": "Odun", "max_stack": 64, "category": "resource", "tier": 1},
	"stone": {"name": "Taş", "max_stack": 64, "category": "resource", "tier": 1},
	"sand": {"name": "Kum", "max_stack": 64, "category": "resource", "tier": 1},
	"hide": {"name": "Deri", "max_stack": 32, "category": "resource", "tier": 1},
	"raw_meat": {"name": "Çiğ Et", "max_stack": 32, "category": "resource", "tier": 1},
	# --- Katman 2: firin cagi ----------------------------------------------
	"coal": {"name": "Kömür", "max_stack": 64, "category": "resource", "tier": 2},
	"copper_ore": {"name": "Bakır Cevheri", "max_stack": 64, "category": "resource", "tier": 2},
	"copper_ingot": {"name": "Bakır Külçe", "max_stack": 64, "category": "resource", "tier": 2},
	"brick": {"name": "Tuğla", "max_stack": 64, "category": "resource", "tier": 2},
	"glass": {"name": "Cam", "max_stack": 64, "category": "resource", "tier": 2},
	# --- Katman 3: demir cagi ----------------------------------------------
	"iron_ore": {"name": "Demir Cevheri", "max_stack": 64, "category": "resource", "tier": 3},
	"iron_ingot": {"name": "Demir Külçe", "max_stack": 64, "category": "resource", "tier": 3},
	"steel": {"name": "Çelik", "max_stack": 64, "category": "resource", "tier": 3},
	"metal_part": {"name": "Metal Parça", "max_stack": 64, "category": "resource", "tier": 3},
	# --- Ozel ----------------------------------------------------------------
	"essence": {"name": "Yaratık Özü", "max_stack": 32, "category": "resource", "tier": 2},
	"rope": {"name": "İp", "max_stack": 64, "category": "resource", "tier": 0},
	"cooked_meat": {"name": "Pişmiş Et", "max_stack": 32, "category": "resource", "tier": 1},
	"seed": {"name": "Tohum", "max_stack": 64, "category": "resource", "tier": 0},
	# --- Aletler: {kademe}_{alet}, hepsi max_stack 1 -----------------------
	"stone_axe": {"name": "Taş Balta", "max_stack": 1, "category": "tool"},
	"stone_pickaxe": {"name": "Taş Kazma", "max_stack": 1, "category": "tool"},
	"stone_shovel": {"name": "Taş Kürek", "max_stack": 1, "category": "tool"},
	"stone_knife": {"name": "Taş Bıçak", "max_stack": 1, "category": "tool"},
	"stone_hammer": {"name": "Taş Çekiç", "max_stack": 1, "category": "tool"},
	"copper_axe": {"name": "Bakır Balta", "max_stack": 1, "category": "tool"},
	"copper_pickaxe": {"name": "Bakır Kazma", "max_stack": 1, "category": "tool"},
	"copper_shovel": {"name": "Bakır Kürek", "max_stack": 1, "category": "tool"},
	"copper_knife": {"name": "Bakır Bıçak", "max_stack": 1, "category": "tool"},
	"copper_hammer": {"name": "Bakır Çekiç", "max_stack": 1, "category": "tool"},
	"iron_axe": {"name": "Demir Balta", "max_stack": 1, "category": "tool"},
	"iron_pickaxe": {"name": "Demir Kazma", "max_stack": 1, "category": "tool"},
	"iron_shovel": {"name": "Demir Kürek", "max_stack": 1, "category": "tool"},
	"iron_knife": {"name": "Demir Bıçak", "max_stack": 1, "category": "tool"},
	"iron_hammer": {"name": "Demir Çekiç", "max_stack": 1, "category": "tool"},
	"steel_axe": {"name": "Çelik Balta", "max_stack": 1, "category": "tool"},
	"steel_pickaxe": {"name": "Çelik Kazma", "max_stack": 1, "category": "tool"},
	"steel_shovel": {"name": "Çelik Kürek", "max_stack": 1, "category": "tool"},
	"steel_knife": {"name": "Çelik Bıçak", "max_stack": 1, "category": "tool"},
	"steel_hammer": {"name": "Çelik Çekiç", "max_stack": 1, "category": "tool"},
	"bucket": {"name": "Kova (Ahşap)", "max_stack": 1, "category": "tool"},
	"metal_bucket": {"name": "Metal Kova", "max_stack": 1, "category": "tool"},
	# --- Silahlar -----------------------------------------------------------
	"club": {"name": "Sopa", "max_stack": 1, "category": "weapon"},
	"spear": {"name": "Mızrak", "max_stack": 1, "category": "weapon"},
	"sling": {"name": "Sapan", "max_stack": 1, "category": "weapon"},
	"bow": {"name": "Yay", "max_stack": 1, "category": "weapon"},
	"arrow": {"name": "Ok", "max_stack": 32, "category": "weapon"},
	"steel_sword": {"name": "Çelik Kılıç", "max_stack": 1, "category": "weapon"},
	# --- Istasyonlar ----------------------------------------------------------
	"campfire": {"name": "Kamp Ateşi", "max_stack": 8, "category": "station"},
	"workbench": {"name": "Çalışma Masası", "max_stack": 8, "category": "station"},
	"research_table": {"name": "Araştırma Masası", "max_stack": 8, "category": "station"},
	"furnace": {"name": "Fırın", "max_stack": 8, "category": "station"},
	"tannery": {"name": "Tabakhane", "max_stack": 8, "category": "station"},
	"anvil": {"name": "Örs", "max_stack": 8, "category": "station"},
	"blast_furnace": {"name": "Yüksek Fırın", "max_stack": 8, "category": "station"},
	# --- Tuzaklar ---------------------------------------------------------------
	"spikes": {"name": "Sivri Kazıklar", "max_stack": 8, "category": "trap"},
	"pit_trap": {"name": "Çukur Tuzağı", "max_stack": 8, "category": "trap"},
	"trip_alarm": {"name": "İp Alarmı", "max_stack": 8, "category": "trap"},
	"log_crusher": {"name": "Ezici Kütük", "max_stack": 8, "category": "trap"},
	"fire_trench": {"name": "Alev Hendeği", "max_stack": 8, "category": "trap"},
	"essence_lamp": {"name": "Öz Lambası", "max_stack": 8, "category": "trap"},
	# --- Yapilar -----------------------------------------------------------------
	"wood_wall": {"name": "Ahşap Duvar", "max_stack": 16, "category": "structure"},
	"wood_door": {"name": "Ahşap Kapı", "max_stack": 16, "category": "structure"},
	"fence": {"name": "Çit", "max_stack": 16, "category": "structure"},
	"stone_wall": {"name": "Taş Duvar", "max_stack": 16, "category": "structure"},
	"brick_wall": {"name": "Tuğla Sur", "max_stack": 16, "category": "structure"},
	"window": {"name": "Pencere", "max_stack": 16, "category": "structure"},
	"steel_door": {"name": "Çelik Kapı", "max_stack": 16, "category": "structure"},
	"torch": {"name": "Meşale", "max_stack": 32, "category": "structure"},
	# --- Tarim --------------------------------------------------------------------
	"hoe": {"name": "Çapa", "max_stack": 1, "category": "farming"},
	"watering_pot": {"name": "Sulama Kabı", "max_stack": 1, "category": "farming"},
	"compost_bin": {"name": "Kompost Fıçısı", "max_stack": 8, "category": "farming"},
	"scarecrow": {"name": "Bostan Korkuluğu", "max_stack": 8, "category": "farming"},
	"irrigation_pipe": {"name": "Sulama Borusu", "max_stack": 16, "category": "farming"},
	# --- Muhendislik + su -------------------------------------------------------
	"pipe": {"name": "Boru", "max_stack": 16, "category": "engineering"},
	"pump": {"name": "Pompa", "max_stack": 8, "category": "engineering"},
	"valve": {"name": "Vana", "max_stack": 16, "category": "engineering"},
}

## Eski (Turkce id'li) oyun esyalari ile GDD id'lerinin karsiligi.
## Ileriki "migrasyon" milestone'unda dunya/tarifler bu tabloya gore
## yeni id'lere gecirilecek; su an iki katalog yan yana yasar.
const LEGACY_MAP: Dictionary = {
	"odun": "wood",
	"tas": "stone",
	"kum": "sand",
	"komur": "coal",
	"ip": "rope",
	"cubuk": "stick",
	"meyve": "berry",
	"tohum": "seed",
	"balta": "stone_axe",
	"kazma": "stone_pickaxe",
	"kurek": "stone_shovel",
	"mizrak": "spear",
	"tezgah": "workbench",
	"ahsap_duvar": "wood_wall",
	"tas_duvar": "stone_wall",
	"kapi": "wood_door",
	"tuzak": "spikes",
}

static func has_item(id: String) -> bool:
	return ITEMS.has(id)

static func display_name(id: String) -> String:
	if ITEMS.has(id):
		return ITEMS[id]["name"]
	return id

static func max_stack(id: String) -> int:
	if ITEMS.has(id):
		return ITEMS[id]["max_stack"]
	return 64

static func category(id: String) -> String:
	if ITEMS.has(id):
		return ITEMS[id]["category"]
	return "resource"

## Ikon yolu: ozel ikon varsa onu, yoksa placeholder dondurur
static func icon(id: String) -> String:
	var path := "res://assets/items/%s.png" % id
	if ResourceLoader.exists(path):
		return path
	return PLACEHOLDER_ICON

## "{kademe}_{alet}" cozumleme: "copper_pickaxe" -> ["copper", "pickaxe"].
## Kademeli olmayan idlerde bos dizi doner.
static func parse_tiered_tool(id: String) -> Array:
	var sep := id.find("_")
	if sep <= 0:
		return []
	var tier := id.substr(0, sep)
	if not tier in TIER_ORDER:
		return []
	return [tier, id.substr(sep + 1)]
