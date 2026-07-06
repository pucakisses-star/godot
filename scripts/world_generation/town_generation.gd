extends SettlementSceneBase

## Above-ground human town interior, entered from the overworld via
## right-click "Begin Journey" on a town tile. Forked from the dwarfhold
## generator: the same zone-grid pipeline (plazas, streets, residences,
## shops with guaranteed doors and connectivity) reinterpreted for the
## surface - grass instead of rock, dirt streets instead of halls, a
## cobbled market square, and timber-walled buildings.


@export var hall_zone_count_range := Vector2i(14, 22)
@export var housing_zone_count_range := Vector2i(80, 140)
@export var civic_building_zone_count_range := Vector2i(45, 95)
@export var plaza_zone_count_range := Vector2i(6, 14)
@export var tilesheet_path := "res://resources/images/town/town_tileset.png"
@export var tavern_vehicle_sprite_path := "res://resources/images/npc/townsfolk_characters.png"
@export var shattered_player_sprite_path := "res://resources/images/shattered_ui/warrior.png"
@export var tavern_npc_count := 5
@export var tavern_npc_speed_range := Vector2(38.0, 62.0)
@export var enable_fog_of_war := false
@export var underground_level_count_range := Vector2i(1, 1)
## Real minutes for one full in-game day.
@export var minutes_per_game_day := 6.0
@export var clock_start_hour := 9.0

# Residence variety: footprints are half-extents (rooms span 2*radius+1
# tiles). Houses sleep one dwarf; dormitories and barracks pack bed rows so
# large populations don't need hundreds of tiny homes.
const RESIDENCE_TYPES := {
	"house": {"weight": 0.72, "radius_min": Vector2i(2, 2), "radius_max": Vector2i(4, 3)},
	"dormitory": {"weight": 0.16, "radius_min": Vector2i(3, 3), "radius_max": Vector2i(5, 4)},
	"barracks": {"weight": 0.12, "radius_min": Vector2i(3, 3), "radius_max": Vector2i(4, 4)}
}

const TILE_ATLAS_DEFS := preload("res://scripts/world_generation/tile_atlas_defs.gd")
const TILE_ATLAS := TILE_ATLAS_DEFS.TOWN_TILE_ATLAS
const PASSABLE_TILE_KEYS := TILE_ATLAS_DEFS.TOWN_PASSABLE_TILE_KEYS
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
var _player_inventory: Dictionary = {}
var _player_coins := 0
var _coins_label: Label
var _trade_shop_cell := Vector2i(2147483647, 2147483647)
var _trade_shop_type := ""
var _shop_stocks: Dictionary = {}
var _active_speech_bubble: PanelContainer
var _escape_menu: EscapeMenu
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
var _last_move_direction := Vector2i.ZERO
var _move_repeat_timer := 0.0
var _npc_states: Array[Dictionary] = []
var _settlement_factions: Array[Dictionary] = []
var _surface_noise: Dictionary = {}
var _surface_chunks: Dictionary = {}
var _surface_last_player_chunk := Vector2i(2147483647, 2147483647)
var _surface_protect_rect := Rect2i()
var _surface_world_origin := Vector2i.ZERO
var _surface_road_cells: Dictionary = {}
var _surface_gates: Array[Dictionary] = []
var _surface_gate_labels: Array[Label] = []
var _surface_arrival_lock := false
var _surface_road_paths: Array[Array] = []
var _surface_anchor_cells: Array[Vector2i] = []
var _surface_creatures: Array[Dictionary] = []
var _surface_spawn_timer := 0.0
var _surface_ambush_stamp := -1
var _player_hp := PlayerStatsService.BASE_MAX_HP
var _player_max_hp := PlayerStatsService.BASE_MAX_HP
var _player_home_cell := Vector2i.ZERO
var _hp_label: Label
var _gear_label: Label
const SURFACE_CREATURE_TEXTURE := preload("res://resources/images/npc/creature_characters.png")
const BOAT_SPRITE_TEXTURE := preload("res://resources/images/npc/boat_sprite.png")
var _player_attack_timer := 0.0
var _staff_cooldown := 0.0
var _companion: Dictionary = {}
var _player_boating := false
var _boat_sprite: Sprite2D
var _player_mounted := false
var _mount_sprite: Sprite2D
var _build_selection := -1
var _player_built_cells: Dictionary = {}
var _farm_plots: Dictionary = {}
var _raid_active := false
var _raid_end_stamp := 0.0
var _next_raid_day := 0
var _music_timer := 0.0
var _wall_damage: Dictionary = {}
var _speed_scale_cache := 1.0
var _inventory_screen: PlayerInventoryPanel
var _factions_label: RichTextLabel
var _faction_event_stamps: Dictionary = {}
var _town_name := ""
var _town_details: Dictionary = {}
var _game_hour := 9.0
var _game_day := 1
var _calendar_start_year := 250
var _bed_cells: Array[Vector2i] = []
var _green_cells: Array[Vector2i] = []
var _farm_animals: Array[Dictionary] = []
var _farm_animal_textures: Dictionary = {}
var _pending_player_spawn_cell := Vector2i(2147483647, 2147483647)
var _town_theme := ""
var _farm_sprites: Array[Node2D] = []
var _farm_pens: Array = []
var _farm_blocked_cells: Dictionary = {}
var _windmill_sails: Array[Dictionary] = []
var _desert_decor_textures: Dictionary = {}
var _furnishing_sprites: Array[Node2D] = []
var _furnishing_blocked_cells: Dictionary = {}
var _glow_sprites: Array[Node2D] = []
var _pending_glows: Array[Dictionary] = []
var _light_overlay_sprite: Sprite2D
var _passable_atlas_set: Dictionary = {}
var _actor_passable_cache: Dictionary = {}
var _last_clock_stamp := -1
var _applied_day_night_tint := Color(-1.0, -1.0, -1.0, -1.0)
var _player_satiety := PlayerStatsService.SATIETY_MAX

const PLAYER_MOVE_REPEAT_INITIAL_DELAY := 0.22
const PLAYER_MOVE_REPEAT_INTERVAL := 0.10
const PLAYER_MOVE_SPEED := 260.0
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
	{"tile": CELL_HALL, "name": "Street"},
	{"tile": CELL_HOUSE, "name": "House"},
	{"tile": CELL_BUILDING, "name": "Building"},
	{"tile": CELL_PLAZA, "name": "Market Square"}
]

const BUILDING_SUBTYPE_FLAVOR := {
	"smithy": "The air rings with hammer blows and quenched steel.",
	"tavern": "Laughter and the smell of roast and ale spill into the street.",
	"bakery": "Warm bread and honey cakes scent the morning air.",
	"chapel": "Candles gutter before a quiet roadside altar.",
	"guardhouse": "Polished pikes and watch rosters line the walls.",
	"market_stall": "Hawkers cry their wares over the market din."
}

const MIN_ZOOM := 0.1
const MAX_ZOOM := 2.5
const ZOOM_STEP := 0.1


const CHEST_SLOT_COLUMNS := 8
const CHEST_SLOT_ROWS := 4
const BACKPACK_SLOT_ROWS := 3


const TOWN_SCENE_SEED_KEY := "town_scene_seed"
const TOWN_SCENE_POPULATION_KEY := "town_scene_population"
const TOWN_SCENE_NAME_KEY := "town_scene_name"
const TOWN_SCENE_TILE_KEY := "town_scene_tile"
const TOWN_SCENE_THEME_KEY := "town_scene_theme"

## Farmstead art from the web game's Farm tileset (16px art; town cells are
## 32px, so a 128px sprite spans four cells).
const FARM_HOUSES_TEXTURE := preload("res://resources/images/webgame_tiles/Farm/Tiled_files/Houses.png")
const FARM_PLANTS_TEXTURE := preload("res://resources/images/webgame_tiles/Farm/Tiled_files/Plants.png")
const FARM_SAILS_TEXTURE := preload("res://resources/images/webgame_tiles/Farm/Tiled_files/Sails_animation.png")
const FARMSTEAD_SITE := Vector2i(10, 9)
const FARM_BUILDING_CROPS := {
	"farmhouse": Rect2(272, 0, 128, 152),
	"barn": Rect2(128, 0, 80, 88),
	"open_barn": Rect2(400, 16, 96, 80)
}
const WINDMILL_BODY_CROP := Rect2(80, 152, 64, 144)
const SAIL_FRAME := Vector2(160, 144)
const SAIL_FRAME_COUNT := 6
const SAIL_FRAME_TIME := 0.16
const FARM_CROP_RECTS: Array[Rect2] = [
	Rect2(480, 0, 16, 32),
	Rect2(368, 0, 16, 32),
	Rect2(192, 48, 32, 32),
	Rect2(32, 0, 32, 32)
]

## Desert dressing for desert-city interiors, from the Desert decor set.
const DESERT_DECOR_DIR := "res://resources/images/webgame_tiles/Desert/Objects_separately/"
const DESERT_DECOR_COMMON: Array[String] = [
	"Cactus1_sand_shadow2.png", "Cactus2_sand_shadow1.png", "Cactus2_sand_shadow2.png",
	"Bones_sand_shadow2.png", "Bones_sand_shadow3.png",
	"Flower_sand_shadow1.png", "Flower_sand_shadow2.png",
	"Roots_sand_shadow5.png", "Roots_sand_shadow6.png", "Roots_sand_shadow7.png"
]
const DESERT_DECOR_RARE: Array[String] = [
	"Statues_sand_shadow1.png", "Statues_sand_shadow2.png",
	"Statues_sand_shadow3.png", "Statues_sand_shadow4.png",
	"The_beast_sand_shadow1.png", "House_stump_sand_shadow.png",
	"Scarabaeus_house_sand_shadow.png", "trilobite_house_sand_shadow.png"
]
const DESERT_BASE_SWAP := {
	"grass": "sand",
	"grass_dark": "sand_alt",
	"grass_tuft": "sand_pebbles"
}
const DESERT_SKIPPED_DECOR: Array[String] = [
	"tree", "tree_dark", "hedge", "hedge_alt",
	"flowers_white", "flowers_yellow"
]

## Spritesheet slots in townsfolk_characters.png block order.
const ROLE_VILLAGER := 0
const ROLE_VILLAGER_WOMAN := 1
const ROLE_GUARD := 2
const ROLE_MERCHANT := 3
const ROLE_BLACKSMITH := 4
const ROLE_CLERIC := 5
const ROLE_FARMER := 6
const ROLE_ELDER := 7

## Which building types each working role reports to, in preference order.
const ROLE_TITLES := {
	ROLE_VILLAGER: "Villager",
	ROLE_VILLAGER_WOMAN: "Villager",
	ROLE_GUARD: "Town Guard",
	ROLE_MERCHANT: "Merchant",
	ROLE_BLACKSMITH: "Blacksmith",
	ROLE_CLERIC: "Cleric",
	ROLE_FARMER: "Farmer",
	ROLE_ELDER: "Elder"
}

const ROLE_WORKPLACES := {
	ROLE_BLACKSMITH: ["smithy", "workshop", "carpenter"],
	ROLE_MERCHANT: ["market_stall", "general_store", "warehouse"],
	ROLE_CLERIC: ["chapel", "town_hall"],
	ROLE_ELDER: ["town_hall", "guild_hall", "tavern"],
	ROLE_VILLAGER: ["tavern", "bakery", "general_store", "warehouse", "stable", "carpenter", "tailor", "apothecary", "inn", "workshop"],
	ROLE_VILLAGER_WOMAN: ["bakery", "tailor", "apothecary", "inn", "tavern", "general_store", "guild_hall", "workshop"]
}

## Upper halves of two-tile-tall furniture, drawn over the cell above the
## furniture base at render time (passable visual caps).
const TALL_DECOR_TOPS := {
	"bed": "bed_top",
	"bed_alt": "bed_alt_top",
	"wardrobe": "wardrobe_top",
	"dresser": "dresser_top",
	"shelf": "shelf_top",
	"forge": "forge_top",
	"oven": "oven_top"
}

const CHEST_LOOT_TABLE := [
	{"name": "Copper Coins", "min": 4, "max": 18},
	{"name": "Wheel of Cheese", "min": 1, "max": 2},
	{"name": "Bolt of Cloth", "min": 1, "max": 3},
	{"name": "Loaf of Bread", "min": 1, "max": 4},
	{"name": "Jar of Honey", "min": 1, "max": 2},
	{"name": "Iron Horseshoes", "min": 2, "max": 6},
	{"name": "Wax Candles", "min": 2, "max": 8},
	{"name": "Skein of Wool", "min": 1, "max": 5},
	{"name": "Dried Fish", "min": 1, "max": 4},
	{"name": "Cave Crab", "min": 1, "max": 2},
	{"name": "Coral Snail", "min": 1, "max": 2},
	{"name": "Old Fishing Rod", "min": 1, "max": 1},
	{"name": "Amber", "min": 1, "max": 2},
	{"name": "Scarlet Cap", "min": 1, "max": 3},
	{"name": "King Bolete", "min": 1, "max": 2},
	{"name": "Gold Trinket", "min": 1, "max": 1}
]

const CIVIC_BUILDING_TYPES := {
	"smithy": {
		"placement_weight": 1.1,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["forge", "armor_stand", "barrel", "bucket"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.6
		}
	},
	"tavern": {
		"placement_weight": 1.2,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["barrel", "jug", "bench", "counter"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.5
		}
	},
	"inn": {
		"placement_weight": 0.8,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["bed", "counter", "barrel", "table"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.4
		}
	},
	"bakery": {
		"placement_weight": 0.9,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["oven", "sack", "counter", "table"],
		"adjacency_preferences": {}
	},
	"general_store": {
		"placement_weight": 1.0,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["counter", "shelf", "sack", "pot"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.45
		}
	},
	"market_stall": {
		"placement_weight": 1.15,
		"preferred_footprint_min": Vector2i(1, 1),
		"preferred_footprint_max": Vector2i(2, 2),
		"decor_tile_pool": ["stall", "stall_alt", "sack", "barrel_open"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.7
		}
	},
	"chapel": {
		"placement_weight": 0.6,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["brazier", "flowers_pot", "bench", "plant_tall"],
		"adjacency_preferences": {}
	},
	"guild_hall": {
		"placement_weight": 0.55,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["table", "bench", "shelf", "chest"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.2
		}
	},
	"town_hall": {
		"placement_weight": 0.4,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["table", "bench", "brazier", "shelf"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.3
		}
	},
	"warehouse": {
		"placement_weight": 0.75,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["sack", "barrel", "chest", "barrel_open"],
		"adjacency_preferences": {}
	},
	"carpenter": {
		"placement_weight": 0.7,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["bench", "table", "barrel", "bucket"],
		"adjacency_preferences": {}
	},
	"tailor": {
		"placement_weight": 0.6,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["table", "dresser", "chest", "plant"],
		"adjacency_preferences": {}
	},
	"apothecary": {
		"placement_weight": 0.55,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["pot", "jug", "plant_tall", "shelf"],
		"adjacency_preferences": {}
	},
	"guardhouse": {
		"placement_weight": 0.65,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["armor_stand", "bed_alt", "chest", "bench"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.35
		}
	},
	"stable": {
		"placement_weight": 0.5,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["bucket", "sack", "bench", "barrel_open"],
		"adjacency_preferences": {}
	},
	"workshop": {
		"placement_weight": 0.8,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["bench", "table", "bucket", "barrel"],
		"adjacency_preferences": {}
	}
}

func _ready() -> void:
	_apply_cached_town_scene_seed()
	_configure_tile_layer()
	global_darkness.color = Color(1.0, 1.0, 1.0, 1.0)
	fog_of_war.visible = false
	_tavern_character_texture = load(tavern_vehicle_sprite_path) as Texture2D
	if _tavern_character_texture == null:
		_tavern_character_texture = _create_placeholder_tavern_character_texture()
	_shattered_player_texture = DwarfHoldActorVisuals.resolve_hero_texture(self)
	if _shattered_player_texture == null:
		_shattered_player_texture = load(shattered_player_sprite_path) as Texture2D
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
	_load_persistent_clock()
	_load_player_combat_state()
	_setup_hp_label()
	_setup_inventory_screen()
	GameAudioService.play_music(self, "town")
	_update_day_night_tint()
	_update_clock_label()
	_generate_city()

func _process(delta: float) -> void:
	_advance_game_clock(delta)
	_player_attack_timer = maxf(_player_attack_timer - delta, 0.0)
	_staff_cooldown = maxf(_staff_cooldown - delta, 0.0)
	_stream_surface_chunks()
	_check_surface_arrival()
	_update_surface_life(delta)
	_update_companion(delta)
	_update_raid(delta)
	_update_music(delta)
	_update_player_turn_movement(delta)
	_update_player_hold_movement(delta)
	_update_npc_movement(delta)
	_update_farm_animals(delta)
	_update_windmill_sails(delta)

