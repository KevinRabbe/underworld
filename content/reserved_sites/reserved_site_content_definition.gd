extends RefCounted
class_name ReservedSiteContentDefinition

## Authored semantic content eligible for assignment to a deterministic reserved site.
## This definition deliberately owns no procedural StableId and imports no worldgen code.

var content_id: String
var categories: Array[String] = []
var eligible_hook_categories: Array[String] = []
var selection_weight: int
var definition_revision: int
var minimum_profile: Vector3
var maximum_profile: Vector3
var metadata: Dictionary


func _init(
	content_id_value: String,
	categories_value: Array = [],
	eligible_hook_categories_value: Array = [],
	selection_weight_value: int = 1,
	definition_revision_value: int = 1,
	minimum_profile_value: Vector3 = Vector3.ZERO,
	maximum_profile_value: Vector3 = Vector3.ONE,
	metadata_value: Dictionary = {}
) -> void:
	content_id = content_id_value
	for value in categories_value:
		categories.append(str(value))
	categories.sort()
	if eligible_hook_categories_value.is_empty():
		eligible_hook_categories.append("reserved_site")
	else:
		for value in eligible_hook_categories_value:
			eligible_hook_categories.append(str(value))
	eligible_hook_categories.sort()
	selection_weight = selection_weight_value
	definition_revision = definition_revision_value
	minimum_profile = minimum_profile_value
	maximum_profile = maximum_profile_value
	metadata = metadata_value.duplicate(true)


func validate() -> Array[String]:
	var failures: Array[String] = []
	if not _valid_semantic_id(content_id):
		failures.append("Reserved-site content_id must be a lowercase dot-separated semantic content ID")
	if categories.is_empty():
		failures.append("Reserved-site content definition requires at least one category.* schema ID")
	var seen_categories: Dictionary = {}
	for category in categories:
		if not category.begins_with("category.") or not _valid_semantic_id(category):
			failures.append("Invalid reserved-site category: %s" % category)
		elif seen_categories.has(category):
			failures.append("Duplicate reserved-site category: %s" % category)
		seen_categories[category] = true
	if eligible_hook_categories.is_empty():
		failures.append("Reserved-site content definition requires eligible hook categories")
	var seen_hooks: Dictionary = {}
	for hook_category in eligible_hook_categories:
		if not _valid_token(hook_category):
			failures.append("Invalid reserved-site hook category: %s" % hook_category)
		elif seen_hooks.has(hook_category):
			failures.append("Duplicate reserved-site hook category: %s" % hook_category)
		seen_hooks[hook_category] = true
	if selection_weight <= 0:
		failures.append("Reserved-site selection_weight must be positive")
	if definition_revision <= 0:
		failures.append("Reserved-site definition_revision must be positive")
	if not _profile_in_unit_range(minimum_profile) or not _profile_in_unit_range(maximum_profile):
		failures.append("Reserved-site profile eligibility must stay within [0, 1]")
	if (
		minimum_profile.x > maximum_profile.x
		or minimum_profile.y > maximum_profile.y
		or minimum_profile.z > maximum_profile.z
	):
		failures.append("Reserved-site minimum_profile must not exceed maximum_profile")
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


func canonical_data() -> Dictionary:
	return {
		"content_id": content_id,
		"categories": categories.duplicate(),
		"eligible_hook_categories": eligible_hook_categories.duplicate(),
		"selection_weight": selection_weight,
		"definition_revision": definition_revision,
		"minimum_profile": minimum_profile,
		"maximum_profile": maximum_profile,
		"metadata": metadata.duplicate(true),
	}


static func _valid_semantic_id(value: String) -> bool:
	if value.is_empty() or value != value.to_lower() or value.find(".") <= 0:
		return false
	if value.begins_with(".") or value.ends_with(".") or value.contains(".."):
		return false
	for index in range(value.length()):
		var codepoint: int = value.unicode_at(index)
		var valid := (
			(codepoint >= 97 and codepoint <= 122)
			or (codepoint >= 48 and codepoint <= 57)
			or codepoint == 95
			or codepoint == 46
		)
		if not valid:
			return false
	return true


static func _valid_token(value: String) -> bool:
	if value.is_empty() or value != value.to_lower():
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
