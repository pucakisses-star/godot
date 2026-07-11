extends RefCounted
class_name EmbarkIntroService

## The embark story shown once when a new character first sets foot in the
## world — the game's "Strike the earth!" screen. Every telling opens on
## the same line ("You feel as if you've been reborn today.") and then
## bends to the character's trade: a miner reads the mountain's bones, a
## brewmaster keeps the hold in cheer, a ranger walks the wild beyond the
## gates. Pure text, deterministic from the character sheet, so a reborn
## successor in the same world gets a fittingly fresh telling of their own.

## The fixed first sentence, per design — every embark opens here.
const OPENING_LINE := "You feel as if you've been reborn today."

## The craft paragraph, keyed by the exact profession (lowercase). Trades
## not listed fall back to their hero-class line below.
const FLAVOR_BY_PROFESSION := {
	"miner": "The mountain's bones are yours to read. Every seam of ore, every buried vein of gems sings to your pick, and where others see dead rock you already see the shape of the halls to come.",
	"mason": "Stone answers to your hands. Yours are the walls and vaults that hold back the dark and the cold, and yours the craft that makes of raw crag a hall fit for kings.",
	"stonemason": "Stone answers to your hands. Yours are the walls and vaults that hold back the dark and the cold, and yours the craft that makes of raw crag a hall fit for kings.",
	"smith": "The forge is your hearth and the ring of the hammer your hymn. From ore and flame you will draw the tools and edges on which the whole hold depends.",
	"metalsmith": "The forge is your hearth and the ring of the hammer your hymn. From ore and flame you will draw the tools and edges on which the whole hold depends.",
	"smelter": "You coax pure metal from stubborn stone. Every bar that leaves your furnace becomes a blade, a hinge, a nail — the small iron bones of a living hold.",
	"toolmaker": "The forge is your hearth and the ring of the hammer your hymn. From ore and flame you will draw the tools and edges on which the whole hold depends.",
	"weaponsmith": "You forge the edge that keeps a hold alive. Axe, hammer and blade — when the dark things climb up from below, it is your work that meets them.",
	"armourer": "You beat plate and mail from unwilling iron. Every dwarf who walks away from a fight in the deeps owes their next breath to the steel you shaped.",
	"brewmaster": "A dwarf without drink is a dwarf without heart. Your barrels and stills will carry the hold in good cheer through the longest winter under the stone.",
	"brewer": "A dwarf without drink is a dwarf without heart. Your barrels and stills will carry the hold in good cheer through the longest winter under the stone.",
	"distiller": "A dwarf without drink is a dwarf without heart. Your barrels and stills will carry the hold in good cheer through the longest winter under the stone.",
	"scholar": "You keep the long memory of your people. Runes, records and old lore are your charge, and a hold that forgets its past does not stand for long.",
	"lorekeeper": "You keep the long memory of your people. Runes, records and old lore are your charge, and a hold that forgets its past does not stand for long.",
	"runescribe": "You keep the long memory of your people. Runes, records and old lore are your charge, and a hold that forgets its past does not stand for long.",
	"runesmith": "You bind power into metal with graven runes. What you forge remembers its purpose, and a hold armed with your work fears little from the deep.",
	"alchemist": "Reagents and reactions bend to your study. Fire, salt and stranger things will serve the hold at your word — carefully, or not at all.",
	"powdermaker": "Reagents and reactions bend to your study. Fire, salt and stranger things will serve the hold at your word — carefully, or not at all.",
	"corpsebinder": "You treat with the things beyond the last breath. The hold will not speak of your work by daylight, but it will be glad of it when the dark presses close.",
	"ranger": "The wild beyond the gates holds no dread for you. You will range the crags and forests, bring back meat and hide, and mark what stalks the dark before it ever finds the hold.",
	"hunter": "The wild beyond the gates holds no dread for you. You will range the crags and forests, bring back meat and hide, and mark what stalks the dark before it ever finds the hold.",
	"farmer": "From cave-moss to root and grain, you coax life from grudging ground. While the caravan is late and the stores run thin, it is your hands that keep the hold fed.",
	"herder": "From beast and pasture you draw meat, milk and leather. While the caravan is late and the stores run thin, it is your hands that keep the hold fed.",
	"shepard": "From beast and pasture you draw meat, milk and leather. While the caravan is late and the stores run thin, it is your hands that keep the hold fed.",
	"butcher": "Nothing a beast gives is wasted under your knife — meat, hide, bone and tallow all find their use. A hold eats well while you draw breath.",
	"carpenter": "Timber and stave take shape beneath your tools: doors and beds, barrels and beams — the hundred small things a living hold cannot do without.",
	"cooper": "Timber and stave take shape beneath your tools: barrels for the brew, casks for the stores, the honest woodwork a hold leans on every day.",
	"wheelwright": "Axle, hub and rim answer to your craft. The carts that haul stone and ore and grain through the hold roll because you made them roll.",
	"cartwright": "Axle, hub and rim answer to your craft. The carts that haul stone and ore and grain through the hold roll because you made them roll.",
	"merchant": "You know the worth of a thing to the last coin. Trade, tally and bargain are your craft, and a hold with a shrewd dealer need never go begging.",
	"banker": "You know the worth of a thing to the last coin. Ledgers and coffers are your craft — undwarfly, some will sneer, until the day their debts come due.",
	"goldsmith": "Precious metal takes beauty in your hands. Crown and ring and reliquary — you give a young hold the splendor that makes rivals reckon it a power.",
	"jewelsmith": "Gemstone and setting answer to your eye. You give a young hold the splendor of cut jewels — the kind of wealth that makes rivals reckon it a power.",
	"gemcutter": "Rough stone becomes fire under your wheel. You give a young hold the splendor of cut jewels — the kind of wealth that makes rivals reckon it a power.",
	"engineer": "You see the hold before a single stone is cut — the aqueducts, the floodgates, the great mechanisms. Where others merely dig, you design.",
	"architect": "You see the hold before a single stone is cut — the halls, the spans, the grand facades. Where others merely dig, you design.",
	"warrior": "You came not to craft but to guard. Axe in hand, you mean to stand between your kin and everything the deep world will send against them.",
	"explorer": "The blank places on the map call to you. You will walk where no dwarf has walked, and bring back the shape of the world beyond the gates.",
	"cartographer": "The blank places on the map call to you. You will chart the crags and rivers and roads, and give the hold true knowledge of the world beyond its gates."
}