func _advance_game_clock(delta: float) -> void:
	if minutes_per_game_day <= 0.0:
		return
	var delta_hours := delta * 24.0 / (minutes_per_game_day * 60.0)
	var hour_before := int(_game_hour)
	_game_hour += delta_hours
	while _game_hour >= 24.0:
		_game_hour -= 24.0
		_game_day += 1
	if int(_game_hour) != hour_before:
		var clock_settings: Dictionary = _world_settings_snapshot()
		clock_settings["game_clock"] = {"hour": _game_hour, "day": _game_day}
		_store_world_settings(clock_settings)
		_refresh_player_stats_town()
		_advance_farm_growth()
		_maybe_start_raid()
	# Strolling the market works up an appetite too.
	_player_satiety = clampf(_player_satiety - delta_hours * PlayerStatsService.SATIETY_DRAIN_PER_GAME_HOUR, 0.0, PlayerStatsService.SATIETY_MAX)
	_advance_afflictions(delta_hours)
	_update_faction_events()
	_update_day_night_tint()
	_update_clock_label()

func _update_clock_label() -> void:
	if clock_label == null:
		return
	var hour := int(_game_hour)
	var minute := int((_game_hour - float(hour)) * 60.0)
	var clock_stamp := (_game_day * 24 + hour) * 60 + minute
	if clock_stamp == _last_clock_stamp:
		return
	_last_clock_stamp = clock_stamp
	var is_night := _game_hour >= 20.0 or _game_hour < 6.0
	clock_label.text = "%s %02d:%02d — %s (%s)" % [
		"🌙" if is_night else "☀",
		hour,
		minute,
		GameCalendar.date_text(_game_day - 1, _calendar_start_year),
		GameCalendar.season_for_day(_game_day - 1)
	]

## Sky tint over the whole scene: white at noon, deep blue at night, warm
## sunrise/sunset shoulders.
func _day_night_tint(hour: float) -> Color:
	var night := Color(0.42, 0.46, 0.68, 1.0)
	var warm := Color(1.0, 0.83, 0.66, 1.0)
	var day := Color(1.0, 1.0, 1.0, 1.0)
	if hour < 5.0 or hour >= 21.5:
		return night
	if hour < 6.5:
		return night.lerp(warm, (hour - 5.0) / 1.5)
	if hour < 8.0:
		return warm.lerp(day, (hour - 6.5) / 1.5)
	if hour < 17.5:
		return day
	if hour < 19.5:
		return day.lerp(warm, (hour - 17.5) / 2.0)
	return warm.lerp(night, (hour - 19.5) / 2.0)

func _update_day_night_tint() -> void:
	# Tint only the map layers so the side panel stays readable at night.
	var tint := _day_night_tint(_game_hour)
	if tint.is_equal_approx(_applied_day_night_tint):
		return
	_applied_day_night_tint = tint
	if city_layer != null:
		city_layer.modulate = tint
	if decor_layer != null:
		decor_layer.modulate = tint
	if actor_layer != null:
		actor_layer.modulate = tint

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _is_text_input_focused():
		if _escape_menu != null:
			_escape_menu.toggle()
		get_viewport().set_input_as_handled()
		return
	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and not _is_text_input_focused():
		match key_event.keycode:
			KEY_B:
				_cycle_town_build_selection()
				get_viewport().set_input_as_handled()
				return
			KEY_Q:
				_handle_quick_drink_action()
				get_viewport().set_input_as_handled()
				return
			KEY_M:
				_toggle_mount()
				get_viewport().set_input_as_handled()
				return
			KEY_I:
				if _inventory_screen != null:
					_inventory_screen.toggle()
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
	SceneCacheService.request_change(self, OVERWORLD_SCENE_PATH)

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

## The world clock is shared across scenes: entering town resumes wherever
## time stood when you left the last settlement.
func _load_persistent_clock() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	var clock_variant: Variant = settings.get("game_clock")
	if clock_variant is Dictionary:
		var clock := clock_variant as Dictionary
		_game_hour = clampf(float(clock.get("hour", _game_hour)), 0.0, 23.99)
		_game_day = maxi(1, int(clock.get("day", _game_day)))
	_player_satiety = PlayerStatsService.load_satiety(self)

## Re-attached from the scene cache: time and appetite moved on while
## this town was parked.
func _on_scene_resumed() -> void:
	_load_persistent_clock()
	_last_clock_stamp = -1
	_applied_day_night_tint = Color(-1.0, -1.0, -1.0, -1.0)
	_update_day_night_tint()
	_update_clock_label()

func _exit_tree() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings") or not game_session.has_method("set_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	settings["game_clock"] = {"hour": _game_hour, "day": _game_day}
	settings["player_satiety"] = _player_satiety
	settings["player_hp"] = _player_hp
	game_session.call("set_world_settings", settings)

## Health follows the walker between scenes the same way the clock does:
## max HP from the character sheet plus gear, current HP from the shared
## save. Above ground it only matters once the wilds start biting.
func _load_player_combat_state() -> void:
	var stats: Dictionary = PlayerStatsService.for_session(self)
	_player_max_hp = float(stats.get("max_hp", _player_max_hp))
	_player_hp = _player_max_hp
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null and game_session.has_method("get_world_settings"):
		var settings: Dictionary = game_session.call("get_world_settings")
		_player_hp = clampf(float(settings.get("player_hp", _player_max_hp)), 1.0, _player_max_hp)

func _save_player_hp() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings") or not game_session.has_method("set_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	settings["player_hp"] = _player_hp
	game_session.call("set_world_settings", settings)

func _setup_hp_label() -> void:
	var controls := get_node_or_null("Margin/Layout/Controls")
	if controls == null:
		return
	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 13)
	controls.add_child(_hp_label)
	_gear_label = Label.new()
	_gear_label.add_theme_font_size_override("font_size", 12)
	_gear_label.modulate = Color(0.85, 0.88, 0.95, 1.0)
	controls.add_child(_gear_label)
	var clock := controls.get_node_or_null("ClockLabel")
	if clock != null:
		controls.move_child(_hp_label, clock.get_index() + 1)
		controls.move_child(_gear_label, clock.get_index() + 2)
	_update_hp_label()
	_update_gear_label()

func _update_hp_label() -> void:
	if _hp_label == null:
		return
	_hp_label.text = "❤ %d / %d" % [int(ceil(_player_hp)), int(_player_max_hp)]
	if _player_hp <= _player_max_hp * 0.3:
		_hp_label.modulate = Color(1.0, 0.5, 0.5, 1.0)
	else:
		_hp_label.modulate = Color(0.95, 0.87, 0.87, 1.0)

func _damage_player(damage: int, source_name: String = "the wilds") -> void:
	if _player_sprite == null:
		return
	_player_hp = maxf(_player_hp - float(damage), 0.0)
	_update_hp_label()
	_flash_sprite(_player_sprite, Color(1.0, 0.35, 0.35, 1.0))
	_spawn_floating_text("-%d" % damage, _player_sprite.position, Color(1.0, 0.4, 0.4, 1.0))
	if _player_hp <= 0.0:
		_handle_player_death(source_name)

## Death in the wilds is a walk of shame, not a game over: you wake back
## at your town doorstep with your wounds bound.
func _handle_player_death(source_name: String) -> void:
	_player_hp = _player_max_hp
	_update_hp_label()
	_player_move_path.clear()
	_player_is_moving = false
	if _player_sprite != null:
		_player_cell = _player_home_cell
		_actor_sprite_to_cell(_player_sprite, _player_home_cell)
		_center_view_on_cell(_player_home_cell)
	_save_player_hp()
	_set_save_status("Slain by %s — you wake back in town." % source_name, Color(0.95, 0.5, 0.5, 1.0))

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
	var header := " ".join(parts) if not parts.is_empty() else "Unnamed Traveler"
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
		_move_repeat_timer += PLAYER_MOVE_REPEAT_INTERVAL / _player_speed_scale()

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
		var next_position := _player_sprite.position.move_toward(_player_move_target_position, PLAYER_MOVE_SPEED * _player_speed_scale() * delta)
		_player_sprite.position = next_position
		_center_view_on_world_position(next_position)
		if next_position.distance_to(_player_move_target_position) > 0.5:
			return
		_player_sprite.position = _player_move_target_position
		_player_cell = _player_move_target_cell
		_player_is_moving = false
		if _try_use_stairs_at_player_cell():
			return

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
		push_error("Missing town tilesheet at %s" % tilesheet_path)
		return
	var texture := load(tilesheet_path) as Texture2D
	if texture == null:
		push_error("Unable to load town tilesheet texture at %s" % tilesheet_path)
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
	# tile write or blocked-cell change invalidates the affected entry.
	var cached: Variant = _actor_passable_cache.get(cell)
	if cached != null:
		return bool(cached)
	var passable := _compute_passable_cell_for_actor(cell)
	_actor_passable_cache[cell] = passable
	return passable

func _compute_passable_cell_for_actor(cell: Vector2i) -> bool:
	if _farm_blocked_cells.has(cell) or _furnishing_blocked_cells.has(cell):
		return false
	if city_layer.get_cell_source_id(cell) < 0:
		return false
	if not _is_passable_atlas_tile(city_layer.get_cell_atlas_coords(cell)):
		return false
	if decor_layer.get_cell_source_id(cell) < 0:
		return true
	return _is_passable_atlas_tile(decor_layer.get_cell_atlas_coords(cell))

func _apply_cached_town_scene_seed() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	var scene_seed := _hold_state.apply_world_settings(settings, TOWN_SCENE_SEED_KEY, TOWN_SCENE_POPULATION_KEY)
	_town_name = String(settings.get(TOWN_SCENE_NAME_KEY, "")).strip_edges()
	_town_theme = String(settings.get(TOWN_SCENE_THEME_KEY, "")).strip_edges().to_lower()
	if _town_theme == "desert":
		var title_label := get_node_or_null("Margin/Layout/Controls/Title") as Label
		if title_label != null:
			title_label.text = "Desert City"
	var chronology := settings.get("chronology", {}) as Dictionary
	_calendar_start_year = maxi(1, int(chronology.get("year", 250)))
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
	_hold_state.generated_levels.clear()

	var details_rng := RandomNumberGenerator.new()
	details_rng.seed = hash("%s::town_details" % seed_text)
	var display_name := _town_name if not _town_name.is_empty() else "Unnamed Town"
	_town_details = TownDetailsGenerator.generate(display_name, _hold_state.selected_hold_population, details_rng)

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
		requested_building_count = maxi(2, int(ceil(float(target_npcs_for_level) / 12.0)))
		requested_hall_count = maxi(3, int(ceil(float(target_npcs_for_level) / 24.0)))
		requested_plaza_count = clampi(1 + target_npcs_for_level / 140, 1, 4)
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
	var plaza_layouts: Array[Dictionary] = []
	var central_plaza_radius := Vector2i(
		maxi(3, roundi(float(_rng.randi_range(6, 10)) * footprint_scale)),
		maxi(3, roundi(float(_rng.randi_range(5, 8)) * footprint_scale))
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
			maxi(2, roundi(float(_rng.randi_range(4, 8)) * footprint_scale)),
			maxi(2, roundi(float(_rng.randi_range(3, 6)) * footprint_scale))
		)
		var plaza_shape := _roll_plaza_shape()
		var plaza_center := Vector2i.ZERO
		var found_location := false
		var plaza_spacing := maxi(6, roundi(14.0 * footprint_scale))
		for _placement_attempt in 24:
			var plaza_anchor := (plaza_layouts[_rng.randi_range(0, plaza_layouts.size() - 1)] as Dictionary).get("center", Vector2i.ZERO) as Vector2i
			var plaza_direction := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][_rng.randi_range(0, 3)] as Vector2i
			var plaza_offset_distance := maxi(12, roundi(float(_rng.randi_range(24, 56)) * footprint_scale))
			var candidate_center := plaza_anchor + plaza_direction * plaza_offset_distance
			candidate_center += Vector2i(_rng.randi_range(-14, 14), _rng.randi_range(-14, 14))
			if _is_plaza_too_close(candidate_center, plaza_radius, plaza_layouts, plaza_spacing):
				continue
			plaza_center = candidate_center
			found_location = true
			break
		if not found_location:
			var fallback_spread := maxi(24, roundi(80.0 * footprint_scale))
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
	_setup_surface_world(grid)
	_latest_zone_counts = level_data.get("zone_counts", {}) as Dictionary
	_latest_requested_zone_counts = level_data.get("requested_zone_counts", {}) as Dictionary
	_latest_civic_buildings_by_id = level_data.get("civic_buildings_by_id", {}) as Dictionary
	_latest_civic_building_type_map = level_data.get("civic_building_type_map", {}) as Dictionary
	_latest_civic_building_name_map = _build_civic_building_name_lookup(_latest_civic_buildings_by_id, seed_input.text.strip_edges(), "townsfolk")
	_latest_residence_type_map = level_data.get("residence_type_map", {}) as Dictionary
	_hold_state.active_level_stairs = level_data.get("stair_cells", {}) as Dictionary

	_chest_inventories.clear()
	_clear_chest_selection()
	_render_city(grid, _hold_state.active_level_stairs)
	_spawn_tavern_characters(grid)
	# After the NPC spawn (which rebuilds the actor layer's children).
	_furnish_interiors(grid)
	_build_farmsteads()
	_scatter_desert_decor()
	_spawn_farm_animals()
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


func _on_lighting_toggle_toggled(toggled_on: bool) -> void:
	_lighting_enabled = toggled_on
	_apply_lighting_state()

## Towns are open-air: the Shattered cave-fog mask that once rode this
## toggle blacked out the whole surface map, so it is permanently retired
## here (the dwarfhold keeps its underground darkness). "Enable lighting"
## now governs the hearth and candle glow pools instead.
func _apply_lighting_state() -> void:
	lighting_layer.visible = true
	if _light_overlay_sprite != null:
		_light_overlay_sprite.visible = _lighting_enabled
	for glow: Node2D in _glow_sprites:
		if is_instance_valid(glow):
			glow.visible = _lighting_enabled

func _render_city(grid: Dictionary, stair_cells: Dictionary = {}) -> void:
	if city_layer.tile_set == null:
		return
	city_layer.clear()
	decor_layer.clear()
	_surface_chunks.clear()
	_surface_last_player_chunk = Vector2i(2147483647, 2147483647)
	var bounds := _find_bounds(grid).grow(1)
	var house_decor_overrides := _build_house_decor_layouts(grid)
	_latest_bed_count = 0
	_bed_cells = []
	_green_cells = []
	for decor_cell_variant: Variant in house_decor_overrides.keys():
		var decor_key := String(house_decor_overrides[decor_cell_variant])
		if decor_key == "bed" or decor_key == "bed_alt":
			_latest_bed_count += 1
			_bed_cells.append(decor_cell_variant as Vector2i)
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := _cell_at(grid, x, y)
			var base_tile := _pick_base_tile(grid, x, y, cell)
			var render_cell := Vector2i(x, y)
			_place_tile(city_layer, render_cell, base_tile)
			var decor_tile := _pick_decor_tile(grid, x, y, cell, base_tile, house_decor_overrides)
			if cell == CELL_ROCK and decor_tile.is_empty():
				_green_cells.append(render_cell)
			if not decor_tile.is_empty():
				_place_tile(decor_layer, render_cell, decor_tile)
				if decor_tile == "chest":
					_ensure_chest_inventory(render_cell)
				if TALL_DECOR_TOPS.has(decor_tile):
					var top_cell := render_cell + Vector2i.UP
					if decor_layer.get_cell_source_id(top_cell) < 0:
						_place_tile(decor_layer, top_cell, String(TALL_DECOR_TOPS[decor_tile]))
	for stair_key: String in ["up", "down"]:
		if not stair_cells.has(stair_key):
			continue
		var stair_cell := stair_cells[stair_key] as Vector2i
		if city_layer.get_cell_source_id(stair_cell) < 0:
			continue
		_place_tile(city_layer, stair_cell, "stairway_up" if stair_key == "up" else "stairway_down")
		decor_layer.erase_cell(stair_cell)
		_actor_passable_cache.erase(stair_cell)
	_reset_view(bounds)

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
	# Loot flows into the same persistent backpack the underdeep uses;
	# coins go straight to the purse.
	for entry_variant: Variant in (_chest_inventories.get(_selected_chest_cell, []) as Array):
		var entry := entry_variant as Dictionary
		var item_name := String(entry.get("name", "Supplies"))
		if item_name == "Copper Coins":
			_adjust_coins(int(entry.get("quantity", 1)))
			continue
		_player_inventory[item_name] = int(_player_inventory.get(item_name, 0)) + int(entry.get("quantity", 1))
	_save_player_inventory()
	_populate_backpack_slots()
	_chest_inventories[_selected_chest_cell] = []
	_update_chest_inventory_panel()

func _on_chest_popup_close_button_pressed() -> void:
	_clear_chest_selection()

