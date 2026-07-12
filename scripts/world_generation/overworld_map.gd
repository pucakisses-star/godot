extends Node2D

@export var map_size: Vector2i = Vector2i(256, 256)
@export var water_level: float = 0.45
@export var falloff_strength: float = 0.08
@export var falloff_power: float = 2.4
@export var noise_frequency: float = 2.0
@export var noise_octaves: int = 4
@export var hill_level: float = 0.72
@export var mountain_level: float = 0.82
@export var landmass_center_count: int = 4
@export var landmass_center_margin: float = 0.12
@export var landmass_falloff_scale: float = 1.35
@export var landmass_mask_strength: float = 0.24
@export var landmass_mask_power: float = 0.82
@export var landmass_mask_threshold: float = 0.47
@export_range(0.1, 4.0, 0.05) var landmass_mask_scale: float = 1.0
@export_range(0.01, 0.5, 0.01) var landmass_mask_edge_falloff: float = 0.26
@export_range(0.0, 5.0, 0.05) var center_shape_strength: float = 1.0
@export_range(0.0, 2.0, 0.05) var landmass_center_min_separation: float = 0.0
@export_range(0.0, 0.5, 0.01) var edge_ocean_strength: float = 0.2
@export_range(0.05, 1.0, 0.01) var edge_ocean_falloff: float = 0.32
@export_range(0.5, 4.0, 0.1) var edge_ocean_curve: float = 1.6
@export var temperature_frequency: float = 1.2
@export var rainfall_frequency: float = 1.7
@export_range(0.0, 1.0, 0.01) var river_frequency: float = 0.5
@export var map_seed: int = 0
@export var tile_size: int = 32
@export_range(0.1, 500.0, 0.1) var kilometers_per_tile: float = 8.0
@export var globe_rotation_speed: float = 0.02
@export var globe_drag_sensitivity: float = 0.008
@export var globe_zoom_step: float = 0.35
@export var globe_min_camera_distance: float = 2.4
@export var globe_max_camera_distance: float = 8.0
@export var scene3d_drag_sensitivity: float = 0.008
@export var scene3d_zoom_step: float = 0.35
@export var scene3d_min_camera_distance: float = 2.4
@export var scene3d_max_camera_distance: float = 9.5
@export var globe_height_scale: float = 0.0
## Fraction of globe longitude reserved for the synthesized ocean strip that
## bridges the map's east and west edges so the sphere wrap has no seam.
@export_range(0.0, 0.3, 0.01) var globe_seam_band: float = 0.08
@export var scene3d_height_scale: float = 0.1
@export var scene3d_mountain_compression: float = 0.35
@export var scene3d_land_blend_power: float = 1.75
@export var route_overlay_line_color: Color = Color(0.82, 0.68, 0.48, 0.9)
@export_range(1.0, 8.0, 0.1) var route_overlay_line_width: float = 2.2
@export_range(1, 5, 1) var route_overlay_target_connections: int = 2
@export_range(0.05, 0.6, 0.01) var route_overlay_max_distance_ratio: float = 0.2
@export var labels_overlay_primary_color: Color = Color(0.93, 0.89, 0.76, 0.96)
@export var labels_overlay_secondary_color: Color = Color(0.85, 0.82, 0.7, 0.92)
@export var labels_overlay_outline_color: Color = Color(0.07, 0.06, 0.04, 0.9)
@export_range(0.0, 4.0, 0.1) var labels_overlay_outline_size: float = 1.0
@export var labels_overlay_rescale_on_zoom: bool = true
@export var labels_overlay_auto_visibility: bool = true
@export_range(4.0, 40.0, 0.5) var labels_overlay_min_screen_size: float = 7.0
@export_range(12.0, 120.0, 1.0) var labels_overlay_max_screen_size: float = 50.0
@export var river_overlay_line_color: Color = Color(0.3, 0.65, 0.9, 0.82)
@export_range(0.5, 6.0, 0.1) var river_overlay_base_width: float = 1.3
@export_range(5.0, 250.0, 1.0) var river_min_flux_to_draw: float = 44.0
@export_range(1, 128, 1) var river_max_count: int = 28
@export var iceberg_tile_options: Array[Vector2i] = [Vector2i(4, 3), Vector2i(5, 3)]

@export_group("Biomes")
@export_range(0.0, 1.0, 0.01) var tundra_threshold: float = 0.28
@export_range(0.0, 1.0, 0.01) var snow_latitude_threshold: float = 0.62
@export_range(0.0, 1.0, 0.01) var desert_threshold: float = 0.25
@export_range(0.0, 0.4, 0.01) var desert_temperature_bias: float = 0.08
@export_range(0.0, 0.4, 0.01) var desert_moisture_bias: float = 0.08
@export_range(0.0, 1.0, 0.01) var badlands_threshold: float = 0.4
@export_range(0.0, 1.0, 0.01) var forest_threshold: float = 0.6
@export_range(0.2, 0.95, 0.01) var forest_max_coverage: float = 0.41
@export_range(0.0, 1.0, 0.01) var jungle_threshold: float = 0.68
@export_range(0.0, 1.0, 0.01) var marsh_threshold: float = 0.68
@export_range(0.0, 1.0, 0.01) var hot_threshold: float = 0.7
@export_range(0.0, 1.0, 0.01) var warm_threshold: float = 0.55

const TILE_ATLAS_DEFS := preload("res://scripts/world_generation/tile_atlas_defs.gd")
const WorldSettings := preload("res://scripts/world_generation/world_settings.gd")
const BIOME_CLASSIFIER := preload("res://scripts/world_generation/biome_classifier.gd")
const STRUCTURE_PLACER := preload("res://scripts/world_generation/structure_placer.gd")
const WORLD_NAMING := preload("res://scripts/world_generation/world_naming.gd")
const OVERWORLD_GENERATION := preload("res://scripts/world_generation/overworld_generation.gd")
const OVERWORLD_RENDERING := preload("res://scripts/world_generation/overworld_rendering.gd")
const OVERWORLD_INTERACTION := preload("res://scripts/world_generation/overworld_interaction.gd")
const OVERWORLD_CONTENT := preload("res://scripts/world_generation/overworld_content.gd")
const SETTLEMENT_NAMING := preload("res://scripts/world_generation/settlement_naming.gd")
const ROUTES_SERVICE := preload("res://scripts/world_generation/overworld_routes_service.gd")

const ATLAS_TEXTURE := TILE_ATLAS_DEFS.ATLAS_TEXTURE
const SAND_TILE := TILE_ATLAS_DEFS.SAND_TILE
const GRASS_TILE := TILE_ATLAS_DEFS.GRASS_TILE
const BADLANDS_TILE := TILE_ATLAS_DEFS.BADLANDS_TILE
const MINE_TILE := TILE_ATLAS_DEFS.MINE_TILE
const MARSH_TILE := TILE_ATLAS_DEFS.MARSH_TILE
const SNOW_TILE := TILE_ATLAS_DEFS.SNOW_TILE
const TREE_TILE := TILE_ATLAS_DEFS.TREE_TILE
const TREE_LONE_TILE := TILE_ATLAS_DEFS.TREE_LONE_TILE
const JUNGLE_TREE_TILE := TILE_ATLAS_DEFS.JUNGLE_TREE_TILE
const CUT_TREES_TILE := TILE_ATLAS_DEFS.CUT_TREES_TILE
const AMBIENT_LUMBER_MILL_TILE := TILE_ATLAS_DEFS.AMBIENT_LUMBER_MILL_TILE
const WATER_TILE := TILE_ATLAS_DEFS.WATER_TILE
const MOUNTAIN_TILE := TILE_ATLAS_DEFS.MOUNTAIN_TILE
const MOUNTAIN_TOP_A_TILE := TILE_ATLAS_DEFS.MOUNTAIN_TOP_A_TILE
const MOUNTAIN_TOP_B_TILE := TILE_ATLAS_DEFS.MOUNTAIN_TOP_B_TILE
const MOUNTAIN_BOTTOM_A_TILE := TILE_ATLAS_DEFS.MOUNTAIN_BOTTOM_A_TILE
const MOUNTAIN_BOTTOM_B_TILE := TILE_ATLAS_DEFS.MOUNTAIN_BOTTOM_B_TILE
const DAM_TILE := TILE_ATLAS_DEFS.DAM_TILE
const MOUNTAIN_PEAK_TILE := TILE_ATLAS_DEFS.MOUNTAIN_PEAK_TILE
const STONE_TILE := TILE_ATLAS_DEFS.STONE_TILE
const DWARFHOLD_TILE := TILE_ATLAS_DEFS.DWARFHOLD_TILE
const ABANDONED_DWARFHOLD_TILE := TILE_ATLAS_DEFS.ABANDONED_DWARFHOLD_TILE
const GREAT_DWARFHOLD_TILE := TILE_ATLAS_DEFS.GREAT_DWARFHOLD_TILE
const DARK_DWARFHOLD_TILE := TILE_ATLAS_DEFS.DARK_DWARFHOLD_TILE
const HILLHOLD_TILE := TILE_ATLAS_DEFS.HILLHOLD_TILE
const CAVE_TILE := TILE_ATLAS_DEFS.CAVE_TILE
const TOWER_TILE := TILE_ATLAS_DEFS.TOWER_TILE
const EVIL_WIZARDS_TOWER_TILE := TILE_ATLAS_DEFS.EVIL_WIZARDS_TOWER_TILE
const WOOD_ELF_GROVES_TILE := TILE_ATLAS_DEFS.WOOD_ELF_GROVES_TILE
const WOOD_ELF_GROVES_LARGE_TILE := TILE_ATLAS_DEFS.WOOD_ELF_GROVES_LARGE_TILE
const WOOD_ELF_GROVES_GRAND_TILE := TILE_ATLAS_DEFS.WOOD_ELF_GROVES_GRAND_TILE
const HILLS_TILE := TILE_ATLAS_DEFS.HILLS_TILE
const HILLS_BADLANDS_TILE := TILE_ATLAS_DEFS.HILLS_BADLANDS_TILE
const HILLS_VARIANT_A_TILE := TILE_ATLAS_DEFS.HILLS_VARIANT_A_TILE
const HILLS_VARIANT_B_TILE := TILE_ATLAS_DEFS.HILLS_VARIANT_B_TILE
const HILLS_SNOW_TILE := TILE_ATLAS_DEFS.HILLS_SNOW_TILE
const TOWN_TILE := TILE_ATLAS_DEFS.TOWN_TILE
const PORT_TOWN_TILE := TILE_ATLAS_DEFS.PORT_TOWN_TILE
const CASTLE_TILE := TILE_ATLAS_DEFS.CASTLE_TILE
const ROADSIDE_TAVERN_TILE := TILE_ATLAS_DEFS.ROADSIDE_TAVERN_TILE
const HAMLET_TILE := TILE_ATLAS_DEFS.HAMLET_TILE
const TREE_SNOW_TILE := TILE_ATLAS_DEFS.TREE_SNOW_TILE
const ACTIVE_VOLCANO_TILE := TILE_ATLAS_DEFS.ACTIVE_VOLCANO_TILE
const VOLCANO_TILE := TILE_ATLAS_DEFS.VOLCANO_TILE
const LAVA_TILE := TILE_ATLAS_DEFS.LAVA_TILE
const OASIS_TILE := TILE_ATLAS_DEFS.OASIS_TILE
const HAMLET_SNOW_TILE := TILE_ATLAS_DEFS.HAMLET_SNOW_TILE
const AMBIENT_SLEEPING_DRAGON_TILE := TILE_ATLAS_DEFS.AMBIENT_SLEEPING_DRAGON_TILE
const AMBIENT_HUNTING_LODGE_TILE := TILE_ATLAS_DEFS.AMBIENT_HUNTING_LODGE_TILE
const AMBIENT_HOMESTEAD_TILE := TILE_ATLAS_DEFS.AMBIENT_HOMESTEAD_TILE
const AMBIENT_MOONWELL_TILE := TILE_ATLAS_DEFS.AMBIENT_MOONWELL_TILE
const AMBIENT_FARM_TILE := TILE_ATLAS_DEFS.AMBIENT_FARM_TILE
const FARM_CROPS_TILE := TILE_ATLAS_DEFS.FARM_CROPS_TILE
const AMBIENT_FARM_VARIANT_TILE := TILE_ATLAS_DEFS.AMBIENT_FARM_VARIANT_TILE
const AMBIENT_GREAT_TREE_TILE := TILE_ATLAS_DEFS.AMBIENT_GREAT_TREE_TILE
const AMBIENT_GREAT_TREE_ALT_TILE := TILE_ATLAS_DEFS.AMBIENT_GREAT_TREE_ALT_TILE
const LIZARDMEN_CITY_TILE := TILE_ATLAS_DEFS.LIZARDMEN_CITY_TILE
const SAINT_SHRINE_TILE := TILE_ATLAS_DEFS.SAINT_SHRINE_TILE
const MONASTERY_TILE := TILE_ATLAS_DEFS.MONASTERY_TILE
const ORC_CAMP_TILE := TILE_ATLAS_DEFS.ORC_CAMP_TILE
const GNOLL_CAMP_TILE := TILE_ATLAS_DEFS.GNOLL_CAMP_TILE
const TROLL_CAMP_TILE := TILE_ATLAS_DEFS.TROLL_CAMP_TILE
const OGRE_CAMP_TILE := TILE_ATLAS_DEFS.OGRE_CAMP_TILE
const BANDIT_CAMP_TILE := TILE_ATLAS_DEFS.BANDIT_CAMP_TILE
const TRAVELERS_CAMP_TILE := TILE_ATLAS_DEFS.TRAVELERS_CAMP_TILE
const DUNGEON_TILE := TILE_ATLAS_DEFS.DUNGEON_TILE
const CENTAUR_ENCAMPMENT_TILE := TILE_ATLAS_DEFS.CENTAUR_ENCAMPMENT_TILE
const BIOME_WATER := TILE_ATLAS_DEFS.BIOME_WATER
const BIOME_MOUNTAIN := TILE_ATLAS_DEFS.BIOME_MOUNTAIN
const BIOME_HILLS := TILE_ATLAS_DEFS.BIOME_HILLS
const BIOME_MARSH := TILE_ATLAS_DEFS.BIOME_MARSH
const BIOME_TUNDRA := TILE_ATLAS_DEFS.BIOME_TUNDRA
const BIOME_DESERT := TILE_ATLAS_DEFS.BIOME_DESERT
const BIOME_BADLANDS := TILE_ATLAS_DEFS.BIOME_BADLANDS
const BIOME_FOREST := TILE_ATLAS_DEFS.BIOME_FOREST
const BIOME_JUNGLE := TILE_ATLAS_DEFS.BIOME_JUNGLE
const BIOME_GRASSLAND := TILE_ATLAS_DEFS.BIOME_GRASSLAND
## Tile skins per settlement type. Every variant is EARNED, never random:
## PORT needs a water 8-neighbor, HAMLET needs a small population, grove
## upgrades need a high population ratio, GREAT/ABANDONED holds come from
## score/abandonment rolls. Castles are a separate scored structure pass
## (browser main.js:27407-27520), not a town skin.
const SETTLEMENT_TILES := {
	"dwarfhold": [DWARFHOLD_TILE, ABANDONED_DWARFHOLD_TILE, GREAT_DWARFHOLD_TILE, DARK_DWARFHOLD_TILE],
	"town": [TOWN_TILE, PORT_TOWN_TILE, HAMLET_TILE, HAMLET_SNOW_TILE],
	"woodElfGrove": [WOOD_ELF_GROVES_TILE, WOOD_ELF_GROVES_LARGE_TILE, WOOD_ELF_GROVES_GRAND_TILE],
	"lizardmenCity": [LIZARDMEN_CITY_TILE]
}

const DWARFHOLD_NEARBY_TOWN_RADIUS := 12.0
const RIVER_NEIGHBOR_DEFINITIONS := [
	{"offset": Vector2i(0, -1), "key": "N", "bit": 1},
	{"offset": Vector2i(1, 0), "key": "E", "bit": 2},
	{"offset": Vector2i(0, 1), "key": "S", "bit": 4},
	{"offset": Vector2i(-1, 0), "key": "W", "bit": 8}
]


const _BIOME_TO_ID := {
	BIOME_WATER: 0,
	BIOME_MOUNTAIN: 1,
	BIOME_HILLS: 2,
	BIOME_MARSH: 3,
	BIOME_TUNDRA: 4,
	BIOME_DESERT: 5,
	BIOME_BADLANDS: 6,
	BIOME_FOREST: 7,
	BIOME_JUNGLE: 8,
	BIOME_GRASSLAND: 9
}
const _ID_TO_BIOME: Array[String] = [
	BIOME_WATER,
	BIOME_MOUNTAIN,
	BIOME_HILLS,
	BIOME_MARSH,
	BIOME_TUNDRA,
	BIOME_DESERT,
	BIOME_BADLANDS,
	BIOME_FOREST,
	BIOME_JUNGLE,
	BIOME_GRASSLAND
]
const TILE_OVERLAY_TREE := 1
const TILE_OVERLAY_FOREST := 1 << 1
const TILE_OVERLAY_RIVER := 1 << 2

## Structures that join the road network alongside true settlements.
const ROUTE_ELIGIBLE_STRUCTURE_IDS := ["roadsideTavern", "travelerCamp", "orcCamp", "tower", "evilWizardTower"]
## Browser summarizeTileResources catalog (main.js:14147-14158), lowercase
## to match the Godot tooltip styling. Water id 0 carries the ocean triad;
## lakes swap to the freshwater triad in _resources_for_tile. Hills (id 2)
## have no browser entry - hill tiles yield their base biome's triad.
const _BIOME_RESOURCES_BY_ID := {
	0: ["rich fisheries", "pearl beds", "kelp forests"],
	1: ["metallic ores", "quarried stone", "crystal seams"],
	3: ["peat bogs", "reed thickets", "bog iron deposits"],
	4: ["fur-bearing fauna", "permafrost relics", "glacial ice"],
	5: ["trade spices", "glass sands", "hidden oasis wells"],
	6: ["scrap metals", "hardy grazing", "quartz outcrops"],
	7: ["hardwood timber", "game animals", "medicinal herbs"],
	8: ["rare hardwoods", "exotic fruits", "alchemical resins"],
	9: ["grain harvests", "pasture livestock", "wildflower dyes"]
}
const DWARFHOLD_POPULATION_RACE_OPTIONS := [
	{"key": "dwarves", "label": "Dwarves", "color": Color("#f4c069")},
	{"key": "humans", "label": "Humans", "color": Color("#9bb6d8")},
	{"key": "halflings", "label": "Halflings", "color": Color("#f7a072")},
	{"key": "gnomes", "label": "Gnomes", "color": Color("#c9a3e6")},
	{"key": "goblins", "label": "Goblins", "color": Color("#7f8c4d")},
	{"key": "kobolds", "label": "Kobolds", "color": Color("#b1c8ff")},
	{"key": "others", "label": "Others", "color": Color("#9e9e9e")}
]
const TOWN_POPULATION_RACE_OPTIONS := [
	{"key": "humans", "label": "Humans", "color": Color("#9bb6d8")},
	{"key": "dwarves", "label": "Dwarves", "color": Color("#f4c069")},
	{"key": "elves", "label": "Elves", "color": Color("#6ecf85")},
	{"key": "halflings", "label": "Halflings", "color": Color("#f7a072")},
	{"key": "gnomes", "label": "Gnomes", "color": Color("#c9a3e6")},
	{"key": "dragonborn", "label": "Dragonborn", "color": Color("#c16a6a")},
	{"key": "tieflings", "label": "Tieflings", "color": Color("#b064b0")},
	{"key": "others", "label": "Others", "color": Color("#9e9e9e")}
]
const WOOD_ELF_GROVE_POPULATION_ROLE_OPTIONS := [
	{"key": "elves", "label": "Wood Elves", "color": Color("#6ecf85")},
	{"key": "satyrs", "label": "Satyrs", "color": Color("#c18c5d")},
	{"key": "nymphs", "label": "Nymphs", "color": Color("#9bd4a9")},
	{"key": "ents", "label": "Ents", "color": Color("#8bbbcf")}
]
const LIZARDMEN_CITY_POPULATION_ROLE_OPTIONS := [
	{"key": "lizardmen", "label": "Lizardmen", "color": Color("#3a9f68")}
]
const DWARFHOLD_NAMES: Array[String] = [
	"Khazadûn Kharn",
	"Dhurnomli Bûr",
	"Zarak-az-Garaz",
	"Barûn-karag",
	"Gundûm Garmak",
	"Azar-khazad",
	"Thûrdrim Duraz",
	"Kazad-grimil",
	"Bêrdûm Barak",
	"Zirak-khazad",
	"Uzbad-az-Narg",
	"Karag Gor",
	"Dûmthûr Mîn",
	"Gûndâl Grum",
	"Thrâng-khazad",
	"Khirûn-karag",
	"Gazad-az-Bôr",
	"Dûrgrim Dûm",
	"Bazâr-durin",
	"Kharak-khazad",
	"Thûrdûn Thrum",
	"Gazûl-dûm",
	"Gor Dûrgheled",
	"Khûrmak Dûm",
	"Barak-dûrûn",
	"Gadrin-karag",
	"Mornûl Khazad",
	"Tharûm Barûn",
	"Dûr-az-Gor",
	"Kûzad Thrang",
	"Grumkhaz Dûm",
	"Narûm-barak",
	"Khûldar Narg",
	"Azûl-az-Khazad",
	"Dûmthrûn Garaz",
	"Grom-dûrin",
	"Khazdûl Garm",
	"Burin-dûm",
	"Zarak-nâl",
	"Thuldûn Karag",
	"Durgrûn Khazad",
	"Garak-dûm",
	"Tharn-az-Dûr",
	"Kharûm Grimdûm",
	"Balzûr Karûn",
	"Mûrkhaz Barak",
	"Thrûm-az-Garaz",
	"Gundûl-dûm",
	"Bârgrin Khazad",
	"Dûmbar Thûr",
	"Nûrgrim Karag",
	"Thûlûm Dûrûn",
	"Kharn-dûm-nâl",
	"Throgar-Mâl",
	"Krundûn Barak",
	"Dûrkhal Varrum",
	"Ghazdûr Grimbar",
	"Kuldûn-Dûr",
	"Brakûl Thrang",
	"Zarnak-dûm",
	"Throldar Kharn",
	"Mûldûn Grakhaz",
	"Durmûr Barûn",
	"Merûn Barin",
	"Dûldar Harnûm",
	"Bronarûm",
	"Kharalûn Dûr",
	"Garûn-kaz",
	"Thûrli Barûn",
	"Balnar Dûm",
	"Orûn Khazal",
	"Dûmren Thûr",
	"Beldûr Karûn",
	"Uldûm Nargaz",
	"Khardûl Barzûn",
	"Thûrkûn-Môr",
	"Zuldarûn",
	"Dûrthang Kharûz",
	"Brûm-dûl",
	"Gûldûn Thazrak",
	"Khazûr-Dumli",
	"Thrûnûl Barûz",
	"Mûrzan-Dûm",
	"Grendûl Varrin",
	"Kharnfell",
	"Dûmholm",
	"Barakdel",
	"Thûrdûn Holdfast",
	"Gromir Karûn",
	"Kharûm Tor",
	"Thulgar's Deep",
	"Brumkeldûm",
	"Dûrmar Hollow",
	"the Great Halls of Thorbardin",
	"Hammerguard",
	"Gor Karakazol",
	"Dur-Vazhatun",
	"Throal",
	"Dun-Ôrdstun",
	"Dûrandur",
	"Black Rock Hold",
	"Barat Nûmenz",
	"Dun Toruhm",
	"Karad-Graef",
	"Dûmthûr Mînrth",
	"Y'olazad-az-Bôr",
	"Gor Dûrgheld",
	"Dwemerhelm",
	"Tuwad-Dhumakon",
	"Skomdihir",
	"Hul-Jorkad",
	"Hul-Az-Krakazol",
	"Ovdal-az-An",
	"Orocarni",
	"Dun-Gardro",
	"Azrak Ordrim",
	"Dal Dulrah",
	"Dungrum",
	"Dun'ragram",
	"Karak Isural",
	"Sinterholm",
	"Karak-Dûmankon",
	"Grozumdihr",
	"Gor Ozumbrog",
	"Azad-Khas",
	"Karag Burag",
	"Hul-Kargdrum",
	"Karak-Duraz",
	"Tharn Khazrim",
	"Karak Grumdril",
	"Mirabar",
	"Dun Ashborun",
	"Avlar-Thrûn",
	"Grom's Peak",
	"Karak Gorûmzra",
	"Ostapchuk",
	"Dammerhall",
	"Almharaz",
	"Haraz Oldrum",
	"Elaig Drum",
	"Karak Ozambrald",
	"Ironhold",
	"Alvar-Baroag",
	"Ondrehrdin",
	"Azrak Zarak",
	"Dun Ezmar",
	"Azgark Metzger"
]
const DWARFHOLD_CLANS: Array[String] = [
	"Stonebeard",
	"Ironfist",
	"Deepdelve",
	"Bronzeborn",
	"Hammerfall",
	"Oakenshield",
	"Flintforge",
	"Granitejaw",
	"Runebinder",
	"Grimhelm",
	"Goldvein",
	"Frostmantle",
	"Fireforge",
	"Emberbrand",
	"Blackhammer"
]
## Dwarfhold ruler titles and names now live in NpcIdentityService
## (DWARF_RULER_TITLES_MALE/FEMALE/NEUTRAL, DWARF_DARK_RULER_TITLES and
## the gendered ruler name pools) so the overworld roll, the chronicle's
## succession lines and the hold's fallback ruler share one gendering.
const DWARFHOLD_GUILDS: Array[String] = [
	"Miners Guild",
	"Smiths Guild",
	"Stonewright Circle",
	"Runecarver Lodge",
	"Brewers Consortium",
	"Machinists Union",
	"Cartographers Hall"
]
const DWARFHOLD_EXPORTS: Array[String] = [
	"Iron ingots",
	"Steel tools",
	"Gemstones",
	"Runed stone",
	"Fine ale",
	"Machined gears",
	"Obsidian glass",
	"Granite blocks"
]
const DWARFHOLD_HALLMARKS: Array[String] = [
	"Renowned for its rune-forges and unbroken gates.",
	"Known for echoing halls lined with gilded reliefs.",
	"Famous for masterwork arms traded across the realm.",
	"Guarded by a renowned shieldwall of veteran thanes.",
	"Caravans arrive daily with ore from the lower delves."
]
const DWARFHOLD_ABANDONED_HALLMARKS: Array[String] = [
	"Silent halls lie sealed behind collapsed tunnels.",
	"Only the rumble of distant stonefall breaks the quiet.",
	"Old banners hang tattered above shuttered gates.",
	"Echoes of abandoned forges linger in the dust."
]

const TREE_BIOMES: Array[String] = TILE_ATLAS_DEFS.TREE_BIOMES
const TREE_BASE_BIOMES: Array[String] = TILE_ATLAS_DEFS.TREE_BASE_BIOMES
const TREE_VARIANT_FOREST_LONE := TILE_ATLAS_DEFS.TREE_VARIANT_FOREST_LONE
const TREE_VARIANT_TUNDRA_LONE := TILE_ATLAS_DEFS.TREE_VARIANT_TUNDRA_LONE


const CIVILIZATION_LABELS := {
	"humans": "Humans",
	"dwarves": "Dwarves",
	"wood_elves": "Wood Elves",
	"lizardmen": "Lizardmen",
	"desert_folk": "Desert Folk"
}

## World-event flavor only needs a sampling of named places, not the
## whole gazetteer.
const WORLD_ROSTER_SETTLEMENT_CAP := 40

## Ambient structures (camps, watchtowers, shrines, dens, cairns...) are
## written to the gazetteer as non-enterable landmarks so nearby wilds can
## stand them up on foot. Cap the list so the settings blob stays bounded.
const WORLD_AMBIENT_SITE_CAP := 2500

@onready var map_layer: TileMapLayer = $MapLayer
@onready var tree_layer: TileMapLayer = get_node_or_null("TreeLayer")
@onready var river_layer: TileMapLayer = get_node_or_null("RiverLayer")
@onready var highland_layer: TileMapLayer = get_node_or_null("HighlandLayer")
@onready var iceberg_layer: TileMapLayer = get_node_or_null("IcebergLayer")
@onready var settlement_layer: TileMapLayer = get_node_or_null("SettlementLayer")
@onready var map_overlays: Node2D = get_node_or_null("MapOverlays")
@onready var elevation_overlay: Sprite2D = get_node_or_null("MapOverlays/ElevationOverlay")
@onready var cliffs_overlay: Sprite2D = get_node_or_null("MapOverlays/CliffsOverlay")
@onready var temperature_overlay: Sprite2D = get_node_or_null("MapOverlays/TemperatureOverlay")
@onready var moisture_overlay: Sprite2D = get_node_or_null("MapOverlays/MoistureOverlay")
@onready var biome_overlay: Sprite2D = get_node_or_null("MapOverlays/BiomeOverlay")
@onready var terrain_shading_overlay: Sprite2D = get_node_or_null("MapOverlays/TerrainShadingOverlay")
@onready var culture_overlay: Sprite2D = get_node_or_null("MapOverlays/CultureOverlay")
@onready var political_boundaries_overlay: Sprite2D = get_node_or_null("MapOverlays/PoliticalBoundariesOverlay")
@onready var routes_overlay: Node2D = get_node_or_null("MapOverlays/RoutesOverlay")
@onready var rivers_overlay: Node2D = get_node_or_null("MapOverlays/RiversOverlay")
@onready var labels_overlay: Node2D = get_node_or_null("MapOverlays/LabelsOverlay")
@onready var political_labels_overlay: Node2D = get_node_or_null("MapOverlays/PoliticalLabelsOverlay")
@onready var overworld_camera: OverworldCamera = get_node_or_null("OverworldCamera")

## Far-zoom LOD: past this zoom the dense tile layers swap for one baked
## snapshot sprite (a tile is ~4px on screen there, so per-tile art is
## imperceptible). Settlements, labels and actors stay live.
const MAP_LOD_ZOOM_THRESHOLD := 0.45
const MAP_LOD_PX_PER_TILE := 2
var _map_snapshot_sprite: Sprite2D
var _map_lod_active := false
@onready var globe_view: Node3D = get_node_or_null("GlobeView")
@onready var globe_camera: Camera3D = get_node_or_null("GlobeView/GlobeCamera")
@onready var globe_mesh: MeshInstance3D = get_node_or_null("GlobeView/GlobeMesh")
@onready var scene3d_view: Node3D = get_node_or_null("Scene3DView")
@onready var scene3d_camera: Camera3D = get_node_or_null("Scene3DView/Scene3DCamera")
@onready var scene3d_mesh: MeshInstance3D = get_node_or_null("Scene3DView/Scene3DMesh")
@onready var map_viewport: SubViewport = get_node_or_null("MapViewport")
@onready var map_viewport_root: Node2D = get_node_or_null("MapViewport/MapViewportRoot")
@onready var regenerate_button: Button = get_node_or_null("MapUi/TopBar/TopBarLayout/RegenerateButton")
@onready var globe_view_button: Button = get_node_or_null("MapUi/TopBar/TopBarLayout/GlobeViewButton")
@onready var scene3d_view_button: Button = get_node_or_null("MapUi/TopBar/TopBarLayout/Scene3DViewButton")
@onready var temperature_map_button: Button = get_node_or_null("MapUi/TopBar/TopBarLayout/TemperatureMapButton")
@onready var elevation_map_button: Button = get_node_or_null("MapUi/TopBar/TopBarLayout/ElevationMapButton")
@onready var cliffs_map_button: Button = get_node_or_null("MapUi/TopBar/TopBarLayout/CliffsMapButton")
@onready var moisture_map_button: Button = get_node_or_null("MapUi/TopBar/TopBarLayout/MoistureMapButton")
@onready var biome_map_button: Button = get_node_or_null("MapUi/TopBar/TopBarLayout/BiomeMapButton")
@onready var culture_map_button: Button = get_node_or_null("MapUi/TopBar/TopBarLayout/CultureMapButton")
@onready var political_boundaries_button: Button = get_node_or_null("MapUi/TopBar/TopBarLayout/PoliticalBoundariesButton")
@onready var routes_map_button: Button = get_node_or_null("MapUi/TopBar/TopBarLayout/RoutesMapButton")
@onready var labels_map_button: Button = get_node_or_null("MapUi/TopBar/TopBarLayout/LabelsMapButton")
@onready var scale_bar_button: Button = get_node_or_null("MapUi/TopBar/TopBarLayout/ScaleBarButton")
@onready var scale_bar_container: Control = get_node_or_null("MapUi/ScaleBarContainer")
@onready var scale_bar_label: Label = get_node_or_null("MapUi/ScaleBarContainer/ScaleBarMargin/ScaleBarVBox/ScaleBarDistanceLabel")
@onready var scale_bar_visual: Control = get_node_or_null("MapUi/ScaleBarContainer/ScaleBarMargin/ScaleBarVBox/ScaleBarVisual")
@onready var loading_screen: Control = get_node_or_null("MapUi/LoadingScreen")
@onready var loading_bar: ProgressBar = get_node_or_null("MapUi/LoadingScreen/LoadingContainer/LoadingPanel/LoadingMargin/LoadingVBox/LoadingBar")
@onready var loading_subtitle: Label = get_node_or_null("MapUi/LoadingScreen/LoadingContainer/LoadingPanel/LoadingMargin/LoadingVBox/LoadingSubtitle")
@onready var loading_footer: Label = get_node_or_null("MapUi/LoadingScreen/LoadingContainer/LoadingPanel/LoadingMargin/LoadingVBox/LoadingFooter")

## The bar eases toward the latest stage percent instead of snapping, so it
## glides across the coarse generation stages; the footer shows the number.
const LOADING_EASE_RATE := 58.0
var _loading_progress_display := 0.0
var _loading_progress_target := 0.0
@onready var structure_context_menu: PopupMenu = get_node_or_null("MapUi/StructureContextMenu")
@onready var structure_details_dialog: AcceptDialog = get_node_or_null("MapUi/StructureDetailsDialog")
@onready var structure_details_tabs: TabContainer = get_node_or_null(
	"MapUi/StructureDetailsDialog/DetailsMargin/DetailsTabs"
)
@onready var structure_details_history_label: RichTextLabel = get_node_or_null(
	"MapUi/StructureDetailsDialog/DetailsMargin/DetailsTabs/History/HistoryText"
)
@onready var structure_details_main_label: RichTextLabel = get_node_or_null(
	"MapUi/StructureDetailsDialog/DetailsMargin/DetailsTabs/Main/MainHeader/MainText"
)
@onready var structure_details_main_image: TextureRect = get_node_or_null(
	"MapUi/StructureDetailsDialog/DetailsMargin/DetailsTabs/Main/MainHeader/MainImageFrame/MainImage"
)
@onready var structure_details_population_history_chart: Control = get_node_or_null(
	"MapUi/StructureDetailsDialog/DetailsMargin/DetailsTabs/Main/MainPopulationHistory/MainPopulationHistoryChart"
)
@onready var structure_details_features_label: RichTextLabel = get_node_or_null(
	"MapUi/StructureDetailsDialog/DetailsMargin/DetailsTabs/Features/FeaturesText"
)
@onready var structure_details_economy_label: RichTextLabel = get_node_or_null(
	"MapUi/StructureDetailsDialog/DetailsMargin/DetailsTabs/Economy/EconomyText"
)
@onready var tooltip_panel: PanelContainer = get_node_or_null("MapUi/MapTooltip")

## The Dwarf Fortress region zoom: double-clicking swaps the whole map for
## a walkable-detail rendering of the same world — streamed tile by tile
## around the camera, panned and zoomed exactly like the overworld itself.
const REGION_ENTER_BUDGET := 48
const REGION_KEEP_TILES := 1400
var _region_mode := false
var _region_layer: Node2D
var _region_icon_layer: Node2D
var _region_sprites := {}
var _region_render_queue: Array[Vector2i] = []
var _region_queued := {}
var _region_noise := {}
var _region_site_anchors: Array[Vector2i] = []
var _region_hint_panel: PanelContainer
var _region_jobs: Array[Dictionary] = []
var _region_cache_stamp := 0
var _is_generating := false
@onready var tooltip_title: Label = get_node_or_null("MapUi/MapTooltip/TooltipMargin/TooltipVBox/TooltipTitle")
@onready var tooltip_biome: Label = get_node_or_null("MapUi/MapTooltip/TooltipMargin/TooltipVBox/TooltipGrid/TooltipBiome")
@onready var tooltip_realm: Label = get_node_or_null("MapUi/MapTooltip/TooltipMargin/TooltipVBox/TooltipGrid/TooltipRealm")
@onready var tooltip_climate: Label = get_node_or_null("MapUi/MapTooltip/TooltipMargin/TooltipVBox/TooltipGrid/TooltipClimate")
@onready var tooltip_resources: Label = get_node_or_null("MapUi/MapTooltip/TooltipMargin/TooltipVBox/TooltipGrid/TooltipResources")
@onready var tooltip_major_population_groups: Label = get_node_or_null("MapUi/MapTooltip/TooltipMargin/TooltipVBox/TooltipGrid/TooltipMajorPopulationGroups")
@onready var tooltip_minor_population_groups: Label = get_node_or_null("MapUi/MapTooltip/TooltipMargin/TooltipVBox/TooltipGrid/TooltipMinorPopulationGroups")
@onready var tooltip_settlement: Label = get_node_or_null("MapUi/MapTooltip/TooltipMargin/TooltipVBox/TooltipGrid/TooltipSettlement")
@onready var tooltip_population: Label = get_node_or_null("MapUi/MapTooltip/TooltipMargin/TooltipVBox/TooltipGrid/TooltipPopulation")
@onready var tooltip_ruler: Label = get_node_or_null("MapUi/MapTooltip/TooltipMargin/TooltipVBox/TooltipGrid/TooltipRuler")
@onready var tooltip_founded: Label = get_node_or_null("MapUi/MapTooltip/TooltipMargin/TooltipVBox/TooltipGrid/TooltipFounded")
@onready var tooltip_prominent_clan: Label = get_node_or_null("MapUi/MapTooltip/TooltipMargin/TooltipVBox/TooltipGrid/TooltipProminentClan")
@onready var tooltip_major_clans: Label = get_node_or_null("MapUi/MapTooltip/TooltipMargin/TooltipVBox/TooltipGrid/TooltipMajorClans")
@onready var tooltip_major_guilds: Label = get_node_or_null("MapUi/MapTooltip/TooltipMargin/TooltipVBox/TooltipGrid/TooltipMajorGuilds")
@onready var tooltip_major_exports: Label = get_node_or_null("MapUi/MapTooltip/TooltipMargin/TooltipVBox/TooltipGrid/TooltipMajorExports")
@onready var tooltip_hallmark: Label = get_node_or_null("MapUi/MapTooltip/TooltipMargin/TooltipVBox/TooltipGrid/TooltipHallmark")
@onready var tooltip_population_breakdown_section: Control = get_node_or_null(
	"MapUi/MapTooltip/TooltipMargin/TooltipVBox/TooltipPopulationBreakdown"
)
@onready var tooltip_population_breakdown_list: VBoxContainer = get_node_or_null(
	"MapUi/MapTooltip/TooltipMargin/TooltipVBox/TooltipPopulationBreakdown/PopulationBreakdownContent/PopulationBreakdownList"
)
@onready var tooltip_population_pie_chart: Control = get_node_or_null(
	"MapUi/MapTooltip/TooltipMargin/TooltipVBox/TooltipPopulationBreakdown/PopulationBreakdownContent/PopulationPieChart"
)
var _atlas_source_id := -1
var _river_atlas_source_id := -1
var _coast_layer: TileMapLayer
var _coast_source_id := -1
var _temperature_noise: FastNoiseLite
var _snow_edge_noise: FastNoiseLite
var _rainfall_noise: FastNoiseLite
var _rainfall_detail_noise: FastNoiseLite
var _desert_band_noise: FastNoiseLite
var _desert_heat_noise: FastNoiseLite
var _desert_detail_noise: FastNoiseLite
var _marsh_variation_noise: FastNoiseLite
var _vegetation_noise: FastNoiseLite
var _rainfall_buffer: PackedFloat32Array = PackedFloat32Array()
var _desert_suitability_buffer: PackedFloat32Array = PackedFloat32Array()
var _desert_heat_buffer: PackedFloat32Array = PackedFloat32Array()
## Combined mountain scores from _build_highland_overlays (browser
## mountainScores); dwarfhold/mine placement reuses them.
var _mountain_score_buffer: PackedFloat32Array = PackedFloat32Array()
var _mountain_candidate_threshold := 0.45
## Flat per-cell terrain buffers shared by the settlement/structure
## placement passes (built once in _place_settlements).
var _placement_fields: Dictionary = {}
## Settlement point sets recorded during placement (browser towns[],
## dwarfholds[], ... arrays) so later passes can enforce distances.
var _town_points: Array[Vector2i] = []
var _hamlet_points: Array[Vector2i] = []
var _dwarfhold_points: Array[Vector2i] = []
var _grove_points: Array[Vector2i] = []
var _lizardmen_city_points: Array[Vector2i] = []
var _desert_city_points: Array[Vector2i] = []
var _hillhold_points: Array[Vector2i] = []
## Per-layout knobs (browser worldGenerationProfiles, main.js:20044-20108).
var _sea_level_shift := 0.02
var _rainfall_bias := 0.0
## The layout's baseline water_level, captured before _estimate_sea_level
## overwrites the export - regeneration must restart from this baseline or
## the same seed yields a different world on regen vs fresh boot.
var _layout_water_level := -1.0
## Slider biases (browser main.js:21300-21331).
var _mountain_ratio := 0.5
var _forest_bias := 0.0
var _tile_data: Dictionary = {}
var _tile_region_names: Dictionary = {}
var _tile_population_groups: Dictionary = {}
## Autowrap labels over-report their minimum height on the frame their text
## changes: they reshape at a stale, near-zero width, wrapping every word onto
## its own line, so a same-frame combined-minimum can be several screens tall
## (and Control.set_size clamps UP to that minimum, so it can't just be shrunk).
## We therefore park the freshly-populated panel off-screen — laid out, so the
## labels reshape at their real width — and only place it on-screen once the
## measured minimum comes back IDENTICAL on two consecutive frames. (The old
## "taller than the viewport" plausibility test let any over-report that still
## fit the screen through: on a 1876px-tall window a ~1770px ghost panel
## flashed for one frame every time the hovered tile changed.) This tracks the
## pending state, the last measurement, and the tile whose content is loaded.
var _tooltip_settle_pending := false
var _tooltip_last_measured_min := Vector2(-1.0, -1.0)
var _tooltip_content_coord := Vector2i(-9999, -9999)
var _height_map: Dictionary = {}
var _height_buffer: PackedFloat32Array = PackedFloat32Array()
var _height_texture: ImageTexture = null
var _temperature_map: Dictionary = {}
var _temperature_buffer: PackedFloat32Array = PackedFloat32Array()
var _moisture_map: Dictionary = {}
var _moisture_buffer: PackedFloat32Array = PackedFloat32Array()
var _biome_map: Dictionary = {}
var _biome_buffer: PackedByteArray = PackedByteArray()
var _world_settings: Dictionary = {}
var _culture_pipeline := CulturalInfluence.new()
var _landmass_centers: Array[Vector2] = []
var _map_layer_original_parent: Node = null
var _map_layer_original_index := -1
var _tree_layer_original_parent: Node = null
var _tree_layer_original_index := -1
var _river_layer_original_parent: Node = null
var _river_layer_original_index := -1
var _highland_layer_original_parent: Node = null
var _highland_layer_original_index := -1
var _iceberg_layer_original_parent: Node = null
var _iceberg_layer_original_index := -1
var _settlement_layer_original_parent: Node = null
var _settlement_layer_original_index := -1
var _overlays_original_parent: Node = null
var _overlays_original_index := -1
var _is_globe_view := false
var _is_dragging_globe := false
var _is_scene3d_view := false
var _is_dragging_scene3d := false
var _elevation_overlay_enabled := false
var _cliffs_overlay_enabled := false
var _temperature_overlay_enabled := false
var _moisture_overlay_enabled := false
var _biome_overlay_enabled := false
var _culture_overlay_enabled := false
var _political_boundaries_overlay_enabled := false
var _routes_overlay_enabled := false
var _labels_overlay_enabled := true
var _scale_bar_enabled := true
var _route_segments: Array = []
var _caravans_layer: Node2D
var _caravan_states: Array[Dictionary] = []
var _caravan_texture: Texture2D
var _escape_menu: EscapeMenu
var _chronology_year := 1000
var _is_first_age := false
var _world_name := ""
var _world_name_label: Label
var _roads_layer: TileMapLayer
var _ships_layer: Node2D
var _ship_states: Array[Dictionary] = []
var _overlay_dirty := {
	"elevation": true,
	"temperature": true,
	"moisture": true,
	"biome": true,
	"culture": true,
	"political_boundaries": true,
	"cliffs": true
}
var _hovered_tile := Vector2i(-999, -999)
var _context_menu_tile := Vector2i(-1, -1)
## The simulated chronicle of the age (WorldChronicleService.simulate output).
var _world_chronicle: Dictionary = {}
var _world_chronicle_button: Button
var _world_chronicle_dialog: AcceptDialog
var _world_chronicle_label: RichTextLabel

const CONTEXT_MENU_BEGIN_JOURNEY_ID := 0
const CONTEXT_MENU_MORE_INFORMATION_ID := 1
const DWARFHOLD_GENERATION_SCENE_PATH := "res://scenes/dwarf_hold_generation.tscn"
const DWARFHOLD_SCENE_SEED_KEY := "dwarfhold_scene_seed"
const DWARFHOLD_SCENE_TILE_KEY := "dwarfhold_scene_tile"
const DWARFHOLD_SCENE_NAME_KEY := "dwarfhold_scene_name"
const DWARFHOLD_SCENE_POPULATION_KEY := "dwarfhold_scene_population"
## Fall summary for abandoned holds ("Fell to <beast>, year <y>") so the
## ruin's scene can show why its halls are silent.
const DWARFHOLD_SCENE_FALL_KEY := "dwarfhold_scene_fall_text"
const TOWN_GENERATION_SCENE_PATH := "res://scenes/town_generation.tscn"
const TOWN_SCENE_SEED_KEY := "town_scene_seed"
const TOWN_SCENE_TILE_KEY := "town_scene_tile"
const TOWN_SCENE_NAME_KEY := "town_scene_name"
const TOWN_SCENE_POPULATION_KEY := "town_scene_population"
const TOWN_SCENE_THEME_KEY := "town_scene_theme"
const TOWN_SCENE_VILLAGE_KEY := "town_scene_is_village"
## The full overworld biome buffer, so the wilds keep matching the world
## map however far a walker strays from a settlement - no window edge to
## wall the terrain back to grassland.
const TOWN_SCENE_WORLD_BIOMES_KEY := "town_scene_world_biomes"
const TOWN_SCENE_WORLD_RIVERS_KEY := "town_scene_world_rivers"
## Set true when the walker embarks onto an open wild tile (no settlement):
## the town scene then raises a bare biome clearing instead of a city.
const TOWN_SCENE_WILD_KEY := "town_scene_is_wild"
## Set true when that wild tile is open water: the clearing is drawn as sea
## and the player is dropped afloat on the ocean rather than on dry ground.
const TOWN_SCENE_WILD_WATER_KEY := "town_scene_wild_water"
const DUNGEON_INTERIOR_SCENE_PATH := "res://scenes/dungeon_interior.tscn"
const DUNGEON_SCENE_SEED_KEY := "dungeon_scene_seed"
const DUNGEON_SCENE_NAME_KEY := "dungeon_scene_name"
const MORE_INFO_IMAGE_FOLDER := "res://resources/images/overworld/more_info"
const GENERATION_YIELD_ROW_INTERVAL := 32
const GENERATION_YIELD_CELL_INTERVAL := 1024

const NEIGHBOR_OFFSETS_8: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)
]
## Index-paired opposites for NEIGHBOR_OFFSETS_8 (browser directionOpposites).
const NEIGHBOR_OPPOSITES_8: Array[int] = [7, 6, 5, 4, 3, 2, 1, 0]

## Browser computeSnowPresence band (main.js:21607-21635): snow is NORTH-only,
## guaranteed above latitude 0.86, noise-thinned through 0.5..0.86, absent
## south of 0.5. latitude = 1 - normalizedY (north = top of the map).
const SNOW_LATITUDE_START := 0.5
const SNOW_LATITUDE_FULL := 0.86
## Minimum Chebyshev distance (tiles) kept clear between desert sand and
## tundra; the belt in between stays grassland so the climates never
## touch, and noise fades the belt out over four more tiles beyond it.
const DESERT_SNOW_BUFFER_RADIUS := 6

## Browser marsh model (main.js:21671-21673).
const MARSH_BASE_THRESHOLD := 0.65
const MARSH_WETNESS_THRESHOLD := 0.66

var _more_info_image_paths: Array[String] = []
var _more_info_texture_cache: Dictionary = {}
var _more_info_cache_initialized := false
var _landmass_masks: Dictionary = {}

## Re-attached from the scene cache (which restarts the parked theme
## itself; nothing extra needed here yet).
func _on_scene_resumed() -> void:
	pass

func _ready() -> void:
	if map_layer == null:
		push_error("Overworld map is missing a TileMapLayer named MapLayer.")
		return
	GameAudioService.play_music(self, "overworld")
	_escape_menu = EscapeMenu.new()
	add_child(_escape_menu)
	_show_loading_screen()
	await get_tree().process_frame
	_apply_cached_world_settings()
	_configure_tileset()
	_configure_overworld_camera_bounds()
	await _generate_map()
	_hide_loading_screen()
	if regenerate_button == null:
		push_error("Overworld map is missing a RegenerateButton at MapUi/TopBar/TopBarLayout/RegenerateButton.")
	else:
		regenerate_button.pressed.connect(_on_regenerate_pressed)
	if globe_view_button != null:
		globe_view_button.toggled.connect(_on_globe_view_toggled)
		globe_view_button.button_pressed = false
	if scene3d_view_button != null:
		scene3d_view_button.toggled.connect(_on_scene3d_view_toggled)
		scene3d_view_button.button_pressed = false
	if temperature_map_button != null:
		temperature_map_button.toggled.connect(_on_temperature_map_toggled)
		temperature_map_button.button_pressed = false
	if elevation_map_button != null:
		elevation_map_button.toggled.connect(_on_elevation_map_toggled)
		elevation_map_button.button_pressed = false
	if cliffs_map_button != null:
		cliffs_map_button.toggled.connect(_on_cliffs_map_toggled)
		cliffs_map_button.button_pressed = false
		cliffs_map_button.tooltip_text = "Toggle the cliff map: shaded relief with escarpments burned in dark"
	if moisture_map_button != null:
		moisture_map_button.toggled.connect(_on_moisture_map_toggled)
		moisture_map_button.button_pressed = false
	if biome_map_button != null:
		biome_map_button.toggled.connect(_on_biome_map_toggled)
		biome_map_button.button_pressed = false
	if culture_map_button != null:
		culture_map_button.toggled.connect(_on_culture_map_toggled)
		culture_map_button.button_pressed = false
	if political_boundaries_button != null:
		political_boundaries_button.toggled.connect(_on_political_boundaries_toggled)
		political_boundaries_button.button_pressed = false
	if routes_map_button != null:
		routes_map_button.toggled.connect(_on_routes_map_toggled)
		routes_map_button.button_pressed = false
	if labels_map_button != null:
		labels_map_button.toggled.connect(_on_labels_map_toggled)
		labels_map_button.button_pressed = _labels_overlay_enabled
		labels_map_button.tooltip_text = "Toggle settlement labels overlay"
	if scale_bar_button != null:
		scale_bar_button.toggled.connect(_on_scale_bar_toggled)
		scale_bar_button.button_pressed = _scale_bar_enabled
	if overworld_camera != null:
		overworld_camera.zoom_changed.connect(_on_overworld_camera_zoom_changed)
	_refresh_scale_bar()
	_cache_map_layer_parent()
	_cache_tree_layer_parent()
	_cache_river_layer_parent()
	_cache_highland_layer_parent()
	_cache_iceberg_layer_parent()
	_cache_settlement_layer_parent()
	_cache_overlay_parent()
	_configure_globe_viewport()
	_configure_scene3d_mesh()
	_set_globe_view(false)
	_set_scene3d_view(false)
	_update_labels_overlay_visibility()
	call_deferred("_cache_more_info_image_paths")
	_configure_structure_context_menu()
	_setup_world_chronicle_ui()

func _on_overworld_camera_zoom_changed(_zoom_level: float) -> void:
	_refresh_scale_bar()
	_update_labels_overlay_zoom_behavior()
	_update_political_labels_zoom_behavior()

func _refresh_scale_bar() -> void:
	if scale_bar_container == null or scale_bar_visual == null or scale_bar_label == null:
		return
	if not _scale_bar_enabled:
		scale_bar_container.visible = false
		return
	if _is_globe_view or _is_scene3d_view:
		scale_bar_container.visible = false
		return
	if overworld_camera == null:
		scale_bar_container.visible = false
		return
	var safe_zoom := maxf(overworld_camera.zoom.x, 0.001)
	# Godot 4: screen pixels per world pixel = zoom, so zooming IN means
	# MORE pixels per km (the bar then steps its labelled distance down).
	var pixels_per_km := float(tile_size) * safe_zoom / maxf(kilometers_per_tile, 0.001)
	if scale_bar_visual.has_method("set_scale_display"):
		scale_bar_visual.call("set_scale_display", pixels_per_km)
	if scale_bar_visual.has_method("get_distance_label"):
		scale_bar_label.text = str(scale_bar_visual.call("get_distance_label"))
	scale_bar_container.visible = true

func _show_loading_screen() -> void:
	if loading_screen != null:
		loading_screen.visible = true
	_loading_progress_display = 0.0
	_set_loading_progress(3.0, "Surveying continental plates...")

func _hide_loading_screen() -> void:
	if loading_screen != null:
		loading_screen.visible = false

## The bar tracks real generation stages; the subtitle narrates them.
## The value is a target the bar eases toward in _process (redraws ride the
## generation waves that already yield to the frame), so it glides across the
## coarse stages instead of jumping. The footer shows the live percentage.
func _set_loading_progress(percent: float, subtitle: String = "") -> void:
	_loading_progress_target = clampf(percent, 0.0, 100.0)
	if loading_subtitle != null and not subtitle.is_empty():
		loading_subtitle.text = subtitle

## Eases the bar toward its target and mirrors it in the footer percentage.
## Called every rendered frame the loading screen is up.
func _update_loading_bar(delta: float) -> void:
	_loading_progress_display = move_toward(_loading_progress_display, _loading_progress_target, delta * LOADING_EASE_RATE)
	if _loading_progress_target >= 99.9:
		# The final stage snaps home so the reveal never lands mid-glide.
		_loading_progress_display = _loading_progress_target
	if loading_bar != null:
		loading_bar.value = _loading_progress_display
	if loading_footer != null:
		loading_footer.text = "%d%% · Please wait while the realm is generated." % int(round(_loading_progress_display))

func _build_map_snapshot() -> void:
	if _tile_data.is_empty():
		return
	var image := Image.create(map_size.x * MAP_LOD_PX_PER_TILE, map_size.y * MAP_LOD_PX_PER_TILE, false, Image.FORMAT_RGBA8)
	var biome_colors := {
		BIOME_WATER: Color(0.16, 0.32, 0.55),
		BIOME_GRASSLAND: Color(0.36, 0.55, 0.28),
		BIOME_FOREST: Color(0.22, 0.42, 0.22),
		BIOME_JUNGLE: Color(0.16, 0.38, 0.24),
		BIOME_DESERT: Color(0.78, 0.70, 0.47),
		BIOME_BADLANDS: Color(0.62, 0.45, 0.32),
		BIOME_MOUNTAIN: Color(0.52, 0.50, 0.48),
		BIOME_HILLS: Color(0.45, 0.50, 0.36),
		BIOME_MARSH: Color(0.32, 0.44, 0.36),
		BIOME_TUNDRA: Color(0.78, 0.80, 0.78)
	}
	for y in range(map_size.y):
		for x in range(map_size.x):
			var coord := Vector2i(x, y)
			var info := _tile_data.get(coord, {}) as Dictionary
			# Default to grassland (not id 0 = water) so a tile missing its
			# biome id never renders as a phantom ocean, matching the rest
			# of the pipeline's fallback.
			var grassland_id := _biome_to_id(BIOME_GRASSLAND)
			var base_biome := _biome_id_to_string(int(info.get("base_biome_id", grassland_id)))
			var color := biome_colors.get(base_biome, Color(0.36, 0.55, 0.28)) as Color
			var flags := int(info.get("overlay_flags", 0))
			if flags & TILE_OVERLAY_RIVER:
				color = Color(0.24, 0.42, 0.62)
			elif flags & (TILE_OVERLAY_TREE | TILE_OVERLAY_FOREST):
				color = color.darkened(0.18)
			var hill_biome := _biome_id_to_string(int(info.get("hill_biome_id", grassland_id)))
			if hill_biome == BIOME_MOUNTAIN:
				color = biome_colors[BIOME_MOUNTAIN]
			elif hill_biome == BIOME_HILLS:
				color = color.lerp(biome_colors[BIOME_HILLS], 0.6)
			for py in range(MAP_LOD_PX_PER_TILE):
				for px in range(MAP_LOD_PX_PER_TILE):
					image.set_pixel(x * MAP_LOD_PX_PER_TILE + px, y * MAP_LOD_PX_PER_TILE + py, color)
	if _map_snapshot_sprite == null:
		_map_snapshot_sprite = Sprite2D.new()
		_map_snapshot_sprite.centered = false
		_map_snapshot_sprite.z_index = map_layer.z_index if map_layer != null else 0
		_map_snapshot_sprite.visible = false
		add_child(_map_snapshot_sprite)
		if map_layer != null:
			move_child(_map_snapshot_sprite, map_layer.get_index())
	_map_snapshot_sprite.texture = ImageTexture.create_from_image(image)
	_map_snapshot_sprite.scale = Vector2.ONE * (float(tile_size) / float(MAP_LOD_PX_PER_TILE))

func _update_map_lod() -> void:
	# Full detail at every zoom: the painted tile layers ARE the map.
	# (The old far-zoom snapshot swap read as "simplified" - gone.)
	if _region_mode:
		return
	if _map_snapshot_sprite != null and _map_snapshot_sprite.visible:
		_map_snapshot_sprite.visible = false
	if not _map_lod_active:
		return
	_map_lod_active = false
	for layer: TileMapLayer in [map_layer, tree_layer, river_layer, highland_layer, iceberg_layer, _coast_layer]:
		if layer != null:
			layer.visible = true

func _process(delta: float) -> void:
	if loading_screen != null and loading_screen.visible:
		_update_loading_bar(delta)
	_update_map_tooltip()
	_update_caravans(delta)
	_update_pirate_ships(delta)
	_update_map_lod()
	if _region_mode:
		_stream_region_tiles()
	if _is_globe_view:
		_rotate_globe(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _region_mode:
			_exit_region_mode()
			get_viewport().set_input_as_handled()
			return
		if _escape_menu != null:
			_escape_menu.toggle()
			get_viewport().set_input_as_handled()
		return
	if _is_globe_view and _handle_globe_input(event):
		return
	if _is_scene3d_view and _handle_scene3d_input(event):
		return
	if _handle_double_click_dive(event):
		get_viewport().set_input_as_handled()
		return
	if _handle_structure_context_menu_input(event):
		get_viewport().set_input_as_handled()
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed:
		return
	if key_event.keycode == KEY_R:
		await _regenerate_map()

func _on_regenerate_pressed() -> void:
	await _regenerate_map()

func _on_globe_view_toggled(is_pressed: bool) -> void:
	if is_pressed:
		if scene3d_view_button != null:
			scene3d_view_button.set_pressed_no_signal(false)
		_set_scene3d_view(false)
	_set_globe_view(is_pressed)

func _on_scene3d_view_toggled(is_pressed: bool) -> void:
	if is_pressed:
		if globe_view_button != null:
			globe_view_button.set_pressed_no_signal(false)
		_set_globe_view(false)
	_set_scene3d_view(is_pressed)

func _on_temperature_map_toggled(is_pressed: bool) -> void:
	_temperature_overlay_enabled = is_pressed
	if is_pressed:
		_ensure_overlay_texture("temperature")
	_update_temperature_overlay_visibility()

func _on_elevation_map_toggled(is_pressed: bool) -> void:
	_elevation_overlay_enabled = is_pressed
	if is_pressed:
		_ensure_overlay_texture("elevation")
	_update_elevation_overlay_visibility()

func _on_cliffs_map_toggled(is_pressed: bool) -> void:
	_cliffs_overlay_enabled = is_pressed
	if is_pressed:
		_ensure_overlay_texture("cliffs")
	_update_cliffs_overlay_visibility()

func _on_moisture_map_toggled(is_pressed: bool) -> void:
	_moisture_overlay_enabled = is_pressed
	if is_pressed:
		_ensure_overlay_texture("moisture")
	_update_moisture_overlay_visibility()

func _on_biome_map_toggled(is_pressed: bool) -> void:
	_biome_overlay_enabled = is_pressed
	if is_pressed:
		_ensure_overlay_texture("biome")
	_update_biome_overlay_visibility()

func _on_culture_map_toggled(is_pressed: bool) -> void:
	_culture_overlay_enabled = is_pressed
	if is_pressed:
		_ensure_overlay_texture("culture")
	_update_culture_overlay_visibility()

func _on_political_boundaries_toggled(is_pressed: bool) -> void:
	_political_boundaries_overlay_enabled = is_pressed
	if is_pressed:
		_ensure_overlay_texture("political_boundaries")
	_update_political_boundaries_overlay_visibility()

func _on_routes_map_toggled(is_pressed: bool) -> void:
	_routes_overlay_enabled = is_pressed
	_update_routes_overlay_visibility()

func _on_labels_map_toggled(is_pressed: bool) -> void:
	_labels_overlay_enabled = is_pressed
	_update_labels_overlay_visibility()

func _on_scale_bar_toggled(is_pressed: bool) -> void:
	_scale_bar_enabled = is_pressed
	_refresh_scale_bar()

func _configure_structure_context_menu() -> void:
	if structure_context_menu == null:
		return
	structure_context_menu.clear()
	structure_context_menu.add_item("Begin your journey here", CONTEXT_MENU_BEGIN_JOURNEY_ID)
	structure_context_menu.add_item("More information", CONTEXT_MENU_MORE_INFORMATION_ID)
	if not structure_context_menu.id_pressed.is_connected(_on_structure_context_menu_id_pressed):
		structure_context_menu.id_pressed.connect(_on_structure_context_menu_id_pressed)

func _handle_structure_context_menu_input(event: InputEvent) -> bool:
	# Globe and 3D views have no meaningful tile under the mouse - the
	# reparented map layer would resolve an arbitrary one near the origin.
	if _is_globe_view or _is_scene3d_view:
		return false
	var mouse_button_event := event as InputEventMouseButton
	if mouse_button_event == null:
		return false

	if not mouse_button_event.pressed:
		if mouse_button_event.button_index == MOUSE_BUTTON_LEFT and structure_context_menu != null and structure_context_menu.visible:
			structure_context_menu.hide()
		return false

	if mouse_button_event.button_index != MOUSE_BUTTON_RIGHT:
		return false

	if map_layer == null:
		return true

	var tile_coord := _get_tile_coord_from_global_position(get_global_mouse_position())
	if not _is_valid_map_coord(tile_coord):
		if structure_context_menu != null:
			structure_context_menu.hide()
		return true

	_context_menu_tile = tile_coord
	if structure_context_menu != null:
		structure_context_menu.position = mouse_button_event.position
		structure_context_menu.popup()
	return true

func _get_tile_coord_from_global_position(world_pos: Vector2) -> Vector2i:
	if map_layer == null:
		return Vector2i(-1, -1)
	var local_mouse := map_layer.to_local(world_pos)
	return map_layer.local_to_map(local_mouse)

func _is_valid_map_coord(coord: Vector2i) -> bool:
	return OVERWORLD_INTERACTION.is_valid_map_coord(coord, map_size)

func _map_cell_count() -> int:
	return OVERWORLD_GENERATION.map_cell_count(map_size)

func _coord_to_index(coord: Vector2i) -> int:
	return coord.y * map_size.x + coord.x

func _xy_to_index(x: int, y: int) -> int:
	return y * map_size.x + x

func _index_to_coord(index: int) -> Vector2i:
	return OVERWORLD_GENERATION.index_to_coord(index, map_size)

func _biome_to_id(biome: String) -> int:
	return int(_BIOME_TO_ID.get(biome, int(_BIOME_TO_ID[BIOME_GRASSLAND])))

func _biome_id_to_string(biome_id: int) -> String:
	if biome_id < 0 or biome_id >= _ID_TO_BIOME.size():
		return BIOME_GRASSLAND
	return _ID_TO_BIOME[biome_id]

func _ensure_map_buffers() -> void:
	var cell_count := _map_cell_count()
	if _height_buffer.size() != cell_count:
		_height_buffer.resize(cell_count)
	if _temperature_buffer.size() != cell_count:
		_temperature_buffer.resize(cell_count)
	if _moisture_buffer.size() != cell_count:
		_moisture_buffer.resize(cell_count)
	if _biome_buffer.size() != cell_count:
		_biome_buffer.resize(cell_count)

func _dictionary_to_float_buffer(source_map: Dictionary, default_value: float = 0.0) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	var cell_count := _map_cell_count()
	buffer.resize(cell_count)
	for y in range(map_size.y):
		for x in range(map_size.x):
			var coord := Vector2i(x, y)
			buffer[_xy_to_index(x, y)] = float(source_map.get(coord, default_value))
	return buffer

func _dictionary_to_biome_buffer(source_map: Dictionary, default_biome: String = BIOME_GRASSLAND) -> PackedByteArray:
	var buffer := PackedByteArray()
	var cell_count := _map_cell_count()
	buffer.resize(cell_count)
	for y in range(map_size.y):
		for x in range(map_size.x):
			var coord := Vector2i(x, y)
			var biome := String(source_map.get(coord, default_biome))
			buffer[_xy_to_index(x, y)] = _biome_to_id(biome)
	return buffer

func _float_buffer_to_dictionary(buffer: PackedFloat32Array) -> Dictionary:
	var map: Dictionary = {}
	for i in range(buffer.size()):
		map[_index_to_coord(i)] = float(buffer[i])
	return map

func _biome_buffer_to_dictionary(buffer: PackedByteArray) -> Dictionary:
	var map: Dictionary = {}
	for i in range(buffer.size()):
		map[_index_to_coord(i)] = _biome_id_to_string(int(buffer[i]))
	return map

func _on_structure_context_menu_id_pressed(action_id: int) -> void:
	var clicked_tile := _context_menu_tile
	if structure_context_menu != null:
		structure_context_menu.hide()
	if not _is_valid_map_coord(clicked_tile):
		return

	match action_id:
		CONTEXT_MENU_BEGIN_JOURNEY_ID:
			_begin_journey_from_tile(clicked_tile)
		CONTEXT_MENU_MORE_INFORMATION_ID:
			_open_structure_details_from_context_menu(clicked_tile)

## Dwarf Fortress-style dive: a double-click glides the camera down
## onto the tile; if a site sits there, the journey begins on landing.
## Wild tiles just get the zoom - the closer look is its own reward.
const DIVE_ZOOM := 3.2
const DIVE_SECONDS := 0.85
## Detailed view is real tile art, so it rewards a much closer look than the
## world map: while in region mode the camera cap lifts to this, restored on
## exit. Remembers the world-map cap so the two never leak into each other.
const REGION_MAX_ZOOM := 12.0
## Half-extent cap (in tiles) of the region detail streamer's window —
## shared by _camera_visible_tile_rect and the region zoom floor so the
## two can never drift apart.
const REGION_STREAM_HALF_TILES := Vector2i(25, 13)
var _world_map_max_zoom := -1.0
var _world_map_min_zoom := -1.0
var _dive_pending := false

func _handle_double_click_dive(event: InputEvent) -> bool:
	var mouse_button_event := event as InputEventMouseButton
	if mouse_button_event == null or not mouse_button_event.pressed or not mouse_button_event.double_click:
		return false
	if mouse_button_event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if _is_globe_view or _is_scene3d_view or _dive_pending:
		return false
	# A dive during the awaited regeneration would enter region mode on a
	# half-built map, and the fit that ends generation would then wipe the
	# region zoom floor — leaving a mostly-blank detail view.
	if _is_generating:
		return false
	if overworld_camera == null or map_layer == null:
		return false
	var tile_coord := _get_tile_coord_from_global_position(get_global_mouse_position())
	if not _is_valid_map_coord(tile_coord):
		return false
	_dive_into_tile(tile_coord)
	return true

func _dive_into_tile(tile_coord: Vector2i) -> void:
	var details := _tile_data.get(tile_coord, {}) as Dictionary
	var enterable := _tile_supports_journey(details)
	var landing := map_layer.to_global(map_layer.map_to_local(tile_coord))
	var target_zoom := maxf(overworld_camera.zoom.x * 2.4, DIVE_ZOOM) if enterable else clampf(overworld_camera.zoom.x * 2.0, 0.2, DIVE_ZOOM)
	var was_region_mode := _region_mode
	_dive_pending = true
	var tween: Tween = overworld_camera.dive_to(landing, target_zoom, DIVE_SECONDS)
	await tween.finished
	_dive_pending = false
	# Esc (or a view toggle) mid-dive changed the mode already - honor
	# that choice instead of undoing it on landing.
	if _region_mode != was_region_mode:
		return
	# Dwarf Fortress style: the first dive switches the whole map into
	# the detailed region view; diving again inside it walks into
	# settlements (right-click Begin Journey works there too).
	if _region_mode:
		if enterable:
			_begin_journey_from_tile(tile_coord)
	else:
		_enter_region_mode()

func _tile_supports_journey(details: Dictionary) -> bool:
	if details.is_empty():
		return false
	# Every tile is now enterable: settlements open their scene, and any other
	# tile - land or open water - embarks into the wilds (a bare clearing on
	# land, a tiny isle ringed by ocean on water).
	return true

func _begin_journey_from_tile(tile_coord: Vector2i) -> void:
	var details := _tile_data.get(tile_coord, {}) as Dictionary
	if details.is_empty():
		return

	if _is_dwarfhold_structure(details):
		var dwarfhold_seed := _dwarfhold_scene_seed_for_tile(tile_coord, details)
		if dwarfhold_seed.is_empty():
			print("Unable to resolve dwarfhold scene seed for %s" % tile_coord)
			return
		_store_selected_dwarfhold_scene_context(dwarfhold_seed, tile_coord, details)
		SceneCacheService.request_change(self, DWARFHOLD_GENERATION_SCENE_PATH)
		return

	if _is_town_settlement(details):
		var town_seed := _town_scene_seed_for_tile(tile_coord, details)
		_store_selected_town_scene_context(town_seed, tile_coord, details, _town_theme_for_details(details))
		SceneCacheService.request_change(self, TOWN_GENERATION_SCENE_PATH)
		return

	if _is_dungeon_structure(details):
		var dungeon_seed := _dungeon_scene_seed_for_tile(tile_coord, details)
		_store_selected_dungeon_scene_context(dungeon_seed, tile_coord, details)
		SceneCacheService.request_change(self, DUNGEON_INTERIOR_SCENE_PATH)
		return

	# Wild (non-settlement) tiles: embark into the open biome wilds. The town
	# scene is reused - it already streams biome-appropriate terrain around a
	# grid center - but flagged to raise a bare clearing with no settlement.
	# Water tiles embark too: the clearing becomes a small isle and the
	# streamer surrounds it with open ocean.
	var wild_seed := _wild_scene_seed_for_tile(tile_coord, details)
	_store_selected_wild_scene_context(wild_seed, tile_coord, details)
	SceneCacheService.request_change(self, TOWN_GENERATION_SCENE_PATH)

func _is_town_settlement(details: Dictionary) -> bool:
	var settlement_type := String(details.get("settlement_type", "")).strip_edges().to_lower()
	return settlement_type == "town" or settlement_type == "city" or settlement_type == "hamlet" or settlement_type == "desertcity"

## Desert cities reuse the town interior scene with a desert skin.
func _town_theme_for_details(details: Dictionary) -> String:
	var settlement_type := String(details.get("settlement_type", "")).strip_edges().to_lower()
	return "desert" if settlement_type == "desertcity" else ""

func _is_dungeon_structure(details: Dictionary) -> bool:
	return String(details.get("structure", "")).strip_edges().to_lower() == "dungeon"

func _dungeon_scene_seed_for_tile(tile_coord: Vector2i, details: Dictionary) -> String:
	var structure_name := _tile_region_name(tile_coord, details)
	if structure_name.is_empty():
		structure_name = "Forgotten Dungeon"
	var seed_basis := "dungeon|%s|%d|%d|%d" % [structure_name, tile_coord.x, tile_coord.y, map_seed]
	return str(seed_basis.hash())

func _store_selected_dungeon_scene_context(seed_text: String, tile_coord: Vector2i, details: Dictionary) -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null:
		return
	if not game_session.has_method("get_world_settings") or not game_session.has_method("set_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	settings[DUNGEON_SCENE_SEED_KEY] = seed_text
	settings[DUNGEON_SCENE_NAME_KEY] = _tile_region_name(tile_coord, details)
	game_session.call("set_world_settings", settings)

func _store_selected_dwarfhold_scene_context(seed_text: String, tile_coord: Vector2i, details: Dictionary) -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null:
		return
	if not game_session.has_method("get_world_settings") or not game_session.has_method("set_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	settings[DWARFHOLD_SCENE_SEED_KEY] = seed_text
	settings[DWARFHOLD_SCENE_TILE_KEY] = {"x": tile_coord.x, "y": tile_coord.y}
	settings[DWARFHOLD_SCENE_NAME_KEY] = _tile_region_name(tile_coord, details)
	settings[DWARFHOLD_SCENE_POPULATION_KEY] = maxi(0, int(details.get("population", 0)))
	settings[DWARFHOLD_SCENE_FALL_KEY] = String(details.get("fall_summary", ""))
	settings["underdeep_sites"] = _build_underdeep_sites(tile_coord)
	game_session.call("set_world_settings", settings)

## Every other settlement on the overworld, projected into the entered
## hold's continuous underground at a fixed cells-per-overworld-tile
## scale, so the underdeep contains the whole world.
func _build_underdeep_sites(origin_coord: Vector2i) -> Array:
	var sites: Array = []
	for coord_variant: Variant in _tile_data.keys():
		var coord := coord_variant as Vector2i
		if coord == origin_coord:
			continue
		var info := _tile_data.get(coord_variant, {}) as Dictionary
		var settlement_type := String(info.get("settlement_type", "")).strip_edges()
		if settlement_type.is_empty():
			continue
		var offset := (coord - origin_coord) * UndergroundWorldService.CELLS_PER_OVERWORLD_TILE
		sites.append({
			"name": _tile_region_name(coord, info),
			"type": settlement_type,
			"x": offset.x,
			"y": offset.y
		})
	return sites

func _store_selected_town_scene_context(seed_text: String, tile_coord: Vector2i, details: Dictionary, theme: String = "") -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null:
		return
	if not game_session.has_method("get_world_settings") or not game_session.has_method("set_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	# A real settlement is never a wild embark: clear any stale wild flags left
	# by a previous open-tile journey so the town scene builds a city.
	settings[TOWN_SCENE_WILD_KEY] = false
	settings[TOWN_SCENE_WILD_WATER_KEY] = false
	settings[TOWN_SCENE_SEED_KEY] = seed_text
	settings[TOWN_SCENE_TILE_KEY] = {"x": tile_coord.x, "y": tile_coord.y}
	settings[TOWN_SCENE_NAME_KEY] = _tile_region_name(tile_coord, details)
	settings[TOWN_SCENE_POPULATION_KEY] = maxi(0, int(details.get("population", 0)))
	settings[TOWN_SCENE_THEME_KEY] = theme
	settings[TOWN_SCENE_VILLAGE_KEY] = bool(details.get("is_hamlet", false)) or bool(details.get("is_snow_village", false))
	settings[TOWN_SCENE_WORLD_BIOMES_KEY] = _build_town_scene_world_biomes()
	settings[TOWN_SCENE_WORLD_RIVERS_KEY] = _build_town_scene_world_rivers()
	game_session.call("set_world_settings", settings)

## Embark context for an open wild tile. Reuses the town scene's world biome
## and river buffers so the streamed wilds match the overworld, but flags the
## scene wild (TOWN_SCENE_WILD_KEY) and zeroes every settlement field so it
## raises a bare biome clearing with no city, population, or theme.
func _store_selected_wild_scene_context(seed_text: String, tile_coord: Vector2i, details: Dictionary) -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null:
		return
	if not game_session.has_method("get_world_settings") or not game_session.has_method("set_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	settings[TOWN_SCENE_WILD_KEY] = true
	settings[TOWN_SCENE_WILD_WATER_KEY] = _patch_biome_label_for_tile(tile_coord) == BIOME_WATER
	settings[TOWN_SCENE_SEED_KEY] = seed_text
	settings[TOWN_SCENE_TILE_KEY] = {"x": tile_coord.x, "y": tile_coord.y}
	settings[TOWN_SCENE_NAME_KEY] = _wild_place_name_for_tile(tile_coord, details)
	settings[TOWN_SCENE_POPULATION_KEY] = 0
	settings[TOWN_SCENE_THEME_KEY] = ""
	settings[TOWN_SCENE_VILLAGE_KEY] = false
	settings[TOWN_SCENE_WORLD_BIOMES_KEY] = _build_town_scene_world_biomes()
	settings[TOWN_SCENE_WORLD_RIVERS_KEY] = _build_town_scene_world_rivers()
	game_session.call("set_world_settings", settings)

## A wild tile's on-screen name: the region name the map tooltip shows (e.g.
## "The Open Plains"), falling back to a biome label ("The Deep Woods") when a
## tile carries no stored region name.
func _wild_place_name_for_tile(tile_coord: Vector2i, details: Dictionary) -> String:
	var region_name := _tile_region_name(tile_coord, details)
	if not region_name.is_empty():
		return region_name
	# Open water gets a sea name rather than "The Water".
	if _patch_biome_label_for_tile(tile_coord) == BIOME_WATER:
		return "The Open Sea"
	var biome := _patch_biome_label_for_tile(tile_coord)
	var biome_label := _resolved_biome_label(tile_coord, biome)
	if biome_label.is_empty():
		return "The Wilds"
	return "The %s" % biome_label

## Deterministic per-tile seed for a wild embark, distinct from the town seed
## namespace so the same tile never collides with a settlement scene.
func _wild_scene_seed_for_tile(tile_coord: Vector2i, details: Dictionary) -> String:
	var place_name := _wild_place_name_for_tile(tile_coord, details)
	var seed_basis := "wild|%s|%d|%d|%d" % [place_name, tile_coord.x, tile_coord.y, map_seed]
	return str(seed_basis.hash())

## The whole overworld's per-tile biome, packed row-major as one byte per
## tile, so the town's wilds match the world map however far the walker
## strays. Base biome wins for water (so coasts read as sea); biome_type
## carries forest, mountain, and the rest. Byte codes go through the shared
## TILE_ATLAS_DEFS codec so the surface service decodes them the same way.
func _build_town_scene_world_biomes() -> Dictionary:
	if _tile_data.is_empty():
		return {}
	var width := map_size.x
	var height := map_size.y
	var codes := PackedByteArray()
	codes.resize(width * height)
	for y in range(height):
		for x in range(width):
			codes[y * width + x] = TILE_ATLAS_DEFS.biome_code(_patch_biome_label_for_tile(Vector2i(x, y)))
	return {"w": width, "h": height, "codes": codes}

## The overworld's river tiles packed row-major as one bit per tile, so the
## town's wilds reproduce the world map's watercourses however far the
## walker strays. A byte is 1 where the tile carries TILE_OVERLAY_RIVER,
## 0 otherwise; the surface service traces a meandering course through
## every flagged tile that joins its river and sea neighbors.
func _build_town_scene_world_rivers() -> Dictionary:
	if _tile_data.is_empty():
		return {}
	var width := map_size.x
	var height := map_size.y
	var bits := PackedByteArray()
	bits.resize(width * height)
	for y in range(height):
		for x in range(width):
			var info := _tile_data.get(Vector2i(x, y), {}) as Dictionary
			bits[y * width + x] = 1 if (int(info.get("overlay_flags", 0)) & TILE_OVERLAY_RIVER) != 0 else 0
	return {"w": width, "h": height, "bits": bits}

func _patch_biome_label_for_tile(tile: Vector2i) -> String:
	if tile.x < 0 or tile.y < 0 or tile.x >= map_size.x or tile.y >= map_size.y:
		return BIOME_GRASSLAND
	var info := _tile_data.get(tile, {}) as Dictionary
	if info.is_empty():
		return BIOME_GRASSLAND
	var base_biome := _tile_base_biome_from_data(info)
	if base_biome == BIOME_WATER:
		return BIOME_WATER
	var overlay_biome := String(info.get("biome_type", ""))
	# Hills are a landform, not a climate - a snowy/sandy hill tile must keep
	# its climate label so towns and streamed wilds stay themed.
	if overlay_biome == BIOME_HILLS and (base_biome == BIOME_TUNDRA or base_biome == BIOME_DESERT or base_biome == BIOME_BADLANDS):
		return base_biome
	return overlay_biome if not overlay_biome.is_empty() else base_biome

func _town_scene_seed_for_tile(tile_coord: Vector2i, details: Dictionary) -> String:
	var existing_seed := String(details.get(TOWN_SCENE_SEED_KEY, "")).strip_edges()
	if not existing_seed.is_empty():
		return existing_seed

	var settlement_name := _tile_region_name(tile_coord, details)
	if settlement_name.is_empty():
		settlement_name = "Unknown Town"
	var population := maxi(0, int(details.get("population", 0)))
	var seed_basis := "town|%s|%d|%d|%d|%d" % [settlement_name, tile_coord.x, tile_coord.y, map_seed, population]
	return str(seed_basis.hash())

func _dwarfhold_scene_seed_for_tile(tile_coord: Vector2i, details: Dictionary) -> String:
	var existing_seed := String(details.get(DWARFHOLD_SCENE_SEED_KEY, "")).strip_edges()
	if not existing_seed.is_empty():
		return existing_seed

	var settlement_name := _tile_region_name(tile_coord, details)
	if settlement_name.is_empty():
		settlement_name = "Unknown Dwarfhold"
	var population := maxi(0, int(details.get("population", 0)))
	var npc_target := int(ceil(float(population) / 10.0))
	var seed_basis := "%s|%d|%d|%d|%d|%d" % [settlement_name, tile_coord.x, tile_coord.y, map_seed, population, npc_target]
	return str(seed_basis.hash())

func _open_structure_details_from_context_menu(tile_coord: Vector2i) -> void:
	var details := _tile_data.get(tile_coord, {}) as Dictionary
	if details.is_empty():
		return

	if _is_dwarfhold_structure(details):
		_show_structure_details_modal(tile_coord, details)
		return

	var settlement_name := _tile_region_name(tile_coord, details)
	if settlement_name.is_empty():
		return
	_show_structure_details_modal(tile_coord, details)

func _is_dwarfhold_structure(details: Dictionary) -> bool:
	var settlement_type := String(details.get("settlement_type", "")).strip_edges().to_lower()
	if settlement_type == "dwarfhold":
		return true
	var settlement_classification := String(details.get("settlement_classification", "")).strip_edges().to_lower()
	return settlement_classification.contains("dwarfhold")

func _show_structure_details_modal(tile_coord: Vector2i, details: Dictionary) -> void:
	if structure_details_dialog == null:
		return

	var settlement_name := _tile_region_name(tile_coord, details)
	if settlement_name.is_empty():
		settlement_name = "Unknown region"
	var settlement_type := String(details.get("settlement_classification", "")).strip_edges()
	if settlement_type.is_empty():
		settlement_type = String(details.get("settlement_type", "Settlement")).strip_edges().capitalize()
	if _is_dwarfhold_structure(details):
		var dwarfhold_access := String(details.get("dwarfhold_access", "")).strip_edges()
		var dwarfhold_depth := String(details.get("dwarfhold_depth", "")).strip_edges()
		var status_parts: Array[String] = []
		if not dwarfhold_access.is_empty():
			status_parts.append(dwarfhold_access)
		if not dwarfhold_depth.is_empty():
			status_parts.append(dwarfhold_depth)
		if not status_parts.is_empty():
			settlement_type = "%s (%s)" % [settlement_type, ", ".join(status_parts)]

	structure_details_dialog.title = "Structure Details — %s" % settlement_name
	if structure_details_tabs != null:
		structure_details_tabs.current_tab = 0

	# No writer ever sets a "biome" key on the details dict; derive the
	# display label from the tile itself.
	var biome_name := _humanize_biome(_patch_biome_label_for_tile(tile_coord)).capitalize()
	var population := int(details.get("population", 0))
	var ruler_title := String(details.get("ruler_title", "")).strip_edges()
	var ruler_name := String(details.get("ruler_name", "")).strip_edges()
	var ruler_display := "Unknown"
	if not ruler_name.is_empty() and not ruler_title.is_empty():
		ruler_display = "%s %s" % [ruler_title, ruler_name]
	elif not ruler_name.is_empty():
		ruler_display = ruler_name

	var founded_text := "Unknown"
	var founded_years_ago := 120
	var founded_value: Variant = details.get("founded_years_ago", null)
	if typeof(founded_value) == TYPE_INT or typeof(founded_value) == TYPE_FLOAT:
		founded_years_ago = maxi(1, int(round(float(founded_value))))
		founded_text = "%s years ago" % str(founded_years_ago)

	## The chronicle is real simulated history; the legacy flavor timeline
	## only backs up sites the simulation never covered.
	var chronicle_events := details.get("chronicle_events", []) as Array
	var history_timeline := ""
	if not chronicle_events.is_empty():
		history_timeline = WorldChronicleService.settlement_events_bbcode(chronicle_events, _chronology_year)
	if history_timeline.is_empty():
		history_timeline = _build_settlement_history_timeline(
			details,
			settlement_name,
			founded_years_ago
		)

	_set_details_tab_text(
		structure_details_history_label,
		"[b]Settlement:[/b] %s\n[b]Type:[/b] %s\n[b]Founded:[/b] %s\n[b]Location:[/b] %s\n[b]Biome:[/b] %s\n\n[b]Chronicle[/b]\n%s" % [
			settlement_name,
			settlement_type,
			founded_text,
			str(tile_coord),
			biome_name,
			history_timeline
		]
	)

	var hallmark := String(details.get("hallmark", "")).strip_edges()
	if hallmark.is_empty():
		hallmark = String(details.get("description", "No notable records yet.")).strip_edges()
	_set_details_tab_text(
		structure_details_main_label,
		"[b]Name:[/b] %s\n[b]Type:[/b] %s\n[b]Population:[/b] %s\n[b]Ruler:[/b] %s\n\n%s" % [
			settlement_name,
			settlement_type,
			str(population),
			ruler_display,
			hallmark
		]
	)
	_set_structure_details_image(tile_coord, details)

	var population_timeline: Array = []
	for entry: Variant in details.get("population_timeline", []):
		if entry is Dictionary:
			population_timeline.append(entry)
	if structure_details_population_history_chart != null and structure_details_population_history_chart.has_method("set_points"):
		structure_details_population_history_chart.call("set_points", population_timeline)

	var major_clans := _variant_array_to_strings(details.get("major_clans", []))
	var major_guilds := _variant_array_to_strings(details.get("major_guilds", []))
	_set_details_tab_text(
		structure_details_features_label,
		"[b]Prominent clan:[/b] %s\n[b]Major clans:[/b] %s\n[b]Major guilds:[/b] %s" % [
			_string_or_unknown(String(details.get("prominent_clan", "")).strip_edges()),
			_format_resource_list(major_clans),
			_format_resource_list(major_guilds)
		]
	)

	var major_exports := _variant_array_to_strings(details.get("major_exports", []))
	_set_details_tab_text(
		structure_details_economy_label,
		"[b]Major exports:[/b] %s\n[b]Nearby biome:[/b] %s\n[b]Settlement class:[/b] %s" % [
			_format_resource_list(major_exports),
			biome_name,
			settlement_type
		]
	)

	structure_details_dialog.popup_centered(Vector2i(700, 480))

func _cache_more_info_image_paths() -> void:
	if _more_info_cache_initialized:
		return
	_more_info_image_paths.clear()
	_more_info_texture_cache.clear()
	var directory := DirAccess.open(MORE_INFO_IMAGE_FOLDER)
	if directory == null:
		_more_info_cache_initialized = true
		return

	directory.list_dir_begin()
	while true:
		var entry := directory.get_next()
		if entry.is_empty():
			break
		if directory.current_is_dir():
			continue

		var lower_entry := entry.to_lower()
		if lower_entry.ends_with(".png") or lower_entry.ends_with(".webp") or lower_entry.ends_with(".jpg") or lower_entry.ends_with(".jpeg"):
			var path := "%s/%s" % [MORE_INFO_IMAGE_FOLDER, entry]
			_more_info_image_paths.append(path)
	directory.list_dir_end()
	_more_info_cache_initialized = true

## Chooses the illustration that best fits the tile — matching the settlement
## kind first (dwarfhold, tower, keep, dungeon, village…) then the surrounding
## biome (forest, mountain, hills, coast, marsh, plains) — and picks it
## deterministically from the tile's coordinate, so the same place always shows
## the same fitting picture instead of a random one that re-rolls each open.
func _set_structure_details_image(tile_coord: Vector2i, details: Dictionary) -> void:
	if structure_details_main_image == null:
		return
	if _more_info_image_paths.is_empty() and not _more_info_cache_initialized:
		_cache_more_info_image_paths()

	if _more_info_image_paths.is_empty():
		structure_details_main_image.texture = null
		return

	var chosen_path := ""
	for keyword: String in _more_info_keywords_for(tile_coord, details):
		var matches: Array[String] = []
		for path: String in _more_info_image_paths:
			if path.get_file().to_lower().contains(keyword):
				matches.append(path)
		if not matches.is_empty():
			matches.sort()
			chosen_path = matches[_stable_more_info_index(tile_coord, matches.size())]
			break
	if chosen_path.is_empty():
		# Nothing matched (e.g. a desert with no themed art): still stable, just
		# picked from the whole pool by coordinate.
		var all_paths := _more_info_image_paths.duplicate()
		all_paths.sort()
		chosen_path = all_paths[_stable_more_info_index(tile_coord, all_paths.size())]

	var texture := _more_info_texture_cache.get(chosen_path, null) as Texture2D
	if texture == null:
		texture = load(chosen_path) as Texture2D
		if texture != null:
			_more_info_texture_cache[chosen_path] = texture
	structure_details_main_image.texture = texture

## A stable pick within a sorted list, keyed on the tile so the illustration
## never changes between openings of the same place.
func _stable_more_info_index(tile_coord: Vector2i, count: int) -> int:
	if count <= 1:
		return 0
	return absi(hash(tile_coord)) % count

## Ordered filename substrings to try, best fit first: the settlement kind, then
## biome fallbacks. The first keyword with any matching image wins.
func _more_info_keywords_for(tile_coord: Vector2i, details: Dictionary) -> Array[String]:
	var type_text := "%s %s" % [
		String(details.get("settlement_classification", "")),
		String(details.get("settlement_type", ""))
	]
	type_text = type_text.to_lower()
	var biome := _patch_biome_label_for_tile(tile_coord).to_lower()
	var abandoned := type_text.contains("abandon") or type_text.contains("lost")
	var keywords: Array[String] = []
	if _is_dwarfhold_structure(details):
		if abandoned:
			keywords.append("abandoned_dwarfhold")
		if biome.contains("hill"):
			keywords.append("hill-hold")
		keywords.append("dwarfhold")
	elif type_text.contains("tower") or type_text.contains("wizard") or type_text.contains("mage"):
		keywords.append("wizard_tower")
	elif type_text.contains("castle") or type_text.contains("keep") or type_text.contains("fort") or type_text.contains("citadel"):
		keywords.append("ruined_castle")
	elif type_text.contains("outpost") or type_text.contains("camp"):
		keywords.append("outpost")
	elif type_text.contains("dungeon") or type_text.contains("lair") or type_text.contains("cave") or type_text.contains("crypt") or type_text.contains("ruin"):
		keywords.append("dungeon")
	elif type_text.contains("town") or type_text.contains("village") or type_text.contains("city") or type_text.contains("hamlet") or type_text.contains("settle"):
		keywords.append("village")
	keywords.append_array(_biome_more_info_keywords(biome))
	return keywords

## Biome-themed filename substrings for the wild-surroundings fallback.
func _biome_more_info_keywords(biome: String) -> Array[String]:
	if biome.contains("forest") or biome.contains("jungle") or biome.contains("wood"):
		return ["forest"]
	if biome.contains("mountain"):
		return ["mountain"]
	if biome.contains("hill"):
		return ["hills"]
	if biome.contains("coast") or biome.contains("beach") or biome.contains("shore") or biome.contains("ocean") or biome.contains("sea") or biome.contains("water"):
		return ["coast"]
	if biome.contains("marsh") or biome.contains("swamp") or biome.contains("bog"):
		return ["marsh"]
	if biome.contains("plain") or biome.contains("grass") or biome.contains("steppe") or biome.contains("meadow") or biome.contains("savanna"):
		return ["plains"]
	return []

func _set_details_tab_text(target: RichTextLabel, text: String) -> void:
	if target == null:
		return
	target.text = text

func _build_settlement_history_timeline(
	details: Dictionary,
	settlement_name: String,
	founded_years_ago: int,
	chronology_year_override: int = 0
) -> String:
	var anchor_year := chronology_year_override if chronology_year_override > 0 else _chronology_year
	return OverworldHistoryService.build_settlement_history_timeline(details, settlement_name, founded_years_ago, anchor_year)

func _resolve_history_kind(details: Dictionary) -> String:
	return OverworldHistoryService.resolve_history_kind(details)

func _build_founding_event_text(history_kind: String, settlement_name: String) -> String:
	return OverworldHistoryService.build_founding_event_text(history_kind, settlement_name)

func _capitalize_timeline_detail(detail: String) -> String:
	return OverworldHistoryService.capitalize_timeline_detail(detail)

func _variant_array_to_strings(entries: Variant) -> Array[String]:
	return OverworldHistoryService.variant_array_to_strings(entries)

func _dedupe_trimmed_strings(entries: Array[String]) -> Array[String]:
	return OverworldHistoryService.dedupe_trimmed_strings(entries)

func _variant_to_clean_string(value: Variant) -> String:
	return OverworldHistoryService.variant_to_clean_string(value)

func _string_or_unknown(value: String) -> String:
	return OverworldHistoryService.string_or_unknown(value)

func _tile_biome_from_data(tile_data: Dictionary) -> String:
	return _biome_id_to_string(int(tile_data.get("biome_id", _biome_to_id(BIOME_GRASSLAND))))

func _tile_base_biome_from_data(tile_data: Dictionary) -> String:
	return _biome_id_to_string(int(tile_data.get("base_biome_id", _biome_to_id(BIOME_GRASSLAND))))

func _tile_hill_biome_from_data(tile_data: Dictionary) -> String:
	return _biome_id_to_string(int(tile_data.get("hill_biome_id", _biome_to_id(BIOME_GRASSLAND))))

## A mountain-overlay tile: never a site for non-alpine structures/settlements
## (towns, hamlets, ports, castles, monasteries, shrines, wizard towers).
func _is_mountain_tile(coord: Vector2i) -> bool:
	var tile_data := _tile_data.get(coord, {}) as Dictionary
	if tile_data.is_empty():
		return false
	if String(tile_data.get("hill_overlay", "")) == BIOME_MOUNTAIN:
		return true
	return _tile_hill_biome_from_data(tile_data) == BIOME_MOUNTAIN

func _tile_has_overlay_flag(tile_data: Dictionary, flag: int) -> bool:
	return (int(tile_data.get("overlay_flags", 0)) & flag) != 0

## Chronology ages arrive as ints ("2") or strings ("Age 1", "Age of
## Discovery"); returns the numeric age, or 0 when it has none.
func _chronology_age_number(age_value: Variant) -> int:
	if age_value is int:
		return int(age_value)
	if age_value is float:
		return int(age_value)
	if age_value is String:
		var digits := ""
		for character in String(age_value):
			if character >= "0" and character <= "9":
				digits += character
		if not digits.is_empty():
			return int(digits)
	return 0

func _tile_region_name(coord: Vector2i, tile_data: Dictionary) -> String:
	if tile_data.has("region_name"):
		return String(tile_data.get("region_name", "")).strip_edges()
	return String(_tile_region_names.get(coord, "")).strip_edges()

func _tile_population_groups_for_coord(coord: Vector2i) -> Dictionary:
	return _tile_population_groups.get(coord, {}) as Dictionary

func _regenerate_map() -> void:
	# One forge at a time: interleaving two generators corrupts the map.
	if _is_generating:
		return
	_show_loading_screen()
	await get_tree().process_frame
	map_seed = 0
	await _generate_map()
	_hide_loading_screen()

func _log_generation_stage(stage_name: String, started_ms: int) -> void:
	var elapsed_ms := Time.get_ticks_msec() - started_ms
	print("[OverworldMap] %s took %d ms" % [stage_name, elapsed_ms])

func _estimate_dictionary_payload_entries(dict_value: Dictionary) -> int:
	var entries := 0
	for value: Variant in dict_value.values():
		if value is Dictionary:
			entries += (value as Dictionary).size()
		elif value is Array:
			entries += (value as Array).size()
		else:
			entries += 1
	return entries

func _log_tile_metadata_profile(total_ms: int) -> void:
	var cells := maxi(1, _map_cell_count())
	var core_entries := _estimate_dictionary_payload_entries(_tile_data)
	var region_entries := _tile_region_names.size()
	var population_entries := _estimate_dictionary_payload_entries(_tile_population_groups)
	print("[OverworldMap] profile size=%dx%d cells=%d total=%dms tile_entries=%d region_entries=%d population_entries=%d" % [
		map_size.x,
		map_size.y,
		cells,
		total_ms,
		core_entries,
		region_entries,
		population_entries
	])

func _mark_all_overlays_dirty() -> void:
	_overlay_dirty["elevation"] = true
	_overlay_dirty["temperature"] = true
	_overlay_dirty["moisture"] = true
	_overlay_dirty["biome"] = true
	_overlay_dirty["culture"] = true
	_overlay_dirty["political_boundaries"] = true
	_overlay_dirty["cliffs"] = true

func _ensure_overlay_texture(overlay_key: String) -> void:
	if not bool(_overlay_dirty.get(overlay_key, false)):
		return
	match overlay_key:
		"elevation":
			_update_elevation_overlay()
		"temperature":
			_update_temperature_overlay()
		"moisture":
			_update_moisture_overlay()
		"biome":
			_update_biome_overlay()
		"culture":
			_update_culture_overlay()
		"political_boundaries":
			_update_political_boundaries_overlay()
		"cliffs":
			_update_cliffs_overlay()

func _generate_map() -> void:
	var map_generation_started_ms := Time.get_ticks_msec()
	if map_layer == null:
		push_error("Overworld map is missing a TileMapLayer named MapLayer.")
		return
	if map_layer.tile_set == null:
		_configure_tileset()
	if tree_layer != null and tree_layer.tile_set == null and map_layer.tile_set != null:
		tree_layer.tile_set = map_layer.tile_set
	if river_layer != null and river_layer.tile_set == null and map_layer.tile_set != null:
		river_layer.tile_set = map_layer.tile_set
	if _atlas_source_id < 0:
		push_error("Overworld map tileset is missing a valid atlas source.")
		return
	if _is_generating:
		return
	_is_generating = true
	# _estimate_sea_level overwrote water_level last run; restore the layout
	# baseline before sampling heights so regeneration is deterministic.
	if _layout_water_level < 0.0:
		_layout_water_level = water_level
	else:
		water_level = _layout_water_level
	# A new world invalidates every cached region-detail tile.
	_exit_region_mode()
	if _region_layer != null:
		for region_child: Node in _region_layer.get_children():
			region_child.queue_free()
	_region_sprites.clear()
	_region_render_queue.clear()
	_region_queued.clear()
	_region_noise.clear()
	_region_site_anchors = []
	# In-flight worker results from the old world must not be applied.
	_region_cache_stamp += 1
	map_layer.clear()
	if tree_layer != null:
		tree_layer.clear()
	if river_layer != null:
		river_layer.clear()
	if highland_layer != null:
		highland_layer.clear()
	if iceberg_layer != null:
		iceberg_layer.clear()
	if settlement_layer != null:
		settlement_layer.clear()
	if _coast_layer != null:
		_coast_layer.clear()
	_tile_data.clear()
	_tile_region_names.clear()
	_tile_population_groups.clear()
	# Forget which tile the visible tooltip describes, or a stationary
	# cursor keeps showing the OLD world's data after a regenerate.
	_tooltip_content_coord = Vector2i(-9999, -9999)

	var cell_count := _map_cell_count()
	var height_buffer := PackedFloat32Array()
	height_buffer.resize(cell_count)
	var temperature_buffer := PackedFloat32Array()
	temperature_buffer.resize(cell_count)
	var moisture_buffer := PackedFloat32Array()
	moisture_buffer.resize(cell_count)
	var vegetation_buffer := PackedFloat32Array()
	vegetation_buffer.resize(cell_count)
	var base_biome_buffer := PackedByteArray()
	base_biome_buffer.resize(cell_count)
	var highland_map: Dictionary = {}
	var generation_memory_before := _current_generation_memory_bytes()
	var generation_peak_memory := generation_memory_before

	var rng := RandomNumberGenerator.new()
	var name_rng := RandomNumberGenerator.new()
	if map_seed == 0:
		rng.randomize()
		map_seed = rng.randi()
	else:
		rng.seed = map_seed
	name_rng.seed = map_seed + 911
	_configure_landmass_centers(rng)
	_set_loading_progress(8.0, "Raising mountains and carving seas...")
	await _yield_generation_wave()
	var frequency_divisor := _feature_frequency_divisor()

	var continent_noise := FastNoiseLite.new()
	continent_noise.seed = map_seed
	continent_noise.frequency = (noise_frequency * 0.35) / frequency_divisor
	continent_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	continent_noise.fractal_octaves = maxi(4, noise_octaves)
	continent_noise.fractal_lacunarity = 2.1
	continent_noise.fractal_gain = 0.52
	continent_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX

	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = map_seed + 37
	detail_noise.frequency = (noise_frequency * 2.2) / frequency_divisor
	detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail_noise.fractal_octaves = 4
	detail_noise.fractal_lacunarity = 2.3
	detail_noise.fractal_gain = 0.55
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX

	var ridge_noise := FastNoiseLite.new()
	ridge_noise.seed = map_seed + 83
	ridge_noise.frequency = (noise_frequency * 1.1) / frequency_divisor
	ridge_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	ridge_noise.fractal_octaves = 3
	ridge_noise.fractal_lacunarity = 2.0
	ridge_noise.fractal_gain = 0.6
	ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX

	_temperature_noise = FastNoiseLite.new()
	_temperature_noise.seed = map_seed + 101
	_temperature_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_temperature_noise.frequency = temperature_frequency / frequency_divisor
	_temperature_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_temperature_noise.fractal_octaves = 3

	# Browser computeSnowPresence noise (main.js:21610-21613): 3 octaves,
	# 0.55 persistence, 2.2 lacunarity, scale 5.3 + rng()*3.2 across the
	# normalized map width. The scale comes from a seed hash so the snow
	# line stays deterministic per world seed.
	_snow_edge_noise = FastNoiseLite.new()
	_snow_edge_noise.seed = map_seed + 0x27d4eb2d
	_snow_edge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_snow_edge_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_snow_edge_noise.fractal_octaves = 3
	_snow_edge_noise.fractal_gain = 0.55
	_snow_edge_noise.fractal_lacunarity = 2.2
	var snow_noise_scale := 5.3 + _hash_coords(3, 11, map_seed + 0x27d4eb2d) * 3.2
	_snow_edge_noise.frequency = snow_noise_scale / frequency_divisor

	# Browser rainfall octabands (main.js:21459-21486): a broad base band
	# (3 octaves, 0.6, 2.05) and a finer detail band (4 octaves, 0.55, 2.25)
	# mixed 0.65/0.35 inside _build_rainfall_buffer.
	_rainfall_noise = FastNoiseLite.new()
	_rainfall_noise.seed = map_seed + 211
	_rainfall_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_rainfall_noise.frequency = rainfall_frequency / frequency_divisor
	_rainfall_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_rainfall_noise.fractal_octaves = 3
	_rainfall_noise.fractal_gain = 0.6
	_rainfall_noise.fractal_lacunarity = 2.05

	_rainfall_detail_noise = FastNoiseLite.new()
	_rainfall_detail_noise.seed = map_seed + 223
	_rainfall_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_rainfall_detail_noise.frequency = (rainfall_frequency * 2.6) / frequency_divisor
	_rainfall_detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_rainfall_detail_noise.fractal_octaves = 4
	_rainfall_detail_noise.fractal_gain = 0.55
	_rainfall_detail_noise.fractal_lacunarity = 2.25

	# Browser desert fields (main.js:21991-22117): the equatorial band warp,
	# the heat jitter and the acceptance noise each get their own octave set.
	_desert_band_noise = FastNoiseLite.new()
	_desert_band_noise.seed = map_seed + 0x2545f491
	_desert_band_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_desert_band_noise.frequency = 2.4 / frequency_divisor
	_desert_band_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_desert_band_noise.fractal_octaves = 4
	_desert_band_noise.fractal_gain = 0.55
	_desert_band_noise.fractal_lacunarity = 2.1

	_desert_heat_noise = FastNoiseLite.new()
	_desert_heat_noise.seed = map_seed + 0x1c69b3f7
	_desert_heat_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_desert_heat_noise.frequency = 3.1 / frequency_divisor
	_desert_heat_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_desert_heat_noise.fractal_octaves = 4
	_desert_heat_noise.fractal_gain = 0.55
	_desert_heat_noise.fractal_lacunarity = 2.2

	_desert_detail_noise = FastNoiseLite.new()
	_desert_detail_noise.seed = map_seed + 0x3ab41d7b
	_desert_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_desert_detail_noise.frequency = 4.4 / frequency_divisor
	_desert_detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_desert_detail_noise.fractal_octaves = 3
	_desert_detail_noise.fractal_gain = 0.55
	_desert_detail_noise.fractal_lacunarity = 2.15

	_marsh_variation_noise = FastNoiseLite.new()
	_marsh_variation_noise.seed = map_seed + 0x51a7f5d3
	_marsh_variation_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_marsh_variation_noise.frequency = 4.6 / frequency_divisor
	_marsh_variation_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_marsh_variation_noise.fractal_octaves = 4
	_marsh_variation_noise.fractal_gain = 0.55
	_marsh_variation_noise.fractal_lacunarity = 2.1

	_vegetation_noise = FastNoiseLite.new()
	_vegetation_noise.seed = map_seed + 317
	_vegetation_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_vegetation_noise.frequency = (noise_frequency * 2.8) / frequency_divisor
	_vegetation_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_vegetation_noise.fractal_octaves = 3

	for y in range(map_size.y):
		for x in range(map_size.x):
			var idx := _xy_to_index(x, y)
			height_buffer[idx] = _sample_height(continent_noise, detail_noise, ridge_noise, x, y)
		if y > 0 and y % GENERATION_YIELD_ROW_INTERVAL == 0:
			await _yield_generation_wave()

	_smooth_height_buffer(height_buffer, 1, 0.35)
	generation_peak_memory = _sample_generation_memory_peak(generation_peak_memory, "height smoothing")
	# Browser estimateSeaLevels (main.js:11590-11601): the sea level is the
	# exact height percentile that puts targetWaterRatio of the map under
	# water (0.47 + the layout's seaLevelShift, main.js:21308).
	water_level = _estimate_sea_level(height_buffer)
	_ensure_landmass_presence_buffer(height_buffer)
	var height_map_for_biome := _float_buffer_to_dictionary(height_buffer)
	_desert_suitability_buffer.resize(cell_count)
	_desert_suitability_buffer.fill(0.0)
	_desert_heat_buffer.resize(cell_count)
	_desert_heat_buffer.fill(0.0)
	var stage_started_ms := Time.get_ticks_msec()
	_build_rainfall_buffer(height_buffer)
	_log_generation_stage("rainfall field", stage_started_ms)
	await _yield_generation_wave()

	stage_started_ms = Time.get_ticks_msec()
	for y in range(map_size.y):
		for x in range(map_size.x):
			var coord := Vector2i(x, y)
			var idx := _xy_to_index(x, y)
			var height := float(height_buffer[idx])
			var temperature := _sample_temperature(x, y, height)
			var moisture := _sample_moisture(x, y, height)
			var vegetation := _sample_vegetation(x, y, height, moisture, temperature)
			temperature_buffer[idx] = temperature
			moisture_buffer[idx] = moisture
			vegetation_buffer[idx] = vegetation
			base_biome_buffer[idx] = _biome_to_id(_assign_base_biome(coord, height, temperature, moisture, height_map_for_biome))
		if y > 0 and y % GENERATION_YIELD_ROW_INTERVAL == 0:
			await _yield_generation_wave()

	_log_generation_stage("climate + base biomes", stage_started_ms)
	stage_started_ms = Time.get_ticks_msec()
	_guarantee_minimum_landmass_buffer(height_buffer, temperature_buffer, moisture_buffer, base_biome_buffer)
	generation_peak_memory = _sample_generation_memory_peak(generation_peak_memory, "climate sampling")
	var height_map := _float_buffer_to_dictionary(height_buffer)
	var temperature_map := _float_buffer_to_dictionary(temperature_buffer)
	var moisture_map := _float_buffer_to_dictionary(moisture_buffer)
	var vegetation_map := _float_buffer_to_dictionary(vegetation_buffer)
	var base_biome_map := _biome_buffer_to_dictionary(base_biome_buffer)
	_landmass_masks = _generate_landmass_masks_from_biome_map(base_biome_map)

	stage_started_ms = Time.get_ticks_msec()
	_smooth_biomes(base_biome_map, 2)
	# The snow field is a direct function of latitude+height (browser
	# main.js:21607-21635); smoothing may never drag tundra south of the
	# band nor thin the guaranteed polar cap, so re-assert it.
	_enforce_snow_presence(base_biome_map, height_buffer)
	generation_peak_memory = _sample_generation_memory_peak(generation_peak_memory, "biome smoothing")
	_log_generation_stage("biome smoothing + snow", stage_started_ms)
	await _yield_generation_wave()
	stage_started_ms = Time.get_ticks_msec()
	_refine_desert_biomes(base_biome_map)
	_log_generation_stage("desert refinement", stage_started_ms)
	await _yield_generation_wave()
	stage_started_ms = Time.get_ticks_msec()
	_refine_marsh_biomes(base_biome_map, height_buffer, moisture_buffer, height_map, rng)
	generation_peak_memory = _sample_generation_memory_peak(generation_peak_memory, "desert and marsh refinement")
	_log_generation_stage("marsh refinement", stage_started_ms)
	await _yield_generation_wave()
	if _count_biome(base_biome_map, BIOME_DESERT) == 0:
		_seed_desert_biomes(base_biome_map, temperature_map, moisture_map, height_map)
		_smooth_biomes(base_biome_map, 1)
		_enforce_snow_presence(base_biome_map, height_buffer)
	base_biome_buffer = _dictionary_to_biome_buffer(base_biome_map)
	stage_started_ms = Time.get_ticks_msec()
	highland_map = _build_highland_overlays(base_biome_map, height_buffer, height_map, rng)
	generation_peak_memory = _sample_generation_memory_peak(generation_peak_memory, "highland ridges")
	_log_generation_stage("highland ridges", stage_started_ms)
	await _yield_generation_wave()
	var tree_biome_map: Dictionary = base_biome_map.duplicate()
	var tree_map := _apply_tree_overlays(
		tree_biome_map,
		moisture_map,
		vegetation_map,
		height_map,
		highland_map,
		rng
	)
	generation_peak_memory = _sample_generation_memory_peak(generation_peak_memory, "tree overlays")
	var river_map := _build_river_map_buffers(height_buffer, moisture_buffer, base_biome_buffer, rng)
	# Browser ensureRiverConnectionsToWater: landlocked river networks get a
	# terminal pond so every river visibly reaches water.
	var river_ponds := OverworldRiverService.ensure_river_connections_to_water(river_map, base_biome_map, height_map, map_size)
	if not river_ponds.is_empty():
		for pond_coord: Vector2i in river_ponds:
			tree_biome_map[pond_coord] = BIOME_WATER
			tree_map.erase(pond_coord)
			highland_map.erase(pond_coord)
		base_biome_buffer = _dictionary_to_biome_buffer(base_biome_map)
		_landmass_masks = _generate_landmass_masks_from_biome_map(base_biome_map)
	var edge_connected_water := _compute_edge_connected_water_mask(base_biome_map)
	var river_tiles := _apply_river_tiles(river_map, base_biome_map, highland_map, tree_map, edge_connected_water)
	var biome_map: Dictionary = tree_biome_map
	for coord: Vector2i in highland_map.keys():
		biome_map[coord] = highland_map[coord]
	generation_peak_memory = _sample_generation_memory_peak(generation_peak_memory, "highland overlays")

	var generation_started_ms := Time.get_ticks_msec()
	_set_loading_progress(20.0, "Laying the land, tile by tile...")
	await _apply_base_tiles(base_biome_map)
	_log_generation_stage("base tiles", generation_started_ms)
	await _yield_generation_wave()

	generation_started_ms = Time.get_ticks_msec()
	_set_loading_progress(48.0, "Growing forests and naming regions...")
	await _apply_tree_tiles(tree_map, base_biome_map)
	_apply_overlays_and_metadata(
		base_biome_map,
		biome_map,
		tree_map,
		highland_map,
		height_map,
		temperature_map,
		moisture_map,
		river_tiles,
		name_rng
	)
	_place_volcano_tiles(highland_map, height_map, rng)
	_log_generation_stage("metadata and overlays", generation_started_ms)
	await _yield_generation_wave()

	generation_started_ms = Time.get_ticks_msec()
	_set_loading_progress(62.0, "Calving icebergs...")
	_place_icebergs(base_biome_map, biome_map, height_map)
	_log_generation_stage("icebergs", generation_started_ms)
	await _yield_generation_wave()

	generation_started_ms = Time.get_ticks_msec()
	_set_loading_progress(70.0, "Founding settlements and cultures...")
	await _yield_generation_wave()
	_place_settlements(height_map, rng)
	_log_generation_stage("settlements", generation_started_ms)
	generation_started_ms = Time.get_ticks_msec()
	_set_loading_progress(74.0, "Raising watchtowers, camps and shrines...")
	await _yield_generation_wave()
	_place_github_style_structures(biome_map, height_map, moisture_map, rng)
	_log_generation_stage("ambient structures", generation_started_ms)
	generation_started_ms = Time.get_ticks_msec()
	_set_loading_progress(77.0, "Charting the trade routes...")
	await _yield_generation_wave()
	_build_routes_overlay_from_settlements()
	_log_generation_stage("routes overlay", generation_started_ms)
	generation_started_ms = Time.get_ticks_msec()
	_set_loading_progress(80.0, "Weaving cultures and drawing borders...")
	await _yield_generation_wave()
	_assign_cultural_groups(biome_map, temperature_map, moisture_map, height_map, rng)
	_log_generation_stage("cultural groups", generation_started_ms)
	generation_started_ms = Time.get_ticks_msec()
	_set_loading_progress(82.0, "Chronicling the ages...")
	_simulate_world_chronicle()
	_log_generation_stage("world chronicle", generation_started_ms)
	# Labels render AFTER the chronicle so razed sites are already renamed
	# ("Ruins of X") and the overlay is only ever built once.
	generation_started_ms = Time.get_ticks_msec()
	_rebuild_labels_overlay()
	_log_generation_stage("labels overlay", generation_started_ms)
	generation_peak_memory = _sample_generation_memory_peak(generation_peak_memory, "settlements and culture")
	_set_loading_progress(84.0, "Drawing the cartographer's overlays...")
	await _yield_generation_wave()
	_height_buffer = height_buffer
	_temperature_buffer = temperature_buffer
	_moisture_buffer = moisture_buffer
	_biome_buffer = _dictionary_to_biome_buffer(biome_map)
	_height_map = _float_buffer_to_dictionary(_height_buffer)
	_temperature_map = _float_buffer_to_dictionary(_temperature_buffer)
	_moisture_map = _float_buffer_to_dictionary(_moisture_buffer)
	_biome_map = _biome_buffer_to_dictionary(_biome_buffer)
	_update_height_texture()
	_apply_coast_overlay()
	_set_loading_progress(89.0, "Binding the gazetteer...")
	await _yield_generation_wave()
	_persist_world_sites()
	_build_map_snapshot()
	_mark_all_overlays_dirty()
	_ensure_overlay_texture("elevation")
	if _temperature_overlay_enabled:
		_ensure_overlay_texture("temperature")
	if _moisture_overlay_enabled:
		_ensure_overlay_texture("moisture")
	if _biome_overlay_enabled:
		_ensure_overlay_texture("biome")
	if _culture_overlay_enabled:
		_ensure_overlay_texture("culture")
	if _political_boundaries_overlay_enabled:
		_ensure_overlay_texture("political_boundaries")
	_update_routes_overlay_visibility()
	_set_loading_progress(93.0, "Inking coasts and shading peaks...")
	await _yield_generation_wave()
	_update_terrain_shading_overlay(base_biome_map)
	_configure_globe_viewport()
	_configure_overworld_camera_bounds()
	if _is_globe_view:
		_update_globe_texture()
	if _is_scene3d_view:
		_update_scene3d_texture()
	_set_loading_progress(100.0, "The realm stands ready.")
	var generation_memory_after := _current_generation_memory_bytes()
	print("Overworld generation memory bytes (before/after/peak): %d / %d / %d" % [generation_memory_before, generation_memory_after, generation_peak_memory])
	_log_tile_metadata_profile(Time.get_ticks_msec() - map_generation_started_ms)
	_is_generating = false

## Writes the gazetteer of enterable sites (tile, class, name, seed)
## into world settings so local scenes know their neighbors and walkers
## can arrive on foot.
func _persist_world_sites() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings") or not game_session.has_method("set_world_settings"):
		return
	var sites: Array = []
	# Ambient structures ride along as non-enterable scenery; collected
	# separately so the enterable gazetteer keeps its leading order.
	var ambient_sites: Array = []
	var ambient_candidate_count := 0
	# Named settlements also feed the world-events roster so ongoing
	# history (raids, caravans, festivals) talks about real places.
	var roster_settlements: Array = []
	for coord_variant: Variant in _tile_data.keys():
		var details := _tile_data[coord_variant] as Dictionary
		var coord := coord_variant as Vector2i
		if details.has("settlement_type") and roster_settlements.size() < WORLD_ROSTER_SETTLEMENT_CAP:
			var roster_name := _tile_region_name(coord, details)
			if not roster_name.is_empty():
				roster_settlements.append({
					"name": roster_name,
					"type": String(details.get("settlement_type", "town"))
				})
		var site_class := ""
		var seed_text := ""
		if _is_dwarfhold_structure(details):
			site_class = "dwarfhold"
			seed_text = _dwarfhold_scene_seed_for_tile(coord, details)
		elif _is_town_settlement(details):
			site_class = "town"
			seed_text = _town_scene_seed_for_tile(coord, details)
		elif _is_dungeon_structure(details):
			site_class = "dungeon"
			seed_text = _dungeon_scene_seed_for_tile(coord, details)
		else:
			# Not enterable: fold in ambient structures as pure scenery so
			# the visited wilds can raise them at their true walking distance.
			var ambient_site := _ambient_site_for_tile(coord, details)
			if not ambient_site.is_empty():
				ambient_candidate_count += 1
				if ambient_sites.size() < WORLD_AMBIENT_SITE_CAP:
					ambient_sites.append(ambient_site)
			continue
		sites.append({
			"x": coord.x, "y": coord.y,
			"class": site_class,
			"seed": seed_text,
			"name": _tile_region_name(coord, details),
			"population": maxi(0, int(details.get("population", 0))),
			"theme": _town_theme_for_details(details)
		})
	if ambient_candidate_count > ambient_sites.size():
		print("[OverworldMap] ambient landmark sites truncated: kept %d of %d" % [ambient_sites.size(), ambient_candidate_count])
	sites.append_array(ambient_sites)
	var faction_names: Array = []
	for faction_source: Dictionary in _collect_faction_sources():
		var faction_label := String(faction_source.get("label", ""))
		if not faction_label.is_empty() and not faction_names.has(faction_label):
			faction_names.append(faction_label)
	var settings: Dictionary = game_session.call("get_world_settings")
	settings[WorldSitesService.SETTINGS_KEY] = sites
	settings["last_scene"] = "res://scenes/overworld.tscn"
	settings[WorldEventsService.ROSTER_KEY] = {
		"settlements": roster_settlements,
		"factions": faction_names
	}
	## The chronicle rides along compactly so town/dwarfhold scenes can read
	## local history (rumors, grudges, fall summaries) without the overworld.
	settings[WorldChronicleService.SETTINGS_KEY] = _world_chronicle
	game_session.call("set_world_settings", settings)

## Runs the seeded history simulation (year 1 to the embark year) over the
## placed settlements and the political states the culture flood assigned,
## then rewrites the map's flavor data as OUTPUTS of that chronicle.
func _simulate_world_chronicle() -> void:
	var chronicle_started_usec := Time.get_ticks_usec()
	## The placement passes already collected every settlement coordinate;
	## walking them beats re-scanning the whole tile dictionary.
	var coords: Array[Vector2i] = []
	coords.append_array(_town_points)
	coords.append_array(_dwarfhold_points)
	coords.append_array(_grove_points)
	coords.append_array(_lizardmen_city_points)
	coords.append_array(_desert_city_points)
	## Deterministic actor order regardless of placement history.
	coords.sort_custom(func(left: Vector2i, right: Vector2i) -> bool:
		if left.y != right.y:
			return left.y < right.y
		return left.x < right.x
	)
	var actors: Array[Dictionary] = []
	for coord: Vector2i in coords:
		var details := _tile_data.get(coord, {}) as Dictionary
		if not details.has("settlement_type"):
			continue
		actors.append({
			"key": "%d,%d" % [coord.x, coord.y],
			"x": coord.x,
			"y": coord.y,
			"name": _tile_region_name(coord, details),
			"type": String(details.get("settlement_type", "town")),
			"class_key": String(details.get("settlement_classification_key", "")),
			"population": maxi(0, int(details.get("population", 0))),
			"is_hamlet": bool(details.get("is_hamlet", false)),
			"state": String(details.get("political_state", "")),
			"ruler_name": String(details.get("ruler_name", "")),
			"ruler_title": String(details.get("ruler_title", "")),
			## The hold's prominent clan, so a dwarven succession line can
			## keep one dynasty surname from founder to sitting ruler.
			"clan": String(details.get("prominent_clan", ""))
		})
	_world_chronicle = WorldChronicleService.simulate(actors, _chronology_year, int(map_seed))
	var simulate_usec := Time.get_ticks_usec() - chronicle_started_usec
	## Lairs are assigned from the pristine simulation (deterministic per
	## seed); the player's recorded kills are patched on afterwards so a
	## re-generated overworld remembers the deed without shifting any
	## surviving beast's den.
	_assign_beast_lairs()
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null and game_session.has_method("get_world_settings"):
		var kill_settings: Dictionary = game_session.call("get_world_settings")
		WorldChronicleService.apply_player_kills(_world_chronicle, WorldChronicleService.player_kills(kill_settings))
		## Dead player characters are history too: their graves re-apply to
		## a regenerated chronicle exactly like the beast kills do.
		WorldChronicleService.apply_player_deaths(_world_chronicle, WorldChronicleService.player_deaths(kill_settings))
	_apply_world_chronicle()
	_apply_beast_lair_surfacing()
	var world_event_count := (_world_chronicle.get("world_events", []) as Array).size()
	print("[OverworldMap] world chronicle: %d settlements, %d world events, %d wars in %d us (sim %d us, apply %d us)" % [
		actors.size(),
		world_event_count,
		(_world_chronicle.get("wars", []) as Array).size(),
		Time.get_ticks_usec() - chronicle_started_usec,
		simulate_usec,
		Time.get_ticks_usec() - chronicle_started_usec - simulate_usec
	])

## Feeds the chronicle back into the tile data: founding years, reshaped
## population timelines, per-settlement event lists, hold falls (including
## conversions of living holds the sim toppled) and razed ruins.
func _apply_world_chronicle() -> void:
	var settlements := _world_chronicle.get("settlements", {}) as Dictionary
	if settlements.is_empty():
		return
	var converted_holds := _world_chronicle.get("converted_holds", []) as Array
	var razed_settlements := _world_chronicle.get("razed_settlements", []) as Array
	for entry_key_variant: Variant in settlements.keys():
		var entry_key := String(entry_key_variant)
		var entry := settlements[entry_key] as Dictionary
		var key_parts := entry_key.split(",")
		if key_parts.size() != 2:
			continue
		var coord := Vector2i(int(key_parts[0]), int(key_parts[1]))
		if not _tile_data.has(coord):
			continue
		var details := _tile_data[coord] as Dictionary
		var founded_year := int(entry.get("founded_year", 1))
		details["founded_years_ago"] = maxi(1, _chronology_year - founded_year)
		details["chronicle_events"] = entry.get("events", [])
		# Renames from conversions and razings are picked up by the labels
		# overlay, which the pipeline builds after this stage.
		if converted_holds.has(entry_key):
			_convert_hold_to_abandoned(coord, details, entry)
		if razed_settlements.has(entry_key):
			_apply_settlement_razing(coord, details, entry)
		var fell_year := int(entry.get("fell_year", 0))
		if fell_year > 0:
			details["fall_year"] = fell_year
			details["fall_summary"] = String(entry.get("fall_text", ""))
		## Notable settlements inherit their lineage's sitting ruler. For
		## dwarfholds the chronicle is AUTHORITATIVE: the succession line's
		## last ruler replaces the placement roll, so the map tooltip, the
		## entered hold and the dynasty tree all name the same ruler.
		var chronicle_ruler := String(entry.get("ruler_name", "")).strip_edges()
		if not chronicle_ruler.is_empty() and fell_year <= 0:
			var chronicle_rules := String(entry.get("type", "")) == "dwarfhold"
			if chronicle_rules or String(details.get("ruler_name", "")).strip_edges().is_empty():
				details["ruler_name"] = chronicle_ruler
				details["ruler_title"] = String(entry.get("ruler_title", ""))
				var chronicle_ruler_gender := String(entry.get("ruler_gender", ""))
				if not chronicle_ruler_gender.is_empty():
					details["ruler_gender"] = chronicle_ruler_gender
		## The population chart replays the chronicle: dips at plague and
		## siege years, booms in golden ages, zero after a fall.
		var timeline_rng := RandomNumberGenerator.new()
		timeline_rng.seed = int(hash("%d|chronicle_timeline|%s" % [map_seed, entry_key]))
		var timeline := WorldChronicleService.build_population_timeline(
			founded_year,
			_chronology_year,
			maxi(0, int(details.get("population", 0))),
			maxi(0, int(entry.get("peak_population", 0))),
			fell_year,
			entry.get("marks", []) as Array,
			timeline_rng
		)
		if not timeline.is_empty():
			details["population_timeline"] = timeline
		_tile_data[coord] = details

## A living hold the chronicle toppled becomes an abandoned ruin on the
## map: tile art, classification and details all follow the fall event.
func _convert_hold_to_abandoned(coord: Vector2i, details: Dictionary, entry: Dictionary) -> void:
	if settlement_layer != null:
		settlement_layer.set_cell(coord, _atlas_source_id, ABANDONED_DWARFHOLD_TILE)
	else:
		map_layer.set_cell(coord, _atlas_source_id, ABANDONED_DWARFHOLD_TILE)
	details["settlement_classification"] = "Abandoned Dwarfhold"
	details["settlement_classification_key"] = "abandoned"
	details["dwarfhold_access"] = "Closed"
	details["population"] = 0
	details["ruler_title"] = ""
	details["ruler_name"] = ""
	details["prominent_clan"] = ""
	details["major_clans"] = []
	details["major_guilds"] = []
	details["major_exports"] = []
	if not DWARFHOLD_ABANDONED_HALLMARKS.is_empty():
		var hallmark_index := absi(int(hash("%d,%d|fall" % [coord.x, coord.y]))) % DWARFHOLD_ABANDONED_HALLMARKS.size()
		details["hallmark"] = DWARFHOLD_ABANDONED_HALLMARKS[hallmark_index]
	details["description"] = String(entry.get("fall_text", "Dust and silence fill the abandoned chambers."))
	## The scene seed keyed population; the ruin re-derives it at 0.
	details.erase(DWARFHOLD_SCENE_SEED_KEY)
	details[DWARFHOLD_SCENE_SEED_KEY] = _dwarfhold_scene_seed_for_tile(coord, details)

## A razed town keeps its tile (the atlas offers no human-ruin art) but is
## renamed "Ruins of X" with population 0; its history explains the rest.
func _apply_settlement_razing(coord: Vector2i, details: Dictionary, entry: Dictionary) -> void:
	var original_name := String(entry.get("name", _tile_region_name(coord, details)))
	_tile_region_names[coord] = "Ruins of %s" % original_name
	details["razed"] = true
	details["population"] = 0
	details["settlement_classification"] = "Ruins"
	details["ruler_title"] = ""
	details["ruler_name"] = ""
	details["description"] = String(entry.get("fall_text", "Only ruins remain."))

## --- Beast lairs ---------------------------------------------------------------

## Ambient structure ids that can host a beast's den, by preference tier.
## Dragons perch where the culture map already drew dragons; the walking
## kinds den in caves, mounds and dens. Every candidate is an ambient
## gazetteer site, so the streamed wilds can raise the lair (and its boss)
## as a real place.
const BEAST_LAIR_DRAGON_STRUCTURES: Array[String] = ["sleeping_dragon", "green_dragon"]
const BEAST_LAIR_DEN_STRUCTURES: Array[String] = ["cave", "troll_mound", "ogre_den", "gnoll_den"]

## Gives every still-living chronicle beast a physical lair, recorded in
## the chronicle payload. A beast that felled a dwarfhold nests in that
## abandoned hold (matching the "still nests where the hold fell" rumors);
## the rest den at a fitting map site. Deterministic from map seed + beast
## name, independent of player history.
func _assign_beast_lairs() -> void:
	var beasts := _world_chronicle.get("beasts", []) as Array
	if beasts.is_empty():
		return
	var settlements := _world_chronicle.get("settlements", {}) as Dictionary
	var settlement_keys: Array[String] = []
	for key_variant: Variant in settlements.keys():
		settlement_keys.append(String(key_variant))
	settlement_keys.sort()
	## Candidate site tiles, gathered in sorted coordinate order so the
	## same seed always yields the same pools.
	var sorted_coords: Array[Vector2i] = []
	for coord_variant: Variant in _tile_data.keys():
		sorted_coords.append(coord_variant as Vector2i)
	sorted_coords.sort_custom(func(left: Vector2i, right: Vector2i) -> bool:
		if left.y != right.y:
			return left.y < right.y
		return left.x < right.x
	)
	var perch_pool: Array[Vector2i] = []
	var den_pool: Array[Vector2i] = []
	for coord: Vector2i in sorted_coords:
		var details := _tile_data[coord] as Dictionary
		if details.has("settlement_type"):
			continue
		var structure_id := String(details.get("structure", "")).strip_edges()
		if structure_id.is_empty():
			continue
		if BEAST_LAIR_DRAGON_STRUCTURES.has(structure_id):
			perch_pool.append(coord)
		elif BEAST_LAIR_DEN_STRUCTURES.has(structure_id):
			den_pool.append(coord)
	var used_tiles: Dictionary = {}
	for beast_variant: Variant in beasts:
		var beast := beast_variant as Dictionary
		if String(beast.get("status", "alive")) != "alive":
			continue
		var beast_name := String(beast.get("name", ""))
		## A hold-feller dens in the (most recently) toppled hold.
		var hold_key := ""
		var hold_fell_year := -1
		for settlement_key: String in settlement_keys:
			var record := settlements[settlement_key] as Dictionary
			if String(record.get("fall_beast", "")) != beast_name:
				continue
			if int(record.get("fell_year", 0)) > hold_fell_year:
				hold_fell_year = int(record.get("fell_year", 0))
				hold_key = settlement_key
		if not hold_key.is_empty():
			var record := settlements[hold_key] as Dictionary
			beast["lair_site"] = {"x": int(record.get("x", 0)), "y": int(record.get("y", 0))}
			beast["lair_kind"] = "hold"
			beast["lair_name"] = String(record.get("name", "a fallen hold"))
			used_tiles[Vector2i(int(record.get("x", 0)), int(record.get("y", 0)))] = true
			continue
		var is_dragon := String(beast.get("kind", "")) == "dragon" or String(beast.get("kind", "")) == "green_dragon"
		var pools: Array = [perch_pool, den_pool] if is_dragon else [den_pool, perch_pool]
		var lair_rng := RandomNumberGenerator.new()
		lair_rng.seed = int(hash("%d|beast_lair|%s" % [map_seed, beast_name]))
		var chosen := Vector2i(2147483647, 2147483647)
		for pool_variant: Variant in pools:
			var pool := pool_variant as Array
			if pool.is_empty():
				continue
			var start_index := lair_rng.randi_range(0, pool.size() - 1)
			for probe: int in range(pool.size()):
				var candidate := pool[(start_index + probe) % pool.size()] as Vector2i
				if not used_tiles.has(candidate):
					chosen = candidate
					break
			if chosen.x != 2147483647:
				break
		if chosen.x == 2147483647:
			continue
		used_tiles[chosen] = true
		var details := _tile_data.get(chosen, {}) as Dictionary
		var site_name := _tile_region_name(chosen, details)
		if site_name.is_empty():
			site_name = String(details.get("structure", "a wild place")).capitalize()
		beast["lair_site"] = {"x": chosen.x, "y": chosen.y}
		beast["lair_kind"] = "site"
		beast["lair_name"] = site_name

## Surfaces the lairs of beasts still alive AFTER the player's kills were
## patched on: abandoned-hold lairs carry the warning in their hallmark
## (tooltip + details modal), ambient lair sites gain "— Lair of <beast>"
## in their region name (map label, hover title, wilds landmark label).
## A slain beast's lair keeps only its ordinary description — the
## labeling drops with the kill.
func _apply_beast_lair_surfacing() -> void:
	for beast_variant: Variant in (_world_chronicle.get("beasts", []) as Array):
		var beast := beast_variant as Dictionary
		if String(beast.get("status", "alive")) != "alive":
			continue
		var lair_site: Variant = beast.get("lair_site", {})
		if not (lair_site is Dictionary) or (lair_site as Dictionary).is_empty():
			continue
		var site := lair_site as Dictionary
		var coord := Vector2i(int(site.get("x", 0)), int(site.get("y", 0)))
		if not _tile_data.has(coord):
			continue
		var details := _tile_data[coord] as Dictionary
		var display := String(beast.get("display", "a nameless beast"))
		details["lair_beast"] = String(beast.get("name", ""))
		details["lair_beast_display"] = display
		if String(beast.get("lair_kind", "")) == "hold":
			details["hallmark"] = "Lair of %s — the beast that brought these halls down still nests in the deep." % display
		else:
			var base_name := _tile_region_name(coord, details)
			var lair_label := "Lair of %s" % String(beast.get("name", "the beast"))
			if base_name.is_empty():
				_tile_region_names[coord] = lair_label
			elif not base_name.contains(lair_label):
				_tile_region_names[coord] = "%s — %s" % [base_name, lair_label]
			details["description"] = "Something vast dens here. This is the lair of %s." % display
		_tile_data[coord] = details

## --- World Chronicle view ----------------------------------------------------

## A read-only "World Chronicle" dialog beside the map-mode buttons: the
## 15-25 loudest events of the age plus the named beasts' fates.
func _setup_world_chronicle_ui() -> void:
	var top_bar := get_node_or_null("MapUi/TopBar/TopBarLayout")
	var map_ui := get_node_or_null("MapUi")
	if top_bar == null or map_ui == null:
		return
	_world_chronicle_button = Button.new()
	_world_chronicle_button.name = "WorldChronicleButton"
	_world_chronicle_button.text = "World Chronicle"
	_world_chronicle_button.tooltip_text = "The recorded history of the age"
	_world_chronicle_button.pressed.connect(_on_world_chronicle_pressed)
	top_bar.add_child(_world_chronicle_button)
	_world_chronicle_dialog = AcceptDialog.new()
	_world_chronicle_dialog.name = "WorldChronicleDialog"
	_world_chronicle_dialog.title = "World Chronicle"
	_world_chronicle_dialog.ok_button_text = "Close"
	var chronicle_margin := MarginContainer.new()
	chronicle_margin.add_theme_constant_override("margin_left", 12)
	chronicle_margin.add_theme_constant_override("margin_right", 12)
	chronicle_margin.add_theme_constant_override("margin_top", 8)
	chronicle_margin.add_theme_constant_override("margin_bottom", 8)
	_world_chronicle_label = RichTextLabel.new()
	_world_chronicle_label.bbcode_enabled = true
	_world_chronicle_label.scroll_active = true
	_world_chronicle_label.fit_content = false
	_world_chronicle_label.custom_minimum_size = Vector2(600.0, 440.0)
	chronicle_margin.add_child(_world_chronicle_label)
	_world_chronicle_dialog.add_child(chronicle_margin)
	map_ui.add_child(_world_chronicle_dialog)

func _on_world_chronicle_pressed() -> void:
	if _world_chronicle_dialog == null or _world_chronicle_label == null:
		return
	_world_chronicle_label.text = WorldChronicleService.overview_bbcode(_world_chronicle)
	_world_chronicle_dialog.popup_centered(Vector2i(660, 520))

## Resolves a non-enterable ambient structure tile into a gazetteer site
## (overworld-atlas art + name) or returns {} when the tile carries no
## standalone landmark art. Structures painted on the settlement layer read
## their atlas coords from the layer; detail-only ambient marks read the
## "tile" of their option Dictionary.
func _ambient_site_for_tile(coord: Vector2i, details: Dictionary) -> Dictionary:
	# Enterable settlements are emitted elsewhere; never double as scenery.
	if details.has("settlement_type"):
		return {}
	var structure_id := String(details.get("structure", "")).strip_edges()
	# Only the structures that actually stand on the overworld map become
	# wilds landmarks - i.e. the ones painted on the settlement layer. The
	# detail-only ambient (extra flavour that surfaces solely in the zoomed
	# map view) is deliberately not projected into the walkable world, which
	# keeps the wilds matching the world map and the site list bounded.
	if settlement_layer == null:
		return {}
	var atlas_coords := settlement_layer.get_cell_atlas_coords(coord)
	if atlas_coords.x < 0:
		return {}
	# Felled woods and tilled fields render as ground, not standalone art;
	# crop/stump scatter cells also paint the settlement layer with no
	# structure of their own - both are excluded here.
	if structure_id.is_empty() or structure_id == "cutWoods" or structure_id == "farmField":
		return {}
	var label := _tile_region_name(coord, details)
	if label.is_empty():
		label = structure_id
	return {
		"x": coord.x, "y": coord.y,
		"class": "ambient",
		"tile_atlas": [atlas_coords.x, atlas_coords.y],
		# The structure id lets the walkable wilds pick a real footprint
		# recipe (building/camp/prop) instead of guessing from the icon art;
		# older saves without it fall back to an atlas-coordinate lookup.
		"structure": structure_id,
		"name": label
	}

func _apply_base_tiles(base_biome_map: Dictionary) -> void:
	for y in range(map_size.y):
		for x in range(map_size.x):
			var coord := Vector2i(x, y)
			var base_biome := base_biome_map.get(coord, BIOME_GRASSLAND) as String
			var tile_coords := _biome_to_tile(base_biome)
			map_layer.set_cell(coord, _atlas_source_id, tile_coords)
		if y > 0 and y % GENERATION_YIELD_ROW_INTERVAL == 0:
			_set_loading_progress(20.0 + 25.0 * float(y) / float(maxi(map_size.y, 1)))
			await _yield_generation_wave()

## Rounds the coastlines after every base-layer edit has landed: land
## bulges into neighboring water cells with capped bands, replacing the
## hard tile-grid shoreline with an organic scallop. Only terrain art
## feeds the bulges - settlement icons count as land but never as art.
func _apply_coast_overlay() -> void:
	if map_layer == null or map_layer.tile_set == null:
		return
	if _coast_layer == null:
		_coast_layer = TileMapLayer.new()
		_coast_layer.name = "CoastLayer"
		add_child(_coast_layer)
		move_child(_coast_layer, map_layer.get_index() + 1)
		_coast_layer.position = map_layer.position
		_coast_layer.scale = map_layer.scale
	_coast_layer.tile_set = map_layer.tile_set
	var coast_started := Time.get_ticks_msec()
	var coast_art_tiles: Array[Vector2i] = [
		SAND_TILE, GRASS_TILE, BADLANDS_TILE, MARSH_TILE, SNOW_TILE, STONE_TILE
	]
	_coast_source_id = OverworldCoastService.apply_coast_overlay(
		_coast_layer,
		map_layer,
		WATER_TILE,
		coast_art_tiles,
		tile_size,
		map_size,
		_coast_source_id
	)
	print("[OverworldMap] coast overlay: %d ms" % (Time.get_ticks_msec() - coast_started))

func _apply_overlays_and_metadata(
	base_biome_map: Dictionary,
	biome_map: Dictionary,
	tree_map: Dictionary,
	highland_map: Dictionary,
	height_map: Dictionary,
	temperature_map: Dictionary,
	moisture_map: Dictionary,
	river_tiles: Dictionary,
	name_rng: RandomNumberGenerator
) -> void:
	var overlays_started := Time.get_ticks_msec()
	var w := map_size.x
	var rows := map_size.y
	# Browser proximity fields are near-euclidean distance transforms
	# (computeEuclideanDistanceField): coast from OCEAN tiles only
	# (falloff 4.2, main.js:28270-28311), marsh from marsh tiles (3.5,
	# main.js:23089-23112), desert from sand+badlands (4.5,
	# main.js:22846-22868), water depth from land (normalized by the map's
	# deepest water, main.js:24761-24784), and forest canopy as distance
	# to the forest EDGE inside forests (falloff 4.2, main.js:28313-28357).
	var ocean_cells := _landmass_masks.get("ocean_cells", {}) as Dictionary
	var ocean_sources: Array[Vector2i] = []
	for cell_variant: Variant in ocean_cells.keys():
		ocean_sources.append(cell_variant as Vector2i)
	var marsh_sources: Array[Vector2i] = []
	var desert_sources: Array[Vector2i] = []
	var land_sources: Array[Vector2i] = []
	var non_forest_sources: Array[Vector2i] = []
	var forest_mask := PackedByteArray()
	forest_mask.resize(w * rows)
	for y in range(rows):
		for x in range(w):
			var coord := Vector2i(x, y)
			var cell_biome := base_biome_map.get(coord, BIOME_GRASSLAND) as String
			if cell_biome == BIOME_MARSH:
				marsh_sources.append(coord)
			elif cell_biome == BIOME_DESERT or cell_biome == BIOME_BADLANDS:
				desert_sources.append(coord)
			if cell_biome != BIOME_WATER:
				land_sources.append(coord)
			# Browser forest mask: grass-base forest tiles only (jungle and
			# snow woods excluded, main.js:28322).
			var is_forest_cell := cell_biome == BIOME_GRASSLAND and tree_map.has(coord) and String(tree_map.get(coord, BIOME_FOREST)) != BIOME_JUNGLE
			if is_forest_cell:
				forest_mask[y * w + x] = 1
			else:
				non_forest_sources.append(coord)
	var coast_field := _chamfer_distance_field(ocean_sources)
	var marsh_field := _chamfer_distance_field(marsh_sources)
	var desert_field := _chamfer_distance_field(desert_sources)
	var land_field := _chamfer_distance_field(land_sources)
	var canopy_field := _chamfer_distance_field(non_forest_sources)
	var has_ocean := not ocean_sources.is_empty()
	var has_marsh := not marsh_sources.is_empty()
	var has_desert := not desert_sources.is_empty()
	var max_water_depth := 0.0
	for y in range(rows):
		for x in range(w):
			if String(base_biome_map.get(Vector2i(x, y), BIOME_GRASSLAND)) != BIOME_WATER:
				continue
			var depth := float(land_field[y * w + x])
			if depth > max_water_depth:
				max_water_depth = depth
	var depth_normalization := (1.0 / max_water_depth) if max_water_depth > 0.0 else 1.0
	var proximity_ms := Time.get_ticks_msec() - overlays_started
	overlays_started = Time.get_ticks_msec()
	var region_naming := _build_region_name_map(biome_map, name_rng)
	var region_names := region_naming.get("names", {}) as Dictionary
	var region_clusters := region_naming.get("clusters", {}) as Dictionary
	print("[OverworldMap] overlays: proximity %d ms | region names %d ms" % [proximity_ms, Time.get_ticks_msec() - overlays_started])
	overlays_started = Time.get_ticks_msec()
	var have_mountain_scores := _mountain_score_buffer.size() == w * rows
	var ruggedness_seed := map_seed + 0x51a7bead
	for y in range(map_size.y):
		for x in range(map_size.x):
			var coord := Vector2i(x, y)
			var idx := y * w + x
			var base_biome := base_biome_map.get(coord, BIOME_GRASSLAND) as String
			var highland_biome := String(highland_map.get(coord, ""))
			if highland_layer != null:
				if highland_map.has(coord):
					var highland_tile := _highland_tile_for_biome(highland_biome, base_biome, coord)
					highland_layer.set_cell(coord, _atlas_source_id, highland_tile)
				else:
					highland_layer.erase_cell(coord)
			# Browser main.js:23684-23687: sand/badlands bases under mountain
			# overlays convert to bare stone. No stone biome id exists, so
			# only the art changes; the classification keeps the base biome.
			if highland_biome == BIOME_MOUNTAIN and (base_biome == BIOME_DESERT or base_biome == BIOME_BADLANDS) and map_layer != null:
				map_layer.set_cell(coord, _atlas_source_id, STONE_TILE)
			var biome := biome_map.get(coord, base_biome) as String
			var region_name := String(region_names.get(coord, ""))
			var has_river := river_tiles.has(coord)
			var overlay_label := ""
			if tree_layer != null and not has_river:
				var tree_tile := tree_layer.get_cell_atlas_coords(coord)
				if tree_tile == TREE_TILE or tree_tile == TREE_SNOW_TILE:
					overlay_label = "forest"
				# Lone trees carry the overlay flag too, so settlement and
				# structure placement stops planting under standing tree art.
				elif tree_tile == JUNGLE_TREE_TILE or tree_tile == TREE_LONE_TILE:
					overlay_label = "tree"
			var overlay_flags := 0
			if overlay_label == "tree":
				overlay_flags |= TILE_OVERLAY_TREE
			elif overlay_label == "forest":
				overlay_flags |= TILE_OVERLAY_FOREST
			if has_river:
				overlay_flags |= TILE_OVERLAY_RIVER
			var is_water := base_biome == BIOME_WATER
			var coast_proximity := 0.0
			var marsh_proximity := 0.0
			var desert_proximity := 0.0
			var canopy_density := 0.0
			var water_depth := 0.0
			if is_water:
				water_depth = clampf(float(land_field[idx]) * depth_normalization, 0.0, 1.0)
			else:
				if has_ocean:
					coast_proximity = clampf(1.0 - float(coast_field[idx]) / 4.2, 0.0, 1.0)
				if base_biome == BIOME_GRASSLAND:
					if has_marsh:
						marsh_proximity = clampf(1.0 - float(marsh_field[idx]) / 3.5, 0.0, 1.0)
					if has_desert:
						desert_proximity = clampf(1.0 - float(desert_field[idx]) / 4.5, 0.0, 1.0)
				if forest_mask[idx] == 1:
					canopy_density = clampf(float(canopy_field[idx]) / 4.2, 0.0, 1.0)
			# Browser mountainRuggedness (main.js:23673-23683, 24845-24857):
			# 0.35 + h*0.45 on mountains, 0.55 + h*0.35 on peaks, +/- 0.15
			# seeded noise; zero everywhere without a mountain overlay.
			var mountain_ruggedness := 0.0
			if highland_biome == BIOME_MOUNTAIN:
				var normalized_height := clampf(float(_mountain_score_buffer[idx]), 0.0, 1.0) if have_mountain_scores else clampf((float(height_map.get(coord, 0.0)) - water_level) / maxf(0.0001, 1.0 - water_level), 0.0, 1.0)
				var is_peak := float(height_map.get(coord, 0.0)) >= 0.97
				var base_ruggedness := (0.55 + normalized_height * 0.35) if is_peak else (0.35 + normalized_height * 0.45)
				var ruggedness_noise := _hash_coords(x, y, ruggedness_seed)
				mountain_ruggedness = clampf(base_ruggedness + (ruggedness_noise - 0.5) * 0.3, 0.0, 1.0)
			_tile_data[coord] = {
				"biome_id": _biome_to_id(biome),
				"base_biome_id": _biome_to_id(base_biome),
				"overlay_flags": overlay_flags,
				"hill_biome_id": _biome_to_id(String(highland_map.get(coord, BIOME_GRASSLAND))),
				# The cultural pipeline (ambient culture rolls, ambient
				# structure gates, political terrain costs) matches on
				# label strings, not ids - without these every
				# biome-keyed culture rule silently never fires.
				"biome_type": biome,
				"base_biome": base_biome,
				"overlay": overlay_label,
				"hill_overlay": highland_biome,
				"structure": "",
				"structure_details": null,
				"ambient_structure": null,
				"surface_variation": _surface_variation_for_coord(coord, base_biome),
				"water_depth": water_depth,
				"coast_proximity": coast_proximity,
				"marsh_proximity": marsh_proximity,
				"desert_proximity": desert_proximity,
				"forest_canopy_density": canopy_density,
				"mountain_ruggedness": mountain_ruggedness,
				"biome_cluster_id": int(region_clusters.get(coord, -1)),
				"temperature": temperature_map.get(coord, 0.0),
				"moisture": moisture_map.get(coord, 0.0)
			}
			if not region_name.is_empty():
				_tile_region_names[coord] = region_name
	print("[OverworldMap] overlays: tile-data loop %d ms" % (Time.get_ticks_msec() - overlays_started))


func _build_river_map_buffers(
	height_buffer: PackedFloat32Array,
	moisture_buffer: PackedFloat32Array,
	base_biome_buffer: PackedByteArray,
	rng: RandomNumberGenerator
) -> Dictionary:
	return OverworldRiverService.build_river_map_buffers(height_buffer, moisture_buffer, base_biome_buffer, rng, map_size, water_level, river_frequency)


func _build_river_map(
	height_map: Dictionary,
	moisture_map: Dictionary,
	base_biome_map: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	return OverworldRiverService.build_river_map(height_map, moisture_map, base_biome_map, rng, map_size, water_level, river_frequency)

func _build_ocean_distance_map(base_biome_map: Dictionary) -> Dictionary:
	return OverworldTerrainService.build_ocean_distance_map(
		base_biome_map,
		map_size,
		BIOME_WATER,
		RIVER_NEIGHBOR_DEFINITIONS,
		Callable(self, "_is_valid_map_coord")
	)

func _compute_edge_connected_water_mask(base_biome_map: Dictionary) -> Dictionary:
	return OverworldTerrainService.compute_edge_connected_water_mask(
		base_biome_map,
		map_size,
		BIOME_WATER,
		RIVER_NEIGHBOR_DEFINITIONS,
		Callable(self, "_is_valid_map_coord")
	)

func _apply_river_tiles(
	river_map: Dictionary,
	base_biome_map: Dictionary,
	highland_map: Dictionary,
	tree_map: Dictionary,
	edge_connected_water: Dictionary
) -> Dictionary:
	var river_source_id := _river_atlas_source_id if _river_atlas_source_id >= 0 else _atlas_source_id
	return OverworldRiverService.apply_river_tiles(river_map, base_biome_map, highland_map, tree_map, edge_connected_water, map_size, river_layer, highland_layer, tree_layer, river_source_id)

func _resolve_river_tile(
	river_map: Dictionary,
	coord: Vector2i,
	base_biome_map: Dictionary,
	ocean_mask: Dictionary
) -> Vector2i:
	return OverworldRiverService.resolve_river_tile(river_map, coord, base_biome_map, ocean_mask, map_size)

func _apply_mountain_overlay_variants(highland_map: Dictionary, height_map: Dictionary) -> void:
	OverworldTerrainFeatureService.apply_mountain_overlay_variants(highland_map, height_map, highland_layer, _atlas_source_id, map_size)


func _place_volcano_tiles(highland_map: Dictionary, height_map: Dictionary, rng: RandomNumberGenerator) -> void:
	var lake_cells_variant: Variant = _landmass_masks.get("lake_cells", {})
	var lake_cells := (lake_cells_variant as Dictionary) if lake_cells_variant is Dictionary else {}
	OverworldTerrainFeatureService.place_volcano_tiles(highland_map, height_map, rng, highland_layer, map_layer, _atlas_source_id, map_size, _tile_data, lake_cells)


func _apply_oases_and_lava(volcanoes: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	OverworldTerrainFeatureService.apply_oases_and_lava(volcanoes, rng, highland_layer, map_layer, _atlas_source_id, map_size, _tile_data)


func _surface_variation_for_coord(coord: Vector2i, base_biome: String) -> float:
	return OverworldTerrainFeatureService.surface_variation_for_coord(coord, base_biome, _rainfall_noise, _temperature_noise)


func _update_terrain_shading_overlay(base_biome_map: Dictionary) -> void:
	if terrain_shading_overlay == null:
		return
	var shading_image := Image.create(map_size.x, map_size.y, false, Image.FORMAT_RGBA8)
	for y in range(map_size.y):
		for x in range(map_size.x):
			var coord := Vector2i(x, y)
			var tile_meta := _tile_data.get(coord, {}) as Dictionary
			var base_biome := _tile_base_biome_from_data(tile_meta)
			var color := Color(0, 0, 0, 0)
			color = _apply_surface_noise_shading_to_color(color, base_biome, float(tile_meta.get("surface_variation", 0.0)))
			color = _apply_coastal_shading_to_color(color, base_biome, _tile_biome_from_data(tile_meta), tile_meta)
			color = _apply_volcano_shading_to_color(color, _tile_biome_from_data(tile_meta), tile_meta)
			shading_image.set_pixel(x, y, color)
	var shading_texture := ImageTexture.create_from_image(shading_image)
	terrain_shading_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	terrain_shading_overlay.centered = false
	terrain_shading_overlay.position = Vector2.ZERO
	terrain_shading_overlay.scale = Vector2(float(tile_size), float(tile_size))
	terrain_shading_overlay.texture = shading_texture


## Browser applyVolcanoShading: land near a volcano darkens by up to
## 40% alpha with proximity; mountains skip it (their art is already dark).
func _apply_volcano_shading_to_color(base_color: Color, biome: String, tile_meta: Dictionary) -> Color:
	if biome == BIOME_MOUNTAIN:
		return base_color
	var proximity := clampf(float(tile_meta.get("volcano_proximity", 0.0)), 0.0, 1.0)
	if proximity <= 0.01:
		return base_color
	return base_color.blend(Color(0.0, 0.0, 0.0, proximity * 0.4))

func _apply_surface_noise_shading_to_color(base_color: Color, base_biome: String, variation: float) -> Color:
	if base_biome != BIOME_TUNDRA and base_biome != BIOME_DESERT and base_biome != BIOME_BADLANDS:
		return base_color
	var v := clampf(variation, -1.0, 1.0)
	if absf(v) < 0.01:
		return base_color
	var lighten := v > 0.0
	var intensity := absf(v)
	if base_biome == BIOME_TUNDRA:
		if lighten:
			return _blend_overlay_color(base_color, Color8(255, 255, 255), clampf(0.1 + intensity * 0.28, 0.0, 0.55))
		return _blend_overlay_color(base_color, Color8(120, 146, 182), clampf(0.08 + intensity * 0.26, 0.0, 0.55))
	if base_biome == BIOME_DESERT:
		if lighten:
			return _blend_overlay_color(base_color, Color8(255, 236, 192), clampf(0.08 + intensity * 0.24, 0.0, 0.55))
		return _blend_overlay_color(base_color, Color8(184, 140, 78), clampf(0.08 + intensity * 0.22, 0.0, 0.55))
	if lighten:
		return _blend_overlay_color(base_color, Color8(235, 206, 168), clampf(0.08 + intensity * 0.22, 0.0, 0.55))
	return _blend_overlay_color(base_color, Color8(143, 102, 66), clampf(0.08 + intensity * 0.24, 0.0, 0.55))


func _apply_coastal_shading_to_color(base_color: Color, base_biome: String, biome_type: String, tile_meta: Dictionary) -> Color:
	var color := base_color
	if base_biome == BIOME_WATER:
		var shallow_factor := clampf(1.0 - float(tile_meta.get("water_depth", 0.0)), 0.0, 1.0)
		if shallow_factor > 0.01:
			color = _blend_overlay_color(color, Color8(88, 164, 218), shallow_factor * 0.32)
		return color
	if base_biome != BIOME_GRASSLAND:
		return color
	var coast_proximity := clampf(float(tile_meta.get("coast_proximity", 0.0)), 0.0, 1.0)
	if coast_proximity > 0.01:
		color = _blend_overlay_color(color, Color8(148, 205, 184), coast_proximity * 0.32)
	var marsh_proximity := clampf(float(tile_meta.get("marsh_proximity", 0.0)), 0.0, 1.0)
	if marsh_proximity > 0.01:
		color = _blend_overlay_color(color, Color8(82, 64, 40), marsh_proximity * 0.55)
	var forest_density := clampf(float(tile_meta.get("forest_canopy_density", 0.0)), 0.0, 1.0)
	if biome_type == BIOME_FOREST and forest_density > 0.01:
		color = _blend_overlay_color(color, Color8(26, 74, 36), forest_density * 0.55)
	var desert_proximity := clampf(float(tile_meta.get("desert_proximity", 0.0)), 0.0, 1.0)
	if desert_proximity > 0.01:
		color = _blend_overlay_color(color, Color8(228, 202, 146), desert_proximity * 0.4)
	return color


func _blend_overlay_color(base_color: Color, tint_color: Color, alpha: float) -> Color:
	var overlay_alpha := clampf(alpha, 0.0, 1.0)
	if overlay_alpha <= 0.0:
		return base_color
	var out_alpha := overlay_alpha + base_color.a * (1.0 - overlay_alpha)
	if out_alpha <= 0.0001:
		return Color(0, 0, 0, 0)
	var out_r := (tint_color.r * overlay_alpha + base_color.r * base_color.a * (1.0 - overlay_alpha)) / out_alpha
	var out_g := (tint_color.g * overlay_alpha + base_color.g * base_color.a * (1.0 - overlay_alpha)) / out_alpha
	var out_b := (tint_color.b * overlay_alpha + base_color.b * base_color.a * (1.0 - overlay_alpha)) / out_alpha
	return Color(out_r, out_g, out_b, out_alpha)

## Browser-parity region clusters: 8-connected same-biome flood fill,
## a stable cluster id per region, and the region name generated with the
## CLUSTER size as context (oceans under 120 tiles downgrade to "Sea").
## Returns {"names": {coord: String}, "clusters": {coord: int}}.
func _build_region_name_map(
	biome_map: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var region_names := {}
	var cluster_ids := {}
	var next_cluster_id := 0
	for y in range(map_size.y):
		for x in range(map_size.x):
			var start := Vector2i(x, y)
			if cluster_ids.has(start):
				continue
			var biome := String(biome_map.get(start, BIOME_GRASSLAND))
			var cluster_id := next_cluster_id
			next_cluster_id += 1
			var cluster_cells: Array[Vector2i] = []
			var frontier: Array[Vector2i] = [start]
			cluster_ids[start] = cluster_id
			while not frontier.is_empty():
				var coord: Vector2i = frontier.pop_back()
				cluster_cells.append(coord)
				for offset: Vector2i in NEIGHBOR_OFFSETS_8:
					var neighbor: Vector2i = coord + offset
					if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= map_size.x or neighbor.y >= map_size.y:
						continue
					if cluster_ids.has(neighbor):
						continue
					if String(biome_map.get(neighbor, BIOME_GRASSLAND)) == biome:
						cluster_ids[neighbor] = cluster_id
						frontier.append(neighbor)
			var water_body_type := ""
			if biome == BIOME_WATER:
				water_body_type = _water_region_type(start, biome_map)
			var region_name := _generate_biome_region_name(biome, water_body_type, rng, cluster_cells.size())
			if not region_name.is_empty():
				for coord: Vector2i in cluster_cells:
					region_names[coord] = region_name
	_apply_island_region_names(biome_map, rng, region_names)
	return {"names": region_names, "clusters": cluster_ids}

## Small islands read as islands, not inland terrain: every land cell on a
## landmass at or below the island size cutoff shares one island-style name
## (Ashen Isle, Stormreach, Isle of Larks) instead of the per-biome
## grassland/desert/marsh region names the cluster pass assigned above.
func _apply_island_region_names(
	biome_map: Dictionary,
	rng: RandomNumberGenerator,
	region_names: Dictionary
) -> void:
	var island_max_tiles := maxi(64, int(round(float(map_size.x * map_size.y) / 512.0)))
	var visited := {}
	var used_names := {}
	for y in range(map_size.y):
		for x in range(map_size.x):
			var start := Vector2i(x, y)
			if visited.has(start):
				continue
			if String(biome_map.get(start, BIOME_GRASSLAND)) == BIOME_WATER:
				continue
			var cells: Array[Vector2i] = []
			var frontier: Array[Vector2i] = [start]
			var touches_edge := false
			visited[start] = true
			while not frontier.is_empty():
				var coord: Vector2i = frontier.pop_back()
				cells.append(coord)
				if coord.x == 0 or coord.y == 0 or coord.x == map_size.x - 1 or coord.y == map_size.y - 1:
					touches_edge = true
				for offset: Vector2i in NEIGHBOR_OFFSETS_8:
					var neighbor: Vector2i = coord + offset
					if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= map_size.x or neighbor.y >= map_size.y:
						continue
					if visited.has(neighbor):
						continue
					if String(biome_map.get(neighbor, BIOME_GRASSLAND)) == BIOME_WATER:
						continue
					visited[neighbor] = true
					frontier.append(neighbor)
			if touches_edge or cells.size() > island_max_tiles:
				continue
			var island_name := WORLD_NAMING.generate_island_name(rng, cells.size(), used_names)
			if island_name.is_empty():
				continue
			used_names[island_name] = true
			for coord: Vector2i in cells:
				region_names[coord] = island_name

func _water_region_type(start_coord: Vector2i, biome_map: Dictionary) -> String:
	var lake_cells_variant: Variant = _landmass_masks.get("lake_cells", {})
	if lake_cells_variant is Dictionary:
		var lake_cells := lake_cells_variant as Dictionary
		if lake_cells.has(start_coord):
			return "lake"
	var ocean_cells_variant: Variant = _landmass_masks.get("ocean_cells", {})
	if ocean_cells_variant is Dictionary:
		var ocean_cells := ocean_cells_variant as Dictionary
		if ocean_cells.has(start_coord):
			return "ocean"

	var frontier: Array[Vector2i] = [start_coord]
	var visited := {}
	while not frontier.is_empty():
		var coord: Vector2i = frontier.pop_back()
		if visited.has(coord):
			continue
		if String(biome_map.get(coord, BIOME_GRASSLAND)) != BIOME_WATER:
			continue
		visited[coord] = true
		if coord.x == 0 or coord.y == 0 or coord.x == map_size.x - 1 or coord.y == map_size.y - 1:
			return "ocean"
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = coord + offset
			if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= map_size.x or neighbor.y >= map_size.y:
				continue
			if visited.has(neighbor):
				continue
			if String(biome_map.get(neighbor, BIOME_GRASSLAND)) == BIOME_WATER:
				frontier.append(neighbor)
	return "lake"


func _generate_landmass_masks_from_biome_map(biome_map: Dictionary) -> Dictionary:
	return TerrainGenerator.generate_landmass_masks_from_biome_map(biome_map, map_size, BIOME_WATER)


func _ensure_landmass_presence(height_map: Dictionary) -> void:
	var desired_land_floor := 0.12
	for _pass_index in range(3):
		var provisional_biomes: Dictionary = {}
		for coord: Vector2i in height_map.keys():
			var height: float = height_map.get(coord, 0.0)
			provisional_biomes[coord] = BIOME_WATER if height < water_level else BIOME_GRASSLAND

		var masks := _generate_landmass_masks_from_biome_map(provisional_biomes)
		var land_cells := masks.get("land_mask", {}) as Dictionary
		var land_ratio := float(land_cells.size()) / maxf(1.0, float(map_size.x * map_size.y))
		if land_ratio >= desired_land_floor:
			return

		var uplift := clampf((desired_land_floor - land_ratio) * 0.85, 0.04, 0.22)
		for coord: Vector2i in height_map.keys():
			height_map[coord] = clampf(float(height_map.get(coord, 0.0)) + uplift, 0.0, 1.0)

func _guarantee_minimum_landmass(
	height_map: Dictionary,
	temperature_map: Dictionary,
	moisture_map: Dictionary,
	base_biome_map: Dictionary
) -> void:
	var desired_land_floor := 0.12
	for _pass_index in range(4):
		var water_tiles := _count_biome(base_biome_map, BIOME_WATER)
		var total_tiles: int = maxi(1, map_size.x * map_size.y)
		var land_ratio := 1.0 - (float(water_tiles) / float(total_tiles))
		if land_ratio >= desired_land_floor:
			return

		var uplift := clampf((desired_land_floor - land_ratio) * 0.95, 0.03, 0.2)
		for y in range(map_size.y):
			for x in range(map_size.x):
				var coord := Vector2i(x, y)
				var new_height := clampf(float(height_map.get(coord, 0.0)) + uplift, 0.0, 1.0)
				height_map[coord] = new_height
				var temperature := _sample_temperature(x, y, new_height)
				var moisture := _sample_moisture(x, y, new_height)
				temperature_map[coord] = temperature
				moisture_map[coord] = moisture
				base_biome_map[coord] = _assign_base_biome(coord, new_height, temperature, moisture, height_map)

## Browser hill overlays (main.js:25238-25292): snow and badlands bases get
## their dedicated hill art, plain hills hash-pick between HILLS and the two
## unused-until-now variants (selectBaseHillOverlayKey).
func _highland_tile_for_biome(highland_biome: String, base_biome: String, coord: Vector2i) -> Vector2i:
	if highland_biome == BIOME_HILLS:
		if base_biome == BIOME_TUNDRA:
			return HILLS_SNOW_TILE
		if base_biome == BIOME_BADLANDS:
			return HILLS_BADLANDS_TILE
		var variant_noise := _hash_coords(coord.x, coord.y, map_seed + 0x3ab41d7f)
		var variant_index := clampi(int(floor(variant_noise * 3.0)), 0, 2)
		if variant_index == 1:
			return HILLS_VARIANT_A_TILE
		if variant_index == 2:
			return HILLS_VARIANT_B_TILE
		return HILLS_TILE
	return _biome_to_tile(highland_biome)

func _yield_generation_wave() -> void:
	if is_inside_tree():
		await get_tree().process_frame

func _terrain_settings() -> Dictionary:
	return {
		"map_size": map_size,
		"map_seed": map_seed,
		"water_level": water_level,
		"falloff_strength": falloff_strength,
		"falloff_power": falloff_power,
		"landmass_falloff_scale": landmass_falloff_scale,
		"landmass_mask_strength": landmass_mask_strength,
		"landmass_mask_power": landmass_mask_power,
		"landmass_mask_threshold": landmass_mask_threshold,
		"landmass_mask_scale": landmass_mask_scale,
		"landmass_mask_edge_falloff": landmass_mask_edge_falloff,
		"center_shape_strength": center_shape_strength,
		"edge_ocean_strength": edge_ocean_strength,
		"edge_ocean_falloff": edge_ocean_falloff,
		"edge_ocean_curve": edge_ocean_curve
	}


func _biome_lookup() -> Dictionary:
	return {
		"water": BIOME_WATER,
		"mountain": BIOME_MOUNTAIN,
		"hills": BIOME_HILLS,
		"marsh": BIOME_MARSH,
		"tundra": BIOME_TUNDRA,
		"desert": BIOME_DESERT,
		"badlands": BIOME_BADLANDS,
		"forest": BIOME_FOREST,
		"jungle": BIOME_JUNGLE,
		"grassland": BIOME_GRASSLAND
	}


func _tile_lookup() -> Dictionary:
	return {
		"sand": SAND_TILE,
		"grass": GRASS_TILE,
		"badlands": BADLANDS_TILE,
		"marsh": MARSH_TILE,
		"snow": SNOW_TILE,
		"tree": TREE_TILE,
		"jungle_tree": JUNGLE_TREE_TILE,
		"water": WATER_TILE,
		"mountain": MOUNTAIN_TILE,
		"hills": HILLS_TILE
	}


func _sample_height(
	continent_noise: FastNoiseLite,
	detail_noise: FastNoiseLite,
	ridge_noise: FastNoiseLite,
	x: int,
	y: int
) -> float:
	return float(TerrainGenerator.sample_height(continent_noise, detail_noise, ridge_noise, x, y, _terrain_settings(), _landmass_centers))

func _feature_frequency_divisor() -> float:
	return maxf(1.0, float(map_size.x))


func _sample_continent_bias(x: int, y: int) -> float:
	return float(TerrainGenerator.sample_continent_bias(x, y, _terrain_settings(), _landmass_centers))


func _sample_edge_ocean_bias(x: int, y: int) -> float:
	return float(TerrainGenerator.sample_edge_ocean_bias(x, y, _terrain_settings()))


func _sample_radial_falloff_bias(centered_nx: float, centered_ny: float) -> float:
	return float(TerrainGenerator.sample_radial_falloff_bias(centered_nx, centered_ny, falloff_strength, falloff_power))


func _sample_landmass_center_bias(centered_nx: float, centered_ny: float) -> float:
	return float(TerrainGenerator.sample_landmass_center_bias(centered_nx, centered_ny, landmass_falloff_scale, falloff_power, _landmass_centers))


func _sample_landmass_mask_bias(nx: float, ny: float) -> float:
	return float(TerrainGenerator.sample_landmass_mask_bias(nx, ny, _terrain_settings()))


func _configure_landmass_centers(rng: RandomNumberGenerator) -> void:
	_landmass_centers = TerrainGenerator.configure_landmass_centers(rng, landmass_center_count, landmass_center_margin, landmass_center_min_separation) as Array[Vector2]


func _distance_to_nearest_landmass_center(nx: float, ny: float) -> float:
	return float(TerrainGenerator.distance_to_nearest_landmass_center(nx, ny, _landmass_centers))


func _smooth_height_map(height_map: Dictionary, passes: int, strength: float) -> void:
	TerrainGenerator.smooth_height_map(height_map, passes, strength, water_level)


func _smooth_height_buffer(height_buffer: PackedFloat32Array, passes: int, strength: float) -> void:
	var height_map := _float_buffer_to_dictionary(height_buffer)
	_smooth_height_map(height_map, passes, strength)
	for i in range(height_buffer.size()):
		height_buffer[i] = float(height_map.get(_index_to_coord(i), water_level))


func _ensure_landmass_presence_buffer(height_buffer: PackedFloat32Array) -> void:
	var height_map := _float_buffer_to_dictionary(height_buffer)
	_ensure_landmass_presence(height_map)
	for i in range(height_buffer.size()):
		height_buffer[i] = float(height_map.get(_index_to_coord(i), water_level))


func _guarantee_minimum_landmass_buffer(
	height_buffer: PackedFloat32Array,
	temperature_buffer: PackedFloat32Array,
	moisture_buffer: PackedFloat32Array,
	base_biome_buffer: PackedByteArray
) -> void:
	var height_map := _float_buffer_to_dictionary(height_buffer)
	var temperature_map := _float_buffer_to_dictionary(temperature_buffer)
	var moisture_map := _float_buffer_to_dictionary(moisture_buffer)
	var base_biome_map := _biome_buffer_to_dictionary(base_biome_buffer)
	_guarantee_minimum_landmass(height_map, temperature_map, moisture_map, base_biome_map)
	for i in range(height_buffer.size()):
		var coord := _index_to_coord(i)
		height_buffer[i] = float(height_map.get(coord, water_level))
		temperature_buffer[i] = float(temperature_map.get(coord, 0.0))
		moisture_buffer[i] = float(moisture_map.get(coord, 0.0))
		base_biome_buffer[i] = _biome_to_id(String(base_biome_map.get(coord, BIOME_GRASSLAND)))


func _sample_landmass_mask(nx: float, ny: float) -> float:
	return float(TerrainGenerator.sample_landmass_mask(nx, ny, _terrain_settings()))


func _ellipse_distance(nx: float, ny: float, center: Vector2, radius: Vector2) -> float:
	return float(TerrainGenerator.ellipse_distance(nx, ny, center, radius))


func _value_noise(x: float, y: float, seed_value: int) -> float:
	var xi := int(floor(x))
	var yi := int(floor(y))
	var tx := x - float(xi)
	var ty := y - float(yi)
	var a := _hash_coords(xi, yi, seed_value)
	var b := _hash_coords(xi + 1, yi, seed_value)
	var c := _hash_coords(xi, yi + 1, seed_value)
	var d := _hash_coords(xi + 1, yi + 1, seed_value)
	var u := _fade(tx)
	var v := _fade(ty)
	var ab := lerpf(a, b, u)
	var cd := lerpf(c, d, u)
	return lerpf(ab, cd, v)


func _hash_coords(x: int, y: int, seed_value: int) -> float:
	var h: int = x * 374761393 + y * 668265263 + seed_value * 2654435761
	h = int((h ^ (h >> 13)) * 1274126177)
	h = h ^ (h >> 16)
	var unsigned: int = h & 0xffffffff
	return float(unsigned) / 4294967295.0


func _fade(t: float) -> float:
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


func _to_normalized(noise_sample: float) -> float:
	return clampf((noise_sample + 1.0) * 0.5, 0.0, 1.0)


func _sample_temperature(x: int, y: int, elevation: float) -> float:
	var latitude := absf((float(y) / maxf(1.0, float(map_size.y - 1))) * 2.0 - 1.0)
	var latitudinal_cold := pow(latitude, 1.4)
	var base_variation := _to_normalized(_temperature_noise.get_noise_2d(float(x), float(y)))
	var detail_variation := _to_normalized(_temperature_noise.get_noise_2d(float(x) * 2.1, float(y) * 2.1))
	var layered_noise := base_variation * 0.7 + detail_variation * 0.3
	var north_bias := pow(1.0 - (float(y) / maxf(1.0, float(map_size.y - 1))), 1.35) * 0.22
	var above_sea := maxf(0.0, elevation - water_level)
	var elevation_cooling := above_sea * 0.9
	return clampf((layered_noise * 0.55 + (1.0 - latitudinal_cold) * 0.45) - elevation_cooling - north_bias, 0.0, 1.0)


## Browser latitude convention (main.js:21616): latitude = 1 - normalizedY,
## so the NORTH pole is the top row and the south holds no snow at all.
func _north_latitude(y: int) -> float:
	return 1.0 - (float(y) + 0.5) / maxf(1.0, float(map_size.y))


## Browser computeSnowPresence (main.js:21607-21635): guaranteed snow above
## latitude 0.86; through 0.5..0.86 coverage = bandFactor*0.7 +
## elevationFactor*0.3 thinned by octave noise; never south of 0.5.
func _compute_snow_presence(x: int, y: int, height_value: float) -> bool:
	var latitude := _north_latitude(y)
	if latitude >= SNOW_LATITUDE_FULL:
		return true
	if latitude <= SNOW_LATITUDE_START:
		return false
	var band_factor := clampf((latitude - SNOW_LATITUDE_START) / (SNOW_LATITUDE_FULL - SNOW_LATITUDE_START), 0.0, 1.0)
	var elevation_factor := clampf((height_value - water_level) * 3.8, 0.0, 1.0)
	var coverage := clampf(band_factor * 0.7 + elevation_factor * 0.3, 0.0, 1.0)
	if _snow_edge_noise == null:
		return band_factor >= 0.5
	return _to_normalized(_snow_edge_noise.get_noise_2d(float(x), float(y))) < coverage


## Re-asserts the snow-presence contract on the whole base-biome map: land
## is tundra exactly where the snow field says so.
func _enforce_snow_presence(base_biome_map: Dictionary, height_buffer: PackedFloat32Array) -> void:
	for y in range(map_size.y):
		var latitude := _north_latitude(y)
		if latitude <= SNOW_LATITUDE_START:
			# South of the band only stray tundra needs clearing.
			for x in range(map_size.x):
				var coord := Vector2i(x, y)
				if String(base_biome_map.get(coord, "")) == BIOME_TUNDRA:
					base_biome_map[coord] = BIOME_GRASSLAND
			continue
		for x in range(map_size.x):
			var coord := Vector2i(x, y)
			var biome := String(base_biome_map.get(coord, ""))
			if biome == BIOME_WATER:
				continue
			var idx := _xy_to_index(x, y)
			if idx < 0 or idx >= height_buffer.size():
				continue
			if _compute_snow_presence(x, y, float(height_buffer[idx])):
				base_biome_map[coord] = BIOME_TUNDRA
			elif biome == BIOME_TUNDRA:
				base_biome_map[coord] = BIOME_GRASSLAND


func _rainfall_at(idx: int) -> float:
	if idx >= 0 and idx < _rainfall_buffer.size():
		return float(_rainfall_buffer[idx])
	return 0.5


## Browser rainfall model (main.js:21459-21531): base/detail octabands mixed
## 0.65/0.35, then value*0.55 + latitudeInfluence*0.25 + coastalInfluence*0.2
## + the layout's rainfallBias, followed by the rain-shadow sweeps.
func _build_rainfall_buffer(height_buffer: PackedFloat32Array) -> void:
	var cell_count := height_buffer.size()
	_rainfall_buffer.resize(cell_count)
	var width := map_size.x
	for y in range(map_size.y):
		var ny := (float(y) + 0.5) / maxf(1.0, float(map_size.y))
		var latitude_influence := 1.0 - absf(ny - 0.5) * 1.8
		var row := y * width
		for x in range(width):
			var idx := row + x
			var elevation := float(height_buffer[idx])
			var base_rain := _to_normalized(_rainfall_noise.get_noise_2d(float(x), float(y)))
			var detail_rain := _to_normalized(_rainfall_detail_noise.get_noise_2d(float(x), float(y)))
			var coastal_influence := clampf(1.0 - absf(elevation - water_level) * 2.4, 0.0, 1.0)
			var rainfall := base_rain * 0.65 + detail_rain * 0.35
			_rainfall_buffer[idx] = clampf(rainfall * 0.55 + latitude_influence * 0.25 + coastal_influence * 0.2 + _rainfall_bias, 0.0, 1.0)
	_apply_rain_shadow(height_buffer, _rainfall_buffer)


## Browser applyRainShadow (main.js:20539-20564): walking each row both
## west->east and east->west, slopes over 0.05 dry the lee side by slope*0.5
## while descents recover (-slope)*0.35, then the field is re-normalized.
func _apply_rain_shadow(elevation: PackedFloat32Array, rainfall: PackedFloat32Array) -> void:
	var adjusted := rainfall.duplicate()
	_rain_shadow_sweep(elevation, rainfall, adjusted, 0, map_size.x, 1)
	_rain_shadow_sweep(elevation, rainfall, adjusted, map_size.x - 1, -1, -1)
	_normalize_field(adjusted)
	for i in range(rainfall.size()):
		rainfall[i] = adjusted[i]


func _rain_shadow_sweep(
	elevation: PackedFloat32Array,
	rainfall: PackedFloat32Array,
	adjusted: PackedFloat32Array,
	start_x: int,
	end_x: int,
	step: int
) -> void:
	var width := map_size.x
	for y in range(map_size.y):
		var row := y * width
		var carried := float(rainfall[row + start_x])
		var x := start_x + step
		while (x < end_x) if step > 0 else (x > end_x):
			var idx := row + x
			var slope := float(elevation[idx - step]) - float(elevation[idx])
			if slope > 0.05:
				carried -= slope * 0.5
			elif slope < -0.05:
				carried += (-slope) * 0.35
			carried = clampf(carried, 0.0, 1.0)
			adjusted[idx] = clampf((float(adjusted[idx]) * 2.0 + carried) / 3.0, 0.0, 1.0)
			x += step


## Browser normalizeField (main.js:20478-20495).
func _normalize_field(field: PackedFloat32Array) -> void:
	var min_value := INF
	var max_value := -INF
	for i in range(field.size()):
		var value := float(field[i])
		min_value = minf(min_value, value)
		max_value = maxf(max_value, value)
	var value_range := max_value - min_value
	if value_range <= 0.0:
		return
	for i in range(field.size()):
		field[i] = (float(field[i]) - min_value) / value_range


## Browser estimateSeaLevels (main.js:11590-11601) with the layout's
## seaLevelShift folded into targetWaterRatio (main.js:21308).
func _estimate_sea_level(height_buffer: PackedFloat32Array) -> float:
	var total := height_buffer.size()
	if total == 0:
		return water_level
	var sorted_heights := height_buffer.duplicate()
	sorted_heights.sort()
	var clamped_ratio := clampf(0.47 + _sea_level_shift, 0.2, 0.8)
	var water_index := clampi(int(floor(float(total) * clamped_ratio)), 0, total - 1)
	return clampf(float(sorted_heights[water_index]), 0.25, 0.65)


func _sample_rainfall(x: int, y: int, _elevation: float) -> float:
	return _rainfall_at(_xy_to_index(x, y))


func _sample_moisture(x: int, y: int, elevation: float) -> float:
	var rainfall := _sample_rainfall(x, y, elevation)
	var drainage := clampf(1.0 - elevation, 0.0, 1.0)
	var noise_variation := _to_normalized(_rainfall_noise.get_noise_2d(float(x) * 1.9, float(y) * 1.9))
	return clampf(rainfall * 0.55 + drainage * 0.3 + noise_variation * 0.15, 0.0, 1.0)


func _sample_vegetation(x: int, y: int, elevation: float, moisture: float, temperature: float) -> float:
	if _vegetation_noise == null:
		return clampf(moisture, 0.0, 1.0)
	var noise_value := _to_normalized(_vegetation_noise.get_noise_2d(float(x), float(y)))
	var climate := clampf(moisture * 0.65 + temperature * 0.35, 0.0, 1.0)
	var elevation_limit := clampf(1.0 - maxf(0.0, elevation - hill_level) * 1.8, 0.0, 1.0)
	return clampf(noise_value * 0.55 + climate * 0.45, 0.0, 1.0) * elevation_limit


func _assign_base_biome(
	coord: Vector2i,
	height: float,
	_temperature: float,
	moisture: float,
	height_map: Dictionary
) -> String:
	if height < water_level:
		return BIOME_WATER
	# Desert fields are evaluated for every land tile so the blur re-masking
	# pass (browser main.js:22366-22525) sees a complete suitability field.
	var desert_candidate := _evaluate_desert_cell(coord.x, coord.y, height)
	# North-only snow owns the tundra line (browser main.js:21607-21635).
	if _compute_snow_presence(coord.x, coord.y, height):
		return BIOME_TUNDRA
	var marsh := _marsh_suitability(coord.x, coord.y, height, moisture, height_map)
	if marsh.z > 0.5:
		return BIOME_MARSH
	if desert_candidate:
		return BIOME_DESERT
	return BIOME_GRASSLAND


## Browser desert suitability (main.js:21991-22117): aridity*0.68 + heat*0.42
## where heat rides a noise-warped equatorial band; acceptance threshold is
## lerp(0.58, 0.52, equatorialAlignment). Also records the suitability and
## heat fields the refinement/badlands passes read later.
func _evaluate_desert_cell(x: int, y: int, height: float) -> bool:
	var idx := _xy_to_index(x, y)
	var rainfall := _rainfall_at(idx)
	var ny := (float(y) + 0.5) / maxf(1.0, float(map_size.y))
	var equatorial := clampf(1.0 - absf(ny - 0.5) * 2.0, 0.0, 1.0)
	if _desert_band_noise != null:
		equatorial = clampf(equatorial + _desert_band_noise.get_noise_2d(float(x), float(y)) * 0.22, 0.0, 1.0)
	# Deserts belong to the warm belt: reject anything too far toward the
	# cold poles, so no dunes ever form up north near the snow.
	if equatorial < 0.34:
		if idx >= 0 and idx < _desert_suitability_buffer.size():
			_desert_suitability_buffer[idx] = 0.0
		return false
	# Deviation: the rainfall belt (latitudeInfluence, main.js:21503) keeps
	# the map's equator wet enough that the browser constants alone never
	# dry it here, pushing every desert poleward. Discounting that belt
	# inside the aridity term restores the browser's equatorial banding.
	var aridity := clampf(1.0 - rainfall * 1.2 + equatorial * 0.3, 0.0, 1.0)
	var elevation_factor := clampf((height - water_level) * 2.6, 0.0, 1.0)
	var heat_noise := 0.0
	if _desert_heat_noise != null:
		heat_noise = _desert_heat_noise.get_noise_2d(float(x), float(y)) * 0.25
	var heat := clampf(equatorial * 0.55 + (1.0 - elevation_factor) * 0.3 + heat_noise, 0.0, 1.0)
	var suitability := clampf(aridity * 0.68 + heat * 0.42, 0.0, 1.0)
	if idx >= 0 and idx < _desert_suitability_buffer.size():
		_desert_suitability_buffer[idx] = suitability
		_desert_heat_buffer[idx] = heat
	# Raised acceptance floors keep deserts to genuine arid pockets rather
	# than sheeting across every warm lowland; raised again (0.62->0.66,
	# 0.70->0.74) to roughly halve desert coverage per player feedback.
	if suitability <= 0.66:
		return false
	if suitability <= lerpf(0.74, 0.66, equatorial):
		return false
	var desert_noise := 0.5
	if _desert_detail_noise != null:
		desert_noise = _to_normalized(_desert_detail_noise.get_noise_2d(float(x), float(y)))
	return desert_noise < suitability


## Browser calculateMarshSuitability (main.js:21758-21939): wetness =
## rainfall*0.75 + (1-drainage)*0.25 (drainage proxied by 1-moisture, same
## proxy the river service uses), lowland and heat gates, then either water
## adjacency or the inland-basin rule. The browser's 75-tile snow exclusion
## (main.js:24565-24591) becomes an equator latitude cutoff because snow is
## north-only. Returns Vector3(score, threshold, qualifies ? 1 : 0); score
## is -1 on hard failure.
func _marsh_suitability(x: int, y: int, height: float, moisture: float, height_map: Dictionary) -> Vector3:
	if height <= water_level:
		return Vector3(-1.0, MARSH_BASE_THRESHOLD, 0.0)
	var ny := (float(y) + 0.5) / maxf(1.0, float(map_size.y))
	if ny < 0.5:
		# Snow can only exist north of the equator; marsh stays south of it.
		return Vector3(-1.0, MARSH_BASE_THRESHOLD, 0.0)
	var rainfall := _rainfall_at(_xy_to_index(x, y))
	var equatorial := clampf(1.0 - absf(ny - 0.5) * 2.0, 0.0, 1.0)
	var elevation_above := maxf(0.0, height - water_level)
	var elevation_penalty := clampf(elevation_above * 3.4, 0.0, 1.0)
	var heat := clampf(equatorial * 0.6 + (1.0 - elevation_penalty) * 0.4, 0.0, 1.0)
	var wetness := clampf(rainfall * 0.75 + moisture * 0.25, 0.0, 1.0)
	var lowland_factor := clampf(1.0 - elevation_above * 4.2, 0.0, 1.0)
	if wetness <= MARSH_WETNESS_THRESHOLD or lowland_factor <= 0.22 or heat <= 0.45:
		return Vector3(-1.0, MARSH_BASE_THRESHOLD, 0.0)
	var suitability := clampf(wetness * 0.68 + lowland_factor * 0.2 + heat * 0.12, 0.0, 1.0)
	if _marsh_variation_noise != null:
		suitability = clampf(suitability + _marsh_variation_noise.get_noise_2d(float(x), float(y)) * 0.06, 0.0, 1.0)
	var threshold := MARSH_BASE_THRESHOLD
	var touches_surface_water := false
	var near_sea_level_neighbors := 0
	var lower_neighbors := 0
	var coord := Vector2i(x, y)
	for offset: Vector2i in NEIGHBOR_OFFSETS_8:
		var neighbor_height := float(height_map.get(coord + offset, height))
		if neighbor_height <= water_level:
			touches_surface_water = true
		if neighbor_height <= water_level + 0.02:
			near_sea_level_neighbors += 1
		if neighbor_height < height:
			lower_neighbors += 1
	var drainage := clampf(1.0 - moisture, 0.0, 1.0)
	var inland_candidate := (
		not touches_surface_water
		and near_sea_level_neighbors >= 4
		and wetness > MARSH_WETNESS_THRESHOLD + 0.05
		and drainage < 0.42
		and lowland_factor > 0.34
		and lower_neighbors >= 2
	)
	if inland_candidate:
		threshold = clampf(threshold + 0.03, 0.5, 0.75)
	if not touches_surface_water and not inland_candidate:
		return Vector3(-1.0, threshold, 0.0)
	return Vector3(suitability, threshold, 1.0 if suitability > threshold else 0.0)


## Browser tree biome pick (main.js:25603-25679): jungle needs an equatorial
## alignment of 1 - |ny-0.5|*3.4 >= 0.45, humidity >= 0.74, heat >= 0.68 and
## no snow within 100 tiles - with north-only snow that buffer becomes an
## equator latitude cutoff (jungle only south of ny = 0.5).
func _tree_overlay_biome(coord: Vector2i, base_biome: String, moisture: float, height: float) -> String:
	if base_biome == BIOME_TUNDRA:
		return BIOME_TUNDRA
	var ny := (float(coord.y) + 0.5) / maxf(1.0, float(map_size.y))
	if ny >= 0.5:
		var equatorial := clampf(1.0 - absf(ny - 0.5) * 3.4, 0.0, 1.0)
		if equatorial >= 0.45:
			var rainfall := _rainfall_at(_xy_to_index(coord.x, coord.y))
			var humidity := clampf(rainfall * 0.82 + moisture * 0.18, 0.0, 1.0)
			var elevation_penalty := clampf(maxf(0.0, height - water_level) * 3.1, 0.0, 1.0)
			var heat := clampf(equatorial * 0.85 + (1.0 - elevation_penalty) * 0.25, 0.0, 1.0)
			if heat >= 0.68 and humidity >= 0.74:
				return BIOME_JUNGLE
	return BIOME_FOREST


## Chebyshev dilation of a 0/1 mask by `radius`, done as two separable
## passes so the coastal buffer stays O(cells * radius).
func _dilate_mask(mask: PackedByteArray, radius: int) -> PackedByteArray:
	var width := map_size.x
	var rows := map_size.y
	var horizontal := PackedByteArray()
	horizontal.resize(mask.size())
	for y in range(rows):
		var row := y * width
		for x in range(width):
			var found := 0
			for dx in range(-radius, radius + 1):
				var nx := x + dx
				if nx < 0 or nx >= width:
					continue
				if mask[row + nx] == 1:
					found = 1
					break
			horizontal[row + x] = found
	var result := PackedByteArray()
	result.resize(mask.size())
	for y in range(rows):
		for x in range(width):
			var found := 0
			for dy in range(-radius, radius + 1):
				var ny := y + dy
				if ny < 0 or ny >= rows:
					continue
				if horizontal[ny * width + x] == 1:
					found = 1
					break
			result[y * width + x] = found
	return result


## Browser traceDirection (main.js:23457-23496): walk from a seed along the
## local ridge direction, claiming cells while the ridge score holds up.
func _trace_ridge_direction(
	start_x: int,
	start_y: int,
	start_dir: int,
	max_steps: int,
	initial_reliability: float,
	candidate_floor: float,
	water_mask: PackedByteArray,
	scores: PackedFloat32Array,
	dir_index: PackedInt32Array,
	dir_strength: PackedFloat32Array,
	mountain_mask: PackedByteArray
) -> void:
	var width := map_size.x
	var rows := map_size.y
	var cx := start_x
	var cy := start_y
	var current_dir := start_dir
	var reliability := initial_reliability
	for _step in range(max_steps):
		var offset: Vector2i = NEIGHBOR_OFFSETS_8[current_dir]
		var nx := cx + offset.x
		var ny := cy + offset.y
		if nx < 0 or ny < 0 or nx >= width or ny >= rows:
			break
		var n_idx := ny * width + nx
		if water_mask[n_idx] == 1:
			break
		if float(scores[n_idx]) < candidate_floor:
			break
		mountain_mask[n_idx] = 1
		cx = nx
		cy = ny
		var next_dir := int(dir_index[n_idx])
		if next_dir >= 0:
			current_dir = next_dir
		reliability = maxf(float(dir_strength[n_idx]), reliability * 0.82)
		if reliability < 0.06:
			break


## Browser ridge-traced mountain ranges (main.js:23151-23592) and composite
## hills (main.js:25238-25401), ported onto the existing highland_map
## interface. The ridge score field combines ridged noise, slope magnitude
## and local contrast (Godot has no tectonic-activity field, so the ridged
## noise doubles as the tectonic proxy); seeds above the slider-shifted
## threshold trace chains along the local ridge direction (up to 18 steps),
## two stochastic growth passes thicken the ranges, coastal cells (within 2
## tiles of water) are suppressed and isolated singles pruned. Ridge cores
## nudge the height field upward so the absolute height>=0.97 peak-overlay
## rule still fires. Rivers still erase mountains downstream
## (OverworldRiverService.apply_river_tiles, browser main.js:24823-24840).
func _build_highland_overlays(
	base_biome_map: Dictionary,
	height_buffer: PackedFloat32Array,
	height_map: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var overlay_map: Dictionary = {}
	var width := map_size.x
	var rows := map_size.y
	var cell_count := width * rows
	if cell_count <= 0 or height_buffer.size() != cell_count:
		return overlay_map

	var water_mask := PackedByteArray()
	water_mask.resize(cell_count)
	# 0 = other land, 1 = grass, 2 = tundra, 3 = badlands (hill-capable bases).
	var base_kind := PackedByteArray()
	base_kind.resize(cell_count)
	for y in range(rows):
		var row := y * width
		for x in range(width):
			var biome := String(base_biome_map.get(Vector2i(x, y), BIOME_GRASSLAND))
			var idx := row + x
			if biome == BIOME_WATER:
				water_mask[idx] = 1
			elif biome == BIOME_GRASSLAND:
				base_kind[idx] = 1
			elif biome == BIOME_TUNDRA:
				base_kind[idx] = 2
			elif biome == BIOME_BADLANDS:
				base_kind[idx] = 3
	var coastal_mask := _dilate_mask(water_mask, 2)

	# Slider bias (main.js:21325-21331): the Mountain ratio becomes a signed
	# bias with a 0.8 power curve, a scarcity factor and a growth factor.
	var bias_linear := _mountain_ratio * 2.0 - 1.0
	var mountain_bias := 0.0
	if not is_zero_approx(bias_linear):
		mountain_bias = signf(bias_linear) * pow(absf(bias_linear), 0.8)
	var mountain_scarcity := 1.0 - _mountain_ratio
	# Lower growth factor: the two spread passes were thickening seeded
	# ridges into half the continent. This keeps ranges to their chains.
	var mountain_growth_factor := 0.18 + _mountain_ratio * 0.5

	# Height window (main.js:22268-22284). Deviation: the browser's eroded
	# heightfield keeps high ground rare, while Godot's carries broad high
	# plateaus - anchoring the window's floor to the land-height
	# distribution (80th percentile) keeps ranges as chains instead of
	# flooding every plateau.
	var land_heights := PackedFloat32Array()
	for idx in range(cell_count):
		if water_mask[idx] == 0:
			land_heights.append(float(height_buffer[idx]))
	var plateau_floor := 0.0
	if not land_heights.is_empty():
		land_heights.sort()
		# 88th percentile (was 80th): only the genuinely high ground seeds
		# ranges, so mountains stay chains instead of blanketing the land.
		plateau_floor = float(land_heights[int(float(land_heights.size() - 1) * 0.88)])
	var base_threshold := minf(maxf(maxf(water_level + 0.1, 0.58), plateau_floor), 0.9)
	var full_threshold := minf(0.98, base_threshold + 0.35)
	var threshold_shift := mountain_bias * 0.18
	var min_base_threshold := minf(maxf(water_level + 0.08 + mountain_scarcity * 0.05, 0.5), 0.92)
	base_threshold = clampf(base_threshold - threshold_shift, min_base_threshold, 0.92)
	full_threshold = clampf(full_threshold - threshold_shift * 1.3, base_threshold + 0.12, 0.99)
	var height_range := maxf(full_threshold - base_threshold, 0.0001)

	# Seed/candidate/prune thresholds (main.js:23160-23177). Raised the
	# neutral seed and candidate floors so a 50% Mountain slider yields
	# real ranges, not half the continent - the slider still biases from
	# these baselines.
	var seed_threshold := clampf(0.93 - mountain_bias * 0.32, 0.52, 0.985)
	var candidate_threshold := clampf(0.74 - mountain_bias * 0.28, 0.2, 0.9)
	var prune_threshold := clampf(0.9 - mountain_bias * 0.2, 0.62, 0.97)

	var ridge_detail_noise := FastNoiseLite.new()
	ridge_detail_noise.seed = map_seed + 0x165667b1
	ridge_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ridge_detail_noise.frequency = 7.4 / maxf(1.0, float(width))
	ridge_detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	ridge_detail_noise.fractal_octaves = 5
	ridge_detail_noise.fractal_gain = 0.47
	ridge_detail_noise.fractal_lacunarity = 2.28

	var orientation_noise := FastNoiseLite.new()
	orientation_noise.seed = map_seed + 0xd3a2646c
	orientation_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	orientation_noise.frequency = 9.2 / maxf(1.0, float(width))
	orientation_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	orientation_noise.fractal_octaves = 3
	orientation_noise.fractal_gain = 0.58
	orientation_noise.fractal_lacunarity = 2.05

	var norm_height := PackedFloat32Array()
	norm_height.resize(cell_count)
	var ridged_field := PackedFloat32Array()
	ridged_field.resize(cell_count)
	var tectonic_field := PackedFloat32Array()
	tectonic_field.resize(cell_count)
	var ridge_field := PackedFloat32Array()
	ridge_field.resize(cell_count)
	var dir_index := PackedInt32Array()
	dir_index.resize(cell_count)
	dir_index.fill(-1)
	var dir_strength := PackedFloat32Array()
	dir_strength.resize(cell_count)
	var scores := PackedFloat32Array()
	scores.resize(cell_count)
	var mountain_mask := PackedByteArray()
	mountain_mask.resize(cell_count)

	# Pass A: ridged noise and normalized height. The browser's tectonic
	# activity field is near zero away from plate boundaries, so the proxy
	# keeps only the crest of the ridged noise (raw > 0.55 remapped and
	# squared) - feeding 1-|noise| in directly floods the map in mountains.
	for y in range(rows):
		var row := y * width
		for x in range(width):
			var idx := row + x
			if water_mask[idx] == 1:
				continue
			var ridged_raw := 1.0 - absf(ridge_detail_noise.get_noise_2d(float(x), float(y)))
			ridged_field[idx] = pow(ridged_raw, 1.25)
			tectonic_field[idx] = pow(clampf((ridged_raw - 0.55) / 0.45, 0.0, 1.0), 2.0)
			norm_height[idx] = clampf((float(height_buffer[idx]) - base_threshold) / height_range, 0.0, 1.0)

	# Pass B: ridge score + local ridge direction (main.js:23179-23303).
	for y in range(rows):
		var row := y * width
		for x in range(width):
			var idx := row + x
			if water_mask[idx] == 1:
				continue
			var height_value := float(height_buffer[idx])
			var left := float(height_buffer[idx - 1]) if x > 0 else height_value
			var right := float(height_buffer[idx + 1]) if x < width - 1 else height_value
			var up := float(height_buffer[idx - width]) if y > 0 else height_value
			var down := float(height_buffer[idx + width]) if y < rows - 1 else height_value
			var grad_x := (right - left) * 0.5
			var grad_y := (down - up) * 0.5
			var slope_magnitude := sqrt(grad_x * grad_x + grad_y * grad_y)

			var tect := float(tectonic_field[idx])
			var tect_left := float(tectonic_field[idx - 1]) if x > 0 else tect
			var tect_right := float(tectonic_field[idx + 1]) if x < width - 1 else tect
			var tect_up := float(tectonic_field[idx - width]) if y > 0 else tect
			var tect_down := float(tectonic_field[idx + width]) if y < rows - 1 else tect
			var tect_grad_x := (tect_right - tect_left) * 0.5
			var tect_grad_y := (tect_down - tect_up) * 0.5
			var tect_mag := sqrt(tect_grad_x * tect_grad_x + tect_grad_y * tect_grad_y)

			var neighbor_sum := 0.0
			var neighbor_count := 0
			for offset: Vector2i in NEIGHBOR_OFFSETS_8:
				var nx := x + offset.x
				var ny := y + offset.y
				if nx < 0 or ny < 0 or nx >= width or ny >= rows:
					continue
				neighbor_sum += float(height_buffer[ny * width + nx])
				neighbor_count += 1
			var neighbor_avg := (neighbor_sum / float(neighbor_count)) if neighbor_count > 0 else height_value
			var local_contrast := maxf(0.0, height_value - neighbor_avg)

			var dir_x := 0.0
			var dir_y := 0.0
			if tect_mag > 0.0003:
				dir_x += -tect_grad_y * 1.6
				dir_y += tect_grad_x * 1.6
			if slope_magnitude > 0.00035:
				dir_x += -grad_y * 0.7
				dir_y += grad_x * 0.7
			var noise_angle := orientation_noise.get_noise_2d(float(x), float(y)) * PI
			if absf(dir_x) + absf(dir_y) < 0.0001:
				dir_x = cos(noise_angle)
				dir_y = sin(noise_angle)
			else:
				var dir_mag := maxf(sqrt(dir_x * dir_x + dir_y * dir_y), 0.0001)
				dir_x = (dir_x / dir_mag) * 0.8 + cos(noise_angle) * 0.2
				dir_y = (dir_y / dir_mag) * 0.8 + sin(noise_angle) * 0.2
			var final_mag := sqrt(dir_x * dir_x + dir_y * dir_y)
			if final_mag > 0.0001:
				dir_x /= final_mag
				dir_y /= final_mag
				dir_strength[idx] = clampf(sqrt(tect_mag) * 3.5 + slope_magnitude * 2.1, 0.0, 1.0)
				var best_index := -1
				var best_dot := 0.35
				for i in range(NEIGHBOR_OFFSETS_8.size()):
					var offset: Vector2i = NEIGHBOR_OFFSETS_8[i]
					var offset_length := sqrt(float(offset.x * offset.x + offset.y * offset.y))
					var dot := (dir_x * float(offset.x) + dir_y * float(offset.y)) / offset_length
					if dot > best_dot:
						best_dot = dot
						best_index = i
				dir_index[idx] = best_index

			var nh := float(norm_height[idx])
			var erosion_penalty := maxf(0.0, neighbor_avg - height_value) * 0.35
			var raw_ridge_score := (
				nh * 0.28
				+ pow(maxf(0.0, nh), 1.6) * 0.3
				+ local_contrast * 0.9
				+ clampf(slope_magnitude * 2.4, 0.0, 1.0) * 0.55
				+ pow(tect, 0.85) * 0.75
				+ float(ridged_field[idx]) * 0.4
				- erosion_penalty
			)
			ridge_field[idx] = maxf(0.0, raw_ridge_score)

	# Directional smoothing, 2 iterations (main.js:23306-23358).
	var ridge_buffer := PackedFloat32Array()
	ridge_buffer.resize(cell_count)
	for _iteration in range(2):
		for y in range(rows):
			var row := y * width
			for x in range(width):
				var idx := row + x
				if water_mask[idx] == 1:
					ridge_buffer[idx] = 0.0
					continue
				var cell_dir := int(dir_index[idx])
				if cell_dir < 0:
					ridge_buffer[idx] = float(ridge_field[idx])
					continue
				var strength := float(dir_strength[idx])
				var weight := 1.0
				var weighted_sum := float(ridge_field[idx])
				for dir_choice: int in [cell_dir, NEIGHBOR_OPPOSITES_8[cell_dir]]:
					var offset: Vector2i = NEIGHBOR_OFFSETS_8[dir_choice]
					var nx := x + offset.x
					var ny := y + offset.y
					if nx < 0 or ny < 0 or nx >= width or ny >= rows:
						continue
					var n_idx := ny * width + nx
					if water_mask[n_idx] == 1:
						continue
					var neighbor_weight := 0.8 + strength * 0.6
					weighted_sum += float(ridge_field[n_idx]) * neighbor_weight
					weight += neighbor_weight
				ridge_buffer[idx] = weighted_sum / weight
		var swap := ridge_field
		ridge_field = ridge_buffer
		ridge_buffer = swap
	_normalize_field(ridge_field)

	# Combined mountain scores (main.js:23360-23385).
	for idx in range(cell_count):
		if water_mask[idx] == 1:
			continue
		var tect := float(tectonic_field[idx])
		var nh := float(norm_height[idx])
		scores[idx] = clampf(
			float(ridge_field[idx]) * 0.6
			+ pow(maxf(0.0, nh), 1.6) * 0.25
			+ nh * 0.18
			+ pow(tect, 0.9) * 0.35
			+ float(dir_strength[idx]) * 0.18,
			0.0,
			1.0
		)

	# Seeds (main.js:23410-23455) with a fallback for barren worlds.
	var seed_count := 0
	for idx in range(cell_count):
		if water_mask[idx] == 1 or coastal_mask[idx] == 1:
			continue
		if float(scores[idx]) >= seed_threshold:
			mountain_mask[idx] = 1
			seed_count += 1
	if seed_count == 0:
		var fallback_candidates: Array[int] = []
		for idx in range(cell_count):
			if water_mask[idx] == 1 or coastal_mask[idx] == 1:
				continue
			if float(scores[idx]) >= seed_threshold * 0.85:
				fallback_candidates.append(idx)
		fallback_candidates.sort_custom(func(a: int, b: int) -> bool:
			return float(scores[a]) > float(scores[b])
		)
		var fallback_limit := mini(maxi(1, int(round(4.0 * _mountain_ratio))), fallback_candidates.size())
		for i in range(fallback_limit):
			mountain_mask[fallback_candidates[i]] = 1

	# Range tracing (main.js:23457-23521): forward up to 18 steps, backward
	# 45% of that, following the local ridge direction.
	var seed_indices: Array[int] = []
	for idx in range(cell_count):
		if mountain_mask[idx] == 1:
			seed_indices.append(idx)
	seed_indices.sort_custom(func(a: int, b: int) -> bool:
		return float(scores[a]) > float(scores[b])
	)
	# Stop tracing at the candidate threshold (was 0.85x below it) so
	# ranges don't crawl far out along weak ridges.
	var candidate_floor := candidate_threshold
	for seed_idx: int in seed_indices:
		var base_dir := int(dir_index[seed_idx])
		var reliability := float(dir_strength[seed_idx])
		if base_dir < 0 or reliability < 0.05:
			continue
		var range_scale := (float(scores[seed_idx]) * 4.0 + float(ridge_field[seed_idx]) * 3.0) * (0.5 + reliability * 0.4)
		# Shorter chains (cap 9, was 18): ranges read as ridgelines, not
		# continent-spanning masses.
		var base_length := 1 + int(floor(range_scale * 0.55))
		var forward_steps := mini(9, base_length + rng.randi_range(0, 2))
		var backward_steps := maxi(1, int(floor(float(forward_steps) * 0.45)))
		var sx := seed_idx % width
		var sy := int(seed_idx / float(width))
		_trace_ridge_direction(sx, sy, base_dir, forward_steps, reliability, candidate_floor, water_mask, scores, dir_index, dir_strength, mountain_mask)
		_trace_ridge_direction(sx, sy, NEIGHBOR_OPPOSITES_8[base_dir], backward_steps, reliability * 0.85, candidate_floor, water_mask, scores, dir_index, dir_strength, mountain_mask)

	# Stochastic growth, 1 pass (was 2): a second spread pass doubled the
	# ranges' footprint, blanketing the land. One pass keeps chains.
	var high_score_threshold := 0.86 + mountain_scarcity * 0.1
	for _growth_pass in range(1):
		for y in range(rows):
			var row := y * width
			for x in range(width):
				var idx := row + x
				if water_mask[idx] == 1 or mountain_mask[idx] == 1 or coastal_mask[idx] == 1:
					continue
				var score := float(scores[idx])
				if score <= 0.0:
					continue
				var mountain_neighbors := 0
				for offset: Vector2i in NEIGHBOR_OFFSETS_8:
					var nx := x + offset.x
					var ny := y + offset.y
					if nx < 0 or ny < 0 or nx >= width or ny >= rows:
						continue
					if mountain_mask[ny * width + nx] == 1:
						mountain_neighbors += 1
				var orientation_strength := float(dir_strength[idx])
				var min_neighbors := 3
				if score > 0.82 or orientation_strength > 0.7:
					min_neighbors = 1
				elif score > 0.66:
					min_neighbors = 1 if orientation_strength > 0.45 else 2
				elif orientation_strength > 0.55:
					min_neighbors = 2
				var directional_support := false
				var cell_dir := int(dir_index[idx])
				if cell_dir >= 0:
					for dir_choice: int in [cell_dir, NEIGHBOR_OPPOSITES_8[cell_dir]]:
						var offset: Vector2i = NEIGHBOR_OFFSETS_8[dir_choice]
						var nx := x + offset.x
						var ny := y + offset.y
						if nx < 0 or ny < 0 or nx >= width or ny >= rows:
							continue
						if mountain_mask[ny * width + nx] == 1:
							directional_support = true
							break
				var probability := minf(0.85, (0.12 + score * 0.6 + orientation_strength * 0.25) * mountain_growth_factor)
				if not directional_support:
					probability *= 0.45
					if orientation_strength > 0.6:
						probability *= 0.6
				if mountain_neighbors >= min_neighbors and (score > high_score_threshold or rng.randf() < probability):
					mountain_mask[idx] = 1

	# Consolidation (main.js:23594-23627): well-supported candidates join.
	for y in range(rows):
		var row := y * width
		for x in range(width):
			var idx := row + x
			if water_mask[idx] == 1 or mountain_mask[idx] == 1 or coastal_mask[idx] == 1:
				continue
			if float(scores[idx]) < candidate_threshold:
				continue
			var mountain_neighbors := 0
			for offset: Vector2i in NEIGHBOR_OFFSETS_8:
				var nx := x + offset.x
				var ny := y + offset.y
				if nx < 0 or ny < 0 or nx >= width or ny >= rows:
					continue
				if mountain_mask[ny * width + nx] == 1:
					mountain_neighbors += 1
			var orientation_strength := float(dir_strength[idx])
			var base_required := 2 if orientation_strength > 0.6 else (3 if orientation_strength > 0.35 else 4)
			var scarcity_penalty := 2 if mountain_scarcity > 0.6 else (1 if mountain_scarcity > 0.35 else 0)
			if mountain_neighbors >= mini(7, base_required + scarcity_penalty):
				mountain_mask[idx] = 1

	# Coastal scrub: traces/growth may have brushed the shoreline buffer.
	for idx in range(cell_count):
		if mountain_mask[idx] == 1 and coastal_mask[idx] == 1:
			mountain_mask[idx] = 0

	# Prune isolated singles (main.js:23629-23657).
	var prune_boost := lerpf(1.18, 0.85, _mountain_ratio)
	for y in range(rows):
		var row := y * width
		for x in range(width):
			var idx := row + x
			if mountain_mask[idx] == 0:
				continue
			var mountain_neighbors := 0
			for offset: Vector2i in NEIGHBOR_OFFSETS_8:
				var nx := x + offset.x
				var ny := y + offset.y
				if nx < 0 or ny < 0 or nx >= width or ny >= rows:
					continue
				if mountain_mask[ny * width + nx] == 1:
					mountain_neighbors += 1
			var orientation_strength := float(dir_strength[idx])
			var min_support := 0 if orientation_strength > 0.65 else 1
			var effective_threshold := prune_threshold * prune_boost * (1.0 - orientation_strength * 0.25)
			if mountain_neighbors <= min_support and float(scores[idx]) < effective_threshold:
				mountain_mask[idx] = 0

	# Composite hills (main.js:25238-25401): slope + height window +
	# mountain adjacency, on grass/snow/badlands bases only.
	var hill_upper := base_threshold
	var hill_lower := clampf(base_threshold - maxf(0.16, height_range * 0.9), water_level + 0.08, hill_upper - 0.04)
	if hill_upper - hill_lower > 0.015:
		var hill_range := maxf(hill_upper - hill_lower, 0.0001)
		var hill_presence_seed := map_seed + 0x0d4d0015
		for y in range(rows):
			var row := y * width
			for x in range(width):
				var idx := row + x
				if water_mask[idx] == 1 or mountain_mask[idx] == 1 or base_kind[idx] == 0:
					continue
				var height_value := float(height_buffer[idx])
				if height_value < hill_lower or height_value >= hill_upper:
					continue
				var slope_sum := 0.0
				var neighbor_count := 0
				var has_mountain_neighbor := false
				for offset: Vector2i in NEIGHBOR_OFFSETS_8:
					var nx := x + offset.x
					var ny := y + offset.y
					if nx < 0 or ny < 0 or nx >= width or ny >= rows:
						continue
					var n_idx := ny * width + nx
					slope_sum += absf(height_value - float(height_buffer[n_idx]))
					neighbor_count += 1
					if mountain_mask[n_idx] == 1:
						has_mountain_neighbor = true
				var average_slope := (slope_sum / float(neighbor_count)) if neighbor_count > 0 else 0.0
				var slope_score := clampf((average_slope - 0.01) * 32.0, 0.0, 1.0)
				if slope_score < 0.08 and not has_mountain_neighbor:
					continue
				var height_score := clampf((height_value - hill_lower) / hill_range, 0.0, 1.0)
				var mountain_bonus := 0.25 if has_mountain_neighbor else clampf(float(scores[idx]) * 0.2, 0.0, 0.2)
				var noise_value := _hash_coords(x, y, hill_presence_seed) - 0.5
				var composite := height_score * 0.6 + slope_score * 0.3 + mountain_bonus + noise_value * 0.12
				if composite > 0.5 - mountain_bonus * 0.18:
					overlay_map[Vector2i(x, y)] = BIOME_HILLS

	# Mountains land last so they always win over hills, and their ridge
	# cores push the height field up (peaks need height >= 0.97 in
	# OverworldTerrainFeatureService.apply_mountain_overlay_variants).
	for idx in range(cell_count):
		if mountain_mask[idx] == 0:
			continue
		var coord := Vector2i(idx % width, int(idx / float(width)))
		overlay_map[coord] = BIOME_MOUNTAIN
		var nudged := maxf(float(height_buffer[idx]), mountain_level + 0.01 + float(scores[idx]) * 0.15)
		height_buffer[idx] = nudged
		height_map[coord] = nudged
	# Dwarfhold and mine placement (browser mountainScores /
	# mountainCandidateThreshold, main.js:23871-24260) reuses the combined
	# mountain score field computed above.
	_mountain_score_buffer = scores
	_mountain_candidate_threshold = candidate_threshold
	return overlay_map


func _apply_tree_overlays(
	biome_map: Dictionary,
	moisture_map: Dictionary,
	vegetation_map: Dictionary,
	height_map: Dictionary,
	highland_map: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var tree_map: Dictionary = {}
	var tree_source_map: Dictionary = {}
	var tree_work_map: Dictionary = {}
	var original_biomes: Dictionary = {}
	var tree_density_map: Dictionary = {}
	# Browser forest slider (main.js:21300-21306, 25691-25770): forestBias
	# lowers the seed threshold (x0.13), raises the growth baseline and the
	# per-neighbor bonus, scales the growth iteration count, multiplies the
	# density by 1 + bias*0.2 and adds bias*0.08 on top.
	var density_threshold := clampf(maxf(0.2, forest_threshold * 0.55) - _forest_bias * 0.13, 0.12, 0.92)
	var neighbor_bonus := clampf(0.07 + _forest_bias * 0.03, 0.02, 0.12)
	var growth_baseline := clampf(0.08 + _forest_bias * 0.06, 0.0, 0.3)
	var growth_passes := maxi(1, 2 + int(roundf(_forest_bias)))
	var max_coverage := clampf(forest_max_coverage + _forest_bias * 0.15, 0.2, 0.95)
	for coord: Vector2i in biome_map.keys():
		if String(highland_map.get(coord, "")) == BIOME_MOUNTAIN:
			continue
		if not TREE_BASE_BIOMES.has(biome_map[coord]):
			continue
		var moisture: float = moisture_map.get(coord, 0.0)
		var vegetation: float = vegetation_map.get(coord, 0.0)
		var elevation: float = height_map.get(coord, 0.0)
		var elevation_relative := clampf(inverse_lerp(water_level, 1.0, elevation), 0.0, 1.0)
		var elevation_center := 0.34
		var elevation_range := 0.28
		var elevation_preference := clampf(1.0 - absf(elevation_relative - elevation_center) / elevation_range, 0.0, 1.0)
		var nx := float(coord.x) / maxf(1.0, float(map_size.x - 1))
		var ny := float(coord.y) / maxf(1.0, float(map_size.y - 1))
		var large_scale_noise := _to_normalized(_vegetation_noise.get_noise_2d(coord.x, coord.y))
		var detail_noise := _value_noise(nx * 28.0 + 1.7, ny * 28.0 + 7.3, map_seed + 0x3c6ef372)
		var density := (large_scale_noise * 0.6 + detail_noise * 0.4) * 0.5
		density *= (0.75 + elevation_preference * 0.65)
		density *= (0.55 + moisture * 0.9)
		density += moisture * 0.2 + vegetation * 0.1
		density = density * (1.0 + _forest_bias * 0.2) + _forest_bias * 0.08
		tree_density_map[coord] = clampf(density, 0.0, 1.0)

	for coord: Vector2i in tree_density_map.keys():
		var density: float = tree_density_map.get(coord, 0.0)
		if density >= density_threshold:
			pass
		elif density <= density_threshold - 0.18:
			continue
		else:
			var soft_chance := clampf((density - (density_threshold - 0.18)) / 0.18, 0.0, 1.0)
			if rng.randf() > soft_chance:
				continue
		var seed_moisture: float = moisture_map.get(coord, 0.0)
		var seed_biome := _tree_overlay_biome(coord, String(biome_map.get(coord, BIOME_GRASSLAND)), seed_moisture, float(height_map.get(coord, 0.0)))
		if not original_biomes.has(coord):
			original_biomes[coord] = biome_map.get(coord, BIOME_GRASSLAND)
		biome_map[coord] = seed_biome
		tree_map[coord] = seed_biome
		tree_source_map[coord] = seed_biome

	for _spread_pass in range(growth_passes):
		var grown_this_pass := false
		tree_work_map.clear()
		for coord: Vector2i in tree_source_map.keys():
			tree_work_map[coord] = tree_source_map[coord]
		for coord: Vector2i in tree_density_map.keys():
			if tree_source_map.has(coord):
				continue
			var density: float = tree_density_map.get(coord, 0.0)
			if density <= 0.12:
				continue
			var neighbor_trees := _count_tree_neighbors_in_map(coord, tree_source_map)
			if neighbor_trees <= 0:
				continue
			var cluster_boost := minf(0.36, float(neighbor_trees) * neighbor_bonus)
			var spread_chance := clampf(growth_baseline + density * 0.58 + cluster_boost, 0.0, 0.96)
			if rng.randf() > spread_chance:
				continue
			var moisture: float = moisture_map.get(coord, 0.0)
			var tree_biome := _tree_overlay_biome(coord, String(biome_map.get(coord, BIOME_GRASSLAND)), moisture, float(height_map.get(coord, 0.0)))
			if not original_biomes.has(coord):
				original_biomes[coord] = biome_map.get(coord, BIOME_GRASSLAND)
			biome_map[coord] = tree_biome
			tree_work_map[coord] = tree_biome
			grown_this_pass = true
		if not grown_this_pass:
			break
		var swap := tree_source_map
		tree_source_map = tree_work_map
		tree_work_map = swap
	tree_map = tree_source_map

	var cleaned_tree_map := tree_map.duplicate()
	for coord: Vector2i in tree_map.keys():
		if _is_adjacent_to_biomes(coord, biome_map, [BIOME_DESERT, BIOME_BADLANDS]):
			if rng.randf() < 0.42:
				cleaned_tree_map.erase(coord)
				biome_map[coord] = original_biomes.get(coord, BIOME_GRASSLAND)
	for coord: Vector2i in cleaned_tree_map.keys():
		var tree_neighbors := _count_tree_neighbors_in_map(coord, cleaned_tree_map)
		if tree_neighbors > 0:
			continue
		var base_biome: String = biome_map.get(coord, BIOME_GRASSLAND)
		if base_biome == BIOME_TUNDRA:
			cleaned_tree_map[coord] = TREE_VARIANT_TUNDRA_LONE
		elif base_biome == BIOME_GRASSLAND:
			cleaned_tree_map[coord] = TREE_VARIANT_FOREST_LONE

	var max_tree_tiles := int(ceil(float(tree_density_map.size()) * max_coverage))
	if cleaned_tree_map.size() > max_tree_tiles:
		var trim_entries: Array[Dictionary] = []
		for coord: Vector2i in cleaned_tree_map.keys():
			var local_density := float(tree_density_map.get(coord, 0.0))
			var local_neighbors := float(_count_tree_neighbors_in_map(coord, cleaned_tree_map))
			trim_entries.append({
				"coord": coord,
				"score": local_density + local_neighbors * 0.035
			})
		trim_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("score", 0.0)) < float(b.get("score", 0.0))
		)
		var remove_total := cleaned_tree_map.size() - max_tree_tiles
		for i in range(mini(remove_total, trim_entries.size())):
			var coord_to_remove: Vector2i = trim_entries[i].get("coord", Vector2i.ZERO)
			cleaned_tree_map.erase(coord_to_remove)
			biome_map[coord_to_remove] = original_biomes.get(coord_to_remove, BIOME_GRASSLAND)
	return cleaned_tree_map


func _apply_tree_tiles(tree_map: Dictionary, base_biome_map: Dictionary) -> void:
	if map_layer == null or tree_layer == null:
		return
	var processed_cells := 0
	for coord: Vector2i in tree_map.keys():
		if map_layer.get_cell_source_id(coord) == -1:
			var fallback_biome := base_biome_map.get(coord, BIOME_GRASSLAND) as String
			if fallback_biome == BIOME_GRASSLAND:
				map_layer.set_cell(coord, _atlas_source_id, GRASS_TILE)
			elif fallback_biome == BIOME_TUNDRA:
				map_layer.set_cell(coord, _atlas_source_id, SNOW_TILE)
			else:
				continue
		var base_tile := map_layer.get_cell_atlas_coords(coord)
		if base_tile != GRASS_TILE and base_tile != SNOW_TILE:
			continue
		var base_biome := base_biome_map.get(coord, BIOME_GRASSLAND) as String
		if base_biome != BIOME_GRASSLAND and base_biome != BIOME_TUNDRA:
			continue
		var tree_biome := tree_map.get(coord, BIOME_FOREST) as String
		var tile_coords := TREE_TILE
		if tree_biome == BIOME_JUNGLE:
			tile_coords = JUNGLE_TREE_TILE
		elif tree_biome == TREE_VARIANT_FOREST_LONE or tree_biome == TREE_VARIANT_TUNDRA_LONE:
			tile_coords = TREE_LONE_TILE
		elif base_biome == BIOME_TUNDRA:
			tile_coords = TREE_SNOW_TILE
		tree_layer.set_cell(coord, _atlas_source_id, tile_coords)
		processed_cells += 1
		if processed_cells % GENERATION_YIELD_CELL_INTERVAL == 0:
			await _yield_generation_wave()


func _has_tree_neighbor(coord: Vector2i, biome_map: Dictionary) -> bool:
	for offset: Vector2i in [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i(-1, -1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(1, 1)
	]:
		var neighbor := coord + offset
		if TREE_BIOMES.has(biome_map.get(neighbor, "")):
			return true
	return false


func _count_tree_neighbors_in_map(coord: Vector2i, source_map: Dictionary) -> int:
	var tree_neighbors := 0
	for offset: Vector2i in [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i(-1, -1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(1, 1)
	]:
		var neighbor := coord + offset
		var biome_value := String(source_map.get(neighbor, ""))
		if TREE_BIOMES.has(biome_value):
			tree_neighbors += 1
		elif biome_value == TREE_VARIANT_FOREST_LONE or biome_value == TREE_VARIANT_TUNDRA_LONE:
			tree_neighbors += 1
	return tree_neighbors


func _is_adjacent_to_biomes(coord: Vector2i, source_map: Dictionary, target_biomes: Array[String]) -> bool:
	for offset: Vector2i in [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i(-1, -1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(1, 1)
	]:
		var neighbor := coord + offset
		if target_biomes.has(String(source_map.get(neighbor, ""))):
			return true
	return false


func _build_tree_coverage_biome_map(base_biome_map: Dictionary, tree_map: Dictionary) -> Dictionary:
	var coverage_map := base_biome_map.duplicate()
	for coord: Vector2i in tree_map.keys():
		var tree_biome := String(tree_map.get(coord, BIOME_FOREST))
		if tree_biome == BIOME_JUNGLE:
			coverage_map[coord] = BIOME_JUNGLE
		else:
			coverage_map[coord] = BIOME_FOREST
	return coverage_map


func _smooth_biomes(biome_map: Dictionary, passes: int) -> void:
	var read_map := biome_map
	var write_map: Dictionary = {}
	for _pass_index in range(passes):
		write_map.clear()
		for coord: Vector2i in read_map.keys():
			var current: String = read_map.get(coord, BIOME_GRASSLAND)
			if current == BIOME_WATER || current == BIOME_MOUNTAIN:
				write_map[coord] = current
				continue
			var neighbor_counts: Dictionary = {}
			for offset: Vector2i in [
				Vector2i.LEFT,
				Vector2i.RIGHT,
				Vector2i.UP,
				Vector2i.DOWN,
				Vector2i(-1, -1),
				Vector2i(1, -1),
				Vector2i(-1, 1),
				Vector2i(1, 1)
			]:
				var neighbor := coord + offset
				var neighbor_biome: String = read_map.get(neighbor, current)
				if neighbor_biome == BIOME_WATER || neighbor_biome == BIOME_MOUNTAIN:
					continue
				neighbor_counts[neighbor_biome] = int(neighbor_counts.get(neighbor_biome, 0)) + 1
			var most_common: String = current
			var most_common_count := -1
			for biome: String in neighbor_counts.keys():
				var count: int = neighbor_counts[biome]
				if count > most_common_count:
					most_common = biome
					most_common_count = count
			if most_common != current and most_common_count >= 4:
				write_map[coord] = most_common
			else:
				write_map[coord] = current
		var swap := read_map
		read_map = write_map
		write_map = swap
	if read_map != biome_map:
		biome_map.clear()
		for coord: Vector2i in read_map.keys():
			biome_map[coord] = read_map[coord]


func _current_generation_memory_bytes() -> int:
	return int(Performance.get_monitor(Performance.MEMORY_STATIC))


func _sample_generation_memory_peak(current_peak: int, stage_label: String) -> int:
	var sampled := _current_generation_memory_bytes()
	if sampled > current_peak:
		print("Overworld generation memory peak at %s: %d bytes" % [stage_label, sampled])
		return sampled
	return current_peak


func _count_biome(biome_map: Dictionary, biome: String) -> int:
	var count := 0
	for coord: Vector2i in biome_map.keys():
		if biome_map.get(coord, "") == biome:
			count += 1
	return count


func _seed_desert_biomes(
	biome_map: Dictionary,
	temperature_map: Dictionary,
	moisture_map: Dictionary,
	height_map: Dictionary
) -> void:
	var candidates: Array[Vector2i] = []
	for coord: Vector2i in biome_map.keys():
		if biome_map.get(coord, "") == BIOME_WATER:
			continue
		if height_map.get(coord, 0.0) < water_level:
			continue
		if temperature_map.get(coord, 0.0) < warm_threshold:
			continue
		candidates.append(coord)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return moisture_map.get(a, 1.0) < moisture_map.get(b, 1.0)
	)
	var target_count := maxi(1, int(round(float(candidates.size()) * 0.015)))
	for index in range(mini(target_count, candidates.size())):
		biome_map[candidates[index]] = BIOME_DESERT


## Browser desert shaping (main.js:22366-22820): two weighted-blur
## re-masking iterations (add above 0.62, remove below 0.5), orphan-sand
## removal, badlands cores inside the desert (main.js:22539-22719), a 2-tile
## sand-snow clearing buffer, and sand<->grass edge smoothing.
func _refine_desert_biomes(base_biome_map: Dictionary) -> void:
	var width := map_size.x
	var rows := map_size.y
	var cell_count := width * rows
	if cell_count <= 0 or _desert_suitability_buffer.size() != cell_count:
		return

	var water_mask := PackedByteArray()
	water_mask.resize(cell_count)
	var snow_mask := PackedByteArray()
	snow_mask.resize(cell_count)
	var grass_mask := PackedByteArray()
	grass_mask.resize(cell_count)
	var desert_mask := PackedByteArray()
	desert_mask.resize(cell_count)
	for y in range(rows):
		var row := y * width
		for x in range(width):
			var idx := row + x
			var biome := String(base_biome_map.get(Vector2i(x, y), BIOME_GRASSLAND))
			if biome == BIOME_WATER:
				water_mask[idx] = 1
			elif biome == BIOME_TUNDRA:
				snow_mask[idx] = 1
			elif biome == BIOME_DESERT or biome == BIOME_BADLANDS:
				desert_mask[idx] = 1
			elif biome == BIOME_GRASSLAND:
				grass_mask[idx] = 1

	# Weighted blur of the suitability field: radius 2, weight 1/(1+d)
	# (1.25 at the centre), 2 iterations, skipping water and snow.
	var offsets_dx := PackedInt32Array()
	var offsets_dy := PackedInt32Array()
	var offsets_weight := PackedFloat32Array()
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			offsets_dx.append(dx)
			offsets_dy.append(dy)
			if dx == 0 and dy == 0:
				offsets_weight.append(1.25)
			else:
				offsets_weight.append(1.0 / (1.0 + sqrt(float(dx * dx + dy * dy))))
	var sample_count := offsets_dx.size()
	var blur_current := _desert_suitability_buffer.duplicate()
	var blur_buffer := PackedFloat32Array()
	blur_buffer.resize(cell_count)
	for _iteration in range(2):
		for y in range(rows):
			var row := y * width
			for x in range(width):
				var idx := row + x
				if water_mask[idx] == 1 or snow_mask[idx] == 1:
					blur_buffer[idx] = 0.0
					continue
				var weight_sum := 0.0
				var sample_sum := 0.0
				for i in range(sample_count):
					var nx := x + offsets_dx[i]
					var ny := y + offsets_dy[i]
					if nx < 0 or ny < 0 or nx >= width or ny >= rows:
						continue
					var n_idx := ny * width + nx
					if water_mask[n_idx] == 1 or snow_mask[n_idx] == 1:
						continue
					var sample_weight := float(offsets_weight[i])
					sample_sum += float(blur_current[n_idx]) * sample_weight
					weight_sum += sample_weight
				blur_buffer[idx] = (sample_sum / weight_sum) if weight_sum > 0.0 else float(blur_current[idx])
		var swap := blur_current
		blur_current = blur_buffer
		blur_buffer = swap

	# Re-mask (main.js:22425-22470).
	var updated_mask := PackedByteArray()
	updated_mask.resize(cell_count)
	for y in range(rows):
		var row := y * width
		for x in range(width):
			var idx := row + x
			if water_mask[idx] == 1 or snow_mask[idx] == 1:
				continue
			var base_suitability := float(_desert_suitability_buffer[idx])
			var neighbor_desert := 0
			var neighbor_count := 0
			var neighbor_snow := 0
			for offset: Vector2i in NEIGHBOR_OFFSETS_8:
				var nx := x + offset.x
				var ny := y + offset.y
				if nx < 0 or ny < 0 or nx >= width or ny >= rows:
					continue
				var n_idx := ny * width + nx
				if snow_mask[n_idx] == 1:
					neighbor_snow += 1
				if water_mask[n_idx] == 1 or snow_mask[n_idx] == 1:
					continue
				neighbor_desert += desert_mask[n_idx]
				neighbor_count += 1
			# Never let sand sit against snow: a desert touching tundra reads
			# as a jarring seam, so clear it and let grassland buffer between.
			if neighbor_snow > 0:
				updated_mask[idx] = 0
				continue
			var local_density := (float(neighbor_desert) / float(neighbor_count)) if neighbor_count > 0 else float(desert_mask[idx])
			# Lower local-density weight and stricter acceptance stop the
			# refine pass from bleeding deserts across their neighbours;
			# the add rule tightened again (0.73->0.76, 0.6->0.64) to help
			# halve desert coverage per player feedback, while the remove
			# rule stays put so seeds with already-sparse deserts keep
			# their few arid pockets.
			var combined := base_suitability * 0.55 + float(blur_current[idx]) * 0.45 + local_density * 0.08
			if combined > 0.76 and base_suitability > 0.64:
				updated_mask[idx] = 1
			elif combined < 0.55 or base_suitability < 0.5:
				updated_mask[idx] = 0
			else:
				updated_mask[idx] = desert_mask[idx]
	desert_mask = updated_mask

	# Orphan removal (main.js:22472-22525): vertically isolated rows, then
	# singles with no desert neighbor at all.
	for y in range(1, rows - 1):
		var row := y * width
		for x in range(width):
			var idx := row + x
			if desert_mask[idx] == 0:
				continue
			if desert_mask[idx - width] == 0 and desert_mask[idx + width] == 0:
				desert_mask[idx] = 0
	for y in range(rows):
		var row := y * width
		for x in range(width):
			var idx := row + x
			if desert_mask[idx] == 0:
				continue
			var has_desert_neighbor := false
			for offset: Vector2i in NEIGHBOR_OFFSETS_8:
				var nx := x + offset.x
				var ny := y + offset.y
				if nx < 0 or ny < 0 or nx >= width or ny >= rows:
					continue
				if desert_mask[ny * width + nx] == 1:
					has_desert_neighbor = true
					break
			if not has_desert_neighbor:
				desert_mask[idx] = 0

	# Desert-snow clearing buffer (main.js:22721-22762, widened from the
	# browser's 2 tiles): sand butting against tundra reads as a jarring
	# climate seam, so a broad grassland belt separates the two. The belt
	# is guaranteed inside DESERT_SNOW_BUFFER_RADIUS and fades out with
	# noise over four more tiles, so its outer edge stays organic instead
	# of tracing the square Chebyshev dilation. Runs before badlands
	# seeding so the badlands mask never grows into the belt.
	var snow_buffer := _dilate_mask(snow_mask, DESERT_SNOW_BUFFER_RADIUS)
	var snow_fringe := _dilate_mask(snow_mask, DESERT_SNOW_BUFFER_RADIUS + 4)
	var belt_seed := map_seed + 0x51ed270b
	for y: int in range(rows):
		var row := y * width
		for x: int in range(width):
			var idx := row + x
			if desert_mask[idx] == 0 or snow_mask[idx] == 1:
				continue
			var clear_cell := snow_buffer[idx] == 1
			if not clear_cell and snow_fringe[idx] == 1:
				clear_cell = _value_noise(float(x) * 0.17, float(y) * 0.17, belt_seed) < 0.5
			if clear_cell:
				desert_mask[idx] = 0
				grass_mask[idx] = 1

	# Badlands cores (main.js:22539-22719): only inside deserts where
	# heat > 0.62 and dryness > 0.55. Deviation from the browser: its
	# "every badlands cell must touch bare sand" rule made solid interiors
	# illegal, so the revert pass carved axis-aligned sand stripes through
	# any mass thicker than two cells, and the saturated likelihood field
	# sheeted the mask straight to the desert rim - together reading as
	# blocky rectangles crossed by sand corridors. Instead the mask stays
	# one cell inside the desert (inheriting the desert's organic, noise
	# grown boundary, and never touching water) and gets a noise-eroded
	# ragged edge below.
	var badlands_mask := PackedByteArray()
	badlands_mask.resize(cell_count)
	var badlands_seed := map_seed + 0x7f4a7c15
	for y in range(rows):
		var row := y * width
		for x in range(width):
			var idx := row + x
			if desert_mask[idx] == 0:
				continue
			var heat := float(_desert_heat_buffer[idx])
			var dryness := float(_desert_suitability_buffer[idx])
			if heat <= 0.62 or dryness <= 0.55:
				continue
			var likelihood := clampf((heat - 0.62) * 1.15 + (dryness - 0.55) * 0.75, 0.0, 1.0)
			if _value_noise(float(x) * 0.11, float(y) * 0.11, badlands_seed) >= likelihood:
				continue
			if not _is_desert_interior(desert_mask, x, y):
				continue
			badlands_mask[idx] = 1

	# Bridge-fill, radius 2. Trimmed to a single pass so badlands cores stay
	# compact instead of ballooning across the whole desert interior.
	for _fill_iteration in range(1):
		var additions: Array[int] = []
		for y in range(rows):
			var row := y * width
			for x in range(width):
				var idx := row + x
				if desert_mask[idx] == 0 or badlands_mask[idx] == 1:
					continue
				# Interior-of-desert also guarantees no water contact, since
				# water is never part of the desert mask.
				if not _is_desert_interior(desert_mask, x, y):
					continue
				var neighbor_count := 0
				var has_left := false
				var has_right := false
				var has_up := false
				var has_down := false
				for dy in range(-2, 3):
					var ny := y + dy
					if ny < 0 or ny >= rows:
						continue
					for dx in range(-2, 3):
						if dx == 0 and dy == 0:
							continue
						var nx := x + dx
						if nx < 0 or nx >= width:
							continue
						if badlands_mask[ny * width + nx] == 0:
							continue
						neighbor_count += 1
						if dx < 0:
							has_left = true
						elif dx > 0:
							has_right = true
						if dy < 0:
							has_up = true
						elif dy > 0:
							has_down = true
				var has_bridge := (has_left and has_right) or (has_up and has_down) or ((has_left or has_right) and (has_up or has_down) and neighbor_count >= 3)
				if neighbor_count >= 2 and has_bridge:
					additions.append(idx)
		if additions.is_empty():
			break
		# The desert mask never changes here, so the interior test each
		# addition already passed cannot be invalidated by other additions;
		# apply the whole batch.
		for addition_idx: int in additions:
			badlands_mask[addition_idx] = 1

	# Noise-driven edge shaping: one grow pass then two erosion passes so
	# badlands borders undulate like the other biomes instead of tracing
	# the saturated likelihood iso-line, which runs straight for long
	# stretches along coasts and heat bands. The grow pass offsets the
	# area the erosion takes, keeping overall badlands coverage near its
	# tuned level. Distinct seed per pass; deterministic per map seed.
	var growth: Array[int] = []
	for y: int in range(rows):
		var row := y * width
		for x: int in range(width):
			var idx := row + x
			if desert_mask[idx] == 0 or badlands_mask[idx] == 1:
				continue
			if not _is_desert_interior(desert_mask, x, y):
				continue
			var touching := 0
			for offset: Vector2i in NEIGHBOR_OFFSETS_8:
				var nx := x + offset.x
				var ny := y + offset.y
				if nx < 0 or ny < 0 or nx >= width or ny >= rows:
					continue
				touching += badlands_mask[ny * width + nx]
			if touching >= 2 and _value_noise(float(x) * 0.29, float(y) * 0.29, badlands_seed + 977) >= 0.4:
				growth.append(idx)
	for growth_idx: int in growth:
		badlands_mask[growth_idx] = 1
	for erosion_pass: int in range(2):
		var eroded: Array[int] = []
		for y: int in range(rows):
			var row := y * width
			for x: int in range(width):
				var idx := row + x
				if badlands_mask[idx] == 0:
					continue
				var exposed := false
				for offset: Vector2i in NEIGHBOR_OFFSETS_8:
					var nx := x + offset.x
					var ny := y + offset.y
					if nx < 0 or ny < 0 or nx >= width or ny >= rows or badlands_mask[ny * width + nx] == 0:
						exposed = true
						break
				if not exposed:
					continue
				# The second pass bites more gently so the ragging does
				# not eat too far into the tuned badlands area.
				var erosion_threshold := 0.4 - 0.1 * float(erosion_pass)
				if _value_noise(float(x) * 0.29, float(y) * 0.29, badlands_seed + 977 * (erosion_pass + 2)) < erosion_threshold:
					eroded.append(idx)
		for eroded_idx: int in eroded:
			badlands_mask[eroded_idx] = 0

	# Whatever flat boundary segments survive the noise erosion (typically
	# where the desert's own edge is straight) still read as stamped
	# rectangle sides, so notch them apart deterministically.
	_break_straight_badlands_runs(badlands_mask, badlands_seed + 0x3d1f29)

	# Erosion can strand slivers; a cell holding onto the mass by fewer
	# than two neighbours reads as a stray chip, so drop it.
	for _cleanup_pass: int in range(2):
		var stray: Array[int] = []
		for y: int in range(rows):
			var row := y * width
			for x: int in range(width):
				var idx := row + x
				if badlands_mask[idx] == 0:
					continue
				var linked := 0
				for offset: Vector2i in NEIGHBOR_OFFSETS_8:
					var nx := x + offset.x
					var ny := y + offset.y
					if nx < 0 or ny < 0 or nx >= width or ny >= rows:
						continue
					linked += badlands_mask[ny * width + nx]
				if linked < 2:
					stray.append(idx)
		if stray.is_empty():
			break
		for stray_idx: int in stray:
			badlands_mask[stray_idx] = 0

	# Solid interior (main.js:22682-22719, strengthened): flood the outside
	# world through non-badlands cells - seeded from every non-desert cell
	# and the map border - then convert any sand the flood cannot reach.
	# The old per-cell "all 8 neighbours badlands" test missed multi-cell
	# pockets, leaving sand corridors inside the badlands body.
	var outside_reach := PackedByteArray()
	outside_reach.resize(cell_count)
	var flood_stack := PackedInt32Array()
	for y: int in range(rows):
		var row := y * width
		for x: int in range(width):
			var idx := row + x
			if badlands_mask[idx] == 1 or outside_reach[idx] == 1:
				continue
			if desert_mask[idx] == 1 and x > 0 and y > 0 and x < width - 1 and y < rows - 1:
				continue
			outside_reach[idx] = 1
			flood_stack.append(idx)
	while not flood_stack.is_empty():
		var flood_idx := int(flood_stack[flood_stack.size() - 1])
		flood_stack.resize(flood_stack.size() - 1)
		var fx := flood_idx % width
		var fy := int(flood_idx / float(width))
		# 4-connectivity: a diagonal-only sand thread still reads as a
		# pocket inside the mass, so it should convert too.
		for offset: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var nx := fx + offset.x
			var ny := fy + offset.y
			if nx < 0 or ny < 0 or nx >= width or ny >= rows:
				continue
			var n_idx := ny * width + nx
			if badlands_mask[n_idx] == 1 or outside_reach[n_idx] == 1:
				continue
			outside_reach[n_idx] = 1
			flood_stack.append(n_idx)
	for idx: int in range(cell_count):
		if desert_mask[idx] == 1 and badlands_mask[idx] == 0 and outside_reach[idx] == 0:
			badlands_mask[idx] = 1

	# Sand<->grass edge smoothing (main.js:22764-22820): cardinal-complete
	# lone tiles flip to match their surroundings.
	var flips: Array[int] = []
	for y in range(1, rows - 1):
		var row := y * width
		for x in range(1, width - 1):
			var idx := row + x
			var is_sand := desert_mask[idx] == 1 and badlands_mask[idx] == 0
			var is_grass := desert_mask[idx] == 0 and grass_mask[idx] == 1
			if not is_sand and not is_grass:
				continue
			var all_grass := true
			var all_sand := true
			for offset: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				var n_idx := (y + offset.y) * width + (x + offset.x)
				var neighbor_sand: bool = desert_mask[n_idx] == 1 and badlands_mask[n_idx] == 0
				var neighbor_grass: bool = desert_mask[n_idx] == 0 and grass_mask[n_idx] == 1
				if not neighbor_grass:
					all_grass = false
				if not neighbor_sand:
					all_sand = false
				if not all_grass and not all_sand:
					break
			if is_sand and all_grass:
				flips.append(idx)
			elif is_grass and all_sand:
				flips.append(idx)
	for flip_idx: int in flips:
		if desert_mask[flip_idx] == 1:
			desert_mask[flip_idx] = 0
			badlands_mask[flip_idx] = 0
			grass_mask[flip_idx] = 1
		else:
			desert_mask[flip_idx] = 1
			grass_mask[flip_idx] = 0

	# Write the refined masks back to the biome dictionary.
	for y in range(rows):
		var row := y * width
		for x in range(width):
			var idx := row + x
			if water_mask[idx] == 1 or snow_mask[idx] == 1:
				continue
			var coord := Vector2i(x, y)
			var biome := String(base_biome_map.get(coord, BIOME_GRASSLAND))
			if desert_mask[idx] == 1:
				var target := BIOME_BADLANDS if badlands_mask[idx] == 1 else BIOME_DESERT
				if biome != target:
					base_biome_map[coord] = target
			elif biome == BIOME_DESERT or biome == BIOME_BADLANDS:
				base_biome_map[coord] = BIOME_GRASSLAND


## True when the cell and all 8 neighbours sit on the desert mask (desert
## or badlands). Badlands only grow here, so the mask always keeps at
## least one desert cell between badlands and grass/water/snow - that rim
## follows the desert's noise-grown outline, keeping badlands borders
## organic without the browser's per-cell touching-sand rule.
func _is_desert_interior(desert_mask: PackedByteArray, x: int, y: int) -> bool:
	var width := map_size.x
	var rows := map_size.y
	if desert_mask[y * width + x] == 0:
		return false
	for offset: Vector2i in NEIGHBOR_OFFSETS_8:
		var nx := x + offset.x
		var ny := y + offset.y
		if nx < 0 or ny < 0 or nx >= width or ny >= rows:
			return false
		if desert_mask[ny * width + nx] == 0:
			return false
	return true


## Scans the badlands boundary in all four exposure directions for
## segments that run straight for more than six cells and erodes periodic
## notches out of them. Straight boundaries that long are what made the
## old badlands read as stamped rectangles; noise erosion alone can leave
## them intact where the underlying desert edge is itself straight.
func _break_straight_badlands_runs(badlands_mask: PackedByteArray, break_seed: int) -> void:
	var width := map_size.x
	var rows := map_size.y
	# For vertical exposures the run follows x; for horizontal ones, y.
	var exposures: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	var to_erode: Dictionary = {}
	for exposure: Vector2i in exposures:
		var outer_limit := width if exposure.y == 0 else rows
		var inner_limit := rows if exposure.y == 0 else width
		for outer: int in range(outer_limit):
			var run_cells: Array[int] = []
			for inner: int in range(inner_limit):
				var x := outer if exposure.y == 0 else inner
				var y := inner if exposure.y == 0 else outer
				var idx := y * width + x
				var nx := x + exposure.x
				var ny := y + exposure.y
				var neighbor_open := nx < 0 or ny < 0 or nx >= width or ny >= rows or badlands_mask[ny * width + nx] == 0
				if badlands_mask[idx] == 1 and neighbor_open:
					run_cells.append(idx)
				else:
					_mark_straight_run_notches(run_cells, break_seed, to_erode)
					run_cells = []
			_mark_straight_run_notches(run_cells, break_seed, to_erode)
	for erode_variant: Variant in to_erode.keys():
		badlands_mask[int(erode_variant)] = 0


## Marks every fifth cell of a straight boundary run longer than six for
## erosion, phased per run from the seeded hash, capping any surviving
## straight stretch at four cells.
func _mark_straight_run_notches(run_cells: Array[int], break_seed: int, to_erode: Dictionary) -> void:
	if run_cells.size() <= 6:
		return
	var phase := int(_hash_coords(run_cells[0], run_cells.size(), break_seed) * 4.99)
	for i: int in range(run_cells.size()):
		if i % 5 == phase:
			to_erode[run_cells[i]] = true


## Browser marsh cellular automaton (main.js:22920-23062): two grow/decay
## iterations driven by live suitability, then isolated-marsh removal.
func _refine_marsh_biomes(
	base_biome_map: Dictionary,
	height_buffer: PackedFloat32Array,
	moisture_buffer: PackedFloat32Array,
	height_map: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var width := map_size.x
	var rows := map_size.y
	var cell_count := width * rows
	if cell_count <= 0 or height_buffer.size() != cell_count or moisture_buffer.size() != cell_count:
		return
	var water_mask := PackedByteArray()
	water_mask.resize(cell_count)
	var grass_mask := PackedByteArray()
	grass_mask.resize(cell_count)
	var marsh_mask := PackedByteArray()
	marsh_mask.resize(cell_count)
	for y in range(rows):
		var row := y * width
		for x in range(width):
			var idx := row + x
			var biome := String(base_biome_map.get(Vector2i(x, y), BIOME_GRASSLAND))
			if biome == BIOME_WATER:
				water_mask[idx] = 1
			elif biome == BIOME_GRASSLAND:
				grass_mask[idx] = 1
			elif biome == BIOME_MARSH:
				marsh_mask[idx] = 1

	for _iteration in range(2):
		var next_mask := PackedByteArray()
		next_mask.resize(cell_count)
		for y in range(rows):
			var row := y * width
			for x in range(width):
				var idx := row + x
				if water_mask[idx] == 1:
					continue
				var currently_marsh := marsh_mask[idx] == 1
				if not currently_marsh and grass_mask[idx] == 0:
					continue
				var marsh_neighbors := 0
				for offset: Vector2i in NEIGHBOR_OFFSETS_8:
					var nx := x + offset.x
					var ny := y + offset.y
					if nx < 0 or ny < 0 or nx >= width or ny >= rows:
						continue
					var n_idx := ny * width + nx
					if water_mask[n_idx] == 0 and marsh_mask[n_idx] == 1:
						marsh_neighbors += 1
				var suitability := _marsh_suitability(x, y, float(height_buffer[idx]), float(moisture_buffer[idx]), height_map)
				var score := suitability.x
				var threshold := suitability.y
				var qualifies := suitability.z > 0.5
				var next_is_marsh := currently_marsh
				if currently_marsh:
					if not qualifies and marsh_neighbors <= 1:
						next_is_marsh = false
					elif marsh_neighbors <= 2 and score < threshold:
						next_is_marsh = false
					elif score < threshold - 0.08:
						next_is_marsh = false
				else:
					next_is_marsh = false
					if qualifies and (marsh_neighbors >= 3 or (marsh_neighbors >= 2 and score > threshold + 0.05)):
						next_is_marsh = true
					elif marsh_neighbors >= 4 and score > threshold - 0.02:
						next_is_marsh = true
				if score < 0.0:
					next_is_marsh = false
				if next_is_marsh:
					next_mask[idx] = 1
		marsh_mask = next_mask

	for y in range(rows):
		var row := y * width
		for x in range(width):
			var idx := row + x
			if water_mask[idx] == 1:
				continue
			var coord := Vector2i(x, y)
			var biome := String(base_biome_map.get(coord, BIOME_GRASSLAND))
			if marsh_mask[idx] == 1:
				if biome != BIOME_MARSH:
					base_biome_map[coord] = BIOME_MARSH
			elif biome == BIOME_MARSH:
				base_biome_map[coord] = BIOME_GRASSLAND

	# Isolated marsh tiles convert to a random neighbor base
	# (main.js:23016-23062).
	var isolated: Array[Dictionary] = []
	for y in range(rows):
		var row := y * width
		for x in range(width):
			var idx := row + x
			if marsh_mask[idx] == 0:
				continue
			var coord := Vector2i(x, y)
			var neighbor_options: Array[String] = []
			var marsh_neighbor_count := 0
			var valid_neighbor_count := 0
			for offset: Vector2i in NEIGHBOR_OFFSETS_8:
				var neighbor := coord + offset
				if not _is_valid_map_coord(neighbor):
					continue
				valid_neighbor_count += 1
				var neighbor_biome := String(base_biome_map.get(neighbor, BIOME_GRASSLAND))
				if neighbor_biome == BIOME_MARSH:
					marsh_neighbor_count += 1
				else:
					neighbor_options.append(neighbor_biome)
			if valid_neighbor_count > 0 and marsh_neighbor_count == 0 and neighbor_options.size() == valid_neighbor_count:
				var picked_base := neighbor_options[rng.randi_range(0, neighbor_options.size() - 1)]
				if picked_base == BIOME_WATER:
					# Never mint new water here: the landmass masks are
					# already frozen for this generation.
					picked_base = BIOME_GRASSLAND
				isolated.append({
					"coord": coord,
					"base": picked_base
				})
	for entry: Dictionary in isolated:
		base_biome_map[entry.get("coord", Vector2i.ZERO) as Vector2i] = String(entry.get("base", BIOME_GRASSLAND))


func _biome_to_tile(biome: String) -> Vector2i:
	return BIOME_CLASSIFIER.biome_to_tile(biome, _tile_lookup(), _biome_lookup())

## Browser iceberg parity (main.js:24593-24712), three deterministic passes:
## (a) snow tiles fully surrounded by water calve into water + iceberg;
## (b) 18% of overlay-free water tiles inside the snow-presence band get a
##     berg - per-coordinate hash, not RNG order, shoreline placement allowed;
## (c) 1-in-50 of snow-band water tiles seed lone drift ice.
## The band is the browser's NORTH-only snow band (latitude = 1 - y/height,
## full above 0.86, partial 0.5-0.86) - the same _compute_snow_presence
## field that drives tundra, so drift ice and snowfields always agree.
const ICEBERG_SHORELINE_CHANCE := 0.18
const ICEBERG_OPEN_WATER_CHANCE := 0.02
const ICEBERG_SHORELINE_SEED_OFFSET := 0x91bd4a2f
const ICEBERG_PRESENCE_SEED_OFFSET := 0x5ad1f32b
const ICEBERG_VARIANT_SEED_OFFSET := 0x3d0e12f7

func _place_icebergs(
	base_biome_map: Dictionary,
	biome_map: Dictionary,
	height_map: Dictionary
) -> void:
	if iceberg_layer == null:
		return
	if map_layer != null:
		iceberg_layer.tile_set = map_layer.tile_set
	iceberg_layer.clear()
	var water_biome_id := _biome_to_id(BIOME_WATER)
	var water_tile := _biome_to_tile(BIOME_WATER)
	# Pass (a): snow islets fully ringed by water become water + iceberg.
	for y in range(map_size.y):
		for x in range(map_size.x):
			var coord := Vector2i(x, y)
			if String(base_biome_map.get(coord, "")) != BIOME_TUNDRA:
				continue
			var fully_surrounded := true
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					if ox == 0 and oy == 0:
						continue
					var neighbor := coord + Vector2i(ox, oy)
					if neighbor.y < 0:
						# Browser: past the top edge counts as open polar sea.
						continue
					if not _is_valid_map_coord(neighbor) or String(base_biome_map.get(neighbor, "")) != BIOME_WATER:
						fully_surrounded = false
						break
				if not fully_surrounded:
					break
			if not fully_surrounded:
				continue
			base_biome_map[coord] = BIOME_WATER
			biome_map[coord] = BIOME_WATER
			if map_layer != null:
				map_layer.set_cell(coord, _atlas_source_id, water_tile)
			if highland_layer != null:
				highland_layer.erase_cell(coord)
			if tree_layer != null:
				tree_layer.erase_cell(coord)
			if river_layer != null:
				river_layer.erase_cell(coord)
			var info := _tile_data.get(coord, {}) as Dictionary
			if not info.is_empty():
				info["biome_id"] = water_biome_id
				info["base_biome_id"] = water_biome_id
				info["hill_biome_id"] = _biome_to_id(BIOME_GRASSLAND)
				info["overlay_flags"] = 0
				# The cultural/structure pipeline matches on the parallel
				# label strings; calved tiles must read as water there too.
				info["biome_type"] = BIOME_WATER
				info["base_biome"] = BIOME_WATER
				info["overlay"] = ""
				info["hill_overlay"] = ""
				info["structure"] = ""
				info["structure_details"] = null
				info["ambient_structure"] = null
				info["water_depth"] = 0.0
				_tile_data[coord] = info
			iceberg_layer.set_cell(coord, _atlas_source_id, _iceberg_tile_for_coord(coord))
	# Passes (b) and (c): hash-seeded drift ice on cold shoreline/open water.
	for y in range(map_size.y):
		for x in range(map_size.x):
			var coord := Vector2i(x, y)
			if not _is_iceberg_water(coord, base_biome_map, water_biome_id):
				continue
			if iceberg_layer.get_cell_source_id(coord) != -1:
				continue
			if not _iceberg_snow_presence(coord, float(height_map.get(coord, 0.0))):
				continue
			var placed := _hash_coords(x, y, map_seed + ICEBERG_SHORELINE_SEED_OFFSET) < ICEBERG_SHORELINE_CHANCE
			if not placed and _north_latitude(y) >= SNOW_LATITUDE_START:
				placed = _hash_coords(x, y, map_seed + ICEBERG_PRESENCE_SEED_OFFSET) < ICEBERG_OPEN_WATER_CHANCE
			if placed:
				iceberg_layer.set_cell(coord, _atlas_source_id, _iceberg_tile_for_coord(coord))

func _is_iceberg_water(coord: Vector2i, base_biome_map: Dictionary, water_biome_id: int) -> bool:
	# Volcano passes rewrite tile_data (lava lakes) without touching the
	# biome dictionaries, so tile_data is the fresher source when present.
	var info := _tile_data.get(coord, {}) as Dictionary
	if not info.is_empty():
		return int(info.get("base_biome_id", -1)) == water_biome_id
	return String(base_biome_map.get(coord, "")) == BIOME_WATER

## Browser needSnowPresenceField (main.js:21637-21646): icebergs read the
## same NORTH-only snow-presence field that assigns tundra.
func _iceberg_snow_presence(coord: Vector2i, tile_height: float) -> bool:
	return _compute_snow_presence(coord.x, coord.y, tile_height)

func _iceberg_tile_for_coord(coord: Vector2i) -> Vector2i:
	if iceberg_tile_options.is_empty():
		return Vector2i(4, 3)
	var variant_noise := _hash_coords(coord.x, coord.y, map_seed + ICEBERG_VARIANT_SEED_OFFSET)
	var variant_index := clampi(int(floor(variant_noise * float(iceberg_tile_options.size()))), 0, iceberg_tile_options.size() - 1)
	return iceberg_tile_options[variant_index]

## Browser-parity settlement placement (main.js:23871-26240): scored town
## candidates with spacing, a hamlet back-fill pass, ridge-scored dwarfhold
## distribution with range coverage, and scored grove/lizardmen passes.
func _place_settlements(height_map: Dictionary, rng: RandomNumberGenerator) -> void:
	_town_points.clear()
	_hamlet_points.clear()
	_dwarfhold_points.clear()
	_grove_points.clear()
	_lizardmen_city_points.clear()
	_desert_city_points.clear()
	_hillhold_points.clear()
	_placement_fields = _build_placement_fields(height_map)
	var stage_log := PackedStringArray()
	var stage_ms := Time.get_ticks_msec()
	if _settlement_frequency_normalized("humans") > 0.0:
		var seeded_grass_hamlets := _place_towns_browser_style(rng)
		_place_hamlet_expansion(seeded_grass_hamlets, rng)
	stage_log.append("towns %d" % (Time.get_ticks_msec() - stage_ms))
	stage_ms = Time.get_ticks_msec()
	if _settlement_frequency_normalized("dwarves") > 0.0:
		_place_dwarfholds_browser_style(rng)
	stage_log.append("dwarfholds %d" % (Time.get_ticks_msec() - stage_ms))
	stage_ms = Time.get_ticks_msec()
	if _settlement_frequency_normalized("wood_elves") > 0.0:
		_place_wood_elf_groves(rng)
	if _settlement_frequency_normalized("lizardmen") > 0.0:
		_place_lizardmen_cities(rng)
	stage_log.append("groves+lizardmen %d" % (Time.get_ticks_msec() - stage_ms))
	print("[OverworldMap] settlement passes ms: %s" % " | ".join(stage_log))


## Normalized settlement frequency for a civilization key (browser
## *SettlementFrequencyNormalized, main.js:21309-21316). Default 0.5.
func _settlement_frequency_normalized(civilization: String) -> float:
	var ratios: Dictionary = _world_settings.get("settlement_ratios", {}) as Dictionary
	var settlements: Dictionary = _world_settings.get("settlements", {}) as Dictionary
	if ratios.has(civilization):
		return clampf(float(ratios.get(civilization, 0.5)), 0.0, 1.0)
	if settlements.has(civilization):
		return clampf(float(settlements.get(civilization, 50.0)) / 100.0, 0.0, 1.0)
	return 0.5


## Browser computeFrequencyMultiplier (main.js:8683-8688): 0 -> 0.5, 1 -> 2.0.
func _frequency_multiplier(frequency_normalized: float) -> float:
	return 0.5 + clampf(frequency_normalized, 0.0, 1.0) * 1.5


## Browser adjustMinDistance (main.js:8781-8806): x1.2 at freq 0, x0.7 at 1.
func _adjusted_min_distance(base_distance: float, frequency_normalized: float) -> int:
	if base_distance <= 0.0:
		return 6
	var multiplier := 1.2 - clampf(frequency_normalized, 0.0, 1.0) * 0.5
	return maxi(1, int(round(base_distance * multiplier)))


## Browser computeStructurePlacementLimit (main.js:8742-8760).
func _structure_placement_limit(base_target: int, max_limit: int, multiplier: float) -> int:
	var safe_target := maxi(1, base_target)
	var safe_multiplier := multiplier if multiplier > 0.0 else 1.0
	return maxi(1, mini(int(round(float(safe_target) * safe_multiplier)), maxi(1, max_limit)))


## Browser computeDwarfholdDistributionAdjustment (main.js:8716-8740).
func _dwarfhold_distribution_adjustment(x: int, y: int, rows: int, seed_value: int) -> float:
	var hashed: int = ((x * 73856093) ^ (y * 19349663) ^ (seed_value * 83492791)) & 0xFFFFFFFF
	var normalized := float(hashed % 1000000) / 1000000.0
	var vertical_bias := (float(y) / maxf(1.0, float(rows))) * 2.0 - 1.0
	return (normalized - 0.5) * 0.15 + vertical_bias * 0.05


func _nearest_distance_sq_points(coord: Vector2i, points: Array[Vector2i]) -> float:
	var best := INF
	for point: Vector2i in points:
		var dist_sq := float((coord - point).length_squared())
		if dist_sq < best:
			best = dist_sq
	return best


## Two-pass chamfer distance transform (near-euclidean, weights 1/1.414)
## from a set of source cells - the browser's computeNearestDistanceSq /
## computeEuclideanDistanceField calls collapse into O(cells) lookups.
func _chamfer_distance_field(sources: Array[Vector2i]) -> PackedFloat32Array:
	var w := map_size.x
	var rows := map_size.y
	var field := PackedFloat32Array()
	field.resize(w * rows)
	field.fill(1.0e9)
	if sources.is_empty():
		return field
	for source: Vector2i in sources:
		if source.x >= 0 and source.y >= 0 and source.x < w and source.y < rows:
			field[source.y * w + source.x] = 0.0
	var diagonal := 1.41421356
	for y in range(rows):
		var row := y * w
		for x in range(w):
			var idx := row + x
			var best := float(field[idx])
			if x > 0 and float(field[idx - 1]) + 1.0 < best:
				best = float(field[idx - 1]) + 1.0
			if y > 0:
				if float(field[idx - w]) + 1.0 < best:
					best = float(field[idx - w]) + 1.0
				if x > 0 and float(field[idx - w - 1]) + diagonal < best:
					best = float(field[idx - w - 1]) + diagonal
				if x < w - 1 and float(field[idx - w + 1]) + diagonal < best:
					best = float(field[idx - w + 1]) + diagonal
			field[idx] = best
	for y in range(rows - 1, -1, -1):
		var row := y * w
		for x in range(w - 1, -1, -1):
			var idx := row + x
			var best := float(field[idx])
			if x < w - 1 and float(field[idx + 1]) + 1.0 < best:
				best = float(field[idx + 1]) + 1.0
			if y < rows - 1:
				if float(field[idx + w]) + 1.0 < best:
					best = float(field[idx + w]) + 1.0
				if x < w - 1 and float(field[idx + w + 1]) + diagonal < best:
					best = float(field[idx + w + 1]) + diagonal
				if x > 0 and float(field[idx + w - 1]) + diagonal < best:
					best = float(field[idx + w - 1]) + diagonal
			field[idx] = best
	return field


## Flat per-cell buffers + per-biome index lists so the placement passes
## avoid re-walking _tile_data dictionaries (65k Vector2i lookups apiece).
func _build_placement_fields(height_map: Dictionary) -> Dictionary:
	var w := map_size.x
	var rows := map_size.y
	var cell_count := w * rows
	var height_field := PackedFloat32Array()
	height_field.resize(cell_count)
	var base_id := PackedByteArray()
	base_id.resize(cell_count)
	var hill_id := PackedByteArray()
	hill_id.resize(cell_count)
	var flags := PackedByteArray()
	flags.resize(cell_count)
	var blocked := PackedByteArray()
	blocked.resize(cell_count)
	var moisture_field := PackedFloat32Array()
	moisture_field.resize(cell_count)
	var moisture_local := PackedFloat32Array()
	moisture_local.resize(cell_count)
	var canopy := PackedFloat32Array()
	canopy.resize(cell_count)
	var grass_cells := PackedInt32Array()
	var snow_cells := PackedInt32Array()
	var sand_cells := PackedInt32Array()
	var marsh_cells := PackedInt32Array()
	var badlands_cells := PackedInt32Array()
	var forest_cells := PackedInt32Array()
	var jungle_cells := PackedInt32Array()
	var grass_id := _biome_to_id(BIOME_GRASSLAND)
	var snow_id := _biome_to_id(BIOME_TUNDRA)
	var sand_id := _biome_to_id(BIOME_DESERT)
	var marsh_id := _biome_to_id(BIOME_MARSH)
	var badlands_id := _biome_to_id(BIOME_BADLANDS)
	for y in range(rows):
		var row := y * w
		for x in range(w):
			var idx := row + x
			var coord := Vector2i(x, y)
			var tile_info := _tile_data.get(coord, {}) as Dictionary
			var cell_base := int(tile_info.get("base_biome_id", grass_id))
			base_id[idx] = cell_base
			hill_id[idx] = int(tile_info.get("hill_biome_id", grass_id))
			var cell_flags := int(tile_info.get("overlay_flags", 0))
			flags[idx] = cell_flags
			height_field[idx] = float(height_map.get(coord, 0.0))
			var wetness := clampf(float(tile_info.get("moisture", 0.5)), 0.0, 1.0)
			moisture_field[idx] = wetness
			var rainfall := float(_rainfall_buffer[idx]) if idx < _rainfall_buffer.size() else 0.5
			# Browser localMoisture = rainfall*0.7 + (1-drainage)*0.3; the
			# wetness map stands in for poor drainage.
			moisture_local[idx] = clampf(rainfall * 0.7 + wetness * 0.3, 0.0, 1.0)
			canopy[idx] = clampf(float(tile_info.get("forest_canopy_density", 0.0)), 0.0, 1.0)
			if tile_info.has("settlement_type") or not String(tile_info.get("structure", "")).is_empty():
				blocked[idx] = 1
			if cell_flags & TILE_OVERLAY_FOREST:
				forest_cells.append(idx)
			elif cell_flags & TILE_OVERLAY_TREE:
				jungle_cells.append(idx)
			if cell_base == grass_id:
				grass_cells.append(idx)
			elif cell_base == snow_id:
				snow_cells.append(idx)
			elif cell_base == sand_id:
				sand_cells.append(idx)
			elif cell_base == marsh_id:
				marsh_cells.append(idx)
			elif cell_base == badlands_id:
				badlands_cells.append(idx)
	return {
		"height": height_field,
		"base_id": base_id,
		"hill_id": hill_id,
		"flags": flags,
		"blocked": blocked,
		"moisture": moisture_field,
		"moisture_local": moisture_local,
		"canopy": canopy,
		"grass_cells": grass_cells,
		"snow_cells": snow_cells,
		"sand_cells": sand_cells,
		"marsh_cells": marsh_cells,
		"badlands_cells": badlands_cells,
		"forest_cells": forest_cells,
		"jungle_cells": jungle_cells
	}


## Town candidate scoring + spacing (browser main.js:24864-25095): grass and
## snow cells scored on elevation near sea+0.18, flatness, edge distance,
## river adjacency, moisture-derived grass preference and biome penalties.
## Towns never land on river tiles.
func _place_towns_browser_style(rng: RandomNumberGenerator) -> int:
	var w := map_size.x
	var rows := map_size.y
	var height_field := _placement_fields["height"] as PackedFloat32Array
	var base_id := _placement_fields["base_id"] as PackedByteArray
	var hill_id := _placement_fields["hill_id"] as PackedByteArray
	var flags := _placement_fields["flags"] as PackedByteArray
	var blocked := _placement_fields["blocked"] as PackedByteArray
	var moisture_field := _placement_fields["moisture"] as PackedFloat32Array
	var moisture_local := _placement_fields["moisture_local"] as PackedFloat32Array
	var water_id := _biome_to_id(BIOME_WATER)
	var mountain_id := _biome_to_id(BIOME_MOUNTAIN)
	var snow_id := _biome_to_id(BIOME_TUNDRA)
	var preferred_elevation := water_level + 0.18
	var max_edge_distance := maxf(1.0, float(mini(w, rows)) / 2.0)
	var overlay_block := TILE_OVERLAY_TREE | TILE_OVERLAY_FOREST | TILE_OVERLAY_RIVER
	var candidates: Array[Dictionary] = []
	for cell_list_variant: Variant in [_placement_fields["grass_cells"], _placement_fields["snow_cells"]]:
		var cell_list := cell_list_variant as PackedInt32Array
		for list_index in cell_list.size():
			var idx := cell_list[list_index]
			if blocked[idx] == 1 or (int(flags[idx]) & overlay_block) != 0:
				continue
			if int(hill_id[idx]) == mountain_id:
				continue
			var x := idx % w
			@warning_ignore("integer_division")
			var y := idx / w
			var is_snow := int(base_id[idx]) == snow_id
			var elevation_value := float(height_field[idx])
			var elevation_score := clampf(1.0 - absf(elevation_value - preferred_elevation) * 2.1, 0.0, 1.0)
			var local_moisture := float(moisture_local[idx])
			var roughness := 0.0
			var neighbor_count := 0
			var neighborhood_moisture_sum := 0.0
			for offset: Vector2i in NEIGHBOR_OFFSETS_8:
				var nx := x + offset.x
				var ny := y + offset.y
				if nx < 0 or ny < 0 or nx >= w or ny >= rows:
					continue
				var n_idx := ny * w + nx
				if int(base_id[n_idx]) == water_id:
					continue
				roughness += absf(elevation_value - float(height_field[n_idx]))
				neighbor_count += 1
				neighborhood_moisture_sum += float(moisture_local[n_idx])
			var average_roughness := (roughness / float(neighbor_count)) if neighbor_count > 0 else 0.0
			var slope_score := clampf(1.0 - average_roughness * 12.0, 0.0, 1.0)
			var edge_distance := mini(mini(x, w - 1 - x), mini(y, rows - 1 - y))
			var edge_score := clampf(float(edge_distance) / max_edge_distance, 0.0, 1.0)
			var neighborhood_moisture := (neighborhood_moisture_sum / float(neighbor_count)) if neighbor_count > 0 else local_moisture
			var blended_moisture := local_moisture * 0.65 + neighborhood_moisture * 0.35
			var dryness := 1.0 - blended_moisture
			var humidity_excess := maxf(0.0, blended_moisture - 0.52)
			var swamp_pressure := maxf(0.0, blended_moisture - 0.68)
			var arid_pressure := maxf(0.0, dryness - 0.55)
			var drainage_value := 1.0 - float(moisture_field[idx])
			var poor_drainage := maxf(0.0, 0.48 - drainage_value)
			var normalized_y := (float(y) + 0.5) / float(rows)
			var latitude_factor := 1.0 - absf(normalized_y - 0.5) * 2.0
			var elevation_above_sea := maxf(elevation_value - water_level, 0.0)
			var elevation_cooling := clampf(1.0 - elevation_above_sea * 3.5, 0.0, 1.0)
			var approximate_temperature := clampf(latitude_factor * 0.75 + elevation_cooling * 0.25, 0.0, 1.0)
			var relative_elevation := elevation_value - water_level
			var biome_tendency := "grassland"
			if relative_elevation < 0.05:
				if blended_moisture > 0.7:
					biome_tendency = "marsh"
				elif blended_moisture > 0.54 and approximate_temperature > 0.52:
					biome_tendency = "forest"
			elif blended_moisture < 0.3:
				biome_tendency = "badlands"
			elif approximate_temperature < 0.3:
				biome_tendency = "tundra"
			elif blended_moisture > 0.72:
				biome_tendency = "marsh"
			elif blended_moisture > 0.52 and approximate_temperature > 0.55:
				biome_tendency = "forest"
			var grass_preference := clampf(
				1.0 - humidity_excess * 1.4 - swamp_pressure * 1.25 - arid_pressure * 1.05 - poor_drainage * 0.55,
				0.0,
				1.0
			)
			if biome_tendency == "forest":
				grass_preference *= 0.12
			elif biome_tendency == "marsh":
				grass_preference *= 0.08
			elif biome_tendency == "tundra" or biome_tendency == "badlands":
				grass_preference *= 0.35
			if not is_snow and grass_preference < 0.22:
				continue
			var river_adjacency := 0
			for definition: Dictionary in RIVER_NEIGHBOR_DEFINITIONS:
				var card_offset := definition.get("offset", Vector2i.ZERO) as Vector2i
				var nx := x + card_offset.x
				var ny := y + card_offset.y
				if nx < 0 or ny < 0 or nx >= w or ny >= rows:
					continue
				if int(flags[ny * w + nx]) & TILE_OVERLAY_RIVER:
					river_adjacency += 1
			var river_score := clampf(0.18 + float(river_adjacency) * 0.06, 0.0, 0.32) if river_adjacency > 0 else 0.0
			var biome_penalty := 0.0
			if biome_tendency == "forest":
				biome_penalty = 0.24
			elif biome_tendency == "marsh":
				biome_penalty = 0.18
			elif biome_tendency == "tundra" or biome_tendency == "badlands":
				biome_penalty = 0.08
			var score := (
				elevation_score * 0.35
				+ slope_score * 0.2
				+ edge_score * 0.12
				+ river_score
				+ grass_preference * 0.32
				- biome_penalty
				+ rng.randf() * 0.12
			)
			candidates.append({
				"coord": Vector2i(x, y),
				"score": score,
				"grass_preference": grass_preference,
				"snow": is_snow
			})
	if candidates.is_empty():
		return 0
	candidates = STRUCTURE_PLACER.sort_candidates_by_score(candidates)
	var human_frequency := _settlement_frequency_normalized("humans")
	var area := w * rows
	var base_target := maxi(2, int(round(float(area) / 4800.0)))
	var max_towns := _structure_placement_limit(base_target, 36, _frequency_multiplier(human_frequency))
	var min_distance := _adjusted_min_distance(maxf(6.0, round(float(mini(w, rows)) / 12.0)), human_frequency)
	var min_distance_sq := float(min_distance * min_distance)
	var placed: Array[Vector2i] = []
	var seeded_grass_hamlets := 0
	for candidate: Dictionary in candidates:
		if placed.size() >= max_towns:
			break
		var is_snow := bool(candidate.get("snow", false))
		if not is_snow and float(candidate.get("grass_preference", 0.0)) < 0.25:
			continue
		var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		if _nearest_distance_sq_points(coord, placed) < min_distance_sq:
			continue
		if _is_mountain_tile(coord):
			continue
		var idx := coord.y * w + coord.x
		if blocked[idx] == 1 or (int(flags[idx]) & TILE_OVERLAY_RIVER) != 0:
			continue
		var settlement_name: String
		var population := 0
		var is_small_village := false
		if is_snow:
			# Browser snow villages (main.js:25040-25046): population 30-100,
			# always classified Village; larger rolls skip the site.
			settlement_name = SETTLEMENT_NAMING.snow_village_name(rng)
			population = maxi(20, int(30.0 + rng.randf() * 70.0))
			if population >= 100:
				continue
			is_small_village = true
		else:
			settlement_name = SETTLEMENT_NAMING.town_name(rng)
			var raw_population := maxi(20, int(20.0 + rng.randf() * 6000.0))
			is_small_village = raw_population < 100
			population = clampi(raw_population, 450, 6200)
		var tile := TOWN_TILE
		# Earned port skin (main.js:25047-25064): an 8-neighbor must be water.
		for offset: Vector2i in NEIGHBOR_OFFSETS_8:
			var nx := coord.x + offset.x
			var ny := coord.y + offset.y
			if nx < 0 or ny < 0 or nx >= w or ny >= rows:
				continue
			if int(base_id[ny * w + nx]) == water_id:
				tile = PORT_TOWN_TILE
				break
		var is_hamlet := false
		if is_small_village:
			if is_snow:
				# Snowy hamlets read as igloo clusters; show them most of the
				# time so the north actually looks inhabited by igloos.
				if rng.randf() < 0.85:
					tile = HAMLET_SNOW_TILE
					is_hamlet = true
			else:
				tile = HAMLET_TILE
				is_hamlet = true
		if is_hamlet:
			population = maxi(18, int(24.0 + rng.randf() * 60.0)) if is_snow else maxi(22, int(28.0 + rng.randf() * 140.0))
		var classification := "Village" if (is_snow or is_hamlet) else TownDetailsGenerator.classification_for_population(population)
		_register_town_settlement(coord, tile, settlement_name, classification, population, is_hamlet, is_snow, rng)
		blocked[idx] = 1
		placed.append(coord)
		_town_points.append(coord)
		if is_hamlet:
			_hamlet_points.append(coord)
			if not is_snow:
				seeded_grass_hamlets += 1
	return seeded_grass_hamlets


func _register_town_settlement(
	coord: Vector2i,
	tile: Vector2i,
	settlement_name: String,
	classification: String,
	population: int,
	is_hamlet: bool,
	is_snow: bool,
	rng: RandomNumberGenerator
) -> void:
	if settlement_layer != null:
		settlement_layer.set_cell(coord, _atlas_source_id, tile)
	else:
		map_layer.set_cell(coord, _atlas_source_id, tile)
	var tile_info := _tile_data.get(coord, {}) as Dictionary
	_tile_region_names[coord] = settlement_name
	tile_info["settlement_type"] = "town"
	tile_info["settlement_classification"] = classification
	tile_info["is_hamlet"] = is_hamlet
	tile_info["is_snow_village"] = is_snow
	var founded_years_ago := _founded_years_ago_for_settlement_type("town", rng)
	tile_info["founded_years_ago"] = founded_years_ago
	# Hamlets and snow villages are all-human (browser generateHamletDetails
	# populationBreakdown, main.js:3894-3910).
	var population_options: Array = TOWN_POPULATION_RACE_OPTIONS
	if is_snow or is_hamlet:
		population_options = [TOWN_POPULATION_RACE_OPTIONS[0]]
	var majority_key := String((population_options[0] as Dictionary).get("key", ""))
	var population_breakdown := _generate_population_breakdown_from_options(population_options, population, rng, majority_key)
	tile_info["population"] = population
	tile_info["population_label"] = "Population"
	tile_info["population_descriptor"] = "residents"
	tile_info["population_breakdown"] = population_breakdown
	# The world chronicle rewrites every settlement's timeline from real
	# events after nations exist; rolling a placeholder here is pure waste.
	tile_info["population_timeline"] = []
	var labels := _labels_from_population_breakdown(population_breakdown)
	_tile_population_groups[coord] = {
		"major_population_groups": labels.get("major", ["Humans"]),
		"minor_population_groups": labels.get("minor", [])
	}
	_tile_data[coord] = tile_info


## Hamlet expansion (browser main.js:25096-25235): back-fill grass hamlets
## up to max(6x seeded, area/12000) scored on a moisture sweet spot, grass
## neighbors, water adjacency and distance-from-town sweet spot.
func _place_hamlet_expansion(seeded_grass_hamlets: int, rng: RandomNumberGenerator) -> void:
	var w := map_size.x
	var rows := map_size.y
	var area := w * rows
	var human_frequency := _settlement_frequency_normalized("humans")
	var desired := maxi(seeded_grass_hamlets * 6, int(round(float(area) / 12000.0 * _frequency_multiplier(human_frequency))))
	var additional_needed := maxi(0, desired - seeded_grass_hamlets)
	if additional_needed <= 0:
		return
	var base_id := _placement_fields["base_id"] as PackedByteArray
	var hill_id := _placement_fields["hill_id"] as PackedByteArray
	var flags := _placement_fields["flags"] as PackedByteArray
	var blocked := _placement_fields["blocked"] as PackedByteArray
	var moisture_local := _placement_fields["moisture_local"] as PackedFloat32Array
	var grass_cells := _placement_fields["grass_cells"] as PackedInt32Array
	var water_id := _biome_to_id(BIOME_WATER)
	var mountain_id := _biome_to_id(BIOME_MOUNTAIN)
	var grass_id := _biome_to_id(BIOME_GRASSLAND)
	var settlement_field := _chamfer_distance_field(_town_points)
	var hamlet_field := _chamfer_distance_field(_hamlet_points)
	var noise_seed := map_seed + 0x62bd3e45
	var overlay_block := TILE_OVERLAY_TREE | TILE_OVERLAY_FOREST | TILE_OVERLAY_RIVER
	var candidates: Array[Dictionary] = []
	for list_index in grass_cells.size():
		var idx := grass_cells[list_index]
		if blocked[idx] == 1 or (int(flags[idx]) & overlay_block) != 0:
			continue
		if int(hill_id[idx]) == mountain_id:
			continue
		var settlement_distance := float(settlement_field[idx])
		if settlement_distance < 5.0:
			continue
		if float(hamlet_field[idx]) < 5.0:
			continue
		var x := idx % w
		@warning_ignore("integer_division")
		var y := idx / w
		var moisture := float(moisture_local[idx])
		var moisture_score := clampf(1.0 - absf(moisture - 0.55) * 2.2, 0.0, 1.0) * 0.24
		var grass_neighbors := 0
		var neighbor_samples := 0
		var water_adjacency := 0
		for offset: Vector2i in NEIGHBOR_OFFSETS_8:
			var nx := x + offset.x
			var ny := y + offset.y
			if nx < 0 or ny < 0 or nx >= w or ny >= rows:
				continue
			var n_idx := ny * w + nx
			if int(base_id[n_idx]) == water_id:
				water_adjacency += 1
				continue
			if int(flags[n_idx]) & TILE_OVERLAY_RIVER:
				water_adjacency += 1
			if int(base_id[n_idx]) == grass_id:
				grass_neighbors += 1
			neighbor_samples += 1
		var adjacency_score := (float(grass_neighbors) / float(neighbor_samples)) * 0.18 if neighbor_samples > 0 else 0.0
		var water_score := clampf(float(water_adjacency) * 0.04, 0.0, 0.18)
		var proximity_score := clampf((settlement_distance - 6.0) / 14.0, 0.0, 1.0) * 0.2
		var latitude := (float(y) + 0.5) / float(rows)
		var latitude_score := absf(sin((latitude + 0.15) * PI * 2.0)) * 0.08
		var noise := _hash_coords(x, y, noise_seed) - 0.5
		var score := 0.28 + moisture_score + adjacency_score + water_score + proximity_score + latitude_score + noise * 0.18 + rng.randf() * 0.08
		candidates.append({"coord": Vector2i(x, y), "score": score})
	if candidates.is_empty():
		return
	candidates = STRUCTURE_PLACER.sort_candidates_by_score(candidates)
	var placed := 0
	for candidate: Dictionary in candidates:
		if placed >= additional_needed:
			break
		if float(candidate.get("score", 0.0)) < 0.24:
			continue
		var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		if _nearest_distance_sq_points(coord, _hamlet_points) < 25.0:
			continue
		if _nearest_distance_sq_points(coord, _town_points) < 20.0:
			continue
		if _is_mountain_tile(coord):
			continue
		var idx := coord.y * w + coord.x
		if blocked[idx] == 1 or (int(flags[idx]) & TILE_OVERLAY_RIVER) != 0:
			continue
		var settlement_name := SETTLEMENT_NAMING.town_name(rng)
		var population := maxi(22, int(28.0 + rng.randf() * 140.0))
		_register_town_settlement(coord, HAMLET_TILE, settlement_name, "Village", population, true, false, rng)
		blocked[idx] = 1
		_town_points.append(coord)
		_hamlet_points.append(coord)
		placed += 1


## Dwarfhold distribution (browser main.js:23871-24175): ridge-scored
## mountain candidates plus high-score near-mountain fallbacks, >=12 tiles
## from towns, spacing 6, per-range coverage and a southern-half top-up.
func _place_dwarfholds_browser_style(rng: RandomNumberGenerator) -> void:
	var w := map_size.x
	var rows := map_size.y
	var cell_count := w * rows
	var base_id := _placement_fields["base_id"] as PackedByteArray
	var hill_id := _placement_fields["hill_id"] as PackedByteArray
	var flags := _placement_fields["flags"] as PackedByteArray
	var blocked := _placement_fields["blocked"] as PackedByteArray
	var height_field := _placement_fields["height"] as PackedFloat32Array
	var water_id := _biome_to_id(BIOME_WATER)
	var mountain_id := _biome_to_id(BIOME_MOUNTAIN)
	var have_scores := _mountain_score_buffer.size() == cell_count
	var fallback_threshold := clampf(_mountain_candidate_threshold * 0.85, 0.28, 0.62)
	var distribution_seed := map_seed + 0x3bd39e8f
	var overlay_block := TILE_OVERLAY_TREE | TILE_OVERLAY_FOREST
	var candidates: Array[Dictionary] = []
	var mountain_candidate_set: Dictionary = {}
	for idx in range(cell_count):
		if int(base_id[idx]) == water_id:
			continue
		if int(flags[idx]) & TILE_OVERLAY_RIVER:
			continue
		var is_mountain := int(hill_id[idx]) == mountain_id or int(base_id[idx]) == mountain_id
		var score := float(_mountain_score_buffer[idx]) if have_scores else clampf((float(height_field[idx]) - water_level) / maxf(0.0001, 1.0 - water_level), 0.0, 1.0)
		if not is_mountain:
			var fallback_eligible: bool = (int(flags[idx]) & overlay_block) == 0 and score >= fallback_threshold
			if not fallback_eligible:
				continue
		var x := idx % w
		@warning_ignore("integer_division")
		var y := idx / w
		var coord := Vector2i(x, y)
		candidates.append({
			"coord": coord,
			"score": score + _dwarfhold_distribution_adjustment(x, y, rows, distribution_seed),
			"raw_score": score,
			"mountain": is_mountain
		})
		if is_mountain:
			mountain_candidate_set[coord] = true
	if candidates.is_empty():
		return
	candidates = STRUCTURE_PLACER.sort_candidates_by_score(candidates)
	var dwarf_frequency := _settlement_frequency_normalized("dwarves")
	var multiplier := _frequency_multiplier(dwarf_frequency)
	var base_target := maxi(1, int(round(float(candidates.size()) / 500.0)))
	var max_dwarfholds := _structure_placement_limit(base_target, 24, multiplier)
	# Abandoned chance lerp(0.35, 0.05, frequency) (main.js:8761-8780).
	var abandoned_chance := clampf(0.35 - dwarf_frequency * 0.30, 0.05, 0.35)
	var min_distance_base := 6.0
	var min_distance := _adjusted_min_distance(min_distance_base, dwarf_frequency)
	var south_min_distance := _adjusted_min_distance(float(maxi(3, int(round(min_distance_base * 0.85)))), dwarf_frequency)
	# O(1) guards: cells within spacing of a placed hold / within 12 tiles
	# of a town are pre-marked instead of point-looped per candidate.
	var town_blocked: Dictionary = {}
	for town: Vector2i in _town_points:
		OverworldSettlementService.mark_occupied_area(town_blocked, town, DWARFHOLD_NEARBY_TOWN_RADIUS)
	var spacing_blocked: Dictionary = {}
	var south_spacing_blocked: Dictionary = {}
	var placed: Array[Vector2i] = []
	for candidate: Dictionary in candidates:
		if placed.size() >= max_dwarfholds:
			break
		var main_coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		if spacing_blocked.has(main_coord) or town_blocked.has(main_coord):
			continue
		if _try_place_dwarfhold(candidate, placed, abandoned_chance, blocked, flags, rng):
			OverworldSettlementService.mark_occupied_area(spacing_blocked, main_coord, float(min_distance))
			OverworldSettlementService.mark_occupied_area(south_spacing_blocked, main_coord, float(south_min_distance))
	if placed.is_empty():
		for candidate: Dictionary in candidates:
			var fallback_coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
			if town_blocked.has(fallback_coord):
				continue
			if _try_place_dwarfhold(candidate, placed, abandoned_chance, blocked, flags, rng):
				OverworldSettlementService.mark_occupied_area(spacing_blocked, fallback_coord, float(min_distance))
				OverworldSettlementService.mark_occupied_area(south_spacing_blocked, fallback_coord, float(south_min_distance))
				break
	# Coverage pass: every connected mountain range with candidates gets at
	# least one hold (browser mountainAreasWithHolds, main.js:24013-24118).
	# Deviation: the browser keys ranges off large named biome clusters;
	# Godot's ridge chains split into many small components, so only ranges
	# of a meaningful size demand coverage and the hold spacing stays
	# enforced (a tiny splinter range next to a held range counts as
	# covered by it).
	var component_of: Dictionary = {}
	var component_sizes: Array[int] = []
	for candidate: Dictionary in candidates:
		var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		if not bool(candidate.get("mountain", false)) or component_of.has(coord):
			continue
		var component_id := component_sizes.size()
		var component_size := 0
		var stack: Array[Vector2i] = [coord]
		while not stack.is_empty():
			var current: Vector2i = stack.pop_back()
			if component_of.has(current):
				continue
			component_of[current] = component_id
			component_size += 1
			for offset: Vector2i in NEIGHBOR_OFFSETS_8:
				var neighbor := current + offset
				if mountain_candidate_set.has(neighbor) and not component_of.has(neighbor):
					stack.append(neighbor)
		component_sizes.append(component_size)
	var missing_components: Dictionary = {}
	for coord_variant: Variant in component_of.keys():
		var range_id := int(component_of[coord_variant])
		if component_sizes[range_id] >= 12:
			missing_components[range_id] = true
	for hold: Vector2i in placed:
		if component_of.has(hold):
			missing_components.erase(int(component_of[hold]))
	if not missing_components.is_empty():
		for candidate: Dictionary in candidates:
			if missing_components.is_empty():
				break
			if not bool(candidate.get("mountain", false)):
				continue
			var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
			var component_id := int(component_of.get(coord, -1))
			if component_id < 0 or not missing_components.has(component_id):
				continue
			if spacing_blocked.has(coord) or town_blocked.has(coord):
				continue
			if _try_place_dwarfhold(candidate, placed, abandoned_chance, blocked, flags, rng):
				OverworldSettlementService.mark_occupied_area(spacing_blocked, coord, float(min_distance))
				OverworldSettlementService.mark_occupied_area(south_spacing_blocked, coord, float(south_min_distance))
				missing_components.erase(component_id)
	# Southern-half top-up with tighter spacing (main.js:24120-24175).
	var south_boundary := int(floor(float(rows) * 0.45))
	var southern_candidate_count := 0
	for candidate: Dictionary in candidates:
		if (candidate.get("coord", Vector2i(-1, -1)) as Vector2i).y >= south_boundary:
			southern_candidate_count += 1
	if southern_candidate_count > 0:
		var placed_south := 0
		for hold: Vector2i in placed:
			if hold.y >= south_boundary:
				placed_south += 1
		var south_base_target := maxi(1, int(round(float(southern_candidate_count) / 650.0)))
		var south_max := _structure_placement_limit(south_base_target, 16, multiplier)
		var south_limit_from_total := maxi(1, int(ceil(float(max_dwarfholds) * 0.5)))
		var south_extra := maxi(0, mini(mini(south_max - placed_south, south_limit_from_total), southern_candidate_count - placed_south))
		if south_extra > 0:
			var south_placed := 0
			for candidate: Dictionary in candidates:
				if south_placed >= south_extra:
					break
				var south_coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
				if south_coord.y < south_boundary:
					continue
				if south_spacing_blocked.has(south_coord) or town_blocked.has(south_coord):
					continue
				if _try_place_dwarfhold(candidate, placed, abandoned_chance, blocked, flags, rng):
					OverworldSettlementService.mark_occupied_area(spacing_blocked, south_coord, float(min_distance))
					OverworldSettlementService.mark_occupied_area(south_spacing_blocked, south_coord, float(south_min_distance))
					south_placed += 1


## Browser tryPlaceDwarfhold (main.js:9097-9260): dark holds within 4 tiles
## of a volcano, GREAT on score>0.75 with a 15% roll, otherwise an abandoned
## roll. Spacing and the 12-tile town guard are enforced by the callers'
## marked-area dictionaries.
func _try_place_dwarfhold(
	candidate: Dictionary,
	placed: Array[Vector2i],
	abandoned_chance: float,
	blocked: PackedByteArray,
	flags: PackedByteArray,
	rng: RandomNumberGenerator
) -> bool:
	var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
	if coord.x < 0 or coord.y < 0 or coord.x >= map_size.x or coord.y >= map_size.y:
		return false
	var idx := coord.y * map_size.x + coord.x
	if blocked[idx] == 1 or (int(flags[idx]) & TILE_OVERLAY_RIVER) != 0:
		return false
	# Never on a volcano tile itself (browser isVolcanoOverlayKey guard).
	if _is_within_tiles_of_volcano(coord, 0):
		return false
	var tile := DWARFHOLD_TILE
	if _is_within_tiles_of_volcano(coord, 4):
		tile = DARK_DWARFHOLD_TILE
	elif float(candidate.get("raw_score", 0.0)) > 0.75 and rng.randf() < 0.15:
		tile = GREAT_DWARFHOLD_TILE
	elif rng.randf() < abandoned_chance:
		tile = ABANDONED_DWARFHOLD_TILE
	if settlement_layer != null:
		settlement_layer.set_cell(coord, _atlas_source_id, tile)
	else:
		map_layer.set_cell(coord, _atlas_source_id, tile)
	var settlement_name := "Dwarfhold"
	if not DWARFHOLD_NAMES.is_empty():
		settlement_name = DWARFHOLD_NAMES[rng.randi_range(0, DWARFHOLD_NAMES.size() - 1)]
	var tile_info := _tile_data.get(coord, {}) as Dictionary
	_tile_region_names[coord] = settlement_name
	_tile_population_groups[coord] = {"major_population_groups": ["Dwarves"], "minor_population_groups": []}
	tile_info["settlement_type"] = "dwarfhold"
	tile_info.merge(_generate_dwarfhold_details(settlement_name, coord, tile, rng), true)
	tile_info[DWARFHOLD_SCENE_SEED_KEY] = _dwarfhold_scene_seed_for_tile(coord, tile_info)
	_tile_data[coord] = tile_info
	blocked[idx] = 1
	placed.append(coord)
	_dwarfhold_points.append(coord)
	return true


## Registers a grove/lizardmen settlement with the standard detail block
## (founded years, population breakdown and timeline).
func _register_scored_settlement(
	coord: Vector2i,
	tile: Vector2i,
	settlement_type: String,
	settlement_name: String,
	civilization_label: String,
	population: int,
	rng: RandomNumberGenerator
) -> void:
	if settlement_layer != null:
		settlement_layer.set_cell(coord, _atlas_source_id, tile)
	else:
		map_layer.set_cell(coord, _atlas_source_id, tile)
	var tile_info := _tile_data.get(coord, {}) as Dictionary
	_tile_region_names[coord] = settlement_name
	_tile_population_groups[coord] = {"major_population_groups": [civilization_label], "minor_population_groups": []}
	tile_info["settlement_type"] = settlement_type
	var founded_years_ago := _founded_years_ago_for_settlement_type(settlement_type, rng)
	tile_info["founded_years_ago"] = founded_years_ago
	var population_options := _population_options_for_settlement_type(settlement_type)
	if not population_options.is_empty():
		var majority_key := String((population_options[0] as Dictionary).get("key", ""))
		var population_breakdown := _generate_population_breakdown_from_options(population_options, population, rng, majority_key)
		tile_info["population"] = population
		tile_info["population_label"] = "Population"
		tile_info["population_descriptor"] = "residents"
		tile_info["population_breakdown"] = population_breakdown
		# Rewritten from chronicle events after the history simulation.
		tile_info["population_timeline"] = []
		var labels := _labels_from_population_breakdown(population_breakdown)
		_tile_population_groups[coord] = {
			"major_population_groups": labels.get("major", [civilization_label]),
			"minor_population_groups": labels.get("minor", [])
		}
	_tile_data[coord] = tile_info


## Wood elf groves (browser main.js:25972-26155): forest-canopy scored,
## never on or adjacent to ocean, min spacing 14, and the grove tile is
## upgraded to LARGE/GRAND by population ratio >=0.8/>=0.9.
func _place_wood_elf_groves(rng: RandomNumberGenerator) -> void:
	var w := map_size.x
	var rows := map_size.y
	var base_id := _placement_fields["base_id"] as PackedByteArray
	var flags := _placement_fields["flags"] as PackedByteArray
	var blocked := _placement_fields["blocked"] as PackedByteArray
	var forest_cells := _placement_fields["forest_cells"] as PackedInt32Array
	var snow_id := _biome_to_id(BIOME_TUNDRA)
	var ocean_cells := _landmass_masks.get("ocean_cells", {}) as Dictionary
	var candidates: Array[Dictionary] = []
	for list_index in forest_cells.size():
		var idx := forest_cells[list_index]
		if blocked[idx] == 1 or int(base_id[idx]) == snow_id:
			continue
		var x := idx % w
		@warning_ignore("integer_division")
		var y := idx / w
		var coord := Vector2i(x, y)
		var near_ocean := ocean_cells.has(coord)
		var tree_neighbors := 0
		for offset: Vector2i in NEIGHBOR_OFFSETS_8:
			var nx := x + offset.x
			var ny := y + offset.y
			if nx < 0 or ny < 0 or nx >= w or ny >= rows:
				near_ocean = true
				continue
			if not near_ocean and ocean_cells.has(Vector2i(nx, ny)):
				near_ocean = true
			if int(flags[ny * w + nx]) & TILE_OVERLAY_FOREST:
				tree_neighbors += 1
		if near_ocean:
			continue
		# Tree-density stand-in for the browser treeDensityField.
		var score := float(tree_neighbors + 1) / 9.0
		candidates.append({"coord": coord, "score": score})
	if candidates.is_empty():
		return
	candidates = STRUCTURE_PLACER.sort_candidates_by_score(candidates)
	var elf_frequency := _settlement_frequency_normalized("wood_elves")
	var base_target := maxi(1, int(round(float(candidates.size()) / 1350.0)))
	var max_groves := _structure_placement_limit(base_target, 28, _frequency_multiplier(elf_frequency))
	var min_distance := _adjusted_min_distance(14.0, elf_frequency)
	var min_distance_sq := float(min_distance * min_distance)
	for candidate: Dictionary in candidates:
		if _grove_points.size() >= max_groves:
			break
		if float(candidate.get("score", 0.0)) < 0.32:
			continue
		var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		if _nearest_distance_sq_points(coord, _grove_points) < min_distance_sq:
			continue
		var idx := coord.y * w + coord.x
		if blocked[idx] == 1:
			continue
		var population := _roll_population_for_settlement_type("woodElfGrove", rng)
		var population_ratio := float(population) / 2800.0
		var tile := WOOD_ELF_GROVES_TILE
		if population_ratio >= 0.9:
			tile = WOOD_ELF_GROVES_GRAND_TILE
		elif population_ratio >= 0.8:
			tile = WOOD_ELF_GROVES_LARGE_TILE
		_register_scored_settlement(coord, tile, "woodElfGrove", SETTLEMENT_NAMING.grove_name(rng), "Wood Elves", population, rng)
		blocked[idx] = 1
		_grove_points.append(coord)


## Lizardmen cities (browser main.js:26157-26234): deep-jungle scoring
## (density + humidity + equatorial band + low elevation), min spacing 18.
func _place_lizardmen_cities(rng: RandomNumberGenerator) -> void:
	var w := map_size.x
	var rows := map_size.y
	var height_field := _placement_fields["height"] as PackedFloat32Array
	var flags := _placement_fields["flags"] as PackedByteArray
	var blocked := _placement_fields["blocked"] as PackedByteArray
	var moisture_local := _placement_fields["moisture_local"] as PackedFloat32Array
	var jungle_cells := _placement_fields["jungle_cells"] as PackedInt32Array
	var preferred_elevation := water_level + 0.08
	var candidates: Array[Dictionary] = []
	for list_index in jungle_cells.size():
		var idx := jungle_cells[list_index]
		if blocked[idx] == 1:
			continue
		var x := idx % w
		@warning_ignore("integer_division")
		var y := idx / w
		var jungle_neighbors := 0
		for offset: Vector2i in NEIGHBOR_OFFSETS_8:
			var nx := x + offset.x
			var ny := y + offset.y
			if nx < 0 or ny < 0 or nx >= w or ny >= rows:
				continue
			if int(flags[ny * w + nx]) & TILE_OVERLAY_TREE:
				jungle_neighbors += 1
		var density := float(jungle_neighbors + 1) / 9.0
		var humidity := float(moisture_local[idx])
		var normalized_y := (float(y) + 0.5) / float(rows)
		var equatorial_alignment := clampf(1.0 - absf(normalized_y - 0.5) * 2.0, 0.0, 1.0)
		var elevation_preference := clampf(1.0 - absf(float(height_field[idx]) - preferred_elevation) * 3.0, 0.0, 1.0)
		var score := density * 0.45 + humidity * 0.25 + equatorial_alignment * 0.15 + elevation_preference * 0.15
		candidates.append({"coord": Vector2i(x, y), "score": score})
	if candidates.is_empty():
		return
	candidates = STRUCTURE_PLACER.sort_candidates_by_score(candidates)
	var lizard_frequency := _settlement_frequency_normalized("lizardmen")
	var base_target := maxi(1, int(round(float(candidates.size()) / 3300.0)))
	var max_cities := _structure_placement_limit(base_target, 18, _frequency_multiplier(lizard_frequency))
	var min_distance := _adjusted_min_distance(18.0, lizard_frequency)
	var min_distance_sq := float(min_distance * min_distance)
	for candidate: Dictionary in candidates:
		if _lizardmen_city_points.size() >= max_cities:
			break
		if float(candidate.get("score", 0.0)) < 0.33:
			continue
		var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		if _nearest_distance_sq_points(coord, _lizardmen_city_points) < min_distance_sq:
			continue
		var idx := coord.y * w + coord.x
		if blocked[idx] == 1:
			continue
		var population := _roll_population_for_settlement_type("lizardmenCity", rng)
		_register_scored_settlement(coord, LIZARDMEN_CITY_TILE, "lizardmenCity", OVERWORLD_CONTENT.generate_lizardmen_city_name(rng), "Lizardmen", population, rng)
		blocked[idx] = 1
		_lizardmen_city_points.append(coord)


func _place_github_style_structures(
	biome_map: Dictionary,
	height_map: Dictionary,
	moisture_map: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var map_area := maxi(1, map_size.x * map_size.y)
	var occupied: Array[Vector2i] = []
	for coord: Vector2i in _tile_data.keys():
		var tile_info := _tile_data.get(coord, {}) as Dictionary
		if tile_info.has("settlement_type") or not String(tile_info.get("structure", "")).strip_edges().is_empty():
			occupied.append(coord)
	if _placement_fields.is_empty():
		_placement_fields = _build_placement_fields(height_map)

	var placer_started := Time.get_ticks_msec()
	var placer_times := PackedStringArray()
	_place_wizard_tower_settlements(biome_map, height_map, moisture_map, rng, occupied, map_area)
	placer_times.append("towers %d" % (Time.get_ticks_msec() - placer_started))
	placer_started = Time.get_ticks_msec()
	_place_desert_cities(rng, occupied, map_area)
	_place_evil_keeps(rng, occupied, map_area)
	placer_times.append("desert+keeps %d" % (Time.get_ticks_msec() - placer_started))
	placer_started = Time.get_ticks_msec()
	# The passes above work off the occupied list; fold their placements
	# into the shared blocked buffer before the browser-parity passes run.
	var blocked := _placement_fields["blocked"] as PackedByteArray
	for coord: Vector2i in occupied:
		if coord.x >= 0 and coord.y >= 0 and coord.x < map_size.x and coord.y < map_size.y:
			blocked[coord.y * map_size.x + coord.x] = 1
	# Distance fields are built once from the settlement sets and reused by
	# every rule below (browser computeNearestDistanceSq call sites).
	var major_points: Array[Vector2i] = []
	major_points.append_array(_town_points)
	major_points.append_array(_dwarfhold_points)
	major_points.append_array(_grove_points)
	major_points.append_array(_lizardmen_city_points)
	major_points.append_array(_desert_city_points)
	var field_major := _chamfer_distance_field(major_points)
	placer_times.append("fields %d" % (Time.get_ticks_msec() - placer_started))
	placer_started = Time.get_ticks_msec()
	_place_mines_hillholds_and_dams(height_map, rng, occupied, map_area)
	placer_times.append("mines %d" % (Time.get_ticks_msec() - placer_started))
	placer_started = Time.get_ticks_msec()
	_place_goblin_caves(rng, occupied, map_area)
	_place_dungeons(rng, occupied, map_area)
	placer_times.append("caves %d" % (Time.get_ticks_msec() - placer_started))
	placer_started = Time.get_ticks_msec()
	var hostile_points := _place_war_camps(field_major, rng, occupied, map_area)
	var field_hostile := _chamfer_distance_field(hostile_points)
	var centaur_points := _place_centaur_encampments(field_major, field_hostile, rng, occupied, map_area)
	var traveler_points := _place_traveler_camps(field_major, field_hostile, centaur_points, rng, occupied, map_area)
	placer_times.append("camps %d" % (Time.get_ticks_msec() - placer_started))
	placer_started = Time.get_ticks_msec()
	_place_roadside_taverns(field_major, field_hostile, centaur_points, traveler_points, rng, occupied, map_area)
	var monastery_points := _place_monasteries(field_major, field_hostile, centaur_points, rng, occupied, map_area)
	_place_castles(field_major, rng, occupied, map_area)
	var field_monastery := _chamfer_distance_field(monastery_points)
	_place_saint_shrines(field_major, field_monastery, rng, occupied, map_area)
	placer_times.append("taverns+clergy+castles %d" % (Time.get_ticks_msec() - placer_started))
	print("[OverworldMap] ambient placers ms: %s" % " | ".join(placer_times))
	# The shared buffers are only valid during generation; drop them.
	_placement_fields = {}


func _place_wizard_tower_settlements(
	biome_map: Dictionary,
	height_map: Dictionary,
	moisture_map: Dictionary,
	rng: RandomNumberGenerator,
	occupied: Array[Vector2i],
	map_area: int
) -> void:
	var tower_candidates := STRUCTURE_PLACER.build_wizard_tower_candidates(
		_tile_data,
		biome_map,
		height_map,
		moisture_map,
		occupied,
		map_size,
		_biome_lookup(),
		rng
	)
	if tower_candidates.is_empty():
		return

	var max_towers := maxi(1, int(round(float(map_area) / 20000.0)))
	var min_distance := maxf(5.0, float(mini(map_size.x, map_size.y)) / 14.0)
	var settlements_created := 0
	for candidate: Dictionary in tower_candidates:
		if settlements_created >= max_towers:
			break
		if float(candidate.get("score", 0.0)) < 0.22:
			continue
		var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		if _is_too_close(coord, occupied, min_distance):
			continue
		if _is_mountain_tile(coord):
			continue
		var is_evil := settlements_created % 2 == 0
		var settlement_type := "evilWizardTower" if is_evil else "wizardTower"
		var settlement_name := SETTLEMENT_NAMING.evil_wizard_tower_name(rng) if is_evil else SETTLEMENT_NAMING.tower_name(rng)
		_place_structure_with_details(
			coord,
			EVIL_WIZARDS_TOWER_TILE if is_evil else TOWER_TILE,
			"evilWizardTower" if is_evil else "tower",
			{
				"settlement_type": settlement_type,
				"region_name": settlement_name,
				"settlement_classification": "Evil Wizard Tower" if is_evil else "Wizard Tower",
				"major_population_groups": ["Wizards"],
				"minor_population_groups": ["Apprentices"]
			}
		)
		occupied.append(coord)
		settlements_created += 1


## Hostile war camps (browser main.js:26506-26706): grass/sand/marsh/
## badlands sites >=6 tiles from settlements, dryness/hill/water scored,
## then typed per terrain (trolls marsh/water, ogres hills, gnolls dry/sand,
## orcs badlands, bandits near settlements ~9 tiles out).
func _place_war_camps(
	field_major: PackedFloat32Array,
	rng: RandomNumberGenerator,
	occupied: Array[Vector2i],
	map_area: int
) -> Array[Vector2i]:
	var w := map_size.x
	var rows := map_size.y
	var base_id := _placement_fields["base_id"] as PackedByteArray
	var hill_id := _placement_fields["hill_id"] as PackedByteArray
	var flags := _placement_fields["flags"] as PackedByteArray
	var blocked := _placement_fields["blocked"] as PackedByteArray
	var water_id := _biome_to_id(BIOME_WATER)
	var mountain_id := _biome_to_id(BIOME_MOUNTAIN)
	var hills_id := _biome_to_id(BIOME_HILLS)
	var grass_id := _biome_to_id(BIOME_GRASSLAND)
	var sand_id := _biome_to_id(BIOME_DESERT)
	var marsh_id := _biome_to_id(BIOME_MARSH)
	var badlands_id := _biome_to_id(BIOME_BADLANDS)
	var noise_seed := map_seed + 0x4a1d2b7f
	var edge_divisor := maxf(6.0, float(mini(w, rows)) / 3.2)
	var candidates: Array[Dictionary] = []
	var hostile_points: Array[Vector2i] = []
	for cell_list_variant: Variant in [
		_placement_fields["grass_cells"],
		_placement_fields["sand_cells"],
		_placement_fields["marsh_cells"],
		_placement_fields["badlands_cells"]
	]:
		var cell_list := cell_list_variant as PackedInt32Array
		for list_index in cell_list.size():
			var idx := cell_list[list_index]
			if blocked[idx] == 1 or (int(flags[idx]) & TILE_OVERLAY_RIVER) != 0:
				continue
			if int(hill_id[idx]) == mountain_id:
				continue
			var settlement_distance := float(field_major[idx])
			if settlement_distance < 6.0:
				continue
			var x := idx % w
			@warning_ignore("integer_division")
			var y := idx / w
			var cell_base := int(base_id[idx])
			var rainfall := float(_rainfall_buffer[idx]) if idx < _rainfall_buffer.size() else 0.5
			var dryness := clampf(1.0 - rainfall, 0.0, 1.0)
			var base_score := 0.2
			if cell_base == badlands_id:
				base_score += 0.45
			elif cell_base == sand_id:
				base_score += 0.36
			elif cell_base == marsh_id:
				base_score += 0.28
			else:
				base_score += 0.24
			var hill_present: bool = int(hill_id[idx]) == hills_id and cell_base != marsh_id
			var hill_bonus := 0.16 if hill_present else 0.0
			var water_adjacency := 0
			for definition: Dictionary in RIVER_NEIGHBOR_DEFINITIONS:
				var offset := definition.get("offset", Vector2i.ZERO) as Vector2i
				var nx := x + offset.x
				var ny := y + offset.y
				if nx < 0 or ny < 0 or nx >= w or ny >= rows:
					continue
				if int(base_id[ny * w + nx]) == water_id:
					water_adjacency += 1
			var water_score := clampf(float(water_adjacency) * 0.08, 0.0, 0.18)
			var settlement_penalty := clampf((10.0 - settlement_distance) * 0.05, 0.0, 0.35)
			var border_distance := mini(mini(x, w - 1 - x), mini(y, rows - 1 - y))
			var edge_score := clampf(float(border_distance) / edge_divisor, 0.0, 1.0) * 0.12
			var noise := _hash_coords(x, y, noise_seed) - 0.5
			var score := base_score + dryness * 0.35 + hill_bonus + water_score + edge_score + noise * 0.22 + rng.randf() * 0.18 - settlement_penalty
			if score > 0.28:
				candidates.append({
					"coord": Vector2i(x, y),
					"score": score,
					"dryness": dryness,
					"water_adjacency": water_adjacency,
					"hill": hill_present,
					"settlement_distance": settlement_distance,
					"grass": cell_base == grass_id,
					"sand": cell_base == sand_id,
					"marsh": cell_base == marsh_id,
					"badlands": cell_base == badlands_id,
					"snow": false
				})
	if candidates.is_empty():
		return hostile_points
	candidates = STRUCTURE_PLACER.sort_candidates_by_score(candidates)
	var max_camps := _structure_placement_limit(maxi(1, int(round(float(map_area) / 14000.0))), 16, 1.0)
	var min_distance_sq := 64.0
	var camp_tiles := {
		"orcCamp": ORC_CAMP_TILE,
		"gnollCamp": GNOLL_CAMP_TILE,
		"trollCamp": TROLL_CAMP_TILE,
		"ogreCamp": OGRE_CAMP_TILE,
		"banditCamp": BANDIT_CAMP_TILE
	}
	for candidate: Dictionary in candidates:
		if hostile_points.size() >= max_camps:
			break
		if float(candidate.get("score", 0.0)) < 0.3:
			continue
		var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		if _nearest_distance_sq_points(coord, hostile_points) < min_distance_sq:
			continue
		var idx := coord.y * w + coord.x
		if blocked[idx] == 1:
			continue
		var camp_id := _select_war_camp_type(candidate, rng)
		_place_structure_with_details(
			coord,
			camp_tiles.get(camp_id, ORC_CAMP_TILE) as Vector2i,
			camp_id,
			{
				"region_name": SETTLEMENT_NAMING.camp_name(camp_id, rng),
				"settlement_classification": camp_id.capitalize()
			}
		)
		blocked[idx] = 1
		occupied.append(coord)
		hostile_points.append(coord)
	return hostile_points


## Browser selectWarCampType (main.js:4549-4612): terrain-weighted typing.
func _select_war_camp_type(candidate: Dictionary, rng: RandomNumberGenerator) -> String:
	var types: Array[String] = ["orcCamp", "gnollCamp", "trollCamp", "ogreCamp", "banditCamp"]
	var base_weights := {"orcCamp": 1.05, "gnollCamp": 0.95, "trollCamp": 0.85, "ogreCamp": 0.8, "banditCamp": 1.1}
	var dryness := clampf(float(candidate.get("dryness", 0.0)), 0.0, 1.0)
	var water_adjacency := maxi(0, int(candidate.get("water_adjacency", 0)))
	var settlement_distance := float(candidate.get("settlement_distance", INF))
	var weights: Array[float] = []
	var total := 0.0
	for camp_type: String in types:
		var weight := float(base_weights.get(camp_type, 1.0))
		match camp_type:
			"orcCamp":
				if bool(candidate.get("badlands", false)):
					weight += 0.6
				if bool(candidate.get("sand", false)):
					weight += 0.4
			"gnollCamp":
				weight += dryness * 0.6
				if bool(candidate.get("sand", false)):
					weight += 0.5
			"trollCamp":
				if bool(candidate.get("marsh", false)):
					weight += 0.7
				weight += minf(float(water_adjacency) * 0.25, 0.75)
				if bool(candidate.get("snow", false)):
					weight -= 0.3
			"ogreCamp":
				if bool(candidate.get("hill", false)):
					weight += 0.8
				if bool(candidate.get("badlands", false)):
					weight += 0.2
			"banditCamp":
				if bool(candidate.get("grass", false)):
					weight += 0.25
				if settlement_distance < INF:
					weight += clampf(1.0 - absf(settlement_distance - 9.0) / 9.0, 0.0, 1.0) * 0.8
		weight = maxf(0.01, weight)
		weights.append(weight)
		total += weight
	var roll := rng.randf() * total
	for type_index in types.size():
		roll -= weights[type_index]
		if roll <= 0.0:
			return types[type_index]
	return types[0]


## Centaur encampments (browser main.js:26708-26840): grass/badlands/snow
## with grass within 15 tiles, >=7 from settlements, >=8 from hostile camps.
func _place_centaur_encampments(
	field_major: PackedFloat32Array,
	field_hostile: PackedFloat32Array,
	rng: RandomNumberGenerator,
	occupied: Array[Vector2i],
	map_area: int
) -> Array[Vector2i]:
	var w := map_size.x
	var rows := map_size.y
	var base_id := _placement_fields["base_id"] as PackedByteArray
	var hill_id := _placement_fields["hill_id"] as PackedByteArray
	var flags := _placement_fields["flags"] as PackedByteArray
	var blocked := _placement_fields["blocked"] as PackedByteArray
	var canopy := _placement_fields["canopy"] as PackedFloat32Array
	var mountain_id := _biome_to_id(BIOME_MOUNTAIN)
	var hills_id := _biome_to_id(BIOME_HILLS)
	var grass_id := _biome_to_id(BIOME_GRASSLAND)
	var badlands_id := _biome_to_id(BIOME_BADLANDS)
	var centaur_points: Array[Vector2i] = []
	var grass_cells := _placement_fields["grass_cells"] as PackedInt32Array
	if grass_cells.is_empty():
		return centaur_points
	var grass_sources: Array[Vector2i] = []
	for list_index in grass_cells.size():
		var idx := grass_cells[list_index]
		@warning_ignore("integer_division")
		grass_sources.append(Vector2i(idx % w, idx / w))
	var field_grass := _chamfer_distance_field(grass_sources)
	var noise_seed := map_seed + 0x53d1c87b
	var candidates: Array[Dictionary] = []
	for cell_list_variant: Variant in [
		_placement_fields["grass_cells"],
		_placement_fields["badlands_cells"],
		_placement_fields["snow_cells"]
	]:
		var cell_list := cell_list_variant as PackedInt32Array
		for list_index in cell_list.size():
			var idx := cell_list[list_index]
			if blocked[idx] == 1 or (int(flags[idx]) & TILE_OVERLAY_RIVER) != 0:
				continue
			if int(hill_id[idx]) == mountain_id:
				continue
			var distance_to_grass := float(field_grass[idx])
			if distance_to_grass > 15.0:
				continue
			if float(field_major[idx]) < 7.0:
				continue
			if float(field_hostile[idx]) < 8.0:
				continue
			var x := idx % w
			@warning_ignore("integer_division")
			var y := idx / w
			var rainfall := clampf(float(_rainfall_buffer[idx]) if idx < _rainfall_buffer.size() else 0.5, 0.0, 1.0)
			var rainfall_score := clampf(1.0 - absf(rainfall - 0.55) * 1.6, 0.0, 1.0)
			var openness_score := clampf(1.0 - float(canopy[idx]), 0.0, 1.0)
			var grass_proximity := clampf(1.0 - minf(distance_to_grass, 15.0) / 15.0, 0.0, 1.0)
			var cell_base := int(base_id[idx])
			var base_score := 0.43 if cell_base == grass_id else (0.41 if cell_base == badlands_id else 0.38)
			var hill_penalty := 0.12 if int(hill_id[idx]) == hills_id else 0.0
			var noise := _hash_coords(x, y, noise_seed) - 0.5
			var score := base_score + grass_proximity * 0.35 + rainfall_score * 0.25 + openness_score * 0.2 - hill_penalty + noise * 0.18
			if score > 0.3:
				candidates.append({"coord": Vector2i(x, y), "score": score})
	if candidates.is_empty():
		return centaur_points
	candidates = STRUCTURE_PLACER.sort_candidates_by_score(candidates)
	var max_encampments := _structure_placement_limit(maxi(1, int(round(float(map_area) / 15000.0))), 14, 1.0)
	var min_distance_sq := 81.0
	for candidate: Dictionary in candidates:
		if centaur_points.size() >= max_encampments:
			break
		if float(candidate.get("score", 0.0)) < 0.32:
			continue
		var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		if _nearest_distance_sq_points(coord, centaur_points) < min_distance_sq:
			continue
		var idx := coord.y * w + coord.x
		if blocked[idx] == 1:
			continue
		_place_structure_with_details(coord, CENTAUR_ENCAMPMENT_TILE, "centaurEncampment", {
			"region_name": SETTLEMENT_NAMING.camp_name("centaurEncampment", rng),
			"settlement_classification": "Centaur Encampment"
		})
		blocked[idx] = 1
		occupied.append(coord)
		centaur_points.append(coord)
	return centaur_points


## Traveler camps (browser main.js:26842-26974): 4-26 tiles from a
## settlement (sweet spot 10), >=7 from hostile camps, >=8 from centaurs.
func _place_traveler_camps(
	field_major: PackedFloat32Array,
	field_hostile: PackedFloat32Array,
	centaur_points: Array[Vector2i],
	rng: RandomNumberGenerator,
	occupied: Array[Vector2i],
	map_area: int
) -> Array[Vector2i]:
	var w := map_size.x
	var rows := map_size.y
	var base_id := _placement_fields["base_id"] as PackedByteArray
	var hill_id := _placement_fields["hill_id"] as PackedByteArray
	var flags := _placement_fields["flags"] as PackedByteArray
	var blocked := _placement_fields["blocked"] as PackedByteArray
	var moisture_field := _placement_fields["moisture"] as PackedFloat32Array
	var water_id := _biome_to_id(BIOME_WATER)
	var mountain_id := _biome_to_id(BIOME_MOUNTAIN)
	var hills_id := _biome_to_id(BIOME_HILLS)
	var noise_seed := map_seed + 0x579c3d11
	var candidates: Array[Dictionary] = []
	var traveler_points: Array[Vector2i] = []
	for cell_list_variant: Variant in [
		_placement_fields["grass_cells"],
		_placement_fields["sand_cells"],
		_placement_fields["badlands_cells"],
		_placement_fields["marsh_cells"]
	]:
		var cell_list := cell_list_variant as PackedInt32Array
		for list_index in cell_list.size():
			var idx := cell_list[list_index]
			if blocked[idx] == 1 or (int(flags[idx]) & TILE_OVERLAY_RIVER) != 0:
				continue
			if int(hill_id[idx]) == mountain_id:
				continue
			var distance := float(field_major[idx])
			if distance < 4.0 or distance > 26.0:
				continue
			if float(field_hostile[idx]) < 7.0:
				continue
			var x := idx % w
			@warning_ignore("integer_division")
			var y := idx / w
			var coord := Vector2i(x, y)
			if _nearest_distance_sq_points(coord, centaur_points) < 64.0:
				continue
			var water_adjacency := 0
			for definition: Dictionary in RIVER_NEIGHBOR_DEFINITIONS:
				var offset := definition.get("offset", Vector2i.ZERO) as Vector2i
				var nx := x + offset.x
				var ny := y + offset.y
				if nx < 0 or ny < 0 or nx >= w or ny >= rows:
					continue
				var n_idx := ny * w + nx
				if int(base_id[n_idx]) == water_id or (int(flags[n_idx]) & TILE_OVERLAY_RIVER) != 0:
					water_adjacency += 1
			var rainfall := float(_rainfall_buffer[idx]) if idx < _rainfall_buffer.size() else 0.5
			var dryness := clampf(1.0 - rainfall, 0.0, 1.0)
			var soil_softness := clampf(float(moisture_field[idx]), 0.0, 1.0)
			var hill_bonus := 0.08 if int(hill_id[idx]) == hills_id else 0.0
			var distance_score := clampf(1.0 - absf(distance - 10.0) / 9.0, 0.0, 1.0) * 0.32
			var water_score := clampf(float(water_adjacency) * 0.07, 0.0, 0.2)
			var noise := _hash_coords(x, y, noise_seed) - 0.5
			var score := 0.24 + distance_score + hill_bonus + water_score + dryness * 0.18 + soil_softness * 0.12 + noise * 0.18 + rng.randf() * 0.12
			if score > 0.3:
				candidates.append({"coord": coord, "score": score})
	if candidates.is_empty():
		return traveler_points
	candidates = STRUCTURE_PLACER.sort_candidates_by_score(candidates)
	var max_camps := _structure_placement_limit(maxi(1, int(round(float(map_area) / 20000.0))), 14, 1.0)
	var min_distance_sq := 49.0
	for candidate: Dictionary in candidates:
		if traveler_points.size() >= max_camps:
			break
		if float(candidate.get("score", 0.0)) < 0.31:
			continue
		var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		if _nearest_distance_sq_points(coord, traveler_points) < min_distance_sq:
			continue
		var idx := coord.y * w + coord.x
		if blocked[idx] == 1:
			continue
		_place_structure_with_details(coord, TRAVELERS_CAMP_TILE, "travelerCamp", {
			"region_name": SETTLEMENT_NAMING.camp_name("travelerCamp", rng),
			"settlement_classification": "Traveler Camp"
		})
		blocked[idx] = 1
		occupied.append(coord)
		traveler_points.append(coord)
	return traveler_points


## Goblin caves (browser main.js:25433-25553): grass/snow foothills (hill
## overlay or mountain-adjacent), never on mountain overlay tiles, slope and
## elevation scored, density area/9000.
func _place_goblin_caves(rng: RandomNumberGenerator, occupied: Array[Vector2i], map_area: int) -> void:
	var w := map_size.x
	var rows := map_size.y
	var base_id := _placement_fields["base_id"] as PackedByteArray
	var hill_id := _placement_fields["hill_id"] as PackedByteArray
	var flags := _placement_fields["flags"] as PackedByteArray
	var blocked := _placement_fields["blocked"] as PackedByteArray
	var height_field := _placement_fields["height"] as PackedFloat32Array
	var water_id := _biome_to_id(BIOME_WATER)
	var mountain_id := _biome_to_id(BIOME_MOUNTAIN)
	var hills_id := _biome_to_id(BIOME_HILLS)
	var noise_seed := map_seed + 0x21f0e1eb
	var candidates: Array[Dictionary] = []
	for cell_list_variant: Variant in [_placement_fields["grass_cells"], _placement_fields["snow_cells"]]:
		var cell_list := cell_list_variant as PackedInt32Array
		for list_index in cell_list.size():
			var idx := cell_list[list_index]
			if blocked[idx] == 1 or (int(flags[idx]) & TILE_OVERLAY_RIVER) != 0:
				continue
			# Tree overlays block caves; hill overlays are the sweet spot and
			# mountain overlays are forbidden outright.
			if (int(flags[idx]) & (TILE_OVERLAY_TREE | TILE_OVERLAY_FOREST)) != 0:
				continue
			if int(hill_id[idx]) == mountain_id:
				continue
			var overlay_is_hill: bool = int(hill_id[idx]) == hills_id
			var x := idx % w
			@warning_ignore("integer_division")
			var y := idx / w
			var height_value := float(height_field[idx])
			var slope_sum := 0.0
			var neighbor_count := 0
			var mountain_neighbors := 0
			for offset: Vector2i in NEIGHBOR_OFFSETS_8:
				var nx := x + offset.x
				var ny := y + offset.y
				if nx < 0 or ny < 0 or nx >= w or ny >= rows:
					continue
				var n_idx := ny * w + nx
				if int(base_id[n_idx]) == water_id:
					continue
				slope_sum += absf(height_value - float(height_field[n_idx]))
				neighbor_count += 1
				if int(hill_id[n_idx]) == mountain_id or int(base_id[n_idx]) == mountain_id:
					mountain_neighbors += 1
			var average_slope := (slope_sum / float(neighbor_count)) if neighbor_count > 0 else 0.0
			var slope_score := clampf((average_slope - 0.009) * 36.0, 0.0, 1.0)
			var hill_bonus := 0.35 if overlay_is_hill else 0.0
			var mountain_bonus := minf(0.25, float(mountain_neighbors) * 0.08)
			var elevation_score := clampf((height_value - water_level) * 1.9, 0.0, 1.0)
			var noise := _hash_coords(x, y, noise_seed) - 0.5
			var composite := hill_bonus + slope_score * 0.45 + mountain_bonus + elevation_score * 0.2 + noise * 0.15
			if composite > 0.22:
				candidates.append({"coord": Vector2i(x, y), "score": composite, "hill": overlay_is_hill})
	if candidates.is_empty():
		return
	candidates = STRUCTURE_PLACER.sort_candidates_by_score(candidates)
	var max_caves := _structure_placement_limit(maxi(1, int(round(float(map_area) / 9000.0))), 22, 1.0)
	var min_distance := 6.0
	var placed: Array[Vector2i] = []
	for candidate: Dictionary in candidates:
		if placed.size() >= max_caves:
			break
		if float(candidate.get("score", 0.0)) < 0.28:
			continue
		var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		var required_distance := maxf(3.0, min_distance - 1.0) if bool(candidate.get("hill", false)) else min_distance
		if _nearest_distance_sq_points(coord, placed) < required_distance * required_distance:
			continue
		var idx := coord.y * w + coord.x
		if blocked[idx] == 1:
			continue
		_place_structure_with_details(coord, CAVE_TILE, "cave", {
			"region_name": SETTLEMENT_NAMING.goblin_cave_name(rng),
			"settlement_classification": "Goblin Cave",
			"population": maxi(28, int(40.0 + rng.randf() * 180.0))
		})
		blocked[idx] = 1
		occupied.append(coord)
		placed.append(coord)


## Dungeons keep their pre-existing dryness-scored placement, driven off
## the flat buffers.
func _place_dungeons(rng: RandomNumberGenerator, occupied: Array[Vector2i], map_area: int) -> void:
	var w := map_size.x
	var flags := _placement_fields["flags"] as PackedByteArray
	var hill_id := _placement_fields["hill_id"] as PackedByteArray
	var blocked := _placement_fields["blocked"] as PackedByteArray
	var moisture_field := _placement_fields["moisture"] as PackedFloat32Array
	var base_id := _placement_fields["base_id"] as PackedByteArray
	var mountain_id := _biome_to_id(BIOME_MOUNTAIN)
	var badlands_id := _biome_to_id(BIOME_BADLANDS)
	var candidates: Array[Dictionary] = []
	for cell_list_variant: Variant in [
		_placement_fields["grass_cells"],
		_placement_fields["snow_cells"],
		_placement_fields["sand_cells"],
		_placement_fields["marsh_cells"],
		_placement_fields["badlands_cells"]
	]:
		var cell_list := cell_list_variant as PackedInt32Array
		for list_index in cell_list.size():
			var idx := cell_list[list_index]
			if blocked[idx] == 1 or (int(flags[idx]) & TILE_OVERLAY_RIVER) != 0:
				continue
			if int(hill_id[idx]) == mountain_id:
				continue
			var dryness := clampf(1.0 - float(moisture_field[idx]), 0.0, 1.0)
			var score := dryness * 0.45 + rng.randf_range(0.0, 0.35)
			if int(base_id[idx]) == badlands_id:
				score += 0.12
			if score > 0.32:
				@warning_ignore("integer_division")
				candidates.append({"coord": Vector2i(idx % w, idx / w), "score": score})
	candidates = STRUCTURE_PLACER.sort_candidates_by_score(candidates)
	var max_dungeons := maxi(1, int(round(float(map_area) / 22000.0)))
	var placed := 0
	for candidate: Dictionary in candidates:
		if placed >= max_dungeons:
			break
		var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		if _is_too_close(coord, occupied, 9.0):
			continue
		var idx := coord.y * w + coord.x
		if blocked[idx] == 1:
			continue
		_place_structure_with_details(coord, DUNGEON_TILE, "dungeon", {
			"region_name": SETTLEMENT_NAMING.dungeon_name(rng),
			"settlement_classification": "Dungeon"
		})
		blocked[idx] = 1
		occupied.append(coord)
		placed += 1


func _place_mines_hillholds_and_dams(
	height_map: Dictionary,
	rng: RandomNumberGenerator,
	occupied: Array[Vector2i],
	map_area: int
) -> void:
	var w := map_size.x
	var rows := map_size.y
	var cell_count := w * rows
	var base_id := _placement_fields["base_id"] as PackedByteArray
	var hill_id := _placement_fields["hill_id"] as PackedByteArray
	var flags := _placement_fields["flags"] as PackedByteArray
	var blocked := _placement_fields["blocked"] as PackedByteArray
	var height_field := _placement_fields["height"] as PackedFloat32Array
	var mountain_id := _biome_to_id(BIOME_MOUNTAIN)
	var hills_id := _biome_to_id(BIOME_HILLS)
	var have_scores := _mountain_score_buffer.size() == cell_count
	# Mines (browser main.js:24179-24270): mountain-overlay tiles with ridge
	# score >= 0.18, spacing 3, and >= 3 tiles from any dwarfhold.
	var mine_candidates: Array[Dictionary] = []
	var hill_candidates: Array[Dictionary] = []
	for idx in range(cell_count):
		if blocked[idx] == 1 or (int(flags[idx]) & TILE_OVERLAY_RIVER) != 0:
			continue
		var is_mountain: bool = int(hill_id[idx]) == mountain_id or int(base_id[idx]) == mountain_id
		var x := idx % w
		@warning_ignore("integer_division")
		var y := idx / w
		if is_mountain:
			var score := float(_mountain_score_buffer[idx]) if have_scores else float(height_field[idx])
			if score >= 0.18:
				mine_candidates.append({"coord": Vector2i(x, y), "score": score})
		elif int(hill_id[idx]) == hills_id:
			hill_candidates.append({"coord": Vector2i(x, y), "score": float(height_field[idx]) + rng.randf() * 0.1})
	mine_candidates = STRUCTURE_PLACER.sort_candidates_by_score(mine_candidates)
	hill_candidates = STRUCTURE_PLACER.sort_candidates_by_score(hill_candidates)

	var dwarf_frequency := _settlement_frequency_normalized("dwarves")
	var max_mines := _structure_placement_limit(maxi(1, int(round(float(mine_candidates.size()) / 420.0))), 28, _frequency_multiplier(dwarf_frequency))
	var mine_spacing := _adjusted_min_distance(3.0, dwarf_frequency)
	var mine_spacing_sq := float(mine_spacing * mine_spacing)
	var placed_mines: Array[Vector2i] = []
	for candidate: Dictionary in mine_candidates:
		if placed_mines.size() >= max_mines:
			break
		var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		var idx := coord.y * w + coord.x
		if blocked[idx] == 1:
			continue
		if _nearest_distance_sq_points(coord, placed_mines) < mine_spacing_sq:
			continue
		if _nearest_distance_sq_points(coord, _dwarfhold_points) < 9.0:
			continue
		if _is_within_tiles_of_volcano(coord, 0):
			continue
		_place_structure_with_details(coord, MINE_TILE, "mine", {
			"region_name": SETTLEMENT_NAMING.mine_name(rng),
			"settlement_classification": "Mine"
		})
		blocked[idx] = 1
		occupied.append(coord)
		placed_mines.append(coord)
	if placed_mines.is_empty():
		for candidate: Dictionary in mine_candidates:
			var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
			var idx := coord.y * w + coord.x
			if blocked[idx] == 1 or _is_within_tiles_of_volcano(coord, 0):
				continue
			_place_structure_with_details(coord, MINE_TILE, "mine", {
				"region_name": SETTLEMENT_NAMING.mine_name(rng),
				"settlement_classification": "Mine"
			})
			blocked[idx] = 1
			occupied.append(coord)
			placed_mines.append(coord)
			break

	var max_hillholds := maxi(1, int(round(float(map_area) / 32000.0)))
	for candidate: Dictionary in hill_candidates:
		if max_hillholds <= 0:
			break
		var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		if _is_too_close(coord, occupied, 10.0):
			continue
		var idx := coord.y * w + coord.x
		if blocked[idx] == 1:
			continue
		_place_structure_with_details(coord, HILLHOLD_TILE, "hillhold", {
			"region_name": SETTLEMENT_NAMING.hillhold_name(rng),
			"settlement_classification": "Hillhold"
		})
		blocked[idx] = 1
		occupied.append(coord)
		_hillhold_points.append(coord)
		max_hillholds -= 1

	var max_dams := maxi(1, int(round(float(map_area) / 52000.0)))
	if max_dams > 0 and not _dwarfhold_points.is_empty():
		# Browser rule: dams are dwarven engineering. They sit on RIVER
		# tiles pinched between mountains, within 10 tiles of a dwarfhold,
		# and even then only some sites (35%) get dammed.
		for y in range(1, rows - 1):
			for x in range(1, w - 1):
				if max_dams <= 0:
					break
				var idx := y * w + x
				if blocked[idx] == 1:
					continue
				if (int(flags[idx]) & TILE_OVERLAY_RIVER) == 0:
					continue
				var west_mountain: bool = int(hill_id[idx - 1]) == mountain_id
				var east_mountain: bool = int(hill_id[idx + 1]) == mountain_id
				var north_mountain: bool = int(hill_id[idx - w]) == mountain_id
				var south_mountain: bool = int(hill_id[idx + w]) == mountain_id
				var pinched := (west_mountain and east_mountain) or (north_mountain and south_mountain)
				if not pinched:
					continue
				var coord := Vector2i(x, y)
				if _nearest_distance_sq_points(coord, _dwarfhold_points) > 100.0:
					continue
				if rng.randf() >= 0.35:
					continue
				_place_structure_with_details(coord, DAM_TILE, "dam", {"region_name": "Dam"})
				blocked[idx] = 1
				occupied.append(coord)
				max_dams -= 1


## Roadside taverns (browser main.js:26976-27110): grass/sand/badlands,
## 3-20 tiles from a civil settlement with the score peaking at 8.
func _place_roadside_taverns(
	field_civil: PackedFloat32Array,
	field_hostile: PackedFloat32Array,
	centaur_points: Array[Vector2i],
	traveler_points: Array[Vector2i],
	rng: RandomNumberGenerator,
	occupied: Array[Vector2i],
	map_area: int
) -> void:
	var w := map_size.x
	var rows := map_size.y
	var base_id := _placement_fields["base_id"] as PackedByteArray
	var hill_id := _placement_fields["hill_id"] as PackedByteArray
	var flags := _placement_fields["flags"] as PackedByteArray
	var blocked := _placement_fields["blocked"] as PackedByteArray
	var moisture_field := _placement_fields["moisture"] as PackedFloat32Array
	var water_id := _biome_to_id(BIOME_WATER)
	var mountain_id := _biome_to_id(BIOME_MOUNTAIN)
	var noise_seed := map_seed + 0x9324f8b1
	var candidates: Array[Dictionary] = []
	for cell_list_variant: Variant in [
		_placement_fields["grass_cells"],
		_placement_fields["sand_cells"],
		_placement_fields["badlands_cells"]
	]:
		var cell_list := cell_list_variant as PackedInt32Array
		for list_index in cell_list.size():
			var idx := cell_list[list_index]
			if blocked[idx] == 1 or (int(flags[idx]) & TILE_OVERLAY_RIVER) != 0:
				continue
			if int(hill_id[idx]) == mountain_id:
				continue
			var distance := float(field_civil[idx])
			if distance < 3.0 or distance > 20.0:
				continue
			var x := idx % w
			@warning_ignore("integer_division")
			var y := idx / w
			var river_adjacency := 0
			for offset: Vector2i in NEIGHBOR_OFFSETS_8:
				var nx := x + offset.x
				var ny := y + offset.y
				if nx < 0 or ny < 0 or nx >= w or ny >= rows:
					continue
				var n_idx := ny * w + nx
				if int(base_id[n_idx]) == water_id or (int(flags[n_idx]) & TILE_OVERLAY_RIVER) != 0:
					river_adjacency += 1
			var rainfall := float(_rainfall_buffer[idx]) if idx < _rainfall_buffer.size() else 0.5
			var fertility := clampf(rainfall * 0.6 + float(moisture_field[idx]) * 0.4, 0.0, 1.0)
			var distance_score := clampf(1.0 - absf(distance - 8.0) / 6.5, 0.0, 1.0) * 0.36
			var river_score := clampf(float(river_adjacency) * 0.09, 0.0, 0.24)
			var noise := _hash_coords(x, y, noise_seed) - 0.5
			var score := 0.26 + distance_score + river_score + fertility * 0.18 + noise * 0.18 + rng.randf() * 0.1
			if score > 0.24:
				candidates.append({"coord": Vector2i(x, y), "score": score})
	if candidates.is_empty():
		return
	candidates = STRUCTURE_PLACER.sort_candidates_by_score(candidates)
	var max_taverns := _structure_placement_limit(maxi(1, int(round(float(map_area) / 18000.0))), 12, 1.0)
	var min_distance_sq := 16.0
	var placed: Array[Vector2i] = []
	for candidate: Dictionary in candidates:
		if placed.size() >= max_taverns:
			break
		if float(candidate.get("score", 0.0)) < 0.26:
			continue
		var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		if _nearest_distance_sq_points(coord, placed) < min_distance_sq:
			continue
		if _nearest_distance_sq_points(coord, traveler_points) < 25.0:
			continue
		if _nearest_distance_sq_points(coord, centaur_points) < 49.0:
			continue
		var idx := coord.y * w + coord.x
		if blocked[idx] == 1 or float(field_hostile[idx]) < 8.0:
			continue
		_place_structure_with_details(coord, ROADSIDE_TAVERN_TILE, "roadsideTavern", {
			"region_name": SETTLEMENT_NAMING.tavern_name(rng),
			"settlement_classification": "Roadside Tavern"
		})
		blocked[idx] = 1
		occupied.append(coord)
		placed.append(coord)


## Monasteries (browser main.js:27269-27406): grass/marsh (never snow or
## mountain), 4-46 tiles from a town or hold, river adjacency bonus,
## spacing 11, cap area/24000.
func _place_monasteries(
	field_major: PackedFloat32Array,
	field_hostile: PackedFloat32Array,
	centaur_points: Array[Vector2i],
	rng: RandomNumberGenerator,
	occupied: Array[Vector2i],
	map_area: int
) -> Array[Vector2i]:
	var w := map_size.x
	var rows := map_size.y
	var base_id := _placement_fields["base_id"] as PackedByteArray
	var hill_id := _placement_fields["hill_id"] as PackedByteArray
	var flags := _placement_fields["flags"] as PackedByteArray
	var blocked := _placement_fields["blocked"] as PackedByteArray
	var height_field := _placement_fields["height"] as PackedFloat32Array
	var mountain_id := _biome_to_id(BIOME_MOUNTAIN)
	var hills_id := _biome_to_id(BIOME_HILLS)
	var grass_id := _biome_to_id(BIOME_GRASSLAND)
	var noise_seed := map_seed + 0x6f12c43d
	var latitude_seed := map_seed + 0x71c2d9a7
	var candidates: Array[Dictionary] = []
	var monastery_points: Array[Vector2i] = []
	for cell_list_variant: Variant in [_placement_fields["grass_cells"], _placement_fields["marsh_cells"]]:
		var cell_list := cell_list_variant as PackedInt32Array
		for list_index in cell_list.size():
			var idx := cell_list[list_index]
			if blocked[idx] == 1 or (int(flags[idx]) & TILE_OVERLAY_RIVER) != 0:
				continue
			if int(hill_id[idx]) == mountain_id:
				continue
			var settlement_distance := float(field_major[idx])
			if settlement_distance < 4.0 or settlement_distance > 46.0:
				continue
			if float(field_hostile[idx]) < 7.0:
				continue
			var x := idx % w
			@warning_ignore("integer_division")
			var y := idx / w
			var coord := Vector2i(x, y)
			if _nearest_distance_sq_points(coord, centaur_points) < 64.0:
				continue
			var river_adjacency := 0
			for definition: Dictionary in RIVER_NEIGHBOR_DEFINITIONS:
				var offset := definition.get("offset", Vector2i.ZERO) as Vector2i
				var nx := x + offset.x
				var ny := y + offset.y
				if nx < 0 or ny < 0 or nx >= w or ny >= rows:
					continue
				if int(flags[ny * w + nx]) & TILE_OVERLAY_RIVER:
					river_adjacency += 1
			var hill_bonus := 0.18 if int(hill_id[idx]) == hills_id else 0.0
			var river_score := clampf(0.18 + float(river_adjacency) * 0.08, 0.0, 0.3) if river_adjacency > 0 else 0.0
			var distance_score := clampf((settlement_distance - 4.0) / 18.0, 0.0, 1.0) * 0.22
			var elevation_score := clampf((float(height_field[idx]) - water_level) * 2.0, 0.0, 1.0) * 0.18
			var base_suitability := 0.18 if int(base_id[idx]) == grass_id else 0.08
			var latitude := (float(y) + 0.5) / float(rows)
			var latitude_noise := _hash_coords(x, int(latitude * 1024.0), latitude_seed) - 0.5
			var latitude_score := absf(sin((latitude + latitude_noise * 0.35) * PI * 2.0)) * 0.14
			var noise := _hash_coords(x, y, noise_seed) - 0.5
			var score := 0.28 + hill_bonus + river_score + distance_score + elevation_score + base_suitability + latitude_score + noise * 0.2 + rng.randf() * 0.12
			candidates.append({"coord": coord, "score": score})
	if candidates.is_empty():
		return monastery_points
	candidates = STRUCTURE_PLACER.sort_candidates_by_score(candidates)
	var max_monasteries := _structure_placement_limit(maxi(1, int(round(float(map_area) / 24000.0))), 12, 1.0)
	var min_distance_sq := 121.0
	for candidate: Dictionary in candidates:
		if monastery_points.size() >= max_monasteries:
			break
		if float(candidate.get("score", 0.0)) < 0.32:
			continue
		var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		if _nearest_distance_sq_points(coord, monastery_points) < min_distance_sq:
			continue
		if _is_mountain_tile(coord):
			continue
		var idx := coord.y * w + coord.x
		if blocked[idx] == 1:
			continue
		_place_structure_with_details(coord, MONASTERY_TILE, "monastery", {
			"region_name": SETTLEMENT_NAMING.monastery_name(rng),
			"settlement_classification": "Monastery"
		})
		blocked[idx] = 1
		occupied.append(coord)
		monastery_points.append(coord)
	return monastery_points


## Castles (browser main.js:27407-27520): no longer a random town skin -
## a scored structure pass on grass/snow with a hills bonus, >=6 tiles from
## settlements, score > 0.34, spacing 12, cap area/26000 (max 10).
func _place_castles(
	field_major: PackedFloat32Array,
	rng: RandomNumberGenerator,
	occupied: Array[Vector2i],
	map_area: int
) -> void:
	var w := map_size.x
	var rows := map_size.y
	var base_id := _placement_fields["base_id"] as PackedByteArray
	var hill_id := _placement_fields["hill_id"] as PackedByteArray
	var flags := _placement_fields["flags"] as PackedByteArray
	var blocked := _placement_fields["blocked"] as PackedByteArray
	var height_field := _placement_fields["height"] as PackedFloat32Array
	var water_id := _biome_to_id(BIOME_WATER)
	var mountain_id := _biome_to_id(BIOME_MOUNTAIN)
	var hills_id := _biome_to_id(BIOME_HILLS)
	var noise_seed := map_seed + 0x7be21a59
	var edge_divisor := maxf(8.0, float(mini(w, rows)) / 2.6)
	var overlay_block := TILE_OVERLAY_TREE | TILE_OVERLAY_FOREST | TILE_OVERLAY_RIVER
	var candidates: Array[Dictionary] = []
	for cell_list_variant: Variant in [_placement_fields["grass_cells"], _placement_fields["snow_cells"]]:
		var cell_list := cell_list_variant as PackedInt32Array
		for list_index in cell_list.size():
			var idx := cell_list[list_index]
			if blocked[idx] == 1 or (int(flags[idx]) & overlay_block) != 0:
				continue
			if int(hill_id[idx]) == mountain_id:
				continue
			var settlement_distance := float(field_major[idx])
			if settlement_distance >= 1.0e8 or settlement_distance < 6.0:
				continue
			var x := idx % w
			@warning_ignore("integer_division")
			var y := idx / w
			var hill_bonus := 0.24 if int(hill_id[idx]) == hills_id else 0.0
			var edge_distance := mini(mini(x, w - 1 - x), mini(y, rows - 1 - y))
			var edge_score := clampf(float(edge_distance) / edge_divisor, 0.0, 1.0) * 0.18
			var height_value := float(height_field[idx])
			var slope_sum := 0.0
			var neighbor_count := 0
			for offset: Vector2i in NEIGHBOR_OFFSETS_8:
				var nx := x + offset.x
				var ny := y + offset.y
				if nx < 0 or ny < 0 or nx >= w or ny >= rows:
					continue
				var n_idx := ny * w + nx
				if int(base_id[n_idx]) == water_id:
					continue
				slope_sum += absf(height_value - float(height_field[n_idx]))
				neighbor_count += 1
			var average_slope := (slope_sum / float(neighbor_count)) if neighbor_count > 0 else 0.0
			var slope_score := clampf(average_slope * 42.0, 0.0, 0.35)
			var settlement_score := clampf((settlement_distance - 6.0) / 20.0, 0.0, 1.0) * 0.28
			var noise := _hash_coords(x, y, noise_seed) - 0.5
			var score := hill_bonus + edge_score + slope_score + settlement_score + noise * 0.22 + rng.randf() * 0.12
			if score > 0.32:
				candidates.append({"coord": Vector2i(x, y), "score": score})
	if candidates.is_empty():
		return
	candidates = STRUCTURE_PLACER.sort_candidates_by_score(candidates)
	var max_castles := _structure_placement_limit(maxi(1, int(round(float(map_area) / 26000.0))), 10, 1.0)
	var min_distance_sq := 144.0
	var placed: Array[Vector2i] = []
	for candidate: Dictionary in candidates:
		if placed.size() >= max_castles:
			break
		if float(candidate.get("score", 0.0)) < 0.34:
			continue
		var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		if _nearest_distance_sq_points(coord, placed) < min_distance_sq:
			continue
		if _is_mountain_tile(coord):
			continue
		var idx := coord.y * w + coord.x
		if blocked[idx] == 1:
			continue
		_place_structure_with_details(coord, CASTLE_TILE, "castle", {
			"region_name": SETTLEMENT_NAMING.castle_name(rng),
			"settlement_classification": "Castle"
		})
		blocked[idx] = 1
		occupied.append(coord)
		placed.append(coord)


## Saint shrines (browser main.js:27524-27655): need a water/river
## 8-neighbor AND a monastery 5-40 tiles away, >=5 from major settlements.
func _place_saint_shrines(
	field_major: PackedFloat32Array,
	field_monastery: PackedFloat32Array,
	rng: RandomNumberGenerator,
	occupied: Array[Vector2i],
	map_area: int
) -> void:
	var w := map_size.x
	var rows := map_size.y
	var base_id := _placement_fields["base_id"] as PackedByteArray
	var hill_id := _placement_fields["hill_id"] as PackedByteArray
	var flags := _placement_fields["flags"] as PackedByteArray
	var blocked := _placement_fields["blocked"] as PackedByteArray
	var moisture_field := _placement_fields["moisture"] as PackedFloat32Array
	var water_id := _biome_to_id(BIOME_WATER)
	var mountain_id := _biome_to_id(BIOME_MOUNTAIN)
	var hills_id := _biome_to_id(BIOME_HILLS)
	var grass_id := _biome_to_id(BIOME_GRASSLAND)
	var snow_id := _biome_to_id(BIOME_TUNDRA)
	var noise_seed := map_seed + 0x8cf43123
	var latitude_seed := map_seed + 0x90a2f4c1
	var candidates: Array[Dictionary] = []
	for cell_list_variant: Variant in [
		_placement_fields["grass_cells"],
		_placement_fields["snow_cells"],
		_placement_fields["marsh_cells"]
	]:
		var cell_list := cell_list_variant as PackedInt32Array
		for list_index in cell_list.size():
			var idx := cell_list[list_index]
			if blocked[idx] == 1 or (int(flags[idx]) & TILE_OVERLAY_RIVER) != 0:
				continue
			if int(hill_id[idx]) == mountain_id:
				continue
			var monastery_distance := float(field_monastery[idx])
			if monastery_distance < 5.0 or monastery_distance > 40.0:
				continue
			if float(field_major[idx]) < 5.0:
				continue
			var x := idx % w
			@warning_ignore("integer_division")
			var y := idx / w
			var water_adjacency := 0
			for offset: Vector2i in NEIGHBOR_OFFSETS_8:
				var nx := x + offset.x
				var ny := y + offset.y
				if nx < 0 or ny < 0 or nx >= w or ny >= rows:
					continue
				var n_idx := ny * w + nx
				if int(base_id[n_idx]) == water_id or (int(flags[n_idx]) & TILE_OVERLAY_RIVER) != 0:
					water_adjacency += 1
			if water_adjacency == 0:
				continue
			var rainfall := float(_rainfall_buffer[idx]) if idx < _rainfall_buffer.size() else 0.5
			var moisture := clampf(rainfall * 0.6 + float(moisture_field[idx]) * 0.4, 0.0, 1.0)
			var moisture_score := clampf(moisture * 0.4, 0.0, 0.28)
			var hill_bonus := 0.12 if int(hill_id[idx]) == hills_id else 0.0
			var devotion_score := clampf((monastery_distance - 5.0) / 18.0, 0.0, 1.0) * 0.22
			var cell_base := int(base_id[idx])
			var base_suitability := 0.16 if cell_base == grass_id else (0.12 if cell_base == snow_id else 0.1)
			var latitude := (float(y) + 0.5) / float(rows)
			var latitude_noise := _hash_coords(x, int(latitude * 1024.0), latitude_seed) - 0.5
			var latitude_score := absf(sin((latitude + latitude_noise * 0.3) * PI * 2.0)) * 0.12
			var noise := _hash_coords(x, y, noise_seed) - 0.5
			var score := 0.25 + moisture_score + hill_bonus + devotion_score + float(water_adjacency) * 0.05 + base_suitability + latitude_score + noise * 0.22 + rng.randf() * 0.12
			candidates.append({"coord": Vector2i(x, y), "score": score})
	if candidates.is_empty():
		return
	candidates = STRUCTURE_PLACER.sort_candidates_by_score(candidates)
	var max_shrines := _structure_placement_limit(maxi(1, int(round(float(map_area) / 24000.0))), 14, 1.0)
	var min_distance_sq := 81.0
	var placed: Array[Vector2i] = []
	for candidate: Dictionary in candidates:
		if placed.size() >= max_shrines:
			break
		if float(candidate.get("score", 0.0)) < 0.3:
			continue
		var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		if _nearest_distance_sq_points(coord, placed) < min_distance_sq:
			continue
		if _is_mountain_tile(coord):
			continue
		var idx := coord.y * w + coord.x
		if blocked[idx] == 1:
			continue
		_place_structure_with_details(coord, SAINT_SHRINE_TILE, "saintShrine", {
			"region_name": SETTLEMENT_NAMING.saint_shrine_name(rng),
			"settlement_classification": "Saint Shrine"
		})
		blocked[idx] = 1
		occupied.append(coord)
		placed.append(coord)


func _place_scored_structure_batch(
	candidates: Array[Dictionary],
	occupied: Array[Vector2i],
	min_distance: float,
	max_count: int,
	min_score: float,
	tile: Vector2i,
	structure_id: String,
	rng: RandomNumberGenerator
) -> void:
	var placed := 0
	for candidate: Dictionary in candidates:
		if placed >= max_count:
			break
		if float(candidate.get("score", 0.0)) < min_score:
			continue
		var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		if _is_too_close(coord, occupied, min_distance):
			continue
		var region_name := SETTLEMENT_NAMING.structure_name(structure_id, rng)
		if region_name.is_empty():
			region_name = structure_id.capitalize()
		_place_structure_with_details(coord, tile, structure_id, {
			"region_name": region_name,
			"settlement_classification": structure_id.capitalize()
		})
		occupied.append(coord)
		placed += 1


func _place_structure_with_details(coord: Vector2i, tile: Vector2i, structure_id: String, extra: Dictionary = {}) -> void:
	if settlement_layer != null:
		settlement_layer.set_cell(coord, _atlas_source_id, tile)
	else:
		map_layer.set_cell(coord, _atlas_source_id, tile)
	var tile_info := _tile_data.get(coord, {}) as Dictionary
	tile_info["structure"] = structure_id
	for key_variant: Variant in extra.keys():
		var key := String(key_variant)
		var value: Variant = extra.get(key_variant)
		if key == "region_name":
			var region_label := String(value).strip_edges()
			if not region_label.is_empty():
				_tile_region_names[coord] = region_label
			continue
		if key == "major_population_groups" or key == "minor_population_groups":
			var existing := _tile_population_groups_for_coord(coord)
			existing[key] = value
			_tile_population_groups[coord] = existing
			continue
		tile_info[key_variant] = value
	_tile_data[coord] = tile_info



func _founded_years_ago_for_settlement_type(settlement_type: String, rng: RandomNumberGenerator) -> int:
	match settlement_type:
		"town":
			return rng.randi_range(40, 900)
		"woodElfGrove":
			return rng.randi_range(120, 2200)
		"lizardmenCity":
			return rng.randi_range(180, 2600)
		_:
			return rng.randi_range(30, 600)

func _population_options_for_settlement_type(settlement_type: String) -> Array:
	match settlement_type:
		"town":
			return TOWN_POPULATION_RACE_OPTIONS
		"woodElfGrove":
			return WOOD_ELF_GROVE_POPULATION_ROLE_OPTIONS
		"lizardmenCity":
			return LIZARDMEN_CITY_POPULATION_ROLE_OPTIONS
		_:
			return []

func _roll_population_for_settlement_type(settlement_type: String, rng: RandomNumberGenerator) -> int:
	match settlement_type:
		"town":
			return rng.randi_range(450, 6200)
		"woodElfGrove":
			return rng.randi_range(240, 2800)
		"lizardmenCity":
			return rng.randi_range(900, 5400)
		_:
			return 0

func _generate_population_breakdown_from_options(
	options: Array,
	population: int,
	rng: RandomNumberGenerator,
	majority_key: String = ""
) -> Array[Dictionary]:
	if options.is_empty() or population <= 0:
		return []

	var resolved_majority_key := majority_key
	if resolved_majority_key.is_empty():
		resolved_majority_key = String((options[0] as Dictionary).get("key", ""))
	var majority_index := -1
	for index in range(options.size()):
		if String((options[index] as Dictionary).get("key", "")) == resolved_majority_key:
			majority_index = index
			break
	if majority_index < 0:
		majority_index = 0

	var shares: Array[float] = []
	shares.resize(options.size())
	for index in range(options.size()):
		shares[index] = 0.0

	var majority_share := 1.0
	if options.size() > 1:
		majority_share = rng.randf_range(0.55, 0.8)
	shares[majority_index] = majority_share

	var remainder_share := maxf(0.0, 1.0 - majority_share)
	if options.size() > 1 and remainder_share > 0.0:
		var remainder_weights: Array[float] = []
		remainder_weights.resize(options.size())
		var total_remainder_weight := 0.0
		for index in range(options.size()):
			if index == majority_index:
				remainder_weights[index] = 0.0
				continue
			var weight := rng.randf_range(0.25, 1.4)
			remainder_weights[index] = weight
			total_remainder_weight += weight
		if total_remainder_weight <= 0.0:
			var split := remainder_share / float(options.size() - 1)
			for index in range(options.size()):
				if index == majority_index:
					continue
				shares[index] = split
		else:
			for index in range(options.size()):
				if index == majority_index:
					continue
				shares[index] = remainder_share * (remainder_weights[index] / total_remainder_weight)

	var remaining := maxi(population, 0)
	var results: Array[Dictionary] = []
	for index in range(options.size()):
		var entry: Dictionary = options[index]
		var share := clampf(shares[index], 0.0, 1.0)
		var count := int(round(float(population) * share))
		if index == options.size() - 1:
			count = maxi(0, remaining)
		remaining -= count
		results.append({
			"key": String(entry.get("key", "")),
			"label": String(entry.get("label", "")),
			"color": entry.get("color", Color.GRAY),
			"percentage": share * 100.0,
			"population": maxi(0, count)
		})

	results.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(b.get("population", 0)) < int(a.get("population", 0))
	)
	return results

func _labels_from_population_breakdown(population_breakdown: Array) -> Dictionary:
	var major: Array[String] = []
	var minor: Array[String] = []
	for entry: Dictionary in population_breakdown:
		var label := String(entry.get("label", "")).strip_edges()
		if label.is_empty():
			continue
		if major.size() < 2:
			major.append(label)
		elif minor.size() < 4:
			minor.append(label)
	return {
		"major": major,
		"minor": minor
	}

func _assign_cultural_groups(
	biome_map: Dictionary,
	temperature_map: Dictionary,
	moisture_map: Dictionary,
	height_map: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var pipeline := CulturalInfluence.new()
	var settlements := _collect_settlement_sources()
	var factions := _collect_faction_sources()
	var wood_elf_territory_info := _resolve_wood_elf_territory()
	pipeline.apply_cultural_influence(
		map_size.x,
		map_size.y,
		_tile_data,
		settlements,
		factions,
		func(_coord: Vector2i, tile_data: Dictionary) -> bool:
			var base := _tile_base_biome_from_data(tile_data)
			return base != BIOME_WATER,
		map_seed,
		wood_elf_territory_info
	)
	var ambient_started := Time.get_ticks_msec()
	pipeline.spawn_ambient_structures(
		map_size.x,
		map_size.y,
		_tile_data,
		func(_coord: Vector2i, tile_data: Dictionary) -> bool:
			var base := _tile_base_biome_from_data(tile_data)
			return base != BIOME_WATER,
		map_seed,
		CultureTypes.AMBIENT_STRUCTURE_OPTIONS_BY_CULTURE
	)
	print("[CulturalInfluence] ambient structure spawn %d ms" % (Time.get_ticks_msec() - ambient_started))
	for coord: Vector2i in _tile_data.keys():
		var tile_info := _tile_data.get(coord, {}) as Dictionary
		if tile_info.is_empty():
			continue
		# Read the resolved influence directly - building full tooltip
		# dictionaries for all 65k tiles doubled this stage's cost.
		var influence_value: Variant = tile_info.get("cultural_influence")
		if influence_value is Dictionary and not (influence_value as Dictionary).is_empty():
			var influence := influence_value as Dictionary
			tile_info["cultural_group"] = String(influence.get("label", "Unknown"))
			var breakdown: Array[Dictionary] = []
			for entry_variant: Variant in (influence.get("breakdown", []) as Array):
				if entry_variant is Dictionary:
					breakdown.append(entry_variant as Dictionary)
			var population_groups := pipeline.derive_population_groups(breakdown)
			var major_groups := population_groups.get("major", []) as Array
			var minor_groups := population_groups.get("minor", []) as Array
			# Browser derivePopulationGroupsFromCulture returns null groups
			# for empty breakdowns - store nothing so structure-stamped
			# groups survive and the tooltip section simply hides.
			if not major_groups.is_empty() or not minor_groups.is_empty():
				_tile_population_groups[coord] = {
					"major_population_groups": major_groups,
					"minor_population_groups": minor_groups
				}
		var ambient_structure: Variant = tile_info.get("ambient_structure", null)
		if ambient_structure is Dictionary:
			# Roads were laid before culture ran; keep them clear of clutter.
			if _roads_layer != null and _roads_layer.get_cell_source_id(coord) >= 0:
				tile_info["ambient_structure"] = null
				_tile_data[coord] = tile_info
				continue
			var ambient_dict := ambient_structure as Dictionary
			tile_info["structure"] = String(ambient_dict.get("id", "ambient"))
			if bool(ambient_dict.get("replace_tree_overlay", false)) and tree_layer != null:
				tree_layer.erase_cell(coord)
				tile_info["overlay_flags"] = int(tile_info.get("overlay_flags", 0)) & ~TILE_OVERLAY_TREE & ~TILE_OVERLAY_FOREST
			# Never paint over existing settlement art: desert-city compound
			# cells carry art without a tile-data marker.
			if settlement_layer != null and not tile_info.has("settlement_type") and ambient_dict.has("tile") and settlement_layer.get_cell_source_id(coord) < 0:
				settlement_layer.set_cell(coord, _atlas_source_id, ambient_dict.get("tile", TOWN_TILE) as Vector2i)
				var ambient_id := String(ambient_dict.get("id", ""))
				if ambient_id == "farm":
					_scatter_farm_crops(coord)
				elif ambient_id == "lumber_mill":
					_scatter_lumber_clearing(coord)
		_tile_data[coord] = tile_info

## A farm is more than its barn: sow crop tiles across the plain-grass cells
## around it so tilled fields read on the map instead of a lone building.
func _scatter_farm_crops(farm_coord: Vector2i) -> void:
	if settlement_layer == null:
		return
	var sown := 0
	for i in range(NEIGHBOR_OFFSETS_8.size()):
		if sown >= 5:
			break
		var neighbor := farm_coord + NEIGHBOR_OFFSETS_8[i]
		if settlement_layer.get_cell_source_id(neighbor) >= 0:
			continue
		var n_info := _tile_data.get(neighbor, {}) as Dictionary
		if n_info.is_empty() or String(n_info.get("structure", "")).strip_edges() != "":
			continue
		if not _is_plain_grass_tile(n_info):
			continue
		# A dirt track or river cutting the plot would clash with the rows.
		if _roads_layer != null and _roads_layer.get_cell_source_id(neighbor) >= 0:
			continue
		if river_layer != null and river_layer.get_cell_source_id(neighbor) >= 0:
			continue
		# FARM_CROPS_TILE (15,0) is the only true tilled-field art; the old
		# "farm variant" constant (16,2) actually points at a heraldic banner,
		# so every field tile uses the crop art.
		settlement_layer.set_cell(neighbor, _atlas_source_id, FARM_CROPS_TILE)
		n_info["structure"] = "farmField"
		n_info["settlement_classification"] = "Farmland"
		_tile_data[neighbor] = n_info
		sown += 1

## A working lumber mill leaves a felled clearing: neighbouring wooded tiles
## lose their trees and show cut-woods stumps (CUT_TREES_TILE, atlas (1,6)),
## so a mill reads as an active logging site rather than a lone shed.
func _scatter_lumber_clearing(mill_coord: Vector2i) -> void:
	if settlement_layer == null or tree_layer == null:
		return
	var cleared := 0
	for i in range(NEIGHBOR_OFFSETS_8.size()):
		if cleared >= 5:
			break
		var neighbor := mill_coord + NEIGHBOR_OFFSETS_8[i]
		if settlement_layer.get_cell_source_id(neighbor) >= 0:
			continue
		# Only fell where woods actually stand.
		if tree_layer.get_cell_source_id(neighbor) < 0:
			continue
		var n_info := _tile_data.get(neighbor, {}) as Dictionary
		if n_info.is_empty() or String(n_info.get("structure", "")).strip_edges() != "":
			continue
		if _roads_layer != null and _roads_layer.get_cell_source_id(neighbor) >= 0:
			continue
		tree_layer.erase_cell(neighbor)
		n_info["overlay_flags"] = int(n_info.get("overlay_flags", 0)) & ~TILE_OVERLAY_TREE & ~TILE_OVERLAY_FOREST
		settlement_layer.set_cell(neighbor, _atlas_source_id, TILE_ATLAS_DEFS.CUT_TREES_TILE)
		n_info["structure"] = "cutWoods"
		n_info["settlement_classification"] = "Logged Woods"
		_tile_data[neighbor] = n_info
		cleared += 1

## Plain grass: grassland base with nothing overlaid - the only ground a
## culture will till or build a homestead on.
func _is_plain_grass_tile(info: Dictionary) -> bool:
	var biome := String(info.get("biome_type", info.get("base_biome", info.get("base", "")))).to_lower()
	var base := String(info.get("base_biome", info.get("base", ""))).to_lower()
	if biome != "grassland" or base != "grassland":
		return false
	if not String(info.get("overlay", "")).strip_edges().is_empty():
		return false
	return String(info.get("hill_overlay", "")).strip_edges().is_empty()

func _collect_settlement_sources() -> Array[Dictionary]:
	var settlements: Array[Dictionary] = []
	for coord: Vector2i in _tile_data.keys():
		var tile_info := _tile_data.get(coord, {}) as Dictionary
		if tile_info.is_empty() or not tile_info.has("settlement_type"):
			continue
		settlements.append({
			"x": coord.x,
			"y": coord.y,
			"type": String(tile_info.get("settlement_type", "town")),
			"population_breakdown": tile_info.get("population_breakdown", [])
		})
	return settlements

func _collect_faction_sources() -> Array[Dictionary]:
	var factions: Array[Dictionary] = []
	for coord: Vector2i in _tile_data.keys():
		var tile_info := _tile_data.get(coord, {}) as Dictionary
		if not tile_info.has("settlement_type"):
			continue
		var settlement_type := String(tile_info.get("settlement_type", "")).to_lower()
		if settlement_type == "":
			continue
		var faction_key := "humans"
		if settlement_type == "dwarfhold":
			faction_key = "dwarves"
		elif settlement_type.find("woodelf") >= 0:
			faction_key = "wood_elves"
		elif settlement_type.find("lizard") >= 0:
			faction_key = "lizardmen"
		elif settlement_type.find("desert") >= 0:
			faction_key = "desert_folk"
		# Browser rule: a town's reach grows with its people - hamlets of
		# ~120 hold little ground, cities of 2000+ claim the full radius.
		var claim_radius := 12
		if faction_key == "humans":
			var town_population := maxi(0, int(tile_info.get("population", 0)))
			var population_scale := clampf(float(town_population - 120) / float(2000 - 120), 0.0, 1.0)
			claim_radius = int(round(lerpf(8.0, 15.0, population_scale)))
		factions.append({
			"key": faction_key,
			"label": String(CIVILIZATION_LABELS.get(faction_key, faction_key.capitalize())),
			"color": CultureTypes.DEFAULT_CULTURE_COLORS.get(faction_key, Color.GRAY),
			"capital": {"x": coord.x, "y": coord.y, "type": settlement_type},
			"claim_radius": claim_radius
		})
	return factions

func _resolve_wood_elf_territory() -> Dictionary:
	for coord: Vector2i in _tile_data.keys():
		var tile_info := _tile_data.get(coord, {}) as Dictionary
		var settlement_type := String(tile_info.get("settlement_type", "")).to_lower()
		if settlement_type.find("woodelf") >= 0:
			return {"center": {"x": coord.x, "y": coord.y}, "radius": 14}
	return {}

func _choose_culture_center(
	profile: Dictionary,
	land_cells: Array[Vector2i],
	existing_centers: Array[Vector2i],
	biome_map: Dictionary,
	temperature_map: Dictionary,
	moisture_map: Dictionary,
	rng: RandomNumberGenerator
) -> Vector2i:
	if land_cells.is_empty():
		return Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	var best_score := -1.0
	var attempts := mini(land_cells.size(), 1600)
	for _attempt in range(attempts):
		var coord: Vector2i = land_cells[rng.randi_range(0, land_cells.size() - 1)]
		var score := _culture_cell_score(profile, coord, biome_map, temperature_map, moisture_map)
		if score <= 0.0:
			continue
		for existing: Vector2i in existing_centers:
			var separation := maxf(1.0, coord.distance_to(existing))
			if separation < 22.0:
				score *= clampf(separation / 22.0, 0.1, 1.0)
		if score > best_score:
			best_score = score
			best = coord
	return best

func _culture_cell_score(
	profile: Dictionary,
	coord: Vector2i,
	biome_map: Dictionary,
	temperature_map: Dictionary,
	moisture_map: Dictionary
) -> float:
	var biome := String(biome_map.get(coord, BIOME_GRASSLAND))
	var score := 1.0
	var preferred_biomes: Array = profile.get("preferred_biomes", []) as Array
	if preferred_biomes.has(biome):
		score += 1.2
	elif biome == BIOME_MOUNTAIN or biome == BIOME_DESERT:
		score *= 0.45
	var temperature := float(temperature_map.get(coord, 0.5))
	var moisture := float(moisture_map.get(coord, 0.5))
	var temperature_goal := float(profile.get("temperature_goal", 0.5))
	var moisture_goal := float(profile.get("moisture_goal", 0.5))
	var climate_alignment := (1.0 - absf(temperature - temperature_goal)) * 0.55 + (1.0 - absf(moisture - moisture_goal)) * 0.45
	return maxf(0.01, score * clampf(climate_alignment, 0.1, 1.0))

func _expand_cultural_groups(
	culture_profiles: Array[Dictionary],
	biome_map: Dictionary,
	temperature_map: Dictionary,
	moisture_map: Dictionary,
	height_map: Dictionary
) -> Dictionary:
	var assignments: Dictionary = {}
	var costs: Dictionary = {}
	var frontier: Array[Dictionary] = []
	for profile: Dictionary in culture_profiles:
		var center := profile.get("center", Vector2i(-1, -1)) as Vector2i
		if center == Vector2i(-1, -1):
			continue
		assignments[center] = profile
		costs[center] = 0.0
		_heap_push(frontier, {"coord": center, "cost": 0.0, "profile": profile})

	while not frontier.is_empty():
		var current := _heap_pop(frontier)
		var coord := current["coord"] as Vector2i
		var current_cost := float(current.get("cost", 0.0))
		if current_cost > float(costs.get(coord, INF)):
			continue
		var profile := current["profile"] as Dictionary
		var cardinal_offsets: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
		for offset: Vector2i in cardinal_offsets:
			var neighbor: Vector2i = coord + offset
			if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= map_size.x or neighbor.y >= map_size.y:
				continue
			var biome := String(biome_map.get(neighbor, BIOME_WATER))
			if biome == BIOME_WATER:
				continue
			var travel_cost := _culture_travel_cost(profile, neighbor, biome_map, temperature_map, moisture_map, height_map)
			var expansionism := maxf(0.2, float(profile.get("expansionism", 1.0)))
			var total_cost := current_cost + (travel_cost / expansionism)
			if total_cost > 280.0:
				continue
			var previous_cost := float(costs.get(neighbor, INF))
			if total_cost < previous_cost:
				costs[neighbor] = total_cost
				assignments[neighbor] = profile
				_heap_push(frontier, {"coord": neighbor, "cost": total_cost, "profile": profile})

	return assignments

func _culture_travel_cost(
	profile: Dictionary,
	coord: Vector2i,
	biome_map: Dictionary,
	temperature_map: Dictionary,
	moisture_map: Dictionary,
	height_map: Dictionary
) -> float:
	var biome := String(biome_map.get(coord, BIOME_GRASSLAND))
	var preferred_biomes: Array = profile.get("preferred_biomes", []) as Array
	var biome_cost := 2.5 if preferred_biomes.has(biome) else 6.5
	var elevation := float(height_map.get(coord, water_level))
	if biome == BIOME_MOUNTAIN:
		biome_cost += float(profile.get("mountain_crossing_penalty", 5.0))
	elif biome == BIOME_HILLS:
		biome_cost += 1.75
	elif elevation < water_level:
		biome_cost += float(profile.get("water_crossing_penalty", 14.0))
	var temperature := float(temperature_map.get(coord, 0.5))
	var moisture := float(moisture_map.get(coord, 0.5))
	var temperature_goal := float(profile.get("temperature_goal", 0.5))
	var moisture_goal := float(profile.get("moisture_goal", 0.5))
	var climate_penalty := absf(temperature - temperature_goal) * 4.0 + absf(moisture - moisture_goal) * 3.0
	return biome_cost + climate_penalty + 1.0

func _get_neighbor_cultures(coord: Vector2i, assignments: Dictionary) -> Array[String]:
	var cultures: Array[String] = []
	var neighbor_offsets: Array[Vector2i] = [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i(-1, -1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(1, 1)
	]
	for offset: Vector2i in neighbor_offsets:
		var neighbor: Vector2i = coord + offset
		if not assignments.has(neighbor):
			continue
		var culture := String((assignments[neighbor] as Dictionary).get("name", "")).strip_edges()
		if culture.is_empty() or cultures.has(culture):
			continue
		cultures.append(culture)
	return cultures

func _heap_push(heap: Array[Dictionary], entry: Dictionary) -> void:
	heap.append(entry)
	var index := heap.size() - 1
	while index > 0:
		var parent := int((index - 1) / 2)
		if float(heap[parent].get("cost", 0.0)) <= float(heap[index].get("cost", 0.0)):
			break
		var temp := heap[parent]
		heap[parent] = heap[index]
		heap[index] = temp
		index = parent

func _heap_pop(heap: Array[Dictionary]) -> Dictionary:
	if heap.is_empty():
		return {}
	var root := heap[0]
	var tail: Dictionary = heap.pop_back()
	if not heap.is_empty():
		heap[0] = tail
		var index := 0
		while true:
			var left := index * 2 + 1
			var right := left + 1
			if left >= heap.size():
				break
			var smallest := left
			if right < heap.size() and float(heap[right].get("cost", 0.0)) < float(heap[left].get("cost", 0.0)):
				smallest = right
			if float(heap[index].get("cost", 0.0)) <= float(heap[smallest].get("cost", 0.0)):
				break
			var temp := heap[index]
			heap[index] = heap[smallest]
			heap[smallest] = temp
			index = smallest
	return root

func _is_too_close(coord: Vector2i, occupied: Array[Vector2i], min_distance: float) -> bool:
	return OverworldSettlementService.is_too_close(coord, occupied, min_distance)

func _is_within_tiles_of_volcano(coord: Vector2i, radius: int) -> bool:
	if highland_layer == null:
		return false
	for oy in range(-radius, radius + 1):
		for ox in range(-radius, radius + 1):
			var offset := Vector2i(ox, oy)
			if coord.distance_to(coord + offset) > float(radius):
				continue
			var neighbor := coord + offset
			var highland_tile := highland_layer.get_cell_atlas_coords(neighbor)
			if highland_tile == ACTIVE_VOLCANO_TILE or highland_tile == VOLCANO_TILE:
				return true
	return false

func _resources_for_biome_id(biome_id: int) -> Array[String]:
	var resolved: Array[String] = []
	for entry: Variant in _BIOME_RESOURCES_BY_ID.get(biome_id, _BIOME_RESOURCES_BY_ID.get(_biome_to_id(BIOME_GRASSLAND), [])):
		resolved.append(String(entry))
	return resolved

## Browser-style tile resources: the biome's base yields plus proximity
## bonuses (coasts, marshes, deserts, volcanoes, deep canopy, cold), with
## lakes and oceans yielding different waters. Capped at 5 per tile.
func _resources_for_tile(coord: Vector2i, data: Dictionary) -> Array[String]:
	var biome_id := int(data.get("biome_id", _biome_to_id(BIOME_GRASSLAND)))
	var resolved: Array[String]
	if biome_id == _biome_to_id(BIOME_WATER) and _is_lake_coord(coord):
		resolved = ["freshwater catches", "boat timber", "shoreline clay"]
	else:
		var catalog_id := biome_id
		if biome_id == _biome_to_id(BIOME_HILLS):
			# Browser hill overlays keep the underlying biome's yields
			# (no hills entry in the main.js:14147-14158 catalog).
			catalog_id = int(data.get("base_biome_id", _biome_to_id(BIOME_GRASSLAND)))
		resolved = _resources_for_biome_id(catalog_id)
	# Bonus order matches the browser (main.js:14177-14194): coast, marsh,
	# desert, volcano, canopy, cold - so the 5-entry cap bites identically.
	if float(data.get("coast_proximity", 0.0)) >= 0.65 and biome_id != _biome_to_id(BIOME_WATER):
		resolved.append("coastal fisheries")
	if float(data.get("marsh_proximity", 0.0)) >= 0.55 and biome_id != _biome_to_id(BIOME_MARSH):
		resolved.append("peat and bog iron")
	if float(data.get("desert_proximity", 0.0)) >= 0.55 and biome_id != _biome_to_id(BIOME_DESERT):
		resolved.append("trade caravans")
	if float(data.get("volcano_proximity", 0.0)) >= 0.45:
		resolved.append("volcanic glass and obsidian")
	if float(data.get("forest_canopy_density", 0.0)) >= 0.65:
		resolved.append("dense lumber stands")
	if float(data.get("temperature", 1.0)) <= 0.25 and biome_id != _biome_to_id(BIOME_TUNDRA):
		resolved.append("fur-bearing game")
	if resolved.size() > 5:
		resolved = resolved.slice(0, 5)
	return resolved

func _is_lake_coord(coord: Vector2i) -> bool:
	var lake_cells_variant: Variant = _landmass_masks.get("lake_cells", {})
	if lake_cells_variant is Dictionary:
		return (lake_cells_variant as Dictionary).has(coord)
	return false

func _describe_climate(data: Dictionary) -> String:
	return OverworldPopulationService.describe_climate(data)

func _format_resource_list(resources: Array[String]) -> String:
	return OverworldPopulationService.format_resource_list(resources)

func _generate_biome_region_name(
	biome: String,
	water_body_type: String,
	rng: RandomNumberGenerator,
	context_size: int
) -> String:
	return WORLD_NAMING.generate_biome_region_name(biome, water_body_type, rng, context_size)

func _pick_random_entry(options: Array[String], rng: RandomNumberGenerator, fallback: String = "") -> String:
	if options.is_empty():
		return fallback
	return options[rng.randi_range(0, options.size() - 1)]

func _pick_unique_entries(
	options: Array[String],
	rng: RandomNumberGenerator,
	count: int,
	guaranteed: String = ""
) -> Array[String]:
	var pool: Array[String] = options.duplicate()
	var chosen: Array[String] = []
	if not guaranteed.is_empty():
		if pool.has(guaranteed):
			pool.erase(guaranteed)
		chosen.append(guaranteed)
	while chosen.size() < count and not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		chosen.append(pool[index])
		pool.remove_at(index)
	return chosen

func _has_nearby_settlement_type(
	coord: Vector2i,
	settlement_type: String,
	search_radius: float
) -> bool:
	if search_radius <= 0.0:
		return false
	for tile_coord: Vector2i in _tile_data.keys():
		var details: Dictionary = _tile_data.get(tile_coord, {}) as Dictionary
		if String(details.get("settlement_type", "")) != settlement_type:
			continue
		if coord.distance_to(tile_coord) <= search_radius:
			return true
	return false

func _sort_fraction_desc(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("fraction", 0.0)) > float(b.get("fraction", 0.0))

func _generate_dwarfhold_population_breakdown(
	population: int,
	has_nearby_human_settlement: bool,
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	if DWARFHOLD_POPULATION_RACE_OPTIONS.is_empty():
		return []

	var config_map := {}
	for option: Dictionary in DWARFHOLD_POPULATION_RACE_OPTIONS:
		var key := String(option.get("key", ""))
		if not key.is_empty():
			config_map[key] = option

	var dwarf_config: Dictionary = config_map.get("dwarves", {}) as Dictionary
	if dwarf_config.is_empty():
		return []

	var resolved_population := maxi(0, population)
	var majority_range := Vector2(0.9, 0.96)
	if has_nearby_human_settlement:
		majority_range = Vector2(0.85, 0.93)
	var dwarf_share := clampf(
		lerpf(majority_range.x, majority_range.y, rng.randf()),
		0.0,
		1.0
	)
	var shares: Array[Dictionary] = [{"config": dwarf_config, "share": dwarf_share}]
	var remainder_share := maxf(0.0, 1.0 - dwarf_share)

	var weight_plans := []
	if has_nearby_human_settlement:
		weight_plans = [
			{"key": "humans", "min": 0.9, "max": 1.6},
			{"key": "halflings", "min": 0.7, "max": 1.2},
			{"key": "gnomes", "min": 0.15, "max": 0.4},
			{"key": "goblins", "min": 0.12, "max": 0.35},
			{"key": "kobolds", "min": 0.12, "max": 0.35},
			{"key": "others", "min": 0.0, "max": 0.2}
		]
	else:
		weight_plans = [
			{"key": "gnomes", "min": 0.8, "max": 1.4},
			{"key": "goblins", "min": 0.9, "max": 1.5},
			{"key": "kobolds", "min": 0.7, "max": 1.2},
			{"key": "others", "min": 0.0, "max": 0.25}
		]

	var weight_entries: Array[Dictionary] = []
	for plan: Dictionary in weight_plans:
		var config: Dictionary = config_map.get(String(plan.get("key", "")), {}) as Dictionary
		if config.is_empty():
			continue
		var min_weight := maxf(0.0, float(plan.get("min", 0.0)))
		var max_weight := maxf(min_weight, float(plan.get("max", min_weight)))
		if max_weight <= 0.0:
			continue
		var weight := min_weight + rng.randf() * (max_weight - min_weight)
		if weight <= 0.0:
			continue
		weight_entries.append({"config": config, "weight": weight})

	var weight_sum := 0.0
	for entry: Dictionary in weight_entries:
		weight_sum += float(entry.get("weight", 0.0))

	if remainder_share > 0.0 and weight_sum > 0.0:
		for entry: Dictionary in weight_entries:
			var share := (float(entry.get("weight", 0.0)) / weight_sum) * remainder_share
			shares.append({"config": entry.get("config", {}), "share": share})

	var total_share := 0.0
	for entry: Dictionary in shares:
		total_share += float(entry.get("share", 0.0))
	var safe_total := total_share if total_share > 0.0 else 1.0

	var normalized_shares: Array[Dictionary] = []
	for entry: Dictionary in shares:
		var share := clampf(float(entry.get("share", 0.0)) / safe_total, 0.0, 1.0)
		normalized_shares.append({"config": entry.get("config", {}), "share": share})

	var percentage_decimals := 2
	var percentage_scale := int(pow(10, percentage_decimals))
	var total_units := 100 * percentage_scale

	var scaled_entries: Array[Dictionary] = []
	for entry: Dictionary in normalized_shares:
		var safe_share := clampf(float(entry.get("share", 0.0)), 0.0, 1.0)
		var raw_percentage := safe_share * 100.0
		var scaled_raw := raw_percentage * float(percentage_scale)
		var base_unit := int(floor(scaled_raw))
		var fraction := clampf(scaled_raw - float(base_unit), 0.0, 1.0)
		scaled_entries.append({
			"config": entry.get("config", {}),
			"base_unit": base_unit,
			"fraction": fraction
		})

	var base_units: Array[int] = []
	for entry: Dictionary in scaled_entries:
		base_units.append(int(entry.get("base_unit", 0)))
	var remainder_units := total_units
	for value: int in base_units:
		remainder_units -= value

	var fractional_order: Array[Dictionary] = []
	for index in range(scaled_entries.size()):
		fractional_order.append({"index": index, "fraction": float(scaled_entries[index].get("fraction", 0.0))})
	fractional_order.sort_custom(Callable(self, "_sort_fraction_desc"))

	if not fractional_order.is_empty():
		var increment_index := 0
		while remainder_units > 0:
			var target: Dictionary = fractional_order[increment_index % fractional_order.size()]
			var target_index := int(target.get("index", 0))
			base_units[target_index] += 1
			remainder_units -= 1
			increment_index += 1

		var ascending := fractional_order.duplicate()
		ascending.reverse()
		var decrement_index := 0
		while remainder_units < 0 and not ascending.is_empty():
			var target: Dictionary = ascending[decrement_index % ascending.size()]
			var target_index := int(target.get("index", 0))
			if base_units[target_index] > 0:
				base_units[target_index] -= 1
				remainder_units += 1
			decrement_index += 1

	if remainder_units != 0 and not base_units.is_empty():
		var last_index := base_units.size() - 1
		var adjusted := clampi(base_units[last_index] + remainder_units, 0, total_units)
		remainder_units -= adjusted - base_units[last_index]
		base_units[last_index] = adjusted

	var results: Array[Dictionary] = []
	for index in range(scaled_entries.size()):
		var config: Dictionary = scaled_entries[index].get("config", {}) as Dictionary
		var percentage := clampf(float(base_units[index]) / float(percentage_scale), 0.0, 100.0)
		var count := int(round(float(resolved_population) * percentage / 100.0))
		results.append({
			"key": String(config.get("key", "")),
			"label": String(config.get("label", "")),
			"color": config.get("color", Color.GRAY),
			"percentage": percentage,
			"population": count
		})
	return results

func _dwarfhold_classification_for_tile(tile: Vector2i) -> Dictionary:
	if tile == GREAT_DWARFHOLD_TILE:
		return {
			"key": "great",
			"label": "Great Dwarfhold",
			"population_range": Vector2i(4800, 12000)
		}
	if tile == DARK_DWARFHOLD_TILE:
		return {
			"key": "dark",
			"label": "Dark Dwarfhold",
			"population_range": Vector2i(1800, 7000)
		}
	if tile == ABANDONED_DWARFHOLD_TILE:
		return {
			"key": "abandoned",
			"label": "Abandoned Dwarfhold",
			"population_range": Vector2i(0, 0)
		}
	return {
		"key": "standard",
		"label": "Dwarfhold",
		"population_range": Vector2i(900, 4800)
	}

func _dwarfhold_access_status_for_classification(classification_key: String, rng: RandomNumberGenerator) -> String:
	if classification_key == "abandoned":
		return "Closed"
	if rng.randf() < 0.12:
		return "Closed"
	return "Open"

func _dwarfhold_depth_for_classification(classification_key: String) -> String:
	if classification_key == "dark":
		return "Underdark"
	return "Overworld"

func _generate_dwarfhold_details(
	settlement_name: String,
	settlement_coord: Vector2i,
	settlement_tile: Vector2i,
	rng: RandomNumberGenerator
) -> Dictionary:
	var classification := _dwarfhold_classification_for_tile(settlement_tile)
	var classification_key := String(classification.get("key", ""))
	var hold_access := _dwarfhold_access_status_for_classification(classification_key, rng)
	var hold_depth := _dwarfhold_depth_for_classification(classification_key)
	var details := {
		"settlement_classification": classification["label"],
		"settlement_classification_key": classification_key,
		"dwarfhold_access": hold_access,
		"dwarfhold_depth": hold_depth,
		"population_label": "Population",
		"population_descriptor": "residents"
	}
	if classification_key == "abandoned":
		details["population"] = 0
		details["ruler_title"] = ""
		details["ruler_name"] = ""
		details["founded_years_ago"] = rng.randi_range(120, 3800)
		details["prominent_clan"] = ""
		details["major_clans"] = []
		details["major_guilds"] = []
		details["major_exports"] = []
		details["hallmark"] = _pick_random_entry(
			DWARFHOLD_ABANDONED_HALLMARKS,
			rng,
			"Silent halls lie sealed behind collapsed tunnels."
		)
		details["description"] = "Dust and silence fill the abandoned chambers."
		return details

	var population_range: Vector2i = classification["population_range"]
	var population := rng.randi_range(population_range.x, population_range.y)
	var has_nearby_human_settlement := _has_nearby_settlement_type(
		settlement_coord,
		"town",
		DWARFHOLD_NEARBY_TOWN_RADIUS
	)
	var clan := _pick_random_entry(DWARFHOLD_CLANS, rng, "Stonebeard")
	var is_dark: bool = classification_key == "dark"
	## Gender first, then a name and title from matching pools, so a
	## Queen is never called Thorin (town_details_generator's pattern).
	var ruler_gender := NpcIdentityService.roll_dwarf_gender(rng)
	var ruler_first := NpcIdentityService.dwarf_ruler_first_name(rng, ruler_gender)
	var ruler_title := NpcIdentityService.dwarf_ruler_title(rng, ruler_gender, is_dark)
	details["population"] = population
	details["ruler_title"] = ruler_title
	details["ruler_name"] = "%s %s" % [ruler_first, clan]
	details["ruler_gender"] = ruler_gender
	details["founded_years_ago"] = rng.randi_range(60, 3200)
	details["prominent_clan"] = clan
	var major_clan_count := rng.randi_range(2, 4)
	details["major_clans"] = _pick_unique_entries(DWARFHOLD_CLANS, rng, major_clan_count, clan)
	var guild_count := rng.randi_range(2, 3)
	var guilds := _pick_unique_entries(DWARFHOLD_GUILDS, rng, guild_count)
	if is_dark and not guilds.has("Ashforged Covenant"):
		guilds.append("Ashforged Covenant")
	details["major_guilds"] = guilds
	var export_count := rng.randi_range(2, 3)
	var exports := _pick_unique_entries(DWARFHOLD_EXPORTS, rng, export_count)
	if is_dark:
		exports.append("Obsidian ingots")
	details["major_exports"] = exports
	var hallmark := _pick_random_entry(
		DWARFHOLD_HALLMARKS,
		rng,
		"Renowned for its rune-forges and unbroken gates."
	)
	if is_dark:
		hallmark = "%s Magma channels keep the forges blazing." % hallmark
	details["hallmark"] = hallmark
	details["description"] = "The hold of %s anchors nearby trade routes." % settlement_name
	var population_breakdown := _generate_dwarfhold_population_breakdown(
		population,
		has_nearby_human_settlement,
		rng
	)
	if is_dark:
		for entry in population_breakdown:
			if String(entry.get("key", "")) == "dwarves":
				entry["label"] = "Dark Dwarves"
				entry["color"] = Color("#3b2a3d")
	details["population_breakdown"] = population_breakdown
	# Rewritten from chronicle events after the history simulation.
	details["population_timeline"] = []
	return details

func _set_tooltip_label(label: Label, text: String, should_show: bool) -> void:
	if label == null:
		return
	label.visible = should_show
	if should_show:
		label.text = text
	var key_label: Label = null
	var parent := label.get_parent()
	if parent != null:
		var previous_index := label.get_index() - 1
		if previous_index >= 0 and previous_index < parent.get_child_count():
			key_label = parent.get_child(previous_index) as Label
	if key_label != null:
		key_label.visible = should_show

func _set_tooltip_section_visible(node: CanvasItem, should_show: bool) -> void:
	if node == null:
		return
	node.visible = should_show

func _format_population_breakdown_entry(entry: Dictionary) -> String:
	var label := String(entry.get("label", "")).strip_edges()
	var percentage := float(entry.get("percentage", 0.0))
	var population := int(entry.get("population", 0))
	var parts: Array[String] = []
	if not label.is_empty():
		parts.append(label)
	if percentage > 0.0:
		parts.append("%0.2f%%" % percentage)
	if population > 0:
		parts.append("(%s)" % str(population))
	return " ".join(parts)

func _populate_population_breakdown_list(breakdown: Array) -> void:
	if tooltip_population_breakdown_list == null:
		return
	# Free synchronously (not queue_free): a deferred free leaves the old rows
	# parented for the rest of the frame, so a same-frame size measurement would
	# double-count them and inflate the panel.
	for child in tooltip_population_breakdown_list.get_children():
		tooltip_population_breakdown_list.remove_child(child)
		child.free()
	var sorted_breakdown := breakdown.duplicate()
	sorted_breakdown.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(b.get("population", 0)) < int(a.get("population", 0))
	)
	for entry: Dictionary in sorted_breakdown:
		if float(entry.get("percentage", 0.0)) <= 0.0:
			continue
		if int(entry.get("population", 0)) <= 0:
			continue
		var label := Label.new()
		label.text = _format_population_breakdown_entry(entry)
		label.add_theme_font_size_override("font_size", 10)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tooltip_population_breakdown_list.add_child(label)

func _humanize_biome(biome: String) -> String:
	if biome.is_empty():
		return ""
	var words := biome.replace("_", " ").split(" ", false)
	for index in range(words.size()):
		words[index] = String(words[index]).capitalize()
	return " ".join(words)

## Browser biomeTypeDefinitions labels (main.js:2767-2778): water resolves
## to "Ocean"/"Lake" per the landmass masks and mountains read as
## "Mountain Range" instead of the raw biome word.
func _resolved_biome_label(coord: Vector2i, biome: String) -> String:
	if biome == BIOME_WATER:
		return "Lake" if _is_lake_coord(coord) else "Ocean"
	if biome == BIOME_MOUNTAIN:
		return "Mountain Range"
	return _humanize_biome(biome)

func _cache_map_layer_parent() -> void:
	if map_layer == null:
		return
	_map_layer_original_parent = map_layer.get_parent()
	if _map_layer_original_parent != null:
		_map_layer_original_index = map_layer.get_index()

func _cache_tree_layer_parent() -> void:
	if tree_layer == null:
		return
	_tree_layer_original_parent = tree_layer.get_parent()
	if _tree_layer_original_parent != null:
		_tree_layer_original_index = tree_layer.get_index()

func _cache_river_layer_parent() -> void:
	if river_layer == null:
		return
	_river_layer_original_parent = river_layer.get_parent()
	if _river_layer_original_parent != null:
		_river_layer_original_index = river_layer.get_index()

func _cache_highland_layer_parent() -> void:
	if highland_layer == null:
		return
	_highland_layer_original_parent = highland_layer.get_parent()
	if _highland_layer_original_parent != null:
		_highland_layer_original_index = highland_layer.get_index()

func _cache_iceberg_layer_parent() -> void:
	if iceberg_layer == null:
		return
	_iceberg_layer_original_parent = iceberg_layer.get_parent()
	if _iceberg_layer_original_parent != null:
		_iceberg_layer_original_index = iceberg_layer.get_index()

func _cache_settlement_layer_parent() -> void:
	if settlement_layer == null:
		return
	_settlement_layer_original_parent = settlement_layer.get_parent()
	if _settlement_layer_original_parent != null:
		_settlement_layer_original_index = settlement_layer.get_index()

func _cache_overlay_parent() -> void:
	if map_overlays == null:
		return
	_overlays_original_parent = map_overlays.get_parent()
	if _overlays_original_parent != null:
		_overlays_original_index = map_overlays.get_index()

func _configure_globe_viewport() -> void:
	if map_viewport == null:
		return
	var viewport_size := Vector2i(map_size.x * tile_size, map_size.y * tile_size)
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return
	map_viewport.size = viewport_size
	map_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _configure_overworld_camera_bounds() -> void:
	if overworld_camera == null:
		return
	var world_rect := _get_world_rect()
	overworld_camera.set_world_bounds(world_rect)
	_refresh_scale_bar()

func _get_world_rect() -> Rect2:
	var world_width := maxf(0.0, float(map_size.x * tile_size))
	var world_height := maxf(0.0, float(map_size.y * tile_size))
	return Rect2(Vector2.ZERO, Vector2(world_width, world_height))

func _set_globe_view(enabled: bool) -> void:
	if enabled:
		# The globe reads the tile layers; region mode has them hidden
		# and would draw its detail sprites over the 3D view.
		_exit_region_mode()
	_is_globe_view = enabled
	if globe_view != null:
		globe_view.visible = enabled
	if overworld_camera != null:
		overworld_camera.enabled = not (enabled or _is_scene3d_view)
		if not enabled and not _is_scene3d_view:
			overworld_camera.make_current()
	if globe_camera != null:
		globe_camera.current = enabled
	if not enabled:
		_is_dragging_globe = false
	if enabled and not _is_scene3d_view:
		_move_map_layer_to_viewport()
		_update_globe_texture()
	elif not enabled and not _is_scene3d_view:
		_restore_map_layer_parent()
	_update_elevation_overlay_visibility()
	_update_cliffs_overlay_visibility()
	_update_temperature_overlay_visibility()
	_update_moisture_overlay_visibility()
	_update_biome_overlay_visibility()
	_update_culture_overlay_visibility()
	_update_political_boundaries_overlay_visibility()
	_update_routes_overlay_visibility()
	_update_rivers_overlay_visibility()
	_update_labels_overlay_visibility()
	if enabled:
		_hide_map_tooltip()
	_refresh_scale_bar()

func _set_scene3d_view(enabled: bool) -> void:
	if enabled:
		_exit_region_mode()
	_is_scene3d_view = enabled
	if scene3d_view != null:
		scene3d_view.visible = enabled
	if overworld_camera != null:
		overworld_camera.enabled = not (_is_globe_view or enabled)
		if not _is_globe_view and not enabled:
			overworld_camera.make_current()
	if scene3d_camera != null:
		scene3d_camera.current = enabled
	if not enabled:
		_is_dragging_scene3d = false
	if enabled and not _is_globe_view:
		_move_map_layer_to_viewport()
		_update_scene3d_texture()
	elif not enabled and not _is_globe_view:
		_restore_map_layer_parent()
	_update_elevation_overlay_visibility()
	_update_cliffs_overlay_visibility()
	_update_temperature_overlay_visibility()
	_update_moisture_overlay_visibility()
	_update_biome_overlay_visibility()
	_update_culture_overlay_visibility()
	_update_political_boundaries_overlay_visibility()
	_update_routes_overlay_visibility()
	_update_rivers_overlay_visibility()
	_update_labels_overlay_visibility()
	if enabled:
		_hide_map_tooltip()
	_refresh_scale_bar()

func _move_map_layer_to_viewport() -> void:
	if map_layer == null or map_viewport_root == null:
		return
	if map_layer.get_parent() == map_viewport_root:
		return
	map_layer.get_parent().remove_child(map_layer)
	map_viewport_root.add_child(map_layer)
	map_layer.position = Vector2.ZERO
	if tree_layer != null:
		if tree_layer.get_parent() != null:
			tree_layer.get_parent().remove_child(tree_layer)
		map_viewport_root.add_child(tree_layer)
		tree_layer.position = Vector2.ZERO
	if river_layer != null:
		if river_layer.get_parent() != null:
			river_layer.get_parent().remove_child(river_layer)
		map_viewport_root.add_child(river_layer)
		river_layer.position = Vector2.ZERO
	if highland_layer != null:
		if highland_layer.get_parent() != null:
			highland_layer.get_parent().remove_child(highland_layer)
		map_viewport_root.add_child(highland_layer)
		highland_layer.position = Vector2.ZERO
	if iceberg_layer != null:
		if iceberg_layer.get_parent() != null:
			iceberg_layer.get_parent().remove_child(iceberg_layer)
		map_viewport_root.add_child(iceberg_layer)
		iceberg_layer.position = Vector2.ZERO
	if settlement_layer != null:
		if settlement_layer.get_parent() != null:
			settlement_layer.get_parent().remove_child(settlement_layer)
		map_viewport_root.add_child(settlement_layer)
		settlement_layer.position = Vector2.ZERO
	if map_overlays != null:
		if map_overlays.get_parent() != null:
			map_overlays.get_parent().remove_child(map_overlays)
		map_viewport_root.add_child(map_overlays)
		map_overlays.position = Vector2.ZERO
	if _coast_layer != null:
		if _coast_layer.get_parent() != null:
			_coast_layer.get_parent().remove_child(_coast_layer)
		map_viewport_root.add_child(_coast_layer)
		_coast_layer.position = Vector2.ZERO

## Tracks whether the OS cursor is inside the window: the tooltip follows
## get_global_mouse_position(), which freezes at its last value once the
## cursor leaves, so without this the tooltip sticks on screen forever.
var _mouse_inside_window := true

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_inside_window = false
		_hide_map_tooltip()
	elif what == NOTIFICATION_WM_MOUSE_ENTER:
		_mouse_inside_window = true

func _update_map_tooltip() -> void:
	if tooltip_panel == null or map_layer == null:
		return
	if not _mouse_inside_window:
		_hide_map_tooltip()
		return
	# The cursor is on real UI (toolbar buttons, scale bar, a dialog): the
	# tile tooltip must not pop up over it. The tooltip's own subtree is
	# exempt so it can't hide itself when edge-clamping slides it under
	# the cursor.
	var hovered_control := get_viewport().gui_get_hovered_control()
	if hovered_control != null and hovered_control != tooltip_panel \
			and not tooltip_panel.is_ancestor_of(hovered_control) \
			and _control_blocks_map_tooltip(hovered_control):
		_hide_map_tooltip()
		return
	if _is_globe_view or _is_scene3d_view:
		if _is_dragging_globe or _is_dragging_scene3d or _hovered_tile.x < 0 or _hovered_tile.y < 0:
			_hide_map_tooltip()
			return
		_present_map_tooltip(_hovered_tile)
		return
	var global_mouse := get_global_mouse_position()
	var local_mouse := map_layer.to_local(global_mouse)
	var coord := map_layer.local_to_map(local_mouse)
	if coord.x < 0 or coord.y < 0 or coord.x >= map_size.x or coord.y >= map_size.y:
		_hide_map_tooltip()
		return
	if not _tile_data.has(coord):
		_hide_map_tooltip()
		return
	if coord != _hovered_tile:
		_hovered_tile = coord
	_present_map_tooltip(coord)

## Interactive controls (STOP filter) and opaque panels suppress the tile
## tooltip. Transparent PASS containers stretched over the map — like the
## top bar's empty strip past its last button — do not: the player sees
## bare map there and expects the tooltip.
func _control_blocks_map_tooltip(hovered: Control) -> bool:
	var node: Node = hovered
	while node is Control:
		var control := node as Control
		if control.mouse_filter == Control.MOUSE_FILTER_STOP:
			return true
		if control is PanelContainer or control is Panel:
			return true
		node = control.get_parent()
	return false

## Shows the tooltip for a tile. Repopulates only when the hovered tile changes
## (re-setting the label text every frame keeps the autowrap measurement
## perpetually stale). On the frame content changes, the panel is laid out but
## parked off-screen so the transient screen-tall measurement is never seen;
## once the combined minimum is trustworthy it is placed at the cursor.
func _present_map_tooltip(coord: Vector2i) -> void:
	if tooltip_panel == null:
		return
	if coord != _tooltip_content_coord:
		_tooltip_content_coord = coord
		_refresh_map_tooltip(coord)
		_tooltip_settle_pending = true
		# New content restarts the stability probe from scratch.
		_tooltip_last_measured_min = Vector2(-1.0, -1.0)
	tooltip_panel.visible = true
	if _tooltip_settle_pending:
		var measured := tooltip_panel.get_combined_minimum_size()
		if measured != _tooltip_last_measured_min:
			# Still settling. Keep it laid out (visible) so the labels
			# reshape at their real width, but off-screen so the stale
			# over-wrapped panel is never seen — no matter how "plausible"
			# its size looks on a tall window.
			_tooltip_last_measured_min = measured
			tooltip_panel.position = Vector2(-100000.0, -100000.0)
			return
		_tooltip_settle_pending = false
	_position_map_tooltip()

func _refresh_map_tooltip(coord: Vector2i) -> void:
	if tooltip_panel == null:
		return
	# The panel must never grab the mouse: if it slides under the cursor
	# near a screen edge it would steal hover and blink on and off.
	if tooltip_panel.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var data: Dictionary = _tile_data.get(coord, {})
	var biome := _tile_biome_from_data(data)
	var resources := _resources_for_tile(coord, data)
	var region_name := _tile_region_name(coord, data)
	var biome_label := _resolved_biome_label(coord, biome)
	if region_name.is_empty():
		if biome_label.is_empty():
			region_name = "Unnamed Region"
		else:
			region_name = "Unnamed %s" % biome_label
	if tooltip_title != null:
		tooltip_title.text = region_name
	_set_tooltip_label(
		tooltip_biome,
		biome_label,
		not biome_label.is_empty()
	)
	# Which nation claims this tile (blank on unclaimed wilds and open sea).
	var realm_name := String(data.get("political_state", "")).strip_edges()
	_set_tooltip_label(
		tooltip_realm,
		realm_name,
		not realm_name.is_empty()
	)
	# The volcanic-warmth qualifier now travels inside describe_climate's
	# unified qualifier list (browser main.js:14241-14271).
	var climate_text := _describe_climate(data).strip_edges()
	_set_tooltip_label(
		tooltip_climate,
		climate_text,
		not climate_text.is_empty()
	)
	var resource_text := _format_resource_list(resources)
	_set_tooltip_label(
		tooltip_resources,
		resource_text,
		not resource_text.is_empty()
	)

	var culture_tooltip := _culture_pipeline.build_tooltip_data(data)
	var population_groups := _tile_population_groups_for_coord(coord)
	var major_population_groups := _variant_array_to_strings(population_groups.get("major_population_groups", []))
	if major_population_groups.is_empty() and not culture_tooltip.is_empty():
		major_population_groups = _variant_array_to_strings(culture_tooltip.get("major_population_groups", []))
	major_population_groups = _dedupe_trimmed_strings(major_population_groups)
	_set_tooltip_label(
		tooltip_major_population_groups,
		_format_resource_list(major_population_groups),
		not major_population_groups.is_empty()
	)
	var minor_population_groups := _variant_array_to_strings(population_groups.get("minor_population_groups", []))
	if minor_population_groups.is_empty() and not culture_tooltip.is_empty():
		minor_population_groups = _variant_array_to_strings(culture_tooltip.get("minor_population_groups", []))
	minor_population_groups = _dedupe_trimmed_strings(minor_population_groups)
	var filtered_minor_population_groups: Array[String] = []
	for group: String in minor_population_groups:
		if major_population_groups.has(group):
			continue
		filtered_minor_population_groups.append(group)
	minor_population_groups = filtered_minor_population_groups
	_set_tooltip_label(
		tooltip_minor_population_groups,
		_format_resource_list(minor_population_groups),
		not minor_population_groups.is_empty()
	)

	var settlement_type := String(data.get("settlement_type", ""))
	var is_dwarfhold := settlement_type == "dwarfhold"
	if is_dwarfhold:
		var classification_label := _variant_to_clean_string(data.get("settlement_classification", "Dwarfhold"))
		if classification_label.is_empty():
			classification_label = "Dwarfhold"
		var dwarfhold_access := _variant_to_clean_string(data.get("dwarfhold_access", ""))
		var dwarfhold_depth := _variant_to_clean_string(data.get("dwarfhold_depth", ""))
		var type_parts: Array[String] = [classification_label]
		if not dwarfhold_access.is_empty() or not dwarfhold_depth.is_empty():
			var access_and_depth: Array[String] = []
			if not dwarfhold_access.is_empty():
				access_and_depth.append(dwarfhold_access)
			if not dwarfhold_depth.is_empty():
				access_and_depth.append(dwarfhold_depth)
			type_parts.append("(%s)" % ", ".join(access_and_depth))
		_set_tooltip_label(tooltip_settlement, " ".join(type_parts), true)

		var population_value: Variant = data.get("population", null)
		var population_text := ""
		if typeof(population_value) == TYPE_INT or typeof(population_value) == TYPE_FLOAT:
			var population_int := maxi(0, int(round(float(population_value))))
			var population_descriptor := _variant_to_clean_string(data.get("population_descriptor", "residents"))
			population_text = str(population_int)
			if not population_descriptor.is_empty():
				population_text = "%s %s" % [population_text, population_descriptor]
		_set_tooltip_label(
			tooltip_population,
			population_text if not population_text.is_empty() else "Unknown",
			true
		)

		var ruler_title := _variant_to_clean_string(data.get("ruler_title", ""))
		var ruler_name := _variant_to_clean_string(data.get("ruler_name", ""))
		var ruler_text := "%s %s" % [ruler_title, ruler_name]
		ruler_text = ruler_text.strip_edges()
		_set_tooltip_label(tooltip_ruler, ruler_text if not ruler_text.is_empty() else "Unknown", true)

		var founded_value: Variant = data.get("founded_years_ago", null)
		var founded_text := ""
		if typeof(founded_value) == TYPE_INT or typeof(founded_value) == TYPE_FLOAT:
			founded_text = "%s years ago" % str(maxi(1, int(round(float(founded_value)))))
		_set_tooltip_label(
			tooltip_founded,
			founded_text if not founded_text.is_empty() else "Unknown",
			true
		)

		var prominent_clan := _variant_to_clean_string(data.get("prominent_clan", ""))
		_set_tooltip_label(
			tooltip_prominent_clan,
			prominent_clan if not prominent_clan.is_empty() else "Unknown",
			true
		)

		var major_clans := _variant_array_to_strings(data.get("major_clans", []))
		_set_tooltip_label(
			tooltip_major_clans,
			_format_resource_list(major_clans),
			not major_clans.is_empty()
		)

		var major_guilds := _variant_array_to_strings(data.get("major_guilds", []))
		_set_tooltip_label(
			tooltip_major_guilds,
			_format_resource_list(major_guilds),
			not major_guilds.is_empty()
		)

		var major_exports := _variant_array_to_strings(data.get("major_exports", []))
		_set_tooltip_label(
			tooltip_major_exports,
			_format_resource_list(major_exports),
			not major_exports.is_empty()
		)

		var hallmark := _variant_to_clean_string(data.get("hallmark", ""))
		_set_tooltip_label(
			tooltip_hallmark,
			hallmark,
			not hallmark.is_empty()
		)

		var population_breakdown: Array = []
		for entry: Variant in data.get("population_breakdown", []):
			if entry is Dictionary:
				population_breakdown.append(entry)
		var has_breakdown := not population_breakdown.is_empty()
		_set_tooltip_section_visible(tooltip_population_breakdown_section, has_breakdown)
		if has_breakdown:
			_populate_population_breakdown_list(population_breakdown)
			if tooltip_population_pie_chart != null and tooltip_population_pie_chart.has_method("set_slices"):
				tooltip_population_pie_chart.call("set_slices", population_breakdown)
		elif tooltip_population_pie_chart != null and tooltip_population_pie_chart.has_method("set_slices"):
			tooltip_population_pie_chart.call("set_slices", [])

	else:
		_set_tooltip_label(tooltip_settlement, "", false)
		_set_tooltip_label(tooltip_population, "", false)
		_set_tooltip_label(tooltip_ruler, "", false)
		_set_tooltip_label(tooltip_founded, "", false)
		_set_tooltip_label(tooltip_prominent_clan, "", false)
		_set_tooltip_label(tooltip_major_clans, "", false)
		_set_tooltip_label(tooltip_major_guilds, "", false)
		_set_tooltip_label(tooltip_major_exports, "", false)
		_set_tooltip_label(tooltip_hallmark, "", false)
		_set_tooltip_section_visible(tooltip_population_breakdown_section, false)
		if tooltip_population_pie_chart != null and tooltip_population_pie_chart.has_method("set_slices"):
			tooltip_population_pie_chart.call("set_slices", [])

func _position_map_tooltip() -> void:
	if tooltip_panel == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var cursor_pos := viewport.get_mouse_position()
	# Only reached once the measurement is trustworthy (see _present_map_tooltip),
	# so the combined minimum is the true content fit here.
	tooltip_panel.size = tooltip_panel.get_combined_minimum_size()
	var tooltip_size := tooltip_panel.size
	var offset := Vector2(16, 16)
	var viewport_size := viewport.get_visible_rect().size
	var max_pos := Vector2(
		maxf(0.0, viewport_size.x - tooltip_size.x),
		maxf(0.0, viewport_size.y - tooltip_size.y)
	)
	var target_pos := cursor_pos + offset
	target_pos.x = clampf(target_pos.x, 0.0, max_pos.x)
	target_pos.y = clampf(target_pos.y, 0.0, max_pos.y)
	tooltip_panel.position = target_pos

func _hide_map_tooltip() -> void:
	if tooltip_panel != null:
		tooltip_panel.visible = false
	_hovered_tile = Vector2i(-999, -999)

func _restore_map_layer_parent() -> void:
	if map_layer == null or _map_layer_original_parent == null:
		return
	if map_layer.get_parent() == _map_layer_original_parent:
		return
	map_layer.get_parent().remove_child(map_layer)
	if _map_layer_original_index >= 0:
		_map_layer_original_parent.add_child(map_layer)
		_map_layer_original_parent.move_child(map_layer, _map_layer_original_index)
	else:
		_map_layer_original_parent.add_child(map_layer)
	map_layer.position = Vector2.ZERO
	if tree_layer != null and _tree_layer_original_parent != null:
		if tree_layer.get_parent() != null:
			tree_layer.get_parent().remove_child(tree_layer)
		if _tree_layer_original_index >= 0:
			_tree_layer_original_parent.add_child(tree_layer)
			_tree_layer_original_parent.move_child(tree_layer, _tree_layer_original_index)
		else:
			_tree_layer_original_parent.add_child(tree_layer)
		tree_layer.position = Vector2.ZERO
	if river_layer != null and _river_layer_original_parent != null:
		if river_layer.get_parent() != null:
			river_layer.get_parent().remove_child(river_layer)
		if _river_layer_original_index >= 0:
			_river_layer_original_parent.add_child(river_layer)
			_river_layer_original_parent.move_child(river_layer, _river_layer_original_index)
		else:
			_river_layer_original_parent.add_child(river_layer)
		river_layer.position = Vector2.ZERO
	if highland_layer != null and _highland_layer_original_parent != null:
		if highland_layer.get_parent() != null:
			highland_layer.get_parent().remove_child(highland_layer)
		if _highland_layer_original_index >= 0:
			_highland_layer_original_parent.add_child(highland_layer)
			_highland_layer_original_parent.move_child(highland_layer, _highland_layer_original_index)
		else:
			_highland_layer_original_parent.add_child(highland_layer)
		highland_layer.position = Vector2.ZERO
	if iceberg_layer != null and _iceberg_layer_original_parent != null:
		if iceberg_layer.get_parent() != null:
			iceberg_layer.get_parent().remove_child(iceberg_layer)
		if _iceberg_layer_original_index >= 0:
			_iceberg_layer_original_parent.add_child(iceberg_layer)
			_iceberg_layer_original_parent.move_child(iceberg_layer, _iceberg_layer_original_index)
		else:
			_iceberg_layer_original_parent.add_child(iceberg_layer)
		iceberg_layer.position = Vector2.ZERO
	if settlement_layer != null and _settlement_layer_original_parent != null:
		if settlement_layer.get_parent() != null:
			settlement_layer.get_parent().remove_child(settlement_layer)
		if _settlement_layer_original_index >= 0:
			_settlement_layer_original_parent.add_child(settlement_layer)
			_settlement_layer_original_parent.move_child(settlement_layer, _settlement_layer_original_index)
		else:
			_settlement_layer_original_parent.add_child(settlement_layer)
		settlement_layer.position = Vector2.ZERO
	if _coast_layer != null and map_layer.get_parent() == self:
		if _coast_layer.get_parent() != null:
			_coast_layer.get_parent().remove_child(_coast_layer)
		add_child(_coast_layer)
		move_child(_coast_layer, map_layer.get_index() + 1)
		_coast_layer.position = map_layer.position
	if map_overlays == null or _overlays_original_parent == null:
		return
	if map_overlays.get_parent() == _overlays_original_parent:
		return
	if map_overlays.get_parent() != null:
		map_overlays.get_parent().remove_child(map_overlays)
	if _overlays_original_index >= 0:
		_overlays_original_parent.add_child(map_overlays)
		_overlays_original_parent.move_child(map_overlays, _overlays_original_index)
	else:
		_overlays_original_parent.add_child(map_overlays)
	map_overlays.position = Vector2.ZERO

func _handle_globe_input(event: InputEvent) -> bool:
	var mouse_button_event := event as InputEventMouseButton
	if mouse_button_event != null:
		if mouse_button_event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging_globe = mouse_button_event.pressed
			return true
		if mouse_button_event.pressed:
			if mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_globe_camera(-globe_zoom_step)
				return true
			if mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_globe_camera(globe_zoom_step)
				return true
	var mouse_motion_event := event as InputEventMouseMotion
	if mouse_motion_event != null and _is_dragging_globe:
		_rotate_globe_from_drag(mouse_motion_event.relative)
		return true
	return false

func _handle_scene3d_input(event: InputEvent) -> bool:
	var mouse_button_event := event as InputEventMouseButton
	if mouse_button_event != null:
		if mouse_button_event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging_scene3d = mouse_button_event.pressed
			return true
		if mouse_button_event.pressed:
			if mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_scene3d_camera(-scene3d_zoom_step)
				return true
			if mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_scene3d_camera(scene3d_zoom_step)
				return true
	var mouse_motion_event := event as InputEventMouseMotion
	if mouse_motion_event != null and _is_dragging_scene3d:
		_rotate_scene3d_from_drag(mouse_motion_event.relative)
		return true
	return false

func _rotate_globe_from_drag(relative_motion: Vector2) -> void:
	if globe_mesh == null:
		return
	globe_mesh.rotate_y(-relative_motion.x * globe_drag_sensitivity)
	globe_mesh.rotate_object_local(Vector3.RIGHT, -relative_motion.y * globe_drag_sensitivity)

func _zoom_globe_camera(distance_delta: float) -> void:
	if globe_camera == null:
		return
	var camera_origin := globe_camera.transform.origin
	var current_distance := camera_origin.length()
	if current_distance <= 0.0001:
		return
	var target_distance := clampf(current_distance + distance_delta, globe_min_camera_distance, globe_max_camera_distance)
	if is_equal_approx(target_distance, current_distance):
		return
	globe_camera.transform.origin = camera_origin.normalized() * target_distance

func _update_globe_texture() -> void:
	if globe_mesh == null or map_viewport == null:
		return
	var viewport_texture := map_viewport.get_texture()
	if viewport_texture == null:
		return
	var globe_material := globe_mesh.material_override as ShaderMaterial
	if globe_material == null:
		return
	globe_mesh.material_override = globe_material
	globe_material.set_shader_parameter("map_texture", viewport_texture)
	globe_material.set_shader_parameter("height_texture", _height_texture)
	globe_material.set_shader_parameter("water_level", water_level)
	globe_material.set_shader_parameter("mountain_level", mountain_level)
	globe_material.set_shader_parameter("mountain_compression", scene3d_mountain_compression)
	globe_material.set_shader_parameter("land_blend_power", scene3d_land_blend_power)
	globe_material.set_shader_parameter("height_scale", globe_height_scale)
	globe_material.set_shader_parameter("seam_band", globe_seam_band)

func _update_scene3d_texture() -> void:
	if scene3d_mesh == null or map_viewport == null:
		return
	var viewport_texture := map_viewport.get_texture()
	if viewport_texture == null:
		return
	var scene3d_material := scene3d_mesh.material_override as ShaderMaterial
	if scene3d_material == null:
		return
	scene3d_material.set_shader_parameter("map_texture", viewport_texture)
	scene3d_material.set_shader_parameter("height_texture", _height_texture)
	scene3d_material.set_shader_parameter("water_level", water_level)
	scene3d_material.set_shader_parameter("mountain_level", mountain_level)
	scene3d_material.set_shader_parameter("mountain_compression", scene3d_mountain_compression)
	scene3d_material.set_shader_parameter("land_blend_power", scene3d_land_blend_power)
	scene3d_material.set_shader_parameter("height_scale", scene3d_height_scale)

func _update_height_texture() -> void:
	if map_size.x <= 0 or map_size.y <= 0:
		_height_texture = null
		return
	var image := Image.create(map_size.x, map_size.y, false, Image.FORMAT_RF)
	if _height_buffer.is_empty():
		image.fill(Color(water_level, 0.0, 0.0, 1.0))
	else:
		for y in range(map_size.y):
			for x in range(map_size.x):
				var idx := _xy_to_index(x, y)
				var h := clampf(float(_height_buffer[idx]), 0.0, 1.0)
				image.set_pixel(x, y, Color(h, 0.0, 0.0, 1.0))
	_height_texture = ImageTexture.create_from_image(image)

func _configure_scene3d_mesh() -> void:
	if scene3d_mesh == null:
		return
	var plane_mesh := scene3d_mesh.mesh as PlaneMesh
	if plane_mesh == null:
		return
	if map_size.y <= 0:
		return
	var aspect := float(map_size.x) / float(map_size.y)
	plane_mesh.size = Vector2(maxf(2.0, 4.0 * aspect), 4.0)

func _rotate_scene3d_from_drag(relative_motion: Vector2) -> void:
	if scene3d_mesh == null:
		return
	scene3d_mesh.rotate_y(-relative_motion.x * scene3d_drag_sensitivity)
	scene3d_mesh.rotate_object_local(Vector3.RIGHT, -relative_motion.y * scene3d_drag_sensitivity)

func _zoom_scene3d_camera(distance_delta: float) -> void:
	if scene3d_camera == null:
		return
	var camera_origin := scene3d_camera.transform.origin
	var current_distance := camera_origin.length()
	if current_distance <= 0.0001:
		return
	var target_distance := clampf(current_distance + distance_delta, scene3d_min_camera_distance, scene3d_max_camera_distance)
	if is_equal_approx(target_distance, current_distance):
		return
	scene3d_camera.transform.origin = camera_origin.normalized() * target_distance

func _rotate_globe(delta: float) -> void:
	if globe_mesh == null or globe_rotation_speed == 0.0 or _is_dragging_globe:
		return
	globe_mesh.rotate_y(globe_rotation_speed * delta)

func _configure_tileset() -> void:
	var result := OverworldTilesetService.build_tile_set(tile_size, iceberg_tile_options)
	var tile_set := result["tile_set"] as TileSet
	_atlas_source_id = int(result["atlas_source_id"])
	_river_atlas_source_id = int(result["river_atlas_source_id"])
	var derived_tile_size := int(result["tile_size"])
	if derived_tile_size > 0 and derived_tile_size != tile_size:
		tile_size = derived_tile_size
	for layer: TileMapLayer in [map_layer, tree_layer, highland_layer, iceberg_layer, settlement_layer]:
		if layer == null:
			continue
		layer.tile_set = tile_set
		if _atlas_source_id >= 0:
			layer.position = Vector2.ZERO


func _update_temperature_overlay() -> void:
	if temperature_overlay == null:
		return
	if _temperature_buffer.is_empty():
		temperature_overlay.texture = null
		_overlay_dirty["temperature"] = false
		return
	var image := Image.create(map_size.x, map_size.y, false, Image.FORMAT_RGBA8)
	for y in range(map_size.y):
		for x in range(map_size.x):
			var idx := _xy_to_index(x, y)
			var temperature := float(_temperature_buffer[idx])
			image.set_pixel(x, y, _temperature_to_color(temperature))
	var texture := ImageTexture.create_from_image(image)
	temperature_overlay.texture = texture
	_overlay_dirty["temperature"] = false
	temperature_overlay.centered = false
	temperature_overlay.scale = Vector2(tile_size, tile_size)
	temperature_overlay.position = Vector2.ZERO
	_update_temperature_overlay_visibility()

func _temperature_to_color(temperature: float) -> Color:
	return OVERWORLD_RENDERING.temperature_to_color(temperature)

func _update_temperature_overlay_visibility() -> void:
	if temperature_overlay == null:
		return
	temperature_overlay.visible = _temperature_overlay_enabled and not (_is_globe_view or _is_scene3d_view)

func _update_elevation_overlay() -> void:
	if elevation_overlay == null:
		return
	if _height_buffer.is_empty():
		elevation_overlay.texture = null
		return
	var image := Image.create(map_size.x, map_size.y, false, Image.FORMAT_RGBA8)
	for y in range(map_size.y):
		for x in range(map_size.x):
			var idx := _xy_to_index(x, y)
			var height := float(_height_buffer[idx])
			image.set_pixel(x, y, _elevation_to_color(height))
	var texture := ImageTexture.create_from_image(image)
	elevation_overlay.texture = texture
	_overlay_dirty["elevation"] = false
	elevation_overlay.centered = false
	elevation_overlay.scale = Vector2(tile_size, tile_size)
	elevation_overlay.position = Vector2.ZERO
	_update_elevation_overlay_visibility()

func _elevation_to_color(height: float) -> Color:
	return OVERWORLD_RENDERING.elevation_to_color(height, water_level, mountain_level)

func _update_elevation_overlay_visibility() -> void:
	if elevation_overlay == null:
		return
	elevation_overlay.visible = _elevation_overlay_enabled and not (_is_globe_view or _is_scene3d_view)

## The cliff map: each tile shaded by its elevation gradient against its
## four neighbours, so slopes hillshade and sharp drops burn in dark like
## Dwarf Fortress's cliff view.
func _update_cliffs_overlay() -> void:
	if cliffs_overlay == null:
		return
	if _height_buffer.is_empty():
		cliffs_overlay.texture = null
		_overlay_dirty["cliffs"] = false
		return
	var image := Image.create(map_size.x, map_size.y, false, Image.FORMAT_RGBA8)
	for y in range(map_size.y):
		for x in range(map_size.x):
			image.set_pixel(x, y, _cliff_color_at(x, y))
	var texture := ImageTexture.create_from_image(image)
	cliffs_overlay.texture = texture
	_overlay_dirty["cliffs"] = false
	cliffs_overlay.centered = false
	cliffs_overlay.scale = Vector2(tile_size, tile_size)
	cliffs_overlay.position = Vector2.ZERO
	_update_cliffs_overlay_visibility()

func _cliff_color_at(x: int, y: int) -> Color:
	var height := float(_height_buffer[_xy_to_index(x, y)])
	var west := float(_height_buffer[_xy_to_index(maxi(x - 1, 0), y)])
	var east := float(_height_buffer[_xy_to_index(mini(x + 1, map_size.x - 1), y)])
	var north := float(_height_buffer[_xy_to_index(x, maxi(y - 1, 0))])
	var south := float(_height_buffer[_xy_to_index(x, mini(y + 1, map_size.y - 1))])
	return OVERWORLD_RENDERING.cliff_shade_color(height, west, east, north, south, water_level, mountain_level)

func _update_cliffs_overlay_visibility() -> void:
	if cliffs_overlay == null:
		return
	cliffs_overlay.visible = _cliffs_overlay_enabled and not (_is_globe_view or _is_scene3d_view)

func _update_moisture_overlay() -> void:
	if moisture_overlay == null:
		return
	if _moisture_buffer.is_empty():
		moisture_overlay.texture = null
		_overlay_dirty["moisture"] = false
		return
	var image := Image.create(map_size.x, map_size.y, false, Image.FORMAT_RGBA8)
	for y in range(map_size.y):
		for x in range(map_size.x):
			var idx := _xy_to_index(x, y)
			var moisture := float(_moisture_buffer[idx])
			image.set_pixel(x, y, _moisture_to_color(moisture))
	var texture := ImageTexture.create_from_image(image)
	moisture_overlay.texture = texture
	_overlay_dirty["moisture"] = false
	moisture_overlay.centered = false
	moisture_overlay.scale = Vector2(tile_size, tile_size)
	moisture_overlay.position = Vector2.ZERO
	_update_moisture_overlay_visibility()

func _moisture_to_color(moisture: float) -> Color:
	return OVERWORLD_RENDERING.moisture_to_color(moisture)

func _update_moisture_overlay_visibility() -> void:
	if moisture_overlay == null:
		return
	moisture_overlay.visible = _moisture_overlay_enabled and not (_is_globe_view or _is_scene3d_view)

func _update_biome_overlay() -> void:
	if biome_overlay == null:
		return
	if _biome_buffer.is_empty():
		biome_overlay.texture = null
		_overlay_dirty["biome"] = false
		return
	var image := Image.create(map_size.x, map_size.y, false, Image.FORMAT_RGBA8)
	for y in range(map_size.y):
		for x in range(map_size.x):
			var idx := _xy_to_index(x, y)
			var biome := _biome_id_to_string(int(_biome_buffer[idx]))
			image.set_pixel(x, y, _biome_to_overlay_color(biome))
	var texture := ImageTexture.create_from_image(image)
	biome_overlay.texture = texture
	_overlay_dirty["biome"] = false
	biome_overlay.centered = false
	biome_overlay.scale = Vector2(tile_size, tile_size)
	biome_overlay.position = Vector2.ZERO
	_update_biome_overlay_visibility()


func _update_culture_overlay() -> void:
	if culture_overlay == null:
		return
	if _tile_data.is_empty():
		culture_overlay.texture = null
		_overlay_dirty["culture"] = false
		return
	var image := _culture_pipeline.build_culture_overlay_image(map_size.x, map_size.y, _tile_data, 0.08, 0.62)
	var texture := ImageTexture.create_from_image(image)
	culture_overlay.texture = texture
	_overlay_dirty["culture"] = false
	culture_overlay.centered = false
	culture_overlay.scale = Vector2(tile_size, tile_size)
	culture_overlay.position = Vector2.ZERO
	_update_culture_overlay_visibility()

func _update_culture_overlay_visibility() -> void:
	if culture_overlay == null:
		return
	culture_overlay.visible = _culture_overlay_enabled and not (_is_globe_view or _is_scene3d_view)

func _update_political_boundaries_overlay() -> void:
	if political_boundaries_overlay == null:
		return
	if _tile_data.is_empty():
		political_boundaries_overlay.texture = null
		_overlay_dirty["political_boundaries"] = false
		return
	var image: Image
	var overlay_scale := float(tile_size)
	if _region_mode:
		# Detail view: render the boundary at sub-tile resolution so it reads as
		# a thin line hugging the realm edge instead of a full 8-tile-wide band.
		var sub := RegionMapService.SUB_TILES
		image = _culture_pipeline.build_region_political_boundaries_overlay_image(
			map_size.x, map_size.y, _tile_data, sub
		)
		overlay_scale = float(tile_size) / float(sub)
	else:
		image = _culture_pipeline.build_political_boundaries_overlay_image(map_size.x, map_size.y, _tile_data)
	var texture := ImageTexture.create_from_image(image)
	political_boundaries_overlay.texture = texture
	political_boundaries_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_overlay_dirty["political_boundaries"] = false
	political_boundaries_overlay.centered = false
	political_boundaries_overlay.scale = Vector2(overlay_scale, overlay_scale)
	political_boundaries_overlay.position = Vector2.ZERO
	_rebuild_political_labels()
	_update_political_boundaries_overlay_visibility()

func _update_political_boundaries_overlay_visibility() -> void:
	var overlay_visible := _political_boundaries_overlay_enabled and not (_is_globe_view or _is_scene3d_view)
	if political_boundaries_overlay != null:
		political_boundaries_overlay.visible = overlay_visible
	if political_labels_overlay != null:
		political_labels_overlay.visible = overlay_visible
		if overlay_visible:
			_update_political_labels_zoom_behavior()

## State-name labels: one per realm at its snapped centroid, reusing the
## settlement label service for identical font/outline styling and zoom
## rescale. Realms below POLITICAL_LABEL_MIN_TILES stay unlabeled.
const POLITICAL_LABEL_MIN_TILES := 12
const POLITICAL_LABEL_IMPORTANCE := 5
## Constant-size nation labels stay readable on the overview only if the map
## isn't papered with them, so only the largest realms by area are labeled.
const POLITICAL_LABEL_MAX_COUNT := 22

func _rebuild_political_labels() -> void:
	if political_labels_overlay == null:
		return
	var state_sums: Dictionary = {}
	var state_tiles: Dictionary = {}
	for coord_variant: Variant in _tile_data.keys():
		var coord := coord_variant as Vector2i
		var tile_info := _tile_data.get(coord, {}) as Dictionary
		var state_name := String(tile_info.get("political_state", "")).strip_edges()
		if state_name.is_empty():
			continue
		if not state_sums.has(state_name):
			state_sums[state_name] = Vector2.ZERO
			state_tiles[state_name] = ([] as Array[Vector2i])
		state_sums[state_name] = (state_sums[state_name] as Vector2) + _map_cell_center(coord)
		(state_tiles[state_name] as Array[Vector2i]).append(coord)

	var entries: Array[Dictionary] = []
	for state_variant: Variant in state_sums.keys():
		var state_name := String(state_variant)
		var coords := state_tiles[state_name] as Array[Vector2i]
		var tile_count := coords.size()
		if tile_count < POLITICAL_LABEL_MIN_TILES:
			continue
		var centroid := (state_sums[state_name] as Vector2) / float(tile_count)
		# Snap onto the realm's nearest tile so a concave shape never labels
		# over water or a neighbouring state.
		var anchor := _nearest_state_tile_center(coords, centroid)
		entries.append({
			"center": anchor,
			"name": state_name,
			"category": "capital",
			"importance": POLITICAL_LABEL_IMPORTANCE,
			"population": tile_count
		})

	# Constant-size nation labels must not crowd the overview, so keep the
	# largest realms (by area) and drop the long tail of tiny statelets.
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("population", 0)) > int(b.get("population", 0))
	)
	if entries.size() > POLITICAL_LABEL_MAX_COUNT:
		entries.resize(POLITICAL_LABEL_MAX_COUNT)

	OverworldLabelsService.rebuild(political_labels_overlay, entries, {
		"tile_size": tile_size,
		"map_pixel_size": Vector2(float(map_size.x * tile_size), float(map_size.y * tile_size)),
		"primary_color": labels_overlay_primary_color,
		"secondary_color": labels_overlay_secondary_color,
		"outline_color": labels_overlay_outline_color,
		"outline_size": labels_overlay_outline_size
	})
	_update_political_labels_zoom_behavior()

func _nearest_state_tile_center(coords: Array[Vector2i], centroid: Vector2) -> Vector2:
	var best_center := centroid
	var best_distance := INF
	for coord: Vector2i in coords:
		var center := _map_cell_center(coord)
		var distance := center.distance_squared_to(centroid)
		if distance < best_distance:
			best_distance = distance
			best_center = center
	return best_center

func _update_political_labels_zoom_behavior() -> void:
	if political_labels_overlay == null or overworld_camera == null:
		return
	# Nation names hold a constant on-screen size and stay visible at every
	# zoom, so they read on the world-overview political map (unlike the
	# settlement labels, which fade in only as you zoom toward the ground).
	OverworldLabelsService.update_zoom_behavior(political_labels_overlay, overworld_camera.zoom.x, {
		"tile_size": tile_size,
		"rescale_on_zoom": labels_overlay_rescale_on_zoom,
		"auto_visibility": false,
		"constant_screen_size": true,
		"target_screen_px": 16.0,
		"min_screen_size": labels_overlay_min_screen_size,
		"max_screen_size": labels_overlay_max_screen_size
	})

## --- Caravans -------------------------------------------------------------
## Merchant wagons ride the trade routes between settlements, ping-ponging
## endlessly. Pure map life: they follow the same terrain-following paths
## the routes overlay draws, and stay visible even with the overlay off.

func _spawn_caravans() -> void:
	_caravan_states.clear()
	if _caravans_layer != null:
		_caravans_layer.queue_free()
		_caravans_layer = null
	if routes_overlay == null or _route_segments.is_empty():
		return
	_caravans_layer = Node2D.new()
	_caravans_layer.name = "CaravansOverlay"
	_caravans_layer.z_index = 6
	routes_overlay.get_parent().add_child(_caravans_layer)
	if _caravan_texture == null:
		_caravan_texture = _create_caravan_texture()
	var caravan_rng := RandomNumberGenerator.new()
	caravan_rng.seed = hash("caravans") + _route_segments.size() * 31
	var caravan_count := mini(6, _route_segments.size())
	for _caravan_index in range(caravan_count):
		var path := _route_segments[caravan_rng.randi_range(0, _route_segments.size() - 1)] as PackedVector2Array
		if path.size() < 4:
			continue
		var total_length := 0.0
		for i in range(path.size() - 1):
			total_length += path[i].distance_to(path[i + 1])
		if total_length <= 1.0:
			continue
		var sprite := Sprite2D.new()
		sprite.texture = _caravan_texture
		sprite.centered = true
		_caravans_layer.add_child(sprite)
		_caravan_states.append({
			"path": path,
			"length": total_length,
			"t": caravan_rng.randf_range(0.0, total_length),
			"dir": 1.0 if caravan_rng.randf() < 0.5 else -1.0,
			"speed": caravan_rng.randf_range(9.0, 16.0),
			"sprite": sprite
		})
	_update_caravans(0.0)
	_update_caravans_visibility()

func _update_caravans(delta: float) -> void:
	for state: Dictionary in _caravan_states:
		var sprite := state.get("sprite") as Sprite2D
		if sprite == null:
			continue
		var total_length := float(state.get("length", 1.0))
		var t := float(state.get("t", 0.0)) + float(state.get("speed", 10.0)) * float(state.get("dir", 1.0)) * delta
		if t <= 0.0:
			t = 0.0
			state["dir"] = 1.0
		elif t >= total_length:
			t = total_length
			state["dir"] = -1.0
		state["t"] = t
		var path := state.get("path") as PackedVector2Array
		var remaining := t
		var caravan_position := path[0]
		var heading := Vector2.RIGHT
		for i in range(path.size() - 1):
			var segment_length := path[i].distance_to(path[i + 1])
			if segment_length <= 0.001:
				continue
			if remaining <= segment_length:
				caravan_position = path[i].lerp(path[i + 1], remaining / segment_length)
				heading = path[i + 1] - path[i]
				break
			remaining -= segment_length
			caravan_position = path[i + 1]
		sprite.position = caravan_position
		sprite.flip_h = heading.x * float(state.get("dir", 1.0)) < 0.0

func _update_caravans_visibility() -> void:
	var overlays_visible := not (_is_globe_view or _is_scene3d_view)
	if _caravans_layer != null:
		_caravans_layer.visible = overlays_visible
	if _ships_layer != null:
		_ships_layer.visible = overlays_visible
	if _roads_layer != null:
		# The detailed view redraws roads as dirt tracks inside its own
		# images; the world-scale brushwork would smear over them.
		_roads_layer.visible = overlays_visible and not _region_mode

func _create_caravan_texture() -> Texture2D:
	var image := Image.create(14, 11, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var canopy := Color(0.92, 0.85, 0.7, 1.0)
	var canopy_shade := Color(0.82, 0.73, 0.57, 1.0)
	var body := Color(0.5, 0.34, 0.19, 1.0)
	var wheel := Color(0.22, 0.16, 0.1, 1.0)
	for x in range(3, 11):
		image.set_pixel(x, 1, canopy_shade)
	for y in range(2, 5):
		for x in range(2, 12):
			image.set_pixel(x, y, canopy)
	for y in range(5, 8):
		for x in range(1, 13):
			image.set_pixel(x, y, body)
	for wheel_x: int in [2, 9]:
		for y in range(8, 10):
			image.set_pixel(wheel_x, y, wheel)
			image.set_pixel(wheel_x + 1, y, wheel)
	return ImageTexture.create_from_image(image)

## --- Road tiles -----------------------------------------------------------
## The atlas ships a hand-drawn winding-road set (row 5); routes are laid
## down as real road tiles, bucketed by which edges each cell connects to.
## The dotted trail overlay stays as the toggleable route highlighter.

func _build_road_tiles() -> void:
	if map_layer == null or map_layer.tile_set == null:
		return
	if _roads_layer == null:
		_roads_layer = TileMapLayer.new()
		_roads_layer.name = "RoadsLayer"
		_roads_layer.tile_set = map_layer.tile_set
		var parent := map_layer.get_parent()
		parent.add_child(_roads_layer)
		var highland_index := highland_layer.get_index() if highland_layer != null else map_layer.get_index()
		parent.move_child(_roads_layer, highland_index + 1)
	_roads_layer.clear()
	if _route_segments.is_empty():
		return
	# Collect road cells from the route paths, skipping unroadable ground.
	var road_cells: Dictionary = {}
	for path_variant: Variant in _route_segments:
		var path := path_variant as PackedVector2Array
		for i in range(path.size()):
			var cell := Vector2i(int(floor(path[i].x / float(tile_size))), int(floor(path[i].y / float(tile_size))))
			var tile_info := _tile_data.get(cell, {}) as Dictionary
			if tile_info.is_empty():
				continue
			if tile_info.has("settlement_type") or not String(tile_info.get("structure", "")).strip_edges().is_empty():
				continue
			if _tile_base_biome_from_data(tile_info) == BIOME_WATER:
				continue
			if _tile_has_overlay_flag(tile_info, TILE_OVERLAY_RIVER):
				continue
			road_cells[cell] = true
	for cell_variant: Variant in road_cells.keys():
		var cell := cell_variant as Vector2i
		var mask := 0
		if road_cells.has(cell + Vector2i.UP) or _is_road_endpoint(cell + Vector2i.UP):
			mask |= 1
		if road_cells.has(cell + Vector2i.RIGHT) or _is_road_endpoint(cell + Vector2i.RIGHT):
			mask |= 2
		if road_cells.has(cell + Vector2i.DOWN) or _is_road_endpoint(cell + Vector2i.DOWN):
			mask |= 4
		if road_cells.has(cell + Vector2i.LEFT) or _is_road_endpoint(cell + Vector2i.LEFT):
			mask |= 8
		_roads_layer.set_cell(cell, _atlas_source_id, _road_tile_for_mask(mask, cell))
		# Roads clear the woods they cut through, like the browser overlay.
		if tree_layer != null and tree_layer.get_cell_source_id(cell) >= 0:
			tree_layer.erase_cell(cell)
			# Clear the woodland flags too (mirrors _scatter_lumber_clearing)
			# so the felled tile stops reading as forest to placement filters.
			var road_info := _tile_data.get(cell, {}) as Dictionary
			if not road_info.is_empty():
				road_info["overlay_flags"] = int(road_info.get("overlay_flags", 0)) & ~TILE_OVERLAY_TREE & ~TILE_OVERLAY_FOREST
				_tile_data[cell] = road_info

func _is_road_endpoint(cell: Vector2i) -> bool:
	var tile_info := _tile_data.get(cell, {}) as Dictionary
	if tile_info.is_empty():
		return false
	if tile_info.has("settlement_type"):
		return true
	return ROUTE_ELIGIBLE_STRUCTURE_IDS.has(String(tile_info.get("structure", "")))

## Buckets the 4-neighbor mask (N=1 E=2 S=4 W=8) into the organic road
## art, picking deterministic variants per cell.
func _road_tile_for_mask(mask: int, cell: Vector2i) -> Vector2i:
	var bucket := "stub"
	match mask:
		5:
			bucket = "ns"
		10:
			bucket = "we"
		6:
			bucket = "corner_se"
		12:
			bucket = "corner_sw"
		3:
			bucket = "corner_ne"
		9:
			bucket = "corner_nw"
		1, 4:
			bucket = "ns"
		2, 8:
			bucket = "we"
		_:
			if mask != 0:
				bucket = "junction"
	var variants := TILE_ATLAS_DEFS.ROAD_TILES.get(bucket, TILE_ATLAS_DEFS.ROAD_TILES["stub"]) as Array
	var pick := absi(cell.x * 73856093 ^ cell.y * 19349663) % variants.size()
	return variants[pick] as Vector2i

## --- Desert cities ----------------------------------------------------------
## The atlas's unshipped desert set becomes a real civilization: golden
## palaces rise from the dunes with sandstone walls, a gate, huts, a
## serpent statue, and palm groves around them.

func _place_desert_cities(rng: RandomNumberGenerator, occupied: Array[Vector2i], map_area: int) -> void:
	if settlement_layer == null:
		return
	var candidates: Array[Vector2i] = []
	var desert_id := _biome_to_id(BIOME_DESERT)
	for coord_variant: Variant in _tile_data.keys():
		var coord := coord_variant as Vector2i
		var tile_info := _tile_data.get(coord, {}) as Dictionary
		if int(tile_info.get("base_biome_id", -1)) != desert_id:
			continue
		if int(tile_info.get("overlay_flags", 0)) != 0:
			continue
		if _tile_hill_biome_from_data(tile_info) == BIOME_MOUNTAIN:
			continue
		if tile_info.has("settlement_type") or not String(tile_info.get("structure", "")).strip_edges().is_empty():
			continue
		candidates.append(coord)
	if candidates.is_empty():
		return
	# Prefer sites with open ground around them so the walls, gate, and
	# huts of the compound have room to stand.
	var open_biomes := [_biome_to_id(BIOME_DESERT), _biome_to_id(BIOME_BADLANDS), _biome_to_id(BIOME_GRASSLAND)]
	var scored_candidates: Array[Dictionary] = []
	for candidate: Vector2i in candidates:
		var open_neighbors := 0
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var neighbor_info := _tile_data.get(candidate + Vector2i(dx, dy), {}) as Dictionary
				if neighbor_info.is_empty():
					continue
				if open_biomes.has(int(neighbor_info.get("base_biome_id", -1))) and int(neighbor_info.get("overlay_flags", 0)) == 0 and _tile_hill_biome_from_data(neighbor_info) != BIOME_MOUNTAIN:
					open_neighbors += 1
		scored_candidates.append({"coord": candidate, "open": open_neighbors + (absi(candidate.x * 73856093 ^ candidate.y * 19349663) % 100) / 1000.0})
	scored_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("open", 0.0)) > float(b.get("open", 0.0))
	)
	candidates.clear()
	for scored: Dictionary in scored_candidates:
		candidates.append(scored.get("coord", Vector2i.ZERO) as Vector2i)
	var max_cities := clampi(int(round(float(map_area) / 26000.0)), 1, 8)
	var placed := 0
	for coord: Vector2i in candidates:
		if placed >= max_cities:
			break
		if _is_too_close(coord, occupied, 12.0):
			continue
		var city_name: String = SETTLEMENT_NAMING.desert_city_name(rng)
		settlement_layer.set_cell(coord, _atlas_source_id, TILE_ATLAS_DEFS.DESERT_CITY_TILE)
		var tile_info := _tile_data.get(coord, {}) as Dictionary
		tile_info["settlement_type"] = "desertCity"
		tile_info["settlement_classification"] = "Desert City"
		tile_info["population"] = rng.randi_range(700, 4500)
		tile_info["founded_years_ago"] = rng.randi_range(100, 1500)
		_tile_data[coord] = tile_info
		_tile_region_names[coord] = city_name
		_tile_population_groups[coord] = {"major_population_groups": ["Desert Folk"], "minor_population_groups": ["Humans"]}
		occupied.append(coord)
		_desert_city_points.append(coord)
		_stamp_desert_city_compound(coord, rng, occupied)
		placed += 1

## Sandstone walls flank a gate below the palace; a hut and the serpent
## statue stand beside it, and palms take root in the surrounding dunes.
func _stamp_desert_city_compound(center: Vector2i, rng: RandomNumberGenerator, occupied: Array[Vector2i]) -> void:
	var decorations := [
		{"offset": Vector2i(-1, 1), "tile": TILE_ATLAS_DEFS.DESERT_WALL_A_TILE},
		{"offset": Vector2i(0, 1), "tile": TILE_ATLAS_DEFS.DESERT_GATE_TILE},
		{"offset": Vector2i(1, 1), "tile": TILE_ATLAS_DEFS.DESERT_WALL_B_TILE},
		{"offset": Vector2i(1, 0), "tile": TILE_ATLAS_DEFS.DESERT_HUT_TILE},
		{"offset": Vector2i(-1, 0), "tile": TILE_ATLAS_DEFS.DESERT_SERPENT_STATUE_TILE}
	]
	# Seeded deserts can be small; the compound spreads onto any open dry
	# ground beside the palace (desert, badlands, or grassland).
	var compound_biomes := [_biome_to_id(BIOME_DESERT), _biome_to_id(BIOME_BADLANDS), _biome_to_id(BIOME_GRASSLAND)]
	for decoration: Dictionary in decorations:
		var cell: Vector2i = center + (decoration.get("offset", Vector2i.ZERO) as Vector2i)
		var tile_info := _tile_data.get(cell, {}) as Dictionary
		if tile_info.is_empty() or tile_info.has("settlement_type"):
			continue
		if not compound_biomes.has(int(tile_info.get("base_biome_id", -1))) or int(tile_info.get("overlay_flags", 0)) != 0:
			continue
		if _tile_hill_biome_from_data(tile_info) == BIOME_MOUNTAIN:
			continue
		if not String(tile_info.get("structure", "")).strip_edges().is_empty():
			continue
		if settlement_layer.get_cell_source_id(cell) >= 0:
			continue
		settlement_layer.set_cell(cell, _atlas_source_id, decoration.get("tile") as Vector2i)
		occupied.append(cell)
	# palm groves and cacti in the nearby dunes
	var desert_id := _biome_to_id(BIOME_DESERT)
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var cell := center + Vector2i(dx, dy)
			if absi(dx) <= 1 and absi(dy) <= 1:
				continue
			var tile_info := _tile_data.get(cell, {}) as Dictionary
			if tile_info.is_empty() or tile_info.has("settlement_type"):
				continue
			if int(tile_info.get("base_biome_id", -1)) != desert_id or int(tile_info.get("overlay_flags", 0)) != 0:
				continue
			if not String(tile_info.get("structure", "")).strip_edges().is_empty():
				continue
			if tree_layer == null or tree_layer.get_cell_source_id(cell) >= 0:
				continue
			if rng.randf() < 0.16:
				tree_layer.set_cell(cell, _atlas_source_id, TILE_ATLAS_DEFS.DESERT_PALMS_TILE if rng.randf() < 0.6 else TILE_ATLAS_DEFS.DESERT_CACTI_TILE)

## --- Evil keeps -------------------------------------------------------------
## Villain strongholds on open ground, well away from honest settlements.

func _place_evil_keeps(rng: RandomNumberGenerator, occupied: Array[Vector2i], map_area: int) -> void:
	var candidates: Array[Dictionary] = []
	var allowed_biomes := [_biome_to_id(BIOME_GRASSLAND), _biome_to_id(BIOME_BADLANDS), _biome_to_id(BIOME_TUNDRA)]
	for coord_variant: Variant in _tile_data.keys():
		var coord := coord_variant as Vector2i
		var tile_info := _tile_data.get(coord, {}) as Dictionary
		if not allowed_biomes.has(int(tile_info.get("base_biome_id", -1))):
			continue
		if int(tile_info.get("overlay_flags", 0)) != 0:
			continue
		if _tile_hill_biome_from_data(tile_info) == BIOME_MOUNTAIN:
			continue
		if tile_info.has("settlement_type") or not String(tile_info.get("structure", "")).strip_edges().is_empty():
			continue
		var score := 0.3 + float(absi(coord.x * 73856093 ^ coord.y * 19349663) % 100) / 200.0
		candidates.append({"coord": coord, "score": score})
	_place_scored_structure_batch(candidates, occupied, 12.0, maxi(1, int(round(float(map_area) / 40000.0))), 0.35, TILE_ATLAS_DEFS.EVIL_KEEP_TILE, "evilKeep", rng)

## --- Pirate ships -----------------------------------------------------------
## Sails on the horizon: ships drift across open ocean, turning away from
## coasts, giving the seas the same life caravans give the roads.

func _spawn_pirate_ships() -> void:
	_ship_states.clear()
	if _ships_layer != null:
		_ships_layer.queue_free()
		_ships_layer = null
	var ocean_cells_variant: Variant = _landmass_masks.get("ocean_cells", {})
	if not (ocean_cells_variant is Dictionary):
		return
	var ocean_cells := ocean_cells_variant as Dictionary
	if ocean_cells.size() < 60 or routes_overlay == null:
		return
	_ships_layer = Node2D.new()
	_ships_layer.name = "PirateShipsOverlay"
	_ships_layer.z_index = 6
	routes_overlay.get_parent().add_child(_ships_layer)
	var atlas_texture := load(TILE_ATLAS_DEFS.ATLAS_TEXTURE) as Texture2D
	if atlas_texture == null:
		return
	var ship_rng := RandomNumberGenerator.new()
	ship_rng.seed = hash("pirates") + ocean_cells.size()
	var ocean_list := ocean_cells.keys()
	var ship_count := clampi(ocean_cells.size() / 4000, 2, 5)
	for _ship_index in range(ship_count):
		var start_cell := ocean_list[ship_rng.randi_range(0, ocean_list.size() - 1)] as Vector2i
		var sprite := Sprite2D.new()
		sprite.texture = atlas_texture
		sprite.region_enabled = true
		sprite.region_rect = Rect2(TILE_ATLAS_DEFS.PIRATE_SHIP_TILE.x * tile_size, TILE_ATLAS_DEFS.PIRATE_SHIP_TILE.y * tile_size, tile_size, tile_size)
		sprite.centered = true
		sprite.position = (Vector2(start_cell) + Vector2(0.5, 0.5)) * float(tile_size)
		_ships_layer.add_child(sprite)
		_ship_states.append({
			"sprite": sprite,
			"heading": ship_rng.randf_range(0.0, TAU),
			"speed": ship_rng.randf_range(7.0, 13.0),
			"turn_timer": ship_rng.randf_range(2.0, 6.0)
		})
	_update_caravans_visibility()

func _update_pirate_ships(delta: float) -> void:
	if _ship_states.is_empty():
		return
	var ocean_cells_variant: Variant = _landmass_masks.get("ocean_cells", {})
	if not (ocean_cells_variant is Dictionary):
		return
	var ocean_cells := ocean_cells_variant as Dictionary
	for state: Dictionary in _ship_states:
		var sprite := state.get("sprite") as Sprite2D
		if sprite == null:
			continue
		var heading := float(state.get("heading", 0.0))
		state["turn_timer"] = float(state.get("turn_timer", 3.0)) - delta
		if float(state.get("turn_timer", 0.0)) <= 0.0:
			heading += randf_range(-0.7, 0.7)
			state["turn_timer"] = randf_range(2.0, 6.0)
		var velocity := Vector2(cos(heading), sin(heading)) * float(state.get("speed", 10.0))
		var ahead := sprite.position + velocity * maxf(delta, 0.5) * 2.0
		var ahead_cell := Vector2i(int(floor(ahead.x / float(tile_size))), int(floor(ahead.y / float(tile_size))))
		if not ocean_cells.has(ahead_cell):
			heading += PI * 0.5 + randf_range(-0.4, 0.4)
			state["heading"] = heading
			continue
		state["heading"] = heading
		sprite.position += velocity * delta
		sprite.flip_h = velocity.x < 0.0

## The world finally wears its name: a banner under the top bar showing
## the embark-chosen world name and the current chronology.
func _update_world_name_label() -> void:
	var map_ui := get_node_or_null("MapUi")
	if map_ui == null:
		return
	if _world_name_label == null:
		_world_name_label = Label.new()
		_world_name_label.add_theme_font_size_override("font_size", 15)
		_world_name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78, 1.0))
		_world_name_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06, 0.9))
		_world_name_label.add_theme_constant_override("outline_size", 4)
		_world_name_label.position = Vector2(14.0, 46.0)
		map_ui.add_child(_world_name_label)
	var display_name := _world_name if not _world_name.is_empty() else "Unnamed World"
	_world_name_label.text = "🌍 %s — Year %d" % [display_name, _chronology_year]
	if _is_first_age:
		_world_name_label.text += " of the First Age"

func _update_routes_overlay_visibility() -> void:
	_update_caravans_visibility()
	if routes_overlay == null:
		return
	routes_overlay.visible = _routes_overlay_enabled and not (_is_globe_view or _is_scene3d_view)

func _update_rivers_overlay_visibility() -> void:
	if rivers_overlay == null:
		return
	rivers_overlay.visible = not (_is_globe_view or _is_scene3d_view)

func _update_labels_overlay_visibility() -> void:
	if labels_overlay == null:
		return
	labels_overlay.visible = _labels_overlay_enabled and not (_is_globe_view or _is_scene3d_view)
	if labels_overlay.visible:
		_update_labels_overlay_zoom_behavior()

## Browser drawLocationLabels (main.js:29488-29680): settlements AND named
## structures (castles, monasteries, hillholds, mines, dungeons, shrines,
## towers...) label by importance tier; anything below importance 2 stays
## unlabeled, exactly the browser cutoff.
func _rebuild_labels_overlay() -> void:
	if labels_overlay == null:
		return
	var entries: Array[Dictionary] = []
	for coord_variant: Variant in _tile_data.keys():
		var coord := coord_variant as Vector2i
		var tile_info := _tile_data.get(coord, {}) as Dictionary
		var settlement_type := String(tile_info.get("settlement_type", "")).strip_edges()
		var structure_id := String(tile_info.get("structure", "")).strip_edges()
		if settlement_type.is_empty() and structure_id.is_empty():
			continue
		var region_name := _tile_region_name(coord, tile_info)
		if region_name.is_empty():
			continue
		var classification := String(tile_info.get("settlement_classification", "")).strip_edges()
		var descriptors: Array[String] = []
		# Browser hamlets/villages carry type 'village' (main.js:3913);
		# Godot marks them with is_hamlet / a "Village" classification on
		# the shared "town" settlement type.
		if bool(tile_info.get("is_hamlet", false)) or classification == "Village":
			descriptors.append("village")
		else:
			descriptors.append(settlement_type)
		descriptors.append(classification)
		descriptors.append(structure_id)
		var category := OverworldLabelsService.resolve_label_category(descriptors)
		var importance := OverworldLabelsService.importance_for_category(category)
		if importance < 2:
			continue
		entries.append({
			"center": _map_cell_center(coord),
			"name": region_name,
			"category": category,
			"importance": importance,
			"population": int(tile_info.get("population", 0))
		})
	OverworldLabelsService.rebuild(labels_overlay, entries, {
		"tile_size": tile_size,
		"map_pixel_size": Vector2(float(map_size.x * tile_size), float(map_size.y * tile_size)),
		"primary_color": labels_overlay_primary_color,
		"secondary_color": labels_overlay_secondary_color,
		"outline_color": labels_overlay_outline_color,
		"outline_size": labels_overlay_outline_size
	})
	_update_labels_overlay_zoom_behavior()
	_update_labels_overlay_visibility()

func _update_labels_overlay_zoom_behavior() -> void:
	if labels_overlay == null or overworld_camera == null:
		return
	OverworldLabelsService.update_zoom_behavior(labels_overlay, overworld_camera.zoom.x, {
		"tile_size": tile_size,
		"rescale_on_zoom": labels_overlay_rescale_on_zoom,
		"auto_visibility": labels_overlay_auto_visibility,
		"min_screen_size": labels_overlay_min_screen_size,
		"max_screen_size": labels_overlay_max_screen_size
	})


func _build_routes_overlay_from_settlements() -> void:
	_route_segments.clear()
	if routes_overlay == null:
		return

	var settlement_cells: Array[Vector2i] = []
	for coord_variant: Variant in _tile_data.keys():
		var coord := coord_variant as Vector2i
		var tile_info := _tile_data.get(coord, {}) as Dictionary
		if String(tile_info.get("settlement_type", "")).strip_edges().is_empty():
			# Browser roads also serve the wayside stops: taverns, camps,
			# and wizard towers all join the route network.
			if not ROUTE_ELIGIBLE_STRUCTURE_IDS.has(String(tile_info.get("structure", ""))):
				continue
		settlement_cells.append(coord)

	if settlement_cells.size() < 2:
		_refresh_routes_overlay_lines()
		return

	var max_distance := maxf(8.0, float(mini(map_size.x, map_size.y)) * route_overlay_max_distance_ratio)
	var desired_connections := maxi(1, route_overlay_target_connections)
	var edge_set: Dictionary = {}
	var route_edges: Array = []

	var connected: Dictionary = {}
	connected[settlement_cells[0]] = true
	while connected.size() < settlement_cells.size():
		var best_from := Vector2i(-1, -1)
		var best_to := Vector2i(-1, -1)
		var best_distance := INF
		for from_coord_variant: Variant in connected.keys():
			var from_coord := from_coord_variant as Vector2i
			for candidate_coord: Vector2i in settlement_cells:
				if connected.has(candidate_coord):
					continue
				var dist := from_coord.distance_to(candidate_coord)
				if dist < best_distance:
					best_distance = dist
					best_from = from_coord
					best_to = candidate_coord
		if best_to == Vector2i(-1, -1):
			break
		_add_route_edge(best_from, best_to, edge_set, route_edges)
		connected[best_to] = true

	for from_coord: Vector2i in settlement_cells:
		var nearby: Array[Dictionary] = []
		for to_coord: Vector2i in settlement_cells:
			if to_coord == from_coord:
				continue
			var dist := from_coord.distance_to(to_coord)
			if dist > max_distance:
				continue
			nearby.append({"coord": to_coord, "distance": dist})
		nearby.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("distance", INF)) < float(b.get("distance", INF))
		)
		for i in range(mini(desired_connections, nearby.size())):
			var entry := nearby[i] as Dictionary
			_add_route_edge(from_coord, entry.get("coord", from_coord) as Vector2i, edge_set, route_edges)

	var route_paths := ROUTES_SERVICE.build_paths(route_edges, _build_route_cost_map(), map_size, tile_size)
	for path in route_paths:
		_route_segments.append(path)
	_refresh_routes_overlay_lines()
	_build_road_tiles()
	_spawn_caravans()
	_spawn_pirate_ships()
	_update_world_name_label()

func _add_route_edge(a: Vector2i, b: Vector2i, edge_set: Dictionary, route_edges: Array) -> void:
	if a == b:
		return
	var key_a := "%d,%d" % [a.x, a.y]
	var key_b := "%d,%d" % [b.x, b.y]
	var ordered_key := "%s|%s" % [key_a, key_b] if key_a < key_b else "%s|%s" % [key_b, key_a]
	if edge_set.has(ordered_key):
		return
	edge_set[ordered_key] = true
	route_edges.append({"a": a, "b": b})

func _build_route_cost_map() -> Dictionary:
	var tile_biomes: Dictionary = {}
	for coord_variant: Variant in _tile_data.keys():
		var tile_info := _tile_data.get(coord_variant, {}) as Dictionary
		tile_biomes[coord_variant] = {
			"base": _tile_base_biome_from_data(tile_info),
			"hill": _tile_hill_biome_from_data(tile_info),
			"river": _tile_has_overlay_flag(tile_info, TILE_OVERLAY_RIVER)
		}
	return ROUTES_SERVICE.build_cost_map(tile_biomes, {
		"water": BIOME_WATER,
		"mountain": BIOME_MOUNTAIN,
		"hills": BIOME_HILLS,
		"marsh": BIOME_MARSH,
		"forest": BIOME_FOREST,
		"jungle": BIOME_JUNGLE
	})

func _map_cell_center(coord: Vector2i) -> Vector2:
	return OVERWORLD_INTERACTION.map_cell_center(coord, tile_size)

func _refresh_routes_overlay_lines() -> void:
	if routes_overlay == null:
		return
	for child in routes_overlay.get_children():
		child.queue_free()
	var trail_paths: Array[PackedVector2Array] = []
	for segment_variant: Variant in _route_segments:
		var segment := segment_variant as PackedVector2Array
		if segment.size() < 2:
			continue
		trail_paths.append(segment)
	if not trail_paths.is_empty():
		var drawer := ROUTES_SERVICE.RouteTrailDrawer.new()
		drawer.paths = trail_paths
		drawer.dot_color = route_overlay_line_color
		drawer.dot_size = maxf(3.0, route_overlay_line_width * 3.0)
		routes_overlay.add_child(drawer)
	_update_routes_overlay_visibility()

func _biome_to_overlay_color(biome: String) -> Color:
	return OVERWORLD_RENDERING.biome_to_overlay_color(biome)

func _update_biome_overlay_visibility() -> void:
	if biome_overlay == null:
		return
	biome_overlay.visible = _biome_overlay_enabled and not (_is_globe_view or _is_scene3d_view)

func _seed_to_map_seed(seed_setting: Variant) -> int:
	var seed_text := str(seed_setting).strip_edges()
	if seed_text.is_empty():
		return map_seed
	if seed_text.is_valid_int():
		return int(seed_text)
	return int(seed_text.hash())

func _apply_terrain_ratio_settings(terrain_ratios: Dictionary) -> void:
	var forest_ratio := clampf(float(terrain_ratios.get("forest", 0.5)), 0.0, 1.0)
	var mountain_ratio := clampf(float(terrain_ratios.get("mountain", 0.5)), 0.0, 1.0)
	var river_ratio := clampf(float(terrain_ratios.get("river", 0.5)), 0.0, 1.0)

	# Browser parity: every slider drives only its own feature pass and none
	# of them reshape the heightfield, the sea level or the landmass falloff.
	# River (main.js:20588-20628) -> buildRiverMap frequency knobs.
	# Mountain (main.js:21325-21331) -> mountainBias, which shifts the ridge
	# seed/candidate/prune thresholds and the growth factor inside
	# _build_highland_overlays.
	# Forest (main.js:21300-21306) -> forestBias, which scales tree seeding
	# thresholds, growth and density inside _apply_tree_overlays.
	river_frequency = river_ratio
	_mountain_ratio = mountain_ratio
	_forest_bias = clampf((forest_ratio - 0.5) * 2.0, -1.5, 1.5)

func _apply_cached_world_settings() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null:
		return
	if game_session.has_method("get_world_settings"):
		var settings: Dictionary = game_session.call("get_world_settings")
		if game_session.has_method("get_world_settings_with_defaults"):
			settings = game_session.call("get_world_settings_with_defaults", settings)
		_world_settings = settings.duplicate(true)
		if settings.has("map_dimensions"):
			map_size = settings["map_dimensions"]
		if settings.has("world_seed"):
			map_seed = _seed_to_map_seed(settings["world_seed"])
		if settings.has("world_layout"):
			var layout_preset := WorldSettings.layout_generation_preset(str(settings["world_layout"]))
			landmass_center_count = int(layout_preset.get("landmass_center_count", 4))
			landmass_center_min_separation = float(layout_preset.get("landmass_center_min_separation", 0.0))
			center_shape_strength = float(layout_preset.get("center_shape_strength", 1.0))
			landmass_mask_strength = float(layout_preset.get("landmass_mask_strength", 0.24))
			landmass_mask_scale = float(layout_preset.get("landmass_mask_scale", 1.0))
			landmass_mask_threshold = float(layout_preset.get("landmass_mask_threshold", 0.47))
			landmass_mask_edge_falloff = float(layout_preset.get("landmass_mask_edge_falloff", 0.26))
			falloff_strength = float(layout_preset.get("falloff_strength", 0.08))
			landmass_falloff_scale = float(layout_preset.get("landmass_falloff_scale", 1.35))
			edge_ocean_strength = float(layout_preset.get("edge_ocean_strength", 0.2))
			edge_ocean_falloff = float(layout_preset.get("edge_ocean_falloff", 0.32))
			water_level = float(layout_preset.get("water_level", 0.45))
			# Refresh the regen baseline so preset changes propagate.
			_layout_water_level = water_level
			falloff_power = float(layout_preset.get("falloff_power", 2.4))
			# Browser worldGenerationProfiles (main.js:20044-20108).
			_sea_level_shift = float(layout_preset.get("sea_level_shift", 0.02))
			_rainfall_bias = float(layout_preset.get("rainfall_bias", 0.0))
		if settings.has("terrain_ratios") and settings["terrain_ratios"] is Dictionary:
			_apply_terrain_ratio_settings(settings["terrain_ratios"])
		_world_name = String(settings.get("world_name", "")).strip_edges()
		var chronology := settings.get("chronology", {}) as Dictionary
		_chronology_year = maxi(1, int(chronology.get("year", 1000)))
		# First-age worlds (browser isFirstAge) are young and untamed:
		# forests seed easier and are allowed to blanket far more land.
		var age_number := _chronology_age_number(chronology.get("age"))
		_is_first_age = age_number == 1
		if _is_first_age:
			forest_threshold = maxf(0.2, forest_threshold - 0.12)
			forest_max_coverage = clampf(forest_max_coverage * 1.5, 0.2, 0.95)
	_configure_globe_viewport()
	_update_globe_texture()


## --- The detailed region map ------------------------------------------------
## Double-clicking the world map switches the WHOLE map into a Dwarf
## Fortress-style detailed view: every overworld tile re-rendered as its
## 64 walkable surface cells (the same terrain function the town wilds
## stream from), streamed in around the camera as you pan and zoom with
## the usual controls. Esc returns to the painted overworld.

func _region_world_seed_text() -> String:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null and game_session.has_method("get_world_settings"):
		var settings: Dictionary = game_session.call("get_world_settings")
		if settings.has("world_seed"):
			return str(settings.get("world_seed"))
	return str(map_seed)

func _region_biome_for_tile(tile: Vector2i) -> String:
	return String(_biome_map.get(tile, BIOME_GRASSLAND))

func _region_river_for_tile(tile: Vector2i) -> bool:
	return _tile_has_overlay_flag(_tile_data.get(tile, {}) as Dictionary, TILE_OVERLAY_RIVER)

func _region_road_for_tile(tile: Vector2i) -> bool:
	return _roads_layer != null and _roads_layer.get_cell_source_id(tile) >= 0

## The detail sprites live on a sibling of the tile layers so hiding the
## painted map leaves them (and the settlement layer above) untouched.
func _ensure_region_layer() -> void:
	if _region_layer != null:
		return
	_region_layer = Node2D.new()
	_region_layer.name = "RegionDetailLayer"
	add_child(_region_layer)
	if map_layer != null:
		_region_layer.transform = map_layer.transform
		move_child(_region_layer, map_layer.get_index() + 1)

## Small settlement/structure icons for region mode. Parented to the detail
## layer so they share the map transform; z_index keeps them above the detail
## tiles that stream in as siblings of the parent afterwards.
func _ensure_region_icon_layer() -> void:
	if _region_icon_layer != null:
		return
	_ensure_region_layer()
	if _region_layer == null:
		return
	_region_icon_layer = Node2D.new()
	_region_icon_layer.name = "RegionIconLayer"
	_region_icon_layer.z_index = 50
	_region_layer.add_child(_region_icon_layer)

func _clear_region_icons() -> void:
	if _region_icon_layer == null:
		return
	for child: Node in _region_icon_layer.get_children():
		child.queue_free()

## Population centers a walker can actually enter; everything else painted
## on the settlement layer (camps, towers, shrines, caves, mines...) is an
## ambient structure and reads as a single detail tile in the region view.
const REGION_MAJOR_SETTLEMENT_TYPES := {
	"town": true,
	"dwarfhold": true,
	"desertCity": true,
	"woodElfGrove": true,
	"lizardmenCity": true
}

## Draws each painted settlement_layer cell as a small sprite centered on its
## tile and bottom-anchored to the lower edge, so a site "sits" on the ground
## instead of tiling the whole 8x8 footprint. Major settlements keep a chunky
## quarter-tile mark; ambient structures shrink to exactly one detail tile.
func _build_region_icons() -> void:
	_ensure_region_icon_layer()
	if _region_icon_layer == null or settlement_layer == null:
		return
	_clear_region_icons()
	var tile_set := settlement_layer.tile_set
	if tile_set == null or _atlas_source_id < 0:
		return
	var src := tile_set.get_source(_atlas_source_id) as TileSetAtlasSource
	if src == null or src.texture == null:
		return
	var atlas_texture := src.texture
	var native_px := src.texture_region_size
	if native_px.x <= 0 or native_px.y <= 0:
		return
	# Major settlements read as roughly a quarter of the overworld tile
	# (2-2.5 detail cells of 8); ambient structures are one detail tile.
	var major_scale := (float(tile_size) * 0.3) / float(native_px.x)
	var ambient_scale := (float(tile_size) / float(RegionMapService.SUB_TILES)) / float(native_px.x)
	var occupied_cells: Dictionary = {}
	for cell: Vector2i in settlement_layer.get_used_cells():
		occupied_cells[cell] = true
		var atlas_coords := settlement_layer.get_cell_atlas_coords(cell)
		if atlas_coords.x < 0:
			continue
		var details := _tile_data.get(cell, {}) as Dictionary
		# Felled/tilled tiles render their stumps or crop rows as ground in the
		# detail view, so they need no separate icon on top.
		var ground_structure := String(details.get("structure", ""))
		if ground_structure == "cutWoods" or ground_structure == "farmField":
			continue
		var settlement_type := String(details.get("settlement_type", "")).strip_edges()
		var is_major := REGION_MAJOR_SETTLEMENT_TYPES.has(settlement_type)
		var icon_scale := major_scale if is_major else ambient_scale
		_add_region_icon(atlas_texture, native_px, atlas_coords, cell, icon_scale)
	# Detail-only ambient sites: extra culturally-placed marks that never reach
	# the world map, surfacing only in this zoomed-in view for a denser world.
	for coord_variant: Variant in _tile_data.keys():
		var cell := coord_variant as Vector2i
		if occupied_cells.has(cell):
			continue
		var details := _tile_data.get(coord_variant, {}) as Dictionary
		var detail_ambient: Variant = details.get("detail_ambient_structure", null)
		if not (detail_ambient is Dictionary):
			continue
		var ambient_dict := detail_ambient as Dictionary
		if not ambient_dict.has("tile"):
			continue
		# Roads carry their own art in the detail render; keep sites off them.
		if _roads_layer != null and _roads_layer.get_cell_source_id(cell) >= 0:
			continue
		_add_region_icon(atlas_texture, native_px, ambient_dict.get("tile", Vector2i.ZERO) as Vector2i, cell, ambient_scale)

## Places one bottom-anchored region-view sprite for a site on its tile.
func _add_region_icon(atlas_texture: Texture2D, native_px: Vector2i, atlas_coords: Vector2i, cell: Vector2i, icon_scale: float) -> void:
	if atlas_coords.x < 0 or atlas_coords.y < 0:
		return
	var on_screen := Vector2(native_px) * icon_scale
	var sprite := Sprite2D.new()
	sprite.texture = atlas_texture
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2(atlas_coords * native_px), Vector2(native_px))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.scale = Vector2.ONE * icon_scale
	var origin := Vector2(cell * tile_size)
	sprite.position = Vector2(
		origin.x + (float(tile_size) - on_screen.x) * 0.5,
		origin.y + float(tile_size) - on_screen.y
	)
	_region_icon_layer.add_child(sprite)

func _ensure_region_hint() -> void:
	if _region_hint_panel != null:
		return
	var ui_parent := tooltip_panel.get_parent() if tooltip_panel != null else self
	_region_hint_panel = PanelContainer.new()
	_region_hint_panel.name = "RegionModeHint"
	var hint_style := StyleBoxFlat.new()
	hint_style.bg_color = Color(0.045, 0.045, 0.055, 0.92)
	hint_style.border_color = Color(0.92, 0.62, 0.16, 1.0)
	hint_style.set_border_width_all(2)
	hint_style.set_content_margin_all(8)
	_region_hint_panel.add_theme_stylebox_override("panel", hint_style)
	_region_hint_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_region_hint_panel.position = Vector2(-370.0, -52.0)
	_region_hint_panel.custom_minimum_size = Vector2(740.0, 0.0)
	var hint_label := Label.new()
	hint_label.text = "Detailed view — pan and zoom as ever · double-click a settlement to travel · Esc returns to the world map"
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_region_hint_panel.add_child(hint_label)
	ui_parent.add_child(_region_hint_panel)

## Settlement anchors (world-cell centers) shade the deep wilds darker,
## the same radial danger rule the walker feels on the ground.
func _refresh_region_site_anchors() -> void:
	_region_site_anchors = []
	for coord_variant: Variant in _tile_data.keys():
		var details := _tile_data.get(coord_variant, {}) as Dictionary
		if String(details.get("settlement_type", "")).strip_edges().is_empty():
			continue
		var coord := coord_variant as Vector2i
		_region_site_anchors.append(coord * RegionMapService.CELLS_PER_TILE + Vector2i(RegionMapService.CELLS_PER_TILE / 2, RegionMapService.CELLS_PER_TILE / 2))

func _enter_region_mode() -> void:
	if _region_mode:
		return
	_region_mode = true
	# Lift the zoom cap so the tile art can be inspected up close, keeping
	# the world-map cap to restore when the detailed view closes.
	if overworld_camera != null:
		if _world_map_max_zoom < 0.0:
			_world_map_max_zoom = overworld_camera.max_zoom
		overworld_camera.max_zoom = REGION_MAX_ZOOM
		# The detail streamer only fills a band around the camera
		# (_camera_visible_tile_rect cap): raise the zoom floor so the
		# viewport can never outgrow the band into blank void. Recomputed
		# on window resize — the floor depends on the viewport size.
		if _world_map_min_zoom < 0.0:
			_world_map_min_zoom = overworld_camera.min_zoom
		_update_region_zoom_floor()
		if not get_viewport().size_changed.is_connected(_update_region_zoom_floor):
			get_viewport().size_changed.connect(_update_region_zoom_floor)
	_ensure_region_layer()
	_ensure_region_hint()
	if _region_noise.is_empty():
		_region_noise = SurfaceWorldService.make_noise_set(hash("surface|%s" % _region_world_seed_text()))
	_refresh_region_site_anchors()
	_set_base_map_layers_visible(false)
	# The settlement layer paints one full overworld-tile icon per site, which
	# swamps an 8x8 detail footprint; small anchored sprites stand in instead.
	if settlement_layer != null:
		settlement_layer.visible = false
	_build_region_icons()
	_region_layer.visible = true
	_region_hint_panel.visible = true
	# A synchronous first ring lands the switch on detail instantly;
	# worker threads flood the rest of the screen in parallel.
	_queue_visible_region_tiles()
	var budget := REGION_ENTER_BUDGET
	while budget > 0 and not _region_render_queue.is_empty():
		_render_region_tile(_region_render_queue.pop_front() as Vector2i)
		budget -= 1
	_dispatch_region_jobs()
	# The overlay resolution differs between world and detail view, so the
	# cached texture is stale for this mode even while the toggle is OFF —
	# mark it dirty unconditionally or re-enabling it later shows the
	# wrong-resolution borders.
	_overlay_dirty["political_boundaries"] = true
	if _political_boundaries_overlay_enabled:
		_ensure_overlay_texture("political_boundaries")

func _exit_region_mode() -> void:
	if not _region_mode:
		return
	_region_mode = false
	# Restore the world-map zoom cap and pull the camera back under it, so a
	# close detail zoom doesn't strand the world map over-magnified.
	if overworld_camera != null and _world_map_max_zoom > 0.0:
		overworld_camera.max_zoom = _world_map_max_zoom
		if overworld_camera.zoom.x > _world_map_max_zoom:
			overworld_camera.adjust_zoom(_world_map_max_zoom - overworld_camera.zoom.x)
	if overworld_camera != null and _world_map_min_zoom > 0.0:
		overworld_camera.min_zoom = _world_map_min_zoom
		_world_map_min_zoom = -1.0
	if get_viewport() != null and get_viewport().size_changed.is_connected(_update_region_zoom_floor):
		get_viewport().size_changed.disconnect(_update_region_zoom_floor)
	_region_render_queue.clear()
	_region_queued.clear()
	if _region_layer != null:
		_region_layer.visible = false
	_clear_region_icons()
	if settlement_layer != null:
		settlement_layer.visible = true
	if _region_hint_panel != null:
		_region_hint_panel.visible = false
	_set_base_map_layers_visible(true)
	# Let the LOD rule re-decide snapshot-vs-tiles for the current zoom.
	_map_lod_active = false
	if _map_snapshot_sprite != null:
		_map_snapshot_sprite.visible = false
	_update_map_lod()
	# Restore the coarse world-map boundary overlay when leaving detail view.
	# Dirty unconditionally: even with the toggle off, the cached texture
	# belongs to the other mode's resolution now.
	_overlay_dirty["political_boundaries"] = true
	if _political_boundaries_overlay_enabled:
		_ensure_overlay_texture("political_boundaries")

## The region floor keeps the viewport inside the streamed detail band;
## it depends on the live viewport size, so window resizes re-derive it.
func _update_region_zoom_floor() -> void:
	if not _region_mode or overworld_camera == null:
		return
	var region_view := get_viewport().get_visible_rect().size
	var band := Vector2(REGION_STREAM_HALF_TILES * 2) * float(tile_size)
	var floor_zoom := maxf(region_view.x / band.x, region_view.y / band.y)
	var base_min := _world_map_min_zoom if _world_map_min_zoom > 0.0 else overworld_camera.min_zoom
	overworld_camera.min_zoom = maxf(base_min, floor_zoom)
	if overworld_camera.zoom.x < overworld_camera.min_zoom:
		overworld_camera.adjust_zoom(overworld_camera.min_zoom - overworld_camera.zoom.x)

func _set_base_map_layers_visible(layers_visible: bool) -> void:
	for layer: TileMapLayer in [map_layer, tree_layer, river_layer, highland_layer, iceberg_layer, _coast_layer]:
		if layer != null:
			layer.visible = layers_visible
	if terrain_shading_overlay != null:
		terrain_shading_overlay.visible = layers_visible
	# Roads are world-scale brush art; the detail images draw their own.
	_update_caravans_visibility()
	if not layers_visible and _map_snapshot_sprite != null:
		_map_snapshot_sprite.visible = false

func _camera_center_tile() -> Vector2i:
	if overworld_camera == null or map_layer == null:
		return map_size / 2
	var local := map_layer.to_local(overworld_camera.global_position)
	return Vector2i(int(floor(local.x / float(tile_size))), int(floor(local.y / float(tile_size))))

## The tiles the camera can currently see, plus a streaming margin. The
## window is capped below the sprite cache so extreme zoom-outs stream a
## band around the camera instead of thrashing the whole world through it.
func _camera_visible_tile_rect(margin: int) -> Rect2i:
	var center := _camera_center_tile()
	var half := Vector2i(9, 6)
	if overworld_camera != null:
		var view := get_viewport().get_visible_rect().size
		var zoom := maxf(overworld_camera.zoom.x, 0.05)
		half = Vector2i(
			int(ceil(view.x / (zoom * float(tile_size) * 2.0))),
			int(ceil(view.y / (zoom * float(tile_size) * 2.0)))
		)
	half += Vector2i(margin, margin)
	half.x = mini(half.x, REGION_STREAM_HALF_TILES.x)
	half.y = mini(half.y, REGION_STREAM_HALF_TILES.y)
	var top_left := (center - half).clamp(Vector2i.ZERO, map_size - Vector2i.ONE)
	var bottom_right := (center + half).clamp(Vector2i.ZERO, map_size - Vector2i.ONE)
	return Rect2i(top_left, bottom_right - top_left + Vector2i.ONE)

func _queue_visible_region_tiles() -> void:
	var rect := _camera_visible_tile_rect(2)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var tile := Vector2i(x, y)
			if _region_sprites.has(tile) or _region_queued.has(tile):
				continue
			_region_render_queue.append(tile)
			_region_queued[tile] = true
	if _region_render_queue.size() > 1:
		var center := _camera_center_tile()
		_region_render_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return Vector2(a - center).length_squared() < Vector2(b - center).length_squared())

## Runs every frame while the mode is on: finished worker renders become
## sprites, and fresh jobs fan out across the thread pool - the screen
## fills in parallel instead of ten tiles a frame.
func _stream_region_tiles() -> void:
	_queue_visible_region_tiles()
	_collect_region_jobs()
	_dispatch_region_jobs()
	_evict_far_region_tiles()

## Everything a worker thread needs, snapshotted on the main thread:
## neighbor water/river-ness for coastline and river-course blending,
## danger at the four corners (interpolated per cell - settlement lists
## are too long to scan 4096 times per tile), and iceberg placement.
func _make_region_job(tile: Vector2i) -> Dictionary:
	var water := PackedFloat32Array()
	water.resize(9)
	var rivers := PackedFloat32Array()
	rivers.resize(9)
	var roads := PackedFloat32Array()
	roads.resize(9)
	var biomes := PackedStringArray()
	biomes.resize(9)
	var canopy := PackedFloat32Array()
	canopy.resize(9)
	var own_biome := _region_biome_for_tile(tile)
	var own_water := 1.0 if own_biome == TILE_ATLAS_DEFS.BIOME_WATER else 0.0
	var own_canopy := float((_tile_data.get(tile, {}) as Dictionary).get("forest_canopy_density", 0.0))
	for ny in 3:
		for nx in 3:
			var neighbor := tile + Vector2i(nx - 1, ny - 1)
			var index := ny * 3 + nx
			if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= map_size.x or neighbor.y >= map_size.y:
				water[index] = own_water
				rivers[index] = 0.0
				roads[index] = 0.0
				biomes[index] = own_biome
				canopy[index] = own_canopy
				continue
			water[index] = 1.0 if _region_biome_for_tile(neighbor) == TILE_ATLAS_DEFS.BIOME_WATER else 0.0
			rivers[index] = 1.0 if _region_river_for_tile(neighbor) else 0.0
			roads[index] = 1.0 if _region_road_for_tile(neighbor) else 0.0
			biomes[index] = _region_biome_for_tile(neighbor)
			canopy[index] = float((_tile_data.get(neighbor, {}) as Dictionary).get("forest_canopy_density", 0.0))
	var corners := PackedFloat32Array()
	corners.resize(4)
	var origin := tile * RegionMapService.CELLS_PER_TILE
	var span := RegionMapService.CELLS_PER_TILE
	corners[0] = RegionMapService.danger_for_world_cell(origin, _region_site_anchors)
	corners[1] = RegionMapService.danger_for_world_cell(origin + Vector2i(span, 0), _region_site_anchors)
	corners[2] = RegionMapService.danger_for_world_cell(origin + Vector2i(0, span), _region_site_anchors)
	corners[3] = RegionMapService.danger_for_world_cell(origin + Vector2i(span, span), _region_site_anchors)
	var has_iceberg := iceberg_layer != null and iceberg_layer.get_cell_source_id(tile) >= 0
	var iceberg_art := Vector2i(-1, -1)
	if has_iceberg:
		iceberg_art = iceberg_layer.get_cell_atlas_coords(tile)
	var tile_ruggedness := float((_tile_data.get(tile, {}) as Dictionary).get("mountain_ruggedness", 0.45))
	if tile_ruggedness <= 0.0:
		tile_ruggedness = 0.45
	# A lumber mill and the tiles it felled render as a logged clearing; a
	# farm's felled-out plots render as a contiguous crop field beside it.
	var tile_structure := String((_tile_data.get(tile, {}) as Dictionary).get("structure", ""))
	var is_clearing := tile_structure == "lumber_mill" or tile_structure == "cutWoods"
	var is_farm_field := tile_structure == "farmField"
	return RegionMapService.make_render_job(
		_region_world_seed_text(), tile,
		own_biome, _region_river_for_tile(tile),
		has_iceberg, water, rivers, corners, tile_ruggedness,
		biomes, roads,
		_region_tileset_image(), tile_size, iceberg_art, canopy, is_clearing, is_farm_field
	)

## The worldmap atlas as a plain RGBA image the render workers can read:
## the detailed view draws with the SAME tiles as the map, DF-style.
var _region_tileset_cache: Image = null

func _region_tileset_image() -> Image:
	if _region_tileset_cache != null:
		return _region_tileset_cache
	var atlas_texture := load(TILE_ATLAS_DEFS.ATLAS_TEXTURE) as Texture2D
	if atlas_texture == null:
		return null
	var atlas_image := atlas_texture.get_image()
	if atlas_image == null:
		return null
	if atlas_image.is_compressed():
		atlas_image.decompress()
	atlas_image.convert(Image.FORMAT_RGBA8)
	_region_tileset_cache = atlas_image
	return _region_tileset_cache

## Synchronous render for the first screenful on entry.
func _render_region_tile(tile: Vector2i) -> void:
	_region_queued.erase(tile)
	if _region_sprites.has(tile) or _region_layer == null:
		return
	var job := _make_region_job(tile)
	RegionMapService.render_job(job)
	_apply_region_job(tile, job)

func _apply_region_job(tile: Vector2i, job: Dictionary) -> void:
	if _region_sprites.has(tile) or _region_layer == null:
		return
	var image := job.get("image") as Image
	if image == null:
		return
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(tile * tile_size)
	sprite.scale = Vector2.ONE * (float(tile_size) / float(image.get_width()))
	_region_layer.add_child(sprite)
	_region_sprites[tile] = sprite

func _dispatch_region_jobs() -> void:
	# Keep the pool's queue deep: dispatch happens once per frame, so
	# capping in-flight jobs at the core count would starve workers
	# between frames and throttle streaming to one batch per frame.
	var max_inflight := clampi(OS.get_processor_count() * 12, 48, 192)
	while _region_jobs.size() < max_inflight and not _region_render_queue.is_empty():
		var tile := _region_render_queue.pop_front() as Vector2i
		if _region_sprites.has(tile):
			_region_queued.erase(tile)
			continue
		var job := _make_region_job(tile)
		var task_id := WorkerThreadPool.add_task(RegionMapService.render_job.bind(job), false, "region detail tile")
		_region_jobs.append({"tile": tile, "task": task_id, "job": job, "stamp": _region_cache_stamp})

func _collect_region_jobs() -> void:
	var index := 0
	while index < _region_jobs.size():
		var entry := _region_jobs[index]
		var task_id := int(entry.get("task", -1))
		if not WorkerThreadPool.is_task_completed(task_id):
			index += 1
			continue
		WorkerThreadPool.wait_for_task_completion(task_id)
		_region_jobs.remove_at(index)
		var tile := entry.get("tile", Vector2i.ZERO) as Vector2i
		_region_queued.erase(tile)
		# Results from before a regenerate describe a world that no
		# longer exists.
		if int(entry.get("stamp", -1)) != _region_cache_stamp:
			continue
		_apply_region_job(tile, entry.get("job", {}) as Dictionary)

func _evict_far_region_tiles() -> void:
	if _region_sprites.size() <= REGION_KEEP_TILES:
		return
	var keep_rect := _camera_visible_tile_rect(3)
	var center := _camera_center_tile()
	var candidates: Array[Vector2i] = []
	for tile_variant: Variant in _region_sprites.keys():
		var tile := tile_variant as Vector2i
		if not keep_rect.has_point(tile):
			candidates.append(tile)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a - center).length_squared() > Vector2(b - center).length_squared())
	var to_remove := _region_sprites.size() - REGION_KEEP_TILES
	for tile: Vector2i in candidates:
		if to_remove <= 0:
			break
		var sprite := _region_sprites.get(tile) as Sprite2D
		if sprite != null:
			sprite.queue_free()
		_region_sprites.erase(tile)
		to_remove -= 1
