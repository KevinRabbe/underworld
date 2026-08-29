extends RefCounted

const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const SurfaceSampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const MacroRegionGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const PrimaryTopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")
const EntranceGenerator := preload("res://worldgen/underworld/entrance_generator.gd")
const ConnectivityGenerator := preload("res://worldgen/underworld/secondary_connectivity_generator.gd")
const GraphValidator := preload("res://worldgen/validation/graph_validator.gd")

const MAX_SEED_SEARCH: int = 256


static func run() -> Array[String]:
	var failures: Array[String] = []
	var coord_a := Vector2i(0, 0)
	var coord_b := Vector2i(1, 0)
	var seed: int = _find_cross_region_seed(coord_a, coord_b, failures)
	if seed < 0:
		return failures

	_test_valid_generated_pair(seed, coord_a, coord_b, failures)
	_test_owner_two_local_endpoints(seed, coord_a, coord_b, failures)
	_test_owner_two_external_endpoints(seed, coord_a, coord_b, failures)
	_test_reference_requires_local_endpoint(seed, coord_a, coord_b, failures)
	_test_reference_remote_owner_identity(seed, coord_a, coord_b, failures)
	_test_reference_edge_identity(seed, coord_a, coord_b, failures)
	_test_reference_remote_endpoint_is_external(seed, coord_a, coord_b, failures)
	_test_negative_region_pair(failures)
	return failures


static func _test_valid_generated_pair(
	seed: int,
	coord_a: Vector2i,
	coord_b: Vector2i,
	failures: Array[String]
) -> void:
	var pair: Dictionary = _build_pair(seed, coord_a, coord_b)
	if not _expect_pair(failures, "valid generated pair", pair):
		return
	var owner = _owner_result(pair)
	var external = _external_result(pair)
	_expect_empty(
		failures,
		"valid owner bundle passes graph validation",
		GraphValidator.validate_region_bundle(owner.bundle)
	)
	_expect_empty(
		failures,
		"valid non-owner bundle passes graph validation",
		GraphValidator.validate_region_bundle(external.bundle)
	)
	_expect_empty(
		failures,
		"valid external reference passes structural validation",
		GraphValidator.validate_external_edge_references(
			external.bundle,
			external.external_edge_references
		)
	)


static func _test_owner_two_local_endpoints(
	seed: int,
	coord_a: Vector2i,
	coord_b: Vector2i,
	failures: Array[String]
) -> void:
	var pair: Dictionary = _build_pair(seed, coord_a, coord_b)
	if not _expect_pair(failures, "two-local fixture", pair):
		return
	var owner = _owner_result(pair)
	var edge = _owned_cross_edge(owner)
	if edge == null:
		failures.append("two-local fixture has no owned cross-region edge")
		return
	var local_ids := _sorted_node_ids(owner.bundle.nodes)
	if local_ids.size() < 2:
		failures.append("two-local fixture needs at least two local nodes")
		return
	edge.endpoint_a_node_id = local_ids[0]
	edge.endpoint_b_node_id = local_ids[1]
	_expect_failure_contains(
		failures,
		"two local endpoints rejected",
		GraphValidator.validate_region_bundle(owner.bundle),
		"Cross-region edge must have exactly one local endpoint"
	)


static func _test_owner_two_external_endpoints(
	seed: int,
	coord_a: Vector2i,
	coord_b: Vector2i,
	failures: Array[String]
) -> void:
	var pair: Dictionary = _build_pair(seed, coord_a, coord_b)
	if not _expect_pair(failures, "two-external fixture", pair):
		return
	var owner = _owner_result(pair)
	var edge = _owned_cross_edge(owner)
	if edge == null:
		failures.append("two-external fixture has no owned cross-region edge")
		return
	edge.endpoint_a_node_id = "000-external-node-a"
	edge.endpoint_b_node_id = "zzz-external-node-b"
	_expect_failure_contains(
		failures,
		"two external endpoints rejected",
		GraphValidator.validate_region_bundle(owner.bundle),
		"Cross-region edge must have exactly one local endpoint"
	)


