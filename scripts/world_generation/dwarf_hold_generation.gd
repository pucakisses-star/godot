extends Control

const CELL_ROCK := 0
const CELL_HALL := 1
const CELL_HOUSE := 2
const CELL_BUILDING := 3
const CELL_PLAZA := 4
const CELL_WATER := 5

@export var hall_zone_count_range := Vector2i(14, 22)
@export var housing_zone_count_range := Vector2i(80, 140)
@export var civic_building_zone_count_range := Vector2i(45, 95)
@export var plaza_zone_count_range := Vector2i(6, 14)
@export var tile_size := Vector2i(32, 32)
@export var tilesheet_path := "res://resources/images/dwarfhold/map.png"
@export var structure_fallback_max_extra_radius := 240
@export var tavern_vehicle_sprite_path := "res://resources/images/npc/dwarf_characters.png"
@export var creature_sprite_path := "res://resources/images/npc/creature_characters.png"
@export var shattered_player_sprite_path := "res://resources/images/shattered_ui/warrior.png"
@export var tavern_npc_count := 5
@export var tavern_npc_speed_range := Vector2(38.0, 62.0)
@export var enable_fog_of_war := true
@export var underground_level_count_range := Vector2i(3, 7)
## Real minutes for one full in-game day (the hold's shift cycle).
@export var minutes_per_game_day := 6.0
@export var clock_start_hour := 9.0

# Residence variety: footprints are half-extents (rooms span 2*radius+1
# tiles). Houses sleep one dwarf; dormitories and barracks pack bed rows so
# large populations don't need hundreds of tiny homes.
const RESIDENCE_TYPES := {
	"house": {"weight": 0.62, "radius_min": Vector2i(2, 2), "radius_max": Vector2i(6, 5)},
	"dormitory": {"weight": 0.24, "radius_min": Vector2i(4, 3), "radius_max": Vector2i(6, 5)},
	"barracks": {"weight": 0.14, "radius_min": Vector2i(4, 3), "radius_max": Vector2i(5, 4)}
}

const TILE_ATLAS_DEFS := preload("res://scripts/world_generation/tile_atlas_defs.gd")
const TILE_ATLAS := TILE_ATLAS_DEFS.DWARFHOLD_TILE_ATLAS
const PASSABLE_TILE_KEYS := TILE_ATLAS_DEFS.DWARFHOLD_PASSABLE_TILE_KEYS
const COLLISION_LAYER_WORLD := 1



@onready var seed_input: LineEdit = %SeedInput
@onready var generate_button: Button = %GenerateButton
@onready var depth_down_button: Button = %DepthDownButton
@onready var depth_up_button: Button = %DepthUpButton
@onready var depth_label: Label = %DepthLabel
@onready var overlay_toggle: CheckButton = %OverlayToggle
@onready var lighting_toggle: CheckButton = %LightingToggle
@onready var city_summary: Label = %CitySummary
@onready var clock_label: Label = get_node_or_null("%ClockLabel")
@onready var city_panel: PanelContainer = %CityPanel
@onready var city_layer: TileMapLayer = %CityTileLayer
@onready var decor_layer: TileMapLayer = %DecorTileLayer
@onready var lighting_layer: Node2D = %LightingLayer
@onready var global_darkness: CanvasModulate = %GlobalDarkness
@onready var fog_of_war: Sprite2D = %FogOfWar
@onready var actor_layer: Node2D = %ActorLayer
@onready var zone_overlay: Control = %ZoneOverlay
@onready var zone_legend: RichTextLabel = %ZoneLegend
@onready var tile_hover_tooltip: PanelContainer = %TileHoverTooltip
@onready var tile_hover_label: Label = %TileHoverLabel
@onready var chest_popup: PanelContainer = %ChestPopup
@onready var chest_popup_title: Label = %ChestPopupTitle
@onready var chest_grid: GridContainer = %ChestGrid
@onready var backpack_grid: GridContainer = %BackpackGrid
@onready var chest_popup_status_label: Label = %ChestPopupStatusLabel
@onready var chest_popup_take_all_button: Button = %ChestPopupTakeAllButton
@onready var chest_popup_close_button: Button = %ChestPopupCloseButton
@onready var chest_popup_close_footer_button: Button = %ChestPopupCloseFooterButton
@onready var back_button: Button = %BackButton
@onready var save_game_button: Button = %SaveGameButton
@onready var save_status_label: Label = %SaveStatusLabel
@onready var player_character_label: Label = %PlayerCharacterLabel

const OVERWORLD_SCENE_PATH := "res://scenes/overworld.tscn"

var _rng := RandomNumberGenerator.new()
var _is_panning := false
var _zoom_level := 1.0
var _pan_offset := Vector2.ZERO
var _map_origin_offset := Vector2.ZERO
var _door_cells: Dictionary = {}
var _latest_grid: Dictionary = {}
var _latest_civic_buildings_by_id: Dictionary = {}
var _latest_civic_building_type_map: Dictionary = {}
var _latest_residence_type_map: Dictionary = {}
var _latest_district_labels: Array = []
var _latest_district_cell_map: Dictionary = {}
var _latest_floor_decor: Dictionary = {}
var _world_noise: Dictionary = {}
var _generated_chunks: Dictionary = {}
var _dug_cells: Dictionary = {}
var _last_player_chunk := Vector2i(2147483647, 2147483647)
var _world_seed_hash := 0
var _underdeep_sites: Array = []
var _sites_by_chunk: Dictionary = {}
var _player_inventory: Dictionary = {}
var _inventory_label: Label
var _creature_states: Array[Dictionary] = []
var _creature_texture: Texture2D
var _creature_repop_timer := 0.0
var _player_hp := 20.0
var _player_attack_timer := 0.0
var _hp_label: Label
var _fishing_state: Dictionary = {}
var _player_coins := 0
var _coins_label: Label
var _trade_shop_cell := Vector2i(2147483647, 2147483647)
var _trade_shop_type := ""
var _shop_stocks: Dictionary = {}
var _active_speech_bubble: PanelContainer
var _build_selection := -1
var _escape_menu: EscapeMenu
var _torch_sprites: Array = []
var _player_glow: Sprite2D
var _glow_texture: Texture2D
var _light_dim := 1.0
var _latest_bed_count := 0
var _show_zone_overlay := false
var _lighting_enabled := true
var _chest_inventories: Dictionary = {}
var _selected_chest_cell := Vector2i(2147483647, 2147483647)
var _chest_slot_panels: Array[PanelContainer] = []
var _chest_slot_labels: Array[Label] = []
var _chest_slot_icons: Array[TextureRect] = []
var _backpack_slot_panels: Array[PanelContainer] = []
var _backpack_slot_labels: Array[Label] = []
var _backpack_slot_icons: Array[TextureRect] = []
var _backpack_slot_items: Array[String] = []
var _latest_zone_counts := {
	"halls": 0,
	"houses": 0,
	"buildings": 0,
	"plazas": 0
}
var _latest_requested_zone_counts := {
	"halls": 0,
	"houses": 0,
	"buildings": 0,
	"plazas": 0
}
var _lighting_mask_image: Image
var _lighting_mask_texture: ImageTexture
var _lighting_mask_sprite: Sprite2D
var _lighting_bounds := Rect2i()
var _revealed_cells: Dictionary = {}
var _visible_cells: Dictionary = {}
var _tavern_character_texture: Texture2D
var _shattered_player_texture: Texture2D
var _placeholder_actor_texture: Texture2D
var _walkable_cells: Array[Vector2i] = []
var _player_sprite: Sprite2D
var _player_cell := Vector2i.ZERO
var _player_control_enabled := false
var _player_move_path: Array[Vector2i] = []
var _player_is_moving := false
var _player_move_target_cell := Vector2i.ZERO
var _player_move_target_position := Vector2.ZERO
var _player_pending_chest_interaction := Vector2i(2147483647, 2147483647)
var _hover_tooltip_cell := Vector2i(2147483647, 2147483647)
var _hover_tooltip_layer: TileMapLayer
var _last_move_direction := Vector2i.ZERO
var _move_repeat_timer := 0.0
var _npc_states: Array[Dictionary] = []
var _furnishing_sprites: Array[Node2D] = []
var _furnishing_blocked_cells: Dictionary = {}
var _hold_state := DwarfHoldStateModel.new()
var _game_hour := 9.0
var _game_day := 1
var _calendar_start_year := 250
var _bed_cells: Array[Vector2i] = []
var _pending_player_spawn_cell := Vector2i(2147483647, 2147483647)

const PLAYER_MOVE_REPEAT_INITIAL_DELAY := 0.22
const PLAYER_MOVE_REPEAT_INTERVAL := 0.10
const PLAYER_MOVE_SPEED := 260.0
const PLAYER_MAX_HP := 20.0
const PLAYER_ATTACK_DAMAGE := 2
const PLAYER_ATTACK_COOLDOWN := 0.45
const CREATURE_CAP := 24
const CREATURE_DESPAWN_DISTANCE := 90
const CITY_REGEN_PER_SECOND := 2.0
const COOKING_HEAT_BUILDING_TYPES := ["forge", "smeltery", "tavern", "brewery", "grand_kitchens"]
const SPD_NEIGHBOR_OFFSETS := [
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
	Vector2i(1, 1)
]

const ZONE_OVERLAY_COLORS := {
	CELL_HALL: Color(0.27, 0.58, 0.90, 0.35),
	CELL_HOUSE: Color(0.84, 0.72, 0.24, 0.35),
	CELL_BUILDING: Color(0.61, 0.35, 0.88, 0.35),
	CELL_PLAZA: Color(0.18, 0.74, 0.66, 0.35)
}

const ZONE_LEGEND_ORDER := [
	{"tile": CELL_HALL, "name": "Hall"},
	{"tile": CELL_HOUSE, "name": "House"},
	{"tile": CELL_BUILDING, "name": "Building"},
	{"tile": CELL_PLAZA, "name": "Plaza"}
]

const BUILDING_SUBTYPE_FLAVOR := {
	"forge": "The air rings with hammer blows and quenched steel.",
	"brewery": "Warm casks and sour mash scent the stone halls.",
	"armory": "Weapon racks and sparring marks line the walls.",
	"granary": "Stores of grain and flour are stacked for lean winters.",
	"mushroom_farm": "Low beds of mushrooms thrive in cool, damp soil.",
	"archives": "Tablet shelves and ledgers preserve clan memory."
}

const MIN_ZOOM := 0.1
const MAX_ZOOM := 2.5
const ZOOM_STEP := 0.1

const SHATTERED_VISION_RADIUS := 7
const SHATTERED_UNSEEN_ALPHA := 1.0
const SHATTERED_REVEALED_ALPHA := 0.72
const SHATTERED_VISIBLE_ALPHA := 0.0

const CHEST_SLOT_COLUMNS := 8
const CHEST_SLOT_ROWS := 4
const BACKPACK_SLOT_ROWS := 3


## Spritesheet slots in dwarf_characters.png block order.
const ROLE_MINER := 0
const ROLE_WARRIOR := 1
const ROLE_SMITH := 2
const ROLE_HOLD_ELDER := 3
const ROLE_BREWER := 4
const ROLE_RUNESCRIBE := 5
const ROLE_DWARF_WOMAN := 6
const ROLE_GOLDSMITH := 7

## Which building types each working role reports to, in preference order.
const ROLE_WORKPLACES := {
	ROLE_MINER: ["miners_guild", "smeltery", "mason_lodge", "storage_warehouse", "workshop"],
	ROLE_SMITH: ["forge", "smeltery", "armory", "weapon_shop", "armor_shop", "engineers_foundry", "workshop"],
	ROLE_HOLD_ELDER: ["archives", "guild_hall", "temple", "merchants_counting_house", "cartographers_office"],
	ROLE_BREWER: ["brewery", "tavern", "cooperage", "granary", "kitchen"],
	ROLE_RUNESCRIBE: ["runesmith_sanctum", "enchanting_study", "archives", "alchemy_laboratory"],
	ROLE_DWARF_WOMAN: ["kitchen", "bakery", "tavern", "infirmary", "tailoring_shop", "general_goods_shop", "mushroom_farm", "butchery", "millhouse"],
	ROLE_GOLDSMITH: ["gemcutters_studio", "bank_vaults", "auction_house", "merchants_counting_house", "trade_supply_store"]
}

const ROLE_TITLES := {
	ROLE_MINER: "Miner",
	ROLE_WARRIOR: "Warrior of the Watch",
	ROLE_SMITH: "Smith",
	ROLE_HOLD_ELDER: "Hold Elder",
	ROLE_BREWER: "Brewer",
	ROLE_RUNESCRIBE: "Runescribe",
	ROLE_DWARF_WOMAN: "Homesteader",
	ROLE_GOLDSMITH: "Goldsmith"
}

const DWARFHOLD_SCENE_SEED_KEY := "dwarfhold_scene_seed"
const DWARFHOLD_SCENE_POPULATION_KEY := "dwarfhold_scene_population"

const CHEST_LOOT_TABLE := [
	{"name": "Iron Ingot", "min": 1, "max": 5},
	{"name": "Gold Nugget", "min": 1, "max": 3},
	{"name": "Mushroom Ration", "min": 2, "max": 6},
	{"name": "Runed Tablet", "min": 1, "max": 2},
	{"name": "Ale Keg", "min": 1, "max": 2},
	{"name": "Stone Block", "min": 3, "max": 8},
	{"name": "Leather Strap", "min": 2, "max": 7},
	{"name": "Gem Shard", "min": 1, "max": 4},
	{"name": "Amber", "min": 1, "max": 2},
	{"name": "Copper Ore", "min": 2, "max": 5},
	{"name": "Dried Fish", "min": 1, "max": 3},
	{"name": "Cave Crab", "min": 1, "max": 2},
	{"name": "Miner's Lantern", "min": 1, "max": 1},
	{"name": "Dynamite Stick", "min": 1, "max": 2},
	{"name": "Skeleton Keys", "min": 1, "max": 1},
	{"name": "Rusty Pickaxe", "min": 1, "max": 1},
	{"name": "Old Fishing Rod", "min": 1, "max": 1},
	{"name": "Steel Ingot", "min": 1, "max": 3},
	{"name": "Copper Ingot", "min": 1, "max": 4},
	{"name": "Tin Ingot", "min": 1, "max": 3},
	{"name": "Silver Ore", "min": 1, "max": 2},
	{"name": "Iron Nails", "min": 2, "max": 8},
	{"name": "Chain Links", "min": 1, "max": 4},
	{"name": "Whetstone", "min": 1, "max": 1},
	{"name": "Smith's Tongs", "min": 1, "max": 1},
	{"name": "Jerky Strip", "min": 1, "max": 4},
	{"name": "Cured Ham", "min": 1, "max": 1},
	{"name": "Aged Sausage", "min": 1, "max": 2},
	{"name": "Miner's Pickaxe", "min": 1, "max": 1},
	{"name": "Copper Pick", "min": 1, "max": 1},
	{"name": "Worn Pickaxe", "min": 1, "max": 1},
	{"name": "Steel Pickaxe", "min": 1, "max": 1},
	{"name": "Prospector's Trowel", "min": 1, "max": 1},
	{"name": "Spade", "min": 1, "max": 1},
	{"name": "Steel Trowel", "min": 1, "max": 1},
	{"name": "Wooden Mallet", "min": 1, "max": 1},
	{"name": "Stone Hammer", "min": 1, "max": 1},
	{"name": "Geologist's Hammer", "min": 1, "max": 1},
	{"name": "Sledgehammer", "min": 1, "max": 1},
	{"name": "Silver Lantern", "min": 1, "max": 1},
	{"name": "Mason's Chisel", "min": 1, "max": 2},
	{"name": "Jig Lures", "min": 1, "max": 2},
	{"name": "Painted Lure", "min": 1, "max": 1},
	{"name": "Willow Rod", "min": 1, "max": 1},
	{"name": "Oak Rod", "min": 1, "max": 1},
	{"name": "Fishing Spear", "min": 1, "max": 1},
	{"name": "Casting Net", "min": 1, "max": 1},
	{"name": "Fish Trap", "min": 1, "max": 1},
	{"name": "Barbed Hook", "min": 1, "max": 3},
	{"name": "Grappling Hook", "min": 1, "max": 1},
	{"name": "Silk Line Spool", "min": 1, "max": 2},
	{"name": "Cork Bobber", "min": 1, "max": 3}
]

## Digging rock occasionally turns up a fossil alongside the Stone.
const DIG_FOSSIL_FINDS := [
	"Amber", "Spider Amber", "Fossil Leaf", "Ancient Skull",
	"Fossil Claw", "Ammonite Shell", "Old Bone", "Serpent Spine",
	"Chalk Ammonite", "Beast-Claw Charm", "Fossil Ribs", "Beast Skull",
	"Petrified Bone", "Fossil Fish", "Skeletal Paw", "Moss Agate",
	"Fossil Antler", "Fern Amber", "Fossil Cluster", "Fin Spines"
]
const DIG_FOSSIL_CHANCE_PERCENT := 7

## Ore veins yield more than iron now and then.
const ORE_VEIN_DROPS := [
	{"name": "Iron Ore", "weight": 55, "min": 2, "max": 4},
	{"name": "Copper Ore", "weight": 25, "min": 1, "max": 3},
	{"name": "Gold Nugget", "weight": 12, "min": 1, "max": 2},
	{"name": "Gem Shard", "weight": 8, "min": 1, "max": 1}
]

## Wild fungal growth sometimes includes a rarer species.
const WILD_MUSHROOM_VARIETIES := [
	"Glowcap", "Frostcap", "Emberspore", "Violet Veil",
	"King Bolete", "Fairy Bells", "Scarlet Cap",
	"Chanterelle", "Wine Cap", "Honey Fungus", "Rosegill", "Porcini",
	"Sunshelf", "Bloodbolete", "Oyster Cap", "Inkcap", "Deep Puffball",
	"Scarlet Stem", "Gilded Parasol", "Firegill Shelf", "Flamecrest",
	"Umber Dapperling", "Violet Coral", "Wyrm's Tongue", "Ghost Funnel",
	"Cauliflower Fungus", "Black Morel", "Ash Parasol", "Pink Bonnet",
	"Chestnut Bonnet", "Verdigris Shelf", "Weeping Olive", "Coral Frill",
	"Pale Umbrella", "Star Fungus", "Mahogany Cap", "Nightgill",
	"Amber Shelf", "Rose Puff", "Fire Coral", "Seafoam Parasol",
	"Dragonmane", "Banded Stalk"
]
const MUSHROOM_VARIETY_CHANCE_PERCENT := 30

## Homesteading: B cycles the build catalog, then click a tile beside you
## to raise it. Walls become solid rock again - dig them back for the
## Stone. Placed chests start empty (they store, they don't spawn loot).
const BUILD_CATALOG := [
	{"name": "Stone Wall", "kind": "wall", "costs": {"Stone": 2}},
	{"name": "Paved Floor", "kind": "floor", "costs": {"Stone": 1}},
	{"name": "Door", "kind": "decor", "tile": "door", "costs": {"Stone": 2}},
	{"name": "Bed", "kind": "decor", "tile": "bed", "costs": {"Stone": 4}},
	{"name": "Table", "kind": "decor", "tile": "table", "costs": {"Stone": 3}},
	{"name": "Storage Chest", "kind": "decor", "tile": "chest", "costs": {"Stone": 4}}
]

## Core-Keeper-style fishing in the underdeep's still lakes: cast with F
## next to water (rod required), wait for the bite, reel on the "!".
const FISHING_ROD_ITEM := "Old Fishing Rod"
const FISH_CATCH_TABLE := [
	{"name": "Cave Perch", "weight": 20},
	{"name": "Silver Darter", "weight": 16},
	{"name": "Emerald Trout", "weight": 14},
	{"name": "Ruby Snapper", "weight": 10},
	{"name": "Blindcave Fish", "weight": 10},
	{"name": "Deep Eel", "weight": 8},
	{"name": "Violet Grouper", "weight": 8},
	{"name": "Cave Crab", "weight": 6},
	{"name": "Golden Koi", "weight": 5},
	{"name": "Coral Snail", "weight": 5},
	{"name": "Striped Bass", "weight": 12},
	{"name": "Cobalt Chub", "weight": 12},
	{"name": "Marigold Carp", "weight": 10},
	{"name": "Sapphire Perch", "weight": 10},
	{"name": "Copperback Trout", "weight": 10},
	{"name": "Jade Carp", "weight": 8},
	{"name": "Crimson Carp", "weight": 8},
	{"name": "Flicker Minnow", "weight": 8},
	{"name": "Frilled Loach", "weight": 6},
	{"name": "Duskfin", "weight": 6},
	{"name": "Bloodfin", "weight": 5},
	{"name": "Speckled Prawn", "weight": 5},
	{"name": "Silverfry", "weight": 5},
	{"name": "Amethyst Angelfish", "weight": 4},
	{"name": "Blossom Koi", "weight": 4},
	{"name": "Cave Lobster", "weight": 4},
	{"name": "Pale Squid", "weight": 3},
	{"name": "Gloom Octopus", "weight": 3},
	{"name": "Ember Squid", "weight": 3},
	{"name": "Bloodworm", "weight": 4},
	{"name": "Mud Grub", "weight": 4},
	{"name": "Rusted Hook", "weight": 6},
	{"name": "Cork Bobber", "weight": 2},
	{"name": "Painted Lure", "weight": 2},
	{"name": "Rusty Anchor", "weight": 1},
	{"name": "Skeleton Keys", "weight": 1},
	# Trophy fish: once-in-a-season catches, straight onto a plaque.
	{"name": "Trophy Asp", "weight": 1},
	{"name": "Trophy Tench", "weight": 1},
	{"name": "Trophy Piranha", "weight": 1},
	{"name": "Trophy Zander", "weight": 1},
	{"name": "Trophy Ghost Cat", "weight": 1},
	{"name": "Trophy Rudd", "weight": 1},
	{"name": "Trophy Grayling", "weight": 1},
	{"name": "Trophy Largemouth Bass", "weight": 1},
	{"name": "Trophy Pike", "weight": 1},
	{"name": "Trophy Burbot", "weight": 1},
	{"name": "Trophy Zope", "weight": 1},
	{"name": "Trophy Alligator Gar", "weight": 1},
	{"name": "Trophy Redtail Catfish", "weight": 1},
	{"name": "Trophy Bluegill", "weight": 1},
	{"name": "Trophy Perch", "weight": 1},
	{"name": "Trophy Bleak", "weight": 1},
	{"name": "Trophy Chinese Paddlefish", "weight": 1},
	{"name": "Trophy Ruffe", "weight": 1},
	{"name": "Trophy Beluga Sturgeon", "weight": 1},
	{"name": "Trophy Gudgeon", "weight": 1},
	{"name": "Trophy Baltic Whitefish", "weight": 1},
	{"name": "Trophy Baltic Anchovy", "weight": 1},
	{"name": "Trophy Sandlance", "weight": 1},
	{"name": "Trophy Pipefish", "weight": 1},
	{"name": "Trophy Baltic Flounder", "weight": 1},
	{"name": "Trophy Turbot", "weight": 1},
	{"name": "Trophy Baltic Roach", "weight": 1},
	{"name": "Trophy Eelpout", "weight": 1},
	{"name": "Trophy Baltic Sprat", "weight": 1},
	{"name": "Trophy Belone", "weight": 1},
	{"name": "Trophy Spiny Dogfish", "weight": 1},
	{"name": "Trophy Baltic Herring", "weight": 1},
	{"name": "Trophy Baltic Cod", "weight": 1},
	{"name": "Trophy Sole", "weight": 1},
	{"name": "Trophy Sand Goby", "weight": 1},
	{"name": "Trophy Lumpfish", "weight": 1},
	{"name": "Trophy Round Goby", "weight": 1},
	{"name": "Trophy Baltic Stickleback", "weight": 1},
	{"name": "Trophy Baltic Eel", "weight": 1},
	{"name": "Trophy Sea Trout", "weight": 1},
	{"name": "Trophy Emerald Piranha", "weight": 1},
	{"name": "Trophy Sardine", "weight": 1}
]

