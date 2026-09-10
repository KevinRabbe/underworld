extends RefCounted
class_name UnderworldSeedDomains

const SeedDomainScript := preload("res://worldgen/random/seed_domain.gd")

# Explicit IDs are permanent once persistent worlds depend on them.
# Do not replace these with insertion-sensitive enum ordinals.

const SURFACE_TREE_EXISTS: int = 0x010001
const SURFACE_TREE_OFFSET: int = 0x010002
const SURFACE_TREE_SHAPE: int = 0x010003
const SURFACE_ROCK_EXISTS: int = 0x010101
const SURFACE_ROCK_OFFSET: int = 0x010102
const SURFACE_ROCK_SHAPE: int = 0x010103
const SURFACE_BRANCH_EXISTS: int = 0x010201
const SURFACE_BRANCH_SHAPE: int = 0x010202
const SURFACE_LOOSE_STONE_EXISTS: int = 0x010211
const SURFACE_LOOSE_STONE_SHAPE: int = 0x010212

const UG_REGION_LAYOUT: int = 0x020001
const UG_NETWORK_EXISTS: int = 0x020101
const UG_NETWORK_TOPOLOGY: int = 0x020102
const UG_NODE_EXISTS: int = 0x020200
const UG_NODE_POSITION: int = 0x020201
const UG_NODE_SHAPE: int = 0x020202
const UG_NODE_PROFILE: int = 0x020203
const UG_PRIMARY_EDGE_TOPOLOGY: int = 0x020211
const UG_ENTRANCE_SELECTION: int = 0x020301
const UG_ENTRANCE_PROFILE: int = 0x020302
const UG_ENTRANCE_SURFACE: int = 0x020303
const UG_ENTRANCE_GEOMETRY: int = 0x020304
const UG_SECONDARY_EXISTS: int = 0x020401
const UG_SECONDARY_SHAPE: int = 0x020402
const UG_SPECIAL_EXISTS: int = 0x020501
const UG_GEOMETRY_SHAPE: int = 0x020601

const GATEWAY_OVERWORLD_SOURCE_SITE: int = 0x030001
const GATEWAY_UNDERWORLD_DESTINATION_SITE: int = 0x030101
const GATEWAY_LINK_PAIRING: int = 0x030201


static func get_domain(domain_id: int):
	for domain in all_domains():
		if domain.domain_id == domain_id:
			return domain
	return null


static func all_domains() -> Array:
	return [
		SeedDomainScript.new(SURFACE_TREE_EXISTS, "surface.tree.exists", 1),
		SeedDomainScript.new(SURFACE_TREE_OFFSET, "surface.tree.offset", 1),
		SeedDomainScript.new(SURFACE_TREE_SHAPE, "surface.tree.shape", 1),
		SeedDomainScript.new(SURFACE_ROCK_EXISTS, "surface.rock.exists", 1),
		SeedDomainScript.new(SURFACE_ROCK_OFFSET, "surface.rock.offset", 1),
		SeedDomainScript.new(SURFACE_ROCK_SHAPE, "surface.rock.shape", 1),
		SeedDomainScript.new(SURFACE_BRANCH_EXISTS, "surface.pickup.branch.exists", 1),
		SeedDomainScript.new(SURFACE_BRANCH_SHAPE, "surface.pickup.branch.shape", 1),
		SeedDomainScript.new(
			SURFACE_LOOSE_STONE_EXISTS,
			"surface.pickup.loose_stone.exists",
			1
		),
		SeedDomainScript.new(
			SURFACE_LOOSE_STONE_SHAPE,
			"surface.pickup.loose_stone.shape",
			1
		),
		SeedDomainScript.new(UG_REGION_LAYOUT, "ug.region.layout", 1),
		SeedDomainScript.new(UG_NETWORK_EXISTS, "ug.network.exists", 1),
		SeedDomainScript.new(UG_NETWORK_TOPOLOGY, "ug.network.topology", 1),
		SeedDomainScript.new(UG_NODE_EXISTS, "ug.node.exists", 1),
		SeedDomainScript.new(UG_NODE_POSITION, "ug.node.position", 1),
		SeedDomainScript.new(UG_NODE_SHAPE, "ug.node.shape", 1),
		SeedDomainScript.new(UG_NODE_PROFILE, "ug.node.profile", 1),
		SeedDomainScript.new(
			UG_PRIMARY_EDGE_TOPOLOGY,
			"ug.primary_edge.topology",
			1
		),
		SeedDomainScript.new(UG_ENTRANCE_SELECTION, "ug.entrance.selection", 1),
		SeedDomainScript.new(UG_ENTRANCE_PROFILE, "ug.entrance.profile", 1),
		SeedDomainScript.new(UG_ENTRANCE_SURFACE, "ug.entrance.surface", 1),
		SeedDomainScript.new(UG_ENTRANCE_GEOMETRY, "ug.entrance.geometry", 1),
		SeedDomainScript.new(UG_SECONDARY_EXISTS, "ug.secondary.exists", 1),
		SeedDomainScript.new(UG_SECONDARY_SHAPE, "ug.secondary.shape", 1),
		SeedDomainScript.new(UG_SPECIAL_EXISTS, "ug.special.exists", 1),
		SeedDomainScript.new(UG_GEOMETRY_SHAPE, "ug.geometry.shape", 1),
		SeedDomainScript.new(
			GATEWAY_OVERWORLD_SOURCE_SITE,
			"gateway.overworld.source_site",
			1
		),
		SeedDomainScript.new(
			GATEWAY_UNDERWORLD_DESTINATION_SITE,
			"gateway.underworld.destination_site",
			1
		),
		SeedDomainScript.new(GATEWAY_LINK_PAIRING, "gateway.link.pairing", 1),
	]


static func validate_registry() -> Array[String]:
	var failures: Array[String] = []
	var ids: Dictionary = {}
	var names: Dictionary = {}

	for domain in all_domains():
		if domain.domain_id <= 0:
			failures.append("Seed domain has non-positive ID: " + domain.readable_name)
		if domain.revision <= 0:
			failures.append("Seed domain has non-positive revision: " + domain.readable_name)
		if domain.readable_name.is_empty():
			failures.append("Seed domain has empty readable name")
		if ids.has(domain.domain_id):
			failures.append("Duplicate seed domain ID: %08x" % domain.domain_id)
		else:
			ids[domain.domain_id] = true
		if names.has(domain.readable_name):
			failures.append("Duplicate seed domain name: " + domain.readable_name)
		else:
			names[domain.readable_name] = true

	return failures
