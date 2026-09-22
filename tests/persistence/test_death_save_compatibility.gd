extends RefCounted

const GAME_SCENE_PATH := "res://app/game/game.tscn"
const TEST_SLOT := "user://death_001_save_compatibility.json"
const PendingLootState := preload("res://gameplay/loot/runtime/pending_loot_state.gd")
const InventoryStateCodec := preload("res://gameplay/items/inventory/inventory_state_codec.gd")
const GameplaySaveCatalog := preload("res://gameplay/persistence/gameplay_save_catalog.gd")
const GameSaveSlotService := preload("res://gameplay/persistence/game_save_slot_service.gd")

const CHITIN_ID := "item.resource.burrower_chitin"
const PROFILE_ID := "loot_profile.creature.burrower.m3"
const OCCURRENCE_ID := "burrower_88"


static func run_runtime(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_cleanup_slot()
	if tree == null or tree.root == null:
		return ["DEATH SAVE compatibility requires SceneTree root"]
	var packed = ResourceLoader.load(GAME_SCENE_PATH)
	if packed == null or not packed is PackedScene:
		return ["DEATH SAVE compatibility could not load Game scene"]

	var game: Node = packed.instantiate()
	game.set("enable_debug_hud", false)
	if not bool(game.call("prepare_new_game")):
		game.free()
		return ["DEATH SAVE compatibility could not prepare NEW Game"]
	tree.root.add_child(game)

	var player = game.get("player")
	var survival = game.get("survival")
	var encounter = game.get("encounter_controller")
	var recovery = game.get("death_recovery_controller")
	var store = game.get("world_delta_store")
	var death_cache = game.get("death_cache_service")
	if player == null or survival == null or encounter == null or recovery == null or store == null or death_cache == null:
		failures.append("DEATH Game composition is missing Player/Survival/encounter/recovery/WorldDelta authority")
		_free_attached(game)
		_cleanup_slot()
		return failures

	var catalog_result: Dictionary = GameplaySaveCatalog.build_registry()
	if not _require_success(catalog_result, "DEATH SAVE catalog", failures):
		_free_attached(game)
		_cleanup_slot()
		return failures
	var registry = catalog_result.get("registry", null)
	var chitin = registry.get_definition(CHITIN_ID) if registry != null else null
	if chitin == null:
		failures.append("DEATH SAVE catalog lacks chitin definition")
		_free_attached(game)
		_cleanup_slot()
		return failures
	var definition_contract: String = InventoryStateCodec.canonical_json(chitin.canonical_descriptor())
	var pending = PendingLootState.new().configure(OCCURRENCE_ID, PROFILE_ID, [{
		"item_id": CHITIN_ID,
		"quantity": 2,
		"definition_contract": definition_contract,
	}])
	if not pending.validate_state().is_empty():
		failures.append("DEATH SAVE pending-loot fixture is invalid")
		_free_attached(game)
		_cleanup_slot()
		return failures
	var imported: Dictionary = encounter.import_pending_loot_states([pending], player.global_position)
	if not _require_success(imported, "DEATH pending-loot import", failures):
		_free_attached(game)
		_cleanup_slot()
		return failures

	var inventory = survival.get_inventory_state()
	var equipment = survival.get_equipment_state()
	var cargo_added: Dictionary = inventory.add_stack(chitin, 3, {"death_fixture": true})
	if not _require_success(cargo_added, "DEATH SAVE cargo fixture", failures):
		_free_attached(game)
		_cleanup_slot()
		return failures
	var cargo_before: Dictionary = inventory.canonical_snapshot()
	var equipment_before: Dictionary = equipment.canonical_snapshot()
	var world_delta_before: Dictionary = store.snapshot()
	var pending_before: Dictionary = encounter.get_pending_loot_snapshot(OCCURRENCE_ID)
	var pending_count_before: int = encounter.get_pending_loot_count()
	var old_position: Vector3 = player.global_position

	# Bypass defense windows and enter the actual Game-composed defeat route. The
	# signal synchronously marks recovery pending; the deferred recovery has not run
	# yet, so we can prove no hidden teleport or loot mutation at the defeated seam.
	player.call("_apply_damage", 999, old_position + Vector3.RIGHT)
	if not bool(player.call("is_defeated")):
		failures.append("real Game lethal damage did not enter defeated state")
	if not bool(recovery.call("is_recovery_pending")):
		failures.append("real Game defeat did not arm recovery lifecycle")
	if player.global_position != old_position:
		failures.append("real Game defeat teleported Player before recovery commit")
	var duplicate_capture: Dictionary = death_cache.capture_death(old_position)
	if not bool(duplicate_capture.get("success", false)) or not bool(duplicate_capture.get("already_captured", false)):
		failures.append("real Game defeat created more than one death cache")

	# Even if collection is explicitly polled while defeated, Game must suppress it
	# so death itself cannot consume/duplicate unresolved rewards.
	game.call("_collect_nearby_pending_loot")
	_assert_post_death_ownership(
		inventory,
		equipment,
		death_cache,
		store,
		encounter,
		equipment_before,
		world_delta_before,
		pending_before,
		pending_count_before,
		cargo_before,
		"while defeated",
		failures
	)

	# A defeated Player is not a recoverable SAVE resume anchor because defeated,
	# health and action state are intentionally not durable. Reject the request
	# before recovery commits and prove the read-only failure mutates no durable
	# inventory/equipment/world/loot authority.
	var defeated_request_variant: Variant = game.call("build_save_request")
	if not defeated_request_variant is Dictionary:
		failures.append("defeated Game SAVE request did not return Dictionary failure")
	elif bool(defeated_request_variant.get("success", false)):
		failures.append("defeated Game unexpectedly produced a successful SAVE request")
	else:
		var defeated_diagnostics: Array = defeated_request_variant.get("diagnostics", [])
		if not defeated_diagnostics.has("SAVE runtime snapshot rejects defeated Player"):
			failures.append("defeated Game SAVE rejection omitted deterministic diagnostic")
	_assert_post_death_ownership(
		inventory,
		equipment,
		death_cache,
		store,
		encounter,
		equipment_before,
		world_delta_before,
		pending_before,
		pending_count_before,
		cargo_before,
		"after rejected defeated SAVE request",
		failures
	)

	var recovered: Dictionary = recovery.call("try_commit_recovery")
	if not _require_success(recovered, "real Game death recovery", failures):
		_free_attached(game)
		_cleanup_slot()
		return failures
	if bool(player.call("is_defeated")):
		failures.append("real Game recovery left Player defeated")
	if not _is_finite_vector3(player.global_position):
		failures.append("real Game recovery committed non-finite Player position")
	_assert_post_death_ownership(
		inventory,
		equipment,
		death_cache,
		store,
		encounter,
		equipment_before,
		world_delta_before,
		pending_before,
		pending_count_before,
		cargo_before,
		"after respawn before cache collection",
		failures
	)

	var request_variant: Variant = game.call("build_save_request")
	if not request_variant is Dictionary or not bool(request_variant.get("success", false)):
		failures.append("post-respawn Game could not build accepted SAVE request: %s" % [
			request_variant.get("diagnostics", []) if request_variant is Dictionary else [],
		])
		_free_attached(game)
		_cleanup_slot()
		return failures
	var request_object: Dictionary = request_variant
	var request_variant_inner: Variant = request_object.get("request", null)
	if not request_variant_inner is Dictionary:
		failures.append("post-respawn SAVE request object did not contain detached request payload")
		_free_attached(game)
		_cleanup_slot()
		return failures
	var request: Dictionary = request_variant_inner
	var resume_wire_variant: Variant = request.get("player_resume", null)
	if not resume_wire_variant is Dictionary:
		failures.append("post-respawn SAVE request omitted player_resume wire snapshot")
	else:
		var resume_wire: Dictionary = resume_wire_variant
		var saved_resume := Vector3(
			float(resume_wire.get("x", INF)),
			float(resume_wire.get("y", INF)),
			float(resume_wire.get("z", INF))
		)
		if saved_resume != player.global_position:
			failures.append("post-respawn SAVE request did not capture committed recovery position")
	var request_pending: Variant = request.get("pending_loot_jsons", null)
	if not request_pending is Array or request_pending.size() != 1:
		failures.append("post-respawn SAVE request changed unresolved pending-loot set")

	var service = GameSaveSlotService.new()
	var saved: Dictionary = service.save_slot(request_object, TEST_SLOT)
	if not _require_success(saved, "post-respawn atomic SAVE", failures):
		_free_attached(game)
		_cleanup_slot()
		return failures
	var loaded: Dictionary = service.load_slot(TEST_SLOT)
	if not _require_success(loaded, "post-respawn atomic load", failures):
		_free_attached(game)
		_cleanup_slot()
		return failures
	var candidate_variant: Variant = loaded.get("candidate", null)
	if not candidate_variant is Dictionary:
		failures.append("post-respawn slot load did not return detached candidate")
	else:
		var candidate: Dictionary = candidate_variant
		if candidate.get("resume_position", Vector3.ZERO) != player.global_position:
			failures.append("save/load round-trip changed post-respawn Player position")
		var restored_inventory = candidate.get("inventory_state", null)
		var restored_equipment = candidate.get("equipment_state", null)
		var restored_store = candidate.get("delta_store", null)
		var restored_pending: Variant = candidate.get("pending_loot_states", null)
		if restored_inventory == null or restored_inventory.occupied_slot_count() != 0:
			failures.append("save/load round-trip restored cargo to defeated Player before recovery")
		if restored_equipment == null or restored_equipment.canonical_snapshot() != equipment_before:
			failures.append("save/load round-trip changed equipment across death")
		if restored_store == null or restored_store.snapshot() != world_delta_before:
			failures.append("save/load round-trip changed WorldDelta across death")
		if not restored_pending is Array or restored_pending.size() != 1:
			failures.append("save/load round-trip lost unresolved pending loot across death")
		elif restored_pending[0].canonical_snapshot() != pending_before:
			failures.append("save/load round-trip changed pending loot across death")
		var restored_death_cache: Variant = candidate.get("death_cache_state", null)
		if not restored_death_cache is Dictionary:
			failures.append("save/load round-trip omitted unresolved death cache")
		elif bool(restored_death_cache.get("cache", {}).get("collected", true)):
			failures.append("save/load round-trip prematurely resolved death cache")

	var collected: Dictionary = death_cache.collect_cache()
	if not _require_success(collected, "normal death-cache recovery", failures):
		_free_attached(game)
		_cleanup_slot()
		return failures
	if inventory.canonical_snapshot() != cargo_before:
		failures.append("normal death-cache recovery did not restore exact cargo")
	if death_cache.has_cache():
		failures.append("resolved death cache remained collectible")
	var recovered_inventory_before_duplicate: Dictionary = inventory.canonical_snapshot()
	var duplicate_collection: Dictionary = death_cache.collect_cache()
	if bool(duplicate_collection.get("success", false)):
		failures.append("resolved death cache restored cargo more than once")
	if inventory.canonical_snapshot() != recovered_inventory_before_duplicate:
		failures.append("rejected duplicate death-cache collection mutated Player cargo")

	var recovered_request_variant: Variant = game.call("build_save_request")
	if not recovered_request_variant is Dictionary or not bool(recovered_request_variant.get("success", false)):
		failures.append("post-recovery Game could not build accepted SAVE request")
	else:
		var recovered_request: Variant = recovered_request_variant.get("request", null)
		if not recovered_request is Dictionary:
			failures.append("post-recovery SAVE request omitted detached request payload")
			_free_attached(game)
			_cleanup_slot()
			return failures
		var recovered_save: Dictionary = service.save_slot(recovered_request, TEST_SLOT)
		if not _require_success(recovered_save, "post-recovery atomic SAVE", failures):
			_free_attached(game)
			_cleanup_slot()
			return failures
		var recovered_loaded: Dictionary = service.load_slot(TEST_SLOT)
		if not _require_success(recovered_loaded, "post-recovery atomic load", failures):
			_free_attached(game)
			_cleanup_slot()
			return failures
		var recovered_candidate: Variant = recovered_loaded.get("candidate", null)
		if not recovered_candidate is Dictionary:
			failures.append("post-recovery slot load did not return detached candidate")
		else:
			var recovered_inventory = recovered_candidate.get("inventory_state", null)
			var recovered_cache: Variant = recovered_candidate.get("death_cache_state", null)
			if recovered_inventory == null or recovered_inventory.canonical_snapshot() != cargo_before:
				failures.append("save/continue after recovery lost or duplicated cargo")
			if not recovered_cache is Dictionary or not bool(recovered_cache.get("cache", {}).get("collected", false)):
				failures.append("save/continue after recovery resurrected death cache")

	_free_attached(game)
	_cleanup_slot()
	return failures


static func _assert_post_death_ownership(
	inventory,
	equipment,
	death_cache,
	store,
	encounter,
	equipment_before: Dictionary,
	world_delta_before: Dictionary,
	pending_before: Dictionary,
	pending_count_before: int,
	cargo_before: Dictionary,
	label: String,
	failures: Array[String]
) -> void:
	if inventory.occupied_slot_count() != 0:
		failures.append("DEATH left cargo in Player inventory %s" % label)
	var cache_snapshot: Dictionary = death_cache.cache_snapshot()
	if not death_cache.has_cache():
		failures.append("DEATH cache is missing unresolved cargo %s" % label)
	elif cache_snapshot.get("cargo", {}) != cargo_before:
		failures.append("DEATH cache does not own exact cargo %s" % label)
	if equipment.canonical_snapshot() != equipment_before:
		failures.append("DEATH mutated equipment %s" % label)
	if store.snapshot() != world_delta_before:
		failures.append("DEATH mutated WorldDelta %s" % label)
	if encounter.get_pending_loot_count() != pending_count_before:
		failures.append("DEATH changed pending-loot count %s" % label)
	if encounter.get_pending_loot_snapshot(OCCURRENCE_ID) != pending_before:
		failures.append("DEATH changed pending-loot state %s" % label)


static func _is_finite_vector3(value: Vector3) -> bool:
	return (
		not is_nan(value.x) and not is_inf(value.x)
		and not is_nan(value.y) and not is_inf(value.y)
		and not is_nan(value.z) and not is_inf(value.z)
	)


static func _free_attached(node: Node) -> void:
	if node == null:
		return
	if node.is_inside_tree():
		var parent: Node = node.get_parent()
		if parent != null:
			parent.remove_child(node)
	node.free()


static func _cleanup_slot() -> void:
	for path in [
		TEST_SLOT,
		TEST_SLOT + GameSaveSlotService.CANDIDATE_SUFFIX,
		TEST_SLOT + GameSaveSlotService.BACKUP_SUFFIX,
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _require_success(result: Dictionary, label: String, failures: Array[String]) -> bool:
	if bool(result.get("success", false)):
		return true
	failures.append("%s failed diagnostics=%s" % [label, result.get("diagnostics", [])])
	return false