const CIVIC_BUILDING_TYPES := {
	"high_kings_palace": {
		"placement_weight": 0.0,
		"preferred_footprint_min": Vector2i(5, 4),
		"preferred_footprint_max": Vector2i(7, 5),
		"decor_tile_pool": ["sign", "chest", "armor_stand", "table_alt"],
		"adjacency_preferences": {}
	},
	"forge": {
		"placement_weight": 1.25,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["anvil", "workbench", "armor_stand", "water_bucket"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.7
		}
	},
	"engineering_workshop": {
		"placement_weight": 0.8,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(5, 3),
		"decor_tile_pool": ["workbench", "anvil", "desk", "water_bucket"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.35
		}
	},
	"leatherworking_shop": {
		"placement_weight": 0.55,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["workbench", "table", "chest", "water_bucket"],
		"adjacency_preferences": {}
	},
	"tailoring_shop": {
		"placement_weight": 0.5,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["table", "stool", "shelf", "chest"],
		"adjacency_preferences": {}
	},
	"enchanting_study": {
		"placement_weight": 0.42,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["sign", "desk", "shelf", "table_alt"],
		"adjacency_preferences": {}
	},
	"alchemy_laboratory": {
		"placement_weight": 0.5,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["water_bucket", "table_alt", "desk", "chest"],
		"adjacency_preferences": {}
	},
	"auction_house": {
		"placement_weight": 0.45,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(5, 3),
		"decor_tile_pool": ["desk", "table_alt", "sign", "chest"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.15
		}
	},
	"general_goods_shop": {
		"placement_weight": 0.7,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["shelf", "table", "chest", "grain_bag"],
		"adjacency_preferences": {}
	},
	"weapon_shop": {
		"placement_weight": 0.65,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["target", "anvil", "workbench", "armor_stand"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.25
		}
	},
	"armor_shop": {
		"placement_weight": 0.62,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["armor_stand", "workbench", "chest", "table"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.2
		}
	},
	"trade_supply_store": {
		"placement_weight": 0.6,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["grain_bag", "keg", "chest", "table"],
		"adjacency_preferences": {}
	},
	"bank_vaults": {
		"placement_weight": 0.35,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["chest", "desk", "sign", "table_alt"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.1
		}
	},
	"tavern": {
		"placement_weight": 0.9,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(5, 3),
		"decor_tile_pool": ["keg", "mug", "table_alt", "stool"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.2
		}
	},
	"barber_shop": {
		"placement_weight": 0.35,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["stool", "table", "desk", "water_bucket"],
		"adjacency_preferences": {}
	},
	"guild_hall": {
		"placement_weight": 0.5,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(5, 3),
		"decor_tile_pool": ["table", "table_alt", "sign", "chest"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.2
		}
	},
	"storage_warehouse": {
		"placement_weight": 0.7,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(5, 3),
		"decor_tile_pool": ["chest", "grain_bag", "keg", "shelf"],
		"adjacency_preferences": {}
	},
	"brewery": {
		"placement_weight": 1.05,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["keg", "winepress", "mug", "table_alt"],
		"adjacency_preferences": {}
	},
	"granary": {
		"placement_weight": 0.95,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["grain_bag", "flour", "shelf", "table"],
		"adjacency_preferences": {}
	},
	"armory": {
		"placement_weight": 0.9,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["armor_stand", "target", "anvil", "workbench"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.45
		}
	},
	"workshop": {
		"placement_weight": 1.1,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["workbench", "desk", "shelf", "butcher_table"],
		"adjacency_preferences": {}
	},
	"kitchen": {
		"placement_weight": 0.85,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["butcher_table", "table", "stool", "water_bucket"],
		"adjacency_preferences": {}
	},
	"barracks": {
		"placement_weight": 0.8,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(5, 3),
		"decor_tile_pool": ["bed", "chest", "armor_stand", "target"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.35
		}
	},
	"temple": {
		"placement_weight": 0.65,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["table_alt", "sign", "mug", "stool"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.2
		}
	},
	"mushroom_farm": {
		"placement_weight": 0.7,
		"preferred_footprint_min": Vector2i(3, 3),
		"preferred_footprint_max": Vector2i(5, 4),
		"decor_tile_pool": ["mushroom_crops", "mushroom_crop_wild", "grain_bag", "water_bucket"],
		"adjacency_preferences": {}
	},
	"archives": {
		"placement_weight": 0.55,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["shelf", "desk", "sign", "chest"],
		"adjacency_preferences": {}
	},
	"infirmary": {
		"placement_weight": 0.6,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["bed", "table", "water_bucket", "chest"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.25
		}
	},
	"miners_guild": {
		"placement_weight": 0.75,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(5, 3),
		"decor_tile_pool": ["stone", "target", "workbench", "chest"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.3
		}
	},
	"mason_lodge": {
		"placement_weight": 0.7,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["stone", "table", "desk", "workbench"],
		"adjacency_preferences": {}
	},
	"engineers_foundry": {
		"placement_weight": 0.65,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["anvil", "workbench", "desk", "water_bucket"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.4
		}
	},
	"gemcutters_studio": {
		"placement_weight": 0.6,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["table_alt", "chest", "sign", "desk"],
		"adjacency_preferences": {}
	},
	"runesmith_sanctum": {
		"placement_weight": 0.5,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["anvil", "sign", "shelf", "desk"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.2
		}
	},
	"smeltery": {
		"placement_weight": 0.7,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(5, 3),
		"decor_tile_pool": ["anvil", "water_bucket", "stone", "workbench"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.5
		}
	},
	"cartographers_office": {
		"placement_weight": 0.45,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["desk", "sign", "table", "shelf"],
		"adjacency_preferences": {}
	},
	"explorers_guild": {
		"placement_weight": 0.55,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["target", "table", "chest", "water_bucket"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.15
		}
	},
	"merchants_counting_house": {
		"placement_weight": 0.55,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["desk", "chest", "table_alt", "shelf"],
		"adjacency_preferences": {}
	},
	"butchery": {
		"placement_weight": 0.75,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["butcher_table", "table", "water_bucket", "chest"],
		"adjacency_preferences": {}
	},
	"bakery": {
		"placement_weight": 0.7,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["table_alt", "flour", "grain_bag", "stool"],
		"adjacency_preferences": {}
	},
	"cooperage": {
		"placement_weight": 0.6,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["keg", "workbench", "chest", "table"],
		"adjacency_preferences": {}
	},
	"tannery": {
		"placement_weight": 0.55,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["water_bucket", "workbench", "chest", "table_alt"],
		"adjacency_preferences": {}
	},
	"millhouse": {
		"placement_weight": 0.65,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["flour", "grain_bag", "table", "shelf"],
		"adjacency_preferences": {}
	},
	"cobblers_shop": {
		"placement_weight": 0.45,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["stool", "chest", "table", "desk"],
		"adjacency_preferences": {}
	},
	"ropemakers_hall": {
		"placement_weight": 0.45,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["table", "workbench", "chest", "stool"],
		"adjacency_preferences": {}
	}
}

func _ready() -> void:
	_apply_cached_dwarfhold_scene_seed()
	_configure_tile_layer()
	global_darkness.color = Color(1.0, 1.0, 1.0, 1.0)
	_lighting_mask_sprite = Sprite2D.new()
	_lighting_mask_sprite.centered = false
	lighting_layer.add_child(_lighting_mask_sprite)
	fog_of_war.visible = false
	_tavern_character_texture = load(tavern_vehicle_sprite_path) as Texture2D
	if _tavern_character_texture == null:
		_tavern_character_texture = _create_placeholder_tavern_character_texture()
	_shattered_player_texture = DwarfHoldActorVisuals.resolve_hero_texture(self)
	if _shattered_player_texture == null:
		_shattered_player_texture = load(shattered_player_sprite_path) as Texture2D
	_creature_texture = load(creature_sprite_path) as Texture2D
	_placeholder_actor_texture = _create_placeholder_actor_texture()
	generate_button.pressed.connect(_on_generate_pressed)
	depth_down_button.pressed.connect(_on_depth_down_pressed)
	depth_up_button.pressed.connect(_on_depth_up_pressed)
	overlay_toggle.toggled.connect(_on_overlay_toggle_toggled)
	lighting_toggle.toggled.connect(_on_lighting_toggle_toggled)
	city_panel.gui_input.connect(_on_city_panel_gui_input)
	city_panel.mouse_exited.connect(_hide_hover_tooltip)
	chest_popup_take_all_button.pressed.connect(_on_loot_chest_button_pressed)
	chest_popup_close_button.pressed.connect(_on_chest_popup_close_button_pressed)
	chest_popup_close_footer_button.pressed.connect(_on_chest_popup_close_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	save_game_button.pressed.connect(_on_save_game_button_pressed)
	_initialize_chest_popup_grids()
	seed_input.text_submitted.connect(func(_text: String) -> void:
		_generate_city()
	)
	_update_zone_legend()
	_lighting_enabled = lighting_toggle.button_pressed
	_apply_lighting_state()
	_clear_chest_selection()
	_update_player_character_label()
	_game_hour = clampf(clock_start_hour, 0.0, 23.99)
	_update_clock_label()
	_setup_inventory_label()
	_setup_hp_label()
	_setup_coins_label()
	_escape_menu = EscapeMenu.new()
	_escape_menu.show_return_to_map = true
	add_child(_escape_menu)
	_glow_texture = _create_glow_texture()
	_player_glow = _create_glow_sprite(7.0)
	lighting_layer.add_child(_player_glow)
	_player_glow.visible = false
	_generate_city()

func _setup_inventory_label() -> void:
	var controls := get_node_or_null("Margin/Layout/Controls")
	if controls == null:
		return
	_inventory_label = Label.new()
	_inventory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inventory_label.add_theme_font_size_override("font_size", 13)
	controls.add_child(_inventory_label)
	var clock := controls.get_node_or_null("ClockLabel")
	if clock != null:
		controls.move_child(_inventory_label, clock.get_index() + 1)
	_update_inventory_label()

func _create_glow_texture() -> Texture2D:
	var glow_size := 128
	var image := Image.create(glow_size, glow_size, false, Image.FORMAT_RGBA8)
	var center := Vector2(glow_size / 2.0, glow_size / 2.0)
	for y in range(glow_size):
		for x in range(glow_size):
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(center) / (glow_size / 2.0)
			var strength := clampf(1.0 - distance, 0.0, 1.0)
			strength = strength * strength
			image.set_pixel(x, y, Color(1.0, 0.85, 0.6, strength * 0.85))
	return ImageTexture.create_from_image(image)

func _create_glow_sprite(tile_span: float) -> Sprite2D:
	var glow := Sprite2D.new()
	glow.texture = _glow_texture
	glow.centered = true
	var glow_material := CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = glow_material
	glow.scale = Vector2.ONE * (tile_span * float(tile_size.x) / 128.0)
	glow.z_index = 15
	return glow

func _process(delta: float) -> void:
	_advance_game_clock(delta)
	_stream_world_chunks()
	_update_wild_darkness(delta)
	_player_attack_timer = maxf(_player_attack_timer - delta, 0.0)
	_update_creature_spawning(delta)
	_update_creatures(delta)
	_update_player_regen(delta)
	_update_fishing(delta)

## The city and deep levels stay lit; the wild underground is dark, held
## back by the player's lantern glow and any placed torches.
func _update_wild_darkness(delta: float) -> void:
	var target := 1.0
	if not _world_noise.is_empty() and _player_sprite != null and not _latest_district_cell_map.has(_player_cell):
		target = 0.4
	_light_dim = lerpf(_light_dim, target, clampf(delta * 3.0, 0.0, 1.0))
	var dim_color := Color(_light_dim, _light_dim, _light_dim, 1.0)
	city_layer.modulate = dim_color
	decor_layer.modulate = dim_color
	actor_layer.modulate = dim_color
	if _player_glow != null:
		_player_glow.visible = _light_dim < 0.95 and _player_sprite != null
		if _player_sprite != null:
			_player_glow.position = _player_sprite.position
	_update_player_turn_movement(delta)
	_update_player_hold_movement(delta)
	_update_npc_movement(delta)

func _advance_game_clock(delta: float) -> void:
	if minutes_per_game_day <= 0.0:
		return
	_game_hour += delta * 24.0 / (minutes_per_game_day * 60.0)
	while _game_hour >= 24.0:
		_game_hour -= 24.0
		_game_day += 1
	_update_clock_label()

func _update_clock_label() -> void:
	if clock_label == null:
		return
	var hour := int(_game_hour)
	var minute := int((_game_hour - float(hour)) * 60.0)
	var is_rest_shift := _game_hour >= 22.0 or _game_hour < 6.0
	clock_label.text = "%s %02d:%02d — %s (%s)" % [
		"🌙" if is_rest_shift else "⛏",
		hour,
		minute,
		GameCalendar.date_text(_game_day - 1, _calendar_start_year),
		GameCalendar.season_for_day(_game_day - 1)
	]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _is_text_input_focused():
		if _escape_menu != null:
			_escape_menu.toggle()
		get_viewport().set_input_as_handled()
		return
	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_T and not _is_text_input_focused():
		_place_torch()
		get_viewport().set_input_as_handled()
		return
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F and not _is_text_input_focused():
		_handle_fish_action()
		get_viewport().set_input_as_handled()
		return
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_B and not _is_text_input_focused():
		_cycle_build_selection()
		get_viewport().set_input_as_handled()
		return
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_C and not _is_text_input_focused():
		_handle_cook_action()
		get_viewport().set_input_as_handled()
		return
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_E and not _is_text_input_focused():
		_handle_quick_eat_action()
		get_viewport().set_input_as_handled()
		return
	if _player_sprite == null or not _player_control_enabled:
		return
	if _is_text_input_focused():
		return
	var move_direction := DwarfHoldUiInputHandler.move_direction_from_event(event)
	if move_direction != Vector2i.ZERO:
		_handle_player_move_input(move_direction)

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(OVERWORLD_SCENE_PATH)

func _on_save_game_button_pressed() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("save_to_file"):
		_set_save_status("Save unavailable", Color(0.95, 0.45, 0.45, 1.0))
		return
	var result: int = int(game_session.call("save_to_file"))
	if result == OK:
		_set_save_status("Game saved", Color(0.6, 0.9, 0.6, 1.0))
	else:
		_set_save_status("Save failed (%d)" % result, Color(0.95, 0.45, 0.45, 1.0))

func _set_save_status(text: String, color: Color) -> void:
	if save_status_label == null:
		return
	save_status_label.text = text
	save_status_label.modulate = color

func _update_player_character_label() -> void:
	if player_character_label == null:
		return
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_player_character"):
		player_character_label.text = ""
		return
	var character: Dictionary = game_session.call("get_player_character")
	if character.is_empty():
		player_character_label.text = ""
		return
	var display_name := str(character.get("name", "")).strip_edges()
	var clan := str(character.get("clan", "")).strip_edges()
	var profession := str(character.get("profession", "")).strip_edges()
	var parts := PackedStringArray()
	if not display_name.is_empty():
		parts.append(display_name)
	if not clan.is_empty():
		parts.append("of %s" % clan)
	var header := " ".join(parts) if not parts.is_empty() else "Unnamed Dwarf"
	if not profession.is_empty():
		header += " — %s" % profession
	player_character_label.text = header

func _handle_player_move_input(direction: Vector2i) -> void:
	_request_player_move_to_cell(_player_cell + direction)
	_last_move_direction = direction
	_move_repeat_timer = PLAYER_MOVE_REPEAT_INITIAL_DELAY

func _update_player_hold_movement(delta: float) -> void:
	if _player_sprite == null or not _player_control_enabled:
		_reset_player_hold_state()
		return
	if _is_text_input_focused():
		_reset_player_hold_state()
		return

	var move_direction := _current_move_input_direction()
	if move_direction == Vector2i.ZERO:
		_reset_player_hold_state()
		return

	if move_direction != _last_move_direction:
		_handle_player_move_input(move_direction)
		return

	_move_repeat_timer -= delta
	while _move_repeat_timer <= 0.0:
		_request_player_move_to_cell(_player_cell + move_direction)
		_move_repeat_timer += PLAYER_MOVE_REPEAT_INTERVAL

func _current_move_input_direction() -> Vector2i:
	return DwarfHoldUiInputHandler.current_move_input_direction()

func _reset_player_hold_state() -> void:
	_last_move_direction = Vector2i.ZERO
	_move_repeat_timer = 0.0

func _update_player_turn_movement(delta: float) -> void:
	if _player_sprite == null or not _player_control_enabled:
		_player_move_path.clear()
		_player_is_moving = false
		_player_pending_chest_interaction = Vector2i(2147483647, 2147483647)
		return

	if _player_is_moving:
		var next_position := _player_sprite.position.move_toward(_player_move_target_position, PLAYER_MOVE_SPEED * delta)
		_player_sprite.position = next_position
		_center_view_on_world_position(next_position)
		if next_position.distance_to(_player_move_target_position) > 0.5:
			return
		_player_sprite.position = _player_move_target_position
		_player_cell = _player_move_target_cell
		_player_is_moving = false
		if _try_use_stairs_at_player_cell():
			return
		if not _latest_grid.is_empty():
			_update_shattered_visibility(_latest_grid)
			_refresh_lighting(_latest_grid)

	if _player_move_path.is_empty():
		if _player_pending_chest_interaction.x != 2147483647:
			if _is_player_adjacent_to_cell(_player_pending_chest_interaction):
				_handle_chest_click(_screen_position_from_cell(_player_pending_chest_interaction))
			_player_pending_chest_interaction = Vector2i(2147483647, 2147483647)
		return

	var next_cell := _player_move_path[0]
	if _player_cell == next_cell:
		_player_move_path.pop_front()
		return

	if _is_cell_occupied_by_npc(next_cell):
		_player_move_path.clear()
		return

	if _try_move_player(next_cell - _player_cell):
		_player_move_path.pop_front()

func _is_text_input_focused() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit

func _is_move_pressed(event: InputEvent, action_name: StringName, wasd_key: Key) -> bool:
	if event.is_action_pressed(action_name):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == wasd_key

func _update_zone_legend() -> void:
	var lines: PackedStringArray = ["[b]Zone Overlay Legend[/b]"]
	for entry: Dictionary in ZONE_LEGEND_ORDER:
		var tile := int(entry["tile"])
		var zone_name := String(entry["name"])
		var color := Color(ZONE_OVERLAY_COLORS[tile])
		var color_hex := color.to_html(false)
		lines.append("[color=#%s]■[/color] %s" % [color_hex, zone_name])
	zone_legend.text = "\n".join(lines)

func _configure_tile_layer() -> void:
	if OS.is_debug_build():
		TILE_ATLAS_DEFS.validate_all_atlases()
	if not FileAccess.file_exists(tilesheet_path):
		push_error("Missing dwarf hold tilesheet at %s" % tilesheet_path)
		return
	var texture := load(tilesheet_path) as Texture2D
	if texture == null:
		push_error("Unable to load dwarf hold tilesheet texture at %s" % tilesheet_path)
		return

	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = tile_size
	var unique_atlas_coords: Dictionary = {}
	for atlas_coords: Vector2i in TILE_ATLAS.values():
		unique_atlas_coords[atlas_coords] = true
	for atlas_coords: Vector2i in unique_atlas_coords.keys():
		atlas.create_tile(atlas_coords)

	var tile_set := TileSet.new()
	tile_set.tile_size = tile_size
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, COLLISION_LAYER_WORLD)
	tile_set.set_physics_layer_collision_mask(0, 0)
	tile_set.add_source(atlas, 0)

	var collision_polygon := PackedVector2Array([
		Vector2.ZERO,
		Vector2(tile_size.x, 0),
		Vector2(tile_size.x, tile_size.y),
		Vector2(0, tile_size.y)
	])
	for atlas_coords: Vector2i in unique_atlas_coords.keys():
		var tile_data := atlas.get_tile_data(atlas_coords, 0)
		if tile_data == null:
			continue
		if _is_passable_atlas_tile(atlas_coords):
			tile_data.set_collision_polygons_count(0, 0)
		else:
			tile_data.set_collision_polygons_count(0, 1)
			tile_data.set_collision_polygon_points(0, 0, collision_polygon)

	city_layer.tile_set = tile_set
	decor_layer.tile_set = tile_set

func _is_passable_atlas_tile(atlas_coords: Vector2i) -> bool:
	for tile_key: String in PASSABLE_TILE_KEYS:
		if TILE_ATLAS.get(tile_key, Vector2i(-1, -1)) == atlas_coords:
			return true
	return false

func _is_passable_cell_for_actor(cell: Vector2i) -> bool:
	if city_layer.get_cell_source_id(cell) < 0:
		return false
	if not _is_passable_atlas_tile(city_layer.get_cell_atlas_coords(cell)):
		return false
	if decor_layer.get_cell_source_id(cell) < 0:
		return true
	return _is_passable_atlas_tile(decor_layer.get_cell_atlas_coords(cell))

