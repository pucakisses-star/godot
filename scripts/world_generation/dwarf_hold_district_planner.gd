extends RefCounted
class_name DwarfHoldDistrictPlanner

## City-scale layout for a dwarfhold's surface level: instead of one
## homogeneous cavern, the hold is planned as named districts — a central
## Great Hall, residential quarters, an industrial Anvil Quarter, mushroom
## farms, peripheral mines, and a gated causeway east to a trading
## outpost — each carved as an organic cavern blob, densely filled with
## buildings separated by narrow alleys, and linked by wide tunnels.
## Deeper levels keep the older warren-style generator ("the lower
## reaches").

const CELL_ROCK := 0
const CELL_HALL := 1
const CELL_HOUSE := 2
const CELL_BUILDING := 3
const CELL_PLAZA := 4

## Footprints are half-extents (gross span = 2*radius+1): a (2,2) house is
## a 5x5 plot with a 3x3 room; anything (3,2) and up is big enough for the
## interior planner to split into multiple rooms.
const RESIDENCE_TYPES := {
	"house": {"weight": 0.62, "radius_min": Vector2i(2, 2), "radius_max": Vector2i(4, 3)},
	"dormitory": {"weight": 0.24, "radius_min": Vector2i(3, 3), "radius_max": Vector2i(5, 4)},
	"barracks": {"weight": 0.14, "radius_min": Vector2i(3, 3), "radius_max": Vector2i(4, 4)}
}

const EXTRA_HALL_NAMES: Array[String] = [
	"Hall of Iron", "Hall of Bronze", "Hall of Steel", "Hall of Mithril",
	"Hall of Copper", "Hall of Gold", "Hall of the Long Banner",
	"Greenstone Hall", "Emberdeep Hall", "Hall of Echoes"
]

const MINE_NAMES: Array[String] = [
	"Iron Mines", "Old Mines", "Deep Mines", "Silver Mines", "Coal Delvings"
]

## Buildings each district kind always tries to place, in order.
const DISTRICT_BUILDING_RECIPES := {
	"great_hall": ["temple", "archives", "merchants_counting_house", "auction_house", "guild_hall"],
	"anvil_quarter": ["forge", "smeltery", "armory", "engineering_workshop", "workshop", "weapon_shop", "armor_shop", "workshop", "forge", "engineers_foundry"],
	"common_quarter": ["tavern", "kitchen", "bakery", "general_goods_shop", "infirmary", "brewery", "granary", "butchery", "millhouse", "cooperage"],
	"noble_quarter": ["bank_vaults", "gemcutters_studio", "auction_house", "tailoring_shop", "barber_shop", "enchanting_study"],
	"mushroom_farms": ["mushroom_farm", "mushroom_farm", "granary", "mushroom_farm"],
	"trading_outpost": ["trade_supply_store", "storage_warehouse"],
	"thieves_guild": ["storage_warehouse"]
}

## Share of the level's bed budget housed in each residential district.
const DISTRICT_BED_SHARES := {
	"common_quarter": 0.62,
	"noble_quarter": 0.18,
	"anvil_quarter": 0.14,
	"mushroom_farms": 0.06
}

