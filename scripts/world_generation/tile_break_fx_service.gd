extends RefCounted
class_name TileBreakFxService

## Core Keeper-style break feedback for mined walls and felled trees: a burst
## of debris chips flung outward, plus a "ghost" of the removed tile that
## topples over and fades. Every node self-frees, so callers just fire and
## forget after they have already removed the real tile.
##
## Capture the tile art with `tile_art()` BEFORE erasing the cell, then call
## `topple_ghost()` (for the fall) and `chip_burst()` (for the debris).

## {texture, region} for a tilemap cell's base art, or {} when the cell is
## empty / not an atlas source. Read this before the cell is cleared.
static func tile_art(layer: TileMapLayer, cell: Vector2i) -> Dictionary:
	if layer == null or layer.tile_set == null:
		return {}
	var source_id := layer.get_cell_source_id(cell)
	if source_id < 0:
		return {}
	var source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if source == null or source.texture == null:
		return {}
	var atlas := layer.get_cell_atlas_coords(cell)
	var cell_size := Vector2(layer.tile_set.tile_size)
	return {
		"texture": source.texture,
		"region": Rect2(Vector2(atlas) * cell_size, cell_size)
	}

## A one-shot spray of small chips at `local_position` (in `parent`'s space).
static func chip_burst(parent: Node2D, local_position: Vector2, color: Color, amount: int = 12) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var particles := CPUParticles2D.new()
	particles.position = local_position
	particles.z_index = 22
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = maxi(1, amount)
	particles.lifetime = 0.55
	particles.direction = Vector2(0.0, -1.0)
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, 320.0)
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 130.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.5
	particles.color = color
	parent.add_child(particles)
	particles.emitting = true
	# CPUParticles2D keeps its node after a one-shot finishes; reap it on a
	# timer so the debris cannot pile up.
	parent.get_tree().create_timer(particles.lifetime + 0.3).timeout.connect(particles.queue_free)

## A ghost of the just-removed tile that leans over (away from the striker),
## squashes flat and fades - the "it falls" beat of the break.
static func topple_ghost(parent: Node2D, local_position: Vector2, texture: Texture2D, region: Rect2, lean_sign: float = 1.0, sprite_scale: float = 1.0) -> void:
	if parent == null or texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = texture
	if region.size.x > 0.0 and region.size.y > 0.0:
		ghost.region_enabled = true
		ghost.region_rect = region
	ghost.position = local_position
	ghost.z_index = 21
	ghost.scale = Vector2.ONE * sprite_scale
	parent.add_child(ghost)
	var lean := 1.0 if lean_sign >= 0.0 else -1.0
	var tween := ghost.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ghost, "rotation", lean * 1.35, 0.30).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(ghost, "scale", Vector2(sprite_scale * 1.05, sprite_scale * 0.15), 0.30).set_ease(Tween.EASE_IN)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.30).set_delay(0.06)
	tween.chain().tween_callback(ghost.queue_free)
