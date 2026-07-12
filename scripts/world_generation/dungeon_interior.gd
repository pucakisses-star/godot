extends Control

## Enterable dungeon interiors, reached from the overworld via right-click
## "Begin your journey here" on a dungeon structure. Rooms and corridors are
## carved from a seeded generator and dressed with the web game's dungeon
## trap tilesets: fire jets that erupt on a cycle, saw blades patrolling
## corridors, pressure plates that spring floor spikes, spike pits, and
## pedestals + chests that pay out treasure into the persistent backpack.

const WALL := 0
const FLOOR := 1

const TILE_PX := 16
const OVERWORLD_SCENE_PATH := "res://scenes/overworld.tscn"
const WALLS_FLOOR_TEXTURE := preload("res://resources/images/webgame_tiles/dungeon_2/Tiled_files/walls_floor.png")
const FIRE_TRAP_TEXTURE := preload("res://resources/images/webgame_tiles/dungeon_2/Tiled_files/fire_trap.png")
const SPIKE_PIT_TEXTURE := preload("res://resources/images/webgame_tiles/dungeon_2/Tiled_files/Spike_trap.png")
const CHEST_TEXTURE := preload("res://resources/images/webgame_tiles/dungeon_2/Tiled_files/Chest_door_lever.png")
const SAW_TEXTURE := preload("res://resources/images/webgame_tiles/dungeon_1/PNG/trap_saw.png")
const SPIKE_PLATE_TEXTURE := preload("res://resources/images/webgame_tiles/dungeon_1/Tiled_files/trap_plate.png")
const PEDESTAL_TEXTURE := preload("res://resources/images/webgame_tiles/dungeon_1/Tiled_files/pedestals.png")
const SUPPLIES_TEXTURE := preload("res://resources/images/webgame_tiles/dungeon_1/Tiled_files/supplies_objects.png")

## walls_floor.png atlas coords (16px grid).
const FLOOR_TILE := Vector2i(11, 18)
const WALL_FACE_TILE := Vector2i(13, 1)
const WALL_FACE_ALT_TILE := Vector2i(12, 1)
const WALL_DARK_TILE := Vector2i(4, 5)
const STAIRS_TILE := Vector2i(13, 21)
const DEBRIS_TILES: Array[Vector2i] = [Vector2i(7, 20), Vector2i(8, 21), Vector2i(9, 20)]

## Dungeons run three floors deep. The first floor keeps the web game's
## brick vaults; below that the Shattered Pixel Dungeon terrain sheets
## take over — the sunken sewers, then the deep caves — with more traps,
## meaner garrisons, and richer treasure the farther down you go.
const MAX_DEPTH := 3
const SPD_SEWERS_TEXTURE := preload("res://resources/images/shattered_ui/tiles_sewers.png")
const SPD_CAVES_TEXTURE := preload("res://resources/images/shattered_ui/tiles_caves.png")
const DEPTH_THEMES: Array[Dictionary] = [
	{
		"label": "the old vaults",
		"floor": Vector2i(11, 18), "floor_variants": [],
		"walls": [Vector2i(13, 1), Vector2i(12, 1)], "wall_dark": Vector2i(4, 5),
		"stairs_up": Vector2i(13, 21), "stairs_down": Vector2i(13, 21),
		"debris": [Vector2i(7, 20), Vector2i(8, 21), Vector2i(9, 20)],
		"tint": Color(1.0, 1.0, 1.0, 1.0)
	},
	{
		"label": "the sunken sewers",
		"texture": "sewers",
		"floor": Vector2i(0, 0), "floor_variants": [Vector2i(1, 0), Vector2i(2, 0)],
		"walls": [Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5)], "wall_dark": Vector2i(14, 3),
		"stairs_up": Vector2i(0, 1), "stairs_down": Vector2i(1, 1),
		"debris": [Vector2i(2, 4), Vector2i(3, 4), Vector2i(1, 4), Vector2i(0, 4)],
		"tint": Color(0.88, 1.0, 0.92, 1.0)
	},
	{
		"label": "the deep caves",
		"texture": "caves",
		"floor": Vector2i(0, 0), "floor_variants": [Vector2i(1, 0), Vector2i(2, 0)],
		"walls": [Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5)], "wall_dark": Vector2i(14, 3),
		"stairs_up": Vector2i(0, 1), "stairs_down": Vector2i(1, 1),
		"debris": [Vector2i(2, 4), Vector2i(3, 4), Vector2i(1, 4), Vector2i(0, 4)],
		"tint": Color(1.0, 0.93, 0.86, 1.0)
	}
]

const DUNGEON_SCENE_SEED_KEY := "dungeon_scene_seed"
const DUNGEON_SCENE_NAME_KEY := "dungeon_scene_name"

var _player_max_hp := PlayerStatsService.BASE_MAX_HP
const PLAYER_MOVE_SPEED := 150.0
const TRAP_DAMAGE_COOLDOWN := 0.9
var _player_attack_damage := PlayerStatsService.BASE_ATTACK
const PLAYER_ATTACK_COOLDOWN := 0.45

## Dungeon garrison: the underdeep mob roster stands guard down here too.
## Elite defs (indices into UndergroundCreatureService.CREATURE_DEFS) watch
## the treasure room; lesser wanderers haunt the other rooms.
const CREATURE_TEXTURE := preload("res://resources/images/npc/creature_characters.png")
const TREASURE_GUARD_DEF_INDICES: Array[int] = [4, 5, 6, 7]
## Roaming mobs by depth: fungi near the surface, war parties in the caves.
const ROOM_MOB_DEF_INDICES_BY_DEPTH: Array = [
	[0, 1, 2, 3, 6],
	[1, 2, 3, 4, 6],
	[3, 4, 5, 6, 7]
]

## Sprite frame tables, transcribed from the web game's Tiled animation data.
const FIRE_FRAME_COUNT := 8
const FIRE_FRAME_TIME := 0.15
const FIRE_BLOCK_CELLS := Vector2i(5, 4)
const SPIKE_PIT_FRAME_TIME := 0.15
const SPIKE_PIT_SEQUENCE: Array[int] = [0, 1, 2, 3, 4, 5, 4, 3, 2, 1, 0, 0]
const SAW_FRAME_COUNT := 6
const SAW_FRAME_TIME := 0.1
const SAW_SPEED := 60.0
const PLATE_STATE_ROWS: Array[int] = [0, 2, 4, 6, 8, 10, 12, 14]
const PLATE_FRAME_TIME := 0.1
const CHEST_STATE_COUNT := 5
const CHEST_FRAME_TIME := 0.12

const PEDESTAL_CROPS: Array[Rect2] = [
	Rect2(16, 16, 48, 48),
	Rect2(128, 16, 48, 48),
	Rect2(240, 16, 48, 48),
	Rect2(16, 64, 48, 48),
	Rect2(240, 64, 48, 48)
]
const SUPPLY_CROPS: Array[Rect2] = [
	Rect2(160, 128, 32, 48),
	Rect2(16, 384, 64, 32),
	Rect2(64, 656, 64, 48)
]

const PEDESTAL_LOOT: Array[String] = [
	"Gold Trinket", "Golden Chain", "Gold Nugget", "Gem Shard",
	"Runed Tablet", "Silver Lantern", "Amber", "Skeleton Keys",
	"Trophy Skull", "Silver Ingot", "Gold Ingot", "Moss Agate"
]

const CHEST_LOOT_TABLE: Array[Dictionary] = [
	{"item": "Copper Coins", "min": 18, "max": 55, "chance": 100},
	{"item": "Gold Dust", "min": 1, "max": 2, "chance": 45},
	{"item": "Gem Shard", "min": 1, "max": 2, "chance": 35},
	{"item": "Gold Ingot", "min": 1, "max": 1, "chance": 20},
	{"item": "Old Bone", "min": 1, "max": 3, "chance": 40},
	{"item": "Ancient Skull", "min": 1, "max": 1, "chance": 18},
	{"item": "Iron Ingot", "min": 1, "max": 2, "chance": 30},
	{"item": "Steel Ingot", "min": 1, "max": 1, "chance": 15},
	{"item": "Fossil Cluster", "min": 1, "max": 1, "chance": 20},
	{"item": "Skeleton Keys", "min": 1, "max": 1, "chance": 12}
]

