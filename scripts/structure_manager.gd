extends RefCounted
## YAPI KAYIT DEFTERI (YAPI_SISTEMI.md 13.1). Dunyadaki tum yerlestirilmis
## yapi ORNEKLERININ metasini tutar: yon, hp, max_hp, durum. Gorsel dugumler
## ve item_id world3d._placed/_placed_nodes'ta kalir; bu sinif onlarin
## YANINDA per-instance veriyi yonetir (muhafazakar: mevcut sistem bozulmaz).
##
## take_hit hasar/tamir/yikim mantigi 13.4; kayit taslagi 13.6.

## Hucre -> {id, rot, hp, max_hp, state}
## state: "ok" | "damaged" (hp < max/2) | "destroyed" (gecici)
var _instances: Dictionary = {}

func place(cell: Vector2i, id: String, rot: int, max_hp: int) -> void:
	_instances[cell] = {
		"id": id, "rot": rot,
		"hp": max_hp, "max_hp": max_hp, "state": "ok",
		"open": false,  # kapilar icin (13.5); digerleri kullanmaz
	}

## Kapi ac/kapa durumu (13.5)
func is_open(cell: Vector2i) -> bool:
	return bool(_instances.get(cell, {}).get("open", false))

func set_open(cell: Vector2i, v: bool) -> void:
	if _instances.has(cell):
		_instances[cell]["open"] = v

func remove(cell: Vector2i) -> void:
	_instances.erase(cell)

func has(cell: Vector2i) -> bool:
	return _instances.has(cell)

func get_inst(cell: Vector2i) -> Dictionary:
	return _instances.get(cell, {})

func rotation_of(cell: Vector2i) -> int:
	return int(_instances.get(cell, {}).get("rot", 0))

func all_cells() -> Array:
	return _instances.keys()

## Hasar uygular; yeni durumu doner: "ok"/"damaged"/"destroyed".
func apply_damage(cell: Vector2i, amount: int) -> String:
	if not _instances.has(cell):
		return "none"
	var inst: Dictionary = _instances[cell]
	inst["hp"] = maxi(0, int(inst["hp"]) - amount)
	if int(inst["hp"]) <= 0:
		inst["state"] = "destroyed"
	elif int(inst["hp"]) < int(inst["max_hp"]) / 2:
		inst["state"] = "damaged"
	else:
		inst["state"] = "ok"
	return String(inst["state"])

## Tamir uygular; tam dolduysa true.
func apply_repair(cell: Vector2i, amount: int) -> bool:
	if not _instances.has(cell):
		return false
	var inst: Dictionary = _instances[cell]
	inst["hp"] = mini(int(inst["max_hp"]), int(inst["hp"]) + amount)
	inst["state"] = "damaged" if int(inst["hp"]) < int(inst["max_hp"]) / 2 else "ok"
	return int(inst["hp"]) >= int(inst["max_hp"])

func hp_ratio(cell: Vector2i) -> float:
	var inst: Dictionary = _instances.get(cell, {})
	if inst.is_empty():
		return 1.0
	return float(inst["hp"]) / maxf(1.0, float(inst["max_hp"]))

# --- Kayit taslagi (13.6): calisir ama baglanmasi cagirana kalir ----------

func to_save_data() -> Array:
	var out: Array = []
	for cell: Vector2i in _instances:
		var inst: Dictionary = _instances[cell]
		out.append({"x": cell.x, "y": cell.y, "id": inst["id"],
				"rot": inst["rot"], "hp": inst["hp"],
				"max_hp": inst["max_hp"], "state": inst["state"],
				"open": inst.get("open", false)})
	return out

func from_save_data(data: Array) -> void:
	_instances.clear()
	for e in data:
		if e is Dictionary and e.has("id"):
			var cell := Vector2i(int(e.get("x", 0)), int(e.get("y", 0)))
			_instances[cell] = {
				"id": String(e["id"]),
				"rot": int(e.get("rot", 0)),
				"hp": int(e.get("hp", 1)),
				"max_hp": int(e.get("max_hp", 1)),
				"state": String(e.get("state", "ok")),
				"open": bool(e.get("open", false)),
			}

func clear() -> void:
	_instances.clear()
