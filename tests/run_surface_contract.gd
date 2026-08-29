extends SceneTree

const SurfaceContractTests := preload("res://tests/surface_contract/test_deterministic_surface_sampler.gd")


func _init() -> void:
	var failures: Array[String] = SurfaceContractTests.run()

	if failures.is_empty():
		print("[SURFACE CONTRACT VALIDATION] PASS")
		print("  repeated and order-independent sampling passed")
		print("  negative/chunk-boundary sampling passed")
		print("  surface sample invariants and pure-data ownership passed")
		quit(0)
		return

	printerr("[SURFACE CONTRACT VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
