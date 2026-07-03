extends Control

## Above-ground human town interior, entered from the overworld via
## right-click "Begin Journey" on a town tile. Forked from the dwarfhold
## generator: the same zone-grid pipeline (plazas, streets, residences,
## shops with guaranteed doors and connectivity) reinterpreted for the
## surface - grass instead of rock, dirt streets instead of halls, a
## cobbled market square, and timber-walled buildings.

const CELL_ROCK := 0
const CELL_HALL := 1
const CELL_HOUSE := 2
const CELL_BUILDING := 3
const CELL_PLAZA := 4

@export var hall_zone_count_range := Vector2i(14, 22)
@export var housing_zone_count_range := Vector2i(80, 140)
@export var civic_building_zone_count_range := Vector2i(45, 95)
@export var plaza_zone_count_range := Vector2i(6, 14)
@export var tile_size := Vector2i(32, 32)
@export var tilesheet_path := "res://resources/images/town/town_tileset.png"
@export var structure_fallback_max_extra_radius := 240
@export var tavern_vehicle_sprite_path := "res://resources/images/dwarfhold/very_epic_taverner_vehicle.png"
@export var shattered_player_sprite_path := "res://resources/images/shattered_ui/warrior.png"
@export var tavern_npc_count := 5
@export var tavern_npc_speed_range := Vector2(38.0, 62.0)
@export var enable_fog_of_war := false
@export var underground_level_count_range := Vector2i(1, 1)

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
var _latest_bed_count := 0
var _show_zone_overlay := false
var _lighting_enabled := true
var _chest_inventories: Dictionary = {}
var _selected_chest_cell := Vector2i(2147483647, 2147483647)
var _chest_slot_panels: Array[PanelContainer] = []
var _chest_slot_labels: Array[Label] = []
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
var _hold_state := DwarfHoldStateModel.new()
var _town_name := ""
var _town_details: Dictionary = {}
var _pending_player_spawn_cell := Vector2i(2147483647, 2147483647)

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

const ZONE_OVERLAY_COLORS := {
	CELL_HALL: Color(0.27, 0.58, 0.90, 0.35),
	CELL_HOUSE: Color(0.84, 0.72, 0.24, 0.35),
	CELL_BUILDING: Color(0.61, 0.35, 0.88, 0.35),
	CELL_PLAZA: Color(0.18, 0.74, 0.66, 0.35)
}

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

const SHATTERED_VISION_RADIUS := 7
const SHATTERED_UNSEEN_ALPHA := 1.0
const SHATTERED_REVEALED_ALPHA := 0.72
const SHATTERED_VISIBLE_ALPHA := 0.0

const CHEST_SLOT_COLUMNS := 8
const CHEST_SLOT_ROWS := 4
const BACKPACK_SLOT_ROWS := 3


const TOWN_SCENE_SEED_KEY := "town_scene_seed"
const TOWN_SCENE_POPULATION_KEY := "town_scene_population"
const TOWN_SCENE_NAME_KEY := "town_scene_name"

