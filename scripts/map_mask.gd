extends RefCounted
## HARITA MASKESI — data/map_mask.png dunya uretimine REHBER olur.
##
## MANTIK: MapGen.generate() normal kosuyor, maske SONRADAN bir gecis
## olarak biniyor (apply). Boylece:
##   - dosya yoksa oyun BIREBIR eski davranista (fallback bedava),
##   - uretecin ic mantigina dokunulmuyor,
##   - test saf fonksiyon uzerinden kosabiliyor (dunya durumu gerekmez).
##
## KENAR ORGANIKLIGI: maske pikseli dogrudan okunmaz; ornekleme noktasi
## noise ile +-WARP_CELLS kaydirilir (domain warp). Cizilen keskin kare
## kenar oyuna sacakli/organik gecer — birebir kopyalanmaz (gorev sarti).
##
## 1 piksel = 1 hucre (128x128). Palet disindaki her renk ve saydam
## piksel "serbest" sayilir: o hucrede uretec ne dediyse o kalir.

const PATH := "res://data/map_mask.png"
const HEIGHT_PATH := "res://data/height_mask.png"
## harita-master: sis yogunlugu katmani (gri tonlama; 0=acik, 255=zifiri).
## Dosya yoksa kesif sistemi halka fallback'ini kullanir (kesif_balance).
const FOG_PATH := "res://data/fog_mask.png"
const MB = preload("res://scripts/map_balance.gd")

## Renk sozlugu (gorevdeki 6 sinif). Boyama araci da bu paleti kullanir —
## baska yerde renk tanimi YOK.
const COLORS := {
	"su": Color(0.231, 0.490, 0.769),        # mavi (#3B7DC4, su ailesi)
	"sik_orman": Color(0.118, 0.357, 0.180), # koyu yesil (#1E5B2E)
	"cayir": Color(0.498, 0.749, 0.302),     # acik yesil (#7FBF4D)
	"kayalik": Color(0.541, 0.541, 0.541),   # gri (#8A8A8A)
	"aciklik": Color(0.851, 0.780, 0.604),   # bej (#D9C79A)
	"rezerv": Color(0.557, 0.353, 0.784),    # mor (#8E5AC8)
	"kum": Color(0.910, 0.835, 0.639),       # kum beji (#E8D5A3) — v2
}
const AD := {
	"su": "Su", "sik_orman": "Sık Orman", "cayir": "Çayır",
	"kayalik": "Kayalık", "aciklik": "Açıklık", "rezerv": "Rezerv",
	"kum": "Kum",
}

## Piksel bu uzakliktan yakinsa palete oturur; degilse serbest.
## (PNG sikistirmasi/yumusatma renkleri hafif oynatabilir.)
const CLASSIFY_MAX_DIST := 0.22

## Kenar organikligi: ornekleme noktasi bu kadar hucre oynar.
const WARP_CELLS := 2.5
const WARP_FREQ := 0.07

## Biyom yogunluklari (deterministik hash ile, RNG yok — ayni maske +
## ayni seed her zaman ayni haritayi verir).
const ORMAN_AGAC := 0.55     # sik_orman: bos cim/toprak hucresi agac olma sansi
const CAYIR_AGAC_KALSIN := 0.06  # cayir: mevcut agacin kalma sansi (tek tuk)
const KAYALIK_KAYA := 0.14   # kayalik: bos hucre kaya olma sansi
## Dogus cevresi maske DINLEMEZ (r hucre): su/orman dogusa binerse oyun
## acilamaz hale gelirdi. RAPOR'da belirtiliyor.
const SPAWN_KORUMA_R := 6

static func load_image() -> Image:
	if ResourceLoader.exists(PATH):
		var tex: Variant = load(PATH)
		if tex is Texture2D:
			return (tex as Texture2D).get_image()
	# Editor tarafinda HENUZ import edilmemis taze kayit (ressam az once
	# yazdi, F5'e basildi): dogrudan dosyadan oku.
	var gp := ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(gp):
		var im := Image.new()
		if im.load(gp) == OK:
			return im
	return null

## Rengi palete oturt. "" = serbest (palet disi / saydam).
static func classify(c: Color) -> String:
	if c.a < 0.5:
		return ""
	var best := ""
	var bd := CLASSIFY_MAX_DIST
	for id: String in COLORS:
		var p: Color = COLORS[id]
		var d: float = absf(c.r - p.r) + absf(c.g - p.g) + absf(c.b - p.b)
		if d < bd:
			bd = d
			best = id
	return best

