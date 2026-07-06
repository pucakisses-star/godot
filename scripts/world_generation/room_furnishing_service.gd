extends RefCounted
class_name RoomFurnishingService

## Turns bare rooms into lived-in homes and stocked shops. Multi-tile
## furniture is cut from the web game's interior sheets (16px art, drawn
## at 2x to match the 32px scenes) and placed by template: dining sets in
## the middle of the room, pantries and cabinets against the north wall,
## rugs underfoot, candles for light, produce shelves in shops. Pieces
## anchor by their floor footprint and overhang the wall behind them,
## which is where the depth comes from.

## The 16px web sheets are pre-upscaled 2x with EPX so they render at
## the same one-world-pixel-per-art-pixel density as the 32px tilesheet
## and character art, instead of standing out twice as chunky.
const HOUSE_INTERIOR_TEXTURE := preload("res://resources/images/webgame_tiles/Farm/Tiled_files/House_interior_2x.png")
const BARN_INTERIOR_TEXTURE := preload("res://resources/images/webgame_tiles/Farm/Tiled_files/Barn_interior_2x.png")
const TAVERN_BAR_TEXTURE := preload("res://resources/images/webgame_tiles/extra/tavern_bar_2x.png")

## rect: source pixels (16px art). cells_w: floor cells wide at 2x.
## rows_block: floor rows that block movement (0 = walk-through decor).
const DF_FURNITURE_TEXTURE := preload("res://resources/images/dwarfhold/df_furniture_atlas.png")

## The rustic interior sheet: rugs, hearths, anvils, armor stands,
## stocked counters and houseplants (16px art like the house sheets).
const INTERIOR_TILESET_TEXTURE := preload("res://resources/images/dwarfhold/Interior_Tileset_2x.png")

