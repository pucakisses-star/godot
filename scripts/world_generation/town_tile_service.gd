extends RefCounted
class_name TownTileService

## Tile selection for above-ground human town interiors. Mirrors the
## DwarfHoldTileService API, but reinterprets the shared zone grid for the
## surface: open ground renders as grass instead of void rock, streets as
## dirt roads, the market square as cobbles, and building edges as timber
## walls instead of stone.

const CELL_ROCK := 0
const CELL_HALL := 1
const CELL_HOUSE := 2
const CELL_BUILDING := 3
const CELL_PLAZA := 4

const TOWN_FURNITURE_TILES: Array[String] = [
	"bed", "bed_alt", "chest", "wardrobe", "dresser", "shelf", "table",
	"bench", "counter", "stall", "stall_alt", "barrel", "barrel_open",
	"pot", "jug", "sack", "bucket", "plant", "plant_tall", "flowers_pot",
	"brazier", "armor_stand", "forge", "oven"
]

## Deterministic per-cell hash so ground variety is stable for a seed.
static func _cell_hash(x: int, y: int) -> int:
	var value := x * 73856093 ^ y * 19349663
	if value < 0:
		value = -value
	return value

static func pick_base_tile(grid: Dictionary, x: int, y: int, cell: int, door_cells: Dictionary) -> String:
	if _is_structural_cell(cell):
		return wall_or_floor_tile(grid, x, y, cell, door_cells)
	match cell:
		CELL_HALL:
			return "road" if _cell_hash(x, y) % 11 != 0 else "road_twig"
		CELL_PLAZA:
			return "plaza" if _cell_hash(x, y) % 5 != 0 else "plaza_alt"
		_:
			var roll := _cell_hash(x, y) % 23
			if roll == 0:
				return "grass_dark"
			if roll == 1 or roll == 2:
				return "grass_tuft"
			return "grass"

static func wall_or_floor_tile(grid: Dictionary, x: int, y: int, cell: int, door_cells: Dictionary) -> String:
	var current_cell := Vector2i(x, y)
	if door_cells.has(current_cell):
		return "door"

	var left_cell := _cell_at(grid, x - 1, y)
	var right_cell := _cell_at(grid, x + 1, y)
	var top_cell := _cell_at(grid, x, y - 1)
	var bottom_cell := _cell_at(grid, x, y + 1)
	if left_cell != cell or right_cell != cell or top_cell != cell or bottom_cell != cell:
		# North walls show their timber face into the room (the interior
		# lies below them); the rest read as wall tops.
		if bottom_cell == cell and top_cell != cell:
			return "plank_wall"
		return "wall"
	return "floor"

static func is_furniture_tile(tile_key: String) -> bool:
	return tile_key in TOWN_FURNITURE_TILES

static func pick_building_decor_tile(cell: Vector2i, building_type_map: Dictionary, building_types: Dictionary, rng: RandomNumberGenerator) -> String:
	var building_type := String(building_type_map.get(cell, "workshop"))
	var building_definition := building_types.get(building_type, building_types.values()[0]) as Dictionary
	var decor_pool := PackedStringArray(building_definition.get("decor_tile_pool", ["barrel", "sack", "table"]))
	if decor_pool.is_empty():
		return ""
	return String(decor_pool[rng.randi_range(0, decor_pool.size() - 1)])

static func pick_decor_tile(grid: Dictionary, x: int, y: int, cell: int, base_tile: String, house_decor_overrides: Dictionary, building_type_map: Dictionary, building_types: Dictionary, rng: RandomNumberGenerator, door_cells: Dictionary) -> String:
	var key := Vector2i(x, y)
	if house_decor_overrides.has(key):
		var house_tile := String(house_decor_overrides[key])
		if is_furniture_tile(house_tile) and base_tile != "floor" and base_tile != "rug":
			return ""
		return house_tile

	if cell == CELL_ROCK:
		return _pick_green_scatter_tile(grid, x, y, rng)

	if _is_corridor_cell(cell):
		return ""

	if _is_structural_cell(cell):
		if _is_corridor_cell(_cell_at(grid, x - 1, y)) or _is_corridor_cell(_cell_at(grid, x + 1, y)) or _is_corridor_cell(_cell_at(grid, x, y - 1)) or _is_corridor_cell(_cell_at(grid, x, y + 1)):
			return ""
		if _is_adjacent_to_door(key, door_cells):
			return ""
		if rng.randf() > 0.09:
			return ""
		if cell == CELL_HOUSE:
			var house_random_tile: String = String(["chest", "pot", "plant", "sack", "bench"][rng.randi_range(0, 4)])
			if base_tile != "floor":
				return ""
			return house_random_tile
		if cell == CELL_BUILDING:
			var building_tile := pick_building_decor_tile(Vector2i(x, y), building_type_map, building_types, rng)
			if is_furniture_tile(building_tile) and base_tile != "floor":
				return ""
			return building_tile
		return ""
	return ""

