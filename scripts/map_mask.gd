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

## Renk sozlugu (gorevdeki 6 sinif). Boyama araci da bu paleti kullanir —
## baska yerde renk tanimi YOK.
const COLORS := {
	"su": Color(0.231, 0.490, 0.769),        # mavi (#3B7DC4, su ailesi)
	"sik_orman": Color(0.118, 0.357, 0.180), # koyu yesil (#1E5B2E)
	"cayir": Color(0.498, 0.749, 0.302),     # acik yesil (#7FBF4D)
	"kayalik": Color(0.541, 0.541, 0.541),   # gri (#8A8A8A)
	"aciklik": Color(0.851, 0.780, 0.604),   # bej (#D9C79A)
	"rezerv": Color(0.557, 0.353, 0.784),    # mor (#8E5AC8)
}
const AD := {
	"su": "Su", "sik_orman": "Sık Orman", "cayir": "Çayır",
	"kayalik": "Kayalık", "aciklik": "Açıklık", "rezerv": "Rezerv",
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
			yeni += _cell_for(id, cur, x, y)
		out.append(yeni)
	return out

## Bir hucrenin maske sinifina gore yeni karakteri. Serbest ("") = uretec
## ne dediyse o. Kurallar BILINCLI yumusak: maske bir REHBER, tarayici
## degil — mevcut dokudan tamamen kopmasin diye her sinif yalnizca kendi
## derdine dokunuyor.
static func _cell_for(id: String, cur: String, x: int, y: int) -> String:
	match id:
		"su":
			return "~"
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
