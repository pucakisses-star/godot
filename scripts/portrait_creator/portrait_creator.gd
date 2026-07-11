@tool
class_name PortraitCreator
extends Control

signal resend_images

## This needs to match with the indexes in the file
## portrait_indexes.gdshaderinc with identifier uid://wfjoy5r4lanh
enum Images {
	PORTRAIT,
	BEARD,
	HAIR
}
const AMOUNT_OF_IMAGES := 3

static var instance: PortraitCreator

@export var target_render: Control
@export var part_picker: PackedScene

@export_group(&"Directories")
@export var character_name: LineEdit
@export var profession_choice: OptionButton
@export var clan_name: OptionButton
@export var female_button: Button
@export var male_button: Button
@export var return_button: Button
@export var create_button: Button
@export var animated_background: TextureRect

const CLAN_OPTIONS := [
	"Stonebeard",
	"Barrelbrow",
	"Oathhammer",
	"Stormshield",
	"Granitebrow",
	"Emberstone",
	"Blackdelve",
	"Hearthhammer",
	"Mithrilbeard",
	"Shieldbreaker",
	"Deepcrag",
	"Duskhollow",
	"Hammerdeep",
	"Deepmantle",
	"Ashmantle",
	"Shadowhearth",
	"Angrund",
	"Angrulok",
	"Badrikk",
	"Barruk",
	"Burrdrik",
	"Bronzebeards",
	"Bronzefist",
	"Copperback",
	"Cragbrow",
	"Craghand",
	"Cragtooth",
	"Donarkhun",
	"Dourback",
	"Dragonback",
	"Drakebeard",
	"Drazhkarak",
	"Dunrakin",
	"Firehand",
	"Firehelm",
	"Flintbeard",
	"Flinthand",
	"Flintheart",
	"Fooger",
	"Forgehand",
	"Grimhelm",
	"Grimstone",
	"Gunnarsson",
	"Gunnisson",
	"Guttrik",
	"Halgakrin",
	"Hammerback",
	"Helhein",
	"Irebeard",
	"Ironbeard",
	"Ironarm",
	"Ironback",
	"Ironfist",
	"Ironforge",
	"Ironhammer",
	"Ironpick",
	"Ironspike",
	"Izorgrung",
	"Kaznagar",
	"Magrest",
	"Norgrimlings",
	"Oakbarrel",
	"Redbeard",
	"Silverscar",
	"Skorrun",
	"Steelcrag",
	"Sternbeard",
	"Stoneback",
	"Stonebeater",
	"Stonebreakers",
	"Stonehammer",
	"Stonehand",
	"Stoneheart",
	"Stoutgirth",
	"Stoutpeak",
	"Svengeln",
	"Threkkson",
	"Thundergun",
	"Thunderheart",
	"Thunderstone",
	"Varnskan",
	"Vorgrund",
	"Yinlinsson",
	"Coppervein",
	"Graniteheart",
	"Deepdelver",
	"Amberpick",
	"Oakenshield",
	"Frosthammer",
	"Berylbraid",
	"Silverhollow",
	"Brazenaxe",
	"Stormhammer",
	"Deeprock",
	"Goldvein",
	"Runesmith",
	"Aleswiller",
	"Argent Hand",
	"Axebreaker",
	"Blackfire",
	"Bloodstone",
	"Boulderscorch",
	"Duergar",
	"Fiania",
	"Goldenforge",
	"Gordemuncher",
	"Hammerhead",
	"Ironson",
	"Kazak Uruk",
	"Orcsplitter",
	"Rockcrawler",
	"Shattered Stone",
	"Bronzebeard",
	"Stormpike",
	"Stonefist",
	"Hylar",
	"Daergar",
	"Daewar",
	"Theiwar",
	"Aghar",
	"Battlehammer",
	"Bitterroot",
	"Black Axe",
	"Boldenbar",
	"Bouldershoulder",
	"Brawnanvil",
	"Brightblade",
	"Brighthelm",
	"Broodhull",
	"Bruenghor",
	"Bukbukken",
	"Chistlesmith",
	"Eaglecleft",
	"Flameshade",
	"Muzgardt",
	"Stoneshaft",
	"Ticklebeard",
	"Dankil",
	"Daraz",
	"Forgebar",
	"Gemcrypt",
	"Girdaur",
	"Hammerhand",
	"Hardhammer",
	"Herlinga",
	"Hillborn",
	"Hillsafar",
	"Horn",
	"Icehammer",
	"Ironeater",
	"Ironstar",
	"Licehair",
	"Ludwakazar",
	"Madbeards",
	"McKnuckles",
	"McRuff",
	"Melairkyn",
	"Orcsmasher",
	"Orothiar",
	"Pwent",
	"Rockjaw",
	"Rookoath",
	"Rustfire",
	"Sandbeards",
	"Shattershield",
	"Stonebridge",
	"Stoneshoulder",
	"Stouthammer",
	"Sunblight",
	"Undurr",
	"Grimlock",
	"MacCloud",
	"Thundermore",
	"Enogtorad",
	"Drummond",
	"Tolorr",
	"Vanderholl",
	"Aringeld",
	"Firecask",
	"Gelderon",
	"Grimmark",
	"Molgrade",
	"Runebinder",
	"Orridus",
	"Shalefoot",
	"Silverhair",
	"Copperlung",
	"Stonescar",
	"Flintbristle",
	"Stonehollow",
	"Silverpick",
	"Ironheart",
	"Weoughld",
	"Llyrnillach",
	"Highhelm"
]

