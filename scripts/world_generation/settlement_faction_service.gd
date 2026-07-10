extends RefCounted
class_name SettlementFactionService

## Fantasy Town Generator-style settlement factions: every hold and town
## rolls a handful of guilds, compacts and cults from its seeded rng.
## Each faction carries a goal, a preferred way of pursuing it, a
## secrecy flag, a meeting place and hour, and members recruited from
## the settlement's existing NPC roster (weighted toward matching
## professions). Open factions show up in the sidebar, tooltips and
## dialogue; secret ones only leak as oblique rumors - and as figures
## slipping toward the same door late at night.

const MEETING_DURATION_HOURS := 2.0

## Archetype fields: name_templates (%s = flavor word), goals, methods,
## secret, professions (identity profession strings that recruit at high
## weight), meeting_types (building types in preference order),
## meeting_hour, events (%s = faction name).
const DWARF_ARCHETYPES := [
	{
		"id": "miners_brotherhood",
		"name_templates": ["Brotherhood of the %s Pick", "The %s Delvers"],
		"goals": ["to claim every vein below the third deep", "to seat a miner on the council"],
		"methods": ["hard bargains and harder shifts", "packed halls and loud oaths"],
		"secret": false,
		"professions": ["Miner"],
		"meeting_types": ["miners_guild", "guild_hall", "tavern"],
		"meeting_hour": 19.0,
		"events": [
			"Word spreads: the %s bought out every pick and lantern in the market.",
			"The %s posted a bounty on the deep tunnels' worst crawler.",
			"Chants echo up the shafts - the %s is voting on something big."
		]
	},
	{
		"id": "brewers_consortium",
		"name_templates": ["The %s Consortium", "The %s Cask Ring"],
		"goals": ["to corner the hold's ale trade", "to brew a cask worthy of the High King"],
		"methods": ["honest coin and free samples", "quiet deals over loud toasts"],
		"secret": false,
		"professions": ["Brewer"],
		"meeting_types": ["brewery", "tavern", "guild_hall"],
		"meeting_hour": 20.0,
		"events": [
			"The %s undercut the grain price again - the bakers are furious.",
			"A new dark stout from the %s has half the hold nursing headaches.",
			"The %s is hiring haulers; casks move under guard now."
		]
	},
	{
		"id": "runecarver_lodge",
		"name_templates": ["The %s Lodge", "Circle of the %s Rune"],
		"goals": ["to recover the lost runes of the founders", "to ward every gate in the hold"],
		"methods": ["patient study and older favors", "sealed letters and salted archives"],
		"secret": false,
		"professions": ["Runescribe", "Hold Elder"],
		"meeting_types": ["runesmith_sanctum", "archives", "enchanting_study", "guild_hall"],
		"meeting_hour": 18.0,
		"events": [
			"The %s paid a fortune for a single cracked rune-stone.",
			"New wardings glow faintly on the gates - the %s's work.",
			"An apprentice of the %s was caught copying forbidden pages."
		]
	},
	{
		"id": "anvil_compact",
		"name_templates": ["The %s Compact", "Order of the %s Anvil"],
		"goals": ["to arm the hold against what stirs below", "to make this forge's mark famous across the realm"],
		"methods": ["masterwork and no shortcuts", "contracts sworn on iron"],
		"secret": false,
		"professions": ["Smith", "Goldsmith"],
		"meeting_types": ["forge", "smeltery", "armory", "guild_hall"],
		"meeting_hour": 17.0,
		"events": [
			"The %s unveiled a blade that hums like the deep rock.",
			"The %s refused an outsider's contract - pride or prudence, none agree.",
			"Forge-smoke ran blue all night; the %s is smelting something strange."
		]
	},
	{
		"id": "deep_star_cult",
		"name_templates": ["Cult of the %s Star", "The %s Communion"],
		"goals": ["to wake what sleeps beneath the starmetal", "to read the future in the deep veins"],
		"methods": ["midnight rites and borrowed keys", "whispers, candles, and patience"],
		"secret": true,
		"professions": [],
		"meeting_types": ["temple", "archives", "storage_warehouse", "warehouse"],
		"meeting_hour": 23.0,
		"events": [
			"Chalk sigils appeared on the deep stair overnight. Scrubbed by noon.",
			"A miner swears the rock hummed back at him. He won't go below again.",
			"Candle stubs and cold incense were found behind the %s door."
		]
	},
	{
		"id": "silent_ledger",
		"name_templates": ["The Silent %s", "The %s Ledger"],
		"goals": ["to move goods the assayers never see", "to own a debt in every district"],
		"methods": ["false manifests and honest smiles", "coin lent kindly, collected coldly"],
		"secret": true,
		"professions": ["Goldsmith"],
		"meeting_types": ["storage_warehouse", "warehouse", "bank_vaults", "tavern"],
		"meeting_hour": 22.0,
		"events": [
			"A warehouse tally came up short again; the clerk just shrugged.",
			"Someone paid off the ferryman's whole debt in unmarked coin.",
			"Two crates left the gates at midnight with no seal and no questions."
		]
	}
]

