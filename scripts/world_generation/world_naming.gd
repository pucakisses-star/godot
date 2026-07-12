extends RefCounted

const FOREST_NAME_PREFIXES: Array[String] = [
	"Verdant", "Whispering", "Emerald", "Silver", "Shadow", "Golden", "Moonlit", "Ancient", "Wild", "Sunset"
]
const FOREST_NAME_SUFFIXES: Array[String] = [
	"Groves", "Woods", "Thicket", "Wilds", "Canopy", "Boughs", "Hollows", "Glade", "Expanse", "Reserve"
]
const FOREST_NAME_MOTIFS: Array[String] = [
	"Echoes", "Mists", "Cicadas", "Fables", "Starlight", "Owls", "Whispers", "Lanterns", "Spirits", "Willows"
]

const MOUNTAIN_NAME_PREFIXES: Array[String] = [
	"Stone", "Iron", "Storm", "Thunder", "Frost", "Dragon", "Obsidian", "Moon", "Sunspire", "Titan"
]
const MOUNTAIN_NAME_SUFFIXES: Array[String] = [
	"Peaks", "Range", "Highlands", "Crown", "Mountains", "Spines", "Escarpment", "Ridge", "Tor", "Bastions"
]
const MOUNTAIN_NAME_MOTIFS: Array[String] = [
	"Storms", "Giants", "Dawn", "Ash", "Echoes", "Legends", "Stars", "Anvils", "Dragons", "Auroras"
]

const DESERT_NAME_DESCRIPTORS: Array[String] = [
	"Shifting", "Burning", "Golden", "Silent", "Glass", "Crimson", "Howling", "Endless", "Scoured", "Sunken"
]
const DESERT_NAME_NOUNS: Array[String] = [
	"Dunes", "Waste", "Expanse", "Sea", "Desert", "Reach", "Barrens", "Quarter", "Wastes", "Sands"
]
const DESERT_NAME_MOTIFS: Array[String] = [
	"Mirages", "Ashes", "Suns", "Bones", "Scorpions", "Dust", "Secrets", "Hollows", "Echoes", "Zephyrs"
]

const TUNDRA_NAME_DESCRIPTORS: Array[String] = [
	"Frozen", "Ivory", "Bleak", "Glimmering", "Shivering", "Frostbound", "Auric", "Pale", "Windshorn", "Starlit"
]
const TUNDRA_NAME_NOUNS: Array[String] = [
	"Tundra", "Reach", "Steppes", "Barrens", "Fields", "Expanse", "Marches", "Plateau", "Glade", "March"
]
const TUNDRA_NAME_MOTIFS: Array[String] = [
	"Auroras", "Frost", "Comets", "Stars", "Echoes", "Drifts", "Owls", "Lights", "Mammoths", "Silence"
]

const GRASSLAND_NAME_DESCRIPTORS: Array[String] = [
	"Windward", "Emerald", "Golden", "Rolling", "Open", "Skylit", "Silver", "Gentle", "Breezy", "Sunlit"
]
const GRASSLAND_NAME_NOUNS: Array[String] = [
	"Plains", "Meadows", "Fields", "Prairies", "Steppes", "Expanse", "Downs", "Reach", "Hearth", "Lowlands"
]
const GRASSLAND_NAME_MOTIFS: Array[String] = [
	"Larks", "Horizon", "Harvests", "Echoes", "Sunsets", "Breezes", "Lanterns", "Auroras", "Stones", "Dreams"
]

const JUNGLE_NAME_DESCRIPTORS: Array[String] = [
	"Emerald", "Verdant", "Sun-dappled", "Obsidian", "Mist-shrouded", "Ancient", "Thundering", "Canopy", "Moonlit", "Serpent"
]
const JUNGLE_NAME_NOUNS: Array[String] = [
	"Jungle", "Wilds", "Canopy", "Rainforest", "Tangle", "Deepwood", "Labyrinth", "Greenway", "Expanse", "Verdure"
]
const JUNGLE_NAME_MOTIFS: Array[String] = [
	"Serpents", "Drums", "Monsoons", "Spirits", "Cenotes", "Orchids", "Tempests", "Roots", "Jaguar Spirits", "Emerald Dawn"
]

