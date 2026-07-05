extends CanvasLayer
class_name EscapeMenu

## The pause menu, shared by every scene: ESC toggles it, the game
## pauses underneath, and it offers Resume / Save / Return to the world
## map / Main Menu / Quit. Scenes create it in code:
##   _escape_menu = EscapeMenu.new()
##   _escape_menu.show_return_to_map = true   # settlement scenes only
##   add_child(_escape_menu)

const OVERWORLD_SCENE_PATH := "res://scenes/overworld.tscn"
const MAIN_MENU_SCENE_PATH := "res://scenes/mainmenu.tscn"

var show_return_to_map := false

var _dimmer: ColorRect
var _panel: PanelContainer
var _status_label: Label

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dimmer = ColorRect.new()
	_dimmer.color = Color(0.0, 0.0, 0.0, 0.55)
	_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dimmer)

	_panel = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.13, 0.11, 0.10, 0.97)
	panel_style.border_color = Color(0.72, 0.6, 0.4, 1.0)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 26
	panel_style.content_margin_right = 26
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", panel_style)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	_panel.add_child(layout)

	var title := Label.new()
	title.text = "— Paused —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.93, 0.87, 0.72, 1.0))
	layout.add_child(title)

	_add_button(layout, "Resume", _on_resume_pressed)
	_add_button(layout, "Save Game", _on_save_pressed)
	if show_return_to_map:
		_add_button(layout, "Return to World Map", _on_return_pressed)
	_add_button(layout, "Main Menu", _on_main_menu_pressed)
	_add_button(layout, "Quit Game", _on_quit_pressed)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.text = ""
	layout.add_child(_status_label)

	visible = false

func _add_button(layout: VBoxContainer, label_text: String, handler: Callable) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(220, 34)
	button.pressed.connect(handler)
	layout.add_child(button)

## The scene's ESC handler is pause-blocked while the menu is open, so
## the menu (which processes during pause) closes itself.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func is_open() -> bool:
	return visible

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	_status_label.text = ""
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

func _on_resume_pressed() -> void:
	close()

func _on_save_pressed() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("save_to_file"):
		_status_label.text = "Saving unavailable"
		return
	var result: int = int(game_session.call("save_to_file"))
	_status_label.text = "Game saved" if result == OK else "Save failed (%d)" % result

func _on_return_pressed() -> void:
	get_tree().paused = false
	SceneCacheService.request_change(self, OVERWORLD_SCENE_PATH)

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	SceneCacheService.request_clear(self)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()
