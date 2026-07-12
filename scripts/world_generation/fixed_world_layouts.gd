extends RefCounted
## Fixed, hand-authored world layouts: instead of noise-driven continents the
## landmass silhouette, biome regions and mountain ranges come from a coarse
## painted grid that is warped, upscaled and handed to the normal generation
## pipeline (rivers, forests, settlements, cultures and history stay procedural).
##
## Grid codes: "." ocean, "l" lake, "g" grassland, "f" forest, "j" jungle,
## "d" desert, "t" tundra/snow, "m" mountain range, "s" marsh, "b" badlands.

const TILE_ATLAS_DEFS := preload("res://scripts/world_generation/tile_atlas_defs.gd")

const CODE_OCEAN := 46      # "."
const CODE_LAKE := 108      # "l"
const CODE_GRASS := 103     # "g"
const CODE_FOREST := 102    # "f"
const CODE_JUNGLE := 106    # "j"
const CODE_DESERT := 100    # "d"
const CODE_TUNDRA := 116    # "t"
const CODE_MOUNTAIN := 109  # "m"
const CODE_MARSH := 115     # "s"
const CODE_BADLANDS := 98   # "b"

## Height model: everything is anchored to the layout sea level so the painted
## coastline is exactly where land crosses it. Mountains sit far above the
## 88th-percentile plateau floor the highland pass uses to seed ranges.
const OCEAN_EDGE_DEPTH := 0.05
const OCEAN_DEPTH_STEP := 0.055
const OCEAN_DISTANCE_CAP := 6
const LAKE_DEPTH := 0.05
const LAND_COAST_LIFT := 0.055
const LAND_INLAND_STEP := 0.018
const LAND_DISTANCE_CAP := 4
const MOUNTAIN_HEIGHT := 0.87
const BADLANDS_EXTRA_LIFT := 0.05
const WARP_CELLS := 0.8
const DETAIL_NOISE_AMPLITUDE := 0.03
## Climate nudging: painted biomes pull temperature/moisture toward values the
## downstream systems (crops, cultures, tooltips) expect for that terrain.
const CLIMATE_TARGET_WEIGHT := 0.75

const EARTH_ROWS: Array[String] = [
	"................................................................................................",
	"................................................................................................",
	".......................tttttttttttttttttttt.....................................................",
	".....................t.tttt..tttttttttttttt................................ttt..................",
	"...............ttttt.tt.ttt......ttttttttt....................t.......tttttttttt.t..............",
	"....tttttt.....tttttt.tttttttt....ttttttt.............t.........tttttttttttttttttttttttttttttttt",
	"gg..gmmggg.gggg..ggggggggg..ggg...gttt.....tt................mgggggggggggggggggggggggggggggggggg",
	"....gggggggg.gm....gggg....gg......tt.............g..............g......fgfffggggggfggggggggggg.",
	"......g......g...g....g....gggg...............gg......fffffffmfffff..g.f..ffmggggggfgg....ff....",
	"................ffg..........................g.g..ff.ffffffffgfffggggfffg.fffmfgfffgf.....f.....",
	".................ggggfg........................fgfmmfffff..mm..gggggggfgggggggggffffff..........",
	"................g.gggfff..fffff................gffggmgfgggfggm.ddddddggdddggddgggfff.f..........",
	"...............mggggggffffmff.................mgg..ggggg...fg.mmmmdgmmmmdddddddggffff...........",
	"...............mddgggggffffm..................gg.....g.gggggg.ddddmmmmmmmdddddgf.f..............",
	"................dddggggfffff..................gdddd......gddddddddggggggddggggff................",
	".................dgddggffff..................ddddddd.gg..dddddddddgggggggggggfffg...............",
	"..................ggdg....g..................ddddddddggggdddd.ddddggggggggggffff................",
	"...................gdg......................ddddddddggdggddddgdg..jjjjjgffggffff................",
	"....................fg..fgg.g...............ddgggggggggggg.mggdd...jjjj..gffff..................",
	".....................jjjj...................dddddddggddddddmddg.....jj...jjjj...................",
	"........................jj.................jjjjdddddgddddjgd........d.....jjj...................",
	"......................j.....mjjj............jjjjjjjjjjjjjjjddd..................................",
	"...........................jmjjjj............jjj.jjjjjjjmjjdd...................................",
	"...........................jmjjjjjj................j.jj.jgdg..............jj....................",
	"...........................mm....jjj...............jj...mgg................j.jj.................",
	"..........................jj.....jjjjj.............jjjjjggj..........................jj.........",
	"...........................g.....jjgggj.............jggjggj.....................................",
	"............................m.jjjjjggg.............ggggggjg.j......................g............",
	".............................djjjggggj.............ggggggj..j....................gggggg.........",
	".............................ddgggggg..............dgdggg...j..................dddddddgm........",
	".............................ddgggg.................ddgmm...g.................dddddddddmg.......",
	".............................dggggg.................ddggg.....................gdgddddddgm.......",
	".............................ggggg...................ggg.......................ggggdddgg........",
	".............................gggg....................................................ggg....g...",
	".............................ggg............................................................g...",
	".............................gg............................................................g....",
	"............................mg.............................................................g....",
	"............................mg..................................................................",
	"............................bg..................................................................",
	"............................tt..................................................................",
	"............................tt..................................................................",
	"...............................t................................................................",
	"tttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttt",
	"tttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttt",
	"tttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttt",
	"tttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttt",
	"tttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttt",
	"tttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttt",
]

