extends RefCounted
class_name OverworldSettlementService

static func build_settlement_candidates(biome_map: Dictionary, tree_layer: TileMapLayer, tree_tile: Vector2i, jungle_tree_tile: Vector2i, settlement_biome_label: Callable) -> Array:
	var candidates: Array = []
	for coord: Vector2i in biome_map.keys():
		var biome := String(settlement_biome_label.call(String(biome_map.get(coord, "grassland"))))
		var tree_overlay := Vector2i(-1, -1)
		if tree_layer != null:
			tree_overlay = tree_layer.get_cell_atlas_coords(coord)
		candidates.append({
			"coord": coord,
			"biome": biome,
			"tree_overlay": tree_overlay,
			"has_forest_tree_overlay": tree_overlay == tree_tile,
			"has_jungle_tree_overlay": tree_overlay == jungle_tree_tile
		})
	return candidates

static func is_too_close(coord: Vector2i, occupied: Array[Vector2i], min_distance: float) -> bool:
	for other: Vector2i in occupied:
		if coord.distance_to(other) < min_distance:
			return true
	return false

## Suitability-weighted sampling pool for one faction type, built once
## instead of re-scoring every map cell per placement.
static func build_weighted_capital_pool(faction_type: String, candidates: Array) -> Dictionary:
	var coords: Array[Vector2i] = []
	var cumulative := PackedFloat32Array()
	var total := 0.0
	for candidate: Dictionary in candidates:
		var suitability := DwarfholdLogic.evaluate_tile_suitability(faction_type, candidate)
		if suitability <= 0.0:
			continue
		total += suitability
		coords.append(candidate["coord"] as Vector2i)
		cumulative.append(total)
	return {"coords": coords, "cumulative": cumulative, "total": total}

## Weighted-random pick of an unblocked coord. Rejection sampling keeps
## the same conditional distribution the old filter-then-choose had;
## the rare exhausted case falls back to a full weighted pass over the
## unblocked remainder.
static func sample_capital_from_pool(pool: Dictionary, blocked: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	var coords: Array[Vector2i] = pool.get("coords", []) as Array[Vector2i]
	var cumulative := pool.get("cumulative", PackedFloat32Array()) as PackedFloat32Array
	var total := float(pool.get("total", 0.0))
	if coords.is_empty() or total <= 0.0:
		return Vector2i(-1, -1)
	for _attempt in 64:
		var pick := cumulative.bsearch(rng.randf_range(0.0, total))
		if pick >= coords.size():
			pick = coords.size() - 1
		if not blocked.has(coords[pick]):
			return coords[pick]
	var open_total := 0.0
	var previous := 0.0
	var open_coords: Array[Vector2i] = []
	var open_cumulative := PackedFloat32Array()
	for index in coords.size():
		var weight := cumulative[index] - previous
		previous = cumulative[index]
		if blocked.has(coords[index]):
			continue
		open_total += weight
		open_coords.append(coords[index])
		open_cumulative.append(open_total)
	if open_coords.is_empty():
		return Vector2i(-1, -1)
	var fallback_pick := open_cumulative.bsearch(rng.randf_range(0.0, open_total))
	return open_coords[mini(fallback_pick, open_coords.size() - 1)]

## Marks every cell within min_distance of the settlement so future
## closeness checks are a single dictionary lookup.
static func mark_occupied_area(blocked: Dictionary, center: Vector2i, min_distance: float) -> void:
	var reach := int(ceilf(min_distance))
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if Vector2(dx, dy).length() < min_distance:
				blocked[center + Vector2i(dx, dy)] = true
