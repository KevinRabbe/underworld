extends SceneTree

const AudioPresentationTests := preload("res://tests/presentation/test_audio_presentation_contract.gd")
const GameplayAudioBindingTests := preload("res://tests/presentation/test_gameplay_audio_binding.gd")


func _init() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	var failures: Array[String] = AudioPresentationTests.run()
	failures.append_array(GameplayAudioBindingTests.run())
	if failures.is_empty():
		print("[AUDIO PRESENTATION VALIDATION] PASS")
		print("  semantic cue vocabulary / replaceable assets / gameplay binding / global-spatial dispatch / ambience / mute-headless safety contracts passed")
		quit(0)
		return
	printerr("[AUDIO PRESENTATION VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
