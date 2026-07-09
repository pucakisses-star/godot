extends RefCounted
class_name DwarfHoldTileService

const CELL_ROCK := 0
const CELL_HALL := 1
const CELL_HOUSE := 2
const CELL_BUILDING := 3
const CELL_PLAZA := 4

static func place_tile(target_layer: TileMapLayer, cell: Vector2i, tile_key: String, tile_atlas: Dictionary) -> void:
	var atlas_coords: Vector2i = tile_atlas.get(tile_key, Vector2i(-1, -1))
	if atlas_coords.x < 0:
		return
	target_layer.set_cell(cell, 0, atlas_coords, 0)

static func pick_base_tile(grid: Dictionary, x: int, y: int, cell: int, door_cells: Dictionary, tile_atlas: Dictionary) -> String:
	if _is_structural_cell(cell):
		return wall_or_floor_tile(grid, x, y, cell, door_cells)
	match cell:
		CELL_HALL:
			return "dirt"
		CELL_PLAZA:
			return "floor"
		CELL_ROCK:
			if is_hall_border_rock_cell(grid, x, y):
				return "stone"
			return ""
		_:
			return "stone"

static func is_hall_border_rock_cell(grid: Dictionary, x: int, y: int) -> bool:
	if _cell_at(grid, x, y) != CELL_ROCK:
		return false
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor := Vector2i(x, y) + direction
		if _is_corridor_cell(_cell_at(grid, neighbor.x, neighbor.y)):
			return true
	return false

static func wall_or_floor_tile(grid: Dictionary, x: int, y: int, cell: int, door_cells: Dictionary) -> String:
	var current_cell := Vector2i(x, y)
	if door_cells.has(current_cell):
		return "door"

	var left_cell := _cell_at(grid, x - 1, y)
	var right_cell := _cell_at(grid, x + 1, y)
	var top_cell := _cell_at(grid, x, y - 1)
	var bottom_cell := _cell_at(grid, x, y + 1)
	var left_open := _is_corridor_cell(left_cell)
	var right_open := _is_corridor_cell(right_cell)
	var top_open := _is_corridor_cell(top_cell)
	var bottom_open := _is_corridor_cell(bottom_cell)
	var left_same := left_cell == cell
	var right_same := right_cell == cell
	var top_same := top_cell == cell
	var bottom_same := bottom_cell == cell

	if left_open:
		return "stone"
	if right_open:
		return "stone"
	if top_open or not top_same:
		return "stone"
	if bottom_open or not bottom_same:
		return "stone"
	if not left_same:
		return "stone"
	if not right_same:
		return "stone"

	return "floor"

static func is_furniture_tile(tile_key: String) -> bool:
	return tile_key in [
		"bed", "chest", "wardrobe", "stool", "mug",
		"workbench", "desk", "anvil", "shelf", "armor_stand", "winepress", "butcher_table", "flour",
		"table", "table_alt", "keg", "target", "water_bucket", "grain_bag"
	]

static func pick_civic_building_decor_tile(cell: Vector2i, civic_building_type_map: Dictionary, civic_building_types: Dictionary, rng: RandomNumberGenerator) -> String:
	var building_type := String(civic_building_type_map.get(cell, "workshop"))
	var civic_definition := civic_building_types.get(building_type, civic_building_types["workshop"]) as Dictionary
	var decor_pool := PackedStringArray(civic_definition.get("decor_tile_pool", ["workbench", "desk", "anvil"]))
	if decor_pool.is_empty():
		return ""
	return String(decor_pool[rng.randi_range(0, decor_pool.size() - 1)])

