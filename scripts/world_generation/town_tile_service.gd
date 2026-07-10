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
## Interior partition wall inside a multi-room building (matches
## SettlementSceneBase.CELL_WALL). Renders as timber wall unless a door is
## punched through it, and never counts as room floor.
const CELL_WALL := 6

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
	if cell == CELL_WALL:
		## Interior partitions are timber walls except where a door was
		## punched to connect two rooms. A partition end that crosses the
		## outer ring picks the matching frame piece so the facade reads as
		## one continuous timber shell.
		if door_cells.has(Vector2i(x, y)):
			return "door"
		return _wall_piece_for_sides(
			not _is_building_fabric(_cell_at(grid, x, y - 1)),
			not _is_building_fabric(_cell_at(grid, x, y + 1)),
			not _is_building_fabric(_cell_at(grid, x - 1, y)),
			not _is_building_fabric(_cell_at(grid, x + 1, y))
		)
	if _is_structural_cell(cell):
		return wall_or_floor_tile(grid, x, y, cell, door_cells)
	if cell == CELL_HALL or cell == CELL_PLAZA:
		return pick_path_tile(grid, x, y, cell)
	return pick_grass_tile(x, y)

## Deterministic grass variety: mostly plain green with occasional darker
## patches, tuft clusters and mottled cells so open ground stops reading as
## one endlessly repeated tile. Biome swaps remap every key downstream.
static func pick_grass_tile(x: int, y: int) -> String:
	var roll := _cell_hash(x, y) % 37
	if roll == 0:
		return "grass_dark"
	if roll <= 2:
		return "grass_tuft"
	if roll <= 4:
		return "grass_tuft_alt"
	if roll <= 7:
		return "grass_mottled"
	return "grass"

## Mask-based path autotiling: a lane/plaza cell that borders open grass
## picks the matching grass-fringed edge, convex-corner or inner-corner
## piece, so paths get soft scalloped borders instead of hard square edges.
## Building fabric and doors count as "closed" (paths butt flush against
## walls), and anything outside the grid decodes to CELL_ROCK = grass.
static func pick_path_tile(grid: Dictionary, x: int, y: int, cell: int) -> String:
	var n_open := _cell_at(grid, x, y - 1) == CELL_ROCK
	var s_open := _cell_at(grid, x, y + 1) == CELL_ROCK
	var w_open := _cell_at(grid, x - 1, y) == CELL_ROCK
	var e_open := _cell_at(grid, x + 1, y) == CELL_ROCK
	if n_open and w_open:
		return "road_edge_nw"
	if n_open and e_open:
		return "road_edge_ne"
	if s_open and w_open:
		return "road_edge_sw"
	if s_open and e_open:
		return "road_edge_se"
	if n_open and s_open:
		return "road_edge_n" if _cell_hash(x, y) % 2 == 0 else "road_edge_s"
	if w_open and e_open:
		return "road_edge_w" if _cell_hash(x, y) % 2 == 0 else "road_edge_e"
	if n_open:
		return "road_edge_n"
	if s_open:
		return "road_edge_s"
	if w_open:
		return "road_edge_w"
	if e_open:
		return "road_edge_e"
	# Fully path-flanked: a grass bite at one open diagonal rounds concave
	# corners; otherwise the interior variant pool.
	if _cell_at(grid, x - 1, y - 1) == CELL_ROCK:
		return "road_in_nw"
	if _cell_at(grid, x + 1, y - 1) == CELL_ROCK:
		return "road_in_ne"
	if _cell_at(grid, x - 1, y + 1) == CELL_ROCK:
		return "road_in_sw"
	if _cell_at(grid, x + 1, y + 1) == CELL_ROCK:
		return "road_in_se"
	return pick_path_interior_tile(x, y, cell == CELL_PLAZA)

## The interior (fully surrounded) path variants, hash-weighted.
static func pick_path_interior_tile(x: int, y: int, is_plaza: bool) -> String:
	if is_plaza:
		var plaza_roll := _cell_hash(x, y) % 11
		if plaza_roll == 0:
			return "plaza_alt"
		if plaza_roll == 1 or plaza_roll == 2:
			return "plaza_c"
		if plaza_roll == 3:
			return "plaza_d"
		return "plaza"
	var roll := _cell_hash(x, y) % 13
	if roll == 0:
		return "road_twig"
	if roll == 1 or roll == 2:
		return "road_alt"
	if roll == 3:
		return "road_stone"
	if roll == 4:
		return "road_sprout"
	return "road"

