extends RefCounted
class_name SettlementNpcScheduler

## Daily-life simulation for settlement NPCs (towns and dwarfholds).
## Each resident gets a role (matching their spritesheet slot), a home bed
## and a workplace; the game clock then drives where they head: work by
## day, leisure at the tavern and around the plaza in the morning and
## evening, home to bed at night. Guard-role NPCs patrol waypoints instead
## of working a building, and half of them keep a night watch. Commutes
## follow cached BFS paths (buildings have walls and single doors, so
## greedy steps alone pile residents against the masonry), with a random
## wander inside the anchor radius on arrival, reusing the tavern
## service's facing/frame animation.
##
## Role numbers are spritesheet slots; which slot means what is supplied
## by the calling scene through the assignment context ("role_quotas",
## "filler_roles", "guard_role", "green_role", "role_workplaces").

const MODE_SLEEP := "sleep"
const MODE_WORK := "work"
const MODE_LEISURE := "leisure"
const MODE_PATROL := "patrol"
const MODE_MEETING := "meeting"

const SLEEP_START_HOUR := 22.0
const SLEEP_END_HOUR := 6.0
const WORK_START_HOUR := 8.0
const WORK_END_HOUR := 18.0

const TRAVEL_COOLDOWN_RANGE := Vector2(0.05, 0.25)
const WANDER_COOLDOWN_RANGE := Vector2(0.8, 2.4)
const SLEEP_COOLDOWN_RANGE := Vector2(4.0, 9.0)

## Commute path computations allowed per update call; the rest of the
## crowd falls back to a greedy step this wake and asks again next time,
## so a whole town changing shift never floods one frame with flood fills.
const MAX_PATHS_PER_UPDATE := 3
static var _path_budget := 0

## Assigns roles, homes and workplaces to freshly spawned NPC states.
## context keys:
##   "bed_cells": Array[Vector2i] (impassable bed decor cells)
##   "building_cells_by_type": Dictionary type -> Array[Vector2i]
##   "street_cells": Array[Vector2i] (walkable street/plaza cells)
##   "green_cells": Array[Vector2i] (walkable open grass cells)
##   "is_walkable": Callable(Vector2i) -> bool
##   "rng": RandomNumberGenerator
##   "role_quotas": Array of {"role": int, "count": int}
##   "filler_roles": Array[int] used to round-robin the remainder
##   "guard_role": int (slot that patrols; -1 for none)
##   "green_role": int (slot that works open green cells; -1 for none)
##   "role_workplaces": Dictionary role -> Array[String] building types
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
	var guard_role := int(context.get("guard_role", -1))
	var green_role := int(context.get("green_role", -1))
	var role_workplaces := context.get("role_workplaces", {}) as Dictionary
	# Where the settlement drinks: taverns and inns soak up a share of
	# everyone's off-hours so common rooms actually fill in the evening.
	var social_cells: Array[Vector2i] = []
	for social_type: String in ["tavern", "inn"]:
		for social_variant: Variant in (buildings.get(social_type, []) as Array):
			var social_cell := social_variant as Vector2i
			if bool(is_walkable.call(social_cell)):
				social_cells.append(social_cell)

	var roles := _build_role_list(npc_states.size(), context.get("role_quotas", []) as Array, context.get("filler_roles", []) as Array, rng)
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
		state["is_guard"] = role == guard_role
		if role == guard_role:
			state["patrol_points"] = _pick_patrol_points(street_cells, rng)
			state["patrol_index"] = 0
			state["work_anchor"] = home_anchor
			state["night_watch"] = (npc_index % 2) == 0
		elif role == green_role and not green_cells.is_empty():
			state["work_anchor"] = _pick_from(green_cells, rng, home_anchor)
		else:
			state["work_anchor"] = _pick_workplace(role, role_workplaces, buildings, is_walkable, rng, street_cells, home_anchor)

		# Leisure: a stool at the tavern for some, the market streets for
		# the rest.
		if not social_cells.is_empty() and rng.randf() < 0.45:
			state["leisure_anchor"] = _pick_from(social_cells, rng, home_anchor)
		else:
			state["leisure_anchor"] = _pick_from(street_cells, rng, home_anchor)
		# Nobody keeps the bell-tower's exact hours: each resident rises,
		# clocks in and turns in a little early or late, so shift changes
		# ripple through the settlement instead of moving it in lock-step.
		state["schedule_jitter"] = rng.randf_range(-0.7, 0.7)
		state["mode"] = ""

