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
	return {"elevation": elevation, "forest": forest, "detail": detail}

## The overworld climate around a settlement, packed for the wilds
## renderer: given a WORLD cell, which overworld tile it sits on and thus
## which biome. patch is {"origin": {"x","y"}, "radius": R, "biomes":
## PackedStringArray} (row-major (2R+1)x(2R+1) window). world_origin is
## the town's shared-space offset; world_cells_per_tile is the local cells
## per overworld tile. Returns {} for an empty patch (standalone tests).
static func make_biome_context(patch: Dictionary, world_origin: Vector2i, world_cells_per_tile: int) -> Dictionary:
	if patch.is_empty():
		return {}
	var biomes := patch.get("biomes", PackedStringArray()) as PackedStringArray
	if biomes == null or biomes.is_empty():
		return {}
	var radius := int(patch.get("radius", 0))
	var span := 2 * radius + 1
	if biomes.size() != span * span:
		return {}
	var origin_variant: Variant = patch.get("origin", {})
	var origin_tile := Vector2i.ZERO
	if origin_variant is Dictionary:
		origin_tile = Vector2i(int((origin_variant as Dictionary).get("x", 0)), int((origin_variant as Dictionary).get("y", 0)))
	return {
		"origin_tile": origin_tile,
		"span": span,
		"biomes": biomes,
		"cells_per_tile": maxi(1, world_cells_per_tile),
		"world_origin": world_origin
	}

## The biome label at a WORLD cell: floor into overworld-tile space, clamp
## into the stored window, read the row-major label. Grassland when the
## context is empty or the cell falls outside the window.
static func biome_for_world_cell(biome_ctx: Dictionary, world_cell: Vector2i) -> String:
	if biome_ctx.is_empty():
		return TILE_ATLAS_DEFS.BIOME_GRASSLAND
	var cells_per_tile := int(biome_ctx.get("cells_per_tile", 64))
	var tile := Vector2i(int(floor(float(world_cell.x) / float(cells_per_tile))), int(floor(float(world_cell.y) / float(cells_per_tile))))
	return _biome_for_tile(biome_ctx, tile)

static func _biome_for_tile(biome_ctx: Dictionary, tile: Vector2i) -> String:
	var origin_tile := biome_ctx.get("origin_tile", Vector2i.ZERO) as Vector2i
	var span := int(biome_ctx.get("span", 1))
	var biomes := biome_ctx.get("biomes") as PackedStringArray
	var local := tile - origin_tile
	# Outside the stored window, fall back to neutral grassland - never
	# clamp to the edge biome, or a coastal town's water edge would wall
	# the whole outer band with ocean past the patch.
	if local.x < 0 or local.y < 0 or local.x >= span or local.y >= span:
		return TILE_ATLAS_DEFS.BIOME_GRASSLAND
	var index := local.y * span + local.x
	if index < 0 or index >= biomes.size():
		return TILE_ATLAS_DEFS.BIOME_GRASSLAND
	var label := biomes[index]
	return label if not label.is_empty() else TILE_ATLAS_DEFS.BIOME_GRASSLAND

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
	# The coastline is the water-presence field wobbled by the detail
	# noise, the same trick the detailed map view uses for its shores.
	var coast := _field_from_neighbors(water3x3, fx, fy) + detail * 0.16
	if coast > 0.5:
		return {"base": "water" if detail > -0.15 else "water_calm", "decor": ""}
	var own_biome := String(biomes3x3[4])
	var land_own := own_biome if own_biome != (TILE_ATLAS_DEFS.BIOME_WATER as String) else String(TILE_ATLAS_DEFS.BIOME_GRASSLAND)
	if coast > 0.4:
		# A sandy shoreline just above the waterline.
		return {"base": "sand" if detail > -0.2 else "sand_pebbles", "decor": ""}
	var land_biome := _blend_land_biome(biomes3x3, land_own, cell, noise_set, fx, fy)
	return _terrain_for_biome(land_biome, cell, elevation, forest, detail, danger)

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
## within-biome detail. The tileset has no snow/stone/marsh surface art, so
## climates render through the closest available keys: rock as pebble/sand,
## tundra as pale muted grass, marsh as dark grass pocked with calm water.
static func _terrain_for_biome(biome: String, cell: Vector2i, elevation: float, forest: float, detail: float, danger: float) -> Dictionary:
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
			# grass in the folds.
			var base := "sand_pebbles"
			if detail < -0.35:
				base = "grass_dark"
			elif detail < 0.05:
				base = "sand"
			var decor := ""
			if forest > 0.35 and detail > 0.55:
				decor = "tree_dark"
			return {"base": base, "decor": decor}
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
			# No white snow tile: keep the ground pale and muted, no blooms,
			# only the odd wind-bent conifer.
			var base := "grass_tuft" if detail > 0.0 else "grass"
			var decor := ""
			if forest > 0.32 and detail > 0.6:
				decor = "tree_dark"
			return {"base": base, "decor": decor}
		TILE_ATLAS_DEFS.BIOME_MARSH:
			# Dark waterlogged grass pocked with frequent calm-water pools.
			if detail > 0.25:
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

static func chunk_for_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(int(floor(float(cell.x) / CHUNK_SIZE)), int(floor(float(cell.y) / CHUNK_SIZE)))

static func chunk_rect(chunk: Vector2i) -> Rect2i:
	return Rect2i(chunk * CHUNK_SIZE, Vector2i(CHUNK_SIZE, CHUNK_SIZE))
