extends RefCounted
class_name NpcIdentityService

## Dwarf Fortress-style identities: every NPC in a settlement carries a
## name, clan, profession, age, temperament, a favorite thing, and a
## dream. Identities are rolled once at spawn from the scene's seeded
## rng, so the same hold always houses the same dwarves.

const DWARF_FIRST_NAMES: Array[String] = [
	"Urist", "Dolgrim", "Thorgar", "Brokk", "Kazrik", "Snorri", "Durin",
	"Balin", "Gimra", "Helga", "Sigrun", "Astrid", "Brunhild", "Katla",
	"Oddny", "Thyra", "Vigdis", "Bofur", "Nali", "Kili", "Dagny", "Ingrid",
	"Grimbold", "Hardek", "Morgrym", "Ovek", "Rurik", "Skadi", "Torvald", "Ulfhild"
]
const DWARF_CLAN_NAMES: Array[String] = [
	"Copperbeard", "Stonefist", "Ironhelm", "Goldvein", "Deepdelver",
	"Anvilborn", "Granitejaw", "Silverbraid", "Emberforge", "Rockseeker",
	"Steeltoe", "Marblebrow", "Gemcutter", "Coalbrand", "Hammerfall",
	"Orehand", "Mithrilheart", "Basaltback", "Flintbeard", "Bronzebelly"
]
## DWARF_FIRST_NAMES split by gender, so rulers, heirs and chronicle
## lineages can pair a gendered title with a matching name. The union
## list above stays for ungendered citizen rolls.
const DWARF_FIRST_NAMES_MALE: Array[String] = [
	"Urist", "Dolgrim", "Thorgar", "Brokk", "Kazrik", "Snorri", "Durin",
	"Balin", "Bofur", "Nali", "Kili", "Grimbold", "Hardek", "Morgrym",
	"Ovek", "Rurik", "Torvald"
]
const DWARF_FIRST_NAMES_FEMALE: Array[String] = [
	"Gimra", "Helga", "Sigrun", "Astrid", "Brunhild", "Katla", "Oddny",
	"Thyra", "Vigdis", "Dagny", "Ingrid", "Skadi", "Ulfhild"
]
## Throne-worthy first names for hold rulers and their succession lines.
const DWARF_RULER_FIRST_NAMES_MALE: Array[String] = [
	"Urist", "Thrain", "Borin", "Durin", "Gimli", "Khazad", "Rurik",
	"Dwalin", "Oin", "Fundin", "Balin", "Kili", "Thorin", "Nori"
]
const DWARF_RULER_FIRST_NAMES_FEMALE: Array[String] = [
	"Dis", "Sigrid", "Brynja", "Thora", "Eydis", "Runa", "Katla",
	"Astrid", "Helga", "Frida", "Vigdis", "Hreda"
]
## Dwarfhold ruler titles, gendered the way town_details_generator genders
## its mayors: a rolled ruler's gender picks the name pool AND the title
## set, so a Queen is never called Thorin. Titles that read the same on
## any ruler (Thane, High Thane, Shieldthane) sit in both gendered lists;
## the neutral set can crown either gender.
const DWARF_RULER_TITLES_MALE: Array[String] = [
	"King", "High King", "King-Under-The-Mountain", "Baron", "Manorlord",
	"Thane", "High Thane", "Forge-Lord", "Shieldthane"
]
const DWARF_RULER_TITLES_FEMALE: Array[String] = [
	"Queen", "Queen Regent", "High Queen", "Baroness",
	"Thane", "High Thane", "Shieldthane"
]
const DWARF_RULER_TITLES_NEUTRAL: Array[String] = [
	"Administrator", "Elder", "Clan Master", "Prophet",
	"Highmaster Hammerdwarf", "Deepwarden", "Runesmith", "Iron Regent"
]
## Dark holds keep their own style of throne; the dark titles read the
## same on any ruler, so the set is ungendered.
const DWARF_DARK_RULER_TITLES: Array[String] = [
	"Sorcerer-Prophet", "Ash Lord", "Obsidian Warden", "Flame Regent", "Deep Ember"
]
const DWARF_RULER_NEUTRAL_TITLE_CHANCE := 0.3
## Gendered pools for callers that pair names with gendered titles or
## family relations ("Lady Duncan Miller" must not happen); the combined
## pool is derived so the three lists can never drift apart.
const TOWNSFOLK_FIRST_NAMES_MALE: Array[String] = [
	"Aldric", "Bertram", "Cedric", "Duncan", "Edwin", "Gareth", "Harold",
	"Osric", "Percival", "Rowan", "Tobias", "Wallace", "Yorick", "Lambert", "Hugh"
]
const TOWNSFOLK_FIRST_NAMES_FEMALE: Array[String] = [
	"Agnes", "Beatrice", "Clara", "Edith", "Greta", "Isolde", "Maren",
	"Nell", "Rosalind", "Sybil", "Tilda", "Winifred", "Petra"
]
const TOWNSFOLK_FIRST_NAMES: Array[String] = TOWNSFOLK_FIRST_NAMES_MALE + TOWNSFOLK_FIRST_NAMES_FEMALE
const TOWNSFOLK_SURNAMES: Array[String] = [
	"Miller", "Thatcher", "Cooper", "Fletcher", "Baker", "Weaver", "Tanner",
	"Mason", "Carter", "Shepherd", "Brewer", "Smith", "Wright", "Potter",
	"Fowler", "Chandler", "Draper", "Sadler", "Glover", "Kemp"
]
const TEMPERAMENTS: Array[String] = [
	"quick to laugh", "slow to trust", "quick to anger", "endlessly patient",
	"fond of gossip", "quiet as stone", "proud to a fault", "kind to strangers",
	"suspicious of elves", "always humming", "stubborn as bedrock", "easily startled",
	"cheerful before breakfast", "gloomy after sundown", "generous with ale",
	"tight with coin", "brave past sense", "careful with words", "boastful", "wistful"
]
const DREAMS: Array[String] = [
	"to craft a masterwork", "to raise a family", "to see the surface world",
	"to master a craft", "to found a hold of their own", "to strike gold",
	"to be remembered in song", "to keep the family name proud",
	"to taste every ale ever brewed", "to slay a great beast",
	"to map the deep roads", "to retire rich and fat", "to learn every rumor worth knowing",
	"to build something that outlasts them", "to make peace with an old rival"
]
## Favorite things drawn from the item catalog so preferences are real goods.
const FAVORITE_ITEMS: Array[String] = [
	"Mushrooms", "Glowcap", "Hearty Stew", "Roast Meat", "Grilled Fish",
	"Cured Ham", "Smoked Ribs", "Gold Nugget", "Gem Shard", "Amber",
	"Silver Ingot", "Golden Koi", "King Bolete", "Blood Sausage",
	"Mushroom Skewer", "Copper Ingot", "Moss Agate", "Marbled Steak",
	"Porcini", "Jerky Strip"
]
## Who a citizen prays to. A slice of every settlement keeps no gods at
## all, and families tend to share an altar.
const DWARF_FAITHS: Array[String] = [
	"the Forge-Father", "the Deep Mother", "the Silent Stone",
	"the Ember Queen", "the Ancestors"
]
const TOWNSFOLK_FAITHS: Array[String] = [
	"the Harvest Mother", "the Lamplighter", "the River Saint",
	"the Twin Oaks", "the Pale Moon"
]
const FAITHLESS_CHANCE := 0.12

