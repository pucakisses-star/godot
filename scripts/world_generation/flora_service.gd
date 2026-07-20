extends RefCounted
class_name FloraService

## Real-botany flora layered over the world's plant tiles: every stamped
## tree, flower patch, mushroom ring, reed bed and cactus belongs to a
## SPECIES, chosen deterministically per cell from the tile's own list -
## fell an oak or a rowan, gather chanterelles or foxglove, and the same
## cell always grows the same plant. Gatherable species pay real pantry
## and apothecary items; the rest are named scenery.

## Tree species per tree tile. "bonus" drops beside the timber.
const TREE_SPECIES := {
	"tree": [
		{"name": "Oak", "weight": 14}, {"name": "Beech", "weight": 10},
		{"name": "Ash", "weight": 9}, {"name": "Elm", "weight": 7},
		{"name": "Field Maple", "weight": 7}, {"name": "Silver Birch", "weight": 10},
		{"name": "Rowan", "weight": 6, "bonus": {"item": "Rowanberries", "min": 1, "max": 2}},
		{"name": "Hawthorn", "weight": 6}, {"name": "Hazel", "weight": 6},
		{"name": "Linden", "weight": 5}, {"name": "Aspen", "weight": 6},
		{"name": "Sycamore", "weight": 5}, {"name": "Wild Apple", "weight": 4},
		{"name": "Willow", "weight": 5}, {"name": "Black Alder", "weight": 5}
	],
	"tree_dark": [
		{"name": "Scots Pine", "weight": 13}, {"name": "Norway Spruce", "weight": 12},
		{"name": "Silver Fir", "weight": 9}, {"name": "Larch", "weight": 8},
		{"name": "Yew", "weight": 4}, {"name": "Juniper", "weight": 5},
		{"name": "Cedar", "weight": 5}, {"name": "Hemlock", "weight": 5},
		{"name": "Black Pine", "weight": 6}, {"name": "Holly", "weight": 4},
		{"name": "Douglas Fir", "weight": 6}, {"name": "Stone Pine", "weight": 4}
	],
	"tree_snowy": [
		{"name": "Snowbound Birch", "weight": 10}, {"name": "Snowbound Rowan", "weight": 5,
			"bonus": {"item": "Rowanberries", "min": 1, "max": 1}},
		{"name": "Snowbound Aspen", "weight": 7}, {"name": "Dwarf Willow", "weight": 6}
	],
	"tree_dark_snowy": [
		{"name": "Snowbound Spruce", "weight": 12}, {"name": "Snowbound Fir", "weight": 9},
		{"name": "Snowbound Pine", "weight": 9}, {"name": "Snowbound Larch", "weight": 7}
	],
	"cactus": [
		{"name": "Saguaro", "weight": 10}, {"name": "Cardón", "weight": 6},
		{"name": "Organ Pipe Cactus", "weight": 6}, {"name": "Joshua Tree", "weight": 5}
	],
	"cactus_small": [
		{"name": "Barrel Cactus", "weight": 10}, {"name": "Prickly Pear", "weight": 8},
		{"name": "Cholla", "weight": 6}, {"name": "Agave", "weight": 6},
		{"name": "Century Plant", "weight": 3}
	]
}

## Gatherable and scenery ground flora per decor tile. Entries with an
## "item" can be foraged; the rest are named wildflowers.
const GROUND_FLORA := {
	"flowers_white": [
		{"name": "Wild Garlic", "weight": 8, "item": "Garlic Sprout", "min": 1, "max": 2},
		{"name": "Chamomile", "weight": 8}, {"name": "Oxeye Daisy", "weight": 10},
		{"name": "Yarrow", "weight": 8},
		{"name": "Snowdrop", "weight": 5}, {"name": "Wood Anemone", "weight": 6},
		{"name": "Meadowsweet", "weight": 6}
	],
	"flowers_yellow": [
		{"name": "Dandelion", "weight": 12}, {"name": "Buttercup", "weight": 10},
		{"name": "St John's Wort", "weight": 6}, {"name": "Gorse", "weight": 6},
		{"name": "Firebloom", "weight": 4, "item": "Firebloom", "min": 1, "max": 1},
		{"name": "Kingcup", "weight": 6}
	],
	"flowers_pink": [
		{"name": "Foxglove", "weight": 7, "item": "Foxglove Sprig", "min": 1, "max": 1},
		{"name": "Heather", "weight": 10}, {"name": "Red Campion", "weight": 8},
		{"name": "Poppy", "weight": 8},
		{"name": "Nightcap Bells", "weight": 4, "item": "Nightcap Bells", "min": 1, "max": 1}
	],
	"flowers_pink_alt": [
		{"name": "Violet Veil", "weight": 5, "item": "Violet Veil", "min": 1, "max": 1},
		{"name": "Thistle", "weight": 9}, {"name": "Knapweed", "weight": 7},
		{"name": "Mandrake", "weight": 2, "item": "Mandrake Root", "min": 1, "max": 1},
		{"name": "Bee Orchid", "weight": 4}
	],
	"reeds": [
		{"name": "Common Reed", "weight": 12}, {"name": "Cattail", "weight": 9},
		{"name": "Bulrush", "weight": 7}, {"name": "Sweet Flag", "weight": 5}
	],
	"reeds_alt": [
		{"name": "Sedge", "weight": 10}, {"name": "Rush", "weight": 8},
		{"name": "Reed Canary-grass", "weight": 6}
	],
	"lily_flower": [
		{"name": "White Water-Lily", "weight": 10}, {"name": "Yellow Pond-Lily", "weight": 7},
		{"name": "Frogbit", "weight": 5}
	]
}

