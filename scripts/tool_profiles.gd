extends RefCounted
## ALET/SILAH EYLEM PROFILLERI (ALET_SISTEMI.md 12.3).
## Sistemin kalbi: her alet uc fazli (windup -> strike -> recover) ve
## ETKI daima strike aninda uygulanir. Denge/his ayari TEK bu dosyadan.
##
## Poz alanlari pivot'un (ToolPivot) yerel Euler donusu (derece) ve
## opsiyonel z-itisi; player3d bunlari Tween ile oynatir.
##   rest   : dinlenme pozu (elde dururken)
##   wind   : hazirlik sonu pozu (geri cekilmis)
##   hit    : vurus pozu (etki ani)
##   push_z : ileri saplama mesafesi (mizrak); 0 = donme tabanli
## kind: "chop"/"mine"/"dig"/"pile"/"harvest"/"repair"/"scoop"/"pour"/"melee"
## is_weapon: saldiri butonu gorunur + hedefsiz sallanabilir
## ranged: ""/"spear"/"sling"/"bow" (Asama 5)

const PROFILES := {
	# --- Aletler ---
	"balta": {
		"windup": 0.18, "strike": 0.10, "recover": 0.22,
		"rest": Vector3(0, 0, 0), "wind": Vector3(-70, 0, 35),
		"hit": Vector3(60, 0, -25), "push_z": 0.0,
		"kind": "chop", "reach": 1, "is_weapon": false,
		"swing_sfx": "swing_axe", "hit_sfx": "hit_wood", "break_sfx": "tree_fall",
	},
	"kazma": {
		"windup": 0.22, "strike": 0.10, "recover": 0.26,
		"rest": Vector3(0, 0, 0), "wind": Vector3(-95, 0, 0),
		"hit": Vector3(70, 0, 0), "push_z": 0.0,
		"kind": "mine", "reach": 1, "is_weapon": false,
		"swing_sfx": "swing_pick", "hit_sfx": "hit_stone", "break_sfx": "rock_break",
	},
	"kurek": {
		"windup": 0.16, "strike": 0.12, "recover": 0.22,
		"rest": Vector3(0, 0, 0), "wind": Vector3(-55, 0, 20),
		"hit": Vector3(55, 0, -10), "push_z": 0.10,
		"kind": "dig", "reach": 1, "is_weapon": false,
		"swing_sfx": "swing_soft", "hit_sfx": "dig_dirt", "break_sfx": "",
	},
	"bicak": {
		"windup": 0.08, "strike": 0.06, "recover": 0.12,
		"rest": Vector3(0, 0, 0), "wind": Vector3(0, -35, 20),
		"hit": Vector3(0, 45, -15), "push_z": 0.0,
		"kind": "harvest", "reach": 1, "is_weapon": true, "damage": 8,
		"swing_sfx": "swing_fast", "hit_sfx": "hit_flesh", "break_sfx": "",
	},
	"cekic": {
		"windup": 0.20, "strike": 0.10, "recover": 0.30,
		"rest": Vector3(0, 0, 0), "wind": Vector3(-30, -50, 0),
		"hit": Vector3(20, 40, 0), "push_z": 0.0,
		"kind": "repair", "reach": 1, "is_weapon": false,
		"swing_sfx": "swing_heavy", "hit_sfx": "hit_wood", "break_sfx": "",
	},
	# --- Yakin dovus silahlari ---
	"sopa": {
		"windup": 0.16, "strike": 0.10, "recover": 0.24,
		"rest": Vector3(0, 0, 0), "wind": Vector3(0, -55, 0),
		"hit": Vector3(0, 55, 0), "push_z": 0.0,
		"kind": "melee", "reach": 1, "is_weapon": true, "damage": 12,
		"swing_sfx": "swing_wood", "hit_sfx": "hit_thud", "break_sfx": "",
	},
	"mizrak": {
		"windup": 0.14, "strike": 0.08, "recover": 0.20,
		"rest": Vector3(0, 0, 0), "wind": Vector3(0, 0, 0),
		"hit": Vector3(0, 0, 0), "push_z": 0.7,
		"kind": "melee", "reach": 2, "is_weapon": true, "damage": 20,
		"ranged": "spear",
		"swing_sfx": "swing_thrust", "hit_sfx": "hit_flesh", "break_sfx": "",
	},
	"kilic": {
		"windup": 0.12, "strike": 0.10, "recover": 0.18,
		"rest": Vector3(0, 0, 0), "wind": Vector3(0, -70, 10),
		"hit": Vector3(0, 65, -10), "push_z": 0.0,
		"kind": "melee", "reach": 1, "is_weapon": true, "damage": 18,
		"combo": true,
		"swing_sfx": "swing_blade", "hit_sfx": "hit_slash", "break_sfx": "",
	},
	# --- Menzilli silahlar (Asama 5) ---
	"sapan": {
		"windup": 0.10, "strike": 0.08, "recover": 0.20,
		"rest": Vector3(0, 0, 0), "wind": Vector3(-20, 0, 0),
		"hit": Vector3(20, 0, 0), "push_z": 0.0,
		"kind": "melee", "reach": 1, "is_weapon": true, "damage": 6,
		"ranged": "sling", "ammo": "cakil",
		"swing_sfx": "sling_whirl", "hit_sfx": "hit_thud", "break_sfx": "",
	},
	"yay": {
		"windup": 0.10, "strike": 0.08, "recover": 0.18,
		"rest": Vector3(0, 0, 0), "wind": Vector3(0, -20, 0),
		"hit": Vector3(0, 10, 0), "push_z": 0.0,
		"kind": "melee", "reach": 1, "is_weapon": true, "damage": 10,
		"ranged": "bow", "ammo": "ok",
		"swing_sfx": "bow_draw", "hit_sfx": "hit_thud", "break_sfx": "",
	},
	# --- Su (11.2 baglama) ---
	"kova": {
		"windup": 0.10, "strike": 0.10, "recover": 0.16,
		"rest": Vector3(0, 0, 0), "wind": Vector3(-25, 0, 15),
		"hit": Vector3(30, 0, -10), "push_z": 0.0,
		"kind": "scoop", "reach": 1, "is_weapon": false,
		"swing_sfx": "swing_soft", "hit_sfx": "water_scoop", "break_sfx": "",
	},
	"kova_dolu": {
		"windup": 0.10, "strike": 0.10, "recover": 0.16,
		"rest": Vector3(0, 0, 0), "wind": Vector3(-25, 0, 15),
		"hit": Vector3(30, 0, -10), "push_z": 0.0,
		"kind": "pour", "reach": 1, "is_weapon": false,
		"swing_sfx": "swing_soft", "hit_sfx": "water_pour", "break_sfx": "",
	},
	# --- Toprak yigma (item elde) ---
	"toprak": {
		"windup": 0.14, "strike": 0.10, "recover": 0.20,
		"rest": Vector3(0, 0, 0), "wind": Vector3(-40, 0, 10),
		"hit": Vector3(40, 0, -5), "push_z": 0.0,
		"kind": "pile", "reach": 1, "is_weapon": false,
		"swing_sfx": "swing_soft", "hit_sfx": "dig_dirt", "break_sfx": "",
	},
}