const MARSH_NAME_DESCRIPTORS: Array[String] = [
	"Glimmer", "Mire", "Gloom", "Low", "Sodden", "Willow", "Brackish", "Sable", "Sunken", "Twilight"
]
const MARSH_NAME_NOUNS: Array[String] = [
	"Bog", "Fen", "Morass", "Quagmire", "Wetlands", "Mires", "Marsh", "Reeds", "Pools", "Sinks"
]
const MARSH_NAME_MOTIFS: Array[String] = [
	"Fireflies", "Lilies", "Secrets", "Mist", "Echoes", "Cranes", "Reeds", "Moss", "Shadows", "Frogs"
]

const BADLANDS_NAME_DESCRIPTORS: Array[String] = [
	"Shattered", "Redstone", "Sundered", "Dustfallen", "Sunblasted", "Windswept", "Bleached", "Broken", "Scorched", "Cracked"
]
const BADLANDS_NAME_NOUNS: Array[String] = [
	"Badlands", "Wastes", "Breaks", "Barrens", "Tablelands", "Escarpment", "Canyons", "Bluffs", "Ridges", "Maze"
]
const BADLANDS_NAME_MOTIFS: Array[String] = [
	"Bones", "Dust", "Echoes", "Thunderheads", "Vultures", "Ash", "Mirages", "Sunstorms", "Ruins", "Storms"
]

const OCEAN_NAME_DESCRIPTORS: Array[String] = [
	"Sapphire", "Tempest", "Sunken", "Cerulean", "Midnight", "Gilded", "Storm", "Azure", "Silent", "Everdeep"
]
const OCEAN_NAME_NOUNS: Array[String] = [
	"Sea", "Ocean", "Gulf", "Sound", "Reach", "Current", "Depths", "Expanse", "Waters", "Strait"
]
const OCEAN_NAME_MOTIFS: Array[String] = [
	"Sirens", "Stars", "Moons", "Whales", "Voyagers", "Storms", "Legends", "Coral", "Mists", "Echoes"
]

const ISLAND_NAME_FIRST_PARTS: Array[String] = [
	"Ash", "Storm", "Gull", "Black", "Ember", "Frost", "Drift", "Salt", "Crow", "Sun",
	"Mist", "Copper", "Whale", "Thorn", "Moon", "Red", "Glass", "Iron", "Green", "Pearl",
	"Bone", "Star", "King", "Hollow", "Tide", "Sea", "Cinder", "Wyrm", "Lantern", "Blue",
	"Gold", "Dagger", "Stone", "Marrow", "Wind", "Coral", "Oath", "Raven", "Brine", "Dusk",
	"Silver", "Honey", "Fox", "Anchor", "Deep", "Wolf", "Heron", "Kelp", "Spray", "Wreck"
]
const ISLAND_NAME_SECOND_PARTS: Array[String] = [
	"reach", "haven", "wake", "wind", "rock", "spire", "fall", "hook", "grave", "reef",
	"harbor", "tide", "water", "sand", "gull", "hollow", "mere", "crown", "briar", "shore",
	"strand", "hold", "watch", "fin", "bell", "veil", "point", "rest", "wood", "light"
]
const ISLAND_NAME_SUFFIXES: Array[String] = ["Isle", "Island"]
const ISLAND_NAME_TINY_SUFFIXES: Array[String] = ["Cay", "Rock", "Skerry", "Holm"]
const ISLAND_OF_MOTIFS: Array[String] = [
	"Larks", "Gulls", "Whales", "Sirens", "Lanterns", "Bones", "Mists", "Tides",
	"Seals", "Sorrows", "Embers", "Pearls", "Reeds", "Wrecks"
]
const ISLAND_SAINT_NAMES: Array[String] = [
	"Aberdeen", "Maria", "Brendan", "Morrow", "Elspeth", "Cassian", "Odile", "Rooke",
	"Isolde", "Fenwick"
]

const LAKE_NAME_DESCRIPTORS: Array[String] = [
	"Silver", "Crystal", "Mirror", "Still", "Glimmer", "Duskwater", "Bright", "Moon", "Amber", "Serene"
]
const LAKE_NAME_NOUNS: Array[String] = [
	"Lake", "Mere", "Loch", "Pond", "Basin", "Reservoir", "Waters", "Lagoon", "Pool", "Bay"
]
const LAKE_NAME_MOTIFS: Array[String] = [
	"Echoes", "Willows", "Lanterns", "Dreams", "Reflections", "Whispers", "Herons", "Lilies", "Dawn", "Stars"
]

