extends Control

## Cartographic scale bar: alternating segments with end ticks. The bar's
## pixel length always matches the labelled distance - when the ideal bar
## would be too long or short, the labelled distance is stepped through the
## 1/2/5 sequence until the bar fits, instead of clamping pixels.

@export var segment_count: int = 4
@export var bar_height: float = 10.0
@export var stroke_color: Color = Color(0.92, 0.89, 0.78, 0.95)
@export var light_segment_color: Color = Color(0.93, 0.9, 0.8, 0.95)
@export var dark_segment_color: Color = Color(0.24, 0.2, 0.14, 0.95)
@export var target_pixel_width: float = 150.0
@export var min_pixel_width: float = 90.0
@export var max_pixel_width: float = 210.0

const NICE_STEPS: Array[float] = [1.0, 2.0, 3.0, 5.0]

var _bar_pixel_width: float = 120.0
var _display_distance_km: float = 100.0

func _ready() -> void:
	custom_minimum_size = Vector2(max_pixel_width + 8.0, bar_height + 10.0)
	queue_redraw()

func set_scale_display(pixels_per_km: float) -> void:
	if pixels_per_km <= 0.0:
		visible = false
		return
	visible = true
	var distance := _pick_nice_distance(target_pixel_width / pixels_per_km)
	var width := distance * pixels_per_km
	var guard := 0
	while width < min_pixel_width and guard < 12:
		distance = _step_nice_distance(distance, 1)
		width = distance * pixels_per_km
		guard += 1
	guard = 0
	while width > max_pixel_width and guard < 12:
		distance = _step_nice_distance(distance, -1)
		width = distance * pixels_per_km
		guard += 1
	_display_distance_km = distance
	_bar_pixel_width = width
	queue_redraw()

func get_distance_label() -> String:
	return "%s km" % _format_number(_display_distance_km)

func _draw() -> void:
	var left := (size.x - _bar_pixel_width) * 0.5
	var top := (size.y - bar_height) * 0.5
	var safe_segments := maxi(segment_count, 1)
	var segment_width := _bar_pixel_width / float(safe_segments)
	for i in range(safe_segments):
		var rect := Rect2(Vector2(left + segment_width * float(i), top), Vector2(segment_width, bar_height))
		draw_rect(rect, dark_segment_color if i % 2 == 0 else light_segment_color, true)
	draw_rect(Rect2(Vector2(left, top), Vector2(_bar_pixel_width, bar_height)), stroke_color, false, 1.0)
	var tick_top := top - 3.0
	var tick_bottom := top + bar_height + 3.0
	draw_line(Vector2(left, tick_top), Vector2(left, tick_bottom), stroke_color, 1.0)
	draw_line(Vector2(left + _bar_pixel_width, tick_top), Vector2(left + _bar_pixel_width, tick_bottom), stroke_color, 1.0)
	draw_line(
		Vector2(left + _bar_pixel_width * 0.5, top + bar_height),
		Vector2(left + _bar_pixel_width * 0.5, tick_bottom),
		stroke_color,
		1.0
	)

func _pick_nice_distance(target_distance: float) -> float:
	var safe_target: float = maxf(target_distance, 0.001)
	var exponent: float = floor(log(safe_target) / log(10.0))
	var magnitude: float = pow(10.0, exponent)
	var normalized: float = safe_target / magnitude
	var step: float = 10.0
	for candidate in NICE_STEPS:
		if normalized <= candidate:
			step = candidate
			break
	return step * magnitude

func _step_nice_distance(distance: float, direction: int) -> float:
	var safe_distance: float = maxf(distance, 0.001)
	var exponent: float = floor(log(safe_distance) / log(10.0) + 0.0001)
	var magnitude: float = pow(10.0, exponent)
	var normalized: float = safe_distance / magnitude
	var index := 0
	var best_error := INF
	for i in range(NICE_STEPS.size()):
		var err := absf(NICE_STEPS[i] - normalized)
		if err < best_error:
			best_error = err
			index = i
	index += direction
	if index >= NICE_STEPS.size():
		return NICE_STEPS[0] * magnitude * 10.0
	if index < 0:
		return NICE_STEPS[NICE_STEPS.size() - 1] * magnitude * 0.1
	return NICE_STEPS[index] * magnitude

func _format_number(value: float) -> String:
	if value >= 100.0:
		return str(int(round(value)))
	if value >= 10.0:
		return String.num(value, 1)
	return String.num(value, 2)
