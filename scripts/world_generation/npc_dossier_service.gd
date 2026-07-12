extends RefCounted
class_name NpcDossierService

## The Dwarf Fortress side of a citizen: attributes, skills, health,
## personality facets, unmet needs, position and a recent-thoughts log,
## all derived DETERMINISTICALLY from the NPC's identity and the world
## seed (no storage - the same dwarf reads the same on every inspection),
## with live scene state (current activity) folded in where it exists.
## The inspection card renders these sections as DF-style tabs.

## DF's skill rank ladder, low to high.
const SKILL_RANKS: Array[String] = [
	"Dabbling", "Novice", "Adequate", "Competent", "Skilled", "Proficient",
	"Talented", "Adept", "Expert", "Accomplished", "Master", "High Master",
	"Grand Master", "Legendary"
]

const GOOD_ATTRIBUTES: Array[String] = [
	"Good focus", "High social awareness", "Agile", "Very strong",
	"Iron-willed", "Quick to heal", "Keen intuition", "Tireless",
	"Great memory", "Sturdy", "Sharp-eyed", "Steady hands"
]
const BAD_ATTRIBUTES: Array[String] = [
	"Recovers slowly", "Easily distracted", "Clumsy", "Weak constitution",
	"Poor memory", "Quick to tire", "Thin-skinned", "Hard of hearing"
]
const QUIRK_ATTRIBUTES: Array[String] = [
	"Flatterer", "Fearless", "Modest", "Boastful", "Slow to trust",
	"Hums while working", "Superstitious", "Talks to themselves",
	"Never forgets a slight", "Collects small stones"
]

const SECONDARY_SKILLS: Array[String] = [
	"Butcher", "Tanner", "Brewer", "Miller", "Thresher", "Cook", "Fisher",
	"Herbalist", "Carpenter", "Mason", "Weaver", "Potter", "Swimmer",
	"Storyteller", "Haggler", "Animal Caretaker", "Gem Cutter", "Sitter"
]

const MILITARY_SKILLS: Array[String] = [
	"Armor User", "Observer", "Dodger", "Discipline", "Fighter",
	"Shield User", "Wrestler", "Striker"
]

const HEALTH_CONDITIONS: Array[String] = [
	"An old leg wound aches in the rain",
	"Missing a finger on the off hand",
	"A scarred brow from a tavern brawl",
	"Weak lungs from years of rock dust",
	"A crooked nose, badly set",
	"Winter chills settle in the joints",
	"An ear that rings after a mine blast",
	"A stiff shoulder from old labor"
]

const PERSONALITY_FACETS: Array[String] = [
	"%P% is quick to anger, and quicker to forget it.",
	"%P% is slow to trust strangers.",
	"%P% takes deep pride in honest work.",
	"%P% cannot abide idleness in others.",
	"%P% is prone to bouts of melancholy.",
	"%P% laughs easily and often.",
	"%P% keeps every promise, however small.",
	"%P% is uncomfortable in crowds.",
	"%P% loves a good argument for its own sake.",
	"%P% needs little in the way of comfort.",
	"%P% is unnerved by open water.",
	"%P% remembers every meal worth remembering.",
	"%P% holds craft above coin.",
	"%P% would rather listen than speak."
]

const VALUE_FACETS: Array[String] = [
	"%P% values honesty above all things.",
	"%P% values loyalty to kin before any law.",
	"%P% values hard work and little else.",
	"%P% values tradition, and distrusts the new.",
	"%P% values cunning over strength.",
	"%P% values a full larder and a quiet evening.",
	"%P% values courage, even reckless courage.",
	"%P% values knowledge hoarded like treasure."
]

const NEEDS_POOL: Array[String] = [
	"Acquire object", "Eat a good meal", "Be with family", "Drink alcohol",
	"Pray", "See great beasts", "Craft something", "Wander",
	"Hear eloquent speech", "Take it easy", "Be with friends", "Make merry"
]

const QUOTES: Array[String] = [
	"I guess I just don't appreciate art.",
	"The stone remembers, even when no one else does.",
	"A dull pick digs twice as long.",
	"Never trust a door you didn't hang yourself.",
	"There's no problem a good meal can't shrink.",
	"Rain is just the sky's opinion.",
	"Coin spends. Craft stays.",
	"I've buried better arguments than that.",
	"Every tunnel goes somewhere. That's the trouble.",
	"You can't rush a mushroom.",
	"My grandmother swung a heavier hammer than you.",
	"Sleep is a debt the morning always collects.",
	"A full mug settles most philosophy.",
	"The mountain was here first. Act like a guest."
]

