class_name NpcInspectionCard
extends PanelContainer

## The right-click dossier: a citizen's name and trade over the slot
## grid of what they carry, plus their purse. One card serves the whole
## scene - inspecting another NPC repopulates it in place. Esc or a
## click outside the panel closes it. Built entirely in code so both
## the town and the hold can spawn one.

const SLOT_COUNT := 6
const SLOT_COLUMNS := 3
const SLOT_SIZE := Vector2(46, 46)

var _header_label: Label
var _coins_label: Label
var _slot_panels: Array[PanelContainer] = []
var _slot_icons: Array[TextureRect] = []
var _slot_counts: Array[Label] = []

func _init() -> void:
	_build_ui()
	visible = false

## Rolls (once) and shows the NPC's belongings. The roll is stored on
## the state so later trade systems mutate the same kit the card shows.
func open(npc_state: Dictionary, role_title: String, seed_value: int) -> void:
	var identity := npc_state.get("identity", {}) as Dictionary
	if not (npc_state.get("belongings") is Dictionary):
		npc_state["belongings"] = SettlementEconomyService.npc_belongings(
			identity, int(npc_state.get("role", 0)), seed_value)
	var belongings := npc_state["belongings"] as Dictionary
	var profession := String(identity.get("profession", role_title))
	_header_label.text = "%s — %s" % [String(identity.get("name", "A stranger")), profession]
	_populate_slots(belongings.get("items", []) as Array)
	_coins_label.text = "🪙 %d coins" % int(belongings.get("coins", 0))
	visible = true
	reset_size()
	_center_in_parent()

func close() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	# Click-away for the screen regions no other control swallows; clicks
	# on the map panel close the card through the scene's click handlers.
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.pressed and not get_global_rect().has_point(mouse_button.global_position):
		close()

func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.12, 0.09, 1.0)
	style.border_color = Color(0.72, 0.58, 0.38, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	layout.add_child(header)
	_header_label = Label.new()
	_header_label.add_theme_font_size_override("font_size", 15)
	_header_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72, 1.0))
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_header_label)
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var grid := GridContainer.new()
	grid.columns = SLOT_COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	layout.add_child(grid)
	for _slot in SLOT_COUNT:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = SLOT_SIZE
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.24, 0.18, 0.13, 1.0)
		slot_style.border_color = Color(0.5, 0.4, 0.28, 1.0)
		slot_style.set_border_width_all(2)
		slot_style.set_corner_radius_all(5)
		panel.add_theme_stylebox_override("panel", slot_style)
		var icon_rect := TextureRect.new()
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.add_child(icon_rect)
		var count_label := Label.new()
		count_label.add_theme_font_size_override("font_size", 11)
		count_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8, 1.0))
		count_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06, 1.0))
		count_label.add_theme_constant_override("outline_size", 3)
		panel.add_child(count_label)
		grid.add_child(panel)
		_slot_panels.append(panel)
		_slot_icons.append(icon_rect)
		_slot_counts.append(count_label)

	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 13)
	_coins_label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.7, 1.0))
	layout.add_child(_coins_label)

func _populate_slots(items: Array) -> void:
	for slot_index in range(SLOT_COUNT):
		var icon_rect := _slot_icons[slot_index]
		var count_label := _slot_counts[slot_index]
		var panel := _slot_panels[slot_index]
		if slot_index >= items.size():
			icon_rect.texture = null
			count_label.text = ""
			panel.tooltip_text = ""
			panel.modulate = Color(1.0, 1.0, 1.0, 0.6)
			continue
		var entry := items[slot_index] as Dictionary
		var item_name := String(entry.get("name", "Oddment"))
		var quantity := int(entry.get("quantity", 1))
		panel.modulate = Color.WHITE
		if ItemDefsService.has_icon(item_name):
			icon_rect.texture = ItemDefsService.icon_texture(item_name)
			count_label.text = "×%d" % quantity if quantity > 1 else ""
			count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		else:
			icon_rect.texture = null
			count_label.text = "%s\n%d" % [DwarfHoldChestService.item_abbreviation(item_name), quantity]
			count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.tooltip_text = ItemDefsService.slot_tooltip(item_name, quantity)

func _center_in_parent() -> void:
	var parent_control := get_parent() as Control
	var area := parent_control.size if parent_control != null else get_viewport_rect().size
	position = ((area - size) * 0.5).max(Vector2.ZERO)