## The four hero-class temperaments, for every trade not named above.
const FLAVOR_BY_CLASS := {
	"warrior": "You are stout of arm and stubborn of will — the kind of dwarf a young hold is raised upon. Whatever labor the day demands, you will set your shoulder to it.",
	"mage": "Yours is the work of the mind and the stranger arts. When muscle alone will not answer, the hold will lean on your learning.",
	"huntress": "You are at home where the tame land ends. Field and forest, beast and weather you understand, and the hold will be fed and forewarned because of it.",
	"rogue": "You have a trader's eye and a light step. Coin, craft and quiet cunning are your tools, and a canny hold needs them as sorely as any axe."
}

## Returns {"title": String, "body": String (BBCode)}.
static func compose(character: Dictionary, world_name: String, year: int) -> Dictionary:
	var profession := String(character.get("profession", "")).strip_edges()
	var character_name := String(character.get("name", "")).strip_edges()
	var title := "A Dwarven %s" % profession if not profession.is_empty() else "A Dwarven Expedition"

	var trade := profession.to_lower() if not profession.is_empty() else "wanderer"
	var awakening := ""
	if character_name.is_empty():
		awakening = "The long dark lifts and you wake to thin mountain air and the weight of purpose in your hands. Whatever you were before has gone to ash and echo. Today you are %s %s, and the mountainhomes have need of you." % [_article(trade), trade]
	else:
		awakening = "The long dark lifts and you wake to thin mountain air, a name already on your lips: %s. Whatever you were before has gone to ash and echo. Today you are %s %s, and the mountainhomes have need of you." % [character_name, _article(trade), trade]

	var flavor := _flavor_for(profession)

	var hardship := "Your small band has trekked in from the forbidding wilderness beyond to raise a new hold for the glory of all dwarfkind. There are almost no supplies left, but stout labor brings sustenance. A caravan is promised before winter shuts the passes — time enough, if you are quick, to delve secure lodgings ere the hungry things below take notice."

	var closing := ""
	if not world_name.strip_edges().is_empty():
		closing = "A new chapter of dwarven history begins here, in %s, in the year %d." % [world_name.strip_edges(), maxi(year, 1)]
	else:
		closing = "A new chapter of dwarven history begins here, in this place, in the year %d." % maxi(year, 1)

	var body := "[b]%s[/b]\n\n%s\n\n%s\n\n%s\n\n%s\n[color=#8fdf7f][b]Strike the earth![/b][/color]" % [
		OPENING_LINE, awakening, flavor, hardship, closing
	]
	return {"title": title, "body": body}

static func _flavor_for(profession: String) -> String:
	var key := profession.strip_edges().to_lower()
	if FLAVOR_BY_PROFESSION.has(key):
		return String(FLAVOR_BY_PROFESSION[key])
	var hero_class := DwarfHoldActorVisuals.hero_class_for_profession(key)
	return String(FLAVOR_BY_CLASS.get(hero_class, FLAVOR_BY_CLASS["warrior"]))

## "a" or "an" for the profession word in prose.
static func _article(word: String) -> String:
	if word.is_empty():
		return "a"
	return "an" if "aeiou".contains(word.substr(0, 1)) else "a"
