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
# 24 real minutes per game day = one game-minute per real second.
@export var minutes_per_game_day := 24.0
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
var _applied_darkness := -1.0
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
## The tile the player actually clicked to open the trade popup. The
## anchor above is the building's flood-fill top-left, which can sit
## many tiles from the counter — range checks must use the clicked cell.
var _trade_click_cell := Vector2i(2147483647, 2147483647)
var _trade_shop_type := ""
var _shop_stocks: Dictionary = {}
var _active_speech_bubble: PanelContainer
var _build_selection := -1
var _escape_menu: EscapeMenu
var _game_over: GameOverScreen
var _torch_sprites: Dictionary = {}
## Core Keeper-style mining target: a pick marker pinned to the diggable
## rock face under the cursor when the dwarf is close enough to swing.
var _mining_cursor: Sprite2D = null
var _mining_cursor_texture: Texture2D
## Minecart rails and the carts that ride them. Rails and cart positions
## live on the level data and the hold-diffs ledger, so track networks
## survive level switches, chunk eviction and full regeneration.
## Auto-generated street lighting: wall-mounted torches and candle
## stands spawned deterministically along the city's carved halls and
## beside building doors, so the hold glows lived-in instead of pitch
## dark between the player's lantern and the hearths.
var _auto_sconce_sprites: Dictionary = {}
var _auto_sconce_cells: Dictionary = {}
var _candle_sconce_texture: Texture2D
var _rail_cells: Dictionary = {}
var _rail_sprites: Dictionary = {}
var _rail_textures: Dictionary = {}
var _minecart_sprites: Dictionary = {}
var _minecart_texture: Texture2D
var _cart_riding := false
var _cart_cell := Vector2i.ZERO
var _cart_origin_cell := Vector2i.ZERO
var _cart_dir := Vector2i.ZERO
var _cart_desired_dir := Vector2i.ZERO
var _cart_progress := 0.0
## Streamed wild chunks currently resident, chunk coords -> true. The
## city core never appears here and is never evicted.
var _streamed_chunks: Dictionary = {}
var _discovery_chunks: Dictionary = {}
var _city_bounds := Rect2i()
var _player_glow: Sprite2D
var _glow_texture: Texture2D
var _torch_texture: Texture2D
var _bobber_texture: Texture2D
## 0 = fully lit (settlement / lighting off), 1 = pitch-dark cave (open
## wild underground). Lerps as the walker crosses the city boundary.
var _darkness_strength := 0.0
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
## Core Keeper-style light-source lighting: a single dark overlay quad on
## the lighting layer whose shader carves soft radial pools at the player
## lantern and every torch. No line-of-sight fog, no per-cell mask.
var _lighting_mask_sprite: Sprite2D
var _darkness_material: ShaderMaterial
var _lighting_bounds := Rect2i()
## Per-cell wall/occlusion map covering _lighting_bounds: 255 where a cell
## blocks light (solid rock or a wall tile), 0 where light passes. The
## darkness shader raymarches this so each reveal pool is clipped by walls
## instead of bleeding a pure radial pool through into adjacent rooms.
var _occlusion_image: Image
var _occlusion_texture: ImageTexture
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
## The floating world-space label shown while the cursor rests on a sign.
var _sign_hover_label: Label
var _sign_hover_cell := Vector2i(2147483647, 2147483647)
var _npc_states: Array[Dictionary] = []
## Venue cells (tavern, temple, market...) for the scheduler's objectives.
var _npc_pois: Dictionary = {}
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
## Cells of light-throwing furnishings (hearths, forges, candles) on the
## shown level; they carve their own reveal pools so the settlement is lit
## by its fires rather than a blanket exemption.
var _light_furnishing_cells: Array[Vector2i] = []
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
	{"tile": CELL_PLAZA, "name": "Plaza"},
	{"tile": CELL_WALL, "name": "Wall"}
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

## Light-source lighting. The overlay darkens the open underground to a
## deep cool black; the player lantern and torches carve warm pools with a
## smooth radial falloff. Radii are in tiles.
const DARK_COLOR := Color(0.03, 0.035, 0.055, 0.955)
const PLAYER_LIGHT_TILES := 7.0
const TORCH_LIGHT_TILES := 9.0
## Glow SPRITES are flame coronas only - small additive halos hugging
## the fire itself. Area illumination belongs to the darkness shader
## alone, whose pools respect walls; big additive blobs do not, and
## running both painted two mismatched lighting systems over the city.
const FLAME_HALO_TILES := 2.2
const CANDLE_HALO_TILES := 1.5
## Fires and candles in the settlement light their own pools, so the city
## glows only around its hearths instead of being blanket-lit.
const HEARTH_LIGHT_TILES := 6.5
const CANDLE_LIGHT_TILES := 4.0
## Furnishing pieces that throw a big fire pool (vs a small candle pool).
const HEARTH_LIGHT_PIECES := ["int_hearth_arch", "int_kiln_beehive", "int_fireplace_dark"]
## Ceiling on lights fed to the overlay shader in one frame (must match the
## shader's MAX_LIGHTS). The player lantern always claims one slot.
const MAX_DYNAMIC_LIGHTS := 128
## Floor for the light cull range; the real range grows with the visible
## view so a zoomed-out camera never shows an unlit lamp on screen.
const LIGHT_CULL_TILES := 48.0
const DARKNESS_SHADER_CODE := "shader_type canvas_item;

const int MAX_LIGHTS = 128;
// Raymarch resolution from a fragment toward each in-range light. 24 steps
// comfortably catches a one-cell-thick wall over a 7-9 tile light radius.
const int OCCLUSION_STEPS = 24;

uniform vec2 overlay_origin = vec2(0.0);
uniform vec2 overlay_size = vec2(1.0);
uniform vec4 darkness_color : source_color = vec4(0.03, 0.035, 0.055, 0.955);
uniform float darkness_strength : hint_range(0.0, 1.0) = 0.0;
uniform int light_count = 0;
uniform vec2 light_pos[MAX_LIGHTS];
uniform float light_radius[MAX_LIGHTS];
// One texel per CELL of the lighting bounds: >0.5 blocks light, 0 passes.
uniform sampler2D occlusion_tex : filter_nearest, repeat_disable;
uniform vec2 occlusion_origin = vec2(0.0);
uniform vec2 occlusion_size = vec2(1.0);
uniform float tile_px = 32.0;

void fragment() {
	vec2 world_pos = overlay_origin + UV * overlay_size;
	float reveal = 0.0;
	for (int i = 0; i < MAX_LIGHTS; i++) {
		if (i >= light_count) { break; }
		float r = light_radius[i];
		if (r <= 0.0) { continue; }
		vec2 lp = light_pos[i];
		float d = distance(world_pos, lp);
		// Out of range: contributes nothing, so skip the raymarch entirely
		// and keep the per-pixel cost at ~1-3 in-range lights.
		if (d >= r) { continue; }
		bool blocked = false;
		for (int s = 1; s < OCCLUSION_STEPS; s++) {
			float t = float(s) / float(OCCLUSION_STEPS);
			// Skip the first/last stretch so a fragment never occludes on
			// its own cell and a light never occludes on its own cell.
			if (t < 0.08 || t > 0.92) { continue; }
			vec2 sample_world = mix(world_pos, lp, t);
			vec2 sample_cell = sample_world / tile_px;
			vec2 occ_uv = (sample_cell - occlusion_origin) / occlusion_size;
			if (texture(occlusion_tex, occ_uv).r > 0.5) {
				blocked = true;
				break;
			}
		}
		if (blocked) { continue; }
		float s2 = 1.0 - smoothstep(r * 0.32, r, d);
		reveal = max(reveal, s2);
	}
	reveal = clamp(reveal, 0.0, 1.0);
	float a = darkness_color.a * darkness_strength * (1.0 - reveal);
	// Torchlight penumbra: the thinning darkness near a light leans warm
	// instead of cold void, so light pools read like firelight.
	vec3 shade = mix(darkness_color.rgb, vec3(0.38, 0.23, 0.10), reveal * 0.6);
	COLOR = vec4(shade, a);
}
"

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

## One human trade title per civic building type: the profession a dwarf
## posted there by the building-first staffing pass wears on their
## inspection card. Covers every CIVIC_BUILDING_TYPES key — including the
## types _assign_room_roles deals to back rooms (kitchen, granary, ...),
## which are civic types themselves. Bedrooms re-zone to CELL_HOUSE and
## leave the civic map entirely, so they never reach staffing.
const PROFESSION_BY_BUILDING := {
	"high_kings_palace": "Steward of the Hall",
	"forge": "Smith",
	"engineering_workshop": "Engineer",
	"leatherworking_shop": "Leatherworker",
	"tailoring_shop": "Tailor",
	"enchanting_study": "Enchanter",
	"alchemy_laboratory": "Alchemist",
	"auction_house": "Auctioneer",
	"general_goods_shop": "Shopkeeper",
	"weapon_shop": "Weaponsmith",
	"armor_shop": "Armorer",
	"trade_supply_store": "Outfitter",
	"bank_vaults": "Vaultwarden",
	"tavern": "Tavernkeeper",
	"barber_shop": "Barber",
	"guild_hall": "Guildmaster",
	"storage_warehouse": "Warehouse Keeper",
	"brewery": "Brewer",
	"granary": "Granary Keeper",
	"armory": "Quartermaster",
	"workshop": "Artisan",
	"kitchen": "Cook",
	"barracks": "Drillmaster",
	"temple": "Priest",
	"mushroom_farm": "Mushroom Farmer",
	"archives": "Archivist",
	"infirmary": "Healer",
	"miners_guild": "Mine Overseer",
	"mason_lodge": "Mason",
	"engineers_foundry": "Foundry Master",
	"gemcutters_studio": "Gemcutter",
	"runesmith_sanctum": "Runesmith",
	"smeltery": "Smelter",
	"cartographers_office": "Cartographer",
	"explorers_guild": "Pathfinder",
	"merchants_counting_house": "Merchant",
	"butchery": "Butcher",
	"bakery": "Baker",
	"cooperage": "Cooper",
	"tannery": "Tanner",
	"millhouse": "Miller",
	"cobblers_shop": "Cobbler",
	"ropemakers_hall": "Ropemaker"
}

const DWARFHOLD_SCENE_SEED_KEY := "dwarfhold_scene_seed"
const DWARFHOLD_SCENE_TILE_KEY := "dwarfhold_scene_tile"
const DWARFHOLD_SCENE_POPULATION_KEY := "dwarfhold_scene_population"
const DWARFHOLD_SCENE_NAME_KEY := "dwarfhold_scene_name"
const DWARFHOLD_SCENE_FALL_KEY := "dwarfhold_scene_fall_text"
const DWARFHOLD_SCENE_GEOLOGY_KEY := "dwarfhold_scene_geology"
const DWARFHOLD_SCENE_OVERLAND_KEY := "dwarfhold_scene_overland_arrival"
## Stage 4 of the hold merge: the main floor lives on the SURFACE, so a
## stair descent lands in the first underhall and ascending from it
## returns to the surface city - the old level-0 city never shows.
const DWARFHOLD_SCENE_FROM_SURFACE_KEY := "dwarfhold_scene_from_surface_stair"
const DWARFHOLD_SCENE_GUILDS_KEY := "dwarfhold_scene_guilds"
const TOWN_SCENE_PATH := "res://scenes/town_generation.tscn"

## Identity carried in from the overworld chronicle: the hold's name and,
## for abandoned ruins, the fall summary ("Fell to <beast>, year <y>").
var _hold_name := ""
var _hold_fall_text := ""
## The hold's overworld tile and, when a still-living chronicle beast
## lairs in these halls, the beast itself — its boss guards the deepest
## level. Empty once the beast is dead (by hero or by the player).
var _hold_tile := Vector2i(2147483647, 2147483647)
var _lair_beast: Dictionary = {}

## The sitting ruler, chronicle-authoritative: the settlement's lineage
## entry (or a seeded fallback for standalone runs) and the index of the
## resident NPC crowned with it on the city level.
var _ruler_record: Dictionary = {}
var _ruler_npc_index := -1

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
const DIG_ORE_CHANCE_PERCENT := 9
const DIG_COAL_CHANCE_PERCENT := 6

## Rock has durability: each pickaxe swing chips it, and it only breaks
## once the accumulated damage reaches the rock's hit points. Bare hands
## dig slowly; the best pickaxe carried in the backpack sets swing damage.
const ROCK_DURABILITY_HP := 12
const HAND_DIG_DAMAGE := 3
## Damage tracks the economy's tool tiering (Rusty 6c ... Dwarven 30c).
const DIG_TOOL_DAMAGE := {
	"Dwarven Pickaxe": 12,
	"Steel Pickaxe": 8,
	"Miner's Pickaxe": 6,
	"Copper Pick": 5,
	"Worn Pickaxe": 4,
	"Rusty Pickaxe": 4
}

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
		"preferred_footprint_min": Vector2i(7, 5),
		"preferred_footprint_max": Vector2i(10, 7),
		"decor_tile_pool": ["sign", "chest", "armor_stand", "table_alt"],
		"adjacency_preferences": {}
	},
	"forge": {
		"placement_weight": 1.25,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(7, 5),
		"decor_tile_pool": ["anvil", "workbench", "armor_stand", "water_bucket"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.7
		}
	},
	"engineering_workshop": {
		"placement_weight": 0.8,
		"preferred_footprint_min": Vector2i(5, 3),
		"preferred_footprint_max": Vector2i(8, 5),
		"decor_tile_pool": ["workbench", "anvil", "desk", "water_bucket"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.35
		}
	},
	"leatherworking_shop": {
		"placement_weight": 0.55,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(7, 5),
		"decor_tile_pool": ["workbench", "table", "chest", "water_bucket"],
		"adjacency_preferences": {}
	},
	"tailoring_shop": {
		"placement_weight": 0.5,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(6, 5),
		"decor_tile_pool": ["table", "stool", "shelf", "chest"],
		"adjacency_preferences": {}
	},
	"enchanting_study": {
		"placement_weight": 0.42,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(6, 5),
		"decor_tile_pool": ["sign", "desk", "shelf", "table_alt"],
		"adjacency_preferences": {}
	},
	"alchemy_laboratory": {
		"placement_weight": 0.5,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(7, 5),
		"decor_tile_pool": ["water_bucket", "table_alt", "desk", "chest"],
		"adjacency_preferences": {}
	},
	"auction_house": {
		"placement_weight": 0.45,
		"preferred_footprint_min": Vector2i(5, 3),
		"preferred_footprint_max": Vector2i(8, 5),
		"decor_tile_pool": ["desk", "table_alt", "sign", "chest"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.15
		}
	},
	"general_goods_shop": {
		"placement_weight": 0.7,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(7, 5),
		"decor_tile_pool": ["shelf", "table", "chest", "grain_bag"],
		"adjacency_preferences": {}
	},
	"weapon_shop": {
		"placement_weight": 0.65,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(7, 5),
		"decor_tile_pool": ["target", "anvil", "workbench", "armor_stand"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.25
		}
	},
	"armor_shop": {
		"placement_weight": 0.62,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(7, 5),
		"decor_tile_pool": ["armor_stand", "workbench", "chest", "table"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.2
		}
	},
	"trade_supply_store": {
		"placement_weight": 0.6,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(7, 5),
		"decor_tile_pool": ["grain_bag", "keg", "chest", "table"],
		"adjacency_preferences": {}
	},
	"bank_vaults": {
		"placement_weight": 0.35,
		"preferred_footprint_min": Vector2i(5, 3),
		"preferred_footprint_max": Vector2i(7, 5),
		"decor_tile_pool": ["chest", "desk", "sign", "table_alt"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.1
		}
	},
	"tavern": {
		"placement_weight": 0.9,
		"preferred_footprint_min": Vector2i(5, 3),
		"preferred_footprint_max": Vector2i(8, 5),
		"decor_tile_pool": ["keg", "mug", "table_alt", "stool"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.2
		}
	},
	"barber_shop": {
		"placement_weight": 0.35,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(6, 5),
		"decor_tile_pool": ["stool", "desk", "water_bucket", "mug"],
		"adjacency_preferences": {}
	},
	"guild_hall": {
		"placement_weight": 0.5,
		"preferred_footprint_min": Vector2i(5, 3),
		"preferred_footprint_max": Vector2i(8, 5),
		"decor_tile_pool": ["table", "table_alt", "sign", "chest"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.2
		}
	},
	"storage_warehouse": {
		"placement_weight": 0.7,
		"preferred_footprint_min": Vector2i(5, 3),
		"preferred_footprint_max": Vector2i(8, 5),
		"decor_tile_pool": ["chest", "grain_bag", "keg", "shelf"],
		"adjacency_preferences": {}
	},
	"brewery": {
		"placement_weight": 1.05,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(7, 5),
		"decor_tile_pool": ["keg", "winepress", "mug", "table_alt"],
		"adjacency_preferences": {}
	},
	"granary": {
		"placement_weight": 0.95,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(6, 5),
		"decor_tile_pool": ["grain_bag", "flour", "shelf", "table"],
		"adjacency_preferences": {}
	},
	"armory": {
		"placement_weight": 0.9,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(7, 5),
		"decor_tile_pool": ["armor_stand", "target", "anvil", "workbench"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.45
		}
	},
	"workshop": {
		"placement_weight": 1.1,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(7, 5),
		"decor_tile_pool": ["workbench", "desk", "shelf", "butcher_table"],
		"adjacency_preferences": {}
	},
	"kitchen": {
		"placement_weight": 0.85,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(6, 5),
		"decor_tile_pool": ["butcher_table", "table", "stool", "water_bucket"],
		"adjacency_preferences": {}
	},
	"barracks": {
		"placement_weight": 0.8,
		"preferred_footprint_min": Vector2i(5, 3),
		"preferred_footprint_max": Vector2i(8, 5),
		"decor_tile_pool": ["bed", "chest", "armor_stand", "target"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.35
		}
	},
	"temple": {
		"placement_weight": 0.65,
		"preferred_footprint_min": Vector2i(5, 3),
		"preferred_footprint_max": Vector2i(7, 5),
		"decor_tile_pool": ["table_alt", "sign", "mug", "stool"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.2
		}
	},
	"mushroom_farm": {
		"placement_weight": 0.7,
		"preferred_footprint_min": Vector2i(5, 4),
		"preferred_footprint_max": Vector2i(8, 6),
		"decor_tile_pool": ["mushroom_crops", "mushroom_crop_wild", "grain_bag", "water_bucket"],
		"adjacency_preferences": {}
	},
	"archives": {
		"placement_weight": 0.55,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(7, 5),
		"decor_tile_pool": ["shelf", "desk", "sign", "chest"],
		"adjacency_preferences": {}
	},
	"infirmary": {
		"placement_weight": 0.6,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(6, 5),
		"decor_tile_pool": ["bed", "table", "water_bucket", "chest"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.25
		}
	},
	"miners_guild": {
		"placement_weight": 0.75,
		"preferred_footprint_min": Vector2i(5, 3),
		"preferred_footprint_max": Vector2i(8, 5),
		"decor_tile_pool": ["stone", "target", "workbench", "chest"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.3
		}
	},
	"mason_lodge": {
		"placement_weight": 0.7,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(7, 5),
		"decor_tile_pool": ["stone", "table", "desk", "workbench"],
		"adjacency_preferences": {}
	},
	"engineers_foundry": {
		"placement_weight": 0.65,
		"preferred_footprint_min": Vector2i(5, 3),
		"preferred_footprint_max": Vector2i(7, 5),
		"decor_tile_pool": ["anvil", "workbench", "desk", "water_bucket"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.4
		}
	},
	"gemcutters_studio": {
		"placement_weight": 0.6,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(6, 5),
		"decor_tile_pool": ["table_alt", "chest", "sign", "desk"],
		"adjacency_preferences": {}
	},
	"runesmith_sanctum": {
		"placement_weight": 0.5,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(7, 5),
		"decor_tile_pool": ["anvil", "sign", "shelf", "desk"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.2
		}
	},
	"smeltery": {
		"placement_weight": 0.7,
		"preferred_footprint_min": Vector2i(5, 3),
		"preferred_footprint_max": Vector2i(8, 5),
		"decor_tile_pool": ["anvil", "water_bucket", "stone", "workbench"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.5
		}
	},
	"cartographers_office": {
		"placement_weight": 0.45,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(6, 5),
		"decor_tile_pool": ["desk", "sign", "table", "shelf"],
		"adjacency_preferences": {}
	},
	"explorers_guild": {
		"placement_weight": 0.55,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(7, 5),
		"decor_tile_pool": ["target", "table", "chest", "water_bucket"],
		"adjacency_preferences": {
			"prefers_hall_arteries": true,
			"hall_artery_bonus_weight": 0.15
		}
	},
	"merchants_counting_house": {
		"placement_weight": 0.55,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(7, 5),
		"decor_tile_pool": ["desk", "chest", "table_alt", "shelf"],
		"adjacency_preferences": {}
	},
	"butchery": {
		"placement_weight": 0.75,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(6, 5),
		"decor_tile_pool": ["butcher_table", "table", "water_bucket", "chest"],
		"adjacency_preferences": {}
	},
	"bakery": {
		"placement_weight": 0.7,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(6, 5),
		"decor_tile_pool": ["table_alt", "flour", "grain_bag", "stool"],
		"adjacency_preferences": {}
	},
	"cooperage": {
		"placement_weight": 0.6,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(7, 5),
		"decor_tile_pool": ["keg", "workbench", "chest", "table"],
		"adjacency_preferences": {}
	},
	"tannery": {
		"placement_weight": 0.55,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(7, 5),
		"decor_tile_pool": ["water_bucket", "workbench", "chest", "table_alt"],
		"adjacency_preferences": {}
	},
	"millhouse": {
		"placement_weight": 0.65,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(7, 5),
		"decor_tile_pool": ["flour", "grain_bag", "table", "shelf"],
		"adjacency_preferences": {}
	},
	"cobblers_shop": {
		"placement_weight": 0.45,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(6, 5),
		"decor_tile_pool": ["stool", "chest", "table", "desk"],
		"adjacency_preferences": {}
	},
	"ropemakers_hall": {
		"placement_weight": 0.45,
		"preferred_footprint_min": Vector2i(4, 3),
		"preferred_footprint_max": Vector2i(6, 5),
		"decor_tile_pool": ["table", "workbench", "chest", "stool"],
		"adjacency_preferences": {}
	}
}

