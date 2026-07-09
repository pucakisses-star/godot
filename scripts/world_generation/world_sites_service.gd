extends RefCounted
class_name WorldSitesService

## The persisted gazetteer. At overworld generation every enterable
## site - towns, cities, hamlets, desert cities, dwarfholds, dungeons -
## is written into world settings with its tile, name, seed and scene
## wiring, so local scenes can know their neighbors and a walker can
## arrive somewhere real without ever opening the map.

const SETTINGS_KEY := "world_sites"

const TOWN_SCENE_PATH := "res://scenes/town_generation.tscn"
const DWARFHOLD_SCENE_PATH := "res://scenes/dwarf_hold_generation.tscn"
const DUNGEON_SCENE_PATH := "res://scenes/dungeon_interior.tscn"

static func sites_from_settings(settings: Dictionary) -> Array:
	return settings.get(SETTINGS_KEY, []) as Array

static func site_tile(site: Dictionary) -> Vector2i:
	return Vector2i(int(site.get("x", 0)), int(site.get("y", 0)))

static func scene_path_for(site: Dictionary) -> String:
	match String(site.get("class", "")):
		"town":
			return TOWN_SCENE_PATH
		"dwarfhold":
			return DWARFHOLD_SCENE_PATH
		"dungeon":
			return DUNGEON_SCENE_PATH
	return ""

## Writes the journey context the destination scene reads at ready -
## the same keys the overworld's Begin Journey writes.
static func store_journey_context(settings: Dictionary, site: Dictionary) -> void:
	var tile := site_tile(site)
	match String(site.get("class", "")):
		"town":
			# A real settlement is never a wild embark: clear any stale wild
			# flags left by an earlier open-tile journey (the overworld's
			# Begin Journey does the same) so the scene builds a city, and
			# carry the village flag when the site records one.
			settings["town_scene_is_wild"] = false
			settings["town_scene_wild_water"] = false
			settings["town_scene_is_village"] = bool(site.get("is_hamlet", false)) or bool(site.get("is_snow_village", false))
			settings["town_scene_seed"] = String(site.get("seed", ""))
			settings["town_scene_tile"] = {"x": tile.x, "y": tile.y}
			settings["town_scene_name"] = String(site.get("name", ""))
			settings["town_scene_population"] = maxi(0, int(site.get("population", 0)))
			settings["town_scene_theme"] = String(site.get("theme", ""))
		"dwarfhold":
			settings["dwarfhold_scene_seed"] = String(site.get("seed", ""))
			settings["dwarfhold_scene_tile"] = {"x": tile.x, "y": tile.y}
			settings["dwarfhold_scene_name"] = String(site.get("name", ""))
			settings["dwarfhold_scene_population"] = maxi(0, int(site.get("population", 0)))
			# Underdeep projections belong to the overworld's richer view;
			# stale ones from another hold would project the wrong towns.
			settings.erase("underdeep_sites")
		"dungeon":
			settings["dungeon_scene_seed"] = String(site.get("seed", ""))
			settings["dungeon_scene_name"] = String(site.get("name", ""))
