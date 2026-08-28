extends RefCounted

const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const SurfaceSampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const MacroRegionGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const PrimaryTopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")
const EntranceGenerator := preload("res://worldgen/underworld/entrance_generator.gd")
const ConnectivityGenerator := preload("res://worldgen/underworld/secondary_connectivity_generator.gd")
const RegionGraphBundle := preload("res://worldgen/graph/region_graph_bundle.gd")
const GraphCanonicalizer := preload("res://worldgen/validation/graph_canonicalizer.gd")
const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")

const FIXTURE_SEED: int = 24681357
const FIXTURE_COORD := Vector2i(-2, -3)


static func run(failures: Array[String]) -> void:
	_test_graph_collection_permutations(failures)
	_test_neighbor_and_external_reference_order(failures)
	_test_logical_content_changes_fingerprint(failures)


static func _test_graph_collection_permutations(failures: Array[String]) -> void:
	var built := _build(FIXTURE_SEED, FIXTURE_COORD, false)
	if not _require_build(built, "canonical graph fixture", failures):
		return
	var bundle = built["result"].bundle
	var source_before := _raw_order_snapshot(bundle)
	var canonical_text := GraphCanonicalizer.region_bundle_canonical_text(bundle)
	var fingerprint := GraphCanonicalizer.region_bundle_fingerprint(bundle)
	_expect_true(failures, "canonical text is non-empty", not canonical_text.is_empty())
	_expect_true(failures, "canonical fingerprint is non-empty", not fingerprint.is_empty())

	var permuted = RegionGraphBundle.new(
		bundle.region_definition,
		_reversed(bundle.networks),
		_reversed(bundle.nodes),
		_reversed(bundle.edges),
		_reversed(bundle.entrances),
		_reversed(bundle.special_location_hooks)
	)
	_expect_equal(
		failures,
		"permuted graph has byte-identical canonical text",
		GraphCanonicalizer.region_bundle_canonical_text(permuted),
		canonical_text
	)
	_expect_equal(
		failures,
		"permuted graph has identical fingerprint",
		GraphCanonicalizer.region_bundle_fingerprint(permuted),
		fingerprint
	)
	_expect_equal(
		failures,
		"canonicalization does not mutate source fixture",
		_raw_order_snapshot(bundle),
		source_before
	)
	_expect_equal(
		failures,
		"negative region coordinate preserved",
		bundle.region_definition.region_coord,
		FIXTURE_COORD
	)


static func _test_neighbor_and_external_reference_order(failures: Array[String]) -> void:
	var normal := _build(FIXTURE_SEED, FIXTURE_COORD, false)
	if not _require_build(normal, "normal neighbor-order fixture", failures):
		return
	var reversed := _build(FIXTURE_SEED, FIXTURE_COORD, true)
	if not _require_build(reversed, "reversed neighbor-order fixture", failures):
		return
	_expect_equal(
		failures,
		"neighbor insertion order cannot change Stage-4 fingerprint",
		reversed["stage_fingerprint"],
		normal["stage_fingerprint"]
	)
	_expect_equal(
		failures,
		"neighbor insertion order cannot change external-reference sequence",
		_external_reference_snapshot(reversed["result"].external_edge_references),
		_external_reference_snapshot(normal["result"].external_edge_references)
	)
	_expect_equal(
		failures,
		"neighbor insertion order cannot change local graph canonical text",
		GraphCanonicalizer.region_bundle_canonical_text(reversed["result"].bundle),
		GraphCanonicalizer.region_bundle_canonical_text(normal["result"].bundle)
	)

	var references: Array = normal["result"].external_edge_references
	var references_before := _external_reference_snapshot(references)
	var reverse_refs := references.duplicate()
	reverse_refs.reverse()
	_expect_equal(
		failures,
		"external-reference canonical envelope ignores insertion order",
		_canonical_external_reference_text(reverse_refs),
		_canonical_external_reference_text(references)
	)
	_expect_equal(
		failures,
		"external-reference canonicalization does not mutate source list",
		_external_reference_snapshot(references),
		references_before
	)


static func _test_logical_content_changes_fingerprint(failures: Array[String]) -> void:
	var baseline := _build(FIXTURE_SEED, FIXTURE_COORD, false)
	var changed := _build(FIXTURE_SEED + 1, FIXTURE_COORD, false)
	if not _require_build(baseline, "baseline content fixture", failures):
		return
	if not _require_build(changed, "changed content fixture", failures):
		return
	var baseline_fp := GraphCanonicalizer.region_bundle_fingerprint(baseline["result"].bundle)
	var changed_fp := GraphCanonicalizer.region_bundle_fingerprint(changed["result"].bundle)
	_expect_true(
		failures,
		"different logical generated graph changes fingerprint",
		baseline_fp != changed_fp
	)


