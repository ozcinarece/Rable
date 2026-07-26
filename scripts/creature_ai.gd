extends RefCounted
## YARATIK YOL BULMA (A*) — hücre ızgarası üzerinde.
##
## NEDEN GEREKLİ: minimal sürümde yaratıklar hedefe DÜZ ÇİZGİDE gidiyor,
## engele çarpınca bir süre yana kayıyordu. Sonuç: duvar örmek anlamsız
## kalıyordu (yaratık duvarı dolaşamıyor, önünde sıkışıyor) ve yaratıklar
## aptal görünüyordu.
##
## TASARIM KARARI — "kır ya da dolaş" tek maliyet fonksiyonunda:
## Yürünemeyen ama KIRILABİLİR hücreler (yapı/ağaç/kaya) yola KAPALI
## değil, sadece PAHALI. Böylece ayrı bir "kırma kararı" mantığı yazmaya
## gerek kalmıyor: kısa bir duvarı dolaşmak ucuzsa dolaşır, kapıyı
## çevreleyen uzun duvarda kırmak ucuzsa kırar. Oyuncunun duvar tasarımı
## doğrudan yaratığın davranışını belirliyor.
##
## MOBİL BÜTÇE: arama düğüm sayısı sınırlı (MAX_NODES). Bütçe dolarsa
## o ana kadarki en iyi düğümden kısmi yol döner — yaratık hiç durmaz,
## bir sonraki yeniden-planlamada yolun kalanını bulur.

const Balance = preload("res://scripts/creature_balance.gd")

## 4 yön. Köşegen YOK: köşegen yürüyüş duvar köşesinden sızmaya yol açar
## ve "duvar ördüm ama içeri girdi" hissi verir.
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1)]

## Bir hücreye girme maliyeti. -1 = geçilemez (harita dışı / su).
## world: is_walkable(cell) ve break_cost(cell) sağlayan nesne.
static func _enter_cost(world, cell: Vector2i, traits: Dictionary) -> int:
	if world.is_walkable(cell):
		return 1
	return world.creature_break_cost(cell, traits)

## A* — start'tan goal'e hücre listesi (start HARİÇ, goal DAHİL).
## Yol yoksa boş dizi. Bütçe dolarsa hedefe EN YAKIN düğüme kadar
## kısmi yol.
static func find_path(world, start: Vector2i, goal: Vector2i,
		traits: Dictionary = {},
		max_nodes: int = Balance.PATH_MAX_NODES) -> Array:
	if start == goal:
		return []
	var came: Dictionary = {}        # cell -> onceki cell
	var gscore: Dictionary = {start: 0}
	# Ikili yigin: [f, cell] ciftleri. GDScript'te hazir oncelik kuyrugu
	# yok; kucuk bir yigin, siralamali dizi eklemeden cok daha ucuz.
	var heap: Array = [[_h(start, goal), start]]
	var expanded := 0
	var best := start
	var best_h := _h(start, goal)

	while not heap.is_empty() and expanded < max_nodes:
		var top: Array = _heap_pop(heap)
		var cur: Vector2i = top[1]
		if cur == goal:
			return _rebuild(came, cur)
		expanded += 1
		var hcur := _h(cur, goal)
		if hcur < best_h:
			best_h = hcur
			best = cur
		for d: Vector2i in DIRS:
			var nb: Vector2i = cur + d
			var step := _enter_cost(world, nb, traits)
			if step < 0:
				continue
			var ng: int = int(gscore[cur]) + step
			if gscore.has(nb) and ng >= int(gscore[nb]):
				continue
			gscore[nb] = ng
			came[nb] = cur
			_heap_push(heap, [ng + _h(nb, goal), nb])
	# Butce doldu ya da yol yok: hedefe en yakin dugume kadar git.
	# Bos donmek yaratigi dondururdu; kismi yol hareketi surdurur ve
	# bir sonraki yeniden-planlama kalanini bulur.
	if best != start:
		return _rebuild(came, best)
	return []

## Manhattan mesafesi — 4 yönlü ızgarada kabul edilebilir (admissible)
## sezgisel: gerçek maliyeti asla abartmaz, yani A* en kısa yolu bulur.
static func _h(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

static func _rebuild(came: Dictionary, end_cell: Vector2i) -> Array:
	var out: Array = [end_cell]
	var cur := end_cell
	while came.has(cur):
		cur = came[cur]
		out.append(cur)
	out.reverse()
	out.remove_at(0)   # start hucresini cikar
	return out

# --- Ikili yigin (min-heap) ---------------------------------------------

static func _heap_push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if heap[p][0] <= heap[i][0]:
			break
		var t = heap[p]
		heap[p] = heap[i]
		heap[i] = t
		i = p

static func _heap_pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return top
	heap[0] = last
	var i := 0
	var n := heap.size()
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var s := i
		if l < n and heap[l][0] < heap[s][0]:
			s = l
		if r < n and heap[r][0] < heap[s][0]:
			s = r
		if s == i:
			break
		var t = heap[s]
		heap[s] = heap[i]
		heap[i] = t
		i = s
	return top
