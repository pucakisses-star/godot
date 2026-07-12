extends RefCounted
class_name OverworldTilesetService

## Builds the overworld TileSet: the main atlas source from the overworld
## sheet (with graceful fallback when the texture is missing), plus the
## dedicated river atlas source. Extracted from overworld_map.gd.

const TILE_ATLAS_DEFS := preload("res://scripts/world_generation/tile_atlas_defs.gd")

## Returns {"tile_set": TileSet, "atlas_source_id": int,
## "river_atlas_source_id": int, "tile_size": int}. Source ids are -1 when
## the relevant texture could not be loaded; tile_size may differ from the
## configured size when the atlas texture dictates its own grid.
static func build_tile_set(configured_tile_size: int, iceberg_tile_options: Array[Vector2i]) -> Dictionary:
	var tile_set := TileSet.new()
	var result := {
		"tile_set": tile_set,
		"atlas_source_id": -1,
		"river_atlas_source_id": -1,
		"tile_size": configured_tile_size
	}
	var overworld_atlas := TileSetAtlasSource.new()
	var tile_coords_list := _base_tile_coords_list()
	for iceberg_tile_coord: Vector2i in iceberg_tile_options:
		tile_coords_list.append(iceberg_tile_coord)
	for road_bucket: Variant in TILE_ATLAS_DEFS.ROAD_SEGMENTS.values():
		for road_variant: Variant in (road_bucket as Array):
			tile_coords_list.append((road_variant as Dictionary)["atlas"] as Vector2i)

	var atlas_texture := load(TILE_ATLAS_DEFS.ATLAS_TEXTURE) as Texture2D
	if atlas_texture == null:
		push_warning("Overworld atlas texture could not be loaded: %s. Using generated fallback atlas." % TILE_ATLAS_DEFS.ATLAS_TEXTURE)
		atlas_texture = build_fallback_overworld_atlas(tile_coords_list, configured_tile_size)
	if atlas_texture == null:
		push_error("Overworld atlas fallback texture could not be generated.")
		return result

	var texture_size: Vector2i = atlas_texture.get_size()
	var max_tile := Vector2i(0, 0)
	for tile_coords: Vector2i in tile_coords_list:
		max_tile.x = max(max_tile.x, tile_coords.x)
		max_tile.y = max(max_tile.y, tile_coords.y)
	var required_columns := max_tile.x + 1
	var required_rows := max_tile.y + 1
	var atlas_tile_size := configured_tile_size
	if required_columns > 0 and required_rows > 0:
		if int(texture_size.x) % required_columns == 0 and int(texture_size.y) % required_rows == 0:
			var derived_tile_size_x := int(texture_size.x / required_columns)
			var derived_tile_size_y := int(texture_size.y / required_rows)
			if derived_tile_size_x == derived_tile_size_y and derived_tile_size_x > 0:
				if derived_tile_size_x != configured_tile_size:
					push_warning(
						"Overworld atlas tile size (%s) differs from configured tile_size (%s); using atlas-derived size." %
						[derived_tile_size_x, configured_tile_size]
					)
					result["tile_size"] = derived_tile_size_x
				atlas_tile_size = derived_tile_size_x
			else:
				push_warning(
					"Overworld atlas texture size (%s) does not map cleanly to a square tile grid (%s x %s)." %
					[texture_size, required_columns, required_rows]
				)
	var max_columns := int(texture_size.x / atlas_tile_size)
	var max_rows := int(texture_size.y / atlas_tile_size)
	if max_columns <= 0 or max_rows <= 0:
		push_error("Overworld atlas texture has no valid tile regions: %s" % TILE_ATLAS_DEFS.ATLAS_TEXTURE)
		return result
	if max_columns < required_columns or max_rows < required_rows:
		push_error(
			"Overworld atlas texture is too small for required tiles (%s x %s needed, got %s x %s)." %
			[required_columns, required_rows, max_columns, max_rows]
		)
	tile_set.tile_size = Vector2i(atlas_tile_size, atlas_tile_size)
	overworld_atlas.texture = atlas_texture
	overworld_atlas.texture_region_size = Vector2i(atlas_tile_size, atlas_tile_size)
	var seen_tiles: Dictionary = {}
	for tile_coords: Vector2i in tile_coords_list:
		if seen_tiles.has(tile_coords):
			continue
		seen_tiles[tile_coords] = true
		if tile_coords.x < 0 or tile_coords.y < 0 or tile_coords.x >= max_columns or tile_coords.y >= max_rows:
			push_warning(
				"Skipping overworld tile %s because it is outside the atlas bounds (%s x %s)." %
				[tile_coords, max_columns, max_rows]
			)
			continue
		overworld_atlas.create_tile(tile_coords)
	result["atlas_source_id"] = tile_set.add_source(overworld_atlas)
	result["river_atlas_source_id"] = configure_river_atlas_source(tile_set)
	return result

