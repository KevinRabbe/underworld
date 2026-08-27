extends RefCounted

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const RegionDefinition := preload("res://worldgen/graph/underground_region_definition.gd")
const NetworkDefinition := preload("res://worldgen/graph/cave_network_definition.gd")
const NodeDefinition := preload("res://worldgen/graph/cave_node_definition.gd")
const EdgeDefinition := preload("res://worldgen/graph/cave_edge_definition.gd")
const EntranceDefinition := preload("res://worldgen/graph/entrance_definition.gd")
const SpecialHookDefinition := preload("res://worldgen/graph/special_location_hook_definition.gd")
const RegionGraphBundle := preload("res://worldgen/graph/region_graph_bundle.gd")


static func build(reverse_collection_order: bool = false):
	var region_address = StableAddress.underground_region(0, 0)
	var region_id: String = StableId.from_address(region_address).value()

	var network_a_address = StableAddress.network(region_address, 0)
	var network_b_address = StableAddress.network(region_address, 1)
	var network_a_id: String = StableId.from_address(network_a_address).value()
	var network_b_id: String = StableId.from_address(network_b_address).value()

	var node_a0_address = StableAddress.node(network_a_address)
	var node_a1_address = StableAddress.node(network_a_address, [0])
	var node_b0_address = StableAddress.node(network_b_address)
	var node_a0_id: String = StableId.from_address(node_a0_address).value()
	var node_a1_id: String = StableId.from_address(node_a1_address).value()
	var node_b0_id: String = StableId.from_address(node_b0_address).value()

	var primary_address = StableAddress.primary_edge(
		network_a_address,
		node_a0_address,
		node_a1_address,
		0
	)
	var primary_id: String = StableId.from_address(primary_address).value()

	var secondary_address = StableAddress.secondary_connector(
		region_address,
		node_a1_address,
		node_b0_address,
		"deliberate_loop",
		0
	)
	var secondary_id: String = StableId.from_address(secondary_address).value()

	var entrance_address = StableAddress.entrance(region_address, 0)
	var entrance_id: String = StableId.from_address(entrance_address).value()

	var hook_address = StableAddress.special_location(node_a1_address, "large-deposit", 0)
	var hook_id: String = StableId.from_address(hook_address).value()

	var node_a0 = NodeDefinition.new(
		node_a0_address,
		network_a_id,
		Vector3(0.0, -20.0, 0.0),
		"ellipsoid",
		Vector3(18.0, 10.0, 15.0),
		Vector3(0.75, 0.25, 0.0),
		"chamber",
		["entry-near"]
	)
	var node_a1 = NodeDefinition.new(
		node_a1_address,
		network_a_id,
		Vector3(30.0, -35.0, 10.0),
		"ellipsoid",
		Vector3(24.0, 14.0, 18.0),
		Vector3(0.25, 0.70, 0.05),
		"junction",
		["resource-capable", "loop-candidate"],
		{"candidate_slot": 0, "branch_depth": 1}
	)
	var node_b0 = NodeDefinition.new(
		node_b0_address,
		network_b_id,
		Vector3(60.0, -45.0, 0.0),
		"ellipsoid",
		Vector3(20.0, 12.0, 20.0),
		Vector3(0.10, 0.75, 0.15),
		"terminal",
		["isolated-primary"]
	)

	var primary_edge = EdgeDefinition.new(
		primary_address,
		node_a0_id,
		node_a1_id,
		region_id,
		"primary",
		{"branch_slot": 0, "vertical_bias": 0.35},
		{"width": 5.0, "roughness": 0.6}
	)
	var secondary_edge = EdgeDefinition.new(
		secondary_address,
		node_a1_id,
		node_b0_id,
		region_id,
		"deliberate_loop",
		{"topology_gain": 0.82},
		{"width": 4.0},
		["secondary"]
	)

	var entrance = EntranceDefinition.new(
		entrance_address,
		region_id,
		network_a_id,
		node_a0_id,
		Vector3(-8.0, 4.0, -5.0),
		Vector3(0.0, -18.0, 0.0),
		"natural_cave",
		"gradual_cave",
		{"surface_radius": 6.0, "clearance": 4.5}
	)

	var hook = SpecialHookDefinition.new(
		hook_address,
		region_id,
		node_a1_id,
		"",
		node_a1.world_position,
		"large_deposit",
		AABB(Vector3(20.0, -43.0, 0.0), Vector3(20.0, 16.0, 20.0)),
		node_a1.profile_blend,
		{"candidate_slot": 0}
	)

	var network_a = NetworkDefinition.new(
		network_a_address,
		region_id,
		node_a0_id,
		[node_a1_id, node_a0_id],
		[primary_id],
		[entrance_id],
		{"node_count": 2}
	)
	var network_b = NetworkDefinition.new(
		network_b_address,
		region_id,
		node_b0_id,
		[node_b0_id],
		[],
		[],
		{"node_count": 1}
	)

	var region = RegionDefinition.new(
		region_address,
		Vector2i(0, 0),
		Vector3.ZERO,
		AABB(Vector3(-128.0, -256.0, -128.0), Vector3(256.0, 256.0, 256.0)),
		Vector3(0.45, 0.45, 0.10),
		[network_b_id, network_a_id],
		[entrance_id],
		[secondary_id],
		[hook_id],
		{"network_count": 2, "accepted_secondary_edges": 1}
	)

	var networks: Array = [network_a, network_b]
	var nodes: Array = [node_a0, node_a1, node_b0]
	var edges: Array = [primary_edge, secondary_edge]
	var entrances: Array = [entrance]
	var hooks: Array = [hook]

	if reverse_collection_order:
		networks.reverse()
		nodes.reverse()
		edges.reverse()
		entrances.reverse()
		hooks.reverse()

	return RegionGraphBundle.new(region, networks, nodes, edges, entrances, hooks)
