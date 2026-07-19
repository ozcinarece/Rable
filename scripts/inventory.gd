extends Node
## Oyuncunun envanteri - autoload (singleton).
##
## Slot mantigi: her esya TURU bir slot kaplar; ayni turden esyalar
## tek slotta yigilir (yigin limiti STACK_MAX). Baslangicta BASE_SLOTS
## slot vardir; her canta +SLOTS_PER_BAG slot acar (en fazla MAX_BAGS).
## Kapasite dolunca toplama/uretim reddedilir ("Envanter dolu!").

signal changed

const STACK_MAX: int = 50
const BASE_SLOTS: int = 8
const SLOTS_PER_BAG: int = 4
const MAX_BAGS: int = 2

var items: Dictionary = {}

func get_slot_count() -> int:
	return BASE_SLOTS + mini(get_count("canta"), MAX_BAGS) * SLOTS_PER_BAG

func get_used_slots() -> int:
	return items.size()

func get_count(item_id: String) -> int:
	return items.get(item_id, 0)

## Bu miktar eklenebilir mi? (yigin limiti + bos slot kontrolu)
func can_add(item_id: String, amount: int) -> bool:
	var current := get_count(item_id)
	if current + amount > STACK_MAX:
		return false
	if current == 0 and items.size() >= get_slot_count():
		return false
	return true

## Birden fazla turu ayni anda ekleme kontrolu (toplama duslari icin)
func can_add_all(drops: Dictionary) -> bool:
	var sim := items.duplicate()
	var slots := get_slot_count()
	for item_id in drops:
		var current: int = sim.get(item_id, 0)
		if current == 0 and sim.size() >= slots:
			return false
		if current + drops[item_id] > STACK_MAX:
			return false
		sim[item_id] = current + drops[item_id]
	return true

func add_item(item_id: String, amount: int) -> bool:
	if not can_add(item_id, amount):
		return false
	items[item_id] = get_count(item_id) + amount
	changed.emit()
	return true

func add_all(drops: Dictionary) -> bool:
	if not can_add_all(drops):
		return false
	for item_id in drops:
		items[item_id] = get_count(item_id) + drops[item_id]
	changed.emit()
	return true

## Yeterli kaynak varsa harcar; slot sifirlaninca bosalir.
func remove_item(item_id: String, amount: int) -> bool:
	if get_count(item_id) < amount:
		return false
	items[item_id] -= amount
	if items[item_id] <= 0:
		items.erase(item_id)
	changed.emit()
	return true

## Kayittan yukleme icin: tum envanteri degistirir.
func set_items(new_items: Dictionary) -> void:
	items = {}
	for item_id in new_items:
		var count := int(new_items[item_id])
		if count > 0:
			items[item_id] = count
	changed.emit()

## Yeni oyun icin: envanteri bosaltir.
func reset() -> void:
	items = {}
	changed.emit()
