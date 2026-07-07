extends SettlementSceneBase

const CELL_WATER := 5

@export var hall_zone_count_range := Vector2i(14, 22)
@export var housing_zone_count_range := Vector2i(80, 140)
@export var civic_building_zone_count_range := Vector2i(45, 95)
@export var plaza_zone_count_range := Vector2i(6, 14)
@export var tilesheet_path := "res://resources/images/dwarfhold/map.png"
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
@onready var lighting_layer: Node2D = %LightingLayer
@onready var global_darkness: CanvasModulate = %GlobalDarkness
@onready var fog_of_war: Sprite2D = %FogOfWar
@onready var actor_layer: Node2D = %ActorLayer
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

var _is_panning := false
var _pan_offset := Vector2.ZERO
var _map_origin_offset := Vector2.ZERO
var _door_cells: Dictionary = {}
var _latest_civic_buildings_by_id: Dictionary = {}
var _latest_district_labels: Array = []
var _latest_district_cell_map: Dictionary = {}
var _latest_floor_decor: Dictionary = {}
var _world_noise: Dictionary = {}
var _generated_chunks: Dictionary = {}
var _dug_cells: Dictionary = {}
var _applied_light_dim := -1.0
var _last_clock_stamp := -1
var _restoring_hold_diffs := false
var _last_player_chunk := Vector2i(2147483647, 2147483647)
var _world_seed_hash := 0
var _hold_market: Dictionary = {}
var _underdeep_sites: Array = []
var _sites_by_chunk: Dictionary = {}
var _player_inventory: Dictionary = {}
var _inventory_label: Label
var _creature_states: Array[Dictionary] = []
var _creature_texture: Texture2D
var _companion: Dictionary = {}
var _staff_cooldown := 0.0
var _gear_label: Label
var _inventory_screen: PlayerInventoryPanel
var _npc_inspection_card: NpcInspectionCard
var _player_hotbar: PlayerHotbar
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
var _torch_sprites: Dictionary = {}
## Streamed wild chunks currently resident, chunk coords -> true. The
## city core never appears here and is never evicted.
var _streamed_chunks: Dictionary = {}
var _discovery_chunks: Dictionary = {}
var _city_bounds := Rect2i()
var _player_glow: Sprite2D
var _glow_texture: Texture2D
var _torch_texture: Texture2D
var _bobber_texture: Texture2D
var _light_dim := 1.0
var _latest_bed_count := 0
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
var _hover_tooltip_npc := ""
var _hover_tooltip_layer: TileMapLayer
var _npc_states: Array[Dictionary] = []
var _settlement_factions: Array[Dictionary] = []
var _factions_label: RichTextLabel
var _faction_event_stamps: Dictionary = {}
var _furnishing_sprites: Array[Node2D] = []
var _furnishing_blocked_cells: Dictionary = {}
var _passable_atlas_set: Dictionary = {}
var _actor_passable_cache: Dictionary = {}
var _game_hour := 9.0
var _game_day := 1
var _calendar_start_year := 250
var _bed_cells: Array[Vector2i] = []
var _pending_player_spawn_cell := Vector2i(2147483647, 2147483647)

const PLAYER_MOVE_SPEED := 260.0
## Base values live in PlayerStatsService; the profession chosen at
## character creation shifts them per player.
var _player_max_hp := PlayerStatsService.BASE_MAX_HP
var _player_attack_damage := PlayerStatsService.BASE_ATTACK
var _player_satiety := PlayerStatsService.SATIETY_MAX
var _hunger_label: Label
var _current_stratum: Dictionary = DepthStrataService.SURFACE
var _furnishing_by_cell: Dictionary = {}
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
	_load_persistent_player_state()
	var scene_stamp: Dictionary = _world_settings_snapshot()
	scene_stamp["last_scene"] = "res://scenes/dwarf_hold_generation.tscn"
	_store_world_settings(scene_stamp)
	_update_clock_label()
	_setup_inventory_screen()
	_setup_hotbar()
	GameAudioService.play_music(self, "hold")
	_setup_inventory_label()
	_setup_hp_label()
	_setup_coins_label()
	_setup_factions_panel()
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
	_staff_cooldown = maxf(_staff_cooldown - delta, 0.0)
	_update_companion(delta)
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
	if absf(_light_dim - target) < 0.002:
		_light_dim = target
	# Only touch the layers while the dim level is actually moving.
	if not is_equal_approx(_light_dim, _applied_light_dim):
		_applied_light_dim = _light_dim
		var dim_color := Color(_light_dim, _light_dim, _light_dim, 1.0)
		city_layer.modulate = dim_color
		decor_layer.modulate = dim_color
		actor_layer.modulate = dim_color
	if _player_glow != null:
		_player_glow.visible = _light_dim < 0.95 and _player_sprite != null
		if _player_sprite != null:
			_player_glow.position = _player_sprite.position
	_update_player_turn_movement(delta)
	_update_npc_movement(delta)

func _advance_game_clock(delta: float) -> void:
	if minutes_per_game_day <= 0.0:
		return
	var delta_hours := delta * 24.0 / (minutes_per_game_day * 60.0)
	var hour_before := int(_game_hour)
	var day_before := _game_day
	_game_hour += delta_hours
	while _game_hour >= 24.0:
		_game_hour -= 24.0
		_game_day += 1
	# A frame spanning ~24h can land on the same integer hour a day on;
	# catch the day rollover so the hooks never skip a day.
	if int(_game_hour) != hour_before or _game_day != day_before:
		# Buffs and other clock-keyed state read the shared settings
		# clock; keep it honest while the scene runs.
		var clock_settings: Dictionary = _world_settings_snapshot()
		clock_settings["game_clock"] = {"hour": _game_hour, "day": _game_day}
		_store_world_settings(clock_settings)
		_refresh_player_stats_from_session()
		if _game_day != day_before:
			_advance_world_events()
	_advance_hunger(delta_hours)
	_advance_afflictions(delta_hours)
	_update_faction_events()
	_update_clock_label()

## A new day means new history: roll the shared world-event log forward
## and surface the freshest news on the status ticker.
func _advance_world_events() -> void:
	var settings: Dictionary = _world_settings_snapshot()
	if settings.is_empty():
		return
	var world_seed_text := str(settings.get("world_seed", seed_input.text.strip_edges()))
	var fresh_events: Array[Dictionary] = WorldEventsService.advance(settings, world_seed_text, _game_day)
	_store_world_settings(settings)
	for event: Dictionary in fresh_events:
		_set_save_status("News: " + String(event.get("text", "")), Color(0.75, 0.8, 0.95))

func _update_clock_label() -> void:
	if clock_label == null:
		return
	var hour := int(_game_hour)
	var minute := int((_game_hour - float(hour)) * 60.0)
	var clock_stamp := (_game_day * 24 + hour) * 60 + minute
	if clock_stamp == _last_clock_stamp:
		return
	_last_clock_stamp = clock_stamp
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
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_Q and not _is_text_input_focused():
		_handle_quick_drink_action()
		get_viewport().set_input_as_handled()
		return
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_I and not _is_text_input_focused():
		if _inventory_screen != null:
			_inventory_screen.toggle()
		get_viewport().set_input_as_handled()
		return
	if key_event != null and key_event.pressed and not key_event.echo and not _is_text_input_focused():
		var hotbar_index := _hotbar_index_for_keycode(key_event.keycode)
		if hotbar_index >= 0:
			_use_hotbar_slot(hotbar_index)
			get_viewport().set_input_as_handled()
			return
	# Movement keys are polled continuously in _update_player_turn_movement,
	# so held keys glide tile to tile with no tap-per-step.

func _on_back_button_pressed() -> void:
	SceneCacheService.request_change(self, OVERWORLD_SCENE_PATH)

func _on_save_game_button_pressed() -> void:
	# Slots, not the orphaned legacy file - the Load screen must see this.
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null:
		_set_save_status("Save unavailable", Color(0.95, 0.45, 0.45, 1.0))
		return
	var slot_id := String(game_session.call("get_current_slot")) if game_session.has_method("get_current_slot") else ""
	if slot_id.is_empty() or slot_id == SaveGameService.AUTOSAVE_SLOT:
		slot_id = SaveGameService.next_free_slot_id()
	var result: Error = SaveGameService.save_slot(self, slot_id)
	if result == OK:
		_set_save_status("Game saved to %s" % slot_id.replace("_", " "), Color(0.6, 0.9, 0.6, 1.0))
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

func _current_move_input_direction() -> Vector2i:
	return DwarfHoldUiInputHandler.current_move_input_direction()

## Picks the player's next tile: held movement keys rule (and cancel any
## click-path), then the click-path continues. Blocked diagonals slide
## along whichever axis is open, so walls never stall a held key.
func _start_next_player_step() -> void:
	var held := _current_move_input_direction()
	if held != Vector2i.ZERO and not _is_text_input_focused():
		_player_move_path.clear()
		if _try_move_player(held):
			return
		if held.x != 0 and held.y != 0:
			if _try_move_player(Vector2i(held.x, 0)):
				return
			var _slid := _try_move_player(Vector2i(0, held.y))
		return
	while not _player_move_path.is_empty():
		var next_cell := _player_move_path[0]
		if next_cell == _player_cell:
			_player_move_path.pop_front()
			continue
		if _is_cell_occupied_by_npc(next_cell):
			_player_move_path.clear()
			return
		if _try_move_player(next_cell - _player_cell):
			_player_move_path.pop_front()
		return

func _finish_idle_interactions() -> void:
	if not _player_move_path.is_empty():
		return
	if _player_pending_chest_interaction.x != 2147483647:
		if _is_player_adjacent_to_cell(_player_pending_chest_interaction):
			_handle_chest_click(_screen_position_from_cell(_player_pending_chest_interaction))
		_player_pending_chest_interaction = Vector2i(2147483647, 2147483647)

