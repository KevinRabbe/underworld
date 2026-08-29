extends RefCounted

const SemanticRoleSchema := preload("res://core/content/schema/semantic_role_schema.gd")
const SchemaId := preload("res://core/content/schema/schema_id.gd")

var _schemas_by_id: Dictionary = {}
var _diagnostics: Array[String] = []


func clear() -> void:
	_schemas_by_id.clear()
	_diagnostics.clear()


func index_schemas(schemas: Array) -> Array[String]:
	clear()
	var failures: Array[String] = []
	var grouped: Dictionary = {}

	for candidate in schemas:
		if candidate == null or not candidate is SemanticRoleSchema:
			failures.append("incompatible semantic role schema type: expected SemanticRoleSchema Resource")
			continue
		var schema_failures: Array[String] = candidate.validate_schema()
		if not schema_failures.is_empty():
			var label: String = str(candidate.schema_id)
			if label.is_empty():
				label = "<unidentified-semantic-role-schema>"
			for failure in schema_failures:
				failures.append("%s: %s" % [label, failure])
			continue
		var schema_id: String = str(candidate.schema_id)
		var group: Array = grouped.get(schema_id, [])
		group.append(candidate)
		grouped[schema_id] = group

	var ids: Array[String] = []
	for key in grouped.keys():
		ids.append(str(key))
	ids.sort()
	for schema_id in ids:
		var group: Array = grouped[schema_id]
		if group.size() != 1:
			failures.append("duplicate semantic role schema id: %s" % schema_id)
			continue
		_schemas_by_id[schema_id] = group[0]

	failures.sort()
	_diagnostics.append_array(failures)
	return diagnostics()


func is_valid() -> bool:
	return _diagnostics.is_empty()


func diagnostics() -> Array[String]:
	var result: Array[String] = []
	result.append_array(_diagnostics)
	return result


func schema_count() -> int:
	return _schemas_by_id.size()


func has_schema(schema_id: String) -> bool:
	return _schemas_by_id.has(schema_id)


func has_animation_role(schema_id: String) -> bool:
	return SchemaId.is_valid_animation_role(schema_id) and has_schema(schema_id)


func has_rig_role(schema_id: String) -> bool:
	return SchemaId.is_valid_rig_role(schema_id) and has_schema(schema_id)


func get_schema(schema_id: String):
	return _schemas_by_id.get(schema_id, null)


func schema_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in _schemas_by_id.keys():
		ids.append(str(key))
	ids.sort()
	return ids


func schema_ids_for_namespace(namespace: String) -> Array[String]:
	var ids: Array[String] = []
	for schema_id in schema_ids():
		if SchemaId.namespace_of(schema_id) == namespace:
			ids.append(schema_id)
	return ids


func canonical_manifest() -> Array[Dictionary]:
	var manifest: Array[Dictionary] = []
	for schema_id in schema_ids():
		manifest.append(_schemas_by_id[schema_id].canonical_descriptor())
	return manifest
