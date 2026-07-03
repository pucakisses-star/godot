extends RefCounted
class_name DwarfHoldTavernService

const TAVERN_SPRITE_COLUMNS := 12
const TAVERN_SPRITE_ROWS := 8
const TAVERN_CHARACTER_COLUMNS := 3
const TAVERN_CHARACTER_ROWS := 4
const TAVERN_CHARACTER_SLOT_COUNT := 8
const TAVERN_FRAME_ADVANCE_SECONDS := 0.22
const TAVERN_WANDER_COOLDOWN_RANGE := Vector2(0.35, 1.25)

static func spawn_tavern_characters(
	actor_layer: Node2D,
	city_layer: TileMapLayer,
	npc_states: Array[Dictionary],
	rng: RandomNumberGenerator,
	walkable_cells: Array[Vector2i],
	tavern_character_texture: Texture2D,
	pending_player_spawn_cell: Vector2i,
	is_walkable_cell: Callable,
	cell_center_position: Callable,
	create_player_sprite: Callable,
	actor_sprite_to_cell: Callable,
	tavern_npc_count: int,
	tavern_npc_speed_range: Vector2,
	placeholder_actor_texture: Texture2D,
	tile_size: Vector2i
) -> Dictionary:
	for child: Node in actor_layer.get_children():
		child.queue_free()
	npc_states.clear()

	if walkable_cells.is_empty() or tavern_character_texture == null:
		return {"player_sprite": null, "player_cell": Vector2i(2147483647, 2147483647)}

	var player_cell: Vector2i
	if pending_player_spawn_cell.x != 2147483647 and bool(is_walkable_cell.call(pending_player_spawn_cell)):
		player_cell = pending_player_spawn_cell
	else:
		player_cell = walkable_cells[rng.randi_range(0, walkable_cells.size() - 1)]

	var player_sprite: Sprite2D = create_player_sprite.call()
	actor_sprite_to_cell.call(player_sprite, player_cell)
	actor_layer.add_child(player_sprite)

	for i in tavern_npc_count:
		var spawn_cell := walkable_cells[rng.randi_range(0, walkable_cells.size() - 1)]
		for _attempt in 12:
			if bool(is_walkable_cell.call(spawn_cell)):
				break
			spawn_cell = walkable_cells[rng.randi_range(0, walkable_cells.size() - 1)]
		if not bool(is_walkable_cell.call(spawn_cell)):
			continue
		var npc_texture := tavern_character_texture if tavern_character_texture != null else placeholder_actor_texture
		var npc_sprite := create_tavern_character_sprite(npc_texture, (i + 1) % TAVERN_CHARACTER_SLOT_COUNT, tile_size)
		actor_sprite_to_cell.call(npc_sprite, spawn_cell)
		actor_layer.add_child(npc_sprite)
		npc_states.append({
			"sprite": npc_sprite,
			"slot": (i + 1) % TAVERN_CHARACTER_SLOT_COUNT,
			"cell": spawn_cell,
			"facing_row": 0,
			"frame": 1,
			"frame_elapsed": 0.0,
			"speed": rng.randf_range(tavern_npc_speed_range.x, tavern_npc_speed_range.y),
			"cooldown": rng.randf_range(TAVERN_WANDER_COOLDOWN_RANGE.x, TAVERN_WANDER_COOLDOWN_RANGE.y),
			"direction": Vector2.ZERO,
			"target": cell_center_position.call(spawn_cell)
		})

	return {"player_sprite": player_sprite, "player_cell": player_cell}