const CHEST_LOOT_TABLE := [
	{"name": "Copper Coins", "min": 4, "max": 18},
	{"name": "Wheel of Cheese", "min": 1, "max": 2},
	{"name": "Bolt of Cloth", "min": 1, "max": 3},
	{"name": "Loaf of Bread", "min": 1, "max": 4},
	{"name": "Jar of Honey", "min": 1, "max": 2},
	{"name": "Iron Horseshoes", "min": 2, "max": 6},
	{"name": "Wax Candles", "min": 2, "max": 8},
	{"name": "Skein of Wool", "min": 1, "max": 5}
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
	_lighting_mask_sprite = Sprite2D.new()
	_lighting_mask_sprite.centered = false
	lighting_layer.add_child(_lighting_mask_sprite)
	fog_of_war.visible = false
	_tavern_character_texture = load(tavern_vehicle_sprite_path) as Texture2D
	if _tavern_character_texture == null:
		_tavern_character_texture = _create_placeholder_tavern_character_texture()
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
	_generate_city()

func _process(delta: float) -> void:
	_update_player_turn_movement(delta)
	_update_player_hold_movement(delta)
	_update_npc_movement(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _is_text_input_focused():
		_on_back_button_pressed()
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
		if not _latest_grid.is_empty():
			_update_shattered_visibility(_latest_grid)
			_refresh_lighting(_latest_grid)

	if _player_move_path.is_empty():
		if _player_pending_chest_interaction.x != 2147483647:
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

func _apply_cached_town_scene_seed() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	var scene_seed := _hold_state.apply_world_settings(settings, TOWN_SCENE_SEED_KEY, TOWN_SCENE_POPULATION_KEY)
	_town_name = String(settings.get(TOWN_SCENE_NAME_KEY, "")).strip_edges()
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
	lighting_layer.visible = _lighting_enabled

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
	_latest_bed_count = 0
	for decor_value: Variant in house_decor_overrides.values():
		var decor_key := String(decor_value)
		if decor_key == "bed" or decor_key == "bed_alt":
			_latest_bed_count += 1
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := _cell_at(grid, x, y)
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
	_initialize_shattered_lighting(grid)
	_refresh_lighting(grid)
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
	_selected_chest_cell = clicked_cell
	_update_chest_inventory_panel()

func _update_chest_inventory_panel() -> void:
	if _selected_chest_cell.x == 2147483647:
		_clear_chest_selection()
		return
	var loot_entries := _chest_inventories.get(_selected_chest_cell, []) as Array
	chest_popup.visible = true
	chest_popup_title.text = "Chest (%d, %d)" % [_selected_chest_cell.x, _selected_chest_cell.y]
	_populate_chest_slots(loot_entries)
	if loot_entries.is_empty():
		chest_popup_status_label.text = "This chest is empty."
		chest_popup_take_all_button.disabled = true
		return
	chest_popup_status_label.text = "Click another chest tile to inspect a different chest."
	chest_popup_take_all_button.disabled = false

func _clear_chest_selection() -> void:
	_selected_chest_cell = Vector2i(2147483647, 2147483647)
	chest_popup_title.text = "Chest"
	chest_popup_status_label.text = "Select a chest tile to view contents"
	chest_popup_take_all_button.disabled = true
	_populate_chest_slots([])
	chest_popup.visible = false

func _on_loot_chest_button_pressed() -> void:
	if _selected_chest_cell.x == 2147483647:
		return
	_chest_inventories[_selected_chest_cell] = []
	_update_chest_inventory_panel()

func _on_chest_popup_close_button_pressed() -> void:
	_clear_chest_selection()

func _initialize_chest_popup_grids() -> void:
	_create_inventory_slots(chest_grid, CHEST_SLOT_COLUMNS * CHEST_SLOT_ROWS, _chest_slot_panels, _chest_slot_labels)
	var backpack_panels: Array[PanelContainer] = []
	var backpack_labels: Array[Label] = []
	_create_inventory_slots(backpack_grid, CHEST_SLOT_COLUMNS * BACKPACK_SLOT_ROWS, backpack_panels, backpack_labels)

func _create_inventory_slots(target_grid: GridContainer, slot_count: int, out_panels: Array[PanelContainer], out_labels: Array[Label]) -> void:
	for child in target_grid.get_children():
		child.queue_free()
	out_panels.clear()
	out_labels.clear()
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
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.text = ""
		panel.add_child(label)
		target_grid.add_child(panel)
		out_panels.append(panel)
		out_labels.append(label)

func _populate_chest_slots(loot_entries: Array) -> void:
	for i in range(_chest_slot_labels.size()):
		_chest_slot_labels[i].text = ""
		_chest_slot_panels[i].tooltip_text = ""
	for i in range(mini(loot_entries.size(), _chest_slot_labels.size())):
		var entry := loot_entries[i] as Dictionary
		var item_name := String(entry.get("name", "Supplies"))
		var quantity := int(entry.get("quantity", 1))
		_chest_slot_labels[i].text = "%s\n%d" % [_item_abbreviation(item_name), quantity]
		_chest_slot_panels[i].tooltip_text = "%s x%d" % [item_name, quantity]

func _item_abbreviation(item_name: String) -> String:
	return DwarfHoldChestService.item_abbreviation(item_name)

func _build_house_decor_layouts(grid: Dictionary) -> Dictionary:
	return TownTileService.build_house_decor_layouts(grid, _latest_residence_type_map)

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
	_walkable_cells = _collect_walkable_cells(grid)
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
	if _player_sprite != null:
		_center_view_on_cell(_player_cell)
	_refresh_lighting(grid)

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
	if _is_chest_cell(clicked_cell):
		_request_chest_interaction(clicked_cell)
		return
	_request_player_move_to_cell(clicked_cell)

func _request_chest_interaction(chest_cell: Vector2i) -> void:
	if _player_cell == chest_cell:
		_handle_chest_click(_screen_position_from_cell(chest_cell))
		return
	if not _is_walkable_cell(chest_cell):
		_clear_chest_selection()
		return
	_request_player_move_to_cell(chest_cell)
	if not _player_move_path.is_empty():
		_player_pending_chest_interaction = chest_cell

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
	DwarfHoldTavernService.update_npc_movement(
		delta, _npc_states, city_layer, _rng,
		tavern_npc_speed_range, tile_size,
		Callable(self, "_is_npc_walkable_cell"),
		Callable(self, "_cell_center_position")
	)

func _create_placeholder_tavern_character_texture() -> Texture2D:
	return DwarfHoldTavernService.create_placeholder_tavern_character_texture()

func _is_walkable_cell(cell: Vector2i) -> bool:
	if _latest_grid.is_empty():
		return false
	var zone := int(_latest_grid.get(cell, CELL_ROCK))
	if zone != CELL_HALL and zone != CELL_HOUSE and zone != CELL_BUILDING and zone != CELL_PLAZA:
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

func _pick_base_tile(grid: Dictionary, x: int, y: int, cell: int) -> String:
	return TownTileService.pick_base_tile(grid, x, y, cell, _door_cells)

func _building_type_for_cell(cell: Vector2i) -> String:
	return String(_latest_civic_building_type_map.get(cell, "workshop"))

func _pick_decor_tile(grid: Dictionary, x: int, y: int, cell: int, base_tile: String, house_decor_overrides: Dictionary) -> String:
	return TownTileService.pick_decor_tile(grid, x, y, cell, base_tile, house_decor_overrides, _latest_civic_building_type_map, CIVIC_BUILDING_TYPES, _rng, _door_cells)


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
	var tooltip_lines: PackedStringArray = ["Tile: %s" % tile_name, "Zone: %s" % zone_name]
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

