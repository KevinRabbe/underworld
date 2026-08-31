extends SceneTree

const HudTests := preload("res://tests/presentation/test_gameplay_hud_contract.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = HudTests.run()
	if failures.is_empty():
		print("[HUD VALIDATION] PASS")
		print("  authoritative vitals / four-slot hotbar / material counts / fail-visible equipment / semantic feedback / DebugHUD independence passed")
		quit(0)
		return
	printerr("[HUD VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
