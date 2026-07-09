class_name CulturalInfluence
extends RefCounted

const CULTURE_TYPES := preload("res://scripts/world_generation/culture_types.gd")
## Canopy depth (0 edge, 1 core) a tile must reach to count as "deep forest"
## for options gated with requires_deep_forest (e.g. moonwells).
const DEEP_FOREST_CANOPY := 0.6
const MIN_RADIUS := 2
const MIN_SCORE := 0.0001
const STATE_FORMS: Array[String] = [
	"Duchy",
	"Grand Duchy",
	"Principality",
	"Kingdom",
	"Empire",
	"Republic",
	"Federation",
	"Trade Company",
	"Most Serene Republic",
	"Oligarchy",
	"Tetrarchy",
	"Triumvirate",
	"Diarchy",
	"Junta",
	"Union",
	"League",
	"Confederation",
	"United Kingdom",
	"United Republic",
	"United Provinces",
	"Commonwealth",
	"Heptarchy",
	"Theocracy",
	"Brotherhood",
	"Thearchy",
	"See",
	"Holy State",
	"Free Territory",
	"Council",
	"Commune",
	"Community",
	"Marches",
	"Dominion",
	"Protectorate",
	"Khanate",
	"Beylik",
	"Tsardom",
	"Khaganate",
	"Shogunate",
	"Caliphate",
	"Emirate",
	"Despotate",
	"Ulus",
	"Horde",
	"Satrapy",
	"Free City",
	"City-state",
	"Diocese",
	"Bishopric",
	"Eparchy",
	"Exarchate",
	"Patriarchate",
	"Imamah"
]

var _sources: Array[Dictionary] = []

func apply_cultural_influence(
	width: int,
	height: int,
	tiles: Dictionary,
	settlements: Array[Dictionary],
	factions: Array[Dictionary],
	is_land_base_tile_fn: Callable,
	seed_number: int,
	wood_elf_territory_info: Dictionary
) -> void:
	var stage_started := Time.get_ticks_msec()
	_sources.clear()
	_clear_existing_influence(tiles)
	_build_settlement_sources(settlements)
	_build_faction_sources(factions)
	_build_ambient_sources(width, height, tiles, seed_number, wood_elf_territory_info)
	var sources_ms := Time.get_ticks_msec() - stage_started
	stage_started = Time.get_ticks_msec()
	_apply_sources(width, height, tiles, is_land_base_tile_fn)
	var apply_ms := Time.get_ticks_msec() - stage_started
	stage_started = Time.get_ticks_msec()
	_resolve_scores(width, height, tiles)
	var resolve_ms := Time.get_ticks_msec() - stage_started
	stage_started = Time.get_ticks_msec()
	_assign_political_regions(width, height, tiles, settlements, factions, is_land_base_tile_fn, seed_number)
	print("[CulturalInfluence] sources %d ms | apply %d ms (%d sources) | resolve %d ms | political %d ms" % [
		sources_ms, apply_ms, _sources.size(), resolve_ms, Time.get_ticks_msec() - stage_started
	])

func add_cultural_source(
	x: int,
	y: int,
	radius: int,
	entries: Array[Dictionary],
	falloff: float = 1.35,
	tile_filter: Callable = Callable()
) -> void:
	if entries.is_empty():
		return
	var normalized_entries := _normalize_entries(entries)
	if normalized_entries.is_empty():
		return
	_sources.append({
		"x": x,
		"y": y,
		"radius": maxi(MIN_RADIUS, radius),
		"falloff": maxf(0.01, falloff),
		"entries": normalized_entries,
		"tile_filter": tile_filter
	})

func normalise_culture_key(key: String, fallback_label: String) -> String:
	var normalized := key.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	if not normalized.is_empty():
		return normalized
	var fallback := fallback_label.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	return fallback if not fallback.is_empty() else "humans"

func format_culture_label(key: String) -> String:
	var parts := key.replace("-", "_").split("_", false)
	if parts.is_empty():
		return "Humans"
	for index in range(parts.size()):
		parts[index] = String(parts[index]).capitalize()
	return " ".join(parts)

func resolve_culture_color(color: Variant, key: String) -> Color:
	if color is Color:
		return color as Color
	if color is String and not String(color).strip_edges().is_empty():
		return Color(String(color))
	return CULTURE_TYPES.DEFAULT_CULTURE_COLORS.get(key, Color.GRAY)

## Browser derivePopulationGroupsFromCulture (main.js:14276-14324): sort
## shares descending, the top entry is always a major, majors accept
## >= 0.22 (or >= 0.16 while fewer than two), minors accept >= 0.08 or
## while fewer than two, labels carry a "(NN%)" suffix from 5% up, and the
## first minor is promoted when no major survived.
func derive_population_groups(breakdown: Array[Dictionary]) -> Dictionary:
	var entries: Array[Dictionary] = []
	for entry: Dictionary in breakdown:
		var share := clampf(float(entry.get("share", 0.0)), 0.0, 1.0)
		if share <= 0.0:
			continue
		var label := String(entry.get("label", "")).strip_edges()
		if label.is_empty():
			label = format_culture_label(String(entry.get("key", "")))
		if label.is_empty():
			continue
		entries.append({"label": label, "share": share})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("share", 0.0)) > float(b.get("share", 0.0))
	)
	var major: Array[String] = []
	var minor: Array[String] = []
	for index in range(entries.size()):
		var entry := entries[index]
		var share := float(entry.get("share", 0.0))
		var label := String(entry.get("label", ""))
		var percentage := int(round(share * 100.0))
		var display := "%s (%d%%)" % [label, percentage] if percentage >= 5 else label
		if index == 0 or share >= 0.22 or (major.size() < 2 and share >= 0.16):
			major.append(display)
		elif share >= 0.08 or minor.size() < 2:
			minor.append(display)
	if major.is_empty() and not minor.is_empty():
		major.append(minor.pop_front() as String)
	return {"major": major, "minor": minor}

