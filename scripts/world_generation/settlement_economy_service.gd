extends RefCounted
class_name SettlementEconomyService

## The living-world layer's shared brain: item prices, shop stock rolls,
## and NPC dialogue/rumor lines. Scenes own the coins, popups, and click
## plumbing; everything here is pure data and rolls.

## Base worth in coins. Anything absent falls back to DEFAULT_ITEM_VALUE.
const DEFAULT_ITEM_VALUE := 2
const ITEM_VALUES := {
	"Stone": 1, "Stone Block": 2, "Iron Ore": 4, "Copper Ore": 5,
	"Gold Nugget": 14, "Gem Shard": 16, "Starmetal Ore": 60, "Starmetal Bar": 150, "Old Tome": 12, "Carved Curio": 6, "Iron Ingot": 8, "Leather Strap": 2,

	"Amber": 12, "Spider Amber": 18, "Fern Amber": 16, "Fossil Leaf": 10,
	"Ancient Skull": 20, "Beast Skull": 18, "Fossil Claw": 12,
	"Ammonite Shell": 10, "Chalk Ammonite": 8, "Old Bone": 4,
	"Serpent Spine": 12, "Fossil Ribs": 10, "Petrified Bone": 6,
	"Fossil Fish": 12, "Skeletal Paw": 10, "Moss Agate": 14,
	"Fossil Antler": 10, "Fossil Cluster": 12, "Fin Spines": 8,
	"Beast-Claw Charm": 15, "Runed Tablet": 22,

	"Rusty Pickaxe": 6, "Worn Pickaxe": 8, "Copper Pick": 10,
	"Miner's Pickaxe": 14, "Steel Pickaxe": 24, "Dwarven Pickaxe": 30,
	"Prospector's Trowel": 8, "Steel Trowel": 12, "Spade": 8,
	"Wooden Mallet": 6, "Stone Hammer": 8, "Geologist's Hammer": 14,
	"Sledgehammer": 12, "Mason's Chisel": 8, "Miner's Lantern": 18,
	"Silver Lantern": 26, "Dynamite Stick": 15, "Skeleton Keys": 25,
	"Gold Trinket": 24,

	"Mushrooms": 2, "Mushroom Ration": 5, "Spore Dust": 3, "Glowcap": 5,
	"Porcini": 4, "Chanterelle": 4, "King Bolete": 4, "Black Morel": 5,
	"Violet Coral": 5, "Fire Coral": 5, "Star Fungus": 6, "Dragonmane": 6,

	"Cave Perch": 3, "Silver Darter": 3, "Emerald Trout": 3,
	"Striped Bass": 3, "Cobalt Chub": 3, "Marigold Carp": 3,
	"Sapphire Perch": 4, "Copperback Trout": 4, "Jade Carp": 4,
	"Crimson Carp": 4, "Ruby Snapper": 5, "Violet Grouper": 5,
	"Duskfin": 5, "Bloodfin": 5, "Frilled Loach": 5, "Flicker Minnow": 3,
	"Speckled Prawn": 5, "Silverfry": 4, "Blindcave Fish": 4,
	"Deep Eel": 5, "Amethyst Angelfish": 10, "Blossom Koi": 12,
	"Golden Koi": 20, "Cave Lobster": 8, "Pale Squid": 6,
	"Gloom Octopus": 6, "Ember Squid": 7, "Cave Crab": 5,
	"Coral Snail": 4, "Bloodworm": 1, "Mud Grub": 1, "Dried Fish": 4,

	# Mounted trophy fish: bragging rights, priced accordingly.
	"Trophy Gudgeon": 18, "Trophy Bleak": 20, "Trophy Ruffe": 22,
	"Trophy Rudd": 26, "Trophy Perch": 28, "Trophy Bluegill": 28,
	"Trophy Grayling": 30, "Trophy Tench": 32, "Trophy Asp": 34,
	"Trophy Zope": 30, "Trophy Piranha": 36, "Trophy Ghost Cat": 38,
	"Trophy Zander": 42, "Trophy Burbot": 44, "Trophy Largemouth Bass": 48,
	"Trophy Pike": 55, "Trophy Alligator Gar": 70, "Trophy Redtail Catfish": 80,
	"Trophy Chinese Paddlefish": 95, "Trophy Beluga Sturgeon": 130,
	"Trophy Sand Goby": 16, "Trophy Baltic Sprat": 18, "Trophy Baltic Anchovy": 18,
	"Trophy Sardine": 18, "Trophy Baltic Stickleback": 20, "Trophy Sandlance": 20,
	"Trophy Pipefish": 22, "Trophy Round Goby": 22, "Trophy Baltic Roach": 24,
	"Trophy Baltic Herring": 26, "Trophy Lumpfish": 28, "Trophy Eelpout": 30,
	"Trophy Baltic Whitefish": 34, "Trophy Belone": 36, "Trophy Sea Trout": 38,
	"Trophy Emerald Piranha": 38, "Trophy Baltic Flounder": 42, "Trophy Sole": 44,
	"Trophy Turbot": 48, "Trophy Baltic Cod": 52, "Trophy Baltic Eel": 55,
	"Trophy Spiny Dogfish": 85,

	"Cork Bobber": 3, "Jig Lures": 6, "Painted Lure": 8, "Barbed Hook": 5,
	"Rusted Hook": 2, "Willow Rod": 12, "Oak Rod": 14,
	"Old Fishing Rod": 10, "Fishing Spear": 12, "Casting Net": 15,
	"Fish Trap": 12, "Grappling Hook": 16, "Rusty Anchor": 8,
	"Silk Line Spool": 10,

	"Grilled Fish": 6, "Mushroom Skewer": 5, "Hearty Stew": 12, "Roast Meat": 8,
	"Gold Ingot": 24, "Silver Ingot": 16, "Steel Ingot": 12, "Copper Ingot": 6,
	"Tin Ingot": 5, "Jade Ingot": 20, "Greensteel Ingot": 18, "Silver Ore": 8,
	"Iron Nails": 3, "Chain Links": 5, "Whetstone": 6, "Forged Blade": 22,
	"Steel Billet": 10, "Smith's Tongs": 8, "Smith's Hammer": 12, "Golden Chain": 26,
	"Mandrake Root": 8, "Snarling Mandrake": 14, "Foxglove Sprig": 6, "Firebloom": 6,
	"Frostleaf": 6, "Nightcap Bells": 7, "Amethyst Bud": 12, "Crimson Rose": 5,
	"Raw Steak": 4, "Marbled Steak": 6, "Prime Cut": 7, "Rack of Ribs": 5,
	"Cured Ham": 9, "Smoked Ribs": 8, "Trophy Skull": 12, "Stag Skull": 14,
	"Antlered Skull": 13, "Ram Skull": 11, "Beast Heart": 7,
	"Loaf of Bread": 3, "Wheel of Cheese": 6, "Jar of Honey": 5,
	"Ale Keg": 10, "Bolt of Cloth": 8, "Wax Candles": 3,
	"Skein of Wool": 4, "Iron Horseshoes": 6, "Lizard Scale": 6,
	"Orcish Tooth": 5
}

