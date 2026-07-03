extends RefCounted
class_name TownNpcScheduler

## Daily-life simulation for town NPCs. Each resident gets a role (matching
## their spritesheet slot), a home bed and a workplace; the game clock then
## drives where they head: work by day, leisure around the market in the
## morning and evening, home to bed at night. Guards patrol street
## waypoints instead of working a building, and half of them keep a night
## watch. Movement is greedy step-toward-anchor with a random wander inside
## the anchor radius, reusing the tavern service's facing/frame animation.

## Spritesheet slots (townsfolk_characters.png block order).
const ROLE_VILLAGER := 0
const ROLE_VILLAGER_WOMAN := 1
const ROLE_GUARD := 2
const ROLE_MERCHANT := 3
const ROLE_BLACKSMITH := 4
const ROLE_CLERIC := 5
const ROLE_FARMER := 6
const ROLE_ELDER := 7

const MODE_SLEEP := "sleep"
const MODE_WORK := "work"
const MODE_LEISURE := "leisure"
const MODE_PATROL := "patrol"

const SLEEP_START_HOUR := 22.0
const SLEEP_END_HOUR := 6.0
const WORK_START_HOUR := 8.0
const WORK_END_HOUR := 18.0

const TRAVEL_COOLDOWN_RANGE := Vector2(0.05, 0.25)
const WANDER_COOLDOWN_RANGE := Vector2(0.8, 2.4)
const SLEEP_COOLDOWN_RANGE := Vector2(4.0, 9.0)

## Which building types each working role reports to, in preference order.
const ROLE_WORKPLACES := {
	ROLE_BLACKSMITH: ["smithy", "workshop", "carpenter"],
	ROLE_MERCHANT: ["market_stall", "general_store", "warehouse"],
	ROLE_CLERIC: ["chapel", "town_hall"],
	ROLE_ELDER: ["town_hall", "guild_hall", "tavern"],
	ROLE_VILLAGER: ["tavern", "bakery", "general_store", "warehouse", "stable", "carpenter", "tailor", "apothecary", "inn", "workshop"],
	ROLE_VILLAGER_WOMAN: ["bakery", "tailor", "apothecary", "inn", "tavern", "general_store", "guild_hall", "workshop"]
}

## Assigns roles, homes and workplaces to freshly spawned NPC states.
## context keys:
##   "bed_cells": Array[Vector2i] (impassable bed decor cells)
##   "building_cells_by_type": Dictionary type -> Array[Vector2i]
##   "street_cells": Array[Vector2i] (walkable street/plaza cells)
##   "green_cells": Array[Vector2i] (walkable open grass cells)
##   "is_walkable": Callable(Vector2i) -> bool
##   "rng": RandomNumberGenerator
static func assign_daily_lives(npc_states: Array[Dictionary], context: Dictionary) -> void:
	var rng := context.get("rng") as RandomNumberGenerator
	var is_walkable := context.get("is_walkable") as Callable
	var bed_cells: Array[Vector2i] = []
	for bed_variant: Variant in (context.get("bed_cells", []) as Array):
		bed_cells.append(bed_variant as Vector2i)
	_shuffle(bed_cells, rng)
	var street_cells: Array[Vector2i] = []
	for street_variant: Variant in (context.get("street_cells", []) as Array):
		street_cells.append(street_variant as Vector2i)
	var green_cells: Array[Vector2i] = []
	for green_variant: Variant in (context.get("green_cells", []) as Array):
		green_cells.append(green_variant as Vector2i)
	var buildings := context.get("building_cells_by_type", {}) as Dictionary

	var roles := _build_role_list(npc_states.size(), buildings, rng)
	var bed_index := 0
	for npc_index in npc_states.size():
		var state := npc_states[npc_index]
		var role: int = roles[npc_index]
		state["slot"] = role
		state["role"] = role

		# Home: a bed of their own (stand on the nearest open cell beside it).
		var home_anchor := Vector2i(2147483647, 2147483647)
		while bed_index < bed_cells.size():
			var candidate := _walkable_neighbor(bed_cells[bed_index], is_walkable)
			bed_index += 1
			if candidate.x != 2147483647:
				home_anchor = candidate
				break
		if home_anchor.x == 2147483647 and not street_cells.is_empty():
			home_anchor = street_cells[rng.randi_range(0, street_cells.size() - 1)]
		state["home_anchor"] = home_anchor

		# Workplace by role.
		match role:
			ROLE_GUARD:
				state["patrol_points"] = _pick_patrol_points(street_cells, rng)
				state["patrol_index"] = 0
				state["work_anchor"] = home_anchor
				state["night_watch"] = (npc_index % 2) == 0
			ROLE_FARMER:
				state["work_anchor"] = _pick_from(green_cells, rng, home_anchor)
			_:
				state["work_anchor"] = _pick_workplace(role, buildings, is_walkable, rng, street_cells, home_anchor)

		# Leisure: around the market and streets.
		state["leisure_anchor"] = _pick_from(street_cells, rng, home_anchor)
		state["mode"] = ""

