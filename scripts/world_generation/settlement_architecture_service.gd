extends RefCounted
class_name SettlementArchitectureService

## Shared building-interior architecture and connectivity guarantees for
## every settlement scene (dwarfholds underground, human towns on the
## surface). Extracted verbatim from dwarf_hold_generation.gd so both
## generators run the SAME machinery: BSP room subdivision with CELL_WALL
## partition lines, spanning-tree internal doors, street-facing exterior
## doors, room-role retagging, and the 0-1 BFS connectivity repair pass.
##
## All functions are static and parameterized by a config Dictionary so
## each scene keeps its own catalogs and tile rules:
##   rng: RandomNumberGenerator      seeded by the caller — call order is
##                                   preserved, so per-seed determinism holds
##   civic_type_map: Dictionary      cell -> civic building type (mutated)
##   residence_type_map: Dictionary  cell -> residence type (mutated)
##   back_roles: Dictionary          building type -> Array of back-room roles
##   default_back_role: String       role dealt when a type has no entry
##   open_plan_types: Array          civic types that never subdivide
##   demolish_zone: int              zone a too-small structure returns to
##                                   (hall underground, open grass on the surface)
##   door_on_open_ground: bool       true: open ground beyond a wall counts as
##                                   a street for exterior doors (the surface
##                                   town case, where grass is walkable);
##                                   false: dwarfhold rock gets a dug stoop

const CELL_ROCK := 0
const CELL_HALL := 1
const CELL_HOUSE := 2
const CELL_BUILDING := 3
const CELL_PLAZA := 4
const CELL_WALL := 6

const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

## --- Multi-room building interiors -----------------------------------------
## Post-pass over every stamped structure: demolish sub-2x2 nooks, BSP-split
## larger plots into 2-5 rooms with CELL_WALL partition lines, punch internal
## doors so the room graph is a spanning tree from the entrance, punch 1-2
## exterior doors on walls that face a street, and retag each room with a
## role (taproom + kitchen + bedrooms; shopfront + workroom; ...).

static func plan_building_interiors(grid: Dictionary, config: Dictionary) -> Dictionary:
	var rng := config.get("rng") as RandomNumberGenerator
	var civic_type_map := config.get("civic_type_map", {}) as Dictionary
	var residence_type_map := config.get("residence_type_map", {}) as Dictionary
	var open_plan_types := config.get("open_plan_types", []) as Array
	var demolish_zone := int(config.get("demolish_zone", CELL_HALL))
	var door_on_open_ground := bool(config.get("door_on_open_ground", false))
	var door_cells: Dictionary = {}
	for component_info: Dictionary in collect_structure_components(grid):
		var zone := int(component_info.get("zone", CELL_HOUSE))
		var bbox := component_info.get("bbox", Rect2i()) as Rect2i
		var cells := component_info.get("cells", []) as Array
		## A gross span under 4 leaves less than a 2x2 interior inside the
		## wall ring: unusable, so it goes back to open ground.
		if bbox.size.x < 4 or bbox.size.y < 4:
			demolish_structure(grid, cells, civic_type_map, residence_type_map, demolish_zone)
			continue
		var is_rect := bbox.size.x * bbox.size.y == cells.size()
		var rooms: Array[Rect2i] = [Rect2i(bbox.position + Vector2i.ONE, bbox.size - Vector2i(2, 2))]
		if is_rect and not _is_open_plan_structure(zone, cells, civic_type_map, open_plan_types):
			rooms = subdivide_structure(grid, bbox, rng)
		punch_internal_doors(grid, rooms, zone, door_cells, rng)
		var entrances := punch_exterior_doors(grid, bbox, zone, door_cells, rng, door_on_open_ground)
		assign_room_roles(grid, rooms, zone, cells, entrances, config)
	return door_cells

