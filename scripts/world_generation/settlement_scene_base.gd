class_name SettlementSceneBase
extends Control

## Shared procedural-generation core for the surface towns and the
## dwarfholds: seeded zone targets, plaza/hall/structure placement,
## door computation, connectivity, and the low-level grid utilities.
## The two scenes evolved as copies; this base is the single source.
## Child scenes own rendering, lighting, and everything scene-flavored.

const CELL_ROCK := 0

const CELL_HALL := 1

const CELL_HOUSE := 2

const CELL_BUILDING := 3

const CELL_PLAZA := 4

## Interior partition wall inside a multi-room structure. 5 is taken by
## the dwarfhold's CELL_WATER, so partitions claim 6. Walls always render
## as stone (impassable, light-blocking) and split a building's zone into
## per-room components so each room is furnished as its own space.
const CELL_WALL := 6

const ZONE_OVERLAY_COLORS := {
	CELL_HALL: Color(0.27, 0.58, 0.90, 0.35),
	CELL_HOUSE: Color(0.84, 0.72, 0.24, 0.35),
	CELL_BUILDING: Color(0.61, 0.35, 0.88, 0.35),
	CELL_PLAZA: Color(0.18, 0.74, 0.66, 0.35),
	CELL_WALL: Color(0.45, 0.45, 0.5, 0.45)
}

@export var tile_size := Vector2i(32, 32)

@export var structure_fallback_max_extra_radius := 240

@onready var city_layer: TileMapLayer = %CityTileLayer

@onready var decor_layer: TileMapLayer = %DecorTileLayer

@onready var zone_overlay: Control = %ZoneOverlay

var _rng := RandomNumberGenerator.new()

var _hold_state := DwarfHoldStateModel.new()

var _latest_grid: Dictionary = {}

var _latest_civic_building_type_map: Dictionary = {}
var _latest_civic_building_name_map: Dictionary = {}

var _latest_residence_type_map: Dictionary = {}

var _show_zone_overlay := false

var _zoom_level := 1.0

## Per-scene catalogs; children override with their own consts.
func _civic_building_types() -> Dictionary:
	return {}

func _residence_types() -> Dictionary:
	return {}

func _pick_seeded_zone_target(count_range: Vector2i) -> int:
	return DwarfHoldGenerationRules.pick_seeded_zone_target(_rng, count_range)

func _roll_residence_type() -> String:
	var roll := _rng.randf()
	var cumulative := 0.0
	for type_name: String in _residence_types().keys():
		cumulative += float((_residence_types()[type_name] as Dictionary).get("weight", 0.0))
		if roll <= cumulative:
			return type_name
	return "house"

func _roll_residence_footprint(residence_type: String) -> Vector2i:
	var residence_def := _residence_types().get(residence_type, _residence_types()["house"]) as Dictionary
	var radius_min := residence_def.get("radius_min", Vector2i(2, 2)) as Vector2i
	var radius_max := residence_def.get("radius_max", Vector2i(6, 5)) as Vector2i
	return Vector2i(
		_rng.randi_range(radius_min.x, radius_max.x),
		_rng.randi_range(radius_min.y, radius_max.y)
	)

## Mirrors the decor templates in DwarfHoldTileService: houses sleep one
## dwarf, dormitories fill alternating cells with bunks, barracks lay bed
## rows every third rank.
func _estimate_residence_beds(residence_type: String, footprint: Vector2i) -> int:
	match residence_type:
		"dormitory":
			return maxi(2, footprint.x * footprint.y)
		"barracks":
			return maxi(2, footprint.x * (((footprint.y * 2 - 1) / 3) + 1))
		_:
			return 1

func _target_npcs_for_level(level_index: int, level_count: int) -> int:
	return _hold_state.target_npcs_for_level(level_index, level_count)

func _pick_civic_building_type() -> String:
	return DwarfHoldLayoutService.pick_civic_building_type(_rng, _civic_building_types())

func _roll_civic_footprint(civic_definition: Dictionary) -> Vector2i:
	return DwarfHoldLayoutService.roll_civic_footprint(_rng, civic_definition)

func _civic_prefers_hall_arteries(civic_definition: Dictionary) -> bool:
	return DwarfHoldLayoutService.civic_prefers_hall_arteries(civic_definition)


