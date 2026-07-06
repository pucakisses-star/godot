extends RefCounted
class_name GearService

## The armory: the ore-to-gear ladder, weapon classes, armor, trinkets,
## garbs, enchants and potion buffs - and the paper-doll equipment model
## that folds a walker's loadout into the stats the scenes use.
##
## Equipment lives in world settings under "player_equipment": a dict of
## slot -> item name. Twelve slots, arranged like the inventory screen:
##   combat:  weapon / bow / staff / charm
##   armor:   head / chest / legs / feet
##   attire:  clothing / amulet / ring / accessory
## Unequipped gear sits in the ordinary backpack as items. Enchants live
## under "player_enchants" (weapon/armor), timed buffs under
## "player_buffs" with expiry in total game hours.

const GEAR_KEY := "player_gear"
const EQUIPMENT_KEY := "player_equipment"
const ENCHANTS_KEY := "player_enchants"
const BUFFS_KEY := "player_buffs"

## Slot layout for the inventory screen: three columns of four.
const EQUIP_SLOT_GRID := [
	["weapon", "head", "clothing"],
	["bow", "chest", "amulet"],
	["staff", "legs", "ring"],
	["charm", "feet", "accessory"]
]
const EQUIP_SLOT_LABELS := {
	"weapon": "⚔", "bow": "🏹", "staff": "🔮", "charm": "🐾",
	"head": "🪖", "chest": "🛡", "legs": "👖", "feet": "🥾",
	"clothing": "👕", "amulet": "📿", "ring": "💍", "accessory": "✨"
}

## Forged pieces. Tier orders the ladder; a full matched armor tier
## (head+chest+legs+feet) grants the set bonus.
const GEAR_DEFS := {
	"Copper Blade": {"slot": "weapon", "tier": 1, "attack": 1, "craft": {"Copper Ingot": 2}},
	"Iron Blade": {"slot": "weapon", "tier": 2, "attack": 2, "craft": {"Iron Ingot": 2}},
	"Gold Blade": {"slot": "weapon", "tier": 3, "attack": 3, "craft": {"Gold Ingot": 2}},
	"Starmetal Blade": {"slot": "weapon", "tier": 4, "attack": 5, "craft": {"Starmetal Bar": 3}},
	"Copper Helm": {"slot": "head", "tier": 1, "hp": 2.0, "craft": {"Copper Ingot": 2}},
	"Iron Helm": {"slot": "head", "tier": 2, "hp": 4.0, "craft": {"Iron Ingot": 2}},
	"Gold Helm": {"slot": "head", "tier": 3, "hp": 6.0, "craft": {"Gold Ingot": 2}},
	"Starmetal Helm": {"slot": "head", "tier": 4, "hp": 9.0, "craft": {"Starmetal Bar": 2}},
	"Copper Plate": {"slot": "chest", "tier": 1, "hp": 4.0, "craft": {"Copper Ingot": 3}},
	"Iron Plate": {"slot": "chest", "tier": 2, "hp": 8.0, "craft": {"Iron Ingot": 3}},
	"Gold Plate": {"slot": "chest", "tier": 3, "hp": 12.0, "craft": {"Gold Ingot": 3}},
	"Starmetal Plate": {"slot": "chest", "tier": 4, "hp": 18.0, "craft": {"Starmetal Bar": 3}},
	"Copper Greaves": {"slot": "legs", "tier": 1, "hp": 3.0, "craft": {"Copper Ingot": 2}},
	"Iron Greaves": {"slot": "legs", "tier": 2, "hp": 6.0, "craft": {"Iron Ingot": 2}},
	"Gold Greaves": {"slot": "legs", "tier": 3, "hp": 9.0, "craft": {"Gold Ingot": 2}},
	"Starmetal Greaves": {"slot": "legs", "tier": 4, "hp": 13.0, "craft": {"Starmetal Bar": 2}},
	"Copper Sabatons": {"slot": "feet", "tier": 1, "hp": 1.0, "speed": 0.02, "craft": {"Copper Ingot": 2}},
	"Iron Sabatons": {"slot": "feet", "tier": 2, "hp": 2.0, "speed": 0.04, "craft": {"Iron Ingot": 2}},
	"Gold Sabatons": {"slot": "feet", "tier": 3, "hp": 4.0, "speed": 0.06, "craft": {"Gold Ingot": 2}},
	"Starmetal Sabatons": {"slot": "feet", "tier": 4, "hp": 6.0, "speed": 0.09, "craft": {"Starmetal Bar": 2}},
	"Short Bow": {"slot": "bow", "tier": 1, "range": 4, "attack": 0, "craft": {"Timber": 3, "Copper Ingot": 1}},
	"War Bow": {"slot": "bow", "tier": 2, "range": 6, "attack": 2, "craft": {"Timber": 4, "Iron Ingot": 2}},
	"Oak Staff": {"slot": "staff", "tier": 1, "attack": 1, "radius": 1, "cooldown": 9.0, "craft": {"Timber": 4, "Gem Shard": 1}},
	"Runed Staff": {"slot": "staff", "tier": 2, "attack": 3, "radius": 2, "cooldown": 7.0, "craft": {"Timber": 4, "Gold Ingot": 2, "Gem Shard": 2}},
	"Beast Charm": {"slot": "charm", "tier": 1, "summon_attack": 2, "craft": {"Lizard Scale": 2, "Orcish Tooth": 2, "Leather Strap": 1}},
	"Hunter's Garb": {"slot": "clothing", "tier": 1, "hp": 3.0, "bow_attack": 2, "craft": {"Cured Leather": 2, "Timber": 2}},
	"Warcaster's Robe": {"slot": "clothing", "tier": 1, "hp": 3.0, "staff_attack": 2, "craft": {"Bolt of Cloth": 2, "Gem Shard": 2}},
	"Beastmaster's Cloak": {"slot": "clothing", "tier": 1, "hp": 3.0, "summon_attack": 2, "craft": {"Cured Leather": 2, "Skein of Wool": 2}}
}