static func collect_structure_components(grid: Dictionary) -> Array[Dictionary]:
	var visited: Dictionary = {}
	var components: Array[Dictionary] = []
	for key_variant: Variant in grid.keys():
		var start_cell := key_variant as Vector2i
		if visited.has(start_cell):
			continue
		var zone := int(grid.get(start_cell, CELL_ROCK))
		if zone != CELL_HOUSE and zone != CELL_BUILDING:
			continue
		var queue: Array[Vector2i] = [start_cell]
		visited[start_cell] = true
		var component: Array[Vector2i] = []
		var lo := start_cell
		var hi := start_cell
		var head := 0
		while head < queue.size():
			var current: Vector2i = queue[head]
			head += 1
			component.append(current)
			lo = Vector2i(mini(lo.x, current.x), mini(lo.y, current.y))
			hi = Vector2i(maxi(hi.x, current.x), maxi(hi.y, current.y))
			for direction: Vector2i in DIRECTIONS:
				var neighbor: Vector2i = current + direction
				if visited.has(neighbor):
					continue
				if int(grid.get(neighbor, CELL_ROCK)) != zone:
					continue
				visited[neighbor] = true
				queue.append(neighbor)
		components.append({
			"zone": zone,
			"cells": component,
			"bbox": Rect2i(lo, hi - lo + Vector2i.ONE)
		})
	return components

static func _is_open_plan_structure(zone: int, cells: Array, civic_type_map: Dictionary, open_plan_types: Array) -> bool:
	if zone != CELL_BUILDING or cells.is_empty():
		return false
	var building_type := String(civic_type_map.get(cells[0] as Vector2i, ""))
	return open_plan_types.has(building_type)

static func demolish_structure(grid: Dictionary, cells: Array, civic_type_map: Dictionary, residence_type_map: Dictionary, demolish_zone: int) -> void:
	for cell_variant: Variant in cells:
		var cell := cell_variant as Vector2i
		grid[cell] = demolish_zone
		civic_type_map.erase(cell)
		residence_type_map.erase(cell)

## BSP split of the plot's interior: each cut stamps a full CELL_WALL line
## across the room (including the bounding wall rows, so the wall ring is
## severed and each room becomes its own zone component). Every resulting
## room keeps an interior of at least 2x2.
static func subdivide_structure(grid: Dictionary, bbox: Rect2i, rng: RandomNumberGenerator) -> Array[Rect2i]:
	var interior := Rect2i(bbox.position + Vector2i.ONE, bbox.size - Vector2i(2, 2))
	var rooms: Array[Rect2i] = [interior]
	var target_rooms := clampi(1 + (interior.size.x * interior.size.y) / 14, 1, 5)
	var guard := 0
	while rooms.size() < target_rooms and guard < 16:
		guard += 1
		var best_index := -1
		var best_area := 0
		for room_index in range(rooms.size()):
			var candidate_room := rooms[room_index]
			## Splittable when one axis fits floor(2) + wall(1) + floor(2).
			if candidate_room.size.x < 5 and candidate_room.size.y < 5:
				continue
			var area := candidate_room.size.x * candidate_room.size.y
			if area > best_area:
				best_area = area
				best_index = room_index
		if best_index < 0:
			break
		var room := rooms[best_index]
		var split_vertical := room.size.x >= room.size.y
		if room.size.x < 5:
			split_vertical = false
		elif room.size.y < 5:
			split_vertical = true
		if split_vertical:
			var cut_x := rng.randi_range(room.position.x + 2, room.end.x - 3)
			for wall_y in range(room.position.y - 1, room.end.y + 1):
				grid[Vector2i(cut_x, wall_y)] = CELL_WALL
			rooms[best_index] = Rect2i(room.position, Vector2i(cut_x - room.position.x, room.size.y))
			rooms.append(Rect2i(Vector2i(cut_x + 1, room.position.y), Vector2i(room.end.x - cut_x - 1, room.size.y)))
		else:
			var cut_y := rng.randi_range(room.position.y + 2, room.end.y - 3)
			for wall_x in range(room.position.x - 1, room.end.x + 1):
				grid[Vector2i(wall_x, cut_y)] = CELL_WALL
			rooms[best_index] = Rect2i(room.position, Vector2i(room.size.x, cut_y - room.position.y))
			rooms.append(Rect2i(Vector2i(room.position.x, cut_y + 1), Vector2i(room.size.x, room.end.y - cut_y - 1)))
	return rooms