func _dig_branching_hall_between_plazas(grid: Dictionary, from_plaza: Dictionary, to_plaza: Dictionary) -> void:
	var from_center := from_plaza.get("center", Vector2i.ZERO) as Vector2i
	var to_center := to_plaza.get("center", Vector2i.ZERO) as Vector2i
	if from_center == to_center:
		return
	var from_radius := from_plaza.get("radius", Vector2i(6, 5)) as Vector2i
	var to_radius := to_plaza.get("radius", Vector2i(6, 5)) as Vector2i
	var corridor_width := _rng.randi_range(3, 5)
	var from_exit := _plaza_edge_cell_facing(from_center, from_radius, to_center)
	var to_exit := _plaza_edge_cell_facing(to_center, to_radius, from_center)
	_dig_wide_hall_path(grid, from_exit, to_exit, corridor_width)

func _roll_plaza_shape() -> String:
	return "rect" if _rng.randf() < 0.5 else "ellipse"

func _dig_plaza_zone(grid: Dictionary, center: Vector2i, radius: Vector2i, shape: String, tile: int) -> void:
	if shape == "rect":
		_dig_rect(grid, center - radius, center + radius, tile)
		return
	_dig_ellipse(grid, center, radius, tile)


func _plaza_clearance_radius(radius: Vector2i) -> float:
	return float(maxi(radius.x, radius.y))

func _is_plaza_too_close(candidate_center: Vector2i, candidate_radius: Vector2i, plaza_layouts: Array[Dictionary], min_gap: int) -> bool:
	var candidate_clearance := _plaza_clearance_radius(candidate_radius)
	for plaza_data_variant: Variant in plaza_layouts:
		var plaza_data := plaza_data_variant as Dictionary
		var existing_center := plaza_data.get("center", Vector2i.ZERO) as Vector2i
		var existing_radius := plaza_data.get("radius", Vector2i(6, 5)) as Vector2i
		var minimum_distance := candidate_clearance + _plaza_clearance_radius(existing_radius) + float(min_gap)
		if candidate_center.distance_to(existing_center) < minimum_distance:
			return true
	return false

func _plaza_edge_cell_facing(plaza_center: Vector2i, plaza_radius: Vector2i, target: Vector2i) -> Vector2i:
	var axis_direction := _major_axis_direction_toward_target(plaza_center, target)
	if axis_direction == Vector2i.LEFT:
		return Vector2i(plaza_center.x - plaza_radius.x, plaza_center.y + _rng.randi_range(-1, 1))
	if axis_direction == Vector2i.RIGHT:
		return Vector2i(plaza_center.x + plaza_radius.x, plaza_center.y + _rng.randi_range(-1, 1))
	if axis_direction == Vector2i.UP:
		return Vector2i(plaza_center.x + _rng.randi_range(-1, 1), plaza_center.y - plaza_radius.y)
	return Vector2i(plaza_center.x + _rng.randi_range(-1, 1), plaza_center.y + plaza_radius.y)

func _dig_wide_hall_path(grid: Dictionary, start: Vector2i, finish: Vector2i, width: int) -> void:
	var half_width := maxi(1, width / 2)
	var corner := Vector2i(finish.x, start.y)
	_dig_wide_hall_segment(grid, start, corner, half_width)
	_dig_wide_hall_segment(grid, corner, finish, half_width)

func _dig_wide_hall_segment(grid: Dictionary, from_cell: Vector2i, to_cell: Vector2i, half_width: int) -> void:
	var segment_from := Vector2i(mini(from_cell.x, to_cell.x), mini(from_cell.y, to_cell.y))
	var segment_to := Vector2i(maxi(from_cell.x, to_cell.x), maxi(from_cell.y, to_cell.y))
	if segment_from.x == segment_to.x:
		segment_from.x -= half_width
		segment_to.x += half_width
	else:
		segment_from.y -= half_width
		segment_to.y += half_width
	_dig_rect(grid, segment_from, segment_to, CELL_HALL)

