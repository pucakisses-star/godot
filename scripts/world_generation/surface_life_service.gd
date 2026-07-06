extends RefCounted
class_name SurfaceLifeService

## Life (and death) in the wilds. Danger is radial - the further from a
## settlement or gate, the darker the land and the meaner what roams it.
## Creatures spawn around a player who leaves the calm ring, chase, and
## bite; travelers walk the roads between settlements and can be talked
## to like anyone else; deep-wild hours carry ambush risk.

const CALM_RADIUS_CELLS := 40.0
const DARK_RADIUS_CELLS := 300.0

const SURFACE_CREATURE_CAP := 6
const CREATURE_CHASE_RANGE := 10
const CREATURE_SPAWN_MIN := 12
const CREATURE_SPAWN_MAX := 20
const CREATURE_DESPAWN_DISTANCE := 44
const CREATURE_SPEED := 44.0
const AMBUSH_DANGER_FLOOR := 0.4
const AMBUSH_CHANCE_PER_HOUR := 0.22

const TRAVELER_CAP := 3
const TRAVELER_STEP_SECONDS := 0.32
const TRAVELER_ROLES := ["Peddler", "Pilgrim", "Courier", "Tinker", "Drover"]

## 0 at a settlement's doorstep, 1 deep in the wilds.
static func danger_for_cell(cell: Vector2i, site_anchors: Array[Vector2i]) -> float:
	var nearest := 999999.0
	for anchor: Vector2i in site_anchors:
		nearest = minf(nearest, Vector2(cell - anchor).length())
	return clampf((nearest - CALM_RADIUS_CELLS) / (DARK_RADIUS_CELLS - CALM_RADIUS_CELLS), 0.0, 1.0)

static func desired_creature_count(danger: float) -> int:
	if danger < 0.2:
		return 0
	return clampi(1 + int(danger * 4.0), 1, SURFACE_CREATURE_CAP)

## Which of the creature roster stalks this ring: mushroom-folk near
## the roads, lizardmen deeper, orcs in the dark.
static func tier_def_index(danger: float, rng: RandomNumberGenerator) -> int:
	if danger < 0.45:
		return rng.randi_range(0, 2)
	if danger < 0.72:
		return rng.randi_range(3, 5)
	return rng.randi_range(6, 7)

static func spawn_creature(states: Array[Dictionary], creature_texture: Texture2D, def_index: int, cell: Vector2i, actor_layer: Node2D, cell_center_position: Callable, tile_size: Vector2i, rng: RandomNumberGenerator) -> void:
	if states.size() >= SURFACE_CREATURE_CAP:
		return
	if def_index < 0 or def_index >= UndergroundCreatureService.CREATURE_DEFS.size():
		return
	var def: Dictionary = UndergroundCreatureService.CREATURE_DEFS[def_index]
	var sprite: Sprite2D = UndergroundCreatureService.create_creature_sprite(creature_texture, int(def.get("slot", 0)), tile_size)
	sprite.position = cell_center_position.call(cell)
	sprite.z_index = 12
	actor_layer.add_child(sprite)
	states.append({
		"def_index": def_index,
		"hp": int(def.get("max_hp", 4)),
		"cell": cell,
		"sprite": sprite,
		"moving": false,
		"dying": false,
		"anim": "idle",
		"wander_timer": rng.randf_range(0.5, 2.0),
		"attack_timer": 0.0,
		"anim_time": rng.randf_range(0.0, 1.0),
		"facing_dir": Vector2i(0, 1)
	})

## Chase-bite-wander AI. on_player_hit(damage) fires when a creature
## lands a blow. Dead creatures are freed and removed here.
static func update_creatures(
	delta: float,
	states: Array[Dictionary],
	player_cell: Vector2i,
	is_walkable: Callable,
	cell_center_position: Callable,
	rng: RandomNumberGenerator,
	on_player_hit: Callable
) -> void:
	for index in range(states.size() - 1, -1, -1):
		var state := states[index]
		var sprite := state.get("sprite") as Sprite2D
		if sprite == null or bool(state.get("dying", false)):
			if sprite != null:
				sprite.queue_free()
			states.remove_at(index)
			continue
		var def: Dictionary = UndergroundCreatureService.CREATURE_DEFS[int(state.get("def_index", 0))]
		var cell := state.get("cell", Vector2i.ZERO) as Vector2i
		var distance := maxi(absi(cell.x - player_cell.x), absi(cell.y - player_cell.y))
		state["attack_timer"] = maxf(float(state.get("attack_timer", 0.0)) - delta, 0.0)
		state["wander_timer"] = maxf(float(state.get("wander_timer", 0.0)) - delta, 0.0)
		var target_position := sprite.position
		if distance <= 1:
			if float(state.get("attack_timer", 0.0)) <= 0.0:
				state["attack_timer"] = 1.4
				CreatureCombatService.set_creature_anim(state, "attack")
				on_player_hit.call(int(def.get("damage", 1)))
		elif distance <= CREATURE_CHASE_RANGE:
			if float(state.get("wander_timer", 0.0)) <= 0.0:
				state["wander_timer"] = 0.28
				var step: Vector2i = CreatureCombatService.step_toward(cell, player_cell, is_walkable)
				if step != Vector2i.ZERO:
					state["cell"] = cell + step
					state["facing_dir"] = step
					CreatureCombatService.set_creature_anim(state, "walk")
		elif float(state.get("wander_timer", 0.0)) <= 0.0:
			state["wander_timer"] = rng.randf_range(1.2, 3.0)
			var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
			var wander := directions[rng.randi_range(0, 3)]
			if bool(is_walkable.call(cell + wander)):
				state["cell"] = cell + wander
				state["facing_dir"] = wander
				CreatureCombatService.set_creature_anim(state, "walk")
		target_position = cell_center_position.call(state.get("cell", cell) as Vector2i)
		sprite.position = sprite.position.move_toward(target_position, CREATURE_SPEED * delta)
		if sprite.position.distance_to(target_position) < 0.5 and String(state.get("anim", "")) == "walk":
			CreatureCombatService.set_creature_anim(state, "idle")
		state["anim_time"] = float(state.get("anim_time", 0.0)) + delta
		CreatureCombatService.animate_creature(state, sprite, def)

