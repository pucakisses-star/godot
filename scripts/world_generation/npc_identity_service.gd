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
const TOWNSFOLK_FIRST_NAMES: Array[String] = [
	"Aldric", "Bertram", "Cedric", "Duncan", "Edwin", "Gareth", "Harold",
	"Osric", "Percival", "Rowan", "Tobias", "Wallace", "Agnes", "Beatrice",
	"Clara", "Edith", "Greta", "Isolde", "Maren", "Nell", "Rosalind",
	"Sybil", "Tilda", "Winifred", "Yorick", "Petra", "Lambert", "Hugh"
]
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

static func generate(rng: RandomNumberGenerator, profession: String, kind: String) -> Dictionary:
	var first_name: String
	var surname: String
	var age: int
	if kind == "dwarf":
		first_name = DWARF_FIRST_NAMES[rng.randi_range(0, DWARF_FIRST_NAMES.size() - 1)]
		surname = DWARF_CLAN_NAMES[rng.randi_range(0, DWARF_CLAN_NAMES.size() - 1)]
		age = rng.randi_range(22, 320)
	else:
		first_name = TOWNSFOLK_FIRST_NAMES[rng.randi_range(0, TOWNSFOLK_FIRST_NAMES.size() - 1)]
		surname = TOWNSFOLK_SURNAMES[rng.randi_range(0, TOWNSFOLK_SURNAMES.size() - 1)]
		age = rng.randi_range(16, 78)
	var faith := ""
	if rng.randf() >= FAITHLESS_CHANCE:
		var faiths := DWARF_FAITHS if kind == "dwarf" else TOWNSFOLK_FAITHS
		faith = faiths[rng.randi_range(0, faiths.size() - 1)]
	return {
		"name": "%s %s" % [first_name, surname],
		"first_name": first_name,
		"clan": surname,
		"profession": profession,
		"age": age,
		"temperament": TEMPERAMENTS[rng.randi_range(0, TEMPERAMENTS.size() - 1)],
		"favorite": FAVORITE_ITEMS[rng.randi_range(0, FAVORITE_ITEMS.size() - 1)],
		"dream": DREAMS[rng.randi_range(0, DREAMS.size() - 1)],
		"faith": faith
	}

## The header line above dialogue and in hover tooltips:
## "Urist Copperbeard, Miner (112)".
static func summary_line(identity: Dictionary) -> String:
	return "%s, %s (%d)" % [
		String(identity.get("name", "A stranger")),
		String(identity.get("profession", "Wanderer")),
		int(identity.get("age", 0))
	]

## A personal line for conversation: their dream, their favorite thing,
## their temperament, their family, or their gods, in their own words.
static func personal_line(identity: Dictionary, rng: RandomNumberGenerator) -> String:
	match rng.randi_range(0, 4):
		0:
			return "My dream? %s." % String(identity.get("dream", "to keep on keeping on")).capitalize()
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
static func appearance_for_identity(identity: Dictionary, species: String = "dwarf") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%d" % [String(identity.get("name", "")), String(identity.get("clan", "")), int(identity.get("age", 0))])
	var age := int(identity.get("age", 60))
	var elder_age := 200 if species == "dwarf" else 58
	var greying_age := 120 if species == "dwarf" else 45
	var hair_color: int
	if age >= elder_age:
		hair_color = rng.randi_range(0, 1)
	elif age >= greying_age and rng.randi_range(0, 2) == 0:
		hair_color = rng.randi_range(0, 1)
	else:
		hair_color = rng.randi_range(2, 5)
	var beard_style := -1
	if species == "dwarf" or rng.randi_range(0, 1) == 0:
		beard_style = rng.randi_range(0, 11)
	return {
		"species": species,
		"skin_tone": rng.randi_range(0, 3),
		"hair_style": rng.randi_range(-1, 7) if species == "human" else rng.randi_range(0, 7),
		"hair_color": hair_color,
		"beard_style": beard_style,
		"beard_color": hair_color,
		"clothes_color": rng.randi_range(0, 17)
	}
