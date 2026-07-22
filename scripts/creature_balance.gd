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
static func night_hp_mult(night: int) -> float:
	return 1.0 + 0.06 * float(maxi(0, night - 1))

static func night_damage_mult(night: int) -> float:
	if night <= EARLY_EASY_NIGHTS:
		return EARLY_DAMAGE_MULT
	return 1.0 + 0.05 * float(night - EARLY_EASY_NIGHTS)

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

# --- 14.5 Maliyet bazlı yol bulma (BASE_SAVUNMA) -------------------------
## Yaratık A* için hücre geçiş maliyeti (denge verisi). Yapı maliyetleri =
## kırma süresi tahmini (hp/hasar) ile orantılı → güçlü duvar "pahalı yol".
## Yaratık AI (Aşama 2+) bu tabloyu okuyacak; şimdilik veri + saf fonksiyon.
const BASE_MOVE_COST := 1              # boş zemin
const RAISE_COST := {1: 3, 2: 6}       # yükselti +1 / +2
const STRUCTURE_COST := {              # yapı hücresi geçiş maliyeti (kırma zorluğu)
	"fence": 5, "ahsap_duvar": 10, "tas_duvar": 18,
	"tugla_sur": 26, "celik_kapi": 40,
}
## İÇ MEKAN CEZASI (Ev/Çatı paketi, 14.5): iç mekan hücreleri çok pahalı sayılır
## → yaratıklar eve girmeyi SON ÇARE görür. Tabloya eklenen "iç mekan: +20".
const INDOOR_COST_PENALTY := 20

## Bir hücrenin toplam geçiş maliyeti: taban + (iç mekansa) ceza. Yol bulma
## bu fonksiyonu çağırır → iç mekan otomatik pahalılaşır.
static func traverse_cost(base_cost: int, cell_is_indoor: bool) -> int:
	return base_cost + (INDOOR_COST_PENALTY if cell_is_indoor else 0)
