extends RefCounted
## TARIM DENGE SAYILARI — tek dogruluk kaynagi (survival_balance ailesi).
## Referans tasarim: kokteki farming_system.gd. Yeni urun eklemek =
## CROPS'a satir eklemek.

## Bos tarla kac gunde cime doner (bakimsizlik)
const TILLED_DECAY_DAYS := 3
## Hasatta tohum iade sansi (VARSAYILAN — urun kendi degerini
## CROPS[..]["seed_return"] ile ezer; tarim-2 tablosu urun basina verdi)
const SEED_RETURN_CHANCE := 0.6
## Sulama kabinin deposu (kac sulama)
const WATERING_CAN_USES := 4

## Bitki tanimlari. stages: evre sayisi (filiz=0 ... olgun=stages-1).
## seed_item/yield_item: envanterdeki GERCEK item id'leri (Turkce katalog).
## TARIM-2 ALANLARI (gorev tablosu birebir):
##   nights: buyume geceleri (stages = nights + 1; evre 0 = filiz)
##   seed_return: hasatta tohum iade sansi
##   night_grow: YALNIZ GECE buyur (gunduz tick atlanir — korotu)
##   no_water: sulama istemez (mantar)
##   field_free: tarla gerekmez — los/golge hucreye ekilir (mantar;
##       basit kural: agac dibi ya da ic mekan = gun isigi azalmis)
##   spoil_immune: bozulmaz bayragi (ILERIYE donuk — bozulma sistemi yok)
##   bonus_drop: hasatta sansli ek esya {item, chance}
const CROPS := {
	"berry_bush": {
		"name": "Yaban Meyvesi",
		"seed_item": "tohum",
		"stages": 3, "nights": 2,
		"yield_item": "meyve",
		"yield_min": 2, "yield_max": 3,
		"seed_return": 0.6,
	},
	"earth_apple": {
		"name": "Toprak Elması",
		"seed_item": "tohum_elma",
		"stages": 4, "nights": 3,
		"yield_item": "toprak_elmasi",
		"yield_min": 2, "yield_max": 2,
		"seed_return": 0.6,
		"spoil_immune": true,
	},
	"golden_wheat": {
		"name": "Altınbaş",
		"seed_item": "tohum_bugday",
		"stages": 5, "nights": 4,
		"yield_item": "altinbas",   # CIG YENMEZ: FOOD_SATIATION'da yok
		"yield_min": 2, "yield_max": 2,
		"seed_return": 0.7,
	},
	"pumpkin": {
		"name": "Közkabağı",
		"seed_item": "tohum_kabak",
		"stages": 6, "nights": 5,
		"yield_item": "kozkabagi",
		"yield_min": 1, "yield_max": 1,
		"seed_return": 0.5,
		"bonus_drop": {"item": "pumpkin_decor", "chance": 0.3},
	},
	"korotu": {
		"name": "Korotu",
		"seed_item": "tohum_korotu",
		"stages": 4, "nights": 3,
		"yield_item": "korotu_cicek",
		"yield_min": 1, "yield_max": 1,
		"seed_return": 0.6,
		"night_grow": true,   # kimligi: yalniz gece buyur, gece parlar
	},
	"mist_mushroom": {
		"name": "Sis Mantarı",
		"seed_item": "tohum_mantar",
		"stages": 3, "nights": 2,
		"yield_item": "sis_mantari",
		"yield_min": 2, "yield_max": 2,
		"seed_return": 0.6,
		"no_water": true,
		"field_free": true,
	},
}

## Tohum esyasindan urun id'si (ekim akisi: eldeki tohum hangi urun?)
static func crop_of_seed(seed_item: String) -> String:
	for cid: String in CROPS:
		if String(CROPS[cid].seed_item) == seed_item:
			return cid
	return ""

