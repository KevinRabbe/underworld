extends SceneTree

const HudTests := preload("res://tests/presentation/test_gameplay_hud_contract.gd")
const ObjectiveGuidanceTests := preload("res://tests/presentation/test_gameplay_objective_guidance.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	failures.append_array(HudTests.run())
	failures.append_array(ObjectiveGuidanceTests.run())
	if failures.is_empty():
		print("[HUD VALIDATION] PASS")
		print("  authoritative vitals / four-slot hotbar / materials / semantic feedback / state-derived M3 objective guidance / DebugHUD independence passed")
		quit(0)
		return
	printerr("[HUD VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
