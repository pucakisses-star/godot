extends RefCounted

const MAP_SIZE_DEFINITIONS := {
	"mini": {
		"name": "Mini",
		"dimensions": Vector2i(228, 128)
	},
	"small": {
		"name": "Small",
		"dimensions": Vector2i(341, 192)
	},
	"normal": {
		"name": "Normal",
		"dimensions": Vector2i(455, 256)
	},
	"large": {
		"name": "Large",
		"dimensions": Vector2i(683, 384)
	},
	"extra-large": {
		"name": "Extra Large",
		"dimensions": Vector2i(910, 512)
	}
}

const DEFAULT_WORLD_SETTINGS := {
	"map_size": "Normal",
	"map_size_key": "normal",
	"map_dimensions": Vector2i(455, 256),
	"world_layout": "Normal",
	"world_seed": "",
	"world_name": "",
	"chronology": {
		"year": 250,
		"age": "Age of Discovery"
	},
	"terrain": {
		"forest": 50,
		"mountain": 50,
		"river": 50
	},
	"terrain_ratios": {
		"forest": 0.5,
		"mountain": 0.5,
		"river": 0.5
	},
	"settlements": {
		"humans": 50,
		"dwarves": 50,
		"wood_elves": 50,
		"lizardmen": 25
	},
	"settlement_ratios": {
		"humans": 0.5,
		"dwarves": 0.5,
		"wood_elves": 0.5,
		"lizardmen": 0.25
	}
}

static func default_settings() -> Dictionary:
	return DEFAULT_WORLD_SETTINGS.duplicate(true)

static func merge_with_defaults(raw_settings: Dictionary) -> Dictionary:
	var merged := _deep_merge(default_settings(), raw_settings)
	return normalize(merged)

static func normalize(raw_settings: Dictionary) -> Dictionary:
	var normalized := _deep_merge(default_settings(), raw_settings)

	var map_size_key := _coerce_map_size_key(raw_settings, normalized)
	var map_size_definition: Dictionary = MAP_SIZE_DEFINITIONS.get(map_size_key, MAP_SIZE_DEFINITIONS[DEFAULT_WORLD_SETTINGS["map_size_key"]])
	normalized["map_size_key"] = map_size_key
	normalized["map_size"] = String(map_size_definition.get("name", DEFAULT_WORLD_SETTINGS["map_size"]))
	normalized["map_dimensions"] = map_size_definition.get("dimensions", DEFAULT_WORLD_SETTINGS["map_dimensions"])

	normalized["world_layout"] = str(normalized.get("world_layout", DEFAULT_WORLD_SETTINGS["world_layout"])).strip_edges()
	if String(normalized["world_layout"]).is_empty():
		normalized["world_layout"] = DEFAULT_WORLD_SETTINGS["world_layout"]

	normalized["world_seed"] = str(normalized.get("world_seed", DEFAULT_WORLD_SETTINGS["world_seed"])).strip_edges()
	normalized["world_name"] = str(normalized.get("world_name", DEFAULT_WORLD_SETTINGS["world_name"])).strip_edges()
	normalized["chronology"] = _normalize_chronology(normalized.get("chronology", {}) as Dictionary)

	normalized["terrain_ratios"] = _normalize_ratio_dict(
		normalized.get("terrain_ratios", {}) as Dictionary,
		normalized.get("terrain", {}) as Dictionary,
		DEFAULT_WORLD_SETTINGS["terrain_ratios"] as Dictionary
	)
	normalized["settlement_ratios"] = _normalize_ratio_dict(
		normalized.get("settlement_ratios", {}) as Dictionary,
		normalized.get("settlements", {}) as Dictionary,
		DEFAULT_WORLD_SETTINGS["settlement_ratios"] as Dictionary
	)

	normalized["terrain"] = _ratios_to_percentages(normalized["terrain_ratios"] as Dictionary)
	normalized["settlements"] = _ratios_to_percentages(normalized["settlement_ratios"] as Dictionary)

	return normalized

