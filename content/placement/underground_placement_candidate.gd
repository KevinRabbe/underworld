extends RefCounted
class_name UndergroundPlacementCandidate

const ContentId := preload("res://core/content/identity/content_id.gd")
const SchemaId := preload("res://core/content/schema/schema_id.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const ReservedSiteAssignment := preload("res://content/reserved_sites/reserved_site_assignment.gd")
const SCRIPT_PATH := "res://content/placement/underground_placement_candidate.gd"

var stable_id: String = ""
var source_kind: String = ""
var region_coord: Vector2i = Vector2i.ZERO
var depth_band: int = 0
var category_ids: Array[String] = []
var trait_ids: Array[String] = []
var local_capacity: int = 0


func configure(
	p_stable_id: String,
	p_source_kind: String,
	p_region_coord: Vector2i,
	p_depth_band: int,
	p_category_ids: Array = [],
	p_trait_ids: Array = [],
	p_local_capacity: int = 1
) -> RefCounted:
	stable_id = p_stable_id
	source_kind = p_source_kind
	region_coord = p_region_coord
	depth_band = p_depth_band
	category_ids.clear()
	for value in p_category_ids:
		category_ids.append(str(value))
	category_ids.sort()
	trait_ids.clear()
	for value in p_trait_ids:
		trait_ids.append(str(value))
	trait_ids.sort()
	local_capacity = p_local_capacity
	return self


static func from_reserved_site_assignment(
	assignment,
	region_coord_value: Vector2i,
	depth_band_value: int,
	trait_ids_value: Array = [],
	local_capacity_value: int = 1
):
	if assignment == null or not assignment is ReservedSiteAssignment:
		return null
	var candidate = load(SCRIPT_PATH).new()
	candidate.configure(
		assignment.site_stable_id,
		"reserved_site",
		region_coord_value,
		depth_band_value,
		assignment.category_ids,
		trait_ids_value,
		local_capacity_value
	)
	return candidate


func validate_candidate() -> Array[String]:
	var failures: Array[String] = []
	if StableId.parse(stable_id) == null:
		failures.append("underground placement candidate requires a canonical sid1 StableId")
	if not _valid_source_kind(source_kind):
		failures.append("underground placement candidate source_kind must be one lowercase ASCII token")
	if depth_band < 0:
		failures.append("underground placement candidate depth_band must be >= 0")
	if local_capacity < 0:
		failures.append("underground placement candidate local_capacity must be >= 0")

	var seen_categories: Dictionary = {}
	for category_id in category_ids:
		for failure in SchemaId.validate_category(category_id):
			failures.append("candidate category: %s" % failure)
		if seen_categories.has(category_id):
			failures.append("duplicate candidate category_id: %s" % category_id)
		seen_categories[category_id] = true

	var seen_traits: Dictionary = {}
	for trait_id in trait_ids:
		if not _valid_trait_id(trait_id):
			failures.append("candidate trait_id must use valid 'trait.*' semantic identity: %s" % trait_id)
		if seen_traits.has(trait_id):
			failures.append("duplicate candidate trait_id: %s" % trait_id)
		seen_traits[trait_id] = true
	failures.sort()
	return failures


func canonical_data() -> Dictionary:
	return {
		"stable_id": stable_id,
		"source_kind": source_kind,
		"region_coord": region_coord,
		"depth_band": depth_band,
		"category_ids": category_ids.duplicate(),
		"trait_ids": trait_ids.duplicate(),
		"local_capacity": local_capacity,
	}


static func _valid_trait_id(value: String) -> bool:
	return ContentId.is_valid(value) and ContentId.family_of(value) == "trait"


static func _valid_source_kind(value: String) -> bool:
	if value.is_empty() or value != value.to_lower() or value != value.strip_edges():
		return false
	for index in range(value.length()):
		var codepoint: int = value.unicode_at(index)
		if not (
			(codepoint >= 97 and codepoint <= 122)
			or (codepoint >= 48 and codepoint <= 57)
			or codepoint == 95
		):
			return false
	return true
