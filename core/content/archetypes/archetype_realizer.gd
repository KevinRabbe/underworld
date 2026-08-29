extends RefCounted

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const ArchetypeDefinition := preload("res://core/content/archetypes/archetype_definition.gd")
const ArchetypeComposition := preload("res://core/content/archetypes/archetype_composition.gd")
const ArchetypeRealizationAdapter := preload("res://core/content/archetypes/archetype_realization_adapter.gd")

var _adapters_by_id: Dictionary = {}


func clear_adapters() -> void:
	_adapters_by_id.clear()


func register_adapter(candidate) -> Array[String]:
	var failures: Array[String] = []
	if candidate == null or not candidate is ArchetypeRealizationAdapter:
		failures.append("expected ArchetypeRealizationAdapter")
		return failures
	failures.append_array(candidate.validate_adapter())
	if not failures.is_empty():
		failures.sort()
		return failures
	if _adapters_by_id.has(candidate.adapter_id):
		failures.append("duplicate realization adapter id: %s" % candidate.adapter_id)
		return failures
	_adapters_by_id[candidate.adapter_id] = candidate
	return failures


func adapter_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in _adapters_by_id.keys():
		ids.append(str(key))
	ids.sort()
	return ids


func realize(
	content_registry,
	validation_result: Dictionary,
	content_id: String
) -> Dictionary:
	var failures: Array[String] = []
	if content_registry == null or not content_registry is ContentRegistry:
		failures.append("expected ContentRegistry")
		return _result(content_id, null, "", failures)
	if not content_registry.is_valid():
		for failure in content_registry.diagnostics():
			failures.append("content registry: %s" % failure)
		failures.sort()
		return _result(content_id, null, "", failures)

	failures.append_array(_validation_prerequisite_failures(validation_result, content_id))
	if not failures.is_empty():
		failures.sort()
		return _result(content_id, null, "", failures)

	var resolved: Dictionary = content_registry.resolve(content_id)
	for failure in resolved.get("diagnostics", []):
		failures.append(str(failure))
	if not failures.is_empty():
		failures.sort()
		return _result(content_id, null, "", failures)

	var definition = resolved.get("definition", null)
	if definition == null or not definition is ArchetypeDefinition:
		failures.append("content definition is not an ArchetypeDefinition: %s" % content_id)
		return _result(content_id, null, "", failures)
	if definition.composition == null or not definition.composition is ArchetypeComposition:
		failures.append("archetype definition has no valid composition: %s" % content_id)
		return _result(content_id, null, "", failures)

	var adapter_id: String = str(definition.composition.realization_adapter_id)
	if not _adapters_by_id.has(adapter_id):
		failures.append(
			"no realization adapter registered for archetype '%s': %s" % [content_id, adapter_id]
		)
		return _result(content_id, null, adapter_id, failures)

	var adapter = _adapters_by_id[adapter_id]
	var realized: Dictionary = adapter.realize(definition)
	for failure in realized.get("diagnostics", []):
		failures.append(str(failure))
	failures.sort()
	var instance = realized.get("instance", null)
	if not failures.is_empty() and instance != null and instance is Node:
		instance.free()
		instance = null
	return _result(content_id, instance, adapter_id, failures)


static func _validation_prerequisite_failures(
	validation_result: Dictionary,
	content_id: String
) -> Array[String]:
	var failures: Array[String] = []
	if not validation_result.has("success"):
		failures.append("expected CONTENT-005 validation result")
		return failures

	if not bool(validation_result.get("success", false)):
		failures.append("CONTENT-005 validation did not accept archetype: %s" % content_id)
		for candidate in validation_result.get("diagnostics", []):
			if not candidate is Dictionary:
				continue
			var source_id: String = str(candidate.get("source_id", ""))
			if source_id != content_id and source_id != "<validation>":
				continue
			failures.append(
				"CONTENT-005 %s: %s" % [
					str(candidate.get("code", "diagnostic")),
					str(candidate.get("message", "")),
				]
			)
		failures.sort()
		return failures

	var covered: bool = false
	for raw_id in validation_result.get("validated_definition_ids", []):
		if str(raw_id) == content_id:
			covered = true
			break
	if not covered:
		failures.append("CONTENT-005 validation result does not cover content id: %s" % content_id)
	return failures


static func _result(
	content_id: String,
	instance,
	adapter_id: String,
	failures: Array[String]
) -> Dictionary:
	return {
		"content_id": content_id,
		"adapter_id": adapter_id,
		"instance": instance,
		"diagnostics": failures,
		"success": failures.is_empty() and instance != null,
	}
