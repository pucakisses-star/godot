extends RefCounted
class_name SurfaceWorldService

## The Core Keeper rule, above ground: the wilds around a town only
## exist near the player. Chunks of surface terrain - grass plains,
## flower meadows, forests, sand barrens, hedge thickets - are derived
## deterministically from the town seed and painted as the player
## wanders out, then dropped again when left far behind. Walking back
## rebuilds the exact same country.

const CHUNK_SIZE := 24

const TILE_ATLAS_DEFS := preload("res://scripts/world_generation/tile_atlas_defs.gd")

static func make_noise_set(world_seed: int) -> Dictionary:
	var elevation := FastNoiseLite.new()
	elevation.seed = world_seed
	elevation.noise_type = FastNoiseLite.TYPE_SIMPLEX
	elevation.frequency = 0.012
	elevation.fractal_type = FastNoiseLite.FRACTAL_FBM
	elevation.fractal_octaves = 3
	var forest := FastNoiseLite.new()
	forest.seed = world_seed + 77
	forest.noise_type = FastNoiseLite.TYPE_SIMPLEX
	forest.frequency = 0.035
	forest.fractal_type = FastNoiseLite.FRACTAL_FBM
	forest.fractal_octaves = 2
	var detail := FastNoiseLite.new()
	detail.seed = world_seed + 154
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail.frequency = 0.6
	# Coastline wobble: LOW frequency on purpose. Wobbling the shore with
	# the per-cell detail noise dithered land and water into a huge
	# salt-and-pepper band; this smooth field makes shores meander in
	# clean curves instead.
	var coast := FastNoiseLite.new()
	coast.seed = world_seed + 233
	coast.noise_type = FastNoiseLite.TYPE_SIMPLEX
	coast.frequency = 0.045
	coast.fractal_type = FastNoiseLite.FRACTAL_FBM
	coast.fractal_octaves = 2
	# Marsh pools: mid frequency so bog water gathers into real pools a
	# few cells wide rather than single-cell speckle.
	var pool := FastNoiseLite.new()
	pool.seed = world_seed + 411
	pool.noise_type = FastNoiseLite.TYPE_SIMPLEX
	pool.frequency = 0.13
	return {"elevation": elevation, "forest": forest, "detail": detail, "coast": coast, "pool": pool}

## The whole overworld's climate, packed for the wilds renderer: given a
## WORLD cell, which overworld tile it sits on and thus which biome. World
## cells are absolute (the town bakes its shared-space offset into them), so
## the full buffer needs no origin. world_biomes is {"w","h","codes":
## PackedByteArray} row-major h*w, each byte a TILE_ATLAS_DEFS biome code.
## world_cells_per_tile is the local cells per overworld tile. Returns {}
## for an empty or malformed buffer (standalone tests).
## world_rivers, when given, is {"w","h","bits":PackedByteArray} row-major
## h*w with a 1 where the overworld tile carries a river; it must match the
## biome buffer's dimensions or it is ignored. river_cache is a mutable
## per-tile course cache: the town streams on the main thread, so carrying
## it on the ctx is safe (the pure RegionMapService port stays stateless).
static func make_biome_context(world_biomes: Dictionary, world_cells_per_tile: int, world_rivers: Dictionary = {}) -> Dictionary:
	if world_biomes.is_empty():
		return {}
	var width := int(world_biomes.get("w", 0))
	var height := int(world_biomes.get("h", 0))
	var codes := world_biomes.get("codes", PackedByteArray()) as PackedByteArray
	if width <= 0 or height <= 0 or codes.size() != width * height:
		return {}
	var river_bits := PackedByteArray()
	if not world_rivers.is_empty():
		var river_width := int(world_rivers.get("w", 0))
		var river_height := int(world_rivers.get("h", 0))
		var bits := world_rivers.get("bits", PackedByteArray()) as PackedByteArray
		if river_width == width and river_height == height and bits.size() == width * height:
			river_bits = bits
	return {
		"w": width,
		"h": height,
		"codes": codes,
		"cells_per_tile": maxi(1, world_cells_per_tile),
		"river_bits": river_bits,
		"river_cache": {}
	}

