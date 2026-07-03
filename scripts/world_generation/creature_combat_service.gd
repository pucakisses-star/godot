class_name CreatureCombatService
extends RefCounted

## Creature movement and animation helpers shared by the dwarfhold and
## the dungeon; the two scenes carried identical copies before this.

## The greedy chase step: the cardinal move that closes the most
## distance, or ZERO when every step is blocked or worse.
static func step_toward(from_cell: Vector2i, target_cell: Vector2i, can_step_to: Callable) -> Vector2i:
	var best := Vector2i.ZERO
	var best_distance := Vector2(from_cell).distance_squared_to(Vector2(target_cell))
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var next := from_cell + direction
		if not bool(can_step_to.call(next)):
			continue
		var distance := Vector2(next).distance_squared_to(Vector2(target_cell))
		if distance < best_distance:
			best_distance = distance
			best = direction
	return best

static func direction_between_cells(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	var delta := to_cell - from_cell
	if absi(delta.x) >= absi(delta.y):
		return Vector2i.RIGHT if delta.x >= 0 else Vector2i.LEFT
	return Vector2i.DOWN if delta.y >= 0 else Vector2i.UP

static func set_creature_anim(state: Dictionary, anim_name: String) -> void:
	if String(state.get("anim", "")) == anim_name:
		return
	state["anim"] = anim_name
	state["anim_time"] = 0.0

static func animate_creature(state: Dictionary, sprite: Sprite2D, def: Dictionary) -> void:
	var facing_dir := state.get("facing_dir", Vector2i(0, 1)) as Vector2i
	var facing_row := 0
	if facing_dir == Vector2i.RIGHT:
		facing_row = 1
	elif facing_dir == Vector2i.LEFT:
		facing_row = 2
	elif facing_dir == Vector2i.UP:
		facing_row = 3
	UndergroundCreatureService.update_creature_frame(
		sprite, int(def.get("slot", 0)),
		String(state.get("anim", "idle")),
		float(state.get("anim_time", 0.0)),
		facing_row
	)