func _initialize_chest_popup_grids() -> void:
	_create_inventory_slots(chest_grid, CHEST_SLOT_COLUMNS * CHEST_SLOT_ROWS, _chest_slot_panels, _chest_slot_labels, _chest_slot_icons)
	_create_inventory_slots(backpack_grid, CHEST_SLOT_COLUMNS * BACKPACK_SLOT_ROWS, _backpack_slot_panels, _backpack_slot_labels, _backpack_slot_icons)
	_load_player_inventory()
	_populate_backpack_slots()
	_setup_coins_label()
	_setup_factions_panel()
	_escape_menu = EscapeMenu.new()
	_escape_menu.show_return_to_map = true
	add_child(_escape_menu)

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
			# Backpack slots sell while a shop trade is open; connections are
			# rebuilt with the panels, so they never stack.
			panel.gui_input.connect(_on_backpack_slot_gui_input.bind(out_panels.size()))
		elif target_grid == chest_grid:
			# Chest slots buy wares while a shop trade is open.
			panel.gui_input.connect(_on_chest_slot_gui_input.bind(out_panels.size()))
		target_grid.add_child(panel)
		out_panels.append(panel)
		out_labels.append(label)
		out_icons.append(icon_rect)

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

## Towns share the same persistent backpack as the underdeep.
## --- Farm animals ---------------------------------------------------------
## Chickens, pigs, and cows from the web game's Farm tileset wander the
## town greens. Sheets: columns 0=down 1=up 2=right (left is mirrored),
## rows are walk frames.

const FARM_ANIMAL_DEFS := [
	{"id": "chicken", "path": "res://resources/images/webgame_tiles/Farm/Tiled_files/Chicken_animation.png", "frame": 32, "speed": 26.0, "rows": 6},
	{"id": "pig", "path": "res://resources/images/webgame_tiles/Farm/Tiled_files/Pig_animation.png", "frame": 32, "speed": 22.0, "rows": 6},
	{"id": "cow", "path": "res://resources/images/webgame_tiles/Farm/Tiled_files/Cow_animation.png", "frame": 64, "speed": 16.0, "rows": 6}
]

## --- Interior furnishing: lived-in homes and stocked shops ------------------
## After the tile pass, every house gets template furniture (dining sets,
## pantries, cabinets, rugs, candles) and every shopfront gets stocked
## shelves and crates, as layered sprites from the web game's interior
## sheets. Hearths and candles cast warm light pools.

func _furnish_interiors(grid: Dictionary) -> void:
	for sprite: Node2D in _furnishing_sprites:
		sprite.queue_free()
	_furnishing_sprites.clear()
	_furnishing_blocked_cells.clear()
	_glow_sprites.clear()
	_pending_glows.clear()
	_actor_passable_cache.clear()
	if actor_layer == null:
		return
	var is_occupied := func(cell: Vector2i) -> bool:
		return decor_layer.get_cell_source_id(cell) >= 0
	# Houses get home comforts.
	for component_variant: Variant in RoomFurnishingService.collect_zone_components(grid, CELL_HOUSE):
		var component: Array[Vector2i] = []
		for cell_variant: Variant in (component_variant as Array):
			component.append(cell_variant as Vector2i)
		var placements: Array[Dictionary] = RoomFurnishingService.plan_house_furnishing(component, is_occupied, _door_cells, _rng)
		_apply_furnishing_placements(placements)
		_place_house_hearth(component, is_occupied)
	# Shops get stock on the shelves.
	for component_variant: Variant in RoomFurnishingService.collect_zone_components(grid, CELL_BUILDING):
		var component: Array[Vector2i] = []
		for cell_variant: Variant in (component_variant as Array):
			component.append(cell_variant as Vector2i)
		if component.is_empty():
			continue
		var building_type := String(_latest_civic_building_type_map.get(component[0], ""))
		var placements: Array[Dictionary] = RoomFurnishingService.plan_shop_dressing(component, building_type, is_occupied, _door_cells, _rng)
		_apply_furnishing_placements(placements)
	# Fire-bearing furniture anywhere on the map casts a warm pool.
	for cell: Vector2i in decor_layer.get_used_cells():
		var decor_key := _tile_name_from_atlas(decor_layer.get_cell_atlas_coords(cell))
		if ["forge", "oven", "brazier"].has(decor_key):
			_spawn_hearth_glow(cell, 3.4)
	_rebuild_light_overlay()

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
				_actor_passable_cache.erase(cell)
		if RoomFurnishingService.piece_emits_light(piece_name):
			_spawn_hearth_glow(base_cell, 2.4)

## Every roomy house earns a hearth on its north wall row: an oven tile,
## its chimney cap, and firelight.
func _place_house_hearth(component: Array[Vector2i], is_occupied: Callable) -> void:
	var interior: Array[Vector2i] = RoomFurnishingService.interior_cells(component)
	if interior.size() < 9:
		return
	var north_row := interior[0].y
	for cell: Vector2i in interior:
		north_row = mini(north_row, cell.y)
	for cell: Vector2i in interior:
		if cell.y != north_row:
			continue
		if bool(is_occupied.call(cell)) or _furnishing_blocked_cells.has(cell):
			continue
		var door_adjacent := false
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if _door_cells.has(cell + direction):
				door_adjacent = true
				break
		if door_adjacent:
			continue
		var occupied_or_furnished := func(check_cell: Vector2i) -> bool:
			return _furnishing_blocked_cells.has(check_cell) or bool(is_occupied.call(check_cell))
		var oven_block: Array[Vector2i] = [cell]
		if not RoomFurnishingService.block_keeps_room_open(oven_block, interior, occupied_or_furnished, _door_cells):
			continue
		_place_tile(decor_layer, cell, "oven")
		if decor_layer.get_cell_source_id(cell + Vector2i.UP) < 0:
			_place_tile(decor_layer, cell + Vector2i.UP, "oven_top")
		_spawn_hearth_glow(cell, 3.4)
		return

## Glows are recorded during furnishing and baked into ONE additive
## overlay texture afterwards - a single canvas item instead of a sprite
## per hearth and candle (the Core Keeper approach to static light).
const LIGHT_OVERLAY_PX_PER_TILE := 4

func _spawn_hearth_glow(cell: Vector2i, radius_cells: float) -> void:
	_pending_glows.append({"cell": cell, "radius": radius_cells})

func _rebuild_light_overlay() -> void:
	if _light_overlay_sprite != null:
		_light_overlay_sprite.queue_free()
		_light_overlay_sprite = null
	if _pending_glows.is_empty() or actor_layer == null:
		return
	var bounds := _find_bounds(_latest_grid).grow(6)
	var image_size := bounds.size * LIGHT_OVERLAY_PX_PER_TILE
	if image_size.x <= 0 or image_size.y <= 0 or image_size.x > 4096 or image_size.y > 4096:
		return
	var image := Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	var glow_color := Color(1.0, 0.72, 0.35, 1.0)
	for glow_variant: Variant in _pending_glows:
		var glow := glow_variant as Dictionary
		var cell := glow.get("cell", Vector2i.ZERO) as Vector2i
		var radius_px := float(glow.get("radius", 2.4)) * float(LIGHT_OVERLAY_PX_PER_TILE)
		var center := (Vector2(cell - bounds.position) + Vector2(0.5, 0.5)) * float(LIGHT_OVERLAY_PX_PER_TILE)
		var reach := int(ceilf(radius_px))
		for py in range(maxi(0, int(center.y) - reach), mini(image_size.y, int(center.y) + reach + 1)):
			for px in range(maxi(0, int(center.x) - reach), mini(image_size.x, int(center.x) + reach + 1)):
				var falloff := 1.0 - Vector2(px + 0.5, py + 0.5).distance_to(center) / radius_px
				if falloff <= 0.0:
					continue
				falloff *= falloff * 0.55
				var existing := image.get_pixel(px, py)
				image.set_pixel(px, py, Color(
					glow_color.r, glow_color.g, glow_color.b,
					minf(existing.a + falloff, 0.8)
				))
	_light_overlay_sprite = Sprite2D.new()
	_light_overlay_sprite.texture = ImageTexture.create_from_image(image)
	_light_overlay_sprite.centered = false
	_light_overlay_sprite.position = Vector2(bounds.position * tile_size)
	_light_overlay_sprite.scale = Vector2(tile_size) / float(LIGHT_OVERLAY_PX_PER_TILE)
	var overlay_material := CanvasItemMaterial.new()
	overlay_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light_overlay_sprite.material = overlay_material
	_light_overlay_sprite.z_index = 14
	_light_overlay_sprite.visible = _lighting_enabled
	actor_layer.add_child(_light_overlay_sprite)

## --- Farmsteads: real farm buildings on the town greens -------------------
## Each farmstead stakes out a rectangle of open grass and raises a
## farmhouse or barn, an animated windmill, a fenced animal pen, and a
## tilled crop plot from the web game's Farm tileset.

func _build_farmsteads() -> void:
	for sprite: Node2D in _farm_sprites:
		sprite.queue_free()
	_farm_sprites.clear()
	_farm_pens.clear()
	_farm_blocked_cells.clear()
	_windmill_sails.clear()
	_actor_passable_cache.clear()
	if actor_layer == null or _town_theme == "desert" or _green_cells.is_empty():
		return
	var farm_target := clampi(_green_cells.size() / 260, 1, 3)
	var origins: Array[Vector2i] = []
	var candidates := _green_cells.duplicate()
	_seeded_shuffle(candidates)
	for candidate_variant: Variant in candidates:
		if origins.size() >= farm_target:
			break
		var origin := candidate_variant as Vector2i
		if not _farmstead_site_fits(origin):
			continue
		var too_close := false
		for existing: Vector2i in origins:
			if Vector2(existing).distance_to(Vector2(origin)) < 16.0:
				too_close = true
				break
		if too_close:
			continue
		# Clear the brush: trees and hedges on the site make way for the farm.
		for y in range(FARMSTEAD_SITE.y):
			for x in range(FARMSTEAD_SITE.x):
				decor_layer.erase_cell(origin + Vector2i(x, y))
				_actor_passable_cache.erase(origin + Vector2i(x, y))
		origins.append(origin)
		_stamp_farmstead(origin, origins.size() == 1)
	# Farmstead ground is spoken for: animals and future farms keep off it.
	if not origins.is_empty():
		var occupied: Dictionary = {}
		for origin: Vector2i in origins:
			for y in range(FARMSTEAD_SITE.y):
				for x in range(FARMSTEAD_SITE.x):
					occupied[origin + Vector2i(x, y)] = true
		var remaining: Array[Vector2i] = []
		for cell: Vector2i in _green_cells:
			if not occupied.has(cell):
				remaining.append(cell)
		_green_cells = remaining

## A farmstead site is open grassland: grass-family base tiles, with only
## removable greenery (trees, hedges, flowers) as decor.
func _farmstead_site_fits(origin: Vector2i) -> bool:
	var removable: Array[Vector2i] = []
	for key: String in ["tree", "tree_dark", "hedge", "hedge_alt", "flowers_white", "flowers_yellow"]:
		removable.append(TILE_ATLAS.get(key, Vector2i(-1, -1)) as Vector2i)
	for y in range(FARMSTEAD_SITE.y):
		for x in range(FARMSTEAD_SITE.x):
			var cell := origin + Vector2i(x, y)
			if city_layer.get_cell_source_id(cell) < 0:
				return false
			if _cell_at(_latest_grid, cell.x, cell.y) != CELL_ROCK:
				return false
			if decor_layer.get_cell_source_id(cell) >= 0 and not removable.has(decor_layer.get_cell_atlas_coords(cell)):
				return false
	return true

func _stamp_farmstead(origin: Vector2i, with_windmill: bool) -> void:
	# Farmhouse or barn over the top-left quarter.
	var building_keys: Array[String] = ["farmhouse", "barn", "open_barn"]
	var building_key := building_keys[0] if with_windmill else building_keys[_rng.randi_range(1, building_keys.size() - 1)]
	var building_crop := FARM_BUILDING_CROPS[building_key] as Rect2
	var building_sprite := _spawn_farm_sprite(FARM_HOUSES_TEXTURE, building_crop, Vector2(origin * tile_size), 10)
	var building_cells := Vector2i(ceili(building_crop.size.x / float(tile_size.x)), ceili(building_crop.size.y / float(tile_size.y)))
	# Anchor the sprite so its base sits on the site's building rows.
	building_sprite.position = Vector2(origin * tile_size) + Vector2(0.0, float(5 * tile_size.y) - building_crop.size.y)
	for y in range(mini(building_cells.y, 5)):
		for x in range(building_cells.x):
			_farm_blocked_cells[origin + Vector2i(x, 5 - 1 - y)] = true
			_actor_passable_cache.erase(origin + Vector2i(x, 5 - 1 - y))

	# Windmill tower with spinning sails to the building's right.
	if with_windmill:
		var body_origin := Vector2(origin * tile_size) + Vector2(float(7 * tile_size.x), float(5 * tile_size.y) - WINDMILL_BODY_CROP.size.y)
		_spawn_farm_sprite(FARM_HOUSES_TEXTURE, WINDMILL_BODY_CROP, body_origin, 10)
		for y in range(5):
			for x in range(2):
				_farm_blocked_cells[origin + Vector2i(7 + x, y)] = true
				_actor_passable_cache.erase(origin + Vector2i(7 + x, y))
		var sails := Sprite2D.new()
		sails.texture = FARM_SAILS_TEXTURE
		sails.region_enabled = true
		sails.centered = true
		sails.region_rect = Rect2(Vector2.ZERO, SAIL_FRAME)
		sails.position = body_origin + Vector2(WINDMILL_BODY_CROP.size.x * 0.5, 44.0)
		sails.z_index = 12
		actor_layer.add_child(sails)
		_farm_sprites.append(sails)
		_windmill_sails.append({"sprite": sails, "anim_time": _rng.randf_range(0.0, 2.0)})

	# Fenced pen along the bottom-left, with a gate gap on its south side.
	var pen_rect := Rect2i(origin + Vector2i(0, 5), Vector2i(6, 4))
	var gate_cell := Vector2i(pen_rect.position.x + pen_rect.size.x / 2, pen_rect.end.y - 1)
	var pen_cells: Array[Vector2i] = []
	for y in range(pen_rect.position.y, pen_rect.end.y):
		for x in range(pen_rect.position.x, pen_rect.end.x):
			var cell := Vector2i(x, y)
			var on_edge := x == pen_rect.position.x or x == pen_rect.end.x - 1 or y == pen_rect.position.y or y == pen_rect.end.y - 1
			if on_edge and cell != gate_cell:
				# Rails run along the top and bottom; posts hold the sides.
				var side := x == pen_rect.position.x or x == pen_rect.end.x - 1
				_place_tile(decor_layer, cell, "fence_post" if side else "fence")
			elif not on_edge:
				pen_cells.append(cell)
	if not pen_cells.is_empty():
		_farm_pens.append(pen_cells)

	# Tilled crop plot on the bottom-right: sandy soil in crop rows.
	var crop_rect := Rect2i(origin + Vector2i(7, 5), Vector2i(3, 4))
	var crop_art := FARM_CROP_RECTS[_rng.randi_range(0, FARM_CROP_RECTS.size() - 1)]
	for y in range(crop_rect.position.y, crop_rect.end.y):
		for x in range(crop_rect.position.x, crop_rect.end.x):
			_place_tile(city_layer, Vector2i(x, y), "sand")
			var plant := Sprite2D.new()
			plant.texture = FARM_PLANTS_TEXTURE
			plant.region_enabled = true
			plant.centered = true
			plant.region_rect = crop_art
			plant.position = _cell_center_position(Vector2i(x, y)) - Vector2(0.0, crop_art.size.y * 0.5 - float(tile_size.y) * 0.25)
			plant.z_index = 9
			actor_layer.add_child(plant)
			_farm_sprites.append(plant)