static func pick_decor_tile(grid: Dictionary, x: int, y: int, cell: int, base_tile: String, house_decor_overrides: Dictionary, civic_building_type_map: Dictionary, civic_building_types: Dictionary, rng: RandomNumberGenerator, door_cells: Dictionary) -> String:
	var key := Vector2i(x, y)
	if house_decor_overrides.has(key):
		var house_tile := String(house_decor_overrides[key])
		if is_furniture_tile(house_tile) and base_tile != "floor":
			return ""
		if (house_tile == "wardrobe" or house_tile == "shelf") and not is_adjacent_to_stone_or_wall(grid, x, y, door_cells):
			return ""
		return house_tile

	if _is_corridor_cell(cell):
		if rng.randf() < 0.015:
			if not is_adjacent_to_business(grid, x, y):
				return ""
			var corridor_tile := "sign"
			if is_furniture_tile(corridor_tile) and base_tile != "floor":
				return ""
			return corridor_tile
		return ""
	if _is_structural_cell(cell):
		if _is_corridor_cell(_cell_at(grid, x - 1, y)) or _is_corridor_cell(_cell_at(grid, x + 1, y)) or _is_corridor_cell(_cell_at(grid, x, y - 1)) or _is_corridor_cell(_cell_at(grid, x, y + 1)):
			return ""
		if is_adjacent_to_door(key, door_cells):
			return ""
		if rng.randf() > 0.09:
			return ""
		if cell == CELL_HOUSE:
			var house_random_tile: String = String(["bed", "chest", "wardrobe", "stool", "mug"][rng.randi_range(0, 4)])
			if is_furniture_tile(house_random_tile) and base_tile != "floor":
				return ""
			if house_random_tile == "wardrobe" and not is_adjacent_to_stone_or_wall(grid, x, y, door_cells):
				return ""
			return house_random_tile
		if cell == CELL_BUILDING:
			var building_tile := pick_civic_building_decor_tile(Vector2i(x, y), civic_building_type_map, civic_building_types, rng)
			if is_furniture_tile(building_tile) and base_tile != "floor":
				return ""
			if building_tile == "shelf" and not is_adjacent_to_stone_or_wall(grid, x, y, door_cells):
				return ""
			return building_tile
		var default_tile: String = String(["table", "mug", "water_bucket"][rng.randi_range(0, 2)])
		if is_furniture_tile(default_tile) and base_tile != "floor":
			return ""
		return default_tile
	return ""

static func is_adjacent_to_business(grid: Dictionary, x: int, y: int) -> bool:
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor := Vector2i(x, y) + direction
		if _cell_at(grid, neighbor.x, neighbor.y) == CELL_BUILDING:
			return true
	return false

static func is_adjacent_to_stone_or_wall(grid: Dictionary, x: int, y: int, door_cells: Dictionary) -> bool:
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor := Vector2i(x, y) + direction
		var neighbor_cell := _cell_at(grid, neighbor.x, neighbor.y)
		if neighbor_cell == CELL_ROCK:
			return true
		if _is_structural_cell(neighbor_cell) and wall_or_floor_tile(grid, neighbor.x, neighbor.y, neighbor_cell, door_cells) == "stone":
			return true
	return false

static func tile_name_from_atlas(atlas_coords: Vector2i, tile_atlas: Dictionary) -> String:
	for tile_key: String in tile_atlas.keys():
		if tile_atlas[tile_key] == atlas_coords:
			return tile_key.replace("_", " ").capitalize()
	return "Unknown"

static func zone_name_for_cell(cell: Vector2i, grid: Dictionary, civic_building_type_map: Dictionary) -> String:
	if grid.is_empty():
		return "Unknown"

	var zone := _cell_at(grid, cell.x, cell.y)
	match zone:
		CELL_HALL:
			return "Hall"
		CELL_PLAZA:
			return "Plaza"
		CELL_HOUSE:
			return "House"
		CELL_BUILDING:
			var subtype := building_type_for_cell_or_empty(cell, civic_building_type_map)
			if subtype.is_empty():
				return "Building"
			return "Building (%s)" % display_name_for_building_type(subtype)
		_:
			return "Rock"

