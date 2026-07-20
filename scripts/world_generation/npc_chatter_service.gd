extends RefCounted
class_name NpcChatterService

## Dwarf-Fortress-style ambient chatter: short lines residents speak in
## captions over their heads as they live their scheduled lives. Lines
## key off what the resident is DOING (the scheduler's activity), what
## is happening around them (raids, weather, the deep), and how they
## FEEL (the live thought log's mood). Everything here returns short
## caption text - the click dialogue keeps its longer paragraphs.

const RAID_GUARD_LINES: Array[String] = [
	"To the walls!", "Steel out! Raiders!", "Hold the line!",
	"They'll not have our stores!", "Form up! Form up!"
]
const RAID_VILLAGER_LINES: Array[String] = [
	"Raiders! Run!", "Bar the doors!", "Where's the guard?!",
	"Not the harvest!", "Hide the children!"
]
const COMBAT_GUARD_LINES: Array[String] = [
	"Back to the dark with you!", "For the hold!",
	"You'll mar no dwarf today!", "Taste dwarven steel!"
]
const WEATHER_LINES := {
	"rain": ["This rain soaks to the bone.", "Wet as a fish out here.",
		"The sky's been weeping all day."],
	"storm": ["That sky means murder.", "In before the lightning!",
		"The gods are hammering something up there."],
	"snow": ["Cold as a tomb out here.", "My beard's gone to frost.",
		"Snow again. Of course."]
}
const JOYFUL_LINES: Array[String] = [
	"A fine day, truly.", "Life sits well with me.", "Couldn't ask for better."
]
const MISERABLE_LINES: Array[String] = [
	"This place grinds me down.", "Ill days. Ill days.",
	"Don't ask. Just don't."
]
const OFF_TO_LINES: Array[String] = [
	"Off to %s, then.", "No dawdling - %s waits.", "Just heading to %s."
]
const SOCIAL_LINES: Array[String] = [
	"%s! Well met!", "Have you heard, %s?", "And how's the family, %s?",
	"There you are, %s!"
]
const SOCIAL_REPLY_LINES: Array[String] = [
	"Ha! Good to see you, %s.", "Aye, %s, so they say.",
	"Same as ever, %s.", "You and your gossip, %s."
]
## Work banter keyed by words in the scheduler's work-station label.
const WORK_LINES := {
	"forge": ["Sparks and song!", "This one'll hold an edge.", "Coal! More coal!"],
	"smelter": ["Feed her hot and slow.", "Good ore, this batch."],
	"taproom": ["Mind the good barrel.", "Drink up or clear a stool."],
	"bread": ["Hot loaves, mind your fingers.", "The oven waits for nobody."],
	"cooking": ["Stew wants stirring.", "Taste that? Perfect."],
	"altar": ["The candles want trimming.", "Peace, friend. Or quiet, at least."],
	"records": ["Ink, ink, and more ink.", "These ledgers won't copy themselves."],
	"books": ["Shhh. The stacks are listening.", "A place for every scroll."],
	"stall": ["Fresh in this morning!", "Two for a copper, friend."],
	"counter": ["Mind the shelves.", "We open at bell, not before."],
	"coin": ["Count it twice. Always twice.", "The vault keeps its own hours."],
	"gems": ["Steady hands, steady light.", "This facet fights me."],
	"runes": ["The stone remembers every stroke.", "Quiet - graving."],
	"hides": ["This hide's a stubborn one.", "Smell? What smell?"]
}
const GENERIC_WORK_LINES: Array[String] = [
	"Back to it, then.", "The work won't do itself.", "Nearly shift's end. Nearly."
]
const NEED_LINES := {
	"drink": ["Ale! The good dark stuff.", "First one's for the ancestors.",
		"A mug, and none of your froth."],
	"worship": ["Stone keep us.", "A quiet word, then back to it."],
	"market": ["Fair prices, my eye.", "Just looking, mind.",
		"What's fresh today, then?"],
	"recreation": ["A moment's peace at last.", "Feet up, world out."]
}
const STROLL_LINES: Array[String] = [
	"Fine evening for a wander.", "The streets talk, if you listen.",
	"Just stretching the legs."
]
const UNDERGROUND_LINES: Array[String] = [
	"The stone hums today.", "Good honest dark, this.",
	"The deep provides.", "Hear that? The mountain settling."
]
## A hall whose laired terror the walker slew remembers its deliverer.
const DELIVERANCE_LINES: Array[String] = [
	"The beast is dead — drink to the walker!", "Sleep comes easy without the roars.",
	"The deep is ours again.", "New kin arrive every day now.",
	"The gates stand open once more.", "They'll sing of that kill for a century."
]
## Deeds travel: surface folk trade tavern gossip about the walker's
## freshest kill, %s standing in for the beast's storied name.
const RUMOR_LINES: Array[String] = [
	"They say a walker felled %s.", "Heard the news? %s is slain.",
	"Drinks were raised when word came: %s is dead.",
	"No more watching the road for %s.",
	"Somebody finally did for %s. Imagine that.",
	"A pedlar swore it true: %s is no more."
]
const GENERIC_IDLE_LINES: Array[String] = [
	"Hm? Just thinking.", "Stone and steel, another day.", "So it goes."
]

## --- Mood -------------------------------------------------------------------
## The live thought log (state.live_thoughts: [{text, valence, day}])
## sums into a mood; bands read like the fortress mood ladder.

