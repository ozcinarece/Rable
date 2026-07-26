extends RefCounted
## YARATIK DENGE VERİSİ (BÖLÜM 15). TÜM sayılar burada — kod dokunmadan
## elle ayarlanır (15.8 anayasa). Yaratık davranışı scriptlerde; bu dosya veri.

# --- Görsel kimlik (15.1): soğuk palet, tek parlak göz --------------------
const BODY_COLOR := Color(0.42, 0.40, 0.55)   # mor-gri gövde
const BODY_COLOR_2 := Color(0.30, 0.34, 0.44) # kırıcı (daha koyu/iri)
const EYE_COLOR := Color(0.35, 0.95, 0.95)    # turkuaz ışıma
const EYE_COLOR_ALT := Color(0.72, 0.45, 0.95) # mor ışıma (tırmanıcı/hızlı)

# --- Öz (essence) düşümü (15.1) ------------------------------------------
const ESSENCE_ITEM := "oz"

# --- Tipler (15.4): can / hız / hasar / özellik / ilk görülme -------------
## essence: ölünce düşen öz adedi. struct_mult: yapıya hasar çarpanı.
## first_night: bu tip ilk hangi gecede karışıma girer.
const TYPES := {
	"normal": {
		"hp": 10, "speed": 2.0, "damage": 6, "essence": 1,
		"first_night": 1, "eye": "turkuaz", "scale": 1.0,
	},
	"tirmanici": {
		"hp": 6, "speed": 2.0, "damage": 4, "essence": 1,
		"first_night": 4, "eye": "mor", "scale": 0.9, "climb_fast": true,
	},
	"kirici": {
		"hp": 24, "speed": 1.2, "damage": 10, "essence": 2, "struct_mult": 3,
		"first_night": 7, "eye": "turkuaz", "scale": 1.35, "target_pref": "structure",
	},
	"hizli": {
		"hp": 4, "speed": 4.0, "damage": 4, "essence": 1,
		"first_night": 10, "eye": "mor", "scale": 0.8, "zigzag": true,
	},
}

static func stat(type: String, key: String, def: Variant = 0) -> Variant:
	return TYPES.get(type, TYPES["normal"]).get(key, def)

# --- Dalga eğrisi (15.2): gece kademesi = gün sayısı ---------------------
## İLK 3 GECE bilerek kolay (14.9): az sayı, sadece normal, düşük hasar.
## toplam = temel + gece*artis (MAX_ACTIVE'e kırpılır). gruplar 2-4.
const WAVE_BASE_COUNT := 3
const WAVE_PER_NIGHT := 2       # her gece +2 yaratık (kaba)
const WAVE_GROUPS_MIN := 2
const WAVE_GROUPS_MAX := 4
const WAVE_GROUP_GAP := 12.0    # gruplar arası saniye
const EARLY_EASY_NIGHTS := 3    # bu geceye kadar sadece normal + düşük hasar
const EARLY_DAMAGE_MULT := 0.6  # ilk gecelerde hasar çarpanı

## Gece kademesine göre can/hasar çarpanı (ileri gecelerde sertleşir).
## MINIMAL: o gece kac yaratik dogar (tek grup, tek seferde).
static func min_wave_count(night: int) -> int:
	var n := MIN_BASE_COUNT + MIN_PER_NIGHT * maxi(0, night - 1)
	return clampi(n, 1, MIN_MAX_COUNT)

static func night_hp_mult(night: int) -> float:
	return 1.0 + 0.06 * float(maxi(0, night - 1))

static func night_damage_mult(night: int) -> float:
	if night <= EARLY_EASY_NIGHTS:
		return EARLY_DAMAGE_MULT
	return 1.0 + 0.05 * float(night - EARLY_EASY_NIGHTS)

# --- MİNİMAL GECE DÖNGÜSÜ (yaratik-gece) ---------------------------------
## Bu blok SADECE minimal surumun sayilaridir. Yukaridaki WAVE_* (gruplu
## dalga) ve tip/tuzak/cevre sayilari SONRAKI turlar icin duruyor —
## minimal surum onlari OKUMAZ (tek grup, tek tip, A* yok).

## Gece basina yaratik sayisi: gece 1 -> MIN_BASE, her gece +MIN_PER_NIGHT,
## en fazla MIN_MAX_COUNT. (gece 1: 2, gece 2: 3, ... gece 11+: 12)
const MIN_BASE_COUNT := 2
const MIN_PER_NIGHT := 1
const MIN_MAX_COUNT := 12

## Ayni anda sahnede durabilecek en fazla yaratik (mobil performans).
const MIN_MAX_ACTIVE := 12