static func despawn_far_creatures(states: Array[Dictionary], player_cell: Vector2i) -> void:
	for index in range(states.size() - 1, -1, -1):
		var cell := states[index].get("cell", Vector2i.ZERO) as Vector2i
		if maxi(absi(cell.x - player_cell.x), absi(cell.y - player_cell.y)) <= CREATURE_DESPAWN_DISTANCE:
			continue
		var sprite := states[index].get("sprite") as Sprite2D
		if sprite != null:
			sprite.queue_free()
		states.remove_at(index)

## --- Travelers on the roads ------------------------------------------------

## Spawns a wanderer partway along a road, with a full identity so the
## hover card and dialogue treat them like anyone else. The state is
## flagged "traveler" and carries its road; the scene keeps it out of
## the town scheduler.
static func spawn_traveler(road_path: Array, kind: String, rng: RandomNumberGenerator, actor_layer: Node2D, cell_center_position: Callable, tile_size: Vector2i) -> Dictionary:
	if road_path.size() < 8:
		return {}
	var index := rng.randi_range(2, road_path.size() - 3)
	var role := String(TRAVELER_ROLES[rng.randi_range(0, TRAVELER_ROLES.size() - 1)])
	var identity: Dictionary = NpcIdentityService.generate(rng, role, kind)
	var layers: Dictionary = NpcIdentityService.appearance_for_identity(identity, "human" if kind == "townsfolk" else "dwarf")
	var sprite := Sprite2D.new()
	sprite.texture = DwarfSpriteComposer.compose(layers)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(float(tile_size.x) / 32.0, float(tile_size.y) / 32.0) * 0.9 * float(layers.get("body_scale", 1.0))
	sprite.z_index = 11
	var cell := road_path[index] as Vector2i
	sprite.position = cell_center_position.call(cell)
	actor_layer.add_child(sprite)
	return {
		"traveler": true,
		"road_index": index,
		"road_step": 1 if rng.randf() < 0.5 else -1,
		"road_path": road_path,
		"step_cooldown": 0.0,
		"identity": identity,
		"npc_name": String(identity.get("name", "A traveler")),
		"composed": true,
		"cell": cell,
		"sprite": sprite,
		"role": 0
	}

## Walks travelers along their road; returns indices that finished
## their journey (reached either end) for the scene to retire.
static func update_travelers(delta: float, npc_states: Array[Dictionary], cell_center_position: Callable) -> Array[int]:
	var finished: Array[int] = []
	for index in npc_states.size():
		var state := npc_states[index]
		if not bool(state.get("traveler", false)):
			continue
		var sprite := state.get("sprite") as Sprite2D
		if sprite == null:
			finished.append(index)
			continue
		var path := state.get("road_path", []) as Array
		var cooldown := float(state.get("step_cooldown", 0.0)) - delta
		if cooldown <= 0.0:
			cooldown = TRAVELER_STEP_SECONDS
			var next_index := int(state.get("road_index", 0)) + int(state.get("road_step", 1))
			if next_index <= 0 or next_index >= path.size():
				finished.append(index)
				continue
			state["road_index"] = next_index
			var next_cell := path[next_index] as Vector2i
			sprite.flip_h = next_cell.x < (state.get("cell", next_cell) as Vector2i).x
			state["cell"] = next_cell
		state["step_cooldown"] = cooldown
		var target: Vector2 = cell_center_position.call(state.get("cell", Vector2i.ZERO) as Vector2i)
		sprite.position = sprite.position.move_toward(target, 52.0 * delta)
	return finished