static func building_type_for_cell_or_empty(cell: Vector2i, civic_building_type_map: Dictionary) -> String:
	if not civic_building_type_map.has(cell):
		return ""
	return String(civic_building_type_map[cell])

static func display_name_for_building_type(building_type: String) -> String:
	var words := building_type.split("_", false)
	for i in range(words.size()):
		words[i] = String(words[i]).capitalize()
	return " ".join(words)

static func building_subtype_summary_text(civic_buildings_by_id: Dictionary) -> String:
	if civic_buildings_by_id.is_empty():
		return ""

	var subtype_counts: Dictionary = {}
	for building_id: String in civic_buildings_by_id.keys():
		var payload := civic_buildings_by_id[building_id] as Dictionary
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

## Residence components carry their type from placement; merged components
## resolve by majority vote and default to a plain house.
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
		place_dormitory_decor(component, occupied, overrides, min_x, min_y, max_x, max_y, door_cells)
		return
	if residence_type == "barracks":
		place_barracks_decor(component, occupied, overrides, min_x, min_y, max_x, max_y, door_cells)
		return

	var top_left_chest := Vector2i(min_x + 1, min_y + 1)
	var top_left_bed := Vector2i(min_x + 2, min_y + 1)
	var top_right_wardrobe := find_wall_adjacent_cell(component, occupied, overrides, Vector2i(max_x - 1, min_y + 1))
	var center_table := Vector2i((min_x + max_x) / 2, (min_y + max_y) / 2)
	var stool_a := center_table + Vector2i(-1, 0)
	var stool_b := center_table + Vector2i(0, -1)

	try_assign_clear_house_decor(overrides, occupied, top_left_chest, "chest", door_cells)
	try_assign_clear_house_decor(overrides, occupied, top_left_bed, "bed", door_cells)
	try_assign_clear_house_decor(overrides, occupied, top_right_wardrobe, "wardrobe", door_cells)
	try_assign_clear_house_decor(overrides, occupied, center_table, "table", door_cells)
	try_assign_clear_house_decor(overrides, occupied, stool_a, "stool", door_cells)
	try_assign_clear_house_decor(overrides, occupied, stool_b, "stool", door_cells)
	ensure_house_has_bed(component, overrides, door_cells)

## Dormitories pack bunks on alternating cells (a bed at every odd local
## coordinate) with a chest and wardrobe by the walls — one bed per
## footprint.x * footprint.y placement estimate.
## Targets sit one cell inside the bbox: the bbox edges ARE the wall ring
## for rectangular rooms, and ring cells render as stone, which makes
## pick_decor_tile suppress any furniture assigned there.
static func place_dormitory_decor(component: Array[Vector2i], occupied: Dictionary, overrides: Dictionary, min_x: int, min_y: int, max_x: int, max_y: int, door_cells: Dictionary = {}) -> void:
	try_assign_house_decor(overrides, occupied, Vector2i(min_x + 1, min_y + 1), "chest")
	try_assign_house_decor(overrides, occupied, find_wall_adjacent_cell(component, occupied, overrides, Vector2i(max_x - 1, min_y + 1)), "wardrobe")
	try_assign_house_decor(overrides, occupied, Vector2i((min_x + max_x) / 2, max_y - 1), "water_bucket")
	for cell: Vector2i in component:
		if cell.x <= min_x or cell.x >= max_x or cell.y <= min_y or cell.y >= max_y:
			continue
		if (cell.x - min_x) % 2 == 1 and (cell.y - min_y) % 2 == 1:
			if is_adjacent_to_door(cell, door_cells):
				continue
			try_assign_house_decor(overrides, occupied, cell, "bed")
	ensure_house_has_bed(component, overrides, door_cells)

