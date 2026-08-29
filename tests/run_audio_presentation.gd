extends SceneTree

const AudioPresentationTests := preload("res://tests/presentation/test_audio_presentation_contract.gd")


func _init() -> void:
	var failures: Array[String] = AudioPresentationTests.run()
	if failures.is_empty():
		print("[AUDIO PRESENTATION VALIDATION] PASS")
		print("  semantic cue vocabulary / replaceable assets / global-spatial dispatch / ambience / mute-headless safety contracts passed")
		quit(0)
		return
	printerr("[AUDIO PRESENTATION VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
