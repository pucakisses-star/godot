class_name DfFurnitureDefs
extends RefCounted

## The Dwarf Fortress furniture and object sheets, packed into one
## atlas: bookcases, chests, cabinets, chairs, tables, beds, jugs,
## crocks, beehives, minecarts, wheelbarrows, books, tools and more.
## Keys are df_<sheet>_<row>_<col> from the source art; rows are
## material variants.

const FURNITURE_ATLAS_TEXTURE := "res://resources/images/dwarfhold/df_furniture_atlas.png"

const FURNITURE_ATLAS := {
	"df_bookcase_0_0": Vector2i(0, 0),
	"df_bookcase_1_0": Vector2i(1, 0),
	"df_bookcase_2_0": Vector2i(2, 0),
	"df_bookcase_3_0": Vector2i(3, 0),
	"df_box_0_0": Vector2i(4, 0),
	"df_box_0_1": Vector2i(5, 0),
	"df_box_0_7": Vector2i(6, 0),
	"df_box_1_0": Vector2i(7, 0),
	"df_box_1_1": Vector2i(8, 0),
	"df_box_1_7": Vector2i(9, 0),
	"df_box_2_0": Vector2i(10, 0),
	"df_box_2_1": Vector2i(11, 0),
	"df_box_2_7": Vector2i(12, 0),
	"df_box_3_0": Vector2i(13, 0),
	"df_box_3_1": Vector2i(14, 0),
	"df_box_3_7": Vector2i(15, 0),
	"df_cabinet_0_0": Vector2i(0, 1),
	"df_cabinet_1_0": Vector2i(1, 1),
	"df_cabinet_2_0": Vector2i(2, 1),
	"df_cabinet_3_0": Vector2i(3, 1),
	"df_chair_0_0": Vector2i(4, 1),
	"df_chair_0_7": Vector2i(5, 1),
	"df_chair_1_0": Vector2i(6, 1),
	"df_chair_2_0": Vector2i(7, 1),
	"df_chair_3_0": Vector2i(8, 1),
	"df_door_0_0": Vector2i(9, 1),
	"df_door_0_1": Vector2i(10, 1),
	"df_door_0_12": Vector2i(12, 1),
	"df_door_0_8": Vector2i(11, 1),
	"df_door_1_0": Vector2i(13, 1),
	"df_door_1_1": Vector2i(14, 1),
	"df_door_1_8": Vector2i(15, 1),
	"df_door_2_0": Vector2i(0, 2),
	"df_door_2_1": Vector2i(1, 2),
	"df_door_2_8": Vector2i(2, 2),
	"df_door_3_0": Vector2i(3, 2),
	"df_door_3_1": Vector2i(4, 2),
	"df_door_3_8": Vector2i(5, 2),
	"df_food_0_0": Vector2i(6, 2),
	"df_food_1_0": Vector2i(7, 2),
	"df_food_2_0": Vector2i(8, 2),
	"df_table_0_0": Vector2i(9, 2),
	"df_table_0_7": Vector2i(10, 2),
	"df_table_1_0": Vector2i(11, 2),
	"df_table_2_0": Vector2i(12, 2),
	"df_table_3_0": Vector2i(13, 2),
	"df_tool_0_0": Vector2i(14, 2),
	"df_tool_10_0": Vector2i(12, 3),
	"df_tool_10_1": Vector2i(13, 3),
	"df_tool_10_2": Vector2i(14, 3),
	"df_tool_10_3": Vector2i(15, 3),
	"df_tool_11_0": Vector2i(0, 4),
	"df_tool_11_1": Vector2i(1, 4),
	"df_tool_11_2": Vector2i(2, 4),
	"df_tool_12_0": Vector2i(3, 4),
	"df_tool_12_1": Vector2i(4, 4),
	"df_tool_12_2": Vector2i(5, 4),
	"df_tool_13_0": Vector2i(6, 4),
	"df_tool_13_1": Vector2i(7, 4),
	"df_tool_13_2": Vector2i(8, 4),
	"df_tool_13_3": Vector2i(9, 4),
	"df_tool_14_0": Vector2i(10, 4),
	"df_tool_15_0": Vector2i(11, 4),
	"df_tool_16_0": Vector2i(12, 4),
	"df_tool_16_1": Vector2i(13, 4),
	"df_tool_17_0": Vector2i(14, 4),
	"df_tool_17_1": Vector2i(15, 4),
	"df_tool_18_0": Vector2i(0, 5),
	"df_tool_18_1": Vector2i(1, 5),
	"df_tool_19_0": Vector2i(2, 5),
	"df_tool_19_1": Vector2i(3, 5),
	"df_tool_1_0": Vector2i(15, 2),
	"df_tool_1_1": Vector2i(0, 3),
	"df_tool_20_0": Vector2i(4, 5),
	"df_tool_20_1": Vector2i(5, 5),
	"df_tool_20_2": Vector2i(6, 5),
	"df_tool_20_3": Vector2i(7, 5),
	"df_tool_21_0": Vector2i(8, 5),
	"df_tool_21_1": Vector2i(9, 5),
	"df_tool_22_0": Vector2i(10, 5),
	"df_tool_23_0": Vector2i(11, 5),
	"df_tool_23_1": Vector2i(12, 5),
	"df_tool_23_2": Vector2i(13, 5),
	"df_tool_23_3": Vector2i(14, 5),
	"df_tool_24_0": Vector2i(15, 5),
	"df_tool_25_0": Vector2i(0, 6),
	"df_tool_26_0": Vector2i(1, 6),
	"df_tool_26_1": Vector2i(2, 6),
	"df_tool_26_2": Vector2i(3, 6),
	"df_tool_26_3": Vector2i(4, 6),
	"df_tool_27_0": Vector2i(5, 6),
	"df_tool_27_1": Vector2i(6, 6),
	"df_tool_28_0": Vector2i(7, 6),
	"df_tool_28_1": Vector2i(8, 6),
	"df_tool_28_2": Vector2i(9, 6),
	"df_tool_28_3": Vector2i(10, 6),
	"df_tool_2_0": Vector2i(1, 3),
	"df_tool_2_1": Vector2i(2, 3),
	"df_tool_3_0": Vector2i(3, 3),
	"df_tool_3_1": Vector2i(4, 3),
	"df_tool_4_0": Vector2i(5, 3),
	"df_tool_4_1": Vector2i(6, 3),
	"df_tool_5_0": Vector2i(7, 3),
	"df_tool_6_0": Vector2i(8, 3),
	"df_tool_7_0": Vector2i(9, 3),
	"df_tool_8_0": Vector2i(10, 3),
	"df_tool_9_0": Vector2i(11, 3),
	"df_toy_0_0": Vector2i(11, 6),
	"df_toy_0_1": Vector2i(12, 6),
	"df_toy_1_0": Vector2i(13, 6),
	"df_toy_1_1": Vector2i(14, 6),
	"df_toy_2_0": Vector2i(15, 6),
	"df_toy_2_1": Vector2i(0, 7),
	"df_toy_3_0": Vector2i(1, 7),
	"df_toy_3_1": Vector2i(2, 7),
	"df_toy_4_0": Vector2i(3, 7),
	"df_toy_4_1": Vector2i(4, 7)
}

