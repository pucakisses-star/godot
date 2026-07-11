extends CanvasLayer
class_name GameOverScreen

## Death is the end of a story, not a respawn. This full-screen modal
## replaces the old wake-up-at-home flow in every scene: the tree pauses
## beneath it (no control, no second death) and the only ways out are the
## three doors — load a previous save, roll a NEW character into the SAME
## world (everything the dead walker did persists and time continues from
## the death date), or abandon the world for the main menu.
##
## Scenes stamp the death details before adding it:
##   _game_over = GameOverScreen.new()
##   _game_over.character_name = ...   # who died
##   _game_over.place_name = ...       # where
##   _game_over.date_line = ...        # GameCalendar.date_text(...)
##   _game_over.cause_name = ...       # what did it
##   add_child(_game_over)

const MAIN_MENU_SCENE_PATH := "res://scenes/mainmenu.tscn"
const CHARACTER_CREATOR_SCENE_PATH := "res://scenes/character_creator.tscn"

var character_name := "A wanderer"
var place_name := "the wilds"
var date_line := ""
var cause_name := ""

var _panel: PanelContainer
var _main_box: VBoxContainer
var _confirm_box: VBoxContainer
var _confirm_label: Label
var _confirm_button: Button
var _load_box: VBoxContainer
var _slot_list: VBoxContainer
var _status_label: Label
var _pending_confirm: Callable = Callable()

func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.06, 0.01, 0.01, 0.78)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The backdrop swallows every click so nothing beneath can be poked.
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	_panel = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.09, 0.08, 0.98)
	panel_style.border_color = Color(0.62, 0.28, 0.22, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 34
	panel_style.content_margin_right = 34
	panel_style.content_margin_top = 22
	panel_style.content_margin_bottom = 22
	_panel.add_theme_stylebox_override("panel", panel_style)
	# A CenterContainer keeps the panel dead-center even as the sub-views
	# (menu / confirm / slot list) swap its size around.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.add_child(_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	_panel.add_child(layout)

	var title := Label.new()
	title.text = "You Have Died"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.88, 0.34, 0.28, 1.0))
	layout.add_child(title)

	var name_label := Label.new()
	name_label.text = character_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", Color(0.93, 0.87, 0.72, 1.0))
	layout.add_child(name_label)

	var cause_label := Label.new()
	cause_label.text = _cause_line()
	cause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cause_label.add_theme_font_size_override("font_size", 13)
	cause_label.modulate = Color(0.85, 0.78, 0.7, 1.0)
	layout.add_child(cause_label)

	var date_label := Label.new()
	date_label.text = date_line
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	date_label.add_theme_font_size_override("font_size", 13)
	date_label.modulate = Color(0.75, 0.7, 0.62, 1.0)
	date_label.visible = not date_line.is_empty()
	layout.add_child(date_label)

	layout.add_child(HSeparator.new())

	_build_main_box(layout)
	_build_confirm_box(layout)
	_build_load_box(layout)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.text = ""
	layout.add_child(_status_label)

	_show_view(_main_box)
	visible = true
	get_tree().paused = true

func _cause_line() -> String:
	var cause := cause_name.strip_edges()
	if cause == "starvation":
		return "Starved to death in %s" % place_name
	if cause.is_empty():
		return "Perished in %s" % place_name
	return "Slain by %s in %s" % [cause, place_name]

func _build_main_box(layout: VBoxContainer) -> void:
	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 8)
	layout.add_child(_main_box)
	_add_button(_main_box, "Load a Save", _on_load_save_pressed)
	_add_button(_main_box, "New Character, Same World", _on_new_character_pressed)
	_add_button(_main_box, "Abandon World", _on_abandon_world_pressed)

func _build_confirm_box(layout: VBoxContainer) -> void:
	_confirm_box = VBoxContainer.new()
	_confirm_box.add_theme_constant_override("separation", 8)
	layout.add_child(_confirm_box)
	_confirm_label = Label.new()
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_label.custom_minimum_size = Vector2(340.0, 0.0)
	_confirm_label.add_theme_font_size_override("font_size", 13)
	_confirm_box.add_child(_confirm_label)
	_confirm_button = _add_button(_confirm_box, "Confirm", _on_confirm_pressed)
	_add_button(_confirm_box, "Back", _on_back_pressed)

