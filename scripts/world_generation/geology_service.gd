extends RefCounted
class_name GeologyService

## Dwarf Fortress-style geology, derived deterministically from the world
## seed and each tile's terrain — no storage, recomputed on demand. Every
## land tile gets a layer class (what rock family underlies it), the stones
## of that family, soil depth, clay, an aquifer rating, a metals list drawn
## from host-rock-appropriate pools, and flux/coal flags. The dwarf hold's
## mining reads the same profiles so what the map promises, the pick finds.

const LAYER_SEDIMENTARY := "sedimentary"
const LAYER_IGNEOUS_EXTRUSIVE := "igneous_extrusive"
const LAYER_IGNEOUS_INTRUSIVE := "igneous_intrusive"
const LAYER_METAMORPHIC := "metamorphic"

const LAYER_LABELS := {
	LAYER_SEDIMENTARY: "Sedimentary",
	LAYER_IGNEOUS_EXTRUSIVE: "Igneous (volcanic)",
	LAYER_IGNEOUS_INTRUSIVE: "Igneous (deep)",
	LAYER_METAMORPHIC: "Metamorphic"
}

const LAYER_STONES := {
	LAYER_SEDIMENTARY: ["Limestone", "Sandstone", "Shale", "Mudstone", "Chalk", "Dolomite", "Siltstone", "Chert"],
	LAYER_IGNEOUS_EXTRUSIVE: ["Basalt", "Rhyolite", "Obsidian", "Andesite", "Dacite"],
	LAYER_IGNEOUS_INTRUSIVE: ["Granite", "Diorite", "Gabbro"],
	LAYER_METAMORPHIC: ["Gneiss", "Schist", "Quartzite", "Marble", "Slate", "Phyllite"]
}

## Metals by host family, roughly mirroring Dwarf Fortress' environment
## rules (hematite in sedimentary and volcanic rock, cassiterite in
## granite, precious metals in deep and metamorphic country).
const METAL_POOLS := {
	LAYER_SEDIMENTARY: ["Iron", "Copper", "Lead", "Zinc", "Silver"],
	LAYER_IGNEOUS_EXTRUSIVE: ["Iron", "Copper", "Gold"],
	LAYER_IGNEOUS_INTRUSIVE: ["Tin", "Copper", "Silver", "Gold", "Nickel", "Platinum"],
	LAYER_METAMORPHIC: ["Gold", "Silver", "Copper", "Zinc", "Lead"]
}

const FLUX_STONES := ["Limestone", "Chalk", "Dolomite", "Marble"]

## Hits a rock of each family takes (feeds the hold's mining durability).
const LAYER_DURABILITY := {
	LAYER_SEDIMENTARY: 9,
	LAYER_IGNEOUS_EXTRUSIVE: 12,
	LAYER_METAMORPHIC: 14,
	LAYER_IGNEOUS_INTRUSIVE: 16
}

## Deeper hold levels progress toward harder country rock, DF-style:
## whatever the surface family is, depth trends metamorphic then deep
## igneous.
static func layer_class_for_depth(profile: Dictionary, level_index: int) -> String:
	var surface_class := String(profile.get("layer_class", LAYER_SEDIMENTARY))
	if level_index <= 0:
		return surface_class
	if level_index == 1:
		if surface_class == LAYER_SEDIMENTARY or surface_class == LAYER_IGNEOUS_EXTRUSIVE:
			return LAYER_METAMORPHIC
		return surface_class
	return LAYER_IGNEOUS_INTRUSIVE

static func _hash01(x: int, y: int, seed_value: int) -> float:
	var h: int = x * 374761393 + y * 668265263 + seed_value * 2654435761
	h = int((h ^ (h >> 13)) * 1274126177)
	h = h ^ (h >> 16)
	var unsigned: int = h & 0xffffffff
	return float(unsigned) / 4294967295.0

## Geology for an overworld tile. tile_info is the map's _tile_data entry;
## water tiles return an empty profile.
static func profile_for_tile(coord: Vector2i, tile_info: Dictionary, map_seed: int) -> Dictionary:
	var base_biome := String(tile_info.get("base_biome", tile_info.get("biome_type", "grassland")))
	if base_biome == "water":
		return {}
	return _build_profile(
		coord.x,
		coord.y,
		map_seed,
		base_biome,
		String(tile_info.get("hill_overlay", "")),
		clampf(float(tile_info.get("volcano_proximity", 0.0)), 0.0, 1.0),
		clampf(float(tile_info.get("coast_proximity", 0.0)), 0.0, 1.0),
		clampf(float(tile_info.get("moisture", 0.5)), 0.0, 1.0)
	)

## Fallback geology for a hold opened without journey context (direct
## scene runs, old saves): fabricates plausible mountain terrain inputs
## from the seed so the profile is stable per world. Holds entered from
## the overworld use their own tile's profile instead.
static func profile_for_seed(seed_value: int) -> Dictionary:
	var moisture := 0.3 + _hash01(3, 17, seed_value) * 0.5
	var volcano := 0.4 if _hash01(11, 29, seed_value) < 0.12 else 0.0
	return _build_profile(7, 13, seed_value, "mountain", "mountain", volcano, _hash01(5, 23, seed_value) * 0.4, moisture)

