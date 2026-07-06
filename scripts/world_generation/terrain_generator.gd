extends RefCounted
class_name TerrainGenerator

const CONTINENT_WARP_SCALE := 3.8
const CONTINENT_MACRO_SCALE := 2.4
const CONTINENT_RIDGE_SCALE := 6.4
const CONTINENT_MICRO_SCALE := 13.0
const SMOOTHING_OFFSETS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1)
]

static func sample_height(continent_noise: FastNoiseLite, detail_noise: FastNoiseLite, ridge_noise: FastNoiseLite, x: int, y: int, settings: Dictionary, landmass_centers: Array[Vector2]) -> float:
	var continent := to_normalized(continent_noise.get_noise_2d(float(x), float(y)))
	var detail := to_normalized(detail_noise.get_noise_2d(float(x), float(y)))
	var ridges := 1.0 - absf(ridge_noise.get_noise_2d(float(x), float(y)))
	var height := continent * 0.72 + detail * 0.18 + ridges * 0.1
	var archipelago := (to_normalized(detail_noise.get_noise_2d(float(x) * 2.6, float(y) * 2.6)) - 0.5) * 0.12
	height += archipelago
	height += sample_continent_bias(x, y, settings, landmass_centers)
	var water_level := float(settings.get("water_level", 0.45))
	var coast_mask := 1.0 - clampf(absf(height - water_level) / 0.15, 0.0, 1.0)
	var coast_jag := detail_noise.get_noise_2d(float(x) * 5.1, float(y) * 5.1) * 0.06 * coast_mask
	return clampf(height + coast_jag, 0.0, 1.0)

static func configure_landmass_centers(rng: RandomNumberGenerator, count: int, margin: float, min_separation: float = 0.0) -> Array[Vector2]:
	var centers: Array[Vector2] = []
	var safe_count := maxi(1, count)
	var clamped_margin := clampf(margin, 0.0, 0.45)
	for _i in range(safe_count):
		var candidate := Vector2.ZERO
		for attempt in 24:
			candidate = Vector2(rng.randf_range(-1.0 + clamped_margin, 1.0 - clamped_margin), rng.randf_range(-1.0 + clamped_margin, 1.0 - clamped_margin))
			if min_separation <= 0.0:
				break
			var far_enough := true
			for existing: Vector2 in centers:
				if candidate.distance_to(existing) < min_separation:
					far_enough = false
					break
			if far_enough:
				break
		centers.append(candidate)
	return centers

static func smooth_height_map(height_map: Dictionary, passes: int, strength: float, water_level: float) -> void:
	for _pass_index in range(passes):
		var next_map: Dictionary = {}
		for coord: Vector2i in height_map.keys():
			var current: float = height_map.get(coord, 0.0)
			var is_land := current >= water_level
			var accum := current
			var count := 1
			for offset: Vector2i in SMOOTHING_OFFSETS:
				var neighbor := coord + offset
				var neighbor_height: float = height_map.get(neighbor, current)
				if is_land and neighbor_height < water_level: continue
				if not is_land and neighbor_height >= water_level: continue
				accum += neighbor_height
				count += 1
			next_map[coord] = lerpf(current, accum / float(count), strength)
		height_map.assign(next_map)

static func to_normalized(noise_sample: float) -> float:
	return clampf((noise_sample + 1.0) * 0.5, 0.0, 1.0)

static func sample_continent_bias(x: int, y: int, settings: Dictionary, landmass_centers: Array[Vector2]) -> float:
	var map_size := settings.get("map_size", Vector2i.ONE) as Vector2i
	var denom_x := maxf(1.0, float(map_size.x - 1))
	var denom_y := maxf(1.0, float(map_size.y - 1))
	var nx := float(x) / denom_x
	var ny := float(y) / denom_y
	var centered_nx := nx * 2.0 - 1.0
	var centered_ny := ny * 2.0 - 1.0
	var map_seed := int(settings.get("map_seed", 0))
	var base_seed := map_seed + 0x6a09e667
	var fractal := (value_noise(nx * 18.0 + 2.3, ny * 18.0 + 9.7, base_seed) - 0.5) * 0.1
	fractal += (value_noise(nx * 42.0 + 13.1, ny * 42.0 + 5.4, base_seed + 0xbb67ae85) - 0.5) * 0.05
	var radial := sample_radial_falloff_bias(centered_nx, centered_ny, float(settings.get("falloff_strength", 0.0)), float(settings.get("falloff_power", 2.4)))
	var center := sample_landmass_center_bias(centered_nx, centered_ny, float(settings.get("landmass_falloff_scale", 1.35)), float(settings.get("falloff_power", 2.4)), landmass_centers) * float(settings.get("center_shape_strength", 1.0))
	var mask := sample_landmass_mask_bias(nx, ny, settings)
	return fractal + radial + center + mask + sample_edge_ocean_bias(x, y, settings)

