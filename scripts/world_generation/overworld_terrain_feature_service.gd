extends RefCounted
class_name OverworldTerrainFeatureService

const TILE_ATLAS_DEFS := preload("res://scripts/world_generation/tile_atlas_defs.gd")

const MOUNTAIN_TOP_A_TILE := TILE_ATLAS_DEFS.MOUNTAIN_TOP_A_TILE
const MOUNTAIN_TOP_B_TILE := TILE_ATLAS_DEFS.MOUNTAIN_TOP_B_TILE
const MOUNTAIN_BOTTOM_A_TILE := TILE_ATLAS_DEFS.MOUNTAIN_BOTTOM_A_TILE
const MOUNTAIN_BOTTOM_B_TILE := TILE_ATLAS_DEFS.MOUNTAIN_BOTTOM_B_TILE
const MOUNTAIN_PEAK_TILE := TILE_ATLAS_DEFS.MOUNTAIN_PEAK_TILE
const ACTIVE_VOLCANO_TILE := TILE_ATLAS_DEFS.ACTIVE_VOLCANO_TILE
const VOLCANO_TILE := TILE_ATLAS_DEFS.VOLCANO_TILE
const OASIS_TILE := TILE_ATLAS_DEFS.OASIS_TILE
const SAND_TILE := TILE_ATLAS_DEFS.SAND_TILE
const WATER_TILE := TILE_ATLAS_DEFS.WATER_TILE
const LAVA_TILE := TILE_ATLAS_DEFS.LAVA_TILE
const GRASS_TILE := TILE_ATLAS_DEFS.GRASS_TILE
const SNOW_TILE := TILE_ATLAS_DEFS.SNOW_TILE
const STONE_TILE := TILE_ATLAS_DEFS.STONE_TILE

const BIOME_MOUNTAIN := TILE_ATLAS_DEFS.BIOME_MOUNTAIN
const BIOME_DESERT := TILE_ATLAS_DEFS.BIOME_DESERT
const BIOME_WATER := TILE_ATLAS_DEFS.BIOME_WATER
const BIOME_BADLANDS := TILE_ATLAS_DEFS.BIOME_BADLANDS
const BIOME_TUNDRA := TILE_ATLAS_DEFS.BIOME_TUNDRA
const BIOME_GRASSLAND := TILE_ATLAS_DEFS.BIOME_GRASSLAND

const TILE_OVERLAY_RIVER := 1 << 2
const TILE_OVERLAY_VOLCANO := 1 << 3
const TILE_OVERLAY_ACTIVE_VOLCANO := 1 << 4

## Browser parity: the volcano's heat aura fades to nothing 6.4 tiles
## out, and the ash apron converts ground from 0.45 proximity inward.
const VOLCANO_PROXIMITY_FALLOFF := 6.4
const VOLCANO_STONE_CONVERSION_THRESHOLD := 0.45

const _BIOME_TO_ID := {
	TILE_ATLAS_DEFS.BIOME_WATER: 0,
	TILE_ATLAS_DEFS.BIOME_MOUNTAIN: 1,
	TILE_ATLAS_DEFS.BIOME_HILLS: 2,
	TILE_ATLAS_DEFS.BIOME_MARSH: 3,
	TILE_ATLAS_DEFS.BIOME_TUNDRA: 4,
	TILE_ATLAS_DEFS.BIOME_DESERT: 5,
	TILE_ATLAS_DEFS.BIOME_BADLANDS: 6,
	TILE_ATLAS_DEFS.BIOME_FOREST: 7,
	TILE_ATLAS_DEFS.BIOME_JUNGLE: 8,
	TILE_ATLAS_DEFS.BIOME_GRASSLAND: 9
}


static func _biome_to_id(biome: String) -> int:
	return int(_BIOME_TO_ID.get(biome, int(_BIOME_TO_ID[BIOME_GRASSLAND])))


static func _to_normalized(noise_sample: float) -> float:
	return clampf((noise_sample + 1.0) * 0.5, 0.0, 1.0)


