extends RefCounted
class_name DwarfHoldUiInputHandler

static func move_direction_from_event(event: InputEvent) -> Vector2i:
	if _is_move_pressed(event, "ui_left", KEY_A):
		return Vector2i.LEFT
	if _is_move_pressed(event, "ui_right", KEY_D):
		return Vector2i.RIGHT
	if _is_move_pressed(event, "ui_up", KEY_W):
		return Vector2i.UP
	if _is_move_pressed(event, "ui_down", KEY_S):
		return Vector2i.DOWN
	return Vector2i.ZERO

## Polled every frame for held-key movement: arrows and WASD both count,
## opposite keys cancel, and two axes together read as a diagonal.
static func current_move_input_direction() -> Vector2i:
	var direction := Vector2i.ZERO
	if Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A):
		direction.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D):
		direction.x += 1
	if Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W):
		direction.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S):
		direction.y += 1
	return direction

static func handle_city_panel_event(
	event: InputEvent,
	handle_player_click_action: Callable,
	apply_zoom: Callable,
	update_hover_tooltip: Callable,
	set_is_panning: Callable,
	is_panning: bool,
	pan_by: Callable,
	update_city_layer_transform: Callable
) -> bool:
	var currently_panning := is_panning
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_MIDDLE or mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			currently_panning = mouse_button.pressed
			set_is_panning.call(currently_panning)
		if mouse_button.pressed:
			if mouse_button.button_index == MOUSE_BUTTON_LEFT:
				handle_player_click_action.call(mouse_button.position)
			if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
				apply_zoom.call(0.1, mouse_button.position)
			elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				apply_zoom.call(-0.1, mouse_button.position)
	if event is InputEventMouseMotion and currently_panning:
		var motion := event as InputEventMouseMotion
		pan_by.call(motion.relative)
		update_city_layer_transform.call()
	if event is InputEventMouse:
		update_hover_tooltip.call((event as InputEventMouse).position)
	return currently_panning

static func _is_move_pressed(event: InputEvent, action_name: StringName, wasd_key: Key) -> bool:
	if event.is_action_pressed(action_name):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == wasd_key
