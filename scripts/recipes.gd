extends RefCounted
## Tum tarifler tek yerde.
##
## BUILD_RECIPES: haritaya yerlestirilen yapilar (insa cubugu)
##   tile: yerlestirilecek harita karakteri (world.gd TILE_DEFS'te tanimli)
##   cost: insa maliyeti
##
## CRAFT_RECIPES: envanterde uretilen esyalar (uretim paneli)
##   output:  uretilen esya(lar) ve adetleri
##   cost:    harcanan esyalar
##   station: "" = elde her yerde uretilir;
##            "tezgah" = calisma tezgahinin yaninda olmayi gerektirir (M4d)

const BUILD_RECIPES: Dictionary = {
	"ahsap_duvar": {"tile": "W", "cost": {"kalas": 2}},
	"tas_duvar": {"tile": "K", "cost": {"tas": 2}},
}

const CRAFT_RECIPES: Dictionary = {
	"kalas": {"output": {"kalas": 2}, "cost": {"odun": 1}, "station": ""},
	"cubuk": {"output": {"cubuk": 2}, "cost": {"kalas": 1}, "station": ""},
	"ip": {"output": {"ip": 1}, "cost": {"yaprak": 3}, "station": ""},
}
