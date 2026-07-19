extends RefCounted
## Insa tarifleri.
## Yeni bir insa edilebilir sey eklemek icin buraya bir kayit ekle,
## world.gd'deki TILE_DEFS'e tile tanimini yaz ve HUD'a bir buton koy.
##
##   tile: yerlestirilecek harita karakteri (world.gd TILE_DEFS'te tanimli)
##   cost: insa maliyeti (envanterdeki kaynak id'leri)

const RECIPES: Dictionary = {
	"ahsap_duvar": {"tile": "W", "cost": {"odun": 2}},
	"tas_duvar": {"tile": "K", "cost": {"tas": 2}},
}