static func update_npc_movement(
	delta: float,
	npc_states: Array[Dictionary],
	city_layer: TileMapLayer,
	rng: RandomNumberGenerator,
	tavern_npc_speed_range: Vector2,
	tile_size: Vector2i,
	is_npc_walkable_callable: Callable,
	cell_center_position: Callable
) -> void:
	for state: Dictionary in npc_states:
		var sprite := state.get("sprite") as Sprite2D
		if sprite == null:
			continue
		var cooldown := float(state.get("cooldown", 0.0)) - delta
		var direction := state.get("direction", Vector2.ZERO) as Vector2
		var target := state.get("target", sprite.position) as Vector2
		if direction.length_squared() <= 0.0 and cooldown <= 0.0:
			for _attempt in 6:
				var candidate := pick_random_wander_direction(rng)
				var candidate_cell := city_layer.local_to_map(sprite.position + candidate * float(tile_size.x))
				if bool(is_npc_walkable_callable.call(candidate_cell)):
					direction = candidate
					target = cell_center_position.call(candidate_cell)
					state["facing_row"] = facing_row_from_direction(candidate)
					break
			cooldown = rng.randf_range(TAVERN_WANDER_COOLDOWN_RANGE.x, TAVERN_WANDER_COOLDOWN_RANGE.y)

		if direction.length_squared() > 0.0:
			var speed := float(state.get("speed", tavern_npc_speed_range.x))
			sprite.position = sprite.position.move_toward(target, speed * delta)
			if sprite.position.distance_to(target) <= 0.5:
				sprite.position = target
				state["cell"] = city_layer.local_to_map(target)
				direction = Vector2.ZERO

		var frame_elapsed := float(state.get("frame_elapsed", 0.0)) + delta
		var frame := int(state.get("frame", 1))
		if direction.length_squared() > 0.0 and frame_elapsed >= TAVERN_FRAME_ADVANCE_SECONDS:
			frame_elapsed = 0.0
			frame = (frame + 1) % TAVERN_CHARACTER_COLUMNS
		elif direction.length_squared() <= 0.0:
			frame = 1
			frame_elapsed = 0.0

		var facing_row := int(state.get("facing_row", 0))
		var slot := int(state.get("slot", 1))
		update_character_frame(sprite, slot, frame, facing_row)

		state["cooldown"] = cooldown
		state["direction"] = direction
		state["target"] = target
		state["frame"] = frame
		state["frame_elapsed"] = frame_elapsed

static func pick_random_wander_direction(rng: RandomNumberGenerator) -> Vector2:
	return DwarfHoldGenerationRules.pick_random_wander_direction(rng)

static func create_placeholder_tavern_character_texture() -> Texture2D:
	return DwarfHoldActorVisuals.create_placeholder_tavern_character_texture(
		TAVERN_SPRITE_COLUMNS,
		TAVERN_SPRITE_ROWS,
		TAVERN_CHARACTER_ROWS,
		TAVERN_CHARACTER_COLUMNS,
		TAVERN_CHARACTER_SLOT_COUNT
	)

static func is_npc_walkable_cell(cell: Vector2i, is_walkable_cell: Callable, decor_layer: TileMapLayer, stone_atlas_coords: Vector2i) -> bool:
	if not bool(is_walkable_cell.call(cell)):
		return false
	if decor_layer.get_cell_source_id(cell) < 0:
		return true
	return decor_layer.get_cell_atlas_coords(cell) != stone_atlas_coords

static func facing_row_from_direction(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y):
		return 2 if direction.x < 0.0 else 1
	return 3 if direction.y < 0.0 else 0

static func update_character_frame(sprite: Sprite2D, character_slot: int, frame_column: int, facing_row: int) -> void:
	if not sprite.region_enabled:
		return
	if sprite.texture == null:
		return
	var source_size := sprite.texture.get_size()
	var frame_width := int(source_size.x / TAVERN_SPRITE_COLUMNS)
	var frame_height := int(source_size.y / TAVERN_SPRITE_ROWS)
	if frame_width <= 0 or frame_height <= 0:
		return
	var slot_column := character_slot % 4
	var slot_row := character_slot / 4
	var atlas_column := slot_column * TAVERN_CHARACTER_COLUMNS + (frame_column % TAVERN_CHARACTER_COLUMNS)
	var atlas_row := slot_row * TAVERN_CHARACTER_ROWS + (facing_row % TAVERN_CHARACTER_ROWS)
	sprite.region_rect = Rect2(atlas_column * frame_width, atlas_row * frame_height, frame_width, frame_height)

static func is_cell_occupied_by_npc(cell: Vector2i, npc_states: Array[Dictionary]) -> bool:
	for state: Dictionary in npc_states:
		var npc_cell := state.get("cell", Vector2i(2147483647, 2147483647)) as Vector2i
		if npc_cell == cell:
			return true
	return false

static func create_tavern_character_sprite(placeholder_actor_texture: Texture2D, character_slot: int, tile_size: Vector2i) -> Sprite2D:
	return DwarfHoldActorVisuals.create_tavern_character_sprite(placeholder_actor_texture, character_slot, tile_size)

static func create_player_character_sprite(shattered_player_texture: Texture2D, tile_size: Vector2i, create_tavern_sprite_callable: Callable) -> Sprite2D:
	return DwarfHoldActorVisuals.create_player_character_sprite(
		shattered_player_texture,
		tile_size,
		create_tavern_sprite_callable
	)

static func create_placeholder_actor_texture() -> Texture2D:
	return DwarfHoldActorVisuals.create_placeholder_actor_texture()

static func placeholder_actor_color(character_slot: int) -> Color:
	return DwarfHoldActorVisuals.placeholder_actor_color(character_slot)
