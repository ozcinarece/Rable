extends RefCounted
## UI RENK SISTEMI - UI_DESIGN.md Bolum 1'in koddaki tek karsiligi.
## Kodda hex tekrari YASAK: her UI rengi buradan okunur.
## Kullanim: const UIColors = preload("res://scripts/ui_colors.gd")

# --- Zemin ve panel -------------------------------------------------------
const PANEL_CREAM := Color("#F6EDD6")
const PANEL_CREAM_DARK := Color("#EDE0C3")
const PANEL_SHADOW := Color("#00000022")
const OVERLAY_DIM := Color("#2B1F1466")

# --- Metin ve cizgi ---------------------------------------------------------
const INK_DARK := Color("#4A3728")
const INK_SOFT := Color("#8A7660")
const INK_FAINT := Color("#C4B49A")

# --- Baslik sekmesi ----------------------------------------------------------
const TAB_BG := Color("#4A3728")
const TAB_TEXT := Color("#F6EDD6")

# --- Durum renkleri -----------------------------------------------------------
const SUCCESS := Color("#7BC47F")
const DANGER := Color("#E07A5F")
const WARNING := Color("#E8B84A")
const RESEARCH := Color("#8FB8DE")

# --- Kategori -> pastel daire rengi (item_db.gd kategorileriyle birebir) ----
const CATEGORY_COLORS := {
	"resource": Color("#A8D8A0"),
	"tool": Color("#F5B971"),
	"weapon": Color("#F09090"),
	"station": Color("#C9A87C"),
	"trap": Color("#B9A0E8"),
	"structure": Color("#9FC5E8"),
	"farming": Color("#D6E8A0"),
	"engineering": Color("#A0D8D8"),
	"special": Color("#E8C4F0"),
}

## Kategori rengi; bilinmeyen kategori resource pasteline duser.
## Yeni kategori eklemek = CATEGORY_COLORS'a tek satir.
static func category_color(category: String) -> Color:
	return CATEGORY_COLORS.get(category, CATEGORY_COLORS["resource"])

## Arastirma dallari -> kategori renk dili (UI_DESIGN 4.4)
const BRANCH_COLORS := {
	"aletler": Color("#F5B971"),
	"insaat": Color("#B9A0E8"),
	"istasyonlar": Color("#C9A87C"),
	"muhendislik": Color("#A0D8D8"),
}

static func branch_color(branch: String) -> Color:
	return BRANCH_COLORS.get(branch, INK_SOFT)
