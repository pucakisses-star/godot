extends Control
class_name EmbarkPreparation

const WorldSettings = preload("res://scripts/world_generation/world_settings.gd")

const MAP_SIZES := [
	{
		"key": "mini",
		"name": "Mini",
		"dimensions": "228 × 128",
		"size": Vector2i(228, 128)
	},
	{
		"key": "small",
		"name": "Small",
		"dimensions": "341 × 192",
		"size": Vector2i(341, 192)
	},
	{
		"key": "normal",
		"name": "Normal",
		"dimensions": "455 × 256",
		"size": Vector2i(455, 256)
	},
	{
		"key": "large",
		"name": "Large",
		"dimensions": "683 × 384",
		"size": Vector2i(683, 384)
	},
	{
		"key": "extra-large",
		"name": "Extra Large",
		"dimensions": "910 × 512",
		"size": Vector2i(910, 512)
	}
]

const WORLD_LAYOUTS := [
	"Normal",
	"Major Continent",
	"Twin Continents",
	"Inland Sea",
	"Archipelago"
]

const CHRONOLOGY_YEAR_MIN := 0
const CHRONOLOGY_YEAR_MAX := 50000
const CHRONOLOGY_AGE_MIN := 2
const CHRONOLOGY_AGE_MAX := 20

const WORLD_NAMES := [
	"Nûrn",
	"Ardganor",
	"Drakmor",
	"Thaldur",
	"Eldrakis",
	"Karrûn",
	"Tholmar",
	"Torra",
	"Albia",
	"Tor",
	"Lassel",
	"Marrov'gar",
	"Planetos",
	"Ulthos",
	"Grrth",
	"Erin",
	"Nûrnheim",
	"Midkemia",
	"Skarnheim",
	"Shannara",
	"Alagaësia",
	"Syf",
	"Elysium",
	"Lankhmar",
	"Arcadia",
	"Eberron",
	"Crobuzon",
	"Valdemar",
	"Uresia",
	"Tiassa",
	"Tairnadal",
	"Solara",
	"Golarion",
	"Aerth",
	"Khand",
	"Sanctuary",
	"Thra",
	"Acheron",
	"Cosmere",
	"Tékumel",
	"Norrathal",
	"Prydain",
	"Kulthea",
	"Bas-Lag",
	"Eternia",
	"Xanth",
	"Abeir-Toril",
	"Earthsea",
	"Pern",
	"Discworld",
	"Hyboria",
	"Avalon",
	"Tyria",
	"Tarnadam",
	"Rokugan",
	"Glorantha",
	"Ivalice",
	"The World of the Five Gods",
	"Narnia",
	"Azeroth",
	"Spira",
	"Noxus",
	"Volkran",
	"Tal'Dorei",
	"Exandria",
	"Runeterra",
	"Eorzea",
	"Thraenor",
	"Xadia",
	"Roshar",
	"Teldrassil",
	"Draenor",
	"Valisthea",
	"Gensokyo",
	"Temeria",
	"Nilfgaard",
	"Aedirn",
	"Redania",
	"Kaedwen",
	"Toussaint",
	"Rivellon",
	"Lucis",
	"Gransys",
	"Drangleic",
	"Lothric",
	"Boletaria",
	"Lordran",
	"Caelid",
	"Limgrave",
	"Altus",
	"Plateauonia",
	"Iria",
	"Theros",
	"Dominaria",
	"Zendikar",
	"Innistrad",
	"Ravnica",
	"Kamigawa",
	"Lorwyn",
	"Tarkir",
	"Ikoria",
	"Strixhaven",
	"Brazenforge",
	"Solarae",
	"Ethyra",
	"Lunathor",
	"Aethernis",
	"Veydris",
	"Nytherra",
	"Astralis",
	"Zephyra",
	"Umbryss",
	"Eclipthar",
	"Skibiti Toliterium",
	"Syx",
	"Quidd"
]

