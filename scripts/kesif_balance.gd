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

# --- 16.3 Kor taslari -----------------------------------------------------
## ANA HAT 6 tas: Ocak'tan disari YAY cizer (aci derece, yaricap hucre).
## Sira ayni zamanda zorluk sirasi: 1-2 Halka 1, 3-4 Halka 2, 5-6 Halka 3.
const TAS_ANA := [
	{"aci": -140.0, "r": 21.0}, {"aci": -84.0, "r": 26.0},
	{"aci": -28.0, "r": 37.0}, {"aci": 28.0, "r": 42.0},
	{"aci": 84.0, "r": 52.0}, {"aci": 140.0, "r": 58.0},
]
## YAN taslar (opsiyonel, 16.7 odulleri Asama 6'da): yaydan sapmis.
const TAS_YAN := {
	"yanA": {"aci": 180.0, "r": 34.0},
	"yanB": {"aci": -170.0, "r": 50.0},
	"yanC": {"aci": 100.0, "r": 57.0},
}
## Yakma bedeli: 1 yol koru + tas basina ARTAN oz (ana sira; 16.3).
const TAS_BEDEL := [
	{"oz": 1}, {"oz": 1}, {"oz": 2}, {"oz": 2}, {"oz": 3}, {"oz": 3},
]
const TAS_YAN_BEDEL := {"oz": 2}
## Bu halkadan itibaren yol korunu tasimak KOZ KABI ister (once mesale koru
## yeter — 16.3 "Halka 1 taslari icin mesaleyle tasinabilir basit koz").
const KOZ_SART_HALKA := 2
## Yakilan tasin cevresinde KALICI sis temizligi yaricapi (16.2).
const TEMIZ_R := 11.0
## Gece sertlesmesi (HIKAYE 8 gorunurluk bedeli): yakilan ANA tas basina
## dalga sayisi carpani artisi.
const SERTLESME_TAS_BASI := 0.08

static func gece_sertlesme(yanik_ana: int) -> float:
	return 1.0 + SERTLESME_TAS_BASI * float(yanik_ana)

## Ana tas indexi -> yanma bedeli (yan taslar icin TAS_YAN_BEDEL).
static func tas_bedel(id: String) -> Dictionary:
	if id.begins_with("ana"):
		var i := int(id.substr(3)) - 1
		return TAS_BEDEL[clampi(i, 0, TAS_BEDEL.size() - 1)]
	return TAS_YAN_BEDEL

# --- 16.4 Sefer ve kamp ---------------------------------------------------
## Gece basinda Ocak'tan bu kadar uzaksan o gece SEFER gecesidir:
## base dalgasi SIMULE edilir, gercek dalga oyuncunun yanina gelmez.
const SEFER_UZAK_R := 18.0
## Atesli kamp gecesi cekim: 2-4 yaratik (16.4 "dalga degil"), olasilik.
const KAMP_KARSILASMA_MIN := 2
const KAMP_KARSILASMA_MAX := 4
const KAMP_KARSILASMA_SANS := 0.6
## Kamp atesi sayilan yaricap (oyuncunun cevresinde placed yol_koru).
const KAMP_YAKIN_R := 6.0
## Atessiz gece cezasi (sabah): "karanlikta titrersin ama gorunmezsin".
const ATESSIZ_HP_CEZA := 8.0
const ATESSIZ_ACLIK_CEZA := 12.0

## SAVUNMA PUANI (16.4 formulu — sabah raporunun matematigi):
##   puan = SIGMA( yapi_hp * tip_agirligi ) + su_hucre * SU_PUAN
## Hesap alani Ocak cevresi SAVUNMA_R. Dalga gucu:
##   dalga = gece * DALGA_TABAN * gece_sertlesme * nefes_carpani
## Hasar = max(0, dalga - puan * SAVUNMA_ETKI). Hasar once savunma
## yapilarini yer, artani Ocak'a gecer ("Ocak hasarli! Eve don").
const SAVUNMA_R := 10.0
const SAVUNMA_AGIRLIK := {
	"ahsap_duvar": 0.10, "tas_duvar": 0.14, "kapi": 0.08, "tuzak": 0.20,
	"kazik": 0.15, "platform": 0.06, "mesale": 0.04,
}
const SU_PUAN := 3.0            # su dolu kazilmis hucre (hendek) basina
const DALGA_TABAN := 6.0
const SAVUNMA_ETKI := 0.8
const HASAR_YAPI_CARPAN := 1.0  # hasar puani -> yapi hp kaybi
## Nefes (HIKAYE 9 kancasi): "kozle" saklan modu dalgayi indirir.
## UI secimi hikaye fazinda; API + kayit bugunden hazir.
const NEFES_CARPAN := {"harla": 1.0, "kozle": 0.65}

static func dalga_gucu(gece: int, yanik_ana: int, nefes: String) -> float:
	return float(gece) * DALGA_TABAN * gece_sertlesme(yanik_ana) \
			* float(NEFES_CARPAN.get(nefes, 1.0))

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
