# Dev harness: renders a scene to PNG for headless verification.
# Usage: SHOT_PATH=/tmp/out.png SHOT_SEED=myseed [SHOT_LAYOUT="Inland Sea"]
#   [SHOT_ZOOM=2.0 SHOT_FOCUS=settlement|marsh] \
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
	print("MAP_CELLS ", used.size())

	var focus_kind := OS.get_environment("SHOT_FOCUS")
	var zoom_text := OS.get_environment("SHOT_ZOOM")
	var focus_cell := Vector2i(-1, -1)
	if focus_kind == "settlement":
		# Use the same source the name labels use: tile data entries with a
		# settlement type.
		for wait_attempt in 80:
			var tile_data_variant: Variant = instance.get("_tile_data")
			if tile_data_variant is Dictionary:
				var tile_data := tile_data_variant as Dictionary
				var best_population := -1
				for coord_variant: Variant in tile_data.keys():
					var info := tile_data.get(coord_variant, {}) as Dictionary
					if String(info.get("settlement_type", "")).strip_edges().is_empty():
						continue
					var population := int(info.get("population", 0))
					if population > best_population:
						best_population = population
						focus_cell = coord_variant as Vector2i
			if focus_cell.x >= 0:
				break
			for i in 5:
				await get_tree().process_frame
		print("FOCUS_CELL ", focus_cell)
	elif focus_kind == "marsh":
		for cell in used:
			if map_layer.get_cell_atlas_coords(cell) == Vector2i(2, 4):
				focus_cell = cell
				break
	if focus_cell.x >= 0 or not zoom_text.is_empty():
		var camera := _find_camera(instance)
		if camera != null:
			# Stop the camera script from reasserting auto-fit while we frame
			# the shot.
			camera.set_process(false)
			camera.set_physics_process(false)
			camera.set_process_input(false)
			camera.set_process_unhandled_input(false)
			# Reapply the framing every frame: the map script re-fits the
			# camera to world bounds on late updates.
			for i in 30:
				if focus_cell.x >= 0:
					camera.position = map_layer.map_to_local(focus_cell)
				if not zoom_text.is_empty() and zoom_text.is_valid_float():
					var zoom_value := maxf(0.05, zoom_text.to_float())
					camera.zoom = Vector2(zoom_value, zoom_value)
				await get_tree().process_frame
	for i in 5:
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