## Barracks lay a bed row every third rank with armor stands and a training
## target between them.
## Chest and target land one cell inside the bbox for the same reason as
## the dormitory: the bbox corners are wall-ring cells whose stone base
## suppresses furniture.
static func place_barracks_decor(component: Array[Vector2i], occupied: Dictionary, overrides: Dictionary, min_x: int, min_y: int, max_x: int, max_y: int, door_cells: Dictionary = {}) -> void:
	try_assign_house_decor(overrides, occupied, Vector2i(min_x + 1, min_y + 1), "chest")
	try_assign_house_decor(overrides, occupied, Vector2i(max_x - 1, max_y - 1), "target")
	for cell: Vector2i in component:
		if cell.x <= min_x or cell.x >= max_x or cell.y <= min_y or cell.y >= max_y:
			continue
		var local_x := cell.x - min_x
		var local_y := cell.y - min_y
		if is_adjacent_to_door(cell, door_cells):
			continue
		if local_x % 2 == 1 and local_y % 3 == 1:
			try_assign_house_decor(overrides, occupied, cell, "bed")
		elif local_y % 3 == 0 and local_x % 4 == 2:
			try_assign_house_decor(overrides, occupied, cell, "armor_stand")
	ensure_house_has_bed(component, overrides, door_cells)

static func ensure_house_has_bed(component: Array[Vector2i], overrides: Dictionary, door_cells: Dictionary = {}) -> void:
	for cell: Vector2i in component:
		if overrides.get(cell, "") == "bed":
			return

	var fallback_bed_cell := component[0]
	var found_clear_cell := false
	for cell: Vector2i in component:
		if overrides.has(cell):
			continue
		if is_adjacent_to_door(cell, door_cells):
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

## Furniture next to a doorway would seal the room, so bed rows and
## armor stands keep clear of doors.
static func is_adjacent_to_door(cell: Vector2i, door_cells: Dictionary) -> bool:
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if door_cells.has(cell + direction):
			return true
	return false

static func try_assign_house_decor(overrides: Dictionary, occupied: Dictionary, cell: Vector2i, tile_key: String) -> void:
	if not occupied.has(cell):
		return
	if overrides.has(cell):
		return
	overrides[cell] = tile_key

static func try_assign_clear_house_decor(overrides: Dictionary, occupied: Dictionary, cell: Vector2i, tile_key: String, door_cells: Dictionary) -> void:
	if is_adjacent_to_door(cell, door_cells):
		return
	try_assign_house_decor(overrides, occupied, cell, tile_key)

static func find_wall_adjacent_cell(component: Array[Vector2i], occupied: Dictionary, overrides: Dictionary, preferred_cell: Vector2i) -> Vector2i:
	if occupied.has(preferred_cell) and not overrides.has(preferred_cell) and is_component_wall_adjacent(preferred_cell, occupied):
		return preferred_cell
	for cell: Vector2i in component:
		if overrides.has(cell):
			continue
		if is_component_wall_adjacent(cell, occupied):
			return cell
	return preferred_cell

## The component includes its wall ring, and furniture only renders on
## "floor" base tiles (cells fully inside the room). So "wall adjacent"
## must mean an INTERIOR cell (all four neighbours in the component)
## that touches the ring (some neighbour sits on the component edge).
## The old test matched the ring cells themselves, whose stone base
## made pick_decor_tile silently drop the furniture.
static func is_component_wall_adjacent(cell: Vector2i, occupied: Dictionary) -> bool:
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if not occupied.has(cell + direction):
			return false
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor := cell + direction
		for inner_direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not occupied.has(neighbor + inner_direction):
				return true
	return false

# --- internal helpers ---

static func _cell_at(grid: Dictionary, x: int, y: int) -> int:
	return int(grid.get(Vector2i(x, y), CELL_ROCK))

static func _is_structural_cell(cell: int) -> bool:
	return cell == CELL_HOUSE or cell == CELL_BUILDING

static func _is_corridor_cell(cell: int) -> bool:
	return cell == CELL_HALL or cell == CELL_PLAZA
