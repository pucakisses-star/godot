extends RefCounted
class_name SettlementNpcScheduler

## Daily-life simulation for settlement NPCs (towns and dwarfholds).
## Each resident gets a role (matching their spritesheet slot), a home bed
## and a workplace; the game clock then drives where they head: work by
## day, leisure in the evening, home to bed at night. Guard-role NPCs
## patrol waypoints instead of working a building, and half of them keep
## a night watch. Commutes follow cached BFS paths (buildings have walls
## and single doors, so greedy steps alone pile residents against the
## masonry), reusing the tavern service's facing/frame animation.
##
## Inside a shift nobody mills at random: every resident runs on NEEDS
## (thirst, faith, company, recreation, errands) that build over time.
## Off-shift they plan an objective against the settlement's venues —
## drink at the tavern, pray at the temple, browse the market, visit a
## friend or kinsdwarf and chat — walk there, engage for a while, and
## sate the need. Workers rotate between task stations around their
## workplace and take a tavern lunch when the town has one. At night a
## dwarf with a claimed bed lies down IN it. Whatever they're doing is
## written to state.activity_label, so inspection UIs can show the goal.
##
## Role numbers are spritesheet slots; which slot means what is supplied
## by the calling scene through the assignment context ("role_quotas",
## "filler_roles", "guard_role", "green_role", "role_workplaces").

const MODE_SLEEP := "sleep"
const MODE_WORK := "work"
const MODE_LEISURE := "leisure"
const MODE_PATROL := "patrol"
const MODE_MEETING := "meeting"
const MODE_SHELTER := "shelter"

const SLEEP_START_HOUR := 22.0
const SLEEP_END_HOUR := 6.0
const WORK_START_HOUR := 8.0
const WORK_END_HOUR := 18.0

const TRAVEL_COOLDOWN_RANGE := Vector2(0.05, 0.25)
const WANDER_COOLDOWN_RANGE := Vector2(0.8, 2.4)
const SLEEP_COOLDOWN_RANGE := Vector2(4.0, 9.0)

## --- Needs & objectives -----------------------------------------------------
## Every resident carries a small set of Dwarf-Fortress-style needs that
## climb in real time; the most pressing one with an available venue
## becomes their next objective. Rates are per real second, tuned so a
## full evening of leisure cycles through two or three objectives.
const NEED_RATES := {
	"drink": 0.014,
	"social": 0.011,
	"worship": 0.008,
	"market": 0.009,
	"recreation": 0.010
}
## Which venue building types can sate a need, in preference order.
const NEED_VENUES := {
	"drink": ["tavern", "inn"],
	"worship": ["temple", "chapel", "church", "shrine"],
	"market": ["market_stall", "general_store", "auction_house", "bakery"],
	"recreation": ["park", "bathhouse", "museum", "library", "archives"]
}
## What engaging at a venue reads as on the inspection card.
const VENUE_LABELS := {
	"tavern": "drinking at the tavern",
	"inn": "drinking at the inn",
	"temple": "praying at the temple",
	"chapel": "praying at the chapel",
	"church": "praying at the church",
	"shrine": "praying at the shrine",
	"market_stall": "browsing the market",
	"general_store": "browsing the shops",
	"auction_house": "watching the auctions",
	"bakery": "buying bread",
	"park": "resting in the park",
	"bathhouse": "enjoying the baths",
	"museum": "admiring the museum",
	"library": "reading in the library",
	"archives": "reading in the archives"
}
## Destination phrasing while walking there ("off to %s").
const VENUE_GOALS := {
	"tavern": "the tavern",
	"inn": "the inn",
	"temple": "the temple",
	"chapel": "the chapel",
	"church": "the church",
	"shrine": "the shrine",
	"market_stall": "the market",
	"general_store": "the shops",
	"auction_house": "the auction house",
	"bakery": "the bakery",
	"park": "the park",
	"bathhouse": "the baths",
	"museum": "the museum",
	"library": "the library",
	"archives": "the archives"
}
## Work reads as the trade, not as "standing around".
const WORK_LABELS := {
	"forge": "hammering at the forge",
	"smithy": "hammering at the forge",
	"smeltery": "feeding the smelter",
	"brewery": "minding the mash",
	"tavern": "keeping the taproom",
	"inn": "keeping the inn",
	"bakery": "baking the day's bread",
	"kitchen": "cooking",
	"market_stall": "minding the stall",
	"general_store": "minding the counter",
	"temple": "tending the altar",
	"chapel": "tending the altar",
	"church": "tending the altar",
	"archives": "copying records",
	"library": "shelving books",
	"runesmith_sanctum": "graving runes",
	"gemcutters_studio": "cutting gems",
	"bank_vaults": "counting coin",
	"barber_shop": "cutting hair",
	"tannery": "scraping hides"
}
const ACTIVITY_ENGAGE_SECONDS := Vector2(8.0, 18.0)
const WORK_STATION_SECONDS := Vector2(6.0, 14.0)
const LUNCH_START_HOUR := 12.0
const LUNCH_END_HOUR := 13.0

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
	var house_cells: Array[Vector2i] = []
	for house_variant: Variant in (context.get("house_cells", []) as Array):
		house_cells.append(house_variant as Vector2i)
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

		# Home: a bed of their own — the bedside cell is the anchor, the
		# bed itself is claimed so its owner can lie IN it at night.
		var home_anchor := Vector2i(2147483647, 2147483647)
		while bed_index < bed_cells.size():
			var bed := bed_cells[bed_index]
			var candidate := _walkable_neighbor(bed, is_walkable)
			bed_index += 1
			if candidate.x != 2147483647:
				home_anchor = candidate
				state["bed_cell"] = bed
				break
		# Out of beds: bunk on a house floor rather than in the street, so
		# nobody sleeps standing in an open corridor.
		if home_anchor.x == 2147483647 and not house_cells.is_empty():
			home_anchor = house_cells[rng.randi_range(0, house_cells.size() - 1)]
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
	# Shuffle before truncating: when the quota counts oversubscribe a
	# small settlement, resize would otherwise always drop the same
	# last-listed roles (the elder vanishes every time). Shuffling first
	# spreads the loss across the roster.
	_shuffle_ints(roles, rng)
	roles.resize(npc_count)
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