func _place_structure_zone(
	grid: Dictionary,
	hubs: Array[Vector2i],
	structure_tile: int,
	offset_generator: Callable,
	size_generator: Callable,
	building_type: String = ""
) -> bool:
	var max_search_rings := 16
	for ring in range(max_search_rings):
		var expansion := ring * 4
		var attempts := 48
		for _attempt in attempts:
			var anchor := hubs[_rng.randi_range(0, hubs.size() - 1)]
			var offset := offset_generator.call() as Vector2i
			var center := anchor + offset
			if ring > 0:
				center += Vector2i(_rng.randi_range(-expansion, expansion), _rng.randi_range(-expansion, expansion))
			var footprint := size_generator.call() as Vector2i
			if _try_place_structure_with_single_door(grid, center, footprint, structure_tile, anchor):
				_register_building_type_metadata(center, footprint, structure_tile, building_type)
				return true

	var fallback_anchor := hubs[_rng.randi_range(0, hubs.size() - 1)]
	var fallback_footprint := size_generator.call() as Vector2i
	return _place_structure_in_open_space(grid, structure_tile, fallback_anchor, fallback_footprint, building_type)

func _place_structure_along_halls(grid: Dictionary, structure_tile: int, footprint: Vector2i, building_type: String = "") -> bool:
	var hall_edge_candidates := _collect_hall_edge_candidates(grid)
	if hall_edge_candidates.is_empty():
		return false
	for _attempt in 140:
		var candidate: Dictionary = hall_edge_candidates[_rng.randi_range(0, hall_edge_candidates.size() - 1)]
		var hall_cell := candidate["hall"] as Vector2i
		var side_dir := candidate["side"] as Vector2i
		var structural_radius := footprint.x if side_dir.x != 0 else footprint.y
		var standoff := structural_radius + _rng.randi_range(1, 3)
		var center := hall_cell + side_dir * standoff
		if not _can_place_structure(grid, center, footprint):
			continue
		_dig_structure_with_room(grid, center, footprint, structure_tile)
		_register_building_type_metadata(center, footprint, structure_tile, building_type)
		var doorway := _pick_side_center_door_cell_facing(center, footprint, -side_dir)
		var exterior := doorway + _outward_direction_for_door(center, footprint, doorway)
		_connect_points(grid, exterior, hall_cell, CELL_HALL)
		return true
	return false

func _collect_hall_edge_candidates(grid: Dictionary) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for key: Variant in grid.keys():
		var hall_cell := key as Vector2i
		if _cell_at(grid, hall_cell.x, hall_cell.y) != CELL_HALL:
			continue
		for side_dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var side_cell := hall_cell + side_dir
			if _cell_at(grid, side_cell.x, side_cell.y) != CELL_ROCK:
				continue
			candidates.append({"hall": hall_cell, "side": side_dir})
	return candidates

func _place_structure_in_open_space(grid: Dictionary, structure_tile: int, anchor: Vector2i, footprint: Vector2i, building_type: String = "") -> bool:
	var start_radius := maxi(footprint.x, footprint.y) + 8
	var max_radius := start_radius + maxi(structure_fallback_max_extra_radius, 0)
	for radius in range(start_radius, max_radius + 1, 8):
		var candidate_centers := [
			Vector2i(anchor.x + radius, anchor.y),
			Vector2i(anchor.x - radius, anchor.y),
			Vector2i(anchor.x, anchor.y + radius),
			Vector2i(anchor.x, anchor.y - radius),
			Vector2i(anchor.x + radius, anchor.y + radius),
			Vector2i(anchor.x - radius, anchor.y + radius),
			Vector2i(anchor.x + radius, anchor.y - radius),
			Vector2i(anchor.x - radius, anchor.y - radius)
		]
		for center: Vector2i in candidate_centers:
			if _try_place_structure_with_single_door(grid, center, footprint, structure_tile, anchor):
				_register_building_type_metadata(center, footprint, structure_tile, building_type)
				return true
	return false


func _register_building_type_metadata(center: Vector2i, footprint: Vector2i, structure_tile: int, building_type: String) -> void:
	if building_type.is_empty():
		return
	if structure_tile != CELL_BUILDING and structure_tile != CELL_HOUSE:
		return
	var target_map := _latest_civic_building_type_map if structure_tile == CELL_BUILDING else _latest_residence_type_map
	for y in range(center.y - footprint.y, center.y + footprint.y + 1):
		for x in range(center.x - footprint.x, center.x + footprint.x + 1):
			target_map[Vector2i(x, y)] = building_type

