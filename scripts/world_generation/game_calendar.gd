extends RefCounted
class_name GameCalendar

## World calendar shared by settlement scenes: 12 months of 30 days in
## four seasons, anchored to the world chronology's starting year (the
## overworld's "Year 250, Age of Discovery"). Scenes advance a running
## day counter; this service turns it into dates and seasons.

const DAYS_PER_MONTH := 30
const MONTHS_PER_YEAR := 12
const DAYS_PER_YEAR := DAYS_PER_MONTH * MONTHS_PER_YEAR

const MONTH_NAMES: Array[String] = [
	"Deepfrost",     # winter
	"Wolfmoon",      # winter
	"Thawmarch",     # spring
	"Seedtide",      # spring
	"Blossomrise",   # spring
	"Highsun",       # summer
	"Emberpeak",     # summer
	"Goldenfield",   # summer
	"Harvestmoon",   # autumn
	"Fallingleaf",   # autumn
	"Mistveil",      # autumn
	"Longnight"      # winter
]

const MONTH_SEASONS: Array[String] = [
	"Winter", "Winter", "Spring", "Spring", "Spring", "Summer",
	"Summer", "Summer", "Autumn", "Autumn", "Autumn", "Winter"
]

## day_index counts from 0 (the day the scene was entered). Days start
## in spring by default so a fresh visit lands in a friendly season.
const START_MONTH_INDEX := 4
const START_DAY_OF_MONTH := 11

## Every year bears a chronicler's name alongside its number - "Year
## 304, the Year of Ash". The pool mixes dark annals, dwarven deeds and
## quiet natural years; an affine walk through it guarantees no two
## years repeat a name within living memory (one full pool length).
const YEAR_EPITHETS: Array[String] = [
	"Ash", "Salt", "Rain", "Rats", "Mourning", "Famine", "Smoke",
	"Cinders", "Hunger", "Graves", "Thorns", "Frost", "Plague", "Rot",
	"Carrion", "Silence", "Black Water", "Bitter Winds", "Empty Cradles",
	"Broken Bread", "the Long Winter", "the Red Sky", "Burning Fields",
	"Hollow Bells", "Dead Rivers", "Wolves", "Locusts", "Mud", "Bones",
	"Sickness", "Blood Rain", "Blight", "No Harvest", "Widows",
	"Cold Hearths", "Drowned Roads", "the Pale Sun", "the Black Moon",
	"Dry Wells", "Empty Nets", "the Falling Star", "the Broken Crown",
	"the Red Comet", "the Sleeping King", "the Open Gate",
	"the Sealed Door", "the Iron Oath", "the False Dawn",
	"the Third Shadow", "the Nameless Child", "the White Stag",
	"the Serpent's Tongue", "the Shattered Horn", "the Burning Tree",
	"the Sunless Feast", "the Stone Angel", "the Last Lantern",
	"the Blind Prophet", "the Crownless Queen", "the Deep Drum",
	"the Silver Wound", "the Black Banner", "the Hollow Mountain",
	"the Wolf Star", "the Bronze Door", "the Weeping Statue",
	"the Buried Flame", "the Unspoken Name", "the Iron Bride",
	"the Seventh Bell",
	"Stone", "Iron", "Bronze", "Deep Roads", "the Broken Pick",
	"the Empty Forge", "the First Delve", "the Fallen Hall",
	"the Sealed Mine", "the Lost Anvil", "the Cracked Helm",
	"the Black Forge", "Deep Fire", "the Stone Kings",
	"the Flooded Shaft", "the Silent Hammer", "the Buried Gate",
	"the Last Ale", "the Long Dig", "the Open Cavern",
	"the Forgotten Stair", "the Deep Rats", "the Copper Plague",
	"the Goblin Moon", "the Empty Mead Hall", "the Stone Funeral",
	"the King Beneath", "the Dead Lanterns", "the Shattered Vault",
	"the Sleeping Forge",
	"Snow", "Wind", "Fog", "Dust", "Clay", "Moss", "Reeds", "Crows",
	"Owls", "Boars", "Bees", "Worms", "Tides", "Storms", "Ice", "Fire",
	"Roots", "Leaves", "Thunder", "Floods", "Drought", "Mist",
	"Flowers", "Nettles", "Briars", "Ravens", "Serpents", "Foxes",
	"Black Pines",
	"Kings", "the Moon", "the Yellow Fire", "Bloodstone"
]

## The epithet's tail: "Ash", "the Long Winter"...
static func year_epithet(year: int) -> String:
	# 45 is coprime to the pool size (133 = 7 x 19), so consecutive
	# years walk the whole pool before any name comes around again.
	return YEAR_EPITHETS[posmod(year * 45 + 17, YEAR_EPITHETS.size())]

## "the Year of Ash" (or "The Year of Ash" when it opens a sentence).
static func year_title(year: int, capitalized: bool = false) -> String:
	return ("The Year of %s" if capitalized else "the Year of %s") % year_epithet(year)

static func _absolute_day(day_index: int) -> int:
	return maxi(0, day_index) + START_MONTH_INDEX * DAYS_PER_MONTH + (START_DAY_OF_MONTH - 1)

static func year_for_day(day_index: int, start_year: int) -> int:
	return start_year + _absolute_day(day_index) / DAYS_PER_YEAR

static func month_index_for_day(day_index: int) -> int:
	return (_absolute_day(day_index) % DAYS_PER_YEAR) / DAYS_PER_MONTH

static func day_of_month_for_day(day_index: int) -> int:
	return (_absolute_day(day_index) % DAYS_PER_MONTH) + 1

static func month_name_for_day(day_index: int) -> String:
	return MONTH_NAMES[month_index_for_day(day_index)]

static func season_for_day(day_index: int) -> String:
	return MONTH_SEASONS[month_index_for_day(day_index)]

## e.g. "12 Blossomrise, Year 250, the Year of Ash"
static func date_text(day_index: int, start_year: int) -> String:
	var year := year_for_day(day_index, start_year)
	return "%d %s, Year %d, %s" % [
		day_of_month_for_day(day_index),
		month_name_for_day(day_index),
		year,
		year_title(year)
	]
