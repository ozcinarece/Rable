extends RefCounted
## MÜHENDİSLİK DENGE VERİSİ (KAZI_SU_MODULU 11.5/11.8/11.9 + GAME_DESIGN 8).
## Merdiven, kazık, boru/pompa/vana sayıları TEK bu dosyada — kod dokunmadan
## elle ayarlanır. Kapsam: yalnız veri; davranış scriptlerde.

# --- Merdiven (11.5) ----------------------------------------------------
## Bu derinlik ve DAHA derin çukurdan merdivensiz ÇIKILAMAZ (1-2 serbest).
const LADDER_DEEP_MIN := 3
## Merdiven erişimi: merdiven hücrede mi yoksa 4-komşusunda da yeterli mi?
const LADDER_ADJACENT_OK := true

# --- Çukur kazığı (11.9) ------------------------------------------------
## Kazığa düşen oyuncunun aldığı küçük hasar (test edilebilirlik).
const SPIKE_FALL_DAMAGE := 8
## Kazık görsel yüksekliği (çukur tabanından yükselen), metre.
const SPIKE_VISUAL_HEIGHT := 0.5

# --- Boru sistemi (11.8) ------------------------------------------------
## Bağlı ve AKTİF hatta saniyede taşınan su birimi (kaynak→hedef).
const PIPE_TRANSFER_PER_SEC := 2.0
## Su kendi başına yalnız AŞAĞI/AYNI seviyeye akar: kaynak yüksekliği
## (−depth) ≥ hedef yüksekliği olmalı. Pompa bu kuralı aşar.
## (Yükseklik = zemin kotu − depth; büyük = yüksek.)

# --- Pompa (11.8) -------------------------------------------------------
## Pompa hattı yukarı taşıyabilir (yükseklik kuralını aşar).
## Yakıt (kömür) fikri: şimdilik KAPALI bayrak (yakıtsız çalışır) — TODO.
const PUMP_REQUIRES_FUEL := false
## Pompalı hatta saniyede taşınan su (yukarı akışta).
const PUMP_TRANSFER_PER_SEC := 2.0

# --- Vana (11.8) --------------------------------------------------------
## Yeni kurulan vana varsayılan durumu (false = kapalı).
const VALVE_DEFAULT_OPEN := false

# --- Genel --------------------------------------------------------------
## Boru ağı transferini kaç saniyede bir işle (mobil performansı; su
## fiziksel akmaz, mantıksal tik). Küçük = akıcı, büyük = ucuz.
const NET_TICK_SECONDS := 0.5
