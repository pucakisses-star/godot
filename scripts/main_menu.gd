extends Control

## The front door: Start forges a new world, Load Game opens the slot
## browser - every save listed with its character, world, day and
## location, plus per-slot Load and Delete.

@onready var load_game_button: Button = %LoadGameButton

var _load_panel: PanelContainer
var _slot_list: VBoxContainer

func _ready() -> void:
	SaveGameService.migrate_legacy_save()
	_refresh_load_button()

func _refresh_load_button() -> void:
	if load_game_button == null:
		return
	load_game_button.disabled = not SaveGameService.has_any_save()

func _on_start_button_pressed() -> void:
	# A new game must not inherit the previously loaded save's slot, or
	# the first manual save would overwrite that older world.
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("set_current_slot"):
		session.call("set_current_slot", "")
	get_tree().change_scene_to_file("res://scenes/character_creator.tscn")

func _on_options_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/options_menu.tscn")

func _on_shattered_pixel_dungeon_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/shattered_pixel_dungeon_windows.tscn")

func _on_load_game_button_pressed() -> void:
	_ensure_load_panel()
	_populate_slot_list()
	_load_panel.visible = true

func _on_return_button_pressed() -> void:
	get_tree().quit()

## --- the Load Game screen ----------------------------------------------

func _ensure_load_panel() -> void:
	if _load_panel != null:
		return
	var dimmer := ColorRect.new()
	dimmer.name = "LoadDimmer"
	dimmer.color = Color(0.02, 0.02, 0.03, 0.8)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)
	_load_panel = PanelContainer.new()
	_load_panel.name = "LoadGamePanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.085, 0.07, 0.98)
	style.border_color = Color(0.72, 0.6, 0.4, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18)
	_load_panel.add_theme_stylebox_override("panel", style)
	_load_panel.set_anchors_preset(Control.PRESET_CENTER)
	_load_panel.custom_minimum_size = Vector2(560.0, 380.0)
	dimmer.add_child(_load_panel)
	_load_panel.position = Vector2.ZERO
	dimmer.visible = false
	# Born hidden, so the first open actually fires visibility_changed.
	_load_panel.visible = false
	_load_panel.visibility_changed.connect(func() -> void:
		dimmer.visible = _load_panel.visible
		if _load_panel.visible:
			_load_panel.reset_size()
			_load_panel.position = (dimmer.size - _load_panel.size) * 0.5)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	_load_panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = "Load Game"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.93, 0.87, 0.72, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.pressed.connect(func() -> void: _load_panel.visible = false)
	header.add_child(close_button)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520.0, 300.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	_slot_list = VBoxContainer.new()
	_slot_list.add_theme_constant_override("separation", 8)
	_slot_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_slot_list)

func _populate_slot_list() -> void:
	for stale: Node in _slot_list.get_children():
		stale.queue_free()
	var saves: Array[Dictionary] = SaveGameService.list_saves()
	if saves.is_empty():
		var empty := Label.new()
		empty.text = "No saved games yet."
		_slot_list.add_child(empty)
		return
	for meta: Dictionary in saves:
		var row := PanelContainer.new()
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0.16, 0.13, 0.1, 1.0)
		row_style.border_color = Color(0.45, 0.38, 0.28, 1.0)
		row_style.set_border_width_all(1)
		row_style.set_corner_radius_all(5)
		row_style.set_content_margin_all(10)
		row.add_theme_stylebox_override("panel", row_style)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_slot_list.add_child(row)
		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 12)
		row.add_child(row_box)
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_box.add_child(text_box)
		var label := Label.new()
		label.text = String(meta.get("label", meta.get("slot_id", "Save")))
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78, 1.0))
		text_box.add_child(label)
		var detail := Label.new()
		detail.text = SaveGameService.describe(meta)
		detail.add_theme_font_size_override("font_size", 12)
		detail.modulate = Color(0.85, 0.82, 0.75, 1.0)
		text_box.add_child(detail)
		var stamp := Label.new()
		stamp.text = String(meta.get("saved_at_text", ""))
		stamp.add_theme_font_size_override("font_size", 10)
		stamp.modulate = Color(0.65, 0.62, 0.56, 1.0)
		text_box.add_child(stamp)
		var load_slot_button := Button.new()
		load_slot_button.text = "Load"
		load_slot_button.custom_minimum_size = Vector2(72.0, 0.0)
		load_slot_button.pressed.connect(_on_slot_load_pressed.bind(String(meta.get("slot_id", ""))))
		row_box.add_child(load_slot_button)
		var delete_button := Button.new()
		delete_button.text = "Delete"
		delete_button.modulate = Color(1.0, 0.75, 0.7, 1.0)
		delete_button.pressed.connect(_on_slot_delete_pressed.bind(String(meta.get("slot_id", ""))))
		row_box.add_child(delete_button)

func _on_slot_load_pressed(slot_id: String) -> void:
	var resume_scene: String = SaveGameService.load_slot(self, slot_id)
	if resume_scene.is_empty():
		_populate_slot_list()
		return
	get_tree().change_scene_to_file(resume_scene)

func _on_slot_delete_pressed(slot_id: String) -> void:
	SaveGameService.delete_slot(slot_id)
	_populate_slot_list()
	_refresh_load_button()
