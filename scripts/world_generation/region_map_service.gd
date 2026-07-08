extends RefCounted
class_name RegionMapService

const TILE_ATLAS_DEFS := preload("res://scripts/world_generation/tile_atlas_defs.gd")

## The Dwarf Fortress zoom: the detailed view subdivides every overworld
## tile into SUB_TILES x SUB_TILES cells drawn with the SAME worldmap
## tileset art (grass, trees, mountains, water), the way DF's region
## view keeps the world map's glyphs. Terrain decisions come from the
## same fields as ever: biomes blend across borders, the coastline is a
## noise-wobbled field, rivers and roads run connected courses tile to
## tile, icebergs drift where the overworld placed them, and settlement
## danger shades the deep wilds. Jobs without a tileset image fall back
## to the old painted per-pixel look.

const CELLS_PER_TILE := 64
const SUB_TILES := 8

const COLOR_GRASS := Color(0.45, 0.62, 0.28)
const COLOR_GRASS_DARK := Color(0.34, 0.51, 0.24)
const COLOR_GRASS_TUFT := Color(0.4, 0.58, 0.26)
const COLOR_TREE := Color(0.18, 0.38, 0.16)
const COLOR_TREE_DARK := Color(0.12, 0.3, 0.14)
const COLOR_HEDGE := Color(0.25, 0.45, 0.2)
const COLOR_FLOWERS := Color(0.78, 0.78, 0.45)
const COLOR_SAND := Color(0.78, 0.7, 0.45)
const COLOR_SAND_DARK := Color(0.7, 0.6, 0.38)
const COLOR_WATER := Color(0.28, 0.45, 0.65)
const COLOR_WATER_DEEP := Color(0.22, 0.38, 0.58)
const COLOR_STONE := Color(0.52, 0.5, 0.47)
const COLOR_STONE_DARK := Color(0.4, 0.38, 0.36)
const COLOR_SNOW := Color(0.88, 0.9, 0.92)
const COLOR_MARSH := Color(0.32, 0.44, 0.3)
const COLOR_BADLANDS := Color(0.62, 0.44, 0.3)
const COLOR_ICE := Color(0.88, 0.92, 0.96)
const COLOR_ICE_EDGE := Color(0.74, 0.82, 0.9)
const COLOR_ROAD := Color(0.58, 0.47, 0.32)
const COLOR_ROAD_WORN := Color(0.5, 0.4, 0.27)

## A render job is a self-contained data pack: assembled on the main
## thread, rendered on a WorkerThreadPool thread (everything it touches
## is job-local), collected back as an Image. water3x3/river3x3/road3x3
## hold the 3x3 neighborhood's water-ness, river-ness and road-ness
## (row-major, own tile at index 4); biomes3x3 the neighborhood's biome
## labels; danger_corners is the danger at the tile's four corners
## (TL, TR, BL, BR), interpolated per cell instead of scanning every
## settlement anchor 4096 times.
static func make_render_job(
	world_seed_text: String,
	tile: Vector2i,
	biome: String,
	has_river: bool,
	has_iceberg: bool,
	water3x3: PackedFloat32Array,
	river3x3: PackedFloat32Array,
	danger_corners: PackedFloat32Array,
	ruggedness: float = 0.45,
	biomes3x3: PackedStringArray = PackedStringArray(),
	road3x3: PackedFloat32Array = PackedFloat32Array(),
	tileset: Image = null,
	atlas_px: int = 32,
	iceberg_tile: Vector2i = Vector2i(-1, -1),
	canopy3x3: PackedFloat32Array = PackedFloat32Array()
) -> Dictionary:
	return {
		"seed": world_seed_text,
		"tile": tile,
		"biome": biome,
		"has_river": has_river,
		"has_iceberg": has_iceberg,
		"water3x3": water3x3,
		"river3x3": river3x3,
		"danger_corners": danger_corners,
		"ruggedness": ruggedness,
		"biomes3x3": biomes3x3,
		"road3x3": road3x3,
		"tileset": tileset,
		"atlas_px": atlas_px,
		"iceberg_tile": iceberg_tile,
		"canopy3x3": canopy3x3,
		"image": null
	}

