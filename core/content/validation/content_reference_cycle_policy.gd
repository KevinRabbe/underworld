extends RefCounted

const ContentReference := preload("res://core/content/references/content_reference.gd")

var allowed_roles: Array[String] = []


func configure(p_allowed_roles: Array = []) -> RefCounted:
	allowed_roles.clear()
	for role in p_allowed_roles:
		allowed_roles.append(str(role))
	return self


func validate_policy() -> Array[String]:
	var failures: Array[String] = []
	var seen: Dictionary = {}
	for role in allowed_roles:
		var probe = ContentReference.new("", role, "", "", false)
		for failure in probe.validate_reference():
			failures.append("allowed cycle role: %s" % failure)
		if seen.has(role):
			failures.append("duplicate allowed cycle role: %s" % role)
		seen[role] = true
	failures.sort()
	return failures


func allows_cycle_edges(edges: Array) -> bool:
	if edges.is_empty():
		return false
	for edge in edges:
		if not allowed_roles.has(str(edge.get("role", ""))):
			return false
	return true


func canonical_descriptor() -> Dictionary:
	var roles: Array[String] = []
	roles.append_array(allowed_roles)
	roles.sort()
	return {"allowed_roles": roles}