func _spawn_farm_sprite(texture: Texture2D, crop: Rect2, top_left: Vector2, z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.centered = false
	sprite.region_rect = crop
	sprite.position = top_left
	sprite.z_index = z
	actor_layer.add_child(sprite)
	_farm_sprites.append(sprite)
	return sprite

func _update_windmill_sails(delta: float) -> void:
	for entry: Dictionary in _windmill_sails:
		var sprite := entry.get("sprite") as Sprite2D
		if sprite == null:
			continue
		var anim_time := float(entry.get("anim_time", 0.0)) + delta
		entry["anim_time"] = anim_time
		var frame := int(anim_time / SAIL_FRAME_TIME) % SAIL_FRAME_COUNT
		sprite.region_rect = Rect2(Vector2(0.0, frame * SAIL_FRAME.y), SAIL_FRAME)

## Desert-city dressing: cacti, bleached bones, dry roots and half-buried
## statues scattered over the sand where a green town would grow trees.
func _scatter_desert_decor() -> void:
	if _town_theme != "desert" or actor_layer == null or _green_cells.is_empty():
		return
	var decor_count := clampi(_green_cells.size() / 36, 8, 30)
	var used_cells: Dictionary = {}
	for decor_index in range(decor_count):
		var cell := _green_cells[_rng.randi_range(0, _green_cells.size() - 1)]
		if used_cells.has(cell):
			continue
		used_cells[cell] = true
		var rare := decor_index < 2 and _rng.randf() < 0.6
		var pool := DESERT_DECOR_RARE if rare else DESERT_DECOR_COMMON
		var file_name := pool[_rng.randi_range(0, pool.size() - 1)]
		var texture := _desert_decor_texture(file_name)
		if texture == null:
			continue
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = true
		sprite.position = _cell_center_position(cell)
		sprite.z_index = 9
		actor_layer.add_child(sprite)
		_farm_sprites.append(sprite)

func _desert_decor_texture(file_name: String) -> Texture2D:
	if not _desert_decor_textures.has(file_name):
		_desert_decor_textures[file_name] = load(DESERT_DECOR_DIR + file_name) as Texture2D
	return _desert_decor_textures.get(file_name) as Texture2D

func _spawn_farm_animals() -> void:
	for state: Dictionary in _farm_animals:
		var old_sprite := state.get("sprite") as Sprite2D
		if old_sprite != null:
			old_sprite.queue_free()
	_farm_animals.clear()
	if actor_layer == null or _town_theme == "desert":
		return
	# Penned animals first: every farmstead pen gets its own little herd.
	for pen_index in range(_farm_pens.size()):
		var pen_cells := _farm_pens[pen_index] as Array
		var herd_size := _rng.randi_range(2, 3)
		for _herd_index in range(herd_size):
			var pen_cell := pen_cells[_rng.randi_range(0, pen_cells.size() - 1)] as Vector2i
			_spawn_farm_animal_at(pen_cell, pen_index)
	if not _green_cells.is_empty():
		var animal_count := clampi(_green_cells.size() / 14, 4, 10)
		for _animal_index in range(animal_count):
			var cell := _green_cells[_rng.randi_range(0, _green_cells.size() - 1)]
			_spawn_farm_animal_at(cell, -1)
	_restore_owned_animals()

func _spawn_farm_animal_at(cell: Vector2i, pen_index: int) -> void:
	var def := FARM_ANIMAL_DEFS[_rng.randi_range(0, FARM_ANIMAL_DEFS.size() - 1)] as Dictionary
	var animal_id := String(def.get("id", "chicken"))
	if not _farm_animal_textures.has(animal_id):
		_farm_animal_textures[animal_id] = load(String(def.get("path", ""))) as Texture2D
	var texture := _farm_animal_textures.get(animal_id) as Texture2D
	if texture == null:
		return
	var frame_px := int(def.get("frame", 32))
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.centered = true
	sprite.region_rect = Rect2(0, 0, frame_px, frame_px)
	sprite.scale = Vector2.ONE * (float(tile_size.y) / float(frame_px)) * 0.9
	sprite.position = _cell_center_position(cell)
	sprite.z_index = 11
	actor_layer.add_child(sprite)
	_farm_animals.append({
		"def": def,
		"sprite": sprite,
		"cell": cell,
		"pen_index": pen_index,
		"moving": false,
		"facing": Vector2i(0, 1),
		"wander_timer": _rng.randf_range(0.5, 4.0),
		"anim_time": _rng.randf_range(0.0, 2.0)
	})

func _update_farm_animals(delta: float) -> void:
	for state: Dictionary in _farm_animals:
		var sprite := state.get("sprite") as Sprite2D
		if sprite == null:
			continue
		var def := state.get("def", {}) as Dictionary
		state["anim_time"] = float(state.get("anim_time", 0.0)) + delta
		if bool(state.get("moving", false)):
			var target := state.get("move_target", sprite.position) as Vector2
			sprite.position = sprite.position.move_toward(target, float(def.get("speed", 20.0)) * delta)
			if sprite.position.distance_to(target) <= 0.5:
				sprite.position = target
				state["cell"] = state.get("move_cell", state.get("cell", Vector2i.ZERO)) as Vector2i
				state["moving"] = false
		else:
			state["wander_timer"] = float(state.get("wander_timer", 0.0)) - delta
			if float(state.get("wander_timer", 0.0)) <= 0.0:
				state["wander_timer"] = _rng.randf_range(1.5, 5.0)
				var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
				var step := directions[_rng.randi_range(0, 3)]
				var next_cell := (state.get("cell", Vector2i.ZERO) as Vector2i) + step
				# Animals keep to the greens; penned animals keep to their pen.
				var pen_index := int(state.get("pen_index", -1))
				var allowed: bool
				if pen_index == -2:
					var home := state.get("home", state.get("cell", Vector2i.ZERO)) as Vector2i
					allowed = maxi(absi(next_cell.x - home.x), absi(next_cell.y - home.y)) <= 3 and _is_passable_cell_for_actor(next_cell)
				elif pen_index >= 0 and pen_index < _farm_pens.size():
					allowed = (_farm_pens[pen_index] as Array).has(next_cell)
				else:
					allowed = _green_cells.has(next_cell)
				if allowed and not bool(state.get("moving", false)):
					state["moving"] = true
					state["move_cell"] = next_cell
					state["move_target"] = _cell_center_position(next_cell)
					state["facing"] = step
		_animate_farm_animal(state, sprite, def)

func _animate_farm_animal(state: Dictionary, sprite: Sprite2D, def: Dictionary) -> void:
	var frame_px := int(def.get("frame", 32))
	var facing := state.get("facing", Vector2i(0, 1)) as Vector2i
	var column := 0
	sprite.flip_h = false
	if facing == Vector2i.UP:
		column = 1
	elif facing == Vector2i.RIGHT:
		column = 2
	elif facing == Vector2i.LEFT:
		column = 2
		sprite.flip_h = true
	var row_count := int(def.get("rows", 6))
	var row := 0
	if bool(state.get("moving", false)):
		row = int(float(state.get("anim_time", 0.0)) * 8.0) % row_count
	sprite.region_rect = Rect2(column * frame_px, row * frame_px, frame_px, frame_px)

## --- The living world: coins, shops, and talk ----------------------------
## Same economy as the underdeep: coins buy from shop buildings (smithy,
## bakery, tavern, general store, market stall, apothecary...), the
## backpack sells for half worth, and townsfolk pass on local rumors.

func _adjust_coins(amount: int) -> void:
	_player_coins = maxi(_player_coins + amount, 0)
	_update_coins_label()
	_update_gear_label()
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
	return 1.0 + float(absi(hash(seed_input.text.strip_edges())) % 40) / 100.0

func _is_trade_mode() -> bool:
	return _trade_shop_cell.x != 2147483647

func _open_trade_popup(cell: Vector2i, shop_type: String) -> void:
	var anchor := _shop_anchor_for_cell(cell)
	if not _shop_stocks.has(anchor):
		var stock_rng := RandomNumberGenerator.new()
		stock_rng.seed = hash(seed_input.text.strip_edges()) ^ hash(anchor)
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
	_player_inventory[item_name] = int(_player_inventory.get(item_name, 0)) + 1
	_save_player_inventory()
	_refresh_trade_panel()
	chest_popup_status_label.text = "Bought %s for %d coins (🪙 %d left)" % [item_name, price, _player_coins]

func _sell_item(item_name: String) -> void:
	if int(_player_inventory.get(item_name, 0)) < 1:
		return
	var price := SettlementEconomyService.sell_price(item_name)
	_player_inventory[item_name] = int(_player_inventory.get(item_name, 0)) - 1
	if int(_player_inventory.get(item_name, 0)) <= 0:
		_player_inventory.erase(item_name)
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

## Backpack clicks in towns sell while a trade is open (no eating above
## ground - towns have no hearts system yet).
func _on_backpack_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not _is_trade_mode():
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if slot_index < 0 or slot_index >= _backpack_slot_items.size():
		return
	_sell_item(_backpack_slot_items[slot_index])

func _end_trade_mode() -> void:
	_trade_shop_cell = Vector2i(2147483647, 2147483647)
	_trade_shop_type = ""

func _npc_state_at_cell(cell: Vector2i) -> Dictionary:
	for state: Dictionary in _npc_states:
		if (state.get("cell", Vector2i(2147483647, 2147483647)) as Vector2i) == cell:
			return state
	return {}

## Every villager is somebody: identities are rolled once at spawn from
## the town's seeded rng, so the same seed always houses the same folk.
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
		var layers := NpcIdentityService.appearance_for_identity(identity, "human")
		var cache_key := str(layers)
		if not texture_cache.has(cache_key):
			texture_cache[cache_key] = DwarfSpriteComposer.compose(layers)
		sprite.texture = texture_cache[cache_key]
		sprite.region_enabled = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(
			float(tile_size.x) / 32.0,
			float(tile_size.y) / 32.0
		) * 0.9 * float(layers.get("body_scale", 1.0))
		state["composed"] = true

func _assign_npc_identities() -> void:
	var used_names: Dictionary = {}
	for state: Dictionary in _npc_states:
		var role_title := String(ROLE_TITLES.get(int(state.get("role", 0)), "Villager"))
		var identity: Dictionary = NpcIdentityService.generate(_rng, role_title, "townsfolk")
		# Nobody shares a full name: spouse/parent/faction references are
		# by name, so collisions would tangle the whole census.
		for _reroll in 8:
			if not used_names.has(String(identity.get("name", ""))):
				break
			identity = NpcIdentityService.generate(_rng, role_title, "townsfolk")
		if used_names.has(String(identity.get("name", ""))):
			identity["name"] = "%s the Younger" % String(identity.get("name", ""))
		used_names[String(identity.get("name", ""))] = true
		state["identity"] = identity
		state["npc_name"] = String(identity.get("name", "A villager"))

## The town's guilds and societies: rolled per generation from the
## seeded rng, recruited from the identity roster, and listed in the
## sidebar. Members answer their faction's meeting bell through the
## scheduler.
## Kinship: couples share a surname, a roof and usually an altar; the
## young are raised as their children. Runs before faces are composed
## so adopted surnames reshape the family resemblance too.
func _assign_npc_families() -> void:
	var family_stats := SettlementFamilyService.build_families(_npc_states, "townsfolk", _rng)
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
		"town", _hold_state.selected_hold_population, building_cells_by_type, _rng
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
	var role_title := String(ROLE_TITLES.get(int(state.get("role", 0)), "Villager"))
	if not state.has("identity"):
		state["identity"] = NpcIdentityService.generate(_rng, role_title, "townsfolk")
		state["npc_name"] = String((state["identity"] as Dictionary).get("name", "A villager"))
	var identity := state.get("identity", {}) as Dictionary
	# Sworn members talk about their faction, others gossip about the
	# guilds, and everyone still has personal news and town rumors.
	var line: String
	var faction_roll := _rng.randf()
	if state.has("faction_name") and faction_roll < 0.35:
		line = SettlementEconomyService.dialogue_line(role_title, SettlementFactionService.member_line(state, _rng), _rng)
	elif faction_roll < 0.5 and not _settlement_factions.is_empty():
		line = SettlementEconomyService.dialogue_line(role_title, SettlementFactionService.faction_rumor(_settlement_factions, _rng), _rng)
	elif _rng.randf() < 0.4:
		line = SettlementEconomyService.dialogue_line(role_title, NpcIdentityService.personal_line(identity, _rng), _rng)
	else:
		var rumor: String = SettlementEconomyService.rumor_from_town_details(_town_details, _rng)
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

func _load_player_inventory() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	var inventory_variant: Variant = settings.get("player_inventory", {})
	_player_inventory = (inventory_variant as Dictionary).duplicate() if inventory_variant is Dictionary else {}
	_player_coins = int(settings.get("player_coins", 0))
	# Old saves wore gear as flags; hang it on the paper doll once.
	if GearService.ensure_equipment_migrated(settings, _player_inventory):
		game_session.call("set_world_settings", settings)
		_save_player_inventory()

func _save_player_inventory() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings") or not game_session.has_method("set_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	settings["player_inventory"] = _player_inventory.duplicate()
	settings["player_coins"] = _player_coins
	game_session.call("set_world_settings", settings)

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

func _item_abbreviation(item_name: String) -> String:
	return DwarfHoldChestService.item_abbreviation(item_name)

func _build_house_decor_layouts(grid: Dictionary) -> Dictionary:
	return TownTileService.build_house_decor_layouts(grid, _latest_residence_type_map, _door_cells)

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
	_player_home_cell = _player_cell
	_ensure_companion()
	_pending_player_spawn_cell = Vector2i(2147483647, 2147483647)
	_assign_npc_daily_lives(grid)
	_assign_npc_identities()
	_assign_npc_families()
	_assign_settlement_factions()
	SettlementAfflictionService.seed_afflictions(_npc_states, _rng)
	_apply_affliction_visuals()
	_apply_identity_appearances()
	if _player_sprite != null:
		_center_view_on_cell(_player_cell)

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
		"green_cells": _green_cells,
		"is_walkable": Callable(self, "_is_walkable_cell"),
		"rng": _rng,
		"guard_role": ROLE_GUARD,
		"green_role": ROLE_FARMER,
		"role_workplaces": ROLE_WORKPLACES,
		"filler_roles": [ROLE_VILLAGER, ROLE_VILLAGER_WOMAN],
		"role_quotas": [
			{"role": ROLE_GUARD, "count": maxi(2, npc_count / 12)},
			{"role": ROLE_BLACKSMITH, "count": mini(npc_count / 10, (building_cells_by_type.get("smithy", []) as Array).size() * 2 + 1)},
			{"role": ROLE_MERCHANT, "count": mini(maxi(1, npc_count / 8), (building_cells_by_type.get("market_stall", []) as Array).size() + (building_cells_by_type.get("general_store", []) as Array).size() * 2 + 1)},
			{"role": ROLE_CLERIC, "count": mini(maxi(1, npc_count / 20), (building_cells_by_type.get("chapel", []) as Array).size() * 2 + 1)},
			{"role": ROLE_FARMER, "count": maxi(1, npc_count / 8)},
			{"role": ROLE_ELDER, "count": maxi(1, npc_count / 10)}
		]
	})
	# Start everyone where their schedule already puts them.
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

func _handle_player_click_action(mouse_position: Vector2) -> void:
	if _player_sprite == null or not _player_control_enabled:
		return
	var clicked_cell := _cell_from_mouse_position(mouse_position)
	if _build_selection >= 0 and _try_place_town_build(clicked_cell):
		return
	if _is_chest_cell(clicked_cell):
		_request_chest_interaction(clicked_cell)
		return
	var creature_index := _surface_creature_index_at_cell(clicked_cell)
	if creature_index >= 0:
		if _is_player_adjacent_to_cell(clicked_cell):
			_attack_surface_creature(creature_index)
			return
		if _try_ranged_attack_town(creature_index, clicked_cell):
			return
	var npc_state := _npc_state_at_cell(clicked_cell)
	if not npc_state.is_empty() and _is_player_adjacent_to_cell(clicked_cell):
		# You don't chat with the risen dead - you put them down.
		if SettlementAfflictionService.is_active_zombie(npc_state):
			var swing := int(PlayerStatsService.for_session(self).get("attack", 2))
			npc_state["zombie_hp"] = int(npc_state.get("zombie_hp", 6)) - swing
			var zombie_sprite := npc_state.get("sprite") as Sprite2D
			if zombie_sprite != null and has_method("_spawn_floating_text"):
				call("_spawn_floating_text", "-%d" % swing, zombie_sprite.position, Color(1.0, 0.85, 0.5, 1.0))
			if int(npc_state.get("zombie_hp", 0)) <= 0:
				npc_state["affliction_dead"] = true
				_remove_dead_afflicted()
				_set_save_status("The corpse falls still at last.", Color(0.8, 0.85, 0.7, 1.0))
			return
		if bool(npc_state.get("traveler", false)) and _try_open_traveler_trade(npc_state):
			return
		_show_npc_dialogue(npc_state)
		return
	var shop_type := _shop_type_at_cell(clicked_cell)
	if not shop_type.is_empty() and _is_player_adjacent_to_cell(clicked_cell):
		_open_trade_popup(clicked_cell, shop_type)
		return
	if _try_boat_action(clicked_cell):
		return
	if _try_farm_action(clicked_cell):
		return
	if _try_collect_produce(clicked_cell):
		return
	if _try_release_animal(clicked_cell):
		return
	if _try_chop_tree(clicked_cell):
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
		if atlas == TILE_ATLAS.get("stairway_up", Vector2i(-1000, -1000)):
			return "up"
		if atlas == TILE_ATLAS.get("stairway_down", Vector2i(-1000, -1000)):
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
	# The wilds stream forever; an unreachable click must not flood them.
	while head < queue.size() and visited.size() < 8000:
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
	if _player_boating:
		# Afloat: water is the road; solid ground means stepping ashore.
		if not _is_water_cell(target_cell):
			if _is_walkable_cell(target_cell) and not _is_cell_occupied_by_npc(target_cell):
				_set_boating(false)
			else:
				return false
	elif not _is_walkable_cell(target_cell):
		if _is_water_cell(target_cell) and int(_player_inventory.get("Coracle", 0)) > 0:
			_set_boating(true)
		else:
			return false
	if _is_cell_occupied_by_npc(target_cell):
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
		Callable(self, "_cell_center_position")
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
		if SettlementAfflictionService.is_active_zombie(state) or bool(state.get("traveler", false)) or bool(state.get("raid_duty", false)):
			continue
		living.append(state)
	return living

