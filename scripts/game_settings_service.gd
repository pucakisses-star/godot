class_name GameSettingsService
extends RefCounted

## Persists the options menu to user://settings.cfg and re-applies it on
## startup (GameSession._ready). Without this every visit to Options
## showed the scene's hardcoded defaults and nothing survived a restart.

const SETTINGS_PATH := "user://settings.cfg"

## One cached ConfigFile for the process: re-loading from disk on every
## read/write made each volume-slider tick a full file round-trip.
static var _config: ConfigFile = null

static func _ensure_config() -> ConfigFile:
	if _config == null:
		_config = ConfigFile.new()
		# A missing file is fine: we start a fresh one.
		_config.load(SETTINGS_PATH)
	return _config

static func save_setting(section: String, key: String, value: Variant) -> void:
	var config := _ensure_config()
	config.set_value(section, key, value)
	config.save(SETTINGS_PATH)

static func get_setting(section: String, key: String, default_value: Variant) -> Variant:
	return _ensure_config().get_value(section, key, default_value)

static func autosave_enabled() -> bool:
	return bool(get_setting("gameplay", "autosave_enabled", true))

## Reapplies every saved display/audio setting. Runs once at startup,
## before any scene plays audio or the player sees the window.
static func apply_saved() -> void:
	var fullscreen := bool(get_setting("display", "fullscreen", false))
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		var size_variant: Variant = get_setting("display", "window_size", null)
		if size_variant is Vector2i:
			DisplayServer.window_set_size(size_variant)
	var vsync := bool(get_setting("display", "vsync", true))
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
	apply_bus_volume("Master", float(get_setting("audio", "master_volume", 100.0)))
	apply_bus_volume("Music", float(get_setting("audio", "music_volume", 80.0)))
	apply_bus_volume("SFX", float(get_setting("audio", "sfx_volume", 80.0)))

## Volume is stored as the slider's 0-100 percent; 0 mutes the bus
## (linear_to_db(0) is -inf, which is exactly silence).
static func apply_bus_volume(bus_name: String, percent: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus == -1:
		return
	AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(percent, 0.0, 100.0) / 100.0))

static func bus_volume_percent(bus_name: String, fallback: float) -> float:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus == -1:
		return fallback
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(bus)) * 100.0, 0.0, 100.0)
