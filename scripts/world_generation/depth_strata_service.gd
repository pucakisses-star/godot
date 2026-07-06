class_name DepthStrataService
extends RefCounted

## Dwarf Fortress rule: the earth changes as you descend. Each hold
## level belongs to a stratum that decides its ore table, how thick the
## fungal growth is, which creatures prowl it, and its cast of light.
## One level is a great natural cavern; the deepest holds the starmetal.

const SOIL := {
	"relic_pieces": ["df_tool_13_0", "df_tool_13_1", "df_tool_13_2", "df_tool_10_0", "df_tool_10_1", "df_tool_18_0"],
	"name": "Loamy Soil",
	"ore_drops": [
		{"name": "Copper Ore", "weight": 55, "min": 1, "max": 3},
		{"name": "Iron Ore", "weight": 30, "min": 1, "max": 2},
		{"name": "Gold Nugget", "weight": 8, "min": 1, "max": 1},
		{"name": "Gem Shard", "weight": 7, "min": 1, "max": 1}
	],
	"vein_count_range": Vector2i(10, 16),
	"mushroom_count_range": Vector2i(14, 22),
	"creature_slots": [0, 1, 2],
	"tint": Color(1.02, 0.99, 0.92),
	"cavern": false,
	"starmetal": false
}

const SEDIMENTARY := {
	"relic_pieces": ["df_tool_16_0", "df_tool_17_0", "df_tool_18_0", "df_tool_18_1", "df_box_0_0", "df_tool_25_0"],
	"name": "Sedimentary Stone",
	"ore_drops": [
		{"name": "Iron Ore", "weight": 55, "min": 2, "max": 4},
		{"name": "Copper Ore", "weight": 20, "min": 1, "max": 3},
		{"name": "Gold Nugget", "weight": 15, "min": 1, "max": 2},
		{"name": "Gem Shard", "weight": 10, "min": 1, "max": 1}
	],
	"vein_count_range": Vector2i(14, 22),
	"mushroom_count_range": Vector2i(8, 14),
	"creature_slots": [1, 2, 3, 4],
	"tint": Color(1.0, 1.0, 1.0),
	"cavern": false,
	"starmetal": false
}

const CAVERN := {
	"relic_pieces": ["df_tool_0_0", "df_tool_12_0", "df_tool_12_1", "df_tool_11_0", "df_box_0_1"],
	"name": "The Fungal Caverns",
	"ore_drops": [
		{"name": "Gem Shard", "weight": 40, "min": 1, "max": 2},
		{"name": "Gold Nugget", "weight": 25, "min": 1, "max": 2},
		{"name": "Iron Ore", "weight": 20, "min": 1, "max": 3},
		{"name": "Copper Ore", "weight": 15, "min": 1, "max": 2}
	],
	"vein_count_range": Vector2i(12, 18),
	"mushroom_count_range": Vector2i(60, 90),
	"creature_slots": [0, 1, 2, 4],
	"tint": Color(0.9, 1.02, 0.95),
	"cavern": true,
	"starmetal": false
}

const IGNEOUS := {
	"relic_pieces": ["df_tool_16_0", "df_tool_16_1", "df_tool_17_0", "df_tool_17_1", "df_tool_26_0", "df_tool_26_1", "df_box_0_0"],
	"name": "Igneous Deep",
	"ore_drops": [
		{"name": "Gold Nugget", "weight": 35, "min": 1, "max": 2},
		{"name": "Gem Shard", "weight": 24, "min": 1, "max": 2},
		{"name": "Iron Ore", "weight": 24, "min": 2, "max": 4},
		{"name": "Copper Ore", "weight": 14, "min": 1, "max": 3},
		{"name": "Runestone", "weight": 3, "min": 1, "max": 1}
	],
	"vein_count_range": Vector2i(16, 26),
	"mushroom_count_range": Vector2i(3, 7),
	"creature_slots": [4, 5, 6, 7],
	"tint": Color(1.0, 0.93, 0.9),
	"cavern": false,
	"starmetal": false
}

const STARMETAL_DEPTH := {
	"relic_pieces": ["df_tool_16_1", "df_tool_17_1", "df_tool_26_2", "df_tool_26_3", "df_tool_25_0", "df_box_0_1"],
	"name": "The Starmetal Vein",
	"ore_drops": [
		{"name": "Gold Nugget", "weight": 29, "min": 1, "max": 2},
		{"name": "Gem Shard", "weight": 29, "min": 1, "max": 2},
		{"name": "Iron Ore", "weight": 24, "min": 2, "max": 4},
		{"name": "Copper Ore", "weight": 14, "min": 1, "max": 3},
		{"name": "Runestone", "weight": 4, "min": 1, "max": 1}
	],
	"vein_count_range": Vector2i(18, 26),
	"mushroom_count_range": Vector2i(2, 5),
	"creature_slots": [5, 6, 7],
	"tint": Color(0.95, 0.94, 1.04),
	"cavern": false,
	"starmetal": true
}