## Trees, hedges and flowers scattered over open grass, thinning out next
## to streets so road edges stay readable.
static func _pick_green_scatter_tile(grid: Dictionary, x: int, y: int, rng: RandomNumberGenerator) -> String:
	var next_to_street := false
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor_cell := _cell_at(grid, x + direction.x, y + direction.y)
		if neighbor_cell != CELL_ROCK:
			next_to_street = true
			break
	var roll := rng.randf()
	if next_to_street:
		if roll < 0.03:
			return "flowers_white" if rng.randf() < 0.5 else "flowers_yellow"
		return ""
	if roll < 0.045:
		return "tree" if rng.randf() < 0.6 else "tree_dark"
	if roll < 0.075:
		return "hedge" if rng.randf() < 0.5 else "hedge_alt"
	if roll < 0.11:
		return "flowers_white" if rng.randf() < 0.5 else "flowers_yellow"
	return ""

static func tile_name_from_atlas(atlas_coords: Vector2i, tile_atlas: Dictionary) -> String:
	for tile_key: String in tile_atlas.keys():
		if tile_atlas[tile_key] == atlas_coords:
			return tile_key.replace("_", " ").capitalize()
	return "Unknown"

static func zone_name_for_cell(cell: Vector2i, grid: Dictionary, building_type_map: Dictionary) -> String:
	if grid.is_empty():
		return "Unknown"

	var zone := _cell_at(grid, cell.x, cell.y)
	match zone:
		CELL_HALL:
			return "Street"
		CELL_PLAZA:
			return "Market Square"
		CELL_HOUSE:
			return "House"
		CELL_BUILDING:
			var subtype := building_type_for_cell_or_empty(cell, building_type_map)
			if subtype.is_empty():
				return "Building"
			return "Building (%s)" % display_name_for_building_type(subtype)
		_:
			return "Green"

static func building_type_for_cell_or_empty(cell: Vector2i, building_type_map: Dictionary) -> String:
	if not building_type_map.has(cell):
		return ""
	return String(building_type_map[cell])

static func display_name_for_building_type(building_type: String) -> String:
	var words := building_type.split("_", false)
	for i in range(words.size()):
		words[i] = String(words[i]).capitalize()
	return " ".join(words)

static func building_subtype_summary_text(buildings_by_id: Dictionary) -> String:
	if buildings_by_id.is_empty():
		return ""

	var subtype_counts: Dictionary = {}
	for building_id: String in buildings_by_id.keys():
		var payload := buildings_by_id[building_id] as Dictionary
		var subtype := String(payload.get("type", "workshop"))
		subtype_counts[subtype] = int(subtype_counts.get(subtype, 0)) + 1

	var sorted_subtypes := subtype_counts.keys()
	sorted_subtypes.sort_custom(func(a: Variant, b: Variant) -> bool:
		return String(a) < String(b)
	)

	var entries: PackedStringArray = []
	for subtype_variant: Variant in sorted_subtypes:
		var subtype := String(subtype_variant)
		entries.append("%s: %d" % [display_name_for_building_type(subtype), int(subtype_counts[subtype])])
	return ", ".join(entries)

## Residence decor: houses get a bedroom template, dormitories bunk rows,
## barracks bed rows with armor stands — same shapes as the dwarfhold
## templates, re-pointed at town tile keys.
static func build_house_decor_layouts(grid: Dictionary, residence_type_map: Dictionary = {}, door_cells: Dictionary = {}) -> Dictionary:
	var visited: Dictionary = {}
	var overrides: Dictionary = {}
	for key: Variant in grid.keys():
		var start_cell := key as Vector2i
		if _cell_at(grid, start_cell.x, start_cell.y) != CELL_HOUSE:
			continue
		if visited.has(start_cell):
			continue

		var queue: Array[Vector2i] = [start_cell]
		var component: Array[Vector2i] = []
		visited[start_cell] = true
		var head := 0
		while head < queue.size():
			var current: Vector2i = queue[head]
			head += 1
			component.append(current)
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor: Vector2i = current + direction
				if visited.has(neighbor):
					continue
				if _cell_at(grid, neighbor.x, neighbor.y) != CELL_HOUSE:
					continue
				visited[neighbor] = true
				queue.append(neighbor)

		if component.is_empty():
			continue
		place_house_decor_template(component, overrides, _component_residence_type(component, residence_type_map), door_cells)

	return overrides

## Furniture next to a doorway would seal the room (furniture blocks
## movement), so bunk rows and armor stands keep clear of doors.
static func _is_adjacent_to_door(cell: Vector2i, door_cells: Dictionary) -> bool:
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if door_cells.has(cell + direction):
			return true
	return false

static func _component_residence_type(component: Array[Vector2i], residence_type_map: Dictionary) -> String:
	if residence_type_map.is_empty():
		return "house"
	var counts: Dictionary = {}
	for cell: Vector2i in component:
		var residence_type := String(residence_type_map.get(cell, ""))
		if residence_type.is_empty():
			continue
		counts[residence_type] = int(counts.get(residence_type, 0)) + 1
	var best_type := "house"
	var best_count := 0
	for type_name: String in counts.keys():
		if int(counts[type_name]) > best_count:
			best_count = int(counts[type_name])
			best_type = type_name
	return best_type

