extends RefCounted
class_name WorldEventsService

## History keeps happening after worldgen: factions declare wars and sign
## peaces, raiders sack far-off settlements, caravans arrive or vanish on
## the road. Every event derives purely from (world seed, absolute day),
## so any scene replaying the same days recovers the same history; the
## shared world settings carry a rolling log that tavern rumors and the
## status ticker read from.

const SETTINGS_KEY := "world_events"
const ROSTER_KEY := "world_roster"
## The log is flavor, not a chronicle - keep only the recent past.
const LOG_CAP := 48
## Rumors older than this read as stale news nobody bothers repeating.
const RUMOR_FRESH_DAYS := 20

## Relative likelihood of each event kind when a day rolls an event.
const EVENT_WEIGHTS := {
	"faction_war_declared": 5,
	"faction_peace": 4,
	"settlement_raided": 13,
	"settlement_growth": 12,
	"settlement_decline": 9,
	"caravan_lost": 9,
	"caravan_arrived": 12,
	"beast_sighting": 13,
	"festival": 11
}

const RAIDER_CULTURES: Array[String] = ["goblin", "orc", "gnoll", "bandit"]
const BEAST_KINDS: Array[String] = ["dragon", "giant", "troll"]

## Fallback pools keep the service talking even before the overworld has
## stored a roster (fresh saves, scenes launched directly).
const FALLBACK_SETTLEMENTS := [
	{"name": "Stonewatch", "type": "town"},
	{"name": "Emberdeep", "type": "dwarfhold"},
	{"name": "Willowmere", "type": "village"},
	{"name": "Saltharbor", "type": "town"},
	{"name": "Thornfield", "type": "village"},
	{"name": "Karag Dun", "type": "dwarfhold"}
]
const FALLBACK_FACTIONS: Array[String] = [
	"Humans", "Dwarves", "Wood Elves", "Lizardmen", "Desert Folk"
]

const WAR_TEMPLATES: Array[String] = [
	"The %s have declared war on the %s — heralds cry it at every gate.",
	"The old truce is broken: the %s march against the %s.",
	"Riders bring word of open war between the %s and the %s."
]
const PEACE_TEMPLATES: Array[String] = [
	"The %s and the %s have signed a peace — the trade roads breathe easier.",
	"Envoys of the %s broke bread with the %s; the war is over, for now.",
	"Peace at last between the %s and the %s, though few trust the ink."
]
const RAID_TEMPLATES: Array[String] = [
	"%s raiders struck %s in the night — smoke was seen for miles.",
	"%s warbands hit %s; the survivors flee along the roads.",
	# No leading article: "A Orc host" needs a/an chosen per culture.
	"%s war-parties tested the gates of %s and were bloodied for it."
]
const GROWTH_TEMPLATES: Array[String] = [
	"%s is thriving — the census counts its folk up near %d%% this season.",
	"Settlers pour into %s; new roofs rise past the old walls, %d%% more hearths burning.",
	"Good harvests fatten %s — its people grown by some %d%% on the year."
]
const DECLINE_TEMPLATES: Array[String] = [
	"%s dwindles — near %d%% of its folk have packed up and moved on.",
	"Hard times in %s: %d%% fewer hearths burn there this season.",
	"Sickness and short rations have thinned %s by a good %d%%."
]
const CARAVAN_LOST_TEMPLATES: Array[String] = [
	"A caravan out of %s never reached %s — the road watch found only wheel ruts.",
	"The caravan from %s to %s is a fortnight overdue; the merchants fear the worst.",
	"Wolves or worse took a caravan on the road between %s and %s."
]
const CARAVAN_ARRIVED_TEMPLATES: Array[String] = [
	"A rich caravan from %s rolled into %s — the markets buzz with new wares.",
	"The road from %s to %s runs safe: another caravan came through laden.",
	"Traders out of %s reached %s with salt, silks, and stranger stories."
]
const BEAST_TEMPLATES: Array[String] = [
	"A %s was seen circling the hills near %s.",
	"Herders outside %s swear a %s took three head of cattle in one night.",
	"Hunters out of %s tracked a %s to its lair and wisely turned back."
]
const FESTIVAL_TEMPLATES: Array[String] = [
	"%s holds its harvest feast — ale flows and the gates stand open to all.",
	"Lantern festival in %s: three nights of music ring from the walls.",
	"%s crowns a harvest queen and roasts an ox in the square."
]

