class_name WorldMinimap
extends Control

## Classic corner minimap for the walkable surface town. A small bordered
## panel pinned to a corner of the map viewport: a header bar (Hide / - / +)
## over a square top-down view of the terrain around the player, drawn cell
## by cell with the player centered and NPCs, gates and landmarks as pips.
##
## The map reads live from the owning town scene each redraw (no data is
## copied): it is handed the scene via configure(scene) and the scene calls
## refresh() on a throttle from its _process. Every value is fetched with
## Object.get()/Object.call() so the minimap stays decoupled from the town
## script's static type and survives empty data (e.g. before the surface
## wilds have streamed in).

const BODY_PX := 176.0
const HEADER_H := 24.0
const PAD := 5.0
const TOP_MARGIN := 16.0
# Inset from the map viewport's right edge, and a screen-right fallback used
# only if the viewport rect is not available yet.
const RIGHT_INSET := 12.0
const RIGHT_MARGIN := 286.0

const RADIUS_MIN := 12
const RADIUS_MAX := 64
const RADIUS_STEP := 8
const RADIUS_DEFAULT := 20

const PANEL_BG := Color(0.10, 0.09, 0.07, 0.92)
const HEADER_BG := Color(0.16, 0.14, 0.10, 0.96)
const BORDER := Color(0.75, 0.65, 0.45, 1.0)
const BODY_BG := Color(0.05, 0.06, 0.05, 1.0)
const TITLE_COLOR := Color(0.90, 0.82, 0.60, 1.0)

const COLOR_UNGENERATED := Color(0.03, 0.03, 0.04, 0.55)
## Fog of war on the expanded view: never-visited ground is solid black.
const COLOR_UNEXPLORED := Color(0.0, 0.0, 0.0, 1.0)
## Chunk geometry of the scene's exploration bitmask; must match the
## EXPLORE_CHUNK_* constants in town_generation.gd.
const EXPLORE_CHUNK_SHIFT := 5
const EXPLORE_CHUNK_SIZE := 1 << EXPLORE_CHUNK_SHIFT
const COLOR_WATER := Color(0.20, 0.42, 0.68, 1.0)
const COLOR_ROAD := Color(0.62, 0.48, 0.30, 1.0)
const COLOR_WALL := Color(0.42, 0.42, 0.45, 1.0)
const COLOR_DECOR := Color(0.16, 0.34, 0.16, 1.0)
const COLOR_GROUND := Color(0.28, 0.55, 0.28, 1.0)

const TILE_ATLAS_DEFS := preload("res://scripts/world_generation/tile_atlas_defs.gd")