## Thought templates: [verb phrase, feeling word, rest, tone]. Tones:
## "good", "great", "bad", "curious" - the card colors the feeling word.
const THOUGHT_TEMPLATES: Array = [
	["felt", "satisfied", "at work.", "good"],
	["felt", "satisfied", "at work.", "good"],
	["felt", "satisfied", "upon improving %SKILL%.", "good"],
	["was", "annoyed", "at the lack of chairs.", "bad"],
	["felt", "euphoric", "due to inebriation.", "great"],
	["was", "grouchy", "when caught in the rain.", "bad"],
	["was", "grouchy", "dwelling upon being caught in the rain.", "bad"],
	["felt", "fondness", "talking with an acquaintance.", "good"],
	["was", "interested", "near a fine Trade Depot.", "curious"],
	["took", "joy", "in a fine meal.", "good"],
	["felt", "lonely", "after being away from people.", "bad"],
	["was", "irritated", "by a bothersome fly.", "bad"],
	["felt", "content", "after a fine drink.", "good"],
	["was", "uneasy", "after a strange dream.", "bad"],
	["felt", "pride", "showing a young one the trade.", "good"],
	["was", "wistful", "remembering %FAVORITE%.", "curious"],
	["felt", "restless", "cooped up indoors.", "bad"],
	["was", "delighted", "by a well-told story.", "great"]
]

static func _pick(pool: Array, rng: RandomNumberGenerator) -> String:
	return String(pool[rng.randi_range(0, pool.size() - 1)])

static func _take(pool: Array, rng: RandomNumberGenerator, count: int) -> Array[String]:
	var source := pool.duplicate()
	var taken: Array[String] = []
	for _step in range(count):
		if source.is_empty():
			break
		var index := rng.randi_range(0, source.size() - 1)
		taken.append(String(source[index]))
		source.remove_at(index)
	return taken

static func _pronoun(gender: String) -> String:
	if gender == "male":
		return "He"
	if gender == "female":
		return "She"
	return "They"

## "He was" / "They were" - the only verb whose agreement shifts.
static func _conjugate(pronoun: String, verb: String) -> String:
	if pronoun == "They" and verb == "was":
		return "were"
	return verb

