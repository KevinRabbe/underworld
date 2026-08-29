extends Resource
class_name UnderworldCavePresentationCatalog

const ProfileScript := preload("res://presentation/world/caves/cave_presentation_profile.gd")

@export var default_profile_id: String = ""
@export var profiles: Array = []


func validate_catalog() -> Array[String]:
	var failures: Array[String] = []
	var by_id: Dictionary = {}
	for candidate in profiles:
		if candidate == null or not candidate is ProfileScript:
			failures.append("cave presentation catalog entries must be CavePresentationProfile resources")
			continue
		for failure in candidate.validate_profile():
			failures.append("profile %s: %s" % [candidate.profile_id, failure])
		if by_id.has(candidate.profile_id):
			failures.append("duplicate cave presentation profile id: %s" % candidate.profile_id)
		by_id[candidate.profile_id] = candidate
	if default_profile_id.is_empty() or not by_id.has(default_profile_id):
		failures.append("cave presentation catalog default profile is not registered: %s" % default_profile_id)
	failures.sort()
	return failures


func profile_by_id(profile_id: String):
	for candidate in profiles:
		if candidate != null and candidate is ProfileScript and candidate.profile_id == profile_id:
			return candidate
	return null


func resolve(context: Dictionary) -> Dictionary:
	var failures: Array[String] = validate_catalog()
	if not failures.is_empty():
		return {"profile": null, "profile_id": "", "diagnostics": failures}
	var matches: Array = []
	for candidate in profiles:
		if candidate.matches(context):
			matches.append(candidate)
	if matches.is_empty():
		var fallback = profile_by_id(default_profile_id)
		return {"profile": fallback, "profile_id": fallback.profile_id, "diagnostics": []}
	matches.sort_custom(func(a, b):
		if a.priority != b.priority:
			return a.priority > b.priority
		if a.specificity() != b.specificity():
			return a.specificity() > b.specificity()
		return a.profile_id < b.profile_id
	)
	var selected = matches[0]
	return {"profile": selected, "profile_id": selected.profile_id, "diagnostics": []}


func canonical_descriptor() -> Dictionary:
	var descriptors: Array = []
	for candidate in profiles:
		if candidate != null and candidate is ProfileScript:
			descriptors.append(candidate.canonical_descriptor())
	descriptors.sort_custom(func(a, b): return str(a.get("profile_id", "")) < str(b.get("profile_id", "")))
	return {"default_profile_id": default_profile_id, "profiles": descriptors}