static func sample_edge_ocean_bias(x: int, y: int, settings: Dictionary) -> float:
	var map_size := settings.get("map_size", Vector2i.ONE) as Vector2i
	var max_x := maxf(1.0, float(map_size.x - 1))
	var max_y := maxf(1.0, float(map_size.y - 1))
	var edge_distance := minf(minf(float(x), max_x - float(x)), minf(float(y), max_y - float(y)))
	var half_span := minf(max_x, max_y) * 0.5
	var edge_normalized := clampf(edge_distance / maxf(half_span, 1.0), 0.0, 1.0)
	var falloff := maxf(float(settings.get("edge_ocean_falloff", 0.32)), 0.01)
	var edge_ratio := clampf(edge_normalized / falloff, 0.0, 1.0)
	var edge_ocean := 1.0 - pow(edge_ratio, float(settings.get("edge_ocean_curve", 1.6)))
	var strength := float(settings.get("edge_ocean_strength", 0.2))
	var interior_support := pow(clampf(edge_normalized, 0.0, 1.0), 2.2) * (strength * 0.28)
	return interior_support - edge_ocean * strength

static func sample_radial_falloff_bias(centered_nx: float, centered_ny: float, falloff_strength: float, falloff_power: float) -> float:
	# Positive strength pulls land toward the map centre; negative strength
	# inverts the profile (sea at the centre, land toward the edges), which
	# the Inland Sea layout relies on.
	if is_zero_approx(falloff_strength): return 0.0
	var radial_distance := Vector2(centered_nx, centered_ny).length() / sqrt(2.0)
	var attenuation := 1.0 - pow(clampf(radial_distance, 0.0, 1.0), maxf(falloff_power, 0.05))
	return (attenuation - 0.5) * 2.0 * falloff_strength

static func sample_landmass_center_bias(centered_nx: float, centered_ny: float, landmass_falloff_scale: float, falloff_power: float, landmass_centers: Array[Vector2]) -> float:
	var clamped_scale := maxf(0.001, landmass_falloff_scale)
	var center_distance := distance_to_nearest_landmass_center(centered_nx, centered_ny, landmass_centers)
	var center_support := 1.0 - pow(clampf(center_distance / clamped_scale, 0.0, 1.0), maxf(falloff_power, 0.05))
	var continental_shell := clampf((center_distance - (clamped_scale * 0.46)) / (clamped_scale * 0.62), 0.0, 1.0)
	var ocean_separation := pow(continental_shell, 1.35) * (0.16 + clamped_scale * 0.04)
	var center_variation := sample_center_voronoi_variation(centered_nx, centered_ny, landmass_centers, clamped_scale)
	return (center_support - 0.5) * 2.0 * (landmass_falloff_scale * 0.08) + center_variation - ocean_separation

static func sample_landmass_mask_bias(nx: float, ny: float, settings: Dictionary) -> float:
	var strength := float(settings.get("landmass_mask_strength", 0.0))
	if strength <= 0.0: return 0.0
	return (sample_landmass_mask(nx, ny, settings) - 0.5) * 2.0 * strength

static func distance_to_nearest_landmass_center(nx: float, ny: float, landmass_centers: Array[Vector2]) -> float:
	if landmass_centers.is_empty(): return Vector2(nx, ny).length()
	var sample_pos := Vector2(nx, ny)
	var min_distance := INF
	for center: Vector2 in landmass_centers:
		min_distance = minf(min_distance, sample_pos.distance_to(center))
	return min_distance