## Thread-safe: builds its own noise set and reads only the job pack
## (the tileset image is shared, but strictly read-only).
static func render_job(job: Dictionary) -> void:
	if job.get("tileset") is Image:
		_render_job_as_tiles(job)
		return
	var noise_set: Dictionary = SurfaceWorldService.make_noise_set(hash("surface|%s" % String(job.get("seed", ""))))
	var tile := job.get("tile", Vector2i.ZERO) as Vector2i
	var biome := String(job.get("biome", ""))
	var has_iceberg := bool(job.get("has_iceberg", false))
	var water3x3 := job.get("water3x3") as PackedFloat32Array
	var danger_corners := job.get("danger_corners") as PackedFloat32Array
	var ruggedness := clampf(float(job.get("ruggedness", 0.45)), 0.0, 1.0)
	var river_mask := PackedByteArray()
	if bool(job.get("has_river", false)):
		river_mask = _build_river_mask(tile, job.get("river3x3") as PackedFloat32Array, water3x3, noise_set)
	var road3x3 := job.get("road3x3") as PackedFloat32Array
	var road_mask := PackedByteArray()
	if road3x3 != null and road3x3.size() == 9 and road3x3[4] >= 0.5:
		road_mask = _build_road_mask(tile, road3x3, noise_set)
	var biome_fields := _build_biome_fields(job.get("biomes3x3") as PackedStringArray, biome)
	var image := Image.create(CELLS_PER_TILE, CELLS_PER_TILE, false, Image.FORMAT_RGB8)
	var tile_origin := tile * CELLS_PER_TILE
	for cy in CELLS_PER_TILE:
		var fy := (float(cy) + 0.5) / float(CELLS_PER_TILE)
		for cx in CELLS_PER_TILE:
			var fx := (float(cx) + 0.5) / float(CELLS_PER_TILE)
			var world_cell := tile_origin + Vector2i(cx, cy)
			var danger := lerpf(
				lerpf(danger_corners[0], danger_corners[1], fx),
				lerpf(danger_corners[2], danger_corners[3], fx),
				fy
			)
			var water_amount := _field_from_neighbors(water3x3, fx, fy)
			var on_river := not river_mask.is_empty() and river_mask[cy * CELLS_PER_TILE + cx] != 0
			var on_road := not road_mask.is_empty() and road_mask[cy * CELLS_PER_TILE + cx] != 0
			var cell_biome := _blended_biome(biome_fields, biome, world_cell, noise_set, fx, fy)
			image.set_pixel(cx, cy, _field_cell_color(world_cell, noise_set, cell_biome, on_river, has_iceberg, danger, water_amount, ruggedness, on_road))
	job["image"] = image

## Per-candidate presence fields for the 3x3 neighborhood's land biomes,
## so palettes can blend across tile borders the way water already does.
## Water neighbors vote for the tile's own biome: the coast field owns
## that transition. Returns [] when the whole neighborhood matches.
## Desert and badlands share a sandy palette; blending them produces stray
## sand tiles inside badlands. This flags that specific pair so the field
## builder can keep them apart while still blending arid land into grass etc.
static func _is_arid_conflict(a: String, b: String) -> bool:
	if a == b:
		return false
	var arid := {TILE_ATLAS_DEFS.BIOME_DESERT: true, TILE_ATLAS_DEFS.BIOME_BADLANDS: true}
	return arid.has(a) and arid.has(b)

static func _build_biome_fields(biomes3x3: PackedStringArray, own_biome: String) -> Array:
	if biomes3x3 == null or biomes3x3.size() != 9:
		return []
	var resolved := PackedStringArray()
	var uniform := true
	for index in 9:
		var label := biomes3x3[index]
		if label.is_empty() or label == TILE_ATLAS_DEFS.BIOME_WATER:
			label = own_biome
		# Desert and badlands are both arid tans; letting one bleed into the
		# other's tiles paints stray sand cells inside a badlands (and vice
		# versa). Treat the pair as non-blending so each renders solid.
		elif _is_arid_conflict(own_biome, label):
			label = own_biome
		resolved.append(label)
		if label != own_biome:
			uniform = false
	if uniform:
		return []
	var fields: Array = []
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
		# Decorrelated wobble offsets per candidate keep the argmax from
		# collapsing back into straight tile edges.
		var wobble_seed := float(hash(candidate) % 1024)
		fields.append({"biome": candidate, "presence": presence, "wobble": wobble_seed})
	return fields

