extends RefCounted

const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")
const Fragment := preload("res://worldgen/geometry/geometry_cell_fragment.gd")
const Plan := preload("res://worldgen/geometry/geometry_cell_plan.gd")
const Config := preload("res://worldgen/geometry/geometry_cell_partition_config.gd")
const Request := preload("res://worldgen/geometry/cave_voxel_field_request.gd")
const LegacyMesher := preload("res://worldgen/geometry/cave_voxel_mesher.gd")
const CachedMesher := preload("res://worldgen/geometry/cave_voxel_mesher_cached.gd")
const Context := preload("res://worldgen/pipeline/world_generation_context.gd")
const PartitionResult := preload("res://worldgen/geometry/geometry_cell_partition_result.gd")
const MeshData := preload("res://worldgen/geometry/cave_mesh_data.gd")
const Budget := preload("res://worldgen/runtime/runtime_performance_budget.gd")
const Profiler := preload("res://worldgen/runtime/runtime_cave_profiler.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_observational_timings_do_not_change_mesh_identity(failures)
	_test_cached_mesher_reproduces_legacy_buffers(failures)
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


static func _test_cached_mesher_reproduces_legacy_buffers(failures: Array[String]) -> void:
	# Small deterministic cell: enough surface to exercise masks/interpolation and
	# edge reuse without doubling the production MAP-015 profiling cost.
	var configuration := Config.new(Vector3(8.0, 8.0, 8.0), 1.0, 8, 1)
	var address := Address.new(Vector3i(-1, 0, 1))
	var cell := AABB(Vector3(-8.0, 0.0, 8.0), Vector3(8.0, 8.0, 8.0))
	var clipped := AABB(Vector3(-7.0, 1.0, 9.0), Vector3(6.0, 6.0, 6.0))
	var metadata := {
		"center": clipped.get_center(),
		"dimensions": Vector3(6.0, 5.0, 6.0),
		"shape_family": "ellipsoid",
		"rotation_y": 0.0,
		"floor_bias": 0.45,
		"wall_roughness": 0.35,
	}
	var fragment := Fragment.new(
		"gfrag1:perf002-equivalence",
		"stable:perf002-equivalence",
		"chamber",
		address,
		cell,
		clipped,
		true,
		{},
		{},
		"source:perf002-equivalence",
		metadata
	)
	var plan := Plan.new(address, [fragment], [], [], "geometry:perf002", "finalization:perf002")
	var context := Context.new(811)
	var provenance = context.make_provenance(
		"geometry_cell_partition",
		"region:perf002",
		"address:perf002",
		["plan-source:perf002"]
	)
	var partition := PartitionResult.new(
		[plan],
		configuration.fingerprint,
		plan.source_geometry_fingerprint,
		plan.source_finalization_fingerprint,
		{},
		[],
		provenance
	)
	var request := Request.new(plan, configuration, provenance, 0.0, partition, context)
	var legacy = LegacyMesher.build(request)
	var cached = CachedMesher.build(request)
	if not legacy.success:
		failures.append("PERF-002 legacy equivalence fixture failed to build")
		return
	if not cached.success:
		failures.append("PERF-002 cached equivalence fixture failed to build: %s" % [cached.diagnostics])
		return
	if cached.data.vertices != legacy.data.vertices:
		failures.append("PERF-002 scalar reuse changed mesh vertices")
	if cached.data.indices != legacy.data.indices:
		failures.append("PERF-002 scalar reuse changed mesh indices")
	if cached.data.normals != legacy.data.normals:
		failures.append("PERF-002 scalar reuse changed mesh normals")
	if cached.data.uvs != legacy.data.uvs:
		failures.append("PERF-002 scalar reuse changed mesh UVs")
	if cached.data.output_fingerprint != legacy.data.output_fingerprint:
		failures.append("PERF-002 scalar reuse changed mesh output fingerprint")
	if cached.data.fingerprint != legacy.data.fingerprint:
		failures.append("PERF-002 scalar reuse changed CaveMeshData fingerprint")
	if cached.data.metrics.get("sample_count") != legacy.data.metrics.get("sample_count"):
		failures.append("PERF-002 scalar reuse changed accepted logical sample-count semantics")


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
		"mesh_extraction_cell_max_ms",
		"mesh_realization_cell_max_ms",
		"collision_realization_cell_max_ms",
		"mesh_memory_total_bytes",
		"resident_geometry_cells",
		"resident_render_cells",
		"resident_collision_cells",
	]:
		if not thresholds.has(required_key):
			failures.append("missing PERF-001 warning budget: " + required_key)
	var semantics: Dictionary = descriptor.get("measurement_semantics", {})
	if not str(semantics.get("mesh_extraction", "")).contains("excludes production executor"):
		failures.append("PERF-001 descriptor does not distinguish staged extraction from production worker scheduling")
	if not str(semantics.get("controller_route_observer_update", "")).contains("demand/gate update"):
		failures.append("PERF-001 descriptor misstates controller-route observer measurements")
	var synthetic := {"mesh_extraction_cell_max_ms": 999999.0}
	var warnings := Budget.evaluate(synthetic)
	if warnings.is_empty():
		failures.append("runtime performance budget did not warn on synthetic over-budget sample")


static func _test_profiler_contract_is_available(failures: Array[String]) -> void:
	if Profiler == null:
		failures.append("runtime cave profiler script failed to load")