func build_tooltip_data(tile_data: Dictionary) -> Dictionary:
	var influence_value: Variant = tile_data.get("cultural_influence", {})
	if not (influence_value is Dictionary):
		return {}
	var influence := influence_value as Dictionary
	if influence.is_empty():
		return {}
	var strength := clampf(float(influence.get("strength", 0.0)), 0.0, 1.0)
	var breakdown: Array[Dictionary] = []
	var breakdown_value: Variant = influence.get("breakdown", [])
	if breakdown_value is Array:
		for entry: Variant in breakdown_value:
			if entry is Dictionary:
				breakdown.append(entry as Dictionary)
	var population_groups := derive_population_groups(breakdown)
	return {
		"label": String(influence.get("label", "Unknown")),
		"color": resolve_culture_color(influence.get("color", Color.GRAY), String(influence.get("key", "humans"))),
		"strength": strength,
		"breakdown": breakdown,
		"major_population_groups": population_groups.get("major", []),
		"minor_population_groups": population_groups.get("minor", [])
	}

func spawn_ambient_structures(
	width: int,
	height: int,
	tiles: Dictionary,
	is_land_base_tile_fn: Callable,
	seed_number: int,
	ambient_structure_options_by_culture: Dictionary
) -> void:
	for y in range(height):
		for x in range(width):
			var coord := Vector2i(x, y)
			var tile := tiles.get(coord, {}) as Dictionary
			if tile.is_empty():
				continue
			tile["ambient_structure"] = null
			tile["detail_ambient_structure"] = null
			if not _can_spawn_ambient_on_tile(coord, tile, is_land_base_tile_fn):
				tiles[coord] = tile
				continue
			var influence_value: Variant = tile.get("cultural_influence", {})
			var influence: Dictionary = {}
			if influence_value is Dictionary:
				influence = influence_value as Dictionary
			if influence.is_empty():
				tiles[coord] = tile
				continue
			var culture_key := String(influence.get("key", ""))
			var options := ambient_structure_options_by_culture.get(culture_key, []) as Array
			if options.is_empty():
				tiles[coord] = tile
				continue
			var strength := clampf(float(influence.get("strength", 0.0)), 0.0, 1.0)
			if strength < 0.24:
				tiles[coord] = tile
				continue
			var chance := clampf(0.015 + strength * 0.10, 0.0, 0.65)
			# The detailed view rewards a denser, lived-in world: a wider net
			# catches extra sites that only surface when the map is zoomed in,
			# leaving the world map itself uncluttered. detail_chance is a
			# superset of chance, so every world-map site also shows up close.
			var detail_chance := clampf(chance * 2.6 + 0.03, 0.0, 0.9)
			var roll := _hash_roll(seed_number, x, y, 433)
			if roll > detail_chance:
				tiles[coord] = tile
				continue
			var option := options[int(_hash_u32(seed_number, x, y, 811) % options.size())] as Dictionary
			if not _ambient_option_matches(option, coord, tiles):
				tiles[coord] = tile
				continue
			# Per-option rarity thins out single-option monster cultures (e.g.
			# harpy roosts) that would otherwise carpet their whole range.
			var rarity := clampf(float(option.get("rarity", 1.0)), 0.0, 1.0)
			if rarity < 1.0 and _hash_roll(seed_number, x, y, 977) > rarity:
				tiles[coord] = tile
				continue
			if roll <= chance:
				tile["ambient_structure"] = option
			else:
				tile["detail_ambient_structure"] = option
			tiles[coord] = tile

func build_culture_overlay_image(
	width: int,
	height: int,
	tiles: Dictionary,
	base_alpha: float = 0.08,
	scale: float = 0.58
) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		for x in range(width):
			var coord := Vector2i(x, y)
			var tile: Dictionary = tiles.get(coord, {}) as Dictionary
			var influence_value: Variant = tile.get("cultural_influence", {})
			var influence: Dictionary = {}
			if influence_value is Dictionary:
				influence = influence_value as Dictionary
			if influence.is_empty():
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var strength := clampf(float(influence.get("strength", 0.0)), 0.0, 1.0)
			var color := resolve_culture_color(influence.get("color", Color.GRAY), String(influence.get("key", "")))
			color.a = clampf(base_alpha + strength * scale, 0.0, 0.78)
			image.set_pixel(x, y, color)

	return image

## Renders realms as translucent culture-coloured fills with a single-cell
## darkened border on every edge against a different owner (including
## unclaimed/water), so states read as closed shapes. The legacy
## _border_color argument is retained for signature compatibility; borders
## are now derived per realm from the fill colour.
func build_political_boundaries_overlay_image(
	width: int,
	height: int,
	tiles: Dictionary,
	_border_color: Color = Color(0.05, 0.03, 0.02, 0.95),
	fill_alpha: float = 0.23,
	border_alpha: float = 0.8
) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	# One fill/border colour per realm, computed once and reused per pixel.
	var realm_colors: Dictionary = {}

	# Fill pass: every claimed tile takes its realm's translucent colour.
	for y in range(height):
		for x in range(width):
			var coord := Vector2i(x, y)
			var owner_key := _political_owner_key(tiles, coord)
			if owner_key.is_empty():
				continue
			var state_name := String((tiles.get(coord, {}) as Dictionary).get("political_state", ""))
			var colors := _resolve_realm_colors(realm_colors, owner_key, state_name, fill_alpha, border_alpha)
			image.set_pixel(x, y, colors["fill"] as Color)

	# Border pass: overwrite the fill on any claimed cell whose 4-neighbour
	# has a different owner with that cell's own darkened realm colour.
	for y in range(height):
		for x in range(width):
			var coord := Vector2i(x, y)
			var owner_key := _political_owner_key(tiles, coord)
			if owner_key.is_empty():
				continue
			if not _political_cell_is_border(tiles, coord, owner_key, width, height):
				continue
			var state_name := String((tiles.get(coord, {}) as Dictionary).get("political_state", ""))
			var colors := _resolve_realm_colors(realm_colors, owner_key, state_name, fill_alpha, border_alpha)
			image.set_pixel(x, y, colors["border"] as Color)
	return image

