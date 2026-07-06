extends RefCounted
class_name GearService

## The armory: the ore-to-gear ladder, weapon classes, trinkets, garbs,
## enchants, and potion buffs - and the math that folds a walker's whole
## loadout into the stats the scenes actually use. Gear ownership lives
## in world settings under "player_gear" (name -> true), enchants under
## "player_enchants" (slot -> enchant), timed buffs under "player_buffs"
## (list with expiry in total game hours). Trinkets are ordinary
## inventory items - carrying one is wearing it.

const GEAR_KEY := "player_gear"
const ENCHANTS_KEY := "player_enchants"
const BUFFS_KEY := "player_buffs"

## Weapon and armor pieces, forged at a furnace-fed anvil from smelted
## bars. Tier orders the ladder; matched blade+plate tiers grant a set
## bonus.
const GEAR_DEFS := {
	"Copper Blade": {"slot": "blade", "tier": 1, "attack": 1, "craft": {"Copper Ingot": 2}},
	"Iron Blade": {"slot": "blade", "tier": 2, "attack": 2, "craft": {"Iron Ingot": 2}},
	"Gold Blade": {"slot": "blade", "tier": 3, "attack": 3, "craft": {"Gold Ingot": 2}},
	"Starmetal Blade": {"slot": "blade", "tier": 4, "attack": 5, "craft": {"Starmetal Bar": 3}},
	"Copper Plate": {"slot": "plate", "tier": 1, "hp": 4.0, "craft": {"Copper Ingot": 3}},
	"Iron Plate": {"slot": "plate", "tier": 2, "hp": 8.0, "craft": {"Iron Ingot": 3}},
	"Gold Plate": {"slot": "plate", "tier": 3, "hp": 12.0, "craft": {"Gold Ingot": 3}},
	"Starmetal Plate": {"slot": "plate", "tier": 4, "hp": 18.0, "craft": {"Starmetal Bar": 3}},
	"Short Bow": {"slot": "bow", "tier": 1, "range": 4, "attack": 0, "craft": {"Timber": 3, "Copper Ingot": 1}},
	"War Bow": {"slot": "bow", "tier": 2, "range": 6, "attack": 2, "craft": {"Timber": 4, "Iron Ingot": 2}},
	"Oak Staff": {"slot": "staff", "tier": 1, "attack": 1, "radius": 1, "cooldown": 9.0, "craft": {"Timber": 4, "Gem Shard": 1}},
	"Runed Staff": {"slot": "staff", "tier": 2, "attack": 3, "radius": 2, "cooldown": 7.0, "craft": {"Timber": 4, "Gold Ingot": 2, "Gem Shard": 2}},
	"Beast Charm": {"slot": "charm", "tier": 1, "summon_attack": 2, "craft": {"Lizard Scale": 2, "Orcish Tooth": 2, "Leather Strap": 1}},
	"Hunter's Garb": {"slot": "garb", "tier": 1, "hp": 3.0, "bow_attack": 2, "craft": {"Cured Leather": 2, "Timber": 2}},
	"Warcaster's Robe": {"slot": "garb", "tier": 1, "hp": 3.0, "staff_attack": 2, "craft": {"Bolt of Cloth": 2, "Gem Shard": 2}},
	"Beastmaster's Cloak": {"slot": "garb", "tier": 1, "hp": 3.0, "summon_attack": 2, "craft": {"Cured Leather": 2, "Skein of Wool": 2}}
}

## The order the anvil offers work in: finish a weapon, cover your back,
## then branch into the classes.
const FORGE_ORDER := [
	"Copper Blade", "Copper Plate", "Iron Blade", "Iron Plate",
	"Short Bow", "Oak Staff", "Beast Charm",
	"Gold Blade", "Gold Plate", "War Bow", "Runed Staff",
	"Hunter's Garb", "Warcaster's Robe", "Beastmaster's Cloak",
	"Starmetal Blade", "Starmetal Plate"
]

const SET_BONUS_ATTACK := 1
const SET_BONUS_HP := 4.0

## Trinkets ride in the pack: the best two carried apply.
const TRINKET_DEFS := {
	"Wolf Fang Charm": {"attack": 1},
	"Hearthstone Amulet": {"hp": 6.0},
	"Fleetfoot Boots": {"speed": 0.15},
	"Warding Ring": {"attack": 1, "hp": 3.0}
}
const TRINKET_SLOTS := 2

