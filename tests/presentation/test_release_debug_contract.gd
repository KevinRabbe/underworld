extends RefCounted

const APP_ROOT_PATH := "res://app/app_root.tscn"
const GAME_SCENE_PATH := "res://app/game/game.tscn"
const GameSaveSlotService := preload("res://gameplay/persistence/game_save_slot_service.gd")

const TEST_SLOT := "user://release_debug_001_app_shell.json"
const DEBUG_LAYER := 25


static func run_runtime(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_cleanup_slot()
	if tree == null or tree.root == null:
		return ["release-debug contract requires SceneTree root"]

	var app_packed = ResourceLoader.load(APP_ROOT_PATH)
	var game_packed = ResourceLoader.load(GAME_SCENE_PATH)
	if app_packed == null or not app_packed is PackedScene:
		return ["release-debug contract could not load production AppRoot"]
	if game_packed == null or not game_packed is PackedScene:
		return ["release-debug contract could not load production Game"]

	# Ordinary production NEW must be release-safe without an export/property toggle.
	var app: Node = app_packed.instantiate()
	if app == null:
		return ["release-debug contract could not instantiate production AppRoot"]
	if not bool(app.call("configure_save_slot_path", TEST_SLOT)):
		app.free()
		return ["release-debug contract could not configure isolated SAVE slot"]
	tree.root.add_child(app)
	await tree.process_frame
	if not bool(app.call("start_new_game")):
		failures.append("production AppRoot NEW could not enter real Game route")
		await _free_attached(tree, app)
		_cleanup_slot()
		return failures
	var new_game: Node = app.get("current_scene") as Node
	_assert_release_game(new_game, "NEW", failures)

	# Build the Continue proof through the accepted production SAVE route rather
	# than constructing a private persistence candidate or mutating slot bytes.
	var saved_variant: Variant = app.call("save_current_game")
	if not saved_variant is Dictionary or not bool(saved_variant.get("success", false)):
		failures.append("release-debug NEW could not produce production SAVE for Continue proof: %s" % [
			saved_variant.get("diagnostics", []) if saved_variant is Dictionary else [],
		])
		await _free_attached(tree, app)
		_cleanup_slot()
		return failures
	await _free_attached(tree, app)

	var continued_app: Node = app_packed.instantiate()
	if continued_app == null:
		_cleanup_slot()
		return failures + ["release-debug contract could not instantiate fresh Continue AppRoot"]
	if not bool(continued_app.call("configure_save_slot_path", TEST_SLOT)):
		continued_app.free()
		_cleanup_slot()
		return failures + ["release-debug contract could not configure Continue SAVE slot"]
	tree.root.add_child(continued_app)
	await tree.process_frame
	if not bool(continued_app.call("continue_game")):
		failures.append("fresh production AppRoot could not Continue release-debug SAVE")
	else:
		var continued_game: Node = continued_app.get("current_scene") as Node
		_assert_release_game(continued_game, "CONTINUE", failures)
	await _free_attached(tree, continued_app)

	# Explicit developer opt-in remains available, but it is one Game-owned root at
	# the reserved debug layer and F3 affects the entire debug presentation family.
	var developer_game: Node = game_packed.instantiate()
	if developer_game == null:
		_cleanup_slot()
		return failures + ["release-debug contract could not instantiate developer Game"]
	developer_game.set("enable_debug_hud", true)
	if not bool(developer_game.call("prepare_new_game")):
		developer_game.free()
		_cleanup_slot()
		return failures + ["developer Game rejected ordinary NEW preparation"]
	tree.root.add_child(developer_game)
	await tree.process_frame

	var debug_hud = developer_game.get("debug_hud")
	var gameplay_hud = developer_game.get("gameplay_hud")
	if debug_hud == null or not is_instance_valid(debug_hud):
		failures.append("explicit developer opt-in did not mount DebugHUD")
	else:
		if debug_hud.get_parent() != developer_game:
			failures.append("DebugHUD is not owned by Game lifetime")
		if int(debug_hud.get("layer")) != DEBUG_LAYER:
			failures.append("explicit DebugHUD must use developer layer %d" % DEBUG_LAYER)
		if _direct_child_count_named(developer_game, "DebugHUD") != 1:
			failures.append("explicit developer opt-in must mount exactly one DebugHUD root")
		var debug_label := debug_hud.get_node_or_null("DebugLabel") as Control
		var crosshair := debug_hud.get_node_or_null("ActionCrosshair") as Control
		var survival_label := debug_hud.get_node_or_null("SurvivalHUD") as Control
		if debug_label == null or crosshair == null or survival_label == null:
			failures.append("DebugHUD is missing one of its developer presentation children")
		else:
			var survival = developer_game.get("survival")
			var store = developer_game.get("world_delta_store")
			var inventory_before: String = survival.get_inventory_state().canonical_json()
			var equipment_before: Dictionary = survival.get_equipment_state().canonical_snapshot()
			var delta_before: Dictionary = store.snapshot()
			var player_before: Vector3 = developer_game.get("player").global_position

			if not (debug_label.visible and crosshair.visible and survival_label.visible):
				failures.append("explicit developer DebugHUD does not start as one visible family")
			_send_f3(debug_hud)
			if debug_label.visible or crosshair.visible or survival_label.visible:
				failures.append("F3 hide left part of the DebugHUD presentation visible")
			if gameplay_hud == null or not is_instance_valid(gameplay_hud) or not bool(gameplay_hud.get("visible")):
				failures.append("F3 debug hide incorrectly suppressed normal GameplayHUD")
			_send_f3(debug_hud)
			if not (debug_label.visible and crosshair.visible and survival_label.visible):
				failures.append("F3 show did not restore the complete DebugHUD presentation family")

			if survival.get_inventory_state().canonical_json() != inventory_before:
				failures.append("developer DebugHUD toggle mutated inventory truth")
			if survival.get_equipment_state().canonical_snapshot() != equipment_before:
				failures.append("developer DebugHUD toggle mutated equipment truth")
			if store.snapshot() != delta_before:
				failures.append("developer DebugHUD toggle mutated WorldDelta truth")
			if developer_game.get("player").global_position != player_before:
				failures.append("developer DebugHUD toggle mutated Player position")

	var debug_ref: WeakRef = weakref(debug_hud) if debug_hud != null else null
	await _free_attached(tree, developer_game)
	if debug_ref != null and debug_ref.get_ref() != null:
		failures.append("Game teardown retained developer DebugHUD outside Game lifetime")

	_cleanup_slot()
	return failures


static func _assert_release_game(game: Node, label: String, failures: Array[String]) -> void:
	if game == null or not is_instance_valid(game):
		failures.append("%s route has no live production Game" % label)
		return
	if bool(game.get("enable_debug_hud")):
		failures.append("%s production Game did not retain debug-off default" % label)
	if game.get("debug_hud") != null or game.get_node_or_null("DebugHUD") != null:
		failures.append("%s production Game mounted DebugHUD despite release default" % label)
	var gameplay_hud = game.get("gameplay_hud")
	if gameplay_hud == null or not is_instance_valid(gameplay_hud):
		failures.append("%s production Game lost normal GameplayHUD with DebugHUD disabled" % label)
	elif not bool(gameplay_hud.get("visible")):
		failures.append("%s normal GameplayHUD is not visible with DebugHUD disabled" % label)


static func _send_f3(debug_hud: Node) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_F3
	debug_hud.call("_unhandled_input", event)


static func _direct_child_count_named(parent: Node, child_name: String) -> int:
	var count: int = 0
	for child in parent.get_children():
		if child.name == child_name:
			count += 1
	return count


static func _free_attached(tree: SceneTree, node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.is_inside_tree():
		node.queue_free()
		await tree.process_frame
	else:
		node.free()


static func _cleanup_slot() -> void:
	for path in [
		TEST_SLOT,
		TEST_SLOT + GameSaveSlotService.CANDIDATE_SUFFIX,
		TEST_SLOT + GameSaveSlotService.BACKUP_SUFFIX,
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