## Clock-scale affliction bookkeeping: recovery, deaths, incubations,
## contagion, and vampires caught out in the sun.
func _advance_afflictions(delta_hours: float) -> void:
	if _npc_states.is_empty() or delta_hours <= 0.0:
		return
	var day_hour := _game_hour >= 6.0 and _game_hour < 20.0
	var affliction_events := SettlementAfflictionService.advance(_npc_states, delta_hours, _rng, true, day_hour)
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

## --- The open surface world --------------------------------------------
## Core Keeper above ground: wild chunks generate around the player as
## they wander past the town edge and evaporate when left behind,
## rebuilt identically from the seed on return. The town itself is
## never touched.

const SURFACE_GEN_RADIUS := 2
const SURFACE_EVICT_RADIUS := 4

## Every town's wilds live in ONE shared world space: an overworld tile
## spans WORLD_CELLS_PER_OVERWORLD_TILE local cells, terrain derives
## from the world seed at absolute world coordinates, and the gazetteer
## places every neighboring site at its true walking distance - with
## roads leading there and an arrival gate that hands the walker over
## to that site's own scene.
const WORLD_CELLS_PER_OVERWORLD_TILE := 64
const SURFACE_SITE_REACH_TILES := 20
const SURFACE_ROAD_COUNT := 4

func _setup_surface_world(grid: Dictionary) -> void:
	for gate_label: Label in _surface_gate_labels:
		if is_instance_valid(gate_label):
			gate_label.queue_free()
	_surface_gate_labels.clear()
	_surface_road_cells.clear()
	_surface_road_paths.clear()
	_surface_gates.clear()
	_surface_anchor_cells.clear()
	_surface_arrival_lock = false
	for creature: Dictionary in _surface_creatures:
		var creature_sprite := creature.get("sprite") as Sprite2D
		if creature_sprite != null:
			creature_sprite.queue_free()
	_surface_creatures.clear()
	_raid_active = false
	_wall_damage.clear()
	CompanionService.despawn(_companion)
	_companion = {}
	for state_index in range(_npc_states.size() - 1, -1, -1):
		if bool(_npc_states[state_index].get("traveler", false)):
			var traveler_sprite := _npc_states[state_index].get("sprite") as Sprite2D
			if traveler_sprite != null:
				traveler_sprite.queue_free()
			_npc_states.remove_at(state_index)
	var seed_text := seed_input.text.strip_edges()
	var settings: Dictionary = {}
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null and game_session.has_method("get_world_settings"):
		settings = game_session.call("get_world_settings")
	var world_seed_text := str(settings.get("world_seed", seed_text))
	_surface_noise = SurfaceWorldService.make_noise_set(hash("surface|%s" % world_seed_text))
	var min_cell := Vector2i(2147483647, 2147483647)
	var max_cell := Vector2i(-2147483648, -2147483648)
	for cell_variant: Variant in grid.keys():
		var cell := cell_variant as Vector2i
		min_cell = Vector2i(mini(min_cell.x, cell.x), mini(min_cell.y, cell.y))
		max_cell = Vector2i(maxi(max_cell.x, cell.x), maxi(max_cell.y, cell.y))
	if min_cell.x == 2147483647:
		_surface_protect_rect = Rect2i()
		return
	_surface_protect_rect = Rect2i(min_cell, max_cell - min_cell + Vector2i.ONE).grow(8)
	# Anchor: this town's grid center sits at the middle of its own
	# overworld tile in shared world space.
	var own_tile_variant: Variant = settings.get(TOWN_SCENE_TILE_KEY)
	var own_tile := Vector2i.ZERO
	if own_tile_variant is Dictionary:
		own_tile = Vector2i(int((own_tile_variant as Dictionary).get("x", 0)), int((own_tile_variant as Dictionary).get("y", 0)))
	var bbox_center := min_cell + (max_cell - min_cell) / 2
	_surface_world_origin = own_tile * WORLD_CELLS_PER_OVERWORLD_TILE + Vector2i(WORLD_CELLS_PER_OVERWORLD_TILE / 2, WORLD_CELLS_PER_OVERWORLD_TILE / 2) - bbox_center
	_plan_surface_sites(own_tile, bbox_center, settings)
	_restore_homestead(settings)

## Neighboring gazetteer sites become gates in the wilds, the nearest
## few joined to town by a dirt road.
func _plan_surface_sites(own_tile: Vector2i, town_center: Vector2i, settings: Dictionary) -> void:
	var reachable: Array[Dictionary] = []
	for site_variant: Variant in WorldSitesService.sites_from_settings(settings):
		var site := site_variant as Dictionary
		var tile: Vector2i = WorldSitesService.site_tile(site)
		if tile == own_tile:
			continue
		if WorldSitesService.scene_path_for(site).is_empty():
			continue
		var tile_distance := maxi(absi(tile.x - own_tile.x), absi(tile.y - own_tile.y))
		if tile_distance > SURFACE_SITE_REACH_TILES:
			continue
		var anchor: Vector2i = tile * WORLD_CELLS_PER_OVERWORLD_TILE + Vector2i(WORLD_CELLS_PER_OVERWORLD_TILE / 2, WORLD_CELLS_PER_OVERWORLD_TILE / 2) - _surface_world_origin
		reachable.append({"site": site, "anchor": anchor, "distance": tile_distance})
	reachable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("distance", 0)) < int(b.get("distance", 0)))
	_surface_anchor_cells.append(town_center)
	for entry_index in reachable.size():
		var entry := reachable[entry_index]
		var anchor := entry.get("anchor", Vector2i.ZERO) as Vector2i
		# Settlements greet from their whole clearing; a hold's carved
		# mountain door and a dungeon's mouth only open at the door itself.
		var trigger_cells: Array[Vector2i] = []
		match String((entry.get("site", {}) as Dictionary).get("class", "")):
			"dwarfhold", "dungeon":
				trigger_cells = [anchor, anchor + Vector2i(0, 1)]
		_surface_gates.append({
			"rect": Rect2i(anchor - Vector2i(3, 3), Vector2i(7, 7)),
			"anchor": anchor,
			"site": entry.get("site", {}),
			"stamped": false,
			"trigger_cells": trigger_cells,
			"label": null
		})
		_surface_anchor_cells.append(anchor)
		if entry_index < SURFACE_ROAD_COUNT:
			_trace_surface_road(town_center, anchor)

## A two-cell-wide dirt road, cell by cell, into the shared road map -
## and an ordered polyline travelers can walk.
func _trace_surface_road(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var delta := to_cell - from_cell
	var steps := maxi(absi(delta.x), absi(delta.y))
	if steps <= 0:
		return
	var path: Array = []
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		var cell := Vector2i(roundi(lerpf(from_cell.x, to_cell.x, t)), roundi(lerpf(from_cell.y, to_cell.y, t)))
		_surface_road_cells[cell] = true
		_surface_road_cells[cell + (Vector2i(1, 0) if absi(delta.y) >= absi(delta.x) else Vector2i(0, 1))] = true
		path.append(cell)
	_surface_road_paths.append(path)

## The tileset has no truly dark grass, so the gloom is painted with
## modulated alternative tiles: four danger buckets, each a dimmer,
## colder cast of the same terrain. Bucket 0 is the plain tile.
const SURFACE_SHADES := [1.0, 0.88, 0.76, 0.64]

func _danger_shade_bucket(danger: float) -> int:
	if danger < 0.35:
		return 0
	if danger < 0.55:
		return 1
	if danger < 0.75:
		return 2
	return 3

func _place_surface_tile(target_layer: TileMapLayer, cell: Vector2i, tile_key: String, danger: float) -> void:
	var bucket := _danger_shade_bucket(danger)
	if bucket == 0:
		_place_tile(target_layer, cell, tile_key)
		return
	var atlas_coords := TILE_ATLAS.get(tile_key, Vector2i(-1, -1)) as Vector2i
	if atlas_coords.x < 0:
		return
	target_layer.set_cell(cell, 0, atlas_coords, _shaded_alternative(target_layer.tile_set, atlas_coords, bucket))
	_actor_passable_cache.erase(cell)

## Alternative ids are deterministic (100 + bucket), so regeneration and
## revisits reuse the same handful instead of leaking new ones.
func _shaded_alternative(layer_tile_set: TileSet, atlas_coords: Vector2i, bucket: int) -> int:
	var source := layer_tile_set.get_source(0) as TileSetAtlasSource
	if source == null or not source.has_tile(atlas_coords):
		return 0
	var alternative_id := 100 + bucket
	if not source.has_alternative_tile(atlas_coords, alternative_id):
		if source.create_alternative_tile(atlas_coords, alternative_id) != alternative_id:
			return 0
		var shade := float(SURFACE_SHADES[bucket])
		source.get_tile_data(atlas_coords, alternative_id).modulate = Color(shade * 0.94, shade, shade * 1.05, 1.0)
	return alternative_id

func _stream_surface_chunks() -> void:
	if _surface_noise.is_empty() or _player_sprite == null:
		return
	var player_chunk: Vector2i = SurfaceWorldService.chunk_for_cell(_player_cell)
	if player_chunk == _surface_last_player_chunk:
		return
	_surface_last_player_chunk = player_chunk
	for chunk_dy in range(-SURFACE_GEN_RADIUS, SURFACE_GEN_RADIUS + 1):
		for chunk_dx in range(-SURFACE_GEN_RADIUS, SURFACE_GEN_RADIUS + 1):
			_ensure_surface_chunk(player_chunk + Vector2i(chunk_dx, chunk_dy))
	_evict_far_surface_chunks(player_chunk)

func _ensure_surface_chunk(chunk: Vector2i) -> void:
	if _surface_chunks.has(chunk):
		return
	var painted: Array[Vector2i] = []
	var rect: Rect2i = SurfaceWorldService.chunk_rect(chunk)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			# Anything the town rendered stays exactly as built; the wilds
			# fill every void right up to its walls.
			if _latest_grid.has(cell) or city_layer.get_cell_source_id(cell) >= 0:
				continue
			var danger := SurfaceLifeService.danger_for_cell(cell, _surface_anchor_cells)
			var terrain: Dictionary = SurfaceWorldService.terrain_for_cell(cell + _surface_world_origin, _surface_noise, danger)
			var base_key := String(terrain.get("base", "grass"))
			var decor_key := String(terrain.get("decor", ""))
			# Flowers are transparent overlays: grass beneath, bloom above.
			if base_key.begins_with("flowers_"):
				decor_key = base_key
				base_key = "grass"
			# Roads cut through everything and stay clear of trees.
			if _surface_road_cells.has(cell):
				base_key = "road" if (cell.x + cell.y) % 3 != 0 else "road_twig"
				decor_key = ""
			_place_surface_tile(city_layer, cell, base_key, danger)
			if not decor_key.is_empty():
				_place_surface_tile(decor_layer, cell, decor_key, danger)
			if _player_built_cells.has(cell):
				_stamp_player_build(cell, String(_player_built_cells[cell]))
			elif _farm_plots.has(cell):
				_stamp_farm_plot(cell)
			painted.append(cell)
	_surface_chunks[chunk] = painted
	_stamp_gates_in_rect(rect)

## A gate is the far site's doorstep in the wilds. Settlements greet you
## with a paved clearing; a dwarfhold shows the carved mountain door you
## descend through; a dungeon is a dark mouth in the ground. All bear the
## site's name floating above.
func _stamp_gates_in_rect(rect: Rect2i) -> void:
	for gate: Dictionary in _surface_gates:
		if bool(gate.get("stamped", false)):
			continue
		var gate_rect := gate.get("rect", Rect2i()) as Rect2i
		if not rect.intersects(gate_rect):
			continue
		gate["stamped"] = true
		var anchor := gate.get("anchor", Vector2i.ZERO) as Vector2i
		var site := gate.get("site", {}) as Dictionary
		match String(site.get("class", "")):
			"dwarfhold":
				_stamp_dwarfhold_facade(anchor)
			"dungeon":
				_stamp_dungeon_mouth(anchor)
			_:
				_stamp_settlement_clearing(gate_rect, anchor)
		var gate_label := Label.new()
		gate_label.text = String(site.get("name", "Somewhere"))
		gate_label.add_theme_font_size_override("font_size", 18)
		gate_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82, 1.0))
		gate_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06, 1.0))
		gate_label.add_theme_constant_override("outline_size", 5)
		gate_label.position = city_layer.map_to_local(anchor + Vector2i(-2, -4))
		gate_label.z_index = 30
		city_layer.add_child(gate_label)
		_surface_gate_labels.append(gate_label)
		gate["label"] = gate_label

func _stamp_settlement_clearing(gate_rect: Rect2i, anchor: Vector2i) -> void:
	for y in range(gate_rect.position.y, gate_rect.end.y):
		for x in range(gate_rect.position.x, gate_rect.end.x):
			var cell := Vector2i(x, y)
			if _latest_grid.has(cell):
				continue
			var edge := x == gate_rect.position.x or y == gate_rect.position.y or x == gate_rect.end.x - 1 or y == gate_rect.end.y - 1
			_place_tile(city_layer, cell, "plaza" if not edge else "road")
			decor_layer.erase_cell(cell)
	_place_tile(decor_layer, anchor + Vector2i(0, -2), "fence_post")

## The hold's face in the wilds: a stone front carved into the hillside,
## hedge-flanked, with one door at its center and a paved apron leading
## in. Only the door (and the apron cell before it) descends.
func _stamp_dwarfhold_facade(anchor: Vector2i) -> void:
	for y in range(anchor.y - 2, anchor.y + 1):
		for x in range(anchor.x - 3, anchor.x + 4):
			var cell := Vector2i(x, y)
			if _latest_grid.has(cell):
				continue
			var wall_key := "wall_alt" if y == anchor.y - 2 else "wall"
			_place_tile(city_layer, cell, wall_key)
			decor_layer.erase_cell(cell)
	_place_tile(city_layer, anchor, "door")
	decor_layer.erase_cell(anchor)
	for y in range(anchor.y + 1, anchor.y + 3):
		for x in range(anchor.x - 2, anchor.x + 3):
			var cell := Vector2i(x, y)
			if _latest_grid.has(cell):
				continue
			_place_tile(city_layer, cell, "plaza")
			decor_layer.erase_cell(cell)
	_place_tile(decor_layer, Vector2i(anchor.x - 3, anchor.y + 1), "hedge")
	_place_tile(decor_layer, Vector2i(anchor.x + 3, anchor.y + 1), "hedge_alt")

## A dungeon shows barely anything: a ring of old stone open to the
## south, a dark doorway at its heart.
func _stamp_dungeon_mouth(anchor: Vector2i) -> void:
	for y in range(anchor.y - 1, anchor.y + 2):
		for x in range(anchor.x - 1, anchor.x + 2):
			var cell := Vector2i(x, y)
			if _latest_grid.has(cell) or cell == anchor:
				continue
			_place_tile(city_layer, cell, "plaza" if cell == anchor + Vector2i(0, 1) else "wall_alt")
			decor_layer.erase_cell(cell)
	_place_tile(city_layer, anchor, "door")
	decor_layer.erase_cell(anchor)

## Walking onto a gate IS the journey: store the destination context
## and hand over to its scene.
func _check_surface_arrival() -> void:
	if _surface_arrival_lock or _surface_gates.is_empty() or _player_sprite == null:
		return
	for gate: Dictionary in _surface_gates:
		var trigger_cells := gate.get("trigger_cells", []) as Array
		var triggered := false
		if trigger_cells.is_empty():
			triggered = (gate.get("rect", Rect2i()) as Rect2i).has_point(_player_cell)
		else:
			for trigger_variant: Variant in trigger_cells:
				if trigger_variant as Vector2i == _player_cell:
					triggered = true
					break
		if not triggered:
			continue
		var site := gate.get("site", {}) as Dictionary
		var scene_path: String = WorldSitesService.scene_path_for(site)
		if scene_path.is_empty():
			continue
		_surface_arrival_lock = true
		var game_session := get_node_or_null("/root/GameSession")
		if game_session == null or not game_session.has_method("get_world_settings") or not game_session.has_method("set_world_settings"):
			return
		var settings: Dictionary = game_session.call("get_world_settings")
		WorldSitesService.store_journey_context(settings, site)
		game_session.call("set_world_settings", settings)
		_set_save_status("You arrive at %s." % String(site.get("name", "your destination")), Color(0.85, 0.9, 0.7, 1.0))
		SceneCacheService.request_change(self, scene_path)
		return

