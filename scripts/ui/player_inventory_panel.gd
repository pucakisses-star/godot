class_name PlayerInventoryPanel
extends PanelContainer

## The character sheet: identity and vitals on the left, the paper doll
## of twelve equipment slots (combat, armor, attire columns) beside the
## full backpack grid in the center, standing and news on the right.
## Click a packed piece of gear to wear it; click a worn piece to take
## it off. Built entirely in code so both the town and the hold can
## spawn one.

const SLOT_SIZE := Vector2(46, 46)
const BACKPACK_COLUMNS := 8
const BACKPACK_SLOTS := 40
const DEFAULT_HINT := "Click gear to wear it · click other items to bind them to the hotbar · I closes"
## Side columns must fit two of themselves plus the ~620px center in a
## 1152px viewport, separators and margins included.
const INFO_COLUMN_WIDTH := 210.0
const SHEET_REFRESH_SECONDS := 0.5
const KEY_COLOR := Color(0.64, 0.56, 0.44, 1.0)
const VALUE_COLOR := Color(0.95, 0.9, 0.76, 1.0)
const SECTION_COLOR := Color(0.85, 0.78, 0.62, 1.0)

var _get_settings: Callable
var _store_settings: Callable
var _get_inventory: Callable
var _on_changed: Callable
var _get_context: Callable = Callable()

var _equipment_buttons: Dictionary = {}
var _backpack_buttons: Array[Button] = []
var _backpack_counts: Array[Label] = []
var _backpack_items: Array[String] = []
var _stats_label: Label
var _hint_label: Label
var _pack_grid: GridContainer
var _portrait_rect: TextureRect
var _sheet_values: Dictionary = {}
var _equipment_label: Label
var _effects_label: Label
var _standing_label: Label
var _news_label: Label
var _sheet_timer: Timer

func setup(get_settings: Callable, store_settings: Callable, get_inventory: Callable, on_changed: Callable, get_context: Callable = Callable()) -> void:
	_get_settings = get_settings
	_store_settings = store_settings
	_get_inventory = get_inventory
	_on_changed = on_changed
	_get_context = get_context
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
	# Wide enough for the two info columns, tall enough that the vitals
	# list needs no scrolling; still inside a 1152x648 viewport.
	custom_minimum_size = Vector2(1096.0, 484.0)
	set_anchors_preset(Control.PRESET_CENTER)
	var style := StyleBoxFlat.new()
	# Opaque: the sheet now spans the scene sidebars, and translucency
	# lets their text ghost through.
	style.bg_color = Color(0.16, 0.12, 0.09, 1.0)
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

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)

	body.add_child(_build_identity_column())
	body.add_child(VSeparator.new())

	var center := VBoxContainer.new()
	center.add_theme_constant_override("separation", 8)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(center)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	center.add_child(columns)

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
	center.add_child(_stats_label)
	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.modulate = Color(0.75, 0.72, 0.65, 1.0)
	_hint_label.text = DEFAULT_HINT
	center.add_child(_hint_label)

	body.add_child(VSeparator.new())
	body.add_child(_build_standing_column())

	# Sidebar values track the world clock and coin purse, so they tick
	# over while the sheet stays open - but only while it is visible.
	_sheet_timer = Timer.new()
	_sheet_timer.wait_time = SHEET_REFRESH_SECONDS
	_sheet_timer.timeout.connect(_refresh_character_sheet)
	add_child(_sheet_timer)
	visibility_changed.connect(_on_visibility_changed)

## --- the character-sheet side columns ------------------------------------

