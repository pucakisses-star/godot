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
	"Orcish Tooth": 5,

	# The armory ladder and its trimmings.
	"Copper Blade": 12, "Iron Blade": 20, "Gold Blade": 35,
	"Copper Plate": 15, "Iron Plate": 25, "Gold Plate": 40,
	"Copper Helm": 10, "Iron Helm": 18, "Gold Helm": 30, "Starmetal Helm": 90,
	"Copper Greaves": 12, "Iron Greaves": 20, "Gold Greaves": 34, "Starmetal Greaves": 100,
	"Copper Sabatons": 10, "Iron Sabatons": 18, "Gold Sabatons": 30, "Starmetal Sabatons": 90,
	"Short Bow": 18, "War Bow": 40, "Oak Staff": 25, "Runed Staff": 60,
	"Beast Charm": 45, "Hunter's Garb": 30, "Warcaster's Robe": 30,
	"Beastmaster's Cloak": 30, "Wolf Fang Charm": 35, "Hearthstone Amulet": 35,
	"Fleetfoot Boots": 40, "Warding Ring": 60, "Arrows": 1, "Runestone": 45,

	# The alchemist's shelf.
	"Healing Potion": 12, "Ironhide Draught": 16, "Hunter's Tonic": 16,
	"Fleetfoot Philter": 14,

	# The field, the pen, and the road.
	"Iron Hoe": 12, "Coracle": 30, "Sow Saddle": 50, "Timber": 2,
	"Carrot Seeds": 3, "Beetroot Seeds": 3, "Tomato Seeds": 3,
	"Carrot": 3, "Beetroot": 3, "Tomato": 3, "Garden Stew": 9,
	"Egg": 3, "Truffle": 12, "Milk Pail": 4,
	"Chicken Crate": 20, "Piglet Crate": 30, "Calf Crate": 45
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
	"apothecary": ["Mushrooms", "Glowcap", "Spore Dust", "Frostcap", "Violet Veil", "Jar of Honey", "Mandrake Root", "Foxglove Sprig", "Frostleaf", "Firebloom", "Nightcap Bells", "Rowanberries", "Garlic Sprout", "Healing Potion", "Ironhide Draught", "Hunter's Tonic", "Fleetfoot Philter"],
	"gemcutters_studio": ["Gem Shard", "Gold Nugget", "Gold Trinket", "Amber"],
	"bank_vaults": ["Gold Nugget", "Gold Trinket", "Gem Shard", "Skeleton Keys"],

	# Wandering vendors: what walks the roads in a pack or a cart.
	# Peddler carries a bit of everything; the tinker tools and travel
	# gear; the drover live animals and tack; the pilgrim remedies and
	# blessed odds and ends.
	"peddler_pack": ["Loaf of Bread", "Arrows", "Carrot Seeds", "Beetroot Seeds", "Tomato Seeds", "Healing Potion", "Wax Candles", "Jerky Strip", "Wheel of Cheese", "Wolf Fang Charm"],
	"tinker_cart": ["Arrows", "Iron Hoe", "Coracle", "Whetstone", "Miner's Lantern", "Iron Nails", "Old Fishing Rod", "Casting Net", "Fleetfoot Boots"],
	"drover_stock": ["Chicken Crate", "Piglet Crate", "Calf Crate", "Sow Saddle", "Skein of Wool", "Egg", "Milk Pail", "Jerky Strip"],
	"pilgrim_satchel": ["Healing Potion", "Wax Candles", "Rowanberries", "Garlic Sprout", "Ironhide Draught", "Runestone", "Hearthstone Amulet"]
}

## Which pack a traveler opens when you trade on the road.
const TRAVELER_STOCK_TYPES := {
	"Peddler": "peddler_pack",
	"Tinker": "tinker_cart",
	"Drover": "drover_stock",
	"Pilgrim": "pilgrim_satchel"
}