static func mood_value(state: Dictionary) -> int:
	var total := 0
	for thought_variant: Variant in (state.get("live_thoughts", []) as Array):
		total += int((thought_variant as Dictionary).get("valence", 0))
	return clampi(total, -9, 9)

static func mood_band(value: int) -> String:
	if value >= 5:
		return "joyful"
	if value >= 1:
		return "content"
	if value >= -1:
		return "steady"
	if value >= -4:
		return "glum"
	return "miserable"

## "Urist has been content lately." for the dossier's Thoughts tab.
static func mood_sentence(identity: Dictionary, value: int) -> String:
	var first := String(identity.get("first_name", ""))
	if first.is_empty():
		first = String(identity.get("name", "They")).get_slice(" ", 0)
	return "%s has been %s lately." % [first, mood_band(value)]

## --- Lines ------------------------------------------------------------------

static func _pick(lines: Array, rng: RandomNumberGenerator) -> String:
	if lines.is_empty():
		return ""
	return String(lines[rng.randi_range(0, lines.size() - 1)])

static func _pick_format(lines: Array, value: String, rng: RandomNumberGenerator) -> String:
	var line := _pick(lines, rng)
	return line % value if line.contains("%s") else line

## The one ambient line for this speaker right now. Priority runs from
## the loudest circumstance down to idle small talk: raids and combat
## shout over everything, foul weather grumbles, then the current
## activity speaks, then the deep, then the person themselves.
static func ambient_line(state: Dictionary, identity: Dictionary, context: Dictionary, rng: RandomNumberGenerator) -> String:
	if bool(context.get("raid", false)):
		return _pick(RAID_GUARD_LINES if bool(context.get("guard", false)) else RAID_VILLAGER_LINES, rng)
	if bool(context.get("combat", false)):
		return _pick(COMBAT_GUARD_LINES, rng)
	var weather := String(context.get("weather", "clear"))
	if not bool(context.get("underground", false)) and WEATHER_LINES.has(weather) and rng.randf() < 0.45:
		return _pick(WEATHER_LINES[weather] as Array, rng)
	if bool(context.get("delivered", false)) and rng.randf() < 0.3:
		return _pick(DELIVERANCE_LINES, rng)
	# Above ground the same deed is hearsay, not homecoming: the news
	# arrives by road and gets retold over mugs.
	var rumor := String(context.get("rumor", ""))
	if not rumor.is_empty() and not bool(context.get("underground", false)) and rng.randf() < 0.25:
		return _pick_format(RUMOR_LINES, rumor, rng)
	var mood := mood_value(state)
	if (mood >= 5 or mood <= -4) and rng.randf() < 0.35:
		return _pick(JOYFUL_LINES if mood > 0 else MISERABLE_LINES, rng)
	var activity := state.get("activity", {}) as Dictionary
	if not activity.is_empty():
		var kind := String(activity.get("kind", ""))
		if not bool(activity.get("engaged", false)):
			var goal := String(activity.get("goal", ""))
			if not goal.is_empty() and rng.randf() < 0.6:
				return _pick_format(OFF_TO_LINES, goal, rng)
		elif kind == "social":
			return _pick_format(SOCIAL_LINES, String(activity.get("partner", "friend")).get_slice(" ", 0), rng)
		elif kind == "station":
			return work_line(String(activity.get("label", "")), rng)
		elif kind == "venue" and NEED_LINES.has(String(activity.get("need", ""))):
			return _pick(NEED_LINES[String(activity.get("need", ""))] as Array, rng)
		elif kind == "stroll":
			return _pick(STROLL_LINES, rng)
	if bool(context.get("underground", false)) and rng.randf() < 0.45:
		var stratum := String(context.get("stratum", ""))
		if not stratum.is_empty() and rng.randf() < 0.35:
			return "%s. Fine digging, this." % stratum
		return _pick(UNDERGROUND_LINES, rng)
	return personal_line_short(identity, rng)

## Banter matched to the work-station label's trade words.
static func work_line(label: String, rng: RandomNumberGenerator) -> String:
	for keyword_variant: Variant in WORK_LINES.keys():
		if label.contains(String(keyword_variant)):
			return _pick(WORK_LINES[keyword_variant] as Array, rng)
	return _pick(GENERIC_WORK_LINES, rng)

## The answer half of a social call, addressed back to the caller.
static func social_reply(speaker_first_name: String, rng: RandomNumberGenerator) -> String:
	return _pick_format(SOCIAL_REPLY_LINES, speaker_first_name, rng)

## Idle small talk drawn from who this person IS: their favorite thing,
## their dream, their kin, their gods - the identity speaking for itself.
static func personal_line_short(identity: Dictionary, rng: RandomNumberGenerator) -> String:
	match rng.randi_range(0, 5):
		0:
			return "Could just murder some %s." % String(identity.get("favorite", "stew"))
		1:
			return "Someday, %s." % String(identity.get("dream", "a quiet life"))
		2:
			var spouse := String(identity.get("spouse", ""))
			if not spouse.is_empty():
				return "Wonder what %s is at." % spouse.get_slice(" ", 0)
			return _pick(GENERIC_IDLE_LINES, rng)
		3:
			var faith := String(identity.get("faith", ""))
			if not faith.is_empty():
				return "%s keep us." % (faith.substr(0, 1).to_upper() + faith.substr(1))
			return _pick(GENERIC_IDLE_LINES, rng)
		4:
			return "They call me %s. They're not wrong." % String(identity.get("temperament", "steady"))
		_:
			return _pick(GENERIC_IDLE_LINES, rng)
