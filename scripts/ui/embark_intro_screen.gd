extends CanvasLayer
class_name EmbarkIntroScreen

## The "Strike the earth!" screen: a parchment panel that greets a new
## character the first time they stand in the world, telling their embark
## story in their own trade's voice. The tree pauses beneath it and the
## backdrop swallows every click, so the world waits until the reader taps
## Okay. Scenes stamp the details before adding it:
##   var intro := EmbarkIntroScreen.new()
##   intro.character = session.get_player_character()
##   intro.world_name = _world_name
##   intro.year = _chronology_year
##   add_child(intro)

var character: Dictionary = {}
var world_name := ""
var year := 1

## Shows the embark story once, the first time a freshly created (or reborn)
## character enters a playable game scene — a settlement, the wilds, or a
## dungeon. Every entry point just calls EmbarkIntroScreen.maybe_present(self)
## from its _ready; the character-scoped flag makes it a no-op on save-loads
## and on later scene changes. Reads the world name and year from the session.
static func maybe_present(host: Node) -> void:
	if host == null:
		return
	var session := host.get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("should_show_embark_intro"):
		return
	if not bool(session.call("should_show_embark_intro")):
		return
	session.call("mark_embark_intro_shown")
	var settings: Dictionary = session.call("get_world_settings") if session.has_method("get_world_settings") else {}
	var chronology_variant: Variant = settings.get("chronology", {})
	var resolved_year := 1
	if chronology_variant is Dictionary:
		resolved_year = maxi(1, int((chronology_variant as Dictionary).get("year", 1)))
	var intro := EmbarkIntroScreen.new()
	intro.character = session.call("get_player_character") as Dictionary
	intro.world_name = String(settings.get("world_name", ""))
	intro.year = resolved_year
	host.add_child(intro)

func _ready() -> void:
	layer = 94
	process_mode = Node.PROCESS_MODE_ALWAYS

	var dimmer := ColorRect.new()
	dimmer.color = Color(0.03, 0.02, 0.01, 0.82)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.14, 0.11, 0.08, 0.99)
	panel_style.border_color = Color(0.74, 0.6, 0.36, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 30
	panel_style.content_margin_right = 30
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var story := EmbarkIntroService.compose(character, world_name, year)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	layout.custom_minimum_size = Vector2(560.0, 0.0)
	panel.add_child(layout)

	var title := Label.new()
	title.text = String(story.get("title", "A Dwarven Expedition"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.93, 0.82, 0.5, 1.0))
	layout.add_child(title)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.custom_minimum_size = Vector2(560.0, 0.0)
	body.add_theme_font_size_override("normal_font_size", 15)
	body.add_theme_font_size_override("bold_font_size", 15)
	body.add_theme_color_override("default_color", Color(0.92, 0.87, 0.76, 1.0))
	body.text = String(story.get("body", ""))
	layout.add_child(body)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(button_row)
	var okay := Button.new()
	okay.text = "Strike the earth!"
	okay.custom_minimum_size = Vector2(200.0, 38.0)
	okay.pressed.connect(_dismiss)
	button_row.add_child(okay)
	okay.grab_focus()

	visible = true
	get_tree().paused = true

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_dismiss()

func _dismiss() -> void:
	get_tree().paused = false
	queue_free()