## Connection-aware fence piece: the four flags say which orthogonal
## neighbors are also fence cells. Straight runs rotate through art
## variants by cell hash so long rails stay lively; the isolated case is
## the true lone post.
static func fence_tile_for_connections(north: bool, east: bool, south: bool, west: bool, x: int, y: int) -> String:
	var mask := (1 if north else 0) | (2 if east else 0) | (4 if south else 0) | (8 if west else 0)
	match mask:
		1:
			return "fence_post"
		2:
			return "fence_cap_e"
		3:
			return "fence_ne"
		4:
			return "fence_cap_s"
		5:
			return "fence_ns" if _cell_hash(x, y) % 3 != 0 else "fence_ns_alt"
		6:
			return "fence_se"
		7:
			return "fence_nse"
		8:
			return "fence_cap_w"
		9:
			return "fence_nw"
		10:
			var run_roll := _cell_hash(x, y) % 3
			if run_roll == 0:
				return "fence_we_alt"
			if run_roll == 1:
				return "fence_we_low"
			return "fence_we"
		11:
			return "fence"
		12:
			return "fence_sw"
		13:
			return "fence_nsw"
		14:
			return "fence_wes"
		15:
			return "fence_cross"
	return "fence_post"

## Autotiles a building cell into the timber-framed 9-slice. A perimeter
## cell borders the exterior on at least one side; we read which of its four
## orthogonal sides face outside (a different cell type) and pick the matching
## frame piece so corners, the lit top beam, side posts and the bottom sill
## all line up. Door cells keep their building's grid value, so a wall next to
## a doorway stays "closed" on that side and frames the opening cleanly.
## Cells fully enclosed by the same building are interior floor.
static func wall_or_floor_tile(grid: Dictionary, x: int, y: int, cell: int, door_cells: Dictionary) -> String:
	var current_cell := Vector2i(x, y)
	if door_cells.has(current_cell):
		return "door"

	## A partition wall counts as "same room": floor tiles flanking an
	## interior CELL_WALL line must stay floor, or every room would grow a
	## second timber ring inside the partition and 2x2 interiors would vanish.
	var up_open := not _is_same_room(_cell_at(grid, x, y - 1), cell)
	var down_open := not _is_same_room(_cell_at(grid, x, y + 1), cell)
	var left_open := not _is_same_room(_cell_at(grid, x - 1, y), cell)
	var right_open := not _is_same_room(_cell_at(grid, x + 1, y), cell)

	if not (up_open or down_open or left_open or right_open):
		return "floor"
	return _wall_piece_for_sides(up_open, down_open, left_open, right_open)

## Maps which of a wall cell's four orthogonal sides face outside onto the
## timber-framed 9-slice: convex corners (two adjacent open sides) first,
## then the four straight edges; a fully-enclosed wall cell is the opaque
## fill piece (interior partitions).
static func _wall_piece_for_sides(up_open: bool, down_open: bool, left_open: bool, right_open: bool) -> String:
	if up_open and left_open:
		return "wall_tl"
	if up_open and right_open:
		return "wall_tr"
	if down_open and left_open:
		return "wall_bl"
	if down_open and right_open:
		return "wall_br"
	if up_open:
		return "wall_top"
	if down_open:
		return "wall_bottom"
	if left_open:
		return "wall_left"
	if right_open:
		return "wall_right"
	return "wall_fill"

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

## Trees, hedges, flowers, stumps and fallen branches scattered over open
## grass, thinning out next to streets so road edges stay readable.
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
			return _pick_flower_tile(rng)
		return ""
	# Full trees span 3 atlas cells of canopy, so they only root on
	# even/even anchor cells: two trees can never sit side by side and
	# carve each other into vertical strips. The boosted anchor rate keeps
	# the overall tree density at the old ~4.5%.
	if posmod(x, 2) == 0 and posmod(y, 2) == 0 and roll < 0.17:
		return "tree" if rng.randf() < 0.6 else "tree_dark"
	if roll < 0.075:
		return "hedge" if rng.randf() < 0.5 else "hedge_alt"
	if roll < 0.11:
		return _pick_flower_tile(rng)
	if roll < 0.122:
		return "stump" if rng.randf() < 0.6 else "stump_alt"
	if roll < 0.132:
		return "branch"
	return ""

static func _pick_flower_tile(rng: RandomNumberGenerator) -> String:
	var flower_roll := rng.randf()
	if flower_roll < 0.4:
		return "flowers_white"
	if flower_roll < 0.8:
		return "flowers_yellow"
	return "flowers_pink" if rng.randf() < 0.5 else "flowers_pink_alt"

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
		CELL_WALL:
			return "Wall"
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

## The neighbor belongs to the same room's fabric: its own zone, or an
## interior partition wall separating it from a sibling room.
static func _is_same_room(neighbor_cell: int, cell: int) -> bool:
	return neighbor_cell == cell or neighbor_cell == CELL_WALL

## Any cell that is part of a building's solid mass — either zone's floor
## plus partition walls. Used to autotile the timber shell around mixed
## buildings (an inn whose bedroom wing was re-zoned to CELL_HOUSE still
## reads as one continuous structure).
static func _is_building_fabric(cell: int) -> bool:
	return cell == CELL_HOUSE or cell == CELL_BUILDING or cell == CELL_WALL