@onready var dungeon_panel: PanelContainer = %DungeonPanel
@onready var floor_layer: TileMapLayer = %FloorTileLayer
@onready var decor_layer: TileMapLayer = %DecorTileLayer
@onready var trap_layer: Node2D = %TrapLayer
@onready var actor_layer: Node2D = %ActorLayer
@onready var dungeon_name_label: Label = %DungeonNameLabel
@onready var hp_label: Label = %HpLabel
@onready var coins_label: Label = %CoinsLabel
@onready var status_label: Label = %StatusLabel
@onready var leave_button: Button = %LeaveButton

var _rng := RandomNumberGenerator.new()
var _grid: Dictionary = {}
var _rooms: Array[Rect2i] = []
var _entrance_cell := Vector2i.ZERO
var _spawn_cell := Vector2i.ZERO
var _dungeon_name := "Forgotten Dungeon"
var _blocked_cells: Dictionary = {}
var _base_seed_text := ""
var _depth := 1
var _down_stairs_cell := Vector2i(2147483647, 2147483647)

var _player_sprite: Sprite2D
var _player_cell := Vector2i.ZERO
var _player_hp := _player_max_hp
var _player_move_path: Array[Vector2i] = []
var _player_is_moving := false
var _respawn_move_lock := false
var _exiting_dungeon := false
var _player_move_target_cell := Vector2i.ZERO
var _player_move_target_position := Vector2.ZERO
var _player_inventory: Dictionary = {}
var _player_coins := 0
var _trap_damage_timers: Dictionary = {}

var _zoom_level := 2.4
var _escape_menu: EscapeMenu
var _game_over: GameOverScreen

var _fire_traps: Array[Dictionary] = []
var _saw_traps: Array[Dictionary] = []
var _spike_plates: Dictionary = {}
var _spike_pits: Array[Dictionary] = []
var _pedestals: Dictionary = {}
var _restored_loot_state: Dictionary = {}
var _chests: Dictionary = {}
var _creatures: Array[Dictionary] = []
var _player_attack_timer := 0.0

func _ready() -> void:
	GameAudioService.play_music(self, "hold")
	_load_scene_context()
	_load_player_inventory()
	leave_button.pressed.connect(_leave_dungeon)
	dungeon_panel.gui_input.connect(_on_panel_gui_input)
	_escape_menu = EscapeMenu.new()
	_escape_menu.show_return_to_map = true
	add_child(_escape_menu)
	_generate_dungeon()
	_update_hp_label()
	_update_coins_label()
	## The "Strike the earth!" greeting, once, on a new walker's first embark.
	EmbarkIntroScreen.maybe_present(self)

## The embark screen reads this to tailor its greeting to the start place.
func _embark_place() -> Dictionary:
	return {"kind": "dungeon", "name": _dungeon_name}

func _process(delta: float) -> void:
	_player_attack_timer = maxf(_player_attack_timer - delta, 0.0)
	_update_player_movement(delta)
	_update_creatures(delta)
	_update_fire_traps(delta)
	_update_saw_traps(delta)
	_update_spike_plates(delta)
	_update_spike_pits(delta)
	_update_chests(delta)
	_decay_trap_damage_timers(delta)
	_update_view_transform()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _escape_menu != null:
			_escape_menu.toggle()
		get_viewport().set_input_as_handled()
		return
	if _player_sprite == null:
		return
	var move_direction := DwarfHoldUiInputHandler.move_direction_from_event(event)
	if move_direction != Vector2i.ZERO:
		_player_move_path.clear()
		_try_step(move_direction)

func _stamp_last_scene() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings") or not game_session.has_method("set_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	settings["last_scene"] = "res://scenes/dungeon_interior.tscn"
	game_session.call("set_world_settings", settings)

func _load_scene_context() -> void:
	_stamp_last_scene()
	var game_session := get_node_or_null("/root/GameSession")
	var seed_text := ""
	if game_session != null and game_session.has_method("get_world_settings"):
		var settings: Dictionary = game_session.call("get_world_settings")
		seed_text = String(settings.get(DUNGEON_SCENE_SEED_KEY, "")).strip_edges()
		var stored_name := String(settings.get(DUNGEON_SCENE_NAME_KEY, "")).strip_edges()
		if not stored_name.is_empty():
			_dungeon_name = stored_name
	if seed_text.is_empty():
		_rng.randomize()
		seed_text = str(_rng.randi())
	_base_seed_text = seed_text

func _load_player_inventory() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	var inventory_variant: Variant = settings.get("player_inventory", {})
	_player_inventory = (inventory_variant as Dictionary).duplicate() if inventory_variant is Dictionary else {}
	_player_coins = int(settings.get("player_coins", 0))
	var stats := PlayerStatsService.for_session(self)
	_player_max_hp = float(stats.get("max_hp", _player_max_hp))
	_player_attack_damage = int(stats.get("attack", _player_attack_damage))
	_player_hp = clampf(float(settings.get("player_hp", _player_max_hp)), 1.0, _player_max_hp)

func _save_player_inventory() -> void:
	# Once the game-over modal owns the session, the death-moment save has
	# already run; the dying scene must not smear its zeroed state over a
	# freshly loaded save or a stripped successor session as it exits.
	if _game_over != null and is_instance_valid(_game_over):
		return
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings") or not game_session.has_method("set_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	settings["player_inventory"] = _player_inventory.duplicate()
	settings["player_coins"] = _player_coins
	settings["player_hp"] = _player_hp
	game_session.call("set_world_settings", settings)

func _exit_tree() -> void:
	_save_player_inventory()

## Chests opened and pedestals looted are remembered per floor, so a
## dungeon cannot be farmed by walking out and back in.
func _dungeon_state_key() -> String:
	return "%s::depth_%d" % [_base_seed_text, _depth]

func _looted_state(create: bool) -> Dictionary:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings"):
		return {}
	var settings: Dictionary = game_session.call("get_world_settings")
	var all_state_variant: Variant = settings.get("dungeon_state", {})
	var all_state: Dictionary = all_state_variant as Dictionary if all_state_variant is Dictionary else {}
	var key := _dungeon_state_key()
	var state_variant: Variant = all_state.get(key, {})
	var state: Dictionary = state_variant as Dictionary if state_variant is Dictionary else {}
	if create:
		all_state[key] = state
		settings["dungeon_state"] = all_state
		game_session.call("set_world_settings", settings)
	return state

func _record_looted(kind: String, cell: Vector2i) -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("set_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	var all_state_variant: Variant = settings.get("dungeon_state", {})
	var all_state: Dictionary = all_state_variant as Dictionary if all_state_variant is Dictionary else {}
	var key := _dungeon_state_key()
	var state: Dictionary = all_state.get(key, {}) as Dictionary
	var cells: Array = state.get(kind, []) as Array
	var cell_key := "%d,%d" % [cell.x, cell.y]
	if not cells.has(cell_key):
		cells.append(cell_key)
	state[kind] = cells
	all_state[key] = state
	settings["dungeon_state"] = all_state
	game_session.call("set_world_settings", settings)

func _was_looted(state: Dictionary, kind: String, cell: Vector2i) -> bool:
	return (state.get(kind, []) as Array).has("%d,%d" % [cell.x, cell.y])

func _theme() -> Dictionary:
	return DEPTH_THEMES[clampi(_depth - 1, 0, DEPTH_THEMES.size() - 1)]

func _theme_texture(depth_theme: Dictionary) -> Texture2D:
	match String(depth_theme.get("texture", "")):
		"sewers":
			return SPD_SEWERS_TEXTURE
		"caves":
			return SPD_CAVES_TEXTURE
		_:
			return WALLS_FLOOR_TEXTURE

func _configure_tile_layer() -> void:
	var depth_theme := _theme()
	var atlas := TileSetAtlasSource.new()
	atlas.texture = _theme_texture(depth_theme)
	atlas.texture_region_size = Vector2i(TILE_PX, TILE_PX)
	var used_tiles: Array[Vector2i] = [
		depth_theme.get("floor", Vector2i.ZERO) as Vector2i,
		depth_theme.get("wall_dark", Vector2i.ZERO) as Vector2i,
		depth_theme.get("stairs_up", Vector2i.ZERO) as Vector2i,
		depth_theme.get("stairs_down", Vector2i.ZERO) as Vector2i
	]
	for coords_variant: Variant in (depth_theme.get("floor_variants", []) as Array) + (depth_theme.get("walls", []) as Array) + (depth_theme.get("debris", []) as Array):
		used_tiles.append(coords_variant as Vector2i)
	for coords: Vector2i in used_tiles:
		if not atlas.has_tile(coords):
			atlas.create_tile(coords)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_PX, TILE_PX)
	tile_set.add_source(atlas, 0)
	floor_layer.tile_set = tile_set
	decor_layer.tile_set = tile_set
	floor_layer.modulate = depth_theme.get("tint", Color.WHITE) as Color
	decor_layer.modulate = depth_theme.get("tint", Color.WHITE) as Color