## The biome painting this cell: each neighborhood biome bids its
## bilinear presence plus its own noise wobble, and the high bid wins -
## the same trick the coastline uses, generalized to many claimants, so
## mountains meet deserts along meandering fronts instead of tile edges.
static func _blended_biome(biome_fields: Array, own_biome: String, world_cell: Vector2i, noise_set: Dictionary, fx: float, fy: float) -> String:
	if biome_fields.is_empty():
		return own_biome
	var noise := noise_set.get("detail") as FastNoiseLite
	var best_biome := own_biome
	var best_score := -1.0
	for field_variant: Variant in biome_fields:
		var field := field_variant as Dictionary
		var presence := field.get("presence") as PackedFloat32Array
		var wobble_seed := float(field.get("wobble", 0.0))
		var wobble := noise.get_noise_2d(float(world_cell.x) * 0.11 + wobble_seed * 91.0, float(world_cell.y) * 0.11 - wobble_seed * 57.0)
		var score := _field_from_neighbors(presence, fx, fy) + wobble * 0.22
		if score > best_score:
			best_score = score
			best_biome = String(field.get("biome", own_biome))
	return best_biome

## DF-style detail render: the tile becomes SUB_TILES x SUB_TILES cells
## of real worldmap art - a ground tile blitted per cell, feature art
## (trees, mountains, hills, icebergs, roads) alpha-blended on top, and
## the wilds-danger shade layered over the lot.
static func _render_job_as_tiles(job: Dictionary) -> void:
	var noise_set: Dictionary = SurfaceWorldService.make_noise_set(hash("surface|%s" % String(job.get("seed", ""))))
	var tileset := job.get("tileset") as Image
	var atlas_px := maxi(1, int(job.get("atlas_px", 32)))
	var tile := job.get("tile", Vector2i.ZERO) as Vector2i
	var biome := String(job.get("biome", ""))
	var has_iceberg := bool(job.get("has_iceberg", false))
	var iceberg_tile := job.get("iceberg_tile", Vector2i(-1, -1)) as Vector2i
	var water3x3 := job.get("water3x3") as PackedFloat32Array
	var danger_corners := job.get("danger_corners") as PackedFloat32Array
	var ruggedness := clampf(float(job.get("ruggedness", 0.45)), 0.0, 1.0)
	var river_mask := PackedByteArray()
	if bool(job.get("has_river", false)):
		river_mask = _build_river_mask(tile, job.get("river3x3") as PackedFloat32Array, water3x3, noise_set, SUB_TILES)
	var road3x3 := job.get("road3x3") as PackedFloat32Array
	var road_mask := PackedByteArray()
	var has_roads := road3x3 != null and road3x3.size() == 9 and road3x3[4] >= 0.5
	if has_roads:
		road_mask = _build_road_mask(tile, road3x3, noise_set, SUB_TILES)
	var biome_fields := _build_biome_fields(job.get("biomes3x3") as PackedStringArray, biome)
	var canopy3x3 := job.get("canopy3x3") as PackedFloat32Array
	var has_canopy := canopy3x3 != null and canopy3x3.size() == 9
	var noise := noise_set.get("detail") as FastNoiseLite
	var cells_per_sub := CELLS_PER_TILE / SUB_TILES
	var image := Image.create(SUB_TILES * atlas_px, SUB_TILES * atlas_px, false, Image.FORMAT_RGBA8)
	var art_rect := func(art: Vector2i) -> Rect2i:
		return Rect2i(art * atlas_px, Vector2i(atlas_px, atlas_px))
	var shade_cache: Dictionary = {}
	for sy in SUB_TILES:
		var fy := (float(sy) + 0.5) / float(SUB_TILES)
		for sx in SUB_TILES:
			var fx := (float(sx) + 0.5) / float(SUB_TILES)
			var world_cell := tile * CELLS_PER_TILE + Vector2i(sx * cells_per_sub + cells_per_sub / 2, sy * cells_per_sub + cells_per_sub / 2)
			var danger := lerpf(
				lerpf(danger_corners[0], danger_corners[1], fx),
				lerpf(danger_corners[2], danger_corners[3], fx),
				fy
			)
			var detail := noise.get_noise_2d(float(world_cell.x), float(world_cell.y))
			var coast := _field_from_neighbors(water3x3, fx, fy) + detail * 0.16
			var on_river := not river_mask.is_empty() and river_mask[sy * SUB_TILES + sx] != 0
			var on_road := not road_mask.is_empty() and road_mask[sy * SUB_TILES + sx] != 0
			var cell_biome := _blended_biome(biome_fields, biome, world_cell, noise_set, fx, fy)
			var canopy := _field_from_neighbors(canopy3x3, fx, fy) if has_canopy else 0.0
			var pick := _pick_cell_art(world_cell, noise_set, cell_biome, coast, detail, on_river, has_iceberg, iceberg_tile, danger, ruggedness, canopy)
			var base_art := pick.get("base", TILE_ATLAS_DEFS.GRASS_TILE) as Vector2i
			var overlay_art := pick.get("overlay", Vector2i(-1, -1)) as Vector2i
			if on_road and not bool(pick.get("is_water", false)):
				overlay_art = _road_art_for_cell(road_mask, road3x3, sx, sy, world_cell)
			var dest := Vector2i(sx * atlas_px, sy * atlas_px)
			image.blit_rect(tileset, art_rect.call(base_art) as Rect2i, dest)
			if overlay_art.x >= 0:
				image.blend_rect(tileset, art_rect.call(overlay_art) as Rect2i, dest)
			# Deep wilds read darker, same radial rule the walker feels.
			var shade_level := int(round(clampf(danger, 0.0, 1.0) * 6.0))
			if shade_level > 0:
				if not shade_cache.has(shade_level):
					var shade := Image.create(atlas_px, atlas_px, false, Image.FORMAT_RGBA8)
					shade.fill(Color(0.0, 0.0, 0.0, float(shade_level) / 6.0 * 0.28))
					shade_cache[shade_level] = shade
				image.blend_rect(shade_cache[shade_level] as Image, Rect2i(0, 0, atlas_px, atlas_px), dest)
	job["image"] = image