static func generate_city_level(
	rng: RandomNumberGenerator,
	level_npc_target: int,
	total_npc_target: int,
	bed_target: int,
	building_target: int
) -> Dictionary:
	var grid: Dictionary = {}
	var building_type_map: Dictionary = {}
	var residence_type_map: Dictionary = {}
	var district_cell_map: Dictionary = {}
	var floor_decor: Dictionary = {}
	var labels: Array = []

	var scale := clampf(sqrt(float(maxi(level_npc_target, 20)) / 110.0), 0.55, 1.9)
	var districts := _plan_districts(rng, total_npc_target, bed_target, building_target, scale)

	# 1. Carve every district blob.
	for district: Dictionary in districts:
		_carve_district(grid, district, rng)

	# 2. Tunnels: every district connects to its hub (usually the Great Hall).
	for district: Dictionary in districts:
		var hub_id := String(district.get("hub", ""))
		if hub_id.is_empty():
			continue
		var hub := _district_by_id(districts, hub_id)
		if hub.is_empty():
			continue
		_dig_tunnel(grid, district, hub, rng)

	# 3. Entrance causeway with gate pinches, east to the trading outpost.
	var great_hall := _district_by_id(districts, "great_hall")
	var outpost := _district_by_id(districts, "trading_outpost")
	if not great_hall.is_empty() and not outpost.is_empty():
		_dig_causeway(grid, great_hall, outpost, labels, rng)

	# 4. Fill districts with buildings and residences.
	for district: Dictionary in districts:
		_fill_district(grid, district, building_type_map, residence_type_map, floor_decor, rng)

	# 5. Tag district cells and place labels.
	for district: Dictionary in districts:
		var center := district.get("center", Vector2i.ZERO) as Vector2i
		labels.append({"name": String(district.get("name", "")), "center": center})
		var radius := int(district.get("radius", 10))
		## Tag out to the same inflated reach _fill_district places structures
		## (radius * 1.35 + 2, plus the stamp's +2 slack) so the outer ring of
		## a district is never left untagged for hostile spawns.
		var tag_radius := roundi(float(radius) * 1.35) + 4
		for y in range(center.y - tag_radius, center.y + tag_radius + 1):
			for x in range(center.x - tag_radius, center.x + tag_radius + 1):
				var cell := Vector2i(x, y)
				if grid.has(cell) and not district_cell_map.has(cell):
					district_cell_map[cell] = String(district.get("name", ""))

	return {
		"grid": grid,
		"building_type_map": building_type_map,
		"residence_type_map": residence_type_map,
		"district_labels": labels,
		"district_cell_map": district_cell_map,
		"floor_decor": floor_decor
	}

