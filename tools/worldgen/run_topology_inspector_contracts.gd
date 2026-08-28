extends SceneTree

const SnapshotBuilder := preload("res://tools/worldgen/topology_snapshot_builder.gd")
const SnapshotSvg := preload("res://tools/worldgen/topology_snapshot_svg.gd")


func _init() -> void:
	var failures: Array[String] = []
	_test_deterministic_snapshot(failures)
	_test_snapshot_integrity(failures)
	_test_negative_coordinates(failures)
	_finish(failures)


static func _test_deterministic_snapshot(failures: Array[String]) -> void:
	var first: Dictionary = SnapshotBuilder.build(12345, Vector2i.ZERO)
	var second: Dictionary = SnapshotBuilder.build(12345, Vector2i.ZERO)
	_expect_true(failures, "first snapshot builds", bool(first.get("success", false)))
	_expect_true(failures, "second snapshot builds", bool(second.get("success", false)))
	if not bool(first.get("success", false)) or not bool(second.get("success", false)):
		return

	_expect_equal(
		failures,
		"macro fingerprint reproduces",
		first["macro_fingerprint"],
		second["macro_fingerprint"]
	)
	_expect_equal(
		failures,
		"topology fingerprint reproduces",
		first["topology_fingerprint"],
		second["topology_fingerprint"]
	)
	var first_json: String = JSON.stringify(first["snapshot"], "", true, true)
	var second_json: String = JSON.stringify(second["snapshot"], "", true, true)
	_expect_equal(failures, "JSON snapshot reproduces exactly", first_json, second_json)
	_expect_equal(
		failures,
		"SVG snapshot reproduces exactly",
		SnapshotSvg.render(first["snapshot"]),
		SnapshotSvg.render(second["snapshot"])
	)


static func _test_snapshot_integrity(failures: Array[String]) -> void:
	var built: Dictionary = SnapshotBuilder.build(778899, Vector2i(2, -3))
	if not bool(built.get("success", false)):
		failures.append("integrity snapshot failed: %s" % str(built.get("diagnostics", [])))
		return
	var snapshot: Dictionary = built["snapshot"]
	_expect_equal(
		failures,
		"snapshot schema",
		str(snapshot.get("schema", "")),
		"underworld-topology-snapshot-v1"
	)
	_expect_equal(
		failures,
		"snapshot carries macro fingerprint",
		str(snapshot.get("macro_fingerprint", "")),
		str(built["macro_fingerprint"])
	)
	_expect_equal(
		failures,
		"snapshot carries topology fingerprint",
		str(snapshot.get("topology_fingerprint", "")),
		str(built["topology_fingerprint"])
	)
	_expect_true(failures, "macro fingerprint is non-empty", not str(built["macro_fingerprint"]).is_empty())
	_expect_true(failures, "topology fingerprint is non-empty", not str(built["topology_fingerprint"]).is_empty())

	var metrics: Dictionary = snapshot.get("metrics", {})
	var networks: Array = snapshot.get("networks", [])
	var nodes: Array = snapshot.get("nodes", [])
	var edges: Array = snapshot.get("edges", [])
	var boundary_candidates: Array = snapshot.get("boundary_candidates", [])
	_expect_equal(
		failures,
		"network count matches topology metrics",
		networks.size(),
		int(metrics.get("accepted_network_count", -1))
	)
	_expect_equal(
		failures,
		"node count matches topology metrics",
		nodes.size(),
		int(metrics.get("node_count", -1))
	)
	_expect_equal(
		failures,
		"edge count matches topology metrics",
		edges.size(),
		int(metrics.get("primary_edge_count", -1))
	)
	_expect_equal(
		failures,
		"boundary count matches topology metrics",
		boundary_candidates.size(),
		int(metrics.get("boundary_candidate_count", -1))
	)
	_expect_sorted(failures, "network IDs are canonical", _ids(networks))
	_expect_sorted(failures, "node IDs are canonical", _ids(nodes))
	_expect_sorted(failures, "edge IDs are canonical", _ids(edges))

	var node_ids: Dictionary = {}
	for node in nodes:
		var node_id: String = str(node.get("stable_id", ""))
		node_ids[node_id] = true
		_expect_true(failures, "node stable id is non-empty", not node_id.is_empty())
		_expect_position_in_bounds(failures, node, snapshot["region"])
		var profile: Array = node.get("profile_blend", [])
		_expect_true(failures, "profile has three weights", profile.size() == 3)
		if profile.size() == 3:
			var total: float = float(profile[0]) + float(profile[1]) + float(profile[2])
			_expect_true(failures, "profile weights are normalized", absf(total - 1.0) <= 0.001)

	for edge in edges:
		_expect_true(
			failures,
			"edge endpoint A exists",
			node_ids.has(str(edge.get("endpoint_a_node_id", "")))
		)
		_expect_true(
			failures,
			"edge endpoint B exists",
			node_ids.has(str(edge.get("endpoint_b_node_id", "")))
		)

	for candidate in boundary_candidates:
		_expect_true(
			failures,
			"boundary candidate node exists",
			node_ids.has(str(candidate.get("node_id", "")))
		)
		_expect_true(
			failures,
			"boundary candidate side is valid",
			str(candidate.get("side", "")) in ["west", "east", "north", "south"]
		)

	var svg: String = SnapshotSvg.render(snapshot)
	_expect_true(failures, "SVG has root element", svg.contains("<svg"))
	_expect_true(failures, "SVG carries seed", svg.contains("seed=778899"))
	_expect_true(failures, "SVG carries topology fingerprint", svg.contains(str(built["topology_fingerprint"])))