const MIDDLE_EARTH_ROWS: Array[String] = [
	"..........................................................................................",
	"..........................................................................................",
	"...............................ttttttttttttttttttttttttttttttttttttttttttttttttttttttt....",
	"...............................ttttttttttttttttttttttttttttttttttttttttttttttttttttttt....",
	"........................tttttttttttttttttttttttttttttttttttttggggggggggggggggggggggggg....",
	"........................tttttttttttttttttttttttttttttttttttttttggggggggggggggggggggggg....",
	"......................tttttttttgggggtttttttttttttttttttttttttttttggggggggggggggggggggg....",
	"......................tttttttttgggggggtttttmttmmmmmmmmmttttttttggggggggggggggggggggggg....",
	"...........................gggggggggggggggmmmmmmmmmmmmmmmmmmmmmggggggggggggggggggggggg....",
	"...........................gggggggggggggggmmmgmmmmmmmmmmmmmmmmmmgggggggggggggggggggggg....",
	"......................ggggggggggggggggggggmmmggggggggggmmmmmmmmgggmmmmmggggggggggggggg....",
	"......................ggggggggggggggggggggmmmggggggggggggggggggggggggggggggggggggggggg....",
	"......................mgggggggggggggggggggmmmgggffffffffggmggggggggggggggggggggggggggg....",
	"......................gmggggggggggggggggggmmmgggffffffffgggggggggggggggggggggggggggggg....",
	".......................gggggggggggggggggggmmmgggffffffffggggggggggggggggggggggbbbbbbgg....",
	".......................gggllggggggggggggggmmmgggffffffffggggggggggggggggggggggbbbbbbgg....",
	"....................ggmgggllggggggggggggggmmmgggffffffffggggggggggggggggggggggbbbbbbgg....",
	"....................ggmmggggggggggggggggggmmmgggffffffffggggggggggggggggggggggbbbbbbgg....",
	"....................mmmgggggggggggggggfgggmmmgggffffffffggggggggggggggggggggggbbbbbbgg....",
	"....................mmmmgggggggggggggfffggmmmgggffffffffgggggggggggggggggggggggggggggg....",
	"....................mmmggggfggggggggfffffgmmmgggffffffffggggggggggggllllllgggggggggggg....",
	"....................gmmmgfffffgggggggfffggmmmgggffffffffggggggggggggllllllgggggggggggg....",
	"....................gmmmgggfgggggsssggfgggmmmgggffffffffggggggggggggllllllgggggggggggg....",
	"....................gmmmgggggggggsssggggggmmmgggffffffffggggggggggggllllllgggggggggggg....",
	"....................gmmmggggggggggggggggggmmmfggffffffffgggggggggggggsgggggggggggggggg....",
	"....................ggmggggggggggggggggggggmmmfgffffffffgggggggggggggggggggggggggggggg....",
	"....................gggggggggggggggggggggggmmmgggggggggglggggggggggggggggggggggggggggg....",
	".....................ggggggggggggggggggggggmmmgggggggggggggggggggggggggggggggggggggggg....",
	".....................ggggggggggggggggggggggmmmfggggggggggggggggggggggggggggggggggggggg....",
	".....................ggggggggggggggggggggggmmfffgggggggggggggggggggggggggggggggggggggg....",
	".....................gggfffffffmgggggggggggmfffffggggggggggggggggggggggggggggggggggggg....",
	".....................gggfffffffgmmgggggggggmmfffgggggggggggggggggggggggggggggggggggggg....",
	".....................gggfffffffgggggggggggggmmsssgggsggggggggggggggggggggggggggggggggg....",
	".....................gggfffffffgggggggggggggmmsssggggssmmmmmmmmmmmmggggggggggggggggggg....",
	".....................gggggggggggggggggggggggmmmgggggggmmmmmmmmmmmmmmgggggggggggggggggg....",
	".....................ggggggggggggggggggggmmmmmmmmmmmmmmmmmmmmmmmmmmggggggggggggggggggg....",
	".....................gggggggggggggggggggmmmmmmmmmmmmmmmmmbbbbbbbbbbggggggggggggggggggg....",
	"..........................gggggggggggggggmmmmmmmmmmmmmmmmbbbbbbbbbbggggggggggggggggggg....",
	"..........................ggggggggggggggggggggggggggfgmmmbbbbbbbbbbggggggggggggggggggg....",
	"..........................g.......gggggggggggggggfffffmmmbbbbllllbbggggggggggggggggggg....",
	".....................................gggggggggggggggfgmmmbbbbllllbbggggggggggggggggggg....",
	"...........................................gggggggggggmmmbbbbbbbbbbggggggggggggggggggg....",
	".............................................dddddddddmmmmmmmmmmmmmggggggggggggggggggg....",
	"..............................................dddddddddmdddddggggggggggggggggggggggggg....",
	"...............................................ddddddddddddddddddddddddddddddddddddddd....",
	".........................................g.d....dddddddddddddddddddddddddddddddddddddd....",
	"........................................g.......dddddddddddddddddddddddddddddddddddddd....",
	".................................................ddddddddddddddddddddddddddddddddddddd....",
	"................................................dddddddddddddddddddddddddddddddddddddd....",
	"................................................dddddddddddddddddddddddddddddddddddddd....",
	"...............................................ddddddddddddddddddddddddddddddddddddddd....",
	"..............................................dddddddddddddddddddddddddddddddddddddddd....",
	".............................................dddddddddddddddddddddddddjjjjjjjjjjjjjjjj....",
	"...........................................dddddddddddddddddddddddddddjjjjjjjjjjjjjjjj....",
	".........................................gggggggjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj....",
	".........................................gggggggjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj....",
]

