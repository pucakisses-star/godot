extends RefCounted
class_name SaveGameService

## The real save system: named slots under user://saves/, each a JSON
## file holding the whole world state (the same settings dictionary
## every scene already persists into) plus a metadata header the Load
## Game screen can list without parsing the world. Loading resumes the
## exact scene you saved in via the "last_scene" setting each scene
## stamps at ready.

const SAVE_DIR := "user://saves"
const AUTOSAVE_SLOT := "autosave"
const LEGACY_SAVE_PATH := "user://save_game.json"
const SAVE_FORMAT_VERSION := 2

const SCENE_LABELS := {
	"res://scenes/overworld.tscn": "The World Map",
	"res://scenes/town_generation.tscn": "town",
	"res://scenes/dwarf_hold_generation.tscn": "dwarfhold",
	"res://scenes/dungeon_interior.tscn": "dungeon"
}

static func slot_path(slot_id: String) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot_id]

static func _session(context: Node) -> Node:
	return context.get_node_or_null("/root/GameSession")

## Where the walker stood when this save was written, for the slot row.
static func location_label(settings: Dictionary) -> String:
	var last_scene := String(settings.get("last_scene", ""))
	match last_scene:
		"res://scenes/town_generation.tscn":
			var town_name := String(settings.get("town_scene_name", "")).strip_edges()
			return town_name if not town_name.is_empty() else "A town"
		"res://scenes/dwarf_hold_generation.tscn":
			var hold_name := String(settings.get("dwarfhold_scene_name", "")).strip_edges()
			return hold_name if not hold_name.is_empty() else "A dwarfhold"
		"res://scenes/dungeon_interior.tscn":
			var dungeon_name := String(settings.get("dungeon_scene_name", "")).strip_edges()
			return dungeon_name if not dungeon_name.is_empty() else "A dungeon"
	return "The World Map"

## The scene a loaded save should reopen into.
static func scene_to_resume(settings: Dictionary) -> String:
	var last_scene := String(settings.get("last_scene", ""))
	if SCENE_LABELS.has(last_scene):
		return last_scene
	return "res://scenes/overworld.tscn"

## Writes the session into a slot. Returns OK or a file error.
static func save_slot(context: Node, slot_id: String, label: String = "") -> Error:
	var session := _session(context)
	if session == null:
		return ERR_UNAVAILABLE
	# Scenes keep clock/HP/satiety local until they exit; ask the live
	# scene to flush so the save captures NOW, not scene-entry time.
	var current_scene := context.get_tree().current_scene if context.is_inside_tree() else null
	if current_scene != null and current_scene.has_method("flush_session_state"):
		current_scene.call("flush_session_state")
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var settings: Dictionary = session.call("get_world_settings")
	var character: Dictionary = session.call("get_player_character")
	var clock := settings.get("game_clock", {}) as Dictionary if settings.get("game_clock") is Dictionary else {}
	if label.strip_edges().is_empty():
		label = default_label(character, settings)
	var payload := {
		"version": SAVE_FORMAT_VERSION,
		"meta": {
			"label": label,
			"saved_at": Time.get_unix_time_from_system(),
			"saved_at_text": Time.get_datetime_string_from_system(false, true),
			"character_name": String(character.get("name", "A wanderer")),
			"character_profession": String(character.get("profession", "")),
			"world_name": String(settings.get("world_name", "")).strip_edges(),
			"day": maxi(1, int(clock.get("day", 1))),
			"hour": int(clock.get("hour", 8.0)),
			"location": location_label(settings)
		},
		"world_settings": session.call("encode_settings_for_save", settings),
		"player_character": session.call("encode_settings_for_save", character)
	}
	var file := FileAccess.open(slot_path(slot_id), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	# Autosaves must not steal the session's slot binding, or the next
	# manual "Save Game" forks a fresh slot instead of updating yours.
	if slot_id != AUTOSAVE_SLOT and session.has_method("set_current_slot"):
		session.call("set_current_slot", slot_id)
	return OK

static func default_label(character: Dictionary, settings: Dictionary) -> String:
	var who := String(character.get("name", "A wanderer")).strip_edges()
	var world := String(settings.get("world_name", "")).strip_edges()
	if who.is_empty():
		who = "A wanderer"
	return "%s of %s" % [who, world] if not world.is_empty() else who

## Loads a slot into the session. Returns the scene path to resume, or
## "" on failure.
static func load_slot(context: Node, slot_id: String) -> String:
	var session := _session(context)
	if session == null:
		return ""
	var path := slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return ""
	if not bool(session.call("load_from_file", path)):
		return ""
	if session.has_method("set_current_slot"):
		session.call("set_current_slot", slot_id)
	return scene_to_resume(session.call("get_world_settings"))

static func delete_slot(slot_id: String) -> void:
	var path := slot_path(slot_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

## Every slot's metadata header, newest first, without loading worlds.
static func list_saves() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return saves
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var slot_id := file_name.trim_suffix(".json")
			var meta := _read_meta(slot_path(slot_id))
			if not meta.is_empty():
				meta["slot_id"] = slot_id
				saves.append(meta)
		file_name = dir.get_next()
	dir.list_dir_end()
	saves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("saved_at", 0.0)) > float(b.get("saved_at", 0.0)))
	return saves

