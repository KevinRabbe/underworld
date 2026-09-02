extends SceneTree

const CellObserverTests := preload("res://tests/resources/test_underground_resource_cell_observer.gd")
const CompositionTests := preload("res://tests/resources/test_underground_resource_composition.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(CellObserverTests.run())
	failures.append_array(CompositionTests.run())
	if failures.is_empty():
		print("[RESOURCE COMPOSITION VALIDATION] PASS")
		print("  current-cell observation / generated reserved-site assignment / channel-scoped candidate identity / canonical iron placement / stale-cell rejection passed")
		quit(0)
		return

	printerr("[RESOURCE COMPOSITION VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
