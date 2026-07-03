extends RefCounted
class_name OverworldLabelsService

## Builds and rescales the settlement name labels shown on the overworld
## map. Extracted from overworld_map.gd. The map script gathers the
## settlement entries (it owns the tile data); this service handles label
## layout, creation, and zoom behaviour.

## entries: [{"center": Vector2, "name": String, "font_size": int,
##            "priority": int, "population": int}], pre-sorted or not.
## config: {"tile_size": int, "primary_color": Color, "secondary_color":
##          Color, "outline_color": Color, "outline_size": float}
static func rebuild(labels_overlay: Node2D, entries: Array[Dictionary], config: Dictionary) -> void:
	if labels_overlay == null:
		return
	for child in labels_overlay.get_children():
		child.queue_free()

	var grouped_settlements := {
		"major": Node2D.new(),
		"minor": Node2D.new()
	}
	for group_name_variant: Variant in grouped_settlements.keys():
		var group_name := String(group_name_variant)
		var group := grouped_settlements[group_name] as Node2D
		group.name = "%sLabels" % group_name.capitalize()
		labels_overlay.add_child(group)

	var sorted_entries := entries.duplicate()
	sorted_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_priority := int(a.get("priority", 0))
		var b_priority := int(b.get("priority", 0))
		if a_priority == b_priority:
			return int(a.get("population", 0)) > int(b.get("population", 0))
		return a_priority > b_priority
	)

	var tile_size := int(config.get("tile_size", 32))
	var primary_color: Color = config.get("primary_color", Color.WHITE)
	var secondary_color: Color = config.get("secondary_color", Color.WHITE)
	var outline_color: Color = config.get("outline_color", Color.BLACK)
	var outline_size := float(config.get("outline_size", 1.0))

	var occupied_rects: Array[Rect2] = []
	for entry: Dictionary in sorted_entries:
		var font_size := int(entry.get("font_size", 12))
		var text := String(entry.get("name", ""))
		var center: Vector2 = entry.get("center", Vector2.ZERO)
		var estimated_width := maxf(22.0, text.length() * float(font_size) * 0.52)
		var estimated_height := float(font_size) * 1.2
		var candidate_rect := Rect2(
			center + Vector2(-estimated_width * 0.5, -float(tile_size) * 0.72 - estimated_height),
			Vector2(estimated_width, estimated_height)
		)
		if _rect_overlaps_any(candidate_rect, occupied_rects):
			continue
		occupied_rects.append(candidate_rect)

		var label := Label.new()
		label.text = text
		label.position = candidate_rect.position
		label.size = candidate_rect.size
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.clip_text = true
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", primary_color if int(entry.get("priority", 0)) >= 2 else secondary_color)
		label.add_theme_color_override("font_outline_color", outline_color)
		label.add_theme_constant_override("outline_size", int(round(outline_size)))
		label.set_meta("base_font_size", font_size)
		label.set_meta("anchor_center", center)

		var group_key := "major" if int(entry.get("priority", 0)) >= 2 else "minor"
		var target_group := grouped_settlements[group_key] as Node2D
		target_group.add_child(label)

## config: {"tile_size": int, "rescale_on_zoom": bool, "auto_visibility":
##          bool, "min_screen_size": float, "max_screen_size": float}
static func update_zoom_behavior(labels_overlay: Node2D, zoom_factor: float, config: Dictionary) -> void:
	if labels_overlay == null:
		return
	var safe_zoom := maxf(zoom_factor, 0.001)
	var tile_size := int(config.get("tile_size", 32))
	var rescale_on_zoom := bool(config.get("rescale_on_zoom", true))
	var auto_visibility := bool(config.get("auto_visibility", true))
	var min_screen_size := float(config.get("min_screen_size", 7.0))
	var max_screen_size := float(config.get("max_screen_size", 50.0))
	for group in labels_overlay.get_children():
		for child in group.get_children():
			var label := child as Label
			if label == null:
				continue
			var base_font_size := float(label.get_meta("base_font_size", 12.0))
			var scaled_font_size := base_font_size
			if rescale_on_zoom:
				scaled_font_size = maxf(8.0, (base_font_size + (base_font_size * safe_zoom)) * 0.5)
			label.add_theme_font_size_override("font_size", int(round(scaled_font_size)))

			# Re-derive the label rect from the scaled font so the text is
			# never clipped by a stale, smaller rect after zooming in.
			var anchor := label.get_meta("anchor_center", Vector2.ZERO) as Vector2
			var scaled_width := maxf(22.0, label.text.length() * scaled_font_size * 0.52)
			var scaled_height := scaled_font_size * 1.2
			label.position = anchor + Vector2(-scaled_width * 0.5, -float(tile_size) * 0.72 - scaled_height)
			label.size = Vector2(scaled_width, scaled_height)

			if auto_visibility:
				var screen_size := scaled_font_size / safe_zoom
				label.visible = screen_size >= min_screen_size and screen_size <= max_screen_size
			else:
				label.visible = true

static func font_size_for_settlement(settlement_type: String) -> int:
	match settlement_type:
		"great_dwarfhold", "dark_dwarfhold", "abandoned_dwarfhold", "dwarfhold":
			return 15
		"city", "wood_elf_grove", "lizardmen_city":
			return 13
		"town", "wizard_tower":
			return 12
		_:
			return 11

static func priority_for_settlement(settlement_type: String) -> int:
	match settlement_type:
		"great_dwarfhold", "dark_dwarfhold", "abandoned_dwarfhold", "dwarfhold":
			return 3
		"city", "wood_elf_grove", "lizardmen_city":
			return 2
		"town", "wizard_tower":
			return 2
		_:
			return 1

static func _rect_overlaps_any(candidate: Rect2, rects: Array[Rect2]) -> bool:
	for rect in rects:
		if candidate.intersects(rect):
			return true
	return false
