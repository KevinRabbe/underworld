extends SceneTree

const GameplayStateCodecTests := preload("res://tests/persistence/test_gameplay_state_codec.gd")
const IntegratedGameSaveContractTests := preload("res://tests/persistence/test_integrated_game_save_contract.gd")
const GameSaveSlotServiceTests := preload("res://tests/persistence/test_game_save_slot_service.gd")
const IntegratedSurvivalPersistenceBoundaryTests := preload("res://tests/persistence/test_integrated_survival_persistence_boundary.gd")
const IntegratedGameRuntimeLifecycleTests := preload("res://tests/persistence/test_integrated_game_runtime_lifecycle.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	failures.append_array(GameplayStateCodecTests.run())
	failures.append_array(IntegratedGameSaveContractTests.run())
	failures.append_array(GameSaveSlotServiceTests.run())
	failures.append_array(IntegratedSurvivalPersistenceBoundaryTests.run())
	failures.append_array(IntegratedGameRuntimeLifecycleTests.run_runtime(self))
	if failures.is_empty():
		print("[PERSISTENCE STATE VALIDATION] PASS")
		print("  gameplay codecs / integrated detached save schema / typed wire / atomic slot lifecycle / source-level legacy retirement / real Game Continue activation passed")
		quit(0)
		return

	printerr("[PERSISTENCE STATE VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