func _apply_cached_dwarfhold_scene_seed() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	var scene_seed := _hold_state.apply_world_settings(settings, DWARFHOLD_SCENE_SEED_KEY, DWARFHOLD_SCENE_POPULATION_KEY)
	var chronology := settings.get("chronology", {}) as Dictionary
	_calendar_start_year = maxi(1, int(chronology.get("year", 250)))
	_underdeep_sites = []
	_sites_by_chunk = {}
	for site_variant: Variant in (settings.get("underdeep_sites", []) as Array):
		var raw_site := site_variant as Dictionary
		var site_cell := Vector2i(int(raw_site.get("x", 0)), int(raw_site.get("y", 0)))
		if maxi(absi(site_cell.x), absi(site_cell.y)) < 90:
			continue
		var site := {
			"name": String(raw_site.get("name", "Lost Settlement")),
			"type": String(raw_site.get("type", "town")),
			"cell": site_cell
		}
		_underdeep_sites.append(site)
		var site_chunk_key: String = UndergroundWorldService.chunk_key(UndergroundWorldService.chunk_for_cell(site_cell))
		if not _sites_by_chunk.has(site_chunk_key):
			_sites_by_chunk[site_chunk_key] = []
		(_sites_by_chunk[site_chunk_key] as Array).append(site)
	var inventory_variant: Variant = settings.get("player_inventory", {})
	_player_inventory = (inventory_variant as Dictionary).duplicate() if inventory_variant is Dictionary else {}
	_player_coins = int(settings.get("player_coins", 0))
	if scene_seed.is_empty():
		return
	seed_input.text = scene_seed

func _on_generate_pressed() -> void:
	_generate_city()

func _on_depth_down_pressed() -> void:
	_show_level(_hold_state.current_level_index - 1)

func _on_depth_up_pressed() -> void:
	_show_level(_hold_state.current_level_index + 1)

func _generate_city() -> void:
	var seed_text := seed_input.text.strip_edges()
	if seed_text.is_empty():
		_rng.randomize()
		seed_text = str(_rng.randi())
		seed_input.text = seed_text

	_rng.seed = hash(seed_text)
	_world_seed_hash = hash(seed_text)
	_hold_state.generated_levels.clear()

	var minimum_levels := mini(underground_level_count_range.x, underground_level_count_range.y)
	var maximum_levels := maxi(underground_level_count_range.x, underground_level_count_range.y)
	var level_count := _hold_state.population_scaled_level_count(maximum_levels)
	if level_count <= 0:
		level_count = maxi(1, _rng.randi_range(minimum_levels, maximum_levels))
	for level_index in range(level_count):
		var level_seed := "%s::depth_%d" % [seed_text, level_index]
		_hold_state.generated_levels.append(_generate_single_level(level_seed, level_index, level_count))

	_show_level(0)

func _generate_single_level(level_seed: String, level_index: int, level_count: int) -> Dictionary:
	_rng.seed = hash(level_seed)
	var is_additional_layer := level_index > 0

	var target_npcs_for_level := _target_npcs_for_level(level_index, level_count)
	var population_scaled := _hold_state.target_resident_npcs > 0

	# 10:1 rule: a hold with population 5,000 hosts 500 resident NPCs, so it
	# digs 500 beds and enough job sites, halls and plazas to support them.
	# Without population data (standalone testing, abandoned ruins) fall back
	# to the legacy fixed ranges.
	var requested_bed_count: int
	var requested_hall_count: int
	var requested_building_count: int
	var requested_plaza_count: int
	if population_scaled:
		requested_bed_count = target_npcs_for_level
		requested_building_count = maxi(2, int(ceil(float(target_npcs_for_level) / 6.0)))
		requested_hall_count = maxi(3, int(ceil(float(target_npcs_for_level) / 24.0)))
		requested_plaza_count = clampi(1 + target_npcs_for_level / 60, 1, 14)
	else:
		requested_hall_count = _pick_seeded_zone_target(hall_zone_count_range)
		requested_bed_count = 0 if is_additional_layer else _pick_seeded_zone_target(housing_zone_count_range)
		requested_building_count = 0 if is_additional_layer else _pick_seeded_zone_target(civic_building_zone_count_range)
		requested_plaza_count = _pick_seeded_zone_target(plaza_zone_count_range)

	# Physical spread follows the level's bed target: ~110 beds matches the
	# legacy footprint, a 50-resident hold shrinks, a great hold sprawls.
	var footprint_scale := 1.0
	if population_scaled:
		footprint_scale = clampf(sqrt(float(maxi(target_npcs_for_level, 1)) / 110.0), 0.35, 1.8)

	var requested_zone_counts := {
		"halls": requested_hall_count,
		"houses": requested_bed_count,
		"beds": requested_bed_count,
		"buildings": requested_building_count,
		"plazas": requested_plaza_count
	}

	var grid: Dictionary = {}
	_latest_civic_buildings_by_id = {}
	_latest_civic_building_type_map = {}
	_latest_residence_type_map = {}
	var district_labels: Array = []
	var district_cell_map: Dictionary = {}
	var floor_decor: Dictionary = {}
	if level_index == 0:
		# The surface level is a full city of named districts; deeper levels
		# keep the older warren generator as the hold's lower reaches.
		var city_plan := DwarfHoldDistrictPlanner.generate_city_level(
			_rng,
			target_npcs_for_level,
			_hold_state.target_resident_npcs,
			requested_bed_count,
			requested_building_count
		)
		grid = city_plan.get("grid", {}) as Dictionary
		_latest_civic_building_type_map = city_plan.get("building_type_map", {}) as Dictionary
		_latest_residence_type_map = city_plan.get("residence_type_map", {}) as Dictionary
		district_labels = city_plan.get("district_labels", []) as Array
		district_cell_map = city_plan.get("district_cell_map", {}) as Dictionary
		floor_decor = city_plan.get("floor_decor", {}) as Dictionary
	else:
		var plaza_layouts: Array[Dictionary] = []
		var central_plaza_radius := Vector2i(
			maxi(4, roundi(float(_rng.randi_range(12, 18)) * footprint_scale)),
			maxi(3, roundi(float(_rng.randi_range(10, 16)) * footprint_scale))
		)
		var central_plaza_shape := _roll_plaza_shape()
		var central_plaza := {"center": Vector2i.ZERO, "radius": central_plaza_radius, "shape": central_plaza_shape}
		_dig_plaza_zone(
			grid,
			central_plaza["center"] as Vector2i,
			central_plaza["radius"] as Vector2i,
			String(central_plaza["shape"]),
			CELL_PLAZA
		)
		plaza_layouts.append(central_plaza)

		for _plaza_index in maxi(0, requested_plaza_count - 1):
			var plaza_radius := Vector2i(
				maxi(3, roundi(float(_rng.randi_range(10, 18)) * footprint_scale)),
				maxi(3, roundi(float(_rng.randi_range(8, 15)) * footprint_scale))
			)
			var plaza_shape := _roll_plaza_shape()
			var plaza_center := Vector2i.ZERO
			var found_location := false
			var plaza_spacing := maxi(8, roundi(22.0 * footprint_scale))
			for _placement_attempt in 24:
				var plaza_anchor := (plaza_layouts[_rng.randi_range(0, plaza_layouts.size() - 1)] as Dictionary).get("center", Vector2i.ZERO) as Vector2i
				var plaza_direction := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][_rng.randi_range(0, 3)] as Vector2i
				var plaza_offset_distance := maxi(18, roundi(float(_rng.randi_range(56, 120)) * footprint_scale))
				var candidate_center := plaza_anchor + plaza_direction * plaza_offset_distance
				candidate_center += Vector2i(_rng.randi_range(-14, 14), _rng.randi_range(-14, 14))
				if _is_plaza_too_close(candidate_center, plaza_radius, plaza_layouts, plaza_spacing):
					continue
				plaza_center = candidate_center
				found_location = true
				break
			if not found_location:
				var fallback_spread := maxi(40, roundi(160.0 * footprint_scale))
				plaza_center = (plaza_layouts[_rng.randi_range(0, plaza_layouts.size() - 1)] as Dictionary).get("center", Vector2i.ZERO) as Vector2i
				plaza_center += Vector2i(_rng.randi_range(-fallback_spread, fallback_spread), _rng.randi_range(-fallback_spread, fallback_spread))
			_dig_plaza_zone(grid, plaza_center, plaza_radius, plaza_shape, CELL_PLAZA)
			plaza_layouts.append({"center": plaza_center, "radius": plaza_radius, "shape": plaza_shape})

		var hubs: Array[Vector2i] = []
		for plaza_data_variant: Variant in plaza_layouts:
			var plaza_data := plaza_data_variant as Dictionary
			hubs.append(plaza_data.get("center", Vector2i.ZERO) as Vector2i)

		if plaza_layouts.size() >= 2:
			for plaza_index in range(1, plaza_layouts.size()):
				var from_plaza := plaza_layouts[plaza_index] as Dictionary
				var from_center := from_plaza.get("center", Vector2i.ZERO) as Vector2i
				var nearest_index := 0
				var nearest_distance := INF
				for candidate_index in range(plaza_index):
					var candidate_center := (plaza_layouts[candidate_index] as Dictionary).get("center", Vector2i.ZERO) as Vector2i
					var candidate_distance := from_center.distance_squared_to(candidate_center)
					if candidate_distance < nearest_distance:
						nearest_distance = candidate_distance
						nearest_index = candidate_index
				var to_plaza := plaza_layouts[nearest_index] as Dictionary
				_dig_branching_hall_between_plazas(grid, from_plaza, to_plaza)

		var extra_hall_branches := maxi(0, requested_hall_count - maxi(0, plaza_layouts.size() - 1))
		for _extra_hall_index in extra_hall_branches:
			if plaza_layouts.size() < 2:
				break
			var from_index := _rng.randi_range(0, plaza_layouts.size() - 1)
			var to_index := _rng.randi_range(0, plaza_layouts.size() - 2)
			if to_index >= from_index:
				to_index += 1
			_dig_branching_hall_between_plazas(grid, plaza_layouts[from_index] as Dictionary, plaza_layouts[to_index] as Dictionary)

		# Place residences until the level's bed budget is met: mostly houses
		# (one bed each), with dormitories and barracks packing bed rows for
		# larger populations.
		var beds_planned := 0
		var residences_placed := 0
		var max_residence_attempts := requested_bed_count * 2 + 60
		for _residence_attempt in max_residence_attempts:
			if beds_planned >= requested_bed_count:
				break
			var residence_type := _roll_residence_type()
			# Small remainders shouldn't burn the budget on one huge barracks.
			if requested_bed_count - beds_planned < 6 and residence_type != "house":
				residence_type = "house"
			var residence_footprint := _roll_residence_footprint(residence_type)
			var estimated_beds := _estimate_residence_beds(residence_type, residence_footprint)
			var placed := _place_structure_along_halls(grid, CELL_HOUSE, residence_footprint, residence_type)
			if not placed:
				placed = _place_structure_zone(
					grid,
					hubs,
					CELL_HOUSE,
					func() -> Vector2i:
						return Vector2i(_rng.randi_range(-14, 14), _rng.randi_range(-9, 9)),
					func() -> Vector2i:
						return residence_footprint,
					residence_type
				)
			if placed:
				beds_planned += estimated_beds
				residences_placed += 1
		requested_zone_counts["houses"] = residences_placed

		for i in requested_building_count:
			var civic_type := _pick_civic_building_type()
			var civic_definition := CIVIC_BUILDING_TYPES[civic_type] as Dictionary
			var civic_footprint := _roll_civic_footprint(civic_definition)
			var prefers_hall_arteries := _civic_prefers_hall_arteries(civic_definition)
			if prefers_hall_arteries and _place_structure_along_halls(grid, CELL_BUILDING, civic_footprint, civic_type):
				continue
			var civic_size_generator := func() -> Vector2i:
				return civic_footprint
			var placed := _place_structure_zone(
				grid,
				hubs,
				CELL_BUILDING,
				func() -> Vector2i:
					return Vector2i(_rng.randi_range(-15, 15), _rng.randi_range(-10, 10)),
				civic_size_generator,
				civic_type
			)
			if not placed and not prefers_hall_arteries:
				_place_structure_along_halls(grid, CELL_BUILDING, civic_footprint, civic_type)


	_ensure_walkable_connectivity(grid)
	var level_door_cells := _compute_single_doors(grid)
	_ensure_door_connectivity(grid, level_door_cells)
	_ensure_walkable_connectivity(grid)
	var civic_buildings_by_id := _compute_civic_buildings_by_id(grid)
	var civic_building_type_map := _build_civic_building_type_lookup(civic_buildings_by_id)
	var zone_counts := _count_zone_components(grid)
	var stair_cells := _pick_level_stair_cells(grid, level_index, level_count)
	return {
		"grid": grid,
		"door_cells": level_door_cells,
		"zone_counts": zone_counts,
		"requested_zone_counts": requested_zone_counts,
		"civic_buildings_by_id": civic_buildings_by_id,
		"civic_building_type_map": civic_building_type_map,
		"residence_type_map": _latest_residence_type_map,
		"district_labels": district_labels,
		"district_cell_map": district_cell_map,
		"floor_decor": floor_decor,
		"stair_cells": stair_cells
	}

func _show_level(target_level_index: int) -> void:
	if _hold_state.generated_levels.is_empty():
		depth_down_button.disabled = true
		depth_up_button.disabled = true
		depth_label.text = "Level 0 / 0"
		return

	_hold_state.current_level_index = clampi(target_level_index, 0, _hold_state.generated_levels.size() - 1)
	var level_data := _hold_state.generated_levels[_hold_state.current_level_index] as Dictionary
	var grid := level_data.get("grid", {}) as Dictionary
	_door_cells = level_data.get("door_cells", {}) as Dictionary
	_latest_grid = grid
	_latest_zone_counts = level_data.get("zone_counts", {}) as Dictionary
	_latest_requested_zone_counts = level_data.get("requested_zone_counts", {}) as Dictionary
	_latest_civic_buildings_by_id = level_data.get("civic_buildings_by_id", {}) as Dictionary
	_latest_civic_building_type_map = level_data.get("civic_building_type_map", {}) as Dictionary
	_latest_residence_type_map = level_data.get("residence_type_map", {}) as Dictionary
	_latest_district_labels = level_data.get("district_labels", []) as Array
	_latest_district_cell_map = level_data.get("district_cell_map", {}) as Dictionary
	_latest_floor_decor = level_data.get("floor_decor", {}) as Dictionary
	if _hold_state.current_level_index == 0:
		# The surface level is an open, diggable underground: rock beyond
		# the city streams in as deterministic noise-carved chunks.
		if not level_data.has("generated_chunks"):
			level_data["generated_chunks"] = {}
		if not level_data.has("dug_cells"):
			level_data["dug_cells"] = {}
		_generated_chunks = level_data.get("generated_chunks", {}) as Dictionary
		_dug_cells = level_data.get("dug_cells", {}) as Dictionary
		_world_noise = UndergroundWorldService.make_noise_set(_world_seed_hash)
	else:
		_world_noise = {}
		_generated_chunks = {}
		_dug_cells = {}
	_last_player_chunk = Vector2i(2147483647, 2147483647)
	_hold_state.active_level_stairs = level_data.get("stair_cells", {}) as Dictionary

	_chest_inventories.clear()
	_clear_chest_selection()
	_render_city(grid, _hold_state.active_level_stairs)
	_spawn_tavern_characters(grid)
	# After the NPC spawn (which rebuilds the actor layer's children).
	_furnish_interiors(grid)
	_update_summary(grid, seed_input.text.strip_edges())
	_update_zone_overlay()
	_update_depth_controls()

func _update_depth_controls() -> void:
	var level_count := _hold_state.generated_levels.size()
	if level_count <= 0:
		depth_down_button.disabled = true
		depth_up_button.disabled = true
		depth_label.text = "Level 0 / 0"
		return
	depth_down_button.disabled = _hold_state.current_level_index <= 0
	depth_up_button.disabled = _hold_state.current_level_index >= level_count - 1
	depth_label.text = "Level %d / %d" % [_hold_state.current_level_index + 1, level_count]


func _pick_seeded_zone_target(count_range: Vector2i) -> int:
	return DwarfHoldGenerationRules.pick_seeded_zone_target(_rng, count_range)

func _roll_residence_type() -> String:
	var roll := _rng.randf()
	var cumulative := 0.0
	for type_name: String in RESIDENCE_TYPES.keys():
		cumulative += float((RESIDENCE_TYPES[type_name] as Dictionary).get("weight", 0.0))
		if roll <= cumulative:
			return type_name
	return "house"

func _roll_residence_footprint(residence_type: String) -> Vector2i:
	var residence_def := RESIDENCE_TYPES.get(residence_type, RESIDENCE_TYPES["house"]) as Dictionary
	var radius_min := residence_def.get("radius_min", Vector2i(2, 2)) as Vector2i
	var radius_max := residence_def.get("radius_max", Vector2i(6, 5)) as Vector2i
	return Vector2i(
		_rng.randi_range(radius_min.x, radius_max.x),
		_rng.randi_range(radius_min.y, radius_max.y)
	)

## Mirrors the decor templates in DwarfHoldTileService: houses sleep one
## dwarf, dormitories fill alternating cells with bunks, barracks lay bed
## rows every third rank.
func _estimate_residence_beds(residence_type: String, footprint: Vector2i) -> int:
	match residence_type:
		"dormitory":
			return maxi(2, footprint.x * footprint.y)
		"barracks":
			return maxi(2, footprint.x * (((footprint.y * 2 - 1) / 3) + 1))
		_:
			return 1

func _target_npcs_for_level(level_index: int, level_count: int) -> int:
	return _hold_state.target_npcs_for_level(level_index, level_count)

func _pick_civic_building_type() -> String:
	return DwarfHoldLayoutService.pick_civic_building_type(_rng, CIVIC_BUILDING_TYPES)

func _roll_civic_footprint(civic_definition: Dictionary) -> Vector2i:
	return DwarfHoldLayoutService.roll_civic_footprint(_rng, civic_definition)

func _civic_prefers_hall_arteries(civic_definition: Dictionary) -> bool:
	return DwarfHoldLayoutService.civic_prefers_hall_arteries(civic_definition)

func _dig_branching_hall_between_plazas(grid: Dictionary, from_plaza: Dictionary, to_plaza: Dictionary) -> void:
	var from_center := from_plaza.get("center", Vector2i.ZERO) as Vector2i
	var to_center := to_plaza.get("center", Vector2i.ZERO) as Vector2i
	if from_center == to_center:
		return
	var from_radius := from_plaza.get("radius", Vector2i(6, 5)) as Vector2i
	var to_radius := to_plaza.get("radius", Vector2i(6, 5)) as Vector2i
	var corridor_width := _rng.randi_range(3, 5)
	var from_exit := _plaza_edge_cell_facing(from_center, from_radius, to_center)
	var to_exit := _plaza_edge_cell_facing(to_center, to_radius, from_center)
	_dig_wide_hall_path(grid, from_exit, to_exit, corridor_width)

func _roll_plaza_shape() -> String:
	return "rect" if _rng.randf() < 0.5 else "ellipse"

func _dig_plaza_zone(grid: Dictionary, center: Vector2i, radius: Vector2i, shape: String, tile: int) -> void:
	if shape == "rect":
		_dig_rect(grid, center - radius, center + radius, tile)
		return
	_dig_ellipse(grid, center, radius, tile)


func _plaza_clearance_radius(radius: Vector2i) -> float:
	return float(maxi(radius.x, radius.y))

func _is_plaza_too_close(candidate_center: Vector2i, candidate_radius: Vector2i, plaza_layouts: Array[Dictionary], min_gap: int) -> bool:
	var candidate_clearance := _plaza_clearance_radius(candidate_radius)
	for plaza_data_variant: Variant in plaza_layouts:
		var plaza_data := plaza_data_variant as Dictionary
		var existing_center := plaza_data.get("center", Vector2i.ZERO) as Vector2i
		var existing_radius := plaza_data.get("radius", Vector2i(6, 5)) as Vector2i
		var minimum_distance := candidate_clearance + _plaza_clearance_radius(existing_radius) + float(min_gap)
		if candidate_center.distance_to(existing_center) < minimum_distance:
			return true
	return false

func _plaza_edge_cell_facing(plaza_center: Vector2i, plaza_radius: Vector2i, target: Vector2i) -> Vector2i:
	var axis_direction := _major_axis_direction_toward_target(plaza_center, target)
	if axis_direction == Vector2i.LEFT:
		return Vector2i(plaza_center.x - plaza_radius.x, plaza_center.y + _rng.randi_range(-1, 1))
	if axis_direction == Vector2i.RIGHT:
		return Vector2i(plaza_center.x + plaza_radius.x, plaza_center.y + _rng.randi_range(-1, 1))
	if axis_direction == Vector2i.UP:
		return Vector2i(plaza_center.x + _rng.randi_range(-1, 1), plaza_center.y - plaza_radius.y)
	return Vector2i(plaza_center.x + _rng.randi_range(-1, 1), plaza_center.y + plaza_radius.y)

func _dig_wide_hall_path(grid: Dictionary, start: Vector2i, finish: Vector2i, width: int) -> void:
	var half_width := maxi(1, width / 2)
	var corner := Vector2i(finish.x, start.y)
	_dig_wide_hall_segment(grid, start, corner, half_width)
	_dig_wide_hall_segment(grid, corner, finish, half_width)

func _dig_wide_hall_segment(grid: Dictionary, from_cell: Vector2i, to_cell: Vector2i, half_width: int) -> void:
	var segment_from := Vector2i(mini(from_cell.x, to_cell.x), mini(from_cell.y, to_cell.y))
	var segment_to := Vector2i(maxi(from_cell.x, to_cell.x), maxi(from_cell.y, to_cell.y))
	if segment_from.x == segment_to.x:
		segment_from.x -= half_width
		segment_to.x += half_width
	else:
		segment_from.y -= half_width
		segment_to.y += half_width
	_dig_rect(grid, segment_from, segment_to, CELL_HALL)