## Found and bought finery: each claims one attire slot.
const TRINKET_DEFS := {
	"Wolf Fang Charm": {"slot": "accessory", "attack": 1},
	"Hearthstone Amulet": {"slot": "amulet", "hp": 6.0},
	"Fleetfoot Boots": {"slot": "feet", "speed": 0.15},
	"Warding Ring": {"slot": "ring", "attack": 1, "hp": 3.0}
}

## The order the anvil offers work in: a weapon first, armor over the
## vitals, the class tools, then the deeper rungs.
const FORGE_ORDER := [
	"Copper Blade", "Copper Plate", "Copper Helm", "Iron Blade", "Iron Plate",
	"Short Bow", "Oak Staff", "Beast Charm",
	"Copper Greaves", "Copper Sabatons", "Iron Helm", "Iron Greaves", "Iron Sabatons",
	"Gold Blade", "Gold Plate", "War Bow", "Runed Staff",
	"Hunter's Garb", "Warcaster's Robe", "Beastmaster's Cloak",
	"Gold Helm", "Gold Greaves", "Gold Sabatons",
	"Starmetal Blade", "Starmetal Plate", "Starmetal Helm", "Starmetal Greaves", "Starmetal Sabatons"
]

## Weapon+chest of one tier keeps the old set bonus; a full four-piece
## armor tier adds the greater one on top.
const SET_BONUS_ATTACK := 1
const SET_BONUS_HP := 4.0
const ARMOR_SET_ATTACK := 2
const ARMOR_SET_HP := 8.0

## Ore into bars at a lit furnace.
const SMELT_DEFS := {
	"Copper Ore": {"bar": "Copper Ingot", "count": 2},
	"Iron Ore": {"bar": "Iron Ingot", "count": 2},
	"Gold Nugget": {"bar": "Gold Ingot", "count": 2},
	"Starmetal Ore": {"bar": "Starmetal Bar", "count": 2}
}
const SMELT_ORDER := ["Starmetal Ore", "Gold Nugget", "Iron Ore", "Copper Ore"]

## Potions: brewed over a clay pot from herbs and the hunt, or bought.
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

## --- the equipment model ----------------------------------------------------

static func gear_def(item_name: String) -> Dictionary:
	if GEAR_DEFS.has(item_name):
		return GEAR_DEFS[item_name] as Dictionary
	if TRINKET_DEFS.has(item_name):
		return TRINKET_DEFS[item_name] as Dictionary
	return {}

## The slot an item buckles into, or "" for ordinary cargo.
static func equip_slot_for(item_name: String) -> String:
	return String(gear_def(item_name).get("slot", ""))

static func equipment(settings: Dictionary) -> Dictionary:
	var stored: Variant = settings.get(EQUIPMENT_KEY)
	return (stored as Dictionary) if stored is Dictionary else {}

static func equipped_in(settings: Dictionary, slot: String) -> String:
	return String(equipment(settings).get(slot, ""))

## Buckles an item from the pack into its slot; whatever hung there
## drops back into the pack. Returns the slot used, or "" if the item
## isn't wearable or isn't carried.
static func equip(settings: Dictionary, inventory: Dictionary, item_name: String) -> String:
	var slot := equip_slot_for(item_name)
	if slot.is_empty() or int(inventory.get(item_name, 0)) < 1:
		return ""
	var worn := equipment(settings)
	var previous := String(worn.get(slot, ""))
	inventory[item_name] = int(inventory.get(item_name, 0)) - 1
	if int(inventory.get(item_name, 0)) <= 0:
		inventory.erase(item_name)
	if not previous.is_empty():
		inventory[previous] = int(inventory.get(previous, 0)) + 1
	worn[slot] = item_name
	settings[EQUIPMENT_KEY] = worn
	return slot