static func _read_meta(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return {}
	var meta: Variant = (parsed as Dictionary).get("meta", {})
	return (meta as Dictionary) if meta is Dictionary else {}

static func has_any_save() -> bool:
	return not list_saves().is_empty()

## The next unused manual slot name.
static func next_free_slot_id() -> String:
	for index in range(1, 100):
		if not FileAccess.file_exists(slot_path("slot_%d" % index)):
			return "slot_%d" % index
	return "slot_overflow"

## The pre-slot single save file becomes slot_1 once, so nothing is lost.
static func migrate_legacy_save() -> void:
	if not FileAccess.file_exists(LEGACY_SAVE_PATH):
		return
	# Slots already exist: the legacy file is stale, not precious - drop
	# it so deleting every slot later can't resurrect an old world.
	if has_any_save():
		DirAccess.remove_absolute(LEGACY_SAVE_PATH)
		return
	var file := FileAccess.open(LEGACY_SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return
	var payload := parsed as Dictionary
	payload["version"] = SAVE_FORMAT_VERSION
	# Describe the slot from the legacy payload itself — a hardcoded
	# "Imported Save · A wanderer · Day 1" header would mislabel the
	# player's real world on the Load Game screen.
	var legacy_settings := payload.get("world_settings", {}) as Dictionary \
		if payload.get("world_settings") is Dictionary else {}
	var legacy_character := payload.get("player_character", {}) as Dictionary \
		if payload.get("player_character") is Dictionary else {}
	var legacy_clock := legacy_settings.get("game_clock", {}) as Dictionary \
		if legacy_settings.get("game_clock") is Dictionary else {}
	payload["meta"] = {
		"label": default_label(legacy_character, legacy_settings),
		"saved_at": Time.get_unix_time_from_system(),
		"saved_at_text": Time.get_datetime_string_from_system(false, true),
		"character_name": String(legacy_character.get("name", "A wanderer")),
		"character_profession": String(legacy_character.get("profession", "")),
		"world_name": String(legacy_settings.get("world_name", "")).strip_edges(),
		"day": maxi(1, int(legacy_clock.get("day", 1))),
		"hour": int(legacy_clock.get("hour", 8.0)),
		"location": location_label(legacy_settings)
	}
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var out := FileAccess.open(slot_path("slot_1"), FileAccess.WRITE)
	if out == null:
		return
	out.store_string(JSON.stringify(payload, "\t"))
	out.close()
	DirAccess.remove_absolute(LEGACY_SAVE_PATH)

## Written whenever the walker crosses between scenes (unless the player
## switched auto save off in Options).
static func autosave(context: Node) -> void:
	if not GameSettingsService.autosave_enabled():
		return
	var session := _session(context)
	if session == null or not session.has_method("has_player_character"):
		return
	if not bool(session.call("has_player_character")):
		return
	save_slot(context, AUTOSAVE_SLOT, "Autosave")

## One line for a slot row on the Load Game screen.
static func describe(meta: Dictionary) -> String:
	var parts := PackedStringArray()
	parts.append(String(meta.get("character_name", "A wanderer")))
	var world := String(meta.get("world_name", ""))
	if not world.is_empty():
		parts.append(world)
	parts.append("Day %d" % int(meta.get("day", 1)))
	parts.append(String(meta.get("location", "The World Map")))
	return " · ".join(parts)