const WESTEROS_ROWS: Array[String] = [
	"..........ttttttttttttttttt.................",
	"..........ttmtttttttttttttt.................",
	"..........tmmmttttttttttttt.................",
	"..........tmmmttttttffffftt.................",
	"..........ttmmmtttttffffftt.................",
	"..........tttmmmttttffffftt.................",
	"..........tttmmmttttttttttt.................",
	"........ttttttmmttttttttttttt...............",
	"........ttttttttmtttttttttttt...............",
	"........ggfffffggggggggggggggg.tt...........",
	"........ggfffffggggggggggggggg..............",
	".......gggfffffggggggggggggggg..............",
	".......ggggggggggggggggggggggg..............",
	"........gggggggggggggggggggggg..............",
	".........ggggggggggggggggggg.............ggg",
	".........ggggggggsssssgggggg.............ggg",
	"...............ggsssssg.................gggg",
	"...............ggsssssg................ggggg",
	".......g.......gggggggg.................gggg",
	"......g...ggggggggggggggggmgggg.........gggg",
	".....gf.g.gmgggggggggggggmmmggg.........fggg",
	".......g..mmmgggggggggggggmmmgg.........fggg",
	".......g..mmmggggggllggggggmmmgg........fggg",
	"..........gmmmgggggggggggggmmmg..g......fggg",
	"..........gmmmggggggggggggggmmm.........fggg",
	"..........ggmmmggggggggggggggmg.........gggg",
	"..........ggmmmgggggggggggggggg.........gggg",
	".........ggggmggggggggggggggg......b....gggg",
	".........gggggggggggggggggggg...........gggg",
	".........ggggggggggggggggggggggggg......gggg",
	".........gggggffffggggggffffffgggg......sggg",
	".........gggggffffggggggffffffgggg......sggg",
	".........gggggggggggggggffffffgggg......gggg",
	".........gggggggggggggggggggffffffg.....gggg",
	"........ggggggggggggggggggggffffffg.....gddd",
	".......gggggggggggggggggggggffffff......gddd",
	".......gggggggggggggggggggggffffff..g...gddd",
	"........gggggggggggggggggggggggggg...g..gddd",
	"........gggggggmmmgggggggggggggggg......gddd",
	"........ggggggmmmmmmmmgggggggggggg......gddd",
	"........gggggggmmmmmmmmgdgdgdggggg......gddd",
	"..........ggggggggmmddddddddddd.........gggg",
	"..........ggggggggggddddddddddd.........gggg",
	"..........ggggggddddddddddddddddddb.....gggg",
	".........gggggggddddddddddddddddddd.....gggg",
	"............ggggddddggddddddddd.........gggg",
	"............ggggggggggddddddddd.........gggg",
	"............................................",
	"............................................",
	"............................................",
	"............................................",
	"............................................",
	"............................................",
	"............................................",
	"............................................",
	"............................................",
]

const AZEROTH_ROWS: Array[String] = [
	"........................................................................",
	"........................................................................",
	"............................ttttttttttmmmmttttttttttttttt...............",
	"............................tttttttttmmmmmmmmmmtttttttttt...............",
	"............................ttttttttttmmmmmmmmmmttttttttt...............",
	"..........................ttttttttttttttttmmmmmtttttttttttt.............",
	"..........................ttttttttttttttttttttttttttfffffft.............",
	"..........................ttttttmmtttttttttttttttttffffffff.............",
	"..........................ttssstttmmjjttttttttggggggggggggg.............",
	"..........................ttssstttttjtttttttttffffggggggggg.............",
	"..............................ttttttttttttttttffffggggggggg.............",
	".......f......................ttttttttttttttttffffggggggbbb.............",
	"......f.gttttttgggggggg.......................ggggggggggbbb.............",
	"......f.gttttttgggggggg......................sggggggggggbbb.............",
	"........gfffffffmgggggg.......................sgggggggggggg.............",
	"........gffffffffgggggg.....................ggggggggggggggggg...........",
	"........gffffffffgggggg.....................ggggggmmmmggggggg...........",
	"........gffffffffgggggg.....................gggggggggggggfffg...........",
	"........gffffffffgggggg.....................gggggggggggggfffg...........",
	"........ggggmgggggggggg.....................gggggggggggggfffg...........",
	"........gggmmmggggggggg.....................ggggggggggggggggg.g.........",
	".........gggmmmggggggggg....................ggggggggssssggggg..g........",
	".........ggggmmggggggggg......g.............ggggggggssssggggg...........",
	".........gggggmggggggggg.......g..............mmtttttgggggggg...........",
	".........bbggggggggggggg......................mmmmmmmmmmmgggg...........",
	".........bbggggggggggggg......................mmmmmmmmmmmmmmg...........",
	".........bbggggggggggggg......................gggmmmmmmmmmmmg...........",
	".........bbggggggggggggg......................gggggggggmmmmmg...........",
	".........bbggggggggggggg......................gggbbbbbggbbbgg...........",
	".........gggggggggggsssg......................gggbbbbbggbbbgg...........",
	".........gggggggggggssss......................gggggmggggggggg...........",
	".........gggggggggggsssg....................gggggggggmmmgggg............",
	".........ffffggggggggggg....................gfffffggggggsssg............",
	".........ffffggbbbbbgggg....................gfffffggggggsssg............",
	"........fffffggbbbbbggg.....................gffffffffgggsssg............",
	"........fffffggbbbbbggg.....................gffffffffggggggg............",
	"........fffffgggggggggg.....................ggggggfffgggbbbg............",
	"........ggggggddddddddg.....................ggggggggggggbbbg............",
	"........dddgggddddddddg.....................gjjjjjjjggggbbbg............",
	"........dddjjjddddddddg.....................gjjjjjjjgggggggg............",
	"........dddjjjddddddddg.....................gjjjjjjjgggggggg............",
	"........dddjjjddddddddg......................jjjjjjjg...................",
	"........ggggggggggggggg......................jjjjjjjg...................",
	"...........gddddddddg........................jjjjjjjg...................",
	"...........gddddddddg...................j....jjjjjjjg...................",
	"...........gggjjjjjgg....................j.....jj.......................",
	"...........gggjjjjjgg...........................j.......................",
	"........................................................................",
	"........................................................................",
	"........................................................................",
	"........................................................................",
	"........................................................................",
]

