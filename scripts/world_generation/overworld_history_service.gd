extends RefCounted
class_name OverworldHistoryService

const OVERWORLD_CONTENT := preload("res://scripts/world_generation/overworld_content.gd")

static func build_settlement_history_timeline(
	details: Dictionary,
	settlement_name: String,
	founded_years_ago: int,
	chronology_year: int = 0
) -> String:
	# Timelines anchor to the world's own chronology year (this used to
	# read the real OS clock, which dated dwarven history in the 2020s).
	var current_year := chronology_year
	if current_year <= 0:
		current_year = 1000
	var founding_year := current_year - maxi(1, founded_years_ago)
	var history_kind := resolve_history_kind(details)
	var event_pool := OVERWORLD_CONTENT.resolve_history_event_pool(history_kind)

	var seed_basis := "%s|%s|%s|%s" % [
		settlement_name,
		history_kind,
		str(founding_year),
		String(details.get("ruler_name", ""))
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed_basis.hash())

	var span := maxi(1, founded_years_ago)
	var middle_event_count := clampi(span / 16, 3, 8)

	# Sample WITHOUT replacement (pools run as small as 2 entries), or the
	# timeline repeats the same event verbatim at different years.
	var remaining_pool: Array[String] = []
	remaining_pool.assign(event_pool)
	var selected_events: Array[String] = []
	for _index in range(mini(middle_event_count, remaining_pool.size())):
		var selected_index := rng.randi_range(0, remaining_pool.size() - 1)
		selected_events.append(remaining_pool[selected_index])
		remaining_pool.remove_at(selected_index)

	var events: Array[Dictionary] = []
	events.append({
		"year": founding_year,
		"description": build_founding_event_text(history_kind, settlement_name)
	})

	for index in range(selected_events.size()):
		var progress := float(index + 1) / float(selected_events.size() + 1)
		var year := int(round(lerpf(float(founding_year), float(current_year), progress)))
		events.append({
			"year": year,
			"description": selected_events[index]
		})

	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("year", 0)) < int(b.get("year", 0))
	)

	var rows: Array[String] = []
	for event: Dictionary in events:
		var event_year := int(event.get("year", current_year))
		var years_ago := maxi(0, current_year - event_year)
		var years_label := "year ago" if years_ago == 1 else "years ago"
		var year_text := "[color=#d4a64a][b]%d %s[/b][/color]" % [years_ago, years_label]
		var description := capitalize_timeline_detail(String(event.get("description", "")).strip_edges())
		if description.is_empty():
			continue
		rows.append("• %s — %s" % [year_text, description])
	if rows.is_empty():
		return "No historical records are currently available."
	return "\n".join(rows)

static func resolve_history_kind(details: Dictionary) -> String:
	var settlement_type := String(details.get("settlement_type", "")).strip_edges().to_lower()
	if settlement_type == "town":
		return "human"
	if settlement_type == "woodelfgrove":
		return "wood_elf"
	if settlement_type == "lizardmencity":
		return "lizardmen"
	if settlement_type == "dwarfhold":
		var class_key := String(details.get("settlement_classification_key", "")).strip_edges().to_lower()
		if class_key == "abandoned":
			return "dwarven_variant_abandoned"
		return "dwarven"
	return "generic"

static func build_founding_event_text(history_kind: String, settlement_name: String) -> String:
	match history_kind:
		"human":
			return "%s was founded at a strategic crossroads." % settlement_name
		"dwarven", "dwarven_variant_abandoned":
			return "%s was founded by a dwarven clan deep beneath the mountain." % settlement_name
		"wood_elf":
			return "%s took root beneath the elder trees." % settlement_name
		"lizardmen":
			return "%s was raised as a sacred city of scaled priest-kings." % settlement_name
		_:
			return "%s first appears in the oldest surviving chronicles." % settlement_name

static func capitalize_timeline_detail(detail: String) -> String:
	if detail.is_empty():
		return detail

	for index in range(detail.length()):
		var character := detail.unicode_at(index)
		if character >= 65 and character <= 90:
			return detail
		if character >= 97 and character <= 122:
			return "%s%s%s" % [detail.substr(0, index), char(character - 32), detail.substr(index + 1)]

	return detail

static func variant_array_to_strings(entries: Variant) -> Array[String]:
	var result: Array[String] = []
	if entries is Array:
		for entry: Variant in entries:
			var value := variant_to_clean_string(entry)
			if not value.is_empty():
				result.append(value)
	return result

static func dedupe_trimmed_strings(entries: Array[String]) -> Array[String]:
	var unique: Array[String] = []
	for entry: String in entries:
		var value := entry.strip_edges()
		if value.is_empty() or unique.has(value):
			continue
		unique.append(value)
	return unique

static func variant_to_clean_string(value: Variant) -> String:
	if value == null:
		return ""
	var text := String(value).strip_edges()
	if text.to_lower() == "null":
		return ""
	return text

static func string_or_unknown(value: String) -> String:
	return value if not value.is_empty() else "Unknown"
