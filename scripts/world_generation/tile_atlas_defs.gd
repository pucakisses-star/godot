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
## Ambient culture structures (CultureTypes): tiles must be registered with
## the tileset service or set_cell on them renders nothing.
const PROSPECTOR_CAMP_TILE := Vector2i(7, 1)
const OGRE_DEN_TILE := Vector2i(5, 1)

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
	# The sheet ships a full dark-grass patch demo at cols 5-9, rows 0-2:
	# solid interior at (6,1), plain-grass fringed edges around it, convex
	# corners on the demo's diagonals and inner-corner "bites" in the 2x2
	# block at cols 8-9 rows 0-1 (verified by per-cell dark-pixel edge
	# profiling). "grass_dark" is re-pointed from (5,1) — which is actually
	# the west EDGE piece and stamped alone read as a hard-cut square — to
	# the true interior; the edge family below lets dark patches blend out.
	"grass_dark": Vector2i(6, 1),
	"grass_dark_edge_n": Vector2i(6, 0),
	"grass_dark_edge_s": Vector2i(6, 2),
	"grass_dark_edge_w": Vector2i(5, 1),
	"grass_dark_edge_e": Vector2i(7, 1),
	"grass_dark_edge_nw": Vector2i(5, 0),
	"grass_dark_edge_ne": Vector2i(7, 0),
	"grass_dark_edge_sw": Vector2i(5, 2),
	"grass_dark_edge_se": Vector2i(7, 2),
	"grass_dark_in_nw": Vector2i(8, 0),
	"grass_dark_in_ne": Vector2i(9, 0),
	"grass_dark_in_sw": Vector2i(8, 1),
	"grass_dark_in_se": Vector2i(9, 1),
	# Pieces the demo lacks (strips, peninsula tips, lone blobs) are
	# composited into appended row 36 at atlas build time from unions of the
	# shipped edge/corner art, the same trick as the road convex corners.
	"grass_dark_edge_ns": Vector2i(0, 36),
	"grass_dark_edge_we": Vector2i(1, 36),
	"grass_dark_tip_n": Vector2i(2, 36),
	"grass_dark_tip_s": Vector2i(3, 36),
	"grass_dark_tip_w": Vector2i(4, 36),
	"grass_dark_tip_e": Vector2i(5, 36),
	"grass_dark_island": Vector2i(6, 36),
	"grass_tuft": Vector2i(2, 3),
	"grass_tuft_alt": Vector2i(1, 3),
	# Re-pointed from (9,1): that cell is the dark demo's SE inner corner
	# (now mapped as such above). (8,2)/(9,2) are the demo's true all-side
	# 50/50 speckle blends, safe to scatter anywhere on plain grass.
	"grass_mottled": Vector2i(8, 2),
	"grass_mottled_alt": Vector2i(9, 2),
	"flowers_white": Vector2i(4, 17),
	"flowers_yellow": Vector2i(5, 18),
	"flowers_pink": Vector2i(3, 19),
	"flowers_pink_alt": Vector2i(4, 19),
	# Snow ground lives on an extra row (26) appended to the sheet at load
	# time by town_generation._configure_tile_layer; the shipped PNG is
	# 44x26 (rows 0-25), so these coords address the painted-in snow cells.
	"snow": Vector2i(0, 26),
	"snow_alt": Vector2i(1, 26),
	"road": Vector2i(14, 4),
	"road_twig": Vector2i(13, 4),
	"road_alt": Vector2i(10, 3),
	"road_stone": Vector2i(9, 3),
	"road_sprout": Vector2i(13, 3),
	# Dirt-path fringe: the sheet's grass-blended blob set at cols 10-14,
	# rows 0-2 (dirt patch demo). edge_* have grass on the named side;
	# in_* keep dirt on all sides with a grass bite at the named diagonal.
	"road_edge_n": Vector2i(11, 0),
	"road_edge_s": Vector2i(11, 2),
	"road_edge_w": Vector2i(10, 1),
	"road_edge_e": Vector2i(12, 1),
	"road_in_nw": Vector2i(13, 0),
	"road_in_ne": Vector2i(14, 0),
	"road_in_sw": Vector2i(13, 1),
	"road_in_se": Vector2i(14, 1),
	# Convex corners (grass on two adjacent sides) don't exist in the sheet;
	# they are composited into appended row 27 at atlas build time from the
	# union of the two matching edge pieces. Row 28 holds snow recolors of
	# the whole fringe set (grass pixels swapped for painted snow) so tundra
	# lanes blend into their snowfield the same way.
	"road_edge_nw": Vector2i(0, 27),
	"road_edge_ne": Vector2i(1, 27),
	"road_edge_sw": Vector2i(2, 27),
	"road_edge_se": Vector2i(3, 27),
	"road_edge_n_snow": Vector2i(0, 28),
	"road_edge_s_snow": Vector2i(1, 28),
	"road_edge_w_snow": Vector2i(2, 28),
	"road_edge_e_snow": Vector2i(3, 28),
	"road_in_nw_snow": Vector2i(4, 28),
	"road_in_ne_snow": Vector2i(5, 28),
	"road_in_sw_snow": Vector2i(6, 28),
	"road_in_se_snow": Vector2i(7, 28),
	"road_edge_nw_snow": Vector2i(8, 28),
	"road_edge_ne_snow": Vector2i(9, 28),
	"road_edge_sw_snow": Vector2i(10, 28),
	"road_edge_se_snow": Vector2i(11, 28),
	# Terrain-seam fringe families, synthesized into appended rows 29-35 at
	# atlas build time (the shipped sheet has no terrain transition art
	# beyond the dirt-path and dark-grass demos). Each family is the "under"
	# terrain tile with the "over" terrain scalloped onto the named side(s),
	# one piece per TOWN_FRINGE_SUFFIXES entry: sand/water/snow cells that
	# border grass wear a grass overhang, beaches lap sand over water,
	# tilled plots fray into their lawns, and snow_alt drifts feather into
	# plain snow (the tundra counterpart of the dark-grass patches).
	"sand_grass_edge_n": Vector2i(0, 29),
	"sand_grass_edge_s": Vector2i(1, 29),
	"sand_grass_edge_w": Vector2i(2, 29),
	"sand_grass_edge_e": Vector2i(3, 29),
	"sand_grass_edge_nw": Vector2i(4, 29),
	"sand_grass_edge_ne": Vector2i(5, 29),
	"sand_grass_edge_sw": Vector2i(6, 29),
	"sand_grass_edge_se": Vector2i(7, 29),
	"sand_grass_in_nw": Vector2i(8, 29),
	"sand_grass_in_ne": Vector2i(9, 29),
	"sand_grass_in_sw": Vector2i(10, 29),
	"sand_grass_in_se": Vector2i(11, 29),
	"sand_grass_edge_ns": Vector2i(12, 29),
	"sand_grass_edge_we": Vector2i(13, 29),
	"sand_grass_tip_n": Vector2i(14, 29),
	"sand_grass_tip_s": Vector2i(15, 29),
	"sand_grass_tip_w": Vector2i(16, 29),
	"sand_grass_tip_e": Vector2i(17, 29),
	"sand_grass_island": Vector2i(18, 29),
	"water_grass_edge_n": Vector2i(0, 39),
	"water_grass_edge_s": Vector2i(4, 39),
	"water_grass_edge_w": Vector2i(8, 39),
	"water_grass_edge_e": Vector2i(12, 39),
	"water_grass_edge_nw": Vector2i(16, 39),
	"water_grass_edge_ne": Vector2i(20, 39),
	"water_grass_edge_sw": Vector2i(24, 39),
	"water_grass_edge_se": Vector2i(28, 39),
	"water_grass_in_nw": Vector2i(32, 39),
	"water_grass_in_ne": Vector2i(36, 39),
	"water_grass_in_sw": Vector2i(40, 39),
	"water_grass_in_se": Vector2i(0, 40),
	"water_grass_edge_ns": Vector2i(4, 40),
	"water_grass_edge_we": Vector2i(8, 40),
	"water_grass_tip_n": Vector2i(12, 40),
	"water_grass_tip_s": Vector2i(16, 40),
	"water_grass_tip_w": Vector2i(20, 40),
	"water_grass_tip_e": Vector2i(24, 40),
	"water_grass_island": Vector2i(28, 40),
	"water_sand_edge_n": Vector2i(0, 41),
	"water_sand_edge_s": Vector2i(4, 41),
	"water_sand_edge_w": Vector2i(8, 41),
	"water_sand_edge_e": Vector2i(12, 41),
	"water_sand_edge_nw": Vector2i(16, 41),
	"water_sand_edge_ne": Vector2i(20, 41),
	"water_sand_edge_sw": Vector2i(24, 41),
	"water_sand_edge_se": Vector2i(28, 41),
	"water_sand_in_nw": Vector2i(32, 41),
	"water_sand_in_ne": Vector2i(36, 41),
	"water_sand_in_sw": Vector2i(40, 41),
	"water_sand_in_se": Vector2i(0, 42),
	"water_sand_edge_ns": Vector2i(4, 42),
	"water_sand_edge_we": Vector2i(8, 42),
	"water_sand_tip_n": Vector2i(12, 42),
	"water_sand_tip_s": Vector2i(16, 42),
	"water_sand_tip_w": Vector2i(20, 42),
	"water_sand_tip_e": Vector2i(24, 42),
	"water_sand_island": Vector2i(28, 42),
	"snow_grass_edge_n": Vector2i(0, 32),
	"snow_grass_edge_s": Vector2i(1, 32),
	"snow_grass_edge_w": Vector2i(2, 32),
	"snow_grass_edge_e": Vector2i(3, 32),
	"snow_grass_edge_nw": Vector2i(4, 32),
	"snow_grass_edge_ne": Vector2i(5, 32),
	"snow_grass_edge_sw": Vector2i(6, 32),
	"snow_grass_edge_se": Vector2i(7, 32),
	"snow_grass_in_nw": Vector2i(8, 32),
	"snow_grass_in_ne": Vector2i(9, 32),
	"snow_grass_in_sw": Vector2i(10, 32),
	"snow_grass_in_se": Vector2i(11, 32),
	"snow_grass_edge_ns": Vector2i(12, 32),
	"snow_grass_edge_we": Vector2i(13, 32),
	"snow_grass_tip_n": Vector2i(14, 32),
	"snow_grass_tip_s": Vector2i(15, 32),
	"snow_grass_tip_w": Vector2i(16, 32),
	"snow_grass_tip_e": Vector2i(17, 32),
	"snow_grass_island": Vector2i(18, 32),
	"tilled_edge_n": Vector2i(0, 33),
	"tilled_edge_s": Vector2i(1, 33),
	"tilled_edge_w": Vector2i(2, 33),
	"tilled_edge_e": Vector2i(3, 33),
	"tilled_edge_nw": Vector2i(4, 33),
	"tilled_edge_ne": Vector2i(5, 33),
	"tilled_edge_sw": Vector2i(6, 33),
	"tilled_edge_se": Vector2i(7, 33),
	"tilled_in_nw": Vector2i(8, 33),
	"tilled_in_ne": Vector2i(9, 33),
	"tilled_in_sw": Vector2i(10, 33),
	"tilled_in_se": Vector2i(11, 33),
	"tilled_edge_ns": Vector2i(12, 33),
	"tilled_edge_we": Vector2i(13, 33),
	"tilled_tip_n": Vector2i(14, 33),
	"tilled_tip_s": Vector2i(15, 33),
	"tilled_tip_w": Vector2i(16, 33),
	"tilled_tip_e": Vector2i(17, 33),
	"tilled_island": Vector2i(18, 33),
	"snow_alt_edge_n": Vector2i(0, 34),
	"snow_alt_edge_s": Vector2i(1, 34),
	"snow_alt_edge_w": Vector2i(2, 34),
	"snow_alt_edge_e": Vector2i(3, 34),
	"snow_alt_edge_nw": Vector2i(4, 34),
	"snow_alt_edge_ne": Vector2i(5, 34),
	"snow_alt_edge_sw": Vector2i(6, 34),
	"snow_alt_edge_se": Vector2i(7, 34),
	"snow_alt_in_nw": Vector2i(8, 34),
	"snow_alt_in_ne": Vector2i(9, 34),
	"snow_alt_in_sw": Vector2i(10, 34),
	"snow_alt_in_se": Vector2i(11, 34),
	"snow_alt_edge_ns": Vector2i(12, 34),
	"snow_alt_edge_we": Vector2i(13, 34),
	"snow_alt_tip_n": Vector2i(14, 34),
	"snow_alt_tip_s": Vector2i(15, 34),
	"snow_alt_tip_w": Vector2i(16, 34),
	"snow_alt_tip_e": Vector2i(17, 34),
	"snow_alt_island": Vector2i(18, 34),
	"water_snow_edge_n": Vector2i(0, 43),
	"water_snow_edge_s": Vector2i(4, 43),
	"water_snow_edge_w": Vector2i(8, 43),
	"water_snow_edge_e": Vector2i(12, 43),
	"water_snow_edge_nw": Vector2i(16, 43),
	"water_snow_edge_ne": Vector2i(20, 43),
	"water_snow_edge_sw": Vector2i(24, 43),
	"water_snow_edge_se": Vector2i(28, 43),
	"water_snow_in_nw": Vector2i(32, 43),
	"water_snow_in_ne": Vector2i(36, 43),
	"water_snow_in_sw": Vector2i(40, 43),
	"water_snow_in_se": Vector2i(0, 44),
	"water_snow_edge_ns": Vector2i(4, 44),
	"water_snow_edge_we": Vector2i(8, 44),
	"water_snow_tip_n": Vector2i(12, 44),
	"water_snow_tip_s": Vector2i(16, 44),
	"water_snow_tip_w": Vector2i(20, 44),
	"water_snow_tip_e": Vector2i(24, 44),
	"water_snow_island": Vector2i(28, 44),
	"sand_snow_edge_n": Vector2i(0, 37),
	"sand_snow_edge_s": Vector2i(1, 37),
	"sand_snow_edge_w": Vector2i(2, 37),
	"sand_snow_edge_e": Vector2i(3, 37),
	"sand_snow_edge_nw": Vector2i(4, 37),
	"sand_snow_edge_ne": Vector2i(5, 37),
	"sand_snow_edge_sw": Vector2i(6, 37),
	"sand_snow_edge_se": Vector2i(7, 37),
	"sand_snow_in_nw": Vector2i(8, 37),
	"sand_snow_in_ne": Vector2i(9, 37),
	"sand_snow_in_sw": Vector2i(10, 37),
	"sand_snow_in_se": Vector2i(11, 37),
	"sand_snow_edge_ns": Vector2i(12, 37),
	"sand_snow_edge_we": Vector2i(13, 37),
	"sand_snow_tip_n": Vector2i(14, 37),
	"sand_snow_tip_s": Vector2i(15, 37),
	"sand_snow_tip_w": Vector2i(16, 37),
	"sand_snow_tip_e": Vector2i(17, 37),
	"sand_snow_island": Vector2i(18, 37),
	"sand": Vector2i(11, 4),
	"sand_alt": Vector2i(9, 4),
	"sand_pebbles": Vector2i(12, 3),
	"plaza": Vector2i(17, 2),
	"plaza_alt": Vector2i(18, 3),
	"plaza_c": Vector2i(16, 0),
	"plaza_d": Vector2i(15, 1),
	"wall": Vector2i(1, 7),
	"wall_alt": Vector2i(2, 7),
	"plank_wall": Vector2i(25, 0),
	# Timber building autotile: the chunky golden log-wall set at cols 0-4,
	# rows 6-8 of town_tileset.png (verified by per-cell PIL extraction and
	# a composited mockup). Corner posts, a braced top beam, solid log side
	# columns and a plank sill — fully opaque squares, so a building ring
	# finally reads as WALLS instead of the faint thin frame the old cols
	# 24-26 9-slice gave ("floor platforms"). The fill piece is the plain
	# log face at (3,7); (1,7)/(2,7) hold the player-build "wall"/"wall_alt"
	# keys, and the atlas validator forbids sharing coordinates.
	"wall_tl": Vector2i(0, 6),
	"wall_top": Vector2i(2, 6),
	"wall_tr": Vector2i(4, 6),
	"wall_left": Vector2i(0, 7),
	"wall_fill": Vector2i(3, 7),
	"wall_right": Vector2i(4, 7),
	"wall_bl": Vector2i(0, 8),
	"wall_bottom": Vector2i(2, 8),
	"wall_br": Vector2i(4, 8),
	"floor": Vector2i(25, 1),
	"door": Vector2i(26, 1),
	"rug": Vector2i(33, 2),
	# Log-fence autotile set (cols 8-13, rows 6-9): a full 16-piece family
	# keyed by which sides a piece's rails leave through (verified against
	# per-cell edge-pixel connectivity). "fence" keeps its legacy coordinate
	# (the N+E+W tee) because player-built fences persist that key;
	# "fence_post" is re-pointed at the true lone post at (8,8) — its old
	# coordinate (9,8) is the NE corner, now mapped as such.
	"fence": Vector2i(10, 8),
	"fence_post": Vector2i(8, 8),
	"fence_ns": Vector2i(8, 7),
	"fence_ns_alt": Vector2i(12, 7),
	"fence_we": Vector2i(12, 6),
	"fence_we_alt": Vector2i(13, 6),
	"fence_we_low": Vector2i(10, 9),
	"fence_se": Vector2i(9, 6),
	"fence_sw": Vector2i(11, 6),
	"fence_ne": Vector2i(9, 8),
	"fence_nw": Vector2i(11, 8),
	"fence_wes": Vector2i(10, 6),
	"fence_nse": Vector2i(9, 7),
	"fence_nsw": Vector2i(11, 7),
	"fence_cross": Vector2i(10, 7),
	"fence_cap_s": Vector2i(8, 6),
	"fence_cap_e": Vector2i(9, 9),
	"fence_cap_w": Vector2i(11, 9),
	# Green-ground scatter: cut stumps, a fallen branch (passable litter).
	"stump": Vector2i(0, 13),
	"stump_alt": Vector2i(2, 13),
	"branch": Vector2i(5, 16),
	# The village well: a 2x2 composition — stone basin pair below, roofed
	# crank pair above. The base cells block movement, the roof halves are
	# passable visual caps (same convention as the *_top furniture keys).
	"well_base_left": Vector2i(3, 15),
	"well_base_right": Vector2i(4, 15),
	"well_roof_left": Vector2i(3, 14),
	"well_roof_right": Vector2i(4, 14),
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
	# Animated water: each base owns TOWN_WATER_ANIMATION_FRAMES consecutive
	# cells to its right (frames painted at atlas build; the shipped flat
	# water art at (0,23)/(1,23) seeds the palette). The water fringe
	# families below stride by 4 for the same reason.
	"water": Vector2i(0, 38),
	"water_calm": Vector2i(4, 38),
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
## The full fringe-piece vocabulary, one atlas column per suffix (in this
## order) for every synthesized transition family. edge_* pieces carry the
## "over" terrain on the named side(s), in_* keep the under-terrain on all
## sides with an over-terrain bite at the named diagonal, tip_* are
## peninsula ends open on three sides, island is fringed all round.
const TOWN_FRINGE_SUFFIXES: Array[String] = [
	"edge_n", "edge_s", "edge_w", "edge_e",
	"edge_nw", "edge_ne", "edge_sw", "edge_se",
	"in_nw", "in_ne", "in_sw", "in_se",
	"edge_ns", "edge_we",
	"tip_n", "tip_s", "tip_w", "tip_e",
	"island"
]