func _compute_civic_buildings_by_id(grid: Dictionary) -> Dictionary:
	var visited: Dictionary = {}
	var by_id: Dictionary = {}
	for key: Variant in grid.keys():
		var start_cell := key as Vector2i
		if visited.has(start_cell):
			continue
		if _cell_at(grid, start_cell.x, start_cell.y) != CELL_BUILDING:
			continue
		var queue: Array[Vector2i] = [start_cell]
		visited[start_cell] = true
		var component: Array[Vector2i] = []
		var head := 0
		while head < queue.size():
			var current: Vector2i = queue[head]
			head += 1
			component.append(current)
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor := current + direction
				if visited.has(neighbor):
					continue
				if _cell_at(grid, neighbor.x, neighbor.y) != CELL_BUILDING:
					continue
				visited[neighbor] = true
				queue.append(neighbor)
		if component.is_empty():
			continue
		var anchor := _stable_component_anchor(component)
		var building_id := "%d:%d" % [anchor.x, anchor.y]
		var building_type := String(_latest_civic_building_type_map.get(anchor, "workshop"))
		by_id[building_id] = {"anchor": anchor, "type": building_type, "cells": component}
	return by_id

func _stable_component_anchor(component: Array[Vector2i]) -> Vector2i:
	var anchor := component[0]
	for cell: Vector2i in component:
		if cell.x < anchor.x or (cell.x == anchor.x and cell.y < anchor.y):
			anchor = cell
	return anchor

## Signboards: every civic building gets a deterministic name over its
## door, rolled from the settlement seed and the building's stable id.
func _build_civic_building_name_lookup(buildings_by_id: Dictionary, seed_text: String, kind: String) -> Dictionary:
	var lookup: Dictionary = {}
	for building_id: String in buildings_by_id.keys():
		var payload := buildings_by_id[building_id] as Dictionary
		var display_name := BuildingNameService.name_for(String(payload.get("type", "workshop")), seed_text, building_id, kind)
		payload["display_name"] = display_name
		for cell_variant: Variant in (payload.get("cells", []) as Array):
			lookup[cell_variant as Vector2i] = display_name
	return lookup

func _build_civic_building_type_lookup(buildings_by_id: Dictionary) -> Dictionary:
	var lookup: Dictionary = {}
	for building_id: String in buildings_by_id.keys():
		var payload := buildings_by_id[building_id] as Dictionary
		var building_type := String(payload.get("type", "workshop"))
		var cells := payload.get("cells", []) as Array
		for cell_variant: Variant in cells:
			lookup[cell_variant as Vector2i] = building_type
	return lookup

func _count_zone_components(grid: Dictionary) -> Dictionary:
	return {
		"halls": _count_components_for_tile(grid, CELL_HALL),
		"houses": _count_components_for_tile(grid, CELL_HOUSE),
		"buildings": _count_components_for_tile(grid, CELL_BUILDING),
		"plazas": _count_components_for_tile(grid, CELL_PLAZA)
	}

func _count_components_for_tile(grid: Dictionary, tile_type: int) -> int:
	var visited: Dictionary = {}
	var component_count := 0
	for key: Variant in grid.keys():
		var start_cell := key as Vector2i
		if visited.has(start_cell):
			continue
		if _cell_at(grid, start_cell.x, start_cell.y) != tile_type:
			continue

		component_count += 1
		var queue: Array[Vector2i] = [start_cell]
		visited[start_cell] = true
		var head := 0
		while head < queue.size():
			var current: Vector2i = queue[head]
			head += 1
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor := current + direction
				if visited.has(neighbor):
					continue
				if _cell_at(grid, neighbor.x, neighbor.y) != tile_type:
					continue
				visited[neighbor] = true
				queue.append(neighbor)

	return component_count

func _on_overlay_toggle_toggled(toggled_on: bool) -> void:
	_show_zone_overlay = toggled_on
	_update_zone_overlay()

func _update_zone_overlay() -> void:
	if zone_overlay.has_method("set_overlay_state"):
		zone_overlay.call("set_overlay_state", _latest_grid, tile_size, _zoom_level, city_layer.position, ZONE_OVERLAY_COLORS, _show_zone_overlay)

func _dig_structure_with_room(grid: Dictionary, center: Vector2i, footprint: Vector2i, structure_tile: int) -> void:
	var from_cell := center - footprint
	var to_cell := center + footprint
	_dig_rect(grid, from_cell, to_cell, structure_tile)