func _place_structure_zone(
	grid: Dictionary,
	hubs: Array[Vector2i],
	structure_tile: int,
	offset_generator: Callable,
	size_generator: Callable,
	building_type: String = ""
) -> bool:
	var max_search_rings := 16
	for ring in range(max_search_rings):
		var expansion := ring * 4
		var attempts := 48
		for _attempt in attempts:
			var anchor := hubs[_rng.randi_range(0, hubs.size() - 1)]
			var offset := offset_generator.call() as Vector2i
			var center := anchor + offset
			if ring > 0:
				center += Vector2i(_rng.randi_range(-expansion, expansion), _rng.randi_range(-expansion, expansion))
			var footprint := size_generator.call() as Vector2i
			if _try_place_structure_with_single_door(grid, center, footprint, structure_tile, anchor):
				_register_building_type_metadata(center, footprint, structure_tile, building_type)
				return true

	var fallback_anchor := hubs[_rng.randi_range(0, hubs.size() - 1)]
	var fallback_footprint := size_generator.call() as Vector2i
	return _place_structure_in_open_space(grid, structure_tile, fallback_anchor, fallback_footprint, building_type)

func _place_structure_along_halls(grid: Dictionary, structure_tile: int, footprint: Vector2i, building_type: String = "") -> bool:
	var hall_edge_candidates := _collect_hall_edge_candidates(grid)
	if hall_edge_candidates.is_empty():
		return false
	for _attempt in 140:
		var candidate: Dictionary = hall_edge_candidates[_rng.randi_range(0, hall_edge_candidates.size() - 1)]
		var hall_cell := candidate["hall"] as Vector2i
		var side_dir := candidate["side"] as Vector2i
		var structural_radius := footprint.x if side_dir.x != 0 else footprint.y
		var standoff := structural_radius + _rng.randi_range(1, 3)
		var center := hall_cell + side_dir * standoff
		if not _can_place_structure(grid, center, footprint):
			continue
		_dig_structure_with_room(grid, center, footprint, structure_tile)
		_register_building_type_metadata(center, footprint, structure_tile, building_type)
		var doorway := _pick_side_center_door_cell_facing(center, footprint, -side_dir)
		var exterior := doorway + _outward_direction_for_door(center, footprint, doorway)
		_connect_points(grid, exterior, hall_cell, CELL_HALL)
		return true
	return false

func _collect_hall_edge_candidates(grid: Dictionary) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for key: Variant in grid.keys():
		var hall_cell := key as Vector2i
		if _cell_at(grid, hall_cell.x, hall_cell.y) != CELL_HALL:
			continue
		for side_dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var side_cell := hall_cell + side_dir
			if _cell_at(grid, side_cell.x, side_cell.y) != CELL_ROCK:
				continue
			candidates.append({"hall": hall_cell, "side": side_dir})
	return candidates

func _place_structure_in_open_space(grid: Dictionary, structure_tile: int, anchor: Vector2i, footprint: Vector2i, building_type: String = "") -> bool:
	var start_radius := maxi(footprint.x, footprint.y) + 8
	var max_radius := start_radius + maxi(structure_fallback_max_extra_radius, 0)
	for radius in range(start_radius, max_radius + 1, 8):
		var candidate_centers := [
			Vector2i(anchor.x + radius, anchor.y),
			Vector2i(anchor.x - radius, anchor.y),
			Vector2i(anchor.x, anchor.y + radius),
			Vector2i(anchor.x, anchor.y - radius),
			Vector2i(anchor.x + radius, anchor.y + radius),
			Vector2i(anchor.x - radius, anchor.y + radius),
			Vector2i(anchor.x + radius, anchor.y - radius),
			Vector2i(anchor.x - radius, anchor.y - radius)
		]
		for center: Vector2i in candidate_centers:
			if _try_place_structure_with_single_door(grid, center, footprint, structure_tile, anchor):
				_register_building_type_metadata(center, footprint, structure_tile, building_type)
				return true
	return false


func _register_building_type_metadata(center: Vector2i, footprint: Vector2i, structure_tile: int, building_type: String) -> void:
	if building_type.is_empty():
		return
	if structure_tile != CELL_BUILDING and structure_tile != CELL_HOUSE:
		return
	var target_map := _latest_civic_building_type_map if structure_tile == CELL_BUILDING else _latest_residence_type_map
	for y in range(center.y - footprint.y, center.y + footprint.y + 1):
		for x in range(center.x - footprint.x, center.x + footprint.x + 1):
			target_map[Vector2i(x, y)] = building_type

func _compute_civic_buildings_by_id(grid: Dictionary) -> Dictionary:
	var visited: Dictionary = {}
	var by_id: Dictionary = {}
	for key: Variant in grid.keys():
		var start_cell := key as Vector2i
		if visited.has(start_cell):
			continue
		if _cell_at(grid, start_cell.x, start_cell.y) != CELL_BUILDING:
			continue
		var queue: Array[Vector2i] = [start_cell]
		visited[start_cell] = true
		var component: Array[Vector2i] = []
		var head := 0
		while head < queue.size():
			var current: Vector2i = queue[head]
			head += 1
			component.append(current)
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor := current + direction
				if visited.has(neighbor):
					continue
				if _cell_at(grid, neighbor.x, neighbor.y) != CELL_BUILDING:
					continue
				visited[neighbor] = true
				queue.append(neighbor)
		if component.is_empty():
			continue
		var anchor := _stable_component_anchor(component)
		var building_id := "%d:%d" % [anchor.x, anchor.y]
		var building_type := String(_latest_civic_building_type_map.get(anchor, "workshop"))
		by_id[building_id] = {"anchor": anchor, "type": building_type, "cells": component}
	return by_id

func _stable_component_anchor(component: Array[Vector2i]) -> Vector2i:
	var anchor := component[0]
	for cell: Vector2i in component:
		if cell.x < anchor.x or (cell.x == anchor.x and cell.y < anchor.y):
			anchor = cell
	return anchor

func _build_civic_building_type_lookup(buildings_by_id: Dictionary) -> Dictionary:
	var lookup: Dictionary = {}
	for building_id: String in buildings_by_id.keys():
		var payload := buildings_by_id[building_id] as Dictionary
		var building_type := String(payload.get("type", "workshop"))
		var cells := payload.get("cells", []) as Array
		for cell_variant: Variant in cells:
			lookup[cell_variant as Vector2i] = building_type
	return lookup

func _count_zone_components(grid: Dictionary) -> Dictionary:
	return {
		"halls": _count_components_for_tile(grid, CELL_HALL),
		"houses": _count_components_for_tile(grid, CELL_HOUSE),
		"buildings": _count_components_for_tile(grid, CELL_BUILDING),
		"plazas": _count_components_for_tile(grid, CELL_PLAZA)
	}

func _count_components_for_tile(grid: Dictionary, tile_type: int) -> int:
	var visited: Dictionary = {}
	var component_count := 0
	for key: Variant in grid.keys():
		var start_cell := key as Vector2i
		if visited.has(start_cell):
			continue
		if _cell_at(grid, start_cell.x, start_cell.y) != tile_type:
			continue

		component_count += 1
		var queue: Array[Vector2i] = [start_cell]
		visited[start_cell] = true
		var head := 0
		while head < queue.size():
			var current: Vector2i = queue[head]
			head += 1
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor := current + direction
				if visited.has(neighbor):
					continue
				if _cell_at(grid, neighbor.x, neighbor.y) != tile_type:
					continue
				visited[neighbor] = true
				queue.append(neighbor)

	return component_count

func _on_overlay_toggle_toggled(toggled_on: bool) -> void:
	_show_zone_overlay = toggled_on
	_update_zone_overlay()

func _on_lighting_toggle_toggled(toggled_on: bool) -> void:
	_lighting_enabled = toggled_on
	_apply_lighting_state()
	if not _latest_grid.is_empty():
		_refresh_lighting(_latest_grid)

func _apply_lighting_state() -> void:
	# The layer stays visible: it carries the player lantern glow and
	# placed torches. The toggle gates only the fog-of-war mask.
	lighting_layer.visible = true
	if _lighting_mask_sprite != null:
		_lighting_mask_sprite.visible = _lighting_enabled

func _update_zone_overlay() -> void:
	if zone_overlay.has_method("set_overlay_state"):
		zone_overlay.call("set_overlay_state", _latest_grid, tile_size, _zoom_level, city_layer.position, ZONE_OVERLAY_COLORS, _show_zone_overlay)

func _dig_structure_with_room(grid: Dictionary, center: Vector2i, footprint: Vector2i, structure_tile: int) -> void:
	var from_cell := center - footprint
	var to_cell := center + footprint
	_dig_rect(grid, from_cell, to_cell, structure_tile)

func _try_place_structure_with_single_door(grid: Dictionary, center: Vector2i, footprint: Vector2i, structure_tile: int, anchor: Vector2i) -> bool:
	if not _can_place_structure(grid, center, footprint):
		return false
	_dig_structure_with_room(grid, center, footprint, structure_tile)
	var outward_dir := _major_axis_direction_toward_target(center, anchor)
	var doorway := _pick_side_center_door_cell_facing(center, footprint, outward_dir)
	var exterior := doorway + _outward_direction_for_door(center, footprint, doorway)
	_connect_points(grid, exterior, anchor, CELL_HALL)
	return true

func _can_place_structure(grid: Dictionary, center: Vector2i, footprint: Vector2i) -> bool:
	var from_cell := center - footprint
	var to_cell := center + footprint
	for y in range(from_cell.y - 1, to_cell.y + 2):
		for x in range(from_cell.x - 1, to_cell.x + 2):
			var tile := _cell_at(grid, x, y)
			if tile == CELL_HOUSE or tile == CELL_BUILDING:
				return false
			if (x == from_cell.x - 1 or x == to_cell.x + 1 or y == from_cell.y - 1 or y == to_cell.y + 1) and _is_corridor_cell(tile):
				return false
	return true

func _pick_structure_door_cell(center: Vector2i, footprint: Vector2i) -> Vector2i:
	var from_cell := center - footprint
	var to_cell := center + footprint
	var side := _rng.randi_range(0, 3)
	match side:
		0:
			var top_x := center.x if from_cell.x + 1 > to_cell.x - 1 else _rng.randi_range(from_cell.x + 1, to_cell.x - 1)
			return Vector2i(top_x, from_cell.y)
		1:
			var bottom_x := center.x if from_cell.x + 1 > to_cell.x - 1 else _rng.randi_range(from_cell.x + 1, to_cell.x - 1)
			return Vector2i(bottom_x, to_cell.y)
		2:
			var left_y := center.y if from_cell.y + 1 > to_cell.y - 1 else _rng.randi_range(from_cell.y + 1, to_cell.y - 1)
			return Vector2i(from_cell.x, left_y)
		_:
			var right_y := center.y if from_cell.y + 1 > to_cell.y - 1 else _rng.randi_range(from_cell.y + 1, to_cell.y - 1)
			return Vector2i(to_cell.x, right_y)

func _pick_side_center_door_cell_facing(center: Vector2i, footprint: Vector2i, outward_dir: Vector2i) -> Vector2i:
	var from_cell := center - footprint
	var to_cell := center + footprint
	if outward_dir == Vector2i.UP:
		return Vector2i(center.x, from_cell.y)
	if outward_dir == Vector2i.DOWN:
		return Vector2i(center.x, to_cell.y)
	if outward_dir == Vector2i.LEFT:
		return Vector2i(from_cell.x, center.y)
	return Vector2i(to_cell.x, center.y)

func _major_axis_direction_toward_target(origin: Vector2i, target: Vector2i) -> Vector2i:
	var delta := target - origin
	if abs(delta.x) >= abs(delta.y):
		return Vector2i.RIGHT if delta.x >= 0 else Vector2i.LEFT
	return Vector2i.DOWN if delta.y >= 0 else Vector2i.UP

func _outward_direction_for_door(center: Vector2i, footprint: Vector2i, door: Vector2i) -> Vector2i:
	var from_cell := center - footprint
	var to_cell := center + footprint
	if door.y == from_cell.y:
		return Vector2i.UP
	if door.y == to_cell.y:
		return Vector2i.DOWN
	if door.x == from_cell.x:
		return Vector2i.LEFT
	return Vector2i.RIGHT

func _compute_single_doors(grid: Dictionary) -> Dictionary:
	var visited: Dictionary = {}
	var chosen_doors: Dictionary = {}

	for key: Variant in grid.keys():
		var start_cell := key as Vector2i
		var tile := _cell_at(grid, start_cell.x, start_cell.y)
		if tile != CELL_HOUSE and tile != CELL_BUILDING:
			continue
		if visited.has(start_cell):
			continue

		var queue: Array[Vector2i] = [start_cell]
		visited[start_cell] = true
		var component_cells: Array[Vector2i] = []
		var head := 0
		while head < queue.size():
			var current: Vector2i = queue[head]
			head += 1
			component_cells.append(current)
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor: Vector2i = current + direction
				if visited.has(neighbor):
					continue
				if _cell_at(grid, neighbor.x, neighbor.y) != tile:
					continue
				visited[neighbor] = true
				queue.append(neighbor)

		var component_lookup: Dictionary = {}
		for component_cell: Vector2i in component_cells:
			component_lookup[component_cell] = true

		var candidates: Array[Vector2i] = []
		for component_cell: Vector2i in component_cells:
			if _is_component_corner_cell(component_cell, component_lookup):
				continue
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var corridor_neighbor := component_cell + direction
				if _is_corridor_cell(_cell_at(grid, corridor_neighbor.x, corridor_neighbor.y)):
					candidates.append(component_cell)
					break

		if candidates.is_empty():
			continue
		var selected := candidates[_rng.randi_range(0, candidates.size() - 1)] as Vector2i
		chosen_doors[selected] = true

	return chosen_doors

func _ensure_door_connectivity(grid: Dictionary, door_cells_by_level: Dictionary) -> void:
	if door_cells_by_level.is_empty():
		return

	var connected_doors: Dictionary = {}
	var door_cells: Array[Vector2i] = []
	for door_variant: Variant in door_cells_by_level.keys():
		var door_cell := door_variant as Vector2i
		door_cells.append(door_cell)

	var root_door := door_cells[0]
	connected_doors[root_door] = true
	var reachable := _collect_walkable_reachable_cells(grid, root_door)

	for _iteration in range(door_cells.size() * 4):
		var disconnected_door := Vector2i(2147483647, 2147483647)
		for door_cell: Vector2i in door_cells:
			if reachable.has(door_cell):
				connected_doors[door_cell] = true
				continue
			disconnected_door = door_cell
			break

		if disconnected_door.x == 2147483647:
			break

		var closest_connected := root_door
		var closest_distance := disconnected_door.distance_squared_to(root_door)
		for connected_variant: Variant in connected_doors.keys():
			var connected_door := connected_variant as Vector2i
			var candidate_distance := disconnected_door.distance_squared_to(connected_door)
			if candidate_distance < closest_distance:
				closest_connected = connected_door
				closest_distance = candidate_distance

		_connect_points(grid, closest_connected, disconnected_door, CELL_HALL)
		reachable = _collect_walkable_reachable_cells(grid, root_door)

func _collect_walkable_reachable_cells(grid: Dictionary, start_cell: Vector2i) -> Dictionary:
	var reachable: Dictionary = {}
	if not grid.has(start_cell):
		return reachable
	if not _is_walkable_zone(_cell_at(grid, start_cell.x, start_cell.y)):
		return reachable

	var queue: Array[Vector2i] = [start_cell]
	reachable[start_cell] = true
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor := current + direction
			if reachable.has(neighbor):
				continue
			if not grid.has(neighbor):
				continue
			if not _is_walkable_zone(_cell_at(grid, neighbor.x, neighbor.y)):
				continue
			reachable[neighbor] = true
			queue.append(neighbor)

	return reachable

func _ensure_walkable_connectivity(grid: Dictionary) -> void:
	var components := _collect_walkable_components(grid)
	if components.size() <= 1:
		return

	var largest_component_index := 0
	var largest_component_size := 0
	for i in range(components.size()):
		var component := components[i] as Array[Vector2i]
		if component.size() > largest_component_size:
			largest_component_size = component.size()
			largest_component_index = i

	var connected_cells: Array[Vector2i] = []
	connected_cells.assign(components[largest_component_index])

	for i in range(components.size()):
		if i == largest_component_index:
			continue
		var component := components[i] as Array[Vector2i]
		if component.is_empty() or connected_cells.is_empty():
			continue

		var nearest_pair := _find_nearest_cell_pair(connected_cells, component)
		if nearest_pair.is_empty():
			continue

		_connect_points(grid, nearest_pair[0] as Vector2i, nearest_pair[1] as Vector2i, CELL_HALL)
		connected_cells.append_array(component)

func _collect_walkable_components(grid: Dictionary) -> Array[Array]:
	var components: Array[Array] = []
	var visited: Dictionary = {}

	for cell_variant: Variant in grid.keys():
		var origin := cell_variant as Vector2i
		if visited.has(origin):
			continue
		if not _is_walkable_zone(_cell_at(grid, origin.x, origin.y)):
			continue

		var queue: Array[Vector2i] = [origin]
		var component: Array[Vector2i] = []
		visited[origin] = true

		var head := 0
		while head < queue.size():
			var current: Vector2i = queue[head]
			head += 1
			component.append(current)
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor := current + direction
				if visited.has(neighbor):
					continue
				if not grid.has(neighbor):
					continue
				if not _is_walkable_zone(_cell_at(grid, neighbor.x, neighbor.y)):
					continue
				visited[neighbor] = true
				queue.append(neighbor)

		if not component.is_empty():
			components.append(component)

	return components

func _find_nearest_cell_pair(group_a: Array[Vector2i], group_b: Array[Vector2i]) -> Array[Vector2i]:
	if group_a.is_empty() or group_b.is_empty():
		return []

	var nearest_a := group_a[0]
	var nearest_b := group_b[0]
	var best_distance := nearest_a.distance_squared_to(nearest_b)

	for cell_a: Vector2i in group_a:
		for cell_b: Vector2i in group_b:
			var candidate_distance := cell_a.distance_squared_to(cell_b)
			if candidate_distance < best_distance:
				best_distance = candidate_distance
				nearest_a = cell_a
				nearest_b = cell_b

	return [nearest_a, nearest_b]

func _is_walkable_zone(cell: int) -> bool:
	return cell == CELL_HALL or cell == CELL_HOUSE or cell == CELL_BUILDING or cell == CELL_PLAZA

func _is_component_corner_cell(cell: Vector2i, component_lookup: Dictionary) -> bool:
	var has_left := component_lookup.has(cell + Vector2i.LEFT)
	var has_right := component_lookup.has(cell + Vector2i.RIGHT)
	var has_up := component_lookup.has(cell + Vector2i.UP)
	var has_down := component_lookup.has(cell + Vector2i.DOWN)
	if (not has_left and not has_up) or (not has_left and not has_down):
		return true
	if (not has_right and not has_up) or (not has_right and not has_down):
		return true
	return false

func _dig_rect(grid: Dictionary, from_cell: Vector2i, to_cell: Vector2i, tile: int) -> void:
	for y in range(from_cell.y, to_cell.y + 1):
		for x in range(from_cell.x, to_cell.x + 1):
			_set_cell(grid, Vector2i(x, y), tile)

func _dig_ellipse(grid: Dictionary, center: Vector2i, radius: Vector2i, tile: int) -> void:
	for y in range(center.y - radius.y, center.y + radius.y + 1):
		for x in range(center.x - radius.x, center.x + radius.x + 1):
			var normalized_x := float(x - center.x) / maxf(float(radius.x), 1.0)
			var normalized_y := float(y - center.y) / maxf(float(radius.y), 1.0)
			if normalized_x * normalized_x + normalized_y * normalized_y <= 1.0:
				_set_cell(grid, Vector2i(x, y), tile)

func _connect_points(grid: Dictionary, start: Vector2i, finish: Vector2i, tile: int) -> void:
	var corridor_width := _rng.randi_range(2, 5)
	var cursor := start
	while cursor.x != finish.x:
		_dig_corridor_at(grid, cursor, tile, true, corridor_width)
		cursor.x += 1 if finish.x > cursor.x else -1
	while cursor.y != finish.y:
		_dig_corridor_at(grid, cursor, tile, false, corridor_width)
		cursor.y += 1 if finish.y > cursor.y else -1
	_dig_corridor_at(grid, finish, tile, true, corridor_width)
	_dig_corridor_at(grid, finish, tile, false, corridor_width)

func _dig_corridor_at(grid: Dictionary, origin: Vector2i, tile: int, horizontal: bool, width: int) -> void:
	var start_offset := -int(width / 2)
	for i in width:
		var offset := start_offset + i
		if horizontal:
			_set_cell(grid, Vector2i(origin.x, origin.y + offset), tile)
		else:
			_set_cell(grid, Vector2i(origin.x + offset, origin.y), tile)

func _set_cell(grid: Dictionary, cell: Vector2i, tile: int) -> void:
	var existing := _cell_at(grid, cell.x, cell.y)
	if tile == CELL_HALL and existing == CELL_PLAZA:
		return
	if _is_corridor_cell(tile) and _is_structural_cell(existing):
		return
	grid[cell] = tile

func _cell_at(grid: Dictionary, x: int, y: int) -> int:
	return int(grid.get(Vector2i(x, y), CELL_ROCK))

func _is_structural_cell(cell: int) -> bool:
	return cell == CELL_HOUSE or cell == CELL_BUILDING

func _is_corridor_cell(cell: int) -> bool:
	return cell == CELL_HALL or cell == CELL_PLAZA

