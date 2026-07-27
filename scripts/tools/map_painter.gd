extends Control
## HARITA RESSAMI v2 — masaustu araci (Godot'ta sahneyi ac, F6).
##
## v2 yenilikleri:
##  - IKI KATMAN: Biyom (map_mask.png) + Yukseklik (height_mask.png)
##  - kum sinifi + "Tumunu Temizle" (onayli)
##  - tekerlek zoom + orta tus / bosluk+surukle pan (tuval VE onizleme,
##    ayni kamera — ikisi ayni yere bakar)
##  - izgara ve dogus/kamp isareti ac-kapa
##  - otomatik dusuk cozunurluklu 3D onizleme (firca birakilinca)
##
## SU SILME AYRIMI (v2'nin ana dersi):
##   Silgi  = "burayi PROSEDURELE birak" — uretec oraya gol koyuyorsa
##            gol GERI GELIR. Su silmek istiyorsan silgi degil,
##   Cayir  = "burasi KESIN KARA" — golu de kiyi kumunu da kaldirir.
## Harita boyutu koddan okunur (base_rows) — buyutme projesi geldiginde
## arac kendiliginden uyar.

const MapMask = preload("res://scripts/map_mask.gd")
const MapGen = preload("res://scripts/map_gen.gd")
const MapBalance = preload("res://scripts/map_balance.gd")

const UNDO_MAX := 10

var n_boy := 128                    # harita boyutu (base_rows'tan okunur)
var mask_img: Image                 # biyom katmani
var height_img: Image               # yukseklik katmani
var base_rows: Array[String] = []
var katman := "biyom"               # biyom | yukseklik
var arac := "firca"                 # firca | silgi | kova
var boya_id := "su"                 # aktif biyom sinifi
var yukseklik_id := "tepe"          # aktif yukseklik kademesi
var firca_boy := 4
var _undo: Array = []               # [{katman, img}]
var _basili := false
var _bosluk := false                # bosluk basili -> pan modu
var _kirli_onizleme := false
var _on3d_mesgul := false
var _oto3d := false

## Ortak kamera: tuval ve 2D onizleme ayni yere bakar.
var kam := {"zoom": 4.0, "pan": Vector2(20, 60)}

var _tuval: Control
var _on2d: Control
var _tuval_tex: ImageTexture
var _on2d_tex: ImageTexture
var _on3d: TextureRect
var _durum: Label
var _zoom_label: Label
var _palet_kutu: HBoxContainer
var _arac_butonlar: Dictionary = {}
var _katman_butonlar: Dictionary = {}
var _izgara := true
var _isaret := true
var _viewport3d: SubViewport = null
var _temizle_onay: ConfirmationDialog