const TAMRIEL_ROWS: Array[String] = [
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	".............................................tt.................",
	".............................................t..................",
	"................................................................",
	"..........................ttttttttttttttttt.gg..bbbbb..gg.......",
	"..........................ttttttttttttttttm.mg..bbmbb..gg.......",
	"............gffffffggggggtggtttttttttttttgm.mg..bbbbb..gg.......",
	"............gffffffgggggggggtttttttttttttgm.mg..bbbbb..gg.......",
	"..........gggffffffgmmmggmmgttttttttmttttgm.mg.........ggb......",
	"..........gggggggggmmmmmmmmgggggggggggggggm.mbbbbbbbbbbbb.......",
	"..........ggggggggggmmmmmmmmggggggggggggggg.mbbbbbbbbbbbb.b.....",
	"............gggggggggggmmgggggmmmmmmmmmmmmm.mbbbbbbbbbbbb.......",
	"............gggggggggggggggggmmmmmmmmmmmmmm.mbbbbbbbbbbbb.......",
	"..............ggggggggggggggggmmmmmmmmmmmmmmmmggggggggggg.......",
	"..............gggggggggggggmgggggggggggggggmmmggggggggggg.......",
	"..............gdddddddddddmmmgggggggggggggggmgggggggggggg.......",
	"..............gddddddddddddmmmgffffffffgggggggggggggggggg.......",
	"..............gddddddddddddmmmgffffffffgggggggggggggggggggg.....",
	"..............gddddddddddddmmmgffffffffgggggmgggffffffffggg.....",
	"..............gddddddddddddgmmmffffffffgggggmgggffffffffggg.....",
	"..............gddddddddddddggmgfffffflggggggmgggffffffffggg.....",
	"..............gddddddddddddggggffffffflgggggmgggffffffffggg.....",
	"..............dddddddggggggggggfffffffgggggggmssssssssssssg.....",
	"..............dddddddggggggggggggggggggggggggmssssssssssssg.....",
	"..............gggggggggggggggggggggggggggggggmssssssssssssg.....",
	"..................gggggggg...gggggggggggggggggssssssssssssg.....",
	"..................ffffffff...ggggggggggggggggsssssssssssssg.....",
	"..................ffffffff...ggggggggggggggggsssssssssssssg.....",
	"..................ffffffff...ggggggggggggggggssssssssssss.......",
	"............g...ffffffffffgdddddddddddggg....ssssssssssss.......",
	"........ggggg...ffffffffffgdddddddddddggg....ssssssssssss.......",
	"........gggg....ffffffffffgdddddddddddggg....ssssssssssss.......",
	"........gffg....ffffffffffgjjjjjjjjjjjjgg....gsssssssssss.......",
	"........gffg....ffffffffffgjjjjjjjjjjjjgg....gsssssssssss.......",
	"........gffg....ffffffffffgjjjjjjjjjjjjgg....gggggggggggg.......",
	"........gggg......ffffffffgjjjjjjjjjjjjgg.......................",
	"..................ffffffffjjjjjjjjj.............................",
	"......gg..................jjjjjjjjj.............................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
]

const HYRULE_ROWS: Array[String] = [
	"........................................................",
	"........................................................",
	"..............tttttgggggggggggbbbbbbbbbbb...............",
	"..............tttttgggggggggggbbbbbbbbbbb...............",
	"......ttmmmmtttttttgggggggggggbbbbbbbbbbbbbbbgg.........",
	"......tttmmmmmmttttgggggggggggbbbbbbbbmbbbbbbgg.........",
	"......tttttmmmmmtttgggggggggggbbbbbbbmbmbbbbbgg.........",
	"......ttttttmmmmmttgggggggggggbbbbbbbbbbbbbbbgg.........",
	"......tttttttttmtttggffgggggggbbbbbbbbbbbbbbbgg.........",
	"......tttttttttttttgggffggggggbbmmmmmbbbbbbbbgg.........",
	"......tttttttgggfffffffffffgggbbbbbbbmmmmmmbbgg.........",
	"......tttttttmggfffffffffffgggggggggggggggggggg.........",
	"......tttttttgmgggggggggggggggggggggggssssssssg.........",
	"......tttttttgggggggggggggggggggggllllsssssmssg.........",
	"......gggggggggggmggggggggllggggggllllssssssmsg.........",
	"......gggggggggggmggggggggggggggggllllsssssmssg.........",
	"......ggggggggggggmgggggggggggggggggggssssssssg.........",
	"......ggggggggggggmgggggggggggggggggggssssssssg.........",
	"......ggggggggggggmgggggggggggggggggggggggggggg.........",
	"......ggggggggggggggggggggggggggggggggggggggggg.........",
	"......ggggggggggggggggggggggggggggggggfffffffgg.........",
	"......mmmmmmmgggggggggggggggggggggggggfffffffgg.........",
	"......mmmmmmmmmmmmmgggggggggggggggggggfffffffgg.........",
	"......mmmmmmmmmmmmmmggggggggggggggggggfffffffggg........",
	"......ggdddddmmmmmmbbbggggggggggggggggffmmfffgg.........",
	"......ggdddddddddggbbbggggggggllggggggffffmffgg.........",
	"......dddddddddddddddggggggglllllllggggggggg............",
	"......dddddddddddddddggggggglllllllggggggggg............",
	"......dddddddddddddddggggggglllllllggggggggg............",
	"......dddddddddddddddggggggglllllllggggggggg............",
	"......dddddddddddddddgggjjjjjjjjjjjjjjjggg..............",
	"......dddddddddddddddgggjjjjjjjjjjjjjjjggg..............",
	"......ddddddlldddddddgggjjjjjjjjjjjjjjjggg..............",
	"......dddddddddddddddgggjjjjjjjjjjjjjjjgg...............",
	"......dddddddddddddddgjjjjjjjjjjjjjjjjjgg...............",
	"......dddddddddddddddgjjjjjjjjjjjjjjjjjggggg............",
	"......dddddddddddddddgjjjjjjjjjjjjjjjjjggggg............",
	"..........dddddddddddgjjjjjjjjjjjjjjjjjgg....f..........",
	"..........dddddddddddgjjjjjjjjjjjjjjjjjgg...f...........",
	"..........ggggggggggggggjjjjjjjjjjjjjjjgg...............",
	"........................................................",
	"........................................................",
	"........................................................",
	"........................................................",
]