func _try_place_structure_with_single_door(grid: Dictionary, center: Vector2i, footprint: Vector2i, structure_tile: int, anchor: Vector2i) -> bool:
	if not _can_place_structure(grid, center, footprint):
		return false
	_dig_structure_with_room(grid, center, footprint, structure_tile)
	var outward_dir := _major_axis_direction_toward_target(center, anchor)
	var doorway := _pick_side_center_door_cell_facing(center, footprint, outward_dir)
	var exterior := doorway + _outward_direction_for_door(center, footprint, doorway)
	_connect_points(grid, exterior, anchor, CELL_HALL)
	return true

func _can_place_structure(grid: Dictionary, center: Vector2i, footprint: Vector2i) -> bool:
	var from_cell := center - footprint
	var to_cell := center + footprint
	for y in range(from_cell.y - 1, to_cell.y + 2):
		for x in range(from_cell.x - 1, to_cell.x + 2):
			var tile := _cell_at(grid, x, y)
			if tile == CELL_HOUSE or tile == CELL_BUILDING:
				return false
			if (x == from_cell.x - 1 or x == to_cell.x + 1 or y == from_cell.y - 1 or y == to_cell.y + 1) and _is_corridor_cell(tile):
				return false
	return true

func _pick_structure_door_cell(center: Vector2i, footprint: Vector2i) -> Vector2i:
	var from_cell := center - footprint
	var to_cell := center + footprint
	var side := _rng.randi_range(0, 3)
	match side:
		0:
			var top_x := center.x if from_cell.x + 1 > to_cell.x - 1 else _rng.randi_range(from_cell.x + 1, to_cell.x - 1)
			return Vector2i(top_x, from_cell.y)
		1:
			var bottom_x := center.x if from_cell.x + 1 > to_cell.x - 1 else _rng.randi_range(from_cell.x + 1, to_cell.x - 1)
			return Vector2i(bottom_x, to_cell.y)
		2:
			var left_y := center.y if from_cell.y + 1 > to_cell.y - 1 else _rng.randi_range(from_cell.y + 1, to_cell.y - 1)
			return Vector2i(from_cell.x, left_y)
		_:
			var right_y := center.y if from_cell.y + 1 > to_cell.y - 1 else _rng.randi_range(from_cell.y + 1, to_cell.y - 1)
			return Vector2i(to_cell.x, right_y)

func _pick_side_center_door_cell_facing(center: Vector2i, footprint: Vector2i, outward_dir: Vector2i) -> Vector2i:
	var from_cell := center - footprint
	var to_cell := center + footprint
	if outward_dir == Vector2i.UP:
		return Vector2i(center.x, from_cell.y)
	if outward_dir == Vector2i.DOWN:
		return Vector2i(center.x, to_cell.y)
	if outward_dir == Vector2i.LEFT:
		return Vector2i(from_cell.x, center.y)
	return Vector2i(to_cell.x, center.y)

func _major_axis_direction_toward_target(origin: Vector2i, target: Vector2i) -> Vector2i:
	var delta := target - origin
	if abs(delta.x) >= abs(delta.y):
		return Vector2i.RIGHT if delta.x >= 0 else Vector2i.LEFT
	return Vector2i.DOWN if delta.y >= 0 else Vector2i.UP

func _outward_direction_for_door(center: Vector2i, footprint: Vector2i, door: Vector2i) -> Vector2i:
	var from_cell := center - footprint
	var to_cell := center + footprint
	if door.y == from_cell.y:
		return Vector2i.UP
	if door.y == to_cell.y:
		return Vector2i.DOWN
	if door.x == from_cell.x:
		return Vector2i.LEFT
	return Vector2i.RIGHT


func _compute_single_doors(grid: Dictionary) -> Dictionary:
	var visited: Dictionary = {}
	var chosen_doors: Dictionary = {}

	for key: Variant in grid.keys():
		var start_cell := key as Vector2i
		var tile := _cell_at(grid, start_cell.x, start_cell.y)
		if tile != CELL_HOUSE and tile != CELL_BUILDING:
			continue
		if visited.has(start_cell):
			continue

		var queue: Array[Vector2i] = [start_cell]
		visited[start_cell] = true
		var component_cells: Array[Vector2i] = []
		var head := 0
		while head < queue.size():
			var current: Vector2i = queue[head]
			head += 1
			component_cells.append(current)
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor: Vector2i = current + direction
				if visited.has(neighbor):
					continue
				if _cell_at(grid, neighbor.x, neighbor.y) != tile:
					continue
				visited[neighbor] = true
				queue.append(neighbor)

		var component_lookup: Dictionary = {}
		for component_cell: Vector2i in component_cells:
			component_lookup[component_cell] = true

		var candidates: Array[Vector2i] = []
		for component_cell: Vector2i in component_cells:
			if _is_component_corner_cell(component_cell, component_lookup):
				continue
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var corridor_neighbor := component_cell + direction
				if _is_corridor_cell(_cell_at(grid, corridor_neighbor.x, corridor_neighbor.y)):
					candidates.append(component_cell)
					break

		if candidates.is_empty():
			continue
		var selected := candidates[_rng.randi_range(0, candidates.size() - 1)] as Vector2i
		chosen_doors[selected] = true

	return chosen_doors

