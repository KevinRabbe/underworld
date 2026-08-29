extends SceneTree

const SurfaceContractTests := preload("res://tests/surface_contract/test_deterministic_surface_sampler.gd")
const SurfacePickupRuntimeTests := preload("res://tests/surface_contract/test_surface_pickup_runtime_contract.gd")
const SurfacePersistenceIdentityTests := preload("res://tests/surface_contract/test_surface_persistence_identity_boundary.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(SurfaceContractTests.run())
	failures.append_array(SurfacePickupRuntimeTests.run())
	failures.append_array(SurfacePersistenceIdentityTests.run())

	if failures.is_empty():
		print("[SURFACE CONTRACT VALIDATION] PASS")
		print("  repeated and order-independent sampling passed")
		print("  negative/chunk-boundary sampling passed")
		print("  surface sample invariants and pure-data ownership passed")
		print("  non-mutating pickup discovery and canonical StableId runtime identity passed")
		print("  malformed, legacy, foreign, and type-mismatched persistence identity fails closed")
		quit(0)
		return

	printerr("[SURFACE CONTRACT VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
