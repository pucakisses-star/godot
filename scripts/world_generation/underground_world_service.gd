extends RefCounted
class_name UndergroundWorldService

## Core-Keeper-style open underground: beyond the hold's carved districts
## the world is unbounded rock, generated in deterministic chunks as the
## player explores. Seamless simplex noise carves natural cave pockets,
## a low-frequency biome noise paints fungal caverns, and a vein noise
## scatters minable rubble. Already-carved cells (the city, tunnels, or
## the player's own digging) are never overwritten.

const CHUNK_SIZE := 24

const CELL_ROCK := 0
const CELL_HALL := 1

const CAVE_THRESHOLD := 0.34
const FUNGAL_THRESHOLD := 0.45
const RUBBLE_THRESHOLD := 0.52

static func make_noise_set(world_seed: int) -> Dictionary:
	var caves := FastNoiseLite.new()
	caves.noise_type = FastNoiseLite.TYPE_SIMPLEX
	caves.seed = world_seed
	caves.frequency = 0.055

	var fungal := FastNoiseLite.new()
	fungal.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fungal.seed = world_seed + 101
	fungal.frequency = 0.012

	var rubble := FastNoiseLite.new()
	rubble.noise_type = FastNoiseLite.TYPE_SIMPLEX
	rubble.seed = world_seed + 202
	rubble.frequency = 0.09

	return {"caves": caves, "fungal": fungal, "rubble": rubble}

## Carves one chunk into the shared grid. Returns the chunk's cell rect so
## the caller can render it. Existing grid cells are left untouched.
static func generate_chunk(grid: Dictionary, floor_decor: Dictionary, chunk: Vector2i, noise_set: Dictionary) -> Rect2i:
	var caves := noise_set.get("caves") as FastNoiseLite
	var fungal := noise_set.get("fungal") as FastNoiseLite
	var rubble := noise_set.get("rubble") as FastNoiseLite
	var origin := chunk * CHUNK_SIZE
	for y in range(origin.y, origin.y + CHUNK_SIZE):
		for x in range(origin.x, origin.x + CHUNK_SIZE):
			var cell := Vector2i(x, y)
			if grid.has(cell):
				continue
			var cave_value := caves.get_noise_2d(float(x), float(y))
			if cave_value <= CAVE_THRESHOLD:
				continue
			grid[cell] = CELL_HALL
			if floor_decor.has(cell):
				continue
			var fungal_value := fungal.get_noise_2d(float(x), float(y))
			if fungal_value > FUNGAL_THRESHOLD:
				var fungal_pick := _cell_hash(x, y) % 10
				if fungal_pick < 4:
					floor_decor[cell] = "mushroom_wild" if fungal_pick % 2 == 0 else "mushroom_crop_wild"
				continue
			var rubble_value := rubble.get_noise_2d(float(x), float(y))
			if rubble_value > RUBBLE_THRESHOLD and _cell_hash(x, y) % 5 == 0:
				floor_decor[cell] = "stone"
	return Rect2i(origin, Vector2i(CHUNK_SIZE, CHUNK_SIZE))

static func chunk_for_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(
		int(floor(float(cell.x) / float(CHUNK_SIZE))),
		int(floor(float(cell.y) / float(CHUNK_SIZE)))
	)

static func chunk_key(chunk: Vector2i) -> String:
	return "%d,%d" % [chunk.x, chunk.y]

static func _cell_hash(x: int, y: int) -> int:
	var value := x * 73856093 ^ y * 19349663
	if value < 0:
		value = -value
	return value
