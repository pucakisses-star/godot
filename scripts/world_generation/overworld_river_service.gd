extends RefCounted
class_name OverworldRiverService

const TILE_ATLAS_DEFS := preload("res://scripts/world_generation/tile_atlas_defs.gd")

const BIOME_WATER := TILE_ATLAS_DEFS.BIOME_WATER
const RIVER_TILES := TILE_ATLAS_DEFS.RIVER_TILES

const RIVER_NEIGHBOR_DEFINITIONS := [
	{"offset": Vector2i(0, -1), "key": "N", "bit": 1},
	{"offset": Vector2i(1, 0), "key": "E", "bit": 2},
	{"offset": Vector2i(0, 1), "key": "S", "bit": 4},
	{"offset": Vector2i(-1, 0), "key": "W", "bit": 8}
]

## Flow directions for carving (tile masks stay 4-way; diagonal steps
## stamp a staircase cell so channels remain edge-connected).
const RIVER_FLOW_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)
]

const RIVER_MASK_SUFFIX_LOOKUP := {
	0: "0",
	1: "N",
	2: "E",
	3: "NE",
	4: "S",
	5: "NS",
	6: "SE",
	7: "NSE",
	8: "W",
	9: "NW",
	10: "WE",
	11: "NWE",
	12: "SW",
	13: "NSW",
	14: "SWE",
	15: "NSWE"
}

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