## Ore into bars at a lit furnace.
const SMELT_DEFS := {
	"Copper Ore": {"bar": "Copper Ingot", "count": 2},
	"Iron Ore": {"bar": "Iron Ingot", "count": 2},
	"Gold Nugget": {"bar": "Gold Ingot", "count": 2},
	"Starmetal Ore": {"bar": "Starmetal Bar", "count": 2}
}
const SMELT_ORDER := ["Starmetal Ore", "Gold Nugget", "Iron Ore", "Copper Ore"]

## Potions: brewed over a clay pot from herbs and the hunt, or bought.
## Heal potions act at once; the rest lay a timed buff on the walker.
const POTION_DEFS := {
	"Healing Potion": {"heal": 12, "brew": {"Scarlet Blossom": 1, "Mushrooms": 2}},
	"Ironhide Draught": {"buff": "Ironhide", "hours": 8.0, "hp": 10.0, "brew": {"Frostleaf": 1, "Dried Root": 2}},
	"Hunter's Tonic": {"buff": "Hunter's Eye", "hours": 8.0, "attack": 2, "brew": {"Firebloom": 1, "Beast Heart": 1}},
	"Fleetfoot Philter": {"buff": "Fleetfoot", "hours": 8.0, "speed": 0.25, "brew": {"Sky Thistle": 1, "Nightberries": 2}}
}

## Enchants: a Runestone read over an open book binds one onto weapon or
## armor. A slot holds one enchant; a new roll replaces a weaker one.
const ENCHANT_COIN_COST := 40
const ENCHANT_DEFS := [
	{"name": "Keen", "target": "weapon", "attack": 1},
	{"name": "Savage", "target": "weapon", "attack": 2},
	{"name": "Stalwart", "target": "armor", "hp": 5.0},
	{"name": "Bulwark", "target": "armor", "hp": 8.0},
	{"name": "Swift", "target": "armor", "speed": 0.1}
]

## --- ownership --------------------------------------------------------------

static func owned_gear(settings: Dictionary) -> Dictionary:
	var owned: Dictionary = {}
	var stored: Variant = settings.get(GEAR_KEY)
	if stored is Dictionary:
		for name_variant: Variant in (stored as Dictionary).keys():
			if bool((stored as Dictionary)[name_variant]):
				owned[String(name_variant)] = true
	# Legacy starmetal flags from before the ladder existed.
	if bool(settings.get("starmetal_blade", false)):
		owned["Starmetal Blade"] = true
	if bool(settings.get("starmetal_plate", false)):
		owned["Starmetal Plate"] = true
	return owned

static func grant(settings: Dictionary, gear_name: String) -> void:
	var stored: Dictionary = settings.get(GEAR_KEY, {}) as Dictionary if settings.get(GEAR_KEY) is Dictionary else {}
	stored[gear_name] = true
	settings[GEAR_KEY] = stored

static func best_in_slot(owned: Dictionary, slot: String) -> Dictionary:
	var best: Dictionary = {}
	var best_tier := -1
	for gear_name: String in GEAR_DEFS.keys():
		var def := GEAR_DEFS[gear_name] as Dictionary
		if String(def.get("slot", "")) != slot or not owned.has(gear_name):
			continue
		if int(def.get("tier", 0)) > best_tier:
			best_tier = int(def.get("tier", 0))
			best = def.duplicate()
			best["name"] = gear_name
	return best

## --- the forge --------------------------------------------------------------

## The first bar the furnace can pull from the pack, richest ore first.
static func smelt_option(inventory: Dictionary) -> Dictionary:
	for ore: String in SMELT_ORDER:
		var recipe := SMELT_DEFS[ore] as Dictionary
		if int(inventory.get(ore, 0)) >= int(recipe.get("count", 2)):
			return {"ore": ore, "bar": String(recipe.get("bar", "")), "count": int(recipe.get("count", 2))}
	return {}

static func can_afford_craft(def: Dictionary, inventory: Dictionary) -> bool:
	var costs := def.get("craft", {}) as Dictionary
	for item_variant: Variant in costs.keys():
		if int(inventory.get(String(item_variant), 0)) < int(costs[item_variant]):
			return false
	return true

## The next piece the anvil would make: first unowned, affordable entry
## in forge order.
static func forge_option(owned: Dictionary, inventory: Dictionary) -> Dictionary:
	for gear_name: String in FORGE_ORDER:
		if owned.has(gear_name):
			continue
		var def := GEAR_DEFS[gear_name] as Dictionary
		if can_afford_craft(def, inventory):
			var result := def.duplicate()
			result["name"] = gear_name
			return result
	return {}

