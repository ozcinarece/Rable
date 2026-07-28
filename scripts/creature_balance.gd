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
## YARATIK TIPLERI — tam liste ve anlamlari YARATIKLAR.md / .csv'de.
## Buradaki tablo TEK KAYNAK; oyun ve tablo ayni satirlari okur.
##
## YETENEKLER yol bulmaya dogrudan bagli (creature_break_cost):
##   climb  -> duvar/yapi tirmanilir, maliyeti dusuk (dolasmaz, asar)
##   swim   -> su gecilebilir (kara yaratigi icin su duvar gibidir)
##   struct_mult -> yapiya vurus hasari carpani
##
## glb: her tipin kendi modeli. DOSYA YOKSA proseduerel govde cizilir
## (kod ResourceLoader ile kontrol eder) — model gelince kendiliginden
## devreye girer, kod degisikligi gerekmez.
## Yol assets/models/creatures/ altini gosterir ama modeller pratikte
## GitHub web arayuzunden assets/models/test/ altina yukleniyor;
## creature.gd IKI KLASORE de bakiyor (bkz. _resolve_glb), yani dosya
## hangisine dusrse dussun bulunur.
const TYPES := {
	"normal": {
		"hp": 10, "speed": 2.0, "damage": 6, "essence": 1,
		"first_night": 1, "eye": "turkuaz", "scale": 1.0,
		# target_h: modelin OYUNDAKI boyu (metre) — scl bundan OLCULEREK
		# hesaplanir (AABB), "scale" tahminine dusulmez. Karakter ~1 birim;
		# yaratik hafif iri dursun diye 1.1.
		"target_h": 1.1,
		"glb": "res://assets/models/creatures/creature_2.glb",
	},
	"tirmanici": {
		"hp": 6, "speed": 2.2, "damage": 4, "essence": 1,
		"first_night": 4, "eye": "mor", "scale": 0.9,
		"climb": true,
		"glb": "res://assets/models/creatures/creature_tirmanici.glb",
	},
	"yuzucu": {
		"hp": 8, "speed": 1.8, "damage": 5, "essence": 1,
		"first_night": 5, "eye": "turkuaz", "scale": 0.95,
		"swim": true,
		"glb": "res://assets/models/creatures/creature_yuzucu.glb",
	},
	"kirici": {
		"hp": 24, "speed": 1.2, "damage": 10, "essence": 2,
		"first_night": 7, "eye": "turkuaz", "scale": 1.35,
		"struct_mult": 3,
		"glb": "res://assets/models/creatures/creature_kirici.glb",
	},
	"hizli": {
		"hp": 4, "speed": 4.0, "damage": 4, "essence": 1,
		"first_night": 10, "eye": "mor", "scale": 0.8,
		"glb": "res://assets/models/creatures/creature_hizli.glb",
	},
	# --- KESIF 16.6: UZAK TEHDITLER — gece dalgasina GIRMEZLER ----------
	# (first_night 999: dalga havuzu bu tipleri hic acmaz; bunlar sisli
	# halkalarin ortam yaratiklaridir, world3d'nin uzak-tehdit dogurucusu
	# kullanir.) Modeller dosya-bekler: GLB dusunce kendiliginden takilir.
	"sis_surusu": {
		"hp": 3, "speed": 3.4, "damage": 3, "essence": 1,
		"first_night": 999, "eye": "mor", "scale": 0.7,
		"glb": "res://assets/models/creatures/creature_sis_surusu.glb",
	},
	"fener_avcisi": {
		"hp": 12, "speed": 2.6, "damage": 7, "essence": 2,
		"first_night": 999, "eye": "turkuaz", "scale": 1.1,
		"glb": "res://assets/models/creatures/creature_fener_avcisi.glb",
	},
	"catlak_dev": {
		"hp": 60, "speed": 0.8, "damage": 16, "essence": 4,
		"first_night": 999, "eye": "turkuaz", "scale": 1.8,
		"struct_mult": 4,
		"glb": "res://assets/models/creatures/creature_catlak_dev.glb",
	},
}

## Tirmanici duvari ASMAYI tercih eder: maliyeti dusuk ama sifir degil
## (tirmanmak zaman alir, duz zemin hala daha ucuz).
const CLIMB_COST := 3
## Yuzucu icin su maliyeti: gecilebilir ama yavas.
const SWIM_COST := 4
## Tirmanirken hiz carpani (SWIM_SLOW'un duvar karsiligi). Tirmanmak
## bedava olsaydi duvar hicbir sey yavaslatmazdi; oyuncu duvardan
## KAZANC gormeliydi.
const CLIMB_SLOW := 0.45

static func stat(type: String, key: String, def: Variant = 0) -> Variant:
	return TYPES.get(type, TYPES["normal"]).get(key, def)

