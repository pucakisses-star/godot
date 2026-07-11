extends Node

const WorldSettings = preload("res://scripts/world_generation/world_settings.gd")

const SAVE_FILE_PATH := "user://save_game.json"
const SAVE_FORMAT_VERSION := 1

## Settings keys that belong to the CHARACTER, not the world: they die
## with the walker so a successor rolled into the same world starts
## fresh. Everything else (seed, diffs, explored masks, homestead,
## chronicle, clock...) is world history and survives the death.
const CHARACTER_SETTINGS_KEYS: Array[String] = [
	"player_hp",
	"player_satiety",
	"player_inventory",
	"player_coins",
	"player_gear",
	"player_equipment",
	"player_enchants",
	"player_buffs",
	"player_hotbar",
	"starmetal_blade",
	"starmetal_plate"
]

var world_settings: Dictionary = {}
var player_character: Dictionary = {}
## The slot this session was last saved to or loaded from ("" = none).
var current_slot_id: String = ""
## Set when a dead character's player chooses "New Character, Same World":
## the character creator then routes straight back into the inherited
## overworld instead of forging a new world.
var pending_same_world_rebirth := false

func set_current_slot(slot_id: String) -> void:
	current_slot_id = slot_id

func get_current_slot() -> String:
	return current_slot_id

## Public JSON-safe encoding for the save service.
func encode_settings_for_save(value: Variant) -> Variant:
	return _encode_for_json(value)

func set_world_settings(settings: Dictionary) -> void:
	world_settings = WorldSettings.merge_with_defaults(settings)

func get_world_settings() -> Dictionary:
	return WorldSettings.merge_with_defaults(world_settings)

func get_world_settings_with_defaults(settings: Dictionary) -> Dictionary:
	return WorldSettings.merge_with_defaults(settings)

func set_player_character(character: Dictionary) -> void:
	player_character = character.duplicate(true)

func get_player_character() -> Dictionary:
	return player_character.duplicate(true)

func has_player_character() -> bool:
	return not player_character.is_empty()

## The "Strike the earth!" embark story shows once per character: true only
## for a freshly created (or reborn) walker who has not yet seen it. The
## flag rides on the character sheet, so it saves/loads with them and a
## same-world successor — a genuinely new character — is greeted afresh.
func should_show_embark_intro() -> bool:
	return not player_character.is_empty() and not bool(player_character.get("embark_intro_shown", false))

func mark_embark_intro_shown() -> void:
	if not player_character.is_empty():
		player_character["embark_intro_shown"] = true

func set_pending_same_world_rebirth(pending: bool) -> void:
	pending_same_world_rebirth = pending

## Reads AND clears the rebirth flag, so it can never leak into a later
## ordinary new-game flow.
func consume_same_world_rebirth() -> bool:
	var pending := pending_same_world_rebirth
	pending_same_world_rebirth = false
	return pending

## "New Character, Same World": strips exactly the character-scoped keys
## out of the world settings while every world-scoped key stays put -
## including game_clock, so the successor's story starts on the death
## date. The session character clears and the next save claims a new slot.
func begin_new_character_in_world() -> void:
	for key: String in CHARACTER_SETTINGS_KEYS:
		world_settings.erase(key)
	world_settings["last_scene"] = "res://scenes/overworld.tscn"
	player_character = {}
	current_slot_id = ""
	pending_same_world_rebirth = true

## "Abandon World": back to the main menu with nothing carried over.
func abandon_world() -> void:
	world_settings = {}
	player_character = {}
	current_slot_id = ""
	pending_same_world_rebirth = false

func has_save_file(path: String = SAVE_FILE_PATH) -> bool:
	return FileAccess.file_exists(path)

func save_to_file(path: String = SAVE_FILE_PATH) -> Error:
	var payload := {
		"version": SAVE_FORMAT_VERSION,
		"world_settings": _encode_for_json(world_settings),
		"player_character": _encode_for_json(player_character)
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return OK

func load_from_file(path: String = SAVE_FILE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return false
	var payload := parsed as Dictionary
	var loaded_settings: Dictionary = _decode_from_json(payload.get("world_settings", {})) as Dictionary
	var loaded_character: Dictionary = _decode_from_json(payload.get("player_character", {})) as Dictionary
	world_settings = WorldSettings.merge_with_defaults(loaded_settings)
	player_character = loaded_character
	return true

static func _encode_for_json(value: Variant) -> Variant:
	if value is Dictionary:
		var encoded: Dictionary = {}
		for key: Variant in (value as Dictionary).keys():
			encoded[str(key)] = _encode_for_json((value as Dictionary)[key])
		return encoded
	if value is Array:
		var encoded_array: Array = []
		for item: Variant in value as Array:
			encoded_array.append(_encode_for_json(item))
		return encoded_array
	if value is Vector2i:
		var vec: Vector2i = value
		return {"__type": "Vector2i", "x": vec.x, "y": vec.y}
	if value is Vector2:
		var vec2: Vector2 = value
		return {"__type": "Vector2", "x": vec2.x, "y": vec2.y}
	return value

static func _decode_from_json(value: Variant) -> Variant:
	if value is Dictionary:
		var dict := value as Dictionary
		var type_tag := str(dict.get("__type", ""))
		if type_tag == "Vector2i":
			return Vector2i(int(dict.get("x", 0)), int(dict.get("y", 0)))
		if type_tag == "Vector2":
			return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))
		var decoded: Dictionary = {}
		for key: Variant in dict.keys():
			decoded[key] = _decode_from_json(dict[key])
		return decoded
	if value is Array:
		var decoded_array: Array = []
		for item: Variant in value as Array:
			decoded_array.append(_decode_from_json(item))
		return decoded_array
	return value
