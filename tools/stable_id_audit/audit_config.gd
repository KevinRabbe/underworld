extends RefCounted
class_name UnderworldStableIdAuditConfig

const CORPUS_REVISION := "stable-id-audit-corpus-v1"

# Symmetric coordinate coverage deliberately includes small boundary-adjacent
# values and large values without depending on worldgen acceptance rules.
const COORDINATES := [
	-1000000,
	-65536,
	-4096,
	-73,
	-1,
	0,
	1,
	73,
	4096,
	65536,
	1000000,
]

# All current address factories accept non-negative candidate slots. The audit
# spans tiny, medium, large and very large valid slot values.
const SLOTS := [0, 1, 2, 7, 31, 255, 4095, 1000000]
const LINEAGE_SLOTS := [0, 7, 255]
const SURFACE_DOMAINS := ["tree", "rock", "resource"]
const CONNECTOR_CLASS := "audit_connector"
const SPECIAL_KIND := "audit_location"
const CHILD_KIND := "audit_child"


static func expected_unique_case_count() -> int:
	var region_count: int = COORDINATES.size() * COORDINATES.size()
	var slot_count: int = SLOTS.size()
	var network_count: int = region_count * slot_count
	var nodes_per_network: int = 1 + slot_count + LINEAGE_SLOTS.size() * LINEAGE_SLOTS.size()
	var node_count: int = network_count * nodes_per_network
	var primary_edge_count: int = network_count * slot_count
	var per_region_slot_families: int = 6 # entrance, anchor, path, connector, special, child
	var region_slot_case_count: int = region_count * slot_count * per_region_slot_families
	var surface_count: int = region_count * SURFACE_DOMAINS.size() * slot_count
	return region_count + network_count + node_count + primary_edge_count + region_slot_case_count + surface_count