# ======================================================================
# Goruntuleyici (tuval + onizleme ayni widget; boyanabilirlik farki var)
# ======================================================================
class Goruntu extends Control:
	var tex: ImageTexture
	var kam: Dictionary
	var n := 128
	var izgara := false
	var isaret := false
	var spawn := Vector2i(-1, -1)
	var boyanabilir := false
	signal boya(px: Vector2i)
	signal boya_bitti
	signal kam_degisti
	var _pan_surukle := false
	var _sol_basili := false
	var _bosluk_ref: Callable   # ressamin _bosluk durumunu okur

	func _init() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

	func piksel(pos: Vector2) -> Vector2i:
		var z: float = kam["zoom"]
		var p := (pos - Vector2(kam["pan"])) / maxf(0.001, z)
		return Vector2i(floori(p.x), floori(p.y))

	func _gui_input(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
				_zoomla(1.15, mb.position)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
				_zoomla(1.0 / 1.15, mb.position)
			elif mb.button_index == MOUSE_BUTTON_MIDDLE:
				_pan_surukle = mb.pressed
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				var pan_modu: bool = _bosluk_ref.is_valid() and bool(_bosluk_ref.call())
				if mb.pressed and (pan_modu or not boyanabilir):
					_pan_surukle = true
				elif mb.pressed and boyanabilir:
					_sol_basili = true
					boya.emit(piksel(mb.position))
				else:
					_pan_surukle = false
					if _sol_basili:
						_sol_basili = false
						boya_bitti.emit()
			return
		var mm := ev as InputEventMouseMotion
		if mm != null:
			if _pan_surukle:
				kam["pan"] = Vector2(kam["pan"]) + mm.relative
				kam_degisti.emit()
			elif _sol_basili and boyanabilir:
				boya.emit(piksel(mm.position))

	func _zoomla(k: float, odak: Vector2) -> void:
		var eski: float = kam["zoom"]
		var yeni: float = clampf(eski * k, 1.0, 24.0)
		# Zoom imlecin altindaki noktaya kilitli (harita kaymasin)
		kam["pan"] = odak - (odak - Vector2(kam["pan"])) * (yeni / eski)
		kam["zoom"] = yeni
		kam_degisti.emit()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.12, 0.14))
		if tex == null:
			return
		var z: float = kam["zoom"]
		var pan := Vector2(kam["pan"])
		draw_set_transform(pan, 0.0, Vector2(z, z))
		# Saydam bolge icin koyu zemin (serbest = uretec)
		draw_rect(Rect2(0, 0, n, n), Color(0.20, 0.22, 0.20))
		draw_texture(tex, Vector2.ZERO)
		if izgara and z >= 3.0:
			var gc := Color(1, 1, 1, 0.10)
			for i in range(0, n + 1, 8):
				draw_line(Vector2(i, 0), Vector2(i, n), gc, -1)
				draw_line(Vector2(0, i), Vector2(n, i), gc, -1)
		if isaret and spawn.x >= 0:
			# Dogus/kamp isareti: kirmizi halka + arti
			var c := Vector2(spawn) + Vector2(0.5, 0.5)
			draw_arc(c, 3.0, 0, TAU, 24, Color(1, 0.25, 0.25, 0.9), -1)
			draw_line(c - Vector2(4.5, 0), c + Vector2(4.5, 0),
					Color(1, 0.25, 0.25, 0.7), -1)
			draw_line(c - Vector2(0, 4.5), c + Vector2(0, 4.5),
					Color(1, 0.25, 0.25, 0.7), -1)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ======================================================================
func _ready() -> void:
	get_window().title = "Harita Ressamı v2"
	base_rows = MapGen.generate(MapBalance.SEED_DEFAULT)
	n_boy = base_rows.size()
	mask_img = MapMask.load_image()
	var kaynak := "kayıtlı maske"
	if mask_img == null or mask_img.get_width() != n_boy:
		mask_img = MapMask.translate_rows(base_rows)
		kaynak = "mevcut haritadan çeviri"
	mask_img.convert(Image.FORMAT_RGBA8)
	height_img = MapMask.load_height_image()
	if height_img == null or height_img.get_width() != n_boy:
		height_img = Image.create(n_boy, n_boy, false, Image.FORMAT_RGBA8)
	height_img.convert(Image.FORMAT_RGBA8)
	_build_ui()
	_tuval_yenile()
	_onizleme_yenile()
	_durum.text = "Hazır — kaynak: %s" % kaynak

func _process(_d: float) -> void:
	# Onizleme surukleme SIRASINDA da yenilenir (karede bir — v1'de de
	# boyleydi; v2 olcumu: 128x128 apply ~5-10 ms, her karede sorunsuz).
	if _kirli_onizleme:
		_kirli_onizleme = false
		_onizleme_yenile()

func _input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k != null and k.keycode == KEY_SPACE:
		_bosluk = k.pressed