## Bos yumruk (elde alet yokken) — hafif whoosh, etkisiz.
const FIST := {
	"windup": 0.12, "strike": 0.08, "recover": 0.16,
	"rest": Vector3(0, 0, 0), "wind": Vector3(0, -30, 0),
	"hit": Vector3(0, 30, 0), "push_z": 0.0,
	"kind": "melee", "reach": 1, "is_weapon": false, "damage": 4,
	"swing_sfx": "swing_fist", "hit_sfx": "hit_thud", "break_sfx": "",
}

## ELE BAGLAMA (ATTACHMENT) OFSETLERI — kod DEGIL VERI.
## Aletin ToolPivot uzerindeki DURAGAN (rest) yerlesimi. Sallama pozlari
## (rest/wind/hit) pivot'u dondurur; bu ofsetler gorseli pivot icinde
## konumlar/dondurur/olcekler, yani sallama bunlarin USTUNE biner.
##   pos   : pivot'a gore yerel konum (m)
##   rot   : yerel Euler donus (derece)
##   scale : normalize boyut uzerine ek carpan
##   size  : dunya boyu hedefi — gorselin en uzun ekseni (m)
## ATTACH_DEFAULT mevcut gorunumu birebir korur (size 0.5, ofset yok).
##
## >>> YENI KARAKTER (Meshy/GLB) GELINCE: el hizalamasini KOD degil BURAYI
## >>> (ATTACH / ATTACH_DEFAULT) duzenleyerek yap. player3d'ye dokunma. <<<
const ATTACH_DEFAULT := {
	"pos": Vector3.ZERO,
	"rot": Vector3.ZERO,
	"scale": 1.0,
	"size": 0.5,
}

const ATTACH := {
	# Uzun saplama silahi: daha uzun gorunsun.
	"mizrak": {"size": 0.95},
	# Yay elde yana degil ONE baksin (kabaca).
	"yay": {"rot": Vector3(0, 90, 0), "size": 0.55},
	# Kucuk el aletleri.
	"sapan": {"size": 0.32},
	"bicak": {"size": 0.34},
}

## Bir esyanin ele baglama ofseti (ATTACH_DEFAULT + varsa esya ozel alanlari).
static func get_attachment(item_id: String) -> Dictionary:
	var d := ATTACH_DEFAULT.duplicate()
	var override: Dictionary = ATTACH.get(item_id, {})
	for k in override:
		d[k] = override[k]
	return d

## Alet kademesi sure carpani (12.3): her kademe windup+recover'i %8 kirpar.
## Su an tek kademe var; ust kademeler geldiginde tier>0 devreye girer.
static func tier_factor(tier: int) -> float:
	return pow(0.92, maxi(0, tier))

## Verilen esya id'sinin profili (yoksa FIST).
static func get_profile(item_id: String) -> Dictionary:
	return PROFILES.get(item_id, FIST)

## Bu esya bir silah mi? (saldiri butonu gorunurlugu)
static func is_weapon(item_id: String) -> bool:
	return bool(PROFILES.get(item_id, FIST).get("is_weapon", false))

## Menzilli tur ("" degilse basili-tut nisan modu)
static func ranged_kind(item_id: String) -> String:
	return String(PROFILES.get(item_id, {}).get("ranged", ""))