## What the anvil wants next (for the "bring me..." message).
static func next_forge_goal(owned: Dictionary) -> Dictionary:
	for gear_name: String in FORGE_ORDER:
		if not owned.has(gear_name):
			var def := GEAR_DEFS[gear_name] as Dictionary
			var result := def.duplicate()
			result["name"] = gear_name
			return result
	return {}

static func craft_costs_text(def: Dictionary) -> String:
	var parts := PackedStringArray()
	var costs := def.get("craft", {}) as Dictionary
	for item_variant: Variant in costs.keys():
		parts.append("%d %s" % [int(costs[item_variant]), String(item_variant)])
	return ", ".join(parts)

## --- potions and buffs -------------------------------------------------------

static func total_game_hours(settings: Dictionary) -> float:
	var clock := settings.get("game_clock", {}) as Dictionary if settings.get("game_clock") is Dictionary else {}
	return float(maxi(1, int(clock.get("day", 1)))) * 24.0 + clampf(float(clock.get("hour", 8.0)), 0.0, 24.0)

static func active_buffs(settings: Dictionary, now_hours: float) -> Array[Dictionary]:
	var alive: Array[Dictionary] = []
	var stored: Variant = settings.get(BUFFS_KEY)
	if stored is Array:
		for buff_variant: Variant in (stored as Array):
			if buff_variant is Dictionary and float((buff_variant as Dictionary).get("until", 0.0)) > now_hours:
				alive.append(buff_variant as Dictionary)
	return alive

## Drinks a potion: returns {"heal": int} or {"buff": name}. The caller
## already removed the item from inventory.
static func drink(settings: Dictionary, potion_name: String, now_hours: float) -> Dictionary:
	var def := POTION_DEFS.get(potion_name, {}) as Dictionary
	if def.has("heal"):
		return {"heal": int(def.get("heal", 0))}
	var buffs := active_buffs(settings, now_hours)
	for index in range(buffs.size() - 1, -1, -1):
		if String(buffs[index].get("buff", "")) == String(def.get("buff", "")):
			buffs.remove_at(index)
	buffs.append({
		"buff": String(def.get("buff", "")),
		"until": now_hours + float(def.get("hours", 8.0)),
		"attack": int(def.get("attack", 0)),
		"hp": float(def.get("hp", 0.0)),
		"speed": float(def.get("speed", 0.0))
	})
	var plain: Array = []
	plain.assign(buffs)
	settings[BUFFS_KEY] = plain
	return {"buff": String(def.get("buff", ""))}

## --- enchanting -------------------------------------------------------------

static func stored_enchants(settings: Dictionary) -> Dictionary:
	var stored: Variant = settings.get(ENCHANTS_KEY)
	return (stored as Dictionary).duplicate() if stored is Dictionary else {}

## Reads a Runestone into an enchant. Prefers an empty slot; otherwise
## replaces the weaker of the two if the roll is stronger. Returns a
## line describing what happened.
static func apply_runestone(settings: Dictionary, rng: RandomNumberGenerator) -> String:
	var roll := ENCHANT_DEFS[rng.randi_range(0, ENCHANT_DEFS.size() - 1)] as Dictionary
	var target := String(roll.get("target", "weapon"))
	var enchants := stored_enchants(settings)
	var current := enchants.get(target, {}) as Dictionary
	var roll_power := int(roll.get("attack", 0)) * 3 + int(float(roll.get("hp", 0.0))) + int(float(roll.get("speed", 0.0)) * 30.0)
	var current_power := int(current.get("attack", 0)) * 3 + int(float(current.get("hp", 0.0))) + int(float(current.get("speed", 0.0)) * 30.0)
	if not current.is_empty() and current_power >= roll_power:
		return "The runestone flares %s, but your %s enchant holds stronger." % [String(roll.get("name", "")), String(current.get("name", ""))]
	enchants[target] = roll.duplicate()
	settings[ENCHANTS_KEY] = enchants
	return "The rune sinks into your %s: %s." % [target, String(roll.get("name", ""))]

## --- the resolved loadout ----------------------------------------------------