static func _build(seed: int, coord: Vector2i, reverse_neighbors: bool) -> Dictionary:
	var context = WorldGenerationContext.new(seed)
	var sampler = SurfaceSampler.new(seed)
	var macro = MacroRegionGenerator.generate(context, coord)
	if not macro.success:
		return _failure("macro_region", macro.diagnostics)
	var topology = PrimaryTopologyGenerator.generate(context, macro.data, sampler)
	if not topology.success:
		return _failure("primary_topology", topology.diagnostics)
	var entrances = EntranceGenerator.generate(context, macro.data, topology.data, sampler)
	if not entrances.success:
		return _failure("entrance_generation", entrances.diagnostics)

	var offsets: Array[Vector2i] = [
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(0, -1),
		Vector2i(0, 1),
	]
	if reverse_neighbors:
		offsets.reverse()
	var neighbor_views: Array = []
	for offset in offsets:
		var neighbor_macro = MacroRegionGenerator.generate(context, coord + offset)
		if not neighbor_macro.success:
			return _failure("neighbor_macro_region", neighbor_macro.diagnostics)
		var neighbor_topology = PrimaryTopologyGenerator.generate(
			context,
			neighbor_macro.data,
			sampler
		)
		if not neighbor_topology.success:
			return _failure("neighbor_primary_topology", neighbor_topology.diagnostics)
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
		return _failure("secondary_connectivity", connectivity.diagnostics)
	return {
		"success": true,
		"result": connectivity.data,
		"stage_fingerprint": connectivity.fingerprint,
		"diagnostics": [],
	}


static func _raw_order_snapshot(bundle) -> String:
	var data := {
		"region_network_ids": bundle.region_definition.network_ids.duplicate(),
		"region_entrance_ids": bundle.region_definition.entrance_ids.duplicate(),
		"region_secondary_edge_ids": bundle.region_definition.secondary_edge_ids.duplicate(),
		"networks": [],
		"nodes": [],
		"edges": [],
		"entrances": [],
		"hooks": [],
	}
	for network in bundle.networks:
		data["networks"].append({
			"id": network.stable_id,
			"node_ids": network.node_ids.duplicate(),
			"primary_edge_ids": network.primary_edge_ids.duplicate(),
			"entrance_path_edge_ids": network.entrance_path_edge_ids.duplicate(),
			"attached_entrance_ids": network.attached_entrance_ids.duplicate(),
		})
	for node in bundle.nodes:
		data["nodes"].append({
			"id": node.stable_id,
			"tags": node.tags.duplicate(),
			"metadata": node.generation_metadata.duplicate(true),
		})
	for edge in bundle.edges:
		data["edges"].append({
			"id": edge.stable_id,
			"tags": edge.tags.duplicate(),
			"topology": edge.topology_parameters.duplicate(true),
			"geometry": edge.geometry_tendencies.duplicate(true),
		})
	for entrance in bundle.entrances:
		data["entrances"].append({
			"id": entrance.stable_id,
			"surface": entrance.surface_integration_parameters.duplicate(true),
			"metadata": entrance.generation_metadata.duplicate(true),
		})
	for hook in bundle.special_location_hooks:
		data["hooks"].append({"id": hook.stable_id, "metadata": hook.generation_metadata.duplicate(true)})
	return CanonicalValue.encode(data)


static func _external_reference_snapshot(references: Array) -> Array[String]:
	var result: Array[String] = []
	for reference in references:
		result.append(CanonicalValue.encode(reference.canonical_data()))
	return result


static func _canonical_external_reference_text(references: Array) -> String:
	var rows: Array = []
	for reference in references:
		rows.append(reference.canonical_data())
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("edge_stable_id", "")) < str(b.get("edge_stable_id", ""))
	)
	return CanonicalValue.encode(rows)


static func _reversed(values: Array) -> Array:
	var result := values.duplicate()
	result.reverse()
	return result


static func _failure(stage: String, diagnostics: Array) -> Dictionary:
	return {"success": false, "stage": stage, "diagnostics": diagnostics}


static func _require_build(built: Dictionary, label: String, failures: Array[String]) -> bool:
	if bool(built.get("success", false)):
		return true
	failures.append("%s failed stage=%s diagnostics=%s" % [
		label,
		str(built.get("stage", "unknown")),
		str(built.get("diagnostics", [])),
	])
	return false


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s expected=%s actual=%s" % [label, str(expected), str(actual)])