## --- Generation -------------------------------------------------------------

func _generate_dungeon() -> void:
	_rng.seed = hash("%s::depth_%d" % [_base_seed_text, _depth])
	_configure_tile_layer()
	dungeon_name_label.text = "%s — Depth %d / %d" % [_dungeon_name, _depth, MAX_DEPTH]
	_grid.clear()
	_rooms.clear()
	_blocked_cells.clear()
	_trap_damage_timers.clear()
	_down_stairs_cell = Vector2i(2147483647, 2147483647)
	var room_count := _rng.randi_range(7, 11)
	var area := Rect2i(0, 0, 58, 42)
	for _attempt in range(room_count * 14):
		if _rooms.size() >= room_count:
			break
		var room_size := Vector2i(_rng.randi_range(5, 9), _rng.randi_range(4, 8))
		var origin := Vector2i(
			_rng.randi_range(area.position.x + 1, area.end.x - room_size.x - 1),
			_rng.randi_range(area.position.y + 1, area.end.y - room_size.y - 1)
		)
		var candidate := Rect2i(origin, room_size)
		var overlaps := false
		for room: Rect2i in _rooms:
			if candidate.grow(1).intersects(room):
				overlaps = true
				break
		if overlaps:
			continue
		_rooms.append(candidate)
		for y in range(candidate.position.y, candidate.end.y):
			for x in range(candidate.position.x, candidate.end.x):
				_grid[Vector2i(x, y)] = FLOOR
	# L-corridors chain the rooms in placement order, then one extra loop.
	for room_index in range(1, _rooms.size()):
		_carve_corridor(_rooms[room_index - 1].get_center(), _rooms[room_index].get_center())
	if _rooms.size() > 3:
		_carve_corridor(_rooms[0].get_center(), _rooms[_rooms.size() - 1].get_center())

	_entrance_cell = _rooms[0].get_center() if not _rooms.is_empty() else Vector2i.ZERO
	_spawn_cell = _entrance_cell + Vector2i(1, 0)
	if int(_grid.get(_spawn_cell, WALL)) != FLOOR:
		_spawn_cell = _entrance_cell + Vector2i(0, 1)

	_render_grid()
	for child in trap_layer.get_children():
		child.queue_free()
	# Treasure claims its ground first; traps then keep clear of it.
	_place_treasure()
	_place_down_stairs()
	_place_traps()
	_spawn_dungeon_creatures()
	_spawn_player()
	_set_status("Depth %d — you enter %s… watch the floor." % [_depth, String((_theme() as Dictionary).get("label", "the dark"))], Color(0.85, 0.8, 0.95, 1.0))

## The way down: a staircase in the treasure room's corner on every floor
## above the bottom. Stepping on it descends into the next theme.
func _place_down_stairs() -> void:
	if _depth >= MAX_DEPTH or _rooms.is_empty():
		return
	var treasure_room := _treasure_room()
	for _attempt in range(30):
		var cell := _random_room_cell(treasure_room)
		if _is_walkable(cell) and cell != _entrance_cell:
			_down_stairs_cell = cell
			floor_layer.set_cell(cell, 0, (_theme() as Dictionary).get("stairs_down", Vector2i.ZERO) as Vector2i)
			decor_layer.erase_cell(cell)
			return

func _travel_to_depth(new_depth: int) -> void:
	var ascending := new_depth < _depth
	_depth = clampi(new_depth, 1, MAX_DEPTH)
	_player_move_path.clear()
	_player_is_moving = false
	_generate_dungeon()
	# Climbing up lands beside the staircase you climbed — matching how
	# the settlement scenes pair stairs — not back at the floor's
	# entrance, where one accidental step exits the dungeon entirely.
	if ascending and _down_stairs_cell != Vector2i(2147483647, 2147483647) and _player_sprite != null:
		var landing := _down_stairs_cell
		for direction: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if _is_walkable(_down_stairs_cell + direction):
				landing = _down_stairs_cell + direction
				break
		_player_cell = landing
		_player_sprite.position = _cell_center(landing)

func _carve_corridor(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var cursor := from_cell
	var horizontal_first := _rng.randf() < 0.5
	var steps: Array[Vector2i] = []
	if horizontal_first:
		steps = [Vector2i(signi(to_cell.x - cursor.x), 0), Vector2i(0, signi(to_cell.y - cursor.y))]
	else:
		steps = [Vector2i(0, signi(to_cell.y - cursor.y)), Vector2i(signi(to_cell.x - cursor.x), 0)]
	for step: Vector2i in steps:
		if step == Vector2i.ZERO:
			continue
		while (step.x != 0 and cursor.x != to_cell.x) or (step.y != 0 and cursor.y != to_cell.y):
			cursor += step
			_grid[cursor] = FLOOR

func _render_grid() -> void:
	var depth_theme := _theme()
	var floor_tile := depth_theme.get("floor", Vector2i.ZERO) as Vector2i
	var floor_variants := depth_theme.get("floor_variants", []) as Array
	var wall_tiles := depth_theme.get("walls", []) as Array
	var wall_dark := depth_theme.get("wall_dark", Vector2i.ZERO) as Vector2i
	var debris := depth_theme.get("debris", []) as Array
	floor_layer.clear()
	decor_layer.clear()
	var floor_cells: Array[Vector2i] = []
	for cell_variant: Variant in _grid.keys():
		if int(_grid[cell_variant]) == FLOOR:
			floor_cells.append(cell_variant as Vector2i)
	var wall_cells: Dictionary = {}
	for cell: Vector2i in floor_cells:
		var cell_tile := floor_tile
		if not floor_variants.is_empty() and (cell.x * 31 + cell.y * 17) % 9 == 0:
			cell_tile = floor_variants[(cell.x + cell.y) % floor_variants.size()] as Vector2i
		floor_layer.set_cell(cell, 0, cell_tile)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var neighbor := cell + Vector2i(dx, dy)
				if int(_grid.get(neighbor, WALL)) != FLOOR:
					wall_cells[neighbor] = true
	for wall_variant: Variant in wall_cells.keys():
		var wall_cell := wall_variant as Vector2i
		# South-facing walls show their face; the rest read as dark mass.
		if int(_grid.get(wall_cell + Vector2i(0, 1), WALL)) == FLOOR and not wall_tiles.is_empty():
			floor_layer.set_cell(wall_cell, 0, wall_tiles[(wall_cell.x + wall_cell.y) % wall_tiles.size()] as Vector2i)
		else:
			floor_layer.set_cell(wall_cell, 0, wall_dark)
	floor_layer.set_cell(_entrance_cell, 0, depth_theme.get("stairs_up", Vector2i.ZERO) as Vector2i)
	# Rubble keeps the halls from feeling freshly swept.
	for cell: Vector2i in floor_cells:
		if cell != _entrance_cell and not debris.is_empty() and _rng.randf() < 0.045:
			decor_layer.set_cell(cell, 0, debris[_rng.randi_range(0, debris.size() - 1)] as Vector2i)

## --- Trap placement ----------------------------------------------------------

func _place_traps() -> void:
	_fire_traps.clear()
	_saw_traps.clear()
	_spike_plates.clear()
	_spike_pits.clear()
	_place_saw_traps()
	_place_fire_traps()
	_place_spike_pits()
	_place_spike_plates()

func _rect_overlaps_blocked(rect: Rect2i) -> bool:
	# The staircase down counts as blocked ground for every area hazard:
	# a trap footprint covering it would hide the way down and force
	# damage to descend. (Sentinel coords before placement never match.)
	if rect.has_point(_down_stairs_cell):
		return true
	for blocked_variant: Variant in _blocked_cells.keys():
		if rect.has_point(blocked_variant as Vector2i):
			return true
	return false

func _is_safe_zone(cell: Vector2i) -> bool:
	if _rooms.is_empty():
		return false
	return _rooms[0].grow(2).has_point(cell)

func _corridor_runs(minimum_length: int) -> Array[Dictionary]:
	## Straight floor runs outside rooms, as {"start", "dir", "length"}.
	var runs: Array[Dictionary] = []
	var in_room: Dictionary = {}
	for room: Rect2i in _rooms:
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				in_room[Vector2i(x, y)] = true
	var claimed: Dictionary = {}
	for cell_variant: Variant in _grid.keys():
		var cell := cell_variant as Vector2i
		if int(_grid[cell_variant]) != FLOOR or in_room.has(cell) or claimed.has(cell):
			continue
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			if int(_grid.get(cell - dir, WALL)) == FLOOR and not in_room.has(cell - dir):
				continue
			var length := 0
			var probe := cell
			while int(_grid.get(probe, WALL)) == FLOOR and not in_room.has(probe):
				length += 1
				probe += dir
			if length >= minimum_length:
				for offset in range(length):
					claimed[cell + dir * offset] = true
				runs.append({"start": cell, "dir": dir, "length": length})
	return runs

func _place_saw_traps() -> void:
	var runs := _corridor_runs(5)
	var placed := 0
	for run: Dictionary in runs:
		if placed >= 2 + _depth:
			break
		var start := run.get("start", Vector2i.ZERO) as Vector2i
		if _is_safe_zone(start):
			continue
		var dir := run.get("dir", Vector2i(1, 0)) as Vector2i
		var length := int(run.get("length", 0))
		var cells: Array[Vector2i] = []
		for offset in range(length):
			cells.append(start + dir * offset)
		var sprite := Sprite2D.new()
		sprite.texture = SAW_TEXTURE
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, 192, 32, 32)
		sprite.scale = Vector2.ONE * 0.75
		sprite.position = _cell_center(cells[0])
		sprite.z_index = 6
		trap_layer.add_child(sprite)
		_saw_traps.append({
			"cells": cells,
			"sprite": sprite,
			"progress": 0.0,
			"direction": 1,
			"anim_time": _rng.randf_range(0.0, 1.0)
		})
		placed += 1

