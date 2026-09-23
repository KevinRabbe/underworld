extends SceneTree

const AppRoot := preload("res://app/app_root.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var app := AppRoot.instantiate()
	root.add_child(app)
	await process_frame
	var failures: Array[String] = []
	var title: Node = app.get("current_scene")
	if title == null:
		failures.append("app did not start on title")
	else:
		title.emit_signal("new_game_requested")
		await process_frame
		if str(app.call("current_route_id")) != "profile_setup":
			failures.append("NEW GAME did not route to profile setup")
		var setup: Node = app.get("current_scene")
		if setup == null or not setup.has_signal("start_requested"):
			failures.append("profile setup route is missing start intent")
		else:
			setup.get_node("Center/Panel/Stack/CharacterName").text = "Contract Survivor"
			setup.get_node("Center/Panel/Stack/WorldName").text = "Contract World"
			setup.get_node("Center/Panel/Stack/WorldSeed").text = "12345"
			setup.get_node("Center/Panel/Stack/StartButton").emit_signal("pressed")
			await process_frame
			if str(app.call("current_route_id")) != "game":
				failures.append("profile setup did not start selected world")
			else:
				var game: Node = app.get("current_scene")
				var context = game.get("_session_world_context") if game != null else null
				if context == null or int(context.world_seed) != 12345:
					failures.append("entered world seed did not reach production world context")
	app.queue_free()
	await process_frame
	if failures.is_empty():
		print("[PROFILE ENTRY VALIDATION] PASS")
		quit(0)
		return
	printerr("[PROFILE ENTRY VALIDATION] FAIL")
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