const OLD_WORLD_ROWS: Array[String] = [
	"............................................................",
	"............................................................",
	"................ttttmmmmmmmmmmttttttttttttttt...............",
	"..............t.tttmmmmmmmmmmmmmmmmmmmmmmttttt..............",
	"...............tttttmmmmmmmmmmmmmmmmmmmmmmttt.t.............",
	"................ttttttttttttttmmmmmmmmmmmtttt...............",
	"................ttttttttttttttttttttttttttttt...............",
	"....................ttttttttttttttttttttt...................",
	"....................ttttttttttttttttttttt............tttttt.",
	"..........ss.........................................tttttt.",
	"..........s..........................................tttttt.",
	".....................................................tttttt.",
	"....................ggggggggggggggggggggggtttttttmmmtbbbbbb.",
	"....................ggssggggggggggggggggggtttttttmmmmbbbbbb.",
	"....................ggggfffffffffffgggggggtttttttmmmmmbbbbb.",
	"....................ggggfffffffffffggggggggtttttttmmmbbbbbb.",
	"................ggggggggfffffffffffgggggggggggggggmmmbbbbbb.",
	"................ggggggggfffffffffffgggggggggggggggmmmbbbbbb.",
	"................ggggggggfffffffffffgggggggggggggggmmmbbbbbb.",
	"................gggggggmggggggfffffffffgggggggggggmmmbbbbbb.",
	"............ggggggggggmmmgggggfffffffffggggggfffggmmmmbbbbb.",
	"............gggggggggggmmmggggfffffffffggggggfffggmmmbbbbbb.",
	"............ggffffgggggmmmggggfffffffffggggggfffgggmmbbbbbb.",
	"..........ggggffffggggggmmmgggggggggggggsssssfffgggmmbbbbbb.",
	"..........ggggffffggggggmmmgggggggggggggsssssfffgggmmbbbbbb.",
	"..........gggggggggggggggmmmggggggggggggsssssfffgggmmbbbbbb.",
	"..........gggggggggggggggmmmgggggggggggggggggfffgggmmmbbbbb.",
	"..........ggggggggggggggggmmmggggggggggggggggfffgggmmbbbbbb.",
	"..........ggggggggggggffffgmggggggggggggggggggggggmmmbbbbbb.",
	"................ggggggffffggggggggggggggggggggggggmmmbbbbbb.",
	"............mmmgggggggffffggggggggggggggggggggggggmmmbbbbbb.",
	"............gggmmmggggggggggggggggggggggggggggg......bbbbbb.",
	"........ggggggggggggggggggggggggggggggggggggggg......mbbbbb.",
	"........gmggggggggggggggggggggggggggggggggggggg......bbbbbb.",
	"........gggg..ggmmggggggggggggggggggggggggggggg......bbbbbb.",
	"........gggg..ggggmgggggggggggggggggggggggggggg......bbbbbb.",
	"........ggmg..gggggmmgggggggggggggggggggggggggg......bbbbbb.",
	"........gggg..ggggggggggggggggggggmmmmmgggggggg......bbbbbb.",
	"........ggggggggggg.gggggggggggggggggggmmmmmmggggmm..mbbbbb.",
	"........gggg..ggggg.ggggggggg.ggggbbbbbbbbbbbbbbbmm..bbbbbb.",
	"........gggg..gggggg.....g.gg.ggggbbbbbbbbbbbbbbbmm..bbbbbb.",
	"..............gggggg.......gg.ggggbbbbbbbbbbbbbbbmm..bbbbbb.",
	"..............gggggg..............bbbbbbbbbbbbbbbmm..bbbbbb.",
	".................g................bbbbbbbbbbbbbbbmm..bbbbbb.",
	"..........ddggddd.g...............bbbbbbbbbbbbbbbgm..bbbbbb.",
	"..........ddddddd.................ggbbbbbbbbbbbmbbbmm.bbbb..",
	"........ddddddddddddddddddd.......ggbbbbbbbbbmbbbbbmm.bbbb..",
	"........ddddddddddddddddddd.......ggbbbbbbbbbbmbbbbgm.bbbb..",
	"........dddddddddddddddddddddddddddddddddgggggggggggg.......",
	"........ddddddddddddddddddddddddddddddddd...................",
	"........dddddddddddddddddddddddddddddddddjjjjjjjjjjjj.......",
	"........dddddddddddddddddddddddddddddddddjjjjjjjjjjjj.......",
]