const MALE_NAME_POOL := [
	"Baern",
	"Dimli",
	"Einkar",
	"Gimli",
	"Harbek",
	"Kargun",
	"Mardin",
	"Orsik",
	"Rurik",
	"Thorin",
	"Ulfgar",
	"Vondal",
	"Urist",
	"Thob",
	"Kadol",
	"Stukos",
	"Likot",
	"Datan",
	"Mörul",
	"Logem",
	"Rakust",
	"Gorim",
	"Norgrim",
	"Balgor",
	"Balgrum",
	"Balro",
	"Byron",
	"Dain",
	"Daragin",
	"Darmar",
	"Darrius",
	"Datunashvili",
	"Dorgan",
	"Dranvin",
	"Duragin",
	"Durgin",
	"Durin",
	"Durnak",
	"Elgor",
	"Flindir",
	"Gardian",
	"Gorin",
	"Harald",
	"Hoogin",
	"Horgrim",
	"Hoyreal",
	"Hrothar",
	"Jamin",
	"Jarin",
	"Jarroc",
	"Khordryn",
	"Kordrim",
	"Korgrim",
	"Kurgil",
	"Maldrik",
	"Marius",
	"Mordrun",
	"Morgrim",
	"Muradin",
	"Odrin",
	"Oshuart",
	"Roorke",
	"Thaivo",
	"Thalgrim",
	"Tharagin",
	"Thorek",
	"Thorgrim",
	"Thrain",
	"Thror",
	"Thuringar",
	"Torgrim",
	"Trearagin",
	"Tyr",
	"Ulgrim",
	"Vearspan",
	"Vondar",
	"Bargrin",
	"Drokal",
	"Khardek",
	"Brundar",
	"Kolgrim",
	"Tharnok",
	"Grimvek",
	"Odrak",
	"Storn",
	"Baldrik",
	"Khemdir",
	"Rugnar",
	"Haldrek",
	"Morvek",
	"Durnik",
	"Kargath",
	"Ulvorn",
	"Brannik",
	"Thorekkan",
	"Galdur",
	"Ragnor",
	"Dromli",
	"Skarn",
	"Vuldrek",
	"Korvash",
	"Drakkel",
	"Borgran",
	"Khuldir",
	"Tarnak",
	"Grodin",
	"Malgrom",
	"Fenrik",
	"Ogrimak",
	"Durvash",
	"Balrik",
	"Thuldar",
	"Krommel",
	"Jarndek",
	"Moradin",
	"Hurgan",
	"Skeldor",
	"Brandek",
	"Vulkar",
	"Dornik",
	"Grimdar",
	"Rokhan",
	"Kharn",
	"Ulgrin",
	"Brumak",
	"Tharvek",
	"Gromlir",
	"Kardun",
	"Vordek",
	"Sturgan",
	"Malrik",
	"Orvash",
	"Drundel",
	"Hrodek",
	"Kargul",
	"Balvorn",
	"Thurnik",
	"Grovak",
	"Ruldar",
	"Dorgath",
	"Skorim",
	"Branvor",
	"Khordek",
	"Murvek",
	"Tarnor",
	"Vulgrim",
	"Drekal",
	"Harnok",
	"Borvik",
	"Grimlor",
	"Ulmar",
	"Stenrik",
	"Kardrim",
	"Throlin",
	"Gurnak",
	"Morgrin",
	"Yorrill",
	"Zromin"
]

