extends SceneTree

const AppShellTests := preload("res://tests/presentation/test_app_shell_contract.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = AppShellTests.run()
	var runtime_failures: Array[String] = await AppShellTests.run_runtime(self)
	failures.append_array(runtime_failures)
	if failures.is_empty():
		print("[APP SHELL VALIDATION] PASS")
		print("  main-scene routing / off-tree NEW+CONTINUE preparation / fail-closed replacement / duplicate guard / theme boundary passed")
		quit(0)
		return
	printerr("[APP SHELL VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
