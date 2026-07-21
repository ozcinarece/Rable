extends RefCounted
## HARİTA ÜRETİM DENGE VERİSİ — tüm yoğunluk/eşik sayıları burada (kod içinde
## sabit yok). Kullanıcı bu dosyayı elle oynayarak haritayı ayarlar. Aynı
## SEED_DEFAULT aynı haritayı verir (deterministik). Farklı harita için seed'i
## değiştir. (Not: taban harita kayda yazılmaz, deltalar yazılır — bu yüzden
## seed sabit; random-per-newgame için seed'in kaydı gerekir, ileride.)

const MAP_SIZE: int = 128
const SEED_DEFAULT: int = 20260721

# --- Zemin lekeleri (çim ana; toprak/plato noise ile) -------------------
const DIRT_SCALE: float = 0.05        # toprak leke noise frekansı (büyük leke)
const DIRT_THRESHOLD: float = 0.62    # bu üstü toprak (yüksek=azınlık leke; çim ana)
const HILL_SCALE: float = 0.035       # yükseltilmiş plato noise frekansı
const HILL_THRESHOLD: float = 0.72    # bu üstü yüksek plato "h" (seyrek plato)

# --- Göl (bir köşede) + kıyı + kil --------------------------------------
const LAKE_CENTER := Vector2(0.24, 0.76)  # normalize köşe (güney-batı)
const LAKE_RADIUS: float = 20.0
const LAKE_EDGE_JITTER: float = 8.0       # kıyı düzensizliği (doğal kavis)
const LAKE_NOISE_SCALE: float = 0.07
const SHORE_WIDTH: float = 3.0            # su etrafı kum kuşağı
const CLAY_CHANCE: float = 0.22           # kum hücresinde kil işareti şansı

# --- Kaya çıkıntıları (öbekli) ------------------------------------------
const ROCK_CLUSTERS: int = 16
const ROCK_CLUSTER_MIN: int = 3
const ROCK_CLUSTER_MAX: int = 6
const ORE_HINT_CLUSTERS: int = 5          # kaç öbekte yüzey cevher ipucu

# --- Ağaçlar (öbekli orman + seyrek tekil) ------------------------------
const FOREST_SCALE: float = 0.045
const FOREST_THRESHOLD: float = 0.62      # bu üstü orman alanı (0..1; öbekli)
const FOREST_DENSITY: float = 0.50        # orman içinde ağaç şansı
const SPARSE_TREE_CHANCE: float = 0.015   # açıklıkta seyrek ağaç
# (world3d ağaç seyreltme kuralı: 1 hücre max 1 ağaç + min 1 boş komşu)

# --- Meyve çalısı -------------------------------------------------------
const BUSH_CHANCE: float = 0.006          # çim hücrelerinde çalı şansı

# --- Doğuş alanı --------------------------------------------------------
const SPAWN_CLEAR_RADIUS: int = 4         # doğuş çevresi temiz (ağaçsız) yarıçap