func _evict_far_surface_chunks(player_chunk: Vector2i) -> void:
	var to_evict: Array[Vector2i] = []
	for chunk_variant: Variant in _surface_chunks.keys():
		var chunk := chunk_variant as Vector2i
		if maxi(absi(chunk.x - player_chunk.x), absi(chunk.y - player_chunk.y)) <= SURFACE_EVICT_RADIUS:
			continue
		to_evict.append(chunk)
	for chunk: Vector2i in to_evict:
		for cell: Vector2i in (_surface_chunks[chunk] as Array[Vector2i]):
			city_layer.erase_cell(cell)
			decor_layer.erase_cell(cell)
			_actor_passable_cache.erase(cell)
		_surface_chunks.erase(chunk)
		# A gate whose ground just evaporated must stamp itself anew on
		# return, or the wilds would swallow its clearing for good.
		var chunk_cells: Rect2i = SurfaceWorldService.chunk_rect(chunk)
		for gate: Dictionary in _surface_gates:
			if not bool(gate.get("stamped", false)):
				continue
			if not (gate.get("rect", Rect2i()) as Rect2i).intersects(chunk_cells):
				continue
			gate["stamped"] = false
			var stale_label := gate.get("label") as Label
			if stale_label != null and is_instance_valid(stale_label):
				_surface_gate_labels.erase(stale_label)
				stale_label.queue_free()
			gate["label"] = null

## --- Life on the surface -------------------------------------------------
## The radial rule made flesh: danger at the player's feet decides how
## many creatures stalk them and how mean those creatures are, deep-wild
## hours roll ambush dice, and the roads carry travelers worth meeting.

func _update_surface_life(delta: float) -> void:
	if _surface_noise.is_empty() or _player_sprite == null:
		return
	var danger: float = SurfaceLifeService.danger_for_cell(_player_cell, _surface_anchor_cells)
	_surface_spawn_timer -= delta
	if _surface_spawn_timer <= 0.0:
		_surface_spawn_timer = 2.5
		_maintain_surface_creatures(danger)
		_maintain_travelers()
	_roll_surface_ambush(danger)
	SurfaceLifeService.update_creatures(
		delta, _surface_creatures, _player_cell,
		Callable(self, "_is_walkable_cell"),
		Callable(self, "_cell_center_position"),
		_rng,
		Callable(self, "_damage_player")
	)
	SurfaceLifeService.despawn_far_creatures(_surface_creatures, _player_cell)
	var finished: Array[int] = SurfaceLifeService.update_travelers(delta, _npc_states, Callable(self, "_cell_center_position"))
	for finished_position in range(finished.size() - 1, -1, -1):
		var state_index := finished[finished_position]
		var traveler_sprite := _npc_states[state_index].get("sprite") as Sprite2D
		if traveler_sprite != null:
			traveler_sprite.queue_free()
		_npc_states.remove_at(state_index)

func _maintain_surface_creatures(danger: float) -> void:
	if _surface_creatures.size() >= SurfaceLifeService.desired_creature_count(danger):
		return
	var cell := _random_wild_cell_near_player(SurfaceLifeService.CREATURE_SPAWN_MIN, SurfaceLifeService.CREATURE_SPAWN_MAX)
	if cell.x == 2147483647:
		return
	# The tier rolls off the SPAWN cell's danger, so a beast prowling in
	# from the dark is as mean as the ground it rose from.
	SurfaceLifeService.spawn_creature(
		_surface_creatures, SURFACE_CREATURE_TEXTURE,
		SurfaceLifeService.tier_def_index(SurfaceLifeService.danger_for_cell(cell, _surface_anchor_cells), _rng),
		cell, actor_layer, Callable(self, "_cell_center_position"), tile_size, _rng
	)

## A walkable wild cell in a ring around the player - never inside the
## town's protected ground.
func _random_wild_cell_near_player(min_distance: int, max_distance: int) -> Vector2i:
	for attempt in 10:
		var angle := _rng.randf_range(0.0, TAU)
		var distance := _rng.randf_range(float(min_distance), float(max_distance))
		var cell := _player_cell + Vector2i(roundi(cos(angle) * distance), roundi(sin(angle) * distance))
		if _surface_protect_rect.has_point(cell):
			continue
		if not _is_walkable_cell(cell):
			continue
		return cell
	return Vector2i(2147483647, 2147483647)

## Deep-wild hours carry ambush risk: at most one roll per game hour,
## and a failed roll stays failed until the clock turns.
func _roll_surface_ambush(danger: float) -> void:
	if danger < SurfaceLifeService.AMBUSH_DANGER_FLOOR:
		return
	var hour_stamp := _game_day * 24 + int(_game_hour)
	if hour_stamp == _surface_ambush_stamp:
		return
	_surface_ambush_stamp = hour_stamp
	if _rng.randf() > SurfaceLifeService.AMBUSH_CHANCE_PER_HOUR:
		return
	var before := _surface_creatures.size()
	for attempt in 12:
		if _surface_creatures.size() >= before + 3:
			break
		var cell := _random_wild_cell_near_player(3, 7)
		if cell.x == 2147483647:
			continue
		SurfaceLifeService.spawn_creature(
			_surface_creatures, SURFACE_CREATURE_TEXTURE,
			SurfaceLifeService.tier_def_index(danger, _rng),
			cell, actor_layer, Callable(self, "_cell_center_position"), tile_size, _rng
		)
	if _surface_creatures.size() > before:
		_set_save_status("Ambush! Shapes rush you from the treeline!", Color(0.95, 0.45, 0.4, 1.0))

## Keeps company on the stretch of road nearest the player, so travelers
## are actually met on the way somewhere, not simulated out of sight.
func _maintain_travelers() -> void:
	if _surface_road_paths.is_empty():
		return
	var traveler_count := 0
	for state: Dictionary in _npc_states:
		if bool(state.get("traveler", false)):
			traveler_count += 1
	if traveler_count >= SurfaceLifeService.TRAVELER_CAP:
		return
	var best_path_index := -1
	var best_road_index := 0
	var best_distance := 48.0 * 48.0
	for path_index in _surface_road_paths.size():
		var candidate_path: Array = _surface_road_paths[path_index]
		for road_index in range(0, candidate_path.size(), 4):
			var squared := Vector2(candidate_path[road_index] as Vector2i).distance_squared_to(Vector2(_player_cell))
			if squared < best_distance:
				best_distance = squared
				best_path_index = path_index
				best_road_index = road_index
	if best_path_index < 0:
		return
	var road_path: Array = _surface_road_paths[best_path_index]
	var traveler: Dictionary = SurfaceLifeService.spawn_traveler(road_path, "townsfolk", _rng, actor_layer, Callable(self, "_cell_center_position"), tile_size)
	if traveler.is_empty():
		return
	var spawn_index := clampi(best_road_index + _rng.randi_range(-30, 30), 2, road_path.size() - 3)
	traveler["road_index"] = spawn_index
	traveler["cell"] = road_path[spawn_index] as Vector2i
	traveler["shop_anchor"] = Vector2i(2000000 + _npc_states.size(), spawn_index)
	(traveler.get("sprite") as Sprite2D).position = _cell_center_position(road_path[spawn_index] as Vector2i)
	_npc_states.append(traveler)

func _surface_creature_index_at_cell(cell: Vector2i) -> int:
	for index in _surface_creatures.size():
		if _surface_creatures[index].get("cell", Vector2i(2147483647, 2147483647)) as Vector2i == cell:
			return index
	return -1

func _attack_surface_creature(creature_index: int) -> void:
	if _player_attack_timer > 0.0:
		return
	_player_attack_timer = 0.45
	GameAudioService.play_sfx(self, "swing")
	_strike_surface_creature(creature_index, int(PlayerStatsService.for_session(self).get("attack", 2)))

## Shared edge for melee, bow, staff, guards and the loyal sporeling.
func _strike_surface_creature(creature_index: int, damage: int) -> void:
	if creature_index < 0 or creature_index >= _surface_creatures.size():
		return
	var state := _surface_creatures[creature_index]
	var def: Dictionary = UndergroundCreatureService.CREATURE_DEFS[int(state.get("def_index", 0))]
	state["hp"] = int(state.get("hp", 1)) - damage
	GameAudioService.play_sfx(self, "hit")
	var sprite := state.get("sprite") as Sprite2D
	if sprite != null:
		_flash_sprite(sprite, Color(1.0, 0.4, 0.35, 1.0))
		_spawn_floating_text("-%d" % damage, sprite.position, Color(1.0, 0.85, 0.5, 1.0))
	if int(state.get("hp", 0)) > 0:
		return
	var creature_name := String(def.get("name", "creature"))
	var coins := _rng.randi_range(2, 6) + int(def.get("damage", 1)) * 2
	_adjust_coins(coins)
	GameAudioService.play_sfx(self, "coin")
	if sprite != null:
		_spawn_floating_text("+%d coins" % coins, sprite.position, Color(0.95, 0.8, 0.4, 1.0))
		sprite.queue_free()
	_surface_creatures.remove_at(creature_index)
	_set_save_status("The %s falls — %d coins scavenged." % [creature_name, coins], Color(0.85, 0.95, 0.7, 1.0))

## --- The homestead layer ---------------------------------------------------
## Everything the player owns above ground: built walls and floors, tilled
## fields, penned animals - persisted per town seed and re-stamped as the
## streaming wilds rebuild. Raids march on it; fences and walls matter
## because raiders and animals path around them like everyone else.

const TOWN_BUILD_CATALOG := [
	{"name": "Timber Wall", "tile": "plank_wall", "kind": "decor", "costs": {"Timber": 3}},
	{"name": "Stone Wall", "tile": "wall", "kind": "decor", "costs": {"Stone": 2}},
	{"name": "Fence", "tile": "fence", "kind": "decor", "costs": {"Timber": 1}},
	{"name": "Door", "tile": "door", "kind": "base", "costs": {"Timber": 2}},
	{"name": "Plank Floor", "tile": "floor", "kind": "base", "costs": {"Timber": 1}},
	{"name": "Storage Chest", "tile": "chest", "kind": "decor", "costs": {"Timber": 4}},
	{"name": "Bed", "tile": "bed", "kind": "decor", "costs": {"Timber": 3, "Skein of Wool": 1}},
	{"name": "Till Soil", "tile": "", "kind": "till", "costs": {}}
]

const CROP_DEFS := {
	"carrot": {"seed": "Carrot Seeds", "yield": "Carrot", "tiles": ["crop_carrot_0", "crop_carrot_1", "crop_carrot_2"]},
	"beetroot": {"seed": "Beetroot Seeds", "yield": "Beetroot", "tiles": ["crop_beetroot_0", "crop_beetroot_1", "crop_beetroot_2"]},
	"tomato": {"seed": "Tomato Seeds", "yield": "Tomato", "tiles": ["crop_tomato_0", "crop_tomato_1", "crop_tomato_2"]}
}
const FARM_STAGE_HOURS := 8.0
const ANIMAL_CRATES := {"Chicken Crate": "chicken", "Piglet Crate": "pig", "Calf Crate": "cow"}
const ANIMAL_PRODUCE := {"chicken": "Egg", "pig": "Truffle", "cow": "Milk Pail"}

const RAID_MIN_HOMESTEAD := 8
const RAID_GRACE_DAYS := 2

func _world_settings_snapshot() -> Dictionary:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings"):
		return {}
	return game_session.call("get_world_settings")

func _store_world_settings(settings: Dictionary) -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null and game_session.has_method("set_world_settings"):
		game_session.call("set_world_settings", settings)

func _scene_store_key(prefix: String) -> String:
	return "%s|%s" % [prefix, seed_input.text.strip_edges()]

func _add_to_inventory(item_name: String, amount: int) -> void:
	if item_name == "Copper Coins":
		_adjust_coins(amount)
		return
	_player_inventory[item_name] = int(_player_inventory.get(item_name, 0)) + amount
	if int(_player_inventory.get(item_name, 0)) <= 0:
		_player_inventory.erase(item_name)
	_populate_backpack_slots()
	_update_gear_label()
	if GearService.TRINKET_DEFS.has(item_name):
		_refresh_player_stats_town()
	_save_player_inventory()

func _refresh_player_stats_town() -> void:
	var stats: Dictionary = PlayerStatsService.for_session(self)
	_player_max_hp = float(stats.get("max_hp", _player_max_hp))
	_player_hp = minf(_player_hp, _player_max_hp)
	_speed_scale_cache = float(stats.get("speed_mult", 1.0))
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
		Callable(self, "_on_equipment_changed")
	)
	chest_popup.get_parent().add_child(_inventory_screen)

func _on_equipment_changed() -> void:
	_refresh_player_stats_town()
	_populate_backpack_slots()
	_save_player_inventory()

func _player_speed_scale() -> float:
	return maxf(_speed_scale_cache * (1.65 if _player_mounted else 1.0), 0.25)

## Q: knock back a potion. Heals wait for wounds; buffs go down whenever.
func _handle_quick_drink_action() -> void:
	for potion_name: String in GearService.POTION_DEFS.keys():
		if int(_player_inventory.get(potion_name, 0)) < 1:
			continue
		var def := GearService.POTION_DEFS[potion_name] as Dictionary
		if def.has("heal") and _player_hp >= _player_max_hp:
			continue
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
			_refresh_player_stats_town()
			_set_save_status("You drink the %s — %s hums in your blood." % [potion_name, String(result.get("buff", ""))], Color(0.8, 0.75, 0.95, 1.0))
		return
	_set_save_status("No potions in the pack — apothecaries and road peddlers sell them.", Color(0.8, 0.8, 0.8, 1.0))

## --- weapon classes at range -------------------------------------------------

func _try_ranged_attack_town(creature_index: int, cell: Vector2i) -> bool:
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
		for index in range(_surface_creatures.size() - 1, -1, -1):
			var creature_cell := _surface_creatures[index].get("cell", Vector2i(9999, 9999)) as Vector2i
			if maxi(absi(creature_cell.x - cell.x), absi(creature_cell.y - cell.y)) <= radius:
				_strike_surface_creature(index, burst)
		return true
	var bow := loadout.get("bow", {}) as Dictionary
	if not bow.is_empty() and distance <= int(bow.get("range", 4)):
		if int(_player_inventory.get("Arrows", 0)) < 1:
			_set_save_status("Your quiver is empty — tinkers and peddlers sell Arrows.", Color(0.95, 0.75, 0.45, 1.0))
			return true
		if _player_attack_timer > 0.0:
			return true
		_player_attack_timer = 0.45
		_add_to_inventory("Arrows", -1)
		GameAudioService.play_sfx(self, "bow")
		_spawn_arrow_flight(_player_cell, cell)
		_strike_surface_creature(creature_index, int(stats.get("attack", 2)) + int(bow.get("attack", 0)))
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

## --- the loyal sporeling -----------------------------------------------------

func _ensure_companion() -> void:
	if not _companion.is_empty() or _player_sprite == null:
		return
	var loadout := PlayerStatsService.for_session(self).get("loadout", {}) as Dictionary
	var charm := loadout.get("charm", {}) as Dictionary
	if charm.is_empty():
		return
	_companion = CompanionService.spawn(charm, SURFACE_CREATURE_TEXTURE, _player_cell, actor_layer, Callable(self, "_cell_center_position"), tile_size)
	if not _companion.is_empty():
		_set_save_status("Something small and loyal pads out of the hedgerows to walk with you.", Color(0.75, 0.92, 0.75, 1.0))

func _update_companion(delta: float) -> void:
	if _companion.is_empty() or _player_sprite == null:
		return
	CompanionService.update(
		delta, _companion, _player_cell, _surface_creatures,
		Callable(self, "_is_walkable_cell"),
		Callable(self, "_cell_center_position"),
		Callable(self, "_strike_surface_creature")
	)

## --- water and the coracle ---------------------------------------------------

func _is_water_cell(cell: Vector2i) -> bool:
	if city_layer.get_cell_source_id(cell) < 0:
		return false
	var atlas_coords := city_layer.get_cell_atlas_coords(cell)
	return atlas_coords == (TILE_ATLAS.get("water") as Vector2i) or atlas_coords == (TILE_ATLAS.get("water_calm") as Vector2i)

