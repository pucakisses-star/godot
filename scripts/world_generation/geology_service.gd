extends RefCounted
class_name GeologyService

## Real-petrology geology, derived deterministically from the world seed
## and each tile's terrain — no storage, recomputed on demand. Every land
## tile gets a layer class (its country-rock family), a stratigraphic
## column of NAMED real rocks drawn from that family's catalog, ore
## MINERALS hosted in the right rock (hematite in sediments, cassiterite
## in granite country, pentlandite in ultramafics), gem species, rare
## geological formations (kimberlite pipes, pegmatite dikes, coal seams,
## karst, evaporites), soil, clay and aquifers. The hold's mining and the
## seamless underhall strata read the same profile, so what the map
## promises, the pick finds.

const LAYER_SEDIMENTARY := "sedimentary"
const LAYER_IGNEOUS_EXTRUSIVE := "igneous_extrusive"
const LAYER_IGNEOUS_INTRUSIVE := "igneous_intrusive"
const LAYER_METAMORPHIC := "metamorphic"

const LAYER_LABELS := {
	LAYER_SEDIMENTARY: "Sedimentary",
	LAYER_IGNEOUS_EXTRUSIVE: "Igneous (volcanic)",
	LAYER_IGNEOUS_INTRUSIVE: "Igneous (deep)",
	LAYER_METAMORPHIC: "Metamorphic"
}

## --- The stone catalog -------------------------------------------------------
## Every rock the world can be made of: real stones with their family,
## a Mohs-flavored hardness (feeds dig durability), and a wall tint the
## underhalls carve in. "kind" subdivides the family the way a field
## geologist would (clastic vs chemical sediments, foliated vs not).