const _ID_TO_BIOME: Array[String] = [
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


static func _is_valid(coord: Vector2i, map_size: Vector2i) -> bool:
	return coord.x >= 0 and coord.y >= 0 and coord.x < map_size.x and coord.y < map_size.y


static func _xy_to_index(x: int, y: int, map_size: Vector2i) -> int:
	return y * map_size.x + x


static func _coord_to_index(coord: Vector2i, map_size: Vector2i) -> int:
	return coord.y * map_size.x + coord.x


static func _index_to_coord(index: int, map_size: Vector2i) -> Vector2i:
	if map_size.x <= 0:
		return Vector2i.ZERO
	@warning_ignore("integer_division")
	return Vector2i(index % map_size.x, index / map_size.x)


static func _biome_id_to_string(biome_id: int) -> String:
	if biome_id < 0 or biome_id >= _ID_TO_BIOME.size():
		return TILE_ATLAS_DEFS.BIOME_GRASSLAND
	return _ID_TO_BIOME[biome_id]


static func _biome_buffer_to_dictionary(buffer: PackedByteArray, map_size: Vector2i) -> Dictionary:
	var map: Dictionary = {}
	for i in range(buffer.size()):
		map[_index_to_coord(i, map_size)] = _biome_id_to_string(int(buffer[i]))
	return map


static func build_river_map_buffers(
	height_buffer: PackedFloat32Array,
	moisture_buffer: PackedFloat32Array,
	base_biome_buffer: PackedByteArray,
	rng: RandomNumberGenerator,
	map_size: Vector2i,
	water_level: float,
	river_frequency: float
) -> Dictionary:
	var frequency_normalized := clampf(river_frequency, 0.0, 1.0)
	var frequency_multiplier := lerpf(0.45, 1.75, frequency_normalized)
	var weight_threshold := 0.12 * lerpf(1.45, 0.45, frequency_normalized)
	var major_river_threshold := lerpf(0.45, 0.28, frequency_normalized)
	var candidates: Array[Dictionary] = []
	for y in range(1, map_size.y - 1):
		for x in range(1, map_size.x - 1):
			var idx := _xy_to_index(x, y, map_size)
			if _biome_id_to_string(int(base_biome_buffer[idx])) == BIOME_WATER:
				continue
			var elev := float(height_buffer[idx])
			if elev <= water_level + 0.02:
				continue
			var sink := clampf(1.0 - float(moisture_buffer[idx]), 0.0, 1.0)
			var height_factor := maxf(0.0, elev - water_level)
			var randomness := 0.35 + rng.randf() * 0.65
			var weight := (height_factor * 0.7 + sink * 0.3) * randomness
			if weight > weight_threshold:
				candidates.append({"idx": idx, "weight": weight})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("weight", 0.0)) > float(b.get("weight", 0.0))
	)
	var base_sources := maxi(8, int(floor(float(map_size.x * map_size.y) / 3200.0)))
	var source_density_multiplier := lerpf(1.8, 3.1, frequency_normalized)
	var max_sources := maxi(4, int(round(float(base_sources) * frequency_multiplier * source_density_multiplier)))
	var ocean_distance := build_ocean_distance_map(_biome_buffer_to_dictionary(base_biome_buffer, map_size), map_size)
	var ocean_influence := lerpf(0.008, 0.02, frequency_normalized)
	var river_map: Dictionary = {}
	# Rivers wander like water: eight flow directions, momentum carrying
	# the current forward, and a slow side-to-side meander per river. The
	# straight-line channels of the old 4-way steepest-descent are gone.
	var far_distance := float(map_size.x + map_size.y)
	for i in range(mini(candidates.size(), max_sources)):
		var candidate := candidates[i] as Dictionary
		var idx := int(candidate.get("idx", 0))
		var coord := _index_to_coord(idx, map_size)
		var steps := 0
		var strength := 2 if float(candidate.get("weight", 0.0)) > major_river_threshold else 1
		var meander_phase := rng.randf() * TAU
		var meander_amplitude := 0.6 + rng.randf() * 0.8
		var last_dir := Vector2.ZERO
		while steps < map_size.x + map_size.y:
			river_map[coord] = mini(4, int(river_map.get(coord, 0)) + strength)
			steps += 1
			var current_idx := _coord_to_index(coord, map_size)
			var current_base_value := float(height_buffer[current_idx]) - float(moisture_buffer[current_idx]) * 0.02
			var current_ocean_distance := float(ocean_distance.get(coord, far_distance))
			var sway := sin(float(steps) * 0.3 + meander_phase) * 0.0045 * meander_amplitude
			var best_offset := Vector2i.ZERO
			# A little slack lets the current carry across flats and low bumps.
			var best_score := current_base_value + 0.0035
			for offset: Vector2i in RIVER_FLOW_OFFSETS:
				var neighbor := coord + offset
				if not _is_valid(neighbor, map_size):
					continue
				var neighbor_idx := _coord_to_index(neighbor, map_size)
				var direction := Vector2(offset).normalized()
				var score := float(height_buffer[neighbor_idx]) - float(moisture_buffer[neighbor_idx]) * 0.02
				score += (float(ocean_distance.get(neighbor, far_distance)) - current_ocean_distance) * ocean_influence * 0.5
				score -= last_dir.dot(direction) * 0.0035
				score += last_dir.cross(direction) * sway
				if score < best_score:
					best_score = score
					best_offset = offset
			if best_offset == Vector2i.ZERO:
				break
			var next := coord + best_offset
			var step_dir := Vector2(best_offset).normalized()
			last_dir = step_dir if last_dir == Vector2.ZERO else last_dir.lerp(step_dir, 0.55).normalized()
			if best_offset.x != 0 and best_offset.y != 0:
				# Staircase the diagonal through the lower shoulder so the
				# channel stays edge-connected for the 4-way tile masks.
				var horizontal := coord + Vector2i(best_offset.x, 0)
				var vertical := coord + Vector2i(0, best_offset.y)
				var shoulder := horizontal
				if float(height_buffer[_coord_to_index(vertical, map_size)]) < float(height_buffer[_coord_to_index(horizontal, map_size)]):
					shoulder = vertical
				if _biome_id_to_string(int(base_biome_buffer[_coord_to_index(shoulder, map_size)])) != BIOME_WATER:
					river_map[shoulder] = mini(4, int(river_map.get(shoulder, 0)) + strength)
			if _biome_id_to_string(int(base_biome_buffer[_coord_to_index(next, map_size)])) == BIOME_WATER:
				break
			coord = next
			if int(river_map.get(coord, 0)) > 0 and steps > 3:
				break
	return river_map


static func build_river_map(
	height_map: Dictionary,
	moisture_map: Dictionary,
	base_biome_map: Dictionary,
	rng: RandomNumberGenerator,
	map_size: Vector2i,
	water_level: float,
	river_frequency: float
) -> Dictionary:
	# Delegates to the buffer walk so there is exactly one river algorithm.
	var cell_count := map_size.x * map_size.y
	var height_buffer := PackedFloat32Array()
	height_buffer.resize(cell_count)
	var moisture_buffer := PackedFloat32Array()
	moisture_buffer.resize(cell_count)
	var biome_buffer := PackedByteArray()
	biome_buffer.resize(cell_count)
	for index in range(cell_count):
		var coord := _index_to_coord(index, map_size)
		height_buffer[index] = float(height_map.get(coord, water_level))
		moisture_buffer[index] = float(moisture_map.get(coord, 0.5))
		biome_buffer[index] = _ID_TO_BIOME.find(String(base_biome_map.get(coord, TILE_ATLAS_DEFS.BIOME_GRASSLAND)))
	return build_river_map_buffers(height_buffer, moisture_buffer, biome_buffer, rng, map_size, water_level, river_frequency)

