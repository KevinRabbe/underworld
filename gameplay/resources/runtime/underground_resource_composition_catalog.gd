extends RefCounted
class_name UndergroundResourceCompositionCatalog

const ReservedSiteDefinition := preload("res://content/reserved_sites/reserved_site_content_definition.gd")
const Candidate := preload("res://content/placement/underground_placement_candidate.gd")
const Policy := preload("res://content/placement/underground_placement_policy.gd")

const RESOURCE_CHANNEL := "resource"
const IRON_SITE_CONTENT_ID := "structure.underworld.iron_outcrop_site"
const IRON_SITE_CATEGORY_ID := "category.structure.underworld.vault"
const IRON_RESOURCE_CONTENT_ID := "resource.deposit.iron_outcrop"
const IRON_RESOURCE_CATEGORY_ID := "category.resource.deposit"
const IRON_POLICY_ID := "placement_policy.resource.iron_outcrop"
const RULEBOOK_REVISION: int = 1
const LOCAL_CAPACITY: int = 1


static func reserved_site_definitions() -> Array:
	return [
		ReservedSiteDefinition.new(
			IRON_SITE_CONTENT_ID,
			[IRON_SITE_CATEGORY_ID],
			["reserved_site"],
			1,
			1,
			Vector3.ZERO,
			Vector3.ONE,
			{
				"placement_channel": RESOURCE_CHANNEL,
				"local_capacity": LOCAL_CAPACITY,
			}
		),
	]


static func placement_policies() -> Array:
	return [
		Policy.new().configure(
			IRON_POLICY_ID,
			IRON_RESOURCE_CONTENT_ID,
			"resource",
			["reserved_site"],
			[IRON_SITE_CATEGORY_ID],
			[],
			[IRON_RESOURCE_CATEGORY_ID],
			0,
			2147483647,
			1,
			1
		),
	]


static func candidate_from_assignment(
	assignment,
	region_coord: Vector2i,
	depth_band: int = 0
):
	if assignment == null:
		return null
	var metadata_variant = assignment.definition_metadata
	if not metadata_variant is Dictionary:
		return null
	var metadata: Dictionary = metadata_variant
	var channel_variant = metadata.get("placement_channel", null)
	if not channel_variant is String or channel_variant != RESOURCE_CHANNEL:
		return null
	var capacity_variant = metadata.get("local_capacity", null)
	if typeof(capacity_variant) != TYPE_INT or int(capacity_variant) != LOCAL_CAPACITY:
		return null
	return Candidate.from_reserved_site_assignment_channel(
		assignment,
		RESOURCE_CHANNEL,
		region_coord,
		depth_band,
		[],
		LOCAL_CAPACITY
	)
