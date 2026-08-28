extends RefCounted
class_name UnderworldTopologySnapshotBuilder

const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const MacroRegionGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const PrimaryTopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")


static func build(world_seed: int, region_coord: Vector2i) -> Dictionary:
	var context = WorldGenerationContext.new(world_seed)
	var macro_stage = MacroRegionGenerator.generate(context, region_coord)
	if not macro_stage.success:
		return _failure("macro_region", macro_stage.diagnostics)

	var topology_stage = PrimaryTopologyGenerator.generate(context, macro_stage.data)
	if not topology_stage.success:
		return _failure("primary_topology", topology_stage.diagnostics)

	return {
		"success": true,
		"snapshot": _snapshot(world_seed, macro_stage.data, topology_stage.data),
		"macro_fingerprint": macro_stage.fingerprint,
		"topology_fingerprint": topology_stage.fingerprint,
		"diagnostics": [],
	}


static func _snapshot(world_seed: int, region_plan, topology) -> Dictionary:
	var bundle = topology.bundle
	var networks: Array = bundle.networks.duplicate()
	var nodes: Array = bundle.nodes.duplicate()
	var edges: Array = bundle.edges.duplicate()
	networks.sort_custom(_stable_less)
	nodes.sort_custom(_stable_less)
	edges.sort_custom(_stable_less)

	var network_data: Array = []
	for network in networks:
		network_data.append({
			"stable_id": network.stable_id,
			"root_node_id": network.root_node_id,
			"node_ids": _sorted_strings(network.node_ids),
			"primary_edge_ids": _sorted_strings(network.primary_edge_ids),
			"topology_metrics": _json_safe(network.topology_metrics),
		})

	var node_data: Array = []
	for node in nodes:
		node_data.append({
			"stable_id": node.stable_id,
			"owning_network_id": node.owning_network_id,
			"world_position": _vector3(node.world_position),
			"approximate_shape": node.approximate_shape,
			"approximate_size": _vector3(node.approximate_size),
			"profile_blend": _vector3(node.profile_blend),
			"semantic_type": node.semantic_type,
			"tags": _sorted_strings(node.tags),
			"generation_metadata": _json_safe(node.generation_metadata),
		})

	var edge_data: Array = []
	for edge in edges:
		edge_data.append({
			"stable_id": edge.stable_id,
			"endpoint_a_node_id": edge.endpoint_a_node_id,
			"endpoint_b_node_id": edge.endpoint_b_node_id,
			"connection_class": edge.connection_class,
			"topology_parameters": _json_safe(edge.topology_parameters),
			"geometry_tendencies": _json_safe(edge.geometry_tendencies),
			"tags": _sorted_strings(edge.tags),
		})

	var boundary_data: Array = []
	var boundary_candidates: Array = topology.boundary_candidate_metadata.duplicate(true)
	boundary_candidates.sort_custom(_address_less)
	for candidate in boundary_candidates:
		boundary_data.append(_json_safe(candidate))

	return {
		"schema": "underworld-topology-snapshot-v1",
		"world_seed": world_seed,
		"region": {
			"stable_id": bundle.region_definition.stable_id,
			"coord": [region_plan.region_coord.x, region_plan.region_coord.y],
			"world_anchor": _vector3(region_plan.world_anchor),
			"world_bounds": _aabb(region_plan.world_bounds),
			"profile_bias": _vector3(region_plan.profile_bias),
			"topology_tendencies": _json_safe(region_plan.topology_tendencies),
		},
		"macro_fingerprint": "" if region_plan == null else "available-in-build-result",
		"topology_fingerprint": topology.fingerprint,
		"metrics": _json_safe(topology.topology_metrics),
		"networks": network_data,
		"nodes": node_data,
		"edges": edge_data,
		"boundary_candidates": boundary_data,
	}


static func _json_safe(value):
	match typeof(value):
		TYPE_VECTOR2I:
			var v2i: Vector2i = value
			return [v2i.x, v2i.y]
		TYPE_VECTOR3I:
			var v3i: Vector3i = value
			return [v3i.x, v3i.y, v3i.z]
		TYPE_VECTOR2:
			var v2: Vector2 = value
			return [v2.x, v2.y]
		TYPE_VECTOR3:
			return _vector3(value)
		TYPE_AABB:
			return _aabb(value)
		TYPE_ARRAY:
			var array_result: Array = []
			for item in value:
				array_result.append(_json_safe(item))
			return array_result
		TYPE_DICTIONARY:
			var dictionary_result: Dictionary = {}
			var keys: Array[String] = []
			var lookup: Dictionary = {}
			for key in value.keys():
				var text: String = str(key)
				keys.append(text)
				lookup[text] = key
			keys.sort()
			for text in keys:
				dictionary_result[text] = _json_safe(value[lookup[text]])
			return dictionary_result
		_:
			return value


static func _vector3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func _aabb(value: AABB) -> Dictionary:
	return {
		"position": _vector3(value.position),
		"size": _vector3(value.size),
	}


static func _sorted_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	result.sort()
	return result


static func _stable_less(a, b) -> bool:
	return str(a.stable_id) < str(b.stable_id)


static func _address_less(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("address", "")) < str(b.get("address", ""))


static func _failure(stage: String, diagnostics: Array) -> Dictionary:
	return {
		"success": false,
		"stage": stage,
		"diagnostics": diagnostics.duplicate(true),
	}