## One door per spanning-tree edge of the room adjacency graph: every room
## is reachable from every other without leaving the building.
static func punch_internal_doors(grid: Dictionary, rooms: Array[Rect2i], zone: int, door_cells: Dictionary, rng: RandomNumberGenerator) -> void:
	if rooms.size() <= 1:
		return
	var edges: Array[Dictionary] = []
	for a_index in range(rooms.size()):
		for b_index in range(a_index + 1, rooms.size()):
			var candidates := shared_wall_door_candidates(grid, rooms[a_index], rooms[b_index], zone)
			if not candidates.is_empty():
				edges.append({"room_a": a_index, "room_b": b_index, "candidates": candidates})
	var connected: Dictionary = {0: true}
	var grew := true
	while grew:
		grew = false
		for edge: Dictionary in edges:
			var room_a := int(edge.get("room_a", 0))
			var room_b := int(edge.get("room_b", 0))
			if connected.has(room_a) == connected.has(room_b):
				continue
			var candidates := edge.get("candidates", []) as Array
			var pick := candidates[rng.randi_range(0, candidates.size() - 1)] as Vector2i
			door_cells[pick] = true
			connected[room_a] = true
			connected[room_b] = true
			grew = true

## Partition cells between two rooms that have room floor on both sides —
## the only spots where a punched door actually joins the two interiors.
static func shared_wall_door_candidates(grid: Dictionary, room_a: Rect2i, room_b: Rect2i, zone: int) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var left_room := room_a if room_a.position.x < room_b.position.x else room_b
	var right_room := room_b if left_room == room_a else room_a
	if right_room.position.x == left_room.end.x + 1:
		var wall_x := left_room.end.x
		for y in range(maxi(room_a.position.y, room_b.position.y), mini(room_a.end.y, room_b.end.y)):
			var wall_cell := Vector2i(wall_x, y)
			if int(grid.get(wall_cell, CELL_ROCK)) != CELL_WALL:
				continue
			if int(grid.get(wall_cell + Vector2i.LEFT, CELL_ROCK)) != zone:
				continue
			if int(grid.get(wall_cell + Vector2i.RIGHT, CELL_ROCK)) != zone:
				continue
			candidates.append(wall_cell)
		return candidates
	var top_room := room_a if room_a.position.y < room_b.position.y else room_b
	var bottom_room := room_b if top_room == room_a else room_a
	if bottom_room.position.y == top_room.end.y + 1:
		var wall_y := top_room.end.y
		for x in range(maxi(room_a.position.x, room_b.position.x), mini(room_a.end.x, room_b.end.x)):
			var wall_cell := Vector2i(x, wall_y)
			if int(grid.get(wall_cell, CELL_ROCK)) != CELL_WALL:
				continue
			if int(grid.get(wall_cell + Vector2i.UP, CELL_ROCK)) != zone:
				continue
			if int(grid.get(wall_cell + Vector2i.DOWN, CELL_ROCK)) != zone:
				continue
			candidates.append(wall_cell)
	return candidates