@onready var map_size_select: OptionButton = %MapSizeSelect
@onready var world_layout_select: OptionButton = %WorldLayoutSelect
@onready var seed_input: LineEdit = %SeedInput
@onready var year_input: SpinBox = %YearInput
@onready var age_input: SpinBox = %AgeInput
@onready var randomise_chronology_button: Button = %RandomiseChronologyButton
@onready var world_name_input: LineEdit = %WorldNameInput
@onready var randomise_world_name_button: Button = %RandomiseWorldNameButton
@onready var embark_button: Button = %EmbarkButton
@onready var back_button: Button = %BackButton

@onready var summary_map_size: Label = %SummaryMapSize
@onready var summary_layout: Label = %SummaryLayout
@onready var summary_seed: Label = %SummarySeed
@onready var summary_chronology: Label = %SummaryChronology
@onready var map_preview: TextureRect = get_node_or_null("%MapPreview")
@onready var background_map: TextureRect = get_node_or_null("BackgroundMap")

## The preview thumbnail runs the real terrain math (same noises, same
## layout preset, same landmass centers) at postcard resolution, so what
## you see is the world you get: pick Twin Continents and two lobes
## appear. The same image, stretched soft, becomes the page backdrop.
const PREVIEW_RESOLUTION := Vector2i(176, 124)
func _ready() -> void:
	randomize()
	_populate_options()
	_apply_cached_world_settings()
	if seed_input.text.strip_edges().is_empty():
		seed_input.text = _generate_seed()
	if world_name_input.text.strip_edges().is_empty():
		world_name_input.text = _generate_world_name()
	# Chronology validation (browser rules): years 0-50000, ages 2-20.
	year_input.min_value = CHRONOLOGY_YEAR_MIN
	year_input.max_value = CHRONOLOGY_YEAR_MAX
	age_input.min_value = CHRONOLOGY_AGE_MIN
	age_input.max_value = CHRONOLOGY_AGE_MAX
	if year_input.value <= 0:
		year_input.value = 1485
	if age_input.value <= 0:
		age_input.value = 18
	_refresh_summary()

	map_size_select.item_selected.connect(func(_index: int) -> void: _refresh_summary())
	world_layout_select.item_selected.connect(func(_index: int) -> void: _refresh_summary())
	seed_input.text_changed.connect(func(_text: String) -> void: _refresh_summary())
	year_input.value_changed.connect(func(_value: float) -> void: _refresh_summary())
	age_input.value_changed.connect(func(_value: float) -> void: _refresh_summary())
	world_name_input.text_changed.connect(func(_text: String) -> void: _refresh_summary())

	randomise_chronology_button.pressed.connect(_on_randomise_chronology_pressed)
	randomise_world_name_button.pressed.connect(_on_randomise_world_name_pressed)
	embark_button.pressed.connect(_on_embark_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _populate_options() -> void:
	map_size_select.clear()
	for map_size: Dictionary in MAP_SIZES:
		map_size_select.add_item("%s — %s" % [map_size["name"], map_size["dimensions"]])
	map_size_select.select(0)

	world_layout_select.clear()
	for layout: String in WORLD_LAYOUTS:
		world_layout_select.add_item(layout)
	world_layout_select.select(0)

func _refresh_summary() -> void:
	var map_size: Dictionary = MAP_SIZES[map_size_select.selected]
	summary_map_size.text = "%s — %s" % [map_size["name"], map_size["dimensions"]]
	summary_layout.text = world_layout_select.get_item_text(world_layout_select.selected)
	summary_seed.text = seed_input.text.strip_edges() if not seed_input.text.strip_edges().is_empty() else "Random"
	summary_chronology.text = "Year %d of the %d Age" % [int(year_input.value), int(age_input.value)]
	_update_map_preview()

func _update_map_preview() -> void:
	if map_preview == null:
		return
	var layout_name := world_layout_select.get_item_text(maxi(world_layout_select.selected, 0))
	var preset: Dictionary = WorldSettings.layout_generation_preset(layout_name)
	var dims := (MAP_SIZES[maxi(map_size_select.selected, 0)] as Dictionary).get("size", Vector2i(455, 256)) as Vector2i
	var seed_text := seed_input.text.strip_edges()
	var preview_seed := 0
	if seed_text.is_valid_int():
		preview_seed = int(seed_text)
	elif not seed_text.is_empty():
		preview_seed = int(seed_text.hash())

	var rng := RandomNumberGenerator.new()
	rng.seed = preview_seed
	var centers: Array[Vector2] = TerrainGenerator.configure_landmass_centers(
		rng,
		int(preset.get("landmass_center_count", 4)),
		0.12,
		float(preset.get("landmass_center_min_separation", 0.0))
	)
	# Mirrors the overworld's noise setup exactly (overworld_map.gd).
	var divisor := maxf(1.0, float(dims.x))
	var continent_noise := FastNoiseLite.new()
	continent_noise.seed = preview_seed
	continent_noise.frequency = (2.0 * 0.35) / divisor
	continent_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	continent_noise.fractal_octaves = 4
	continent_noise.fractal_lacunarity = 2.1
	continent_noise.fractal_gain = 0.52
	continent_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = preview_seed + 37
	detail_noise.frequency = (2.0 * 2.2) / divisor
	detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail_noise.fractal_octaves = 4
	detail_noise.fractal_lacunarity = 2.3
	detail_noise.fractal_gain = 0.55
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	var ridge_noise := FastNoiseLite.new()
	ridge_noise.seed = preview_seed + 83
	ridge_noise.frequency = (2.0 * 1.1) / divisor
	ridge_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	ridge_noise.fractal_octaves = 3
	ridge_noise.fractal_lacunarity = 2.0
	ridge_noise.fractal_gain = 0.6
	ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX

	var water_level := float(preset.get("water_level", 0.45))
	var terrain_settings := {
		"map_size": dims,
		"map_seed": preview_seed,
		"water_level": water_level,
		"falloff_strength": float(preset.get("falloff_strength", 0.08)),
		"falloff_power": float(preset.get("falloff_power", 2.4)),
		"landmass_falloff_scale": float(preset.get("landmass_falloff_scale", 1.35)),
		"landmass_mask_strength": float(preset.get("landmass_mask_strength", 0.24)),
		"landmass_mask_power": 0.82,
		"landmass_mask_threshold": float(preset.get("landmass_mask_threshold", 0.47)),
		"landmass_mask_scale": float(preset.get("landmass_mask_scale", 1.0)),
		"landmass_mask_edge_falloff": float(preset.get("landmass_mask_edge_falloff", 0.26)),
		"center_shape_strength": float(preset.get("center_shape_strength", 1.0)),
		"edge_ocean_strength": float(preset.get("edge_ocean_strength", 0.2)),
		"edge_ocean_falloff": float(preset.get("edge_ocean_falloff", 0.32)),
		"edge_ocean_curve": 1.6
	}
	var image := Image.create(PREVIEW_RESOLUTION.x, PREVIEW_RESOLUTION.y, false, Image.FORMAT_RGB8)
	for py in range(PREVIEW_RESOLUTION.y):
		var y := int(float(py) * float(dims.y) / float(PREVIEW_RESOLUTION.y))
		for px in range(PREVIEW_RESOLUTION.x):
			var x := int(float(px) * float(dims.x) / float(PREVIEW_RESOLUTION.x))
			var height := float(TerrainGenerator.sample_height(continent_noise, detail_noise, ridge_noise, x, y, terrain_settings, centers))
			image.set_pixel(px, py, _preview_height_color(height, water_level))
	var texture := ImageTexture.create_from_image(image)
	map_preview.texture = texture
	if background_map != null:
		background_map.texture = texture

func _preview_height_color(height: float, water_level: float) -> Color:
	if height < water_level - 0.10:
		return Color8(22, 48, 92)
	if height < water_level - 0.03:
		return Color8(34, 72, 126)
	if height < water_level:
		return Color8(52, 102, 156)
	if height < water_level + 0.012:
		return Color8(197, 178, 128)
	if height < water_level + 0.14:
		return Color8(98, 138, 70)
	if height < water_level + 0.26:
		return Color8(72, 110, 56)
	if height < water_level + 0.35:
		return Color8(118, 110, 88)
	if height < water_level + 0.44:
		return Color8(142, 138, 130)
	return Color8(224, 227, 232)

func _on_randomise_chronology_pressed() -> void:
	year_input.value = random_chronology_year()
	age_input.value = random_chronology_age()
	_refresh_summary()

## Browser chronologyBias: rolls skew hard toward the dawn of history.
## Years span 0-50000 with exponent 2.8, then up to four 85% rerolls
## keep most worlds under year 1000; ages span 2-20 with exponent 1.6.
static func biased_random_int(min_value: int, max_value: int, exponent: float) -> int:
	var span := max_value - min_value + 1
	return clampi(min_value + int(floor(pow(randf(), exponent) * float(span))), min_value, max_value)

static func random_chronology_year() -> int:
	var year := biased_random_int(CHRONOLOGY_YEAR_MIN, CHRONOLOGY_YEAR_MAX, 2.8)
	for _retry in range(4):
		if year < 1000 or randf() >= 0.85:
			break
		year = biased_random_int(CHRONOLOGY_YEAR_MIN, CHRONOLOGY_YEAR_MAX, 2.8)
	return year

static func random_chronology_age() -> int:
	return biased_random_int(CHRONOLOGY_AGE_MIN, CHRONOLOGY_AGE_MAX, 1.6)

func _on_randomise_world_name_pressed() -> void:
	world_name_input.text = _generate_world_name()
	_refresh_summary()

func _generate_seed() -> String:
	return "%s%s%s" % [
		_characters_for_seed(3),
		randi_range(100, 999),
		_characters_for_seed(2)
	]

func _generate_world_name() -> String:
	return WORLD_NAMES.pick_random()

func _characters_for_seed(amount: int) -> String:
	const OPTIONS := "abcdefghijklmnopqrstuvwxyz"
	var result := ""
	for _i in amount:
		result += OPTIONS[randi_range(0, OPTIONS.length() - 1)]
	return result

func _on_embark_pressed() -> void:
	if world_name_input.text.strip_edges().is_empty():
		world_name_input.text = _generate_world_name()
		_refresh_summary()
	_store_world_settings()
	SceneCacheService.request_clear(self)
	get_tree().change_scene_to_file("res://scenes/overworld.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/character_creator.tscn")

func _store_world_settings() -> void:
	var map_size: Dictionary = MAP_SIZES[map_size_select.selected]
	var world_seed := seed_input.text.strip_edges()
	if world_seed.is_empty():
		world_seed = _generate_seed()
		seed_input.text = world_seed
	var settings := WorldSettings.merge_with_defaults({
		"map_size_key": map_size["key"],
		"world_layout": world_layout_select.get_item_text(world_layout_select.selected),
		"world_seed": world_seed,
		"world_name": world_name_input.text.strip_edges(),
		"chronology": {
			"year": int(year_input.value),
			"age": int(age_input.value)
		}
	})
	var game_session := get_node_or_null("/root/GameSession")
	if game_session && game_session.has_method("set_world_settings"):
		game_session.call("set_world_settings", settings)

func _apply_cached_world_settings() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("get_world_settings"):
		return
	var settings: Dictionary = game_session.call("get_world_settings")
	if settings.is_empty():
		return

	var map_size_key := str(settings.get("map_size_key", "normal"))
	for i in MAP_SIZES.size():
		var map_size_option: Dictionary = MAP_SIZES[i]
		if String(map_size_option.get("key", "")) == map_size_key:
			map_size_select.select(i)
			break

	var layout := str(settings.get("world_layout", WORLD_LAYOUTS[0]))
	var layout_index := WORLD_LAYOUTS.find(layout)
	if layout_index >= 0:
		world_layout_select.select(layout_index)

	seed_input.text = str(settings.get("world_seed", "")).strip_edges()
	world_name_input.text = str(settings.get("world_name", "")).strip_edges()
	var chronology := settings.get("chronology", {}) as Dictionary
	if chronology.has("year"):
		year_input.value = int(chronology.get("year", 1485))
	if chronology.has("age"):
		# Settings normalization stores the age as "Age N"; int("Age 18")
		# parses to 0 and the SpinBox would silently reset the field.
		age_input.value = max(1, _chronology_age_number(chronology.get("age")))

static func _chronology_age_number(age_value: Variant) -> int:
	if age_value is int or age_value is float:
		return int(age_value)
	var digits := ""
	for age_char in String(age_value):
		if age_char >= "0" and age_char <= "9":
			digits += age_char
	return int(digits) if not digits.is_empty() else 18
