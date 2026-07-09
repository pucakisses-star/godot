extends RefCounted

const ATLAS_TEXTURE := "res://resources/images/overworld/atlas/overworld.png"
# Rivers use their own sheet: RIVER_TILES coordinates index into the
# world-map details tilesheet (16px tiles), not the overworld atlas.
const RIVER_ATLAS_TEXTURE := "res://resources/images/overworld/atlas/world_map_details.png"
const RIVER_ATLAS_TILE_SIZE := 16
const SAND_TILE := Vector2i(0, 0)
const GRASS_TILE := Vector2i(1, 0)
const BADLANDS_TILE := Vector2i(2, 1)
# Mines read as the dark arch entrance, shared with the dwarf homestead art.
const MINE_TILE := Vector2i(3, 1)
const MARSH_TILE := Vector2i(2, 4)
const SNOW_TILE := Vector2i(3, 2)
const TREE_TILE := Vector2i(0, 1)
const TREE_LONE_TILE := Vector2i(6, 5)
const JUNGLE_TREE_TILE := Vector2i(0, 3)
const CUT_TREES_TILE := Vector2i(1, 6)
const AMBIENT_LUMBER_MILL_TILE := Vector2i(0, 6)
const WATER_TILE := Vector2i(4, 1)
const RIVER_TILES := {
	"RIVER_NS": Vector2i(0, 4),
	"RIVER_WE": Vector2i(1, 4),
	"RIVER_SE": Vector2i(2, 4),
	"RIVER_SW": Vector2i(3, 4),
	"RIVER_NE": Vector2i(4, 4),
	"RIVER_NW": Vector2i(5, 4),
	"RIVER_NSE": Vector2i(6, 4),
	"RIVER_SWE": Vector2i(7, 4),
	"RIVER_NWE": Vector2i(8, 4),
	"RIVER_NSW": Vector2i(9, 4),
	"RIVER_NSWE": Vector2i(10, 4),
	"RIVER_0": Vector2i(11, 4),
	"RIVER_N": Vector2i(12, 4),
	"RIVER_S": Vector2i(13, 4),
	"RIVER_W": Vector2i(14, 4),
	"RIVER_E": Vector2i(15, 4),
	"RIVER_MAJOR_NS": Vector2i(0, 5),
	"RIVER_MAJOR_WE": Vector2i(1, 5),
	"RIVER_MAJOR_SE": Vector2i(2, 5),
	"RIVER_MAJOR_SW": Vector2i(3, 5),
	"RIVER_MAJOR_NE": Vector2i(4, 5),
	"RIVER_MAJOR_NW": Vector2i(5, 5),
	"RIVER_MAJOR_NSE": Vector2i(6, 5),
	"RIVER_MAJOR_SWE": Vector2i(7, 5),
	"RIVER_MAJOR_NWE": Vector2i(8, 5),
	"RIVER_MAJOR_NSW": Vector2i(9, 5),
	"RIVER_MAJOR_NSWE": Vector2i(10, 5),
	"RIVER_MAJOR_0": Vector2i(11, 5),
	"RIVER_MAJOR_N": Vector2i(12, 5),
	"RIVER_MAJOR_S": Vector2i(13, 5),
	"RIVER_MAJOR_W": Vector2i(14, 5),
	"RIVER_MAJOR_E": Vector2i(15, 5),
	"RIVER_MOUTH_NARROW_N": Vector2i(12, 7),
	"RIVER_MOUTH_NARROW_S": Vector2i(13, 7),
	"RIVER_MOUTH_NARROW_W": Vector2i(14, 7),
	"RIVER_MOUTH_NARROW_E": Vector2i(15, 7),
	"RIVER_MAJOR_MOUTH_NARROW_N": Vector2i(12, 8),
	"RIVER_MAJOR_MOUTH_NARROW_S": Vector2i(13, 8),
	"RIVER_MAJOR_MOUTH_NARROW_W": Vector2i(14, 8),
	"RIVER_MAJOR_MOUTH_NARROW_E": Vector2i(15, 8)
}
const MOUNTAIN_TILE := Vector2i(3, 0)
const MOUNTAIN_TOP_A_TILE := Vector2i(4, 0)
const MOUNTAIN_TOP_B_TILE := Vector2i(5, 0)
const MOUNTAIN_BOTTOM_A_TILE := Vector2i(7, 0)
const MOUNTAIN_BOTTOM_B_TILE := Vector2i(8, 0)
const DAM_TILE := Vector2i(8, 1)
const MOUNTAIN_PEAK_TILE := Vector2i(10, 0)
## A lone craggy peak, distinct from the tiled mountain-block art above.
const MOUNTAIN_ALT_TILE := Vector2i(9, 0)
## Faith buildings: a small chapel, a domed temple, and a grand cathedral.
const CHAPEL_TILE := Vector2i(10, 1)
const DOMED_TEMPLE_TILE := Vector2i(9, 1)
const GRAND_CATHEDRAL_TILE := Vector2i(11, 0)
const STONE_TILE := Vector2i(2, 0)
const DWARFHOLD_TILE := Vector2i(9, 2)
const ABANDONED_DWARFHOLD_TILE := Vector2i(8, 2)
const GREAT_DWARFHOLD_TILE := Vector2i(6, 0)
const DARK_DWARFHOLD_TILE := Vector2i(17, 0)
const HILLHOLD_TILE := Vector2i(7, 4)
# Caves read as a rugged rock cave mouth (distinct from the dungeon at
# (7,2)); the old (5,1) green mound looked like a shrub, not a cave.
const CAVE_TILE := Vector2i(8, 2)
const TOWER_TILE := Vector2i(6, 1)
const EVIL_WIZARDS_TOWER_TILE := Vector2i(3, 3)
const WOOD_ELF_GROVES_TILE := Vector2i(4, 2)
const WOOD_ELF_GROVES_LARGE_TILE := Vector2i(5, 2)
const WOOD_ELF_GROVES_GRAND_TILE := Vector2i(6, 2)
const HILLS_TILE := Vector2i(1, 3)
const HILLS_BADLANDS_TILE := Vector2i(1, 4)
const HILLS_VARIANT_A_TILE := Vector2i(4, 4)
const HILLS_VARIANT_B_TILE := Vector2i(2, 5)
const HILLS_SNOW_TILE := Vector2i(2, 3)
const TOWN_TILE := Vector2i(1, 2)
const PORT_TOWN_TILE := Vector2i(5, 4)
const CASTLE_TILE := Vector2i(6, 4)
const ROADSIDE_TAVERN_TILE := Vector2i(12, 1)
const HAMLET_TILE := Vector2i(16, 1)
const TREE_SNOW_TILE := Vector2i(1, 1)
const ACTIVE_VOLCANO_TILE := Vector2i(12, 2)
const VOLCANO_TILE := Vector2i(13, 2)
const LAVA_TILE := Vector2i(14, 2)
const OASIS_TILE := Vector2i(12, 0)
const HAMLET_SNOW_TILE := Vector2i(13, 0)
const AMBIENT_SLEEPING_DRAGON_TILE := Vector2i(14, 0)
const AMBIENT_HUNTING_LODGE_TILE := Vector2i(16, 0)
const AMBIENT_HOMESTEAD_TILE := Vector2i(13, 1)
const AMBIENT_MOONWELL_TILE := Vector2i(2, 6)
const AMBIENT_FARM_TILE := Vector2i(15, 1)
const FARM_CROPS_TILE := Vector2i(15, 0)
const AMBIENT_FARM_VARIANT_TILE := Vector2i(16, 2)
const AMBIENT_GREAT_TREE_TILE := Vector2i(14, 1)
const AMBIENT_GREAT_TREE_ALT_TILE := Vector2i(15, 2)
const LIZARDMEN_CITY_TILE := Vector2i(11, 2)
const SAINT_SHRINE_TILE := Vector2i(11, 1)
const MONASTERY_TILE := Vector2i(2, 2)
# Camp tiles point at the atlas's actual tent art. The old coords (9,0),
# (11,0), (9,1), (10,1), (7,1) hold mountains and settlement buildings, so
# camps were rendering as peaks/cathedrals/keeps. Real tent art lives at
# (11,3) war-camp tents, (15,2) raider teepee, (1,5) nomad tents.
const ORC_CAMP_TILE := Vector2i(11, 3)
const GNOLL_CAMP_TILE := Vector2i(15, 2)
const TROLL_CAMP_TILE := Vector2i(11, 3)
const OGRE_CAMP_TILE := Vector2i(11, 3)
const BANDIT_CAMP_TILE := Vector2i(15, 2)
const TRAVELERS_CAMP_TILE := Vector2i(1, 5)
const DUNGEON_TILE := Vector2i(7, 2)
const CENTAUR_ENCAMPMENT_TILE := Vector2i(10, 2)