const FAERUN_ROWS: Array[String] = [
	"........................................................................",
	"........................................................................",
	"..............tttttttttttttttttttttttttttttttgttttttttttttttttttttttttt.",
	"..............tttttttttttttttttttttttttttttttgttttttttttttttttttttttttt.",
	"..........t...ttttmmmmmmmttttttttttttttttttttgttttttttttttttttttttttttt.",
	"...........t..ggtmmmmmmmmmmmmmmmmgggggggggggggttttttttttmmmmttttttttttt.",
	".............gggttmmmmmmmmmmmmmmmmggggggggggggtttttttttmmmmmmmmtttttttt.",
	".............ggggggggggggmmmmmmmmgggggggggggggggggggggggmmmmmmmmggggggg.",
	"..............ggggggfffffffffgggggggggggggggggggggggggggggggmmmgggggggg.",
	"..............ggggggfffffffffgggggggggggggggggggggggggggggggggggggggggg.",
	"..............ggggggfffffffffgggggggdddddddgggggggggggggggggmmmmggggggg.",
	"............ggggggggfffffffffgggggggdddddddgggggggggggggggggggggmmmgggg.",
	"............ggggggggfffffffffffgggggdddddddgggggggggggggggggggggggggggg.",
	"............ggggggggggfffffffffmggdddddddddbggggggggggggggggggggggggggg.",
	"............ggggggggggfffffffffgmgddddddddbg......ggggggggggggggggggggg.",
	"............ggggggggggfffffffffgmgdddddddddg......ggggggggggggggggggggg.",
	"............ggggggggggfffffffffgmgdddddddddg......ggggggggggggggggggggg.",
	"...........gggggggggggfffffffffggmdddddddddffffgggfffffffgggggggggggggg.",
	"............ggggggggggggggggggggggdddddddddffffgggfffffffgggggggggggggg.",
	"............ggggggggggggggggggggggggggggggggggggggfffffffgggggggggggggg.",
	"......g.....gggggggfggggggmggggggggggggggggggggggggg.......gggggggggggg.",
	".......g....ggggggggfggggggmgggggggggggg..gggggggggg.......gggggggggggg.",
	"......g.....ggggggggggggggggmgggggmmgg.....................gggggggggggg.",
	"..............gggggggggggggggmggggggmm.....................gggggggggggg.",
	"..............ggggggggggggggggmggggggg.................ff..gggggggggggg.",
	".............ggggggggggggggggggggggggg.................gggggggmmmmmmmgg.",
	"..............gggggggggggggggggggggggg.................ggggggmmmmmmmmmg.",
	"..............gggggggggggggggggggggggg.................gggggggmmmmmmmgg.",
	"....g.........ggggggggggggggggfffffffggggg...........gggggggggggggggggg.",
	".....g........ggggggmmmmggggggfffffffggggg.........gggggggggggggggggggg.",
	"..............gggggmmmmmmmmgggfffffffg.............gggggggggggggggggggg.",
	"..............ggggggmmmmmmmmgggggggggg....ggggggggggggggggsssssssgggggg.",
	"..............gggggggggggggggggggggggg....ggggggggggggggggsssssssgggggg.",
	"..............gggggggggggggggggggggggg....ggggggggggggggggsssssssgggggg.",
	"..............ggggggggggggggggggggggggggggggggggggggmmmmggggggggggggggg.",
	"................ggggggggggggggggggggggggggggggggggggggggmmmgggggggggggg.",
	"...............gggfffffffffgggggggggggggggggggggggggggggggggsssssssssss.",
	"................ggfffffffffgggggggggggggggggggggggggggggggggsssssssssss.",
	"................ggggggggggmmmm.......gggggggggggggggggggggggsssssssssss.",
	"................gggggggggggggg.......gggggggggggggggggggggggsssssssssss.",
	"................ggdddddddddddddgggggggggggggggggbbbbbbbbbbbgsssssssssss.",
	"................gsdddddddddddddgggggggggggggggggbbbbbbbbbbbgsssssssssss.",
	"........jjjjjjjjjgsddddddddddddgggggggggggggggggbbbbbbbbbbbgsssssssssss.",
	"........jjjjjjjjj...dddddddddddgggggggggggggggggggggggggggggggggggggggg.",
	"........jjmjjjjjj...dddddddddddgggggggggggggggggggggggggddddddddddddddd.",
	"......jjjjjjjjjjjjj.ggggggggggggggggggggggggggggggggggggddddddddddddddd.",
	"......jjjjjjmjjjjjj.jjjjjgggggggggggggggggggggggggggggggddddddddddddddd.",
	"......jjjjjjjjjjjjj.jjjjjgggggggggggggggggggggggggggggggddddddddddddddd.",
	"......jjjjjjjjjjjjj.jjjjjgggggggggggggggggggggggggggggggddddddddddddddd.",
	"........................................................................",
	"........................................................................",
	"........................................................................",
]

const LAYOUT_ORDER: Array[String] = [
	"earth",
	"middle-earth",
	"westeros",
	"azeroth",
	"tamriel",
	"hyrule",
	"old-world",
	"faerun",
]

const LAYOUTS := {
	"earth": {"label": "Earth", "rows": EARTH_ROWS},
	"middle-earth": {"label": "Middle-earth", "rows": MIDDLE_EARTH_ROWS},
	"westeros": {"label": "Westeros", "rows": WESTEROS_ROWS},
	"azeroth": {"label": "Azeroth", "rows": AZEROTH_ROWS},
	"tamriel": {"label": "Tamriel", "rows": TAMRIEL_ROWS},
	"hyrule": {"label": "Hyrule", "rows": HYRULE_ROWS},
	"old-world": {"label": "The Old World (Warhammer)", "rows": OLD_WORLD_ROWS},
	"faerun": {"label": "Faerûn", "rows": FAERUN_ROWS},
}

static func layout_labels() -> Array[String]:
	var labels: Array[String] = []
	for key: String in LAYOUT_ORDER:
		labels.append(String((LAYOUTS[key] as Dictionary).get("label", key)))
	return labels


## "" when the label is not a fixed layout (procedural layouts keep their path).
static func layout_key_for_label(layout_label: String) -> String:
	var wanted := layout_label.strip_edges().to_lower()
	for key: String in LAYOUT_ORDER:
		if String((LAYOUTS[key] as Dictionary).get("label", key)).to_lower() == wanted:
			return key
	return ""


