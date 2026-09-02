extends SceneTree

const AppShellTests := preload("res://tests/presentation/test_app_shell_contract.gd")
const GameFlowTests := preload("res://tests/presentation/test_game_flow_contract.gd")
const WeaponGameSessionTests := preload("res://tests/presentation/test_weapon_game_session_contract.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = AppShellTests.run()
	failures.append_array(GameFlowTests.run())
	var runtime_failures: Array[String] = await AppShellTests.run_runtime(self)
	failures.append_array(runtime_failures)
	var gameflow_runtime_failures: Array[String] = await GameFlowTests.run_runtime(self)
	failures.append_array(gameflow_runtime_failures)
	var weapon_runtime_failures: Array[String] = await WeaponGameSessionTests.run_runtime(self)
	failures.append_array(weapon_runtime_failures)
	if failures.is_empty():
		print("[APP SHELL VALIDATION] PASS")
		print("  routing / off-tree NEW+CONTINUE / pause-resume / Save & Quit / teardown / theme boundary / ordinary Game weapon-session composition passed")
		quit(0)
		return
	printerr("[APP SHELL VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
