extends RefCounted
class_name WorldChronicleService

## Dwarf Fortress-style lite history. After settlements are placed and the
## political flood has drawn its nations, worldgen runs one seeded chronicle
## from year 1 to the embark year: staggered foundings, wars with named
## battles at real settlements, named beasts that rampage or bring holds
## down, plagues, golden ages and ruler successions. Every ruin, founding
## date, faction grudge and tavern rumor then traces back to a concrete
## event with a year and named actors instead of an independent flavor roll.
##
## The chronicle is pure data (JSON-safe: String/int/bool/Array/Dictionary
## only) and fully deterministic from (map seed, chronology year, the
## settlement roster). It is stored in world settings under SETTINGS_KEY so
## town and dwarfhold scenes can read local history without the overworld.

const SETTINGS_KEY := "world_chronicle"

## Player-made history: beasts the PLAYER has slain, kept separately from
## the simulated chronicle so a re-generated overworld (same seed, fresh
## simulation) can re-apply the kills instead of resurrecting the beast.
## beast name -> {"year": int, "by": String, "place": String}.
const KILLS_KEY := "world_beast_kills"

## Player-made tragedy: the characters who DIED in this world, kept beside
## the beast-kill register so a re-generated overworld (same seed, fresh
## simulation) re-applies the deaths to its chronicle exactly like the
## kills. Array of {"year": int, "name": String, "place": String,
## "cause": String}.
const DEATHS_KEY := "world_player_deaths"

const OVERWORLD_CONTENT := preload("res://scripts/world_generation/overworld_content.gd")

## Beast archetypes reuse creature concepts the world already knows: the
## green dragon and sleeping dragon of the culture map, the dragon/giant/
## troll sightings of WorldEventsService, and the "what stirs below" the
## dwarven Anvil Compact arms against. No new art — beasts live in text.
const BEAST_ARCHETYPES := [
	{"kind": "green_dragon", "label": "the green dragon", "fells_holds": true},
	{"kind": "dragon", "label": "the dragon", "fells_holds": true},
	{"kind": "giant", "label": "the giant", "fells_holds": false},
	{"kind": "troll", "label": "the troll-king", "fells_holds": false},
	{"kind": "thing_below", "label": "the deep horror", "fells_holds": true}
]
const BEAST_NAME_PREFIXES: Array[String] = [
	"Khar", "Vor", "Mor", "Skar", "Gral", "Naz", "Bel", "Dur", "Uz", "Zar", "Thrag", "Ash"
]
const BEAST_NAME_SUFFIXES: Array[String] = [
	"azhul", "gash", "thrax", "goth", "duum", "ymir", "khaz", "roth", "moth", "grimm", "ulk", "vex"
]

## The unique trophy a slain beast yields ("Skarthrax's Fang" style),
## keyed by beast kind. ItemDefsService resolves the icon/flavor and
## SettlementEconomyService the (high) sell value from the suffix.
const BEAST_TROPHY_SUFFIXES := {
	"green_dragon": "Fang",
	"dragon": "Fang",
	"giant": "Knucklebone",
	"troll": "Crown",
	"thing_below": "Eye"
}

## Split by gender so a rolled name never wears the wrong title
## ("Lady Duncan Miller"); Mayor and Reeve fit anyone.
const TOWN_RULER_TITLES_MALE: Array[String] = [
	"Mayor", "Lord", "Reeve", "Alderman", "Baron"
]
const TOWN_RULER_TITLES_FEMALE: Array[String] = [
	"Mayor", "Lady", "Reeve", "Baroness"
]
const ELF_RULER_TITLES: Array[String] = [
	"Warden", "Elder Warden", "Bough-Speaker"
]
const LIZARD_RULER_TITLES: Array[String] = [
	"Priest-King", "Oracle", "Scale-Lord"
]
const ELF_FIRST_NAMES: Array[String] = [
	"Aelira", "Thandriel", "Sylvara", "Faelor", "Ithilwen", "Caladhor", "Nimloth", "Erendriel"
]

const PLAGUE_NAMES: Array[String] = [
	"The Gray Plague", "The Weeping Fever", "The Ashen Pox", "The Red Sweats", "The Hollow Cough"
]
const WAR_NAME_FLAVORS: Array[String] = [
	"Salt", "Iron", "Ember", "Border", "Broken Oath", "Long", "Silent", "Winter", "Bitter", "Crownless"
]

## How loudly each event kind echoes when picking the world chronicle.
const WORLD_EVENT_IMPORTANCE := {
	"fall": 9,
	"beast_slain": 8,
	"razing": 8,
	"conquest": 7,
	"war_start": 6,
	"war_end": 5,
	"battle": 4,
	"beast_attack": 3,
	"plague": 3,
	"golden_age": 2,
	"founding": 1
}
const WORLD_EVENT_MIN := 15
const WORLD_EVENT_MAX := 25
const SETTLEMENT_EVENT_CAP := 14
const NEIGHBOR_NATION_DISTANCE := 40.0
const NEIGHBOR_RUMOR_DISTANCE := 60.0

## --- Simulation -------------------------------------------------------------

## Runs the whole chronicle. actors: one record per settlement with keys
## key ("x,y"), x, y, name, type, class_key, population, is_hamlet, state,
## ruler_name, ruler_title. Returns the JSON-safe chronicle dictionary.
static func simulate(actors: Array[Dictionary], chronology_year: int, seed_number: int) -> Dictionary:
	var current_year := maxi(1, chronology_year)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash("%d|world_chronicle|%d" % [seed_number, current_year]))

	var records: Dictionary = {}
	var order: Array[String] = []
	for actor: Dictionary in actors:
		var record_key := String(actor.get("key", ""))
		if record_key.is_empty() or records.has(record_key):
			continue
		order.append(record_key)
		records[record_key] = {
			"key": record_key,
			"x": int(actor.get("x", 0)),
			"y": int(actor.get("y", 0)),
			"name": String(actor.get("name", "a settlement")),
			"type": String(actor.get("type", "town")),
			"class_key": String(actor.get("class_key", "")),
			"population": maxi(0, int(actor.get("population", 0))),
			"is_hamlet": bool(actor.get("is_hamlet", false)),
			"state": String(actor.get("state", "")).strip_edges(),
			"ruler_name": String(actor.get("ruler_name", "")),
			"ruler_title": String(actor.get("ruler_title", "")),
			"clan": String(actor.get("clan", "")),
			"founded_year": 1,
			"founded_by": "",
			"fell_year": 0,
			"fall_text": "",
			"razed": false,
			"peak_population": maxi(0, int(actor.get("population", 0))),
			"events": [],
			"marks": [],
			"rumors": [],
			"agenda_goals": []
		}

	var chronicle := {
		"version": 1,
		"year": current_year,
		"beasts": [],
		"wars": [],
		"world_events": [],
		"world_rumors": [],
		"settlements": records,
		"converted_holds": [],
		"razed_settlements": []
	}
	if order.is_empty():
		return chronicle

	var all_events: Array[Dictionary] = []
	_simulate_foundings(records, order, current_year, rng, all_events)
	var beasts := _spawn_beasts(rng)
	chronicle["beasts"] = beasts
	_simulate_wars(chronicle, records, order, current_year, rng, all_events)
	_simulate_hold_falls(chronicle, records, order, beasts, current_year, rng, all_events)
	_simulate_beast_rampages(records, order, beasts, current_year, rng, all_events)
	_simulate_razings(chronicle, records, order, beasts, current_year, rng, all_events)
	_simulate_local_calamities(records, order, current_year, rng, all_events)
	_simulate_ruler_lines(records, order, current_year, rng, all_events)
	_finalize_settlements(records, order, beasts, current_year)
	chronicle["world_events"] = _select_world_events(all_events, current_year)
	chronicle["world_rumors"] = _build_world_rumors(chronicle, rng)
	return chronicle

## Staggers foundings across [1, current_year]: elder races root early,
## towns spread across the middle ages, hamlets are recent growth.
static func _simulate_foundings(
	records: Dictionary,
	order: Array[String],
	current_year: int,
	rng: RandomNumberGenerator,
	all_events: Array[Dictionary]
) -> void:
	var span := maxi(1, current_year - 1)
	for record_key: String in order:
		var record := records[record_key] as Dictionary
		var settlement_type := String(record.get("type", "town"))
		var band := Vector2(0.1, 0.85)
		match settlement_type:
			"dwarfhold":
				band = Vector2(0.02, 0.45)
			"woodElfGrove":
				band = Vector2(0.02, 0.4)
			"lizardmenCity":
				band = Vector2(0.02, 0.35)
			_:
				band = Vector2(0.5, 0.96) if bool(record.get("is_hamlet", false)) else Vector2(0.1, 0.85)
		var founded_year := 1
		if span > 8:
			founded_year = clampi(1 + int(round(float(span) * rng.randf_range(band.x, band.y))), 1, maxi(1, current_year - 4))
		var founder := _roll_person(settlement_type, rng)
		record["founded_year"] = founded_year
		record["founded_by"] = String(founder.get("full", ""))
		var founding_text := _founding_text(settlement_type, founder)
		_push_event(record, all_events, founded_year, "founding", founding_text, String(record.get("name", "")))

static func _founding_text(settlement_type: String, founder: Dictionary) -> String:
	var full := String(founder.get("full", ""))
	match settlement_type:
		"dwarfhold":
			return "Founded by %s, whose clan first delved beneath the mountain." % full
		"woodElfGrove":
			# The bare name here: the titled form doubles the noun
			# ("under the wardenship of Warden Aelira").
			return "Took root beneath the elder trees under the wardenship of %s." % String(founder.get("name", full))
		"lizardmenCity":
			return "Raised as a temple city by %s." % full
		_:
			return "Founded by %s, who raised the first hall at the crossroads." % full

## 2-5 named beasts drawn from the world's existing creature concepts.
static func _spawn_beasts(rng: RandomNumberGenerator) -> Array:
	var beasts: Array = []
	var beast_count := rng.randi_range(2, 5)
	var used_names: Dictionary = {}
	for beast_index: int in range(beast_count):
		var archetype := BEAST_ARCHETYPES[rng.randi_range(0, BEAST_ARCHETYPES.size() - 1)] as Dictionary
		var beast_name := ""
		for attempt: int in range(8):
			beast_name = "%s%s" % [
				BEAST_NAME_PREFIXES[rng.randi_range(0, BEAST_NAME_PREFIXES.size() - 1)],
				BEAST_NAME_SUFFIXES[rng.randi_range(0, BEAST_NAME_SUFFIXES.size() - 1)]
			]
			if not used_names.has(beast_name):
				break
		used_names[beast_name] = true
		beasts.append({
			"name": beast_name,
			"kind": String(archetype.get("kind", "dragon")),
			"label": String(archetype.get("label", "the dragon")),
			"display": "%s %s" % [String(archetype.get("label", "the dragon")), beast_name],
			"fells_holds": bool(archetype.get("fells_holds", false)),
			"status": "alive",
			"slain_year": 0,
			"slain_by": "",
			"slain_by_player": false,
			"lair": "",
			## Physical lair, assigned by the overworld after simulation:
			## the map tile the still-living beast dens at, its site kind
			## ("hold" or "site") and the site's display name.
			"lair_site": {},
			"lair_kind": "",
			"lair_name": ""
		})
	return beasts

