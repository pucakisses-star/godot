extends Control

const AXIS_LABEL_COLOR := Color(0.78, 0.82, 0.9, 0.95)
const AXIS_LINE_COLOR := Color(0.32, 0.36, 0.45, 0.9)
const CHART_LINE_COLOR := Color(0.85, 0.9, 0.95, 0.9)
const CHART_POINT_COLOR := Color(0.95, 0.95, 1.0, 0.95)
const CHART_POINT_HOVER_COLOR := Color(1.0, 0.95, 0.55, 0.95)

var points: Array = []
var _hovered_index := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	## _mouse_exited is not a virtual method; connect it so the hover
	## highlight clears when the pointer leaves the chart.
	mouse_exited.connect(_mouse_exited)

func set_points(data: Array) -> void:
	points = data.duplicate()
	_hovered_index = -1
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_motion_event := event as InputEventMouseMotion
		var index := _point_index_at_position(mouse_motion_event.position)
		if _hovered_index != index:
			_hovered_index = index
			queue_redraw()

func _mouse_exited() -> void:
	if _hovered_index != -1:
		_hovered_index = -1
		queue_redraw()

func _get_tooltip(at_position: Vector2) -> String:
	var index := _point_index_at_position(at_position)
	if index == -1:
		return ""
	var entry := points[index] as Dictionary
	var year := int(entry.get("year", index + 1))
	var population := int(entry.get("population", 0))
	return "Year %d\nPopulation: %d" % [year, population]

func _chart_area() -> Rect2:
	var rect_size := size
	var left_margin := 52.0
	var right_margin := 10.0
	var top_margin := 10.0
	var bottom_margin := 30.0
	return Rect2(
		Vector2(left_margin, top_margin),
		rect_size - Vector2(left_margin + right_margin, top_margin + bottom_margin)
	)

func _point_index_at_position(pointer_position: Vector2) -> int:
	var chart_points := _compute_chart_points()
	if chart_points.is_empty():
		return -1
	var nearest := -1
	var nearest_distance := INF
	for index in range(chart_points.size()):
		var distance := chart_points[index].distance_to(pointer_position)
		if distance < nearest_distance:
			nearest = index
			nearest_distance = distance
	return nearest if nearest_distance <= 12.0 else -1

func _compute_chart_points() -> PackedVector2Array:
	var plot := _chart_area()
	if plot.size.x <= 0.0 or plot.size.y <= 0.0:
		return PackedVector2Array()

	var values: Array[float] = []
	for entry: Dictionary in points:
		values.append(float(entry.get("population", 0.0)))
	if values.is_empty():
		return PackedVector2Array()

	var min_value: float = values.min()
	var max_value: float = values.max()
	if is_equal_approx(min_value, max_value):
		max_value = min_value + 1.0

	var chart_points := PackedVector2Array()
	for index in range(values.size()):
		var ratio := 0.0
		if values.size() > 1:
			ratio = float(index) / float(values.size() - 1)
		var x := plot.position.x + plot.size.x * ratio
		var value_ratio: float = (values[index] - min_value) / (max_value - min_value)
		var y: float = plot.position.y + plot.size.y * (1.0 - value_ratio)
		chart_points.append(Vector2(x, y))
	return chart_points

func _draw_axis_labels(plot: Rect2, min_value: float, max_value: float) -> void:
	var axis_font := get_theme_default_font()
	# Y-axis label and value range
	draw_string(axis_font, Vector2(6.0, plot.position.y - 2.0), "Population", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, AXIS_LABEL_COLOR)
	# draw_string's position is the LEFT edge of the alignment box, so a
	# right-aligned box must start box-width short of the target edge —
	# otherwise these labels land inside the plot / past the widget.
	draw_string(axis_font, Vector2(plot.position.x - 6.0 - 46.0, plot.position.y + 4.0), str(int(round(max_value))), HORIZONTAL_ALIGNMENT_RIGHT, 46.0, 11, AXIS_LABEL_COLOR)
	draw_string(axis_font, Vector2(plot.position.x - 6.0 - 46.0, plot.end.y), str(int(round(min_value))), HORIZONTAL_ALIGNMENT_RIGHT, 46.0, 11, AXIS_LABEL_COLOR)
	# X-axis label and year range
	var start_year := 1
	var end_year := points.size()
	if not points.is_empty():
		start_year = int((points[0] as Dictionary).get("year", 1))
		end_year = int((points[points.size() - 1] as Dictionary).get("year", points.size()))
	draw_string(axis_font, Vector2(plot.position.x, plot.end.y + 18.0), str(start_year), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, AXIS_LABEL_COLOR)
	draw_string(axis_font, Vector2(plot.end.x - 40.0, plot.end.y + 18.0), str(end_year), HORIZONTAL_ALIGNMENT_RIGHT, 40.0, 11, AXIS_LABEL_COLOR)
	draw_string(axis_font, Vector2(plot.position.x + plot.size.x * 0.5 - 24.0, plot.end.y + 18.0), "Year", HORIZONTAL_ALIGNMENT_CENTER, 48.0, 12, AXIS_LABEL_COLOR)

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return

	draw_rect(rect, Color(0.08, 0.08, 0.1, 0.6), true)
	var plot := _chart_area()
	if plot.size.x <= 0.0 or plot.size.y <= 0.0:
		return

	var chart_points := _compute_chart_points()
	if chart_points.size() == 0:
		draw_rect(plot, Color(0.2, 0.2, 0.25, 0.6), true)
		return

	var min_value := INF
	var max_value := -INF
	for entry: Dictionary in points:
		var population := float(entry.get("population", 0.0))
		min_value = minf(min_value, population)
		max_value = maxf(max_value, population)
	if is_equal_approx(min_value, max_value):
		max_value = min_value + 1.0

	draw_line(plot.position, Vector2(plot.position.x, plot.end.y), AXIS_LINE_COLOR, 1.0)
	draw_line(Vector2(plot.position.x, plot.end.y), plot.end, AXIS_LINE_COLOR, 1.0)
	_draw_axis_labels(plot, min_value, max_value)

	if chart_points.size() >= 2:
		draw_polyline(chart_points, CHART_LINE_COLOR, 2.0, true)
	for index in range(chart_points.size()):
		var point := chart_points[index]
		var is_hovered := index == _hovered_index
		draw_circle(point, 4.5 if is_hovered else 2.5, CHART_POINT_HOVER_COLOR if is_hovered else CHART_POINT_COLOR)
