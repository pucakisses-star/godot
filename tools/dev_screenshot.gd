# Dev harness: renders a scene to PNG for headless verification.
# Usage: SHOT_PATH=/tmp/out.png SHOT_SEED=myseed \
#   xvfb-run godot --path . --rendering-driver opengl3 res://tools/dev_screenshot.tscn
extends Node

func _ready() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.set("world_settings", {
			"map_size_key": "mini",
			"world_seed": OS.get_environment("SHOT_SEED"),
			"world_layout": OS.get_environment("SHOT_LAYOUT") if not OS.get_environment("SHOT_LAYOUT").is_empty() else "Normal",
			"terrain": {"forest": 50, "mountain": 40, "river": 60}
		})
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var packed: PackedScene = load("res://scenes/overworld.tscn")
	var instance := packed.instantiate()
	viewport.add_child(instance)
	var map_layer := instance.get_node_or_null("MapLayer") as TileMapLayer
	var used: Array[Vector2i] = []
	for attempt in 60:
		for i in 5:
			await get_tree().process_frame
		if map_layer != null:
			used = map_layer.get_used_cells()
		if used.size() > 1000:
			break
	var tally: Dictionary = {}
	var first_marsh := Vector2i(-1, -1)
	for cell in used:
		var atlas_coords := map_layer.get_cell_atlas_coords(cell)
		tally[atlas_coords] = int(tally.get(atlas_coords, 0)) + 1
		if atlas_coords == Vector2i(2, 4) and first_marsh.x < 0:
			first_marsh = cell
	print("MAP_CELLS ", used.size())
	print("MARSH(2,4)=", int(tally.get(Vector2i(2, 4), 0)),
		" MONASTERY(2,2)=", int(tally.get(Vector2i(2, 2), 0)),
		" LONE_TREE(6,5)=", int(tally.get(Vector2i(6, 5), 0)),
		" OLD_LONE(0,2)=", int(tally.get(Vector2i(0, 2), 0)))
	if first_marsh.x >= 0:
		var camera := _find_camera(instance)
		if camera != null:
			camera.position = map_layer.map_to_local(first_marsh)
			camera.zoom = Vector2(1.6, 1.6)
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := viewport.get_texture().get_image()
	var out := OS.get_environment("SHOT_PATH")
	if out.is_empty():
		out = "/tmp/shot.png"
	img.save_png(out)
	print("SCREENSHOT_SAVED ", out)
	get_tree().quit()

func _find_camera(root: Node) -> Camera2D:
	if root is Camera2D:
		return root
	for child in root.get_children():
		var found := _find_camera(child)
		if found != null:
			return found
	return null