## Frame count for the looping water animation. Every water-family tile
## (open water, calm ponds, and each shoreline fringe piece) owns this many
## consecutive atlas cells; frame 0 is the mapped base cell.
const TOWN_WATER_ANIMATION_FRAMES := 4

## The looped tile keys: their art is painted per frame at atlas build and
## their atlas tiles get animation frames in _configure_tile_layer.
static func town_water_animated_keys() -> Array[String]:
	var keys: Array[String] = ["water", "water_calm"]
	for family: String in ["water_grass", "water_sand", "water_snow"]:
		for suffix: String in TOWN_FRINGE_SUFFIXES:
			keys.append("%s_%s" % [family, suffix])
	return keys

## Recipes for the synthesized transition families: each paints the "under"
## ground tile with the "over" ground scalloped across the open side(s),
## into the appended atlas row holding that family's keys. "rim" darkens the
## over-terrain pixels along the waterline so banks read as banks.
const TOWN_FRINGE_FAMILIES := {
	"sand_grass": {"under": "sand", "over": "grass", "rim": false},
	"water_grass": {"under": "water", "over": "grass", "rim": true},
	"water_sand": {"under": "water", "over": "sand", "rim": true},
	"snow_grass": {"under": "snow", "over": "grass", "rim": false},
	"tilled": {"under": "tilled_soil", "over": "grass", "rim": false},
	"snow_alt": {"under": "snow_alt", "over": "snow", "rim": false},
	"water_snow": {"under": "water", "over": "snow", "rim": true},
	"sand_snow": {"under": "sand", "over": "snow", "rim": false}
}