static func sample_center_voronoi_variation(nx: float, ny: float, landmass_centers: Array[Vector2], falloff_scale: float) -> float:
	if landmass_centers.size() < 2:
		return 0.0
	var sample_pos := Vector2(nx, ny)
	var nearest := INF
	var second_nearest := INF
	for center: Vector2 in landmass_centers:
		var dist := sample_pos.distance_to(center)
		if dist < nearest:
			second_nearest = nearest
			nearest = dist
		elif dist < second_nearest:
			second_nearest = dist
	if !is_finite(second_nearest):
		return 0.0
	var scale := maxf(falloff_scale * 0.68, 0.001)
	var separation := clampf((second_nearest - nearest) / scale, 0.0, 1.0)
	var near_center := clampf(1.0 - nearest / maxf(falloff_scale, 0.001), 0.0, 1.0)
	var boundary_carve := (1.0 - separation) * 0.08
	var lobe_bonus := pow(near_center, 1.35) * 0.09
	return lobe_bonus - boundary_carve

static func sample_landmass_mask(nx: float, ny: float, settings: Dictionary) -> float:
	var map_seed := int(settings.get("map_seed", 0))
	var base_seed := map_seed + 0x9e3779b
	var warp_x := (value_noise(nx * CONTINENT_WARP_SCALE + 2.7, ny * CONTINENT_WARP_SCALE + 9.1, base_seed) - 0.5) * 0.18
	var warp_y := (value_noise(nx * CONTINENT_WARP_SCALE + 13.2, ny * CONTINENT_WARP_SCALE + 4.8, base_seed + 0x85ebca6) - 0.5) * 0.18
	var sx := nx + warp_x
	var sy := ny + warp_y

	var mask_scale := maxf(float(settings.get("landmass_mask_scale", 1.0)), 0.05)
	var macro := sample_fbm(sx * CONTINENT_MACRO_SCALE * mask_scale, sy * CONTINENT_MACRO_SCALE * mask_scale, base_seed + 0xc2b2ae35, 4, 2.05, 0.52)
	var ridge_source := sample_fbm(sx * CONTINENT_RIDGE_SCALE * mask_scale, sy * CONTINENT_RIDGE_SCALE * mask_scale, base_seed + 0x27d4eb2f, 3, 2.0, 0.58)
	var ridges := 1.0 - absf(ridge_source * 2.0 - 1.0)
	var micro := sample_fbm(sx * CONTINENT_MICRO_SCALE * mask_scale, sy * CONTINENT_MICRO_SCALE * mask_scale, base_seed + 0x165667b1, 2, 2.35, 0.5)

	var raw := macro * 0.82 + ridges * 0.24 + (micro - 0.5) * 0.14
	var threshold := float(settings.get("landmass_mask_threshold", 0.47))
	var thresholded := clampf((raw - threshold) / 0.45, 0.0, 1.0)
	var value := pow(thresholded, float(settings.get("landmass_mask_power", 0.82)))

	var edge_distance := minf(minf(nx, 1.0 - nx), minf(ny, 1.0 - ny))
	var edge_band := maxf(float(settings.get("landmass_mask_edge_falloff", 0.26)), 0.001)
	var edge_falloff := clampf(edge_distance / edge_band, 0.0, 1.0)
	value *= edge_falloff

	value += (value_noise(nx * 12.5 + 3.1, ny * 12.5 + 7.9, base_seed) - 0.5) * 0.12
	value += (value_noise(nx * 34.2 + 11.3, ny * 34.2 + 4.6, base_seed + 0x85ebca6) - 0.5) * 0.06
	return clampf(value, 0.0, 1.0)

static func sample_fbm(x: float, y: float, seed_value: int, octaves: int, lacunarity: float, gain: float) -> float:
	var value := 0.0
	var amplitude := 1.0
	var frequency := 1.0
	var total_amplitude := 0.0
	for octave in range(maxi(1, octaves)):
		var octave_seed := seed_value + octave * 0x45d9f3b
		value += value_noise(x * frequency, y * frequency, octave_seed) * amplitude
		total_amplitude += amplitude
		frequency *= lacunarity
		amplitude *= gain
	if total_amplitude <= 0.0:
		return 0.5
	return value / total_amplitude

