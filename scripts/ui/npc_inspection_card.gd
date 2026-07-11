class_name NpcInspectionCard
extends PanelContainer

## The right-click dossier: a citizen's name and trade over the slot
## grid of what they carry, plus their purse. One card serves the whole
## scene - inspecting another NPC repopulates it in place. Esc or a
## click outside the panel closes it. Built entirely in code so both
## the town and the hold can spawn one.
##
## Rulers get a second tab: the DYNASTY, a pixel-art family tree of the
## chronicle's succession line (violent successions in red, the dead
## desaturated) plus the sitting ruler's spouse and children. The tab
## only exists for NPC states flagged is_ruler with a lineage.

const SLOT_COUNT := 6
const SLOT_COLUMNS := 3
const SLOT_SIZE := Vector2(46, 46)

var _header_label: Label
var _coins_label: Label
var _slot_panels: Array[PanelContainer] = []
var _slot_icons: Array[TextureRect] = []
var _slot_counts: Array[Label] = []
var _tabs: TabContainer
var _dynasty_scroll: ScrollContainer
var _tree_view: FamilyTreeView

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
	_populate_dynasty(npc_state)
	visible = true
	reset_size()
	_center_in_parent()

func close() -> void:
	visible = false

## Whether the open card offers the Dynasty tab (rulers only).
func dynasty_tab_available() -> bool:
	return _tabs.tabs_visible

## Lineage + kin nodes the tree draws; 0 when the tab is hidden.
func dynasty_node_count() -> int:
	return _tree_view.node_count() if _tabs.tabs_visible else 0

func show_dynasty_tab() -> void:
	if _tabs.tabs_visible:
		_tabs.current_tab = 1

func _populate_dynasty(npc_state: Dictionary) -> void:
	var lineage := npc_state.get("ruler_lineage", []) as Array
	var is_ruler := bool(npc_state.get("is_ruler", false)) and not lineage.is_empty()
	_tabs.tabs_visible = is_ruler
	_tabs.set_tab_hidden(1, not is_ruler)
	_tabs.current_tab = 0
	if is_ruler:
		var identity := npc_state.get("identity", {}) as Dictionary
		_tree_view.set_dynasty(lineage, npc_state.get("ruler_kin", {}) as Dictionary, int(identity.get("age", 120)))
		_dynasty_scroll.custom_minimum_size = Vector2(420, 500)
	else:
		_tree_view.set_dynasty([], {}, 120)
		_dynasty_scroll.custom_minimum_size = Vector2.ZERO

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

	## Two pages under one header: the pockets, and (for rulers) the line.
	_tabs = TabContainer.new()
	_tabs.tabs_visible = false
	layout.add_child(_tabs)

	var belongings_box := VBoxContainer.new()
	belongings_box.name = "Belongings"
	belongings_box.add_theme_constant_override("separation", 8)
	_tabs.add_child(belongings_box)

	var grid := GridContainer.new()
	grid.columns = SLOT_COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	belongings_box.add_child(grid)
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
	belongings_box.add_child(_coins_label)

	_dynasty_scroll = ScrollContainer.new()
	_dynasty_scroll.name = "Dynasty"
	_tabs.add_child(_dynasty_scroll)
	_tree_view = FamilyTreeView.new()
	_tree_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dynasty_scroll.add_child(_tree_view)
	_tabs.set_tab_hidden(1, true)

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