const RUMOR_TEMPLATES: Array[String] = [
	"Word from the road, %s: %s",
	"A trader told me, %s — %s",
	"Heard it %s from a caravan guard: %s",
	"News reached us %s: %s"
]

## Spelled-out small counts so rumors read like speech, not a ledger.
const NUMBER_WORDS: Array[String] = [
	"no", "one", "two", "three", "four", "five", "six", "seven",
	"eight", "nine", "ten", "eleven", "twelve"
]

## Rolls the days in (last_day, absolute_day], appends what happened to
## the stored log, and returns only the freshly generated events.
static func advance(settings: Dictionary, world_seed_text: String, absolute_day: int) -> Array[Dictionary]:
	var events_state: Dictionary = settings.get(SETTINGS_KEY, {}) if settings.get(SETTINGS_KEY, {}) is Dictionary else {}
	var last_day := int(events_state.get("last_day", 0))
	var event_log: Array = events_state.get("log", []) if events_state.get("log", []) is Array else []
	var new_events: Array[Dictionary] = []
	if absolute_day <= last_day:
		return new_events
	var settlements := _settlement_pool(settings)
	var factions := _faction_pool(settings)
	for day: int in range(last_day + 1, absolute_day + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s|worldevents|%d" % [world_seed_text, day])
		for _slot: int in range(_roll_event_count(rng)):
			new_events.append(_roll_event(day, rng, settlements, factions))
	for event: Dictionary in new_events:
		event_log.append(event)
	while event_log.size() > LOG_CAP:
		event_log.pop_front()
	settings[SETTINGS_KEY] = {"last_day": absolute_day, "log": event_log}
	return new_events

## The newest max_count events, oldest first.
static func recent_events(settings: Dictionary, max_count: int) -> Array[Dictionary]:
	var events_state: Dictionary = settings.get(SETTINGS_KEY, {}) if settings.get(SETTINGS_KEY, {}) is Dictionary else {}
	var event_log: Array = events_state.get("log", []) if events_state.get("log", []) is Array else []
	var picked: Array[Dictionary] = []
	for entry_index: int in range(maxi(0, event_log.size() - maxi(0, max_count)), event_log.size()):
		if event_log[entry_index] is Dictionary:
			picked.append(event_log[entry_index] as Dictionary)
	return picked

## Wraps a fresh-enough event in a spoken template ("Word from the road,
## three days back: ..."). Empty when nothing recent is worth repeating.
static func rumor_from_events(settings: Dictionary, absolute_day: int, rng: RandomNumberGenerator) -> String:
	var fresh: Array[Dictionary] = []
	for event: Dictionary in recent_events(settings, LOG_CAP):
		var age_days := absolute_day - int(event.get("day", 0))
		if age_days >= 0 and age_days <= RUMOR_FRESH_DAYS:
			fresh.append(event)
	if fresh.is_empty():
		return ""
	var chosen := fresh[rng.randi_range(0, fresh.size() - 1)]
	var ago_text := _days_ago_text(absolute_day - int(chosen.get("day", 0)))
	var event_text := String(chosen.get("text", ""))
	return RUMOR_TEMPLATES[rng.randi_range(0, RUMOR_TEMPLATES.size() - 1)] % [ago_text, event_text]

static func _days_ago_text(age_days: int) -> String:
	if age_days <= 0:
		return "just this morning"
	if age_days == 1:
		return "yesterday"
	if age_days < NUMBER_WORDS.size():
		return "%s days back" % NUMBER_WORDS[age_days]
	return "a couple of weeks back"

## 0-2 events a day: most days something small happens somewhere.
static func _roll_event_count(rng: RandomNumberGenerator) -> int:
	var roll := rng.randf()
	if roll < 0.35:
		return 0
	if roll < 0.8:
		return 1
	return 2

static func _weighted_kind(rng: RandomNumberGenerator) -> String:
	var total_weight := 0
	for kind_name: String in EVENT_WEIGHTS.keys():
		total_weight += int(EVENT_WEIGHTS[kind_name])
	var pick := rng.randi_range(1, total_weight)
	for kind_name: String in EVENT_WEIGHTS.keys():
		pick -= int(EVENT_WEIGHTS[kind_name])
		if pick <= 0:
			return kind_name
	return "festival"

static func _settlement_pool(settings: Dictionary) -> Array[Dictionary]:
	var roster: Dictionary = settings.get(ROSTER_KEY, {}) if settings.get(ROSTER_KEY, {}) is Dictionary else {}
	var raw_settlements: Array = roster.get("settlements", []) if roster.get("settlements", []) is Array else []
	var pool: Array[Dictionary] = []
	for entry_variant: Variant in raw_settlements:
		if entry_variant is Dictionary and not String((entry_variant as Dictionary).get("name", "")).is_empty():
			pool.append(entry_variant as Dictionary)
	# Caravans and raids need at least two named places to talk about.
	if pool.size() < 2:
		pool = []
		for fallback_variant: Variant in FALLBACK_SETTLEMENTS:
			pool.append(fallback_variant as Dictionary)
	return pool

static func _faction_pool(settings: Dictionary) -> Array[String]:
	var roster: Dictionary = settings.get(ROSTER_KEY, {}) if settings.get(ROSTER_KEY, {}) is Dictionary else {}
	var raw_factions: Array = roster.get("factions", []) if roster.get("factions", []) is Array else []
	var pool: Array[String] = []
	for entry_variant: Variant in raw_factions:
		var faction_name := String(entry_variant)
		if not faction_name.is_empty() and not pool.has(faction_name):
			pool.append(faction_name)
	# Wars take two sides; fall back to the great cultures if the roster
	# only knows one (or none).
	if pool.size() < 2:
		pool = FALLBACK_FACTIONS.duplicate()
	return pool

static func _pick_settlement_name(rng: RandomNumberGenerator, settlements: Array[Dictionary]) -> String:
	return String(settlements[rng.randi_range(0, settlements.size() - 1)].get("name", "a far settlement"))

static func _pick_template(rng: RandomNumberGenerator, templates: Array[String]) -> String:
	return templates[rng.randi_range(0, templates.size() - 1)]

static func _roll_event(day: int, rng: RandomNumberGenerator, settlements: Array[Dictionary], factions: Array[String]) -> Dictionary:
	var kind := _weighted_kind(rng)
	var event := {"day": day, "kind": kind}
	match kind:
		"faction_war_declared", "faction_peace":
			var first_index := rng.randi_range(0, factions.size() - 1)
			var second_index := (first_index + rng.randi_range(1, factions.size() - 1)) % factions.size()
			var templates := WAR_TEMPLATES if kind == "faction_war_declared" else PEACE_TEMPLATES
			event["text"] = _pick_template(rng, templates) % [factions[first_index], factions[second_index]]
		"settlement_raided":
			var settlement_name := _pick_settlement_name(rng, settlements)
			var culture := RAIDER_CULTURES[rng.randi_range(0, RAIDER_CULTURES.size() - 1)]
			event["settlement"] = settlement_name
			event["text"] = _pick_template(rng, RAID_TEMPLATES) % [culture.capitalize(), settlement_name]
		"settlement_growth", "settlement_decline":
			var settlement_name := _pick_settlement_name(rng, settlements)
			var percent := rng.randi_range(3, 12)
			var templates := GROWTH_TEMPLATES if kind == "settlement_growth" else DECLINE_TEMPLATES
			event["settlement"] = settlement_name
			event["text"] = _pick_template(rng, templates) % [settlement_name, percent]
		"caravan_lost", "caravan_arrived":
			var first_index := rng.randi_range(0, settlements.size() - 1)
			var second_index := (first_index + rng.randi_range(1, settlements.size() - 1)) % settlements.size()
			var origin_name := String(settlements[first_index].get("name", "a far settlement"))
			var destination_name := String(settlements[second_index].get("name", "another settlement"))
			var templates := CARAVAN_LOST_TEMPLATES if kind == "caravan_lost" else CARAVAN_ARRIVED_TEMPLATES
			event["settlement"] = destination_name
			event["text"] = _pick_template(rng, templates) % [origin_name, destination_name]
		"beast_sighting":
			var settlement_name := _pick_settlement_name(rng, settlements)
			var beast := BEAST_KINDS[rng.randi_range(0, BEAST_KINDS.size() - 1)]
			event["settlement"] = settlement_name
			# Template argument order differs per line; keep them explicit.
			match rng.randi_range(0, BEAST_TEMPLATES.size() - 1):
				0:
					event["text"] = BEAST_TEMPLATES[0] % [beast, settlement_name]
				1:
					event["text"] = BEAST_TEMPLATES[1] % [settlement_name, beast]
				_:
					event["text"] = BEAST_TEMPLATES[2] % [settlement_name, beast]
		_:
			var settlement_name := _pick_settlement_name(rng, settlements)
			event["settlement"] = settlement_name
			event["text"] = _pick_template(rng, FESTIVAL_TEMPLATES) % settlement_name
	return event
