extends RefCounted
## KESIF DENGE VERISI (KESIF.md Bolum 16). TUM sayilar burada — kod
## dokunmadan elle ayarlanir. Halka matematigi de burada: "hucrenin
## halkasi" sorusu tek kaynaktan cevaplanir.
##
## HARITA OLCEGI NOTU: 16.8 "Halka 3 = 2-3 gece yuruyus" ister; 128x128
## haritada merkez-kose ~90 hucre, bu mesafeler SIKISIK. Halka orantilari
## korunuyor, gercek genisletme ayri gorev (harita-master Asama 0).
## Yaricaplar buyuyen haritada SADECE bu tablodan degisir.

# --- 16.1 Halkalar --------------------------------------------------------
## Halka siniri = Ocak'tan Oklid mesafesi (hucre). Son halka acik uclu.
const RING_R := [16.0, 30.0, 46.0]      # R0 | R1 | R2 siniri; otesi R3
const RING_COUNT := 4

## Halka basina sis yogunlugu (0..1). R0 Yuva'da sis YOK.
const SIS := [0.0, 0.25, 0.6, 1.0]

## Halka basina gereken tasinabilir isik kademesi (16.1 tablosu):
## 0=hic, 1=mesale K1, 2=kor feneri K2, 3=koz kabi K3.
const GEREKEN_ISIK := [0, 1, 2, 3]

## Isik kademesi -> envanter esyasi (yuksekten alcaga taranir).
const ISIK_ESYA := {3: "koz_kabi", 2: "kor_feneri", 1: "mesale"}

# --- 16.1 Isik kapisi etkileri (yapay duvar yok, karanlik var) -----------
## Vinyet siddeti: yeterli isikla sis "atmosfer"dir, yetersizle "duvar".
const VINYET_ISIKLI := 0.30    # sis * bu = hafif kenar karartma
const VINYET_ACIK_BASI := 0.55 # her eksik isik kademesi vinyeti buyutur
const VINYET_MAX := 0.92       # ekran hicbir zaman tam kapanmaz
const SOGUK_CARPAN := 0.5      # renk sogumasi = sis * bu (0..1)
## Fener kisikken (16.5 stealth) ekstra kenar karartmasi.
const KISIK_VINYET_EK := 0.18

## Yetersiz isikta hedefleme yalniz ON hucreye iner (genis tarama kapali).
const KISITLI_HEDEFLEME := true
## Yetersiz isikta kamp kurulamaz (16.4 bunu okur).
const KAMP_ISIK_SART := true

# --- 16.2 Sis gorseli (mobil dostu) --------------------------------------
const SIS_DUZLEM_BOYUT := 44.0   # oyuncuyu izleyen alcak sis karesi (m)
const SIS_DUZLEM_YUKSEK := 0.55  # zeminden yukseklik (m)
const SIS_DUZLEM_ALFA := 0.16    # tam siste taban seffaflik
const SIS_RENK := Color(0.62, 0.66, 0.78)  # soguk gri-lavanta

## Gunduz-guvenli kurali bu halkadan itibaren KIRILIR (16.2): loş bolgede
## gunduz de uyanik tehdit olabilir. Asama 5 tehditleri bunu okur.
const YABANI_GUNDUZ_HALKA := 2

# --- Sorgular -------------------------------------------------------------

static func ring_of(cell: Vector2i, merkez: Vector2i) -> int:
	var d := Vector2(cell - merkez).length()
	for i in RING_R.size():
		if d <= RING_R[i]:
			return i
	return RING_COUNT - 1

static func sis_yogunluk(ring: int) -> float:
	return SIS[clampi(ring, 0, SIS.size() - 1)]

static func gereken_isik(ring: int) -> int:
	return GEREKEN_ISIK[clampi(ring, 0, GEREKEN_ISIK.size() - 1)]

## Envanterden tasinan isik kademesi. inv: get_count(id) cevaplayan nesne
## (test edilebilirlik icin parametre; oyunda Inventory autoload'u gecilir).
static func tasinan_isik(inv: Object) -> int:
	for tier in [3, 2, 1]:
		if int(inv.call("get_count", String(ISIK_ESYA[tier]))) > 0:
			return tier
	return 0

## Isik acigi: 0 = kapi acik; >0 = eksik kademe sayisi.
static func isik_acigi(ring: int, isik: int) -> int:
	return maxi(0, gereken_isik(ring) - isik)

## Ekran vinyet siddeti (0..1). sis=0 iken daima 0.
static func vinyet(sis: float, acik: int, kisik: bool) -> float:
	if sis <= 0.0:
		return 0.0
	var v := sis * VINYET_ISIKLI + float(acik) * VINYET_ACIK_BASI * sis
	if kisik:
		v += KISIK_VINYET_EK
	return clampf(v, 0.0, VINYET_MAX)

## Renk sogumasi (0..1) — sis arttikca dunya sograr, isik bunu azaltmaz
## (sis oradadir; isik yalnizca GORMENI saglar).
static func soguk(sis: float) -> float:
	return clampf(sis * SOGUK_CARPAN, 0.0, 1.0)
