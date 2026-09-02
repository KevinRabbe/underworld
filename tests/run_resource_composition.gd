extends SceneTree

const CellObserverTests := preload("res://tests/resources/test_underground_resource_cell_observer.gd")
const CompositionTests := preload("res://tests/resources/test_underground_resource_composition.gd")
const ResidencyTests := preload("res://tests/resources/test_underground_resource_residency.gd")
const RealizationTests := preload("res://tests/resources/test_underground_resource_realization.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	failures.append_array(CellObserverTests.run())
	failures.append_array(CompositionTests.run())
	failures.append_array(ResidencyTests.run())

	var realization_parent := Node3D.new()
	root.add_child(realization_parent)
	failures.append_array(await RealizationTests.run(realization_parent))
	root.remove_child(realization_parent)
	realization_parent.free()

	if failures.is_empty():
		print("[RESOURCE COMPOSITION VALIDATION] PASS")
		print("  detached runtime source boundary / generated reserved-site assignment / channel-scoped candidate identity / canonical iron placement / bounded semantic residency / collision-gated support projection + realization / immediate retirement + depleted re-entry / stale-cell rejection passed")
		quit(0)
		return

	printerr("[RESOURCE COMPOSITION VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
