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
	printerr("[PLAYTEST INPUT HARNESS] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
