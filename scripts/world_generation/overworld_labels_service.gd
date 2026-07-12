extends RefCounted
class_name OverworldLabelsService

## Builds and rescales the location name labels shown on the overworld
## map. Extracted from overworld_map.gd. The map script gathers the
## settlement and structure entries (it owns the tile data); this service
## handles category/importance resolution, label layout, creation, and
## zoom behaviour.
##
## Browser parity (main.js:29377-29392, 29488-29680): every location of
## importance >= 2 gets a label; placement tries nine candidate offsets
## around the anchor and always falls back to a clamped position instead
## of dropping the label on overlap.

## Browser locationLabelImportanceByCategory (main.js:29377-29392).
const IMPORTANCE_BY_CATEGORY := {
	"capital": 6,
	"city": 5,
	"dwarfhold": 5,
	"hillhold": 4,
	"castle": 4,
	"temple": 3,
	"monastery": 3,
	"town": 3,
	"grove": 2,
	"village": 2,
	"tower": 2,
	"shrine": 2,
	"mine": 2,
	"dungeon": 2
}

## Browser resolveLocationLabelCategory (main.js:29394-29456): normalize
## every descriptor (snake/kebab/camelCase to spaced lowercase), join, and
## match category keywords in priority order.
static func resolve_label_category(descriptors: Array[String]) -> String:
	var parts: Array[String] = []
	for value: String in descriptors:
		if value.strip_edges().is_empty():
			continue
		parts.append(_normalize_descriptor(value))
	if parts.is_empty():
		return "location"
	var combined := " ".join(parts)
	if combined.contains("capital"):
		return "capital"
	if combined.contains("dwarfhold"):
		return "dwarfhold"
	if combined.contains("hillhold"):
		return "hillhold"
	if combined.contains("metropolis") or combined.contains("city"):
		return "city"
	if combined.contains("town"):
		return "town"
	if combined.contains("village") or combined.contains("hamlet"):
		return "village"
	if combined.contains("castle") or combined.contains("citadel") or combined.contains("keep"):
		return "castle"
	if combined.contains("temple"):
		return "temple"
	if combined.contains("monastery") or combined.contains("abbey"):
		return "monastery"
	if combined.contains("grove"):
		return "grove"
	if combined.contains("tower"):
		return "tower"
	if combined.contains("shrine"):
		return "shrine"
	if combined.contains("mine"):
		return "mine"
	if combined.contains("dungeon"):
		return "dungeon"
	if combined.contains("camp"):
		return "camp"
	return parts[0]

static func _normalize_descriptor(value: String) -> String:
	var spaced := ""
	for index in range(value.length()):
		var character := value[index]
		if character == "_" or character == "-":
			if not spaced.ends_with(" "):
				spaced += " "
			continue
		if index > 0 and character >= "A" and character <= "Z":
			var previous := value[index - 1]
			if previous >= "a" and previous <= "z":
				spaced += " "
		spaced += character
	return spaced.strip_edges().to_lower()

static func importance_for_category(category: String) -> int:
	return int(IMPORTANCE_BY_CATEGORY.get(category, 1))

## Slack around the measured glyphs so the outline and antialiasing never
## touch the clip edge — a too-tight box clips the first and last letters.
const LABEL_HORIZONTAL_PADDING := 7.0

## The real pixel box a name needs at a given size. Measured from the font
## the labels actually draw with (no font override → the fallback font),
## not guessed from character count, so long names are never clipped.
static func label_box_size(text: String, font_size: int) -> Vector2:
	var font := ThemeDB.fallback_font
	var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	return Vector2(
		maxf(22.0, measured.x + LABEL_HORIZONTAL_PADDING * 2.0),
		maxf(measured.y, float(font_size) * 1.2)
	)

## Browser fonts run 14-22px on canvas; the Godot map labels keep their
## established smaller range, scaled 11-16 by importance tier.
static func font_size_for_importance(importance: int) -> int:
	match importance:
		6:
			return 16
		5:
			return 15
		4:
			return 14
		3:
			return 12
		_:
			return 11

