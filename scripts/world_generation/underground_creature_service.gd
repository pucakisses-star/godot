extends RefCounted
class_name UndergroundCreatureService

## Hostile creatures of the wild underdeep. Pure data + rolls; the scene
## owns sprites and the update loop. Slots index into
## creature_characters.png, repacked from the web game's mob tilesheets
## (Fungi, Lizardmen, Orcs) into the same 12x8 layout as the NPC sheets.
## Danger scales with distance from the hold: min_distance gates when a
## creature enters the spawn pool, so the far dark grows nastier.

const CREATURE_DEFS: Array[Dictionary] = [
	{
		"name": "Sporeling", "slot": 0, "max_hp": 4, "damage": 1,
		"speed": 55.0, "aggro_range": 6, "attack_cooldown": 1.4,
		"min_distance": 0, "weight": 10,
		"loot": [
			{"item": "Mushrooms", "min": 1, "max": 2, "chance": 100},
			{"item": "Spore Dust", "min": 1, "max": 1, "chance": 50}
		]
	},
	{
		"name": "Crimson Sporecap", "slot": 1, "max_hp": 7, "damage": 2,
		"speed": 70.0, "aggro_range": 7, "attack_cooldown": 1.3,
		"min_distance": 25, "weight": 7,
		"loot": [
			{"item": "Spore Dust", "min": 1, "max": 2, "chance": 100},
			{"item": "Mushrooms", "min": 1, "max": 1, "chance": 60}
		]
	},
	{
		"name": "Elder Myconid", "slot": 2, "max_hp": 10, "damage": 2,
		"speed": 50.0, "aggro_range": 6, "attack_cooldown": 1.5,
		"min_distance": 55, "weight": 5,
		"loot": [
			{"item": "Spore Dust", "min": 2, "max": 3, "chance": 100},
			{"item": "Glowcap", "min": 1, "max": 1, "chance": 40}
		]
	},
	{
		"name": "Lizardman Skirmisher", "slot": 3, "max_hp": 8, "damage": 2,
		"speed": 100.0, "aggro_range": 9, "attack_cooldown": 1.2,
		"min_distance": 40, "weight": 7,
		"loot": [
			{"item": "Lizard Scale", "min": 1, "max": 2, "chance": 100},
			{"item": "Lizard Fillet", "min": 1, "max": 1, "chance": 70}
		]
	},
	{
		"name": "Lizardman Stalker", "slot": 4, "max_hp": 11, "damage": 3,
		"speed": 105.0, "aggro_range": 10, "attack_cooldown": 1.2,
		"min_distance": 80, "weight": 5,
		"loot": [
			{"item": "Lizard Scale", "min": 1, "max": 2, "chance": 100},
			{"item": "Lizard Fillet", "min": 1, "max": 2, "chance": 70},
			{"item": "Iron Ore", "min": 1, "max": 1, "chance": 40}
		]
	},
	{
		"name": "Lizardman Chieftain", "slot": 5, "max_hp": 15, "damage": 3,
		"speed": 95.0, "aggro_range": 10, "attack_cooldown": 1.3,
		"min_distance": 130, "weight": 4,
		"loot": [
			{"item": "Lizard Scale", "min": 2, "max": 3, "chance": 100},
			{"item": "Gold Trinket", "min": 1, "max": 1, "chance": 50}
		]
	},
	{
		"name": "Orc Raider", "slot": 6, "max_hp": 13, "damage": 3,
		"speed": 85.0, "aggro_range": 9, "attack_cooldown": 1.4,
		"min_distance": 90, "weight": 5,
		"loot": [
			{"item": "Orcish Tooth", "min": 1, "max": 2, "chance": 100},
			{"item": "Raw Haunch", "min": 1, "max": 1, "chance": 60},
			{"item": "Stone", "min": 1, "max": 2, "chance": 50}
		]
	},
	{
		"name": "Orc Warlord", "slot": 7, "max_hp": 20, "damage": 4,
		"speed": 75.0, "aggro_range": 9, "attack_cooldown": 1.6,
		"min_distance": 150, "weight": 4,
		"loot": [
			{"item": "Orcish Tooth", "min": 2, "max": 3, "chance": 100},
			{"item": "Rack of Ribs", "min": 1, "max": 1, "chance": 60},
			{"item": "Iron Ore", "min": 1, "max": 2, "chance": 60}
		]
	}
]

