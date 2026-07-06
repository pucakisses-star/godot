extends RefCounted
class_name RegionMapService

const TILE_ATLAS_DEFS := preload("res://scripts/world_generation/tile_atlas_defs.gd")

## The Dwarf Fortress zoom: double-clicking the world map opens a
## region view where every overworld tile expands into its 64 walkable
## surface cells, rendered from the SAME terrain function the town
## wilds stream from - so the region map shows the actual ground a
## walker would cross. The overworld biome recolors the palette
## (mountains crag, tundra whitens, deserts parch, marshes pool),
## rivers wind through their tiles, and settlement danger rings shade
## the deep wilds darker.

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

## Renders the region: tiles_span x tiles_span overworld tiles from
## top_left_tile, each 64x64 world cells, cell_px pixels per cell.
## biome_for_tile(tile) -> String, river_for_tile(tile) -> bool,
## site_anchors are settlement centers in WORLD CELL coordinates.
static func render_region(
	world_seed_text: String,
	top_left_tile: Vector2i,
	tiles_span: int,
	biome_for_tile: Callable,
	river_for_tile: Callable,
	site_anchors: Array[Vector2i],
	cell_px: int = 2
) -> ImageTexture:
	var noise_set: Dictionary = SurfaceWorldService.make_noise_set(hash("surface|%s" % world_seed_text))
	var size_cells := tiles_span * CELLS_PER_TILE
	var image := Image.create(size_cells * cell_px, size_cells * cell_px, false, Image.FORMAT_RGB8)
	for tile_dy in tiles_span:
		for tile_dx in tiles_span:
			var tile := top_left_tile + Vector2i(tile_dx, tile_dy)
			var biome := String(biome_for_tile.call(tile))
			var has_river := bool(river_for_tile.call(tile))
			var tile_origin := tile * CELLS_PER_TILE
			for cy in CELLS_PER_TILE:
				for cx in CELLS_PER_TILE:
					var world_cell := tile_origin + Vector2i(cx, cy)
					var danger := danger_for_world_cell(world_cell, site_anchors)
					var color := _cell_color(world_cell, noise_set, biome, has_river, danger)
					var px := (tile_dx * CELLS_PER_TILE + cx) * cell_px
					var py := (tile_dy * CELLS_PER_TILE + cy) * cell_px
					for oy in cell_px:
						for ox in cell_px:
							image.set_pixel(px + ox, py + oy, color)
	return ImageTexture.create_from_image(image)

## One overworld tile as a 64x64-cell detail texture (cell_px pixels
## per cell), for the streaming full-map region view.
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
	var terrain: Dictionary = SurfaceWorldService.terrain_for_cell(world_cell, noise_set, danger)
	var base_key := String(terrain.get("base", "grass"))
	var decor_key := String(terrain.get("decor", ""))
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
	if not decor_key.is_empty() and base_key != "water" and base_key != "water_calm":
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
