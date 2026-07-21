extends RefCounted
## GDD VERI KATMANI - Alet -> kaynak eslesmesi (GAME_DESIGN.md Bolum 1-2).
## Su an sadece VERI: toplama mekanigi bu tabloyu ileriki milestone'da
## okuyacak. can_gather() mantigi hazir, dunyaya baglanmasi sonraki is.

const ItemDb = preload("res://scripts/item_db.gd")

## Kaynak -> hangi aletle toplanir.
## tool "": elle toplanir. "better_with": alet sart degil ama verimi artirir.
## min_tier: aletin en dusuk kademesi (ItemDb.TIER_ORDER sirasina gore).
const GATHER_RULES: Dictionary = {
	# Katman 0: elle
	"stick": {"tool": ""},
	"pebble": {"tool": ""},
	"fiber": {"tool": ""},
	"berry": {"tool": ""},
	"clay": {"tool": "", "better_with": "shovel"},
	# Katman 1: tas aletler
	"wood": {"tool": "axe", "min_tier": "stone"},
	"stone": {"tool": "pickaxe", "min_tier": "stone"},
	"sand": {"tool": "shovel", "min_tier": "stone"},
	"hide": {"tool": "knife", "min_tier": "stone"},
	"raw_meat": {"tool": ""},  # hayvandan; bicak yuzme bonusu hide icindir
	# Katman 2+: kazma kademeleri cevherleri acar
	"coal": {"tool": "pickaxe", "min_tier": "stone"},
	"copper_ore": {"tool": "pickaxe", "min_tier": "stone"},
	"iron_ore": {"tool": "pickaxe", "min_tier": "copper"},
}

## Kazma kademesi -> actigi yeni cevherler (ilerleme kurali: her katmanin
## kazmasi bir sonraki cevheri acar)
const PICKAXE_UNLOCKS: Dictionary = {
	"stone": ["coal", "copper_ore"],
	"copper": ["iron_ore"],
	"iron": [],
	"steel": [],
}

## Kademe ozel yetenekleri (GDD Bolum 2) - davranis kodu ileriki milestone
const TIER_PERKS: Dictionary = {
	"steel_axe": "tek vurusta agac",
	"iron_shovel": "3x3 alan kazma",
	"steel_knife": "oz verimi +%50",
	"iron_hammer": "uzaktan tamir",
	"metal_bucket": "sicak sivi tasima",
}

## a kademesi b'den dusuk degil mi? (orn. "iron" >= "stone" -> true)
static func tier_at_least(a: String, b: String) -> bool:
	return ItemDb.TIER_ORDER.find(a) >= ItemDb.TIER_ORDER.find(b)

## Eldeki alet bu kaynagi toplayabilir mi?
## tool_item_id: "" (bos el) veya "{kademe}_{alet}" (orn. "copper_pickaxe")
static func can_gather(resource_id: String, tool_item_id: String) -> bool:
	if not GATHER_RULES.has(resource_id):
		return true  # kurali olmayan kaynak serbest
	var rule: Dictionary = GATHER_RULES[resource_id]
	var needed_tool: String = rule.get("tool", "")
	if needed_tool == "":
		return true
	var parsed := ItemDb.parse_tiered_tool(tool_item_id)
	if parsed.is_empty() or parsed[1] != needed_tool:
		return false
	return tier_at_least(parsed[0], rule.get("min_tier", "stone"))