## What each kind of shop keeps behind the counter. Keys cover both the
## town and dwarfhold building-type vocabularies.
const SHOP_STOCK_POOLS := {
	"bakery": ["Loaf of Bread", "Mushroom Ration", "Jar of Honey", "Wheel of Cheese", "Mushroom Skewer"],
	"kitchen": ["Loaf of Bread", "Mushroom Ration", "Grilled Fish", "Hearty Stew", "Mushroom Skewer"],
	"grand_kitchens": ["Hearty Stew", "Grilled Fish", "Mushroom Skewer", "Mushroom Ration", "Wheel of Cheese"],
	"tavern": ["Ale Keg", "Grilled Fish", "Hearty Stew", "Roast Meat", "Smoked Ribs", "Loaf of Bread", "Wheel of Cheese"],
	"inn": ["Loaf of Bread", "Wheel of Cheese", "Jar of Honey", "Grilled Fish", "Ale Keg"],
	"brewery": ["Ale Keg", "Mushroom Skewer", "Jar of Honey"],
	"general_store": ["Stone", "Leather Strap", "Wax Candles", "Miner's Lantern", "Old Fishing Rod", "Cork Bobber", "Silk Line Spool", "Spade", "Mushroom Ration"],
	"general_goods_shop": ["Stone", "Leather Strap", "Miner's Lantern", "Old Fishing Rod", "Cork Bobber", "Silk Line Spool", "Spade", "Mushroom Ration"],
	"trade_supply_store": ["Stone", "Leather Strap", "Miner's Lantern", "Rusty Pickaxe", "Spade", "Casting Net", "Fish Trap", "Silk Line Spool"],
	"market_stall": ["Loaf of Bread", "Wheel of Cheese", "Skein of Wool", "Bolt of Cloth", "Wax Candles", "Dried Fish", "Jar of Honey", "Cured Ham", "Jerky Strip", "Aged Sausage", "Rowanberries"],
	"smithy": ["Iron Ingot", "Steel Ingot", "Copper Ingot", "Iron Nails", "Iron Horseshoes", "Miner's Pickaxe", "Stone Hammer", "Mason's Chisel", "Whetstone", "Chain Links"],
	"forge": ["Iron Ingot", "Steel Ingot", "Steel Billet", "Miner's Pickaxe", "Steel Pickaxe", "Forged Blade", "Whetstone", "Smith's Tongs", "Mason's Chisel"],
	"weapon_shop": ["Iron Ingot", "Steel Pickaxe", "Geologist's Hammer", "Fishing Spear", "Sledgehammer"],
	"armor_shop": ["Iron Ingot", "Leather Strap", "Stone Hammer", "Miner's Lantern"],
	"apothecary": ["Mushrooms", "Glowcap", "Spore Dust", "Frostcap", "Violet Veil", "Jar of Honey", "Mandrake Root", "Foxglove Sprig", "Frostleaf", "Firebloom", "Nightcap Bells", "Rowanberries", "Garlic Sprout"],
	"gemcutters_studio": ["Gem Shard", "Gold Nugget", "Gold Trinket", "Amber"],
	"bank_vaults": ["Gold Nugget", "Gold Trinket", "Gem Shard", "Skeleton Keys"]
}

