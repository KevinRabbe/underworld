extends "res://core/content/registry/content_definition.gd"
class_name ReservedSiteContentDefinition

## Authored semantic content eligible for assignment to a deterministic reserved site.
## Generic semantic identity/revision/category/capability declarations come from
## the accepted ContentDefinition contract. This subtype owns only reserved-site
## hook eligibility, weighting/profile policy and family-specific metadata.

var eligible_hook_categories: Array[String] = []
var selection_weight: int = 1
var minimum_profile: Vector3 = Vector3.ZERO
var maximum_profile: Vector3 = Vector3.ONE
var metadata: Dictionary = {}


func _init(
	content_id_value: String = "",
	category_ids_value: Array = [],
	eligible_hook_categories_value: Array = [],
	selection_weight_value: int = 1,
	schema_revision_value: int = 1,
	minimum_profile_value: Vector3 = Vector3.ZERO,
	maximum_profile_value: Vector3 = Vector3.ONE,
	metadata_value: Dictionary = {}
) -> void:
	configure(content_id_value, ContentId.family_of(content_id_value), schema_revision_value)
	configure_schema_declarations(category_ids_value, [])
	if eligible_hook_categories_value.is_empty():
		eligible_hook_categories.append("reserved_site")
	else:
		for value in eligible_hook_categories_value:
			eligible_hook_categories.append(str(value))
	eligible_hook_categories.sort()
	selection_weight = selection_weight_value
	minimum_profile = minimum_profile_value
	maximum_profile = maximum_profile_value
	metadata = metadata_value.duplicate(true)


func validate_definition() -> Array[String]:
	var failures: Array[String] = super.validate_definition()
	if category_ids.is_empty():
		failures.append("Reserved-site content definition requires at least one category_id")
	if eligible_hook_categories.is_empty():
		failures.append("Reserved-site content definition requires eligible hook categories")
	var seen_hooks: Dictionary = {}
	for hook_category in eligible_hook_categories:
		if not _valid_hook_category(hook_category):
			failures.append("Invalid reserved-site hook category: %s" % hook_category)
		elif seen_hooks.has(hook_category):
			failures.append("Duplicate reserved-site hook category: %s" % hook_category)
		seen_hooks[hook_category] = true
	if selection_weight <= 0:
		failures.append("Reserved-site selection_weight must be positive")
	if not _profile_in_unit_range(minimum_profile) or not _profile_in_unit_range(maximum_profile):
		failures.append("Reserved-site profile eligibility must stay within [0, 1]")
	if (
		minimum_profile.x > maximum_profile.x
		or minimum_profile.y > maximum_profile.y
		or minimum_profile.z > maximum_profile.z
	):
		failures.append("Reserved-site minimum_profile must not exceed maximum_profile")
	failures.sort()
	return failures


func matches_hook(hook) -> bool:
	if hook == null:
		return false
	var hook_category: String = str(hook.get("semantic_category"))
	if not eligible_hook_categories.has(hook_category):
		return false
	var profile_variant = hook.get("profile_blend")
	if typeof(profile_variant) != TYPE_VECTOR3:
		return false
	var profile: Vector3 = profile_variant
	return (
		profile.x >= minimum_profile.x
		and profile.y >= minimum_profile.y
		and profile.z >= minimum_profile.z
		and profile.x <= maximum_profile.x
		and profile.y <= maximum_profile.y
		and profile.z <= maximum_profile.z
	)


func canonical_descriptor() -> Dictionary:
	var descriptor: Dictionary = super.canonical_descriptor()
	descriptor["eligible_hook_categories"] = eligible_hook_categories.duplicate()
	descriptor["selection_weight"] = selection_weight
	descriptor["minimum_profile"] = minimum_profile
	descriptor["maximum_profile"] = maximum_profile
	descriptor["metadata"] = metadata.duplicate(true)
	return descriptor


static func _valid_hook_category(value: String) -> bool:
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


static func _profile_in_unit_range(value: Vector3) -> bool:
	return (
		value.x >= 0.0 and value.x <= 1.0
		and value.y >= 0.0 and value.y <= 1.0
		and value.z >= 0.0 and value.z <= 1.0
	)
