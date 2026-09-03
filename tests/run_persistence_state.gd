extends SceneTree

const GameplayStateCodecTests := preload("res://tests/persistence/test_gameplay_state_codec.gd")
const IntegratedGameSaveContractTests := preload("res://tests/persistence/test_integrated_game_save_contract.gd")
const GameSaveSlotServiceTests := preload("res://tests/persistence/test_game_save_slot_service.gd")
const SaveDomainReviewerRepairTests := preload("res://tests/persistence/test_save_domain_reviewer_repairs.gd")
const IntegratedSurvivalPersistenceBoundaryTests := preload("res://tests/persistence/test_integrated_survival_persistence_boundary.gd")
const IntegratedGameRuntimeLifecycleTests := preload("res://tests/persistence/test_integrated_game_runtime_lifecycle.gd")
const GameSaveTransitionPhaseReviewerRepairTests := preload("res://tests/persistence/test_game_save_transition_phase_reviewer_repair.gd")
const DeepUnderworldContinueReadinessTests := preload("res://tests/persistence/test_deep_underworld_continue_readiness.gd")
const DeathSaveCompatibilityTests := preload("res://tests/persistence/test_death_save_compatibility.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	failures.append_array(GameplayStateCodecTests.run())
	failures.append_array(IntegratedGameSaveContractTests.run())
	failures.append_array(GameSaveSlotServiceTests.run())
	failures.append_array(SaveDomainReviewerRepairTests.run())
	failures.append_array(IntegratedSurvivalPersistenceBoundaryTests.run())
	failures.append_array(IntegratedGameRuntimeLifecycleTests.run_runtime(self))
	failures.append_array(GameSaveTransitionPhaseReviewerRepairTests.run_runtime(self))
	failures.append_array(await DeepUnderworldContinueReadinessTests.run_runtime(self))
	failures.append_array(DeathSaveCompatibilityTests.run_runtime(self))
	if failures.is_empty():
		print("[PERSISTENCE STATE VALIDATION] PASS")
		print("  gameplay codecs / integrated detached save schema / typed wire / final mutation-boundary conditional SAVE CAS / transition-phase SAVE rejection / atomic slot lifecycle / source-level legacy retirement / restored loot allocator through real Game Continue activation / deep underworld exact-position multi-cell collision-safe Continue + real physics frames / death-recovery save compatibility passed")
		quit(0)
		return

	printerr("[PERSISTENCE STATE VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