## Region/detail view wants a thin boundary line, not a full overworld-tile
## band: the coarse overlay paints one pixel per overworld tile, so a 1-tile
## border balloons to a whole SUB×SUB detail footprint (~8 tiles wide) once
## the map is magnified. This renders the overlay at `sub` sub-cells per tile
## and hugs the border only `border_sub` sub-cells deep along the realm edge,
## keeping a light realm fill for territory tint.
func build_region_political_boundaries_overlay_image(
	width: int,
	height: int,
	tiles: Dictionary,
	sub: int,
	border_sub: int = 1,
	fill_alpha: float = 0.16,
	border_alpha: float = 0.85
) -> Image:
	sub = maxi(sub, 1)
	border_sub = clampi(border_sub, 1, sub)
	var image := Image.create(width * sub, height * sub, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var realm_colors: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var coord := Vector2i(x, y)
			var owner_key := _political_owner_key(tiles, coord)
			if owner_key.is_empty():
				continue
			var state_name := String((tiles.get(coord, {}) as Dictionary).get("political_state", ""))
			var colors := _resolve_realm_colors(realm_colors, owner_key, state_name, fill_alpha, border_alpha)
			var fill := colors["fill"] as Color
			var border := colors["border"] as Color
			var edge_left := _region_edge_is_border(tiles, coord, owner_key, width, height, Vector2i(-1, 0))
			var edge_right := _region_edge_is_border(tiles, coord, owner_key, width, height, Vector2i(1, 0))
			var edge_up := _region_edge_is_border(tiles, coord, owner_key, width, height, Vector2i(0, -1))
			var edge_down := _region_edge_is_border(tiles, coord, owner_key, width, height, Vector2i(0, 1))
			var base_x := x * sub
			var base_y := y * sub
			for sy in range(sub):
				for sx in range(sub):
					var on_border := false
					if edge_left and sx < border_sub:
						on_border = true
					elif edge_right and sx >= sub - border_sub:
						on_border = true
					elif edge_up and sy < border_sub:
						on_border = true
					elif edge_down and sy >= sub - border_sub:
						on_border = true
					image.set_pixel(base_x + sx, base_y + sy, border if on_border else fill)
	return image

## True when the orthogonal neighbour in `dir` lies off the map or belongs to a
## different realm (unclaimed/water included) — i.e. that tile edge is a border.
func _region_edge_is_border(tiles: Dictionary, coord: Vector2i, owner_key: String, width: int, height: int, dir: Vector2i) -> bool:
	var neighbor := coord + dir
	if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= width or neighbor.y >= height:
		return true
	return _political_owner_key(tiles, neighbor) != owner_key

func _political_owner_key(tiles: Dictionary, coord: Vector2i) -> String:
	return String((tiles.get(coord, {}) as Dictionary).get("political_owner", "")).strip_edges().to_lower()

## A claimed cell is a border when any orthogonal neighbour lies off the map
## or has a different owner (unclaimed/water included).
func _political_cell_is_border(tiles: Dictionary, coord: Vector2i, owner_key: String, width: int, height: int) -> bool:
	var neighbors: Array[Vector2i] = [
		Vector2i(coord.x + 1, coord.y),
		Vector2i(coord.x - 1, coord.y),
		Vector2i(coord.x, coord.y + 1),
		Vector2i(coord.x, coord.y - 1)
	]
	for neighbor: Vector2i in neighbors:
		if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= width or neighbor.y >= height:
			return true
		if _political_owner_key(tiles, neighbor) != owner_key:
			return true
	return false

## Caches {"fill", "border"} per (owner|state). The state name drives a
## deterministic +-0.04 hue and +-0.08 value shift so neighbouring realms of
## the same culture stay distinct; the border is that colour darkened ~40%.
func _resolve_realm_colors(cache: Dictionary, owner_key: String, state_name: String, fill_alpha: float, border_alpha: float) -> Dictionary:
	var cache_key := "%s|%s" % [owner_key, state_name]
	if cache.has(cache_key):
		return cache[cache_key] as Dictionary
	var base := resolve_culture_color(null, owner_key)
	var state_hash := absi(state_name.hash())
	var hue_shift := (float(state_hash % 1000) / 1000.0 - 0.5) * 0.08
	var value_shift := (float((state_hash / 1000) % 1000) / 1000.0 - 0.5) * 0.16
	var shifted := Color.from_hsv(
		fposmod(base.h + hue_shift, 1.0),
		base.s,
		clampf(base.v + value_shift, 0.0, 1.0)
	)
	var fill := shifted
	fill.a = fill_alpha
	var border := Color(shifted.r * 0.6, shifted.g * 0.6, shifted.b * 0.6, border_alpha)
	var result := {"fill": fill, "border": border}
	cache[cache_key] = result
	return result

func _clear_existing_influence(tiles: Dictionary) -> void:
	for coord: Vector2i in tiles.keys():
		var tile := tiles.get(coord, {}) as Dictionary
		tile["cultural_influence"] = null
		tile["cultural_influence_scores"] = null
		tile["political_owner"] = null
		tile["ambient_structure"] = null
		tiles[coord] = tile

func _build_settlement_sources(settlements: Array[Dictionary]) -> void:
	for settlement: Dictionary in settlements:
		var x := int(settlement.get("x", -1))
		var y := int(settlement.get("y", -1))
		if x < 0 or y < 0:
			continue
		var settlement_type := String(settlement.get("type", "town")).to_lower()
		var entries := _entries_for_settlement(settlement, settlement_type)
		if entries.is_empty():
			continue
		var base_claim_radius := int(CULTURE_TYPES.SETTLEMENT_CLAIM_RADIUS_BY_TYPE.get(settlement_type, 9))
		var type_multiplier := float(CULTURE_TYPES.SETTLEMENT_RADIUS_MULTIPLIER_BY_TYPE.get(settlement_type, 1.0))
		var radius := maxi(8, int(round(base_claim_radius * type_multiplier)))
		var falloff := float(CULTURE_TYPES.SETTLEMENT_FALLOFF_BY_TYPE.get(settlement_type, 1.35))
		add_cultural_source(x, y, radius, entries, falloff)

func _build_faction_sources(factions: Array[Dictionary]) -> void:
	for faction: Dictionary in factions:
		if not faction.has("capital"):
			continue
		var capital := faction.get("capital", {}) as Dictionary
		var x := int(capital.get("x", -1))
		var y := int(capital.get("y", -1))
		if x < 0 or y < 0:
			continue
		var radius := maxi(8, int(faction.get("claim_radius", 12)))
		var key := normalise_culture_key(String(faction.get("key", "humans")), String(faction.get("label", "Humans")))
		var capital_type := String(capital.get("type", "settlement")).strip_edges().to_lower()
		var tile_filter := func(_coord: Vector2i, tile: Dictionary) -> bool:
			return _faction_type_matches_tile(capital_type, tile)
		add_cultural_source(
			x,
			y,
			radius,
			[{"key": key, "label": format_culture_label(key), "color": resolve_culture_color(faction.get("color", null), key), "share": 1.0}],
			1.28,
			tile_filter
		)

func _build_ambient_sources(width: int, height: int, tiles: Dictionary, seed_number: int, wood_elf_territory_info: Dictionary) -> void:
	var stride := maxi(3, mini(6, int(round(float(maxi(width, height)) / 72.0)) + 2))
	for y in range(0, height, stride):
		for x in range(0, width, stride):
			var coord := Vector2i(x, y)
			var tile := tiles.get(coord, {}) as Dictionary
			if tile.is_empty():
				continue
			var base := String(tile.get("base_biome", tile.get("base", tile.get("biome_type", ""))))
			if base == "water":
				_add_water_ambient_source(seed_number, coord, tiles)
				continue
			var biome := String(tile.get("biome_type", base))
			var structure := String(tile.get("structure", "")).to_lower()
			_add_biome_ambient_source(seed_number, coord, biome)
			_add_structure_ambient_source(seed_number, coord, structure)
	if wood_elf_territory_info.has("center"):
		var center := wood_elf_territory_info.get("center", {}) as Dictionary
		var cx := int(center.get("x", -1))
		var cy := int(center.get("y", -1))
		if cx >= 0 and cy >= 0:
			var radius := maxi(10, int(wood_elf_territory_info.get("radius", 14)))
			add_cultural_source(
				cx,
				cy,
				radius,
				[{"key": "wood_elves", "label": "Wood Elves", "color": CULTURE_TYPES.DEFAULT_CULTURE_COLORS["wood_elves"], "share": 1.0}],
				1.1
			)

## Sea peoples: sources roll on open water (browser main.js:7722-7753)
## and their influence lands only on shore tiles that touch the water,
## since influence is never painted onto the sea itself.
func _add_water_ambient_source(seed_number: int, coord: Vector2i, tiles: Dictionary) -> void:
	var coastal_filter := func(candidate_coord: Vector2i, _candidate_tile: Dictionary) -> bool:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var neighbor := tiles.get(candidate_coord + Vector2i(dx, dy), {}) as Dictionary
				if String(neighbor.get("base_biome", neighbor.get("base", ""))) == "water":
					return true
		return false
	var add_roll := func(salt: int, threshold: float, radius: int, key: String, label: String, falloff: float) -> void:
		if _hash_roll(seed_number, coord.x, coord.y, salt) < threshold:
			add_cultural_source(coord.x, coord.y, radius, [{"key": key, "label": label, "color": CULTURE_TYPES.DEFAULT_CULTURE_COLORS.get(key, Color.GRAY), "share": 1.0}], falloff, coastal_filter)
	add_roll.call(12, 0.07, 8, "karkinos", "Karkinos", 1.32)
	add_roll.call(14, 0.06, 8, "locathah", "Locathah", 1.3)
	add_roll.call(16, 0.055, 8, "merfolks", "Merfolks", 1.28)
	add_roll.call(19, 0.045, 7, "hadozee", "Hadozee", 1.35)

func _add_biome_ambient_source(seed_number: int, coord: Vector2i, biome: String) -> void:
	var add_roll := func(salt: int, threshold: float, radius: int, key: String, label: String, falloff: float) -> void:
		if _hash_roll(seed_number, coord.x, coord.y, salt) < threshold:
			add_cultural_source(coord.x, coord.y, radius, [{"key": key, "label": label, "color": CULTURE_TYPES.DEFAULT_CULTURE_COLORS.get(key, Color.GRAY), "share": 1.0}], falloff)

	match biome:
		"grassland":
			add_roll.call(18, 0.08, 6, "humans", "Humans", 1.35)
			add_roll.call(21, 0.05, 7, "half_orcs", "Half-Orcs", 1.4)
			add_roll.call(23, 0.045, 7, "half_elves", "Half-Elves", 1.32)
			add_roll.call(25, 0.04, 8, "centaurs", "Centaurs", 1.45)
			add_roll.call(27, 0.038, 8, "firbolg", "Firbolg", 1.38)
			add_roll.call(29, 0.032, 8, "aarakocra", "Aarakocra", 1.48)
			add_roll.call(31, 0.036, 7, "gnomes", "Gnomes", 1.34)
			add_roll.call(33, 0.028, 8, "ogres", "Ogres", 1.45)
		"forest", "jungle":
			add_roll.call(39, 0.06, 7, "wood_elves", "Wood Elves", 1.2)
			add_roll.call(41, 0.05, 8, "dryad", "Dryad", 1.22)
			add_roll.call(43, 0.048, 8, "leshy", "Leshy", 1.24)
			add_roll.call(45, 0.045, 7, "satyr", "Satyr", 1.28)
			add_roll.call(47, 0.04, 8, "fae", "Fae", 1.2)
			add_roll.call(49, 0.055, 7, "pygmy", "Pygmy", 1.3)
			add_roll.call(52, 0.043, 8, "hadozee", "Hadozee", 1.34)
			add_roll.call(54, 0.042, 8, "snakemen", "Snakemen", 1.36)
		"tundra":
			add_roll.call(44, 0.06, 7, "orc", "Orc", 1.45)
			add_roll.call(56, 0.045, 8, "tuskar", "Tuskar", 1.45)
			add_roll.call(58, 0.04, 8, "fimir", "Fimir", 1.48)
		"desert", "badlands":
			add_roll.call(60, 0.055, 8, "blemaayae", "Blemaayae", 1.34)
			add_roll.call(62, 0.05, 8, "braxat", "Braxat", 1.36)
			add_roll.call(66, 0.045, 8, "quilboar", "Quilboar", 1.4)
			add_roll.call(68, 0.042, 8, "hobgoblin", "Hobgoblin", 1.44)
			add_roll.call(70, 0.038, 8, "gnolls", "Gnolls", 1.46)
		"mountain", "hills":
			# Browser main.js:7809-7827: true mountains (not mere hills)
			# very rarely shelter a dragon, whose territory reaches wider
			# than any other ambient culture's.
			if biome == "mountain":
				add_roll.call(94, 0.013, 10, "dragons", "Dragons", 1.4)
			add_roll.call(71, 0.055, 8, "dwarves", "Dwarves", 1.38)
			add_roll.call(72, 0.045, 8, "aarakocra", "Aarakocra", 1.42)
			add_roll.call(74, 0.04, 8, "giants", "Giants", 1.48)
			add_roll.call(76, 0.038, 8, "harpies", "Harpies", 1.44)
			add_roll.call(78, 0.034, 8, "trolls", "Trolls", 1.48)
			add_roll.call(80, 0.03, 8, "fimir", "Fimir", 1.5)
		"marsh":
			add_roll.call(82, 0.055, 8, "karkinos", "Karkinos", 1.34)
			add_roll.call(84, 0.05, 8, "locathah", "Locathah", 1.32)
			add_roll.call(86, 0.048, 8, "dryad", "Dryad", 1.26)
			add_roll.call(88, 0.046, 8, "leshy", "Leshy", 1.28)
			add_roll.call(90, 0.042, 8, "snakemen", "Snakemen", 1.4)
			add_roll.call(92, 0.04, 8, "merfolks", "Merfolks", 1.34)
	if ["grassland", "badlands", "marsh", "forest", "jungle"].has(biome) and _hash_roll(seed_number, coord.x, coord.y, 51) < 0.05:
		add_cultural_source(coord.x, coord.y, 6, [{"key": "beastmen", "label": "Beastmen", "color": CULTURE_TYPES.DEFAULT_CULTURE_COLORS["beastmen"], "share": 1.0}], 1.4)

func _add_structure_ambient_source(seed_number: int, coord: Vector2i, structure: String) -> void:
	if structure.find("dungeon") >= 0 or structure.find("wizard") >= 0 or structure.find("tower") >= 0 or structure.findn("keep") >= 0:
		if _hash_roll(seed_number, coord.x, coord.y, 61) < 0.6:
			add_cultural_source(coord.x, coord.y, 8, [{"key": "demons", "label": "Demons", "color": CULTURE_TYPES.DEFAULT_CULTURE_COLORS["demons"], "share": 1.0}], 1.65)
	if structure.find("cave") >= 0 and _hash_roll(seed_number, coord.x, coord.y, 63) < 0.22:
		add_cultural_source(coord.x, coord.y, 9, [{"key": "dragons", "label": "Dragons", "color": CULTURE_TYPES.DEFAULT_CULTURE_COLORS["dragons"], "share": 1.0}], 1.7)

func _apply_sources(width: int, height: int, tiles: Dictionary, is_land_base_tile_fn: Callable) -> void:
	for source: Dictionary in _sources:
		var sx := int(source.get("x", 0))
		var sy := int(source.get("y", 0))
		var radius := int(source.get("radius", MIN_RADIUS))
		var radius_sq := radius * radius
		var falloff := float(source.get("falloff", 1.35))
		var min_x := maxi(0, sx - radius)
		var max_x := mini(width - 1, sx + radius)
		var min_y := maxi(0, sy - radius)
		var max_y := mini(height - 1, sy + radius)
		var entries := source.get("entries", []) as Array[Dictionary]
		var tile_filter := source.get("tile_filter", Callable()) as Callable
		for y in range(min_y, max_y + 1):
			var dy := y - sy
			for x in range(min_x, max_x + 1):
				var dx := x - sx
				var dist_sq := dx * dx + dy * dy
				if dist_sq > radius_sq:
					continue
				var coord := Vector2i(x, y)
				if not _can_apply_to_tile(coord, tiles, is_land_base_tile_fn, tile_filter):
					continue
				var distance := sqrt(float(dist_sq))
				var proximity := clampf(1.0 - distance / float(radius), 0.0, 1.0)
				if proximity <= 0.0:
					continue
				var influence_factor := pow(proximity, falloff)
				if influence_factor <= 0.0:
					continue
				# Accumulate into the tile's existing scores dictionary in
				# place; rebuilding it per overlapping source is what made
				# worldgen crawl.
				var tile := tiles[coord] as Dictionary
				var scores_value: Variant = tile.get("cultural_influence_scores")
				var scores: Dictionary
				if scores_value is Dictionary:
					scores = scores_value as Dictionary
				else:
					scores = {}
					tile["cultural_influence_scores"] = scores
				for entry: Dictionary in entries:
					var key := String(entry.get("key", "humans"))
					if not _culture_matches_tile_biome(key, tile):
						continue
					var score := float(entry.get("share", 0.0)) * influence_factor
					if score <= 0.0:
						continue
					scores[key] = float(scores.get(key, 0.0)) + score

func _resolve_scores(width: int, height: int, tiles: Dictionary) -> void:
	for y in range(height):
		for x in range(width):
			var coord := Vector2i(x, y)
			var tile := tiles.get(coord, {}) as Dictionary
			if tile.is_empty():
				continue
			var scores_value: Variant = tile.get("cultural_influence_scores", {})
			var scores: Dictionary = scores_value as Dictionary if scores_value is Dictionary else {}
			if scores.is_empty():
				tile["cultural_influence"] = null
				tile["cultural_influence_scores"] = null
				tiles[coord] = tile
				continue
			var total := 0.0
			var dominant_key := ""
			var dominant_score := -1.0
			for key: String in scores.keys():
				var value := maxf(0.0, float(scores.get(key, 0.0)))
				total += value
				if value > dominant_score:
					dominant_score = value
					dominant_key = key
			if total <= MIN_SCORE or dominant_key.is_empty():
				tile["cultural_influence"] = null
				tile["cultural_influence_scores"] = null
				tiles[coord] = tile
				continue
			var breakdown: Array[Dictionary] = []
			for key: String in scores.keys():
				var absolute_strength := clampf(float(scores.get(key, 0.0)), 0.0, 1.0)
				if absolute_strength <= MIN_SCORE:
					continue
				breakdown.append({
					"key": key,
					"label": format_culture_label(key),
					"color": resolve_culture_color(null, key),
					"strength": absolute_strength,
					"share": clampf(float(scores.get(key, 0.0)) / total, 0.0, 1.0)
				})
			breakdown.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("strength", 0.0)) > float(b.get("strength", 0.0)) )
			tile["cultural_influence"] = {
				"key": dominant_key,
				"label": format_culture_label(dominant_key),
				"color": resolve_culture_color(null, dominant_key),
				"strength": clampf(dominant_score, 0.0, 1.0),
				"breakdown": breakdown
			}
			tile["cultural_influence_scores"] = null
			tiles[coord] = tile