## GLB KANCALARI (crops/ klasoru). TARIM-GLB-2: ILK UCLU GELDI —
## pumpkin(+decor), korotu_flower, earth_apple (dokulu Meshy, 1024'e
## indirildi). golden_wheat + mist_mushroom HENUZ YOK: dosya yoksa
## ayirt edilebilir proseduerel placeholder cizilir (fallback kurali;
## world3d._crop_placeholder).
const CROP_GLB_KANCA := {
	"earth_apple": "res://assets/models/crops/earth_apple.glb",
	"golden_wheat": "res://assets/models/crops/golden_wheat.glb",
	"pumpkin": "res://assets/models/crops/pumpkin.glb",
	"pumpkin_decor": "res://assets/models/crops/pumpkin_decor.glb",
	"korotu": "res://assets/models/crops/korotu_flower.glb",
	"mist_mushroom": "res://assets/models/crops/mist_mushroom.glb",
}
## Korotu placeholder emission'u (gece parlar — kimligi bu).
const KOROTU_EMISSION := Color(0.30, 0.95, 0.85)
const KOROTU_EMISSION_ENERJI := 1.2

## TARIM-GLB-2 olculeri. OLCEK IMPORT root_scale ILE (node scale
## yasak; carpanlar .glb.import dosyalarinda) — buradaki hedef boylar
## belge + dogrulama: diz boyu bandi 0.35-0.5, kabak iri kalabilir.
## Dogal boylar olculdu: pumpkin 0.617, earth_apple 0.662, korotu 1.0.
const CROP_GLB_BOY := {"pumpkin": 0.55, "earth_apple": 0.38, "korotu": 0.45}
## Toprak tumsekli modeller zemine gomulur (kenar cimle bulussun).
const CROP_GLB_GOM := {"pumpkin": 0.015, "earth_apple": 0.02, "korotu": 0.015}
## Fide evresi: olgun modelin bu orani (mevcut kural).
const FIDE_ORAN := 0.5
## Korotu GLB isiltisi: Meshy emissive dokusu kanaliyla; gece
## _update_water_night ayni gece kaynagindan guclendirir.
const KOROTU_GLB_ENERJI_GUNDUZ := 0.25
const KOROTU_GLB_ENERJI_GECE := 1.6

## MANTAR GOLGE KURALI: hucre "los" sayilir eger agac dibi (1 hucre
## komsulukta agac) YA DA ic mekan (cati alti) ise.
const MANTAR_GOLGE_AGAC_KOMSU := 1

## MUTFAK BUFF'LARI (yemek etkileri; sayilar burada, uygulama
## PlayerStats zamanli-etki cercevesi).
const BUFFS := {
	"koz_corbasi": {
		"ad": "Köz Çorbası",
		"gece_boyu": true,          # sure: gece bitene kadar
		"sis_direnci": true,        # sis/soguk cezalarina bagisiklik
		"vinyet_carpan": 0.25,      # sis vinyeti bu carpanla kisilir
		"isik_halka_yaricap": 2.6,  # oyuncu cevresi kucuk isik halkasi (m)
		"isik_halka_enerji": 0.9,
		"ikon": "res://assets/items/koz_corbasi.png",
	},
	"korlu_lokma": {
		"ad": "Korlu Lokma",
		"sure_sn": 180.0,           # 3 dk
		"hiz_carpani": 1.3,
		"ikon": "res://assets/items/korlu_lokma.png",
	},
}

## Zemin renkleri (world3d._cell_props tarafindan okunur; GROUND char yok)
const TILLED_COLOR := Color(0.36, 0.24, 0.13)      # surulu kuru toprak
const TILLED_WET_COLOR := Color(0.25, 0.165, 0.10) # sulanmis (koyu/islak)
const TILLED_TOP := -0.03                          # hafif cukur his

## Meshy bitki dokulari cok ACIK geliyor (albedoya isik pismis gibi);
## sahne paletine cekmek icin albedo carpani. 1.0 = dokunma.
const CROP_TINT := Color(0.62, 0.70, 0.56)

## Ses kancalari (calar HENUZ yok — veri hazir, RAPOR/DURUM notu)
const SFX := {"till": "dig_dirt", "plant": "plant_seed",
		"water": "water_pour", "fill": "water_fill", "harvest": "harvest_pop"}
