extends RefCounted

const Fixture := preload("res://worldgen/validation/map015_fixture.gd")
const WorldContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const SurfaceSampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const MacroGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const TopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")
const EntranceGenerator := preload("res://worldgen/underworld/entrance_generator.gd")
const ConnectivityGenerator := preload("res://worldgen/underworld/secondary_connectivity_generator.gd")
const HookGenerator := preload("res://worldgen/underworld/special_location_hook_generator.gd")
const RegionFinalizer := preload("res://worldgen/underworld/region_finalizer.gd")
const GeometryGenerator := preload("res://worldgen/underworld/cave_geometry_generator.gd")
const PartitionConfig := preload("res://worldgen/geometry/geometry_cell_partition_config.gd")
const PartitionRequest := preload("res://worldgen/geometry/geometry_cell_partition_request.gd")
const Partitioner := preload("res://worldgen/geometry/geometry_cell_partitioner.gd")
const VoxelRequest := preload("res://worldgen/geometry/cave_voxel_field_request.gd")
const LegacyMesher := preload("res://worldgen/geometry/cave_voxel_mesher.gd")
const CachedMesher := preload("res://worldgen/geometry/cave_voxel_mesher_cached.gd")
const CollisionBuilder := preload("res://worldgen/runtime/cave_collision_builder.gd")
const SurfacePlan := preload("res://worldgen/surface/surface_entrance_chunk_plan.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var fixture := _fixture_partition()
	if not bool(fixture.get("success", false)):
		for failure in fixture.get("failures", []):
			failures.append("PERF-002 pinned fixture: " + str(failure))
		return failures

	var partition = fixture["partition"]
	var cell_config = fixture["cell_config"]
	var context = fixture["context"]
	var provenance = partition.provenance
	if partition.data.plans.size() != 8:
		failures.append("PERF-002 pinned fixture must contain exactly 8 geometry cells")
		return failures

	for plan in partition.data.plans:
		var request := VoxelRequest.new(plan, cell_config, provenance, 0.0, partition.data, context)
		var legacy = LegacyMesher.build(request)
		var cached = CachedMesher.build(request)
		var label: String = plan.cell_address.canonical_text()
		if not legacy.success or not cached.success:
			failures.append("%s: old/optimized mesh build did not both succeed" % label)
			continue
		_expect(failures, label + ": vertices differ", legacy.data.vertices == cached.data.vertices)
		_expect(failures, label + ": indices differ", legacy.data.indices == cached.data.indices)
		_expect(failures, label + ": normals differ", legacy.data.normals == cached.data.normals)
		_expect(failures, label + ": UVs differ", legacy.data.uvs == cached.data.uvs)
		_expect(
			failures,
			label + ": output fingerprint differs",
			legacy.data.output_fingerprint == cached.data.output_fingerprint
		)
		_expect(
			failures,
			label + ": CaveMeshData fingerprint differs",
			legacy.data.fingerprint == cached.data.fingerprint
		)
		_expect(
			failures,
			label + ": logical sample semantics differ",
			int(legacy.data.metrics.get("sample_count", -1)) == int(cached.data.metrics.get("sample_count", -2))
		)
		_expect(
			failures,
			label + ": cube ownership differs",
			int(legacy.data.metrics.get("cube_count", -1)) == int(cached.data.metrics.get("cube_count", -2))
		)

		var provenance_fingerprint: String = provenance.fingerprint if provenance != null else ""
		var legacy_collision = CollisionBuilder.prepare(legacy.data, provenance_fingerprint)
		var cached_collision = CollisionBuilder.prepare(cached.data, provenance_fingerprint)
		if not legacy_collision.success or not cached_collision.success:
			failures.append("%s: old/optimized collision preparation did not both succeed" % label)
			continue
		_expect(
			failures,
			label + ": collision faces differ",
			legacy_collision.data.vertices == cached_collision.data.vertices
		)
		_expect(
			failures,
			label + ": collision fingerprint differs",
			legacy_collision.data.fingerprint == cached_collision.data.fingerprint
		)

	if failures.is_empty():
		print("[PERF-002 PARITY] PASS cells=8 exact mesh/collision identity")
	return failures


static func _fixture_partition() -> Dictionary:
	var context = WorldContext.new(Fixture.SEED)
	var sampler = SurfaceSampler.new(Fixture.SEED)
	var macro = MacroGenerator.generate(context, Fixture.REGION)
	if not macro.success:
		return _fail("macro", macro.diagnostics)
	var topology = TopologyGenerator.generate(context, macro.data, sampler)
	if not topology.success:
		return _fail("topology", topology.diagnostics)
	var entrances = EntranceGenerator.generate(context, macro.data, topology.data, sampler)
	if not entrances.success:
		return _fail("entrances", entrances.diagnostics)

	var selected = null
	for descriptor in entrances.data.surface_integration_descriptors:
		if str(descriptor.entrance_id) == Fixture.ENTRANCE_ID:
			selected = descriptor
			break
	if selected == null:
		return _fail("entrances", ["fixture entrance was not found"])

	var neighbor_views: Array = []
	for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var neighbor_macro = MacroGenerator.generate(context, Fixture.REGION + offset)
		if not neighbor_macro.success:
			return _fail("neighbor-macro", neighbor_macro.diagnostics)
		var neighbor_topology = TopologyGenerator.generate(context, neighbor_macro.data, sampler)
		if not neighbor_topology.success:
			return _fail("neighbor-topology", neighbor_topology.diagnostics)
		neighbor_views.append({
			"region_plan": neighbor_macro.data,
			"primary_topology": neighbor_topology.data,
		})

	var connectivity = ConnectivityGenerator.generate(
		context,
		macro.data,
		topology.data,
		entrances.data,
		neighbor_views
	)
	if not connectivity.success:
		return _fail("connectivity", connectivity.diagnostics)
	var hooks = HookGenerator.generate(context, macro.data, connectivity.data)
	if not hooks.success:
		return _fail("hooks", hooks.diagnostics)
	var finalized = RegionFinalizer.generate(context, macro.data, entrances.data, connectivity.data, hooks.data)
	if not finalized.success:
		return _fail("finalization", finalized.diagnostics)
	var geometry = GeometryGenerator.generate(context, macro.data, finalized.data, neighbor_views)
	if not geometry.success:
		return _fail("geometry", geometry.diagnostics)

	var cell_config = PartitionConfig.new()
	var bounds := AABB(selected.surface_world_position - Vector3(32, 32, 32), Vector3(64, 64, 64))
	var surface_result = SurfacePlan.build(
		bounds,
		[selected],
		Vector2i(16, 16),
		entrances.fingerprint,
		cell_config
	)
	if not surface_result.success:
		return _fail("surface-plan", surface_result.diagnostics)
	if surface_result.data.demand_handoffs.is_empty():
		return _fail("surface-plan", ["fixture produced no runtime demand handoff"])
	var handoff = surface_result.data.demand_handoffs[0]
	var expected_geometry_sources = GeometryGenerator.expected_provenance_sources(
		macro.data,
		finalized.data,
		neighbor_views
	)
	var partition_request = PartitionRequest.new(
		geometry.data,
		finalized.data,
		cell_config,
		handoff.cell_addresses,
		context,
		expected_geometry_sources
	)
	var partition = Partitioner.generate(partition_request)
	if not partition.success:
		return _fail("partition", partition.diagnostics)
	return {
		"success": true,
		"partition": partition,
		"cell_config": cell_config,
		"context": context,
	}


static func _fail(stage: String, diagnostics: Array) -> Dictionary:
	var failures: Array[String] = []
	for diagnostic in diagnostics:
		failures.append("%s: %s" % [stage, str(diagnostic)])
	return {"success": false, "failures": failures}


static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