static func apply_mountain_overlay_variants(
	highland_map: Dictionary,
	height_map: Dictionary,
	highland_layer: TileMapLayer,
	atlas_source_id: int,
	map_size: Vector2i
) -> void:
	if highland_layer == null:
		return
	for y in range(map_size.y):
		for x in range(map_size.x):
			var coord := Vector2i(x, y)
			if String(highland_map.get(coord, "")) != BIOME_MOUNTAIN:
				continue
			var has_mountain_above := y > 0 and String(highland_map.get(Vector2i(x, y - 1), "")) == BIOME_MOUNTAIN
			var has_mountain_below := y < map_size.y - 1 and String(highland_map.get(Vector2i(x, y + 1), "")) == BIOME_MOUNTAIN
			var hash_value: int = absi(((x + 1) * 73856093) ^ ((y + 1) * 19349663))
			if not has_mountain_above and has_mountain_below:
				highland_layer.set_cell(coord, atlas_source_id, MOUNTAIN_TOP_A_TILE if hash_value % 2 == 0 else MOUNTAIN_TOP_B_TILE)
			elif not has_mountain_below and has_mountain_above:
				highland_layer.set_cell(coord, atlas_source_id, MOUNTAIN_BOTTOM_A_TILE if hash_value % 2 == 0 else MOUNTAIN_BOTTOM_B_TILE)
			elif float(height_map.get(coord, 0.0)) >= 0.97:
				highland_layer.set_cell(coord, atlas_source_id, MOUNTAIN_PEAK_TILE)


static func place_volcano_tiles(
	highland_map: Dictionary,
	height_map: Dictionary,
	rng: RandomNumberGenerator,
	highland_layer: TileMapLayer,
	map_layer: TileMapLayer,
	atlas_source_id: int,
	map_size: Vector2i,
	tile_data: Dictionary,
	lake_cells: Dictionary = {}
) -> void:
	apply_mountain_overlay_variants(highland_map, height_map, highland_layer, atlas_source_id, map_size)
	var candidates: Array[Dictionary] = []
	for coord_variant: Variant in highland_map.keys():
		var coord := coord_variant as Vector2i
		if String(highland_map.get(coord, "")) != BIOME_MOUNTAIN:
			continue
		# Browser rule: never on a river or an occupied tile.
		var info := tile_data.get(coord, {}) as Dictionary
		if (int(info.get("overlay_flags", 0)) & TILE_OVERLAY_RIVER) != 0:
			continue
		if not String(info.get("settlement_type", "")).strip_edges().is_empty() or not String(info.get("structure", "")).strip_edges().is_empty():
			continue
		candidates.append({
			"coord": coord,
			"height": float(height_map.get(coord, 0.0)),
			"score": rng.randf()
		})
	if candidates.is_empty():
		apply_oases_and_lava([], rng, highland_layer, map_layer, atlas_source_id, map_size, tile_data)
		return

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ah := float(a.get("height", 0.0))
		var bh := float(b.get("height", 0.0))
		if not is_equal_approx(ah, bh):
			return ah > bh
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	var base_volcano_count := int(round(float(candidates.size()) / 600.0))
	var rarity_adjusted_target := maxi(1, int(round(float(maxi(1, base_volcano_count)) * 0.15)))
	var desired_count := clampi(rarity_adjusted_target, 1, mini(candidates.size(), 6))
	var selection_pool := candidates.slice(0, mini(candidates.size(), maxi(desired_count * 5, desired_count + 3)))
	var volcanoes: Array[Vector2i] = []
	var min_distance_sq := 36
	var attempts := 0
	var max_attempts := selection_pool.size() * 3
	while not selection_pool.is_empty() and volcanoes.size() < desired_count and attempts < max_attempts:
		attempts += 1
		var pick_index := rng.randi_range(0, selection_pool.size() - 1)
		var candidate := selection_pool[pick_index] as Dictionary
		selection_pool.remove_at(pick_index)
		var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		var too_close := false
		for placed in volcanoes:
			var dx := coord.x - placed.x
			var dy := coord.y - placed.y
			if dx * dx + dy * dy < min_distance_sq:
				too_close = true
				break
		if too_close:
			continue
		if highland_layer != null:
			highland_layer.set_cell(coord, atlas_source_id, ACTIVE_VOLCANO_TILE if volcanoes.is_empty() else VOLCANO_TILE)
		# The cone itself stands on bare stone (browser main.js:23794-23796:
		# tile.base = stoneTileKey). No dedicated stone biome id exists, so
		# the classification stays BIOME_BADLANDS; only the art is stone.
		if map_layer != null:
			map_layer.set_cell(coord, atlas_source_id, STONE_TILE)
		if tile_data.has(coord):
			var tile_info := tile_data.get(coord, {}) as Dictionary
			if not tile_info.is_empty():
				if volcanoes.is_empty():
					tile_info["overlay_flags"] = int(tile_info.get("overlay_flags", 0)) | TILE_OVERLAY_ACTIVE_VOLCANO
				else:
					tile_info["overlay_flags"] = int(tile_info.get("overlay_flags", 0)) | TILE_OVERLAY_VOLCANO
				tile_info["base_biome_id"] = _biome_to_id(BIOME_BADLANDS)
				tile_info["volcano_proximity"] = 1.0
				# Browser main.js:23790-23793: volcano ruggedness 0.65 +/- 0.175.
				tile_info["mountain_ruggedness"] = clampf(0.65 + (rng.randf() - 0.5) * 0.35, 0.0, 1.0)
				tile_data[coord] = tile_info
		volcanoes.append(coord)

	_apply_volcano_proximity(volcanoes, rng, map_layer, atlas_source_id, map_size, tile_data)
	apply_oases_and_lava(volcanoes, rng, highland_layer, map_layer, atlas_source_id, map_size, tile_data, lake_cells)