## Ground art plus optional feature art for one detail cell, decided by
## the same fields the painted renderer used.
static func _pick_cell_art(world_cell: Vector2i, noise_set: Dictionary, cell_biome: String, coast: float, detail: float, on_river: bool, has_iceberg: bool, iceberg_tile: Vector2i, danger: float, ruggedness: float, canopy: float = 0.0) -> Dictionary:
	if coast > 0.5:
		var result := {"base": TILE_ATLAS_DEFS.WATER_TILE, "is_water": true}
		if has_iceberg and iceberg_tile.x >= 0:
			var berg := (noise_set.get("detail") as FastNoiseLite).get_noise_2d(float(world_cell.x) * 2.6, float(world_cell.y) * 2.6)
			if berg > 0.4:
				result["overlay"] = iceberg_tile
		return result
	if on_river:
		return {"base": TILE_ATLAS_DEFS.WATER_TILE, "is_water": true}
	var terrain: Dictionary = SurfaceWorldService.terrain_for_cell(world_cell, noise_set, danger)
	var base_key := String(terrain.get("base", "grass"))
	var decor_key := String(terrain.get("decor", ""))
	if base_key.begins_with("water"):
		# The ground terrain is sampled without biome context, so its basins
		# hold water everywhere - including deserts, which then speckle with
		# lakes. Arid country (desert/badlands) has no standing water here;
		# its rare oases are placed as their own landmark instead.
		var arid := cell_biome == TILE_ATLAS_DEFS.BIOME_DESERT or cell_biome == TILE_ATLAS_DEFS.BIOME_BADLANDS
		if not arid:
			# Ponds thin to landmarks at map scale, exactly as before.
			var pond_keep := (noise_set.get("detail") as FastNoiseLite).get_noise_2d(float(world_cell.x) * 0.13, float(world_cell.y) * 0.13)
			if pond_keep >= 0.3:
				return {"base": TILE_ATLAS_DEFS.WATER_TILE, "is_water": true}
		decor_key = ""
	# A sandy shoreline just above the waterline.
	if coast > 0.4:
		return {"base": TILE_ATLAS_DEFS.SAND_TILE}
	var has_tree_decor := decor_key.begins_with("tree")
	match cell_biome:
		TILE_ATLAS_DEFS.BIOME_MOUNTAIN:
			# A range reads as mountains: most cells carry the mountain
			# glyph, peaks crown the heights, and only the low draws open
			# into bare-rock benches or the odd green valley floor.
			# Ruggedness raises the peaks and narrows the valleys.
			var peak_threshold := lerpf(0.62, 0.45, ruggedness)
			var valley_threshold := lerpf(-0.35, -0.55, ruggedness)
			if detail > peak_threshold:
				return {"base": TILE_ATLAS_DEFS.STONE_TILE, "overlay": TILE_ATLAS_DEFS.MOUNTAIN_PEAK_TILE}
			if detail < valley_threshold - 0.3:
				# A sheltered green valley floor deep in the low ground.
				if has_tree_decor:
					return {"base": TILE_ATLAS_DEFS.GRASS_TILE, "overlay": TILE_ATLAS_DEFS.TREE_TILE}
				return {"base": TILE_ATLAS_DEFS.GRASS_TILE}
			if detail < valley_threshold:
				# A bare rock bench between the ridges.
				return {"base": TILE_ATLAS_DEFS.STONE_TILE}
			return {"base": TILE_ATLAS_DEFS.STONE_TILE, "overlay": TILE_ATLAS_DEFS.MOUNTAIN_TILE}
		TILE_ATLAS_DEFS.BIOME_HILLS:
			if detail > 0.2 or has_tree_decor:
				return {"base": TILE_ATLAS_DEFS.GRASS_TILE, "overlay": TILE_ATLAS_DEFS.HILLS_TILE}
			return {"base": TILE_ATLAS_DEFS.GRASS_TILE}
		TILE_ATLAS_DEFS.BIOME_TUNDRA:
			if has_tree_decor:
				return {"base": TILE_ATLAS_DEFS.SNOW_TILE, "overlay": TILE_ATLAS_DEFS.TREE_SNOW_TILE}
			return {"base": TILE_ATLAS_DEFS.SNOW_TILE}
		TILE_ATLAS_DEFS.BIOME_DESERT:
			if not decor_key.is_empty() and detail > 0.35:
				return {"base": TILE_ATLAS_DEFS.SAND_TILE, "overlay": TILE_ATLAS_DEFS.DESERT_CACTI_TILE}
			return {"base": TILE_ATLAS_DEFS.SAND_TILE}
		TILE_ATLAS_DEFS.BIOME_BADLANDS:
			return {"base": TILE_ATLAS_DEFS.BADLANDS_TILE}
		TILE_ATLAS_DEFS.BIOME_MARSH:
			if detail > 0.5:
				return {"base": TILE_ATLAS_DEFS.WATER_TILE, "is_water": true}
			return {"base": TILE_ATLAS_DEFS.MARSH_TILE}
		TILE_ATLAS_DEFS.BIOME_FOREST:
			# Canopy depth (distance into the forest, 0 at the edge, 1 in the
			# core) lowers the tree threshold, so a wood thins to scattered
			# stands at its fringe and closes to near-solid trees deep inside.
			# Small forests never reach a deep core, so they stay sparse.
			var forest_threshold := lerpf(0.55, -0.7, clampf(canopy, 0.0, 1.0))
			if detail > forest_threshold:
				return {"base": TILE_ATLAS_DEFS.GRASS_TILE, "overlay": TILE_ATLAS_DEFS.TREE_TILE}
			return {"base": TILE_ATLAS_DEFS.GRASS_TILE}
		TILE_ATLAS_DEFS.BIOME_JUNGLE:
			# Jungle is dense even at the margins and turns near-solid at heart.
			var jungle_threshold := lerpf(0.15, -0.8, clampf(canopy, 0.0, 1.0))
			if has_tree_decor or detail > jungle_threshold:
				return {"base": TILE_ATLAS_DEFS.GRASS_TILE, "overlay": TILE_ATLAS_DEFS.JUNGLE_TREE_TILE}
			return {"base": TILE_ATLAS_DEFS.GRASS_TILE}
	if has_tree_decor:
		return {"base": TILE_ATLAS_DEFS.GRASS_TILE, "overlay": TILE_ATLAS_DEFS.TREE_LONE_TILE}
	return {"base": TILE_ATLAS_DEFS.GRASS_TILE}

