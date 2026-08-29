extends SceneTree

const UI_ARCHITECTURE_CONTRACT := preload("res://tests/presentation/test_ui_architecture_contract.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = UI_ARCHITECTURE_CONTRACT.run()
	if failures.is_empty():
		print("[UI ARCHITECTURE VALIDATION] PASS")
		quit(0)
		return
	for failure in failures:
		push_error("[UI ARCHITECTURE VALIDATION] %s" % failure)
	print("[UI ARCHITECTURE VALIDATION] FAIL (%d)" % failures.size())
	quit(1)
