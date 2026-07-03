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
@export var eye_color: HSlider
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
var _gender_button_base_positions: Dictionary = {}

const GENDER_BUTTON_BRIGHTNESS_NORMAL := 0.85
const GENDER_BUTTON_BRIGHTNESS_HOVER := 1.08
const GENDER_BUTTON_BRIGHTNESS_PRESSED := 1.18
const GENDER_BUTTON_SELECTED_OFFSET := Vector2(0, 3)
const GENDER_BUTTON_TWEEN_DURATION := 0.12
const BACKGROUND_ZOOM_SPEED := 0.0034
const BACKGROUND_ZOOM_AMOUNT := 0.08
const BEARD_STYLE_ENABLED_MODULATE := Color(1, 1, 1, 1)
const BEARD_STYLE_DISABLED_MODULATE := Color(0.55, 0.55, 0.55, 1)
const ROLLING_DICE_SOUND_PATH := "res://resources/sounds/rolling-dice.mp3"

var _hovered_attribute_icon: Control
var _randomize_sound_player: AudioStreamPlayer

## In-world appearance: which dwarf from the dwarfhold spritesheet walks
## the world as this character.
const WORLD_SPRITE_SHEET := preload("res://resources/images/npc/dwarf_characters.png")
const WORLD_SPRITE_SLOT_COUNT := 8
const WORLD_SPRITE_FRAME := Vector2i(32, 32)
const WORLD_SPRITE_FRAME_SECONDS := 0.22
var _world_slot := 0
var _world_preview: TextureRect
var _world_preview_atlas: AtlasTexture
var _world_walk_frame := 0
var _world_frame_elapsed := 0.0
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
	_build_world_appearance_picker()
	_world_slot = _rng.randi_range(0, WORLD_SPRITE_SLOT_COUNT - 1)
	_update_world_preview()

func _process(delta: float) -> void:
	_position_attribute_tooltip()
	_update_animated_background(delta)
	_animate_world_preview(delta)

func _setup_animated_background() -> void:
	if animated_background == null:
		return
	animated_background.pivot_offset = animated_background.size * 0.5

## --- In-world appearance -------------------------------------------------
## The dwarves of the hold sheet, walking in place under the portrait;
## arrows cycle through the eight of them.

func _build_world_appearance_picker() -> void:
	if target_render == null:
		return
	var portrait_holder := target_render.get_parent() as Control
	if portrait_holder == null or portrait_holder.get_parent() == null:
		return
	var column := portrait_holder.get_parent()
	var picker := VBoxContainer.new()
	picker.name = "WorldAppearancePicker"
	picker.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := Label.new()
	title.text = "In-World Appearance"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	picker.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var previous_button := Button.new()
	previous_button.text = "◀"
	previous_button.focus_mode = Control.FOCUS_NONE
	previous_button.pressed.connect(_on_world_slot_step.bind(-1))
	row.add_child(previous_button)
	_world_preview_atlas = AtlasTexture.new()
	_world_preview_atlas.atlas = WORLD_SPRITE_SHEET
	_world_preview = TextureRect.new()
	_world_preview.texture = _world_preview_atlas
	_world_preview.custom_minimum_size = Vector2(96, 96)
	_world_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_world_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(_world_preview)
	var next_button := Button.new()
	next_button.text = "▶"
	next_button.focus_mode = Control.FOCUS_NONE
	next_button.pressed.connect(_on_world_slot_step.bind(1))
	row.add_child(next_button)
	picker.add_child(row)
	column.add_child(picker)
	column.move_child(picker, portrait_holder.get_index() + 1)

func _on_world_slot_step(step: int) -> void:
	_world_slot = posmod(_world_slot + step, WORLD_SPRITE_SLOT_COUNT)
	_update_world_preview()

func _update_world_preview() -> void:
	if _world_preview_atlas == null:
		return
	var slot_column := _world_slot % 4
	var slot_row := _world_slot / 4
	_world_preview_atlas.region = Rect2(
		(slot_column * 3 + _world_walk_frame) * WORLD_SPRITE_FRAME.x,
		slot_row * 4 * WORLD_SPRITE_FRAME.y,
		WORLD_SPRITE_FRAME.x,
		WORLD_SPRITE_FRAME.y
	)

func _animate_world_preview(delta: float) -> void:
	if _world_preview_atlas == null:
		return
	_world_frame_elapsed += delta
	if _world_frame_elapsed < WORLD_SPRITE_FRAME_SECONDS:
		return
	_world_frame_elapsed = 0.0
	_world_walk_frame = (_world_walk_frame + 1) % 3
	_update_world_preview()

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

	_clear_attribute_description()

func _on_attribute_icon_hovered(icon: Control) -> void:
	if icon == null:
		return
	_hovered_attribute_icon = icon
	var title := String(icon.get_meta("attribute_title", "")).strip_edges()
	var description := String(icon.get_meta("attribute_description", "")).strip_edges()
	if attribute_tooltip_panel:
		attribute_tooltip_panel.visible = true
	if attribute_tooltip_backdrop:
		attribute_tooltip_backdrop.visible = true
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

func _position_attribute_tooltip() -> void:
	if attribute_tooltip_panel == null or not attribute_tooltip_panel.visible:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var tooltip_size := attribute_tooltip_panel.get_combined_minimum_size()
	attribute_tooltip_panel.size = tooltip_size
	var viewport_size := viewport.get_visible_rect().size
	var target_pos := (viewport_size - tooltip_size) * 0.5
	target_pos.x = maxf(0.0, target_pos.x)
	target_pos.y = maxf(0.0, target_pos.y)
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
	_gender_button_base_positions[button] = button.position

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

	var base_position: Vector2 = _gender_button_base_positions.get(button, button.position)
	button.position = base_position + GENDER_BUTTON_SELECTED_OFFSET if is_selected else base_position

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
	_update_attribute_reminders()

func _on_profession_selected(_index: int) -> void:
	_update_attribute_reminders()

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
		"eye_color": eye_color.value if eye_color else 0.0,
		"hair_color": hair_color.value if hair_color else 0.0,
		"hair_style": int(hair_style.value) if hair_style else 0,
		"beard_color": beard_color.value if beard_color else 0.0,
		"beard_style": int(beard_style.value) if beard_style else 0,
		"character_slot": _world_slot
	}

func _on_randomize_button_pressed() -> void:
	_play_randomize_sound()
	_set_gender(_rng.randf() < 0.5)

	if profession_choice and profession_choice.item_count > 0:
		profession_choice.select(_rng.randi_range(0, profession_choice.item_count - 1))
	if clan_name and clan_name.item_count > 0:
		clan_name.select(_rng.randi_range(0, clan_name.item_count - 1))
	if skin_color:
		skin_color.value = _rng.randf_range(skin_color.min_value, skin_color.max_value)
	if eye_color:
		eye_color.value = _rng.randf_range(eye_color.min_value, eye_color.max_value)
	if beard_style:
		beard_style.value = _rng.randi_range(int(beard_style.min_value), int(beard_style.max_value))
	if hair_style:
		hair_style.value = _rng.randi_range(int(hair_style.min_value), int(hair_style.max_value))

	_world_slot = _rng.randi_range(0, WORLD_SPRITE_SLOT_COUNT - 1)
	_update_world_preview()

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
