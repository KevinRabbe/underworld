extends RefCounted

const APP_ROOT_PATH := "res://app/app_root.tscn"
const TITLE_SCREEN_PATH := "res://presentation/ui/screens/title/title_screen.tscn"
const GAME_FIXTURE_PATH := "res://tests/fixtures/pair_slot_game_fixture.gd"
const ProfileCatalog := preload("res://gameplay/persistence/profile_catalog.gd")
const GameSaveSlotService := preload("res://gameplay/persistence/game_save_slot_service.gd")

static func run_runtime(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var catalog_path := ProfileCatalog.PATH
	_cleanup_catalog(catalog_path)
	var character_a: Dictionary = ProfileCatalog.create_character("Pair A", catalog_path, "male")
	var character_b: Dictionary = ProfileCatalog.create_character("Pair B", catalog_path, "female")
	var world_one: Dictionary = ProfileCatalog.create_world("Pair One", 4242, catalog_path)
	var world_two: Dictionary = ProfileCatalog.create_world("Pair Two", 4343, catalog_path)
	if not bool(character_a.get("success", false)) or not bool(character_b.get("success", false)) or not bool(world_one.get("success", false)) or not bool(world_two.get("success", false)):
		return ["pair AppRoot fixture could not create identities"]
	var app_scene: PackedScene = ResourceLoader.load(APP_ROOT_PATH)
	var title_scene: PackedScene = ResourceLoader.load(TITLE_SCREEN_PATH)
	var fixture_script = ResourceLoader.load(GAME_FIXTURE_PATH)
	if app_scene == null or title_scene == null or fixture_script == null:
		return ["pair AppRoot fixture could not load production routes"]
	var game_root := Node.new()
	game_root.set_script(fixture_script)
	var game_scene := PackedScene.new()
	if game_scene.pack(game_root) != OK:
		return ["pair AppRoot fixture could not pack Game route"]
	game_root.free()
	var app: Node = app_scene.instantiate()
	app.call("configure_route_scenes", title_scene, game_scene)
	tree.root.add_child(app)
	await tree.process_frame
	var profile_a1 := {"character": character_a["character"], "world": world_one["world"]}
	var profile_b2 := {"character": character_b["character"], "world": world_two["world"]}
	var profile_a2 := {"character": character_a["character"], "world": world_two["world"]}
	var profile_b1 := {"character": character_b["character"], "world": world_one["world"]}
	if not bool(app.call("start_new_game", profile_a1)):
		failures.append("A/W1 NEW route failed")
	var save_a1: Dictionary = app.call("save_current_game")
	if not bool(save_a1.get("success", false)):
		failures.append("A/W1 SAVE failed: " + str(save_a1.get("diagnostics", [])))
	if not bool(app.call("show_title")) or not bool(app.call("start_new_game", profile_b2)):
		failures.append("B/W2 NEW route failed")
	var save_b2: Dictionary = app.call("save_current_game")
	if not bool(save_b2.get("success", false)):
		failures.append("B/W2 SAVE failed: " + str(save_b2.get("diagnostics", [])))
	else:
		# A forced gameplay SAVE failure must not move the last-successfully-saved
		# pair or corrupt the already durable B/W2 slot.
		app.get("current_scene").set("fail_saves", 1)
		var failed_b2: Dictionary = app.call("save_current_game")
		if bool(failed_b2.get("success", false)):
			failures.append("forced B/W2 SAVE unexpectedly succeeded")
		elif not bool(app.call("show_title")) or not bool(app.call("continue_game")):
			failures.append("SAVE failure made last saved B/W2 pair unreachable")
		else:
			var retained_b2: Dictionary = app.get("_active_profile")
			if str(retained_b2.get("character", {}).get("character_id", "")) != str(character_b["character"]["character_id"]):
				failures.append("SAVE failure changed last saved pair")
	if not bool(app.call("show_title")) or not bool(app.call("start_new_game", profile_a1)):
		failures.append("existing A/W1 did not route to Continue")
	else:
		var restored_a1: Node = app.get("current_scene")
		if str(restored_a1.get("prepared_mode")) != "continue" or float(restored_a1.get("prepared_candidate").get("resume_position", Vector3.ZERO).x) != 11.0:
			failures.append("existing A/W1 did not restore its isolated state")
		if str(restored_a1.get("prepared_profile", {}).get("character", {}).get("appearance", {}).get("body_type", "")) != "male":
			failures.append("existing A/W1 Continue dropped Character-owned male appearance")
	if not bool(app.call("show_title")) or not bool(app.call("start_new_game", profile_b2)):
		failures.append("existing B/W2 did not route to Continue")
	else:
		var restored_b2: Node = app.get("current_scene")
		if str(restored_b2.get("prepared_mode")) != "continue" or float(restored_b2.get("prepared_candidate").get("resume_position", Vector3.ZERO).x) != 22.0:
			failures.append("existing B/W2 did not restore its isolated state")
		if str(restored_b2.get("prepared_profile", {}).get("character", {}).get("appearance", {}).get("body_type", "")) != "female":
			failures.append("existing B/W2 Continue dropped Character-owned female appearance")
	if not bool(app.call("show_title")) or not bool(app.call("start_new_game", profile_a2)):
		failures.append("A/W2 did not start independently")
	else:
		if str(app.get("current_scene").get("prepared_mode")) != "new":
			failures.append("A/W2 unexpectedly reused another pair")
	if not bool(app.call("show_title")) or not bool(app.call("start_new_game", profile_b1)):
		failures.append("B/W1 did not start independently")
	else:
		if str(app.get("current_scene").get("prepared_mode")) != "new":
			failures.append("B/W1 unexpectedly reused another pair")
	if not bool(app.call("show_title")) or not bool(app.call("continue_game")):
		failures.append("Continue after B/W2 did not restore last saved pair")
	else:
		var active_b2: Dictionary = app.get("_active_profile")
		if str(active_b2.get("character", {}).get("character_id", "")) != str(character_b["character"]["character_id"]):
			failures.append("Continue did not restore last saved B/W2 pair")
		if str(app.get("current_scene").get("prepared_profile", {}).get("character", {}).get("appearance", {}).get("body_type", "")) != "female":
			failures.append("last saved B/W2 Continue dropped Character-owned female appearance")
	if not bool(app.call("show_title")) or not bool(app.call("start_new_game", profile_a1)):
		failures.append("A/W1 switch-back route failed")
	else:
		var save_a1_again: Dictionary = app.call("save_current_game")
		if not bool(save_a1_again.get("success", false)):
			failures.append("A/W1 switch-back SAVE failed: " + str(save_a1_again.get("diagnostics", [])))
		elif not bool(app.call("show_title")):
			failures.append("A/W1 switch-back could not return to title")
		elif not bool(app.call("continue_game")):
			failures.append("A/W1 switch-back Continue failed")
		else:
			var active_a1: Dictionary = app.get("_active_profile")
			if str(active_a1.get("character", {}).get("character_id", "")) != str(character_a["character"]["character_id"]):
				failures.append("Continue did not retarget to last saved A/W1 pair")
			if str(app.get("current_scene").get("prepared_profile", {}).get("character", {}).get("appearance", {}).get("body_type", "")) != "male":
				failures.append("last saved A/W1 Continue dropped Character-owned male appearance")
	app.free()
	await tree.process_frame
	# Restart the real AppRoot against the same catalog and pair slots. CONTINUE
	# must still resolve the durable A/W1 binding after process lifecycle reset.
	var restarted_app: Node = app_scene.instantiate()
	restarted_app.call("configure_route_scenes", title_scene, game_scene)
	tree.root.add_child(restarted_app)
	await tree.process_frame
	if not bool(restarted_app.call("continue_game")):
		failures.append("restart CONTINUE failed")
	else:
		var restarted_profile: Dictionary = restarted_app.get("_active_profile")
		if str(restarted_profile.get("character", {}).get("character_id", "")) != str(character_a["character"]["character_id"]):
			failures.append("restart did not restore last saved A/W1 pair")
	restarted_app.free()
	# A stale global legacy save must be rejected before it can poison the
	# absent deterministic A/W1 Pair Slot. Title must also remain disabled rather
	# than falling back to an unrelated global candidate.
	var pair_service = GameSaveSlotService.new()
	var a1_slot := GameSaveSlotService.pair_slot_path(str(character_a["character"]["character_id"]), str(world_one["world"]["world_id"]))
	var b2_slot := GameSaveSlotService.pair_slot_path(str(character_b["character"]["character_id"]), str(world_two["world"]["world_id"]))
	var legacy_json := _read(a1_slot)
	var stale_legacy_json := _read(b2_slot)
	_cleanup_paths([a1_slot, GameSaveSlotService.DEFAULT_SLOT_PATH])
	var staged_stale_legacy := pair_service.persist_candidate_json(stale_legacy_json, GameSaveSlotService.DEFAULT_SLOT_PATH)
	if not bool(staged_stale_legacy.get("success", false)):
		failures.append("stale legacy global fixture could not be staged")
	else:
		var stale_app: Node = app_scene.instantiate()
		stale_app.call("configure_route_scenes", title_scene, game_scene)
		tree.root.add_child(stale_app)
		await tree.process_frame
		var stale_title: Node = stale_app.get("current_scene")
		var stale_continue_button: Button = stale_title.get("continue_button")
		if stale_continue_button == null or not stale_continue_button.disabled:
			failures.append("stale legacy fallback incorrectly enabled Title CONTINUE")
		if bool(stale_app.call("continue_game")):
			failures.append("stale legacy fallback incorrectly restored a mismatched pair")
		if str(pair_service.probe_slot(a1_slot).get("classification", "")) != GameSaveSlotService.CLASS_NONE:
			failures.append("stale legacy candidate poisoned the absent Pair Slot")
		if not FileAccess.file_exists(GameSaveSlotService.DEFAULT_SLOT_PATH):
			failures.append("stale legacy source was deleted while being rejected")
		stale_app.free()
	# Exercise the accepted global-slot compatibility path through real AppRoot:
	# remove only the deterministic A/W1 slot, stage the exact bytes in the
	# legacy slot, and require Continue to recreate/use the Pair Slot without
	# deleting the legacy source.
	_cleanup_paths([a1_slot, GameSaveSlotService.DEFAULT_SLOT_PATH])
	var staged_legacy := pair_service.persist_candidate_json(legacy_json, GameSaveSlotService.DEFAULT_SLOT_PATH)
	if not bool(staged_legacy.get("success", false)):
		failures.append("legacy global fixture could not be staged")
	else:
		var migrated_app: Node = app_scene.instantiate()
		migrated_app.call("configure_route_scenes", title_scene, game_scene)
		tree.root.add_child(migrated_app)
		await tree.process_frame
		if not bool(migrated_app.call("continue_game")):
			failures.append("legacy global migration Continue failed")
		else:
			var migrated_profile: Dictionary = migrated_app.get("_active_profile")
			if str(migrated_profile.get("character", {}).get("character_id", "")) != str(character_a["character"]["character_id"]):
				failures.append("legacy migration restored the wrong Character pair")
			if str(pair_service.probe_slot(a1_slot).get("classification", "")) != GameSaveSlotService.CLASS_AVAILABLE:
				failures.append("legacy migration did not recreate Pair Slot")
		if not FileAccess.file_exists(GameSaveSlotService.DEFAULT_SLOT_PATH):
			failures.append("legacy migration deleted the source slot")
		migrated_app.free()
	_cleanup_paths([a1_slot, GameSaveSlotService.DEFAULT_SLOT_PATH])
	_cleanup_slots(character_a, character_b, world_one, world_two)
	_cleanup_catalog(catalog_path)
	return failures

static func _cleanup_slots(character_a: Dictionary, character_b: Dictionary, world_one: Dictionary, world_two: Dictionary) -> void:
	for character in [character_a.get("character", {}), character_b.get("character", {})]:
		for world in [world_one.get("world", {}), world_two.get("world", {})]:
			var path := GameSaveSlotService.pair_slot_path(str(character.get("character_id", "")), str(world.get("world_id", "")))
			for transient in [path, path + GameSaveSlotService.CANDIDATE_SUFFIX, path + GameSaveSlotService.BACKUP_SUFFIX]:
				if FileAccess.file_exists(transient):
					DirAccess.remove_absolute(ProjectSettings.globalize_path(transient))

static func _cleanup_catalog(path: String) -> void:
	for transient in [path, path + ".candidate", path + ".backup"]:
		if FileAccess.file_exists(transient):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(transient))

static func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""

static func _cleanup_paths(paths: Array) -> void:
	for path in paths:
		for transient in [path, path + GameSaveSlotService.CANDIDATE_SUFFIX, path + GameSaveSlotService.BACKUP_SUFFIX]:
			if FileAccess.file_exists(transient):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(transient))