## Builds the per-tile fields for a fixed layout: synthesized heights, painted
## base biomes, climate targets (-1.0 = leave procedural), vegetation floors
## (painted forests/jungles read as dense growth to the tree pass) and the
## jungle cell set (painted jungles bypass the latitude-locked jungle rule).
static func build_layout_fields(
	layout_key: String,
	map_dimensions: Vector2i,
	map_seed: int,
	sea_level: float
) -> Dictionary:
	var layout_variant: Variant = LAYOUTS.get(layout_key)
	if not (layout_variant is Dictionary):
		return {}
	var rows := (layout_variant as Dictionary).get("rows", []) as Array
	var grid_h := rows.size()
	if grid_h <= 0 or map_dimensions.x <= 0 or map_dimensions.y <= 0:
		return {}
	var grid_w := String(rows[0]).length()
	if grid_w <= 0:
		return {}

	var codes := PackedByteArray()
	codes.resize(grid_w * grid_h)
	for gy in range(grid_h):
		var row := String(rows[gy])
		for gx in range(grid_w):
			codes[gy * grid_w + gx] = row.unicode_at(gx)

	var coarse_heights := _build_coarse_heights(codes, grid_w, grid_h, sea_level)
	var coarse_biomes := _resolve_coarse_biomes(codes, grid_w, grid_h)

	# Aspect-preserving fit: the grid covers as much of the map as possible and
	# the remainder is letterboxed with open ocean.
	var scale := minf(float(map_dimensions.x) / float(grid_w), float(map_dimensions.y) / float(grid_h))
	var offset_x := (float(map_dimensions.x) - float(grid_w) * scale) * 0.5
	var offset_y := (float(map_dimensions.y) - float(grid_h) * scale) * 0.5

	var warp_noise_x := FastNoiseLite.new()
	warp_noise_x.seed = map_seed + 0x5f3759df
	warp_noise_x.noise_type = FastNoiseLite.TYPE_SIMPLEX
	warp_noise_x.fractal_type = FastNoiseLite.FRACTAL_FBM
	warp_noise_x.fractal_octaves = 3
	warp_noise_x.frequency = 1.0 / (3.2 * scale)
	var warp_noise_y := FastNoiseLite.new()
	warp_noise_y.seed = map_seed + 0x2c1b3c6d
	warp_noise_y.noise_type = FastNoiseLite.TYPE_SIMPLEX
	warp_noise_y.fractal_type = FastNoiseLite.FRACTAL_FBM
	warp_noise_y.fractal_octaves = 3
	warp_noise_y.frequency = 1.0 / (3.2 * scale)
	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = map_seed + 0x68e31da4
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail_noise.fractal_octaves = 4
	detail_noise.frequency = 0.055

	var cell_count := map_dimensions.x * map_dimensions.y
	var heights := PackedFloat32Array()
	heights.resize(cell_count)
	var biomes := PackedStringArray()
	biomes.resize(cell_count)
	var temperature_targets := PackedFloat32Array()
	temperature_targets.resize(cell_count)
	var moisture_targets := PackedFloat32Array()
	moisture_targets.resize(cell_count)
	var vegetation_floors := PackedFloat32Array()
	vegetation_floors.resize(cell_count)
	var jungle_cells := {}
	var deep_ocean_height := sea_level - OCEAN_EDGE_DEPTH - OCEAN_DEPTH_STEP * float(OCEAN_DISTANCE_CAP - 1)

	for y in range(map_dimensions.y):
		for x in range(map_dimensions.x):
			var idx := y * map_dimensions.x + x
			var warped_gx := (float(x) + 0.5 - offset_x) / scale + warp_noise_x.get_noise_2d(float(x), float(y)) * WARP_CELLS
			var warped_gy := (float(y) + 0.5 - offset_y) / scale + warp_noise_y.get_noise_2d(float(x), float(y)) * WARP_CELLS
			var cell_gx := int(floor(warped_gx))
			var cell_gy := int(floor(warped_gy))
			var code := CODE_OCEAN
			if cell_gx >= 0 and cell_gy >= 0 and cell_gx < grid_w and cell_gy < grid_h:
				code = codes[cell_gy * grid_w + cell_gx]

			var height := _bilinear_coarse_height(
				coarse_heights, grid_w, grid_h, warped_gx, warped_gy, deep_ocean_height
			)
			height += detail_noise.get_noise_2d(float(x), float(y)) * DETAIL_NOISE_AMPLITUDE
			# The painted code owns the land/water call: keep the synthesized
			# height on its side of the sea level so the coastline never drifts
			# from the layout.
			if code == CODE_OCEAN or code == CODE_LAKE:
				height = minf(height, sea_level - 0.02)
			else:
				height = maxf(height, sea_level + 0.02)
			heights[idx] = clampf(height, 0.0, 1.0)

			if cell_gx >= 0 and cell_gy >= 0 and cell_gx < grid_w and cell_gy < grid_h:
				biomes[idx] = coarse_biomes[cell_gy * grid_w + cell_gx]
			else:
				biomes[idx] = TILE_ATLAS_DEFS.BIOME_WATER

			var climate := _climate_targets_for_code(code)
			temperature_targets[idx] = climate.x
			moisture_targets[idx] = climate.y
			vegetation_floors[idx] = climate.z
			if code == CODE_JUNGLE:
				jungle_cells[Vector2i(x, y)] = true

	return {
		"heights": heights,
		"biomes": biomes,
		"temperature_targets": temperature_targets,
		"moisture_targets": moisture_targets,
		"vegetation_floors": vegetation_floors,
		"jungle_cells": jungle_cells,
		"water_level": sea_level
	}


## Vector3(temperature target, moisture target, vegetation floor); -1.0 targets
## leave the procedural climate untouched.
static func _climate_targets_for_code(code: int) -> Vector3:
	match code:
		CODE_TUNDRA:
			return Vector3(0.1, -1.0, 0.0)
		CODE_DESERT:
			return Vector3(0.85, 0.08, 0.0)
		CODE_BADLANDS:
			return Vector3(0.72, 0.15, 0.0)
		CODE_JUNGLE:
			return Vector3(0.85, 0.85, 0.85)
		CODE_MARSH:
			return Vector3(0.6, 0.92, 0.3)
		CODE_FOREST:
			return Vector3(0.45, 0.7, 0.8)
		_:
			return Vector3(-1.0, -1.0, 0.0)


static func _is_water_code(code: int) -> bool:
	return code == CODE_OCEAN or code == CODE_LAKE