## 1-2 exterior doors on non-corner ring cells whose outward neighbor is a
## street (hall/plaza) and whose inward neighbor is room floor. Underground,
## a building carved flush against rock gets a one-cell stoop dug out
## instead, which the connectivity repair then ties into the hall network.
## On the surface (door_on_open_ground) the grass beyond a wall is itself
## walkable, so open-ground walls host doors exactly like street walls.
static func punch_exterior_doors(grid: Dictionary, bbox: Rect2i, zone: int, door_cells: Dictionary, rng: RandomNumberGenerator, door_on_open_ground: bool) -> Array[Vector2i]:
	var street_candidates: Array[Dictionary] = []
	var rock_candidates: Array[Dictionary] = []
	var perimeter: Array[Dictionary] = []
	for x in range(bbox.position.x + 1, bbox.end.x - 1):
		perimeter.append({"cell": Vector2i(x, bbox.position.y), "inward": Vector2i.DOWN})
		perimeter.append({"cell": Vector2i(x, bbox.end.y - 1), "inward": Vector2i.UP})
	for y in range(bbox.position.y + 1, bbox.end.y - 1):
		perimeter.append({"cell": Vector2i(bbox.position.x, y), "inward": Vector2i.RIGHT})
		perimeter.append({"cell": Vector2i(bbox.end.x - 1, y), "inward": Vector2i.LEFT})
	for entry: Dictionary in perimeter:
		var ring_cell := entry.get("cell", Vector2i.ZERO) as Vector2i
		var inward := entry.get("inward", Vector2i.DOWN) as Vector2i
		if int(grid.get(ring_cell, CELL_ROCK)) != zone:
			continue
		if int(grid.get(ring_cell + inward, CELL_ROCK)) != zone:
			continue
		var outward_zone := int(grid.get(ring_cell - inward, CELL_ROCK))
		if outward_zone == CELL_HALL or outward_zone == CELL_PLAZA:
			street_candidates.append(entry)
		elif outward_zone == CELL_ROCK:
			rock_candidates.append(entry)
	if door_on_open_ground:
		## Surface towns: grass-facing walls are as good as street-facing
		## ones — the lane tracer will run a path up to whichever door wins.
		street_candidates.append_array(rock_candidates)
		rock_candidates = []
	var doors: Array[Vector2i] = []
	if not street_candidates.is_empty():
		var first := street_candidates[rng.randi_range(0, street_candidates.size() - 1)]
		var first_cell := first.get("cell", Vector2i.ZERO) as Vector2i
		door_cells[first_cell] = true
		doors.append(first_cell)
		## Big plots earn a second entrance on a stretch of wall far from
		## the first, so long buildings don't funnel everyone one way.
		if bbox.size.x * bbox.size.y >= 60 and street_candidates.size() > 1:
			var far_options: Array[Vector2i] = []
			for candidate: Dictionary in street_candidates:
				var candidate_cell := candidate.get("cell", Vector2i.ZERO) as Vector2i
				if maxi(absi(candidate_cell.x - first_cell.x), absi(candidate_cell.y - first_cell.y)) >= 4:
					far_options.append(candidate_cell)
			if not far_options.is_empty():
				var second_cell := far_options[rng.randi_range(0, far_options.size() - 1)]
				door_cells[second_cell] = true
				doors.append(second_cell)
	elif not rock_candidates.is_empty():
		var pick := rock_candidates[rng.randi_range(0, rock_candidates.size() - 1)]
		var pick_cell := pick.get("cell", Vector2i.ZERO) as Vector2i
		var inward := pick.get("inward", Vector2i.DOWN) as Vector2i
		grid[pick_cell - inward] = CELL_HALL
		door_cells[pick_cell] = true
		doors.append(pick_cell)
	return doors

## Deals roles from the entrance inward: the entrance room keeps the
## building's own trade, back rooms take the type's back_roles entry.
## Dormitories and barracks turn their entrance room into a common room.
static func assign_room_roles(grid: Dictionary, rooms: Array[Rect2i], zone: int, cells: Array, entrances: Array[Vector2i], config: Dictionary) -> void:
	if rooms.size() <= 1 or cells.is_empty():
		return
	var civic_type_map := config.get("civic_type_map", {}) as Dictionary
	var residence_type_map := config.get("residence_type_map", {}) as Dictionary
	var entrance_index := 0
	for entrance_cell: Vector2i in entrances:
		var found := false
		for room_index in range(rooms.size()):
			## The entrance's inward floor cell is inside exactly one room;
			## grow(1) folds the ring cell itself into the containing room.
			if Rect2i(rooms[room_index].position - Vector2i.ONE, rooms[room_index].size + Vector2i(2, 2)).has_point(entrance_cell):
				entrance_index = room_index
				found = true
				break
		if found:
			break
	var ordered: Array[Rect2i] = [rooms[entrance_index]]
	var remaining: Array[Rect2i] = []
	for room_index in range(rooms.size()):
		if room_index != entrance_index:
			remaining.append(rooms[room_index])
	var entrance_center := rooms[entrance_index].get_center()
	remaining.sort_custom(func(rect_a: Rect2i, rect_b: Rect2i) -> bool:
		var da := absi(rect_a.get_center().x - entrance_center.x) + absi(rect_a.get_center().y - entrance_center.y)
		var db := absi(rect_b.get_center().x - entrance_center.x) + absi(rect_b.get_center().y - entrance_center.y)
		if da == db:
			return rect_a.position < rect_b.position
		return da < db
	)
	ordered.append_array(remaining)
	if zone == CELL_HOUSE:
		var residence_type := String(residence_type_map.get(cells[0] as Vector2i, "house"))
		if residence_type == "dormitory" or residence_type == "barracks":
			## Bunk halls keep their bed rows; the entrance room becomes the
			## shared common room (table, chest, hearth-side clutter).
			retag_room_cells(ordered[0], residence_type_map, "house")
		return
	var building_type := String(civic_type_map.get(cells[0] as Vector2i, "workshop"))
	var back_roles_by_type := config.get("back_roles", {}) as Dictionary
	var default_back_role := String(config.get("default_back_role", "storage_warehouse"))
	var back_roles := back_roles_by_type.get(building_type, [default_back_role]) as Array
	for order_index in range(1, ordered.size()):
		var role := String(back_roles[mini(order_index - 1, back_roles.size() - 1)])
		if role == "bedroom":
			convert_room_to_house(grid, ordered[order_index], civic_type_map, residence_type_map)
		else:
			retag_room_cells(ordered[order_index], civic_type_map, role)