func _make_side_column(column_out: Array[VBoxContainer]) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(INFO_COLUMN_WIDTH, 0.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	column_out.append(column)
	return scroll

func _add_section_header(parent: VBoxContainer, header_text: String) -> void:
	var header_label := Label.new()
	header_label.text = header_text
	header_label.add_theme_font_size_override("font_size", 13)
	header_label.add_theme_color_override("font_color", SECTION_COLOR)
	parent.add_child(header_label)
	parent.add_child(HSeparator.new())

## One SS13-style record row: a dim key against a bright value.
func _add_info_row(parent: VBoxContainer, key_text: String, value_key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var key_label := Label.new()
	key_label.text = key_text
	key_label.add_theme_font_size_override("font_size", 11)
	key_label.add_theme_color_override("font_color", KEY_COLOR)
	key_label.custom_minimum_size = Vector2(72.0, 0.0)
	key_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(key_label)
	var value_label := Label.new()
	value_label.add_theme_font_size_override("font_size", 11)
	value_label.add_theme_color_override("font_color", VALUE_COLOR)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(value_label)
	_sheet_values[value_key] = value_label

func _add_info_block(parent: VBoxContainer, block_font_size: int, block_color: Color) -> Label:
	var block := Label.new()
	block.add_theme_font_size_override("font_size", block_font_size)
	block.add_theme_color_override("font_color", block_color)
	block.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(block)
	return block

## LEFT: who you are - portrait, identity records, vitals.
func _build_identity_column() -> ScrollContainer:
	var column_out: Array[VBoxContainer] = []
	var scroll := _make_side_column(column_out)
	var column := column_out[0]
	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(112.0, 112.0)
	_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_portrait_rect)
	_add_section_header(column, "Identity")
	_add_info_row(column, "Name", "name")
	_add_info_row(column, "Trade", "profession")
	_add_info_row(column, "World", "world")
	_add_info_row(column, "Place", "place")
	_add_info_row(column, "Date", "date")
	_add_info_row(column, "Time", "time")
	_add_section_header(column, "Vitals")
	_add_info_row(column, "Health", "hp")
	_add_info_row(column, "Attack", "attack")
	_add_info_row(column, "Satiety", "satiety")
	_add_info_row(column, "Coins", "coins")
	return scroll

## RIGHT: what you carry and know - gear, buffs, standing, news.
func _build_standing_column() -> ScrollContainer:
	var column_out: Array[VBoxContainer] = []
	var scroll := _make_side_column(column_out)
	var column := column_out[0]
	_add_section_header(column, "Equipped")
	_equipment_label = _add_info_block(column, 11, VALUE_COLOR)
	_add_section_header(column, "Effects")
	_effects_label = _add_info_block(column, 11, VALUE_COLOR)
	_add_section_header(column, "Standing")
	_standing_label = _add_info_block(column, 11, VALUE_COLOR)
	_add_section_header(column, "Latest News")
	_news_label = _add_info_block(column, 10, Color(0.8, 0.75, 0.64, 1.0))
	return scroll

func _on_visibility_changed() -> void:
	if _sheet_timer == null:
		return
	if visible and is_inside_tree():
		_sheet_timer.start()
	else:
		_sheet_timer.stop()

func _add_backpack_slot() -> void:
	var pack_button := _make_slot_button()
	pack_button.pressed.connect(_on_backpack_slot_pressed.bind(_backpack_buttons.size()))
	# A packed slot is a drag source: dragging it onto the open world drops
	# the item at the player's feet. The scene's catcher does the mutation.
	pack_button.set_drag_forwarding(
		Callable(self, "_backpack_drag_data").bind(_backpack_buttons.size()),
		Callable(),
		Callable()
	)
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

## Drag payload for backpack slot `index`: only a slot holding a real item
## can be dragged, and the drag carries that item's icon as its preview.
func _backpack_drag_data(_at_position: Vector2, index: int) -> Variant:
	if index < 0 or index >= _backpack_buttons.size():
		return null
	var item_name := String(_backpack_buttons[index].get_meta("item_name", ""))
	if item_name.is_empty():
		return null
	set_drag_preview(_make_drag_preview(item_name))
	return {"kind": "item_drop", "item": item_name}

func _make_drag_preview(item_name: String) -> Control:
	var preview := TextureRect.new()
	preview.texture = ItemDefsService.icon_texture(item_name)
	preview.custom_minimum_size = SLOT_SIZE
	preview.size = SLOT_SIZE
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.modulate = Color(1.0, 1.0, 1.0, 0.85)
	return preview

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
	_refresh_character_sheet()

## Repaints the side columns from the live scene context (clock, purse,
## factions...) plus the session stores the panel already reads.
func _refresh_character_sheet() -> void:
	if _portrait_rect == null or not is_inside_tree():
		return
	var settings: Dictionary = _get_settings.call()
	var context: Dictionary = {}
	if _get_context.is_valid():
		context = _get_context.call()
	var character: Dictionary = {}
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("get_player_character"):
		character = session.call("get_player_character")
	if _portrait_rect.texture == null:
		_portrait_rect.texture = _resolve_portrait()
	var display_name := String(character.get("name", "")).strip_edges()
	_set_sheet_value("name", display_name if not display_name.is_empty() else "Nameless Dwarf")
	var profession := String(character.get("profession", "")).strip_edges()
	_set_sheet_value("profession", profession.capitalize() if not profession.is_empty() else "Wanderer")
	var world_name := String(settings.get("world_name", "")).strip_edges()
	_set_sheet_value("world", world_name if not world_name.is_empty() else "Unnamed World")
	_set_sheet_value("place", String(context.get("place_name", "—")))
	var game_day := int(context.get("game_day", 0))
	if game_day > 0:
		# Scenes render dates off day-1: day 1 on the clock is calendar
		# index 0.
		_set_sheet_value("date", GameCalendar.date_text(game_day - 1, int(context.get("calendar_start_year", 250))))
		var game_hour := float(context.get("game_hour", 0.0))
		_set_sheet_value("time", "%02d:%02d" % [int(game_hour), int((game_hour - floorf(game_hour)) * 60.0)])
	else:
		_set_sheet_value("date", "—")
		_set_sheet_value("time", "—")
	var stats: Dictionary = PlayerStatsService.for_session(self)
	var hp_max := float(context.get("max_hp", float(stats.get("max_hp", PlayerStatsService.BASE_MAX_HP))))
	var hp_now := float(context.get("hp", hp_max))
	_set_sheet_value("hp", "%d / %d" % [int(ceilf(hp_now)), int(hp_max)])
	_set_sheet_value("attack", str(int(stats.get("attack", PlayerStatsService.BASE_ATTACK))))
	var satiety := float(context.get("satiety", -1.0))
	_set_sheet_value("satiety", ("%d / %d" % [int(satiety), int(PlayerStatsService.SATIETY_MAX)]) if satiety >= 0.0 else "—")
	_set_sheet_value("coins", str(int(context.get("coins", 0))))
	_equipment_label.text = _equipment_lines(settings)
	_effects_label.text = _effect_lines(settings, context)
	_standing_label.text = _standing_lines(context)
	_news_label.text = _news_lines(settings)

func _set_sheet_value(value_key: String, value_text: String) -> void:
	var value_label := _sheet_values.get(value_key) as Label
	if value_label != null and value_label.text != value_text:
		value_label.text = value_text

## The face on the sheet: the composed creator dwarf, else the walking
## frame of the sheet-slot character, else the profession's hero idle.
func _resolve_portrait() -> Texture2D:
	var composed: Texture2D = DwarfHoldActorVisuals.resolve_player_dwarf_texture(self)
	if composed != null:
		return composed
	var slot := DwarfHoldActorVisuals.resolve_player_character_slot(self)
	if slot >= 0:
		var sheet: Texture2D = DwarfHoldActorVisuals.DWARF_CHARACTERS_TEXTURE
		var frame_width := int(sheet.get_width() / 12.0)
		var frame_height := int(sheet.get_height() / 8.0)
		if frame_width >= 8 and frame_height >= 8:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			@warning_ignore("integer_division")
			atlas.region = Rect2(
				((slot % 4) * 3 + 1) * frame_width,
				(slot / 4) * 4 * frame_height,
				frame_width,
				frame_height
			)
			return atlas
	var hero: Texture2D = DwarfHoldActorVisuals.resolve_hero_texture(self)
	if hero != null:
		var hero_atlas := AtlasTexture.new()
		hero_atlas.atlas = hero
		hero_atlas.region = Rect2(Vector2.ZERO, DwarfHoldActorVisuals.HERO_FRAME_SIZE)
		return hero_atlas
	return null

func _equipment_lines(settings: Dictionary) -> String:
	var worn: Dictionary = GearService.equipment(settings)
	var lines: PackedStringArray = []
	for row_variant: Variant in GearService.EQUIP_SLOT_GRID:
		for slot_variant: Variant in (row_variant as Array):
			var slot := String(slot_variant)
			var item_name := String(worn.get(slot, ""))
			if not item_name.is_empty():
				lines.append("%s %s" % [String(GearService.EQUIP_SLOT_LABELS.get(slot, "")), item_name])
	var enchants: Dictionary = GearService.stored_enchants(settings)
	for target_variant: Variant in enchants.keys():
		var enchant := enchants[target_variant] as Dictionary
		if not enchant.is_empty():
			lines.append("✨ %s (%s enchant)" % [String(enchant.get("name", "")), String(target_variant)])
	if lines.is_empty():
		return "Nothing equipped"
	return "\n".join(lines)

func _effect_lines(settings: Dictionary, context: Dictionary) -> String:
	# The scene clock is fresher than the hourly settings stamp.
	var now_hours := GearService.total_game_hours(settings)
	if context.has("game_day"):
		now_hours = float(maxi(1, int(context.get("game_day", 1)))) * 24.0 + float(context.get("game_hour", 0.0))
	var lines: PackedStringArray = []
	for buff: Dictionary in GearService.active_buffs(settings, now_hours):
		var hours_left := maxf(float(buff.get("until", 0.0)) - now_hours, 0.0)
		lines.append("%s — %dh %02dm left" % [String(buff.get("buff", "")), int(hours_left), int(fmod(hours_left, 1.0) * 60.0)])
	if lines.is_empty():
		return "No draughts at work"
	return "\n".join(lines)

func _standing_lines(context: Dictionary) -> String:
	var lines: PackedStringArray = []
	var companion_attack := int(context.get("companion_attack", 0))
	if companion_attack > 0:
		lines.append("🐾 Sporeling companion (⚔ %d)" % companion_attack)
	var factions: Array = context.get("factions", []) if context.get("factions") is Array else []
	var secret_count := 0
	for faction_variant: Variant in factions:
		if not (faction_variant is Dictionary):
			continue
		var faction := faction_variant as Dictionary
		if bool(faction.get("secret", false)):
			secret_count += 1
			continue
		lines.append("%s — %d sworn" % [String(faction.get("name", "")), (faction.get("members", []) as Array).size()])
	if secret_count > 0:
		lines.append("...and whispers of something that meets after dark.")
	var discoveries := int(context.get("discoveries", -1))
	if discoveries >= 0:
		lines.append("🗺 %d places discovered" % discoveries)
	if lines.is_empty():
		return "No ties yet"
	return "\n".join(lines)

func _news_lines(settings: Dictionary) -> String:
	var events: Array[Dictionary] = WorldEventsService.recent_events(settings, 3)
	if events.is_empty():
		return "No word from the wider world."
	var lines: PackedStringArray = []
	# Freshest word first.
	for event_index: int in range(events.size() - 1, -1, -1):
		var event := events[event_index]
		lines.append("Day %d — %s" % [int(event.get("day", 0)), String(event.get("text", ""))])
	return "\n".join(lines)