## Named-beast bosses (the world chronicle's still-living beasts, met at
## their lairs). Each reuses an existing creature def's art and AI but
## scaled up, tinted per beast kind, and boss-statted: HP ~8-12x the
## Orc Warlord's 20 and damage ~2x its 4, tuned against a player of
## ~20-50 max HP and ~4-9 attack with mid-tier gear — deadly toe-to-toe,
## beatable with food, potions and reach.
const BEAST_BOSS_SPECS := {
	"green_dragon": {
		"def_index": 5, "scale": 2.0, "tint": Color(0.55, 1.0, 0.5, 1.0),
		"max_hp": 200, "damage": 8, "aggro_range": 12, "attack_cooldown": 1.5,
		"speed": 90.0, "coins_min": 150, "coins_max": 230
	},
	"dragon": {
		"def_index": 5, "scale": 2.0, "tint": Color(1.0, 0.52, 0.4, 1.0),
		"max_hp": 220, "damage": 9, "aggro_range": 12, "attack_cooldown": 1.5,
		"speed": 90.0, "coins_min": 160, "coins_max": 250
	},
	"giant": {
		"def_index": 7, "scale": 2.0, "tint": Color(0.98, 0.9, 0.72, 1.0),
		"max_hp": 200, "damage": 9, "aggro_range": 11, "attack_cooldown": 1.8,
		"speed": 70.0, "coins_min": 130, "coins_max": 210
	},
	"troll": {
		"def_index": 7, "scale": 1.8, "tint": Color(0.6, 0.92, 0.55, 1.0),
		"max_hp": 170, "damage": 7, "aggro_range": 11, "attack_cooldown": 1.2,
		"speed": 85.0, "coins_min": 120, "coins_max": 200
	},
	"thing_below": {
		"def_index": 2, "scale": 1.9, "tint": Color(0.82, 0.58, 1.0, 1.0),
		"max_hp": 240, "damage": 8, "aggro_range": 12, "attack_cooldown": 1.6,
		"speed": 60.0, "coins_min": 170, "coins_max": 260
	}
}

static func boss_spec_for_kind(kind: String) -> Dictionary:
	return BEAST_BOSS_SPECS.get(kind, BEAST_BOSS_SPECS["dragon"]) as Dictionary

## Grows and tints a freshly created creature sprite into the named boss
## and hangs its name label overhead (the wilds-landmark label look).
## self_modulate keeps the tint off the label; the label's inverse scale
## keeps the text at UI size regardless of the boss sprite's growth.
static func apply_boss_visuals(sprite: Sprite2D, spec: Dictionary, display_name: String) -> void:
	if sprite == null:
		return
	sprite.scale *= float(spec.get("scale", 1.8))
	sprite.self_modulate = spec.get("tint", Color.WHITE) as Color
	var label := Label.new()
	label.name = "BossNameLabel"
	label.text = display_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.55, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.05, 0.95))
	label.add_theme_constant_override("outline_size", 5)
	# Relative z 0: the tag inherits the boss sprite's own draw band and
	# sits just above it in tree order. A high relative z lifted it over
	# the hold's darkness quad, leaking the boss's position into
	# unexplored black while the boss itself was hidden.
	label.z_index = 0
	var inverse := Vector2(
		1.0 / maxf(absf(sprite.scale.x), 0.001),
		1.0 / maxf(absf(sprite.scale.y), 0.001)
	)
	label.scale = inverse
	var estimated_width := maxf(60.0, float(display_name.length()) * 8.5)
	label.size = Vector2(estimated_width, 20.0)
	var frame_height := 32.0
	if sprite.texture != null:
		frame_height = sprite.texture.get_size().y / float(SHEET_ROWS)
	label.position = Vector2(
		-estimated_width * 0.5 * inverse.x,
		-frame_height * 0.5 - 24.0 * inverse.y
	)
	sprite.add_child(label)

## Animation layout of creature_characters.png: 8 slot blocks in a 4x2
## grid, each block 17 columns x 4 facing rows (down, right, left, up).
## Columns per block: walk 3 | idle 3 | attack 4 | hurt 3 | death 4,
## resampled from the web game's 64x64 mob sheets.
const SHEET_BLOCK_COLUMNS := 17
const SHEET_COLUMNS := 68
const SHEET_ROWS := 8
const ANIM_FRAMES := {
	"walk": {"start": 0, "count": 3, "frame_time": 0.16, "loop": true},
	"idle": {"start": 3, "count": 3, "frame_time": 0.34, "loop": true},
	"attack": {"start": 6, "count": 4, "frame_time": 0.11, "loop": false},
	"hurt": {"start": 10, "count": 3, "frame_time": 0.10, "loop": false},
	"death": {"start": 13, "count": 4, "frame_time": 0.16, "loop": false}
}