## Winding dirt-road segments (row 5 of the atlas), bucketed by which
## edges the trail leaves through. Organic art, so buckets hold variants.
const ROAD_TILES := {
	"ns": [Vector2i(7, 5), Vector2i(14, 5), Vector2i(16, 5)],
	"we": [Vector2i(13, 5), Vector2i(15, 5), Vector2i(11, 5), Vector2i(21, 5)],
	"corner_se": [Vector2i(10, 5)],
	"corner_sw": [Vector2i(8, 5)],
	"corner_ne": [Vector2i(9, 5)],
	"corner_nw": [Vector2i(20, 5)],
	"junction": [Vector2i(12, 5), Vector2i(17, 5)],
	"stub": [Vector2i(18, 5), Vector2i(19, 5)]
}

## The desert city set: golden palace, sandstone walls and gate, hut,
## serpent statue, and desert vegetation.
const DESERT_CITY_TILE := Vector2i(8, 3)
const DESERT_SERPENT_STATUE_TILE := Vector2i(9, 3)
const DESERT_WALL_A_TILE := Vector2i(6, 6)
const DESERT_WALL_B_TILE := Vector2i(7, 6)
const DESERT_GATE_TILE := Vector2i(8, 6)
const DESERT_HUT_TILE := Vector2i(9, 6)
const DESERT_PALMS_TILE := Vector2i(7, 3)
const DESERT_CACTI_TILE := Vector2i(10, 3)

