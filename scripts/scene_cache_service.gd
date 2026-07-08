class_name SceneCacheService
extends Node

## Keeps the world alive between scene switches. The overworld and the
## last settlement you visited are parked as live instances instead of
## being freed, so walking out of a town re-attaches the same overworld
## (no 12-second regeneration) and stepping back into the town finds it
## exactly as you left it. Core Keeper feel on a scene-based structure.
##
## Parked scenes are keyed by scene path plus the seed that shaped them,
## so entering a *different* town still generates fresh. Scenes may
## implement `_on_scene_resumed()` to resync session-driven state (the
## world clock, HP, satiety) that advanced while they were parked.

const CACHE_LIMIT := 2

## Scene paths worth parking, mapped to the world-settings key whose
## value distinguishes one instance from another.
const CACHEABLE_SEED_KEYS := {
	"res://scenes/overworld.tscn": "world_seed",
	"res://scenes/town_generation.tscn": "town_scene_seed",
	"res://scenes/dwarf_hold_generation.tscn": "dwarfhold_scene_seed"
}

var _parked: Dictionary = {}
var _order: Array[String] = []

## A short fade-to-black wraps every scene change, so entering a settlement
## (or stepping back out) reads as a seamless doorway rather than a hard cut
## and a loading-screen flash: the outgoing view fades out, the incoming
## scene is built behind the black, and the ready scene fades back in.
## Settlement generation runs synchronously inside the swap, so it finishes
## while the screen is fully black and the reveal lands on a ready scene.
const FADE_OUT_SECONDS := 0.22
const FADE_IN_SECONDS := 0.32
var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null

func change_scene(target_path: String) -> void:
	_ensure_fade()
	await _tween_fade_alpha(1.0, FADE_OUT_SECONDS)
	_perform_swap(target_path)
	# Let the freshly built scene lay out and paint before the reveal, so the
	# fade-in never flashes an unrendered frame.
	await get_tree().process_frame
	await get_tree().process_frame
	await _tween_fade_alpha(0.0, FADE_IN_SECONDS)
	if _fade_layer != null and is_instance_valid(_fade_layer):
		_fade_layer.visible = false

func _ensure_fade() -> void:
	if _fade_layer != null and is_instance_valid(_fade_layer):
		_fade_layer.visible = true
		return
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 128
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_rect)

func _tween_fade_alpha(target_alpha: float, duration: float) -> void:
	if _fade_rect == null or not is_instance_valid(_fade_rect):
		return
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", target_alpha, duration)
	await tween.finished

func _perform_swap(target_path: String) -> void:
	var tree := get_tree()
	var current := tree.current_scene
	var target_key := _cache_key(target_path)

	# Park the outgoing scene when it's cacheable; freeing is the default.
	# The key was stamped when the instance was attached - recomputing it
	# now would mis-file the instance if the seed settings changed since.
	if current != null:
		var current_key := String(current.get_meta("scene_cache_key", _cache_key(current.scene_file_path)))
		tree.root.remove_child(current)
		if not current_key.is_empty() and current_key != target_key:
			_parked[current_key] = current
			_order.erase(current_key)
			_order.append(current_key)
		else:
			current.queue_free()

	var incoming: Node = null
	if not target_key.is_empty() and _parked.has(target_key):
		incoming = _parked[target_key]
		_parked.erase(target_key)
		_order.erase(target_key)
	else:
		incoming = (load(target_path) as PackedScene).instantiate()
	if not target_key.is_empty():
		incoming.set_meta("scene_cache_key", target_key)
	tree.root.add_child(incoming)
	tree.current_scene = incoming
	# Cached scenes skip _ready, so stamp last_scene here for both fresh
	# and revived instances - saves must resume into THIS scene.
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("get_world_settings"):
		var settings: Dictionary = session.call("get_world_settings")
		settings["last_scene"] = target_path
		session.call("set_world_settings", settings)
	if incoming.has_method("_on_scene_resumed"):
		incoming.call("_on_scene_resumed")

	while _order.size() > CACHE_LIMIT:
		var evicted_key: String = _order.pop_front()
		var evicted := _parked.get(evicted_key) as Node
		_parked.erase(evicted_key)
		if evicted != null:
			evicted.queue_free()

## Dropping to the main menu or starting a new world invalidates every
## parked instance.
func clear() -> void:
	for parked_variant: Variant in _parked.values():
		var parked := parked_variant as Node
		if parked != null:
			parked.queue_free()
	_parked.clear()
	_order.clear()

func _cache_key(scene_path: String) -> String:
	if scene_path.is_empty() or not CACHEABLE_SEED_KEYS.has(scene_path):
		return ""
	var seed_value := ""
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("get_world_settings"):
		var settings: Dictionary = session.call("get_world_settings")
		seed_value = str(settings.get(String(CACHEABLE_SEED_KEYS[scene_path]), ""))
	return "%s::%s" % [scene_path, seed_value]

## Convenience for call sites that may run before the autoload exists
## (tests instancing scenes directly): falls back to a plain change.
static func request_change(from_node: Node, target_path: String) -> void:
	# Crossing between scenes is the natural autosave moment.
	SaveGameService.autosave(from_node)
	var service := from_node.get_node_or_null("/root/SceneCache")
	if service != null and service.has_method("change_scene"):
		service.call("change_scene", target_path)
	else:
		from_node.get_tree().change_scene_to_file(target_path)

static func request_clear(from_node: Node) -> void:
	var service := from_node.get_node_or_null("/root/SceneCache")
	if service != null and service.has_method("clear"):
		service.call("clear")
