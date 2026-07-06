extends RefCounted

## Base-biome, marsh and tree-biome rules were ported into OverworldMap
## (browser-parity worldgen): snow presence (main.js:21607-21635), the marsh
## suitability model (main.js:21758-21939), the equatorial desert bands
## (main.js:21991-22117) and the badlands desert cores (main.js:22539-22719)
## all need the generator's seeded noise fields, so they live next to the
## pipeline in overworld_map.gd. This helper keeps the biome -> atlas tile
## mapping.

static func biome_to_tile(biome: String, tiles: Dictionary, biomes: Dictionary) -> Vector2i:
	if biome == String(biomes.get("water", "water")): return tiles.get("water", Vector2i.ZERO) as Vector2i
	if biome == String(biomes.get("mountain", "mountain")): return tiles.get("mountain", Vector2i.ZERO) as Vector2i
	if biome == String(biomes.get("hills", "hills")): return tiles.get("hills", Vector2i.ZERO) as Vector2i
	if biome == String(biomes.get("marsh", "marsh")): return tiles.get("marsh", Vector2i.ZERO) as Vector2i
	if biome == String(biomes.get("tundra", "tundra")): return tiles.get("snow", Vector2i.ZERO) as Vector2i
	if biome == String(biomes.get("desert", "desert")): return tiles.get("sand", Vector2i.ZERO) as Vector2i
	if biome == String(biomes.get("badlands", "badlands")): return tiles.get("badlands", Vector2i.ZERO) as Vector2i
	if biome == String(biomes.get("forest", "forest")): return tiles.get("tree", Vector2i.ZERO) as Vector2i
	if biome == String(biomes.get("jungle", "jungle")): return tiles.get("jungle_tree", Vector2i.ZERO) as Vector2i
	return tiles.get("grass", Vector2i.ZERO) as Vector2i