func _set_boating(boating: bool) -> void:
	if _player_boating == boating:
		return
	_player_boating = boating
	GameAudioService.play_sfx(self, "splash")
	if boating and _player_mounted:
		_toggle_mount()
	if _boat_sprite == null and _player_sprite != null:
		_boat_sprite = Sprite2D.new()
		_boat_sprite.texture = BOAT_SPRITE_TEXTURE
		_boat_sprite.position = Vector2(0.0, 4.0)
		# Behind the rider but above the water tiles.
		_boat_sprite.show_behind_parent = true
		_boat_sprite.scale = Vector2(0.9, 0.75)
		_player_sprite.add_child(_boat_sprite)
	if _boat_sprite != null:
		_boat_sprite.visible = boating
	if boating:
		_set_save_status("You push the coracle out onto the water.", Color(0.7, 0.82, 0.95, 1.0))
	else:
		_set_save_status("You drag the coracle ashore and step out.", Color(0.7, 0.82, 0.95, 1.0))

func _try_boat_action(cell: Vector2i) -> bool:
	if _player_boating or not _is_water_cell(cell) or not _is_player_adjacent_to_cell(cell):
		return false
	if int(_player_inventory.get("Coracle", 0)) < 1:
		_set_save_status("Open water. A Coracle would carry you across — tinkers on the road sell them.", Color(0.7, 0.82, 0.95, 1.0))
		return true
	_set_boating(true)
	_player_cell = cell
	_actor_sprite_to_cell(_player_sprite, cell)
	return true

## --- the riding sow ----------------------------------------------------------

func _toggle_mount() -> void:
	if not _player_mounted and int(_player_inventory.get("Sow Saddle", 0)) < 1:
		_set_save_status("You need a Sow Saddle to ride — drovers on the road sell them (M to mount).", Color(0.8, 0.8, 0.8, 1.0))
		return
	if _player_boating:
		_set_save_status("Not in the boat.", Color(0.8, 0.8, 0.8, 1.0))
		return
	_player_mounted = not _player_mounted
	GameAudioService.play_sfx(self, "mount")
	if _mount_sprite == null and _player_sprite != null:
		var pig_texture := load("res://resources/images/webgame_tiles/Farm/Tiled_files/Pig_animation.png") as Texture2D
		if pig_texture != null:
			_mount_sprite = Sprite2D.new()
			_mount_sprite.texture = pig_texture
			_mount_sprite.region_enabled = true
			_mount_sprite.region_rect = Rect2(0, 0, 32, 32)
			_mount_sprite.position = Vector2(0.0, 4.0)
			_mount_sprite.show_behind_parent = true
			_mount_sprite.scale = Vector2(0.85, 0.7)
			_player_sprite.add_child(_mount_sprite)
	if _mount_sprite != null:
		_mount_sprite.visible = _player_mounted
	if _player_mounted:
		_set_save_status("You swing into the saddle — the sow trots off eagerly.", Color(0.85, 0.8, 0.7, 1.0))
	else:
		_set_save_status("You dismount. The sow looks relieved.", Color(0.85, 0.8, 0.7, 1.0))

## --- building the homestead --------------------------------------------------

func _cycle_town_build_selection() -> void:
	_build_selection += 1
	if _build_selection >= TOWN_BUILD_CATALOG.size():
		_build_selection = -1
		_set_save_status("Build mode off", Color(0.8, 0.8, 0.8, 1.0))
		return
	var entry := TOWN_BUILD_CATALOG[_build_selection] as Dictionary
	var costs_text := _town_build_costs_text(entry)
	if String(entry.get("kind", "")) == "till":
		costs_text = "needs an Iron Hoe"
	_set_save_status("🔨 Build: %s (%s) — click a tile beside you · B for next" % [String(entry.get("name", "")), costs_text], Color(0.85, 0.9, 0.75, 1.0))

func _town_build_costs_text(entry: Dictionary) -> String:
	var parts := PackedStringArray()
	var costs := entry.get("costs", {}) as Dictionary
	for item_variant: Variant in costs.keys():
		parts.append("%d %s" % [int(costs[item_variant]), String(item_variant)])
	return ", ".join(parts) if not parts.is_empty() else "free"

func _build_kind_for_tile(tile_key: String) -> String:
	for entry_variant: Variant in TOWN_BUILD_CATALOG:
		if String((entry_variant as Dictionary).get("tile", "")) == tile_key:
			return String((entry_variant as Dictionary).get("kind", "decor"))
	return "decor"

## Buildable ground: streamed wilds grass or sand, never the town's own
## cells, roads, water, or someone's standing spot.
func _can_build_on_cell(cell: Vector2i) -> bool:
	if _latest_grid.has(cell) or _surface_road_cells.has(cell) or _player_built_cells.has(cell) or _farm_plots.has(cell):
		return false
	if city_layer.get_cell_source_id(cell) < 0 or _is_water_cell(cell):
		return false
	if decor_layer.get_cell_source_id(cell) >= 0:
		return false
	if _is_cell_occupied_by_npc(cell) or _surface_creature_index_at_cell(cell) >= 0 or cell == _player_cell:
		return false
	return true

func _try_place_town_build(cell: Vector2i) -> bool:
	if _build_selection < 0 or _build_selection >= TOWN_BUILD_CATALOG.size():
		return false
	if not _is_player_adjacent_to_cell(cell) or cell == _player_cell:
		return false
	var entry := TOWN_BUILD_CATALOG[_build_selection] as Dictionary
	if String(entry.get("kind", "")) == "till":
		return _try_till_cell(cell)
	var build_name := String(entry.get("name", ""))
	var costs := entry.get("costs", {}) as Dictionary
	for item_variant: Variant in costs.keys():
		if int(_player_inventory.get(String(item_variant), 0)) < int(costs[item_variant]):
			_set_save_status("Need %s for %s" % [_town_build_costs_text(entry), build_name], Color(0.95, 0.75, 0.45, 1.0))
			return true
	if not _can_build_on_cell(cell):
		_set_save_status("Can't raise %s there — clear wild ground only." % build_name, Color(0.95, 0.75, 0.45, 1.0))
		return true
	for item_variant: Variant in costs.keys():
		_add_to_inventory(String(item_variant), -int(costs[item_variant]))
	var tile_key := String(entry.get("tile", "wall"))
	_player_built_cells[cell] = tile_key
	_stamp_player_build(cell, tile_key)
	if tile_key == "chest" and not _chest_inventories.has(cell):
		_chest_inventories[cell] = []
	_persist_player_builds()
	GameAudioService.play_sfx(self, "till")
	_spawn_floating_text("+%s" % build_name, _cell_center_position(cell), Color(0.8, 0.95, 0.7, 1.0))
	_set_save_status("Built %s (homestead: %d pieces)" % [build_name, _player_built_cells.size()], Color(0.75, 0.92, 0.7, 1.0))
	return true

func _stamp_player_build(cell: Vector2i, tile_key: String) -> void:
	if city_layer.get_cell_source_id(cell) < 0:
		_place_tile(city_layer, cell, "grass")
	if _build_kind_for_tile(tile_key) == "base":
		_place_tile(city_layer, cell, tile_key)
		decor_layer.erase_cell(cell)
	else:
		_place_tile(decor_layer, cell, tile_key)
	_actor_passable_cache.erase(cell)

func _remove_player_build(cell: Vector2i) -> void:
	var tile_key := String(_player_built_cells.get(cell, ""))
	_player_built_cells.erase(cell)
	_wall_damage.erase(cell)
	if _build_kind_for_tile(tile_key) == "base":
		_place_tile(city_layer, cell, "grass")
	else:
		decor_layer.erase_cell(cell)
	_actor_passable_cache.erase(cell)
	_persist_player_builds()

func _persist_player_builds() -> void:
	var settings: Dictionary = _world_settings_snapshot()
	var stored: Dictionary = {}
	for cell_variant: Variant in _player_built_cells.keys():
		var cell := cell_variant as Vector2i
		stored["%d,%d" % [cell.x, cell.y]] = String(_player_built_cells[cell_variant])
	settings[_scene_store_key("town_builds")] = stored
	_store_world_settings(settings)

func _homestead_center() -> Vector2i:
	if _player_built_cells.is_empty():
		return _player_home_cell
	var total := Vector2.ZERO
	for cell_variant: Variant in _player_built_cells.keys():
		total += Vector2(cell_variant as Vector2i)
	return Vector2i((total / float(_player_built_cells.size())).round())

## --- fields and pens ---------------------------------------------------------

func _can_till_cell(cell: Vector2i) -> bool:
	if not _can_build_on_cell(cell):
		return false
	var atlas_coords := city_layer.get_cell_atlas_coords(cell)
	for grass_key: String in ["grass", "grass_dark", "grass_tuft"]:
		if atlas_coords == (TILE_ATLAS.get(grass_key) as Vector2i):
			return true
	return false

func _try_till_cell(cell: Vector2i) -> bool:
	if int(_player_inventory.get("Iron Hoe", 0)) < 1:
		_set_save_status("Tilling wants an Iron Hoe — tinkers on the road sell them.", Color(0.95, 0.75, 0.45, 1.0))
		return true
	if not _can_till_cell(cell):
		_set_save_status("Only open grass takes the hoe.", Color(0.95, 0.75, 0.45, 1.0))
		return true
	_farm_plots[cell] = {"crop": "", "stage": 0, "planted_h": 0.0}
	_stamp_farm_plot(cell)
	_persist_farm()
	GameAudioService.play_sfx(self, "till")
	_set_save_status("You turn the earth. Click the plot with seeds in your pack to plant.", Color(0.75, 0.92, 0.7, 1.0))
	return true

func _stamp_farm_plot(cell: Vector2i) -> void:
	var plot := _farm_plots.get(cell, {}) as Dictionary
	if plot.is_empty():
		return
	_place_tile(city_layer, cell, "tilled_soil")
	var crop := String(plot.get("crop", ""))
	if crop.is_empty() or not CROP_DEFS.has(crop):
		decor_layer.erase_cell(cell)
	else:
		var stage_tiles := (CROP_DEFS[crop] as Dictionary).get("tiles", []) as Array
		var stage := clampi(int(plot.get("stage", 0)), 0, stage_tiles.size() - 1)
		_place_tile(decor_layer, cell, String(stage_tiles[stage]))
	_actor_passable_cache.erase(cell)

func _try_farm_action(cell: Vector2i) -> bool:
	if not _farm_plots.has(cell) or not _is_player_adjacent_to_cell(cell):
		return false
	var plot := _farm_plots[cell] as Dictionary
	var crop := String(plot.get("crop", ""))
	if crop.is_empty():
		for crop_id: String in CROP_DEFS.keys():
			var seed_item := String((CROP_DEFS[crop_id] as Dictionary).get("seed", ""))
			if int(_player_inventory.get(seed_item, 0)) >= 1:
				_add_to_inventory(seed_item, -1)
				plot["crop"] = crop_id
				plot["stage"] = 0
				plot["planted_h"] = float(_game_day) * 24.0 + _game_hour
				_stamp_farm_plot(cell)
				_persist_farm()
				GameAudioService.play_sfx(self, "till")
				_set_save_status("You plant %s." % seed_item, Color(0.75, 0.92, 0.7, 1.0))
				return true
		_set_save_status("Tilled and waiting — peddlers and the general store sell seeds.", Color(0.8, 0.8, 0.8, 1.0))
		return true
	if int(plot.get("stage", 0)) >= 2:
		var yield_item := String((CROP_DEFS[crop] as Dictionary).get("yield", "crop"))
		var amount := 2 + (1 if _rng.randf() < 0.5 else 0)
		_add_to_inventory(yield_item, amount)
		if _rng.randf() < 0.35:
			_add_to_inventory(String((CROP_DEFS[crop] as Dictionary).get("seed", "")), 1)
		GameAudioService.play_sfx(self, "harvest")
		_spawn_floating_text("+%d %s" % [amount, yield_item], _cell_center_position(cell), Color(0.8, 0.95, 0.7, 1.0))
		plot["crop"] = ""
		plot["stage"] = 0
		_stamp_farm_plot(cell)
		_persist_farm()
		return true
	_set_save_status("The %s still grows — a stage every %d hours." % [crop, int(FARM_STAGE_HOURS)], Color(0.8, 0.8, 0.8, 1.0))
	return true

func _advance_farm_growth() -> void:
	var now_hours := float(_game_day) * 24.0 + _game_hour
	var changed := false
	for cell_variant: Variant in _farm_plots.keys():
		var plot := _farm_plots[cell_variant] as Dictionary
		if String(plot.get("crop", "")).is_empty():
			continue
		var stage := clampi(int((now_hours - float(plot.get("planted_h", now_hours))) / FARM_STAGE_HOURS), 0, 2)
		if stage != int(plot.get("stage", 0)):
			plot["stage"] = stage
			_stamp_farm_plot(cell_variant as Vector2i)
			changed = true
	if changed:
		_persist_farm()

func _persist_farm() -> void:
	var settings: Dictionary = _world_settings_snapshot()
	var stored: Dictionary = {}
	for cell_variant: Variant in _farm_plots.keys():
		var cell := cell_variant as Vector2i
		var plot := _farm_plots[cell_variant] as Dictionary
		stored["%d,%d" % [cell.x, cell.y]] = {"crop": String(plot.get("crop", "")), "stage": int(plot.get("stage", 0)), "planted_h": float(plot.get("planted_h", 0.0))}
	settings[_scene_store_key("town_farm")] = stored
	_store_world_settings(settings)

## Live animals released from a drover's crate near the homestead.
func _try_release_animal(cell: Vector2i) -> bool:
	if not _is_player_adjacent_to_cell(cell) or cell == _player_cell:
		return false
	var crate_name := ""
	for candidate: String in ANIMAL_CRATES.keys():
		if int(_player_inventory.get(candidate, 0)) >= 1:
			crate_name = candidate
			break
	if crate_name.is_empty():
		return false
	if not _is_walkable_cell(cell) or _is_cell_occupied_by_npc(cell):
		return false
	var kind := String(ANIMAL_CRATES[crate_name])
	_add_to_inventory(crate_name, -1)
	_spawn_owned_animal(kind, cell, float(_game_day) * 24.0 + _game_hour)
	_persist_animals()
	GameAudioService.play_sfx(self, "mount")
	_set_save_status("You open the crate — the %s trots out. Fence it in and collect its yield daily." % kind, Color(0.75, 0.92, 0.7, 1.0))
	return true

func _spawn_owned_animal(kind: String, cell: Vector2i, last_produce_h: float) -> void:
	var def: Dictionary = {}
	for def_variant: Variant in FARM_ANIMAL_DEFS:
		if String((def_variant as Dictionary).get("id", "")) == kind:
			def = def_variant as Dictionary
			break
	if def.is_empty():
		return
	var animal_id := String(def.get("id", "chicken"))
	if not _farm_animal_textures.has(animal_id):
		_farm_animal_textures[animal_id] = load(String(def.get("path", ""))) as Texture2D
	var texture := _farm_animal_textures.get(animal_id) as Texture2D
	if texture == null:
		return
	var frame_px := int(def.get("frame", 32))
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.centered = true
	sprite.region_rect = Rect2(0, 0, frame_px, frame_px)
	sprite.scale = Vector2.ONE * (float(tile_size.y) / float(frame_px)) * 0.9
	sprite.position = _cell_center_position(cell)
	sprite.z_index = 11
	actor_layer.add_child(sprite)
	_farm_animals.append({
		"def": def,
		"sprite": sprite,
		"cell": cell,
		"pen_index": -2,
		"home": cell,
		"owned": true,
		"last_produce_h": last_produce_h,
		"moving": false,
		"facing": Vector2i(0, 1),
		"wander_timer": _rng.randf_range(0.5, 4.0),
		"anim_time": _rng.randf_range(0.0, 2.0)
	})

func _try_collect_produce(cell: Vector2i) -> bool:
	if not _is_player_adjacent_to_cell(cell):
		return false
	for state: Dictionary in _farm_animals:
		if not bool(state.get("owned", false)):
			continue
		if (state.get("cell", Vector2i(9999, 9999)) as Vector2i) != cell:
			continue
		var kind := String((state.get("def", {}) as Dictionary).get("id", "chicken"))
		var produce := String(ANIMAL_PRODUCE.get(kind, "Egg"))
		var now_hours := float(_game_day) * 24.0 + _game_hour
		if now_hours - float(state.get("last_produce_h", 0.0)) < 24.0:
			_set_save_status("The %s has nothing for you yet — come back tomorrow." % kind, Color(0.8, 0.8, 0.8, 1.0))
			return true
		state["last_produce_h"] = now_hours
		_add_to_inventory(produce, 1)
		_persist_animals()
		GameAudioService.play_sfx(self, "harvest")
		_spawn_floating_text("+1 %s" % produce, _cell_center_position(cell), Color(0.8, 0.95, 0.7, 1.0))
		_set_save_status("You collect the %s's %s." % [kind, produce], Color(0.75, 0.92, 0.7, 1.0))
		return true
	return false

