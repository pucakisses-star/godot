extends Control

## Title screen: the two web-game GIFs (the smith at his anvil, the armored
## dwarf by the forge) play side by side, each covering half the screen,
## behind the framed Dwarf Hold panel. The GIF frames are pre-baked into
## sprite sheets of 640x480 cells, 5 per row, and advanced here by hand.

const SMITH_FRAME_COUNT := 71
const SMITH_FRAME_TIME := 0.05
const TITLE_FRAME_COUNT := 64
const TITLE_FRAME_TIME := 0.1
const GIF_FRAME_SIZE := Vector2(640, 480)
const SHEET_COLUMNS := 5

@onready var load_game_button: Button = %LoadGameButton
@onready var left_pane: Control = %LeftPane
@onready var right_pane: Control = %RightPane
@onready var smith_sprite: Sprite2D = %SmithSprite
@onready var title_sprite: Sprite2D = %TitleSprite

var _smith_time := 0.0
var _title_time := 0.0

func _ready() -> void:
	_refresh_load_button()
	get_viewport().size_changed.connect(_layout_background_panes)
	_layout_background_panes()

func _process(delta: float) -> void:
	_smith_time += delta
	_title_time += delta
	_apply_gif_frame(smith_sprite, int(_smith_time / SMITH_FRAME_TIME) % SMITH_FRAME_COUNT)
	_apply_gif_frame(title_sprite, int(_title_time / TITLE_FRAME_TIME) % TITLE_FRAME_COUNT)

func _apply_gif_frame(sprite: Sprite2D, frame: int) -> void:
	if sprite == null:
		return
	var column := frame % SHEET_COLUMNS
	var row := frame / SHEET_COLUMNS
	sprite.region_rect = Rect2(Vector2(column, row) * GIF_FRAME_SIZE, GIF_FRAME_SIZE)

## Scale each animation to cover its half of the screen, centered and
## clipped by its pane.
func _layout_background_panes() -> void:
	for pane_pair: Array in [[left_pane, smith_sprite], [right_pane, title_sprite]]:
		var pane := pane_pair[0] as Control
		var sprite := pane_pair[1] as Sprite2D
		if pane == null or sprite == null:
			continue
		var pane_size := pane.size
		if pane_size.x <= 0.0 or pane_size.y <= 0.0:
			continue
		var cover_scale := maxf(pane_size.x / GIF_FRAME_SIZE.x, pane_size.y / GIF_FRAME_SIZE.y)
		sprite.scale = Vector2.ONE * cover_scale
		sprite.position = pane_size * 0.5

func _refresh_load_button() -> void:
	if load_game_button == null:
		return
	var game_session := get_node_or_null("/root/GameSession")
	var has_save := game_session != null and game_session.has_method("has_save_file") and bool(game_session.call("has_save_file"))
	load_game_button.disabled = not has_save

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/character_creator.tscn")


func _on_options_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/options_menu.tscn")


func _on_load_game_button_pressed() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("load_from_file"):
		return
	if not bool(game_session.call("load_from_file")):
		return
	get_tree().change_scene_to_file("res://scenes/overworld.tscn")


func _on_return_button_pressed() -> void:
	get_tree().quit()