const PIRATE_SHIP_TILE := Vector2i(6, 3)
const EVIL_KEEP_TILE := Vector2i(18, 1)
const DARK_GATE_TILE := Vector2i(17, 1)
const DARK_SPIRE_TILE := Vector2i(17, 2)
const GREEN_DRAGON_TILE := Vector2i(18, 0)
const OLD_GROWTH_TILE := Vector2i(0, 2)
const WATCHTOWER_TILE := Vector2i(3, 4)
const HERMIT_HUT_TILE := Vector2i(0, 4)
const TENT_CAMP_TILE := Vector2i(1, 5)
const FARMHOUSE_TILE := Vector2i(4, 5)
const STONE_CAIRN_TILE := Vector2i(5, 6)
const WAR_PYRE_TILE := Vector2i(13, 3)

const BIOME_WATER := "water"
const BIOME_MOUNTAIN := "mountain"
const BIOME_HILLS := "hills"
const BIOME_MARSH := "marsh"
const BIOME_TUNDRA := "tundra"
const BIOME_DESERT := "desert"
const BIOME_BADLANDS := "badlands"
const BIOME_FOREST := "forest"
const BIOME_JUNGLE := "jungle"
const BIOME_GRASSLAND := "grassland"

## The wire format for the town-scene world biome buffer: one byte per
## overworld tile, indexing this order. Grassland sits at 0 so an unknown
## or zero byte decodes to a safe land default. Both the overworld (writer)
## and the surface service (reader) go through biome_code/biome_label so
## the two sides agree without sharing the map's internal id tables.
const BIOME_ORDER: Array[String] = [
	BIOME_GRASSLAND, BIOME_WATER, BIOME_MOUNTAIN, BIOME_HILLS, BIOME_MARSH,
	BIOME_TUNDRA, BIOME_DESERT, BIOME_BADLANDS, BIOME_FOREST, BIOME_JUNGLE
]

static func biome_code(label: String) -> int:
	var code := BIOME_ORDER.find(label)
	return code if code >= 0 else 0

static func biome_label(code: int) -> String:
	if code < 0 or code >= BIOME_ORDER.size():
		return BIOME_GRASSLAND
	return BIOME_ORDER[code]

const TREE_BIOMES: Array[String] = [BIOME_FOREST, BIOME_JUNGLE, BIOME_TUNDRA]
const TREE_BASE_BIOMES: Array[String] = [BIOME_GRASSLAND, BIOME_TUNDRA]
const TREE_VARIANT_FOREST_LONE := "forest_lone"
const TREE_VARIANT_TUNDRA_LONE := "tundra_lone"