func _ready() -> void:
	_apply_cached_dwarfhold_scene_seed()
	_configure_tile_layer()
	# The CanvasModulate would tint the whole canvas, including the side UI
	# panel, so it is left neutral; the dark cave comes from the overlay
	# quad below, which is clipped to the map view.
	global_darkness.color = Color(1.0, 1.0, 1.0, 1.0)
	_darkness_material = ShaderMaterial.new()
	var darkness_shader := Shader.new()
	darkness_shader.code = DARKNESS_SHADER_CODE
	_darkness_material.shader = darkness_shader
	_darkness_material.set_shader_parameter("darkness_color", DARK_COLOR)
	_darkness_material.set_shader_parameter("darkness_strength", 0.0)
	_darkness_material.set_shader_parameter("light_count", 0)
	_lighting_mask_sprite = Sprite2D.new()
	_lighting_mask_sprite.centered = false
	_lighting_mask_sprite.texture = _create_white_texture()
	_lighting_mask_sprite.material = _darkness_material
	# Above every world actor (creatures 12, items 6, player/NPCs 11) so
	# darkness swallows them all alike — at z 1 monsters and loot floated
	# fully lit over unexplored black. Torches (14) and glows (15) stay on
	# top as the light sources that punch through.
	_lighting_mask_sprite.z_index = 13
	_lighting_mask_sprite.visible = false
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
	_setup_drop_catcher()
	GameAudioService.play_music(self, "hold")
	_setup_inventory_label()
	_setup_hp_label()
	_setup_coins_label()
	_setup_factions_panel()
	_escape_menu = EscapeMenu.new()
	_escape_menu.show_return_to_map = true
	add_child(_escape_menu)
	_glow_texture = _create_glow_texture()
	# The walker's lantern halo; the shader carves the real 7-tile pool.
	_player_glow = _create_glow_sprite(FLAME_HALO_TILES)
	lighting_layer.add_child(_player_glow)
	_player_glow.visible = false
	_generate_city()
	## The "Strike the earth!" greeting, once, on a new walker's first embark.
	EmbarkIntroScreen.maybe_present(self)

## The embark screen reads this to tailor its greeting to the start place.
func _embark_place() -> Dictionary:
	return {"kind": "dwarfhold", "name": _hold_name}

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

