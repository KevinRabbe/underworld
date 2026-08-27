extends SceneTree

const StableIdentityTests := preload("res://tests/foundation/test_stable_identity.gd")
const DeterministicRandomTests := preload("res://tests/foundation/test_deterministic_random.gd")
const ManifestAndGraphTests := preload("res://tests/foundation/test_manifest_and_graph.gd")
const LegacyV2MigrationTests := preload("res://tests/foundation/test_legacy_v2_migration.gd")
const ServiceBoundaryTests := preload("res://tests/foundation/test_service_boundaries.gd")
const ReproductionProbe := preload("res://worldgen/validation/reproduction_probe.gd")
const SampleGraphFixture := preload("res://tests/foundation/sample_graph_fixture.gd")
const GraphValidator := preload("res://worldgen/validation/graph_validator.gd")
const GraphCanonicalizer := preload("res://worldgen/validation/graph_canonicalizer.gd")


func _init() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var mode: String = str(args.get("mode", "fast"))

	match mode:
		"fast":
			_run_fast()
		"fixture":
			_run_fixture(str(args.get("name", "graph")))
		"repro":
			_run_reproduction(args)
		"batch":
			_run_batch(args)
		_:
			printerr("[VALIDATION] unknown mode: %s" % mode)
			_print_usage()
			quit(2)


func _run_fast() -> void:
	var failures: Array[String] = []
	failures.append_array(StableIdentityTests.run())
	failures.append_array(DeterministicRandomTests.run())
	failures.append_array(ManifestAndGraphTests.run())
	failures.append_array(LegacyV2MigrationTests.run())
	failures.append_array(ServiceBoundaryTests.run())
	_finish("fast", failures)


func _run_fixture(fixture_name: String) -> void:
	var failures: Array[String] = []
	match fixture_name:
		"legacy-v2":
			failures.append_array(LegacyV2MigrationTests.run())
		"graph":
			var bundle = SampleGraphFixture.build()
			failures.append_array(GraphValidator.validate_region_bundle(bundle))
			if failures.is_empty():
				print(
					"[VALIDATION] graph fingerprint=%s" %
					GraphCanonicalizer.region_bundle_fingerprint(bundle)
				)
		_:
			failures.append("unknown fixture: %s" % fixture_name)
	_finish("fixture:%s" % fixture_name, failures)


func _run_reproduction(args: Dictionary) -> void:
	var world_seed: int = int(args.get("seed", "12345"))
	var region_x: int = int(args.get("region-x", "0"))
	var region_z: int = int(args.get("region-z", "0"))
	var expected: String = str(args.get("expect", ""))
	var region := Vector2i(region_x, region_z)
	var probe: Dictionary = ReproductionProbe.build(world_seed, region)
	var fingerprint: String = str(probe["fingerprint"])

	print("[VALIDATION REPRO]")
	print("  seed=%d" % world_seed)
	print("  region=(%d,%d)" % [region_x, region_z])
	print("  fingerprint=%s" % fingerprint)
	print("  payload=%s" % probe["canonical"])

	if not expected.is_empty() and fingerprint != expected:
		printerr(
			"[VALIDATION REPRO] FAIL seed=%d region=(%d,%d) expected=%s actual=%s" % [
				world_seed,
				region_x,
				region_z,
				expected,
				fingerprint,
			]
		)
		quit(1)
		return
	quit(0)


func _run_batch(args: Dictionary) -> void:
	var start_seed: int = int(args.get("start-seed", "1"))
	var seed_count: int = maxi(int(args.get("count", "100")), 1)
	var region_radius: int = maxi(int(args.get("region-radius", "1")), 0)
	var failures: Array[String] = []
	var cases: int = 0
	var fingerprints: Dictionary = {}

	for seed_offset in range(seed_count):
		var world_seed: int = start_seed + seed_offset
		for region_z in range(-region_radius, region_radius + 1):
			for region_x in range(-region_radius, region_radius + 1):
				var region := Vector2i(region_x, region_z)
				var first: Dictionary = ReproductionProbe.build(world_seed, region)
				var second: Dictionary = ReproductionProbe.build(world_seed, region)
				cases += 1
				if first["fingerprint"] != second["fingerprint"]:
					failures.append(
						"non-deterministic probe seed=%d region=(%d,%d) first=%s second=%s" % [
							world_seed,
							region_x,
							region_z,
							first["fingerprint"],
							second["fingerprint"],
						]
					)
					continue

				var fingerprint: String = str(first["fingerprint"])
				var case_key: String = "%d:%d:%d" % [world_seed, region_x, region_z]
				fingerprints[case_key] = fingerprint

	print(
		"[VALIDATION BATCH] cases=%d seeds=%d start_seed=%d radius=%d unique_cases=%d" % [
			cases,
			seed_count,
			start_seed,
			region_radius,
			fingerprints.size(),
		]
	)
	_finish("batch", failures)


func _finish(label: String, failures: Array[String]) -> void:
	if failures.is_empty():
		print("[VALIDATION] PASS %s" % label)
		quit(0)
		return

	printerr("[VALIDATION] FAIL %s — %d failure(s)" % [label, failures.size()])
	for failure in failures:
		printerr("  - " + failure)
	quit(1)


static func _parse_args(raw_args: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for raw in raw_args:
		var value: String = str(raw)
		if not value.begins_with("--"):
			continue
		value = value.substr(2)
		var equals_index: int = value.find("=")
		if equals_index < 0:
			result[value] = "true"
		else:
			result[value.substr(0, equals_index)] = value.substr(equals_index + 1)
	return result


static func _print_usage() -> void:
	print("Underworld headless validation")
	print("  --mode=fast")
	print("  --mode=fixture --name=graph|legacy-v2")
	print("  --mode=repro --seed=12345 --region-x=0 --region-z=0 [--expect=probe-sha256:...]")
	print("  --mode=batch --start-seed=1 --count=100 --region-radius=1")
