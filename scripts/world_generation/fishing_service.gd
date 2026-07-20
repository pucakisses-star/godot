extends RefCounted
class_name FishingService

## The hand-liner's ledger: what bites where. Every water answers to the
## ground around it — trout in the green country, char under the snow,
## barbs in the dune seeps, catfish in the marsh mud, pale blind things
## in the underhall pools. The Golden Koi answers to nothing: it turns up
## anywhere, rarely, and pays like it knows it.

## Odds the koi takes the hook instead of the local stock.
const GOLDEN_KOI_CHANCE := 0.08
const GOLDEN_KOI := {"name": "Golden Koi", "value": 20}

## Biome -> the fish that water holds. Values mirror
## SettlementEconomyService.ITEM_VALUES so the market and the field guide
## never disagree.
const FISH_SPECIES := {
	"grass": {"name": "River Trout", "value": 4},
	"forest": {"name": "River Trout", "value": 4},
	"snow": {"name": "Icefin Char", "value": 5},
	"sand": {"name": "Dune Barb", "value": 4},
	"marsh": {"name": "Mudwhisker Catfish", "value": 5},
	"cave": {"name": "Pale Cavefish", "value": 6},
}

static func catch_for_biome(biome: String, rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf() < GOLDEN_KOI_CHANCE:
		return GOLDEN_KOI
	return FISH_SPECIES.get(biome, FISH_SPECIES["grass"]) as Dictionary