static func _deep_merge(base: Dictionary, override: Dictionary) -> Dictionary:
	for key: Variant in override.keys():
		if base.has(key) and base[key] is Dictionary and override[key] is Dictionary:
			base[key] = _deep_merge((base[key] as Dictionary).duplicate(true), override[key] as Dictionary)
		else:
			base[key] = override[key]
	return base

static func _coerce_map_size_key(raw_settings: Dictionary, merged_settings: Dictionary) -> String:
	var key := str(merged_settings.get("map_size_key", "")).strip_edges().to_lower()
	if MAP_SIZE_DEFINITIONS.has(key):
		return key

	var map_size_name := str(raw_settings.get("map_size", merged_settings.get("map_size", ""))).strip_edges().to_lower()
	for map_size_key: String in MAP_SIZE_DEFINITIONS.keys():
		if str((MAP_SIZE_DEFINITIONS[map_size_key] as Dictionary).get("name", "")).to_lower() == map_size_name:
			return map_size_key

	var map_dimensions: Variant = raw_settings.get("map_dimensions", merged_settings.get("map_dimensions", Vector2i.ZERO))
	if map_dimensions is Vector2i:
		for dimensions_key: String in MAP_SIZE_DEFINITIONS.keys():
			if (MAP_SIZE_DEFINITIONS[dimensions_key] as Dictionary).get("dimensions", Vector2i.ZERO) == map_dimensions:
				return dimensions_key

	return DEFAULT_WORLD_SETTINGS["map_size_key"]

static func _normalize_chronology(chronology: Dictionary) -> Dictionary:
	var defaults: Dictionary = DEFAULT_WORLD_SETTINGS["chronology"] as Dictionary
	var year := int(chronology.get("year", defaults["year"]))
	## Year 0 is a legitimate embark roll (dawn of history); a missing
	## key already falls back to the default above, so only reject
	## negative years here.
	if year < 0:
		year = int(defaults["year"])

	var raw_age: Variant = chronology.get("age", defaults["age"])
	var age := str(raw_age).strip_edges()
	if raw_age is int or raw_age is float or age.is_valid_int():
		age = "Age %d" % max(1, int(raw_age))
	if age.is_empty():
		age = str(defaults["age"])

	return {
		"year": year,
		"age": age
	}