const DWARF_FIRST_NAMES: Array[String] = [
	"Borin", "Dagna", "Thrain", "Vigdis", "Kelda", "Rurik", "Brokk",
	"Eydis", "Snorri", "Hilda", "Orin", "Magna", "Durgan", "Sigrun",
	"Korgan", "Thyra", "Baldrek", "Ingrid", "Harek", "Astrid"
]
const DWARF_CLAN_NAMES: Array[String] = [
	"Embervein", "Stonehewn", "Deepdelve", "Ironbraid", "Gravelbeard",
	"Amberhall", "Coalbrow", "Granitefist", "Silverdelf", "Rockmantle"
]

const GREETING_LINES: Array[String] = [
	"Well met, traveler.",
	"Mind the deep roads out there.",
	"Fine shift for it, isn't it?",
	"You look like you've seen the wilds.",
	"Don't let the dark bite.",
	"New face! We don't get many."
]

const PROFESSION_LINES: Array[String] = [
	"I keep busy as a %s here.",
	"A %s's work is never done.",
	"Been a %s all my life, like my kin before me.",
	"The hold feeds well when a %s does their job."
]

static func item_value(item_name: String) -> int:
	return int(ITEM_VALUES.get(item_name, DEFAULT_ITEM_VALUE))

static func sell_price(item_name: String) -> int:
	return maxi(1, item_value(item_name) / 2)

static func buy_price(item_name: String, price_scale: float) -> int:
	return maxi(1, int(round(float(item_value(item_name)) * maxf(price_scale, 0.1))))

static func is_shop_building_type(building_type: String) -> bool:
	return SHOP_STOCK_POOLS.has(building_type)