const DWARFHOLD_TILE_ATLAS := {
	"dirt": Vector2i(0, 2),
	"workbench": Vector2i(0, 3),
	"shelf": Vector2i(0, 4),
	"winepress": Vector2i(0, 5),
	"grain_bag": Vector2i(0, 6),
	"stairway_up": Vector2i(0, 7),
	"wall_right": Vector2i(1, 1),
	"bed": Vector2i(1, 3),
	"butcher_table": Vector2i(1, 4),
	"chest": Vector2i(1, 5),
	"flour": Vector2i(1, 6),
	"sign": Vector2i(1, 7),
	"stone": Vector2i(2, 1),
	"wall_top": Vector2i(2, 2),
	"wall_bottom": Vector2i(2, 0),
	"mushroom_crops": Vector2i(2, 3),
	"wardrobe": Vector2i(2, 5),
	"floor": Vector2i(2, 6),
	"armor_stand": Vector2i(2, 7),
	"wall_left": Vector2i(3, 1),
	"table": Vector2i(3, 3),
	"mug": Vector2i(3, 4),
	"mushroom_crop_wild": Vector2i(3, 5),
	"water_bucket": Vector2i(3, 6),
	"stool": Vector2i(4, 2),
	"table_alt": Vector2i(5, 2),
	"door": Vector2i(4, 3),
	"desk": Vector2i(4, 4),
	"mushroom_wild": Vector2i(4, 5),
	"keg": Vector2i(5, 5),
	"target": Vector2i(6, 3),
	"anvil": Vector2i(6, 4),
	"stairway_down": Vector2i(6, 7),
	"water": Vector2i(6, 0)
}
const DWARFHOLD_PASSABLE_TILE_KEYS := ["floor", "dirt", "door", "stairway_up", "stairway_down"]

## Above-ground human town interiors. Coordinates index the 32px grid of
## resources/images/town/town_tileset.png (a 2x upscale of the village
## interior sheet so it matches the rest of the game's 32px tiles).
const TOWN_TILE_ATLAS_TEXTURE := "res://resources/images/town/town_tileset.png"
## Town tiles whose art spans multiple atlas cells (the full trees):
## created as one atlas tile of the given size and drawn offset so the
## TRUNK cell - the bottom-middle of the region - is the map cell. The
## single-quadrant stamps these replace looked like broken tree strips.
const TOWN_MULTI_CELL_TILES := {
	Vector2i(0, 16): {"size": Vector2i(3, 2), "origin": Vector2i(0, -16)},
	Vector2i(0, 18): {"size": Vector2i(3, 3), "origin": Vector2i(0, -32)}
}

