extends RefCounted
## Performans ayar/olcum verileri (RAPOR_PERF.md ile birlikte okunur).
##
## ALTIN KURAL: once olc, sonra dokun. Bu dosya HEM debug overlay'in
## ornekleme ayarlarini HEM de 3 kademeli grafik kalite profilini tutar.
## Sayilar burada; mantik world3d/hud icinde. Boylece dengeyi tek yerden
## cevirebiliriz.

# --- Overlay ornekleme -------------------------------------------------
## Overlay metnini kac saniyede bir tazele (her kare degil; overlay'in
## kendisi olcumu bozmasin diye seyrek).
const OVERLAY_REFRESH_SEC := 0.25
## FPS ortalamasi icin kayan pencere (kare sayisi).
const FPS_WINDOW := 30

# --- CI perf-probe -----------------------------------------------------
## Her senaryoda sayac toplamadan once kac kare isinma birak.
const PROBE_WARMUP_FRAMES := 8
## Her senaryoda kac kare ornekle (ortalama + tepe icin).
const PROBE_SAMPLE_FRAMES := 30
## Yogun base senaryosu icin uretilecek yapi sayisi.
const PROBE_DENSE_STRUCTURES := 32
## Yogun base senaryosu icin mesale sayisi.
const PROBE_DENSE_TORCHES := 6
## Dalga senaryosu icin uretilecek yaratik sayisi (MAX_ACTIVE'e kadar).
const PROBE_WAVE_CREATURES := 12

# --- 3 kademeli grafik kalitesi ----------------------------------------
## Kademeler: her biri golge/isik/partikul profili. Degerler world3d'de
## uygulanir (apply_quality). "Orta" varsayilan (dengeli).
##  - dir_shadow: yonlu (gunes) golge acik mi
##  - dir_shadow_size: golge atlasi cozunurlugu (px)
##  - dir_shadow_dist: golge kamera menzili (m) — kucuk = net + ucuz
##  - max_torches: ayni anda aktif mesale isigi butcesi
##  - torch_flicker: mesale titresimi (kapali = her kare enerji yazma yok)
##  - particles: partikul efektleri (kazi tozu, oz dagilmasi vs.) acik mi
##  - far_simplify_dist: bu mesafeden uzak yaratik/efekt basitlesir (m)
const TIERS := {
	"dusuk": {
		"label": "Düşük",
		"dir_shadow": false,
		"dir_shadow_size": 1024,
		"dir_shadow_dist": 24.0,
		"max_torches": 3,
		"torch_flicker": false,
		"particles": false,
		"far_simplify_dist": 14.0,
	},
	"orta": {
		"label": "Orta",
		"dir_shadow": true,
		"dir_shadow_size": 2048,
		"dir_shadow_dist": 40.0,
		"max_torches": 6,
		"torch_flicker": true,
		"particles": true,
		"far_simplify_dist": 22.0,
	},
	"yuksek": {
		"label": "Yüksek",
		"dir_shadow": true,
		"dir_shadow_size": 4096,
		"dir_shadow_dist": 60.0,
		"max_torches": 10,
		"torch_flicker": true,
		"particles": true,
		"far_simplify_dist": 32.0,
	},
}

## Varsayilan kademe (mobil dengeli).
const DEFAULT_TIER := "orta"
## Kademe sirasi (menude soldan saga).
const TIER_ORDER := ["dusuk", "orta", "yuksek"]

static func tier(name: String) -> Dictionary:
	return TIERS.get(name, TIERS[DEFAULT_TIER])

static func tier_val(name: String, key: String, def = null):
	return TIERS.get(name, TIERS[DEFAULT_TIER]).get(key, def)
