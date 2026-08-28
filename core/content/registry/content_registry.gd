extends RefCounted

const ContentId := preload("res://core/content/identity/content_id.gd")
const ContentDefinition := preload("res://core/content/registry/content_definition.gd")
const ContentReference := preload("res://core/content/references/content_reference.gd")

var _definitions_by_id: Dictionary = {}
var _diagnostics: Array[String] = []


func clear() -> void:
	_definitions_by_id.clear()
	_diagnostics.clear()


func index_definitions(definitions: Array) -> Array[String]:
	return _rebuild(definitions, [])


func load_resource_paths(paths: Array) -> Array[String]:
	var ordered_paths: Array[String] = []
	for raw_path in paths:
		var path: String = str(raw_path)
		if not ordered_paths.has(path):
			ordered_paths.append(path)
	ordered_paths.sort()

	var definitions: Array = []
	var load_failures: Array[String] = []
	for path in ordered_paths:
		if path.is_empty():
			load_failures.append("content resource path is empty")
			continue
		if not ResourceLoader.exists(path):
			load_failures.append("content resource does not exist: %s" % path)
			continue
		var resource: Resource = ResourceLoader.load(path)
		if resource == null:
			load_failures.append("content resource failed to load: %s" % path)
			continue
		definitions.append(resource)

	return _rebuild(definitions, load_failures)


func is_valid() -> bool:
	return _diagnostics.is_empty()


func diagnostics() -> Array[String]:
	var result: Array[String] = []
	result.append_array(_diagnostics)
	return result


func definition_count() -> int:
	return _definitions_by_id.size()


func has_definition(content_id: String) -> bool:
	return _definitions_by_id.has(content_id)


func get_definition(content_id: String):
	return _definitions_by_id.get(content_id, null)


func definition_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in _definitions_by_id.keys():
		ids.append(str(key))
	ids.sort()
	return ids


func definition_ids_for_family(definition_family: String) -> Array[String]:
	var ids: Array[String] = []
	if not ContentId.is_valid_family(definition_family):
		return ids
	for content_id in definition_ids():
		var definition = _definitions_by_id[content_id]
		if str(definition.definition_family) == definition_family:
			ids.append(content_id)
	return ids


func canonical_manifest() -> Array[Dictionary]:
	var manifest: Array[Dictionary] = []
	for content_id in definition_ids():
		var definition = _definitions_by_id[content_id]
		manifest.append(definition.canonical_descriptor())
	return manifest


func resolve(content_id: String, expected_family: String = "") -> Dictionary:
	var failures: Array[String] = []
	failures.append_array(ContentId.validate(content_id))
	if not expected_family.is_empty():
		for failure in ContentId.validate_family(expected_family):
			failures.append("expected family: %s" % failure)
	if not failures.is_empty():
		return {"definition": null, "diagnostics": failures}

	if not _definitions_by_id.has(content_id):
		failures.append("missing content definition: %s" % content_id)
		return {"definition": null, "diagnostics": failures}

	var definition = _definitions_by_id[content_id]
	if not expected_family.is_empty() and str(definition.definition_family) != expected_family:
		failures.append(
			"content definition %s has family '%s', expected '%s'" % [
				content_id,
				definition.definition_family,
				expected_family,
			]
		)
		return {"definition": null, "diagnostics": failures}
	return {"definition": definition, "diagnostics": failures}


func resolve_reference(reference) -> Dictionary:
	var failures: Array[String] = []
	if reference == null or not reference is ContentReference:
		failures.append("incompatible content reference type")
		return {"definition": null, "diagnostics": failures}

	failures.append_array(reference.validate_reference())
	if not failures.is_empty():
		return {"definition": null, "diagnostics": failures}
	if reference.target_id.is_empty() and not reference.required:
		return {"definition": null, "diagnostics": failures}

	var resolved: Dictionary = resolve(reference.target_id, reference.expected_family)
	var resolved_failures: Array = resolved.get("diagnostics", [])
	if not resolved_failures.is_empty():
		var source_label: String = reference.source_id if not reference.source_id.is_empty() else "<anonymous>"
		for failure in resolved_failures:
			failures.append(
				"%s reference '%s' -> %s: %s" % [
					source_label,
					reference.role,
					reference.target_id,
					failure,
				]
			)
		return {"definition": null, "diagnostics": failures}
	return {"definition": resolved.get("definition"), "diagnostics": failures}


func _rebuild(definitions: Array, initial_failures: Array[String]) -> Array[String]:
	_definitions_by_id.clear()
	_diagnostics.clear()

	var failures: Array[String] = []
	failures.append_array(initial_failures)
	var grouped: Dictionary = {}

	for candidate in definitions:
		if candidate == null or not candidate is ContentDefinition:
			failures.append("incompatible content definition type: expected ContentDefinition Resource")
			continue

		var definition_failures: Array[String] = candidate.validate_definition()
		if not definition_failures.is_empty():
			var label: String = str(candidate.content_id)
			if label.is_empty():
				label = "<unidentified-definition>"
			for failure in definition_failures:
				failures.append("%s: %s" % [label, failure])
			continue

		var content_id: String = str(candidate.content_id)
		var group: Array = grouped.get(content_id, [])
		group.append(candidate)
		grouped[content_id] = group

	var ids: Array[String] = []
	for key in grouped.keys():
		ids.append(str(key))
	ids.sort()

	for content_id in ids:
		var group: Array = grouped[content_id]
		if group.size() != 1:
			failures.append("duplicate semantic content id: %s" % content_id)
			continue
		_definitions_by_id[content_id] = group[0]

	failures.sort()
	_diagnostics.append_array(failures)
	return diagnostics()
