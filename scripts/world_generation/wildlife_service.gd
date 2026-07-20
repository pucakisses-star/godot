extends RefCounted
class_name WildlifeService

## Real-fauna species layered over the game's creature bodies, the way
## Dwarf Fortress layers species over glyphs: each species claims a
## body (a sprite row or a farm-animal sheet), a tint and a size, the
## biomes it ranges, its own stats and loot. The wilds spawn what the
## ground supports - marsh newts in the fens, dune basilisks in the
## sand, yetis in the snows, aurochs on the plain - and the underhalls
## field cave-adapted kin of the same bodies.
##
## Body slots on creature_characters.png:
##   0-2 fungal shapes, 3-5 reptilian hunters, 6-7 brutes.
## Tiers mirror the danger ladder: 0 = slots 0-2, 1 = 3-5, 2 = 6-7.

const SPECIES: Array[Dictionary] = [
	# --- Tier 0: small things (fungal bodies) --------------------------------
	{"name": "Sporeling", "slot": 0, "tier": 0, "biomes": ["forest", "grass", "cave"],
		"tint": Color(1, 1, 1), "scale": 1.0, "max_hp": 4, "damage": 1,
		"loot": [{"item": "Mushrooms", "min": 1, "max": 2, "chance": 100}]},
	{"name": "Puffball Crawler", "slot": 0, "tier": 0, "biomes": ["grass", "forest"],
		"tint": Color(1.05, 1.02, 0.9), "scale": 0.9, "max_hp": 3, "damage": 1,
		"loot": [{"item": "Spore Dust", "min": 1, "max": 2, "chance": 100}]},
	{"name": "Frost Sporeling", "slot": 0, "tier": 0, "biomes": ["snow"],
		"tint": Color(0.85, 0.95, 1.1), "scale": 1.0, "max_hp": 5, "damage": 1,
		"loot": [{"item": "Frostcap", "min": 1, "max": 1, "chance": 70}]},
	{"name": "Dust Lurker", "slot": 0, "tier": 0, "biomes": ["sand"],
		"tint": Color(1.1, 1.0, 0.8), "scale": 1.0, "max_hp": 4, "damage": 1,
		"loot": [{"item": "Spore Dust", "min": 1, "max": 2, "chance": 100}]},
	{"name": "Crimson Sporecap", "slot": 1, "tier": 0, "biomes": ["forest", "cave"],
		"tint": Color(1, 1, 1), "scale": 1.0, "max_hp": 7, "damage": 2,
		"loot": [{"item": "Spore Dust", "min": 1, "max": 2, "chance": 100}]},
	{"name": "Witchcap Shambler", "slot": 1, "tier": 0, "biomes": ["marsh", "forest"],
		"tint": Color(0.85, 0.9, 1.05), "scale": 1.05, "max_hp": 8, "damage": 2,
		"loot": [{"item": "Nightcap Bells", "min": 1, "max": 1, "chance": 60},
			{"item": "Spore Dust", "min": 1, "max": 1, "chance": 60}]},
	{"name": "Elder Myconid", "slot": 2, "tier": 0, "biomes": ["cave", "forest"],
		"tint": Color(1, 1, 1), "scale": 1.0, "max_hp": 10, "damage": 2,
		"loot": [{"item": "Spore Dust", "min": 2, "max": 3, "chance": 100},
			{"item": "Glowcap", "min": 1, "max": 1, "chance": 40}]},
	{"name": "Glowcap Warden", "slot": 2, "tier": 0, "biomes": ["cave"],
		"tint": Color(0.8, 1.05, 1.1), "scale": 1.05, "max_hp": 11, "damage": 2,
		"loot": [{"item": "Glowcap", "min": 1, "max": 2, "chance": 100}]},
	# --- Tier 1: hunters (reptilian bodies) ----------------------------------
	{"name": "Lizardman Skirmisher", "predator": true, "slot": 3, "tier": 1, "biomes": ["grass", "forest", "marsh"],
		"tint": Color(1, 1, 1), "scale": 1.0, "max_hp": 8, "damage": 2,
		"loot": [{"item": "Leather Strap", "min": 1, "max": 1, "chance": 60}]},
	{"name": "Marsh Newt", "predator": true, "slot": 3, "tier": 1, "biomes": ["marsh"],
		"tint": Color(0.8, 1.0, 0.85), "scale": 0.9, "max_hp": 7, "damage": 2,
		"loot": [{"item": "Grilled Fish", "min": 1, "max": 1, "chance": 40}]},
	{"name": "Sand Skink", "predator": true, "slot": 3, "tier": 1, "biomes": ["sand"],
		"tint": Color(1.1, 1.0, 0.75), "scale": 0.95, "max_hp": 8, "damage": 2,
		"loot": [{"item": "Leather Strap", "min": 1, "max": 1, "chance": 70}]},
	{"name": "Frost Newt", "predator": true, "slot": 3, "tier": 1, "biomes": ["snow"],
		"tint": Color(0.8, 0.92, 1.15), "scale": 0.95, "max_hp": 9, "damage": 2,
		"loot": [{"item": "Frostleaf", "min": 1, "max": 1, "chance": 50}]},
	{"name": "Cave Skink", "predator": true, "slot": 3, "tier": 1, "biomes": ["cave"],
		"tint": Color(0.85, 0.85, 0.95), "scale": 0.95, "max_hp": 8, "damage": 2,
		"loot": [{"item": "Leather Strap", "min": 1, "max": 1, "chance": 60}]},
	{"name": "Lizardman Stalker", "predator": true, "slot": 4, "tier": 1, "biomes": ["forest", "grass", "marsh"],
		"tint": Color(1, 1, 1), "scale": 1.0, "max_hp": 11, "damage": 3,
		"loot": [{"item": "Leather Strap", "min": 1, "max": 2, "chance": 70}]},
	{"name": "Bog Salamander", "predator": true, "slot": 4, "tier": 1, "biomes": ["marsh"],
		"tint": Color(0.75, 0.9, 0.7), "scale": 1.05, "max_hp": 12, "damage": 3,
		"loot": [{"item": "Violet Veil", "min": 1, "max": 1, "chance": 40}]},
	{"name": "Dune Basilisk", "predator": true, "slot": 4, "tier": 1, "biomes": ["sand"],
		"tint": Color(1.15, 1.05, 0.7), "scale": 1.1, "max_hp": 13, "damage": 3,
		"loot": [{"item": "Gem Shard", "min": 1, "max": 1, "chance": 30},
			{"item": "Leather Strap", "min": 1, "max": 1, "chance": 70}]},
	{"name": "Lizardman Chieftain", "predator": true, "slot": 5, "tier": 1, "biomes": ["grass", "forest", "marsh"],
		"tint": Color(1, 1, 1), "scale": 1.0, "max_hp": 15, "damage": 3,
		"loot": [{"item": "Leather Strap", "min": 1, "max": 2, "chance": 80},
			{"item": "Gold Nugget", "min": 1, "max": 1, "chance": 25}]},
	{"name": "River Drake", "predator": true, "slot": 5, "tier": 1, "biomes": ["marsh", "grass"],
		"tint": Color(0.75, 0.95, 1.1), "scale": 1.1, "max_hp": 16, "damage": 3,
		"loot": [{"item": "Golden Koi", "min": 1, "max": 1, "chance": 40}]},
	{"name": "Salt Drake", "predator": true, "slot": 5, "tier": 1, "biomes": ["sand"],
		"tint": Color(1.1, 1.1, 0.95), "scale": 1.1, "max_hp": 16, "damage": 3,
		"loot": [{"item": "Gem Shard", "min": 1, "max": 1, "chance": 35}]},
	# --- Tier 2: brutes ------------------------------------------------------
	{"name": "Orc Raider", "predator": true, "slot": 6, "tier": 2, "biomes": ["grass", "forest", "sand"],
		"tint": Color(1, 1, 1), "scale": 1.0, "max_hp": 13, "damage": 3,
		"loot": [{"item": "Leather Strap", "min": 1, "max": 2, "chance": 80}]},
	{"name": "Gnoll Prowler", "predator": true, "slot": 6, "tier": 2, "biomes": ["grass", "sand"],
		"tint": Color(1.05, 0.95, 0.75), "scale": 1.0, "max_hp": 12, "damage": 3,
		"loot": [{"item": "Jerky Strip", "min": 1, "max": 2, "chance": 70}]},
	{"name": "Bog Fiend", "predator": true, "slot": 6, "tier": 2, "biomes": ["marsh"],
		"tint": Color(0.75, 0.85, 0.7), "scale": 1.05, "max_hp": 14, "damage": 3,
		"loot": [{"item": "Mandrake Root", "min": 1, "max": 1, "chance": 40}]},
	{"name": "Cave Ghoul", "predator": true, "slot": 6, "tier": 2, "biomes": ["cave"],
		"tint": Color(0.8, 0.85, 0.9), "scale": 1.0, "max_hp": 14, "damage": 3,
		"loot": [{"item": "Old Tome", "min": 1, "max": 1, "chance": 20},
			{"item": "Leather Strap", "min": 1, "max": 1, "chance": 60}]},
	{"name": "Orc Warlord", "predator": true, "slot": 7, "tier": 2, "biomes": ["grass", "forest", "sand"],
		"tint": Color(1, 1, 1), "scale": 1.0, "max_hp": 20, "damage": 4,
		"loot": [{"item": "Leather Strap", "min": 2, "max": 3, "chance": 90},
			{"item": "Gold Nugget", "min": 1, "max": 1, "chance": 35}]},
	{"name": "Highland Troll", "predator": true, "slot": 7, "tier": 2, "biomes": ["grass", "forest"],
		"tint": Color(0.85, 0.95, 0.85), "scale": 1.15, "max_hp": 24, "damage": 4,
		"loot": [{"item": "Stone", "min": 2, "max": 4, "chance": 100}]},
	{"name": "Yeti", "predator": true, "slot": 7, "tier": 2, "biomes": ["snow"],
		"tint": Color(1.1, 1.12, 1.2), "scale": 1.15, "max_hp": 24, "damage": 4,
		"loot": [{"item": "Skein of Wool", "min": 1, "max": 2, "chance": 80},
			{"item": "Frostcap", "min": 1, "max": 1, "chance": 40}]},
	{"name": "Sand Reaver", "predator": true, "slot": 7, "tier": 2, "biomes": ["sand"],
		"tint": Color(1.15, 1.0, 0.75), "scale": 1.1, "max_hp": 22, "damage": 4,
		"loot": [{"item": "Gem Shard", "min": 1, "max": 1, "chance": 40},
			{"item": "Leather Strap", "min": 1, "max": 2, "chance": 70}]},
	{"name": "Deep Troll", "predator": true, "slot": 7, "tier": 2, "biomes": ["cave"],
		"tint": Color(0.8, 0.82, 0.9), "scale": 1.15, "max_hp": 25, "damage": 4,
		"loot": [{"item": "Stone", "min": 2, "max": 4, "chance": 100},
			{"item": "Gem Shard", "min": 1, "max": 1, "chance": 30}]}
]