## Folds gear + set bonus + garb + carried trinkets + enchants + live
## buffs into one stats block. inventory drives trinkets and arrows.
static func resolve_loadout(settings: Dictionary, inventory: Dictionary) -> Dictionary:
	var owned := owned_gear(settings)
	var now_hours := total_game_hours(settings)
	var attack_bonus := 0
	var hp_bonus := 0.0
	var speed_bonus := 0.0
	var blade := best_in_slot(owned, "blade")
	var plate := best_in_slot(owned, "plate")
	var garb := best_in_slot(owned, "garb")
	attack_bonus += int(blade.get("attack", 0))
	hp_bonus += float(plate.get("hp", 0.0))
	hp_bonus += float(garb.get("hp", 0.0))
	var set_tier := 0
	if not blade.is_empty() and int(blade.get("tier", 0)) == int(plate.get("tier", -1)):
		set_tier = int(blade.get("tier", 0))
		attack_bonus += SET_BONUS_ATTACK
		hp_bonus += SET_BONUS_HP
	# Trinkets: the best two in the pack, ranked by rough power.
	var carried: Array[Dictionary] = []
	for trinket_name: String in TRINKET_DEFS.keys():
		if int(inventory.get(trinket_name, 0)) > 0:
			var def := (TRINKET_DEFS[trinket_name] as Dictionary).duplicate()
			def["name"] = trinket_name
			def["power"] = int(def.get("attack", 0)) * 3 + int(float(def.get("hp", 0.0))) + int(float(def.get("speed", 0.0)) * 30.0)
			carried.append(def)
	carried.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("power", 0)) > int(b.get("power", 0)))
	var worn: Array[String] = []
	for index in mini(TRINKET_SLOTS, carried.size()):
		attack_bonus += int(carried[index].get("attack", 0))
		hp_bonus += float(carried[index].get("hp", 0.0))
		speed_bonus += float(carried[index].get("speed", 0.0))
		worn.append(String(carried[index].get("name", "")))
	# Enchants.
	var enchants := stored_enchants(settings)
	var weapon_enchant := enchants.get("weapon", {}) as Dictionary
	var armor_enchant := enchants.get("armor", {}) as Dictionary
	attack_bonus += int(weapon_enchant.get("attack", 0))
	hp_bonus += float(armor_enchant.get("hp", 0.0))
	speed_bonus += float(armor_enchant.get("speed", 0.0))
	# Potion buffs still running.
	var buff_names: Array[String] = []
	for buff: Dictionary in active_buffs(settings, now_hours):
		attack_bonus += int(buff.get("attack", 0))
		hp_bonus += float(buff.get("hp", 0.0))
		speed_bonus += float(buff.get("speed", 0.0))
		buff_names.append(String(buff.get("buff", "")))
	var bow := best_in_slot(owned, "bow")
	if not bow.is_empty():
		bow["attack"] = int(bow.get("attack", 0)) + int(garb.get("bow_attack", 0))
	var staff := best_in_slot(owned, "staff")
	if not staff.is_empty():
		staff["attack"] = int(staff.get("attack", 0)) + int(garb.get("staff_attack", 0))
	var charm := best_in_slot(owned, "charm")
	if not charm.is_empty():
		charm["summon_attack"] = int(charm.get("summon_attack", 0)) + int(garb.get("summon_attack", 0))
	return {
		"attack_bonus": attack_bonus,
		"hp_bonus": hp_bonus,
		"speed_mult": 1.0 + speed_bonus,
		"blade": blade, "plate": plate, "garb": garb,
		"bow": bow, "staff": staff, "charm": charm,
		"set_tier": set_tier,
		"trinkets": worn,
		"buffs": buff_names
	}

## One HUD line: what you fight with and what still hums on you.
static func loadout_line(loadout: Dictionary, arrows: int) -> String:
	var parts := PackedStringArray()
	var blade := loadout.get("blade", {}) as Dictionary
	if not blade.is_empty():
		parts.append("⚔ %s" % String(blade.get("name", "")))
	var bow := loadout.get("bow", {}) as Dictionary
	if not bow.is_empty():
		parts.append("🏹 %s (%d)" % [String(bow.get("name", "")), arrows])
	var staff := loadout.get("staff", {}) as Dictionary
	if not staff.is_empty():
		parts.append("🔮 %s" % String(staff.get("name", "")))
	var plate := loadout.get("plate", {}) as Dictionary
	if not plate.is_empty():
		parts.append("🛡 %s" % String(plate.get("name", "")))
	if int(loadout.get("set_tier", 0)) > 0:
		parts.append("set!")
	var buffs := loadout.get("buffs", []) as Array
	if not buffs.is_empty():
		var buff_names: PackedStringArray = []
		for buff_variant: Variant in buffs:
			buff_names.append(String(buff_variant))
		parts.append("✨ %s" % ", ".join(buff_names))
	return " · ".join(parts)