# ======================================================================
# UI
# ======================================================================
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var kok := HBoxContainer.new()
	kok.set_anchors_preset(Control.PRESET_FULL_RECT)
	kok.add_theme_constant_override("separation", 10)
	add_child(kok)

	var sol := VBoxContainer.new()
	sol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sol.size_flags_stretch_ratio = 1.0
	kok.add_child(sol)

	# Katman secimi
	var krow := HBoxContainer.new()
	krow.add_theme_constant_override("separation", 6)
	sol.add_child(krow)
	for kt: Array in [["biyom", "🎨 Biyom"], ["yukseklik", "⛰ Yükseklik"]]:
		var kb := Button.new()
		kb.toggle_mode = true
		kb.text = String(kt[1])
		kb.button_pressed = (String(kt[0]) == "biyom")
		kb.pressed.connect(_katman_sec.bind(String(kt[0])))
		krow.add_child(kb)
		_katman_butonlar[kt[0]] = kb
	var tem := Button.new()
	tem.text = "🗑 Tümünü Temizle"
	tem.pressed.connect(func(): _temizle_onay.popup_centered())
	krow.add_child(tem)
	_temizle_onay = ConfirmationDialog.new()
	_temizle_onay.dialog_text = ("Aktif katmandaki TÜM boyama silinecek "
			+ "(prosedürele döner). Emin misin?")
	_temizle_onay.ok_button_text = "Evet, temizle"
	_temizle_onay.confirmed.connect(_tumunu_temizle)
	add_child(_temizle_onay)

	# Palet (katmana gore yeniden kurulur)
	_palet_kutu = HBoxContainer.new()
	_palet_kutu.add_theme_constant_override("separation", 6)
	sol.add_child(_palet_kutu)
	_palet_kur()

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
	slider.custom_minimum_size = Vector2(110, 0)
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

	# Gorunum satiri
	var vrow := HBoxContainer.new()
	vrow.add_theme_constant_override("separation", 8)
	sol.add_child(vrow)
	var izg := CheckButton.new()
	izg.text = "Izgara"
	izg.set_pressed_no_signal(_izgara)
	izg.toggled.connect(func(on: bool):
		_izgara = on
		_goruntuleri_tazele())
	vrow.add_child(izg)
	var isr := CheckButton.new()
	isr.text = "Doğuş işareti"
	isr.set_pressed_no_signal(_isaret)
	isr.toggled.connect(func(on: bool):
		_isaret = on
		_goruntuleri_tazele())
	vrow.add_child(isr)
	_zoom_label = Label.new()
	_zoom_label.text = "Zoom: 4.0x"
	vrow.add_child(_zoom_label)

	# Tuval
	_tuval = _goruntu_kur(true)
	sol.add_child(_tuval)
	_durum = Label.new()
	_durum.text = "Hazır"
	sol.add_child(_durum)

	# --- SAG ---
	var sag := VBoxContainer.new()
	sag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sag.size_flags_stretch_ratio = 1.0
	kok.add_child(sag)
	var l2 := Label.new()
	l2.text = "Canlı önizleme (maske + noise) — aynı kamera"
	sag.add_child(l2)
	_on2d = _goruntu_kur(false)
	sag.add_child(_on2d)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 8)
	sag.add_child(brow)
	var b3 := Button.new()
	b3.text = "🏔 3D Önizle (tam)"
	b3.pressed.connect(func(): _onizle_3d(false))
	brow.add_child(b3)
	var oto := CheckButton.new()
	oto.text = "3D otomatik (düşük çözünürlük, fırça bırakınca)"
	oto.toggled.connect(func(on: bool): _oto3d = on)
	brow.add_child(oto)
	_on3d = TextureRect.new()
	_on3d.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_on3d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sag.add_child(_on3d)

func _goruntu_kur(boyanabilir: bool) -> Control:
	var g := Goruntu.new()
	g.kam = kam
	g.n = n_boy
	g.izgara = _izgara
	g.isaret = _isaret
	g.spawn = _dogus_bul()
	g.boyanabilir = boyanabilir
	g._bosluk_ref = func() -> bool: return _bosluk
	g.kam_degisti.connect(_kam_guncellendi)
	if boyanabilir:
		g.boya.connect(_darbe)
		g.boya_bitti.connect(_darbe_bitti)
	return g

func _dogus_bul() -> Vector2i:
	for y in n_boy:
		var x := base_rows[y].find("P")
		if x != -1:
			return Vector2i(x, y)
	return Vector2i(n_boy / 2, n_boy / 2)

func _kam_guncellendi() -> void:
	_zoom_label.text = "Zoom: %.1fx" % float(kam["zoom"])
	_goruntuleri_tazele()

func _goruntuleri_tazele() -> void:
	for g in [_tuval, _on2d]:
		if g != null:
			(g as Goruntu).izgara = _izgara
			(g as Goruntu).isaret = _isaret
			g.queue_redraw()

## Katman degisince palet yeniden kurulur.
func _palet_kur() -> void:
	for c in _palet_kutu.get_children():
		c.queue_free()
	if katman == "biyom":
		for id: String in MapMask.COLORS:
			_palet_butonu(String(MapMask.AD[id]), Color(MapMask.COLORS[id]),
					func(): _biyom_sec(id))
	else:
		_palet_butonu("Alçak*", Color(MapMask.H_ALCAK),
				func(): _yukseklik_sec("alcak"))
		_palet_butonu("Normal (düzle)", Color(MapMask.H_NORMAL),
				func(): _yukseklik_sec("normal"))
		_palet_butonu("Tepe", Color(MapMask.H_TEPE),
				func(): _yukseklik_sec("tepe"))