## --- The dynasty tree ----------------------------------------------------
## The succession line as pixel art: one composed 32x32 dwarf bust per
## lineage member (deterministic from name+clan+age, the same seeding
## the walking sprites use) scaled 2x with nearest filtering, name +
## title + reign years beneath, chunky 2px connectors down the line —
## red with a dagger where a reign ended in blood — then the sitting
## ruler's consort beside them and their children branching below.
## Deceased members (every non-sitting predecessor) draw desaturated.
class FamilyTreeView:
	extends Control

	const PORTRAIT := 64
	const NODE_WIDTH := 150
	const NODE_HEIGHT := 112
	const LINK_HEIGHT := 26
	const SPOUSE_GAP := 158
	const CHILD_SPACING := 132
	const EDGE_PADDING := 16
	const LINE_THICKNESS := 2.0
	const LINE_COLOR := Color(0.62, 0.52, 0.36, 1.0)
	const VIOLENT_COLOR := Color(0.85, 0.24, 0.2, 1.0)
	const NAME_COLOR := Color(0.95, 0.88, 0.72, 1.0)
	const TITLE_COLOR := Color(0.78, 0.68, 0.5, 1.0)
	const REIGN_COLOR := Color(0.62, 0.57, 0.47, 1.0)
	const DEAD_TEXT := Color(0.55, 0.52, 0.46, 1.0)
	const HIGHLIGHT_COLOR := Color(0.93, 0.77, 0.26, 1.0)

	## The succession column, then the consort and the children row.
	var _line_nodes: Array[Dictionary] = []
	var _spouse_node: Dictionary = {}
	var _child_nodes: Array[Dictionary] = []

	func node_count() -> int:
		var total := _line_nodes.size() + _child_nodes.size()
		if not _spouse_node.is_empty():
			total += 1
		return total

	## sitting_age: the living ruler's actual identity age, so their tree
	## portrait is seeded exactly like their walking sprite.
	func set_dynasty(lineage: Array, kin: Dictionary, sitting_age: int) -> void:
		_line_nodes = []
		_spouse_node = {}
		_child_nodes = []
		for member_variant: Variant in lineage:
			if not (member_variant is Dictionary):
				continue
			var member := member_variant as Dictionary
			var member_name := String(member.get("name", ""))
			var start_year := int(member.get("start", 1))
			var end_year := int(member.get("end", 0))
			var sitting := bool(member.get("sitting", false)) or end_year <= 0
			var reign_label := (
				"Year %d – now" % start_year
				if sitting
				else "Year %d – %d" % [start_year, end_year]
			)
			## Predecessor ages are synthetic but deterministic, so the
			## same dynasty always shows the same faces.
			var portrait_age := 60 + maxi(0, end_year - start_year) if not sitting else sitting_age
			_line_nodes.append({
				"texture": _portrait_for(member_name, portrait_age, "Dwarf", not sitting, sitting),
				"name": member_name,
				"subtitle": String(member.get("title", "")),
				"reign": reign_label,
				"deceased": not sitting,
				"violent_link": bool(member.get("violent_end", false)),
				"highlight": sitting
			})
		var spouse_variant: Variant = kin.get("spouse", {})
		if spouse_variant is Dictionary and not (spouse_variant as Dictionary).is_empty():
			var spouse := spouse_variant as Dictionary
			_spouse_node = {
				"texture": _portrait_for(String(spouse.get("name", "")), int(spouse.get("age", 100)), String(spouse.get("race", "Dwarf")), false, false),
				"name": String(spouse.get("name", "")),
				"subtitle": "Consort",
				"reign": "",
				"deceased": false,
				"violent_link": false,
				"highlight": false
			}
		for child_variant: Variant in (kin.get("children", []) as Array):
			if not (child_variant is Dictionary):
				continue
			var child := child_variant as Dictionary
			_child_nodes.append({
				"texture": _portrait_for(String(child.get("name", "")), int(child.get("age", 30)), String(child.get("race", "Dwarf")), false, false),
				"name": String(child.get("name", "")),
				"subtitle": "Heir",
				"reign": "",
				"deceased": false,
				"violent_link": false,
				"highlight": false
			})
		custom_minimum_size = _content_size()
		queue_redraw()

	## The full composed dwarf, seeded exactly like the walking sprites so
	## the tree shows the very dwarf who walks the hold; the sitting ruler
	## wears their circlet, and the dead are drained toward stone-gray.
	static func _portrait_for(person_name: String, age: int, race: String, deceased: bool, crowned: bool) -> ImageTexture:
		var clan := person_name.get_slice(" ", 1) if person_name.contains(" ") else ""
		var identity := {"name": person_name, "clan": clan, "age": age, "race": race}
		var layers := NpcIdentityService.appearance_for_identity(identity, "dwarf")
		var texture := DwarfSpriteComposer.compose_crowned(layers) if crowned else DwarfSpriteComposer.compose(layers)
		if not deceased:
			return texture
		var image := texture.get_image()
		for pixel_y: int in range(image.get_height()):
			for pixel_x: int in range(image.get_width()):
				var pixel := image.get_pixel(pixel_x, pixel_y)
				if pixel.a <= 0.0:
					continue
				var gray := pixel.r * 0.3 + pixel.g * 0.59 + pixel.b * 0.11
				image.set_pixel(pixel_x, pixel_y, Color(gray, gray * 0.98, gray * 1.06, pixel.a))
		return ImageTexture.create_from_image(image)

	func _content_size() -> Vector2:
		if _line_nodes.is_empty():
			return Vector2.ZERO
		var content_width := float(NODE_WIDTH + 2 * EDGE_PADDING)
		if not _spouse_node.is_empty():
			content_width = maxf(content_width, float(NODE_WIDTH + SPOUSE_GAP + 2 * EDGE_PADDING))
		if not _child_nodes.is_empty():
			content_width = maxf(content_width, float(_child_nodes.size() * CHILD_SPACING + 2 * EDGE_PADDING))
		var content_height := float(_line_nodes.size() * NODE_HEIGHT + (_line_nodes.size() - 1) * LINK_HEIGHT + 2 * EDGE_PADDING)
		if not _child_nodes.is_empty():
			content_height += float(LINK_HEIGHT + NODE_HEIGHT)
		return Vector2(content_width, content_height)

	## Center x of the succession column inside the content area.
	func _column_center_x() -> float:
		var center := size.x * 0.5
		if not _spouse_node.is_empty():
			center -= float(SPOUSE_GAP) * 0.5
		return maxf(center, float(EDGE_PADDING + NODE_WIDTH / 2))

	func _draw() -> void:
		if _line_nodes.is_empty():
			return
		var column_x := _column_center_x()
		var cursor_y := float(EDGE_PADDING)
		var sitting_center := Vector2.ZERO
		for node_index: int in range(_line_nodes.size()):
			var node := _line_nodes[node_index]
			_draw_person(node, Vector2(column_x, cursor_y))
			if node_index == _line_nodes.size() - 1:
				sitting_center = Vector2(column_x, cursor_y + float(PORTRAIT) * 0.5)
			if node_index < _line_nodes.size() - 1:
				var link_top := cursor_y + float(NODE_HEIGHT)
				var violent := bool(node.get("violent_link", false))
				var link_color := VIOLENT_COLOR if violent else LINE_COLOR
				draw_rect(Rect2(column_x - LINE_THICKNESS * 0.5, link_top, LINE_THICKNESS, float(LINK_HEIGHT)), link_color)
				if violent:
					_draw_dagger(Vector2(column_x + 8.0, link_top + float(LINK_HEIGHT) * 0.5))
			cursor_y += float(NODE_HEIGHT + LINK_HEIGHT)
		var couple_anchor := sitting_center
		if not _spouse_node.is_empty():
			var spouse_x := column_x + float(SPOUSE_GAP)
			var spouse_top := sitting_center.y - float(PORTRAIT) * 0.5
			## The marriage bar between the two busts.
			draw_rect(Rect2(column_x + float(PORTRAIT) * 0.5, sitting_center.y - LINE_THICKNESS * 0.5, spouse_x - column_x - float(PORTRAIT), LINE_THICKNESS), LINE_COLOR)
			_draw_person(_spouse_node, Vector2(spouse_x, spouse_top))
			couple_anchor = Vector2((column_x + spouse_x) * 0.5, sitting_center.y)
		if not _child_nodes.is_empty():
			## cursor_y already sits one link below the last node's block.
			var row_top := cursor_y
			## Children hang from a T-rail under the couple: the drop falls
			## from the marriage bar (or from under the lone ruler's text).
			var rail_y := row_top - 10.0
			var drop_top := couple_anchor.y if not _spouse_node.is_empty() else row_top - float(LINK_HEIGHT)
			draw_rect(Rect2(couple_anchor.x - LINE_THICKNESS * 0.5, drop_top, LINE_THICKNESS, rail_y - drop_top), LINE_COLOR)
			var row_width := float(_child_nodes.size() * CHILD_SPACING)
			var row_left := couple_anchor.x - row_width * 0.5 + float(CHILD_SPACING) * 0.5
			var first_x := row_left
			var last_x := row_left + float((_child_nodes.size() - 1) * CHILD_SPACING)
			draw_rect(Rect2(minf(first_x, couple_anchor.x), rail_y, maxf(last_x, couple_anchor.x) - minf(first_x, couple_anchor.x) + LINE_THICKNESS, LINE_THICKNESS), LINE_COLOR)
			for child_index: int in range(_child_nodes.size()):
				var child_x := row_left + float(child_index * CHILD_SPACING)
				draw_rect(Rect2(child_x - LINE_THICKNESS * 0.5, rail_y, LINE_THICKNESS, 10.0), LINE_COLOR)
				_draw_person(_child_nodes[child_index], Vector2(child_x, row_top))

	## One person: 2x bust (nearest = crisp pixels), then the three text
	## rows. top_position.x is the node's CENTER x, .y the portrait top.
	func _draw_person(node: Dictionary, top_position: Vector2) -> void:
		var texture_variant: Variant = node.get("texture")
		var portrait_rect := Rect2(top_position.x - float(PORTRAIT) * 0.5, top_position.y, float(PORTRAIT), float(PORTRAIT))
		## A framed stone plaque behind every bust makes the pixels pop.
		draw_rect(portrait_rect.grow(4.0), Color(0.23, 0.18, 0.14, 1.0))
		var frame_color := HIGHLIGHT_COLOR if bool(node.get("highlight", false)) else Color(0.48, 0.39, 0.27, 1.0)
		draw_rect(portrait_rect.grow(4.0), frame_color, false, 2.0)
		if texture_variant is Texture2D:
			draw_texture_rect(texture_variant as Texture2D, portrait_rect, false)
		var deceased := bool(node.get("deceased", false))
		var font := ThemeDB.fallback_font
		var text_left := top_position.x - float(NODE_WIDTH) * 0.5
		var name_color := DEAD_TEXT if deceased else NAME_COLOR
		var subtitle_color := DEAD_TEXT if deceased else TITLE_COLOR
		draw_string(font, Vector2(text_left, top_position.y + float(PORTRAIT) + 14.0), String(node.get("name", "")), HORIZONTAL_ALIGNMENT_CENTER, float(NODE_WIDTH), 12, name_color)
		draw_string(font, Vector2(text_left, top_position.y + float(PORTRAIT) + 28.0), String(node.get("subtitle", "")), HORIZONTAL_ALIGNMENT_CENTER, float(NODE_WIDTH), 11, subtitle_color)
		var reign := String(node.get("reign", ""))
		if not reign.is_empty():
			draw_string(font, Vector2(text_left, top_position.y + float(PORTRAIT) + 41.0), reign, HORIZONTAL_ALIGNMENT_CENTER, float(NODE_WIDTH), 10, DEAD_TEXT if deceased else REIGN_COLOR)

	## A little pixel dagger beside a red connector: blade, guard, grip.
	func _draw_dagger(center: Vector2) -> void:
		var blade := Color(0.82, 0.84, 0.88, 1.0)
		var guard := Color(0.79, 0.62, 0.26, 1.0)
		var grip := Color(0.45, 0.3, 0.18, 1.0)
		draw_rect(Rect2(center.x - 1.0, center.y - 6.0, 2.0, 7.0), blade)
		draw_rect(Rect2(center.x - 3.0, center.y + 1.0, 6.0, 2.0), guard)
		draw_rect(Rect2(center.x - 1.0, center.y + 3.0, 2.0, 4.0), grip)
