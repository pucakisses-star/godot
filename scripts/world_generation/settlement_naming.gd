extends RefCounted
class_name SettlementNaming

## Procedural name generators for overworld settlements and structures.
## Ported from the original web prototype (Github Game/main.js) so towns,
## groves, towers, camps, mines, monasteries, shrines, taverns, dungeons
## and goblin caves all get proper names instead of generic type labels.

const TOWN_PREFIXES: Array[String] = [
	"Oak", "River", "Stone", "Amber", "Green", "Silver", "Gold", "Iron",
	"Autumn", "Frost", "Sun", "Star", "Moon", "Wolf", "Wind", "Bright",
	"High", "Low", "Cedar", "Elm", "Maple", "Ash", "Willow", "King",
	"Queens", "Dragon", "Hearth", "North", "South", "East", "West"
]

const TOWN_SUFFIXES: Array[String] = [
	"ford", "field", "holm", "stead", "wich", "wick", "haven", "crest",
	"gate", "watch", "brook", "ton", "ham", "bridge", "moor", "port",
	"fall", "mere", "bury", "ridge", "bank", "view", "grove", "vale",
	"reach", "cross", "run", "rise", "pass"
]

const TOWN_DESCRIPTORS: Array[String] = [
	"Market", "Crossroads", "Commons", "Harbor", "Square", "Heights",
	"Heath", "Village", "Town", "Hold", "Keep", "Exchange", "Quarter",
	"Reach", "Hollow"
]

const GROVE_PREFIXES: Array[String] = [
	"Sylvan", "Moon", "Star", "Silver", "Verdant", "Thorn", "Whisper",
	"Autumn", "Lark", "Eversong", "Glimmer", "Sun", "Briar", "Moss", "Willow"
]

const GROVE_SUFFIXES: Array[String] = [
	"Grove", "Glade", "Haven", "Refuge", "Circle", "Hollow", "Sanctum",
	"Enclave", "Retreat", "Thicket"
]

const GROVE_DESCRIPTORS: Array[String] = [
	"of the Dawn Chorus", "of Whispering Leaves", "of Starlit Boughs",
	"of the Emerald Court", "of the Eternal Spring", "of the Moonlit Vale",
	"of the Verdant Watch", "of the First Trees", "of Glimmering Dew",
	"of the Silver Song"
]

const TOWER_PREFIXES: Array[String] = [
	"Obsidian", "Gilded", "Runed", "Frost", "Storm", "Ivory", "Crimson",
	"Verdant", "Azure", "Shadow", "Sunset", "Moonrise", "Starfall",
	"Ember", "Sapphire"
]

const TOWER_NOUNS: Array[String] = [
	"Tower", "Spire", "Watch", "Keep", "Pinnacle", "Bastion", "Citadel",
	"Lantern"
]

const TOWER_QUALIFIERS: Array[String] = [
	"of Dawn", "of Twilight", "of Storms", "of Secrets", "of Embers",
	"of Whispers", "of the North", "of the Veil", "of Echoes",
	"of the First Light", "of the Last Watch", "of the Silent Choir"
]

const MINE_PREFIXES: Array[String] = [
	"Iron", "Silver", "Copper", "Gold", "Mithril", "Coal", "Gem",
	"Obsidian", "Crystal", "Rune", "Ember", "Thunder", "Star", "Deep"
]

const MINE_SUFFIXES: Array[String] = [
	"delve", "reach", "shaft", "vein", "hollow", "works", "forge",
	"deep", "spire", "gate"
]

const MINE_DESCRIPTORS: Array[String] = [
	"Mine", "Delve", "Excavation", "Works", "Prospect"
]

const HILLHOLD_PREFIXES: Array[String] = [
	"Stone", "Amber", "Bronze", "Granite", "Cloud", "Storm", "Frost",
	"Ember", "Ridge", "Hearth", "Rune", "Copper", "Oak", "Pine",
	"Crown", "Deep", "Iron"
]

