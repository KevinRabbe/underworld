extends RefCounted
class_name UnderworldGraphValidator

const StableId := preload("res://worldgen/identity/stable_id.gd")

const PROFILE_EPSILON: float = 0.001


static func validate_region_bundle(bundle) -> Array[String]:
	var failures: Array[String] = []
	if bundle == null:
		return ["Region graph bundle is null"]
	if bundle.region_definition == null:
		return ["Region graph bundle has no region definition"]

	var region = bundle.region_definition
	_validate_identity(region, "region", failures)
	_validate_profile(region.profile_bias, "region profile_bias", failures)
	_validate_vector3(region.world_anchor, "region world_anchor", failures)
	_validate_aabb(region.world_bounds, "region world_bounds", failures)

	var networks: Dictionary = _index_definitions(bundle.networks, "network", failures)
	var nodes: Dictionary = _index_definitions(bundle.nodes, "node", failures)
	var edges: Dictionary = _index_definitions(bundle.edges, "edge", failures)
	var entrances: Dictionary = _index_definitions(bundle.entrances, "entrance", failures)
	var hooks: Dictionary = _index_definitions(
		bundle.special_location_hooks,
		"special_location_hook",
		failures
	)

	_validate_region_membership_lists(region, networks, edges, entrances, hooks, failures)
	_validate_networks(region, networks, nodes, edges, entrances, failures)
	_validate_nodes(networks, nodes, failures)
	_validate_edges(region, nodes, edges, failures)
	_validate_entrances(region, networks, nodes, edges, entrances, failures)
	_validate_hooks(region, nodes, edges, hooks, failures)
	_validate_global_identity_uniqueness(region, networks, nodes, edges, entrances, hooks, failures)

	return failures


static func _index_definitions(
	definitions: Array,
	label: String,
	failures: Array[String]
) -> Dictionary:
	var result: Dictionary = {}
	for definition in definitions:
		if definition == null:
			failures.append("Null %s definition" % label)
			continue
		_validate_identity(definition, label, failures)
		var stable_id: String = str(definition.stable_id)
		if stable_id.is_empty():
			continue
		if result.has(stable_id):
			failures.append("Duplicate %s StableId: %s" % [label, stable_id])
			continue
		result[stable_id] = definition
	return result


static func _validate_identity(definition, label: String, failures: Array[String]) -> void:
	if definition.stable_address == null:
		failures.append("%s has null StableAddress" % label)
		return
	var expected = StableId.from_address(definition.stable_address)
	if expected == null:
		failures.append("%s has invalid StableAddress" % label)
		return
	if str(definition.stable_id) != expected.value():
		failures.append(
			"%s StableId does not match StableAddress: %s" % [label, str(definition.stable_id)]
		)


static func _validate_region_membership_lists(
	region,
	networks: Dictionary,
	edges: Dictionary,
	entrances: Dictionary,
	hooks: Dictionary,
	failures: Array[String]
) -> void:
	_validate_unique_strings(region.network_ids, "region network_ids", failures)
	_validate_unique_strings(region.entrance_ids, "region entrance_ids", failures)
	_validate_unique_strings(region.secondary_edge_ids, "region secondary_edge_ids", failures)
	_validate_unique_strings(
		region.special_location_hook_ids,
		"region special_location_hook_ids",
		failures
	)

	_validate_exact_id_set(region.network_ids, networks, "region network", failures)
	_validate_exact_id_set(region.entrance_ids, entrances, "region entrance", failures)
	_validate_exact_id_set(
		region.special_location_hook_ids,
		hooks,
		"region special-location hook",
		failures
	)

	for edge_id in region.secondary_edge_ids:
		if not edges.has(edge_id):
			failures.append("Region references missing secondary edge: " + edge_id)
			continue
		if edges[edge_id].connection_class == "primary":
			failures.append("Region secondary_edge_ids contains primary edge: " + edge_id)