static func _test_reference_requires_local_endpoint(
	seed: int,
	coord_a: Vector2i,
	coord_b: Vector2i,
	failures: Array[String]
) -> void:
	var pair: Dictionary = _build_pair(seed, coord_a, coord_b)
	if not _expect_pair(failures, "missing-local-reference fixture", pair):
		return
	var external = _external_result(pair)
	var reference = external.external_edge_references[0]
	reference.local_endpoint_node_id = "missing-local-endpoint"
	_expect_failure_contains(
		failures,
		"external reference requires real local endpoint",
		GraphValidator.validate_external_edge_references(
			external.bundle,
			external.external_edge_references
		),
		"External edge reference local endpoint is missing"
	)


static func _test_reference_remote_owner_identity(
	seed: int,
	coord_a: Vector2i,
	coord_b: Vector2i,
	failures: Array[String]
) -> void:
	var pair: Dictionary = _build_pair(seed, coord_a, coord_b)
	if not _expect_pair(failures, "remote-owner fixture", pair):
		return
	var external = _external_result(pair)
	var reference = external.external_edge_references[0]
	reference.remote_region_id = reference.local_region_id
	_expect_failure_contains(
		failures,
		"remote region must match reference owner",
		GraphValidator.validate_external_edge_references(
			external.bundle,
			external.external_edge_references
		),
		"External edge reference remote region must match owner region"
	)


static func _test_reference_edge_identity(
	seed: int,
	coord_a: Vector2i,
	coord_b: Vector2i,
	failures: Array[String]
) -> void:
	var pair: Dictionary = _build_pair(seed, coord_a, coord_b)
	if not _expect_pair(failures, "edge-identity fixture", pair):
		return
	var external = _external_result(pair)
	var reference = external.external_edge_references[0]
	reference.edge_stable_id = "mismatched-edge-id"
	_expect_failure_contains(
		failures,
		"external reference edge identity is canonical",
		GraphValidator.validate_external_edge_references(
			external.bundle,
			external.external_edge_references
		),
		"External edge reference StableId does not match StableAddress"
	)


static func _test_reference_remote_endpoint_is_external(
	seed: int,
	coord_a: Vector2i,
	coord_b: Vector2i,
	failures: Array[String]
) -> void:
	var pair: Dictionary = _build_pair(seed, coord_a, coord_b)
	if not _expect_pair(failures, "remote-endpoint fixture", pair):
		return
	var external = _external_result(pair)
	var reference = external.external_edge_references[0]
	var local_ids := _sorted_node_ids(external.bundle.nodes)
	if local_ids.size() < 2:
		failures.append("remote-endpoint fixture needs at least two local nodes")
		return
	reference.remote_endpoint_node_id = (
		local_ids[1]
		if local_ids[0] == reference.local_endpoint_node_id
		else local_ids[0]
	)
	_expect_failure_contains(
		failures,
		"external reference remote endpoint cannot resolve locally",
		GraphValidator.validate_external_edge_references(
			external.bundle,
			external.external_edge_references
		),
		"External edge reference remote endpoint resolves locally"
	)


static func _test_negative_region_pair(failures: Array[String]) -> void:
	var coord_a := Vector2i(-5, -4)
	var coord_b := Vector2i(-4, -4)
	var seed: int = _find_cross_region_seed(coord_a, coord_b, failures)
	if seed < 0:
		return
	var pair: Dictionary = _build_pair(seed, coord_a, coord_b)
	if not _expect_pair(failures, "negative cross-region fixture", pair):
		return
	var owner = _owner_result(pair)
	var external = _external_result(pair)
	_expect_empty(
		failures,
		"negative owner bundle passes",
		GraphValidator.validate_region_bundle(owner.bundle)
	)
	_expect_empty(
		failures,
		"negative external reference passes",
		GraphValidator.validate_external_edge_references(
			external.bundle,
			external.external_edge_references
		)
	)


static func _find_cross_region_seed(
	coord_a: Vector2i,
	coord_b: Vector2i,
	failures: Array[String]
) -> int:
	for seed in range(1, MAX_SEED_SEARCH + 1):
		var pair: Dictionary = _build_pair(seed, coord_a, coord_b)
		if not bool(pair.get("success", false)):
			failures.append(
				"cross-region seed search failed seed=%d coords=%s/%s diagnostics=%s" % [
					seed,
					str(coord_a),
					str(coord_b),
					str(pair.get("diagnostics", [])),
				]
			)
			return -1
		if _pair_has_cross_region_connection(pair):
			return seed
	failures.append(
		"no cross-region connector found in seeds 1..%d coords=%s/%s" % [
			MAX_SEED_SEARCH,
			str(coord_a),
			str(coord_b),
		]
	)
	return -1