const STONE_CATALOG := {
	# Sedimentary — clastic.
	"Sandstone": {"class": LAYER_SEDIMENTARY, "kind": "clastic", "hardness": 3, "tint": Color(1.04, 1.0, 0.9)},
	"Arkose": {"class": LAYER_SEDIMENTARY, "kind": "clastic", "hardness": 3, "tint": Color(1.05, 0.98, 0.9)},
	"Greywacke": {"class": LAYER_SEDIMENTARY, "kind": "clastic", "hardness": 4, "tint": Color(0.96, 0.96, 0.94)},
	"Quartz Arenite": {"class": LAYER_SEDIMENTARY, "kind": "clastic", "hardness": 4, "tint": Color(1.04, 1.02, 0.96)},
	"Siltstone": {"class": LAYER_SEDIMENTARY, "kind": "clastic", "hardness": 3, "tint": Color(1.0, 0.98, 0.9)},
	"Mudstone": {"class": LAYER_SEDIMENTARY, "kind": "clastic", "hardness": 2, "tint": Color(0.98, 0.95, 0.88)},
	"Claystone": {"class": LAYER_SEDIMENTARY, "kind": "clastic", "hardness": 2, "tint": Color(1.0, 0.94, 0.86)},
	"Shale": {"class": LAYER_SEDIMENTARY, "kind": "clastic", "hardness": 2, "tint": Color(0.94, 0.93, 0.92)},
	"Oil Shale": {"class": LAYER_SEDIMENTARY, "kind": "clastic", "hardness": 2, "tint": Color(0.9, 0.88, 0.84)},
	"Conglomerate": {"class": LAYER_SEDIMENTARY, "kind": "clastic", "hardness": 3, "tint": Color(1.0, 0.97, 0.9)},
	"Breccia": {"class": LAYER_SEDIMENTARY, "kind": "clastic", "hardness": 3, "tint": Color(1.0, 0.95, 0.9)},
	"Marl": {"class": LAYER_SEDIMENTARY, "kind": "clastic", "hardness": 2, "tint": Color(1.0, 0.99, 0.92)},
	# Sedimentary — chemical and biochemical.
	"Limestone": {"class": LAYER_SEDIMENTARY, "kind": "chemical", "hardness": 3, "tint": Color(1.04, 1.03, 0.96), "flux": true},
	"Chalk": {"class": LAYER_SEDIMENTARY, "kind": "chemical", "hardness": 1, "tint": Color(1.06, 1.06, 1.02), "flux": true},
	"Coquina": {"class": LAYER_SEDIMENTARY, "kind": "chemical", "hardness": 2, "tint": Color(1.05, 1.02, 0.94)},
	"Travertine": {"class": LAYER_SEDIMENTARY, "kind": "chemical", "hardness": 3, "tint": Color(1.05, 1.0, 0.9)},
	"Tufa": {"class": LAYER_SEDIMENTARY, "kind": "chemical", "hardness": 2, "tint": Color(1.04, 1.02, 0.94)},
	"Dolomite": {"class": LAYER_SEDIMENTARY, "kind": "chemical", "hardness": 4, "tint": Color(1.0, 1.0, 0.94), "flux": true},
	"Chert": {"class": LAYER_SEDIMENTARY, "kind": "chemical", "hardness": 6, "tint": Color(0.96, 0.94, 0.88)},
	"Flint": {"class": LAYER_SEDIMENTARY, "kind": "chemical", "hardness": 6, "tint": Color(0.9, 0.9, 0.88)},
	"Ironstone": {"class": LAYER_SEDIMENTARY, "kind": "chemical", "hardness": 4, "tint": Color(1.0, 0.9, 0.82)},
	"Phosphorite": {"class": LAYER_SEDIMENTARY, "kind": "chemical", "hardness": 3, "tint": Color(0.96, 0.94, 0.86)},
	"Diatomite": {"class": LAYER_SEDIMENTARY, "kind": "chemical", "hardness": 1, "tint": Color(1.06, 1.05, 1.0)},
	"Gypsum": {"class": LAYER_SEDIMENTARY, "kind": "evaporite", "hardness": 1, "tint": Color(1.06, 1.04, 0.98)},
	"Anhydrite": {"class": LAYER_SEDIMENTARY, "kind": "evaporite", "hardness": 2, "tint": Color(1.02, 1.02, 0.98)},
	"Rock Salt": {"class": LAYER_SEDIMENTARY, "kind": "evaporite", "hardness": 1, "tint": Color(1.05, 1.03, 1.0)},
	# Igneous — extrusive (volcanic).
	"Basalt": {"class": LAYER_IGNEOUS_EXTRUSIVE, "kind": "mafic", "hardness": 6, "tint": Color(0.86, 0.86, 0.88)},
	"Vesicular Basalt": {"class": LAYER_IGNEOUS_EXTRUSIVE, "kind": "mafic", "hardness": 5, "tint": Color(0.88, 0.87, 0.88)},
	"Andesite": {"class": LAYER_IGNEOUS_EXTRUSIVE, "kind": "intermediate", "hardness": 6, "tint": Color(0.92, 0.9, 0.9)},
	"Dacite": {"class": LAYER_IGNEOUS_EXTRUSIVE, "kind": "intermediate", "hardness": 6, "tint": Color(0.95, 0.93, 0.9)},
	"Rhyolite": {"class": LAYER_IGNEOUS_EXTRUSIVE, "kind": "felsic", "hardness": 6, "tint": Color(1.0, 0.94, 0.88)},
	"Obsidian": {"class": LAYER_IGNEOUS_EXTRUSIVE, "kind": "glass", "hardness": 5, "tint": Color(0.8, 0.8, 0.86)},
	"Pitchstone": {"class": LAYER_IGNEOUS_EXTRUSIVE, "kind": "glass", "hardness": 5, "tint": Color(0.84, 0.83, 0.84)},
	"Pumice": {"class": LAYER_IGNEOUS_EXTRUSIVE, "kind": "pyroclastic", "hardness": 2, "tint": Color(1.02, 1.0, 0.96)},
	"Scoria": {"class": LAYER_IGNEOUS_EXTRUSIVE, "kind": "pyroclastic", "hardness": 3, "tint": Color(0.92, 0.84, 0.8)},
	"Tuff": {"class": LAYER_IGNEOUS_EXTRUSIVE, "kind": "pyroclastic", "hardness": 3, "tint": Color(0.98, 0.94, 0.86)},
	"Ignimbrite": {"class": LAYER_IGNEOUS_EXTRUSIVE, "kind": "pyroclastic", "hardness": 5, "tint": Color(0.96, 0.9, 0.84)},
	"Trachyte": {"class": LAYER_IGNEOUS_EXTRUSIVE, "kind": "felsic", "hardness": 6, "tint": Color(0.97, 0.94, 0.9)},
	"Phonolite": {"class": LAYER_IGNEOUS_EXTRUSIVE, "kind": "felsic", "hardness": 6, "tint": Color(0.93, 0.94, 0.9)},
	"Komatiite": {"class": LAYER_IGNEOUS_EXTRUSIVE, "kind": "ultramafic", "hardness": 6, "tint": Color(0.88, 0.92, 0.86)},
	# Igneous — intrusive (plutonic).
	"Granite": {"class": LAYER_IGNEOUS_INTRUSIVE, "kind": "felsic", "hardness": 7, "tint": Color(1.0, 0.94, 0.9)},
	"Alkali Granite": {"class": LAYER_IGNEOUS_INTRUSIVE, "kind": "felsic", "hardness": 7, "tint": Color(1.02, 0.92, 0.88)},
	"Granodiorite": {"class": LAYER_IGNEOUS_INTRUSIVE, "kind": "felsic", "hardness": 7, "tint": Color(0.97, 0.94, 0.9)},
	"Tonalite": {"class": LAYER_IGNEOUS_INTRUSIVE, "kind": "intermediate", "hardness": 7, "tint": Color(0.95, 0.94, 0.92)},
	"Diorite": {"class": LAYER_IGNEOUS_INTRUSIVE, "kind": "intermediate", "hardness": 7, "tint": Color(0.92, 0.92, 0.92)},
	"Monzonite": {"class": LAYER_IGNEOUS_INTRUSIVE, "kind": "intermediate", "hardness": 7, "tint": Color(0.95, 0.92, 0.9)},
	"Syenite": {"class": LAYER_IGNEOUS_INTRUSIVE, "kind": "felsic", "hardness": 7, "tint": Color(0.98, 0.93, 0.88)},
	"Gabbro": {"class": LAYER_IGNEOUS_INTRUSIVE, "kind": "mafic", "hardness": 7, "tint": Color(0.86, 0.88, 0.9)},
	"Norite": {"class": LAYER_IGNEOUS_INTRUSIVE, "kind": "mafic", "hardness": 7, "tint": Color(0.87, 0.88, 0.88)},
	"Troctolite": {"class": LAYER_IGNEOUS_INTRUSIVE, "kind": "mafic", "hardness": 7, "tint": Color(0.88, 0.89, 0.92)},
	"Anorthosite": {"class": LAYER_IGNEOUS_INTRUSIVE, "kind": "mafic", "hardness": 6, "tint": Color(0.96, 0.96, 0.98)},
	"Peridotite": {"class": LAYER_IGNEOUS_INTRUSIVE, "kind": "ultramafic", "hardness": 6, "tint": Color(0.86, 0.92, 0.84)},
	"Dunite": {"class": LAYER_IGNEOUS_INTRUSIVE, "kind": "ultramafic", "hardness": 6, "tint": Color(0.88, 0.94, 0.82)},
	"Pyroxenite": {"class": LAYER_IGNEOUS_INTRUSIVE, "kind": "ultramafic", "hardness": 6, "tint": Color(0.85, 0.88, 0.85)},
	"Aplite": {"class": LAYER_IGNEOUS_INTRUSIVE, "kind": "felsic", "hardness": 7, "tint": Color(1.02, 0.98, 0.94)},
	"Carbonatite": {"class": LAYER_IGNEOUS_INTRUSIVE, "kind": "rare", "hardness": 4, "tint": Color(0.98, 0.96, 0.9)},
	# Metamorphic — foliated.
	"Slate": {"class": LAYER_METAMORPHIC, "kind": "foliated", "hardness": 4, "tint": Color(0.88, 0.89, 0.92)},
	"Phyllite": {"class": LAYER_METAMORPHIC, "kind": "foliated", "hardness": 4, "tint": Color(0.9, 0.9, 0.93)},
	"Mica Schist": {"class": LAYER_METAMORPHIC, "kind": "foliated", "hardness": 5, "tint": Color(0.94, 0.92, 0.88)},
	"Garnet Schist": {"class": LAYER_METAMORPHIC, "kind": "foliated", "hardness": 5, "tint": Color(0.96, 0.88, 0.86)},
	"Talc Schist": {"class": LAYER_METAMORPHIC, "kind": "foliated", "hardness": 2, "tint": Color(0.94, 0.96, 0.92)},
	"Greenschist": {"class": LAYER_METAMORPHIC, "kind": "foliated", "hardness": 4, "tint": Color(0.88, 0.95, 0.88)},
	"Blueschist": {"class": LAYER_METAMORPHIC, "kind": "foliated", "hardness": 5, "tint": Color(0.87, 0.9, 0.97)},
	"Gneiss": {"class": LAYER_METAMORPHIC, "kind": "foliated", "hardness": 7, "tint": Color(0.95, 0.93, 0.9)},
	"Augen Gneiss": {"class": LAYER_METAMORPHIC, "kind": "foliated", "hardness": 7, "tint": Color(0.96, 0.92, 0.88)},
	"Migmatite": {"class": LAYER_METAMORPHIC, "kind": "foliated", "hardness": 7, "tint": Color(0.97, 0.92, 0.86)},
	"Mylonite": {"class": LAYER_METAMORPHIC, "kind": "foliated", "hardness": 6, "tint": Color(0.9, 0.89, 0.88)},
	"Amphibolite": {"class": LAYER_METAMORPHIC, "kind": "foliated", "hardness": 6, "tint": Color(0.85, 0.89, 0.86)},
	# Metamorphic — non-foliated.
	"Quartzite": {"class": LAYER_METAMORPHIC, "kind": "nonfoliated", "hardness": 8, "tint": Color(1.0, 0.99, 0.96)},
	"Marble": {"class": LAYER_METAMORPHIC, "kind": "nonfoliated", "hardness": 4, "tint": Color(1.04, 1.04, 1.02), "flux": true},
	"Dolomitic Marble": {"class": LAYER_METAMORPHIC, "kind": "nonfoliated", "hardness": 4, "tint": Color(1.02, 1.02, 0.98), "flux": true},
	"Hornfels": {"class": LAYER_METAMORPHIC, "kind": "nonfoliated", "hardness": 7, "tint": Color(0.89, 0.88, 0.86)},
	"Skarn": {"class": LAYER_METAMORPHIC, "kind": "nonfoliated", "hardness": 6, "tint": Color(0.93, 0.9, 0.84)},
	"Soapstone": {"class": LAYER_METAMORPHIC, "kind": "nonfoliated", "hardness": 2, "tint": Color(0.93, 0.95, 0.92)},
	"Serpentinite": {"class": LAYER_METAMORPHIC, "kind": "nonfoliated", "hardness": 4, "tint": Color(0.85, 0.94, 0.85)},
	"Granulite": {"class": LAYER_METAMORPHIC, "kind": "nonfoliated", "hardness": 7, "tint": Color(0.94, 0.92, 0.9)},
	"Eclogite": {"class": LAYER_METAMORPHIC, "kind": "nonfoliated", "hardness": 8, "tint": Color(0.88, 0.92, 0.88)},
	"Novaculite": {"class": LAYER_METAMORPHIC, "kind": "nonfoliated", "hardness": 8, "tint": Color(1.0, 1.0, 0.97)}
}