## The mode an NPC should be in at the given hour. shelter (a storm rages
## outside) sends only the off-duty home: workers keep working, guards
## keep patrolling, meetings still gather.
static func mode_for_hour(state: Dictionary, hour: float, shelter := false) -> String:
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
	if shelter:
		return MODE_SHELTER
	return MODE_LEISURE

static func anchor_for_mode(state: Dictionary, mode: String) -> Vector2i:
	match mode:
		MODE_SLEEP:
			return state.get("home_anchor", Vector2i.ZERO) as Vector2i
		MODE_SHELTER:
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
		MODE_SHELTER:
			return 1
		MODE_WORK:
			return 2
		MODE_PATROL:
			return 0
		MODE_MEETING:
			return 2
		_:
			return 5

## Per-frame update: clock-driven anchors, needs-driven objectives, and
## pathed walks, reusing the tavern service's facing/frame animation.
## pois: venue type -> Array of walkable Vector2i cells (build_poi_table).
static func update_scheduled_npcs(
	delta: float,
	npc_states: Array[Dictionary],
	city_layer: TileMapLayer,
	rng: RandomNumberGenerator,
	tile_size: Vector2i,
	hour: float,
	is_npc_walkable: Callable,
	cell_center_position: Callable,
	shelter := false,
	pois: Dictionary = {}
) -> void:
	_path_budget = MAX_PATHS_PER_UPDATE
	for state: Dictionary in npc_states:
		var sprite := state.get("sprite") as Sprite2D
		if sprite == null:
			continue

		_raise_needs(state, delta, rng)
		# A running engagement burns down in real time; on completion the
		# need it served is sated and the resident plans afresh.
		var running := state.get("activity", {}) as Dictionary
		if not running.is_empty() and bool(running.get("engaged", false)):
			running["remaining"] = float(running.get("remaining", 0.0)) - delta
			if float(running["remaining"]) <= 0.0:
				var sated := String(running.get("need", ""))
				var needs := state.get("needs", {}) as Dictionary
				if not sated.is_empty() and needs.has(sated):
					needs[sated] = 0.0
				# A chat seen through to its end is a shared moment; leave the
				# partner's name so the scene can settle it into the pair's bond.
				if String(running.get("kind", "")) == "social":
					state["social_call_done"] = String(running.get("partner", ""))
				state.erase("activity")

		var mode := mode_for_hour(state, hour, shelter)
		if String(state.get("mode", "")) != mode:
			state["mode"] = mode
			# A short random dawdle before setting out staggers departures
			# (and spreads the path computations across many frames).
			state["cooldown"] = rng.randf_range(0.0, 2.0)
			state.erase("travel_path")
			state.erase("activity")
			_update_sleep_tag(sprite, false)
			_leave_bed(state, sprite, cell_center_position)

		var cooldown := float(state.get("cooldown", 0.0)) - delta
		var direction := state.get("direction", Vector2.ZERO) as Vector2
		var target := state.get("target", sprite.position) as Vector2

		if direction.length_squared() <= 0.0 and cooldown <= 0.0:
			var current_cell := city_layer.local_to_map(sprite.position)
			var anchor := anchor_for_mode(state, mode)
			var radius := _radius_for_mode(mode)

			if mode == MODE_PATROL and _chebyshev(current_cell, anchor) <= 1:
				state["patrol_index"] = int(state.get("patrol_index", 0)) + 1
				anchor = anchor_for_mode(state, mode)
			# Already tucked in: the bed IS the anchor, or the sleeper would
			# march back to the bedside cell and hop in again forever.
			if mode == MODE_SLEEP and bool(state.get("in_bed", false)):
				anchor = state.get("bed_cell", anchor) as Vector2i

			# Work and leisure run on objectives, not on loitering: the
			# activity (a venue visit, a task station, a social call)
			# overrides the mode's plain anchor while it lasts.
			var activity := _ensure_activity(state, mode, npc_states, pois, rng, hour, is_npc_walkable)
			if not activity.is_empty():
				anchor = _activity_anchor(state, activity, npc_states, anchor)
				radius = int(activity.get("radius", 1))
			var distance := _chebyshev(current_cell, anchor)

			var step := Vector2i.ZERO
			if distance > radius:
				# Homes and workplaces sit behind walls with a single door;
				# greedy steps lose themselves against the masonry, so every
				# commute follows a real path (greedy only as a stopgap when
				# the path budget or an unreachable goal leaves none).
				step = _travel_path_step(state, current_cell, anchor, is_npc_walkable)
				if step == Vector2i.ZERO:
					step = _step_toward(current_cell, anchor, is_npc_walkable, rng)
				if not activity.is_empty():
					_set_label(state, "off to %s" % String(activity.get("goal", "an errand")))
				elif mode == MODE_SLEEP:
					_set_label(state, "heading home to sleep")
				elif mode == MODE_SHELTER:
					_set_label(state, "hurrying out of the storm")
				elif mode == MODE_MEETING:
					_set_label(state, "answering the meeting bell")
				elif mode == MODE_PATROL:
					_set_label(state, "on patrol")
				else:
					_set_label(state, "")
				# A traveller who can't advance this wake shouldn't report
				# an unreachable errand forever; give up and replan.
				if step == Vector2i.ZERO and not activity.is_empty() and int(state.get("travel_bfs_backoff", 0)) > 0:
					state.erase("activity")
			elif mode == MODE_SLEEP:
				step = Vector2i.ZERO
				_update_sleep_tag(sprite, true)
				_lie_in_bed(state, sprite, cell_center_position)
				_set_label(state, "asleep in bed" if bool(state.get("in_bed", false)) else "asleep on their feet")
			elif mode == MODE_PATROL:
				_set_label(state, "keeping the night watch" if bool(state.get("night_watch", false)) else "on patrol")
			elif mode == MODE_MEETING:
				_set_label(state, "at a gathering")
			elif mode == MODE_SHELTER:
				_set_label(state, "sheltering from the storm")
			elif not activity.is_empty():
				# ARRIVED: engage the objective — face it, hold the spot,
				# and let the countdown at the top of the loop run it out.
				step = _engage_activity(state, activity, current_cell, npc_states, is_npc_walkable, rng)
			else:
				_set_label(state, "")
				if rng.randf() < 0.6:
					step = _wander_step(current_cell, anchor, radius, is_npc_walkable, rng)

			if step != Vector2i.ZERO:
				var next_cell := current_cell + step
				direction = Vector2(step)
				target = cell_center_position.call(next_cell)
				state["facing_row"] = DwarfHoldTavernService.facing_row_from_direction(direction)
				cooldown = rng.randf_range(TRAVEL_COOLDOWN_RANGE.x, TRAVEL_COOLDOWN_RANGE.y) if distance > radius else rng.randf_range(WANDER_COOLDOWN_RANGE.x, WANDER_COOLDOWN_RANGE.y)
			elif not activity.is_empty() and distance <= radius:
				# Engaged residents re-check often (to keep facing a moving
				# chat partner and to count the engagement down).
				cooldown = rng.randf_range(0.6, 1.2)
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

