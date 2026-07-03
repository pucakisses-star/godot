extends RefCounted
class_name ItemDefsService

## The item catalog: every inventory item's icon and flavor line.
## Icons live in item_icons.png, a 12x12 atlas of 32px icons packed from
## the web game's Inventory tilesheets - rows 0-3 Mining (indices 0-47),
## rows 4-7 Mushroom (48-95), rows 8-11 Fishing (96-143). Items without
## an entry fall back to the old abbreviation text in slot UIs.

const ITEM_ICONS_TEXTURE := preload("res://resources/images/items/item_icons.png")
const ATLAS_COLUMNS := 12
const ICON_SIZE := 32

const ITEM_DEFS := {
	# --- raw materials & ores ---
	"Stone": {"icon": 44, "flavor": "Honest rock, the hold's first currency."},
	"Iron Ore": {"icon": 45, "flavor": "Rust-red and heavy. The forge is hungry."},
	"Copper Ore": {"icon": 15, "flavor": "Gleams warm even before the smelter."},
	"Gold Nugget": {"icon": 12, "flavor": "Enough to turn a merchant's head."},
	"Gem Shard": {"icon": 88, "flavor": "A splinter of buried starlight."},
	"Iron Ingot": {"icon": 30, "flavor": "Smelted and stamped by hold smiths."},
	"Stone Block": {"icon": 0, "flavor": "Quarried square and true."},
	"Leather Strap": {"icon": 46, "flavor": "Keeps armor, packs, and promises together."},

	# --- fossils & relics dug from the rock ---
	"Amber": {"icon": 2, "flavor": "Old sunlight, gone hard."},
	"Spider Amber": {"icon": 13, "flavor": "Something eight-legged sleeps inside."},
	"Fossil Leaf": {"icon": 19, "flavor": "A leaf from a forest no one remembers."},
	"Ancient Skull": {"icon": 14, "flavor": "It grins like it knows the way down."},
	"Fossil Claw": {"icon": 16, "flavor": "Whatever owned this, be glad it's gone."},
	"Ammonite Shell": {"icon": 23, "flavor": "A spiral older than the mountains."},
	"Old Bone": {"icon": 18, "flavor": "Dry, heavy, and oddly comforting."},
	"Serpent Spine": {"icon": 21, "flavor": "Coiled vertebrae of a deep-tunnel serpent."},
	"Runed Tablet": {"icon": 11, "flavor": "The script predates the First Delving."},

	# --- tools & treasures ---
	"Gold Trinket": {"icon": 31, "flavor": "An ornate key to nothing in particular."},
	"Skeleton Keys": {"icon": 47, "flavor": "Somewhere, doors are waiting."},
	"Rusty Pickaxe": {"icon": 24, "flavor": "It has one more tunnel in it. Maybe."},
	"Dwarven Pickaxe": {"icon": 26, "flavor": "Balanced steel, rune-stamped haft."},
	"Miner's Lantern": {"icon": 43, "flavor": "Brass-caged flame, the miner's true friend."},
	"Dynamite Stick": {"icon": 38, "flavor": "For when the pick isn't persuasive enough."},

	# --- fungi of the underdeep ---
	"Mushrooms": {"icon": 48, "flavor": "Cave-white and filling enough."},
	"Mushroom Ration": {"icon": 55, "flavor": "Dried, salted, and dwarf-approved."},
	"Spore Dust": {"icon": 87, "flavor": "Shimmers faintly when disturbed."},
	"Glowcap": {"icon": 70, "flavor": "Lights a lantern's worth on its own."},
	"Frostcap": {"icon": 75, "flavor": "Cold to the touch, colder to the tongue."},
	"Emberspore": {"icon": 71, "flavor": "Smolders quietly. Do not pocket carelessly."},
	"Violet Veil": {"icon": 63, "flavor": "Beautiful. Probably a warning."},
	"King Bolete": {"icon": 51, "flavor": "A feast wearing a little brown cap."},
	"Fairy Bells": {"icon": 90, "flavor": "They chime when no one is listening."},
	"Scarlet Cap": {"icon": 57, "flavor": "The classic. Cooks swear by it; healers swear at it."},

	# --- catch of the dark waters ---
	"Dried Fish": {"icon": 108, "flavor": "Traded up from the sunlit rivers."},
	"Blindcave Fish": {"icon": 107, "flavor": "Never saw it coming. Never saw anything."},
	"Cave Perch": {"icon": 98, "flavor": "The everyday catch of the underdeep lakes."},
	"Emerald Trout": {"icon": 100, "flavor": "Green as a grove it has never seen."},
	"Deep Eel": {"icon": 105, "flavor": "Longer than your arm and twice as unhappy."},
	"Ruby Snapper": {"icon": 106, "flavor": "Prized by hold cooks and hold jewelers alike."},
	"Violet Grouper": {"icon": 111, "flavor": "Fat, purple, and inexplicably smug."},
	"Silver Darter": {"icon": 112, "flavor": "A flash of moonlight in black water."},
	"Golden Koi": {"icon": 115, "flavor": "Luck made flesh, or so the miners insist."},
	"Cave Crab": {"icon": 123, "flavor": "All armor, mostly claw, surprisingly sweet."},
	"Coral Snail": {"icon": 125, "flavor": "Its shell spirals like the underdeep itself."},
	"Old Fishing Rod": {"icon": 133, "flavor": "Someone fished the dark lakes once."},
	"Rusted Hook": {"icon": 138, "flavor": "Big enough to worry about what it caught."},

	# --- trophies off the wild things ---
	"Lizard Scale": {"icon": 129, "flavor": "Iridescent and knife-hard."},
	"Orcish Tooth": {"icon": 7, "flavor": "Strung as a warning, kept as a prize."}
}

static var _texture_cache: Dictionary = {}

static func has_icon(item_name: String) -> bool:
	return ITEM_DEFS.has(item_name)

static func flavor_text(item_name: String) -> String:
	var def := ITEM_DEFS.get(item_name, {}) as Dictionary
	return String(def.get("flavor", ""))

static func icon_texture(item_name: String) -> Texture2D:
	if not ITEM_DEFS.has(item_name):
		return null
	if _texture_cache.has(item_name):
		return _texture_cache[item_name] as Texture2D
	var icon_index := int((ITEM_DEFS[item_name] as Dictionary).get("icon", 0))
	var atlas := AtlasTexture.new()
	atlas.atlas = ITEM_ICONS_TEXTURE
	atlas.region = Rect2(
		(icon_index % ATLAS_COLUMNS) * ICON_SIZE,
		(icon_index / ATLAS_COLUMNS) * ICON_SIZE,
		ICON_SIZE,
		ICON_SIZE
	)
	_texture_cache[item_name] = atlas
	return atlas

static func slot_tooltip(item_name: String, quantity: int) -> String:
	var tooltip := "%s ×%d" % [item_name, quantity]
	var flavor := flavor_text(item_name)
	if not flavor.is_empty():
		tooltip += "\n" + flavor
	return tooltip