## Role composition from caller-supplied quotas, padded with filler roles.
static func _build_role_list(npc_count: int, role_quotas: Array, filler_roles: Array, rng: RandomNumberGenerator) -> Array[int]:
	var roles: Array[int] = []
	for quota_variant: Variant in role_quotas:
		var quota := quota_variant as Dictionary
		var role := int(quota.get("role", 0))
		for _i in range(maxi(0, int(quota.get("count", 0)))):
			roles.append(role)
	var filler_index := 0
	while roles.size() < npc_count:
		if filler_roles.is_empty():
			roles.append(0)
		else:
			roles.append(int(filler_roles[filler_index % filler_roles.size()]))
		filler_index += 1
	roles.resize(npc_count)
	_shuffle_ints(roles, rng)
	return roles

static func _pick_workplace(role: int, role_workplaces: Dictionary, buildings: Dictionary, is_walkable: Callable, rng: RandomNumberGenerator, street_cells: Array[Vector2i], fallback: Vector2i) -> Vector2i:
	var preferences: Array = role_workplaces.get(role, []) as Array
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
	# Sworn faction members answer the meeting bell before anything else -
	# including sleep, which is how the midnight cults get their crowds.
	var meeting_hour := float(state.get("faction_meeting_hour", -1.0))
	if meeting_hour >= 0.0 and fposmod(hour - meeting_hour, 24.0) < SettlementFactionService.MEETING_DURATION_HOURS:
		return MODE_MEETING
	# Meetings answer the true bell; everything else runs on the NPC's own
	# slightly-off personal clock so the town never moves in lock-step.
	var personal_hour := fposmod(hour + float(state.get("schedule_jitter", 0.0)), 24.0)
	var sleeping := personal_hour >= SLEEP_START_HOUR or personal_hour < SLEEP_END_HOUR
	# Nocturnal citizens sleep through the working day and walk the night.
	if bool(state.get("nocturnal", false)):
		sleeping = personal_hour >= 8.0 and personal_hour < 18.0
	if bool(state.get("is_guard", false)):
		if sleeping and not bool(state.get("night_watch", false)):
			return MODE_SLEEP
		return MODE_PATROL
	if sleeping:
		return MODE_SLEEP
	if personal_hour >= WORK_START_HOUR and personal_hour < WORK_END_HOUR:
		return MODE_WORK
	return MODE_LEISURE

static func anchor_for_mode(state: Dictionary, mode: String) -> Vector2i:
	match mode:
		MODE_SLEEP:
			return state.get("home_anchor", Vector2i.ZERO) as Vector2i
		MODE_WORK:
			return state.get("work_anchor", Vector2i.ZERO) as Vector2i
		MODE_MEETING:
			return state.get("faction_meeting_anchor", state.get("leisure_anchor", Vector2i.ZERO)) as Vector2i
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
		MODE_MEETING:
			return 2
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
	_path_budget = MAX_PATHS_PER_UPDATE
	for state: Dictionary in npc_states:
		var sprite := state.get("sprite") as Sprite2D
		if sprite == null:
			continue

		var mode := mode_for_hour(state, hour)
		if String(state.get("mode", "")) != mode:
			state["mode"] = mode
			# A short random dawdle before setting out staggers departures
			# (and spreads the path computations across many frames).
			state["cooldown"] = rng.randf_range(0.0, 2.0)
			state.erase("travel_path")
			_update_sleep_tag(sprite, false)

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
				# Homes and workplaces sit behind walls with a single door;
				# greedy steps lose themselves against the masonry, so every
				# commute follows a real path (greedy only as a stopgap when
				# the path budget or an unreachable goal leaves none).
				step = _travel_path_step(state, current_cell, anchor, is_npc_walkable)
				if step == Vector2i.ZERO:
					step = _step_toward(current_cell, anchor, is_npc_walkable, rng)
			elif mode == MODE_SLEEP:
				step = Vector2i.ZERO
				_update_sleep_tag(sprite, true)
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

		# Rewrite the sprite region only when the visible frame changed;
		# idle crowds otherwise cost a region write per NPC per frame.
		var facing_row := int(state.get("facing_row", 0))
		var frame_key := facing_row * 16 + frame
		if int(state.get("frame_key", -1)) != frame_key:
			state["frame_key"] = frame_key
			if bool(state.get("composed", false)):
				# DF-style composed citizens are single-pose; they face
				# their walk by mirroring.
				if facing_row == 1:
					sprite.flip_h = false
				elif facing_row == 2:
					sprite.flip_h = true
			else:
				DwarfHoldTavernService.update_character_frame(sprite, int(state.get("slot", 0)), frame, facing_row)

		state["cooldown"] = cooldown
		state["direction"] = direction
		state["target"] = target
		state["frame"] = frame
		state["frame_elapsed"] = frame_elapsed

## One greedy step toward the goal; when the best axis is blocked, tries the
## other axis, then any open cell so crowds squeeze around corners.
const CARDINAL_DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