func _find_bounds(grid: Dictionary) -> Rect2i:
	if grid.is_empty():
		return Rect2i(Vector2i.ZERO, Vector2i.ONE)
	var min_x := 2147483647
	var min_y := 2147483647
	var max_x := -2147483648
	var max_y := -2147483648
	for key: Variant in grid.keys():
		var cell := key as Vector2i
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_x = maxi(max_x, cell.x)
		max_y = maxi(max_y, cell.y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _render_city(grid: Dictionary, stair_cells: Dictionary = {}) -> void:
	if city_layer.tile_set == null:
		return
	city_layer.clear()
	decor_layer.clear()
	var bounds := _find_bounds(grid).grow(1)
	var house_decor_overrides := _build_house_decor_layouts(grid)
	for floor_cell_variant: Variant in _latest_floor_decor.keys():
		if not house_decor_overrides.has(floor_cell_variant):
			house_decor_overrides[floor_cell_variant] = _latest_floor_decor[floor_cell_variant]
	_latest_bed_count = 0
	_bed_cells = []
	for decor_cell_variant: Variant in house_decor_overrides.keys():
		if String(house_decor_overrides[decor_cell_variant]) == "bed":
			_latest_bed_count += 1
			_bed_cells.append(decor_cell_variant as Vector2i)
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := _cell_at(grid, x, y)
			if cell == CELL_ROCK and not _is_hall_border_rock_cell(grid, x, y):
				continue
			var base_tile := _pick_base_tile(grid, x, y, cell)
			var render_cell := Vector2i(x, y)
			_place_tile(city_layer, render_cell, base_tile)
			var decor_tile := _pick_decor_tile(grid, x, y, cell, base_tile, house_decor_overrides)
			if not decor_tile.is_empty():
				_place_tile(decor_layer, render_cell, decor_tile)
				if decor_tile == "chest":
					_ensure_chest_inventory(render_cell)
	for stair_key: String in ["up", "down"]:
		if not stair_cells.has(stair_key):
			continue
		var stair_cell := stair_cells[stair_key] as Vector2i
		if city_layer.get_cell_source_id(stair_cell) < 0:
			continue
		_place_tile(city_layer, stair_cell, "stairway_up" if stair_key == "up" else "stairway_down")
		decor_layer.erase_cell(stair_cell)
	_rebuild_district_labels()
	_initialize_shattered_lighting(grid)
	_refresh_lighting(grid)
	_reset_view(bounds)

func _rebuild_district_labels() -> void:
	var existing := city_layer.get_node_or_null("DistrictLabels")
	if existing != null:
		existing.queue_free()
	if _latest_district_labels.is_empty():
		return
	var labels_root := Node2D.new()
	labels_root.name = "DistrictLabels"
	labels_root.z_index = 20
	city_layer.add_child(labels_root)
	for label_variant: Variant in _latest_district_labels:
		var entry := label_variant as Dictionary
		var text := String(entry.get("name", ""))
		if text.is_empty():
			continue
		var center := entry.get("center", Vector2i.ZERO) as Vector2i
		var label := Label.new()
		label.text = text.to_upper()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color(0.93, 0.88, 0.78, 0.95))
		label.add_theme_color_override("font_outline_color", Color(0.09, 0.08, 0.09, 0.9))
		label.add_theme_constant_override("outline_size", 6)
		var estimated_width := maxf(40.0, float(label.text.length()) * 14.0)
		label.position = city_layer.map_to_local(center) - Vector2(estimated_width * 0.5, float(tile_size.y) * 2.2)
		label.size = Vector2(estimated_width, 28.0)
		labels_root.add_child(label)

func _pick_level_stair_cells(grid: Dictionary, level_index: int, level_count: int) -> Dictionary:
	var result := {}
	if level_count <= 1:
		return result

	var requires_up_stair := level_index > 0
	var requires_down_stair := level_index < level_count - 1

	var up_cell := Vector2i(2147483647, 2147483647)
	if requires_up_stair:
		up_cell = _pick_required_stair_cell(grid)
		if up_cell.x != 2147483647:
			result["up"] = up_cell

	if requires_down_stair:
		var down_cell := _pick_required_stair_cell(grid)
		if down_cell == up_cell:
			down_cell = _pick_required_stair_cell(grid, up_cell)
		if down_cell.x != 2147483647:
			result["down"] = down_cell

	return result

func _pick_required_stair_cell(grid: Dictionary, excluded_cell: Vector2i = Vector2i(2147483647, 2147483647)) -> Vector2i:
	var stair_candidates := _stair_candidates_for_level(grid)
	if not stair_candidates.is_empty():
		var shuffled_candidates := stair_candidates.duplicate()
		_seeded_shuffle(shuffled_candidates)
		for candidate_variant: Variant in shuffled_candidates:
			var candidate := candidate_variant as Vector2i
			if candidate != excluded_cell:
				return candidate

	var walkable_cells := _collect_walkable_cells(grid)
	if not walkable_cells.is_empty():
		var shuffled_walkable := walkable_cells.duplicate()
		_seeded_shuffle(shuffled_walkable)
		for walkable_variant: Variant in shuffled_walkable:
			var walkable_cell := walkable_variant as Vector2i
			if walkable_cell != excluded_cell:
				return walkable_cell

	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var forced_cell: Vector2i = excluded_cell + offset
		if forced_cell == excluded_cell:
			continue
		if not grid.has(forced_cell):
			continue
		grid[forced_cell] = CELL_HALL
		return forced_cell

	for key_variant: Variant in grid.keys():
		var grid_cell := key_variant as Vector2i
		if grid_cell == excluded_cell:
			continue
		grid[grid_cell] = CELL_HALL
		return grid_cell

	return Vector2i(2147483647, 2147483647)

func _stair_candidates_for_level(grid: Dictionary) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for key: Variant in grid.keys():
		var cell := key as Vector2i
		var zone := int(grid[key])
		if zone == CELL_HALL or zone == CELL_PLAZA:
			candidates.append(cell)
	if candidates.is_empty():
		candidates = _collect_walkable_cells(grid)
	return candidates


func _initialize_shattered_lighting(grid: Dictionary) -> void:
	if grid.is_empty():
		_lighting_bounds = Rect2i(Vector2i.ZERO, Vector2i.ONE)
		_revealed_cells.clear()
		_visible_cells.clear()
		if _lighting_mask_sprite != null:
			_lighting_mask_sprite.visible = false
		return

	_lighting_bounds = _find_bounds(grid).grow(1)
	var image_size := Vector2i(
		maxi(_lighting_bounds.size.x * tile_size.x, 1),
		maxi(_lighting_bounds.size.y * tile_size.y, 1)
	)
	_lighting_mask_image = Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	_lighting_mask_image.fill(Color(0, 0, 0, SHATTERED_UNSEEN_ALPHA))
	_lighting_mask_texture = ImageTexture.create_from_image(_lighting_mask_image)
	if _lighting_mask_sprite != null:
		_lighting_mask_sprite.texture = _lighting_mask_texture
		_lighting_mask_sprite.position = Vector2(_lighting_bounds.position * tile_size)
		_lighting_mask_sprite.visible = _lighting_enabled
	_revealed_cells.clear()
	_visible_cells.clear()
	_update_shattered_visibility(grid)

func _refresh_lighting(grid: Dictionary) -> void:
	if _lighting_mask_sprite == null:
		return
	if not _lighting_enabled or grid.is_empty() or _lighting_mask_image == null or _lighting_mask_texture == null:
		_lighting_mask_sprite.visible = false
		return

	_lighting_mask_sprite.visible = true
	_lighting_mask_sprite.position = Vector2(_lighting_bounds.position * tile_size)
	for cell_variant: Variant in grid.keys():
		var cell := cell_variant as Vector2i
		var alpha := SHATTERED_UNSEEN_ALPHA
		if _visible_cells.has(cell):
			alpha = SHATTERED_VISIBLE_ALPHA
		elif _revealed_cells.has(cell):
			alpha = SHATTERED_REVEALED_ALPHA
		_draw_lighting_alpha_for_cell(cell, alpha)

	_lighting_mask_texture.update(_lighting_mask_image)

func _draw_lighting_alpha_for_cell(cell: Vector2i, alpha: float) -> void:
	if _lighting_mask_image == null:
		return
	var local_cell := cell - _lighting_bounds.position
	if local_cell.x < 0 or local_cell.y < 0 or local_cell.x >= _lighting_bounds.size.x or local_cell.y >= _lighting_bounds.size.y:
		return
	var pixel_origin := Vector2i(local_cell.x * tile_size.x, local_cell.y * tile_size.y)
	_lighting_mask_image.fill_rect(Rect2i(pixel_origin, tile_size), Color(0, 0, 0, clampf(alpha, 0.0, 1.0)))

func _update_shattered_visibility(grid: Dictionary) -> void:
	_visible_cells.clear()
	if grid.is_empty() or _player_sprite == null:
		return

	for dy in range(-SHATTERED_VISION_RADIUS, SHATTERED_VISION_RADIUS + 1):
		for dx in range(-SHATTERED_VISION_RADIUS, SHATTERED_VISION_RADIUS + 1):
			var cell := _player_cell + Vector2i(dx, dy)
			if not grid.has(cell):
				continue
			if Vector2(dx, dy).length() > SHATTERED_VISION_RADIUS + 0.25:
				continue
			if not _has_line_of_sight_to_cell(_player_cell, cell):
				continue
			_visible_cells[cell] = true
			_revealed_cells[cell] = true

func _has_line_of_sight_to_cell(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	return DwarfHoldLightingService.has_line_of_sight_to_cell(
		from_cell,
		to_cell,
		Callable(self, "_is_transparent_lighting_cell")
	)

func _is_transparent_lighting_cell(cell: Vector2i) -> bool:
	if city_layer.get_cell_source_id(cell) < 0:
		return false
	return _is_passable_atlas_tile(city_layer.get_cell_atlas_coords(cell))

func _ensure_chest_inventory(cell: Vector2i) -> void:
	DwarfHoldChestService.ensure_chest_inventory(_chest_inventories, cell, _rng, CHEST_LOOT_TABLE)

func _cell_from_mouse_position(mouse_position: Vector2) -> Vector2i:
	var local_position := (mouse_position - city_layer.position) / _zoom_level
	return city_layer.local_to_map(local_position)

func _is_chest_cell(cell: Vector2i) -> bool:
	if decor_layer.get_cell_source_id(cell) < 0:
		return false
	return decor_layer.get_cell_atlas_coords(cell) == TILE_ATLAS["chest"]

func _handle_chest_click(mouse_position: Vector2) -> void:
	var clicked_cell := _cell_from_mouse_position(mouse_position)
	if not _is_chest_cell(clicked_cell):
		_clear_chest_selection()
		return
	_end_trade_mode()
	_selected_chest_cell = clicked_cell
	_update_chest_inventory_panel()

func _update_chest_inventory_panel() -> void:
	if _selected_chest_cell.x == 2147483647:
		_clear_chest_selection()
		return
	var loot_entries := _chest_inventories.get(_selected_chest_cell, []) as Array
	chest_popup.visible = true
	chest_popup_title.text = "Chest (%d, %d)" % [_selected_chest_cell.x, _selected_chest_cell.y]
	var section_label := chest_popup.find_child("ChestSectionLabel", true, false) as Label
	if section_label != null:
		section_label.text = "Chest Storage"
	_populate_chest_slots(loot_entries)
	if loot_entries.is_empty():
		chest_popup_status_label.text = "This chest is empty."
		chest_popup_take_all_button.disabled = true
		return
	chest_popup_status_label.text = "Click another chest tile to inspect a different chest."
	chest_popup_take_all_button.disabled = false

func _clear_chest_selection() -> void:
	_end_trade_mode()
	_selected_chest_cell = Vector2i(2147483647, 2147483647)
	chest_popup_title.text = "Chest"
	chest_popup_status_label.text = "Select a chest tile to view contents"
	chest_popup_take_all_button.disabled = true
	_populate_chest_slots([])
	chest_popup.visible = false

func _on_loot_chest_button_pressed() -> void:
	if _selected_chest_cell.x == 2147483647:
		return
	for entry_variant: Variant in (_chest_inventories.get(_selected_chest_cell, []) as Array):
		var entry := entry_variant as Dictionary
		_add_to_inventory(String(entry.get("name", "Supplies")), int(entry.get("quantity", 1)))
	_chest_inventories[_selected_chest_cell] = []
	_update_chest_inventory_panel()

func _on_chest_popup_close_button_pressed() -> void:
	_clear_chest_selection()

func _initialize_chest_popup_grids() -> void:
	_create_inventory_slots(chest_grid, CHEST_SLOT_COLUMNS * CHEST_SLOT_ROWS, _chest_slot_panels, _chest_slot_labels, _chest_slot_icons)
	_create_inventory_slots(backpack_grid, CHEST_SLOT_COLUMNS * BACKPACK_SLOT_ROWS, _backpack_slot_panels, _backpack_slot_labels, _backpack_slot_icons)

func _create_inventory_slots(target_grid: GridContainer, slot_count: int, out_panels: Array[PanelContainer], out_labels: Array[Label], out_icons: Array[TextureRect]) -> void:
	for child in target_grid.get_children():
		child.queue_free()
	out_panels.clear()
	out_labels.clear()
	out_icons.clear()
	for _slot in slot_count:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(36, 36)
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.68, 0.56, 0.44, 1.0) if target_grid == chest_grid else Color(0.76, 0.80, 0.78, 1.0)
		slot_style.border_width_left = 2
		slot_style.border_width_top = 2
		slot_style.border_width_right = 2
		slot_style.border_width_bottom = 2
		slot_style.border_color = Color(0.34, 0.22, 0.12, 1.0) if target_grid == chest_grid else Color(0.52, 0.56, 0.54, 1.0)
		panel.add_theme_stylebox_override("panel", slot_style)
		var icon_rect := TextureRect.new()
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.add_child(icon_rect)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.05, 0.9))
		label.add_theme_constant_override("outline_size", 3)
		label.text = ""
		panel.add_child(label)
		if target_grid == backpack_grid:
			# Backpack slots are clickable (eat food, or sell while trading).
			# out_panels.size() is this slot's index; panels are freed and
			# rebuilt together, so the connection never stacks.
			panel.gui_input.connect(_on_backpack_slot_gui_input.bind(out_panels.size()))
		elif target_grid == chest_grid:
			# Chest slots buy wares while a shop trade is open.
			panel.gui_input.connect(_on_chest_slot_gui_input.bind(out_panels.size()))
		target_grid.add_child(panel)
		out_panels.append(panel)
		out_labels.append(label)
		out_icons.append(icon_rect)

## Fills one slot with an item: icon + count when the catalog knows the
## item, the old abbreviation text otherwise.
func _fill_inventory_slot(slot_index: int, panels: Array[PanelContainer], labels: Array[Label], icons: Array[TextureRect], item_name: String, quantity: int) -> void:
	if ItemDefsService.has_icon(item_name):
		icons[slot_index].texture = ItemDefsService.icon_texture(item_name)
		labels[slot_index].text = "×%d" % quantity
		labels[slot_index].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		labels[slot_index].vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	else:
		labels[slot_index].text = "%s\n%d" % [_item_abbreviation(item_name), quantity]
		labels[slot_index].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		labels[slot_index].vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panels[slot_index].tooltip_text = ItemDefsService.slot_tooltip(item_name, quantity)

func _clear_inventory_slots(panels: Array[PanelContainer], labels: Array[Label], icons: Array[TextureRect]) -> void:
	for i in range(labels.size()):
		labels[i].text = ""
		panels[i].tooltip_text = ""
		icons[i].texture = null

func _populate_chest_slots(loot_entries: Array) -> void:
	_clear_inventory_slots(_chest_slot_panels, _chest_slot_labels, _chest_slot_icons)
	for i in range(mini(loot_entries.size(), _chest_slot_labels.size())):
		var entry := loot_entries[i] as Dictionary
		_fill_inventory_slot(i, _chest_slot_panels, _chest_slot_labels, _chest_slot_icons, String(entry.get("name", "Supplies")), int(entry.get("quantity", 1)))

## The backpack grid mirrors the player's persistent inventory.
func _populate_backpack_slots() -> void:
	if _backpack_slot_labels.is_empty():
		return
	_clear_inventory_slots(_backpack_slot_panels, _backpack_slot_labels, _backpack_slot_icons)
	_backpack_slot_items.clear()
	var item_names := _player_inventory.keys()
	item_names.sort()
	for i in range(mini(item_names.size(), _backpack_slot_labels.size())):
		var item_name := String(item_names[i])
		_backpack_slot_items.append(item_name)
		_fill_inventory_slot(i, _backpack_slot_panels, _backpack_slot_labels, _backpack_slot_icons, item_name, int(_player_inventory[item_name]))
		if _is_trade_mode():
			_backpack_slot_panels[i].tooltip_text += "\nSell for %d coins" % SettlementEconomyService.sell_price(item_name)

## Clicking a backpack slot that holds something edible eats one of it.
func _on_backpack_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if slot_index < 0 or slot_index >= _backpack_slot_items.size():
		return
	var item_name := _backpack_slot_items[slot_index]
	if _is_trade_mode():
		_sell_item(item_name)
		return
	if not ItemDefsService.is_edible(item_name):
		return
	_eat_item(item_name)

func _item_abbreviation(item_name: String) -> String:
	return DwarfHoldChestService.item_abbreviation(item_name)

func _build_house_decor_layouts(grid: Dictionary) -> Dictionary:
	return DwarfHoldTileService.build_house_decor_layouts(grid, _latest_residence_type_map, _door_cells)

func _on_city_panel_gui_input(event: InputEvent) -> void:
	_is_panning = DwarfHoldUiInputHandler.handle_city_panel_event(
		event,
		Callable(self, "_handle_player_click_action"),
		Callable(self, "_apply_zoom"),
		Callable(self, "_update_hover_tooltip"),
		Callable(self, "_set_is_panning"),
		_is_panning,
		Callable(self, "_pan_city_view"),
		Callable(self, "_update_city_layer_transform")
	)

func _set_is_panning(value: bool) -> void:
	_is_panning = value

func _pan_city_view(delta: Vector2) -> void:
	_pan_offset += delta

