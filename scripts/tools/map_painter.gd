extends Control
## HARITA RESSAMI — masaustu araci. Godot'ta bu sahneyi ac, F6 ile kostur.
## SOL: maske tuvali (firca/silgi/kova, 6 renk, geri al).
## SAG: canli 2D biyom onizlemesi (maske + noise birlesik sonucu) ve
## istege bagli 3D kusbakisi (pahali oldugu icin butonla).
##
## Editor eklentisi DEGIL, normal sahne — basit kalsin (gorev sarti).
## Mobil degil: fare oncelikli, pencere serbestce boyutlanir.

const MapMask = preload("res://scripts/map_mask.gd")
const MapGen = preload("res://scripts/map_gen.gd")
const MapBalance = preload("res://scripts/map_balance.gd")

const N := 128                      # maske = harita: 1 px = 1 hucre
const UNDO_MAX := 10

var mask_img: Image
var base_rows: Array[String] = []   # uretec ciktisi (bir kez, cache)
var arac := "firca"                 # firca | silgi | kova
var boya_id := "su"
var firca_boy := 4
var _undo: Array = []
var _basili := false
var _kirli_onizleme := false        # firca darbesi geldi, onizleme guncellensin

var _tuval: TextureRect
var _tuval_tex: ImageTexture
var _on2d: TextureRect
var _on2d_tex: ImageTexture
var _on3d: TextureRect
var _durum: Label
var _arac_butonlar: Dictionary = {}
var _viewport3d: SubViewport = null

func _ready() -> void:
	get_window().title = "Harita Ressamı"
	base_rows = MapGen.generate(MapBalance.SEED_DEFAULT)
	# Ilk acilis: kayitli maske varsa o, yoksa mevcut haritanin yaklasik
	# cevirisi (bos sayfadan baslanmaz — gorev sarti).
	mask_img = MapMask.load_image()
	var kaynak := "kayitli maske"
	if mask_img == null or mask_img.get_width() != N:
		mask_img = MapMask.translate_rows(base_rows)
		kaynak = "mevcut haritadan çeviri"
	mask_img.convert(Image.FORMAT_RGBA8)
	_build_ui()
	_tuval_yenile()
	_onizleme_yenile()
	_durum.text = "Hazır — kaynak: %s" % kaynak

func _process(_delta: float) -> void:
	# Onizleme her darbede DEGIL karede bir yenilenir (surukleme akici kalsin)
	if _kirli_onizleme:
		_kirli_onizleme = false
		_onizleme_yenile()