## The biome label at a WORLD cell: floor into overworld-tile space, then
## read the full buffer (clamped to the true map edge). Grassland when the
## context is empty.
static func biome_for_world_cell(biome_ctx: Dictionary, world_cell: Vector2i) -> String:
	if biome_ctx.is_empty():
		return TILE_ATLAS_DEFS.BIOME_GRASSLAND
	var cells_per_tile := int(biome_ctx.get("cells_per_tile", 64))
	var tile := Vector2i(int(floor(float(world_cell.x) / float(cells_per_tile))), int(floor(float(world_cell.y) / float(cells_per_tile))))
	return _biome_for_tile(biome_ctx, tile)

## Clamping to [0,w-1]x[0,h-1] here is correct: it is the world's own edge,
## not an interior window, so tiles past the map read as its border biome.
static func _biome_for_tile(biome_ctx: Dictionary, tile: Vector2i) -> String:
	var width := int(biome_ctx.get("w", 0))
	var height := int(biome_ctx.get("h", 0))
	if width <= 0 or height <= 0:
		return TILE_ATLAS_DEFS.BIOME_GRASSLAND
	var codes := biome_ctx.get("codes") as PackedByteArray
	var clamped := Vector2i(clampi(tile.x, 0, width - 1), clampi(tile.y, 0, height - 1))
	var index := clamped.y * width + clamped.x
	if index < 0 or index >= codes.size():
		return TILE_ATLAS_DEFS.BIOME_GRASSLAND
	return TILE_ATLAS_DEFS.biome_label(codes[index])

## Whether the overworld tile carries a river, read from the packed bits
## clamped to the world's own edge (a false when the ctx has no rivers).
static func _tile_has_river(biome_ctx: Dictionary, tile: Vector2i) -> bool:
	var bits := biome_ctx.get("river_bits", PackedByteArray()) as PackedByteArray
	if bits.is_empty():
		return false
	var width := int(biome_ctx.get("w", 0))
	var height := int(biome_ctx.get("h", 0))
	if width <= 0 or height <= 0:
		return false
	var clamped := Vector2i(clampi(tile.x, 0, width - 1), clampi(tile.y, 0, height - 1))
	var index := clamped.y * width + clamped.x
	if index < 0 or index >= bits.size():
		return false
	return bits[index] != 0

## The ground and its dressing for one cell:
## {"base": tile key, "decor": tile key or ""}. danger (0..1) is the
## radial rule: the further from civilization, the darker the land -
## meadows give way to deep woods, flowers stop blooming, and thickets
## close in. When biome_ctx is non-empty the overworld climate around the
## settlement steers the palette (ocean at coasts, sand in deserts, denser
## woods in forests, rocky mountain fringes, pale tundra), blended across
## tile borders so coastlines meander; the noise adds within-biome detail.
## An empty biome_ctx reproduces the standalone-noise behavior exactly.
static func terrain_for_cell(cell: Vector2i, noise_set: Dictionary, danger: float = 0.0, biome_ctx: Dictionary = {}) -> Dictionary:
	var elevation := (noise_set.get("elevation") as FastNoiseLite).get_noise_2d(float(cell.x), float(cell.y))
	var forest := (noise_set.get("forest") as FastNoiseLite).get_noise_2d(float(cell.x), float(cell.y))
	var detail := (noise_set.get("detail") as FastNoiseLite).get_noise_2d(float(cell.x), float(cell.y))
	forest += danger * 0.3
	if biome_ctx.is_empty():
		return _legacy_terrain(cell, elevation, forest, detail, danger)
	return _biome_terrain(cell, noise_set, elevation, forest, detail, danger, biome_ctx)