func _apply_zoom(zoom_delta: float, focus_position: Vector2) -> void:
	var previous_zoom := _zoom_level
	_zoom_level = clampf(_zoom_level + zoom_delta, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(previous_zoom, _zoom_level):
		return
	var zoom_ratio := _zoom_level / previous_zoom
	_pan_offset = focus_position - ((focus_position - _pan_offset) * zoom_ratio)
	_update_city_layer_transform()

func _reset_view(bounds: Rect2i) -> void:
	var panel_size := city_panel.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		return
	var map_size := Vector2(bounds.size * tile_size)
	_map_origin_offset = -Vector2(bounds.position * tile_size)
	var fit_zoom := minf(
		panel_size.x / maxf(map_size.x + 32.0, 1.0),
		panel_size.y / maxf(map_size.y + 32.0, 1.0)
	)
	_zoom_level = clampf(fit_zoom, MIN_ZOOM, 1.0)
	var scaled_map_size := map_size * _zoom_level
	_pan_offset = (panel_size - scaled_map_size) * 0.5
	_update_city_layer_transform()

func _update_city_layer_transform() -> void:
	city_layer.scale = Vector2.ONE * _zoom_level
	city_layer.position = _pan_offset + (_map_origin_offset * _zoom_level)
	decor_layer.scale = city_layer.scale
	decor_layer.position = city_layer.position
	actor_layer.scale = city_layer.scale
	actor_layer.position = city_layer.position
	if tile_hover_tooltip.visible:
		tile_hover_tooltip.position = _clamp_tooltip_position(tile_hover_tooltip.position)
	lighting_layer.scale = city_layer.scale
	lighting_layer.position = city_layer.position
	_update_zone_overlay()

func _spawn_tavern_characters(grid: Dictionary) -> void:
	_player_sprite = null
	_player_control_enabled = true
	_player_move_path.clear()
	_player_is_moving = false
	_player_pending_chest_interaction = Vector2i(2147483647, 2147483647)
	var zone_walkable_cells := _collect_walkable_cells(grid)
	_walkable_cells = []
	for zone_cell in zone_walkable_cells:
		if _is_passable_cell_for_actor(zone_cell):
			_walkable_cells.append(zone_cell)
	# Resident count follows the hold's population at 10:1, split across
	# levels; the export count is only the floor for population-less holds.
	var level_npc_target := _target_npcs_for_level(
		_hold_state.current_level_index,
		maxi(_hold_state.generated_levels.size(), 1)
	)
	var npc_spawn_count := maxi(tavern_npc_count, mini(level_npc_target, 250))
	var result := DwarfHoldTavernService.spawn_tavern_characters(
		actor_layer, city_layer, _npc_states, _rng, _walkable_cells,
		_tavern_character_texture, _pending_player_spawn_cell,
		Callable(self, "_is_walkable_cell"),
		Callable(self, "_cell_center_position"),
		Callable(self, "_create_player_character_sprite"),
		Callable(self, "_actor_sprite_to_cell"),
		npc_spawn_count, tavern_npc_speed_range,
		_placeholder_actor_texture, tile_size
	)
	_player_sprite = result.get("player_sprite")
	_player_cell = result.get("player_cell", _player_cell)
	_pending_player_spawn_cell = Vector2i(2147483647, 2147483647)
	_relocate_player_to_city_heart(grid)
	_assign_npc_daily_lives(grid)
	_assign_npc_identities()
	_clear_torch_sprites()
	_clear_creatures()
	_end_fishing("")
	var shown_level := _hold_state.generated_levels[_hold_state.current_level_index] as Dictionary
	for torch_cell_variant: Variant in (shown_level.get("torches", []) as Array):
		_spawn_torch_at(torch_cell_variant as Vector2i)

## On the district city level the player arrives at the Great Hall, the
## one spot guaranteed to connect to every quarter, rather than a random
## alley pocket.
func _relocate_player_to_city_heart(grid: Dictionary) -> void:
	if _player_sprite == null or _latest_district_labels.is_empty():
		return
	var heart := Vector2i.ZERO
	for label_variant: Variant in _latest_district_labels:
		var entry := label_variant as Dictionary
		if String(entry.get("name", "")) == "Great Hall":
			heart = entry.get("center", Vector2i.ZERO) as Vector2i
			break
	for ring in range(0, 14):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var candidate := heart + Vector2i(dx, dy)
				if int(grid.get(candidate, CELL_ROCK)) != CELL_PLAZA and int(grid.get(candidate, CELL_ROCK)) != CELL_HALL:
					continue
				if not _is_walkable_cell(candidate):
					continue
				_player_cell = candidate
				_player_sprite.position = _cell_center_position(candidate)
				_center_view_on_cell(candidate)
				return
	if _player_sprite != null:
		_center_view_on_cell(_player_cell)
	_refresh_lighting(grid)

func _assign_npc_daily_lives(grid: Dictionary) -> void:
	if _npc_states.is_empty():
		return
	var building_cells_by_type: Dictionary = {}
	for building_cell_variant: Variant in _latest_civic_building_type_map.keys():
		var building_type := String(_latest_civic_building_type_map[building_cell_variant])
		if not building_cells_by_type.has(building_type):
			building_cells_by_type[building_type] = []
		(building_cells_by_type[building_type] as Array).append(building_cell_variant)
	var street_cells: Array[Vector2i] = []
	for grid_cell_variant: Variant in grid.keys():
		var zone := int(grid[grid_cell_variant])
		if zone != CELL_HALL and zone != CELL_PLAZA:
			continue
		var street_cell := grid_cell_variant as Vector2i
		if _is_walkable_cell(street_cell):
			street_cells.append(street_cell)
	var npc_count := _npc_states.size()
	SettlementNpcScheduler.assign_daily_lives(_npc_states, {
		"bed_cells": _bed_cells,
		"building_cells_by_type": building_cells_by_type,
		"street_cells": street_cells,
		"green_cells": [],
		"is_walkable": Callable(self, "_is_walkable_cell"),
		"rng": _rng,
		"guard_role": ROLE_WARRIOR,
		"green_role": -1,
		"role_workplaces": ROLE_WORKPLACES,
		"filler_roles": [ROLE_MINER, ROLE_DWARF_WOMAN],
		"role_quotas": [
			{"role": ROLE_WARRIOR, "count": maxi(2, npc_count / 12)},
			{"role": ROLE_SMITH, "count": mini(maxi(1, npc_count / 8), (building_cells_by_type.get("forge", []) as Array).size() + (building_cells_by_type.get("smeltery", []) as Array).size() * 2 + 1)},
			{"role": ROLE_BREWER, "count": mini(maxi(1, npc_count / 10), (building_cells_by_type.get("brewery", []) as Array).size() * 2 + (building_cells_by_type.get("tavern", []) as Array).size() + 1)},
			{"role": ROLE_RUNESCRIBE, "count": mini(maxi(1, npc_count / 14), (building_cells_by_type.get("runesmith_sanctum", []) as Array).size() * 2 + (building_cells_by_type.get("archives", []) as Array).size() + 1)},
			{"role": ROLE_GOLDSMITH, "count": mini(maxi(1, npc_count / 14), (building_cells_by_type.get("gemcutters_studio", []) as Array).size() * 2 + (building_cells_by_type.get("bank_vaults", []) as Array).size() + 1)},
			{"role": ROLE_HOLD_ELDER, "count": maxi(1, npc_count / 12)}
		]
	})
	# Start every dwarf where the current shift already puts them.
	for state: Dictionary in _npc_states:
		var sprite := state.get("sprite") as Sprite2D
		if sprite == null:
			continue
		var mode: String = SettlementNpcScheduler.mode_for_hour(state, _game_hour)
		var anchor: Vector2i = SettlementNpcScheduler.anchor_for_mode(state, mode)
		if anchor.x != 2147483647 and _is_walkable_cell(anchor):
			sprite.position = _cell_center_position(anchor)
			state["cell"] = anchor
			state["target"] = sprite.position
		DwarfHoldTavernService.update_character_frame(sprite, int(state.get("slot", 0)), 1, 0)

func _stream_world_chunks() -> void:
	if _world_noise.is_empty() or _player_sprite == null:
		return
	var player_chunk: Vector2i = UndergroundWorldService.chunk_for_cell(_player_cell)
	if player_chunk == _last_player_chunk:
		return
	_last_player_chunk = player_chunk
	_ensure_chunks_around(player_chunk)

func _ensure_chunks_around(player_chunk: Vector2i) -> void:
	for chunk_dy in range(-2, 3):
		for chunk_dx in range(-2, 3):
			var chunk := player_chunk + Vector2i(chunk_dx, chunk_dy)
			var key: String = UndergroundWorldService.chunk_key(chunk)
			if _generated_chunks.has(key):
				continue
			_generated_chunks[key] = true
			var stamped_site := false
			for site_variant: Variant in (_sites_by_chunk.get(key, []) as Array):
				var site := site_variant as Dictionary
				UndergroundWorldService.stamp_settlement_site(_latest_grid, _latest_floor_decor, site)
				_latest_district_labels.append({"name": String(site.get("name", "")), "center": site.get("cell", Vector2i.ZERO), "wild": true})
				stamped_site = true
			var discovery: Dictionary = UndergroundWorldService.stamp_chunk_discovery(_latest_grid, _latest_floor_decor, chunk, _world_seed_hash)
			if not discovery.is_empty():
				discovery["wild"] = true
				_latest_district_labels.append(discovery)
			var rect: Rect2i = UndergroundWorldService.generate_chunk(_latest_grid, _latest_floor_decor, chunk, _world_noise)
			_render_world_rect(rect.grow(14 if stamped_site else 1))
			if stamped_site or not discovery.is_empty():
				_rebuild_district_labels()
			var spawn_rng := RandomNumberGenerator.new()
			spawn_rng.seed = _world_seed_hash ^ hash(key)
			for spawn: Dictionary in UndergroundCreatureService.roll_chunk_spawns(_latest_grid, _latest_district_cell_map, rect, spawn_rng):
				_spawn_creature_at(spawn.get("cell", Vector2i.ZERO) as Vector2i, int(spawn.get("def_index", 0)))

## Renders a rect of the open world: carved floor, rock shells around it,
## and any streamed floor decor. Place-only, so city cells keep their
## richer render.
func _render_world_rect(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			var zone := _cell_at(_latest_grid, x, y)
			var base_tile := _pick_base_tile(_latest_grid, x, y, zone)
			if base_tile.is_empty():
				continue
			_place_tile(city_layer, cell, base_tile)
			if decor_layer.get_cell_source_id(cell) < 0 and _latest_floor_decor.has(cell):
				var decor_key := String(_latest_floor_decor[cell])
				_place_tile(decor_layer, cell, decor_key)
				if decor_key == "chest":
					_ensure_chest_inventory(cell)

func _is_diggable_cell(cell: Vector2i) -> bool:
	if _world_noise.is_empty():
		return false
	return _cell_at(_latest_grid, cell.x, cell.y) == CELL_ROCK

func _is_minable_rubble(cell: Vector2i) -> bool:
	if decor_layer.get_cell_source_id(cell) < 0:
		return false
	return decor_layer.get_cell_atlas_coords(cell) == TILE_ATLAS.get("stone", Vector2i(-1000, -1000))

## Click-harvest for wild decor: ore veins yield iron, fungal growth
## yields mushrooms.
func _try_harvest_decor(cell: Vector2i) -> bool:
	if not _is_player_adjacent_to_cell(cell):
		return false
	if decor_layer.get_cell_source_id(cell) < 0:
		return false
	var atlas := decor_layer.get_cell_atlas_coords(cell)
	if atlas == TILE_ATLAS.get("stone", Vector2i(-1000, -1000)):
		decor_layer.erase_cell(cell)
		_latest_floor_decor.erase(cell)
		var vein_drop := _roll_weighted_drop(ORE_VEIN_DROPS)
		_add_to_inventory(
			String(vein_drop.get("name", "Iron Ore")),
			_rng.randi_range(int(vein_drop.get("min", 1)), int(vein_drop.get("max", 2)))
		)
		return true
	if atlas == TILE_ATLAS.get("mushroom_wild", Vector2i(-1000, -1000)) or atlas == TILE_ATLAS.get("mushroom_crop_wild", Vector2i(-1000, -1000)) or atlas == TILE_ATLAS.get("mushroom_crops", Vector2i(-1000, -1000)):
		decor_layer.erase_cell(cell)
		_latest_floor_decor.erase(cell)
		_add_to_inventory("Mushrooms", _rng.randi_range(1, 2))
		if _rng.randi_range(1, 100) <= MUSHROOM_VARIETY_CHANCE_PERCENT:
			_add_to_inventory(WILD_MUSHROOM_VARIETIES[_rng.randi_range(0, WILD_MUSHROOM_VARIETIES.size() - 1)], 1)
		return true
	return false

func _roll_weighted_drop(drop_table: Array) -> Dictionary:
	var total_weight := 0
	for entry_variant: Variant in drop_table:
		total_weight += int((entry_variant as Dictionary).get("weight", 1))
	var roll := _rng.randi_range(1, maxi(total_weight, 1))
	for entry_variant: Variant in drop_table:
		roll -= int((entry_variant as Dictionary).get("weight", 1))
		if roll <= 0:
			return entry_variant as Dictionary
	return drop_table[0] as Dictionary

func _place_torch() -> void:
	if _player_sprite == null or _world_noise.is_empty():
		return
	if int(_player_inventory.get("Stone", 0)) < 1:
		_set_save_status("Need 1 Stone to place a torch (dig a wall)", Color(0.95, 0.75, 0.45, 1.0))
		return
	_add_to_inventory("Stone", -1)
	var level_data := _hold_state.generated_levels[_hold_state.current_level_index] as Dictionary
	if not level_data.has("torches"):
		level_data["torches"] = []
	(level_data["torches"] as Array).append(_player_cell)
	_spawn_torch_at(_player_cell)
	_set_save_status("Torch placed", Color(0.95, 0.85, 0.55, 1.0))

func _spawn_torch_at(cell: Vector2i) -> void:
	var torch := Sprite2D.new()
	torch.texture = _create_torch_texture()
	torch.centered = true
	torch.position = _cell_center_position(cell)
	torch.z_index = 14
	lighting_layer.add_child(torch)
	var glow := _create_glow_sprite(5.0)
	glow.position = Vector2.ZERO
	torch.add_child(glow)
	_torch_sprites.append(torch)

func _clear_torch_sprites() -> void:
	for torch_variant: Variant in _torch_sprites:
		var torch := torch_variant as Sprite2D
		if torch != null:
			torch.queue_free()
	_torch_sprites = []

func _create_torch_texture() -> Texture2D:
	var image := Image.create(8, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(7, 15):
		image.set_pixel(3, y, Color(0.45, 0.3, 0.16, 1.0))
		image.set_pixel(4, y, Color(0.36, 0.24, 0.13, 1.0))
	for y in range(2, 7):
		for x in range(2, 6):
			var flame := Color(1.0, 0.62, 0.15, 1.0) if y > 3 else Color(1.0, 0.85, 0.3, 1.0)
			if (x == 2 or x == 5) and y == 2:
				continue
			image.set_pixel(x, y, flame)
	image.resize(16, 32, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)

## --- The living world: coins, shops, and talk ----------------------------
## Coins buy goods at shop buildings (click an adjacent bakery, forge,
## tavern...); anything in the backpack sells for half its worth. NPCs
## chat when clicked and pass on rumors that point at real discoveries.

func _adjust_coins(amount: int) -> void:
	_player_coins = maxi(_player_coins + amount, 0)
	_update_coins_label()
	_save_player_inventory()

func _setup_coins_label() -> void:
	var controls := get_node_or_null("Margin/Layout/Controls")
	if controls == null:
		return
	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 13)
	_coins_label.modulate = Color(0.95, 0.85, 0.5, 1.0)
	controls.add_child(_coins_label)
	var clock := controls.get_node_or_null("ClockLabel")
	if clock != null:
		controls.move_child(_coins_label, clock.get_index() + 1)
	_update_coins_label()

func _update_coins_label() -> void:
	if _coins_label == null:
		return
	_coins_label.text = "🪙 %d coins" % _player_coins

func _shop_type_at_cell(cell: Vector2i) -> String:
	var building_type := String(_latest_civic_building_type_map.get(cell, ""))
	if SettlementEconomyService.is_shop_building_type(building_type):
		return building_type
	return ""

## One stock per building: flood-fill the contiguous same-type cells and
## key the shop by its smallest cell.
func _shop_anchor_for_cell(cell: Vector2i) -> Vector2i:
	var shop_type := String(_latest_civic_building_type_map.get(cell, ""))
	var anchor := cell
	var queue: Array[Vector2i] = [cell]
	var visited := {cell: true}
	var head := 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		if current.y < anchor.y or (current.y == anchor.y and current.x < anchor.x):
			anchor = current
		for offset: Vector2i in SPD_NEIGHBOR_OFFSETS:
			var next := current + offset
			if visited.has(next):
				continue
			if String(_latest_civic_building_type_map.get(next, "")) != shop_type:
				continue
			visited[next] = true
			queue.append(next)
	return anchor

func _price_scale() -> float:
	return 1.0 + float(absi(_world_seed_hash) % 40) / 100.0

func _is_trade_mode() -> bool:
	return _trade_shop_cell.x != 2147483647

func _open_trade_popup(cell: Vector2i, shop_type: String) -> void:
	var anchor := _shop_anchor_for_cell(cell)
	if not _shop_stocks.has(anchor):
		var stock_rng := RandomNumberGenerator.new()
		stock_rng.seed = _world_seed_hash ^ hash(anchor)
		_shop_stocks[anchor] = SettlementEconomyService.generate_shop_stock(shop_type, stock_rng)
	_selected_chest_cell = Vector2i(2147483647, 2147483647)
	_trade_shop_cell = anchor
	_trade_shop_type = shop_type
	chest_popup.visible = true
	chest_popup_title.text = "Trade — %s" % _display_name_for_building_type(shop_type)
	chest_popup_take_all_button.disabled = true
	var section_label := chest_popup.find_child("ChestSectionLabel", true, false) as Label
	if section_label != null:
		section_label.text = "Wares for sale"
	_refresh_trade_panel()

func _refresh_trade_panel() -> void:
	if not _is_trade_mode():
		return
	var stock := _shop_stocks.get(_trade_shop_cell, []) as Array
	_clear_inventory_slots(_chest_slot_panels, _chest_slot_labels, _chest_slot_icons)
	for i in range(mini(stock.size(), _chest_slot_labels.size())):
		var entry := stock[i] as Dictionary
		var item_name := String(entry.get("name", "Supplies"))
		var quantity := int(entry.get("quantity", 1))
		_fill_inventory_slot(i, _chest_slot_panels, _chest_slot_labels, _chest_slot_icons, item_name, quantity)
		_chest_slot_panels[i].tooltip_text += "\nBuy for %d coins" % SettlementEconomyService.buy_price(item_name, _price_scale())
	_populate_backpack_slots()
	chest_popup_status_label.text = "🪙 %d coins — click wares to buy, click your pack to sell" % _player_coins
	if stock.is_empty():
		chest_popup_status_label.text = "🪙 %d coins — the shelves are bare; come back later" % _player_coins

func _buy_trade_item(slot_index: int) -> void:
	var stock := _shop_stocks.get(_trade_shop_cell, []) as Array
	if slot_index < 0 or slot_index >= stock.size():
		return
	var entry := stock[slot_index] as Dictionary
	var item_name := String(entry.get("name", "Supplies"))
	var price := SettlementEconomyService.buy_price(item_name, _price_scale())
	if _player_coins < price:
		chest_popup_status_label.text = "Not enough coins for %s (%d needed)" % [item_name, price]
		return
	_adjust_coins(-price)
	entry["quantity"] = int(entry.get("quantity", 1)) - 1
	if int(entry.get("quantity", 0)) <= 0:
		stock.remove_at(slot_index)
	_add_to_inventory(item_name, 1)
	_refresh_trade_panel()
	chest_popup_status_label.text = "Bought %s for %d coins (🪙 %d left)" % [item_name, price, _player_coins]

func _sell_item(item_name: String) -> void:
	if int(_player_inventory.get(item_name, 0)) < 1:
		return
	var price := SettlementEconomyService.sell_price(item_name)
	_add_to_inventory(item_name, -1)
	_adjust_coins(price)
	_refresh_trade_panel()
	chest_popup_status_label.text = "Sold %s for %d coins (🪙 %d)" % [item_name, price, _player_coins]

func _on_chest_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not _is_trade_mode():
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	_buy_trade_item(slot_index)

func _end_trade_mode() -> void:
	_trade_shop_cell = Vector2i(2147483647, 2147483647)
	_trade_shop_type = ""

func _npc_state_at_cell(cell: Vector2i) -> Dictionary:
	for state: Dictionary in _npc_states:
		if (state.get("cell", Vector2i(2147483647, 2147483647)) as Vector2i) == cell:
			return state
	return {}

## Every dwarf is somebody: identities are rolled once at spawn from the
## hold's seeded rng, so the same seed always houses the same dwarves.
func _assign_npc_identities() -> void:
	for state: Dictionary in _npc_states:
		var role_title := String(ROLE_TITLES.get(int(state.get("role", 0)), "Dwarf"))
		var identity: Dictionary = NpcIdentityService.generate(_rng, role_title, "dwarf")
		state["identity"] = identity
		state["npc_name"] = String(identity.get("name", "A dwarf"))

func _show_npc_dialogue(state: Dictionary) -> void:
	var role_title := String(ROLE_TITLES.get(int(state.get("role", 0)), "Dwarf"))
	if not state.has("identity"):
		state["identity"] = NpcIdentityService.generate(_rng, role_title, "dwarf")
		state["npc_name"] = String((state["identity"] as Dictionary).get("name", "A dwarf"))
	var identity := state.get("identity", {}) as Dictionary
	# Sometimes they talk about themselves instead of the news.
	var line: String
	if _rng.randf() < 0.4:
		line = SettlementEconomyService.dialogue_line(role_title, NpcIdentityService.personal_line(identity, _rng), _rng)
	else:
		var rumor: String = SettlementEconomyService.rumor_from_labels(
			_latest_district_labels, _latest_district_cell_map, _player_cell, _rng
		)
		line = SettlementEconomyService.dialogue_line(role_title, rumor, _rng)
	var sprite := state.get("sprite") as Sprite2D
	var anchor_position: Vector2 = sprite.position if sprite != null else _player_sprite.position
	_spawn_speech_bubble("%s\n%s" % [NpcIdentityService.summary_line(identity), line], anchor_position)

func _spawn_speech_bubble(text: String, world_position: Vector2) -> void:
	if _active_speech_bubble != null and is_instance_valid(_active_speech_bubble):
		_active_speech_bubble.queue_free()
	var bubble := PanelContainer.new()
	var bubble_style := StyleBoxFlat.new()
	bubble_style.bg_color = Color(0.12, 0.1, 0.09, 0.92)
	bubble_style.border_color = Color(0.75, 0.65, 0.45, 1.0)
	bubble_style.border_width_left = 2
	bubble_style.border_width_top = 2
	bubble_style.border_width_right = 2
	bubble_style.border_width_bottom = 2
	bubble_style.corner_radius_top_left = 6
	bubble_style.corner_radius_top_right = 6
	bubble_style.corner_radius_bottom_left = 6
	bubble_style.corner_radius_bottom_right = 6
	bubble_style.content_margin_left = 8
	bubble_style.content_margin_right = 8
	bubble_style.content_margin_top = 5
	bubble_style.content_margin_bottom = 5
	bubble.add_theme_stylebox_override("panel", bubble_style)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(230, 0)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.94, 0.9, 0.8, 1.0))
	bubble.add_child(label)
	bubble.z_index = 40
	bubble.position = world_position + Vector2(-115.0, -86.0)
	city_layer.add_child(bubble)
	_active_speech_bubble = bubble
	var tween := create_tween()
	tween.tween_interval(4.5)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.5)
	tween.tween_callback(bubble.queue_free)

## --- Homesteading -------------------------------------------------------
## Carve a cave, then make it home: walls, paving, doors, and furniture
## built from what you've mined. Everything places adjacent to the player.

func _cycle_build_selection() -> void:
	_build_selection += 1
	if _build_selection >= BUILD_CATALOG.size():
		_build_selection = -1
		_set_save_status("Build mode off", Color(0.8, 0.8, 0.8, 1.0))
		return
	var entry := BUILD_CATALOG[_build_selection] as Dictionary
	_set_save_status("🔨 Build: %s (%s) — click a tile beside you · B for next" % [
		String(entry.get("name", "")), _build_costs_text(entry)
	], Color(0.85, 0.9, 0.75, 1.0))

func _build_costs_text(entry: Dictionary) -> String:
	var parts := PackedStringArray()
	var costs := entry.get("costs", {}) as Dictionary
	for item_variant: Variant in costs.keys():
		parts.append("%d %s" % [int(costs[item_variant]), String(item_variant)])
	return ", ".join(parts)

func _can_afford_build(entry: Dictionary) -> bool:
	var costs := entry.get("costs", {}) as Dictionary
	for item_variant: Variant in costs.keys():
		if int(_player_inventory.get(String(item_variant), 0)) < int(costs[item_variant]):
			return false
	return true

func _consume_build_costs(entry: Dictionary) -> void:
	var costs := entry.get("costs", {}) as Dictionary
	for item_variant: Variant in costs.keys():
		_add_to_inventory(String(item_variant), -int(costs[item_variant]))

## Places the selected buildable on an adjacent tile. Returns true when
## the click was consumed by build mode (even on a refused placement).
func _try_place_build(cell: Vector2i) -> bool:
	if _build_selection < 0 or _build_selection >= BUILD_CATALOG.size():
		return false
	if not _is_player_adjacent_to_cell(cell) or cell == _player_cell:
		return false
	var entry := BUILD_CATALOG[_build_selection] as Dictionary
	var build_name := String(entry.get("name", ""))
	if not _can_afford_build(entry):
		_set_save_status("Need %s for %s" % [_build_costs_text(entry), build_name], Color(0.95, 0.75, 0.45, 1.0))
		return true
	var zone := int(_latest_grid.get(cell, CELL_ROCK))
	var kind := String(entry.get("kind", "decor"))
	match kind:
		"wall":
			if zone != CELL_HALL and zone != CELL_PLAZA:
				_set_save_status("A wall needs open floor to stand on", Color(0.95, 0.75, 0.45, 1.0))
				return true
			if decor_layer.get_cell_source_id(cell) >= 0:
				_set_save_status("Clear that tile first", Color(0.95, 0.75, 0.45, 1.0))
				return true
			if _is_cell_occupied_by_npc(cell) or _creature_index_at_cell(cell) >= 0:
				_set_save_status("Someone is standing there", Color(0.95, 0.75, 0.45, 1.0))
				return true
			_latest_grid[cell] = CELL_ROCK
			_dug_cells.erase(cell)
			_render_world_rect(Rect2i(cell - Vector2i(2, 2), Vector2i(5, 5)))
			if _lighting_enabled:
				_update_shattered_visibility(_latest_grid)
				_refresh_lighting(_latest_grid)
		"floor":
			if zone != CELL_HALL:
				_set_save_status("Paving needs bare cavern floor", Color(0.95, 0.75, 0.45, 1.0))
				return true
			_latest_grid[cell] = CELL_PLAZA
			_render_world_rect(Rect2i(cell - Vector2i(1, 1), Vector2i(3, 3)))
		_:
			if zone != CELL_HALL and zone != CELL_PLAZA and zone != CELL_HOUSE:
				_set_save_status("%s needs carved ground" % build_name, Color(0.95, 0.75, 0.45, 1.0))
				return true
			if decor_layer.get_cell_source_id(cell) >= 0:
				_set_save_status("That tile is already furnished", Color(0.95, 0.75, 0.45, 1.0))
				return true
			var tile_key := String(entry.get("tile", "table"))
			_latest_floor_decor[cell] = tile_key
			# Player-built chests start empty: storage, not treasure.
			if tile_key == "chest" and not _chest_inventories.has(cell):
				_chest_inventories[cell] = []
			_place_tile(decor_layer, cell, tile_key)
	_consume_build_costs(entry)
	_set_save_status("Built %s" % build_name, Color(0.75, 0.92, 0.7, 1.0))
	_spawn_floating_text("+%s" % build_name, _cell_center_position(cell), Color(0.8, 0.95, 0.7, 1.0))
	return true