## --- Needs, objectives & beds -------------------------------------------

## Filters each known venue type's cells down to walkable ones. Scenes
## call this once after generation and hand the table to every
## update_scheduled_npcs call.
static func build_poi_table(building_cells_by_type: Dictionary, is_walkable: Callable) -> Dictionary:
	var pois: Dictionary = {}
	var wanted: Dictionary = {}
	for need_variant: Variant in NEED_VENUES.values():
		for venue_variant: Variant in need_variant as Array:
			wanted[String(venue_variant)] = true
	for venue_type_variant: Variant in building_cells_by_type.keys():
		var venue_type := String(venue_type_variant)
		if not wanted.has(venue_type):
			continue
		var open_cells: Array = []
		for cell_variant: Variant in (building_cells_by_type[venue_type_variant] as Array):
			var cell := cell_variant as Vector2i
			if bool(is_walkable.call(cell)):
				open_cells.append(cell)
		if not open_cells.is_empty():
			pois[venue_type] = open_cells
	return pois

## Needs climb in real time, seeded at a random level so the whole
## settlement doesn't get thirsty in unison.
static func _raise_needs(state: Dictionary, delta: float, rng: RandomNumberGenerator) -> void:
	var needs := state.get("needs", {}) as Dictionary
	if needs.is_empty():
		for need_variant: Variant in NEED_RATES.keys():
			needs[String(need_variant)] = rng.randf_range(0.0, 0.6)
		state["needs"] = needs
	for need_variant: Variant in NEED_RATES.keys():
		var need := String(need_variant)
		needs[need] = minf(float(needs[need]) + float(NEED_RATES[need]) * delta, 1.5)