## Unbuckles a slot back into the pack. Returns the item freed, or "".
static func unequip(settings: Dictionary, inventory: Dictionary, slot: String) -> String:
	var worn := equipment(settings)
	var item_name := String(worn.get(slot, ""))
	if item_name.is_empty():
		return ""
	worn.erase(slot)
	settings[EQUIPMENT_KEY] = worn
	inventory[item_name] = int(inventory.get(item_name, 0)) + 1
	return item_name

## Everything the walker owns of a slot's gear - worn or packed - so
## the anvil never forges duplicates.
static func owned_gear(settings: Dictionary, inventory: Dictionary = {}) -> Dictionary:
	var owned: Dictionary = {}
	for item_variant: Variant in equipment(settings).values():
		owned[String(item_variant)] = true
	for item_variant: Variant in inventory.keys():
		if not equip_slot_for(String(item_variant)).is_empty():
			owned[String(item_variant)] = true
	# Legacy stores from before the paper doll existed.
	var legacy: Variant = settings.get(GEAR_KEY)
	if legacy is Dictionary:
		for name_variant: Variant in (legacy as Dictionary).keys():
			if bool((legacy as Dictionary)[name_variant]):
				owned[String(name_variant)] = true
	if bool(settings.get("starmetal_blade", false)):
		owned["Starmetal Blade"] = true
	if bool(settings.get("starmetal_plate", false)):
		owned["Starmetal Plate"] = true
	return owned

## Grants a freshly forged piece: into the pack, and straight onto an
## empty slot when there is one.
static func grant(settings: Dictionary, inventory: Dictionary, item_name: String) -> void:
	inventory[item_name] = int(inventory.get(item_name, 0)) + 1
	var slot := equip_slot_for(item_name)
	if not slot.is_empty() and equipped_in(settings, slot).is_empty():
		equip(settings, inventory, item_name)

## One-time upgrade of old saves: ownership flags become real items,
## then the best of each slot buckles on. Returns true when it changed
## anything (caller should persist).
static func ensure_equipment_migrated(settings: Dictionary, inventory: Dictionary) -> bool:
	if settings.get(EQUIPMENT_KEY) is Dictionary:
		return false
	var owned := owned_gear(settings, {})
	for gear_name: String in owned.keys():
		if not gear_def(gear_name).is_empty():
			inventory[gear_name] = maxi(int(inventory.get(gear_name, 0)), 1)
	settings[EQUIPMENT_KEY] = {}
	settings.erase(GEAR_KEY)
	settings.erase("starmetal_blade")
	settings.erase("starmetal_plate")
	auto_equip_best(settings, inventory)
	return true

## Fills every empty slot with the strongest carried candidate.
static func auto_equip_best(settings: Dictionary, inventory: Dictionary) -> void:
	for row_variant: Variant in EQUIP_SLOT_GRID:
		for slot_variant: Variant in (row_variant as Array):
			var slot := String(slot_variant)
			if not equipped_in(settings, slot).is_empty():
				continue
			var best_name := ""
			var best_rank := -1
			for item_variant: Variant in inventory.keys():
				var item_name := String(item_variant)
				var def := gear_def(item_name)
				if String(def.get("slot", "")) != slot:
					continue
				var rank := int(def.get("tier", 0)) * 100 + int(def.get("attack", 0)) * 3 + int(float(def.get("hp", 0.0)))
				if rank > best_rank:
					best_rank = rank
					best_name = item_name
			if not best_name.is_empty():
				equip(settings, inventory, best_name)

## --- the forge --------------------------------------------------------------

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

