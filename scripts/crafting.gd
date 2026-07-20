extends Node
## Uretim sistemi - autoload (singleton).
##
## ZAMANLI KUYRUK: "5 balta uret" dersen maliyetin tamami pesin dusulur,
## urunler teker teker uretilir (her biri tarifin "time" suresi kadar).
## Kuyrugun basindaki isin ilerlemesi get_progress() ile okunur; HUD
## bunu ilerleme cubugunda gosterir. Envanter doluysa uretim bekler.

const Recipes = preload("res://scripts/recipes.gd")

## Kuyruk yapisi degisince yayinlanir (eleman bitti/eklendi/temizlendi)
signal queue_changed

## Tezgah yakinligi degistiginde yayinlanir (HUD tarifleri gunceller)
signal station_changed

## Oyuncu su anda bir calisma tezgahinin yaninda mi? (World gunceller)
var near_station: bool = false:
	set(value):
		if near_station == value:
			return
		near_station = value
		station_changed.emit()

## Siradaki isler: her biri {"id": tarif, "remaining": kalan adet,
## "progress": ilk urunun gecen suresi}
var queue: Array = []

## Envanter dolu oldugu icin teslim bekleniyor mu? (HUD uyari gosterir)
var blocked: bool = false

## Tarif SU AN 1 adet uretilebilir mi? (istasyon + kaynak kontrolu)
func can_craft(recipe_id: String) -> bool:
	return max_craftable(recipe_id) >= 1

## Eldeki malzemeyle en fazla kac adet uretilebilir? (istasyon yoksa 0)
func max_craftable(recipe_id: String) -> int:
	# Arastirma kapisi: bir arastirma dugumune bagli tarifler yalnizca
	# dugum acildiginda uretilebilir (bagli olmayanlar serbesttir)
	var research := get_node_or_null("/root/Research")
	if research != null and not research.is_recipe_unlocked(recipe_id):
		return 0
	var recipe: Dictionary = Recipes.CRAFT_RECIPES[recipe_id]
	if recipe["station"] != "" and not near_station:
		return 0
	var best := 99
	for item_id in recipe["cost"]:
		var need: int = recipe["cost"][item_id]
		best = mini(best, Inventory.get_count(item_id) / need)
	return best

## Kuyruga is ekler; maliyet PESIN dusulur. Basariliysa true.
func enqueue(recipe_id: String, count: int) -> bool:
	count = mini(count, max_craftable(recipe_id))
	if count <= 0:
		return false
	var recipe: Dictionary = Recipes.CRAFT_RECIPES[recipe_id]
	for item_id in recipe["cost"]:
		Inventory.remove_item(item_id, recipe["cost"][item_id] * count)
	queue.append({"id": recipe_id, "remaining": count, "progress": 0.0})
	queue_changed.emit()
	return true

func _process(delta: float) -> void:
	if queue.is_empty():
		return
	var entry: Dictionary = queue[0]
	var recipe: Dictionary = Recipes.CRAFT_RECIPES[entry["id"]]
	if not blocked:
		entry["progress"] += delta
	if entry["progress"] < float(recipe["time"]):
		return
	# Sure doldu: urunu teslim etmeyi dene (envanter doluysa bekle)
	if not Inventory.add_all(recipe["output"]):
		blocked = true
		return
	blocked = false
	entry["progress"] = 0.0
	entry["remaining"] = int(entry["remaining"]) - 1
	if entry["remaining"] <= 0:
		queue.pop_front()
	queue_changed.emit()

## Kuyrugun basindaki isin ilerlemesi (0..1); kuyruk bossa -1
func get_progress() -> float:
	if queue.is_empty():
		return -1.0
	var entry: Dictionary = queue[0]
	var recipe: Dictionary = Recipes.CRAFT_RECIPES[entry["id"]]
	return clampf(entry["progress"] / float(recipe["time"]), 0.0, 1.0)

## Kuyruktaki toplam is sayisi (HUD rozeti icin)
func get_total_remaining() -> int:
	var total := 0
	for entry in queue:
		total += int(entry["remaining"])
	return total

# --- Kayit / yukleme ----------------------------------------------------

func to_save() -> Array:
	return queue.duplicate(true)

func load_save(saved: Array) -> void:
	queue = []
	for entry in saved:
		if entry is Dictionary and Recipes.CRAFT_RECIPES.has(entry.get("id", "")):
			queue.append({"id": String(entry["id"]),
					"remaining": int(entry.get("remaining", 0)),
					"progress": float(entry.get("progress", 0.0))})
	blocked = false
	queue_changed.emit()

func reset() -> void:
	queue = []
	blocked = false
	queue_changed.emit()