## The standalone-noise wilds (no overworld context): the lowest basins
## hold boatable water, the lowlands dry to barrens, and grassland shades
## darker under canopy and in the deep wilds.
static func _legacy_terrain(cell: Vector2i, elevation: float, forest: float, detail: float, danger: float) -> Dictionary:
	# The lowest basins hold open water: lakes and ponds a walker needs
	# a boat to cross. Sand shores ring them via the band below.
	if elevation < -0.5:
		return {"base": "water" if detail > -0.2 else "water_calm", "decor": ""}
	# Dry barrens fill the lowlands; deep ones read scorched.
	if elevation < -0.36:
		return {"base": "sand_pebbles" if detail > 0.3 - danger * 0.5 else "sand", "decor": ""}
	if elevation < -0.3:
		return {"base": "sand_alt" if detail > 0.0 else "sand", "decor": ""}
	# Grassland, shaded darker under heavy canopy and in the deep wilds.
	var base := "grass"
	if forest > 0.2 or danger > 0.62:
		base = "grass_dark"
	elif detail > 0.42:
		base = "grass_tuft"
	elif detail < -0.52 and danger < 0.4:
		base = "flowers_white" if cell.x % 2 == 0 else "flowers_yellow"
	var decor := ""
	if forest > 0.16:
		# Forests thicken toward their heart; the detail noise scatters
		# the individual trunks so edges stay ragged.
		var tree_bias := clampf((forest - 0.16) * 2.4, 0.0, 0.82 + danger * 0.1)
		if detail > 0.7 - tree_bias:
			decor = "tree_dark" if forest > 0.4 or danger > 0.55 else "tree"
	elif forest < -0.42 and detail > 0.55 - danger * 0.2:
		decor = "hedge" if detail < 0.72 else "hedge_alt"
	return {"base": base, "decor": decor}

## The overworld-steered wilds. The coast is a bilinear water-presence
## field wobbled by the detail noise, so shores meander instead of snapping
## to the tile grid; a sand beach hugs the waterline; and on land the
## argmax of per-biome presence fields (each with its own noise wobble)
## decides the climate, so deserts meet forests along meandering fronts.
static func _biome_terrain(cell: Vector2i, noise_set: Dictionary, elevation: float, forest: float, detail: float, danger: float, biome_ctx: Dictionary) -> Dictionary:
	var cells_per_tile := int(biome_ctx.get("cells_per_tile", 64))
	var tile := Vector2i(int(floor(float(cell.x) / float(cells_per_tile))), int(floor(float(cell.y) / float(cells_per_tile))))
	var local_x := cell.x - tile.x * cells_per_tile
	var local_y := cell.y - tile.y * cells_per_tile
	var fx := (float(local_x) + 0.5) / float(cells_per_tile)
	var fy := (float(local_y) + 0.5) / float(cells_per_tile)
	var biomes3x3 := PackedStringArray()
	biomes3x3.resize(9)
	var water3x3 := PackedFloat32Array()
	water3x3.resize(9)
	for ny in 3:
		for nx in 3:
			var neighbor := tile + Vector2i(nx - 1, ny - 1)
			var index := ny * 3 + nx
			var label := _biome_for_tile(biome_ctx, neighbor)
			biomes3x3[index] = label
			water3x3[index] = 1.0 if label == (TILE_ATLAS_DEFS.BIOME_WATER as String) else 0.0
	# The coastline is the water-presence field wobbled by a dedicated
	# SMOOTH noise: shores meander in clean curves. (The old per-cell
	# detail wobble dithered the whole transition into speckle.)
	var coast_wobble := detail * 0.16
	var coast_noise := noise_set.get("coast") as FastNoiseLite
	if coast_noise != null:
		coast_wobble = coast_noise.get_noise_2d(float(cell.x), float(cell.y)) * 0.18
	var coast := _field_from_neighbors(water3x3, fx, fy) + coast_wobble
	if coast > 0.52:
		return {"base": "water" if detail > -0.15 else "water_calm", "decor": ""}
	var own_biome := String(biomes3x3[4])
	var land_own := own_biome if own_biome != (TILE_ATLAS_DEFS.BIOME_WATER as String) else String(TILE_ATLAS_DEFS.BIOME_GRASSLAND)
	if coast > 0.46:
		# Wading shallows: a walkable ribbon of thigh-deep water over a
		# sandy bottom between the beach and the open water.
		return {"base": "water_shallow", "decor": ""}
	if coast > 0.4:
		# A sandy shoreline just above the waterline.
		return {"base": "sand" if detail > -0.2 else "sand_pebbles", "decor": ""}
	# The overworld's rivers reproduced on the ground: the tile's meandering
	# course is built once (cached on the ctx) and carved into whatever land
	# it crosses. Coast and beach are already handled above, so this only
	# touches dry cells; the course reads as ordinary water (block/boatable).
	if _tile_has_river(biome_ctx, tile):
		var river_cells := _river_mask_for_tile(biome_ctx, tile, water3x3, noise_set, cells_per_tile)
		if river_cells.has(local_y * cells_per_tile + local_x):
			return {"base": "water" if detail > -0.15 else "water_calm", "decor": ""}
	var land_biome := _blend_land_biome(biomes3x3, land_own, cell, noise_set, fx, fy)
	return _terrain_for_biome(land_biome, cell, elevation, forest, detail, danger, noise_set)