## Deterministik 0..1 (proje genelindeki ayni cekirdek).
static func hash01(x: int, y: int, salt: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	return float(absi(h) % 100003) / 100003.0

## Maske uygulanmis satirlar. img null ise DOKUNMADAN geri doner.
static func apply(rows: Array[String], seed_val: int) -> Array[String]:
	var img := load_image()
	if img == null:
		return rows
	return apply_img(rows, img, seed_val)

static func apply_img(rows: Array[String], img: Image,
		seed_val: int) -> Array[String]:
	var n := rows.size()
	if n == 0 or img == null:
		return rows
	# Domain warp: iki eksen icin iki noise (ayni noise iki eksende
	# kullanilinca kayma kosegene yapisir).
	var wa := FastNoiseLite.new()
	wa.seed = seed_val + 71
	wa.noise_type = FastNoiseLite.TYPE_SIMPLEX
	wa.frequency = WARP_FREQ
	var wb := FastNoiseLite.new()
	wb.seed = seed_val + 97
	wb.noise_type = FastNoiseLite.TYPE_SIMPLEX
	wb.frequency = WARP_FREQ
	# Dogus hucresi ("P") koruma merkezi
	var spawn := Vector2i(n / 2, n / 2)
	for y in n:
		var x := rows[y].find("P")
		if x != -1:
			spawn = Vector2i(x, y)
			break
	var out: Array[String] = []
	var maske_su: Array[Vector2i] = []   # otomatik kiyi bandi icin
	for y in n:
		var satir := rows[y]
		var yeni := ""
		for x in n:
			var cur := satir[x]
			# Kenar kusagi (kumsal halkasi) ve dogus isareti dokunulmaz
			if x == 0 or y == 0 or x == n - 1 or y == n - 1 or cur == "P":
				yeni += cur
				continue
			var sd := Vector2i(x, y) - spawn
			if sd.x * sd.x + sd.y * sd.y <= SPAWN_KORUMA_R * SPAWN_KORUMA_R:
				yeni += cur
				continue
			# Organik ornekleme: maske pikseli warp'lu noktadan okunur
			var sx := clampi(x + roundi(wa.get_noise_2d(x, y) * WARP_CELLS),
					0, img.get_width() - 1)
			var sy := clampi(y + roundi(wb.get_noise_2d(x, y) * WARP_CELLS),
					0, img.get_height() - 1)
			var id := classify(img.get_pixel(sx, sy))
			if id == "su" and cur != "~":
				maske_su.append(Vector2i(x, y))
			yeni += _cell_for(id, cur, x, y)
		out.append(yeni)
	return _kiyi_bandi(out, maske_su)

## OTOMATIK KUM BANDI (v2): maskeyle YENI acilan su hucrelerinin cevresine
## kum. Uretecin kendi golu zaten kendi kumunu koyuyor (SHORE_WIDTH) —
## genislik ORADAN turetiliyor, ikinci bir "kiyi genisligi" tanimi yok
## (tek kaynak sarti). Elle boyanan kum bunun USTUNE genisletme olarak
## biner: kum sinifi hucreyi dogrudan "s" yapar, bant yalniz cim/topragi
## kuma cevirir (agaca/kayaya dokunmaz).
static func _kiyi_bandi(out: Array[String],
		maske_su: Array[Vector2i]) -> Array[String]:
	if maske_su.is_empty():
		return out
	var n := out.size()
	# DUZ tampon (idx=y*n+x): Array icindeki PackedByteArray'e indeksle
	# yazmak KALICI DEGIL (copy-on-write) — map_gen.gd'nin bastaki dersi.
	var buf := PackedByteArray()
	buf.resize(n * n)
	for y in n:
		var rb := out[y].to_ascii_buffer()
		for x in n:
			buf[y * n + x] = rb[x]
	var taban := maxi(1, int(round(MB.SHORE_WIDTH)) - 1)
	for c: Vector2i in maske_su:
		# Hucre basina genislik oynar (kiyi cizgisi duz serit olmasin)
		var w := taban + (1 if hash01(c.x, c.y, 829) < 0.5 else 0)
		for dy in range(-w, w + 1):
			for dx in range(-w, w + 1):
				if dx * dx + dy * dy > w * w:
					continue
				var x := c.x + dx
				var y := c.y + dy
				if x < 1 or y < 1 or x >= n - 1 or y >= n - 1:
					continue
				var b := buf[y * n + x]
				if b == 46 or b == 100:   # "." | "d"
					buf[y * n + x] = 115  # "s"
	var sonuc: Array[String] = []
	for y in n:
		sonuc.append(buf.slice(y * n, y * n + n).get_string_from_ascii())
	return sonuc

## Bir hucrenin maske sinifina gore yeni karakteri. Serbest ("") = uretec
## ne dediyse o. Kurallar BILINCLI yumusak: maske bir REHBER, tarayici
## degil — mevcut dokudan tamamen kopmasin diye her sinif yalnizca kendi
## derdine dokunuyor.
static func _cell_for(id: String, cur: String, x: int, y: int) -> String:
	# KARA ZORLAMA (v2 — su silme bugunun cozumu): su/kum DISINDAKI her
	# sinif once suyu ve kiyi kumunu KARAYA cevirir. Onceki halde cayir
	# yalniz agac/kayaya dokunuyordu; golun ustune cayir boyamak golu
	# SILMIYORDU (silgi de silmez: silgi = "uretec karar versin", uretec
	# de oraya yine gol koyar). Artik: silgi = proseduerele birak,
	# cayir/aciklik/orman/kayalik/rezerv = BURASI KESIN KARA.
	if id != "" and id != "su" and id != "kum" \
			and (cur == "~" or cur == "s" or cur == "k"):
		cur = "."
	match id:
		"su":
			return "~"
		"kum":
			# Elle kumsal: su dahil her seyi kuma cevirir (golu doldurur)
			return "s"
		"aciklik":
			# Bej açıklık: engelsiz duz cim (kamp acikligi hissi)
			if cur in ["T", "#", "m", "h", "d"]:
				return "."
			return cur
		"cayir":
			# Cimen: agaclar tek tuk kalir, kaya/plato temizlenir
			if cur == "T":
				return "T" if hash01(x, y, 811) < CAYIR_AGAC_KALSIN else "."
			if cur in ["#", "h"]:
				return "."
			return cur
		"sik_orman":
			if cur in [".", "d"] and hash01(x, y, 821) < ORMAN_AGAC:
				return "T"
			return cur
		"kayalik":
			if cur in [".", "d"] and hash01(x, y, 823) < KAYALIK_KAYA:
				return "#"
			if cur == "T" and hash01(x, y, 827) < 0.5:
				return "."   # kayalikta orman seyrelir
			return cur
		"rezerv":
			# Mor: ilerideki icerik icin AYRILMIS bos alan — engel yok
			if cur in ["T", "#", "m"]:
				return "."
			return cur
	return cur

# =======================================================================
# YUKSEKLIK KATMANI (v2)
# =======================================================================
## Ikinci maske: data/height_mask.png, gri tonlari. Ressamdaki 3 kademe:
##   alcak(0) = koyu gri, normal(1) = orta gri, tepe(2) = acik gri;
##   saydam = serbest (uretec karar verir).
## DONUSTURUCU (muhafazakar — RAPOR'da gerekcesi):
##   tepe   -> "h" (mevcut plato sistemi: falez kenarlari, arazi rengi,
##             katilik — hepsi hazir; yeni bir yukseklik alani ACILMADI)
##   normal -> "h" temizle (plato yasagi, duz zemin garantisi)
##   alcak  -> bugun normal ile AYNI davranir. Gercek cukur/teras tabani
##             ayri bir arazi projesi; maske formati 3 kademeyi simdiden
##             sakliyor, o proje gelince veri hazir.
## KAZI UYUMU NOTU: "h" hucreleri mevcut sistemde KATI (uzerine cikilmaz,
## kazilmaz). "Yukseltilmis ama kazilabilir zemin" bugunku arazide yok —
## bunu taklit etmeye kalkmak (ornegin depth=-2 baslangici) kazi yiginini
## kahverengi tumsek olarak cizer ve kayit deltalariyla catisirdi.
## Muhafazakar karar: tepe = plato. RAPOR_HARITA2'de acikca yaziyor.
const H_ALCAK := Color(0.10, 0.10, 0.10)
const H_NORMAL := Color(0.50, 0.50, 0.50)
const H_TEPE := Color(0.95, 0.95, 0.95)
const H_AD := {"alcak": "Alçak", "normal": "Normal", "tepe": "Tepe"}

static func load_height_image() -> Image:
	if ResourceLoader.exists(HEIGHT_PATH):
		var tex: Variant = load(HEIGHT_PATH)
		if tex is Texture2D:
			return (tex as Texture2D).get_image()
	var gp := ProjectSettings.globalize_path(HEIGHT_PATH)
	if FileAccess.file_exists(gp):
		var im := Image.new()
		if im.load(gp) == OK:
			return im
	return null

static func height_classify(c: Color) -> String:
	if c.a < 0.5:
		return ""
	var v := c.r
	if v < 0.30:
		return "alcak"
	if v > 0.70:
		return "tepe"
	return "normal"

static func apply_height(rows: Array[String], seed_val: int) -> Array[String]:
	var img := load_height_image()
	if img == null:
		return rows
	return apply_height_img(rows, img, seed_val)

static func apply_height_img(rows: Array[String], img: Image,
		seed_val: int) -> Array[String]:
	var n := rows.size()
	if n == 0 or img == null:
		return rows
	var wa := FastNoiseLite.new()
	wa.seed = seed_val + 113
	wa.noise_type = FastNoiseLite.TYPE_SIMPLEX
	wa.frequency = WARP_FREQ
	var wb := FastNoiseLite.new()
	wb.seed = seed_val + 131
	wb.noise_type = FastNoiseLite.TYPE_SIMPLEX
	wb.frequency = WARP_FREQ
	var spawn := Vector2i(n / 2, n / 2)
	for y in n:
		var x := rows[y].find("P")
		if x != -1:
			spawn = Vector2i(x, y)
			break
	var out: Array[String] = []
	for y in n:
		var satir := rows[y]
		var yeni := ""
		for x in n:
			var cur := satir[x]
			if x == 0 or y == 0 or x == n - 1 or y == n - 1 or cur == "P":
				yeni += cur
				continue
			var sd := Vector2i(x, y) - spawn
			if sd.x * sd.x + sd.y * sd.y <= SPAWN_KORUMA_R * SPAWN_KORUMA_R:
				yeni += cur
				continue
			var sx := clampi(x + roundi(wa.get_noise_2d(x, y) * WARP_CELLS),
					0, img.get_width() - 1)
			var sy := clampi(y + roundi(wb.get_noise_2d(x, y) * WARP_CELLS),
					0, img.get_height() - 1)
			match height_classify(img.get_pixel(sx, sy)):
				"tepe":
					# Su/kuma tepe koymuyoruz: falez suya girmesin
					if cur in [".", "d", "T", "#", "m"]:
						yeni += "h"
					else:
						yeni += cur
				"normal", "alcak":
					yeni += "." if cur == "h" else cur
				_:
					yeni += cur
		out.append(yeni)
	return out

## Char -> onizleme rengi (boyama aracinin sag paneli ve ilk ceviri
## icin). Oyunun gercek renkleri degil, okunakli harita paleti.
const CHAR_RENK := {
	".": Color(0.55, 0.75, 0.38), "d": Color(0.62, 0.50, 0.34),
	"s": Color(0.87, 0.80, 0.60), "k": Color(0.72, 0.58, 0.44),
	"~": Color(0.30, 0.55, 0.85), "h": Color(0.58, 0.60, 0.55),
	"#": Color(0.45, 0.45, 0.45), "T": Color(0.16, 0.42, 0.22),
	"m": Color(0.45, 0.65, 0.30), "P": Color(1.0, 0.35, 0.35),
}

static func char_color(ch: String) -> Color:
	return CHAR_RENK.get(ch, Color(0.5, 0.5, 0.5))

## MEVCUT haritanin yaklasik maske cevirisi (boyama araci bos sayfa
## acmasin). Uretec ciktisi sinif renklerine indirgenir, sonra 3x3
## cogunluk suzgeciyle lekelesir (piksel gurultusu degil boyanabilir
## bloblar kalsin).
static func translate_rows(rows: Array[String]) -> Image:
	var n := rows.size()
	# Tek gecis: char -> sinif id'si (index tablosu)
	var ids: Array = []
	var id_of := func(ch: String) -> String:
		match ch:
			"~": return "su"
			"s", "k": return "aciklik"
			"T": return "sik_orman"
			"#", "h": return "kayalik"
			_: return "cayir"
	for y in n:
		var row_ids: Array = []
		for x in n:
			row_ids.append(id_of.call(rows[y][x]))
		ids.append(row_ids)
	# 3x3 cogunluk (lekelesme)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var say: Dictionary = {}
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var yy := clampi(y + dy, 0, n - 1)
					var xx := clampi(x + dx, 0, n - 1)
					var id2: String = ids[yy][xx]
					say[id2] = int(say.get(id2, 0)) + 1
			var top := ""
			var topn := 0
			for k2: String in say:
				if int(say[k2]) > topn:
					topn = int(say[k2])
					top = k2
			img.set_pixel(x, y, COLORS[top])
	return img


## harita-master: sis maskesi. load_height_image ile ayni iki asamali
## yol (import edilmis kaynak -> ham dosya fallback).
static func load_fog_image() -> Image:
	if ResourceLoader.exists(FOG_PATH):
		var tex: Variant = load(FOG_PATH)
		if tex is Texture2D:
			return (tex as Texture2D).get_image()
	var gp := ProjectSettings.globalize_path(FOG_PATH)
	if FileAccess.file_exists(gp):
		var img := Image.new()
		if img.load(gp) == OK:
			return img
	return null

## Hucredeki sis yogunlugu (0..1). Maske sinir disinda kalirsa 1 (zifir
## kenar kusagi — haritadan cikis yonu her zaman sisli).
static func fog_at(img: Image, cell: Vector2i) -> float:
	if img == null:
		return -1.0
	if cell.x < 0 or cell.y < 0 \
			or cell.x >= img.get_width() or cell.y >= img.get_height():
		return 1.0
	return img.get_pixel(cell.x, cell.y).r