## Fungus species: the surface ring and the cave-adapted deep kinds the
## underhall fungus patches grow. All gatherable.
const SURFACE_FUNGI: Array[Dictionary] = [
	{"name": "Chanterelle", "weight": 9, "item": "Chanterelle", "min": 1, "max": 2},
	{"name": "Porcini", "weight": 8, "item": "Porcini", "min": 1, "max": 2},
	{"name": "King Bolete", "weight": 6, "item": "King Bolete", "min": 1, "max": 1},
	{"name": "Black Morel", "weight": 5, "item": "Black Morel", "min": 1, "max": 1},
	{"name": "Field Mushroom", "weight": 12, "item": "Mushrooms", "min": 1, "max": 3},
	{"name": "Fly Agaric", "weight": 6, "item": "Spore Dust", "min": 1, "max": 1},
	{"name": "Puffball", "weight": 7, "item": "Mushrooms", "min": 1, "max": 2},
	{"name": "Shaggy Inkcap", "weight": 6, "item": "Mushrooms", "min": 1, "max": 2}
]
const CAVE_FUNGI: Array[Dictionary] = [
	{"name": "Glowcap", "weight": 10, "item": "Glowcap", "min": 1, "max": 2},
	{"name": "Cave Polypore", "weight": 9, "item": "Mushrooms", "min": 1, "max": 2},
	{"name": "Frostcap", "weight": 5, "item": "Frostcap", "min": 1, "max": 1},
	{"name": "Witchcap", "weight": 6, "item": "Spore Dust", "min": 1, "max": 2},
	{"name": "Dwarven Buttons", "weight": 9, "item": "Mushrooms", "min": 1, "max": 3},
	{"name": "Veinmoss Bracket", "weight": 5, "item": "Glowcap", "min": 1, "max": 1}
]

const FORAGE_TILE_KEYS := ["flowers_white", "flowers_yellow", "flowers_pink", "flowers_pink_alt",
	"reeds", "reeds_alt", "lily_flower", "mushroom_wild", "mushroom_crop_wild"]

static func _hash01(cell: Vector2i, seed_value: int, salt: int) -> float:
	var h: int = cell.x * 374761393 + cell.y * 668265263 + (seed_value + salt) * 2654435761
	h = int((h ^ (h >> 13)) * 1274126177)
	h = h ^ (h >> 16)
	return float(h & 0xffffffff) / 4294967295.0

static func _pick_weighted(pool: Array, roll01: float) -> Dictionary:
	var total := 0
	for entry_variant: Variant in pool:
		total += int((entry_variant as Dictionary).get("weight", 1))
	if total <= 0:
		return {}
	var roll := int(roll01 * float(total)) % total
	var running := 0
	for entry_variant: Variant in pool:
		var entry := entry_variant as Dictionary
		running += int(entry.get("weight", 1))
		if roll < running:
			return entry
	return pool[0] as Dictionary

## The tree species growing at this cell - stable per cell and world.
static func tree_species_at(tile_key: String, cell: Vector2i, seed_value: int) -> Dictionary:
	var pool := TREE_SPECIES.get(tile_key, []) as Array
	if pool.is_empty():
		return {}
	return _pick_weighted(pool, _hash01(cell, seed_value, 0x71EE))

## The ground flora species at this cell. Fungus tiles draw from the
## surface or cave ring by context; everything else from its tile list.
static func flora_species_at(tile_key: String, cell: Vector2i, seed_value: int, underground: bool) -> Dictionary:
	var pool: Array = []
	if tile_key == "mushroom_wild" or tile_key == "mushroom_crop_wild":
		pool = CAVE_FUNGI if underground else SURFACE_FUNGI
	else:
		pool = GROUND_FLORA.get(tile_key, []) as Array
	if pool.is_empty():
		return {}
	return _pick_weighted(pool, _hash01(cell, seed_value, 0xF10A))