## Per-candidate bilinear presence plus per-biome noise wobble; the high
## bid wins, so land biomes meet along meandering fronts instead of tile
## edges. Water neighbors vote for the tile's own land biome - the coast
## field above owns that transition.
static func _blend_land_biome(biomes3x3: PackedStringArray, land_own: String, cell: Vector2i, noise_set: Dictionary, fx: float, fy: float) -> String:
	var resolved := PackedStringArray()
	resolved.resize(9)
	var uniform := true
	for index in 9:
		var label := biomes3x3[index]
		if label.is_empty() or label == (TILE_ATLAS_DEFS.BIOME_WATER as String):
			label = land_own
		resolved[index] = label
		if label != land_own:
			uniform = false
	if uniform:
		return land_own
	var noise := noise_set.get("detail") as FastNoiseLite
	var best_biome := land_own
	var best_score := -1.0
	var seen: Dictionary = {}
	for index in 9:
		var candidate := resolved[index]
		if seen.has(candidate):
			continue
		seen[candidate] = true
		var presence := PackedFloat32Array()
		presence.resize(9)
		for presence_index in 9:
			presence[presence_index] = 1.0 if resolved[presence_index] == candidate else 0.0
		# Decorrelated wobble per candidate keeps the argmax from collapsing
		# back into straight tile edges.
		var wobble_seed := float(hash(candidate) % 1024)
		var wobble := noise.get_noise_2d(float(cell.x) * 0.11 + wobble_seed * 91.0, float(cell.y) * 0.11 - wobble_seed * 57.0)
		var score := _field_from_neighbors(presence, fx, fy) + wobble * 0.22
		if score > best_score:
			best_score = score
			best_biome = candidate
	return best_biome