## Stones a family column draws from routinely (rare stones enter only
## through formations).
const COMMON_STONES := {
	LAYER_SEDIMENTARY: ["Sandstone", "Arkose", "Greywacke", "Quartz Arenite", "Siltstone", "Mudstone",
		"Claystone", "Shale", "Conglomerate", "Breccia", "Marl", "Limestone", "Chalk", "Coquina",
		"Travertine", "Dolomite", "Chert", "Flint", "Ironstone", "Phosphorite"],
	LAYER_IGNEOUS_EXTRUSIVE: ["Basalt", "Vesicular Basalt", "Andesite", "Dacite", "Rhyolite", "Obsidian",
		"Pitchstone", "Pumice", "Scoria", "Tuff", "Ignimbrite", "Trachyte", "Phonolite"],
	LAYER_IGNEOUS_INTRUSIVE: ["Granite", "Alkali Granite", "Granodiorite", "Tonalite", "Diorite",
		"Monzonite", "Syenite", "Gabbro", "Norite", "Troctolite", "Anorthosite", "Peridotite",
		"Dunite", "Pyroxenite", "Aplite"],
	LAYER_METAMORPHIC: ["Slate", "Phyllite", "Mica Schist", "Garnet Schist", "Greenschist", "Blueschist",
		"Gneiss", "Augen Gneiss", "Migmatite", "Amphibolite", "Quartzite", "Marble", "Dolomitic Marble",
		"Hornfels", "Soapstone", "Serpentinite", "Granulite", "Eclogite"]
}