## Wars between neighboring nations (the flood-assigned political states):
## a start year, 1-3 named battles at real settlements of the two states,
## and an end in white peace or conquest. Only history changes hands — the
## present political map stays exactly as the flood drew it.
static func _simulate_wars(
	chronicle: Dictionary,
	records: Dictionary,
	order: Array[String],
	current_year: int,
	rng: RandomNumberGenerator,
	all_events: Array[Dictionary]
) -> void:
	var span := current_year - 1
	if span < 30:
		return
	var by_state: Dictionary = {}
	for record_key: String in order:
		var record := records[record_key] as Dictionary
		var state_name := String(record.get("state", ""))
		if state_name.is_empty():
			continue
		if not by_state.has(state_name):
			by_state[state_name] = []
		(by_state[state_name] as Array).append(record_key)
	var state_names: Array[String] = []
	for state_variant: Variant in by_state.keys():
		state_names.append(String(state_variant))
	if state_names.size() < 2:
		return
	# Neighboring nations: any two states with settlements close enough to
	# march between. One flat pass over settlement pairs keeps this cheap
	# even when every city is its own state; closest pairs go first so
	# border wars dominate.
	var flat_states: Array[String] = []
	var flat_positions := PackedVector2Array()
	for record_key: String in order:
		var record := records[record_key] as Dictionary
		var state_name := String(record.get("state", ""))
		if state_name.is_empty():
			continue
		flat_states.append(state_name)
		flat_positions.append(Vector2(float(record.get("x", 0)), float(record.get("y", 0))))
	var best_by_pair: Dictionary = {}
	var neighbor_distance_squared := NEIGHBOR_NATION_DISTANCE * NEIGHBOR_NATION_DISTANCE
	for first_index: int in range(flat_states.size()):
		for second_index: int in range(first_index + 1, flat_states.size()):
			if flat_states[first_index] == flat_states[second_index]:
				continue
			var distance_squared := flat_positions[first_index].distance_squared_to(flat_positions[second_index])
			if distance_squared > neighbor_distance_squared:
				continue
			var pair_key := (
				"%s|%s" % [flat_states[first_index], flat_states[second_index]]
				if flat_states[first_index] < flat_states[second_index]
				else "%s|%s" % [flat_states[second_index], flat_states[first_index]]
			)
			if not best_by_pair.has(pair_key) or distance_squared < float(best_by_pair[pair_key]):
				best_by_pair[pair_key] = distance_squared
	var pairs: Array[Dictionary] = []
	for pair_key_variant: Variant in best_by_pair.keys():
		var pair_key := String(pair_key_variant)
		var pair_names := pair_key.split("|")
		pairs.append({
			"a": pair_names[0],
			"b": pair_names[1],
			"distance": sqrt(float(best_by_pair[pair_key]))
		})
	if pairs.is_empty():
		return
	pairs.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if absf(float(left.get("distance", 0.0)) - float(right.get("distance", 0.0))) > 0.001:
			return float(left.get("distance", 0.0)) < float(right.get("distance", 0.0))
		return String(left.get("a", "")) + String(left.get("b", "")) < String(right.get("a", "")) + String(right.get("b", ""))
	)
	var war_count := clampi(int(round(float(span) / 70.0)), 1, 4)
	war_count = mini(war_count, pairs.size())
	var wars: Array = []
	for war_index: int in range(war_count):
		var pair := pairs[war_index] as Dictionary
		var attacker := String(pair.get("a", ""))
		var defender := String(pair.get("b", ""))
		if rng.randf() < 0.5:
			var swap := attacker
			attacker = defender
			defender = swap
		var sites: Array[String] = []
		for site_key_variant: Variant in (by_state[attacker] as Array):
			sites.append(String(site_key_variant))
		for site_key_variant: Variant in (by_state[defender] as Array):
			sites.append(String(site_key_variant))
		var earliest := 6
		for site_key: String in sites:
			var site := records[site_key] as Dictionary
			earliest = maxi(earliest, int(site.get("founded_year", 1)) + 2)
		if earliest >= current_year - 6:
			continue
		var start_year := clampi(
			rng.randi_range(int(float(span) * 0.25), maxi(earliest, current_year - 10)),
			earliest,
			current_year - 6
		)
		var end_year := mini(start_year + rng.randi_range(3, 12), current_year - 1)
		var war_name := "The %s War" % WAR_NAME_FLAVORS[rng.randi_range(0, WAR_NAME_FLAVORS.size() - 1)]
		var battles: Array = []
		var battle_count := rng.randi_range(1, 3)
		var used_sites: Dictionary = {}
		for battle_index: int in range(battle_count):
			var battle_year := clampi(rng.randi_range(start_year, end_year), start_year, end_year)
			var candidates: Array[String] = []
			for site_key: String in sites:
				var site := records[site_key] as Dictionary
				if int(site.get("founded_year", 1)) < battle_year and not used_sites.has(site_key):
					candidates.append(site_key)
			if candidates.is_empty():
				continue
			var site_key := candidates[rng.randi_range(0, candidates.size() - 1)]
			used_sites[site_key] = true
			var site := records[site_key] as Dictionary
			var site_name := String(site.get("name", "the walls"))
			var site_state := String(site.get("state", ""))
			var enemy_state := defender if site_state == attacker else attacker
			var battle_name := "Battle of %s" % site_name
			battles.append({"year": battle_year, "name": battle_name, "site": site_key, "site_name": site_name})
			var battle_text := (
				"Besieged by the armies of %s at the %s; a hard year of hunger followed." % [_realm_ref(enemy_state), battle_name]
				if rng.randf() < 0.5
				else "The %s was fought at the gates; the armies of %s were thrown back." % [battle_name, _realm_ref(enemy_state)]
			)
			_push_event(site, all_events, battle_year, "battle", battle_text, site_name)
			_push_mark(site, battle_year, "battle", rng.randf_range(0.08, 0.2))
			(site["rumors"] as Array).append("My grandmother survived the %s. She never spoke of it twice." % battle_name)
			(site["agenda_goals"] as Array).append("to repay %s for the %s" % [_realm_ref(enemy_state), battle_name])
		if battles.is_empty():
			continue
		var outcome := "white_peace"
		if rng.randf() < 0.5 and not battles.is_empty():
			outcome = "conquest"
			var loser := defender if rng.randf() < 0.65 else attacker
			var winner := attacker if loser == defender else defender
			var conquest_key := ""
			for battle_variant: Variant in battles:
				var battle := battle_variant as Dictionary
				var site := records[String(battle.get("site", ""))] as Dictionary
				if String(site.get("state", "")) == loser:
					conquest_key = String(battle.get("site", ""))
					break
			if conquest_key.is_empty():
				var loser_sites := by_state[loser] as Array
				conquest_key = String(loser_sites[rng.randi_range(0, loser_sites.size() - 1)])
			var conquered := records[conquest_key] as Dictionary
			var conquered_name := String(conquered.get("name", ""))
			_push_event(
				conquered, all_events, end_year, "conquest",
				"Stormed by the armies of %s as %s ended; for a generation it flew the banner of %s." % [_realm_ref(winner), _war_ref(war_name), _realm_ref(winner)],
				conquered_name
			)
			_push_mark(conquered, end_year, "battle", rng.randf_range(0.1, 0.22))
			(conquered["agenda_goals"] as Array).append("to cast off every debt owed to %s" % _realm_ref(winner))
		all_events.append({
			"year": start_year,
			"type": "war_start",
			"text": "%s began: %s marched against %s." % [war_name, _capitalize_first(_realm_ref(attacker)), _realm_ref(defender)],
			"site_name": ""
		})
		var end_text := (
			"%s ended in a white peace between %s and %s." % [war_name, _realm_ref(attacker), _realm_ref(defender)]
			if outcome == "white_peace"
			else "%s ended: %s dictated terms to %s." % [war_name, _capitalize_first(_realm_ref(attacker)), _realm_ref(defender)]
		)
		all_events.append({"year": end_year, "type": "war_end", "text": end_text, "site_name": ""})
		wars.append({
			"name": war_name,
			"attacker": attacker,
			"defender": defender,
			"start": start_year,
			"end": end_year,
			"outcome": outcome,
			"battles": battles
		})
	chronicle["wars"] = wars

## Every abandoned dwarfhold on the map is an OUTPUT of history: each gets
## a fall event (year, cause, the beast or army responsible). When the sim
## hungers for more falls than the placer left ruins, it converts living
## standard holds — the overworld applies the tile change.
static func _simulate_hold_falls(
	chronicle: Dictionary,
	records: Dictionary,
	order: Array[String],
	beasts: Array,
	current_year: int,
	rng: RandomNumberGenerator,
	all_events: Array[Dictionary]
) -> void:
	var fallen_keys: Array[String] = []
	var standard_holds: Array[String] = []
	for record_key: String in order:
		var record := records[record_key] as Dictionary
		if String(record.get("type", "")) != "dwarfhold":
			continue
		var class_key := String(record.get("class_key", ""))
		if class_key == "abandoned":
			fallen_keys.append(record_key)
		elif class_key == "standard":
			standard_holds.append(record_key)
	# The sim may want a fall or two beyond what the placer scattered, but
	# never so many that the living-hold count leaves its usual range.
	var converted: Array = []
	if standard_holds.size() > 2:
		var extra_roll := rng.randf()
		var extra_falls := 0
		if extra_roll < 0.15:
			extra_falls = 2
		elif extra_roll < 0.45:
			extra_falls = 1
		extra_falls = mini(extra_falls, standard_holds.size() - 2)
		for extra_index: int in range(extra_falls):
			var pick_index := rng.randi_range(0, standard_holds.size() - 1)
			var converted_key := standard_holds[pick_index]
			standard_holds.remove_at(pick_index)
			var converted_record := records[converted_key] as Dictionary
			converted_record["class_key"] = "abandoned"
			converted.append(converted_key)
			fallen_keys.append(converted_key)
	chronicle["converted_holds"] = converted
	var wars := chronicle.get("wars", []) as Array
	for fallen_key: String in fallen_keys:
		var record := records[fallen_key] as Dictionary
		var founded_year := int(record.get("founded_year", 1))
		var earliest := mini(founded_year + 20, current_year - 2)
		var latest := maxi(earliest, current_year - 10)
		var fall_year := clampi(rng.randi_range(earliest, latest), founded_year + 1, current_year - 1)
		if int(record.get("population", 0)) <= 0:
			record["peak_population"] = rng.randi_range(900, 4800)
		record["fell_year"] = fall_year
		var hold_name := String(record.get("name", "the hold"))
		var war_cause: Dictionary = {}
		for war_variant: Variant in wars:
			var war := war_variant as Dictionary
			var involves_hold := String(record.get("state", "")) in [String(war.get("attacker", "")), String(war.get("defender", ""))]
			if involves_hold and int(war.get("start", 0)) <= fall_year and fall_year <= int(war.get("end", 0)):
				war_cause = war
				break
		if not war_cause.is_empty() and rng.randf() < 0.35:
			var enemy := String(war_cause.get("attacker", ""))
			if enemy == String(record.get("state", "")):
				enemy = String(war_cause.get("defender", ""))
			var fall_text := "The gates were breached by the armies of %s during %s; the hold fell, and its halls have been silent since." % [_realm_ref(enemy), _war_ref(String(war_cause.get("name", "the war")))]
			record["fall_text"] = "Fell to the armies of %s, year %d — %s" % [_realm_ref(enemy), fall_year, GameCalendar.year_title(fall_year)]
			_push_event(record, all_events, fall_year, "fall", fall_text, hold_name)
		else:
			var beast := _pick_hold_felling_beast(beasts, rng)
			beast["lair"] = hold_name
			var beast_display := String(beast.get("display", "a beast"))
			var fall_text := "%s rose from the deeps; the hold fell, and its halls have been silent since." % _capitalize_first(beast_display)
			record["fall_text"] = "Fell to %s, year %d — %s" % [beast_display, fall_year, GameCalendar.year_title(fall_year)]
			record["fall_beast"] = String(beast.get("name", ""))
			_push_event(record, all_events, fall_year, "fall", fall_text, hold_name)
		_push_mark(record, fall_year, "fall", 1.0)

static func _pick_hold_felling_beast(beasts: Array, rng: RandomNumberGenerator) -> Dictionary:
	var candidates: Array[int] = []
	for beast_index: int in range(beasts.size()):
		if bool((beasts[beast_index] as Dictionary).get("fells_holds", false)):
			candidates.append(beast_index)
	if candidates.is_empty():
		for beast_index: int in range(beasts.size()):
			candidates.append(beast_index)
	return beasts[candidates[rng.randi_range(0, candidates.size() - 1)]] as Dictionary

## Each beast rampages 1-3 times: repelled by a named hero, or it burns a
## quarter (a population dip). The last rampage may end with the beast
## slain — but never before the hold-falls history already pinned on it.
static func _simulate_beast_rampages(
	records: Dictionary,
	order: Array[String],
	beasts: Array,
	current_year: int,
	rng: RandomNumberGenerator,
	all_events: Array[Dictionary]
) -> void:
	var span := current_year - 1
	if span < 20:
		return
	for beast_variant: Variant in beasts:
		var beast := beast_variant as Dictionary
		var busy_until := 4
		for record_key: String in order:
			var record := records[record_key] as Dictionary
			if String(record.get("fall_beast", "")) == String(beast.get("name", "")):
				busy_until = maxi(busy_until, int(record.get("fell_year", 0)))
		var rampage_count := rng.randi_range(1, 3)
		var rampage_years: Array[int] = []
		for rampage_index: int in range(rampage_count):
			var rampage_year := rng.randi_range(mini(busy_until + 2, current_year - 2), current_year - 1)
			if rampage_year > busy_until and not rampage_years.has(rampage_year):
				rampage_years.append(rampage_year)
		rampage_years.sort()
		for rampage_index: int in range(rampage_years.size()):
			var rampage_year := rampage_years[rampage_index]
			var target_key := _pick_standing_settlement(records, order, rampage_year, rng)
			if target_key.is_empty():
				continue
			var target := records[target_key] as Dictionary
			var target_name := String(target.get("name", ""))
			var beast_display := String(beast.get("display", "a beast"))
			var is_last := rampage_index == rampage_years.size() - 1
			if rng.randf() < 0.5:
				var hero := _roll_person(String(target.get("type", "town")), rng)
				var hero_name := String(hero.get("name", "a hero"))
				if is_last and rng.randf() < 0.4:
					beast["status"] = "slain"
					beast["slain_year"] = rampage_year
					beast["slain_by"] = hero_name
					_push_event(
						target, all_events, rampage_year, "beast_slain",
						"The hero %s slew %s beneath the walls; the bells rang for a week." % [hero_name, beast_display],
						target_name
					)
				else:
					_push_event(
						target, all_events, rampage_year, "beast_attack",
						"%s descended upon the settlement and was driven off by the hero %s." % [_capitalize_first(beast_display), hero_name],
						target_name
					)
			else:
				_push_event(
					target, all_events, rampage_year, "beast_attack",
					"%s fell upon the settlement; the quarter nearest the gates burned." % _capitalize_first(beast_display),
					target_name
				)
				_push_mark(target, rampage_year, "beast", rng.randf_range(0.1, 0.3))
			if String(beast.get("status", "alive")) == "alive":
				(target["rumors"] as Array).append("They say %s will come back for %s one day. I keep salt by the door." % [beast_display, target_name])
				(target["agenda_goals"] as Array).append("to see %s slain" % beast_display)