func _place_fire_traps() -> void:
	var placed := 0
	for room_index in range(1, _rooms.size()):
		if placed >= 1 + _depth:
			break
		var room := _rooms[room_index]
		if room.size.x < FIRE_BLOCK_CELLS.x + 2 or room.size.y < FIRE_BLOCK_CELLS.y + 1:
			continue
		var origin := Vector2i(
			_rng.randi_range(room.position.x + 1, room.end.x - FIRE_BLOCK_CELLS.x - 1),
			_rng.randi_range(room.position.y, room.end.y - FIRE_BLOCK_CELLS.y - 1)
		)
		if _rect_overlaps_blocked(Rect2i(origin, FIRE_BLOCK_CELLS)):
			continue
		var sprite := Sprite2D.new()
		sprite.texture = FIRE_TRAP_TEXTURE
		sprite.region_enabled = true
		sprite.centered = false
		sprite.region_rect = Rect2(0, 0, 80, 64)
		sprite.position = Vector2(origin * TILE_PX)
		sprite.z_index = 5
		trap_layer.add_child(sprite)
		_fire_traps.append({
			"origin": origin,
			"sprite": sprite,
			"timer": _rng.randf_range(0.5, 2.5),
			"active": false
		})
		placed += 1

func _place_spike_pits() -> void:
	var placed := 0
	for room_index in range(1, _rooms.size()):
		if placed >= 3:
			break
		var room := _rooms[_rooms.size() - room_index]
		if room.size.x < 5 or room.size.y < 5:
			continue
		var origin := Vector2i(
			_rng.randi_range(room.position.x + 1, room.end.x - 4),
			_rng.randi_range(room.position.y + 1, room.end.y - 4)
		)
		if _is_safe_zone(origin) or _rect_overlaps_blocked(Rect2i(origin, Vector2i(3, 3))):
			continue
		var sprite := Sprite2D.new()
		sprite.texture = SPIKE_PIT_TEXTURE
		sprite.region_enabled = true
		sprite.centered = false
		sprite.region_rect = Rect2(0, 0, 48, 48)
		sprite.position = Vector2(origin * TILE_PX)
		sprite.z_index = 4
		trap_layer.add_child(sprite)
		_spike_pits.append({
			"origin": origin,
			"sprite": sprite,
			"anim_time": _rng.randf_range(0.0, 1.8)
		})
		placed += 1

func _place_spike_plates() -> void:
	var candidates: Array[Vector2i] = []
	for cell_variant: Variant in _grid.keys():
		var cell := cell_variant as Vector2i
		if int(_grid[cell_variant]) != FLOOR or _is_safe_zone(cell) or _blocked_cells.has(cell):
			continue
		# Never on the way down: a plate sprite would cover the staircase
		# and force trap damage to descend.
		if cell == _down_stairs_cell:
			continue
		if decor_layer.get_cell_source_id(cell) >= 0:
			continue
		candidates.append(cell)
	candidates.sort()
	_seeded_shuffle(candidates)
	var target := clampi(candidates.size() / 24, 4, 10) + 2 * (_depth - 1)
	for cell: Vector2i in candidates:
		if _spike_plates.size() >= target:
			break
		var too_close := false
		for existing_variant: Variant in _spike_plates.keys():
			if (existing_variant as Vector2i).distance_to(cell) < 3.0:
				too_close = true
				break
		if too_close:
			continue
		var sprite := Sprite2D.new()
		sprite.texture = SPIKE_PLATE_TEXTURE
		sprite.region_enabled = true
		sprite.centered = false
		sprite.region_rect = Rect2(16, 0, 16, 32)
		sprite.position = Vector2(cell * TILE_PX) - Vector2(0, TILE_PX)
		sprite.z_index = 4
		trap_layer.add_child(sprite)
		_spike_plates[cell] = {
			"sprite": sprite,
			"state": 0,
			"timer": 0.0,
			"triggered": false
		}

## --- Treasure ----------------------------------------------------------------

func _place_treasure() -> void:
	_restored_loot_state = _looted_state(false)
	_pedestals.clear()
	_chests.clear()
	if _rooms.is_empty():
		return
	# The treasure room is the one farthest from the entrance.
	var treasure_room := _rooms[0]
	var best_distance := -1.0
	for room: Rect2i in _rooms:
		var distance := Vector2(room.get_center()).distance_to(Vector2(_entrance_cell))
		if distance > best_distance:
			best_distance = distance
			treasure_room = room
	var pedestal_count := _rng.randi_range(2, 4) + (_depth - 1)
	for _pedestal_attempt in range(pedestal_count * 10):
		if _pedestals.size() >= pedestal_count:
			break
		var cell := Vector2i(
			_rng.randi_range(treasure_room.position.x + 1, treasure_room.end.x - 2),
			_rng.randi_range(treasure_room.position.y + 1, treasure_room.end.y - 2)
		)
		if _pedestals.has(cell):
			continue
		var sprite := Sprite2D.new()
		sprite.texture = PEDESTAL_TEXTURE
		sprite.region_enabled = true
		sprite.region_rect = PEDESTAL_CROPS[_rng.randi_range(0, PEDESTAL_CROPS.size() - 1)]
		sprite.scale = Vector2.ONE * 0.6
		sprite.position = _cell_center(cell)
		sprite.z_index = 7
		trap_layer.add_child(sprite)
		var item := PEDESTAL_LOOT[_rng.randi_range(0, PEDESTAL_LOOT.size() - 1)]
		var icon := _spawn_item_icon(item, _cell_center(cell) + Vector2(0, -10.0))
		_pedestals[cell] = {"sprite": sprite, "icon": icon, "item": item, "looted": false}
		if _was_looted(_restored_loot_state, "pedestals", cell):
			_pedestals[cell]["looted"] = true
			icon.queue_free()
			_pedestals[cell]["icon"] = null
		_blocked_cells[cell] = true
	# Chests in one or two of the other far rooms.
	var chest_count := _rng.randi_range(1, 2) + (_depth - 1)
	var chest_rooms := _rooms.duplicate()
	chest_rooms.erase(_rooms[0])
	_seeded_shuffle(chest_rooms)
	for room_variant: Variant in chest_rooms:
		if _chests.size() >= chest_count:
			break
		var room := room_variant as Rect2i
		var cell := Vector2i(
			_rng.randi_range(room.position.x + 1, room.end.x - 2),
			_rng.randi_range(room.position.y + 1, room.end.y - 2)
		)
		if _pedestals.has(cell) or _chests.has(cell):
			continue
		var sprite := Sprite2D.new()
		sprite.texture = CHEST_TEXTURE
		sprite.region_enabled = true
		sprite.centered = false
		sprite.region_rect = Rect2(96, 16, 32, 32)
		sprite.position = Vector2(cell * TILE_PX) - Vector2(8.0, TILE_PX)
		sprite.z_index = 7
		trap_layer.add_child(sprite)
		_chests[cell] = {"sprite": sprite, "opened": false, "anim_time": 0.0, "animating": false}
		if _was_looted(_restored_loot_state, "chests", cell):
			_chests[cell]["opened"] = true
			sprite.region_rect = Rect2(96, (CHEST_STATE_COUNT - 1) * 48 + 16, 32, 32)
		_blocked_cells[cell] = true
	# A few supply piles for dressing.
	for room: Rect2i in _rooms:
		if _rng.randf() > 0.55 or room == _rooms[0]:
			continue
		var cell := Vector2i(room.position.x + 1, room.position.y + 1)
		if _blocked_cells.has(cell):
			continue
		var sprite := Sprite2D.new()
		sprite.texture = SUPPLIES_TEXTURE
		sprite.region_enabled = true
		sprite.region_rect = SUPPLY_CROPS[_rng.randi_range(0, SUPPLY_CROPS.size() - 1)]
		sprite.scale = Vector2.ONE * 0.7
		sprite.position = _cell_center(cell)
		sprite.z_index = 6
		trap_layer.add_child(sprite)
		_blocked_cells[cell] = true

