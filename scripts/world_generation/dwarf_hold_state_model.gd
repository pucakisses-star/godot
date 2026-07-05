extends RefCounted
class_name DwarfHoldStateModel

const INVALID_CELL := Vector2i(2147483647, 2147483647)

var generated_levels: Array[Dictionary] = []
var current_level_index := 0
var active_level_stairs: Dictionary = {}
var selected_hold_population := 0
var target_resident_npcs := 0

func apply_world_settings(settings: Dictionary, seed_key: String, population_key: String) -> String:
	var scene_seed := String(settings.get(seed_key, "")).strip_edges()
	selected_hold_population = maxi(0, int(settings.get(population_key, 0)))
	target_resident_npcs = int(ceil(float(selected_hold_population) / 10.0))
	return scene_seed

## How many underground levels a hold of this population digs: roughly one
## level per 120 residents, so a 50-resident hold is a single cozy level
## while a great hold spans the maximum depth. Returns 0 when there is no
## population data so callers can fall back to a random roll.
func population_scaled_level_count(max_levels: int) -> int:
	if target_resident_npcs <= 0:
		return 0
	# Every hold pierces the full strata - soil, stone, the cavern and
	# the starmetal deep - population digs it deeper still.
	return clampi(2 + int(ceil(float(target_resident_npcs) / 120.0)), 4, maxi(4, max_levels))

func target_npcs_for_level(level_index: int, level_count: int) -> int:
	if target_resident_npcs <= 0:
		return 0
	var safe_level_count := maxi(level_count, 1)
	var base_target := target_resident_npcs / safe_level_count
	var remainder := target_resident_npcs % safe_level_count
	if level_index < remainder:
		return base_target + 1
	return base_target
