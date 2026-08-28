extends SceneTree

const StableIdentityTests := preload("res://tests/foundation/test_stable_identity.gd")
const DeterministicRandomTests := preload("res://tests/foundation/test_deterministic_random.gd")
const ManifestAndGraphTests := preload("res://tests/foundation/test_manifest_and_graph.gd")
const LegacyV2MigrationTests := preload("res://tests/foundation/test_legacy_v2_migration.gd")
const ServiceBoundaryTests := preload("res://tests/foundation/test_service_boundaries.gd")
const ProvenanceTests := preload("res://tests/foundation/test_generation_provenance.gd")
const CaveMeshTests := preload("res://tests/geometry/test_cave_mesh_builder.gd")
const PrimaryTopologyTests := preload("res://tests/topology/test_primary_topology.gd")
const EntranceGenerationTests := preload("res://tests/entrances/test_entrance_generation.gd")
const SecondaryConnectivityTests := preload("res://tests/connectivity/test_secondary_connectivity.gd")
const CaveGeometryTests := preload("res://tests/geometry/test_cave_geometry.gd")
const GeometryCellTests := preload("res://tests/geometry/test_geometry_cells.gd")
const ReproductionProbe := preload("res://worldgen/validation/reproduction_probe.gd")
const TopologyProbe := preload("res://worldgen/validation/topology_reproduction_probe.gd")
const EntranceProbe := preload("res://worldgen/validation/entrance_reproduction_probe.gd")
const ConnectivityProbe := preload("res://worldgen/validation/secondary_connectivity_reproduction_probe.gd")
const GeometryProbe := preload("res://worldgen/validation/cave_geometry_reproduction_probe.gd")
const GeometryCellProbe := preload("res://worldgen/validation/geometry_cell_reproduction_probe.gd")
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
		"topology-repro":
			_run_topology_reproduction(args)
		"entrance-repro":
			_run_entrance_reproduction(args)
		"connectivity-repro":
			_run_connectivity_reproduction(args)
		"geometry-repro":
			_run_geometry_reproduction(args)
		"geometry-cell-repro":
			_run_geometry_cell_reproduction(args)
		"batch":
			_run_batch(args)
		"geometry-cell-batch":
			_run_geometry_cell_batch(args)
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
	failures.append_array(ProvenanceTests.run())
	failures.append_array(CaveMeshTests.run())
	failures.append_array(PrimaryTopologyTests.run())
	failures.append_array(EntranceGenerationTests.run())
	failures.append_array(SecondaryConnectivityTests.run())
	failures.append_array(CaveGeometryTests.run())
	failures.append_array(GeometryCellTests.run())
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
				var first: Dictionary = GeometryProbe.build(world_seed, region)
				var second: Dictionary = GeometryProbe.build(world_seed, region)
				cases += 1
				if not bool(first.get("success", false)) or not bool(second.get("success", false)):
					failures.append(
						"geometry probe failed seed=%d region=(%d,%d) first=%s second=%s" % [
							world_seed,
							region_x,
							region_z,
							first.get("diagnostics", []),
							second.get("diagnostics", []),
						]
					)
					continue
				if first["fingerprint"] != second["fingerprint"]:
					failures.append(
						"non-deterministic geometry seed=%d region=(%d,%d) first=%s second=%s" % [
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


func _run_geometry_cell_batch(args: Dictionary) -> void:
	var start_seed: int = int(args.get("start-seed", "1"))
	var seed_count: int = maxi(int(args.get("count", "100")), 1)
	var region_radius: int = maxi(int(args.get("region-radius", "1")), 0)
	var failures: Array[String] = []
	var cases := 0
	var fingerprints: Dictionary = {}
	for seed_offset in range(seed_count):
		var world_seed := start_seed + seed_offset
		for region_z in range(-region_radius, region_radius + 1):
			for region_x in range(-region_radius, region_radius + 1):
				var region := Vector2i(region_x, region_z)
				var first: Dictionary = GeometryCellProbe.build(world_seed, region)
				var second: Dictionary = GeometryCellProbe.build(world_seed, region)
				cases += 1
				if not bool(first.get("success", false)) or not bool(second.get("success", false)):
					failures.append("geometry-cell probe failed seed=%d region=(%d,%d)" % [world_seed, region_x, region_z])
					continue
				if first["fingerprint"] != second["fingerprint"]:
					failures.append("non-deterministic geometry-cell seed=%d region=(%d,%d)" % [world_seed, region_x, region_z])
					continue
				fingerprints["%d:%d:%d" % [world_seed, region_x, region_z]] = first["fingerprint"]
	print("[VALIDATION GEOMETRY CELL BATCH] cases=%d seeds=%d start_seed=%d radius=%d unique_cases=%d" % [
		cases, seed_count, start_seed, region_radius, fingerprints.size(),
	])
	_finish("geometry-cell-batch", failures)


func _run_topology_reproduction(args: Dictionary) -> void:
	var world_seed: int = int(args.get("seed", "12345"))
	var region_x: int = int(args.get("region-x", "0"))
	var region_z: int = int(args.get("region-z", "0"))
	var expected: String = str(args.get("expect", ""))
	var probe: Dictionary = TopologyProbe.build(world_seed, Vector2i(region_x, region_z))
	if not bool(probe.get("success", false)):
		printerr("[TOPOLOGY REPRO] FAIL diagnostics=%s" % probe.get("diagnostics", []))
		quit(1)
		return
	var fingerprint: String = str(probe["fingerprint"])
	print("[TOPOLOGY REPRO]")
	print("  seed=%d" % world_seed)
	print("  region=(%d,%d)" % [region_x, region_z])
	print("  macro_fingerprint=%s" % probe["macro_fingerprint"])
	print("  topology_fingerprint=%s" % fingerprint)
	print("  metrics=%s" % probe["metrics"])
	if not expected.is_empty() and fingerprint != expected:
		printerr("[TOPOLOGY REPRO] expected=%s actual=%s" % [expected, fingerprint])
		quit(1)
		return
	quit(0)


func _run_entrance_reproduction(args: Dictionary) -> void:
	var world_seed: int = int(args.get("seed", "12345"))
	var region_x: int = int(args.get("region-x", "0"))
	var region_z: int = int(args.get("region-z", "0"))
	var expected: String = str(args.get("expect", ""))
	var probe: Dictionary = EntranceProbe.build(world_seed, Vector2i(region_x, region_z))
	if not bool(probe.get("success", false)):
		printerr("[ENTRANCE REPRO] FAIL stage=%s diagnostics=%s" % [
			probe.get("stage", "unknown"), probe.get("diagnostics", []),
		])
		quit(1)
		return
	var fingerprint: String = str(probe["fingerprint"])
	print("[ENTRANCE REPRO]")
	print("  seed=%d" % world_seed)
	print("  region=(%d,%d)" % [region_x, region_z])
	print("  macro_fingerprint=%s" % probe["macro_fingerprint"])
	print("  topology_fingerprint=%s" % probe["topology_fingerprint"])
	print("  entrance_fingerprint=%s" % fingerprint)
	print("  metrics=%s" % probe["metrics"])
	if not expected.is_empty() and fingerprint != expected:
		printerr("[ENTRANCE REPRO] expected=%s actual=%s" % [expected, fingerprint])
		quit(1)
		return
	quit(0)


func _run_connectivity_reproduction(args: Dictionary) -> void:
	var world_seed: int = int(args.get("seed", "12345"))
	var region_x: int = int(args.get("region-x", "0"))
	var region_z: int = int(args.get("region-z", "0"))
	var expected: String = str(args.get("expect", ""))
	var probe: Dictionary = ConnectivityProbe.build(world_seed, Vector2i(region_x, region_z))
	if not bool(probe.get("success", false)):
		printerr("[CONNECTIVITY REPRO] FAIL stage=%s diagnostics=%s" % [
			probe.get("stage", "unknown"), probe.get("diagnostics", []),
		])
		quit(1)
		return
	var fingerprint: String = str(probe["fingerprint"])
	print("[CONNECTIVITY REPRO]")
	print("  seed=%d" % world_seed)
	print("  region=(%d,%d)" % [region_x, region_z])
	print("  macro_fingerprint=%s" % probe["macro_fingerprint"])
	print("  topology_fingerprint=%s" % probe["topology_fingerprint"])
	print("  entrance_fingerprint=%s" % probe["entrance_fingerprint"])
	print("  connectivity_fingerprint=%s" % fingerprint)
	print("  metrics=%s" % probe["metrics"])
	if not expected.is_empty() and fingerprint != expected:
		printerr("[CONNECTIVITY REPRO] expected=%s actual=%s" % [expected, fingerprint])
		quit(1)
		return
	quit(0)


func _run_geometry_reproduction(args: Dictionary) -> void:
	var world_seed: int = int(args.get("seed", "12345"))
	var region_x: int = int(args.get("region-x", "0"))
	var region_z: int = int(args.get("region-z", "0"))
	var expected: String = str(args.get("expect", ""))
	var probe: Dictionary = GeometryProbe.build(world_seed, Vector2i(region_x, region_z))
	if not bool(probe.get("success", false)):
		printerr("[GEOMETRY REPRO] FAIL stage=%s diagnostics=%s" % [
			probe.get("stage", "unknown"), probe.get("diagnostics", []),
		])
		quit(1)
		return
	var fingerprint: String = str(probe["fingerprint"])
	print("[GEOMETRY REPRO]")
	print("  seed=%d" % world_seed)
	print("  region=(%d,%d)" % [region_x, region_z])
	print("  macro_fingerprint=%s" % probe["macro_fingerprint"])
	print("  topology_fingerprint=%s" % probe["topology_fingerprint"])
	print("  entrance_fingerprint=%s" % probe["entrance_fingerprint"])
	print("  connectivity_fingerprint=%s" % probe["connectivity_fingerprint"])
	print("  geometry_fingerprint=%s" % fingerprint)
	print("  metrics=%s" % probe["metrics"])
	if not expected.is_empty() and fingerprint != expected:
		printerr("[GEOMETRY REPRO] expected=%s actual=%s" % [expected, fingerprint])
		quit(1)
		return
	quit(0)


func _run_geometry_cell_reproduction(args: Dictionary) -> void:
	var world_seed: int = int(args.get("seed", "12345"))
	var region_x: int = int(args.get("region-x", "0"))
	var region_z: int = int(args.get("region-z", "0"))
	var expected: String = str(args.get("expect", ""))
	var probe: Dictionary = GeometryCellProbe.build(world_seed, Vector2i(region_x, region_z))
	if not bool(probe.get("success", false)):
		printerr("[GEOMETRY CELL REPRO] FAIL stage=%s diagnostics=%s" % [
			probe.get("stage", "unknown"), probe.get("diagnostics", []),
		])
		quit(1)
		return
	var fingerprint: String = str(probe["fingerprint"])
	print("[GEOMETRY CELL REPRO]")
	print("  seed=%d" % world_seed)
	print("  region=(%d,%d)" % [region_x, region_z])
	print("  geometry_fingerprint=%s" % probe["geometry_fingerprint"])
	print("  partition_fingerprint=%s" % fingerprint)
	print("  metrics=%s" % probe["metrics"])
	if not expected.is_empty() and fingerprint != expected:
		printerr("[GEOMETRY CELL REPRO] expected=%s actual=%s" % [expected, fingerprint])
		quit(1)
		return
	quit(0)


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
	print("  --mode=topology-repro --seed=12345 --region-x=0 --region-z=0 [--expect=topology-sha256:...]")
	print("  --mode=entrance-repro --seed=12345 --region-x=0 --region-z=0 [--expect=entrances-sha256:...]")
	print("  --mode=connectivity-repro --seed=12345 --region-x=0 --region-z=0 [--expect=connectivity-sha256:...]")
	print("  --mode=geometry-repro --seed=12345 --region-x=0 --region-z=0 [--expect=geometry-sha256:...]")
	print("  --mode=geometry-cell-repro --seed=12345 --region-x=0 --region-z=0 [--expect=gpartition-result1:sha256:...]")
	print("  --mode=batch --start-seed=1 --count=100 --region-radius=1")
	print("  --mode=geometry-cell-batch --start-seed=1 --count=250 --region-radius=1")