## What each profession keeps in their pockets when inspected. "tools"
## always yields one pick (the trade's instrument); "wares" is either a
## SHOP_STOCK_POOLS key (crafts-folk carry what they sell) or an inline
## item list. "coin_max" caps the purse - merchants jingle, farmers don't.
## Keys cover both settlement vocabularies plus the road professions.
const NPC_KIT_TABLE := {
	"Blacksmith": {"tools": ["Smith's Hammer", "Smith's Tongs"], "wares": "smithy", "coin_max": 16},
	"Smith": {"tools": ["Smith's Hammer", "Smith's Tongs"], "wares": "forge", "coin_max": 16},
	"Merchant": {"tools": [], "wares": "market_stall", "coin_max": 30},
	"Goldsmith": {"tools": ["Mason's Chisel"], "wares": "gemcutters_studio", "coin_max": 30},
	"Brewer": {"tools": [], "wares": "brewery", "coin_max": 14},
	"Town Guard": {"tools": ["Whetstone"], "wares": ["Arrows", "Jerky Strip", "Mushroom Ration", "Loaf of Bread", "Dried Fish"], "coin_max": 12},
	"Warrior of the Watch": {"tools": ["Whetstone"], "wares": ["Arrows", "Mushroom Ration", "Jerky Strip", "Dried Fish"], "coin_max": 12},
	"Farmer": {"tools": ["Spade"], "wares": ["Carrot Seeds", "Beetroot Seeds", "Tomato Seeds", "Carrot", "Beetroot", "Tomato", "Egg"], "coin_max": 8},
	"Homesteader": {"tools": [], "wares": ["Egg", "Milk Pail", "Loaf of Bread", "Wheel of Cheese", "Skein of Wool", "Truffle"], "coin_max": 8},
	"Cleric": {"tools": ["Wax Candles"], "wares": ["Old Tome", "Healing Potion", "Rowanberries", "Jar of Honey"], "coin_max": 10},
	"Elder": {"tools": ["Wax Candles"], "wares": ["Old Tome", "Healing Potion", "Carved Curio", "Jar of Honey"], "coin_max": 14},
	"Hold Elder": {"tools": ["Wax Candles"], "wares": ["Old Tome", "Runestone", "Healing Potion", "Carved Curio"], "coin_max": 14},
	"Miner": {"tools": ["Rusty Pickaxe", "Worn Pickaxe", "Copper Pick"], "wares": ["Stone", "Iron Ore", "Copper Ore", "Mushrooms", "Miner's Lantern"], "coin_max": 8},
	"Runescribe": {"tools": ["Mason's Chisel"], "wares": ["Runed Tablet", "Old Tome", "Gem Shard", "Wax Candles"], "coin_max": 12},
	"Peddler": {"tools": [], "wares": "peddler_pack", "coin_max": 24},
	"Tinker": {"tools": [], "wares": "tinker_cart", "coin_max": 20},
	"Drover": {"tools": [], "wares": "drover_stock", "coin_max": 16},
	"Pilgrim": {"tools": [], "wares": "pilgrim_satchel", "coin_max": 8}
}
## Villagers and anyone without a listed trade: bread, cloth, trinkets.
const NPC_KIT_GENERIC := {
	"tools": [],
	"wares": ["Loaf of Bread", "Bolt of Cloth", "Wax Candles", "Carved Curio", "Wheel of Cheese", "Skein of Wool"],
	"coin_max": 6
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

## --- Local supply and demand -------------------------------------------------
## Each settlement's export goods trade CHEAP at home and its demanded
## goods DEAR - both buying and selling - so hauling wares between
## settlements earns a real margin.

const MARKET_EXPORT_SCALE := 0.6
const MARKET_DEMAND_SCALE := 1.7

## Maps the flavor export strings in settlement details ("Salted riverfish
## and smoked eel") onto real ITEM_VALUES names by keyword, so new flavor
## text degrades to "no match" instead of pricing phantom goods.
const EXPORT_KEYWORD_ITEMS := {
	"fish": ["Dried Fish", "Grilled Fish"],
	"eel": ["Dried Fish", "Grilled Fish"],
	"wool": ["Skein of Wool", "Bolt of Cloth"],
	"textile": ["Bolt of Cloth", "Skein of Wool"],
	"grain": ["Loaf of Bread"],
	"wine": ["Ale Keg"],
	"ale": ["Ale Keg"],
	"brew": ["Ale Keg"],
	"cordial": ["Ale Keg"],
	"timber": ["Timber"],
	"hardwood": ["Timber", "Carved Curio"],
	"furniture": ["Carved Curio", "Timber"],
	"ceramic": ["Carved Curio"],
	"pottery": ["Carved Curio"],
	"ironmongery": ["Iron Ingot", "Iron Nails", "Iron Horseshoes"],
	"iron": ["Iron Ore", "Iron Ingot"],
	"ore": ["Iron Ore", "Copper Ore", "Iron Ingot"],
	"ingot": ["Iron Ingot", "Copper Ingot"],
	"gem": ["Gem Shard"],
	"stone": ["Stone Block", "Stone"],
	"manuscript": ["Old Tome"],
	"scroll": ["Old Tome"],
	"oil": ["Wax Candles"],
	"soap": ["Wax Candles"],
	"instrument": ["Carved Curio"],
	"saddle": ["Leather Strap", "Iron Horseshoes"],
	"tack": ["Leather Strap", "Iron Horseshoes"],
	"leather": ["Leather Strap"],
	"honey": ["Jar of Honey"],
	"cheese": ["Wheel of Cheese"]
}

## What a settlement might be short of; demands roll from here EXCLUDING
## anything the settlement itself exports.
const DEMAND_ITEM_GROUPS := [
	["Iron Ingot", "Iron Ore"],
	["Dried Fish", "Grilled Fish"],
	["Skein of Wool", "Bolt of Cloth"],
	["Ale Keg"],
	["Timber"],
	["Gem Shard", "Gold Nugget"],
	["Loaf of Bread", "Wheel of Cheese"],
	["Healing Potion"],
	["Old Tome"],
	["Leather Strap", "Iron Horseshoes"],
	["Wax Candles"],
	["Whetstone", "Iron Nails"]
]

## Dwarfholds carry no generated details dict; their exports are what a
## mountain sells, rolled from the hold seed.
const HOLD_EXPORT_OPTIONS: Array[String] = [
	"Iron ore and forged ingots",
	"Cut gems and polished amber",
	"Dressed stone blocks",
	"Copper ore and cast ingots"
]

const MERCHANT_MARKET_LINES: Array[String] = [
	"We ship %s by the barrel here — but %s fetches triple.",
	"Nobody pays full coin for %s in this market; bring us %s and you'll leave rich.",
	"Everyone here sells %s. What we can't get enough of is %s."
]

## The settlement's price sheet: exports trade at export_scale of normal,
## demands at demand_scale, everything else unchanged. Pure function of
## the details and seed, so every visit prices the same.
static func settlement_market(town_details: Dictionary, settlement_seed: int) -> Dictionary:
	var exports: Array[String] = []
	for export_variant: Variant in (town_details.get("major_exports", []) as Array):
		var lowered := String(export_variant).to_lower()
		for keyword: String in EXPORT_KEYWORD_ITEMS.keys():
			if not lowered.contains(keyword):
				continue
			for item_variant: Variant in (EXPORT_KEYWORD_ITEMS[keyword] as Array):
				var item_name := String(item_variant)
				if not exports.has(item_name):
					exports.append(item_name)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("market|%d" % settlement_seed)
	# A settlement whose flavor exports map to nothing still undercuts on
	# something, so every market has a cheap side.
	if exports.is_empty():
		exports.assign(DEMAND_ITEM_GROUPS[rng.randi_range(0, DEMAND_ITEM_GROUPS.size() - 1)] as Array)
	var demand_pool: Array[int] = []
	for group_index: int in range(DEMAND_ITEM_GROUPS.size()):
		var overlaps := false
		for item_variant: Variant in (DEMAND_ITEM_GROUPS[group_index] as Array):
			if exports.has(String(item_variant)):
				overlaps = true
				break
		if not overlaps:
			demand_pool.append(group_index)
	var demands: Array[String] = []
	var want := mini(rng.randi_range(2, 3), demand_pool.size())
	for _pick_index: int in range(want):
		var pool_index := rng.randi_range(0, demand_pool.size() - 1)
		for item_variant: Variant in (DEMAND_ITEM_GROUPS[demand_pool[pool_index]] as Array):
			demands.append(String(item_variant))
		demand_pool.remove_at(pool_index)
	return {
		"exports": exports,
		"demands": demands,
		"export_scale": MARKET_EXPORT_SCALE,
		"demand_scale": MARKET_DEMAND_SCALE
	}

## A details-like dict for settlements without one (dwarfholds), feeding
## settlement_market the same way town details do.
static func hold_details_stub(settlement_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("hold_exports|%d" % settlement_seed)
	var pool := HOLD_EXPORT_OPTIONS.duplicate()
	var exports: Array[String] = []
	for _pick_index: int in range(2):
		var pool_index := rng.randi_range(0, pool.size() - 1)
		exports.append(String(pool[pool_index]))
		pool.remove_at(pool_index)
	return {"major_exports": exports}

static func market_price_multiplier(item_name: String, market: Dictionary) -> float:
	if (market.get("exports", []) as Array).has(item_name):
		return float(market.get("export_scale", MARKET_EXPORT_SCALE))
	if (market.get("demands", []) as Array).has(item_name):
		return float(market.get("demand_scale", MARKET_DEMAND_SCALE))
	return 1.0

static func local_buy_price(item_name: String, price_scale: float, market: Dictionary) -> int:
	return maxi(1, int(round(float(buy_price(item_name, price_scale)) * market_price_multiplier(item_name, market))))

static func local_sell_price(item_name: String, market: Dictionary) -> int:
	return maxi(1, int(round(float(sell_price(item_name)) * market_price_multiplier(item_name, market))))

## One-line shop hint: "Cheap here: Dried Fish, Grilled Fish · Dear here:
## Iron Ingot, Ale Keg" - first couple of names from each side.
static func market_hint_line(market: Dictionary) -> String:
	var cheap := _joined_leading_names(market.get("exports", []) as Array, 2)
	var dear := _joined_leading_names(market.get("demands", []) as Array, 2)
	if cheap.is_empty() and dear.is_empty():
		return ""
	return "Cheap here: %s · Dear here: %s" % [cheap, dear]

static func _joined_leading_names(names: Array, count: int) -> String:
	var picked: Array[String] = []
	for name_index: int in range(mini(count, names.size())):
		picked.append(String(names[name_index]))
	return ", ".join(picked)

## What a merchant says about the local market, quoting real wares.
static func merchant_market_line(market: Dictionary, rng: RandomNumberGenerator) -> String:
	var exports := market.get("exports", []) as Array
	var demands := market.get("demands", []) as Array
	if exports.is_empty() or demands.is_empty():
		return ""
	var export_name := String(exports[rng.randi_range(0, exports.size() - 1)]).to_lower()
	var demand_name := String(demands[rng.randi_range(0, demands.size() - 1)]).to_lower()
	return MERCHANT_MARKET_LINES[rng.randi_range(0, MERCHANT_MARKET_LINES.size() - 1)] % [export_name, demand_name]

## --- Caravan escort pay --------------------------------------------------------

const CARAVAN_BASE_PAY := 30
const CARAVAN_DANGER_PAY_SCALE := 1.5

## Escort pay grows with the road and spikes while the news says the
## roads are dangerous (lost caravans, raided settlements).
static func caravan_pay(distance_cells: int, recent_world_events: Array) -> int:
	var pay := CARAVAN_BASE_PAY + distance_cells / 2
	for event_variant: Variant in recent_world_events:
		var kind := String((event_variant as Dictionary).get("kind", ""))
		if kind == "caravan_lost" or kind == "settlement_raided":
			return int(round(float(pay) * CARAVAN_DANGER_PAY_SCALE))
	return pay

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

## Rolls what a citizen carries: 2-5 role-appropriate items and a small
## purse. Seeded from name+profession (plus the caller's scene salt), so
## a second look at the same NPC always shows the same pockets - callers
## store the result on the NPC state so trade systems can mutate it later.
static func npc_belongings(identity: Dictionary, role: int, seed_value: int) -> Dictionary:
	var profession := String(identity.get("profession", ""))
	var kit := NPC_KIT_TABLE.get(profession, NPC_KIT_GENERIC) as Dictionary
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%d|%d" % [String(identity.get("name", "")), profession, role, seed_value])
	var items: Array[Dictionary] = []
	var tools := kit.get("tools", []) as Array
	if not tools.is_empty():
		items.append({"name": String(tools[rng.randi_range(0, tools.size() - 1)]), "quantity": 1})
	var wares_variant: Variant = kit.get("wares", [])
	var pool: Array = (SHOP_STOCK_POOLS.get(wares_variant, []) as Array).duplicate() if wares_variant is String else (wares_variant as Array).duplicate()
	var want := rng.randi_range(2, 5) - items.size()
	for _pick_index in range(want):
		if pool.is_empty():
			break
		var pick_index := rng.randi_range(0, pool.size() - 1)
		var item_name := String(pool[pick_index])
		pool.remove_at(pick_index)
		# Staples stack a little; anything dear is carried singly.
		var quantity := rng.randi_range(1, 3) if item_value(item_name) <= 6 else 1
		items.append({"name": item_name, "quantity": quantity})
	return {"items": items, "coins": rng.randi_range(0, int(kit.get("coin_max", 6)))}

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
