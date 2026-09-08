extends SceneTree

const PlayerLocomotionTests := preload("res://tests/character/test_player_locomotion_controller.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = PlayerLocomotionTests.run()
	if failures.is_empty():
		print("[PLAYER LOCOMOTION VALIDATION] PASS")
		print("  idle / walk / sprint / block / air / dodge / parry / jump / coyote / buffer / terminal traces passed")
		quit(0)
		return
	printerr("[PLAYER LOCOMOTION VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)