const HILLHOLD_SUFFIXES: Array[String] = [
	"watch", "guard", "hold", "fast", "hearth", "delve", "gate",
	"spire", "tor", "bastion"
]

const HILLHOLD_DESCRIPTORS: Array[String] = [
	"Hill", "Heights", "Tor", "Rise", "Overlook", "Sentinel", "Cairn", "Keep"
]

const ORC_ADJECTIVES: Array[String] = [
	"Ironjaw", "Bloodfang", "Stormhide", "Ashen", "Bonegnaw",
	"Thunderhoof", "Grimgaze", "Skullsplitter", "Nightscar", "Rageborn"
]

const ORC_NOUNS: Array[String] = [
	"Clan", "Warband", "Legion", "Brood", "Horde", "Reavers",
	"Marauders", "Prowlers"
]

const GNOLL_ADJECTIVES: Array[String] = [
	"Dustmane", "Howling", "Sunscar", "Nightmaw", "Boneclaw", "Ashsnout",
	"Stormsnout", "Ragged", "Skullmuzzle", "Emberfang"
]

const GNOLL_NOUNS: Array[String] = [
	"Pack", "Raid", "Howlers", "Hunters", "Warband", "Maw", "Snarl",
	"Scavengers"
]

const TROLL_ADJECTIVES: Array[String] = [
	"Bog", "Stone", "Mire", "Frost", "Grim", "Thunder", "Rot",
	"Boulder", "Moss", "Brine"
]

const TROLL_NOUNS: Array[String] = [
	"Den", "Brood", "Hollow", "Pit", "Haunt", "Grotto", "Crag", "Hold"
]

const OGRE_ADJECTIVES: Array[String] = [
	"Crushjaw", "Bonegrinder", "Thundermaul", "Ironbelly", "Boulderfist",
	"Skullsmash", "Stormbreaker", "Gorehammer", "Rubblehide", "Maulbrand"
]

const OGRE_NOUNS: Array[String] = [
	"Clan", "Muster", "Warband", "Brutes", "Crushers", "Maulers",
	"Slam", "Rend"
]

const BANDIT_ADJECTIVES: Array[String] = [
	"Red", "Black", "Iron", "Rust", "Shadow", "Amber", "Silver", "Wild",
	"Gravel", "Broken"
]

const BANDIT_NOUNS: Array[String] = [
	"Knives", "Riders", "Coyotes", "Lanterns", "Vultures", "Hands",
	"Blades", "Company", "Road", "Hollows"
]

const CENTAUR_ADJECTIVES: Array[String] = [
	"Swiftwind", "Stormhoof", "Sunmane", "Moonstride", "Galeheart",
	"Starhoof", "Dawnrunner", "Thunderleaf", "Mistveil", "Wildsong"
]

const CENTAUR_NOUNS: Array[String] = [
	"Herd", "Circle", "Moot", "Outriders", "Gathering", "Courers",
	"Skyriders", "Wardens"
]

const TRAVELER_ADJECTIVES: Array[String] = [
	"Lantern", "Amber", "Star", "Frontier", "Drift", "Iron", "Wayfarer",
	"Cedar"
]

const TRAVELER_LANDMARKS: Array[String] = [
	"Crossing", "Hollow", "Trail", "Fork", "Pass", "Fields", "Meadow"
]

const TRAVELER_NOUNS: Array[String] = [
	"Camp", "Encampment", "Outpost", "Commons", "Waystation"
]

const MONASTERY_ORDERS: Array[String] = [
	"Order of the Dawn Lantern", "Order of Silent Rivers",
	"Brotherhood of the Verdant Star", "Scribes of the Hidden Song",
	"Wardens of the Azure Flame", "Sisters of the Gentle Bell"
]

const MONASTERY_VIRTUES: Array[String] = [
	"Contemplation", "Vigilance", "Compassion", "Illumination",
	"Endurance", "Harmony"
]