const DISPLAY_NAMES := {
	"bookcase": "Bookcase", "box": "Chest", "cabinet": "Cabinet", "chair": "Chair",
	"table": "Table", "door": "Door", "tool": "Tool", "toy": "Curio", "food": "Meal"
}

## Containers the player can search once for loot.
const SEARCHABLE_PREFIXES := [
	"df_box_", "df_cabinet_", "df_bookcase_",
	"int_dresser_", "int_cupboard_", "int_cabinet_", "int_bookshelf_"
]

static func display_name(key: String) -> String:
	if key.begins_with("int_"):
		return key.trim_prefix("int_").capitalize()
	if not key.begins_with("df_"):
		return key.capitalize()
	var parts := key.trim_prefix("df_").split("_")
	return String(DISPLAY_NAMES.get(parts[0], parts[0].capitalize()))

static func is_searchable(key: String) -> bool:
	for prefix: String in SEARCHABLE_PREFIXES:
		if key.begins_with(prefix):
			return true
	return false

static func key_for_atlas(coords: Vector2i) -> String:
	for key_variant: Variant in FURNITURE_ATLAS.keys():
		if FURNITURE_ATLAS[key_variant] == coords:
			return String(key_variant)
	return ""

static func keys_with_prefix(prefix: String) -> Array[String]:
	var matches: Array[String] = []
	for key_variant: Variant in FURNITURE_ATLAS.keys():
		if String(key_variant).begins_with(prefix):
			matches.append(String(key_variant))
	matches.sort()
	return matches