func _spawn_item_icon(item_name: String, world_position: Vector2) -> Sprite2D:
	var texture := ItemDefsService.icon_texture(item_name)
	if texture == null:
		return null
	var icon := Sprite2D.new()
	icon.texture = texture
	icon.scale = Vector2.ONE * 0.45
	icon.position = world_position
	icon.z_index = 8
	trap_layer.add_child(icon)
	return icon

func _cell_has_trap(cell: Vector2i) -> bool:
	if _spike_plates.has(cell):
		return true
	for pit: Dictionary in _spike_pits:
		var origin := pit.get("origin", Vector2i.ZERO) as Vector2i
		if Rect2i(origin, Vector2i(3, 3)).has_point(cell):
			return true
	for fire: Dictionary in _fire_traps:
		var origin := fire.get("origin", Vector2i.ZERO) as Vector2i
		if Rect2i(origin, FIRE_BLOCK_CELLS).has_point(cell):
			return true
	for saw: Dictionary in _saw_traps:
		if (saw.get("cells", []) as Array).has(cell):
			return true
	return false

## --- Monsters ------------------------------------------------------------------
## The underdeep mob roster garrisons the dungeon: elite lizardmen and orc
## chieftains stand over the treasure room, lesser things prowl the halls.
## Same animation state machine as the dwarfhold (walk/idle loops, attack and
## hurt one-shots, a death animation that lingers before the corpse fades).

func _spawn_dungeon_creatures() -> void:
	for state: Dictionary in _creatures:
		var old_sprite := state.get("sprite") as Sprite2D
		if old_sprite != null:
			old_sprite.queue_free()
	_creatures.clear()
	if _rooms.is_empty():
		return
	# The treasure room's honor guard, posted beside the pedestals.
	var treasure_room := _treasure_room()
	var guard_count := _rng.randi_range(2, 3) + (_depth - 1)
	for _guard_index in range(guard_count * 8):
		if _guards_in_room(treasure_room) >= guard_count:
			break
		var cell := _random_room_cell(treasure_room)
		if _creature_can_spawn_at(cell):
			_spawn_creature_at(cell, TREASURE_GUARD_DEF_INDICES[_rng.randi_range(0, TREASURE_GUARD_DEF_INDICES.size() - 1)])
	# Wandering mobs in the other rooms; the entrance room stays safe.
	var mob_pool := ROOM_MOB_DEF_INDICES_BY_DEPTH[clampi(_depth - 1, 0, ROOM_MOB_DEF_INDICES_BY_DEPTH.size() - 1)] as Array
	var room_chance := minf(0.6 + 0.15 * float(_depth - 1), 0.9)
	for room_index in range(1, _rooms.size()):
		var room := _rooms[room_index]
		if room == treasure_room or _rng.randf() > room_chance:
			continue
		var mob_count := _rng.randi_range(1, 2)
		for _mob_attempt in range(mob_count * 6):
			if _guards_in_room(room) >= mob_count:
				break
			var cell := _random_room_cell(room)
			if _creature_can_spawn_at(cell):
				_spawn_creature_at(cell, int(mob_pool[_rng.randi_range(0, mob_pool.size() - 1)]))

func _treasure_room() -> Rect2i:
	var treasure_room := _rooms[0]
	var best_distance := -1.0
	for room: Rect2i in _rooms:
		var distance := Vector2(room.get_center()).distance_to(Vector2(_entrance_cell))
		if distance > best_distance:
			best_distance = distance
			treasure_room = room
	return treasure_room

func _random_room_cell(room: Rect2i) -> Vector2i:
	return Vector2i(
		_rng.randi_range(room.position.x, room.end.x - 1),
		_rng.randi_range(room.position.y, room.end.y - 1)
	)

func _guards_in_room(room: Rect2i) -> int:
	var count := 0
	for state: Dictionary in _creatures:
		if room.has_point(state.get("cell", Vector2i.ZERO) as Vector2i):
			count += 1
	return count

func _creature_can_spawn_at(cell: Vector2i) -> bool:
	return _is_walkable(cell) and _creature_index_at_cell(cell) < 0 and not _cell_has_trap(cell) and cell != _spawn_cell

