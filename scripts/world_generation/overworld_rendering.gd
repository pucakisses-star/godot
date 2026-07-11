extends RefCounted

static func temperature_to_color(temperature: float) -> Color:
	var cold := Color(0.2, 0.45, 1.0, 0.45)
	var hot := Color(1.0, 0.25, 0.1, 0.45)
	return cold.lerp(hot, clampf(temperature, 0.0, 1.0))

static func elevation_to_color(height: float, water_level: float, mountain_level: float) -> Color:
	var alpha := 0.45
	var deep_water := Color(0.0, 0.2, 0.55, alpha)
	var shallow_water := Color(0.1, 0.5, 0.85, alpha)
	var lowland := Color(0.2, 0.6, 0.35, alpha)
	var highland := Color(0.6, 0.5, 0.25, alpha)
	var snow := Color(0.92, 0.92, 0.96, alpha)
	if height < water_level:
		var water_ratio := clampf(height / maxf(water_level, 0.001), 0.0, 1.0)
		return deep_water.lerp(shallow_water, water_ratio)
	if height < mountain_level:
		var land_ratio := clampf((height - water_level) / maxf(mountain_level - water_level, 0.001), 0.0, 1.0)
		return lowland.lerp(highland, land_ratio)
	var mountain_ratio := clampf((height - mountain_level) / maxf(1.0 - mountain_level, 0.001), 0.0, 1.0)
	return highland.lerp(snow, mountain_ratio)

## Dwarf-Fortress-style cliff / shaded-relief tint for one land tile.
## Shades by the elevation gradient against the four neighbours: a
## hillshade lights the slopes from the north-west, an earthy ramp colours
## by height, and any steep drop to a neighbour is burned in dark so
## escarpments read as crisp cliff lines. Water is drawn flat and cold so
## the land relief stands on its own. Nearly opaque — this is a base view,
## not a translucent wash like the other overlays.
static func cliff_shade_color(height: float, west: float, east: float, north: float, south: float, water_level: float, mountain_level: float) -> Color:
	var alpha := 0.92
	if height < water_level:
		var depth := clampf(height / maxf(water_level, 0.001), 0.0, 1.0)
		var deep := Color(0.09, 0.12, 0.22, alpha)
		var shallow := Color(0.16, 0.24, 0.36, alpha)
		return deep.lerp(shallow, depth)
	## Surface normal from the exaggerated gradient, so even gentle land
	## shades and cliffs read hard.
	var exaggeration := 14.0
	var dzdx := (east - west) * 0.5
	var dzdy := (south - north) * 0.5
	var normal := Vector3(-dzdx * exaggeration, -dzdy * exaggeration, 1.0).normalized()
	var light := Vector3(-0.6, -0.7, 0.42).normalized()
	var shade := clampf(0.34 + 0.9 * normal.dot(light), 0.06, 1.25)
	var base: Color
	if height < mountain_level:
		var land_ratio := clampf((height - water_level) / maxf(mountain_level - water_level, 0.001), 0.0, 1.0)
		base = Color(0.6, 0.64, 0.5).lerp(Color(0.55, 0.44, 0.31), land_ratio)
	else:
		var peak_ratio := clampf((height - mountain_level) / maxf(1.0 - mountain_level, 0.001), 0.0, 1.0)
		base = Color(0.55, 0.44, 0.31).lerp(Color(0.93, 0.92, 0.9), peak_ratio)
	var lit := Color(
		clampf(base.r * shade, 0.0, 1.0),
		clampf(base.g * shade, 0.0, 1.0),
		clampf(base.b * shade, 0.0, 1.0),
		alpha
	)
	## The steeper the fall to any neighbour, the darker the face.
	var max_slope := maxf(
		maxf(absf(height - west), absf(height - east)),
		maxf(absf(height - north), absf(height - south))
	)
	var cliff_amount := smoothstep(0.035, 0.13, max_slope)
	return lit.lerp(Color(0.05, 0.045, 0.05, alpha), cliff_amount * 0.82)

static func moisture_to_color(moisture: float) -> Color:
	var dry := Color(0.55, 0.35, 0.18, 0.45)
	var wet := Color(0.15, 0.55, 0.9, 0.45)
	return dry.lerp(wet, clampf(moisture, 0.0, 1.0))

static func biome_to_overlay_color(biome: String, alpha: float = 0.45) -> Color:
	match biome:
		"water":
			return Color(0.1, 0.35, 0.75, alpha)
		"mountain":
			return Color(0.55, 0.55, 0.6, alpha)
		"hills":
			return Color(0.6, 0.45, 0.25, alpha)
		"marsh":
			return Color(0.2, 0.6, 0.45, alpha)
		"tundra":
			return Color(0.75, 0.8, 0.9, alpha)
		"desert":
			return Color(0.9, 0.75, 0.35, alpha)
		"badlands":
			return Color(0.7, 0.35, 0.25, alpha)
		"forest":
			return Color(0.2, 0.55, 0.25, alpha)
		"jungle":
			return Color(0.15, 0.45, 0.2, alpha)
		"grassland":
			return Color(0.35, 0.7, 0.35, alpha)
	return Color(0.5, 0.5, 0.5, alpha)