func _ensure_door_connectivity(grid: Dictionary, door_cells_by_level: Dictionary) -> void:
	if door_cells_by_level.is_empty():
		return

	var connected_doors: Dictionary = {}
	var door_cells: Array[Vector2i] = []
	for door_variant: Variant in door_cells_by_level.keys():
		var door_cell := door_variant as Vector2i
		door_cells.append(door_cell)

	var root_door := door_cells[0]
	connected_doors[root_door] = true
	var reachable := _collect_walkable_reachable_cells(grid, root_door)

	for _iteration in range(door_cells.size() * 4):
		var disconnected_door := Vector2i(2147483647, 2147483647)
		for door_cell: Vector2i in door_cells:
			if reachable.has(door_cell):
				connected_doors[door_cell] = true
				continue
			disconnected_door = door_cell
			break

		if disconnected_door.x == 2147483647:
			break

		var closest_connected := root_door
		var closest_distance := disconnected_door.distance_squared_to(root_door)
		for connected_variant: Variant in connected_doors.keys():
			var connected_door := connected_variant as Vector2i
			var candidate_distance := disconnected_door.distance_squared_to(connected_door)
			if candidate_distance < closest_distance:
				closest_connected = connected_door
				closest_distance = candidate_distance

		_connect_points(grid, closest_connected, disconnected_door, CELL_HALL)
		reachable = _collect_walkable_reachable_cells(grid, root_door)

func _collect_walkable_reachable_cells(grid: Dictionary, start_cell: Vector2i) -> Dictionary:
	var reachable: Dictionary = {}
	if not grid.has(start_cell):
		return reachable
	if not _is_walkable_zone(_cell_at(grid, start_cell.x, start_cell.y)):
		return reachable

	var queue: Array[Vector2i] = [start_cell]
	reachable[start_cell] = true
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor := current + direction
			if reachable.has(neighbor):
				continue
			if not grid.has(neighbor):
				continue
			if not _is_walkable_zone(_cell_at(grid, neighbor.x, neighbor.y)):
				continue
			reachable[neighbor] = true
			queue.append(neighbor)

	return reachable

func _ensure_walkable_connectivity(grid: Dictionary) -> void:
	var components := _collect_walkable_components(grid)
	if components.size() <= 1:
		return

	var largest_component_index := 0
	var largest_component_size := 0
	for i in range(components.size()):
		var component := components[i] as Array[Vector2i]
		if component.size() > largest_component_size:
			largest_component_size = component.size()
			largest_component_index = i

	var connected_cells: Array[Vector2i] = []
	connected_cells.assign(components[largest_component_index])

	for i in range(components.size()):
		if i == largest_component_index:
			continue
		var component := components[i] as Array[Vector2i]
		if component.is_empty() or connected_cells.is_empty():
			continue

		var nearest_pair := _find_nearest_cell_pair(connected_cells, component)
		if nearest_pair.is_empty():
			continue

		_connect_points(grid, nearest_pair[0] as Vector2i, nearest_pair[1] as Vector2i, CELL_HALL)
		connected_cells.append_array(component)

func _collect_walkable_components(grid: Dictionary) -> Array[Array]:
	var components: Array[Array] = []
	var visited: Dictionary = {}

	for cell_variant: Variant in grid.keys():
		var origin := cell_variant as Vector2i
		if visited.has(origin):
			continue
		if not _is_walkable_zone(_cell_at(grid, origin.x, origin.y)):
			continue

		var queue: Array[Vector2i] = [origin]
		var component: Array[Vector2i] = []
		visited[origin] = true

		var head := 0
		while head < queue.size():
			var current: Vector2i = queue[head]
			head += 1
			component.append(current)
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor := current + direction
				if visited.has(neighbor):
					continue
				if not grid.has(neighbor):
					continue
				if not _is_walkable_zone(_cell_at(grid, neighbor.x, neighbor.y)):
					continue
				visited[neighbor] = true
				queue.append(neighbor)

		if not component.is_empty():
			components.append(component)

	return components