## Rich per-tile palette: the map paints what the ground actually IS -
## sand gold, snow white, shallow fords pale, marsh murk, hold streets
## warm - instead of collapsing everything into grass green and barrier
## gray. Prefix rules, first match wins, so specifics precede generics.
const TILE_COLOR_RULES: Array = [
	["water_shallow", Color(0.38, 0.62, 0.78, 1.0)],
	["water", Color(0.20, 0.42, 0.68, 1.0)],
	["massif_rock_dark", Color(0.30, 0.31, 0.36, 1.0)],
	["massif_rock_top", Color(0.56, 0.57, 0.62, 1.0)],
	["massif_rock", Color(0.44, 0.45, 0.50, 1.0)],
	["sandstone", Color(0.72, 0.60, 0.42, 1.0)],
	["sand", Color(0.79, 0.71, 0.46, 1.0)],
	["snow_rock", Color(0.62, 0.66, 0.68, 1.0)],
	["snow", Color(0.87, 0.89, 0.92, 1.0)],
	["ice_brick", Color(0.66, 0.78, 0.86, 1.0)],
	["grass_dark", Color(0.19, 0.40, 0.20, 1.0)],
	["grass", Color(0.28, 0.55, 0.28, 1.0)],
	["flowers", Color(0.62, 0.48, 0.58, 1.0)],
	["tree", Color(0.10, 0.28, 0.13, 1.0)],
	["hedge", Color(0.20, 0.42, 0.22, 1.0)],
	["stump", Color(0.42, 0.32, 0.20, 1.0)],
	["cactus", Color(0.30, 0.52, 0.26, 1.0)],
	["palm", Color(0.28, 0.48, 0.24, 1.0)],
	["desert_bones", Color(0.80, 0.78, 0.68, 1.0)],
	["desert_rock", Color(0.60, 0.44, 0.32, 1.0)],
	["sealed_gate", Color(0.20, 0.20, 0.26, 1.0)],
	["gravestone", Color(0.58, 0.58, 0.62, 1.0)],
	["stone_coffin", Color(0.58, 0.58, 0.62, 1.0)],
	["statue", Color(0.62, 0.62, 0.66, 1.0)],
	["fountain", Color(0.45, 0.60, 0.75, 1.0)],
	["street_lamp", Color(0.95, 0.80, 0.40, 1.0)],
	["chest", Color(0.76, 0.56, 0.26, 1.0)],
	["ruin", Color(0.60, 0.60, 0.64, 1.0)],
	["web", Color(0.78, 0.78, 0.80, 1.0)],
	["plaza", Color(0.62, 0.59, 0.52, 1.0)],
	["road", Color(0.62, 0.48, 0.30, 1.0)],
	["floor", Color(0.56, 0.46, 0.32, 1.0)],
	["wall", Color(0.38, 0.35, 0.33, 1.0)],
	["door", Color(0.72, 0.52, 0.26, 1.0)],
	["stairway", Color(0.92, 0.84, 0.46, 1.0)],
	["fence", Color(0.50, 0.38, 0.24, 1.0)],
	["bed", Color(0.62, 0.30, 0.30, 1.0)],
	["table", Color(0.52, 0.40, 0.26, 1.0)],
	["bench", Color(0.52, 0.40, 0.26, 1.0)],
	["shelf", Color(0.52, 0.40, 0.26, 1.0)],
	["dresser", Color(0.52, 0.40, 0.26, 1.0)],
	["stool", Color(0.52, 0.40, 0.26, 1.0)],
	["barrel", Color(0.55, 0.40, 0.24, 1.0)],
	["keg", Color(0.55, 0.40, 0.24, 1.0)],
	["sack", Color(0.66, 0.56, 0.38, 1.0)],
	["grain_bag", Color(0.66, 0.56, 0.38, 1.0)],
	["anvil", Color(0.40, 0.40, 0.44, 1.0)],
	["workbench", Color(0.52, 0.40, 0.26, 1.0)],
	["armor_stand", Color(0.55, 0.55, 0.60, 1.0)],
	["mud", Color(0.40, 0.32, 0.22, 1.0)],
	["dirt", Color(0.46, 0.36, 0.25, 1.0)]
]

## The hold's own kit (the embedded dwarfhold city, tile source 1) gets
## explicit colors so its streets, walls and stairways read on the map.
const HOLD_TILE_COLORS := {
	"stone": Color(0.33, 0.30, 0.29, 1.0),
	"stone_face": Color(0.38, 0.35, 0.33, 1.0),
	"floor": Color(0.58, 0.48, 0.34, 1.0),
	"dirt": Color(0.46, 0.36, 0.25, 1.0),
	"dirt_alt": Color(0.42, 0.33, 0.23, 1.0),
	"dirt_shadow": Color(0.38, 0.30, 0.21, 1.0),
	"door": Color(0.80, 0.60, 0.30, 1.0),
	"stairway_down": Color(0.95, 0.85, 0.45, 1.0),
	"stairway_up": Color(0.95, 0.85, 0.45, 1.0)
}

## Reverse atlas lookups (coords -> tile key), built lazily on first use.
var _town_key_by_coords: Dictionary = {}
var _hold_key_by_coords: Dictionary = {}

const COLOR_PLAYER := Color(1.0, 0.95, 0.45, 1.0)
const COLOR_PLAYER_EDGE := Color(0.15, 0.12, 0.05, 1.0)
const COLOR_NPC := Color(0.85, 0.90, 1.0, 1.0)
const COLOR_GATE := Color(0.95, 0.82, 0.20, 1.0)
const COLOR_LANDMARK := Color(0.95, 0.55, 0.20, 1.0)

const EXPANDED_FILL := 0.8
const EXPANDED_MAX_PX := 720.0
const EXPANDED_RADIUS_SCALE := 2

var _scene: Node = null
var _city_panel: Control = null
var _radius := RADIUS_DEFAULT
var _collapsed := false
## Pressing M blows the corner map up to a large centred view; pressing it
## again drops back to the corner. Expanded shows a wider radius.
var _expanded := false