static func _validate_networks(
	region,
	networks: Dictionary,
	nodes: Dictionary,
	edges: Dictionary,
	entrances: Dictionary,
	failures: Array[String]
) -> void:
	for network_id in networks.keys():
		var network = networks[network_id]
		if network.owning_region_id != region.stable_id:
			failures.append("Network has wrong owning region: " + network_id)

		_validate_unique_strings(network.node_ids, "network node_ids " + network_id, failures)
		_validate_unique_strings(
			network.primary_edge_ids,
			"network primary_edge_ids " + network_id,
			failures
		)
		_validate_unique_strings(
			network.entrance_path_edge_ids,
			"network entrance_path_edge_ids " + network_id,
			failures
		)
		_validate_unique_strings(
			network.attached_entrance_ids,
			"network attached_entrance_ids " + network_id,
			failures
		)

		if not nodes.has(network.root_node_id):
			failures.append("Network root node is missing: " + network_id)
		elif nodes[network.root_node_id].owning_network_id != network_id:
			failures.append("Network root node belongs to another network: " + network_id)

		for node_id in network.node_ids:
			if not nodes.has(node_id):
				failures.append("Network references missing node: " + node_id)
			elif nodes[node_id].owning_network_id != network_id:
				failures.append("Network references node owned by another network: " + node_id)

		for edge_id in network.primary_edge_ids:
			if not edges.has(edge_id):
				failures.append("Network references missing primary edge: " + edge_id)
				continue
			var edge = edges[edge_id]
			if edge.connection_class != "primary" and edge.connection_class != "vertical_transition":
				failures.append("Network primary edge list contains non-primary edge: " + edge_id)
			if nodes.has(edge.endpoint_a_node_id) and nodes[edge.endpoint_a_node_id].owning_network_id != network_id:
				failures.append("Primary edge endpoint A belongs to another network: " + edge_id)
			if nodes.has(edge.endpoint_b_node_id) and nodes[edge.endpoint_b_node_id].owning_network_id != network_id:
				failures.append("Primary edge endpoint B belongs to another network: " + edge_id)

		for edge_id in network.entrance_path_edge_ids:
			if not edges.has(edge_id):
				failures.append("Network references missing entrance-path edge: " + edge_id)
				continue
			var path_edge = edges[edge_id]
			if path_edge.connection_class != "entrance_path":
				failures.append("Network entrance path list contains wrong edge class: " + edge_id)
			if nodes.has(path_edge.endpoint_a_node_id) and nodes[path_edge.endpoint_a_node_id].owning_network_id != network_id:
				failures.append("Entrance path endpoint A belongs to another network: " + edge_id)
			if nodes.has(path_edge.endpoint_b_node_id) and nodes[path_edge.endpoint_b_node_id].owning_network_id != network_id:
				failures.append("Entrance path endpoint B belongs to another network: " + edge_id)

		for entrance_id in network.attached_entrance_ids:
			if not entrances.has(entrance_id):
				failures.append("Network references missing entrance: " + entrance_id)
			elif entrances[entrance_id].connected_network_id != network_id:
				failures.append("Network references entrance attached elsewhere: " + entrance_id)

		_validate_primary_connectivity(network, nodes, edges, failures)


static func _validate_primary_connectivity(
	network,
	nodes: Dictionary,
	edges: Dictionary,
	failures: Array[String]
) -> void:
	if not nodes.has(network.root_node_id):
		return

	var adjacency: Dictionary = {}
	for node_id in network.node_ids:
		adjacency[node_id] = []
	var endpoint_pairs: Dictionary = {}
	var connectivity_edge_ids: Array = network.primary_edge_ids.duplicate()
	connectivity_edge_ids.append_array(network.entrance_path_edge_ids)
	for edge_id in connectivity_edge_ids:
		if not edges.has(edge_id):
			continue
		var edge = edges[edge_id]
		if not adjacency.has(edge.endpoint_a_node_id) or not adjacency.has(edge.endpoint_b_node_id):
			continue
		var pair_key: String = edge.endpoint_a_node_id + "\n" + edge.endpoint_b_node_id
		if endpoint_pairs.has(pair_key):
			failures.append(
				"Network has duplicate undirected edge endpoints: %s" % network.stable_id
			)
		else:
			endpoint_pairs[pair_key] = true
		adjacency[edge.endpoint_a_node_id].append(edge.endpoint_b_node_id)
		adjacency[edge.endpoint_b_node_id].append(edge.endpoint_a_node_id)

	var reached: Dictionary = {network.root_node_id: true}
	var pending: Array[String] = [network.root_node_id]
	while not pending.is_empty():
		var current: String = pending.pop_front()
		for neighbor_variant in adjacency.get(current, []):
			var neighbor: String = str(neighbor_variant)
			if reached.has(neighbor):
				continue
			reached[neighbor] = true
			pending.append(neighbor)

	if reached.size() != network.node_ids.size():
		failures.append(
			"Network is disconnected: %s reached=%d nodes=%d" % [
				network.stable_id,
				reached.size(),
				network.node_ids.size(),
			]
		)