const SAINTLY_NAMES: Array[String] = [
	"Saint Elowen", "Saint Calder", "Saint Miriel", "Saint Tharan",
	"Saint Ysoria", "Saint Brannoc"
]

const TAVERN_ADJECTIVES: Array[String] = [
	"Golden", "Starlit", "Roaring", "Whispering", "Copper", "Moonlit",
	"Wandering"
]

const TAVERN_NOUNS: Array[String] = [
	"Hearth", "Steed", "Keg", "Anvil", "Lantern", "Drum", "Oak"
]

const TAVERN_DESCRIPTORS: Array[String] = [
	"Crossroads Inn", "Wayside Rest", "Taphouse", "Roadhouse",
	"Pilgrim's Lodge", "Caravan Hostel"
]

const DUNGEON_PREFIXES: Array[String] = [
	"Whispering", "Sunken", "Forsaken", "Crumbling", "Midnight",
	"Shrouded", "Veiled", "Obsidian"
]

const DUNGEON_SUFFIXES: Array[String] = [
	"Vault", "Depths", "Catacomb", "Sepulchre", "Labyrinth", "Halls",
	"Crypt"
]

const GOBLIN_CAVE_PREFIXES: Array[String] = [
	"Murkfang", "Skullcleft", "Rotlash", "Gloomspine", "Ashknuckle",
	"Blightvein", "Snarltooth", "Festerwick"
]

const GOBLIN_CAVE_SUFFIXES: Array[String] = [
	"Warrens", "Lair", "Grotto", "Den", "Burrows", "Hollow", "Tunnels"
]

const CASTLE_HOUSE_NAMES: Array[String] = [
	"House Blackthorn", "House Rivenshield", "House Cindergate",
	"House Frostmere", "House Dawnspear", "House Emberhall"
]

static func town_name(rng: RandomNumberGenerator) -> String:
	var prefix := _pick(TOWN_PREFIXES, rng, "Oak")
	var suffix := _pick(TOWN_SUFFIXES, rng, "ford")
	var base_name := "%s%s" % [prefix, suffix]
	var descriptor := _pick(TOWN_DESCRIPTORS, rng, "")
	var style_roll := rng.randf()
	if style_roll < 0.3 and not descriptor.is_empty():
		return "%s %s" % [base_name, descriptor]
	if style_roll < 0.65:
		return base_name
	return "Town of %s" % base_name

static func grove_name(rng: RandomNumberGenerator) -> String:
	var prefix := _pick(GROVE_PREFIXES, rng, "Sylvan")
	var suffix := _pick(GROVE_SUFFIXES, rng, "Grove")
	var base_name := "%s %s" % [prefix, suffix]
	var descriptor := _pick(GROVE_DESCRIPTORS, rng, "")
	if not descriptor.is_empty() and rng.randf() < 0.65:
		return "%s %s" % [base_name, descriptor]
	return base_name

static func tower_name(rng: RandomNumberGenerator) -> String:
	var prefix := _pick(TOWER_PREFIXES, rng, "Obsidian")
	var noun := _pick(TOWER_NOUNS, rng, "Tower")
	var qualifier := _pick(TOWER_QUALIFIERS, rng, "")
	var style_roll := rng.randf()
	if style_roll < 0.35 and not qualifier.is_empty():
		return "%s %s %s" % [prefix, noun, qualifier]
	if style_roll < 0.65:
		return "%s %s" % [prefix, noun]
	if not qualifier.is_empty():
		return "Tower %s" % qualifier
	return "%s %s" % [prefix, noun]

static func evil_wizard_tower_name(rng: RandomNumberGenerator) -> String:
	return "Evil Wizard's %s" % tower_name(rng)

static func mine_name(rng: RandomNumberGenerator) -> String:
	var prefix := _pick(MINE_PREFIXES, rng, "Iron")
	var suffix := _pick(MINE_SUFFIXES, rng, "delve")
	var descriptor := _pick(MINE_DESCRIPTORS, rng, "Mine")
	var combined := "%s%s" % [prefix, suffix]
	var style_roll := rng.randf()
	if style_roll < 0.35:
		return "%s %s" % [combined, descriptor]
	if style_roll < 0.65:
		return "%s %s" % [prefix, descriptor]
	if style_roll < 0.85:
		return "%s of %s" % [descriptor, combined]
	return combined