## context_size is the water-body cluster size in tiles for water regions
## (browser context.size; oceans under 120 tiles downgrade to "Sea").
## Hills clusters get no region name (browser biomeTypeDefinitions has no
## hills entry, main.js:2767-2778).
static func generate_biome_region_name(biome: String, water_body_type: String, rng: RandomNumberGenerator, context_size: int) -> String:
	match biome:
		"forest": return _generate_forest_name(rng)
		"mountain": return _generate_mountain_name(rng)
		"desert": return _generate_desert_name(rng)
		"tundra": return _generate_tundra_name(rng)
		"grassland": return _generate_grassland_name(rng)
		"jungle": return _generate_jungle_name(rng)
		"marsh": return _generate_marsh_name(rng)
		"badlands": return _generate_badlands_name(rng)
		"water":
			if water_body_type == "lake":
				return _generate_lake_name(rng)
			return _generate_ocean_name(rng, context_size)
		_:
			return ""

## Pattern probabilities mirror the browser generators (main.js:2619-2749):
## motif-form chance first, then (where the browser has one) a separate
## roll for the "The ..." form.
static func _generate_forest_name(rng: RandomNumberGenerator) -> String:
	var prefix := _pick_random_entry(FOREST_NAME_PREFIXES, rng, "Verdant")
	var suffix := _pick_random_entry(FOREST_NAME_SUFFIXES, rng, "Woods")
	var motif := _pick_random_entry(FOREST_NAME_MOTIFS, rng)
	if not motif.is_empty() and rng.randf() < 0.65: return "%s %s of the %s" % [prefix, suffix, motif]
	if rng.randf() < 0.35: return "The %s %s" % [prefix, suffix]
	return "%s %s" % [prefix, suffix]

static func _generate_mountain_name(rng: RandomNumberGenerator) -> String:
	var prefix := _pick_random_entry(MOUNTAIN_NAME_PREFIXES, rng, "Stone")
	var suffix := _pick_random_entry(MOUNTAIN_NAME_SUFFIXES, rng, "Peaks")
	var motif := _pick_random_entry(MOUNTAIN_NAME_MOTIFS, rng)
	if not motif.is_empty() and rng.randf() < 0.6: return "%s %s of the %s" % [prefix, suffix, motif]
	return "The %s %s" % [prefix, suffix]

static func _generate_desert_name(rng: RandomNumberGenerator) -> String:
	var descriptor := _pick_random_entry(DESERT_NAME_DESCRIPTORS, rng, "Shifting")
	var noun := _pick_random_entry(DESERT_NAME_NOUNS, rng, "Dunes")
	var motif := _pick_random_entry(DESERT_NAME_MOTIFS, rng)
	if not motif.is_empty() and rng.randf() < 0.5: return "%s of the %s" % [noun, motif]
	return "The %s %s" % [descriptor, noun]

static func _generate_tundra_name(rng: RandomNumberGenerator) -> String:
	var descriptor := _pick_random_entry(TUNDRA_NAME_DESCRIPTORS, rng, "Frozen")
	var noun := _pick_random_entry(TUNDRA_NAME_NOUNS, rng, "Tundra")
	var motif := _pick_random_entry(TUNDRA_NAME_MOTIFS, rng)
	if not motif.is_empty() and rng.randf() < 0.55: return "%s of the %s" % [noun, motif]
	return "The %s %s" % [descriptor, noun]

static func _generate_grassland_name(rng: RandomNumberGenerator) -> String:
	var descriptor := _pick_random_entry(GRASSLAND_NAME_DESCRIPTORS, rng, "Windward")
	var noun := _pick_random_entry(GRASSLAND_NAME_NOUNS, rng, "Plains")
	var motif := _pick_random_entry(GRASSLAND_NAME_MOTIFS, rng)
	if not motif.is_empty() and rng.randf() < 0.5: return "%s of the %s" % [noun, motif]
	if rng.randf() < 0.4: return "The %s %s" % [descriptor, noun]
	return "%s %s" % [descriptor, noun]

static func _generate_jungle_name(rng: RandomNumberGenerator) -> String:
	var descriptor := _pick_random_entry(JUNGLE_NAME_DESCRIPTORS, rng, "Emerald")
	var noun := _pick_random_entry(JUNGLE_NAME_NOUNS, rng, "Jungle")
	var motif := _pick_random_entry(JUNGLE_NAME_MOTIFS, rng)
	if not motif.is_empty() and rng.randf() < 0.65: return "%s of the %s" % [noun, motif]
	if rng.randf() < 0.45: return "The %s %s" % [descriptor, noun]
	return "%s %s" % [descriptor, noun]

