extends RefCounted

const APP_ROOT_PATH := "res://app/app_root.tscn"
const TITLE_SCREEN_PATH := "res://presentation/ui/screens/title/title_screen.tscn"
const GAME_FIXTURE_PATH := "res://tests/fixtures/app_shell_game_fixture.gd"
const ProfileCatalog := preload("res://gameplay/persistence/profile_catalog.gd")


class ContextProbe extends RefCounted:
	var world_id: String

	func _init(value: String) -> void:
		world_id = value


class LifecycleSaveService extends RefCounted:
	var available := false
	var save_count := 0
	var seed := 4242
	var canonical_world_id := "wid1:lifecycle-world"
	var content_fingerprint := ""

	func probe_slot(_path: String) -> Dictionary:
		return {"success": true, "available": available, "classification": "AVAILABLE" if available else "NONE", "diagnostics": []}

	func save_slot(_request: Dictionary, _path: String, _condition: Dictionary = {}) -> Dictionary:
		save_count += 1
		available = true
		content_fingerprint = "lifecycle-fingerprint-%d" % save_count
		return {"success": true, "content_fingerprint": content_fingerprint, "diagnostics": []}

	func load_slot(_path: String) -> Dictionary:
		if not available:
			return {"success": true, "classification": "NONE", "diagnostics": []}
		return {
			"success": true,
			"classification": "AVAILABLE",
			"content_fingerprint": content_fingerprint,
			"candidate": {"world_seed": seed, "world_context": ContextProbe.new(canonical_world_id)},
			"diagnostics": [],
		}


static func run_runtime(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var catalog_path := ProfileCatalog.PATH
	_cleanup_catalog(catalog_path)
	var character_a := ProfileCatalog.create_character("Lifecycle A", catalog_path)
	var character_b := ProfileCatalog.create_character("Lifecycle B", catalog_path)
	var world_one := ProfileCatalog.create_world("Lifecycle One", 4242, catalog_path)
	var world_two := ProfileCatalog.create_world("Lifecycle Two", 4343, catalog_path)
	if not bool(character_a.get("success", false)) or not bool(character_b.get("success", false)) or not bool(world_one.get("success", false)) or not bool(world_two.get("success", false)):
		return ["profile lifecycle fixture could not create identities"]
	ProfileCatalog.select_pair(character_a["character"]["character_id"], world_one["world"]["world_id"], catalog_path)

	var app_scene: PackedScene = ResourceLoader.load(APP_ROOT_PATH)
	var title_scene: PackedScene = ResourceLoader.load(TITLE_SCREEN_PATH)
	var fixture_script = ResourceLoader.load(GAME_FIXTURE_PATH)
	if app_scene == null or title_scene == null or fixture_script == null:
		_cleanup_catalog(catalog_path)
		return ["profile lifecycle fixture could not load AppRoot resources"]
	var game_root := Node.new()
	game_root.name = "ProfileLifecycleGame"
	game_root.set_script(fixture_script)
	var game_scene := PackedScene.new()
	if game_scene.pack(game_root) != OK:
		game_root.free()
		_cleanup_catalog(catalog_path)
		return ["profile lifecycle fixture could not pack Game scene"]
	game_root.free()

	var save_service := LifecycleSaveService.new()
	var app: Node = app_scene.instantiate()
	app.call("configure_route_scenes", title_scene, game_scene)
	app.set("_save_slot_service", save_service)
	tree.root.add_child(app)
	await tree.process_frame
	var profile := {"character": character_a["character"], "world": world_one["world"]}
	if not bool(app.call("start_new_game", profile)):
		failures.append("A + World1 did not start")
	var first_save := app.call("save_current_game")
	if not bool(first_save.get("success", false)):
		failures.append("A + World1 SAVE failed")
	var first_pair := ProfileCatalog.saved_pair(catalog_path)
	if not bool(first_pair.get("success", false)) or str(first_pair.get("content_fingerprint", "")) != "lifecycle-fingerprint-1":
		failures.append("first SAVE did not durably bind exact pair and fingerprint")
	app.call("show_title")
	app.free()

	# A fresh AppRoot instance proves the catalog binding survives process reload.
	var restarted: Node = app_scene.instantiate()
	restarted.call("configure_route_scenes", title_scene, game_scene)
	restarted.set("_save_slot_service", save_service)
	tree.root.add_child(restarted)
	await tree.process_frame
	if not bool(restarted.call("continue_game")):
		failures.append("fresh-process CONTINUE did not restore A + World1")
	else:
		var active: Dictionary = restarted.get("_active_profile")
		if str(active.get("character", {}).get("character_id", "")) != str(character_a["character"]["character_id"]):
			failures.append("CONTINUE active profile was not exact saved Character A")
	var selected_b := ProfileCatalog.select_pair(character_b["character"]["character_id"], world_one["world"]["world_id"], catalog_path)
	if not bool(selected_b.get("success", false)) or not bool(restarted.call("show_title")) or not bool(restarted.call("continue_game")):
		failures.append("B + World1 selection incorrectly blocked saved-pair Continue")
	else:
		var active_b_case: Dictionary = restarted.get("_active_profile")
		if str(active_b_case.get("character", {}).get("character_id", "")) != str(character_a["character"]["character_id"]):
			failures.append("B + World1 Continue was misattributed to selected Character B")
	ProfileCatalog.select_pair(character_a["character"]["character_id"], world_two["world"]["world_id"], catalog_path)
	if not bool(restarted.call("show_title")) or not bool(restarted.call("continue_game")):
		failures.append("A + World2 selection incorrectly blocked saved-pair Continue")
	else:
		var active_world_case: Dictionary = restarted.get("_active_profile")
		if str(active_world_case.get("world", {}).get("world_id", "")) != str(world_one["world"]["world_id"]):
			failures.append("A + World2 Continue was misattributed to selected World2")

	# The second SAVE refreshes the exact binding for the active saved pair.
	var second_save := restarted.call("save_current_game")
	var second_pair := ProfileCatalog.saved_pair(catalog_path)
	if not bool(second_save.get("success", false)) or str(second_pair.get("content_fingerprint", "")) != "lifecycle-fingerprint-2":
		failures.append("Continue -> SAVE again did not refresh the exact binding")
	restarted.call("show_title")

	# Make the profile binding promotion fail after the gameplay slot commits.
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(catalog_path + ".candidate"))
	var failed_binding_save := restarted.call("continue_game")
	if not failed_binding_save:
		failures.append("precondition CONTINUE before binding-failure injection failed")
	var binding_failure := restarted.call("save_current_game")
	if bool(binding_failure.get("success", false)):
		failures.append("binding write failure was not surfaced after slot commit")
	restarted.call("show_title")
	if bool(restarted.call("continue_game")):
		failures.append("stale saved binding authorized a newer slot after binding failure")

	restarted.free()
	_cleanup_catalog(catalog_path)
	return failures


static func _cleanup_catalog(path: String) -> void:
	for transient in [path, path + ".candidate", path + ".backup"]:
		var absolute := ProjectSettings.globalize_path(transient)
		if FileAccess.file_exists(transient):
			DirAccess.remove_absolute(absolute)
		elif DirAccess.dir_exists_absolute(absolute):
			DirAccess.remove_absolute(absolute)