static func _step_toward(from_cell: Vector2i, to_cell: Vector2i, is_npc_walkable: Callable, rng: RandomNumberGenerator) -> Vector2i:
	var delta := to_cell - from_cell
	var primary := Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) else Vector2i(0, signi(delta.y))
	var secondary := Vector2i(0, signi(delta.y)) if absi(delta.x) >= absi(delta.y) else Vector2i(signi(delta.x), 0)
	if primary != Vector2i.ZERO and bool(is_npc_walkable.call(from_cell + primary)):
		return primary
	if secondary != Vector2i.ZERO and bool(is_npc_walkable.call(from_cell + secondary)):
		return secondary
	# Detours walk the fixed cardinal list from a random start so crowds
	# still squeeze around corners without per-call array churn.
	var start := rng.randi_range(0, 3)
	for offset in 4:
		var detour := CARDINAL_DIRECTIONS[(start + offset) % 4]
		if detour == primary or detour == secondary:
			continue
		if bool(is_npc_walkable.call(from_cell + detour)):
			return detour
	return Vector2i.ZERO

## Follows (and lazily computes) a BFS path to the current anchor. The
## path is cached on the state and rebuilt when the goal moves (a patrol
## waypoint advances, a mode changes) or a cell along it closes.
static func _travel_path_step(state: Dictionary, from_cell: Vector2i, anchor: Vector2i, is_npc_walkable: Callable) -> Vector2i:
	if (state.get("travel_goal", Vector2i(2147483647, 2147483647)) as Vector2i) != anchor:
		state["travel_goal"] = anchor
		state.erase("travel_path")
		state.erase("travel_bfs_backoff")
	var path_variant: Variant = state.get("travel_path")
	if path_variant is Array:
		var path := path_variant as Array
		if not path.is_empty():
			var next := path[0] as Vector2i
			if _chebyshev(from_cell, next) <= 1 and bool(is_npc_walkable.call(next)):
				path.remove_at(0)
				return next - from_cell
		# Stale or blocked: fall through and plot afresh.
		state.erase("travel_path")
	# An unreachable goal shouldn't cost a flood fill on every wake.
	var backoff := int(state.get("travel_bfs_backoff", 0))
	if backoff > 0:
		state["travel_bfs_backoff"] = backoff - 1
		return Vector2i.ZERO
	if _path_budget <= 0:
		return Vector2i.ZERO
	_path_budget -= 1
	var fresh_path := _bfs_path(from_cell, anchor, is_npc_walkable)
	state["travel_path"] = fresh_path
	if fresh_path.is_empty():
		state["travel_bfs_backoff"] = 24
		return Vector2i.ZERO
	var first := fresh_path[0] as Vector2i
	fresh_path.remove_at(0)
	return first - from_cell

const TRAVEL_PATH_VISIT_CAP := 16384

static func _bfs_path(from_cell: Vector2i, to_cell: Vector2i, is_npc_walkable: Callable) -> Array:
	if from_cell == to_cell:
		return []
	var queue: Array[Vector2i] = [from_cell]
	var came_from: Dictionary = {from_cell: from_cell}
	var head := 0
	var found := false
	while head < queue.size() and came_from.size() < TRAVEL_PATH_VISIT_CAP:
		var current := queue[head]
		head += 1
		if current == to_cell:
			found = true
			break
		for direction: Vector2i in CARDINAL_DIRECTIONS:
			var next := current + direction
			if came_from.has(next):
				continue
			if next != to_cell and not bool(is_npc_walkable.call(next)):
				continue
			came_from[next] = current
			queue.append(next)
	if not found:
		return []
	var reversed: Array[Vector2i] = []
	var cursor := to_cell
	while cursor != from_cell:
		reversed.append(cursor)
		cursor = came_from[cursor] as Vector2i
	var path: Array = []
	for i in range(reversed.size() - 1, -1, -1):
		path.append(reversed[i])
	return path

static func _wander_step(from_cell: Vector2i, anchor: Vector2i, radius: int, is_npc_walkable: Callable, rng: RandomNumberGenerator) -> Vector2i:
	var start := rng.randi_range(0, 3)
	for offset in 4:
		var direction := CARDINAL_DIRECTIONS[(start + offset) % 4]
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

const SLEEP_TAG_NAME := "SleepTag"

## A little "z Z" over a resident who has actually reached their bed, so
## the night shift of the schedule reads at a glance.
static func _update_sleep_tag(sprite: Sprite2D, asleep: bool) -> void:
	var tag := sprite.get_node_or_null(SLEEP_TAG_NAME) as Label
	if not asleep:
		if tag != null:
			tag.visible = false
		return
	if tag == null:
		tag = Label.new()
		tag.name = SLEEP_TAG_NAME
		tag.text = "z Z"
		tag.add_theme_font_size_override("font_size", 8)
		tag.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.85))
		tag.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.2, 0.8))
		tag.add_theme_constant_override("outline_size", 2)
		tag.position = Vector2(4.0, -24.0)
		tag.z_index = 30
		sprite.add_child(tag)
	tag.visible = true