## --- The mineral catalog -----------------------------------------------------
## Real ore minerals and gem species, each hosted where geology puts
## them: a class list, or specific stones (which bind tighter). "item"
## is the inventory good a strike pays out, so the economy stays whole.

const MINERAL_CATALOG := {
	# Iron.
	# Hematite spans sediments, lavas and metamorphosed banded iron alike.
	"Hematite": {"metal": "Iron", "item": "Iron Ore", "hosts": [LAYER_SEDIMENTARY, LAYER_IGNEOUS_EXTRUSIVE, LAYER_METAMORPHIC], "weight": 30},
	"Magnetite": {"metal": "Iron", "item": "Iron Ore", "hosts": [LAYER_IGNEOUS_INTRUSIVE, LAYER_METAMORPHIC], "weight": 22},
	"Limonite": {"metal": "Iron", "item": "Iron Ore", "hosts": [LAYER_SEDIMENTARY], "weight": 16},
	"Siderite": {"metal": "Iron", "item": "Iron Ore", "hosts": [LAYER_SEDIMENTARY], "weight": 10},
	"Goethite": {"metal": "Iron", "item": "Iron Ore", "hosts": [LAYER_SEDIMENTARY], "weight": 8},
	"Bog Iron": {"metal": "Iron", "item": "Iron Ore", "hosts": [LAYER_SEDIMENTARY], "weight": 6, "biomes": ["marsh"]},
	"Pyrite": {"metal": "Iron", "item": "Iron Ore", "hosts": [LAYER_SEDIMENTARY, LAYER_METAMORPHIC, LAYER_IGNEOUS_INTRUSIVE], "weight": 10, "note": "fool's gold"},
	# Copper.
	"Native Copper": {"metal": "Copper", "item": "Copper Ore", "stones": ["Basalt", "Vesicular Basalt"], "weight": 12},
	"Malachite": {"metal": "Copper", "item": "Copper Ore", "hosts": [LAYER_SEDIMENTARY], "weight": 18},
	"Azurite": {"metal": "Copper", "item": "Copper Ore", "hosts": [LAYER_SEDIMENTARY], "weight": 10},
	"Chalcopyrite": {"metal": "Copper", "item": "Copper Ore", "hosts": [LAYER_IGNEOUS_INTRUSIVE, LAYER_METAMORPHIC], "weight": 22},
	"Bornite": {"metal": "Copper", "item": "Copper Ore", "hosts": [LAYER_IGNEOUS_INTRUSIVE], "weight": 10},
	"Chalcocite": {"metal": "Copper", "item": "Copper Ore", "hosts": [LAYER_SEDIMENTARY, LAYER_IGNEOUS_INTRUSIVE], "weight": 8},
	"Cuprite": {"metal": "Copper", "item": "Copper Ore", "hosts": [LAYER_SEDIMENTARY], "weight": 6},
	# Tin, lead, zinc.
	"Cassiterite": {"metal": "Tin", "item": "Tin Ore", "stones": ["Granite", "Alkali Granite", "Aplite", "Pegmatite"], "weight": 16},
	"Galena": {"metal": "Lead", "item": "Lead Ore", "stones": ["Limestone", "Dolomite", "Marble", "Dolomitic Marble"], "weight": 18, "silver_bearing": true},
	"Cerussite": {"metal": "Lead", "item": "Lead Ore", "hosts": [LAYER_SEDIMENTARY], "weight": 6},
	"Sphalerite": {"metal": "Zinc", "item": "Zinc Ore", "stones": ["Limestone", "Dolomite", "Marble", "Skarn"], "weight": 14},
	"Smithsonite": {"metal": "Zinc", "item": "Zinc Ore", "hosts": [LAYER_SEDIMENTARY], "weight": 6},
	# Silver and gold.
	"Native Silver": {"metal": "Silver", "item": "Silver Ore", "hosts": [LAYER_IGNEOUS_INTRUSIVE], "weight": 8},
	"Acanthite": {"metal": "Silver", "item": "Silver Ore", "hosts": [LAYER_IGNEOUS_INTRUSIVE, LAYER_METAMORPHIC], "weight": 8},
	"Native Gold": {"metal": "Gold", "item": "Gold Ore", "hosts": [LAYER_IGNEOUS_INTRUSIVE, LAYER_METAMORPHIC], "weight": 10},
	# Placers wash out of gold-bearing highlands into their own gravels.
	"Placer Gold": {"metal": "Gold", "item": "Gold Nugget", "hosts": [LAYER_SEDIMENTARY, LAYER_METAMORPHIC], "weight": 6, "placer": true},
	"Electrum": {"metal": "Gold", "item": "Gold Ore", "hosts": [LAYER_IGNEOUS_INTRUSIVE], "weight": 4},
	# Nickel, platinum (ultramafic country).
	"Pentlandite": {"metal": "Nickel", "item": "Nickel Ore", "stones": ["Peridotite", "Dunite", "Norite", "Pyroxenite", "Komatiite"], "weight": 12},
	"Garnierite": {"metal": "Nickel", "item": "Nickel Ore", "stones": ["Serpentinite"], "weight": 8},
	"Native Platinum": {"metal": "Platinum", "item": "Platinum Ore", "stones": ["Dunite", "Peridotite"], "weight": 5},
	# Coal (its rank rides the formation roll).
	"Coal Seam": {"metal": "Coal", "item": "Coal", "hosts": [LAYER_SEDIMENTARY], "weight": 14, "seam": true}
}

