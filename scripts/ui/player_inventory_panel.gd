class_name PlayerInventoryPanel
extends PanelContainer

## The inventory screen: a paper doll of twelve equipment slots (combat,
## armor, attire columns) beside the full backpack grid. Click a packed
## piece of gear to wear it; click a worn piece to take it off. Built
## entirely in code so both the town and the hold can spawn one.

const SLOT_SIZE := Vector2(46, 46)
const BACKPACK_COLUMNS := 8
const BACKPACK_SLOTS := 40
const DEFAULT_HINT := "Click gear to wear it · click other items to bind them to the hotbar · I closes"

var _get_settings: Callable
var _store_settings: Callable
var _get_inventory: Callable
var _on_changed: Callable

var _equipment_buttons: Dictionary = {}
var _backpack_buttons: Array[Button] = []
var _backpack_counts: Array[Label] = []
var _backpack_items: Array[String] = []
var _stats_label: Label
var _hint_label: Label
var _pack_grid: GridContainer

func setup(get_settings: Callable, store_settings: Callable, get_inventory: Callable, on_changed: Callable) -> void:
	_get_settings = get_settings
	_store_settings = store_settings
	_get_inventory = get_inventory
	_on_changed = on_changed
	_build_ui()
	visible = false

func toggle() -> void:
	visible = not visible
	if visible:
		_hint_label.text = DEFAULT_HINT
		refresh()
		reset_size()
		var parent_control := get_parent() as Control
		var area := parent_control.size if parent_control != null else get_viewport_rect().size
		position = ((area - size) * 0.5).max(Vector2.ZERO)

func _build_ui() -> void:
	custom_minimum_size = Vector2(720.0, 430.0)
	set_anchors_preset(Control.PRESET_CENTER)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.12, 0.09, 0.97)
	style.border_color = Color(0.72, 0.58, 0.38, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = "Pack & Panoply"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.pressed.connect(func() -> void: visible = false)
	header.add_child(close_button)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	layout.add_child(columns)

	# The paper doll: three columns of four slots.
	var doll_box := VBoxContainer.new()
	columns.add_child(doll_box)
	var doll_title := Label.new()
	doll_title.text = "Worn"
	doll_title.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62, 1.0))
	doll_box.add_child(doll_title)
	var doll_grid := GridContainer.new()
	doll_grid.columns = 3
	doll_grid.add_theme_constant_override("h_separation", 6)
	doll_grid.add_theme_constant_override("v_separation", 6)
	doll_box.add_child(doll_grid)
	for row_variant: Variant in GearService.EQUIP_SLOT_GRID:
		for slot_variant: Variant in (row_variant as Array):
			var slot := String(slot_variant)
			var slot_button := _make_slot_button()
			slot_button.pressed.connect(_on_equipment_slot_pressed.bind(slot))
			doll_grid.add_child(slot_button)
			_equipment_buttons[slot] = slot_button

	var separator := VSeparator.new()
	columns.add_child(separator)

	# The backpack grid.
	var pack_box := VBoxContainer.new()
	pack_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(pack_box)
	var pack_title := Label.new()
	pack_title.text = "Backpack"
	pack_title.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62, 1.0))
	pack_box.add_child(pack_title)
	# The grid scrolls: a pack can hold more distinct items than one
	# screenful of slots, and every one of them must stay reachable.
	var pack_scroll := ScrollContainer.new()
	pack_scroll.custom_minimum_size = Vector2(
		BACKPACK_COLUMNS * (SLOT_SIZE.x + 6.0) + 14.0,
		(BACKPACK_SLOTS / BACKPACK_COLUMNS) * (SLOT_SIZE.y + 6.0)
	)
	pack_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pack_box.add_child(pack_scroll)
	_pack_grid = GridContainer.new()
	_pack_grid.columns = BACKPACK_COLUMNS
	_pack_grid.add_theme_constant_override("h_separation", 6)
	_pack_grid.add_theme_constant_override("v_separation", 6)
	pack_scroll.add_child(_pack_grid)
	for index in BACKPACK_SLOTS:
		_add_backpack_slot()

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 13)
	_stats_label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.7, 1.0))
	layout.add_child(_stats_label)
	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.modulate = Color(0.75, 0.72, 0.65, 1.0)
	_hint_label.text = DEFAULT_HINT
	layout.add_child(_hint_label)

func _add_backpack_slot() -> void:
	var pack_button := _make_slot_button()
	pack_button.pressed.connect(_on_backpack_slot_pressed.bind(_backpack_buttons.size()))
	_pack_grid.add_child(pack_button)
	_backpack_buttons.append(pack_button)
	var count := Label.new()
	count.add_theme_font_size_override("font_size", 11)
	count.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8, 1.0))
	count.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06, 1.0))
	count.add_theme_constant_override("outline_size", 3)
	count.position = Vector2(SLOT_SIZE.x - 22.0, SLOT_SIZE.y - 18.0)
	pack_button.add_child(count)
	_backpack_counts.append(count)

func _make_slot_button() -> Button:
	var slot_button := Button.new()
	slot_button.custom_minimum_size = SLOT_SIZE
	slot_button.expand_icon = true
	slot_button.add_theme_font_size_override("font_size", 20)
	var slot_style := StyleBoxFlat.new()
	slot_style.bg_color = Color(0.24, 0.18, 0.13, 1.0)
	slot_style.border_color = Color(0.5, 0.4, 0.28, 1.0)
	slot_style.set_border_width_all(2)
	slot_style.set_corner_radius_all(5)
	slot_button.add_theme_stylebox_override("normal", slot_style)
	var hover_style := slot_style.duplicate() as StyleBoxFlat
	hover_style.border_color = Color(0.85, 0.72, 0.45, 1.0)
	slot_button.add_theme_stylebox_override("hover", hover_style)
	slot_button.add_theme_stylebox_override("pressed", hover_style)
	return slot_button

