extends Node
## Oyuncunun envanteri - autoload (singleton).
##
## SIRALI slot dizisi: her slot ya bos (null) ya da {"id": ..., "count": ...}.
## Ayni turden esyalar yigilir (yigin limiti STACK_MAX). Surukle-birakla
## slotlarin yeri degistirilebilir. Baslangicta BASE_SLOTS slot aciktir;
## her canta +SLOTS_PER_BAG slot acar (en fazla MAX_BAGS).
##
## Hizli erisim (hotbar): 8 gozluk atama listesi. Slot degil REFERANSTIR:
## bir esya turunu gosterir; sayisi envanterden okunur. Ilk
## HOTBAR_UNLOCKED gozu acik, kalani seviye sistemiyle acilacak.

signal changed

const STACK_MAX: int = 50
const BASE_SLOTS: int = 8
const SLOTS_PER_BAG: int = 4
const MAX_BAGS: int = 2
const TOTAL_SLOTS: int = BASE_SLOTS + MAX_BAGS * SLOTS_PER_BAG  # 16
const HOTBAR_SIZE: int = 8
const HOTBAR_UNLOCKED: int = 4  # kalani seviye atlayinca acilacak

var slots: Array = []   # TOTAL_SLOTS eleman; null veya {"id","count"}
var hotbar: Array = []  # HOTBAR_SIZE eleman; "" veya item_id

func _ready() -> void:
	_init_arrays()

func _init_arrays() -> void:
	slots = []
	slots.resize(TOTAL_SLOTS)
	hotbar = []
	for i in HOTBAR_SIZE:
		hotbar.append("")

## Su an kullanilabilir slot sayisi (canta sayisina gore)
func get_slot_count() -> int:
	return BASE_SLOTS + mini(get_count("canta"), MAX_BAGS) * SLOTS_PER_BAG

func get_used_slots() -> int:
	var used := 0
	for i in get_slot_count():
		if slots[i] != null:
			used += 1
	return used

func get_count(item_id: String) -> int:
	var total := 0
	for slot in slots:
		if slot != null and slot["id"] == item_id:
			total += slot["count"]
	return total

# --- Ekleme / cikarma ---------------------------------------------------

## Bu miktar eklenebilir mi? (mevcut yiginlara + bos slotlara dagitilir)
func can_add(item_id: String, amount: int) -> bool:
	return can_add_all({item_id: amount})

## Birden fazla turu ayni anda ekleme kontrolu (toplama duslari icin)
func can_add_all(drops: Dictionary) -> bool:
	var sim: Array = []
	for slot in slots:
		sim.append(null if slot == null else slot.duplicate())
	for item_id in drops:
		if not _sim_add(sim, item_id, drops[item_id]):
			return false
	return true

# sim dizisine ekleme dener; sigmazsa false (sim degismis olabilir)
func _sim_add(sim: Array, item_id: String, amount: int) -> bool:
	var capacity := get_slot_count()
	var left: int = amount
	for i in capacity:
		if left <= 0:
			break
		if sim[i] != null and sim[i]["id"] == item_id and sim[i]["count"] < STACK_MAX:
			var take: int = mini(STACK_MAX - sim[i]["count"], left)
			sim[i]["count"] += take
			left -= take
	for i in capacity:
		if left <= 0:
			break
		if sim[i] == null:
			var take: int = mini(STACK_MAX, left)
			sim[i] = {"id": item_id, "count": take}
			left -= take
	return left <= 0

func add_item(item_id: String, amount: int) -> bool:
	return add_all({item_id: amount})

func add_all(drops: Dictionary) -> bool:
	if not can_add_all(drops):
		return false
	for item_id in drops:
		_sim_add(slots, item_id, drops[item_id])
	changed.emit()
	return true

## Yeterli kaynak varsa harcar (son slotlardan geriye dogru eksiltir).
func remove_item(item_id: String, amount: int) -> bool:
	if get_count(item_id) < amount:
		return false
	var left := amount
	for i in range(slots.size() - 1, -1, -1):
		if left <= 0:
			break
		var slot = slots[i]
		if slot == null or slot["id"] != item_id:
			continue
		var take: int = mini(slot["count"], left)
		slot["count"] -= take
		left -= take
		if slot["count"] <= 0:
			slots[i] = null
	changed.emit()
	return true

# --- Surukle & birak ----------------------------------------------------

## Iki slotun yerini degistirir; ayni tur ise yigini birlestirir.
func move_slot(from: int, to: int) -> void:
	if from == to or from < 0 or to < 0 \
			or from >= slots.size() or to >= slots.size():
		return
	var a = slots[from]
	var b = slots[to]
	if a == null:
		return
	if b != null and b["id"] == a["id"]:
		var space: int = STACK_MAX - b["count"]
		var moved: int = mini(space, a["count"])
		b["count"] += moved
		a["count"] -= moved
		if a["count"] <= 0:
			slots[from] = null
	else:
		slots[from] = b
		slots[to] = a
	changed.emit()

## Slotu tamamen bosaltir ve icerigini dondurur (yere birakma icin).
func clear_slot(index: int) -> Dictionary:
	if index < 0 or index >= slots.size() or slots[index] == null:
		return {}
	var content: Dictionary = slots[index]
	slots[index] = null
	changed.emit()
	return content

## Hotbar gozune esya turu atar ("" = bosalt). Ayni tur baska gozdeyse
## eski atama kaldirilir (bir tur tek gozde olsun).
func set_hotbar(index: int, item_id: String) -> void:
	if index < 0 or index >= HOTBAR_SIZE:
		return
	if item_id != "":
		for i in HOTBAR_SIZE:
			if hotbar[i] == item_id:
				hotbar[i] = ""
	hotbar[index] = item_id
	changed.emit()

func swap_hotbar(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0 or a >= HOTBAR_SIZE or b >= HOTBAR_SIZE:
		return
	var tmp: String = hotbar[a]
	hotbar[a] = hotbar[b]
	hotbar[b] = tmp
	changed.emit()

# --- Kayit / yukleme ----------------------------------------------------

func to_save() -> Dictionary:
	return {"slots": slots.duplicate(true), "hotbar": hotbar.duplicate()}

func load_save(data: Dictionary) -> void:
	_init_arrays()
	var saved_slots: Array = data.get("slots", [])
	for i in mini(saved_slots.size(), TOTAL_SLOTS):
		var slot = saved_slots[i]
		if slot is Dictionary and slot.has("id") and int(slot.get("count", 0)) > 0:
			slots[i] = {"id": String(slot["id"]), "count": int(slot["count"])}
	var saved_hotbar: Array = data.get("hotbar", [])
	for i in mini(saved_hotbar.size(), HOTBAR_SIZE):
		hotbar[i] = String(saved_hotbar[i])
	changed.emit()

## Eski (v2) kayitlar icin: {"item_id": adet} sozlugunden slotlari doldurur.
func load_from_dict(items: Dictionary) -> void:
	_init_arrays()
	for item_id in items:
		var count := int(items[item_id])
		while count > 0:
			var take: int = mini(STACK_MAX, count)
			var placed := false
			for i in TOTAL_SLOTS:
				if slots[i] == null:
					slots[i] = {"id": item_id, "count": take}
					placed = true
					break
			if not placed:
				break
			count -= take
	changed.emit()

## Yeni oyun icin: envanteri bosaltir.
func reset() -> void:
	_init_arrays()
	changed.emit()
