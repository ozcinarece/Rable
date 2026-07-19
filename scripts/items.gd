extends RefCounted
## Esya kayit defteri: her esyanin gorunen adi ve ikonu.
## Yeni bir esya eklemek icin buraya bir satir ekle ve
## assets/items/ altina 32x32 bir ikon koy.
##
## Buradaki sira, envanter cubugundaki gosterim sirasidir.

const ITEMS: Dictionary = {
	"odun": {"name": "Odun", "icon": "res://assets/items/odun.png"},
	"yaprak": {"name": "Yaprak", "icon": "res://assets/items/yaprak.png"},
	"kalas": {"name": "Kalas", "icon": "res://assets/items/kalas.png"},
	"cubuk": {"name": "Çubuk", "icon": "res://assets/items/cubuk.png"},
	"ip": {"name": "İp", "icon": "res://assets/items/ip.png"},
	"tas": {"name": "Taş", "icon": "res://assets/items/tas.png"},
}

static func display_name(item_id: String) -> String:
	if ITEMS.has(item_id):
		return ITEMS[item_id]["name"]
	return item_id