static func _plan_districts(rng: RandomNumberGenerator, total_npc_target: int, bed_target: int, building_target: int, scale: float) -> Array[Dictionary]:
	var districts: Array[Dictionary] = []
	var has_noble := total_npc_target >= 200
	var has_palace := total_npc_target >= 400
	var extra_commons := clampi(bed_target / 90, 0, 3)

	var great_hall_radius := maxi(9, roundi(13.0 * scale))
	districts.append({
		"id": "great_hall", "kind": "great_hall", "name": "Great Hall",
		"center": Vector2i.ZERO, "radius": great_hall_radius,
		"hub": "", "beds": 0, "has_palace": has_palace,
		"plaza_core": true
	})

	var bed_shares := DISTRICT_BED_SHARES.duplicate()
	if not has_noble:
		bed_shares["common_quarter"] = float(bed_shares["common_quarter"]) + float(bed_shares["noble_quarter"])
		bed_shares["noble_quarter"] = 0.0

	var ring_kinds: Array[String] = ["common_quarter", "anvil_quarter", "mushroom_farms"]
	if has_noble:
		ring_kinds.append("noble_quarter")
	for extra_index in range(extra_commons):
		ring_kinds.append("common_quarter")

	var common_bed_pool := int(float(bed_target) * float(bed_shares["common_quarter"]))
	var common_count := 1 + extra_commons
	var used_hall_names: Array[String] = []
	var angle := rng.randf_range(0.0, TAU)
	var angle_step := TAU / float(ring_kinds.size())
	var common_seen := 0
	for kind in ring_kinds:
		var beds := 0
		var district_name := ""
		match kind:
			"common_quarter":
				beds = common_bed_pool / common_count
				if common_seen == 0:
					district_name = "Common Quarter"
				else:
					district_name = _pick_unused(EXTRA_HALL_NAMES, used_hall_names, rng, "Hall of Iron")
				common_seen += 1
			"anvil_quarter":
				beds = int(float(bed_target) * float(bed_shares["anvil_quarter"]))
				district_name = "Anvil Quarter"
			"noble_quarter":
				beds = int(float(bed_target) * float(bed_shares["noble_quarter"]))
				district_name = "Noble Quarter"
			"mushroom_farms":
				beds = int(float(bed_target) * float(bed_shares["mushroom_farms"]))
				district_name = "Mushroom Farms"
		var radius := _radius_for_district(kind, beds, scale)
		var wobble := rng.randf_range(-0.1, 0.1)
		var distance := great_hall_radius + radius + rng.randi_range(14, 22)
		var center := Vector2i(
			roundi(cos(angle + wobble) * float(distance)),
			roundi(sin(angle + wobble) * float(distance) * 0.85)
		)
		districts.append({
			"id": "%s_%d" % [kind, districts.size()], "kind": kind, "name": district_name,
			"center": center, "radius": radius, "hub": "great_hall", "beds": beds,
			"has_palace": false, "plaza_core": kind != "mushroom_farms"
		})
		angle += angle_step

	# Peripheral mines: far out along a rocky tunnel, west or south.
	var mine_angle := rng.randf_range(PI * 0.6, PI * 1.35)
	var mine_distance := roundi(float(great_hall_radius) + 34.0 * scale + float(rng.randi_range(8, 18)))
	districts.append({
		"id": "mine", "kind": "mine", "name": _pick(MINE_NAMES, rng, "Iron Mines"),
		"center": Vector2i(roundi(cos(mine_angle) * float(mine_distance)), roundi(sin(mine_angle) * float(mine_distance) * 0.8)),
		"radius": maxi(6, roundi(8.0 * scale)), "hub": _nearest_ring_id(districts), "beds": 0,
		"has_palace": false, "plaza_core": false
	})

	# Trading outpost past the eastern causeway.
	var east_x := 0
	for district: Dictionary in districts:
		var center := district.get("center", Vector2i.ZERO) as Vector2i
		east_x = maxi(east_x, center.x + int(district.get("radius", 10)))
	districts.append({
		"id": "trading_outpost", "kind": "trading_outpost", "name": "Trading Outpost",
		"center": Vector2i(east_x + rng.randi_range(24, 34), rng.randi_range(-6, 6)),
		"radius": 7, "hub": "", "beds": 0, "has_palace": false, "plaza_core": false
	})

	# Rarely, a hidden thieves' guild at the end of a long thin tunnel.
	if total_npc_target >= 150 and rng.randf() < 0.35:
		districts.append({
			"id": "thieves_guild", "kind": "thieves_guild", "name": "Thieves' Guild",
			"center": Vector2i(-mine_distance - rng.randi_range(6, 14), mine_distance / 2 + rng.randi_range(4, 12)),
			"radius": 5, "hub": "mine", "beds": 0, "has_palace": false, "plaza_core": false
		})

	# Building quota bookkeeping so the level target is roughly respected.
	var recipe_limit := clampi(3 + bed_target / 10, 3, 99)
	for district: Dictionary in districts:
		district["recipe_limit"] = recipe_limit
	var recipe_total := 0
	for district: Dictionary in districts:
		recipe_total += mini(recipe_limit, (DISTRICT_BUILDING_RECIPES.get(String(district.get("kind", "")), []) as Array).size())
	var spare := maxi(0, building_target - recipe_total)
	for district: Dictionary in districts:
		var kind := String(district.get("kind", ""))
		district["extra_buildings"] = 0
		if kind == "common_quarter" or kind == "anvil_quarter":
			district["extra_buildings"] = spare / 4

	return districts

static func _radius_for_district(kind: String, beds: int, scale: float) -> int:
	var recipe_size := (DISTRICT_BUILDING_RECIPES.get(kind, []) as Array).size()
	## Civic plots grew to ~9x7 gross for multi-room interiors, and homes
	## to ~7x5, so each recipe slot and each bed budgets more floor.
	var estimated_area := float(recipe_size) * 66.0 + float(beds) * 11.0
	var radius := roundi(sqrt(maxf(estimated_area, 60.0) / PI) * 1.55)
	return clampi(roundi(float(radius) * clampf(scale, 0.9, 1.5)), 8, 28)

static func _district_by_id(districts: Array[Dictionary], id: String) -> Dictionary:
	for district: Dictionary in districts:
		if String(district.get("id", "")) == id:
			return district
	return {}

static func _nearest_ring_id(districts: Array[Dictionary]) -> String:
	# Prefer hooking mines to an industrial or common district over the core.
	for district: Dictionary in districts:
		if String(district.get("kind", "")) == "anvil_quarter":
			return String(district.get("id", "great_hall"))
	return "great_hall"

## --- carving -----------------------------------------------------------