static func build_ocean_distance_map(base_biome_map: Dictionary, map_size: Vector2i) -> Dictionary:
	return OverworldTerrainService.build_ocean_distance_map(
		base_biome_map,
		map_size,
		BIOME_WATER,
		RIVER_NEIGHBOR_DEFINITIONS,
		func(coord: Vector2i) -> bool: return _is_valid(coord, map_size)
	)


static func compute_edge_connected_water_mask(base_biome_map: Dictionary, map_size: Vector2i) -> Dictionary:
	return OverworldTerrainService.compute_edge_connected_water_mask(
		base_biome_map,
		map_size,
		BIOME_WATER,
		RIVER_NEIGHBOR_DEFINITIONS,
		func(coord: Vector2i) -> bool: return _is_valid(coord, map_size)
	)


static func apply_river_tiles(
	river_map: Dictionary,
	base_biome_map: Dictionary,
	highland_map: Dictionary,
	tree_map: Dictionary,
	edge_connected_water: Dictionary,
	map_size: Vector2i,
	river_layer: TileMapLayer,
	highland_layer: TileMapLayer,
	tree_layer: TileMapLayer,
	atlas_source_id: int
) -> Dictionary:
	var river_tiles: Dictionary = {}
	if river_layer == null:
		return river_tiles
	for y in range(map_size.y):
		for x in range(map_size.x):
			var coord := Vector2i(x, y)
			if int(river_map.get(coord, 0)) <= 0 or String(base_biome_map.get(coord, "")) == BIOME_WATER:
				river_layer.erase_cell(coord)
				continue
			var river_tile := resolve_river_tile(river_map, coord, base_biome_map, edge_connected_water, map_size)
			if river_tile.x < 0 or river_tile.y < 0:
				river_layer.erase_cell(coord)
				continue
			river_layer.set_cell(coord, atlas_source_id, river_tile)
			river_tiles[coord] = true
			highland_map.erase(coord)
			if highland_layer != null:
				highland_layer.erase_cell(coord)
			tree_map.erase(coord)
			if tree_layer != null:
				tree_layer.erase_cell(coord)
	return river_tiles


static func resolve_river_tile(
	river_map: Dictionary,
	coord: Vector2i,
	base_biome_map: Dictionary,
	ocean_mask: Dictionary,
	map_size: Vector2i
) -> Vector2i:
	var strength := int(river_map.get(coord, 0))
	if strength <= 0:
		return Vector2i(-1, -1)
	var mask := 0
	var river_neighbor_count := 0
	for def_variant: Variant in RIVER_NEIGHBOR_DEFINITIONS:
		var def := def_variant as Dictionary
		var neighbor := coord + (def.get("offset", Vector2i.ZERO) as Vector2i)
		if not _is_valid(neighbor, map_size):
			continue
		if int(river_map.get(neighbor, 0)) > 0:
			mask |= int(def.get("bit", 0))
			river_neighbor_count += 1
	var touches_ocean := false
	if river_neighbor_count == 1:
		for def_variant: Variant in RIVER_NEIGHBOR_DEFINITIONS:
			var def := def_variant as Dictionary
			var bit := int(def.get("bit", 0))
			if (mask & bit) != 0:
				continue
			var neighbor := coord + (def.get("offset", Vector2i.ZERO) as Vector2i)
			if not _is_valid(neighbor, map_size):
				continue
			if ocean_mask.has(neighbor):
				mask |= bit
				touches_ocean = true
	var suffix := String(RIVER_MASK_SUFFIX_LOOKUP.get(mask, "NSWE"))
	var base_key := "RIVER_%s" % suffix
	var major_key := "RIVER_MAJOR_%s" % suffix
	var use_major := strength >= 3 and RIVER_TILES.has(major_key)
	var tile_key := major_key if use_major else base_key
	if suffix.length() == 1 and suffix != "0" and not touches_ocean:
		for def_variant: Variant in RIVER_NEIGHBOR_DEFINITIONS:
			var def := def_variant as Dictionary
			if String(def.get("key", "")) != suffix:
				continue
			var neighbor := coord + (def.get("offset", Vector2i.ZERO) as Vector2i)
			if not _is_valid(neighbor, map_size):
				break
			if String(base_biome_map.get(neighbor, "")) != BIOME_WATER:
				break
			var mouth_prefix := "RIVER_MAJOR_MOUTH_NARROW_" if use_major else "RIVER_MOUTH_NARROW_"
			var mouth_key := "%s%s" % [mouth_prefix, suffix]
			if RIVER_TILES.has(mouth_key):
				tile_key = mouth_key
			break
	if not RIVER_TILES.has(tile_key):
		tile_key = "RIVER_NSWE"
	return RIVER_TILES.get(tile_key, Vector2i(-1, -1)) as Vector2i