static func _validate_nodes(
	networks: Dictionary,
	nodes: Dictionary,
	failures: Array[String]
) -> void:
	for node_id in nodes.keys():
		var node = nodes[node_id]
		if not networks.has(node.owning_network_id):
			failures.append("Node references missing owning network: " + node_id)
		else:
			var network = networks[node.owning_network_id]
			if not network.node_ids.has(node_id):
				failures.append("Owning network omits node from node_ids: " + node_id)

		_validate_vector3(node.world_position, "node world_position " + node_id, failures)
		_validate_vector3(node.approximate_size, "node approximate_size " + node_id, failures)
		if node.approximate_size.x <= 0.0 or node.approximate_size.y <= 0.0 or node.approximate_size.z <= 0.0:
			failures.append("Node has non-positive approximate_size: " + node_id)
		_validate_profile(node.profile_blend, "node profile_blend " + node_id, failures)
		if node.approximate_shape.is_empty():
			failures.append("Node has empty approximate_shape: " + node_id)
		if node.semantic_type.is_empty():
			failures.append("Node has empty semantic_type: " + node_id)
		_validate_unique_strings(node.tags, "node tags " + node_id, failures)


static func _validate_edges(
	region,
	nodes: Dictionary,
	edges: Dictionary,
	failures: Array[String]
) -> void:
	for edge_id in edges.keys():
		var edge = edges[edge_id]
		if edge.owning_region_id != region.stable_id:
			failures.append("Edge has wrong owning region: " + edge_id)
		if edge.endpoint_a_node_id == edge.endpoint_b_node_id:
			failures.append("Edge connects a node to itself: " + edge_id)
		if edge.endpoint_b_node_id < edge.endpoint_a_node_id:
			failures.append("Edge endpoint order is not canonical: " + edge_id)

		var allows_external: bool = edge.connection_class == "cross_region_connection"
		if not nodes.has(edge.endpoint_a_node_id) and not allows_external:
			failures.append("Edge endpoint A is missing: " + edge_id)
		if not nodes.has(edge.endpoint_b_node_id) and not allows_external:
			failures.append("Edge endpoint B is missing: " + edge_id)
		if edge.connection_class.is_empty():
			failures.append("Edge has empty connection_class: " + edge_id)
		_validate_unique_strings(edge.tags, "edge tags " + edge_id, failures)


static func _validate_entrances(
	region,
	networks: Dictionary,
	nodes: Dictionary,
	edges: Dictionary,
	entrances: Dictionary,
	failures: Array[String]
) -> void:
	for entrance_id in entrances.keys():
		var entrance = entrances[entrance_id]
		if entrance.owning_region_id != region.stable_id:
			failures.append("Entrance has wrong owning region: " + entrance_id)
		if not networks.has(entrance.connected_network_id):
			failures.append("Entrance references missing network: " + entrance_id)
		elif not networks[entrance.connected_network_id].attached_entrance_ids.has(entrance_id):
			failures.append("Entrance is omitted from connected network: " + entrance_id)
		if not nodes.has(entrance.connected_node_id):
			failures.append("Entrance references missing node: " + entrance_id)
		elif nodes[entrance.connected_node_id].owning_network_id != entrance.connected_network_id:
			failures.append("Entrance node/network ownership mismatch: " + entrance_id)

		_validate_vector3(
			entrance.surface_world_position,
			"entrance surface position " + entrance_id,
			failures
		)
		_validate_vector3(
			entrance.underground_connection_position,
			"entrance underground position " + entrance_id,
			failures
		)
		if entrance.entrance_kind.is_empty():
			failures.append("Entrance has empty entrance_kind: " + entrance_id)
		if entrance.descent_profile.is_empty():
			failures.append("Entrance has empty descent_profile: " + entrance_id)
		var path_edge_id: String = str(
			entrance.generation_metadata.get("entrance_path_edge_id", "")
		)
		if path_edge_id.is_empty():
			failures.append("Entrance has no entrance-path edge reference: " + entrance_id)
		else:
			var matching_paths: int = 0
			for network in networks.values():
				if path_edge_id in network.entrance_path_edge_ids:
					matching_paths += 1
			if matching_paths != 1:
				failures.append(
					"Entrance path must belong to exactly one network: %s count=%d" % [
						entrance_id, matching_paths,
					]
				)
			if not edges.has(path_edge_id):
				failures.append("Entrance references missing entrance-path edge: " + entrance_id)
			else:
				var path_edge = edges[path_edge_id]
				if path_edge.connection_class != "entrance_path":
					failures.append("Entrance route has wrong edge class: " + entrance_id)
				if (
					path_edge.endpoint_a_node_id != entrance.connected_node_id
					and path_edge.endpoint_b_node_id != entrance.connected_node_id
				):
					failures.append("Entrance path does not reach connected node: " + entrance_id)
				if str(path_edge.topology_parameters.get("entrance_id", "")) != entrance_id:
					failures.append("Entrance path metadata references another entrance: " + entrance_id)
		var integration: Dictionary = entrance.surface_integration_parameters
		if not integration.has("required_opening_bounds"):
			failures.append("Entrance is missing required opening bounds: " + entrance_id)
		else:
			_validate_aabb(
				integration["required_opening_bounds"],
				"entrance opening bounds " + entrance_id,
				failures
			)
		if float(integration.get("clearance_radius", 0.0)) <= 0.0:
			failures.append("Entrance has non-positive clearance radius: " + entrance_id)
		if not integration.has("orientation"):
			failures.append("Entrance is missing orientation: " + entrance_id)
		else:
			var orientation: Vector3 = integration["orientation"]
			_validate_vector3(orientation, "entrance orientation " + entrance_id, failures)
			if absf(orientation.length() - 1.0) > 0.001:
				failures.append("Entrance orientation is not normalized: " + entrance_id)