static func _carve_district(grid: Dictionary, district: Dictionary, rng: RandomNumberGenerator) -> void:
	var center := district.get("center", Vector2i.ZERO) as Vector2i
	var radius := int(district.get("radius", 10))
	var kind := String(district.get("kind", ""))

	if kind == "mine":
		_carve_stringy_cave(grid, center, radius, rng)
		return

	# Organic blob: overlapping ellipses random-walked around the center.
	var disk_count := 8 + rng.randi_range(0, 6)
	var walker := center
	for disk_index in range(disk_count):
		var disk_radius := Vector2i(
			maxi(3, roundi(float(radius) * rng.randf_range(0.34, 0.6))),
			maxi(3, roundi(float(radius) * rng.randf_range(0.28, 0.5)))
		)
		_dig_ellipse(grid, walker, disk_radius, CELL_HALL)
		walker = center + Vector2i(
			rng.randi_range(-radius + disk_radius.x / 2, radius - disk_radius.x / 2),
			rng.randi_range(-radius + disk_radius.y / 2, radius - disk_radius.y / 2)
		)

	if bool(district.get("plaza_core", false)):
		var core_radius := Vector2i(maxi(3, radius / 3), maxi(3, radius / 4))
		if kind == "great_hall":
			core_radius = Vector2i(maxi(5, radius / 2), maxi(4, roundi(float(radius) / 2.5)))
		_dig_ellipse(grid, center, core_radius, CELL_PLAZA)

static func _carve_stringy_cave(grid: Dictionary, center: Vector2i, radius: int, rng: RandomNumberGenerator) -> void:
	var walker := center
	for tendril in range(3 + rng.randi_range(0, 2)):
		walker = center
		var heading := rng.randf_range(0.0, TAU)
		for step in range(radius * 2):
			var pocket := Vector2i(rng.randi_range(2, 4), rng.randi_range(2, 3))
			_dig_ellipse(grid, walker, pocket, CELL_HALL)
			heading += rng.randf_range(-0.8, 0.8)
			walker += Vector2i(roundi(cos(heading) * 2.0), roundi(sin(heading) * 2.0))

static func _dig_ellipse(grid: Dictionary, center: Vector2i, radius: Vector2i, tile: int) -> void:
	for y in range(center.y - radius.y, center.y + radius.y + 1):
		for x in range(center.x - radius.x, center.x + radius.x + 1):
			var dx := float(x - center.x) / maxf(float(radius.x), 0.001)
			var dy := float(y - center.y) / maxf(float(radius.y), 0.001)
			if dx * dx + dy * dy <= 1.0:
				var cell := Vector2i(x, y)
				var existing := int(grid.get(cell, CELL_ROCK))
				if existing == CELL_ROCK or (tile == CELL_PLAZA and existing == CELL_HALL):
					grid[cell] = tile

static func _dig_tunnel(grid: Dictionary, from_district: Dictionary, to_district: Dictionary, rng: RandomNumberGenerator) -> void:
	var start := from_district.get("center", Vector2i.ZERO) as Vector2i
	var finish := to_district.get("center", Vector2i.ZERO) as Vector2i
	var kind := String(from_district.get("kind", ""))
	var width := 1 if kind == "thieves_guild" else rng.randi_range(2, 3)
	if kind == "mine":
		width = rng.randi_range(1, 2)
	# Wind through a midpoint so long tunnels aren't ruler-straight.
	var mid := (start + finish) / 2 + Vector2i(rng.randi_range(-6, 6), rng.randi_range(-6, 6))
	_dig_wide_path(grid, start, mid, width)
	_dig_wide_path(grid, mid, finish, width)

