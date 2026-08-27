extends SceneTree

const StableIdentityTests := preload("res://tests/foundation/test_stable_identity.gd")
const DeterministicRandomTests := preload("res://tests/foundation/test_deterministic_random.gd")
const ManifestAndGraphTests := preload("res://tests/foundation/test_manifest_and_graph.gd")
const LegacyV2MigrationTests := preload("res://tests/foundation/test_legacy_v2_migration.gd")
const ServiceBoundaryTests := preload("res://tests/foundation/test_service_boundaries.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(StableIdentityTests.run())
	failures.append_array(DeterministicRandomTests.run())
	failures.append_array(ManifestAndGraphTests.run())
	failures.append_array(LegacyV2MigrationTests.run())
	failures.append_array(ServiceBoundaryTests.run())

	if failures.is_empty():
		print("[FOUNDATION TESTS] PASS")
		print("  StableAddress / StableId vectors and invariants passed")
		print("  Seed-domain registry / seed derivation / PRNG vectors passed")
		print("  GeneratorManifest / canonical serialization / graph invariants passed")
		print("  Prototype-v2 save migration / quarantine / repeatability passed")
		print("  WorldGenerationContext / definition service / delta-store boundaries passed")
		quit(0)
		return

	printerr("[FOUNDATION TESTS] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