## Grazing and ground fowl on the farm-animal sheets: the huntable side
## of the wilds. "body" picks the sheet; prey never fight back.
const HERD_SPECIES: Array[Dictionary] = [
	{"name": "Pheasant", "body": "chicken", "biomes": ["grass", "forest"],
		"tint": Color(1.05, 0.85, 0.7), "scale": 1.0, "max_hp": 3,
		"loot": [{"item": "Roast Meat", "min": 1, "max": 1, "chance": 100}]},
	{"name": "Grouse", "body": "chicken", "biomes": ["forest", "grass"],
		"tint": Color(0.85, 0.75, 0.7), "scale": 0.95, "max_hp": 3,
		"loot": [{"item": "Roast Meat", "min": 1, "max": 1, "chance": 100}]},
	{"name": "Ptarmigan", "body": "chicken", "biomes": ["snow"],
		"tint": Color(1.15, 1.15, 1.2), "scale": 0.95, "max_hp": 3,
		"loot": [{"item": "Roast Meat", "min": 1, "max": 1, "chance": 100}]},
	{"name": "Moorfowl", "body": "chicken", "biomes": ["marsh"],
		"tint": Color(0.8, 0.85, 0.95), "scale": 0.95, "max_hp": 3,
		"loot": [{"item": "Roast Meat", "min": 1, "max": 1, "chance": 100}]},
	{"name": "Wild Boar", "body": "pig", "biomes": ["forest", "grass"],
		"tint": Color(0.7, 0.62, 0.58), "scale": 1.05, "max_hp": 8,
		"loot": [{"item": "Marbled Steak", "min": 1, "max": 2, "chance": 100},
			{"item": "Leather Strap", "min": 1, "max": 1, "chance": 60}]},
	{"name": "Peccary", "body": "pig", "biomes": ["sand"],
		"tint": Color(0.85, 0.75, 0.6), "scale": 0.9, "max_hp": 6,
		"loot": [{"item": "Cured Ham", "min": 1, "max": 1, "chance": 100}]},
	{"name": "Tusked Marsh Hog", "body": "pig", "biomes": ["marsh"],
		"tint": Color(0.6, 0.62, 0.55), "scale": 1.1, "max_hp": 9,
		"loot": [{"item": "Marbled Steak", "min": 1, "max": 2, "chance": 100}]},
	{"name": "Aurochs", "body": "cow", "biomes": ["grass"],
		"tint": Color(0.6, 0.5, 0.45), "scale": 1.15, "max_hp": 14,
		"loot": [{"item": "Marbled Steak", "min": 2, "max": 3, "chance": 100},
			{"item": "Leather Strap", "min": 1, "max": 2, "chance": 80}]},
	{"name": "Elk", "body": "cow", "biomes": ["forest", "grass"],
		"tint": Color(0.75, 0.65, 0.55), "scale": 1.05, "max_hp": 11,
		"loot": [{"item": "Marbled Steak", "min": 1, "max": 2, "chance": 100},
			{"item": "Leather Strap", "min": 1, "max": 1, "chance": 70}]},
	{"name": "Yak", "body": "cow", "biomes": ["snow"],
		"tint": Color(0.55, 0.5, 0.5), "scale": 1.1, "max_hp": 13,
		"loot": [{"item": "Skein of Wool", "min": 1, "max": 2, "chance": 100},
			{"item": "Marbled Steak", "min": 1, "max": 2, "chance": 80}]},
	{"name": "Bison", "body": "cow", "biomes": ["grass"],
		"tint": Color(0.5, 0.42, 0.38), "scale": 1.15, "max_hp": 14,
		"loot": [{"item": "Marbled Steak", "min": 2, "max": 3, "chance": 100},
			{"item": "Skein of Wool", "min": 1, "max": 1, "chance": 60}]},
	{"name": "Tundra Reindeer", "body": "cow", "biomes": ["snow"],
		"tint": Color(0.8, 0.78, 0.75), "scale": 1.0, "max_hp": 10,
		"loot": [{"item": "Marbled Steak", "min": 1, "max": 2, "chance": 100},
			{"item": "Leather Strap", "min": 1, "max": 1, "chance": 70}]}
]

