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

## Creature casts by depth band - the same ladder the fixed strata use,
## kept separate so geology-driven strata field identical wildlife.
static func _creature_slots_for_fraction(fraction: float) -> Array:
	if fraction <= 0.34:
		return SOIL.get("creature_slots", []) as Array
	if fraction <= 0.67:
		return SEDIMENTARY.get("creature_slots", []) as Array
	return IGNEOUS.get("creature_slots", []) as Array

const RELIC_PIECES_BY_CLASS := {
	"sedimentary": ["df_tool_16_0", "df_tool_17_0", "df_tool_18_0", "df_tool_18_1", "df_box_0_0", "df_tool_25_0"],
	"igneous_extrusive": ["df_tool_16_0", "df_tool_16_1", "df_tool_17_0", "df_tool_17_1", "df_tool_26_0", "df_box_0_0"],
	"igneous_intrusive": ["df_tool_16_0", "df_tool_16_1", "df_tool_17_0", "df_tool_17_1", "df_tool_26_0", "df_tool_26_1", "df_box_0_0"],
	"metamorphic": ["df_tool_16_1", "df_tool_17_1", "df_tool_26_0", "df_tool_25_0", "df_box_0_1"]
}

## The stratum a level belongs to when its tile's REAL geology is known:
## the level carves through the profile's own stratigraphic column - its
## named stones, their wall tints, and an ore table built from the
## minerals and gems that country actually hosts. The fungal cavern
## (promoted shallower where karst riddles the limestone) and the
## starmetal deep keep their places in the ladder.
static func stratum_for_level_with_geology(geology: Dictionary, level_index: int, level_count: int) -> Dictionary:
	if geology.is_empty():
		return stratum_for_level(level_index, level_count)
	if level_index <= 0:
		return SURFACE
	var karst := (geology.get("formations", []) as Array).has("Karst Caves")
	var cavern_index := cavern_level_index(level_count)
	if karst and cavern_index < 0 and level_count >= 3:
		cavern_index = maxi(1, (level_count * 2) / 5)
	if level_index == cavern_index:
		var cavern := CAVERN.duplicate(true)
		if karst:
			cavern["name"] = "The Karst Caverns"
		return cavern
	if level_index == level_count - 1 and level_count >= 3:
		return STARMETAL_DEPTH
	var column: Array[Dictionary] = GeologyService.strata_column(geology, maxi(level_count - 1, 1))
	if column.is_empty():
		return stratum_for_level(level_index, level_count)
	var entry := column[clampi(level_index - 1, 0, column.size() - 1)]
	var entry_class := String(entry.get("class", "sedimentary"))
	var fraction := float(level_index) / float(maxi(level_count - 1, 1))
	var is_soil := bool(entry.get("soil", false))
	var vein_range := Vector2i(10, 16) if is_soil else _vein_range_for_class(entry_class)
	var mushroom_range := Vector2i(14, 22) if is_soil \
		else (Vector2i(8, 14) if entry_class == "sedimentary" else (Vector2i(6, 10) if entry_class == "metamorphic" else Vector2i(3, 7)))
	return {
		"relic_pieces": (SOIL.get("relic_pieces") if is_soil else RELIC_PIECES_BY_CLASS.get(entry_class, SEDIMENTARY.get("relic_pieces"))) as Array,
		"name": String(entry.get("name", "Deep Stone")),
		"stone": String(entry.get("stone", "")),
		"ore_drops": geology_ore_drops(geology, fraction > 0.5),
		"vein_count_range": vein_range,
		"mushroom_count_range": mushroom_range,
		"creature_slots": _creature_slots_for_fraction(fraction),
		"tint": entry.get("tint", Color(1.0, 1.0, 1.0)),
		"cavern": false,
		"starmetal": false
	}

static func _vein_range_for_class(layer_class: String) -> Vector2i:
	match layer_class:
		"sedimentary":
			return Vector2i(14, 22)
		"igneous_extrusive":
			return Vector2i(14, 22)
		"metamorphic":
			return Vector2i(15, 24)
		_:
			return Vector2i(16, 26)

## The ore table a tile's real minerals build: every hosted ore mineral
## and gem species becomes a weighted drop paying its true item, tagged
## with the mineral name so a strike can announce what was struck.
static func geology_ore_drops(geology: Dictionary, deep: bool) -> Array:
	var drops: Array = []
	for mineral_variant: Variant in (geology.get("minerals", []) as Array):
		var mineral := mineral_variant as Dictionary
		var mineral_name := String(mineral.get("name", ""))
		var info := GeologyService.MINERAL_CATALOG.get(mineral_name, {}) as Dictionary
		var item := String(mineral.get("item", "Iron Ore"))
		var top := 3 if item == "Iron Ore" or item == "Copper Ore" or item == "Coal" else 2
		drops.append({"name": item, "weight": int(info.get("weight", 8)),
			"min": 1, "max": top + (1 if deep else 0), "mineral": mineral_name})
	for gem_variant: Variant in (geology.get("gems", []) as Array):
		var gem := gem_variant as Dictionary
		var gem_name := String(gem.get("name", ""))
		var gem_info := GeologyService.GEM_CATALOG.get(gem_name, {}) as Dictionary
		drops.append({"name": String(gem.get("item", "Gem Shard")),
			"weight": maxi(int(gem_info.get("weight", 5)) * 3 / 5, 2),
			"min": 1, "max": 1, "mineral": gem_name})
	# Flux country pays flux: carbonate columns (limestone, chalk,
	# dolomite, marble) shed the smelter's Flux Stone alongside their
	# ores - the steel crucible's other ingredient besides coal.
	if bool(geology.get("flux", false)):
		drops.append({"name": "Flux Stone", "weight": 12, "min": 1, "max": 2, "mineral": "Flux-grade Limestone"})
	if deep:
		drops.append({"name": "Runestone", "weight": 3, "min": 1, "max": 1})
	return drops

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
		## Roll the deposit size once; rerolling the threshold every
		## iteration made the loop nearly always stop at the minimum.
		var starmetal_target := rng.randi_range(4, 6)
		for _attempt in range(120):
			if starmetal_cells.size() >= starmetal_target:
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
					## Only blow out solid rock (0), like the sibling carvers,
					## so hollows never shred placed houses and rooms.
					var cell := center + Vector2i(dx, dy)
					if int(grid.get(cell, 0)) == 0:
						grid[cell] = 1