static func _test_negative_coordinates(failures: Array[String]) -> void:
	var built: Dictionary = SnapshotBuilder.build(-998877, Vector2i(-5, -4))
	_expect_true(failures, "negative-coordinate snapshot builds", bool(built.get("success", false)))
	if not bool(built.get("success", false)):
		return
	var snapshot: Dictionary = built["snapshot"]
	_expect_equal(failures, "negative seed is preserved", int(snapshot.get("world_seed", 0)), -998877)
	_expect_equal(failures, "negative region coordinate is preserved", snapshot["region"]["coord"], [-5, -4])
	_expect_true(failures, "negative snapshot has nodes", not snapshot.get("nodes", []).is_empty())
	_expect_true(failures, "negative snapshot SVG renders", SnapshotSvg.render(snapshot).contains("region=(-5,-4)"))


static func _expect_position_in_bounds(
	failures: Array[String],
	node: Dictionary,
	region: Dictionary
) -> void:
	var bounds: Dictionary = region.get("world_bounds", {})
	var minimum: Array = bounds.get("position", [0.0, 0.0, 0.0])
	var size: Array = bounds.get("size", [0.0, 0.0, 0.0])
	var position: Array = node.get("world_position", [])
	if position.size() != 3:
		failures.append("node position must have three coordinates")
		return
	for axis in range(3):
		var lower: float = float(minimum[axis]) - 0.001
		var upper: float = float(minimum[axis]) + float(size[axis]) + 0.001
		var value: float = float(position[axis])
		if value < lower or value > upper:
			failures.append("node position outside region bounds axis=%d value=%s range=[%s,%s]" % [
				axis, str(value), str(lower), str(upper),
			])


static func _ids(definitions: Array) -> Array[String]:
	var result: Array[String] = []
	for definition in definitions:
		result.append(str(definition.get("stable_id", "")))
	return result


static func _expect_sorted(failures: Array[String], label: String, values: Array[String]) -> void:
	var sorted: Array[String] = values.duplicate()
	sorted.sort()
	_expect_equal(failures, label, values, sorted)


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s expected=%s actual=%s" % [label, str(expected), str(actual)])


static func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("[WORLDGEN INSPECTOR] PASS")
		quit(0)
		return
	printerr("[WORLDGEN INSPECTOR] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
