extends Node
## PLAYERSTATS — hayatta kalma koordinatörü (autoload). Açlık azalması (efor
## çarpanı), eşik uyarıları, açlık→can bağlantısı (0 iken erime / iyi
## beslenince yenilenme), mide bulantısı, ölüm + yeniden doğuş. TÜM sayılar
## SurvivalBalance'ta (kod içinde sabit yok). Değer deposu mevcut Health/
## Hunger autoload'larında kalır (HUD/kayıt uyumu) — bu script mantığı sürer.

const Balance = preload("res://scripts/survival_balance.gd")

signal hunger_warning       # açlık eşiğin altına düştü (HUD nabız)
signal hunger_recovered     # eşiğin üstüne çıktı
signal nausea_started       # çiğ et mide bulantısı başladı
signal player_died(death_count: int)
signal respawned

## world3d her kare günceller: koşma/kazı gibi efor sırasında true (açlık
## çarpanı SurvivalBalance.EFFORT_HUNGER_MULT'tan gelir — sabit burada yok).
var exerting: bool = false
## Ölüm sayacı (RAPOR/gün özeti istatistiği).
var death_count: int = 0
## world3d atar (yeniden doğuş konumu için respawn_player çağrılır).
var world: Node = null

var _nausea_time: float = 0.0
var _was_warning: bool = false
var _dead: bool = false

func _process(delta: float) -> void:
	if _dead:
		return
	if _nausea_time > 0.0:
		_nausea_time = maxf(0.0, _nausea_time - delta)
	_tick_hunger(delta)
	_tick_health(delta)

## Açlık azalması: efor + (bulantı varsa) 2x çarpanla. Eşik uyarısı sinyali.
func _tick_hunger(delta: float) -> void:
	var mult: float = Balance.EFFORT_HUNGER_MULT if exerting else 1.0
	if _nausea_time > 0.0:
		mult *= Balance.NAUSEA_HUNGER_MULT
	var before := Hunger.value
	Hunger.value = maxf(0.0, Hunger.value - Balance.HUNGER_DECAY_PER_SEC * mult * delta)
	if int(Hunger.value) != int(before):
		Hunger.changed.emit()
	var warn: bool = Hunger.value < Balance.HUNGER_WARN_THRESHOLD
	if warn and not _was_warning:
		hunger_warning.emit()
	elif not warn and _was_warning:
		hunger_recovered.emit()
	_was_warning = warn

## Açlık 0 -> can erir (ölüme kadar). Açlık > eşik -> yavaş can yenilenir.
func _tick_health(delta: float) -> void:
	if Hunger.value <= 0.0:
		Health.value = maxf(0.0, Health.value - Balance.STARVE_HEALTH_LOSS_PER_SEC * delta)
		Health.changed.emit()
		if Health.value <= 0.0:
			_die()
	elif Hunger.value > Balance.REGEN_HUNGER_THRESHOLD \
			and Health.value < Balance.HEALTH_MAX:
		Health.value = minf(Balance.HEALTH_MAX,
				Health.value + Balance.HEALTH_REGEN_PER_SEC * delta)
		Health.changed.emit()

## Bir yiyeceğin doyma değeri (yenebilir mi kontrolü için de kullanılır).
func is_edible(item_id: String) -> bool:
	return Balance.FOOD_SATIATION.has(item_id)

func satiation_of(item_id: String) -> float:
	return float(Balance.FOOD_SATIATION.get(item_id, 0.0))

## Yeme etkisini uygular (yeme eylemi bitince world3d çağırır). Doyma ekler;
## çiğ etse %20 şansla mide bulantısı başlatır. Envanterden düşme çağırana ait.
func apply_food(item_id: String) -> void:
	Hunger.value = minf(Balance.HUNGER_MAX,
			Hunger.value + satiation_of(item_id))
	Hunger.changed.emit()
	if item_id in Balance.RAW_MEAT_IDS and randf() < Balance.NAUSEA_CHANCE:
		_nausea_time = Balance.NAUSEA_DURATION
		nausea_started.emit()

func is_nauseous() -> bool:
	return _nausea_time > 0.0

# --- Ölüm / yeniden doğuş ----------------------------------------------

func _die() -> void:
	if _dead:
		return
	_dead = true
	death_count += 1
	player_died.emit(death_count)
	# Envanter v1'de KORUNUR (Balance.DROP_ITEMS_ON_DEATH kapalı).
	# world3d kararmayı + konumu yönetir; sonra istatler sıfırlanır.
	if world != null and world.has_method("respawn_player"):
		world.respawn_player()
	Health.value = Balance.RESPAWN_HEALTH
	Hunger.value = Balance.RESPAWN_HUNGER
	_nausea_time = 0.0
	_was_warning = false
	Health.changed.emit()
	Hunger.changed.emit()
	_dead = false
	respawned.emit()

## "Yeni Oyun" / reset: sayaç ve durum sıfırlanır (Health/Hunger.reset ayrı).
func reset() -> void:
	death_count = 0
	_nausea_time = 0.0
	_was_warning = false
	_dead = false
