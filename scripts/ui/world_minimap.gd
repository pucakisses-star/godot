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
const COLOR_WATER := Color(0.20, 0.42, 0.68, 1.0)
const COLOR_ROAD := Color(0.62, 0.48, 0.30, 1.0)
const COLOR_WALL := Color(0.42, 0.42, 0.45, 1.0)
const COLOR_DECOR := Color(0.16, 0.34, 0.16, 1.0)
const COLOR_GROUND := Color(0.28, 0.55, 0.28, 1.0)

const COLOR_PLAYER := Color(1.0, 0.95, 0.45, 1.0)
const COLOR_PLAYER_EDGE := Color(0.15, 0.12, 0.05, 1.0)
const COLOR_NPC := Color(0.85, 0.90, 1.0, 1.0)
const COLOR_GATE := Color(0.95, 0.82, 0.20, 1.0)
const COLOR_LANDMARK := Color(0.95, 0.55, 0.20, 1.0)

var _scene: Node = null
var _city_panel: Control = null
var _radius := RADIUS_DEFAULT
var _collapsed := false

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
	var cursor := (BODY_PX + 2.0 * PAD) - 4.0
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
	var width := BODY_PX + 2.0 * PAD
	var height := HEADER_H if _collapsed else HEADER_H + BODY_PX + 2.0 * PAD
	custom_minimum_size = Vector2(width, height)
	size = Vector2(width, height)


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


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_BG, true)
	draw_rect(Rect2(0.0, 0.0, size.x, HEADER_H), HEADER_BG, true)
	var font := get_theme_default_font()
	if font != null:
		draw_string(font, Vector2(8.0, HEADER_H - 8.0), "Map", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TITLE_COLOR)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER, false, 2.0)
	if _collapsed:
		return
	_draw_body()


func _draw_body() -> void:
	var origin := Vector2(PAD, HEADER_H + PAD)
	var body_rect := Rect2(origin, Vector2(BODY_PX, BODY_PX))
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

	var span := 2 * _radius + 1
	var cell_px := BODY_PX / float(span)
	# One extra pixel on each rect closes the seams between neighbours.
	var rect_size := Vector2(cell_px + 1.0, cell_px + 1.0)
	for dy: int in range(-_radius, _radius + 1):
		for dx: int in range(-_radius, _radius + 1):
			var cell := player_cell + Vector2i(dx, dy)
			var cell_color := _color_for_cell(cell, city, decor, roads, blocked)
			var top_left := origin + Vector2(float(dx + _radius) * cell_px, float(dy + _radius) * cell_px)
			draw_rect(Rect2(top_left, rect_size), cell_color, true)

	_draw_markers(origin, player_cell, cell_px)
	draw_rect(body_rect, BORDER, false, 1.0)


func _color_for_cell(cell: Vector2i, city: TileMapLayer, decor: TileMapLayer, roads: Dictionary, blocked: Dictionary) -> Color:
	if city.get_cell_source_id(cell) < 0:
		return COLOR_UNGENERATED
	if bool(_scene.call("_is_water_cell", cell)):
		return COLOR_WATER
	if roads.has(cell):
		return COLOR_ROAD
	# Walls, buildings, mountains and other barriers read as gray; passable
	# vegetation stays green so paths and open ground stand out.
	if blocked.has(cell) or not bool(_scene.call("_is_walkable_cell", cell)):
		return COLOR_WALL
	if decor != null and decor.get_cell_source_id(cell) >= 0:
		return COLOR_DECOR
	return COLOR_GROUND


func _draw_markers(origin: Vector2, player_cell: Vector2i, cell_px: float) -> void:
	var pip := maxf(2.0, cell_px * 0.55)
	for gate: Dictionary in _read_dict_array("_surface_gates"):
		_draw_pip(origin, player_cell, gate.get("anchor", Vector2i.ZERO) as Vector2i, cell_px, pip, COLOR_GATE)
	for landmark: Dictionary in _read_dict_array("_surface_landmarks"):
		_draw_pip(origin, player_cell, landmark.get("anchor", Vector2i.ZERO) as Vector2i, cell_px, pip, COLOR_LANDMARK)
	for npc: Dictionary in _read_dict_array("_npc_states"):
		_draw_pip(origin, player_cell, npc.get("cell", Vector2i(2147483647, 2147483647)) as Vector2i, cell_px, pip, COLOR_NPC)
	# Player last, dead centre, brighter and larger with a dark rim.
	var center := origin + Vector2(BODY_PX * 0.5, BODY_PX * 0.5)
	var player_r := maxf(3.5, cell_px * 0.9)
	draw_circle(center, player_r + 1.5, COLOR_PLAYER_EDGE)
	draw_circle(center, player_r, COLOR_PLAYER)


func _draw_pip(origin: Vector2, player_cell: Vector2i, cell: Vector2i, cell_px: float, pip: float, color: Color) -> void:
	var rel := cell - player_cell
	if absi(rel.x) > _radius or absi(rel.y) > _radius:
		return
	var point := origin + Vector2(
		(float(rel.x + _radius) + 0.5) * cell_px,
		(float(rel.y + _radius) + 0.5) * cell_px
	)
	draw_circle(point, pip, color)


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
