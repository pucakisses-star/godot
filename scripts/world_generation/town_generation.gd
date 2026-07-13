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
## Towns keep MODEST cellars: the surface village plus at most one storage
## cellar level. The shared population clamp respects this maximum, so towns
## never dig the dwarfhold's 4+ strata.
@export var underground_level_count_range := Vector2i(1, 2)
## Real minutes for one full in-game day.
# 24 real minutes per game day = one game-minute per real second.
@export var minutes_per_game_day := 24.0
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
## The timber-framed room 9-slice. These pieces are cut out toward the
## building exterior, so they are stamped on the decor layer over a ground
## tile (see the paint loop) instead of directly on the terrain layer.
const WALL_FRAME_TILE_KEYS: Array[String] = [
	"wall_tl", "wall_top", "wall_tr",
	"wall_left", "wall_fill", "wall_right",
	"wall_bl", "wall_bottom", "wall_br"
]



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
var _crate_armed := ""
var _trade_shop_type := ""
## The real-world cell the walk-away leash measures while a trade popup is
## open; traveler stocks anchor at a synthetic far-away cell, so the leash
## needs the trader's actual spot (sentinel = fall back to the shop anchor).
var _trade_leash_cell := Vector2i(2147483647, 2147483647)
var _shop_stocks: Dictionary = {}
## Game day each shop anchor last rerolled its shelves.
var _shop_restock_day: Dictionary = {}
var _active_speech_bubble: PanelContainer
var _escape_menu: EscapeMenu
var _game_over: GameOverScreen
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
## The hotbar slot last used (-1 = none): drives the held-item sprite.
var _selected_hotbar_index := -1
## Items dropped to the world, each { sprite, cell, item, count }; walking
## onto a cell scoops it back up.
var _ground_items: Array[Dictionary] = []
## Invisible full-rect drop target that turns a slot drag into a world drop.
var _drop_catcher: Control
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
## Venue cells (tavern, chapel, market...) for the scheduler's objectives.
var _npc_pois: Dictionary = {}
var _settlement_factions: Array[Dictionary] = []
var _surface_noise: Dictionary = {}
var _surface_chunks: Dictionary = {}
var _surface_last_player_chunk := Vector2i(2147483647, 2147483647)
var _surface_protect_rect := Rect2i()
var _surface_world_origin := Vector2i.ZERO
var _surface_biome_ctx: Dictionary = {}
## The biome of the overworld tile this town sits on, resolved from the
## world biome buffer at setup. Drives the ground palette (snow on tundra).
var _town_ground_biome := ""
var _surface_road_cells: Dictionary = {}
var _surface_blocked_cells: Dictionary = {}
## Per-streaming-pass memo of terrain families sampled for seam autotiling
## (cleared each pass; deterministic, so staleness only costs recompute).
var _surface_family_memo: Dictionary = {}
## Lazy atlas-coords -> terrain-family lookup for painted ground cells.
var _atlas_family_by_coords: Dictionary = {}
## Dark-grass blob patches only grow inside this rect (the current grid's
## key bounds shrunk by one), so the painted clearing's rim stays plain and
## the streamed wilds never butt foreign terrain against a patch interior.
var _dark_grass_rect := Rect2i()
var _surface_gates: Array[Dictionary] = []
var _surface_gate_labels: Array[Label] = []
# Non-enterable ambient structures (camps, watchtowers, shrines...) that sit
# near the visited settlement, raised in the wilds as pure scenery using the
# overworld atlas art. Each entry: {anchor, tile_atlas: Vector2i, name}.
var _surface_landmarks: Array[Dictionary] = []
var _surface_landmark_layer: Node2D = null
var _surface_landmark_atlas_texture: Texture2D = null
## Sliding site window: the whole overworld gazetteer, cached once per
## surface build, is projected into the wilds around the player's CURRENT
## overworld tile instead of one-shot around the entered settlement.
var _surface_all_sites: Array = []
var _surface_own_tile := Vector2i.ZERO
var _surface_window_tile := Vector2i(2147483647, 2147483647)
var _surface_planned_site_keys: Dictionary = {}
## Roads persist once traced (trails stay), so re-entering the window
## never re-traces; keyed by site key.
var _surface_site_road_traced: Dictionary = {}
## Cells blocked by stamped landmark footprints (furniture, props, tents),
## keyed cell -> site key so per-site unstamps release exactly their own.
var _surface_landmark_blocked_cells: Dictionary = {}
var _surface_world_seed_text := ""
var _surface_arrival_lock := false
var _surface_road_paths: Array[Array] = []
## Grass cells beside lane junctions that host a wooden direction post,
## planned by the lane tracer and rendered through _pick_decor_tile.
var _direction_post_cells: Dictionary = {}
## Shop signboards standing on the grass by a civic entrance: sign cell ->
## the establishment's anchor cell (whose maps carry its name and trade).
## Recomputed deterministically from the level data on every _show_level.
var _shop_sign_cells: Dictionary = {}
## Plaza-rim notice boards carrying seeded village notices (cell -> true).
var _notice_board_cells: Dictionary = {}
## The floating world-space label shown while the cursor rests on a sign.
var _sign_hover_label: Label
var _sign_hover_cell := Vector2i(2147483647, 2147483647)
var _surface_anchor_cells: Array[Vector2i] = []
var _surface_creatures: Array[Dictionary] = []
## Camp sites whose garrison was wiped out this visit ("x,y" site key ->
## true): a cleared camp stays quiet until the scene is re-entered.
var _camp_cleared_sites: Dictionary = {}
var _surface_spawn_timer := 0.0
var _surface_ambush_stamp := -1
var _player_hp := PlayerStatsService.BASE_MAX_HP
var _player_max_hp := PlayerStatsService.BASE_MAX_HP
var _player_home_cell := Vector2i.ZERO
var _hp_label: Label
var _gear_label: Label
const WorldMinimapScript := preload("res://scripts/ui/world_minimap.gd")
var _minimap: WorldMinimapScript
var _minimap_refresh_timer := 0.0
var _minimap_last_player_cell := Vector2i(2147483647, 2147483647)
const MINIMAP_REFRESH_SECONDS := 0.2
## Fog-of-war exploration: every cell the walker has actually seen (a disc
## of EXPLORE_RADIUS around each cell stood on), stored per 32x32 chunk of
## shared WORLD space (scene cell + _surface_world_origin) as a bitmask so
## the expanded map can black out ground never visited.
const EXPLORE_RADIUS := 14
const EXPLORE_CHUNK_SHIFT := 5
const EXPLORE_CHUNK_SIZE := 1 << EXPLORE_CHUNK_SHIFT
const EXPLORE_CHUNK_BYTES := (EXPLORE_CHUNK_SIZE * EXPLORE_CHUNK_SIZE) >> 3
const EXPLORE_PERSIST_SECONDS := 3.0
## Vector2i world-chunk -> PackedByteArray(EXPLORE_CHUNK_BYTES) bitmask.
var _explored_chunks: Dictionary = {}
var _explored_last_cell := Vector2i(2147483647, 2147483647)
var _explored_dirty := false
var _explored_persist_timer := 0.0
## The circular stamp of offsets marked around the player, built once.
var _explore_disc_offsets: Array[Vector2i] = []
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
# Absolute game-hours at the last growth re-rate, so a frame that crosses
# several hours slides the planting stamp by all of them, not just one.
var _farm_last_growth_hours := -1.0
var _raid_active := false
var _raid_end_stamp := 0.0
var _next_raid_day := 0
var _music_timer := 0.0
var _wall_damage: Dictionary = {}
var _speed_scale_cache := 1.0
var _inventory_screen: PlayerInventoryPanel
var _npc_inspection_card: NpcInspectionCard
var _player_hotbar: PlayerHotbar
var _factions_label: RichTextLabel
var _faction_event_stamps: Dictionary = {}
var _town_name := ""
var _town_details: Dictionary = {}
var _town_market: Dictionary = {}
var _caravan_job: Dictionary = {}
var _caravan_next_offer_stamp := 0.0
var _caravan_offer_dialog: ConfirmationDialog
var _game_hour := 9.0
var _game_day := 1
var _calendar_start_year := 250
var _bed_cells: Array[Vector2i] = []
var _green_cells: Array[Vector2i] = []
## Village dressing planned at generation time (deterministic per seed):
## fenced garden yards beside houses and the market-square well anchor.
var _village_yards: Array = []
var _village_well_cell := Vector2i(2147483647, 2147483647)
var _farm_animals: Array[Dictionary] = []
var _farm_animal_textures: Dictionary = {}
var _pending_player_spawn_cell := Vector2i(2147483647, 2147483647)
var _town_theme := ""
## Hamlets/snow villages keep the Village classification regardless of
## population (browser generateHamletDetails).
var _town_is_village := false
## True for an open-wild embark: no settlement is generated, just a walkable
## biome clearing the player spawns onto (see TOWN_SCENE_WILD_KEY).
var _wild_mode := false
## The clearing is tiny, so the spawn framing must land on the player; the
## city panel may still be unsized when _show_level runs on the first frame,
## so we re-center once its layout settles.
var _wild_needs_recenter := false
## True for an open-water wild embark: the clearing is drawn as sea, the ocean
## is the walkable medium, and the player spawns afloat.
var _wild_water := false
## Active fishing: cast with F beside water, wait for the bite, reel on the "!".
var _fishing_state: Dictionary = {}
var _bobber_texture: Texture2D
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
# Core Keeper-style shoreline reflections: a screen-sampling shader quad
# follows the view, masked to the water cells it currently covers.
const WATER_REFLECTION_SHADER := preload("res://shaders/water_reflection.gdshader")
var _reflection_sprite: Sprite2D
var _reflection_mask_texture: ImageTexture
var _reflection_rect_cells := Rect2i()
var _reflection_rebuild_timer := 0.0
var _passable_atlas_set: Dictionary = {}
var _actor_passable_cache: Dictionary = {}
## Atlas coords of the full-tree and understory decor tiles, filled once and
## used by the post-paint pass that clears stumps/bushes out from under trees.
var _tree_decor_set: Dictionary = {}
var _understory_decor_set: Dictionary = {}
var _last_clock_stamp := -1
var _applied_day_night_tint := Color(-1.0, -1.0, -1.0, -1.0)
var _player_satiety := PlayerStatsService.SATIETY_MAX
# Daily weather: a pure function of (world seed, absolute day), refreshed
# on entry and at each midnight rollover, never saved.
var _current_weather: Dictionary = {}
var _weather_overlay: Node2D
var _rain_particles: CPUParticles2D
var _snow_particles: CPUParticles2D
var _lightning_rect: ColorRect
var _lightning_countdown := 0.0
var _weather_overlay_active := true
var _weather_refill_frame := -1

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
const TOWN_SCENE_VILLAGE_KEY := "town_scene_is_village"
const TOWN_SCENE_WORLD_BIOMES_KEY := "town_scene_world_biomes"
const TOWN_SCENE_WORLD_RIVERS_KEY := "town_scene_world_rivers"
## When set, the walker embarked onto an open wild tile: raise a bare biome
## clearing (no city, no residents) so the player spawns in the wilds.
const TOWN_SCENE_WILD_KEY := "town_scene_is_wild"
## When set (wild + open water), the clearing is drawn as sea and the player
## is dropped afloat on the ocean instead of onto dry ground.
const TOWN_SCENE_WILD_WATER_KEY := "town_scene_wild_water"

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
	"grass_tuft": "sand_pebbles",
	"grass_tuft_alt": "sand_pebbles",
	"grass_mottled": "sand_alt",
	"grass_mottled_alt": "sand_alt",
	# Desert lanes keep bare dirt: the grass-fringed path edges would paint
	# green scallops onto sand, so they collapse back to plain road art.
	"road_edge_n": "road", "road_edge_s": "road",
	"road_edge_w": "road", "road_edge_e": "road",
	"road_edge_nw": "road", "road_edge_ne": "road",
	"road_edge_sw": "road", "road_edge_se": "road",
	"road_in_nw": "road", "road_in_ne": "road",
	"road_in_sw": "road", "road_in_se": "road",
	"road_sprout": "road_alt"
}
const DESERT_SKIPPED_DECOR: Array[String] = [
	"tree", "tree_dark", "hedge", "hedge_alt",
	"flowers_white", "flowers_yellow", "flowers_pink", "flowers_pink_alt",
	"stump", "stump_alt"
]
## Tundra towns sit on snow: the grass-family ground tiles swap to the
## painted-in snow tiles (mirrors DESERT_BASE_SWAP), and grassland greenery
## (bushes, hedges, blooms) is skipped so the settled area reads as winter.
## The scatter trees ("tree"/"tree_dark") swap to their snow-capped variants
## in _pick_decor_tile, and the path-fringe tiles swap to their snow recolors
## (appended atlas row 28) so lanes scallop into the snowfield instead of
## sprouting grass.
const SNOW_BASE_SWAP := {
	"grass": "snow",
	"grass_dark": "snow_alt",
	"grass_tuft": "snow_alt",
	"grass_tuft_alt": "snow_alt",
	"grass_mottled": "snow",
	"grass_mottled_alt": "snow",
	"road_edge_n": "road_edge_n_snow", "road_edge_s": "road_edge_s_snow",
	"road_edge_w": "road_edge_w_snow", "road_edge_e": "road_edge_e_snow",
	"road_in_nw": "road_in_nw_snow", "road_in_ne": "road_in_ne_snow",
	"road_in_sw": "road_in_sw_snow", "road_in_se": "road_in_se_snow",
	"road_edge_nw": "road_edge_nw_snow", "road_edge_ne": "road_edge_ne_snow",
	"road_edge_sw": "road_edge_sw_snow", "road_edge_se": "road_edge_se_snow",
	"road_sprout": "road"
}
const SNOW_SKIPPED_DECOR: Array[String] = [
	"hedge", "hedge_alt", "flowers_white", "flowers_yellow",
	"flowers_pink", "flowers_pink_alt"
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

## Footprints are half-extents: a (3,2) minimum is a 7x5 gross plot, a
## (5,4) maximum an 11x9 one — big enough for the interior planner to
## split every shop into a shopfront plus back rooms (multi-room plots
## need at least a 4-gross span per axis or they get demolished).
const CIVIC_BUILDING_TYPES := {
	"smithy": {
		"placement_weight": 1.1,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["forge", "armor_stand", "barrel", "bucket"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.6
		}
	},
	"tavern": {
		"placement_weight": 1.2,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(5, 4),
		"decor_tile_pool": ["barrel", "jug", "bench", "counter"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.5
		}
	},
	"inn": {
		"placement_weight": 0.8,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(5, 4),
		"decor_tile_pool": ["bed", "counter", "barrel", "table"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.4
		}
	},
	"bakery": {
		"placement_weight": 0.9,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["oven", "sack", "counter", "table"],
		"adjacency_preferences": {}
	},
	"general_store": {
		"placement_weight": 1.0,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(5, 3),
		"decor_tile_pool": ["counter", "shelf", "sack", "pot"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.45
		}
	},
	"market_stall": {
		"placement_weight": 1.15,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(2, 2),
		"decor_tile_pool": ["stall", "stall_alt", "sack", "barrel_open"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.7
		}
	},
	"chapel": {
		"placement_weight": 0.6,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(4, 4),
		"decor_tile_pool": ["brazier", "flowers_pot", "bench", "plant_tall"],
		"adjacency_preferences": {}
	},
	"guild_hall": {
		"placement_weight": 0.55,
		"preferred_footprint_min": Vector2i(3, 3),
		"preferred_footprint_max": Vector2i(5, 4),
		"decor_tile_pool": ["table", "bench", "shelf", "chest"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.2
		}
	},
	"town_hall": {
		"placement_weight": 0.4,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(5, 4),
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
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["bench", "table", "barrel", "bucket"],
		"adjacency_preferences": {}
	},
	"tailor": {
		"placement_weight": 0.6,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["table", "dresser", "chest", "plant"],
		"adjacency_preferences": {}
	},
	"apothecary": {
		"placement_weight": 0.55,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["pot", "jug", "plant_tall", "shelf"],
		"adjacency_preferences": {}
	},
	"guardhouse": {
		"placement_weight": 0.65,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["armor_stand", "bed_alt", "chest", "bench"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.35
		}
	},
	"stable": {
		"placement_weight": 0.5,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["bucket", "sack", "bench", "barrel_open"],
		"adjacency_preferences": {}
	},
	"workshop": {
		"placement_weight": 0.8,
		"preferred_footprint_min": Vector2i(3, 2),
		"preferred_footprint_max": Vector2i(4, 3),
		"decor_tile_pool": ["bench", "table", "bucket", "barrel"],
		"adjacency_preferences": {}
	},
	## Back-of-house room roles. Never placed as standalone buildings
	## (placement_weight 0) — the interior planner retags a shopfront's
	## rear rooms with them so each room furnishes to its function: the
	## inn's kitchen, the store's stockroom, the smithy's forge annex.
	"kitchen": {
		"placement_weight": 0.0,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["oven", "pot", "sack", "bucket"],
		"adjacency_preferences": {}
	},
	"storeroom": {
		"placement_weight": 0.0,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["sack", "barrel", "chest", "barrel_open"],
		"adjacency_preferences": {}
	},
	"forge_room": {
		"placement_weight": 0.0,
		"preferred_footprint_min": Vector2i(2, 2),
		"preferred_footprint_max": Vector2i(3, 3),
		"decor_tile_pool": ["forge", "barrel", "bucket", "armor_stand"],
		"adjacency_preferences": {}
	}
}

## Back rooms behind each town shopfront, dealt from the entrance inward:
## a tavern is taproom + kitchen + bedrooms, an inn adds a bedroom wing, a
## general store keeps a stockroom, a smithy backs onto its forge annex.
## "bedroom" re-zones the room to CELL_HOUSE so it gets beds, house
## furnishing, and a slot in the NPC sleep schedule.
const TOWN_ROOM_BACK_ROLES := {
	"tavern": ["kitchen", "bedroom", "bedroom"],
	"inn": ["kitchen", "bedroom", "bedroom", "bedroom"],
	"bakery": ["kitchen", "storeroom"],
	"general_store": ["storeroom", "bedroom"],
	"smithy": ["forge_room", "storeroom"],
	"chapel": ["bedroom", "storeroom"],
	"guild_hall": ["storeroom", "bedroom"],
	"town_hall": ["storeroom", "bedroom"],
	"warehouse": ["storeroom", "storeroom"],
	"carpenter": ["workshop", "storeroom"],
	"tailor": ["storeroom", "bedroom"],
	"apothecary": ["storeroom", "bedroom"],
	"guardhouse": ["bedroom", "storeroom"],
	"stable": ["storeroom"],
	"workshop": ["storeroom"]
}

## Buildings that read as one open floor and never subdivide: a market
## stall is a single stand, a stable one straw-floored hall.
const TOWN_OPEN_PLAN_BUILDING_TYPES := ["market_stall", "stable"]

## Room roles that never earn a street signboard: nobody advertises the
## kitchen. The shopfront room keeps the building's trade and its board.
const SIGN_SKIPPED_ROOM_TYPES := {"kitchen": true, "storeroom": true, "forge_room": true}

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
	var scene_stamp: Dictionary = _world_settings_snapshot()
	scene_stamp["last_scene"] = "res://scenes/town_generation.tscn"
	_store_world_settings(scene_stamp)
	_setup_hp_label()
	_setup_inventory_screen()
	_setup_hotbar()
	_setup_drop_catcher()
	_setup_minimap()
	GameAudioService.play_music(self, "town")
	_refresh_weather(false)
	_update_day_night_tint()
	_update_clock_label()
	_generate_city()
	## The "Strike the earth!" greeting, once, on a new walker's first embark.
	EmbarkIntroScreen.maybe_present(self)

## The embark screen reads this to tailor its greeting: an ocean embark, a
## wild embark coloured by the biome at the spawn, or an arrival in a town.
func _embark_place() -> Dictionary:
	if _wild_water:
		return {"kind": "ocean"}
	if _wild_mode:
		var biome := ""
		if not _surface_biome_ctx.is_empty():
			biome = SurfaceWorldService.biome_for_world_cell(_surface_biome_ctx, _player_cell + _surface_world_origin)
		return {"kind": "wild", "biome": biome}
	return {"kind": "town", "name": _town_name}

func _process(delta: float) -> void:
	_advance_game_clock(delta)
	_player_attack_timer = maxf(_player_attack_timer - delta, 0.0)
	_staff_cooldown = maxf(_staff_cooldown - delta, 0.0)
	# Frame the wild spawn on the player once the panel has a real size.
	if _wild_needs_recenter and _player_sprite != null and city_panel.size.x > 0.0 and city_panel.size.y > 0.0:
		_center_view_on_cell(_player_cell)
		_wild_needs_recenter = false
	_stream_surface_chunks()
	_check_surface_arrival()
	_update_surface_life(delta)
	_update_companion(delta)
	_update_raid(delta)
	_update_caravan_job(delta)
	_update_fishing(delta)
	_update_music(delta)
	_update_player_turn_movement(delta)
	_update_ground_items(delta)
	_update_npc_movement(delta)
	_update_farm_animals(delta)
	_update_windmill_sails(delta)
	_update_water_reflection(delta)
	_update_weather_frame(delta)
	_update_exploration(delta)
	_update_minimap(delta)

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
	# A frame that spans ~24h can land on the same integer hour a day
	# later; catch the day rollover too so the hooks never skip a day.
	if int(_game_hour) != hour_before or _game_day != day_before:
		var clock_settings: Dictionary = _world_settings_snapshot()
		clock_settings["game_clock"] = {"hour": _game_hour, "day": _game_day}
		_store_world_settings(clock_settings)
		_refresh_player_stats_town()
		_advance_farm_growth()
		_maybe_start_raid()
		if _game_day != day_before:
			_advance_world_events()
			_refresh_weather(true)
	# Strolling the market works up an appetite too.
	_player_satiety = clampf(_player_satiety - delta_hours * PlayerStatsService.SATIETY_DRAIN_PER_GAME_HOUR, 0.0, PlayerStatsService.SATIETY_MAX)
	_advance_afflictions(delta_hours)
	_update_faction_events()
	_update_day_night_tint()
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
	var is_night := _game_hour >= 20.0 or _game_hour < 6.0
	clock_label.text = "%s %02d:%02d — %s (%s) · %s" % [
		"🌙" if is_night else "☀",
		hour,
		minute,
		GameCalendar.date_text(_game_day - 1, _calendar_start_year),
		GameCalendar.season_for_day(_game_day - 1),
		String(_current_weather.get("kind", "clear")).capitalize()
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
	# Sealed cellars see no sky: underground levels stay untinted, the
	# same way the precipitation overlay already gates on the level.
	var tint := (
		Color.WHITE
		if _is_underground_level()
		else _day_night_tint(_game_hour) * WeatherService.tint_multiplier(_current_weather)
	)
	if tint.is_equal_approx(_applied_day_night_tint):
		return
	_applied_day_night_tint = tint
	if city_layer != null:
		city_layer.modulate = tint
	if decor_layer != null:
		decor_layer.modulate = tint
	if actor_layer != null:
		actor_layer.modulate = tint
	# Landmark icons (tents, pyres, great trees) live on a sibling layer
	# that must darken with everything else or they glow at midnight.
	if _surface_landmark_layer != null and is_instance_valid(_surface_landmark_layer):
		_surface_landmark_layer.modulate = tint

## --- Weather -----------------------------------------------------------------
## The sky is WeatherService.weather_for_day(world seed, absolute day):
## the same day always looks the same, so nothing weather-shaped persists.
## Precipitation is a screen-space veil in panel coordinates (parented
## beside the zoomed map layers, not inside them), so it covers the
## visible panel at any pan or zoom.

const WEATHER_TICKER_LINES := {
	"clear": "The clouds break; sunlight returns to the streets.",
	"overcast": "Grey clouds roll in over the rooftops.",
	"rain": "Rain sets in over the fields.",
	"storm": "A storm breaks over the town — folk hurry indoors.",
	"snow": "Snow begins to fall, hushing the streets."
}
const WEATHER_TICKER_COLOR := Color(0.7, 0.82, 0.95, 1.0)
const WEATHER_EMIT_MARGIN := 48.0
const RAIN_FALL_SPEED := 620.0
const SNOW_FALL_SPEED := 55.0
const LIGHTNING_INTERVAL_RANGE := Vector2(6.0, 14.0)

func _refresh_weather(announce: bool) -> void:
	var settings: Dictionary = _world_settings_snapshot()
	var world_seed_text := str(settings.get("world_seed", seed_input.text.strip_edges()))
	var previous_kind := String(_current_weather.get("kind", ""))
	_current_weather = WeatherService.weather_for_day(world_seed_text, _game_day - 1)
	var kind := String(_current_weather.get("kind", "clear"))
	if announce and kind != previous_kind and WEATHER_TICKER_LINES.has(kind):
		_set_save_status(String(WEATHER_TICKER_LINES[kind]), WEATHER_TICKER_COLOR)
	# The weather multiplies into the cached tint and the clock suffix.
	_applied_day_night_tint = Color(-1.0, -1.0, -1.0, -1.0)
	_last_clock_stamp = -1
	_update_day_night_tint()
	_update_clock_label()
	_update_weather_visuals()

func _update_weather_visuals() -> void:
	_ensure_weather_overlay()
	var kind := String(_current_weather.get("kind", "clear"))
	var intensity := clampf(float(_current_weather.get("intensity", 0.5)), 0.0, 1.0)
	# Rain and snow fall on the surface level only; cellars stay dry.
	var active := _weather_overlay_active and _hold_state.current_level_index == 0
	_weather_overlay.visible = active
	var rain_amount := maxi(1, int(140.0 * intensity * (1.6 if kind == "storm" else 1.0)))
	_configure_precipitation(_rain_particles, rain_amount, active and (kind == "rain" or kind == "storm"))
	_configure_precipitation(_snow_particles, maxi(1, int(110.0 * intensity)), active and kind == "snow")
	if not (active and kind == "storm"):
		_lightning_rect.modulate.a = 0.0
	_apply_weather_to_reflection()

## Touching CPUParticles2D.amount clears the live pool without re-running
## preprocess, leaving a bare sky for a full fall cycle — so only apply
## changes, then queue a restart (which re-runs preprocess) for a later
## frame: a restart on the scene's add/_ready frame never takes.
func _configure_precipitation(particles: CPUParticles2D, target_amount: int, emit: bool) -> void:
	if particles.amount == target_amount and particles.emitting == emit:
		return
	particles.amount = target_amount
	particles.emitting = emit
	if emit:
		_weather_refill_frame = int(Engine.get_process_frames())

## Per-frame: pause the veil while the panel is hidden and roll the
## lightning clock during storms (the tree's pause stops _process itself).
func _update_weather_frame(delta: float) -> void:
	if _weather_overlay == null or not is_instance_valid(_weather_overlay):
		return
	var active := city_panel.is_visible_in_tree()
	if active != _weather_overlay_active:
		_weather_overlay_active = active
		_update_weather_visuals()
	if not active or _hold_state.current_level_index != 0:
		return
	# A stalled frame (city generation, window drags) fast-forwards the
	# particle pool past its lifetime and empties the sky; refill on a
	# later calm frame, when preprocess can re-fill the whole drop.
	if delta > 0.5:
		_weather_refill_frame = int(Engine.get_process_frames())
	elif _weather_refill_frame >= 0 and int(Engine.get_process_frames()) > _weather_refill_frame:
		_weather_refill_frame = -1
		if _rain_particles.emitting:
			_rain_particles.restart()
		if _snow_particles.emitting:
			_snow_particles.restart()
	if String(_current_weather.get("kind", "")) != "storm":
		return
	_lightning_countdown -= delta
	if _lightning_countdown > 0.0:
		return
	_lightning_countdown = _rng.randf_range(LIGHTNING_INTERVAL_RANGE.x, LIGHTNING_INTERVAL_RANGE.y)
	_flash_lightning()

func _flash_lightning() -> void:
	_lightning_rect.size = city_panel.size
	var tween := create_tween()
	tween.tween_property(_lightning_rect, "modulate:a", 0.25, 0.06)
	tween.tween_property(_lightning_rect, "modulate:a", 0.0, 0.3)

func _ensure_weather_overlay() -> void:
	if _weather_overlay != null and is_instance_valid(_weather_overlay):
		return
	_weather_overlay = Node2D.new()
	_weather_overlay.name = "WeatherOverlay"
	# Above the light overlay (14), below floating text (30); clipped by
	# the panel like every other map layer.
	_weather_overlay.z_index = 15
	city_panel.add_child(_weather_overlay)
	_rain_particles = CPUParticles2D.new()
	_rain_particles.name = "RainParticles"
	_rain_particles.texture = _make_weather_texture(Vector2i(2, 6), Color(0.72, 0.82, 1.0, 0.85), false)
	_rain_particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rain_particles.emitting = false
	_rain_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain_particles.direction = Vector2(0.12, 1.0)
	_rain_particles.spread = 2.0
	_rain_particles.gravity = Vector2.ZERO
	_rain_particles.initial_velocity_min = RAIN_FALL_SPEED * 0.9
	_rain_particles.initial_velocity_max = RAIN_FALL_SPEED * 1.1
	# Streaks lean into their down-right fall (canvas rotation is y-down).
	_rain_particles.angle_min = -7.0
	_rain_particles.angle_max = -7.0
	_weather_overlay.add_child(_rain_particles)
	_snow_particles = CPUParticles2D.new()
	_snow_particles.name = "SnowParticles"
	_snow_particles.texture = _make_weather_texture(Vector2i(3, 3), Color(1.0, 1.0, 1.0, 0.9), true)
	_snow_particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_snow_particles.emitting = false
	_snow_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_snow_particles.direction = Vector2(0.0, 1.0)
	_snow_particles.spread = 25.0
	_snow_particles.gravity = Vector2(0.0, 8.0)
	_snow_particles.initial_velocity_min = SNOW_FALL_SPEED * 0.7
	_snow_particles.initial_velocity_max = SNOW_FALL_SPEED * 1.3
	# Flakes wander sideways instead of falling plumb.
	_snow_particles.tangential_accel_min = -14.0
	_snow_particles.tangential_accel_max = 14.0
	_weather_overlay.add_child(_snow_particles)
	_lightning_rect = ColorRect.new()
	_lightning_rect.name = "LightningFlash"
	_lightning_rect.color = Color(1.0, 1.0, 1.0, 1.0)
	_lightning_rect.modulate.a = 0.0
	_lightning_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weather_overlay.add_child(_lightning_rect)
	if not city_panel.resized.is_connected(_layout_weather_overlay):
		city_panel.resized.connect(_layout_weather_overlay)
	_layout_weather_overlay()

## Emission spans the panel plus a margin; lifetimes cover the full drop
## so drift fills the view (preprocess hides the empty first seconds).
func _layout_weather_overlay() -> void:
	if _weather_overlay == null or not is_instance_valid(_weather_overlay):
		return
	var panel_size := city_panel.size
	var drop_height := panel_size.y + WEATHER_EMIT_MARGIN * 2.0
	var emit_center := Vector2(panel_size.x * 0.5, -WEATHER_EMIT_MARGIN)
	var emit_extents := Vector2(panel_size.x * 0.5 + WEATHER_EMIT_MARGIN, 8.0)
	_rain_particles.position = emit_center
	_rain_particles.emission_rect_extents = emit_extents
	_rain_particles.lifetime = maxf(0.4, drop_height / RAIN_FALL_SPEED)
	_rain_particles.preprocess = _rain_particles.lifetime
	_snow_particles.position = emit_center
	_snow_particles.emission_rect_extents = emit_extents
	_snow_particles.lifetime = maxf(2.0, drop_height / SNOW_FALL_SPEED)
	_snow_particles.preprocess = _snow_particles.lifetime
	_lightning_rect.position = Vector2.ZERO
	_lightning_rect.size = panel_size
	# New lifetimes only take hold on a fresh cycle; refill active veils.
	if _rain_particles.emitting or _snow_particles.emitting:
		_weather_refill_frame = int(Engine.get_process_frames())

func _make_weather_texture(texture_size: Vector2i, color: Color, round_corners: bool) -> ImageTexture:
	var image := Image.create(texture_size.x, texture_size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	if round_corners:
		var clear := Color(0.0, 0.0, 0.0, 0.0)
		image.set_pixel(0, 0, clear)
		image.set_pixel(texture_size.x - 1, 0, clear)
		image.set_pixel(0, texture_size.y - 1, clear)
		image.set_pixel(texture_size.x - 1, texture_size.y - 1, clear)
	return ImageTexture.create_from_image(image)

func _apply_weather_to_reflection() -> void:
	if _reflection_sprite == null or not is_instance_valid(_reflection_sprite):
		return
	(_reflection_sprite.material as ShaderMaterial).set_shader_parameter("rain_ripple", _weather_rain_ripple())

func _weather_rain_ripple() -> float:
	var kind := String(_current_weather.get("kind", "clear"))
	if kind != "rain" and kind != "storm":
		return 0.0
	return clampf(float(_current_weather.get("intensity", 0.5)), 0.3, 1.0)

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
			KEY_F:
				_handle_fish_action()
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
			_:
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
	_refresh_weather(false)
	_update_day_night_tint()
	_update_clock_label()

func _exit_tree() -> void:
	flush_session_state()

## Pushes the live clock/HP/satiety into the session. Runs on scene exit
## AND whenever SaveGameService writes a slot, so saves capture now.
func flush_session_state() -> void:
	# Once the game-over modal owns the session, the death-moment flush has
	# already run; the dying scene must not smear its zeroed state over a
	# freshly loaded save or a stripped successor session as it exits.
	if _game_over != null and is_instance_valid(_game_over):
		return
	# The explored mask rides the same flush: scene exits and slot saves
	# both capture the freshest fog-of-war state.
	_flush_exploration()
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

## The corner minimap lives inside the map viewport (top_level, so the
## PanelContainer does not stretch it) and reads the live scene each redraw.
func _setup_minimap() -> void:
	if city_panel == null:
		return
	_minimap = WorldMinimapScript.new()
	_minimap.name = "WorldMinimap"
	# The root TownGeneration Control is not a layout container, so a direct
	# child keeps the fixed corner size we set instead of being stretched.
	add_child(_minimap)
	_minimap.configure(self)

## Recenter and repaint on a throttle, or immediately when the player steps
## to a new cell, so the map tracks movement without rebuilding every frame.
func _update_minimap(delta: float) -> void:
	if _minimap == null or not is_instance_valid(_minimap):
		return
	_minimap_refresh_timer -= delta
	if _player_cell != _minimap_last_player_cell:
		_minimap_last_player_cell = _player_cell
		_minimap_refresh_timer = 0.0
	if _minimap_refresh_timer > 0.0:
		return
	_minimap_refresh_timer = MINIMAP_REFRESH_SECONDS
	_minimap.refresh()

## --- fog-of-war exploration ---------------------------------------------
## The expanded map (M) only shows land the walker has actually seen: the
## corridor walked plus a view disc around it. Tracking is hot-path cheap -
## work happens only on the frame the player crosses into a new cell - and
## the mask persists through world settings like the homestead does.

## Marks the view disc when the player enters a new cell, then banks dirty
## bits into the session settings on a slow throttle.
func _update_exploration(delta: float) -> void:
	if _player_sprite == null or _is_underground_level():
		return
	if _player_cell != _explored_last_cell:
		_explored_last_cell = _player_cell
		_mark_explored_around(_player_cell)
	if not _explored_dirty:
		return
	_explored_persist_timer -= delta
	if _explored_persist_timer <= 0.0:
		_persist_exploration()

## Sets the explored bit for every cell of the circular view disc around a
## scene cell. Offsets run row-major so consecutive cells usually share a
## chunk: the chunk's mask is fetched once and written back only on change
## (PackedByteArray copies on write, so the write-back is required).
func _mark_explored_around(center_cell: Vector2i) -> void:
	if _explore_disc_offsets.is_empty():
		for disc_dy: int in range(-EXPLORE_RADIUS, EXPLORE_RADIUS + 1):
			for disc_dx: int in range(-EXPLORE_RADIUS, EXPLORE_RADIUS + 1):
				if disc_dx * disc_dx + disc_dy * disc_dy <= EXPLORE_RADIUS * EXPLORE_RADIUS:
					_explore_disc_offsets.append(Vector2i(disc_dx, disc_dy))
	var world_center := center_cell + _surface_world_origin
	var cached_chunk := Vector2i(2147483647, 2147483647)
	var mask := PackedByteArray()
	var mask_changed := false
	for offset: Vector2i in _explore_disc_offsets:
		var world_cell := world_center + offset
		var chunk := Vector2i(world_cell.x >> EXPLORE_CHUNK_SHIFT, world_cell.y >> EXPLORE_CHUNK_SHIFT)
		if chunk != cached_chunk:
			if mask_changed:
				_explored_chunks[cached_chunk] = mask
			var mask_variant: Variant = _explored_chunks.get(chunk)
			if mask_variant is PackedByteArray:
				mask = mask_variant as PackedByteArray
			else:
				mask = PackedByteArray()
				mask.resize(EXPLORE_CHUNK_BYTES)
			cached_chunk = chunk
			mask_changed = false
		var local_index := (world_cell.y & (EXPLORE_CHUNK_SIZE - 1)) * EXPLORE_CHUNK_SIZE + (world_cell.x & (EXPLORE_CHUNK_SIZE - 1))
		var byte_index := local_index >> 3
		var bit := 1 << (local_index & 7)
		if (mask[byte_index] & bit) == 0:
			mask[byte_index] = mask[byte_index] | bit
			mask_changed = true
			_explored_dirty = true
	if mask_changed:
		_explored_chunks[cached_chunk] = mask

## Settings key for this settlement's explored mask: world seed plus the
## scene's overworld tile, so each settlement keeps its own mask and a
## fresh world seed starts fully unexplored (no bleed between worlds).
func _explored_store_key() -> String:
	return "town_explored|%s|%d,%d" % [_surface_world_seed_text, _surface_own_tile.x, _surface_own_tile.y]

## Packs the per-chunk bitmasks into JSON-safe base64 strings under "x,y"
## chunk keys (the same convention hold_diffs/homestead cells use) and
## stores them in the shared world settings.
func _persist_exploration() -> void:
	_explored_dirty = false
	_explored_persist_timer = EXPLORE_PERSIST_SECONDS
	if _surface_world_seed_text.is_empty():
		return
	var settings: Dictionary = _world_settings_snapshot()
	var stored: Dictionary = {}
	for chunk_variant: Variant in _explored_chunks.keys():
		var chunk := chunk_variant as Vector2i
		stored["%d,%d" % [chunk.x, chunk.y]] = Marshalls.raw_to_base64(_explored_chunks[chunk_variant] as PackedByteArray)
	settings[_explored_store_key()] = stored
	_store_world_settings(settings)

## Banks any unsaved exploration; runs before the surface world (and with
## it the store key) rebuilds, and whenever the scene flushes session state.
func _flush_exploration() -> void:
	if _explored_dirty:
		_persist_exploration()

## Restores this settlement's explored mask. Runs after _setup_surface_world
## stamps the seed and tile, so a newly generated world reads a fresh key
## and comes back empty while re-entering the same settlement restores it.
func _restore_exploration(settings: Dictionary) -> void:
	_explored_chunks.clear()
	_explored_last_cell = Vector2i(2147483647, 2147483647)
	_explored_dirty = false
	_explored_persist_timer = 0.0
	var stored_variant: Variant = settings.get(_explored_store_key())
	if not (stored_variant is Dictionary):
		return
	var stored := stored_variant as Dictionary
	for key_variant: Variant in stored.keys():
		var parts := String(key_variant).split(",")
		if parts.size() != 2:
			continue
		var encoded_variant: Variant = stored[key_variant]
		if not (encoded_variant is String):
			continue
		var mask := Marshalls.base64_to_raw(encoded_variant as String)
		if mask.size() != EXPLORE_CHUNK_BYTES:
			continue
		_explored_chunks[Vector2i(int(parts[0]), int(parts[1]))] = mask

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

## Death is final: no respawn. The grave goes into the world chronicle,
## the session state flushes as it stood at the last breath, and the
## game-over screen offers a save, a successor, or the main menu.
func _handle_player_death(source_name: String) -> void:
	if _game_over != null and is_instance_valid(_game_over):
		return
	_player_hp = 0.0
	_update_hp_label()
	_player_move_path.clear()
	_player_is_moving = false
	_save_player_hp()
	var place := _town_name if not _town_name.is_empty() else "the wilds"
	_record_death_and_show_game_over(source_name, place)

## Writes the death into the persistent chronicle register (so it survives
## regeneration like the beast kills), flushes the session at the death
## date, and raises the game-over modal. The tree pauses beneath it.
func _record_death_and_show_game_over(source_name: String, place_name: String) -> void:
	var player_name := "A wanderer"
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null and game_session.has_method("get_player_character"):
		var character: Dictionary = game_session.call("get_player_character")
		var character_name := String(character.get("name", "")).strip_edges()
		if not character_name.is_empty():
			player_name = character_name
	var death_year := GameCalendar.year_for_day(_game_day - 1, _calendar_start_year)
	var settings: Dictionary = _world_settings_snapshot()
	WorldChronicleService.record_player_death(settings, player_name, place_name, death_year, source_name)
	_store_world_settings(settings)
	flush_session_state()
	if _escape_menu != null and _escape_menu.is_open():
		_escape_menu.close()
	_game_over = GameOverScreen.new()
	_game_over.character_name = player_name
	_game_over.place_name = place_name
	_game_over.date_line = GameCalendar.date_text(_game_day - 1, _calendar_start_year)
	_game_over.cause_name = source_name
	add_child(_game_over)

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

# --- Active fishing ---------------------------------------------------------
# Cast with F beside water (an Old Fishing Rod required); the bobber drifts,
# dips on a bite ("!"), and pressing F inside the bite window reels in the
# catch. Moving snaps the line; reeling early scares the fish off. Works on
# lake shores, river banks, coasts, and from the boat out on the open sea.
const FISHING_ROD_ITEM := "Old Fishing Rod"
const TOWN_FISH_CATCH_TABLE := [
	{"name": "Striped Bass", "weight": 16},
	{"name": "Silver Darter", "weight": 14},
	{"name": "Emerald Trout", "weight": 14},
	{"name": "Copperback Trout", "weight": 12},
	{"name": "Cobalt Chub", "weight": 12},
	{"name": "Marigold Carp", "weight": 10},
	{"name": "Sapphire Perch", "weight": 10},
	{"name": "Ruby Snapper", "weight": 9},
	{"name": "Jade Carp", "weight": 8},
	{"name": "Crimson Carp", "weight": 7},
	{"name": "Speckled Prawn", "weight": 6},
	{"name": "Golden Koi", "weight": 5},
	{"name": "Blossom Koi", "weight": 4},
]

func _handle_fish_action() -> void:
	if not _fishing_state.is_empty():
		if String(_fishing_state.get("phase", "")) == "bite":
			_catch_fish()
		else:
			_end_fishing("You reel in too early - nothing on the hook")
		return
	if _player_sprite == null or not _player_control_enabled:
		return
	var water_cell := _find_nearby_water_cell()
	if water_cell.x == 2147483647:
		_set_save_status("No water within casting reach", Color(0.8, 0.85, 0.95, 1.0))
		return
	if int(_player_inventory.get(FISHING_ROD_ITEM, 0)) < 1:
		_set_save_status("You need an Old Fishing Rod - search chests and camps", Color(0.95, 0.75, 0.45, 1.0))
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
	_set_save_status("You cast your line into the water...", Color(0.75, 0.85, 0.95, 1.0))

## The nearest water cell within two tiles of the walker (own cell excluded),
## using the rendered-tile test so lakes, coasts, and open sea all qualify.
func _find_nearby_water_cell() -> Vector2i:
	var best := Vector2i(2147483647, 2147483647)
	var best_distance := 999
	for offset_y in range(-2, 3):
		for offset_x in range(-2, 3):
			if offset_x == 0 and offset_y == 0:
				continue
			var candidate := _player_cell + Vector2i(offset_x, offset_y)
			if not _is_water_cell(candidate):
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
			_fishing_state["phase"] = "waiting"
			_fishing_state["timer"] = _rng.randf_range(2.0, 5.0)
			_set_save_status("The bite slips away...", Color(0.8, 0.85, 0.95, 1.0))

func _catch_fish() -> void:
	var bobber := _fishing_state.get("bobber") as Sprite2D
	var catch_position: Vector2 = bobber.position if bobber != null else _player_sprite.position
	var caught := _roll_weighted_drop(TOWN_FISH_CATCH_TABLE)
	var item_name := String(caught.get("name", "Striped Bass"))
	_add_to_inventory(item_name, 1)
	_spawn_floating_text("Caught %s!" % item_name, catch_position, Color(0.6, 0.95, 1.0, 1.0))
	var flavor: String = ItemDefsService.flavor_text(item_name)
	_end_fishing("Caught %s!%s" % [item_name, (" " + flavor) if not flavor.is_empty() else ""])

func _end_fishing(message: String) -> void:
	var bobber := _fishing_state.get("bobber") as Sprite2D
	# A level rebuild may already have freed the bobber with the actor layer.
	if bobber != null and is_instance_valid(bobber):
		bobber.queue_free()
	_fishing_state = {}
	if not message.is_empty():
		_set_save_status(message, Color(0.75, 0.85, 0.95, 1.0))

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
	# can never skip the walker across arrival triggers unchecked.
	var budget := minf(PLAYER_MOVE_SPEED * _player_speed_scale() * delta, float(tile_size.x))
	while _player_is_moving and budget > 0.0:
		var remaining := _player_sprite.position.distance_to(_player_move_target_position)
		if remaining > budget:
			_player_sprite.position = _player_sprite.position.move_toward(_player_move_target_position, budget)
			break
		budget -= remaining
		_player_sprite.position = _player_move_target_position
		_player_cell = _player_move_target_cell
		_player_is_moving = false
		_close_out_of_range_popups()
		if _try_use_stairs_at_player_cell():
			_center_view_on_world_position(_player_sprite.position)
			return
		_start_next_player_step()
	_center_view_on_world_position(_player_sprite.position)
	if not _player_is_moving:
		_finish_idle_interactions()

## Walking away slams the lid: the chest/trade popup only works within
## reach of its tile, so held keys can't shop from across the map.
func _close_out_of_range_popups() -> void:
	if chest_popup == null or not chest_popup.visible:
		return
	var anchor := _trade_shop_cell if _is_trade_mode() else _selected_chest_cell
	# Traveler trades key their stock to a synthetic far-away anchor; leash
	# against the recorded real-world cell instead whenever one is set.
	if _is_trade_mode() and _trade_leash_cell.x != 2147483647:
		anchor = _trade_leash_cell
	if anchor.x == 2147483647:
		return
	var span := _player_cell - anchor
	if maxi(absi(span.x), absi(span.y)) > 6:
		_clear_chest_selection()

func _is_text_input_focused() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit

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
	var base_texture := load(tilesheet_path) as Texture2D
	if base_texture == null:
		push_error("Unable to load town tilesheet texture at %s" % tilesheet_path)
		return
	# The shipped sheet has no snow ground art, so tundra towns render on
	# procedurally painted snow tiles appended in an extra row at the bottom.
	var texture := _build_town_atlas_texture(base_texture)
	if texture == null:
		push_error("Unable to build augmented town atlas texture from %s" % tilesheet_path)
		return

	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = tile_size
	var unique_atlas_coords: Dictionary = {}
	for atlas_coords: Vector2i in TILE_ATLAS.values():
		unique_atlas_coords[atlas_coords] = true
	for atlas_coords: Vector2i in unique_atlas_coords.keys():
		if TILE_ATLAS_DEFS.TOWN_MULTI_CELL_TILES.has(atlas_coords):
			# Full trees: one logical tile whose art spans several atlas
			# cells, anchored so the trunk sits on the map cell.
			var multi := TILE_ATLAS_DEFS.TOWN_MULTI_CELL_TILES[atlas_coords] as Dictionary
			atlas.create_tile(atlas_coords, multi.get("size", Vector2i.ONE) as Vector2i)
			var multi_data := atlas.get_tile_data(atlas_coords, 0)
			if multi_data != null:
				multi_data.texture_origin = multi.get("origin", Vector2i.ZERO) as Vector2i
		else:
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

	# The dwarfhold's own tilesheet rides the SAME tileset as source 1:
	# a hold's surface ward renders its true carved-stone streets inside
	# the town scene's world - one grid, two atlases. Stage 1 of merging
	# the hold into the walkable world.
	var hold_texture := load(HOLD_TILESHEET_PATH) as Texture2D
	if hold_texture != null:
		var hold_atlas := TileSetAtlasSource.new()
		hold_atlas.texture = hold_texture
		hold_atlas.texture_region_size = tile_size
		var hold_coords_seen: Dictionary = {}
		for hold_coords_variant: Variant in TILE_ATLAS_DEFS.DWARFHOLD_TILE_ATLAS.values():
			var hold_coords := hold_coords_variant as Vector2i
			if hold_coords_seen.has(hold_coords):
				continue
			hold_coords_seen[hold_coords] = true
			hold_atlas.create_tile(hold_coords)
			var hold_tile_data := hold_atlas.get_tile_data(hold_coords, 0)
			if hold_tile_data == null:
				continue
			if _is_hold_passable_atlas_tile(hold_coords):
				hold_tile_data.set_collision_polygons_count(0, 0)
			else:
				hold_tile_data.set_collision_polygons_count(0, 1)
				hold_tile_data.set_collision_polygon_points(0, 0, collision_polygon)
		tile_set.add_source(hold_atlas, HOLD_TILE_SOURCE_ID)

	# Frame-based water animation: each water tile cycles through the frames
	# painted beside it at atlas build, pixel-art style (no shader waves).
	for water_key: String in TILE_ATLAS_DEFS.town_water_animated_keys():
		var water_coords := TILE_ATLAS.get(water_key, Vector2i(-1, -1)) as Vector2i
		if water_coords.x < 0 or atlas.get_tile_data(water_coords, 0) == null:
			continue
		atlas.set_tile_animation_columns(water_coords, 0)
		atlas.set_tile_animation_frames_count(water_coords, TILE_ATLAS_DEFS.TOWN_WATER_ANIMATION_FRAMES)
		for frame_index: int in range(TILE_ATLAS_DEFS.TOWN_WATER_ANIMATION_FRAMES):
			atlas.set_tile_animation_frame_duration(water_coords, frame_index, 0.32)

	city_layer.tile_set = tile_set
	decor_layer.tile_set = tile_set
	# Full trees are multi-cell tiles whose art overhangs their anchor cell.
	# TileMapLayer batches tiles into rendering quadrants and clips each
	# quadrant to its cells' bounds, which shears the overhanging bottom off
	# some trees. A 1-cell quadrant gives every tile its own canvas item
	# sized to its own texture, so no tree is ever clipped. The decor layer
	# is sparse (trees, tufts, the odd prop), so the lost batching is cheap.
	decor_layer.rendering_quadrant_size = 1

## Builds the town/surface atlas texture: the shipped tilesheet with extra
## 32px rows appended at the bottom, holding procedurally painted tiles the
## PNG doesn't ship — snow ground (row 26), grass-fringed convex path
## corners composited from the edge pieces (row 27), and snow recolors of
## the whole path-fringe set for tundra lanes (row 28). Everything stays in
## source 0 so _shaded_alternative and every other atlas consumer keeps
## working.
func _build_town_atlas_texture(base_texture: Texture2D) -> ImageTexture:
	var base_image := base_texture.get_image()
	if base_image == null:
		return null
	if base_image.is_compressed():
		base_image.decompress()
	base_image.convert(Image.FORMAT_RGBA8)
	var snow_coords: Array[Vector2i] = [
		TILE_ATLAS.get("snow", Vector2i(0, 26)) as Vector2i,
		TILE_ATLAS.get("snow_alt", Vector2i(1, 26)) as Vector2i
	]
	# Every appended-row cell is addressed through the atlas table, so the
	# augmented sheet just needs to reach the deepest mapped row. Multi-cell
	# tiles (the full trees) span extra rows below their mapped coordinate.
	var max_row := 0
	for coords_variant: Variant in TILE_ATLAS.values():
		var mapped_coords := coords_variant as Vector2i
		var row_span := 1
		if TILE_ATLAS_DEFS.TOWN_MULTI_CELL_TILES.has(mapped_coords):
			var multi_entry := TILE_ATLAS_DEFS.TOWN_MULTI_CELL_TILES[mapped_coords] as Dictionary
			row_span = (multi_entry.get("size", Vector2i.ONE) as Vector2i).y
		max_row = maxi(max_row, mapped_coords.y + row_span - 1)
	var needed_height := maxi(base_image.get_height(), (max_row + 1) * tile_size.y)
	var augmented := Image.create(base_image.get_width(), needed_height, false, Image.FORMAT_RGBA8)
	augmented.blit_rect(base_image, Rect2i(Vector2i.ZERO, base_image.get_size()), Vector2i.ZERO)
	for variant_index: int in range(snow_coords.size()):
		_paint_snow_tile(augmented, snow_coords[variant_index], variant_index)
	_paint_path_fringe_tiles(augmented)
	_harmonize_demo_grass_tiles(augmented)
	_repaint_hedge_decor_tiles(augmented)
	# Water frames must exist before the fringe pass samples them as the
	# "under" terrain of the shoreline pieces.
	_paint_water_frames(augmented)
	_paint_terrain_fringe_tiles(augmented)
	# Cellar art the sheet doesn't ship: the stairway pair that links the
	# surface to its storage cellar, and the solid-earth fill around dug
	# cellar rooms.
	_paint_stair_tiles(augmented)
	_paint_cellar_rock_tile(augmented)
	# Wading shallows for wilds coasts and marsh pools.
	_paint_water_shallow_tile(augmented)
	# Tundra dressing and the ice-ruin set (wind-carved snow, the
	# snow-capped boulder, ruin floors/walls/towers/webs).
	_paint_snow_pattern_tiles(augmented)
	_paint_snow_rock_tile(augmented)
	_paint_ruin_tiles(augmented)
	# Desert dressing and the sandstone-ruin set (rippled dunes, wind
	# streaks, cacti, palm, bones, mesa rock).
	_paint_sand_pattern_tiles(augmented)
	_paint_desert_flora_tiles(augmented)
	_paint_sandstone_ruin_tiles(augmented)
	# The hold massif's grey mountain stone.
	_paint_massif_rock_tiles(augmented)
	# The churchyard-and-park kit: headstones, coffin, statue, fountain
	# quarters and the street lamp.
	_paint_graveyard_tiles(augmented)
	# A closed hold's iron-banded gate slab.
	_paint_sealed_gate_tile(augmented)
	# Lakeshore water plants (transparent decor over the animated water) and
	# the snow-dusted copies of the two full-height trees.
	_paint_water_plant_tiles(augmented)
	_paint_snowy_tree_tiles(augmented)
	return ImageTexture.create_from_image(augmented)

## The shipped sheet's flat water cells that seed the animation palette.
const SHEET_WATER_SOURCE := Vector2i(0, 23)
const SHEET_WATER_CALM_SOURCE := Vector2i(1, 23)

## Paints the looping pixel-art water animation: for each of the two water
## bases, TOWN_WATER_ANIMATION_FRAMES tiles side by side. Every frame is the
## sheet's own water palette with drifting caustic dapples — pale rounded
## patches that slide and morph, Stardew style — plus a few deeper shadows.
## All sine terms use whole periods across the 16-block tile and a phase of
## one full turn across the frame loop, so tiles butt seamlessly against
## their neighbors and frame 3 flows back into frame 0.
func _paint_water_frames(image: Image) -> void:
	var blocks := 16
	var frame_count := TILE_ATLAS_DEFS.TOWN_WATER_ANIMATION_FRAMES
	for base_variant: Array in [["water", SHEET_WATER_SOURCE, false], ["water_calm", SHEET_WATER_CALM_SOURCE, true]]:
		var target_base := TILE_ATLAS.get(String(base_variant[0]), Vector2i(-1, -1)) as Vector2i
		if target_base.x < 0:
			continue
		var source := base_variant[1] as Vector2i
		var calm := bool(base_variant[2])
		# The body color: the shipped tile's average, so shore rims, the
		# reflection quad's color keying and the minimap all keep reading it
		# as the same water.
		var sum := Vector3.ZERO
		for ty: int in range(tile_size.y):
			for tx: int in range(tile_size.x):
				var pixel := image.get_pixel(source.x * tile_size.x + tx, source.y * tile_size.y + ty)
				sum += Vector3(pixel.r, pixel.g, pixel.b)
		var base_color := Color(sum.x / 1024.0, sum.y / 1024.0, sum.z / 1024.0, 1.0)
		var dapple := Color(minf(base_color.r * 1.34 + 0.10, 1.0), minf(base_color.g * 1.30 + 0.09, 1.0), minf(base_color.b * 1.16 + 0.05, 1.0), 1.0)
		var dapple_soft := base_color.lerp(dapple, 0.45)
		var deep := Color(base_color.r * 0.88, base_color.g * 0.90, base_color.b * 0.96, 1.0)
		for frame_index: int in range(frame_count):
			var phase := TAU * float(frame_index) / float(frame_count)
			var origin := Vector2i((target_base.x + frame_index) * tile_size.x, target_base.y * tile_size.y)
			for by: int in range(blocks):
				for bx: int in range(blocks):
					# One dominant low-frequency lobe field (large connected
					# caustic patches, reference style) nudged by a faster
					# counter-drifting ripple; whole periods per tile.
					var u := TAU * float(bx) / float(blocks)
					var v := TAU * float(by) / float(blocks)
					# Asymmetric spatial phases keep features off the tile's
					# center/corners; per-block hash jitter rags the blob
					# edges so the pattern reads organic, not gridded.
					var swell := sin(u + 0.7 + phase) * sin(v + 2.3 - phase) * 1.25 \
						+ sin(u + v * 2.0 + 1.1 + phase) * 0.45 \
						+ sin(u * 2.0 - v + 4.2 + phase * 2.0) * 0.3 \
						+ float(absi(hash(Vector2i(bx * 7 + 3, by * 5 + 1))) % 100) * 0.007 - 0.35
					# Static per-block grain so the body is not one flat tone.
					var grain := float(absi(hash(Vector2i(bx, by)) * 31) % 7 - 3) * 0.006
					var tone := Color(clampf(base_color.r + grain, 0.0, 1.0), clampf(base_color.g + grain, 0.0, 1.0), clampf(base_color.b + grain, 0.0, 1.0), 1.0)
					var dapple_cut := 1.15 if calm else 0.82
					if swell > dapple_cut + 0.34:
						tone = dapple
					elif swell > dapple_cut:
						tone = dapple_soft
					elif not calm and swell < -1.28:
						tone = deep
					for py: int in range(2):
						for px: int in range(2):
							image.set_pixel(origin.x + bx * 2 + px, origin.y + by * 2 + py, tone)

## The sheet's grass-demo region (dark patches, tufts, mottled blends) sits
## on its own mid-green (140,169,66), while the game's plain grass tile is
## the flat (160,174,68). Left alone, every tuft/mottled accent and every
## dark-patch fringe reads as a ghost square against the plain lawn - the
## very hard cut this pass removes. Repaint the demo mid-green with the
## plain grass color on all mapped demo tiles (before the dark-piece
## compositor runs, so the synthesized extras inherit the fix).
func _harmonize_demo_grass_tiles(image: Image) -> void:
	var plain := (TILE_ATLAS.get("grass", Vector2i(1, 1)) as Vector2i) * tile_size
	var plain_color := image.get_pixel(plain.x, plain.y)
	var demo_keys: Array[String] = [
		"grass_dark", "grass_dark_edge_n", "grass_dark_edge_s",
		"grass_dark_edge_w", "grass_dark_edge_e",
		"grass_dark_edge_nw", "grass_dark_edge_ne",
		"grass_dark_edge_sw", "grass_dark_edge_se",
		"grass_dark_in_nw", "grass_dark_in_ne",
		"grass_dark_in_sw", "grass_dark_in_se",
		"grass_tuft", "grass_tuft_alt", "grass_mottled", "grass_mottled_alt"
	]
	for demo_key: String in demo_keys:
		var coords := TILE_ATLAS.get(demo_key, Vector2i(-1, -1)) as Vector2i
		if coords.x < 0:
			continue
		for ty: int in range(tile_size.y):
			for tx: int in range(tile_size.x):
				var pixel := image.get_pixel(coords.x * tile_size.x + tx, coords.y * tile_size.y + ty)
				if pixel.r8 == 140 and pixel.g8 == 169 and pixel.b8 == 66:
					image.set_pixel(coords.x * tile_size.x + tx, coords.y * tile_size.y + ty, plain_color)

## The sheet's lone standalone bush: a rounded shrub with a transparent
## surround and its own ground shadow, sitting unmapped next to the fence
## family. It becomes the single-cell hedge decor art below.
const SHEET_HEDGE_BUSH_SOURCE := Vector2i(14, 9)

## The mapped "hedge"/"hedge_alt" cells (15,7)/(16,7) are interior slabs of
## the sheet's big multi-tile hedge blob: opaque edge to edge, and mostly the
## flat demo dark-grass ground (106,164,65) the demo scene sat on.
## Stamped as single-cell decor they render as wrong-colored green squares
## over the real ground instead of bushes. Color-keying that backing away
## leaves only ragged edge scraps (the bush art itself lives in other cells),
## so instead both cells are repainted with the sheet's own standalone bush
## - mirrored for the alt so the pair still reads as two variants. The decor
## layer draws over the ground tile, so the transparent surround is correct.
func _repaint_hedge_decor_tiles(image: Image) -> void:
	var source := SHEET_HEDGE_BUSH_SOURCE * tile_size
	for hedge_variant: Array in [["hedge", false], ["hedge_alt", true]]:
		var coords := TILE_ATLAS.get(String(hedge_variant[0]), Vector2i(-1, -1)) as Vector2i
		if coords.x < 0:
			continue
		var mirrored := bool(hedge_variant[1])
		for ty: int in range(tile_size.y):
			for tx: int in range(tile_size.x):
				var source_x := (tile_size.x - 1 - tx) if mirrored else tx
				var pixel := image.get_pixel(source.x + source_x, source.y + ty)
				image.set_pixel(coords.x * tile_size.x + tx, coords.y * tile_size.y + ty, pixel)

## A pixel of the path-fringe art counts as vegetation when green clearly
## leads red (leaf greens) OR clearly leads blue (the olive tuft speckles:
## measured g-b >= 73 for tufts vs <= 55 for every dirt tone in the fringe
## set). Dirt browns and dark outline pixels stay with the dirt side so
## edges keep their definition.
func _fringe_pixel_is_grass(color: Color) -> bool:
	if color.a <= 0.15:
		return false
	return color.g8 > color.r8 + 8 or color.g8 - color.b8 >= 62

## Composites the missing convex path corners (grass on two adjacent sides)
## from unions of the sheet's edge pieces, then recolors the full fringe set
## with the painted snow ground for tundra lanes. Deterministic: pure pixel
## transforms of shipped art plus the seeded snow tile.
func _paint_path_fringe_tiles(image: Image) -> void:
	var edge_sources := {
		"n": TILE_ATLAS.get("road_edge_n", Vector2i.ZERO) as Vector2i,
		"s": TILE_ATLAS.get("road_edge_s", Vector2i.ZERO) as Vector2i,
		"w": TILE_ATLAS.get("road_edge_w", Vector2i.ZERO) as Vector2i,
		"e": TILE_ATLAS.get("road_edge_e", Vector2i.ZERO) as Vector2i
	}
	# Convex corners: keep the dirt of one edge piece, but let either
	# source's grass win so the fringe wraps both named sides.
	var corner_recipes := {
		"road_edge_nw": ["n", "w"],
		"road_edge_ne": ["n", "e"],
		"road_edge_sw": ["s", "w"],
		"road_edge_se": ["s", "e"]
	}
	for corner_key: String in corner_recipes.keys():
		var sides := corner_recipes[corner_key] as Array
		var primary := edge_sources[sides[0]] as Vector2i
		var secondary := edge_sources[sides[1]] as Vector2i
		var target := TILE_ATLAS.get(corner_key, Vector2i.ZERO) as Vector2i
		for ty: int in range(tile_size.y):
			for tx: int in range(tile_size.x):
				var primary_pixel := image.get_pixel(primary.x * tile_size.x + tx, primary.y * tile_size.y + ty)
				var secondary_pixel := image.get_pixel(secondary.x * tile_size.x + tx, secondary.y * tile_size.y + ty)
				var out := primary_pixel
				if not _fringe_pixel_is_grass(primary_pixel) and _fringe_pixel_is_grass(secondary_pixel):
					out = secondary_pixel
				image.set_pixel(target.x * tile_size.x + tx, target.y * tile_size.y + ty, out)
	# Snow recolors: copy each fringe piece and swap its grass pixels for
	# the painted snow ground at the same offsets.
	var snow_origin := (TILE_ATLAS.get("snow", Vector2i(0, 26)) as Vector2i) * tile_size
	var fringe_keys: Array[String] = [
		"road_edge_n", "road_edge_s", "road_edge_w", "road_edge_e",
		"road_in_nw", "road_in_ne", "road_in_sw", "road_in_se",
		"road_edge_nw", "road_edge_ne", "road_edge_sw", "road_edge_se"
	]
	for fringe_key: String in fringe_keys:
		var source := TILE_ATLAS.get(fringe_key, Vector2i.ZERO) as Vector2i
		var target := TILE_ATLAS.get(fringe_key + "_snow", Vector2i(-1, -1)) as Vector2i
		if target.x < 0:
			continue
		for ty: int in range(tile_size.y):
			for tx: int in range(tile_size.x):
				var source_pixel := image.get_pixel(source.x * tile_size.x + tx, source.y * tile_size.y + ty)
				var out := source_pixel
				if _fringe_pixel_is_grass(source_pixel):
					out = image.get_pixel(snow_origin.x + tx, snow_origin.y + ty)
				image.set_pixel(target.x * tile_size.x + tx, target.y * tile_size.y + ty, out)

## A pixel of the shipped dark-grass demo art that belongs to the PLAIN
## grass side: the demo uses exactly two greens (plain r=140/160 vs dark
## r=106, measured), so the red channel separates them cleanly.
func _dark_demo_pixel_is_plain(color: Color) -> bool:
	return color.r8 >= 125

## Fills in the terrain-transition art the sheet doesn't ship:
## 1) the dark-grass pieces missing from the shipped patch demo (strips,
##    peninsula tips, lone islands), composited as unions of the demo's edge
##    and corner pieces — same trick as the road convex corners; and
## 2) the synthesized fringe families of TOWN_FRINGE_FAMILIES (grass over
##    sand/water/snow, sand over water, tilled-soil fringes, snow_alt
##    drifts), painted as the under tile with the over tile scalloped across
##    each piece's open sides. Purely deterministic pixel work at 2px block
##    granularity so the results match the sheet's chunky 2x-upscaled style.
func _paint_terrain_fringe_tiles(image: Image) -> void:
	var dark_recipes := {
		"grass_dark_edge_ns": ["grass_dark_edge_n", "grass_dark_edge_s"],
		"grass_dark_edge_we": ["grass_dark_edge_w", "grass_dark_edge_e"],
		"grass_dark_tip_n": ["grass_dark_edge_nw", "grass_dark_edge_ne"],
		"grass_dark_tip_s": ["grass_dark_edge_sw", "grass_dark_edge_se"],
		"grass_dark_tip_w": ["grass_dark_edge_nw", "grass_dark_edge_sw"],
		"grass_dark_tip_e": ["grass_dark_edge_ne", "grass_dark_edge_se"],
		"grass_dark_island": ["grass_dark_edge_nw", "grass_dark_edge_ne", "grass_dark_edge_sw", "grass_dark_edge_se"]
	}
	for target_key: String in dark_recipes.keys():
		var sources := dark_recipes[target_key] as Array
		var target := TILE_ATLAS.get(target_key, Vector2i(-1, -1)) as Vector2i
		if target.x < 0:
			continue
		var primary := TILE_ATLAS.get(String(sources[0]), Vector2i.ZERO) as Vector2i
		for ty: int in range(tile_size.y):
			for tx: int in range(tile_size.x):
				var out := image.get_pixel(primary.x * tile_size.x + tx, primary.y * tile_size.y + ty)
				if not _dark_demo_pixel_is_plain(out):
					for source_index: int in range(1, sources.size()):
						var source := TILE_ATLAS.get(String(sources[source_index]), Vector2i.ZERO) as Vector2i
						var candidate := image.get_pixel(source.x * tile_size.x + tx, source.y * tile_size.y + ty)
						if _dark_demo_pixel_is_plain(candidate):
							out = candidate
							break
				image.set_pixel(target.x * tile_size.x + tx, target.y * tile_size.y + ty, out)

	for family_key: String in TILE_ATLAS_DEFS.TOWN_FRINGE_FAMILIES.keys():
		var recipe := TILE_ATLAS_DEFS.TOWN_FRINGE_FAMILIES[family_key] as Dictionary
		var under := TILE_ATLAS.get(String(recipe.get("under", "grass")), Vector2i.ZERO) as Vector2i
		var over := TILE_ATLAS.get(String(recipe.get("over", "grass")), Vector2i.ZERO) as Vector2i
		var rim := bool(recipe.get("rim", false))
		# Water-under families animate: one fringe piece per water frame,
		# sampling that frame's water as the under terrain. The scallop mask
		# is frame-independent, so the shore keeps its shape while the water
		# inside it moves in lockstep with the open-water tiles.
		var frame_count := TILE_ATLAS_DEFS.TOWN_WATER_ANIMATION_FRAMES if String(recipe.get("under", "")) == "water" else 1
		for suffix: String in TILE_ATLAS_DEFS.TOWN_FRINGE_SUFFIXES:
			var target := TILE_ATLAS.get("%s_%s" % [family_key, suffix], Vector2i(-1, -1)) as Vector2i
			if target.x < 0:
				continue
			for frame_index: int in range(frame_count):
				_paint_fringe_piece(image, target + Vector2i(frame_index, 0), under + Vector2i(frame_index, 0), over, suffix, family_key, rim)

## Paints one synthesized fringe piece: the under tile everywhere, the over
## tile across a scalloped band along each open side (union), with an
## optional darkened rim along the over side of the boundary (waterlines).
## The coverage mask lives on the 16x16 grid of 2px blocks; band depths are
## periodic two-harmonic scallops plus hashed jitter, so adjacent pieces of
## a family continue each other's fringe across tile seams.
func _paint_fringe_piece(image: Image, target: Vector2i, under: Vector2i, over: Vector2i, suffix: String, family_key: String, rim: bool) -> void:
	var blocks := 16
	var covered: Array[bool] = []
	covered.resize(blocks * blocks)
	var open_n := suffix in ["edge_n", "edge_nw", "edge_ne", "edge_ns", "tip_n", "tip_w", "tip_e", "island"]
	var open_s := suffix in ["edge_s", "edge_sw", "edge_se", "edge_ns", "tip_s", "tip_w", "tip_e", "island"]
	var open_w := suffix in ["edge_w", "edge_nw", "edge_sw", "edge_we", "tip_w", "tip_n", "tip_s", "island"]
	var open_e := suffix in ["edge_e", "edge_ne", "edge_se", "edge_we", "tip_e", "tip_n", "tip_s", "island"]
	var family_hash := hash(family_key)
	for by: int in range(blocks):
		for bx: int in range(blocks):
			var hit := false
			if open_n and by < _fringe_band_depth(bx, 0.4, family_hash):
				hit = true
			if not hit and open_s and by >= blocks - _fringe_band_depth(bx, 2.3, family_hash + 7):
				hit = true
			if not hit and open_w and bx < _fringe_band_depth(by, 4.1, family_hash + 13):
				hit = true
			if not hit and open_e and bx >= blocks - _fringe_band_depth(by, 5.6, family_hash + 29):
				hit = true
			if not hit and suffix.begins_with("in_"):
				# Diagonal bite: a wobbled corner cut, mirrored per quadrant.
				var dx := bx if suffix.ends_with("nw") or suffix.ends_with("sw") else blocks - 1 - bx
				var dy := by if suffix.ends_with("nw") or suffix.ends_with("ne") else blocks - 1 - by
				hit = dx + dy < 5 + absi(family_hash + (dx - dy) * 31) % 3
			covered[by * blocks + bx] = hit
	for ty: int in range(tile_size.y):
		for tx: int in range(tile_size.x):
			var bx := tx / 2
			var by := ty / 2
			var out: Color
			if covered[by * blocks + bx]:
				out = image.get_pixel(over.x * tile_size.x + tx, over.y * tile_size.y + ty)
				if rim and _fringe_block_on_boundary(covered, bx, by, blocks):
					out = Color(out.r * 0.72, out.g * 0.72, out.b * 0.8, out.a)
			else:
				out = image.get_pixel(under.x * tile_size.x + tx, under.y * tile_size.y + ty)
			image.set_pixel(target.x * tile_size.x + tx, target.y * tile_size.y + ty, out)

## Scalloped band depth (in 2px blocks) at position t along a side: a base
## depth plus two sine harmonics (periodic over the tile, so runs of the
## same edge piece stay continuous) plus deterministic per-block jitter.
func _fringe_band_depth(t: int, phase: float, salt: int) -> int:
	var wave := 4.0 + 1.6 * sin(TAU * float(t) / 16.0 + phase) + 1.0 * sin(TAU * 2.0 * float(t) / 16.0 + phase * 1.7)
	var jitter := absi(salt * 92821 + t * 68917) % 3 - 1
	return clampi(roundi(wave) + jitter, 2, 7)

## Whether a covered block touches the uncovered side of the mask (the
## boundary rim). Blocks past the tile edge count as covered - the over
## terrain continues in the neighboring cell, so the rim never outlines the
## tile border itself.
func _fringe_block_on_boundary(covered: Array[bool], bx: int, by: int, blocks: int) -> bool:
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var nx := bx + offset.x
		var ny := by + offset.y
		if nx < 0 or ny < 0 or nx >= blocks or ny >= blocks:
			continue
		if not covered[ny * blocks + nx]:
			return true
	return false

## Paints a convincing 32px snow ground tile into one atlas cell: a
## near-white base with faint cool-blue speckle grain, soft blue shadow
## dapples (drift depressions), and a few bright sparkles, so it reads as
## snow rather than a flat white square. Deterministic per variant.
func _paint_snow_tile(image: Image, cell_coords: Vector2i, variant: int) -> void:
	var origin := cell_coords * tile_size
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("town_snow_ground|%d" % variant)
	var width := tile_size.x
	var height := tile_size.y
	# Base fill: bright snow with a barely-there cool tint and per-pixel grain.
	for ty: int in range(height):
		for tx: int in range(width):
			var grain := rng.randf() * 0.05
			var lum := clampf(0.93 - grain, 0.0, 1.0)
			var col := Color(lum, minf(1.0, lum + 0.01), minf(1.0, lum + 0.04), 1.0)
			image.set_pixel(origin.x + tx, origin.y + ty, col)
	# Cool-blue shadow dapples: small soft depressions in the drift.
	var dapple_count := 5 + variant * 2
	for _dapple: int in range(dapple_count):
		var cx := rng.randi_range(2, width - 3)
		var cy := rng.randi_range(2, height - 3)
		var radius := rng.randi_range(2, 4)
		for oy: int in range(-radius, radius + 1):
			for ox: int in range(-radius, radius + 1):
				var px := cx + ox
				var py := cy + oy
				if px < 0 or py < 0 or px >= width or py >= height:
					continue
				var dist := sqrt(float(ox * ox + oy * oy))
				if dist > float(radius):
					continue
				var falloff := 1.0 - dist / float(radius)
				var shade := 0.12 * falloff
				var existing := image.get_pixel(origin.x + px, origin.y + py)
				var shaded := Color(
					clampf(existing.r - shade, 0.0, 1.0),
					clampf(existing.g - shade * 0.85, 0.0, 1.0),
					clampf(existing.b - shade * 0.5, 0.0, 1.0),
					1.0)
				image.set_pixel(origin.x + px, origin.y + py, shaded)
	# A sprinkle of bright sparkle highlights catching the light on top.
	var sparkle_count := 10 + variant * 4
	for _sparkle: int in range(sparkle_count):
		var sx := rng.randi_range(0, width - 1)
		var sy := rng.randi_range(0, height - 1)
		image.set_pixel(origin.x + sx, origin.y + sy, Color(1.0, 1.0, 1.0, 1.0))

## Deterministic per-pixel wood/stone grain for the painted cellar tiles,
## the same hash TownTileService uses for ground variety.
func _cellar_grain(x: int, y: int) -> int:
	var value := x * 73856093 ^ y * 19349663
	if value < 0:
		value = -value
	return value % 5 - 2

## Paints the two stairway tiles into appended atlas row 45 (the sheet ships
## no stair or hatch art). "stairway_down" is a wooden cellar hatch seen from
## above: a plank frame around a dark shaft with four treads stepping down
## into blackness. "stairway_up" is a stone flight rising to a warm lit
## opening at the tile's top. Both are designed to read at 32px: high tread
## contrast, one strong direction cue each (darkening descent vs. light at
## the top of the climb).
func _paint_stair_tiles(image: Image) -> void:
	var down_coords := TILE_ATLAS.get("stairway_down", Vector2i(-1, -1)) as Vector2i
	var up_coords := TILE_ATLAS.get("stairway_up", Vector2i(-1, -1)) as Vector2i
	if down_coords.x >= 0:
		_paint_hatch_down_tile(image, down_coords * tile_size)
	if up_coords.x >= 0:
		_paint_steps_up_tile(image, up_coords * tile_size)

func _paint_hatch_down_tile(image: Image, origin: Vector2i) -> void:
	var frame := Color8(126, 104, 72)
	var frame_light := Color8(150, 126, 88)
	var frame_dark := Color8(96, 78, 52)
	# Plank frame ring with wood grain across the whole tile first.
	for ty: int in range(tile_size.y):
		for tx: int in range(tile_size.x):
			var grain := float(_cellar_grain(tx, ty)) * 0.014
			image.set_pixel(origin.x + tx, origin.y + ty, Color(frame.r + grain, frame.g + grain, frame.b + grain, 1.0))
	# The open shaft: near-black so the hole reads as a hole.
	var open_lo := 4
	var open_hi := tile_size.x - 5
	for ty: int in range(open_lo, open_hi + 1):
		for tx: int in range(open_lo, open_hi + 1):
			image.set_pixel(origin.x + tx, origin.y + ty, Color8(20, 14, 10))
	# Four treads descending from the shaft's top edge, each inset 2px more
	# and darker than the last, with a lit front edge — the narrowing,
	# darkening run is the "down" cue.
	var tread_colors: Array[Color] = [
		Color8(168, 138, 92), Color8(128, 102, 66), Color8(92, 72, 46), Color8(60, 46, 30)
	]
	for tread_index: int in range(tread_colors.size()):
		var tread := tread_colors[tread_index]
		var inset := tread_index * 2
		var band_top := open_lo + tread_index * 5
		for ty: int in range(band_top, band_top + 4):
			for tx: int in range(open_lo + inset, open_hi - inset + 1):
				var grain := float(_cellar_grain(tx, ty)) * 0.010
				var tone := Color(tread.r + grain, tread.g + grain, tread.b + grain, 1.0)
				if ty == band_top:
					tone = Color(minf(tread.r + 0.16, 1.0), minf(tread.g + 0.13, 1.0), minf(tread.b + 0.09, 1.0), 1.0)
				image.set_pixel(origin.x + tx, origin.y + ty, tone)
	# Frame bevel (lit top-left, shaded bottom-right) plus a shadow rim under
	# the frame's inner lip so the opening pops off the floor tile below it.
	for tx: int in range(tile_size.x):
		image.set_pixel(origin.x + tx, origin.y, frame_light)
		image.set_pixel(origin.x + tx, origin.y + tile_size.y - 1, frame_dark)
	for ty: int in range(tile_size.y):
		image.set_pixel(origin.x, origin.y + ty, frame_light)
		image.set_pixel(origin.x + tile_size.x - 1, origin.y + ty, frame_dark)
	for tx: int in range(open_lo - 1, open_hi + 2):
		image.set_pixel(origin.x + tx, origin.y + open_lo - 1, Color8(54, 42, 30))
		image.set_pixel(origin.x + tx, origin.y + open_hi + 1, Color8(140, 116, 80))
	for ty: int in range(open_lo - 1, open_hi + 2):
		image.set_pixel(origin.x + open_lo - 1, origin.y + ty, Color8(54, 42, 30))
		image.set_pixel(origin.x + open_hi + 1, origin.y + ty, Color8(140, 116, 80))

func _paint_steps_up_tile(image: Image, origin: Vector2i) -> void:
	# Dark stonework surround: the stairwell's side walls.
	for ty: int in range(tile_size.y):
		for tx: int in range(tile_size.x):
			var grain := float(_cellar_grain(tx + 7, ty + 3)) * 0.012
			image.set_pixel(origin.x + tx, origin.y + ty, Color(0.165 + grain, 0.15 + grain, 0.14 + grain, 1.0))
	# Six stone treads climbing toward the top of the tile, brightest at the
	# top — the rising gradient plus the lit opening are the "up" cue.
	var flight_lo := 6
	var flight_hi := tile_size.x - 7
	var tread_count := 6
	for tread_index: int in range(tread_count):
		var band_top := 2 + tread_index * 5
		var depth := float(tread_index) / float(tread_count - 1)
		var lum := 0.78 - depth * 0.45
		var tread := Color(lum, lum * 0.92, lum * 0.78, 1.0)
		for ty: int in range(band_top, mini(band_top + 5, tile_size.y - 1)):
			for tx: int in range(flight_lo, flight_hi + 1):
				var grain := float(_cellar_grain(tx, ty)) * 0.012
				var tone := Color(tread.r + grain, tread.g + grain, tread.b + grain, 1.0)
				if ty == band_top:
					tone = Color(minf(tread.r + 0.14, 1.0), minf(tread.g + 0.13, 1.0), minf(tread.b + 0.10, 1.0), 1.0)
				elif ty == band_top + 4:
					tone = Color(maxf(tread.r - 0.17, 0.0), maxf(tread.g - 0.16, 0.0), maxf(tread.b - 0.14, 0.0), 1.0)
				image.set_pixel(origin.x + tx, origin.y + ty, tone)
	# Warm daylight spilling in from the surface at the top of the flight.
	for ty: int in range(2):
		for tx: int in range(flight_lo, flight_hi + 1):
			image.set_pixel(origin.x + tx, origin.y + ty, Color8(255, 232, 170))
	# Hard shadow lines where the flight meets the side walls.
	for ty: int in range(tile_size.y):
		image.set_pixel(origin.x + flight_lo - 1, origin.y + ty, Color8(22, 18, 14))
		image.set_pixel(origin.x + flight_hi + 1, origin.y + ty, Color8(22, 18, 14))

## The solid undug earth that surrounds a cellar's rooms: dark packed soil
## with faint stone flecks, kept low-contrast so the dug rooms read as the
## bright figure against it (the town-side equivalent of the dwarfhold's
## "stone" fill).
func _paint_cellar_rock_tile(image: Image) -> void:
	var coords := TILE_ATLAS.get("cellar_rock", Vector2i(-1, -1)) as Vector2i
	if coords.x < 0:
		return
	var origin := coords * tile_size
	for ty: int in range(tile_size.y):
		for tx: int in range(tile_size.x):
			var grain := float(_cellar_grain(tx + 13, ty + 29)) * 0.010
			var tone := Color(0.14 + grain, 0.115 + grain, 0.095 + grain, 1.0)
			# Sparse embedded-stone flecks, hash-placed so tiling stays quiet.
			var fleck := (tx * 73856093 ^ ty * 19349663) & 0x7fffffff
			if fleck % 53 == 0:
				tone = Color(0.24, 0.21, 0.19, 1.0)
			elif fleck % 67 == 1:
				tone = Color(0.075, 0.06, 0.05, 1.0)
			image.set_pixel(origin.x + tx, origin.y + ty, tone)

## Wading shallows: the sheet ships no shallow-water art, so paint a pale
## blue-green glaze with caustic ripple crests and sand grains showing
## through the water - clearly lighter than the deep animated water, so
## "walkable" reads at a glance. All wave terms use whole periods across
## the tile (the vertical phase rides a periodic inner sine), so shallows
## band together seamlessly.
func _paint_water_shallow_tile(image: Image) -> void:
	var coords := TILE_ATLAS.get("water_shallow", Vector2i(-1, -1)) as Vector2i
	if coords.x < 0:
		return
	var origin := coords * tile_size
	for ty: int in range(tile_size.y):
		for tx: int in range(tile_size.x):
			var wave := sin(float(tx) * TAU / float(tile_size.x) * 2.0 + sin(float(ty) * TAU / float(tile_size.y)) * 1.3)
			wave += sin(float(ty) * TAU / float(tile_size.y) * 2.0 + 1.1) * 0.6
			var tone := Color(0.42, 0.62, 0.66, 1.0)
			if wave > 0.9:
				tone = Color(0.56, 0.75, 0.76, 1.0)
			elif wave < -0.95:
				tone = Color(0.36, 0.55, 0.61, 1.0)
			var grain := (tx * 73856093 ^ ty * 19349663) & 0x7fffffff
			if grain % 41 == 0:
				tone = Color(0.63, 0.62, 0.5, 1.0)
			image.set_pixel(origin.x + tx, origin.y + ty, tone)

## Wind-carved snow: the painted snow base engraved with pale-blue drift
## strokes (sastrugi), kept clear of the tile edges so any mix of plain
## and carved snow tiles butts seamlessly.
func _paint_snow_pattern_tiles(image: Image) -> void:
	var snow_coords := TILE_ATLAS.get("snow", Vector2i(-1, -1)) as Vector2i
	if snow_coords.x < 0:
		return
	for variant_index: int in range(2):
		var key := "snow_swirl" if variant_index == 0 else "snow_carved"
		var coords := TILE_ATLAS.get(key, Vector2i(-1, -1)) as Vector2i
		if coords.x < 0:
			continue
		var origin := coords * tile_size
		image.blit_rect(image, Rect2i(snow_coords * tile_size, tile_size), origin)
		var groove := Color(0.63, 0.76, 0.87, 1.0)
		var crest := Color(0.94, 0.97, 1.0, 1.0)
		var stroke_count := 3 + variant_index
		for stroke_index in range(stroke_count):
			var base_y := 5 + stroke_index * (tile_size.y - 10) / stroke_count + variant_index * 2
			var span_start := 3 + ((stroke_index * 7 + variant_index * 5) % 6)
			var span_end := tile_size.x - 3 - ((stroke_index * 5 + variant_index * 3) % 6)
			for tx in range(span_start, span_end):
				var arc := sin(float(tx - span_start) / float(maxi(span_end - span_start, 1)) * PI)
				var wave := sin(float(tx) * 0.55 + float(stroke_index) * 2.1 + float(variant_index) * 1.3) * 1.6
				var ty := base_y + int(round(wave * arc))
				if ty < 2 or ty > tile_size.y - 3:
					continue
				image.set_pixel(origin.x + tx, origin.y + ty, groove)
				image.set_pixel(origin.x + tx, origin.y + ty - 1, crest)

## A snow-capped boulder on a transparent surround: grey stone with a
## white crown and a soft ground shadow. Blocking decor - a rock is a
## rock.
func _paint_snow_rock_tile(image: Image) -> void:
	var coords := TILE_ATLAS.get("snow_rock", Vector2i(-1, -1)) as Vector2i
	if coords.x < 0:
		return
	var origin := coords * tile_size
	var center := Vector2(float(tile_size.x) * 0.5, float(tile_size.y) * 0.62)
	var radius := Vector2(float(tile_size.x) * 0.34, float(tile_size.y) * 0.26)
	for ty in range(tile_size.y):
		for tx in range(tile_size.x):
			var dx := (float(tx) - center.x) / radius.x
			var dy := (float(ty) - center.y) / radius.y
			var d := dx * dx + dy * dy
			if d > 1.0:
				# soft shadow pooling under the south rim
				if d < 1.5 and dy > 0.4:
					image.set_pixel(origin.x + tx, origin.y + ty, Color(0.42, 0.5, 0.6, 0.35))
				continue
			var tone := Color(0.52, 0.55, 0.6, 1.0)
			if dy < -0.15 - dx * dx * 0.35:
				tone = Color(0.95, 0.97, 1.0, 1.0)
			elif d > 0.62:
				tone = Color(0.38, 0.41, 0.47, 1.0)
			elif dx < -0.25 and dy < 0.1:
				tone = Color(0.62, 0.65, 0.7, 1.0)
			var grain := (tx * 73856093 ^ ty * 19349663) & 0x7fffffff
			if grain % 31 == 0 and tone.r < 0.9:
				tone = Color(0.45, 0.48, 0.54, 1.0)
			image.set_pixel(origin.x + tx, origin.y + ty, tone)

## The ice-ruin kit: dark blue-stone floors (whole and cracked), white
## ice-brick walls (whole and worn down to courses over floor), a
## snow-capped column, and a corner web.
func _paint_ruin_tiles(image: Image) -> void:
	var floor_dark := Color(0.2, 0.24, 0.31, 1.0)
	var floor_grout := Color(0.15, 0.18, 0.24, 1.0)
	var floor_light := Color(0.25, 0.3, 0.38, 1.0)
	var brick_white := Color(0.92, 0.95, 0.98, 1.0)
	var brick_shade := Color(0.74, 0.82, 0.9, 1.0)
	var brick_mortar := Color(0.55, 0.66, 0.78, 1.0)
	for key: String in ["ruin_floor", "ruin_floor_cracked"]:
		var coords := TILE_ATLAS.get(key, Vector2i(-1, -1)) as Vector2i
		if coords.x < 0:
			continue
		var origin := coords * tile_size
		for ty in range(tile_size.y):
			for tx in range(tile_size.x):
				var tone := floor_dark
				if (tx % 16 == 0) or (ty % 16 == 0):
					tone = floor_grout
				else:
					var grain := (tx * 73856093 ^ ty * 19349663) & 0x7fffffff
					if grain % 23 == 0:
						tone = floor_light
					elif grain % 29 == 1:
						tone = floor_grout
				image.set_pixel(origin.x + tx, origin.y + ty, tone)
		if key == "ruin_floor_cracked":
			# One jagged diagonal crack with a couple of offshoots.
			var cy := 6.0
			for tx in range(3, tile_size.x - 3):
				cy += sin(float(tx) * 1.7) * 1.4 + 0.55
				var ty := clampi(int(cy), 2, tile_size.y - 3)
				image.set_pixel(origin.x + tx, origin.y + ty, floor_grout)
				if tx % 7 == 0:
					image.set_pixel(origin.x + tx, origin.y + ty + 1, floor_grout)
	# Whole wall: full courses of white brick.
	var brick_coords := TILE_ATLAS.get("ice_brick", Vector2i(-1, -1)) as Vector2i
	if brick_coords.x >= 0:
		var origin := brick_coords * tile_size
		for ty in range(tile_size.y):
			for tx in range(tile_size.x):
				var course := ty / 8
				var offset := (course % 2) * 8
				var tone := brick_white
				if ty % 8 >= 6:
					tone = brick_mortar
				elif (tx + offset) % 16 >= 14:
					tone = brick_mortar
				elif ty % 8 >= 4:
					tone = brick_shade
				image.set_pixel(origin.x + tx, origin.y + ty, tone)
	# Worn wall: ruin floor showing behind, brick courses surviving below a
	# ragged breakline.
	var worn_coords := TILE_ATLAS.get("ice_brick_worn", Vector2i(-1, -1)) as Vector2i
	var floor_coords := TILE_ATLAS.get("ruin_floor", Vector2i(-1, -1)) as Vector2i
	if worn_coords.x >= 0 and floor_coords.x >= 0:
		var origin := worn_coords * tile_size
		image.blit_rect(image, Rect2i(floor_coords * tile_size, tile_size), origin)
		for tx in range(tile_size.x):
			var break_y := 12 + int(round(sin(float(tx) * 0.9) * 3.0)) + ((tx * 7) % 3)
			for ty in range(break_y, tile_size.y):
				var course := ty / 8
				var offset := (course % 2) * 8
				var tone := brick_white
				if ty % 8 >= 6:
					tone = brick_mortar
				elif (tx + offset) % 16 >= 14:
					tone = brick_mortar
				elif ty % 8 >= 4:
					tone = brick_shade
				if ty == break_y:
					tone = brick_shade
				image.set_pixel(origin.x + tx, origin.y + ty, tone)
	# The column: a snow-capped drum on transparent ground.
	var tower_coords := TILE_ATLAS.get("ruin_tower", Vector2i(-1, -1)) as Vector2i
	if tower_coords.x >= 0:
		var origin := tower_coords * tile_size
		var left := tile_size.x / 2 - 6
		var right := tile_size.x / 2 + 6
		for ty in range(2, tile_size.y):
			for tx in range(left, right):
				var tone := brick_white
				if ty < 7:
					tone = Color(0.97, 0.99, 1.0, 1.0)
				elif ty % 6 >= 4:
					tone = brick_mortar
				elif tx >= right - 3:
					tone = brick_shade
				image.set_pixel(origin.x + tx, origin.y + ty, tone)
			if ty >= tile_size.y - 3:
				image.set_pixel(origin.x + left - 1, origin.y + ty, brick_shade)
				image.set_pixel(origin.x + right, origin.y + ty, brick_shade)
	# The web: thin radial strands anchored in the north-west corner.
	var web_coords := TILE_ATLAS.get("web", Vector2i(-1, -1)) as Vector2i
	if web_coords.x >= 0:
		var origin := web_coords * tile_size
		var strand := Color(0.88, 0.9, 0.93, 0.75)
		var faint := Color(0.88, 0.9, 0.93, 0.4)
		for ray in range(5):
			var angle := 0.12 + float(ray) * (PI * 0.5 - 0.24) / 4.0
			for step in range(2, 15):
				var tx := int(round(cos(angle) * float(step)))
				var ty := int(round(sin(angle) * float(step)))
				if tx < tile_size.x and ty < tile_size.y:
					image.set_pixel(origin.x + tx, origin.y + ty, strand)
		for ring in range(2):
			var ring_radius := 6.0 + float(ring) * 5.0
			for arc_step in range(20):
				var angle := float(arc_step) / 19.0 * PI * 0.5
				var tx := int(round(cos(angle) * ring_radius))
				var ty := int(round(sin(angle) * ring_radius))
				if tx < tile_size.x and ty < tile_size.y:
					image.set_pixel(origin.x + tx, origin.y + ty, faint)

## Rippled dune sand: the shipped sand base engraved with darker wind
## ripples (and a streak variant whose pale gusts sweep diagonally),
## marks kept off the tile edges so mixed sand butts seamlessly.
func _paint_sand_pattern_tiles(image: Image) -> void:
	var sand_coords := TILE_ATLAS.get("sand", Vector2i(-1, -1)) as Vector2i
	if sand_coords.x < 0:
		return
	for variant_index: int in range(3):
		var key := ["sand_ripple", "sand_ripple_alt", "sand_streak"][variant_index] as String
		var coords := TILE_ATLAS.get(key, Vector2i(-1, -1)) as Vector2i
		if coords.x < 0:
			continue
		var origin := coords * tile_size
		image.blit_rect(image, Rect2i(sand_coords * tile_size, tile_size), origin)
		if variant_index < 2:
			var groove := Color(0.66, 0.55, 0.36, 1.0)
			var crest := Color(0.9, 0.82, 0.62, 1.0)
			var stroke_count := 3 + variant_index
			for stroke_index in range(stroke_count):
				var base_y := 5 + stroke_index * (tile_size.y - 10) / stroke_count + variant_index * 2
				var span_start := 3 + ((stroke_index * 5 + variant_index * 7) % 6)
				var span_end := tile_size.x - 3 - ((stroke_index * 3 + variant_index * 5) % 6)
				for tx in range(span_start, span_end):
					var arc := sin(float(tx - span_start) / float(maxi(span_end - span_start, 1)) * PI)
					var wave := sin(float(tx) * 0.5 + float(stroke_index) * 1.9 + float(variant_index) * 0.8) * 1.7
					var ty := base_y + int(round(wave * arc))
					if ty < 2 or ty > tile_size.y - 3:
						continue
					image.set_pixel(origin.x + tx, origin.y + ty, groove)
					image.set_pixel(origin.x + tx, origin.y + ty + 1, crest)
		else:
			# Pale wind gusts sweeping up-right.
			var gust := Color(0.97, 0.94, 0.86, 0.6)
			for gust_index in range(2):
				var start := Vector2(5.0 + float(gust_index) * 11.0, float(tile_size.y - 5 - gust_index * 4))
				for step in range(14):
					var px := start + Vector2(float(step) * 1.0, -float(step) * 0.7 + sin(float(step) * 0.9) * 1.2)
					if px.x < 2.0 or px.y < 2.0 or px.x > float(tile_size.x - 3) or px.y > float(tile_size.y - 3):
						continue
					image.set_pixel(origin.x + int(px.x), origin.y + int(px.y), gust)

## The desert's standing life and litter, all on transparent surrounds:
## a saguaro with two arms, a clump of barrel cacti, sun-bleached bones,
## a red mesa boulder, and the 1x2 palm (crown row above the trunk row).
func _paint_desert_flora_tiles(image: Image) -> void:
	var cactus_body := Color(0.28, 0.52, 0.3, 1.0)
	var cactus_dark := Color(0.18, 0.38, 0.22, 1.0)
	var cactus_light := Color(0.42, 0.66, 0.4, 1.0)
	var cactus_coords := TILE_ATLAS.get("cactus", Vector2i(-1, -1)) as Vector2i
	if cactus_coords.x >= 0:
		var origin := cactus_coords * tile_size
		var mid := tile_size.x / 2
		for ty in range(4, tile_size.y - 1):
			for tx in range(mid - 3, mid + 3):
				var tone := cactus_body
				if tx == mid - 3 or tx == mid + 2:
					tone = cactus_dark
				elif tx == mid - 1:
					tone = cactus_light
				image.set_pixel(origin.x + tx, origin.y + ty, tone)
		# Two arms: out then up.
		for tx in range(mid - 9, mid - 3):
			image.set_pixel(origin.x + tx, origin.y + 14, cactus_dark)
			image.set_pixel(origin.x + tx, origin.y + 13, cactus_body)
		for ty in range(8, 14):
			image.set_pixel(origin.x + mid - 9, origin.y + ty, cactus_dark)
			image.set_pixel(origin.x + mid - 8, origin.y + ty, cactus_body)
		for tx in range(mid + 3, mid + 8):
			image.set_pixel(origin.x + tx, origin.y + 18, cactus_dark)
			image.set_pixel(origin.x + tx, origin.y + 17, cactus_body)
		for ty in range(12, 18):
			image.set_pixel(origin.x + mid + 6, origin.y + ty, cactus_body)
			image.set_pixel(origin.x + mid + 7, origin.y + ty, cactus_dark)
	var clump_coords := TILE_ATLAS.get("cactus_small", Vector2i(-1, -1)) as Vector2i
	if clump_coords.x >= 0:
		var origin := clump_coords * tile_size
		for blob_index in range(3):
			var blob_center := [Vector2(9.0, 22.0), Vector2(19.0, 18.0), Vector2(24.0, 25.0)][blob_index] as Vector2
			var blob_radius := [6.0, 7.0, 5.0][blob_index] as float
			for ty in range(tile_size.y):
				for tx in range(tile_size.x):
					var delta := Vector2(float(tx), float(ty)) - blob_center
					var d := delta.length() / blob_radius
					if d > 1.0:
						continue
					var tone := cactus_body
					if d > 0.78:
						tone = cactus_dark
					elif delta.x < -1.0 and delta.y < 0.0:
						tone = cactus_light
					image.set_pixel(origin.x + tx, origin.y + ty, tone)
	var bones_coords := TILE_ATLAS.get("desert_bones", Vector2i(-1, -1)) as Vector2i
	if bones_coords.x >= 0:
		var origin := bones_coords * tile_size
		var bone := Color(0.93, 0.9, 0.8, 1.0)
		var bone_shade := Color(0.76, 0.72, 0.6, 1.0)
		# A longhorn skull: dome, snout, two out-swept horns.
		for ty in range(12, 20):
			for tx in range(12, 21):
				var tone := bone if ty < 17 else bone_shade
				image.set_pixel(origin.x + tx, origin.y + ty, tone)
		for tx in range(14, 19):
			image.set_pixel(origin.x + tx, origin.y + 20, bone_shade)
		image.set_pixel(origin.x + 14, origin.y + 15, Color(0.2, 0.16, 0.12, 1.0))
		image.set_pixel(origin.x + 18, origin.y + 15, Color(0.2, 0.16, 0.12, 1.0))
		for horn_step in range(6):
			image.set_pixel(origin.x + 11 - horn_step, origin.y + 13 - horn_step / 2, bone)
			image.set_pixel(origin.x + 21 + horn_step, origin.y + 13 - horn_step / 2, bone)
	var rock_coords := TILE_ATLAS.get("desert_rock", Vector2i(-1, -1)) as Vector2i
	if rock_coords.x >= 0:
		var origin := rock_coords * tile_size
		var center := Vector2(float(tile_size.x) * 0.5, float(tile_size.y) * 0.6)
		var radius := Vector2(float(tile_size.x) * 0.33, float(tile_size.y) * 0.28)
		for ty in range(tile_size.y):
			for tx in range(tile_size.x):
				var dx := (float(tx) - center.x) / radius.x
				var dy := (float(ty) - center.y) / radius.y
				var d := dx * dx + dy * dy
				if d > 1.0:
					if d < 1.5 and dy > 0.4:
						image.set_pixel(origin.x + tx, origin.y + ty, Color(0.45, 0.34, 0.24, 0.35))
					continue
				var tone := Color(0.62, 0.4, 0.3, 1.0)
				if dy < -0.2 - dx * dx * 0.3:
					tone = Color(0.76, 0.53, 0.4, 1.0)
				elif d > 0.62:
					tone = Color(0.46, 0.29, 0.22, 1.0)
				var grain := (tx * 73856093 ^ ty * 19349663) & 0x7fffffff
				if grain % 29 == 0:
					tone = Color(0.52, 0.34, 0.25, 1.0)
				image.set_pixel(origin.x + tx, origin.y + ty, tone)
	# The palm: crown on the mapped row, trunk on the row beneath.
	var palm_coords := TILE_ATLAS.get("palm", Vector2i(-1, -1)) as Vector2i
	if palm_coords.x >= 0:
		var origin := palm_coords * tile_size
		var trunk := Color(0.5, 0.34, 0.2, 1.0)
		var trunk_dark := Color(0.38, 0.25, 0.15, 1.0)
		var frond := Color(0.24, 0.5, 0.28, 1.0)
		var frond_dark := Color(0.15, 0.36, 0.2, 1.0)
		var mid := tile_size.x / 2
		# Trunk (lower tile): gently bowed with ring shadows.
		for ty in range(0, tile_size.y - 2):
			var bow := int(round(sin(float(ty) * 0.1) * 2.0))
			var tx0 := mid - 2 + bow
			for tx in range(tx0, tx0 + 4):
				var tone := trunk if tx > tx0 else trunk_dark
				if ty % 5 == 4:
					tone = trunk_dark
				image.set_pixel(origin.x + tx, origin.y + tile_size.y + ty, tone)
		# Crown (upper tile): fronds fanning from the crown point.
		var crown := Vector2(float(mid), float(tile_size.y - 4))
		for frond_index in range(7):
			var angle := PI + float(frond_index) * PI / 6.0
			for step in range(13):
				var droop := float(step) * float(step) * 0.045
				var px := crown + Vector2(cos(angle) * float(step) * 1.15, sin(angle) * float(step) * 0.55 + droop)
				if px.x < 1.0 or px.y < 1.0 or px.x > float(tile_size.x - 2) or px.y > float(tile_size.y - 1):
					continue
				image.set_pixel(origin.x + int(px.x), origin.y + int(px.y), frond)
				image.set_pixel(origin.x + int(px.x), origin.y + int(px.y) + 1, frond_dark)

## The sandstone recolor of the ruin kit for desert forts.
func _paint_sandstone_ruin_tiles(image: Image) -> void:
	var floor_dark := Color(0.42, 0.33, 0.23, 1.0)
	var floor_grout := Color(0.33, 0.25, 0.17, 1.0)
	var floor_light := Color(0.5, 0.4, 0.28, 1.0)
	var brick_face := Color(0.82, 0.68, 0.46, 1.0)
	var brick_shade := Color(0.68, 0.55, 0.37, 1.0)
	var brick_mortar := Color(0.52, 0.41, 0.28, 1.0)
	for key: String in ["ruin_floor_sand", "ruin_floor_sand_cracked"]:
		var coords := TILE_ATLAS.get(key, Vector2i(-1, -1)) as Vector2i
		if coords.x < 0:
			continue
		var origin := coords * tile_size
		for ty in range(tile_size.y):
			for tx in range(tile_size.x):
				var tone := floor_dark
				if (tx % 16 == 0) or (ty % 16 == 0):
					tone = floor_grout
				else:
					var grain := (tx * 73856093 ^ ty * 19349663) & 0x7fffffff
					if grain % 23 == 0:
						tone = floor_light
					elif grain % 29 == 1:
						tone = floor_grout
				image.set_pixel(origin.x + tx, origin.y + ty, tone)
		if key == "ruin_floor_sand_cracked":
			var crack_y := 6.0
			for tx in range(3, tile_size.x - 3):
				crack_y += sin(float(tx) * 1.7) * 1.4 + 0.55
				var ty := clampi(int(crack_y), 2, tile_size.y - 3)
				image.set_pixel(origin.x + tx, origin.y + ty, floor_grout)
	var brick_coords := TILE_ATLAS.get("sandstone_brick", Vector2i(-1, -1)) as Vector2i
	if brick_coords.x >= 0:
		var origin := brick_coords * tile_size
		for ty in range(tile_size.y):
			for tx in range(tile_size.x):
				var course := ty / 8
				var offset := (course % 2) * 8
				var tone := brick_face
				if ty % 8 >= 6:
					tone = brick_mortar
				elif (tx + offset) % 16 >= 14:
					tone = brick_mortar
				elif ty % 8 >= 4:
					tone = brick_shade
				image.set_pixel(origin.x + tx, origin.y + ty, tone)
	var worn_coords := TILE_ATLAS.get("sandstone_brick_worn", Vector2i(-1, -1)) as Vector2i
	var floor_coords := TILE_ATLAS.get("ruin_floor_sand", Vector2i(-1, -1)) as Vector2i
	if worn_coords.x >= 0 and floor_coords.x >= 0:
		var origin := worn_coords * tile_size
		image.blit_rect(image, Rect2i(floor_coords * tile_size, tile_size), origin)
		for tx in range(tile_size.x):
			var break_y := 12 + int(round(sin(float(tx) * 0.9) * 3.0)) + ((tx * 7) % 3)
			for ty in range(break_y, tile_size.y):
				var course := ty / 8
				var offset := (course % 2) * 8
				var tone := brick_face
				if ty % 8 >= 6:
					tone = brick_mortar
				elif (tx + offset) % 16 >= 14:
					tone = brick_mortar
				elif ty % 8 >= 4:
					tone = brick_shade
				if ty == break_y:
					tone = brick_shade
				image.set_pixel(origin.x + tx, origin.y + ty, tone)
	var tower_coords := TILE_ATLAS.get("ruin_tower_sand", Vector2i(-1, -1)) as Vector2i
	if tower_coords.x >= 0:
		var origin := tower_coords * tile_size
		var left := tile_size.x / 2 - 6
		var right := tile_size.x / 2 + 6
		for ty in range(2, tile_size.y):
			for tx in range(left, right):
				var tone := brick_face
				if ty < 5:
					tone = Color(0.88, 0.76, 0.55, 1.0)
				elif ty % 6 >= 4:
					tone = brick_mortar
				elif tx >= right - 3:
					tone = brick_shade
				image.set_pixel(origin.x + tx, origin.y + ty, tone)

## The massif's mountain stone: cold grey crag with strong faceting so a
## hold's mountain reads as ROCK on any ground - the first massif reused
## sandy scree tiles and disappeared into dirt-toned biomes. Three
## shades: the body, a darker foot rim, and a light-catching top.
func _paint_massif_rock_tiles(image: Image) -> void:
	var shades := {
		"massif_rock": [Color(0.47, 0.48, 0.52, 1.0), Color(0.36, 0.37, 0.41, 1.0), Color(0.58, 0.59, 0.63, 1.0)],
		"massif_rock_dark": [Color(0.33, 0.34, 0.38, 1.0), Color(0.24, 0.25, 0.29, 1.0), Color(0.42, 0.43, 0.47, 1.0)],
		"massif_rock_top": [Color(0.58, 0.6, 0.65, 1.0), Color(0.46, 0.48, 0.53, 1.0), Color(0.72, 0.74, 0.79, 1.0)]
	}
	for key: String in shades.keys():
		var coords := TILE_ATLAS.get(key, Vector2i(-1, -1)) as Vector2i
		if coords.x < 0:
			continue
		var palette := shades[key] as Array
		var body := palette[0] as Color
		var crack := palette[1] as Color
		var facet := palette[2] as Color
		var origin := coords * tile_size
		for ty in range(tile_size.y):
			for tx in range(tile_size.x):
				var tone := body
				var grain := (tx * 73856093 ^ ty * 19349663) & 0x7fffffff
				# Angular facet plates split by crack seams.
				var plate := ((tx * 5 + ty * 3) / 16 + (tx * 2 - ty) / 13) % 3
				if plate == 1:
					tone = facet if grain % 7 < 3 else body
				elif plate == 2 and grain % 5 < 2:
					tone = crack
				if grain % 43 == 0:
					tone = crack
				elif grain % 53 == 1:
					tone = facet
				image.set_pixel(origin.x + tx, origin.y + ty, tone)

## The churchyard-and-park kit, all on transparent surrounds: rounded and
## cross headstones, a lidded 1x2 stone coffin, a moss-eaten statue, the
## four quarters of a two-tier stone fountain with pooling water, and a
## wrought-iron street lamp whose lantern glows above its post.
## The barred mouth of a closed hold: a dressed-stone slab filling the
## whole passage, crossed by two riveted iron bands. It reads as a gate
## someone shut on purpose, not a wall that happens to be there.
func _paint_sealed_gate_tile(image: Image) -> void:
	var origin := (TILE_ATLAS.get("sealed_gate", Vector2i(10, 54)) as Vector2i) * 32
	var slab := Color(0.30, 0.29, 0.32, 1.0)
	var slab_light := Color(0.38, 0.37, 0.40, 1.0)
	var seam := Color(0.22, 0.21, 0.24, 1.0)
	var iron := Color(0.16, 0.16, 0.19, 1.0)
	var rivet := Color(0.52, 0.51, 0.56, 1.0)
	for y in range(32):
		for x in range(32):
			var pick := slab
			# Dressed-block courses with staggered vertical seams.
			if y % 8 == 0 or (x + (8 if (y / 8) % 2 == 0 else 0)) % 16 == 0:
				pick = seam
			elif (x * 13 + y * 7) % 11 == 0:
				pick = slab_light
			image.set_pixel(origin.x + x, origin.y + y, pick)
	# Two iron bands with rivets, and a heavy jamb down both edges.
	for band_y: int in [7, 21]:
		for y in range(band_y, band_y + 4):
			for x in range(32):
				image.set_pixel(origin.x + x, origin.y + y, iron)
		for rivet_x: int in [3, 11, 19, 27]:
			image.set_pixel(origin.x + rivet_x, origin.y + band_y + 1, rivet)
			image.set_pixel(origin.x + rivet_x + 1, origin.y + band_y + 1, rivet)
	for y in range(32):
		image.set_pixel(origin.x, origin.y + y, iron)
		image.set_pixel(origin.x + 1, origin.y + y, iron)
		image.set_pixel(origin.x + 30, origin.y + y, iron)
		image.set_pixel(origin.x + 31, origin.y + y, iron)

func _paint_graveyard_tiles(image: Image) -> void:
	var stone := Color(0.62, 0.63, 0.66, 1.0)
	var stone_dark := Color(0.45, 0.46, 0.5, 1.0)
	var stone_light := Color(0.76, 0.77, 0.8, 1.0)
	var moss := Color(0.4, 0.55, 0.34, 1.0)
	var water := Color(0.4, 0.62, 0.82, 1.0)
	var water_light := Color(0.62, 0.8, 0.94, 1.0)
	var iron := Color(0.18, 0.18, 0.21, 1.0)
	var lamp_glow := Color(1.0, 0.85, 0.45, 1.0)
	# Headstone: rounded slab with an inscription line and grass shadow.
	var grave_coords := TILE_ATLAS.get("gravestone", Vector2i(-1, -1)) as Vector2i
	if grave_coords.x >= 0:
		var origin := grave_coords * tile_size
		for ty in range(8, 28):
			for tx in range(10, 22):
				var tone := stone
				if ty < 12 and (tx < 12 or tx > 19):
					continue
				if tx >= 20 or ty >= 26:
					tone = stone_dark
				elif tx <= 11 and ty < 20:
					tone = stone_light
				image.set_pixel(origin.x + tx, origin.y + ty, tone)
		for tx in range(13, 19):
			image.set_pixel(origin.x + tx, origin.y + 16, stone_dark)
			if tx < 17:
				image.set_pixel(origin.x + tx, origin.y + 19, stone_dark)
		image.set_pixel(origin.x + 11, origin.y + 26, moss)
		image.set_pixel(origin.x + 12, origin.y + 27, moss)
	# Cross marker.
	var cross_coords := TILE_ATLAS.get("gravestone_cross", Vector2i(-1, -1)) as Vector2i
	if cross_coords.x >= 0:
		var origin := cross_coords * tile_size
		for ty in range(6, 28):
			for tx in range(14, 18):
				image.set_pixel(origin.x + tx, origin.y + ty, stone if tx < 16 else stone_dark)
		for tx in range(9, 23):
			for ty in range(11, 15):
				image.set_pixel(origin.x + tx, origin.y + ty, stone if ty < 13 else stone_dark)
		image.set_pixel(origin.x + 15, origin.y + 27, moss)
	# The coffin: a lidded sarcophagus lying head-north (art spans two
	# rows; the atlas anchor is the FOOT row, head drawn above).
	var coffin_coords := TILE_ATLAS.get("stone_coffin", Vector2i(-1, -1)) as Vector2i
	if coffin_coords.x >= 0:
		var origin := coffin_coords * tile_size
		for ty in range(4, 62):
			var half_width := 9 if ty < 14 else (11 if ty < 40 else 9)
			for tx in range(16 - half_width, 16 + half_width):
				var tone := stone
				if tx >= 16 + half_width - 3 or ty >= 58:
					tone = stone_dark
				elif tx <= 16 - half_width + 2:
					tone = stone_light
				image.set_pixel(origin.x + tx, origin.y + ty, tone)
		# Lid seam and a moss bloom on the shoulder.
		for ty in range(6, 60):
			if ty % 2 == 0:
				image.set_pixel(origin.x + 16, origin.y + ty, stone_dark)
		for moss_spot: Vector2i in [Vector2i(9, 18), Vector2i(10, 19), Vector2i(22, 44), Vector2i(21, 45)]:
			image.set_pixel(origin.x + moss_spot.x, origin.y + moss_spot.y, moss)
	# The mossy statue: a robed figure gone green at the edges.
	var statue_coords := TILE_ATLAS.get("statue_mossy", Vector2i(-1, -1)) as Vector2i
	if statue_coords.x >= 0:
		var origin := statue_coords * tile_size
		for ty in range(22, 30):
			for tx in range(8, 24):
				image.set_pixel(origin.x + tx, origin.y + ty, stone_dark if ty > 27 else stone)
		for ty in range(8, 22):
			var half_width := 3 if ty < 12 else 5
			for tx in range(16 - half_width, 16 + half_width):
				image.set_pixel(origin.x + tx, origin.y + ty, stone if tx < 18 else stone_dark)
		for tx in range(14, 18):
			image.set_pixel(origin.x + tx, origin.y + 5, stone_light)
			image.set_pixel(origin.x + tx, origin.y + 6, stone)
		image.set_pixel(origin.x + 13, origin.y + 6, stone)
		image.set_pixel(origin.x + 18, origin.y + 6, stone)
		for moss_spot: Vector2i in [Vector2i(12, 15), Vector2i(11, 16), Vector2i(20, 12), Vector2i(9, 24), Vector2i(22, 25), Vector2i(10, 23)]:
			image.set_pixel(origin.x + moss_spot.x, origin.y + moss_spot.y, moss)
	# The fountain quarters: assembled 2x2, a raised stone rim around a
	# pool with a lit inner basin; NW carries the spout tier.
	for quarter: String in ["fountain_nw", "fountain_ne", "fountain_sw", "fountain_se"]:
		var coords := TILE_ATLAS.get(quarter, Vector2i(-1, -1)) as Vector2i
		if coords.x < 0:
			continue
		var origin := coords * tile_size
		var flip_x := quarter == "fountain_ne" or quarter == "fountain_se"
		var flip_y := quarter == "fountain_sw" or quarter == "fountain_se"
		for ty in range(tile_size.y):
			for tx in range(tile_size.x):
				# Work in the NW quarter's frame; mirror for the others.
				var ux := (tile_size.x - 1 - tx) if flip_x else tx
				var uy := (tile_size.y - 1 - ty) if flip_y else ty
				var fx := float(ux) / 32.0
				var fy := float(uy) / 32.0
				var ring := sqrt((1.0 - fx) * (1.0 - fx) + (1.0 - fy) * (1.0 - fy))
				var tone := Color(0, 0, 0, 0)
				if ring < 0.55:
					tone = water_light if (ux + uy) % 9 < 2 else water
				elif ring < 0.75:
					tone = stone_light if ring < 0.62 else stone
				elif ring < 0.95:
					tone = stone_dark if (ux * 7 + uy * 3) % 11 == 0 else stone
				if tone.a > 0.0:
					image.set_pixel(origin.x + tx, origin.y + ty, tone)
		if quarter == "fountain_nw":
			# The upper basin and spout live on the NW quarter, near the join.
			for ty in range(20, 32):
				for tx in range(20, 32):
					var d := Vector2(float(tx) - 32.0, float(ty) - 32.0).length()
					if d < 10.0:
						image.set_pixel(origin.x + tx, origin.y + ty, stone_light if d > 7.0 else water_light)
	# The street lamp: iron post on the anchor row, glowing lantern above.
	var lamp_coords := TILE_ATLAS.get("street_lamp", Vector2i(-1, -1)) as Vector2i
	if lamp_coords.x >= 0:
		var origin := lamp_coords * tile_size
		for ty in range(10, 62):
			image.set_pixel(origin.x + 15, origin.y + ty, iron)
			image.set_pixel(origin.x + 16, origin.y + ty, iron)
		for tx in range(12, 20):
			image.set_pixel(origin.x + tx, origin.y + 60, iron)
			image.set_pixel(origin.x + tx, origin.y + 61, iron)
		# The lantern: iron cage around a warm pane.
		for ty in range(2, 12):
			for tx in range(11, 21):
				var edge := tx <= 12 or tx >= 19 or ty <= 3 or ty >= 10
				image.set_pixel(origin.x + tx, origin.y + ty, iron if edge else lamp_glow)
		image.set_pixel(origin.x + 15, origin.y + 1, iron)
		image.set_pixel(origin.x + 16, origin.y + 1, iron)

## --- painted water plants and snow trees --------------------------------------

## The water-plant palette, tuned to sit on the sheet's blue water without
## vanishing: mid pad green with a dark rim and a pale top-left highlight,
## plus reed greens and a ghost-pale ripple ring.
const PLANT_PAD_GREEN := Color(0.30, 0.55, 0.24, 1.0)
const PLANT_PAD_DARK := Color(0.14, 0.33, 0.16, 1.0)
const PLANT_PAD_LIGHT := Color(0.52, 0.74, 0.34, 1.0)
const PLANT_REED_DARK := Color(0.16, 0.40, 0.19, 1.0)
const PLANT_REED_LIGHT := Color(0.40, 0.65, 0.28, 1.0)
const PLANT_RIPPLE := Color(0.78, 0.88, 0.96, 0.5)

## One 2px art block of a painted plant tile (the sheet is a 2x upscale, so
## all synthesized art works on the 16x16 block grid).
func _plant_block(image: Image, origin: Vector2i, bx: int, by: int, color: Color) -> void:
	if bx < 0 or by < 0 or bx > 15 or by > 15:
		return
	for py: int in range(2):
		for px: int in range(2):
			image.set_pixel(origin.x + bx * 2 + px, origin.y + by * 2 + py, color)

## One round lily pad on the block grid: an ellipse with a notch wedge cut
## toward notch_angle, a dark rim on boundary blocks, and a pale highlight
## along the upper-left inner rim. Everything outside stays transparent.
func _paint_lily_pad(image: Image, origin: Vector2i, center: Vector2, radius: Vector2, notch_angle: float) -> void:
	var covered: Dictionary = {}
	for by: int in range(16):
		for bx: int in range(16):
			var dx := (float(bx) - center.x) / radius.x
			var dy := (float(by) - center.y) / radius.y
			if dx * dx + dy * dy > 1.0:
				continue
			# The notch: a wedge from just off-center to the rim.
			var block_angle := atan2(float(by) - center.y, float(bx) - center.x)
			var offset_angle := absf(angle_difference(block_angle, notch_angle))
			if offset_angle < 0.42 and dx * dx + dy * dy > 0.12:
				continue
			covered[Vector2i(bx, by)] = true
	for block_variant: Variant in covered.keys():
		var block := block_variant as Vector2i
		var on_rim := false
		for neighbor: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not covered.has(block + neighbor):
				on_rim = true
				break
		var tone := PLANT_PAD_GREEN
		if on_rim:
			# Upper-left rim catches the light; the rest darkens to a rim line.
			var toward_light := float(block.x) < center.x - 0.5 and float(block.y) < center.y + 0.5
			tone = PLANT_PAD_LIGHT if toward_light else PLANT_PAD_DARK
		elif (block.x * 73856093 ^ block.y * 19349663) % 11 == 0:
			# Sparse dark speckle so big pads aren't one flat green plate.
			tone = PLANT_PAD_DARK.lerp(PLANT_PAD_GREEN, 0.5)
		_plant_block(image, origin, block.x, block.y, tone)

## One reed clump: a handful of slim blades leaning off vertical, alternating
## dark and light greens with lit tips, breaking the surface through a faint
## pale ripple ring at the waterline.
func _paint_reed_clump(image: Image, origin: Vector2i, mirrored: bool, salt: int) -> void:
	var water_line := 12
	# Ripple ring first, so blades draw over its middle.
	for ripple_dx: int in range(-4, 5):
		var lift := 1 if absi(ripple_dx) >= 3 else 0
		if absi(ripple_dx) == 4:
			lift = 2
		_plant_block(image, origin, 7 + ripple_dx, water_line - lift + 1, PLANT_RIPPLE)
	var blade_count := 5
	for blade_index: int in range(blade_count):
		var blade_hash := absi((salt * 31 + blade_index) * 92821)
		var base_x := 3 + blade_index * 2 + blade_hash % 2
		var height := 5 + blade_hash % 6
		var lean := (blade_hash / 7) % 3 - 1
		var tone := PLANT_REED_DARK if blade_index % 2 == 0 else PLANT_REED_LIGHT
		for step: int in range(height):
			var bx := base_x + (lean * step) / maxi(height - 1, 1)
			if mirrored:
				bx = 15 - bx
			var blade_tone := tone
			if step >= height - 2:
				blade_tone = PLANT_REED_LIGHT.lerp(Color(0.62, 0.8, 0.42, 1.0), 0.5)
			_plant_block(image, origin, bx, water_line - step, blade_tone)

## Paints the five water-plant decor tiles into appended atlas row 46:
## a single pad, a clustered pair (plus a sprout of a third), a flowering
## white lily, and two mirrored reed clumps. All transparent-backed decor
## drawn over the animated water bases.
func _paint_water_plant_tiles(image: Image) -> void:
	var keys: Array[String] = ["lily_pad", "lily_pad_pair", "lily_flower", "reeds", "reeds_alt"]
	for plant_key: String in keys:
		var coords := TILE_ATLAS.get(plant_key, Vector2i(-1, -1)) as Vector2i
		if coords.x < 0:
			continue
		var origin := coords * tile_size
		# Clear to full transparency; the decor layer supplies the water.
		for ty: int in range(tile_size.y):
			for tx: int in range(tile_size.x):
				image.set_pixel(origin.x + tx, origin.y + ty, Color(0, 0, 0, 0))
		match plant_key:
			"lily_pad":
				_paint_lily_pad(image, origin, Vector2(7.5, 8.0), Vector2(5.4, 4.4), 0.6)
			"lily_pad_pair":
				_paint_lily_pad(image, origin, Vector2(5.0, 5.5), Vector2(4.2, 3.4), 2.6)
				_paint_lily_pad(image, origin, Vector2(10.5, 11.0), Vector2(3.4, 2.8), -0.7)
				_paint_lily_pad(image, origin, Vector2(12.5, 4.5), Vector2(2.0, 1.6), 1.8)
			"lily_flower":
				_paint_lily_pad(image, origin, Vector2(7.5, 8.5), Vector2(5.0, 4.2), -2.2)
				# The white blossom: two petal layers and a warm center.
				var petal := Color(0.95, 0.96, 0.99, 1.0)
				var petal_shade := Color(0.82, 0.85, 0.93, 1.0)
				for petal_offset: Vector2i in [
						Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2),
						Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
					var layer_tone := petal if petal_offset.y <= 0 else petal_shade
					_plant_block(image, origin, 7 + petal_offset.x, 7 + petal_offset.y, layer_tone)
				for core_offset: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					_plant_block(image, origin, 7 + core_offset.x, 7 + core_offset.y, petal)
				_plant_block(image, origin, 7, 7, Color(0.95, 0.78, 0.30, 1.0))
			"reeds":
				_paint_reed_clump(image, origin, false, 3)
			"reeds_alt":
				_paint_reed_clump(image, origin, true, 11)

## A snow-tree source pixel that belongs to the canopy (dustable): leafy
## green, where green clearly leads red and blue. Trunk browns, the dark
## sprite outline and transparent surround all refuse snow, so caps sit
## INSIDE the tree's outline and the silhouette survives.
func _snow_tree_pixel_is_canopy(color: Color) -> bool:
	if color.a <= 0.5:
		return false
	return color.g8 > color.r8 + 12 and color.g8 > color.b8 + 12

## Copies both full-height tree regions into their appended-row cells and
## dusts them with snow: every canopy block whose upward neighbor is not
## canopy (sky or a dark branch crease) starts a snow run 1-4 blocks deep
## with hash jitter — deep white caps across the crown top, thinner dusting
## along lower branch shoulders — and the bottom block of each run shades
## pale blue so caps read as lying ON the foliage.
func _paint_snowy_tree_tiles(image: Image) -> void:
	for recipe: Array in [["tree", "tree_snowy"], ["tree_dark", "tree_dark_snowy"]]:
		var source := TILE_ATLAS.get(String(recipe[0]), Vector2i(-1, -1)) as Vector2i
		var target := TILE_ATLAS.get(String(recipe[1]), Vector2i(-1, -1)) as Vector2i
		if source.x < 0 or target.x < 0:
			continue
		var multi := TILE_ATLAS_DEFS.TOWN_MULTI_CELL_TILES.get(source, {}) as Dictionary
		var size_cells := multi.get("size", Vector2i.ONE) as Vector2i
		var size_px := Vector2i(size_cells.x * tile_size.x, size_cells.y * tile_size.y)
		var region := image.get_region(Rect2i(source * tile_size, size_px))
		image.blit_rect(region, Rect2i(Vector2i.ZERO, size_px), target * tile_size)
		_dust_snow_on_tree(image, target * tile_size, size_px, hash(String(recipe[1])))

func _dust_snow_on_tree(image: Image, origin: Vector2i, size_px: Vector2i, salt: int) -> void:
	var blocks_x := size_px.x / 2
	var blocks_y := size_px.y / 2
	var snow_top := Color(0.94, 0.96, 1.0, 1.0)
	var snow_shade := Color(0.74, 0.81, 0.94, 1.0)
	# The canopy mask is read before any snow is painted, so a finished cap
	# can never seed a second run cascading down the crown.
	var canopy: Array[bool] = []
	canopy.resize(blocks_x * blocks_y)
	# The sheet's own lit yellow-green (g >= 150) paints every upward-facing
	# lobe surface, so it doubles as the shoulder-dusting mask below.
	var lit: Array[bool] = []
	lit.resize(blocks_x * blocks_y)
	for by: int in range(blocks_y):
		for bx: int in range(blocks_x):
			var mask_pixel := image.get_pixel(origin.x + bx * 2, origin.y + by * 2)
			canopy[by * blocks_x + bx] = _snow_tree_pixel_is_canopy(mask_pixel)
			lit[by * blocks_x + bx] = canopy[by * blocks_x + bx] and mask_pixel.g8 >= 150
	# A cap starts on an upward-facing canopy surface (canopy with no canopy
	# above). Lone one-block starters on the near-vertical crown sides are
	# rejected - they read as white flecks stuck to the outline - by asking
	# for a horizontal starter neighbor, so only genuine tops and branch
	# shoulders (flat runs) catch snow. The bottom rows are the ground fringe
	# around the trunk and stay bare.
	var starter: Array[bool] = []
	starter.resize(blocks_x * blocks_y)
	for by: int in range(blocks_y - 6):
		for bx: int in range(blocks_x):
			starter[by * blocks_x + bx] = canopy[by * blocks_x + bx] \
				and (by == 0 or not canopy[(by - 1) * blocks_x + bx])
	for bx: int in range(blocks_x):
		for by: int in range(blocks_y):
			if not starter[by * blocks_x + bx]:
				continue
			var left_starts := bx > 0 and starter[by * blocks_x + bx - 1]
			var right_starts := bx < blocks_x - 1 and starter[by * blocks_x + bx + 1]
			if not (left_starts or right_starts):
				continue
			# Caps run deeper near the crown (small by), thinner further down.
			var depth := 1 + absi(salt + bx * 68917 + by * 92821) % 3
			if by < blocks_y / 3:
				depth += 2
			var run := 0
			for step: int in range(depth):
				if by + step >= blocks_y or (step > 0 and not canopy[(by + step) * blocks_x + bx]):
					break
				run = step
			for step: int in range(run + 1):
				var tone := snow_shade if step == run and run > 0 else snow_top
				for py: int in range(2):
					for px: int in range(2):
						image.set_pixel(origin.x + bx * 2 + px, origin.y + (by + step) * 2 + py, tone)
	# Dusted branch shoulders: whole horizontal runs of the lit lobe surfaces
	# frost over (snow lies along a branch, it doesn't speckle), more often
	# near the crown, each streak closed by pale-blue shade on its underside.
	for by: int in range(blocks_y - 6):
		var bx := 0
		while bx < blocks_x:
			if not lit[by * blocks_x + bx]:
				bx += 1
				continue
			var run_end := bx
			while run_end + 1 < blocks_x and lit[by * blocks_x + run_end + 1]:
				run_end += 1
			var run_hash := absi(hash(Vector3i(salt, bx + by * 41, run_end)))
			var keep_one_in := 3 if by * 3 > blocks_y else 2
			if run_end - bx >= 1 and run_hash % keep_one_in == 0:
				# Jittered ends keep streaks from tracing the art exactly.
				var trim_left := run_hash / 7 % 2
				var trim_right := run_hash / 13 % 2
				for run_x: int in range(bx + trim_left, run_end + 1 - trim_right):
					for py: int in range(2):
						for px: int in range(2):
							image.set_pixel(origin.x + run_x * 2 + px, origin.y + by * 2 + py, snow_top)
					var under_index := (by + 1) * blocks_x + run_x
					if run_x > bx and run_x < run_end and canopy[under_index] and not lit[under_index]:
						for py: int in range(2):
							for px: int in range(2):
								image.set_pixel(origin.x + run_x * 2 + px, origin.y + (by + 1) * 2 + py, snow_shade)
			bx = run_end + 1

func _is_passable_atlas_tile(atlas_coords: Vector2i) -> bool:
	if _passable_atlas_set.is_empty():
		for tile_key: String in PASSABLE_TILE_KEYS:
			var coords := TILE_ATLAS.get(tile_key, Vector2i(-1, -1)) as Vector2i
			if coords != Vector2i(-1, -1):
				_passable_atlas_set[coords] = true
	return _passable_atlas_set.has(atlas_coords)

## Hold-source tiles carry the HOLD atlas's walkability: dirt, floors,
## doors and stairs walk; stone and walls block.
func _is_hold_passable_atlas_tile(atlas_coords: Vector2i) -> bool:
	if _hold_passable_atlas_set.is_empty():
		for tile_key: String in TILE_ATLAS_DEFS.DWARFHOLD_PASSABLE_TILE_KEYS:
			var coords := TILE_ATLAS_DEFS.DWARFHOLD_TILE_ATLAS.get(tile_key, Vector2i(-1, -1)) as Vector2i
			if coords != Vector2i(-1, -1):
				_hold_passable_atlas_set[coords] = true
	return _hold_passable_atlas_set.has(atlas_coords)

## Source-aware walkability: cells painted from the hold's atlas (source
## 1) answer with hold rules, town cells with town rules.
func _is_passable_layer_cell(layer: TileMapLayer, cell: Vector2i) -> bool:
	if layer.get_cell_source_id(cell) == HOLD_TILE_SOURCE_ID:
		return _is_hold_passable_atlas_tile(layer.get_cell_atlas_coords(cell))
	return _is_passable_atlas_tile(layer.get_cell_atlas_coords(cell))

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
	# Open-sea embark: the ocean itself is the walkable medium (the player is
	# afloat), so sea cells are passable and let the walker roam the water.
	if _wild_water and _is_water_cell(cell):
		return true
	# Mountain crags in the streamed wilds keep their rocky tile but block
	# movement; roads never enter this set, so passes stay open.
	if _surface_blocked_cells.has(cell):
		return false
	# Stamped ambient footprints: tents, props and furniture in the wilds.
	if _surface_landmark_blocked_cells.has(cell):
		return false
	if _farm_blocked_cells.has(cell) or _furnishing_blocked_cells.has(cell):
		return false
	if city_layer.get_cell_source_id(cell) < 0:
		return false
	if not _is_passable_layer_cell(city_layer, cell):
		return false
	if decor_layer.get_cell_source_id(cell) < 0:
		return true
	return _is_passable_layer_cell(decor_layer, cell)

func _apply_cached_town_scene_seed() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	var scene_seed := _hold_state.apply_world_settings(settings, TOWN_SCENE_SEED_KEY, TOWN_SCENE_POPULATION_KEY)
	_town_name = String(settings.get(TOWN_SCENE_NAME_KEY, "")).strip_edges()
	_town_theme = String(settings.get(TOWN_SCENE_THEME_KEY, "")).strip_edges().to_lower()
	_town_is_village = bool(settings.get(TOWN_SCENE_VILLAGE_KEY, false))
	_wild_mode = bool(settings.get(TOWN_SCENE_WILD_KEY, false))
	_wild_water = _wild_mode and bool(settings.get(TOWN_SCENE_WILD_WATER_KEY, false))
	if _wild_mode:
		# Name the header for the wilderness, not "Unnamed Town".
		var wild_title_label := get_node_or_null("Margin/Layout/Controls/Title") as Label
		if wild_title_label != null:
			wild_title_label.text = _town_name if not _town_name.is_empty() else ("The Open Sea" if _wild_water else "The Wilds")
		var wild_desc_label := get_node_or_null("Margin/Layout/Controls/Description") as Label
		if wild_desc_label != null:
			if _wild_water:
				wild_desc_label.text = "Open ocean - no land in sight. You drift afloat; click to row, press F to fish."
			else:
				wild_desc_label.text = "Open wilderness - no settlement here. Click to walk; hover tiles for details."
	elif _town_theme == "desert":
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

	# Wild embark: skip the whole settlement pipeline and raise a single
	# walkable clearing. The surface streamer then fills biome wilds around it.
	if _wild_mode:
		_town_details = {}
		_town_market = {}
		_hold_state.generated_levels.append(_generate_wild_clearing_level())
		_show_level(0)
		return

	var details_rng := RandomNumberGenerator.new()
	details_rng.seed = hash("%s::town_details" % seed_text)
	var display_name := _town_name if not _town_name.is_empty() else "Unnamed Town"
	_town_details = TownDetailsGenerator.generate(display_name, _hold_state.selected_hold_population, details_rng, {"village": _town_is_village})
	_town_market = SettlementEconomyService.settlement_market(_town_details, hash(seed_text))

	var minimum_levels := mini(underground_level_count_range.x, underground_level_count_range.y)
	var maximum_levels := maxi(underground_level_count_range.x, underground_level_count_range.y)
	var level_count := _hold_state.population_scaled_level_count(maximum_levels)
	if level_count <= 0:
		level_count = maxi(1, _rng.randi_range(minimum_levels, maximum_levels))
	for level_index in range(level_count):
		var level_seed := "%s::depth_%d" % [seed_text, level_index]
		_hold_state.generated_levels.append(_generate_single_level(level_seed, level_index, level_count))

	_show_level(0)

## A bare walkable clearing for a wild embark: an odd-sized square of open
## ground (CELL_ROCK renders as grass in the town tileset) centered on the
## origin, with no buildings, halls, plazas, stairs, or civic zones. It is
## non-empty so _setup_surface_world anchors the biome wilds around it, and
## its cells count as walkable in wild mode (see _collect_walkable_cells).
func _generate_wild_clearing_level() -> Dictionary:
	var grid: Dictionary = {}
	var clearing_radius := 5
	for offset_y in range(-clearing_radius, clearing_radius + 1):
		for offset_x in range(-clearing_radius, clearing_radius + 1):
			grid[Vector2i(offset_x, offset_y)] = CELL_ROCK
	return {
		"grid": grid,
		"door_cells": {},
		"zone_counts": {},
		"requested_zone_counts": {},
		"civic_buildings_by_id": {},
		"civic_building_type_map": {},
		"residence_type_map": {},
		"stair_cells": {}
	}

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
	var village_yards: Array[Dictionary] = []
	var well_cell := DwarfHoldStateModel.INVALID_CELL
	var level_door_cells: Dictionary = {}

	## The surface level is a VILLAGE, not a carved cave city: one modest
	## market square, free-standing multi-room lots scattered around it with
	## green verges between them, winding 2-3 tile lanes from every door to
	## the square, fenced kitchen gardens, and a well on the plaza. The
	## blob-carved street pipeline below survives only for the underground
	## cellar levels, where wide dug halls still make sense.
	if level_index == 0:
		var plaza_radius := Vector2i(_rng.randi_range(4, 6), _rng.randi_range(3, 4))
		_dig_plaza_zone(grid, Vector2i.ZERO, plaza_radius, _roll_plaza_shape(), CELL_PLAZA)
		requested_zone_counts["plazas"] = 1
		for _building_index in requested_building_count:
			var civic_type := _pick_civic_building_type()
			var civic_definition := CIVIC_BUILDING_TYPES[civic_type] as Dictionary
			var civic_footprint := _roll_civic_footprint(civic_definition)
			_place_village_lot(grid, civic_footprint, CELL_BUILDING, civic_type, plaza_radius)
		var village_beds_planned := 0
		var village_residences_placed := 0
		for _residence_attempt in requested_bed_count * 2 + 60:
			if village_beds_planned >= requested_bed_count:
				break
			var residence_type := _roll_residence_type()
			# Small remainders shouldn't burn the budget on one huge barracks.
			if requested_bed_count - village_beds_planned < 6 and residence_type != "house":
				residence_type = "house"
			var residence_footprint := _roll_residence_footprint(residence_type)
			if _place_village_lot(grid, residence_footprint, CELL_HOUSE, residence_type, plaza_radius):
				village_beds_planned += _estimate_residence_beds(residence_type, residence_footprint)
				village_residences_placed += 1
		requested_zone_counts["houses"] = village_residences_placed
		## Interiors first (doors define where lanes start), then the lane
		## network, then yards on whichever house flanks stayed green.
		level_door_cells = _plan_town_building_interiors(grid)
		_trace_village_lanes(grid, level_door_cells)
		village_yards = _plan_house_yards(grid, level_door_cells)
		well_cell = _pick_village_well_cell(grid)
		var village_civic_buildings := _compute_civic_buildings_by_id(grid)
		var village_stairs := _pick_level_stair_cells(grid, level_index, level_count, level_door_cells)
		_repair_town_level_connectivity(grid, level_door_cells, village_stairs, level_index)
		return {
			"grid": grid,
			"door_cells": level_door_cells,
			"zone_counts": _count_zone_components(grid),
			"requested_zone_counts": requested_zone_counts,
			"civic_buildings_by_id": village_civic_buildings,
			"civic_building_type_map": _build_civic_building_type_lookup(village_civic_buildings),
			"residence_type_map": _latest_residence_type_map,
			"stair_cells": village_stairs,
			"village_yards": village_yards,
			"well_cell": well_cell
		}

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
		## Cellars are the town's storage: every underground building is a
		## warehouse (crates/sacks/chest decor, storeroom back rooms) instead
		## of a random shopfront that makes no sense below a village.
		var civic_type := "warehouse" if is_additional_layer else _pick_civic_building_type()
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
	## Multi-room interiors replace the old one-door-per-rectangle pass:
	## cellar storerooms get partition walls, internal doors and room roles
	## just like the surface lots (doors face dug halls, never solid earth).
	level_door_cells = _plan_town_building_interiors(grid, level_index == 0)
	var civic_buildings_by_id := _compute_civic_buildings_by_id(grid)
	var civic_building_type_map := _build_civic_building_type_lookup(civic_buildings_by_id)
	var zone_counts := _count_zone_components(grid)
	var stair_cells := _pick_level_stair_cells(grid, level_index, level_count, level_door_cells)
	## The non-negotiable pass: at tile passability (the same rules movement
	## uses), every walkable cell must reach every other.
	_repair_town_level_connectivity(grid, level_door_cells, stair_cells, level_index)
	return {
		"grid": grid,
		"door_cells": level_door_cells,
		"zone_counts": zone_counts,
		"requested_zone_counts": requested_zone_counts,
		"civic_buildings_by_id": civic_buildings_by_id,
		"civic_building_type_map": civic_building_type_map,
		"residence_type_map": _latest_residence_type_map,
		"stair_cells": stair_cells,
		"village_yards": village_yards,
		"well_cell": well_cell
	}

## --- Village architecture ---------------------------------------------------
## Shared multi-room interior planning (see SettlementArchitectureService):
## BSP partitions, spanning-tree internal doors, exterior doors, and the
## town's own room-role deals (taproom + kitchen + bedrooms; showroom +
## storeroom; smithy + forge annex). Demolished nooks return to open grass,
## and grass-facing walls host doors because the lawn itself is walkable.
## Cellar levels pass doors_on_open_ground=false: down there the implicit
## ground is solid earth, so exterior doors must face dug halls or they
## would open straight into rock.
func _plan_town_building_interiors(grid: Dictionary, doors_on_open_ground: bool = true) -> Dictionary:
	return SettlementArchitectureService.plan_building_interiors(grid, {
		"rng": _rng,
		"civic_type_map": _latest_civic_building_type_map,
		"residence_type_map": _latest_residence_type_map,
		"back_roles": TOWN_ROOM_BACK_ROLES,
		"default_back_role": "storeroom",
		"open_plan_types": TOWN_OPEN_PLAN_BUILDING_TYPES,
		"demolish_zone": CELL_ROCK,
		"door_on_open_ground": doors_on_open_ground
	})

## Tile passability at generation time, mirroring TownTileService's render
## rules: open grass, lanes and the square are walkable; building cells
## walk only on floor and doors; partitions open only at doors. Bounded to
## the settled grid so the BFS cannot leak across the infinite implicit
## grass outside town.
func _town_generation_passable(grid: Dictionary, door_cells: Dictionary, bounds: Rect2i, cell: Vector2i, rock_is_open: bool = true) -> bool:
	if not bounds.has_point(cell):
		return false
	var zone := int(grid.get(cell, CELL_ROCK))
	match zone:
		CELL_ROCK:
			## Above ground the implicit green is open terrain; in a cellar
			## the undug earth is solid, so movement (and the repair pass)
			## must route through dug halls — mirroring the render rules,
			## where "cellar_rock" blocks like the dwarfhold's stone.
			return rock_is_open
		CELL_HALL, CELL_PLAZA:
			return true
		CELL_WALL:
			return door_cells.has(cell)
		CELL_HOUSE, CELL_BUILDING:
			var tile := TownTileService.wall_or_floor_tile(grid, cell.x, cell.y, zone, door_cells)
			return tile == "floor" or tile == "door"
		_:
			return false

func _repair_town_level_connectivity(grid: Dictionary, door_cells: Dictionary, stair_cells: Dictionary, level_index: int) -> void:
	var bounds := _find_bounds(grid).grow(1)
	# Cellars route through dug halls only; the surface walks its lawns too.
	var rock_is_open := level_index == 0
	var is_passable := func(cell: Vector2i) -> bool:
		return _town_generation_passable(grid, door_cells, bounds, cell, rock_is_open)
	SettlementArchitectureService.repair_level_connectivity(grid, door_cells, stair_cells, level_index, is_passable, "Town")

## Free-standing village lot: a rectangular plot dropped on open grass
## around the market square, keeping a 2-cell green verge to every other
## zone so lanes, yards and trees fit between the buildings. Early attempts
## hug the square, later ones drift outward, so the village densifies from
## the center like a real settlement.
func _place_village_lot(grid: Dictionary, footprint: Vector2i, structure_tile: int, building_type: String, plaza_radius: Vector2i) -> bool:
	var base_reach := float(maxi(plaza_radius.x, plaza_radius.y) + maxi(footprint.x, footprint.y)) + 4.0
	for attempt in 260:
		var reach := base_reach + float(attempt) * 0.3 + _rng.randf() * 6.0
		var angle := _rng.randf() * TAU
		## Slight landscape bias: villages spread wider than tall so the
		## screen-shaped map reads naturally.
		var center := Vector2i(roundi(cos(angle) * reach * 1.25), roundi(sin(angle) * reach * 0.8))
		if not _can_place_village_lot(grid, center, footprint):
			continue
		_dig_structure_with_room(grid, center, footprint, structure_tile)
		_register_building_type_metadata(center, footprint, structure_tile, building_type)
		return true
	return false

func _can_place_village_lot(grid: Dictionary, center: Vector2i, footprint: Vector2i) -> bool:
	var from_cell := center - footprint - Vector2i(2, 2)
	var to_cell := center + footprint + Vector2i(2, 2)
	for y in range(from_cell.y, to_cell.y + 1):
		for x in range(from_cell.x, to_cell.x + 1):
			if _cell_at(grid, x, y) != CELL_ROCK:
				return false
	return true

## --- Village lanes: winding paths instead of carved boulevards -------------
## Every building entrance gets a 2-3 tile wide winding dirt lane to the
## nearest already-traced road cell; the market square rim seeds the
## network, so streets grow outward as an organic tree. Entrances are wired
## nearest-first, which makes far homesteads branch off their neighbors'
## lanes rather than cutting their own highways to the square.
func _trace_village_lanes(grid: Dictionary, door_cells: Dictionary) -> void:
	var spine: Array[Vector2i] = []
	for key_variant: Variant in grid.keys():
		if int(grid[key_variant]) == CELL_PLAZA:
			spine.append(key_variant as Vector2i)
	if spine.is_empty():
		spine.append(Vector2i.ZERO)
	var entries: Array[Vector2i] = []
	for door_variant: Variant in door_cells.keys():
		var door_cell := door_variant as Vector2i
		var door_zone := int(grid.get(door_cell, CELL_ROCK))
		## Internal partition doors sit on CELL_WALL cells; only ring doors
		## (still zoned as their building) open onto the village green.
		if door_zone != CELL_HOUSE and door_zone != CELL_BUILDING:
			continue
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var outside := door_cell + direction
			if int(grid.get(outside, CELL_ROCK)) == CELL_ROCK and int(grid.get(door_cell - direction, CELL_ROCK)) == door_zone:
				entries.append(outside)
				break
	entries.sort_custom(func(cell_a: Vector2i, cell_b: Vector2i) -> bool:
		var da := cell_a.length_squared()
		var db := cell_b.length_squared()
		if da == db:
			return cell_a < cell_b
		return da < db
	)
	for entry: Vector2i in entries:
		var target := entry
		var best_distance := 2147483647
		for spine_cell: Vector2i in spine:
			var candidate_distance := entry.distance_squared_to(spine_cell)
			if candidate_distance < best_distance:
				best_distance = candidate_distance
				target = spine_cell
		_carve_winding_lane(grid, entry, target, spine)
	_plan_direction_posts(grid)

## Wooden direction posts stand beside a handful of lane junctions (hall
## cells where three or more lane arms meet), on the grass just off the
## lane, so crossroads read as signed crossroads. Deterministic per seed
## and sparse: a hash gate plus a hard cap keeps it to a few per town.
func _plan_direction_posts(grid: Dictionary) -> void:
	_direction_post_cells.clear()
	var junctions: Array[Vector2i] = []
	for key_variant: Variant in grid.keys():
		var cell := key_variant as Vector2i
		if int(grid[cell]) != CELL_HALL:
			continue
		var arms := 0
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor_zone := int(grid.get(cell + direction, CELL_ROCK))
			if neighbor_zone == CELL_HALL or neighbor_zone == CELL_PLAZA:
				arms += 1
		if arms >= 3 and absi(cell.x * 92821 ^ cell.y * 68917) % 9 == 0:
			junctions.append(cell)
	junctions.sort_custom(func(cell_a: Vector2i, cell_b: Vector2i) -> bool:
		return cell_a < cell_b
	)
	for junction: Vector2i in junctions:
		if _direction_post_cells.size() >= 6:
			break
		for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			var post_cell := junction + direction
			# The post wants open grass beside the lane, clear of other posts.
			if int(grid.get(post_cell, CELL_ROCK)) != CELL_ROCK:
				continue
			if _direction_post_cells.has(post_cell):
				continue
			_direction_post_cells[post_cell] = true
			break

## Plans the village's readable boards for the level on display, purely
## from the stored level data (no RNG state), so re-showing a level always
## rebuilds the same signs. Every civic room with a ring door gets a shop
## signboard on the grass flanking its entrance, and the market square's
## rim hosts up to two notice boards. Cellars and the wilds carry none.
func _plan_village_signboards(grid: Dictionary) -> void:
	_shop_sign_cells.clear()
	_notice_board_cells.clear()
	_clear_sign_hover_label()
	if _wild_mode or _is_underground_level() or grid.is_empty():
		return
	var render_bounds := _find_bounds(grid).grow(1)
	var used: Dictionary = _direction_post_cells.duplicate()
	var building_ids := _latest_civic_buildings_by_id.keys()
	building_ids.sort()
	for building_id_variant: Variant in building_ids:
		var payload := _latest_civic_buildings_by_id[building_id_variant] as Dictionary
		# Back rooms (kitchens, stockrooms, forge annexes) hang no boards;
		# the shopfront room wearing the building's trade carries the sign.
		if SIGN_SKIPPED_ROOM_TYPES.has(String(payload.get("type", ""))):
			continue
		var anchor_variant: Variant = payload.get("anchor")
		if not (anchor_variant is Vector2i):
			continue
		var sign_cell := _pick_signboard_cell_for_building(grid, payload, used, render_bounds)
		if sign_cell.x == 2147483647:
			continue
		used[sign_cell] = true
		_shop_sign_cells[sign_cell] = anchor_variant as Vector2i
	# Notice boards: grass cells hugging the square, sorted for
	# determinism, spaced so the two boards never crowd one corner.
	var rim_cells: Array[Vector2i] = []
	for key_variant: Variant in grid.keys():
		var plaza_cell := key_variant as Vector2i
		if int(grid[plaza_cell]) != CELL_PLAZA:
			continue
		for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			var rim_cell := plaza_cell + direction
			if int(grid.get(rim_cell, CELL_ROCK)) != CELL_ROCK:
				continue
			if used.has(rim_cell) or not render_bounds.has_point(rim_cell):
				continue
			rim_cells.append(rim_cell)
	rim_cells.sort()
	for rim_cell: Vector2i in rim_cells:
		if _notice_board_cells.size() >= 2:
			break
		var spaced := true
		for placed_variant: Variant in _notice_board_cells.keys():
			var placed := placed_variant as Vector2i
			if absi(placed.x - rim_cell.x) + absi(placed.y - rim_cell.y) < 10:
				spaced = false
				break
		if not spaced:
			continue
		used[rim_cell] = true
		_notice_board_cells[rim_cell] = true

## The open-grass cell where a civic room's signboard stands: beside the
## stoop of its ring door, off the lane, never sealing a doorway. Returns
## the invalid sentinel when no ring door faces usable grass.
func _pick_signboard_cell_for_building(grid: Dictionary, payload: Dictionary, used: Dictionary, render_bounds: Rect2i) -> Vector2i:
	var door_candidates: Array[Vector2i] = []
	for cell_variant: Variant in (payload.get("cells", []) as Array):
		var cell := cell_variant as Vector2i
		if _door_cells.has(cell):
			door_candidates.append(cell)
	door_candidates.sort()
	for door_cell: Vector2i in door_candidates:
		for direction: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
			var outside := door_cell + direction
			var outside_zone := int(grid.get(outside, CELL_ROCK))
			# Only ring doors open onto the village; partition doors face
			# another room and never earn a board.
			if outside_zone != CELL_ROCK and outside_zone != CELL_HALL and outside_zone != CELL_PLAZA:
				continue
			var perpendicular := Vector2i(direction.y, direction.x)
			for flank: Vector2i in [outside + perpendicular, outside - perpendicular, outside + direction + perpendicular, outside + direction - perpendicular]:
				if used.has(flank) or _door_cells.has(flank):
					continue
				if int(grid.get(flank, CELL_ROCK)) != CELL_ROCK:
					continue
				if not render_bounds.has_point(flank):
					continue
				return flank
	return Vector2i(2147483647, 2147483647)

func _carve_winding_lane(grid: Dictionary, from_cell: Vector2i, to_cell: Vector2i, spine: Array[Vector2i]) -> void:
	## Most lanes are 2 tiles wide; roughly a third widen to 3.
	var wide := _rng.randf() < 0.3
	var cursor := from_cell
	var guard := 0
	while cursor != to_cell and guard < 900:
		guard += 1
		_stamp_lane_cell(grid, cursor, wide)
		## Every other lane cell joins the spine so later lanes can branch
		## off this one instead of tracing their own way to the square.
		if guard % 2 == 0:
			spine.append(cursor)
		var delta := to_cell - cursor
		var step_horizontal := absi(delta.x) > absi(delta.y)
		if delta.x != 0 and delta.y != 0:
			## Weight the step toward the longer remaining axis: the lane
			## drifts diagonally instead of running ruler-straight legs.
			step_horizontal = _rng.randf() < float(absi(delta.x)) / float(absi(delta.x) + absi(delta.y))
		var step := Vector2i(signi(delta.x), 0) if step_horizontal else Vector2i(0, signi(delta.y))
		## An occasional sideways wobble far from the goal keeps it winding.
		if _rng.randf() < 0.12 and absi(delta.x) + absi(delta.y) > 5:
			step = Vector2i(0, 1 if _rng.randf() < 0.5 else -1) if step.x != 0 else Vector2i(1 if _rng.randf() < 0.5 else -1, 0)
		cursor += step
	_stamp_lane_cell(grid, to_cell, wide)

func _stamp_lane_cell(grid: Dictionary, cell: Vector2i, wide: bool) -> void:
	## A 2x2 stamp guarantees a continuous >=2-tile lane along any step
	## direction; wide lanes stamp the 3x3 block around the cursor.
	## _set_cell refuses to eat building floors, walls, or the square.
	var origin := cell - Vector2i.ONE if wide else cell
	var span := 3 if wide else 2
	for offset_y in span:
		for offset_x in span:
			_set_cell(grid, origin + Vector2i(offset_x, offset_y), CELL_HALL)

## --- Yards & the village well ----------------------------------------------
## Some houses stake out a fenced yard on a free flank: fence rails with a
## gate gap (the farm-pen art) around rows of garden crops and flowers.
## Yards are planned at generation time so they are deterministic per seed
## and never block a lane; the fences themselves are stamped as decor.
func _plan_house_yards(grid: Dictionary, door_cells: Dictionary) -> Array[Dictionary]:
	var yards: Array[Dictionary] = []
	for component_info: Dictionary in SettlementArchitectureService.collect_structure_components(grid):
		if int(component_info.get("zone", CELL_ROCK)) != CELL_HOUSE:
			continue
		## Rooms of one house are separate components (walls sever them), so
		## the roll runs per room — sides that face a sibling room fail the
		## all-grass check and never get a yard.
		if _rng.randf() > 0.35:
			continue
		var bbox := component_info.get("bbox", Rect2i()) as Rect2i
		var yard := _fit_yard_beside(grid, door_cells, bbox)
		if not yard.is_empty():
			yards.append(yard)
	return yards

func _fit_yard_beside(grid: Dictionary, door_cells: Dictionary, bbox: Rect2i) -> Dictionary:
	var depth := _rng.randi_range(3, 4)
	var sides: Array[Vector2i] = [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]
	_seeded_shuffle(sides)
	for side: Vector2i in sides:
		var rect := Rect2i()
		if side == Vector2i.DOWN:
			rect = Rect2i(Vector2i(bbox.position.x, bbox.end.y), Vector2i(bbox.size.x, depth))
		elif side == Vector2i.UP:
			rect = Rect2i(Vector2i(bbox.position.x, bbox.position.y - depth), Vector2i(bbox.size.x, depth))
		elif side == Vector2i.LEFT:
			rect = Rect2i(Vector2i(bbox.position.x - depth, bbox.position.y), Vector2i(depth, bbox.size.y))
		else:
			rect = Rect2i(Vector2i(bbox.end.x, bbox.position.y), Vector2i(depth, bbox.size.y))
		if rect.size.x < 3 or rect.size.y < 3:
			continue
		## The yard, its fence line, and one cell of breathing room beyond
		## must all be open grass — lanes were traced first, so a yard can
		## never wall off a doorway. The margin row on the house's own side
		## is exempt: that's the building wall the yard leans against.
		var margin := rect.grow(1)
		var clear := true
		for y in range(margin.position.y, margin.end.y):
			for x in range(margin.position.x, margin.end.x):
				var on_house_margin := (side == Vector2i.DOWN and y < rect.position.y) \
					or (side == Vector2i.UP and y >= rect.end.y) \
					or (side == Vector2i.LEFT and x >= rect.end.x) \
					or (side == Vector2i.RIGHT and x < rect.position.x)
				if on_house_margin:
					continue
				if _cell_at(grid, x, y) != CELL_ROCK:
					clear = false
					break
			if not clear:
				break
		if not clear:
			continue
		## A doorway directly on the shared house wall must stay clear too.
		var door_blocked := false
		for door_variant: Variant in door_cells.keys():
			var door_cell := door_variant as Vector2i
			if rect.grow(1).has_point(door_cell) and bbox.has_point(door_cell):
				door_blocked = true
				break
		if door_blocked:
			continue
		var rails: Array[Vector2i] = []
		var posts: Array[Vector2i] = []
		var garden: Array[Vector2i] = []
		## Fence the three open edges; the house wall closes the fourth.
		## The gate sits mid-way along the edge opposite the house.
		var gate := rect.position + rect.size / 2
		if side == Vector2i.DOWN:
			gate = Vector2i(rect.position.x + rect.size.x / 2, rect.end.y - 1)
		elif side == Vector2i.UP:
			gate = Vector2i(rect.position.x + rect.size.x / 2, rect.position.y)
		elif side == Vector2i.LEFT:
			gate = Vector2i(rect.position.x, rect.position.y + rect.size.y / 2)
		else:
			gate = Vector2i(rect.end.x - 1, rect.position.y + rect.size.y / 2)
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				var house_edge := (side == Vector2i.DOWN and y == rect.position.y) \
					or (side == Vector2i.UP and y == rect.end.y - 1) \
					or (side == Vector2i.LEFT and x == rect.end.x - 1) \
					or (side == Vector2i.RIGHT and x == rect.position.x)
				var on_rim := x == rect.position.x or x == rect.end.x - 1 or y == rect.position.y or y == rect.end.y - 1
				if cell == gate:
					continue
				if on_rim and not house_edge:
					## Horizontal runs read as rails, vertical as posts —
					## the same art split the farm pens use.
					if y == rect.position.y or y == rect.end.y - 1:
						rails.append(cell)
					else:
						posts.append(cell)
				else:
					garden.append(cell)
		return {"rails": rails, "posts": posts, "gate": gate, "garden": garden, "rect": rect}
	return {}

## The well stands at the market square's heart: a 2x2 decor composition
## whose basin row blocks movement while the roof halves stay walk-under.
## The anchor (basin-left) is searched over the whole plaza nearest its
## heart — the old fixed (-1,0) probe silently dropped the well whenever
## the organic plaza shape missed that exact spot. One breathing-room ring
## is required around the composition so the well never hugs the plaza rim.
func _pick_village_well_cell(grid: Dictionary) -> Vector2i:
	var plaza_cells: Array[Vector2i] = []
	var centroid := Vector2.ZERO
	for key_variant: Variant in grid.keys():
		if int(grid[key_variant]) == CELL_PLAZA:
			var plaza_cell := key_variant as Vector2i
			plaza_cells.append(plaza_cell)
			centroid += Vector2(plaza_cell)
	if plaza_cells.is_empty():
		return DwarfHoldStateModel.INVALID_CELL
	centroid /= float(plaza_cells.size())
	plaza_cells.sort_custom(func(cell_a: Vector2i, cell_b: Vector2i) -> bool:
		var da := Vector2(cell_a).distance_squared_to(centroid)
		var db := Vector2(cell_b).distance_squared_to(centroid)
		if is_equal_approx(da, db):
			return cell_a < cell_b
		return da < db
	)
	for margin: int in [1, 0]:
		for anchor: Vector2i in plaza_cells:
			var fits := true
			for y in range(-1 - margin, 1 + margin):
				for x in range(-margin, 2 + margin):
					if int(grid.get(anchor + Vector2i(x, y), CELL_ROCK)) != CELL_PLAZA:
						fits = false
						break
				if not fits:
					break
			if fits:
				return anchor
	return DwarfHoldStateModel.INVALID_CELL

## Whether the level currently on display is a cellar. Every surface-only
## system (wilds streaming, gates, weather, farms, animals, caravans) keys
## off this so cellars render as sealed underground interiors.
func _is_underground_level() -> bool:
	return _hold_state.current_level_index > 0

## Towns sleep everyone above ground: the 10:1 resident target applies to
## the surface level IN FULL, and the storage cellar draws no share. The
## base class's even split across levels quartered the street population
## when the old clamp bug forced towns to four levels.
func _target_npcs_for_level(level_index: int, _level_count: int) -> int:
	if level_index > 0:
		return 0
	return _hold_state.target_resident_npcs

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
	# The actor layer (with any dropped-item sprites) is rebuilt below; drop
	# the stale ground-item entries so they can't re-grant items later.
	_clear_ground_items()
	_setup_surface_world(grid)
	_latest_zone_counts = level_data.get("zone_counts", {}) as Dictionary
	_latest_requested_zone_counts = level_data.get("requested_zone_counts", {}) as Dictionary
	_latest_civic_buildings_by_id = level_data.get("civic_buildings_by_id", {}) as Dictionary
	_latest_civic_building_type_map = level_data.get("civic_building_type_map", {}) as Dictionary
	_latest_civic_building_name_map = _build_civic_building_name_lookup(_latest_civic_buildings_by_id, seed_input.text.strip_edges(), "townsfolk")
	_latest_residence_type_map = level_data.get("residence_type_map", {}) as Dictionary
	_plan_village_signboards(grid)
	_village_yards = level_data.get("village_yards", []) as Array
	var well_variant: Variant = level_data.get("well_cell")
	_village_well_cell = (well_variant as Vector2i) if well_variant is Vector2i else Vector2i(2147483647, 2147483647)
	_hold_state.active_level_stairs = level_data.get("stair_cells", {}) as Dictionary

	_chest_inventories.clear()
	# Shop stocks are keyed by anchor cell; a reseed must roll fresh shelves
	# instead of serving the old town's (possibly depleted) stock on a
	# colliding anchor.
	_shop_stocks.clear()
	_clear_chest_selection()
	_render_city(grid, _hold_state.active_level_stairs)
	# _restore_homestead (via _setup_surface_world above) stamps saved builds
	# before _render_city clears both layers and repaints the town rect plus
	# its one-cell border ring; a build hugging the town edge sits on that
	# ring, so the repaint wiped its art while _player_built_cells kept
	# blocking the cell (and a ring chest stopped answering clicks).
	_restamp_player_builds()
	_spawn_tavern_characters(grid)
	# After the NPC spawn (which rebuilds the actor layer's children).
	_furnish_interiors(grid)
	_build_farmsteads()
	_scatter_desert_decor()
	_spawn_farm_animals()
	_update_summary(grid, seed_input.text.strip_edges())
	_update_zone_overlay()
	_update_depth_controls()
	# Crossing the surface/underground boundary changes the sky tint rule;
	# drop the cache so the new level's tint applies this frame.
	_applied_day_night_tint = Color(-1.0, -1.0, -1.0, -1.0)
	_update_day_night_tint()
	_update_weather_visuals()
	if _wild_mode and _player_sprite != null:
		_wild_needs_recenter = true
		# An open-sea embark starts the player afloat so the boat sprite shows
		# and the water reads as their medium from the first frame.
		if _wild_water:
			_set_boating(true)

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
	# Ward darkness and its sconces ride the same switch: lighting off
	# means a plain, undarkened ward.
	for overlay_variant: Variant in _ward_overlays.values():
		for node_variant: Variant in (overlay_variant as Dictionary).get("nodes", []) as Array:
			var ward_node := node_variant as Node2D
			if ward_node != null and is_instance_valid(ward_node):
				ward_node.visible = _lighting_enabled

func _render_city(grid: Dictionary, stair_cells: Dictionary = {}) -> void:
	if city_layer.tile_set == null:
		return
	city_layer.clear()
	decor_layer.clear()
	_surface_chunks.clear()
	_surface_family_memo.clear()
	_surface_last_player_chunk = Vector2i(2147483647, 2147483647)
	var bounds := _find_bounds(grid).grow(1)
	_dark_grass_rect = _find_bounds(grid).grow(-1)
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
			if base_tile in WALL_FRAME_TILE_KEYS:
				# Framed-room pieces are opaque toward the interior and cut out
				# toward the exterior, so they sit over a ground tile: lay the
				# surrounding ground on the terrain layer and stamp the timber
				# frame on the decor layer above it. Cut-out edges then read as
				# walls-on-ground rather than black gaps. The cell still blocks:
				# the ground is walkable but the frame tile is not in the passable
				# set, and passability requires both layers to clear.
				_place_tile(city_layer, render_cell, _wall_ground_fill_tile())
				_place_tile(decor_layer, render_cell, base_tile)
			else:
				_place_tile(city_layer, render_cell, base_tile)
			var decor_tile := _pick_decor_tile(grid, x, y, cell, base_tile, house_decor_overrides)
			# Cellar rock is solid earth, not a lawn: keep it out of the
			# green-cell pool that feeds farms, animals and NPC idling.
			if cell == CELL_ROCK and decor_tile.is_empty() and not _is_underground_level():
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
		# The hatch may have displaced two-tile-tall furniture (indoor stair
		# cells are floor cells); its cap above would hang orphaned, so
		# clear any *_top piece whose base this stair just replaced.
		var cap_cell := stair_cell + Vector2i.UP
		if decor_layer.get_cell_source_id(cap_cell) >= 0:
			var cap_atlas := decor_layer.get_cell_atlas_coords(cap_cell)
			for top_key_variant: Variant in TALL_DECOR_TOPS.values():
				# Parenthesized: "as" binds looser than "==", so the bare cast
				# tried to cast the comparison's bool and errored every pass.
				if cap_atlas == (TILE_ATLAS.get(String(top_key_variant), Vector2i(-1000, -1000)) as Vector2i):
					decor_layer.erase_cell(cap_cell)
					_actor_passable_cache.erase(cap_cell)
					break
	_stamp_village_well(stair_cells)
	_stamp_village_yards()
	_reset_view(bounds)

## Stamps the market-square well: basin pair on the anchor row (blocking),
## roofed crank pair above (passable visual caps). Skipped when a stairway
## claimed one of its cells.
func _stamp_village_well(stair_cells: Dictionary) -> void:
	if _village_well_cell.x == 2147483647:
		return
	var pieces := {
		_village_well_cell: "well_base_left",
		_village_well_cell + Vector2i.RIGHT: "well_base_right",
		_village_well_cell + Vector2i.UP: "well_roof_left",
		_village_well_cell + Vector2i(1, -1): "well_roof_right"
	}
	for stair_variant: Variant in stair_cells.values():
		if pieces.has(stair_variant as Vector2i):
			return
	for piece_cell: Vector2i in pieces.keys():
		_place_tile(decor_layer, piece_cell, String(pieces[piece_cell]))

## Stamps every planned yard: fence rails and posts with a gate gap, and
## garden rows inside — tilled soil with a crop on alternating ranks, the
## rest flowers or open grass. Desert and snow towns keep the fence but
## skip the tilled beds, matching their barren dressing rules. Yard ground
## leaves _green_cells so farmsteads, animals, and scatter keep off it.
func _stamp_village_yards() -> void:
	if _village_yards.is_empty():
		return
	var yard_ground: Dictionary = {}
	var grow_crops := _town_theme != "desert" and _town_ground_biome != TILE_ATLAS_DEFS.BIOME_TUNDRA
	var crop_families: Array[String] = ["crop_carrot", "crop_beetroot", "crop_tomato"]
	for yard_variant: Variant in _village_yards:
		var yard := yard_variant as Dictionary
		# Connection-aware fencing: rails and posts form one line set (the
		# gate cell was never added, so its flanks resolve to end caps and
		# the gap reads as a gateway instead of a missing tooth).
		var fence_line: Dictionary = {}
		for rail_variant: Variant in (yard.get("rails", []) as Array):
			fence_line[rail_variant as Vector2i] = true
		for post_variant: Variant in (yard.get("posts", []) as Array):
			fence_line[post_variant as Vector2i] = true
		for fence_variant: Variant in fence_line.keys():
			var fence_cell := fence_variant as Vector2i
			_place_tile(decor_layer, fence_cell, _fence_tile_for_line(fence_line, fence_cell))
			yard_ground[fence_cell] = true
		var gate_variant: Variant = yard.get("gate")
		if gate_variant is Vector2i:
			# The gate stays open ground; clear any scatter decor off it.
			decor_layer.erase_cell(gate_variant as Vector2i)
			_actor_passable_cache.erase(gate_variant as Vector2i)
		var crop_family := crop_families[_rng.randi_range(0, crop_families.size() - 1)]
		# The tilled ranks are decided up front so each bed cell can pick the
		# grass-fringed tilled piece matching its rank neighbors: single-rank
		# beds get frayed north/south edges, rank ends get peninsula tips.
		var tilled_cells: Dictionary = {}
		if grow_crops:
			for garden_variant: Variant in (yard.get("garden", []) as Array):
				var garden_cell := garden_variant as Vector2i
				if absi(garden_cell.y) % 2 == 0:
					tilled_cells[garden_cell] = true
		for garden_variant: Variant in (yard.get("garden", []) as Array):
			var garden_cell := garden_variant as Vector2i
			yard_ground[garden_cell] = true
			# Clear tree/hedge scatter so the plot reads as tended ground.
			decor_layer.erase_cell(garden_cell)
			_actor_passable_cache.erase(garden_cell)
			if tilled_cells.has(garden_cell):
				_place_tile(city_layer, garden_cell, _tilled_tile_key(garden_cell, tilled_cells))
				_place_tile(decor_layer, garden_cell, "%s_%d" % [crop_family, _rng.randi_range(1, 2)])
			elif _rng.randf() < 0.3 and _town_theme != "desert" and _town_ground_biome != TILE_ATLAS_DEFS.BIOME_TUNDRA:
				_place_tile(decor_layer, garden_cell, "flowers_white" if _rng.randf() < 0.5 else "flowers_yellow")
	if not yard_ground.is_empty():
		var remaining_green: Array[Vector2i] = []
		for green_cell: Vector2i in _green_cells:
			if not yard_ground.has(green_cell):
				remaining_green.append(green_cell)
		_green_cells = remaining_green

## Picks the fence piece whose rails match the line's actual neighbors, so
## runs, corners, tees and gate-flanking end caps all connect.
func _fence_tile_for_line(fence_line: Dictionary, cell: Vector2i) -> String:
	return TownTileService.fence_tile_for_connections(
		fence_line.has(cell + Vector2i.UP),
		fence_line.has(cell + Vector2i.RIGHT),
		fence_line.has(cell + Vector2i.DOWN),
		fence_line.has(cell + Vector2i.LEFT),
		cell.x, cell.y
	)

func _pick_level_stair_cells(grid: Dictionary, level_index: int, level_count: int, door_cells: Dictionary = {}) -> Dictionary:
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
		## The surface cellar hatch lives INDOORS: a back-room floor cell of
		## a house or shop, like a real cellar entrance. The floor cell is
		## already passable at the connectivity pass's rules, and the repair
		## pass roots its BFS at the stairs, so reachability stays guaranteed.
		var down_cell := Vector2i(2147483647, 2147483647)
		if level_index == 0:
			down_cell = _pick_indoor_stair_cell(grid, door_cells, up_cell)
		if down_cell.x == 2147483647:
			down_cell = _pick_required_stair_cell(grid)
			if down_cell == up_cell:
				down_cell = _pick_required_stair_cell(grid, up_cell)
		if down_cell.x != 2147483647:
			result["down"] = down_cell

	return result

## An interior floor cell for the surface down-stair, biased toward BACK
## rooms (rooms without their own exterior door — the hatch belongs in a
## pantry, not the shopfront). Rooms are zone components (partition walls
## sever them); a room owning a ring door keeps its zone on the door cell,
## so door_cells membership marks entrance rooms. Falls back to any interior
## floor cell, and to the sentinel when the level has no buildings at all.
func _pick_indoor_stair_cell(grid: Dictionary, door_cells: Dictionary, excluded_cell: Vector2i) -> Vector2i:
	var visited: Dictionary = {}
	var back_room_candidates: Array[Vector2i] = []
	var any_candidates: Array[Vector2i] = []
	for key_variant: Variant in grid.keys():
		var origin := key_variant as Vector2i
		if visited.has(origin):
			continue
		var zone := int(grid[key_variant])
		if zone != CELL_BUILDING and zone != CELL_HOUSE:
			continue
		var queue: Array[Vector2i] = [origin]
		visited[origin] = true
		var room_cells: Array[Vector2i] = []
		var has_exterior_door := false
		var head := 0
		while head < queue.size():
			var current: Vector2i = queue[head]
			head += 1
			room_cells.append(current)
			if door_cells.has(current):
				has_exterior_door = true
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor: Vector2i = current + direction
				if visited.has(neighbor):
					continue
				if int(grid.get(neighbor, CELL_ROCK)) != zone:
					continue
				visited[neighbor] = true
				queue.append(neighbor)
		for room_cell: Vector2i in room_cells:
			if room_cell == excluded_cell or door_cells.has(room_cell):
				continue
			if TownTileService.wall_or_floor_tile(grid, room_cell.x, room_cell.y, zone, door_cells) != "floor":
				continue
			any_candidates.append(room_cell)
			if not has_exterior_door:
				back_room_candidates.append(room_cell)
	var pool := back_room_candidates if not back_room_candidates.is_empty() else any_candidates
	if pool.is_empty():
		return Vector2i(2147483647, 2147483647)
	_seeded_shuffle(pool)
	return pool[0]

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
	# The wilds have no interiors to dress; the clearing stays open ground.
	if actor_layer == null or _wild_mode:
		return
	## Stairways live on the CITY layer (no decor), so the decor probe alone
	## reads them as free floor — a prop dropped there would hide the cellar
	## hatch and block the only way downstairs.
	var stair_lookup: Dictionary = {}
	for stair_variant: Variant in _hold_state.active_level_stairs.values():
		stair_lookup[stair_variant as Vector2i] = true
	var is_occupied := func(cell: Vector2i) -> bool:
		return stair_lookup.has(cell) or decor_layer.get_cell_source_id(cell) >= 0
	# Houses get home comforts.
	for component_variant: Variant in RoomFurnishingService.collect_zone_components(grid, CELL_HOUSE):
		var component: Array[Vector2i] = []
		for cell_variant: Variant in (component_variant as Array):
			component.append(cell_variant as Vector2i)
		var placements: Array[Dictionary] = RoomFurnishingService.plan_house_furnishing(component, is_occupied, _door_cells, _rng, grid)
		_apply_furnishing_placements(placements)
		_place_house_hearth(grid, component, is_occupied)
	# Shops get stock on the shelves.
	for component_variant: Variant in RoomFurnishingService.collect_zone_components(grid, CELL_BUILDING):
		var component: Array[Vector2i] = []
		for cell_variant: Variant in (component_variant as Array):
			component.append(cell_variant as Vector2i)
		if component.is_empty():
			continue
		var building_type := String(_latest_civic_building_type_map.get(component[0], ""))
		var placements: Array[Dictionary] = RoomFurnishingService.plan_shop_dressing(component, building_type, is_occupied, _door_cells, _rng, grid)
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
		# Furniture is scenery, treated as tiles: the decor layer, under
		# every walker, tinted by the same day/night modulate.
		decor_layer.add_child(sprite)
		_furnishing_sprites.append(sprite)
		if int((RoomFurnishingService.PIECES.get(piece_name, {}) as Dictionary).get("rows_block", 1)) > 0:
			for cell: Vector2i in RoomFurnishingService.footprint_cells(piece_name, base_cell):
				_furnishing_blocked_cells[cell] = true
				_actor_passable_cache.erase(cell)
		if RoomFurnishingService.piece_emits_light(piece_name):
			_spawn_hearth_glow(base_cell, 2.4)

## Every roomy house earns a hearth on its north wall row: an oven tile,
## its chimney cap, and firelight. The grid lets interior_cells treat
## partition-wall neighbors as inside, so multi-room houses keep theirs.
func _place_house_hearth(grid: Dictionary, component: Array[Vector2i], is_occupied: Callable) -> void:
	var interior: Array[Vector2i] = RoomFurnishingService.interior_cells(component, grid)
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
	# No farms in the untamed wilds - the clearing has no settlement to feed.
	# And none in the cellars: farmsteads are surface dressing.
	if actor_layer == null or _wild_mode or _is_underground_level() or _town_theme == "desert" or _green_cells.is_empty():
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
	for key: String in ["tree", "tree_dark", "tree_snowy", "tree_dark_snowy",
			"hedge", "hedge_alt", "flowers_white",
			"flowers_yellow", "flowers_pink", "flowers_pink_alt", "stump", "stump_alt"]:
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
	var pen_fence: Dictionary = {}
	for y in range(pen_rect.position.y, pen_rect.end.y):
		for x in range(pen_rect.position.x, pen_rect.end.x):
			var cell := Vector2i(x, y)
			var on_edge := x == pen_rect.position.x or x == pen_rect.end.x - 1 or y == pen_rect.position.y or y == pen_rect.end.y - 1
			if on_edge and cell != gate_cell:
				pen_fence[cell] = true
			elif not on_edge:
				pen_cells.append(cell)
	# Connection-aware pieces: corner posts, straight rails, and end caps
	# flanking the gate, instead of the old two-tile checkerboard.
	for fence_variant: Variant in pen_fence.keys():
		var fence_cell := fence_variant as Vector2i
		_place_tile(decor_layer, fence_cell, _fence_tile_for_line(pen_fence, fence_cell))
	if not pen_cells.is_empty():
		_farm_pens.append(pen_cells)

	# Tilled crop plot on the bottom-right: sandy soil in crop rows, its rim
	# wearing the grass fringe so the field doesn't cut a hard tan rectangle
	# out of the green (desert/snow towns keep the plain barren plot).
	var crop_rect := Rect2i(origin + Vector2i(7, 5), Vector2i(3, 4))
	var crop_art := FARM_CROP_RECTS[_rng.randi_range(0, FARM_CROP_RECTS.size() - 1)]
	var plot_fringed := _town_theme != "desert" and _town_ground_biome != TILE_ATLAS_DEFS.BIOME_TUNDRA
	var plot_members: Dictionary = {}
	for y in range(crop_rect.position.y, crop_rect.end.y):
		for x in range(crop_rect.position.x, crop_rect.end.x):
			plot_members[Vector2i(x, y)] = true
	for y in range(crop_rect.position.y, crop_rect.end.y):
		for x in range(crop_rect.position.x, crop_rect.end.x):
			var plot_tile := "sand"
			if plot_fringed:
				var suffix := TownTileService.fringe_suffix(
					not plot_members.has(Vector2i(x, y - 1)),
					not plot_members.has(Vector2i(x, y + 1)),
					not plot_members.has(Vector2i(x - 1, y)),
					not plot_members.has(Vector2i(x + 1, y)),
					not plot_members.has(Vector2i(x - 1, y - 1)),
					not plot_members.has(Vector2i(x + 1, y - 1)),
					not plot_members.has(Vector2i(x - 1, y + 1)),
					not plot_members.has(Vector2i(x + 1, y + 1)),
					true, x, y)
				if not suffix.is_empty():
					plot_tile = "sand_grass_" + suffix
			_place_tile(city_layer, Vector2i(x, y), plot_tile)
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
	# Surface-only dressing: no sun-bleached bones in an underground cellar.
	if _town_theme != "desert" or actor_layer == null or _is_underground_level() or _green_cells.is_empty():
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
	if actor_layer == null:
		return
	# Cellars keep no livestock at all — not even the player's own animals
	# follow them underground (they're restored on the next surface render).
	if _is_underground_level():
		return
	# Owned animals are the player's property, not town dressing: restore
	# them first so wild and desert scenes (where crates still release)
	# keep them across rebuilds instead of losing them to the next persist.
	_restore_owned_animals()
	if _wild_mode or _town_theme == "desert":
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
	# The farm sheets are drawn at 32px-per-tile density: the cow's 64px
	# frame means it IS a two-tile beast. Scale by pixel density, not
	# frame-fit, or the cow shrinks down to chicken size.
	sprite.scale = Vector2.ONE * (float(tile_size.y) / 32.0)
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
	# The farm sheets carry native side facings: column 2 walks LEFT and
	# column 3 walks RIGHT. Reusing column 2 for both (with a flip) made
	# every animal amble backwards half the time.
	var column := 0
	sprite.flip_h = false
	if facing == Vector2i.UP:
		column = 1
	elif facing == Vector2i.RIGHT:
		column = 3
	elif facing == Vector2i.LEFT:
		column = 2
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

## Why a sealed hold is sealed: chronicler's flavor, stable per site.
const SEALED_GATE_REASONS: Array[String] = [
	"\"The hold mourns. No strangers.\"",
	"\"Plague walks the deep halls. Turn back.\"",
	"\"War has come to the mountain. The gate stays shut.\"",
	"\"The deep levels have gone silent. None enter.\"",
	"\"Goblin banners in the pass. We open for no one.\"",
	"\"By order of the Thane: sealed until the omen passes.\""
]

func _sealed_gate_reason(cell: Vector2i) -> String:
	var site_key := _ward_site_key_for_cell(cell)
	return SEALED_GATE_REASONS[absi(hash("seal_reason|%s" % site_key)) % SEALED_GATE_REASONS.size()]

## The ward city's workshops trade for real: a click inside a hold
## plot resolves to its building's shop counter. Returns {} off-plot
## and for buildings that keep no counter (palace, barracks, homes).
func _ward_shop_at_cell(cell: Vector2i) -> Dictionary:
	for landmark: Dictionary in _surface_landmarks:
		if String(landmark.get("structure", "")) != "dwarfhold_city":
			continue
		var plan := landmark.get("plan", {}) as Dictionary
		if plan.is_empty() or not (plan.get("bounds", Rect2i()) as Rect2i).has_point(cell):
			continue
		for plot_variant: Variant in plan.get("plots", []) as Array:
			var plot := plot_variant as Dictionary
			var plot_rect := plot.get("rect", Rect2i()) as Rect2i
			if not plot_rect.has_point(cell):
				continue
			var plot_type := String(plot.get("type", ""))
			if not SettlementEconomyService.is_shop_building_type(plot_type):
				return {}
			# One counter per building: the stock anchors on the plot,
			# not the clicked tile, so every wall shares the shelves.
			return {"type": plot_type, "anchor": plot_rect.position}
	return {}

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

func _with_market_hint(section_text: String) -> String:
	var hint := SettlementEconomyService.market_hint_line(_town_market)
	return section_text if hint.is_empty() else "%s — %s" % [section_text, hint]

func _is_trade_mode() -> bool:
	return _trade_shop_cell.x != 2147483647

func _open_trade_popup(cell: Vector2i, shop_type: String, anchor_override: Vector2i = Vector2i(2147483647, 2147483647)) -> void:
	var anchor := anchor_override if anchor_override.x != 2147483647 else _shop_anchor_for_cell(cell)
	# Shelves restock with the calendar: a new game day rerolls the
	# shop's wares, so the forge cycles fresh tools and blades over time
	# instead of selling the same three items forever.
	var last_restock := int(_shop_restock_day.get(anchor, _game_day if _shop_stocks.has(anchor) else -1))
	if not _shop_stocks.has(anchor) or last_restock < _game_day:
		var stock_rng := RandomNumberGenerator.new()
		stock_rng.seed = hash(seed_input.text.strip_edges()) ^ hash(anchor) ^ (_game_day * 7919)
		_shop_stocks[anchor] = SettlementEconomyService.generate_shop_stock(shop_type, stock_rng)
		_shop_restock_day[anchor] = _game_day
	_selected_chest_cell = Vector2i(2147483647, 2147483647)
	_trade_shop_cell = anchor
	# The leash measures from the clicked counter tile, not the stock anchor.
	_trade_leash_cell = cell
	_trade_shop_type = shop_type
	chest_popup.visible = true
	chest_popup_title.text = "Trade — %s" % _display_name_for_building_type(shop_type)
	chest_popup_take_all_button.disabled = true
	var section_label := chest_popup.find_child("ChestSectionLabel", true, false) as Label
	if section_label != null:
		section_label.text = _with_market_hint("Wares for sale")
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
		_chest_slot_panels[i].tooltip_text += "\nBuy for %d coins" % SettlementEconomyService.local_buy_price(item_name, _price_scale(), _town_market)
	_populate_backpack_slots()
	chest_popup_status_label.text = "🪙 %d coins — click wares to buy, click your pack to sell" % _player_coins
	if stock.is_empty():
		chest_popup_status_label.text = "🪙 %d coins — the shelves are bare; come back later" % _player_coins

## Tavern fare is eaten at the bar the moment it is bought: hearts and
## a full belly instead of a backpack item.
const TAVERN_MEAL_HEARTS := {
	"Hearty Stew": 6, "Roast Meat": 5, "Smoked Ribs": 5, "Grilled Fish": 4,
	"Loaf of Bread": 3, "Wheel of Cheese": 3, "Ale Keg": 2
}

func _buy_trade_item(slot_index: int) -> void:
	var stock := _shop_stocks.get(_trade_shop_cell, []) as Array
	if slot_index < 0 or slot_index >= stock.size():
		return
	var entry := stock[slot_index] as Dictionary
	var item_name := String(entry.get("name", "Supplies"))
	var price := SettlementEconomyService.local_buy_price(item_name, _price_scale(), _town_market)
	if _player_coins < price:
		chest_popup_status_label.text = "Not enough coins for %s (%d needed)" % [item_name, price]
		return
	_adjust_coins(-price)
	entry["quantity"] = int(entry.get("quantity", 1)) - 1
	if int(entry.get("quantity", 0)) <= 0:
		stock.remove_at(slot_index)
	if _trade_shop_type == "tavern" and TAVERN_MEAL_HEARTS.has(item_name):
		var hearts := int(TAVERN_MEAL_HEARTS[item_name])
		_player_hp = minf(_player_hp + float(hearts), _player_max_hp)
		_player_satiety = minf(_player_satiety + float(hearts) * PlayerStatsService.SATIETY_MAX / 12.0, PlayerStatsService.SATIETY_MAX)
		_update_hp_label()
		_save_player_hp()
		if _player_sprite != null:
			_spawn_floating_text("+%d ❤" % hearts, _player_sprite.position + Vector2(0, -14), Color(0.95, 0.5, 0.5, 1.0))
		_refresh_trade_panel()
		chest_popup_status_label.text = "You eat the %s at the bar — +%d ❤ (🪙 %d left)" % [item_name, hearts, _player_coins]
		return
	_player_inventory[item_name] = int(_player_inventory.get(item_name, 0)) + 1
	_save_player_inventory()
	_refresh_trade_panel()
	chest_popup_status_label.text = "Bought %s for %d coins (🪙 %d left)" % [item_name, price, _player_coins]

func _sell_item(item_name: String) -> void:
	if int(_player_inventory.get(item_name, 0)) < 1:
		return
	var price := SettlementEconomyService.local_sell_price(item_name, _town_market)
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
	_trade_leash_cell = Vector2i(2147483647, 2147483647)
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
		) * float(layers.get("body_scale", 1.0))
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
	## Chronicle grudges (wars survived, beasts still at large) redirect one
	## guild's agenda toward the town's real history.
	SettlementFactionService.apply_history_agenda(
		_settlement_factions,
		WorldChronicleService.history_agenda_goals(_world_settings_snapshot(), _town_name),
		_rng
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
	# Wilds keepers speak as their true calling, not the town role table.
	if bool(state.get("wilds_keeper", false)):
		role_title = String((state.get("identity", {}) as Dictionary).get("profession", role_title))
	if not state.has("identity"):
		state["identity"] = NpcIdentityService.generate(_rng, role_title, "townsfolk")
		state["npc_name"] = String((state["identity"] as Dictionary).get("name", "A villager"))
	var identity := state.get("identity", {}) as Dictionary
	# Sworn members talk about their faction, others gossip about the
	# guilds, and everyone still has personal news and town rumors.
	var line: String
	var faction_roll := _rng.randf()
	if int(state.get("role", 0)) == ROLE_MERCHANT and _rng.randf() < 0.4:
		# Merchants talk shop: what this market dumps cheap and pays dear for.
		line = SettlementEconomyService.dialogue_line(role_title, SettlementEconomyService.merchant_market_line(_town_market, _rng), _rng)
	elif state.has("faction_name") and faction_roll < 0.35:
		line = SettlementEconomyService.dialogue_line(role_title, SettlementFactionService.member_line(state, _rng), _rng)
	elif faction_roll < 0.5 and not _settlement_factions.is_empty():
		line = SettlementEconomyService.dialogue_line(role_title, SettlementFactionService.faction_rumor(_settlement_factions, _rng), _rng)
	elif _rng.randf() < 0.4:
		line = SettlementEconomyService.dialogue_line(role_title, NpcIdentityService.personal_line(identity, _rng), _rng)
	else:
		# World news travels: sometimes the gossip is about far-off wars
		# and caravans instead of the town's own affairs. History runs
		# deepest — chronicle rumors recall the town's own recorded past.
		var rumor := ""
		if _rng.randf() < 0.35:
			rumor = WorldChronicleService.history_rumor(_world_settings_snapshot(), _town_name, _rng)
		if rumor.is_empty() and _rng.randf() < 0.4:
			rumor = WorldEventsService.rumor_from_events(_world_settings_snapshot(), _game_day, _rng)
		if rumor.is_empty():
			rumor = SettlementEconomyService.rumor_from_town_details(_town_details, _rng)
		line = SettlementEconomyService.dialogue_line(role_title, rumor, _rng)
	var sprite := state.get("sprite") as Sprite2D
	var anchor_position: Vector2 = sprite.position if sprite != null else _player_sprite.position
	_spawn_speech_bubble("%s\n%s" % [NpcIdentityService.summary_line(identity), line], anchor_position)
	if _caravan_offer_pay(state) > 0:
		_show_caravan_offer()

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
	var save_changed := GearService.ensure_equipment_migrated(settings, _player_inventory)
	if GearService.seed_default_hotbar(settings, _player_inventory):
		save_changed = true
	if save_changed:
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
			_backpack_slot_panels[i].tooltip_text += "\nSell for %d coins" % SettlementEconomyService.local_sell_price(item_name, _town_market)

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
	_sync_surface_landmark_transform()
	if tile_hover_tooltip.visible:
		_place_hover_tooltip(tile_hover_tooltip.position - city_panel.global_position)
	lighting_layer.scale = city_layer.scale
	lighting_layer.position = city_layer.position
	if _reflection_sprite != null and is_instance_valid(_reflection_sprite):
		(_reflection_sprite.material as ShaderMaterial).set_shader_parameter("view_zoom", _zoom_level)
	_update_zone_overlay()

func _spawn_tavern_characters(grid: Dictionary) -> void:
	_player_sprite = null
	# The respawn below frees the old player sprite and with it the boat and
	# mount children; drop the stale refs and flags so nothing touches a
	# freed instance and an open-sea embark can raise a fresh boat after.
	_boat_sprite = null
	_mount_sprite = null
	_player_boating = false
	_player_mounted = false
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
	# The wilds hold no residents, and neither does a storage cellar: the
	# tavern_npc_count floor only pads the SURFACE of population-less towns.
	var npc_spawn_count := 0 if _wild_mode or _is_underground_level() else maxi(tavern_npc_count, mini(level_npc_target, 250))
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
	# The body was just rebuilt; re-hang whatever the player is holding.
	_refresh_held_item()

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
	var house_cells: Array[Vector2i] = []
	for grid_cell_variant: Variant in grid.keys():
		var zone := int(grid[grid_cell_variant])
		var lived_cell := grid_cell_variant as Vector2i
		if zone == CELL_HOUSE and _is_walkable_cell(lived_cell):
			house_cells.append(lived_cell)
		if zone != CELL_HALL and zone != CELL_PLAZA:
			continue
		if _is_walkable_cell(lived_cell):
			street_cells.append(lived_cell)
	var npc_count := _npc_states.size()
	# The venue table drives off-shift objectives (tavern, chapel, market
	# visits); built once per generation and handed to every update.
	_npc_pois = SettlementNpcScheduler.build_poi_table(building_cells_by_type, Callable(self, "_is_walkable_cell"))
	SettlementNpcScheduler.assign_daily_lives(_npc_states, {
		"bed_cells": _bed_cells,
		"building_cells_by_type": building_cells_by_type,
		"street_cells": street_cells,
		"house_cells": house_cells,
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
		var mode: String = SettlementNpcScheduler.mode_for_hour(state, _game_hour, WeatherService.is_storm(_current_weather))
		var anchor: Vector2i = SettlementNpcScheduler.anchor_for_mode(state, mode)
		if anchor.x != 2147483647 and _is_walkable_cell(anchor):
			sprite.position = _cell_center_position(anchor)
			state["cell"] = anchor
			state["target"] = sprite.position
		DwarfHoldTavernService.update_character_frame(sprite, int(state.get("slot", 0)), 1, 0)

func _collect_walkable_cells(grid: Dictionary) -> Array[Vector2i]:
	# The wild clearing has no zones - every grassy cell is open ground, so the
	# whole grid is a candidate for the player spawn (passability is filtered
	# by the caller against the rendered tiles).
	if _wild_mode:
		var cells: Array[Vector2i] = []
		for cell_variant: Variant in grid.keys():
			cells.append(cell_variant as Vector2i)
		return cells
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
	# Ward dwarves carry the full dossier: same card, same DF tabs.
	var ward_dwarf := _ward_dwarf_at_cell(clicked_cell)
	if not ward_dwarf.is_empty():
		_open_npc_inspection(ward_dwarf)
		return true
	var npc_state := _npc_state_at_cell(clicked_cell)
	# The risen dead have no pockets worth rifling.
	if npc_state.is_empty() or SettlementAfflictionService.is_active_zombie(npc_state):
		if _npc_inspection_card != null:
			_npc_inspection_card.close()
		# No citizen claimed the click: a sign under the cursor reads
		# itself aloud instead (a look, not a touch, at any distance).
		var sign_info := _sign_text_for_cell(clicked_cell)
		if not sign_info.is_empty():
			_show_sign_dialogue(clicked_cell, sign_info)
			return true
		return false
	_open_npc_inspection(npc_state)
	return true

func _open_npc_inspection(npc_state: Dictionary) -> void:
	if _npc_inspection_card == null:
		return
	var role_title := String(ROLE_TITLES.get(int(npc_state.get("role", 0)), "Villager"))
	if not npc_state.has("identity"):
		npc_state["identity"] = NpcIdentityService.generate(_rng, role_title, "townsfolk")
		npc_state["npc_name"] = String((npc_state["identity"] as Dictionary).get("name", "A villager"))
	_npc_inspection_card.open(npc_state, role_title, hash(seed_input.text.strip_edges()), _calendar_start_year)

func _handle_player_click_action(mouse_position: Vector2) -> void:
	# Any left-click on the map is a click-away for an open inspection.
	if _npc_inspection_card != null and _npc_inspection_card.visible:
		_npc_inspection_card.close()
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
	# The ward's folk: the peddler trades, the rest offer a word.
	var ward_dwarf := _ward_dwarf_at_cell(clicked_cell)
	if not ward_dwarf.is_empty() and _is_player_adjacent_to_cell(clicked_cell):
		if bool(ward_dwarf.get("traveler", false)) and _try_open_traveler_trade(ward_dwarf):
			return
		_spawn_floating_text("Rock and stone!", _cell_center_position(clicked_cell) + Vector2(0, -12), Color(0.9, 0.85, 0.7, 1.0))
		return
	# The mountain digs from inside: an adjacent swing at massif rock
	# chips it away by the hold's own geology.
	if _is_ward_rock_cell(clicked_cell) and _is_player_adjacent_to_cell(clicked_cell):
		_swing_at_ward_rock(clicked_cell)
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
		if bool(npc_state.get("wilds_keeper", false)) and _try_open_keeper_trade(npc_state):
			return
		_show_npc_dialogue(npc_state)
		return
	var shop_type := _shop_type_at_cell(clicked_cell)
	if not shop_type.is_empty() and _is_player_adjacent_to_cell(clicked_cell):
		_open_trade_popup(clicked_cell, shop_type)
		return
	# The hold city's workshops trade too: the forge sells tools and
	# blades, the store buys ore and stone, the tavern serves meals.
	var ward_shop := _ward_shop_at_cell(clicked_cell)
	if not ward_shop.is_empty() and _is_player_adjacent_to_cell(clicked_cell):
		_open_trade_popup(clicked_cell, String(ward_shop.get("type", "")), ward_shop.get("anchor", clicked_cell) as Vector2i)
		return
	# Knocking on a sealed hold gate earns only the reason it is shut.
	if city_layer.get_cell_source_id(clicked_cell) == 0 \
			and city_layer.get_cell_atlas_coords(clicked_cell) == (TILE_ATLAS.get("sealed_gate", Vector2i(-9, -9)) as Vector2i):
		_spawn_floating_text(_sealed_gate_reason(clicked_cell), _cell_center_position(clicked_cell) + Vector2(0, -14), Color(0.85, 0.82, 0.9, 1.0))
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
	if _latest_grid.is_empty():
		return
	# A target outside the generated grid is the streamed wilds (in wild and
	# ocean embarks the grid is only the 11x11 clearing): accept it whenever
	# the keyboard step's passability would, so "click to walk / click to
	# row" works beyond the clearing. Grid targets keep the town logic.
	if not _latest_grid.has(target_cell) and not _is_walkable_cell(target_cell):
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
	# No grid-membership gate: off-grid cells are the streamed wilds, where
	# the same actor passability the keyboard consults decides the step, so
	# click paths may leave the embark clearing. Grid cells resolve through
	# the identical walkability check, unchanged. The path BFS keeps its
	# 8000-cell flood cap, so unreachable wilds clicks stay bounded.
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
	# One tile per step, always - a longer vector would glide the sprite
	# across intermediate cells nothing ever walkability-checked.
	if absi(direction.x) > 1 or absi(direction.y) > 1:
		return false
	var target_cell := _player_cell + direction
	# Corner rule, same as the click pathfinder: no squeezing diagonally
	# between two blocked orthogonals.
	if direction.x != 0 and direction.y != 0:
		if not _player_can_pass_cell(_player_cell + Vector2i(direction.x, 0)) or not _player_can_pass_cell(_player_cell + Vector2i(0, direction.y)):
			return false
	if _is_cell_occupied_by_npc(target_cell):
		return false
	if _player_boating:
		# Afloat: water is the road; solid ground means stepping ashore.
		if not _is_water_cell(target_cell):
			if _is_walkable_cell(target_cell):
				_set_boating(false)
			else:
				return false
	elif not _is_walkable_cell(target_cell):
		if _is_water_cell(target_cell) and int(_player_inventory.get("Coracle", 0)) > 0:
			_set_boating(true)
		else:
			return false
	_player_move_target_cell = target_cell
	_player_move_target_position = _cell_center_position(target_cell)
	_player_is_moving = true
	return true

## What counts as open ground for the corner rule depends on the medium:
## a boater's clearance is water, a walker's is floor.
func _player_can_pass_cell(cell: Vector2i) -> bool:
	if _is_walkable_cell(cell):
		return true
	return _player_boating and _is_water_cell(cell)

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
		Callable(self, "_cell_center_position"),
		WeatherService.is_storm(_current_weather),
		_npc_pois
	)

## The dead answer to their hunger, not the clock.
func _scheduled_states() -> Array[Dictionary]:
	var living: Array[Dictionary] = []
	for state: Dictionary in _npc_states:
		if SettlementAfflictionService.is_active_zombie(state) or bool(state.get("traveler", false)) or bool(state.get("raid_duty", false)) or bool(state.get("wilds_keeper", false)):
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
## PROTOTYPE: each overworld tile expands to a 768-cell-square walkable
## region (was 64). At the fixed 8 km/tile that drops the ground scale from
## ~125 m/step to ~10 m/step. The surface is chunk-streamed, so only the
## window around the player ever exists; the one structure that scaled with
## this constant — the per-tile river course — was reworked to a sparse,
## scale-aware set (SurfaceWorldService) so it never allocates 768x768.
const WORLD_CELLS_PER_OVERWORLD_TILE := 768
const SURFACE_SITE_REACH_TILES := 20
## A settlement entering the window only earns a connecting road when the
## nearest network anchor is within this many cells, so trails stay local
## instead of spanning the map corner to corner.
const SURFACE_ROAD_MAX_CELLS := 14 * WORLD_CELLS_PER_OVERWORLD_TILE

func _setup_surface_world(grid: Dictionary) -> void:
	# The exploration store key changes with the seed/tile stamped below:
	# bank any unsaved exploration under the old key before the rebuild.
	_flush_exploration()
	for gate_label: Label in _surface_gate_labels:
		if is_instance_valid(gate_label):
			gate_label.queue_free()
	_surface_gate_labels.clear()
	_surface_road_cells.clear()
	_surface_blocked_cells.clear()
	_surface_road_paths.clear()
	_surface_gates.clear()
	# Landmark sprites (furnishing pieces, glows, icons, labels) live on the
	# decor/actor/city layers; free them explicitly before dropping the list.
	for landmark: Dictionary in _surface_landmarks:
		_unstamp_surface_landmark_nodes(landmark)
	_surface_landmarks.clear()
	_surface_planned_site_keys.clear()
	_surface_site_road_traced.clear()
	_surface_landmark_blocked_cells.clear()
	_surface_all_sites = []
	_surface_window_tile = Vector2i(2147483647, 2147483647)
	if _surface_landmark_layer != null and is_instance_valid(_surface_landmark_layer):
		for child: Node in _surface_landmark_layer.get_children():
			child.queue_free()
	_surface_anchor_cells.clear()
	_surface_arrival_lock = false
	# The rebuild frees the actor layer's children, bobber included; drop
	# the fishing state so no frame ever touches the freed sprite again.
	_fishing_state = {}
	_clear_caravan_job()
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
		if bool(_npc_states[state_index].get("traveler", false)) or bool(_npc_states[state_index].get("wilds_keeper", false)):
			var traveler_sprite := _npc_states[state_index].get("sprite") as Sprite2D
			if traveler_sprite != null:
				traveler_sprite.queue_free()
			_npc_states.remove_at(state_index)
	# A rebuilt scene garrisons its camps afresh.
	_camp_cleared_sites.clear()
	## Cellars are sealed underground interiors. The teardown above still
	## ran (gates, creatures, caravans and travelers never survive the
	## descent), but no wilds belong down here: clearing the noise set is
	## the master off-switch — _stream_surface_chunks, _check_surface_arrival
	## (via the emptied gate list) and _update_surface_life all early-out on
	## it. Homestead builds and farm plots are surface-anchored, so they are
	## dropped too or they'd restamp into the cellar at the same coordinates.
	if _is_underground_level():
		_surface_noise = {}
		_surface_protect_rect = Rect2i()
		_player_built_cells.clear()
		_farm_plots.clear()
		_wall_damage.clear()
		return
	var seed_text := seed_input.text.strip_edges()
	var settings: Dictionary = {}
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null and game_session.has_method("get_world_settings"):
		settings = game_session.call("get_world_settings")
	var world_seed_text := str(settings.get("world_seed", seed_text))
	_surface_world_seed_text = world_seed_text
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
	# The wilds derive their climate from the overworld biomes around this
	# settlement, so coasts read as sea, deserts as sand, forests as woods.
	_surface_biome_ctx = SurfaceWorldService.make_biome_context(settings.get(TOWN_SCENE_WORLD_BIOMES_KEY, {}) as Dictionary, WORLD_CELLS_PER_OVERWORLD_TILE, settings.get(TOWN_SCENE_WORLD_RIVERS_KEY, {}) as Dictionary)
	# The town's own ground climate: the biome of the overworld tile its
	# centre sits on. Empty when there is no world buffer (standalone tests),
	# which leaves the default grass palette. Snow towns key off tundra here.
	if _surface_biome_ctx.is_empty():
		_town_ground_biome = ""
	else:
		var town_centre_world_cell := own_tile * WORLD_CELLS_PER_OVERWORLD_TILE + Vector2i(WORLD_CELLS_PER_OVERWORLD_TILE / 2, WORLD_CELLS_PER_OVERWORLD_TILE / 2)
		_town_ground_biome = SurfaceWorldService.biome_for_world_cell(_surface_biome_ctx, town_centre_world_cell)
	# The whole gazetteer rides along; the sliding window (re-evaluated as
	# the walker crosses overworld-tile boundaries) decides which sites are
	# live as gates and landmark footprints at any moment.
	_surface_all_sites = WorldSitesService.sites_from_settings(settings)
	_surface_own_tile = own_tile
	_surface_anchor_cells.append(bbox_center)
	_refresh_surface_site_window(own_tile)
	_restore_homestead(settings)
	_restore_exploration(settings)

## The overworld tile a wilds cell stands on, in shared world space.
func _overworld_tile_for_cell(cell: Vector2i) -> Vector2i:
	var world_cell := cell + _surface_world_origin
	return Vector2i(
		int(floor(float(world_cell.x) / float(WORLD_CELLS_PER_OVERWORLD_TILE))),
		int(floor(float(world_cell.y) / float(WORLD_CELLS_PER_OVERWORLD_TILE))))

## Re-evaluates the sliding site window around the given overworld tile:
## gazetteer sites entering the window get planned (gates registered,
## footprints queued for stamping when their chunks stream), sites leaving
## get unplanned. Enter/exit radii differ so a walker pacing a tile border
## doesn't thrash plans. Entering sites are planned nearest-first so each
## new road connects to the closest part of the growing network.
const SURFACE_SITE_WINDOW_EXIT_TILES := SURFACE_SITE_REACH_TILES + 2

func _refresh_surface_site_window(center_tile: Vector2i) -> void:
	_surface_window_tile = center_tile
	var entering: Array[Dictionary] = []
	for site_variant: Variant in _surface_all_sites:
		var site := site_variant as Dictionary
		var tile: Vector2i = WorldSitesService.site_tile(site)
		if tile == _surface_own_tile:
			continue
		var site_key := "%d,%d" % [tile.x, tile.y]
		var tile_distance := maxi(absi(tile.x - center_tile.x), absi(tile.y - center_tile.y))
		if _surface_planned_site_keys.has(site_key):
			if tile_distance > SURFACE_SITE_WINDOW_EXIT_TILES:
				_unplan_surface_site(site_key)
		elif tile_distance <= SURFACE_SITE_REACH_TILES:
			entering.append({"site": site, "key": site_key, "distance": tile_distance})
	entering.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("distance", 0)) < int(b.get("distance", 0)))
	for entry: Dictionary in entering:
		_plan_surface_site(entry.get("site", {}) as Dictionary, String(entry.get("key", "")))

## Registers one gazetteer site in the live window: ambient structures
## become landmark footprints, enterable sites become arrival gates joined
## to the nearest live anchor by a dirt road (once, ever - trails persist).
func _plan_surface_site(site: Dictionary, site_key: String) -> void:
	var tile: Vector2i = WorldSitesService.site_tile(site)
	var anchor: Vector2i = tile * WORLD_CELLS_PER_OVERWORLD_TILE + Vector2i(WORLD_CELLS_PER_OVERWORLD_TILE / 2, WORLD_CELLS_PER_OVERWORLD_TILE / 2) - _surface_world_origin
	if String(site.get("class", "")) == "ambient":
		# Ambient structures are non-enterable scenery: real walkable
		# footprints stamped when their chunks stream in.
		_surface_planned_site_keys[site_key] = true
		_register_surface_landmark(site, anchor, site_key)
		return
	if WorldSitesService.scene_path_for(site).is_empty():
		return
	_surface_planned_site_keys[site_key] = true
	# Settlements greet from their whole clearing; a hold's carved
	# mountain door and a dungeon's mouth only open at the door itself.
	var trigger_cells: Array[Vector2i] = []
	var gate_rect := Rect2i(anchor - Vector2i(3, 3), Vector2i(7, 7))
	match String(site.get("class", "")):
		"dwarfhold":
			# The mouth and the WHOLE MAIN FLOOR are walked freely in
			# THIS scene; the only transition left is DESCENDING, so the
			# trigger is the great hall's stair down to the deeps.
			trigger_cells = [_hold_ward_stair_cell(anchor)]
			# A hold's gate is a whole mountain city, far bigger than a
			# clearing: the rect must cover every stone cell so eviction
			# knows to re-stamp the full mountain on return.
			gate_rect = Rect2i(
				anchor - Vector2i(HOLD_CITY_HALF_W + 1, HOLD_CITY_HALF_H * 2 + 1),
				Vector2i(HOLD_CITY_HALF_W * 2 + 3, HOLD_CITY_HALF_H * 2 + 5))
			# The city's streets, stone and interiors stream chunk by
			# chunk as a landmark plan keyed to the same site.
			var already_registered := false
			for landmark: Dictionary in _surface_landmarks:
				if String(landmark.get("key", "")) == site_key:
					already_registered = true
					break
			if not already_registered:
				_surface_landmarks.append({
					"key": site_key,
					"tile": tile,
					"anchor": anchor,
					"tile_atlas": Vector2i(-1, -1),
					"structure": "dwarfhold_city",
					"name": String(site.get("name", "")),
					# The gazetteer's gate status: a Closed hold bars its
					# mouth against outsiders in the stamped city.
					"closed": String(site.get("access", "Open")) == "Closed",
					"plan": {},
					"rect": Rect2i(
						anchor - Vector2i(HOLD_CITY_HALF_W + 1, HOLD_CITY_HALF_H * 2 + 1),
						Vector2i(HOLD_CITY_HALF_W * 2 + 3, HOLD_CITY_HALF_H * 2 + 3)),
					"stamped_chunks": {},
					"nodes_by_chunk": {}
				})
		"dungeon":
			trigger_cells = [anchor, anchor + Vector2i(0, 1)]
	_surface_gates.append({
		"key": site_key,
		"rect": gate_rect,
		"anchor": anchor,
		"site": site,
		"stamped": false,
		"trigger_cells": trigger_cells,
		"label": null
	})
	if not _surface_site_road_traced.has(site_key):
		# One connecting road per settlement, to the nearest anchor already
		# in the network (the entered town's center seeds it). Distant
		# outliers stay roadless, as the old nearest-few rule left them.
		# A hold's trail aims at the paved apron BELOW its gate - a road
		# ending on the buried anchor would vanish under the massif.
		var road_target := anchor
		if String(site.get("class", "")) == "dwarfhold":
			road_target = anchor + Vector2i(0, 3)
		var nearest := Vector2i(2147483647, 2147483647)
		var nearest_distance := 2147483647
		for known_anchor: Vector2i in _surface_anchor_cells:
			var known_distance := maxi(absi(known_anchor.x - anchor.x), absi(known_anchor.y - anchor.y))
			if known_distance < nearest_distance:
				nearest_distance = known_distance
				nearest = known_anchor
		if nearest.x != 2147483647 and nearest_distance <= SURFACE_ROAD_MAX_CELLS:
			_trace_surface_road(nearest, road_target)
			_surface_site_road_traced[site_key] = true
	_surface_anchor_cells.append(anchor)

## Removes a site that slid out of the window. Its chunks are far outside
## the eviction radius by then, so stamped ground is already gone; this
## clears the bookkeeping (gate, anchor, landmark plan) and any nodes.
func _unplan_surface_site(site_key: String) -> void:
	_surface_planned_site_keys.erase(site_key)
	for gate_index in range(_surface_gates.size() - 1, -1, -1):
		var gate := _surface_gates[gate_index]
		if String(gate.get("key", "")) != site_key:
			continue
		var gate_label := gate.get("label") as Label
		if gate_label != null and is_instance_valid(gate_label):
			_surface_gate_labels.erase(gate_label)
			gate_label.queue_free()
		_free_ward_dwarves_for_key(site_key)
		_free_ward_overlay_for_key(site_key)
		# A hold massif's stamped stone must not haunt the wilds after the
		# mountain is unplanned; natural crag flags in the same rect come
		# back when their chunks repaint from terrain.
		var stale_rect := gate.get("rect", Rect2i()) as Rect2i
		for stale_y in range(stale_rect.position.y, stale_rect.end.y):
			for stale_x in range(stale_rect.position.x, stale_rect.end.x):
				_surface_blocked_cells.erase(Vector2i(stale_x, stale_y))
		_surface_anchor_cells.erase(gate.get("anchor", Vector2i.ZERO) as Vector2i)
		_surface_gates.remove_at(gate_index)
	for landmark_index in range(_surface_landmarks.size() - 1, -1, -1):
		var landmark := _surface_landmarks[landmark_index]
		if String(landmark.get("key", "")) != site_key:
			continue
		_unstamp_surface_landmark_nodes(landmark)
		_surface_landmarks.remove_at(landmark_index)

## Records an ambient structure as a wilds landmark with a real footprint
## recipe. Landmarks on the town footprint are dropped so the streets stay
## clean. The footprint plan itself is computed lazily (and deterministically
## from world seed + site tile) the first time one of its chunks streams.
func _register_surface_landmark(site: Dictionary, anchor: Vector2i, site_key: String) -> void:
	if _surface_protect_rect.has_area() and _surface_protect_rect.has_point(anchor):
		return
	var atlas_variant: Variant = site.get("tile_atlas", [])
	var atlas_coords := Vector2i(-1, -1)
	if atlas_variant is Array and (atlas_variant as Array).size() >= 2:
		var atlas_array := atlas_variant as Array
		atlas_coords = Vector2i(int(atlas_array[0]), int(atlas_array[1]))
	if atlas_coords.x < 0 or atlas_coords.y < 0:
		return
	var structure_id := String(site.get("structure", ""))
	if structure_id.is_empty():
		# Older saves persisted only the icon's atlas coords; map them back
		# to a representative structure id so recipes still apply.
		structure_id = String(AMBIENT_ID_BY_ATLAS.get(atlas_coords, ""))
	_surface_landmarks.append({
		"key": site_key,
		"tile": WorldSitesService.site_tile(site),
		"anchor": anchor,
		"tile_atlas": atlas_coords,
		"structure": structure_id,
		"name": String(site.get("name", "")),
		# Footprint plan (lazy) and its bounding rect for chunk intersection.
		"plan": {},
		"rect": Rect2i(anchor - Vector2i(8, 8), Vector2i(17, 17)),
		# Chunk -> true for every chunk whose slice of this footprint is
		# currently stamped; nodes_by_chunk carries that chunk's sprites.
		"stamped_chunks": {},
		"nodes_by_chunk": {}
	})

## Keeps the landmark layer locked to the city layer's pan/zoom, exactly as
## the actor and lighting layers are, so landmark sprites share the town's
## cell-to-pixel space.
func _sync_surface_landmark_transform() -> void:
	if _surface_landmark_layer == null or not is_instance_valid(_surface_landmark_layer):
		return
	_surface_landmark_layer.scale = city_layer.scale
	_surface_landmark_layer.position = city_layer.position

func _ensure_surface_landmark_layer() -> void:
	if _surface_landmark_layer != null and is_instance_valid(_surface_landmark_layer):
		return
	_surface_landmark_layer = Node2D.new()
	_surface_landmark_layer.name = "SurfaceLandmarkLayer"
	# Above ground tiles and decor, below the actor sprites (z 9-11) so the
	# player and creatures pass in front of the scenery.
	_surface_landmark_layer.z_index = 3
	var landmark_parent: Node = decor_layer.get_parent() if decor_layer != null and decor_layer.get_parent() != null else self
	landmark_parent.add_child(_surface_landmark_layer)
	_sync_surface_landmark_transform()

## --- Ambient landmark footprints ------------------------------------------
## Every ambient gazetteer site inside the window becomes a REAL place in
## the wilds: buildings with timber walls and furnished interiors, camps
## with tents around a fire, or a blocking prop. Footprints are planned
## deterministically (world seed + site tile) and stamped chunk-slice by
## chunk-slice as the terrain streams, so re-streams reproduce the same
## world byte for byte.

## Building-class ambients: a walled structure with door(s), rooms via the
## shared BSP planner, and interiors dressed by furnishing theme ("house"
## uses the home template instead of a shop theme).
const AMBIENT_BUILDING_RECIPES := {
	"cathedral": {"w": 11, "h": 9, "rooms": 3, "dress": "temple"},
	"temple": {"w": 8, "h": 7, "rooms": 2, "dress": "temple"},
	"monastery": {"w": 9, "h": 7, "rooms": 2, "dress": "temple"},
	"chapel": {"w": 7, "h": 6, "rooms": 2, "dress": "chapel"},
	"castle": {"w": 10, "h": 8, "rooms": 3, "dress": "guardhouse"},
	"hunting_lodge": {"w": 6, "h": 5, "rooms": 1, "dress": "tavern"},
	"roadsideTavern": {"w": 7, "h": 6, "rooms": 2, "dress": "tavern"},
	"homestead": {"w": 6, "h": 5, "rooms": 1, "dress": "house"},
	"farmhouse": {"w": 6, "h": 5, "rooms": 1, "dress": "house"},
	"farm": {"w": 6, "h": 5, "rooms": 1, "dress": "house"},
	"desert_hut": {"w": 5, "h": 4, "rooms": 1, "dress": "house"},
	"hermit_hut": {"w": 5, "h": 4, "rooms": 1, "dress": "apothecary"},
	"watchtower": {"w": 5, "h": 5, "rooms": 1, "dress": "guardhouse"},
	"orc_watchtower": {"w": 5, "h": 5, "rooms": 1, "dress": "guardhouse"},
	"lumber_mill": {"w": 6, "h": 5, "rooms": 1, "dress": "carpenter"}
}

## Camp-class ambients: a dirt clearing, campfire with a warm glow, tents
## (overworld tent art, grounded and blocking), crates and racks. "war"
## camps add weapon racks; "pyre" swaps the fire bowl for the burning-pyre
## art with a bigger glow.
const AMBIENT_CAMP_RECIPES := {
	"tent_camp": {"tents": 4},
	"wanderer_camp": {"tents": 4},
	"travelerCamp": {"tents": 4},
	"centaur_camp": {"tents": 4},
	"centaurEncampment": {"tents": 4},
	"prospect_camp": {"tents": 3},
	"revel_camp": {"tents": 3},
	"war_camp": {"tents": 5, "war": true},
	"orc_camp": {"tents": 5, "war": true},
	"orcCamp": {"tents": 5, "war": true},
	"gnollCamp": {"tents": 4, "war": true},
	"trollCamp": {"tents": 3, "war": true},
	"ogreCamp": {"tents": 3, "war": true},
	"banditCamp": {"tents": 4, "war": true},
	"raider_camp": {"tents": 4, "war": true},
	"thorn_camp": {"tents": 3, "war": true},
	"war_banner": {"tents": 3, "war": true},
	"gnoll_den": {"tents": 3, "war": true},
	"ogre_den": {"tents": 2, "war": true},
	"war_pyre": {"tents": 2, "war": true, "pyre": true}
}

## Prop-class ambients rendered from town tileset art; anything not listed
## in one of the recipe tables keeps its overworld icon, now grounded as a
## blocking 1-cell prop.
const AMBIENT_PROP_RECIPES := {
	"moonwell": {"prop": "well"},
	"great_tree": {"prop": "grand_icon"},
	"old_growth": {"prop": "grove"}
}

## Hostile bands garrisoning war-class camps: camp structure id -> pool of
## UndergroundCreatureService def indices whose art best fits the camp's
## owner (orcs for orc/war camps, the swift lizardmen standing in for
## gnoll and bandit packs, warlords for the troll/ogre dens).
const AMBIENT_CAMP_HOSTILES := {
	"war_camp": [6, 6, 7],
	"orc_camp": [6, 6, 7], "orcCamp": [6, 6, 7],
	"gnollCamp": [3, 3, 4], "gnoll_den": [3, 4, 4],
	"trollCamp": [5, 7], "ogreCamp": [7, 7], "ogre_den": [7, 7],
	"banditCamp": [3, 4, 6], "raider_camp": [4, 6, 6],
	"thorn_camp": [3, 4, 5], "war_banner": [6, 7], "war_pyre": [6, 7, 7]
}

## Keepers of the friendly wilds buildings: structure id -> the professions
## living there. Each entry becomes one named NPC with a full identity.
const AMBIENT_KEEPER_ROSTER := {
	"hermit_hut": ["Hermit"],
	"chapel": ["Priest"], "temple": ["Priest"], "monastery": ["Priest"],
	"cathedral": ["Priest", "Acolyte"],
	"hunting_lodge": ["Hunter"],
	"homestead": ["Settler", "Settler"],
	"farmhouse": ["Settler", "Settler"],
	"farm": ["Settler", "Settler"],
	"watchtower": ["Watchman"],
	"lumber_mill": ["Woodcutter"]
}

## Which existing stock pool a trading keeper opens: the hermit deals in
## herbs and remedies, the hunter in cured meats, hides and provisions.
const AMBIENT_KEEPER_STOCK := {"Hermit": "apothecary", "Hunter": "market_stall"}

## Spoils rifled from a cleared war camp's tents: arms and armor fittings.
const AMBIENT_CAMP_SPOILS: Array[String] = ["Forged Blade", "Iron Ingot", "Whetstone", "Leather Strap"]

const AMBIENT_KEEPER_WANDER_RADIUS := 3
const AMBIENT_KEEPER_STEP_SPEED := 30.0

## Legacy-save fallback: older worlds persisted only the icon's atlas
## coords, so map them back to a representative structure id. (3,1) is
## shared by the mine icon and the mountain homestead; both read fine as
## a small homestead building.
const AMBIENT_ID_BY_ATLAS := {
	Vector2i(10, 1): "chapel", Vector2i(9, 1): "temple", Vector2i(11, 0): "cathedral",
	Vector2i(2, 2): "monastery", Vector2i(6, 4): "castle", Vector2i(16, 0): "hunting_lodge",
	Vector2i(12, 1): "roadsideTavern", Vector2i(13, 1): "homestead", Vector2i(3, 1): "homestead",
	Vector2i(4, 5): "farmhouse", Vector2i(15, 1): "farm", Vector2i(0, 4): "hermit_hut",
	Vector2i(3, 4): "watchtower", Vector2i(17, 2): "orc_watchtower", Vector2i(9, 6): "desert_hut",
	Vector2i(0, 6): "lumber_mill",
	Vector2i(1, 5): "tent_camp", Vector2i(11, 3): "war_camp", Vector2i(10, 2): "centaur_camp",
	Vector2i(16, 2): "war_banner", Vector2i(15, 2): "thorn_camp", Vector2i(7, 1): "prospect_camp",
	Vector2i(13, 3): "war_pyre", Vector2i(5, 1): "ogre_den",
	Vector2i(2, 6): "moonwell", Vector2i(14, 1): "great_tree", Vector2i(0, 2): "old_growth"
}

const AMBIENT_TENT_ICON := Vector2i(1, 5)
const AMBIENT_PYRE_ICON := Vector2i(13, 3)
const AMBIENT_GLOW_WARM := Color(1.0, 0.72, 0.35, 1.0)
const AMBIENT_GLOW_MOON := Color(0.45, 0.72, 1.0, 1.0)

## Stamps every landmark slice that falls inside the freshly streamed
## chunk. Plans are computed lazily on first contact; a plan that fails
## (waterlogged site) leaves the landmark as a non-blocking icon.
func _stamp_landmarks_in_chunk(chunk: Vector2i, chunk_rect: Rect2i) -> void:
	for landmark: Dictionary in _surface_landmarks:
		if not chunk_rect.intersects(landmark.get("rect", Rect2i()) as Rect2i):
			continue
		var stamped_chunks := landmark.get("stamped_chunks", {}) as Dictionary
		if stamped_chunks.has(chunk):
			continue
		var plan := landmark.get("plan", {}) as Dictionary
		if plan.is_empty():
			plan = _plan_landmark_footprint(landmark)
			landmark["plan"] = plan
			landmark["rect"] = plan.get("bounds", landmark.get("rect", Rect2i())) as Rect2i
		_apply_landmark_plan_slice(landmark, plan, chunk, chunk_rect)
		stamped_chunks[chunk] = true
		_maybe_spawn_landmark_inhabitants(landmark, plan, chunk_rect)

## Applies the slice of a footprint plan inside one chunk: ground/decor
## tiles, blocked-cell registration, and the sprites (furniture pieces,
## glows, icon art, name label) anchored in this chunk.
func _apply_landmark_plan_slice(landmark: Dictionary, plan: Dictionary, chunk: Vector2i, chunk_rect: Rect2i) -> void:
	var site_key := String(landmark.get("key", ""))
	var ground := plan.get("ground", {}) as Dictionary
	for cell_variant: Variant in ground.keys():
		var cell := cell_variant as Vector2i
		if not chunk_rect.has_point(cell) or _latest_grid.has(cell):
			continue
		var ground_key := String(ground[cell])
		# "hold:" keys come from the hold's own tilesheet (a dwarfhold
		# city's floors, walls and doors) and take no danger shading.
		if ground_key.begins_with("hold:"):
			_place_hold_tile(city_layer, cell, ground_key.substr(5))
			continue
		# Stamps wear the same danger gloom as the terrain around them, so
		# a deep-wild chapel doesn't sit on an artificially sunlit square.
		_place_surface_tile(city_layer, cell, ground_key, SurfaceLifeService.danger_for_cell(cell, _surface_anchor_cells))
	var decor := plan.get("decor", {}) as Dictionary
	for cell_variant: Variant in decor.keys():
		var cell := cell_variant as Vector2i
		if not chunk_rect.has_point(cell) or _latest_grid.has(cell):
			continue
		var decor_key := String(decor[cell])
		if decor_key.is_empty():
			decor_layer.erase_cell(cell)
		else:
			_place_surface_tile(decor_layer, cell, decor_key, SurfaceLifeService.danger_for_cell(cell, _surface_anchor_cells))
			# A stamped strongbox opens through the shared chest panel.
			if decor_key == "chest":
				_ensure_chest_inventory(cell)
		_actor_passable_cache.erase(cell)
	var blocked := plan.get("blocked", {}) as Dictionary
	for cell_variant: Variant in blocked.keys():
		var cell := cell_variant as Vector2i
		if not chunk_rect.has_point(cell):
			continue
		_surface_landmark_blocked_cells[cell] = site_key
		_actor_passable_cache.erase(cell)
	var nodes: Array = []
	for sprite_variant: Variant in plan.get("sprites", []) as Array:
		var sprite_def := sprite_variant as Dictionary
		var cell := sprite_def.get("cell", Vector2i.ZERO) as Vector2i
		if not chunk_rect.has_point(cell):
			continue
		match String(sprite_def.get("type", "")):
			"piece":
				var piece_sprite: Sprite2D = RoomFurnishingService.create_piece_sprite(String(sprite_def.get("piece", "")), cell, tile_size)
				if piece_sprite != null:
					decor_layer.add_child(piece_sprite)
					nodes.append(piece_sprite)
			"glow":
				var glow_sprite: Sprite2D = RoomFurnishingService.create_glow_sprite(
					_cell_center_position(cell),
					float(sprite_def.get("radius", 2.5)) * float(tile_size.x),
					sprite_def.get("color", AMBIENT_GLOW_WARM) as Color)
				glow_sprite.visible = _lighting_enabled
				actor_layer.add_child(glow_sprite)
				# Firelight breathes: a slow scale pulse, phase-varied per
				# cell so neighboring glows never throb in unison.
				var glow_base_scale := glow_sprite.scale
				var glow_period := 0.5 + float(absi(cell.x * 31 + cell.y * 17) % 40) * 0.01
				var glow_pulse := glow_sprite.create_tween().set_loops()
				glow_pulse.tween_property(glow_sprite, "scale", glow_base_scale * 1.12, glow_period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				glow_pulse.tween_property(glow_sprite, "scale", glow_base_scale, glow_period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				_glow_sprites.append(glow_sprite)
				nodes.append(glow_sprite)
			"icon":
				var icon_sprite := _create_landmark_icon_sprite(
					sprite_def.get("atlas", Vector2i.ZERO) as Vector2i,
					cell, float(sprite_def.get("scale", 1.5)))
				if icon_sprite != null:
					nodes.append(icon_sprite)
			"label":
				var name_label := Label.new()
				name_label.text = String(landmark.get("name", ""))
				name_label.add_theme_font_size_override("font_size", 15)
				name_label.add_theme_color_override("font_color", Color(0.92, 0.9, 0.78, 1.0))
				name_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06, 1.0))
				name_label.add_theme_constant_override("outline_size", 4)
				name_label.position = city_layer.map_to_local(cell)
				name_label.z_index = 30
				city_layer.add_child(name_label)
				nodes.append(name_label)
	if not nodes.is_empty():
		var nodes_by_chunk := landmark.get("nodes_by_chunk", {}) as Dictionary
		var chunk_nodes := nodes_by_chunk.get(chunk, []) as Array
		chunk_nodes.append_array(nodes)
		nodes_by_chunk[chunk] = chunk_nodes
	# A hold city's slice may have just re-stoned cells the player once
	# dug through; the persisted galleries re-open with their chunk.
	if String(plan.get("kind", "")) == "dwarfhold_city":
		_apply_ward_digs(site_key, chunk_rect)

## The grounded overworld-icon sprite (the pre-footprint landmark look),
## bottom-anchored on its cell so the art "sits" on the ground.
func _create_landmark_icon_sprite(atlas_coords: Vector2i, cell: Vector2i, icon_scale: float) -> Sprite2D:
	_ensure_surface_landmark_layer()
	if _surface_landmark_layer == null:
		return null
	if _surface_landmark_atlas_texture == null:
		_surface_landmark_atlas_texture = load(TILE_ATLAS_DEFS.ATLAS_TEXTURE) as Texture2D
	if _surface_landmark_atlas_texture == null:
		return null
	var sprite := Sprite2D.new()
	sprite.texture = _surface_landmark_atlas_texture
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2(atlas_coords) * 32.0, Vector2(32.0, 32.0))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	var landmark_scale := float(tile_size.x) * icon_scale / 32.0
	sprite.scale = Vector2.ONE * landmark_scale
	var span := 32.0 * landmark_scale
	var center := _cell_center_position(cell)
	sprite.position = Vector2(center.x - span * 0.5, center.y + float(tile_size.y) * 0.5 - span)
	_surface_landmark_layer.add_child(sprite)
	return sprite

## Frees one chunk's slice of a stamped landmark (its sprites and blocked
## cells); the ground tiles are erased by the chunk evictor itself via the
## painted-cell list. The plan is kept - re-streaming replays it verbatim.
func _unstamp_surface_landmark_chunk(landmark: Dictionary, chunk: Vector2i, chunk_rect: Rect2i) -> void:
	# Inhabitants live and die with the anchor's chunk: its eviction frees
	# their sprites and states; re-streaming it spawns them anew (unless the
	# camp was cleared this visit).
	var plan := landmark.get("plan", {}) as Dictionary
	if plan.has("anchor") and chunk_rect.has_point(plan.get("anchor", Vector2i.ZERO) as Vector2i):
		_free_landmark_inhabitants(landmark)
	var nodes_by_chunk := landmark.get("nodes_by_chunk", {}) as Dictionary
	for node_variant: Variant in nodes_by_chunk.get(chunk, []) as Array:
		var node := node_variant as Node
		if node != null and is_instance_valid(node):
			if node is Node2D:
				_glow_sprites.erase(node as Node2D)
			node.queue_free()
	nodes_by_chunk.erase(chunk)
	var site_key := String(landmark.get("key", ""))
	var blocked := (landmark.get("plan", {}) as Dictionary).get("blocked", {}) as Dictionary
	for cell_variant: Variant in blocked.keys():
		var cell := cell_variant as Vector2i
		if not chunk_rect.has_point(cell):
			continue
		if String(_surface_landmark_blocked_cells.get(cell, "")) == site_key:
			_surface_landmark_blocked_cells.erase(cell)
			_actor_passable_cache.erase(cell)
	(landmark.get("stamped_chunks", {}) as Dictionary).erase(chunk)

## Full teardown of a landmark's spawned state (window exit or rebuild):
## every chunk's nodes and every blocked cell it registered.
func _unstamp_surface_landmark_nodes(landmark: Dictionary) -> void:
	_free_landmark_inhabitants(landmark)
	var nodes_by_chunk := landmark.get("nodes_by_chunk", {}) as Dictionary
	for chunk_variant: Variant in nodes_by_chunk.keys():
		for node_variant: Variant in nodes_by_chunk.get(chunk_variant, []) as Array:
			var node := node_variant as Node
			if node != null and is_instance_valid(node):
				if node is Node2D:
					_glow_sprites.erase(node as Node2D)
				node.queue_free()
	nodes_by_chunk.clear()
	var site_key := String(landmark.get("key", ""))
	var blocked := (landmark.get("plan", {}) as Dictionary).get("blocked", {}) as Dictionary
	for cell_variant: Variant in blocked.keys():
		var cell := cell_variant as Vector2i
		if String(_surface_landmark_blocked_cells.get(cell, "")) == site_key:
			_surface_landmark_blocked_cells.erase(cell)
			_actor_passable_cache.erase(cell)
	(landmark.get("stamped_chunks", {}) as Dictionary).clear()

## --- Site inhabitants --------------------------------------------------------
## The wilds' stage sets get their cast: war-class camps garrison a hostile
## band from the surface creature pipeline, friendly buildings house their
## keeper(s) with full identities. Everything rolls deterministically from
## world seed + site tile, spawns when the chunk holding the site's anchor
## streams in, and is freed when that chunk evicts.

## Spawns a landmark's inhabitants the moment its anchor cell streams in.
## Camps wiped out this visit stay quiet until scene re-entry.
func _maybe_spawn_landmark_inhabitants(landmark: Dictionary, plan: Dictionary, chunk_rect: Rect2i) -> void:
	if bool(landmark.get("inhabited", false)) or not bool(plan.get("ok", false)):
		return
	if not plan.has("anchor"):
		return
	var anchor := plan.get("anchor", Vector2i.ZERO) as Vector2i
	if not chunk_rect.has_point(anchor):
		return
	var structure_id := String(landmark.get("structure", ""))
	# A chronicle beast's lair outranks any camp or keeper roster: the
	# named boss spawns with the site's chunk, exactly like a garrison.
	var lair_beast: Dictionary = WorldChronicleService.lair_beast_for_tile(
		_world_settings_snapshot(), landmark.get("tile", Vector2i.ZERO) as Vector2i
	)
	if not lair_beast.is_empty():
		landmark["inhabited"] = true
		_spawn_surface_lair_boss(landmark, plan, lair_beast)
		return
	if AMBIENT_CAMP_HOSTILES.has(structure_id):
		landmark["inhabited"] = true
		if not _camp_cleared_sites.has(String(landmark.get("key", ""))):
			_spawn_camp_hostiles(landmark, plan, structure_id)
	elif AMBIENT_KEEPER_ROSTER.has(structure_id):
		landmark["inhabited"] = true
		_spawn_site_keepers(landmark, plan, structure_id)

## Open ground to stand on inside a footprint: plan cells in the anchor's
## own chunk (the one whose streaming triggered the spawn, so the pick is
## independent of which neighbor chunks happen to be in), unblocked and
## walkable, shuffled by the site's seeded rng.
func _landmark_spawn_cells(plan: Dictionary, rng: RandomNumberGenerator, count: int) -> Array[Vector2i]:
	var anchor := plan.get("anchor", Vector2i.ZERO) as Vector2i
	var anchor_chunk_rect: Rect2i = SurfaceWorldService.chunk_rect(SurfaceWorldService.chunk_for_cell(anchor))
	var blocked := plan.get("blocked", {}) as Dictionary
	var open_cells: Array[Vector2i] = []
	for cell_variant: Variant in (plan.get("ground", {}) as Dictionary).keys():
		var cell := cell_variant as Vector2i
		if cell == anchor or blocked.has(cell) or not anchor_chunk_rect.has_point(cell):
			continue
		if not _is_walkable_cell(cell) or _is_cell_occupied_by_npc(cell):
			continue
		open_cells.append(cell)
	# Dictionary key order is not contractual; sort before the seeded
	# shuffle so the same site always seats its folk on the same cells.
	open_cells.sort()
	_seeded_shuffle_with(open_cells, rng)
	if open_cells.size() > count:
		open_cells.resize(count)
	return open_cells

## A war camp's garrison: 2-4 hostiles from the camp's def pool, leashed to
## the fire, run by the same AI/combat/loot pipeline as every wild creature.
func _spawn_camp_hostiles(landmark: Dictionary, plan: Dictionary, structure_id: String) -> void:
	var site_key := String(landmark.get("key", ""))
	var tile := landmark.get("tile", Vector2i.ZERO) as Vector2i
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|garrison|%d,%d" % [_surface_world_seed_text, tile.x, tile.y])
	var pool := AMBIENT_CAMP_HOSTILES.get(structure_id, []) as Array
	if pool.is_empty():
		return
	var band_size := rng.randi_range(2, 4)
	var anchor := plan.get("anchor", Vector2i.ZERO) as Vector2i
	for cell: Vector2i in _landmark_spawn_cells(plan, rng, band_size):
		var def_index := int(pool[rng.randi_range(0, pool.size() - 1)])
		var size_before := _surface_creatures.size()
		SurfaceLifeService.spawn_creature(
			_surface_creatures, SURFACE_CREATURE_TEXTURE, def_index,
			cell, actor_layer, Callable(self, "_cell_center_position"), tile_size, rng, true
		)
		if _surface_creatures.size() > size_before:
			var creature := _surface_creatures[_surface_creatures.size() - 1]
			creature["site_key"] = site_key
			creature["home_cell"] = anchor

## The named beast at its surface lair (a sleeping-dragon perch, a cave
## mouth, a den): one boss-statted creature from the same surface pipeline,
## grown and tinted into the chronicle's beast, name overhead, leashed to
## the lair like a camp garrison. Never spawns once the beast is dead.
func _spawn_surface_lair_boss(landmark: Dictionary, plan: Dictionary, lair_beast: Dictionary) -> void:
	var site_key := String(landmark.get("key", ""))
	var tile := landmark.get("tile", Vector2i.ZERO) as Vector2i
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|lair|%d,%d" % [_surface_world_seed_text, tile.x, tile.y])
	var spec: Dictionary = UndergroundCreatureService.boss_spec_for_kind(String(lair_beast.get("kind", "dragon")))
	var anchor := plan.get("anchor", Vector2i.ZERO) as Vector2i
	var cells: Array[Vector2i] = _landmark_spawn_cells(plan, rng, 1)
	var boss_cell := anchor + Vector2i(0, 2)
	if not cells.is_empty():
		boss_cell = cells[0]
	else:
		# Icon-plan lairs have no planned ground; take the nearest open
		# cell beside the lair art instead.
		for probe_offset: Vector2i in [
			Vector2i(0, 2), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, -2),
			Vector2i(2, 2), Vector2i(-2, 2), Vector2i(2, -2), Vector2i(-2, -2), Vector2i(0, 3)
		]:
			if _is_walkable_cell(anchor + probe_offset) and not _is_cell_occupied_by_npc(anchor + probe_offset):
				boss_cell = anchor + probe_offset
				break
	var size_before := _surface_creatures.size()
	SurfaceLifeService.spawn_creature(
		_surface_creatures, SURFACE_CREATURE_TEXTURE, int(spec.get("def_index", 7)),
		boss_cell, actor_layer, Callable(self, "_cell_center_position"), tile_size, rng, true
	)
	if _surface_creatures.size() <= size_before:
		return
	var boss := _surface_creatures[_surface_creatures.size() - 1]
	var display := String(lair_beast.get("display", "a nameless beast"))
	boss["site_key"] = site_key
	boss["home_cell"] = anchor
	boss["boss"] = true
	boss["beast_name"] = String(lair_beast.get("name", ""))
	boss["beast_display"] = display
	boss["beast_kind"] = String(lair_beast.get("kind", "dragon"))
	boss["lair_name"] = String(lair_beast.get("lair_name", ""))
	boss["hp"] = int(spec.get("max_hp", 200))
	boss["damage_override"] = int(spec.get("damage", 8))
	boss["aggro_override"] = int(spec.get("aggro_range", 12))
	boss["cooldown_override"] = float(spec.get("attack_cooldown", 1.5))
	boss["leash_override"] = 6
	var sprite := boss.get("sprite") as Sprite2D
	if sprite != null:
		UndergroundCreatureService.apply_boss_visuals(sprite, spec, WorldChronicleService._capitalize_first(display))
	_set_save_status("Something vast stirs at its lair — %s is here." % display, Color(1.0, 0.55, 0.45, 1.0))

## The world remembers a surface kill exactly like a hold kill: trophy,
## hoard, the persistent register, and the stored chronicle's new event.
func _award_surface_lair_kill(state: Dictionary) -> void:
	var spec: Dictionary = UndergroundCreatureService.boss_spec_for_kind(String(state.get("beast_kind", "dragon")))
	var coins := _rng.randi_range(int(spec.get("coins_min", 120)), int(spec.get("coins_max", 200)))
	_adjust_coins(coins)
	var trophy := WorldChronicleService.beast_trophy_name({
		"name": String(state.get("beast_name", "Beast")),
		"kind": String(state.get("beast_kind", "dragon"))
	})
	_add_to_inventory(trophy, 1)
	GameAudioService.play_sfx(self, "coin")
	var player_name := "A wanderer"
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null and game_session.has_method("get_player_character"):
		var character: Dictionary = game_session.call("get_player_character")
		var character_name := String(character.get("name", "")).strip_edges()
		if not character_name.is_empty():
			player_name = character_name
	var place := String(state.get("lair_name", "")).strip_edges()
	if place.is_empty():
		place = "its lair"
	var kill_year := GameCalendar.year_for_day(_game_day - 1, _calendar_start_year)
	var settings: Dictionary = _world_settings_snapshot()
	WorldChronicleService.record_player_beast_kill(settings, String(state.get("beast_name", "")), player_name, place, kill_year)
	_store_world_settings(settings)
	_set_save_status(
		"%s is slain! You claim %s and %d coins — the world will remember this." % [
			WorldChronicleService._capitalize_first(String(state.get("beast_display", "the beast"))), trophy, coins
		],
		Color(1.0, 0.85, 0.45, 1.0)
	)

## A friendly building's keeper(s): named, composed townsfolk sprites with
## identities seeded from world seed + site tile, so the same hermit greets
## every visit. Keepers anchor to their site and never join town schedules.
func _spawn_site_keepers(landmark: Dictionary, plan: Dictionary, structure_id: String) -> void:
	var site_key := String(landmark.get("key", ""))
	var tile := landmark.get("tile", Vector2i.ZERO) as Vector2i
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|keeper|%d,%d" % [_surface_world_seed_text, tile.x, tile.y])
	var roster := AMBIENT_KEEPER_ROSTER.get(structure_id, []) as Array
	var cells := _landmark_spawn_cells(plan, rng, roster.size())
	for keeper_index in range(mini(roster.size(), cells.size())):
		var profession := String(roster[keeper_index])
		var identity: Dictionary = NpcIdentityService.generate(rng, profession, "human")
		var layers: Dictionary = NpcIdentityService.appearance_for_identity(identity, "human")
		var sprite := Sprite2D.new()
		sprite.texture = DwarfSpriteComposer.compose(layers)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(float(tile_size.x) / 32.0, float(tile_size.y) / 32.0) * float(layers.get("body_scale", 1.0))
		sprite.z_index = 11
		var cell := cells[keeper_index]
		sprite.position = _cell_center_position(cell)
		actor_layer.add_child(sprite)
		_npc_states.append({
			"wilds_keeper": true,
			"site_key": site_key,
			"role": ROLE_VILLAGER,
			"identity": identity,
			"npc_name": String(identity.get("name", "A keeper")),
			"composed": true,
			"cell": cell,
			"sprite": sprite,
			"home_cell": cell,
			"work_cell": plan.get("anchor", cell) as Vector2i,
			"wander_timer": rng.randf_range(1.0, 3.0),
			# Synthetic far-away stock anchor, unique and stable per keeper,
			# for the traveler-style trade popup.
			"shop_anchor": Vector2i(3000000 + tile.x * 8 + keeper_index, tile.y)
		})

## Frees every creature and keeper belonging to a site (chunk eviction,
## window exit, or full rebuild). Live garrisons return on re-stream.
func _free_landmark_inhabitants(landmark: Dictionary) -> void:
	if not bool(landmark.get("inhabited", false)):
		return
	landmark["inhabited"] = false
	var site_key := String(landmark.get("key", ""))
	for index in range(_surface_creatures.size() - 1, -1, -1):
		if String(_surface_creatures[index].get("site_key", "")) != site_key:
			continue
		var creature_sprite := _surface_creatures[index].get("sprite") as Sprite2D
		if creature_sprite != null:
			creature_sprite.queue_free()
		_surface_creatures.remove_at(index)
	for index in range(_npc_states.size() - 1, -1, -1):
		if String(_npc_states[index].get("site_key", "")) != site_key:
			continue
		var keeper_sprite := _npc_states[index].get("sprite") as Sprite2D
		if keeper_sprite != null:
			keeper_sprite.queue_free()
		_npc_states.remove_at(index)

## When the last of a camp's band falls this visit, the site is cleared:
## the tents give up their plunder (war camps hoard arms) and the camp
## stays quiet until the scene is re-entered.
func _note_camp_creature_down(site_key: String) -> void:
	for creature: Dictionary in _surface_creatures:
		if String(creature.get("site_key", "")) == site_key:
			return
	_camp_cleared_sites[site_key] = true
	var plunder := 8 + _rng.randi_range(0, 12)
	_adjust_coins(plunder)
	var spoil := AMBIENT_CAMP_SPOILS[_rng.randi_range(0, AMBIENT_CAMP_SPOILS.size() - 1)]
	_add_to_inventory(spoil, 1)
	GameAudioService.play_sfx(self, "coin")
	_set_save_status("Camp cleared! You plunder %d coins and a %s from the tents." % [plunder, spoil], Color(0.7, 0.95, 0.7, 1.0))

## Keepers idle around their doorstep: a short wander leashed to the home
## cell, never following the town scheduler and never leaving the site.
func _update_wilds_keepers(delta: float) -> void:
	for state: Dictionary in _npc_states:
		if not bool(state.get("wilds_keeper", false)):
			continue
		var sprite := state.get("sprite") as Sprite2D
		if sprite == null:
			continue
		state["wander_timer"] = float(state.get("wander_timer", 0.0)) - delta
		if float(state.get("wander_timer", 0.0)) <= 0.0:
			state["wander_timer"] = _rng.randf_range(2.0, 5.0)
			var home := state.get("home_cell", state.get("cell", Vector2i.ZERO)) as Vector2i
			var cell := state.get("cell", home) as Vector2i
			var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
			var step := directions[_rng.randi_range(0, 3)]
			var target := cell + step
			if maxi(absi(target.x - home.x), absi(target.y - home.y)) <= AMBIENT_KEEPER_WANDER_RADIUS \
					and _is_walkable_cell(target) and not _is_cell_occupied_by_npc(target) \
					and target != _player_cell and _surface_creature_index_at_cell(target) < 0:
				state["cell"] = target
				sprite.flip_h = step.x < 0
		var target_position := _cell_center_position(state.get("cell", Vector2i.ZERO) as Vector2i)
		sprite.position = sprite.position.move_toward(target_position, AMBIENT_KEEPER_STEP_SPEED * delta)

## Hermits and hunters trade from their doorstep, traveler-style: a
## synthetic stock anchor keyed to the site, stock rolled once per scene
## from the keeper's own name, leash measured from where they stand.
func _try_open_keeper_trade(state: Dictionary) -> bool:
	var profession := String((state.get("identity", {}) as Dictionary).get("profession", ""))
	if not AMBIENT_KEEPER_STOCK.has(profession):
		return false
	var stock_type := String(AMBIENT_KEEPER_STOCK[profession])
	var anchor := state.get("shop_anchor", Vector2i(3000001, 0)) as Vector2i
	if not _shop_stocks.has(anchor):
		var stock_rng := RandomNumberGenerator.new()
		stock_rng.seed = hash(String((state.get("identity", {}) as Dictionary).get("name", "keeper")))
		_shop_stocks[anchor] = SettlementEconomyService.generate_shop_stock(stock_type, stock_rng)
	_selected_chest_cell = Vector2i(2147483647, 2147483647)
	_trade_shop_cell = anchor
	# The leash measures from where the keeper stands, not the synthetic
	# far-away stock anchor, so a single step can't slam the popup shut.
	_trade_leash_cell = state.get("cell", _player_cell) as Vector2i
	_trade_shop_type = stock_type
	chest_popup.visible = true
	chest_popup_title.text = "Trade — %s" % String(state.get("npc_name", "A keeper"))
	chest_popup_take_all_button.disabled = true
	var section_label := chest_popup.find_child("ChestSectionLabel", true, false) as Label
	if section_label != null:
		section_label.text = _with_market_hint("Wares on offer")
	_refresh_trade_panel()
	return true

## --- Footprint planning ----------------------------------------------------

## The footprint's RNG is seeded from world seed + site tile alone, so the
## same site plans the same footprint on every visit, walk order be damned.
func _landmark_rng(tile: Vector2i) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|ambient|%d,%d" % [_surface_world_seed_text, tile.x, tile.y])
	return rng

## The deterministic terrain base key at a wilds cell, ignoring danger
## shading (water and ground family don't depend on it).
func _landmark_terrain_base(cell: Vector2i) -> String:
	var terrain: Dictionary = SurfaceWorldService.terrain_for_cell(cell + _surface_world_origin, _surface_noise, 0.0, _surface_biome_ctx)
	return String(terrain.get("base", "grass"))

func _landmark_rect_is_wet(rect: Rect2i) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if _landmark_terrain_base(Vector2i(x, y)).begins_with("water"):
				return true
	return false

## Never stamp onto water: nudge the footprint to the nearest dry spot
## within a few cells, or report failure so the site stays an icon.
func _landmark_dry_anchor(anchor: Vector2i, half_extent: Vector2i) -> Vector2i:
	for radius in range(0, 7):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var candidate := anchor + Vector2i(dx, dy)
				var rect := Rect2i(candidate - half_extent, half_extent * 2 + Vector2i.ONE)
				if _surface_protect_rect.has_area() and rect.intersects(_surface_protect_rect):
					continue
				if not _landmark_rect_is_wet(rect):
					return candidate
	return Vector2i(2147483647, 2147483647)

## Which open-ground palette the clearing around a footprint wears, from
## the terrain family at its anchor: snow sites clear to snowfield, desert
## ones to sand, everything else to meadow grass.
func _landmark_ground_family(anchor: Vector2i) -> String:
	var family := TownTileService.terrain_family_for_tile_key(_landmark_terrain_base(anchor))
	if family == "sand":
		return "sand"
	if family == "snow" or family == "snow_alt":
		return "snow"
	return "grass"

func _landmark_clearing_key(family: String, rng: RandomNumberGenerator) -> String:
	match family:
		"sand":
			return "sand" if rng.randf() > 0.2 else "sand_alt"
		"snow":
			return "snow" if rng.randf() > 0.2 else "snow_alt"
	if rng.randf() > 0.25:
		return "grass"
	return "grass_tuft" if rng.randf() > 0.5 else "grass_mottled"

## Dispatch: build the full deterministic footprint plan for one landmark.
## Returns {"ok": false} only when even the icon art is missing.
func _plan_landmark_footprint(landmark: Dictionary) -> Dictionary:
	var structure_id := String(landmark.get("structure", ""))
	var rng := _landmark_rng(landmark.get("tile", Vector2i.ZERO) as Vector2i)
	var plan: Dictionary = {}
	if structure_id == "dwarfhold_city":
		return _plan_dwarfhold_main_floor(landmark, rng)
	if AMBIENT_BUILDING_RECIPES.has(structure_id):
		plan = _plan_landmark_building(landmark, AMBIENT_BUILDING_RECIPES[structure_id] as Dictionary, rng)
	elif AMBIENT_CAMP_RECIPES.has(structure_id):
		plan = _plan_landmark_camp(landmark, AMBIENT_CAMP_RECIPES[structure_id] as Dictionary, rng)
	elif AMBIENT_PROP_RECIPES.has(structure_id):
		plan = _plan_landmark_prop(landmark, AMBIENT_PROP_RECIPES[structure_id] as Dictionary)
	if plan.is_empty():
		plan = _plan_landmark_icon(landmark)
	return plan

## A real building in the wilds: timber wall ring (the town wall pieces),
## interior rooms from the shared BSP planner, a door onto open ground,
## themed furnishings, and a clearing apron with a dirt doorstep.
func _plan_landmark_building(landmark: Dictionary, recipe: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var plot_size := Vector2i(int(recipe.get("w", 6)), int(recipe.get("h", 5)))
	var half := plot_size / 2
	var apron_half := half + Vector2i(2, 2)
	var anchor := _landmark_dry_anchor(landmark.get("anchor", Vector2i.ZERO) as Vector2i, apron_half)
	if anchor.x == 2147483647:
		print("[Wilds] '%s' (%s) is waterlogged; kept as icon" % [String(landmark.get("name", "")), String(landmark.get("structure", ""))])
		return {}
	var footprint := Rect2i(anchor - half, plot_size)
	var apron := footprint.grow(2)
	var zone_grid: Dictionary = {}
	for y in range(footprint.position.y, footprint.end.y):
		for x in range(footprint.position.x, footprint.end.x):
			zone_grid[Vector2i(x, y)] = CELL_BUILDING
	var door_cells: Dictionary = {}
	var rooms: Array[Rect2i] = SettlementArchitectureService.subdivide_structure(zone_grid, footprint, rng, int(recipe.get("rooms", 1)))
	SettlementArchitectureService.punch_internal_doors(zone_grid, rooms, CELL_BUILDING, door_cells, rng)
	var entrances: Array[Vector2i] = SettlementArchitectureService.punch_exterior_doors(zone_grid, footprint, CELL_BUILDING, door_cells, rng, true)
	var ground: Dictionary = {}
	var decor: Dictionary = {}
	var blocked: Dictionary = {}
	var sprites: Array = []
	var ground_family := _landmark_ground_family(anchor)
	for y in range(apron.position.y, apron.end.y):
		for x in range(apron.position.x, apron.end.x):
			var cell := Vector2i(x, y)
			if zone_grid.has(cell):
				ground[cell] = TownTileService.pick_base_tile(zone_grid, x, y, int(zone_grid[cell]), door_cells)
			else:
				ground[cell] = _landmark_clearing_key(ground_family, rng)
			# The clearing fells any streamed trees and scrub under the site.
			decor[cell] = ""
	# A short dirt doorstep from each entrance onto the open ground.
	for entrance: Vector2i in entrances:
		for direction: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
			if zone_grid.has(entrance + direction):
				continue
			for step in range(1, 4):
				var path_cell: Vector2i = entrance + direction * step
				ground[path_cell] = "road"
				decor[path_cell] = ""
			break
	# Themed interiors: each BSP room is its own zone component, dressed by
	# the same furnishing planners the village houses and shops use.
	var furnished: Dictionary = {}
	var is_occupied := func(check_cell: Vector2i) -> bool:
		return furnished.has(check_cell)
	var dress_type := String(recipe.get("dress", "house"))
	for component_variant: Variant in RoomFurnishingService.collect_zone_components(zone_grid, CELL_BUILDING):
		var component: Array[Vector2i] = []
		for cell_variant: Variant in (component_variant as Array):
			component.append(cell_variant as Vector2i)
		var placements: Array[Dictionary] = []
		if dress_type == "house":
			placements = RoomFurnishingService.plan_house_furnishing(component, is_occupied, door_cells, rng, zone_grid)
		else:
			placements = RoomFurnishingService.plan_shop_dressing(component, dress_type, is_occupied, door_cells, rng, zone_grid)
		for placement: Dictionary in placements:
			var piece_name := String(placement.get("piece", ""))
			var base_cell := placement.get("cell", Vector2i.ZERO) as Vector2i
			sprites.append({"type": "piece", "cell": base_cell, "piece": piece_name})
			if int((RoomFurnishingService.PIECES.get(piece_name, {}) as Dictionary).get("rows_block", 1)) > 0:
				for footprint_cell: Vector2i in RoomFurnishingService.footprint_cells(piece_name, base_cell):
					blocked[footprint_cell] = true
					furnished[footprint_cell] = true
			if RoomFurnishingService.piece_emits_light(piece_name):
				sprites.append({"type": "glow", "cell": base_cell, "radius": 2.4, "color": AMBIENT_GLOW_WARM})
	sprites.append({"type": "label", "cell": Vector2i(footprint.position.x, footprint.position.y - 2)})
	return {
		"ok": true, "kind": "building", "anchor": anchor,
		"ground": ground, "decor": decor, "blocked": blocked,
		"sprites": sprites, "bounds": apron.grow(1)
	}

## THE HOLD'S ENTIRE MAIN FLOOR, on the surface level, carved into the
## mountain: a great-hall plaza with the descend-stair at its heart, a
## ring gallery and four arteries, and NINE big multi-room buildings -
## palace, forge, tavern, store, barracks and homes - each subdivided by
## the shared BSP planner and dressed by the same themed furnishers the
## rest of the world uses (rugs, beds, hearths, counters). Everything
## else inside the bounds is solid minable stone, ragged at the rim so
## it blends into the mountain biome around it. Streamed chunk by chunk
## like any landmark; the gate adds darkness, sconces and dwarves.
func _plan_dwarfhold_main_floor(landmark: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var anchor := landmark.get("anchor", Vector2i.ZERO) as Vector2i
	var center := anchor + Vector2i(0, -HOLD_CITY_HALF_H)
	var rect := Rect2i(
		Vector2i(anchor.x - HOLD_CITY_HALF_W, anchor.y - HOLD_CITY_HALF_H * 2),
		Vector2i(HOLD_CITY_HALF_W * 2 + 1, HOLD_CITY_HALF_H * 2 + 1))
	var zone_grid: Dictionary = {}
	# The great hall: paved plaza around the stair down to the deeps.
	var plaza := Rect2i(center + Vector2i(-5, -3), Vector2i(11, 7))
	for y in range(plaza.position.y, plaza.end.y):
		for x in range(plaza.position.x, plaza.end.x):
			zone_grid[Vector2i(x, y)] = CELL_PLAZA
	# Arteries (3 wide) and the ring gallery (2 thick) carve the streets.
	for y in range(center.y - 10, center.y - 3):
		for x in range(center.x - 1, center.x + 2):
			zone_grid[Vector2i(x, y)] = CELL_HALL
	for y in range(center.y + 4, anchor.y + 1):
		for x in range(center.x - 1, center.x + 2):
			zone_grid[Vector2i(x, y)] = CELL_HALL
	for x in range(center.x + 6, center.x + 15):
		for y in range(center.y - 1, center.y + 2):
			zone_grid[Vector2i(x, y)] = CELL_HALL
	for x in range(center.x - 14, center.x - 5):
		for y in range(center.y - 1, center.y + 2):
			zone_grid[Vector2i(x, y)] = CELL_HALL
	for y in range(center.y - 11, center.y + 12):
		for x in range(center.x - 16, center.x + 17):
			var ring_cell := Vector2i(x, y)
			var dx := absi(x - center.x)
			var dy := absi(y - center.y)
			if (dx == 15 or dx == 16) and dy <= 11:
				zone_grid[ring_cell] = CELL_HALL
			elif (dy == 10 or dy == 11) and dx <= 16:
				zone_grid[ring_cell] = CELL_HALL
	# Nine building plots, each flush against a street so its doors have
	# somewhere to open. Palace and workshops ring the plaza; homes and
	# the barracks take the outer blocks.
	var plots: Array[Dictionary] = [
		{"rect": Rect2i(center + Vector2i(-14, -9), Vector2i(13, 6)), "type": "high_kings_palace"},
		{"rect": Rect2i(center + Vector2i(2, -9), Vector2i(13, 6)), "type": "forge"},
		{"rect": Rect2i(center + Vector2i(-14, 4), Vector2i(13, 6)), "type": "tavern"},
		{"rect": Rect2i(center + Vector2i(2, 4), Vector2i(13, 6)), "type": "general_goods_shop"},
		{"rect": Rect2i(center + Vector2i(-8, -16), Vector2i(16, 5)), "type": "barracks"},
		{"rect": Rect2i(center + Vector2i(-23, -5), Vector2i(7, 8)), "type": "house"},
		{"rect": Rect2i(center + Vector2i(17, -5), Vector2i(7, 8)), "type": "house"},
		{"rect": Rect2i(center + Vector2i(-13, 12), Vector2i(12, 5)), "type": "house"},
		{"rect": Rect2i(center + Vector2i(2, 12), Vector2i(12, 5)), "type": "house"}
	]
	var door_cells: Dictionary = {}
	for plot: Dictionary in plots:
		var plot_rect := plot.get("rect", Rect2i()) as Rect2i
		for y in range(plot_rect.position.y, plot_rect.end.y):
			for x in range(plot_rect.position.x, plot_rect.end.x):
				zone_grid[Vector2i(x, y)] = CELL_BUILDING
		var rooms: Array[Rect2i] = SettlementArchitectureService.subdivide_structure(zone_grid, plot_rect, rng, 4)
		SettlementArchitectureService.punch_internal_doors(zone_grid, rooms, CELL_BUILDING, door_cells, rng)
		SettlementArchitectureService.punch_exterior_doors(zone_grid, plot_rect, CELL_BUILDING, door_cells, rng, false)
	# Render the zones into hold tiles over a solid stone field, ragged
	# at the rim so the mountain reads as one mass with the biome.
	var ground: Dictionary = {}
	var decor: Dictionary = {}
	var blocked: Dictionary = {}
	var sprites: Array = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			var rim := mini(mini(x - rect.position.x, rect.end.x - 1 - x), mini(y - rect.position.y, rect.end.y - 1 - y))
			var zone := int(zone_grid.get(cell, CELL_ROCK))
			if zone == CELL_ROCK:
				# The rim frays by hash so the city's stone melts into
				# the range instead of ending on a hard rectangle: the
				# outermost ring keeps a third of its stone, the next
				# ring two thirds, and everything deeper is solid.
				if rim < 2 and (hash("hold_rim|%d|%d" % [cell.x, cell.y]) & 0xffff) % 3 < (2 - rim):
					continue
				var fold := hash("hold_fold|%d|%d" % [cell.x, cell.y]) & 0xffff
				var rock_key := "massif_rock"
				if fold % 9 == 0:
					rock_key = "massif_rock_top"
				elif fold % 4 == 0:
					rock_key = "massif_rock_dark"
				ground[cell] = rock_key
				decor[cell] = ""
				continue
			decor[cell] = ""
			if door_cells.has(cell):
				ground[cell] = "hold:door"
			elif zone == CELL_WALL:
				ground[cell] = "hold:wall"
			elif zone == CELL_HALL:
				var hall_fold := hash("hold_fold|%d|%d" % [cell.x, cell.y]) & 0xffff
				ground[cell] = "hold:dirt_alt" if hall_fold % 5 == 0 else "hold:dirt"
			elif zone == CELL_PLAZA:
				ground[cell] = "hold:floor"
			else:
				# CELL_BUILDING: the ring is wall, the inside is floor.
				var plot_edge := false
				for plot: Dictionary in plots:
					var plot_rect := plot.get("rect", Rect2i()) as Rect2i
					if not plot_rect.has_point(cell):
						continue
					plot_edge = x == plot_rect.position.x or y == plot_rect.position.y \
						or x == plot_rect.end.x - 1 or y == plot_rect.end.y - 1
					break
				ground[cell] = "hold:wall" if plot_edge else "hold:floor"
	ground[center] = "hold:stairway_down"
	# A closed hold bars its mouth: iron-banded slabs seal the FULL
	# width of the south artery (three columns, two rows deep) so no
	# gap remains beside the gate. The stone around it still yields to
	# a pick, so the determined tunnel their own way in.
	var gates_closed := bool(landmark.get("closed", false))
	if gates_closed:
		for seal_x in range(anchor.x - 1, anchor.x + 2):
			ground[Vector2i(seal_x, anchor.y)] = "sealed_gate"
			ground[Vector2i(seal_x, anchor.y - 1)] = "sealed_gate"
	# The hold sheet has NO "wall" tile - the old key was silently
	# skipped, leaving every building wall as unpainted (and walkable!)
	# biome ground. Walls are hold stone, showing a carved face where
	# open ground lies to their south, the same look the hold scene uses.
	for wall_variant: Variant in ground.keys():
		if String(ground[wall_variant]) != "hold:wall":
			continue
		var below := String(ground.get((wall_variant as Vector2i) + Vector2i(0, 1), ""))
		var open_below := below.begins_with("hold:") and below != "hold:wall" \
			and below != "hold:stone" and below != "hold:stone_face"
		ground[wall_variant] = "hold:stone_face" if open_below else "hold:stone"
	# Themed interiors: every BSP room is its own component, dressed by
	# the same planners the villages use; light-throwing pieces double as
	# lights for the ward's darkness shader.
	var light_cells: Array = []
	var furnished: Dictionary = {}
	var is_occupied := func(check_cell: Vector2i) -> bool:
		return furnished.has(check_cell)
	for component_variant: Variant in RoomFurnishingService.collect_zone_components(zone_grid, CELL_BUILDING):
		var component: Array[Vector2i] = []
		for cell_variant: Variant in (component_variant as Array):
			component.append(cell_variant as Vector2i)
		if component.is_empty():
			continue
		var dress_type := "house"
		for plot: Dictionary in plots:
			if (plot.get("rect", Rect2i()) as Rect2i).has_point(component[0]):
				dress_type = String(plot.get("type", "house"))
				break
		var placements: Array[Dictionary] = []
		if dress_type == "house":
			placements = RoomFurnishingService.plan_house_furnishing(component, is_occupied, door_cells, rng, zone_grid)
		else:
			placements = RoomFurnishingService.plan_shop_dressing(component, dress_type, is_occupied, door_cells, rng, zone_grid)
		for placement: Dictionary in placements:
			var piece_name := String(placement.get("piece", ""))
			var base_cell := placement.get("cell", Vector2i.ZERO) as Vector2i
			sprites.append({"type": "piece", "cell": base_cell, "piece": piece_name})
			if int((RoomFurnishingService.PIECES.get(piece_name, {}) as Dictionary).get("rows_block", 1)) > 0:
				for footprint_cell: Vector2i in RoomFurnishingService.footprint_cells(piece_name, base_cell):
					blocked[footprint_cell] = true
					furnished[footprint_cell] = true
			if RoomFurnishingService.piece_emits_light(piece_name):
				# Corona-sized: the ward shader lights the room's pool
				# (via light_cells); the sprite is the flame's own shine.
				sprites.append({"type": "glow", "cell": base_cell, "radius": 0.9, "color": AMBIENT_GLOW_WARM})
				light_cells.append(base_cell)
	# Every home keeps one lootable strongbox on a clear floor cell,
	# wired to the same chest panel the rest of the town uses.
	for plot: Dictionary in plots:
		if String(plot.get("type", "")) != "house":
			continue
		var plot_rect := plot.get("rect", Rect2i()) as Rect2i
		var chest_placed := false
		for y in range(plot_rect.position.y + 1, plot_rect.end.y - 1):
			if chest_placed:
				break
			for x in range(plot_rect.position.x + 1, plot_rect.end.x - 1):
				var chest_cell := Vector2i(x, y)
				if String(ground.get(chest_cell, "")) != "hold:floor":
					continue
				if furnished.has(chest_cell) or door_cells.has(chest_cell):
					continue
				var beside_door := false
				for offset: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
					if door_cells.has(chest_cell + offset):
						beside_door = true
						break
				if beside_door:
					continue
				decor[chest_cell] = "chest"
				furnished[chest_cell] = true
				chest_placed = true
				break
	# Sconce torches pace the streets wherever they hug stone or a wall.
	var sconce_cells: Array = []
	for cell_variant: Variant in zone_grid.keys():
		var street_cell := cell_variant as Vector2i
		var street_zone := int(zone_grid[cell_variant])
		if street_zone != CELL_HALL and street_zone != CELL_PLAZA:
			continue
		var hugs_wall := false
		for offset: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
			var neighbor_zone := int(zone_grid.get(street_cell + offset, CELL_ROCK))
			if neighbor_zone == CELL_ROCK or neighbor_zone == CELL_WALL or neighbor_zone == CELL_BUILDING:
				hugs_wall = true
				break
		if not hugs_wall:
			continue
		if (hash("ward_sconce|%d|%d" % [street_cell.x, street_cell.y]) & 0xffff) % WARD_SCONCE_SPACING != 0:
			continue
		sconce_cells.append(street_cell)
	# Dwarves walk the streets; spawn picks come from the open hall pool.
	var spawn_cells: Array = []
	for cell_variant: Variant in zone_grid.keys():
		var open_zone := int(zone_grid[cell_variant])
		if open_zone != CELL_HALL and open_zone != CELL_PLAZA:
			continue
		if (hash("ward_spawn|%d|%d" % [(cell_variant as Vector2i).x, (cell_variant as Vector2i).y]) & 0xffff) % 9 == 0:
			spawn_cells.append(cell_variant)
	return {
		"ok": true, "kind": "dwarfhold_city", "anchor": anchor,
		"ground": ground, "decor": decor, "blocked": blocked,
		"sprites": sprites, "bounds": rect.grow(1),
		"sconces": sconce_cells, "light_cells": light_cells,
		"spawn_cells": spawn_cells, "stair": center,
		# The buildings keep their trades: clicks inside a plot open the
		# matching shop counter (forge, tavern, general store).
		"plots": plots,
		"closed": gates_closed
	}

## A camp: roundish dirt clearing, campfire (or burning pyre) with a warm
## glow at its heart, tents ringing the fire, crates and racks scattered.
func _plan_landmark_camp(landmark: Dictionary, recipe: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var anchor := _landmark_dry_anchor(landmark.get("anchor", Vector2i.ZERO) as Vector2i, Vector2i(4, 4))
	if anchor.x == 2147483647:
		print("[Wilds] '%s' (%s) is waterlogged; kept as icon" % [String(landmark.get("name", "")), String(landmark.get("structure", ""))])
		return {}
	var members: Dictionary = {}
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			# Clip the square's corners so the clearing reads as a blob.
			if Vector2(dx, dy).length() > 3.4:
				continue
			members[anchor + Vector2i(dx, dy)] = true
	var ground: Dictionary = {}
	var decor: Dictionary = {}
	var blocked: Dictionary = {}
	var sprites: Array = []
	var ground_family := _landmark_ground_family(anchor)
	for cell_variant: Variant in members.keys():
		var cell := cell_variant as Vector2i
		ground[cell] = _camp_clearing_tile(cell, members, ground_family, rng)
		decor[cell] = ""
	# The fire: a brazier bowl, or the burning war-pyre art for pyre camps.
	if bool(recipe.get("pyre", false)):
		sprites.append({"type": "icon", "cell": anchor, "atlas": AMBIENT_PYRE_ICON, "scale": 1.7})
		blocked[anchor] = true
		sprites.append({"type": "glow", "cell": anchor, "radius": 4.0, "color": AMBIENT_GLOW_WARM})
	else:
		decor[anchor] = "brazier"
		sprites.append({"type": "glow", "cell": anchor, "radius": 3.0, "color": AMBIENT_GLOW_WARM})
	# Tents around the fire, from the overworld tent art, each blocking its
	# ground cell. Slots are fixed; the rng picks which stay empty.
	var tent_slots: Array[Vector2i] = [
		Vector2i(-2, -2), Vector2i(2, -2), Vector2i(-3, 1), Vector2i(3, 1),
		Vector2i(0, -3), Vector2i(-1, 2)
	]
	_seeded_shuffle_with(tent_slots, rng)
	var tent_count := clampi(int(recipe.get("tents", 3)), 0, tent_slots.size())
	for tent_index in range(tent_count):
		var tent_cell: Vector2i = anchor + tent_slots[tent_index]
		sprites.append({"type": "icon", "cell": tent_cell, "atlas": AMBIENT_TENT_ICON, "scale": 1.35})
		blocked[tent_cell] = true
	# Camp clutter: crates and sacks; war camps rack their arms.
	var clutter_pool: Array[String] = ["barrel", "barrel_open", "jug", "bucket"]
	if bool(recipe.get("war", false)):
		clutter_pool.append_array(["armor_stand", "armor_stand", "stall"])
	else:
		clutter_pool.append("stall_alt")
	var clutter_slots: Array[Vector2i] = [
		Vector2i(1, 1), Vector2i(-2, 0), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(1, 3)
	]
	for clutter_index in range(2 + rng.randi_range(0, 2)):
		if clutter_index >= clutter_slots.size():
			break
		var clutter_cell: Vector2i = anchor + clutter_slots[clutter_index]
		if blocked.has(clutter_cell) or clutter_cell == anchor:
			continue
		decor[clutter_cell] = clutter_pool[rng.randi_range(0, clutter_pool.size() - 1)]
	sprites.append({"type": "label", "cell": anchor + Vector2i(-3, -5)})
	return {
		"ok": true, "kind": "camp", "anchor": anchor,
		"ground": ground, "decor": decor, "blocked": blocked,
		"sprites": sprites, "bounds": Rect2i(anchor - Vector2i(5, 5), Vector2i(11, 11))
	}

## Dirt-clearing autotile: edge pieces where the blob meets open ground
## (grass fringe on grass, snow recolors on snow, bare dirt on sand),
## scatter variety inside.
func _camp_clearing_tile(cell: Vector2i, members: Dictionary, family: String, rng: RandomNumberGenerator) -> String:
	var scatter_roll := rng.randi_range(0, 8)
	var scatter := "road"
	if scatter_roll == 0:
		scatter = "road_twig"
	elif scatter_roll == 1:
		scatter = "road_alt"
	elif scatter_roll == 2:
		scatter = "road_stone"
	# Desert camps sit on bare dirt against sand: fringes would paint green.
	if family == "sand":
		return scatter
	var suffix_snow := "_snow" if family == "snow" else ""
	var n_open := not members.has(cell + Vector2i.UP)
	var s_open := not members.has(cell + Vector2i.DOWN)
	var w_open := not members.has(cell + Vector2i.LEFT)
	var e_open := not members.has(cell + Vector2i.RIGHT)
	if n_open and w_open:
		return "road_edge_nw%s" % suffix_snow
	if n_open and e_open:
		return "road_edge_ne%s" % suffix_snow
	if s_open and w_open:
		return "road_edge_sw%s" % suffix_snow
	if s_open and e_open:
		return "road_edge_se%s" % suffix_snow
	if n_open:
		return "road_edge_n%s" % suffix_snow
	if s_open:
		return "road_edge_s%s" % suffix_snow
	if w_open:
		return "road_edge_w%s" % suffix_snow
	if e_open:
		return "road_edge_e%s" % suffix_snow
	if not members.has(cell + Vector2i(-1, -1)):
		return "road_in_nw%s" % suffix_snow
	if not members.has(cell + Vector2i(1, -1)):
		return "road_in_ne%s" % suffix_snow
	if not members.has(cell + Vector2i(-1, 1)):
		return "road_in_sw%s" % suffix_snow
	if not members.has(cell + Vector2i(1, 1)):
		return "road_in_se%s" % suffix_snow
	return scatter

## Prop landmarks from town tileset art: the moonwell (village well on a
## dark-grass glade, moonlit glow), the great tree (full dark canopy), or
## an old-growth grove of three.
func _plan_landmark_prop(landmark: Dictionary, recipe: Dictionary) -> Dictionary:
	var prop := String(recipe.get("prop", ""))
	var anchor := _landmark_dry_anchor(landmark.get("anchor", Vector2i.ZERO) as Vector2i, Vector2i(3, 3))
	if anchor.x == 2147483647:
		print("[Wilds] '%s' (%s) is waterlogged; kept as icon" % [String(landmark.get("name", "")), String(landmark.get("structure", ""))])
		return {}
	var ground: Dictionary = {}
	var decor: Dictionary = {}
	var blocked: Dictionary = {}
	var sprites: Array = []
	var ground_family := _landmark_ground_family(anchor)
	match prop:
		"well":
			# A moonlit glade: dark grass under the well where the ground is
			# grassy at all (snow and sand glades stay their own colour).
			if ground_family == "grass":
				for dy in range(-2, 2):
					for dx in range(-2, 3):
						ground[anchor + Vector2i(dx, dy)] = "grass_dark"
			for dy in range(-2, 2):
				for dx in range(-2, 3):
					decor[anchor + Vector2i(dx, dy)] = ""
			decor[anchor] = "well_base_left"
			decor[anchor + Vector2i.RIGHT] = "well_base_right"
			decor[anchor + Vector2i.UP] = "well_roof_left"
			decor[anchor + Vector2i(1, -1)] = "well_roof_right"
			sprites.append({"type": "glow", "cell": anchor, "radius": 2.6, "color": AMBIENT_GLOW_MOON})
		"grand_icon":
			# The great tree towers over the woods: its overworld art blown
			# up to a three-cell crown on a shaded glade, base row blocked.
			if ground_family == "grass":
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						ground[anchor + Vector2i(dx, dy)] = "grass_dark"
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					decor[anchor + Vector2i(dx, dy)] = ""
			sprites.append({"type": "icon", "cell": anchor, "atlas": landmark.get("tile_atlas", Vector2i.ZERO) as Vector2i, "scale": 3.0})
			blocked[anchor] = true
			blocked[anchor + Vector2i.LEFT] = true
			blocked[anchor + Vector2i.RIGHT] = true
		"grove":
			# Grove sentinels on snow ground wear the snow-capped variant.
			var grove_tree := "tree_dark_snowy" if ground_family.begins_with("snow") else "tree_dark"
			for offset: Vector2i in [Vector2i.ZERO, Vector2i(-3, 2), Vector2i(3, 2)]:
				decor[anchor + offset] = grove_tree
				blocked[anchor + offset] = true
		_:
			return {}
	sprites.append({"type": "label", "cell": anchor + Vector2i(-2, -4)})
	return {
		"ok": true, "kind": "prop",
		"ground": ground, "decor": decor, "blocked": blocked,
		"sprites": sprites, "bounds": Rect2i(anchor - Vector2i(5, 5), Vector2i(11, 11))
	}

## The fallback: the overworld icon, grounded and now BLOCKING its anchor
## cell when that cell is dry (a mid-lake icon stays pure scenery).
func _plan_landmark_icon(landmark: Dictionary) -> Dictionary:
	var anchor := landmark.get("anchor", Vector2i.ZERO) as Vector2i
	var atlas_coords := landmark.get("tile_atlas", Vector2i(-1, -1)) as Vector2i
	if atlas_coords.x < 0:
		return {"ok": false}
	var blocked: Dictionary = {}
	if not _landmark_terrain_base(anchor).begins_with("water"):
		blocked[anchor] = true
	var sprites: Array = [
		{"type": "icon", "cell": anchor, "atlas": atlas_coords, "scale": 1.5},
		{"type": "label", "cell": anchor + Vector2i(-2, -3)}
	]
	# Icon landmarks carry their anchor too: a chronicle beast laired at a
	# bare-icon site (sleeping dragon, cave mouth) spawns with its chunk
	# exactly like a camp garrison. Camps/keepers are unaffected — their
	# structure ids never resolve to icon plans.
	return {
		"ok": true, "kind": "icon", "anchor": anchor,
		"ground": {}, "decor": {}, "blocked": blocked,
		"sprites": sprites, "bounds": Rect2i(anchor - Vector2i(3, 3), Vector2i(7, 7))
	}

## Fisher-Yates with a caller-owned rng, so footprint plans shuffle
## deterministically from their site seed (unlike _seeded_shuffle, which
## draws from the scene's shared stream).
func _seeded_shuffle_with(arr: Array, rng: RandomNumberGenerator) -> void:
	for index in range(arr.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var held: Variant = arr[index]
		arr[index] = arr[swap_index]
		arr[swap_index] = held

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
		var sidecar: Vector2i = cell + (Vector2i(1, 0) if absi(delta.y) >= absi(delta.x) else Vector2i(0, 1))
		for road_cell: Vector2i in [cell, sidecar]:
			if _surface_road_cells.has(road_cell):
				continue
			_surface_road_cells[road_cell] = true
			# Roads traced mid-walk (a site sliding into the window) must
			# show up in ground that already streamed; unstreamed chunks
			# pick the road up from the shared map when they paint.
			_repaint_streamed_road_cell(road_cell)
		path.append(cell)
	_surface_road_paths.append(path)

func _repaint_streamed_road_cell(cell: Vector2i) -> void:
	if not _surface_chunks.has(SurfaceWorldService.chunk_for_cell(cell)):
		return
	if _latest_grid.has(cell) or _player_built_cells.has(cell) or _farm_plots.has(cell):
		return
	var danger := SurfaceLifeService.danger_for_cell(cell, _surface_anchor_cells)
	_place_surface_tile(city_layer, cell, _surface_road_tile_key(cell, danger), danger)
	decor_layer.erase_cell(cell)
	_surface_blocked_cells.erase(cell)
	_actor_passable_cache.erase(cell)

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
	# Sliding site window: crossing an overworld-tile boundary re-evaluates
	# which gazetteer sites are live. Checked before the chunk early-out
	# because tile borders (64 cells) don't align with chunk borders (24).
	if not _surface_all_sites.is_empty():
		var player_tile := _overworld_tile_for_cell(_player_cell)
		if player_tile != _surface_window_tile:
			_refresh_surface_site_window(player_tile)
	var player_chunk: Vector2i = SurfaceWorldService.chunk_for_cell(_player_cell)
	if player_chunk == _surface_last_player_chunk:
		return
	_surface_last_player_chunk = player_chunk
	_surface_family_memo.clear()
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
			var terrain: Dictionary = SurfaceWorldService.terrain_for_cell(cell + _surface_world_origin, _surface_noise, danger, _surface_biome_ctx)
			var base_key := String(terrain.get("base", "grass"))
			var decor_key := String(terrain.get("decor", ""))
			var blocked := bool(terrain.get("blocked", false))
			# Flowers are transparent overlays: grass beneath, bloom above.
			if base_key.begins_with("flowers_"):
				decor_key = base_key
				base_key = "grass"
			# Full-height trees only root on spaced anchor cells; the wilds'
			# noise wants a tree on nearly every deep-forest cell, and
			# side-by-side 3-cell canopies carved each other into vertical
			# strips. Off-anchor tree cells drop to understory scatter.
			if decor_key == "tree" or decor_key == "tree_dark":
				var world_cell: Vector2i = cell + _surface_world_origin
				if not _is_tree_anchor_cell(world_cell):
					decor_key = _understory_decor_key(world_cell, base_key)
				elif base_key.begins_with("snow"):
					# Snow-covered pines on tundra ground. The swap happens at
					# placement only - the terrain field keeps answering
					# tree/tree_dark, so the anchor-lattice and crown-suppression
					# checks above and in _cell_under_tree_crown are untouched.
					decor_key += "_snowy"
			# Lakeshore water plants: lily pads and reed clumps over the shore
			# shallows, where the water is within a few cells of dry land.
			if decor_key.is_empty() and base_key.begins_with("water"):
				decor_key = _water_plant_decor_key(cell)
			# Roads cut through everything and stay clear of trees; a road cell
			# is never a barrier, so a trail carves a pass through crags.
			if _surface_road_cells.has(cell):
				base_key = _surface_road_tile_key(cell, danger)
				decor_key = ""
				blocked = false
			# Crag cells keep their rocky tile but stop movement, so a range
			# reads as a real obstacle with walkable valley passes between.
			if blocked:
				_surface_blocked_cells[cell] = true
				_actor_passable_cache.erase(cell)
			elif not _surface_road_cells.has(cell):
				# Terrain-seam autotiling: a sand/water/snow/dark-grass cell
				# bordering another family swaps to the matching fringe piece
				# so biome fronts, shorelines and forest floors blend instead
				# of cutting hard along the cell grid.
				base_key = _surface_fringe_base_key(cell, base_key)
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
	_stamp_landmarks_in_chunk(chunk, rect)
	_stamp_snow_ruins_in_chunk(rect)
	_stamp_graveyards_in_chunk(rect)
	_stamp_road_lamps_in_chunk(rect)
	_clear_understory_under_trees(rect)

## --- Randomly generated ice ruins ------------------------------------------
## Ruined snow forts scattered through the tundra wilds: one candidate
## anchor per SNOW_RUIN_LATTICE-cell block of WORLD space (hash-rolled,
## so every embark sees the same fort at the same spot), realized only
## where the ground is snow. The layout is a pure function of the anchor,
## so each streaming chunk stamps just its own slice and eviction or
## repaint always rebuilds the identical ruin — dark stone floor, broken
## ice-brick walls, snow-capped columns, webs in the corners and one
## lootable chest at its heart.
const SNOW_RUIN_LATTICE := 56
const SNOW_RUIN_CHANCE := 0.3
const SNOW_RUIN_MAX_HALF := 9
const SNOW_RUIN_GATE_CLEARANCE := 26

## Which painted kit a ruin builds from, by the biome it stands in:
## ice-brick forts on the tundra, sandstone forts in the desert.
const RUIN_STYLES := {
	TILE_ATLAS_DEFS.BIOME_TUNDRA: {
		"floor": "ruin_floor", "cracked": "ruin_floor_cracked",
		"brick": "ice_brick", "worn": "ice_brick_worn", "tower": "ruin_tower"
	},
	TILE_ATLAS_DEFS.BIOME_DESERT: {
		"floor": "ruin_floor_sand", "cracked": "ruin_floor_sand_cracked",
		"brick": "sandstone_brick", "worn": "sandstone_brick_worn", "tower": "ruin_tower_sand"
	}
}

var _snow_ruin_layouts: Dictionary = {}

func _stamp_snow_ruins_in_chunk(rect: Rect2i) -> void:
	if _surface_biome_ctx.is_empty():
		return
	var world_rect := Rect2i(rect.position + _surface_world_origin, rect.size)
	var min_block_x := int(floor(float(world_rect.position.x - SNOW_RUIN_MAX_HALF) / float(SNOW_RUIN_LATTICE)))
	var min_block_y := int(floor(float(world_rect.position.y - SNOW_RUIN_MAX_HALF) / float(SNOW_RUIN_LATTICE)))
	var max_block_x := int(floor(float(world_rect.end.x + SNOW_RUIN_MAX_HALF) / float(SNOW_RUIN_LATTICE)))
	var max_block_y := int(floor(float(world_rect.end.y + SNOW_RUIN_MAX_HALF) / float(SNOW_RUIN_LATTICE)))
	for block_y in range(min_block_y, max_block_y + 1):
		for block_x in range(min_block_x, max_block_x + 1):
			var anchor := _snow_ruin_anchor(Vector2i(block_x, block_y))
			if anchor.x == 2147483647:
				continue
			var layout := _snow_ruin_layout(anchor)
			for cell_variant: Variant in layout.keys():
				var cell := cell_variant as Vector2i
				if not rect.has_point(cell):
					continue
				if _latest_grid.has(cell) or _surface_road_cells.has(cell) or _surface_landmark_blocked_cells.has(cell):
					continue
				var piece := layout[cell] as Dictionary
				var base_key := String(piece.get("base", ""))
				if not base_key.is_empty():
					_place_tile(city_layer, cell, base_key)
				var decor_key := String(piece.get("decor", ""))
				if decor_key.is_empty():
					decor_layer.erase_cell(cell)
				else:
					_place_tile(decor_layer, cell, decor_key)

## The block's LOCAL-space ruin anchor, or the sentinel when the block
## rolled no ruin, its ground carries no ruin style (only tundra and
## desert forts exist), or a site gate is too close (the fort must never
## collide with a hold massif or clearing).
func _snow_ruin_anchor(block: Vector2i) -> Vector2i:
	var sentinel := Vector2i(2147483647, 2147483647)
	var roll := hash("snow_ruin|%s|%d|%d" % [_surface_world_seed_text, block.x, block.y])
	if float(roll & 0xffff) / 65535.0 > SNOW_RUIN_CHANCE:
		return sentinel
	var span := SNOW_RUIN_LATTICE - SNOW_RUIN_MAX_HALF * 2 - 2
	var world_anchor := block * SNOW_RUIN_LATTICE + Vector2i(
		SNOW_RUIN_MAX_HALF + 1 + (roll >> 16) % span,
		SNOW_RUIN_MAX_HALF + 1 + (roll >> 32) % span
	)
	if not RUIN_STYLES.has(SurfaceWorldService.biome_for_world_cell(_surface_biome_ctx, world_anchor)):
		return sentinel
	var anchor := world_anchor - _surface_world_origin
	for gate: Dictionary in _surface_gates:
		var gate_anchor := gate.get("anchor", Vector2i.ZERO) as Vector2i
		if maxi(absi(gate_anchor.x - anchor.x), absi(gate_anchor.y - anchor.y)) < SNOW_RUIN_GATE_CLEARANCE:
			return sentinel
	return anchor

## The full fort as {local cell: {"base": key, "decor": key}}, cached per
## anchor. Deterministic: seeded by the anchor's world position.
func _snow_ruin_layout(anchor: Vector2i) -> Dictionary:
	var cached_variant: Variant = _snow_ruin_layouts.get(anchor)
	if cached_variant is Dictionary:
		return cached_variant as Dictionary
	if _snow_ruin_layouts.size() > 24:
		_snow_ruin_layouts.clear()
	var world_anchor := anchor + _surface_world_origin
	var style := RUIN_STYLES.get(
		SurfaceWorldService.biome_for_world_cell(_surface_biome_ctx, world_anchor),
		RUIN_STYLES[TILE_ATLAS_DEFS.BIOME_TUNDRA]
	) as Dictionary
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("snow_ruin_layout|%s|%d|%d" % [_surface_world_seed_text, world_anchor.x, world_anchor.y])
	var layout: Dictionary = {}
	var half_w := rng.randi_range(6, SNOW_RUIN_MAX_HALF)
	var half_h := rng.randi_range(5, SNOW_RUIN_MAX_HALF - 1)
	# The courtyard: a ragged dark-stone blob.
	for y in range(-half_h, half_h + 1):
		for x in range(-half_w, half_w + 1):
			var dx := float(x) / float(half_w)
			var dy := float(y) / float(half_h)
			var edge := float(hash("ruin_edge|%d|%d" % [world_anchor.x + x, world_anchor.y + y]) & 0xffff) / 65535.0
			if dx * dx + dy * dy > 0.66 + edge * 0.45:
				continue
			layout[anchor + Vector2i(x, y)] = {
				"base": String(style["cracked"]) if rng.randf() < 0.28 else String(style["floor"]),
				"decor": ""
			}
	# Broken wall runs: straight courses with collapse gaps, a share worn
	# down to their lowest bricks.
	for _run in range(rng.randi_range(4, 7)):
		var horizontal := rng.randf() < 0.5
		var run_length := rng.randi_range(3, 7)
		var start := Vector2i(
			rng.randi_range(-half_w + 2, half_w - 2 - (run_length if horizontal else 0)),
			rng.randi_range(-half_h + 2, half_h - 2 - (0 if horizontal else run_length))
		)
		for step in range(run_length):
			if rng.randf() < 0.24:
				continue
			var cell := anchor + start + (Vector2i(step, 0) if horizontal else Vector2i(0, step))
			if not layout.has(cell):
				continue
			layout[cell] = {
				"base": String(style["worn"]) if rng.randf() < 0.35 else String(style["brick"]),
				"decor": ""
			}
	# Snow-capped columns on the rim.
	for _tower in range(rng.randi_range(2, 4)):
		var angle := rng.randf() * TAU
		var rim_cell := anchor + Vector2i(
			int(round(cos(angle) * float(half_w - 1))),
			int(round(sin(angle) * float(half_h - 1)))
		)
		if layout.has(rim_cell):
			var rim_entry := layout[rim_cell] as Dictionary
			if String(rim_entry.get("base", "")).begins_with("ruin_floor"):
				rim_entry["decor"] = String(style["tower"])
	# Webs where floor meets standing wall.
	var web_budget := rng.randi_range(3, 5)
	for cell_variant: Variant in layout.keys():
		if web_budget <= 0:
			break
		var cell := cell_variant as Vector2i
		var entry := layout[cell] as Dictionary
		if not String(entry.get("base", "")).begins_with("ruin_floor") or not String(entry.get("decor", "")).is_empty():
			continue
		var wall_beside := false
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbor_entry_variant: Variant = layout.get(cell + offset)
			if not (neighbor_entry_variant is Dictionary):
				continue
			var neighbor_base := String((neighbor_entry_variant as Dictionary).get("base", ""))
			if neighbor_base == String(style["brick"]) or neighbor_base == String(style["worn"]):
				wall_beside = true
				break
		if wall_beside and rng.randf() < 0.3:
			entry["decor"] = "web"
			web_budget -= 1
	# One chest at the heart: the ruin's reward (chest decor cells are
	# lootable through the ordinary chest interaction).
	for radius in range(0, 4):
		var placed := false
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var cell := anchor + Vector2i(x, y)
				var entry_variant: Variant = layout.get(cell)
				if not (entry_variant is Dictionary):
					continue
				var entry := entry_variant as Dictionary
				if String(entry.get("base", "")).begins_with("ruin_floor") and String(entry.get("decor", "")).is_empty():
					entry["decor"] = "chest"
					placed = true
					break
			if placed:
				break
		if placed:
			break
	_snow_ruin_layouts[anchor] = layout
	return layout

## --- Churchyards and street lamps -------------------------------------------
## Old burial grounds scattered through temperate wilds, one candidate
## per lattice block of WORLD space like the ruined forts: rows of
## headstones and cross markers, lidded stone coffins, a moss-eaten
## statue or a working two-tier fountain at the heart, and wrought
## street lamps at the gate corners. Everything is decor over untouched
## ground, so the yard sits naturally in whatever grass or autumn forest
## it was dug in.
const GRAVEYARD_LATTICE := 64
const GRAVEYARD_CHANCE := 0.22
const GRAVEYARD_HALF := Vector2i(5, 4)

var _graveyard_layouts: Dictionary = {}
var _lamp_glow_sprites: Dictionary = {}

func _stamp_graveyards_in_chunk(rect: Rect2i) -> void:
	if _surface_biome_ctx.is_empty():
		return
	var world_rect := Rect2i(rect.position + _surface_world_origin, rect.size)
	var pad := GRAVEYARD_HALF + Vector2i(1, 2)
	var min_block_x := int(floor(float(world_rect.position.x - pad.x) / float(GRAVEYARD_LATTICE)))
	var min_block_y := int(floor(float(world_rect.position.y - pad.y) / float(GRAVEYARD_LATTICE)))
	var max_block_x := int(floor(float(world_rect.end.x + pad.x) / float(GRAVEYARD_LATTICE)))
	var max_block_y := int(floor(float(world_rect.end.y + pad.y) / float(GRAVEYARD_LATTICE)))
	for block_y in range(min_block_y, max_block_y + 1):
		for block_x in range(min_block_x, max_block_x + 1):
			var anchor := _graveyard_anchor(Vector2i(block_x, block_y))
			if anchor.x == 2147483647:
				continue
			var layout := _graveyard_layout(anchor)
			for cell_variant: Variant in layout.keys():
				var cell := cell_variant as Vector2i
				if not rect.has_point(cell):
					continue
				if _latest_grid.has(cell) or _surface_road_cells.has(cell) or _surface_landmark_blocked_cells.has(cell):
					continue
				# Only stand stones on open painted ground - never in water
				# or on crag.
				if city_layer.get_cell_source_id(cell) < 0:
					continue
				if not _is_passable_atlas_tile(city_layer.get_cell_atlas_coords(cell)):
					continue
				if decor_layer.get_cell_source_id(cell) >= 0:
					decor_layer.erase_cell(cell)
				_place_tile(decor_layer, cell, String(layout[cell]))

func _graveyard_anchor(block: Vector2i) -> Vector2i:
	var sentinel := Vector2i(2147483647, 2147483647)
	var roll := hash("graveyard|%s|%d|%d" % [_surface_world_seed_text, block.x, block.y])
	if float(roll & 0xffff) / 65535.0 > GRAVEYARD_CHANCE:
		return sentinel
	var span := GRAVEYARD_LATTICE - maxi(GRAVEYARD_HALF.x, GRAVEYARD_HALF.y) * 2 - 4
	var world_anchor := block * GRAVEYARD_LATTICE + Vector2i(
		GRAVEYARD_HALF.x + 2 + (roll >> 16) % span,
		GRAVEYARD_HALF.y + 2 + (roll >> 32) % span
	)
	var biome := SurfaceWorldService.biome_for_world_cell(_surface_biome_ctx, world_anchor)
	if biome != (TILE_ATLAS_DEFS.BIOME_GRASSLAND as String) and biome != (TILE_ATLAS_DEFS.BIOME_FOREST as String):
		return sentinel
	var anchor := world_anchor - _surface_world_origin
	for gate: Dictionary in _surface_gates:
		var gate_anchor := gate.get("anchor", Vector2i.ZERO) as Vector2i
		if maxi(absi(gate_anchor.x - anchor.x), absi(gate_anchor.y - anchor.y)) < SNOW_RUIN_GATE_CLEARANCE:
			return sentinel
	return anchor

## {local cell: decor key}. Rows of markers around a centerpiece, a few
## coffins among them, lamps on the south corners.
func _graveyard_layout(anchor: Vector2i) -> Dictionary:
	var cached_variant: Variant = _graveyard_layouts.get(anchor)
	if cached_variant is Dictionary:
		return cached_variant as Dictionary
	if _graveyard_layouts.size() > 24:
		_graveyard_layouts.clear()
	var world_anchor := anchor + _surface_world_origin
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("graveyard_layout|%s|%d|%d" % [_surface_world_seed_text, world_anchor.x, world_anchor.y])
	var layout: Dictionary = {}
	# The centerpiece: a fountain in park-like yards, a statue in the rest.
	if rng.randf() < 0.45:
		layout[anchor + Vector2i(0, -1)] = "fountain_nw"
		layout[anchor + Vector2i(1, -1)] = "fountain_ne"
		layout[anchor + Vector2i(0, 0)] = "fountain_sw"
		layout[anchor + Vector2i(1, 0)] = "fountain_se"
	else:
		layout[anchor] = "statue_mossy"
	# Marker rows, spaced like the reference yard; coffins take a slot in
	# roughly one row per yard.
	for row_y in range(-GRAVEYARD_HALF.y, GRAVEYARD_HALF.y + 1, 2):
		for col_x in range(-GRAVEYARD_HALF.x, GRAVEYARD_HALF.x + 1, 2):
			var cell := anchor + Vector2i(col_x, row_y)
			if layout.has(cell) or absi(col_x) <= 1 and absi(row_y) <= 1:
				continue
			var marker_roll := rng.randf()
			if marker_roll < 0.3:
				continue
			if marker_roll < 0.42 and row_y > -GRAVEYARD_HALF.y:
				# Coffins anchor at their FOOT; the head row above must
				# stay inside the yard.
				layout[cell] = "stone_coffin"
			elif marker_roll < 0.75:
				layout[cell] = "gravestone"
			else:
				layout[cell] = "gravestone_cross"
	# Lamps light the yard's south corners.
	layout[anchor + Vector2i(-GRAVEYARD_HALF.x, GRAVEYARD_HALF.y)] = "street_lamp"
	layout[anchor + Vector2i(GRAVEYARD_HALF.x, GRAVEYARD_HALF.y)] = "street_lamp"
	_graveyard_layouts[anchor] = layout
	return layout

## Wrought lamps pace the wild roads: roughly one per eleven road cells,
## set on the verge beside the trail, each with a warm breathing glow.
func _stamp_road_lamps_in_chunk(rect: Rect2i) -> void:
	if _surface_road_cells.is_empty():
		return
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var road_cell := Vector2i(x, y)
			if not _surface_road_cells.has(road_cell):
				continue
			var world_cell := road_cell + _surface_world_origin
			if (hash("road_lamp|%d|%d" % [world_cell.x, world_cell.y]) & 0xffff) % 11 != 0:
				continue
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var verge := road_cell + offset
				if not rect.has_point(verge):
					continue
				if _surface_road_cells.has(verge) or _latest_grid.has(verge) or _lamp_glow_sprites.has(verge):
					continue
				if city_layer.get_cell_source_id(verge) < 0:
					continue
				if not _is_passable_atlas_tile(city_layer.get_cell_atlas_coords(verge)):
					continue
				if decor_layer.get_cell_source_id(verge) >= 0:
					continue
				_place_tile(decor_layer, verge, "street_lamp")
				_spawn_lamp_glow(verge)
				break

func _spawn_lamp_glow(cell: Vector2i) -> void:
	if _lamp_glow_sprites.has(cell):
		return
	var glow: Sprite2D = RoomFurnishingService.create_glow_sprite(
		_cell_center_position(cell) + Vector2(0.0, -float(tile_size.y)),
		2.2 * float(tile_size.x),
		Color(1.0, 0.8, 0.42, 1.0)
	)
	glow.visible = _lighting_enabled
	actor_layer.add_child(glow)
	var base_scale := glow.scale
	var period := 0.5 + float(absi(cell.x * 31 + cell.y * 17) % 40) * 0.01
	var pulse := glow.create_tween().set_loops()
	pulse.tween_property(glow, "scale", base_scale * 1.1, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(glow, "scale", base_scale, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_lamp_glow_sprites[cell] = glow

## Ground-truth guarantee that no cut-stump or bush is left drawn on top of
## a tree: after a chunk (and its landmarks) are painted, scan it — grown by
## the footprint margin so cross-chunk seams are covered either way a pair
## streams in — and erase any understory tile that actually sits under a
## placed tree tile. A tree's art hangs downward and one cell to each side
## of its anchor, so a cell is covered by an anchor at columns x-1..x+1 and
## rows y-2..y. Reads the real placed tiles, so it does not depend on
## re-deriving terrain or on the paint order.
func _clear_understory_under_trees(rect: Rect2i) -> void:
	if _tree_decor_set.is_empty():
		for key: String in ["tree", "tree_dark", "tree_snowy", "tree_dark_snowy"]:
			_tree_decor_set[TILE_ATLAS.get(key, Vector2i(-1, -1))] = true
		for key: String in ["stump", "stump_alt", "hedge", "hedge_alt"]:
			_understory_decor_set[TILE_ATLAS.get(key, Vector2i(-1, -1))] = true
	var scan := rect.grow(2)
	for y in range(scan.position.y, scan.end.y):
		for x in range(scan.position.x, scan.end.x):
			var cell := Vector2i(x, y)
			if decor_layer.get_cell_source_id(cell) < 0:
				continue
			if not _understory_decor_set.has(decor_layer.get_cell_atlas_coords(cell)):
				continue
			if _tree_tile_covers_cell(cell):
				decor_layer.erase_cell(cell)
				_actor_passable_cache.erase(cell)

func _tree_tile_covers_cell(cell: Vector2i) -> bool:
	for dy: int in range(-2, 1):
		for dx: int in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var anchor := cell + Vector2i(dx, dy)
			if decor_layer.get_cell_source_id(anchor) < 0:
				continue
			if _tree_decor_set.has(decor_layer.get_cell_atlas_coords(anchor)):
				return true
	return false

## Trees may only root on a lattice spaced 2 cells across and 3 cells down
## (with a deterministic per-row jog so the woods don't grid up). The
## horizontal 2 keeps a 3-cell-wide canopy off a neighbor's trunk column;
## the vertical 3 keeps the tall dark-tree canopy — which reaches two rows
## ABOVE its trunk — from being drawn over the trunk of the tree above it
## (which read as trees with no base). Both together stop trunks vanishing
## and stop tree crowns being carved into vertical strips.
func _is_tree_anchor_cell(world_cell: Vector2i) -> bool:
	if posmod(world_cell.y, 3) != 0:
		return false
	var row_jog := absi(world_cell.y * 40503 >> 4) % 2
	return posmod(world_cell.x + row_jog, 2) == 0

## What grows where a too-crowded tree was thinned out: mostly open ground,
## with occasional bushes and stumps so the forest floor keeps its clutter.
## Bushes stay off snow and sand (leafy green reads wrong there); stumps
## suit any ground. Nothing grows under a neighboring tree's crown: the
## overhanging canopy art would be overdrawn by decor placed there.
func _understory_decor_key(world_cell: Vector2i, base_key: String) -> String:
	var cell_hash := absi(world_cell.x * 73856093 ^ world_cell.y * 19349663)
	var roll := cell_hash % 12
	if roll > 3:
		return ""
	if _cell_under_tree_crown(world_cell):
		return ""
	if roll <= 1:
		if base_key.begins_with("snow") or base_key.begins_with("sand"):
			return ""
		return "hedge" if roll == 0 else "hedge_alt"
	return "stump" if cell_hash % 5 != 0 else "stump_alt"

## Whether a nearby lattice anchor holds a tree whose art visually covers
## this cell. Measured footprint: a tree's art is centered on its anchor
## column (one cell left and right) and hangs DOWNWARD from the anchor
## row — the crown on the anchor row, the trunk up to two rows below it.
## So the anchors that could cover cell (x,y) sit at columns x-1..x+1 and
## rows y-2..y (an anchor at or ABOVE the cell, its art draping down onto
## it). Only those few candidates are tested, with the same deterministic
## terrain field the chunk painter uses, so the verdict is stable across
## (re-)streaming.
func _cell_under_tree_crown(world_cell: Vector2i) -> bool:
	for anchor_y: int in range(world_cell.y - 2, world_cell.y + 1):
		for anchor_x: int in range(world_cell.x - 1, world_cell.x + 2):
			var anchor := Vector2i(anchor_x, anchor_y)
			if anchor == world_cell or not _is_tree_anchor_cell(anchor):
				continue
			var scene_cell := anchor - _surface_world_origin
			# Cells the town rendered or a road claimed never get a tree.
			if _latest_grid.has(scene_cell) or _surface_road_cells.has(scene_cell):
				continue
			# Recompute the anchor's OWN danger: it shifts the forest
			# threshold, so borrowing the query cell's danger can misjudge
			# whether the anchor really grew a tree and leak a stump under it.
			var anchor_danger := SurfaceLifeService.danger_for_cell(anchor, _surface_anchor_cells)
			var terrain: Dictionary = SurfaceWorldService.terrain_for_cell(anchor, _surface_noise, anchor_danger, _surface_biome_ctx)
			var decor := String(terrain.get("decor", ""))
			if decor == "tree" or decor == "tree_dark":
				return true
	return false

## Water plants stop at this Chebyshev distance from dry land: beyond it the
## lake is open deep water and stays bare.
const WATER_PLANT_MAX_SHORE_DISTANCE := 4
## Per-distance placement chance (percent) inside a plant blob: dense right
## off the bank, thinning to almost nothing at the deep edge of the shallows.
const WATER_PLANT_DENSITY_BY_DISTANCE: Array[int] = [0, 60, 42, 22, 9]

## The water-plant dressing for one painted water cell: lily pads (singles,
## clustered pairs, the occasional flowering white lily) through the shore
## shallows, reed clumps hugging the bank, nothing in open deep water. All
## verdicts are deterministic per world cell - a coarse hash lattice gathers
## the plants into shoreline blobs (reference style, not a uniform sprinkle)
## and per-cell hash rolls pick the species - so re-streaming a lake rebuilds
## the exact same beds. Snow-shored (tundra) water stays bare: green pads on
## a winter lake read wrong against the snow-lapped fringe.
func _water_plant_decor_key(cell: Vector2i) -> String:
	var world_cell: Vector2i = cell + _surface_world_origin
	# Coarse cluster gate first - it is cheap and rejects most open water
	# before the ring scan below ever runs.
	if _water_plant_blob_field(world_cell) < 0.60:
		return ""
	# Tundra water is winter water even when a sand ring separates it from
	# the snowfield (the coast band), so the biome label backs up the
	# snow-shore check below.
	if SurfaceWorldService.biome_for_world_cell(_surface_biome_ctx, world_cell) == TILE_ATLAS_DEFS.BIOME_TUNDRA:
		return ""
	var shore := _water_shore_info(cell)
	var shore_distance := int(shore.get("distance", WATER_PLANT_MAX_SHORE_DISTANCE + 1))
	if shore_distance > WATER_PLANT_MAX_SHORE_DISTANCE:
		return ""
	if bool(shore.get("snow", false)):
		return ""
	var cell_hash := absi(world_cell.x * 73856093 ^ world_cell.y * 19349663)
	if cell_hash % 100 >= WATER_PLANT_DENSITY_BY_DISTANCE[shore_distance]:
		return ""
	# Reeds break the surface right against the bank; pads float further out.
	if shore_distance <= 2 and (cell_hash / 100) % 3 == 0:
		return "reeds" if (cell_hash / 300) % 2 == 0 else "reeds_alt"
	var pad_roll := (cell_hash / 900) % 8
	if pad_roll == 0:
		# The flowering share: one blossom per ~8 pad placements.
		return "lily_flower"
	if pad_roll <= 2:
		return "lily_pad_pair"
	return "lily_pad"

## Where the shore is, seen from a water cell: expanding Chebyshev rings up
## to the plant limit, answered from the same memoized deterministic terrain
## families the fringe autotiling uses (painted ground where it exists, the
## noise field where it doesn't), so verdicts are stable across re-streaming.
## "snow" is true when the dry land on the nearest ring AND the ring behind
## it is at least a third snow-family - winter lakes wear a one-cell sand
## beach at the waterline, so the nearest ring alone would miss the
## snowfield right behind it.
func _water_shore_info(cell: Vector2i) -> Dictionary:
	var nearest := 0
	var land := 0
	var snow_land := 0
	for distance: int in range(1, WATER_PLANT_MAX_SHORE_DISTANCE + 2):
		for dy: int in range(-distance, distance + 1):
			for dx: int in range(-distance, distance + 1):
				if maxi(absi(dx), absi(dy)) != distance:
					continue
				var family := _surface_cell_family(cell + Vector2i(dx, dy))
				if family == "water":
					continue
				land += 1
				if family.begins_with("snow"):
					snow_land += 1
		if land > 0 and nearest == 0:
			nearest = distance
		if nearest > 0 and distance >= nearest + 1:
			break
	if nearest == 0 or nearest > WATER_PLANT_MAX_SHORE_DISTANCE:
		return {"distance": WATER_PLANT_MAX_SHORE_DISTANCE + 1, "snow": false}
	return {"distance": nearest, "snow": snow_land * 3 >= land}

## Value noise over world cells (hash lattice every 3 cells, smoothstepped
## bilinear blend), the same trick as the town's dark-grass patches but with
## its own salt: high-field cells form the multi-cell plant beds.
func _water_plant_blob_field(world_cell: Vector2i) -> float:
	var gx := int(floor(float(world_cell.x) / 3.0))
	var gy := int(floor(float(world_cell.y) / 3.0))
	var fx := (float(world_cell.x) - float(gx) * 3.0) / 3.0
	var fy := (float(world_cell.y) - float(gy) * 3.0) / 3.0
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var v00 := _water_plant_lattice_value(gx, gy)
	var v10 := _water_plant_lattice_value(gx + 1, gy)
	var v01 := _water_plant_lattice_value(gx, gy + 1)
	var v11 := _water_plant_lattice_value(gx + 1, gy + 1)
	return lerpf(lerpf(v00, v10, fx), lerpf(v01, v11, fx), fy)

func _water_plant_lattice_value(gx: int, gy: int) -> float:
	var value := (gx * 11 + 5) * 73856093 ^ (gy * 7 - 3) * 19349663
	if value < 0:
		value = -value
	return float(value % 1024) / 1023.0

## Wilds road tile with the same grass-fringed autotiling the village lanes
## use: a side is "open" when its neighbor is grassy non-road ground, so
## trails scallop into meadows but stay bare dirt against sand, snow, rock
## and water. Neighbor terrain comes from the same deterministic field the
## chunk painter uses.
func _surface_road_tile_key(cell: Vector2i, danger: float) -> String:
	var n_open := _road_side_open(cell + Vector2i.UP, danger)
	var s_open := _road_side_open(cell + Vector2i.DOWN, danger)
	var w_open := _road_side_open(cell + Vector2i.LEFT, danger)
	var e_open := _road_side_open(cell + Vector2i.RIGHT, danger)
	if n_open and w_open:
		return "road_edge_nw"
	if n_open and e_open:
		return "road_edge_ne"
	if s_open and w_open:
		return "road_edge_sw"
	if s_open and e_open:
		return "road_edge_se"
	if n_open and s_open:
		return "road_edge_n" if (cell.x + cell.y) % 2 == 0 else "road_edge_s"
	if w_open and e_open:
		return "road_edge_w" if (cell.x + cell.y) % 2 == 0 else "road_edge_e"
	if n_open:
		return "road_edge_n"
	if s_open:
		return "road_edge_s"
	if w_open:
		return "road_edge_w"
	if e_open:
		return "road_edge_e"
	if _road_side_open(cell + Vector2i(-1, -1), danger):
		return "road_in_nw"
	if _road_side_open(cell + Vector2i(1, -1), danger):
		return "road_in_ne"
	if _road_side_open(cell + Vector2i(-1, 1), danger):
		return "road_in_sw"
	if _road_side_open(cell + Vector2i(1, 1), danger):
		return "road_in_se"
	var roll := absi(cell.x * 73856093 ^ cell.y * 19349663) % 9
	if roll == 0:
		return "road_twig"
	if roll == 1:
		return "road_alt"
	if roll == 2:
		return "road_stone"
	return "road"

## True when the neighbor of a road cell is open grassy ground: town grass
## verges and wild grass-family terrain qualify; roads, buildings, water,
## sand, snow and rock do not.
func _road_side_open(neighbor: Vector2i, danger: float) -> bool:
	if _surface_road_cells.has(neighbor):
		return false
	if _latest_grid.has(neighbor):
		return int(_latest_grid.get(neighbor, 0)) == TownTileService.CELL_ROCK
	var terrain: Dictionary = SurfaceWorldService.terrain_for_cell(neighbor + _surface_world_origin, _surface_noise, danger, _surface_biome_ctx)
	if bool(terrain.get("blocked", false)):
		return false
	var base_key := String(terrain.get("base", "grass"))
	return base_key.begins_with("grass") or base_key.begins_with("flowers")

## Terrain-seam autotiling for the streamed wilds: given the cell's freshly
## computed base tile, return the fringe piece matching which of its eight
## neighbors belong to the family that overhangs it. Dark grass wears a
## plain-grass fringe toward meadows and lane verges; sand and snow wear a
## grass overhang at biome fronts; water shorelines pick a grass, sand or
## snow lap (in that order of preference); snow_alt drifts feather into
## plain snow. Everything else keeps its tile. Deterministic: neighbor
## families come from painted ground where it exists and from the same
## noise field the painter will use where it doesn't.
func _surface_fringe_base_key(cell: Vector2i, base_key: String) -> String:
	var family := TownTileService.terrain_family_for_tile_key(base_key)
	if not (family in ["grass_dark", "sand", "snow", "snow_alt", "water"]):
		return base_key
	var neighbor_families: Array[String] = []
	for offset: Vector2i in [
			Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
			Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		neighbor_families.append(_surface_cell_family(cell + offset))
	var open_families: Array[String] = []
	var prefix := ""
	match family:
		"grass_dark":
			open_families = ["grass", "road"]
			prefix = "grass_dark"
		"sand":
			# Sand meets grassland at desert fronts and snow at tundra ones
			# (lakeshore beaches, barren lowlands): vote for the overhang.
			var grass_side := 0
			var snow_side := 0
			for neighbor_family: String in neighbor_families:
				match neighbor_family:
					"grass", "grass_dark":
						grass_side += 1
					"snow", "snow_alt":
						snow_side += 1
			if snow_side > grass_side:
				open_families = ["snow", "snow_alt"]
				prefix = "sand_snow"
			else:
				open_families = ["grass", "grass_dark"]
				prefix = "sand_grass"
		"snow":
			open_families = ["grass", "grass_dark"]
			prefix = "snow_grass"
		"snow_alt":
			open_families = ["snow"]
			prefix = "snow_alt"
	if family == "water":
		# Every dry land side counts as open (so the mask wraps the whole
		# shoreline), and the overhang art follows the majority shore: a
		# grass bank, a sand beach, or a snow lip. Mixed shores keep the
		# majority material - a slightly-off fringe hue beats a hard cut.
		var grass_votes := 0
		var sand_votes := 0
		var snow_votes := 0
		for neighbor_family: String in neighbor_families:
			match neighbor_family:
				"grass", "grass_dark":
					grass_votes += 1
				"sand":
					sand_votes += 1
				"snow", "snow_alt":
					snow_votes += 1
		if grass_votes + sand_votes + snow_votes == 0:
			return base_key
		open_families = ["grass", "grass_dark", "sand", "snow", "snow_alt"]
		if grass_votes >= sand_votes and grass_votes >= snow_votes:
			prefix = "water_grass"
		elif sand_votes >= snow_votes:
			prefix = "water_sand"
		else:
			prefix = "water_snow"
	var suffix := TownTileService.fringe_suffix(
		neighbor_families[0] in open_families,
		neighbor_families[1] in open_families,
		neighbor_families[2] in open_families,
		neighbor_families[3] in open_families,
		neighbor_families[4] in open_families,
		neighbor_families[5] in open_families,
		neighbor_families[6] in open_families,
		neighbor_families[7] in open_families,
		true, cell.x, cell.y)
	if suffix.is_empty():
		return base_key
	return "%s_%s" % [prefix, suffix]

## The terrain family at a cell, for seam masks. Painted ground (the town,
## already-streamed chunks, player builds) is the truth; unpainted wilds
## are classified from the same deterministic terrain field the painter
## uses, so masks agree across chunk borders regardless of paint order.
## Memoized per streaming pass - neighbors are shared by adjacent cells.
func _surface_cell_family(cell: Vector2i) -> String:
	var memo: Variant = _surface_family_memo.get(cell)
	if memo != null:
		return String(memo)
	var family := _compute_surface_cell_family(cell)
	_surface_family_memo[cell] = family
	return family

func _compute_surface_cell_family(cell: Vector2i) -> String:
	if _surface_blocked_cells.has(cell):
		return "rock"
	if _surface_road_cells.has(cell):
		return "road"
	if city_layer.get_cell_source_id(cell) >= 0:
		return _family_for_atlas_coords(city_layer.get_cell_atlas_coords(cell))
	var danger := SurfaceLifeService.danger_for_cell(cell, _surface_anchor_cells)
	var terrain: Dictionary = SurfaceWorldService.terrain_for_cell(cell + _surface_world_origin, _surface_noise, danger, _surface_biome_ctx)
	if bool(terrain.get("blocked", false)):
		return "rock"
	return TownTileService.terrain_family_for_tile_key(String(terrain.get("base", "grass")))

func _family_for_atlas_coords(atlas_coords: Vector2i) -> String:
	if _atlas_family_by_coords.is_empty():
		for tile_key: String in TILE_ATLAS.keys():
			_atlas_family_by_coords[TILE_ATLAS[tile_key]] = TownTileService.terrain_family_for_tile_key(tile_key)
	return String(_atlas_family_by_coords.get(atlas_coords, "other"))

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
		# A closed hold announces itself: the name wears its status.
		if String(site.get("class", "")) == "dwarfhold" and String(site.get("access", "Open")) == "Closed":
			gate_label.text += "\n⛓ Gates sealed"
		gate_label.add_theme_font_size_override("font_size", 18)
		gate_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82, 1.0))
		gate_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06, 1.0))
		gate_label.add_theme_constant_override("outline_size", 5)
		# A hold's name floats over its great hall at the city's heart;
		# every other site names itself above its doorstep.
		var label_cell := anchor + Vector2i(-2, -4)
		if String(site.get("class", "")) == "dwarfhold":
			label_cell = _hold_ward_stair_cell(anchor) + Vector2i(-2, -3)
		gate_label.position = city_layer.map_to_local(label_cell)
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

## The hold's face in the wilds: the mountain itself. A hold rises out of
## its overworld tile, so arriving overland means meeting a ragged crag
## massif of impassable stone — the same blocked-crag rock the wild
## ranges use — with a dressed-stone front carved into its south face and
## one door at its center. Only the door (and the apron cell before it)
## descends; every other approach meets solid rock. Roads are left alone,
## so a traced trail still carves its pass up to the door.
## The massif grew to hold a real WARD inside: the mountain's interior
## is the hold's surface district, walked into through the mouth with no
## scene change at all. Descending to the city proper happens at the
## ward's stair.
## The city's half extents in cells: the main floor spans the full
## rect (width 2w+1, height 2h+1) with the mouth at the south center.
const HOLD_CITY_HALF_W := 24
const HOLD_CITY_HALF_H := 17
const HOLD_TILE_SOURCE_ID := 1
const HOLD_TILESHEET_PATH := "res://resources/images/dwarfhold/map.png"

var _hold_passable_atlas_set: Dictionary = {}
## Ward dwarves: lightweight wanderers walking the embedded district,
## keyed by gate site key so they free with their gate.
var _ward_dwarves: Array[Dictionary] = []

## Where the embedded ward's descend-stair sits relative to the gate
## anchor - the great hall's heart, shared by the plan and the trigger.
func _hold_ward_stair_cell(anchor: Vector2i) -> Vector2i:
	return anchor + Vector2i(0, -HOLD_CITY_HALF_H)

func _stamp_dwarfhold_facade(anchor: Vector2i) -> void:
	# The city itself - stone, streets, buildings, furnishings - streams
	# chunk by chunk as the "dwarfhold_city" landmark plan. The facade
	# stamp owns what is GATE-scoped: the apron outside the mouth, the
	# darkness overlay with its sconce torches, and the ward dwarves.
	var gate_key := _ward_site_key_for_cell(anchor)
	var plan := _dwarfhold_city_plan(gate_key)
	# The doorstep: a paved apron just outside the mouth, hedge-flanked,
	# where the trail from the wilds arrives.
	for y in range(anchor.y + 1, anchor.y + 3):
		for x in range(anchor.x - 2, anchor.x + 3):
			var cell := Vector2i(x, y)
			if _latest_grid.has(cell):
				continue
			_place_tile(city_layer, cell, "plaza")
			decor_layer.erase_cell(cell)
			_surface_blocked_cells.erase(cell)
	_place_tile(decor_layer, Vector2i(anchor.x - 3, anchor.y + 1), "hedge")
	_place_tile(decor_layer, Vector2i(anchor.x + 3, anchor.y + 1), "hedge_alt")
	# Player-dug galleries re-open on every stamp.
	_apply_ward_digs(gate_key)
	var sconce_cells: Array[Vector2i] = []
	for sconce_variant: Variant in plan.get("sconces", []) as Array:
		sconce_cells.append(sconce_variant as Vector2i)
	var light_cells: Array[Vector2i] = []
	for light_variant: Variant in plan.get("light_cells", []) as Array:
		light_cells.append(light_variant as Vector2i)
	_spawn_ward_overlay(gate_key, anchor, sconce_cells, light_cells, not bool(plan.get("closed", false)))
	var spawn_cells: Dictionary = {}
	for spawn_variant: Variant in plan.get("spawn_cells", []) as Array:
		spawn_cells[spawn_variant as Vector2i] = true
	var ward_rng := RandomNumberGenerator.new()
	ward_rng.seed = hash("hold_ward|%s|%d|%d" % [_surface_world_seed_text, anchor.x, anchor.y])
	_spawn_ward_dwarves(anchor, spawn_cells, ward_rng)

## The city plan for a hold gate, shared with the landmark streamer (and
## computed here first if the facade stamps before any city chunk).
func _dwarfhold_city_plan(gate_key: String) -> Dictionary:
	for landmark: Dictionary in _surface_landmarks:
		if String(landmark.get("key", "")) != gate_key:
			continue
		if String(landmark.get("structure", "")) != "dwarfhold_city":
			continue
		var plan := landmark.get("plan", {}) as Dictionary
		if plan.is_empty():
			plan = _plan_landmark_footprint(landmark)
			landmark["plan"] = plan
			landmark["rect"] = plan.get("bounds", landmark.get("rect", Rect2i())) as Rect2i
		return plan
	return {}

## A few of the hold's folk walk their surface ward: lightweight
## wanderers stepping cell to cell on hold ground, freed with the gate.
func _spawn_ward_dwarves(anchor: Vector2i, ward_cells: Dictionary, rng: RandomNumberGenerator) -> void:
	var gate_key := ""
	for gate: Dictionary in _surface_gates:
		if (gate.get("anchor", Vector2i.ZERO) as Vector2i) == anchor:
			gate_key = String(gate.get("key", ""))
			break
	for dwarf: Dictionary in _ward_dwarves:
		if String(dwarf.get("key", "")) == gate_key:
			return
	var open_cells: Array[Vector2i] = []
	for cell_variant: Variant in ward_cells.keys():
		open_cells.append(cell_variant as Vector2i)
	if open_cells.is_empty():
		return
	# A full main floor houses a real population of walkers; the tiny
	# pocket wards of older saves keep their handful.
	var dwarf_count := clampi(open_cells.size() / 4, 3, 14)
	var ward_professions: Array[String] = ["Miner", "Mason", "Brewer", "Smith", "Engraver"]
	for dwarf_index in range(dwarf_count):
		var spawn_cell := open_cells[rng.randi_range(0, open_cells.size() - 1)]
		var sprite := DwarfHoldActorVisuals.create_tavern_character_sprite(DwarfHoldActorVisuals.DWARF_CHARACTERS_TEXTURE, rng.randi_range(0, 7), tile_size)
		if sprite == null:
			continue
		sprite.position = _cell_center_position(spawn_cell)
		sprite.z_index = 11
		actor_layer.add_child(sprite)
		# The first dwarf of every ward keeps a peddler's pack, so the
		# surface district trades like a real outpost; the rest carry
		# proper hold trades and full right-click dossiers.
		var profession := "Peddler" if dwarf_index == 0 else ward_professions[rng.randi_range(0, ward_professions.size() - 1)]
		var identity := NpcIdentityService.generate(rng, profession, "dwarf")
		_ward_dwarves.append({
			"key": gate_key,
			"sprite": sprite,
			"cell": spawn_cell,
			"timer": rng.randf_range(0.8, 2.4),
			"identity": identity,
			"npc_name": String(identity.get("name", "A dwarf")),
			"traveler": dwarf_index == 0
		})

func _ward_dwarf_at_cell(cell: Vector2i) -> Dictionary:
	for dwarf: Dictionary in _ward_dwarves:
		if (dwarf.get("cell", Vector2i(2147483647, 0)) as Vector2i) == cell:
			return dwarf
	return {}

func _free_ward_dwarves_for_key(gate_key: String) -> void:
	for dwarf_index in range(_ward_dwarves.size() - 1, -1, -1):
		var dwarf := _ward_dwarves[dwarf_index]
		if String(dwarf.get("key", "")) != gate_key:
			continue
		var sprite := dwarf.get("sprite") as Sprite2D
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
		_ward_dwarves.remove_at(dwarf_index)

## --- The dark under the mountain ---------------------------------------------
## The ward is interior space, so it is properly dark in there: an
## ellipse-masked darkness quad rides each stamped massif in the SAME
## scene, opened by warm pools - the player's own light, flickering wall
## sconces on the shell rock, daylight spilling through the mouth and
## lamplight up the stairwell. One sprite and one shader per hold,
## freed with its gate like everything else in the ward.
const WARD_LIGHT_MAX := 96
const WARD_PLAYER_LIGHT_TILES := 5.0
const WARD_SCONCE_LIGHT_TILES := 3.6
const WARD_FURNISHING_LIGHT_TILES := 2.6
const WARD_MOUTH_LIGHT_TILES := 4.5
const WARD_STAIR_LIGHT_TILES := 3.0
const WARD_SCONCE_SPACING := 4
const WARD_DARKNESS_SHADER := """
shader_type canvas_item;
uniform vec2 overlay_origin;
uniform vec2 overlay_size;
uniform vec2 ward_center_px;
uniform vec2 ward_half_px;
uniform int light_count = 0;
uniform vec2 light_pos[96];
uniform float light_radius[96];
uniform vec4 darkness_color : source_color = vec4(0.02, 0.03, 0.055, 0.93);

void fragment() {
	vec2 world = overlay_origin + UV * overlay_size;
	vec2 e = (world - ward_center_px) / ward_half_px;
	float reach = dot(e, e);
	// Dark across the ward and its rock shell, feathered out just past
	// the massif's ragged edge so the wilds keep their daylight.
	float mask = 1.0 - smoothstep(0.72, 1.15, reach);
	float reveal = 0.0;
	for (int i = 0; i < light_count; i++) {
		float d = distance(world, light_pos[i]);
		reveal = max(reveal, 1.0 - smoothstep(light_radius[i] * 0.35, light_radius[i], d));
	}
	// Lit ground warms before it clears - torchlight, not a cutout.
	vec3 tinted = mix(darkness_color.rgb, vec3(0.42, 0.26, 0.11), reveal * 0.55);
	COLOR = vec4(tinted, darkness_color.a * mask * (1.0 - reveal * 0.92));
}
"""

var _ward_overlays: Dictionary = {}
var _ward_torch_frames: SpriteFrames = null
var _ward_torch_texture: Texture2D = null

func _spawn_ward_overlay(gate_key: String, anchor: Vector2i, sconce_cells: Array[Vector2i], light_cells: Array[Vector2i] = [], mouth_open: bool = true) -> void:
	if gate_key.is_empty() or _ward_overlays.has(gate_key):
		return
	var tile_px := Vector2(float(tile_size.x), float(tile_size.y))
	var top_left := Vector2i(anchor.x - HOLD_CITY_HALF_W - 2, anchor.y - HOLD_CITY_HALF_H * 2 - 2)
	var origin_px := _cell_center_position(top_left) - tile_px * 0.5
	var size_px := Vector2(float(HOLD_CITY_HALF_W * 2 + 5), float(HOLD_CITY_HALF_H * 2 + 4)) * tile_px
	var quad_image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	quad_image.fill(Color.WHITE)
	var overlay_sprite := Sprite2D.new()
	overlay_sprite.texture = ImageTexture.create_from_image(quad_image)
	overlay_sprite.centered = false
	overlay_sprite.position = origin_px
	overlay_sprite.scale = size_px / 4.0
	overlay_sprite.z_index = 12
	var shader := Shader.new()
	shader.code = WARD_DARKNESS_SHADER
	var overlay_material := ShaderMaterial.new()
	overlay_material.shader = shader
	overlay_material.set_shader_parameter("overlay_origin", origin_px)
	overlay_material.set_shader_parameter("overlay_size", size_px)
	# The mask ellipse inscribes the whole city rect with a feather past
	# its rim: the carved floor sits deep inside, the stone corners fall
	# outside and keep their mountain daylight.
	overlay_material.set_shader_parameter("ward_center_px", _cell_center_position(_hold_ward_stair_cell(anchor)))
	overlay_material.set_shader_parameter("ward_half_px", Vector2(float(HOLD_CITY_HALF_W + 3) * tile_px.x, float(HOLD_CITY_HALF_H + 3) * tile_px.y))
	overlay_sprite.material = overlay_material
	overlay_sprite.visible = _lighting_enabled
	actor_layer.add_child(overlay_sprite)
	var nodes: Array = [overlay_sprite]
	var sconces: Array = []
	for sconce_cell: Vector2i in sconce_cells:
		nodes.append(_spawn_ward_sconce(sconce_cell))
		sconces.append({
			"pos": _cell_center_position(sconce_cell),
			"radius": WARD_SCONCE_LIGHT_TILES * tile_px.x,
			"phase": float(absi(sconce_cell.x * 7 + sconce_cell.y * 13))
		})
	# The buildings' own hearths and candelabras light their rooms too
	# (their glow sprites live with the landmark; the shader pool here).
	for light_cell: Vector2i in light_cells:
		sconces.append({
			"pos": _cell_center_position(light_cell),
			"radius": WARD_FURNISHING_LIGHT_TILES * tile_px.x,
			"phase": float(absi(light_cell.x * 11 + light_cell.y * 5))
		})
	# Daylight through the mouth, lamplight up the stairwell: two fixed
	# pools that keep the way in and the way down readable. A sealed
	# gate lets no daylight past its iron.
	var static_lights: Array = [
		{"pos": _cell_center_position(_hold_ward_stair_cell(anchor)), "radius": WARD_STAIR_LIGHT_TILES * tile_px.x}
	]
	if mouth_open:
		static_lights.append({"pos": _cell_center_position(Vector2i(anchor.x, anchor.y + 1)), "radius": WARD_MOUTH_LIGHT_TILES * tile_px.x})
	_ward_overlays[gate_key] = {
		"material": overlay_material,
		"nodes": nodes,
		"sconces": sconces,
		"static_lights": static_lights
	}

## A wall torch in the ward: the hold's own stick-and-collar sprite with
## an animated swaying flame and a breathing warm glow.
func _spawn_ward_sconce(cell: Vector2i) -> Sprite2D:
	if _ward_torch_texture == null:
		_ward_torch_texture = _create_ward_torch_texture()
	var sconce := Sprite2D.new()
	sconce.texture = _ward_torch_texture
	sconce.centered = true
	sconce.position = _cell_center_position(cell)
	sconce.z_index = 13
	sconce.visible = _lighting_enabled
	var flame := AnimatedSprite2D.new()
	flame.sprite_frames = _ward_torch_flame_frames()
	flame.animation = &"burn"
	flame.position = Vector2(0.0, -10.0)
	flame.frame = absi(cell.x * 7 + cell.y * 13) % 3
	sconce.add_child(flame)
	# Corona only: the ward's darkness shader carves the real pool, so
	# the sprite just hugs the flame instead of fogging the street.
	var glow: Sprite2D = RoomFurnishingService.create_glow_sprite(Vector2.ZERO, 0.9 * float(tile_size.x), Color(1.0, 0.72, 0.35, 1.0))
	glow.position = Vector2(0.0, -6.0)
	sconce.add_child(glow)
	actor_layer.add_child(sconce)
	flame.play()
	var glow_base_scale := glow.scale
	var glow_period := 0.5 + float(absi(cell.x * 31 + cell.y * 17) % 40) * 0.01
	var glow_pulse := glow.create_tween().set_loops()
	glow_pulse.tween_property(glow, "scale", glow_base_scale * 1.12, glow_period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glow_pulse.tween_property(glow, "scale", glow_base_scale, glow_period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return sconce

## The torch stick alone - the flame is a separate animated sprite so it
## can sway (mirrors the hold's own torch art).
func _create_ward_torch_texture() -> Texture2D:
	var image := Image.create(8, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(7, 15):
		image.set_pixel(3, y, Color(0.45, 0.3, 0.16, 1.0))
		image.set_pixel(4, y, Color(0.36, 0.24, 0.13, 1.0))
	image.set_pixel(2, 7, Color(0.3, 0.3, 0.34, 1.0))
	image.set_pixel(5, 7, Color(0.3, 0.3, 0.34, 1.0))
	image.resize(16, 32, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)

func _ward_torch_flame_frames() -> SpriteFrames:
	if _ward_torch_frames != null:
		return _ward_torch_frames
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"burn")
	frames.set_animation_speed(&"burn", 7.0)
	frames.set_animation_loop(&"burn", true)
	for sway in range(3):
		var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		var tip_x := [3, 4, 5][sway] as int
		var body := Color(1.0, 0.62, 0.15, 1.0)
		var core := Color(1.0, 0.85, 0.3, 1.0)
		for y in range(3, 7):
			for x in range(2, 6):
				if (x == 2 or x == 5) and y == 3:
					continue
				image.set_pixel(x, y, body if y > 4 else core)
		image.set_pixel(tip_x, 2, core)
		image.set_pixel(tip_x, 1, Color(1.0, 0.95, 0.6, 1.0))
		image.resize(16, 16, Image.INTERPOLATE_NEAREST)
		frames.add_frame(&"burn", ImageTexture.create_from_image(image))
	_ward_torch_frames = frames
	return frames

func _free_ward_overlay_for_key(gate_key: String) -> void:
	if not _ward_overlays.has(gate_key):
		return
	var overlay := _ward_overlays[gate_key] as Dictionary
	for node_variant: Variant in overlay.get("nodes", []) as Array:
		var node := node_variant as Node2D
		if node != null and is_instance_valid(node):
			node.queue_free()
	_ward_overlays.erase(gate_key)

## Feeds each ward shader its lights every frame: the player first, then
## the mouth and stairwell pools, then every sconce riding a slow sine
## flicker phase-keyed per cell so no two throb in unison.
func _update_ward_darkness() -> void:
	if _ward_overlays.is_empty() or not _lighting_enabled:
		return
	var flicker_phase := float(Time.get_ticks_msec()) * 0.001
	var player_position := _player_sprite.position if _player_sprite != null else Vector2.ZERO
	for overlay_variant: Variant in _ward_overlays.values():
		var overlay := overlay_variant as Dictionary
		var ward_material := overlay.get("material") as ShaderMaterial
		if ward_material == null:
			continue
		# A full main floor carries more fires than the shader holds:
		# when over budget the NEAREST pools to the player win the slots,
		# exactly as the hold scene picks its own lights.
		var flames := (overlay.get("sconces", []) as Array).duplicate()
		if flames.size() > WARD_LIGHT_MAX - 3:
			flames.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return (a.get("pos") as Vector2).distance_squared_to(player_position) < (b.get("pos") as Vector2).distance_squared_to(player_position))
		var positions := PackedVector2Array()
		var radii := PackedFloat32Array()
		if _player_sprite != null:
			positions.append(player_position)
			radii.append(WARD_PLAYER_LIGHT_TILES * float(tile_size.x))
		for light_variant: Variant in overlay.get("static_lights", []) as Array:
			var light := light_variant as Dictionary
			positions.append(light.get("pos", Vector2.ZERO) as Vector2)
			radii.append(float(light.get("radius", 0.0)))
		for sconce_variant: Variant in flames:
			if positions.size() >= WARD_LIGHT_MAX:
				break
			var sconce := sconce_variant as Dictionary
			positions.append(sconce.get("pos", Vector2.ZERO) as Vector2)
			var flicker := 1.0 + 0.07 * sin(flicker_phase * 8.0 + float(sconce.get("phase", 0.0)))
			radii.append(float(sconce.get("radius", 0.0)) * flicker)
		ward_material.set_shader_parameter("light_count", positions.size())
		ward_material.set_shader_parameter("light_pos", positions)
		ward_material.set_shader_parameter("light_radius", radii)

## --- Digging the massif from inside -----------------------------------------
## The mountain is minable in the SAME scene: adjacent clicks swing at
## massif rock with the hold's tool ladder, durability follows the hold
## site's own geology, breaks pay Stone (and sometimes the tile's
## advertised ore), and dug cells persist per site in world settings so
## carved galleries survive streaming and reloads.
const WARD_DIG_TOOL_DAMAGE := {
	# Names match the real items the shops sell and drops grant - the
	# old "Miner's Pick"/"Rusty Pick" spellings existed nowhere, so a
	# bought pickaxe never actually dug any better.
	"Dwarven Pickaxe": 12, "Steel Pickaxe": 8, "Miner's Pickaxe": 6,
	"Copper Pick": 5, "Worn Pickaxe": 4, "Rusty Pickaxe": 4
}
const WARD_HAND_DIG_DAMAGE := 3
const WARD_DIG_ORE_CHANCE_PERCENT := 9
const WARD_SWING_COOLDOWN := 0.35
const WARD_DUG_SETTINGS_KEY := "hold_ward_dug"

var _ward_rock_damage: Dictionary = {}
var _ward_swing_timer := 0.0
var _massif_rock_coords_set: Dictionary = {}

func _is_ward_rock_cell(cell: Vector2i) -> bool:
	if city_layer.get_cell_source_id(cell) != 0:
		return false
	if _massif_rock_coords_set.is_empty():
		for rock_key: String in ["massif_rock", "massif_rock_dark", "massif_rock_top"]:
			var coords := TILE_ATLAS.get(rock_key, Vector2i(-1, -1)) as Vector2i
			if coords.x >= 0:
				_massif_rock_coords_set[coords] = true
	return _massif_rock_coords_set.has(city_layer.get_cell_atlas_coords(cell))

## The geology the swing digs by: the nearest hold gate's recorded tile
## profile (the same one its tooltip and mines advertise).
func _ward_geology_for_cell(cell: Vector2i) -> Dictionary:
	for gate: Dictionary in _surface_gates:
		var site := gate.get("site", {}) as Dictionary
		if String(site.get("class", "")) != "dwarfhold":
			continue
		var gate_anchor := gate.get("anchor", Vector2i.ZERO) as Vector2i
		if maxi(absi(gate_anchor.x - cell.x), absi(gate_anchor.y - cell.y)) <= HOLD_CITY_HALF_H * 2 + 6:
			var geology_variant: Variant = site.get("geology")
			if geology_variant is Dictionary:
				return geology_variant as Dictionary
	return {}

func _ward_site_key_for_cell(cell: Vector2i) -> String:
	for gate: Dictionary in _surface_gates:
		var site := gate.get("site", {}) as Dictionary
		if String(site.get("class", "")) != "dwarfhold":
			continue
		var gate_anchor := gate.get("anchor", Vector2i.ZERO) as Vector2i
		if maxi(absi(gate_anchor.x - cell.x), absi(gate_anchor.y - cell.y)) <= HOLD_CITY_HALF_H * 2 + 6:
			return String(gate.get("key", ""))
	return ""

func _swing_at_ward_rock(cell: Vector2i) -> void:
	if _ward_swing_timer > 0.0:
		return
	_ward_swing_timer = WARD_SWING_COOLDOWN
	var damage := WARD_HAND_DIG_DAMAGE
	for tool_name: String in WARD_DIG_TOOL_DAMAGE.keys():
		if int(_player_inventory.get(tool_name, 0)) > 0:
			damage = maxi(damage, int(WARD_DIG_TOOL_DAMAGE[tool_name]))
	var geology := _ward_geology_for_cell(cell)
	var rock_hp := 12
	if not geology.is_empty():
		var layer := GeologyService.layer_class_for_depth(geology, 0)
		rock_hp = int(GeologyService.LAYER_DURABILITY.get(layer, 12))
	var total_damage := int(_ward_rock_damage.get(cell, 0)) + damage
	if total_damage >= rock_hp:
		_dig_ward_rock(cell, geology)
		return
	_ward_rock_damage[cell] = total_damage
	TileBreakFxService.chip_burst(city_layer, _cell_center_position(cell), Color(0.55, 0.55, 0.58, 1.0), 5)

func _dig_ward_rock(cell: Vector2i, geology: Dictionary) -> void:
	_ward_rock_damage.erase(cell)
	var art := TileBreakFxService.tile_art(city_layer, cell)
	_place_hold_tile(city_layer, cell, "dirt")
	decor_layer.erase_cell(cell)
	_surface_blocked_cells.erase(cell)
	_add_to_inventory("Stone", 1)
	# The pick finds what the tile's tooltip promised.
	if not geology.is_empty() and randi_range(1, 100) <= WARD_DIG_ORE_CHANCE_PERCENT:
		var metals := geology.get("metals", []) as Array
		if not metals.is_empty():
			var ore := "%s Ore" % String(metals[randi_range(0, metals.size() - 1)])
			_add_to_inventory(ore, 1)
			_spawn_floating_text("Struck %s!" % ore, _cell_center_position(cell), Color(0.95, 0.85, 0.5, 1.0))
	if not art.is_empty():
		TileBreakFxService.topple_ghost(city_layer, _cell_center_position(cell), art["texture"] as Texture2D, art["region"] as Rect2, 1.0)
	TileBreakFxService.chip_burst(city_layer, _cell_center_position(cell), Color(0.55, 0.55, 0.58, 1.0), 12)
	_record_ward_dig(cell)

## Dug galleries persist per hold site: {site_key: ["x,y", ...]} in the
## shared world settings, re-applied whenever the massif re-stamps.
func _record_ward_dig(cell: Vector2i) -> void:
	var site_key := _ward_site_key_for_cell(cell)
	if site_key.is_empty():
		return
	var settings: Dictionary = _world_settings_snapshot()
	var dug: Dictionary = settings.get(WARD_DUG_SETTINGS_KEY, {}) as Dictionary if settings.get(WARD_DUG_SETTINGS_KEY) is Dictionary else {}
	var cells: Array = dug.get(site_key, []) as Array
	var cell_key := "%d,%d" % [cell.x, cell.y]
	if not cells.has(cell_key):
		cells.append(cell_key)
	dug[site_key] = cells
	settings[WARD_DUG_SETTINGS_KEY] = dug
	_store_world_settings(settings)

## Re-opens previously dug massif cells after a (re)stamp. Pass a rect
## to limit the pass to one chunk's slice (the landmark streamer's case).
func _apply_ward_digs(site_key: String, within_rect: Rect2i = Rect2i()) -> void:
	if site_key.is_empty():
		return
	var settings: Dictionary = _world_settings_snapshot()
	var dug: Dictionary = settings.get(WARD_DUG_SETTINGS_KEY, {}) as Dictionary if settings.get(WARD_DUG_SETTINGS_KEY) is Dictionary else {}
	for cell_key_variant: Variant in (dug.get(site_key, []) as Array):
		var parts := String(cell_key_variant).split(",")
		if parts.size() != 2:
			continue
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		if within_rect.has_area() and not within_rect.has_point(cell):
			continue
		_place_hold_tile(city_layer, cell, "dirt")
		decor_layer.erase_cell(cell)
		_surface_blocked_cells.erase(cell)

## One random step every couple of seconds, on walkable ground only.
func _update_ward_dwarves(delta: float) -> void:
	for dwarf: Dictionary in _ward_dwarves:
		dwarf["timer"] = float(dwarf.get("timer", 1.0)) - delta
		if float(dwarf["timer"]) > 0.0:
			continue
		dwarf["timer"] = randf_range(1.2, 3.0)
		var cell := dwarf.get("cell", Vector2i.ZERO) as Vector2i
		var options: Array[Vector2i] = []
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var step := cell + offset
			if _is_passable_cell_for_actor(step) and step != _player_cell:
				options.append(step)
		if options.is_empty():
			continue
		var next_cell := options[randi_range(0, options.size() - 1)]
		dwarf["cell"] = next_cell
		var sprite := dwarf.get("sprite") as Sprite2D
		if sprite != null and is_instance_valid(sprite):
			sprite.position = _cell_center_position(next_cell)

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
	if _surface_gates.is_empty() or _player_sprite == null:
		return
	if _surface_arrival_lock:
		# Re-arm once the walker steps off the gate they left through,
		# so gates survive the scene being parked and revived.
		if not _player_on_any_gate_cell():
			_surface_arrival_lock = false
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

func _player_on_any_gate_cell() -> bool:
	for gate: Dictionary in _surface_gates:
		var trigger_cells := gate.get("trigger_cells", []) as Array
		if trigger_cells.is_empty():
			if (gate.get("rect", Rect2i()) as Rect2i).has_point(_player_cell):
				return true
			continue
		for trigger_variant: Variant in trigger_cells:
			if (trigger_variant as Vector2i) == _player_cell:
				return true
	return false

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
			# Street-lamp glows die with their chunk; the deterministic
			# lamp pass re-lights them when the road streams back in.
			var lamp_glow := _lamp_glow_sprites.get(cell) as Sprite2D
			if lamp_glow != null:
				lamp_glow.queue_free()
				_lamp_glow_sprites.erase(cell)
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
			# Ward dwarves, sconces and the darkness quad evaporate with
			# their ward's ground; the re-stamp on return rebuilds them.
			_free_ward_dwarves_for_key(String(gate.get("key", "")))
			_free_ward_overlay_for_key(String(gate.get("key", "")))
		# Landmark footprints release this chunk's slice (sprites, blocked
		# cells); the cached plan re-stamps it identically on return.
		for landmark: Dictionary in _surface_landmarks:
			if (landmark.get("stamped_chunks", {}) as Dictionary).has(chunk):
				_unstamp_surface_landmark_chunk(landmark, chunk, chunk_cells)

## --- Life on the surface -------------------------------------------------
## The radial rule made flesh: danger at the player's feet decides how
## many creatures stalk them and how mean those creatures are, deep-wild
## hours roll ambush dice, and the roads carry travelers worth meeting.

func _update_surface_life(delta: float) -> void:
	if _surface_noise.is_empty() or _player_sprite == null:
		return
	_update_ward_dwarves(delta)
	_update_ward_darkness()
	_ward_swing_timer = maxf(0.0, _ward_swing_timer - delta)
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
	_update_wilds_keepers(delta)
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
	var fallen_site_key := String(state.get("site_key", ""))
	var is_boss := bool(state.get("boss", false))
	_surface_creatures.remove_at(creature_index)
	if is_boss:
		# A named beast, not a camp band: trophy, hoard, and recorded
		# history instead of tent plunder.
		_award_surface_lair_kill(state)
		return
	_set_save_status("The %s falls — %d coins scavenged." % [creature_name, coins], Color(0.85, 0.95, 0.7, 1.0))
	# The last of a camp's garrison marks the site cleared (with plunder).
	if not fallen_site_key.is_empty():
		_note_camp_creature_down(fallen_site_key)

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
## Season re-rates the growing hour; rain (or a storm) waters for free.
const FARM_SEASON_GROWTH := {"Spring": 1.15, "Summer": 1.0, "Autumn": 0.85, "Winter": 0.2}
const FARM_RAIN_GROWTH_BONUS := 1.25
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
	if _player_hotbar != null:
		_player_hotbar.refresh()
	if GearService.TRINKET_DEFS.has(item_name):
		_refresh_player_stats_town()
	_refresh_held_item()
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
	return {
		"hp": _player_hp,
		"max_hp": _player_max_hp,
		"satiety": _player_satiety,
		"coins": _player_coins,
		"game_day": _game_day,
		"game_hour": _game_hour,
		"calendar_start_year": _calendar_start_year,
		"place_name": _town_name if not _town_name.is_empty() else "Unnamed Town",
		"factions": _settlement_factions,
		"companion_attack": int(_companion.get("attack", 0))
	}

func _on_equipment_changed() -> void:
	_refresh_player_stats_town()
	_populate_backpack_slots()
	_save_player_inventory()
	if _player_hotbar != null:
		_player_hotbar.refresh()
	_refresh_held_item()

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
	_player_hotbar.set_selected(_selected_hotbar_index)
	_player_hotbar.reposition.call_deferred()
	_refresh_held_item()

func _hotbar_index_for_keycode(keycode: int) -> int:
	if keycode >= KEY_1 and keycode <= KEY_9:
		return keycode - KEY_1
	if keycode == KEY_0:
		return 9
	return -1

## --- held item ----------------------------------------------------------

## Resolves the selected slot's bound item (only if at least one is packed)
## and shows it in the player's hand; anything else clears the sprite.
func _refresh_held_item() -> void:
	if _player_sprite == null:
		return
	var held_item := ""
	if _selected_hotbar_index >= 0:
		var settings: Dictionary = _world_settings_snapshot()
		var bindings: Array = GearService.hotbar_bindings(settings)
		if _selected_hotbar_index < bindings.size():
			var candidate := String(bindings[_selected_hotbar_index])
			if not candidate.is_empty() and int(_player_inventory.get(candidate, 0)) >= 1:
				held_item = candidate
	HeldItemService.update(_player_sprite, held_item, tile_size)
	if _player_hotbar != null:
		_player_hotbar.set_selected(_selected_hotbar_index)

## --- ground items (drag-to-drop, walk-over to reclaim) ------------------

## Docks the invisible drop catcher inside the map panel. Kept a child of
## CityPanel with MOUSE_FILTER_PASS so plain clicks/pans still reach the
## panel's gui_input, while a slot drag released over open world falls to
## this control (the hotbar/inventory sit above it and swallow slot-to-slot
## drags first).
func _setup_drop_catcher() -> void:
	if city_panel == null:
		return
	_drop_catcher = Control.new()
	_drop_catcher.name = "WorldDropCatcher"
	_drop_catcher.mouse_filter = Control.MOUSE_FILTER_PASS
	_drop_catcher.set_drag_forwarding(
		Callable(),
		Callable(self, "_catcher_can_drop"),
		Callable(self, "_catcher_drop")
	)
	city_panel.add_child(_drop_catcher)

func _catcher_can_drop(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and String((data as Dictionary).get("kind", "")) == "item_drop"

func _catcher_drop(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var payload := data as Dictionary
	if String(payload.get("kind", "")) != "item_drop":
		return
	_drop_item_to_ground(String(payload.get("item", "")), 1)

## Takes `count` of an item out of the pack and lays it on the ground at the
## player's feet (or the nearest free neighbour), where walking back over it
## picks it up again.
func _drop_item_to_ground(item_name: String, count: int) -> bool:
	if item_name.is_empty() or count <= 0:
		return false
	if int(_player_inventory.get(item_name, 0)) < count:
		_set_save_status("No %s to drop." % item_name, Color(0.95, 0.75, 0.45, 1.0))
		return false
	var texture := ItemDefsService.icon_texture(item_name)
	if texture == null:
		return false
	var drop_cell := _free_ground_cell(_player_cell)
	_add_to_inventory(item_name, -count)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 6
	sprite.scale = Vector2.ONE * (float(tile_size.y) * 0.6 / 32.0)
	sprite.position = _cell_center_position(drop_cell)
	actor_layer.add_child(sprite)
	# "armed" only once the player steps off the drop cell, so an item laid
	# at your own feet waits to be walked back over instead of snapping
	# straight back into the pack the next frame.
	_ground_items.append({"sprite": sprite, "cell": drop_cell, "item": item_name, "count": count, "armed": _player_cell != drop_cell})
	_set_save_status("Dropped %s ×%d" % [item_name, count], Color(0.85, 0.85, 0.7, 1.0))
	return true

## Frees dropped-item sprites and empties the list, so a level/scene rebuild
## can't leave stale entries that re-grant items when the player stands on a
## matching cell afterward.
func _clear_ground_items() -> void:
	for entry: Dictionary in _ground_items:
		var sprite := entry.get("sprite") as Sprite2D
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
	_ground_items.clear()

func _update_ground_items(_delta: float) -> void:
	if _ground_items.is_empty() or _player_sprite == null:
		return
	for index in range(_ground_items.size() - 1, -1, -1):
		var entry := _ground_items[index]
		var entry_cell := entry.get("cell", Vector2i.ZERO) as Vector2i
		if entry_cell != _player_cell:
			# Stepped off: this item can now be reclaimed on return.
			entry["armed"] = true
			continue
		if not bool(entry.get("armed", true)):
			continue
		var item_name := String(entry.get("item", ""))
		var count := int(entry.get("count", 1))
		var sprite := entry.get("sprite") as Sprite2D
		if sprite != null:
			sprite.queue_free()
		_ground_items.remove_at(index)
		_add_to_inventory(item_name, count)
		_set_save_status("Picked up %s ×%d" % [item_name, count], Color(0.7, 0.95, 0.6, 1.0))
		if _player_hotbar != null:
			_player_hotbar.refresh()
		_refresh_held_item()

## The player's cell if it holds no loot yet, else the closest walkable,
## unoccupied neighbour so two drops never stack on one tile.
func _free_ground_cell(origin: Vector2i) -> Vector2i:
	if not _ground_cell_occupied(origin):
		return origin
	for offset: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP, Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var candidate := origin + offset
		if _is_walkable_cell(candidate) and not _ground_cell_occupied(candidate):
			return candidate
	return origin

func _ground_cell_occupied(cell: Vector2i) -> bool:
	for entry: Dictionary in _ground_items:
		if (entry.get("cell", Vector2i.ZERO) as Vector2i) == cell:
			return true
	return false

## The quick keys: potions drink, food eats, the hoe arms till mode,
## anything else just reports itself.
func _use_hotbar_slot(index: int) -> void:
	var settings: Dictionary = _world_settings_snapshot()
	var bindings: Array = GearService.hotbar_bindings(settings)
	var item_name := String(bindings[index]) if index < bindings.size() else ""
	# Record the pick before any early-out so the held-item sprite tracks
	# the current selection (an empty or dry slot simply shows nothing).
	_selected_hotbar_index = index
	_refresh_held_item()
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
	if item_name == "Iron Hoe":
		for entry_index in TOWN_BUILD_CATALOG.size():
			if String((TOWN_BUILD_CATALOG[entry_index] as Dictionary).get("kind", "")) == "till":
				_build_selection = entry_index
				_set_save_status("🔨 Till Soil armed — click grass beside you.", Color(0.85, 0.9, 0.75, 1.0))
				return
	if ANIMAL_CRATES.has(item_name):
		_crate_armed = item_name
		_set_save_status("🐾 %s armed — click open grass beside you to release the %s." % [item_name, String(ANIMAL_CRATES[item_name])], Color(0.85, 0.9, 0.75, 1.0))
		return
	_set_save_status("%s ×%d in the pack." % [item_name, int(_player_inventory.get(item_name, 0))], Color(0.8, 0.8, 0.8, 1.0))

## Eating above ground: mends and feeds, same math as the hold.
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
	GameAudioService.play_sfx(self, "eat")
	if _player_sprite != null:
		_spawn_floating_text("+%d" % heal, _player_sprite.position, Color(0.5, 0.95, 0.5, 1.0))
	_set_save_status("Ate %s (+%d)" % [item_name, heal], Color(0.7, 0.95, 0.6, 1.0))

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
		_drink_potion(potion_name)
		return
	_set_save_status("No potions in the pack — apothecaries and road peddlers sell them.", Color(0.8, 0.8, 0.8, 1.0))

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
		_refresh_player_stats_town()
		_set_save_status("You drink the %s — %s hums in your blood." % [potion_name, String(result.get("buff", ""))], Color(0.8, 0.75, 0.95, 1.0))

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
	# Family-based so the grass/sand/snow-lapped shoreline pieces still count
	# as water: they block walkers, take a boat, reflect, and fish.
	return _family_for_atlas_coords(city_layer.get_cell_atlas_coords(cell)) == "water"

## --- Water reflections -------------------------------------------------------
## The shore mirrors whoever stands on it, Core Keeper style: a quad over
## the visible water re-samples the drawn screen a mirrored distance above
## each pixel. The quad follows the view; its cell mask (water flag +
## rows-of-water-above, which locates each column's shoreline) rebuilds
## when the view moves to new cells or the refresh timer laps, so
## streamed wilds ponds and coasts reflect too.

const REFLECTION_VIEW_MARGIN_CELLS := 6
const REFLECTION_REFRESH_SECONDS := 2.0
const REFLECTION_MAX_MASK_CELLS := Vector2i(220, 150)

func _update_water_reflection(delta: float) -> void:
	_reflection_rebuild_timer -= delta
	var panel_size := city_panel.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0 or _latest_grid.is_empty():
		return
	var zoom := maxf(_zoom_level, 0.001)
	var top_left := (Vector2.ZERO - city_layer.position) / zoom
	var bottom_right := (panel_size - city_layer.position) / zoom
	var min_cell := Vector2i(
		floori(top_left.x / float(tile_size.x)) - REFLECTION_VIEW_MARGIN_CELLS,
		floori(top_left.y / float(tile_size.y)) - REFLECTION_VIEW_MARGIN_CELLS
	)
	var max_cell := Vector2i(
		ceili(bottom_right.x / float(tile_size.x)) + REFLECTION_VIEW_MARGIN_CELLS,
		ceili(bottom_right.y / float(tile_size.y)) + REFLECTION_VIEW_MARGIN_CELLS
	)
	var rect := Rect2i(min_cell, (max_cell - min_cell).clamp(Vector2i.ONE, REFLECTION_MAX_MASK_CELLS))
	if rect == _reflection_rect_cells and _reflection_rebuild_timer > 0.0:
		return
	_reflection_rect_cells = rect
	_reflection_rebuild_timer = REFLECTION_REFRESH_SECONDS
	_rebuild_reflection_mask(rect)

func _rebuild_reflection_mask(rect: Rect2i) -> void:
	_ensure_reflection_sprite()
	var image := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RG8)
	var any_water := false
	for y in rect.size.y:
		for x in rect.size.x:
			var cell := rect.position + Vector2i(x, y)
			if not _is_water_cell(cell):
				continue
			any_water = true
			var rows_above := 0
			while rows_above < 15 and _is_water_cell(cell + Vector2i(0, -(rows_above + 1))):
				rows_above += 1
			image.set_pixel(x, y, Color(1.0, float(rows_above) / 16.0, 0.0))
	_reflection_sprite.visible = any_water
	if not any_water:
		return
	if _reflection_mask_texture != null and Vector2i(_reflection_mask_texture.get_size()) == rect.size:
		_reflection_mask_texture.update(image)
	else:
		_reflection_mask_texture = ImageTexture.create_from_image(image)
	var reflection_material := _reflection_sprite.material as ShaderMaterial
	reflection_material.set_shader_parameter("reflection_mask", _reflection_mask_texture)
	reflection_material.set_shader_parameter("mask_cells", Vector2(rect.size))
	reflection_material.set_shader_parameter("tile_px", float(tile_size.x))
	reflection_material.set_shader_parameter("view_zoom", _zoom_level)
	_reflection_sprite.position = Vector2(rect.position * tile_size)
	_reflection_sprite.scale = Vector2(rect.size * tile_size)

func _ensure_reflection_sprite() -> void:
	if _reflection_sprite != null and is_instance_valid(_reflection_sprite) and _reflection_sprite.get_parent() == actor_layer:
		return
	_reflection_sprite = Sprite2D.new()
	_reflection_sprite.name = "WaterReflection"
	_reflection_sprite.centered = false
	var white := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	_reflection_sprite.texture = ImageTexture.create_from_image(white)
	# Above every reflectable actor and prop, below the light overlay
	# (14) and floating text (30), so lighting still dims the water and
	# UI chatter never shows in it.
	_reflection_sprite.z_index = 13
	var reflection_material := ShaderMaterial.new()
	reflection_material.shader = WATER_REFLECTION_SHADER
	reflection_material.set_shader_parameter("rain_ripple", _weather_rain_ripple())
	_reflection_sprite.material = reflection_material
	actor_layer.add_child(_reflection_sprite)

func _set_boating(boating: bool) -> void:
	if _player_boating == boating:
		return
	_player_boating = boating
	GameAudioService.play_sfx(self, "splash")
	if boating and _player_mounted:
		_toggle_mount()
	# A level rebuild can free the sprite under us; treat a dead ref as absent.
	if not is_instance_valid(_boat_sprite) and _player_sprite != null:
		_boat_sprite = Sprite2D.new()
		_boat_sprite.texture = BOAT_SPRITE_TEXTURE
		_boat_sprite.position = Vector2(0.0, 4.0)
		# Behind the rider but above the water tiles.
		_boat_sprite.show_behind_parent = true
		_boat_sprite.scale = Vector2.ONE
		_player_sprite.add_child(_boat_sprite)
	if is_instance_valid(_boat_sprite):
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
	# Cancel any in-flight step so its arrival can't drag the boater back
	# onto the departed land cell.
	_player_is_moving = false
	_player_move_path.clear()
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
	# A level rebuild can free the sprite under us; treat a dead ref as absent.
	if not is_instance_valid(_mount_sprite) and _player_sprite != null:
		var pig_texture := load("res://resources/images/webgame_tiles/Farm/Tiled_files/Pig_animation.png") as Texture2D
		if pig_texture != null:
			_mount_sprite = Sprite2D.new()
			_mount_sprite.texture = pig_texture
			_mount_sprite.region_enabled = true
			_mount_sprite.region_rect = Rect2(0, 0, 32, 32)
			_mount_sprite.position = Vector2(0.0, 4.0)
			_mount_sprite.show_behind_parent = true
			_mount_sprite.scale = Vector2.ONE
			_player_sprite.add_child(_mount_sprite)
	if is_instance_valid(_mount_sprite):
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
	# Ground under a build follows the biome swap (snow/sand), never raw grass.
	if city_layer.get_cell_source_id(cell) < 0:
		_place_tile(city_layer, cell, _wall_ground_fill_tile())
	if _build_kind_for_tile(tile_key) == "base":
		_place_tile(city_layer, cell, tile_key)
		decor_layer.erase_cell(cell)
	else:
		_place_tile(decor_layer, cell, tile_key)
	_actor_passable_cache.erase(cell)

## Re-stamps every owned build and field whose cell _render_city overpainted:
## only cells the city pass tiled (the town rect plus its grow(1) border
## ring) have ground here, so this is a no-op for builds out in streamed-
## chunk territory - their cells are still untiled and _ensure_surface_chunk
## re-stamps them when their chunk paints.
func _restamp_player_builds() -> void:
	for cell_variant: Variant in _player_built_cells.keys():
		var cell := cell_variant as Vector2i
		if city_layer.get_cell_source_id(cell) >= 0:
			_stamp_player_build(cell, String(_player_built_cells[cell_variant]))
	for plot_variant: Variant in _farm_plots.keys():
		var plot_cell := plot_variant as Vector2i
		if city_layer.get_cell_source_id(plot_cell) >= 0:
			_stamp_farm_plot(plot_cell)

func _remove_player_build(cell: Vector2i) -> void:
	var tile_key := String(_player_built_cells.get(cell, ""))
	_player_built_cells.erase(cell)
	_wall_damage.erase(cell)
	if _build_kind_for_tile(tile_key) == "base":
		# Repaint the biome's own ground so snow and desert homesteads don't
		# get a bright green patch where a build once stood.
		_place_tile(city_layer, cell, _wall_ground_fill_tile())
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
	# Any grass-family ground takes the hoe, including the dark-grass patch
	# fringes and mottled blends (family-based, so new variants stay covered).
	var family := _family_for_atlas_coords(city_layer.get_cell_atlas_coords(cell))
	return family == "grass" or family == "grass_dark"

func _try_till_cell(cell: Vector2i) -> bool:
	if int(_player_inventory.get("Iron Hoe", 0)) < 1:
		_set_save_status("Tilling wants an Iron Hoe — tinkers on the road sell them.", Color(0.95, 0.75, 0.45, 1.0))
		return true
	if not _can_till_cell(cell):
		_set_save_status("Only open grass takes the hoe.", Color(0.95, 0.75, 0.45, 1.0))
		return true
	_farm_plots[cell] = {"crop": "", "stage": 0, "planted_h": 0.0}
	_stamp_farm_plot(cell)
	# A new plot closes its neighbors' masks: restamp adjoining plots so a
	# growing field knits together instead of keeping stale inner fringes.
	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			var neighbor := cell + Vector2i(offset_x, offset_y)
			if neighbor != cell and _farm_plots.has(neighbor):
				_stamp_farm_plot(neighbor)
	_persist_farm()
	GameAudioService.play_sfx(self, "till")
	_set_save_status("You turn the earth. Click the plot with seeds in your pack to plant.", Color(0.75, 0.92, 0.7, 1.0))
	return true

## The tilled piece for a worked cell: fringe toward any bordering grass so
## a plot frays into its lawn instead of cutting a hard brown square.
## members marks sibling tilled cells (they stay flush with each other).
func _tilled_tile_key(cell: Vector2i, members: Dictionary) -> String:
	var suffix := TownTileService.fringe_suffix(
		_tilled_side_open(cell + Vector2i(0, -1), members),
		_tilled_side_open(cell + Vector2i(0, 1), members),
		_tilled_side_open(cell + Vector2i(-1, 0), members),
		_tilled_side_open(cell + Vector2i(1, 0), members),
		_tilled_side_open(cell + Vector2i(-1, -1), members),
		_tilled_side_open(cell + Vector2i(1, -1), members),
		_tilled_side_open(cell + Vector2i(-1, 1), members),
		_tilled_side_open(cell + Vector2i(1, 1), members),
		true, cell.x, cell.y)
	return "tilled_soil" if suffix.is_empty() else "tilled_" + suffix

func _tilled_side_open(neighbor: Vector2i, members: Dictionary) -> bool:
	if members.has(neighbor):
		return false
	if city_layer.get_cell_source_id(neighbor) < 0:
		return false
	var family := _family_for_atlas_coords(city_layer.get_cell_atlas_coords(neighbor))
	return family == "grass" or family == "grass_dark"

func _stamp_farm_plot(cell: Vector2i) -> void:
	var plot := _farm_plots.get(cell, {}) as Dictionary
	if plot.is_empty():
		return
	_place_tile(city_layer, cell, _tilled_tile_key(cell, _farm_plots))
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
	# Stages read elapsed hours since planted_h, so season and rain re-rate
	# growth by sliding the planting stamp. Scale the slide by the hours
	# actually elapsed since the last re-rate (usually 1) so a stall or a
	# fast clock that jumps several hours in a frame is rated in full.
	var elapsed := 1.0 if _farm_last_growth_hours < 0.0 else clampf(now_hours - _farm_last_growth_hours, 0.0, 48.0)
	_farm_last_growth_hours = now_hours
	var stamp_shift := (1.0 - _farm_growth_multiplier()) * elapsed
	var changed := false
	for cell_variant: Variant in _farm_plots.keys():
		var plot := _farm_plots[cell_variant] as Dictionary
		if String(plot.get("crop", "")).is_empty():
			continue
		if absf(stamp_shift) > 0.001:
			plot["planted_h"] = float(plot.get("planted_h", now_hours)) + stamp_shift
			changed = true
		var stage := clampi(int((now_hours - float(plot.get("planted_h", now_hours))) / FARM_STAGE_HOURS), 0, 2)
		if stage != int(plot.get("stage", 0)):
			plot["stage"] = stage
			_stamp_farm_plot(cell_variant as Vector2i)
			changed = true
	if changed:
		_persist_farm()

func _farm_growth_multiplier() -> float:
	var multiplier := float(FARM_SEASON_GROWTH.get(GameCalendar.season_for_day(_game_day - 1), 1.0))
	var kind := String(_current_weather.get("kind", "clear"))
	if kind == WeatherService.KIND_RAIN or kind == WeatherService.KIND_STORM:
		multiplier *= FARM_RAIN_GROWTH_BONUS
	return multiplier

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
	# Only an ARMED crate releases (use it from the hotbar first) - a
	# crate riding in the pack must not fire on ordinary walk clicks.
	if _crate_armed.is_empty():
		return false
	if not _is_player_adjacent_to_cell(cell) or cell == _player_cell:
		return false
	var crate_name := _crate_armed
	if int(_player_inventory.get(crate_name, 0)) < 1:
		_crate_armed = ""
		return false
	if not _is_walkable_cell(cell) or _is_cell_occupied_by_npc(cell):
		return false
	_crate_armed = ""
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
	# The farm sheets are drawn at 32px-per-tile density: the cow's 64px
	# frame means it IS a two-tile beast. Scale by pixel density, not
	# frame-fit, or the cow shrinks down to chicken size.
	sprite.scale = Vector2.ONE * (float(tile_size.y) / 32.0)
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
	var choppable := false
	for tree_key: String in ["tree", "tree_dark", "tree_snowy", "tree_dark_snowy"]:
		if atlas_coords == (TILE_ATLAS.get(tree_key, Vector2i(-1, -1)) as Vector2i):
			choppable = true
			break
	if not choppable:
		return false
	# Grab the tree's art before it is cleared so the break FX can topple a
	# ghost of it; the tree leans away from the player as it falls.
	var art := TileBreakFxService.tile_art(decor_layer, cell)
	decor_layer.erase_cell(cell)
	_actor_passable_cache.erase(cell)
	_add_to_inventory("Timber", 2)
	GameAudioService.play_sfx(self, "harvest")
	var fell_position := _cell_center_position(cell)
	var lean_sign := 1.0 if cell.x >= _player_cell.x else -1.0
	if not art.is_empty():
		TileBreakFxService.topple_ghost(city_layer, fell_position, art["texture"] as Texture2D, art["region"] as Rect2, lean_sign)
	TileBreakFxService.chip_burst(city_layer, fell_position, Color(0.36, 0.55, 0.22, 1.0), 14)
	_spawn_floating_text("+2 Timber", fell_position, Color(0.8, 0.95, 0.7, 1.0))
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
	# The leash measures from where the traveler stands, not the synthetic
	# far-away stock anchor, so a single step can't slam the popup shut.
	_trade_leash_cell = state.get("cell", _player_cell) as Vector2i
	_trade_shop_type = stock_type
	chest_popup.visible = true
	chest_popup_title.text = "Trade — %s" % String(state.get("npc_name", "A traveler"))
	chest_popup_take_all_button.disabled = true
	var section_label := chest_popup.find_child("ChestSectionLabel", true, false) as Label
	if section_label != null:
		section_label.text = _with_market_hint("Wares from the pack")
	_refresh_trade_panel()
	return true

## --- caravan escort ------------------------------------------------------------
## The market's merchant doubles as caravan master: sign on, walk beside
## the wagon out to a waypost in the wilds, fight off the ambushes, get
## paid on arrival. Scene-local - leaving town abandons the job.

const CARAVAN_STEP_SECONDS := 0.4
const CARAVAN_SPRITE_SPEED := 96.0
const CARAVAN_GUARD_RANGE := 10
const CARAVAN_ROUTE_MIN := 90
const CARAVAN_ROUTE_MAX := 130
const CARAVAN_WAGON_HP := 6
const CARAVAN_HIT_BEAT_SECONDS := 1.2
const CARAVAN_OFFER_COOLDOWN_HOURS := 24.0
## The covered stall from the farm sheet reads as a covered wagon in motion.
const CARAVAN_WAGON_CROP := Rect2(132, 90, 74, 52)

func _caravan_master_state() -> Dictionary:
	for state: Dictionary in _npc_states:
		if int(state.get("role", -1)) == ROLE_MERCHANT and not bool(state.get("traveler", false)):
			return state
	return {}

## Coins the master would offer this NPC's caller right now; 0 means no
## offer (not the master, job running, or cooling down after the last run).
func _caravan_offer_pay(state: Dictionary) -> int:
	if not _caravan_job.is_empty() or _surface_road_paths.is_empty():
		return 0
	if not is_same(state, _caravan_master_state()):
		return 0
	if float(_game_day) * 24.0 + _game_hour < _caravan_next_offer_stamp:
		return 0
	return SettlementEconomyService.caravan_pay((CARAVAN_ROUTE_MIN + CARAVAN_ROUTE_MAX) / 2, WorldEventsService.recent_events(_world_settings_snapshot(), 12))

func _show_caravan_offer() -> void:
	if _caravan_offer_dialog == null:
		_caravan_offer_dialog = ConfirmationDialog.new()
		_caravan_offer_dialog.title = "Caravan Escort"
		_caravan_offer_dialog.ok_button_text = "Sign on"
		_caravan_offer_dialog.cancel_button_text = "Not today"
		_caravan_offer_dialog.confirmed.connect(_on_caravan_offer_confirmed)
		add_child(_caravan_offer_dialog)
	var pay := _caravan_offer_pay(_caravan_master_state())
	_caravan_offer_dialog.dialog_text = "\"Wagon's loaded for the waypost and the roads are ugly.\nWalk guard beside it and there's ~%d coins on arrival.\"" % pay
	_caravan_offer_dialog.popup_centered()

func _on_caravan_offer_confirmed() -> void:
	_start_caravan_job(_caravan_master_state())

func _start_caravan_job(master_state: Dictionary) -> void:
	if not _caravan_job.is_empty() or master_state.is_empty():
		return
	var route := _build_caravan_route(master_state.get("cell", _player_cell) as Vector2i)
	if route.size() < CARAVAN_ROUTE_MIN / 2:
		_set_save_status("The caravan master squints at the roads and shakes his head — no route today.", Color(0.8, 0.8, 0.8, 1.0))
		return
	var pay := SettlementEconomyService.caravan_pay(route.size(), WorldEventsService.recent_events(_world_settings_snapshot(), 12))
	var start_position := _cell_center_position(route[0])
	var wagon_sprite := Sprite2D.new()
	wagon_sprite.texture = FARM_HOUSES_TEXTURE
	wagon_sprite.region_enabled = true
	wagon_sprite.region_rect = CARAVAN_WAGON_CROP
	wagon_sprite.position = start_position
	wagon_sprite.z_index = 12
	actor_layer.add_child(wagon_sprite)
	var traders: Array[Dictionary] = []
	for trader_index: int in range(2):
		traders.append(_spawn_caravan_trader(route[0], trader_index))
	_caravan_job = {
		"route": route,
		"route_index": 0,
		"wagon_sprite": wagon_sprite,
		"wagon_hp": CARAVAN_WAGON_HP,
		"traders": traders,
		"waypost_nodes": _spawn_caravan_waypost(route[route.size() - 1]),
		"pay": pay,
		"step_timer": CARAVAN_STEP_SECONDS,
		"hit_beat": CARAVAN_HIT_BEAT_SECONDS,
		"nag_timer": 0.0,
		"ambush_marks": [route.size() / 3, (route.size() * 2) / 3]
	}
	_set_save_status("The caravan rolls out — stay within %d paces of the wagon." % CARAVAN_GUARD_RANGE, Color(0.85, 0.9, 0.75, 1.0))

func _spawn_caravan_trader(cell: Vector2i, trader_index: int) -> Dictionary:
	var identity: Dictionary = NpcIdentityService.generate(_rng, "Merchant", "townsfolk")
	var layers: Dictionary = NpcIdentityService.appearance_for_identity(identity, "human")
	var sprite := Sprite2D.new()
	sprite.texture = DwarfSpriteComposer.compose(layers)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(float(tile_size.x) / 32.0, float(tile_size.y) / 32.0) * float(layers.get("body_scale", 1.0))
	sprite.z_index = 11
	sprite.position = _cell_center_position(cell)
	actor_layer.add_child(sprite)
	return {"sprite": sprite, "hp": 6, "cell": cell, "trail": trader_index + 1}

## The waypost camp at the route's end: a roadside shelter and a name.
func _spawn_caravan_waypost(cell: Vector2i) -> Array:
	var shelter := Sprite2D.new()
	shelter.texture = FARM_HOUSES_TEXTURE
	shelter.region_enabled = true
	shelter.region_rect = FARM_BUILDING_CROPS["open_barn"] as Rect2
	shelter.centered = false
	shelter.position = _cell_center_position(cell) - Vector2(48.0, 70.0)
	shelter.z_index = 10
	actor_layer.add_child(shelter)
	var post_label := Label.new()
	post_label.text = "Trade Waypost"
	post_label.add_theme_font_size_override("font_size", 18)
	post_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82, 1.0))
	post_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06, 1.0))
	post_label.add_theme_constant_override("outline_size", 5)
	post_label.position = city_layer.map_to_local(cell + Vector2i(-2, -4))
	post_label.z_index = 30
	city_layer.add_child(post_label)
	return [shelter, post_label]

## The wagon's road: pathfind from the master's stand to the head of the
## longest surface road, then follow it out until the roll of 90-130
## cells is spent - stopping shy of the far gate so the waypost stays a
## camp, not a doorstep.
func _build_caravan_route(start_cell: Vector2i) -> Array[Vector2i]:
	var best_path: Array = []
	for path_variant: Array in _surface_road_paths:
		if path_variant.size() > best_path.size():
			best_path = path_variant
	if best_path.size() < 24:
		return []
	var route: Array[Vector2i] = [start_cell]
	var road_head := best_path[0] as Vector2i
	route.append_array(_build_player_path(start_cell, road_head))
	if route[route.size() - 1] != road_head:
		# No walkable lane to the road head; muster on the road instead.
		route = [road_head]
	var end_index := clampi(_rng.randi_range(CARAVAN_ROUTE_MIN, CARAVAN_ROUTE_MAX) - route.size(), 8, best_path.size() - 12)
	for road_index: int in range(1, end_index + 1):
		route.append(best_path[road_index] as Vector2i)
	return route

func _update_caravan_job(delta: float) -> void:
	if _caravan_job.is_empty():
		return
	var wagon_sprite := _caravan_job.get("wagon_sprite") as Sprite2D
	if wagon_sprite == null or not is_instance_valid(wagon_sprite):
		_finish_caravan_job("The caravan is lost.")
		return
	var route := _caravan_job.get("route", []) as Array
	var route_index := int(_caravan_job.get("route_index", 0))
	var wagon_cell := route[route_index] as Vector2i
	if maxi(absi(wagon_cell.x - _player_cell.x), absi(wagon_cell.y - _player_cell.y)) > CARAVAN_GUARD_RANGE:
		_caravan_job["nag_timer"] = float(_caravan_job.get("nag_timer", 0.0)) - delta
		if float(_caravan_job.get("nag_timer", 0.0)) <= 0.0:
			_caravan_job["nag_timer"] = 4.0
			_set_save_status("The caravan waits for its guard.", Color(0.95, 0.85, 0.55, 1.0))
	else:
		_caravan_job["nag_timer"] = 0.0
		_caravan_job["step_timer"] = float(_caravan_job.get("step_timer", 0.0)) - delta
		if float(_caravan_job.get("step_timer", 0.0)) <= 0.0 and route_index < route.size() - 1:
			_caravan_job["step_timer"] = CARAVAN_STEP_SECONDS
			route_index += 1
			_caravan_job["route_index"] = route_index
			wagon_sprite.flip_h = (route[route_index] as Vector2i).x < wagon_cell.x
			wagon_cell = route[route_index] as Vector2i
			_maybe_spring_caravan_ambush(route_index, wagon_cell)
	wagon_sprite.position = wagon_sprite.position.move_toward(_cell_center_position(wagon_cell), CARAVAN_SPRITE_SPEED * delta)
	_update_caravan_traders(delta, route, route_index)
	_update_caravan_damage(delta, wagon_cell)
	if _caravan_job.is_empty():
		return
	if route_index >= route.size() - 1 and wagon_sprite.position.distance_to(_cell_center_position(wagon_cell)) < 2.0:
		var pay := int(_caravan_job.get("pay", 0))
		_adjust_coins(pay)
		GameAudioService.play_sfx(self, "coin")
		_spawn_floating_text("+%d coins" % pay, wagon_sprite.position, Color(0.95, 0.8, 0.4, 1.0))
		_finish_caravan_job("The caravan reaches the waypost — %d coins for the escort." % pay, Color(0.7, 0.95, 0.7, 1.0))

## The traders trail the wagon a cell or two behind, single file.
func _update_caravan_traders(delta: float, route: Array, route_index: int) -> void:
	for trader_variant: Variant in (_caravan_job.get("traders", []) as Array):
		var trader := trader_variant as Dictionary
		var sprite := trader.get("sprite") as Sprite2D
		if sprite == null or not is_instance_valid(sprite):
			continue
		var trail_cell := route[maxi(route_index - int(trader.get("trail", 1)), 0)] as Vector2i
		trader["cell"] = trail_cell
		var target: Vector2 = _cell_center_position(trail_cell)
		sprite.flip_h = target.x < sprite.position.x
		sprite.position = sprite.position.move_toward(target, CARAVAN_SPRITE_SPEED * delta)

## Hostiles beside the wagon or its traders land a blow every beat the
## guard leaves them unanswered; the wagon splinters, the traders bleed.
func _update_caravan_damage(delta: float, wagon_cell: Vector2i) -> void:
	_caravan_job["hit_beat"] = float(_caravan_job.get("hit_beat", 0.0)) - delta
	if float(_caravan_job.get("hit_beat", 0.0)) > 0.0:
		return
	_caravan_job["hit_beat"] = CARAVAN_HIT_BEAT_SECONDS
	var wagon_sprite := _caravan_job.get("wagon_sprite") as Sprite2D
	if _any_hostile_adjacent(wagon_cell):
		_caravan_job["wagon_hp"] = int(_caravan_job.get("wagon_hp", CARAVAN_WAGON_HP)) - 2
		if wagon_sprite != null:
			_flash_sprite(wagon_sprite, Color(1.0, 0.4, 0.35, 1.0))
			_spawn_floating_text("-2", wagon_sprite.position, Color(1.0, 0.4, 0.4, 1.0))
	var traders := _caravan_job.get("traders", []) as Array
	for trader_index: int in range(traders.size() - 1, -1, -1):
		var trader := traders[trader_index] as Dictionary
		if not _any_hostile_adjacent(trader.get("cell", wagon_cell) as Vector2i):
			continue
		trader["hp"] = int(trader.get("hp", 6)) - 2
		var trader_sprite := trader.get("sprite") as Sprite2D
		if trader_sprite != null and is_instance_valid(trader_sprite):
			_flash_sprite(trader_sprite, Color(1.0, 0.4, 0.35, 1.0))
			if int(trader.get("hp", 0)) <= 0:
				trader_sprite.queue_free()
		if int(trader.get("hp", 0)) <= 0:
			traders.remove_at(trader_index)
			_set_save_status("A trader falls under the ambush!", Color(0.95, 0.5, 0.4, 1.0))
	if int(_caravan_job.get("wagon_hp", 0)) <= 0:
		_finish_caravan_job("The wagon is wrecked — the caravan is lost, and so is your pay.")
	elif traders.is_empty():
		_finish_caravan_job("Both traders lie dead — there is no one left to pay you.")

func _any_hostile_adjacent(cell: Vector2i) -> bool:
	for creature: Dictionary in _surface_creatures:
		var creature_cell := creature.get("cell", Vector2i(2147483647, 2147483647)) as Vector2i
		if maxi(absi(creature_cell.x - cell.x), absi(creature_cell.y - cell.y)) <= 1:
			return true
	return false

## Two planned ambushes, sprung as the wagon crosses 1/3 and 2/3 of the
## route: a small pack rushes it from the treeline.
func _maybe_spring_caravan_ambush(route_index: int, wagon_cell: Vector2i) -> void:
	var marks := _caravan_job.get("ambush_marks", []) as Array
	for mark_index: int in range(marks.size() - 1, -1, -1):
		if route_index < int(marks[mark_index]):
			continue
		marks.remove_at(mark_index)
		var want := _rng.randi_range(2, 3)
		var spawned := 0
		for _attempt: int in range(want * 6):
			if spawned >= want:
				break
			var cell := _walkable_cell_near(wagon_cell, 3, 6)
			if cell.x == 2147483647:
				continue
			var size_before := _surface_creatures.size()
			SurfaceLifeService.spawn_creature(
				_surface_creatures, SURFACE_CREATURE_TEXTURE,
				SurfaceLifeService.tier_def_index(SurfaceLifeService.danger_for_cell(cell, _surface_anchor_cells), _rng),
				cell, actor_layer, Callable(self, "_cell_center_position"), tile_size, _rng, true
			)
			if _surface_creatures.size() > size_before:
				spawned += 1
		if spawned > 0:
			GameAudioService.play_sfx(self, "raid_horn")
			_set_save_status("Ambush! %d shapes rush the wagon!" % spawned, Color(0.95, 0.45, 0.4, 1.0))

func _walkable_cell_near(center: Vector2i, min_distance: int, max_distance: int) -> Vector2i:
	for _attempt: int in range(10):
		var angle := _rng.randf_range(0.0, TAU)
		var distance := _rng.randf_range(float(min_distance), float(max_distance))
		var cell := center + Vector2i(roundi(cos(angle) * distance), roundi(sin(angle) * distance))
		if _is_walkable_cell(cell):
			return cell
	return Vector2i(2147483647, 2147483647)

## Success or failure, the run ends the same way: the ticker speaks, the
## wagon lingers a beat then fades, the waypost camp fades with it, and
## the master needs a day before the next load is ready.
func _finish_caravan_job(ticker_text: String, ticker_color: Color = Color(0.95, 0.5, 0.4, 1.0)) -> void:
	if not ticker_text.is_empty():
		_set_save_status(ticker_text, ticker_color)
	var wagon_sprite := _caravan_job.get("wagon_sprite") as Sprite2D
	if wagon_sprite != null and is_instance_valid(wagon_sprite):
		var tween := create_tween()
		tween.tween_interval(1.2)
		tween.tween_property(wagon_sprite, "modulate:a", 0.0, 0.6)
		tween.tween_callback(wagon_sprite.queue_free)
	for trader_variant: Variant in (_caravan_job.get("traders", []) as Array):
		var trader_sprite := (trader_variant as Dictionary).get("sprite") as Sprite2D
		if trader_sprite != null and is_instance_valid(trader_sprite):
			trader_sprite.queue_free()
	# The waypost sprite and label were untracked after the job cleared -
	# free them here so completed/failed runs don't orphan a camp (which
	# then survived regeneration, hovering over unrelated terrain).
	for node_variant: Variant in (_caravan_job.get("waypost_nodes", []) as Array):
		var node := node_variant as Node
		if node != null and is_instance_valid(node):
			node.queue_free()
	_caravan_next_offer_stamp = float(_game_day) * 24.0 + _game_hour + CARAVAN_OFFER_COOLDOWN_HOURS
	_caravan_job = {}

## Regeneration rebuilds the world under the wagon; drop the job silently.
func _clear_caravan_job() -> void:
	if _caravan_job.is_empty():
		return
	_finish_caravan_job("")
	# A rebuilt world owes no cooldown; the master offers fresh.
	_caravan_next_offer_stamp = 0.0

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

## Places a tile from the HOLD's atlas (tileset source 1): the embedded
## ward draws the hold's true carved-stone art inside the town's world.
func _place_hold_tile(target_layer: TileMapLayer, cell: Vector2i, tile_key: String) -> void:
	var coords := TILE_ATLAS_DEFS.DWARFHOLD_TILE_ATLAS.get(tile_key, Vector2i(-1, -1)) as Vector2i
	if coords.x < 0:
		return
	target_layer.set_cell(cell, HOLD_TILE_SOURCE_ID, coords)
	_actor_passable_cache.erase(cell)

func _pick_base_tile(grid: Dictionary, x: int, y: int, cell: int) -> String:
	# An open-sea embark draws its clearing as water, not grass, so the player
	# is dropped straight onto the ocean.
	if _wild_water and cell == CELL_ROCK:
		return "water"
	## Cellar levels are dug out of solid earth: undug cells render as the
	## painted rock fill (blocking, like dwarfhold stone), and lane/plaza
	## tiles drop their grass-fringed edges — there is no lawn underground
	## for a path to scallop into. Biome swaps are skipped too; a cellar
	## looks the same under a snowfield or a desert.
	if _is_underground_level():
		if cell == CELL_ROCK:
			return "cellar_rock"
		var cellar_key := TownTileService.pick_base_tile(grid, x, y, cell, _door_cells, Rect2i())
		if cellar_key.begins_with("road_edge") or cellar_key.begins_with("road_in"):
			return TownTileService.pick_path_interior_tile(x, y, cell == CELL_PLAZA)
		return cellar_key
	var tile_key := TownTileService.pick_base_tile(grid, x, y, cell, _door_cells, _dark_grass_rect)
	if _town_theme == "desert":
		# The whole dark-grass patch family flattens to the sand variant:
		# sand_alt reads as sand, so desert greens need no fringe pieces.
		if tile_key.begins_with("grass_dark"):
			return "sand_alt"
		if DESERT_BASE_SWAP.has(tile_key):
			return String(DESERT_BASE_SWAP[tile_key])
	if _town_ground_biome == TILE_ATLAS_DEFS.BIOME_TUNDRA:
		# Dark-grass patches become snow_alt drifts wholesale: the synthesized
		# snow_alt fringe family mirrors the grass_dark keys suffix for suffix,
		# so tundra greens blend drift patches the same way grass towns blend
		# dark grass.
		if tile_key.begins_with("grass_dark"):
			return tile_key.replace("grass_dark", "snow_alt")
		if SNOW_BASE_SWAP.has(tile_key):
			return String(SNOW_BASE_SWAP[tile_key])
	return tile_key

## The opaque ground stamped under a framed-room wall cell so the frame's
## cut-out exterior edges blend into the surroundings instead of the dark
## panel behind the layers. Grass suits the common grassy building plot;
## desert towns swap it for sand to match their terrain.
func _wall_ground_fill_tile() -> String:
	# Cellar building shells stand in solid earth, so their frame cut-outs
	# blend into the rock fill instead of a phantom green lawn.
	if _is_underground_level():
		return "cellar_rock"
	if _town_theme == "desert" and DESERT_BASE_SWAP.has("grass"):
		return String(DESERT_BASE_SWAP["grass"])
	if _town_ground_biome == TILE_ATLAS_DEFS.BIOME_TUNDRA and SNOW_BASE_SWAP.has("grass"):
		return String(SNOW_BASE_SWAP["grass"])
	return "grass"

func _building_type_for_cell(cell: Vector2i) -> String:
	return String(_latest_civic_building_type_map.get(cell, "workshop"))

func _pick_decor_tile(grid: Dictionary, x: int, y: int, cell: int, base_tile: String, house_decor_overrides: Dictionary) -> String:
	# No shrubs or grass tufts sprout on the open sea.
	if _wild_water and (base_tile == "water" or base_tile == "water_calm"):
		return ""
	# Direction posts stand where the lane tracer marked a junction.
	if _direction_post_cells.has(Vector2i(x, y)):
		return "direction_post"
	# Shop signboards by civic entrances and plaza-rim notice boards share
	# the carved-board art; their text resolves via _sign_text_for_cell.
	if _shop_sign_cells.has(Vector2i(x, y)) or _notice_board_cells.has(Vector2i(x, y)):
		return "signboard"
	# Nothing grows in the cellar's solid earth: no trees, hedges or blooms
	# scattered over undug rock (interior furniture still places normally).
	if _is_underground_level() and cell == CELL_ROCK:
		return ""
	var decor_key := TownTileService.pick_decor_tile(grid, x, y, cell, base_tile, house_decor_overrides, _latest_civic_building_type_map, CIVIC_BUILDING_TYPES, _rng, _door_cells)
	# The desert has no greenery: cacti and bones are scattered as sprites instead.
	if _town_theme == "desert" and DESERT_SKIPPED_DECOR.has(decor_key):
		return ""
	# Snow towns skip grassland blooms and bushes, and their scatter trees
	# stand snow-capped on the snow ground so the settled area reads as a
	# winter village, not a meadow.
	if _town_ground_biome == TILE_ATLAS_DEFS.BIOME_TUNDRA:
		if SNOW_SKIPPED_DECOR.has(decor_key):
			return ""
		if decor_key == "tree" or decor_key == "tree_dark":
			return decor_key + "_snowy"
	return decor_key


func _update_summary(grid: Dictionary, seed_text: String) -> void:
	var bounds := _find_bounds(grid)
	# The wilds carry no civic tallies - just name the place and note it is open.
	if _wild_mode:
		var wild_place := _town_name if not _town_name.is_empty() else "The Wilds"
		city_summary.text = "%s\nSeed %s\nOpen wilderness - no settlement.\nClearing: %dx%d" % [
			wild_place, seed_text, bounds.size.x, bounds.size.y
		]
		return
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

## The readable text for a sign-like decor cell, or {} when the cell holds
## no sign. Deterministic per settlement seed and cell: direction posts
## point at the nearest named gazetteer sites, shop signboards carry their
## establishment's name and trade, notice boards a seeded village notice.
func _sign_text_for_cell(cell: Vector2i) -> Dictionary:
	var sign_seed_text := seed_input.text.strip_edges()
	if _direction_post_cells.has(cell):
		var post_text := SignTextService.direction_post_text(_surface_all_sites, _overworld_tile_for_cell(cell), sign_seed_text, cell)
		if post_text.is_empty():
			post_text = SignTextService.flavor_text(sign_seed_text, cell)
		return {"title": "Direction Post", "text": post_text}
	if _shop_sign_cells.has(cell):
		var anchor := _shop_sign_cells[cell] as Vector2i
		var display_name := String(_latest_civic_building_name_map.get(anchor, ""))
		var trade := _building_type_for_cell_or_empty(anchor)
		var trade_display := "" if trade.is_empty() else _display_name_for_building_type(trade)
		var sign_text := SignTextService.business_sign_text(display_name, trade_display)
		if sign_text.is_empty():
			sign_text = SignTextService.flavor_text(sign_seed_text, cell)
		return {"title": display_name if not display_name.is_empty() else "Sign", "text": sign_text}
	if _notice_board_cells.has(cell):
		return {"title": "Notice Board", "text": SignTextService.flavor_text(sign_seed_text, cell)}
	return {}

## Floats the sign's text above the board in world space — small, warm,
## outlined so it reads over any ground — replacing the tile tooltip.
func _show_sign_hover_label(cell: Vector2i, sign_info: Dictionary) -> void:
	if _sign_hover_cell == cell and _sign_hover_label != null and is_instance_valid(_sign_hover_label):
		return
	_clear_sign_hover_label()
	var label := Label.new()
	label.text = String(sign_info.get("text", ""))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.97, 0.93, 0.8, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.09, 0.07, 0.05, 1.0))
	label.add_theme_constant_override("outline_size", 6)
	label.z_index = 45
	city_layer.add_child(label)
	label.reset_size()
	label.position = _cell_center_position(cell) - Vector2(label.size.x * 0.5, label.size.y + float(tile_size.y) * 0.75)
	_sign_hover_label = label
	_sign_hover_cell = cell

func _clear_sign_hover_label() -> void:
	if _sign_hover_label != null and is_instance_valid(_sign_hover_label):
		_sign_hover_label.queue_free()
	_sign_hover_label = null
	_sign_hover_cell = Vector2i(2147483647, 2147483647)

## Right-clicking a sign reads it aloud: the text opens in the same speech
## panel NPC dialogue uses, anchored over the board. No portrait — boards
## have no face — just the title line and the sign's text.
func _show_sign_dialogue(cell: Vector2i, sign_info: Dictionary) -> void:
	_spawn_speech_bubble("%s\n%s" % [String(sign_info.get("title", "Sign")), String(sign_info.get("text", ""))], _cell_center_position(cell))

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
	# A sign under the cursor floats its text above the board instead of
	# the regular tile tooltip (a villager on the stoop still wins).
	if hovered_npc.is_empty():
		var sign_info := _sign_text_for_cell(hovered_cell)
		if not sign_info.is_empty():
			_show_sign_hover_label(hovered_cell, sign_info)
			tile_hover_tooltip.visible = false
			return
	_clear_sign_hover_label()
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
	_clear_sign_hover_label()
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
