extends RefCounted
## Tum uretim tarifleri tek listede (insa cubugu kaldirildi; yapilar da
## uretim menusunden ESYA olarak uretilir, sonra elde tutulup yere konur).
##
##   output:   uretilen esya(lar) ve adetleri
##   cost:     bir adet uretimin maliyeti
##   station:  "" = elde her yerde; "tezgah" = tezgah yaninda uretilir
##   category: uretim menusu sekmesi (CATEGORIES anahtari)
##   time:     BIR adedin uretim suresi (saniye) - karmasiklikla artar

const CATEGORIES: Dictionary = {
	"malzeme": "Malzeme",
	"alet": "Aletler",
	"savas": "Savaş & Av",
	"yapi": "Yapılar",
	"tarim": "Tarım",
}

const CRAFT_RECIPES: Dictionary = {
	# --- Malzemeler (el, hizli) ---
	"kalas": {"output": {"kalas": 2}, "cost": {"odun": 1},
			"station": "", "category": "malzeme", "time": 1.0},
	"cubuk": {"output": {"cubuk": 2}, "cost": {"kalas": 1},
			"station": "", "category": "malzeme", "time": 1.0},
	"ip": {"output": {"ip": 1}, "cost": {"yaprak": 3},
			"station": "", "category": "malzeme", "time": 1.0},
	# --- Aletler (tezgah) ---
	"balta": {"output": {"balta": 1}, "cost": {"cubuk": 2, "ip": 1, "tas": 1},
			"station": "tezgah", "category": "alet", "time": 3.0},
	"kazma": {"output": {"kazma": 1}, "cost": {"cubuk": 2, "ip": 1, "tas": 2},
			"station": "tezgah", "category": "alet", "time": 3.0},
	"kurek": {"output": {"kurek": 1}, "cost": {"cubuk": 2, "ip": 1, "kalas": 1},
			"station": "tezgah", "category": "alet", "time": 3.0},
	"canta": {"output": {"canta": 1}, "cost": {"ip": 3, "yaprak": 4},
			"station": "tezgah", "category": "alet", "time": 4.0},
	"arastirma_masasi": {"output": {"arastirma_masasi": 1},
			"cost": {"kalas": 4, "tas": 2, "ip": 1},
			"station": "tezgah", "category": "yapi", "time": 4.0},
	# --- Savas & Av ---
	"mizrak": {"output": {"mizrak": 1}, "cost": {"cubuk": 2, "tas": 1, "ip": 1},
			"station": "tezgah", "category": "savas", "time": 3.0},
	"zirh": {"output": {"zirh": 1}, "cost": {"ip": 4, "kalas": 2, "tas": 2},
			"station": "tezgah", "category": "savas", "time": 5.0},
	"sapka": {"output": {"sapka": 1}, "cost": {"ip": 2, "yaprak": 3},
			"station": "tezgah", "category": "savas", "time": 3.0},
	"tuzak": {"output": {"tuzak": 1}, "cost": {"cubuk": 2, "tas": 1},
			"station": "", "category": "savas", "time": 2.0},
	# --- Yapilar (uret -> eline al -> yere koy) ---
	"ahsap_duvar": {"output": {"ahsap_duvar": 1}, "cost": {"kalas": 2},
			"station": "", "category": "yapi", "time": 2.0},
	"tas_duvar": {"output": {"tas_duvar": 1}, "cost": {"tas": 2},
			"station": "", "category": "yapi", "time": 2.0},
	"zemin": {"output": {"zemin": 1}, "cost": {"kalas": 1},
			"station": "", "category": "yapi", "time": 1.5},
	"kapi": {"output": {"kapi": 1}, "cost": {"kalas": 3, "ip": 1},
			"station": "", "category": "yapi", "time": 2.5},
	"sandik": {"output": {"sandik": 1}, "cost": {"kalas": 4, "ip": 1},
			"station": "", "category": "yapi", "time": 2.5},
	"tezgah": {"output": {"tezgah": 1}, "cost": {"kalas": 4, "cubuk": 2},
			"station": "", "category": "yapi", "time": 4.0},
	"yatak": {"output": {"yatak": 1}, "cost": {"kalas": 4, "ip": 2, "yaprak": 2},
			"station": "", "category": "yapi", "time": 4.0},
	"kamp_evi": {"output": {"kamp_evi": 1}, "cost": {"kalas": 6, "ip": 2, "yaprak": 4},
			"station": "", "category": "yapi", "time": 6.0},
	# --- Tarim ---
	"tohum": {"output": {"tohum": 2}, "cost": {"meyve": 1},
			"station": "", "category": "tarim", "time": 1.0},
}