## Gem species with their true habitats. All pay Gem Shard unless a
## dedicated item exists (Moss Agate, Amber).
const GEM_CATALOG := {
	"Diamond": {"item": "Gem Shard", "stones": ["Kimberlite"], "weight": 20},
	"Ruby": {"item": "Gem Shard", "stones": ["Marble", "Dolomitic Marble"], "weight": 6},
	"Sapphire": {"item": "Gem Shard", "stones": ["Marble", "Syenite"], "weight": 6},
	"Emerald": {"item": "Gem Shard", "stones": ["Pegmatite", "Mica Schist"], "weight": 5},
	"Aquamarine": {"item": "Gem Shard", "stones": ["Pegmatite", "Granite"], "weight": 5},
	"Garnet": {"item": "Gem Shard", "stones": ["Garnet Schist", "Gneiss", "Eclogite"], "weight": 10},
	"Topaz": {"item": "Gem Shard", "stones": ["Rhyolite", "Pegmatite", "Granite"], "weight": 6},
	"Tourmaline": {"item": "Gem Shard", "stones": ["Pegmatite", "Mica Schist"], "weight": 6},
	"Amethyst": {"item": "Gem Shard", "hosts": [LAYER_IGNEOUS_EXTRUSIVE], "weight": 8},
	"Moss Agate": {"item": "Moss Agate", "stones": ["Basalt", "Vesicular Basalt", "Andesite"], "weight": 8},
	"Jasper": {"item": "Gem Shard", "hosts": [LAYER_SEDIMENTARY, LAYER_IGNEOUS_EXTRUSIVE], "weight": 7},
	"Opal": {"item": "Gem Shard", "stones": ["Sandstone", "Rhyolite"], "weight": 5},
	"Jade": {"item": "Gem Shard", "stones": ["Serpentinite"], "weight": 6},
	"Lapis Lazuli": {"item": "Gem Shard", "stones": ["Marble"], "weight": 5},
	"Turquoise": {"item": "Gem Shard", "hosts": [LAYER_SEDIMENTARY], "weight": 4, "biomes": ["desert", "badlands"]},
	"Moonstone": {"item": "Gem Shard", "stones": ["Syenite", "Anorthosite"], "weight": 4},
	"Peridot": {"item": "Gem Shard", "stones": ["Peridotite", "Dunite"], "weight": 5},
	"Amber": {"item": "Amber", "hosts": [LAYER_SEDIMENTARY], "weight": 5, "coastal": true},
	"Onyx": {"item": "Gem Shard", "hosts": [LAYER_IGNEOUS_EXTRUSIVE], "weight": 4},
	"Carnelian": {"item": "Gem Shard", "hosts": [LAYER_SEDIMENTARY], "weight": 4},
	"Zircon": {"item": "Gem Shard", "hosts": [LAYER_IGNEOUS_INTRUSIVE], "weight": 4},
	"Spinel": {"item": "Gem Shard", "stones": ["Marble"], "weight": 4}
}

## Rare formations, each a real geological event: what it requires and
## what it adds to the tile. Stones listed here join the column; extra
## minerals/gems join the pools.
const FORMATION_CATALOG := {
	"Kimberlite Pipe": {"classes": [LAYER_IGNEOUS_INTRUSIVE, LAYER_METAMORPHIC], "chance": 0.03,
		"stones": ["Kimberlite"], "gems": ["Diamond"], "label": "kimberlite pipe"},
	"Pegmatite Dikes": {"classes": [LAYER_IGNEOUS_INTRUSIVE], "chance": 0.12,
		"stones": ["Pegmatite"], "gems": ["Emerald", "Aquamarine", "Tourmaline", "Topaz"],
		"minerals": ["Cassiterite"], "label": "pegmatite dikes"},
	"Evaporite Beds": {"classes": [LAYER_SEDIMENTARY], "chance": 0.1, "biomes": ["desert", "badlands"],
		"stones": ["Rock Salt", "Gypsum", "Anhydrite"], "label": "evaporite beds"},
	"Coal Measures": {"classes": [LAYER_SEDIMENTARY], "chance": 0.4,
		"stones": ["Oil Shale"], "minerals": ["Coal Seam"], "label": "coal measures"},
	"Banded Iron": {"classes": [LAYER_METAMORPHIC, LAYER_SEDIMENTARY], "chance": 0.07,
		"stones": ["Ironstone"], "minerals": ["Hematite", "Magnetite"], "label": "banded iron formation"},
	"Skarn Contact": {"classes": [LAYER_IGNEOUS_INTRUSIVE, LAYER_METAMORPHIC], "chance": 0.09,
		"stones": ["Skarn", "Hornfels"], "minerals": ["Chalcopyrite", "Magnetite", "Sphalerite"],
		"gems": ["Garnet"], "label": "skarn contact zone"},
	"Karst Caves": {"classes": [LAYER_SEDIMENTARY], "chance": 0.14, "needs_wet": true,
		"needs_stones": ["Limestone", "Dolomite", "Chalk"], "label": "karst cave systems"},
	"Geode Pockets": {"classes": [LAYER_IGNEOUS_EXTRUSIVE], "chance": 0.12,
		"gems": ["Amethyst", "Moss Agate", "Onyx"], "label": "geode pockets"},
	"Placer Deposits": {"classes": [LAYER_SEDIMENTARY, LAYER_METAMORPHIC], "chance": 0.08, "needs_wet": true,
		"minerals": ["Placer Gold"], "label": "placer deposits"},
	"Carbonatite Intrusion": {"classes": [LAYER_IGNEOUS_INTRUSIVE], "chance": 0.04,
		"stones": ["Carbonatite"], "label": "carbonatite intrusion"}
}