## Explicit race, weighted per settlement kind: holds are dwarven with
## goblin, gnome, kobold and human minorities; towns the reverse. Races
## bring their own names, lifespans, and looks.
const RACES_BY_KIND := {
	"dwarf": [["Dwarf", 86], ["Goblin", 5], ["Gnome", 4], ["Kobold", 3], ["Human", 2]],
	"townsfolk": [["Human", 83], ["Gnome", 6], ["Dwarf", 5], ["Goblin", 3], ["Kobold", 3]]
}
const RACE_AGE_RANGES := {
	"Dwarf": [22, 320], "Human": [16, 78], "Gnome": [30, 260],
	"Goblin": [12, 60], "Kobold": [10, 50]
}
const GOBLIN_FIRST_NAMES: Array[String] = [
	"Snik", "Grubbash", "Mizzle", "Rakka", "Fettle", "Yagra", "Skiv",
	"Nubbin", "Grix", "Tarnak", "Wexla", "Bogrin"
]
const GOBLIN_SURNAMES: Array[String] = [
	"Mudgrin", "Rustbite", "Sniplash", "Damptoe", "Cinderlick", "Gutterwise",
	"Shankfoot", "Molepaw"
]
const GNOME_FIRST_NAMES: Array[String] = [
	"Fizwick", "Nimble", "Tock", "Perriwig", "Glimmer", "Boddynock",
	"Ellywick", "Sprocket", "Quilla", "Wrenna", "Fenwick", "Dabbledob"
]
const GNOME_SURNAMES: Array[String] = [
	"Cogspinner", "Murmurwell", "Thistletorque", "Copperwhistle", "Fiddlefen",
	"Glowpocket", "Nackleknob", "Silverspring"
]
const KOBOLD_FIRST_NAMES: Array[String] = [
	"Yip", "Skarn", "Meepo", "Tikka", "Vex", "Drazzik", "Snarl", "Kekkit",
	"Izzik", "Pox", "Rikrik", "Zsofka"
]
const KOBOLD_SURNAMES: Array[String] = [
	"Emberclaw", "Tunnelborn", "Scaleflint", "Deepsnout", "Wyrmkin",
	"Ashscale", "Cavewhisper", "Gravelhiss"
]

