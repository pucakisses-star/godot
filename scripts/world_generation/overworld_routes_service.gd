extends RefCounted
class_name OverworldRoutesService

## Terrain-aware trade-route paths for the overworld Routes overlay.
##
## Instead of straight lines between settlements, routes are pathfound
## across the tile grid (hugging coastlines, skirting mountains, fording
## rivers only when needed) and rendered as a crisp dotted trail in the
## style of hand-drawn fantasy-map trade routes.

## Pathfinds every edge across the map grid.
## edges: [{"a": Vector2i, "b": Vector2i}]
## cost_map: coord -> float travel-cost multiplier (>= 1.0)
## Returns one PackedVector2Array of pixel-space tile centers per edge.
static func build_paths(
	edges: Array,
	cost_map: Dictionary,
	map_size: Vector2i,
	tile_size: int
) -> Array[PackedVector2Array]:
	var paths: Array[PackedVector2Array] = []
	if edges.is_empty() or map_size.x <= 0 or map_size.y <= 0:
		return paths

	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, map_size)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for coord_variant: Variant in cost_map.keys():
		var coord := coord_variant as Vector2i
		if grid.is_in_boundsv(coord):
			grid.set_point_weight_scale(coord, maxf(1.0, float(cost_map.get(coord_variant, 1.0))))

	for edge_variant: Variant in edges:
		var edge := edge_variant as Dictionary
		var from_coord := edge.get("a", Vector2i(-1, -1)) as Vector2i
		var to_coord := edge.get("b", Vector2i(-1, -1)) as Vector2i
		if not grid.is_in_boundsv(from_coord) or not grid.is_in_boundsv(to_coord):
			continue
		var cell_path := grid.get_id_path(from_coord, to_coord)
		if cell_path.size() < 2:
			continue
		var pixel_path := PackedVector2Array()
		for cell in cell_path:
			pixel_path.append((Vector2(cell) + Vector2(0.5, 0.5)) * float(tile_size))
		paths.append(pixel_path)
	return paths

## Builds the per-tile travel-cost map from the map's tile metadata.
## tile_biomes: coord -> {"base": String, "hill": String, "river": bool}
## biome_names: {"water": ..., "mountain": ..., "hills": ..., "marsh": ...,
##               "forest": ..., "jungle": ...}
static func build_cost_map(tile_biomes: Dictionary, biome_names: Dictionary) -> Dictionary:
	var water_name := String(biome_names.get("water", "water"))
	var mountain_name := String(biome_names.get("mountain", "mountain"))
	var hills_name := String(biome_names.get("hills", "hills"))
	var marsh_name := String(biome_names.get("marsh", "marsh"))
	var forest_name := String(biome_names.get("forest", "forest"))
	var jungle_name := String(biome_names.get("jungle", "jungle"))
	var cost_map: Dictionary = {}
	for coord_variant: Variant in tile_biomes.keys():
		var info := tile_biomes.get(coord_variant, {}) as Dictionary
		var base := String(info.get("base", ""))
		var hill := String(info.get("hill", ""))
		var cost := 1.0
		if base == water_name:
			# Open water is crossable (ferry lanes) but strongly avoided, so
			# roads hug coastlines instead of cutting across bays.
			cost = 14.0
		elif base == mountain_name or hill == mountain_name:
			cost = 6.0
		elif base == marsh_name:
			cost = 5.0
		elif hill == hills_name:
			cost = 2.2
		elif base == forest_name or base == jungle_name:
			cost = 1.8
		if bool(info.get("river", false)):
			cost += 3.0
		# Deterministic per-tile jitter so long roads meander a little
		# instead of locking onto ruler-straight diagonals.
		var coord := coord_variant as Vector2i
		cost += float((int(coord.x) * 73856093 ^ int(coord.y) * 19349663) % 100) * 0.004
		cost_map[coord_variant] = cost
	return cost_map

## Node that draws every route as a dotted pixel trail: one small square
## per path tile, skipping the endpoints so dots never sit on top of the
## settlement sprites.
class RouteTrailDrawer extends Node2D:
	var paths: Array[PackedVector2Array] = []
	var dot_color: Color = Color(0.82, 0.68, 0.48, 0.9)
	var shadow_color: Color = Color(0.16, 0.11, 0.07, 0.65)
	var dot_size: float = 7.0

	func _draw() -> void:
		var half := floorf(dot_size * 0.5)
		var size_vec := Vector2(dot_size, dot_size)
		var shadow_vec := size_vec + Vector2(2.0, 2.0)
		for path in paths:
			for i in range(1, path.size() - 1):
				var center := path[i].floor()
				draw_rect(Rect2(center - Vector2(half + 1.0, half + 1.0), shadow_vec), shadow_color)
				draw_rect(Rect2(center - Vector2(half, half), size_vec), dot_color)