func _persist_animals() -> void:
	var settings: Dictionary = _world_settings_snapshot()
	var stored: Array = []
	for state: Dictionary in _farm_animals:
		if not bool(state.get("owned", false)):
			continue
		var home := state.get("home", Vector2i.ZERO) as Vector2i
		stored.append({"kind": String((state.get("def", {}) as Dictionary).get("id", "chicken")), "x": home.x, "y": home.y, "last_produce_h": float(state.get("last_produce_h", 0.0))})
	settings[_scene_store_key("town_animals")] = stored
	_store_world_settings(settings)

func _restore_owned_animals() -> void:
	var settings: Dictionary = _world_settings_snapshot()
	var stored: Variant = settings.get(_scene_store_key("town_animals"))
	if not (stored is Array):
		return
	for entry_variant: Variant in (stored as Array):
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		_spawn_owned_animal(String(entry.get("kind", "chicken")), Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0))), float(entry.get("last_produce_h", 0.0)))

## Restores the whole owned layer from the save: builds, fields, the
## raid calendar. Animals rebuild after the town dressing pass.
func _restore_homestead(settings: Dictionary) -> void:
	_player_built_cells.clear()
	_farm_plots.clear()
	_wall_damage.clear()
	var builds: Variant = settings.get(_scene_store_key("town_builds"))
	if builds is Dictionary:
		for key_variant: Variant in (builds as Dictionary).keys():
			var parts := String(key_variant).split(",")
			if parts.size() != 2:
				continue
			var cell := Vector2i(int(parts[0]), int(parts[1]))
			_player_built_cells[cell] = String((builds as Dictionary)[key_variant])
			_stamp_player_build(cell, String((builds as Dictionary)[key_variant]))
			if String((builds as Dictionary)[key_variant]) == "chest" and not _chest_inventories.has(cell):
				_chest_inventories[cell] = []
	var farm: Variant = settings.get(_scene_store_key("town_farm"))
	if farm is Dictionary:
		for key_variant: Variant in (farm as Dictionary).keys():
			var parts := String(key_variant).split(",")
			if parts.size() != 2:
				continue
			var cell := Vector2i(int(parts[0]), int(parts[1]))
			var plot_variant: Variant = (farm as Dictionary)[key_variant]
			if plot_variant is Dictionary:
				_farm_plots[cell] = (plot_variant as Dictionary).duplicate()
				_stamp_farm_plot(cell)
	_next_raid_day = int(settings.get("town_next_raid_day", 0))

## --- tree felling ------------------------------------------------------------

func _try_chop_tree(cell: Vector2i) -> bool:
	if not _is_player_adjacent_to_cell(cell):
		return false
	if decor_layer.get_cell_source_id(cell) < 0:
		return false
	var atlas_coords := decor_layer.get_cell_atlas_coords(cell)
	if atlas_coords != (TILE_ATLAS.get("tree") as Vector2i) and atlas_coords != (TILE_ATLAS.get("tree_dark") as Vector2i):
		return false
	decor_layer.erase_cell(cell)
	_actor_passable_cache.erase(cell)
	_add_to_inventory("Timber", 2)
	GameAudioService.play_sfx(self, "harvest")
	_spawn_floating_text("+2 Timber", _cell_center_position(cell), Color(0.8, 0.95, 0.7, 1.0))
	_set_save_status("You fell the tree — the wilds grow them back in time.", Color(0.75, 0.92, 0.7, 1.0))
	return true

## --- trading on the road -----------------------------------------------------

func _try_open_traveler_trade(state: Dictionary) -> bool:
	var role := String((state.get("identity", {}) as Dictionary).get("profession", ""))
	if not SettlementEconomyService.TRAVELER_STOCK_TYPES.has(role):
		return false
	var stock_type := String(SettlementEconomyService.TRAVELER_STOCK_TYPES[role])
	var anchor := state.get("shop_anchor", Vector2i(2000001, 0)) as Vector2i
	if not _shop_stocks.has(anchor):
		var stock_rng := RandomNumberGenerator.new()
		stock_rng.seed = hash(String((state.get("identity", {}) as Dictionary).get("name", "wanderer")))
		_shop_stocks[anchor] = SettlementEconomyService.generate_shop_stock(stock_type, stock_rng)
	_selected_chest_cell = Vector2i(2147483647, 2147483647)
	_trade_shop_cell = anchor
	_trade_shop_type = stock_type
	chest_popup.visible = true
	chest_popup_title.text = "Trade — %s" % String(state.get("npc_name", "A traveler"))
	chest_popup_take_all_button.disabled = true
	var section_label := chest_popup.find_child("ChestSectionLabel", true, false) as Label
	if section_label != null:
		section_label.text = "Wares from the pack"
	_refresh_trade_panel()
	return true

## --- raids on the homestead --------------------------------------------------

## Once the homestead is worth robbing, evening raids come for it. The
## horn sounds, a band spawns in the dark ring and marches; your walls
## slow them, your guards and sporeling meet them, and whatever reaches
## the heart of your ground robs you before melting away.
func _maybe_start_raid() -> void:
	if _raid_active or _player_built_cells.size() < RAID_MIN_HOMESTEAD:
		return
	if _next_raid_day <= 0:
		_next_raid_day = _game_day + RAID_GRACE_DAYS
		_persist_next_raid_day()
		return
	if _game_day < _next_raid_day or int(_game_hour) < 19 or int(_game_hour) >= 23:
		return
	var center := _homestead_center()
	var raider_count := 4 + mini(3, _game_day / 4)
	var spawned := 0
	for attempt in raider_count * 6:
		if spawned >= raider_count:
			break
		var angle := _rng.randf_range(0.0, TAU)
		var ring := _rng.randf_range(24.0, 32.0)
		var cell := center + Vector2i(roundi(cos(angle) * ring), roundi(sin(angle) * ring))
		if not _is_walkable_cell(cell):
			continue
		var size_before := _surface_creatures.size()
		var raider_defs := [3, 4, 5, 6, 6, 7]
		SurfaceLifeService.spawn_creature(_surface_creatures, SURFACE_CREATURE_TEXTURE, int(raider_defs[_rng.randi_range(0, raider_defs.size() - 1)]), cell, actor_layer, Callable(self, "_cell_center_position"), tile_size, _rng, true)
		if _surface_creatures.size() > size_before:
			var raider := _surface_creatures[_surface_creatures.size() - 1]
			raider["raider"] = true
			raider["march_target"] = center
			raider["hp"] = int(raider.get("hp", 8)) + 4
			spawned += 1
	if spawned == 0:
		return
	_raid_active = true
	_raid_end_stamp = float(_game_day) * 24.0 + _game_hour + 2.0
	_next_raid_day = _game_day + 3 + _rng.randi_range(0, 2)
	_persist_next_raid_day()
	GameAudioService.play_sfx(self, "raid_horn")
	_set_save_status("A war horn sounds — %d raiders march on your homestead!" % spawned, Color(0.95, 0.4, 0.35, 1.0))

func _persist_next_raid_day() -> void:
	var settings: Dictionary = _world_settings_snapshot()
	settings["town_next_raid_day"] = _next_raid_day
	_store_world_settings(settings)

func _update_raid(delta: float) -> void:
	if not _raid_active:
		return
	var raiders: Array[Dictionary] = []
	for state: Dictionary in _surface_creatures:
		if bool(state.get("raider", false)) and not bool(state.get("dying", false)):
			raiders.append(state)
	if raiders.is_empty():
		_end_raid(true)
		return
	if float(_game_day) * 24.0 + _game_hour >= _raid_end_stamp:
		_end_raid(false)
		return
	for raider: Dictionary in raiders:
		_update_raider_bashing(raider, delta)
	_update_guard_response(delta, raiders)

## A raider stuck against your walls starts breaking them: three blows
## fell one piece. Solid rings buy time; gaps invite the knife.
func _update_raider_bashing(raider: Dictionary, delta: float) -> void:
	var cell := raider.get("cell", Vector2i.ZERO) as Vector2i
	if cell != (raider.get("bash_last_cell", Vector2i(9999, 9999)) as Vector2i):
		raider["bash_last_cell"] = cell
		raider["bash_stuck_time"] = 0.0
		return
	raider["bash_stuck_time"] = float(raider.get("bash_stuck_time", 0.0)) + delta
	if float(raider.get("bash_stuck_time", 0.0)) < 2.0:
		return
	raider["bash_stuck_time"] = 0.0
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var wall_cell := cell + offset
		if not _player_built_cells.has(wall_cell):
			continue
		var hits := int(_wall_damage.get(wall_cell, 0)) + 1
		if hits >= 3:
			var broken := String(_player_built_cells.get(wall_cell, "wall"))
			_remove_player_build(wall_cell)
			GameAudioService.play_sfx(self, "hit")
			_set_save_status("A raider smashes through your %s!" % broken, Color(0.95, 0.5, 0.4, 1.0))
		else:
			_wall_damage[wall_cell] = hits
			_spawn_floating_text("crack!", _cell_center_position(wall_cell), Color(0.85, 0.8, 0.7, 1.0))
		return

## Town guards drop their rounds and close on raiders within their ward.
func _update_guard_response(delta: float, raiders: Array[Dictionary]) -> void:
	for state: Dictionary in _npc_states:
		if int(state.get("role", -1)) != ROLE_GUARD:
			continue
		var sprite := state.get("sprite") as Sprite2D
		if sprite == null:
			continue
		var guard_cell := state.get("cell", Vector2i.ZERO) as Vector2i
		var best := -1
		var best_distance := 26
		for index in raiders.size():
			var raider_cell := raiders[index].get("cell", Vector2i(9999, 9999)) as Vector2i
			var distance := maxi(absi(raider_cell.x - guard_cell.x), absi(raider_cell.y - guard_cell.y))
			if distance < best_distance:
				best_distance = distance
				best = index
		if best < 0:
			state.erase("raid_duty")
			continue
		state["raid_duty"] = true
		state["guard_step_timer"] = float(state.get("guard_step_timer", 0.0)) - delta
		state["guard_attack_timer"] = maxf(float(state.get("guard_attack_timer", 0.0)) - delta, 0.0)
		if best_distance <= 1:
			if float(state.get("guard_attack_timer", 0.0)) <= 0.0:
				state["guard_attack_timer"] = 1.2
				var raider_index := _surface_creatures.find(raiders[best])
				if raider_index >= 0:
					_strike_surface_creature(raider_index, 2)
		elif float(state.get("guard_step_timer", 0.0)) <= 0.0:
			state["guard_step_timer"] = 0.4
			var step: Vector2i = CreatureCombatService.step_toward(guard_cell, raiders[best].get("cell", guard_cell) as Vector2i, Callable(self, "_is_npc_walkable_cell"))
			if step != Vector2i.ZERO:
				state["cell"] = guard_cell + step
				sprite.position = _cell_center_position(guard_cell + step)

func _end_raid(victorious: bool) -> void:
	_raid_active = false
	_wall_damage.clear()
	var center := _homestead_center()
	var stolen := 0
	for index in range(_surface_creatures.size() - 1, -1, -1):
		var state := _surface_creatures[index]
		if not bool(state.get("raider", false)):
			continue
		var raider_cell := state.get("cell", Vector2i(9999, 9999)) as Vector2i
		if not victorious and maxi(absi(raider_cell.x - center.x), absi(raider_cell.y - center.y)) <= 8:
			stolen += 15
		var sprite := state.get("sprite") as Sprite2D
		if sprite != null:
			sprite.queue_free()
		_surface_creatures.remove_at(index)
	for state: Dictionary in _npc_states:
		state.erase("raid_duty")
	if victorious:
		var bounty := 25 + _rng.randi_range(0, 20)
		_adjust_coins(bounty)
		GameAudioService.play_sfx(self, "coin")
		if _rng.randf() < 0.5:
			_add_to_inventory("Runestone", 1)
			_set_save_status("Raid repelled! +%d coins — and a Runestone off their chief." % bounty, Color(0.7, 0.95, 0.7, 1.0))
		else:
			_set_save_status("Raid repelled! +%d coins scavenged off the fallen." % bounty, Color(0.7, 0.95, 0.7, 1.0))
	else:
		stolen = mini(stolen, _player_coins)
		if stolen > 0:
			_adjust_coins(-stolen)
			_set_save_status("The raiders withdraw with %d of your coins." % stolen, Color(0.95, 0.5, 0.4, 1.0))
		else:
			_set_save_status("The raiders lose heart and melt back into the wilds.", Color(0.8, 0.85, 0.7, 1.0))

## --- the land's two voices ---------------------------------------------------

func _update_music(delta: float) -> void:
	_music_timer -= delta
	if _music_timer > 0.0:
		return
	_music_timer = 4.0
	if _surface_anchor_cells.is_empty() or _player_sprite == null:
		return
	var danger: float = SurfaceLifeService.danger_for_cell(_player_cell, _surface_anchor_cells)
	GameAudioService.play_music(self, "wilds" if danger > 0.4 else "town")

func _is_walkable_cell(cell: Vector2i) -> bool:
	# Above ground the green is open terrain: any rendered passable tile is
	# walkable, so building walls and furniture are the only barriers and a
	# street severed by later construction is still reachable across grass.
	if _latest_grid.is_empty():
		return false
	return _is_passable_cell_for_actor(cell)

func _is_npc_walkable_cell(cell: Vector2i) -> bool:
	return DwarfHoldTavernService.is_npc_walkable_cell(cell, Callable(self, "_is_walkable_cell"), decor_layer, TILE_ATLAS.get("wall", Vector2i(-1000, -1000)))

func _actor_sprite_to_cell(sprite: Sprite2D, cell: Vector2i) -> void:
	sprite.position = _cell_center_position(cell)

func _cell_center_position(cell: Vector2i) -> Vector2:
	return city_layer.map_to_local(cell)

func _place_tile(target_layer: TileMapLayer, cell: Vector2i, tile_key: String) -> void:
	DwarfHoldTileService.place_tile(target_layer, cell, tile_key, TILE_ATLAS)
	_actor_passable_cache.erase(cell)

func _pick_base_tile(grid: Dictionary, x: int, y: int, cell: int) -> String:
	var tile_key := TownTileService.pick_base_tile(grid, x, y, cell, _door_cells)
	if _town_theme == "desert" and DESERT_BASE_SWAP.has(tile_key):
		return String(DESERT_BASE_SWAP[tile_key])
	return tile_key

func _building_type_for_cell(cell: Vector2i) -> String:
	return String(_latest_civic_building_type_map.get(cell, "workshop"))

func _pick_decor_tile(grid: Dictionary, x: int, y: int, cell: int, base_tile: String, house_decor_overrides: Dictionary) -> String:
	var decor_key := TownTileService.pick_decor_tile(grid, x, y, cell, base_tile, house_decor_overrides, _latest_civic_building_type_map, CIVIC_BUILDING_TYPES, _rng, _door_cells)
	# The desert has no greenery: cacti and bones are scattered as sprites instead.
	if _town_theme == "desert" and DESERT_SKIPPED_DECOR.has(decor_key):
		return ""
	return decor_key


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
		city_summary.text += "\nTown Population: %d (target residents in-scene: %d at 10:1)" % [_hold_state.selected_hold_population, expected_npcs]
		city_summary.text += "\nBeds: %d (resident target: %d)" % [_latest_bed_count, level_npc_target]
	if not _town_details.is_empty():
		city_summary.text += "\n\n%s — %s" % [String(_town_details.get("name", "Town")), String(_town_details.get("classification", "Town"))]
		city_summary.text += "\nRuler: %s %s" % [String(_town_details.get("ruler_title", "Mayor")), String(_town_details.get("ruler_name", ""))]
		city_summary.text += "\n%s: %s" % ["Prominent House", String(_town_details.get("prominent_house", ""))]
		var guild_names := PackedStringArray()
		for guild_variant: Variant in (_town_details.get("major_guilds", []) as Array):
			guild_names.append(String(guild_variant))
		if not guild_names.is_empty():
			city_summary.text += "\nGuilds: %s" % ", ".join(guild_names)
		var export_names := PackedStringArray()
		for export_variant: Variant in (_town_details.get("major_exports", []) as Array):
			export_names.append(String(export_variant))
		if not export_names.is_empty():
			city_summary.text += "\nExports: %s" % ", ".join(export_names)
		city_summary.text += "\n%s" % String(_town_details.get("hallmark", ""))
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
	# A villager under the cursor introduces themselves, matched against the
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
	return TownTileService.tile_name_from_atlas(atlas_coords, TILE_ATLAS)

func _zone_name_for_cell(cell: Vector2i) -> String:
	return TownTileService.zone_name_for_cell(cell, _latest_grid, _latest_civic_building_type_map)

func _building_type_for_cell_or_empty(cell: Vector2i) -> String:
	return TownTileService.building_type_for_cell_or_empty(cell, _latest_civic_building_type_map)

func _display_name_for_building_type(building_type: String) -> String:
	return TownTileService.display_name_for_building_type(building_type)

func _building_subtype_summary_text() -> String:
	return TownTileService.building_subtype_summary_text(_latest_civic_buildings_by_id)

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