static func configure_river_atlas_source(tile_set: TileSet) -> int:
	var river_texture := load(TILE_ATLAS_DEFS.RIVER_ATLAS_TEXTURE) as Texture2D
	if river_texture == null:
		push_warning(
			"River atlas texture could not be loaded: %s. Rivers will fall back to the overworld atlas." %
			TILE_ATLAS_DEFS.RIVER_ATLAS_TEXTURE
		)
		return -1
	var cell_size := int(tile_set.tile_size.x)
	var source_tile_size := int(TILE_ATLAS_DEFS.RIVER_ATLAS_TILE_SIZE)
	var river_image := river_texture.get_image()
	if river_image == null:
		return -1
	# The river sheet uses smaller tiles than the overworld atlas; upscale it
	# (nearest neighbour, pixel art) so its tiles fill the map grid cells.
	if source_tile_size != cell_size and source_tile_size > 0:
		var upscale := float(cell_size) / float(source_tile_size)
		river_image.resize(
			int(round(river_image.get_width() * upscale)),
			int(round(river_image.get_height() * upscale)),
			Image.INTERPOLATE_NEAREST
		)
	var river_atlas := TileSetAtlasSource.new()
	river_atlas.texture = ImageTexture.create_from_image(river_image)
	river_atlas.texture_region_size = Vector2i(cell_size, cell_size)
	var max_columns := int(river_image.get_width() / cell_size)
	var max_rows := int(river_image.get_height() / cell_size)
	for tile_key: String in TILE_ATLAS_DEFS.RIVER_TILES.keys():
		var tile_coords: Vector2i = TILE_ATLAS_DEFS.RIVER_TILES[tile_key]
		if tile_coords.x < 0 or tile_coords.y < 0 or tile_coords.x >= max_columns or tile_coords.y >= max_rows:
			push_warning(
				"Skipping river tile %s %s because it is outside the river atlas bounds (%s x %s)." %
				[tile_key, tile_coords, max_columns, max_rows]
			)
			continue
		if river_atlas.has_tile(tile_coords):
			continue
		river_atlas.create_tile(tile_coords)
	return tile_set.add_source(river_atlas)

static func build_fallback_overworld_atlas(tile_coords_list: Array[Vector2i], tile_size: int) -> Texture2D:
	if tile_coords_list.is_empty():
		return null
	var max_coord := Vector2i.ZERO
	for coords: Vector2i in tile_coords_list:
		max_coord.x = max(max_coord.x, coords.x)
		max_coord.y = max(max_coord.y, coords.y)
	var image_width := (max_coord.x + 1) * tile_size
	var image_height := (max_coord.y + 1) * tile_size
	if image_width <= 0 or image_height <= 0:
		return null
	var atlas_image := Image.create(image_width, image_height, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color(0.12, 0.12, 0.12, 1.0))
	var palette: Array[Color] = [
		Color(0.86, 0.68, 0.36, 1.0),
		Color(0.28, 0.67, 0.36, 1.0),
		Color(0.61, 0.44, 0.33, 1.0),
		Color(0.41, 0.44, 0.48, 1.0),
		Color(0.31, 0.58, 0.51, 1.0),
		Color(0.88, 0.92, 0.95, 1.0),
		Color(0.18, 0.38, 0.78, 1.0),
		Color(0.72, 0.28, 0.64, 1.0)
	]
	for i in range(tile_coords_list.size()):
		var coords: Vector2i = tile_coords_list[i]
		var tile_rect := Rect2i(coords * tile_size, Vector2i(tile_size, tile_size))
		var tile_color: Color = palette[i % palette.size()]
		atlas_image.fill_rect(tile_rect, tile_color)
		atlas_image.fill_rect(Rect2i(tile_rect.position, Vector2i(tile_size, 1)), Color.BLACK)
		atlas_image.fill_rect(Rect2i(tile_rect.position + Vector2i(0, tile_size - 1), Vector2i(tile_size, 1)), Color.BLACK)
		atlas_image.fill_rect(Rect2i(tile_rect.position, Vector2i(1, tile_size)), Color.BLACK)
		atlas_image.fill_rect(Rect2i(tile_rect.position + Vector2i(tile_size - 1, 0), Vector2i(1, tile_size)), Color.BLACK)
	return ImageTexture.create_from_image(atlas_image)