func _palet_butonu(ad: String, renk: Color, cb: Callable) -> void:
	var b := Button.new()
	b.text = ad
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = renk
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_color_override("font_color",
			Color.WHITE if renk.get_luminance() < 0.6 else Color.BLACK)
	b.pressed.connect(cb)
	_palet_kutu.add_child(b)

func _biyom_sec(id: String) -> void:
	boya_id = id
	if arac == "silgi":
		_arac_sec("firca")
	_durum.text = "Renk: %s" % String(MapMask.AD[id])

func _yukseklik_sec(id: String) -> void:
	yukseklik_id = id
	if arac == "silgi":
		_arac_sec("firca")
	_durum.text = "Kademe: %s" % String(MapMask.H_AD[id]) \
			+ ("  (* Alçak bugün Normal ile aynı davranır)" if id == "alcak" else "")

func _katman_sec(kt: String) -> void:
	katman = kt
	for k: String in _katman_butonlar:
		(_katman_butonlar[k] as Button).set_pressed_no_signal(k == kt)
	_palet_kur()
	_tuval_yenile()
	_durum.text = "Katman: %s" % ("Biyom" if kt == "biyom" else "Yükseklik")

func _arac_sec(a: String) -> void:
	arac = a
	for k: String in _arac_butonlar:
		(_arac_butonlar[k] as Button).set_pressed_no_signal(k == a)
	_durum.text = "Araç: %s" % a

func _aktif_img() -> Image:
	return mask_img if katman == "biyom" else height_img

func _aktif_renk() -> Color:
	if arac == "silgi":
		return Color(0, 0, 0, 0)
	if katman == "biyom":
		return MapMask.COLORS[boya_id]
	match yukseklik_id:
		"alcak": return Color(MapMask.H_ALCAK)
		"tepe": return Color(MapMask.H_TEPE)
	return Color(MapMask.H_NORMAL)

# ======================================================================
# Boyama
# ======================================================================
var _darbe_undo_alindi := false

func _darbe(px: Vector2i) -> void:
	if px.x < 0 or px.y < 0 or px.x >= n_boy or px.y >= n_boy:
		return
	if not _darbe_undo_alindi:
		_undo_kaydet()
		_darbe_undo_alindi = true
	var img := _aktif_img()
	match arac:
		"kova":
			_kova(img, px)
		_:
			var renk := _aktif_renk()
			var r := firca_boy
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if dx * dx + dy * dy > r * r:
						continue
					var x := px.x + dx
					var y := px.y + dy
					if x >= 0 and y >= 0 and x < n_boy and y < n_boy:
						img.set_pixel(x, y, renk)
	_tuval_yenile()
	_kirli_onizleme = true

func _darbe_bitti() -> void:
	_darbe_undo_alindi = false
	if _oto3d:
		_onizle_3d(true)

## Kova: ayni SINIFTAKI bitisik bolgeyi doldurur.
func _kova(img: Image, px: Vector2i) -> void:
	var sinif := func(c: Color) -> String:
		return MapMask.classify(c) if katman == "biyom" \
				else MapMask.height_classify(c)
	var hedef := String(sinif.call(img.get_pixel(px.x, px.y)))
	var renk := _aktif_renk()
	if String(sinif.call(renk)) == hedef:
		return
	var kuyruk: Array = [px]
	var gezildi: Dictionary = {}
	while not kuyruk.is_empty():
		var c: Vector2i = kuyruk.pop_back()
		if gezildi.has(c) or c.x < 0 or c.y < 0 or c.x >= n_boy or c.y >= n_boy:
			continue
		gezildi[c] = true
		if String(sinif.call(img.get_pixel(c.x, c.y))) != hedef:
			continue
		img.set_pixel(c.x, c.y, renk)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(0, 1), Vector2i(0, -1)]:
			kuyruk.append(c + d)

