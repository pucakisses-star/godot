class_name NpcInspectionCard
extends PanelContainer

## The right-click dossier: a citizen's profile — a composed portrait bust
## beside their name, trade, race, age and clan and a few lines of kin and
## temperament — over two tabs, their belongings and their family tree. One
## card serves the whole scene: inspecting another NPC repopulates it in
## place. Esc or a click outside the panel closes it. Built entirely in
## code so both the town and the hold can spawn one.
##
## EVERY NPC gets a family tab: a pixel-art family tree drawn from a
## "family graph" — generations in rows, couples under marriage bars,
## siblings, aunts, uncles and cousins fanning out under their own parents,
## relation labels relative to the inspected person. A sitting ruler shows
## their whole DYNASTY (the succession line, violent successions in red);
## everyone else shows their own FAMILY (parents, grandparents, siblings,
## aunts/uncles, cousins, spouse and children), built on demand and cached
## on the state. The dead are desaturated; married-in kin sit on muted
## plaques; the inspected person is highlighted and, for rulers, crowned.

const SLOT_COUNT := 6
const SLOT_COLUMNS := 3
const SLOT_SIZE := Vector2(46, 46)
const PORTRAIT_SIZE := 72.0

var _portrait_rect: TextureRect
var _name_label: Label
var _subtitle_label: Label
var _age_clan_label: Label
var _detail_rows: VBoxContainer
var _coins_label: Label
var _seed_value := 0
var _slot_panels: Array[PanelContainer] = []
var _slot_icons: Array[TextureRect] = []
var _slot_counts: Array[Label] = []
var _tabs: TabContainer
var _tree_view: FamilyTreeView

func _init() -> void:
	_build_ui()
	visible = false

## Rolls (once) and shows the NPC's profile and belongings. The roll is
## stored on the state so later trade systems mutate the same kit the card
## shows. present_year dates the family tree (birth/death years and the
## ages the busts are composed at); 0 falls back to the ruler graph's own
## year, then to 200.
func open(npc_state: Dictionary, role_title: String, seed_value: int, present_year: int = 0) -> void:
	_seed_value = seed_value
	var identity := npc_state.get("identity", {}) as Dictionary
	if not (npc_state.get("belongings") is Dictionary):
		npc_state["belongings"] = SettlementEconomyService.npc_belongings(
			identity, int(npc_state.get("role", 0)), seed_value)
	var belongings := npc_state["belongings"] as Dictionary
	var year := present_year
	if year <= 0:
		var ruler_family := npc_state.get("ruler_family", {}) as Dictionary
		year = int(ruler_family.get("year", 200)) if not ruler_family.is_empty() else 200
	_populate_profile(npc_state, identity, role_title)
	_populate_slots(belongings.get("items", []) as Array)
	_coins_label.text = "🪙 %d coins" % int(belongings.get("coins", 0))
	_populate_family(npc_state, identity, year)
	visible = true
	reset_size()
	_center_in_parent()

## The profile block: a composed bust beside name, race + trade, age +
## clan and the identity's kin/temperament detail lines.
func _populate_profile(npc_state: Dictionary, identity: Dictionary, role_title: String) -> void:
	var race := String(identity.get("race", "Dwarf"))
	var profession := String(identity.get("profession", role_title))
	var species := "human" if race == "Human" or race == "Gnome" else "dwarf"
	var layers := NpcIdentityService.appearance_for_identity(identity, species)
	var crowned := bool(npc_state.get("is_ruler", false))
	_portrait_rect.texture = DwarfSpriteComposer.compose_crowned(layers) if crowned else DwarfSpriteComposer.compose(layers)
	_name_label.text = String(identity.get("name", "A stranger"))
	_subtitle_label.text = ("%s %s" % [race, profession]).strip_edges() if not race.is_empty() else profession
	var age_clan := "Age %d" % int(identity.get("age", 0))
	var clan := String(identity.get("clan", ""))
	if not clan.is_empty():
		age_clan += " • Clan %s" % clan
	_age_clan_label.text = age_clan
	for child: Node in _detail_rows.get_children():
		# Free NOW, not end-of-frame: open() measures with reset_size()
		# this same frame, and queued-free rows still count toward the
		# minimum size — inflating every card after the first with a band
		# of dead space.
		_detail_rows.remove_child(child)
		child.free()
	for line: String in NpcIdentityService.detail_lines(identity):
		var row := Label.new()
		row.text = line
		row.add_theme_font_size_override("font_size", 11)
		row.add_theme_color_override("font_color", Color(0.72, 0.66, 0.54, 1.0))
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(220.0, 0.0)
		_detail_rows.add_child(row)

func close() -> void:
	visible = false

## Whether the open card's family tab has anything to draw.
func dynasty_tab_available() -> bool:
	return _tree_view.node_count() > 0

## People the family tree draws.
func dynasty_node_count() -> int:
	return _tree_view.node_count()

func show_dynasty_tab() -> void:
	_tabs.current_tab = 1
	call_deferred("_apply_dynasty_focus")

## Scrolls the (now laid-out) family tab onto the inspected person; runs
## deferred whenever the tab becomes the active page.
func _apply_dynasty_focus() -> void:
	if _tabs.current_tab != 1:
		return
	_tree_view.focus_on_sitting()