func _spawn_creature_at(cell: Vector2i, def_index: int) -> void:
	if def_index < 0 or def_index >= UndergroundCreatureService.CREATURE_DEFS.size():
		return
	var def: Dictionary = UndergroundCreatureService.CREATURE_DEFS[def_index]
	var sprite: Sprite2D = UndergroundCreatureService.create_creature_sprite(CREATURE_TEXTURE, int(def.get("slot", 0)), Vector2i(TILE_PX, TILE_PX))
	sprite.position = _cell_center(cell)
	sprite.z_index = 9
	actor_layer.add_child(sprite)
	_creatures.append({
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

func _creature_index_at_cell(cell: Vector2i) -> int:
	for index in range(_creatures.size()):
		var state := _creatures[index]
		if bool(state.get("dying", false)):
			continue
		if (state.get("cell", Vector2i(2147483647, 2147483647)) as Vector2i) == cell:
			return index
		if bool(state.get("moving", false)) and (state.get("move_cell", Vector2i(2147483647, 2147483647)) as Vector2i) == cell:
			return index
	return -1

func _creature_can_step_to(cell: Vector2i) -> bool:
	if not _is_walkable(cell):
		return false
	# The entrance room is safe ground; monsters will not follow you in.
	if _is_safe_zone(cell):
		return false
	if _creature_index_at_cell(cell) >= 0:
		return false
	return cell != _player_cell

func _update_creatures(delta: float) -> void:
	if _creatures.is_empty():
		return
	var removals: Array[int] = []
	for index in range(_creatures.size()):
		var state := _creatures[index]
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
		state["attack_timer"] = maxf(float(state.get("attack_timer", 0.0)) - delta, 0.0)
		# One-shot swings and flinches play out, then locomotion retakes the sprite.
		var current_anim := String(state.get("anim", "idle"))
		if (current_anim == "attack" or current_anim == "hurt") and float(state.get("anim_time", 0.0)) >= UndergroundCreatureService.anim_duration(current_anim):
			_set_creature_anim(state, "idle")
		if bool(state.get("moving", false)):
			var target := state.get("move_target", sprite.position) as Vector2
			var creature_speed := float(def.get("speed", 60.0)) * (float(TILE_PX) / 32.0)
			sprite.position = sprite.position.move_toward(target, creature_speed * delta)
			if sprite.position.distance_to(target) <= 0.4:
				sprite.position = target
				state["cell"] = state.get("move_cell", cell) as Vector2i
				state["moving"] = false
		elif player_distance <= 1 and not _is_safe_zone(_player_cell):
			state["facing_dir"] = _direction_between_cells(cell, _player_cell)
			if float(state.get("attack_timer", 0.0)) <= 0.0:
				state["attack_timer"] = float(def.get("attack_cooldown", 1.3))
				_set_creature_anim(state, "attack")
				_damage_player(int(def.get("damage", 1)), String(def.get("name", "creature")))
		else:
			var step := Vector2i.ZERO
			if player_distance <= int(def.get("aggro_range", 6)) and not _is_safe_zone(_player_cell):
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
					state["move_target"] = _cell_center(next_cell)
					state["facing_dir"] = step
		current_anim = String(state.get("anim", "idle"))
		if current_anim != "attack" and current_anim != "hurt":
			_set_creature_anim(state, "walk" if bool(state.get("moving", false)) else "idle")
		_animate_creature(state, sprite, def)
	for removal_index in range(removals.size() - 1, -1, -1):
		_creatures.remove_at(removals[removal_index])

func _creature_step_toward(from_cell: Vector2i, target_cell: Vector2i) -> Vector2i:
	return CreatureCombatService.step_toward(from_cell, target_cell, Callable(self, "_creature_can_step_to"))

func _direction_between_cells(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	return CreatureCombatService.direction_between_cells(from_cell, to_cell)

func _set_creature_anim(state: Dictionary, anim_name: String) -> void:
	CreatureCombatService.set_creature_anim(state, anim_name)

func _animate_creature(state: Dictionary, sprite: Sprite2D, def: Dictionary) -> void:
	CreatureCombatService.animate_creature(state, sprite, def)

func _attack_creature(creature_index: int) -> void:
	if creature_index < 0 or creature_index >= _creatures.size():
		return
	if _player_attack_timer > 0.0:
		return
	_player_attack_timer = PLAYER_ATTACK_COOLDOWN
	var state := _creatures[creature_index]
	if bool(state.get("dying", false)):
		return
	var def: Dictionary = UndergroundCreatureService.CREATURE_DEFS[int(state.get("def_index", 0))]
	var sprite := state.get("sprite") as Sprite2D
	state["hp"] = int(state.get("hp", 1)) - _player_attack_damage
	if sprite != null:
		_flash_sprite(sprite, Color(1.0, 0.45, 0.45, 1.0))
		_spawn_floating_text("-%d" % _player_attack_damage, sprite.position, Color(1.0, 0.85, 0.5, 1.0))
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
	state["dying"] = true
	state["moving"] = false
	_set_creature_anim(state, "death")
	var message := "Slew %s" % String(def.get("name", "creature"))
	if not loot_parts.is_empty():
		message += " — " + ", ".join(loot_parts)
	_set_status(message, Color(0.85, 0.95, 0.7, 1.0))
	_save_player_inventory()

## --- Player ------------------------------------------------------------------

func _spawn_player() -> void:
	if _player_sprite != null:
		_player_sprite.queue_free()
	# Your delver is the dwarf chosen at character creation; characters
	# made before the picker wear the profession hero sheet instead.
	_player_sprite = Sprite2D.new()
	var composed := DwarfHoldActorVisuals.resolve_player_dwarf_texture(self)
	var character_slot := DwarfHoldActorVisuals.resolve_player_character_slot(self)
	if composed != null:
		_player_sprite.texture = composed
		_player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_player_sprite.scale = Vector2.ONE * (float(TILE_PX) / float(composed.get_height())) * 0.95
	elif character_slot >= 0:
		var dwarf_texture := DwarfHoldActorVisuals.DWARF_CHARACTERS_TEXTURE
		var frame := Vector2i(dwarf_texture.get_width() / 12, dwarf_texture.get_height() / 8)
		_player_sprite.texture = dwarf_texture
		_player_sprite.region_enabled = true
		_player_sprite.region_rect = Rect2(
			((character_slot % 4) * 3 + 1) * frame.x,
			(character_slot / 4) * 4 * frame.y,
			frame.x, frame.y)
		_player_sprite.scale = Vector2.ONE * (float(TILE_PX) / float(frame.y)) * 0.95
	else:
		var texture := DwarfHoldActorVisuals.resolve_hero_texture(self)
		_player_sprite.texture = texture
		if texture != null:
			_player_sprite.region_enabled = true
			_player_sprite.region_rect = Rect2(Vector2.ZERO, DwarfHoldActorVisuals.HERO_FRAME_SIZE)
			_player_sprite.scale = Vector2.ONE * (float(TILE_PX) / DwarfHoldActorVisuals.HERO_FRAME_SIZE.y) * 1.05
	_player_sprite.z_index = 10
	_player_cell = _spawn_cell
	_player_sprite.position = _cell_center(_player_cell)
	actor_layer.add_child(_player_sprite)
	_player_move_path.clear()
	_player_is_moving = false

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE_PX) + Vector2(TILE_PX, TILE_PX) * 0.5

func _is_walkable(cell: Vector2i) -> bool:
	return int(_grid.get(cell, WALL)) == FLOOR and not _blocked_cells.has(cell)

func _try_step(direction: Vector2i) -> void:
	if _player_is_moving:
		return
	# One tile per step, always - a longer vector would glide the sprite
	# across intermediate cells (and their traps/stairs) unchecked.
	if direction == Vector2i.ZERO or absi(direction.x) > 1 or absi(direction.y) > 1:
		return
	var next_cell := _player_cell + direction
	# Stepping into a monster swings at it instead.
	var creature_index := _creature_index_at_cell(next_cell)
	if creature_index >= 0:
		_attack_creature(creature_index)
		return
	if _pedestals.has(next_cell):
		_loot_pedestal(next_cell)
		return
	if _chests.has(next_cell):
		_loot_chest(next_cell)
		return
	if not _is_walkable(next_cell):
		return
	_player_is_moving = true
	_player_move_target_cell = next_cell
	_player_move_target_position = _cell_center(next_cell)

## A held key walks but never bumps: attacking monsters and looting stay
## deliberate tap (or click) actions, so gliding past a spider is safe.
func _try_held_step(direction: Vector2i) -> bool:
	var next_cell := _player_cell + direction
	if _creature_index_at_cell(next_cell) >= 0 or _pedestals.has(next_cell) or _chests.has(next_cell):
		return false
	if not _is_walkable(next_cell):
		return false
	# Corner rule: no diagonal squeeze between two blocked orthogonals.
	if direction.x != 0 and direction.y != 0:
		if not _is_walkable(_player_cell + Vector2i(direction.x, 0)) or not _is_walkable(_player_cell + Vector2i(0, direction.y)):
			return false
	_player_is_moving = true
	_player_move_target_cell = next_cell
	_player_move_target_position = _cell_center(next_cell)
	return true

func _start_next_dungeon_step() -> void:
	var held := DwarfHoldUiInputHandler.current_move_input_direction()
	if _respawn_move_lock:
		if held != Vector2i.ZERO:
			return
		_respawn_move_lock = false
	if held != Vector2i.ZERO:
		_player_move_path.clear()
		if _try_held_step(held):
			return
		# Blocked diagonals slide along whichever axis is open.
		if held.x != 0 and held.y != 0:
			if _try_held_step(Vector2i(held.x, 0)):
				return
			var _slid := _try_held_step(Vector2i(0, held.y))
		return
	if _player_move_path.is_empty():
		return
	var next_cell := _player_move_path[0]
	if _creature_index_at_cell(next_cell) >= 0:
		_player_move_path.clear()
		_try_step(next_cell - _player_cell)
		return
	if _pedestals.has(next_cell) or _chests.has(next_cell):
		_player_move_path.clear()
		_try_step(next_cell - _player_cell)
		return
	if not _is_walkable(next_cell):
		_player_move_path.clear()
		return
	_player_move_path.pop_front()
	_try_step(next_cell - _player_cell)

func _update_player_movement(delta: float) -> void:
	if _player_sprite == null:
		return
	if not _player_is_moving:
		_start_next_dungeon_step()
		if not _player_is_moving:
			return
	# Spend this frame's travel budget across tile boundaries so held
	# keys read as one continuous glide instead of tap-per-tile. Capped
	# at one tile so a lag spike can't skip the walker across traps.
	var budget := minf(PLAYER_MOVE_SPEED * delta, float(TILE_PX))
	while _player_is_moving and budget > 0.0:
		var remaining := _player_sprite.position.distance_to(_player_move_target_position)
		if remaining > budget:
			_player_sprite.position = _player_sprite.position.move_toward(_player_move_target_position, budget)
			return
		budget -= remaining
		_player_sprite.position = _player_move_target_position
		_player_cell = _player_move_target_cell
		_player_is_moving = false
		var depth_before := _depth
		_on_player_entered_cell(_player_cell)
		# Stairs may have rebuilt the floor (or left the dungeon entirely).
		if _player_sprite == null or _depth != depth_before or _exiting_dungeon:
			return
		_start_next_dungeon_step()

func _on_player_entered_cell(cell: Vector2i) -> void:
	if cell == _entrance_cell:
		# The stairs up: out of the dungeon from the first floor,
		# back toward daylight from anywhere deeper.
		if _depth <= 1:
			_leave_dungeon()
		else:
			_travel_to_depth(_depth - 1)
		return
	if cell == _down_stairs_cell:
		_travel_to_depth(_depth + 1)
		return
	var plate := _spike_plates.get(cell, {}) as Dictionary
	if not plate.is_empty() and not bool(plate.get("triggered", false)):
		plate["triggered"] = true
		plate["state"] = 1
		plate["timer"] = 0.0
		_set_status("Click! A pressure plate sinks underfoot…", Color(0.95, 0.75, 0.45, 1.0))

func _on_panel_gui_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if wheel != null and wheel.pressed:
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_level = clampf(_zoom_level + 0.2, 1.2, 4.5)
			return
		if wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_level = clampf(_zoom_level - 0.2, 1.2, 4.5)
			return
		if wheel.button_index == MOUSE_BUTTON_LEFT:
			var cell := _cell_at_panel_position(wheel.position)
			# Mid-glide the walker belongs to the arriving tile, so paths
			# start there - never from the departed cell.
			var path_start := _player_move_target_cell if _player_is_moving else _player_cell
			var creature_index := _creature_index_at_cell(cell)
			if creature_index >= 0:
				if _is_adjacent_to_player(cell):
					_attack_creature(creature_index)
				else:
					_player_move_path = _find_path(path_start, cell)
				return
			if _pedestals.has(cell) and _is_adjacent_to_player(cell):
				_loot_pedestal(cell)
				return
			if _chests.has(cell) and _is_adjacent_to_player(cell):
				_loot_chest(cell)
				return
			_player_move_path = _find_path(path_start, cell)

func _is_adjacent_to_player(cell: Vector2i) -> bool:
	var delta := cell - _player_cell
	return absi(delta.x) <= 1 and absi(delta.y) <= 1

func _cell_at_panel_position(panel_position: Vector2) -> Vector2i:
	var local := (panel_position - floor_layer.position) / _zoom_level
	return Vector2i(floori(local.x / float(TILE_PX)), floori(local.y / float(TILE_PX)))

func _find_path(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	var target_blocked := _pedestals.has(to_cell) or _chests.has(to_cell)
	if not _is_walkable(to_cell) and not target_blocked:
		return empty
	var frontier: Array[Vector2i] = [from_cell]
	var came_from: Dictionary = {from_cell: from_cell}
	var visited := 0
	while not frontier.is_empty() and visited < 5000:
		var current := frontier.pop_front() as Vector2i
		visited += 1
		if current == to_cell:
			break
		for direction: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbor := current + direction
			if came_from.has(neighbor):
				continue
			if neighbor == to_cell and target_blocked:
				came_from[neighbor] = current
				frontier.append(neighbor)
				continue
			if not _is_walkable(neighbor):
				continue
			came_from[neighbor] = current
			frontier.append(neighbor)
	if not came_from.has(to_cell):
		return empty
	var path: Array[Vector2i] = []
	var cursor := to_cell
	while cursor != from_cell:
		path.push_front(cursor)
		cursor = came_from[cursor] as Vector2i
	return path

func _update_view_transform() -> void:
	if _player_sprite == null:
		return
	var panel_size := dungeon_panel.size
	var target := panel_size * 0.5 - _player_sprite.position * _zoom_level
	for layer_variant: Variant in [floor_layer, decor_layer, trap_layer, actor_layer]:
		var layer := layer_variant as Node2D
		layer.scale = Vector2.ONE * _zoom_level
		layer.position = target

## --- Trap behavior -----------------------------------------------------------

func _update_fire_traps(delta: float) -> void:
	for trap: Dictionary in _fire_traps:
		var sprite := trap.get("sprite") as Sprite2D
		if sprite == null:
			continue
		var timer := float(trap.get("timer", 0.0)) - delta
		if bool(trap.get("active", false)):
			var elapsed := float(trap.get("elapsed", 0.0)) + delta
			trap["elapsed"] = elapsed
			var frame := int(elapsed / FIRE_FRAME_TIME)
			if frame >= FIRE_FRAME_COUNT:
				trap["active"] = false
				trap["timer"] = _rng.randf_range(1.4, 3.2)
				sprite.region_rect = Rect2(0, 0, 80, 64)
			else:
				sprite.region_rect = Rect2(0, frame * 64, 80, 64)
				if frame >= 2 and frame <= 6:
					var origin := trap.get("origin", Vector2i.ZERO) as Vector2i
					if Rect2i(origin, FIRE_BLOCK_CELLS).has_point(_player_cell):
						_apply_trap_damage("fire_%s" % origin, 2, "the fire jets")
		else:
			trap["timer"] = timer
			if timer <= 0.0:
				trap["active"] = true
				trap["elapsed"] = 0.0

func _update_saw_traps(delta: float) -> void:
	for trap: Dictionary in _saw_traps:
		var sprite := trap.get("sprite") as Sprite2D
		var cells := trap.get("cells", []) as Array
		if sprite == null or cells.size() < 2:
			continue
		var anim_time := float(trap.get("anim_time", 0.0)) + delta
		trap["anim_time"] = anim_time
		var frame := int(anim_time / SAW_FRAME_TIME) % SAW_FRAME_COUNT
		sprite.region_rect = Rect2(frame * 32, 192, 32, 32)
		var progress := float(trap.get("progress", 0.0))
		var direction := int(trap.get("direction", 1))
		progress += direction * (SAW_SPEED / float(TILE_PX)) * delta
		if progress >= float(cells.size() - 1):
			progress = float(cells.size() - 1)
			direction = -1
		elif progress <= 0.0:
			progress = 0.0
			direction = 1
		trap["progress"] = progress
		trap["direction"] = direction
		var index := clampi(int(round(progress)), 0, cells.size() - 1)
		var lower := clampi(floori(progress), 0, cells.size() - 1)
		var upper := clampi(lower + 1, 0, cells.size() - 1)
		var blend := progress - float(lower)
		sprite.position = _cell_center(cells[lower] as Vector2i).lerp(_cell_center(cells[upper] as Vector2i), blend)
		if (cells[index] as Vector2i) == _player_cell:
			_apply_trap_damage("saw_%s" % str(cells[0]), 3, "a whirling saw blade")

func _update_spike_plates(delta: float) -> void:
	for cell_variant: Variant in _spike_plates.keys():
		var plate := _spike_plates[cell_variant] as Dictionary
		if not bool(plate.get("triggered", false)):
			continue
		var sprite := plate.get("sprite") as Sprite2D
		if sprite == null:
			continue
		plate["timer"] = float(plate.get("timer", 0.0)) + delta
		if float(plate.get("timer", 0.0)) >= PLATE_FRAME_TIME:
			plate["timer"] = 0.0
			var state := int(plate.get("state", 0)) + 1
			if state >= PLATE_STATE_ROWS.size():
				state = 0
				plate["triggered"] = false
			plate["state"] = state
			sprite.region_rect = Rect2(16, PLATE_STATE_ROWS[state] * TILE_PX, 16, 32)
			if state == 4 and (cell_variant as Vector2i) == _player_cell:
				_apply_trap_damage("plate_%s" % cell_variant, 3, "springing floor spikes")

func _update_spike_pits(delta: float) -> void:
	for pit: Dictionary in _spike_pits:
		var sprite := pit.get("sprite") as Sprite2D
		if sprite == null:
			continue
		var anim_time := float(pit.get("anim_time", 0.0)) + delta
		pit["anim_time"] = anim_time
		var sequence_index := int(anim_time / SPIKE_PIT_FRAME_TIME) % SPIKE_PIT_SEQUENCE.size()
		var frame := SPIKE_PIT_SEQUENCE[sequence_index]
		sprite.region_rect = Rect2(0, frame * 48, 48, 48)
		if frame >= 4:
			var origin := pit.get("origin", Vector2i.ZERO) as Vector2i
			if Rect2i(origin, Vector2i(3, 3)).has_point(_player_cell):
				_apply_trap_damage("pit_%s" % origin, 2, "the spike pit")

func _update_chests(delta: float) -> void:
	for cell_variant: Variant in _chests.keys():
		var chest := _chests[cell_variant] as Dictionary
		if not bool(chest.get("animating", false)):
			continue
		var sprite := chest.get("sprite") as Sprite2D
		if sprite == null:
			continue
		var anim_time := float(chest.get("anim_time", 0.0)) + delta
		chest["anim_time"] = anim_time
		var state := mini(int(anim_time / CHEST_FRAME_TIME), CHEST_STATE_COUNT - 1)
		sprite.region_rect = Rect2(96, state * 48 + 16, 32, 32)
		if state >= CHEST_STATE_COUNT - 1:
			chest["animating"] = false

func _decay_trap_damage_timers(delta: float) -> void:
	for key_variant: Variant in _trap_damage_timers.keys():
		var remaining := float(_trap_damage_timers[key_variant]) - delta
		if remaining <= 0.0:
			_trap_damage_timers.erase(key_variant)
		else:
			_trap_damage_timers[key_variant] = remaining

func _apply_trap_damage(source_key: String, amount: int, source_name: String) -> void:
	if _trap_damage_timers.has(source_key):
		return
	_trap_damage_timers[source_key] = TRAP_DAMAGE_COOLDOWN
	_damage_player(amount, source_name)

func _damage_player(amount: int, source_name: String) -> void:
	if _player_sprite == null:
		return
	_player_hp = maxf(_player_hp - float(amount), 0.0)
	_update_hp_label()
	_flash_sprite(_player_sprite, Color(1.0, 0.35, 0.35, 1.0))
	_spawn_floating_text("-%d" % amount, _player_sprite.position, Color(1.0, 0.4, 0.4, 1.0))
	if _player_hp <= 0.0:
		_handle_player_death(source_name)

## Death is final: no crawling back to the entrance. Half the purse stays
## lost in the dark, the grave goes into the world chronicle, and the
## game-over screen takes over.
func _handle_player_death(source_name: String) -> void:
	if _game_over != null and is_instance_valid(_game_over):
		return
	_player_hp = 0.0
	var lost_coins := _player_coins / 2
	if lost_coins > 0:
		_player_coins -= lost_coins
		_update_coins_label()
		_spawn_floating_text("-%d coins" % lost_coins, _player_sprite.position, Color(0.95, 0.8, 0.4, 1.0))
	_save_player_inventory()
	_update_hp_label()
	_player_move_path.clear()
	_player_is_moving = false
	_record_death_and_show_game_over(source_name)

## The dungeon has no clock of its own: the death date reads the shared
## session clock and world chronology instead, then the death is written
## into the persistent chronicle register like a beast kill.
func _record_death_and_show_game_over(source_name: String) -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	var player_name := "A wanderer"
	if game_session.has_method("get_player_character"):
		var character: Dictionary = game_session.call("get_player_character")
		var character_name := String(character.get("name", "")).strip_edges()
		if not character_name.is_empty():
			player_name = character_name
	var game_day := 1
	var clock_variant: Variant = settings.get("game_clock")
	if clock_variant is Dictionary:
		game_day = maxi(1, int((clock_variant as Dictionary).get("day", 1)))
	var start_year := 250
	var chronology_variant: Variant = settings.get("chronology")
	if chronology_variant is Dictionary:
		start_year = int((chronology_variant as Dictionary).get("year", 250))
	var place := _dungeon_name if not _dungeon_name.is_empty() else "a forgotten dungeon"
	var death_year := GameCalendar.year_for_day(game_day - 1, start_year)
	WorldChronicleService.record_player_death(settings, player_name, place, death_year, source_name)
	if game_session.has_method("set_world_settings"):
		game_session.call("set_world_settings", settings)
	if _escape_menu != null and _escape_menu.is_open():
		_escape_menu.close()
	_game_over = GameOverScreen.new()
	_game_over.character_name = player_name
	_game_over.place_name = place
	_game_over.date_line = GameCalendar.date_text(game_day - 1, start_year)
	_game_over.cause_name = source_name
	add_child(_game_over)

## --- Loot --------------------------------------------------------------------

func _loot_pedestal(cell: Vector2i) -> void:
	var pedestal := _pedestals.get(cell, {}) as Dictionary
	if pedestal.is_empty() or bool(pedestal.get("looted", false)):
		return
	pedestal["looted"] = true
	_record_looted("pedestals", cell)
	var item := String(pedestal.get("item", ""))
	_add_to_inventory(item, 1)
	var icon := pedestal.get("icon") as Sprite2D
	if icon != null:
		icon.queue_free()
		pedestal["icon"] = null
	_spawn_floating_text("+1 %s" % item, _cell_center(cell), Color(0.95, 0.9, 0.6, 1.0))
	_set_status("You lift the %s from its pedestal." % item, Color(0.85, 0.95, 0.7, 1.0))
	_save_player_inventory()

func _loot_chest(cell: Vector2i) -> void:
	var chest := _chests.get(cell, {}) as Dictionary
	if chest.is_empty() or bool(chest.get("opened", false)):
		return
	chest["opened"] = true
	_record_looted("chests", cell)
	chest["animating"] = true
	chest["anim_time"] = 0.0
	var loot_parts: PackedStringArray = []
	for entry: Dictionary in CHEST_LOOT_TABLE:
		if _rng.randi_range(1, 100) > int(entry.get("chance", 100)):
			continue
		var amount := _rng.randi_range(int(entry.get("min", 1)), int(entry.get("max", 1)))
		if amount <= 0:
			continue
		var item := String(entry.get("item", ""))
		_add_to_inventory(item, amount)
		loot_parts.append("%d %s" % [amount, item])
	_spawn_floating_text("Treasure!", _cell_center(cell), Color(0.95, 0.9, 0.6, 1.0))
	if loot_parts.is_empty():
		_set_status("The chest is empty — long since picked over.", Color(0.8, 0.8, 0.8, 1.0))
	else:
		_set_status("Chest opened — " + ", ".join(loot_parts), Color(0.85, 0.95, 0.7, 1.0))
	_save_player_inventory()

func _add_to_inventory(item_name: String, amount: int) -> void:
	if item_name.is_empty() or amount <= 0:
		return
	# Coins skip the backpack and land straight in the purse.
	if item_name == "Copper Coins":
		_player_coins += amount
		_update_coins_label()
		return
	_player_inventory[item_name] = int(_player_inventory.get(item_name, 0)) + amount

## --- UI ----------------------------------------------------------------------

func _update_hp_label() -> void:
	hp_label.text = "❤ %d / %d" % [int(ceil(_player_hp)), int(_player_max_hp)]
	if _player_hp <= _player_max_hp * 0.3:
		hp_label.modulate = Color(1.0, 0.5, 0.5, 1.0)
	else:
		hp_label.modulate = Color(0.95, 0.87, 0.87, 1.0)

func _update_coins_label() -> void:
	coins_label.text = "🪙 %d coins" % _player_coins

func _set_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.modulate = color

func _flash_sprite(sprite: Sprite2D, flash_color: Color) -> void:
	sprite.modulate = flash_color
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)

func _spawn_floating_text(text: String, world_position: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.1, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	label.position = world_position + Vector2(-10.0, -18.0)
	label.z_index = 30
	trap_layer.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0, -14.0), 1.1)
	tween.tween_property(label, "modulate", Color(color.r, color.g, color.b, 0.0), 1.1)
	tween.chain().tween_callback(label.queue_free)

func _leave_dungeon() -> void:
	# The movement loop must not keep stepping a scene that is leaving.
	_exiting_dungeon = true
	_save_player_inventory()
	SceneCacheService.request_change(self, OVERWORLD_SCENE_PATH)

func _seeded_shuffle(values: Array) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap: Variant = values[i]
		values[i] = values[j]
		values[j] = swap