static func place_house_decor_template(component: Array[Vector2i], overrides: Dictionary, residence_type: String = "house", door_cells: Dictionary = {}) -> void:
	var occupied: Dictionary = {}
	for cell: Vector2i in component:
		occupied[cell] = true

	var min_x := component[0].x
	var max_x := component[0].x
	var min_y := component[0].y
	var max_y := component[0].y
	for cell: Vector2i in component:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)

	if residence_type == "dormitory":
		_place_dormitory_decor(component, occupied, overrides, min_x, min_y, max_x, max_y, door_cells)
		return
	if residence_type == "barracks":
		_place_barracks_decor(component, occupied, overrides, min_x, min_y, max_x, max_y, door_cells)
		return

	_try_assign_clear_decor(overrides, occupied, Vector2i(min_x + 1, min_y + 1), "chest", door_cells)
	_try_assign_clear_decor(overrides, occupied, Vector2i(min_x + 2, min_y + 1), "bed", door_cells)
	_try_assign_clear_decor(overrides, occupied, Vector2i(max_x - 1, min_y + 1), "wardrobe", door_cells)
	_try_assign_clear_decor(overrides, occupied, Vector2i((min_x + max_x) / 2, (min_y + max_y) / 2), "table", door_cells)
	_try_assign_clear_decor(overrides, occupied, Vector2i((min_x + max_x) / 2 - 1, (min_y + max_y) / 2), "bench", door_cells)
	_try_assign_clear_decor(overrides, occupied, Vector2i(max_x - 1, max_y - 1), "plant", door_cells)
	ensure_house_has_bed(component, overrides, door_cells)

static func _place_dormitory_decor(component: Array[Vector2i], occupied: Dictionary, overrides: Dictionary, min_x: int, min_y: int, max_x: int, max_y: int, door_cells: Dictionary = {}) -> void:
	for cell: Vector2i in component:
		if (cell.x - min_x) % 2 == 1 and (cell.y - min_y) % 2 == 1:
			if _is_adjacent_to_door(cell, door_cells):
				continue
			_try_assign_decor(overrides, occupied, cell, "bed")
	_try_assign_decor(overrides, occupied, Vector2i(min_x, min_y), "chest")
	_try_assign_decor(overrides, occupied, Vector2i(max_x, min_y), "wardrobe")
	_try_assign_decor(overrides, occupied, Vector2i((min_x + max_x) / 2, max_y), "bucket")
	ensure_house_has_bed(component, overrides, door_cells)

static func _place_barracks_decor(component: Array[Vector2i], occupied: Dictionary, overrides: Dictionary, min_x: int, min_y: int, max_x: int, max_y: int, door_cells: Dictionary = {}) -> void:
	for cell: Vector2i in component:
		var local_x := cell.x - min_x
		var local_y := cell.y - min_y
		if _is_adjacent_to_door(cell, door_cells):
			continue
		if local_x % 2 == 1 and local_y % 3 == 1:
			_try_assign_decor(overrides, occupied, cell, "bed_alt")
		elif local_y % 3 == 0 and local_x % 4 == 2:
			_try_assign_decor(overrides, occupied, cell, "armor_stand")
	_try_assign_decor(overrides, occupied, Vector2i(min_x, min_y), "chest")
	ensure_house_has_bed(component, overrides, door_cells)

static func ensure_house_has_bed(component: Array[Vector2i], overrides: Dictionary, door_cells: Dictionary = {}) -> void:
	for cell: Vector2i in component:
		var assigned := String(overrides.get(cell, ""))
		if assigned == "bed" or assigned == "bed_alt":
			return

	var fallback_bed_cell := component[0]
	var found_clear_cell := false
	for cell: Vector2i in component:
		if overrides.has(cell):
			continue
		if _is_adjacent_to_door(cell, door_cells):
			continue
		fallback_bed_cell = cell
		found_clear_cell = true
		break
	if not found_clear_cell:
		for cell: Vector2i in component:
			if not overrides.has(cell):
				fallback_bed_cell = cell
				break
	overrides[fallback_bed_cell] = "bed"

static func _try_assign_decor(overrides: Dictionary, occupied: Dictionary, cell: Vector2i, tile_key: String) -> void:
	if not occupied.has(cell):
		return
	if overrides.has(cell):
		return
	overrides[cell] = tile_key

static func _try_assign_clear_decor(overrides: Dictionary, occupied: Dictionary, cell: Vector2i, tile_key: String, door_cells: Dictionary) -> void:
	if _is_adjacent_to_door(cell, door_cells):
		return
	_try_assign_decor(overrides, occupied, cell, tile_key)

static func _cell_at(grid: Dictionary, x: int, y: int) -> int:
	return int(grid.get(Vector2i(x, y), CELL_ROCK))

static func _is_corridor_cell(cell: int) -> bool:
	return cell == CELL_HALL or cell == CELL_PLAZA

static func _is_structural_cell(cell: int) -> bool:
	return cell == CELL_HOUSE or cell == CELL_BUILDING
