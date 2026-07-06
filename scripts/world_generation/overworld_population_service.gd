extends RefCounted
class_name OverworldPopulationService

## Browser describeTileClimate (main.js:14199-14274): six temperature and
## moisture bands plus proximity qualifiers appended in parentheses. Takes
## the tile data dictionary so the qualifier fields travel with it.
static func describe_climate(tile_data: Dictionary) -> String:
	var temperature := clampf(float(tile_data.get("temperature", 0.0)), 0.0, 1.0)
	var moisture := clampf(float(tile_data.get("moisture", 0.0)), 0.0, 1.0)
	var temp_label := "Tropical heat"
	if temperature <= 0.18:
		temp_label = "Polar chill"
	elif temperature <= 0.32:
		temp_label = "Cold climate"
	elif temperature <= 0.48:
		temp_label = "Cool climate"
	elif temperature <= 0.68:
		temp_label = "Temperate climate"
	elif temperature <= 0.85:
		temp_label = "Warm climate"
	var moisture_label := "waterlogged ground"
	if moisture <= 0.18:
		moisture_label = "parched air"
	elif moisture <= 0.32:
		moisture_label = "dry winds"
	elif moisture <= 0.52:
		moisture_label = "balanced rainfall"
	elif moisture <= 0.7:
		moisture_label = "humid air"
	elif moisture <= 0.85:
		moisture_label = "wet seasons"
	var qualifiers: Array[String] = []
	if clampf(float(tile_data.get("coast_proximity", 0.0)), 0.0, 1.0) >= 0.65:
		qualifiers.append("coastal breezes")
	if clampf(float(tile_data.get("desert_proximity", 0.0)), 0.0, 1.0) >= 0.55 and moisture < 0.4:
		qualifiers.append("dry trade winds")
	if clampf(float(tile_data.get("marsh_proximity", 0.0)), 0.0, 1.0) >= 0.6:
		qualifiers.append("lowland mists")
	if clampf(float(tile_data.get("volcano_proximity", 0.0)), 0.0, 1.0) >= 0.45:
		qualifiers.append("volcanic warmth")
	var description := "%s with %s" % [temp_label, moisture_label]
	if not qualifiers.is_empty():
		description += " (%s)" % format_resource_list(qualifiers)
	return description

static func format_resource_list(resources: Array[String]) -> String:
	var items: Array[String] = []
	for entry: String in resources:
		items.append(String(entry))
	if items.is_empty():
		return "None"
	if items.size() == 1:
		return items[0]
	if items.size() == 2:
		return "%s and %s" % [items[0], items[1]]
	var combined := ""
	for index in range(items.size()):
		if index == items.size() - 1:
			combined += "and %s" % items[index]
		else:
			combined += "%s, " % items[index]
	return combined
