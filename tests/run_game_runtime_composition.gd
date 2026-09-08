extends SceneTree

const GameRuntimeCompositionTests := preload("res://tests/presentation/test_game_runtime_composition_contract.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = await GameRuntimeCompositionTests.run_runtime(self)
	if failures.is_empty():
		print("[GAME RUNTIME COMPOSITION VALIDATION] PASS")
		quit(0)
		return
	printerr("[GAME RUNTIME COMPOSITION VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