func _build_load_box(layout: VBoxContainer) -> void:
	_load_box = VBoxContainer.new()
	_load_box.add_theme_constant_override("separation", 8)
	layout.add_child(_load_box)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420.0, 220.0)
	_load_box.add_child(scroll)
	_slot_list = VBoxContainer.new()
	_slot_list.add_theme_constant_override("separation", 6)
	_slot_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_slot_list)
	_add_button(_load_box, "Back", _on_back_pressed)

func _add_button(host: VBoxContainer, label_text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(300, 36)
	button.pressed.connect(handler)
	host.add_child(button)
	return button

func _show_view(view: VBoxContainer) -> void:
	_main_box.visible = view == _main_box
	_confirm_box.visible = view == _confirm_box
	_load_box.visible = view == _load_box
	# The panel shrinks back around whichever view is showing.
	_panel.reset_size()

## There is no escaping death: ESC only backs out of the sub-views.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if _confirm_box.visible or _load_box.visible:
			_show_view(_main_box)
		get_viewport().set_input_as_handled()

## --- Load a Save ---------------------------------------------------------

func _on_load_save_pressed() -> void:
	_populate_slot_list()
	_show_view(_load_box)

func _populate_slot_list() -> void:
	for stale: Node in _slot_list.get_children():
		stale.queue_free()
	var saves: Array[Dictionary] = SaveGameService.list_saves()
	if saves.is_empty():
		var empty := Label.new()
		empty.text = "No saved games. Death stands."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_slot_list.add_child(empty)
		return
	for meta: Dictionary in saves:
		var row := PanelContainer.new()
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0.17, 0.13, 0.11, 1.0)
		row_style.border_color = Color(0.45, 0.36, 0.28, 1.0)
		row_style.set_border_width_all(1)
		row_style.set_corner_radius_all(5)
		row_style.set_content_margin_all(8)
		row.add_theme_stylebox_override("panel", row_style)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_slot_list.add_child(row)
		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 10)
		row.add_child(row_box)
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_box.add_child(text_box)
		var label := Label.new()
		label.text = String(meta.get("label", meta.get("slot_id", "Save")))
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78, 1.0))
		text_box.add_child(label)
		var detail := Label.new()
		detail.text = SaveGameService.describe(meta)
		detail.add_theme_font_size_override("font_size", 11)
		detail.modulate = Color(0.85, 0.82, 0.75, 1.0)
		text_box.add_child(detail)
		var load_button := Button.new()
		load_button.text = "Load"
		load_button.custom_minimum_size = Vector2(64.0, 0.0)
		load_button.pressed.connect(_on_slot_load_pressed.bind(String(meta.get("slot_id", ""))))
		row_box.add_child(load_button)

func _on_slot_load_pressed(slot_id: String) -> void:
	var resume_scene: String = SaveGameService.load_slot(self, slot_id)
	if resume_scene.is_empty():
		_status_label.text = "That save could not be loaded."
		_populate_slot_list()
		return
	# Parked scenes hold the dead timeline; the loaded save must rebuild.
	get_tree().paused = false
	SceneCacheService.request_clear(self)
	get_tree().change_scene_to_file(resume_scene)

## --- New character / abandon world ----------------------------------------

func _on_new_character_pressed() -> void:
	_confirm_label.text = (
		"A new dwarf takes up the tale in the same world. Everything %s did — and lost — remains, and time marches on from this day." % character_name
	)
	_confirm_button.text = "Confirm: New Character"
	_pending_confirm = Callable(self, "_do_new_character")
	_show_view(_confirm_box)

func _on_abandon_world_pressed() -> void:
	_confirm_label.text = "Leave this world to its fate and return to the main menu. Anything not saved is lost."
	_confirm_button.text = "Confirm: Abandon World"
	_pending_confirm = Callable(self, "_do_abandon_world")
	_show_view(_confirm_box)

func _on_confirm_pressed() -> void:
	if _pending_confirm.is_valid():
		_pending_confirm.call()

func _on_back_pressed() -> void:
	_pending_confirm = Callable()
	_show_view(_main_box)

func _do_new_character() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("begin_new_character_in_world"):
		_status_label.text = "Session unavailable."
		return
	session.call("begin_new_character_in_world")
	get_tree().paused = false
	SceneCacheService.request_clear(self)
	get_tree().change_scene_to_file(CHARACTER_CREATOR_SCENE_PATH)

func _do_abandon_world() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("abandon_world"):
		session.call("abandon_world")
	get_tree().paused = false
	SceneCacheService.request_clear(self)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