## The *_top keys are the upper halves of two-tile-tall furniture sprites.
## They render as visual caps over the cell above the furniture, so they
## stay passable — the blocking cell is the furniture base itself.
const TOWN_PASSABLE_TILE_KEYS := [
	"grass", "grass_dark", "grass_tuft", "grass_tuft_alt", "grass_mottled",
	"grass_mottled_alt",
	"grass_dark_edge_n", "grass_dark_edge_s", "grass_dark_edge_w", "grass_dark_edge_e",
	"grass_dark_edge_nw", "grass_dark_edge_ne", "grass_dark_edge_sw", "grass_dark_edge_se",
	"grass_dark_in_nw", "grass_dark_in_ne", "grass_dark_in_sw", "grass_dark_in_se",
	"grass_dark_edge_ns", "grass_dark_edge_we",
	"grass_dark_tip_n", "grass_dark_tip_s", "grass_dark_tip_w", "grass_dark_tip_e",
	"grass_dark_island",
	"flowers_white", "flowers_yellow", "flowers_pink", "flowers_pink_alt",
	"snow", "snow_alt",
	"road", "road_twig", "road_alt", "road_stone", "road_sprout",
	"road_edge_n", "road_edge_s", "road_edge_w", "road_edge_e",
	"road_in_nw", "road_in_ne", "road_in_sw", "road_in_se",
	"road_edge_nw", "road_edge_ne", "road_edge_sw", "road_edge_se",
	"road_edge_n_snow", "road_edge_s_snow", "road_edge_w_snow", "road_edge_e_snow",
	"road_in_nw_snow", "road_in_ne_snow", "road_in_sw_snow", "road_in_se_snow",
	"road_edge_nw_snow", "road_edge_ne_snow", "road_edge_sw_snow", "road_edge_se_snow",
	"sand", "sand_alt", "sand_pebbles",
	# Grass-fringed sand, snow-drift variants, grass-fringed snow and the
	# tilled-plot fringe are all walkable ground; the water fringe families
	# are deliberately absent (a grass- or sand-lapped water cell is still
	# water and still blocks walkers unless they boat).
	"sand_grass_edge_n", "sand_grass_edge_s", "sand_grass_edge_w", "sand_grass_edge_e",
	"sand_grass_edge_nw", "sand_grass_edge_ne", "sand_grass_edge_sw", "sand_grass_edge_se",
	"sand_grass_in_nw", "sand_grass_in_ne", "sand_grass_in_sw", "sand_grass_in_se",
	"sand_grass_edge_ns", "sand_grass_edge_we", "sand_grass_tip_n", "sand_grass_tip_s",
	"sand_grass_tip_w", "sand_grass_tip_e", "sand_grass_island",
	"sand_snow_edge_n", "sand_snow_edge_s", "sand_snow_edge_w", "sand_snow_edge_e",
	"sand_snow_edge_nw", "sand_snow_edge_ne", "sand_snow_edge_sw", "sand_snow_edge_se",
	"sand_snow_in_nw", "sand_snow_in_ne", "sand_snow_in_sw", "sand_snow_in_se",
	"sand_snow_edge_ns", "sand_snow_edge_we", "sand_snow_tip_n", "sand_snow_tip_s",
	"sand_snow_tip_w", "sand_snow_tip_e", "sand_snow_island",
	"snow_grass_edge_n", "snow_grass_edge_s", "snow_grass_edge_w", "snow_grass_edge_e",
	"snow_grass_edge_nw", "snow_grass_edge_ne", "snow_grass_edge_sw", "snow_grass_edge_se",
	"snow_grass_in_nw", "snow_grass_in_ne", "snow_grass_in_sw", "snow_grass_in_se",
	"snow_grass_edge_ns", "snow_grass_edge_we", "snow_grass_tip_n", "snow_grass_tip_s",
	"snow_grass_tip_w", "snow_grass_tip_e", "snow_grass_island",
	"snow_alt_edge_n", "snow_alt_edge_s", "snow_alt_edge_w", "snow_alt_edge_e",
	"snow_alt_edge_nw", "snow_alt_edge_ne", "snow_alt_edge_sw", "snow_alt_edge_se",
	"snow_alt_in_nw", "snow_alt_in_ne", "snow_alt_in_sw", "snow_alt_in_se",
	"snow_alt_edge_ns", "snow_alt_edge_we", "snow_alt_tip_n", "snow_alt_tip_s",
	"snow_alt_tip_w", "snow_alt_tip_e", "snow_alt_island",
	"tilled_edge_n", "tilled_edge_s", "tilled_edge_w", "tilled_edge_e",
	"tilled_edge_nw", "tilled_edge_ne", "tilled_edge_sw", "tilled_edge_se",
	"tilled_in_nw", "tilled_in_ne", "tilled_in_sw", "tilled_in_se",
	"tilled_edge_ns", "tilled_edge_we", "tilled_tip_n", "tilled_tip_s",
	"tilled_tip_w", "tilled_tip_e", "tilled_island",
	"plaza", "plaza_alt", "plaza_c", "plaza_d",
	# A fallen branch is ground litter, not a barrier.
	"branch",
	"floor", "door", "rug",
	"bed_top", "bed_alt_top", "wardrobe_top", "dresser_top", "shelf_top",
	"forge_top", "oven_top", "well_roof_left", "well_roof_right",
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
