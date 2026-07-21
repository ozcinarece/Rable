extends RefCounted
## HAVUZ COZUCU (KAZI_SU_MODULU.md 11.2): kazilmis hucrelerden
## "bilesik kaplar" dogrulugunda su havuzlari cikarir.
##
## SADECE veri isler - sahneye/gorsele dokunmaz. Kare basina maliyet
## SIFIR: yalnizca arazi/su degistiginde (kaz, yig, dok, al) sifirdan
## cagirilir; kazilmis hucre sayisi kucuk oldugundan tam yeniden hesap
## ucuzdur. Havuz bolunme/birlesme flood-fill'den kendiliginden cikar.

## depth sozlugunden havuzlari cikarir: depth >= 1 hucrelerin 4-komsu
## baglantili bilesenleri. Donus: [{"cells": [Vector2i..], "capacity": f}]
static func compute_pools(depth: Dictionary) -> Array:
	var pools: Array = []
	var seen: Dictionary = {}
	for start in depth:
		if int(depth[start]) < 1 or seen.has(start):
			continue
		var cells: Array = []
		var capacity := 0.0
		var stack: Array = [start]
		seen[start] = true
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			cells.append(c)
			capacity += float(int(depth[c]))
			for n in [Vector2i(1, 0), Vector2i(-1, 0),
					Vector2i(0, 1), Vector2i(0, -1)]:
				var nc: Vector2i = c + n
				if not seen.has(nc) and int(depth.get(nc, 0)) >= 1:
					seen[nc] = true
					stack.append(nc)
		pools.append({"cells": cells, "capacity": capacity})
	return pools

## Havuzun TEK su yuzeyi kotunu cozer: s oyle ki SUM max(0, s + d_i)
## = hacim. Birim "seviye": 0 = zemin kotu, hucre tabani = -d_i.
## Farkli derinlikteki hucreler ayni yuzeyi paylasir (bilesik kaplar).
## Hacim kapasiteyi asmamali (cagiran kirpar).
static func solve_surface(cells: Array, depth: Dictionary, volume: float) -> float:
	var deepest := 0
	for c in cells:
		deepest = maxi(deepest, int(depth.get(c, 0)))
	if volume <= 0.0:
		return -float(deepest)
	# Tabanlari derinden sigla tara; su bir sonraki tabana ulasana
	# kadar aktif hucrelere esit dagilir
	var floors: Array = []
	for c in cells:
		floors.append(-float(int(depth.get(c, 0))))
	floors.sort()
	var s: float = floors[0]
	var left := volume
	var active := 0
	var idx := 0
	while left > 0.0:
		while idx < floors.size() and float(floors[idx]) <= s + 0.000001:
			idx += 1
			active += 1
		var next_floor := 0.0 if idx >= floors.size() else float(floors[idx])
		var room := (next_floor - s) * float(active)
		if idx >= floors.size() or room >= left:
			s += left / float(active)
			left = 0.0
		else:
			s = next_floor
			left -= room
	return minf(s, 0.0)

## Cozulen yuzeye gore hucre basina su sutunu (seviye cinsinden)
static func distribute(cells: Array, depth: Dictionary, surface: float) -> Dictionary:
	var out: Dictionary = {}
	for c in cells:
		out[c] = maxf(0.0, surface + float(int(depth.get(c, 0))))
	return out