static func _normalize_ratio_dict(primary: Dictionary, legacy_percentages: Dictionary, defaults: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for key: String in defaults.keys():
		var default_ratio := float(defaults[key])
		var ratio_value := _coerce_ratio(primary.get(key, null), default_ratio)
		if primary.has(key):
			normalized[key] = ratio_value
			continue

		if legacy_percentages.has(key):
			normalized[key] = _coerce_ratio(legacy_percentages[key], default_ratio)
			continue

		normalized[key] = default_ratio
	return normalized

static func _coerce_ratio(value: Variant, fallback: float) -> float:
	if value == null:
		return fallback
	if not (value is int or value is float):
		var numeric_text := str(value).strip_edges()
		if not numeric_text.is_valid_float() and not numeric_text.is_valid_int():
			return fallback
		value = float(numeric_text)

	var numeric_value := float(value)
	if numeric_value > 1.0 and numeric_value <= 100.0:
		numeric_value /= 100.0
	return clampf(numeric_value, 0.0, 1.0)

static func _ratios_to_percentages(ratios: Dictionary) -> Dictionary:
	var percentages: Dictionary = {}
	for key: String in ratios.keys():
		percentages[key] = int(roundf(float(ratios[key]) * 100.0))
	return percentages

static func layout_generation_preset(layout_label: String) -> Dictionary:
	# Every preset lists every tunable so switching layouts can never leak
	# values from a previously applied preset.
	var layout_presets := {
		"normal": {
			# DF-style geography: several ragged landmasses split by channels
			# and inland seas, land running close to the map edges.
			"landmass_center_count": 7,
			"landmass_center_min_separation": 0.0,
			"center_shape_strength": 1.0,
			"landmass_mask_strength": 0.55,
			"landmass_mask_scale": 1.6,
			"landmass_mask_threshold": 0.45,
			"landmass_mask_edge_falloff": 0.07,
			"falloff_strength": 0.0,
			"landmass_falloff_scale": 2.0,
			"edge_ocean_strength": 0.06,
			"edge_ocean_falloff": 0.1,
			"water_level": 0.45,
			# Browser worldGenerationProfiles (main.js:20044-20108):
			# seaLevelShift feeds targetWaterRatio = 0.47 + shift,
			# rainfallBias feeds the rainfall field directly.
			"sea_level_shift": 0.02,
			"rainfall_bias": 0.0
		},
		"major continent": {
			# One dominant ragged landmass surrounded by open ocean.
			"landmass_center_count": 1,
			"landmass_center_min_separation": 0.0,
			"center_shape_strength": 1.4,
			"landmass_mask_strength": 0.4,
			"landmass_mask_scale": 1.1,
			"landmass_mask_threshold": 0.44,
			"landmass_mask_edge_falloff": 0.16,
			"falloff_strength": 0.34,
			"landmass_falloff_scale": 1.5,
			"edge_ocean_strength": 0.3,
			"edge_ocean_falloff": 0.28,
			"water_level": 0.45,
			"sea_level_shift": 0.0,
			"rainfall_bias": 0.0
		},
		"twin continents": {
			# Two forced lobes far apart with a sea channel between them.
			"landmass_center_count": 2,
			"landmass_center_min_separation": 1.1,
			"center_shape_strength": 3.2,
			"landmass_mask_strength": 0.3,
			"landmass_mask_scale": 1.5,
			"landmass_mask_threshold": 0.45,
			"landmass_mask_edge_falloff": 0.1,
			"falloff_strength": 0.0,
			"landmass_falloff_scale": 1.1,
			"edge_ocean_strength": 0.12,
			"edge_ocean_falloff": 0.14,
			"water_level": 0.45,
			"sea_level_shift": -0.02,
			"rainfall_bias": -0.02
		},
		"inland sea": {
			# Inverted radial profile: sea at the centre, a ragged ring of
			# land around it.
			"landmass_center_count": 4,
			"landmass_center_min_separation": 0.0,
			"center_shape_strength": 0.4,
			"landmass_mask_strength": 0.25,
			"landmass_mask_scale": 1.6,
			"landmass_mask_threshold": 0.48,
			"landmass_mask_edge_falloff": 0.06,
			"falloff_strength": -0.45,
			"falloff_power": 1.3,
			"landmass_falloff_scale": 1.6,
			"edge_ocean_strength": 0.05,
			"edge_ocean_falloff": 0.08,
			"water_level": 0.49,
			"sea_level_shift": 0.04,
			"rainfall_bias": 0.03
		},
		"archipelago": {
			# High-frequency mask with no continental anchors: island fields.
			"landmass_center_count": 9,
			"landmass_center_min_separation": 0.0,
			"center_shape_strength": 0.0,
			"landmass_mask_strength": 0.65,
			"landmass_mask_scale": 3.8,
			"landmass_mask_threshold": 0.55,
			"landmass_mask_edge_falloff": 0.07,
			"falloff_strength": 0.0,
			"landmass_falloff_scale": 1.35,
			"edge_ocean_strength": 0.06,
			"edge_ocean_falloff": 0.08,
			"water_level": 0.5,
			"sea_level_shift": 0.08,
			"rainfall_bias": 0.05
		}
	}
	var key := layout_label.strip_edges().to_lower()
	if layout_presets.has(key):
		return layout_presets[key]
	return layout_presets["normal"]

