extends RefCounted
## HAYATTA KALMA DENGE VERISI — TUM sayilar burada (kod icinde sabit YOK).
## Kullanici bu dosyayi elle oynayarak dengeyi ayarlar. PlayerStats +
## world3d + hud bu degerleri okur; hicbir yerde tekrar sabit yazilmaz.

# --- Açlık (hunger) -----------------------------------------------------
const HUNGER_MAX: float = 100.0
## Saniyede azalma. 0.21 -> ~8 dakikada 100->0 (dinlenirken).
const HUNGER_DECAY_PER_SEC: float = 0.21
## Koşma/kazı gibi efor açlığı bu kadar hızlandırır (%25).
const EFFORT_HUNGER_MULT: float = 1.25
## Bu değerin altında "acıktın" uyarısı (HUD açlık barı warning nabzı).
const HUNGER_WARN_THRESHOLD: float = 30.0

# --- Can (health) -------------------------------------------------------
const HEALTH_MAX: float = 100.0
## Açlık 0 iken saniyede erien can.
const STARVE_HEALTH_LOSS_PER_SEC: float = 0.5
## Bu açlığın ÜSTÜNDE yavaş otomatik can yenilenmesi olur.
const REGEN_HUNGER_THRESHOLD: float = 70.0
## İyi beslenince saniyede yenilenen can.
const HEALTH_REGEN_PER_SEC: float = 1.0

# --- Ölüm / yeniden doğuş ----------------------------------------------
const RESPAWN_HEALTH: float = 50.0
const RESPAWN_HUNGER: float = 50.0
## v1: envanter ölümde KORUNUR. İleride açılabilir bayrak (denge kararı).
const DROP_ITEMS_ON_DEATH: bool = false

# --- Yeme (edible) ------------------------------------------------------
## Yiyecek id -> doyma değeri (açlığa eklenir). Yeni yiyecek = tek satır.
const FOOD_SATIATION: Dictionary = {
	"meyve": 12.0,       # berry (yaban meyvesi)
	"mantar": 10.0,      # mevcut toplanabilir
	"cig_et": 15.0,      # raw_meat (kaynak: hayvan — yaratık fazı)
	"pismis_et": 40.0,   # cooked_meat (ocak/kamp ateşinde pişer)
}
## Çiğ et caydırıcısı: %20 şansla kısa mide bulantısı (açlık 2x hızlı azalır).
## Hastalık sistemi YOK — basit tutuldu.
const RAW_MEAT_IDS: Array = ["cig_et"]
const NAUSEA_CHANCE: float = 0.20
const NAUSEA_DURATION: float = 5.0
const NAUSEA_HUNGER_MULT: float = 2.0
## Yeme eylemi süresi (sn) — ALET_SISTEMI "tüketme" profili.
const EAT_DURATION: float = 1.0