## --- Fishing ------------------------------------------------------------
## Cast next to a lake with F. The bobber drifts, dips on a bite ("!"),
## and pressing F inside the bite window reels in the catch. Moving
## snaps the line; reeling early scares the fish off.

func _handle_fish_action() -> void:
	if not _fishing_state.is_empty():
		if String(_fishing_state.get("phase", "")) == "bite":
			_catch_fish()
		else:
			_end_fishing("You reel in too early — nothing on the hook")
		return
	if _player_sprite == null or not _player_control_enabled:
		return
	var water_cell := _find_nearby_water_cell()
	if water_cell.x == 2147483647:
		_set_save_status("No still water within casting reach", Color(0.8, 0.85, 0.95, 1.0))
		return
	if int(_player_inventory.get(FISHING_ROD_ITEM, 0)) < 1:
		_set_save_status("You need an Old Fishing Rod — search chests and camps", Color(0.95, 0.75, 0.45, 1.0))
		return
	var bobber := Sprite2D.new()
	bobber.texture = _create_bobber_texture()
	bobber.position = _cell_center_position(water_cell)
	bobber.z_index = 13
	actor_layer.add_child(bobber)
	_fishing_state = {
		"cell": water_cell,
		"phase": "waiting",
		"timer": _rng.randf_range(2.5, 6.0),
		"bobber": bobber,
		"anchor": _player_cell,
		"bob_time": 0.0
	}
	_set_save_status("You cast your line into the dark water…", Color(0.75, 0.85, 0.95, 1.0))

func _find_nearby_water_cell() -> Vector2i:
	var best := Vector2i(2147483647, 2147483647)
	var best_distance := 999
	for offset_y in range(-2, 3):
		for offset_x in range(-2, 3):
			var candidate := _player_cell + Vector2i(offset_x, offset_y)
			if int(_latest_grid.get(candidate, CELL_ROCK)) != CELL_WATER:
				continue
			var distance := maxi(absi(offset_x), absi(offset_y))
			if distance < best_distance:
				best_distance = distance
				best = candidate
	return best

func _update_fishing(delta: float) -> void:
	if _fishing_state.is_empty():
		return
	if _player_cell != (_fishing_state.get("anchor", _player_cell) as Vector2i):
		_end_fishing("The line snaps as you move")
		return
	var bobber := _fishing_state.get("bobber") as Sprite2D
	if bobber == null:
		_fishing_state = {}
		return
	_fishing_state["bob_time"] = float(_fishing_state.get("bob_time", 0.0)) + delta
	_fishing_state["timer"] = float(_fishing_state.get("timer", 0.0)) - delta
	var rest_position: Vector2 = _cell_center_position(_fishing_state.get("cell", _player_cell) as Vector2i)
	var phase := String(_fishing_state.get("phase", "waiting"))
	if phase == "waiting":
		bobber.position = rest_position + Vector2(0.0, sin(float(_fishing_state.get("bob_time", 0.0)) * 3.0) * 1.5)
		if float(_fishing_state.get("timer", 0.0)) <= 0.0:
			_fishing_state["phase"] = "bite"
			_fishing_state["timer"] = 1.4
			_spawn_floating_text("!", bobber.position + Vector2(0, -10), Color(1.0, 0.9, 0.4, 1.0))
	else:
		bobber.position = rest_position + Vector2(0.0, 4.0 + sin(float(_fishing_state.get("bob_time", 0.0)) * 18.0) * 3.0)
		if float(_fishing_state.get("timer", 0.0)) <= 0.0:
			# The bite slips away; the bobber settles and waits again.
			_fishing_state["phase"] = "waiting"
			_fishing_state["timer"] = _rng.randf_range(2.0, 5.0)
			_set_save_status("The bite slips away…", Color(0.8, 0.85, 0.95, 1.0))

func _catch_fish() -> void:
	var bobber := _fishing_state.get("bobber") as Sprite2D
	var catch_position: Vector2 = bobber.position if bobber != null else _player_sprite.position
	var caught := _roll_weighted_drop(FISH_CATCH_TABLE)
	var item_name := String(caught.get("name", "Cave Perch"))
	_add_to_inventory(item_name, 1)
	_spawn_floating_text("Caught %s!" % item_name, catch_position, Color(0.6, 0.95, 1.0, 1.0))
	var flavor: String = ItemDefsService.flavor_text(item_name)
	_end_fishing("Caught %s!%s" % [item_name, (" " + flavor) if not flavor.is_empty() else ""])

func _end_fishing(message: String) -> void:
	var bobber := _fishing_state.get("bobber") as Sprite2D
	if bobber != null:
		bobber.queue_free()
	_fishing_state = {}
	if not message.is_empty():
		_set_save_status(message, Color(0.75, 0.85, 0.95, 1.0))

func _create_bobber_texture() -> Texture2D:
	var image := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(10):
		for x in range(10):
			var distance := Vector2(x - 4.5, y - 4.5).length()
			if distance <= 4.0:
				image.set_pixel(x, y, Color(0.85, 0.2, 0.15, 1.0) if y < 5 else Color(0.95, 0.93, 0.88, 1.0))
			elif distance <= 4.8:
				image.set_pixel(x, y, Color(0.15, 0.1, 0.1, 1.0))
	image.resize(20, 20, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)

## --- Cooking & eating -----------------------------------------------------
## Press C beside a torch or a hearth building to cook raw food: a raw fish
## and a raw mushroom together become Hearty Stew, otherwise each cooks into
## its own dish. Press E (or click a backpack slot) to eat; the quick-eat
## always picks the smallest meal that still helps.

## True when the player stands within one cell of a placed torch or of a
## civic building that keeps a fire burning.
func _is_heat_source_nearby() -> bool:
	if _hold_state.current_level_index >= 0 and _hold_state.current_level_index < _hold_state.generated_levels.size():
		var level_data := _hold_state.generated_levels[_hold_state.current_level_index] as Dictionary
		for torch_cell_variant: Variant in (level_data.get("torches", []) as Array):
			var torch_cell := torch_cell_variant as Vector2i
			if maxi(absi(torch_cell.x - _player_cell.x), absi(torch_cell.y - _player_cell.y)) <= 1:
				return true
	for offset_y: int in range(-1, 2):
		for offset_x: int in range(-1, 2):
			var candidate := _player_cell + Vector2i(offset_x, offset_y)
			var building_type := String(_latest_civic_building_type_map.get(candidate, ""))
			if COOKING_HEAT_BUILDING_TYPES.has(building_type):
				return true
	return false

## The first inventory item (alphabetically) that cooks into the given dish.
func _first_raw_ingredient_for(dish_name: String) -> String:
	var item_names := _player_inventory.keys()
	item_names.sort()
	for item_variant: Variant in item_names:
		var item_name := String(item_variant)
		if ItemDefsService.cooked_result(item_name) == dish_name and int(_player_inventory.get(item_name, 0)) >= 1:
			return item_name
	return ""

func _handle_cook_action() -> void:
	if _player_sprite == null:
		return
	if not _is_heat_source_nearby():
		_set_save_status("You need a fire — stand by a torch or a hearth", Color(0.95, 0.75, 0.45, 1.0))
		return
	var raw_fish := _first_raw_ingredient_for("Grilled Fish")
	var raw_mushroom := _first_raw_ingredient_for("Mushroom Skewer")
	var raw_meat := _first_raw_ingredient_for("Roast Meat")
	var dish := ""
	if not raw_fish.is_empty() and not raw_mushroom.is_empty():
		_add_to_inventory(raw_fish, -1)
		_add_to_inventory(raw_mushroom, -1)
		dish = "Hearty Stew"
	elif not raw_meat.is_empty():
		_add_to_inventory(raw_meat, -1)
		dish = "Roast Meat"
	elif not raw_fish.is_empty():
		_add_to_inventory(raw_fish, -1)
		dish = "Grilled Fish"
	elif not raw_mushroom.is_empty():
		_add_to_inventory(raw_mushroom, -1)
		dish = "Mushroom Skewer"
	else:
		_set_save_status("Nothing raw to cook", Color(0.8, 0.85, 0.95, 1.0))
		return
	_add_to_inventory(dish, 1)
	_spawn_floating_text("Cooked %s!" % dish, _player_sprite.position, Color(1.0, 0.8, 0.45, 1.0))
	_set_save_status(ItemDefsService.flavor_text(dish), Color(0.95, 0.85, 0.6, 1.0))

## Quick-eat: pick the smallest-heal edible in the pack so nothing big is
## wasted on a scratch.
func _handle_quick_eat_action() -> void:
	if _player_hp >= PLAYER_MAX_HP:
		_set_save_status("You're at full health", Color(0.7, 0.9, 0.7, 1.0))
		return
	var choice := ""
	var choice_heal := 2147483647
	var item_names := _player_inventory.keys()
	item_names.sort()
	for item_variant: Variant in item_names:
		var item_name := String(item_variant)
		if not ItemDefsService.is_edible(item_name):
			continue
		var heal := ItemDefsService.heal_amount(item_name)
		if heal < choice_heal:
			choice_heal = heal
			choice = item_name
	if choice.is_empty():
		_set_save_status("Nothing edible in your pack", Color(0.8, 0.85, 0.95, 1.0))
		return
	_eat_item(choice)

## Eats one of the named item: heals, refreshes the HP label, and lets
## _add_to_inventory refresh the backpack UI and persist the change.
func _eat_item(item_name: String) -> void:
	if not ItemDefsService.is_edible(item_name) or int(_player_inventory.get(item_name, 0)) < 1:
		return
	if _player_hp >= PLAYER_MAX_HP:
		_set_save_status("You're at full health", Color(0.7, 0.9, 0.7, 1.0))
		return
	var heal := ItemDefsService.heal_amount(item_name)
	_add_to_inventory(item_name, -1)
	_player_hp = minf(_player_hp + float(heal), PLAYER_MAX_HP)
	_update_hp_label()
	if _player_sprite != null:
		_spawn_floating_text("+%d" % heal, _player_sprite.position, Color(0.5, 0.95, 0.5, 1.0))
	_set_save_status("Ate %s (+%d)" % [item_name, heal], Color(0.7, 0.95, 0.6, 1.0))

## --- Creatures & combat -------------------------------------------------
## The wild dark bites back: chunks roll ambient spawns, the deep repopulates
## near the player, and anything that closes to melee range chews on the
## player's hearts. The city itself stays safe ground - creatures refuse to
## step onto district cells and the hold slowly heals you.

func _spawn_creature_at(cell: Vector2i, def_index: int) -> void:
	if _creature_states.size() >= CREATURE_CAP:
		return
	if def_index < 0 or def_index >= UndergroundCreatureService.CREATURE_DEFS.size():
		return
	var def: Dictionary = UndergroundCreatureService.CREATURE_DEFS[def_index]
	var sprite: Sprite2D = UndergroundCreatureService.create_creature_sprite(_creature_texture, int(def.get("slot", 0)), tile_size)
	sprite.position = _cell_center_position(cell)
	sprite.z_index = 12
	actor_layer.add_child(sprite)
	_creature_states.append({
		"def_index": def_index,
		"hp": int(def.get("max_hp", 4)),
		"cell": cell,
		"sprite": sprite,
		"moving": false,
		"dying": false,
		"anim": "idle",
		"wander_timer": _rng.randf_range(0.5, 2.0),
		"attack_timer": 0.0,
		"anim_time": _rng.randf_range(0.0, 1.0),
		"facing_dir": Vector2i(0, 1)
	})

func _clear_creatures() -> void:
	for state: Dictionary in _creature_states:
		var sprite := state.get("sprite") as Sprite2D
		if sprite != null:
			sprite.queue_free()
	_creature_states = []

func _creature_index_at_cell(cell: Vector2i) -> int:
	for index in range(_creature_states.size()):
		var state := _creature_states[index]
		if bool(state.get("dying", false)):
			continue
		if (state.get("cell", Vector2i(2147483647, 2147483647)) as Vector2i) == cell:
			return index
		if bool(state.get("moving", false)) and (state.get("move_cell", Vector2i(2147483647, 2147483647)) as Vector2i) == cell:
			return index
	return -1

func _creature_can_step_to(cell: Vector2i) -> bool:
	if not _is_walkable_cell(cell):
		return false
	if _latest_district_cell_map.has(cell):
		return false
	if _creature_index_at_cell(cell) >= 0:
		return false
	return cell != _player_cell

## Keeps the dark around the player populated after chunk-roll creatures
## are slain or left behind.
func _update_creature_spawning(delta: float) -> void:
	if _world_noise.is_empty() or _player_sprite == null or not _player_control_enabled:
		return
	if _latest_district_cell_map.has(_player_cell):
		return
	_creature_repop_timer -= delta
	if _creature_repop_timer > 0.0:
		return
	_creature_repop_timer = _rng.randf_range(3.0, 6.0)
	if _creature_states.size() >= CREATURE_CAP:
		return
	var angle := _rng.randf_range(0.0, TAU)
	var distance := _rng.randf_range(12.0, 26.0)
	var cell := _player_cell + Vector2i(int(round(cos(angle) * distance)), int(round(sin(angle) * distance)))
	if not _creature_can_step_to(cell):
		return
	_spawn_creature_at(cell, UndergroundCreatureService.pick_definition_index(Vector2(cell).length(), _rng))

func _update_creatures(delta: float) -> void:
	if _creature_states.is_empty():
		return
	var removals: Array[int] = []
	for index in range(_creature_states.size()):
		var state := _creature_states[index]
		var sprite := state.get("sprite") as Sprite2D
		if sprite == null:
			removals.append(index)
			continue
		var def: Dictionary = UndergroundCreatureService.CREATURE_DEFS[int(state.get("def_index", 0))]
		state["anim_time"] = float(state.get("anim_time", 0.0)) + delta
		# Corpses play their death animation, linger a beat, then fade.
		if bool(state.get("dying", false)):
			if float(state.get("anim_time", 0.0)) >= UndergroundCreatureService.anim_duration("death") + 0.6:
				sprite.queue_free()
				removals.append(index)
			else:
				_animate_creature(state, sprite, def)
			continue
		var cell := state.get("cell", Vector2i.ZERO) as Vector2i
		var player_distance := maxi(absi(cell.x - _player_cell.x), absi(cell.y - _player_cell.y))
		if player_distance > CREATURE_DESPAWN_DISTANCE:
			sprite.queue_free()
			removals.append(index)
			continue
		state["attack_timer"] = maxf(float(state.get("attack_timer", 0.0)) - delta, 0.0)
		# One-shot swings and flinches play out, then locomotion retakes the sprite.
		var current_anim := String(state.get("anim", "idle"))
		if (current_anim == "attack" or current_anim == "hurt") and float(state.get("anim_time", 0.0)) >= UndergroundCreatureService.anim_duration(current_anim):
			_set_creature_anim(state, "idle")
		if bool(state.get("moving", false)):
			var target := state.get("move_target", sprite.position) as Vector2
			sprite.position = sprite.position.move_toward(target, float(def.get("speed", 60.0)) * delta)
			if sprite.position.distance_to(target) <= 0.5:
				sprite.position = target
				state["cell"] = state.get("move_cell", cell) as Vector2i
				state["moving"] = false
		elif player_distance <= 1 and _player_sprite != null and _player_control_enabled:
			state["facing_dir"] = _direction_between_cells(cell, _player_cell)
			if float(state.get("attack_timer", 0.0)) <= 0.0:
				state["attack_timer"] = float(def.get("attack_cooldown", 1.3))
				_set_creature_anim(state, "attack")
				_damage_player(int(def.get("damage", 1)), String(def.get("name", "creature")))
		else:
			var step := Vector2i.ZERO
			if player_distance <= int(def.get("aggro_range", 6)) and not _latest_district_cell_map.has(_player_cell):
				step = _creature_step_toward(cell, _player_cell)
			else:
				state["wander_timer"] = float(state.get("wander_timer", 0.0)) - delta
				if float(state.get("wander_timer", 0.0)) <= 0.0:
					state["wander_timer"] = _rng.randf_range(1.2, 3.2)
					var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
					step = directions[_rng.randi_range(0, 3)]
			if step != Vector2i.ZERO:
				var next_cell := cell + step
				if _creature_can_step_to(next_cell):
					state["moving"] = true
					state["move_cell"] = next_cell
					state["move_target"] = _cell_center_position(next_cell)
					state["facing_dir"] = step
		# Locomotion owns the looped animations unless a one-shot is playing.
		current_anim = String(state.get("anim", "idle"))
		if current_anim != "attack" and current_anim != "hurt":
			_set_creature_anim(state, "walk" if bool(state.get("moving", false)) else "idle")
		_animate_creature(state, sprite, def)
	for removal_index in range(removals.size() - 1, -1, -1):
		_creature_states.remove_at(removals[removal_index])

func _creature_step_toward(from_cell: Vector2i, target_cell: Vector2i) -> Vector2i:
	var best := Vector2i.ZERO
	var best_distance := Vector2(from_cell).distance_squared_to(Vector2(target_cell))
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var next := from_cell + direction
		if not _creature_can_step_to(next):
			continue
		var distance := Vector2(next).distance_squared_to(Vector2(target_cell))
		if distance < best_distance:
			best_distance = distance
			best = direction
	return best

func _direction_between_cells(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	var delta := to_cell - from_cell
	if absi(delta.x) >= absi(delta.y):
		return Vector2i.RIGHT if delta.x >= 0 else Vector2i.LEFT
	return Vector2i.DOWN if delta.y >= 0 else Vector2i.UP

func _set_creature_anim(state: Dictionary, anim_name: String) -> void:
	if String(state.get("anim", "")) == anim_name:
		return
	state["anim"] = anim_name
	state["anim_time"] = 0.0

func _animate_creature(state: Dictionary, sprite: Sprite2D, def: Dictionary) -> void:
	var facing_dir := state.get("facing_dir", Vector2i(0, 1)) as Vector2i
	var facing_row := 0
	if facing_dir == Vector2i.RIGHT:
		facing_row = 1
	elif facing_dir == Vector2i.LEFT:
		facing_row = 2
	elif facing_dir == Vector2i.UP:
		facing_row = 3
	UndergroundCreatureService.update_creature_frame(
		sprite, int(def.get("slot", 0)),
		String(state.get("anim", "idle")),
		float(state.get("anim_time", 0.0)),
		facing_row
	)

func _attack_creature(creature_index: int) -> void:
	if creature_index < 0 or creature_index >= _creature_states.size():
		return
	if _player_attack_timer > 0.0:
		return
	_player_attack_timer = PLAYER_ATTACK_COOLDOWN
	var state := _creature_states[creature_index]
	if bool(state.get("dying", false)):
		return
	var def: Dictionary = UndergroundCreatureService.CREATURE_DEFS[int(state.get("def_index", 0))]
	var sprite := state.get("sprite") as Sprite2D
	state["hp"] = int(state.get("hp", 1)) - PLAYER_ATTACK_DAMAGE
	if sprite != null:
		_flash_sprite(sprite, Color(1.0, 0.45, 0.45, 1.0))
		_spawn_floating_text("-%d" % PLAYER_ATTACK_DAMAGE, sprite.position, Color(1.0, 0.85, 0.5, 1.0))
	if int(state.get("hp", 0)) > 0:
		_set_creature_anim(state, "hurt")
		return
	var loot: Dictionary = UndergroundCreatureService.roll_loot(def, _rng)
	var loot_parts := PackedStringArray()
	var loot_items := loot.keys()
	loot_items.sort()
	for item_variant: Variant in loot_items:
		_add_to_inventory(String(item_variant), int(loot[item_variant]))
		loot_parts.append("%s ×%d" % [String(item_variant), int(loot[item_variant])])
	# The corpse plays its death animation out before fading (see
	# _update_creatures); dying creatures no longer block or take hits.
	state["dying"] = true
	state["moving"] = false
	_set_creature_anim(state, "death")
	var message := "Slew %s" % String(def.get("name", "creature"))
	if not loot_parts.is_empty():
		message += " — " + ", ".join(loot_parts)
	_set_save_status(message, Color(0.85, 0.95, 0.7, 1.0))

func _damage_player(amount: int, source_name: String) -> void:
	if _player_sprite == null:
		return
	_player_hp = maxf(_player_hp - float(amount), 0.0)
	_update_hp_label()
	_flash_sprite(_player_sprite, Color(1.0, 0.35, 0.35, 1.0))
	_spawn_floating_text("-%d" % amount, _player_sprite.position, Color(1.0, 0.4, 0.4, 1.0))
	if _player_hp <= 0.0:
		_handle_player_death(source_name)

func _handle_player_death(source_name: String) -> void:
	_player_hp = PLAYER_MAX_HP
	_update_hp_label()
	_player_move_path.clear()
	_player_is_moving = false
	_relocate_player_to_city_heart(_latest_grid)
	_set_save_status("Slain by %s — you wake back in the hold" % source_name, Color(0.95, 0.5, 0.5, 1.0))

## The hold is home: standing on city ground slowly mends your wounds.
func _update_player_regen(delta: float) -> void:
	if _player_sprite == null or _player_hp >= PLAYER_MAX_HP:
		return
	if _latest_district_cell_map.is_empty() or _latest_district_cell_map.has(_player_cell):
		_player_hp = minf(_player_hp + CITY_REGEN_PER_SECOND * delta, PLAYER_MAX_HP)
		_update_hp_label()

func _setup_hp_label() -> void:
	var controls := get_node_or_null("Margin/Layout/Controls")
	if controls == null:
		return
	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 13)
	controls.add_child(_hp_label)
	var clock := controls.get_node_or_null("ClockLabel")
	if clock != null:
		controls.move_child(_hp_label, clock.get_index() + 1)
	_update_hp_label()

func _update_hp_label() -> void:
	if _hp_label == null:
		return
	_hp_label.text = "❤ %d / %d" % [int(ceil(_player_hp)), int(PLAYER_MAX_HP)]
	if _player_hp <= PLAYER_MAX_HP * 0.3:
		_hp_label.modulate = Color(1.0, 0.5, 0.5, 1.0)
	else:
		_hp_label.modulate = Color(0.95, 0.87, 0.87, 1.0)

