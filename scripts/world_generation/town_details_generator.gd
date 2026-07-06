extends RefCounted
class_name TownDetailsGenerator

## Seeded lore for human towns: ruler, hallmark, prominent house, guilds
## and exports. Ported from the web prototype's generateTownDetails so the
## town interior scene can show the same flavor the overworld promises.

const RULER_TITLES_MALE: Array[String] = [
	"Mayor", "Lord Mayor", "High Steward", "Burgomaster", "Castellan"
]
const RULER_TITLES_FEMALE: Array[String] = [
	"Mayor", "Lady Mayor", "High Steward", "Burgomistress", "Castellan"
]
const RULER_TITLES_NEUTRAL: Array[String] = [
	"Governor", "Magistrate", "Marshal", "Chamberlain", "Steward"
]

const TOWN_HALLMARKS: Array[String] = [
	"Celebrated for its midsummer lantern festivals that light the riverways.",
	"Known for bustling markets where spices and silks trade hands till dusk.",
	"Renowned scribes illuminate tomes commissioned by distant courts.",
	"Shipwrights here launch swift river cutters and stout coastal cogs.",
	"Bards gather nightly in its echoing amphitheatre for tale and song.",
	"Town gardens brim with rare herbs prized by alchemists abroad.",
	"Its watchfires are said to be seen from the bordering highlands.",
	"Pilgrims arrive seasonally to venerate relics kept in the hilltop chapel.",
	"Stone bridges arch over canals lined with copper-roofed warehouses.",
	"Famous for street performers who juggle embers without being burned."
]

const TOWN_EXPORT_OPTIONS: Array[String] = [
	"Fine woolens and dyed textiles",
	"Barrels of spiced wine and cordial",
	"Carved hardwood furniture and cabinetry",
	"Glazed ceramics and painted pottery",
	"Ironmongery tools and horseshoes",
	"Salted riverfish and smoked eel",
	"Illuminated manuscripts and scrolls",
	"Perfumed oils and soaps",
	"Handcrafted musical instruments",
	"Leather saddles and tack"
]

const PROMINENT_FAMILY_NAMES: Array[String] = [
	"Ambermere", "Briarhelm", "Crownhill", "Dunleigh", "Emberfast",
	"Fairbloom", "Hallowmere", "Kestrelbourne", "Marrowind", "Ravenbrook",
	"Stormholt", "Thornwall", "Underford", "Wintermere"
]

const TOWN_GUILD_OPTIONS: Array[String] = [
	"Merchants Consortium", "River Bargemen Union", "Artisan Collective",
	"Scribes and Illuminators Guild", "Shipwrights Assembly",
	"Alchemists Conclave", "Vintners Circle", "Weavers Syndicate",
	"Stevedores Brotherhood", "Stonemasons Chapter",
	"Cartographers Fellowship", "Apothecaries Guild",
	"Wrights and Carpenters Lodge", "Guard Captains Council",
	"Miners Exchange"
]

const FIRST_NAMES_MALE: Array[String] = [
	"Aldric", "Berend", "Cedric", "Darian", "Edric", "Garran", "Henric",
	"Loric", "Rowan", "Therin"
]
const FIRST_NAMES_FEMALE: Array[String] = [
	"Adela", "Brienne", "Celia", "Elowen", "Fiora", "Gwendolyn", "Isolde",
	"Maren", "Rowena", "Seren"
]
const FIRST_NAMES_NEUTRAL: Array[String] = [
	"Arlen", "Ember", "Finley", "Morgan", "Robin", "Sage", "Tarian"
]

const COMMON_OCCUPATIONS: Array[String] = [
	"Baker", "Blacksmith", "Carpenter", "Chandler", "Cobbler", "Cooper",
	"Farmer", "Fisher", "Innkeeper", "Mason", "Miller", "Potter",
	"Stablehand", "Tailor", "Town Guard", "Weaver"
]

static func classification_for_population(population: int) -> String:
	if population >= 6000:
		return "City"
	if population >= 3600:
		return "Large Town"
	if population >= 100:
		return "Town"
	return "Village"