## The slot band a danger tier rolls (matches the old tier_def_index).
static func tier_for_slot(slot: int) -> int:
	if slot <= 2:
		return 0
	if slot <= 5:
		return 1
	return 2

## A species for a hostile spawn: filtered to the tier's bodies and the
## biome underfoot; a biome with no specialist falls back to the tier's
## generalists so no ground ever spawns nothing.
static func pick_species(biome: String, tier: int, rng: RandomNumberGenerator) -> Dictionary:
	var matches: Array[Dictionary] = []
	var fallback: Array[Dictionary] = []
	for species: Dictionary in SPECIES:
		if int(species.get("tier", 0)) != tier:
			continue
		fallback.append(species)
		if (species.get("biomes", []) as Array).has(biome):
			matches.append(species)
	var pool := matches if not matches.is_empty() else fallback
	if pool.is_empty():
		return {}
	return pool[rng.randi_range(0, pool.size() - 1)]

## A cave species wearing the given body slot, for the underhall spawns
## that already picked their slot from the stratum's cast.
static func cave_species_for_slot(slot: int, rng: RandomNumberGenerator) -> Dictionary:
	var matches: Array[Dictionary] = []
	var fallback: Array[Dictionary] = []
	for species: Dictionary in SPECIES:
		if int(species.get("slot", -1)) != slot:
			continue
		fallback.append(species)
		if (species.get("biomes", []) as Array).has("cave"):
			matches.append(species)
	var pool := matches if not matches.is_empty() else fallback
	if pool.is_empty():
		return {}
	return pool[rng.randi_range(0, pool.size() - 1)]