# ======================================================================
# UI
# ======================================================================
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var kok := HBoxContainer.new()
	kok.set_anchors_preset(Control.PRESET_FULL_RECT)
	kok.add_theme_constant_override("separation", 10)
	add_child(kok)

	# --- SOL: araclar + tuval ---
	var sol := VBoxContainer.new()
	sol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sol.size_flags_stretch_ratio = 1.0
	kok.add_child(sol)

	# Renk paleti: 6 buyuk buton (hex girme yok)
	var palet := HBoxContainer.new()
	palet.add_theme_constant_override("separation", 6)
	sol.add_child(palet)
	for id: String in MapMask.COLORS:
		var b := Button.new()
		b.text = String(MapMask.AD[id])
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()
		sb.bg_color = MapMask.COLORS[id]
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_color_override("font_color", Color.WHITE
				if MapMask.COLORS[id].get_luminance() < 0.6 else Color.BLACK)
		b.pressed.connect(func():
			boya_id = id
			if arac == "silgi":
				_arac_sec("firca")
			_durum.text = "Renk: %s" % String(MapMask.AD[id]))
		palet.add_child(b)

	# Arac satiri
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 6)
	sol.add_child(arow)
	for a: Array in [["firca", "Fırça"], ["silgi", "Silgi"], ["kova", "Kova"]]:
		var tb := Button.new()
		tb.toggle_mode = true
		tb.text = String(a[1])
		tb.button_pressed = (String(a[0]) == "firca")
		tb.pressed.connect(_arac_sec.bind(String(a[0])))
		arow.add_child(tb)
		_arac_butonlar[a[0]] = tb
	var bl := Label.new()
	bl.text = "Boyut"
	arow.add_child(bl)
	var slider := HSlider.new()
	slider.min_value = 1
	slider.max_value = 14
	slider.value = firca_boy
	slider.custom_minimum_size = Vector2(120, 0)
	slider.value_changed.connect(func(v: float): firca_boy = int(v))
	arow.add_child(slider)
	var undo_b := Button.new()
	undo_b.text = "↶ Geri Al"
	undo_b.pressed.connect(_geri_al)
	arow.add_child(undo_b)
	var kaydet := Button.new()
	kaydet.text = "💾 Kaydet"
	kaydet.pressed.connect(_kaydet)
	arow.add_child(kaydet)
	var yukle := Button.new()
	yukle.text = "Yükle"
	yukle.pressed.connect(_yukle)
	arow.add_child(yukle)

	# Tuval
	_tuval = TextureRect.new()
	_tuval.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tuval.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tuval.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tuval.mouse_filter = Control.MOUSE_FILTER_STOP
	_tuval.gui_input.connect(_tuval_girdi)
	sol.add_child(_tuval)
	_tuval_tex = ImageTexture.create_from_image(mask_img if mask_img != null
			else Image.create(N, N, false, Image.FORMAT_RGBA8))
	_tuval.texture = _tuval_tex

	_durum = Label.new()
	_durum.text = "Hazır"
	sol.add_child(_durum)

	# --- SAG: onizlemeler ---
	var sag := VBoxContainer.new()
	sag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sag.size_flags_stretch_ratio = 1.0
	kok.add_child(sag)
	var l2 := Label.new()
	l2.text = "Canlı önizleme (maske + noise)"
	sag.add_child(l2)
	_on2d = TextureRect.new()
	_on2d.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_on2d.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_on2d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sag.add_child(_on2d)
	var b3 := Button.new()
	b3.text = "🏔 3D Önizle (kaydeder + dünyayı kurar, birkaç sn)"
	b3.pressed.connect(_onizle_3d)
	sag.add_child(b3)
	_on3d = TextureRect.new()
	_on3d.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_on3d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sag.add_child(_on3d)

func _arac_sec(a: String) -> void:
	arac = a
	for k: String in _arac_butonlar:
		(_arac_butonlar[k] as Button).set_pressed_no_signal(k == a)
	_durum.text = "Araç: %s" % a

# ======================================================================
# Boyama
# ======================================================================
## Ekran koordinati -> maske pikseli (KEEP_ASPECT_CENTERED hesabi).
func _piksel(pos: Vector2) -> Vector2i:
	var ts := _tuval.size
	var olcek: float = minf(ts.x / float(N), ts.y / float(N))
	var ofs := (ts - Vector2(N, N) * olcek) * 0.5
	var p := (pos - ofs) / maxf(0.001, olcek)
	return Vector2i(floori(p.x), floori(p.y))

func _tuval_girdi(ev: InputEvent) -> void:
	# InputEvent tabanindan alt sinif ozelligi okumak PARSE HATASI verir
	# (bu projede daha once tum dosyayi olduren tuzak) -> once cast.
	var mb := ev as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_undo_kaydet()
			_basili = true
			_darbe(_piksel(mb.position))
		else:
			_basili = false
		return
	var mm := ev as InputEventMouseMotion
	if mm != null and _basili:
		_darbe(_piksel(mm.position))

func _darbe(px: Vector2i) -> void:
	if px.x < 0 or px.y < 0 or px.x >= N or px.y >= N:
		return
	match arac:
		"kova":
			_kova(px)
			_basili = false   # kova tek atim
		_:
			var renk: Color = Color(0, 0, 0, 0) if arac == "silgi" \
					else MapMask.COLORS[boya_id]
			var r := firca_boy
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if dx * dx + dy * dy > r * r:
						continue
					var x := px.x + dx
					var y := px.y + dy
					if x >= 0 and y >= 0 and x < N and y < N:
						mask_img.set_pixel(x, y, renk)
	_tuval_yenile()
	_kirli_onizleme = true

