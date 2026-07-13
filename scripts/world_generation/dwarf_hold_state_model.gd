extends RefCounted
class_name DwarfHoldStateModel

const INVALID_CELL := Vector2i(2147483647, 2147483647)

var generated_levels: Array[Dictionary] = []
var current_level_index := 0
var active_level_stairs: Dictionary = {}
var selected_hold_population := 0
var target_resident_npcs := 0

## --- The level column: navigation authority ---------------------------------
## Both settlement scenes (surface town and underground hold) drive a stack
## of level grids through this one model. These helpers are the single
## source of truth for "where am I in the column and where can I go", so
## the two scenes stop each re-deriving `index > 0` / `< size - 1` /
## `clampi(...)` inline. This is also the seam the eventual seamless
## surface<->deep column hangs off: today the top of the stack is index 0
## and the bottom is the deepest; a unified column will map z onto the same
## navigation predicates.
func level_count() -> int:
	return generated_levels.size()

func has_levels() -> bool:
	return not generated_levels.is_empty()

func is_valid_index(index: int) -> bool:
	return index >= 0 and index < generated_levels.size()

## True when current_level_index actually addresses a generated level.
func has_current() -> bool:
	return is_valid_index(current_level_index)

## Clamps an arbitrary target into the generated range (empty stack -> 0).
func clamp_index(target_index: int) -> int:
	if generated_levels.is_empty():
		return 0
	return clampi(target_index, 0, generated_levels.size() - 1)

## Index 0 is the top of the column (surface / main floor); the last index
## is the deepest dug level.
func is_top_level() -> bool:
	return current_level_index <= 0

func is_deepest() -> bool:
	return has_levels() and current_level_index == generated_levels.size() - 1

## The level dict the walker currently stands on, or {} if the stack is empty.
func current_level() -> Dictionary:
	if not has_current():
		return {}
	return generated_levels[current_level_index] as Dictionary

## 1-based level for display ("Level 3 / 5").
func display_level() -> int:
	return current_level_index + 1

func apply_world_settings(settings: Dictionary, seed_key: String, population_key: String) -> String:
	var scene_seed := String(settings.get(seed_key, "")).strip_edges()
	selected_hold_population = maxi(0, int(settings.get(population_key, 0)))
	target_resident_npcs = int(ceil(float(selected_hold_population) / 10.0))
	return scene_seed

## How many underground levels a settlement of this population digs: roughly
## one level per 120 residents, so a 50-resident hold is a single cozy level
## while a great hold spans the maximum depth. Returns 0 when there is no
## population data so callers can fall back to a random roll.
func population_scaled_level_count(max_levels: int) -> int:
	if target_resident_npcs <= 0:
		return 0
	# Every dwarfhold pierces the full strata - soil, stone, the cavern and
	# the starmetal deep - population digs it deeper still. But the SCENE's
	# configured maximum always wins: the old hard floor of 4 forced surface
	# towns (whose range caps at 2) to dig four phantom cellar levels, so the
	# floor is capped at the scene's own maximum instead.
	var minimum_levels := mini(4, maxi(1, max_levels))
	return clampi(2 + int(ceil(float(target_resident_npcs) / 120.0)), minimum_levels, maxi(minimum_levels, max_levels))

func target_npcs_for_level(level_index: int, total_levels: int) -> int:
	if target_resident_npcs <= 0:
		return 0
	var safe_level_count := maxi(total_levels, 1)
	var base_target := target_resident_npcs / safe_level_count
	var remainder := target_resident_npcs % safe_level_count
	if level_index < remainder:
		return base_target + 1
	return base_target