## The ground/decor for one land biome, using the noise fields for
## within-biome detail. The tileset has no stone/marsh surface art, so those
## climates render through the closest available keys: rock as pebble/sand,
## marsh as dark grass pocked with calm water. Tundra uses the painted-in
## snow ground tile.
static func _terrain_for_biome(biome: String, cell: Vector2i, elevation: float, forest: float, detail: float, danger: float, noise_set: Dictionary = {}) -> Dictionary:
	match biome:
		TILE_ATLAS_DEFS.BIOME_DESERT:
			var base := "sand"
			if detail > 0.3:
				base = "sand_pebbles"
			elif detail > 0.0:
				base = "sand_alt"
			return {"base": base, "decor": ""}
		TILE_ATLAS_DEFS.BIOME_BADLANDS:
			return {"base": "sand_pebbles" if detail > -0.2 else "sand", "decor": ""}
		TILE_ATLAS_DEFS.BIOME_MOUNTAIN:
			# Rocky fringes: pebble crags with sparse dark conifers and drier
			# grass in the folds. Crags are impassable rock; the low valley
			# folds and lower slopes stay walkable so a range is a real
			# barrier with passes threaded through it, not a solid wall.
			var base := "sand_pebbles"
			if detail < -0.35:
				base = "grass_dark"
			elif detail < 0.05:
				base = "sand"
			var decor := ""
			if forest > 0.35 and detail > 0.55:
				decor = "tree_dark"
			# Crags block; folds and lower slopes below the threshold stay
			# open. The detail noise is high-frequency, so the threshold is
			# tuned to -0.1: above it the range is a clear majority of rock,
			# below it the open cells still percolate into continuous valley
			# passes a walker can thread from one side to the other.
			var mountain_terrain := {"base": base, "decor": decor}
			if detail > -0.1:
				mountain_terrain["blocked"] = true
			return mountain_terrain
		TILE_ATLAS_DEFS.BIOME_HILLS:
			# Greener than the peaks, still stony on the ridgelines.
			var base := "grass_dark"
			if detail > 0.35:
				base = "sand_pebbles"
			elif detail > 0.1:
				base = "grass_tuft"
			var decor := ""
			if forest > 0.3 and detail > 0.5:
				decor = "tree_dark" if danger > 0.55 else "tree"
			return {"base": base, "decor": decor}
		TILE_ATLAS_DEFS.BIOME_TUNDRA:
			# Real snow ground (painted into the town/surface tileset), with
			# an occasional drift variant and the odd wind-bent conifer.
			var base := "snow_alt" if detail > 0.35 else "snow"
			var decor := ""
			if forest > 0.32 and detail > 0.6:
				decor = "tree_dark"
			return {"base": base, "decor": decor}
		TILE_ATLAS_DEFS.BIOME_MARSH:
			# Dark waterlogged grass gathered into real bog pools (the pool
			# noise is mid-frequency, so water forms wadeable ponds a few
			# cells wide instead of single-cell speckle).
			var pool_noise := noise_set.get("pool") as FastNoiseLite
			if pool_noise != null:
				if pool_noise.get_noise_2d(float(cell.x), float(cell.y)) > 0.3:
					return {"base": "water_shallow", "decor": ""}
			elif detail > 0.25:
				return {"base": "water_calm", "decor": ""}
			var base := "grass_tuft" if detail < -0.45 else "grass_dark"
			var decor := ""
			if forest < -0.4 and detail > 0.0:
				decor = "hedge"
			return {"base": base, "decor": decor}
		TILE_ATLAS_DEFS.BIOME_FOREST:
			# Denser woods: canopy grass with a low tree threshold.
			var base := "grass"
			if forest > 0.0 or danger > 0.62:
				base = "grass_dark"
			elif detail > 0.42:
				base = "grass_tuft"
			var decor := ""
			var tree_bias := clampf((forest + 0.3) * 2.4, 0.0, 0.9 + danger * 0.08)
			if detail > 0.4 - tree_bias:
				decor = "tree_dark" if forest > 0.3 or danger > 0.55 else "tree"
			return {"base": base, "decor": decor}
		TILE_ATLAS_DEFS.BIOME_JUNGLE:
			# Deepest, darkest canopy: dark grass smothered in dark trees.
			var decor := ""
			var tree_bias := clampf((forest + 0.5) * 2.4, 0.0, 0.95)
			if detail > 0.3 - tree_bias:
				decor = "tree_dark"
			return {"base": "grass_dark", "decor": decor}
	# Grassland and any unmapped climate keep the standalone-noise wilds.
	return _legacy_terrain(cell, elevation, forest, detail, danger)

## Bilinear between tile centers so a field crosses tile boundaries
## smoothly instead of stair-stepping the tile grid.
static func _field_from_neighbors(values: PackedFloat32Array, fx: float, fy: float) -> float:
	var ox := fx - 0.5
	var oy := fy - 0.5
	var sx := -1 if ox < 0.0 else 1
	var sy := -1 if oy < 0.0 else 1
	var wx := absf(ox)
	var wy := absf(oy)
	var own := values[4]
	var horizontal := values[4 + sx]
	var vertical := values[4 + 3 * sy]
	var diagonal := values[4 + 3 * sy + sx]
	return lerpf(lerpf(own, horizontal, wx), lerpf(vertical, diagonal, wx), wy)

