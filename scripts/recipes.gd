extends RefCounted
## Tum tarifler tek yerde.
##
## BUILD_RECIPES: haritaya yerlestirilen yapilar (insa cubugu)
##   name: butonda gorunen ad
##   icon: butonda gorunen ikon
##   tile: yerlestirilecek harita karakteri (world.gd TILE_DEFS'te tanimli)
##   cost: insa maliyeti
##
## CRAFT_RECIPES: envanterde uretilen esyalar (uretim paneli)
##   output:  uretilen esya(lar) ve adetleri
##   cost:    harcanan esyalar
##   station: "" = elde her yerde uretilir;
##            "tezgah" = calisma tezgahinin yaninda olmayi gerektirir

const BUILD_RECIPES: Dictionary = {
	"ahsap_duvar": {"name": "Ahşap Duvar", "icon": "res://assets/tiles/wood_wall.png",
			"tile": "W", "cost": {"kalas": 2}},
	"tas_duvar": {"name": "Taş Duvar", "icon": "res://assets/tiles/stone_wall.png",
			"tile": "K", "cost": {"tas": 2}},
	"tezgah": {"name": "Tezgah", "icon": "res://assets/tiles/tezgah.png",
			"tile": "B", "cost": {"kalas": 4, "cubuk": 2}},
	"kamp_evi": {"name": "Kamp Evi", "icon": "res://assets/tiles/ev.png",
			"tile": "E", "cost": {"kalas": 6, "ip": 2, "yaprak": 4}},
	"sandik": {"name": "Sandık", "icon": "res://assets/tiles/sandik.png",
			"tile": "S", "cost": {"kalas": 4, "ip": 1}},
	# Diken tuzagi: yaratiklar ustunden gecerken hasar alir (5 kullanimlik)
	"tuzak": {"name": "Tuzak", "icon": "res://assets/tiles/tuzak.png",
			"tile": "Z", "cost": {"cubuk": 2, "tas": 1}},
	# Cukur doldurma: sadece cukur ("o") uzerine uygulanabilir
	"doldur": {"name": "Doldur", "icon": "res://assets/items/toprak.png",
			"tile": "d", "cost": {"toprak": 1}, "place_on": "o"},
}

const CRAFT_RECIPES: Dictionary = {
	"kalas": {"output": {"kalas": 2}, "cost": {"odun": 1}, "station": ""},
	"cubuk": {"output": {"cubuk": 2}, "cost": {"kalas": 1}, "station": ""},
	"ip": {"output": {"ip": 1}, "cost": {"yaprak": 3}, "station": ""},
	"balta": {"output": {"balta": 1}, "cost": {"cubuk": 2, "ip": 1, "tas": 1}, "station": "tezgah"},
	"kazma": {"output": {"kazma": 1}, "cost": {"cubuk": 2, "ip": 1, "tas": 2}, "station": "tezgah"},
	"kurek": {"output": {"kurek": 1}, "cost": {"cubuk": 2, "ip": 1, "kalas": 1}, "station": "tezgah"},
	"canta": {"output": {"canta": 1}, "cost": {"ip": 3, "yaprak": 4}, "station": "tezgah"},
	"mizrak": {"output": {"mizrak": 1}, "cost": {"cubuk": 2, "tas": 1, "ip": 1}, "station": "tezgah"},
	"zirh": {"output": {"zirh": 1}, "cost": {"ip": 4, "kalas": 2, "tas": 2}, "station": "tezgah"},
	"sapka": {"output": {"sapka": 1}, "cost": {"ip": 2, "yaprak": 3}, "station": "tezgah"},
}