## The heat aura, browser-style: proximity = 1 - distance / 6.4 around
## every volcano, stamped into tile data (resources, climate and shading
## read it), with an ash apron converting grass and snow to scorched
## ground - guaranteed at the rim, noise-ragged toward the edge.
static func _apply_volcano_proximity(
	volcanoes: Array[Vector2i],
	rng: RandomNumberGenerator,
	map_layer: TileMapLayer,
	atlas_source_id: int,
	map_size: Vector2i,
	tile_data: Dictionary
) -> void:
	if volcanoes.is_empty():
		return
	var apron_noise := FastNoiseLite.new()
	apron_noise.seed = rng.randi()
	apron_noise.noise_type = FastNoiseLite.TYPE_VALUE
	apron_noise.frequency = 0.18 + rng.randf() * 0.06
	var fine_seed := rng.randi()
	var reach := int(ceil(VOLCANO_PROXIMITY_FALLOFF))
	for volcano in volcanoes:
		for oy in range(-reach, reach + 1):
			for ox in range(-reach, reach + 1):
				if ox == 0 and oy == 0:
					continue
				var coord := volcano + Vector2i(ox, oy)
				if coord.x < 0 or coord.y < 0 or coord.x >= map_size.x or coord.y >= map_size.y:
					continue
				var proximity := clampf(1.0 - Vector2(ox, oy).length() / VOLCANO_PROXIMITY_FALLOFF, 0.0, 1.0)
				if proximity <= 0.0:
					continue
				var info := tile_data.get(coord, {}) as Dictionary
				if info.is_empty():
					continue
				var base_tile := map_layer.get_cell_atlas_coords(coord) if map_layer != null else Vector2i(-1, -1)
				# Water keeps no heat memory (lava lakes are handled apart).
				if base_tile == WATER_TILE:
					continue
				info["volcano_proximity"] = maxf(float(info.get("volcano_proximity", 0.0)), proximity)
				tile_data[coord] = info
				# Ash apron: only living ground scorches.
				if proximity < VOLCANO_STONE_CONVERSION_THRESHOLD:
					continue
				if base_tile != GRASS_TILE and base_tile != SNOW_TILE:
					continue
				var scorch := proximity >= 0.95
				if not scorch:
					var coarse := apron_noise.get_noise_2d(float(coord.x), float(coord.y)) * 0.5
					var fine := float(absi(hash(Vector3i(coord.x, coord.y, fine_seed))) % 1000) / 1000.0 - 0.5
					var conversion_score := proximity + coarse * 0.55 + fine * 0.25
					scorch = conversion_score >= 0.58 - proximity * 0.3
				if scorch and map_layer != null:
					# Ash apron converts to stone art (browser stoneTileKey);
					# classification stays badlands (no stone biome id).
					map_layer.set_cell(coord, atlas_source_id, STONE_TILE)
					info["base_biome_id"] = _biome_to_id(BIOME_BADLANDS)
					tile_data[coord] = info