func _find_nearest_cell_pair(group_a: Array[Vector2i], group_b: Array[Vector2i]) -> Array[Vector2i]:
	if group_a.is_empty() or group_b.is_empty():
		return []

	var nearest_a := group_a[0]
	var nearest_b := group_b[0]
	var best_distance := nearest_a.distance_squared_to(nearest_b)

	for cell_a: Vector2i in group_a:
		for cell_b: Vector2i in group_b:
			var candidate_distance := cell_a.distance_squared_to(cell_b)
			if candidate_distance < best_distance:
				best_distance = candidate_distance
				nearest_a = cell_a
				nearest_b = cell_b

	return [nearest_a, nearest_b]

func _is_walkable_zone(cell: int) -> bool:
	return cell == CELL_HALL or cell == CELL_HOUSE or cell == CELL_BUILDING or cell == CELL_PLAZA

func _is_component_corner_cell(cell: Vector2i, component_lookup: Dictionary) -> bool:
	var has_left := component_lookup.has(cell + Vector2i.LEFT)
	var has_right := component_lookup.has(cell + Vector2i.RIGHT)
	var has_up := component_lookup.has(cell + Vector2i.UP)
	var has_down := component_lookup.has(cell + Vector2i.DOWN)
	if (not has_left and not has_up) or (not has_left and not has_down):
		return true
	if (not has_right and not has_up) or (not has_right and not has_down):
		return true
	return false


func _dig_rect(grid: Dictionary, from_cell: Vector2i, to_cell: Vector2i, tile: int) -> void:
	for y in range(from_cell.y, to_cell.y + 1):
		for x in range(from_cell.x, to_cell.x + 1):
			_set_cell(grid, Vector2i(x, y), tile)

func _dig_ellipse(grid: Dictionary, center: Vector2i, radius: Vector2i, tile: int) -> void:
	for y in range(center.y - radius.y, center.y + radius.y + 1):
		for x in range(center.x - radius.x, center.x + radius.x + 1):
			var normalized_x := float(x - center.x) / maxf(float(radius.x), 1.0)
			var normalized_y := float(y - center.y) / maxf(float(radius.y), 1.0)
			if normalized_x * normalized_x + normalized_y * normalized_y <= 1.0:
				_set_cell(grid, Vector2i(x, y), tile)

func _connect_points(grid: Dictionary, start: Vector2i, finish: Vector2i, tile: int) -> void:
	var corridor_width := _rng.randi_range(2, 5)
	var cursor := start
	while cursor.x != finish.x:
		_dig_corridor_at(grid, cursor, tile, true, corridor_width)
		cursor.x += 1 if finish.x > cursor.x else -1
	while cursor.y != finish.y:
		_dig_corridor_at(grid, cursor, tile, false, corridor_width)
		cursor.y += 1 if finish.y > cursor.y else -1
	_dig_corridor_at(grid, finish, tile, true, corridor_width)
	_dig_corridor_at(grid, finish, tile, false, corridor_width)

func _dig_corridor_at(grid: Dictionary, origin: Vector2i, tile: int, horizontal: bool, width: int) -> void:
	var start_offset := -int(width / 2)
	for i in width:
		var offset := start_offset + i
		if horizontal:
			_set_cell(grid, Vector2i(origin.x, origin.y + offset), tile)
		else:
			_set_cell(grid, Vector2i(origin.x + offset, origin.y), tile)

func _set_cell(grid: Dictionary, cell: Vector2i, tile: int) -> void:
	var existing := _cell_at(grid, cell.x, cell.y)
	if tile == CELL_HALL and existing == CELL_PLAZA:
		return
	if _is_corridor_cell(tile) and _is_structural_cell(existing):
		return
	grid[cell] = tile

func _cell_at(grid: Dictionary, x: int, y: int) -> int:
	return int(grid.get(Vector2i(x, y), CELL_ROCK))

func _is_structural_cell(cell: int) -> bool:
	return cell == CELL_HOUSE or cell == CELL_BUILDING

func _is_corridor_cell(cell: int) -> bool:
	return cell == CELL_HALL or cell == CELL_PLAZA

func _find_bounds(grid: Dictionary) -> Rect2i:
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