const SURFACE := {
	"relic_pieces": [],
	"name": "Surface Halls",
	"ore_drops": [
		{"name": "Iron Ore", "weight": 55, "min": 2, "max": 4},
		{"name": "Copper Ore", "weight": 25, "min": 1, "max": 3},
		{"name": "Gold Nugget", "weight": 12, "min": 1, "max": 2},
		{"name": "Gem Shard", "weight": 8, "min": 1, "max": 1}
	],
	"vein_count_range": Vector2i(0, 0),
	"mushroom_count_range": Vector2i(0, 0),
	"creature_slots": [0, 1, 2, 3, 4, 5, 6, 7],
	"tint": Color(1.0, 1.0, 1.0),
	"cavern": false,
	"starmetal": false
}

## The cavern interrupts the strata around three-fifths depth (only in
## holds deep enough to hold one); the last level always carries the
## starmetal when the hold runs at least three levels deep.
static func cavern_level_index(level_count: int) -> int:
	if level_count < 4:
		return -1
	return maxi(2, (level_count * 3) / 5)

static func stratum_for_level(level_index: int, level_count: int) -> Dictionary:
	if level_index <= 0:
		return SURFACE
	if level_index == cavern_level_index(level_count):
		return CAVERN
	if level_index == level_count - 1 and level_count >= 3:
		return STARMETAL_DEPTH
	var fraction := float(level_index) / float(maxi(level_count - 1, 1))
	if fraction <= 0.34:
		return SOIL
	if fraction <= 0.67:
		return SEDIMENTARY
	return IGNEOUS

## Stamps the stratum's character into a carved warren level: ore veins
## and fungus on open hall floor, cavern hollows blown out around the
## warren, and the starmetal cells on the deepest level. Returns the
## starmetal cells so the scene can mark and guard them.
static func stamp_stratum_features(grid: Dictionary, floor_decor: Dictionary, stratum: Dictionary, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var hall_cells: Array[Vector2i] = []
	for cell_variant: Variant in grid.keys():
		if int(grid[cell_variant]) == 1 and not floor_decor.has(cell_variant):
			hall_cells.append(cell_variant as Vector2i)
	if hall_cells.is_empty():
		return []

	if bool(stratum.get("cavern", false)):
		_carve_cavern_hollows(grid, hall_cells, rng)
		hall_cells.clear()
		for cell_variant: Variant in grid.keys():
			if int(grid[cell_variant]) == 1 and not floor_decor.has(cell_variant):
				hall_cells.append(cell_variant as Vector2i)

	var vein_range := stratum.get("vein_count_range", Vector2i.ZERO) as Vector2i
	for _vein in range(rng.randi_range(vein_range.x, vein_range.y)):
		var cell := hall_cells[rng.randi_range(0, hall_cells.size() - 1)]
		if not floor_decor.has(cell):
			floor_decor[cell] = "stone"

	var mushroom_range := stratum.get("mushroom_count_range", Vector2i.ZERO) as Vector2i
	for _mushroom in range(rng.randi_range(mushroom_range.x, mushroom_range.y)):
		var cell := hall_cells[rng.randi_range(0, hall_cells.size() - 1)]
		if not floor_decor.has(cell):
			floor_decor[cell] = "mushroom_wild" if rng.randi_range(0, 1) == 0 else "mushroom_crop_wild"

	var starmetal_cells: Array[Vector2i] = []
	if bool(stratum.get("starmetal", false)):
		for _attempt in range(120):
			if starmetal_cells.size() >= rng.randi_range(4, 6):
				break
			var cell := hall_cells[rng.randi_range(0, hall_cells.size() - 1)]
			if floor_decor.has(cell) or starmetal_cells.has(cell):
				continue
			floor_decor[cell] = "stone"
			starmetal_cells.append(cell)
	return starmetal_cells

## Blows out organic hollows around the warren so the level reads as a
## natural cavern rather than dug corridors.
static func _carve_cavern_hollows(grid: Dictionary, hall_cells: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	var hollow_count := rng.randi_range(4, 6)
	for _hollow in range(hollow_count):
		var anchor := hall_cells[rng.randi_range(0, hall_cells.size() - 1)]
		var center := anchor + Vector2i(rng.randi_range(-10, 10), rng.randi_range(-8, 8))
		var radius := rng.randi_range(5, 9)
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var wobble := 1.0 + 0.35 * sin(float(dx) * 0.9 + float(dy) * 1.3 + float(rng.randi_range(0, 6)))
				if Vector2(dx, dy).length() <= float(radius) * 0.82 * wobble:
					grid[center + Vector2i(dx, dy)] = 1
