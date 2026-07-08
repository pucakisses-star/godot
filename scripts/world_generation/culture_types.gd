class_name CultureTypes
extends RefCounted

const DEFAULT_CULTURE_COLORS: Dictionary[String, Color] = {
	"humans": Color("#A0C6E5"),
	"dwarves": Color("#C9A061"),
	"wood_elves": Color("#6EBF7A"),
	"halflings": Color("#EBC28A"),
	"lizardmen": Color("#6BBE88"),
	"karkinos": Color("#3aa7c9"),
	"blemaayae": Color("#a35fa9"),
	"pygmy": Color("#4e9f63"),
	"half_orcs": Color("#7c9358"),
	"half_elves": Color("#89bb8c"),
	"dryad": Color("#3f9b7a"),
	"leshy": Color("#5d8a51"),
	"satyr": Color("#b67c4f"),
	"hobgoblin": Color("#9b5a4a"),
	"locathah": Color("#4e93bf"),
	"firbolg": Color("#88a86a"),
	"aarakocra": Color("#a3a8c8"),
	"braxat": Color("#c47d4a"),
	"hadozee": Color("#4f8d74"),
	"quilboar": Color("#8f5a59"),
	"merfolks": Color("#4aa7d8"),
	"fae": Color("#a58de2"),
	"snakemen": Color("#6f9b55"),
	"gnomes": Color("#d9b16c"),
	"ogres": Color("#7f6f66"),
	"trolls": Color("#5f7f6b"),
	"harpies": Color("#8d8cab"),
	"giants": Color("#9095a1"),
	"centaurs": Color("#9b7b55"),
	"tuskar": Color("#6d86aa"),
	"fimir": Color("#567572"),
	"demons": Color("#D46A6A"),
	"desert_folk": Color("#D9A94A"),
	"dragons": Color("#8A6BDA"),
	"beastmen": Color("#8D6E63"),
	"gnolls": Color("#A77B4E"),
	"orc": Color("#719A54")
}

const SETTLEMENT_CLAIM_RADIUS_BY_TYPE: Dictionary[String, int] = {
	"town": 10,
	"dwarfhold": 12,
	"woodelfgrove": 13,
	"woodelfgroves": 13,
	"lizardmencity": 11,
	"capital": 16,
	"hamlet": 9,
	"castle": 11,
	"port": 11,
	"desertcity": 11
}

const SETTLEMENT_RADIUS_MULTIPLIER_BY_TYPE: Dictionary[String, float] = {
	"town": 1.0,
	"dwarfhold": 1.2,
	"woodelfgrove": 1.25,
	"lizardmencity": 1.15,
	"capital": 1.35,
	"hamlet": 0.85,
	"castle": 1.1,
	"port": 1.05
}

const SETTLEMENT_FALLOFF_BY_TYPE: Dictionary[String, float] = {
	"town": 1.25,
	"dwarfhold": 1.55,
	"woodelfgrove": 1.1,
	"lizardmencity": 1.2,
	"capital": 1.35,
	"hamlet": 1.15,
	"castle": 1.45,
	"port": 1.2
}

const DEFAULT_SETTLEMENT_BREAKDOWN_BY_TYPE: Dictionary[String, Array] = {
	"town": [
		{"key": "humans", "label": "Humans", "color": DEFAULT_CULTURE_COLORS["humans"], "share": 0.72},
		{"key": "halflings", "label": "Halflings", "color": DEFAULT_CULTURE_COLORS["halflings"], "share": 0.16},
		{"key": "dwarves", "label": "Dwarves", "color": DEFAULT_CULTURE_COLORS["dwarves"], "share": 0.12}
	],
	"dwarfhold": [
		{"key": "dwarves", "label": "Dwarves", "color": DEFAULT_CULTURE_COLORS["dwarves"], "share": 0.82},
		{"key": "humans", "label": "Humans", "color": DEFAULT_CULTURE_COLORS["humans"], "share": 0.10},
		{"key": "halflings", "label": "Halflings", "color": DEFAULT_CULTURE_COLORS["halflings"], "share": 0.08}
	],
	"woodelfgrove": [
		{"key": "wood_elves", "label": "Wood Elves", "color": DEFAULT_CULTURE_COLORS["wood_elves"], "share": 0.86},
		{"key": "humans", "label": "Humans", "color": DEFAULT_CULTURE_COLORS["humans"], "share": 0.14}
	],
	"lizardmencity": [
		{"key": "lizardmen", "label": "Lizardmen", "color": DEFAULT_CULTURE_COLORS["lizardmen"], "share": 0.88},
		{"key": "humans", "label": "Humans", "color": DEFAULT_CULTURE_COLORS["humans"], "share": 0.12}
	]
}