## A tiny opaque-white texture stretched to cover the map bounds; the
## darkness shader ignores its pixels and works from UV, so 8x8 is plenty.
func _create_white_texture() -> Texture2D:
	var white_image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	white_image.fill(Color(1.0, 1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(white_image)

func _create_glow_texture() -> Texture2D:
	var glow_size := 128
	var image := Image.create(glow_size, glow_size, false, Image.FORMAT_RGBA8)
	var center := Vector2(glow_size / 2.0, glow_size / 2.0)
	for y in range(glow_size):
		for x in range(glow_size):
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(center) / (glow_size / 2.0)
			var strength := clampf(1.0 - distance, 0.0, 1.0)
			strength = strength * strength
			image.set_pixel(x, y, Color(1.0, 0.82, 0.55, strength * 0.55))
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
	_update_ground_items(delta)
	_update_wild_darkness(delta)
	_player_attack_timer = maxf(_player_attack_timer - delta, 0.0)
	_staff_cooldown = maxf(_staff_cooldown - delta, 0.0)
	_update_companion(delta)
	_update_creature_spawning(delta)
	_update_creatures(delta)
	_update_player_regen(delta)
	_update_fishing(delta)

## Every level of the hold sits in darkness - the city, the wild
## underground AND the deep mining strata (deep levels used to skip the
## overlay entirely and drew fully lit, which is exactly un-Core-Keeper).
## Only light sources carve reveal pools: the player's lantern, placed
## torches, and the settlement's own hearths and candles.
func _update_wild_darkness(delta: float) -> void:
	# The lighting toggle off forces full daylight everywhere.
	var target := 0.0
	if _lighting_enabled and _player_sprite != null:
		target = 1.0
	_darkness_strength = lerpf(_darkness_strength, target, clampf(delta * 3.0, 0.0, 1.0))
	if absf(_darkness_strength - target) < 0.002:
		_darkness_strength = target
	# Only poke the shader while the darkness level is actually moving.
	if not is_equal_approx(_darkness_strength, _applied_darkness):
		_applied_darkness = _darkness_strength
		if _darkness_material != null:
			_darkness_material.set_shader_parameter("darkness_strength", _darkness_strength)
	if _player_glow != null:
		_player_glow.visible = _lighting_enabled and _player_sprite != null and _darkness_strength > 0.05
		if _player_sprite != null:
			_player_glow.position = _player_sprite.position
	_update_light_uniforms()
	_update_minecart(delta)
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
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_R and not _is_text_input_focused():
		_place_rail()
		get_viewport().set_input_as_handled()
		return
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_C and not _is_text_input_focused():
		_handle_cart_key()
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
	# The lantern pool tracks the player every frame in _update_light_uniforms,
	# so crossing a tile needs no lighting rebuild.
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
	## In trade mode, measure from the clicked tile, not the shop anchor:
	## the anchor is the building's top-left flood-fill cell, so a large
	## shop would slam the popup shut on the first step near its far side.
	var anchor := _selected_chest_cell
	if _is_trade_mode():
		anchor = _trade_click_cell if _trade_click_cell.x != 2147483647 else _trade_shop_cell
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
	_hold_name = String(settings.get(DWARFHOLD_SCENE_NAME_KEY, ""))
	_hold_fall_text = String(settings.get(DWARFHOLD_SCENE_FALL_KEY, ""))
	_hold_tile = Vector2i(2147483647, 2147483647)
	_lair_beast = {}
	var tile_variant: Variant = settings.get(DWARFHOLD_SCENE_TILE_KEY, null)
	if tile_variant is Dictionary:
		var tile_dict := tile_variant as Dictionary
		_hold_tile = Vector2i(int(tile_dict.get("x", 2147483647)), int(tile_dict.get("y", 2147483647)))
		## The chronicle's still-living beast laired in THIS hold; slain
		## beasts (by sim hero or player) never come back.
		_lair_beast = WorldChronicleService.lair_beast_for_tile(settings, _hold_tile)
	var geology_variant: Variant = settings.get(DWARFHOLD_SCENE_GEOLOGY_KEY, null)
	_journey_geology = (geology_variant as Dictionary).duplicate(true) if geology_variant is Dictionary else {}
	# The guilds the overworld tooltip advertises: the scene's open
	# factions adopt these names so the map's promise walks the halls.
	_journey_guilds = []
	for guild_variant: Variant in (settings.get(DWARFHOLD_SCENE_GUILDS_KEY, []) as Array if settings.get(DWARFHOLD_SCENE_GUILDS_KEY) is Array else []):
		var guild_name := String(guild_variant).strip_edges()
		if not guild_name.is_empty():
			_journey_guilds.append(guild_name)
	# One-shot: an overland walk-in spawns at the south gate; consumed so
	# later level moves and reloads keep their own spawn logic.
	_overland_arrival = bool(settings.get(DWARFHOLD_SCENE_OVERLAND_KEY, false))
	if settings.has(DWARFHOLD_SCENE_OVERLAND_KEY):
		settings.erase(DWARFHOLD_SCENE_OVERLAND_KEY)
		_store_world_settings(settings)
	# Sticky, unlike the overland flag: every stair descent (the only
	# real way in since stage 4) lands in the first underhall and
	# ascends back OUT to the surface city - and a save reloaded in the
	# underhalls must keep that shape, so the key is never consumed.
	_from_surface_stair = bool(settings.get(DWARFHOLD_SCENE_FROM_SURFACE_KEY, false))
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
	# Stage 4: on a surface-stair visit, level 0's duplicate city is
	# retired - stepping above the first underhall exits to the surface.
	if _from_surface_stair and _hold_state.current_level_index - 1 <= 0:
		_exit_to_surface_city()
		return
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
	# DF-style geology for this hold's country rock: the overworld tile the
	# hold rises from when a journey carried it in, a seed-derived profile
	# only for holds opened without one (direct scene runs, old saves).
	if _journey_geology.is_empty():
		_geology = GeologyService.profile_for_seed(_world_seed_hash)
	else:
		_geology = _journey_geology.duplicate(true)
	# Holds carry no generated details dict; the market derives from a
	# seeded stub of mountain exports (ore, ingots, gems, stone).
	_hold_market = SettlementEconomyService.settlement_market(SettlementEconomyService.hold_details_stub(_world_seed_hash), _world_seed_hash)
	_hold_state.generated_levels.clear()
	## Reseeding invalidates anything keyed by cell coordinates from the
	## old world: stale shop stocks would sell the previous hold's wares,
	## and stale discovery flags would block chunk eviction forever.
	_shop_stocks.clear()
	_discovery_chunks.clear()

	var minimum_levels := mini(underground_level_count_range.x, underground_level_count_range.y)
	var maximum_levels := maxi(underground_level_count_range.x, underground_level_count_range.y)
	var level_count := _hold_state.population_scaled_level_count(maximum_levels)
	if level_count <= 0:
		level_count = maxi(1, _rng.randi_range(minimum_levels, maximum_levels))
	for level_index in range(level_count):
		var level_seed := "%s::depth_%d" % [seed_text, level_index]
		var level_data := _generate_single_level(level_seed, level_index, level_count)
		# Level 0 is the hold's main-floor city (now shown on the surface);
		# everything below it is a dug underhall. A future unified column
		# reads these kinds to route surface vs deep generation.
		level_data["kind"] = "hold_city" if level_index == 0 else "underhall"
		_hold_state.generated_levels.append(level_data)

	if _from_surface_stair and _hold_state.generated_levels.size() > 1:
		# Stage 4: the main floor lives on the SURFACE. Descending the
		# great hall's stair lands in the first underhall, arriving at
		# its up-stair - the same shaft the walker just climbed down.
		_pending_player_spawn_cell = _resolve_stair_spawn_cell(1, "up", _pending_player_spawn_cell)
		_show_level(1)
	else:
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
	## Multi-room interiors replace the old one-door-per-rectangle pass:
	## large plots get partition walls, internal doors forming a spanning
	## tree, street-facing exterior doors, and per-room role tags. Unusable
	## sub-2x2 nooks are demolished back into open hall.
	var level_door_cells := _plan_building_interiors(grid)
	var civic_buildings_by_id := _compute_civic_buildings_by_id(grid)
	var civic_building_type_map := _build_civic_building_type_lookup(civic_buildings_by_id)
	var zone_counts := _count_zone_components(grid)
	var stratum := DepthStrataService.stratum_for_level(level_index, level_count)
	var starmetal_cells: Array[Vector2i] = []
	if is_additional_layer:
		starmetal_cells = DepthStrataService.stamp_stratum_features(grid, floor_decor, stratum, _rng)
	var stair_cells := _pick_level_stair_cells(grid, level_index, level_count)
	## The non-negotiable pass: at the tile-passability level (the same
	## rules movement uses), every walkable cell must reach every other.
	## Runs after stratum features and stairs so nothing re-fragments it.
	_repair_level_connectivity(grid, level_door_cells, stair_cells, level_index)
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

## --- Multi-room building interiors -----------------------------------------
## Post-pass over every stamped structure: demolish sub-2x2 nooks, BSP-split
## larger plots into 2-5 rooms with CELL_WALL partition lines, punch internal
## doors so the room graph is a spanning tree from the entrance, punch 1-2
## exterior doors on walls that face a hall or plaza, and retag each room
## with a role (taproom + kitchen + bedrooms; shopfront + workroom; ...).

## Back rooms behind a shopfront, in the order they're dealt from the
## entrance inward. "bedroom" re-zones the room to CELL_HOUSE so it gets a
## bed tile, house furnishing, and a slot in the NPC sleep schedule.
const ROOM_BACK_ROLES := {
	"tavern": ["kitchen", "bedroom", "bedroom", "bedroom"],
	"brewery": ["kitchen", "storage_warehouse", "bedroom"],
	"bakery": ["kitchen", "storage_warehouse", "bedroom"],
	"kitchen": ["granary", "storage_warehouse", "bedroom"],
	"butchery": ["storage_warehouse", "kitchen"],
	"millhouse": ["granary", "storage_warehouse"],
	"granary": ["storage_warehouse", "granary"],
	"forge": ["workshop", "armory", "storage_warehouse"],
	"smeltery": ["workshop", "storage_warehouse"],
	"armory": ["workshop", "storage_warehouse"],
	"weapon_shop": ["workshop", "storage_warehouse"],
	"armor_shop": ["workshop", "storage_warehouse"],
	"engineering_workshop": ["workshop", "storage_warehouse"],
	"engineers_foundry": ["workshop", "storage_warehouse"],
	"workshop": ["storage_warehouse", "workshop"],
	"cooperage": ["workshop", "storage_warehouse"],
	"temple": ["archives", "bedroom"],
	"archives": ["enchanting_study", "bedroom"],
	"guild_hall": ["archives", "bedroom"],
	"merchants_counting_house": ["storage_warehouse", "bedroom"],
	"auction_house": ["storage_warehouse", "bedroom"],
	"bank_vaults": ["storage_warehouse", "guild_hall"],
	"gemcutters_studio": ["workshop", "bedroom"],
	"tailoring_shop": ["workshop", "bedroom"],
	"barber_shop": ["bedroom", "storage_warehouse"],
	"enchanting_study": ["archives", "bedroom"],
	"infirmary": ["bedroom", "bedroom", "kitchen"],
	"general_goods_shop": ["storage_warehouse", "bedroom"],
	"trade_supply_store": ["storage_warehouse", "storage_warehouse"],
	"high_kings_palace": ["guild_hall", "bedroom", "bedroom", "bank_vaults"]
}

## Buildings that read as one open work floor and never subdivide.
const OPEN_PLAN_BUILDING_TYPES := ["mushroom_farm"]

func _plan_building_interiors(grid: Dictionary) -> Dictionary:
	## The heavy lifting lives in the shared SettlementArchitectureService
	## (BSP subdivision, internal/exterior doors, room roles) so the surface
	## towns run the exact same machinery. The config reproduces the hold's
	## historical behavior bit-for-bit: same rng, same call order.
	return SettlementArchitectureService.plan_building_interiors(grid, {
		"rng": _rng,
		"civic_type_map": _latest_civic_building_type_map,
		"residence_type_map": _latest_residence_type_map,
		"back_roles": ROOM_BACK_ROLES,
		"default_back_role": "storage_warehouse",
		"open_plan_types": OPEN_PLAN_BUILDING_TYPES,
		"demolish_zone": CELL_HALL,
		"door_on_open_ground": false
	})

## --- Level-wide connectivity guarantee -------------------------------------
## The shared repair pass (see SettlementArchitectureService) at the hold's
## own tile passability: rock is solid, walls open only at doors.

func _is_generation_passable(grid: Dictionary, door_cells: Dictionary, cell: Vector2i) -> bool:
	var zone := int(grid.get(cell, CELL_ROCK))
	match zone:
		CELL_HALL, CELL_PLAZA:
			return true
		CELL_WALL:
			return door_cells.has(cell)
		CELL_HOUSE, CELL_BUILDING:
			return DwarfHoldTileService.wall_or_floor_tile(grid, cell.x, cell.y, zone, door_cells) != "stone"
		_:
			return false

func _repair_level_connectivity(grid: Dictionary, door_cells: Dictionary, stair_cells: Dictionary, level_index: int) -> void:
	var is_passable := func(cell: Vector2i) -> bool:
		return _is_generation_passable(grid, door_cells, cell)
	SettlementArchitectureService.repair_level_connectivity(grid, door_cells, stair_cells, level_index, is_passable, "DwarfHold")


## Each level's wild rock gets its own noise seed; level 0 keeps the
## bare world hash so pre-stage-4 saves' streamed chunks stay identical.
func _level_world_seed(level_index: int) -> int:
	if level_index <= 0:
		return _world_seed_hash
	return _world_seed_hash ^ (level_index * 2654435761)

func _show_level(target_level_index: int) -> void:
	if not _hold_state.has_levels():
		depth_down_button.disabled = true
		depth_up_button.disabled = true
		depth_label.text = "Level 0 / 0"
		return

	_hold_state.current_level_index = _hold_state.clamp_index(target_level_index)
	var level_data := _hold_state.generated_levels[_hold_state.current_level_index] as Dictionary
	var grid := level_data.get("grid", {}) as Dictionary
	_door_cells = level_data.get("door_cells", {}) as Dictionary
	_latest_grid = grid
	# This level's actor layer is about to be rebuilt (dropped-item sprites
	# freed with it); drop the stale entries so they can't re-grant items.
	_clear_ground_items()
	# Mining damage is per-level state; a level switch restores full rock.
	_clear_all_rock_damage()
	_latest_zone_counts = level_data.get("zone_counts", {}) as Dictionary
	_latest_requested_zone_counts = level_data.get("requested_zone_counts", {}) as Dictionary
	_latest_civic_buildings_by_id = level_data.get("civic_buildings_by_id", {}) as Dictionary
	_latest_civic_building_type_map = level_data.get("civic_building_type_map", {}) as Dictionary
	_latest_civic_building_name_map = _build_civic_building_name_lookup(_latest_civic_buildings_by_id, seed_input.text.strip_edges(), "dwarf")
	_latest_residence_type_map = level_data.get("residence_type_map", {}) as Dictionary
	_latest_district_labels = level_data.get("district_labels", []) as Array
	_latest_district_cell_map = level_data.get("district_cell_map", {}) as Dictionary
	_latest_floor_decor = level_data.get("floor_decor", {}) as Dictionary
	# EVERY level is an open, diggable underground: rock beyond the halls
	# streams in as deterministic noise-carved chunks, each level with
	# its own cavern layout. (Level 0 keeps its original seed so old
	# saves' galleries still line up.) Discovery flags are per-level
	# state exactly like the chunks that carry them: binding a shared
	# dict across levels left stale flags that blocked chunk eviction
	# on every OTHER level, stranding tiles and creatures forever.
	if not level_data.has("generated_chunks"):
		level_data["generated_chunks"] = {}
	if not level_data.has("dug_cells"):
		level_data["dug_cells"] = {}
	if not level_data.has("discovery_chunks"):
		level_data["discovery_chunks"] = {}
	_generated_chunks = level_data.get("generated_chunks", {}) as Dictionary
	_dug_cells = level_data.get("dug_cells", {}) as Dictionary
	_discovery_chunks = level_data.get("discovery_chunks", {}) as Dictionary
	_world_noise = UndergroundWorldService.make_noise_set(_level_world_seed(_hold_state.current_level_index))
	_last_player_chunk = Vector2i(2147483647, 2147483647)
	_streamed_chunks = {}
	var stored_bounds: Variant = level_data.get("city_bounds")
	if stored_bounds is Rect2i:
		_city_bounds = stored_bounds
	else:
		_city_bounds = _find_bounds(grid).grow(2)
		level_data["city_bounds"] = _city_bounds
	## _render_city only redraws up to _city_bounds.grow(96): chunks
	## generated beyond that would keep their "generated" flag but never
	## get tiles re-placed nor evicted — permanent invisible void. Drop
	## those keys; _ensure_chunks_around regenerates them deterministically
	## and _apply_hold_diffs_to_rect replays the player's edits.
	if not _generated_chunks.is_empty():
		var render_limit := _city_bounds.grow(96)
		for chunk_key_variant: Variant in _generated_chunks.keys():
			var parts := String(chunk_key_variant).split(",")
			if parts.size() != 2:
				continue
			var chunk := Vector2i(int(parts[0]), int(parts[1]))
			# encloses, not intersects: a chunk straddling the render edge only
			# gets its inner half redrawn, so it must re-stream too.
			if not render_limit.encloses(UndergroundWorldService.chunk_rect(chunk)):
				_generated_chunks.erase(chunk_key_variant)
	_hold_state.active_level_stairs = level_data.get("stair_cells", {}) as Dictionary

	# Chests keep their contents per level: sharing the level_data dict
	# means looting persists and revisits never reroll fresh loot.
	if not (level_data.get("chest_inventories") is Dictionary):
		level_data["chest_inventories"] = {}
	_chest_inventories = level_data.get("chest_inventories") as Dictionary
	## Shop stocks are keyed by anchor cell only: another level's shop can
	## collide on the same anchor and serve wrong/depleted stock.
	_shop_stocks.clear()
	_clear_chest_selection()
	_apply_hold_diffs_to_level(level_data, grid)
	# The previous level's furniture must not block this level's spawn
	# checks; _furnish_interiors rebuilds both maps right after.
	_furnishing_blocked_cells.clear()
	_furnishing_by_cell.clear()
	_light_furnishing_cells.clear()
	_render_city(grid, _hold_state.active_level_stairs)
	_spawn_tavern_characters(grid)
	# After the NPC spawn (which rebuilds the actor layer's children).
	_furnish_interiors(grid)
	_update_summary(grid, seed_input.text.strip_edges())
	_update_zone_overlay()
	_update_depth_controls()
	_maybe_spawn_lair_boss()

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

func _apply_lighting_state() -> void:
	# The layer stays visible: it carries the player lantern glow and placed
	# torches. The toggle gates the darkness overlay and its warm glows, so
	# off = the whole hold fully lit.
	lighting_layer.visible = true
	if _lighting_mask_sprite != null:
		_lighting_mask_sprite.visible = _lighting_enabled
	_set_light_glows_visible(_lighting_enabled)

## Warm additive glows ride on top of the revealed pools; hide them when
## lighting is off so a fully lit hold shows no stray warm blobs.
func _set_light_glows_visible(glows_on: bool) -> void:
	if _player_glow != null:
		_player_glow.visible = glows_on and _player_sprite != null and _darkness_strength > 0.05
	for torch_variant: Variant in _torch_sprites.values():
		var torch := torch_variant as Sprite2D
		if torch == null:
			continue
		for child: Node in torch.get_children():
			var glow := child as Sprite2D
			if glow != null:
				glow.visible = glows_on
	for sconce_variant: Variant in _auto_sconce_sprites.values():
		var sconce := sconce_variant as Sprite2D
		if sconce == null:
			continue
		for child: Node in sconce.get_children():
			var glow := child as Sprite2D
			if glow != null:
				glow.visible = glows_on

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
	## Decor must not ride the live shared _rng: every _show_level revisit
	## would reroll chest/decor positions (fresh farmable loot). The rng is
	## reseeded per cell inside _pick_decor_tile, so a grid that grew from
	## chunk streaming can't shift the sequence for every later cell either.
	var decor_rng := RandomNumberGenerator.new()
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := _cell_at(grid, x, y)
			if cell == CELL_ROCK and not _is_hall_border_rock_cell(grid, x, y):
				continue
			var base_tile := _pick_base_tile(grid, x, y, cell)
			var render_cell := Vector2i(x, y)
			_place_tile(city_layer, render_cell, base_tile)
			var decor_tile := _pick_decor_tile(grid, x, y, cell, base_tile, house_decor_overrides, decor_rng)
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
	_initialize_darkness_overlay(grid)
	_reset_view(bounds)

func _rebuild_district_labels() -> void:
	var existing := city_layer.get_node_or_null("DistrictLabels")
	if existing != null:
		## queue_free keeps the node (and its name) alive until frame end,
		## so the fresh sibling would get auto-renamed and the next lookup
		## would miss it, leaking labels. Rename first, then free.
		existing.name = "DistrictLabelsRetired"
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


## Size and place the darkness overlay to cover the map view. It is a
## single shader quad, so unlike the old fog image it costs nothing to make
## it large; the darkness level and light pools are driven per frame.
func _initialize_darkness_overlay(grid: Dictionary) -> void:
	if _lighting_mask_sprite == null:
		return
	if grid.is_empty():
		_lighting_bounds = Rect2i(Vector2i.ZERO, Vector2i.ONE)
		_lighting_mask_sprite.visible = false
		return
	# Track the live grid (city plus the streamed wild around the walker) so
	# the dark cave follows wherever the dwarf digs. Far chunks are evicted,
	# so the grid - and this quad - stay bounded.
	var lighting_full := _find_bounds(grid).grow(6)
	if _city_bounds.has_area():
		lighting_full = lighting_full.intersection(_city_bounds.grow(600))
	_lighting_bounds = lighting_full
	var origin := Vector2(_lighting_bounds.position * tile_size)
	var size_px := Vector2(
		maxf(float(_lighting_bounds.size.x * tile_size.x), 1.0),
		maxf(float(_lighting_bounds.size.y * tile_size.y), 1.0)
	)
	_lighting_mask_sprite.position = origin
	var texture := _lighting_mask_sprite.texture
	if texture != null:
		var tex_size := texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			_lighting_mask_sprite.scale = size_px / tex_size
	if _darkness_material != null:
		_darkness_material.set_shader_parameter("overlay_origin", origin)
		_darkness_material.set_shader_parameter("overlay_size", size_px)
	_build_occlusion_texture()
	_lighting_mask_sprite.visible = _lighting_enabled
	_update_light_uniforms()

## Rebuild the per-cell wall map for the current _lighting_bounds and hand it
## to the darkness shader. One L8 texel per cell keeps it tiny (1 byte/cell)
## and NEAREST sampling means each texel maps cleanly to its cell.
func _build_occlusion_texture() -> void:
	if _darkness_material == null:
		return
	var base := _lighting_bounds.position
	var wide := maxi(_lighting_bounds.size.x, 1)
	var tall := maxi(_lighting_bounds.size.y, 1)
	var data := PackedByteArray()
	data.resize(wide * tall)
	var index := 0
	for y in range(tall):
		for x in range(wide):
			data[index] = 255 if _cell_blocks_light(Vector2i(base.x + x, base.y + y)) else 0
			index += 1
	_occlusion_image = Image.create_from_data(wide, tall, false, Image.FORMAT_L8, data)
	_occlusion_texture = ImageTexture.create_from_image(_occlusion_image)
	_darkness_material.set_shader_parameter("occlusion_tex", _occlusion_texture)
	_darkness_material.set_shader_parameter("occlusion_origin", Vector2(base))
	_darkness_material.set_shader_parameter("occlusion_size", Vector2(float(wide), float(tall)))
	_darkness_material.set_shader_parameter("tile_px", float(tile_size.x))

## A cell blocks light when it is unrendered solid rock or a non-passable
## wall tile; open floor / passable tiles let light through.
func _cell_blocks_light(cell: Vector2i) -> bool:
	if city_layer.get_cell_source_id(cell) < 0:
		return true
	return not _is_passable_atlas_tile(city_layer.get_cell_atlas_coords(cell))

## Flip a single cell's occlusion texel after its tile changes (e.g. digging
## rock into open hall) so light opens through the new gap without a full
## overlay rebuild.
func _refresh_occlusion_cell(cell: Vector2i) -> void:
	if _occlusion_image == null or _occlusion_texture == null:
		return
	if not _lighting_bounds.has_point(cell):
		return
	var local := cell - _lighting_bounds.position
	var value := 1.0 if _cell_blocks_light(cell) else 0.0
	_occlusion_image.set_pixel(local.x, local.y, Color(value, value, value))
	_occlusion_texture.update(_occlusion_image)

## Feed the overlay shader the live light sources: the player lantern first
## (always lit), then nearby torches, capped to the shader's slot count.
func _update_light_uniforms() -> void:
	if _darkness_material == null:
		return
	# Every source becomes a candidate first, then the NEAREST ones claim
	# the shader's slots. The old fixed class order (placed torches, then
	# furnishings, then sconces) starved whole classes in a dense city:
	# a wall sconce would draw its glow sprite yet never carve the
	# darkness, reading as a bright blob in a black void.
	var player_position := _player_sprite.position if _player_sprite != null else Vector2.ZERO
	# Cull to what the camera can actually show, not a fixed ring around
	# the player - a zoomed-out view must never show an unlit lamp.
	var cull_px := LIGHT_CULL_TILES * float(tile_size.x)
	if city_panel != null and _zoom_level > 0.0:
		cull_px = maxf(cull_px, (city_panel.size * 0.5).length() / _zoom_level + TORCH_LIGHT_TILES * float(tile_size.x))
	var cull_sq := cull_px * cull_px
	# Firelight breathes: torch and hearth radii ride a slow per-source
	# sine so the pools flicker like flame, Core Keeper style. Phases are
	# keyed by cell so neighboring fires never pulse in lockstep.
	var flicker_phase := float(Time.get_ticks_msec()) * 0.001
	var candidates: Array = []
	for torch_cell_variant: Variant in _torch_sprites.keys():
		var torch_cell := torch_cell_variant as Vector2i
		var torch_position := _cell_center_position(torch_cell)
		if torch_position.distance_squared_to(player_position) > cull_sq:
			continue
		var torch_flicker := 1.0 + 0.05 * sin(flicker_phase * 8.0 + float(torch_cell.x * 7 + torch_cell.y * 13))
		candidates.append({"pos": torch_position, "radius": TORCH_LIGHT_TILES * float(tile_size.x) * torch_flicker})
	# The settlement's own fires and candles light their pools, so districts
	# glow around their hearths instead of being uniformly bright.
	for light_cell: Vector2i in _light_furnishing_cells:
		var light_position := _cell_center_position(light_cell)
		if light_position.distance_squared_to(player_position) > cull_sq:
			continue
		var is_hearth := HEARTH_LIGHT_PIECES.has(String(_furnishing_by_cell.get(light_cell, "")))
		var hearth_flicker := 1.0 + (0.04 if is_hearth else 0.0) * sin(flicker_phase * 6.0 + float(light_cell.x * 11 + light_cell.y * 5))
		candidates.append({"pos": light_position, "radius": (HEARTH_LIGHT_TILES if is_hearth else CANDLE_LIGHT_TILES) * float(tile_size.x) * hearth_flicker})
	for sconce_variant: Variant in _auto_sconce_cells.keys():
		var sconce_cell := sconce_variant as Vector2i
		var sconce_position := _cell_center_position(sconce_cell)
		if sconce_position.distance_squared_to(player_position) > cull_sq:
			continue
		var sconce_flicker := 1.0 + 0.05 * sin(flicker_phase * 8.0 + float(sconce_cell.x * 5 + sconce_cell.y * 11))
		candidates.append({"pos": sconce_position, "radius": float(_auto_sconce_cells[sconce_variant]) * float(tile_size.x) * sconce_flicker})
	# Only sort when over budget; the far end of the list is what drops.
	if candidates.size() > MAX_DYNAMIC_LIGHTS - 1:
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return (a.get("pos") as Vector2).distance_squared_to(player_position) < (b.get("pos") as Vector2).distance_squared_to(player_position))
	var positions := PackedVector2Array()
	var radii := PackedFloat32Array()
	if _player_sprite != null:
		positions.append(player_position)
		radii.append(PLAYER_LIGHT_TILES * float(tile_size.x))
	for candidate_variant: Variant in candidates:
		if positions.size() >= MAX_DYNAMIC_LIGHTS:
			break
		var candidate := candidate_variant as Dictionary
		positions.append(candidate.get("pos") as Vector2)
		radii.append(float(candidate.get("radius", 0.0)))
	_darkness_material.set_shader_parameter("light_count", positions.size())
	_darkness_material.set_shader_parameter("light_pos", positions)
	_darkness_material.set_shader_parameter("light_radius", radii)

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
	# A stair arrival chose its own spawn; overland walk-ins step out of
	# the mountain mouth at the south gate; every other fresh entry gets
	# pulled to the Great Hall.
	var arrived_via_stairs := _pending_player_spawn_cell.x != 2147483647
	_pending_player_spawn_cell = Vector2i(2147483647, 2147483647)
	if not arrived_via_stairs:
		if _overland_arrival:
			_overland_arrival = false
			_relocate_player_to_south_gate(grid)
		else:
			_relocate_player_to_city_heart(grid)
	# The lantern pool spawns wherever the dwarf now stands; the per-frame
	# uniform update carries it from here.
	_update_light_uniforms()
	_assign_npc_daily_lives(grid)
	_assign_npc_identities()
	_assign_npc_families()
	_apply_ruler_identity()
	_materialize_dynasty_kin()
	_assign_settlement_factions()
	SettlementAfflictionService.seed_afflictions(_npc_states, _rng)
	_apply_affliction_visuals()
	_apply_identity_appearances()
	_clear_torch_sprites()
	_clear_rail_sprites()
	_clear_minecart_sprites()
	_clear_auto_sconces()
	_clear_creatures()
	_end_fishing("")
	var shown_level := _hold_state.generated_levels[_hold_state.current_level_index] as Dictionary
	for torch_cell_variant: Variant in (shown_level.get("torches", []) as Array):
		_spawn_torch_at(torch_cell_variant as Vector2i)
	# The city lights itself: sconces along the carved streets and at
	# the building doors, rebuilt per level from the grid.
	_spawn_auto_sconces()
	# The level's rail network and parked carts come back with it.
	_rail_cells = {}
	for rail_cell_variant: Variant in (shown_level.get("rails", []) as Array):
		_rail_cells[rail_cell_variant as Vector2i] = true
	for rail_cell_variant: Variant in _rail_cells.keys():
		_spawn_rail_at(rail_cell_variant as Vector2i)
	for cart_cell_variant: Variant in (shown_level.get("carts", []) as Array):
		_spawn_minecart_at(cart_cell_variant as Vector2i)
	# The body was just rebuilt; re-hang whatever the player is holding.
	_refresh_held_item()

## On the district city level the player arrives at the Great Hall, the
## one spot guaranteed to connect to every quarter, rather than a random
## alley pocket.
## The overland walk-in continues INTO the hold: the player appears at
## the city's southern edge near its horizontal center - the inside of
## the mountain mouth they just stepped through - instead of teleporting
## to the Great Hall.
func _relocate_player_to_south_gate(grid: Dictionary) -> void:
	if _player_sprite == null or grid.is_empty():
		return
	var bounds := _find_bounds(grid)
	var center_x := bounds.position.x + bounds.size.x / 2
	var best := Vector2i(2147483647, 2147483647)
	var best_score := -2147483647
	for cell_variant: Variant in grid.keys():
		var cell := cell_variant as Vector2i
		var zone := int(grid[cell_variant])
		if zone != CELL_HALL and zone != CELL_PLAZA:
			continue
		# Southernmost first; near the center column as tie-break.
		var score := cell.y * 1000 - absi(cell.x - center_x)
		if score > best_score:
			best_score = score
			best = cell
	if best.x == 2147483647:
		_relocate_player_to_city_heart(grid)
		return
	_player_cell = best
	_actor_sprite_to_cell(_player_sprite, best)
	_center_view_on_world_position(_player_sprite.position)

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
	# The venue table drives off-shift objectives (tavern, temple, market
	# visits); built once per generation and handed to every update.
	_npc_pois = SettlementNpcScheduler.build_poi_table(building_cells_by_type, Callable(self, "_is_walkable_cell"))
	SettlementNpcScheduler.assign_daily_lives(_npc_states, {
		"bed_cells": _bed_cells,
		"building_cells_by_type": building_cells_by_type,
		"street_cells": street_cells,
		"house_cells": house_cells,
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
	## The seat is claimed BEFORE staffing: the flag keeps the staffing
	## pass from ever posting the sitting ruler behind a counter, while
	## the palace still hires its own Steward of the Hall.
	_designate_hold_ruler()
	## Role quotas cover the classic trades but leave any building type
	## outside every role's workplace list (barber shop, tannery, ...)
	## forever empty; the building-first pass guarantees each civic
	## building at least one worker before anyone takes their post.
	_staff_civic_buildings()
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

## --- Building-first staffing ------------------------------------------------
## assign_daily_lives staffs by role quota, so a generated building whose
## type no role prefers never sees a worker. This pass flips the direction:
## every civic building instance gets at least one resident whose work
## anchor lies inside it, titled by the building's trade ("Barber" for the
## barber shop). Rooms of a multi-room building are grouped through their
## punched partition doors so a tavern with a kitchen and cellar counts as
## ONE workplace staffed for its front-room type.

## Room types _assign_room_roles deals to back rooms. Used to spot which
## room of a grouped building still wears the building's own trade (the
## entrance room is never retagged).
const STAFFING_BACK_ROOM_TYPES := {
	"kitchen": true, "storage_warehouse": true, "granary": true,
	"workshop": true, "armory": true, "archives": true,
	"enchanting_study": true, "guild_hall": true, "bank_vaults": true
}

func _staff_civic_buildings() -> void:
	if _npc_states.is_empty() or _latest_civic_buildings_by_id.is_empty():
		return
	var room_ids: Array[String] = []
	for room_id_variant: Variant in _latest_civic_buildings_by_id.keys():
		room_ids.append(String(room_id_variant))
	## Sorted ids everywhere: staffing must never depend on Dictionary
	## iteration order, only on the seeded rng, so a seed replays exactly.
	room_ids.sort()
	var room_of_cell: Dictionary = {}
	for room_id: String in room_ids:
		var payload := _latest_civic_buildings_by_id[room_id] as Dictionary
		for cell_variant: Variant in (payload.get("cells", []) as Array):
			room_of_cell[cell_variant as Vector2i] = room_id
	var groups := _group_rooms_into_buildings(room_ids, room_of_cell)
	var group_keys: Array[String] = []
	var group_of_room: Dictionary = {}
	for group_key_variant: Variant in groups.keys():
		var group_key := String(group_key_variant)
		group_keys.append(group_key)
		for member_variant: Variant in (groups[group_key] as Array):
			group_of_room[String(member_variant)] = group_key
	group_keys.sort()
	## Who already works where: role-preferred anchors handed out by the
	## scheduler count as staff, so a forge that drew a smith needs no
	## second hire. Guards patrol; their work anchor is not a workplace.
	var workers_by_group: Dictionary = {}
	var group_of_npc: Array[String] = []
	group_of_npc.resize(_npc_states.size())
	for npc_index in _npc_states.size():
		group_of_npc[npc_index] = ""
		var state := _npc_states[npc_index]
		if bool(state.get("is_guard", false)):
			continue
		## The ruler holds court in the palace but is not its keeper: the
		## seat never counts as staff, so the hall still hires a steward.
		if bool(state.get("is_ruler", false)):
			continue
		var anchor := state.get("work_anchor", Vector2i(2147483647, 2147483647)) as Vector2i
		var anchor_room := String(room_of_cell.get(anchor, ""))
		if anchor_room.is_empty():
			continue
		var anchor_group := String(group_of_room.get(anchor_room, ""))
		if anchor_group.is_empty():
			continue
		if not workers_by_group.has(anchor_group):
			workers_by_group[anchor_group] = []
		(workers_by_group[anchor_group] as Array).append(npc_index)
		group_of_npc[npc_index] = anchor_group
	var staffed_buildings := 0
	var shortfall := 0
	var unstaffable := 0
	for group_key: String in group_keys:
		var rooms := groups[group_key] as Array
		var front_room_id := _pick_front_room(rooms)
		var front_payload := _latest_civic_buildings_by_id[front_room_id] as Dictionary
		var building_type := String(front_payload.get("type", "workshop"))
		var profession := String(PROFESSION_BY_BUILDING.get(building_type, "Artisan"))
		var existing := workers_by_group.get(group_key, []) as Array
		if not existing.is_empty():
			## Already staffed: the first-listed worker keeps the shop and
			## takes the trade's title; workmates keep their role titles.
			var keeper := _npc_states[int(existing[0])]
			keeper["staffed_building_type"] = building_type
			keeper["staffed_profession"] = profession
			staffed_buildings += 1
			continue
		var work_cells := _walkable_building_cells(rooms, front_room_id)
		if work_cells.is_empty():
			## Dressing left no floor to stand on: not a workplace at all.
			unstaffable += 1
			continue
		var candidate_index := _pick_staffing_candidate(building_type, workers_by_group, group_of_npc)
		if candidate_index < 0:
			shortfall += 1
			continue
		var old_group := group_of_npc[candidate_index]
		if not old_group.is_empty():
			(workers_by_group[old_group] as Array).erase(candidate_index)
		var state := _npc_states[candidate_index]
		state["work_anchor"] = work_cells[_rng.randi_range(0, work_cells.size() - 1)]
		state["staffed_building_type"] = building_type
		state["staffed_profession"] = profession
		workers_by_group[group_key] = [candidate_index]
		group_of_npc[candidate_index] = group_key
		staffed_buildings += 1
	print("[%s] civic staffing: %d buildings, %d staffed, %d shortfall, %d unstaffable" % [
		name, group_keys.size(), staffed_buildings, shortfall, unstaffable])

## Union-find over room components: two rooms belong to one physical
## building when a punched internal door (a CELL_WALL partition cell with
## room floor on both sides) joins them. Exterior doors sit on ring cells
## inside a single component and union nothing. Doors into converted
## bedrooms see CELL_HOUSE on one side, which is in no civic room either.
func _group_rooms_into_buildings(room_ids: Array[String], room_of_cell: Dictionary) -> Dictionary:
	var parent: Dictionary = {}
	for room_id: String in room_ids:
		parent[room_id] = room_id
	for door_variant: Variant in _door_cells.keys():
		var door_cell := door_variant as Vector2i
		if int(_latest_grid.get(door_cell, CELL_ROCK)) != CELL_WALL:
			continue
		_union_door_sides(parent, room_of_cell, door_cell, Vector2i.LEFT, Vector2i.RIGHT)
		_union_door_sides(parent, room_of_cell, door_cell, Vector2i.UP, Vector2i.DOWN)
	var groups: Dictionary = {}
	for room_id: String in room_ids:
		var root := _find_room_root(parent, room_id)
		if not groups.has(root):
			groups[root] = []
		(groups[root] as Array).append(room_id)
	return groups

func _union_door_sides(parent: Dictionary, room_of_cell: Dictionary, door_cell: Vector2i, side_a: Vector2i, side_b: Vector2i) -> void:
	var room_a := String(room_of_cell.get(door_cell + side_a, ""))
	var room_b := String(room_of_cell.get(door_cell + side_b, ""))
	if room_a.is_empty() or room_b.is_empty() or room_a == room_b:
		return
	var root_a := _find_room_root(parent, room_a)
	var root_b := _find_room_root(parent, room_b)
	if root_a == root_b:
		return
	## The lower id becomes the root so group identity is independent of
	## the order unions arrive in.
	if root_b < root_a:
		var swap := root_a
		root_a = root_b
		root_b = swap
	parent[root_b] = root_a

func _find_room_root(parent: Dictionary, room_id: String) -> String:
	var current := room_id
	var hop := String(parent.get(current, current))
	while hop != current:
		current = hop
		hop = String(parent.get(current, current))
	return current

## The room that still wears the building's own trade. _assign_room_roles
## keeps the entrance room's original type and retags the rest with back
## roles, so prefer an exterior-door room whose type is not a dealt back
## role; ties resolve to the first room in sorted-id order.
func _pick_front_room(rooms: Array) -> String:
	var best_id := String(rooms[0])
	var best_score := 5
	for room_variant: Variant in rooms:
		var room_id := String(room_variant)
		var payload := _latest_civic_buildings_by_id[room_id] as Dictionary
		var is_back: bool = STAFFING_BACK_ROOM_TYPES.has(String(payload.get("type", "")))
		var has_door := false
		for cell_variant: Variant in (payload.get("cells", []) as Array):
			if _door_cells.has(cell_variant as Vector2i):
				has_door = true
				break
		var score := 3
		if has_door and not is_back:
			score = 0
		elif not is_back:
			score = 1
		elif has_door:
			score = 2
		if score < best_score:
			best_score = score
			best_id = room_id
	return best_id

## Standable floor inside the building, front room first so the keeper
## works the shopfront rather than the cellar. Sorted before the rng draw
## so the seeded roll is the only source of variation.
func _walkable_building_cells(rooms: Array, front_room_id: String) -> Array[Vector2i]:
	var ordered_rooms: Array[String] = [front_room_id]
	for room_variant: Variant in rooms:
		var room_id := String(room_variant)
		if room_id != front_room_id:
			ordered_rooms.append(room_id)
	for room_id: String in ordered_rooms:
		var payload := _latest_civic_buildings_by_id[room_id] as Dictionary
		var walkable: Array[Vector2i] = []
		for cell_variant: Variant in (payload.get("cells", []) as Array):
			var cell := cell_variant as Vector2i
			if _is_walkable_cell(cell):
				walkable.append(cell)
		if not walkable.is_empty():
			walkable.sort()
			return walkable
	return []

## Best unhired dwarf for a vacant building: a role that already lists the
## trade, then the filler roles, then anyone who isn't a guard or a Hold
## Elder — guards must patrol and elders hold a quota, so neither is
## conscripted into shopkeeping (elders still staff their own preferred
## types through the role-match tiers, which leaves their role intact).
## Within each pair of tiers the idle (street-anchored) hire first;
## pulling a workmate is allowed only when it leaves the old workplace
## still staffed. Dwarfs already titled as keepers are never re-hired.
func _pick_staffing_candidate(building_type: String, workers_by_group: Dictionary, group_of_npc: Array[String]) -> int:
	for tier in 6:
		for npc_index in _npc_states.size():
			var state := _npc_states[npc_index]
			if bool(state.get("is_guard", false)):
				continue
			## The sitting ruler is never pulled behind a shop counter.
			if bool(state.get("is_ruler", false)):
				continue
			if state.has("staffed_building_type"):
				continue
			var role := int(state.get("role", 0))
			var role_matches: bool = (ROLE_WORKPLACES.get(role, []) as Array).has(building_type)
			var is_filler := role == ROLE_MINER or role == ROLE_DWARF_WOMAN
			if tier <= 1 and not role_matches:
				continue
			if (tier == 2 or tier == 3) and not is_filler:
				continue
			if tier >= 4 and role == ROLE_HOLD_ELDER:
				continue
			var idle := group_of_npc[npc_index].is_empty()
			if tier % 2 == 0:
				if not idle:
					continue
			else:
				if idle:
					continue
				var old_workers := workers_by_group.get(group_of_npc[npc_index], []) as Array
				if old_workers.size() < 2:
					continue
			return npc_index
	return -1

func _stream_world_chunks() -> void:
	if _world_noise.is_empty() or _player_sprite == null:
		return
	var player_chunk: Vector2i = UndergroundWorldService.chunk_for_cell(_player_cell)
	if player_chunk == _last_player_chunk:
		return
	_last_player_chunk = player_chunk
	_ensure_chunks_around(player_chunk)
	_evict_far_chunks(player_chunk)
	# The wild around the walker just changed shape; resize the dark overlay
	# quad so freshly streamed cavern stays in the dark, not lit through.
	_initialize_darkness_overlay(_latest_grid)

## Core Keeper rule: the world only exists near the player. Wild chunks
## more than EVICT_CHUNK_RADIUS out are dropped entirely - tiles, grid
## entries, decor, creatures - and rebuilt from seed plus the player's
## recorded diffs when walked back into. The city core is never evicted.
const EVICT_CHUNK_RADIUS := 4

## Sites and discoveries stamp structures that spill past their chunk;
## evicting any chunk they touch would tear holes in them. Underdeep
## sites only stamp on the DEEPEST level, so only that level's chunks
## earn their protection - guarding them everywhere left unstamped
## chunks on shallow levels unevictable.
func _chunk_neighborhood_has_stamp(chunk: Vector2i) -> bool:
	var sites_stamp_here := _hold_state.is_deepest()
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var neighbor := chunk + Vector2i(dx, dy)
			if _discovery_chunks.has(neighbor):
				return true
			if sites_stamp_here and not (_sites_by_chunk.get(UndergroundWorldService.chunk_key(neighbor), []) as Array).is_empty():
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
				# Evicted rock regenerates at full durability.
				if _rock_damage.has(cell) or _rock_crack_sprites.has(cell):
					_clear_rock_crack(cell)
				# Rails and parked carts release their sprites with the
				# chunk; the level data re-raises them on return.
				var rail := _rail_sprites.get(cell) as Sprite2D
				if rail != null:
					rail.queue_free()
					_rail_sprites.erase(cell)
				var cart := _minecart_sprites.get(cell) as Sprite2D
				if cart != null and not (_cart_riding and cell == _cart_cell):
					cart.queue_free()
					_minecart_sprites.erase(cell)
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

## Walked back into an evicted area: the recorded torches, rails and
## carts get their sprites back.
func _respawn_torches_in_rect(rect: Rect2i) -> void:
	if not _hold_state.has_levels():
		return
	var level_data := _hold_state.generated_levels[_hold_state.current_level_index] as Dictionary
	for torch_cell_variant: Variant in (level_data.get("torches", []) as Array):
		var cell := torch_cell_variant as Vector2i
		if rect.has_point(cell):
			_spawn_torch_at(cell)
	for rail_cell_variant: Variant in (level_data.get("rails", []) as Array):
		var cell := rail_cell_variant as Vector2i
		if rect.has_point(cell):
			_spawn_rail_at(cell)
			_refresh_rail_art_around(cell)
	for cart_cell_variant: Variant in (level_data.get("carts", []) as Array):
		var cell := cart_cell_variant as Vector2i
		if rect.has_point(cell):
			_spawn_minecart_at(cell)

func _ensure_chunks_around(player_chunk: Vector2i) -> void:
	for chunk_dy in range(-2, 3):
		for chunk_dx in range(-2, 3):
			var chunk := player_chunk + Vector2i(chunk_dx, chunk_dy)
			var key: String = UndergroundWorldService.chunk_key(chunk)
			if _generated_chunks.has(key):
				continue
			_generated_chunks[key] = true
			var stamped_site := false
			# Underdeep settlements live at the BOTTOM of the world: they
			# stamp only on the deepest level, not once per stratum.
			if _hold_state.is_deepest():
				for site_variant: Variant in (_sites_by_chunk.get(key, []) as Array):
					var site := site_variant as Dictionary
					UndergroundWorldService.stamp_settlement_site(_latest_grid, _latest_floor_decor, site)
					_append_district_label_once({"name": String(site.get("name", "")), "center": site.get("cell", Vector2i.ZERO), "wild": true})
					stamped_site = true
			var discovery: Dictionary = UndergroundWorldService.stamp_chunk_discovery(_latest_grid, _latest_floor_decor, chunk, _level_world_seed(_hold_state.current_level_index))
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
	_stamp_active_stairs_in_rect(rect)

## Re-stamps the active level's staircases inside a repainted rect.
## Chunk streaming, digging and building all repaint base tiles through
## _render_world_rect, and _pick_base_tile knows nothing about stairs —
## without this the stairway tile visibly vanishes (and stops working)
## the moment a nearby chunk streams in. Any future repaint path must
## call this too.
func _stamp_active_stairs_in_rect(rect: Rect2i) -> void:
	for stair_key: String in ["up", "down"]:
		if not _hold_state.active_level_stairs.has(stair_key):
			continue
		var stair_cell := _hold_state.active_level_stairs[stair_key] as Vector2i
		if not rect.has_point(stair_cell):
			continue
		if city_layer.get_cell_source_id(stair_cell) < 0:
			continue
		_place_tile(city_layer, stair_cell, "stairway_up" if stair_key == "up" else "stairway_down")
		decor_layer.erase_cell(stair_cell)
		_actor_passable_cache.erase(stair_cell)

## Rock digs on EVERY level: the surface hold's streamed wilds and the
## deep strata alike (the pick's whole geology ladder lives down there).
## The dig ledger persists per level, so deep tunnels survive revisits.
func _is_diggable_cell(cell: Vector2i) -> bool:
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

## Frees dropped-item sprites and empties the list, so a level rebuild can't
## leave stale entries that re-grant items when the player stands on a
## matching cell on the next level.
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

## The quick keys: potions drink, food eats, tools report themselves.
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
	## _spawn_torch_at silently no-ops on an occupied cell: without this
	## guard a double-place still eats the Stone and duplicates the cell
	## in the torches array.
	if _torch_sprites.has(_player_cell):
		_set_save_status("A torch already burns here", Color(0.95, 0.75, 0.45, 1.0))
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
	# The living flame: an animated sprite riding the torch head, its
	# tongue swaying frame to frame like the reference candles.
	var flame := AnimatedSprite2D.new()
	flame.sprite_frames = _torch_flame_frames()
	flame.animation = &"burn"
	flame.position = Vector2(0.0, -10.0)
	flame.play()
	# Stagger phases so a corridor of torches never dances in unison.
	flame.frame = absi(cell.x * 7 + cell.y * 13) % 3
	torch.add_child(flame)
	# The glow sprite is the flame's own corona, nothing more: the
	# darkness shader is the ONE system that lights the ground (and it
	# respects walls, which an additive blob never can). Full-radius
	# glows painted a second, wall-ignoring light over the shader's
	# pools and the two reads fought each other.
	var glow := _create_glow_sprite(FLAME_HALO_TILES)
	glow.position = Vector2.ZERO
	glow.visible = _lighting_enabled
	torch.add_child(glow)
	_attach_glow_pulse(glow, cell)
	_torch_sprites[cell] = torch
	# A fresh torch is a new light pool; hand it to the shader at once.
	_update_light_uniforms()

## A soft breathing pulse on a light's warm halo, phase-varied per cell
## so neighboring fires never throb together.
func _attach_glow_pulse(glow: Sprite2D, cell: Vector2i) -> void:
	var base_scale := glow.scale
	var period := 0.5 + float(absi(cell.x * 31 + cell.y * 17) % 40) * 0.01
	var pulse := glow.create_tween().set_loops()
	pulse.tween_property(glow, "scale", base_scale * 1.12, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(glow, "scale", base_scale, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

var _torch_flame_frames_cache: SpriteFrames = null

## Three flame frames, tip swaying left-center-right.
func _torch_flame_frames() -> SpriteFrames:
	if _torch_flame_frames_cache != null:
		return _torch_flame_frames_cache
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
	_torch_flame_frames_cache = frames
	return frames

func _clear_torch_sprites() -> void:
	for torch_variant: Variant in _torch_sprites.values():
		var torch := torch_variant as Sprite2D
		if torch != null:
			torch.queue_free()
	_torch_sprites = {}

## --- Generated street lighting ---------------------------------------------
## Every SCONCE_SPACING-th street cell that hugs a wall carries a torch
## or candle stand, and building doors get a torch beside them - the
## hold's own folk keep their halls lit. Deterministic per cell, rebuilt
## with each level, and fed to the darkness shader after the player's
## own lights.
const SCONCE_SPACING := 6
const SCONCE_LIGHT_TILES := 6.5
const CANDLE_SCONCE_LIGHT_TILES := 4.5

func _clear_auto_sconces() -> void:
	for sconce_variant: Variant in _auto_sconce_sprites.values():
		var sconce := sconce_variant as Sprite2D
		if sconce != null:
			sconce.queue_free()
	_auto_sconce_sprites = {}
	_auto_sconce_cells = {}

func _spawn_auto_sconces() -> void:
	if _latest_grid.is_empty() or not _city_bounds.has_area():
		return
	for cell_variant: Variant in _latest_grid.keys():
		var cell := cell_variant as Vector2i
		if not _city_bounds.has_point(cell):
			continue
		var zone := int(_latest_grid[cell_variant])
		if zone != CELL_HALL and zone != CELL_PLAZA:
			continue
		# Sconces hang on walls: the cell must hug rock or a building
		# face.
		var against_wall := false
		for offset: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
			var neighbor_zone := int(_latest_grid.get(cell + offset, CELL_ROCK))
			if neighbor_zone == CELL_ROCK or neighbor_zone == CELL_BUILDING or neighbor_zone == CELL_HOUSE or neighbor_zone == CELL_WALL:
				against_wall = true
				break
		if not against_wall:
			continue
		var roll := hash("sconce|%d|%d|%d" % [_world_seed_hash, cell.x, cell.y])
		if (roll & 0xffff) % SCONCE_SPACING != 0:
			continue
		_spawn_sconce_at(cell, ((roll >> 16) & 0xff) % 3 == 0)
	# A torch beside most building doors, so thresholds glow welcome.
	for door_variant: Variant in _door_cells.keys():
		var door_cell := door_variant as Vector2i
		var roll := hash("door_sconce|%d|%d|%d" % [_world_seed_hash, door_cell.x, door_cell.y])
		if (roll & 0xffff) % 5 == 0:
			continue
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var beside := door_cell + offset
			if _auto_sconce_cells.has(beside) or _torch_sprites.has(beside):
				continue
			var zone := int(_latest_grid.get(beside, CELL_ROCK))
			if zone == CELL_HALL or zone == CELL_PLAZA:
				_spawn_sconce_at(beside, false)
				break

func _spawn_sconce_at(cell: Vector2i, is_candle: bool) -> void:
	if _auto_sconce_sprites.has(cell) or _torch_sprites.has(cell):
		return
	var sconce := Sprite2D.new()
	if is_candle:
		if _candle_sconce_texture == null:
			_candle_sconce_texture = _create_candle_sconce_texture()
		sconce.texture = _candle_sconce_texture
	else:
		if _torch_texture == null:
			_torch_texture = _create_torch_texture()
		sconce.texture = _torch_texture
	sconce.centered = true
	sconce.position = _cell_center_position(cell)
	sconce.z_index = 14
	lighting_layer.add_child(sconce)
	if not is_candle:
		var flame := AnimatedSprite2D.new()
		flame.sprite_frames = _torch_flame_frames()
		flame.animation = &"burn"
		flame.position = Vector2(0.0, -10.0)
		flame.play()
		flame.frame = absi(cell.x * 7 + cell.y * 13) % 3
		sconce.add_child(flame)
	# The shader still lights the sconce's full pool (via
	# _auto_sconce_cells below); the sprite is only the flame's corona.
	var radius_tiles := CANDLE_SCONCE_LIGHT_TILES if is_candle else SCONCE_LIGHT_TILES
	var glow := _create_glow_sprite(CANDLE_HALO_TILES if is_candle else FLAME_HALO_TILES)
	glow.position = Vector2.ZERO
	glow.visible = _lighting_enabled
	sconce.add_child(glow)
	_attach_glow_pulse(glow, cell)
	_auto_sconce_sprites[cell] = sconce
	_auto_sconce_cells[cell] = radius_tiles

## A cluster of three lit candles on a small iron dish.
func _create_candle_sconce_texture() -> Texture2D:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var wax := Color(0.93, 0.89, 0.78, 1.0)
	var flame := Color(1.0, 0.8, 0.3, 1.0)
	var dish := Color(0.28, 0.27, 0.3, 1.0)
	for candle_index in range(3):
		var cx := [5, 8, 11][candle_index] as int
		var top := [7, 5, 8][candle_index] as int
		for y in range(top, 12):
			image.set_pixel(cx, y, wax)
			image.set_pixel(cx + 1, y, wax)
		image.set_pixel(cx, top - 1, flame)
		image.set_pixel(cx + 1, top - 2, Color(1.0, 0.95, 0.6, 1.0))
	for x in range(3, 14):
		image.set_pixel(x, 12, dish)
		image.set_pixel(x, 13, dish)
	image.resize(32, 32, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)

## --- Minecarts -------------------------------------------------------------
## Core Keeper-style rails: lay track cell by cell (R, 1 Timber + 1
## Stone), set a cart on it (C, 2 Iron Ingots), climb aboard (C beside
## the cart) and pick a direction - the cart barrels along the track,
## following corners, steered at junctions by whatever direction is
## held, and stops at the end of the line. C steps off a stopped cart.

const RAIL_TIMBER_COST := 1
const RAIL_STONE_COST := 1
const CART_INGOT_COST := 2
const CART_SPEED_TILES := 7.0

func _place_rail() -> void:
	if _player_sprite == null:
		return
	var cell := _player_cell
	if _rail_cells.has(cell):
		_set_save_status("Rails already run here", Color(0.85, 0.8, 0.7, 1.0))
		return
	if int(_player_inventory.get("Timber", 0)) < RAIL_TIMBER_COST or int(_player_inventory.get("Stone", 0)) < RAIL_STONE_COST:
		_set_save_status("Need %d Timber and %d Stone to lay rails" % [RAIL_TIMBER_COST, RAIL_STONE_COST], Color(0.95, 0.75, 0.45, 1.0))
		return
	_add_to_inventory("Timber", -RAIL_TIMBER_COST)
	_add_to_inventory("Stone", -RAIL_STONE_COST)
	var level_data := _hold_state.generated_levels[_hold_state.current_level_index] as Dictionary
	if not level_data.has("rails"):
		level_data["rails"] = []
	(level_data["rails"] as Array).append(cell)
	_record_hold_edit("rails", cell)
	_rail_cells[cell] = true
	_spawn_rail_at(cell)
	_refresh_rail_art_around(cell)
	_set_save_status("Rails laid", Color(0.85, 0.82, 0.7, 1.0))

func _spawn_rail_at(cell: Vector2i) -> void:
	_rail_cells[cell] = true
	if _rail_sprites.has(cell):
		return
	var rail := Sprite2D.new()
	rail.texture = _rail_texture_for(_rail_signature(cell))
	rail.centered = true
	rail.position = _cell_center_position(cell)
	# Above the floor, below every actor (player/NPCs 11, creatures 12).
	rail.z_index = 4
	lighting_layer.add_child(rail)
	_rail_sprites[cell] = rail

## Re-derives the connection art of a cell and its four neighbors after
## the network changes.
func _refresh_rail_art_around(cell: Vector2i) -> void:
	for offset: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbor := cell + offset
		var sprite := _rail_sprites.get(neighbor) as Sprite2D
		if sprite != null:
			sprite.texture = _rail_texture_for(_rail_signature(neighbor))

func _clear_rail_sprites() -> void:
	for rail_variant: Variant in _rail_sprites.values():
		var rail := rail_variant as Sprite2D
		if rail != null:
			rail.queue_free()
	_rail_sprites = {}

## Which arms this rail cell extends toward its rail neighbors: "ns",
## "ew", corners, or the full cross; a stub follows its one neighbor's
## axis, an orphan lies east-west.
func _rail_signature(cell: Vector2i) -> String:
	var north := _rail_cells.has(cell + Vector2i(0, -1))
	var east := _rail_cells.has(cell + Vector2i(1, 0))
	var south := _rail_cells.has(cell + Vector2i(0, 1))
	var west := _rail_cells.has(cell + Vector2i(-1, 0))
	var count := (1 if north else 0) + (1 if east else 0) + (1 if south else 0) + (1 if west else 0)
	if count >= 3:
		return "cross"
	if north and south:
		return "ns"
	if east and west:
		return "ew"
	if north and east:
		return "ne"
	if north and west:
		return "nw"
	if south and east:
		return "se"
	if south and west:
		return "sw"
	if north or south:
		return "ns"
	return "ew"

## Track art painted on demand per signature: iron rails riding wooden
## sleepers, arms reaching the tile edges they connect toward.
func _rail_texture_for(signature: String) -> Texture2D:
	var cached_variant: Variant = _rail_textures.get(signature)
	if cached_variant is Texture2D:
		return cached_variant as Texture2D
	var arms := {
		"ns": [true, false, true, false], "ew": [false, true, false, true],
		"ne": [true, true, false, false], "nw": [true, false, false, true],
		"se": [false, true, true, false], "sw": [false, false, true, true],
		"cross": [true, true, true, true]
	}.get(signature, [false, true, false, true]) as Array
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var sleeper := Color(0.42, 0.29, 0.17, 1.0)
	var iron := Color(0.55, 0.53, 0.5, 1.0)
	var iron_dark := Color(0.34, 0.33, 0.32, 1.0)
	# Vertical arm: sleepers span x4..11 every 3px, rails at x5 and x10.
	if bool(arms[0]) or bool(arms[2]):
		var y_start := 0 if bool(arms[0]) else 7
		var y_end := 16 if bool(arms[2]) else 9
		for ty in range(y_start, y_end):
			if ty % 3 == 1:
				for tx in range(4, 12):
					image.set_pixel(tx, ty, sleeper)
		for ty in range(y_start, y_end):
			image.set_pixel(5, ty, iron)
			image.set_pixel(6, ty, iron_dark)
			image.set_pixel(10, ty, iron)
			image.set_pixel(11, ty, iron_dark)
	if bool(arms[1]) or bool(arms[3]):
		var x_start := 7 if not bool(arms[3]) else 0
		var x_end := 9 if not bool(arms[1]) else 16
		for tx in range(x_start, x_end):
			if tx % 3 == 1:
				for ty in range(4, 12):
					image.set_pixel(tx, ty, sleeper)
		for tx in range(x_start, x_end):
			image.set_pixel(tx, 5, iron)
			image.set_pixel(tx, 6, iron_dark)
			image.set_pixel(tx, 10, iron)
			image.set_pixel(tx, 11, iron_dark)
	image.resize(int(tile_size.x), int(tile_size.y), Image.INTERPOLATE_NEAREST)
	var texture := ImageTexture.create_from_image(image)
	_rail_textures[signature] = texture
	return texture

func _create_minecart_texture() -> Texture2D:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var body := Color(0.36, 0.3, 0.26, 1.0)
	var rim := Color(0.55, 0.48, 0.4, 1.0)
	var hollow := Color(0.16, 0.13, 0.11, 1.0)
	var wheel := Color(0.12, 0.12, 0.13, 1.0)
	for ty in range(4, 13):
		for tx in range(3, 13):
			var tone := body
			if ty == 4 or ty == 12 or tx == 3 or tx == 12:
				tone = rim
			elif ty >= 6 and ty <= 10 and tx >= 5 and tx <= 10:
				tone = hollow
			image.set_pixel(tx, ty, tone)
	for wheel_x: int in [4, 11]:
		image.set_pixel(wheel_x, 13, wheel)
		image.set_pixel(wheel_x + 1, 13, wheel)
	image.resize(int(tile_size.x), int(tile_size.y), Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)

func _spawn_minecart_at(cell: Vector2i) -> void:
	if _minecart_sprites.has(cell):
		return
	if _minecart_texture == null:
		_minecart_texture = _create_minecart_texture()
	var cart := Sprite2D.new()
	cart.texture = _minecart_texture
	cart.centered = true
	cart.position = _cell_center_position(cell)
	cart.z_index = 10
	lighting_layer.add_child(cart)
	_minecart_sprites[cell] = cart

func _clear_minecart_sprites() -> void:
	for cart_variant: Variant in _minecart_sprites.values():
		var cart := cart_variant as Sprite2D
		if cart != null:
			cart.queue_free()
	_minecart_sprites = {}
	_cart_riding = false
	_cart_dir = Vector2i.ZERO

## C beside (or atop) a cart mounts it; C on your own rail with ingots
## to spare builds one; C aboard a stopped cart steps off.
func _handle_cart_key() -> void:
	if _player_sprite == null:
		return
	if _cart_riding:
		if _cart_dir == Vector2i.ZERO:
			_dismount_cart()
		else:
			_set_save_status("Hold on!", Color(0.9, 0.8, 0.6, 1.0))
		return
	var mount_cell := Vector2i(2147483647, 2147483647)
	if _minecart_sprites.has(_player_cell):
		mount_cell = _player_cell
	else:
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if _minecart_sprites.has(_player_cell + offset):
				mount_cell = _player_cell + offset
				break
	if mount_cell.x != 2147483647:
		_mount_cart(mount_cell)
		return
	_place_minecart()

func _place_minecart() -> void:
	var cell := _player_cell
	if not _rail_cells.has(cell):
		_set_save_status("A minecart needs rails beneath it (R to lay track)", Color(0.95, 0.75, 0.45, 1.0))
		return
	if _minecart_sprites.has(cell):
		_set_save_status("A cart already waits here", Color(0.85, 0.8, 0.7, 1.0))
		return
	if int(_player_inventory.get("Iron Ingot", 0)) < CART_INGOT_COST:
		_set_save_status("Need %d Iron Ingots to build a minecart" % CART_INGOT_COST, Color(0.95, 0.75, 0.45, 1.0))
		return
	_add_to_inventory("Iron Ingot", -CART_INGOT_COST)
	var level_data := _hold_state.generated_levels[_hold_state.current_level_index] as Dictionary
	if not level_data.has("carts"):
		level_data["carts"] = []
	(level_data["carts"] as Array).append(cell)
	_record_hold_edit("cart_at", cell, true)
	_spawn_minecart_at(cell)
	_set_save_status("Minecart built - press C beside it to ride", Color(0.85, 0.82, 0.7, 1.0))

func _mount_cart(cell: Vector2i) -> void:
	_cart_riding = true
	_cart_cell = cell
	_cart_origin_cell = cell
	_cart_dir = Vector2i.ZERO
	_cart_desired_dir = Vector2i.ZERO
	_cart_progress = 0.0
	_player_move_path.clear()
	_player_is_moving = false
	_player_cell = cell
	_player_sprite.position = _cell_center_position(cell)
	_center_view_on_world_position(_player_sprite.position)
	_set_save_status("Aboard - hold a direction to ride, C to step off", Color(0.85, 0.82, 0.7, 1.0))

func _dismount_cart() -> void:
	_cart_riding = false
	_cart_dir = Vector2i.ZERO
	# Step off onto the first open non-rail neighbor; failing that, any
	# open neighbor; failing THAT, stay put on the cart cell.
	for prefer_off_rail: bool in [true, false]:
		for offset: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
			var step_cell := _cart_cell + offset
			if not _is_walkable_cell(step_cell) or _is_cell_occupied_by_npc(step_cell):
				continue
			if bool(prefer_off_rail) and _rail_cells.has(step_cell):
				continue
			_player_cell = step_cell
			_player_sprite.position = _cell_center_position(step_cell)
			_center_view_on_world_position(_player_sprite.position)
			return

## The ride itself: the cart barrels toward the next rail cell, follows
## lone corners, honors the held direction at junctions, and brakes at
## the end of the line (recording its new resting place in the ledger).
func _update_minecart(delta: float) -> void:
	if not _cart_riding or _cart_dir == Vector2i.ZERO:
		return
	_cart_progress += delta * CART_SPEED_TILES
	while _cart_progress >= 1.0 and _cart_dir != Vector2i.ZERO:
		_cart_progress -= 1.0
		_move_cart_to(_cart_cell + _cart_dir)
		_cart_dir = _next_cart_direction()
		if _cart_dir == Vector2i.ZERO:
			_settle_cart()
	var cart := _minecart_sprites.get(_cart_cell) as Sprite2D
	var glide := _cell_center_position(_cart_cell)
	if _cart_dir != Vector2i.ZERO:
		glide += Vector2(_cart_dir) * Vector2(tile_size) * clampf(_cart_progress, 0.0, 1.0)
	if cart != null:
		cart.position = glide
	_player_sprite.position = glide
	_center_view_on_world_position(glide)

func _move_cart_to(next_cell: Vector2i) -> void:
	var cart := _minecart_sprites.get(_cart_cell) as Sprite2D
	_minecart_sprites.erase(_cart_cell)
	_cart_cell = next_cell
	_player_cell = next_cell
	if cart != null:
		_minecart_sprites[next_cell] = cart

## Straight ahead first, then the held direction, then a lone corner;
## never straight back the way it came.
func _next_cart_direction() -> Vector2i:
	var candidates: Array[Vector2i] = []
	if _cart_desired_dir != Vector2i.ZERO and _cart_desired_dir != -_cart_dir and _rail_cells.has(_cart_cell + _cart_desired_dir):
		return _cart_desired_dir
	if _rail_cells.has(_cart_cell + _cart_dir):
		return _cart_dir
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if offset == -_cart_dir:
			continue
		if _rail_cells.has(_cart_cell + offset):
			candidates.append(offset)
	if candidates.size() == 1:
		return candidates[0]
	return Vector2i.ZERO

## The cart came to rest: move its ledger entry from where it started to
## where it stopped so regeneration rebuilds it here.
func _settle_cart() -> void:
	_cart_progress = 0.0
	if _cart_origin_cell == _cart_cell:
		return
	var level_data := _hold_state.generated_levels[_hold_state.current_level_index] as Dictionary
	var carts := level_data.get("carts", []) as Array
	carts.erase(_cart_origin_cell)
	if not carts.has(_cart_cell):
		carts.append(_cart_cell)
	level_data["carts"] = carts
	_record_hold_edit("cart_at", _cart_origin_cell, false)
	_record_hold_edit("cart_at", _cart_cell, true)
	_cart_origin_cell = _cart_cell

func _create_torch_texture() -> Texture2D:
	# Just the stick and its iron collar - the flame is a separate
	# ANIMATED sprite so it can sway (see _torch_flame_frames).
	var image := Image.create(8, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(7, 15):
		image.set_pixel(3, y, Color(0.45, 0.3, 0.16, 1.0))
		image.set_pixel(4, y, Color(0.36, 0.24, 0.13, 1.0))
	image.set_pixel(2, 7, Color(0.3, 0.3, 0.34, 1.0))
	image.set_pixel(5, 7, Color(0.3, 0.3, 0.34, 1.0))
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
	_trade_click_cell = cell
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
	_trade_click_cell = Vector2i(2147483647, 2147483647)
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
		## The sitting ruler's composed sprite wears a small gold circlet.
		var is_crowned := bool(state.get("is_ruler", false))
		var cache_key := "%s|crown:%s" % [str(layers), str(is_crowned)]
		if not texture_cache.has(cache_key):
			texture_cache[cache_key] = (
				DwarfSpriteComposer.compose_crowned(layers)
				if is_crowned
				else DwarfSpriteComposer.compose(layers)
			)
		sprite.texture = texture_cache[cache_key]
		sprite.region_enabled = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(
			float(tile_size.x) / 32.0,
			float(tile_size.y) / 32.0
		) * float(layers.get("body_scale", 1.0))
		state["composed"] = true

## The trade on a dwarf's card: the sitting ruler wears their throne
## title, a posted keeper wears their building's profession ("Barber"),
## everyone else their spritesheet role title.
func _npc_role_title(state: Dictionary) -> String:
	var throne_title := String(state.get("ruler_title", ""))
	if not throne_title.is_empty():
		return throne_title
	var staffed_title := String(state.get("staffed_profession", ""))
	if not staffed_title.is_empty():
		return staffed_title
	return String(ROLE_TITLES.get(int(state.get("role", 0)), "Dwarf"))

func _assign_npc_identities() -> void:
	var used_names: Dictionary = {}
	for state: Dictionary in _npc_states:
		var role_title := _npc_role_title(state)
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

## --- The sitting ruler --------------------------------------------------
## The chronicle's succession line ends in a real dwarf: the settlement's
## sitting ruler walks the city level as a named NPC, holds court at the
## High King's Palace (or the guild hall, or the largest civic building),
## wears a pixel circlet, and answers with rank-appropriate lines. The
## dynasty behind them feeds the inspection card's family-tree tab.

## Chronicle entry for this hold (ruler name/title/lineage). Standalone
## runs without an overworld chronicle crown a seeded fallback so tests
## and direct scene boots still seat somebody.
func _resolve_ruler_record() -> Dictionary:
	var chronicle := WorldChronicleService.chronicle_from_settings(_world_settings_snapshot())
	var entry := WorldChronicleService.settlement_entry_by_name(chronicle, _hold_name)
	if not entry.is_empty() and int(entry.get("fell_year", 0)) <= 0 \
			and not String(entry.get("ruler_name", "")).strip_edges().is_empty():
		var record := entry.duplicate(true)
		## Chronicles minted before the dynasty graphs (or fabricated by
		## tests) carry a lineage but no family — grow one, seed-stable.
		var family_variant: Variant = record.get("family", {})
		if not (family_variant is Dictionary) or (family_variant as Dictionary).is_empty():
			var family_rng := RandomNumberGenerator.new()
			family_rng.seed = hash("%s|%s|ruler_family" % [seed_input.text.strip_edges(), _hold_name])
			record["family"] = WorldChronicleService.build_family_for_lineage(
				record.get("lineage", []) as Array,
				String(record.get("clan", "")),
				_calendar_start_year,
				family_rng
			)
		return record
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|hold_ruler" % seed_input.text.strip_edges())
	var ruler_gender := NpcIdentityService.roll_dwarf_gender(rng)
	var first_name := NpcIdentityService.dwarf_ruler_first_name(rng, ruler_gender)
	var clan := NpcIdentityService.DWARF_CLAN_NAMES[rng.randi_range(0, NpcIdentityService.DWARF_CLAN_NAMES.size() - 1)]
	var title := NpcIdentityService.dwarf_ruler_title(rng, ruler_gender, false)
	var since := maxi(1, _calendar_start_year - rng.randi_range(4, 30))
	var full_name := "%s %s" % [first_name, clan]
	var lineage: Array = [{
		"name": full_name,
		"title": title,
		"gender": ruler_gender,
		"start": since,
		"end": 0,
		"violent_end": false,
		"sitting": true
	}]
	return {
		"ruler_name": full_name,
		"ruler_title": title,
		"ruler_gender": ruler_gender,
		"ruler_since": since,
		"lineage": lineage,
		"family": WorldChronicleService.build_family_for_lineage(lineage, clan, _calendar_start_year, rng)
	}

## Where the ruler holds court: walkable floor of the palace when the
## level raised one, else the guild hall, else the roomiest civic
## building. Sorted room ids and cells keep the choice seed-stable.
func _ruler_station_cells() -> Array[Vector2i]:
	var best_cells: Array[Vector2i] = []
	var best_rank := 3
	var best_size := 0
	var room_ids: Array[String] = []
	for room_id_variant: Variant in _latest_civic_buildings_by_id.keys():
		room_ids.append(String(room_id_variant))
	room_ids.sort()
	for room_id: String in room_ids:
		var payload := _latest_civic_buildings_by_id[room_id] as Dictionary
		var building_type := String(payload.get("type", ""))
		var rank := 2
		if building_type == "high_kings_palace":
			rank = 0
		elif building_type == "guild_hall":
			rank = 1
		if rank > best_rank:
			continue
		var walkable: Array[Vector2i] = []
		for cell_variant: Variant in (payload.get("cells", []) as Array):
			var cell := cell_variant as Vector2i
			if _is_walkable_cell(cell):
				walkable.append(cell)
		if walkable.is_empty():
			continue
		walkable.sort()
		if rank < best_rank or walkable.size() > best_size:
			best_rank = rank
			best_size = walkable.size()
			best_cells = walkable
	return best_cells

## Crowns one resident on the city level BEFORE the staffing pass, so
## the is_ruler flag excludes them from every shopkeeper pull while the
## palace still hires its own steward.
func _designate_hold_ruler() -> void:
	_ruler_npc_index = -1
	_ruler_record = {}
	if _npc_states.is_empty() or _hold_state.current_level_index != 0:
		return
	## Fallen holds keep no court: nobody sits a throne in silent halls.
	if not _hold_fall_text.is_empty():
		return
	var station_cells := _ruler_station_cells()
	if station_cells.is_empty():
		return
	_ruler_record = _resolve_ruler_record()
	if String(_ruler_record.get("ruler_name", "")).strip_edges().is_empty():
		return
	var candidates: Array[int] = []
	for npc_index: int in range(_npc_states.size()):
		if not bool(_npc_states[npc_index].get("is_guard", false)):
			candidates.append(npc_index)
	if candidates.is_empty():
		return
	_ruler_npc_index = candidates[_rng.randi_range(0, candidates.size() - 1)]
	var state := _npc_states[_ruler_npc_index]
	state["is_ruler"] = true
	state["work_anchor"] = station_cells[_rng.randi_range(0, station_cells.size() - 1)]

## The crowned NPC becomes the actual ruler AFTER the family pass, so no
## later surname adoption can undo the royal name; kin links minted under
## the pre-coronation name follow the crown.
func _apply_ruler_identity() -> void:
	if _ruler_npc_index < 0 or _ruler_npc_index >= _npc_states.size():
		return
	var state := _npc_states[_ruler_npc_index]
	var identity := state.get("identity", {}) as Dictionary
	if identity.is_empty():
		return
	var old_name := String(identity.get("name", ""))
	var ruler_name := String(_ruler_record.get("ruler_name", ""))
	var ruler_title := String(_ruler_record.get("ruler_title", "Thane"))
	## A citizen already wearing the royal name steps aside first.
	for other_index: int in range(_npc_states.size()):
		if other_index == _ruler_npc_index:
			continue
		var other_identity := _npc_states[other_index].get("identity", {}) as Dictionary
		if String(other_identity.get("name", "")) != ruler_name:
			continue
		var stepped_aside_name := "%s the Younger" % ruler_name
		_repair_kin_references(String(other_identity.get("name", "")), stepped_aside_name)
		other_identity["name"] = stepped_aside_name
		_npc_states[other_index]["npc_name"] = stepped_aside_name
	identity["name"] = ruler_name
	identity["first_name"] = ruler_name.get_slice(" ", 0)
	identity["clan"] = ruler_name.get_slice(" ", 1)
	identity["race"] = "Dwarf"
	identity["profession"] = ruler_title
	identity["gender"] = String(_ruler_record.get("ruler_gender", ""))
	## Rulers are elders: the reign must fit inside one dwarven life.
	var since := int(_ruler_record.get("ruler_since", _calendar_start_year))
	var reign_years := maxi(0, _calendar_start_year - since)
	identity["age"] = clampi(maxi(int(identity.get("age", 120)), reign_years + 60), 60, 320)
	state["npc_name"] = ruler_name
	state["ruler_title"] = ruler_title
	state["ruler_since"] = since
	state["ruler_lineage"] = (_ruler_record.get("lineage", []) as Array).duplicate(true)
	state["ruler_family"] = (_ruler_record.get("family", {}) as Dictionary).duplicate(true)
	state["ruler_hold_name"] = _hold_name
	if not old_name.is_empty() and old_name != ruler_name:
		_repair_kin_references(old_name, ruler_name)
	## The dynasty graph is authoritative for royal kin names: the roster
	## spouse and children the family pass minted are renamed to match.
	_reconcile_kin_with_family(state, identity)
	state["ruler_kin"] = _ruler_kin_payload(identity)
	print("[%s] ruler: %s %s seated (lineage %d, family %d)" % [
		name, ruler_title, ruler_name, (state.get("ruler_lineage", []) as Array).size(),
		((state.get("ruler_family", {}) as Dictionary).get("people", {}) as Dictionary).size()])

## Spouse/parents/children references are by name; a rename walks the
## whole roster so no link dangles on the old one.
func _repair_kin_references(old_name: String, new_name: String) -> void:
	if old_name.is_empty() or old_name == new_name:
		return
	for other_variant: Variant in _npc_states:
		var other := other_variant as Dictionary
		var other_identity := other.get("identity", {}) as Dictionary
		if other_identity.is_empty():
			continue
		if String(other_identity.get("spouse", "")) == old_name:
			other_identity["spouse"] = new_name
		_rename_in_kin_list(other_identity, "parents", old_name, new_name)
		_rename_in_kin_list(other_identity, "children", old_name, new_name)

func _rename_in_kin_list(identity: Dictionary, list_key: String, old_name: String, new_name: String) -> void:
	var entries_variant: Variant = identity.get(list_key)
	if not (entries_variant is Array):
		return
	var entries := entries_variant as Array
	for entry_index: int in range(entries.size()):
		if String(entries[entry_index]) == old_name:
			entries[entry_index] = new_name

## The roster's royal family renamed onto the dynasty graph: the ruler's
## roster spouse takes the graph consort's name (and age), roster
## children pair up with the graph's children of the sitting ruler by
## birth order, and any roster child beyond the graph's brood is quietly
## detached from the royal couple. Renames run through a two-phase
## placeholder pass so swapped names never collide mid-walk.
func _reconcile_kin_with_family(state: Dictionary, identity: Dictionary) -> void:
	var family := state.get("ruler_family", {}) as Dictionary
	var people := family.get("people", {}) as Dictionary
	var sitting_id := String(family.get("sitting", ""))
	if people.is_empty() or not people.has(sitting_id):
		return
	var sitting := people[sitting_id] as Dictionary
	var renames: Array[Dictionary] = []
	## The consort.
	var spouse_id := String(sitting.get("spouse", ""))
	var roster_spouse := String(identity.get("spouse", ""))
	if not roster_spouse.is_empty() and people.has(spouse_id):
		var graph_spouse := people[spouse_id] as Dictionary
		var spouse_age := clampi(_calendar_start_year - int(graph_spouse.get("birth", 0)), 60, 320)
		renames.append({"old": roster_spouse, "new": String(graph_spouse.get("name", "")), "age": spouse_age})
	## The children, graph brood sorted by birth.
	var graph_children: Array[Dictionary] = []
	for child_variant: Variant in (sitting.get("children", []) as Array):
		var child_id := String(child_variant)
		if people.has(child_id):
			graph_children.append(people[child_id] as Dictionary)
	graph_children.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left.get("birth", 0)) != int(right.get("birth", 0)):
			return int(left.get("birth", 0)) < int(right.get("birth", 0))
		return String(left.get("id", "")) < String(right.get("id", ""))
	)
	var roster_children: Array[String] = []
	for child_name_variant: Variant in (identity.get("children", []) as Array):
		roster_children.append(String(child_name_variant))
	for child_index: int in range(roster_children.size()):
		if child_index < graph_children.size():
			var graph_child := graph_children[child_index]
			var child_age := clampi(_calendar_start_year - int(graph_child.get("birth", 0)), 6, 49)
			renames.append({"old": roster_children[child_index], "new": String(graph_child.get("name", "")), "age": child_age})
		else:
			_detach_roster_child(roster_children[child_index], identity)
	## Phase 1: park every renamed kin on a placeholder so a swap between
	## two royal names cannot dangle; phase 2: land the graph names.
	for rename_index: int in range(renames.size()):
		var rename := renames[rename_index]
		if String(rename.get("old", "")) == String(rename.get("new", "")):
			continue
		_rename_roster_npc(String(rename.get("old", "")), "«royal kin %d»" % rename_index, -1)
	for rename_index: int in range(renames.size()):
		var rename := renames[rename_index]
		if String(rename.get("old", "")) == String(rename.get("new", "")):
			continue
		_rename_roster_npc("«royal kin %d»" % rename_index, String(rename.get("new", "")), int(rename.get("age", -1)))

## Renames one roster NPC (identity + npc_name + everyone's kin lists);
## a citizen already wearing the new name steps aside as "the Younger".
func _rename_roster_npc(old_name: String, new_name: String, new_age: int) -> void:
	if old_name.is_empty() or new_name.is_empty() or old_name == new_name:
		return
	var target_state: Dictionary = {}
	for state_variant: Variant in _npc_states:
		var candidate := state_variant as Dictionary
		if String(candidate.get("npc_name", "")) == old_name:
			target_state = candidate
			break
	if target_state.is_empty():
		return
	for state_variant: Variant in _npc_states:
		var other := state_variant as Dictionary
		if other == target_state or String(other.get("npc_name", "")) != new_name:
			continue
		var other_identity := other.get("identity", {}) as Dictionary
		var stepped_aside := "%s the Younger" % new_name
		_repair_kin_references(new_name, stepped_aside)
		other_identity["name"] = stepped_aside
		other["npc_name"] = stepped_aside
	var identity := target_state.get("identity", {}) as Dictionary
	identity["name"] = new_name
	identity["first_name"] = new_name.get_slice(" ", 0)
	if new_name.contains(" ") and not new_name.begins_with("«"):
		identity["clan"] = new_name.get_slice(" ", 1)
	if new_age > 0:
		identity["age"] = new_age
	target_state["npc_name"] = new_name
	_repair_kin_references(old_name, new_name)

## Every living soul on the dynasty tree walks the hold: each surviving
## graph person takes over a generic roster dwarf (name, gender, age and
## kin links), so the ruler's whole living family exists in the flesh.
## The consort and children were already claimed by
## _reconcile_kin_with_family; this covers siblings, cousins, aunts and
## any long-lived elders. Runs right after _apply_ruler_identity.
func _materialize_dynasty_kin() -> void:
	if _ruler_npc_index < 0 or _ruler_npc_index >= _npc_states.size():
		return
	var ruler_state := _npc_states[_ruler_npc_index]
	var family := ruler_state.get("ruler_family", {}) as Dictionary
	var people := family.get("people", {}) as Dictionary
	var sitting_id := String(family.get("sitting", ""))
	if people.is_empty() or sitting_id.is_empty():
		return
	ruler_state["dynasty_person_id"] = sitting_id
	var state_by_name: Dictionary = {}
	for state_variant: Variant in _npc_states:
		state_by_name[String((state_variant as Dictionary).get("npc_name", ""))] = state_variant
	## Roster dwarves that can be taken over: not the ruler, not anyone
	## already wearing a dynasty name; the kinless first, so takeovers
	## sever as few roster marriages as possible.
	var dynasty_names: Dictionary = {}
	for person_variant: Variant in people.values():
		dynasty_names[String((person_variant as Dictionary).get("name", ""))] = true
	var candidates: Array[int] = []
	for npc_index: int in range(_npc_states.size()):
		if npc_index == _ruler_npc_index:
			continue
		var state := _npc_states[npc_index]
		if dynasty_names.has(String(state.get("npc_name", ""))):
			continue
		candidates.append(npc_index)
	candidates.sort_custom(func(left: int, right: int) -> bool:
		return _roster_kin_weight(_npc_states[left]) < _roster_kin_weight(_npc_states[right]))
	## Half the roster stays ordinary folk no matter how wide the tree.
	var takeover_budget := mini(candidates.size(), _npc_states.size() / 2)
	var cursor := 0
	var materialized := 0
	for person_id_variant: Variant in (family.get("order", []) as Array):
		var person_id := String(person_id_variant)
		if person_id == sitting_id:
			continue
		var person := people.get(person_id, {}) as Dictionary
		if person.is_empty() or int(person.get("death", 0)) > 0:
			continue
		var person_name := String(person.get("name", ""))
		if person_name.is_empty():
			continue
		var graph_year := int(family.get("year", _calendar_start_year))
		var person_age := clampi(graph_year - int(person.get("birth", graph_year - 100)), 16, 320)
		## Already walking under this name (the consort and children the
		## reconcile pass renamed): tag them so their card shows the
		## dynasty tree centered on themselves.
		if state_by_name.has(person_name):
			var existing := state_by_name[person_name] as Dictionary
			existing["dynasty_person_id"] = person_id
			existing["ruler_family"] = family
			_apply_graph_kin_names(existing.get("identity", {}) as Dictionary, people, person)
			continue
		if cursor >= candidates.size() or materialized >= takeover_budget:
			break
		var state := _npc_states[candidates[cursor]]
		cursor += 1
		materialized += 1
		var identity := state.get("identity", {}) as Dictionary
		var old_name := String(identity.get("name", ""))
		_detach_roster_kin(old_name)
		identity["name"] = person_name
		identity["first_name"] = person_name.get_slice(" ", 0)
		identity["clan"] = person_name.get_slice(" ", 1) if person_name.contains(" ") else String(person.get("clan", ""))
		identity["gender"] = String(person.get("gender", ""))
		identity["race"] = String(person.get("race", "Dwarf"))
		identity["age"] = person_age
		_apply_graph_kin_names(identity, people, person)
		state["npc_name"] = person_name
		state["dynasty_person_id"] = person_id
		state["ruler_family"] = family
		state_by_name[person_name] = state
	print("[%s] dynasty kin: %d living members walking the hold" % [name, materialized])

## How entangled a roster dwarf is; the least entangled are the first
## picked when the dynasty needs bodies.
func _roster_kin_weight(state: Dictionary) -> int:
	var identity := state.get("identity", {}) as Dictionary
	var weight := 0
	if not String(identity.get("spouse", "")).is_empty():
		weight += 2
	weight += (identity.get("children", []) as Array).size()
	weight += (identity.get("parents", []) as Array).size()
	if not String(state.get("staffed_profession", "")).is_empty():
		weight += 1
	return weight

## Rewrites an identity's kin links to the dynasty graph's names, so the
## detail lines and roster references match the family tree exactly.
func _apply_graph_kin_names(identity: Dictionary, people: Dictionary, person: Dictionary) -> void:
	if identity.is_empty():
		return
	var spouse_id := String(person.get("spouse", ""))
	identity["spouse"] = String((people.get(spouse_id, {}) as Dictionary).get("name", "")) if people.has(spouse_id) else ""
	var parent_names: Array = []
	for parent_variant: Variant in (person.get("parents", []) as Array):
		var parent := people.get(String(parent_variant), {}) as Dictionary
		if not parent.is_empty():
			parent_names.append(String(parent.get("name", "")))
	identity["parents"] = parent_names
	var child_names: Array = []
	for child_variant: Variant in (person.get("children", []) as Array):
		var child := people.get(String(child_variant), {}) as Dictionary
		if not child.is_empty():
			child_names.append(String(child.get("name", "")))
	identity["children"] = child_names

## Severs a renamed-away dwarf's old roster marriage and kin references,
## so nobody claims a spouse who no longer exists under that name.
func _detach_roster_kin(old_name: String) -> void:
	if old_name.is_empty():
		return
	for state_variant: Variant in _npc_states:
		var other := state_variant as Dictionary
		var other_identity := other.get("identity", {}) as Dictionary
		if other_identity.is_empty():
			continue
		if String(other_identity.get("spouse", "")) == old_name:
			other_identity["spouse"] = ""
		_remove_from_kin_list(other_identity, "parents", old_name)
		_remove_from_kin_list(other_identity, "children", old_name)

func _remove_from_kin_list(identity: Dictionary, list_key: String, kin_name: String) -> void:
	var entries_variant: Variant = identity.get(list_key)
	if not (entries_variant is Array):
		return
	var entries := entries_variant as Array
	for entry_index: int in range(entries.size() - 1, -1, -1):
		if String(entries[entry_index]) == kin_name:
			entries.remove_at(entry_index)

## Unlinks one roster child from the royal couple when the dynasty graph
## records fewer children than the family pass placed under their roof.
func _detach_roster_child(child_name: String, ruler_identity: Dictionary) -> void:
	if child_name.is_empty():
		return
	var ruler_name := String(ruler_identity.get("name", ""))
	var ruler_children := ruler_identity.get("children", []) as Array
	ruler_children.erase(child_name)
	var spouse_name := String(ruler_identity.get("spouse", ""))
	for state_variant: Variant in _npc_states:
		var other := state_variant as Dictionary
		var other_identity := other.get("identity", {}) as Dictionary
		var other_name := String(other_identity.get("name", ""))
		if other_name == spouse_name:
			(other_identity.get("children", []) as Array).erase(child_name)
		elif other_name == child_name:
			var child_parents := other_identity.get("parents", []) as Array
			child_parents.erase(ruler_name)
			child_parents.erase(spouse_name)

## The ruler's living kin as portrait-ready stubs (name/clan/age/race),
## looked up from the roster for the dynasty tree's spouse+children row.
func _ruler_kin_payload(identity: Dictionary) -> Dictionary:
	var payload := {"spouse": {}, "children": []}
	var spouse_name := String(identity.get("spouse", ""))
	var child_names: Array[String] = []
	for child_variant: Variant in (identity.get("children", []) as Array):
		child_names.append(String(child_variant))
	for other_variant: Variant in _npc_states:
		var other := other_variant as Dictionary
		var other_identity := other.get("identity", {}) as Dictionary
		var other_name := String(other_identity.get("name", ""))
		if other_name.is_empty():
			continue
		var stub := {
			"name": other_name,
			"clan": String(other_identity.get("clan", "")),
			"age": int(other_identity.get("age", 100)),
			"race": String(other_identity.get("race", "Dwarf"))
		}
		if other_name == spouse_name and not spouse_name.is_empty():
			payload["spouse"] = stub
		elif child_names.has(other_name):
			(payload["children"] as Array).append(stub)
	return payload

## What the sitting ruler says: their hold, their line, their grudges.
func _ruler_dialogue_line(state: Dictionary) -> String:
	var hold_label := _hold_name if not _hold_name.is_empty() else "this hold"
	var throne_title := String(state.get("ruler_title", "Thane"))
	var since := int(state.get("ruler_since", _calendar_start_year))
	var pool: Array[String] = [
		"I am %s of %s. Speak plainly; the stone listens." % [throne_title, hold_label],
		"Every gate and gallery of %s answers to this seat. Keep its peace." % hold_label,
		"I have ruled %s since the year %d — %s. It has cost me more than gold." % [hold_label, since, GameCalendar.year_title(since)]
	]
	var lineage := state.get("ruler_lineage", []) as Array
	if lineage.size() > 1:
		var predecessor := lineage[lineage.size() - 2] as Dictionary
		pool.append("Before me, %s %s held this seat. I mean to be remembered longer." % [
			String(predecessor.get("title", "")), String(predecessor.get("name", ""))])
		var line_founder := lineage[0] as Dictionary
		pool.append("My line runs back to %s %s, year %d. %d rulers, one mountain." % [
			String(line_founder.get("title", "")), String(line_founder.get("name", "")),
			int(line_founder.get("start", 1)), lineage.size()])
	for member_variant: Variant in lineage:
		if bool((member_variant as Dictionary).get("violent_end", false)):
			pool.append("The seat of %s has been taken in blood before. Not while I draw breath." % hold_label)
			break
	for goal: String in WorldChronicleService.history_agenda_goals(_world_settings_snapshot(), _hold_name):
		pool.append("While I rule, this hold does not forget: %s." % goal)
	return pool[_rng.randi_range(0, pool.size() - 1)]

func _assign_settlement_factions() -> void:
	_faction_event_stamps.clear()
	var building_cells_by_type: Dictionary = {}
	for building_cell_variant: Variant in _latest_civic_building_type_map.keys():
		var building_type := String(_latest_civic_building_type_map[building_cell_variant])
		if not building_cells_by_type.has(building_type):
			building_cells_by_type[building_type] = []
		(building_cells_by_type[building_type] as Array).append(building_cell_variant)
	_settlement_factions = SettlementFactionService.generate_factions(
		"dwarf", _hold_state.selected_hold_population, building_cells_by_type, _rng, _journey_guilds
	)
	## Chronicle grudges (a neighbor hold that fell, a beast still below)
	## redirect one lodge's agenda toward the hold's real history.
	SettlementFactionService.apply_history_agenda(
		_settlement_factions,
		WorldChronicleService.history_agenda_goals(_world_settings_snapshot(), _hold_name),
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
	var role_title := _npc_role_title(state)
	if not state.has("identity"):
		state["identity"] = NpcIdentityService.generate(_rng, role_title, "dwarf")
		state["npc_name"] = String((state["identity"] as Dictionary).get("name", "A dwarf"))
	var identity := state.get("identity", {}) as Dictionary
	# Sworn members talk about their faction, others gossip about the
	# guilds, and everyone still has personal news and map rumors.
	var line: String
	var faction_roll := _rng.randf()
	if bool(state.get("is_ruler", false)):
		# The seat speaks for itself: hold, lineage, and old grudges.
		line = _ruler_dialogue_line(state)
	elif int(state.get("role", 0)) == ROLE_GOLDSMITH and _rng.randf() < 0.4:
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
		# History runs deepest — chronicle rumors recall the recorded past.
		var rumor := ""
		if _rng.randf() < 0.35:
			rumor = WorldChronicleService.history_rumor(_world_settings_snapshot(), _hold_name, _rng)
		if rumor.is_empty() and _rng.randf() < 0.4:
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
			## The new wall must block light like dug walls admit it:
			## refresh the occlusion texture (mirrors _dig_cell).
			_refresh_occlusion_cell(cell)
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
	# Below the darkness quad (13): the bobber belongs to the world, not
	# the light pass.
	bobber.z_index = 12
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
	if not _hold_state.has_levels():
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

## --- The named beast's lair ----------------------------------------------
## When the chronicle laired a still-living beast in this hold, its boss
## waits on the DEEPEST level: an existing creature def grown and tinted
## into the named beast, run by the same AI pipeline with boss stats.

func _maybe_spawn_lair_boss() -> void:
	if _lair_beast.is_empty() or not _hold_state.has_levels():
		return
	if not _hold_state.is_deepest():
		return
	## Re-check the register: the beast may have died this very visit.
	if WorldChronicleService.is_beast_slain(_world_settings_snapshot(), String(_lair_beast.get("name", ""))):
		_lair_beast = {}
		return
	for state: Dictionary in _creature_states:
		if bool(state.get("boss", false)):
			return
	var hall_cells: Array[Vector2i] = []
	for cell_variant: Variant in _latest_grid.keys():
		if int(_latest_grid[cell_variant]) == CELL_HALL:
			hall_cells.append(cell_variant as Vector2i)
	if hall_cells.is_empty():
		return
	## The beast holds the far end of the level: the hall cell farthest
	## from wherever the player came in.
	var boss_cell := hall_cells[0]
	var best_distance := -1.0
	for cell: Vector2i in hall_cells:
		var distance := Vector2(cell - _player_cell).length()
		if distance > best_distance:
			best_distance = distance
			boss_cell = cell
	_spawn_lair_boss_at(boss_cell)

func _spawn_lair_boss_at(cell: Vector2i) -> void:
	var spec: Dictionary = UndergroundCreatureService.boss_spec_for_kind(String(_lair_beast.get("kind", "dragon")))
	var def_index := int(spec.get("def_index", 7))
	if def_index < 0 or def_index >= UndergroundCreatureService.CREATURE_DEFS.size():
		return
	var def: Dictionary = UndergroundCreatureService.CREATURE_DEFS[def_index]
	var display := String(_lair_beast.get("display", "a nameless beast"))
	var sprite: Sprite2D = UndergroundCreatureService.create_creature_sprite(_creature_texture, int(def.get("slot", 0)), tile_size)
	UndergroundCreatureService.apply_boss_visuals(sprite, spec, WorldChronicleService._capitalize_first(display))
	sprite.position = _cell_center_position(cell)
	# Below the darkness quad (13): even the lair boss hides in the dark
	# until a light reveals it.
	sprite.z_index = 12
	actor_layer.add_child(sprite)
	_creature_states.append({
		"def_index": def_index,
		"hp": int(spec.get("max_hp", 200)),
		"cell": cell,
		"sprite": sprite,
		"moving": false,
		"dying": false,
		"anim": "idle",
		"wander_timer": _rng.randf_range(0.5, 2.0),
		"attack_timer": 0.0,
		"anim_time": _rng.randf_range(0.0, 1.0),
		"facing_dir": Vector2i(0, 1),
		"boss": true,
		"beast_name": String(_lair_beast.get("name", "")),
		"beast_display": display,
		"beast_kind": String(_lair_beast.get("kind", "dragon")),
		"damage_override": int(spec.get("damage", 8)),
		"aggro_override": int(spec.get("aggro_range", 12)),
		"cooldown_override": float(spec.get("attack_cooldown", 1.5)),
		"speed_override": float(spec.get("speed", 80.0))
	})
	_set_save_status("The deep stirs — %s nests here." % display, Color(1.0, 0.55, 0.45, 1.0))

## Big coins, the beast's unique trophy, and a world that remembers: the
## kill is written to the persistent register and the stored chronicle,
## so rumors flip, the World Chronicle updates, and the beast never
## respawns — here or anywhere.
func _award_lair_boss_kill(state: Dictionary) -> void:
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
	var place := _hold_name if not _hold_name.is_empty() else "a fallen hold"
	var kill_year := GameCalendar.year_for_day(_game_day - 1, _calendar_start_year)
	var settings: Dictionary = _world_settings_snapshot()
	WorldChronicleService.record_player_beast_kill(settings, String(state.get("beast_name", "")), player_name, place, kill_year)
	_store_world_settings(settings)
	_lair_beast = {}
	var sprite := state.get("sprite") as Sprite2D
	if sprite != null:
		_spawn_floating_text("+%d coins" % coins, sprite.position, Color(0.95, 0.8, 0.4, 1.0))
	_set_save_status(
		"%s is slain! You claim %s and %d coins — the world will remember this." % [
			WorldChronicleService._capitalize_first(String(state.get("beast_display", "the beast"))), trophy, coins
		],
		Color(1.0, 0.85, 0.45, 1.0)
	)

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
		# The named beast guards its lair from wherever the player enters;
		# only ordinary prowlers vanish with distance.
		if player_distance > CREATURE_DESPAWN_DISTANCE and not bool(state.get("boss", false)):
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
			sprite.position = sprite.position.move_toward(target, float(state.get("speed_override", float(def.get("speed", 60.0)))) * delta)
			if sprite.position.distance_to(target) <= 0.5:
				sprite.position = target
				state["cell"] = state.get("move_cell", cell) as Vector2i
				state["moving"] = false
		elif player_distance <= 1 and _player_sprite != null and _player_control_enabled:
			state["facing_dir"] = _direction_between_cells(cell, _player_cell)
			if float(state.get("attack_timer", 0.0)) <= 0.0:
				state["attack_timer"] = float(state.get("cooldown_override", float(def.get("attack_cooldown", 1.3))))
				_set_creature_anim(state, "attack")
				var source_name := String(state.get("beast_display", def.get("name", "creature")))
				_damage_player(int(state.get("damage_override", int(def.get("damage", 1)))), source_name)
		else:
			var step := Vector2i.ZERO
			if player_distance <= int(state.get("aggro_override", int(def.get("aggro_range", 6)))) and not _latest_district_cell_map.has(_player_cell):
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
	# A named beast's fall echoes further: trophy, hoard, and history.
	if bool(state.get("boss", false)):
		_award_lair_boss_kill(state)

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

## Death is final: no waking back in the Great Hall. Half the purse spills
## where the walker fell (the drop stays with the world), the grave goes
## into the chronicle, and the game-over screen takes over.
func _handle_player_death(source_name: String) -> void:
	if _game_over != null and is_instance_valid(_game_over):
		return
	_player_hp = 0.0
	var lost_coins := _player_coins / 2
	if lost_coins > 0:
		_adjust_coins(-lost_coins)
		if _player_sprite != null:
			_spawn_floating_text("-%d coins" % lost_coins, _player_sprite.position, Color(0.95, 0.8, 0.4, 1.0))
	_save_player_inventory()
	_update_hp_label()
	_player_move_path.clear()
	_player_is_moving = false
	var place := _hold_name if not _hold_name.is_empty() else "a dwarfhold"
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
			# Death is final now: no satiety refill for a respawn that
			# no longer happens.
			_handle_player_death("starvation")
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
	_refresh_held_item()
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
		## Erasing decor on a cell must retire any earlier build there:
		## replay runs decor_edits then decor_erased, so a stale edit
		## would otherwise rebuild furniture the player harvested.
		if field == "decor_erased" and level.get("decor_edits") is Dictionary:
			(level["decor_edits"] as Dictionary).erase(key)
	else:
		var edits: Dictionary = level.get(field, {}) as Dictionary
		edits[key] = value
		level[field] = edits
		## Building decor on a previously-harvested cell must drop the
		## erase marker, or replay deletes the new furniture right after
		## placing it (decor_erased runs last).
		if field == "decor_edits" and level.get("decor_erased") is Array:
			(level["decor_erased"] as Array).erase(key)
	hold[level_key] = level
	diffs[hold_key] = hold
	settings["hold_diffs"] = diffs
	game_session.call("set_world_settings", settings)

## Digging through a player-built wall must also drop its "grid_edits"
## entry: replay order is dug first, then grid_edits, so a stale wall
## edit would resurrect the wall over the freshly dug hall.
func _erase_hold_grid_edit(cell: Vector2i) -> void:
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
	var grid_edits: Dictionary = level.get("grid_edits", {}) as Dictionary
	if not grid_edits.has(_cell_key(cell)):
		return
	grid_edits.erase(_cell_key(cell))
	level["grid_edits"] = grid_edits
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
	# Rails come back as the laid network; carts come back wherever they
	# last came to rest (cart_at retires old cells with a false).
	if not level_data.has("rails"):
		level_data["rails"] = []
	var rails := level_data["rails"] as Array
	for key_variant: Variant in (diff.get("rails", []) as Array):
		var cell := _parse_cell_key(String(key_variant))
		if not rails.has(cell):
			rails.append(cell)
	if not level_data.has("carts"):
		level_data["carts"] = []
	var carts := level_data["carts"] as Array
	var cart_edits := diff.get("cart_at", {}) as Dictionary
	for key_variant: Variant in cart_edits.keys():
		var cell := _parse_cell_key(String(key_variant))
		if bool(cart_edits[key_variant]):
			if not carts.has(cell):
				carts.append(cell)
		else:
			carts.erase(cell)
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
	## Player-built furniture must survive chunk eviction + re-stream too,
	## mirroring _apply_hold_diffs_to_level; without this, wild-chunk decor
	## vanishes the first time its chunk is evicted and streamed back in.
	var decor_edits := diff.get("decor_edits", {}) as Dictionary
	for key_variant: Variant in decor_edits.keys():
		var cell := _parse_cell_key(String(key_variant))
		if rect.has_point(cell):
			var tile_key := String(decor_edits[key_variant])
			_latest_floor_decor[cell] = tile_key
			if tile_key == "chest" and not _chest_inventories.has(cell):
				_chest_inventories[cell] = []
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
	# Once the game-over modal owns the session, the death-moment flush has
	# already run; the dying scene must not smear its zeroed state over a
	# freshly loaded save or a stripped successor session as it exits.
	if _game_over != null and is_instance_valid(_game_over):
		return
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

## Mining damage per rock cell (not persisted: chunk eviction, level
## switches and reloads restore the rock to full durability).
var _rock_damage: Dictionary = {}
var _rock_crack_sprites: Dictionary = {}
var _rock_crack_textures: Array[ImageTexture] = []
## This world's geologic profile (GeologyService), set with the seed.
var _geology: Dictionary = {}
## Geology carried in from the overworld tile the hold stands on; when
## present it overrides the seed-derived profile so the pick finds what
## that mountain's tooltip advertised.
var _journey_geology: Dictionary = {}
## The guild names the overworld tooltip advertises for this hold; the
## scene's open factions adopt them so map and halls agree.
var _journey_guilds: Array[String] = []
## True when the player walked in overland through the mountain mouth
## (vs a map journey or stairs): they spawn at the hold's south gate.
var _overland_arrival := false
## The visit came down the surface city's great-hall stair (stage 4):
## the walker lives in the underhalls and ascends OUT, not to level 0.
var _from_surface_stair := false

## An ore appropriate to the current stratum, drawn from this world's
## metal list - the same list the overworld geology readout advertises.
func _roll_dig_ore(layer_class: String) -> String:
	if _geology.is_empty():
		return ""
	var metals := _geology.get("metals", []) as Array
	if metals.is_empty():
		return ""
	var host_pool := GeologyService.METAL_POOLS.get(layer_class, []) as Array
	var candidates: Array[String] = []
	for metal_variant: Variant in metals:
		var metal := String(metal_variant)
		if host_pool.has(metal):
			candidates.append(metal)
	if candidates.is_empty():
		for metal_variant: Variant in metals:
			candidates.append(String(metal_variant))
	return "%s Ore" % candidates[_rng.randi_range(0, candidates.size() - 1)]

## One pickaxe swing at a rock wall, gated by the shared swing cooldown so
## click spam can't bypass durability. Damage comes from the best digging
## tool carried; the rock breaks when its hit points run out.
func _swing_at_rock(cell: Vector2i) -> void:
	if _player_attack_timer > 0.0:
		return
	_player_attack_timer = PLAYER_ATTACK_COOLDOWN
	var damage := HAND_DIG_DAMAGE
	for tool_name: String in DIG_TOOL_DAMAGE.keys():
		if int(_player_inventory.get(tool_name, 0)) > 0:
			damage = maxi(damage, int(DIG_TOOL_DAMAGE[tool_name]))
	var rock_hp := _rock_durability()
	var total_damage := int(_rock_damage.get(cell, 0)) + damage
	if total_damage >= rock_hp:
		_dig_cell(cell)
		return
	_rock_damage[cell] = total_damage
	_update_rock_crack(cell, float(total_damage) / float(rock_hp))
	# A small chip spray per swing; the full crumble plays on the last hit.
	TileBreakFxService.chip_burst(city_layer, _cell_center_position(cell), Color(0.55, 0.53, 0.5, 1.0), 5)

## Rock durability follows the level's geologic layer: soft sedimentary
## strata dig faster than deep granite country.
func _rock_durability() -> int:
	if _geology.is_empty():
		return ROCK_DURABILITY_HP
	var layer := GeologyService.layer_class_for_depth(_geology, _hold_state.current_level_index)
	return int(GeologyService.LAYER_DURABILITY.get(layer, ROCK_DURABILITY_HP))

## The named stratum this level is dug through, stable per level.
func _level_stone_name() -> String:
	if _geology.is_empty():
		return "Stone"
	var layer := GeologyService.layer_class_for_depth(_geology, _hold_state.current_level_index)
	if layer == String(_geology.get("layer_class", "")):
		var surface_stones := _geology.get("stones", []) as Array
		if not surface_stones.is_empty():
			return String(surface_stones[0])
	var stones := GeologyService.LAYER_STONES.get(layer, []) as Array
	if stones.is_empty():
		return "Stone"
	return String(stones[absi(_world_seed_hash + _hold_state.current_level_index * 31) % stones.size()])

## Crack overlay stages drawn over the damaged wall tile.
func _update_rock_crack(cell: Vector2i, damage_ratio: float) -> void:
	_ensure_rock_crack_textures()
	if _rock_crack_textures.is_empty():
		return
	var stage := clampi(int(damage_ratio * float(_rock_crack_textures.size())), 0, _rock_crack_textures.size() - 1)
	var sprite := _rock_crack_sprites.get(cell) as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = true
		sprite.position = _cell_center_position(cell)
		sprite.z_index = 2
		city_layer.add_child(sprite)
		_rock_crack_sprites[cell] = sprite
	sprite.texture = _rock_crack_textures[stage]

func _clear_rock_crack(cell: Vector2i) -> void:
	var sprite := _rock_crack_sprites.get(cell) as Sprite2D
	if sprite != null:
		sprite.queue_free()
	_rock_crack_sprites.erase(cell)
	_rock_damage.erase(cell)

func _clear_all_rock_damage() -> void:
	for cell_variant: Variant in _rock_crack_sprites.keys():
		var sprite := _rock_crack_sprites.get(cell_variant) as Sprite2D
		if sprite != null:
			sprite.queue_free()
	_rock_crack_sprites.clear()
	_rock_damage.clear()

## Three crack stages generated once: dark polyline fissures that spread
## and darken as the rock takes damage.
func _ensure_rock_crack_textures() -> void:
	if not _rock_crack_textures.is_empty():
		return
	var crack_rng := RandomNumberGenerator.new()
	crack_rng.seed = 0xC7AC4
	for stage in range(3):
		var image := Image.create(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
		var crack_color := Color(0.07, 0.06, 0.05, 0.58 + float(stage) * 0.14)
		for _crack_index in range(2 + stage * 2):
			var pos := Vector2(
				crack_rng.randf_range(5.0, float(tile_size.x) - 5.0),
				crack_rng.randf_range(5.0, float(tile_size.y) - 5.0)
			)
			var direction := Vector2.RIGHT.rotated(crack_rng.randf_range(0.0, TAU))
			for _step in range(crack_rng.randi_range(7, 13)):
				var px := Vector2i(int(pos.x), int(pos.y))
				if px.x >= 0 and px.y >= 0 and px.x < tile_size.x and px.y < tile_size.y:
					image.set_pixelv(px, crack_color)
					if px.x + 1 < tile_size.x:
						image.set_pixel(px.x + 1, px.y, crack_color)
				direction = direction.rotated(crack_rng.randf_range(-0.55, 0.55))
				pos += direction
		_rock_crack_textures.append(ImageTexture.create_from_image(image))

func _dig_cell(cell: Vector2i) -> void:
	# The rock is spent: clear its damage bookkeeping and crack overlay.
	_clear_rock_crack(cell)
	# Grab the wall art before it is re-rendered as open floor, so the break
	# FX can crumble a ghost of the rock away.
	var art := TileBreakFxService.tile_art(city_layer, cell)
	_latest_grid[cell] = CELL_HALL
	_dug_cells[cell] = true
	## If this wall was player-built, retire its grid edit so replay
	## (dug first, then grid_edits) can't bring the wall back.
	_erase_hold_grid_edit(cell)
	_record_hold_edit("dug", cell)
	_add_to_inventory("Stone", 1)
	var layer_class := ""
	if not _geology.is_empty():
		layer_class = GeologyService.layer_class_for_depth(_geology, _hold_state.current_level_index)
	# Fossils only survive in sedimentary strata; elsewhere the pick can
	# strike ore from this world's veins or a coal seam instead.
	if layer_class == GeologyService.LAYER_SEDIMENTARY and _rng.randi_range(1, 100) <= DIG_FOSSIL_CHANCE_PERCENT:
		var fossil: String = DIG_FOSSIL_FINDS[_rng.randi_range(0, DIG_FOSSIL_FINDS.size() - 1)]
		_add_to_inventory(fossil, 1)
		if _player_sprite != null:
			_spawn_floating_text("Found %s!" % fossil, _player_sprite.position, Color(0.95, 0.9, 0.6, 1.0))
	elif layer_class == GeologyService.LAYER_SEDIMENTARY and bool(_geology.get("coal", false)) and _rng.randi_range(1, 100) <= DIG_COAL_CHANCE_PERCENT:
		_add_to_inventory("Coal", 1)
		if _player_sprite != null:
			_spawn_floating_text("Struck a coal seam!", _player_sprite.position, Color(0.75, 0.72, 0.68, 1.0))
	elif _rng.randi_range(1, 100) <= DIG_ORE_CHANCE_PERCENT:
		var ore := _roll_dig_ore(layer_class)
		if not ore.is_empty():
			_add_to_inventory(ore, 1)
			if _player_sprite != null:
				_spawn_floating_text("Struck %s!" % ore, _player_sprite.position, Color(0.95, 0.85, 0.5, 1.0))
	_render_world_rect(Rect2i(cell - Vector2i(1, 1), Vector2i(3, 3)))
	# The rock is now open hall; open the light through the fresh gap.
	_refresh_occlusion_cell(cell)
	var dig_position := _cell_center_position(cell)
	var dig_lean := 1.0 if _player_sprite == null or dig_position.x >= _player_sprite.position.x else -1.0
	if not art.is_empty():
		TileBreakFxService.topple_ghost(city_layer, dig_position, art["texture"] as Texture2D, art["region"] as Rect2, dig_lean)
	TileBreakFxService.chip_burst(city_layer, dig_position, Color(0.55, 0.53, 0.5, 1.0), 12)

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
	var role_title := _npc_role_title(npc_state)
	if not npc_state.has("identity"):
		npc_state["identity"] = NpcIdentityService.generate(_rng, role_title, "dwarf")
		npc_state["npc_name"] = String((npc_state["identity"] as Dictionary).get("name", "A dwarf"))
	_npc_inspection_card.open(npc_state, role_title, hash(seed_input.text.strip_edges()), _calendar_start_year)

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
	# Click-to-walk stays parked while riding a cart; the keys steer.
	if _cart_riding:
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
		_swing_at_rock(target_cell)
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
	if not _hold_state.has_current():
		return false

	var stair_direction := _stair_direction_at_cell(_player_cell)
	if stair_direction == "down" and _hold_state.current_level_index < _hold_state.generated_levels.size() - 1:
		var destination_index := _hold_state.current_level_index + 1
		_pending_player_spawn_cell = _resolve_stair_spawn_cell(destination_index, "up", _player_cell)
		_show_level(destination_index)
		return true
	if stair_direction == "up" and _hold_state.current_level_index > 0:
		var destination_index := _hold_state.current_level_index - 1
		# Stage 4: from the first underhall the way up IS the surface -
		# the great hall above belongs to the town scene, and the old
		# level-0 city never shows on a surface-stair visit.
		if _from_surface_stair and destination_index == 0:
			_exit_to_surface_city()
			return true
		_pending_player_spawn_cell = _resolve_stair_spawn_cell(destination_index, "down", _player_cell)
		_show_level(destination_index)
		return true
	return false

## Hands the walker back to the surface city. The town scene is almost
## always parked in the scene cache from the descent, so this revives it
## exactly as it was left - standing on the great hall's stair, arrival
## lock armed until they step off.
func _exit_to_surface_city() -> void:
	_set_save_status("You climb back up to the great hall.", Color(0.85, 0.9, 0.7, 1.0))
	SceneCacheService.request_change(self, TOWN_SCENE_PATH)

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
	# Aboard a minecart the keys steer the CART: launch along a rail, or
	# queue the turn taken at the next junction. Walking is suspended.
	if _cart_riding:
		if absi(direction.x) + absi(direction.y) != 1:
			return false
		_cart_desired_dir = direction
		if _cart_dir == Vector2i.ZERO and _rail_cells.has(_cart_cell + direction):
			_cart_dir = direction
			_cart_progress = 0.0
		return true
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
		Callable(self, "_cell_center_position"),
		false, _npc_pois
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
	## CELL_WALL is walkable only where a door tile was punched through the
	## partition; the atlas check below sorts door from stone.
	if zone != CELL_HALL and zone != CELL_HOUSE and zone != CELL_BUILDING and zone != CELL_PLAZA and zone != CELL_WALL:
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
	_light_furnishing_cells.clear()
	_actor_passable_cache.clear()
	if actor_layer == null:
		return
	var is_occupied := func(cell: Vector2i) -> bool:
		return decor_layer.get_cell_source_id(cell) >= 0
	for component_variant: Variant in RoomFurnishingService.collect_zone_components(grid, CELL_HOUSE):
		var component: Array[Vector2i] = []
		for cell_variant: Variant in (component_variant as Array):
			component.append(cell_variant as Vector2i)
		var placements: Array[Dictionary] = RoomFurnishingService.plan_house_furnishing(component, is_occupied, _door_cells, _rng, grid)
		_apply_furnishing_placements(placements)
	for component_variant: Variant in RoomFurnishingService.collect_zone_components(grid, CELL_BUILDING):
		var component: Array[Vector2i] = []
		for cell_variant: Variant in (component_variant as Array):
			component.append(cell_variant as Vector2i)
		if component.is_empty():
			continue
		var building_type := String(_latest_civic_building_type_map.get(component[0], ""))
		var placements: Array[Dictionary] = RoomFurnishingService.plan_shop_dressing(component, building_type, is_occupied, _door_cells, _rng, grid)
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
			_light_furnishing_cells.append(base_cell)
			# Corona only - the shader lights the hearth's actual pool.
			var glow: Sprite2D = RoomFurnishingService.create_glow_sprite(
				_cell_center_position(base_cell),
				0.9 * float(tile_size.x),
				Color(1.0, 0.72, 0.35, 1.0)
			)
			actor_layer.add_child(glow)
			# Candles and hearths breathe like the torches do.
			_attach_glow_pulse(glow, base_cell)
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

## Takes the caller's rng (a per-level seeded one from _render_city) so
## revisits re-deal the exact same decor instead of rerolling loot spots.
func _pick_decor_tile(grid: Dictionary, x: int, y: int, cell: int, base_tile: String, house_decor_overrides: Dictionary, rng: RandomNumberGenerator) -> String:
	## Per-cell seed: the roll for a cell must never depend on how many other
	## cells rolled before it (render bounds grow as wild chunks stream in).
	rng.seed = _world_seed_hash ^ hash("decor|%d|%d|%d" % [_hold_state.current_level_index, x, y])
	return DwarfHoldTileService.pick_decor_tile(grid, x, y, cell, base_tile, house_decor_overrides, _latest_civic_building_type_map, CIVIC_BUILDING_TYPES, rng, _door_cells)


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
	elif not _hold_fall_text.is_empty():
		## Silent ruin: surface the chronicle's fall event on entry.
		var fall_line := _hold_fall_text
		if not _hold_name.is_empty():
			fall_line = "%s — %s" % [_hold_name, _hold_fall_text]
		city_summary.text += "\n%s" % fall_line
	if not building_subtype_summary.is_empty():
		city_summary.text += "\nBuilding Types: %s" % building_subtype_summary

## Whether the decor layer holds the carved wooden sign at this cell —
## the corridor boards by shopfronts and the boards hung inside shops.
func _is_sign_decor_cell(cell: Vector2i) -> bool:
	if decor_layer.get_cell_source_id(cell) < 0:
		return false
	return decor_layer.get_cell_atlas_coords(cell) == (TILE_ATLAS.get("sign", Vector2i(-1000, -1000)) as Vector2i)

## The readable text for a sign cell, or {} when the cell holds no sign.
## A sign inside a shop names that shop; a corridor sign names the civic
## building it stands beside; a board with no business near it carries a
## seeded notice. Deterministic per hold seed and cell.
func _sign_text_for_cell(cell: Vector2i) -> Dictionary:
	if not _is_sign_decor_cell(cell):
		return {}
	var sign_seed_text := seed_input.text.strip_edges()
	var owner_cell := cell
	if not _latest_civic_building_type_map.has(owner_cell):
		for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			if _latest_civic_building_type_map.has(cell + direction):
				owner_cell = cell + direction
				break
	if _latest_civic_building_type_map.has(owner_cell):
		var display_name := String(_latest_civic_building_name_map.get(owner_cell, ""))
		var trade := _building_type_for_cell_or_empty(owner_cell)
		var trade_display := "" if trade.is_empty() else _display_name_for_building_type(trade)
		var sign_text := SignTextService.business_sign_text(display_name, trade_display)
		if not sign_text.is_empty():
			return {"title": display_name if not display_name.is_empty() else "Sign", "text": sign_text}
	return {"title": "Notice", "text": SignTextService.flavor_text(sign_seed_text, cell)}

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
	_update_mining_cursor(hovered_cell)
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
	# A sign under the cursor floats its text above the board instead of
	# the regular tile tooltip (a dwarf standing on it still wins).
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
	# Rock reads as its actual stratum ("Tile: Limestone"), DF-style.
	if zone_name == "Rock" and (tile_name == "Stone" or tile_name == "Stone Face" or tile_name == "Unknown"):
		tile_name = _level_stone_name()
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
	_clear_sign_hover_label()
	tile_hover_tooltip.visible = false
	_hover_tooltip_cell = Vector2i(2147483647, 2147483647)
	_hover_tooltip_layer = null
	_hover_tooltip_npc = ""
	if _mining_cursor != null:
		_mining_cursor.visible = false

## Shows the pick marker over hovered rock the player could swing at
## right now (diggable and adjacent); hides it everywhere else.
func _update_mining_cursor(hovered_cell: Vector2i) -> void:
	if _mining_cursor == null:
		_mining_cursor_texture = _create_mining_cursor_texture()
		_mining_cursor = Sprite2D.new()
		_mining_cursor.texture = _mining_cursor_texture
		_mining_cursor.centered = true
		# Above the darkness mask (13) and torches (14): the target marker
		# must read even on unlit rock.
		_mining_cursor.z_index = 16
		lighting_layer.add_child(_mining_cursor)
	var cursor_visible := _player_sprite != null and _player_control_enabled \
		and _is_diggable_cell(hovered_cell) and _is_player_adjacent_to_cell(hovered_cell)
	_mining_cursor.visible = cursor_visible
	if cursor_visible:
		_mining_cursor.position = _cell_center_position(hovered_cell)

## The Core Keeper-blue pickaxe painted at runtime like the torch art:
## a bright arced head over a wooden haft, nearest-upscaled to stay
## chunky.
func _create_mining_cursor_texture() -> Texture2D:
	var image := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var bright := Color(0.45, 0.74, 0.96, 1.0)
	var deep := Color(0.16, 0.45, 0.85, 1.0)
	for x in range(2, 10):
		image.set_pixel(x, 1, bright)
	for x in range(1, 11):
		image.set_pixel(x, 2, deep)
	image.set_pixel(1, 3, deep)
	image.set_pixel(10, 3, deep)
	image.set_pixel(0, 4, deep)
	image.set_pixel(11, 4, deep)
	for y in range(3, 11):
		image.set_pixel(5, y, Color(0.55, 0.38, 0.22, 1.0))
		image.set_pixel(6, y, Color(0.42, 0.28, 0.16, 1.0))
	image.resize(24, 24, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)

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