## The map body's side length in pixels: the compact square by default, or a
## large centred square (a fraction of the shorter screen side) when expanded.
func _body_px() -> float:
	if not _expanded:
		return BODY_PX
	var short_side := EXPANDED_MAX_PX
	var viewport := get_viewport()
	if viewport != null:
		var view_size := viewport.get_visible_rect().size
		short_side = minf(view_size.x, view_size.y)
	return clampf(short_side * EXPANDED_FILL, BODY_PX, EXPANDED_MAX_PX)


## Cells shown around the player: the expanded view widens the radius so the
## bigger map also reveals more ground, not just larger tiles.
func _view_radius() -> int:
	if _expanded:
		return mini(RADIUS_MAX, _radius * EXPANDED_RADIUS_SCALE)
	return _radius

var _hide_button: Button
var _zoom_out_button: Button
var _zoom_in_button: Button


func _ready() -> void:
	# Parented to the scene's root Control (a plain Control, so it is not
	# stretched the way a container child would be). Eat clicks so poking the
	# map through the minimap does not start a world pan.
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 25
	_build_header_buttons()
	_apply_size()


## M toggles the expanded view. Handled as unhandled key input so a focused
## text field (e.g. the seed box) still types an "m" normally.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_M:
		_toggle_expanded()
		get_viewport().set_input_as_handled()


func _toggle_expanded() -> void:
	_expanded = not _expanded
	if _expanded:
		# Expanding always reveals the map, even from the collapsed stub.
		_collapsed = false
		_hide_button.text = "Hide"
		_zoom_in_button.visible = true
		_zoom_out_button.visible = true
	_reposition()
	queue_redraw()


func configure(scene: Node) -> void:
	_scene = scene
	var panel_variant: Variant = scene.get("city_panel")
	if panel_variant is Control:
		_city_panel = panel_variant as Control
		if not _city_panel.resized.is_connected(_reposition):
			_city_panel.resized.connect(_reposition)
	_reposition()
	queue_redraw()


## Called on a throttle from the town scene's _process: recenter on the
## player and repaint. Cheap enough to call whenever the player cell moves.
func refresh() -> void:
	_reposition()
	queue_redraw()


func _build_header_buttons() -> void:
	_zoom_in_button = _make_header_button("+")
	_zoom_in_button.pressed.connect(_on_zoom_in_pressed)
	_zoom_out_button = _make_header_button("-")
	_zoom_out_button.pressed.connect(_on_zoom_out_pressed)
	_hide_button = _make_header_button("Hide")
	_hide_button.pressed.connect(_on_hide_pressed)
	_layout_header_buttons()


func _make_header_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 11)
	add_child(button)
	return button


func _layout_header_buttons() -> void:
	var button_h := HEADER_H - 6.0
	var top := 3.0
	var cursor := (_body_px() + 2.0 * PAD) - 4.0
	var square_w := 22.0
	var hide_w := 44.0
	cursor -= square_w
	_zoom_in_button.position = Vector2(cursor, top)
	_zoom_in_button.size = Vector2(square_w, button_h)
	cursor -= square_w + 2.0
	_zoom_out_button.position = Vector2(cursor, top)
	_zoom_out_button.size = Vector2(square_w, button_h)
	cursor -= hide_w + 2.0
	_hide_button.position = Vector2(cursor, top)
	_hide_button.size = Vector2(hide_w, button_h)


func _apply_size() -> void:
	var body := _body_px()
	var width := body + 2.0 * PAD
	var height := HEADER_H if _collapsed else HEADER_H + body + 2.0 * PAD
	custom_minimum_size = Vector2(width, height)
	size = Vector2(width, height)
	_layout_header_buttons()


## Pin to the top-right of the map viewport. The surrounding layout can be
## taller than the window (the controls column overflows vertically), so Y
## is pinned to the screen top; only the panel's right edge is tracked for X,
## which maps 1:1 to screen space.
func _reposition() -> void:
	_apply_size()
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	if _expanded:
		# Centre the big map on the map viewport.
		var viewport := get_viewport()
		var view_size := viewport.get_visible_rect().size if viewport != null else size
		var center_x := _screen_right_edge() - RIGHT_MARGIN * 0.5
		if _city_panel != null and is_instance_valid(_city_panel):
			var rect := _city_panel.get_global_rect()
			if rect.size.x > 1.0:
				center_x = rect.position.x + rect.size.x * 0.5
		position = Vector2(center_x - size.x * 0.5, maxf(TOP_MARGIN, (view_size.y - size.y) * 0.5))
		return
	var right_edge := _screen_right_edge()
	position = Vector2(right_edge - size.x - RIGHT_INSET, TOP_MARGIN)