## Builds the full dossier once; the card caches it on the npc_state so
## reopening reads identically. role_title steers position/squad; the
## live activity_label (when present) leads the thought log.
static func build(identity: Dictionary, role_title: String, seed_value: int, npc_state: Dictionary) -> Dictionary:
	var npc_name := String(identity.get("name", "A stranger"))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|dossier|%s" % [seed_value, npc_name])
	var gender := String(identity.get("gender", ""))
	var pronoun := _pronoun(gender)
	var age := int(identity.get("age", 100))
	var profession := String(identity.get("profession", role_title)).strip_edges()
	if profession.is_empty():
		profession = "Villager"

	# --- attributes: a few gifts, sometimes a flaw, always a quirk ---
	var attributes: Array[Dictionary] = []
	for text: String in _take(GOOD_ATTRIBUTES, rng, 2 + (1 if rng.randf() < 0.4 else 0)):
		attributes.append({"text": text, "tone": "good"})
	if rng.randf() < 0.65:
		for text: String in _take(BAD_ATTRIBUTES, rng, 1 + (1 if rng.randf() < 0.25 else 0)):
			attributes.append({"text": text, "tone": "bad"})
	for text: String in _take(QUIRK_ATTRIBUTES, rng, 1 + (1 if rng.randf() < 0.5 else 0)):
		attributes.append({"text": text, "tone": "plain"})

	# --- skills: the trade rank grows with age; side skills stay low ---
	var age_rank := clampi(3 + int(float(age) / 45.0) + rng.randi_range(0, 2), 3, 9)
	var skills: Array[Dictionary] = []
	skills.append({"name": profession, "rank": SKILL_RANKS[age_rank], "level": age_rank})
	var secondary_count := rng.randi_range(3, 6)
	for skill_name: String in _take(SECONDARY_SKILLS, rng, secondary_count):
		var level := rng.randi_range(0, 3)
		skills.append({"name": skill_name, "rank": SKILL_RANKS[level], "level": level})

	# --- position and squad ---
	var lowered_role := role_title.to_lower()
	var is_military := lowered_role.contains("guard") or lowered_role.contains("watch") \
		or lowered_role.contains("soldier") or lowered_role.contains("captain")
	var position_title := "No official position"
	if bool(npc_state.get("is_ruler", false)):
		position_title = role_title
	elif is_military:
		position_title = role_title
	var squad_name := "None"
	if is_military:
		squad_name = "The Stone Watch" if rng.randf() < 0.5 else "The Gate Wards"
	var military: Array[Dictionary] = []
	for skill_name: String in _take(MILITARY_SKILLS, rng, rng.randi_range(4, 5)):
		var floor_level := 2 if is_military else 0
		var level := clampi(rng.randi_range(floor_level, floor_level + 2), 0, 4)
		military.append({"name": skill_name, "rank": SKILL_RANKS[level], "level": level})

	# --- health ---
	var conditions: Array[String] = []
	if rng.randf() < 0.35 or age > 200:
		conditions = _take(HEALTH_CONDITIONS, rng, 1 + (1 if age > 250 and rng.randf() < 0.5 else 0))
	var health_status := "Healthy" if conditions.is_empty() else "Mostly sound"
	var rest_state := "Well rested"
	var doing := String(npc_state.get("activity_label", "")).to_lower()
	if doing.contains("sleep"):
		rest_state = "Sleeping"
	elif rng.randf() < 0.2:
		rest_state = "A little tired"

	# --- personality: facets + a value + their dream and faith ---
	var personality: Array[String] = []
	var temperament := String(identity.get("temperament", "")).strip_edges()
	if not temperament.is_empty():
		personality.append("%s is %s by nature." % [pronoun, temperament.to_lower()])
	for facet: String in _take(PERSONALITY_FACETS, rng, 3):
		personality.append(facet.replace("%P%", pronoun))
	personality.append(_pick(VALUE_FACETS, rng).replace("%P%", pronoun))
	var dream := String(identity.get("dream", "")).strip_edges().trim_suffix(".")
	if not dream.is_empty():
		# Identity dreams read "to be remembered in song": keep the
		# infinitive under "hopes", not the clumsy "dreams of to be".
		if dream.to_lower().begins_with("to "):
			personality.append("%s hopes %s." % [pronoun, dream.to_lower()])
		else:
			personality.append("%s dreams of %s." % [pronoun, dream.to_lower()])
	var faith := String(identity.get("faith", "")).strip_edges()
	if not faith.is_empty():
		personality.append("%s keeps the faith of %s." % [pronoun, faith])

	# --- unmet needs ---
	var needs := _take(NEEDS_POOL, rng, rng.randi_range(0, 3))

	# --- the thought log, most recent first ---
	var favorite := String(identity.get("favorite", "an old keepsake"))
	var skill_mention := String((skills[rng.randi_range(0, skills.size() - 1)] as Dictionary).get("name", profession)).to_lower()
	var thoughts: Array[Dictionary] = []
	if not doing.is_empty():
		thoughts.append({
			"lead": "%s is" % pronoun, "feeling": "busy",
			"rest": "%s right now." % doing, "tone": "curious"
		})
	var template_pool := THOUGHT_TEMPLATES.duplicate()
	var thought_count := rng.randi_range(7, 10)
	for _thought in range(thought_count):
		if template_pool.is_empty():
			break
		var index := rng.randi_range(0, template_pool.size() - 1)
		var template := template_pool[index] as Array
		template_pool.remove_at(index)
		var rest := String(template[2])
		rest = rest.replace("%SKILL%", skill_mention).replace("%FAVORITE%", favorite.to_lower())
		thoughts.append({
			"lead": "%s %s" % [pronoun, _conjugate(pronoun, String(template[0]))],
			"feeling": String(template[1]),
			"rest": rest,
			"tone": String(template[3])
		})

	return {
		"attributes": attributes,
		"thoughts": thoughts,
		"skills": skills,
		"military": military,
		"position": position_title,
		"squad": squad_name,
		"health_status": health_status,
		"health_conditions": conditions,
		"rest_state": rest_state,
		"personality": personality,
		"needs": needs,
		"quote": _pick(QUOTES, rng),
		"pronoun": pronoun
	}