## --- Dwarf ruler gendering ---------------------------------------------------
## One source of truth for the gender-consistent ruler rolls: overworld
## details, chronicle lineages and the hold's fallback ruler all pull
## from these pools, so a title always matches its bearer's name pool.

static func roll_dwarf_gender(rng: RandomNumberGenerator) -> String:
	return "female" if rng.randf() < 0.5 else "male"

static func dwarf_ruler_first_name(rng: RandomNumberGenerator, gender: String) -> String:
	var pool := DWARF_RULER_FIRST_NAMES_FEMALE if gender == "female" else DWARF_RULER_FIRST_NAMES_MALE
	return pool[rng.randi_range(0, pool.size() - 1)]

static func dwarf_ruler_title(rng: RandomNumberGenerator, gender: String, is_dark: bool) -> String:
	if is_dark:
		return DWARF_DARK_RULER_TITLES[rng.randi_range(0, DWARF_DARK_RULER_TITLES.size() - 1)]
	if rng.randf() < DWARF_RULER_NEUTRAL_TITLE_CHANCE:
		return DWARF_RULER_TITLES_NEUTRAL[rng.randi_range(0, DWARF_RULER_TITLES_NEUTRAL.size() - 1)]
	var pool := DWARF_RULER_TITLES_FEMALE if gender == "female" else DWARF_RULER_TITLES_MALE
	return pool[rng.randi_range(0, pool.size() - 1)]

## Gender of a dwarf first name by pool membership ("" when unknown).
static func dwarf_name_gender(first_name: String) -> String:
	if DWARF_FIRST_NAMES_FEMALE.has(first_name) or DWARF_RULER_FIRST_NAMES_FEMALE.has(first_name):
		return "female"
	if DWARF_FIRST_NAMES_MALE.has(first_name) or DWARF_RULER_FIRST_NAMES_MALE.has(first_name):
		return "male"
	return ""

static func roll_race(rng: RandomNumberGenerator, kind: String) -> String:
	var pool := RACES_BY_KIND.get(kind, RACES_BY_KIND["townsfolk"]) as Array
	var total := 0
	for entry_variant: Variant in pool:
		total += int((entry_variant as Array)[1])
	var roll := rng.randi_range(1, total)
	for entry_variant: Variant in pool:
		var entry := entry_variant as Array
		roll -= int(entry[1])
		if roll <= 0:
			return String(entry[0])
	return String((pool[0] as Array)[0])