## The road art matching this cell's course: N/E/S/W bits from the mask
## (border cells also look across the tile edge) pick straight, corner,
## junction or stub art - the same buckets the world map lays.
static func _road_art_for_cell(road_mask: PackedByteArray, road3x3: PackedFloat32Array, sx: int, sy: int, world_cell: Vector2i) -> Vector2i:
	var bits := 0
	if (sy > 0 and road_mask[(sy - 1) * SUB_TILES + sx] != 0) or (sy == 0 and road3x3[1] >= 0.5):
		bits |= 1
	if (sx < SUB_TILES - 1 and road_mask[sy * SUB_TILES + sx + 1] != 0) or (sx == SUB_TILES - 1 and road3x3[5] >= 0.5):
		bits |= 2
	if (sy < SUB_TILES - 1 and road_mask[(sy + 1) * SUB_TILES + sx] != 0) or (sy == SUB_TILES - 1 and road3x3[7] >= 0.5):
		bits |= 4
	if (sx > 0 and road_mask[sy * SUB_TILES + sx - 1] != 0) or (sx == 0 and road3x3[3] >= 0.5):
		bits |= 8
	var bucket := "stub"
	match bits:
		5:
			bucket = "ns"
		10:
			bucket = "we"
		6:
			bucket = "corner_se"
		12:
			bucket = "corner_sw"
		3:
			bucket = "corner_ne"
		9:
			bucket = "corner_nw"
		1, 4:
			bucket = "ns"
		2, 8:
			bucket = "we"
		_:
			if bits != 0:
				bucket = "junction"
	var variants := TILE_ATLAS_DEFS.ROAD_TILES.get(bucket, TILE_ATLAS_DEFS.ROAD_TILES["stub"]) as Array
	var pick := absi(world_cell.x * 73856093 ^ world_cell.y * 19349663) % variants.size()
	return variants[pick] as Vector2i

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

