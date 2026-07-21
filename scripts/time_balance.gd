extends RefCounted
## GÜNDÜZ/GECE DENGE VERİSİ — tüm süreler/sayılar burada (kod içinde sabit yok).
## Kullanıcı elle oynayarak ritmi ayarlar. Bir tam gün = dawn+day+dusk+night.

# --- Faz süreleri (gerçek saniye) --------------------------------------
const DAWN_SECONDS: float = 45.0     # şafak geçişi
const DAY_SECONDS: float = 600.0     # gündüz (10 dk)
const DUSK_SECONDS: float = 45.0     # akşam geçişi
const NIGHT_SECONDS: float = 240.0   # gece (4 dk)
const CYCLE_SECONDS: float = DAWN_SECONDS + DAY_SECONDS + DUSK_SECONDS + NIGHT_SECONDS

# --- HUD ritmi ----------------------------------------------------------
const NIGHT_WARN_LEAD: float = 60.0  # geceye son 1 dk: pill uyarı + nabız
const NIGHT_PILL_SECONDS: float = 2.0  # gece başında "Gece N" pill süresi

# --- Uyku (BASE_SAVUNMA 14.2) ------------------------------------------
const SLEEP_MAX_NIGHT: int = 3       # yalnız ilk 3 gece uyunabilir
const SLEEP_HEAL_HEALTH: float = 20.0
const SLEEP_HEAL_HUNGER: float = 15.0
