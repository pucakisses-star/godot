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
var _hover_tooltip_layer: TileMapLayer
var _last_move_direction := Vector2i.ZERO
var _move_repeat_timer := 0.0
var _npc_states: Array[Dictionary] = []
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
	_update_day_night_tint()
	_update_clock_label()
	_generate_city()

func _process(delta: float) -> void:
	_advance_game_clock(delta)
	_update_player_turn_movement(delta)
	_update_player_hold_movement(delta)
	_update_npc_movement(delta)
	_update_farm_animals(delta)
	_update_windmill_sails(delta)

func _advance_game_clock(delta: float) -> void:
	if minutes_per_game_day <= 0.0:
		return
	var delta_hours := delta * 24.0 / (minutes_per_game_day * 60.0)
	_game_hour += delta_hours
	while _game_hour >= 24.0:
		_game_hour -= 24.0
		_game_day += 1
	# Strolling the market works up an appetite too.
	_player_satiety = clampf(_player_satiety - delta_hours * PlayerStatsService.SATIETY_DRAIN_PER_GAME_HOUR, 0.0, PlayerStatsService.SATIETY_MAX)
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

func _exit_tree() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings") or not game_session.has_method("set_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	settings["game_clock"] = {"hour": _game_hour, "day": _game_day}
	settings["player_satiety"] = _player_satiety
	game_session.call("set_world_settings", settings)

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
	_latest_zone_counts = level_data.get("zone_counts", {}) as Dictionary
	_latest_requested_zone_counts = level_data.get("requested_zone_counts", {}) as Dictionary
	_latest_civic_buildings_by_id = level_data.get("civic_buildings_by_id", {}) as Dictionary
	_latest_civic_building_type_map = level_data.get("civic_building_type_map", {}) as Dictionary
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
	for glow: Node2D in _glow_sprites:
		if is_instance_valid(glow):
			glow.visible = _lighting_enabled

func _render_city(grid: Dictionary, stair_cells: Dictionary = {}) -> void:
	if city_layer.tile_set == null:
		return
	city_layer.clear()
	decor_layer.clear()
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

func _spawn_hearth_glow(cell: Vector2i, radius_cells: float) -> void:
	var glow: Sprite2D = RoomFurnishingService.create_glow_sprite(
		_cell_center_position(cell),
		radius_cells * float(tile_size.x),
		Color(1.0, 0.72, 0.35, 1.0)
	)
	glow.visible = _lighting_enabled
	actor_layer.add_child(glow)
	_furnishing_sprites.append(glow)
	_glow_sprites.append(glow)

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
	if _green_cells.is_empty():
		return
	var animal_count := clampi(_green_cells.size() / 14, 4, 10)
	for _animal_index in range(animal_count):
		var cell := _green_cells[_rng.randi_range(0, _green_cells.size() - 1)]
		_spawn_farm_animal_at(cell, -1)

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
				if pen_index >= 0 and pen_index < _farm_pens.size():
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
func _assign_npc_identities() -> void:
	for state: Dictionary in _npc_states:
		var role_title := String(ROLE_TITLES.get(int(state.get("role", 0)), "Villager"))
		var identity: Dictionary = NpcIdentityService.generate(_rng, role_title, "townsfolk")
		state["identity"] = identity
		state["npc_name"] = String(identity.get("name", "A villager"))

func _show_npc_dialogue(state: Dictionary) -> void:
	var role_title := String(ROLE_TITLES.get(int(state.get("role", 0)), "Villager"))
	if not state.has("identity"):
		state["identity"] = NpcIdentityService.generate(_rng, role_title, "townsfolk")
		state["npc_name"] = String((state["identity"] as Dictionary).get("name", "A villager"))
	var identity := state.get("identity", {}) as Dictionary
	# Sometimes they talk about themselves instead of the news.
	var line: String
	if _rng.randf() < 0.4:
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
	_assign_npc_daily_lives(grid)
	_assign_npc_identities()
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
	var tooltip_position := _clamp_tooltip_position(mouse_position + Vector2(16, 16))
	if tile_hover_tooltip.visible and hovered_cell == _hover_tooltip_cell and hovered_layer == _hover_tooltip_layer:
		tile_hover_tooltip.position = tooltip_position
		return

	var atlas_coords := hovered_layer.get_cell_atlas_coords(hovered_cell)
	var tile_name := _tile_name_from_atlas(atlas_coords)
	var zone_name := _zone_name_for_cell(hovered_cell)
	var tooltip_lines: PackedStringArray = []
	# A villager under the cursor introduces themselves, Dwarf Fortress style.
	var hovered_npc := _npc_state_at_cell(hovered_cell)
	if not hovered_npc.is_empty() and hovered_npc.has("identity"):
		var identity := hovered_npc.get("identity", {}) as Dictionary
		tooltip_lines.append(NpcIdentityService.summary_line(identity))
		for detail: String in NpcIdentityService.detail_lines(identity):
			tooltip_lines.append(detail)
		tooltip_lines.append("")
	tooltip_lines.append("Tile: %s" % tile_name)
	tooltip_lines.append("Zone: %s" % zone_name)
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
	return TownTileService.tile_name_from_atlas(atlas_coords, TILE_ATLAS)

func _zone_name_for_cell(cell: Vector2i) -> String:
	return TownTileService.zone_name_for_cell(cell, _latest_grid, _latest_civic_building_type_map)

func _building_type_for_cell_or_empty(cell: Vector2i) -> String:
	return TownTileService.building_type_for_cell_or_empty(cell, _latest_civic_building_type_map)

func _display_name_for_building_type(building_type: String) -> String:
	return TownTileService.display_name_for_building_type(building_type)

func _building_subtype_summary_text() -> String:
	return TownTileService.building_subtype_summary_text(_latest_civic_buildings_by_id)

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