const FEMALE_NAME_POOL := [
	"Audhild",
	"Brynna",
	"Diesa",
	"Eldeth",
	"Finellen",
	"Gurdis",
	"Helja",
	"Kathra",
	"Liftrasa",
	"Sannl",
	"Torbera",
	"Vistra",
	"Domas",
	"Rigòth",
	"Kadôl",
	"Meng",
	"Onol",
	"Rith",
	"Sigrid",
	"Thilda",
	"Asgrid",
	"Helga",
	"Goden",
	"Emera",
	"Hilda",
	"Moira",
	"Brunna",
	"Keldra",
	"Audrika",
	"Thorga",
	"Durnella",
	"Grimsa",
	"Hildren",
	"Baldris",
	"Skara",
	"Vondra",
	"Khorra",
	"Bryndis",
	"Ulvara",
	"Morna",
	"Ragna",
	"Torhilda",
	"Dagna",
	"Finra",
	"Kardra",
	"Helvara",
	"Sigrun",
	"Borna",
	"Thryssa",
	"Kelmora",
	"Audra",
	"Skaldi",
	"Vigrid",
	"Durnis",
	"Grimna",
	"Hroda",
	"Brilda",
	"Malda",
	"Orla",
	"Khendra",
	"Balra",
	"Thildaen",
	"Gurna",
	"Rigdra",
	"Ulrissa",
	"Morgria",
	"Tarnis",
	"Brylda",
	"Kardis",
	"Hella",
	"Fenna",
	"Skorla",
	"Dorga",
	"Thorae",
	"Brunnae",
	"Vendra",
	"Korga",
	"Audmora",
	"Runa",
	"Grimra",
	"Heldis",
	"Borika",
	"Dagnae",
	"Thryna",
	"Ulmara",
	"Skelda",
	"Mornael",
	"Keldis",
	"Ragnae",
	"Brindra",
	"Gildra",
	"Tarnia",
	"Kardella",
	"Hrothra",
	"Baldis",
	"Fenra",
	"Skarna",
	"Vuldra",
	"Ordis",
	"Durnika",
	"Bryssa",
	"Thulda",
	"Grena",
	"Ulgrida",
	"Mordra",
	"Khora"
]

@export_group(&"Directories")
@export_dir var portrait_dir: String
@export_dir var beard_dir: String
@export_dir var hair_dir: String

@export_group(&"Sliders")
@export var skin_color: HSlider
@export var clothing_color: HSlider
@export var hair_color: HSlider
@export var hair_style: HSlider
@export var beard_color: HSlider
@export var beard_style: HSlider

@export_group(&"Attribute Icons")
@export var beardless_reminder: Control
@export var dark_dwarf_reminder: Control
@export var grey_dwarf_reminder: Control
@export var banker_reminder: Control
@export var attribute_tooltip_backdrop: ColorRect
@export var attribute_tooltip_panel: Control
@export var attribute_reminder_title: Label
@export var attribute_reminder_text: Label

@export_group(&"Default images")
@export var portrait: CompressedTexture2D:
	get:
		return _portrait
	set(value):
		_portrait = value
		resend_images.emit()

@export var beard: CompressedTexture2D:
	get:
		return _beard
	set(value):
		_beard = value
		resend_images.emit()

@export var hair: CompressedTexture2D:
	get:
		return _hair
	set(value):
		_hair = value
		resend_images.emit()

var _portrait: CompressedTexture2D
var _beard: CompressedTexture2D
var _hair: CompressedTexture2D

var _images: Array[CompressedTexture2D]
var _colors: Array[Vector3]

var _selected := Images.PORTRAIT
var _is_female := false
var _rng := RandomNumberGenerator.new()

var _available_beards: Array[CompressedTexture2D]
var _available_hairs: Array[CompressedTexture2D]
var _gender_button_hover_shadow: StyleBoxFlat
var _gender_button_pressed_shadow: StyleBoxFlat
var _gender_button_normal_shadow: StyleBoxFlat

const GENDER_BUTTON_BRIGHTNESS_NORMAL := 0.85
const GENDER_BUTTON_BRIGHTNESS_HOVER := 1.08
const GENDER_BUTTON_BRIGHTNESS_PRESSED := 1.18
const GENDER_BUTTON_TWEEN_DURATION := 0.12
const BACKGROUND_ZOOM_SPEED := 0.0034
const BACKGROUND_ZOOM_AMOUNT := 0.08
const BEARD_STYLE_ENABLED_MODULATE := Color(1, 1, 1, 1)
const BEARD_STYLE_DISABLED_MODULATE := Color(0.55, 0.55, 0.55, 1)
const ROLLING_DICE_SOUND_PATH := "res://resources/sounds/rolling-dice.mp3"

var _hovered_attribute_icon: Control
var _randomize_sound_player: AudioStreamPlayer

## The pixel dwarf built from the Dwarf Fortress layer sheets, kept in
## sync with the painted portrait: the same sliders drive both, and the
## composed sprite is the player's in-world body.
var _dwarf_preview: TextureRect
var _dwarf_body_preview: TextureRect
var _stats_label: Label
var _background_zoom := 1.0

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	instance = null
	_images.clear()
	_available_hairs.clear()
	_available_beards.clear()

