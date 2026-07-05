extends RefCounted
class_name OverworldCoastService

## Rounds the overworld coastlines. Land visually bulges into each
## neighboring water cell as a band with semicircular end caps, so the
## shoreline reads as an organic scallop instead of a hard tile grid.
## Overlay tiles are generated at map-build time by masking the
## adjacent land tile's own art (the biome art tiles seamlessly, so the
## pattern continues across the cell boundary), packed into one dynamic
## atlas source and painted onto a dedicated coast layer.

## How deep a land bulge reaches into a water cell, as a tile fraction.
const BAND_DEPTH_RATIO := 0.375
const SHEET_COLUMNS := 16

## Neighbor bits: N, NE, E, SE, S, SW, W, NW.
const DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)
]
const BIT_N := 1
const BIT_NE := 2
const BIT_E := 4
const BIT_SE := 8
const BIT_S := 16
const BIT_SW := 32
const BIT_W := 64
const BIT_NW := 128

## Paints coast bulges over every water cell that touches land.
## art_tiles: terrain tiles allowed to provide bulge art (settlement
## icons and other props count as land for the mask but never as art).
## Returns the new atlas source id (-1 when nothing was painted);
## previous_source_id is removed from the tile set first.
static func apply_coast_overlay(
	coast_layer: TileMapLayer,
	map_layer: TileMapLayer,
	water_tile: Vector2i,
	art_tiles: Array[Vector2i],
	tile_size: int,
	map_size: Vector2i,
	previous_source_id: int
) -> int:
	coast_layer.clear()
	var tile_set := coast_layer.tile_set
	if tile_set == null or map_layer == null:
		return -1
	if previous_source_id >= 0 and tile_set.has_source(previous_source_id):
		tile_set.remove_source(previous_source_id)

	var atlas_image := _terrain_atlas_image(map_layer)
	if atlas_image == null:
		return -1

	# Pass 1: every water cell bordered by land gets a (art tile, mask) key.
	var art_set: Dictionary = {}
	for art_tile: Vector2i in art_tiles:
		art_set[art_tile] = true
	var placements: Dictionary = {}
	var variant_slots: Dictionary = {}
	for y in range(map_size.y):
		for x in range(map_size.x):
			var coord := Vector2i(x, y)
			if map_layer.get_cell_atlas_coords(coord) != water_tile:
				continue
			var mask := 0
			var art_votes: Dictionary = {}
			for bit_index in DIRS.size():
				var neighbor := coord + DIRS[bit_index]
				if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= map_size.x or neighbor.y >= map_size.y:
					continue
				var neighbor_tile := map_layer.get_cell_atlas_coords(neighbor)
				if neighbor_tile == water_tile or neighbor_tile == Vector2i(-1, -1):
					continue
				mask |= 1 << bit_index
				if art_set.has(neighbor_tile):
					art_votes[neighbor_tile] = int(art_votes.get(neighbor_tile, 0)) + 1
			if mask == 0 or art_votes.is_empty():
				continue
			var best_art := Vector2i.ZERO
			var best_votes := -1
			for art_variant: Variant in art_votes.keys():
				if int(art_votes[art_variant]) > best_votes:
					best_votes = int(art_votes[art_variant])
					best_art = art_variant as Vector2i
			var key := "%d,%d|%d" % [best_art.x, best_art.y, mask]
			if not variant_slots.has(key):
				variant_slots[key] = {"index": variant_slots.size(), "art": best_art, "mask": mask}
			placements[coord] = key

	if variant_slots.is_empty():
		return -1

	# Pass 2: compose the variant sheet - each slot is the land art
	# masked by the bulge silhouette for its neighbor mask.
	var rows := (variant_slots.size() + SHEET_COLUMNS - 1) / SHEET_COLUMNS
	var sheet := Image.create(SHEET_COLUMNS * tile_size, rows * tile_size, false, Image.FORMAT_RGBA8)
	var mask_cache: Dictionary = {}
	for key_variant: Variant in variant_slots.keys():
		var slot := variant_slots[key_variant] as Dictionary
		var mask := int(slot["mask"])
		var art := slot["art"] as Vector2i
		var index := int(slot["index"])
		var coverage: PackedByteArray = mask_cache.get(mask, PackedByteArray())
		if coverage.is_empty():
			coverage = _bulge_coverage(mask, tile_size)
			mask_cache[mask] = coverage
		var dest := Vector2i((index % SHEET_COLUMNS) * tile_size, (index / SHEET_COLUMNS) * tile_size)
		var src := Vector2i(art.x * tile_size, art.y * tile_size)
		for py in range(tile_size):
			for px in range(tile_size):
				if coverage[py * tile_size + px] == 0:
					continue
				sheet.set_pixelv(dest + Vector2i(px, py), atlas_image.get_pixelv(src + Vector2i(px, py)))

	var coast_source := TileSetAtlasSource.new()
	coast_source.texture = ImageTexture.create_from_image(sheet)
	coast_source.texture_region_size = Vector2i(tile_size, tile_size)
	for key_variant: Variant in variant_slots.keys():
		var slot := variant_slots[key_variant] as Dictionary
		var index := int(slot["index"])
		coast_source.create_tile(Vector2i(index % SHEET_COLUMNS, index / SHEET_COLUMNS))
	var source_id := tile_set.add_source(coast_source)

	# Pass 3: paint.
	for coord_variant: Variant in placements.keys():
		var coord := coord_variant as Vector2i
		var slot := variant_slots[placements[coord_variant]] as Dictionary
		var index := int(slot["index"])
		coast_layer.set_cell(coord, source_id, Vector2i(index % SHEET_COLUMNS, index / SHEET_COLUMNS))
	return source_id

