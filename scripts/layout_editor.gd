extends RefCounted
## YERLESIM EDITORU — veri katmani (JSON okuma/yazma + arac tanimlari).
## UI hud.gd'de, sahne islemleri world3d.gd'de. Bu dosya OYUN MANTIGI
## ICERMEZ: yalnizca "duzen nasil saklanir" sorusuna cevap verir.
##
## GELISTIRICI ARACI: yalnizca debug build'de ya da TestMode acikken
## gorunur (bkz. hud.gd). Yayin surumune sizmaz.
##
## NEDEN GOREL (relative) HUCRE:
## Kamp merkezi TOHUMA bagli — her yeni dunyada baska bir hucrede.
## Mutlak hucre yazilsaydi disa aktarilan duzen yalniz o tohumda dogru
## olurdu. Bu yuzden her ogenin hucresi KAMP MERKEZINE GORE ofset olarak
## saklanir; dunya kurulurken merkeze eklenir.

const SURUM := 1
## Oyunun okudugu dosya (repoda). VARSA baslangic kampi bundan kurulur.
const RES_PATH := "res://data/camp_layout.json"
## Editorun yazdigi dosya (cihazda). Kullanici bunu alip repoya tasir.
const USER_PATH := "user://camp_layout.json"

# --- Araclar -------------------------------------------------------------
const ARAC_YERLESTIR := "yerlestir"
const ARAC_SEC := "sec"
const ARAC_SIL := "sil"
const ARAC_YOL := "yol"

const ARAC_ADI := {
	ARAC_YERLESTIR: "Yerleştir",
	ARAC_SEC: "Seç / Taşı",
	ARAC_SIL: "Sil",
	ARAC_YOL: "Yol Fırçası",
}

## Geri al derinligi (gorevde 10).
const UNDO_MAX := 10

## Dekor olcek kaydiricisi sinirlari (±%10, yalniz dekor).
const OLCEK_MIN := 0.90
const OLCEK_MAX := 1.10

# --- Kategoriler (YERLESTIR listesi) -------------------------------------
## id'ler oyunun kendi kayitlarindan geliyor: "yapi" -> world3d.PLACE_MODELS,
## "dekor" -> EnvModels.PATHS. Burada yalnizca EDITORDE SUNULAN alt kume
## ve gosterim adi var; yeni bir model kaydi TANIMLANMIYOR.
const KATEGORILER := [
	{"id": "yapi", "ad": "Yapılar",
			"ogeler": ["ocak", "sandik", "arastirma_masasi", "yatak",
					"duvar", "kapi", "mesale"]},
	{"id": "yol", "ad": "Yol", "ogeler": ["yol_hucresi"]},
	{"id": "dekor", "ad": "Dekor",
			"ogeler": ["ruined_hut", "ruined_well", "grass_tuft",
					"pebble_cluster", "twig_debris", "planting_mound"]},
	{"id": "tarla", "ad": "Tarla", "ogeler": ["tarla_hucresi"]},
]

# --- JSON ----------------------------------------------------------------
## Bos duzen iskeleti.
static func bos_duzen() -> Dictionary:
	return {"surum": SURUM, "aciklama": "Kamp yerlesimi (yerlesim editoru)",
			"ogeler": []}

## Bir ogeyi standart bicime sokar. Hucre GORELDIR (merkeze gore ofset).
static func oge(tur: String, id: String, ofset: Vector2i,
		rot: int = 0, olcek: float = 1.0, varyant: String = "") -> Dictionary:
	var d: Dictionary = {
		"tur": tur, "id": id,
		"hucre": [ofset.x, ofset.y],
		"rot": rot,
	}
	# Varsayilan degerler yazilmiyor: dosya insan gozuyle okunacak,
	# her satirda "olcek": 1.0 gormek gurultu.
	if not is_equal_approx(olcek, 1.0):
		d["olcek"] = snappedf(olcek, 0.01)
	if varyant != "":
		d["varyant"] = varyant
	return d

static func ofset_of(o: Dictionary) -> Vector2i:
	var h: Array = o.get("hucre", [0, 0])
	return Vector2i(int(h[0]), int(h[1]))

## Dosyaya yaz. INSAN OKUR bicim: girintili JSON, ogeler tur/hucre
## sirasina gore dizili (elle bakip duzeltmek icin).
static func yaz(yol: String, duzen: Dictionary) -> bool:
	var ogeler: Array = duzen.get("ogeler", [])
	ogeler.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if String(a.get("tur", "")) != String(b.get("tur", "")):
			return String(a.get("tur", "")) < String(b.get("tur", ""))
		var ah: Array = a.get("hucre", [0, 0])
		var bh: Array = b.get("hucre", [0, 0])
		if int(ah[1]) != int(bh[1]):
			return int(ah[1]) < int(bh[1])
		return int(ah[0]) < int(bh[0]))
	duzen["ogeler"] = ogeler
	duzen["surum"] = SURUM
	var f := FileAccess.open(yol, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(duzen, "  "))
	f.close()
	return true

## Dosyayi oku. Yoksa/bozuksa BOS SOZLUK doner — cagiran taraf
## fallback'e (kodlanmis kamp) duser.
static func oku(yol: String) -> Dictionary:
	if not FileAccess.file_exists(yol):
		return {}
	var f := FileAccess.open(yol, FileAccess.READ)
	if f == null:
		return {}
	var metin := f.get_as_text()
	f.close()
	var v: Variant = JSON.parse_string(metin)
	if typeof(v) != TYPE_DICTIONARY:
		push_warning("camp_layout.json okunamadi: %s" % yol)
		return {}
	var d: Dictionary = v
	if not d.has("ogeler"):
		return {}
	return d

## Oyunun kullanacagi duzen: once repodaki dosya, yoksa bos.
static func oyun_duzeni() -> Dictionary:
	return oku(RES_PATH)