func _update_player_turn_movement(delta: float) -> void:
	if _player_sprite == null or not _player_control_enabled:
		_player_move_path.clear()
		_player_is_moving = false
		_player_pending_chest_interaction = Vector2i(2147483647, 2147483647)
		return

	if not _player_is_moving:
		_start_next_player_step()
		if not _player_is_moving:
			_finish_idle_interactions()
			return

	# Spend this frame's travel budget, flowing across tile boundaries so
	# held keys read as one continuous Core Keeper-style glide instead of
	# a step, a stall, and another step. Capped at one tile so a lag spike
	# can never skip the walker across trigger cells unchecked.
	var budget := minf(PLAYER_MOVE_SPEED * delta, float(tile_size.x))
	var crossed_tile := false
	while _player_is_moving and budget > 0.0:
		var remaining := _player_sprite.position.distance_to(_player_move_target_position)
		if remaining > budget:
			_player_sprite.position = _player_sprite.position.move_toward(_player_move_target_position, budget)
			break
		budget -= remaining
		_player_sprite.position = _player_move_target_position
		_player_cell = _player_move_target_cell
		_player_is_moving = false
		crossed_tile = true
		_close_out_of_range_popups()
		if _try_use_stairs_at_player_cell():
			_center_view_on_world_position(_player_sprite.position)
			return
		_start_next_player_step()
	_center_view_on_world_position(_player_sprite.position)
	if crossed_tile and not _latest_grid.is_empty():
		_update_shattered_visibility(_latest_grid)
		_refresh_lighting(_latest_grid)
	if not _player_is_moving:
		_finish_idle_interactions()

func _is_text_input_focused() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit

## Walking away slams the lid: the chest/trade popup only works within
## reach of its tile, so held keys can't shop from across the hold.
func _close_out_of_range_popups() -> void:
	if chest_popup == null or not chest_popup.visible:
		return
	var anchor := _trade_shop_cell if _is_trade_mode() else _selected_chest_cell
	if anchor.x == 2147483647:
		return
	var span := _player_cell - anchor
	if maxi(absi(span.x), absi(span.y)) > 6:
		_clear_chest_selection()

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
	if _passable_atlas_set.is_empty():
		for tile_key: String in PASSABLE_TILE_KEYS:
			var coords := TILE_ATLAS.get(tile_key, Vector2i(-1, -1)) as Vector2i
			if coords != Vector2i(-1, -1):
				_passable_atlas_set[coords] = true
	return _passable_atlas_set.has(atlas_coords)

func _is_passable_cell_for_actor(cell: Vector2i) -> bool:
	# NPCs test candidate cells every step, so verdicts are cached; any
	# tile write (digging, building, furnishing) invalidates the entry.
	var cached: Variant = _actor_passable_cache.get(cell)
	if cached != null:
		return bool(cached)
	var passable := _compute_passable_cell_for_actor(cell)
	_actor_passable_cache[cell] = passable
	return passable

func _compute_passable_cell_for_actor(cell: Vector2i) -> bool:
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
	# Old saves wore gear as flags; hang it on the paper doll once.
	var save_changed := GearService.ensure_equipment_migrated(settings, _player_inventory)
	if GearService.seed_default_hotbar(settings, _player_inventory):
		save_changed = true
	if save_changed:
		_store_world_settings(settings)
		_save_player_inventory()
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
	# Holds carry no generated details dict; the market derives from a
	# seeded stub of mountain exports (ore, ingots, gems, stone).
	_hold_market = SettlementEconomyService.settlement_market(SettlementEconomyService.hold_details_stub(_world_seed_hash), _world_seed_hash)
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
	_latest_civic_building_name_map = {}
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
	var stratum := DepthStrataService.stratum_for_level(level_index, level_count)
	var starmetal_cells: Array[Vector2i] = []
	if is_additional_layer:
		starmetal_cells = DepthStrataService.stamp_stratum_features(grid, floor_decor, stratum, _rng)
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
		"stair_cells": stair_cells,
		"starmetal_cells": starmetal_cells
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
	_latest_civic_building_name_map = _build_civic_building_name_lookup(_latest_civic_buildings_by_id, seed_input.text.strip_edges(), "dwarf")
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
	_streamed_chunks = {}
	var stored_bounds: Variant = level_data.get("city_bounds")
	if stored_bounds is Rect2i:
		_city_bounds = stored_bounds
	else:
		_city_bounds = _find_bounds(grid).grow(2)
		level_data["city_bounds"] = _city_bounds
	_hold_state.active_level_stairs = level_data.get("stair_cells", {}) as Dictionary

	# Chests keep their contents per level: sharing the level_data dict
	# means looting persists and revisits never reroll fresh loot.
	if not (level_data.get("chest_inventories") is Dictionary):
		level_data["chest_inventories"] = {}
	_chest_inventories = level_data.get("chest_inventories") as Dictionary
	_clear_chest_selection()
	_apply_hold_diffs_to_level(level_data, grid)
	# The previous level's furniture must not block this level's spawn
	# checks; _furnish_interiors rebuilds both maps right after.
	_furnishing_blocked_cells.clear()
	_furnishing_by_cell.clear()
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
	var stratum := DepthStrataService.stratum_for_level(_hold_state.current_level_index, level_count)
	_current_stratum = stratum
	depth_label.text = "Level %d / %d — %s" % [_hold_state.current_level_index + 1, level_count, String(stratum.get("name", ""))]
	var stratum_tint := stratum.get("tint", Color.WHITE) as Color
	city_layer.modulate = stratum_tint
	decor_layer.modulate = stratum_tint
	_populate_stratum_creatures(stratum)
	if not _hold_state.generated_levels.is_empty():
		_scatter_stratum_relics(stratum, _hold_state.generated_levels[_hold_state.current_level_index] as Dictionary)


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

func _render_city(grid: Dictionary, stair_cells: Dictionary = {}) -> void:
	if city_layer.tile_set == null:
		return
	city_layer.clear()
	decor_layer.clear()
	# Same clamp as the lighting: render the city and its surroundings,
	# let the chunk streamer redraw far wilds as the walker approaches.
	var bounds := _find_bounds(grid).grow(1)
	if _city_bounds.has_area():
		bounds = bounds.intersection(_city_bounds.grow(96))
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
		_actor_passable_cache.erase(stair_cell)
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

	# Streamed wilds can stretch the grid arbitrarily far; the fog image
	# must stay city-sized or one distant discovery balloons it to
	# gigabytes. Cells beyond the clamp simply go unmasked, exactly like
	# freshly streamed chunks always have.
	var lighting_full := _find_bounds(grid).grow(1)
	if _city_bounds.has_area():
		lighting_full = lighting_full.intersection(_city_bounds.grow(96))
	_lighting_bounds = lighting_full
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
			_backpack_slot_panels[i].tooltip_text += "\nSell for %d coins" % SettlementEconomyService.local_sell_price(item_name, _hold_market)

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
		Callable(self, "_update_city_layer_transform"),
		Callable(self, "_handle_player_right_click")
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
		_place_hover_tooltip(tile_hover_tooltip.position - city_panel.global_position)
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
	# A stair arrival chose its own spawn; only fresh entries (no pending
	# cell) get pulled to the Great Hall.
	var arrived_via_stairs := _pending_player_spawn_cell.x != 2147483647
	_pending_player_spawn_cell = Vector2i(2147483647, 2147483647)
	if not arrived_via_stairs:
		_relocate_player_to_city_heart(grid)
	# Lighting was initialized before the player existed; now that the
	# dwarf stands somewhere, punch their vision into the fog.
	_update_shattered_visibility(grid)
	_refresh_lighting(grid)
	_assign_npc_daily_lives(grid)
	_assign_npc_identities()
	_assign_npc_families()
	_assign_settlement_factions()
	SettlementAfflictionService.seed_afflictions(_npc_states, _rng)
	_apply_affliction_visuals()
	_apply_identity_appearances()
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
				_ensure_companion()
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
	_evict_far_chunks(player_chunk)

## Core Keeper rule: the world only exists near the player. Wild chunks
## more than EVICT_CHUNK_RADIUS out are dropped entirely - tiles, grid
## entries, decor, creatures - and rebuilt from seed plus the player's
## recorded diffs when walked back into. The city core is never evicted.
const EVICT_CHUNK_RADIUS := 4

