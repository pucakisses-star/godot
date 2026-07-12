extends Control

var slices: Array = []

func _ready() -> void:
	# The chart lives inside the cursor-following map tooltip: it must
	# never swallow clicks (a plain Control defaults to STOP, which ate
	# map clicks whenever edge-clamping parked the tooltip under the
	# cursor).
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_slices(data: Array) -> void:
	slices = data.duplicate()
	queue_redraw()

func _draw() -> void:
	var rect := get_rect()
	var radius := minf(rect.size.x, rect.size.y) * 0.5
	if radius <= 0.0:
		return
	var center := rect.size * 0.5
	if slices.is_empty():
		draw_circle(center, radius, Color(0.2, 0.2, 0.2, 0.5))
		return

	var total := 0.0
	for entry: Dictionary in slices:
		total += float(entry.get("percentage", 0.0))
	if total <= 0.0:
		draw_circle(center, radius, Color(0.2, 0.2, 0.2, 0.5))
		return

	var start_angle := -PI / 2.0
	for entry: Dictionary in slices:
		var percentage := float(entry.get("percentage", 0.0))
		if percentage <= 0.0:
			continue
		var slice_angle := TAU * (percentage / total)
		var steps := maxi(6, int(round(slice_angle / (PI / 18.0))))
		var points := PackedVector2Array()
		points.append(center)
		for index in range(steps + 1):
			var angle := start_angle + slice_angle * (float(index) / float(steps))
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		var color_value: Variant = entry.get("color", Color(0.7, 0.7, 0.7))
		var slice_color: Color = color_value if color_value is Color else Color(str(color_value))
		var colors := PackedColorArray()
		colors.resize(points.size())
		for i in range(points.size()):
			colors[i] = slice_color
		draw_polygon(points, colors)
		start_angle += slice_angle

	draw_arc(center, radius, 0.0, TAU, 48, Color(0.1, 0.1, 0.1, 0.6), 1.0)