## Tags a room's gross rect (floor plus its stretch of wall ring) in the
## given type map. Shared partition cells may be tagged by either side —
## they render as plain wall, so the tie doesn't matter.
static func retag_room_cells(room: Rect2i, type_map: Dictionary, type_name: String) -> void:
	var gross := Rect2i(room.position - Vector2i.ONE, room.size + Vector2i(2, 2))
	for y in range(gross.position.y, gross.end.y):
		for x in range(gross.position.x, gross.end.x):
			var cell := Vector2i(x, y)
			if type_map.has(cell):
				type_map[cell] = type_name

## An inn bedroom or an infirmary ward is a house room in all but name:
## re-zoning to CELL_HOUSE buys the bed tile, the house furnishing
## templates, and a slot in the NPC sleep rotation for free.
static func convert_room_to_house(grid: Dictionary, room: Rect2i, civic_type_map: Dictionary, residence_type_map: Dictionary) -> void:
	var gross := Rect2i(room.position - Vector2i.ONE, room.size + Vector2i(2, 2))
	for y in range(gross.position.y, gross.end.y):
		for x in range(gross.position.x, gross.end.x):
			var cell := Vector2i(x, y)
			if int(grid.get(cell, CELL_ROCK)) == CELL_BUILDING:
				grid[cell] = CELL_HOUSE
			civic_type_map.erase(cell)
			residence_type_map[cell] = "house"

## --- Level-wide connectivity guarantee -------------------------------------
## Flood-fills the level at TILE passability (the same wall/floor/door rules
## rendering and movement use — zone flood fills lie, because a building's
## wall ring shares the zone of its floor). While more than one component
## exists, bridge each pocket to the root along the cheapest wall-crossing
## path: walls become doors, rock becomes a short hall tunnel.
## is_passable is the scene's own tile rule: a Callable(cell: Vector2i) ->
## bool closing over the live grid and door dictionaries, so doors punched
## mid-repair are immediately visible to later sweeps.

static func repair_level_connectivity(grid: Dictionary, door_cells: Dictionary, stair_cells: Dictionary, level_index: int, is_passable: Callable, settlement_label: String) -> void:
	var repairs_made := 0
	## One bridge sweep normally connects everything; extra sweeps verify
	## and mop up interactions between freshly punched openings.
	for _sweep in range(4):
		var components := collect_passable_components(grid, is_passable)
		if components.size() <= 1:
			break
		var root_index := pick_root_component(components, stair_cells)
		repairs_made += bridge_components(grid, door_cells, components, root_index, is_passable)
	if repairs_made > 20:
		print("%s connectivity: level %d needed %d repairs — layout generator produced a badly fragmented map" % [settlement_label, level_index, repairs_made])

static func collect_passable_components(grid: Dictionary, is_passable: Callable) -> Array[Array]:
	var components: Array[Array] = []
	var visited: Dictionary = {}
	for key_variant: Variant in grid.keys():
		var origin := key_variant as Vector2i
		if visited.has(origin):
			continue
		if not bool(is_passable.call(origin)):
			continue
		var queue: Array[Vector2i] = [origin]
		visited[origin] = true
		var component: Array[Vector2i] = []
		var head := 0
		while head < queue.size():
			var current: Vector2i = queue[head]
			head += 1
			component.append(current)
			for direction: Vector2i in DIRECTIONS:
				var neighbor: Vector2i = current + direction
				if visited.has(neighbor):
					continue
				if not bool(is_passable.call(neighbor)):
					continue
				visited[neighbor] = true
				queue.append(neighbor)
		components.append(component)
	return components