const CULTURE_BIOME_LIMITS: Dictionary[String, Array] = {
	"desert_folk": ["desert", "badlands", "grassland"],
	"dwarves": ["mountain", "hills"],
	"karkinos": ["ocean", "lake", "marsh", "water"],
	"blemaayae": ["desert", "badlands", "jungle", "mountain", "hills"],
	"pygmy": ["jungle"],
	"half_orcs": ["grassland", "badlands", "desert"],
	"half_elves": ["forest", "grassland"],
	"dryad": ["forest", "marsh", "lake"],
	"leshy": ["forest", "marsh"],
	"satyr": ["forest", "grassland"],
	"snakemen": ["desert", "jungle"],
	"hobgoblin": ["badlands", "mountain", "hills", "grassland"],
	"locathah": ["ocean", "lake", "marsh", "water"],
	"firbolg": ["forest", "grassland"],
	"aarakocra": ["mountain", "hills", "grassland"],
	"gnomes": ["mountain"],
	"braxat": ["desert", "badlands", "jungle"],
	"hadozee": ["ocean", "lake", "water", "jungle"],
	"merfolks": ["ocean"],
	"quilboar": ["badlands", "desert", "grassland"],
	"fimir": ["marsh"]
}

const AMBIENT_STRUCTURE_OPTIONS_BY_CULTURE: Dictionary[String, Array] = {
	"humans": [
		{
			"id": "farm",
			"label": "Farm",
			"tile": Vector2i(15, 1),
			"requires_tree_neighbor": false,
			"requires_plain_grass": true
		},
		{
			"id": "homestead",
			"label": "Homestead",
			"tile": Vector2i(13, 1),
			"disallow_forest_overlay": false,
			"requires_plain_grass": true
		},
		{
			"id": "hunting_lodge",
			"label": "Hunting Lodge",
			"tile": Vector2i(16, 0),
			"requires_tree_overlay": true,
			"replace_tree_overlay": true
		},
		{
			"id": "lumber_mill",
			"label": "Lumber Mill",
			# (0,5) is sparse filler in the overworld atlas; the actual mill
			# art lives at (0,6) (AMBIENT_LUMBER_MILL_TILE), so a spawned mill
			# was drawing near-nothing. Point it at the real building.
			"tile": Vector2i(0, 6),
			"requires_tree_overlay": true,
			"replace_tree_overlay": true
		},
		{
			"id": "castle",
			"label": "Castle",
			"tile": Vector2i(6, 4),
			"requires_plain_grass": true
		},
		{
			"id": "monastery",
			"label": "Monastery",
			"tile": Vector2i(2, 2),
			"requires_plain_grass": true
		},
		{
			"id": "saintShrine",
			"label": "Saint Shrine",
			"tile": Vector2i(11, 1),
			"requires_plain_grass": true
		},
		{
			"id": "roadsideTavern",
			"label": "Roadside Tavern",
			"tile": Vector2i(12, 1),
			"requires_plain_grass": true
		},
		{"id": "watchtower", "label": "Watchtower", "tile": Vector2i(3, 4), "requires_plain_grass": true},
		{"id": "farmhouse", "label": "Farmhouse", "tile": Vector2i(4, 5), "requires_plain_grass": true},
		{"id": "hermit_hut", "label": "Hermit's Hut", "tile": Vector2i(0, 4)}
	],
	"wood_elves": [
		{"id": "moonwell", "label": "Moonwell", "tile": Vector2i(2, 5), "requires_tree_neighbor": true, "requires_deep_forest": true},
		{"id": "great_tree", "label": "Great Tree", "tile": Vector2i(14, 1), "requires_tree_overlay": true},
		{"id": "old_growth", "label": "Old Growth", "tile": Vector2i(0, 2), "requires_tree_overlay": true, "replace_tree_overlay": true}
	],
	"dragons": [
		# Browser: the Sleeping Dragon coils on a mountain peak
		# (requiresMountainOverlay); the green dragon haunts cave mouths;
		# the rest are tile-less tooltip landmarks, and diluting the pick
		# pool keeps actual dragons a rare sight.
		{"id": "sleeping_dragon", "label": "Sleeping Dragon", "tile": Vector2i(14, 0), "requires_mountain_overlay": true},
		# The green dragon used to require a cave neighbour, which almost never
		# coincided with dragon territory, so it never appeared. Ungated now:
		# it lairs across dragon lands (the lowland counterpart to the
		# mountain-bound sleeper), so both dragon types actually show up.
		{"id": "green_dragon", "label": "Green Dragon", "tile": Vector2i(18, 0)},
		{"id": "molten_perch", "label": "Molten Perch"},
		{"id": "treasure_scatter", "label": "Treasure Scatter"},
		{"id": "windworn_ledge", "label": "Windworn Ledge"},
		{"id": "skycoil_outlook", "label": "Skycoil Outlook"}
	],
	# The wider folk of the world (browser AMBIENT_STRUCTURE_OPTIONS):
	# every land culture leaves its mark on its own territory.
	# Dwarves are folk of the deep stone: their ambient marks only rise on
	# mountains (peaks or mountain overlays), never out on the open lowlands.
	"dwarves": [
		{"id": "prospect_camp", "label": "Prospector's Camp", "tile": Vector2i(7, 1), "requires_mountain": true},
		{"id": "homestead", "label": "Mountain Homestead", "tile": Vector2i(13, 1), "requires_mountain": true}
	],
	"half_orcs": [
		{"id": "hunting_lodge", "label": "Hunting Lodge", "tile": Vector2i(16, 0), "requires_tree_overlay": true, "replace_tree_overlay": true},
		{"id": "war_camp", "label": "War Camp", "tile": Vector2i(11, 3), "requires_plain_grass": true},
		# Orcs mark their ground: a war banner (atlas 16,2) and a rough
		# watchtower (17,2). No terrain gate so they show across orc lands
		# (grassland/badlands/desert), not just plain grass.
		{"id": "war_banner", "label": "War Banner", "tile": Vector2i(16, 2)},
		{"id": "orc_watchtower", "label": "Orc Watchtower", "tile": Vector2i(17, 2)}
	],
	"half_elves": [
		{"id": "homestead", "label": "Homestead", "tile": Vector2i(13, 1), "requires_plain_grass": true},
		{"id": "moonwell", "label": "Moonwell", "tile": Vector2i(2, 6), "requires_tree_neighbor": true, "requires_deep_forest": true}
	],
	"centaurs": [
		{"id": "centaur_camp", "label": "Centaur Camp", "tile": Vector2i(10, 2), "requires_plain_grass": true},
		{"id": "tent_camp", "label": "Tent Camp", "tile": Vector2i(1, 5), "requires_plain_grass": true}
	],
	"firbolg": [
		{"id": "great_tree", "label": "Elder Tree", "tile": Vector2i(14, 1), "requires_tree_overlay": true}
	],
	"gnomes": [
		{"id": "homestead", "label": "Gnomish Burrow", "tile": Vector2i(13, 1), "requires_plain_grass": true},
		{"id": "farm", "label": "Tinker's Plot", "tile": Vector2i(16, 2), "requires_plain_grass": true}
	],
	"aarakocra": [
		{"id": "cliff_aerie", "label": "Cliff Aerie", "tile": Vector2i(2, 2)}
	],
	"ogres": [
		{"id": "ogre_den", "label": "Ogre Den", "tile": Vector2i(9, 1)}
	],
	"trolls": [
		{"id": "troll_mound", "label": "Troll Mound", "tile": Vector2i(9, 0)}
	],
	"gnolls": [
		{"id": "gnoll_den", "label": "Gnoll Den", "tile": Vector2i(11, 0)}
	],
	"orc": [
		{"id": "orc_camp", "label": "Orc Camp", "tile": Vector2i(11, 3)},
		{"id": "war_pyre", "label": "War Pyre", "tile": Vector2i(13, 3)}
	],
	"hobgoblin": [
		{"id": "war_banner", "label": "War Banner Camp", "tile": Vector2i(10, 1)}
	],
	"quilboar": [
		{"id": "thorn_camp", "label": "Thorn Camp", "tile": Vector2i(11, 0)}
	],
	"blemaayae": [
		{"id": "wanderer_camp", "label": "Wanderers' Camp", "tile": Vector2i(7, 1)}
	],
	"braxat": [
		{"id": "raider_camp", "label": "Raider Camp", "tile": Vector2i(10, 1)}
	],
	"tuskar": [
		{"id": "hunting_lodge", "label": "Tusked Lodge", "tile": Vector2i(16, 0), "requires_tree_overlay": true, "replace_tree_overlay": true}
	],
	"fimir": [
		{"id": "bog_ruin", "label": "Bog Ruin", "tile": Vector2i(7, 2)}
	],
	"giants": [
		{"id": "giant_cairn", "label": "Giant's Cairn", "tile": Vector2i(9, 0)},
		{"id": "stone_cairn", "label": "Stone Cairn", "tile": Vector2i(5, 6)}
	],
	"harpies": [
		{"id": "harpy_roost", "label": "Harpy Roost", "tile": Vector2i(7, 2)}
	],
	"beastmen": [
		{"id": "hunting_lodge", "label": "Beast Lodge", "tile": Vector2i(16, 0), "requires_tree_overlay": true, "replace_tree_overlay": true}
	],
	"demons": [
		{"id": "profane_ruin", "label": "Profane Ruin", "tile": Vector2i(7, 2)},
		{"id": "dark_gate", "label": "Dark Gate", "tile": Vector2i(17, 1)},
		{"id": "dark_spire", "label": "Dark Spire", "tile": Vector2i(17, 2)}
	],
	"dryad": [
		{"id": "great_tree", "label": "Heart Tree", "tile": Vector2i(14, 1), "requires_tree_overlay": true}
	],
	"leshy": [
		{"id": "moonwell", "label": "Forest Shrine", "tile": Vector2i(2, 6), "requires_tree_neighbor": true, "requires_deep_forest": true}
	],
	"satyr": [
		{"id": "revel_camp", "label": "Revel Glade", "tile": Vector2i(7, 1), "requires_tree_neighbor": true}
	],
	"fae": [
		{"id": "moonwell", "label": "Fae Circle", "tile": Vector2i(2, 6), "requires_tree_neighbor": true, "requires_deep_forest": true}
	],
	"pygmy": [
		{"id": "hunting_lodge", "label": "Canopy Camp", "tile": Vector2i(16, 0), "requires_tree_overlay": true, "replace_tree_overlay": true}
	],
	"desert_folk": [
		{"id": "desert_hut", "label": "Desert Hut", "tile": Vector2i(9, 6)},
		{"id": "serpent_statue", "label": "Serpent Statue", "tile": Vector2i(9, 3)}
	],
	"snakemen": [
		{"id": "sunken_shrine", "label": "Sunken Shrine", "tile": Vector2i(7, 2)}
	]
}
