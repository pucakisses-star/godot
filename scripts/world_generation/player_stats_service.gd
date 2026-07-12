class_name PlayerStatsService
extends RefCounted

## Derives the player's combat and survival stats from the character
## sheet, so the profession chosen at creation matters in play. Named
## professions carry their own bonuses; everything else falls back to
## its hero-class temperament (the same mapping that used to pick the
## SPD sprite).

const BASE_MAX_HP := 20.0
const BASE_ATTACK := 2

## Exact profession overrides (lowercase): {hp, attack}.
const PROFESSION_STATS := {
	"miner": {"hp": 8, "attack": 1},
	"mason": {"hp": 6, "attack": 0},
	"armourer": {"hp": 10, "attack": 0},
	"weaponsmith": {"hp": 0, "attack": 3},
	"smith": {"hp": 4, "attack": 2},
	"metalsmith": {"hp": 4, "attack": 2},
	"brewmaster": {"hp": 6, "attack": 0},
	"brewer": {"hp": 6, "attack": 0},
	"distiller": {"hp": 6, "attack": 0},
	"ranger": {"hp": 2, "attack": 2},
	"hunter": {"hp": 2, "attack": 2},
	"farmer": {"hp": 4, "attack": 0},
	"herder": {"hp": 4, "attack": 0},
	"shepherd": {"hp": 4, "attack": 0},
	# Compat alias: older saves stored the misspelled profession.
	"shepard": {"hp": 4, "attack": 0},
	"scholar": {"hp": -2, "attack": 3},
	"alchemist": {"hp": -2, "attack": 3},
	"banker": {"hp": -2, "attack": -1}
}

## Class fallbacks for the long tail of professions.
const CLASS_STATS := {
	"warrior": {"hp": 4, "attack": 1},
	"mage": {"hp": -2, "attack": 2},
	"rogue": {"hp": 0, "attack": 1},
	"huntress": {"hp": 2, "attack": 1}
}

static func _modifiers(character: Dictionary) -> Dictionary:
	var profession := String(character.get("profession", "")).strip_edges().to_lower()
	if profession.is_empty():
		# Legacy saves without a profession keep the plain base values.
		return {"hp": 0, "attack": 0}
	if PROFESSION_STATS.has(profession):
		return PROFESSION_STATS[profession] as Dictionary
	var hero_class := DwarfHoldActorVisuals.hero_class_for_profession(profession)
	return CLASS_STATS.get(hero_class, {"hp": 0, "attack": 0}) as Dictionary

static func max_hp(character: Dictionary) -> float:
	return maxf(8.0, BASE_MAX_HP + float(int(_modifiers(character).get("hp", 0))))

static func attack_damage(character: Dictionary) -> int:
	return maxi(1, BASE_ATTACK + int(_modifiers(character).get("attack", 0)))

## The character sheet plus the whole armory: gear ladder, set bonus,
## carried trinkets, enchants and live potion buffs all fold in here.
static func for_session(context: Node) -> Dictionary:
	var character: Dictionary = {}
	var settings: Dictionary = {}
	var session := context.get_node_or_null("/root/GameSession")
	if session != null and session.has_method("get_player_character"):
		character = session.call("get_player_character")
	if session != null and session.has_method("get_world_settings"):
		settings = session.call("get_world_settings")
	var inventory := settings.get("player_inventory", {}) as Dictionary if settings.get("player_inventory") is Dictionary else {}
	var loadout: Dictionary = GearService.resolve_loadout(settings, inventory)
	return {
		"max_hp": max_hp(character) + float(loadout.get("hp_bonus", 0.0)),
		"attack": attack_damage(character) + int(loadout.get("attack_bonus", 0)),
		"speed_mult": float(loadout.get("speed_mult", 1.0)),
		"loadout": loadout
	}

## --- Starmetal gear ---------------------------------------------------------
## Deep-level starmetal smelts into bars at a working furnace and forges
## into permanent gear at an anvil. Gear is a world-settings flag, so it
## persists like the rest of the player state.

const GEAR_STARMETAL_BLADE := "starmetal_blade"
const GEAR_STARMETAL_PLATE := "starmetal_plate"
const STARMETAL_BLADE_ATTACK := 3
const STARMETAL_PLATE_HP := 15.0
const SMELT_ORE_PER_BAR := 2
const FORGE_BARS_PER_PIECE := 3

static func has_gear(context: Node, gear_key: String) -> bool:
	var session := context.get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("get_world_settings"):
		return false
	var settings: Dictionary = session.call("get_world_settings")
	return bool(settings.get(gear_key, false))

static func grant_gear(context: Node, gear_key: String) -> void:
	var session := context.get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("get_world_settings") or not session.has_method("set_world_settings"):
		return
	var settings: Dictionary = session.call("get_world_settings")
	settings[gear_key] = true
	session.call("set_world_settings", settings)

static func stat_summary(character: Dictionary) -> String:
	return "❤ %d   ⚔ %d" % [int(max_hp(character)), attack_damage(character)]

## --- Hunger ---------------------------------------------------------------
## Satiety runs 0..100 and drains with the world clock; food restores it
## in proportion to its heal value. Below the hungry line wounds stop
## mending; at zero the dwarf starves.

const SATIETY_MAX := 100.0
const SATIETY_DRAIN_PER_GAME_HOUR := 4.0
const SATIETY_HUNGRY_THRESHOLD := 25.0
const STARVATION_DAMAGE_PER_GAME_HOUR := 2.0
const SATIETY_PER_HEAL_POINT := 4.0

static func load_satiety(context: Node) -> float:
	var session := context.get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("get_world_settings"):
		return SATIETY_MAX
	var settings: Dictionary = session.call("get_world_settings")
	return clampf(float(settings.get("player_satiety", SATIETY_MAX)), 0.0, SATIETY_MAX)

static func save_satiety(context: Node, satiety: float) -> void:
	var session := context.get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("get_world_settings") or not session.has_method("set_world_settings"):
		return
	var settings: Dictionary = session.call("get_world_settings")
	settings["player_satiety"] = clampf(satiety, 0.0, SATIETY_MAX)
	session.call("set_world_settings", settings)

static func hunger_label(satiety: float) -> String:
	if satiety <= 0.0:
		return "🍖 Starving!"
	if satiety <= SATIETY_HUNGRY_THRESHOLD:
		return "🍖 Hungry (%d%%)" % int(satiety)
	return "🍖 Sated (%d%%)" % int(satiety)