## --- interaction --------------------------------------------------------

func _on_equipment_slot_pressed(slot: String) -> void:
	var settings: Dictionary = _get_settings.call()
	var inventory: Dictionary = _get_inventory.call()
	var freed: String = GearService.unequip(settings, inventory, slot)
	if freed.is_empty():
		return
	_store_settings.call(settings)
	refresh()
	if _on_changed.is_valid():
		_on_changed.call()

func _on_backpack_slot_pressed(index: int) -> void:
	if index >= _backpack_buttons.size():
		return
	# The name stamped at render time, not a positional lookup - the
	# sorted list can shift under an open panel (e.g. drinking the last
	# potion of a type from the hotbar).
	var item_name := String(_backpack_buttons[index].get_meta("item_name", ""))
	if item_name.is_empty():
		return
	if GearService.equip_slot_for(item_name).is_empty():
		# Not wearable: clicking binds it to (or frees it from) the hotbar.
		var bind_settings: Dictionary = _get_settings.call()
		var bound := GearService.hotbar_index_of(bind_settings, item_name)
		if bound >= 0:
			GearService.set_hotbar_binding(bind_settings, bound, "")
			_hint_label.text = "%s unbound from key %d." % [item_name, (bound + 1) % 10]
		else:
			bound = GearService.bind_hotbar_first_free(bind_settings, item_name)
			if bound < 0:
				_hint_label.text = "The hotbar is full — unbind something first."
				return
			_hint_label.text = "%s bound to key %d." % [item_name, (bound + 1) % 10]
		_store_settings.call(bind_settings)
		refresh()
		if _on_changed.is_valid():
			_on_changed.call()
		return
	var settings: Dictionary = _get_settings.call()
	var inventory: Dictionary = _get_inventory.call()
	GearService.equip(settings, inventory, item_name)
	_store_settings.call(settings)
	refresh()
	if _on_changed.is_valid():
		_on_changed.call()

## --- rendering ----------------------------------------------------------

func refresh() -> void:
	if _equipment_buttons.is_empty():
		return
	var settings: Dictionary = _get_settings.call()
	var inventory: Dictionary = _get_inventory.call()
	var worn: Dictionary = GearService.equipment(settings)
	for slot_variant: Variant in _equipment_buttons.keys():
		var slot := String(slot_variant)
		var slot_button := _equipment_buttons[slot] as Button
		var item_name := String(worn.get(slot, ""))
		if item_name.is_empty():
			slot_button.icon = null
			slot_button.text = String(GearService.EQUIP_SLOT_LABELS.get(slot, "?"))
			slot_button.modulate = Color(1.0, 1.0, 1.0, 0.45)
			slot_button.tooltip_text = "Empty %s slot" % slot
		else:
			slot_button.text = ""
			slot_button.icon = ItemDefsService.icon_texture(item_name)
			slot_button.modulate = Color.WHITE
			slot_button.tooltip_text = GearService.gear_tooltip(item_name)
			if slot_button.icon == null:
				slot_button.text = item_name.left(2)
	_backpack_items.clear()
	var item_names := inventory.keys()
	item_names.sort()
	# Grow the grid when the pack outnumbers the slots (it scrolls).
	while _backpack_buttons.size() < item_names.size():
		_add_backpack_slot()
	for index in _backpack_buttons.size():
		var pack_button := _backpack_buttons[index]
		var count_label := _backpack_counts[index]
		if index < item_names.size():
			var item_name := String(item_names[index])
			_backpack_items.append(item_name)
			pack_button.set_meta("item_name", item_name)
			pack_button.icon = ItemDefsService.icon_texture(item_name)
			pack_button.text = "" if pack_button.icon != null else item_name.left(2)
			pack_button.modulate = Color.WHITE
			var quantity := int(inventory.get(item_name, 0))
			count_label.text = "×%d" % quantity if quantity > 1 else ""
			var tooltip := GearService.gear_tooltip(item_name)
			if tooltip.is_empty():
				tooltip = ItemDefsService.slot_tooltip(item_name, quantity)
			elif quantity > 1:
				tooltip += "\n×%d carried" % quantity
			var flavor := ItemDefsService.flavor_text(item_name)
			if not flavor.is_empty() and not tooltip.contains(flavor):
				tooltip += "\n" + flavor
			var bound_key := GearService.hotbar_index_of(settings, item_name)
			if bound_key >= 0:
				tooltip += "\nHotbar key %d" % [(bound_key + 1) % 10]
			pack_button.tooltip_text = tooltip
		else:
			pack_button.set_meta("item_name", "")
			pack_button.icon = null
			pack_button.text = ""
			pack_button.tooltip_text = ""
			pack_button.modulate = Color(1.0, 1.0, 1.0, 0.6)
			count_label.text = ""
	var stats: Dictionary = PlayerStatsService.for_session(self)
	var loadout := stats.get("loadout", {}) as Dictionary
	var stats_text := "⚔ %d   ❤ %d   👟 %d%%" % [
		int(stats.get("attack", 2)),
		int(float(stats.get("max_hp", 20.0))),
		int(float(stats.get("speed_mult", 1.0)) * 100.0)
	]
	if int(loadout.get("armor_set_tier", 0)) > 0:
		stats_text += "   — full armor set (tier %d)!" % int(loadout.get("armor_set_tier", 0))
	elif int(loadout.get("set_tier", 0)) > 0:
		stats_text += "   — matched set (tier %d)" % int(loadout.get("set_tier", 0))
	_stats_label.text = stats_text
