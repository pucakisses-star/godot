extends RefCounted
class_name BuildingNameService

## Every civic building deserves a name over its door. Names are rolled
## deterministically from the settlement seed and the building's stable
## id, so "The Bronze Tankard" stays "The Bronze Tankard" on every visit
## and every level round-trip.

const ADJECTIVES: Array[String] = [
	"Bronze", "Gilded", "Sleeping", "Crooked", "Merry", "Thirsty", "Iron",
	"Silver", "Broken", "Laughing", "Stubborn", "Wandering", "Old", "Salty",
	"Copper", "Velvet", "Howling", "Quiet", "Golden", "Bearded"
]
const TAVERN_NOUNS: Array[String] = [
	"Tankard", "Anvil", "Wyvern", "Lantern", "Boar", "Barrel", "Pick",
	"Griffon", "Kettle", "Stag", "Toad", "Hammer", "Mole", "Raven", "Flagon"
]
const STATELY_NOUNS: Array[String] = [
	"Sanctum", "Vault", "Chamber", "Court", "Spire", "Gallery", "Rotunda",
	"Bastion", "Athenaeum", "Reliquary", "Hall", "Archive"
]
const PROPRIETORS_DWARF: Array[String] = [
	"Copperbeard", "Stonefist", "Ironhelm", "Goldvein", "Deepdelver",
	"Anvilborn", "Granitejaw", "Silverbraid", "Emberforge", "Rockseeker",
	"Steeltoe", "Gemcutter", "Coalbrand", "Hammerfall", "Flintbeard"
]
const PROPRIETORS_TOWN: Array[String] = [
	"Miller", "Thatcher", "Cooper", "Fletcher", "Baker", "Weaver", "Tanner",
	"Mason", "Carter", "Shepherd", "Brewer", "Smith", "Wright", "Potter", "Kemp"
]

## Tavern-style "The Adjective Noun" names.
const SIGNBOARD_TYPES := [
	"tavern", "inn", "brewery", "bakery", "auction_house", "market_stall",
	"general_store", "general_goods_shop", "trade_supply_store", "barber_shop"
]
## Stately "The Adjective Noun" institutions.
const STATELY_TYPES := [
	"temple", "chapel", "archives", "bank_vaults", "guild_hall", "town_hall",
	"high_kings_palace", "enchanting_study", "runesmith_sanctum", "infirmary",
	"merchants_counting_house", "cartographers_office", "explorers_guild",
	"miners_guild", "mason_lodge", "monastery"
]

static func name_for(building_type: String, seed_text: String, building_id: String, kind: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|building" % [seed_text, building_id])
	var adjective := ADJECTIVES[rng.randi_range(0, ADJECTIVES.size() - 1)]
	if SIGNBOARD_TYPES.has(building_type):
		return "The %s %s" % [adjective, TAVERN_NOUNS[rng.randi_range(0, TAVERN_NOUNS.size() - 1)]]
	if STATELY_TYPES.has(building_type):
		return "The %s %s" % [adjective, STATELY_NOUNS[rng.randi_range(0, STATELY_NOUNS.size() - 1)]]
	# Workshops and trades hang the proprietor's name over the door.
	var proprietors := PROPRIETORS_DWARF if kind == "dwarf" else PROPRIETORS_TOWN
	var owner := proprietors[rng.randi_range(0, proprietors.size() - 1)]
	var trade := building_type.replace("_", " ").capitalize()
	return "%s's %s" % [owner, trade]
