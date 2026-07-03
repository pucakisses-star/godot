extends RefCounted
class_name UndergroundCreatureService

## Hostile creatures of the wild underdeep. Pure data + rolls; the scene
## owns sprites and the update loop. Slots index into
## creature_characters.png, repacked from the web game's mob tilesheets
## (Fungi, Lizardmen, Orcs) into the same 12x8 layout as the NPC sheets.
## Danger scales with distance from the hold: min_distance gates when a
## creature enters the spawn pool, so the far dark grows nastier.

const CREATURE_DEFS: Array[Dictionary] = [
	{
		"name": "Sporeling", "slot": 0, "max_hp": 4, "damage": 1,
		"speed": 55.0, "aggro_range": 6, "attack_cooldown": 1.4,
		"min_distance": 0, "weight": 10,
		"loot": [
			{"item": "Mushrooms", "min": 1, "max": 2, "chance": 100},
			{"item": "Spore Dust", "min": 1, "max": 1, "chance": 50}
		]
	},
	{
		"name": "Crimson Sporecap", "slot": 1, "max_hp": 7, "damage": 2,
		"speed": 70.0, "aggro_range": 7, "attack_cooldown": 1.3,
		"min_distance": 25, "weight": 7,
		"loot": [
			{"item": "Spore Dust", "min": 1, "max": 2, "chance": 100},
			{"item": "Mushrooms", "min": 1, "max": 1, "chance": 60}
		]
	},
	{
		"name": "Elder Myconid", "slot": 2, "max_hp": 10, "damage": 2,
		"speed": 50.0, "aggro_range": 6, "attack_cooldown": 1.5,
		"min_distance": 55, "weight": 5,
		"loot": [
			{"item": "Spore Dust", "min": 2, "max": 3, "chance": 100},
			{"item": "Glowcap", "min": 1, "max": 1, "chance": 40}
		]
	},
	{
		"name": "Lizardman Skirmisher", "slot": 3, "max_hp": 8, "damage": 2,
		"speed": 100.0, "aggro_range": 9, "attack_cooldown": 1.2,
		"min_distance": 40, "weight": 7,
		"loot": [{"item": "Lizard Scale", "min": 1, "max": 2, "chance": 100}]
	},
	{
		"name": "Lizardman Stalker", "slot": 4, "max_hp": 11, "damage": 3,
		"speed": 105.0, "aggro_range": 10, "attack_cooldown": 1.2,
		"min_distance": 80, "weight": 5,
		"loot": [
			{"item": "Lizard Scale", "min": 1, "max": 2, "chance": 100},
			{"item": "Iron Ore", "min": 1, "max": 1, "chance": 40}
		]
	},
	{
		"name": "Lizardman Chieftain", "slot": 5, "max_hp": 15, "damage": 3,
		"speed": 95.0, "aggro_range": 10, "attack_cooldown": 1.3,
		"min_distance": 130, "weight": 4,
		"loot": [
			{"item": "Lizard Scale", "min": 2, "max": 3, "chance": 100},
			{"item": "Gold Trinket", "min": 1, "max": 1, "chance": 50}
		]
	},
	{
		"name": "Orc Raider", "slot": 6, "max_hp": 13, "damage": 3,
		"speed": 85.0, "aggro_range": 9, "attack_cooldown": 1.4,
		"min_distance": 90, "weight": 5,
		"loot": [
			{"item": "Orcish Tooth", "min": 1, "max": 2, "chance": 100},
			{"item": "Stone", "min": 1, "max": 2, "chance": 50}
		]
	},
	{
		"name": "Orc Warlord", "slot": 7, "max_hp": 20, "damage": 4,
		"speed": 75.0, "aggro_range": 9, "attack_cooldown": 1.6,
		"min_distance": 150, "weight": 4,
		"loot": [
			{"item": "Orcish Tooth", "min": 2, "max": 3, "chance": 100},
			{"item": "Iron Ore", "min": 1, "max": 2, "chance": 60}
		]
	}
]

## Picks a creature for a spawn point, weighted among everything whose
## danger gate the distance has passed.
static func pick_definition_index(distance_from_city: float, rng: RandomNumberGenerator) -> int:
	var total_weight := 0
	for def: Dictionary in CREATURE_DEFS:
		if distance_from_city >= float(int(def.get("min_distance", 0))):
			total_weight += int(def.get("weight", 1))
	if total_weight <= 0:
		return 0
	var roll := rng.randi_range(1, total_weight)
	for def_index in range(CREATURE_DEFS.size()):
		var def := CREATURE_DEFS[def_index]
		if distance_from_city < float(int(def.get("min_distance", 0))):
			continue
		roll -= int(def.get("weight", 1))
		if roll <= 0:
			return def_index
	return 0

static func roll_loot(def: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var loot: Dictionary = {}
	for entry_variant: Variant in (def.get("loot", []) as Array):
		var entry := entry_variant as Dictionary
		if rng.randi_range(1, 100) > int(entry.get("chance", 100)):
			continue
		var amount := rng.randi_range(int(entry.get("min", 1)), int(entry.get("max", 1)))
		if amount > 0:
			var item := String(entry.get("item", ""))
			loot[item] = int(loot.get(item, 0)) + amount
	return loot

## Deterministic per-chunk ambush rolls: which freshly streamed wild cells
## start with a creature on them. Returns [{"cell", "def_index"}].
static func roll_chunk_spawns(grid: Dictionary, district_cell_map: Dictionary, chunk_rect: Rect2i, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var spawns: Array[Dictionary] = []
	var spawn_count := rng.randi_range(0, 2)
	if spawn_count <= 0:
		return spawns
	for _attempt in range(spawn_count * 6):
		if spawns.size() >= spawn_count:
			break
		var cell := Vector2i(
			rng.randi_range(chunk_rect.position.x, chunk_rect.end.x - 1),
			rng.randi_range(chunk_rect.position.y, chunk_rect.end.y - 1)
		)
		if int(grid.get(cell, 0)) != 1:
			continue
		if district_cell_map.has(cell):
			continue
		var distance := Vector2(cell).length()
		spawns.append({"cell": cell, "def_index": pick_definition_index(distance, rng)})
	return spawns