static func _build_pair(seed: int, coord_a: Vector2i, coord_b: Vector2i) -> Dictionary:
	var context = WorldGenerationContext.new(seed)
	var sampler = SurfaceSampler.new(seed)
	var a: Dictionary = _build_region(context, sampler, coord_a)
	if not bool(a.get("success", false)):
		return a
	var b: Dictionary = _build_region(context, sampler, coord_b)
	if not bool(b.get("success", false)):
		return b
	var result_a = ConnectivityGenerator.generate(
		context,
		a["macro"],
		a["topology"],
		a["entrances"],
		[{"region_plan": b["macro"], "primary_topology": b["topology"]}]
	)
	if not result_a.success:
		return {"success": false, "diagnostics": result_a.diagnostics}
	var result_b = ConnectivityGenerator.generate(
		context,
		b["macro"],
		b["topology"],
		b["entrances"],
		[{"region_plan": a["macro"], "primary_topology": a["topology"]}]
	)
	if not result_b.success:
		return {"success": false, "diagnostics": result_b.diagnostics}
	return {
		"success": true,
		"result_a": result_a.data,
		"result_b": result_b.data,
		"diagnostics": [],
	}


static func _build_region(context, sampler, coord: Vector2i) -> Dictionary:
	var macro_stage = MacroRegionGenerator.generate(context, coord)
	if not macro_stage.success:
		return {
			"success": false,
			"stage": "macro_region",
			"diagnostics": macro_stage.diagnostics,
		}
	var topology_stage = PrimaryTopologyGenerator.generate(
		context,
		macro_stage.data,
		sampler
	)
	if not topology_stage.success:
		return {
			"success": false,
			"stage": "primary_topology",
			"diagnostics": topology_stage.diagnostics,
		}
	var entrance_stage = EntranceGenerator.generate(
		context,
		macro_stage.data,
		topology_stage.data,
		sampler
	)
	if not entrance_stage.success:
		return {
			"success": false,
			"stage": "entrance_generation",
			"diagnostics": entrance_stage.diagnostics,
		}
	return {
		"success": true,
		"macro": macro_stage.data,
		"topology": topology_stage.data,
		"entrances": entrance_stage.data,
		"diagnostics": [],
	}


static func _pair_has_cross_region_connection(pair: Dictionary) -> bool:
	var a = pair["result_a"]
	var b = pair["result_b"]
	return (
		(_has_owned_cross_edge(a) and not b.external_edge_references.is_empty())
		or (_has_owned_cross_edge(b) and not a.external_edge_references.is_empty())
	)


static func _owner_result(pair: Dictionary):
	return pair["result_a"] if _has_owned_cross_edge(pair["result_a"]) else pair["result_b"]


static func _external_result(pair: Dictionary):
	return (
		pair["result_a"]
		if not pair["result_a"].external_edge_references.is_empty()
		else pair["result_b"]
	)


static func _has_owned_cross_edge(result) -> bool:
	return _owned_cross_edge(result) != null


static func _owned_cross_edge(result):
	for edge_id in result.bundle.region_definition.secondary_edge_ids:
		for edge in result.bundle.edges:
			if edge.stable_id == edge_id and edge.connection_class == "cross_region_connection":
				return edge
	return null


static func _sorted_node_ids(nodes: Array) -> Array[String]:
	var result: Array[String] = []
	for node in nodes:
		if node != null:
			result.append(str(node.stable_id))
	result.sort()
	return result


static func _expect_pair(
	failures: Array[String],
	label: String,
	pair: Dictionary
) -> bool:
	if bool(pair.get("success", false)):
		return true
	failures.append("%s failed: %s" % [label, str(pair.get("diagnostics", []))])
	return false


static func _expect_empty(
	failures: Array[String],
	label: String,
	actual: Array[String]
) -> void:
	if not actual.is_empty():
		failures.append("%s expected no failures actual=%s" % [label, str(actual)])


static func _expect_failure_contains(
	failures: Array[String],
	label: String,
	actual: Array[String],
	needle: String
) -> void:
	for failure in actual:
		if needle in failure:
			return
	failures.append("%s missing diagnostic '%s' actual=%s" % [label, needle, str(actual)])
