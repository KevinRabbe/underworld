extends RefCounted

const SchemaId := preload("res://core/content/schema/schema_id.gd")

var capability_ids: Array[String] = []


func configure(p_capability_ids: Array = []) -> RefCounted:
	capability_ids.clear()
	for capability_id in p_capability_ids:
		capability_ids.append(str(capability_id))
	return self


func validate_context() -> Array[String]:
	var failures: Array[String] = []
	var seen: Dictionary = {}
	for capability_id in capability_ids:
		for failure in SchemaId.validate_capability(capability_id):
			failures.append("crafting context capability: %s" % failure)
		if seen.has(capability_id):
			failures.append("duplicate crafting context capability: %s" % capability_id)
		seen[capability_id] = true
	failures.sort()
	return failures


func has_capability(capability_id: String) -> bool:
	return capability_ids.has(capability_id)


func canonical_descriptor() -> Dictionary:
	var ordered: Array[String] = []
	ordered.append_array(capability_ids)
	ordered.sort()
	return {"capability_ids": ordered}