# --- Dalga karisimi (15.4) ----------------------------------------------
## Bir tip ancak first_night'tan itibaren havuza girer. Havuzda AGIRLIKLA
## secilir: "normal" omurga, ozel tipler cesni.
const MIX_WEIGHT := {
	"normal": 10, "tirmanici": 4, "yuzucu": 3, "kirici": 2, "hizli": 3,
}
## Ozel tipler gecenin en fazla bu oranini kaplar. Sinir OLMASA acilan
## tip sayisi arttikca normal yaratik kaybolur ve her gece "ozel gecesi"
## gibi hissettirirdi; omurga korunuyor.
const MIX_SPECIAL_MAX := 0.5

## O gece hangi tipler cikabilir.
static func unlocked_types(night: int) -> Array:
	var out: Array = []
	for t: String in TYPES:
		if night >= int(TYPES[t].get("first_night", 1)):
			out.append(t)
	return out

## Gecenin yaratik listesi. Bir tip ILK acildigi gece MUTLAKA gorunur —
## yeni tehdit sessizce degil, farkedilerek girsin diye.
static func wave_mix(night: int, count: int, rng: RandomNumberGenerator = null) -> Array:
	var out: Array = []
	if count <= 0:
		return out
	var pool: Array = unlocked_types(night)
	# Bu gece acilan tip(ler) once garanti kontenjan alir.
	for t: String in pool:
		if out.size() >= count:
			break
		if t != "normal" and int(TYPES[t].get("first_night", 1)) == night:
			out.append(t)
	var ozel_limit: int = int(floor(float(count) * MIX_SPECIAL_MAX))
	var toplam: int = 0
	for t: String in pool:
		toplam += int(MIX_WEIGHT.get(t, 1))
	if toplam <= 0:
		while out.size() < count:
			out.append("normal")
		return out
	while out.size() < count:
		var ozel: int = 0
		for t: String in out:
			if t != "normal":
				ozel += 1
		if ozel >= ozel_limit:
			out.append("normal")
			continue
		var r: int = (rng.randi_range(0, toplam - 1) if rng != null
				else randi_range(0, toplam - 1))
		var sec: String = "normal"
		for t: String in pool:
			r -= int(MIX_WEIGHT.get(t, 1))
			if r < 0:
				sec = t
				break
		out.append(sec)
	return out

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

## Dogus kurallari (yaratik-gece): harita kenarindan DEGIL — Ocak/oyuncu
## MERKEZLI HALKA: merkeze SPAWN_RING_MIN..MAX hucre mesafede, sisli/
## ormanlik yonler agirlikli. Oyuncunun GORUS ALANINDA dogmaz (frustum).
const SPAWN_RING_MIN := 25        # halka ic yaricapi (hucre)
const SPAWN_RING_MAX := 40        # halka dis yaricapi
const SPAWN_FOG_BONUS := 3.0      # aday puani: sis yogunlugu (0..1) * bu
const SPAWN_TREE_BONUS := 1.5     # aday puani: bitisik agac varsa ek
const SPAWN_CANDIDATES := 12      # agirlikli secim icin aday sayisi
const SPAWN_EDGE_MARGIN := 2      # (eski kenar banti — son care fallback)
const SPAWN_MIN_DIST_PLAYER := 10 # oyuncuya en az bu kadar hucre
const SPAWN_MIN_DIST_HEARTH := 8  # Ocak'a en az bu kadar hucre
const SPAWN_TRIES := 40           # uygun hucre arama denemesi

## Topraktan dogrulma: kul-duman + kabuk parcaciklari, govde bu surede
## yukselir; surece AI islemez (daze). Renkler dunya diliyle.
const BIRTH_SECONDS := 1.0
const BIRTH_ASH_COLOR := Color(0.45, 0.43, 0.40)   # kul-duman grisi
const BIRTH_SHELL_COLOR := Color(0.30, 0.24, 0.18) # kabuk/toprak koyusu

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

# --- ANIMASYON (yaratik-gece: creature_2.glb rig'i) ----------------------
## GLB'de UC klip var (olculdu): Running / Walk_with_Walker_Support /
## Walking. Kullanici karari: yurume aksiyonu Walk_with_Walker_Support.
## Idle ve saldiri klibi YOK — durunca klip durdurulur, saldiri lunge
## tween'iyle kalir (ANIM_ATTACK dosya-bekler kanca: klip gelirse ismi
## buraya yazilir, kod hazir).
const ANIM_WALK := "Walk_with_Walker_Support"
const ANIM_ATTACK := ""            # savurma klibi gelince adi buraya
const ANIM_BLEND := 0.15           # gecis yumusatmasi (sn)
## Yurume klibinin YAZILDIGI hiz (m/sn) — speed_scale = hiz / bu deger.
## Kayma olursa elle ayarlanacak tek sayi budur.
const ANIM_WALK_REF_SPEED := 1.6

# --- CATLAK ISIMASI (yaratik-gece) ---------------------------------------
## Model dokusunda emissive VAR (olculdu) — enerji katmani buradan.
## Gece kaynagi su/cim ailesiyle AYNI (_update_water_night cagirir).
const EMISSION_DAY := 0.7          # gunduz soluk
const EMISSION_NIGHT := 2.4        # gece parlar
const EMISSION_LIGHT_DIM := 0.45   # isik alaninda soner (Isik Kurami)

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
