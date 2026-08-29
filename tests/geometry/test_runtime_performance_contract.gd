extends RefCounted

const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")
const MeshData := preload("res://worldgen/geometry/cave_mesh_data.gd")
const Budget := preload("res://worldgen/runtime/runtime_performance_budget.gd")
const Profiler := preload("res://worldgen/runtime/runtime_cave_profiler.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_observational_timings_do_not_change_mesh_identity(failures)
	_test_warning_budgets_are_explicit_and_non_gating(failures)
	_test_profiler_contract_is_available(failures)
	return failures


static func _test_observational_timings_do_not_change_mesh_identity(failures: Array[String]) -> void:
	var address := Address.new(Vector3i(-2, -3, -2))
	var vertices := PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD])
	var indices := PackedInt32Array([0, 1, 2])
	var normals := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	var uvs := PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
	var base_metrics := {
		"vertex_count": 3,
		"triangle_count": 1,
		"memory_bytes": 104,
		"extraction_ms": 1.0,
		"preparation_ms": 1.0,
	}
	var first := MeshData.new(
		address,
		AABB(Vector3(-64, -96, -64), Vector3(32, 32, 32)),
		vertices,
		indices,
		normals,
		uvs,
		["descriptor:perf001"],
		["fragment:perf001"],
		"input:perf001",
		base_metrics
	)
	var changed_metrics := base_metrics.duplicate(true)
	changed_metrics["extraction_ms"] = 999999.0
	changed_metrics["preparation_ms"] = 888888.0
	changed_metrics["runtime_realization_ms"] = 777777.0
	var second := MeshData.new(
		address,
		first.world_bounds,
		vertices,
		indices,
		normals,
		uvs,
		["descriptor:perf001"],
		["fragment:perf001"],
		"input:perf001",
		changed_metrics
	)
	if first.output_fingerprint != second.output_fingerprint:
		failures.append("wall-clock profiling changed deterministic mesh-buffer identity")
	if first.fingerprint != second.fingerprint:
		failures.append("wall-clock profiling changed deterministic CaveMeshData identity")


static func _test_warning_budgets_are_explicit_and_non_gating(failures: Array[String]) -> void:
	var descriptor := Budget.descriptor()
	if int(descriptor.get("revision", 0)) <= 0:
		failures.append("runtime performance budget revision is missing")
	if str(descriptor.get("policy", "")) != "warning_only":
		failures.append("PERF-001 budgets must remain warning-only")
	if bool(descriptor.get("timings_affect_determinism", true)):
		failures.append("performance timings are incorrectly declared deterministic")
	var thresholds: Dictionary = descriptor.get("thresholds", {})
	for required_key in [
		"controller_bootstrap_ms",
		"mesh_worker_cell_max_ms",
		"mesh_realization_cell_max_ms",
		"collision_realization_cell_max_ms",
		"mesh_memory_total_bytes",
		"resident_geometry_cells",
		"resident_render_cells",
		"resident_collision_cells",
	]:
		if not thresholds.has(required_key):
			failures.append("missing PERF-001 warning budget: " + required_key)
	var synthetic := {"mesh_worker_cell_max_ms": 999999.0}
	var warnings := Budget.evaluate(synthetic)
	if warnings.is_empty():
		failures.append("runtime performance budget did not warn on synthetic over-budget sample")


static func _test_profiler_contract_is_available(failures: Array[String]) -> void:
	if Profiler == null or not Profiler.has_method("run_map015"):
		failures.append("runtime cave profiler does not expose the MAP-015 profiling entrypoint")