static func _dig_causeway(grid: Dictionary, great_hall: Dictionary, outpost: Dictionary, labels: Array, rng: RandomNumberGenerator) -> void:
	var start := great_hall.get("center", Vector2i.ZERO) as Vector2i
	var finish := outpost.get("center", Vector2i.ZERO) as Vector2i
	var row := start.y + rng.randi_range(-2, 2)
	_dig_wide_path(grid, start, Vector2i(start.x, row), 2)
	_dig_wide_path(grid, Vector2i(start.x, row), Vector2i(finish.x, row), 2)
	_dig_wide_path(grid, Vector2i(finish.x, row), finish, 2)

	# Gate pinches: narrow the causeway to one tile at two points.
	var inner_gate_x := start.x + (finish.x - start.x) * 2 / 5
	var city_gate_x := start.x + (finish.x - start.x) * 4 / 5
	for gate_x: int in [inner_gate_x, city_gate_x]:
		for y in range(row - 3, row + 4):
			var cell := Vector2i(gate_x, y)
			if y != row and int(grid.get(cell, CELL_ROCK)) == CELL_HALL:
				grid.erase(cell)
	labels.append({"name": "Inner Gates", "center": Vector2i(inner_gate_x, row - 3)})
	labels.append({"name": "City Gates", "center": Vector2i(city_gate_x, row - 3)})

static func _dig_wide_path(grid: Dictionary, start: Vector2i, finish: Vector2i, width: int) -> void:
	var half := maxi(0, width / 2)
	var corner := Vector2i(finish.x, start.y)
	_dig_wide_segment(grid, start, corner, half)
	_dig_wide_segment(grid, corner, finish, half)

static func _dig_wide_segment(grid: Dictionary, from_cell: Vector2i, to_cell: Vector2i, half: int) -> void:
	var lo := Vector2i(mini(from_cell.x, to_cell.x), mini(from_cell.y, to_cell.y))
	var hi := Vector2i(maxi(from_cell.x, to_cell.x), maxi(from_cell.y, to_cell.y))
	if lo.x == hi.x:
		lo.x -= half
		hi.x += half
	else:
		lo.y -= half
		hi.y += half
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var cell := Vector2i(x, y)
			if int(grid.get(cell, CELL_ROCK)) == CELL_ROCK:
				grid[cell] = CELL_HALL

## --- filling -----------------------------------------------------------

