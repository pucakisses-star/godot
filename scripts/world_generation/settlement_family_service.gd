extends RefCounted
class_name SettlementFamilyService

## Kinship for the roster: adults pair into couples, the young are
## placed as their children, and a family shares one surname, one roof
## and (usually) one faith. Rolled from the scene's seeded rng right
## after identities, so the same seed always raises the same families.

## Age bands per race. Long-lived races stay "young" a long time.
const ADULT_AGE := {"Dwarf": 60, "Human": 22, "Gnome": 50, "Goblin": 16, "Kobold": 13}
const CHILD_AGE_MAX := {"Dwarf": 49, "Human": 19, "Gnome": 39, "Goblin": 12, "Kobold": 9}
const COUPLE_CHANCE := 0.6
const MAX_CHILDREN_PER_FAMILY := 3
const SHARED_FAITH_CHANCE := 0.8

## Mutates identities and home anchors in place; returns
## {"couples": int, "children_placed": int} for tests and logs.
static func build_families(npc_states: Array[Dictionary], kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var default_race := "Dwarf" if kind == "dwarf" else "Human"
	var used_names: Dictionary = {}
	for state: Dictionary in npc_states:
		used_names[String((state.get("identity", {}) as Dictionary).get("name", ""))] = true
	var adults_by_race: Dictionary = {}
	var youths: Array[int] = []
	for index in npc_states.size():
		var identity := npc_states[index].get("identity", {}) as Dictionary
		if identity.is_empty():
			continue
		var race := String(identity.get("race", default_race))
		var age := int(identity.get("age", 0))
		if age >= int(ADULT_AGE.get(race, 22)):
			var race_adults: Array = adults_by_race.get(race, [])
			race_adults.append(index)
			adults_by_race[race] = race_adults
		elif age <= int(CHILD_AGE_MAX.get(race, 19)):
			youths.append(index)
	_shuffle(youths, rng)

	# Pair adjacent adults into couples - within their own race.
	var families: Array[Dictionary] = []
	for race_variant: Variant in adults_by_race.keys():
		var race_pool: Array[int] = []
		for adult_variant: Variant in (adults_by_race[race_variant] as Array):
			race_pool.append(int(adult_variant))
		_shuffle(race_pool, rng)
		var adult_cursor := 0
		while adult_cursor + 1 < race_pool.size():
			if rng.randf() >= COUPLE_CHANCE:
				adult_cursor += 1
				continue
			var first := npc_states[race_pool[adult_cursor]]
			var second := npc_states[race_pool[adult_cursor + 1]]
			adult_cursor += 2
			var family_clan := String((first.get("identity", {}) as Dictionary).get("clan", ""))
			var family_faith := String((first.get("identity", {}) as Dictionary).get("faith", ""))
			_adopt_surname(second, family_clan, used_names)
			if rng.randf() < SHARED_FAITH_CHANCE and not family_faith.is_empty():
				(second.get("identity", {}) as Dictionary)["faith"] = family_faith
			var first_identity := first.get("identity", {}) as Dictionary
			var second_identity := second.get("identity", {}) as Dictionary
			first_identity["spouse"] = String(second_identity.get("name", ""))
			second_identity["spouse"] = String(first_identity.get("name", ""))
			# One roof: the second partner moves in.
			second["home_anchor"] = first.get("home_anchor", second.get("home_anchor", Vector2i.ZERO))
			families.append({"parents": [first, second], "clan": family_clan, "faith": family_faith, "race": String(race_variant)})

	# Children join families round-robin until every youth has parents
	# or every family is full.
	var children_placed := 0
	var family_cursor := 0
	for youth_index: int in youths:
		if families.is_empty():
			break
		var placed := false
		for _attempt in families.size():
			var family := families[family_cursor % families.size()]
			family_cursor += 1
			var parents := family.get("parents", []) as Array
			var siblings := family.get("children", []) as Array
			if siblings.size() >= MAX_CHILDREN_PER_FAMILY:
				continue
			var child := npc_states[youth_index]
			var child_race := String((child.get("identity", {}) as Dictionary).get("race", default_race))
			if child_race != String(family.get("race", default_race)):
				continue
			_adopt_surname(child, String(family.get("clan", "")), used_names)
			var child_identity := child.get("identity", {}) as Dictionary
			if rng.randf() < SHARED_FAITH_CHANCE and not String(family.get("faith", "")).is_empty():
				child_identity["faith"] = String(family.get("faith", ""))
			var parent_names: Array[String] = []
			for parent_variant: Variant in parents:
				var parent := parent_variant as Dictionary
				var parent_identity := parent.get("identity", {}) as Dictionary
				parent_names.append(String(parent_identity.get("name", "")))
				var their_children := parent_identity.get("children", []) as Array
				their_children.append(String(child_identity.get("name", "")))
				parent_identity["children"] = their_children
			child_identity["parents"] = parent_names
			var first_parent := parents[0] as Dictionary
			child["home_anchor"] = first_parent.get("home_anchor", child.get("home_anchor", Vector2i.ZERO))
			siblings.append(child)
			family["children"] = siblings
			children_placed += 1
			placed = true
			break
		if not placed:
			continue
	return {"couples": families.size(), "children_placed": children_placed}

## Rewrites clan/surname and the derived full name on state + identity.
## Keeps the old surname when adoption would duplicate an existing name
## (references are by name, so duplicates would tangle the census).
static func _adopt_surname(state: Dictionary, family_clan: String, used_names: Dictionary) -> void:
	if family_clan.is_empty():
		return
	var identity := state.get("identity", {}) as Dictionary
	var new_name := "%s %s" % [String(identity.get("first_name", "Somebody")), family_clan]
	var old_name := String(identity.get("name", ""))
	if new_name == old_name:
		identity["clan"] = family_clan
		return
	if used_names.has(new_name):
		return
	used_names.erase(old_name)
	used_names[new_name] = true
	identity["clan"] = family_clan
	identity["name"] = new_name
	state["npc_name"] = new_name

static func _shuffle(values: Array[int], rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := values[i]
		values[i] = values[j]
		values[j] = swap
