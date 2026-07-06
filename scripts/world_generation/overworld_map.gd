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
@export_range(0.0, 1.0, 0.01) var iceberg_temperature_threshold: float = 0.32
@export_range(0.0, 1.0, 0.01) var iceberg_density: float = 0.12
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
const SETTLEMENT_TILES := {
	"dwarfhold": [DWARFHOLD_TILE, ABANDONED_DWARFHOLD_TILE, GREAT_DWARFHOLD_TILE, DARK_DWARFHOLD_TILE],
	"town": [TOWN_TILE, PORT_TOWN_TILE, CASTLE_TILE, HAMLET_TILE],
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
const _BIOME_RESOURCES_BY_ID := {
	0: ["fish", "salt"],
	1: ["stone", "iron", "gems"],
	2: ["stone", "game", "herbs"],
	3: ["reeds", "peat", "herbs"],
	4: ["fur", "ice", "hardwood"],
	5: ["spice", "glass", "salt"],
	6: ["clay", "copper", "scrub"],
	7: ["timber", "game", "berries"],
	8: ["exotic wood", "fruit", "spices"],
	9: ["grain", "livestock", "herbs"]
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
const DWARFHOLD_RULER_TITLES: Array[String] = [
	"Thane",
	"High Thane",
	"Forge-Lord",
	"Shieldthane",
	"Deepwarden",
	"Runesmith",
	"Iron Regent"
]
const DARK_DWARFHOLD_RULER_TITLES: Array[String] = [
	"Sorcerer-Prophet",
	"Ash Lord",
	"Obsidian Warden",
	"Flame Regent",
	"Deep Ember"
]
const DWARFHOLD_RULER_NAMES: Array[String] = [
	"Urist",
	"Thrain",
	"Borin",
	"Durin",
	"Gimli",
	"Khazad",
	"Rurik",
	"Dwalin",
	"Oin",
	"Fundin",
	"Balin",
	"Kili",
	"Thorin",
	"Nori"
]
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

@onready var map_layer: TileMapLayer = $MapLayer
@onready var tree_layer: TileMapLayer = get_node_or_null("TreeLayer")
@onready var river_layer: TileMapLayer = get_node_or_null("RiverLayer")
@onready var highland_layer: TileMapLayer = get_node_or_null("HighlandLayer")
@onready var iceberg_layer: TileMapLayer = get_node_or_null("IcebergLayer")
@onready var settlement_layer: TileMapLayer = get_node_or_null("SettlementLayer")
@onready var map_overlays: Node2D = get_node_or_null("MapOverlays")
@onready var elevation_overlay: Sprite2D = get_node_or_null("MapOverlays/ElevationOverlay")
@onready var temperature_overlay: Sprite2D = get_node_or_null("MapOverlays/TemperatureOverlay")
@onready var moisture_overlay: Sprite2D = get_node_or_null("MapOverlays/MoistureOverlay")
@onready var biome_overlay: Sprite2D = get_node_or_null("MapOverlays/BiomeOverlay")
@onready var terrain_shading_overlay: Sprite2D = get_node_or_null("MapOverlays/TerrainShadingOverlay")
@onready var culture_overlay: Sprite2D = get_node_or_null("MapOverlays/CultureOverlay")
@onready var political_boundaries_overlay: Sprite2D = get_node_or_null("MapOverlays/PoliticalBoundariesOverlay")
@onready var routes_overlay: Node2D = get_node_or_null("MapOverlays/RoutesOverlay")
@onready var rivers_overlay: Node2D = get_node_or_null("MapOverlays/RiversOverlay")
@onready var labels_overlay: Node2D = get_node_or_null("MapOverlays/LabelsOverlay")
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

## The Dwarf Fortress region zoom: the double-click dive now lands on an
## embark-style detailed map instead of jumping straight into a scene.
const REGION_TILES_SPAN := 5
const REGION_CELL_PX := 2
var _region_panel: Control
var _region_map_rect: TextureRect
var _region_marker_layer: Control
var _region_title_label: Label
var _region_info_label: Label
var _region_tile := Vector2i.ZERO
@onready var tooltip_title: Label = get_node_or_null("MapUi/MapTooltip/TooltipMargin/TooltipVBox/TooltipTitle")
@onready var tooltip_biome: Label = get_node_or_null("MapUi/MapTooltip/TooltipMargin/TooltipVBox/TooltipGrid/TooltipBiome")
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
var _vegetation_noise: FastNoiseLite
var _tile_data: Dictionary = {}
var _tile_region_names: Dictionary = {}
var _tile_population_groups: Dictionary = {}
var _tooltip_cache_coord := Vector2i(-1, -1)
var _tooltip_cache: Dictionary = {}
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
	"political_boundaries": true
}
var _hovered_tile := Vector2i(-999, -999)
var _context_menu_tile := Vector2i(-1, -1)

const CONTEXT_MENU_BEGIN_JOURNEY_ID := 0
const CONTEXT_MENU_MORE_INFORMATION_ID := 1
const DWARFHOLD_GENERATION_SCENE_PATH := "res://scenes/dwarf_hold_generation.tscn"
const DWARFHOLD_SCENE_SEED_KEY := "dwarfhold_scene_seed"
const DWARFHOLD_SCENE_TILE_KEY := "dwarfhold_scene_tile"
const DWARFHOLD_SCENE_NAME_KEY := "dwarfhold_scene_name"
const DWARFHOLD_SCENE_POPULATION_KEY := "dwarfhold_scene_population"
const TOWN_GENERATION_SCENE_PATH := "res://scenes/town_generation.tscn"
const TOWN_SCENE_SEED_KEY := "town_scene_seed"
const TOWN_SCENE_TILE_KEY := "town_scene_tile"
const TOWN_SCENE_NAME_KEY := "town_scene_name"
const TOWN_SCENE_POPULATION_KEY := "town_scene_population"
const TOWN_SCENE_THEME_KEY := "town_scene_theme"
const DUNGEON_INTERIOR_SCENE_PATH := "res://scenes/dungeon_interior.tscn"
const DUNGEON_SCENE_SEED_KEY := "dungeon_scene_seed"
const DUNGEON_SCENE_NAME_KEY := "dungeon_scene_name"
const MORE_INFO_IMAGE_FOLDER := "res://resources/images/overworld/more_info"
const GENERATION_YIELD_ROW_INTERVAL := 32
const GENERATION_YIELD_CELL_INTERVAL := 1024

var _more_info_image_paths: Array[String] = []
var _more_info_texture_cache: Dictionary = {}
var _more_info_cache_initialized := false
var _landmass_masks: Dictionary = {}

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

func _on_overworld_camera_zoom_changed(_zoom_level: float) -> void:
	_refresh_scale_bar()
	_update_labels_overlay_zoom_behavior()

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

func _hide_loading_screen() -> void:
	if loading_screen != null:
		loading_screen.visible = false

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
			var base_biome := _biome_id_to_string(int(info.get("base_biome_id", 0)))
			var color := biome_colors.get(base_biome, Color(0.36, 0.55, 0.28)) as Color
			var flags := int(info.get("overlay_flags", 0))
			if flags & TILE_OVERLAY_RIVER:
				color = Color(0.24, 0.42, 0.62)
			elif flags & (TILE_OVERLAY_TREE | TILE_OVERLAY_FOREST):
				color = color.darkened(0.18)
			var hill_biome := _biome_id_to_string(int(info.get("hill_biome_id", 0)))
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
	if _map_snapshot_sprite == null or overworld_camera == null:
		return
	var far_out: bool = overworld_camera.zoom.x < MAP_LOD_ZOOM_THRESHOLD and not (_is_globe_view or _is_scene3d_view)
	if far_out == _map_lod_active:
		return
	_map_lod_active = far_out
	_map_snapshot_sprite.visible = far_out and not (_is_globe_view or _is_scene3d_view)
	for layer: TileMapLayer in [map_layer, tree_layer, river_layer, highland_layer, iceberg_layer, _coast_layer]:
		if layer != null:
			layer.visible = not far_out

func _process(delta: float) -> void:
	_update_map_tooltip()
	_update_caravans(delta)
	_update_pirate_ships(delta)
	_update_map_lod()
	if _is_globe_view:
		_rotate_globe(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _region_panel != null and _region_panel.visible:
			_close_region_map()
			get_viewport().set_input_as_handled()
			return
		if _escape_menu != null:
			_escape_menu.toggle()
			get_viewport().set_input_as_handled()
		return
	# The region view swallows the mouse: right-click zooms back out.
	if _region_panel != null and _region_panel.visible:
		var region_mouse := event as InputEventMouseButton
		if region_mouse != null and region_mouse.pressed and region_mouse.button_index == MOUSE_BUTTON_RIGHT:
			_close_region_map()
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
var _dive_pending := false

func _handle_double_click_dive(event: InputEvent) -> bool:
	var mouse_button_event := event as InputEventMouseButton
	if mouse_button_event == null or not mouse_button_event.pressed or not mouse_button_event.double_click:
		return false
	if mouse_button_event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if _is_globe_view or _is_scene3d_view or _dive_pending:
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
	_dive_pending = true
	var tween: Tween = overworld_camera.dive_to(landing, target_zoom, DIVE_SECONDS)
	await tween.finished
	_dive_pending = false
	# Dwarf Fortress style: the dive opens the detailed region map;
	# traveling happens from its settlement markers (or right-click
	# Begin Journey as ever). enterable only shapes the zoom feel.
	_open_region_map(tile_coord)

func _tile_supports_journey(details: Dictionary) -> bool:
	if details.is_empty():
		return false
	return _is_dwarfhold_structure(details) or _is_town_settlement(details) or _is_dungeon_structure(details)

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

	print("Begin journey is not yet available for this settlement type: %s" % tile_coord)

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
	settings[TOWN_SCENE_SEED_KEY] = seed_text
	settings[TOWN_SCENE_TILE_KEY] = {"x": tile_coord.x, "y": tile_coord.y}
	settings[TOWN_SCENE_NAME_KEY] = _tile_region_name(tile_coord, details)
	settings[TOWN_SCENE_POPULATION_KEY] = maxi(0, int(details.get("population", 0)))
	settings[TOWN_SCENE_THEME_KEY] = theme
	game_session.call("set_world_settings", settings)

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

	var biome_name := String(details.get("biome", "Unknown biome")).capitalize()
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

	var history_timeline := _build_settlement_history_timeline(
		details,
		settlement_name,
		founded_years_ago
	)

	_set_details_tab_text(
		structure_details_history_label,
		"[b]Settlement:[/b] %s\n[b]Type:[/b] %s\n[b]Founded:[/b] %s\n[b]Location:[/b] %s\n[b]Biome:[/b] %s\n\n[b]Chronological Timeline[/b]\n%s" % [
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
	_set_structure_details_random_image()

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

func _set_structure_details_random_image() -> void:
	if structure_details_main_image == null:
		return
	if _more_info_image_paths.is_empty() and not _more_info_cache_initialized:
		_cache_more_info_image_paths()

	if _more_info_image_paths.is_empty():
		structure_details_main_image.texture = null
		return

	var random_index := randi_range(0, _more_info_image_paths.size() - 1)
	var random_path := _more_info_image_paths[random_index]
	var random_texture := _more_info_texture_cache.get(random_path, null) as Texture2D
	if random_texture == null:
		random_texture = load(random_path) as Texture2D
		if random_texture != null:
			_more_info_texture_cache[random_path] = random_texture
	structure_details_main_image.texture = random_texture

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
	_tooltip_cache_coord = Vector2i(-1, -1)
	_tooltip_cache.clear()

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

	# The snow line gets its own CELL-SCALE noise. Every other field is
	# scaled by 1/map width, which on big maps flattens to a constant
	# across the whole map - that constant is what drew the ruler-straight
	# treeline. This one keeps an absolute frequency so the boundary
	# wanders at 10-50 cell wavelengths no matter the map size.
	_snow_edge_noise = FastNoiseLite.new()
	_snow_edge_noise.seed = map_seed + 313
	_snow_edge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_snow_edge_noise.frequency = 0.055
	_snow_edge_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_snow_edge_noise.fractal_octaves = 4

	_rainfall_noise = FastNoiseLite.new()
	_rainfall_noise.seed = map_seed + 211
	_rainfall_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_rainfall_noise.frequency = rainfall_frequency / frequency_divisor
	_rainfall_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_rainfall_noise.fractal_octaves = 4

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
	_ensure_landmass_presence_buffer(height_buffer)
	var height_map_for_biome := _float_buffer_to_dictionary(height_buffer)

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

	_guarantee_minimum_landmass_buffer(height_buffer, temperature_buffer, moisture_buffer, base_biome_buffer)
	generation_peak_memory = _sample_generation_memory_peak(generation_peak_memory, "climate sampling")
	var height_map := _float_buffer_to_dictionary(height_buffer)
	var temperature_map := _float_buffer_to_dictionary(temperature_buffer)
	var moisture_map := _float_buffer_to_dictionary(moisture_buffer)
	var vegetation_map := _float_buffer_to_dictionary(vegetation_buffer)
	var base_biome_map := _biome_buffer_to_dictionary(base_biome_buffer)
	_landmass_masks = _generate_landmass_masks_from_biome_map(base_biome_map)

	_smooth_biomes(base_biome_map, 2)
	generation_peak_memory = _sample_generation_memory_peak(generation_peak_memory, "biome smoothing")
	if _count_biome(base_biome_map, BIOME_DESERT) == 0:
		_seed_desert_biomes(base_biome_map, temperature_map, moisture_map, height_map)
		_smooth_biomes(base_biome_map, 1)
	base_biome_buffer = _dictionary_to_biome_buffer(base_biome_map)
	var tree_biome_map: Dictionary = base_biome_map.duplicate()
	var tree_map := _apply_tree_overlays(
		tree_biome_map,
		temperature_map,
		moisture_map,
		vegetation_map,
		height_map,
		rng
	)
	generation_peak_memory = _sample_generation_memory_peak(generation_peak_memory, "tree overlays")
	highland_map = _build_highland_overlays(base_biome_map, height_map)
	var river_map := _build_river_map_buffers(height_buffer, moisture_buffer, base_biome_buffer, rng)
	var edge_connected_water := _compute_edge_connected_water_mask(base_biome_map)
	var river_tiles := _apply_river_tiles(river_map, base_biome_map, highland_map, tree_map, edge_connected_water)
	var biome_map: Dictionary = tree_biome_map
	for coord: Vector2i in highland_map.keys():
		biome_map[coord] = highland_map[coord]
	generation_peak_memory = _sample_generation_memory_peak(generation_peak_memory, "highland overlays")

	var generation_started_ms := Time.get_ticks_msec()
	await _apply_base_tiles(base_biome_map)
	_log_generation_stage("base tiles", generation_started_ms)
	await _yield_generation_wave()

	generation_started_ms = Time.get_ticks_msec()
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
	_place_icebergs(base_biome_map, temperature_map, height_map, rng)
	_log_generation_stage("icebergs", generation_started_ms)
	await _yield_generation_wave()

	generation_started_ms = Time.get_ticks_msec()
	_place_settlements(biome_map, rng)
	_log_generation_stage("settlements", generation_started_ms)
	generation_started_ms = Time.get_ticks_msec()
	_place_github_style_structures(biome_map, height_map, moisture_map, rng)
	_log_generation_stage("ambient structures", generation_started_ms)
	generation_started_ms = Time.get_ticks_msec()
	_build_routes_overlay_from_settlements()
	_log_generation_stage("routes overlay", generation_started_ms)
	generation_started_ms = Time.get_ticks_msec()
	_rebuild_labels_overlay()
	_log_generation_stage("labels overlay", generation_started_ms)
	generation_started_ms = Time.get_ticks_msec()
	_assign_cultural_groups(biome_map, temperature_map, moisture_map, height_map, rng)
	_log_generation_stage("cultural groups", generation_started_ms)
	generation_peak_memory = _sample_generation_memory_peak(generation_peak_memory, "settlements and culture")
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
	_update_terrain_shading_overlay(base_biome_map)
	_configure_globe_viewport()
	_configure_overworld_camera_bounds()
	if _is_globe_view:
		_update_globe_texture()
	if _is_scene3d_view:
		_update_scene3d_texture()
	var generation_memory_after := _current_generation_memory_bytes()
	print("Overworld generation memory bytes (before/after/peak): %d / %d / %d" % [generation_memory_before, generation_memory_after, generation_peak_memory])
	_log_tile_metadata_profile(Time.get_ticks_msec() - map_generation_started_ms)

## Writes the gazetteer of enterable sites (tile, class, name, seed)
## into world settings so local scenes know their neighbors and walkers
## can arrive on foot.
func _persist_world_sites() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings") or not game_session.has_method("set_world_settings"):
		return
	var sites: Array = []
	for coord_variant: Variant in _tile_data.keys():
		var details := _tile_data[coord_variant] as Dictionary
		var coord := coord_variant as Vector2i
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
			continue
		sites.append({
			"x": coord.x, "y": coord.y,
			"class": site_class,
			"seed": seed_text,
			"name": _tile_region_name(coord, details),
			"population": maxi(0, int(details.get("population", 0))),
			"theme": _town_theme_for_details(details)
		})
	var settings: Dictionary = game_session.call("get_world_settings")
	settings[WorldSitesService.SETTINGS_KEY] = sites
	game_session.call("set_world_settings", settings)

func _apply_base_tiles(base_biome_map: Dictionary) -> void:
	for y in range(map_size.y):
		for x in range(map_size.x):
			var coord := Vector2i(x, y)
			var base_biome := base_biome_map.get(coord, BIOME_GRASSLAND) as String
			var tile_coords := _biome_to_tile(base_biome)
			map_layer.set_cell(coord, _atlas_source_id, tile_coords)
		if y > 0 and y % GENERATION_YIELD_ROW_INTERVAL == 0:
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
	var coast_proximity_map := _build_proximity_map(base_biome_map, [BIOME_WATER], 8)
	var marsh_proximity_map := _build_proximity_map(base_biome_map, [BIOME_MARSH], 7)
	var desert_proximity_map := _build_proximity_map(base_biome_map, [BIOME_DESERT, BIOME_BADLANDS], 8)
	var tree_coverage_map := _build_tree_coverage_biome_map(base_biome_map, tree_map)
	var forest_proximity_map := _build_proximity_map(tree_coverage_map, [BIOME_FOREST, BIOME_JUNGLE], 6)
	var proximity_ms := Time.get_ticks_msec() - overlays_started
	overlays_started = Time.get_ticks_msec()
	var context_size := maxi(map_size.x, map_size.y)
	var region_names := _build_region_name_map(biome_map, name_rng, context_size)
	print("[OverworldMap] overlays: proximity %d ms | region names %d ms" % [proximity_ms, Time.get_ticks_msec() - overlays_started])
	overlays_started = Time.get_ticks_msec()
	for y in range(map_size.y):
		for x in range(map_size.x):
			var coord := Vector2i(x, y)
			var base_biome := base_biome_map.get(coord, BIOME_GRASSLAND) as String
			if highland_layer != null:
				if highland_map.has(coord):
					var highland_biome := highland_map[coord] as String
					var highland_tile := _highland_tile_for_biome(highland_biome, base_biome)
					highland_layer.set_cell(coord, _atlas_source_id, highland_tile)
				else:
					highland_layer.erase_cell(coord)
			var biome := biome_map.get(coord, base_biome) as String
			var region_name := String(region_names.get(coord, ""))
			var has_river := river_tiles.has(coord)
			var overlay_label := ""
			if tree_layer != null and not has_river:
				var tree_tile := tree_layer.get_cell_atlas_coords(coord)
				if tree_tile == TREE_TILE or tree_tile == TREE_SNOW_TILE:
					overlay_label = "forest"
				elif tree_tile == JUNGLE_TREE_TILE:
					overlay_label = "tree"
			var overlay_flags := 0
			if overlay_label == "tree":
				overlay_flags |= TILE_OVERLAY_TREE
			elif overlay_label == "forest":
				overlay_flags |= TILE_OVERLAY_FOREST
			if has_river:
				overlay_flags |= TILE_OVERLAY_RIVER
			_tile_data[coord] = {
				"biome_id": _biome_to_id(biome),
				"base_biome_id": _biome_to_id(base_biome),
				"overlay_flags": overlay_flags,
				"hill_biome_id": _biome_to_id(String(highland_map.get(coord, BIOME_GRASSLAND))),
				"structure": "",
				"structure_details": null,
				"ambient_structure": null,
				"surface_variation": _surface_variation_for_coord(coord, base_biome),
				"water_depth": _water_depth_for_coord(coord, base_biome, height_map),
				"coast_proximity": float(coast_proximity_map.get(coord, 0.0)),
				"marsh_proximity": float(marsh_proximity_map.get(coord, 0.0)),
				"desert_proximity": float(desert_proximity_map.get(coord, 0.0)),
				"forest_canopy_density": float(forest_proximity_map.get(coord, 0.0)),
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
	OverworldTerrainFeatureService.place_volcano_tiles(highland_map, height_map, rng, highland_layer, map_layer, _atlas_source_id, map_size, _tile_data)


func _apply_oases_and_lava(volcanoes: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	OverworldTerrainFeatureService.apply_oases_and_lava(volcanoes, rng, highland_layer, map_layer, _atlas_source_id, map_size, _tile_data)


func _build_proximity_map(biome_map: Dictionary, target_biomes: Array[String], max_distance: int) -> Dictionary:
	return OverworldTerrainFeatureService.build_proximity_map(biome_map, target_biomes, max_distance, map_size)


func _surface_variation_for_coord(coord: Vector2i, base_biome: String) -> float:
	return OverworldTerrainFeatureService.surface_variation_for_coord(coord, base_biome, _rainfall_noise, _temperature_noise)


func _water_depth_for_coord(coord: Vector2i, base_biome: String, height_map: Dictionary) -> float:
	return OverworldTerrainFeatureService.water_depth_for_coord(coord, base_biome, height_map, water_level)


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
			shading_image.set_pixel(x, y, color)
	var shading_texture := ImageTexture.create_from_image(shading_image)
	terrain_shading_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	terrain_shading_overlay.centered = false
	terrain_shading_overlay.position = Vector2.ZERO
	terrain_shading_overlay.scale = Vector2(float(tile_size), float(tile_size))
	terrain_shading_overlay.texture = shading_texture


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

func _build_region_name_map(
	biome_map: Dictionary,
	rng: RandomNumberGenerator,
	context_size: int
) -> Dictionary:
	var region_names := {}
	for y in range(map_size.y):
		for x in range(map_size.x):
			var start := Vector2i(x, y)
			if region_names.has(start):
				continue
			var biome := String(biome_map.get(start, BIOME_GRASSLAND))
			var water_body_type := ""
			if biome == BIOME_WATER:
				water_body_type = _water_region_type(start, biome_map)
			var region_name := _generate_biome_region_name(biome, water_body_type, rng, context_size)
			var frontier: Array[Vector2i] = [start]
			while not frontier.is_empty():
				var coord: Vector2i = frontier.pop_back()
				if region_names.has(coord):
					continue
				if String(biome_map.get(coord, BIOME_GRASSLAND)) != biome:
					continue
				region_names[coord] = region_name
				for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var neighbor: Vector2i = coord + offset
					if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= map_size.x or neighbor.y >= map_size.y:
						continue
					if region_names.has(neighbor):
						continue
					if String(biome_map.get(neighbor, BIOME_GRASSLAND)) == biome:
						frontier.append(neighbor)
	return region_names

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

func _highland_tile_for_biome(highland_biome: String, base_biome: String) -> Vector2i:
	if highland_biome == BIOME_HILLS and base_biome == BIOME_TUNDRA:
		return Vector2i(HILLS_TILE.x + 1, HILLS_TILE.y)
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


func _biome_thresholds() -> Dictionary:
	return {
		"water_level": water_level,
		"tundra_threshold": tundra_threshold,
		"marsh_threshold": marsh_threshold,
		"hot_threshold": hot_threshold,
		"desert_threshold": desert_threshold,
		"desert_temperature_bias": desert_temperature_bias,
		"desert_moisture_bias": desert_moisture_bias,
		"warm_threshold": warm_threshold,
		"badlands_threshold": badlands_threshold
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


func _sample_snow_latitude_strength(coord: Vector2i) -> float:
	var y_ratio := float(coord.y) / maxf(1.0, float(map_size.y - 1))
	var latitude := absf(y_ratio * 2.0 - 1.0)
	var latitude_strength := pow(latitude, 1.35)
	if _snow_edge_noise == null:
		return clampf(latitude_strength, 0.0, 1.0)
	var x := float(coord.x)
	var y := float(coord.y)
	# Broad lobes sweep the snow line in whole-peninsula pushes; the
	# ragged octave chews the edge at a few-cell scale.
	var lobes := _to_normalized(_snow_edge_noise.get_noise_2d(x * 0.35, y * 0.35))
	var ragged := _to_normalized(_snow_edge_noise.get_noise_2d(x * 1.6 + 71.0, y * 1.6 - 37.0))
	var band_breakup := (lobes - 0.5) * 0.34 + (ragged - 0.5) * 0.14
	return clampf(latitude_strength + band_breakup, 0.0, 1.0)


func _sample_rainfall(x: int, y: int, elevation: float) -> float:
	var humidity := _to_normalized(_rainfall_noise.get_noise_2d(float(x), float(y)))
	var orographic := maxf(0.0, mountain_level - elevation) * 0.25
	return clampf(humidity + orographic, 0.0, 1.0)


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
	temperature: float,
	moisture: float,
	height_map: Dictionary
) -> String:
	var biomes := _biome_lookup()
	var base_biome := BIOME_CLASSIFIER.assign_base_biome(coord, height, temperature, moisture, height_map, _biome_thresholds(), biomes)
	# The snow strength contour owns the treeline in both directions:
	# warm valleys bite north into the tundra, snowy fingers reach south
	# into the grass. Temperature still fences how far a finger may go.
	var snow_strength := _sample_snow_latitude_strength(coord)
	if base_biome == String(biomes.get("tundra", BIOME_TUNDRA)):
		if snow_strength < snow_latitude_threshold:
			return String(biomes.get("grassland", BIOME_GRASSLAND))
	elif base_biome == String(biomes.get("grassland", BIOME_GRASSLAND)):
		if snow_strength >= snow_latitude_threshold + 0.05 and temperature < tundra_threshold + 0.12:
			return String(biomes.get("tundra", BIOME_TUNDRA))
	return base_biome


func _tree_overlay_biome(temperature: float, moisture: float) -> String:
	return BIOME_CLASSIFIER.tree_overlay_biome(temperature, moisture, jungle_threshold, hot_threshold, tundra_threshold, _biome_lookup())


func _build_highland_overlays(biome_map: Dictionary, height_map: Dictionary) -> Dictionary:
	var overlay_map: Dictionary = {}
	for coord: Vector2i in biome_map.keys():
		if biome_map[coord] == BIOME_WATER:
			continue
		var height: float = height_map.get(coord, 0.0)
		if height > mountain_level:
			overlay_map[coord] = BIOME_MOUNTAIN
		elif height > hill_level:
			overlay_map[coord] = BIOME_HILLS
	return overlay_map


func _apply_tree_overlays(
	biome_map: Dictionary,
	temperature_map: Dictionary,
	moisture_map: Dictionary,
	vegetation_map: Dictionary,
	height_map: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var tree_map: Dictionary = {}
	var tree_source_map: Dictionary = {}
	var tree_work_map: Dictionary = {}
	var original_biomes: Dictionary = {}
	var tree_density_map: Dictionary = {}
	var density_threshold := maxf(0.2, forest_threshold * 0.55)
	for coord: Vector2i in biome_map.keys():
		if height_map.get(coord, 0.0) > mountain_level:
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
		var seed_temperature: float = temperature_map.get(coord, 0.0)
		var seed_moisture: float = moisture_map.get(coord, 0.0)
		var seed_biome := _tree_overlay_biome(seed_temperature, seed_moisture)
		if not original_biomes.has(coord):
			original_biomes[coord] = biome_map.get(coord, BIOME_GRASSLAND)
		biome_map[coord] = seed_biome
		tree_map[coord] = seed_biome
		tree_source_map[coord] = seed_biome

	for _spread_pass in range(3):
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
			var cluster_boost := minf(0.36, float(neighbor_trees) * 0.07)
			var spread_chance := clampf(0.08 + density * 0.58 + cluster_boost, 0.0, 0.96)
			if rng.randf() > spread_chance:
				continue
			var temperature: float = temperature_map.get(coord, 0.0)
			var moisture: float = moisture_map.get(coord, 0.0)
			var tree_biome := _tree_overlay_biome(temperature, moisture)
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

	var max_tree_tiles := int(ceil(float(tree_density_map.size()) * clampf(forest_max_coverage, 0.2, 0.95)))
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


func _is_marsh(coord: Vector2i, height: float, moisture: float, height_map: Dictionary) -> bool:
	return BIOME_CLASSIFIER.is_marsh(coord, height, moisture, height_map, marsh_threshold, water_level)


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


func _biome_to_tile(biome: String) -> Vector2i:
	return BIOME_CLASSIFIER.biome_to_tile(biome, _tile_lookup(), _biome_lookup())

func _place_icebergs(
	biome_map: Dictionary,
	temperature_map: Dictionary,
	height_map: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	if iceberg_layer == null:
		return
	if map_layer != null:
		iceberg_layer.tile_set = map_layer.tile_set
	iceberg_layer.clear()
	var candidates: Array[Vector2i] = []
	var coldest_coord := Vector2i(-1, -1)
	var coldest_temp := 1.0
	for coord: Vector2i in biome_map.keys():
		if biome_map.get(coord, "") != BIOME_WATER:
			continue
		var temp := float(temperature_map.get(coord, 1.0))
		if temp < coldest_temp:
			coldest_temp = temp
			coldest_coord = coord
		if temp <= iceberg_temperature_threshold and _is_iceberg_candidate(coord, height_map):
			candidates.append(coord)
	var placed := 0
	for coord: Vector2i in candidates:
		if rng.randf() <= iceberg_density:
			var selected_iceberg_tile := _pick_iceberg_tile(rng)
			iceberg_layer.set_cell(coord, _atlas_source_id, selected_iceberg_tile)
			placed += 1
	if placed == 0 and coldest_coord != Vector2i(-1, -1):
		var fallback_iceberg_tile := _pick_iceberg_tile(rng)
		iceberg_layer.set_cell(coldest_coord, _atlas_source_id, fallback_iceberg_tile)

func _pick_iceberg_tile(rng: RandomNumberGenerator) -> Vector2i:
	if iceberg_tile_options.is_empty():
		return Vector2i(4, 3)
	return iceberg_tile_options[rng.randi_range(0, iceberg_tile_options.size() - 1)]

func _is_iceberg_candidate(coord: Vector2i, height_map: Dictionary) -> bool:
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
		var neighbor_height: float = height_map.get(neighbor, 1.0)
		if neighbor_height >= water_level:
			return false
	return true

func _place_settlements(biome_map: Dictionary, rng: RandomNumberGenerator) -> void:
	var settings := _world_settings
	var ratios: Dictionary = settings.get("settlement_ratios", {}) as Dictionary
	var settlements: Dictionary = settings.get("settlements", {}) as Dictionary
	var base_count: int = maxi(1, int(round(float(map_size.x * map_size.y) / 4096.0)))

	var min_distance := 8.0
	# Suitability pools are scored once per faction type; placements then
	# draw weighted samples against an O(1) blocked-area set instead of
	# re-filtering and re-scoring every map cell per settlement.
	var blocked_area: Dictionary = {}
	var capital_pools: Dictionary = {}
	var class_buckets := OverworldSettlementService.build_settlement_class_buckets(
		biome_map, tree_layer, TREE_TILE, JUNGLE_TREE_TILE, Callable(self, "_settlement_biome_label"))

	for civilization: String in DwarfholdLogic.SETTLEMENT_TYPES.keys():
		var settlement_type := String(DwarfholdLogic.SETTLEMENT_TYPES[civilization])
		var ratio := -1.0
		if ratios.has(civilization):
			ratio = float(ratios.get(civilization, 0.0))
		elif settlements.has(civilization):
			var raw_value := float(settlements.get(civilization, 0.0))
			ratio = clampf(raw_value / 100.0, 0.0, 1.0)
		else:
			ratio = 0.5
		if ratio <= 0.0:
			continue
		if not capital_pools.has(settlement_type):
			capital_pools[settlement_type] = OverworldSettlementService.build_weighted_capital_pool(settlement_type, class_buckets)
		var pool := capital_pools[settlement_type] as Dictionary
		var count: int = maxi(1, int(round(base_count * ratio)))
		for _i in range(count):
			var chosen: Vector2i = OverworldSettlementService.sample_capital_from_pool(pool, blocked_area, rng)
			if chosen == Vector2i(-1, -1):
				break
			OverworldSettlementService.mark_occupied_area(blocked_area, chosen, min_distance)
			var biome_label := _settlement_biome_label(biome_map.get(chosen, BIOME_GRASSLAND))
			var tile := _select_settlement_tile(settlement_type, biome_label, rng, chosen)
			if settlement_layer != null:
				settlement_layer.set_cell(chosen, _atlas_source_id, tile)
			else:
				map_layer.set_cell(chosen, _atlas_source_id, tile)
			var tile_info: Dictionary = {}
			if _tile_data.has(chosen):
				tile_info = _tile_data[chosen] as Dictionary
			var settlement_name: String = String(OVERWORLD_CONTENT.SETTLEMENT_NAMES.get(civilization, "Settlement"))
			if civilization == "dwarves" and not DWARFHOLD_NAMES.is_empty():
				settlement_name = DWARFHOLD_NAMES[rng.randi_range(0, DWARFHOLD_NAMES.size() - 1)]
			elif civilization == "lizardmen":
				settlement_name = OVERWORLD_CONTENT.generate_lizardmen_city_name(rng)
			elif civilization == "humans":
				settlement_name = SETTLEMENT_NAMING.town_name(rng)
			elif civilization == "wood_elves":
				settlement_name = SETTLEMENT_NAMING.grove_name(rng)
			_tile_region_names[chosen] = settlement_name
			var civilization_label := String(CIVILIZATION_LABELS.get(civilization, civilization.capitalize()))
			_tile_population_groups[chosen] = {"major_population_groups": [civilization_label], "minor_population_groups": []}
			tile_info["settlement_type"] = settlement_type
			if settlement_type == "dwarfhold":
				tile_info.merge(_generate_dwarfhold_details(settlement_name, chosen, tile, rng), true)
				tile_info[DWARFHOLD_SCENE_SEED_KEY] = _dwarfhold_scene_seed_for_tile(chosen, tile_info)
			else:
				var founded_years_ago := _founded_years_ago_for_settlement_type(settlement_type, rng)
				tile_info["founded_years_ago"] = founded_years_ago
				var population_options := _population_options_for_settlement_type(settlement_type)
				if not population_options.is_empty():
					var population := _roll_population_for_settlement_type(settlement_type, rng)
					var primary_population_option: Dictionary = population_options[0]
					var majority_key := String(primary_population_option.get("key", ""))
					var population_breakdown := _generate_population_breakdown_from_options(
						population_options,
						population,
						rng,
						majority_key
					)
					var population_timeline := _generate_population_timeline(population, rng, founded_years_ago)
					tile_info["population"] = population
					tile_info["population_label"] = "Population"
					tile_info["population_descriptor"] = "residents"
					tile_info["population_breakdown"] = population_breakdown
					tile_info["population_timeline"] = population_timeline
					var labels := _labels_from_population_breakdown(population_breakdown)
					_tile_population_groups[chosen] = {
						"major_population_groups": labels.get("major", [civilization_label]),
						"minor_population_groups": labels.get("minor", [])
					}
			_tile_data[chosen] = tile_info


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

	var placer_started := Time.get_ticks_msec()
	var placer_times := PackedStringArray()
	_place_wizard_tower_settlements(biome_map, height_map, moisture_map, rng, occupied, map_area)
	placer_times.append("towers %d" % (Time.get_ticks_msec() - placer_started))
	placer_started = Time.get_ticks_msec()
	_place_desert_cities(rng, occupied, map_area)
	_place_evil_keeps(rng, occupied, map_area)
	placer_times.append("desert+keeps %d" % (Time.get_ticks_msec() - placer_started))
	placer_started = Time.get_ticks_msec()
	_place_hostile_camps(biome_map, moisture_map, rng, occupied, map_area)
	placer_times.append("camps %d" % (Time.get_ticks_msec() - placer_started))
	placer_started = Time.get_ticks_msec()
	_place_caves_and_dungeons(biome_map, height_map, moisture_map, rng, occupied, map_area)
	placer_times.append("caves %d" % (Time.get_ticks_msec() - placer_started))
	placer_started = Time.get_ticks_msec()
	_place_mines_hillholds_and_dams(height_map, rng, occupied, map_area)
	_place_clergy_and_taverns(moisture_map, rng, occupied, map_area)
	placer_times.append("mines+clergy %d" % (Time.get_ticks_msec() - placer_started))
	print("[OverworldMap] ambient placers ms: %s" % " | ".join(placer_times))


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


func _place_hostile_camps(
	biome_map: Dictionary,
	moisture_map: Dictionary,
	rng: RandomNumberGenerator,
	occupied: Array[Vector2i],
	map_area: int
) -> void:
	var camp_types: Array[Dictionary] = [
		{"id": "orcCamp", "tile": ORC_CAMP_TILE},
		{"id": "gnollCamp", "tile": GNOLL_CAMP_TILE},
		{"id": "trollCamp", "tile": TROLL_CAMP_TILE},
		{"id": "ogreCamp", "tile": OGRE_CAMP_TILE},
		{"id": "banditCamp", "tile": BANDIT_CAMP_TILE},
		{"id": "travelerCamp", "tile": TRAVELERS_CAMP_TILE},
		{"id": "centaurEncampment", "tile": CENTAUR_ENCAMPMENT_TILE}
	]
	var camp_candidates := STRUCTURE_PLACER.build_camp_candidates(
		_tile_data,
		biome_map,
		moisture_map,
		occupied,
		_biome_lookup(),
		rng
	)
	if camp_candidates.is_empty():
		return
	var max_camps := maxi(1, int(round(float(map_area) / 14000.0)))
	var min_distance := 8.0
	var placed := 0
	for candidate: Dictionary in camp_candidates:
		if placed >= max_camps:
			break
		if float(candidate.get("score", 0.0)) < 0.3:
			continue
		var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		if _is_too_close(coord, occupied, min_distance):
			continue
		var camp_id := _select_camp_type_from_biome(_tile_base_biome_from_data(_tile_data.get(coord, {}) as Dictionary), rng)
		var camp_def: Dictionary = {}
		for def: Dictionary in camp_types:
			if String(def.get("id", "")) == camp_id:
				camp_def = def
				break
		if camp_def.is_empty():
			camp_def = camp_types[0] as Dictionary
		_place_structure_with_details(
			coord,
			camp_def.get("tile", ORC_CAMP_TILE) as Vector2i,
			camp_id,
			{
				"region_name": SETTLEMENT_NAMING.camp_name(camp_id, rng),
				"settlement_classification": camp_id.capitalize()
			}
		)
		occupied.append(coord)
		placed += 1



func _select_camp_type_from_biome(base_biome: String, rng: RandomNumberGenerator) -> String:
	return STRUCTURE_PLACER.select_camp_type_from_biome(base_biome, rng, _biome_lookup())


func _place_caves_and_dungeons(
	biome_map: Dictionary,
	height_map: Dictionary,
	moisture_map: Dictionary,
	rng: RandomNumberGenerator,
	occupied: Array[Vector2i],
	map_area: int
) -> void:
	var candidates := STRUCTURE_PLACER.build_cave_and_dungeon_candidates(
		_tile_data,
		biome_map,
		height_map,
		moisture_map,
		occupied,
		_biome_lookup(),
		rng
	)
	var cave_candidates: Array[Dictionary] = candidates.get("caves", [])
	var dungeon_candidates: Array[Dictionary] = candidates.get("dungeons", [])

	var max_caves := maxi(1, int(round(float(map_area) / 18000.0)))
	var max_dungeons := maxi(1, int(round(float(map_area) / 22000.0)))
	_place_scored_structure_batch(cave_candidates, occupied, 7.0, max_caves, 0.3, CAVE_TILE, "cave", rng)
	_place_scored_structure_batch(dungeon_candidates, occupied, 9.0, max_dungeons, 0.32, DUNGEON_TILE, "dungeon", rng)


func _place_mines_hillholds_and_dams(
	height_map: Dictionary,
	rng: RandomNumberGenerator,
	occupied: Array[Vector2i],
	map_area: int
) -> void:
	var mountain_candidates: Array[Dictionary] = []
	var hill_candidates: Array[Dictionary] = []
	var occupied_set: Dictionary = {}
	for occupied_coord: Vector2i in occupied:
		occupied_set[occupied_coord] = true
	for coord_variant: Variant in _tile_data.keys():
		var coord := coord_variant as Vector2i
		if occupied_set.has(coord):
			continue
		var tile_info := _tile_data.get(coord, {}) as Dictionary
		if tile_info.is_empty() or _tile_has_overlay_flag(tile_info, TILE_OVERLAY_RIVER):
			continue
		var base_biome := _tile_base_biome_from_data(tile_info)
		var hill_overlay := _tile_hill_biome_from_data(tile_info)
		if base_biome == BIOME_MOUNTAIN or hill_overlay == BIOME_MOUNTAIN:
			mountain_candidates.append({"coord": coord, "score": float(height_map.get(coord, 0.0)) + rng.randf() * 0.1})
		elif hill_overlay == BIOME_HILLS:
			hill_candidates.append({"coord": coord, "score": float(height_map.get(coord, 0.0)) + rng.randf() * 0.1})

	mountain_candidates = STRUCTURE_PLACER.sort_candidates_by_score(mountain_candidates)
	hill_candidates = STRUCTURE_PLACER.sort_candidates_by_score(hill_candidates)

	var max_mines := maxi(1, int(round(float(map_area) / 24000.0)))
	var max_hillholds := maxi(1, int(round(float(map_area) / 32000.0)))
	var max_dams := maxi(1, int(round(float(map_area) / 52000.0)))
	var placed_dwarf_sites: Array[Vector2i] = []

	for candidate in mountain_candidates:
		if max_mines <= 0:
			break
		var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		if _is_too_close(coord, occupied, 7.0):
			continue
		_place_structure_with_details(coord, MINE_TILE, "mine", {
			"region_name": SETTLEMENT_NAMING.mine_name(rng),
			"settlement_classification": "Mine"
		})
		occupied.append(coord)
		occupied_set[coord] = true
		placed_dwarf_sites.append(coord)
		max_mines -= 1

	for candidate in hill_candidates:
		if max_hillholds <= 0:
			break
		var coord := candidate.get("coord", Vector2i(-1, -1)) as Vector2i
		if _is_too_close(coord, occupied, 10.0):
			continue
		_place_structure_with_details(coord, HILLHOLD_TILE, "hillhold", {
			"region_name": SETTLEMENT_NAMING.hillhold_name(rng),
			"settlement_classification": "Hillhold"
		})
		occupied.append(coord)
		occupied_set[coord] = true
		placed_dwarf_sites.append(coord)
		max_hillholds -= 1

	if max_dams > 0:
		# Browser rule: dams are dwarven engineering. They sit on RIVER
		# tiles pinched between mountains, within 10 tiles of a dwarfhold,
		# and even then only some sites (35%) get dammed.
		var dwarfhold_coords: Array[Vector2i] = []
		for hold_coord_variant: Variant in _tile_data.keys():
			var hold_info := _tile_data.get(hold_coord_variant, {}) as Dictionary
			if String(hold_info.get("settlement_type", "")).findn("dwarfhold") >= 0:
				dwarfhold_coords.append(hold_coord_variant as Vector2i)
		if not dwarfhold_coords.is_empty():
			for y in range(1, map_size.y - 1):
				for x in range(1, map_size.x - 1):
					if max_dams <= 0:
						break
					var coord := Vector2i(x, y)
					if occupied_set.has(coord):
						continue
					var dam_tile_info := _tile_data.get(coord, {}) as Dictionary
					if not _tile_has_overlay_flag(dam_tile_info, TILE_OVERLAY_RIVER):
						continue
					var west_hill := _tile_hill_biome_from_data((_tile_data.get(Vector2i(x - 1, y), {}) as Dictionary))
					var east_hill := _tile_hill_biome_from_data((_tile_data.get(Vector2i(x + 1, y), {}) as Dictionary))
					var north_hill := _tile_hill_biome_from_data((_tile_data.get(Vector2i(x, y - 1), {}) as Dictionary))
					var south_hill := _tile_hill_biome_from_data((_tile_data.get(Vector2i(x, y + 1), {}) as Dictionary))
					var pinched := (west_hill == BIOME_MOUNTAIN and east_hill == BIOME_MOUNTAIN) \
						or (north_hill == BIOME_MOUNTAIN and south_hill == BIOME_MOUNTAIN)
					if not pinched:
						continue
					if not _is_too_close(coord, dwarfhold_coords, 10.0):
						continue
					if rng.randf() >= 0.35:
						continue
					_place_structure_with_details(coord, DAM_TILE, "dam", {"region_name": "Dam"})
					occupied.append(coord)
					occupied_set[coord] = true
					max_dams -= 1


func _place_clergy_and_taverns(
	moisture_map: Dictionary,
	rng: RandomNumberGenerator,
	occupied: Array[Vector2i],
	map_area: int
) -> void:
	var monastery_candidates: Array[Dictionary] = []
	var shrine_candidates: Array[Dictionary] = []
	var tavern_candidates: Array[Dictionary] = []
	var occupied_set: Dictionary = {}
	for occupied_coord: Vector2i in occupied:
		occupied_set[occupied_coord] = true
	for coord_variant: Variant in _tile_data.keys():
		var coord := coord_variant as Vector2i
		if occupied_set.has(coord):
			continue
		var tile_info := _tile_data.get(coord, {}) as Dictionary
		if tile_info.is_empty() or _tile_has_overlay_flag(tile_info, TILE_OVERLAY_RIVER):
			continue
		var base := _tile_base_biome_from_data(tile_info)
		if base == BIOME_WATER or base == BIOME_MARSH:
			continue
		var score := float(moisture_map.get(coord, 0.5)) + rng.randf() * 0.2
		if base == BIOME_MOUNTAIN or base == BIOME_HILLS:
			monastery_candidates.append({"coord": coord, "score": score + 0.15})
		if base == BIOME_GRASSLAND or base == BIOME_FOREST:
			shrine_candidates.append({"coord": coord, "score": score})
		if base != BIOME_DESERT and base != BIOME_BADLANDS:
			tavern_candidates.append({"coord": coord, "score": score})

	monastery_candidates = STRUCTURE_PLACER.sort_candidates_by_score(monastery_candidates)
	shrine_candidates = STRUCTURE_PLACER.sort_candidates_by_score(shrine_candidates)
	tavern_candidates = STRUCTURE_PLACER.sort_candidates_by_score(tavern_candidates)

	_place_scored_structure_batch(monastery_candidates, occupied, 12.0, maxi(1, int(round(float(map_area) / 45000.0))), 0.35, MONASTERY_TILE, "monastery", rng)
	_place_scored_structure_batch(shrine_candidates, occupied, 10.0, maxi(1, int(round(float(map_area) / 36000.0))), 0.32, SAINT_SHRINE_TILE, "saintShrine", rng)
	_place_scored_structure_batch(tavern_candidates, occupied, 9.0, maxi(1, int(round(float(map_area) / 28000.0))), 0.3, ROADSIDE_TAVERN_TILE, "roadsideTavern", rng)



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
			_tile_population_groups[coord] = {
				"major_population_groups": population_groups.get("major", []),
				"minor_population_groups": population_groups.get("minor", [])
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
			if settlement_layer != null and not tile_info.has("settlement_type") and ambient_dict.has("tile"):
				settlement_layer.set_cell(coord, _atlas_source_id, ambient_dict.get("tile", TOWN_TILE) as Vector2i)
		_tile_data[coord] = tile_info

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

func _settlement_biome_label(biome: String) -> String:
	match biome:
		BIOME_MOUNTAIN:
			return "mountain"
		BIOME_HILLS:
			return "grass"
		BIOME_TUNDRA:
			return "snow"
		BIOME_DESERT:
			return "sand"
		BIOME_BADLANDS:
			return "badlands"
		BIOME_FOREST, BIOME_JUNGLE:
			return "forest"
		BIOME_MARSH:
			return "marsh"
		BIOME_WATER:
			return "water"
		_:
			return "grass"

func _select_settlement_tile(
	settlement_type: String,
	biome_label: String,
	rng: RandomNumberGenerator,
	coord: Vector2i
) -> Vector2i:
	match settlement_type:
		"town":
			if biome_label == "snow":
				return HAMLET_SNOW_TILE
			var options: Array = SETTLEMENT_TILES.get("town", [TOWN_TILE]) as Array
			return options[rng.randi_range(0, options.size() - 1)]
		"dwarfhold":
			return DARK_DWARFHOLD_TILE if _is_within_tiles_of_volcano(coord, 8) else DWARFHOLD_TILE
		"woodElfGrove":
			var elf_tiles: Array = SETTLEMENT_TILES.get("woodElfGrove", [WOOD_ELF_GROVES_TILE]) as Array
			return elf_tiles[rng.randi_range(0, elf_tiles.size() - 1)]
		"lizardmenCity":
			return LIZARDMEN_CITY_TILE
		_:
			return TOWN_TILE

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
		resolved = _resources_for_biome_id(biome_id)
	if float(data.get("coast_proximity", 0.0)) >= 0.65 and biome_id != _biome_to_id(BIOME_WATER):
		resolved.append("coastal fisheries")
	if float(data.get("marsh_proximity", 0.0)) >= 0.55 and biome_id != _biome_to_id(BIOME_MARSH):
		resolved.append("peat and bog iron")
	if float(data.get("desert_proximity", 0.0)) >= 0.55 and biome_id != _biome_to_id(BIOME_DESERT):
		resolved.append("trade caravans")
	if float(data.get("forest_canopy_density", 0.0)) >= 0.65:
		resolved.append("dense lumber stands")
	if float(data.get("temperature", 1.0)) <= 0.25:
		resolved.append("fur-bearing game")
	if _is_within_tiles_of_volcano(coord, 3):
		resolved.append("volcanic glass and obsidian")
	if resolved.size() > 5:
		resolved = resolved.slice(0, 5)
	return resolved

func _is_lake_coord(coord: Vector2i) -> bool:
	var lake_cells_variant: Variant = _landmass_masks.get("lake_cells", {})
	if lake_cells_variant is Dictionary:
		return (lake_cells_variant as Dictionary).has(coord)
	return false

func _describe_climate(temperature: float, moisture: float) -> String:
	return OverworldPopulationService.describe_climate(temperature, moisture)

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

func _generate_population_timeline(
	population: int,
	rng: RandomNumberGenerator,
	founded_years_ago: int
) -> Array[Dictionary]:
	var resolved_population := maxi(0, population)
	if resolved_population <= 0:
		return []
	var resolved_founded_years_ago := maxi(0, founded_years_ago)

	var points: Array[Dictionary] = []
	var total_points := resolved_founded_years_ago + 1
	var base_start := maxf(20.0, float(resolved_population) * rng.randf_range(0.18, 0.48))
	var current_value := base_start

	for year_since_founding in range(total_points):
		if year_since_founding == total_points - 1:
			current_value = float(resolved_population)
		else:
			var timeline_ratio := 0.0
			if total_points > 1:
				timeline_ratio = float(year_since_founding) / float(total_points - 1)
			var target_value := lerpf(base_start, float(resolved_population), timeline_ratio)
			var drift := (target_value - current_value) * 0.16
			var noise_strength := lerpf(0.075, 0.03, timeline_ratio)
			var noise := rng.randf_range(-1.0, 1.0) * maxf(8.0, current_value * noise_strength)
			current_value = clampf(
				current_value + drift + noise,
				10.0,
				float(resolved_population) * 1.75
			)

		var years_ago := resolved_founded_years_ago - year_since_founding
		points.append({
			"label": "Founding" if year_since_founding == 0 else ("Current" if years_ago == 0 else "Year %d" % year_since_founding),
			"year": year_since_founding,
			"population": int(round(current_value)),
			"years_ago": years_ago
		})

	if points.size() > 1:
		points[points.size() - 1]["population"] = resolved_population
	return points

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
	var ruler_first := _pick_random_entry(DWARFHOLD_RULER_NAMES, rng, "Urist")
	var is_dark: bool = classification_key == "dark"
	var ruler_title := (
		_pick_random_entry(DARK_DWARFHOLD_RULER_TITLES, rng, "Sorcerer-Prophet")
		if is_dark
		else _pick_random_entry(DWARFHOLD_RULER_TITLES, rng, "Thane")
	)
	details["population"] = population
	details["ruler_title"] = ruler_title
	details["ruler_name"] = "%s %s" % [ruler_first, clan]
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
	var founded_years_ago := int(details.get("founded_years_ago", 0))
	var population_timeline := _generate_population_timeline(population, rng, founded_years_ago)
	if is_dark:
		for entry in population_breakdown:
			if String(entry.get("key", "")) == "dwarves":
				entry["label"] = "Dark Dwarves"
				entry["color"] = Color("#3b2a3d")
	details["population_breakdown"] = population_breakdown
	details["population_timeline"] = population_timeline
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
	for child in tooltip_population_breakdown_list.get_children():
		child.queue_free()
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

func _update_map_tooltip() -> void:
	if tooltip_panel == null or map_layer == null:
		return
	if _is_globe_view or _is_scene3d_view:
		if _is_dragging_globe or _is_dragging_scene3d or _hovered_tile.x < 0 or _hovered_tile.y < 0:
			_hide_map_tooltip()
			return
		_refresh_map_tooltip(_hovered_tile)
		tooltip_panel.visible = true
		_position_map_tooltip()
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
		_refresh_map_tooltip(coord)
	tooltip_panel.visible = true
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
	var temperature := float(data.get("temperature", 0.0))
	var moisture := float(data.get("moisture", 0.0))
	var resources := _resources_for_tile(coord, data)
	var region_name := _tile_region_name(coord, data)
	var biome_label := _humanize_biome(biome)
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
	var climate_text := _describe_climate(temperature, moisture).strip_edges()
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
	if not culture_tooltip.is_empty():
		var influence_label := String(culture_tooltip.get("label", "Unknown"))
		if not influence_label.is_empty() and not major_population_groups.has(influence_label) and not minor_population_groups.has(influence_label):
			minor_population_groups.append(influence_label)
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
	tooltip_panel.size = tooltip_panel.get_combined_minimum_size()
	_tooltip_cache_coord = coord
	_tooltip_cache = {"region_name": region_name}

func _position_map_tooltip() -> void:
	if tooltip_panel == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var cursor_pos := viewport.get_mouse_position()
	# The autowrap labels carry fixed wrap widths, so the combined minimum
	# is stable; snapping to it here heals the screen-tall panel that a
	# pre-layout measurement (autowrap heights taken before widths settled)
	# used to leave behind without reintroducing per-frame flicker.
	var min_size := tooltip_panel.get_combined_minimum_size()
	if absf(tooltip_panel.size.y - min_size.y) > 1.0 or absf(tooltip_panel.size.x - min_size.x) > 1.0:
		tooltip_panel.size = min_size
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
	var image := _culture_pipeline.build_political_boundaries_overlay_image(map_size.x, map_size.y, _tile_data)
	var texture := ImageTexture.create_from_image(image)
	political_boundaries_overlay.texture = texture
	_overlay_dirty["political_boundaries"] = false
	political_boundaries_overlay.centered = false
	political_boundaries_overlay.scale = Vector2(tile_size, tile_size)
	political_boundaries_overlay.position = Vector2.ZERO
	_update_political_boundaries_overlay_visibility()

func _update_political_boundaries_overlay_visibility() -> void:
	if political_boundaries_overlay == null:
		return
	political_boundaries_overlay.visible = _political_boundaries_overlay_enabled and not (_is_globe_view or _is_scene3d_view)

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
		_roads_layer.visible = overlays_visible

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

func _rebuild_labels_overlay() -> void:
	if labels_overlay == null:
		return
	var entries: Array[Dictionary] = []
	for coord_variant: Variant in _tile_data.keys():
		var coord := coord_variant as Vector2i
		var tile_info := _tile_data.get(coord, {}) as Dictionary
		var settlement_type := String(tile_info.get("settlement_type", "")).strip_edges().to_lower()
		if settlement_type.is_empty():
			continue
		var region_name := _tile_region_name(coord, tile_info)
		if region_name.is_empty():
			continue
		entries.append({
			"center": _map_cell_center(coord),
			"name": region_name,
			"font_size": OverworldLabelsService.font_size_for_settlement(settlement_type),
			"priority": OverworldLabelsService.priority_for_settlement(settlement_type),
			"population": int(tile_info.get("population", 0))
		})
	OverworldLabelsService.rebuild(labels_overlay, entries, {
		"tile_size": tile_size,
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

	var forest_delta := forest_ratio - 0.5
	var mountain_delta := mountain_ratio - 0.5
	var river_delta := river_ratio - 0.5

	water_level = clampf(water_level + (river_delta * 0.12) - (mountain_delta * 0.04), 0.2, 0.7)
	noise_frequency = clampf(noise_frequency + (mountain_delta * 1.2) - (forest_delta * 0.3), 0.6, 4.0)
	falloff_strength = clampf(falloff_strength + (river_delta * 0.16), -0.45, 0.45)
	landmass_falloff_scale = clampf(landmass_falloff_scale + (mountain_delta * 0.35), 0.8, 2.2)

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
			falloff_power = float(layout_preset.get("falloff_power", 2.4))
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


## --- The region map ---------------------------------------------------------
## Double-clicking the world map zooms into a Dwarf Fortress embark-style
## region view: the surrounding tiles rendered at full walkable detail
## (64 cells per tile) from the shared surface terrain, with an info
## panel for the chosen tile and settlement markers you can travel to.

func _ensure_region_panel() -> void:
	if _region_panel != null:
		return
	var ui_parent := tooltip_panel.get_parent() if tooltip_panel != null else self
	_region_panel = Control.new()
	_region_panel.name = "RegionMapPanel"
	_region_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_region_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_region_panel.visible = false
	ui_parent.add_child(_region_panel)
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.02, 0.02, 0.03, 0.88)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_region_panel.add_child(dimmer)
	# The map itself, centered-left like the embark screen.
	_region_map_rect = TextureRect.new()
	_region_map_rect.stretch_mode = TextureRect.STRETCH_KEEP
	_region_map_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_region_panel.add_child(_region_map_rect)
	_region_marker_layer = Control.new()
	_region_marker_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	_region_map_rect.add_child(_region_marker_layer)
	# DF-style info panel: black field, amber border, top right.
	var info_panel := PanelContainer.new()
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color(0.045, 0.045, 0.055, 0.98)
	info_style.border_color = Color(0.92, 0.62, 0.16, 1.0)
	info_style.set_border_width_all(3)
	info_style.set_content_margin_all(12)
	info_panel.add_theme_stylebox_override("panel", info_style)
	info_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	info_panel.position = Vector2(-360.0, 16.0)
	info_panel.custom_minimum_size = Vector2(340.0, 300.0)
	_region_panel.add_child(info_panel)
	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 6)
	info_panel.add_child(info_box)
	_region_title_label = Label.new()
	_region_title_label.add_theme_font_size_override("font_size", 17)
	_region_title_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8, 1.0))
	_region_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_region_title_label.custom_minimum_size = Vector2(310.0, 0.0)
	info_box.add_child(_region_title_label)
	_region_info_label = Label.new()
	_region_info_label.add_theme_font_size_override("font_size", 13)
	_region_info_label.add_theme_color_override("font_color", Color(0.85, 0.83, 0.76, 1.0))
	_region_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_region_info_label.custom_minimum_size = Vector2(310.0, 0.0)
	info_box.add_child(_region_info_label)
	# Bottom hint bar, DF style.
	var hint_panel := PanelContainer.new()
	var hint_style := info_style.duplicate() as StyleBoxFlat
	hint_style.set_content_margin_all(8)
	hint_panel.add_theme_stylebox_override("panel", hint_style)
	hint_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_panel.position = Vector2(-320.0, -60.0)
	hint_panel.custom_minimum_size = Vector2(640.0, 0.0)
	_region_panel.add_child(hint_panel)
	var hint_label := Label.new()
	hint_label.text = "Left-click a settlement to travel there.  Right-click or Esc to zoom back out."
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_panel.add_child(hint_label)

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

func _open_region_map(center_tile: Vector2i) -> void:
	_ensure_region_panel()
	_region_tile = center_tile
	var half := REGION_TILES_SPAN / 2
	var top_left := center_tile - Vector2i(half, half)
	top_left.x = clampi(top_left.x, 0, maxi(0, map_size.x - REGION_TILES_SPAN))
	top_left.y = clampi(top_left.y, 0, maxi(0, map_size.y - REGION_TILES_SPAN))
	# Settlement anchors shade danger; those inside the span get markers.
	var anchors: Array[Vector2i] = []
	var span_sites: Array[Dictionary] = []
	for coord_variant: Variant in _tile_data.keys():
		var coord := coord_variant as Vector2i
		var details := _tile_data.get(coord_variant, {}) as Dictionary
		if String(details.get("settlement_type", "")).strip_edges().is_empty():
			continue
		anchors.append(coord * RegionMapService.CELLS_PER_TILE + Vector2i(RegionMapService.CELLS_PER_TILE / 2, RegionMapService.CELLS_PER_TILE / 2))
		if coord.x >= top_left.x and coord.x < top_left.x + REGION_TILES_SPAN and coord.y >= top_left.y and coord.y < top_left.y + REGION_TILES_SPAN:
			span_sites.append({"tile": coord, "details": details})
	_region_map_rect.texture = RegionMapService.render_region(
		_region_world_seed_text(), top_left, REGION_TILES_SPAN,
		Callable(self, "_region_biome_for_tile"),
		Callable(self, "_region_river_for_tile"),
		anchors, REGION_CELL_PX
	)
	var map_pixels := float(REGION_TILES_SPAN * RegionMapService.CELLS_PER_TILE * REGION_CELL_PX)
	_region_map_rect.position = Vector2(40.0, maxf((_region_panel.size.y - map_pixels) * 0.5, 16.0))
	# Settlement markers over the map.
	for stale: Node in _region_marker_layer.get_children():
		stale.queue_free()
	for site: Dictionary in span_sites:
		var site_tile := site.get("tile", Vector2i.ZERO) as Vector2i
		var site_details := site.get("details", {}) as Dictionary
		var marker := Button.new()
		marker.text = "⌂ %s" % _tile_region_name(site_tile, site_details)
		marker.add_theme_font_size_override("font_size", 12)
		var marker_style := StyleBoxFlat.new()
		marker_style.bg_color = Color(0.1, 0.08, 0.05, 0.85)
		marker_style.border_color = Color(0.92, 0.62, 0.16, 1.0)
		marker_style.set_border_width_all(1)
		marker_style.set_content_margin_all(4)
		marker.add_theme_stylebox_override("normal", marker_style)
		marker.tooltip_text = "Travel to %s" % _tile_region_name(site_tile, site_details)
		var local := (site_tile - top_left) * RegionMapService.CELLS_PER_TILE + Vector2i(RegionMapService.CELLS_PER_TILE / 2, RegionMapService.CELLS_PER_TILE / 2)
		marker.position = Vector2(local * REGION_CELL_PX) - Vector2(30.0, 12.0)
		marker.pressed.connect(_on_region_site_pressed.bind(site_tile))
		_region_marker_layer.add_child(marker)
	# The info panel describes the double-clicked tile, DF-style.
	var details := _tile_data.get(center_tile, {}) as Dictionary
	var biome := _tile_biome_from_data(details)
	var region_name := _tile_region_name(center_tile, details)
	var biome_label := _humanize_biome(biome)
	if region_name.is_empty():
		region_name = "Unnamed %s" % biome_label if not biome_label.is_empty() else "Unnamed Region"
	_region_title_label.text = region_name
	var lines: PackedStringArray = []
	if not biome_label.is_empty():
		lines.append(biome_label)
	var climate := _describe_climate(float(details.get("temperature", 0.0)), float(details.get("moisture", 0.0))).strip_edges()
	if not climate.is_empty():
		lines.append("Climate: %s" % climate)
	var center_anchor := center_tile * RegionMapService.CELLS_PER_TILE + Vector2i(RegionMapService.CELLS_PER_TILE / 2, RegionMapService.CELLS_PER_TILE / 2)
	lines.append("Surroundings: %s" % RegionMapService.surroundings_label(RegionMapService.danger_for_world_cell(center_anchor, anchors)))
	if _region_river_for_tile(center_tile):
		lines.append("A river runs through it.")
	var settlement_type := String(details.get("settlement_type", "")).strip_edges()
	if not settlement_type.is_empty():
		lines.append("Settlement: %s (pop. %d)" % [settlement_type.capitalize(), int(details.get("population", 0))])
	var resource_text := _format_resource_list(_resources_for_tile(center_tile, details))
	if not resource_text.is_empty():
		lines.append("")
		lines.append("Resources: %s" % resource_text)
	if span_sites.is_empty():
		lines.append("")
		lines.append("No settlements in these parts.")
	_region_info_label.text = "\n".join(lines)
	_region_panel.visible = true
	_region_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.tween_property(_region_panel, "modulate:a", 1.0, 0.18)

func _close_region_map() -> void:
	if _region_panel != null:
		_region_panel.visible = false

func _on_region_site_pressed(site_tile: Vector2i) -> void:
	_close_region_map()
	_begin_journey_from_tile(site_tile)