## Formation-only stones (not in the walk-up catalog above).
const FORMATION_STONES := {
	"Kimberlite": {"class": LAYER_IGNEOUS_INTRUSIVE, "kind": "rare", "hardness": 5, "tint": Color(0.85, 0.9, 0.94)},
	"Pegmatite": {"class": LAYER_IGNEOUS_INTRUSIVE, "kind": "rare", "hardness": 7, "tint": Color(1.03, 0.97, 0.94)}
}

const FLUX_STONES := ["Limestone", "Chalk", "Dolomite", "Marble", "Dolomitic Marble", "Coquina", "Travertine"]

## Hits a rock of each family takes (feeds the hold's mining durability);
## a specific stone's hardness refines it via stone_durability().
const LAYER_DURABILITY := {
	LAYER_SEDIMENTARY: 9,
	LAYER_IGNEOUS_EXTRUSIVE: 12,
	LAYER_METAMORPHIC: 14,
	LAYER_IGNEOUS_INTRUSIVE: 16
}

## A specific stone's dig durability from its real hardness (Mohs-ish
## 1..8 → 4..20 swings), falling back to the family number.
static func stone_durability(stone_name: String) -> int:
	var info := stone_info(stone_name)
	if info.is_empty():
		return 12
	return 4 + int(info.get("hardness", 4)) * 2

static func stone_info(stone_name: String) -> Dictionary:
	if STONE_CATALOG.has(stone_name):
		return STONE_CATALOG[stone_name] as Dictionary
	if FORMATION_STONES.has(stone_name):
		return FORMATION_STONES[stone_name] as Dictionary
	return {}

## Deeper hold levels progress toward harder country rock: whatever the
## surface family is, depth trends metamorphic then deep igneous.
static func layer_class_for_depth(profile: Dictionary, level_index: int) -> String:
	var surface_class := String(profile.get("layer_class", LAYER_SEDIMENTARY))
	if level_index <= 0:
		return surface_class
	if level_index == 1:
		if surface_class == LAYER_SEDIMENTARY or surface_class == LAYER_IGNEOUS_EXTRUSIVE:
			return LAYER_METAMORPHIC
		return surface_class
	return LAYER_IGNEOUS_INTRUSIVE

static func _hash01(x: int, y: int, seed_value: int) -> float:
	var h: int = x * 374761393 + y * 668265263 + seed_value * 2654435761
	h = int((h ^ (h >> 13)) * 1274126177)
	h = h ^ (h >> 16)
	var unsigned: int = h & 0xffffffff
	return float(unsigned) / 4294967295.0

## Geology for an overworld tile. tile_info is the map's _tile_data entry;
## water tiles return an empty profile.
static func profile_for_tile(coord: Vector2i, tile_info: Dictionary, map_seed: int) -> Dictionary:
	var base_biome := String(tile_info.get("base_biome", tile_info.get("biome_type", "grassland")))
	if base_biome == "water":
		return {}
	return _build_profile(
		coord.x,
		coord.y,
		map_seed,
		base_biome,
		String(tile_info.get("hill_overlay", "")),
		clampf(float(tile_info.get("volcano_proximity", 0.0)), 0.0, 1.0),
		clampf(float(tile_info.get("coast_proximity", 0.0)), 0.0, 1.0),
		clampf(float(tile_info.get("moisture", 0.5)), 0.0, 1.0)
	)

## Fallback geology for a hold opened without journey context (direct
## scene runs, old saves): fabricates plausible mountain terrain inputs
## from the seed so the profile is stable per world. Holds entered from
## the overworld use their own tile's profile instead.
static func profile_for_seed(seed_value: int) -> Dictionary:
	var moisture := 0.3 + _hash01(3, 17, seed_value) * 0.5
	var volcano := 0.4 if _hash01(11, 29, seed_value) < 0.12 else 0.0
	return _build_profile(7, 13, seed_value, "mountain", "mountain", volcano, _hash01(5, 23, seed_value) * 0.4, moisture)