func _screen_right_edge() -> float:
	if _city_panel != null and is_instance_valid(_city_panel):
		var rect := _city_panel.get_global_rect()
		if rect.size.x > 1.0:
			return rect.end.x
	var viewport := get_viewport()
	if viewport != null:
		return viewport.get_visible_rect().size.x - RIGHT_MARGIN
	return size.x + RIGHT_INSET


func _on_hide_pressed() -> void:
	_collapsed = not _collapsed
	# Hiding while expanded must also drop the expanded layout, or the
	# collapsed header keeps the big map's width and stays floating
	# dead-center of the screen instead of docking back to the corner.
	if _collapsed and _expanded:
		_expanded = false
	_hide_button.text = "Show" if _collapsed else "Hide"
	_zoom_in_button.visible = not _collapsed
	_zoom_out_button.visible = not _collapsed
	_reposition()
	queue_redraw()


func _on_zoom_out_pressed() -> void:
	# Zooming out shows more ground: widen the cell radius.
	_radius = mini(_radius + RADIUS_STEP, RADIUS_MAX)
	queue_redraw()


func _on_zoom_in_pressed() -> void:
	_radius = maxi(_radius - RADIUS_STEP, RADIUS_MIN)
	queue_redraw()


## Mouse wheel over the map zooms it (in the corner and, above all, in the
## expanded M view): up tightens onto the player, down pulls back to reveal
## more ground. The event is eaten so the same scroll never also zooms the
## world behind the map.
func _gui_input(event: InputEvent) -> void:
	if _collapsed:
		return
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		_on_zoom_in_pressed()
		accept_event()
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_on_zoom_out_pressed()
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_BG, true)
	draw_rect(Rect2(0.0, 0.0, size.x, HEADER_H), HEADER_BG, true)
	var font := get_theme_default_font()
	if font != null:
		var title := "Map — M to close" if _expanded else "Map"
		draw_string(font, Vector2(8.0, HEADER_H - 8.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TITLE_COLOR)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER, false, 2.0)
	if _collapsed:
		return
	_draw_body()


func _draw_body() -> void:
	var body := _body_px()
	var radius := _view_radius()
	var origin := Vector2(PAD, HEADER_H + PAD)
	var body_rect := Rect2(origin, Vector2(body, body))
	draw_rect(body_rect, BODY_BG, true)
	if _scene == null or not is_instance_valid(_scene):
		draw_rect(body_rect, BORDER, false, 1.0)
		return
	var city_variant: Variant = _scene.get("city_layer")
	if not (city_variant is TileMapLayer):
		draw_rect(body_rect, BORDER, false, 1.0)
		return
	var city := city_variant as TileMapLayer
	var decor_variant: Variant = _scene.get("decor_layer")
	var decor := decor_variant as TileMapLayer if decor_variant is TileMapLayer else null
	var player_cell := _read_vector2i("_player_cell")
	var roads := _read_dictionary("_surface_road_cells")
	var blocked := _read_dictionary("_surface_blocked_cells")
	# Cells the wilds have not streamed in yet are coloured straight from the
	# overworld biome field, so the whole map reads as land/sea instead of a
	# black void beyond the small live chunk around the player.
	var biome_ctx := _read_dictionary("_surface_biome_ctx")
	var world_origin := _read_vector2i("_surface_world_origin")
	# Fog of war applies to the expanded (M) view only: ground the walker
	# has never seen draws solid black. The docked corner map stays as-is.
	# Scenes without an exploration mask keep the regular unmasked render.
	var explored_variant: Variant = _scene.get("_explored_chunks") if _expanded else null
	var fog_enabled := explored_variant is Dictionary
	var explored: Dictionary = explored_variant as Dictionary if fog_enabled else {}

	var span := 2 * radius + 1
	var cell_px := body / float(span)
	# One extra pixel on each rect closes the seams between neighbours.
	var rect_size := Vector2(cell_px + 1.0, cell_px + 1.0)
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var cell := player_cell + Vector2i(dx, dy)
			var top_left := origin + Vector2(float(dx + radius) * cell_px, float(dy + radius) * cell_px)
			if fog_enabled and not _is_explored_cell(cell, explored, world_origin):
				draw_rect(Rect2(top_left, rect_size), COLOR_UNEXPLORED, true)
				continue
			var cell_color := _color_for_cell(cell, city, decor, roads, blocked, biome_ctx, world_origin)
			draw_rect(Rect2(top_left, rect_size), cell_color, true)

	_draw_markers(origin, player_cell, cell_px, radius, body, fog_enabled, explored, world_origin)
	draw_rect(body_rect, BORDER, false, 1.0)


