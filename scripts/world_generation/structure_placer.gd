extends RefCounted

## Sorts candidate dictionaries by descending score without a per-compare
## lambda: pack (-score, index) pairs, native-sort, rebuild in order.
static func _sort_by_score(candidates: Array[Dictionary]) -> Array[Dictionary]:
	var order := PackedVector2Array()
	order.resize(candidates.size())
	for index in candidates.size():
		order[index] = Vector2(-float(candidates[index].get("score", 0.0)), float(index))
	order.sort()
	var sorted: Array[Dictionary] = []
	sorted.resize(candidates.size())
	for index in order.size():
		sorted[index] = candidates[int(order[index].y)]
	return sorted

static func _occupied_set(occupied: Array[Vector2i]) -> Dictionary:
	var occupied_set: Dictionary = {}
	for coord: Vector2i in occupied:
		occupied_set[coord] = true
	return occupied_set

static func build_wizard_tower_candidates(tile_data: Dictionary, biome_map: Dictionary, height_map: Dictionary, moisture_map: Dictionary, occupied: Array[Vector2i], map_size: Vector2i, biomes: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var occupied_set := _occupied_set(occupied)
	var candidates: Array[Dictionary] = []
	for coord: Vector2i in tile_data.keys():
		var tile_info := tile_data.get(coord, {}) as Dictionary
		if occupied_set.has(coord) or bool(tile_info.get("river", false)): continue
		var base_biome := String(tile_info.get("base_biome", biome_map.get(coord, biomes.get("grassland", "grassland")))).to_lower()
		if base_biome != String(biomes.get("grassland", "grassland")) and base_biome != String(biomes.get("tundra", "tundra")): continue
		if not String(tile_info.get("overlay", "")).strip_edges().is_empty(): continue
		if not String(tile_info.get("hill_overlay", "")).strip_edges().is_empty(): continue
		var height_value := float(height_map.get(coord, 0.0))
		var dryness := clampf(1.0 - float(moisture_map.get(coord, 0.5)), 0.0, 1.0)
		var edge_distance := mini(mini(coord.x, map_size.x - 1 - coord.x), mini(coord.y, map_size.y - 1 - coord.y))
		var edge_score := clampf(float(edge_distance) / maxf(1.0, float(mini(map_size.x, map_size.y)) / 2.2), 0.0, 1.0)
		var terrain_bonus := 0.18 if base_biome == String(biomes.get("tundra", "tundra")) else 0.12
		var score := clampf(height_value * 1.35, 0.0, 1.0) * 0.35 + dryness * 0.2 + edge_score * 0.15 + terrain_bonus + rng.randf_range(0.0, 0.3)
		candidates.append({"coord": coord, "score": score, "base": base_biome})
	return _sort_by_score(candidates)

static func build_camp_candidates(tile_data: Dictionary, biome_map: Dictionary, moisture_map: Dictionary, occupied: Array[Vector2i], biomes: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var occupied_set := _occupied_set(occupied)
	var candidates: Array[Dictionary] = []
	for coord: Vector2i in tile_data.keys():
		var tile_info := tile_data.get(coord, {}) as Dictionary
		if occupied_set.has(coord) or bool(tile_info.get("river", false)): continue
		var base_biome := String(tile_info.get("base_biome", biome_map.get(coord, biomes.get("grassland", "grassland")))).to_lower()
		if base_biome == String(biomes.get("water", "water")) or base_biome == String(biomes.get("mountain", "mountain")): continue
		if String(tile_info.get("overlay", "")).to_lower().contains("mountain"): continue
		var dryness := clampf(1.0 - float(moisture_map.get(coord, 0.5)), 0.0, 1.0)
		var score := dryness * 0.35 + rng.randf_range(0.0, 0.28)
		if base_biome == String(biomes.get("badlands", "badlands")): score += 0.45
		elif base_biome == String(biomes.get("desert", "desert")): score += 0.36
		elif base_biome == String(biomes.get("marsh", "marsh")): score += 0.28
		else: score += 0.2
		candidates.append({"coord": coord, "score": score, "base_biome": base_biome})
	return _sort_by_score(candidates)

static func build_cave_and_dungeon_candidates(tile_data: Dictionary, biome_map: Dictionary, height_map: Dictionary, moisture_map: Dictionary, occupied: Array[Vector2i], biomes: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var occupied_set := _occupied_set(occupied)
	var caves: Array[Dictionary] = []
	var dungeons: Array[Dictionary] = []
	for coord: Vector2i in tile_data.keys():
		var tile_info := tile_data.get(coord, {}) as Dictionary
		if occupied_set.has(coord) or bool(tile_info.get("river", false)): continue
		var base_biome := String(tile_info.get("base_biome", biome_map.get(coord, biomes.get("grassland", "grassland")))).to_lower()
		var overlay := String(tile_info.get("overlay", "")).to_lower()
		var height_value := float(height_map.get(coord, 0.0))
		var dryness := clampf(1.0 - float(moisture_map.get(coord, 0.5)), 0.0, 1.0)
		if base_biome == String(biomes.get("mountain", "mountain")) or overlay.contains("hill"):
			caves.append({"coord": coord, "score": height_value * 0.55 + dryness * 0.1 + rng.randf_range(0.0, 0.35)})
		if base_biome != String(biomes.get("water", "water")) and base_biome != String(biomes.get("mountain", "mountain")):
			var dungeon_score := dryness * 0.45 + rng.randf_range(0.0, 0.35)
			if base_biome == String(biomes.get("badlands", "badlands")): dungeon_score += 0.12
			dungeons.append({"coord": coord, "score": dungeon_score})
	return {"caves": _sort_by_score(caves), "dungeons": _sort_by_score(dungeons)}

static func select_camp_type_from_biome(base_biome: String, rng: RandomNumberGenerator, biomes: Dictionary) -> String:
	var biome_key := base_biome.to_lower()
	var options: Array[String] = ["orcCamp", "gnollCamp", "banditCamp"]
	if biome_key == String(biomes.get("badlands", "badlands")) or biome_key == String(biomes.get("desert", "desert")):
		options = ["orcCamp", "gnollCamp", "trollCamp", "ogreCamp", "banditCamp"]
	elif biome_key == String(biomes.get("grassland", "grassland")):
		options = ["banditCamp", "travelerCamp", "centaurEncampment", "orcCamp"]
	elif biome_key == String(biomes.get("marsh", "marsh")):
		options = ["gnollCamp", "trollCamp", "ogreCamp"]
	return options[rng.randi_range(0, options.size() - 1)]