const PIECES := {
	"round_rug": {"sheet": "house", "rect": Rect2(0, 0, 52, 52), "cells_w": 4, "rows_block": 0, "z": 4},
	"cabinet": {"sheet": "house", "rect": Rect2(48, 8, 48, 48), "cells_w": 3, "rows_block": 1, "z": 8},
	"pantry": {"sheet": "house", "rect": Rect2(144, 16, 32, 48), "cells_w": 2, "rows_block": 1, "z": 8},
	"desk": {"sheet": "house", "rect": Rect2(216, 16, 56, 48), "cells_w": 4, "rows_block": 1, "z": 8},
	"long_table": {"sheet": "house", "rect": Rect2(48, 64, 48, 32), "cells_w": 3, "rows_block": 1, "z": 8},
	"round_table": {"sheet": "house", "rect": Rect2(96, 64, 48, 48), "cells_w": 3, "rows_block": 2, "z": 8},
	"dining_set": {"sheet": "house", "rect": Rect2(144, 66, 64, 48), "cells_w": 4, "rows_block": 2, "z": 8},
	"candles": {"sheet": "house", "rect": Rect2(224, 64, 24, 48), "cells_w": 1, "rows_block": 1, "z": 8, "light": true},
	"counter_veg": {"sheet": "house", "rect": Rect2(32, 112, 48, 32), "cells_w": 3, "rows_block": 1, "z": 8},
	"bench_long": {"sheet": "house", "rect": Rect2(96, 112, 64, 32), "cells_w": 4, "rows_block": 1, "z": 8},
	"plant_palm": {"sheet": "house", "rect": Rect2(0, 96, 24, 44), "cells_w": 1, "rows_block": 1, "z": 8},
	"produce_shelf": {"sheet": "barn", "rect": Rect2(16, 24, 96, 40), "cells_w": 6, "rows_block": 1, "z": 8},
	"barrel_shelf": {"sheet": "barn", "rect": Rect2(128, 32, 64, 48), "cells_w": 4, "rows_block": 1, "z": 8},
	"crate_cluster": {"sheet": "barn", "rect": Rect2(160, 144, 64, 48), "cells_w": 4, "rows_block": 2, "z": 8},
	"crate_floor": {"sheet": "barn", "rect": Rect2(32, 240, 64, 48), "cells_w": 4, "rows_block": 0, "z": 6},
	## The tavern bar: counter with candle, mug and bottle, stool out front.
	"bar_counter": {"sheet": "bar", "rect": Rect2(0, 0, 64, 48), "cells_w": 4, "rows_block": 2, "z": 8, "light": true},
	"bar_barrel": {"sheet": "bar", "rect": Rect2(66, 0, 11, 15), "cells_w": 1, "rows_block": 1, "z": 8},
	## Rustic interior sheet: rugs underfoot...
	"int_rug_red_square": {"sheet": "interior", "rect": Rect2(469, 36, 39, 39), "cells_w": 2, "rows_block": 0, "z": 3},
	"int_rug_red_long": {"sheet": "interior", "rect": Rect2(471, 82, 35, 43), "cells_w": 2, "rows_block": 0, "z": 3},
	"int_rug_green_square": {"sheet": "interior", "rect": Rect2(469, 132, 39, 39), "cells_w": 2, "rows_block": 0, "z": 3},
	"int_rug_green_long": {"sheet": "interior", "rect": Rect2(471, 178, 35, 43), "cells_w": 2, "rows_block": 0, "z": 3},
	## ...the working fires of smithies, bakeries and taprooms...
	"int_hearth_arch": {"sheet": "interior", "rect": Rect2(321, 336, 30, 30), "cells_w": 2, "rows_block": 1, "z": 8, "light": true},
	"int_kiln_beehive": {"sheet": "interior", "rect": Rect2(355, 339, 26, 27), "cells_w": 2, "rows_block": 1, "z": 8, "light": true},
	"int_fireplace_dark": {"sheet": "interior", "rect": Rect2(386, 339, 28, 28), "cells_w": 2, "rows_block": 1, "z": 8, "light": true},
	"int_anvil": {"sheet": "interior", "rect": Rect2(304, 336, 16, 14), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_weapon_rack_axes": {"sheet": "interior", "rect": Rect2(242, 345, 27, 21), "cells_w": 2, "rows_block": 1, "z": 8},
	"int_weapon_rack_pikes": {"sheet": "interior", "rect": Rect2(275, 346, 26, 20), "cells_w": 2, "rows_block": 1, "z": 8},
	"int_armor_stand_wood": {"sheet": "interior", "rect": Rect2(242, 306, 12, 14), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_armor_stand_silver": {"sheet": "interior", "rect": Rect2(242, 321, 12, 15), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_armor_stand_dark": {"sheet": "interior", "rect": Rect2(257, 306, 14, 14), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_armor_stand_plate": {"sheet": "interior", "rect": Rect2(257, 321, 14, 15), "cells_w": 1, "rows_block": 1, "z": 8},
	## ...stocked kitchen counters and tavern fare...
	"int_counter_crockery": {"sheet": "interior", "rect": Rect2(273, 315, 30, 19), "cells_w": 2, "rows_block": 1, "z": 8},
	"int_counter_linens": {"sheet": "interior", "rect": Rect2(305, 315, 30, 19), "cells_w": 2, "rows_block": 1, "z": 8},
	"int_counter_jugs": {"sheet": "interior", "rect": Rect2(337, 314, 30, 20), "cells_w": 2, "rows_block": 1, "z": 8},
	"int_roast_bird": {"sheet": "interior", "rect": Rect2(304, 355, 16, 11), "cells_w": 1, "rows_block": 1, "z": 8},
	## ...cabinets, shelves and seats...
	"int_dresser_drawers": {"sheet": "interior", "rect": Rect2(385, 279, 14, 19), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_cupboard_doors": {"sheet": "interior", "rect": Rect2(400, 276, 16, 22), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_shelf_flowerpot": {"sheet": "interior", "rect": Rect2(417, 276, 14, 20), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_shelf_small": {"sheet": "interior", "rect": Rect2(433, 281, 14, 15), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_bookshelf_red": {"sheet": "interior", "rect": Rect2(449, 276, 14, 20), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_bookshelf_wide": {"sheet": "interior", "rect": Rect2(466, 276, 28, 20), "cells_w": 2, "rows_block": 1, "z": 8},
	"int_cabinet_tall": {"sheet": "interior", "rect": Rect2(497, 276, 14, 20), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_stool_cushion": {"sheet": "interior", "rect": Rect2(306, 284, 12, 14), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_chair_cushion": {"sheet": "interior", "rect": Rect2(322, 282, 12, 16), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_chair_cushion_red": {"sheet": "interior", "rect": Rect2(338, 282, 12, 16), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_candle_stand": {"sheet": "interior", "rect": Rect2(354, 280, 12, 18), "cells_w": 1, "rows_block": 1, "z": 8, "light": true},
	"int_stool_low": {"sheet": "interior", "rect": Rect2(370, 283, 12, 15), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_bench_rough": {"sheet": "interior", "rect": Rect2(7, 171, 34, 13), "cells_w": 2, "rows_block": 1, "z": 8},
	"int_stump_table": {"sheet": "interior", "rect": Rect2(0, 208, 16, 16), "cells_w": 1, "rows_block": 1, "z": 8},
	## ...and greenery to soften the stone.
	"int_urn_basket": {"sheet": "interior", "rect": Rect2(384, 313, 16, 21), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_plant_potted": {"sheet": "interior", "rect": Rect2(402, 313, 12, 21), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_plant_tree": {"sheet": "interior", "rect": Rect2(416, 310, 15, 24), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_pot_clay": {"sheet": "interior", "rect": Rect2(370, 321, 12, 13), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_pot_crate": {"sheet": "interior", "rect": Rect2(434, 321, 12, 13), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_table_flower_blue": {"sheet": "interior", "rect": Rect2(450, 317, 12, 17), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_table_flower_white": {"sheet": "interior", "rect": Rect2(466, 317, 12, 17), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_table_flower_pot": {"sheet": "interior", "rect": Rect2(482, 319, 12, 15), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_table_plant_fern": {"sheet": "interior", "rect": Rect2(497, 317, 15, 17), "cells_w": 1, "rows_block": 1, "z": 8}
}

## Building types whose interiors read as stocked shops.
const SHOP_DRESSING_TYPES := [
	"market_stall", "general_store", "warehouse", "bakery", "tavern", "brewery"
]

## Trades share a dressing theme: the same hearth-and-anvil kit fits a
## forge, a smeltery or a weapon shop; books and long rugs fit a temple
## as well as a counting house. Types not listed here (and not shops)
## keep their bare tile decor.
const DRESSING_THEME_BY_TYPE := {
	"forge": "smithy", "smeltery": "smithy", "engineers_foundry": "smithy",
	"armory": "smithy", "weapon_shop": "smithy", "armor_shop": "smithy", "smithy": "smithy",
	"bakery": "kitchen", "kitchen": "kitchen", "granary": "kitchen",
	"butchery": "kitchen", "millhouse": "kitchen",
	"temple": "stately", "chapel": "stately", "high_kings_palace": "stately",
	"guild_hall": "stately", "archives": "stately", "enchanting_study": "stately",
	"runesmith_sanctum": "stately", "town_hall": "stately", "bank_vaults": "stately",
	"auction_house": "stately", "merchants_counting_house": "stately",
	"cartographers_office": "stately", "explorers_guild": "stately",
	"barracks": "guard", "guardhouse": "guard",
	"infirmary": "herbal", "apothecary": "herbal", "alchemy_laboratory": "herbal",
	"mushroom_farm": "herbal",
	"tavern": "hearthside", "inn": "hearthside", "brewery": "hearthside",
	"workshop": "craft", "engineering_workshop": "craft", "leatherworking_shop": "craft",
	"tailoring_shop": "craft", "carpenter": "craft", "tailor": "craft",
	"cooperage": "craft", "tannery": "craft", "cobblers_shop": "craft",
	"ropemakers_hall": "craft", "mason_lodge": "craft", "gemcutters_studio": "craft",
	"miners_guild": "craft", "storage_warehouse": "stockroom"
}

## Flood-fills the grid into connected components of one zone value,
## walls included (the zone's edge cells render as walls).
static func collect_zone_components(grid: Dictionary, zone: int) -> Array:
	var visited: Dictionary = {}
	var components: Array = []
	for key: Variant in grid.keys():
		var start := key as Vector2i
		if int(grid.get(start, -1)) != zone or visited.has(start):
			continue
		var queue: Array[Vector2i] = [start]
		var component: Array[Vector2i] = []
		visited[start] = true
		var head := 0
		while head < queue.size():
			var current := queue[head]
			head += 1
			component.append(current)
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor := current + direction
				if visited.has(neighbor) or int(grid.get(neighbor, -1)) != zone:
					continue
				visited[neighbor] = true
				queue.append(neighbor)
		components.append(component)
	return components

## Interior cells are the ones fully inside the room (every neighbor is
## part of the same component), i.e. not the wall ring.
static func interior_cells(component: Array[Vector2i]) -> Array[Vector2i]:
	var member: Dictionary = {}
	for cell: Vector2i in component:
		member[cell] = true
	var interior: Array[Vector2i] = []
	for cell: Vector2i in component:
		var inside := true
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not member.has(cell + direction):
				inside = false
				break
		if inside:
			interior.append(cell)
	return interior

static func _bbox(cells: Array[Vector2i]) -> Rect2i:
	var min_x := cells[0].x
	var min_y := cells[0].y
	var max_x := cells[0].x
	var max_y := cells[0].y
	for cell: Vector2i in cells:
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_x = maxi(max_x, cell.x)
		max_y = maxi(max_y, cell.y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

static func footprint_cells(piece_name: String, base_cell: Vector2i) -> Array[Vector2i]:
	var piece := piece_def(piece_name)
	var cells: Array[Vector2i] = []
	for row in range(maxi(int(piece.get("rows_block", 1)), 1)):
		for column in range(int(piece.get("cells_w", 1))):
			cells.append(base_cell + Vector2i(column, row))
	return cells

## Can the piece sit here? Every footprint cell must be interior floor,
## free of furniture, and not up against a doorway.
static func _fits(piece_name: String, base_cell: Vector2i, interior_set: Dictionary, is_occupied: Callable, door_cells: Dictionary) -> bool:
	for cell: Vector2i in footprint_cells(piece_name, base_cell):
		if not interior_set.has(cell):
			return false
		if bool(is_occupied.call(cell)):
			return false
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.ZERO]:
			if door_cells.has(cell + direction):
				return false
	return true

## The prime rule of furnishing: never wall anything off. After adding
## the piece, every free cell in the room must stay connected to the
## doorway, and every existing furnishing (beds, chests) must keep a
## reachable free neighbor to be used from.
static func _keeps_room_open(piece_name: String, base_cell: Vector2i, interior: Array[Vector2i], is_occupied: Callable, door_cells: Dictionary) -> bool:
	var piece := PIECES.get(piece_name, {}) as Dictionary
	if int(piece.get("rows_block", 1)) <= 0:
		return true
	return block_keeps_room_open(footprint_cells(piece_name, base_cell), interior, is_occupied, door_cells)

## A placement is acceptable when it creates no NEW problems: free floor
## that was connected to the door stays connected, and furniture that had
## a reachable neighbor keeps one. (Some legacy layouts pack bunks so
## tight they already violate this; measuring against the baseline lets
## us furnish the healthy rooms without punishing the crowded ones.)
static func block_keeps_room_open(new_blocked: Array[Vector2i], interior: Array[Vector2i], is_occupied: Callable, door_cells: Dictionary) -> bool:
	var baseline := _room_openness([], interior, is_occupied, door_cells)
	var with_block := _room_openness(new_blocked, interior, is_occupied, door_cells)
	if int(with_block.get("free", 0)) <= 0:
		return false
	return int(with_block.get("unreached_free", 0)) <= int(baseline.get("unreached_free", 0)) \
		and int(with_block.get("unusable_furniture", 0)) <= int(baseline.get("unusable_furniture", 0))

static func _room_openness(new_blocked: Array[Vector2i], interior: Array[Vector2i], is_occupied: Callable, door_cells: Dictionary) -> Dictionary:
	var footprint: Dictionary = {}
	for cell: Vector2i in new_blocked:
		footprint[cell] = true
	var free: Dictionary = {}
	var existing_furniture: Array[Vector2i] = []
	var starts: Array[Vector2i] = []
	for cell: Vector2i in interior:
		if footprint.has(cell):
			continue
		if bool(is_occupied.call(cell)):
			existing_furniture.append(cell)
			continue
		free[cell] = true
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if door_cells.has(cell + direction):
				starts.append(cell)
	if free.is_empty():
		return {"free": 0, "unreached_free": 0, "unusable_furniture": existing_furniture.size()}
	if starts.is_empty():
		starts.append(free.keys()[0] as Vector2i)
	var reached: Dictionary = {}
	var frontier: Array[Vector2i] = []
	for start: Vector2i in starts:
		if not reached.has(start):
			reached[start] = true
			frontier.append(start)
	var head := 0
	while head < frontier.size():
		var current: Vector2i = frontier[head]
		head += 1
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next_cell: Vector2i = current + direction
			if free.has(next_cell) and not reached.has(next_cell):
				reached[next_cell] = true
				frontier.append(next_cell)
	var unusable := 0
	for cell: Vector2i in existing_furniture:
		var usable := false
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if reached.has(cell + direction):
				usable = true
				break
		if not usable:
			unusable += 1
	return {
		"free": free.size(),
		"unreached_free": free.size() - reached.size(),
		"unusable_furniture": unusable
	}

## Furnishing plan for one house: a list of {"piece", "cell"} placements.
## Bigger rooms earn bigger furniture; the wall ring and door approaches
## stay clear so residents can still reach their beds.
static func plan_house_furnishing(component: Array[Vector2i], is_occupied: Callable, door_cells: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	var interior := interior_cells(component)
	if interior.size() < 4:
		return placements
	var interior_set: Dictionary = {}
	for cell: Vector2i in interior:
		interior_set[cell] = true
	var box := _bbox(interior)

	var claimed: Dictionary = {}
	var occupied_or_claimed := func(cell: Vector2i) -> bool:
		return claimed.has(cell) or bool(is_occupied.call(cell))

	var try_place := func(piece_name: String, base_cell: Vector2i) -> bool:
		if not _fits(piece_name, base_cell, interior_set, occupied_or_claimed, door_cells):
			return false
		if not _keeps_room_open(piece_name, base_cell, interior, occupied_or_claimed, door_cells):
			return false
		placements.append({"piece": piece_name, "cell": base_cell})
		for cell: Vector2i in footprint_cells(piece_name, base_cell):
			claimed[cell] = true
		return true

	# Small homes still get a warm corner: candles and a plant.
	if interior.size() < 6:
		for cell: Vector2i in interior:
			if try_place.call("candles", cell):
				break
		for cell: Vector2i in interior:
			if try_place.call("plant_palm", cell):
				break
		var small_pool: Array[String] = ["df_box_1_0", "df_box_2_0", "df_tool_20_0", "df_tool_11_0", "df_toy_0_0", "df_chair_0_0", "df_food_0_0", "int_stool_cushion", "int_pot_clay", "int_stump_table", "int_table_flower_pot"]
		var small_count := rng.randi_range(1, 2)
		for _small in range(small_count * 5):
			if small_count <= 0:
				break
			if try_place.call(small_pool[rng.randi_range(0, small_pool.size() - 1)], interior[rng.randi_range(0, interior.size() - 1)]):
				small_count -= 1
		return placements

	# The dining set holds the middle of any room wide enough for it,
	# with a rug beneath and candles beside.
	if box.size.x >= 5 and box.size.y >= 4:
		var set_cell := Vector2i(box.position.x + (box.size.x - 4) / 2, box.position.y + (box.size.y - 2) / 2)
		if try_place.call("dining_set", set_cell):
			var rug_pool: Array[String] = ["round_rug", "int_rug_red_square", "int_rug_green_square", "int_rug_red_long"]
			placements.insert(0, {"piece": rug_pool[rng.randi_range(0, rug_pool.size() - 1)], "cell": set_cell + Vector2i(0, -1)})
			for candle_offset: Vector2i in [Vector2i(-1, 0), Vector2i(4, 0), Vector2i(-1, 1), Vector2i(4, 1)]:
				if try_place.call("candles", set_cell + candle_offset):
					break
	elif box.size.x >= 3 and box.size.y >= 3:
		var table_cell := Vector2i(box.position.x + (box.size.x - 3) / 2, box.position.y + (box.size.y - 2) / 2)
		if not try_place.call("round_table", table_cell):
			try_place.call("long_table", table_cell)

	# North wall: pantry and cabinet lean against it, tops overhanging.
	var north_row := box.position.y
	var north_candidates: Array[Vector2i] = []
	for x in range(box.position.x, box.end.x):
		north_candidates.append(Vector2i(x, north_row))
	if not north_candidates.is_empty():
		var start_index := rng.randi_range(0, north_candidates.size() - 1)
		for offset in range(north_candidates.size()):
			if try_place.call("pantry", north_candidates[(start_index + offset) % north_candidates.size()]):
				break
		if box.size.x >= 5:
			for offset in range(north_candidates.size()):
				if try_place.call("cabinet", north_candidates[(start_index + offset * 3) % north_candidates.size()]):
					break

	# A hearth fire warms the bigger homes from the north wall.
	if interior.size() >= 14:
		for x in range(box.position.x, box.end.x - 1):
			if try_place.call("int_fireplace_dark" if rng.randf() < 0.6 else "int_hearth_arch", Vector2i(x, box.position.y)):
				break

	# A kitchen counter for the bigger homes, greenery for everyone.
	if box.size.x >= 6 and rng.randf() < 0.7:
		try_place.call("counter_veg", Vector2i(box.position.x, box.end.y - 1))
	var corners: Array[Vector2i] = [
		box.position, Vector2i(box.end.x - 1, box.position.y),
		Vector2i(box.position.x, box.end.y - 1), Vector2i(box.end.x - 1, box.end.y - 1)
	]
	for corner: Vector2i in corners:
		if rng.randf() < 0.5 and try_place.call("plant_palm", corner):
			break

	# DF clutter: every home owns things - a chest at the foot of the
	# bed, a cabinet, books, a jug, a child's toy...
	var clutter_pool: Array[String] = [
		"df_box_1_0", "df_box_1_1", "df_box_2_0", "df_box_2_1", "df_box_3_0", "df_box_3_1",
		"df_cabinet_0_0", "df_cabinet_1_0", "df_cabinet_2_0", "df_cabinet_3_0",
		"df_bookcase_0_0", "df_bookcase_1_0",
		"df_tool_20_0", "df_tool_20_1", "df_tool_20_2", "df_tool_20_3",
		"df_tool_11_0", "df_tool_11_1", "df_tool_11_2",
		"df_tool_12_0", "df_tool_12_1",
		"df_toy_0_0", "df_toy_0_1", "df_toy_1_0", "df_toy_1_1",
		"df_chair_0_0", "df_chair_1_0", "df_chair_2_0",
		"df_food_0_0", "df_food_1_0", "df_food_2_0",
		"int_stool_cushion", "int_chair_cushion", "int_chair_cushion_red", "int_candle_stand",
		"int_dresser_drawers", "int_cupboard_doors", "int_shelf_flowerpot", "int_shelf_small",
		"int_bookshelf_red", "int_plant_potted", "int_plant_tree", "int_pot_clay",
		"int_table_flower_blue", "int_table_flower_white", "int_table_plant_fern",
		"int_stump_table", "int_urn_basket"
	]
	var clutter_count := rng.randi_range(3, mini(7, 3 + interior.size() / 6))
	var edge_cells: Array[Vector2i] = []
	for cell: Vector2i in interior:
		if cell.y == box.position.y or cell.x == box.position.x or cell.x == box.end.x - 1 or cell.y == box.end.y - 1:
			edge_cells.append(cell)
	for _clutter in range(clutter_count * 6):
		if clutter_count <= 0:
			break
		var piece: String = clutter_pool[rng.randi_range(0, clutter_pool.size() - 1)]
		var candidate: Vector2i
		if not edge_cells.is_empty() and rng.randf() < 0.7:
			candidate = edge_cells[rng.randi_range(0, edge_cells.size() - 1)]
		else:
			candidate = interior[rng.randi_range(0, interior.size() - 1)]
		if try_place.call(piece, candidate):
			clutter_count -= 1
	return placements

## Dressing for shopfront interiors: stocked shelves along the north
## wall, crates of goods in the corners, loose produce by the counter.
static func plan_shop_dressing(component: Array[Vector2i], building_type: String, is_occupied: Callable, door_cells: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	if not SHOP_DRESSING_TYPES.has(building_type) and not DRESSING_THEME_BY_TYPE.has(building_type):
		return placements
	var interior := interior_cells(component)
	if interior.size() < 6:
		return placements
	var interior_set: Dictionary = {}
	for cell: Vector2i in interior:
		interior_set[cell] = true
	var box := _bbox(interior)

	var claimed: Dictionary = {}
	var occupied_or_claimed := func(cell: Vector2i) -> bool:
		return claimed.has(cell) or bool(is_occupied.call(cell))
	var try_place := func(piece_name: String, base_cell: Vector2i) -> bool:
		if not _fits(piece_name, base_cell, interior_set, occupied_or_claimed, door_cells):
			return false
		if not _keeps_room_open(piece_name, base_cell, interior, occupied_or_claimed, door_cells):
			return false
		placements.append({"piece": piece_name, "cell": base_cell})
		for cell: Vector2i in footprint_cells(piece_name, base_cell):
			claimed[cell] = true
		return true

	# Trade-theme dressing goes first so the signature pieces claim the
	# room's prime spots: the forge fire on the north wall, the temple
	# rug in the center, racks and stands along the edges.
	var theme := String(DRESSING_THEME_BY_TYPE.get(building_type, ""))
	var center_top := Vector2i(
		box.position.x + maxi((box.size.x - 2) / 2, 0),
		box.position.y + maxi((box.size.y - 2) / 2, 0)
	)
	match theme:
		"smithy":
			for x in range(box.position.x, box.end.x - 1):
				if try_place.call("int_hearth_arch", Vector2i(x, box.position.y)):
					break
			try_place.call("int_anvil", center_top)
			for x in range(box.end.x - 2, box.position.x - 1, -1):
				if try_place.call("int_weapon_rack_axes" if rng.randf() < 0.5 else "int_weapon_rack_pikes", Vector2i(x, box.position.y)):
					break
			var stand_pool: Array[String] = ["int_armor_stand_wood", "int_armor_stand_silver", "int_armor_stand_dark", "int_armor_stand_plate"]
			var stand_corners: Array[Vector2i] = [
				Vector2i(box.position.x, box.end.y - 1), Vector2i(box.end.x - 1, box.end.y - 1),
				Vector2i(box.position.x, box.position.y), Vector2i(box.end.x - 1, box.position.y)
			]
			for corner: Vector2i in stand_corners:
				if try_place.call(stand_pool[rng.randi_range(0, stand_pool.size() - 1)], corner) and rng.randf() < 0.4:
					break
		"kitchen":
			for x in range(box.position.x, box.end.x - 1):
				if try_place.call("int_kiln_beehive", Vector2i(x, box.position.y)):
					break
			var counter_run: Array[String] = ["int_counter_crockery", "int_counter_linens", "int_counter_jugs"]
			for step in range(rng.randi_range(2, 3)):
				try_place.call(counter_run[rng.randi_range(0, counter_run.size() - 1)], Vector2i(box.position.x + step * 2, box.end.y - 1))
			try_place.call("int_roast_bird", center_top + Vector2i(1, 0))
		"stately":
			placements.append({"piece": "int_rug_red_long" if rng.randf() < 0.5 else "int_rug_green_long", "cell": center_top})
			for candle_offset: Vector2i in [Vector2i(-1, 0), Vector2i(2, 0)]:
				try_place.call("int_candle_stand", center_top + candle_offset)
			var book_run: Array[String] = ["int_bookshelf_wide", "int_bookshelf_red", "int_cabinet_tall"]
			var books_placed := 0
			for x in range(box.position.x, box.end.x):
				if try_place.call(book_run[rng.randi_range(0, book_run.size() - 1)], Vector2i(x, box.position.y)):
					books_placed += 1
					if books_placed >= 3:
						break
			try_place.call("int_plant_tree", Vector2i(box.end.x - 1, box.end.y - 1))
		"guard":
			# The rug goes first in the list: with furniture stacked by
			# placement order, first placed means drawn underneath.
			placements.insert(0, {"piece": "int_rug_green_square", "cell": center_top})
			for x in range(box.position.x, box.end.x - 1):
				if try_place.call("int_weapon_rack_pikes", Vector2i(x, box.position.y)):
					break
			var stands: Array[String] = ["int_armor_stand_silver", "int_armor_stand_plate", "int_armor_stand_dark", "int_armor_stand_wood"]
			var stand_count := rng.randi_range(2, 3)
			for _stand in range(stand_count * 4):
				if stand_count <= 0:
					break
				if try_place.call(stands[rng.randi_range(0, stands.size() - 1)], interior[rng.randi_range(0, interior.size() - 1)]):
					stand_count -= 1
		"herbal":
			var green_pool: Array[String] = ["int_plant_potted", "int_plant_tree", "int_urn_basket", "int_table_flower_blue", "int_table_flower_white", "int_table_plant_fern", "int_shelf_flowerpot"]
			var green_count := rng.randi_range(3, 5)
			for _green in range(green_count * 4):
				if green_count <= 0:
					break
				if try_place.call(green_pool[rng.randi_range(0, green_pool.size() - 1)], interior[rng.randi_range(0, interior.size() - 1)]):
					green_count -= 1
			for x in range(box.position.x, box.end.x):
				if try_place.call("int_shelf_small", Vector2i(x, box.position.y)):
					break
		"hearthside":
			for x in range(box.position.x, box.end.x - 1):
				if try_place.call("int_fireplace_dark", Vector2i(x, box.position.y)):
					break
			placements.append({"piece": "int_rug_red_square", "cell": center_top})
			try_place.call("int_roast_bird", center_top + Vector2i(-1, 1))
		"craft":
			for x in range(box.position.x, box.end.x - 1):
				if try_place.call("int_bench_rough", Vector2i(x, box.position.y)):
					break
			try_place.call("int_urn_basket", Vector2i(box.end.x - 1, box.end.y - 1))
			try_place.call("int_stool_low", center_top + Vector2i(-1, 1))
		"stockroom":
			var stock_pool: Array[String] = ["int_pot_crate", "int_urn_basket", "int_pot_clay", "int_counter_jugs"]
			var stock_count := rng.randi_range(3, 5)
			for _stock in range(stock_count * 4):
				if stock_count <= 0:
					break
				if try_place.call(stock_pool[rng.randi_range(0, stock_pool.size() - 1)], interior[rng.randi_range(0, interior.size() - 1)]):
					stock_count -= 1

	# Shopfront staples stay exclusive to the storefront types.
	if SHOP_DRESSING_TYPES.has(building_type):
		# Taverns get the bar itself, front and center, with spare kegs.
		if building_type == "tavern" and box.size.x >= 5 and box.size.y >= 3:
			# Prefer the north wall, but a busy taproom takes any row with
			# space for the counter.
			var bar_done := false
			for y in range(box.position.y, box.end.y - 1):
				if try_place.call("bar_counter", Vector2i(box.position.x + (box.size.x - 4) / 2, y)):
					bar_done = true
					break
				for x in range(box.position.x, box.end.x - 3):
					if try_place.call("bar_counter", Vector2i(x, y)):
						bar_done = true
						break
				if bar_done:
					break
			try_place.call("bar_barrel", Vector2i(box.end.x - 1, box.end.y - 1))
			try_place.call("bar_barrel", Vector2i(box.position.x, box.end.y - 1))
		for x in range(box.position.x, box.end.x):
			if box.size.x >= 7 and try_place.call("produce_shelf", Vector2i(x, box.position.y)):
				break
			if box.size.x < 7 and try_place.call("barrel_shelf", Vector2i(x, box.position.y)):
				break
		try_place.call("crate_cluster", Vector2i(box.end.x - 4, box.end.y - 2))
		if rng.randf() < 0.7:
			try_place.call("crate_floor", Vector2i(box.position.x, box.end.y - 1))

		# Reference look: continuous stocked shelf runs along the walls.
		var shelf_run: Array[String] = ["df_tool_23_0", "df_tool_23_1", "df_tool_23_2", "df_tool_23_3", "df_bookcase_2_0", "df_cabinet_1_0"]
		var run_length := rng.randi_range(2, 4)
		var run_start := Vector2i(box.position.x + 1, box.position.y)
		for step in range(run_length):
			try_place.call(shelf_run[rng.randi_range(0, shelf_run.size() - 1)], run_start + Vector2i(step, 0))

	# The tools of the trade, scattered where they were last used.
	var trade_pools := {
		"tavern": ["df_tool_11_0", "df_tool_11_1", "df_tool_11_2", "df_tool_12_0", "df_tool_12_1", "df_tool_0_0", "df_food_0_0", "df_food_1_0", "df_food_2_0", "df_tool_21_0", "df_chair_0_0", "int_stool_cushion", "int_chair_cushion_red", "int_bench_rough"],
		"brewery": ["df_tool_11_0", "df_tool_11_1", "df_tool_12_0", "df_tool_12_1", "df_tool_12_2", "df_tool_27_0", "df_tool_27_1", "df_tool_18_0"],
		"bakery": ["df_tool_21_0", "df_tool_21_1", "df_tool_14_0", "df_food_0_0", "df_food_1_0", "df_tool_12_0"],
		"warehouse": ["df_box_0_0", "df_box_0_1", "df_tool_16_0", "df_tool_16_1", "df_tool_17_0", "df_tool_17_1", "df_tool_18_0", "df_tool_18_1", "df_tool_10_0", "df_tool_10_1"],
		"general_store": ["df_box_1_0", "df_box_2_0", "df_tool_20_0", "df_tool_11_0", "df_toy_0_0", "df_toy_1_0", "df_food_0_0"],
		"market_stall": ["df_box_0_0", "df_food_0_0", "df_food_1_0", "df_tool_11_1", "df_toy_0_1"]
	}
	var trade_pool: Array = trade_pools.get(building_type, ["df_tool_26_0", "df_tool_26_1", "df_tool_26_2", "df_tool_25_0", "df_tool_23_0", "df_tool_23_1", "df_tool_27_0", "df_toy_2_0", "df_toy_2_1"]) as Array
	var trade_count := rng.randi_range(2, 4)
	var open_cells: Array[Vector2i] = interior.duplicate()
	for _piece in range(trade_count * 4):
		if trade_count <= 0 or open_cells.is_empty():
			break
		var piece := String(trade_pool[rng.randi_range(0, trade_pool.size() - 1)])
		if try_place.call(piece, open_cells[rng.randi_range(0, open_cells.size() - 1)]):
			trade_count -= 1
	return placements

## Builds the sprite for a placement, anchored so its base sits on the
## footprint's floor rows and the rest overhangs the wall behind it.
## DF furniture pieces (df_*) come from the packed atlas: single-cell
## sprites resolved through DfFurnitureDefs rather than the PIECES map.
static func piece_def(piece_name: String) -> Dictionary:
	if piece_name.begins_with("df_"):
		if not DfFurnitureDefs.FURNITURE_ATLAS.has(piece_name):
			return {}
		return {"cells_w": 1, "rows_block": 1, "z": 8}
	return PIECES.get(piece_name, {}) as Dictionary

static func create_piece_sprite(piece_name: String, base_cell: Vector2i, tile_size: Vector2i) -> Sprite2D:
	if piece_name.begins_with("df_"):
		var coords_variant: Variant = DfFurnitureDefs.FURNITURE_ATLAS.get(piece_name)
		if coords_variant == null:
			return null
		var coords := coords_variant as Vector2i
		var df_sprite := Sprite2D.new()
		df_sprite.texture = DF_FURNITURE_TEXTURE
		df_sprite.region_enabled = true
		df_sprite.centered = false
		df_sprite.region_rect = Rect2(coords.x * 32, coords.y * 32, 32, 32)
		df_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		df_sprite.scale = Vector2(float(tile_size.x) / 32.0, float(tile_size.y) / 32.0)
		df_sprite.position = Vector2(base_cell * tile_size)
		# Furniture is scenery, treated as tiles: it lives on the decor
		# layer at z 0 so walkers and their speech draw over it. Stacking
		# among pieces (rug under table) comes from placement order.
		df_sprite.z_index = 0
		return df_sprite
	var piece := PIECES.get(piece_name, {}) as Dictionary
	if piece.is_empty():
		return null
	var sprite := Sprite2D.new()
	match String(piece.get("sheet", "house")):
		"barn":
			sprite.texture = BARN_INTERIOR_TEXTURE
		"bar":
			sprite.texture = TAVERN_BAR_TEXTURE
		"interior":
			sprite.texture = INTERIOR_TILESET_TEXTURE
		_:
			sprite.texture = HOUSE_INTERIOR_TEXTURE
	sprite.region_enabled = true
	sprite.centered = false
	var source_rect := piece.get("rect", Rect2()) as Rect2
	# rects are authored against the 16px originals; the sheets on disk
	# are their 2x EPX upscales.
	var rect := Rect2(source_rect.position * 2.0, source_rect.size * 2.0)
	sprite.region_rect = rect
	var scale := float(tile_size.x) / 32.0
	sprite.scale = Vector2.ONE * scale
	var rows_block := maxi(int(piece.get("rows_block", 1)), 1)
	var base_bottom := float((base_cell.y + rows_block) * tile_size.y)
	sprite.position = Vector2(float(base_cell.x * tile_size.x), base_bottom - rect.size.y * scale)
	# Treated as tiles: z 0 on the decor layer, under every walker.
	sprite.z_index = 0
	return sprite

static func piece_emits_light(piece_name: String) -> bool:
	return bool(piece_def(piece_name).get("light", false))

## A warm additive light pool for hearths and candle stands.
static func create_glow_sprite(world_position: Vector2, radius: float, color: Color) -> Sprite2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color.r, color.g, color.b, 0.55))
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 96
	texture.height = 96
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.position = world_position
	sprite.scale = Vector2.ONE * (radius / 48.0)
	sprite.z_index = 14
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = material
	return sprite