static func _set_label(state: Dictionary, text: String) -> void:
	state["activity_label"] = text

## Returns the state's current activity, planning a new one when idle.
## Activities: {"kind", "need", "cell"/"partner", "label", "remaining",
## "radius", "engaged"}.
static func _ensure_activity(
	state: Dictionary,
	mode: String,
	npc_states: Array[Dictionary],
	pois: Dictionary,
	rng: RandomNumberGenerator,
	hour: float,
	is_npc_walkable: Callable
) -> Dictionary:
	if mode != MODE_WORK and mode != MODE_LEISURE:
		return {}
	var activity := state.get("activity", {}) as Dictionary
	if not activity.is_empty():
		return activity
	if mode == MODE_WORK:
		activity = _plan_work_activity(state, pois, rng, hour, is_npc_walkable)
	else:
		activity = _plan_leisure_activity(state, npc_states, pois, rng)
	if not activity.is_empty():
		state["activity"] = activity
	return activity

## Workers rotate between task stations around their workplace; when the
## settlement pours ale, midday is spent at the tavern instead.
static func _plan_work_activity(
	state: Dictionary,
	pois: Dictionary,
	rng: RandomNumberGenerator,
	hour: float,
	is_npc_walkable: Callable
) -> Dictionary:
	var personal_hour := fposmod(hour + float(state.get("schedule_jitter", 0.0)), 24.0)
	if personal_hour >= LUNCH_START_HOUR and personal_hour < LUNCH_END_HOUR:
		var lunch_cell := _pick_venue_cell(["tavern", "inn"], pois, rng)
		if lunch_cell.x != 2147483647:
			return {
				"kind": "venue", "need": "drink", "cell": lunch_cell,
				"label": "taking lunch at the tavern",
				"goal": "the tavern for lunch",
				"remaining": rng.randf_range(ACTIVITY_ENGAGE_SECONDS.x, ACTIVITY_ENGAGE_SECONDS.y),
				"radius": 1, "engaged": false
			}
	var work_anchor := state.get("work_anchor", Vector2i(2147483647, 2147483647)) as Vector2i
	if work_anchor.x == 2147483647:
		return {}
	var station := work_anchor
	for _attempt in 6:
		var candidate := work_anchor + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
		if candidate != work_anchor and bool(is_npc_walkable.call(candidate)):
			station = candidate
			break
	var trade := String(state.get("staffed_building_type", ""))
	var label := String(WORK_LABELS.get(trade, "hard at work"))
	if bool(state.get("is_ruler", false)):
		label = "holding court"
	return {
		"kind": "station", "need": "", "cell": station,
		"label": label,
		"goal": "their post",
		"remaining": rng.randf_range(WORK_STATION_SECONDS.x, WORK_STATION_SECONDS.y),
		"radius": 0, "engaged": false
	}