## entries: [{"center": Vector2, "name": String, "category": String,
##            "importance": int, "population": int}]
## config: {"tile_size": int, "map_pixel_size": Vector2, "primary_color":
##          Color, "secondary_color": Color, "outline_color": Color,
##          "outline_size": float}
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
		var a_importance := int(a.get("importance", 0))
		var b_importance := int(b.get("importance", 0))
		if a_importance == b_importance:
			return int(a.get("population", 0)) > int(b.get("population", 0))
		return a_importance > b_importance
	)

	var tile_size := int(config.get("tile_size", 32))
	var map_pixel_size: Vector2 = config.get("map_pixel_size", Vector2.ZERO)
	var primary_color: Color = config.get("primary_color", Color.WHITE)
	var secondary_color: Color = config.get("secondary_color", Color.WHITE)
	var outline_color: Color = config.get("outline_color", Color.BLACK)
	var outline_size := float(config.get("outline_size", 1.0))

	var occupied_rects: Array[Rect2] = []
	for entry: Dictionary in sorted_entries:
		var importance := int(entry.get("importance", 1))
		if importance < 2:
			continue
		var font_size := font_size_for_importance(importance)
		var text := String(entry.get("name", ""))
		var center: Vector2 = entry.get("center", Vector2.ZERO)
		var box := label_box_size(text, font_size)
		var half_size := box * 0.5
		var offset_distance := maxf(float(tile_size) * 0.9, float(font_size) * 2.2)
		# Browser candidateOffsets (main.js:29628-29638): above, below,
		# right, left, four diagonals, far above.
		var candidate_offsets: Array[Vector2] = [
			Vector2(0.0, -offset_distance * 0.75),
			Vector2(0.0, offset_distance * 0.75),
			Vector2(offset_distance, 0.0),
			Vector2(-offset_distance, 0.0),
			Vector2(offset_distance * 0.85, -offset_distance * 0.45),
			Vector2(-offset_distance * 0.85, -offset_distance * 0.45),
			Vector2(offset_distance * 0.85, offset_distance * 0.45),
			Vector2(-offset_distance * 0.85, offset_distance * 0.45),
			Vector2(0.0, -offset_distance * 1.35)
		]
		var placed_center := Vector2.ZERO
		var used_fallback := true
		for offset: Vector2 in candidate_offsets:
			var candidate_center := center + offset
			var candidate_rect := Rect2(candidate_center - half_size, half_size * 2.0)
			if map_pixel_size.x > 0.0 and map_pixel_size.y > 0.0:
				if candidate_rect.position.x < 0.0 or candidate_rect.position.y < 0.0:
					continue
				if candidate_rect.end.x > map_pixel_size.x or candidate_rect.end.y > map_pixel_size.y:
					continue
			if _rect_overlaps_any(candidate_rect, occupied_rects):
				continue
			placed_center = candidate_center
			used_fallback = false
			break
		if used_fallback:
			# Browser fallback (main.js:29667-29680): clamp the anchor into
			# the map bounds and place regardless of overlap.
			placed_center = center
			if map_pixel_size.x > 0.0 and map_pixel_size.y > 0.0:
				placed_center.x = clampf(placed_center.x, half_size.x, map_pixel_size.x - half_size.x)
				placed_center.y = clampf(placed_center.y, half_size.y, map_pixel_size.y - half_size.y)
		var placed_rect := Rect2(placed_center - half_size, half_size * 2.0)
		occupied_rects.append(placed_rect)

		var label := Label.new()
		label.text = text
		label.position = placed_rect.position
		label.size = placed_rect.size
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.clip_text = true
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", primary_color if importance >= 3 else secondary_color)
		label.add_theme_color_override("font_outline_color", outline_color)
		label.add_theme_constant_override("outline_size", int(round(outline_size)))
		label.set_meta("base_font_size", font_size)
		label.set_meta("anchor_center", placed_center)
		label.set_meta("category", String(entry.get("category", "location")))
		label.set_meta("importance", importance)
		label.set_meta("used_fallback", used_fallback)

		var group_key := "major" if importance >= 3 else "minor"
		var target_group := grouped_settlements[group_key] as Node2D
		target_group.add_child(label)

## config: {"tile_size": int, "rescale_on_zoom": bool, "auto_visibility":
##          bool, "min_screen_size": float, "max_screen_size": float}
static func update_zoom_behavior(labels_overlay: Node2D, zoom_factor: float, config: Dictionary) -> void:
	if labels_overlay == null:
		return
	var safe_zoom := maxf(zoom_factor, 0.001)
	var rescale_on_zoom := bool(config.get("rescale_on_zoom", true))
	var auto_visibility := bool(config.get("auto_visibility", true))
	var min_screen_size := float(config.get("min_screen_size", 7.0))
	var max_screen_size := float(config.get("max_screen_size", 50.0))
	# Constant-screen mode (political/nation labels): the font grows as the
	# camera zooms out so the name holds a roughly fixed on-screen size and
	# stays readable on the world-overview political map, and it is never
	# auto-hidden while the overlay is up.
	var constant_screen := bool(config.get("constant_screen_size", false))
	var target_screen_px := float(config.get("target_screen_px", 15.0))
	for group in labels_overlay.get_children():
		for child in group.get_children():
			var label := child as Label
			if label == null:
				continue
			var base_font_size := float(label.get_meta("base_font_size", 12.0))
			var scaled_font_size := base_font_size
			if constant_screen:
				scaled_font_size = clampf(target_screen_px / safe_zoom, base_font_size, base_font_size * 60.0)
			elif rescale_on_zoom:
				# Godot 4: screen px = world px * zoom, so holding readable
				# size while zoomED OUT means growing the world-space font by
				# 1/zoom (half-compensated). Scaling WITH zoom (the old code)
				# double-magnified: specks when zoomed out, banners zoomed in.
				scaled_font_size = maxf(8.0, (base_font_size + (base_font_size / safe_zoom)) * 0.5)
			var rounded_size := int(round(scaled_font_size))

			# Re-shape (font measure + rect) only when the rounded size
			# actually changed: zoom_changed fires per FRAME during dive
			# tweens, and re-measuring every label every frame is the
			# worst-timed work the map does.
			if int(label.get_meta("applied_font_size", -1)) != rounded_size:
				label.set_meta("applied_font_size", rounded_size)
				label.add_theme_font_size_override("font_size", rounded_size)
				# Re-derive the label rect from the scaled font, centered on
				# the collision-resolved placement, so the text is never
				# clipped by a stale, smaller rect after zooming in.
				var anchor := label.get_meta("anchor_center", Vector2.ZERO) as Vector2
				var scaled_box := label_box_size(label.text, rounded_size)
				label.position = anchor - scaled_box * 0.5
				label.size = scaled_box

			if constant_screen:
				label.visible = true
			elif auto_visibility:
				# On-screen glyph height is world font size * zoom (Godot 4).
				var screen_size := scaled_font_size * safe_zoom
				label.visible = screen_size >= min_screen_size and screen_size <= max_screen_size
			else:
				label.visible = true

static func _rect_overlaps_any(candidate: Rect2, rects: Array[Rect2]) -> bool:
	for rect in rects:
		if candidate.intersects(rect):
			return true
	return false
