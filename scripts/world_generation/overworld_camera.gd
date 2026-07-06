extends Camera2D

class_name OverworldCamera

signal zoom_changed(zoom_level: float)

@export var zoom_step: float = 0.1
@export var min_zoom: float = 0.2
@export var max_zoom: float = 4.0
@export var move_speed: float = 600.0
@export var auto_fit_world_on_bounds_set: bool = true

const PAN_THRESHOLD: float = 3.0

var _is_panning := false
var _pan_pointer_index := -1
var _pan_start_screen := Vector2.ZERO
var _pan_start_position := Vector2.ZERO
var _pan_exceeded_threshold := false
var _world_bounds := Rect2()
var _has_world_bounds := false
var _dive_tween: Tween

func _unhandled_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null:
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			adjust_zoom(zoom_step)
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			adjust_zoom(-zoom_step)
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_start_pan(mouse_event.position, -1)
			else:
				_end_pan()
			return

	var touch_event := event as InputEventScreenTouch
	if touch_event != null:
		if touch_event.pressed:
			_start_pan(touch_event.position, touch_event.index)
		else:
			_end_pan()
		return

	var drag_event := event as InputEventScreenDrag
	if drag_event != null:
		_update_pan(drag_event.position, drag_event.index)
		return

	var motion_event := event as InputEventMouseMotion
	if motion_event != null:
		_update_pan(motion_event.position, -1)

## A Dwarf Fortress-style dive: glide onto a spot while zooming in.
## Returns the tween so callers can await the landing.
func dive_to(world_position: Vector2, target_zoom: float, duration: float = 0.85) -> Tween:
	if _dive_tween != null and _dive_tween.is_valid():
		_dive_tween.kill()
	_end_pan()
	var clamped_zoom := clampf(target_zoom, min_zoom, max_zoom)
	_dive_tween = create_tween().set_parallel(true)
	_dive_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_dive_tween.tween_property(self, "global_position", world_position, duration)
	_dive_tween.tween_method(_apply_dive_zoom, zoom.x, clamped_zoom, duration)
	return _dive_tween

func is_diving() -> bool:
	return _dive_tween != null and _dive_tween.is_valid() and _dive_tween.is_running()

func _apply_dive_zoom(zoom_level: float) -> void:
	zoom = Vector2(zoom_level, zoom_level)
	zoom_changed.emit(zoom_level)

func _physics_process(delta: float) -> void:
	if is_diving():
		return
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0

	if direction != Vector2.ZERO:
		global_position += direction.normalized() * move_speed * delta
		_clamp_to_world_bounds()

func adjust_zoom(delta: float) -> void:
	var next_zoom := clampf(zoom.x + delta, min_zoom, max_zoom)
	if is_equal_approx(next_zoom, zoom.x):
		return
	var mouse_world_before := get_global_mouse_position()
	zoom = Vector2(next_zoom, next_zoom)
	var mouse_world_after := get_global_mouse_position()
	global_position += mouse_world_before - mouse_world_after
	_clamp_to_world_bounds()
	zoom_changed.emit(next_zoom)

func set_world_bounds(bounds: Rect2) -> void:
	_world_bounds = bounds
	_has_world_bounds = true
	_update_camera_limits()
	if auto_fit_world_on_bounds_set:
		_fit_to_world_bounds()
	else:
		_clamp_to_world_bounds()

func _fit_to_world_bounds() -> void:
	if not _has_world_bounds:
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	if _world_bounds.size.x <= 0.0 or _world_bounds.size.y <= 0.0:
		return
	var fit_zoom_x := viewport_size.x / _world_bounds.size.x
	var fit_zoom_y := viewport_size.y / _world_bounds.size.y
	var next_zoom := maxf(0.001, minf(fit_zoom_x, fit_zoom_y))
	zoom = Vector2(next_zoom, next_zoom)
	global_position = _world_bounds.position + (_world_bounds.size * 0.5)
	_clamp_to_world_bounds()
	zoom_changed.emit(next_zoom)

func _update_camera_limits() -> void:
	if not _has_world_bounds:
		return
	limit_left = int(floor(_world_bounds.position.x))
	limit_top = int(floor(_world_bounds.position.y))
	limit_right = int(ceil(_world_bounds.position.x + _world_bounds.size.x))
	limit_bottom = int(ceil(_world_bounds.position.y + _world_bounds.size.y))

func _clamp_to_world_bounds() -> void:
	if not _has_world_bounds:
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var half_view := (viewport_size * 0.5) / zoom
	var min_pos := _world_bounds.position + half_view
	var max_pos := _world_bounds.position + _world_bounds.size - half_view
	var clamped := global_position
	if min_pos.x > max_pos.x:
		clamped.x = _world_bounds.position.x + (_world_bounds.size.x * 0.5)
	else:
		clamped.x = clampf(clamped.x, min_pos.x, max_pos.x)
	if min_pos.y > max_pos.y:
		clamped.y = _world_bounds.position.y + (_world_bounds.size.y * 0.5)
	else:
		clamped.y = clampf(clamped.y, min_pos.y, max_pos.y)
	global_position = clamped

func _start_pan(screen_position: Vector2, pointer_index: int) -> void:
	if is_diving():
		return
	_is_panning = true
	_pan_pointer_index = pointer_index
	_pan_start_screen = screen_position
	_pan_start_position = global_position
	_pan_exceeded_threshold = false

func _update_pan(screen_position: Vector2, pointer_index: int) -> void:
	if not _is_panning or _pan_pointer_index != pointer_index:
		return
	var delta := screen_position - _pan_start_screen
	if not _pan_exceeded_threshold and delta.length() > PAN_THRESHOLD:
		_pan_exceeded_threshold = true
		get_viewport().set_input_as_handled()
	if not _pan_exceeded_threshold:
		return
	var world_delta := delta / zoom
	global_position = _pan_start_position - world_delta
	_clamp_to_world_bounds()

func _end_pan() -> void:
	if not _is_panning:
		return
	_is_panning = false
	_pan_pointer_index = -1