## The tile's river course, built once and cached on the ctx. The 3x3
## river-bit neighborhood joins the shared water3x3 field, so a flagged
## tile knows which of its edges to reach toward. The course is stored
## SPARSELY (a set of local linear cell indices) rather than a dense
## grid*grid mask, so a large cells_per_tile costs river-length memory,
## not tile-area memory.
static func _river_mask_for_tile(biome_ctx: Dictionary, tile: Vector2i, water3x3: PackedFloat32Array, noise_set: Dictionary, cells_per_tile: int) -> Dictionary:
	var cache := biome_ctx.get("river_cache", {}) as Dictionary
	if cache.has(tile):
		return cache[tile] as Dictionary
	var river3x3 := PackedFloat32Array()
	river3x3.resize(9)
	for ny in 3:
		for nx in 3:
			var neighbor := tile + Vector2i(nx - 1, ny - 1)
			river3x3[ny * 3 + nx] = 1.0 if _tile_has_river(biome_ctx, neighbor) else 0.0
	var mask := _build_river_mask(tile, river3x3, water3x3, noise_set, cells_per_tile)
	cache[tile] = mask
	return mask

## Ported from RegionMapService: rivers run tile center to edge midpoints,
## one meandering segment per river or sea neighbor, wobble faded to zero at
## both endpoints so a tile's course meets its neighbors' exactly at the
## shared edge. A lone river tile still shows its stream, north to south.
## Returns a set {local_index: true}.
static func _build_river_mask(tile: Vector2i, river3x3: PackedFloat32Array, water3x3: PackedFloat32Array, noise_set: Dictionary, grid: int) -> Dictionary:
	var mask: Dictionary = {}
	var center := Vector2(grid * 0.5, grid * 0.5)
	var noise := noise_set.get("detail") as FastNoiseLite
	var connections := 0
	var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for direction: Vector2i in directions:
		var index := 4 + direction.x + 3 * direction.y
		if river3x3[index] < 0.5 and water3x3[index] < 0.5:
			continue
		var edge_mid := center + Vector2(direction) * (grid * 0.5)
		_stamp_river_segment(mask, center, edge_mid, tile, noise, grid)
		connections += 1
	if connections == 0:
		_stamp_river_segment(mask, Vector2(center.x, 0.0), center, tile, noise, grid)
		_stamp_river_segment(mask, center, Vector2(center.x, float(grid)), tile, noise, grid)
	return mask

static func _stamp_river_segment(mask: Dictionary, from_point: Vector2, to_point: Vector2, tile: Vector2i, noise: FastNoiseLite, grid: int) -> void:
	var axis := (to_point - from_point).normalized()
	var perpendicular := Vector2(-axis.y, axis.x)
	# Width, meander amplitude and meander wavelength all scale with the
	# tile's cell resolution, so a stream reads the same whether a tile is
	# 64 or 768 cells across (at 64 these collapse to the original 1-cell
	# brush, 11-cell wobble, 0.12 frequency).
	var brush := maxi(1, grid / 256)
	var wobble_amp := 11.0 * float(grid) / 64.0
	var wobble_freq := 0.12 * 64.0 / float(grid)
	# One sample per cell of segment length keeps the course continuous at
	# any scale (the dense mask relied on 56 steps oversampling a 32-cell run).
	var steps := maxi(56, int(ceil((to_point - from_point).length())))
	for step in steps + 1:
		var t := float(step) / float(steps)
		var straight := from_point.lerp(to_point, t)
		# Wobble is sampled in world-cell units - the same "surface|seed"
		# detail noise the map render uses - so the ground reproduces the
		# world map's exact course; it fades to zero at both endpoints.
		var world := Vector2(tile * grid) + straight
		var wobble := noise.get_noise_2d(world.x * wobble_freq, world.y * wobble_freq) * wobble_amp * sin(PI * t)
		var pos := straight + perpendicular * wobble
		var px := int(round(pos.x))
		var py := int(round(pos.y))
		for oy in range(-brush, brush + 1):
			for ox in range(-brush, brush + 1):
				var mx := px + ox
				var my := py + oy
				if mx >= 0 and my >= 0 and mx < grid and my < grid:
					mask[my * grid + mx] = true

static func chunk_for_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(int(floor(float(cell.x) / CHUNK_SIZE)), int(floor(float(cell.y) / CHUNK_SIZE)))

static func chunk_rect(chunk: Vector2i) -> Rect2i:
	return Rect2i(chunk * CHUNK_SIZE, Vector2i(CHUNK_SIZE, CHUNK_SIZE))