## Sites and discoveries stamp structures that spill past their chunk;
## evicting any chunk they touch would tear holes in them.
func _chunk_neighborhood_has_stamp(chunk: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var neighbor := chunk + Vector2i(dx, dy)
			if _discovery_chunks.has(neighbor):
				return true
			if not (_sites_by_chunk.get(UndergroundWorldService.chunk_key(neighbor), []) as Array).is_empty():
				return true
	return false

func _append_district_label_once(label: Dictionary) -> void:
	var center: Variant = label.get("center", Vector2i.ZERO)
	var label_name := String(label.get("name", ""))
	for existing_variant: Variant in _latest_district_labels:
		var existing := existing_variant as Dictionary
		if String(existing.get("name", "")) == label_name and existing.get("center", Vector2i(-1, -1)) == center:
			return
	_latest_district_labels.append(label)

func _evict_far_chunks(player_chunk: Vector2i) -> void:
	var to_evict: Array[Vector2i] = []
	for chunk_variant: Variant in _streamed_chunks.keys():
		var chunk := chunk_variant as Vector2i
		if maxi(absi(chunk.x - player_chunk.x), absi(chunk.y - player_chunk.y)) > EVICT_CHUNK_RADIUS:
			to_evict.append(chunk)
	for chunk: Vector2i in to_evict:
		var rect: Rect2i = UndergroundWorldService.chunk_rect(chunk)
		if rect.intersects(_city_bounds):
			continue
		if _chunk_neighborhood_has_stamp(chunk):
			continue
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				city_layer.erase_cell(cell)
				decor_layer.erase_cell(cell)
				_latest_grid.erase(cell)
				_latest_floor_decor.erase(cell)
				_actor_passable_cache.erase(cell)
				var torch := _torch_sprites.get(cell) as Sprite2D
				if torch != null:
					torch.queue_free()
					_torch_sprites.erase(cell)
		for index in range(_creature_states.size() - 1, -1, -1):
			var state := _creature_states[index] as Dictionary
			var creature_cell := state.get("cell", Vector2i(2147483647, 0)) as Vector2i
			if rect.has_point(creature_cell):
				var sprite := state.get("sprite") as Sprite2D
				if sprite != null:
					sprite.queue_free()
				_creature_states.remove_at(index)
		_streamed_chunks.erase(chunk)
		_generated_chunks.erase(UndergroundWorldService.chunk_key(chunk))

## Walked back into an evicted area: the recorded torches get their
## sprites back.
func _respawn_torches_in_rect(rect: Rect2i) -> void:
	if _hold_state.generated_levels.is_empty():
		return
	var level_data := _hold_state.generated_levels[_hold_state.current_level_index] as Dictionary
	for torch_cell_variant: Variant in (level_data.get("torches", []) as Array):
		var cell := torch_cell_variant as Vector2i
		if rect.has_point(cell):
			_spawn_torch_at(cell)

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
				_append_district_label_once({"name": String(site.get("name", "")), "center": site.get("cell", Vector2i.ZERO), "wild": true})
				stamped_site = true
			var discovery: Dictionary = UndergroundWorldService.stamp_chunk_discovery(_latest_grid, _latest_floor_decor, chunk, _world_seed_hash)
			if not discovery.is_empty():
				discovery["wild"] = true
				_discovery_chunks[chunk] = true
				_append_district_label_once(discovery)
			var rect: Rect2i = UndergroundWorldService.generate_chunk(_latest_grid, _latest_floor_decor, chunk, _world_noise)
			_streamed_chunks[chunk] = true
			# A re-stamped site spills past the chunk; the player's edits
			# must win over the stamp across the whole spill.
			_apply_hold_diffs_to_rect(rect.grow(14) if stamped_site else rect)
			_render_world_rect(rect.grow(14 if stamped_site else 1))
			_respawn_torches_in_rect(rect)
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
## Chests, cabinets and bookcases can be searched once for whatever the
## owner left inside.
func _try_search_furnishing(cell: Vector2i) -> bool:
	if not _is_player_adjacent_to_cell(cell) and cell != _player_cell:
		return false
	var piece := String(_furnishing_by_cell.get(cell, ""))
	if piece.is_empty() or not DfFurnitureDefs.is_searchable(piece):
		return false
	var level_data := _hold_state.generated_levels[_hold_state.current_level_index] as Dictionary
	var searched := level_data.get("searched_cells", {}) as Dictionary
	if searched.has(cell):
		_set_save_status("Already ransacked.", Color(0.75, 0.75, 0.8, 1.0))
		return true
	searched[cell] = true
	level_data["searched_cells"] = searched
	var roll := _rng.randi_range(1, 100)
	var found := ""
	if roll <= 55:
		var coins := _rng.randi_range(2, 8)
		# Straight into the purse - a "Coins" pack item can't be spent.
		_adjust_coins(coins)
		found = "%d coins" % coins
	elif roll <= 70:
		_add_to_inventory("Mushrooms", _rng.randi_range(1, 2))
		found = "dried mushrooms"
	elif roll <= 82:
		_add_to_inventory("Old Tome", 1)
		found = "an old tome"
	elif roll <= 92:
		_add_to_inventory("Carved Curio", 1)
		found = "a carved curio"
	else:
		_add_to_inventory("Gem Shard", 1)
		found = "a gem shard!"
	_spawn_floating_text("Found %s" % found, _cell_center_position(cell), Color(0.95, 0.9, 0.6, 1.0))
	_set_save_status("You search the %s: %s." % [DfFurnitureDefs.display_name(piece).to_lower(), found], Color(0.9, 0.85, 0.6, 1.0))
	return true

## Working fires smelt starmetal ore into bars; the anvil forges bars
## into permanent gear: first a blade (+attack), then a plate (+max HP).
const FORGE_FIRE_PIECES := ["int_hearth_arch", "int_kiln_beehive"]

func _world_settings_snapshot() -> Dictionary:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings"):
		return {}
	return game_session.call("get_world_settings")

func _store_world_settings(settings: Dictionary) -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null and game_session.has_method("set_world_settings"):
		game_session.call("set_world_settings", settings)

## The workshops answer by station: a lit furnace smelts whatever ore
## the pack holds (richest first), the anvil walks the whole gear ladder
## in order, the clay pot brews potions from herbs and the hunt, and an
## open bookshelf reads runestones into enchants.
func _try_work_forge(cell: Vector2i) -> bool:
	if not _is_player_adjacent_to_cell(cell) and cell != _player_cell:
		return false
	var piece := String(_furnishing_by_cell.get(cell, ""))
	if FORGE_FIRE_PIECES.has(piece):
		var smelt: Dictionary = GearService.smelt_option(_player_inventory)
		if smelt.is_empty():
			_set_save_status("The furnace roars, hungry for ore: two of a kind smelt one bar.", Color(0.75, 0.8, 0.9, 1.0))
			return true
		_add_to_inventory(String(smelt.get("ore", "")), -int(smelt.get("count", 2)))
		_add_to_inventory(String(smelt.get("bar", "")), 1)
		GameAudioService.play_sfx(self, "forge")
		_spawn_floating_text(String(smelt.get("bar", "")), _cell_center_position(cell), Color(0.7, 0.85, 1.0, 1.0))
		_set_save_status("The fire flares: %s, hot from the mold." % String(smelt.get("bar", "")), Color(0.7, 0.85, 1.0, 1.0))
		return true
	if piece == "int_anvil":
		var settings: Dictionary = _world_settings_snapshot()
		var owned: Dictionary = GearService.owned_gear(settings, _player_inventory)
		var option: Dictionary = GearService.forge_option(owned, _player_inventory)
		if option.is_empty():
			var goal: Dictionary = GearService.next_forge_goal(owned)
			if goal.is_empty():
				_set_save_status("The anvil rests: every piece it knows is already yours.", Color(0.75, 0.8, 0.9, 1.0))
			else:
				_set_save_status("The anvil waits: %s asks %s." % [String(goal.get("name", "")), GearService.craft_costs_text(goal)], Color(0.75, 0.8, 0.9, 1.0))
			return true
		var costs := option.get("craft", {}) as Dictionary
		for cost_item: Variant in costs.keys():
			_add_to_inventory(String(cost_item), -int(costs[cost_item]))
		GearService.grant(settings, _player_inventory, String(option.get("name", "")))
		_store_world_settings(settings)
		_save_player_inventory()
		if _inventory_screen != null and _inventory_screen.visible:
			_inventory_screen.refresh()
		GameAudioService.play_sfx(self, "forge")
		_spawn_floating_text("%s!" % String(option.get("name", "")), _cell_center_position(cell), Color(0.7, 0.85, 1.0, 1.0))
		_set_save_status("You forge %s. The ladder climbs." % String(option.get("name", "")), Color(0.7, 0.85, 1.0, 1.0))
		_refresh_player_stats_from_session()
		_ensure_companion()
		return true
	if piece == "int_pot_clay":
		return _try_brew_potion()
	if piece.begins_with("int_bookshelf"):
		return _try_enchant()
	return false

func _try_brew_potion() -> bool:
	for potion_name: String in GearService.POTION_DEFS.keys():
		var recipe := (GearService.POTION_DEFS[potion_name] as Dictionary).get("brew", {}) as Dictionary
		var brewable := true
		for herb_variant: Variant in recipe.keys():
			if int(_player_inventory.get(String(herb_variant), 0)) < int(recipe[herb_variant]):
				brewable = false
				break
		if not brewable:
			continue
		for herb_variant: Variant in recipe.keys():
			_add_to_inventory(String(herb_variant), -int(recipe[herb_variant]))
		_add_to_inventory(potion_name, 1)
		GameAudioService.play_sfx(self, "drink")
		_set_save_status("The pot bubbles: %s, corked and ready (Q to drink)." % potion_name, Color(0.75, 0.9, 0.75, 1.0))
		return true
	_set_save_status("The pot waits for makings — a Healing Potion asks 1 Scarlet Blossom and 2 Mushrooms.", Color(0.75, 0.8, 0.9, 1.0))
	return true

func _try_enchant() -> bool:
	if int(_player_inventory.get("Runestone", 0)) < 1:
		_set_save_status("The open book hums — bring a Runestone and %d coins to bind an enchant." % GearService.ENCHANT_COIN_COST, Color(0.75, 0.8, 0.9, 1.0))
		return true
	if _player_coins < GearService.ENCHANT_COIN_COST:
		_set_save_status("The binding asks %d coins alongside the stone." % GearService.ENCHANT_COIN_COST, Color(0.95, 0.75, 0.45, 1.0))
		return true
	_add_to_inventory("Runestone", -1)
	_adjust_coins(-GearService.ENCHANT_COIN_COST)
	var settings: Dictionary = _world_settings_snapshot()
	var line: String = GearService.apply_runestone(settings, _rng)
	_store_world_settings(settings)
	GameAudioService.play_sfx(self, "enchant")
	_set_save_status(line, Color(0.8, 0.75, 0.95, 1.0))
	_refresh_player_stats_from_session()
	return true

func _refresh_player_stats_from_session() -> void:
	var stats := PlayerStatsService.for_session(self)
	_player_max_hp = float(stats.get("max_hp", _player_max_hp))
	_player_attack_damage = int(stats.get("attack", _player_attack_damage))
	_player_hp = minf(_player_hp, _player_max_hp)
	_update_hp_label()
	_update_gear_label()

func _update_gear_label() -> void:
	if _gear_label == null:
		return
	var loadout := PlayerStatsService.for_session(self).get("loadout", {}) as Dictionary
	_gear_label.text = GearService.loadout_line(loadout, int(_player_inventory.get("Arrows", 0)))

## The inventory screen (I): paper-doll equipment beside the backpack.
func _setup_inventory_screen() -> void:
	if chest_popup == null:
		return
	_inventory_screen = PlayerInventoryPanel.new()
	_inventory_screen.setup(
		Callable(self, "_world_settings_snapshot"),
		Callable(self, "_store_world_settings"),
		func() -> Dictionary: return _player_inventory,
		Callable(self, "_on_equipment_changed"),
		Callable(self, "_inventory_screen_context")
	)
	chest_popup.get_parent().add_child(_inventory_screen)
	_npc_inspection_card = NpcInspectionCard.new()
	chest_popup.get_parent().add_child(_npc_inspection_card)
	# UI must outdraw the world: furnishing sprites carry z 8-14 and
	# speech bubbles z 40 in the same canvas, and z_index beats tree
	# order - without this, pots and stoves render over open menus.
	_inventory_screen.z_index = 50
	_npc_inspection_card.z_index = 50
	chest_popup.z_index = 50
	if tile_hover_tooltip != null:
		tile_hover_tooltip.z_index = 50

## Live scene state for the character-sheet columns; the panel reads
## everything else from the session stores.
func _inventory_screen_context() -> Dictionary:
	var discovery_count := 0
	for label_variant: Variant in _latest_district_labels:
		if label_variant is Dictionary and bool((label_variant as Dictionary).get("wild", false)):
			discovery_count += 1
	return {
		"hp": _player_hp,
		"max_hp": _player_max_hp,
		"satiety": _player_satiety,
		"coins": _player_coins,
		"game_day": _game_day,
		"game_hour": _game_hour,
		"calendar_start_year": _calendar_start_year,
		"place_name": "Level %d — %s" % [_hold_state.current_level_index + 1, String(_current_stratum.get("name", "the hold"))],
		"factions": _settlement_factions,
		"companion_attack": int(_companion.get("attack", 0)),
		"discoveries": discovery_count
	}

func _on_equipment_changed() -> void:
	_refresh_player_stats_from_session()
	_update_inventory_label()
	_save_player_inventory()
	if _player_hotbar != null:
		_player_hotbar.refresh()

func _setup_hotbar() -> void:
	if chest_popup == null:
		return
	_player_hotbar = PlayerHotbar.new()
	_player_hotbar.setup(
		Callable(self, "_world_settings_snapshot"),
		func() -> Dictionary: return _player_inventory,
		Callable(self, "_use_hotbar_slot")
	)
	chest_popup.get_parent().add_child(_player_hotbar)
	_player_hotbar.z_index = 50
	_player_hotbar.refresh()
	_player_hotbar.reposition.call_deferred()

func _hotbar_index_for_keycode(keycode: int) -> int:
	if keycode >= KEY_1 and keycode <= KEY_9:
		return keycode - KEY_1
	if keycode == KEY_0:
		return 9
	return -1

## The quick keys: potions drink, food eats, tools report themselves.
func _use_hotbar_slot(index: int) -> void:
	var settings: Dictionary = _world_settings_snapshot()
	var bindings: Array = GearService.hotbar_bindings(settings)
	var item_name := String(bindings[index]) if index < bindings.size() else ""
	if item_name.is_empty():
		_set_save_status("Hotbar %d is empty — bind items from the pack (I)." % [(index + 1) % 10], Color(0.8, 0.8, 0.8, 1.0))
		return
	if _player_hotbar != null:
		_player_hotbar.flash(index)
	if int(_player_inventory.get(item_name, 0)) < 1:
		_set_save_status("Out of %s." % item_name, Color(0.95, 0.75, 0.45, 1.0))
		return
	if GearService.POTION_DEFS.has(item_name):
		_drink_potion(item_name)
		return
	if ItemDefsService.is_edible(item_name):
		_eat_item(item_name)
		return
	_set_save_status("%s ×%d in the pack." % [item_name, int(_player_inventory.get(item_name, 0))], Color(0.8, 0.8, 0.8, 1.0))

func _try_harvest_decor(cell: Vector2i) -> bool:
	if not _is_player_adjacent_to_cell(cell):
		return false
	if decor_layer.get_cell_source_id(cell) < 0:
		return false
	var atlas := decor_layer.get_cell_atlas_coords(cell)
	if atlas == TILE_ATLAS.get("stone", Vector2i(-1000, -1000)):
		decor_layer.erase_cell(cell)
		_actor_passable_cache.erase(cell)
		_latest_floor_decor.erase(cell)
		_record_hold_edit("decor_erased", cell)
		if _current_level_starmetal_cells().has(cell):
			_add_to_inventory("Starmetal Ore", _rng.randi_range(1, 2))
			_spawn_floating_text("Starmetal!", _cell_center_position(cell), Color(0.65, 0.85, 1.0, 1.0))
			_set_save_status("You pry starmetal from the living rock.", Color(0.7, 0.85, 1.0, 1.0))
			return true
		var vein_drop := _roll_weighted_drop(_current_stratum.get("ore_drops", ORE_VEIN_DROPS) as Array)
		_add_to_inventory(
			String(vein_drop.get("name", "Iron Ore")),
			_rng.randi_range(int(vein_drop.get("min", 1)), int(vein_drop.get("max", 2)))
		)
		return true
	if atlas == TILE_ATLAS.get("mushroom_wild", Vector2i(-1000, -1000)) or atlas == TILE_ATLAS.get("mushroom_crop_wild", Vector2i(-1000, -1000)) or atlas == TILE_ATLAS.get("mushroom_crops", Vector2i(-1000, -1000)):
		decor_layer.erase_cell(cell)
		_actor_passable_cache.erase(cell)
		_latest_floor_decor.erase(cell)
		_record_hold_edit("decor_erased", cell)
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
	_record_hold_edit("torches", _player_cell)
	_spawn_torch_at(_player_cell)
	_set_save_status("Torch placed", Color(0.95, 0.85, 0.55, 1.0))

func _spawn_torch_at(cell: Vector2i) -> void:
	if _torch_sprites.has(cell):
		return
	var torch := Sprite2D.new()
	if _torch_texture == null:
		_torch_texture = _create_torch_texture()
	torch.texture = _torch_texture
	torch.centered = true
	torch.position = _cell_center_position(cell)
	torch.z_index = 14
	lighting_layer.add_child(torch)
	var glow := _create_glow_sprite(5.0)
	glow.position = Vector2.ZERO
	torch.add_child(glow)
	_torch_sprites[cell] = torch

func _clear_torch_sprites() -> void:
	for torch_variant: Variant in _torch_sprites.values():
		var torch := torch_variant as Sprite2D
		if torch != null:
			torch.queue_free()
	_torch_sprites = {}

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
		var hint := SettlementEconomyService.market_hint_line(_hold_market)
		section_label.text = "Wares for sale" if hint.is_empty() else "Wares for sale — %s" % hint
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
		_chest_slot_panels[i].tooltip_text += "\nBuy for %d coins" % SettlementEconomyService.local_buy_price(item_name, _price_scale(), _hold_market)
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
	var price := SettlementEconomyService.local_buy_price(item_name, _price_scale(), _hold_market)
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
	var price := SettlementEconomyService.local_sell_price(item_name, _hold_market)
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
## Every citizen wears their own face: composed DF layers seeded from
## their identity. Identical rolls share one texture.
func _apply_identity_appearances() -> void:
	var texture_cache: Dictionary = {}
	for state_variant: Variant in _npc_states:
		var state := state_variant as Dictionary
		var identity := state.get("identity", {}) as Dictionary
		if identity.is_empty():
			continue
		var sprite := state.get("sprite") as Sprite2D
		if sprite == null:
			continue
		var layers := NpcIdentityService.appearance_for_identity(identity, "dwarf")
		var cache_key := str(layers)
		if not texture_cache.has(cache_key):
			texture_cache[cache_key] = DwarfSpriteComposer.compose(layers)
		sprite.texture = texture_cache[cache_key]
		sprite.region_enabled = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(
			float(tile_size.x) / 32.0,
			float(tile_size.y) / 32.0
		) * float(layers.get("body_scale", 1.0))
		state["composed"] = true

func _assign_npc_identities() -> void:
	var used_names: Dictionary = {}
	for state: Dictionary in _npc_states:
		var role_title := String(ROLE_TITLES.get(int(state.get("role", 0)), "Dwarf"))
		var identity: Dictionary = NpcIdentityService.generate(_rng, role_title, "dwarf")
		# Nobody shares a full name: spouse/parent/faction references are
		# by name, so collisions would tangle the whole census.
		for _reroll in 8:
			if not used_names.has(String(identity.get("name", ""))):
				break
			identity = NpcIdentityService.generate(_rng, role_title, "dwarf")
		if used_names.has(String(identity.get("name", ""))):
			identity["name"] = "%s the Younger" % String(identity.get("name", ""))
		used_names[String(identity.get("name", ""))] = true
		state["identity"] = identity
		state["npc_name"] = String(identity.get("name", "A dwarf"))

## The hold's guilds and cults: rolled per generation from the seeded
## rng, recruited from the identity roster, and listed in the sidebar.
## Members answer their faction's meeting bell through the scheduler.
## Kinship: couples share a surname, a roof and usually an altar; the
## young are raised as their children. Runs before faces are composed
## so adopted surnames reshape the family resemblance too.
func _assign_npc_families() -> void:
	var family_stats := SettlementFamilyService.build_families(_npc_states, "dwarf", _rng)
	print("[%s] families: %d couples, %d children" % [name, int(family_stats.get("couples", 0)), int(family_stats.get("children_placed", 0))])

func _assign_settlement_factions() -> void:
	_faction_event_stamps.clear()
	var building_cells_by_type: Dictionary = {}
	for building_cell_variant: Variant in _latest_civic_building_type_map.keys():
		var building_type := String(_latest_civic_building_type_map[building_cell_variant])
		if not building_cells_by_type.has(building_type):
			building_cells_by_type[building_type] = []
		(building_cells_by_type[building_type] as Array).append(building_cell_variant)
	_settlement_factions = SettlementFactionService.generate_factions(
		"dwarf", _hold_state.selected_hold_population, building_cells_by_type, _rng
	)
	SettlementFactionService.assign_members(_settlement_factions, _npc_states, Callable(self, "_is_npc_walkable_cell"), _rng)
	_update_factions_panel()

func _setup_factions_panel() -> void:
	var controls := get_node_or_null("Margin/Layout/Controls")
	if controls == null:
		return
	_factions_label = RichTextLabel.new()
	_factions_label.bbcode_enabled = true
	_factions_label.fit_content = true
	_factions_label.scroll_active = false
	_factions_label.add_theme_font_size_override("normal_font_size", 12)
	_factions_label.add_theme_font_size_override("bold_font_size", 12)
	_factions_label.add_theme_font_size_override("italics_font_size", 11)
	controls.add_child(_factions_label)
	var legend := controls.get_node_or_null("ZoneLegend")
	if legend != null:
		controls.move_child(_factions_label, legend.get_index() + 1)

func _update_factions_panel() -> void:
	if _factions_label != null:
		_factions_label.text = SettlementFactionService.sidebar_bbcode(_settlement_factions)

## When a meeting breaks up, word of what the faction did gets out -
## once per faction per day, and only if the player is around to hear.
func _update_faction_events() -> void:
	for faction: Dictionary in _settlement_factions:
		var since := fposmod(_game_hour - float(faction.get("meeting_hour", 20.0)), 24.0)
		if since < SettlementFactionService.MEETING_DURATION_HOURS or since > SettlementFactionService.MEETING_DURATION_HOURS + 1.0:
			continue
		var stamp := "%s|%d" % [String(faction.get("id", "")), _game_day]
		if _faction_event_stamps.has(stamp):
			continue
		_faction_event_stamps[stamp] = true
		var line := SettlementFactionService.meeting_event_line(faction, _rng)
		if not line.is_empty():
			_set_save_status(line, Color(0.8, 0.75, 0.9, 1.0))

func _show_npc_dialogue(state: Dictionary) -> void:
	var role_title := String(ROLE_TITLES.get(int(state.get("role", 0)), "Dwarf"))
	if not state.has("identity"):
		state["identity"] = NpcIdentityService.generate(_rng, role_title, "dwarf")
		state["npc_name"] = String((state["identity"] as Dictionary).get("name", "A dwarf"))
	var identity := state.get("identity", {}) as Dictionary
	# Sworn members talk about their faction, others gossip about the
	# guilds, and everyone still has personal news and map rumors.
	var line: String
	var faction_roll := _rng.randf()
	if int(state.get("role", 0)) == ROLE_GOLDSMITH and _rng.randf() < 0.4:
		# The hold's traders talk shop: what goes cheap here, what pays.
		line = SettlementEconomyService.dialogue_line(role_title, SettlementEconomyService.merchant_market_line(_hold_market, _rng), _rng)
	elif state.has("faction_name") and faction_roll < 0.35:
		line = SettlementEconomyService.dialogue_line(role_title, SettlementFactionService.member_line(state, _rng), _rng)
	elif faction_roll < 0.5 and not _settlement_factions.is_empty():
		line = SettlementEconomyService.dialogue_line(role_title, SettlementFactionService.faction_rumor(_settlement_factions, _rng), _rng)
	elif _rng.randf() < 0.4:
		line = SettlementEconomyService.dialogue_line(role_title, NpcIdentityService.personal_line(identity, _rng), _rng)
	else:
		# World news travels even underground: sometimes the gossip is
		# about far-off wars and caravans instead of the local deeps.
		var rumor := ""
		if _rng.randf() < 0.4:
			rumor = WorldEventsService.rumor_from_events(_world_settings_snapshot(), _game_day, _rng)
		if rumor.is_empty():
			rumor = SettlementEconomyService.rumor_from_labels(
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
			_record_hold_edit("grid_edits", cell, CELL_ROCK)
			_render_world_rect(Rect2i(cell - Vector2i(2, 2), Vector2i(5, 5)))
			if _lighting_enabled:
				_update_shattered_visibility(_latest_grid)
				_refresh_lighting(_latest_grid)
		"floor":
			if zone != CELL_HALL:
				_set_save_status("Paving needs bare cavern floor", Color(0.95, 0.75, 0.45, 1.0))
				return true
			_latest_grid[cell] = CELL_PLAZA
			_record_hold_edit("grid_edits", cell, CELL_PLAZA)
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
			_record_hold_edit("decor_edits", cell, tile_key)
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
	if _bobber_texture == null:
		_bobber_texture = _create_bobber_texture()
	bobber.texture = _bobber_texture
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
## Q: knock back a potion. Heals wait for wounds; buffs go down whenever.
func _handle_quick_drink_action() -> void:
	for potion_name: String in GearService.POTION_DEFS.keys():
		if int(_player_inventory.get(potion_name, 0)) < 1:
			continue
		var def := GearService.POTION_DEFS[potion_name] as Dictionary
		if def.has("heal") and _player_hp >= _player_max_hp:
			continue
		_drink_potion(potion_name)
		return
	_set_save_status("No potions in the pack. Herbalists sell them; a clay pot brews them.", Color(0.8, 0.8, 0.8, 1.0))

func _drink_potion(potion_name: String) -> void:
	if int(_player_inventory.get(potion_name, 0)) < 1:
		return
	var settings: Dictionary = _world_settings_snapshot()
	settings["game_clock"] = {"hour": _game_hour, "day": _game_day}
	var result: Dictionary = GearService.drink(settings, potion_name, float(_game_day) * 24.0 + _game_hour)
	_store_world_settings(settings)
	_add_to_inventory(potion_name, -1)
	GameAudioService.play_sfx(self, "drink")
	if result.has("heal"):
		_player_hp = minf(_player_hp + float(int(result.get("heal", 0))), _player_max_hp)
		_update_hp_label()
		_set_save_status("You drink the %s (+%d HP)." % [potion_name, int(result.get("heal", 0))], Color(0.9, 0.6, 0.6, 1.0))
	else:
		_refresh_player_stats_from_session()
		_set_save_status("You drink the %s — %s hums in your blood." % [potion_name, String(result.get("buff", ""))], Color(0.8, 0.75, 0.95, 1.0))

func _handle_quick_eat_action() -> void:
	if _player_hp >= _player_max_hp and _player_satiety > PlayerStatsService.SATIETY_MAX * 0.9:
		_set_save_status("You're at full health and well fed", Color(0.7, 0.9, 0.7, 1.0))
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
	if _player_hp >= _player_max_hp and _player_satiety > PlayerStatsService.SATIETY_MAX * 0.9:
		_set_save_status("You're at full health and well fed", Color(0.7, 0.9, 0.7, 1.0))
		return
	var heal := ItemDefsService.heal_amount(item_name)
	_add_to_inventory(item_name, -1)
	_player_hp = minf(_player_hp + float(heal), _player_max_hp)
	_player_satiety = clampf(_player_satiety + float(heal) * PlayerStatsService.SATIETY_PER_HEAL_POINT, 0.0, PlayerStatsService.SATIETY_MAX)
	PlayerStatsService.save_satiety(self, _player_satiety)
	_update_hp_label()
	_update_hunger_label()
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
	CompanionService.despawn(_companion)
	_companion = {}

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

func _current_level_starmetal_cells() -> Array:
	if _hold_state.generated_levels.is_empty():
		return []
	var level_data := _hold_state.generated_levels[_hold_state.current_level_index] as Dictionary
	return level_data.get("starmetal_cells", []) as Array

## Deep levels are populated on arrival from the stratum's roster; the
## starmetal veins come guarded by the deep's strongest.
## Abandoned works of older delvers: minecarts, ladders, crocks and the
## like, scattered once per level and re-placed identically on revisits.
func _scatter_stratum_relics(stratum: Dictionary, level_data: Dictionary) -> void:
	if _hold_state.current_level_index == 0:
		return
	var relic_pool := stratum.get("relic_pieces", []) as Array
	if relic_pool.is_empty():
		return
	var placements_variant: Variant = level_data.get("relic_placements")
	var placements: Array = []
	if placements_variant is Array:
		placements = placements_variant as Array
	else:
		# Stairs must stay walkable: a blocking relic on the only up-stair
		# would seal the level.
		var stair_cells := {}
		for stair_variant: Variant in (level_data.get("stair_cells", {}) as Dictionary).values():
			stair_cells[stair_variant] = true
		var hall_cells: Array[Vector2i] = []
		for cell_variant: Variant in _latest_grid.keys():
			if int(_latest_grid[cell_variant]) == CELL_HALL and not _latest_floor_decor.has(cell_variant) and not stair_cells.has(cell_variant):
				hall_cells.append(cell_variant as Vector2i)
		if not hall_cells.is_empty():
			for _relic in range(_rng.randi_range(6, 12)):
				placements.append({
					"piece": String(relic_pool[_rng.randi_range(0, relic_pool.size() - 1)]),
					"cell": hall_cells[_rng.randi_range(0, hall_cells.size() - 1)]
				})
		level_data["relic_placements"] = placements
	var typed: Array[Dictionary] = []
	for placement_variant: Variant in placements:
		typed.append(placement_variant as Dictionary)
	_apply_furnishing_placements(typed)

func _populate_stratum_creatures(stratum: Dictionary) -> void:
	if _hold_state.current_level_index == 0:
		return
	var slots := stratum.get("creature_slots", []) as Array
	if slots.is_empty():
		return
	var hall_cells: Array[Vector2i] = []
	for cell_variant: Variant in _latest_grid.keys():
		if int(_latest_grid[cell_variant]) == CELL_HALL:
			hall_cells.append(cell_variant as Vector2i)
	if hall_cells.is_empty():
		return
	var spawn_count := clampi(3 + _hold_state.current_level_index, 3, 8)
	for _spawn in range(spawn_count):
		if _creature_states.size() >= CREATURE_CAP:
			break
		var cell := hall_cells[_rng.randi_range(0, hall_cells.size() - 1)]
		if Vector2(cell - _player_cell).length() < 12.0:
			continue
		_spawn_creature_at(cell, int(slots[_rng.randi_range(0, slots.size() - 1)]))
	for starmetal_cell_variant: Variant in _current_level_starmetal_cells():
		if _creature_states.size() >= CREATURE_CAP:
			break
		var guard_cell := (starmetal_cell_variant as Vector2i) + Vector2i(_rng.randi_range(-2, 2), _rng.randi_range(-2, 2))
		if _is_walkable_cell(guard_cell):
			_spawn_creature_at(guard_cell, int(slots[slots.size() - 1]))

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
	return CreatureCombatService.step_toward(from_cell, target_cell, Callable(self, "_creature_can_step_to"))

func _direction_between_cells(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	return CreatureCombatService.direction_between_cells(from_cell, to_cell)

func _set_creature_anim(state: Dictionary, anim_name: String) -> void:
	CreatureCombatService.set_creature_anim(state, anim_name)

func _animate_creature(state: Dictionary, sprite: Sprite2D, def: Dictionary) -> void:
	CreatureCombatService.animate_creature(state, sprite, def)

func _attack_creature(creature_index: int) -> void:
	if _player_attack_timer > 0.0:
		return
	_player_attack_timer = PLAYER_ATTACK_COOLDOWN
	GameAudioService.play_sfx(self, "swing")
	_hurt_creature(creature_index, _player_attack_damage)

## Shared blade-edge for the player, the bow, the staff and the loyal
## sporeling: damage, loot, and the dying animation.
func _hurt_creature(creature_index: int, damage: int) -> void:
	if creature_index < 0 or creature_index >= _creature_states.size():
		return
	var state := _creature_states[creature_index]
	if bool(state.get("dying", false)):
		return
	var def: Dictionary = UndergroundCreatureService.CREATURE_DEFS[int(state.get("def_index", 0))]
	var sprite := state.get("sprite") as Sprite2D
	state["hp"] = int(state.get("hp", 1)) - damage
	GameAudioService.play_sfx(self, "hit")
	if sprite != null:
		_flash_sprite(sprite, Color(1.0, 0.45, 0.45, 1.0))
		_spawn_floating_text("-%d" % damage, sprite.position, Color(1.0, 0.85, 0.5, 1.0))
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

## Reaching weapons. The staff bursts over a knot of beasts on its own
## cooldown; the bow spends an arrow a shot. Melee stays king up close.
func _try_ranged_attack(creature_index: int, cell: Vector2i) -> bool:
	var distance := maxi(absi(cell.x - _player_cell.x), absi(cell.y - _player_cell.y))
	var stats: Dictionary = PlayerStatsService.for_session(self)
	var loadout := stats.get("loadout", {}) as Dictionary
	var staff := loadout.get("staff", {}) as Dictionary
	if not staff.is_empty() and distance <= 3 and _staff_cooldown <= 0.0:
		_staff_cooldown = float(staff.get("cooldown", 9.0))
		var radius := int(staff.get("radius", 1))
		var burst := int(stats.get("attack", 2)) + int(staff.get("attack", 1))
		GameAudioService.play_sfx(self, "magic")
		_spawn_floating_text("✦", _cell_center_position(cell), Color(0.8, 0.6, 1.0, 1.0))
		for index in range(_creature_states.size() - 1, -1, -1):
			var creature_cell := _creature_states[index].get("cell", Vector2i(9999, 9999)) as Vector2i
			if maxi(absi(creature_cell.x - cell.x), absi(creature_cell.y - cell.y)) <= radius:
				_hurt_creature(index, burst)
		return true
	var bow := loadout.get("bow", {}) as Dictionary
	if not bow.is_empty() and distance <= int(bow.get("range", 4)):
		if int(_player_inventory.get("Arrows", 0)) < 1:
			_set_save_status("Your quiver is empty — tinkers and peddlers sell Arrows.", Color(0.95, 0.75, 0.45, 1.0))
			return true
		if _player_attack_timer > 0.0:
			return true
		_player_attack_timer = PLAYER_ATTACK_COOLDOWN
		_add_to_inventory("Arrows", -1)
		GameAudioService.play_sfx(self, "bow")
		_spawn_arrow_flight(_player_cell, cell)
		_hurt_creature(creature_index, int(stats.get("attack", 2)) + int(bow.get("attack", 0)))
		return true
	return false

func _spawn_arrow_flight(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var arrow_image := Image.create(8, 2, false, Image.FORMAT_RGBA8)
	arrow_image.fill(Color(0.85, 0.78, 0.6, 1.0))
	var arrow := Sprite2D.new()
	arrow.texture = ImageTexture.create_from_image(arrow_image)
	arrow.position = _cell_center_position(from_cell)
	var target: Vector2 = _cell_center_position(to_cell)
	arrow.rotation = (target - arrow.position).angle()
	arrow.z_index = 20
	actor_layer.add_child(arrow)
	var tween := create_tween()
	tween.tween_property(arrow, "position", target, 0.14)
	tween.tween_callback(arrow.queue_free)

## The Beast Charm's sporeling: spawned while the charm is owned, fights
## whatever the dark sends, burrows home if left behind.
func _ensure_companion() -> void:
	if not _companion.is_empty() or _player_sprite == null or _creature_texture == null:
		return
	var loadout := PlayerStatsService.for_session(self).get("loadout", {}) as Dictionary
	var charm := loadout.get("charm", {}) as Dictionary
	if charm.is_empty():
		return
	_companion = CompanionService.spawn(charm, _creature_texture, _player_cell, actor_layer, Callable(self, "_cell_center_position"), tile_size)
	if not _companion.is_empty():
		_set_save_status("Something small and loyal pads out of the dark to walk with you.", Color(0.75, 0.92, 0.75, 1.0))

func _update_companion(delta: float) -> void:
	if _companion.is_empty() or _player_sprite == null:
		return
	CompanionService.update(
		delta, _companion, _player_cell, _creature_states,
		Callable(self, "_creature_can_step_to_from_companion"),
		Callable(self, "_cell_center_position"),
		Callable(self, "_hurt_creature")
	)

func _creature_can_step_to_from_companion(cell: Vector2i) -> bool:
	return bool(_creature_can_step_to(cell))

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
	_player_hp = _player_max_hp
	var lost_coins := _player_coins / 2
	if lost_coins > 0:
		_adjust_coins(-lost_coins)
		if _player_sprite != null:
			_spawn_floating_text("-%d coins" % lost_coins, _player_sprite.position, Color(0.95, 0.8, 0.4, 1.0))
	_save_player_inventory()
	_update_hp_label()
	_player_move_path.clear()
	_player_is_moving = false
	if _latest_district_labels.is_empty():
		# Deep levels have no Great Hall to wake in - climb the walker
		# back to the city level instead of reviving them mid-melee.
		call_deferred("_show_level", 0)
	else:
		_relocate_player_to_city_heart(_latest_grid)
	_set_save_status("Slain by %s — you wake back in the hold" % source_name, Color(0.95, 0.5, 0.5, 1.0))

## The hold is home: standing on city ground slowly mends your wounds -
## as long as there's food in your belly.
func _update_player_regen(delta: float) -> void:
	if _player_sprite == null or _player_hp >= _player_max_hp:
		return
	if _player_satiety <= PlayerStatsService.SATIETY_HUNGRY_THRESHOLD:
		return
	if _latest_district_cell_map.is_empty() or _latest_district_cell_map.has(_player_cell):
		_player_hp = minf(_player_hp + CITY_REGEN_PER_SECOND * delta, _player_max_hp)
		_update_hp_label()

func _advance_hunger(delta_hours: float) -> void:
	if delta_hours <= 0.0:
		return
	var was_starving := _player_satiety <= 0.0
	_player_satiety = clampf(_player_satiety - delta_hours * PlayerStatsService.SATIETY_DRAIN_PER_GAME_HOUR, 0.0, PlayerStatsService.SATIETY_MAX)
	if _player_satiety <= 0.0:
		if not was_starving:
			_set_save_status("Your stomach gnaws at you — find food!", Color(0.95, 0.6, 0.4, 1.0))
		_player_hp = maxf(_player_hp - delta_hours * PlayerStatsService.STARVATION_DAMAGE_PER_GAME_HOUR, 0.0)
		_update_hp_label()
		if _player_hp <= 0.0:
			_handle_player_death("starvation")
			_player_satiety = PlayerStatsService.SATIETY_MAX * 0.3
	_update_hunger_label()

func _setup_hp_label() -> void:
	var controls := get_node_or_null("Margin/Layout/Controls")
	if controls == null:
		return
	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 13)
	controls.add_child(_hp_label)
	_hunger_label = Label.new()
	_hunger_label.add_theme_font_size_override("font_size", 13)
	controls.add_child(_hunger_label)
	_gear_label = Label.new()
	_gear_label.add_theme_font_size_override("font_size", 12)
	_gear_label.modulate = Color(0.85, 0.88, 0.95, 1.0)
	controls.add_child(_gear_label)
	var clock := controls.get_node_or_null("ClockLabel")
	if clock != null:
		controls.move_child(_hp_label, clock.get_index() + 1)
		controls.move_child(_hunger_label, clock.get_index() + 2)
		controls.move_child(_gear_label, clock.get_index() + 3)
	_update_hp_label()
	_update_hunger_label()
	_update_gear_label()

func _update_hunger_label() -> void:
	if _hunger_label == null:
		return
	_hunger_label.text = PlayerStatsService.hunger_label(_player_satiety)
	if _player_satiety <= 0.0:
		_hunger_label.modulate = Color(1.0, 0.5, 0.4, 1.0)
	elif _player_satiety <= PlayerStatsService.SATIETY_HUNGRY_THRESHOLD:
		_hunger_label.modulate = Color(1.0, 0.8, 0.5, 1.0)
	else:
		_hunger_label.modulate = Color.WHITE

func _update_hp_label() -> void:
	if _hp_label == null:
		return
	_hp_label.text = "❤ %d / %d" % [int(ceil(_player_hp)), int(_player_max_hp)]
	if _player_hp <= _player_max_hp * 0.3:
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
	if _player_hotbar != null:
		_player_hotbar.refresh()
	_save_player_inventory()

func _save_player_inventory() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings") or not game_session.has_method("set_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	settings["player_inventory"] = _player_inventory.duplicate()
	settings["player_coins"] = _player_coins
	settings["player_hp"] = _player_hp
	game_session.call("set_world_settings", settings)

## --- Cross-visit persistence ---------------------------------------------
## Player edits to the hold (digging, torches, builds, cleared decor) are
## mirrored into GameSession keyed by hold seed and level, then re-applied
## on entry - so the base you carve survives leaving the scene.

static func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

static func _parse_cell_key(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

func _hold_diff_for_level() -> Dictionary:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings"):
		return {}
	var settings: Dictionary = game_session.call("get_world_settings")
	var diffs: Dictionary = settings.get("hold_diffs", {}) as Dictionary if settings.get("hold_diffs") is Dictionary else {}
	var hold: Dictionary = diffs.get(str(_world_seed_hash), {}) as Dictionary if diffs.get(str(_world_seed_hash)) is Dictionary else {}
	var level_variant: Variant = hold.get(str(_hold_state.current_level_index), {})
	return level_variant as Dictionary if level_variant is Dictionary else {}

## field semantics: "dug"/"torches"/"decor_erased" are cell lists
## (value omitted); "grid_edits"/"decor_edits" map cell -> value.
func _record_hold_edit(field: String, cell: Vector2i, value: Variant = null) -> void:
	if _restoring_hold_diffs:
		return
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings") or not game_session.has_method("set_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	var diffs: Dictionary = settings.get("hold_diffs", {}) as Dictionary if settings.get("hold_diffs") is Dictionary else {}
	var hold_key := str(_world_seed_hash)
	var hold: Dictionary = diffs.get(hold_key, {}) as Dictionary if diffs.get(hold_key) is Dictionary else {}
	var level_key := str(_hold_state.current_level_index)
	var level: Dictionary = hold.get(level_key, {}) as Dictionary if hold.get(level_key) is Dictionary else {}
	var key := _cell_key(cell)
	if value == null:
		var cells: Array = level.get(field, []) as Array
		if not cells.has(key):
			cells.append(key)
		level[field] = cells
	else:
		var edits: Dictionary = level.get(field, {}) as Dictionary
		edits[key] = value
		level[field] = edits
	hold[level_key] = level
	diffs[hold_key] = hold
	settings["hold_diffs"] = diffs
	game_session.call("set_world_settings", settings)

## Re-applies the stored diff to freshly generated level data. Order
## matters: digs first, then grid edits (a wall built over a dug cell
## must win), then decor.
func _apply_hold_diffs_to_level(level_data: Dictionary, grid: Dictionary) -> void:
	var diff := _hold_diff_for_level()
	if diff.is_empty():
		return
	_restoring_hold_diffs = true
	for key_variant: Variant in (diff.get("dug", []) as Array):
		var cell := _parse_cell_key(String(key_variant))
		grid[cell] = CELL_HALL
		_dug_cells[cell] = true
	var grid_edits := diff.get("grid_edits", {}) as Dictionary
	for key_variant: Variant in grid_edits.keys():
		grid[_parse_cell_key(String(key_variant))] = int(grid_edits[key_variant])
	var decor_edits := diff.get("decor_edits", {}) as Dictionary
	for key_variant: Variant in decor_edits.keys():
		var cell := _parse_cell_key(String(key_variant))
		var tile_key := String(decor_edits[key_variant])
		_latest_floor_decor[cell] = tile_key
		if tile_key == "chest" and not _chest_inventories.has(cell):
			_chest_inventories[cell] = []
	for key_variant: Variant in (diff.get("decor_erased", []) as Array):
		_latest_floor_decor.erase(_parse_cell_key(String(key_variant)))
	if not level_data.has("torches"):
		level_data["torches"] = []
	var torches := level_data["torches"] as Array
	for key_variant: Variant in (diff.get("torches", []) as Array):
		var cell := _parse_cell_key(String(key_variant))
		if not torches.has(cell):
			torches.append(cell)
	_restoring_hold_diffs = false

## Chunk streaming regenerates terrain from noise, which would refill
## player-dug tunnels: re-assert the diff for cells inside the new chunk.
func _apply_hold_diffs_to_rect(rect: Rect2i) -> void:
	var diff := _hold_diff_for_level()
	if diff.is_empty():
		return
	for key_variant: Variant in (diff.get("dug", []) as Array):
		var cell := _parse_cell_key(String(key_variant))
		if rect.has_point(cell):
			_latest_grid[cell] = CELL_HALL
			_dug_cells[cell] = true
	var grid_edits := diff.get("grid_edits", {}) as Dictionary
	for key_variant: Variant in grid_edits.keys():
		var cell := _parse_cell_key(String(key_variant))
		if rect.has_point(cell):
			_latest_grid[cell] = int(grid_edits[key_variant])
	for key_variant: Variant in (diff.get("decor_erased", []) as Array):
		var cell := _parse_cell_key(String(key_variant))
		if rect.has_point(cell):
			_latest_floor_decor.erase(cell)

func _load_persistent_player_state() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings"):
		return
	var stats := PlayerStatsService.for_session(self)
	_player_max_hp = float(stats.get("max_hp", _player_max_hp))
	_player_attack_damage = int(stats.get("attack", _player_attack_damage))
	_player_satiety = PlayerStatsService.load_satiety(self)
	var settings: Dictionary = game_session.call("get_world_settings")
	_player_hp = clampf(float(settings.get("player_hp", _player_max_hp)), 1.0, _player_max_hp)
	var clock_variant: Variant = settings.get("game_clock")
	if clock_variant is Dictionary:
		var clock := clock_variant as Dictionary
		_game_hour = clampf(float(clock.get("hour", _game_hour)), 0.0, 23.99)
		_game_day = maxi(1, int(clock.get("day", _game_day)))

func _save_persistent_player_state() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings") or not game_session.has_method("set_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	settings["player_hp"] = _player_hp
	settings["player_satiety"] = _player_satiety
	settings["game_clock"] = {"hour": _game_hour, "day": _game_day}
	game_session.call("set_world_settings", settings)

## Re-attached from the scene cache: pull the wounds, hunger and clock
## the rest of the world inflicted while this hold was parked.
func _on_scene_resumed() -> void:
	_load_persistent_player_state()
	_last_clock_stamp = -1
	_update_clock_label()
	_update_hp_label()
	_update_hunger_label()

func _exit_tree() -> void:
	_save_persistent_player_state()

## Pushes the live clock/HP/satiety into the session. Runs on scene exit
## AND whenever SaveGameService writes a slot, so saves capture now.
func flush_session_state() -> void:
	_save_persistent_player_state()

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
	_record_hold_edit("dug", cell)
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
	# The dwarf assembled at character creation walks the world; older
	# characters keep the sheet slot or the profession hero sheet.
	var composed := DwarfHoldActorVisuals.resolve_player_dwarf_texture(self)
	if composed != null:
		return DwarfHoldActorVisuals.create_composed_player_sprite(composed, tile_size)
	var character_slot := DwarfHoldActorVisuals.resolve_player_character_slot(self)
	if character_slot >= 0:
		return DwarfHoldTavernService.create_tavern_character_sprite(
			DwarfHoldActorVisuals.DWARF_CHARACTERS_TEXTURE, character_slot, tile_size)
	return DwarfHoldTavernService.create_player_character_sprite(
		_shattered_player_texture,
		tile_size,
		Callable(self, "_create_tavern_character_sprite")
	)

func _create_placeholder_actor_texture() -> Texture2D:
	return DwarfHoldTavernService.create_placeholder_actor_texture()

## Right-click on a living citizen opens their inspection card - a look,
## not a touch, so it works at any distance. Returns whether the click
## was claimed; unclaimed right-presses fall through to map panning.
func _handle_player_right_click(mouse_position: Vector2) -> bool:
	var clicked_cell := _cell_from_mouse_position(mouse_position)
	var npc_state := _npc_state_at_cell(clicked_cell)
	# The risen dead have no pockets worth rifling.
	if npc_state.is_empty() or SettlementAfflictionService.is_active_zombie(npc_state):
		if _npc_inspection_card != null:
			_npc_inspection_card.close()
		return false
	_open_npc_inspection(npc_state)
	return true

func _open_npc_inspection(npc_state: Dictionary) -> void:
	if _npc_inspection_card == null:
		return
	var role_title := String(ROLE_TITLES.get(int(npc_state.get("role", 0)), "Dwarf"))
	if not npc_state.has("identity"):
		npc_state["identity"] = NpcIdentityService.generate(_rng, role_title, "dwarf")
		npc_state["npc_name"] = String((npc_state["identity"] as Dictionary).get("name", "A dwarf"))
	_npc_inspection_card.open(npc_state, role_title, hash(seed_input.text.strip_edges()))

func _handle_player_click_action(mouse_position: Vector2) -> void:
	# Any left-click on the map is a click-away for an open inspection.
	if _npc_inspection_card != null and _npc_inspection_card.visible:
		_npc_inspection_card.close()
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
		# You don't chat with the risen dead - you put them down.
		if SettlementAfflictionService.is_active_zombie(npc_state):
			var swing := int(PlayerStatsService.for_session(self).get("attack", 2))
			npc_state["zombie_hp"] = int(npc_state.get("zombie_hp", 6)) - swing
			var zombie_sprite := npc_state.get("sprite") as Sprite2D
			if zombie_sprite != null:
				_spawn_floating_text("-%d" % swing, zombie_sprite.position, Color(1.0, 0.85, 0.5, 1.0))
			if int(npc_state.get("zombie_hp", 0)) <= 0:
				npc_state["affliction_dead"] = true
				_remove_dead_afflicted()
				_set_save_status("The corpse falls still at last.", Color(0.8, 0.85, 0.7, 1.0))
			return
		_show_npc_dialogue(npc_state)
		return
	var shop_type := _shop_type_at_cell(clicked_cell)
	if not shop_type.is_empty() and _is_player_adjacent_to_cell(clicked_cell):
		_open_trade_popup(clicked_cell, shop_type)
		return
	if _try_work_forge(clicked_cell):
		return
	var far_creature := _creature_index_at_cell(clicked_cell)
	if far_creature >= 0 and not _is_player_adjacent_to_cell(clicked_cell) and _try_ranged_attack(far_creature, clicked_cell):
		return
	if _try_search_furnishing(clicked_cell):
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
	# A one-step path is consumed immediately (leaving the path empty but
	# the walker moving), so "moving" also counts as path accepted.
	if not _player_move_path.is_empty() or _player_is_moving:
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

	# Mid-glide the walker belongs to the tile it is arriving at, not the
	# one it left - pathing from the stale cell made the first step a
	# multi-tile jump through unchecked ground.
	var path_start := _player_move_target_cell if _player_is_moving else _player_cell
	var next_path := _build_player_path(path_start, target_cell)
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
	# One tile per step, always - a longer vector would glide the sprite
	# across intermediate cells nothing ever walkability-checked.
	if absi(direction.x) > 1 or absi(direction.y) > 1:
		return false
	# Corner rule, same as the click pathfinder: no squeezing diagonally
	# between two blocked orthogonals into sealed rooms.
	if direction.x != 0 and direction.y != 0:
		if not _is_walkable_cell(_player_cell + Vector2i(direction.x, 0)) or not _is_walkable_cell(_player_cell + Vector2i(0, direction.y)):
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
	var predator_events := SettlementAfflictionService.update_predators(
		delta, _npc_states, city_layer, _rng, _game_hour,
		Callable(self, "_is_npc_walkable_cell"),
		Callable(self, "_cell_center_position"),
		float(_game_day) * 24.0 + _game_hour
	)
	for predator_event: String in predator_events:
		_set_save_status(predator_event, Color(0.95, 0.6, 0.55, 1.0))
	SettlementNpcScheduler.update_scheduled_npcs(
		delta, _scheduled_states(), city_layer, _rng,
		tile_size, _game_hour,
		Callable(self, "_is_npc_walkable_cell"),
		Callable(self, "_cell_center_position")
	)

## The dead answer to their hunger, not the clock.
func _scheduled_states() -> Array[Dictionary]:
	var living: Array[Dictionary] = []
	for state: Dictionary in _npc_states:
		if not SettlementAfflictionService.is_active_zombie(state):
			living.append(state)
	return living

## Clock-scale affliction bookkeeping: recovery, deaths, incubations,
## contagion, and vampires caught out in the sun.
func _advance_afflictions(delta_hours: float) -> void:
	if _npc_states.is_empty() or delta_hours <= 0.0:
		return
	var day_hour := _game_hour >= 6.0 and _game_hour < 20.0
	var affliction_events := SettlementAfflictionService.advance(_npc_states, delta_hours, _rng, false, day_hour)
	for affliction_event: String in affliction_events:
		_set_save_status(affliction_event, Color(0.95, 0.6, 0.55, 1.0))
	_apply_affliction_visuals()
	_remove_dead_afflicted()

func _apply_affliction_visuals() -> void:
	for state: Dictionary in _npc_states:
		var sprite := state.get("sprite") as Sprite2D
		if sprite == null:
			continue
		var tint: Color = SettlementAfflictionService.tint_for(state)
		var tint_key := str(tint)
		if String(state.get("affliction_tint_applied", "")) == tint_key:
			continue
		state["affliction_tint_applied"] = tint_key
		sprite.modulate = tint

func _remove_dead_afflicted() -> void:
	for index in range(_npc_states.size() - 1, -1, -1):
		var state := _npc_states[index]
		if not bool(state.get("affliction_dead", false)):
			continue
		var sprite := state.get("sprite") as Sprite2D
		if sprite != null:
			sprite.queue_free()
		_npc_states.remove_at(index)

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
	_furnishing_by_cell.clear()
	_actor_passable_cache.clear()
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
		# Furniture is scenery, treated as tiles: the decor layer, under
		# every walker, tinted by the same day/night modulate.
		decor_layer.add_child(sprite)
		_furnishing_sprites.append(sprite)
		for footprint_cell: Vector2i in RoomFurnishingService.footprint_cells(piece_name, base_cell):
			_furnishing_by_cell[footprint_cell] = piece_name
		if int(RoomFurnishingService.piece_def(piece_name).get("rows_block", 1)) > 0:
			for cell: Vector2i in RoomFurnishingService.footprint_cells(piece_name, base_cell):
				_furnishing_blocked_cells[cell] = true
				_actor_passable_cache.erase(cell)
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
	_actor_passable_cache.erase(cell)

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
	# A dwarf under the cursor introduces themselves, matched against the
	# sprite bodies so a walker mid-step still counts as hovered.
	var hovered_npc := _npc_state_near_mouse(mouse_position)
	if hovered_npc.is_empty():
		hovered_npc = _npc_state_at_cell(hovered_cell)
	var hovered_npc_name := String((hovered_npc.get("identity", {}) as Dictionary).get("name", ""))
	if tile_hover_tooltip.visible and hovered_cell == _hover_tooltip_cell and hovered_layer == _hover_tooltip_layer and hovered_npc_name == _hover_tooltip_npc:
		_place_hover_tooltip(mouse_position + Vector2(16, 16))
		return

	var atlas_coords := hovered_layer.get_cell_atlas_coords(hovered_cell)
	var tile_name := _tile_name_from_atlas(atlas_coords)
	var zone_name := _zone_name_for_cell(hovered_cell)
	var tooltip_lines: PackedStringArray = []
	if not hovered_npc.is_empty() and hovered_npc.has("identity"):
		var identity := hovered_npc.get("identity", {}) as Dictionary
		tooltip_lines.append(NpcIdentityService.summary_line(identity))
		for detail: String in NpcIdentityService.detail_lines(identity):
			tooltip_lines.append(detail)
		if hovered_npc.has("faction_name") and not bool(hovered_npc.get("faction_secret", false)):
			tooltip_lines.append("Sworn to the %s" % String(hovered_npc.get("faction_name", "")))
		var affliction_line: String = SettlementAfflictionService.tooltip_line(hovered_npc)
		if not affliction_line.is_empty():
			tooltip_lines.append(affliction_line)
		tooltip_lines.append("")
	tooltip_lines.append("Tile: %s" % tile_name)
	tooltip_lines.append("Zone: %s" % zone_name)
	var furnishing_piece := String(_furnishing_by_cell.get(hovered_cell, ""))
	if not furnishing_piece.is_empty():
		var piece_line := "Furniture: %s" % DfFurnitureDefs.display_name(furnishing_piece)
		if DfFurnitureDefs.is_searchable(furnishing_piece):
			piece_line += " (click to search)"
		elif FORGE_FIRE_PIECES.has(furnishing_piece):
			piece_line += " (click to smelt starmetal)"
		elif furnishing_piece == "int_anvil":
			piece_line += " (click to forge starmetal gear)"
		tooltip_lines.append(piece_line)
	var district_name := String(_latest_district_cell_map.get(hovered_cell, ""))
	if not district_name.is_empty():
		tooltip_lines.insert(0, "District: %s" % district_name)
	var subtype := _building_type_for_cell_or_empty(hovered_cell)
	if not subtype.is_empty():
		var signboard := String(_latest_civic_building_name_map.get(hovered_cell, ""))
		if signboard.is_empty():
			tooltip_lines.append("Subtype: %s" % _display_name_for_building_type(subtype))
		else:
			tooltip_lines.append("%s — %s" % [signboard, _display_name_for_building_type(subtype)])
		var flavor := String(BUILDING_SUBTYPE_FLAVOR.get(subtype, ""))
		if not flavor.is_empty():
			tooltip_lines.append(flavor)
	tile_hover_label.text = "\n".join(tooltip_lines)
	tile_hover_tooltip.reset_size()
	_place_hover_tooltip(mouse_position + Vector2(16, 16))
	tile_hover_tooltip.visible = true
	_hover_tooltip_cell = hovered_cell
	_hover_tooltip_layer = hovered_layer
	_hover_tooltip_npc = hovered_npc_name

## The NPC whose sprite body sits under the cursor, nearest first.
func _npc_state_near_mouse(mouse_position: Vector2) -> Dictionary:
	if city_layer == null:
		return {}
	var local_point := (mouse_position - city_layer.position) / maxf(city_layer.scale.x, 0.001)
	var best: Dictionary = {}
	var best_distance := float(tile_size.x) * 0.75
	for state: Dictionary in _npc_states:
		var sprite := state.get("sprite") as Sprite2D
		if sprite == null or not sprite.visible:
			continue
		var distance := sprite.position.distance_to(local_point)
		if distance < best_distance:
			best_distance = distance
			best = state
	return best

func _hide_hover_tooltip() -> void:
	tile_hover_tooltip.visible = false
	_hover_tooltip_cell = Vector2i(2147483647, 2147483647)
	_hover_tooltip_layer = null
	_hover_tooltip_npc = ""

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

## The tooltip is top_level so the CityPanel container cannot stretch it
## across the whole panel; top_level positions are canvas-space, so the
## panel-local clamp result gets offset by the panel's global origin.
func _place_hover_tooltip(panel_local_position: Vector2) -> void:
	tile_hover_tooltip.position = city_panel.global_position + _clamp_tooltip_position(panel_local_position)

func _clamp_tooltip_position(desired_position: Vector2) -> Vector2:
	var tooltip_size := tile_hover_tooltip.size
	var panel_size := city_panel.size
	return Vector2(
		clampf(desired_position.x, 0.0, maxf(panel_size.x - tooltip_size.x, 0.0)),
		clampf(desired_position.y, 0.0, maxf(panel_size.y - tooltip_size.y, 0.0))
	)

## The town's civic catalog and residence mix differ from the hold's;
## the shared generation core reads them through these overrides.
func _civic_building_types() -> Dictionary:
	return CIVIC_BUILDING_TYPES

func _residence_types() -> Dictionary:
	return RESIDENCE_TYPES
