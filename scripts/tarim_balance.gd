extends RefCounted
## TARIM DENGE SAYILARI — tek dogruluk kaynagi (survival_balance ailesi).
## Referans tasarim: kokteki farming_system.gd. Yeni urun eklemek =
## CROPS'a satir eklemek.

## Bos tarla kac gunde cime doner (bakimsizlik)
const TILLED_DECAY_DAYS := 3
## Hasatta tohum iade sansi
const SEED_RETURN_CHANCE := 0.6
## Sulama kabinin deposu (kac sulama)
const WATERING_CAN_USES := 4

## Bitki tanimlari. stages: evre sayisi (filiz=0 ... olgun=stages-1).
## seed_item/yield_item: envanterdeki GERCEK item id'leri (Turkce katalog).
const CROPS := {
	"berry_bush": {
		"name": "Yaban Meyvesi",
		"seed_item": "tohum",
		"stages": 3,
		"yield_item": "meyve",
		"yield_min": 2, "yield_max": 3,
	},
}

## Zemin renkleri (world3d._cell_props tarafindan okunur; GROUND char yok)
const TILLED_COLOR := Color(0.36, 0.24, 0.13)      # surulu kuru toprak
const TILLED_WET_COLOR := Color(0.25, 0.165, 0.10) # sulanmis (koyu/islak)
const TILLED_TOP := -0.03                          # hafif cukur his

## Ses kancalari (calar HENUZ yok — veri hazir, RAPOR/DURUM notu)
const SFX := {"till": "dig_dirt", "plant": "plant_seed",
		"water": "water_pour", "fill": "water_fill", "harvest": "harvest_pop"}