static func _fill_district(grid: Dictionary, district: Dictionary, building_type_map: Dictionary, residence_type_map: Dictionary, floor_decor: Dictionary, rng: RandomNumberGenerator) -> void:
	var kind := String(district.get("kind", ""))
	var center := district.get("center", Vector2i.ZERO) as Vector2i
	var radius := roundi(float(int(district.get("radius", 10))) * 1.35) + 2

	# The High King's Palace anchors the Great Hall of a major hold. The
	# old fixed spot straddled the plaza core (CELL_PLAZA, never CELL_HALL)
	# so the stamp could not land and no hold ever raised its palace; the
	# palace now may claim plaza floor and walks candidate spots around
	# the core rim until one fits.
	if bool(district.get("has_palace", false)):
		var palace_footprint := Vector2i(6, 4)
		var palace_spots: Array[Vector2i] = [center + Vector2i(-radius / 2, 0)]
		for _spot in range(60):
			palace_spots.append(_random_cell_in_district(center, radius, rng))
		for palace_center: Vector2i in palace_spots:
			## Keep clear of the plaza middle: the palace fronts the Great
			## Hall, it does not swallow it.
			if maxi(absi(palace_center.x - center.x), absi(palace_center.y - center.y)) < radius / 2:
				continue
			if _stamp_palace(grid, palace_center, palace_footprint, radius, center):
				_record_footprint(building_type_map, palace_center, palace_footprint, "high_kings_palace")
				break

	var recipe: Array = (DISTRICT_BUILDING_RECIPES.get(kind, []) as Array).duplicate()
	recipe = recipe.slice(0, mini(recipe.size(), int(district.get("recipe_limit", 99))))
	for _extra in range(int(district.get("extra_buildings", 0))):
		recipe.append("workshop" if kind == "anvil_quarter" else "general_goods_shop")
	for building_type_variant: Variant in recipe:
		var building_type := String(building_type_variant)
		## Civic plots run 7x5 up to 11x9 gross so the interior planner can
		## subdivide them into a shopfront plus back rooms.
		var footprint := Vector2i(rng.randi_range(3, 5), rng.randi_range(2, 4))
		if building_type == "temple":
			footprint = Vector2i(4, 3)
		if building_type == "mushroom_farm":
			footprint = Vector2i(rng.randi_range(3, 4), rng.randi_range(3, 4))
		for _attempt in 40:
			var candidate := _random_cell_in_district(center, radius, rng)
			if _stamp_structure(grid, candidate, footprint, CELL_BUILDING, radius, center):
				_record_footprint(building_type_map, candidate, footprint, building_type)
				break

	# Residences until the district's bed quota is met.
	var bed_quota := int(district.get("beds", 0))
	var beds_planned := 0
	var attempts := 0
	while beds_planned < bed_quota and attempts < bed_quota * 4 + 60:
		attempts += 1
		var residence_type := _roll_residence_type(rng)
		if kind == "anvil_quarter":
			residence_type = "barracks" if rng.randf() < 0.6 else "dormitory"
		elif kind == "noble_quarter":
			residence_type = "house"
		if bed_quota - beds_planned < 6:
			residence_type = "house"
		var residence_def := RESIDENCE_TYPES.get(residence_type, RESIDENCE_TYPES["house"]) as Dictionary
		var radius_min := residence_def.get("radius_min", Vector2i(2, 2)) as Vector2i
		var radius_max := residence_def.get("radius_max", Vector2i(3, 3)) as Vector2i
		var footprint := Vector2i(rng.randi_range(radius_min.x, radius_max.x), rng.randi_range(radius_min.y, radius_max.y))
		var candidate := _random_cell_in_district(center, radius, rng)
		if _stamp_structure(grid, candidate, footprint, CELL_HOUSE, radius, center):
			_record_footprint(residence_type_map, candidate, footprint, residence_type)
			beds_planned += _estimate_residence_beds(residence_type, footprint)

	# Densify: pack the urban quarters wall-to-wall with small homes and
	# workshops until nothing else fits, so districts read as dense city
	# blocks with narrow alleys instead of sparse caverns.
	if kind == "common_quarter" or kind == "noble_quarter" or kind == "anvil_quarter" or kind == "great_hall":
		var wants_building := kind == "anvil_quarter" or kind == "great_hall"
		# Two passes with shrinking footprints: two-room row houses first,
		# then proper small homes squeezed into the gaps. Nothing smaller
		# than a 5x5 plot (3x3 room) is ever stamped — the old 1x1/2x1
		# nooks produced unusable single-tile interiors.
		var densify_footprints: Array[Vector2i] = [Vector2i(3, 2), Vector2i(2, 2)]
		for footprint in densify_footprints:
			## The final 5x5-house pass walks every cell: with the tiny
			## nook footprints gone, a coarser scan leaves conspicuous
			## bald patches between plots.
			var scan_step := 2 if footprint.x > 2 else 1
			for scan_y in range(center.y - radius, center.y + radius + 1, scan_step):
				for scan_x in range(center.x - radius, center.x + radius + 1, scan_step):
					var candidate := Vector2i(scan_x + rng.randi_range(-1, 1), scan_y + rng.randi_range(-1, 1))
					if wants_building and rng.randf() < 0.6:
						if _stamp_structure(grid, candidate, footprint, CELL_BUILDING, radius, center):
							var densify_type := "workshop" if kind == "anvil_quarter" else "guild_hall"
							_record_footprint(building_type_map, candidate, footprint, densify_type)
					else:
						if _stamp_structure(grid, candidate, footprint, CELL_HOUSE, radius, center):
							var residence_kind := "house"
							if footprint.x >= 3 and rng.randf() < 0.4:
								residence_kind = "dormitory"
							_record_footprint(residence_type_map, candidate, footprint, residence_kind)

	# District floor flavor.
	if kind == "mushroom_farms" or kind == "mine":
		var scatter_pool: Array[String] = []
		if kind == "mushroom_farms":
			scatter_pool = ["mushroom_crops", "mushroom_crop_wild", "mushroom_wild"]
		else:
			scatter_pool = ["stone", "mushroom_wild"]
		var scatter_chance := 0.16 if kind == "mushroom_farms" else 0.05
		for y in range(center.y - radius - 4, center.y + radius + 5):
			for x in range(center.x - radius - 4, center.x + radius + 5):
				var cell := Vector2i(x, y)
				if int(grid.get(cell, CELL_ROCK)) != CELL_HALL:
					continue
				if floor_decor.has(cell):
					continue
				if rng.randf() < scatter_chance:
					floor_decor[cell] = scatter_pool[rng.randi_range(0, scatter_pool.size() - 1)]