## Off-shift, the most pressing need with an open venue wins: a drink, a
## prayer, an errand, a bath — or calling on kin for a chat. With nothing
## pressing (or nowhere to go), an evening stroll still has a name.
static func _plan_leisure_activity(
	state: Dictionary,
	npc_states: Array[Dictionary],
	pois: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var needs := state.get("needs", {}) as Dictionary
	var need_keys: Array = needs.keys()
	need_keys.sort_custom(func(left: Variant, right: Variant) -> bool:
		return float(needs[left]) > float(needs[right]))
	for need_variant: Variant in need_keys:
		var need := String(need_variant)
		if float(needs[need]) < 0.55:
			break
		if need == "social":
			var partner_name := _pick_chat_partner(state, npc_states, rng)
			if partner_name.is_empty():
				continue
			return {
				"kind": "social", "need": "social", "partner": partner_name,
				"label": "calling on %s" % partner_name.get_slice(" ", 0),
				"goal": "call on %s" % partner_name.get_slice(" ", 0),
				"remaining": rng.randf_range(ACTIVITY_ENGAGE_SECONDS.x, ACTIVITY_ENGAGE_SECONDS.y),
				"radius": 1, "engaged": false
			}
		var venue_types := NEED_VENUES.get(need, []) as Array
		var venue_cell := Vector2i(2147483647, 2147483647)
		var venue_label := ""
		var venue_goal := ""
		for venue_type_variant: Variant in venue_types:
			var venue_type := String(venue_type_variant)
			var cells := pois.get(venue_type, []) as Array
			if cells.is_empty():
				continue
			venue_cell = cells[rng.randi_range(0, cells.size() - 1)] as Vector2i
			venue_label = String(VENUE_LABELS.get(venue_type, "running an errand"))
			venue_goal = String(VENUE_GOALS.get(venue_type, "an errand"))
			break
		if venue_cell.x == 2147483647:
			continue
		return {
			"kind": "venue", "need": need, "cell": venue_cell,
			"label": venue_label,
			"goal": venue_goal,
			"remaining": rng.randf_range(ACTIVITY_ENGAGE_SECONDS.x, ACTIVITY_ENGAGE_SECONDS.y),
			"radius": 1, "engaged": false
		}
	## Nothing urgent: a named stroll near their haunt (sates recreation).
	return {
		"kind": "stroll", "need": "recreation",
		"cell": state.get("leisure_anchor", Vector2i.ZERO) as Vector2i,
		"label": "taking the evening air",
		"goal": "their favorite haunt",
		"remaining": rng.randf_range(ACTIVITY_ENGAGE_SECONDS.x, ACTIVITY_ENGAGE_SECONDS.y),
		"radius": 3, "engaged": false
	}

## Kin first (spouse, then parents/children living in the roster), then
## any fellow resident, so chats reflect the census.
static func _pick_chat_partner(state: Dictionary, npc_states: Array[Dictionary], rng: RandomNumberGenerator) -> String:
	var own_name := String(state.get("npc_name", ""))
	var identity := state.get("identity", {}) as Dictionary
	var preferred: Array[String] = []
	var spouse := String(identity.get("spouse", ""))
	if not spouse.is_empty():
		preferred.append(spouse)
	for list_key: String in ["children", "parents"]:
		for kin_variant: Variant in (identity.get(list_key, []) as Array):
			preferred.append(String(kin_variant))
	for kin_name: String in preferred:
		if not kin_name.is_empty() and kin_name != own_name and _find_state_by_name(npc_states, kin_name) >= 0:
			return kin_name
	if npc_states.size() <= 1:
		return ""
	for _attempt in 4:
		var other := npc_states[rng.randi_range(0, npc_states.size() - 1)]
		var other_name := String(other.get("npc_name", ""))
		if not other_name.is_empty() and other_name != own_name:
			return other_name
	return ""

static func _find_state_by_name(npc_states: Array[Dictionary], npc_name: String) -> int:
	for index in npc_states.size():
		if String(npc_states[index].get("npc_name", "")) == npc_name:
			return index
	return -1

## Where the activity wants the resident: a fixed venue cell, or the
## chat partner's CURRENT cell (kept fresh so the path follows them).
static func _activity_anchor(state: Dictionary, activity: Dictionary, npc_states: Array[Dictionary], fallback: Vector2i) -> Vector2i:
	if String(activity.get("kind", "")) == "social":
		var partner_index := _find_state_by_name(npc_states, String(activity.get("partner", "")))
		if partner_index < 0:
			state.erase("activity")
			return fallback
		return npc_states[partner_index].get("cell", fallback) as Vector2i
	return activity.get("cell", fallback) as Vector2i

## On arrival: mark the activity engaged, face what it's about, and pull
## an idle chat partner into the conversation. Strolls keep drifting
## inside their radius; everything else holds its spot.
static func _engage_activity(
	state: Dictionary,
	activity: Dictionary,
	current_cell: Vector2i,
	npc_states: Array[Dictionary],
	is_npc_walkable: Callable,
	rng: RandomNumberGenerator
) -> Vector2i:
	activity["engaged"] = true
	_set_label(state, String(activity.get("label", "")))
	var kind := String(activity.get("kind", ""))
	if kind == "social":
		var partner_index := _find_state_by_name(npc_states, String(activity.get("partner", "")))
		if partner_index >= 0:
			var partner := npc_states[partner_index]
			var partner_cell := partner.get("cell", current_cell) as Vector2i
			var toward := partner_cell - current_cell
			if toward != Vector2i.ZERO:
				state["facing_row"] = DwarfHoldTavernService.facing_row_from_direction(Vector2(toward))
			# An idle off-shift partner turns to answer: both hold still,
			# face each other, and wear the conversation on their card.
			if String(partner.get("mode", "")) == MODE_LEISURE and (partner.get("direction", Vector2.ZERO) as Vector2).length_squared() <= 0.0:
				partner["facing_row"] = DwarfHoldTavernService.facing_row_from_direction(Vector2(-toward))
				partner["cooldown"] = maxf(float(partner.get("cooldown", 0.0)), 1.5)
				_set_label(partner, "chatting with %s" % String(state.get("npc_name", "someone")).get_slice(" ", 0))
			_set_label(state, "chatting with %s" % String(activity.get("partner", "someone")).get_slice(" ", 0))
		return Vector2i.ZERO
	if kind == "stroll":
		return _wander_step(current_cell, activity.get("cell", current_cell) as Vector2i, int(activity.get("radius", 3)), is_npc_walkable, rng)
	var focus := activity.get("cell", current_cell) as Vector2i
	var toward_focus := focus - current_cell
	if toward_focus != Vector2i.ZERO:
		state["facing_row"] = DwarfHoldTavernService.facing_row_from_direction(Vector2(toward_focus))
	return Vector2i.ZERO

## A dwarf with a claimed bed sleeps IN it: the sprite lies sideways on
## the bed cell (the zZ tag counter-rotates to stay readable).
static func _lie_in_bed(state: Dictionary, sprite: Sprite2D, cell_center_position: Callable) -> void:
	if bool(state.get("in_bed", false)):
		return
	var bed_variant: Variant = state.get("bed_cell")
	if not (bed_variant is Vector2i):
		return
	var bed := bed_variant as Vector2i
	sprite.position = cell_center_position.call(bed)
	sprite.rotation_degrees = 90.0
	state["cell"] = bed
	state["target"] = sprite.position
	state["in_bed"] = true
	var tag := sprite.get_node_or_null(SLEEP_TAG_NAME) as Label
	if tag != null:
		tag.rotation_degrees = -90.0

## Waking up steps back off the bed onto the bedside anchor.
static func _leave_bed(state: Dictionary, sprite: Sprite2D, cell_center_position: Callable) -> void:
	if not bool(state.get("in_bed", false)):
		return
	state["in_bed"] = false
	sprite.rotation_degrees = 0.0
	var tag := sprite.get_node_or_null(SLEEP_TAG_NAME) as Label
	if tag != null:
		tag.rotation_degrees = 0.0
	var home := state.get("home_anchor", Vector2i(2147483647, 2147483647)) as Vector2i
	if home.x != 2147483647:
		sprite.position = cell_center_position.call(home)
		state["cell"] = home
		state["target"] = sprite.position

static func _pick_venue_cell(venue_types: Array, pois: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	for venue_type_variant: Variant in venue_types:
		var cells := pois.get(String(venue_type_variant), []) as Array
		if not cells.is_empty():
			return cells[rng.randi_range(0, cells.size() - 1)] as Vector2i
	return Vector2i(2147483647, 2147483647)

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
	# BFS admits the goal cell even when it's blocked; don't step onto it
	# if that first cell isn't walkable (the cached-path branch guards the
	# same way).
	if not bool(is_npc_walkable.call(first)):
		return Vector2i.ZERO
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
