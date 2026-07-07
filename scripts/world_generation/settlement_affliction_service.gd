extends RefCounted
class_name SettlementAfflictionService

## What ails the citizenry. Mundane diseases spread by proximity, run
## their course, and occasionally kill. Two curses walk among them:
## zombieism turns a citizen into a shambling corpse that hunts healthy
## neighbors and spreads by bite, and vampirism hides in plain sight -
## the vampire keeps their name and face, sleeps through the day (the
## sun burns), and at night stalks victims who are alone or asleep,
## turning them quietly. Afflictions live on the npc state under
## "affliction": {"id", "name", "kind", "hours_left", ...}.

const KIND_DISEASE := "disease"
const KIND_ZOMBIE := "zombie"
const KIND_VAMPIRE := "vampire"
const KIND_INCUBATING_ZOMBIE := "incubating_zombie"
const KIND_INCUBATING_VAMPIRE := "incubating_vampire"

const DISEASES := [
	{"id": "winter_flu", "name": "Winter Flu", "contagious": true, "duration_hours": 36.0, "lethal_per_hour": 0.0},
	{"id": "gutter_plague", "name": "Gutter Plague", "contagious": true, "duration_hours": 72.0, "lethal_per_hour": 0.004},
	{"id": "botfly_sickness", "name": "Botfly Sickness", "contagious": false, "duration_hours": 60.0, "lethal_per_hour": 0.001},
	{"id": "cave_fever", "name": "Cave Fever", "contagious": true, "duration_hours": 48.0, "lethal_per_hour": 0.002},
	{"id": "stone_lung", "name": "Stone Lung", "contagious": false, "duration_hours": 96.0, "lethal_per_hour": 0.001}
]

const DISEASE_CHANCE := 0.08
const PATIENT_ZERO_ZOMBIE_CHANCE := 0.3
const HIDDEN_VAMPIRE_CHANCE := 0.35
const CONTAGION_PER_HOUR := 0.18
const CONTAGION_RADIUS := 1
const ZOMBIE_INCUBATION_HOURS := 10.0
const VAMPIRE_INCUBATION_HOURS := 36.0
const ZOMBIE_HP := 6
const ZOMBIE_BITE_COOLDOWN := 2.5
const ZOMBIE_STEP_COOLDOWN := 0.45
const VAMPIRE_BITE_COOLDOWN_HOURS := 20.0
const VAMPIRE_LONELY_RADIUS := 4
const SUN_DEATH_HOURS := 3.0

const TINTS := {
	KIND_DISEASE: Color(0.82, 0.95, 0.8, 1.0),
	KIND_ZOMBIE: Color(0.62, 0.78, 0.6, 1.0),
	KIND_VAMPIRE: Color(0.93, 0.9, 0.98, 1.0),
	KIND_INCUBATING_ZOMBIE: Color(0.8, 0.88, 0.78, 1.0),
	KIND_INCUBATING_VAMPIRE: Color(0.95, 0.93, 0.98, 1.0)
}