static func _pick_standing_settlement(records: Dictionary, order: Array[String], event_year: int, rng: RandomNumberGenerator) -> String:
	var candidates: Array[String] = []
	for record_key: String in order:
		var record := records[record_key] as Dictionary
		if int(record.get("founded_year", 1)) >= event_year:
			continue
		var fell_year := int(record.get("fell_year", 0))
		if fell_year > 0 and fell_year <= event_year:
			continue
		candidates.append(record_key)
	if candidates.is_empty():
		return ""
	return candidates[rng.randi_range(0, candidates.size() - 1)]

## Optionally 1-2 razed human settlements. The overworld atlas offers no
## human-ruin tile, so razed sites keep their art but become "Ruins of X"
## with population 0 — the overworld applies the rename.
static func _simulate_razings(
	chronicle: Dictionary,
	records: Dictionary,
	order: Array[String],
	beasts: Array,
	current_year: int,
	rng: RandomNumberGenerator,
	all_events: Array[Dictionary]
) -> void:
	if current_year < 40:
		return
	var candidates: Array[String] = []
	for record_key: String in order:
		var record := records[record_key] as Dictionary
		if String(record.get("type", "")) != "town":
			continue
		if bool(record.get("is_hamlet", false)) or int(record.get("population", 0)) < 260:
			candidates.append(record_key)
	if candidates.is_empty():
		return
	var raze_roll := rng.randf()
	var raze_count := 0
	if raze_roll < 0.2:
		raze_count = 2
	elif raze_roll < 0.65:
		raze_count = 1
	raze_count = mini(raze_count, candidates.size())
	var razed_keys: Array = []
	var wars := chronicle.get("wars", []) as Array
	for raze_index: int in range(raze_count):
		var pick_index := rng.randi_range(0, candidates.size() - 1)
		var razed_key := candidates[pick_index]
		candidates.remove_at(pick_index)
		var record := records[razed_key] as Dictionary
		var founded_year := int(record.get("founded_year", 1))
		var raze_min := founded_year + 10
		var raze_max := maxi(raze_min, current_year - 5)
		var raze_year := clampi(rng.randi_range(raze_min, raze_max), founded_year + 1, current_year - 1)
		var razed_name := String(record.get("name", ""))
		record["razed"] = true
		record["fell_year"] = raze_year
		record["peak_population"] = maxi(int(record.get("population", 0)), 60)
		if not wars.is_empty() and rng.randf() < 0.5:
			var war := wars[rng.randi_range(0, wars.size() - 1)] as Dictionary
			var enemy := String(war.get("attacker", ""))
			if enemy == String(record.get("state", "")):
				enemy = String(war.get("defender", ""))
			raze_year = clampi(rng.randi_range(int(war.get("start", raze_year)), int(war.get("end", raze_year))), founded_year + 1, current_year - 1)
			record["fell_year"] = raze_year
			record["fall_text"] = "Razed by the armies of %s, year %d — %s" % [_realm_ref(enemy), raze_year, GameCalendar.year_title(raze_year)]
			_push_event(
				record, all_events, raze_year, "razing",
				"Razed by the armies of %s during %s; the survivors scattered, and only ruins remain." % [_realm_ref(enemy), _war_ref(String(war.get("name", "the war")))],
				razed_name
			)
		else:
			var beast := beasts[rng.randi_range(0, beasts.size() - 1)] as Dictionary
			var beast_display := String(beast.get("display", "a beast"))
			record["fall_text"] = "Razed by %s, year %d — %s" % [beast_display, raze_year, GameCalendar.year_title(raze_year)]
			_push_event(
				record, all_events, raze_year, "razing",
				"%s burned the settlement to its footings; the survivors scattered, and only ruins remain." % _capitalize_first(beast_display),
				razed_name
			)
		_push_mark(record, raze_year, "fall", 1.0)
		razed_keys.append(razed_key)
	chronicle["razed_settlements"] = razed_keys

## Plagues, famines and golden ages, rolled per settlement across its
## lifespan. Each leaves a mark the population timeline later replays.
static func _simulate_local_calamities(
	records: Dictionary,
	order: Array[String],
	current_year: int,
	rng: RandomNumberGenerator,
	all_events: Array[Dictionary]
) -> void:
	for record_key: String in order:
		var record := records[record_key] as Dictionary
		var founded_year := int(record.get("founded_year", 1))
		var last_year := int(record.get("fell_year", 0))
		if last_year <= 0:
			last_year = current_year
		var age := last_year - founded_year
		if age < 40:
			continue
		var slots := clampi(int(round(float(age) / 80.0)), 1, 3)
		var settlement_name := String(record.get("name", ""))
		for slot_index: int in range(slots):
			if rng.randf() >= 0.45:
				continue
			var event_year := clampi(rng.randi_range(founded_year + 8, last_year - 4), founded_year + 1, last_year - 1)
			var kind_roll := rng.randf()
			if kind_roll < 0.4:
				var plague_name := PLAGUE_NAMES[rng.randi_range(0, PLAGUE_NAMES.size() - 1)]
				_push_event(
					record, all_events, event_year, "plague",
					"%s swept through; a third of the people perished." % plague_name,
					settlement_name
				)
				_push_mark(record, event_year, "plague", rng.randf_range(0.28, 0.42))
				(record["rumors"] as Array).append("The old folk still speak of %s, back in the year %d — %s. The dead outnumbered the living." % [plague_name, event_year, GameCalendar.year_title(event_year)])
			elif kind_roll < 0.65:
				_push_event(
					record, all_events, event_year, "famine",
					"The harvests failed two years running; hunger emptied many homes.",
					settlement_name
				)
				_push_mark(record, event_year, "famine", rng.randf_range(0.15, 0.28))
			else:
				_push_event(
					record, all_events, event_year, "golden_age",
					"A golden age of trade began; coin and settlers poured in.",
					settlement_name
				)
				_push_mark(record, event_year, "golden_age", -rng.randf_range(0.15, 0.3))

## Ruler lineages generated for the notable settlements: reign spans from
## founding to now, violent successions recorded as events, and the full
## line stored (JSON-safe) on the record so the hold scene can draw the
## dynasty tree. The line's last ruler becomes the sitting one — for
## dwarfholds the lineage is AUTHORITATIVE and replaces the placement
## roll; other settlements only fill an empty seat.
static func _simulate_ruler_lines(
	records: Dictionary,
	order: Array[String],
	current_year: int,
	rng: RandomNumberGenerator,
	all_events: Array[Dictionary]
) -> void:
	for record_key: String in order:
		var record := records[record_key] as Dictionary
		var settlement_type := String(record.get("type", "town"))
		var fell_year := int(record.get("fell_year", 0))
		if fell_year > 0:
			continue
		var notable := false
		match settlement_type:
			"dwarfhold", "lizardmenCity":
				notable = true
			"town":
				notable = int(record.get("population", 0)) >= 900
			_:
				notable = false
		if not notable:
			continue
		var is_dark := String(record.get("class_key", "")) == "dark"
		var dynasty_clan := String(record.get("clan", ""))
		var founded_year := int(record.get("founded_year", 1))
		var settlement_name := String(record.get("name", ""))
		var reign_start := founded_year
		var used_first_names: Dictionary = {}
		var ruler := _roll_lineage_ruler(settlement_type, is_dark, dynasty_clan, used_first_names, rng)
		var lineage: Array = []
		var violent_recorded := 0
		while true:
			var reign_length := rng.randi_range(14, 38)
			if reign_start + reign_length >= current_year:
				break
			var reign_end := reign_start + reign_length
			var heir := _roll_lineage_ruler(settlement_type, is_dark, dynasty_clan, used_first_names, rng)
			## violent_end marks HOW this reign closed: the connector to the
			## heir draws red in the dynasty tree when the seat was taken in
			## blood. Only the first two feuds echo as chronicle events.
			var violent := rng.randf() < 0.18
			lineage.append({
				"name": String(ruler.get("name", "")),
				"title": String(ruler.get("title", "")),
				"gender": String(ruler.get("gender", "")),
				"start": reign_start,
				"end": reign_end,
				"violent_end": violent,
				"sitting": false
			})
			if violent and violent_recorded < 2:
				violent_recorded += 1
				_push_event(
					record, all_events, reign_end, "succession",
					"%s %s was slain; %s %s took the seat amid dark whispers." % [
						String(ruler.get("title", "")), String(ruler.get("name", "")),
						String(heir.get("title", "")), String(heir.get("name", ""))
					],
					settlement_name
				)
			reign_start = reign_end
			ruler = heir
		lineage.append({
			"name": String(ruler.get("name", "")),
			"title": String(ruler.get("title", "")),
			"gender": String(ruler.get("gender", "")),
			"start": reign_start,
			"end": 0,
			"violent_end": false,
			"sitting": true
		})
		record["lineage"] = lineage
		## Dwarfholds grow the succession line into a full dynasty graph —
		## spouses, siblings, aunts, uncles and cousins — for the family
		## tree tab. The flat lineage stays authoritative for dialogue.
		if settlement_type == "dwarfhold":
			record["family"] = build_family_for_lineage(lineage, dynasty_clan, current_year, rng)
		var existing_ruler := String(record.get("ruler_name", "")).strip_edges()
		if settlement_type == "dwarfhold" or existing_ruler.is_empty():
			record["ruler_name"] = String(ruler.get("name", ""))
			record["ruler_title"] = String(ruler.get("title", ""))
			record["ruler_gender"] = String(ruler.get("gender", ""))
		record["ruler_since"] = reign_start