func _undo_kaydet() -> void:
	_undo.append({"katman": katman, "img": _aktif_img().duplicate()})
	while _undo.size() > UNDO_MAX:
		_undo.pop_front()

func _geri_al() -> void:
	if _undo.is_empty():
		_durum.text = "Geri alınacak adım yok"
		return
	var son: Dictionary = _undo.pop_back()
	if String(son["katman"]) == "biyom":
		mask_img = son["img"]
	else:
		height_img = son["img"]
	_tuval_yenile()
	_onizleme_yenile()
	_durum.text = "Geri alındı (%d adım kaldı)" % _undo.size()

func _tumunu_temizle() -> void:
	_undo_kaydet()
	_aktif_img().fill(Color(0, 0, 0, 0))
	_tuval_yenile()
	_onizleme_yenile()
	_durum.text = "Katman temizlendi (prosedürele döndü) — Geri Al mümkün"

# ======================================================================
# Onizleme + kayit
# ======================================================================
func _tuval_yenile() -> void:
	var img := _aktif_img()
	if _tuval_tex == null:
		_tuval_tex = ImageTexture.create_from_image(img)
	else:
		_tuval_tex.set_image(img)   # katman degisebilir: update degil set
	(_tuval as Goruntu).tex = _tuval_tex
	_tuval.queue_redraw()

func _onizleme_yenile() -> void:
	var rows := MapMask.apply_img(base_rows, mask_img, MapBalance.SEED_DEFAULT)
	rows = MapMask.apply_height_img(rows, height_img, MapBalance.SEED_DEFAULT)
	var img := Image.create(n_boy, n_boy, false, Image.FORMAT_RGBA8)
	for y in n_boy:
		for x in n_boy:
			img.set_pixel(x, y, MapMask.char_color(rows[y][x]))
	if _on2d_tex == null:
		_on2d_tex = ImageTexture.create_from_image(img)
	else:
		_on2d_tex.update(img)
	(_on2d as Goruntu).tex = _on2d_tex
	_on2d.queue_redraw()

func _kaydet() -> void:
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://data"))
	var e1 := mask_img.save_png(ProjectSettings.globalize_path(MapMask.PATH))
	var e2 := height_img.save_png(
			ProjectSettings.globalize_path(MapMask.HEIGHT_PATH))
	_durum.text = "Kaydedildi: map_mask.png + height_mask.png" \
			if e1 == OK and e2 == OK else "KAYDEDILEMEDI (%d/%d)" % [e1, e2]

func _yukle() -> void:
	var im := MapMask.load_image()
	var him := MapMask.load_height_image()
	if im == null and him == null:
		_durum.text = "Kayıtlı maske yok"
		return
	_undo_kaydet()
	if im != null:
		im.convert(Image.FORMAT_RGBA8)
		mask_img = im
	if him != null:
		him.convert(Image.FORMAT_RGBA8)
		height_img = him
	_tuval_yenile()
	_onizleme_yenile()
	_durum.text = "Yüklendi (iki katman)"

## 3D kusbakisi. dusuk=true: firca birakilinca otomatik kosulan hizli
## surum (320px). Tam kalite butonu 640px.
func _onizle_3d(dusuk: bool) -> void:
	if _on3d_mesgul:
		return
	_on3d_mesgul = true
	_kaydet()
	_durum.text = "3D kuruluyor%s..." % (" (hızlı)" if dusuk else "")
	OS.set_environment("RABLE_MASK_PREVIEW", "1")
	if _viewport3d != null:
		_viewport3d.queue_free()
	_viewport3d = SubViewport.new()
	_viewport3d.size = Vector2i(320, 320) if dusuk else Vector2i(640, 640)
	_viewport3d.own_world_3d = true
	_viewport3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport3d)
	var dunya: Node = load("res://scenes/World3D.tscn").instantiate()
	_viewport3d.add_child(dunya)
	for i in 8:
		await get_tree().process_frame
	await get_tree().create_timer(0.4 if dusuk else 0.8).timeout
	var img := _viewport3d.get_texture().get_image()
	_on3d.texture = ImageTexture.create_from_image(img)
	_viewport3d.queue_free()
	_viewport3d = null
	OS.set_environment("RABLE_MASK_PREVIEW", "")
	_on3d_mesgul = false
	_durum.text = "3D önizleme hazır (%s)" % ("hızlı" if dusuk else "tam")
