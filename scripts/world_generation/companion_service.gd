extends RefCounted
class_name CompanionService

## The Beast Charm's answer: a loyal sporeling that pads after the
## walker and throws itself at whatever threatens them. It cannot die -
## beaten low, it burrows and re-emerges at its master's heel.

const FOLLOW_DISTANCE := 2
const LEASH_DISTANCE := 12
const HUNT_RANGE := 8
const STEP_SECONDS := 0.3
const ATTACK_SECONDS := 1.6

static func spawn(charm: Dictionary, creature_texture: Texture2D, player_cell: Vector2i, actor_layer: Node2D, cell_center_position: Callable, tile_size: Vector2i) -> Dictionary:
	if charm.is_empty():
		return {}
	var sprite: Sprite2D = UndergroundCreatureService.create_creature_sprite(creature_texture, 0, tile_size)
	sprite.position = cell_center_position.call(player_cell + Vector2i(1, 0))
	sprite.z_index = 11
	sprite.modulate = Color(0.85, 1.0, 0.85, 1.0)
	actor_layer.add_child(sprite)
	return {
		"cell": player_cell + Vector2i(1, 0),
		"sprite": sprite,
		"attack": maxi(1, int(charm.get("summon_attack", 2))),
		"step_timer": 0.0,
		"attack_timer": 0.0,
		"anim": "idle",
		"anim_time": 0.0,
		"facing_dir": Vector2i(0, 1)
	}

static func despawn(companion: Dictionary) -> void:
	var sprite := companion.get("sprite") as Sprite2D
	if sprite != null and is_instance_valid(sprite):
		sprite.queue_free()

## One tick: hunt the nearest hostile in range, else heel. on_strike is
## called with the index of the hostile state struck this frame.
static func update(
	delta: float,
	companion: Dictionary,
	player_cell: Vector2i,
	hostiles: Array[Dictionary],
	is_walkable: Callable,
	cell_center_position: Callable,
	on_strike: Callable
) -> void:
	if companion.is_empty():
		return
	var sprite := companion.get("sprite") as Sprite2D
	if sprite == null or not is_instance_valid(sprite):
		return
	var cell := companion.get("cell", player_cell) as Vector2i
	companion["step_timer"] = maxf(float(companion.get("step_timer", 0.0)) - delta, 0.0)
	companion["attack_timer"] = maxf(float(companion.get("attack_timer", 0.0)) - delta, 0.0)
	# Far from its master, it simply burrows home.
	if maxi(absi(cell.x - player_cell.x), absi(cell.y - player_cell.y)) > LEASH_DISTANCE:
		cell = player_cell + Vector2i(1, 0)
		companion["cell"] = cell
		sprite.position = cell_center_position.call(cell)
	# Nearest hostile within hunting range.
	var target_index := -1
	var target_distance := HUNT_RANGE + 1
	for index in hostiles.size():
		var hostile_cell := hostiles[index].get("cell", Vector2i(9999, 9999)) as Vector2i
		var distance := maxi(absi(hostile_cell.x - cell.x), absi(hostile_cell.y - cell.y))
		if distance < target_distance:
			target_distance = distance
			target_index = index
	if target_index >= 0 and target_distance <= 1:
		if float(companion.get("attack_timer", 0.0)) <= 0.0:
			companion["attack_timer"] = ATTACK_SECONDS
			CreatureCombatService.set_creature_anim(companion, "attack")
			on_strike.call(target_index, int(companion.get("attack", 2)))
	elif float(companion.get("step_timer", 0.0)) <= 0.0:
		companion["step_timer"] = STEP_SECONDS
		var goal := player_cell
		if target_index >= 0:
			goal = hostiles[target_index].get("cell", player_cell) as Vector2i
		elif maxi(absi(cell.x - player_cell.x), absi(cell.y - player_cell.y)) <= FOLLOW_DISTANCE:
			goal = cell
		if goal != cell:
			var step: Vector2i = CreatureCombatService.step_toward(cell, goal, is_walkable)
			if step != Vector2i.ZERO:
				companion["cell"] = cell + step
				companion["facing_dir"] = step
				CreatureCombatService.set_creature_anim(companion, "walk")
	var target_position: Vector2 = cell_center_position.call(companion.get("cell", cell) as Vector2i)
	sprite.position = sprite.position.move_toward(target_position, 58.0 * delta)
	if sprite.position.distance_to(target_position) < 0.5 and String(companion.get("anim", "")) == "walk":
		CreatureCombatService.set_creature_anim(companion, "idle")
	companion["anim_time"] = float(companion.get("anim_time", 0.0)) + delta
	CreatureCombatService.animate_creature(companion, sprite, UndergroundCreatureService.CREATURE_DEFS[0] as Dictionary)