static func hillhold_name(rng: RandomNumberGenerator) -> String:
	var prefix := _pick(HILLHOLD_PREFIXES, rng, "Stone")
	var suffix := _pick(HILLHOLD_SUFFIXES, rng, "hold")
	var descriptor := _pick(HILLHOLD_DESCRIPTORS, rng, "")
	var base_name := "%s%s" % [prefix, suffix]
	var style_roll := rng.randf()
	if style_roll < 0.3 and not descriptor.is_empty():
		return "%s %s" % [base_name, descriptor]
	if style_roll < 0.6 and not descriptor.is_empty():
		return "%s Hillhold" % descriptor
	if style_roll < 0.85:
		return "%s Hillhold" % base_name
	return "%s Hold" % base_name

static func camp_name(camp_id: String, rng: RandomNumberGenerator) -> String:
	match camp_id:
		"orcCamp":
			return _band_name(ORC_ADJECTIVES, ORC_NOUNS, rng,
				["%s %s Camp", "%s %s Warcamp", "Camp of the %s %s"])
		"gnollCamp":
			return _band_name(GNOLL_ADJECTIVES, GNOLL_NOUNS, rng,
				["%s %s Den", "%s %s War-Pack", "Den of the %s %s"])
		"trollCamp":
			return _band_name(TROLL_ADJECTIVES, TROLL_NOUNS, rng,
				["%s %s", "%s %s Brood", "%2$s of the %1$s Tides"])
		"ogreCamp":
			return _band_name(OGRE_ADJECTIVES, OGRE_NOUNS, rng,
				["%s %s Muster", "%s %s Camp", "Stronghold of the %s %s"])
		"banditCamp":
			return _band_name(BANDIT_ADJECTIVES, BANDIT_NOUNS, rng,
				["%s %s Hideout", "%s %s Camp", "Hideout of the %s %s"])
		"centaurEncampment":
			return _band_name(CENTAUR_ADJECTIVES, CENTAUR_NOUNS, rng,
				["%s %s Encampment", "%2$s of the %1$s Plains", "%s %s Moot"])
		"travelerCamp":
			return traveler_camp_name(rng)
		_:
			return _band_name(BANDIT_ADJECTIVES, BANDIT_NOUNS, rng,
				["%s %s Camp", "%s %s Camp", "Camp of the %s %s"])

static func traveler_camp_name(rng: RandomNumberGenerator) -> String:
	var adjective := _pick(TRAVELER_ADJECTIVES, rng, "Lantern")
	var noun := _pick(TRAVELER_NOUNS, rng, "Camp")
	var landmark := _pick(TRAVELER_LANDMARKS, rng, "")
	var style_roll := rng.randf()
	if style_roll < 0.35 and not landmark.is_empty():
		return "%s %s %s" % [adjective, landmark, noun]
	if style_roll < 0.7:
		return "%s %s" % [adjective, noun]
	return "%s of the %s Road" % [noun, adjective]

static func monastery_name(rng: RandomNumberGenerator) -> String:
	var order_name := _pick(MONASTERY_ORDERS, rng, "Order of the Dawn Lantern")
	var virtue := _pick(MONASTERY_VIRTUES, rng, "Contemplation")
	if rng.randf() < 0.5:
		if order_name.to_lower().contains("monastery"):
			return order_name
		return "%s Monastery" % order_name
	return "Monastery of %s" % virtue

static func saint_shrine_name(rng: RandomNumberGenerator) -> String:
	var saint := _pick(SAINTLY_NAMES, rng, "Saint Elowen")
	if rng.randf() < 0.5:
		return "Shrine of %s" % saint
	return "%s's Shrine" % saint