func _ready() -> void:
	_rng.randomize()
	_load_available_hairs()
	_load_available_beards()

	skin_color.value_changed.connect(_on_color_changed.bind(Images.PORTRAIT))
	hair_color.value_changed.connect(_on_color_changed.bind(Images.HAIR))
	if hair_style:
		hair_style.value_changed.connect(_on_hair_style_changed)
	if beard_color:
		beard_color.value_changed.connect(_on_color_changed.bind(Images.BEARD))
	if beard_style:
		beard_style.value_changed.connect(_on_beard_style_changed)

	character_name.text_changed.connect(_on_name_changed)
	if female_button:
		female_button.toggle_mode = true
		female_button.pressed.connect(_set_gender.bind(true))
		_setup_gender_button(female_button)
	if male_button:
		male_button.toggle_mode = true
		male_button.pressed.connect(_set_gender.bind(false))
		_setup_gender_button(male_button)
	if return_button:
		_setup_gender_button(return_button)
	if create_button:
		_setup_gender_button(create_button)

	clan_name.clear()
	for clan: String in CLAN_OPTIONS:
		clan_name.add_item(clan)
	if clan_name:
		clan_name.item_selected.connect(_on_clan_selected)
	if profession_choice:
		profession_choice.item_selected.connect(_on_profession_selected)
		if profession_choice.item_count > 0 and profession_choice.selected < 0:
			profession_choice.select(0)

	resend_images.connect(_on_resend_images)

	_images.resize(3)
	_colors.resize(3)
	_setup_beard_style_slider()
	_update_beard_style_availability()
	_setup_hair_style_slider()
	_configure_attribute_reminder_entries()
	_refresh_random_name()
	_update_attribute_reminders()
	_update_gender_button_selection_visuals()
	_clear_attribute_description()
	_setup_animated_background()
	_setup_clothing_slider()
	_build_dwarf_body_panel()
	_build_stats_label()
	_refresh_dwarf_preview()

	# Open on a fresh random dwarf every time the creator loads — all parts
	# rolled, not the same default. Editor previews keep their authored state.
	if not Engine.is_editor_hint():
		_randomize_all_parts()

func _process(delta: float) -> void:
	_position_attribute_tooltip()
	_update_animated_background(delta)

func _setup_animated_background() -> void:
	if animated_background == null:
		return
	animated_background.pivot_offset = animated_background.size * 0.5

## --- In-world body ------------------------------------------------------
## A framed panel on the right shows the dwarf assembled from the Dwarf
## Fortress layer sheets at pixel scale; every slider that shapes the
## painted portrait reshapes this dwarf too.

const BODY_PANEL_TEXTURE := preload("res://resources/images/character_creator/ui/bodypanel.png")

func _build_dwarf_body_panel() -> void:
	if target_render == null:
		return
	# Head bust in the stone face frame, top left.
	var frame_holder := target_render.get_parent()
	if frame_holder == null:
		return
	_dwarf_preview = TextureRect.new()
	_dwarf_preview.name = "DwarfPreview"
	_dwarf_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dwarf_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_dwarf_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_dwarf_preview.position = Vector2(72.0, 40.0)
	_dwarf_preview.size = Vector2(280.0, 280.0)
	frame_holder.add_child(_dwarf_preview)
	# The old painted-portrait render is superseded by the pixel bust;
	# left visible it bleeds through as a dark silhouette.
	target_render.visible = false
	# The full dwarf takes over the big center panel from the old static
	# painted body.
	var static_body := find_child("DwarfBodySprite2", true, false) as TextureRect
	if static_body != null:
		static_body.visible = false
		var panel := static_body.get_parent() as Control
		_dwarf_body_preview = TextureRect.new()
		_dwarf_body_preview.name = "DwarfBodyPreview"
		_dwarf_body_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_dwarf_body_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_dwarf_body_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_dwarf_body_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
		_dwarf_body_preview.offset_left = 28.0
		_dwarf_body_preview.offset_right = -28.0
		_dwarf_body_preview.offset_top = 30.0
		_dwarf_body_preview.offset_bottom = -30.0
		panel.add_child(_dwarf_body_preview)

func _setup_clothing_slider() -> void:
	if clothing_color == null:
		return
	clothing_color.min_value = 0
	clothing_color.step = 1
	clothing_color.max_value = DwarfSpriteComposer.CLOTHES_COLOR_COUNT - 1
	if not clothing_color.value_changed.is_connected(_on_clothing_changed):
		clothing_color.value_changed.connect(_on_clothing_changed)

func _on_clothing_changed(_value: float) -> void:
	_refresh_dwarf_preview()

## Slider fractions map onto the sheet's discrete palettes, so a nudge
## of skin or hair color moves both views together.
func _slider_fraction(slider: HSlider) -> float:
	if slider == null or slider.max_value <= slider.min_value:
		return 0.0
	return clampf((slider.value - slider.min_value) / (slider.max_value - slider.min_value), 0.0, 1.0)

func _fraction_to_index(fraction: float, count: int) -> int:
	return clampi(int(fraction * float(count)), 0, count - 1)

func _current_dwarf_layers() -> Dictionary:
	## Females never carry a beard, mirroring the painted-portrait path
	## which nulls the beard layer when female is selected.
	var beardless := _is_female or (beard_style != null and is_equal_approx(beard_style.value, beard_style.max_value))
	var hair_index := int(hair_style.value) if hair_style != null else 0
	var beard_index := int(beard_style.value) if beard_style != null else 0
	return {
		"skin_tone": _fraction_to_index(_slider_fraction(skin_color), DwarfSpriteComposer.SKIN_TONE_ROWS.size()),
		"hair_style": hair_index % DwarfSpriteComposer.HAIR_STYLE_ROWS.size(),
		"hair_color": _fraction_to_index(_slider_fraction(hair_color), DwarfSpriteComposer.COLOR_COLUMN_COUNT),
		"beard_style": -1 if beardless else beard_index % DwarfSpriteComposer.BEARD_STYLE_ROWS.size(),
		"beard_color": _fraction_to_index(_slider_fraction(beard_color), DwarfSpriteComposer.COLOR_COLUMN_COUNT),
		"clothes_color": int(clothing_color.value) if clothing_color != null else 7
	}