const TOWN_ARCHETYPES := [
	{
		"id": "harvest_guild",
		"name_templates": ["The %s Harvest Guild", "The %s Furrow"],
		"goals": ["to fix a fair grain price for good", "to break the millers' hold on the town"],
		"methods": ["full barns and firm handshakes", "petitions read loudly at market"],
		"secret": false,
		"professions": ["Farmer"],
		"meeting_types": ["guild_hall", "town_hall", "tavern"],
		"meeting_hour": 18.0,
		"events": [
			"The %s pledged seed-corn to every smallholder this spring.",
			"The %s marched a petition to the town hall, mud boots and all.",
			"Granary doors got new locks - the %s trusts no one this year."
		]
	},
	{
		"id": "craftsmens_circle",
		"name_templates": ["The %s Circle", "The Worshipful %s"],
		"goals": ["to seat a craftsman on the council", "to drive shoddy outland goods from the market"],
		"methods": ["guild marks and closed ranks", "apprenticeships promised and withheld"],
		"secret": false,
		"professions": ["Blacksmith", "Merchant"],
		"meeting_types": ["guild_hall", "workshop", "smithy", "tavern"],
		"meeting_hour": 19.0,
		"events": [
			"The %s stamped its mark on half the market stalls this week.",
			"A peddler's cart was turned back at the gate - the %s's doing, folk say.",
			"The %s took on six new apprentices in one day."
		]
	},
	{
		"id": "wardens_of_the_lamp",
		"name_templates": ["Wardens of the %s Lamp", "The %s Watch"],
		"goals": ["to see every lane lit and every gate manned", "to root out whoever robs the night carts"],
		"methods": ["rounds walked twice and favors remembered", "quiet questions in loud taverns"],
		"secret": false,
		"professions": ["Town Guard"],
		"meeting_types": ["guardhouse", "town_hall", "tavern"],
		"meeting_hour": 21.0,
		"events": [
			"The %s hung new lamps along the river lane.",
			"The %s dragged a cart-robber to the stocks before dawn.",
			"Extra watch on the walls tonight - the %s smells trouble."
		]
	},
	{
		"id": "pale_moon_cult",
		"name_templates": ["Cult of the %s Moon", "The %s Vigil"],
		"goals": ["to call something down from the pale sky", "to keep an old promise the town forgot"],
		"methods": ["hymns hummed under breath", "gifts left at thresholds by night"],
		"secret": true,
		"professions": ["Cleric"],
		"meeting_types": ["chapel", "warehouse", "stable"],
		"meeting_hour": 23.0,
		"events": [
			"White petals were scattered on every doorstep facing the moonrise.",
			"The chapel candles burned all night, though the door was locked.",
			"A shepherd heard singing from the old %s after midnight."
		]
	},
	{
		"id": "river_ring",
		"name_templates": ["The %s Ring", "The Low %s"],
		"goals": ["to move untaxed goods up the river", "to buy the harbormaster twice over"],
		"methods": ["night barges and bought silence", "debts collected in favors"],
		"secret": true,
		"professions": ["Merchant"],
		"meeting_types": ["warehouse", "stable", "tavern"],
		"meeting_hour": 22.0,
		"events": [
			"A barge slipped in before dawn riding low, and left riding high.",
			"The toll ledger lost a page. Nobody is looking very hard for it.",
			"Someone bought every lantern-hood in the chandlery. All of them."
		]
	}
]

