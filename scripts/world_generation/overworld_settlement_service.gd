extends RefCounted
class_name OverworldSettlementService


static func is_too_close(coord: Vector2i, occupied: Array[Vector2i], min_distance: float) -> bool:
	for other: Vector2i in occupied:
		if coord.distance_to(other) < min_distance:
			return true
	return false

## Suitability depends only on a cell's (biome label, tree-overlay)
## class, so cells go straight into class buckets - one pass, no
## per-cell candidate dictionaries - and every faction pool shares them.
static func build_settlement_class_buckets(biome_map: Dictionary, tree_layer: TileMapLayer, tree_tile: Vector2i, jungle_tree_tile: Vector2i, settlement_biome_label: Callable) -> Dictionary:
	var buckets: Dictionary = {}
	var label_cache: Dictionary = {}
	for coord: Vector2i in biome_map.keys():
		var raw_biome := String(biome_map.get(coord, "grassland"))
		var biome_variant: Variant = label_cache.get(raw_biome)
		var biome: String
		if biome_variant == null:
			biome = String(settlement_biome_label.call(raw_biome))
			label_cache[raw_biome] = biome
		else:
			biome = String(biome_variant)
		var tree_overlay := Vector2i(-1, -1)
		if tree_layer != null:
			tree_overlay = tree_layer.get_cell_atlas_coords(coord)
		var has_forest := tree_overlay == tree_tile
		var has_jungle := tree_overlay == jungle_tree_tile
		var key := "%s|%d|%d" % [biome, 1 if has_forest else 0, 1 if has_jungle else 0]
		var bucket_variant: Variant = buckets.get(key)
		var bucket: Dictionary
		if bucket_variant == null:
			bucket = {
				"sample": {
					"coord": coord,
					"biome": biome,
					"tree_overlay": tree_overlay,
					"has_forest_tree_overlay": has_forest,
					"has_jungle_tree_overlay": has_jungle
				},
				"coords": [] as Array[Vector2i]
			}
			buckets[key] = bucket
		else:
			bucket = bucket_variant as Dictionary
		(bucket["coords"] as Array[Vector2i]).append(coord)
	return buckets

## Weighted sampling pool for one faction type over the class buckets.
## Every cell of a class shares the class weight, so drawing a class by
## cumulative weight and then a uniform member is exactly the per-cell
## weighted draw.
static func build_weighted_capital_pool(faction_type: String, class_buckets: Dictionary) -> Dictionary:
	var groups: Array[Dictionary] = []
	var cumulative := PackedFloat32Array()
	var total := 0.0
	for key_variant: Variant in class_buckets.keys():
		var bucket := class_buckets[key_variant] as Dictionary
		var suitability := DwarfholdLogic.evaluate_tile_suitability(faction_type, bucket["sample"] as Dictionary)
		if suitability <= 0.0:
			continue
		var coords := bucket["coords"] as Array[Vector2i]
		total += suitability * coords.size()
		groups.append({"coords": coords, "weight": suitability})
		cumulative.append(total)
	return {"groups": groups, "cumulative": cumulative, "total": total}

## Weighted-random pick of an unblocked coord. Rejection sampling keeps
## the same conditional distribution the old filter-then-choose had;
## the rare exhausted case falls back to a full weighted pass over the
## unblocked remainder.
static func sample_capital_from_pool(pool: Dictionary, blocked: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	var groups: Array[Dictionary] = pool.get("groups", []) as Array[Dictionary]
	var cumulative := pool.get("cumulative", PackedFloat32Array()) as PackedFloat32Array
	var total := float(pool.get("total", 0.0))
	if groups.is_empty() or total <= 0.0:
		return Vector2i(-1, -1)
	for _attempt in 64:
		var group_index := cumulative.bsearch(rng.randf_range(0.0, total))
		if group_index >= groups.size():
			group_index = groups.size() - 1
		var coords := groups[group_index]["coords"] as Array[Vector2i]
		var coord := coords[rng.randi_range(0, coords.size() - 1)]
		if not blocked.has(coord):
			return coord
	var open_total := 0.0
	var open_coords: Array[Vector2i] = []
	var open_cumulative := PackedFloat32Array()
	for group: Dictionary in groups:
		var weight := float(group["weight"])
		for coord: Vector2i in (group["coords"] as Array[Vector2i]):
			if blocked.has(coord):
				continue
			open_total += weight
			open_coords.append(coord)
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