func _refresh_dwarf_preview() -> void:
	var layers := _current_dwarf_layers()
	if _dwarf_preview != null:
		_dwarf_preview.texture = DwarfSpriteComposer.compose_head(layers)
	if _dwarf_body_preview != null:
		_dwarf_body_preview.texture = DwarfSpriteComposer.compose(layers)

func _update_animated_background(delta: float) -> void:
	if animated_background == null:
		return
	if animated_background.pivot_offset == Vector2.ZERO and animated_background.size != Vector2.ZERO:
		animated_background.pivot_offset = animated_background.size * 0.5
	var max_zoom := 1.0 + BACKGROUND_ZOOM_AMOUNT
	_background_zoom = minf(max_zoom, _background_zoom + (BACKGROUND_ZOOM_SPEED * delta))
	animated_background.scale = Vector2.ONE * _background_zoom

func _configure_attribute_reminder_entries() -> void:
	_configure_attribute_reminder_entry(beardless_reminder)
	_configure_attribute_reminder_entry(dark_dwarf_reminder)
	_configure_attribute_reminder_entry(grey_dwarf_reminder)
	_configure_attribute_reminder_entry(banker_reminder)

func _configure_attribute_reminder_entry(entry: Control) -> void:
	if entry == null:
		return
	var icon := entry.find_child("Icon", true, false) as Control
	var text := entry.get_node_or_null("Text") as Label
	if icon and icon.get_parent() == entry:
		entry.move_child(icon, 0)
	if text:
		text.visible = false
	if icon and text:
		var description_text := text.text.strip_edges()
		var title := description_text.get_slice(":", 0).strip_edges()
		var body := description_text.substr(title.length()).trim_prefix(":").strip_edges()
		icon.set_meta("attribute_title", title)
		icon.set_meta("attribute_description", body)
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.tooltip_text = ""
		icon.mouse_entered.connect(_on_attribute_icon_hovered.bind(icon))
		icon.mouse_exited.connect(_on_attribute_icon_unhovered.bind(icon))

func _on_attribute_icon_hovered(icon: Control) -> void:
	if icon == null:
		return
	_hovered_attribute_icon = icon
	var title := String(icon.get_meta("attribute_title", "")).strip_edges()
	var description := String(icon.get_meta("attribute_description", "")).strip_edges()
	if attribute_tooltip_panel:
		attribute_tooltip_panel.visible = true
	if attribute_tooltip_backdrop:
		attribute_tooltip_backdrop.visible = false
	if attribute_reminder_title:
		attribute_reminder_title.text = title
	if attribute_reminder_text:
		attribute_reminder_text.text = description
		attribute_reminder_text.visible = not description.is_empty()
	_position_attribute_tooltip()

func _on_attribute_icon_unhovered(icon: Control) -> void:
	if icon == _hovered_attribute_icon:
		_hovered_attribute_icon = null
		_clear_attribute_description()

func _clear_attribute_description() -> void:
	if attribute_tooltip_panel:
		attribute_tooltip_panel.visible = false
	if attribute_tooltip_backdrop:
		attribute_tooltip_backdrop.visible = false
	if attribute_reminder_title:
		attribute_reminder_title.text = ""
	if attribute_reminder_text:
		attribute_reminder_text.text = ""
		attribute_reminder_text.visible = false

## Floats above the hovered icon like a normal tooltip, clamped to the
## viewport (falls below the icon when there is no room above).
func _position_attribute_tooltip() -> void:
	if attribute_tooltip_panel == null or not attribute_tooltip_panel.visible:
		return
	if _hovered_attribute_icon == null or not is_instance_valid(_hovered_attribute_icon):
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var tooltip_size := attribute_tooltip_panel.get_combined_minimum_size()
	attribute_tooltip_panel.size = tooltip_size
	var viewport_size := viewport.get_visible_rect().size
	var icon_rect := _hovered_attribute_icon.get_global_rect()
	var target_pos := Vector2(
		icon_rect.get_center().x - tooltip_size.x * 0.5,
		icon_rect.position.y - tooltip_size.y - 10.0
	)
	if target_pos.y < 4.0:
		target_pos.y = icon_rect.end.y + 10.0
	target_pos.x = clampf(target_pos.x, 4.0, maxf(4.0, viewport_size.x - tooltip_size.x - 4.0))
	target_pos.y = clampf(target_pos.y, 4.0, maxf(4.0, viewport_size.y - tooltip_size.y - 4.0))
	attribute_tooltip_panel.position = target_pos