static func generate(rng: RandomNumberGenerator, profession: String, kind: String) -> Dictionary:
	var race := roll_race(rng, kind)
	var first_name: String
	var surname: String
	match race:
		"Dwarf":
			first_name = DWARF_FIRST_NAMES[rng.randi_range(0, DWARF_FIRST_NAMES.size() - 1)]
			surname = DWARF_CLAN_NAMES[rng.randi_range(0, DWARF_CLAN_NAMES.size() - 1)]
		"Goblin":
			first_name = GOBLIN_FIRST_NAMES[rng.randi_range(0, GOBLIN_FIRST_NAMES.size() - 1)]
			surname = GOBLIN_SURNAMES[rng.randi_range(0, GOBLIN_SURNAMES.size() - 1)]
		"Gnome":
			first_name = GNOME_FIRST_NAMES[rng.randi_range(0, GNOME_FIRST_NAMES.size() - 1)]
			surname = GNOME_SURNAMES[rng.randi_range(0, GNOME_SURNAMES.size() - 1)]
		"Kobold":
			first_name = KOBOLD_FIRST_NAMES[rng.randi_range(0, KOBOLD_FIRST_NAMES.size() - 1)]
			surname = KOBOLD_SURNAMES[rng.randi_range(0, KOBOLD_SURNAMES.size() - 1)]
		_:
			first_name = TOWNSFOLK_FIRST_NAMES[rng.randi_range(0, TOWNSFOLK_FIRST_NAMES.size() - 1)]
			surname = TOWNSFOLK_SURNAMES[rng.randi_range(0, TOWNSFOLK_SURNAMES.size() - 1)]
	var age_range := RACE_AGE_RANGES.get(race, [16, 78]) as Array
	var age := rng.randi_range(int(age_range[0]), int(age_range[1]))
	var faith := ""
	if rng.randf() >= FAITHLESS_CHANCE:
		var faiths := DWARF_FAITHS if kind == "dwarf" else TOWNSFOLK_FAITHS
		faith = faiths[rng.randi_range(0, faiths.size() - 1)]
	return {
		"name": "%s %s" % [first_name, surname],
		"first_name": first_name,
		"clan": surname,
		"race": race,
		"profession": profession,
		"age": age,
		"temperament": TEMPERAMENTS[rng.randi_range(0, TEMPERAMENTS.size() - 1)],
		"favorite": FAVORITE_ITEMS[rng.randi_range(0, FAVORITE_ITEMS.size() - 1)],
		"dream": DREAMS[rng.randi_range(0, DREAMS.size() - 1)],
		"faith": faith
	}

## The header line above dialogue and in hover tooltips:
## "Urist Copperbeard, Dwarf Miner (112)".
static func summary_line(identity: Dictionary) -> String:
	var race := String(identity.get("race", ""))
	var calling := String(identity.get("profession", "Wanderer"))
	if not race.is_empty():
		calling = "%s %s" % [race, calling]
	return "%s, %s (%d)" % [
		String(identity.get("name", "A stranger")),
		calling,
		int(identity.get("age", 0))
	]

## A personal line for conversation: their dream, their favorite thing,
## their temperament, their family, or their gods, in their own words.
static func personal_line(identity: Dictionary, rng: RandomNumberGenerator) -> String:
	match rng.randi_range(0, 4):
		0:
			# capitalize() Title-Cases Every Word (it's for snake_case
			# identifiers); spoken dialogue only wants the first letter up.
			# (Not WorldChronicleService._capitalize_first: that would make
			# the chronicle<->identity class references cyclic.)
			var dream := String(identity.get("dream", "to keep on keeping on"))
			return "My dream? %s." % (dream.substr(0, 1).to_upper() + dream.substr(1))
		1:
			return "Nothing beats a bit of %s, I say." % String(identity.get("favorite", "quiet"))
		2:
			var spouse := String(identity.get("spouse", ""))
			var children := identity.get("children", []) as Array
			if not spouse.is_empty() and not children.is_empty():
				return "%s and the little ones keep me honest." % spouse.get_slice(" ", 0)
			if not spouse.is_empty():
				return "Wed to %s, and gladly." % spouse
			var parents := identity.get("parents", []) as Array
			if not parents.is_empty():
				return "My folks? %s's kin, through and through." % String(parents[0]).get_slice(" ", 0)
			return "Folk around here call me %s." % String(identity.get("temperament", "steady"))
		3:
			var faith := String(identity.get("faith", ""))
			if not faith.is_empty():
				return "I keep faith with %s. It keeps me back." % faith
			return "Gods? Never had much use for them."
		_:
			return "Folk around here call me %s." % String(identity.get("temperament", "steady"))