## One member of a succession line. Dwarfholds roll gender-consistent
## name+title pairs from the shared NpcIdentityService pools and keep the
## hold's dynasty clan; other races keep their ungendered pools. First
## names are unique within one line so the tree reads person by person.
static func _roll_lineage_ruler(
	settlement_type: String,
	is_dark: bool,
	dynasty_clan: String,
	used_first_names: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	if settlement_type != "dwarfhold":
		return _roll_person(settlement_type, rng)
	var gender := NpcIdentityService.roll_dwarf_gender(rng)
	var first := NpcIdentityService.dwarf_ruler_first_name(rng, gender)
	for _reroll: int in range(6):
		if not used_first_names.has(first):
			break
		first = NpcIdentityService.dwarf_ruler_first_name(rng, gender)
	used_first_names[first] = true
	var clan := dynasty_clan
	if clan.is_empty():
		clan = NpcIdentityService.DWARF_CLAN_NAMES[rng.randi_range(0, NpcIdentityService.DWARF_CLAN_NAMES.size() - 1)]
	var title := NpcIdentityService.dwarf_ruler_title(rng, gender, is_dark)
	var full_name := "%s %s" % [first, clan]
	return {
		"name": full_name,
		"title": title,
		"gender": gender,
		"full": "%s %s" % [title, full_name]
	}

## --- Dynasty family graphs ----------------------------------------------------
## A dwarfhold's succession line expanded into a small genealogy: every
## included ruler gains a married-in spouse and children (the heir among
## them); occasionally the seat passes to a sibling or a nephew instead.
## Non-heir kin of the most recent generations get spouses and children
## of their own — the sitting ruler's aunts, uncles and cousins. The
## graph is JSON-safe (String/int/bool/Array/Dictionary), deterministic
## from the rng handed in, and bounded by FAMILY_HARD_CAP people.

const FAMILY_HARD_CAP := 76
## How many rulers of a long chain the graph includes; the lineage array
## itself keeps the full line for dialogue and the history tab.
const FAMILY_RULER_WINDOW := 9
## The most recent generations whose non-heir children get spouses and
## children of their own (the cousins). Older generations stay slim.
const FAMILY_RICH_GENERATIONS := 3
const FAMILY_SIBLING_SUCCESSION_CHANCE := 0.12
const FAMILY_NEPHEW_SUCCESSION_CHANCE := 0.12
const FAMILY_KIN_SPOUSE_CHANCE := 0.6

## Builds the family graph for one succession line. Returns {"people":
## {id: person}, "order": [ids], "roots": [ids], "sitting": id, "year":
## int}. Person fields: name/gender/clan/race, birth/death (0 = alive),
## title + reign_start/reign_end + ruler_index for rulers, sitting,
## violent_end (their reign closed in blood), violent_takeover (they
## TOOK the seat in blood), married_in, parents/spouse/children ids,
## generation (tree row, 0 = oldest).
static func build_family_for_lineage(
	lineage: Array,
	dynasty_clan: String,
	current_year: int,
	rng: RandomNumberGenerator
) -> Dictionary:
	if lineage.is_empty():
		return {}
	var people: Dictionary = {}
	var id_order: Array = []
	var used_first: Dictionary = {}
	for member_variant: Variant in lineage:
		used_first[String((member_variant as Dictionary).get("name", "")).get_slice(" ", 0)] = true
	var clan := dynasty_clan
	if clan.is_empty():
		var founder_name := String((lineage[0] as Dictionary).get("name", ""))
		clan = founder_name.get_slice(" ", 1) if founder_name.contains(" ") else "Stonefist"
	var window_start := maxi(0, lineage.size() - FAMILY_RULER_WINDOW)

	## The oldest included ruler roots the tree.
	var root_entry := lineage[window_start] as Dictionary
	var root_fields := _family_ruler_fields(root_entry, window_start, clan)
	root_fields["birth"] = int(root_entry.get("start", 1)) - rng.randi_range(55, 105)
	if window_start > 0:
		root_fields["violent_takeover"] = bool((lineage[window_start - 1] as Dictionary).get("violent_end", false))
	var current_id := _family_add(people, id_order, root_fields)

	## Two generations of unthroned forebears above the oldest included
	## ruler, so the tree reaches back past the first crowned name. The
	## root ruler therefore sits at generation 2 and the chain grows down
	## from there (every later generation derives from its predecessor).
	var root_person := people[current_id] as Dictionary
	root_person["generation"] = 2
	var root_race := String(root_person.get("race", "Dwarf"))
	var elder_id := current_id
	for forebear_generation: int in [1, 0]:
		var elder := people[elder_id] as Dictionary
		var blood_gender := "male" if rng.randf() < 0.5 else "female"
		var blood_birth := int(elder["birth"]) - rng.randi_range(24, 45)
		var blood_id := _individual_add(people, id_order, used_first, rng, "", blood_gender, clan, blood_birth, root_race, false, forebear_generation)
		if blood_id.is_empty():
			break
		var married_id := _individual_add(
			people, id_order, used_first, rng, "",
			"female" if blood_gender == "male" else "male",
			_family_surname(root_race, rng, clan),
			blood_birth + rng.randi_range(-8, 8), root_race, true, forebear_generation
		)
		var forebear_couple: Array[String] = [blood_id]
		if not married_id.is_empty():
			forebear_couple.append(married_id)
		_family_link_child(people, forebear_couple, elder_id)
		_individual_wed(people, blood_id, married_id)
		elder_id = blood_id

	## The chain: each succession places the next ruler as a child,
	## sibling or nephew/niece of the one before.
	for chain_index: int in range(window_start, lineage.size() - 1):
		current_id = _family_place_successor(
			people, id_order, current_id,
			lineage[chain_index] as Dictionary, lineage[chain_index + 1] as Dictionary,
			chain_index + 1, clan, used_first, rng
		)
	var sitting_id := current_id
	var sitting := people[sitting_id] as Dictionary
	sitting["sitting"] = true
	## The sitting ruler always has a consort recorded.
	if String(sitting["spouse"]).is_empty():
		_family_create_spouse(people, id_order, sitting_id, clan, used_first, rng, true)
	var max_generation := int(sitting["generation"])

	## Children for the recent ruler couples (the heir is already among
	## them); older rulers keep only the heir so the graph stays bounded.
	var ruler_ids: Array[String] = []
	for person_id_variant: Variant in id_order:
		var person_id := String(person_id_variant)
		if int((people[person_id] as Dictionary)["ruler_index"]) >= 0:
			ruler_ids.append(person_id)
	for ruler_person_id: String in ruler_ids:
		var ruler_person := people[ruler_person_id] as Dictionary
		if int(ruler_person["generation"]) < max_generation - (FAMILY_RICH_GENERATIONS - 1):
			continue
		if String(ruler_person["spouse"]).is_empty():
			_family_create_spouse(people, id_order, ruler_person_id, clan, used_first, rng, true)
		var reign_end := int(ruler_person["reign_end"])
		if reign_end <= 0:
			reign_end = current_year
		var target_children := rng.randi_range(1, 3) if bool(ruler_person["sitting"]) else rng.randi_range(2, 4)
		while (ruler_person["children"] as Array).size() < target_children:
			var child_id := _family_add_child(
				people, id_order, ruler_person_id,
				int(ruler_person["reign_start"]) + 1, reign_end - 2,
				clan, used_first, rng
			)
			if child_id.is_empty():
				break

	## Spouses and children (the cousins) for the recent non-heir kin:
	## the sitting ruler's aunts and uncles first, then their siblings.
	var kin_ids: Array[String] = []
	for person_id_variant: Variant in id_order:
		var person_id := String(person_id_variant)
		var person := people[person_id] as Dictionary
		if int(person["ruler_index"]) >= 0 or bool(person["married_in"]):
			continue
		if (person["parents"] as Array).is_empty():
			continue
		if int(person["generation"]) < max_generation - 1 or int(person["generation"]) > max_generation:
			continue
		kin_ids.append(person_id)
	var cousin_guaranteed := false
	for kin_id: String in kin_ids:
		var kin := people[kin_id] as Dictionary
		var is_parent_generation := int(kin["generation"]) == max_generation - 1
		var wants_spouse := (is_parent_generation and not cousin_guaranteed) or rng.randf() < FAMILY_KIN_SPOUSE_CHANCE
		var partner_id := ""
		if wants_spouse and String(kin["spouse"]).is_empty():
			partner_id = _family_create_spouse(people, id_order, kin_id, clan, used_first, rng, false)
		var child_count := rng.randi_range(0, 3)
		if is_parent_generation and not partner_id.is_empty() and not cousin_guaranteed:
			child_count = maxi(child_count, 1)
		for _child_slot: int in range(child_count):
			var child_id := _family_add_child(
				people, id_order, kin_id,
				int(kin["birth"]) + 20, mini(int(kin["birth"]) + 48, current_year - 1),
				clan, used_first, rng
			)
			if child_id.is_empty():
				break
			if is_parent_generation:
				cousin_guaranteed = true

	## Deaths: slain rulers fall with their reign, retired ones linger,
	## and long dwarf lifespans let some grandparents overlap the present.
	for person_id_variant: Variant in id_order:
		var person_id := String(person_id_variant)
		var person := people[person_id] as Dictionary
		var death := 0
		if bool(person["sitting"]):
			death = 0
		elif int(person["ruler_index"]) >= 0:
			death = int(person["reign_end"]) + (0 if bool(person["violent_end"]) else rng.randi_range(4, 60))
		else:
			death = int(person["birth"]) + rng.randi_range(150, 250)
		if death >= current_year:
			death = 0
		if death > 0 and death <= int(person["birth"]):
			death = int(person["birth"]) + 1
		person["death"] = death
	## The sitting couple is alive by definition.
	var sitting_spouse_id := String(sitting["spouse"])
	if not sitting_spouse_id.is_empty():
		(people[sitting_spouse_id] as Dictionary)["death"] = 0

	var roots: Array = []
	for person_id_variant: Variant in id_order:
		var person_id := String(person_id_variant)
		var person := people[person_id] as Dictionary
		if (person["parents"] as Array).is_empty() and not bool(person["married_in"]):
			roots.append(person_id)
	return {"people": people, "order": id_order, "roots": roots, "sitting": sitting_id, "year": current_year}

## Builds the family graph centered on one ordinary NPC (dwarf or human),
## not a succession line: the focus is the sitting person (ruler_index -1,
## no title), with their two parents, up to two grandparent couples and
## great-grandparent couples above the blood lines, a scatter of
## aunts/uncles and cousins, siblings, a spouse and children.
## focus keys: name, clan, gender ("" to derive), age, race, current_year,
## spouse (name or ""), parents (Array of names), children (Array of names).
## Returns the same graph shape as build_family_for_lineage; deterministic
## from rng and bounded by FAMILY_HARD_CAP.
static func build_family_for_individual(focus: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var people: Dictionary = {}
	var id_order: Array = []
	var used_first: Dictionary = {}

	var focus_name := String(focus.get("name", "A stranger"))
	var race := String(focus.get("race", "Dwarf"))
	if race.is_empty():
		race = "Dwarf"
	var current_year := int(focus.get("current_year", 200))
	var age := maxi(1, int(focus.get("age", 100)))
	var focus_birth := current_year - age
	var focus_clan := String(focus.get("clan", ""))
	if focus_clan.is_empty():
		focus_clan = focus_name.get_slice(" ", 1) if focus_name.contains(" ") else _family_surname(race, rng, "")
	## The focus's own gender only steers their spouse's gender.
	var focus_gender := String(focus.get("gender", ""))
	if focus_gender.is_empty():
		if race == "Dwarf":
			focus_gender = NpcIdentityService.dwarf_name_gender(focus_name.get_slice(" ", 0))
		if focus_gender.is_empty():
			focus_gender = "female" if rng.randf() < 0.5 else "male"
	used_first[focus_name.get_slice(" ", 0)] = true

	## gen 3: the focus, the sitting person the tree centers on.
	var focus_fields := _family_person_fields(focus_name, focus_gender, focus_clan, focus_birth, race)
	focus_fields["sitting"] = true
	focus_fields["generation"] = 3
	var focus_id := _family_add(people, id_order, focus_fields)

	## gen 2: two parents — a blood parent sharing the focus's clan and a
	## married-in parent of another. Provided names fill them when given.
	var provided_parents := focus.get("parents", []) as Array
	var blood_name := ""
	var married_name := ""
	if provided_parents.size() >= 2:
		var name_a := String(provided_parents[0])
		var name_b := String(provided_parents[1])
		if name_b.get_slice(" ", 1) == focus_clan and name_a.get_slice(" ", 1) != focus_clan:
			blood_name = name_b
			married_name = name_a
		else:
			blood_name = name_a
			married_name = name_b
	elif provided_parents.size() == 1:
		blood_name = String(provided_parents[0])
	var blood_gender := NpcIdentityService.dwarf_name_gender(blood_name.get_slice(" ", 0)) if (race == "Dwarf" and not blood_name.is_empty()) else ""
	if blood_gender.is_empty():
		blood_gender = "male" if rng.randf() < 0.5 else "female"
	var married_gender := "female" if blood_gender == "male" else "male"
	var blood_parent_birth := focus_birth - rng.randi_range(24, 45)
	var married_parent_birth := focus_birth - rng.randi_range(24, 45)
	var blood_parent_id := _individual_add(people, id_order, used_first, rng, blood_name, blood_gender, focus_clan, blood_parent_birth, race, false, 2)
	var married_parent_clan := _family_surname(race, rng, focus_clan)
	if not married_name.is_empty() and married_name.contains(" "):
		married_parent_clan = married_name.get_slice(" ", 1)
	var married_parent_id := _individual_add(people, id_order, used_first, rng, married_name, married_gender, married_parent_clan, married_parent_birth, race, true, 2)
	var focus_parent_ids: Array[String] = []
	if not blood_parent_id.is_empty():
		focus_parent_ids.append(blood_parent_id)
	if not married_parent_id.is_empty():
		focus_parent_ids.append(married_parent_id)
	_family_link_child(people, focus_parent_ids, focus_id)
	_individual_wed(people, blood_parent_id, married_parent_id)

	## gen 1: a grandparent couple over each parent (maternal side second,
	## so it drops out first if the cap is reached).
	var paternal_gp := _individual_grandparents(people, id_order, used_first, rng, blood_parent_id, focus_clan, race, 1)
	var maternal_gp := _individual_grandparents(people, id_order, used_first, rng, married_parent_id, married_parent_clan, race, 1)

	## gen 0: great-grandparent couples over each blood grandparent, so
	## the tree reaches back three full generations from the focus.
	if not paternal_gp.is_empty():
		_individual_grandparents(people, id_order, used_first, rng, paternal_gp[0], focus_clan, race, 0)
	if not maternal_gp.is_empty():
		_individual_grandparents(people, id_order, used_first, rng, maternal_gp[0], married_parent_clan, race, 0)

	## gen 2 aunts/uncles under each grandparent couple, gen 3 cousins under
	## the aunts/uncles that wed.
	_individual_aunts(people, id_order, used_first, rng, paternal_gp, blood_parent_birth, focus_clan, race, current_year, 2)
	_individual_aunts(people, id_order, used_first, rng, maternal_gp, married_parent_birth, married_parent_clan, race, current_year, 2)

	## gen 3 siblings of the focus, sharing the same two parents.
	var sibling_count := rng.randi_range(0, 3)
	for _sibling_slot: int in range(sibling_count):
		if people.size() >= FAMILY_HARD_CAP:
			break
		var sibling_gender := "male" if rng.randf() < 0.5 else "female"
		var sibling_birth := maxi(focus_birth + rng.randi_range(-14, 14), blood_parent_birth + 16)
		var sibling_id := _individual_add(people, id_order, used_first, rng, "", sibling_gender, focus_clan, sibling_birth, race, false, 3)
		if sibling_id.is_empty():
			break
		_family_link_child(people, focus_parent_ids, sibling_id)

	## gen 3 spouse (married-in): the given name, else a ~70% roll.
	var focus_spouse_name := String(focus.get("spouse", ""))
	var focus_spouse_id := ""
	if (not focus_spouse_name.is_empty() or rng.randf() < 0.7) and people.size() < FAMILY_HARD_CAP:
		var spouse_gender := "female" if focus_gender == "male" else "male"
		if race == "Dwarf" and not focus_spouse_name.is_empty():
			var derived := NpcIdentityService.dwarf_name_gender(focus_spouse_name.get_slice(" ", 0))
			if not derived.is_empty():
				spouse_gender = derived
		var spouse_clan := _family_surname(race, rng, focus_clan)
		if not focus_spouse_name.is_empty() and focus_spouse_name.contains(" "):
			spouse_clan = focus_spouse_name.get_slice(" ", 1)
		var spouse_birth := focus_birth + rng.randi_range(-10, 10)
		focus_spouse_id = _individual_add(people, id_order, used_first, rng, focus_spouse_name, spouse_gender, spouse_clan, spouse_birth, race, true, 3)
		_individual_wed(people, focus_id, focus_spouse_id)

	## gen 4 children of the focus: named ones when given, else a small
	## brood only when the focus has a spouse. Born after focus_birth + 16.
	var child_parent_ids: Array[String] = [focus_id]
	if not focus_spouse_id.is_empty():
		child_parent_ids.append(focus_spouse_id)
	var provided_children := focus.get("children", []) as Array
	if not provided_children.is_empty():
		for child_variant: Variant in provided_children:
			if people.size() >= FAMILY_HARD_CAP:
				break
			var child_name := String(child_variant)
			var child_gender := NpcIdentityService.dwarf_name_gender(child_name.get_slice(" ", 0)) if race == "Dwarf" else ""
			var child_hi := current_year - 1
			var child_lo := focus_birth + 16
			if child_hi < child_lo:
				break
			var child_birth := clampi(focus_birth + rng.randi_range(16, maxi(17, age - 1)), child_lo, child_hi)
			var child_id := _individual_add(people, id_order, used_first, rng, child_name, child_gender, focus_clan, child_birth, race, false, 4)
			if child_id.is_empty():
				break
			_family_link_child(people, child_parent_ids, child_id)
	elif not focus_spouse_id.is_empty():
		var child_count := rng.randi_range(0, 3)
		var child_hi := current_year - 1
		var child_lo := focus_birth + 16
		for _child_slot: int in range(child_count):
			if people.size() >= FAMILY_HARD_CAP or child_hi < child_lo:
				break
			var child_gender := "male" if rng.randf() < 0.5 else "female"
			var child_birth := rng.randi_range(child_lo, child_hi)
			var child_id := _individual_add(people, id_order, used_first, rng, "", child_gender, focus_clan, child_birth, race, false, 4)
			if child_id.is_empty():
				break
			_family_link_child(people, child_parent_ids, child_id)

	## Deaths: the focus, their spouse and their children are alive by
	## definition; everyone else dies of old age on their race's clock, and
	## a death at or after the present year just means still living.
	var always_alive: Dictionary = {focus_id: true}
	if not focus_spouse_id.is_empty():
		always_alive[focus_spouse_id] = true
	for child_variant: Variant in ((people[focus_id] as Dictionary)["children"] as Array):
		always_alive[String(child_variant)] = true
	for person_id_variant: Variant in id_order:
		var person_id := String(person_id_variant)
		var person := people[person_id] as Dictionary
		if always_alive.has(person_id):
			person["death"] = 0
			continue
		var person_race := String(person["race"])
		var birth := int(person["birth"])
		var death := 0
		if person_race == "Dwarf":
			death = birth + rng.randi_range(150, 250)
		else:
			var life := int((NpcIdentityService.RACE_AGE_RANGES.get(person_race, [16, 78]) as Array)[1])
			death = birth + rng.randi_range(int(life * 0.9), int(life * 1.15))
		if death >= current_year:
			death = 0
		if death > 0 and death <= birth:
			death = birth + 1
		person["death"] = death

	var roots: Array = []
	for person_id_variant: Variant in id_order:
		var person_id := String(person_id_variant)
		var person := people[person_id] as Dictionary
		if (person["parents"] as Array).is_empty() and not bool(person["married_in"]):
			roots.append(person_id)
	return {"people": people, "order": id_order, "roots": roots, "sitting": focus_id, "year": current_year}

## Adds one ordinary (non-ruler) graph person: resolves a gender and a
## race-aware name when none was supplied, stamps married_in/generation,
## and returns its id ("" when the graph is already at the hard cap).
static func _individual_add(
	people: Dictionary,
	id_order: Array,
	used_first: Dictionary,
	rng: RandomNumberGenerator,
	person_name: String,
	gender: String,
	clan: String,
	birth: int,
	race: String,
	married_in: bool,
	generation: int
) -> String:
	if people.size() >= FAMILY_HARD_CAP:
		return ""
	var final_gender := gender
	if final_gender.is_empty():
		final_gender = "female" if rng.randf() < 0.5 else "male"
	var final_name := person_name
	if final_name.is_empty():
		final_name = "%s %s" % [_family_first_name(final_gender, used_first, rng, race), clan]
	else:
		used_first[final_name.get_slice(" ", 0)] = true
	var fields := _family_person_fields(final_name, final_gender, clan, birth, race)
	fields["married_in"] = married_in
	fields["generation"] = generation
	return _family_add(people, id_order, fields)

## Records a two-way marriage between two graph ids (no-op if either is "").
static func _individual_wed(people: Dictionary, first_id: String, second_id: String) -> void:
	if first_id.is_empty() or second_id.is_empty():
		return
	(people[first_id] as Dictionary)["spouse"] = second_id
	(people[second_id] as Dictionary)["spouse"] = first_id

## A grandparent couple (one blood sharing child_clan, one married-in of
## another) over child_id. Returns the couple's ids, or [] when full.
static func _individual_grandparents(
	people: Dictionary,
	id_order: Array,
	used_first: Dictionary,
	rng: RandomNumberGenerator,
	child_id: String,
	child_clan: String,
	race: String,
	generation: int = 0
) -> Array[String]:
	if child_id.is_empty() or people.size() + 1 >= FAMILY_HARD_CAP:
		return []
	var child := people[child_id] as Dictionary
	var child_birth := int(child["birth"])
	var blood_gender := "male" if rng.randf() < 0.5 else "female"
	var married_gender := "female" if blood_gender == "male" else "male"
	var blood_birth := child_birth - rng.randi_range(24, 45)
	var married_birth := child_birth - rng.randi_range(24, 45)
	var blood_id := _individual_add(people, id_order, used_first, rng, "", blood_gender, child_clan, blood_birth, race, false, generation)
	var married_clan := _family_surname(race, rng, child_clan)
	var married_id := _individual_add(people, id_order, used_first, rng, "", married_gender, married_clan, married_birth, race, true, generation)
	var gp_ids: Array[String] = []
	if not blood_id.is_empty():
		gp_ids.append(blood_id)
	if not married_id.is_empty():
		gp_ids.append(married_id)
	_family_link_child(people, gp_ids, child_id)
	_individual_wed(people, blood_id, married_id)
	return gp_ids

## 0-2 aunts/uncles (siblings of a parent) under a grandparent couple, and
## 0-3 cousins under each aunt/uncle that takes a married-in spouse.
static func _individual_aunts(
	people: Dictionary,
	id_order: Array,
	used_first: Dictionary,
	rng: RandomNumberGenerator,
	grandparents: Array[String],
	parent_birth: int,
	clan: String,
	race: String,
	current_year: int,
	aunt_generation: int = 1
) -> void:
	if grandparents.size() < 2:
		return
	var grandparent_birth := int((people[grandparents[0]] as Dictionary)["birth"])
	var aunt_count := rng.randi_range(0, 2)
	for _aunt_slot: int in range(aunt_count):
		if people.size() >= FAMILY_HARD_CAP:
			break
		var aunt_gender := "male" if rng.randf() < 0.5 else "female"
		var aunt_birth := maxi(parent_birth + rng.randi_range(-12, 12), grandparent_birth + 16)
		var aunt_id := _individual_add(people, id_order, used_first, rng, "", aunt_gender, clan, aunt_birth, race, false, aunt_generation)
		if aunt_id.is_empty():
			break
		_family_link_child(people, grandparents, aunt_id)
		if rng.randf() >= FAMILY_KIN_SPOUSE_CHANCE or people.size() >= FAMILY_HARD_CAP:
			continue
		var spouse_gender := "female" if aunt_gender == "male" else "male"
		var spouse_clan := _family_surname(race, rng, clan)
		var spouse_birth := aunt_birth + rng.randi_range(-10, 10)
		var spouse_id := _individual_add(people, id_order, used_first, rng, "", spouse_gender, spouse_clan, spouse_birth, race, true, aunt_generation)
		if spouse_id.is_empty():
			continue
		_individual_wed(people, aunt_id, spouse_id)
		var cousin_parents: Array[String] = [aunt_id, spouse_id]
		var cousin_count := rng.randi_range(0, 3)
		for _cousin_slot: int in range(cousin_count):
			if people.size() >= FAMILY_HARD_CAP:
				break
			var cousin_gender := "male" if rng.randf() < 0.5 else "female"
			var cousin_birth := mini(aunt_birth + rng.randi_range(18, 40), current_year - 1)
			if cousin_birth <= aunt_birth + 15:
				continue
			var cousin_id := _individual_add(people, id_order, used_first, rng, "", cousin_gender, clan, cousin_birth, race, false, aunt_generation + 1)
			if cousin_id.is_empty():
				break
			_family_link_child(people, cousin_parents, cousin_id)

## Seats lineage member heir_entry in the graph relative to the ruler it
## succeeds: usually their child, sometimes a sibling or a nephew/niece
## (which reads especially well under a violent succession). Returns the
## new ruler's person id.
static func _family_place_successor(
	people: Dictionary,
	id_order: Array,
	ruler_id: String,
	ruler_entry: Dictionary,
	heir_entry: Dictionary,
	heir_index: int,
	clan: String,
	used_first: Dictionary,
	rng: RandomNumberGenerator
) -> String:
	var ruler := people[ruler_id] as Dictionary
	var ruler_parents := ruler["parents"] as Array
	var relation := "child"
	var roll := rng.randf()
	if not ruler_parents.is_empty():
		if roll < FAMILY_SIBLING_SUCCESSION_CHANCE:
			relation = "sibling"
		elif roll < FAMILY_SIBLING_SUCCESSION_CHANCE + FAMILY_NEPHEW_SUCCESSION_CHANCE:
			relation = "nephew"
	var fields := _family_ruler_fields(heir_entry, heir_index, clan)
	fields["violent_takeover"] = bool(ruler_entry.get("violent_end", false))
	var parent_ids: Array[String] = []
	if relation == "sibling":
		for parent_variant: Variant in ruler_parents:
			parent_ids.append(String(parent_variant))
		fields["generation"] = int(ruler["generation"])
		## A younger sibling, but born before they took the seat.
		fields["birth"] = clampi(
			int(ruler["birth"]) + rng.randi_range(2, 16),
			int(ruler["birth"]) + 1,
			int(fields["reign_start"]) - 2
		)
	elif relation == "nephew":
		var sibling_id := _family_find_or_create_sibling(people, id_order, ruler_id, clan, used_first, rng)
		if sibling_id.is_empty():
			relation = "child"
		else:
			var sibling := people[sibling_id] as Dictionary
			var partner_id := String(sibling["spouse"])
			if partner_id.is_empty():
				partner_id = _family_create_spouse(people, id_order, sibling_id, clan, used_first, rng, true)
			parent_ids.append(sibling_id)
			if not partner_id.is_empty():
				parent_ids.append(partner_id)
			fields["generation"] = int(sibling["generation"]) + 1
			var nephew_hi := int(ruler["reign_end"]) - 2
			var nephew_lo := mini(maxi(int(sibling["birth"]) + 16, int(ruler["reign_start"]) - 8), nephew_hi)
			nephew_lo = maxi(nephew_lo, int(sibling["birth"]) + 1)
			fields["birth"] = rng.randi_range(nephew_lo, maxi(nephew_lo, nephew_hi))
	if relation == "child":
		var spouse_id := String(ruler["spouse"])
		if spouse_id.is_empty():
			spouse_id = _family_create_spouse(people, id_order, ruler_id, clan, used_first, rng, true)
		parent_ids.append(ruler_id)
		if not spouse_id.is_empty():
			parent_ids.append(spouse_id)
		fields["generation"] = int(ruler["generation"]) + 1
		var oldest_parent_birth := int(ruler["birth"])
		if not spouse_id.is_empty():
			oldest_parent_birth = maxi(oldest_parent_birth, int((people[spouse_id] as Dictionary)["birth"]))
		## Born inside the parent's reign; the reign window wins over the
		## generation-gap wish so nobody is born after their own accession.
		var child_hi := int(ruler["reign_end"]) - 2
		var child_lo := mini(maxi(int(ruler["reign_start"]) + 1, oldest_parent_birth + 16), child_hi)
		fields["birth"] = rng.randi_range(child_lo, maxi(child_lo, child_hi))
	var heir_id := _family_add(people, id_order, fields)
	_family_link_child(people, parent_ids, heir_id)
	return heir_id

## An existing non-ruler sibling of ruler_id, or a freshly rolled one
## under the same parents ("" when the graph is full or rootless).
static func _family_find_or_create_sibling(
	people: Dictionary,
	id_order: Array,
	ruler_id: String,
	clan: String,
	used_first: Dictionary,
	rng: RandomNumberGenerator
) -> String:
	var ruler := people[ruler_id] as Dictionary
	var ruler_parents := ruler["parents"] as Array
	if ruler_parents.is_empty():
		return ""
	var parent := people[String(ruler_parents[0])] as Dictionary
	for child_variant: Variant in (parent["children"] as Array):
		var child_id := String(child_variant)
		if child_id != ruler_id and int((people[child_id] as Dictionary)["ruler_index"]) < 0:
			return child_id
	if people.size() + 2 > FAMILY_HARD_CAP:
		return ""
	var gender := "female" if rng.randf() < 0.5 else "male"
	var birth := clampi(
		int(ruler["birth"]) + rng.randi_range(-10, 10),
		int(parent["birth"]) + 16,
		int(ruler["reign_start"]) - 2
	)
	var fields := _family_person_fields("%s %s" % [_family_first_name(gender, used_first, rng), clan], gender, clan, birth)
	fields["generation"] = int(ruler["generation"])
	var sibling_id := _family_add(people, id_order, fields)
	var parent_ids: Array[String] = []
	for parent_variant: Variant in ruler_parents:
		parent_ids.append(String(parent_variant))
	_family_link_child(people, parent_ids, sibling_id)
	return sibling_id

## A married-in spouse for partner_id: a different clan, a name from the
## matching gendered pool, gender opposite (always for dynasty parents,
## nearly always otherwise). Returns "" when the graph is full.
static func _family_create_spouse(
	people: Dictionary,
	id_order: Array,
	partner_id: String,
	dynasty_clan: String,
	used_first: Dictionary,
	rng: RandomNumberGenerator,
	force_opposite: bool
) -> String:
	if people.size() >= FAMILY_HARD_CAP:
		return ""
	var partner := people[partner_id] as Dictionary
	var partner_gender := String(partner["gender"])
	var gender := "female" if partner_gender == "male" else "male"
	if not force_opposite and rng.randf() < 0.08:
		gender = partner_gender
	var spouse_clan := dynasty_clan
	for _reroll: int in range(6):
		spouse_clan = NpcIdentityService.DWARF_CLAN_NAMES[rng.randi_range(0, NpcIdentityService.DWARF_CLAN_NAMES.size() - 1)]
		if spouse_clan != dynasty_clan:
			break
	var fields := _family_person_fields(
		"%s %s" % [_family_first_name(gender, used_first, rng), spouse_clan],
		gender, spouse_clan,
		int(partner["birth"]) + rng.randi_range(-14, 14)
	)
	fields["married_in"] = true
	fields["generation"] = int(partner["generation"])
	var spouse_id := _family_add(people, id_order, fields)
	partner["spouse"] = spouse_id
	(people[spouse_id] as Dictionary)["spouse"] = partner_id
	return spouse_id

## One child of parent_id (and their spouse when wed), born inside
## [birth_lo, birth_hi] and after both parents. "" when impossible.
static func _family_add_child(
	people: Dictionary,
	id_order: Array,
	parent_id: String,
	birth_lo: int,
	birth_hi: int,
	clan: String,
	used_first: Dictionary,
	rng: RandomNumberGenerator
) -> String:
	if people.size() >= FAMILY_HARD_CAP:
		return ""
	var parent := people[parent_id] as Dictionary
	var parent_ids: Array[String] = [parent_id]
	var lo := maxi(birth_lo, int(parent["birth"]) + 16)
	var spouse_id := String(parent["spouse"])
	if not spouse_id.is_empty():
		parent_ids.append(spouse_id)
		lo = maxi(lo, int((people[spouse_id] as Dictionary)["birth"]) + 16)
	if birth_hi < lo:
		return ""
	var gender := "female" if rng.randf() < 0.5 else "male"
	var fields := _family_person_fields(
		"%s %s" % [_family_first_name(gender, used_first, rng), clan],
		gender, clan, rng.randi_range(lo, birth_hi)
	)
	fields["generation"] = int(parent["generation"]) + 1
	var child_id := _family_add(people, id_order, fields)
	_family_link_child(people, parent_ids, child_id)
	return child_id

## Person skeleton with every key present, so readers can index without
## existence checks. All values JSON-safe.
static func _family_person_fields(person_name: String, gender: String, person_clan: String, birth: int, race: String = "Dwarf") -> Dictionary:
	return {
		"id": "",
		"name": person_name,
		"gender": gender,
		"clan": person_clan,
		"race": race,
		"birth": birth,
		"death": 0,
		"title": "",
		"reign_start": 0,
		"reign_end": 0,
		"sitting": false,
		"violent_end": false,
		"violent_takeover": false,
		"married_in": false,
		"ruler_index": -1,
		"parents": [],
		"spouse": "",
		"children": [],
		"generation": 0
	}

## Person fields for one lineage ruler (name, title, reign, flags).
static func _family_ruler_fields(entry: Dictionary, lineage_index: int, clan: String) -> Dictionary:
	var fields := _family_person_fields(String(entry.get("name", "")), String(entry.get("gender", "")), clan, 0)
	fields["title"] = String(entry.get("title", ""))
	fields["reign_start"] = int(entry.get("start", 0))
	fields["reign_end"] = int(entry.get("end", 0))
	fields["sitting"] = bool(entry.get("sitting", false))
	fields["violent_end"] = bool(entry.get("violent_end", false))
	fields["ruler_index"] = lineage_index
	return fields

static func _family_add(people: Dictionary, id_order: Array, fields: Dictionary) -> String:
	var person_id := "p%d" % id_order.size()
	fields["id"] = person_id
	people[person_id] = fields
	id_order.append(person_id)
	return person_id

## Wires child_id under every id in parent_ids, both directions.
static func _family_link_child(people: Dictionary, parent_ids: Array[String], child_id: String) -> void:
	var child := people[child_id] as Dictionary
	var child_parents := child["parents"] as Array
	for parent_id: String in parent_ids:
		if parent_id.is_empty() or child_parents.has(parent_id) or not people.has(parent_id):
			continue
		child_parents.append(parent_id)
		var parent := people[parent_id] as Dictionary
		var parent_children := parent["children"] as Array
		if not parent_children.has(child_id):
			parent_children.append(child_id)

## A first name from the gendered dwarf pools, avoiding names the graph
## already uses when it can (the pools are finite; a long dynasty may
## repeat a first name under a different clan).
static func _family_first_name(gender: String, used_first: Dictionary, rng: RandomNumberGenerator, race: String = "Dwarf") -> String:
	var pool: Array[String] = []
	if race == "Human":
		pool.append_array(
			NpcIdentityService.TOWNSFOLK_FIRST_NAMES_FEMALE
			if gender == "female"
			else NpcIdentityService.TOWNSFOLK_FIRST_NAMES_MALE
		)
	elif gender == "female":
		pool.append_array(NpcIdentityService.DWARF_FIRST_NAMES_FEMALE)
		pool.append_array(NpcIdentityService.DWARF_RULER_FIRST_NAMES_FEMALE)
	else:
		pool.append_array(NpcIdentityService.DWARF_FIRST_NAMES_MALE)
		pool.append_array(NpcIdentityService.DWARF_RULER_FIRST_NAMES_MALE)
	var first := pool[rng.randi_range(0, pool.size() - 1)]
	for _reroll: int in range(12):
		if not used_first.has(first):
			break
		first = pool[rng.randi_range(0, pool.size() - 1)]
	used_first[first] = true
	return first

## A surname for the given race (dwarf clans, human trade-names), rerolled
## a few times so a married-in line differs from avoid_clan when it can.
static func _family_surname(race: String, rng: RandomNumberGenerator, avoid_clan: String) -> String:
	var pool: Array[String] = []
	if race == "Human":
		pool.append_array(NpcIdentityService.TOWNSFOLK_SURNAMES)
	else:
		pool.append_array(NpcIdentityService.DWARF_CLAN_NAMES)
	var surname := pool[rng.randi_range(0, pool.size() - 1)]
	for _reroll: int in range(6):
		if surname != avoid_clan:
			break
		surname = pool[rng.randi_range(0, pool.size() - 1)]
	return surname

## Sorts, caps and cross-links each settlement's story: neighbor ruins
## feed rumors and grudges so a town gossips about the fallen hold nearby.
static func _finalize_settlements(
	records: Dictionary,
	order: Array[String],
	beasts: Array,
	current_year: int
) -> void:
	var fallen_keys: Array[String] = []
	for record_key: String in order:
		var record := records[record_key] as Dictionary
		if int(record.get("fell_year", 0)) > 0:
			fallen_keys.append(record_key)
	for record_key: String in order:
		var record := records[record_key] as Dictionary
		var events := record.get("events", []) as Array
		events.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			if int(left.get("year", 0)) != int(right.get("year", 0)):
				return int(left.get("year", 0)) < int(right.get("year", 0))
			return String(left.get("type", "")) < String(right.get("type", ""))
		)
		if events.size() > SETTLEMENT_EVENT_CAP:
			var kept: Array = []
			var overflow: Array = []
			for event_variant: Variant in events:
				var event := event_variant as Dictionary
				var event_type := String(event.get("type", ""))
				if event_type == "founding" or event_type == "fall" or event_type == "razing":
					kept.append(event)
				else:
					overflow.append(event)
			var slot_count := SETTLEMENT_EVENT_CAP - kept.size()
			for overflow_index: int in range(mini(slot_count, overflow.size())):
				kept.append(overflow[overflow_index])
			kept.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
				return int(left.get("year", 0)) < int(right.get("year", 0))
			)
			events = kept
		record["events"] = events
		# Neighbor scars: the nearest fallen or razed site within gossip range.
		if int(record.get("fell_year", 0)) <= 0:
			var origin := Vector2(float(record.get("x", 0)), float(record.get("y", 0)))
			var best_key := ""
			var best_distance := NEIGHBOR_RUMOR_DISTANCE
			for fallen_key: String in fallen_keys:
				if fallen_key == record_key:
					continue
				var fallen := records[fallen_key] as Dictionary
				var fallen_point := Vector2(float(fallen.get("x", 0)), float(fallen.get("y", 0)))
				var distance := origin.distance_to(fallen_point)
				if distance < best_distance:
					best_distance = distance
					best_key = fallen_key
			if not best_key.is_empty():
				var fallen := records[best_key] as Dictionary
				var fallen_name := String(fallen.get("name", ""))
				if bool(fallen.get("razed", false)):
					(record["rumors"] as Array).append("Nobody rebuilds %s. Not after year %d — %s." % [fallen_name, int(fallen.get("fell_year", 0)), GameCalendar.year_title(int(fallen.get("fell_year", 0)))])
					(record["agenda_goals"] as Array).append("to avenge the razing of %s" % fallen_name)
				else:
					var beast_name := String(fallen.get("fall_beast", ""))
					var beast := _beast_by_name(beasts, beast_name)
					if not beast.is_empty() and String(beast.get("status", "")) == "alive":
						(record["rumors"] as Array).append("They say %s still nests where %s fell." % [String(beast.get("display", "the beast")), fallen_name])
						(record["agenda_goals"] as Array).append("to see %s slain" % String(beast.get("display", "the beast")))
					else:
						(record["rumors"] as Array).append("There is dwarf-gold still under %s, if you dare the silent halls." % fallen_name)
						if String(record.get("type", "")) == "dwarfhold":
							(record["agenda_goals"] as Array).append("to reclaim the silent halls of %s" % fallen_name)
		record["rumors"] = _cap_strings(record.get("rumors", []) as Array, 4)
		record["agenda_goals"] = _cap_strings(record.get("agenda_goals", []) as Array, 3)
		record["founded_years_ago"] = maxi(1, current_year - int(record.get("founded_year", 1)))

