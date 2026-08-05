extends RefCounted
## HASAT ANIMASYONU VERISI (hasat-anim) — "Sallan, Firla, Uc".
## Yalniz SUNUM: item verimi/tohum iadesi mantigi DEGISMEZ; oyuncu
## animasyon oynarken BLOKLANMAZ (async, girdi kilidi yok). Toplam
## ~0.9 sn. Hizli test katmani (RABLE_TEST_LEVEL=hizli) eski anlik
## yolu kullanir — test determinizmi bozulmaz.

# --- 1) SALLAN ---------------------------------------------------------
const SALLAN_SN := 0.15          # kokten 2 kez saga-sola, sonumlu
const SALLAN_ACI_DERECE := 8.0
const SALLAN_SONUM := 0.55       # her salinimda aci bu carpanla kuculur

# --- 2) FIRLA + POP ----------------------------------------------------
const FIRLA_SN := 0.3            # item parabolu
const FIRLA_YUKSEK := 0.6        # parabol tepe yuksekligi (m)
const FIRLA_MESAFE_MIN := 0.5    # hucre cinsinden dusme uzakligi
const FIRLA_MESAFE_MAX := 1.0
const FIRLA_DONUS_TUR := 1.0     # havada donme (tam tur)
const SEKME_SN := 0.12           # yere tek sekme
const SEKME_YUKSEK := 0.12
const POP_SIS_ORAN := 1.15       # bitki %115 sisme
const POP_SIS_SN := 0.08
const POP_COKUS_SN := 0.15       # %0'a ease-in cokus ("pop")
const YAPRAK_KIRPIK_MIN := 4     # bitki renginde kirpik parcacigi
const YAPRAK_KIRPIK_MAX := 6
const TOPRAK_PUF_RENK := Color(0.5, 0.38, 0.24)
const TOPRAK_PUF_ADET := 5

# --- 3) UC (oyuncuya emilis) -------------------------------------------
const UC_BEKLE_SN := 0.25        # yerde bekleme
const UCUS_SN := 0.4             # oyuncuya kavisli ucus
const UCUS_ITEM_ARA_SN := 0.05   # ardisik ritim (item basina gecikme)
const UCUS_KAVIS := 0.5          # kavis tepe eki (m)
const EMILIS_SFX := "harvest_pop"  # ses kancasi (dosya gelince calar)

# --- Urun kisilikleri --------------------------------------------------
## pumpkin: AGIR — firlamaz, yerinde tombul ziplar (squash), oyuncuya
##   DAHA YAVAS ucar. korotu: firlama aninda isik soner (korotu-isik
##   kurali) + 2-3 turkuaz zerre yukari suzulur (veda).
## golden_wheat sap-sap dalga (0.03 sn soldan saga) DOSYA-BEKLER:
##   v2 modeli TEK mesh — ayrik sap dugumlu surum gelirse baglanir;
##   o zamana dek bugday genel akisi kullanir (tum kompozisyon birlikte).
const KISILIK := {
	"pumpkin": {"firlamaz": true, "ucus_carpani": 1.6},
	"korotu": {"zerre": true},
	"golden_wheat": {"sap_dalga_sn": 0.03},  # kanca (dosya-bekler)
}
const KOROTU_ZERRE_ADET := 3
const KOROTU_ZERRE_YUKSEK := 0.7
const KOROTU_ZERRE_SN := 1.1

# --- Kalite / cakisma --------------------------------------------------
## Kalite Dusuk: parcaciklar kapali (perf_balance "particles") +
## sureler yariya — hiz hissi korunur, sus gider.
const DUSUK_SURE_CARPAN := 0.5