## Kova: ayni SINIFTAKI bitisik bolgeyi doldurur (piksel esitligi degil —
## PNG yumusatmasiyla ayni bolgenin pikselleri milim milim farkli olabilir).
func _kova(px: Vector2i) -> void:
	var hedef := MapMask.classify(mask_img.get_pixel(px.x, px.y))
	var renk: Color = Color(0, 0, 0, 0) if arac == "silgi" \
			else MapMask.COLORS[boya_id]
	var yeni_sinif := MapMask.classify(renk)
	if hedef == yeni_sinif:
		return
	var kuyruk: Array = [px]
	var gezildi: Dictionary = {}
	while not kuyruk.is_empty():
		var c: Vector2i = kuyruk.pop_back()
		if gezildi.has(c) or c.x < 0 or c.y < 0 or c.x >= N or c.y >= N:
			continue
		gezildi[c] = true
		if MapMask.classify(mask_img.get_pixel(c.x, c.y)) != hedef:
			continue
		mask_img.set_pixel(c.x, c.y, renk)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(0, 1), Vector2i(0, -1)]:
			kuyruk.append(c + d)

func _undo_kaydet() -> void:
	_undo.append(mask_img.duplicate())
	while _undo.size() > UNDO_MAX:
		_undo.pop_front()

func _geri_al() -> void:
	if _undo.is_empty():
		_durum.text = "Geri alınacak adım yok"
		return
	mask_img = _undo.pop_back()
	_tuval_yenile()
	_onizleme_yenile()
	_durum.text = "Geri alındı (%d adım kaldı)" % _undo.size()

# ======================================================================
# Onizleme + kaydet
# ======================================================================
func _tuval_yenile() -> void:
	_tuval_tex.update(mask_img)

## 2D biyom onizlemesi: maske + noise'un BIRLESIK sonucu. Her darbede
## degil karede bir (bkz. _process) — 128x128 icin ucuz.
func _onizleme_yenile() -> void:
	var rows := MapMask.apply_img(base_rows, mask_img, MapBalance.SEED_DEFAULT)
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			img.set_pixel(x, y, MapMask.char_color(rows[y][x]))
	if _on2d_tex == null:
		_on2d_tex = ImageTexture.create_from_image(img)
		_on2d.texture = _on2d_tex
	else:
		_on2d_tex.update(img)

func _kaydet() -> void:
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://data"))
	var yol := ProjectSettings.globalize_path(MapMask.PATH)
	var e := mask_img.save_png(yol)
	_durum.text = "Kaydedildi: data/map_mask.png" if e == OK \
			else "KAYDEDILEMEDI (%d)" % e

func _yukle() -> void:
	var im := MapMask.load_image()
	if im == null:
		_durum.text = "Kayıtlı maske yok"
		return
	im.convert(Image.FORMAT_RGBA8)
	_undo_kaydet()
	mask_img = im
	_tuval_yenile()
	_onizleme_yenile()
	_durum.text = "Yüklendi: data/map_mask.png"

## 3D kusbakisi: PAHALI oldugu icin butonla (gorev sarti). Once kaydeder
## (dunya uretimi diskteki maskeyi okur), sonra gercek oyun sahnesini
## bir SubViewport icinde kurar, tepeden bir kare alir, sahneyi bosaltir.
func _onizle_3d() -> void:
	_kaydet()
	_durum.text = "3D kuruluyor... (birkaç sn)"
	OS.set_environment("RABLE_MASK_PREVIEW", "1")
	if _viewport3d != null:
		_viewport3d.queue_free()
	_viewport3d = SubViewport.new()
	_viewport3d.size = Vector2i(640, 640)
	_viewport3d.own_world_3d = true
	_viewport3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport3d)
	var dunya: Node = load("res://scenes/World3D.tscn").instantiate()
	_viewport3d.add_child(dunya)
	# Kurulum + ilk kareler (arazi mesh'i ready'de kuruluyor; birkac kare
	# bekleyip goruntuyu aliyoruz)
	for i in 8:
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	var img := _viewport3d.get_texture().get_image()
	_on3d.texture = ImageTexture.create_from_image(img)
	_viewport3d.queue_free()
	_viewport3d = null
	OS.set_environment("RABLE_MASK_PREVIEW", "")
	_durum.text = "3D önizleme hazır (kayıtlı maskeyle üretildi)"