static func tavern_name(rng: RandomNumberGenerator) -> String:
	var adjective := _pick(TAVERN_ADJECTIVES, rng, "Golden")
	var noun := _pick(TAVERN_NOUNS, rng, "Hearth")
	var descriptor := _pick(TAVERN_DESCRIPTORS, rng, "Roadhouse")
	var style_roll := rng.randf()
	if style_roll < 0.45:
		return "The %s %s" % [adjective, noun]
	if style_roll < 0.75:
		return "%s %s %s" % [adjective, noun, descriptor]
	return "%s of the %s %s" % [descriptor, adjective, noun]

static func dungeon_name(rng: RandomNumberGenerator) -> String:
	var prefix := _pick(DUNGEON_PREFIXES, rng, "Sunken")
	var suffix := _pick(DUNGEON_SUFFIXES, rng, "Vault")
	var style_roll := rng.randf()
	if style_roll < 0.4:
		return "%s %s" % [prefix, suffix]
	if style_roll < 0.75:
		return "%s of %s Echoes" % [suffix, prefix]
	return "%s %s of Dread" % [prefix, suffix]

static func goblin_cave_name(rng: RandomNumberGenerator) -> String:
	var prefix := _pick(GOBLIN_CAVE_PREFIXES, rng, "Murkfang")
	var suffix := _pick(GOBLIN_CAVE_SUFFIXES, rng, "Warrens")
	var style_roll := rng.randf()
	if style_roll < 0.4:
		return "%s %s" % [prefix, suffix]
	if style_roll < 0.75:
		return "%s's %s" % [prefix, suffix]
	return "%s of %s" % [suffix, prefix]

static func castle_name(rng: RandomNumberGenerator) -> String:
	var house := _pick(CASTLE_HOUSE_NAMES, rng, "House Blackthorn")
	var base := house.trim_prefix("House ")
	var style_roll := rng.randf()
	if style_roll < 0.4:
		return "Castle %s" % base
	if style_roll < 0.7:
		return "%s Keep" % base
	return "%s Holdfast" % base

## Names a scored structure by its structure id; returns an empty string
## for ids without a dedicated generator so callers can fall back.
static func structure_name(structure_id: String, rng: RandomNumberGenerator) -> String:
	match structure_id:
		"monastery":
			return monastery_name(rng)
		"saintShrine":
			return saint_shrine_name(rng)
		"roadsideTavern":
			return tavern_name(rng)
		"castle":
			return castle_name(rng)
		"mine":
			return mine_name(rng)
		"hillhold":
			return hillhold_name(rng)
		"dungeon":
			return dungeon_name(rng)
		"cave", "goblinCave":
			return goblin_cave_name(rng)
		_:
			return ""

static func _band_name(adjectives: Array[String], nouns: Array[String], rng: RandomNumberGenerator, patterns: Array) -> String:
	var adjective := _pick(adjectives, rng, "Iron")
	var noun := _pick(nouns, rng, "Band")
	var style_roll := rng.randf()
	var pattern_index := 0
	if style_roll >= 0.66:
		pattern_index = 2
	elif style_roll >= 0.33:
		pattern_index = 1
	var pattern := String(patterns[pattern_index])
	var name := ""
	if pattern.contains("%1$s"):
		name = pattern.replace("%1$s", adjective).replace("%2$s", noun)
	else:
		name = pattern % [adjective, noun]
	return _collapse_repeated_words(name)

## Guards against vocab/pattern collisions such as "Moot Moot" when the
## rolled noun already ends the pattern.
static func _collapse_repeated_words(name: String) -> String:
	var words := name.split(" ", false)
	var result: Array[String] = []
	for word in words:
		if not result.is_empty() and result[result.size() - 1] == word:
			continue
		result.append(word)
	return " ".join(result)

static func _pick(options: Array[String], rng: RandomNumberGenerator, fallback: String) -> String:
	if options.is_empty():
		return fallback
	return options[rng.randi_range(0, options.size() - 1)]