## Role composition scaled to what the town actually built.
static func _build_role_list(npc_count: int, buildings: Dictionary, rng: RandomNumberGenerator) -> Array[int]:
	var roles: Array[int] = []
	var guard_count := maxi(2, npc_count / 12)
	var smith_count := mini(npc_count / 10, (buildings.get("smithy", []) as Array).size() * 2 + 1)
	var merchant_count := mini(maxi(1, npc_count / 8), (buildings.get("market_stall", []) as Array).size() + (buildings.get("general_store", []) as Array).size() * 2 + 1)
	var cleric_count := mini(maxi(1, npc_count / 20), (buildings.get("chapel", []) as Array).size() * 2 + 1)
	var farmer_count := maxi(1, npc_count / 8)
	var elder_count := maxi(1, npc_count / 10)
	for _i in range(guard_count):
		roles.append(ROLE_GUARD)
	for _i in range(smith_count):
		roles.append(ROLE_BLACKSMITH)
	for _i in range(merchant_count):
		roles.append(ROLE_MERCHANT)
	for _i in range(cleric_count):
		roles.append(ROLE_CLERIC)
	for _i in range(farmer_count):
		roles.append(ROLE_FARMER)
	for _i in range(elder_count):
		roles.append(ROLE_ELDER)
	var villager_toggle := false
	while roles.size() < npc_count:
		roles.append(ROLE_VILLAGER if villager_toggle else ROLE_VILLAGER_WOMAN)
		villager_toggle = not villager_toggle
	roles.resize(npc_count)
	_shuffle_ints(roles, rng)
	return roles

static func _pick_workplace(role: int, buildings: Dictionary, is_walkable: Callable, rng: RandomNumberGenerator, street_cells: Array[Vector2i], fallback: Vector2i) -> Vector2i:
	var preferences: Array = ROLE_WORKPLACES.get(role, []) as Array
	for type_variant: Variant in preferences:
		var cells := buildings.get(String(type_variant), []) as Array
		if cells.is_empty():
			continue
		for _attempt in 8:
			var cell := cells[rng.randi_range(0, cells.size() - 1)] as Vector2i
			if bool(is_walkable.call(cell)):
				return cell
	return _pick_from(street_cells, rng, fallback)

static func _pick_patrol_points(street_cells: Array[Vector2i], rng: RandomNumberGenerator) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	if street_cells.is_empty():
		return points
	for _i in range(3):
		points.append(street_cells[rng.randi_range(0, street_cells.size() - 1)])
	return points

## The mode an NPC should be in at the given hour.
static func mode_for_hour(state: Dictionary, hour: float) -> String:
	var sleeping := hour >= SLEEP_START_HOUR or hour < SLEEP_END_HOUR
	var role := int(state.get("role", ROLE_VILLAGER))
	if role == ROLE_GUARD:
		if sleeping and not bool(state.get("night_watch", false)):
			return MODE_SLEEP
		return MODE_PATROL
	if sleeping:
		return MODE_SLEEP
	if hour >= WORK_START_HOUR and hour < WORK_END_HOUR:
		return MODE_WORK
	return MODE_LEISURE

static func anchor_for_mode(state: Dictionary, mode: String) -> Vector2i:
	match mode:
		MODE_SLEEP:
			return state.get("home_anchor", Vector2i.ZERO) as Vector2i
		MODE_WORK:
			return state.get("work_anchor", Vector2i.ZERO) as Vector2i
		MODE_PATROL:
			var points_variant: Variant = state.get("patrol_points", [])
			var points := points_variant as Array
			if points.is_empty():
				return state.get("home_anchor", Vector2i.ZERO) as Vector2i
			var index := int(state.get("patrol_index", 0)) % points.size()
			return points[index] as Vector2i
		_:
			return state.get("leisure_anchor", Vector2i.ZERO) as Vector2i

static func _radius_for_mode(mode: String) -> int:
	match mode:
		MODE_SLEEP:
			return 0
		MODE_WORK:
			return 2
		MODE_PATROL:
			return 0
		_:
			return 5