## Rivers run tile center to edge midpoints, one meandering segment per
## river (or sea) neighbor. Wobble fades to zero at both endpoints so
## every tile's course meets its neighbors' exactly at the shared edge.
## grid picks the mask resolution (64 painted cells or 8 art sub-tiles).
static func _build_river_mask(tile: Vector2i, river3x3: PackedFloat32Array, water3x3: PackedFloat32Array, noise_set: Dictionary, grid: int = CELLS_PER_TILE) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(grid * grid)
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
		# A lone river tile still shows its stream: north to south.
		_stamp_river_segment(mask, Vector2(center.x, 0.0), center, tile, noise, grid)
		_stamp_river_segment(mask, center, Vector2(center.x, float(grid)), tile, noise, grid)
	return mask

static func _stamp_river_segment(mask: PackedByteArray, from_point: Vector2, to_point: Vector2, tile: Vector2i, noise: FastNoiseLite, grid: int = CELLS_PER_TILE) -> void:
	var axis := (to_point - from_point).normalized()
	var perpendicular := Vector2(-axis.y, axis.x)
	var grid_scale := float(grid) / float(CELLS_PER_TILE)
	var brush := 1 if grid >= CELLS_PER_TILE else 0
	var steps := 56 if grid >= CELLS_PER_TILE else 16
	for step in steps + 1:
		var t := float(step) / float(steps)
		var straight := from_point.lerp(to_point, t)
		# Wobble is sampled in world-cell units so both resolutions carve
		# the same course, then scaled into this mask's grid - with a
		# floor so coarse art grids still meander instead of ruling
		# straight center-to-edge lines.
		var world := (Vector2(tile) + straight / float(grid)) * float(CELLS_PER_TILE)
		var wobble := noise.get_noise_2d(world.x * 0.12, world.y * 0.12) * maxf(11.0 * grid_scale, 2.6) * sin(PI * t)
		var pos := straight + perpendicular * wobble
		var px := int(round(pos.x))
		var py := int(round(pos.y))
		for oy in range(-brush, brush + 1):
			for ox in range(-brush, brush + 1):
				var mx := px + ox
				var my := py + oy
				if mx >= 0 and my >= 0 and mx < grid and my < grid:
					mask[my * grid + mx] = 1

## Roads run tile center to edge midpoints toward road neighbors, a
## touch straighter and narrower than rivers. A connectionless road tile
## (a settlement approach) shows as a trodden yard at the center.
static func _build_road_mask(tile: Vector2i, road3x3: PackedFloat32Array, noise_set: Dictionary, grid: int = CELLS_PER_TILE) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(grid * grid)
	var center := Vector2(grid * 0.5, grid * 0.5)
	var noise := noise_set.get("detail") as FastNoiseLite
	var connections := 0
	var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for direction: Vector2i in directions:
		if road3x3[4 + direction.x + 3 * direction.y] < 0.5:
			continue
		var edge_mid := center + Vector2(direction) * (grid * 0.5)
		_stamp_road_segment(mask, center, edge_mid, tile, noise, grid)
		connections += 1
	if connections == 0:
		var yard := maxi(1, grid / 32)
		for oy in range(-yard, yard + 1):
			for ox in range(-yard, yard + 1):
				var mx := int(center.x) + ox
				var my := int(center.y) + oy
				if mx >= 0 and my >= 0 and mx < grid and my < grid:
					mask[my * grid + mx] = 1
	return mask

static func _stamp_road_segment(mask: PackedByteArray, from_point: Vector2, to_point: Vector2, tile: Vector2i, noise: FastNoiseLite, grid: int = CELLS_PER_TILE) -> void:
	var axis := (to_point - from_point).normalized()
	var perpendicular := Vector2(-axis.y, axis.x)
	var grid_scale := float(grid) / float(CELLS_PER_TILE)
	var reach := 1 if grid >= CELLS_PER_TILE else 0
	var steps := 56 if grid >= CELLS_PER_TILE else 16
	for step in steps + 1:
		var t := float(step) / float(steps)
		var straight := from_point.lerp(to_point, t)
		var world := (Vector2(tile) + straight / float(grid)) * float(CELLS_PER_TILE)
		# Carts keep straighter lines than water; the wobble still fades
		# to zero at the endpoints so tracks meet at shared tile edges.
		var wobble := noise.get_noise_2d(world.x * 0.1 + 500.0, world.y * 0.1 - 500.0) * 5.0 * grid_scale * sin(PI * t)
		var pos := straight + perpendicular * wobble
		var px := int(round(pos.x))
		var py := int(round(pos.y))
		for oy in range(0, reach + 1):
			for ox in range(0, reach + 1):
				var mx := px + ox
				var my := py + oy
				if mx >= 0 and my >= 0 and mx < grid and my < grid:
					mask[my * grid + mx] = 1