const TOWN_TILE_ATLAS := {
	"grass": Vector2i(1, 1),
	"grass_dark": Vector2i(5, 1),
	"grass_tuft": Vector2i(2, 3),
	"flowers_white": Vector2i(4, 17),
	"flowers_yellow": Vector2i(5, 18),
	"road": Vector2i(14, 4),
	"road_twig": Vector2i(13, 4),
	"sand": Vector2i(11, 4),
	"sand_alt": Vector2i(9, 4),
	"sand_pebbles": Vector2i(12, 3),
	"plaza": Vector2i(17, 2),
	"plaza_alt": Vector2i(18, 3),
	"wall": Vector2i(1, 7),
	"wall_alt": Vector2i(2, 7),
	"plank_wall": Vector2i(25, 0),
	"floor": Vector2i(25, 1),
	"door": Vector2i(26, 1),
	"rug": Vector2i(33, 2),
	"fence": Vector2i(10, 8),
	"fence_post": Vector2i(9, 8),
	"hedge": Vector2i(15, 7),
	"hedge_alt": Vector2i(16, 7),
	"tree": Vector2i(0, 16),
	"tree_dark": Vector2i(0, 18),
	"bed": Vector2i(28, 22),
	"bed_top": Vector2i(28, 21),
	"bed_alt": Vector2i(31, 22),
	"bed_alt_top": Vector2i(31, 21),
	"chest": Vector2i(31, 17),
	"wardrobe": Vector2i(25, 18),
	"wardrobe_top": Vector2i(25, 17),
	"dresser": Vector2i(21, 18),
	"dresser_top": Vector2i(21, 17),
	"shelf": Vector2i(27, 18),
	"shelf_top": Vector2i(27, 17),
	"table": Vector2i(3, 11),
	"bench": Vector2i(0, 11),
	"counter": Vector2i(16, 11),
	"stall": Vector2i(3, 13),
	"stall_alt": Vector2i(4, 13),
	"barrel": Vector2i(12, 17),
	"barrel_open": Vector2i(13, 17),
	"pot": Vector2i(23, 20),
	"jug": Vector2i(12, 15),
	"sack": Vector2i(12, 14),
	"bucket": Vector2i(13, 19),
	"plant": Vector2i(24, 20),
	"plant_tall": Vector2i(26, 20),
	"flowers_pot": Vector2i(28, 20),
	"brazier": Vector2i(21, 20),
	"armor_stand": Vector2i(16, 19),
	"forge": Vector2i(20, 22),
	"forge_top": Vector2i(20, 21),
	"oven": Vector2i(23, 22),
	"oven_top": Vector2i(23, 21),
	# Row 23 additions: open water, worked earth, and the three field
	# crops (three growth stages each, lifted from the Farm plants sheet).
	"water": Vector2i(0, 23),
	"water_calm": Vector2i(1, 23),
	"tilled_soil": Vector2i(2, 23),
	"crop_carrot_0": Vector2i(3, 23),
	"crop_carrot_1": Vector2i(4, 23),
	"crop_carrot_2": Vector2i(5, 23),
	"crop_beetroot_0": Vector2i(6, 23),
	"crop_beetroot_1": Vector2i(7, 23),
	"crop_beetroot_2": Vector2i(8, 23),
	"crop_tomato_0": Vector2i(9, 23),
	"crop_tomato_1": Vector2i(10, 23),
	"crop_tomato_2": Vector2i(11, 23)
}
## The *_top keys are the upper halves of two-tile-tall furniture sprites.
## They render as visual caps over the cell above the furniture, so they
## stay passable — the blocking cell is the furniture base itself.
const TOWN_PASSABLE_TILE_KEYS := [
	"grass", "grass_dark", "grass_tuft", "flowers_white", "flowers_yellow",
	"road", "road_twig", "sand", "sand_alt", "sand_pebbles",
	"plaza", "plaza_alt", "floor", "door", "rug",
	"bed_top", "bed_alt_top", "wardrobe_top", "dresser_top", "shelf_top",
	"forge_top", "oven_top",
	# Water is deliberately absent: it blocks walkers unless they boat.
	"tilled_soil",
	"crop_carrot_0", "crop_carrot_1", "crop_carrot_2",
	"crop_beetroot_0", "crop_beetroot_1", "crop_beetroot_2",
	"crop_tomato_0", "crop_tomato_1", "crop_tomato_2"
]

static func validate_atlas_no_duplicates(atlas_name: String, atlas: Dictionary) -> bool:
	var seen: Dictionary = {}
	var valid := true
	for key: String in atlas.keys():
		var coords: Vector2i = atlas[key]
		if seen.has(coords):
			push_warning("Atlas '%s': duplicate coordinate %s shared by '%s' and '%s'" % [atlas_name, coords, seen[coords], key])
			valid = false
		else:
			seen[coords] = key
	return valid