func _assign_political_regions(
	width: int,
	height: int,
	tiles: Dictionary,
	settlements: Array[Dictionary],
	factions: Array[Dictionary],
	is_land_base_tile_fn: Callable,
	seed_number: int
) -> void:
	var seeds := _build_political_seeds(settlements, factions, tiles, seed_number)
	if seeds.is_empty():
		return

	# Bucketed Dijkstra over packed arrays. All per-cell inputs of the
	# step cost (terrain class, dominant culture, jitter, land mask) are
	# precomputed in one pass so the flood's inner loop does no String
	# work; results are identical to the old dictionary flood.
	var cell_count := width * height
	var max_cost := maxi(180, int((width + height) * 1.6))
	var terrain_cost := PackedInt32Array()
	terrain_cost.resize(cell_count)
	var dominant_ids := PackedInt32Array()
	dominant_ids.resize(cell_count)
	var biome_class := PackedInt32Array()
	biome_class.resize(cell_count)
	var jitter := PackedInt32Array()
	jitter.resize(cell_count)
	var land_mask := PackedByteArray()
	land_mask.resize(cell_count)
	var key_ids: Dictionary = {"": 0}
	for y in range(height):
		var row := y * width
		for x in range(width):
			var index := row + x
			var coord := Vector2i(x, y)
			if not _is_land_tile(coord, tiles, is_land_base_tile_fn):
				continue
			land_mask[index] = 1
			var tile := tiles.get(coord, {}) as Dictionary
			var biome := String(tile.get("biome_type", tile.get("base_biome", tile.get("base", "")))).to_lower()
			var base := String(tile.get("base_biome", tile.get("base", biome))).to_lower()
			var overlay := String(tile.get("hill_overlay", "")).to_lower()
			if overlay == "mountain" or base == "mountain" or biome == "mountain":
				terrain_cost[index] = 24
				biome_class[index] = 1
			elif overlay == "hills" or base == "hills" or biome == "hills":
				terrain_cost[index] = 9
			elif base == "marsh" or biome == "marsh":
				terrain_cost[index] = 6
			if biome == "forest" or biome == "jungle":
				biome_class[index] = 2
			elif biome == "grassland":
				biome_class[index] = 3
			var influence_value: Variant = tile.get("cultural_influence", {})
			if influence_value is Dictionary:
				var dominant_key := String((influence_value as Dictionary).get("key", "")).to_lower()
				if not dominant_key.is_empty():
					if not key_ids.has(dominant_key):
						key_ids[dominant_key] = key_ids.size()
					dominant_ids[index] = int(key_ids[dominant_key])
			jitter[index] = int(_hash_u32(seed_number, x, y, 977) % 4)

	# Per-seed precomputation: interned key id and terrain-bonus class.
	var seed_key_ids := PackedInt32Array()
	var seed_bonus_class := PackedInt32Array()
	for political_seed: Dictionary in seeds:
		var owner_key := String(political_seed.get("key", "")).to_lower()
		if not key_ids.has(owner_key):
			key_ids[owner_key] = key_ids.size()
		seed_key_ids.append(int(key_ids[owner_key]))
		match owner_key:
			"dwarves":
				seed_bonus_class.append(1)
			"wood_elves":
				seed_bonus_class.append(2)
			"humans":
				seed_bonus_class.append(3)
			_:
				seed_bonus_class.append(0)

	var costs := PackedInt32Array()
	costs.resize(cell_count)
	costs.fill(1_000_000)
	var owners := PackedInt32Array()
	owners.resize(cell_count)
	owners.fill(-1)
	# One bucket per cost value; entries encode (seed_index << 20) | cell.
	var buckets: Array[PackedInt64Array] = []
	buckets.resize(max_cost + 1)
	for cost in range(max_cost + 1):
		buckets[cost] = PackedInt64Array()

	for seed_index in seeds.size():
		var political_seed := seeds[seed_index]
		var sx := int(political_seed.get("x", -1))
		var sy := int(political_seed.get("y", -1))
		if sx < 0 or sy < 0 or sx >= width or sy >= height:
			continue
		var index := sy * width + sx
		if land_mask[index] == 0:
			continue
		owners[index] = seed_index
		costs[index] = 0
		buckets[0].append((seed_index << 20) | index)

	var neighbor_offsets := PackedInt32Array([-1, 1, -width, width])
	var current_cost := 0
	while current_cost <= max_cost:
		var bucket := buckets[current_cost]
		if bucket.is_empty():
			current_cost += 1
			continue
		var encoded := bucket[bucket.size() - 1]
		bucket.resize(bucket.size() - 1)
		buckets[current_cost] = bucket
		var index := int(encoded & 0xFFFFF)
		var seed_index := int(encoded >> 20)
		if costs[index] != current_cost:
			continue
		var cx := index % width
		var owner_id := seed_key_ids[seed_index]
		var bonus_class := seed_bonus_class[seed_index]
		for offset_index in 4:
			var next := index + neighbor_offsets[offset_index]
			if offset_index == 0 and cx == 0:
				continue
			if offset_index == 1 and cx == width - 1:
				continue
			if next < 0 or next >= cell_count:
				continue
			if land_mask[next] == 0:
				continue
			var step_cost := 10 + terrain_cost[next]
			var dominant := dominant_ids[next]
			if dominant == owner_id:
				step_cost -= 4
			elif dominant != 0:
				step_cost += 8
			if bonus_class == 1 and biome_class[next] == 1:
				step_cost -= 10
			elif bonus_class == 2 and biome_class[next] == 2:
				step_cost -= 7
			elif bonus_class == 3 and biome_class[next] == 3:
				step_cost -= 2
			step_cost = maxi(3, step_cost + jitter[next])
			var new_cost := current_cost + step_cost
			if new_cost > max_cost:
				continue
			if new_cost >= costs[next]:
				continue
			costs[next] = new_cost
			owners[next] = seed_index
			buckets[new_cost].append((seed_index << 20) | next)

	for y in range(height):
		var row := y * width
		for x in range(width):
			var coord := Vector2i(x, y)
			var tile := tiles.get(coord, {}) as Dictionary
			if tile.is_empty():
				continue
			var owner_index := owners[row + x]
			var political_seed: Dictionary = seeds[owner_index] if owner_index >= 0 else {}
			tile["political_owner"] = String(political_seed.get("key", "")).strip_edges().to_lower()
			tile["political_state"] = String(political_seed.get("state_name", "")).strip_edges()