static func _beast_by_name(beasts: Array, beast_name: String) -> Dictionary:
	if beast_name.is_empty():
		return {}
	for beast_variant: Variant in beasts:
		var beast := beast_variant as Dictionary
		if String(beast.get("name", "")) == beast_name:
			return beast
	return {}

static func _cap_strings(entries: Array, cap: int) -> Array:
	var unique: Array = []
	for entry_variant: Variant in entries:
		var text := String(entry_variant)
		if text.is_empty() or unique.has(text):
			continue
		unique.append(text)
		if unique.size() >= cap:
			break
	return unique

## The 15-25 loudest echoes, importance-ranked then told in year order.
static func _select_world_events(all_events: Array[Dictionary], _current_year: int) -> Array:
	var scored := all_events.duplicate()
	scored.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := int(WORLD_EVENT_IMPORTANCE.get(String(left.get("type", "")), 0))
		var right_score := int(WORLD_EVENT_IMPORTANCE.get(String(right.get("type", "")), 0))
		if left_score != right_score:
			return left_score > right_score
		return int(left.get("year", 0)) < int(right.get("year", 0))
	)
	var keep_count := clampi(scored.size(), 0, WORLD_EVENT_MAX)
	if scored.size() > WORLD_EVENT_MIN:
		keep_count = maxi(WORLD_EVENT_MIN, keep_count)
	var picked: Array = []
	for event_index: int in range(keep_count):
		var event := scored[event_index] as Dictionary
		var site_name := String(event.get("site_name", ""))
		var text := String(event.get("text", ""))
		if not site_name.is_empty():
			text = "%s — %s" % [site_name, text]
		picked.append({
			"year": int(event.get("year", 0)),
			"type": String(event.get("type", "")),
			"text": text
		})
	picked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("year", 0)) < int(right.get("year", 0))
	)
	return picked

