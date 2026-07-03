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

## e.g. "12 Blossomrise, Year 250"
static func date_text(day_index: int, start_year: int) -> String:
	return "%d %s, Year %d" % [
		day_of_month_for_day(day_index),
		month_name_for_day(day_index),
		year_for_day(day_index, start_year)
	]