## The coastline is a smooth noise-wobbled field, not a tile boundary:
## shores meander, beaches hug the waterline, ponds thin out to
## landmarks instead of wallpaper, and icebergs dot the marked seas.
static func _field_cell_color(world_cell: Vector2i, noise_set: Dictionary, biome: String, on_river: bool, has_iceberg: bool, danger: float, water_amount: float, ruggedness: float = 0.45, on_road: bool = false) -> Color:
	var detail := (noise_set.get("detail") as FastNoiseLite).get_noise_2d(float(world_cell.x), float(world_cell.y))
	var coast := water_amount + detail * 0.16
	if coast > 0.5:
		if has_iceberg:
			var berg := (noise_set.get("detail") as FastNoiseLite).get_noise_2d(float(world_cell.x) * 2.6, float(world_cell.y) * 2.6)
			if berg > 0.4:
				return COLOR_ICE if berg > 0.52 else COLOR_ICE_EDGE
		return COLOR_WATER if detail > -0.15 else COLOR_WATER_DEEP
	if on_river:
		return COLOR_WATER if detail > -0.3 else COLOR_WATER_DEEP
	var terrain: Dictionary = SurfaceWorldService.terrain_for_cell(world_cell, noise_set, danger)
	var base_key := String(terrain.get("base", "grass"))
	var decor_key := String(terrain.get("decor", ""))
	if base_key.begins_with("water"):
		# Arid country has no standing water; dry the basin ponds to sand so
		# deserts and badlands don't speckle with lakes.
		var arid := biome == TILE_ATLAS_DEFS.BIOME_DESERT or biome == TILE_ATLAS_DEFS.BIOME_BADLANDS
		# The walkable wilds sprinkle ponds generously; at map scale keep
		# only the strongest clusters so lakes read as landmarks.
		var pond_keep := (noise_set.get("detail") as FastNoiseLite).get_noise_2d(float(world_cell.x) * 0.13, float(world_cell.y) * 0.13)
		if arid:
			base_key = "sand"
			decor_key = ""
		elif pond_keep < 0.3:
			base_key = "grass_dark" if pond_keep < -0.1 else "grass_tuft"
			decor_key = ""
	# A sandy shoreline just above the waterline.
	if coast > 0.4 and not base_key.begins_with("water"):
		base_key = "sand" if detail > -0.2 else "sand_pebbles"
		decor_key = ""
	var color := COLOR_GRASS
	match base_key:
		"grass_dark":
			color = COLOR_GRASS_DARK
		"grass_tuft":
			color = COLOR_GRASS_TUFT
		"flowers_white", "flowers_yellow":
			color = COLOR_FLOWERS
		"sand", "sand_alt":
			color = COLOR_SAND
		"sand_pebbles":
			color = COLOR_SAND_DARK
		"water":
			color = COLOR_WATER
		"water_calm":
			color = COLOR_WATER_DEEP
	if not decor_key.is_empty() and not base_key.begins_with("water"):
		match decor_key:
			"tree":
				color = COLOR_TREE
			"tree_dark":
				color = COLOR_TREE_DARK
			"hedge", "hedge_alt":
				color = COLOR_HEDGE
			"flowers_white", "flowers_yellow":
				color = COLOR_FLOWERS
	# The overworld climate repaints the same ground.
	var is_water_ground := base_key.begins_with("water")
	if not is_water_ground:
		match biome:
			TILE_ATLAS_DEFS.BIOME_MOUNTAIN:
				# Rugged ranges render rockier up close: the crag threshold
				# eases from 0.6 (gentle) down to 0.25 (savage ridge).
				var crag_threshold := lerpf(0.6, 0.25, ruggedness)
				color = COLOR_STONE_DARK if not decor_key.is_empty() or detail > crag_threshold else COLOR_STONE
			TILE_ATLAS_DEFS.BIOME_HILLS:
				color = color.lerp(COLOR_STONE, 0.35)
			TILE_ATLAS_DEFS.BIOME_TUNDRA:
				color = color.lerp(COLOR_SNOW, 0.4 if not decor_key.is_empty() else 0.72)
			TILE_ATLAS_DEFS.BIOME_DESERT:
				color = color.lerp(COLOR_SAND, 0.3 if not decor_key.is_empty() else 0.85)
			TILE_ATLAS_DEFS.BIOME_BADLANDS:
				color = color.lerp(COLOR_BADLANDS, 0.3 if not decor_key.is_empty() else 0.75)
			TILE_ATLAS_DEFS.BIOME_MARSH:
				color = color.lerp(COLOR_MARSH, 0.5)
				if detail > 0.5:
					color = COLOR_WATER_DEEP
			TILE_ATLAS_DEFS.BIOME_FOREST:
				if decor_key.is_empty() and detail > 0.15:
					color = COLOR_TREE
			TILE_ATLAS_DEFS.BIOME_JUNGLE:
				if decor_key.is_empty() and detail > 0.0:
					color = COLOR_TREE
				color = Color(color.r * 0.85, minf(color.g * 1.1, 1.0), color.b * 0.85)
	# A dirt track pressed into whatever ground it crosses (rivers stay
	# on top: the road fords them).
	if on_road and not is_water_ground:
		color = color.lerp(COLOR_ROAD_WORN if detail > 0.25 else COLOR_ROAD, 0.8)
	# Deep wilds read darker, same radial rule the walker feels.
	var shade := 1.0 - danger * 0.28
	return Color(color.r * shade, color.g * shade, color.b * shade)