const FLAVOR_WORDS: Array[String] = [
	"Iron", "Amber", "Granite", "Ember", "Silver", "Oaken", "Deep",
	"Golden", "Old", "Crimson", "Quiet", "Broken", "First", "Grey", "Salt"
]

## Rolls the settlement's factions. kind is "dwarf" or "town";
## building_cells_by_type maps building type -> Array of cells.
static func generate_factions(kind: String, population: int, building_cells_by_type: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var pool := (DWARF_ARCHETYPES if kind == "dwarf" else TOWN_ARCHETYPES).duplicate()
	var count := clampi(2 + population / 900, 2, 4)
	var factions: Array[Dictionary] = []
	var picked_secret := false
	while factions.size() < count and not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		# The last slot goes to a secret society when none was drawn yet.
		if factions.size() == count - 1 and not picked_secret:
			for secret_index in pool.size():
				if bool((pool[secret_index] as Dictionary).get("secret", false)):
					index = secret_index
					break
		var archetype := pool[index] as Dictionary
		pool.remove_at(index)
		var meeting := _pick_meeting_cell(archetype, building_cells_by_type, rng)
		if meeting.is_empty():
			continue
		var templates := archetype.get("name_templates", ["The %s Circle"]) as Array
		var goals := archetype.get("goals", []) as Array
		var methods := archetype.get("methods", []) as Array
		var flavor := FLAVOR_WORDS[rng.randi_range(0, FLAVOR_WORDS.size() - 1)]
		var name_template := String(templates[rng.randi_range(0, templates.size() - 1)])
		factions.append({
			"id": String(archetype.get("id", "faction")),
			"name": name_template % flavor if name_template.contains("%s") else name_template,
			"goal": String(goals[rng.randi_range(0, goals.size() - 1)]) if not goals.is_empty() else "to endure",
			"method": String(methods[rng.randi_range(0, methods.size() - 1)]) if not methods.is_empty() else "quietly",
			"secret": bool(archetype.get("secret", false)),
			"professions": archetype.get("professions", []) as Array,
			"meeting_cell": meeting.get("cell", Vector2i.ZERO) as Vector2i,
			"meeting_building": String(meeting.get("building_type", "")),
			"meeting_hour": float(archetype.get("meeting_hour", 20.0)) + rng.randf_range(-0.5, 0.5),
			"events": archetype.get("events", []) as Array,
			"members": [] as Array[String],
			"leader": ""
		})
		if bool(archetype.get("secret", false)):
			picked_secret = true
	return factions

## A settlement that remembers the chronicle — a battle lost, a hold that
## fell nearby, a beast still at large — turns one open faction's agenda
## toward that grudge ("to see the green dragon Vorgash slain"). Goals come
## from WorldChronicleService.history_agenda_goals via the world settings.
static func apply_history_agenda(factions: Array[Dictionary], history_goals: Array[String], rng: RandomNumberGenerator) -> void:
	if factions.is_empty() or history_goals.is_empty():
		return
	var open_indices: Array[int] = []
	for faction_index: int in factions.size():
		if not bool(factions[faction_index].get("secret", false)):
			open_indices.append(faction_index)
	if open_indices.is_empty():
		return
	var target_index := open_indices[rng.randi_range(0, open_indices.size() - 1)]
	factions[target_index]["goal"] = history_goals[rng.randi_range(0, history_goals.size() - 1)]
	factions[target_index]["historic_goal"] = true

static func _pick_meeting_cell(archetype: Dictionary, building_cells_by_type: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	for type_variant: Variant in (archetype.get("meeting_types", []) as Array):
		var cells := building_cells_by_type.get(String(type_variant), []) as Array
		if cells.is_empty():
			continue
		return {"cell": cells[rng.randi_range(0, cells.size() - 1)] as Vector2i, "building_type": String(type_variant)}
	# A young settlement may lack the proper hall; any roof does for now.
	var available_types := building_cells_by_type.keys()
	if not available_types.is_empty():
		var fallback_type := String(available_types[rng.randi_range(0, available_types.size() - 1)])
		var fallback_cells := building_cells_by_type.get(fallback_type, []) as Array
		if not fallback_cells.is_empty():
			return {"cell": fallback_cells[rng.randi_range(0, fallback_cells.size() - 1)] as Vector2i, "building_type": fallback_type}
	return {}

## Recruits members from the spawned NPC roster. Matching professions
## join eagerly, anyone may drift in at low odds, and each NPC swears to
## at most one faction. The first recruit with the most years leads.
##
## Settlement interiors fragment into walkable pockets, so a single
## meeting cell can be unreachable for half the roster. Every member
## therefore gathers at the cell of THEIR OWN walkable component that
## lies closest to the meeting hall: neighbors of the hall crowd its
## door, members from cut-off quarters hold a chapter corner as near to
## it as their streets allow. The scheduler can then always path there.
## npc states gain: faction_id/name/secret, faction_meeting_hour,
## faction_meeting_anchor.
static func assign_members(factions: Array[Dictionary], npc_states: Array[Dictionary], is_walkable: Callable, rng: RandomNumberGenerator) -> void:
	if factions.is_empty():
		return
	var capacity := clampi(npc_states.size() / maxi(factions.size(), 1), 3, 12)
	var leader_age: Array[int] = []
	leader_age.resize(factions.size())
	leader_age.fill(-1)
	var component_of_cell: Dictionary = {}
	var component_cells: Array = []
	for state: Dictionary in npc_states:
		var identity := state.get("identity", {}) as Dictionary
		if identity.is_empty():
			continue
		var home_cell := state.get("cell", Vector2i.ZERO) as Vector2i
		var component_index := _component_for(home_cell, component_of_cell, component_cells, is_walkable)
		if component_index < 0:
			continue
		var profession := String(identity.get("profession", ""))
		var start := rng.randi_range(0, factions.size() - 1)
		for offset in factions.size():
			var faction_index := (start + offset) % factions.size()
			var faction := factions[faction_index]
			if (faction.get("members", []) as Array).size() >= capacity:
				continue
			var professions := faction.get("professions", []) as Array
			var chance := 0.6 if professions.has(profession) else (0.10 if bool(faction.get("secret", false)) else 0.06)
			if rng.randf() >= chance:
				continue
			var anchor := _component_anchor(faction, component_index, component_cells)
			if anchor.x == 2147483647:
				continue
			var member_name := String(identity.get("name", "A stranger"))
			(faction["members"] as Array[String]).append(member_name)
			state["faction_id"] = String(faction.get("id", ""))
			state["faction_name"] = String(faction.get("name", ""))
			state["faction_secret"] = bool(faction.get("secret", false))
			state["faction_meeting_hour"] = float(faction.get("meeting_hour", 20.0))
			state["faction_meeting_anchor"] = anchor
			var age := int(identity.get("age", 0))
			if age > leader_age[faction_index]:
				leader_age[faction_index] = age
				faction["leader"] = member_name
			break

## Labels the walkable component containing cell (flood-filled once and
## cached); returns its index into component_cells, or -1.
const COMPONENT_FLOOD_CAP := 20000

static func _component_for(cell: Vector2i, component_of_cell: Dictionary, component_cells: Array, is_walkable: Callable) -> int:
	if component_of_cell.has(cell):
		return int(component_of_cell[cell])
	if not bool(is_walkable.call(cell)):
		return -1
	var index := component_cells.size()
	var cells: Array[Vector2i] = [cell]
	component_of_cell[cell] = index
	var head := 0
	while head < cells.size() and cells.size() < COMPONENT_FLOOD_CAP:
		var current := cells[head]
		head += 1
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := current + direction
			if component_of_cell.has(next) or not bool(is_walkable.call(next)):
				continue
			component_of_cell[next] = index
			cells.append(next)
	component_cells.append(cells)
	return index

## The cell of the given component closest to the faction's hall,
## cached per (faction, component) pair.
static func _component_anchor(faction: Dictionary, component_index: int, component_cells: Array) -> Vector2i:
	var anchor_cache := faction.get("anchor_cache", {}) as Dictionary
	if anchor_cache.has(component_index):
		return anchor_cache[component_index] as Vector2i
	var meeting_cell := faction.get("meeting_cell", Vector2i.ZERO) as Vector2i
	var best := Vector2i(2147483647, 2147483647)
	var best_distance := 2147483647
	for cell: Vector2i in (component_cells[component_index] as Array[Vector2i]):
		var distance := maxi(absi(cell.x - meeting_cell.x), absi(cell.y - meeting_cell.y))
		if distance < best_distance:
			best_distance = distance
			best = cell
	anchor_cache[component_index] = best
	faction["anchor_cache"] = anchor_cache
	return best

## --- Talk of the town -------------------------------------------------------

## A rumor about some faction: open ones by name and goal, secret ones
## only as strange happenings around their meeting place.
static func faction_rumor(factions: Array[Dictionary], rng: RandomNumberGenerator) -> String:
	if factions.is_empty():
		return ""
	var faction := factions[rng.randi_range(0, factions.size() - 1)]
	var display_building := String(faction.get("meeting_building", "hall")).replace("_", " ")
	if bool(faction.get("secret", false)):
		var whispers: Array[String] = [
			"Folk slip into the %s after dark and nobody talks about it." % display_building,
			"Someone scratched a queer sign by the %s door. It was gone by morning." % display_building,
			"Stay clear of the %s past the late bell, if you ask me." % display_building
		]
		return whispers[rng.randi_range(0, whispers.size() - 1)]
	match rng.randi_range(0, 2):
		0:
			return "They say the %s means %s." % [String(faction.get("name", "guild")), String(faction.get("goal", "to endure"))]
		1:
			return "The %s gets its way by %s, mark me." % [String(faction.get("name", "guild")), String(faction.get("method", "patience"))]
		_:
			return "The %s meets at the %s most evenings. %s runs it." % [
				String(faction.get("name", "guild")), display_building,
				String(faction.get("leader", "Somebody"))
			]

## What a sworn member says about their own faction when chatted with.
static func member_line(state: Dictionary, rng: RandomNumberGenerator) -> String:
	if bool(state.get("faction_secret", false)):
		var denials: Array[String] = [
			"I keep to myself after dark. Why do you ask?",
			"Meetings? I sleep sound and early, friend.",
			"You'd do well to forget whatever you think you saw."
		]
		return denials[rng.randi_range(0, denials.size() - 1)]
	var faction_name := String(state.get("faction_name", ""))
	if faction_name.is_empty():
		return ""
	var lines: Array[String] = [
		"We of the %s look after our own." % faction_name,
		"The %s has plans, friend. Good ones." % faction_name,
		"Sworn to the %s, and proud of it." % faction_name
	]
	return lines[rng.randi_range(0, lines.size() - 1)]

## An event line rolled when a faction's meeting breaks up.
static func meeting_event_line(faction: Dictionary, rng: RandomNumberGenerator) -> String:
	var events := faction.get("events", []) as Array
	if events.is_empty():
		return ""
	var template := String(events[rng.randi_range(0, events.size() - 1)])
	if template.contains("%s"):
		var stand_in := String(faction.get("meeting_building", "hall")).replace("_", " ") if bool(faction.get("secret", false)) else String(faction.get("name", "guild"))
		return template % stand_in
	return template

## Sidebar text: open factions in full, secret ones only as a whisper.
static func sidebar_bbcode(factions: Array[Dictionary]) -> String:
	if factions.is_empty():
		return ""
	var lines: PackedStringArray = ["[b]Factions[/b]"]
	var secret_count := 0
	for faction: Dictionary in factions:
		if bool(faction.get("secret", false)):
			secret_count += 1
			continue
		var display_building := String(faction.get("meeting_building", "hall")).replace("_", " ")
		lines.append("[b]%s[/b] (%d sworn)" % [String(faction.get("name", "")), (faction.get("members", []) as Array).size()])
		lines.append("[i]%s — %s[/i]" % [String(faction.get("goal", "")).capitalize(), String(faction.get("method", ""))])
		lines.append("Meets at the %s around %d:00, led by %s" % [display_building, int(faction.get("meeting_hour", 20.0)), String(faction.get("leader", "no one yet"))])
	if secret_count > 0:
		lines.append("[i]...and whispers of something that meets after dark.[/i]")
	return "\n".join(lines)