func _build_political_seeds(settlements: Array[Dictionary], factions: Array[Dictionary], tiles: Dictionary, seed_number: int) -> Array[Dictionary]:
	var seeds: Array[Dictionary] = []
	var occupied := {}
	for faction: Dictionary in factions:
		var capital := faction.get("capital", {}) as Dictionary
		var x := int(capital.get("x", -1))
		var y := int(capital.get("y", -1))
		if x < 0 or y < 0:
			continue
		var key := normalise_culture_key(String(faction.get("key", "")), String(faction.get("label", "")))
		var coord := Vector2i(x, y)
		occupied[coord] = true
		seeds.append({
			"x": x,
			"y": y,
			"key": key,
			"weight": 3,
			"state_name": _generate_state_name(key, x, y, seed_number)
		})

	for settlement: Dictionary in settlements:
		var x := int(settlement.get("x", -1))
		var y := int(settlement.get("y", -1))
		if x < 0 or y < 0:
			continue
		var coord := Vector2i(x, y)
		if occupied.has(coord):
			continue
		var tile := tiles.get(coord, {}) as Dictionary
		var influence_value: Variant = tile.get("cultural_influence", {})
		var influence: Dictionary = {}
		if influence_value is Dictionary:
			influence = influence_value as Dictionary
		var key := String(influence.get("key", "humans")).strip_edges()
		if key.is_empty():
			key = "humans"
		var normalized_key := normalise_culture_key(key, "humans")
		seeds.append({
			"x": x,
			"y": y,
			"key": normalized_key,
			"weight": 1,
			"state_name": _generate_state_name(normalized_key, x, y, seed_number)
		})

	return seeds