static func _build_profile(
	x: int,
	y: int,
	seed_value: int,
	base_biome: String,
	hill_overlay: String,
	volcano_proximity: float,
	coast_proximity: float,
	moisture: float
) -> Dictionary:
	var is_mountain := hill_overlay == "mountain" or base_biome == "mountain"
	var class_roll := _hash01(x, y, seed_value + 0x6E01)
	var layer_class := LAYER_SEDIMENTARY
	if volcano_proximity > 0.25:
		layer_class = LAYER_IGNEOUS_EXTRUSIVE
	elif is_mountain:
		layer_class = LAYER_METAMORPHIC if class_roll < 0.5 else LAYER_IGNEOUS_INTRUSIVE
	elif base_biome == "marsh" or coast_proximity > 0.35:
		layer_class = LAYER_SEDIMENTARY
	elif base_biome == "desert" or base_biome == "badlands":
		layer_class = LAYER_SEDIMENTARY if class_roll < 0.55 else LAYER_IGNEOUS_EXTRUSIVE
	else:
		if class_roll < 0.45:
			layer_class = LAYER_SEDIMENTARY
		elif class_roll < 0.72:
			layer_class = LAYER_METAMORPHIC
		else:
			layer_class = LAYER_IGNEOUS_INTRUSIVE

	# Three to five named strata from the family catalog, ordered as the
	# column will carry them.
	var pool := (COMMON_STONES[layer_class] as Array).duplicate()
	var stones: Array[String] = []
	var stone_count := 3 + int(_hash01(x, y, seed_value + 0x6E02) * 2.99)
	for stone_index in range(stone_count):
		if pool.is_empty():
			break
		var pick := int(_hash01(x, y, seed_value + 0x6E10 + stone_index) * float(pool.size())) % pool.size()
		stones.append(String(pool[pick]))
		pool.remove_at(pick)
	if layer_class == LAYER_SEDIMENTARY and _hash01(x, y, seed_value + 0x6E03) < 0.55 and not _has_flux(stones):
		stones[0] = "Limestone"

	# The basement below the surface family: what the deep levels carve.
	var basement_pool := (COMMON_STONES[layer_class_for_depth({"layer_class": layer_class}, 1)] as Array).duplicate()
	var deep_pool := (COMMON_STONES[LAYER_IGNEOUS_INTRUSIVE] as Array).duplicate()
	var basement_stones: Array[String] = []
	for basement_index in range(2):
		if basement_pool.is_empty():
			break
		var pick := int(_hash01(x, y, seed_value + 0x6E40 + basement_index) * float(basement_pool.size())) % basement_pool.size()
		var stone_name := String(basement_pool[pick])
		basement_pool.remove_at(pick)
		if not stones.has(stone_name):
			basement_stones.append(stone_name)
	var deep_pick := int(_hash01(x, y, seed_value + 0x6E48) * float(deep_pool.size())) % deep_pool.size()
	var deep_stone := String(deep_pool[deep_pick])

	# Formations: each rolls independently against its own requirements.
	var formations: Array[String] = []
	var formation_index := 0
	for formation_name_variant: Variant in FORMATION_CATALOG.keys():
		formation_index += 1
		var formation := FORMATION_CATALOG[formation_name_variant] as Dictionary
		if not (formation.get("classes", []) as Array).has(layer_class):
			continue
		if formation.has("biomes") and not (formation.get("biomes", []) as Array).has(base_biome):
			continue
		if bool(formation.get("needs_wet", false)) and moisture <= 0.45:
			continue
		if formation.has("needs_stones"):
			var found := false
			for needed_variant: Variant in (formation.get("needs_stones", []) as Array):
				if stones.has(String(needed_variant)):
					found = true
					break
			if not found:
				continue
		if _hash01(x, y, seed_value + 0x6E60 + formation_index * 7) < float(formation.get("chance", 0.0)):
			formations.append(String(formation_name_variant))
			for formation_stone_variant: Variant in (formation.get("stones", []) as Array):
				var formation_stone := String(formation_stone_variant)
				if not stones.has(formation_stone):
					stones.append(formation_stone)

	var flux := _has_flux(stones)
	var coal := formations.has("Coal Measures")
	var coal_rank := ""
	if coal:
		var rank_roll := _hash01(x, y, seed_value + 0x6E09)
		coal_rank = "anthracite" if layer_class == LAYER_METAMORPHIC or rank_roll < 0.15 \
			else ("bituminous coal" if rank_roll < 0.6 else "lignite")

	# Soil depth from biome and wetness; flat wet lowlands carry the
	# deepest soil, mountains bare rock.
	var soil := "Shallow"
	if is_mountain or base_biome == "badlands":
		soil = "None" if _hash01(x, y, seed_value + 0x6E05) < 0.6 else "Shallow"
	elif base_biome == "marsh":
		soil = "Very deep"
	elif base_biome == "desert" or base_biome == "tundra":
		soil = "Shallow"
	elif moisture > 0.6:
		soil = "Very deep"
	elif moisture > 0.4:
		soil = "Deep"

	var clay := ""
	if base_biome != "desert" and moisture > 0.5 and (layer_class == LAYER_SEDIMENTARY or base_biome == "marsh"):
		clay = "Deep clay" if moisture > 0.7 and soil == "Very deep" else "Shallow clay"

	var aquifer := ""
	var porous := layer_class == LAYER_SEDIMENTARY or soil == "Deep" or soil == "Very deep"
	if porous and not is_mountain:
		if moisture > 0.75:
			aquifer = "Heavy aquifer"
		elif moisture > 0.5:
			aquifer = "Light aquifer"

	# Ore minerals hosted by this tile's actual column (surface stones,
	# basement and deep stone all offer their habitats), plus whatever
	# the formations inject.
	var column_stones: Array[String] = []
	column_stones.append_array(stones)
	column_stones.append_array(basement_stones)
	column_stones.append(deep_stone)
	var column_classes: Array[String] = [layer_class,
		layer_class_for_depth({"layer_class": layer_class}, 1), LAYER_IGNEOUS_INTRUSIVE]
	var minerals: Array[Dictionary] = []
	var mineral_index := 0
	for mineral_name_variant: Variant in MINERAL_CATALOG.keys():
		mineral_index += 1
		var mineral_name := String(mineral_name_variant)
		var mineral := MINERAL_CATALOG[mineral_name] as Dictionary
		if not _habitat_matches(mineral, column_classes, column_stones, base_biome):
			continue
		var presence := 0.22 + float(mineral.get("weight", 8)) * 0.012
		if _hash01(x, y, seed_value + 0x6E80 + mineral_index * 11) < presence:
			minerals.append({"name": mineral_name, "metal": String(mineral.get("metal", "")),
				"item": String(mineral.get("item", "Iron Ore"))})
	for formation_name: String in formations:
		var formation := FORMATION_CATALOG[formation_name] as Dictionary
		for extra_variant: Variant in (formation.get("minerals", []) as Array):
			var extra_name := String(extra_variant)
			if not _mineral_listed(minerals, extra_name):
				var extra := MINERAL_CATALOG[extra_name] as Dictionary
				minerals.append({"name": extra_name, "metal": String(extra.get("metal", "")),
					"item": String(extra.get("item", "Iron Ore"))})
	if minerals.is_empty():
		# No tile is barren: the commonest iron of the family seeps in.
		var default_iron := "Hematite" if layer_class == LAYER_SEDIMENTARY or layer_class == LAYER_IGNEOUS_EXTRUSIVE else "Magnetite"
		minerals.append({"name": default_iron, "metal": "Iron", "item": "Iron Ore"})

	# Gem species by habitat, plus formation gems.
	var gems: Array[Dictionary] = []
	var gem_index := 0
	for gem_name_variant: Variant in GEM_CATALOG.keys():
		gem_index += 1
		var gem_name := String(gem_name_variant)
		var gem := GEM_CATALOG[gem_name] as Dictionary
		if bool(gem.get("coastal", false)) and coast_proximity <= 0.3:
			continue
		if not _habitat_matches(gem, column_classes, column_stones, base_biome):
			continue
		if _hash01(x, y, seed_value + 0x6EA0 + gem_index * 13) < 0.16 + float(gem.get("weight", 5)) * 0.012:
			gems.append({"name": gem_name, "item": String(gem.get("item", "Gem Shard"))})
	for formation_name: String in formations:
		var formation := FORMATION_CATALOG[formation_name] as Dictionary
		for gem_extra_variant: Variant in (formation.get("gems", []) as Array):
			var gem_extra := String(gem_extra_variant)
			if not _mineral_listed(gems, gem_extra):
				gems.append({"name": gem_extra, "item": String((GEM_CATALOG[gem_extra] as Dictionary).get("item", "Gem Shard"))})

	# Legacy metals list: the unique metal names the minerals carry, so
	# every older consumer (hold dossiers, dig payouts) keeps working.
	var metals: Array[String] = []
	for mineral_entry: Dictionary in minerals:
		var metal := String(mineral_entry.get("metal", ""))
		if not metal.is_empty() and metal != "Coal" and not metals.has(metal):
			metals.append(metal)

	return {
		"layer_class": layer_class,
		"layer_label": String(LAYER_LABELS[layer_class]),
		"stones": stones,
		"basement_stones": basement_stones,
		"deep_stone": deep_stone,
		"soil": soil,
		"clay": clay,
		"aquifer": aquifer,
		"metals": metals,
		"minerals": minerals,
		"gems": gems,
		"formations": formations,
		"flux": flux,
		"coal": coal,
		"coal_rank": coal_rank
	}