static func validate_all_atlases() -> bool:
	var valid := true
	if not validate_atlas_no_duplicates("DWARFHOLD_TILE_ATLAS", DWARFHOLD_TILE_ATLAS):
		valid = false
	if not validate_atlas_no_duplicates("TOWN_TILE_ATLAS", TOWN_TILE_ATLAS):
		valid = false
	var overworld_atlas: Dictionary = {
		"SAND_TILE": SAND_TILE, "GRASS_TILE": GRASS_TILE, "BADLANDS_TILE": BADLANDS_TILE,
		"MINE_TILE": MINE_TILE, "MARSH_TILE": MARSH_TILE, "SNOW_TILE": SNOW_TILE,
		"TREE_TILE": TREE_TILE, "TREE_LONE_TILE": TREE_LONE_TILE,
		"JUNGLE_TREE_TILE": JUNGLE_TREE_TILE, "CUT_TREES_TILE": CUT_TREES_TILE,
		"AMBIENT_LUMBER_MILL_TILE": AMBIENT_LUMBER_MILL_TILE, "WATER_TILE": WATER_TILE,
		"MOUNTAIN_TILE": MOUNTAIN_TILE, "MOUNTAIN_TOP_A_TILE": MOUNTAIN_TOP_A_TILE,
		"MOUNTAIN_TOP_B_TILE": MOUNTAIN_TOP_B_TILE,
		"MOUNTAIN_BOTTOM_A_TILE": MOUNTAIN_BOTTOM_A_TILE,
		"MOUNTAIN_BOTTOM_B_TILE": MOUNTAIN_BOTTOM_B_TILE, "DAM_TILE": DAM_TILE,
		"MOUNTAIN_PEAK_TILE": MOUNTAIN_PEAK_TILE, "STONE_TILE": STONE_TILE,
		"DWARFHOLD_TILE": DWARFHOLD_TILE,
		"ABANDONED_DWARFHOLD_TILE": ABANDONED_DWARFHOLD_TILE,
		"GREAT_DWARFHOLD_TILE": GREAT_DWARFHOLD_TILE,
		"DARK_DWARFHOLD_TILE": DARK_DWARFHOLD_TILE, "HILLHOLD_TILE": HILLHOLD_TILE,
		"CAVE_TILE": CAVE_TILE, "TOWER_TILE": TOWER_TILE,
		"EVIL_WIZARDS_TOWER_TILE": EVIL_WIZARDS_TOWER_TILE,
		"WOOD_ELF_GROVES_TILE": WOOD_ELF_GROVES_TILE,
		"WOOD_ELF_GROVES_LARGE_TILE": WOOD_ELF_GROVES_LARGE_TILE,
		"WOOD_ELF_GROVES_GRAND_TILE": WOOD_ELF_GROVES_GRAND_TILE,
		"HILLS_TILE": HILLS_TILE, "HILLS_BADLANDS_TILE": HILLS_BADLANDS_TILE,
		"HILLS_VARIANT_A_TILE": HILLS_VARIANT_A_TILE,
		"HILLS_VARIANT_B_TILE": HILLS_VARIANT_B_TILE, "HILLS_SNOW_TILE": HILLS_SNOW_TILE,
		"TOWN_TILE": TOWN_TILE, "PORT_TOWN_TILE": PORT_TOWN_TILE,
		"CASTLE_TILE": CASTLE_TILE, "ROADSIDE_TAVERN_TILE": ROADSIDE_TAVERN_TILE,
		"HAMLET_TILE": HAMLET_TILE, "TREE_SNOW_TILE": TREE_SNOW_TILE,
		"ACTIVE_VOLCANO_TILE": ACTIVE_VOLCANO_TILE, "VOLCANO_TILE": VOLCANO_TILE,
		"LAVA_TILE": LAVA_TILE, "OASIS_TILE": OASIS_TILE,
		"HAMLET_SNOW_TILE": HAMLET_SNOW_TILE,
		"AMBIENT_SLEEPING_DRAGON_TILE": AMBIENT_SLEEPING_DRAGON_TILE,
		"AMBIENT_HUNTING_LODGE_TILE": AMBIENT_HUNTING_LODGE_TILE,
		"AMBIENT_HOMESTEAD_TILE": AMBIENT_HOMESTEAD_TILE,
		"AMBIENT_MOONWELL_TILE": AMBIENT_MOONWELL_TILE,
		"AMBIENT_FARM_TILE": AMBIENT_FARM_TILE, "FARM_CROPS_TILE": FARM_CROPS_TILE,
		"AMBIENT_FARM_VARIANT_TILE": AMBIENT_FARM_VARIANT_TILE,
		"AMBIENT_GREAT_TREE_TILE": AMBIENT_GREAT_TREE_TILE,
		"AMBIENT_GREAT_TREE_ALT_TILE": AMBIENT_GREAT_TREE_ALT_TILE,
		"LIZARDMEN_CITY_TILE": LIZARDMEN_CITY_TILE,
		"SAINT_SHRINE_TILE": SAINT_SHRINE_TILE, "MONASTERY_TILE": MONASTERY_TILE,
		"ORC_CAMP_TILE": ORC_CAMP_TILE, "GNOLL_CAMP_TILE": GNOLL_CAMP_TILE,
		"TROLL_CAMP_TILE": TROLL_CAMP_TILE, "OGRE_CAMP_TILE": OGRE_CAMP_TILE,
		"BANDIT_CAMP_TILE": BANDIT_CAMP_TILE, "TRAVELERS_CAMP_TILE": TRAVELERS_CAMP_TILE,
		"DUNGEON_TILE": DUNGEON_TILE, "CENTAUR_ENCAMPMENT_TILE": CENTAUR_ENCAMPMENT_TILE,
	}
	if not validate_atlas_no_duplicates("OVERWORLD_TILES", overworld_atlas):
		valid = false
	if not validate_atlas_no_duplicates("RIVER_TILES", RIVER_TILES):
		valid = false
	return valid
