extends SceneTree

const Harness := preload("res://tests/playtest/test_survival_demo_input_harness.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = await Harness.run_runtime(self)
	if failures.is_empty():
		print("[PLAYTEST INPUT HARNESS] PASS — production movement / inventory / equip / craft / build input and save boundary exercised")
		quit(0)
		return
	var blocked := false
	for failure in failures:
		if failure.begins_with("BLOCKED:") or failure.begins_with("SAVE BLOCKED:"):
			blocked = true
	printerr("[PLAYTEST INPUT HARNESS] %s — %d issue(s)" % ["BLOCKED" if blocked else "FAIL", failures.size()])
	for failure in failures:
		printerr("  - " + failure)
	quit(2 if blocked else 1)
