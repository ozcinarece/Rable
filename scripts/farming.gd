extends Node
## TARIM CEKIRDEGI (Faz 0: tarla + ekim + sulama + hasat) — autoload
## "Farming". YALNIZ VERI + MANTIK; gorsel cizmez. plot_changed'i
## dinleyen world3d zemini/bitki dugumunu yeniler (veri->gorsel ayrigi).
##
## Referans: kokteki farming_system.gd. FARKLAR (RAPOR_TARIM3D):
## - Dunya gecerlilik kontrolleri (derinlik/su/doluluk) WORLD3D'de:
##   modul saf kalir, world _till_valid ile onaylayip till_cell cagirir.
## - Gun surucusu WORLD3D: safakta ONCE bitisik-su otomatigi
##   (water_free), SONRA day_tick — sinyal sira belirsizligi yok.
## - Hasat verim atisi/sacilimi world'de (ground_item sistemi).

const Balance = preload("res://scripts/tarim_balance.gd")

signal plot_changed(cell: Vector2i)          # gorsel guncelleme icin
signal crop_harvest_ready(cell: Vector2i)    # UI ipucu kancasi

## Tarla verisi: cell (Vector2i) -> plot sozlugu
var plots: Dictionary = {}
## Sulama kabinda kalan kullanim
var watering_can_left := 0

func _make_plot() -> Dictionary:
	return {
		"crop_id": "",          # "" = bos tarla
		"stage": 0,             # mevcut evre
		"watered_today": false, # bugun sulandi mi
		"empty_days": 0,        # bos gun sayaci (cime donus)
	}

# --- 1) TARLA ACMA (gecerlilik world3d._till_valid'de) --------------------
func till_cell(cell: Vector2i) -> bool:
	if plots.has(cell):
		return false
	plots[cell] = _make_plot()
	plot_changed.emit(cell)
	return true

# --- 2) EKIM ---------------------------------------------------------------
func can_plant(cell: Vector2i, crop_id: String) -> Dictionary:
	if not plots.has(cell):
		return {"ok": false, "reason": "Önce çapayla tarla aç"}
	if String(plots[cell].crop_id) != "":
		return {"ok": false, "reason": "Burada zaten bitki var"}
	if not Balance.CROPS.has(crop_id):
		return {"ok": false, "reason": "Bilinmeyen tohum"}
	return {"ok": true, "reason": ""}

## Tohumun envanterden dusurulmesi CAGIRANA aittir (world3d _try_plant).
func plant(cell: Vector2i, crop_id: String) -> bool:
	if not bool(can_plant(cell, crop_id).ok):
		return false
	var plot: Dictionary = plots[cell]
	plot.crop_id = crop_id
	plot.stage = 0
	plot.empty_days = 0
	plot_changed.emit(cell)   # gorsel: filiz
	return true

# --- 3) SULAMA -------------------------------------------------------------
func fill_watering_can() -> void:
	watering_can_left = Balance.WATERING_CAN_USES

func can_water(cell: Vector2i) -> Dictionary:
	if watering_can_left <= 0:
		return {"ok": false, "reason": "Kap boş — sudan doldur"}
	if not plots.has(cell):
		return {"ok": false, "reason": "Burası tarla değil"}
	if bool(plots[cell].watered_today):
		return {"ok": false, "reason": "Bugün sulandı zaten"}
	return {"ok": true, "reason": ""}

func water(cell: Vector2i) -> bool:
	if not bool(can_water(cell).ok):
		return false
	plots[cell].watered_today = true
	watering_can_left -= 1
	plot_changed.emit(cell)   # gorsel: toprak koyulasir (islak)
	return true

## KADEME 2: bitisik su otomatigi — depo harcamaz (world3d safakta cagirir)
func water_free(cell: Vector2i) -> void:
	if plots.has(cell) and not bool(plots[cell].watered_today):
		plots[cell].watered_today = true
		plot_changed.emit(cell)

# --- 4) GUN DONGUSU — BUYUME (world3d safakta cagirir) ----------------------
func day_tick() -> void:
	for cell: Vector2i in plots.keys():
		var plot: Dictionary = plots[cell]
		if String(plot.crop_id) == "":
			plot.empty_days += 1
			if int(plot.empty_days) >= Balance.TILLED_DECAY_DAYS:
				plots.erase(cell)   # bakimsiz tarla cime doner
				plot_changed.emit(cell)
				continue
		else:
			var max_stage: int = int(Balance.CROPS[plot.crop_id].stages) - 1
			# --- ISIK KURALI BURAYA GELECEK (hikaye fazi; simdilik yok) ---
			if bool(plot.watered_today) and int(plot.stage) < max_stage:
				plot.stage += 1
				plot_changed.emit(cell)
				if int(plot.stage) == max_stage:
					crop_harvest_ready.emit(cell)
		plot.watered_today = false   # islaklik her sabah sifirlanir

# --- 5) HASAT ----------------------------------------------------------------
func can_harvest(cell: Vector2i) -> bool:
	if not plots.has(cell):
		return false
	var plot: Dictionary = plots[cell]
	if String(plot.crop_id) == "":
		return false
	return int(plot.stage) >= int(Balance.CROPS[plot.crop_id].stages) - 1

## Hasadi uygular, urun tanimini dondurur (verim atisi + sacilim world'de).
func harvest_clear(cell: Vector2i) -> Dictionary:
	if not can_harvest(cell):
		return {}
	var plot: Dictionary = plots[cell]
	var crop: Dictionary = Balance.CROPS[plot.crop_id]
	plot.crop_id = ""
	plot.stage = 0
	plot.empty_days = 0
	plot_changed.emit(cell)   # gorsel: surulu-bos tarla
	return crop

# --- 6) KAYIT ----------------------------------------------------------------
func to_save_data() -> Dictionary:
	var out := {}
	for cell: Vector2i in plots.keys():
		out["%d,%d" % [cell.x, cell.y]] = plots[cell].duplicate()
	return {"plots": out, "can_left": watering_can_left}

func from_save_data(data: Dictionary) -> void:
	# Eski hucrelerin gorseli temizlensin diye once mevcutlari duyur
	var old_cells: Array = plots.keys()
	plots.clear()
	for cell: Vector2i in old_cells:
		plot_changed.emit(cell)
	var saved: Dictionary = data.get("plots", {})
	for key: String in saved.keys():
		var parts := key.split(",")
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		plots[cell] = saved[key]
		plot_changed.emit(cell)
	watering_can_left = int(data.get("can_left", 0))