## A handful of world-scale rumors any settlement may repeat.
static func _build_world_rumors(chronicle: Dictionary, rng: RandomNumberGenerator) -> Array:
	var rumors: Array = []
	for war_variant: Variant in (chronicle.get("wars", []) as Array):
		var war := war_variant as Dictionary
		var battles := war.get("battles", []) as Array
		if battles.is_empty():
			continue
		var battle := battles[rng.randi_range(0, battles.size() - 1)] as Dictionary
		rumors.append("They still sing of the %s, from %s." % [String(battle.get("name", "old battle")), _war_ref(String(war.get("name", "the war")))])
	for beast_variant: Variant in (chronicle.get("beasts", []) as Array):
		var beast := beast_variant as Dictionary
		if String(beast.get("status", "")) == "slain":
			rumors.append("%s is dead, they say — %s slew it in the year %d, %s. I'd still not whistle in the deeps." % [
				_capitalize_first(String(beast.get("display", "the beast"))),
				String(beast.get("slain_by", "a hero")),
				int(beast.get("slain_year", 0)),
				GameCalendar.year_title(int(beast.get("slain_year", 0)))
			])
		elif not String(beast.get("lair", "")).is_empty():
			rumors.append("They say %s still nests where %s fell." % [String(beast.get("display", "the beast")), String(beast.get("lair", ""))])
	return _cap_strings(rumors, 6)