func _is_land_tile(coord: Vector2i, tiles: Dictionary, is_land_base_tile_fn: Callable) -> bool:
	if not tiles.has(coord):
		return false
	var tile := tiles.get(coord, {}) as Dictionary
	if tile.is_empty():
		return false
	if is_land_base_tile_fn.is_valid():
		return bool(is_land_base_tile_fn.call(coord, tile))
	return String(tile.get("base_biome", tile.get("base", ""))).to_lower() != "water"


func _generate_state_name(culture_key: String, x: int, y: int, seed_number: int) -> String:
	var normalized_key := normalise_culture_key(culture_key, "humans")
	var culture_label := format_culture_label(normalized_key)
	if STATE_FORMS.is_empty():
		return culture_label
	var index := int(_hash_u32(seed_number, x, y, normalized_key.hash()) % STATE_FORMS.size())
	var form := STATE_FORMS[index]
	if form in ["Empire", "Khaganate", "Shogunate", "Caliphate", "Oligarchy", "Union", "Confederation", "League"]:
		return "%s %s" % [culture_label, form]
	return "%s of %s" % [form, culture_label]

func _entries_for_settlement(settlement: Dictionary, settlement_type: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if settlement.has("population_breakdown"):
		var population_breakdown := settlement.get("population_breakdown", []) as Array
		for entry_variant: Variant in population_breakdown:
			if not (entry_variant is Dictionary):
				continue
			var entry := entry_variant as Dictionary
			var label := String(entry.get("label", ""))
			var key := normalise_culture_key(String(entry.get("key", "")), label)
			var percentage := maxf(0.0, float(entry.get("percentage", 0.0)))
			entries.append({
				"key": key,
				"label": label if not label.is_empty() else format_culture_label(key),
				"color": resolve_culture_color(entry.get("color", null), key),
				"share": percentage / 100.0
			})
	if entries.is_empty():
		var fallback := CULTURE_TYPES.DEFAULT_SETTLEMENT_BREAKDOWN_BY_TYPE.get(settlement_type, CULTURE_TYPES.DEFAULT_SETTLEMENT_BREAKDOWN_BY_TYPE.get("town", [])) as Array
		for item_variant: Variant in fallback:
			if item_variant is Dictionary:
				entries.append((item_variant as Dictionary).duplicate(true))
	return _normalize_entries(entries)

func _normalize_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	var total := 0.0
	for entry: Dictionary in entries:
		var label := String(entry.get("label", "")).strip_edges()
		var key := normalise_culture_key(String(entry.get("key", "")), label)
		var share := maxf(0.0, float(entry.get("share", entry.get("percentage", 0.0))))
		if share > 1.0:
			share /= 100.0
		if share <= 0.0:
			continue
		total += share
		normalized.append({
			"key": key,
			"label": label if not label.is_empty() else format_culture_label(key),
			"color": resolve_culture_color(entry.get("color", null), key),
			"share": share
		})
	if total <= 0.0:
		return []
	for entry: Dictionary in normalized:
		entry["share"] = float(entry.get("share", 0.0)) / total
	return normalized

func _can_apply_to_tile(coord: Vector2i, tiles: Dictionary, is_land_base_tile_fn: Callable, tile_filter: Callable) -> bool:
	if not tiles.has(coord):
		return false
	if is_land_base_tile_fn.is_valid() and not bool(is_land_base_tile_fn.call(coord, tiles.get(coord, {}))):
		return false
	if tile_filter.is_valid() and not bool(tile_filter.call(coord, tiles.get(coord, {}))):
		return false
	return true

func _can_spawn_ambient_on_tile(coord: Vector2i, tile: Dictionary, is_land_base_tile_fn: Callable) -> bool:
	if is_land_base_tile_fn.is_valid() and not bool(is_land_base_tile_fn.call(coord, tile)):
		return false
	if String(tile.get("structure", "")).strip_edges() != "":
		return false
	# Settlement tiles carry settlement_type with structure still "" - an
	# ambient stamped there would corrupt the town/dwarfhold/city tile.
	if not String(tile.get("settlement_type", "")).strip_edges().is_empty():
		return false
	return true

func _ambient_option_matches(option: Dictionary, coord: Vector2i, tiles: Dictionary) -> bool:
	# "Tree overlay" means any woodland. Regular woods are labelled "forest"
	# and only jungle carries the literal "tree" tag, so a bare "tree" test
	# silently excluded every temperate forest - which is why lumber mills
	# and hunting lodges (human, tree-gated) never appeared. Match both.
	if bool(option.get("requires_tree_overlay", false)) and not _has_woodland_overlay(coord, tiles):
		return false
	if bool(option.get("requires_tree_neighbor", false)) and not _has_woodland_neighbor(coord, tiles):
		return false
	if bool(option.get("disallow_forest_overlay", false)) and _has_overlay(coord, tiles, "forest"):
		return false
	if bool(option.get("requires_cave_neighbor", false)) and not _has_neighbor_structure(coord, tiles, "cave"):
		return false
	if bool(option.get("requires_mountain_overlay", false)) and not _has_overlay(coord, tiles, "mountain"):
		return false
	if bool(option.get("requires_deep_forest", false)):
		var forest_tile := tiles.get(coord, {}) as Dictionary
		if float(forest_tile.get("forest_canopy_density", 0.0)) < DEEP_FOREST_CANOPY:
			return false
	if bool(option.get("requires_mountain", false)) and not _tile_is_mountain(coord, tiles):
		return false
	var tile := tiles.get(coord, {}) as Dictionary
	var tile_biome := String(tile.get("biome_type", tile.get("base_biome", tile.get("base", "")))).to_lower()
	if bool(option.get("requires_plain_grass", false)):
		if tile_biome != "grassland":
			return false
		var base_biome := String(tile.get("base_biome", tile.get("base", ""))).to_lower()
		if base_biome != "grassland":
			return false
		if not String(tile.get("overlay", "")).strip_edges().is_empty():
			return false
		if not String(tile.get("hill_overlay", "")).strip_edges().is_empty():
			return false
	return true

## True when the tile itself is mountain: either its biome resolves to
## mountain or it carries a mountain overlay. Broader than the overlay-only
## dragon gate, so a bare mountain-biome peak still counts.
func _tile_is_mountain(coord: Vector2i, tiles: Dictionary) -> bool:
	var tile := tiles.get(coord, {}) as Dictionary
	var biome := String(tile.get("biome_type", tile.get("base_biome", tile.get("base", "")))).to_lower()
	if biome == "mountain":
		return true
	return _has_overlay(coord, tiles, "mountain")

## Any woodland on this tile: temperate forest ("forest"), jungle ("tree"),
## or an explicit tree tag. The label split is a worldgen quirk; woodland
## gates should not care which flavour of trees stand here.
func _has_woodland_overlay(coord: Vector2i, tiles: Dictionary) -> bool:
	return _has_overlay(coord, tiles, "tree") or _has_overlay(coord, tiles, "forest")

func _has_woodland_neighbor(coord: Vector2i, tiles: Dictionary) -> bool:
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		if _has_woodland_overlay(coord + offset, tiles):
			return true
	return false

func _has_overlay(coord: Vector2i, tiles: Dictionary, overlay_key: String) -> bool:
	var tile := tiles.get(coord, {}) as Dictionary
	# Trees live in "overlay", mountains and hills in "hill_overlay";
	# gates like requires_mountain_overlay must see both.
	var overlay := "%s %s" % [String(tile.get("overlay", "")), String(tile.get("hill_overlay", ""))]
	return overlay.to_lower().find(overlay_key) >= 0

func _has_neighbor_overlay(coord: Vector2i, tiles: Dictionary, overlay_key: String) -> bool:
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		if _has_overlay(coord + offset, tiles, overlay_key):
			return true
	return false

func _has_neighbor_structure(coord: Vector2i, tiles: Dictionary, structure_key: String) -> bool:
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var tile := tiles.get(coord + offset, {}) as Dictionary
		if String(tile.get("structure", "")).to_lower().find(structure_key) >= 0:
			return true
	return false

func _hash_u32(seed_number: int, x: int, y: int, salt: int) -> int:
	var value: int = seed_number
	value = int(value ^ (x * 374761393))
	value = int(value ^ (y * 668265263))
	value = int(value ^ (salt * 2246822519))
	value = int((value ^ (value >> 13)) * 1274126177)
	value = int(value ^ (value >> 16))
	return value & 0x7fffffff

func _hash_roll(seed_number: int, x: int, y: int, salt: int) -> float:
	return float(_hash_u32(seed_number, x, y, salt) % 1000000) / 1000000.0


func _culture_matches_tile_biome(culture_key: String, tile: Dictionary) -> bool:
	var allowed_biomes: Array = CULTURE_TYPES.CULTURE_BIOME_LIMITS.get(culture_key, [])
	if allowed_biomes.is_empty():
		return true
	var biome := String(tile.get("biome_type", tile.get("base_biome", tile.get("base", "")))).to_lower()
	for allowed: Variant in allowed_biomes:
		if String(allowed).to_lower() == biome:
			return true
	return false


func _faction_type_matches_tile(faction_type: String, tile: Dictionary) -> bool:
	var resolved_type := faction_type.strip_edges().to_lower()
	if resolved_type.is_empty():
		resolved_type = "settlement"
	var base := String(tile.get("base_biome", tile.get("base", tile.get("biome_type", "")))).to_lower()
	var biome := String(tile.get("biome_type", base)).to_lower()
	var overlay := String(tile.get("overlay", "")).to_lower()
	var hill_overlay := String(tile.get("hill_overlay", tile.get("hillOverlay", ""))).to_lower()
	var structure := String(tile.get("structure", "")).to_lower()

	var has_mountain_overlay := overlay.find("mountain") >= 0 or hill_overlay.find("mountain") >= 0
	var has_hill_overlay := overlay.find("hill") >= 0 or hill_overlay.find("hill") >= 0
	var has_tree_overlay := overlay.find("tree") >= 0 or hill_overlay.find("tree") >= 0 or overlay.find("forest") >= 0
	var has_jungle_overlay := overlay.find("jungle") >= 0 or hill_overlay.find("jungle") >= 0

	match resolved_type:
		"dwarfhold", "hillhold":
			if structure.find("dwarfhold") >= 0 or structure.find("hillhold") >= 0:
				return true
			if biome == "mountain" or biome == "hills":
				return true
			return has_mountain_overlay or has_hill_overlay
		"woodelfgrove", "wood_elf_grove":
			if structure.find("wood_elf") >= 0:
				return true
			return biome == "forest" or biome == "jungle" or has_tree_overlay
		"lizardmencity", "lizardmen_city":
			if base == "water":
				return false
			if structure.find("lizardmen") >= 0:
				return true
			if biome == "jungle" or has_jungle_overlay:
				return true
			return biome == "marsh"
		"tower", "evilwizardtower", "evil_wizard_tower":
			if base == "water":
				return false
			if has_mountain_overlay:
				return false
			return true
		"village":
			if base == "water" or has_mountain_overlay:
				return false
			return true
		"town", "city":
			if base == "water":
				return false
			return not has_mountain_overlay
		_:
			return base != "water"
