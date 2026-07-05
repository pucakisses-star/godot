extends RefCounted
class_name ItemDefsService

## The item catalog: every inventory item's icon and flavor line.
## Icons live in item_icons.png, a 12x12 atlas of 32px icons packed from
## the web game's Inventory tilesheets - rows 0-3 Mining (indices 0-47),
## rows 4-7 Mushroom (48-95), rows 8-11 Fishing (96-143). Items without
## an entry fall back to the old abbreviation text in slot UIs.

const ITEM_ICONS_TEXTURE := preload("res://resources/images/items/item_icons.png")
## Second sheet: Alchemy (0-47), Butchery (48-95), Metallurgy (96-143),
## packed from the web game's remaining Inventory tilesheets. Entries
## with "sheet": 2 index into it.
const ITEM_ICONS2_TEXTURE := preload("res://resources/images/items/item_icons2.png")
## Third sheet: mounted fish trophies (0-19), cut from the freshwater-fish
## poster and set on little wooden plaques. Entries with "sheet": 3.
const ITEM_ICONS3_TEXTURE := preload("res://resources/images/items/item_icons3.png")
const ATLAS_COLUMNS := 12
const ICON_SIZE := 32

const ITEM_DEFS := {
	# --- raw materials & ores ---
	"Stone": {"icon": 44, "flavor": "Honest rock, the hold's first currency."},
	"Iron Ore": {"icon": 45, "flavor": "Rust-red and heavy. The forge is hungry."},
	"Copper Ore": {"icon": 15, "flavor": "Gleams warm even before the smelter."},
	"Gold Nugget": {"icon": 12, "flavor": "Enough to turn a merchant's head."},
	"Gem Shard": {"icon": 88, "flavor": "A splinter of buried starlight."},
	"Starmetal Ore": {"icon": 88, "flavor": "Sky-iron from the world's roots. It hums against the skin."},
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
	"Hearty Stew": {"icon": 39, "flavor": "Fish, fungus, and firelight in one pot."},

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
	"Sledgehammer": {"icon": 40, "flavor": "For rock that talks back."},
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
	"Cork Bobber": {"icon": 143, "flavor": "It floats. That is its entire job."},

	# --- herbs and strange growths (sheet 2: alchemy) ---
	"Violet Bloom": {"icon": 0, "sheet": 2, "flavor": "Sweetens tinctures and tempers."},
	"Bluebell Cluster": {"icon": 1, "sheet": 2, "flavor": "Rings softly when dried."},
	"Golden Tulip": {"icon": 2, "sheet": 2, "flavor": "Worth more pressed than planted."},
	"Redcap Sprig": {"icon": 3, "sheet": 2, "flavor": "Berries in a neat little row."},
	"Pink Starflower": {"icon": 4, "sheet": 2, "flavor": "Blooms only where nobody looks."},
	"Meadow Blossoms": {"icon": 5, "sheet": 2, "flavor": "A fistful of ordinary magic."},
	"Dried Root": {"icon": 6, "sheet": 2, "flavor": "Bitter, knotted, medicinal."},
	"Carrotwood Bundle": {"icon": 7, "sheet": 2, "flavor": "Neither carrot nor wood, both somehow."},
	"Hooked Root": {"icon": 8, "sheet": 2, "flavor": "Grips the soil like it owes it money."},
	"Wormroot": {"icon": 9, "sheet": 2, "flavor": "Wriggles a little. Probably fine."},
	"Mandrake Root": {"icon": 10, "sheet": 2, "flavor": "Do not listen when it hums."},
	"Spiked Tuber": {"icon": 11, "sheet": 2, "flavor": "Even the soil is careful with it."},
	"Firebloom": {"icon": 12, "sheet": 2, "flavor": "Warm to the touch, hot to the tongue."},
	"Sky Thistle": {"icon": 13, "sheet": 2, "flavor": "Grows toward thunder."},
	"Frostleaf": {"icon": 14, "sheet": 2, "flavor": "Never melts, never wilts."},
	"Bitterberries": {"icon": 15, "sheet": 2, "flavor": "The name undersells them."},
	"Sunburst Lily": {"icon": 16, "sheet": 2, "flavor": "Petals like a struck match."},
	"Star Aster": {"icon": 17, "sheet": 2, "flavor": "Alchemists pay well for the pollen."},
	"Hornroot": {"icon": 18, "sheet": 2, "flavor": "Ground fine, it wakes the sleeping."},
	"Creeping Vine": {"icon": 19, "sheet": 2, "flavor": "Keep it away from your other herbs."},
	"Burrseed": {"icon": 20, "sheet": 2, "flavor": "It chose your sock. Honor that."},
	"Husk Pod": {"icon": 21, "sheet": 2, "flavor": "Rattles with dormant seeds."},
	"Tanglewood Knot": {"icon": 22, "sheet": 2, "flavor": "A puzzle the forest tied itself."},
	"Pale Tendrils": {"icon": 23, "sheet": 2, "flavor": "Grown in dark, spent in light."},
	"Duskviolet": {"icon": 24, "sheet": 2, "flavor": "Opens at the hour of closing doors."},
	"Goldweed": {"icon": 25, "sheet": 2, "flavor": "A weed to farmers, a wage to pickers."},
	"Crimson Rose": {"icon": 26, "sheet": 2, "flavor": "Beauty with a blade on every stem."},
	"Nightcap Bells": {"icon": 27, "sheet": 2, "flavor": "Steep for dreams; do not overdo it."},
	"Scarlet Blossom": {"icon": 28, "sheet": 2, "flavor": "Red as the wound it mends."},
	"Foxglove Sprig": {"icon": 29, "sheet": 2, "flavor": "Heals hearts or stops them."},
	"Redroot": {"icon": 30, "sheet": 2, "flavor": "Dyes cloth, hands, and reputations."},
	"Spiral Bloom": {"icon": 31, "sheet": 2, "flavor": "Coiled like a question."},
	"Flamepetal": {"icon": 32, "sheet": 2, "flavor": "Burns cold. Nobody knows why."},
	"Whisker Root": {"icon": 33, "sheet": 2, "flavor": "Twitches toward water."},
	"Pale Mandrake": {"icon": 34, "sheet": 2, "flavor": "Quieter than its cousin. Suspicious."},
	"Bramble Root": {"icon": 35, "sheet": 2, "flavor": "The stubborn heart of the hedge."},
	"Rose Posy": {"icon": 36, "sheet": 2, "flavor": "An apology, pre-packaged."},
	"Ember Fern": {"icon": 37, "sheet": 2, "flavor": "Fronds like banked coals."},
	"Nightberries": {"icon": 38, "sheet": 2, "flavor": "Sweet at dusk, sour by dawn."},
	"Rowanberries": {"icon": 39, "sheet": 2, "flavor": "Wards off small evils and large birds."},
	"Blazing Orchid": {"icon": 40, "sheet": 2, "flavor": "The desert's one extravagance."},
	"Frostbloom Cluster": {"icon": 41, "sheet": 2, "flavor": "Winter, bottled in petals."},
	"Amethyst Bud": {"icon": 42, "sheet": 2, "flavor": "Half flower, half gemstone."},
	"Garlic Sprout": {"icon": 43, "sheet": 2, "flavor": "The humblest ward that works."},
	"Greenman Root": {"icon": 44, "sheet": 2, "flavor": "It has a face. Do not name it."},
	"Seed Pod Husk": {"icon": 45, "sheet": 2, "flavor": "Empty, but it remembers being full."},
	"Twinroot": {"icon": 46, "sheet": 2, "flavor": "Always grows in pairs. Always."},
	"Snarling Mandrake": {"icon": 47, "sheet": 2, "flavor": "Pick it fast and apologize later."},

	# --- the butcher's table (sheet 2: butchery) ---
	"Raw Steak": {"icon": 48, "sheet": 2, "flavor": "Honest red meat."},
	"Raw Cutlet": {"icon": 49, "sheet": 2, "flavor": "Thin-cut and quick to the pan."},
	"Marbled Steak": {"icon": 50, "sheet": 2, "flavor": "The good cut. Don't ruin it."},
	"Raw Haunch": {"icon": 51, "sheet": 2, "flavor": "A meal with a handle."},
	"Flank Cut": {"icon": 52, "sheet": 2, "flavor": "Tough, but it feeds four."},
	"Rack of Ribs": {"icon": 53, "sheet": 2, "flavor": "Built for the long fire."},
	"Aged Sausage": {"icon": 54, "sheet": 2, "flavor": "Older than some apprentices."},
	"Ground Meat": {"icon": 55, "sheet": 2, "flavor": "Ask no questions of it."},
	"Pork Belly": {"icon": 56, "sheet": 2, "flavor": "Rolled and ready for the smoker."},
	"Prime Cut": {"icon": 57, "sheet": 2, "flavor": "The thane's table gets these."},
	"Poultry Wing": {"icon": 58, "sheet": 2, "flavor": "Small, but there are always more."},
	"Ham Hock": {"icon": 59, "sheet": 2, "flavor": "Soup's best friend."},
	"Poultry Breast": {"icon": 60, "sheet": 2, "flavor": "Lean and blameless."},
	"Blood Sausage": {"icon": 61, "sheet": 2, "flavor": "An acquired taste, promptly acquired."},
	"Jerky Strip": {"icon": 62, "sheet": 2, "flavor": "Chews back a little."},
	"Spiced Fillet": {"icon": 63, "sheet": 2, "flavor": "Crusted with trade-road pepper."},
	"Roast Meat": {"icon": 64, "sheet": 2, "flavor": "Rolled, roasted, and irresistible."},
	"Picked Bones": {"icon": 65, "sheet": 2, "flavor": "Someone was thorough."},
	"Tripe": {"icon": 66, "sheet": 2, "flavor": "Waste nothing, the hold survives."},
	"Smoked Ribs": {"icon": 67, "sheet": 2, "flavor": "The smell alone sells them."},
	"Beast Heart": {"icon": 68, "sheet": 2, "flavor": "Still warm with old courage."},
	"Beast Liver": {"icon": 69, "sheet": 2, "flavor": "Rich, dark, and dividing opinion."},
	"Wing Joint": {"icon": 70, "sheet": 2, "flavor": "Off something bigger than a chicken."},
	"Game Leg": {"icon": 71, "sheet": 2, "flavor": "Ran far. Tastes like it."},
	"Spiced Mince": {"icon": 72, "sheet": 2, "flavor": "Ready for pies and questions."},
	"Marrowbone": {"icon": 73, "sheet": 2, "flavor": "The dog and the cook both stare."},
	"Rolled Roast": {"icon": 74, "sheet": 2, "flavor": "Tied with string and promises."},
	"Charred Ribs": {"icon": 75, "sheet": 2, "flavor": "Someone left them on too long. Still good."},
	"Kidney Cut": {"icon": 76, "sheet": 2, "flavor": "For the breakfast of the brave."},
	"Beast Shank": {"icon": 77, "sheet": 2, "flavor": "Slow-cooked or not at all."},
	"Hollow Horn": {"icon": 78, "sheet": 2, "flavor": "Drink from it or sound the alarm."},
	"Dried Meat": {"icon": 79, "sheet": 2, "flavor": "Miner's lunch, week three."},
	"Lizard Fillet": {"icon": 80, "sheet": 2, "flavor": "Tastes like ambitious chicken."},
	"Loin Chop": {"icon": 81, "sheet": 2, "flavor": "One good chop deserves another."},
	"Trophy Skull": {"icon": 82, "sheet": 2, "flavor": "It stares. Mount it high."},
	"Blood Horn": {"icon": 83, "sheet": 2, "flavor": "Red to the tip. Best not ask."},
	"Talon Bones": {"icon": 84, "sheet": 2, "flavor": "Claws off something that hunted."},
	"Ram Skull": {"icon": 85, "sheet": 2, "flavor": "Curled horns, straight bargain."},
	"Coiled Horn": {"icon": 86, "sheet": 2, "flavor": "A spiral worth a shelf."},
	"Cracked Bones": {"icon": 87, "sheet": 2, "flavor": "The marrow's gone; the luck remains."},
	"Butcher's Platter": {"icon": 88, "sheet": 2, "flavor": "Everything, arranged with pride."},
	"Cured Ham": {"icon": 89, "sheet": 2, "flavor": "A year in the cellar, gone in a night."},
	"Antlered Skull": {"icon": 90, "sheet": 2, "flavor": "The forest's old crown."},
	"Shed Antler": {"icon": 91, "sheet": 2, "flavor": "Dropped, not taken."},
	"Cloven Hooves": {"icon": 92, "sheet": 2, "flavor": "Sold in pairs, naturally."},
	"Stag Skull": {"icon": 93, "sheet": 2, "flavor": "Twelve points of quiet dignity."},
	"Fire-touched Antlers": {"icon": 94, "sheet": 2, "flavor": "Scorched in some story worth hearing."},
	"Femur Bone": {"icon": 95, "sheet": 2, "flavor": "Large enough to argue with."},

	# --- the smelter's yield (sheet 2: metallurgy) ---
	"Gold Ingot": {"icon": 96, "sheet": 2, "flavor": "The hold's ambition, cast solid."},
	"Gold Wire": {"icon": 97, "sheet": 2, "flavor": "Wealth, drawn fine."},
	"Greensteel Ingot": {"icon": 98, "sheet": 2, "flavor": "Alloyed with something the smiths won't name."},
	"Gold Dust": {"icon": 99, "sheet": 2, "flavor": "Sweep the smithy floor. Carefully."},
	"Smith's Hammer": {"icon": 100, "sheet": 2, "flavor": "Ten thousand strikes and counting."},
	"Metal File": {"icon": 101, "sheet": 2, "flavor": "Patience, with teeth."},
	"Copper Plate": {"icon": 102, "sheet": 2, "flavor": "Curls at the edge like old paper."},
	"Polishing Cloth": {"icon": 103, "sheet": 2, "flavor": "Green with use, priceless with skill."},
	"Brass Sheet": {"icon": 104, "sheet": 2, "flavor": "Hammered thin as a rumor."},
	"Wire Spool": {"icon": 105, "sheet": 2, "flavor": "A mile of maybe."},
	"Bronze Lump": {"icon": 106, "sheet": 2, "flavor": "Rough from the crucible."},
	"Gilded Plates": {"icon": 107, "sheet": 2, "flavor": "For doors that want to boast."},
	"Steel Ingot": {"icon": 108, "sheet": 2, "flavor": "The backbone of everything sharp."},
	"Steel Rods": {"icon": 109, "sheet": 2, "flavor": "Straight answers to bent problems."},
	"Copper Ingot": {"icon": 110, "sheet": 2, "flavor": "Warm-colored, cold-forged."},
	"Golden Chain": {"icon": 111, "sheet": 2, "flavor": "Every link a week's wages."},
	"Iron Nails": {"icon": 112, "sheet": 2, "flavor": "Civilization, sold by the pound."},
	"Iron Rivets": {"icon": 113, "sheet": 2, "flavor": "What holds the hold together."},
	"Copper Coil": {"icon": 114, "sheet": 2, "flavor": "Wound tight as a miser."},
	"Brass Plate": {"icon": 115, "sheet": 2, "flavor": "Polished until it argues with lamps."},
	"Molten Gold": {"icon": 116, "sheet": 2, "flavor": "Do not pocket while warm."},
	"Tangled Wire": {"icon": 117, "sheet": 2, "flavor": "An apprentice's afternoon, preserved."},
	"Tin Ingot": {"icon": 118, "sheet": 2, "flavor": "Humble metal, honest work."},
	"Metal Shavings": {"icon": 119, "sheet": 2, "flavor": "The lathe's confetti."},
	"Smithing Pick": {"icon": 120, "sheet": 2, "flavor": "For coaxing slag off a bloom."},
	"Silver Ingot": {"icon": 121, "sheet": 2, "flavor": "Moonlight with a stamp on it."},
	"Copper Rod": {"icon": 122, "sheet": 2, "flavor": "Conducts heat, lightning, and envy."},
	"Silver Ore": {"icon": 123, "sheet": 2, "flavor": "Gray stone hiding a bright secret."},
	"Smith's Tongs": {"icon": 124, "sheet": 2, "flavor": "The only safe handshake with iron."},
	"Leather Sheet": {"icon": 125, "sheet": 2, "flavor": "Tanned flat and waiting."},
	"Cured Leather": {"icon": 126, "sheet": 2, "flavor": "Supple enough to argue into any shape."},
	"Smith's Apron": {"icon": 127, "sheet": 2, "flavor": "Scarred in all the right places."},
	"Blade Blank": {"icon": 128, "sheet": 2, "flavor": "A sword, minus the decisions."},
	"Leather Cord": {"icon": 129, "sheet": 2, "flavor": "Binds hilts, hafts, and bargains."},
	"Shield Boss": {"icon": 130, "sheet": 2, "flavor": "The fist at the shield's heart."},
	"Whetstone": {"icon": 131, "sheet": 2, "flavor": "Every edge's oldest friend."},
	"Copper Fittings": {"icon": 132, "sheet": 2, "flavor": "For pipes, stills, and secret doors."},
	"Steel Billet": {"icon": 133, "sheet": 2, "flavor": "Fold it seven times and mean it."},
	"Forged Blade": {"icon": 134, "sheet": 2, "flavor": "Waiting only for a handle and a cause."},
	"Binding Ring": {"icon": 135, "sheet": 2, "flavor": "Holds barrels, gates, and oaths."},
	"Iron Spikes": {"icon": 136, "sheet": 2, "flavor": "Persuasive landscaping."},
	"Crucible": {"icon": 137, "sheet": 2, "flavor": "Where ore confesses what it really is."},
	"Gold Trimmings": {"icon": 138, "sheet": 2, "flavor": "Offcuts of extravagance."},
	"Brass Panels": {"icon": 139, "sheet": 2, "flavor": "The engineer's favorite wallpaper."},
	"Molten Slag": {"icon": 140, "sheet": 2, "flavor": "The furnace's opinion of impurities."},
	"Chain Links": {"icon": 141, "sheet": 2, "flavor": "Strength, one honest loop at a time."},
	"Jade Ingot": {"icon": 142, "sheet": 2, "flavor": "Metal with a memory of stone."},
	"Hooked Blade": {"icon": 143, "sheet": 2, "flavor": "For work that pulls back."},

	# --- mounted fish trophies (sheet 3) — rare catches for the wall ---
	"Trophy Asp": {"icon": 0, "sheet": 3, "flavor": "Silver lightning, finally still."},
	"Trophy Tench": {"icon": 1, "sheet": 3, "flavor": "The doctor fish, gold-flanked and smug."},
	"Trophy Piranha": {"icon": 2, "sheet": 3, "flavor": "Still grinning. Keep your fingers back."},
	"Trophy Zander": {"icon": 3, "sheet": 3, "flavor": "Glass-eyed hunter of the deep pools."},
	"Trophy Ghost Cat": {"icon": 4, "sheet": 3, "flavor": "You can see right through it. It saw you first."},
	"Trophy Rudd": {"icon": 5, "sheet": 3, "flavor": "Red fins bright as a festival flag."},
	"Trophy Grayling": {"icon": 6, "sheet": 3, "flavor": "The lady of the stream, sail-finned."},
	"Trophy Largemouth Bass": {"icon": 7, "sheet": 3, "flavor": "That mouth has swallowed better lures than yours."},
	"Trophy Pike": {"icon": 8, "sheet": 3, "flavor": "The river wolf, all teeth and patience."},
	"Trophy Burbot": {"icon": 9, "sheet": 3, "flavor": "The only cod that ever loved fresh water."},
	"Trophy Zope": {"icon": 10, "sheet": 3, "flavor": "A silver platter with fins."},
	"Trophy Alligator Gar": {"icon": 11, "sheet": 3, "flavor": "Armored like a keep, jawed like a trap."},
	"Trophy Redtail Catfish": {"icon": 12, "sheet": 3, "flavor": "Whiskers longer than your beard."},
	"Trophy Bluegill": {"icon": 13, "sheet": 3, "flavor": "Small, bright, and endlessly proud."},
	"Trophy Perch": {"icon": 14, "sheet": 3, "flavor": "Striped sergeant of the reeds."},
	"Trophy Bleak": {"icon": 15, "sheet": 3, "flavor": "A sliver of moonlight on a plaque."},
	"Trophy Chinese Paddlefish": {"icon": 16, "sheet": 3, "flavor": "A living oar from waters far away."},
	"Trophy Ruffe": {"icon": 17, "sheet": 3, "flavor": "Prickly little bandit of the shallows."},
	"Trophy Beluga Sturgeon": {"icon": 18, "sheet": 3, "flavor": "River royalty older than the hold itself."},
	"Trophy Gudgeon": {"icon": 19, "sheet": 3, "flavor": "Every angler's first, framed at last."},

	# --- Baltic trophies (sheet 3, icons 20-41) ---
	"Trophy Baltic Whitefish": {"icon": 20, "sheet": 3, "flavor": "Pale gold from cold grey water."},
	"Trophy Baltic Anchovy": {"icon": 21, "sheet": 3, "flavor": "Small fish, long bragging rights."},
	"Trophy Sandlance": {"icon": 22, "sheet": 3, "flavor": "A silver needle that swims."},
	"Trophy Pipefish": {"icon": 23, "sheet": 3, "flavor": "A seahorse that gave up on posture."},
	"Trophy Baltic Flounder": {"icon": 24, "sheet": 3, "flavor": "Both eyes on you, always."},
	"Trophy Turbot": {"icon": 25, "sheet": 3, "flavor": "A pebbled platter with opinions."},
	"Trophy Baltic Roach": {"icon": 26, "sheet": 3, "flavor": "Red-finned regular of every net."},
	"Trophy Eelpout": {"icon": 27, "sheet": 3, "flavor": "Grumpy face, loyal to the bottom."},
	"Trophy Baltic Sprat": {"icon": 28, "sheet": 3, "flavor": "The sea's small change."},
	"Trophy Belone": {"icon": 29, "sheet": 3, "flavor": "The garfish: a fencing foil with fins."},
	"Trophy Spiny Dogfish": {"icon": 30, "sheet": 3, "flavor": "The littlest shark still counts as a shark."},
	"Trophy Baltic Herring": {"icon": 31, "sheet": 3, "flavor": "Backbone of a hundred harbors."},
	"Trophy Baltic Cod": {"icon": 32, "sheet": 3, "flavor": "The fish wars were fought over."},
	"Trophy Sole": {"icon": 33, "sheet": 3, "flavor": "Flat, humble, and worth its weight."},
	"Trophy Sand Goby": {"icon": 34, "sheet": 3, "flavor": "Barely bigger than the hook."},
	"Trophy Lumpfish": {"icon": 35, "sheet": 3, "flavor": "A cheerful cobblestone of the sea."},
	"Trophy Round Goby": {"icon": 36, "sheet": 3, "flavor": "The uninvited guest of every shore."},
	"Trophy Baltic Stickleback": {"icon": 37, "sheet": 3, "flavor": "Three spines and infinite courage."},
	"Trophy Baltic Eel": {"icon": 38, "sheet": 3, "flavor": "It crossed an ocean twice for this wall."},
	"Trophy Sea Trout": {"icon": 39, "sheet": 3, "flavor": "Silver as the tide it rode in on."},
	"Trophy Emerald Piranha": {"icon": 40, "sheet": 3, "flavor": "Its grin outshines its scales."},
	"Trophy Sardine": {"icon": 41, "sheet": 3, "flavor": "One escaped the tin, into legend."}
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
	"Mud Grub": {"heal": 1},

	# --- the butcher's table (raw meats roast into Roast Meat) ---
	"Raw Steak": {"heal": 3, "cooked_into": "Roast Meat"},
	"Raw Cutlet": {"heal": 2, "cooked_into": "Roast Meat"},
	"Marbled Steak": {"heal": 4, "cooked_into": "Roast Meat"},
	"Raw Haunch": {"heal": 3, "cooked_into": "Roast Meat"},
	"Flank Cut": {"heal": 3, "cooked_into": "Roast Meat"},
	"Rack of Ribs": {"heal": 4, "cooked_into": "Roast Meat"},
	"Ground Meat": {"heal": 2, "cooked_into": "Roast Meat"},
	"Pork Belly": {"heal": 3, "cooked_into": "Roast Meat"},
	"Prime Cut": {"heal": 4, "cooked_into": "Roast Meat"},
	"Poultry Wing": {"heal": 2, "cooked_into": "Roast Meat"},
	"Poultry Breast": {"heal": 3, "cooked_into": "Roast Meat"},
	"Game Leg": {"heal": 3, "cooked_into": "Roast Meat"},
	"Lizard Fillet": {"heal": 3, "cooked_into": "Roast Meat"},
	"Beast Heart": {"heal": 3, "cooked_into": "Roast Meat"},
	"Beast Shank": {"heal": 3, "cooked_into": "Roast Meat"},

	# --- ready to eat ---
	"Roast Meat": {"heal": 9},
	"Jerky Strip": {"heal": 4},
	"Dried Meat": {"heal": 4},
	"Aged Sausage": {"heal": 5},
	"Blood Sausage": {"heal": 5},
	"Smoked Ribs": {"heal": 7},
	"Cured Ham": {"heal": 7},
	"Spiced Fillet": {"heal": 6},
	"Bitterberries": {"heal": 1},
	"Nightberries": {"heal": 2},
	"Rowanberries": {"heal": 2},
	"Garlic Sprout": {"heal": 1}
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
	var item_def := ITEM_DEFS[item_name] as Dictionary
	var icon_index := int(item_def.get("icon", 0))
	var atlas := AtlasTexture.new()
	match int(item_def.get("sheet", 1)):
		3:
			atlas.atlas = ITEM_ICONS3_TEXTURE
		2:
			atlas.atlas = ITEM_ICONS2_TEXTURE
		_:
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