func _color_for_cell(cell: Vector2i, city: TileMapLayer, decor: TileMapLayer, roads: Dictionary, blocked: Dictionary, biome_ctx: Dictionary, world_origin: Vector2i) -> Color:
	var source_id := city.get_cell_source_id(cell)
	if source_id < 0:
		# Not streamed: paint from the overworld biome field so the map shows
		# the surrounding land and sea instead of black.
		if biome_ctx.is_empty():
			return COLOR_UNGENERATED
		return _biome_color(SurfaceWorldService.biome_for_world_cell(biome_ctx, cell + world_origin))
	# The embedded dwarfhold city paints from the hold's own kit.
	if source_id == 1:
		var hold_key := _tile_key_for(city.get_cell_atlas_coords(cell), true)
		if HOLD_TILE_COLORS.has(hold_key):
			return HOLD_TILE_COLORS[hold_key] as Color
		var hold_rule := _rule_color(hold_key)
		return hold_rule if hold_rule.a > 0.0 else COLOR_GROUND
	var city_key := _tile_key_for(city.get_cell_atlas_coords(cell), false)
	if bool(_scene.call("_is_water_cell", cell)):
		return COLOR_WATER
	if roads.has(cell):
		return COLOR_ROAD
	# Decor draws over its ground: canopies, lamps, graves, furniture.
	if decor != null and decor.get_cell_source_id(cell) >= 0:
		var decor_color := _rule_color(_tile_key_for(decor.get_cell_atlas_coords(cell), false))
		if decor_color.a > 0.0:
			return decor_color
	# Barriers whose tile the palette knows keep their own look (a stone
	# range reads gray-blue, a timber wall brown); the rest stay gray.
	if blocked.has(cell) or not bool(_scene.call("_is_walkable_cell", cell)):
		var barrier_color := _rule_color(city_key)
		return barrier_color if barrier_color.a > 0.0 else COLOR_WALL
	if decor != null and decor.get_cell_source_id(cell) >= 0:
		return COLOR_DECOR
	var ground_color := _rule_color(city_key)
	return ground_color if ground_color.a > 0.0 else COLOR_GROUND

## First matching prefix rule, or transparent when the key is unknown so
## the caller can fall back to its coarse family color.
func _rule_color(tile_key: String) -> Color:
	if tile_key.is_empty():
		return Color(0, 0, 0, 0)
	for rule: Array in TILE_COLOR_RULES:
		if tile_key.begins_with(String(rule[0])):
			return rule[1] as Color
	return Color(0, 0, 0, 0)

## Reverse lookup from painted atlas coords to the tile key that put them
## there, for both the town atlas (source 0) and the hold kit (source 1).
func _tile_key_for(coords: Vector2i, hold_source: bool) -> String:
	if _town_key_by_coords.is_empty():
		for key_variant: Variant in TILE_ATLAS_DEFS.TOWN_TILE_ATLAS.keys():
			var coords_variant: Variant = TILE_ATLAS_DEFS.TOWN_TILE_ATLAS[key_variant]
			if coords_variant is Vector2i:
				_town_key_by_coords[coords_variant] = String(key_variant)
		for key_variant: Variant in TILE_ATLAS_DEFS.DWARFHOLD_TILE_ATLAS.keys():
			var coords_variant: Variant = TILE_ATLAS_DEFS.DWARFHOLD_TILE_ATLAS[key_variant]
			if coords_variant is Vector2i:
				_hold_key_by_coords[coords_variant] = String(key_variant)
	if hold_source:
		return String(_hold_key_by_coords.get(coords, ""))
	return String(_town_key_by_coords.get(coords, ""))


