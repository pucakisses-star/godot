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
	"Stone Block": {"icon": 44, "flavor": "Quarried square and true."},
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
	"Orcish Tooth": {"icon": 7, "flavor": "Strung as a warning, kept as a prize."},

	# --- dishes off the cookfire ---
	"Grilled Fish": {"icon": 109, "flavor": "Charred crisp outside, flaking sweet within."},
	"Mushroom Skewer": {"icon": 80, "flavor": "Caps roasted on a pick haft, miner style."},
	"Hearty Stew": {"icon": 40, "flavor": "Fish, fungus, and firelight in one bowl."},

	# --- more fossils out of the dark rock ---
	"Chalk Ammonite": {"icon": 0, "flavor": "A pale spiral pressed into soft stone."},
	"Beast-Claw Charm": {"icon": 1, "flavor": "Claws and shells on a rotted cord."},
	"Fossil Ribs": {"icon": 3, "flavor": "Something big breathed here once."},
	"Beast Skull": {"icon": 4, "flavor": "Long-jawed and patient as stone."},
	"Petrified Bone": {"icon": 5, "flavor": "Green with age, hard as the rock around it."},
	"Fossil Fish": {"icon": 6, "flavor": "It swam here before there was a here."},
	"Skeletal Paw": {"icon": 8, "flavor": "Five claws, still reaching."},
	"Moss Agate": {"icon": 9, "flavor": "A garden sealed in a pebble."},
	"Fossil Antler": {"icon": 10, "flavor": "Shed in an age no calendar remembers."},
	"Fern Amber": {"icon": 17, "flavor": "A whole frond, caught mid-summer."},
	"Fossil Cluster": {"icon": 20, "flavor": "A knot of old bones grown into the stone."},
	"Fin Spines": {"icon": 22, "flavor": "A fan of needles off some deep swimmer."},

	# --- tools of the trade ---
	"Miner's Pickaxe": {"icon": 25, "flavor": "Standard issue for the third shift."},
	"Copper Pick": {"icon": 27, "flavor": "Soft metal, stubborn owner."},
	"Worn Pickaxe": {"icon": 28, "flavor": "The handle remembers a thousand swings."},
	"Steel Pickaxe": {"icon": 29, "flavor": "Sings when it bites the rock."},
	"Prospector's Trowel": {"icon": 32, "flavor": "For digging carefully, next to digging greedily."},
	"Spade": {"icon": 33, "flavor": "Turns soil, gravel, and arguments."},
	"Steel Trowel": {"icon": 34, "flavor": "The archaeologist's answer to the pickaxe."},
	"Wooden Mallet": {"icon": 35, "flavor": "Persuades pegs, tents, and stuck lids."},
	"Stone Hammer": {"icon": 36, "flavor": "Old-fashioned, like the best arguments."},
	"Geologist's Hammer": {"icon": 37, "flavor": "One end asks; the other insists."},
	"Oil Pot": {"icon": 39, "flavor": "Clay-cased fire. Handle gently."},
	"Silver Lantern": {"icon": 41, "flavor": "Burns clean and cold, like moonlight."},
	"Mason's Chisel": {"icon": 42, "flavor": "Every hall began with one of these."},

	# --- fungi of the deeper dark ---
	"Chanterelle": {"icon": 49, "flavor": "Golden, frilled, and worth the stooping."},
	"Wine Cap": {"icon": 50, "flavor": "Dark red and faintly sweet."},
	"Honey Fungus": {"icon": 52, "flavor": "Small, amber, quietly everywhere."},
	"Rosegill": {"icon": 53, "flavor": "Blushing gills under a ragged cap."},
	"Porcini": {"icon": 54, "flavor": "The fat king of the cook-pot."},
	"Sunshelf": {"icon": 56, "flavor": "A ledge of orange in the gloom."},
	"Bloodbolete": {"icon": 58, "flavor": "Bruises crimson at a touch."},
	"Oyster Cap": {"icon": 59, "flavor": "Pale shelves growing in polite rows."},
	"Inkcap": {"icon": 60, "flavor": "Melts to black ink by morning."},
	"Deep Puffball": {"icon": 61, "flavor": "Blue, round, and rude when squeezed."},
	"Scarlet Stem": {"icon": 62, "flavor": "Thin red legs under little hats."},
	"Gilded Parasol": {"icon": 64, "flavor": "Wide as a plate and twice as proud."},
	"Firegill Shelf": {"icon": 65, "flavor": "Striped in ember red and night blue."},
	"Flamecrest": {"icon": 66, "flavor": "Stands like a frozen campfire."},
	"Umber Dapperling": {"icon": 67, "flavor": "Dotted, dapper, and a little suspect."},
	"Violet Coral": {"icon": 68, "flavor": "Branches of purple in the still air."},
	"Wyrm's Tongue": {"icon": 69, "flavor": "Curled, red, and best not licked back."},
	"Ghost Funnel": {"icon": 72, "flavor": "White as a miner's midwinter."},
	"Cauliflower Fungus": {"icon": 73, "flavor": "A tangled head of pale gold."},
	"Black Morel": {"icon": 74, "flavor": "Honeycombed and dark as the deep."},
	"Ash Parasol": {"icon": 76, "flavor": "Speckled gray, calm as dust."},
	"Pink Bonnet": {"icon": 77, "flavor": "A wide pink lip on a slender neck."},
	"Chestnut Bonnet": {"icon": 78, "flavor": "Two small brown heads, always nodding."},
	"Verdigris Shelf": {"icon": 79, "flavor": "Green-gray like old copper roofs."},
	"Weeping Olive": {"icon": 81, "flavor": "Beads of dew it never earned."},
	"Coral Frill": {"icon": 82, "flavor": "Orange lace off a cave reef."},
	"Pale Umbrella": {"icon": 83, "flavor": "Three white canopies, no rain to keep off."},
	"Star Fungus": {"icon": 84, "flavor": "A green star fallen very far indeed."},
	"Mahogany Cap": {"icon": 85, "flavor": "Polished brown, cabinet-worthy."},
	"Nightgill": {"icon": 86, "flavor": "Purple-black frills that drink the lamplight."},
	"Amber Shelf": {"icon": 89, "flavor": "Waves of orange stacked on the stone."},
	"Rose Puff": {"icon": 91, "flavor": "Rosy globes on thin green stems."},
	"Fire Coral": {"icon": 92, "flavor": "Red antlers of the fungal deep."},
	"Seafoam Parasol": {"icon": 93, "flavor": "Teal caps like a tide that never came."},
	"Dragonmane": {"icon": 94, "flavor": "Curls of red and gold, faintly warm."},
	"Banded Stalk": {"icon": 95, "flavor": "Ringed like a tree, soft as bread."},

	# --- more catch from the dark lakes ---
	"Striped Bass": {"icon": 96, "flavor": "Barred silver and orange, strong on the line."},
	"Marigold Carp": {"icon": 97, "flavor": "Round, golden, and cheerfully dim."},
	"Cobalt Chub": {"icon": 99, "flavor": "Blue-green and quick through the shallows."},
	"Crimson Carp": {"icon": 101, "flavor": "Broad red flanks, deep lake pride."},
	"Flicker Minnow": {"icon": 102, "flavor": "Gone before you're sure you saw it."},
	"Amethyst Angelfish": {"icon": 103, "flavor": "Purple and gold, dressed for a feast."},
	"Duskfin": {"icon": 104, "flavor": "Twilight-colored and shy of torchlight."},
	"Frilled Loach": {"icon": 110, "flavor": "Whiskered, ruffled, oddly dignified."},
	"Jade Carp": {"icon": 113, "flavor": "Leaps like it has somewhere better to be."},
	"Blossom Koi": {"icon": 114, "flavor": "Red on white, a painting that swims."},
	"Bloodfin": {"icon": 116, "flavor": "Deep red and none too friendly."},
	"Speckled Prawn": {"icon": 117, "flavor": "Pink, spotted, and sweet as a secret."},
	"Copperback Trout": {"icon": 118, "flavor": "Burnished scales over green depths."},
	"Sapphire Perch": {"icon": 119, "flavor": "Blue and yellow, bright as a banner."},
	"Gloom Octopus": {"icon": 120, "flavor": "Eight arms and no opinions it will share."},
	"Pale Squid": {"icon": 121, "flavor": "Bone-white and curious about your lantern."},
	"Ember Squid": {"icon": 122, "flavor": "Glows faintly, like coals underwater."},
	"Cave Lobster": {"icon": 124, "flavor": "Armored, orange, and worth the pinch."},
	"Silverfry": {"icon": 128, "flavor": "A whole school in one lucky scoop."},
	"Bloodworm": {"icon": 126, "flavor": "Bait, mostly. Dinner, desperately."},
	"Mud Grub": {"icon": 127, "flavor": "The lake floor's least glamorous citizen."},

	# --- tackle and lake salvage ---
	"Jig Lures": {"icon": 130, "flavor": "A jangle of hooks that promise everything."},
	"Painted Lure": {"icon": 131, "flavor": "Prettier than any real fish down here."},
	"Willow Rod": {"icon": 132, "flavor": "Light, whippy, and quick to the strike."},
	"Oak Rod": {"icon": 134, "flavor": "Heavy, patient, built for the big ones."},
	"Fishing Spear": {"icon": 135, "flavor": "For anglers who hate waiting."},
	"Casting Net": {"icon": 136, "flavor": "Weighted corners, wide ambitions."},
	"Fish Trap": {"icon": 137, "flavor": "Wicker patience. Set it and walk away."},
	"Barbed Hook": {"icon": 139, "flavor": "Once in, never out."},
	"Grappling Hook": {"icon": 140, "flavor": "Three claws, many bad ideas."},
	"Rusty Anchor": {"icon": 141, "flavor": "Someone sailed these waters. Somehow."},
	"Silk Line Spool": {"icon": 142, "flavor": "Spider-silk line, strong as regret."},
	"Cork Bobber": {"icon": 143, "flavor": "It floats. That is its entire job."}
}

