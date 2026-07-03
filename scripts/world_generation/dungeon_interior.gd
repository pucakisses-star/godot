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

const DUNGEON_SCENE_SEED_KEY := "dungeon_scene_seed"
const DUNGEON_SCENE_NAME_KEY := "dungeon_scene_name"

const PLAYER_MAX_HP := 20.0
const PLAYER_MOVE_SPEED := 150.0
const TRAP_DAMAGE_COOLDOWN := 0.9

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

var _player_sprite: Sprite2D
var _player_cell := Vector2i.ZERO
var _player_hp := PLAYER_MAX_HP
var _player_move_path: Array[Vector2i] = []
var _player_is_moving := false
var _player_move_target_cell := Vector2i.ZERO
var _player_move_target_position := Vector2.ZERO
var _player_inventory: Dictionary = {}
var _player_coins := 0
var _trap_damage_timers: Dictionary = {}

var _zoom_level := 2.4
var _escape_menu: EscapeMenu

var _fire_traps: Array[Dictionary] = []
var _saw_traps: Array[Dictionary] = []
var _spike_plates: Dictionary = {}
var _spike_pits: Array[Dictionary] = []
var _pedestals: Dictionary = {}
var _chests: Dictionary = {}

func _ready() -> void:
	_load_scene_context()
	_load_player_inventory()
	_configure_tile_layer()
	leave_button.pressed.connect(_leave_dungeon)
	dungeon_panel.gui_input.connect(_on_panel_gui_input)
	_escape_menu = EscapeMenu.new()
	_escape_menu.show_return_to_map = true
	add_child(_escape_menu)
	_generate_dungeon()
	_update_hp_label()
	_update_coins_label()

func _process(delta: float) -> void:
	_update_player_movement(delta)
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

func _load_scene_context() -> void:
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
	_rng.seed = hash(seed_text)
	dungeon_name_label.text = _dungeon_name

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

func _configure_tile_layer() -> void:
	var atlas := TileSetAtlasSource.new()
	atlas.texture = WALLS_FLOOR_TEXTURE
	atlas.texture_region_size = Vector2i(TILE_PX, TILE_PX)
	var used_tiles: Array[Vector2i] = [FLOOR_TILE, WALL_FACE_TILE, WALL_FACE_ALT_TILE, WALL_DARK_TILE, STAIRS_TILE]
	used_tiles.append_array(DEBRIS_TILES)
	for coords: Vector2i in used_tiles:
		if not atlas.has_tile(coords):
			atlas.create_tile(coords)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_PX, TILE_PX)
	tile_set.add_source(atlas, 0)
	floor_layer.tile_set = tile_set
	decor_layer.tile_set = tile_set

## --- Generation -------------------------------------------------------------

func _generate_dungeon() -> void:
	_grid.clear()
	_rooms.clear()
	_blocked_cells.clear()
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
	_place_traps()
	_spawn_player()
	_set_status("You descend into %s… watch the floor." % _dungeon_name, Color(0.85, 0.8, 0.95, 1.0))

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
	floor_layer.clear()
	decor_layer.clear()
	var floor_cells: Array[Vector2i] = []
	for cell_variant: Variant in _grid.keys():
		if int(_grid[cell_variant]) == FLOOR:
			floor_cells.append(cell_variant as Vector2i)
	var wall_cells: Dictionary = {}
	for cell: Vector2i in floor_cells:
		floor_layer.set_cell(cell, 0, FLOOR_TILE)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var neighbor := cell + Vector2i(dx, dy)
				if int(_grid.get(neighbor, WALL)) != FLOOR:
					wall_cells[neighbor] = true
	for wall_variant: Variant in wall_cells.keys():
		var wall_cell := wall_variant as Vector2i
		# South-facing walls show their brick face; the rest read as dark mass.
		if int(_grid.get(wall_cell + Vector2i(0, 1), WALL)) == FLOOR:
			floor_layer.set_cell(wall_cell, 0, WALL_FACE_TILE if (wall_cell.x + wall_cell.y) % 2 == 0 else WALL_FACE_ALT_TILE)
		else:
			floor_layer.set_cell(wall_cell, 0, WALL_DARK_TILE)
	floor_layer.set_cell(_entrance_cell, 0, STAIRS_TILE)
	# Rubble keeps the halls from feeling freshly swept.
	for cell: Vector2i in floor_cells:
		if cell != _entrance_cell and _rng.randf() < 0.045:
			decor_layer.set_cell(cell, 0, DEBRIS_TILES[_rng.randi_range(0, DEBRIS_TILES.size() - 1)])

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
		if placed >= 3:
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
		if placed >= 2:
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
		if decor_layer.get_cell_source_id(cell) >= 0:
			continue
		candidates.append(cell)
	candidates.sort()
	_seeded_shuffle(candidates)
	var target := clampi(candidates.size() / 24, 4, 10)
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
	var pedestal_count := _rng.randi_range(2, 4)
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
		_blocked_cells[cell] = true
	# Chests in one or two of the other far rooms.
	var chest_count := _rng.randi_range(1, 2)
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