## options:
##   "village": true  - force the Village classification regardless of
##     population (hamlets and snow villages, browser generateHamletDetails
##     main.js:3883-3922 keeps classification 'Village' at pop 28-168).
static func generate(town_name: String, population: int, rng: RandomNumberGenerator, options: Dictionary = {}) -> Dictionary:
	var classification := "Village" if bool(options.get("village", false)) else classification_for_population(population)
	var gender_roll := rng.randf()
	var first_names := FIRST_NAMES_NEUTRAL
	var ruler_titles := RULER_TITLES_NEUTRAL
	if gender_roll < 0.45:
		first_names = FIRST_NAMES_MALE
		ruler_titles = RULER_TITLES_MALE
	elif gender_roll < 0.9:
		first_names = FIRST_NAMES_FEMALE
		ruler_titles = RULER_TITLES_FEMALE

	var first_name := _pick(first_names, rng, "Aldric")
	var family_name := _pick(PROMINENT_FAMILY_NAMES, rng, "Ambermere")
	var ruler_title := _pick(ruler_titles, rng, "Mayor")
	var hallmark := _pick(TOWN_HALLMARKS, rng, "Bustling markets draw traders from afar.")
	var founded_years_ago := maxi(12, 30 + rng.randi_range(0, 419))
	var prominent_house := "House %s" % _pick(PROMINENT_FAMILY_NAMES, rng, family_name)

	var major_guilds: Array[String] = []
	if classification != "Village":
		major_guilds = _pick_unique(TOWN_GUILD_OPTIONS, rng.randi_range(1, 3), rng)
	var major_exports := _pick_unique(TOWN_EXPORT_OPTIONS, rng.randi_range(1, 3), rng)

	return {
		"name": town_name,
		"classification": classification,
		"population": population,
		"ruler_title": ruler_title,
		"ruler_name": "%s %s" % [first_name, family_name],
		"founded_years_ago": founded_years_ago,
		"prominent_house": prominent_house,
		"hallmark": hallmark,
		"major_guilds": major_guilds,
		"major_exports": major_exports
	}

static func npc_name(rng: RandomNumberGenerator) -> String:
	var gender_roll := rng.randf()
	var first_names := FIRST_NAMES_NEUTRAL
	if gender_roll < 0.45:
		first_names = FIRST_NAMES_MALE
	elif gender_roll < 0.9:
		first_names = FIRST_NAMES_FEMALE
	return "%s %s" % [_pick(first_names, rng, "Rowan"), _pick(PROMINENT_FAMILY_NAMES, rng, "Fairbloom")]

## Occupations lean toward the town's guilds (a Weavers Syndicate town has
## more weavers) with common trades filling the rest.
static func npc_occupation(major_guilds: Array[String], rng: RandomNumberGenerator) -> String:
	if not major_guilds.is_empty() and rng.randf() < 0.35:
		var guild := _pick(major_guilds, rng, "")
		var occupation := _occupation_from_guild(guild)
		if not occupation.is_empty():
			return occupation
	return _pick(COMMON_OCCUPATIONS, rng, "Farmer")

static func _occupation_from_guild(guild: String) -> String:
	var lowered := guild.to_lower()
	if lowered.contains("merchant"):
		return "Merchant"
	if lowered.contains("bargemen"):
		return "Bargeman"
	if lowered.contains("artisan"):
		return "Artisan"
	if lowered.contains("scribe"):
		return "Scribe"
	if lowered.contains("shipwright"):
		return "Shipwright"
	if lowered.contains("alchemist"):
		return "Alchemist"
	if lowered.contains("vintner"):
		return "Vintner"
	if lowered.contains("weaver"):
		return "Weaver"
	if lowered.contains("stevedore"):
		return "Stevedore"
	if lowered.contains("stonemason"):
		return "Stonemason"
	if lowered.contains("cartographer"):
		return "Cartographer"
	if lowered.contains("apothecar"):
		return "Apothecary"
	if lowered.contains("carpenter"):
		return "Carpenter"
	if lowered.contains("guard"):
		return "Town Guard"
	if lowered.contains("miner"):
		return "Miner"
	return ""

static func _pick(options: Array[String], rng: RandomNumberGenerator, fallback: String) -> String:
	if options.is_empty():
		return fallback
	return options[rng.randi_range(0, options.size() - 1)]

static func _pick_unique(options: Array[String], count: int, rng: RandomNumberGenerator) -> Array[String]:
	var pool := options.duplicate()
	var picked: Array[String] = []
	var target := clampi(count, 0, pool.size())
	for _i in range(target):
		var index := rng.randi_range(0, pool.size() - 1)
		picked.append(pool[index])
		pool.remove_at(index)
	return picked