static func _build_profile(
	x: int,
	y: int,
	seed_value: int,
	base_biome: String,
	hill_overlay: String,
	volcano_proximity: float,
	coast_proximity: float,
	moisture: float
) -> Dictionary:
	var is_mountain := hill_overlay == "mountain" or base_biome == "mountain"
	var class_roll := _hash01(x, y, seed_value + 0x6E01)
	var layer_class := LAYER_SEDIMENTARY
	if volcano_proximity > 0.25:
		layer_class = LAYER_IGNEOUS_EXTRUSIVE
	elif is_mountain:
		layer_class = LAYER_METAMORPHIC if class_roll < 0.5 else LAYER_IGNEOUS_INTRUSIVE
	elif base_biome == "marsh" or coast_proximity > 0.35:
		layer_class = LAYER_SEDIMENTARY
	elif base_biome == "desert" or base_biome == "badlands":
		layer_class = LAYER_SEDIMENTARY if class_roll < 0.55 else LAYER_IGNEOUS_EXTRUSIVE
	else:
		if class_roll < 0.45:
			layer_class = LAYER_SEDIMENTARY
		elif class_roll < 0.72:
			layer_class = LAYER_METAMORPHIC
		else:
			layer_class = LAYER_IGNEOUS_INTRUSIVE

	# Two or three named strata from the family, flux-bearing where the
	# family allows it.
	var pool := (LAYER_STONES[layer_class] as Array).duplicate()
	var stones: Array[String] = []
	var stone_count := 2 + (1 if _hash01(x, y, seed_value + 0x6E02) < 0.5 else 0)
	for stone_index in range(stone_count):
		if pool.is_empty():
			break
		var pick := int(_hash01(x, y, seed_value + 0x6E10 + stone_index) * float(pool.size())) % pool.size()
		stones.append(String(pool[pick]))
		pool.remove_at(pick)
	if layer_class == LAYER_SEDIMENTARY and _hash01(x, y, seed_value + 0x6E03) < 0.55 and not _has_flux(stones):
		stones[0] = "Limestone"
	var flux := _has_flux(stones)
	var coal := layer_class == LAYER_SEDIMENTARY and _hash01(x, y, seed_value + 0x6E04) < 0.4

	# Soil depth from biome and wetness; DF's flat wet lowlands carry the
	# deepest soil, mountains bare rock.
	var soil := "Shallow"
	if is_mountain or base_biome == "badlands":
		soil = "None" if _hash01(x, y, seed_value + 0x6E05) < 0.6 else "Shallow"
	elif base_biome == "marsh":
		soil = "Very deep"
	elif base_biome == "desert" or base_biome == "tundra":
		soil = "Shallow"
	elif moisture > 0.6:
		soil = "Very deep"
	elif moisture > 0.4:
		soil = "Deep"

	var clay := ""
	if base_biome != "desert" and moisture > 0.5 and (layer_class == LAYER_SEDIMENTARY or base_biome == "marsh"):
		clay = "Deep clay" if moisture > 0.7 and soil == "Very deep" else "Shallow clay"

	var aquifer := ""
	var porous := layer_class == LAYER_SEDIMENTARY or soil == "Deep" or soil == "Very deep"
	if porous and not is_mountain:
		if moisture > 0.75:
			aquifer = "Heavy aquifer"
		elif moisture > 0.5:
			aquifer = "Light aquifer"

	# Shallow metals from the surface family, deep metals from the hard
	# country rock underneath - the tooltip shows the union.
	var metals: Array[String] = []
	_pick_metals(metals, METAL_POOLS[layer_class] as Array, x, y, seed_value + 0x6E20, 1 + int(_hash01(x, y, seed_value + 0x6E06) * 2.0))
	var deep_class := layer_class_for_depth({"layer_class": layer_class}, 2)
	_pick_metals(metals, METAL_POOLS[deep_class] as Array, x, y, seed_value + 0x6E30, 1 + int(_hash01(x, y, seed_value + 0x6E07) * 2.99))
	if layer_class == LAYER_SEDIMENTARY and not metals.has("Iron") and _hash01(x, y, seed_value + 0x6E08) < 0.7:
		metals.insert(0, "Iron")

	return {
		"layer_class": layer_class,
		"layer_label": String(LAYER_LABELS[layer_class]),
		"stones": stones,
		"soil": soil,
		"clay": clay,
		"aquifer": aquifer,
		"metals": metals,
		"flux": flux,
		"coal": coal
	}

static func _has_flux(stones: Array[String]) -> bool:
	for stone: String in stones:
		if FLUX_STONES.has(stone):
			return true
	return false

static func _pick_metals(into: Array[String], pool: Array, x: int, y: int, seed_value: int, count: int) -> void:
	var candidates := pool.duplicate()
	for pick_index in range(count):
		if candidates.is_empty():
			return
		var pick := int(_hash01(x, y, seed_value + pick_index) * float(candidates.size())) % candidates.size()
		var metal := String(candidates[pick])
		candidates.remove_at(pick)
		if not into.has(metal):
			into.append(metal)