static func _random_cell_in_district(center: Vector2i, radius: int, rng: RandomNumberGenerator) -> Vector2i:
	return center + Vector2i(rng.randi_range(-radius, radius), rng.randi_range(-radius, radius))

## Dense placement: the whole footprint must be carved district floor and
## free of other structures; the surrounding ring may be floor (so
## buildings sit one alley apart) but never another structure (so
## components never merge).
static func _stamp_structure(grid: Dictionary, center: Vector2i, footprint: Vector2i, zone: int, district_radius: int, district_center: Vector2i) -> bool:
	var lo := center - footprint
	var hi := center + footprint
	if maxi(absi(center.x - district_center.x), absi(center.y - district_center.y)) > district_radius + 2:
		return false
	for y in range(lo.y - 1, hi.y + 2):
		for x in range(lo.x - 1, hi.x + 2):
			var cell := Vector2i(x, y)
			var existing := int(grid.get(cell, CELL_ROCK))
			var inside := x >= lo.x and x <= hi.x and y >= lo.y and y <= hi.y
			if inside:
				if existing != CELL_HALL:
					return false
			else:
				if existing == CELL_HOUSE or existing == CELL_BUILDING:
					return false
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			grid[Vector2i(x, y)] = zone
	return true

## Palace stamp: unlike _stamp_structure the interior may claim plaza
## floor AND carve into raw rock (dwarves build into the mountain), so
## long as enough of the footprint touches dug floor to front the Great
## Hall. Existing houses and buildings are never overwritten.
static func _stamp_palace(grid: Dictionary, center: Vector2i, footprint: Vector2i, district_radius: int, district_center: Vector2i) -> bool:
	var lo := center - footprint
	var hi := center + footprint
	if maxi(absi(center.x - district_center.x), absi(center.y - district_center.y)) > district_radius + 2:
		return false
	var dug_cells := 0
	for y in range(lo.y - 1, hi.y + 2):
		for x in range(lo.x - 1, hi.x + 2):
			var cell := Vector2i(x, y)
			var existing := int(grid.get(cell, CELL_ROCK))
			var inside := x >= lo.x and x <= hi.x and y >= lo.y and y <= hi.y
			if existing == CELL_HOUSE or existing == CELL_BUILDING:
				return false
			if inside and (existing == CELL_HALL or existing == CELL_PLAZA):
				dug_cells += 1
	## At least a quarter of the interior must already be open floor so
	## the palace attaches to the hall rather than floating in rock.
	var interior_cells := (footprint.x * 2 + 1) * (footprint.y * 2 + 1)
	if dug_cells * 4 < interior_cells:
		return false
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			grid[Vector2i(x, y)] = CELL_BUILDING
	return true

static func _record_footprint(type_map: Dictionary, center: Vector2i, footprint: Vector2i, type_name: String) -> void:
	for y in range(center.y - footprint.y, center.y + footprint.y + 1):
		for x in range(center.x - footprint.x, center.x + footprint.x + 1):
			type_map[Vector2i(x, y)] = type_name

static func _roll_residence_type(rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	var cumulative := 0.0
	for type_name: String in RESIDENCE_TYPES.keys():
		cumulative += float((RESIDENCE_TYPES[type_name] as Dictionary).get("weight", 0.0))
		if roll <= cumulative:
			return type_name
	return "house"

static func _estimate_residence_beds(residence_type: String, footprint: Vector2i) -> int:
	match residence_type:
		"dormitory":
			return maxi(2, footprint.x * footprint.y)
		"barracks":
			return maxi(2, footprint.x * (((footprint.y * 2 - 1) / 3) + 1))
		_:
			return 1

static func _pick(options: Array[String], rng: RandomNumberGenerator, fallback: String) -> String:
	if options.is_empty():
		return fallback
	return options[rng.randi_range(0, options.size() - 1)]

static func _pick_unused(options: Array[String], used: Array[String], rng: RandomNumberGenerator, fallback: String) -> String:
	for _attempt in 12:
		var candidate := options[rng.randi_range(0, options.size() - 1)]
		if not used.has(candidate):
			used.append(candidate)
			return candidate
	return fallback