## Per-frame update: clock-driven anchors + greedy walk, reusing the tavern
## service's facing/frame animation.
static func update_scheduled_npcs(
	delta: float,
	npc_states: Array[Dictionary],
	city_layer: TileMapLayer,
	rng: RandomNumberGenerator,
	tile_size: Vector2i,
	hour: float,
	is_npc_walkable: Callable,
	cell_center_position: Callable
) -> void:
	for state: Dictionary in npc_states:
		var sprite := state.get("sprite") as Sprite2D
		if sprite == null:
			continue

		var mode := mode_for_hour(state, hour)
		if String(state.get("mode", "")) != mode:
			state["mode"] = mode
			state["cooldown"] = 0.0

		var cooldown := float(state.get("cooldown", 0.0)) - delta
		var direction := state.get("direction", Vector2.ZERO) as Vector2
		var target := state.get("target", sprite.position) as Vector2

		if direction.length_squared() <= 0.0 and cooldown <= 0.0:
			var current_cell := city_layer.local_to_map(sprite.position)
			var anchor := anchor_for_mode(state, mode)
			var radius := _radius_for_mode(mode)
			var distance := _chebyshev(current_cell, anchor)

			if mode == MODE_PATROL and distance <= 1:
				state["patrol_index"] = int(state.get("patrol_index", 0)) + 1
				anchor = anchor_for_mode(state, mode)
				distance = _chebyshev(current_cell, anchor)

			var step := Vector2i.ZERO
			if distance > radius:
				step = _step_toward(current_cell, anchor, is_npc_walkable, rng)
			elif mode == MODE_SLEEP:
				step = Vector2i.ZERO
			elif rng.randf() < 0.6:
				step = _wander_step(current_cell, anchor, radius, is_npc_walkable, rng)

			if step != Vector2i.ZERO:
				var next_cell := current_cell + step
				direction = Vector2(step)
				target = cell_center_position.call(next_cell)
				state["facing_row"] = DwarfHoldTavernService.facing_row_from_direction(direction)
				cooldown = rng.randf_range(TRAVEL_COOLDOWN_RANGE.x, TRAVEL_COOLDOWN_RANGE.y) if distance > radius else rng.randf_range(WANDER_COOLDOWN_RANGE.x, WANDER_COOLDOWN_RANGE.y)
			else:
				cooldown = rng.randf_range(SLEEP_COOLDOWN_RANGE.x, SLEEP_COOLDOWN_RANGE.y) if mode == MODE_SLEEP else rng.randf_range(WANDER_COOLDOWN_RANGE.x, WANDER_COOLDOWN_RANGE.y)

		if direction.length_squared() > 0.0:
			var speed := float(state.get("speed", 40.0))
			sprite.position = sprite.position.move_toward(target, speed * delta)
			if sprite.position.distance_to(target) <= 0.5:
				sprite.position = target
				state["cell"] = city_layer.local_to_map(target)
				direction = Vector2.ZERO

		var frame_elapsed := float(state.get("frame_elapsed", 0.0)) + delta
		var frame := int(state.get("frame", 1))
		if direction.length_squared() > 0.0 and frame_elapsed >= DwarfHoldTavernService.TAVERN_FRAME_ADVANCE_SECONDS:
			frame_elapsed = 0.0
			frame = (frame + 1) % DwarfHoldTavernService.TAVERN_CHARACTER_COLUMNS
		elif direction.length_squared() <= 0.0:
			frame = 1
			frame_elapsed = 0.0

		DwarfHoldTavernService.update_character_frame(sprite, int(state.get("slot", 0)), frame, int(state.get("facing_row", 0)))

		state["cooldown"] = cooldown
		state["direction"] = direction
		state["target"] = target
		state["frame"] = frame
		state["frame_elapsed"] = frame_elapsed

## One greedy step toward the goal; when the best axis is blocked, tries the
## other axis, then any open cell so crowds squeeze around corners.
static func _step_toward(from_cell: Vector2i, to_cell: Vector2i, is_npc_walkable: Callable, rng: RandomNumberGenerator) -> Vector2i:
	var delta := to_cell - from_cell
	var candidates: Array[Vector2i] = []
	var primary := Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) else Vector2i(0, signi(delta.y))
	var secondary := Vector2i(0, signi(delta.y)) if absi(delta.x) >= absi(delta.y) else Vector2i(signi(delta.x), 0)
	if primary != Vector2i.ZERO:
		candidates.append(primary)
	if secondary != Vector2i.ZERO:
		candidates.append(secondary)
	var detours: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	_shuffle(detours, rng)
	for detour in detours:
		if not candidates.has(detour):
			candidates.append(detour)
	for candidate in candidates:
		if bool(is_npc_walkable.call(from_cell + candidate)):
			return candidate
	return Vector2i.ZERO

static func _wander_step(from_cell: Vector2i, anchor: Vector2i, radius: int, is_npc_walkable: Callable, rng: RandomNumberGenerator) -> Vector2i:
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	_shuffle(directions, rng)
	for direction in directions:
		var next_cell := from_cell + direction
		if _chebyshev(next_cell, anchor) > radius:
			continue
		if bool(is_npc_walkable.call(next_cell)):
			return direction
	return Vector2i.ZERO

static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

static func _walkable_neighbor(cell: Vector2i, is_walkable: Callable) -> Vector2i:
	var directions: Array[Vector2i] = [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]
	for direction in directions:
		if bool(is_walkable.call(cell + direction)):
			return cell + direction
	return Vector2i(2147483647, 2147483647)

static func _pick_from(cells: Array[Vector2i], rng: RandomNumberGenerator, fallback: Vector2i) -> Vector2i:
	if cells.is_empty():
		return fallback
	return cells[rng.randi_range(0, cells.size() - 1)]

static func _shuffle(values: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := values[i]
		values[i] = values[j]
		values[j] = swap

static func _shuffle_ints(values: Array[int], rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := values[i]
		values[i] = values[j]
		values[j] = swap
