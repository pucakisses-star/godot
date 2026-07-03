extends RefCounted
class_name DwarfHoldActorVisuals

## Builds an NPC sprite. When the texture is a 12x8 character sheet
## (8 slots of 3 walk frames x 4 facings), the sprite uses an animated
## region that DwarfHoldTavernService.update_character_frame advances;
## tiny textures (the 1x1 placeholder) fall back to the colored box.
static func create_tavern_character_sprite(character_texture: Texture2D, character_slot: int, tile_size: Vector2i) -> Sprite2D:
	if character_texture != null:
		var source_size := character_texture.get_size()
		var frame_width := int(source_size.x / 12.0)
		var frame_height := int(source_size.y / 8.0)
		if frame_width >= 8 and frame_height >= 8:
			var sheet_sprite := Sprite2D.new()
			sheet_sprite.texture = character_texture
			sheet_sprite.region_enabled = true
			sheet_sprite.centered = true
			var slot_column := character_slot % 4
			var slot_row := character_slot / 4
			sheet_sprite.region_rect = Rect2(
				(slot_column * 3 + 1) * frame_width,
				slot_row * 4 * frame_height,
				frame_width,
				frame_height
			)
			sheet_sprite.scale = Vector2(
				float(tile_size.x) / float(frame_width),
				float(tile_size.y) / float(frame_height)
			) * 0.9
			return sheet_sprite

	var sprite := Sprite2D.new()
	sprite.texture = character_texture
	sprite.region_enabled = false
	sprite.centered = true
	sprite.modulate = placeholder_actor_color(character_slot)
	sprite.scale = Vector2(float(tile_size.x), float(tile_size.y)) * 0.45
	return sprite

static func create_player_character_sprite(shattered_player_texture: Texture2D, tile_size: Vector2i, fallback_creator: Callable) -> Sprite2D:
	if shattered_player_texture == null:
		var fallback_sprite := fallback_creator.call(0) as Sprite2D
		fallback_sprite.modulate = Color(0.98, 0.95, 0.70, 1.0)
		return fallback_sprite

	var sprite := Sprite2D.new()
	sprite.texture = shattered_player_texture
	sprite.region_enabled = true
	sprite.centered = true
	sprite.modulate = Color.WHITE
	var source_size := shattered_player_texture.get_size()
	var source_tile_size := Vector2i(16, 16)
	if source_size.x > 0 and source_size.y > 0:
		source_tile_size.x = maxi(1, mini(16, source_size.x))
		source_tile_size.y = maxi(1, mini(16, source_size.y))
	sprite.region_rect = Rect2(Vector2.ZERO, Vector2(source_tile_size))
	sprite.scale = Vector2(float(tile_size.x) / float(source_tile_size.x), float(tile_size.y) / float(source_tile_size.y)) * 0.9
	return sprite

static func create_placeholder_actor_texture() -> Texture2D:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)

static func placeholder_actor_color(character_slot: int) -> Color:
	var palette := [
		Color(0.92, 0.82, 0.55, 1.0),
		Color(0.75, 0.34, 0.30, 1.0),
		Color(0.31, 0.61, 0.84, 1.0),
		Color(0.38, 0.72, 0.44, 1.0),
		Color(0.74, 0.49, 0.84, 1.0),
		Color(0.90, 0.66, 0.26, 1.0),
		Color(0.41, 0.75, 0.74, 1.0),
		Color(0.62, 0.62, 0.67, 1.0)
	]
	var index := posmod(character_slot, palette.size())
	return palette[index]

static func create_placeholder_tavern_character_texture(
	tavern_sprite_columns: int,
	tavern_sprite_rows: int,
	tavern_character_rows: int,
	tavern_character_columns: int,
	tavern_character_slot_count: int
) -> Texture2D:
	var frame_size := Vector2i(16, 16)
	var texture_size := Vector2i(tavern_sprite_columns * frame_size.x, tavern_sprite_rows * frame_size.y)
	var image := Image.create(texture_size.x, texture_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	var base_palette := [
		Color(0.86, 0.29, 0.29, 1.0),
		Color(0.31, 0.73, 0.38, 1.0),
		Color(0.29, 0.53, 0.86, 1.0),
		Color(0.85, 0.69, 0.25, 1.0),
		Color(0.71, 0.36, 0.84, 1.0),
		Color(0.23, 0.76, 0.77, 1.0),
		Color(0.88, 0.47, 0.16, 1.0),
		Color(0.52, 0.61, 0.22, 1.0)
	]

	for slot in tavern_character_slot_count:
		var slot_column := slot % 4
		var slot_row := slot / 4
		var base_color: Color = base_palette[slot % base_palette.size()]
		for facing in tavern_character_rows:
			for frame in tavern_character_columns:
				var atlas_column := slot_column * tavern_character_columns + frame
				var atlas_row := slot_row * tavern_character_rows + facing
				var top_left := Vector2i(atlas_column * frame_size.x, atlas_row * frame_size.y)

				var brightness := 0.85 + (0.07 * frame) + (0.03 * facing)
				var fill_color := base_color * brightness
				fill_color.a = 1.0
				image.fill_rect(Rect2i(top_left, frame_size), fill_color)

				var eye_y := top_left.y + 4
				image.set_pixel(top_left.x + 5, eye_y, Color(0.1, 0.1, 0.1, 1.0))
				image.set_pixel(top_left.x + 10, eye_y, Color(0.1, 0.1, 0.1, 1.0))
				image.fill_rect(Rect2i(top_left + Vector2i(4, 11), Vector2i(8, 2)), Color(0.14, 0.14, 0.14, 1.0))

	return ImageTexture.create_from_image(image)
