extends SceneTree

const AppShellTests := preload("res://tests/presentation/test_app_shell_contract.gd")


func _init() -> void:
	var failures: Array[String] = AppShellTests.run()
	if failures.is_empty():
		print("[APP SHELL VALIDATION] PASS")
		print("  main-scene routing / title intents / fail-closed Continue / independent game scene passed")
		quit(0)
		return
	printerr("[APP SHELL VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