func _flash_sprite(sprite: Sprite2D, flash_color: Color) -> void:
	sprite.modulate = flash_color
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)

func _spawn_floating_text(text: String, world_position: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.1, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.position = world_position + Vector2(-12.0, -30.0)
	label.z_index = 30
	city_layer.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 22.0, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.15)
	tween.chain().tween_callback(label.queue_free)

func _add_to_inventory(item_name: String, amount: int) -> void:
	# Coins are currency, not cargo: they go to the purse, not the pack.
	if item_name == "Copper Coins":
		_adjust_coins(amount)
		return
	_player_inventory[item_name] = int(_player_inventory.get(item_name, 0)) + amount
	if int(_player_inventory.get(item_name, 0)) <= 0:
		_player_inventory.erase(item_name)
	_update_inventory_label()
	_save_player_inventory()

func _save_player_inventory() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings") or not game_session.has_method("set_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	settings["player_inventory"] = _player_inventory.duplicate()
	settings["player_coins"] = _player_coins
	game_session.call("set_world_settings", settings)

func _update_inventory_label() -> void:
	if _inventory_label == null:
		return
	if _player_inventory.is_empty():
		_inventory_label.text = "🎒 Backpack empty — dig rock, mine ore, pick mushrooms"
		_populate_backpack_slots()
		return
	var parts := PackedStringArray()
	var item_names := _player_inventory.keys()
	item_names.sort()
	for item_variant: Variant in item_names:
		parts.append("%s ×%d" % [String(item_variant), int(_player_inventory[item_variant])])
	_inventory_label.text = "🎒 " + ", ".join(parts)
	_populate_backpack_slots()

func _dig_cell(cell: Vector2i) -> void:
	_latest_grid[cell] = CELL_HALL
	_dug_cells[cell] = true
	_add_to_inventory("Stone", 1)
	if _rng.randi_range(1, 100) <= DIG_FOSSIL_CHANCE_PERCENT:
		var fossil: String = DIG_FOSSIL_FINDS[_rng.randi_range(0, DIG_FOSSIL_FINDS.size() - 1)]
		_add_to_inventory(fossil, 1)
		if _player_sprite != null:
			_spawn_floating_text("Found %s!" % fossil, _player_sprite.position, Color(0.95, 0.9, 0.6, 1.0))
	_render_world_rect(Rect2i(cell - Vector2i(1, 1), Vector2i(3, 3)))
	if _lighting_enabled:
		_update_shattered_visibility(_latest_grid)
		_refresh_lighting(_latest_grid)

func _collect_walkable_cells(grid: Dictionary) -> Array[Vector2i]:
	return DwarfHoldLayoutService.collect_walkable_cells(grid, [CELL_HALL, CELL_HOUSE, CELL_BUILDING, CELL_PLAZA])

func _seeded_shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func _create_tavern_character_sprite(character_slot: int) -> Sprite2D:
	return DwarfHoldTavernService.create_tavern_character_sprite(_placeholder_actor_texture, character_slot, tile_size)

func _create_player_character_sprite() -> Sprite2D:
	return DwarfHoldTavernService.create_player_character_sprite(
		_shattered_player_texture,
		tile_size,
		Callable(self, "_create_tavern_character_sprite")
	)

func _create_placeholder_actor_texture() -> Texture2D:
	return DwarfHoldTavernService.create_placeholder_actor_texture()

func _handle_player_click_action(mouse_position: Vector2) -> void:
	if _player_sprite == null or not _player_control_enabled:
		return
	var clicked_cell := _cell_from_mouse_position(mouse_position)
	if _build_selection >= 0 and _try_place_build(clicked_cell):
		return
	if _is_chest_cell(clicked_cell):
		_request_chest_interaction(clicked_cell)
		return
	var npc_state := _npc_state_at_cell(clicked_cell)
	if not npc_state.is_empty() and _is_player_adjacent_to_cell(clicked_cell):
		_show_npc_dialogue(npc_state)
		return
	var shop_type := _shop_type_at_cell(clicked_cell)
	if not shop_type.is_empty() and _is_player_adjacent_to_cell(clicked_cell):
		_open_trade_popup(clicked_cell, shop_type)
		return
	if _try_harvest_decor(clicked_cell):
		return
	_request_player_move_to_cell(clicked_cell)

func _request_chest_interaction(chest_cell: Vector2i) -> void:
	if _is_player_adjacent_to_cell(chest_cell):
		_handle_chest_click(_screen_position_from_cell(chest_cell))
		return
	var approach_cell := _nearest_walkable_neighbor(chest_cell)
	if approach_cell.x == 2147483647:
		_clear_chest_selection()
		return
	_request_player_move_to_cell(approach_cell)
	if not _player_move_path.is_empty():
		_player_pending_chest_interaction = chest_cell

func _is_player_adjacent_to_cell(cell: Vector2i) -> bool:
	var delta := cell - _player_cell
	return maxi(absi(delta.x), absi(delta.y)) <= 1

func _nearest_walkable_neighbor(cell: Vector2i) -> Vector2i:
	var best := Vector2i(2147483647, 2147483647)
	var best_distance := INF
	for offset: Vector2i in SPD_NEIGHBOR_OFFSETS:
		var neighbor: Vector2i = cell + offset
		if not _is_walkable_cell(neighbor):
			continue
		var distance := Vector2(_player_cell).distance_squared_to(Vector2(neighbor))
		if distance < best_distance:
			best_distance = distance
			best = neighbor
	return best

func _request_player_move_to_cell(target_cell: Vector2i) -> void:
	if _player_sprite == null or not _player_control_enabled:
		return
	if target_cell == _player_cell:
		_player_move_path.clear()
		return
	var creature_index := _creature_index_at_cell(target_cell)
	if creature_index >= 0:
		if _is_player_adjacent_to_cell(target_cell):
			_attack_creature(creature_index)
			return
		var approach_cell := _nearest_walkable_neighbor(target_cell)
		if approach_cell.x != 2147483647 and approach_cell != target_cell:
			_request_player_move_to_cell(approach_cell)
		return
	if _is_diggable_cell(target_cell) and _is_player_adjacent_to_cell(target_cell):
		_dig_cell(target_cell)
		return
	if _latest_grid.is_empty() or not _latest_grid.has(target_cell):
		return

	var next_path := _build_player_path(_player_cell, target_cell)
	if next_path.is_empty():
		if not _is_cell_occupied_by_npc(target_cell):
			_player_move_path.clear()
		return

	_player_move_path = next_path
	if not _player_is_moving:
		_update_player_turn_movement(0.0)

func _try_use_stairs_at_player_cell() -> bool:
	if _hold_state.generated_levels.is_empty() or _hold_state.current_level_index < 0 or _hold_state.current_level_index >= _hold_state.generated_levels.size():
		return false

	var stair_direction := _stair_direction_at_cell(_player_cell)
	if stair_direction == "down" and _hold_state.current_level_index < _hold_state.generated_levels.size() - 1:
		var destination_index := _hold_state.current_level_index + 1
		_pending_player_spawn_cell = _resolve_stair_spawn_cell(destination_index, "up", _player_cell)
		_show_level(destination_index)
		return true
	if stair_direction == "up" and _hold_state.current_level_index > 0:
		var destination_index := _hold_state.current_level_index - 1
		_pending_player_spawn_cell = _resolve_stair_spawn_cell(destination_index, "down", _player_cell)
		_show_level(destination_index)
		return true
	return false

func _stair_direction_at_cell(cell: Vector2i) -> String:
	for layer: TileMapLayer in [decor_layer, city_layer]:
		if layer == null or layer.get_cell_source_id(cell) < 0:
			continue
		var atlas := layer.get_cell_atlas_coords(cell)
		if atlas == TILE_ATLAS["stairway_up"]:
			return "up"
		if atlas == TILE_ATLAS["stairway_down"]:
			return "down"
	return ""

func _resolve_stair_spawn_cell(level_index: int, preferred_stair: String, fallback_cell: Vector2i) -> Vector2i:
	if level_index < 0 or level_index >= _hold_state.generated_levels.size():
		return fallback_cell
	var level_data := _hold_state.generated_levels[level_index] as Dictionary
	var stairs := level_data.get("stair_cells", {}) as Dictionary
	if stairs.has(preferred_stair):
		return stairs[preferred_stair] as Vector2i
	if stairs.has("up"):
		return stairs["up"] as Vector2i
	if stairs.has("down"):
		return stairs["down"] as Vector2i
	return fallback_cell

func _build_player_path(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if from_cell == to_cell:
		return result

	var queue: Array[Vector2i] = [from_cell]
	var visited := {from_cell: true}
	var came_from: Dictionary = {}
	var found := false

	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		if current == to_cell:
			found = true
			break
		for offset: Vector2i in SPD_NEIGHBOR_OFFSETS:
			var next := current + offset
			if visited.has(next):
				continue
			if not _can_step_to_cell(current, next, to_cell):
				continue
			visited[next] = true
			came_from[next] = current
			queue.append(next)

	if not found:
		return result

	var path_reversed: Array[Vector2i] = []
	var cursor := to_cell
	while cursor != from_cell:
		path_reversed.append(cursor)
		cursor = came_from.get(cursor, from_cell) as Vector2i
		if cursor == from_cell:
			break
	if path_reversed.is_empty():
		return result
	for i in range(path_reversed.size() - 1, -1, -1):
		result.append(path_reversed[i])
	return result

func _can_step_to_cell(from_cell: Vector2i, to_cell: Vector2i, goal_cell: Vector2i) -> bool:
	if not _latest_grid.has(to_cell):
		return false
	if not _is_walkable_cell(to_cell):
		return false
	if to_cell != goal_cell and _is_cell_occupied_by_npc(to_cell):
		return false
	if _creature_index_at_cell(to_cell) >= 0:
		return false
	var delta := to_cell - from_cell
	if absi(delta.x) == 1 and absi(delta.y) == 1:
		var orth_a := from_cell + Vector2i(delta.x, 0)
		var orth_b := from_cell + Vector2i(0, delta.y)
		if not _is_walkable_cell(orth_a) or not _is_walkable_cell(orth_b):
			return false
	return true

func _is_cell_occupied_by_npc(cell: Vector2i) -> bool:
	return DwarfHoldTavernService.is_cell_occupied_by_npc(cell, _npc_states)

func _screen_position_from_cell(cell: Vector2i) -> Vector2:
	return city_layer.position + (_cell_center_position(cell) * _zoom_level)

func _try_move_player(direction: Vector2i) -> bool:
	if direction == Vector2i.ZERO:
		return false
	var target_cell := _player_cell + direction
	if not _is_walkable_cell(target_cell):
		return false
	if _is_cell_occupied_by_npc(target_cell):
		return false
	if _creature_index_at_cell(target_cell) >= 0:
		return false
	_player_move_target_cell = target_cell
	_player_move_target_position = _cell_center_position(target_cell)
	_player_is_moving = true
	return true

func _center_view_on_cell(cell: Vector2i) -> void:
	_center_view_on_world_position(_cell_center_position(cell))

func _center_view_on_world_position(local_position: Vector2) -> void:
	var panel_size := city_panel.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		return
	var panel_center := panel_size * 0.5
	_pan_offset = panel_center - ((_map_origin_offset + local_position) * _zoom_level)
	_update_city_layer_transform()

func _update_npc_movement(delta: float) -> void:
	SettlementNpcScheduler.update_scheduled_npcs(
		delta, _npc_states, city_layer, _rng,
		tile_size, _game_hour,
		Callable(self, "_is_npc_walkable_cell"),
		Callable(self, "_cell_center_position")
	)

func _create_placeholder_tavern_character_texture() -> Texture2D:
	return DwarfHoldTavernService.create_placeholder_tavern_character_texture()

func _is_walkable_cell(cell: Vector2i) -> bool:
	if _latest_grid.is_empty():
		return false
	if _furnishing_blocked_cells.has(cell):
		return false
	var zone := int(_latest_grid.get(cell, CELL_ROCK))
	if zone != CELL_HALL and zone != CELL_HOUSE and zone != CELL_BUILDING and zone != CELL_PLAZA:
		return false
	return _is_passable_cell_for_actor(cell)

func _is_npc_walkable_cell(cell: Vector2i) -> bool:
	return DwarfHoldTavernService.is_npc_walkable_cell(cell, Callable(self, "_is_walkable_cell"), decor_layer, TILE_ATLAS["stone"])

## --- Interior furnishing: lived-in homes and stocked cellars ---------------
## Same engine as the towns: template furniture sprites in every roomy
## house, stocked shelves in tavern/brewery/warehouse-type buildings,
## and candlelight pools. The hold's stone rooms keep their tile beds;
## the sprites layer comfort on top.

func _furnish_interiors(grid: Dictionary) -> void:
	for sprite: Node2D in _furnishing_sprites:
		sprite.queue_free()
	_furnishing_sprites.clear()
	_furnishing_blocked_cells.clear()
	if actor_layer == null:
		return
	var is_occupied := func(cell: Vector2i) -> bool:
		return decor_layer.get_cell_source_id(cell) >= 0
	for component_variant: Variant in RoomFurnishingService.collect_zone_components(grid, CELL_HOUSE):
		var component: Array[Vector2i] = []
		for cell_variant: Variant in (component_variant as Array):
			component.append(cell_variant as Vector2i)
		var placements: Array[Dictionary] = RoomFurnishingService.plan_house_furnishing(component, is_occupied, _door_cells, _rng)
		_apply_furnishing_placements(placements)
	for component_variant: Variant in RoomFurnishingService.collect_zone_components(grid, CELL_BUILDING):
		var component: Array[Vector2i] = []
		for cell_variant: Variant in (component_variant as Array):
			component.append(cell_variant as Vector2i)
		if component.is_empty():
			continue
		var building_type := String(_latest_civic_building_type_map.get(component[0], ""))
		var placements: Array[Dictionary] = RoomFurnishingService.plan_shop_dressing(component, building_type, is_occupied, _door_cells, _rng)
		_apply_furnishing_placements(placements)

func _apply_furnishing_placements(placements: Array[Dictionary]) -> void:
	for placement: Dictionary in placements:
		var piece_name := String(placement.get("piece", ""))
		var base_cell := placement.get("cell", Vector2i.ZERO) as Vector2i
		var sprite: Sprite2D = RoomFurnishingService.create_piece_sprite(piece_name, base_cell, tile_size)
		if sprite == null:
			continue
		actor_layer.add_child(sprite)
		_furnishing_sprites.append(sprite)
		if int((RoomFurnishingService.PIECES.get(piece_name, {}) as Dictionary).get("rows_block", 1)) > 0:
			for cell: Vector2i in RoomFurnishingService.footprint_cells(piece_name, base_cell):
				_furnishing_blocked_cells[cell] = true
		if RoomFurnishingService.piece_emits_light(piece_name):
			var glow: Sprite2D = RoomFurnishingService.create_glow_sprite(
				_cell_center_position(base_cell),
				2.4 * float(tile_size.x),
				Color(1.0, 0.72, 0.35, 1.0)
			)
			actor_layer.add_child(glow)
			_furnishing_sprites.append(glow)

func _actor_sprite_to_cell(sprite: Sprite2D, cell: Vector2i) -> void:
	sprite.position = _cell_center_position(cell)

func _cell_center_position(cell: Vector2i) -> Vector2:
	return city_layer.map_to_local(cell)

func _place_tile(target_layer: TileMapLayer, cell: Vector2i, tile_key: String) -> void:
	DwarfHoldTileService.place_tile(target_layer, cell, tile_key, TILE_ATLAS)

func _pick_base_tile(grid: Dictionary, x: int, y: int, cell: int) -> String:
	if cell == CELL_WATER:
		return "water"
	return DwarfHoldTileService.pick_base_tile(grid, x, y, cell, _door_cells, TILE_ATLAS)

func _is_hall_border_rock_cell(grid: Dictionary, x: int, y: int) -> bool:
	return DwarfHoldTileService.is_hall_border_rock_cell(grid, x, y)

func _building_type_for_cell(cell: Vector2i) -> String:
	return String(_latest_civic_building_type_map.get(cell, "workshop"))

func _pick_decor_tile(grid: Dictionary, x: int, y: int, cell: int, base_tile: String, house_decor_overrides: Dictionary) -> String:
	return DwarfHoldTileService.pick_decor_tile(grid, x, y, cell, base_tile, house_decor_overrides, _latest_civic_building_type_map, CIVIC_BUILDING_TYPES, _rng, _door_cells)


func _update_summary(grid: Dictionary, seed_text: String) -> void:
	var bounds := _find_bounds(grid)
	var hall_zones := int(_latest_zone_counts.get("halls", 0))
	var house_zones := int(_latest_zone_counts.get("houses", 0))
	var building_zones := int(_latest_zone_counts.get("buildings", 0))
	var plaza_zones := int(_latest_zone_counts.get("plazas", 0))
	var requested_halls := int(_latest_requested_zone_counts.get("halls", 0))
	var requested_houses := int(_latest_requested_zone_counts.get("houses", 0))
	var requested_buildings := int(_latest_requested_zone_counts.get("buildings", 0))
	var requested_plazas := int(_latest_requested_zone_counts.get("plazas", 0))
	var expected_npcs := int(ceil(float(_hold_state.selected_hold_population) / 10.0))

	var building_subtype_summary := _building_subtype_summary_text()
	city_summary.text = "Seed %s\nDepth: %d / %d\nBounds: %dx%d (origin %d, %d)\nHalls: %d/%d | Houses: %d/%d | Buildings: %d/%d | Plazas: %d/%d" % [
		seed_text,
		_hold_state.current_level_index + 1,
		maxi(_hold_state.generated_levels.size(), 1),
		bounds.size.x,
		bounds.size.y,
		bounds.position.x,
		bounds.position.y,
		hall_zones,
		requested_halls,
		house_zones,
		requested_houses,
		building_zones,
		requested_buildings,
		plaza_zones,
		requested_plazas
	]
	if expected_npcs > 0:
		var level_npc_target := _target_npcs_for_level(
			_hold_state.current_level_index,
			maxi(_hold_state.generated_levels.size(), 1)
		)
		city_summary.text += "\nHold Population: %d (target residents in-scene: %d at 10:1)" % [_hold_state.selected_hold_population, expected_npcs]
		city_summary.text += "\nBeds this level: %d (level resident target: %d)" % [_latest_bed_count, level_npc_target]
	if not building_subtype_summary.is_empty():
		city_summary.text += "\nBuilding Types: %s" % building_subtype_summary

func _update_hover_tooltip(mouse_position: Vector2) -> void:
	if city_layer.tile_set == null:
		_hide_hover_tooltip()
		return

	var hovered_cell := _cell_from_mouse_position(mouse_position)
	var hovered_layer := decor_layer
	if decor_layer.get_cell_source_id(hovered_cell) < 0:
		hovered_layer = city_layer
	if hovered_layer.get_cell_source_id(hovered_cell) < 0:
		_hide_hover_tooltip()
		return
	var tooltip_position := _clamp_tooltip_position(mouse_position + Vector2(16, 16))
	if tile_hover_tooltip.visible and hovered_cell == _hover_tooltip_cell and hovered_layer == _hover_tooltip_layer:
		tile_hover_tooltip.position = tooltip_position
		return

	var atlas_coords := hovered_layer.get_cell_atlas_coords(hovered_cell)
	var tile_name := _tile_name_from_atlas(atlas_coords)
	var zone_name := _zone_name_for_cell(hovered_cell)
	var tooltip_lines: PackedStringArray = []
	# A dwarf under the cursor introduces themselves, Dwarf Fortress style.
	var hovered_npc := _npc_state_at_cell(hovered_cell)
	if not hovered_npc.is_empty() and hovered_npc.has("identity"):
		var identity := hovered_npc.get("identity", {}) as Dictionary
		tooltip_lines.append(NpcIdentityService.summary_line(identity))
		for detail: String in NpcIdentityService.detail_lines(identity):
			tooltip_lines.append(detail)
		tooltip_lines.append("")
	tooltip_lines.append("Tile: %s" % tile_name)
	tooltip_lines.append("Zone: %s" % zone_name)
	var district_name := String(_latest_district_cell_map.get(hovered_cell, ""))
	if not district_name.is_empty():
		tooltip_lines.insert(0, "District: %s" % district_name)
	var subtype := _building_type_for_cell_or_empty(hovered_cell)
	if not subtype.is_empty():
		tooltip_lines.append("Subtype: %s" % _display_name_for_building_type(subtype))
		var flavor := String(BUILDING_SUBTYPE_FLAVOR.get(subtype, ""))
		if not flavor.is_empty():
			tooltip_lines.append(flavor)
	tile_hover_label.text = "\n".join(tooltip_lines)
	tile_hover_tooltip.reset_size()
	tile_hover_tooltip.position = _clamp_tooltip_position(mouse_position + Vector2(16, 16))
	tile_hover_tooltip.visible = true
	_hover_tooltip_cell = hovered_cell
	_hover_tooltip_layer = hovered_layer

func _hide_hover_tooltip() -> void:
	tile_hover_tooltip.visible = false
	_hover_tooltip_cell = Vector2i(2147483647, 2147483647)
	_hover_tooltip_layer = null

func _tile_name_from_atlas(atlas_coords: Vector2i) -> String:
	return DwarfHoldTileService.tile_name_from_atlas(atlas_coords, TILE_ATLAS)

func _zone_name_for_cell(cell: Vector2i) -> String:
	return DwarfHoldTileService.zone_name_for_cell(cell, _latest_grid, _latest_civic_building_type_map)

func _building_type_for_cell_or_empty(cell: Vector2i) -> String:
	return DwarfHoldTileService.building_type_for_cell_or_empty(cell, _latest_civic_building_type_map)

func _display_name_for_building_type(building_type: String) -> String:
	return DwarfHoldTileService.display_name_for_building_type(building_type)

func _building_subtype_summary_text() -> String:
	return DwarfHoldTileService.building_subtype_summary_text(_latest_civic_buildings_by_id)

func _clamp_tooltip_position(desired_position: Vector2) -> Vector2:
	var tooltip_size := tile_hover_tooltip.size
	var panel_size := city_panel.size
	return Vector2(
		clampf(desired_position.x, 0.0, maxf(panel_size.x - tooltip_size.x, 0.0)),
		clampf(desired_position.y, 0.0, maxf(panel_size.y - tooltip_size.y, 0.0))
	)