## A decompressed RGBA copy of the terrain atlas the map layer draws from.
static func _terrain_atlas_image(map_layer: TileMapLayer) -> Image:
	var tile_set := map_layer.tile_set
	if tile_set == null:
		return null
	for source_index in tile_set.get_source_count():
		var source := tile_set.get_source(tile_set.get_source_id(source_index)) as TileSetAtlasSource
		if source == null or source.texture == null:
			continue
		var image := source.texture.get_image()
		if image == null:
			continue
		if image.is_compressed():
			image.decompress()
		if image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)
		return image
	return null

## The bulge silhouette for one neighbor mask: a byte per pixel, 1 where
## the land art shows. Cardinal land neighbors push a band into the cell
## with semicircular caps on open ends; diagonal-only land contributes a
## quarter disc so single-tile steps read as smooth curves.
static func _bulge_coverage(mask: int, tile_size: int) -> PackedByteArray:
	var coverage := PackedByteArray()
	coverage.resize(tile_size * tile_size)
	var depth := maxi(int(round(tile_size * BAND_DEPTH_RATIO)), 3)
	var n := mask & BIT_N != 0
	var ne := mask & BIT_NE != 0
	var e := mask & BIT_E != 0
	var se := mask & BIT_SE != 0
	var s := mask & BIT_S != 0
	var sw := mask & BIT_SW != 0
	var w := mask & BIT_W != 0
	var nw := mask & BIT_NW != 0
	var depth_sq := float(depth * depth)
	for y in range(tile_size):
		for x in range(tile_size):
			var covered := false
			if n:
				covered = _band_pixel(x, y, tile_size, depth, not (w or nw), not (e or ne))
			if not covered and s:
				covered = _band_pixel(x, tile_size - 1 - y, tile_size, depth, not (w or sw), not (e or se))
			if not covered and w:
				covered = _band_pixel(y, x, tile_size, depth, not (n or nw), not (s or sw))
			if not covered and e:
				covered = _band_pixel(y, tile_size - 1 - x, tile_size, depth, not (n or ne), not (s or se))
			if not covered and nw and not n and not w:
				covered = float(x * x + y * y) <= depth_sq
			if not covered and ne and not n and not e:
				var dx := tile_size - 1 - x
				covered = float(dx * dx + y * y) <= depth_sq
			if not covered and sw and not s and not w:
				var dy := tile_size - 1 - y
				covered = float(x * x + dy * dy) <= depth_sq
			if not covered and se and not s and not e:
				var dx2 := tile_size - 1 - x
				var dy2 := tile_size - 1 - y
				covered = float(dx2 * dx2 + dy2 * dy2) <= depth_sq
			if covered:
				coverage[y * tile_size + x] = 1
	return coverage

## One band along the cell edge: v is depth into the cell, u runs along
## the edge. Open ends taper as semicircles instead of stopping square.
static func _band_pixel(u: int, v: int, tile_size: int, depth: int, start_open: bool, end_open: bool) -> bool:
	if v >= depth:
		return false
	var cap_radius := depth * 0.5
	if start_open and float(u) < cap_radius:
		var du := float(u) - cap_radius
		var dv := float(v) - cap_radius
		return du * du + dv * dv <= cap_radius * cap_radius
	if end_open and float(u) > float(tile_size) - cap_radius:
		var du2 := float(u) - (float(tile_size) - cap_radius)
		var dv2 := float(v) - cap_radius
		return du2 * du2 + dv2 * dv2 <= cap_radius * cap_radius
	return true
