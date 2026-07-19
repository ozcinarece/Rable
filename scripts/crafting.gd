extends Node
## Uretim sistemi - autoload (singleton).
## Tarifleri okur, maliyeti Inventory'den harcar, urunu Inventory'ye ekler.
##
## Istasyon (tezgah) gereksinimi M4d'de gelecek: World, oyuncu tezgahin
## yanindayken near_station'i true yapacak; simdilik tum el tarifleri acik.

const Recipes = preload("res://scripts/recipes.gd")

## Oyuncu su anda bir calisma tezgahinin yaninda mi? (World gunceller)
var near_station: bool = false

## Tarif su an uretilebilir mi? (istasyon + kaynak kontrolu)
func can_craft(recipe_id: String) -> bool:
	var recipe: Dictionary = Recipes.CRAFT_RECIPES[recipe_id]
	if recipe["station"] != "" and not near_station:
		return false
	for item_id in recipe["cost"]:
		if Inventory.get_count(item_id) < recipe["cost"][item_id]:
			return false
	return true

## Uretmeyi dener; basariliysa true doner.
func craft(recipe_id: String) -> bool:
	if not can_craft(recipe_id):
		return false
	var recipe: Dictionary = Recipes.CRAFT_RECIPES[recipe_id]
	for item_id in recipe["cost"]:
		Inventory.remove_item(item_id, recipe["cost"][item_id])
	for item_id in recipe["output"]:
		Inventory.add_item(item_id, recipe["output"][item_id])
	return true