## Folds worn equipment + set bonuses + enchants + live buffs into one
## stats block. Reads legacy flag stores through a virtual equipment
## view until migration persists the real one.
static func resolve_loadout(settings: Dictionary, inventory: Dictionary) -> Dictionary:
	var worn: Dictionary = equipment(settings)
	if not (settings.get(EQUIPMENT_KEY) is Dictionary):
		# Old save mid-flight: wear the best of the flag-store virtually.
		var virtual_settings := {EQUIPMENT_KEY: {}}
		var virtual_inventory := {}
		for gear_name: String in owned_gear(settings, inventory).keys():
			if not gear_def(gear_name).is_empty():
				virtual_inventory[gear_name] = 1
		auto_equip_best(virtual_settings, virtual_inventory)
		worn = equipment(virtual_settings)
	var now_hours := total_game_hours(settings)
	var attack_bonus := 0
	var hp_bonus := 0.0
	var speed_bonus := 0.0
	var pieces: Dictionary = {}
	for slot_variant: Variant in worn.keys():
		var item_name := String(worn[slot_variant])
		var def := gear_def(item_name)
		if def.is_empty():
			continue
		var piece := def.duplicate()
		piece["name"] = item_name
		var slot_name := String(slot_variant)
		pieces[slot_name] = piece
		# Bow and staff damage applies at shot time, not to the base swing.
		if slot_name == "weapon" or slot_name == "amulet" or slot_name == "ring" or slot_name == "accessory":
			attack_bonus += int(def.get("attack", 0))
		hp_bonus += float(def.get("hp", 0.0))
		speed_bonus += float(def.get("speed", 0.0))
	var weapon := pieces.get("weapon", {}) as Dictionary
	var chest := pieces.get("chest", {}) as Dictionary
	var garb := pieces.get("clothing", {}) as Dictionary
	# Weapon+chest tier match: the old set bonus.
	var set_tier := 0
	if not weapon.is_empty() and int(weapon.get("tier", 0)) == int(chest.get("tier", -1)):
		set_tier = int(weapon.get("tier", 0))
		attack_bonus += SET_BONUS_ATTACK
		hp_bonus += SET_BONUS_HP
	# Full armor tier: the greater one.
	var armor_set_tier := 0
	var head_tier := int((pieces.get("head", {}) as Dictionary).get("tier", -1))
	if head_tier > 0 and head_tier == int(chest.get("tier", -2)) and head_tier == int((pieces.get("legs", {}) as Dictionary).get("tier", -3)) and head_tier == int((pieces.get("feet", {}) as Dictionary).get("tier", -4)):
		armor_set_tier = head_tier
		attack_bonus += ARMOR_SET_ATTACK
		hp_bonus += ARMOR_SET_HP
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
	var bow := pieces.get("bow", {}) as Dictionary
	if not bow.is_empty():
		bow["attack"] = int(bow.get("attack", 0)) + int(garb.get("bow_attack", 0))
	var staff := pieces.get("staff", {}) as Dictionary
	if not staff.is_empty():
		staff["attack"] = int(staff.get("attack", 0)) + int(garb.get("staff_attack", 0))
	var charm := pieces.get("charm", {}) as Dictionary
	if not charm.is_empty():
		charm["summon_attack"] = int(charm.get("summon_attack", 0)) + int(garb.get("summon_attack", 0))
	var worn_names: Array[String] = []
	for slot_variant: Variant in worn.keys():
		worn_names.append(String(worn[slot_variant]))
	return {
		"attack_bonus": attack_bonus,
		"hp_bonus": hp_bonus,
		"speed_mult": 1.0 + speed_bonus,
		"blade": weapon, "plate": chest, "garb": garb,
		"bow": bow, "staff": staff, "charm": charm,
		"pieces": pieces,
		"set_tier": set_tier,
		"armor_set_tier": armor_set_tier,
		"trinkets": worn_names,
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
	if int(loadout.get("armor_set_tier", 0)) > 0:
		parts.append("full set!")
	elif int(loadout.get("set_tier", 0)) > 0:
		parts.append("set!")
	var buffs := loadout.get("buffs", []) as Array
	if not buffs.is_empty():
		var buff_names: PackedStringArray = []
		for buff_variant: Variant in buffs:
			buff_names.append(String(buff_variant))
		parts.append("✨ %s" % ", ".join(buff_names))
	return " · ".join(parts)

## A tooltip block for a piece of gear: stats then flavor.
static func gear_tooltip(item_name: String) -> String:
	var def := gear_def(item_name)
	if def.is_empty():
		return ""
	var lines: PackedStringArray = []
	lines.append(item_name)
	var stat_parts := PackedStringArray()
	if int(def.get("attack", 0)) != 0:
		stat_parts.append("⚔ +%d" % int(def.get("attack", 0)))
	if float(def.get("hp", 0.0)) != 0.0:
		stat_parts.append("❤ +%d" % int(float(def.get("hp", 0.0))))
	if float(def.get("speed", 0.0)) != 0.0:
		stat_parts.append("👟 +%d%%" % int(float(def.get("speed", 0.0)) * 100.0))
	if def.has("range"):
		stat_parts.append("range %d" % int(def.get("range", 0)))
	if def.has("radius"):
		stat_parts.append("burst %d" % int(def.get("radius", 0)))
	if def.has("summon_attack"):
		stat_parts.append("pet ⚔ %d" % int(def.get("summon_attack", 0)))
	if int(def.get("tier", 0)) > 0:
		stat_parts.append("tier %d" % int(def.get("tier", 0)))
	if not stat_parts.is_empty():
		lines.append("  ".join(stat_parts))
	return "\n".join(lines)
