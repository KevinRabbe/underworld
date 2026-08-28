extends RefCounted
class_name UnderworldGraphCanonicalizer

const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")


static func region_bundle_data(bundle) -> Dictionary:
	if bundle == null or bundle.region_definition == null:
		return {}

	return {
		"region": _region_data(bundle.region_definition),
		"networks": _definitions_data(bundle.networks, _network_data),
		"nodes": _definitions_data(bundle.nodes, _node_data),
		"edges": _definitions_data(bundle.edges, _edge_data),
		"entrances": _definitions_data(bundle.entrances, _entrance_data),
		"special_location_hooks": _definitions_data(
			bundle.special_location_hooks,
			_special_hook_data
		),
	}


static func region_bundle_canonical_text(bundle) -> String:
	return CanonicalValue.encode(region_bundle_data(bundle))


static func region_bundle_fingerprint(bundle) -> String:
	return CanonicalValue.fingerprint(region_bundle_data(bundle))


static func _definitions_data(definitions: Array, converter: Callable) -> Array:
	var ids: Array[String] = []
	var by_id: Dictionary = {}
	for definition in definitions:
		if definition == null:
			continue
		var stable_id: String = str(definition.stable_id)
		if by_id.has(stable_id):
			# Validator reports duplicate identities. Returning an impossible marker
			# prevents an invalid bundle from sharing a valid fingerprint silently.
			stable_id += "#duplicate-%d" % ids.size()
		ids.append(stable_id)
		by_id[stable_id] = definition
	ids.sort()

	var result: Array = []
	for stable_id in ids:
		result.append(converter.call(by_id[stable_id]))
	return result


static func _region_data(region) -> Dictionary:
	return {
		"stable_id": region.stable_id,
		"stable_address": _address_text(region.stable_address),
		"region_coord": region.region_coord,
		"world_anchor": region.world_anchor,
		"world_bounds": region.world_bounds,
		"profile_bias": region.profile_bias,
		"network_ids": _sorted_strings(region.network_ids),
		"entrance_ids": _sorted_strings(region.entrance_ids),
		"secondary_edge_ids": _sorted_strings(region.secondary_edge_ids),
		"special_location_hook_ids": _sorted_strings(region.special_location_hook_ids),
		"topology_metrics": region.topology_metrics,
	}


static func _network_data(network) -> Dictionary:
	return {
		"stable_id": network.stable_id,
		"stable_address": _address_text(network.stable_address),
		"owning_region_id": network.owning_region_id,
		"root_node_id": network.root_node_id,
		"node_ids": _sorted_strings(network.node_ids),
		"primary_edge_ids": _sorted_strings(network.primary_edge_ids),
		"entrance_path_edge_ids": _sorted_strings(network.entrance_path_edge_ids),
		"attached_entrance_ids": _sorted_strings(network.attached_entrance_ids),
		"topology_metrics": network.topology_metrics,
	}


static func _node_data(node) -> Dictionary:
	return {
		"stable_id": node.stable_id,
		"stable_address": _address_text(node.stable_address),
		"owning_network_id": node.owning_network_id,
		"world_position": node.world_position,
		"approximate_shape": node.approximate_shape,
		"approximate_size": node.approximate_size,
		"profile_blend": node.profile_blend,
		"semantic_type": node.semantic_type,
		"tags": _sorted_strings(node.tags),
		"generation_metadata": node.generation_metadata,
	}


static func _edge_data(edge) -> Dictionary:
	return {
		"stable_id": edge.stable_id,
		"stable_address": _address_text(edge.stable_address),
		"endpoint_a_node_id": edge.endpoint_a_node_id,
		"endpoint_b_node_id": edge.endpoint_b_node_id,
		"owning_region_id": edge.owning_region_id,
		"connection_class": edge.connection_class,
		"topology_parameters": edge.topology_parameters,
		"geometry_tendencies": edge.geometry_tendencies,
		"tags": _sorted_strings(edge.tags),
	}


static func _entrance_data(entrance) -> Dictionary:
	return {
		"stable_id": entrance.stable_id,
		"stable_address": _address_text(entrance.stable_address),
		"owning_region_id": entrance.owning_region_id,
		"connected_network_id": entrance.connected_network_id,
		"connected_node_id": entrance.connected_node_id,
		"surface_world_position": entrance.surface_world_position,
		"underground_connection_position": entrance.underground_connection_position,
		"entrance_kind": entrance.entrance_kind,
		"descent_profile": entrance.descent_profile,
		"surface_integration_parameters": entrance.surface_integration_parameters,
		"generation_metadata": entrance.generation_metadata,
	}


static func _special_hook_data(hook) -> Dictionary:
	return {
		"stable_id": hook.stable_id,
		"stable_address": _address_text(hook.stable_address),
		"owning_region_id": hook.owning_region_id,
		"anchor_node_id": hook.anchor_node_id,
		"anchor_edge_id": hook.anchor_edge_id,
		"free_world_anchor": hook.free_world_anchor,
		"semantic_category": hook.semantic_category,
		"reserved_bounds": hook.reserved_bounds,
		"profile_blend": hook.profile_blend,
		"generation_metadata": hook.generation_metadata,
	}


static func _sorted_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	result.sort()
	return result


static func _address_text(address) -> String:
	return address.canonical_text() if address != null else ""