const BFS_NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]


## Multi-source BFS distances on the coarse grid (4-connected): water cells get
## steps-to-land, land cells get steps-to-water. Both start at 1 on cells
## adjacent to the opposite kind.
static func _build_coarse_heights(
	codes: PackedByteArray,
	grid_w: int,
	grid_h: int,
	sea_level: float
) -> PackedFloat32Array:
	var count := grid_w * grid_h
	var distances := PackedInt32Array()
	distances.resize(count)
	distances.fill(-1)
	var frontier: Array[Vector2i] = []
	for gy in range(grid_h):
		for gx in range(grid_w):
			var i := gy * grid_w + gx
			var water := _is_water_code(codes[i])
			var borders_opposite := false
			if gx > 0 and _is_water_code(codes[i - 1]) != water:
				borders_opposite = true
			elif gx < grid_w - 1 and _is_water_code(codes[i + 1]) != water:
				borders_opposite = true
			elif gy > 0 and _is_water_code(codes[i - grid_w]) != water:
				borders_opposite = true
			elif gy < grid_h - 1 and _is_water_code(codes[i + grid_w]) != water:
				borders_opposite = true
			if borders_opposite:
				distances[i] = 1
				frontier.append(Vector2i(gx, gy))
	var cursor := 0
	while cursor < frontier.size():
		var current: Vector2i = frontier[cursor]
		cursor += 1
		var current_index := current.y * grid_w + current.x
		var next_distance := distances[current_index] + 1
		var current_water := _is_water_code(codes[current_index])
		for offset: Vector2i in BFS_NEIGHBOR_OFFSETS:
			var neighbor := current + offset
			if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= grid_w or neighbor.y >= grid_h:
				continue
			var neighbor_index := neighbor.y * grid_w + neighbor.x
			if distances[neighbor_index] != -1 or _is_water_code(codes[neighbor_index]) != current_water:
				continue
			distances[neighbor_index] = next_distance
			frontier.append(neighbor)

	var coarse_heights := PackedFloat32Array()
	coarse_heights.resize(count)
	for i in range(count):
		var code := codes[i]
		var distance := maxi(1, distances[i])
		var target := 0.0
		if code == CODE_LAKE:
			target = sea_level - LAKE_DEPTH
		elif code == CODE_OCEAN:
			target = sea_level - OCEAN_EDGE_DEPTH - OCEAN_DEPTH_STEP * float(mini(distance, OCEAN_DISTANCE_CAP) - 1)
		else:
			target = sea_level + LAND_COAST_LIFT + LAND_INLAND_STEP * float(mini(distance, LAND_DISTANCE_CAP) - 1)
			if code == CODE_MOUNTAIN:
				target = MOUNTAIN_HEIGHT
			elif code == CODE_BADLANDS:
				target += BADLANDS_EXTRA_LIFT
		coarse_heights[i] = target
	return coarse_heights


## Painted mountains become high terrain over a hill-capable base biome; snowy
## neighbors make the base tundra so ranges bordering snowfields read frozen.
static func _resolve_coarse_biomes(codes: PackedByteArray, grid_w: int, grid_h: int) -> PackedStringArray:
	var biomes := PackedStringArray()
	biomes.resize(grid_w * grid_h)
	for gy in range(grid_h):
		for gx in range(grid_w):
			var i := gy * grid_w + gx
			var code := codes[i]
			var biome: String = TILE_ATLAS_DEFS.BIOME_GRASSLAND
			if code == CODE_OCEAN or code == CODE_LAKE:
				biome = TILE_ATLAS_DEFS.BIOME_WATER
			elif code == CODE_TUNDRA:
				biome = TILE_ATLAS_DEFS.BIOME_TUNDRA
			elif code == CODE_DESERT:
				biome = TILE_ATLAS_DEFS.BIOME_DESERT
			elif code == CODE_MARSH:
				biome = TILE_ATLAS_DEFS.BIOME_MARSH
			elif code == CODE_BADLANDS:
				biome = TILE_ATLAS_DEFS.BIOME_BADLANDS
			elif code == CODE_MOUNTAIN:
				var snowy := false
				if gx > 0 and codes[i - 1] == CODE_TUNDRA:
					snowy = true
				elif gx < grid_w - 1 and codes[i + 1] == CODE_TUNDRA:
					snowy = true
				elif gy > 0 and codes[i - grid_w] == CODE_TUNDRA:
					snowy = true
				elif gy < grid_h - 1 and codes[i + grid_w] == CODE_TUNDRA:
					snowy = true
				if snowy:
					biome = TILE_ATLAS_DEFS.BIOME_TUNDRA
			biomes[i] = biome
	return biomes


static func _coarse_height_at(
	coarse_heights: PackedFloat32Array,
	grid_w: int,
	grid_h: int,
	gx: int,
	gy: int,
	fallback: float
) -> float:
	if gx < 0 or gy < 0 or gx >= grid_w or gy >= grid_h:
		return fallback
	return float(coarse_heights[gy * grid_w + gx])


static func _bilinear_coarse_height(
	coarse_heights: PackedFloat32Array,
	grid_w: int,
	grid_h: int,
	warped_gx: float,
	warped_gy: float,
	fallback: float
) -> float:
	var fx := warped_gx - 0.5
	var fy := warped_gy - 0.5
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var tx := fx - float(x0)
	var ty := fy - float(y0)
	var h00 := _coarse_height_at(coarse_heights, grid_w, grid_h, x0, y0, fallback)
	var h10 := _coarse_height_at(coarse_heights, grid_w, grid_h, x0 + 1, y0, fallback)
	var h01 := _coarse_height_at(coarse_heights, grid_w, grid_h, x0, y0 + 1, fallback)
	var h11 := _coarse_height_at(coarse_heights, grid_w, grid_h, x0 + 1, y0 + 1, fallback)
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), ty)
