extends RefCounted
class_name UnderworldTopologyAtlasBuilder

const SnapshotBuilder := preload("res://tools/worldgen/topology_snapshot_builder.gd")

const MAX_RADIUS: int = 4


static func build(world_seed: int, center_coord: Vector2i, radius: int = 1) -> Dictionary:
	if radius < 0 or radius > MAX_RADIUS:
		return {
			"success": false,
			"stage": "topology_atlas",
			"diagnostics": ["Atlas radius must be between 0 and %d" % MAX_RADIUS],
		}

	var regions: Array = []
	var topology_fingerprints: Array[String] = []
	var totals: Dictionary = {
		"region_count": 0,
		"network_count": 0,
		"node_count": 0,
		"edge_count": 0,
		"boundary_candidate_count": 0,
	}

	for region_z in range(center_coord.y - radius, center_coord.y + radius + 1):
		for region_x in range(center_coord.x - radius, center_coord.x + radius + 1):
			var coord := Vector2i(region_x, region_z)
			var built: Dictionary = SnapshotBuilder.build(world_seed, coord)
			if not bool(built.get("success", false)):
				return {
					"success": false,
					"stage": "topology_atlas",
					"failed_region": [coord.x, coord.y],
					"diagnostics": built.get("diagnostics", []).duplicate(true),
				}

			var snapshot: Dictionary = built["snapshot"].duplicate(true)
			regions.append(snapshot)
			topology_fingerprints.append(str(built["topology_fingerprint"]))
			totals["region_count"] = int(totals["region_count"]) + 1
			totals["network_count"] = int(totals["network_count"]) + snapshot.get("networks", []).size()
			totals["node_count"] = int(totals["node_count"]) + snapshot.get("nodes", []).size()
			totals["edge_count"] = int(totals["edge_count"]) + snapshot.get("edges", []).size()
			totals["boundary_candidate_count"] = int(totals["boundary_candidate_count"]) + snapshot.get("boundary_candidates", []).size()

	var diameter: int = radius * 2 + 1
	var atlas: Dictionary = {
		"schema": "underworld-topology-atlas-v1",
		"world_seed": world_seed,
		"center_region": [center_coord.x, center_coord.y],
		"radius": radius,
		"grid_size": [diameter, diameter],
		"totals": totals,
		"topology_fingerprints": topology_fingerprints,
		"regions": regions,
	}
	return {
		"success": true,
		"atlas": atlas,
		"diagnostics": [],
	}