## Longer sheet for tooltips: temperament, favorite, dream, kin and gods.
static func detail_lines(identity: Dictionary) -> Array[String]:
	var lines: Array[String] = [
		"Temperament: %s" % String(identity.get("temperament", "steady")),
		"Favors: %s" % String(identity.get("favorite", "quiet evenings")),
		"Dreams %s" % String(identity.get("dream", "of nothing much"))
	]
	var faith := String(identity.get("faith", ""))
	if not faith.is_empty():
		lines.append("Keeps faith with %s" % faith)
	var spouse := String(identity.get("spouse", ""))
	if not spouse.is_empty():
		lines.append("Wed to %s" % spouse)
	var parents := identity.get("parents", []) as Array
	if not parents.is_empty():
		var parent_names: Array[String] = []
		for parent_variant: Variant in parents:
			parent_names.append(String(parent_variant))
		lines.append("Child of %s" % " and ".join(parent_names))
	var children := identity.get("children", []) as Array
	if not children.is_empty():
		var child_firsts: Array[String] = []
		for child_variant: Variant in children:
			child_firsts.append(String(child_variant).get_slice(" ", 0))
		lines.append("Parent of %s" % ", ".join(child_firsts))
	return lines

## DF rule: every citizen looks like themselves. Appearance layers are
## rolled deterministically from the identity, so the same dwarf keeps
## the same face across sessions. Age greys the hair; dwarves keep
## their beards, human beards are a coin toss.
static func appearance_for_identity(identity: Dictionary, default_species: String = "dwarf") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%d" % [String(identity.get("name", "")), String(identity.get("clan", "")), int(identity.get("age", 0))])
	var race := String(identity.get("race", ""))
	if race.is_empty():
		race = "Dwarf" if default_species == "dwarf" else "Human"
	# Each race maps onto the layer sheets its own way: sheet choice,
	# skin tint (goblin green, kobold rust), beards, and body scale.
	var species := "human" if race == "Human" or race == "Gnome" else "dwarf"
	var skin_tint := ""
	var body_scale := 1.0
	var beardless := false
	match race:
		"Goblin":
			skin_tint = "#7fbf6a"
			body_scale = 0.8
			beardless = true
		"Kobold":
			skin_tint = "#c98a5e"
			body_scale = 0.72
			beardless = true
		"Gnome":
			body_scale = 0.72
	var age := int(identity.get("age", 60))
	var age_range := RACE_AGE_RANGES.get(race, [16, 78]) as Array
	var lifespan := float(int(age_range[1]))
	var elder_age := int(lifespan * 0.68)
	var greying_age := int(lifespan * 0.45)
	var hair_color: int
	if age >= elder_age:
		hair_color = rng.randi_range(0, 1)
	elif age >= greying_age and rng.randi_range(0, 2) == 0:
		hair_color = rng.randi_range(0, 1)
	else:
		hair_color = rng.randi_range(2, 5)
	var beard_style := -1
	if not beardless and (race == "Dwarf" or race == "Gnome" or rng.randi_range(0, 1) == 0):
		beard_style = rng.randi_range(0, 11)
	var layers := {
		"species": species,
		"skin_tone": rng.randi_range(0, 3),
		"hair_style": rng.randi_range(-1, 7) if species == "human" else rng.randi_range(0, 7),
		"hair_color": hair_color,
		"beard_style": beard_style,
		"beard_color": hair_color,
		"clothes_color": rng.randi_range(0, 17),
		"body_scale": body_scale
	}
	if not skin_tint.is_empty():
		layers["skin_tint"] = skin_tint
	return layers
