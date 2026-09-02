extends SceneTree

const GameplayStateCodecTests := preload("res://tests/persistence/test_gameplay_state_codec.gd")
const IntegratedGameSaveContractTests := preload("res://tests/persistence/test_integrated_game_save_contract.gd")
const GameSaveSlotServiceTests := preload("res://tests/persistence/test_game_save_slot_service.gd")
const IntegratedSurvivalPersistenceBoundaryTests := preload("res://tests/persistence/test_integrated_survival_persistence_boundary.gd")
const IntegratedGameRuntimeLifecycleTests := preload("res://tests/persistence/test_integrated_game_runtime_lifecycle.gd")
const DeathSaveCompatibilityTests := preload("res://tests/persistence/test_death_save_compatibility.gd")
const HeadlessSceneTreeCleanupTests := preload("res://tests/persistence/test_headless_scene_tree_cleanup.gd")
const HeadlessSceneTreeCleanup := preload("res://tests/helpers/headless_scene_tree_cleanup.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	failures.append_array(GameplayStateCodecTests.run())
	failures.append_array(IntegratedGameSaveContractTests.run())
	failures.append_array(GameSaveSlotServiceTests.run())
	failures.append_array(IntegratedSurvivalPersistenceBoundaryTests.run())
	failures.append_array(IntegratedGameRuntimeLifecycleTests.run_runtime(self))
	failures.append_array(DeathSaveCompatibilityTests.run_runtime(self))

	# Preserve the complete semantic result before entering test-harness cleanup.
	# Cleanup may advance engine lifecycle only; it is never allowed to rewrite a
	# gameplay/persistence assertion into success.
	var semantic_failures: Array[String] = failures.duplicate()
	failures.append_array(await HeadlessSceneTreeCleanupTests.run_runtime(self))
	failures.append_array(await HeadlessSceneTreeCleanup.drain(self))

	if failures.is_empty():
		print("[PERSISTENCE STATE VALIDATION] PASS")
		print("  gameplay codecs / integrated detached save schema / typed wire / atomic slot lifecycle / source-level legacy retirement / restored loot allocator through real Game Continue activation / death-recovery save compatibility / bounded headless teardown passed")
		quit(0)
		return

	printerr("[PERSISTENCE STATE VALIDATION] FAIL — %d failure(s)" % failures.size())
	if semantic_failures.is_empty():
		printerr("  semantic persistence contracts passed before cleanup; failure is in teardown hygiene")
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