func _setup_gender_button(button: Button) -> void:
	if !_gender_button_normal_shadow:
		_gender_button_normal_shadow = _build_gender_shadow_style(0, Color(0, 0, 0, 0), Vector2.ZERO)
		_gender_button_hover_shadow = _build_gender_shadow_style(10, Color(0, 0, 0, 0.35), Vector2(0, 4))
		_gender_button_pressed_shadow = _build_gender_shadow_style(14, Color(0, 0, 0, 0.45), Vector2(0, 6))

	button.add_theme_stylebox_override("normal", _gender_button_normal_shadow)
	button.add_theme_stylebox_override("hover", _gender_button_hover_shadow)
	button.add_theme_stylebox_override("pressed", _gender_button_pressed_shadow)
	button.add_theme_stylebox_override("focus", _gender_button_hover_shadow)
	button.add_theme_stylebox_override("hover_pressed", _gender_button_pressed_shadow)

	button.self_modulate = Color(GENDER_BUTTON_BRIGHTNESS_NORMAL, GENDER_BUTTON_BRIGHTNESS_NORMAL, GENDER_BUTTON_BRIGHTNESS_NORMAL, 1.0)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	button.mouse_entered.connect(_on_gender_button_hover.bind(button))
	button.mouse_exited.connect(_on_gender_button_unhover.bind(button))
	button.focus_entered.connect(_on_gender_button_hover.bind(button))
	button.focus_exited.connect(_on_gender_button_unhover.bind(button))
	button.button_down.connect(_on_gender_button_pressed.bind(button))
	button.button_up.connect(_on_gender_button_released.bind(button))

func _build_gender_shadow_style(shadow_size: int, color: Color, offset: Vector2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.shadow_size = shadow_size
	style.shadow_color = color
	style.shadow_offset = offset
	return style

func _on_gender_button_hover(button: Button) -> void:
	if button.is_pressed():
		return
	_animate_gender_button(button, GENDER_BUTTON_BRIGHTNESS_HOVER)

func _on_gender_button_unhover(button: Button) -> void:
	if button.is_pressed():
		return
	_animate_gender_button(button, GENDER_BUTTON_BRIGHTNESS_NORMAL)

func _on_gender_button_pressed(button: Button) -> void:
	_animate_gender_button(button, GENDER_BUTTON_BRIGHTNESS_PRESSED)

func _on_gender_button_released(button: Button) -> void:
	if button.button_pressed:
		return
	if button.is_hovered() or button.has_focus():
		_animate_gender_button(button, GENDER_BUTTON_BRIGHTNESS_HOVER)
	else:
		_animate_gender_button(button, GENDER_BUTTON_BRIGHTNESS_NORMAL)

func _animate_gender_button(button: Button, brightness: float) -> void:
	var tween := button.create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "self_modulate", Color(brightness, brightness, brightness, 1.0), GENDER_BUTTON_TWEEN_DURATION)

func _refresh_random_name() -> void:
	if character_name.text.strip_edges().is_empty():
		character_name.text = _generate_full_name()

func _set_gender(is_female: bool) -> void:
	_is_female = is_female
	_update_gender_button_selection_visuals()
	_update_beard_style_availability()
	## Recompose the pixel preview so the beard change shows immediately.
	_refresh_dwarf_preview()
	character_name.text = _generate_full_name()
	_update_attribute_reminders()

func _update_gender_button_selection_visuals() -> void:
	if female_button == null or male_button == null:
		return

	female_button.button_pressed = _is_female
	male_button.button_pressed = not _is_female

	_update_gender_button_visual_state(female_button, _is_female)
	_update_gender_button_visual_state(male_button, not _is_female)

func _update_gender_button_visual_state(button: Button, is_selected: bool) -> void:
	if button == null:
		return

	# The buttons live in an HBoxContainer, which owns their positions -
	# nudging position here collapsed both onto one spot (a vanishing
	# button). Selection reads through brightness and the pressed shadow.
	if is_selected:
		_animate_gender_button(button, GENDER_BUTTON_BRIGHTNESS_PRESSED)
	elif button.is_hovered() or button.has_focus():
		_animate_gender_button(button, GENDER_BUTTON_BRIGHTNESS_HOVER)
	else:
		_animate_gender_button(button, GENDER_BUTTON_BRIGHTNESS_NORMAL)

func _update_beard_style_availability() -> void:
	if beard_style == null:
		return
	beard_style.editable = not _is_female
	beard_style.mouse_filter = Control.MOUSE_FILTER_IGNORE if _is_female else Control.MOUSE_FILTER_STOP
	beard_style.focus_mode = Control.FOCUS_NONE if _is_female else Control.FOCUS_ALL
	beard_style.modulate = BEARD_STYLE_DISABLED_MODULATE if _is_female else BEARD_STYLE_ENABLED_MODULATE
	if _is_female:
		beard = null

