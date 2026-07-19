extends Node
## Oyuncunun envanteri - autoload (singleton) olarak kayitli.
## Oyunun her yerinden "Inventory.add_item(...)" seklinde erisilebilir.
##
## Basit bir sozluk yapisi kullanir: {"odun": 5, "tas": 2} gibi.
## Ileride crafting sistemi de ayni sozlugu okuyup harcayacak.

## Envanter icerigi her degistiginde yayinlanir (HUD bunu dinler).
signal changed

var items: Dictionary = {}

func add_item(item_id: String, amount: int) -> void:
	items[item_id] = get_count(item_id) + amount
	changed.emit()

## Ileride crafting icin: yeterli kaynak varsa harcar, yoksa false doner.
func remove_item(item_id: String, amount: int) -> bool:
	if get_count(item_id) < amount:
		return false
	items[item_id] -= amount
	changed.emit()
	return true

func get_count(item_id: String) -> int:
	return items.get(item_id, 0)

## Kayittan yukleme icin: tum envanteri degistirir.
func set_items(new_items: Dictionary) -> void:
	items = {}
	for item_id in new_items:
		items[item_id] = int(new_items[item_id])
	changed.emit()

## Yeni oyun icin: envanteri bosaltir.
func reset() -> void:
	items = {}
	changed.emit()
