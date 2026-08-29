extends RefCounted
class_name UndergroundPlacementPolicy

const ContentId := preload("res://core/content/identity/content_id.gd")
const ContentReference := preload("res://core/content/references/content_reference.gd")
const SchemaId := preload("res://core/content/schema/schema_id.gd")

const POLICY_FAMILY := "placement_policy"
const TARGET_ROLE := "placement.target"

var policy_id: String = ""
var target_reference = null
var eligible_source_kinds: Array[String] = []
var required_candidate_category_ids: Array[String] = []
var required_candidate_trait_ids: Array[String] = []
var required_target_category_ids: Array[String] = []
var minimum_depth_band: int = 0
var maximum_depth_band: int = 2147483647
var max_per_candidate: int = 1
var selection_weight: int = 1


func configure(
	p_policy_id: String,
	p_target_content_id: String,
	p_expected_family: String,
	p_eligible_source_kinds: Array = [],
	p_required_candidate_category_ids: Array = [],
	p_required_candidate_trait_ids: Array = [],
	p_required_target_category_ids: Array = [],
	p_minimum_depth_band: int = 0,
	p_maximum_depth_band: int = 2147483647,
	p_max_per_candidate: int = 1,
	p_selection_weight: int = 1
) -> RefCounted:
	policy_id = p_policy_id
	target_reference = ContentReference.new(
		p_policy_id,
		TARGET_ROLE,
		p_target_content_id,
		p_expected_family,
		true
	)
	eligible_source_kinds = _sorted_strings(p_eligible_source_kinds)
	required_candidate_category_ids = _sorted_strings(p_required_candidate_category_ids)
	required_candidate_trait_ids = _sorted_strings(p_required_candidate_trait_ids)
	required_target_category_ids = _sorted_strings(p_required_target_category_ids)
	minimum_depth_band = p_minimum_depth_band
	maximum_depth_band = p_maximum_depth_band
	max_per_candidate = p_max_per_candidate
	selection_weight = p_selection_weight
	return self


func validate_policy() -> Array[String]:
	var failures: Array[String] = []
	for failure in ContentId.validate(policy_id):
		failures.append("placement policy id: %s" % failure)
	if ContentId.is_valid(policy_id) and ContentId.family_of(policy_id) != POLICY_FAMILY:
		failures.append("placement policy id must use '%s.*' family: %s" % [POLICY_FAMILY, policy_id])

	if target_reference == null or not target_reference is ContentReference:
		failures.append("placement policy requires a semantic ContentReference target")
	else:
		for failure in target_reference.validate_reference():
			failures.append("placement target reference: %s" % failure)
		if target_reference.source_id != policy_id:
			failures.append("placement target reference source_id must equal policy_id")
		if target_reference.role != TARGET_ROLE:
			failures.append("placement target reference role must be '%s'" % TARGET_ROLE)
		if target_reference.expected_family.is_empty():
			failures.append("placement target reference requires an expected content family")

	_validate_source_kinds(eligible_source_kinds, failures)
	_validate_categories(required_candidate_category_ids, "candidate", failures)
	_validate_traits(required_candidate_trait_ids, failures)
	_validate_categories(required_target_category_ids, "target", failures)

	if minimum_depth_band < 0:
		failures.append("placement policy minimum_depth_band must be >= 0")
	if maximum_depth_band < minimum_depth_band:
		failures.append("placement policy maximum_depth_band must be >= minimum_depth_band")
	if max_per_candidate <= 0:
		failures.append("placement policy max_per_candidate must be > 0")
	if selection_weight <= 0:
		failures.append("placement policy selection_weight must be > 0")
	failures.sort()
	return failures


func matches_candidate(candidate) -> bool:
	if candidate == null:
		return false
	if not eligible_source_kinds.is_empty() and not eligible_source_kinds.has(str(candidate.source_kind)):
		return false
	var candidate_depth: int = int(candidate.depth_band)
	if candidate_depth < minimum_depth_band or candidate_depth > maximum_depth_band:
		return false
	for category_id in required_candidate_category_ids:
		if not candidate.category_ids.has(category_id):
			return false
	for trait_id in required_candidate_trait_ids:
		if not candidate.trait_ids.has(trait_id):
			return false
	return true


func canonical_descriptor() -> Dictionary:
	var target_data: Dictionary = {}
	if target_reference != null and target_reference is ContentReference:
		target_data = {
			"source_id": target_reference.source_id,
			"role": target_reference.role,
			"target_id": target_reference.target_id,
			"expected_family": target_reference.expected_family,
			"required": target_reference.required,
		}
	return {
		"policy_id": policy_id,
		"target_reference": target_data,
		"eligible_source_kinds": eligible_source_kinds.duplicate(),
		"required_candidate_category_ids": required_candidate_category_ids.duplicate(),
		"required_candidate_trait_ids": required_candidate_trait_ids.duplicate(),
		"required_target_category_ids": required_target_category_ids.duplicate(),
		"minimum_depth_band": minimum_depth_band,
		"maximum_depth_band": maximum_depth_band,
		"max_per_candidate": max_per_candidate,
		"selection_weight": selection_weight,
	}


static func _sorted_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	result.sort()
	return result


static func _validate_source_kinds(values: Array[String], failures: Array[String]) -> void:
	var seen: Dictionary = {}
	for value in values:
		if not _valid_source_kind(value):
			failures.append("placement policy source kind must be one lowercase ASCII token: %s" % value)
		if seen.has(value):
			failures.append("duplicate placement policy source kind: %s" % value)
		seen[value] = true


static func _validate_categories(values: Array[String], label: String, failures: Array[String]) -> void:
	var seen: Dictionary = {}
	for value in values:
		for failure in SchemaId.validate_category(value):
			failures.append("placement policy %s category: %s" % [label, failure])
		if seen.has(value):
			failures.append("duplicate placement policy %s category: %s" % [label, value])
		seen[value] = true


static func _validate_traits(values: Array[String], failures: Array[String]) -> void:
	var seen: Dictionary = {}
	for value in values:
		if not ContentId.is_valid(value) or ContentId.family_of(value) != "trait":
			failures.append("placement policy trait must use valid 'trait.*' semantic identity: %s" % value)
		if seen.has(value):
			failures.append("duplicate placement policy trait: %s" % value)
		seen[value] = true


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