static func anim_duration(anim: String) -> float:
	var spec := ANIM_FRAMES.get(anim, {}) as Dictionary
	return float(int(spec.get("count", 1))) * float(spec.get("frame_time", 0.15))

static func create_creature_sprite(creature_texture: Texture2D, slot: int, tile_size: Vector2i) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = creature_texture
	sprite.centered = true
	if creature_texture != null:
		var frame_height := creature_texture.get_size().y / float(SHEET_ROWS)
		sprite.region_enabled = true
		# Mobs occupy ~45px of their 64px frame; 1.35x keeps them tile-sized.
		sprite.scale = Vector2.ONE * (float(tile_size.y) / maxf(frame_height, 1.0)) * 1.35
	update_creature_frame(sprite, slot, "idle", 0.0, 0)
	return sprite

static func update_creature_frame(sprite: Sprite2D, slot: int, anim: String, anim_time: float, facing_row: int) -> void:
	if sprite == null or sprite.texture == null or not sprite.region_enabled:
		return
	var spec := ANIM_FRAMES.get(anim, ANIM_FRAMES["idle"]) as Dictionary
	var frame_count := int(spec.get("count", 1))
	var frame_index := int(anim_time / maxf(float(spec.get("frame_time", 0.15)), 0.001))
	if bool(spec.get("loop", true)):
		frame_index = frame_index % frame_count
	else:
		frame_index = mini(frame_index, frame_count - 1)
	var source_size := sprite.texture.get_size()
	var frame_width := source_size.x / float(SHEET_COLUMNS)
	var frame_height := source_size.y / float(SHEET_ROWS)
	var column := (slot % 4) * SHEET_BLOCK_COLUMNS + int(spec.get("start", 0)) + frame_index
	var row := (slot / 4) * 4 + facing_row
	sprite.region_rect = Rect2(column * frame_width, row * frame_height, frame_width, frame_height)

## Picks a creature for a spawn point, weighted among everything whose
## danger gate the distance has passed.
static func pick_definition_index(distance_from_city: float, rng: RandomNumberGenerator) -> int:
	var total_weight := 0
	for def: Dictionary in CREATURE_DEFS:
		if distance_from_city >= float(int(def.get("min_distance", 0))):
			total_weight += int(def.get("weight", 1))
	if total_weight <= 0:
		return 0
	var roll := rng.randi_range(1, total_weight)
	for def_index in range(CREATURE_DEFS.size()):
		var def := CREATURE_DEFS[def_index]
		if distance_from_city < float(int(def.get("min_distance", 0))):
			continue
		roll -= int(def.get("weight", 1))
		if roll <= 0:
			return def_index
	return 0

static func roll_loot(def: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var loot: Dictionary = {}
	for entry_variant: Variant in (def.get("loot", []) as Array):
		var entry := entry_variant as Dictionary
		if rng.randi_range(1, 100) > int(entry.get("chance", 100)):
			continue
		var amount := rng.randi_range(int(entry.get("min", 1)), int(entry.get("max", 1)))
		if amount > 0:
			var item := String(entry.get("item", ""))
			loot[item] = int(loot.get(item, 0)) + amount
	return loot

## Deterministic per-chunk ambush rolls: which freshly streamed wild cells
## start with a creature on them. Returns [{"cell", "def_index"}].
static func roll_chunk_spawns(grid: Dictionary, district_cell_map: Dictionary, chunk_rect: Rect2i, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var spawns: Array[Dictionary] = []
	var spawn_count := rng.randi_range(0, 2)
	if spawn_count <= 0:
		return spawns
	for _attempt in range(spawn_count * 6):
		if spawns.size() >= spawn_count:
			break
		var cell := Vector2i(
			rng.randi_range(chunk_rect.position.x, chunk_rect.end.x - 1),
			rng.randi_range(chunk_rect.position.y, chunk_rect.end.y - 1)
		)
		if int(grid.get(cell, 0)) != 1:
			continue
		if district_cell_map.has(cell):
			continue
		var distance := Vector2(cell).length()
		spawns.append({"cell": cell, "def_index": pick_definition_index(distance, rng)})
	return spawns