static func _generate_marsh_name(rng: RandomNumberGenerator) -> String:
	var descriptor := _pick_random_entry(MARSH_NAME_DESCRIPTORS, rng, "Glimmer")
	var noun := _pick_random_entry(MARSH_NAME_NOUNS, rng, "Bog")
	var motif := _pick_random_entry(MARSH_NAME_MOTIFS, rng)
	if not motif.is_empty() and rng.randf() < 0.6: return "%s %s of the %s" % [descriptor, noun, motif]
	return "The %s %s" % [descriptor, noun]

static func _generate_badlands_name(rng: RandomNumberGenerator) -> String:
	var descriptor := _pick_random_entry(BADLANDS_NAME_DESCRIPTORS, rng, "Shattered")
	var noun := _pick_random_entry(BADLANDS_NAME_NOUNS, rng, "Badlands")
	var motif := _pick_random_entry(BADLANDS_NAME_MOTIFS, rng)
	if not motif.is_empty() and rng.randf() < 0.55: return "%s of the %s" % [noun, motif]
	if rng.randf() < 0.35: return "The %s %s" % [descriptor, noun]
	return "%s %s" % [descriptor, noun]

static func _generate_ocean_name(rng: RandomNumberGenerator, context_size: int) -> String:
	var descriptor := _pick_random_entry(OCEAN_NAME_DESCRIPTORS, rng, "Sapphire")
	var noun := _pick_random_entry(OCEAN_NAME_NOUNS, rng, "Sea")
	var motif := _pick_random_entry(OCEAN_NAME_MOTIFS, rng)
	# Browser: context.size is the water BODY size in tiles; small bodies
	# never carry the "Ocean" noun.
	if context_size < 120 and noun == "Ocean": noun = "Sea"
	if not motif.is_empty() and rng.randf() < 0.65: return "%s of the %s" % [noun, motif]
	return "The %s %s" % [descriptor, noun]

static func _generate_lake_name(rng: RandomNumberGenerator) -> String:
	var descriptor := _pick_random_entry(LAKE_NAME_DESCRIPTORS, rng, "Silver")
	var noun := _pick_random_entry(LAKE_NAME_NOUNS, rng, "Lake")
	var motif := _pick_random_entry(LAKE_NAME_MOTIFS, rng)
	var lower_noun := noun.to_lower()
	if lower_noun == "lake" or lower_noun == "loch":
		if not motif.is_empty() and rng.randf() < 0.7: return "%s %s" % [noun, motif]
		return "%s %s" % [noun, descriptor]
	if not motif.is_empty() and rng.randf() < 0.6: return "The %s %s of the %s" % [descriptor, noun, motif]
	return "The %s %s" % [descriptor, noun]

## Island-flavored names (Ashen Isle, Stormreach, Ember Cay, Isle of Larks)
## for small sea landmasses whose per-biome names would otherwise read as
## inland terrain. island_size in tiles gates the tiny-island suffixes
## (Cay/Rock/Skerry); used_names keeps names unique across one map build.
static func generate_island_name(rng: RandomNumberGenerator, island_size: int, used_names: Dictionary) -> String:
	var candidate := ""
	for _attempt in range(12):
		candidate = _compose_island_name(rng, island_size)
		if not used_names.has(candidate):
			return candidate
	return candidate

static func _compose_island_name(rng: RandomNumberGenerator, island_size: int) -> String:
	var roll := rng.randf()
	if roll < 0.08:
		return "%s of %s" % [
			"Isle" if rng.randf() < 0.7 else "Island",
			_pick_random_entry(ISLAND_OF_MOTIFS, rng, "Larks")
		]
	if roll < 0.15:
		return "St. %s %s" % [
			_pick_random_entry(ISLAND_SAINT_NAMES, rng, "Maria"),
			_pick_random_entry(ISLAND_NAME_SUFFIXES, rng, "Isle")
		]
	var first := _pick_random_entry(ISLAND_NAME_FIRST_PARTS, rng, "Drift")
	var second := _pick_random_entry(ISLAND_NAME_SECOND_PARTS, rng, "wood")
	if second == first.to_lower():
		second = "haven"
	var compound := first + second
	if island_size <= 12 and roll < 0.45:
		return "%s %s" % [compound, _pick_random_entry(ISLAND_NAME_TINY_SUFFIXES, rng, "Cay")]
	if roll < 0.55:
		return compound
	return "%s %s" % [compound, _pick_random_entry(ISLAND_NAME_SUFFIXES, rng, "Isle")]

static func _pick_random_entry(options: Array[String], rng: RandomNumberGenerator, fallback: String = "") -> String:
	if options.is_empty(): return fallback
	return options[rng.randi_range(0, options.size() - 1)]
