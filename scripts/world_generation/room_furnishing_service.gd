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

## Purpose-painted grand-hall pieces the reference interiors demanded:
## the throne, the purple candelabra, the grandfather clock, the bathtub
## and the iron stove (2x sheet like the others).
const EXTRA_FURNITURE_TEXTURE := preload("res://resources/images/dwarfhold/extra_furniture_2x.png")

## Interior partition wall (matches SettlementSceneBase.CELL_WALL): floor
## cells beside a partition still count as interior, so rooms carved out
## of a larger building keep a furnishable floor.
const CELL_WALL := 6

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
	## ...grooming stations for the barber's parlor: a wash basin with jug
	## and brush, a lather bowl on a razor strop, a shears-and-kettle
	## counter, and a high-backed client chair drawn from behind so it
	## reads as facing the station it is pulled up to...
	"int_groom_basin": {"sheet": "interior", "rect": Rect2(240, 233, 16, 23), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_groom_lather": {"sheet": "interior", "rect": Rect2(256, 233, 16, 23), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_groom_shears": {"sheet": "interior", "rect": Rect2(288, 233, 16, 23), "cells_w": 1, "rows_block": 1, "z": 8},
	"barber_chair": {"sheet": "house", "rect": Rect2(210, 8, 12, 21), "cells_w": 1, "rows_block": 1, "z": 8},
	## ...and greenery to soften the stone.
	"int_urn_basket": {"sheet": "interior", "rect": Rect2(384, 313, 16, 21), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_plant_potted": {"sheet": "interior", "rect": Rect2(402, 313, 12, 21), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_plant_tree": {"sheet": "interior", "rect": Rect2(416, 310, 15, 24), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_pot_clay": {"sheet": "interior", "rect": Rect2(370, 321, 12, 13), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_pot_crate": {"sheet": "interior", "rect": Rect2(434, 321, 12, 13), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_table_flower_blue": {"sheet": "interior", "rect": Rect2(450, 317, 12, 17), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_table_flower_white": {"sheet": "interior", "rect": Rect2(466, 317, 12, 17), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_table_flower_pot": {"sheet": "interior", "rect": Rect2(482, 319, 12, 15), "cells_w": 1, "rows_block": 1, "z": 8},
	"int_table_plant_fern": {"sheet": "interior", "rect": Rect2(497, 317, 15, 17), "cells_w": 1, "rows_block": 1, "z": 8},
	## The grand-hall kit: seat of honor, ceremonial light, the ticking
	## heirloom, and the comforts of a proper dwarven home.
	"throne_red": {"sheet": "extra", "rect": Rect2(0, 0, 14, 22), "cells_w": 1, "rows_block": 1, "z": 8},
	"candelabra_purple": {"sheet": "extra", "rect": Rect2(16, 0, 14, 24), "cells_w": 1, "rows_block": 1, "z": 8, "light": true},
	"grandfather_clock": {"sheet": "extra", "rect": Rect2(32, 0, 13, 26), "cells_w": 1, "rows_block": 1, "z": 8},
	"bathtub_white": {"sheet": "extra", "rect": Rect2(48, 0, 26, 17), "cells_w": 2, "rows_block": 1, "z": 8},
	"stove_iron": {"sheet": "extra", "rect": Rect2(48, 18, 26, 15), "cells_w": 2, "rows_block": 1, "z": 8, "light": true}
}

## Building types whose interiors read as stocked shops. The dwarfhold's
## goods-and-supply storefronts earn the same stocked-shelf staples as
## the town shops.
const SHOP_DRESSING_TYPES := [
	"market_stall", "general_store", "warehouse", "bakery", "tavern", "brewery",
	"general_goods_shop", "trade_supply_store"
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
	"miners_guild": "craft", "storage_warehouse": "stockroom",
	## Every remaining civic type from both catalogs resolves to a theme so
	## no shop interior is left as bare planks: the barber gets its own
	## grooming kit, and the goods-and-storage trades share the stockroom.
	"barber_shop": "grooming",
	"general_goods_shop": "stockroom", "trade_supply_store": "stockroom",
	"general_store": "stockroom", "market_stall": "stockroom",
	"warehouse": "stockroom", "stable": "stockroom",
	## Town back-of-house room roles (dealt by the interior planner): the
	## storeroom behind a shopfront and the forge room behind a smithy.
	"storeroom": "stockroom", "forge_room": "smithy"
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
## part of the same component), i.e. not the wall ring. When the caller
## passes the grid, a CELL_WALL neighbor also counts as "inside": floor
## against an interior partition renders as floor, so it is furnishable.
static func interior_cells(component: Array[Vector2i], grid: Dictionary = {}) -> Array[Vector2i]:
	var member: Dictionary = {}
	for cell: Vector2i in component:
		member[cell] = true
	var interior: Array[Vector2i] = []
	for cell: Vector2i in component:
		var inside := true
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + direction
			if member.has(neighbor):
				continue
			if int(grid.get(neighbor, 0)) == CELL_WALL:
				continue
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
static func plan_house_furnishing(component: Array[Vector2i], is_occupied: Callable, door_cells: Dictionary, rng: RandomNumberGenerator, grid: Dictionary = {}) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	var interior := interior_cells(component, grid)
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

	# --- Themed room ------------------------------------------------------
	# Each house (one zone component) is dressed as a single themed room so
	# a settlement reads as a mix of bedrooms, kitchens, studies, living
	# rooms and washrooms rather than the same scatter everywhere. The theme
	# is chosen from the room's map position, so it is stable per seed and
	# spread across the town. Every house already owns a bed tile, which the
	# occupancy check keeps furniture off of.
	var theme_pool: Array[String] = ["bedroom", "living", "kitchen", "study", "bedroom", "living", "bath"]
	var theme_hash := absi(int(box.position.x) * 73 + int(box.position.y) * 131 + interior.size())
	var theme := theme_pool[theme_hash % theme_pool.size()]
	# A washroom only reads on a snug footprint; a big hall becomes a kitchen.
	if theme == "bath" and interior.size() > 14:
		theme = "kitchen"
	var near_square := absi(box.size.x - box.size.y) <= 1

	# A big rug anchors the middle of the room. Rugs are walk-through decor,
	# so they are inserted at the FRONT of the list (drawn under everything)
	# and never claim their cells, letting furniture stand on top.
	var place_center_rug := func(long_ok: bool) -> void:
		var rug_name := ""
		var rug_w := 2
		if box.size.x >= 6 and box.size.y >= 5:
			rug_name = "round_rug"
			rug_w = 4
		elif near_square and box.size.x >= 4 and box.size.y >= 4:
			rug_name = "int_rug_red_square" if rng.randf() < 0.5 else "int_rug_green_square"
		elif long_ok and box.size.x >= 3 and box.size.y >= 3:
			rug_name = "int_rug_red_long" if rng.randf() < 0.5 else "int_rug_green_long"
		if rug_name == "":
			return
		var rug_cell := Vector2i(
			box.position.x + maxi((box.size.x - rug_w) / 2, 0),
			box.position.y + maxi(box.size.y / 2, 1)
		)
		if not interior_set.has(rug_cell):
			return
		placements.insert(0, {"piece": rug_name, "cell": rug_cell})

	# Line a wall with a cycling run of themed pieces; wider pieces claim
	# their span so the next one lands past them.
	var place_run := func(line_cells: Array[Vector2i], pool: Array) -> void:
		if pool.is_empty():
			return
		var pool_index := 0
		for line_cell: Vector2i in line_cells:
			if try_place.call(String(pool[pool_index % pool.size()]), line_cell):
				pool_index += 1

	var north_line: Array[Vector2i] = []
	var south_line: Array[Vector2i] = []
	for x in range(box.position.x, box.end.x):
		north_line.append(Vector2i(x, box.position.y))
		south_line.append(Vector2i(x, box.end.y - 1))
	var west_line: Array[Vector2i] = []
	var east_line: Array[Vector2i] = []
	for y in range(box.position.y + 1, box.end.y - 1):
		west_line.append(Vector2i(box.position.x, y))
		east_line.append(Vector2i(box.end.x - 1, y))
	var center_top := Vector2i(
		box.position.x + maxi((box.size.x - 4) / 2, 0),
		box.position.y + maxi((box.size.y - 2) / 2, 0)
	)

	match theme:
		"bedroom":
			place_center_rug.call(true)
			# Wardrobes and dressers along the north wall, plants between.
			place_run.call(north_line, ["int_cabinet_tall", "int_dresser_drawers", "int_plant_potted", "int_cupboard_doors", "int_dresser_drawers"])
			place_run.call(west_line, ["int_plant_potted", "int_table_flower_blue"])
			place_run.call(east_line, ["int_plant_tree", "int_table_flower_white"])
		"kitchen":
			place_center_rug.call(false)
			# Counters, a cupboard and a stove run the north wall; a roast
			# hangs over the work, a second counter run lines the south.
			place_run.call(north_line, ["int_counter_crockery", "int_kiln_beehive", "int_counter_jugs", "int_cupboard_doors", "int_counter_crockery"])
			try_place.call("int_roast_bird", center_top)
			place_run.call(south_line, ["counter_veg", "int_counter_jugs"])
			for x in range(box.position.x, box.end.x - 1):
				if try_place.call("int_hearth_arch", Vector2i(x, box.position.y)):
					break
		"study":
			place_center_rug.call(true)
			# A wall of books, then a desk with a cushioned chair on the rug.
			place_run.call(north_line, ["int_bookshelf_wide", "grandfather_clock", "int_bookshelf_red", "int_cabinet_tall", "int_bookshelf_wide"])
			place_run.call(east_line, ["int_bookshelf_red", "int_cabinet_tall"])
			if try_place.call("desk", center_top):
				for chair_offset: Vector2i in [Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 0)]:
					if try_place.call("int_chair_cushion" if rng.randf() < 0.5 else "int_chair_cushion_red", center_top + chair_offset):
						break
			else:
				try_place.call("int_chair_cushion", center_top)
		"bath":
			place_center_rug.call(true)
			# A washroom with a proper tub against the north wall, basins
			# and jugs beside it, clay pots, urns and greenery around.
			for tub_x: int in range(box.position.x, box.end.x - 2):
				if try_place.call("bathtub_white", Vector2i(tub_x, box.position.y)):
					break
			place_run.call(north_line, ["int_counter_crockery", "int_counter_jugs", "int_cupboard_doors"])
			place_run.call(south_line, ["int_urn_basket", "int_pot_clay", "int_table_flower_pot"])
			place_run.call(west_line, ["int_plant_potted"])
			place_run.call(east_line, ["int_plant_tree"])
		_:
			# Living / dining room: a table set on a big rug, candelabra
			# beside it, a sideboard and bench along the walls.
			place_center_rug.call(false)
			var seated := false
			if box.size.x >= 5 and box.size.y >= 4:
				var set_cell := Vector2i(box.position.x + (box.size.x - 4) / 2, box.position.y + (box.size.y - 2) / 2)
				if try_place.call("dining_set", set_cell):
					seated = true
					for candle_offset: Vector2i in [Vector2i(-1, 0), Vector2i(4, 0), Vector2i(-1, 1), Vector2i(4, 1)]:
						if try_place.call("int_candle_stand", set_cell + candle_offset):
							break
			if not seated and box.size.x >= 3 and box.size.y >= 3:
				if not try_place.call("round_table", center_top):
					try_place.call("long_table", center_top)
			place_run.call(north_line, ["int_cupboard_doors", "candelabra_purple", "grandfather_clock", "cabinet", "int_candle_stand"])
			place_run.call(south_line, ["bench_long"])

	# --- Corners and clutter ---------------------------------------------
	# A plant or candle stand tucked into most corners, then a scatter of
	# small props on the walls and open floor to fill the room out. Every
	# placement still passes the fit + openness guards, so door paths stay
	# clear and the room stays walkable.
	var corners: Array[Vector2i] = [
		box.position, Vector2i(box.end.x - 1, box.position.y),
		Vector2i(box.position.x, box.end.y - 1), Vector2i(box.end.x - 1, box.end.y - 1)
	]
	var corner_pool: Array[String] = ["int_plant_tree", "plant_palm", "int_plant_potted", "int_candle_stand", "int_pot_clay"]
	for corner: Vector2i in corners:
		try_place.call(corner_pool[rng.randi_range(0, corner_pool.size() - 1)], corner)

	var prop_pool: Array[String] = [
		"int_pot_clay", "int_urn_basket", "int_table_flower_blue", "int_table_flower_white",
		"int_table_flower_pot", "int_stump_table", "int_plant_potted", "int_shelf_small",
		"int_stool_cushion", "df_box_1_0", "df_box_2_0", "df_tool_20_0", "df_toy_0_0", "df_food_0_0"
	]
	var edge_cells: Array[Vector2i] = []
	for cell: Vector2i in interior:
		if cell.y == box.position.y or cell.x == box.position.x or cell.x == box.end.x - 1 or cell.y == box.end.y - 1:
			edge_cells.append(cell)
	var prop_count := rng.randi_range(3, mini(8, 4 + interior.size() / 5))
	for _prop in range(prop_count * 6):
		if prop_count <= 0:
			break
		var piece_name: String = prop_pool[rng.randi_range(0, prop_pool.size() - 1)]
		var candidate: Vector2i
		if not edge_cells.is_empty() and rng.randf() < 0.65:
			candidate = edge_cells[rng.randi_range(0, edge_cells.size() - 1)]
		else:
			candidate = interior[rng.randi_range(0, interior.size() - 1)]
		if try_place.call(piece_name, candidate):
			prop_count -= 1
	return placements

## Dressing for shopfront interiors: stocked shelves along the north
## wall, crates of goods in the corners, loose produce by the counter.
static func plan_shop_dressing(component: Array[Vector2i], building_type: String, is_occupied: Callable, door_cells: Dictionary, rng: RandomNumberGenerator, grid: Dictionary = {}) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	if not SHOP_DRESSING_TYPES.has(building_type) and not DRESSING_THEME_BY_TYPE.has(building_type):
		return placements
	var interior := interior_cells(component, grid)
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
	# rug in the center, racks and stands along the edges. Every theme
	# then lines the walls with trade furniture so small shop floors
	# read as densely dressed as the reference interiors.
	var theme := String(DRESSING_THEME_BY_TYPE.get(building_type, ""))
	var center_top := Vector2i(
		box.position.x + maxi((box.size.x - 2) / 2, 0),
		box.position.y + maxi((box.size.y - 2) / 2, 0)
	)
	var north_line: Array[Vector2i] = []
	var south_line: Array[Vector2i] = []
	for x: int in range(box.position.x, box.end.x):
		north_line.append(Vector2i(x, box.position.y))
		south_line.append(Vector2i(x, box.end.y - 1))
	var west_line: Array[Vector2i] = []
	var east_line: Array[Vector2i] = []
	for y: int in range(box.position.y + 1, box.end.y - 1):
		west_line.append(Vector2i(box.position.x, y))
		east_line.append(Vector2i(box.end.x - 1, y))
	# Line a wall with a cycling run of themed pieces; wider pieces claim
	# their span so the next one lands past them.
	var place_run := func(line_cells: Array[Vector2i], pool: Array) -> void:
		if pool.is_empty():
			return
		var pool_index := 0
		for line_cell: Vector2i in line_cells:
			if try_place.call(String(pool[pool_index % pool.size()]), line_cell):
				pool_index += 1
	# Rugs are walk-through decor drawn under the furniture: inserted at
	# the FRONT of the list and never claiming their cells, so seats and
	# tables can stand on top of them.
	var place_center_rug := func(rug_name: String) -> void:
		if box.size.x < 3 or box.size.y < 3:
			return
		var rug_cell := Vector2i(
			box.position.x + maxi((box.size.x - 2) / 2, 0),
			box.position.y + maxi((box.size.y - 2) / 2, 0)
		)
		if interior_set.has(rug_cell):
			placements.insert(0, {"piece": rug_name, "cell": rug_cell})
	match theme:
		"grooming":
			# The barber's parlor: wash-basin, shears and lather stations
			# line the north wall like mirror stands, each with a client
			# chair pulled up in front; a reception counter sits by the
			# entry wall with waiting seats down the west side and a rug
			# in the middle of the floor.
			place_center_rug.call("int_rug_red_square" if rng.randf() < 0.5 else "int_rug_green_square")
			var stations: Array[String] = ["int_groom_basin", "int_groom_shears", "int_groom_lather"]
			var station_index := 0
			for line_cell: Vector2i in north_line:
				if not try_place.call(stations[station_index % stations.size()], line_cell):
					continue
				station_index += 1
				try_place.call("barber_chair", line_cell + Vector2i(0, 1))
			# Narrow parlors whose north wall is mostly door approach still
			# deserve a working floor: spill stations down the east wall,
			# client chairs pulled up beside them.
			if station_index < 2:
				for line_cell: Vector2i in east_line:
					if not try_place.call(stations[station_index % stations.size()], line_cell):
						continue
					station_index += 1
					try_place.call("barber_chair", line_cell + Vector2i(-1, 0))
			place_run.call(south_line, ["int_counter_linens", "int_stool_cushion"])
			place_run.call(west_line, ["int_chair_cushion_red", "int_chair_cushion"])
			place_run.call(east_line, ["int_candle_stand", "int_plant_potted"])
		"smithy":
			for x: int in range(box.position.x, box.end.x - 1):
				if try_place.call("int_hearth_arch", Vector2i(x, box.position.y)):
					break
			try_place.call("int_anvil", center_top)
			place_run.call(north_line, ["int_weapon_rack_axes", "int_counter_jugs", "int_weapon_rack_pikes"])
			var stand_pool: Array[String] = ["int_armor_stand_wood", "int_armor_stand_silver", "int_armor_stand_dark", "int_armor_stand_plate"]
			place_run.call(west_line, [stand_pool[rng.randi_range(0, stand_pool.size() - 1)], "int_pot_clay"])
			place_run.call(east_line, [stand_pool[rng.randi_range(0, stand_pool.size() - 1)], "int_urn_basket"])
			place_run.call(south_line, ["int_bench_rough", stand_pool[rng.randi_range(0, stand_pool.size() - 1)]])
		"kitchen":
			for x: int in range(box.position.x, box.end.x - 1):
				if try_place.call("int_kiln_beehive", Vector2i(x, box.position.y)):
					break
			place_run.call(north_line, ["stove_iron", "int_counter_crockery", "int_counter_jugs", "int_cupboard_doors"])
			place_run.call(south_line, ["int_counter_linens", "int_counter_crockery", "int_urn_basket"])
			place_run.call(west_line, ["int_pot_clay", "int_shelf_small"])
			try_place.call("int_roast_bird", center_top + Vector2i(1, 0))
			try_place.call("int_stump_table", center_top)
		"stately":
			place_center_rug.call("int_rug_red_long" if rng.randf() < 0.5 else "int_rug_green_long")
			# The seat of honor faces the hall from the north wall, flanked
			# by the purple candelabras of the reference throne room.
			for throne_x: int in range(box.position.x + 1, box.end.x - 1):
				if try_place.call("throne_red", Vector2i(throne_x, box.position.y)):
					try_place.call("candelabra_purple", Vector2i(throne_x + 1, box.position.y))
					try_place.call("candelabra_purple", Vector2i(throne_x - 1, box.position.y))
					break
			for candle_offset: Vector2i in [Vector2i(-1, 0), Vector2i(2, 0)]:
				try_place.call("candelabra_purple", center_top + candle_offset)
			place_run.call(north_line, ["int_bookshelf_wide", "grandfather_clock", "int_bookshelf_red", "int_cabinet_tall"])
			place_run.call(east_line, ["int_bookshelf_red", "int_plant_tree"])
			place_run.call(west_line, ["grandfather_clock", "int_cabinet_tall", "int_table_flower_white"])
			# A reading table with a cushioned chair beside the rug turns
			# the hall from a bare library into a working office.
			if box.size.x >= 4 and box.size.y >= 4:
				if try_place.call("long_table", center_top + Vector2i(-1, 1)):
					try_place.call("int_chair_cushion_red", center_top + Vector2i(2, 1))
		"guard":
			# The rug goes first in the list: with furniture stacked by
			# placement order, first placed means drawn underneath.
			place_center_rug.call("int_rug_green_square")
			place_run.call(north_line, ["int_weapon_rack_pikes", "int_weapon_rack_axes"])
			var stands: Array[String] = ["int_armor_stand_silver", "int_armor_stand_plate", "int_armor_stand_dark", "int_armor_stand_wood"]
			place_run.call(west_line, [stands[rng.randi_range(0, stands.size() - 1)]])
			place_run.call(east_line, [stands[rng.randi_range(0, stands.size() - 1)]])
			place_run.call(south_line, ["int_bench_rough", stands[rng.randi_range(0, stands.size() - 1)]])
			var stand_count := rng.randi_range(2, 3)
			for _stand in range(stand_count * 4):
				if stand_count <= 0:
					break
				if try_place.call(stands[rng.randi_range(0, stands.size() - 1)], interior[rng.randi_range(0, interior.size() - 1)]):
					stand_count -= 1
		"herbal":
			place_center_rug.call("int_rug_green_square")
			place_run.call(north_line, ["int_shelf_small", "int_shelf_flowerpot", "int_cupboard_doors"])
			place_run.call(south_line, ["int_counter_crockery", "int_table_plant_fern"])
			place_run.call(west_line, ["int_plant_potted", "int_pot_clay"])
			place_run.call(east_line, ["int_plant_tree", "int_urn_basket"])
			var green_pool: Array[String] = ["int_plant_potted", "int_plant_tree", "int_urn_basket", "int_table_flower_blue", "int_table_flower_white", "int_table_plant_fern", "int_shelf_flowerpot"]
			var green_count := rng.randi_range(3, 5)
			for _green in range(green_count * 4):
				if green_count <= 0:
					break
				if try_place.call(green_pool[rng.randi_range(0, green_pool.size() - 1)], interior[rng.randi_range(0, interior.size() - 1)]):
					green_count -= 1
		"hearthside":
			for x: int in range(box.position.x, box.end.x - 1):
				if try_place.call("int_fireplace_dark", Vector2i(x, box.position.y)):
					break
			place_center_rug.call("int_rug_red_square")
			place_run.call(north_line, ["int_counter_jugs", "int_cupboard_doors"])
			# A common table ringed by stools makes the taproom read as a
			# place people actually drink in.
			if try_place.call("int_stump_table", center_top + Vector2i(0, 1)):
				for stool_offset: Vector2i in [Vector2i(-1, 1), Vector2i(1, 1), Vector2i(0, 2)]:
					try_place.call("int_stool_cushion" if rng.randf() < 0.5 else "int_stool_low", center_top + stool_offset)
			try_place.call("int_roast_bird", center_top + Vector2i(-1, 1))
			place_run.call(west_line, ["int_stool_low", "int_pot_clay"])
			place_run.call(east_line, ["bar_barrel", "int_urn_basket"])
		"craft":
			place_run.call(north_line, ["int_bench_rough", "int_counter_linens", "int_shelf_small"])
			place_run.call(south_line, ["int_bench_rough", "int_urn_basket"])
			place_run.call(west_line, ["int_pot_crate", "int_pot_clay"])
			place_run.call(east_line, ["int_shelf_small", "int_urn_basket"])
			try_place.call("int_stump_table", center_top)
			try_place.call("int_stool_low", center_top + Vector2i(-1, 1))
			try_place.call("int_stool_low", center_top + Vector2i(1, 1))
		"stockroom":
			place_run.call(north_line, ["int_counter_jugs", "int_pot_crate", "int_cupboard_doors"])
			place_run.call(west_line, ["int_pot_crate", "int_urn_basket"])
			place_run.call(east_line, ["int_urn_basket", "int_pot_clay"])
			place_run.call(south_line, ["int_pot_crate", "int_pot_clay"])
			# Loose floor crates are walk-through decor, so a wide room can
			# take them without choking the aisles.
			try_place.call("crate_floor", Vector2i(box.position.x, box.end.y - 2))
			var stock_pool: Array[String] = ["int_pot_crate", "int_urn_basket", "int_pot_clay", "int_counter_jugs"]
			var stock_count := rng.randi_range(4, 6)
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

	# --- Corners and clutter -----------------------------------------------
	# The finishing pass every dressed interior gets: greenery or a candle
	# stand tucked into the corners, then small props scattered along the
	# walls, scaled to floor area. Placements still run the fit + openness
	# guards, so the door approach and room connectivity stay intact.
	var corner_pool: Array[String] = ["int_plant_tree", "int_plant_potted", "int_candle_stand", "int_urn_basket", "int_pot_clay"]
	var corners: Array[Vector2i] = [
		box.position, Vector2i(box.end.x - 1, box.position.y),
		Vector2i(box.position.x, box.end.y - 1), Vector2i(box.end.x - 1, box.end.y - 1)
	]
	for corner: Vector2i in corners:
		try_place.call(corner_pool[rng.randi_range(0, corner_pool.size() - 1)], corner)
	var prop_pool: Array[String] = [
		"int_pot_clay", "int_urn_basket", "int_table_flower_pot", "int_shelf_small",
		"int_plant_potted", "int_stool_low", "df_box_1_0", "df_box_2_0", "df_tool_20_0"
	]
	var edge_cells: Array[Vector2i] = []
	for cell: Vector2i in interior:
		if cell.y == box.position.y or cell.x == box.position.x or cell.x == box.end.x - 1 or cell.y == box.end.y - 1:
			edge_cells.append(cell)
	var prop_count := rng.randi_range(2, mini(7, 3 + interior.size() / 5))
	for _prop in range(prop_count * 6):
		if prop_count <= 0:
			break
		var prop_name: String = prop_pool[rng.randi_range(0, prop_pool.size() - 1)]
		var candidate: Vector2i
		if not edge_cells.is_empty() and rng.randf() < 0.65:
			candidate = edge_cells[rng.randi_range(0, edge_cells.size() - 1)]
		else:
			candidate = interior[rng.randi_range(0, interior.size() - 1)]
		if try_place.call(prop_name, candidate):
			prop_count -= 1
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
		"extra":
			sprite.texture = EXTRA_FURNITURE_TEXTURE
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

## Shared glow resources: the ring pixels depend only on the RGB
## (radius rides sprite.scale), so every hearth, sconce, and street lamp
## of a color shares ONE texture and ONE additive material - an underhall
## with 140 sconces uploads one 96x96 image, not 140.
## Hard pixel light: the halo is three flat concentric rings drawn at
## 12x12 and upscaled nearest - chunky stepped firelight, no gradient.
static var _glow_textures: Dictionary = {}
static var _glow_material: CanvasItemMaterial

static func _glow_texture_for_color(color: Color) -> Texture2D:
	var key := color.to_html(false)
	if _glow_textures.has(key):
		return _glow_textures[key] as Texture2D
	var image := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for py in range(12):
		for px in range(12):
			var ring_distance := Vector2(float(px) - 5.5, float(py) - 5.5).length()
			var ring_alpha := 0.0
			if ring_distance <= 2.5:
				ring_alpha = 0.5
			elif ring_distance <= 4.0:
				ring_alpha = 0.3
			elif ring_distance <= 5.5:
				ring_alpha = 0.14
			if ring_alpha > 0.0:
				image.set_pixel(px, py, Color(color.r, color.g, color.b, ring_alpha))
	image.resize(96, 96, Image.INTERPOLATE_NEAREST)
	var texture := ImageTexture.create_from_image(image)
	_glow_textures[key] = texture
	return texture

## A warm additive light pool for hearths and candle stands.
static func create_glow_sprite(world_position: Vector2, radius: float, color: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _glow_texture_for_color(color)
	sprite.centered = true
	sprite.position = world_position
	sprite.scale = Vector2.ONE * (radius / 48.0)
	sprite.z_index = 14
	if _glow_material == null:
		_glow_material = CanvasItemMaterial.new()
		_glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = _glow_material
	return sprite
