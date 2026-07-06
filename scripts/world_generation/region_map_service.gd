extends RefCounted
class_name RegionMapService

const TILE_ATLAS_DEFS := preload("res://scripts/world_generation/tile_atlas_defs.gd")

## The Dwarf Fortress zoom: the detailed view re-renders every overworld
## tile as its 64 walkable surface cells, from the SAME terrain function
## the town wilds stream from. The overworld biome recolors the palette
## (mountains crag, tundra whitens, deserts parch, marshes pool), the
## coastline is a smooth noise-wobbled field rather than a tile boundary,
## rivers run connected courses tile to tile, icebergs drift where the
## overworld placed them, and settlement danger shades the deep wilds.

const CELLS_PER_TILE := 64

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

## A render job is a self-contained data pack: assembled on the main
## thread, rendered on a WorkerThreadPool thread (everything it touches
## is job-local), collected back as an Image. water3x3/river3x3 hold the
## 3x3 neighborhood's water-ness and river-ness (row-major, own tile at
## index 4); danger_corners is the danger at the tile's four corners
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
	danger_corners: PackedFloat32Array
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
		"image": null
	}

## Thread-safe: builds its own noise set and reads only the job pack.
static func render_job(job: Dictionary) -> void:
	var noise_set: Dictionary = SurfaceWorldService.make_noise_set(hash("surface|%s" % String(job.get("seed", ""))))
	var tile := job.get("tile", Vector2i.ZERO) as Vector2i
	var biome := String(job.get("biome", ""))
	var has_iceberg := bool(job.get("has_iceberg", false))
	var water3x3 := job.get("water3x3") as PackedFloat32Array
	var danger_corners := job.get("danger_corners") as PackedFloat32Array
	var river_mask := PackedByteArray()
	if bool(job.get("has_river", false)):
		river_mask = _build_river_mask(tile, job.get("river3x3") as PackedFloat32Array, water3x3, noise_set)
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
			image.set_pixel(cx, cy, _field_cell_color(world_cell, noise_set, biome, on_river, has_iceberg, danger, water_amount))
	job["image"] = image

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
static func _build_river_mask(tile: Vector2i, river3x3: PackedFloat32Array, water3x3: PackedFloat32Array, noise_set: Dictionary) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(CELLS_PER_TILE * CELLS_PER_TILE)
	var center := Vector2(CELLS_PER_TILE * 0.5, CELLS_PER_TILE * 0.5)
	var noise := noise_set.get("detail") as FastNoiseLite
	var connections := 0
	var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for direction: Vector2i in directions:
		var index := 4 + direction.x + 3 * direction.y
		if river3x3[index] < 0.5 and water3x3[index] < 0.5:
			continue
		var edge_mid := center + Vector2(direction) * (CELLS_PER_TILE * 0.5)
		_stamp_river_segment(mask, center, edge_mid, tile, noise)
		connections += 1
	if connections == 0:
		# A lone river tile still shows its stream: north to south.
		_stamp_river_segment(mask, Vector2(center.x, 0.0), center, tile, noise)
		_stamp_river_segment(mask, center, Vector2(center.x, float(CELLS_PER_TILE)), tile, noise)
	return mask

static func _stamp_river_segment(mask: PackedByteArray, from_point: Vector2, to_point: Vector2, tile: Vector2i, noise: FastNoiseLite) -> void:
	var axis := (to_point - from_point).normalized()
	var perpendicular := Vector2(-axis.y, axis.x)
	var steps := 56
	for step in steps + 1:
		var t := float(step) / float(steps)
		var straight := from_point.lerp(to_point, t)
		var world := Vector2(tile * CELLS_PER_TILE) + straight
		var wobble := noise.get_noise_2d(world.x * 0.12, world.y * 0.12) * 11.0 * sin(PI * t)
		var pos := straight + perpendicular * wobble
		var px := int(round(pos.x))
		var py := int(round(pos.y))
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				var mx := px + ox
				var my := py + oy
				if mx >= 0 and my >= 0 and mx < CELLS_PER_TILE and my < CELLS_PER_TILE:
					mask[my * CELLS_PER_TILE + mx] = 1

## The coastline is a smooth noise-wobbled field, not a tile boundary:
## shores meander, beaches hug the waterline, ponds thin out to
## landmarks instead of wallpaper, and icebergs dot the marked seas.
static func _field_cell_color(world_cell: Vector2i, noise_set: Dictionary, biome: String, on_river: bool, has_iceberg: bool, danger: float, water_amount: float) -> Color:
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
		# The walkable wilds sprinkle ponds generously; at map scale keep
		# only the strongest clusters so lakes read as landmarks.
		var pond_keep := (noise_set.get("detail") as FastNoiseLite).get_noise_2d(float(world_cell.x) * 0.13, float(world_cell.y) * 0.13)
		if pond_keep < 0.3:
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
				color = COLOR_STONE_DARK if not decor_key.is_empty() or detail > 0.45 else COLOR_STONE
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