## Everything edible: how much it heals, and (for raw food) the dish a
## cookfire turns it into. One raw fish plus one raw mushroom cooked
## together make a Hearty Stew instead of their single dishes.
const FOOD_DEFS := {
	# --- raw catch (cooks into Grilled Fish) ---
	"Cave Perch": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Silver Darter": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Emerald Trout": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Ruby Snapper": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Blindcave Fish": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Deep Eel": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Violet Grouper": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Golden Koi": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Cave Crab": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Coral Snail": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Dried Fish": {"heal": 5},

	# --- raw fungi (cook into Mushroom Skewer) ---
	"Mushrooms": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Glowcap": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Frostcap": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Emberspore": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Violet Veil": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"King Bolete": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Fairy Bells": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Scarlet Cap": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Mushroom Ration": {"heal": 5},

	# --- cooked dishes ---
	"Grilled Fish": {"heal": 8},
	"Mushroom Skewer": {"heal": 6},
	"Hearty Stew": {"heal": 14},

	# --- town provisions ---
	"Loaf of Bread": {"heal": 4},
	"Wheel of Cheese": {"heal": 6},
	"Jar of Honey": {"heal": 5},

	# --- the deeper dark's fungi (all skewer-ready) ---
	"Chanterelle": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Wine Cap": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Honey Fungus": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Rosegill": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Porcini": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Sunshelf": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Bloodbolete": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Oyster Cap": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Inkcap": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Deep Puffball": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Scarlet Stem": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Gilded Parasol": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Firegill Shelf": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Flamecrest": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Umber Dapperling": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Violet Coral": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Wyrm's Tongue": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Ghost Funnel": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Cauliflower Fungus": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Black Morel": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Ash Parasol": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Pink Bonnet": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Chestnut Bonnet": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Verdigris Shelf": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Weeping Olive": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Coral Frill": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Pale Umbrella": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Star Fungus": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Mahogany Cap": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Nightgill": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Amber Shelf": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Rose Puff": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Fire Coral": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Seafoam Parasol": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Dragonmane": {"heal": 2, "cooked_into": "Mushroom Skewer"},
	"Banded Stalk": {"heal": 2, "cooked_into": "Mushroom Skewer"},

	# --- the wider catch (all grill-ready) ---
	"Striped Bass": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Marigold Carp": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Cobalt Chub": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Crimson Carp": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Flicker Minnow": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Amethyst Angelfish": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Duskfin": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Frilled Loach": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Jade Carp": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Blossom Koi": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Bloodfin": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Speckled Prawn": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Copperback Trout": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Sapphire Perch": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Gloom Octopus": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Pale Squid": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Ember Squid": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Cave Lobster": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Silverfry": {"heal": 3, "cooked_into": "Grilled Fish"},
	"Bloodworm": {"heal": 1},
	"Mud Grub": {"heal": 1}
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

static func is_edible(item_name: String) -> bool:
	return FOOD_DEFS.has(item_name)

static func heal_amount(item_name: String) -> int:
	var def := FOOD_DEFS.get(item_name, {}) as Dictionary
	return int(def.get("heal", 0))

## The dish this raw item cooks into, or "" when it cannot be cooked.
static func cooked_result(item_name: String) -> String:
	var def := FOOD_DEFS.get(item_name, {}) as Dictionary
	return String(def.get("cooked_into", ""))

static func slot_tooltip(item_name: String, quantity: int) -> String:
	var tooltip := "%s ×%d" % [item_name, quantity]
	var flavor := flavor_text(item_name)
	if not flavor.is_empty():
		tooltip += "\n" + flavor
	return tooltip
