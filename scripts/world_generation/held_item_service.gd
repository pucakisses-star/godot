class_name HeldItemService
extends RefCounted

## A small icon of the currently selected hotbar item, tucked into the
## player model's hand. Shared by the town and the hold so both walkable
## scenes render what the wanderer is holding in the same way.

const HELD_NODE_NAME := "HeldItem"
## Item icons are drawn from 32px atlas cells.
const ICON_SOURCE_PX := 32.0

## Finds (or makes) the "HeldItem" sprite parented to the player model and
## points it at the given item's icon. An empty name or a missing texture
## removes the sprite. The offset and scale are expressed in world tiles
## then divided back out of the player sprite's own scale, so the held icon
## reads at a steady ~half-tile no matter how the body texture is scaled.
static func update(player_sprite: Node2D, item_name: String, tile_size: Vector2i) -> void:
	if player_sprite == null:
		return
	var held := player_sprite.get_node_or_null(NodePath(HELD_NODE_NAME)) as Sprite2D
	var texture: Texture2D = null
	if not item_name.is_empty():
		texture = ItemDefsService.icon_texture(item_name)
	if texture == null:
		if held != null:
			held.queue_free()
		return
	if held == null:
		held = Sprite2D.new()
		held.name = HELD_NODE_NAME
		held.centered = true
		held.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# A small relative z lifts the icon above the body it hangs from.
		held.z_index = 5
		player_sprite.add_child(held)
	held.texture = texture
	var body_scale := player_sprite.scale
	var scale_x := body_scale.x if absf(body_scale.x) > 0.0001 else 1.0
	var scale_y := body_scale.y if absf(body_scale.y) > 0.0001 else 1.0
	# Half a tile on screen, undoing the body's scale so it holds steady.
	var target_px := float(tile_size.y) * 0.5
	held.scale = Vector2((target_px / ICON_SOURCE_PX) / scale_x, (target_px / ICON_SOURCE_PX) / scale_y)
	# A hand offset: a little right of and below the body's center.
	held.position = Vector2((float(tile_size.x) * 0.3) / scale_x, (float(tile_size.y) * 0.3) / scale_y)
	held.visible = true