## Dogus kurallari: harita kenarindan ic bantta, oyuncuya/Ocak'a en az
## bu kadar hucre uzakta dogar (kucuk haritada kural gevsetilir).
const SPAWN_EDGE_MARGIN := 2      # kenardan ic bant genisligi
const SPAWN_MIN_DIST_PLAYER := 10 # oyuncuya en az bu kadar hucre
const SPAWN_MIN_DIST_HEARTH := 8  # Ocak'a en az bu kadar hucre
const SPAWN_TRIES := 40           # uygun hucre arama denemesi

## Hedefleme: oyuncu bu menzildeyse oyuncuyu, degilse Ocak'i kovalar.
# --- YOL BULMA (Asama 2) ------------------------------------------------
## Arama butcesi: mobilde kare basina birden fazla yaratik yol arayabilir.
## 900 dugum, 128x128 haritada tipik bir kamp-kenar mesafesini rahat
## kapsiyor; dolarsa kismi yol donuyor (yaratik durmuyor).
const PATH_MAX_NODES := 900
## Yeniden planlama araligi (sn). Her karede yol aramak gereksiz: hedef
## yavas hareket ediyor ve dunya nadiren degisiyor.
const REPATH_SECONDS := 0.8
## Hedef bu kadar hucre kaydiysa beklemeden yeniden planla (oyuncu
## kosarak uzaklasinca yaratigin eski yolu takip etmesi aptalca olurdu).
const REPATH_TARGET_SHIFT := 3
## KIRILABILIR engelin yola maliyeti. 1 = bos hucre. Yuksek deger =
## "once dolasmayi dene". 14: yaklasik 14 hucreden kisa bir dolambac
## varsa yaratik DOLASIR, yoksa KIRAR. Oyuncunun duvar tasarimi
## dogrudan bu esikle konusuyor.
const BREAK_COST := 14
## Kirilamaz engel (harita kenari, su, plato): yol kapali.
const BLOCK_IMPASSABLE := -1

const AGGRO_RANGE := 7.0          # metre (hucre ~1 m)

## Temas ve saldiri
const CONTACT_RANGE := 0.9        # oyuncuya bu mesafede saldirir (m)
const ATTACK_COOLDOWN := 1.2      # oyuncuya saldiri araligi (sn)
const STRUCT_ATTACK_COOLDOWN := 0.9  # yapiya vurus araligi (sn)
const STRUCT_DAMAGE := 12         # yapiya bir vurusta hasar

## Takilma cozumu (A* YOK): bu sure ilerleyemezse yana kayar.
const STUCK_SECONDS := 2.0
const STUCK_SIDE_SPEED := 0.8     # yana kayma hizi carpani
const STUCK_SIDE_SECONDS := 0.8   # ne kadar sure yana kayar
const STEP_EPSILON := 0.02        # "ilerledi" sayilan en kucuk mesafe (m)

## Safak temizligi: kalan yaratiklar bu surede erir.
const DAWN_MELT_SECONDS := 0.5

# --- Çevre (15.5): KAZI_SU 11.1 tablosu ----------------------------------
const CLIMB_SECONDS := {2: 3.0, 3: 6.0, 4: 999.0}  # depth -> tırmanma süresi
const CLIMBER_SECONDS := {2: 2.0, 3: 2.0, 4: 2.0}  # tırmanıcı tip
const LADDER_CLIMB_FACTOR := 0.5   # merdiven varsa süre yarıya
const RAISE_CLIMB_SECONDS := {1: 1.0, 2: 2.0}  # yükselti tırmanma
const SWIM_SLOW := 0.30            # su: %70 yavaş (0.30 çarpan)
const LIGHT_SLOW := 0.90           # ışık alanında %10 yavaş

# --- Tuzaklar (15.6) -----------------------------------------------------
const SPIKE_SLOW := 0.60           # kazık: %40 yavaş (0.60 çarpan)
const SPIKE_BREAK_HITS := 3        # 3 tetiklemede kırılır
const FLAME_DPS := 6.0             # alev hendeği saniyelik hasar
const ALARM_WARN_SECONDS := 3.0

# --- Ocak / sabah ekonomisi (15.7) ---------------------------------------
const HEARTH_BREAK_NEXT_WAVE_MULT := 1.20  # ocak yıkılırsa ertesi gece +%20
const MORNING_REWARD := {          # hasarsız gece bonusu (gün kademesine göre taban)
	"item": "oz", "base": 1, "per_night": 1,
}

# --- Performans (15.8) ---------------------------------------------------
const MAX_ACTIVE := 16             # aynı anda max aktif yaratık
const FAR_SIMPLIFY_DIST := 22.0    # bu uzaklıktan öte animasyon/karmaşa kapalı