static func _validate_hooks(
	region,
	nodes: Dictionary,
	edges: Dictionary,
	hooks: Dictionary,
	failures: Array[String]
) -> void:
	for hook_id in hooks.keys():
		var hook = hooks[hook_id]
		if hook.owning_region_id != region.stable_id:
			failures.append("Special-location hook has wrong owning region: " + hook_id)
		if not hook.anchor_node_id.is_empty() and not nodes.has(hook.anchor_node_id):
			failures.append("Special-location hook references missing node: " + hook_id)
		if not hook.anchor_edge_id.is_empty() and not edges.has(hook.anchor_edge_id):
			failures.append("Special-location hook references missing edge: " + hook_id)
		_validate_vector3(hook.free_world_anchor, "hook world anchor " + hook_id, failures)
		_validate_aabb(hook.reserved_bounds, "hook reserved bounds " + hook_id, failures)
		_validate_profile(hook.profile_blend, "hook profile_blend " + hook_id, failures)
		if hook.semantic_category.is_empty():
			failures.append("Special-location hook has empty semantic_category: " + hook_id)


static func _validate_global_identity_uniqueness(
	region,
	networks: Dictionary,
	nodes: Dictionary,
	edges: Dictionary,
	entrances: Dictionary,
	hooks: Dictionary,
	failures: Array[String]
) -> void:
	var seen: Dictionary = {region.stable_id: "region"}
	var groups: Array = [networks, nodes, edges, entrances, hooks]
	var labels: Array[String] = ["network", "node", "edge", "entrance", "hook"]
	for group_index in range(groups.size()):
		var group: Dictionary = groups[group_index]
		for stable_id in group.keys():
			if seen.has(stable_id):
				failures.append(
					"StableId collision across graph definitions: %s (%s / %s)" % [
						stable_id,
						seen[stable_id],
						labels[group_index],
					]
				)
			else:
				seen[stable_id] = labels[group_index]


static func _validate_exact_id_set(
	references: Array,
	indexed: Dictionary,
	label: String,
	failures: Array[String]
) -> void:
	for stable_id in references:
		if not indexed.has(stable_id):
			failures.append("%s list references missing definition: %s" % [label, stable_id])
	for stable_id in indexed.keys():
		if not references.has(stable_id):
			failures.append("%s definition omitted from owning list: %s" % [label, stable_id])


static func _validate_unique_strings(
	values: Array,
	label: String,
	failures: Array[String]
) -> void:
	var seen: Dictionary = {}
	for value_variant in values:
		var value: String = str(value_variant)
		if value.is_empty():
			failures.append(label + " contains empty value")
		elif seen.has(value):
			failures.append("%s contains duplicate value: %s" % [label, value])
		else:
			seen[value] = true


static func _validate_profile(value: Vector3, label: String, failures: Array[String]) -> void:
	_validate_vector3(value, label, failures)
	if value.x < 0.0 or value.y < 0.0 or value.z < 0.0:
		failures.append(label + " contains negative weight")
	var total: float = value.x + value.y + value.z
	if absf(total - 1.0) > PROFILE_EPSILON:
		failures.append("%s is not normalized (sum=%s)" % [label, str(total)])


static func _validate_vector3(value: Vector3, label: String, failures: Array[String]) -> void:
	if not is_finite(value.x) or not is_finite(value.y) or not is_finite(value.z):
		failures.append(label + " contains non-finite value")


static func _validate_aabb(value: AABB, label: String, failures: Array[String]) -> void:
	_validate_vector3(value.position, label + " position", failures)
	_validate_vector3(value.size, label + " size", failures)
	if value.size.x < 0.0 or value.size.y < 0.0 or value.size.z < 0.0:
		failures.append(label + " has negative size")