## Rolls a shopkeeper's stock: 4-6 distinct wares with small quantities,
## cheap staples stacked deeper than treasures.
static func generate_shop_stock(shop_type: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var pool := (SHOP_STOCK_POOLS.get(shop_type, SHOP_STOCK_POOLS["general_store"]) as Array).duplicate()
	var stock: Array[Dictionary] = []
	var want := rng.randi_range(4, mini(6, pool.size()))
	for _pick_index in range(want):
		if pool.is_empty():
			break
		var pick_index := rng.randi_range(0, pool.size() - 1)
		var item_name := String(pool[pick_index])
		pool.remove_at(pick_index)
		var quantity := rng.randi_range(2, 5) if item_value(item_name) <= 6 else rng.randi_range(1, 2)
		stock.append({"name": item_name, "quantity": quantity})
	return stock

static func dwarf_npc_name(rng: RandomNumberGenerator) -> String:
	return "%s %s" % [
		DWARF_FIRST_NAMES[rng.randi_range(0, DWARF_FIRST_NAMES.size() - 1)],
		DWARF_CLAN_NAMES[rng.randi_range(0, DWARF_CLAN_NAMES.size() - 1)]
	]

static func compass_word(delta: Vector2i) -> String:
	if delta == Vector2i.ZERO:
		return "right here"
	var angle := atan2(float(delta.y), float(delta.x))
	var sector := int(round(angle / (PI / 4.0)))
	match sector:
		0: return "east"
		1: return "southeast"
		2: return "south"
		3: return "southwest"
		-1: return "northeast"
		-2: return "north"
		-3: return "northwest"
		_: return "west"

## Builds a rumor from real map labels (discoveries and underdeep sites),
## pointing an actual direction from where the player stands. Labels whose
## centers sit on named city ground are skipped - locals aren't a rumor.
static func rumor_from_labels(labels: Array, district_cell_map: Dictionary, player_cell: Vector2i, rng: RandomNumberGenerator) -> String:
	var candidates: Array[Dictionary] = []
	for label_variant: Variant in labels:
		var entry := label_variant as Dictionary
		# Only wild labels (streamed discoveries and underdeep sites) make
		# rumors; nobody gossips about their own city districts.
		if not bool(entry.get("wild", false)):
			continue
		if district_cell_map.has(entry.get("center", Vector2i.ZERO) as Vector2i):
			continue
		candidates.append(entry)
	if candidates.is_empty():
		return ""
	var chosen := candidates[rng.randi_range(0, candidates.size() - 1)]
	var chosen_center := chosen.get("center", Vector2i.ZERO) as Vector2i
	var delta := chosen_center - player_cell
	var distance := Vector2(delta).length()
	var distance_word := "close by" if distance < 60.0 else ("a fair trek out" if distance < 160.0 else "far off in the deep")
	var direction := compass_word(delta)
	var rumor_templates: Array[String] = [
		"They say %s lies to the %s, %s.",
		"A prospector swore they found %s %s, off to the %s.",
		"Word at the tavern is there's %s to the %s - %s."
	]
	var label_name := String(chosen.get("name", "something strange"))
	var article_name := label_name if label_name.begins_with("The") else ("the %s" % label_name)
	match rng.randi_range(0, 2):
		0: return rumor_templates[0] % [article_name, direction, distance_word]
		1: return rumor_templates[1] % [article_name, distance_word, direction]
		_: return rumor_templates[2] % [article_name, direction, distance_word]

## A rumor for towns, drawn from the town's generated details.
static func rumor_from_town_details(town_details: Dictionary, rng: RandomNumberGenerator) -> String:
	var lines: Array[String] = []
	var exports := town_details.get("major_exports", []) as Array
	if not exports.is_empty():
		lines.append("Good coin in %s these days, if you can supply it." % String(exports[rng.randi_range(0, exports.size() - 1)]).to_lower())
	var guilds := town_details.get("major_guilds", []) as Array
	if not guilds.is_empty():
		lines.append("The %s has been hiring hands all season." % String(guilds[rng.randi_range(0, guilds.size() - 1)]))
	var ruler_name := String(town_details.get("ruler_name", ""))
	if not ruler_name.is_empty():
		lines.append("%s %s keeps the peace well enough, I suppose." % [String(town_details.get("ruler_title", "Mayor")), ruler_name])
	var hallmark := String(town_details.get("hallmark", ""))
	if not hallmark.is_empty():
		lines.append(hallmark)
	if lines.is_empty():
		return ""
	return lines[rng.randi_range(0, lines.size() - 1)]

## Assembles what an NPC says: greeting, a line about their work, and
## (usually) a rumor worth following.
static func dialogue_line(profession_title: String, rumor_text: String, rng: RandomNumberGenerator) -> String:
	var parts: Array[String] = []
	parts.append(GREETING_LINES[rng.randi_range(0, GREETING_LINES.size() - 1)])
	if not profession_title.is_empty() and rng.randf() < 0.7:
		parts.append(PROFESSION_LINES[rng.randi_range(0, PROFESSION_LINES.size() - 1)] % profession_title.to_lower())
	if not rumor_text.is_empty():
		parts.append(rumor_text)
	return " ".join(parts)