func _on_tab_changed(tab_index: int) -> void:
	if tab_index == 1:
		call_deferred("_apply_dynasty_focus")

## Loads the family tab. A sitting ruler shows their prebuilt dynasty
## graph ("Dynasty"); everyone else gets an individual family graph, built
## once from their identity and cached on the state, shown as "Family".
func _populate_family(npc_state: Dictionary, identity: Dictionary, present_year: int) -> void:
	var age := int(identity.get("age", 120))
	_tabs.current_tab = 0
	var ruler_family := npc_state.get("ruler_family", {}) as Dictionary
	var ruler_people := ruler_family.get("people", {}) as Dictionary
	if bool(npc_state.get("is_ruler", false)) and not ruler_people.is_empty():
		_tabs.set_tab_title(1, "Dynasty")
		_tree_view.set_dynasty(
			npc_state.get("ruler_lineage", []) as Array,
			npc_state.get("ruler_kin", {}) as Dictionary,
			age,
			ruler_family
		)
	else:
		_tabs.set_tab_title(1, "Family")
		_tree_view.set_dynasty([], {}, age, _individual_family(npc_state, identity, present_year))
	_tree_view.custom_minimum_size = Vector2(420, 500)

## The inspected NPC's own family graph, built on first inspection from
## their identity (name/clan/gender/age/race and any roster kin) and cached
## on the state so reopening the card reuses the exact same tree.
func _individual_family(npc_state: Dictionary, identity: Dictionary, present_year: int) -> Dictionary:
	var cached_variant: Variant = npc_state.get("family_graph")
	if cached_variant is Dictionary and not (cached_variant as Dictionary).is_empty():
		return cached_variant as Dictionary
	var npc_name := String(identity.get("name", "A stranger"))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|npcfamily|%s" % [_seed_value, npc_name])
	var focus := {
		"name": npc_name,
		"clan": String(identity.get("clan", "")),
		"gender": String(identity.get("gender", "")),
		"age": int(identity.get("age", 100)),
		"race": String(identity.get("race", "Dwarf")),
		"current_year": present_year,
		"spouse": String(identity.get("spouse", "")),
		"parents": identity.get("parents", []),
		"children": identity.get("children", [])
	}
	var graph := WorldChronicleService.build_family_for_individual(focus, rng)
	npc_state["family_graph"] = graph
	return graph

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

	## The profile: a composed bust on a stone plaque beside the name,
	## race + trade, age + clan and the kin/temperament detail rows, with
	## the close button pinned to the top-right corner.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	layout.add_child(header)

	var portrait_frame := PanelContainer.new()
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = Color(0.23, 0.18, 0.14, 1.0)
	portrait_style.border_color = Color(0.48, 0.39, 0.27, 1.0)
	portrait_style.set_border_width_all(2)
	portrait_style.set_corner_radius_all(4)
	portrait_style.set_content_margin_all(4)
	portrait_frame.add_theme_stylebox_override("panel", portrait_style)
	header.add_child(portrait_frame)
	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_frame.add_child(_portrait_rect)

	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 2)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(details)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 17)
	_name_label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.74, 1.0))
	details.add_child(_name_label)
	_subtitle_label = Label.new()
	_subtitle_label.add_theme_font_size_override("font_size", 13)
	_subtitle_label.add_theme_color_override("font_color", Color(0.82, 0.72, 0.52, 1.0))
	details.add_child(_subtitle_label)
	_age_clan_label = Label.new()
	_age_clan_label.add_theme_font_size_override("font_size", 12)
	_age_clan_label.add_theme_color_override("font_color", Color(0.78, 0.7, 0.56, 1.0))
	details.add_child(_age_clan_label)
	_detail_rows = VBoxContainer.new()
	_detail_rows.add_theme_constant_override("separation", 1)
	details.add_child(_detail_rows)

	var close_button := Button.new()
	close_button.text = "✕"
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.pressed.connect(close)
	header.add_child(close_button)

	## Two pages under one profile: the pockets, and the family tree.
	_tabs = TabContainer.new()
	_tabs.tab_changed.connect(_on_tab_changed)
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

	# The tree is its own pan/zoom viewport (drag to move, wheel to zoom) — no
	# ScrollContainer, so it clips to the tab and the whole genealogy is
	# reachable by dragging out to distant kin and zooming to fit.
	_tree_view = FamilyTreeView.new()
	_tree_view.name = "Dynasty"
	_tree_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(_tree_view)

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
## The chronicle's dynasty graph as a proper genealogy: generations as
## horizontal rows (oldest at the top), couples side by side under a
## marriage bar, children fanning out beneath their parents on clean
## orthogonal connectors, cousins under their own parents. Every person
## is a composed pixel bust (64px for rulers, 48px for kin) over a stone
## plaque with name, relation to the sitting ruler (Grandmother, Uncle,
## Cousin...) and years. Succession stubs draw red with a dagger when
## the seat was taken in blood; the dead are drained toward stone-gray;
## married-in spouses sit on muted plaques; the sitting ruler is crowned
## and gold-framed. Layout is the classic recursive subtree-width walk:
## a couple's x is the center of its children's span, a row's y its
## generation. Portraits are composed lazily on first draw and cached.
class FamilyTreeView:
	extends Control

	const RULER_PORTRAIT := 64
	const MINOR_PORTRAIT := 48
	const PORTRAIT_BOX := 64.0
	const NODE_WIDTH := 132.0
	const NODE_HEIGHT := 118.0
	const ROW_GAP := 40.0
	const COUPLE_GAP := 14.0
	const SUBTREE_GAP := 26.0
	const EDGE_PADDING := 18.0
	const RAIL_GAP := 18.0
	const LINE_THICKNESS := 2.0
	const LINE_COLOR := Color(0.62, 0.52, 0.36, 1.0)
	const VIOLENT_COLOR := Color(0.85, 0.24, 0.2, 1.0)
	const NAME_COLOR := Color(0.95, 0.88, 0.72, 1.0)
	const TITLE_COLOR := Color(0.78, 0.68, 0.5, 1.0)
	const REIGN_COLOR := Color(0.62, 0.57, 0.47, 1.0)
	const DEAD_TEXT := Color(0.55, 0.52, 0.46, 1.0)
	const HIGHLIGHT_COLOR := Color(0.93, 0.77, 0.26, 1.0)
	const FRAME_COLOR := Color(0.48, 0.39, 0.27, 1.0)
	const MUTED_FRAME_COLOR := Color(0.36, 0.31, 0.24, 1.0)
	const PLAQUE_COLOR := Color(0.23, 0.18, 0.14, 1.0)
	const MUTED_PLAQUE_COLOR := Color(0.19, 0.16, 0.13, 1.0)

	## Pan/zoom of the view: content is drawn through a single transform, so
	## the player can drag the genealogy around and wheel-zoom to fit a wide
	## family into the tab or lean in on one branch.
	const MIN_ZOOM := 0.35
	const MAX_ZOOM := 2.5
	const ZOOM_STEP := 1.12

	## The dynasty graph (person id -> person dictionary) and its layout.
	var _people: Dictionary = {}
	var _order: Array[String] = []
	var _sitting_id := ""
	var _present_year := 0
	var _sitting_age := 120
	var _nodes: Array[Dictionary] = []
	var _segments: Array[Dictionary] = []
	var _daggers: Array[Vector2] = []
	var _sitting_center := Vector2.ZERO
	var _content_size := Vector2.ZERO
	var _portrait_cache: Dictionary = {}
	var _view_offset := Vector2.ZERO
	var _zoom := 1.0
	var _dragging := false

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP

	## Drag with the left/middle button to pan, mouse wheel to zoom toward the
	## cursor. Bounded so the tree can never be flung off to an empty void.
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var button := event as InputEventMouseButton
			if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
				_zoom_to(_zoom * ZOOM_STEP, button.position)
				accept_event()
			elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
				_zoom_to(_zoom / ZOOM_STEP, button.position)
				accept_event()
			elif button.button_index == MOUSE_BUTTON_LEFT or button.button_index == MOUSE_BUTTON_MIDDLE:
				_dragging = button.pressed
				accept_event()
		elif event is InputEventMouseMotion and _dragging:
			_view_offset += (event as InputEventMouseMotion).relative
			_clamp_view_offset()
			queue_redraw()
			accept_event()

	func _zoom_to(target_zoom: float, pivot: Vector2) -> void:
		var new_zoom := clampf(target_zoom, MIN_ZOOM, MAX_ZOOM)
		if is_equal_approx(new_zoom, _zoom):
			return
		# Keep the content point under the cursor pinned as the scale changes.
		var world := (pivot - _view_offset) / _zoom
		_zoom = new_zoom
		_view_offset = pivot - world * _zoom
		_clamp_view_offset()
		queue_redraw()

	## Enforces the "never flung off to an empty void" promise: at least
	## a margin of the tree stays inside the viewport after pan or zoom.
	func _clamp_view_offset() -> void:
		var view := size
		if view.x <= 0.0 or view.y <= 0.0:
			return
		var margin := 60.0
		var content := _content_size * _zoom
		_view_offset.x = clampf(_view_offset.x, margin - content.x, view.x - margin)
		_view_offset.y = clampf(_view_offset.y, margin - content.y, view.y - margin)

	## Frames the sitting/focus person in the middle of the view at 1:1, the
	## natural starting pose whenever the tab opens.
	func focus_on_sitting() -> void:
		_zoom = 1.0
		var view := size
		if view == Vector2.ZERO:
			view = _content_size
		_view_offset = view * 0.5 - _sitting_center * _zoom
		queue_redraw()

	## People the tree draws; 0 when no dynasty is loaded.
	func node_count() -> int:
		return _nodes.size()

	## Where the sitting ruler sits in content coordinates, so the card
	## can scroll the view onto them when the tab opens.
	func sitting_scroll_center() -> Vector2:
		return _sitting_center

	## sitting_age: the living ruler's identity age, so their tree bust is
	## seeded exactly like their walking sprite. family: the chronicle's
	## dynasty graph; when absent the flat lineage + roster kin fall back
	## to a single-parent chain so old saves still draw.
	func set_dynasty(lineage: Array, kin: Dictionary, sitting_age: int, family: Dictionary = {}) -> void:
		_sitting_age = sitting_age
		var people_variant: Variant = family.get("people", {})
		if people_variant is Dictionary and not (people_variant as Dictionary).is_empty():
			_people = (people_variant as Dictionary).duplicate(true)
			_sitting_id = String(family.get("sitting", ""))
			_present_year = int(family.get("year", 0))
			_order = []
			for id_variant: Variant in (family.get("order", []) as Array):
				var person_id := String(id_variant)
				if _people.has(person_id):
					_order.append(person_id)
			if _order.is_empty():
				for key_variant: Variant in _people.keys():
					_order.append(String(key_variant))
				_order.sort()
		else:
			_build_fallback_family(lineage, kin)
		_layout()
		queue_redraw()

	## Chronicles without a dynasty graph still draw: the succession line
	## becomes a single-parent chain and the roster kin hang beneath the
	## sitting ruler, matching what the old column view showed.
	func _build_fallback_family(lineage: Array, kin: Dictionary) -> void:
		_people = {}
		_order = []
		_sitting_id = ""
		_present_year = 0
		var previous_id := ""
		var previous_violent := false
		for member_index: int in range(lineage.size()):
			if not (lineage[member_index] is Dictionary):
				continue
			var member := lineage[member_index] as Dictionary
			var person_id := "l%d" % member_index
			var member_name := String(member.get("name", ""))
			var end_year := int(member.get("end", 0))
			var sitting := bool(member.get("sitting", false)) or end_year <= 0
			var parents: Array = []
			if not previous_id.is_empty():
				parents.append(previous_id)
				(( _people[previous_id] as Dictionary)["children"] as Array).append(person_id)
			_people[person_id] = {
				"id": person_id,
				"name": member_name,
				"gender": String(member.get("gender", "")),
				"clan": member_name.get_slice(" ", 1) if member_name.contains(" ") else "",
				"race": "Dwarf",
				"birth": 0,
				"death": 0 if sitting else maxi(end_year, 1),
				"age": _sitting_age if sitting else 60 + maxi(0, end_year - int(member.get("start", 0))),
				"title": String(member.get("title", "")),
				"reign_start": int(member.get("start", 0)),
				"reign_end": end_year,
				"sitting": sitting,
				"violent_end": bool(member.get("violent_end", false)),
				"violent_takeover": previous_violent,
				"married_in": false,
				"ruler_index": member_index,
				"parents": parents,
				"spouse": "",
				"children": [],
				"generation": member_index
			}
			_order.append(person_id)
			previous_violent = bool(member.get("violent_end", false))
			previous_id = person_id
			if sitting:
				_sitting_id = person_id
		if _sitting_id.is_empty():
			return
		var sitting_person := _people[_sitting_id] as Dictionary
		var spouse_variant: Variant = kin.get("spouse", {})
		if spouse_variant is Dictionary and not (spouse_variant as Dictionary).is_empty():
			var stub := spouse_variant as Dictionary
			var stub_name := String(stub.get("name", ""))
			_people["k_spouse"] = _fallback_kin_person("k_spouse", stub, int(sitting_person.get("generation", 0)))
			(_people["k_spouse"] as Dictionary)["spouse"] = _sitting_id
			(_people["k_spouse"] as Dictionary)["married_in"] = true
			sitting_person["spouse"] = "k_spouse"
			_order.append("k_spouse")
			if stub_name.is_empty():
				pass
		for child_index: int in range((kin.get("children", []) as Array).size()):
			var child_variant: Variant = (kin.get("children", []) as Array)[child_index]
			if not (child_variant is Dictionary):
				continue
			var child_id := "k_child%d" % child_index
			_people[child_id] = _fallback_kin_person(child_id, child_variant as Dictionary, int(sitting_person.get("generation", 0)) + 1)
			var child_parents := (_people[child_id] as Dictionary)["parents"] as Array
			child_parents.append(_sitting_id)
			(sitting_person["children"] as Array).append(child_id)
			var spouse_id := String(sitting_person.get("spouse", ""))
			if not spouse_id.is_empty():
				child_parents.append(spouse_id)
				((_people[spouse_id] as Dictionary)["children"] as Array).append(child_id)
			_order.append(child_id)

	## A roster kin stub (name/clan/age/race) as a graph person.
	func _fallback_kin_person(person_id: String, stub: Dictionary, generation: int) -> Dictionary:
		var stub_name := String(stub.get("name", ""))
		return {
			"id": person_id,
			"name": stub_name,
			"gender": NpcIdentityService.dwarf_name_gender(stub_name.get_slice(" ", 0)),
			"clan": String(stub.get("clan", "")),
			"race": String(stub.get("race", "Dwarf")),
			"birth": 0,
			"death": 0,
			"age": int(stub.get("age", 100)),
			"title": "",
			"reign_start": 0,
			"reign_end": 0,
			"sitting": false,
			"violent_end": false,
			"violent_takeover": false,
			"married_in": false,
			"ruler_index": -1,
			"parents": [],
			"spouse": "",
			"children": [],
			"generation": generation
		}

	func _person(person_id: String) -> Dictionary:
		var person_variant: Variant = _people.get(person_id, {})
		return person_variant as Dictionary if person_variant is Dictionary else {}

	## --- Layout ------------------------------------------------------------

	func _layout() -> void:
		_nodes = []
		_segments = []
		_daggers = []
		_sitting_center = Vector2.ZERO
		if _people.is_empty():
			custom_minimum_size = Vector2.ZERO
			return
		## Couple units: a person and their spouse share one slot, blood
		## member first so the subtree hangs under the dynasty line.
		var unit_by_person: Dictionary = {}
		var units: Array[Dictionary] = []
		for person_id: String in _order:
			if unit_by_person.has(person_id):
				continue
			var person := _person(person_id)
			var members: Array = [person_id]
			var spouse_id := String(person.get("spouse", ""))
			if not spouse_id.is_empty() and _people.has(spouse_id) and not unit_by_person.has(spouse_id):
				if bool(person.get("married_in", false)) and not bool(_person(spouse_id).get("married_in", false)):
					members = [spouse_id, person_id]
				else:
					members.append(spouse_id)
			for member_variant: Variant in members:
				unit_by_person[String(member_variant)] = units.size()
			units.append({
				"members": members,
				"children": [],
				"parent": -1,
				"width": 0.0,
				"center": 0.0,
				"generation": int(_person(String(members[0])).get("generation", 0))
			})
		## Children attach beneath their parents' unit, one parent only.
		for unit_index: int in range(units.size()):
			var unit := units[unit_index]
			for member_variant: Variant in (unit["members"] as Array):
				var member := _person(String(member_variant))
				for child_variant: Variant in (member.get("children", []) as Array):
					var child_id := String(child_variant)
					var child_unit := int(unit_by_person.get(child_id, -1))
					if child_unit < 0 or child_unit == unit_index:
						continue
					var child_entry := units[child_unit]
					if int(child_entry["parent"]) >= 0 or int(child_entry["generation"]) <= int(unit["generation"]):
						continue
					child_entry["parent"] = unit_index
					(unit["children"] as Array).append(child_unit)
			(unit["children"] as Array).sort_custom(func(left_variant: Variant, right_variant: Variant) -> bool:
				var left_person := _person(String((units[int(left_variant)]["members"] as Array)[0]))
				var right_person := _person(String((units[int(right_variant)]["members"] as Array)[0]))
				if int(left_person.get("birth", 0)) != int(right_person.get("birth", 0)):
					return int(left_person.get("birth", 0)) < int(right_person.get("birth", 0))
				return String(left_person.get("id", "")) < String(right_person.get("id", ""))
			)
		## Recursive subtree-width layout from each root.
		var root_cursor := EDGE_PADDING
		for unit_index: int in range(units.size()):
			if int(units[unit_index]["parent"]) >= 0:
				continue
			_measure_unit(units, unit_index)
			_place_unit(units, unit_index, root_cursor)
			root_cursor += float(units[unit_index]["width"]) + SUBTREE_GAP * 2.0
		## Rows, plaques and connectors.
		var max_generation := 0
		var content_right := 0.0
		for unit: Dictionary in units:
			max_generation = maxi(max_generation, int(unit["generation"]))
		for unit: Dictionary in units:
			var members := unit["members"] as Array
			var row_top := EDGE_PADDING + float(int(unit["generation"])) * (NODE_HEIGHT + ROW_GAP)
			var own_width := float(members.size()) * NODE_WIDTH + float(members.size() - 1) * COUPLE_GAP
			var unit_left := float(unit["center"]) - own_width * 0.5
			var member_centers: Array[float] = []
			for member_index: int in range(members.size()):
				var member_center := unit_left + NODE_WIDTH * 0.5 + float(member_index) * (NODE_WIDTH + COUPLE_GAP)
				member_centers.append(member_center)
				_append_person_node(String(members[member_index]), Vector2(member_center, row_top))
				content_right = maxf(content_right, member_center + NODE_WIDTH * 0.5)
			var bar_y := row_top + PORTRAIT_BOX * 0.5
			if members.size() == 2:
				var left_half := float(_portrait_size(String(members[0]))) * 0.5 + 5.0
				var right_half := float(_portrait_size(String(members[1]))) * 0.5 + 5.0
				_add_hline(member_centers[0] + left_half, member_centers[1] - right_half, bar_y, LINE_COLOR)
			var children := unit["children"] as Array
			if children.is_empty():
				continue
			var anchor_x := (member_centers[0] + member_centers[member_centers.size() - 1]) * 0.5
			## Couples drop from the marriage bar; a lone parent drops from
			## below their plaque text so no line strikes the labels.
			var drop_top := bar_y if members.size() == 2 else row_top + NODE_HEIGHT - 2.0
			var child_row_top := EDGE_PADDING + float(int(unit["generation"]) + 1) * (NODE_HEIGHT + ROW_GAP)
			var rail_y := child_row_top - RAIL_GAP
			_add_vline(anchor_x, drop_top, rail_y, LINE_COLOR)
			var rail_min := anchor_x
			var rail_max := anchor_x
			for child_variant: Variant in children:
				var child_unit := units[int(child_variant)] as Dictionary
				var child_members := child_unit["members"] as Array
				var child_own := float(child_members.size()) * NODE_WIDTH + float(child_members.size() - 1) * COUPLE_GAP
				var blood_center := float(child_unit["center"]) - child_own * 0.5 + NODE_WIDTH * 0.5
				rail_min = minf(rail_min, blood_center)
				rail_max = maxf(rail_max, blood_center)
				var blood_person := _person(String(child_members[0]))
				var violent := bool(blood_person.get("violent_takeover", false))
				_add_vline(blood_center, rail_y, child_row_top, VIOLENT_COLOR if violent else LINE_COLOR)
				if violent:
					_daggers.append(Vector2(blood_center + 9.0, (rail_y + child_row_top) * 0.5))
			_add_hline(rail_min, rail_max, rail_y, LINE_COLOR)
		# Content bounds drive pan/zoom framing, not the tab size — the view is
		# a fixed viewport the player drags within, so this must NOT become the
		# control's minimum (that would blow the card up to the tree's width).
		_content_size = Vector2(
			content_right + EDGE_PADDING,
			EDGE_PADDING * 2.0 + float(max_generation + 1) * NODE_HEIGHT + float(max_generation) * ROW_GAP
		)

	## A unit's width: its couple, or its children's span, whichever is
	## wider. Stored on the unit and returned for the parent's sum.
	func _measure_unit(units: Array[Dictionary], unit_index: int) -> float:
		var unit := units[unit_index]
		var member_count := (unit["members"] as Array).size()
		var own_width := float(member_count) * NODE_WIDTH + float(member_count - 1) * COUPLE_GAP
		var children := unit["children"] as Array
		var kids_width := 0.0
		for child_variant: Variant in children:
			kids_width += _measure_unit(units, int(child_variant))
		if children.size() > 1:
			kids_width += SUBTREE_GAP * float(children.size() - 1)
		var width := maxf(own_width, kids_width)
		unit["width"] = width
		return width

	## Places a unit's subtree into [left, left + width]: children first,
	## then the couple centered over its children's couple centers.
	func _place_unit(units: Array[Dictionary], unit_index: int, left: float) -> void:
		var unit := units[unit_index]
		var width := float(unit["width"])
		var children := unit["children"] as Array
		var member_count := (unit["members"] as Array).size()
		var own_width := float(member_count) * NODE_WIDTH + float(member_count - 1) * COUPLE_GAP
		var center := left + width * 0.5
		if not children.is_empty():
			var kids_width := 0.0
			for child_variant: Variant in children:
				kids_width += float((units[int(child_variant)] as Dictionary)["width"])
			kids_width += SUBTREE_GAP * float(children.size() - 1)
			var cursor := left + (width - kids_width) * 0.5
			for child_variant: Variant in children:
				var child_index := int(child_variant)
				_place_unit(units, child_index, cursor)
				cursor += float((units[child_index] as Dictionary)["width"]) + SUBTREE_GAP
			var first_center := float((units[int(children[0])] as Dictionary)["center"])
			var last_center := float((units[int(children[children.size() - 1])] as Dictionary)["center"])
			center = clampf((first_center + last_center) * 0.5, left + own_width * 0.5, left + width - own_width * 0.5)
		unit["center"] = center

	## One person's display node: plaque texts, flags and position.
	func _append_person_node(person_id: String, top_center: Vector2) -> void:
		var person := _person(person_id)
		var is_ruler := int(person.get("ruler_index", -1)) >= 0
		var sitting := bool(person.get("sitting", false))
		var death := int(person.get("death", 0))
		var deceased := death > 0
		var relation := relation_label(_people, _sitting_id, person_id)
		var line_b := String(person.get("title", "")) if sitting or relation.is_empty() else relation
		var line_c := ""
		if is_ruler:
			var reign_end := int(person.get("reign_end", 0))
			line_c = (
				"r. %d – now" % int(person.get("reign_start", 0))
				if sitting or reign_end <= 0
				else "r. %d – %d" % [int(person.get("reign_start", 0)), reign_end]
			)
		else:
			## Births before year 1 predate the chronicle — leave them out.
			var birth := int(person.get("birth", 0))
			if deceased:
				line_c = "%d – %d" % [birth, death] if birth >= 1 else "d. %d" % death
			elif birth >= 1:
				line_c = "b. %d" % birth
		_nodes.append({
			"id": person_id,
			"top": top_center,
			"portrait": RULER_PORTRAIT if is_ruler else MINOR_PORTRAIT,
			"name": String(person.get("name", "")),
			"line_b": line_b,
			"line_c": line_c,
			"deceased": deceased,
			"sitting": sitting,
			"married_in": bool(person.get("married_in", false))
		})
		if sitting:
			_sitting_center = top_center + Vector2(0.0, PORTRAIT_BOX * 0.5)

	func _portrait_size(person_id: String) -> int:
		return RULER_PORTRAIT if int(_person(person_id).get("ruler_index", -1)) >= 0 else MINOR_PORTRAIT

	func _add_vline(x: float, y0: float, y1: float, color: Color) -> void:
		_segments.append({
			"rect": Rect2(x - LINE_THICKNESS * 0.5, minf(y0, y1), LINE_THICKNESS, absf(y1 - y0)),
			"color": color
		})

	func _add_hline(x0: float, x1: float, y: float, color: Color) -> void:
		_segments.append({
			"rect": Rect2(minf(x0, x1), y - LINE_THICKNESS * 0.5, absf(x1 - x0) + LINE_THICKNESS, LINE_THICKNESS),
			"color": color
		})

	## --- Relations to the sitting ruler -------------------------------------
	## Static so headless tests can label any graph member directly.

	## "Grandmother", "Uncle", "Cousin", "Consort"... relative to the
	## sitting ruler; blood first, then colloquial by-marriage labels;
	## ancestors beyond great-grandparents read "Forebear".
	static func relation_label(people: Dictionary, sitting_id: String, person_id: String) -> String:
		if person_id == sitting_id or sitting_id.is_empty() or not people.has(person_id):
			return ""
		var blood := _blood_relation_label(people, sitting_id, person_id)
		if not blood.is_empty():
			return blood
		var person := people[person_id] as Dictionary
		var gender := String(person.get("gender", ""))
		var spouse_id := String(person.get("spouse", ""))
		if spouse_id == sitting_id:
			return "Consort"
		if spouse_id.is_empty() or not people.has(spouse_id):
			return "Kin"
		match _blood_relation_label(people, sitting_id, spouse_id):
			"Brother", "Sister", "Sibling":
				return _gendered(gender, "Brother-in-law", "Sister-in-law", "Kin by marriage")
			"Uncle", "Aunt", "Parent's sibling":
				return _gendered(gender, "Uncle", "Aunt", "Kin by marriage")
			"Great-Uncle", "Great-Aunt", "Elder kin":
				return _gendered(gender, "Great-Uncle", "Great-Aunt", "Kin by marriage")
			"Son", "Daughter", "Child":
				return _gendered(gender, "Son-in-law", "Daughter-in-law", "Kin by marriage")
			_:
				return "Kin by marriage"

	## Blood relation only ("" when none): ancestor/descendant depth
	## first, then the nearest common ancestor decides sibling, uncle,
	## nephew or cousin.
	static func _blood_relation_label(people: Dictionary, sitting_id: String, person_id: String) -> String:
		var person := people[person_id] as Dictionary
		var gender := String(person.get("gender", ""))
		var sitting_ancestors := _ancestor_depths(people, sitting_id)
		var person_ancestors := _ancestor_depths(people, person_id)
		if sitting_ancestors.has(person_id):
			match int(sitting_ancestors[person_id]):
				1:
					return _gendered(gender, "Father", "Mother", "Parent")
				2:
					return _gendered(gender, "Grandfather", "Grandmother", "Grandparent")
				3:
					return _gendered(gender, "Great-Grandfather", "Great-Grandmother", "Great-Grandparent")
				_:
					return "Forebear"
		if person_ancestors.has(sitting_id):
			match int(person_ancestors[sitting_id]):
				1:
					return _gendered(gender, "Son", "Daughter", "Child")
				2:
					return _gendered(gender, "Grandson", "Granddaughter", "Grandchild")
				_:
					return "Descendant"
		var best_sitting := -1
		var best_person := -1
		for ancestor_variant: Variant in sitting_ancestors.keys():
			if not person_ancestors.has(ancestor_variant):
				continue
			var depth_sitting := int(sitting_ancestors[ancestor_variant])
			var depth_person := int(person_ancestors[ancestor_variant])
			if best_sitting < 0 or depth_sitting + depth_person < best_sitting + best_person \
					or (depth_sitting + depth_person == best_sitting + best_person and depth_sitting < best_sitting):
				best_sitting = depth_sitting
				best_person = depth_person
		if best_sitting < 0:
			return ""
		if best_sitting == 1 and best_person == 1:
			return _gendered(gender, "Brother", "Sister", "Sibling")
		if best_sitting == 2 and best_person == 1:
			return _gendered(gender, "Uncle", "Aunt", "Parent's sibling")
		if best_sitting >= 3 and best_person == 1:
			return _gendered(gender, "Great-Uncle", "Great-Aunt", "Elder kin")
		if best_sitting == 1 and best_person >= 2:
			return _gendered(gender, "Nephew", "Niece", "Sibling's child")
		if best_sitting >= 2 and best_person >= 2:
			return "Cousin"
		return "Kin"

	## Minimum parent-link distance from start_id to each of its
	## ancestors (start_id itself at depth 0).
	static func _ancestor_depths(people: Dictionary, start_id: String) -> Dictionary:
		var depths: Dictionary = {start_id: 0}
		var frontier: Array[String] = [start_id]
		while not frontier.is_empty():
			var next_frontier: Array[String] = []
			for frontier_id: String in frontier:
				var person_variant: Variant = people.get(frontier_id, {})
				if not (person_variant is Dictionary):
					continue
				var person := person_variant as Dictionary
				var next_depth := int(depths[frontier_id]) + 1
				for parent_variant: Variant in (person.get("parents", []) as Array):
					var parent_id := String(parent_variant)
					if not people.has(parent_id):
						continue
					if depths.has(parent_id) and int(depths[parent_id]) <= next_depth:
						continue
					depths[parent_id] = next_depth
					next_frontier.append(parent_id)
			frontier = next_frontier
		return depths

	static func _gendered(gender: String, male_label: String, female_label: String, neutral_label: String) -> String:
		if gender == "male":
			return male_label
		if gender == "female":
			return female_label
		return neutral_label

	## --- Drawing -------------------------------------------------------------

	func _draw() -> void:
		# Everything below is authored in content coordinates; this single
		# transform applies the current pan and zoom to the whole tree at once.
		draw_set_transform(_view_offset, 0.0, Vector2(_zoom, _zoom))
		for segment: Dictionary in _segments:
			draw_rect(segment["rect"] as Rect2, segment["color"] as Color)
		for dagger: Vector2 in _daggers:
			_draw_dagger(dagger)
		for node: Dictionary in _nodes:
			_draw_person_node(node)

	## One person: framed plaque, lazily composed bust (crowned when
	## sitting, desaturated when dead), then name / relation / years.
	func _draw_person_node(node: Dictionary) -> void:
		var top := node["top"] as Vector2
		var portrait_size := float(int(node["portrait"]))
		var portrait_rect := Rect2(
			top.x - portrait_size * 0.5,
			top.y + (PORTRAIT_BOX - portrait_size) * 0.5,
			portrait_size, portrait_size
		)
		var sitting := bool(node.get("sitting", false))
		var married_in := bool(node.get("married_in", false))
		var deceased := bool(node.get("deceased", false))
		draw_rect(portrait_rect.grow(4.0), MUTED_PLAQUE_COLOR if married_in else PLAQUE_COLOR)
		var frame_color := HIGHLIGHT_COLOR if sitting else (MUTED_FRAME_COLOR if married_in else FRAME_COLOR)
		draw_rect(portrait_rect.grow(4.0), frame_color, false, 2.0)
		var texture := _portrait_texture(node)
		if texture != null:
			draw_texture_rect(texture, portrait_rect, false)
		var font := ThemeDB.fallback_font
		var text_left := top.x - NODE_WIDTH * 0.5
		var text_top := top.y + PORTRAIT_BOX
		var name_color := DEAD_TEXT if deceased else (TITLE_COLOR if married_in else NAME_COLOR)
		var subtitle_color := DEAD_TEXT if deceased else TITLE_COLOR
		draw_string(font, Vector2(text_left, text_top + 14.0), String(node.get("name", "")), HORIZONTAL_ALIGNMENT_CENTER, NODE_WIDTH, 12, name_color)
		draw_string(font, Vector2(text_left, text_top + 28.0), String(node.get("line_b", "")), HORIZONTAL_ALIGNMENT_CENTER, NODE_WIDTH, 11, subtitle_color)
		var line_c := String(node.get("line_c", ""))
		if not line_c.is_empty():
			draw_string(font, Vector2(text_left, text_top + 41.0), line_c, HORIZONTAL_ALIGNMENT_CENTER, NODE_WIDTH, 10, DEAD_TEXT if deceased else REIGN_COLOR)

	## Composed on first draw, cached by name/age/flags — a full tree
	## holds ~40 busts and reopening a card reuses every one of them.
	func _portrait_texture(node: Dictionary) -> Texture2D:
		var person := _person(String(node.get("id", "")))
		var deceased := bool(node.get("deceased", false))
		# "sitting" only means "the person this tree centers on" — every
		# inspected citizen carries it. Only actual rulers wear the crown,
		# but the focus person's bust always uses their real age (a child's
		# portrait must not fall through to the adult-floored estimate).
		var sitting := bool(node.get("sitting", false))
		var crowned := sitting and int(person.get("ruler_index", -1)) >= 0
		var age := int(person.get("age", 0))
		if sitting:
			age = _sitting_age
		elif age <= 0:
			var birth := int(person.get("birth", 0))
			var death := int(person.get("death", 0))
			var last_year := death if death > 0 else _present_year
			age = clampi(last_year - birth, 20, 320) if last_year > birth else 100
		var person_name := String(person.get("name", ""))
		var race := String(person.get("race", "Dwarf"))
		var cache_key := "%s|%s|%d|%s|%d|%d" % [
			person_name, String(person.get("clan", "")), age, race,
			1 if deceased else 0, 1 if crowned else 0
		]
		var cached_variant: Variant = _portrait_cache.get(cache_key)
		if cached_variant is Texture2D:
			return cached_variant as Texture2D
		if _portrait_cache.size() > 160:
			_portrait_cache.clear()
		var identity := {
			"name": person_name,
			"clan": String(person.get("clan", "")),
			"age": age,
			"race": race
		}
		var layers := NpcIdentityService.appearance_for_identity(identity, "dwarf")
		var texture := DwarfSpriteComposer.compose_crowned(layers) if crowned else DwarfSpriteComposer.compose(layers)
		if deceased:
			texture = _desaturated(texture)
		_portrait_cache[cache_key] = texture
		return texture

	## The dead are drained toward stone-gray, faintly cold.
	static func _desaturated(texture: ImageTexture) -> ImageTexture:
		var image := texture.get_image()
		for pixel_y: int in range(image.get_height()):
			for pixel_x: int in range(image.get_width()):
				var pixel := image.get_pixel(pixel_x, pixel_y)
				if pixel.a <= 0.0:
					continue
				var gray := pixel.r * 0.3 + pixel.g * 0.59 + pixel.b * 0.11
				image.set_pixel(pixel_x, pixel_y, Color(gray, gray * 0.98, gray * 1.06, pixel.a))
		return ImageTexture.create_from_image(image)

	## A little pixel dagger beside a red connector: blade, guard, grip.
	func _draw_dagger(center: Vector2) -> void:
		var blade := Color(0.82, 0.84, 0.88, 1.0)
		var guard := Color(0.79, 0.62, 0.26, 1.0)
		var grip := Color(0.45, 0.3, 0.18, 1.0)
		draw_rect(Rect2(center.x - 1.0, center.y - 6.0, 2.0, 7.0), blade)
		draw_rect(Rect2(center.x - 3.0, center.y + 1.0, 6.0, 2.0), guard)
		draw_rect(Rect2(center.x - 1.0, center.y + 3.0, 2.0, 4.0), grip)