## --- Player ------------------------------------------------------------------

func _spawn_player() -> void:
	if _player_sprite != null:
		_player_sprite.queue_free()
	_player_sprite = Sprite2D.new()
	var texture := load("res://resources/images/shattered_ui/warrior.png") as Texture2D
	_player_sprite.texture = texture
	if texture != null:
		var longest := maxf(texture.get_size().x, texture.get_size().y)
		_player_sprite.scale = Vector2.ONE * (float(TILE_PX) / maxf(longest, 1.0)) * 1.25
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
	var next_cell := _player_cell + direction
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

func _update_player_movement(delta: float) -> void:
	if _player_sprite == null:
		return
	if _player_is_moving:
		_player_sprite.position = _player_sprite.position.move_toward(_player_move_target_position, PLAYER_MOVE_SPEED * delta)
		if _player_sprite.position.distance_to(_player_move_target_position) <= 0.4:
			_player_sprite.position = _player_move_target_position
			_player_cell = _player_move_target_cell
			_player_is_moving = false
			_on_player_entered_cell(_player_cell)
	elif not _player_move_path.is_empty():
		var next_cell := _player_move_path[0]
		if _pedestals.has(next_cell) or _chests.has(next_cell):
			_player_move_path.clear()
			_try_step(next_cell - _player_cell)
			return
		if not _is_walkable(next_cell):
			_player_move_path.clear()
			return
		_player_move_path.pop_front()
		_try_step(next_cell - _player_cell)

func _on_player_entered_cell(cell: Vector2i) -> void:
	if cell == _entrance_cell:
		_leave_dungeon()
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
			if _pedestals.has(cell) and _is_adjacent_to_player(cell):
				_loot_pedestal(cell)
				return
			if _chests.has(cell) and _is_adjacent_to_player(cell):
				_loot_chest(cell)
				return
			_player_move_path = _find_path(_player_cell, cell)

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

func _handle_player_death(source_name: String) -> void:
	_player_hp = PLAYER_MAX_HP
	_update_hp_label()
	_player_move_path.clear()
	_player_is_moving = false
	_player_cell = _spawn_cell
	_player_sprite.position = _cell_center(_player_cell)
	_set_status("Felled by %s — you crawl back to the entrance" % source_name, Color(0.95, 0.5, 0.5, 1.0))

## --- Loot --------------------------------------------------------------------

func _loot_pedestal(cell: Vector2i) -> void:
	var pedestal := _pedestals.get(cell, {}) as Dictionary
	if pedestal.is_empty() or bool(pedestal.get("looted", false)):
		return
	pedestal["looted"] = true
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
	hp_label.text = "❤ %d / %d" % [int(ceil(_player_hp)), int(PLAYER_MAX_HP)]
	if _player_hp <= PLAYER_MAX_HP * 0.3:
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
	_save_player_inventory()
	get_tree().change_scene_to_file(OVERWORLD_SCENE_PATH)

func _seeded_shuffle(values: Array) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap: Variant = values[i]
		values[i] = values[j]
		values[j] = swap
