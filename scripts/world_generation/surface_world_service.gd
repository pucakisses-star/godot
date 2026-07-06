extends RefCounted
class_name SurfaceWorldService

## The Core Keeper rule, above ground: the wilds around a town only
## exist near the player. Chunks of surface terrain - grass plains,
## flower meadows, forests, sand barrens, hedge thickets - are derived
## deterministically from the town seed and painted as the player
## wanders out, then dropped again when left far behind. Walking back
## rebuilds the exact same country.

const CHUNK_SIZE := 24

static func make_noise_set(world_seed: int) -> Dictionary:
	var elevation := FastNoiseLite.new()
	elevation.seed = world_seed
	elevation.noise_type = FastNoiseLite.TYPE_SIMPLEX
	elevation.frequency = 0.012
	elevation.fractal_type = FastNoiseLite.FRACTAL_FBM
	elevation.fractal_octaves = 3
	var forest := FastNoiseLite.new()
	forest.seed = world_seed + 77
	forest.noise_type = FastNoiseLite.TYPE_SIMPLEX
	forest.frequency = 0.035
	forest.fractal_type = FastNoiseLite.FRACTAL_FBM
	forest.fractal_octaves = 2
	var detail := FastNoiseLite.new()
	detail.seed = world_seed + 154
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail.frequency = 0.6
	return {"elevation": elevation, "forest": forest, "detail": detail}

## The ground and its dressing for one cell:
## {"base": tile key, "decor": tile key or ""}.
static func terrain_for_cell(cell: Vector2i, noise_set: Dictionary) -> Dictionary:
	var elevation := (noise_set.get("elevation") as FastNoiseLite).get_noise_2d(float(cell.x), float(cell.y))
	var forest := (noise_set.get("forest") as FastNoiseLite).get_noise_2d(float(cell.x), float(cell.y))
	var detail := (noise_set.get("detail") as FastNoiseLite).get_noise_2d(float(cell.x), float(cell.y))
	# Dry barrens fill the lowlands.
	if elevation < -0.36:
		return {"base": "sand_pebbles" if detail > 0.3 else "sand", "decor": ""}
	if elevation < -0.3:
		return {"base": "sand_alt" if detail > 0.0 else "sand", "decor": ""}
	# Grassland, shaded darker under heavy canopy.
	var base := "grass"
	if forest > 0.2:
		base = "grass_dark"
	elif detail > 0.42:
		base = "grass_tuft"
	elif detail < -0.52:
		base = "flowers_white" if cell.x % 2 == 0 else "flowers_yellow"
	var decor := ""
	if forest > 0.16:
		# Forests thicken toward their heart; the detail noise scatters
		# the individual trunks so edges stay ragged.
		var tree_bias := clampf((forest - 0.16) * 2.4, 0.0, 0.82)
		if detail > 0.7 - tree_bias:
			decor = "tree_dark" if forest > 0.4 else "tree"
	elif forest < -0.42 and detail > 0.55:
		decor = "hedge" if detail < 0.72 else "hedge_alt"
	return {"base": base, "decor": decor}

static func chunk_for_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(int(floor(float(cell.x) / CHUNK_SIZE)), int(floor(float(cell.y) / CHUNK_SIZE)))

static func chunk_rect(chunk: Vector2i) -> Rect2i:
	return Rect2i(chunk * CHUNK_SIZE, Vector2i(CHUNK_SIZE, CHUNK_SIZE))
