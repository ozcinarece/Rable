extends RefCounted
## PROSEDÜREL HARİTA ÜRETECİ (noise + seed). MapData.MAP'in yerine geçer;
## AYNI char formatında bir Array[String] döndürür (world3d._build_world
## değişmeden tüketir). Aynı seed => aynı harita. Sayılar MapBalance'ta.
##
## Char sözlüğü: "." çim · "d" toprak · "s" kum · "~" su · "h" yüksek plato
##   "#" kaya · "T" ağaç · "m" meyve çalısı · "k" kil-işaretli kum · "P" doğuş
##
## Not: Düz bir PackedByteArray (idx=y*n+x) kullanılır. `Array[PackedByteArray]`
## içinde `grid[y][x]=v` KALICI DEĞİL (packed dizi kopya-üzerine-yazma) — bu
## yüzden tek boyutlu tampon + elle indeksleme.

const B = preload("res://scripts/map_balance.gd")

const C_GRASS := 46   # "."
const C_DIRT := 100   # "d"
const C_SAND := 115   # "s"
const C_WATER := 126  # "~"
const C_HILL := 104   # "h"
const C_ROCK := 35    # "#"
const C_TREE := 84    # "T"
const C_BUSH := 109   # "m"
const C_CLAY := 107   # "k"
const C_SPAWN := 80   # "P"

static func generate(seed_val: int) -> Array[String]:
	var n: int = B.MAP_SIZE
	var grid := PackedByteArray()
	grid.resize(n * n)
	grid.fill(C_GRASS)

	var terrain := FastNoiseLite.new()
	terrain.seed = seed_val
	terrain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	terrain.frequency = B.DIRT_SCALE
	var hill := FastNoiseLite.new()
	hill.seed = seed_val + 11
	hill.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	hill.frequency = B.HILL_SCALE
	var forest := FastNoiseLite.new()
	forest.seed = seed_val + 23
	forest.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	forest.frequency = B.FOREST_SCALE
	var laken := FastNoiseLite.new()
	laken.seed = seed_val + 37
	laken.noise_type = FastNoiseLite.TYPE_SIMPLEX
	laken.frequency = B.LAKE_NOISE_SCALE
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var lake_c := Vector2(B.LAKE_CENTER.x * n, B.LAKE_CENTER.y * n)

	# 1) GÖL + kıyı kumu + kil işaretleri (doğal kavisli kenar)
	for y in n:
		for x in n:
			var d := Vector2(x, y).distance_to(lake_c)
			var edge: float = B.LAKE_RADIUS + laken.get_noise_2d(x, y) * B.LAKE_EDGE_JITTER
			if d < edge - B.SHORE_WIDTH:
				grid[y * n + x] = C_WATER
			elif d < edge:
				grid[y * n + x] = C_CLAY if rng.randf() < B.CLAY_CHANCE else C_SAND

	# 2) Yüksek plato + 3) toprak lekeleri (yalnızca çim üstünde)
	for y in n:
		for x in n:
			var k := y * n + x
			if grid[k] != C_GRASS:
				continue
			if _n01(hill.get_noise_2d(x, y)) > B.HILL_THRESHOLD:
				grid[k] = C_HILL
			elif _n01(terrain.get_noise_2d(x, y)) > B.DIRT_THRESHOLD:
				grid[k] = C_DIRT

	# 4) KAYA öbekleri (rastgele yürüyüş; çim/toprak üstüne)
	for i in B.ROCK_CLUSTERS:
		var cx := rng.randi_range(6, n - 7)
		var cz := rng.randi_range(6, n - 7)
		var count := rng.randi_range(B.ROCK_CLUSTER_MIN, B.ROCK_CLUSTER_MAX)
		for j in count:
			if cx >= 1 and cz >= 1 and cx < n - 1 and cz < n - 1:
				var k := cz * n + cx
				if grid[k] == C_GRASS or grid[k] == C_DIRT:
					grid[k] = C_ROCK
			cx += rng.randi_range(-1, 1)
			cz += rng.randi_range(-1, 1)

	# 5) AĞAÇLAR: orman alanları (öbek) + seyrek tekiller
	for y in n:
		for x in n:
			var k := y * n + x
			if grid[k] != C_GRASS and grid[k] != C_DIRT:
				continue
			var f := _n01(forest.get_noise_2d(x, y))
			var place := false
			if f > B.FOREST_THRESHOLD:
				place = rng.randf() < B.FOREST_DENSITY
			else:
				place = rng.randf() < B.SPARSE_TREE_CHANCE
			if place:
				grid[k] = C_TREE

	# 6) MEYVE çalıları (kalan çim)
	for y in n:
		for x in n:
			var k := y * n + x
			if grid[k] == C_GRASS and rng.randf() < B.BUSH_CHANCE:
				grid[k] = C_BUSH

	# 7) DOĞUŞ: merkeze yakın düz çim; çevresi temizlenir (güvenli açıklık)
	var sp := _find_spawn(grid, n)
	var r: int = B.SPAWN_CLEAR_RADIUS
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cx2 := sp.x + dx
			var cz2 := sp.y + dy
			if cx2 < 1 or cz2 < 1 or cx2 >= n - 1 or cz2 >= n - 1:
				continue
			var kk := cz2 * n + cx2
			var cur := grid[kk]
			if cur == C_TREE or cur == C_ROCK or cur == C_BUSH \
					or cur == C_HILL or cur == C_DIRT:
				grid[kk] = C_GRASS
	grid[sp.y * n + sp.x] = C_SPAWN

	# 8) Kenar kuşağı: en dış halka kum (denize inen kumsal hissi)
	for i in n:
		grid[i] = C_SAND                    # üst satır
		grid[(n - 1) * n + i] = C_SAND      # alt satır
		grid[i * n] = C_SAND                # sol sütun
		grid[i * n + (n - 1)] = C_SAND      # sağ sütun

	# Satırları String'e çevir (idx=y*n+x -> her satır dilim)
	var out: Array[String] = []
	for y in n:
		out.append(grid.slice(y * n, y * n + n).get_string_from_ascii())
	return out

## Noise (-1..1) -> (0..1)
static func _n01(v: float) -> float:
	return v * 0.5 + 0.5

## Merkeze en yakın çim/toprak hücresi (su/plato/ağaç değil): düz güvenli yer.
static func _find_spawn(grid: PackedByteArray, n: int) -> Vector2i:
	var c := Vector2i(n / 2, n / 2)
	for radius in range(0, n / 2):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var x := c.x + dx
				var y := c.y + dy
				if x < 2 or y < 2 or x >= n - 2 or y >= n - 2:
					continue
				var g := grid[y * n + x]
				if g == C_GRASS or g == C_DIRT:
					return Vector2i(x, y)
	return c