func _generate_random_name() -> String:
	var pool := FEMALE_NAME_POOL if _is_female else MALE_NAME_POOL
	if pool.is_empty():
		return ""
	return pool[_rng.randi_range(0, pool.size() - 1)]

func _get_selected_clan() -> String:
	if clan_name and clan_name.item_count > 0:
		var selected_index := clan_name.selected
		if selected_index < 0:
			selected_index = 0
		return clan_name.get_item_text(selected_index)
	return ""

func _generate_full_name(first_name: String = "") -> String:
	var given_name := first_name.strip_edges()
	if given_name.is_empty():
		given_name = _generate_random_name()
	var clan := _get_selected_clan()
	if clan.is_empty():
		return given_name
	return "%s %s" % [given_name, clan]

func _on_clan_selected(_index: int) -> void:
	var current_name := character_name.text.strip_edges()
	var given_name := current_name
	if current_name.contains(" "):
		given_name = current_name.split(" ", false, 1)[0]
	character_name.text = _generate_full_name(given_name)

func _on_name_changed(_new_text: String) -> void:
	for curr_idx in AMOUNT_OF_IMAGES:
		_colors[curr_idx].z = 1
	var shader: ShaderMaterial = target_render.material
	shader.set_shader_parameter(&"colors", _colors)

func _load_available_beards() -> void:
	_available_beards.clear()
	var dir := DirAccess.open(beard_dir)
	if dir == null:
		return
	var beard_files := PackedStringArray()
	for curr_file in dir.get_files():
		if curr_file.ends_with(".png"):
			beard_files.append(curr_file)
	beard_files.sort()
	for curr_file in beard_files:
		_available_beards.append(load(beard_dir.path_join(curr_file)))

func _load_available_hairs() -> void:
	_available_hairs.clear()
	var dir := DirAccess.open(hair_dir)
	if dir == null:
		return
	var hair_files := PackedStringArray()
	for curr_file in dir.get_files():
		if curr_file.ends_with(".png"):
			hair_files.append(curr_file)
	hair_files.sort()
	for curr_file in hair_files:
		_available_hairs.append(load(hair_dir.path_join(curr_file)))

func _setup_hair_style_slider() -> void:
	if hair_style == null:
		return
	hair_style.min_value = 0
	hair_style.step = 1
	hair_style.max_value = maxi(_available_hairs.size() - 1, 0)
	hair_style.value = 0
	_on_hair_style_changed(hair_style.value)

func _on_hair_style_changed(value: float) -> void:
	if _available_hairs.is_empty():
		return
	var style_index := clampi(int(round(value)), 0, _available_hairs.size() - 1)
	hair = _available_hairs[style_index]
	_refresh_dwarf_preview()

func _setup_beard_style_slider() -> void:
	if beard_style == null:
		return
	beard_style.min_value = 0
	beard_style.step = 1
	beard_style.max_value = _available_beards.size()
	beard_style.value = 0
	_on_beard_style_changed(beard_style.value)

func _on_beard_style_changed(value: float) -> void:
	var style_index := int(round(value))
	if _available_beards.is_empty():
		beard = null
	elif style_index >= _available_beards.size():
		beard = null
	else:
		beard = _available_beards[clampi(style_index, 0, _available_beards.size() - 1)]
	_refresh_dwarf_preview()
	_update_attribute_reminders()

func _on_profession_selected(_index: int) -> void:
	_update_stats_label()
	_update_attribute_reminders()

## The profession's combat stats, shown right under the dropdown so the
## choice visibly matters.
func _build_stats_label() -> void:
	if profession_choice == null:
		return
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 13)
	_stats_label.modulate = Color(0.95, 0.85, 0.6, 1.0)
	var host := profession_choice.get_parent()
	host.add_child(_stats_label)
	host.move_child(_stats_label, profession_choice.get_index() + 1)
	_update_stats_label()

func _update_stats_label() -> void:
	if _stats_label == null:
		return
	var profession := ""
	if profession_choice != null and profession_choice.selected >= 0:
		profession = profession_choice.get_item_text(profession_choice.selected)
	_stats_label.text = PlayerStatsService.stat_summary({"profession": profession})

func _update_attribute_reminders() -> void:
	if banker_reminder:
		banker_reminder.visible = _is_banker_selected()
	if dark_dwarf_reminder:
		dark_dwarf_reminder.visible = _is_dark_dwarf_selected()
	if grey_dwarf_reminder:
		grey_dwarf_reminder.visible = _is_grey_dwarf_selected()
	if beardless_reminder:
		beardless_reminder.visible = _is_beardless_selected()

	if _hovered_attribute_icon and not _hovered_attribute_icon.is_visible_in_tree():
		_hovered_attribute_icon = null
		_clear_attribute_description()

func _is_banker_selected() -> bool:
	if profession_choice == null or profession_choice.item_count == 0:
		return false
	var selected_index := profession_choice.selected
	if selected_index < 0:
		return false
	return profession_choice.get_item_text(selected_index).to_lower() == "banker"