## The stratigraphic column for a hold's deep levels: level 1 down. Each
## entry names the stone the level is carved through (soil first where
## the profile carries any, straight into rock on bare mountains), its
## family class, tint and durability - the underhall strata read this.
static func strata_column(profile: Dictionary, level_count: int) -> Array[Dictionary]:
	var column: Array[Dictionary] = []
	var stones: Array[String] = []
	for stone_variant: Variant in (profile.get("stones", []) as Array):
		stones.append(String(stone_variant))
	var basement: Array[String] = []
	for basement_variant: Variant in (profile.get("basement_stones", []) as Array):
		basement.append(String(basement_variant))
	var deep_stone := String(profile.get("deep_stone", "Granite"))
	var soil := String(profile.get("soil", "Shallow"))
	var ladder: Array[String] = []
	ladder.append_array(stones)
	ladder.append_array(basement)
	if ladder.is_empty():
		ladder.append(deep_stone)
	for level_index in range(maxi(level_count, 1)):
		if level_index == 0 and soil != "None":
			var soil_name := "Loamy Soil"
			match soil:
				"Very deep":
					soil_name = "Deep Loam"
				"Deep":
					soil_name = "Loamy Soil"
				_:
					soil_name = "Thin Soil over %s" % ladder[0]
			column.append({"stone": ladder[0], "name": soil_name, "soil": true,
				"class": String(profile.get("layer_class", LAYER_SEDIMENTARY)),
				"tint": Color(1.02, 0.99, 0.92)})
			continue
		# Bare-rock tiles and deeper levels walk the ladder; the last level
		# always reaches the deep stone.
		var rock_index := level_index - (0 if soil == "None" else 1)
		var stone_name := deep_stone
		if level_index >= level_count - 1:
			stone_name = deep_stone
		elif rock_index < ladder.size():
			stone_name = ladder[rock_index]
		var info := stone_info(stone_name)
		column.append({"stone": stone_name, "name": stone_name, "soil": false,
			"class": String(info.get("class", LAYER_IGNEOUS_INTRUSIVE)),
			"tint": info.get("tint", Color(1.0, 1.0, 1.0))})
	return column

static func _habitat_matches(entry: Dictionary, column_classes: Array[String], column_stones: Array[String], base_biome: String) -> bool:
	if entry.has("biomes") and not (entry.get("biomes", []) as Array).has(base_biome):
		return false
	if entry.has("stones"):
		for stone_variant: Variant in (entry.get("stones", []) as Array):
			if column_stones.has(String(stone_variant)):
				return true
		return false
	for class_variant: Variant in (entry.get("hosts", []) as Array):
		if column_classes.has(String(class_variant)):
			return true
	return false

static func _mineral_listed(entries: Array[Dictionary], entry_name: String) -> bool:
	for entry: Dictionary in entries:
		if String(entry.get("name", "")) == entry_name:
			return true
	return false

static func _has_flux(stones: Array[String]) -> bool:
	for stone: String in stones:
		if FLUX_STONES.has(stone):
			return true
	return false