## One overworld tile as a 64x64-cell detail texture. Kept for tests and
## tools; the streaming view goes through make_render_job/render_job.
static func render_tile(
	noise_set: Dictionary,
	tile: Vector2i,
	biome: String,
	has_river: bool,
	site_anchors: Array[Vector2i],
	cell_px: int = 1
) -> ImageTexture:
	var image := Image.create(CELLS_PER_TILE * cell_px, CELLS_PER_TILE * cell_px, false, Image.FORMAT_RGB8)
	var tile_origin := tile * CELLS_PER_TILE
	for cy in CELLS_PER_TILE:
		for cx in CELLS_PER_TILE:
			var world_cell := tile_origin + Vector2i(cx, cy)
			var danger := danger_for_world_cell(world_cell, site_anchors)
			var color := _cell_color(world_cell, noise_set, biome, has_river, danger)
			for oy in cell_px:
				for ox in cell_px:
					image.set_pixel(cx * cell_px + ox, cy * cell_px + oy, color)
	return ImageTexture.create_from_image(image)

static func danger_for_world_cell(world_cell: Vector2i, site_anchors: Array[Vector2i]) -> float:
	var nearest := 999999.0
	for anchor: Vector2i in site_anchors:
		nearest = minf(nearest, Vector2(world_cell - anchor).length())
	return clampf((nearest - SurfaceLifeService.CALM_RADIUS_CELLS) / (SurfaceLifeService.DARK_RADIUS_CELLS - SurfaceLifeService.CALM_RADIUS_CELLS), 0.0, 1.0)

static func _cell_color(world_cell: Vector2i, noise_set: Dictionary, biome: String, has_river: bool, danger: float) -> Color:
	var detail := (noise_set.get("detail") as FastNoiseLite).get_noise_2d(float(world_cell.x), float(world_cell.y))
	# Whole-water tiles: two blues rippled by the detail noise.
	if biome == TILE_ATLAS_DEFS.BIOME_WATER:
		return COLOR_WATER if detail > -0.15 else COLOR_WATER_DEEP
	# A river winds through its tile: a narrow band meandering with the
	# terrain noise, always drawn over the land.
	if has_river:
		var tile_center_x := int(floor(float(world_cell.x) / CELLS_PER_TILE)) * CELLS_PER_TILE + CELLS_PER_TILE / 2
		var meander := sin(float(world_cell.y) * 0.11 + float(tile_center_x) * 0.37) * 9.0
		if absf(float(world_cell.x - tile_center_x) - meander) < 2.0:
			return COLOR_WATER
	var water3x3 := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0, 0])
	return _field_cell_color(world_cell, noise_set, biome, false, false, danger, _field_from_neighbors(water3x3, 0.5, 0.5))

## The DF-style "Surroundings" word for a tile's danger.
static func surroundings_label(danger: float) -> String:
	if danger < 0.15:
		return "Serene"
	if danger < 0.4:
		return "Calm"
	if danger < 0.65:
		return "Wilderness"
	if danger < 0.85:
		return "Untamed Wilds"
	return "Savage"