## --- Shared event plumbing ---------------------------------------------------

static func _push_event(record: Dictionary, all_events: Array[Dictionary], event_year: int, event_type: String, text: String, site_name: String) -> void:
	var event := {"year": event_year, "type": event_type, "text": text}
	(record["events"] as Array).append(event)
	all_events.append({"year": event_year, "type": event_type, "text": text, "site_name": site_name})

## magnitude > 0 is a population dip ratio, < 0 a boom; 1.0 means the end.
static func _push_mark(record: Dictionary, mark_year: int, kind: String, magnitude: float) -> void:
	(record["marks"] as Array).append({"year": mark_year, "kind": kind, "magnitude": magnitude})

static func _roll_person(settlement_type: String, rng: RandomNumberGenerator) -> Dictionary:
	var first := ""
	var last := ""
	var title := ""
	var gender := ""
	match settlement_type:
		"dwarfhold":
			## Founders and heroes are gender-consistent like the ruler
			## lines: gender first, then name and title from matching pools.
			gender = NpcIdentityService.roll_dwarf_gender(rng)
			var first_pool := (
				NpcIdentityService.DWARF_FIRST_NAMES_FEMALE
				if gender == "female"
				else NpcIdentityService.DWARF_FIRST_NAMES_MALE
			)
			first = first_pool[rng.randi_range(0, first_pool.size() - 1)]
			last = NpcIdentityService.DWARF_CLAN_NAMES[rng.randi_range(0, NpcIdentityService.DWARF_CLAN_NAMES.size() - 1)]
			title = NpcIdentityService.dwarf_ruler_title(rng, gender, false)
		"woodElfGrove":
			first = ELF_FIRST_NAMES[rng.randi_range(0, ELF_FIRST_NAMES.size() - 1)]
			title = ELF_RULER_TITLES[rng.randi_range(0, ELF_RULER_TITLES.size() - 1)]
		"lizardmenCity":
			var prefixes: Array[String] = OVERWORLD_CONTENT.LIZARDMEN_CITY_NAME_PREFIXES
			var suffixes: Array[String] = OVERWORLD_CONTENT.LIZARDMEN_CITY_NAME_SUFFIXES
			first = "%s%s" % [
				prefixes[rng.randi_range(0, prefixes.size() - 1)],
				suffixes[rng.randi_range(0, suffixes.size() - 1)]
			]
			title = LIZARD_RULER_TITLES[rng.randi_range(0, LIZARD_RULER_TITLES.size() - 1)]
		_:
			## Towns mirror the dwarfhold branch: gender first, then name
			## and title from matching pools.
			gender = "female" if rng.randf() < 0.5 else "male"
			var town_pool := (
				NpcIdentityService.TOWNSFOLK_FIRST_NAMES_FEMALE
				if gender == "female"
				else NpcIdentityService.TOWNSFOLK_FIRST_NAMES_MALE
			)
			first = town_pool[rng.randi_range(0, town_pool.size() - 1)]
			last = NpcIdentityService.TOWNSFOLK_SURNAMES[rng.randi_range(0, NpcIdentityService.TOWNSFOLK_SURNAMES.size() - 1)]
			var town_titles := (
				TOWN_RULER_TITLES_FEMALE if gender == "female" else TOWN_RULER_TITLES_MALE
			)
			title = town_titles[rng.randi_range(0, town_titles.size() - 1)]
	var full_name := first if last.is_empty() else "%s %s" % [first, last]
	return {
		"name": full_name,
		"title": title,
		"gender": gender,
		"full": "%s %s" % [title, full_name]
	}

static func _capitalize_first(text: String) -> String:
	if text.is_empty():
		return text
	return text.substr(0, 1).to_upper() + text.substr(1)

## Realm names are mostly titled forms ("Kingdom of Valemont") that read
## wrong bare in a sentence ("the armies of Kingdom of Valemont"); those
## take a leading "the". Standalone names ("Ironroot") pass through.
static func _realm_ref(state_name: String) -> String:
	var trimmed := state_name.strip_edges()
	if trimmed.is_empty() or trimmed.begins_with("The ") or trimmed.begins_with("the "):
		return trimmed
	if trimmed.contains(" of "):
		return "the %s" % trimmed
	return trimmed

## War names are minted as "The X War"; mid-sentence the capital reads
## wrong ("as The Salt War ended").
static func _war_ref(war_name: String) -> String:
	if war_name.begins_with("The "):
		return "the %s" % war_name.trim_prefix("The ")
	return war_name

## --- Population timelines ----------------------------------------------------

## Replays a settlement's chronicle marks into the population chart data:
## plagues and sieges dip the curve at their exact years, golden ages lift
## it, and fallen or razed sites drop to zero and stay there. Point years
## are ABSOLUTE chronicle years so the chart aligns with the history tab.
static func build_population_timeline(
	founded_year: int,
	current_year: int,
	final_population: int,
	peak_population: int,
	fell_year: int,
	marks: Array,
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var start_year := clampi(founded_year, 1, maxi(1, current_year))
	var end_year := maxi(start_year, current_year)
	var span := end_year - start_year
	var target := float(maxi(final_population, 20)) if fell_year <= 0 else float(maxi(peak_population, 60))
	if fell_year <= 0 and final_population <= 0:
		return []
	# Sample years: a coarse grid plus every mark year, so shocks always land.
	var step := maxi(1, int(ceil(float(span) / 120.0)))
	var sample_set: Dictionary = {}
	var sample_year := start_year
	while sample_year <= end_year:
		sample_set[sample_year] = true
		sample_year += step
	sample_set[end_year] = true
	var shock_by_year: Dictionary = {}
	var boom_years: Dictionary = {}
	for mark_variant: Variant in marks:
		var mark := mark_variant as Dictionary
		var mark_year := clampi(int(mark.get("year", 0)), start_year, end_year)
		var magnitude := float(mark.get("magnitude", 0.0))
		sample_set[mark_year] = true
		sample_set[mini(mark_year + maxi(1, step), end_year)] = true
		if magnitude >= 0.999:
			continue
		if magnitude > 0.0:
			shock_by_year[mark_year] = maxf(float(shock_by_year.get(mark_year, 0.0)), magnitude)
		else:
			for boom_year: int in range(mark_year, mini(mark_year + 20, end_year) + 1):
				boom_years[boom_year] = true
			sample_set[mini(mark_year + 20, end_year)] = true
	if fell_year > 0:
		var clamped_fall := clampi(fell_year, start_year, end_year)
		sample_set[clamped_fall] = true
		sample_set[maxi(clamped_fall - 1, start_year)] = true
	var sample_years: Array = sample_set.keys()
	sample_years.sort()

	var value := maxf(12.0, target * rng.randf_range(0.15, 0.4))
	var points: Array[Dictionary] = []
	var previous_year := start_year
	for year_variant: Variant in sample_years:
		var point_year := int(year_variant)
		var elapsed := point_year - previous_year
		previous_year = point_year
		if elapsed > 0:
			var pull := 1.0 - pow(0.965, float(elapsed))
			var local_target := target * (1.18 if boom_years.has(point_year) else 1.0)
			value += (local_target - value) * pull
			value += value * rng.randf_range(-0.02, 0.025)
		if shock_by_year.has(point_year):
			value *= 1.0 - float(shock_by_year[point_year])
		value = clampf(value, 8.0, target * 1.6)
		var population_value := int(round(value))
		if fell_year > 0 and point_year >= fell_year:
			population_value = 0
		if fell_year <= 0 and point_year == end_year:
			population_value = final_population
		var label := "Founding" if point_year == start_year else ("Current" if point_year == end_year else "Year %d" % point_year)
		points.append({
			"label": label,
			"year": point_year,
			"population": maxi(0, population_value),
			"years_ago": maxi(0, current_year - point_year)
		})
	return points

## --- Read-side helpers (scenes + UI) -----------------------------------------

static func chronicle_from_settings(settings: Dictionary) -> Dictionary:
	var stored: Variant = settings.get(SETTINGS_KEY, {})
	if stored is Dictionary:
		return stored as Dictionary
	return {}

## Finds a settlement entry by display name ("Ruins of X" matches X too).
static func settlement_entry_by_name(chronicle: Dictionary, settlement_name: String) -> Dictionary:
	var wanted := settlement_name.strip_edges()
	if wanted.is_empty():
		return {}
	if wanted.begins_with("Ruins of "):
		wanted = wanted.trim_prefix("Ruins of ")
	var settlements := chronicle.get("settlements", {}) as Dictionary
	for entry_key_variant: Variant in settlements.keys():
		var entry := settlements[entry_key_variant] as Dictionary
		if String(entry.get("name", "")) == wanted:
			return entry
	return {}

## History-flavored rumor for a settlement's NPCs: local memory first,
## world-scale echoes as the fallback. Empty when no chronicle exists.
## Beasts the player slew flip the talk: stale "still nests" lines drop
## and the taverns celebrate the deed instead.
static func history_rumor(settings: Dictionary, settlement_name: String, rng: RandomNumberGenerator) -> String:
	var chronicle := chronicle_from_settings(settings)
	if chronicle.is_empty():
		return ""
	var pool: Array[String] = []
	var entry := settlement_entry_by_name(chronicle, settlement_name)
	for rumor_variant: Variant in (entry.get("rumors", []) as Array):
		pool.append(String(rumor_variant))
	if pool.is_empty() or rng.randf() < 0.35:
		for rumor_variant: Variant in (chronicle.get("world_rumors", []) as Array):
			pool.append(String(rumor_variant))
	var celebration := player_kill_rumors(settings)
	if not celebration.is_empty():
		var kills := player_kills(settings)
		var slain_displays: Array[String] = []
		for beast_variant: Variant in (chronicle.get("beasts", []) as Array):
			var beast := beast_variant as Dictionary
			if kills.has(String(beast.get("name", ""))):
				slain_displays.append(String(beast.get("display", "")))
		# Baked lines still fearing the dead beast ("still nests", "will
		# come back") read wrong once the player has done the deed.
		var filtered: Array[String] = []
		for line: String in pool:
			var mentions_slain := false
			for display: String in slain_displays:
				if not display.is_empty() and line.contains(display):
					mentions_slain = true
					break
			if not mentions_slain:
				filtered.append(line)
		pool = filtered
		pool.append_array(celebration)
	if pool.is_empty():
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]