static func pick_root_component(components: Array[Array], stair_cells: Dictionary) -> int:
	var stair_lookup: Dictionary = {}
	for stair_variant: Variant in stair_cells.values():
		stair_lookup[stair_variant as Vector2i] = true
	var largest_index := 0
	var largest_size := 0
	for component_index in range(components.size()):
		var component := components[component_index]
		for cell_variant: Variant in component:
			if stair_lookup.has(cell_variant as Vector2i):
				## The stairs are where the player arrives: everything must
				## be reachable from here specifically.
				return component_index
		if component.size() > largest_size:
			largest_size = component.size()
			largest_index = component_index
	return largest_index

## 0-1 BFS from the whole root component: passable steps cost 0, blocked
## cells cost 1 (they can be opened). The first time each pocket is reached
## its path is minimal, so we open the fewest walls/rock cells possible.
static func bridge_components(grid: Dictionary, door_cells: Dictionary, components: Array[Array], root_index: int, is_passable: Callable) -> int:
	var component_of_cell: Dictionary = {}
	for component_index in range(components.size()):
		if component_index == root_index:
			continue
		for cell_variant: Variant in components[component_index]:
			component_of_cell[cell_variant as Vector2i] = component_index
	var bounds := find_bounds(grid).grow(2)
	var dist: Dictionary = {}
	var prev: Dictionary = {}
	var current_layer: Array[Vector2i] = []
	for cell_variant: Variant in components[root_index]:
		var root_cell := cell_variant as Vector2i
		dist[root_cell] = 0
		current_layer.append(root_cell)
	var unreached := components.size() - 1
	var bridged := 0
	var layer_distance := 0
	var bridge_targets: Array[Vector2i] = []
	while not current_layer.is_empty() and unreached > 0:
		var next_layer: Array[Vector2i] = []
		var head := 0
		while head < current_layer.size():
			var current: Vector2i = current_layer[head]
			head += 1
			if int(dist.get(current, -1)) != layer_distance:
				continue
			if component_of_cell.has(current):
				## First touch of a pocket: remember the entry cell, retire
				## the whole pocket so we don't bridge it twice.
				var touched := int(component_of_cell[current])
				bridge_targets.append(current)
				for cell_variant: Variant in components[touched]:
					component_of_cell.erase(cell_variant as Vector2i)
				unreached -= 1
				if unreached <= 0:
					break
			for direction: Vector2i in DIRECTIONS:
				var neighbor: Vector2i = current + direction
				if not bounds.has_point(neighbor):
					continue
				var step_cost := 0 if bool(is_passable.call(neighbor)) else 1
				var next_distance := layer_distance + step_cost
				if dist.has(neighbor) and int(dist[neighbor]) <= next_distance:
					continue
				dist[neighbor] = next_distance
				prev[neighbor] = current
				if step_cost == 0:
					current_layer.append(neighbor)
				else:
					next_layer.append(neighbor)
		current_layer = next_layer
		layer_distance += 1
	for target: Vector2i in bridge_targets:
		open_bridge_path(grid, door_cells, prev, target, is_passable)
		bridged += 1
	return bridged

## Walks the predecessor chain back to the root, opening every blocked cell
## on the way: structure walls and partitions become doors (they stay
## light-blocking stone elsewhere), anything else becomes hall floor.
static func open_bridge_path(grid: Dictionary, door_cells: Dictionary, prev: Dictionary, target: Vector2i, is_passable: Callable) -> void:
	var cursor := target
	var guard := 0
	while prev.has(cursor) and guard < 4096:
		guard += 1
		if not bool(is_passable.call(cursor)):
			var zone := int(grid.get(cursor, CELL_ROCK))
			if zone == CELL_HOUSE or zone == CELL_BUILDING or zone == CELL_WALL:
				door_cells[cursor] = true
			else:
				grid[cursor] = CELL_HALL
		cursor = prev[cursor] as Vector2i

static func find_bounds(grid: Dictionary) -> Rect2i:
	if grid.is_empty():
		return Rect2i(Vector2i.ZERO, Vector2i.ONE)
	var min_x := 2147483647
	var min_y := 2147483647
	var max_x := -2147483648
	var max_y := -2147483648
	for key: Variant in grid.keys():
		var cell := key as Vector2i
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_x = maxi(max_x, cell.x)
		max_y = maxi(max_y, cell.y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