## A grazer for the biome, or {} where nothing ranges (bare rock).
static func pick_herd_species(biome: String, rng: RandomNumberGenerator) -> Dictionary:
	var matches: Array[Dictionary] = []
	for species: Dictionary in HERD_SPECIES:
		if (species.get("biomes", []) as Array).has(biome):
			matches.append(species)
	if matches.is_empty():
		return {}
	return matches[rng.randi_range(0, matches.size() - 1)]

## Dresses a spawned creature state in its species: name, stats and loot
## overrides on the state, tint and size on the sprite. The base def's
## body (sprite row, animation) is untouched.
static func apply_species(state: Dictionary, species: Dictionary) -> void:
	if species.is_empty():
		return
	state["species_name"] = String(species.get("name", ""))
	if bool(species.get("predator", false)):
		state["predator"] = true
	if species.has("max_hp"):
		state["hp"] = int(species.get("max_hp", 8))
	if species.has("damage"):
		state["damage_override"] = int(species.get("damage", 2))
	if species.has("speed"):
		state["speed_override"] = float(species.get("speed", 70.0))
	if species.has("aggro_range"):
		state["aggro_override"] = int(species.get("aggro_range", 7))
	if species.has("loot"):
		state["loot_override"] = species.get("loot")
	var sprite := state.get("sprite") as Sprite2D
	if sprite != null and is_instance_valid(sprite):
		sprite.modulate = species.get("tint", Color.WHITE) as Color
		sprite.scale *= float(species.get("scale", 1.0))
