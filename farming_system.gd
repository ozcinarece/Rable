# =============================================================
# farming_system.gd — TARIM ÇEKİRDEĞİ (REFERANS TASARIM KODU)
# Bu dosya kullanıcının verdiği tasarım referansıdır; OYUN BUNU
# YÜKLEMEZ. Çalışan uyarlama: scripts/farming.gd (autoload
# "Farming") + denge: scripts/tarim_balance.gd.
# [ENTEGRASYON] noktalarının gerçek karşılıkları RAPOR_TARIM3D.md'de.
# =============================================================
extends Node

signal plot_changed(cell: Vector2i)
signal crop_harvest_ready(cell: Vector2i)

const TILLED_DECAY_DAYS := 3
const SEED_RETURN_CHANCE := 0.6
const WATERING_CAN_USES := 4

const CROPS := {
	"berry_bush": {
		"name": "Yaban Meyvesi",
		"seed_item": "seed",
		"stages": 3,
		"yield_item": "berry",
		"yield_min": 2, "yield_max": 3,
	},
}

var plots: Dictionary = {}

func _make_plot() -> Dictionary:
	return {"crop_id": "", "stage": 0, "watered_today": false, "empty_days": 0}

func _ready() -> void:
	# [ENTEGRASYON] TimeManager.day_started.connect(_on_day_started)
	pass

func can_till(cell: Vector2i) -> Dictionary:
	if plots.has(cell):
		return {"ok": false, "reason": "Burası zaten tarla"}
	# [ENTEGRASYON] GridWorld derinlik/su/doluluk kontrolleri
	return {"ok": true, "reason": ""}

func till_cell(cell: Vector2i) -> bool:
	var check := can_till(cell)
	if not check.ok:
		return false
	plots[cell] = _make_plot()
	plot_changed.emit(cell)
	return true

func can_plant(cell: Vector2i, crop_id: String) -> Dictionary:
	if not plots.has(cell):
		return {"ok": false, "reason": "Önce çapayla tarla aç"}
	if plots[cell].crop_id != "":
		return {"ok": false, "reason": "Burada zaten bitki var"}
	if not CROPS.has(crop_id):
		return {"ok": false, "reason": "Bilinmeyen tohum"}
	return {"ok": true, "reason": ""}

func plant(cell: Vector2i, crop_id: String) -> bool:
	var check := can_plant(cell, crop_id)
	if not check.ok:
		return false
	var plot: Dictionary = plots[cell]
	plot.crop_id = crop_id
	plot.stage = 0
	plot.empty_days = 0
	plot_changed.emit(cell)
	return true

var watering_can_left := 0

func fill_watering_can() -> void:
	watering_can_left = WATERING_CAN_USES

func can_water(cell: Vector2i) -> Dictionary:
	if watering_can_left <= 0:
		return {"ok": false, "reason": "Kap boş — sudan doldur"}
	if not plots.has(cell):
		return {"ok": false, "reason": "Burası tarla değil"}
	if plots[cell].watered_today:
		return {"ok": false, "reason": "Bugün sulandı zaten"}
	return {"ok": true, "reason": ""}

func water(cell: Vector2i) -> bool:
	var check := can_water(cell)
	if not check.ok:
		return false
	plots[cell].watered_today = true
	watering_can_left -= 1
	plot_changed.emit(cell)
	return true

func _on_day_started() -> void:
	for cell: Vector2i in plots.keys():
		var plot: Dictionary = plots[cell]
		if plot.crop_id == "":
			plot.empty_days += 1
			if plot.empty_days >= TILLED_DECAY_DAYS:
				plots.erase(cell)
				plot_changed.emit(cell)
				continue
		else:
			var max_stage: int = CROPS[plot.crop_id].stages - 1
			# --- IŞIK KURALI BURAYA GELECEK (sonraki adım) ---
			if plot.watered_today and plot.stage < max_stage:
				plot.stage += 1
				plot_changed.emit(cell)
				if plot.stage == max_stage:
					crop_harvest_ready.emit(cell)
		plot.watered_today = false

func can_harvest(cell: Vector2i) -> bool:
	if not plots.has(cell): return false
	var plot: Dictionary = plots[cell]
	if plot.crop_id == "": return false
	return plot.stage >= CROPS[plot.crop_id].stages - 1

func harvest(cell: Vector2i) -> bool:
	if not can_harvest(cell):
		return false
	var plot: Dictionary = plots[cell]
	plot.crop_id = ""
	plot.stage = 0
	plot.empty_days = 0
	plot_changed.emit(cell)
	return true

func to_save_data() -> Dictionary:
	var out := {}
	for cell: Vector2i in plots.keys():
		out["%d,%d" % [cell.x, cell.y]] = plots[cell].duplicate()
	return {"plots": out, "can_left": watering_can_left}

func from_save_data(data: Dictionary) -> void:
	plots.clear()
	for key: String in data.get("plots", {}).keys():
		var parts := key.split(",")
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		plots[cell] = data.plots[key]
		plot_changed.emit(cell)
	watering_can_left = data.get("can_left", 0)