static func apply_oases_and_lava(
	volcanoes: Array[Vector2i],
	rng: RandomNumberGenerator,
	highland_layer: TileMapLayer,
	map_layer: TileMapLayer,
	atlas_source_id: int,
	map_size: Vector2i,
	tile_data: Dictionary,
	lake_cells: Dictionary = {}
) -> void:
	for coord_variant: Variant in tile_data.keys():
		var coord := coord_variant as Vector2i
		var tile_info := tile_data.get(coord, {}) as Dictionary
		if tile_info.is_empty():
			continue
		var base_biome := _tile_base_biome_from_data(tile_info)
		var base_tile := map_layer.get_cell_atlas_coords(coord)
		if base_biome == BIOME_DESERT and base_tile == SAND_TILE:
			# Browser main.js:22884 skips tiles with any overlay (river,
			# trees), a hill/highland overlay, or a structure/settlement.
			if int(tile_info.get("overlay_flags", 0)) != 0:
				continue
			if not String(tile_info.get("structure", "")).strip_edges().is_empty():
				continue
			if not String(tile_info.get("settlement_type", "")).strip_edges().is_empty():
				continue
			if highland_layer != null and highland_layer.get_cell_atlas_coords(coord) != Vector2i(-1, -1):
				continue
			var has_adjacent_oasis := false
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					if ox == 0 and oy == 0:
						continue
					var neighbor := coord + Vector2i(ox, oy)
					if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= map_size.x or neighbor.y >= map_size.y:
						continue
					if highland_layer != null and highland_layer.get_cell_atlas_coords(neighbor) == OASIS_TILE:
						has_adjacent_oasis = true
						break
				if has_adjacent_oasis:
					break
			if not has_adjacent_oasis:
				# Browser main.js:22903-22908: chance scales with desert
				# suitability (aridity * 0.68 + heat * 0.42), capped at 0.12.
				var desert_suitability := (1.0 - float(tile_info.get("moisture", 0.0))) * 0.68 + float(tile_info.get("temperature", 0.0)) * 0.42
				var oasis_chance := clampf(0.00025 + desert_suitability * 0.002, 0.0, 0.12)
				if rng.randf() < oasis_chance and highland_layer != null and highland_layer.get_cell_atlas_coords(coord) == Vector2i(-1, -1):
					highland_layer.set_cell(coord, atlas_source_id, OASIS_TILE)

	# Browser rule: every LAKE tile touching a volcano boils into lava -
	# always, and only lakes; the open sea never converts.
	for volcano_coord in volcanoes:
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				if ox == 0 and oy == 0:
					continue
				var neighbor := volcano_coord + Vector2i(ox, oy)
				if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= map_size.x or neighbor.y >= map_size.y:
					continue
				if map_layer.get_cell_atlas_coords(neighbor) != WATER_TILE:
					continue
				if not lake_cells.has(neighbor):
					continue
				map_layer.set_cell(neighbor, atlas_source_id, LAVA_TILE)
				if tile_data.has(neighbor):
					var info := tile_data.get(neighbor, {}) as Dictionary
					info["base_biome_id"] = _biome_to_id(BIOME_BADLANDS)
					info["biome_id"] = _biome_to_id(BIOME_BADLANDS)
					info["volcano_proximity"] = 1.0
					tile_data[neighbor] = info


static func surface_variation_for_coord(
	coord: Vector2i,
	base_biome: String,
	rainfall_noise: FastNoiseLite,
	temperature_noise: FastNoiseLite
) -> float:
	if base_biome != BIOME_TUNDRA and base_biome != BIOME_DESERT and base_biome != BIOME_BADLANDS:
		return 0.0
	var coarse := _to_normalized(rainfall_noise.get_noise_2d(float(coord.x) * 0.8, float(coord.y) * 0.8))
	var detail := _to_normalized(temperature_noise.get_noise_2d(float(coord.x) * 2.3, float(coord.y) * 2.3))
	return clampf((coarse * 0.65 + detail * 0.35 - 0.5) * 1.6, -1.0, 1.0)


static func _tile_base_biome_from_data(p_tile_data: Dictionary) -> String:
	var _ID_TO_BIOME: Array[String] = [
		TILE_ATLAS_DEFS.BIOME_WATER,
		TILE_ATLAS_DEFS.BIOME_MOUNTAIN,
		TILE_ATLAS_DEFS.BIOME_HILLS,
		TILE_ATLAS_DEFS.BIOME_MARSH,
		TILE_ATLAS_DEFS.BIOME_TUNDRA,
		TILE_ATLAS_DEFS.BIOME_DESERT,
		TILE_ATLAS_DEFS.BIOME_BADLANDS,
		TILE_ATLAS_DEFS.BIOME_FOREST,
		TILE_ATLAS_DEFS.BIOME_JUNGLE,
		TILE_ATLAS_DEFS.BIOME_GRASSLAND
	]
	var biome_id := int(p_tile_data.get("base_biome_id", _biome_to_id(BIOME_GRASSLAND)))
	if biome_id < 0 or biome_id >= _ID_TO_BIOME.size():
		return BIOME_GRASSLAND
	return _ID_TO_BIOME[biome_id]