static func _base_tile_coords_list() -> Array[Vector2i]:
	return [
		TILE_ATLAS_DEFS.SAND_TILE,
		TILE_ATLAS_DEFS.GRASS_TILE,
		TILE_ATLAS_DEFS.BADLANDS_TILE,
		TILE_ATLAS_DEFS.MINE_TILE,
		TILE_ATLAS_DEFS.MARSH_TILE,
		TILE_ATLAS_DEFS.SNOW_TILE,
		TILE_ATLAS_DEFS.TREE_TILE,
		TILE_ATLAS_DEFS.TREE_LONE_TILE,
		TILE_ATLAS_DEFS.TREE_SNOW_TILE,
		TILE_ATLAS_DEFS.JUNGLE_TREE_TILE,
		TILE_ATLAS_DEFS.CUT_TREES_TILE,
		TILE_ATLAS_DEFS.AMBIENT_LUMBER_MILL_TILE,
		TILE_ATLAS_DEFS.WATER_TILE,
		TILE_ATLAS_DEFS.MOUNTAIN_TILE,
		TILE_ATLAS_DEFS.MOUNTAIN_TOP_A_TILE,
		TILE_ATLAS_DEFS.MOUNTAIN_TOP_B_TILE,
		TILE_ATLAS_DEFS.MOUNTAIN_BOTTOM_A_TILE,
		TILE_ATLAS_DEFS.MOUNTAIN_BOTTOM_B_TILE,
		TILE_ATLAS_DEFS.DAM_TILE,
		TILE_ATLAS_DEFS.MOUNTAIN_PEAK_TILE,
		TILE_ATLAS_DEFS.STONE_TILE,
		TILE_ATLAS_DEFS.DWARFHOLD_TILE,
		TILE_ATLAS_DEFS.ABANDONED_DWARFHOLD_TILE,
		TILE_ATLAS_DEFS.GREAT_DWARFHOLD_TILE,
		TILE_ATLAS_DEFS.DARK_DWARFHOLD_TILE,
		TILE_ATLAS_DEFS.HILLHOLD_TILE,
		TILE_ATLAS_DEFS.CAVE_TILE,
		TILE_ATLAS_DEFS.TOWER_TILE,
		TILE_ATLAS_DEFS.EVIL_WIZARDS_TOWER_TILE,
		TILE_ATLAS_DEFS.WOOD_ELF_GROVES_TILE,
		TILE_ATLAS_DEFS.WOOD_ELF_GROVES_LARGE_TILE,
		TILE_ATLAS_DEFS.WOOD_ELF_GROVES_GRAND_TILE,
		TILE_ATLAS_DEFS.HILLS_TILE,
		TILE_ATLAS_DEFS.HILLS_BADLANDS_TILE,
		TILE_ATLAS_DEFS.HILLS_VARIANT_A_TILE,
		TILE_ATLAS_DEFS.HILLS_VARIANT_B_TILE,
		TILE_ATLAS_DEFS.HILLS_SNOW_TILE,
		TILE_ATLAS_DEFS.TOWN_TILE,
		TILE_ATLAS_DEFS.PORT_TOWN_TILE,
		TILE_ATLAS_DEFS.CASTLE_TILE,
		TILE_ATLAS_DEFS.ROADSIDE_TAVERN_TILE,
		TILE_ATLAS_DEFS.HAMLET_TILE,
		TILE_ATLAS_DEFS.ACTIVE_VOLCANO_TILE,
		TILE_ATLAS_DEFS.VOLCANO_TILE,
		TILE_ATLAS_DEFS.LAVA_TILE,
		TILE_ATLAS_DEFS.OASIS_TILE,
		TILE_ATLAS_DEFS.HAMLET_SNOW_TILE,
		TILE_ATLAS_DEFS.AMBIENT_SLEEPING_DRAGON_TILE,
		TILE_ATLAS_DEFS.AMBIENT_HUNTING_LODGE_TILE,
		TILE_ATLAS_DEFS.AMBIENT_HOMESTEAD_TILE,
		TILE_ATLAS_DEFS.AMBIENT_MOONWELL_TILE,
		TILE_ATLAS_DEFS.AMBIENT_FARM_TILE,
		TILE_ATLAS_DEFS.FARM_CROPS_TILE,
		TILE_ATLAS_DEFS.AMBIENT_FARM_VARIANT_TILE,
		TILE_ATLAS_DEFS.AMBIENT_GREAT_TREE_TILE,
		TILE_ATLAS_DEFS.AMBIENT_GREAT_TREE_ALT_TILE,
		TILE_ATLAS_DEFS.LIZARDMEN_CITY_TILE,
		TILE_ATLAS_DEFS.SAINT_SHRINE_TILE,
		TILE_ATLAS_DEFS.MONASTERY_TILE,
		TILE_ATLAS_DEFS.ORC_CAMP_TILE,
		TILE_ATLAS_DEFS.GNOLL_CAMP_TILE,
		TILE_ATLAS_DEFS.TROLL_CAMP_TILE,
		TILE_ATLAS_DEFS.OGRE_CAMP_TILE,
		TILE_ATLAS_DEFS.BANDIT_CAMP_TILE,
		TILE_ATLAS_DEFS.TRAVELERS_CAMP_TILE,
		TILE_ATLAS_DEFS.DUNGEON_TILE,
		TILE_ATLAS_DEFS.CENTAUR_ENCAMPMENT_TILE,
		TILE_ATLAS_DEFS.DESERT_CITY_TILE,
		TILE_ATLAS_DEFS.DESERT_SERPENT_STATUE_TILE,
		TILE_ATLAS_DEFS.DESERT_WALL_A_TILE,
		TILE_ATLAS_DEFS.DESERT_WALL_B_TILE,
		TILE_ATLAS_DEFS.DESERT_GATE_TILE,
		TILE_ATLAS_DEFS.DESERT_HUT_TILE,
		TILE_ATLAS_DEFS.DESERT_PALMS_TILE,
		TILE_ATLAS_DEFS.DESERT_CACTI_TILE,
		TILE_ATLAS_DEFS.EVIL_KEEP_TILE,
		TILE_ATLAS_DEFS.DARK_GATE_TILE,
		TILE_ATLAS_DEFS.DARK_SPIRE_TILE,
		TILE_ATLAS_DEFS.GREEN_DRAGON_TILE,
		TILE_ATLAS_DEFS.OLD_GROWTH_TILE,
		TILE_ATLAS_DEFS.WATCHTOWER_TILE,
		TILE_ATLAS_DEFS.HERMIT_HUT_TILE,
		TILE_ATLAS_DEFS.TENT_CAMP_TILE,
		TILE_ATLAS_DEFS.FARMHOUSE_TILE,
		TILE_ATLAS_DEFS.STONE_CAIRN_TILE,
		TILE_ATLAS_DEFS.WAR_PYRE_TILE,
		TILE_ATLAS_DEFS.MOUNTAIN_ALT_TILE,
		TILE_ATLAS_DEFS.CHAPEL_TILE,
		TILE_ATLAS_DEFS.DOMED_TEMPLE_TILE,
		TILE_ATLAS_DEFS.GRAND_CATHEDRAL_TILE,
		TILE_ATLAS_DEFS.PROSPECTOR_CAMP_TILE,
		TILE_ATLAS_DEFS.OGRE_DEN_TILE
	]