static func ellipse_distance(nx: float, ny: float, center: Vector2, radius: Vector2) -> float:
	var dx := (nx - center.x) / maxf(radius.x, 0.001)
	var dy := (ny - center.y) / maxf(radius.y, 0.001)
	return sqrt(dx * dx + dy * dy)

static func value_noise(x: float, y: float, seed_value: int) -> float:
	var xi := int(floor(x))
	var yi := int(floor(y))
	var tx := x - float(xi)
	var ty := y - float(yi)
	var a := hash_coords(xi, yi, seed_value)
	var b := hash_coords(xi + 1, yi, seed_value)
	var c := hash_coords(xi, yi + 1, seed_value)
	var d := hash_coords(xi + 1, yi + 1, seed_value)
	var u := fade(tx)
	var v := fade(ty)
	var ab := lerpf(a, b, u)
	var cd := lerpf(c, d, u)
	return lerpf(ab, cd, v)

static func hash_coords(x: int, y: int, seed_value: int) -> float:
	var h: int = x * 374761393 + y * 668265263 + seed_value * 2654435761
	h = int((h ^ (h >> 13)) * 1274126177)
	h = h ^ (h >> 16)
	var unsigned: int = h & 0xffffffff
	return float(unsigned) / 4294967295.0

static func fade(t: float) -> float:
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


static func generate_landmass_masks_from_biome_map(biome_map: Dictionary, map_size: Vector2i, water_biome: String) -> Dictionary:
	var land_mask: Dictionary[Vector2i, bool] = {}
	var water_mask: Dictionary[Vector2i, bool] = {}
	var visited: Dictionary[Vector2i, bool] = {}
	var ocean_cells: Dictionary[Vector2i, bool] = {}
	var lake_cells: Dictionary[Vector2i, bool] = {}

	for y in range(map_size.y):
		for x in range(map_size.x):
			var coord := Vector2i(x, y)
			if String(biome_map.get(coord, "")) == water_biome:
				water_mask[coord] = true
			else:
				land_mask[coord] = true

	# Browser parity (main.js:28219-28226): a water cluster counts as ocean
	# when it touches the map edge OR is at least max(80, area / 80) tiles,
	# so vast inland seas are oceans rather than lakes.
	var ocean_size_threshold := maxi(80, int(round(float(map_size.x * map_size.y) / 80.0)))

	for coord: Vector2i in water_mask.keys():
		if visited.has(coord):
			continue
		var queue: Array[Vector2i] = [coord]
		var component: Array[Vector2i] = []
		var touches_edge := false

		while !queue.is_empty():
			var current: Vector2i = queue.pop_back()
			if visited.has(current):
				continue
			visited[current] = true
			component.append(current)
			if current.x == 0 or current.y == 0 or current.x == map_size.x - 1 or current.y == map_size.y - 1:
				touches_edge = true
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor: Vector2i = current + offset
				if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= map_size.x or neighbor.y >= map_size.y:
					continue
				if water_mask.has(neighbor) and !visited.has(neighbor):
					queue.append(neighbor)

		var qualifies_as_ocean := touches_edge or component.size() >= ocean_size_threshold
		for cell in component:
			if qualifies_as_ocean:
				ocean_cells[cell] = true
			else:
				lake_cells[cell] = true

	var sea_island: Array[Vector2i] = []
	var lake_island: Array[Vector2i] = []

	for coord: Vector2i in land_mask.keys():
		var adjacent_ocean := false
		var adjacent_lake := false
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = coord + offset
			if !water_mask.has(neighbor):
				continue
			if lake_cells.has(neighbor):
				adjacent_lake = true
			else:
				adjacent_ocean = true
		if adjacent_lake or adjacent_ocean:
			if adjacent_lake and !adjacent_ocean:
				lake_island.append(coord)
			else:
				sea_island.append(coord)

	return {
		"paths": [],
		"land_mask": land_mask,
		"water_mask": water_mask,
		"ocean_cells": ocean_cells,
		"lake_cells": lake_cells,
		"coastline": {
			"sea_island": sea_island,
			"lake_island": lake_island
		},
		"lakes": {"freshwater": lake_cells.keys()}
	}
