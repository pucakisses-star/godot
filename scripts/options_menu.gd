extends Control

## Every control syncs to the LIVE state on entry (the .tscn's defaults
## are only a first-launch guess), applies immediately on change, and
## persists through GameSettingsService so a restart keeps the choice.

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080)
]

@onready var fullscreen_check: CheckBox = $Panel/MarginContainer/VBoxContainer/FullscreenCheckBox
@onready var vsync_check: CheckBox = $Panel/MarginContainer/VBoxContainer/VsyncCheckBox
@onready var resolution_option: OptionButton = $Panel/MarginContainer/VBoxContainer/ResolutionRow/ResolutionOptionButton
@onready var master_slider: HSlider = $Panel/MarginContainer/VBoxContainer/MasterVolumeRow/MasterVolumeSlider
@onready var music_slider: HSlider = $Panel/MarginContainer/VBoxContainer/MusicVolumeRow/MusicVolumeSlider
@onready var sfx_slider: HSlider = $Panel/MarginContainer/VBoxContainer/SfxVolumeRow/SfxVolumeSlider
@onready var auto_save_check: CheckBox = $Panel/MarginContainer/VBoxContainer/AutoSaveCheckBox

## Volume changes apply to the buses instantly but persist to disk on a
## short debounce — value_changed fires per tick of a drag, and a file
## write per tick can hitch on slow storage.
var _volume_save_debounce: Timer


func _ready() -> void:
	_volume_save_debounce = Timer.new()
	_volume_save_debounce.one_shot = true
	_volume_save_debounce.wait_time = 0.4
	_volume_save_debounce.timeout.connect(_persist_volumes)
	add_child(_volume_save_debounce)
	var mode := DisplayServer.window_get_mode()
	var is_fullscreen := (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	fullscreen_check.set_pressed_no_signal(is_fullscreen)
	vsync_check.set_pressed_no_signal(
		DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	)
	_sync_resolution_selection()
	master_slider.set_value_no_signal(GameSettingsService.bus_volume_percent("Master", 100.0))
	music_slider.set_value_no_signal(GameSettingsService.bus_volume_percent("Music", 80.0))
	sfx_slider.set_value_no_signal(GameSettingsService.bus_volume_percent("SFX", 80.0))
	auto_save_check.set_pressed_no_signal(GameSettingsService.autosave_enabled())
	fullscreen_check.grab_focus()


## Marks the entry matching the actual window size; when none does (the
## engine-default window, a manual resize), an honest "(current)" entry
## is shown instead of pretending a listed resolution is active.
func _sync_resolution_selection() -> void:
	var current := DisplayServer.window_get_size()
	for index in RESOLUTIONS.size():
		if RESOLUTIONS[index] == current:
			resolution_option.select(index)
			return
	resolution_option.add_item("%d x %d (current)" % [current.x, current.y])
	resolution_option.select(resolution_option.item_count - 1)


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/mainmenu.tscn")


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if toggled_on else DisplayServer.WINDOW_MODE_WINDOWED
	)
	GameSettingsService.save_setting("display", "fullscreen", toggled_on)


func _on_master_volume_value_changed(value: float) -> void:
	GameSettingsService.apply_bus_volume("Master", value)
	_volume_save_debounce.start()


func _on_music_volume_value_changed(value: float) -> void:
	GameSettingsService.apply_bus_volume("Music", value)
	_volume_save_debounce.start()


func _on_sfx_volume_value_changed(value: float) -> void:
	GameSettingsService.apply_bus_volume("SFX", value)
	_volume_save_debounce.start()


func _persist_volumes() -> void:
	GameSettingsService.save_setting("audio", "master_volume", master_slider.value)
	GameSettingsService.save_setting("audio", "music_volume", music_slider.value)
	GameSettingsService.save_setting("audio", "sfx_volume", sfx_slider.value)


func _exit_tree() -> void:
	# Leaving before the debounce fires must not drop the last change.
	if _volume_save_debounce != null and not _volume_save_debounce.is_stopped():
		_persist_volumes()


func _on_resolution_item_selected(index: int) -> void:
	if index < 0 or index >= RESOLUTIONS.size():
		return
	DisplayServer.window_set_size(RESOLUTIONS[index])
	GameSettingsService.save_setting("display", "window_size", RESOLUTIONS[index])


func _on_vsync_toggled(toggled_on: bool) -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if toggled_on else DisplayServer.VSYNC_DISABLED
	)
	GameSettingsService.save_setting("display", "vsync", toggled_on)


func _on_auto_save_toggled(toggled_on: bool) -> void:
	GameSettingsService.save_setting("gameplay", "autosave_enabled", toggled_on)