## Celebration lines for beasts the player personally slew.
static func player_kill_rumors(settings: Dictionary) -> Array[String]:
	var chronicle := chronicle_from_settings(settings)
	var kills := player_kills(settings)
	var lines: Array[String] = []
	if chronicle.is_empty() or kills.is_empty():
		return lines
	for beast_variant: Variant in (chronicle.get("beasts", []) as Array):
		var beast := beast_variant as Dictionary
		var beast_name := String(beast.get("name", ""))
		if not kills.has(beast_name):
			continue
		var kill := kills[beast_name] as Dictionary
		var slayer := String(kill.get("by", "a wanderer"))
		var display := String(beast.get("display", "the beast"))
		lines.append("Have you heard? %s slew %s! The taverns have not stopped toasting the deed." % [slayer, display])
		lines.append("They say %s walked out of %s carrying proof %s is dead. What a time to be alive." % [
			slayer, String(kill.get("place", "the lair")), display
		])
	return lines

## --- Player-made beast history -------------------------------------------------

static func player_kills(settings: Dictionary) -> Dictionary:
	var stored: Variant = settings.get(KILLS_KEY, {})
	if stored is Dictionary:
		return stored as Dictionary
	return {}

## True when the beast is dead — slain by a hero in the simulation or by
## the player afterwards. Spawn paths check this so a dead beast never
## walks again.
static func is_beast_slain(settings: Dictionary, beast_name: String) -> bool:
	if beast_name.is_empty():
		return true
	if player_kills(settings).has(beast_name):
		return true
	var beast := _beast_by_name(chronicle_from_settings(settings).get("beasts", []) as Array, beast_name)
	return not beast.is_empty() and String(beast.get("status", "alive")) == "slain"

## Patches a (freshly simulated or stored) chronicle with the player's
## kills: the beast's fate flips to slain and the world chronicle gains
## the "was slain by <player> at <place>" event once.
static func apply_player_kills(chronicle: Dictionary, kills: Dictionary) -> void:
	if chronicle.is_empty() or kills.is_empty():
		return
	var world_events := chronicle.get("world_events", []) as Array
	for beast_variant: Variant in (chronicle.get("beasts", []) as Array):
		var beast := beast_variant as Dictionary
		var beast_name := String(beast.get("name", ""))
		if not kills.has(beast_name):
			continue
		var kill := kills[beast_name] as Dictionary
		beast["status"] = "slain"
		beast["slain_year"] = int(kill.get("year", 0))
		beast["slain_by"] = String(kill.get("by", "a wanderer"))
		beast["slain_by_player"] = true
		var event_text := "%s was slain by %s at %s." % [
			_capitalize_first(String(beast.get("display", "the beast"))),
			String(kill.get("by", "a wanderer")),
			String(kill.get("place", "its lair"))
		]
		var already_recorded := false
		for event_variant: Variant in world_events:
			if String((event_variant as Dictionary).get("text", "")) == event_text:
				already_recorded = true
				break
		if not already_recorded:
			world_events.append({"year": int(kill.get("year", 0)), "type": "beast_slain", "text": event_text})
	chronicle["world_events"] = world_events

## Records the player slaying a beast: the kill register and the stored
## chronicle in the SAME settings dictionary are both updated, so the
## deed survives scene changes and saves. Callers persist the settings.
static func record_player_beast_kill(settings: Dictionary, beast_name: String, player_name: String, place_name: String, kill_year: int) -> void:
	if beast_name.is_empty():
		return
	var slayer := player_name.strip_edges()
	if slayer.is_empty():
		slayer = "A wanderer"
	var place := place_name.strip_edges()
	if place.is_empty():
		place = "its lair"
	var kills := player_kills(settings).duplicate()
	kills[beast_name] = {"year": maxi(1, kill_year), "by": slayer, "place": place}
	settings[KILLS_KEY] = kills
	var chronicle := chronicle_from_settings(settings)
	apply_player_kills(chronicle, kills)

## --- Player deaths -------------------------------------------------------------

static func player_deaths(settings: Dictionary) -> Array:
	var stored: Variant = settings.get(DEATHS_KEY, [])
	if stored is Array:
		return stored as Array
	return []

## One chronicle line for a recorded death.
static func _death_event_text(death: Dictionary) -> String:
	var who := String(death.get("name", "A wanderer"))
	var place := String(death.get("place", "the wilds"))
	var cause := String(death.get("cause", "")).strip_edges()
	if cause == "starvation":
		return "%s starved to death at %s." % [who, place]
	if cause.is_empty():
		return "%s perished at %s." % [who, place]
	return "%s perished at %s, slain by %s." % [who, place, _cause_ref(cause)]

## Creature defs carry Title-Case display names ("Orc Raider"), which read
## raw in a sentence — those become "an orc raider". Already-phrased causes
## ("the fire jets", "a whirling saw blade", named beasts) pass through.
static func _cause_ref(cause: String) -> String:
	if cause.begins_with("The "):
		return "the %s" % cause.trim_prefix("The ")
	var first_char := cause.substr(0, 1)
	if first_char != first_char.to_upper():
		return cause
	var lowered := cause.to_lower()
	var article := "an" if lowered.substr(0, 1) in ["a", "e", "i", "o", "u"] else "a"
	return "%s %s" % [article, lowered]

## Patches a (freshly simulated or stored) chronicle with the deaths of
## player characters: each becomes a world event (and a tavern rumor)
## once, the same mechanism the beast-kill register rides.
static func apply_player_deaths(chronicle: Dictionary, deaths: Array) -> void:
	if chronicle.is_empty() or deaths.is_empty():
		return
	var world_events := chronicle.get("world_events", []) as Array
	var world_rumors := chronicle.get("world_rumors", []) as Array
	for death_variant: Variant in deaths:
		if not (death_variant is Dictionary):
			continue
		var death := death_variant as Dictionary
		var event_text := _death_event_text(death)
		var already_recorded := false
		for event_variant: Variant in world_events:
			if String((event_variant as Dictionary).get("text", "")) == event_text:
				already_recorded = true
				break
		if already_recorded:
			continue
		world_events.append({"year": maxi(1, int(death.get("year", 0))), "type": "player_death", "text": event_text})
		world_rumors.append("They say %s A grim business." % event_text)
	chronicle["world_events"] = world_events
	chronicle["world_rumors"] = world_rumors

## Records a player character's death: the persistent register and the
## stored chronicle in the SAME settings dictionary are both updated, so
## the grave survives scene changes, saves, and world regeneration.
## Callers persist the settings.
static func record_player_death(settings: Dictionary, player_name: String, place_name: String, death_year: int, cause: String) -> void:
	var who := player_name.strip_edges()
	if who.is_empty():
		who = "A wanderer"
	var place := place_name.strip_edges()
	if place.is_empty():
		place = "the wilds"
	var deaths := player_deaths(settings).duplicate()
	deaths.append({
		"year": maxi(1, death_year),
		"name": who,
		"place": place,
		"cause": cause.strip_edges()
	})
	settings[DEATHS_KEY] = deaths
	apply_player_deaths(chronicle_from_settings(settings), deaths)

## The still-living beast laired at this overworld tile, or {} when the
## tile hosts no lair (or its beast is already dead).
static func lair_beast_for_tile(settings: Dictionary, tile: Vector2i) -> Dictionary:
	var chronicle := chronicle_from_settings(settings)
	if chronicle.is_empty():
		return {}
	for beast_variant: Variant in (chronicle.get("beasts", []) as Array):
		var beast := beast_variant as Dictionary
		if String(beast.get("status", "alive")) != "alive":
			continue
		var lair_site: Variant = beast.get("lair_site", {})
		if not (lair_site is Dictionary) or (lair_site as Dictionary).is_empty():
			continue
		var site := lair_site as Dictionary
		if int(site.get("x", 2147483647)) != tile.x or int(site.get("y", 2147483647)) != tile.y:
			continue
		if is_beast_slain(settings, String(beast.get("name", ""))):
			continue
		return beast.duplicate(true)
	return {}

## "Skarthrax's Fang" — the beast's unique trophy item name.
static func beast_trophy_name(beast: Dictionary) -> String:
	var suffix := String(BEAST_TROPHY_SUFFIXES.get(String(beast.get("kind", "dragon")), "Fang"))
	return "%s's %s" % [String(beast.get("name", "Beast")), suffix]

## Chronicle-born faction goals ("to see the green dragon Vorgash slain").
static func history_agenda_goals(settings: Dictionary, settlement_name: String) -> Array[String]:
	var chronicle := chronicle_from_settings(settings)
	var entry := settlement_entry_by_name(chronicle, settlement_name)
	var goals: Array[String] = []
	for goal_variant: Variant in (entry.get("agenda_goals", []) as Array):
		var goal := String(goal_variant)
		if not goal.is_empty():
			goals.append(goal)
	return goals

## BBCode rows for one settlement's chronicle, oldest first.
static func settlement_events_bbcode(events: Array, current_year: int) -> String:
	var rows: Array[String] = []
	for event_variant: Variant in events:
		if not (event_variant is Dictionary):
			continue
		var event := event_variant as Dictionary
		var text := String(event.get("text", "")).strip_edges()
		if text.is_empty():
			continue
		var event_year := int(event.get("year", 0))
		var years_ago := maxi(0, current_year - event_year)
		var ago_label := "this year" if years_ago == 0 else ("%d year%s ago" % [years_ago, "" if years_ago == 1 else "s"])
		rows.append("• [color=#d4a64a][b]Year %d[/b], %s[/color] ([i]%s[/i]) — %s" % [event_year, GameCalendar.year_title(event_year), ago_label, text])
	return "\n".join(rows)

## BBCode for the World Chronicle dialog: the loudest events of the age.
static func overview_bbcode(chronicle: Dictionary) -> String:
	var current_year := int(chronicle.get("year", 0))
	var rows: Array[String] = []
	rows.append("[b]The World Chronicle[/b] — years 1 to %d" % current_year)
	rows.append("")
	var world_events := chronicle.get("world_events", []) as Array
	if world_events.is_empty():
		rows.append("[i]The age has been quiet; the chroniclers recorded little.[/i]")
	for event_variant: Variant in world_events:
		var event := event_variant as Dictionary
		var overview_year := int(event.get("year", 0))
		rows.append("[color=#d4a64a][b]Year %d[/b], %s[/color] — %s" % [overview_year, GameCalendar.year_title(overview_year), String(event.get("text", ""))])
	var beasts := chronicle.get("beasts", []) as Array
	var beast_rows: Array[String] = []
	for beast_variant: Variant in beasts:
		var beast := beast_variant as Dictionary
		var status := String(beast.get("status", "alive"))
		var status_text := "still at large"
		if status == "slain":
			status_text = "slain by %s, year %d" % [String(beast.get("slain_by", "a hero")), int(beast.get("slain_year", 0))]
		elif String(beast.get("lair_kind", "")) == "hold" or not String(beast.get("lair", "")).is_empty():
			status_text = "nests in the ruins of %s" % String(beast.get("lair_name", beast.get("lair", "")))
		elif not String(beast.get("lair_name", "")).is_empty():
			status_text = "lairs at %s" % String(beast.get("lair_name", ""))
		beast_rows.append("• %s — [i]%s[/i]" % [_capitalize_first(String(beast.get("display", "a beast"))), status_text])
	if not beast_rows.is_empty():
		rows.append("")
		rows.append("[b]Named beasts of the age[/b]")
		rows.append_array(beast_rows)
	return "\n".join(rows)
