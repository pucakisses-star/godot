extends RefCounted
class_name SignTextService

## Readable signs. Every sign-like decor cell (shop signboards, corridor
## signs, notice boards, direction posts) resolves to a short text rolled
## deterministically from the settlement seed and the sign's cell, so the
## same board says the same thing on every visit. Business signs carry the
## establishment's rolled name and trade; direction posts point at real
## gazetteer sites with a compass arrow; everything else gets a village
## notice from the flavor pool below.

## Short village-notice flavor lines for boards with no business to name.
const NOTICE_FLAVOR: Array[String] = [
	"Market day every Fifthday. Stalls by the square, no haggling after dusk.",
	"LOST: one spotted pig, answers to Turnip. Reward: a wheel of cheese.",
	"Beware wolves on the outer paths after dark. Travel in pairs.",
	"Grain tally due at the granary before first frost. No exceptions.",
	"WANTED: strong backs for the harvest. Ask at the tavern, mornings only.",
	"The well water is fine. Whoever keeps saying otherwise, stop it.",
	"Curfew bell rings at tenth hour. Latecomers explain themselves to the watch.",
	"FOUND: one left boot, good sole. Claim it from the cobbler's stoop.",
	"No fishing off the mill bridge. The miller's patience is thinner than the ice.",
	"Tithe barrels stand by the shrine. Give what you can spare, not what you can't.",
	"REWARD for word of the peddler who sold the mayor a 'self-stirring' pot.",
	"Livestock tally: three goats, one cow, and Turnip still missing (see above).",
	"Keep your chimneys swept. Last month's fire is nobody's idea of a festival.",
	"Dance on the green come midsummer. Bring a lantern and your own cup."
]

## A seeded notice for a plain sign or notice board: stable per seed and cell.
static func flavor_text(seed_text: String, cell: Vector2i) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d,%d|sign_flavor" % [seed_text, cell.x, cell.y])
	return NOTICE_FLAVOR[rng.randi_range(0, NOTICE_FLAVOR.size() - 1)]

## "The Quiet Anvil — Barber Shop": the establishment's rolled name plus
## its trade, degrading gracefully when either half is missing.
static func business_sign_text(display_name: String, trade_display: String) -> String:
	if display_name.is_empty():
		return trade_display
	# Proprietor-format names already end with the trade ("Fletcher's
	# Storeroom"); repeating it after the dash would read twice.
	if trade_display.is_empty() or display_name.ends_with(trade_display):
		return display_name
	return "%s — %s" % [display_name, trade_display]

## The 8-way compass arrow from a sign toward a destination, in map space
## (positive y points south/down, matching the tile grid).
static func compass_arrow(delta: Vector2i) -> String:
	if delta == Vector2i.ZERO:
		return "•"
	var octant := wrapi(roundi(atan2(float(delta.y), float(delta.x)) / (PI / 4.0)), 0, 8)
	return ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"][octant]

## Direction-post text: the 2-3 nearest named gazetteer sites, one per
## line, each led by the compass arrow from the post's overworld tile.
## Empty when the gazetteer has nothing to point at (caller falls back to
## a notice). Sites share the wire format of WorldSitesService ("name",
## "x", "y" overworld tile coordinates).
static func direction_post_text(sites: Array, post_tile: Vector2i, seed_text: String, cell: Vector2i) -> String:
	var entries: Array[Dictionary] = []
	for site_variant: Variant in sites:
		if not (site_variant is Dictionary):
			continue
		var site := site_variant as Dictionary
		var site_name := String(site.get("name", ""))
		if site_name.is_empty():
			continue
		var site_tile := Vector2i(int(site.get("x", 0)), int(site.get("y", 0)))
		if site_tile == post_tile:
			continue
		entries.append({
			"name": site_name,
			"tile": site_tile,
			"distance": (site_tile - post_tile).length_squared()
		})
	if entries.is_empty():
		return ""
	entries.sort_custom(func(entry_a: Dictionary, entry_b: Dictionary) -> bool:
		var distance_a := int(entry_a.get("distance", 0))
		var distance_b := int(entry_b.get("distance", 0))
		if distance_a == distance_b:
			return String(entry_a.get("name", "")) < String(entry_b.get("name", ""))
		return distance_a < distance_b
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d,%d|sign_post" % [seed_text, cell.x, cell.y])
	var line_count := mini(entries.size(), rng.randi_range(2, 3))
	var lines := PackedStringArray()
	for entry_index in line_count:
		var entry := entries[entry_index]
		var arrow := compass_arrow((entry.get("tile") as Vector2i) - post_tile)
		lines.append("%s %s" % [arrow, String(entry.get("name", ""))])
	return "\n".join(lines)