## Seeds the roster: a slice carries a disease; some settlements wake
## with a shambling corpse; some already house a quiet vampire.
static func seed_afflictions(npc_states: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for state: Dictionary in npc_states:
		if rng.randf() < DISEASE_CHANCE:
			var disease := DISEASES[rng.randi_range(0, DISEASES.size() - 1)] as Dictionary
			state["affliction"] = {
				"id": String(disease.get("id", "")),
				"name": String(disease.get("name", "")),
				"kind": KIND_DISEASE,
				"hours_left": float(disease.get("duration_hours", 48.0)) * rng.randf_range(0.5, 1.0)
			}
	if npc_states.is_empty():
		return
	if rng.randf() < PATIENT_ZERO_ZOMBIE_CHANCE:
		var zombie := npc_states[rng.randi_range(0, npc_states.size() - 1)]
		_turn_zombie(zombie)
	if rng.randf() < HIDDEN_VAMPIRE_CHANCE:
		for _attempt in 8:
			var candidate := npc_states[rng.randi_range(0, npc_states.size() - 1)]
			var kind := String((candidate.get("affliction", {}) as Dictionary).get("kind", ""))
			if kind.is_empty():
				_turn_vampire(candidate)
				break

static func _turn_zombie(state: Dictionary) -> void:
	state["affliction"] = {"id": "zombieism", "name": "Zombieism", "kind": KIND_ZOMBIE, "hours_left": 0.0}
	state["zombie_hp"] = ZOMBIE_HP
	# The dead keep no appointments.
	state.erase("faction_meeting_hour")

static func _turn_vampire(state: Dictionary) -> void:
	state["affliction"] = {"id": "vampirism", "name": "Vampirism", "kind": KIND_VAMPIRE, "hours_left": 0.0, "last_bite_hour": -1000.0, "sun_hours": 0.0}
	# Sleeps the day away; walks the night.
	state["nocturnal"] = true

## Clock tick: recovery, deaths, incubation flips, contagion, and (in
## sunlit settlements) vampires caught outside by day. Returns event
## lines for the status feed; dead states are flagged "affliction_dead".
static func advance(npc_states: Array[Dictionary], delta_hours: float, rng: RandomNumberGenerator, has_sunlight: bool, day_hour: bool) -> Array[String]:
	var events: Array[String] = []
	if delta_hours <= 0.0:
		return events
	for state: Dictionary in npc_states:
		var affliction_variant: Variant = state.get("affliction")
		if not (affliction_variant is Dictionary):
			continue
		var affliction := affliction_variant as Dictionary
		var npc_name := String(state.get("npc_name", "Somebody"))
		match String(affliction.get("kind", "")):
			KIND_DISEASE:
				affliction["hours_left"] = float(affliction.get("hours_left", 0.0)) - delta_hours
				if rng.randf() < float(_disease_by_id(String(affliction.get("id", ""))).get("lethal_per_hour", 0.0)) * delta_hours:
					state["affliction_dead"] = true
					events.append("%s succumbed to the %s." % [npc_name, String(affliction.get("name", "sickness"))])
				elif float(affliction.get("hours_left", 0.0)) <= 0.0:
					state.erase("affliction")
			KIND_INCUBATING_ZOMBIE:
				affliction["hours_left"] = float(affliction.get("hours_left", 0.0)) - delta_hours
				if float(affliction.get("hours_left", 0.0)) <= 0.0:
					_turn_zombie(state)
					events.append("%s has risen — the dead walk!" % npc_name)
			KIND_INCUBATING_VAMPIRE:
				affliction["hours_left"] = float(affliction.get("hours_left", 0.0)) - delta_hours
				if float(affliction.get("hours_left", 0.0)) <= 0.0:
					_turn_vampire(state)
					events.append("By dawn, %s seems somehow... changed." % npc_name)
			KIND_VAMPIRE:
				if has_sunlight and day_hour and not _is_home(state):
					affliction["sun_hours"] = float(affliction.get("sun_hours", 0.0)) + delta_hours
					if float(affliction.get("sun_hours", 0.0)) >= SUN_DEATH_HOURS:
						state["affliction_dead"] = true
						events.append("Only a drift of ash remains where %s stood in the sun." % npc_name)
				else:
					# Sunlight death is continuous exposure, not a lifetime
					# tally: back home or after dusk, the clock resets.
					affliction["sun_hours"] = 0.0
	# Contagion: the visibly sick pass their disease to whoever lingers
	# beside them. Infections are gathered during the sweep and applied
	# afterward so a case caught this tick cannot chain to a third NPC in
	# the same tick, and the spread stays independent of array order.
	var new_infections: Array[Dictionary] = []
	for state: Dictionary in npc_states:
		if bool(state.get("affliction_dead", false)):
			continue
		var affliction := state.get("affliction", {}) as Dictionary
		if String(affliction.get("kind", "")) != KIND_DISEASE:
			continue
		var disease := _disease_by_id(String(affliction.get("id", "")))
		if not bool(disease.get("contagious", false)):
			continue
		var carrier_cell := state.get("cell", Vector2i.ZERO) as Vector2i
		for other: Dictionary in npc_states:
			if other == state or other.has("affliction"):
				continue
			var other_cell := other.get("cell", Vector2i(9999, 9999)) as Vector2i
			if maxi(absi(other_cell.x - carrier_cell.x), absi(other_cell.y - carrier_cell.y)) > CONTAGION_RADIUS:
				continue
			if rng.randf() < CONTAGION_PER_HOUR * delta_hours:
				new_infections.append({
					"target": other,
					"id": String(affliction.get("id", "")),
					"name": String(affliction.get("name", "")),
					"hours_left": float(disease.get("duration_hours", 48.0))
				})
	for infection: Dictionary in new_infections:
		var target := infection.get("target", {}) as Dictionary
		if target.has("affliction") or bool(target.get("affliction_dead", false)):
			continue
		target["affliction"] = {
			"id": String(infection.get("id", "")),
			"name": String(infection.get("name", "")),
			"kind": KIND_DISEASE,
			"hours_left": float(infection.get("hours_left", 48.0))
		}
	return events

static func _disease_by_id(disease_id: String) -> Dictionary:
	for disease_variant: Variant in DISEASES:
		if String((disease_variant as Dictionary).get("id", "")) == disease_id:
			return disease_variant as Dictionary
	return {}

static func _is_home(state: Dictionary) -> bool:
	var home := state.get("home_anchor", Vector2i(9999, 9999)) as Vector2i
	var cell := state.get("cell", Vector2i.ZERO) as Vector2i
	return maxi(absi(cell.x - home.x), absi(cell.y - home.y)) <= 2

## Per-frame predator behavior. Zombies chase the nearest healthy
## citizen and spread by bite; vampires pick a victim who is alone or
## asleep, let the scheduler walk them there, and bite unseen. Returns
## event lines (zombies are loud; vampires are not).
## game_hour is hour-of-day (0-24); total_game_hours is absolute time
## (day * 24 + hour) so multi-day cooldowns survive midnight.
static func update_predators(
	delta: float,
	npc_states: Array[Dictionary],
	city_layer: TileMapLayer,
	rng: RandomNumberGenerator,
	game_hour: float,
	is_npc_walkable: Callable,
	cell_center_position: Callable,
	total_game_hours: float = -1.0
) -> Array[String]:
	var events: Array[String] = []
	var absolute_hours := total_game_hours if total_game_hours >= 0.0 else game_hour
	for state: Dictionary in npc_states:
		var affliction := state.get("affliction", {}) as Dictionary
		match String(affliction.get("kind", "")):
			KIND_ZOMBIE:
				var zombie_events := _update_zombie(delta, state, npc_states, city_layer, rng, is_npc_walkable, cell_center_position)
				events.append_array(zombie_events)
			KIND_VAMPIRE:
				_update_vampire(state, npc_states, game_hour, absolute_hours)
	return events

static func _update_zombie(delta: float, state: Dictionary, npc_states: Array[Dictionary], city_layer: TileMapLayer, rng: RandomNumberGenerator, is_npc_walkable: Callable, cell_center_position: Callable) -> Array[String]:
	var events: Array[String] = []
	var sprite := state.get("sprite") as Sprite2D
	if sprite == null:
		return events
	var bite_cooldown := float(state.get("zombie_bite_cooldown", 0.0)) - delta
	var step_cooldown := float(state.get("zombie_step_cooldown", 0.0)) - delta
	var current_cell := city_layer.local_to_map(sprite.position)
	state["cell"] = current_cell
	# Nearest healthy target.
	var target: Dictionary = {}
	var best_distance := 999999
	for other: Dictionary in npc_states:
		if other == state:
			continue
		var other_kind := String((other.get("affliction", {}) as Dictionary).get("kind", ""))
		if other_kind == KIND_ZOMBIE:
			continue
		var other_cell := other.get("cell", Vector2i(9999, 9999)) as Vector2i
		var distance := maxi(absi(other_cell.x - current_cell.x), absi(other_cell.y - current_cell.y))
		if distance < best_distance:
			best_distance = distance
			target = other
	if not target.is_empty() and best_distance <= 1:
		if bite_cooldown <= 0.0:
			bite_cooldown = ZOMBIE_BITE_COOLDOWN
			if not target.has("affliction"):
				target["affliction"] = {"id": "zombie_virus", "name": "Zombie Virus", "kind": KIND_INCUBATING_ZOMBIE, "hours_left": ZOMBIE_INCUBATION_HOURS}
				events.append("%s was bitten by the shambling corpse of %s!" % [String(target.get("npc_name", "Somebody")), String(state.get("npc_name", "a stranger"))])
	elif not target.is_empty() and step_cooldown <= 0.0:
		step_cooldown = ZOMBIE_STEP_COOLDOWN
		var target_cell := target.get("cell", current_cell) as Vector2i
		var step: Vector2i = SettlementNpcScheduler._step_toward(current_cell, target_cell, is_npc_walkable, rng)
		if step != Vector2i.ZERO:
			var next_cell := current_cell + step
			sprite.position = cell_center_position.call(next_cell)
			state["cell"] = next_cell
			sprite.flip_h = step.x < 0
	state["zombie_bite_cooldown"] = bite_cooldown
	state["zombie_step_cooldown"] = step_cooldown
	return events

## The vampire hunts by appointment, not by chase: pick a victim who is
## alone or abed, point the night's wanderings at them (the scheduler
## does the walking), and bite when nobody else is near.
static func _update_vampire(state: Dictionary, npc_states: Array[Dictionary], game_hour: float, total_game_hours: float) -> void:
	var night := game_hour >= 21.0 or game_hour < 5.0
	if not night:
		state.erase("vampire_target")
		return
	var affliction := state.get("affliction", {}) as Dictionary
	# The cooldown compares ABSOLUTE hours: hour-of-day arithmetic made a
	# 20-hour cooldown unmeetable for any bite after 4 in the morning.
	var last_bite := float(affliction.get("last_bite_hour", -1000.0))
	if last_bite > -999.0 and total_game_hours - last_bite < VAMPIRE_BITE_COOLDOWN_HOURS:
		return
	var my_cell := state.get("cell", Vector2i.ZERO) as Vector2i
	# Keep or pick a victim: healthy, and either asleep at home or alone.
	var victim_name := String(state.get("vampire_target", ""))
	var victim: Dictionary = {}
	var best_distance := 999999
	for other: Dictionary in npc_states:
		if other == state or other.has("affliction"):
			continue
		var lonely := true
		var other_cell := other.get("cell", Vector2i(9999, 9999)) as Vector2i
		for third: Dictionary in npc_states:
			if third == other or third == state:
				continue
			var third_cell := third.get("cell", Vector2i(9999, 9999)) as Vector2i
			if maxi(absi(third_cell.x - other_cell.x), absi(third_cell.y - other_cell.y)) <= VAMPIRE_LONELY_RADIUS:
				lonely = false
				break
		var asleep := String(other.get("mode", "")) == "sleep"
		if not lonely and not asleep:
			continue
		if String(other.get("npc_name", "")) == victim_name:
			victim = other
			break
		var distance := maxi(absi(other_cell.x - my_cell.x), absi(other_cell.y - my_cell.y))
		if distance < best_distance:
			best_distance = distance
			victim = other
	if victim.is_empty():
		state.erase("vampire_target")
		return
	state["vampire_target"] = String(victim.get("npc_name", ""))
	var victim_cell := victim.get("cell", my_cell) as Vector2i
	# The night's leisure leads to the victim's side.
	state["leisure_anchor"] = victim_cell
	if maxi(absi(victim_cell.x - my_cell.x), absi(victim_cell.y - my_cell.y)) <= 1:
		victim["affliction"] = {"id": "pale_sickness", "name": "a strange pallor", "kind": KIND_INCUBATING_VAMPIRE, "hours_left": VAMPIRE_INCUBATION_HOURS}
		affliction["last_bite_hour"] = total_game_hours
		state.erase("vampire_target")

## What the hover card admits to. Diseases and shambling are plain to
## see; a vampire only reads as someone who keeps from the light.
static func tooltip_line(state: Dictionary) -> String:
	var affliction := state.get("affliction", {}) as Dictionary
	if affliction.is_empty():
		return ""
	match String(affliction.get("kind", "")):
		KIND_DISEASE:
			return "Afflicted: %s" % String(affliction.get("name", "a sickness"))
		KIND_ZOMBIE:
			return "Afflicted: Zombieism — it hungers"
		KIND_INCUBATING_ZOMBIE:
			return "Afflicted: a festering bite"
		KIND_INCUBATING_VAMPIRE:
			return "Looks pale and drawn of late"
		KIND_VAMPIRE:
			return "Pale, and keeps from the light"
	return ""

static func tint_for(state: Dictionary) -> Color:
	var affliction := state.get("affliction", {}) as Dictionary
	if affliction.is_empty():
		return Color.WHITE
	return TINTS.get(String(affliction.get("kind", "")), Color.WHITE) as Color

static func is_active_zombie(state: Dictionary) -> bool:
	return String((state.get("affliction", {}) as Dictionary).get("kind", "")) == KIND_ZOMBIE
