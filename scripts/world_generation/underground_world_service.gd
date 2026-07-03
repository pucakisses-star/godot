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
const CELL_HOUSE := 2
const CELL_BUILDING := 3
const CELL_PLAZA := 4

## Overworld tiles project into the underground at this many cells per
## overworld tile, so the whole surface map exists as one continuous
## underdeep you can walk or dig across.
const CELLS_PER_OVERWORLD_TILE := 12

## Per-chunk chance (percent) of a wild discovery in the rock.
const DISCOVERY_CHANCE_PERCENT := 5

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

## Wild discoveries: rolled deterministically per chunk. Returns a label
## dictionary ({"name", "center"}) or {} when the chunk has none.
static func stamp_chunk_discovery(grid: Dictionary, floor_decor: Dictionary, chunk: Vector2i, world_seed: int) -> Dictionary:
	var roll_hash := _cell_hash(chunk.x * 3 + world_seed, chunk.y * 7 - world_seed)
	if roll_hash % 100 >= DISCOVERY_CHANCE_PERCENT:
		return {}
	# Keep discoveries out of the city's home chunks.
	if absi(chunk.x) < 4 and absi(chunk.y) < 4:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = roll_hash
	var center := chunk * CHUNK_SIZE + Vector2i(CHUNK_SIZE / 2, CHUNK_SIZE / 2) + Vector2i(rng.randi_range(-4, 4), rng.randi_range(-4, 4))
	match roll_hash % 3:
		0:
			_stamp_ruin(grid, floor_decor, center, rng)
			return {"name": "Ancient Ruin", "center": center}
		1:
			_stamp_camp(grid, floor_decor, center, rng)
			return {"name": "Abandoned Camp", "center": center}
		_:
			_stamp_ore_cavern(grid, floor_decor, center, rng)
			return {"name": "Ore Cavern", "center": center}

static func _stamp_ruin(grid: Dictionary, floor_decor: Dictionary, center: Vector2i, rng: RandomNumberGenerator) -> void:
	for room_index in range(rng.randi_range(2, 3)):
		var room_center := center + Vector2i(rng.randi_range(-5, 5), rng.randi_range(-4, 4))
		var radius := Vector2i(rng.randi_range(2, 3), rng.randi_range(2, 3))
		_carve_ellipse_hall(grid, room_center, radius)
	floor_decor[center] = "chest"
	for _rubble in range(rng.randi_range(2, 4)):
		var rubble_cell := center + Vector2i(rng.randi_range(-4, 4), rng.randi_range(-3, 3))
		if not floor_decor.has(rubble_cell):
			floor_decor[rubble_cell] = "stone"

static func _stamp_camp(grid: Dictionary, floor_decor: Dictionary, center: Vector2i, rng: RandomNumberGenerator) -> void:
	_carve_ellipse_hall(grid, center, Vector2i(rng.randi_range(4, 5), rng.randi_range(3, 4)))
	floor_decor[center] = "keg"
	floor_decor[center + Vector2i(1, 0)] = "table"
	floor_decor[center + Vector2i(-1, 1)] = "chest"

static func _stamp_ore_cavern(grid: Dictionary, floor_decor: Dictionary, center: Vector2i, rng: RandomNumberGenerator) -> void:
	_carve_ellipse_hall(grid, center, Vector2i(rng.randi_range(5, 7), rng.randi_range(4, 5)))
	for _vein in range(rng.randi_range(8, 14)):
		var vein_cell := center + Vector2i(rng.randi_range(-6, 6), rng.randi_range(-4, 4))
		if int(grid.get(vein_cell, CELL_ROCK)) == CELL_HALL and not floor_decor.has(vein_cell):
			floor_decor[vein_cell] = "stone"

## Projects an overworld settlement into the underdeep as a carved site.
## site: {"name": String, "type": String, "cell": Vector2i}
static func stamp_settlement_site(grid: Dictionary, floor_decor: Dictionary, site: Dictionary) -> void:
	var center := site.get("cell", Vector2i.ZERO) as Vector2i
	var site_type := String(site.get("type", "town"))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(site.get("name", "site")))
	var is_hold := site_type.contains("dwarfhold") or site_type == "hillhold"
	var cavern_radius := Vector2i(10, 8) if is_hold else Vector2i(8, 6)
	for disk_index in range(6):
		var disk_center := center + Vector2i(rng.randi_range(-4, 4), rng.randi_range(-3, 3))
		_carve_ellipse_hall(grid, disk_center, Vector2i(maxi(3, cavern_radius.x - rng.randi_range(0, 4)), maxi(3, cavern_radius.y - rng.randi_range(0, 3))))
	if is_hold:
		_carve_ellipse(grid, center, Vector2i(3, 2), CELL_PLAZA)
	var house_count := rng.randi_range(4, 7) if not is_hold else rng.randi_range(6, 9)
	for _house in range(house_count):
		var house_center := center + Vector2i(rng.randi_range(-cavern_radius.x + 2, cavern_radius.x - 2), rng.randi_range(-cavern_radius.y + 2, cavern_radius.y - 2))
		_stamp_site_house(grid, floor_decor, house_center, rng)

static func _stamp_site_house(grid: Dictionary, floor_decor: Dictionary, center: Vector2i, rng: RandomNumberGenerator) -> void:
	var footprint := Vector2i(2, 2)
	var lo := center - footprint
	var hi := center + footprint
	for y in range(lo.y - 1, hi.y + 2):
		for x in range(lo.x - 1, hi.x + 2):
			var cell := Vector2i(x, y)
			var existing := int(grid.get(cell, CELL_ROCK))
			var inside := x >= lo.x and x <= hi.x and y >= lo.y and y <= hi.y
			if inside and existing != CELL_HALL:
				return
			if not inside and (existing == CELL_HOUSE or existing == CELL_BUILDING):
				return
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			grid[Vector2i(x, y)] = CELL_HOUSE
	# Carve a doorway and furnish the single room.
	var door_side := rng.randi_range(0, 3)
	var door_cell := Vector2i(center.x, lo.y) if door_side == 0 else Vector2i(center.x, hi.y) if door_side == 1 else Vector2i(lo.x, center.y) if door_side == 2 else Vector2i(hi.x, center.y)
	grid[door_cell] = CELL_HALL
	if not floor_decor.has(center):
		floor_decor[center] = "bed"
	var chest_cell := center + Vector2i(1, 1)
	if not floor_decor.has(chest_cell):
		floor_decor[chest_cell] = "chest"

static func _carve_ellipse_hall(grid: Dictionary, center: Vector2i, radius: Vector2i) -> void:
	_carve_ellipse(grid, center, radius, CELL_HALL)

static func _carve_ellipse(grid: Dictionary, center: Vector2i, radius: Vector2i, tile: int) -> void:
	for y in range(center.y - radius.y, center.y + radius.y + 1):
		for x in range(center.x - radius.x, center.x + radius.x + 1):
			var dx := float(x - center.x) / maxf(float(radius.x), 0.001)
			var dy := float(y - center.y) / maxf(float(radius.y), 0.001)
			if dx * dx + dy * dy <= 1.0:
				var cell := Vector2i(x, y)
				var existing := int(grid.get(cell, CELL_ROCK))
				if existing == CELL_ROCK or (tile == CELL_PLAZA and existing == CELL_HALL):
					grid[cell] = tile

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