func _is_dark_dwarf_selected() -> bool:
	if skin_color == null:
		return false
	return is_equal_approx(skin_color.value, skin_color.max_value)

func _is_grey_dwarf_selected() -> bool:
	if skin_color == null:
		return false
	return is_equal_approx(skin_color.value, skin_color.min_value)

func _is_beardless_selected() -> bool:
	if beard_style == null:
		return false
	return is_equal_approx(beard_style.value, beard_style.max_value)

func _on_resend_images() -> void:
	_images[Images.PORTRAIT] = portrait
	_images[Images.BEARD] = beard
	_images[Images.HAIR] = hair

	var shader: ShaderMaterial = target_render.material
	shader.set_shader_parameter(&"images", _images)

func _on_color_changed(value: float, type: Images) -> void:
	_colors[type].x = value
	var shader: ShaderMaterial = target_render.material
	shader.set_shader_parameter(&"colors", _colors)
	_refresh_dwarf_preview()
	if type == Images.PORTRAIT:
		_update_attribute_reminders()

func _on_gamma_changed(value: float) -> void:
	_colors[_selected].z = value
	var shader: ShaderMaterial = target_render.material
	shader.set_shader_parameter(&"colors", _colors)

func _on_return_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/mainmenu.tscn")

func _on_create_button_pressed() -> void:
	_persist_character_to_session()
	## A successor character (born from the game-over screen) inherits the
	## dead walker's world: skip the world forge and land straight on the
	## existing overworld, where Begin Journey embarks anywhere afresh.
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null and game_session.has_method("consume_same_world_rebirth") and bool(game_session.call("consume_same_world_rebirth")):
		get_tree().change_scene_to_file("res://scenes/overworld.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/world_generation_display.tscn")

func _persist_character_to_session() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("set_player_character"):
		return
	game_session.call("set_player_character", _build_character_dict())

func _build_character_dict() -> Dictionary:
	var profession_text := ""
	if profession_choice and profession_choice.selected >= 0:
		profession_text = profession_choice.get_item_text(profession_choice.selected)
	var clan_text := ""
	if clan_name and clan_name.selected >= 0:
		clan_text = clan_name.get_item_text(clan_name.selected)
	return {
		"name": character_name.text if character_name else "",
		"gender": "female" if _is_female else "male",
		"profession": profession_text,
		"clan": clan_text,
		"skin_color": skin_color.value if skin_color else 0.0,
		"clothing_color": clothing_color.value if clothing_color else 0.0,
		"hair_color": hair_color.value if hair_color else 0.0,
		"hair_style": int(hair_style.value) if hair_style else 0,
		"beard_color": beard_color.value if beard_color else 0.0,
		"beard_style": int(beard_style.value) if beard_style else 0,
		"dwarf_layers": _current_dwarf_layers()
	}

func _on_randomize_button_pressed() -> void:
	_play_randomize_sound()
	_randomize_all_parts()

## Rolls every part of the character — gender, profession, clan, skin/hair/beard
## colors, hair and beard style, clothing color and name — to a fresh random
## combination. Driven by the dice button and once on load (see _ready) so the
## creator always opens on a new dwarf rather than the same default.
func _randomize_all_parts() -> void:
	_set_gender(_rng.randf() < 0.5)

	if profession_choice and profession_choice.item_count > 0:
		profession_choice.select(_rng.randi_range(0, profession_choice.item_count - 1))
	if clan_name and clan_name.item_count > 0:
		clan_name.select(_rng.randi_range(0, clan_name.item_count - 1))
	if skin_color:
		skin_color.value = _rng.randf_range(skin_color.min_value, skin_color.max_value)
	if hair_color:
		hair_color.value = _rng.randf_range(hair_color.min_value, hair_color.max_value)
	if beard_color:
		beard_color.value = _rng.randf_range(beard_color.min_value, beard_color.max_value)
	if beard_style:
		beard_style.value = _rng.randi_range(int(beard_style.min_value), int(beard_style.max_value))
	if hair_style:
		hair_style.value = _rng.randi_range(int(hair_style.min_value), int(hair_style.max_value))

	if clothing_color:
		clothing_color.value = _rng.randi_range(0, DwarfSpriteComposer.CLOTHES_COLOR_COUNT - 1)
	_refresh_dwarf_preview()
	_update_stats_label()

	character_name.text = _generate_full_name()
	_update_attribute_reminders()

func _play_randomize_sound() -> void:
	if not ResourceLoader.exists(ROLLING_DICE_SOUND_PATH):
		return
	var rolling_dice_sound := load(ROLLING_DICE_SOUND_PATH) as AudioStream
	if rolling_dice_sound == null:
		return
	if _randomize_sound_player == null:
		_randomize_sound_player = AudioStreamPlayer.new()
		_randomize_sound_player.name = "RandomizeSoundPlayer"
		add_child(_randomize_sound_player)
	_randomize_sound_player.stream = rolling_dice_sound
	_randomize_sound_player.play()
