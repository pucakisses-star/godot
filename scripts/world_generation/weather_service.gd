extends RefCounted
class_name WeatherService

## Daily weather for the surface settlements. Each absolute day rolls one
## sky from a season-weighted table seeded purely by (world seed, day), so
## every scene agrees on the forecast and nothing new needs saving.

const KIND_CLEAR := "clear"
const KIND_OVERCAST := "overcast"
const KIND_RAIN := "rain"
const KIND_STORM := "storm"
const KIND_SNOW := "snow"

## Cumulative-roll [kind, weight] rows; each season's weights sum to 1.
## Winter is buried in snow, with the odd freezing rain slipping through;
## the green seasons never snow.
const SEASON_TABLES := {
	"Winter": [[KIND_SNOW, 0.60], [KIND_RAIN, 0.05], [KIND_OVERCAST, 0.20], [KIND_CLEAR, 0.15]],
	"Spring": [[KIND_RAIN, 0.30], [KIND_STORM, 0.08], [KIND_OVERCAST, 0.22], [KIND_CLEAR, 0.40]],
	"Summer": [[KIND_CLEAR, 0.55], [KIND_STORM, 0.12], [KIND_RAIN, 0.13], [KIND_OVERCAST, 0.20]],
	"Autumn": [[KIND_RAIN, 0.32], [KIND_STORM, 0.10], [KIND_OVERCAST, 0.28], [KIND_CLEAR, 0.30]]
}

## Componentwise daylight multipliers: cloud gloom, blue-grey rain, dark
## storms, a cool cast under snow.
const KIND_TINTS := {
	KIND_CLEAR: Color(1.0, 1.0, 1.0, 1.0),
	KIND_OVERCAST: Color(0.92, 0.92, 0.93, 1.0),
	KIND_RAIN: Color(0.80, 0.82, 0.88, 1.0),
	KIND_STORM: Color(0.68, 0.70, 0.76, 1.0),
	KIND_SNOW: Color(0.88, 0.90, 0.94, 1.0)
}

## {"kind": clear|overcast|rain|storm|snow, "intensity": 0.3..1.0},
## deterministic in (world_seed_text, day_index).
static func weather_for_day(world_seed_text: String, day_index: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|weather|%d" % [world_seed_text, day_index])
	var kind := seasonal_weather_roll(GameCalendar.season_for_day(day_index), rng)
	return {"kind": kind, "intensity": rng.randf_range(0.3, 1.0)}

## One sky drawn from a season's weight table with the caller's dice - the
## bias itself, separated so anything (a forecast, a chronicle, a test rig)
## can sample a season without committing to a calendar day.
static func seasonal_weather_roll(season: String, roll_rng: RandomNumberGenerator) -> String:
	var table := SEASON_TABLES.get(season, SEASON_TABLES["Spring"]) as Array
	var roll := roll_rng.randf()
	var cumulative := 0.0
	for row_variant: Variant in table:
		var row := row_variant as Array
		cumulative += float(row[1])
		if roll <= cumulative:
			return String(row[0])
	return KIND_CLEAR

static func is_precipitating(weather: Dictionary) -> bool:
	var kind := String(weather.get("kind", KIND_CLEAR))
	return kind == KIND_RAIN or kind == KIND_STORM or kind == KIND_SNOW

## Storms ground the off-duty townsfolk; heavy snow is a blizzard and
## counts the same.
static func is_storm(weather: Dictionary) -> bool:
	var kind := String(weather.get("kind", KIND_CLEAR))
	if kind == KIND_STORM:
		return true
	return kind == KIND_SNOW and float(weather.get("intensity", 0.0)) > 0.8

## Multiplies into the hour-of-day tint (white leaves it untouched).
static func tint_multiplier(weather: Dictionary) -> Color:
	return KIND_TINTS.get(String(weather.get("kind", KIND_CLEAR)), Color.WHITE) as Color