## Overworld-biome colour for cells the wilds have not streamed in, so the
## expanded map reads as a real map of the surrounding land.
func _biome_color(biome: String) -> Color:
	match biome:
		"water":
			return COLOR_WATER
		"forest":
			return COLOR_DECOR
		"jungle":
			return Color(0.12, 0.30, 0.14, 1.0)
		"desert":
			return Color(0.80, 0.72, 0.45, 1.0)
		"badlands":
			return Color(0.55, 0.40, 0.28, 1.0)
		"mountain":
			return COLOR_WALL
		"hills":
			return Color(0.40, 0.50, 0.30, 1.0)
		"tundra":
			return Color(0.72, 0.76, 0.74, 1.0)
		"marsh":
			return Color(0.24, 0.38, 0.32, 1.0)
		_:
			return COLOR_GROUND


func _draw_markers(origin: Vector2, player_cell: Vector2i, cell_px: float, radius: int, body: float, fog_enabled: bool, explored: Dictionary, world_origin: Vector2i) -> void:
	var pip := clampf(cell_px * 0.55, 2.0, 6.0)
	# Under fog, pips only show on explored ground; the player always draws.
	for gate: Dictionary in _read_dict_array("_surface_gates"):
		var gate_cell := gate.get("anchor", Vector2i.ZERO) as Vector2i
		if fog_enabled and not _is_explored_cell(gate_cell, explored, world_origin):
			continue
		_draw_pip(origin, player_cell, gate_cell, cell_px, pip, radius, COLOR_GATE)
	for landmark: Dictionary in _read_dict_array("_surface_landmarks"):
		var landmark_cell := landmark.get("anchor", Vector2i.ZERO) as Vector2i
		if fog_enabled and not _is_explored_cell(landmark_cell, explored, world_origin):
			continue
		_draw_pip(origin, player_cell, landmark_cell, cell_px, pip, radius, COLOR_LANDMARK)
	for npc: Dictionary in _read_dict_array("_npc_states"):
		var npc_cell := npc.get("cell", Vector2i(2147483647, 2147483647)) as Vector2i
		if fog_enabled and not _is_explored_cell(npc_cell, explored, world_origin):
			continue
		_draw_pip(origin, player_cell, npc_cell, cell_px, pip, radius, COLOR_NPC)
	# Player last, dead centre, brighter and larger with a dark rim.
	var center := origin + Vector2(body * 0.5, body * 0.5)
	var player_r := clampf(cell_px * 0.9, 3.5, 7.0)
	draw_circle(center, player_r + 1.5, COLOR_PLAYER_EDGE)
	draw_circle(center, player_r, COLOR_PLAYER)


func _draw_pip(origin: Vector2, player_cell: Vector2i, cell: Vector2i, cell_px: float, pip: float, radius: int, color: Color) -> void:
	var rel := cell - player_cell
	if absi(rel.x) > radius or absi(rel.y) > radius:
		return
	var point := origin + Vector2(
		(float(rel.x + radius) + 0.5) * cell_px,
		(float(rel.y + radius) + 0.5) * cell_px
	)
	draw_circle(point, pip, color)


## Bit lookup into the scene's world-space exploration bitmask (one bit per
## cell, 32x32-cell chunks); scene cells convert through the world origin.
func _is_explored_cell(cell: Vector2i, explored: Dictionary, world_origin: Vector2i) -> bool:
	var world_cell := cell + world_origin
	var chunk := Vector2i(world_cell.x >> EXPLORE_CHUNK_SHIFT, world_cell.y >> EXPLORE_CHUNK_SHIFT)
	var mask_variant: Variant = explored.get(chunk)
	if not (mask_variant is PackedByteArray):
		return false
	var mask := mask_variant as PackedByteArray
	var local_index := (world_cell.y & (EXPLORE_CHUNK_SIZE - 1)) * EXPLORE_CHUNK_SIZE + (world_cell.x & (EXPLORE_CHUNK_SIZE - 1))
	var byte_index := local_index >> 3
	if byte_index >= mask.size():
		return false
	return (mask[byte_index] & (1 << (local_index & 7))) != 0


func _read_vector2i(property: String) -> Vector2i:
	var value: Variant = _scene.get(property)
	return value if value is Vector2i else Vector2i.ZERO


func _read_dictionary(property: String) -> Dictionary:
	var value: Variant = _scene.get(property)
	return value if value is Dictionary else {}


func _read_dict_array(property: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var value: Variant = _scene.get(property)
	if value is Array:
		for entry: Variant in value as Array:
			if entry is Dictionary:
				result.append(entry as Dictionary)
	return result
