extends RefCounted

const CategorySchema := preload("res://core/content/schema/category_schema.gd")
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
		if candidate == null or not candidate is CategorySchema:
			failures.append("incompatible category schema type: expected CategorySchema Resource")
			continue
		var schema_failures: Array[String] = candidate.validate_schema()
		if not schema_failures.is_empty():
			var label: String = str(candidate.schema_id)
			if label.is_empty():
				label = "<unidentified-category-schema>"
			for failure in schema_failures:
				failures.append("%s: %s" % [label, failure])
			continue
		var schema_id: String = str(candidate.schema_id)
		var group: Array = grouped.get(schema_id, [])
		group.append(candidate)
		grouped[schema_id] = group

	var grouped_ids: Array[String] = []
	for key in grouped.keys():
		grouped_ids.append(str(key))
	grouped_ids.sort()
	for schema_id in grouped_ids:
		var group: Array = grouped[schema_id]
		if group.size() != 1:
			failures.append("duplicate category schema id: %s" % schema_id)
			continue
		_schemas_by_id[schema_id] = group[0]

	_validate_references(failures)
	_detect_cycles(failures)
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


func get_schema(schema_id: String):
	return _schemas_by_id.get(schema_id, null)


func schema_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in _schemas_by_id.keys():
		ids.append(str(key))
	ids.sort()
	return ids


func canonical_manifest() -> Array[Dictionary]:
	var manifest: Array[Dictionary] = []
	for schema_id in schema_ids():
		manifest.append(_schemas_by_id[schema_id].canonical_descriptor())
	return manifest


func expanded_categories(category_ids: Array) -> Array[String]:
	if not is_valid():
		return []
	var expanded: Dictionary = {}
	for raw_id in category_ids:
		var category_id: String = str(raw_id)
		if not SchemaId.is_valid_category(category_id) or not has_schema(category_id):
			return []
		_collect_category_and_parents(category_id, expanded)
	var result: Array[String] = []
	for key in expanded.keys():
		result.append(str(key))
	result.sort()
	return result


func is_category_or_descendant(declared_category_id: String, required_category_id: String) -> bool:
	if not has_schema(declared_category_id) or not has_schema(required_category_id):
		return false
	return expanded_categories([declared_category_id]).has(required_category_id)


func matches_required_categories(
	declared_category_ids: Array,
	required_category_ids: Array,
	require_all: bool = true
) -> bool:
	if not is_valid():
		return false
	if required_category_ids.is_empty():
		return true
	var expanded: Array[String] = expanded_categories(declared_category_ids)
	if expanded.is_empty() and not declared_category_ids.is_empty():
		return false

	var matches: int = 0
	for raw_required in required_category_ids:
		var required_id: String = str(raw_required)
		if not SchemaId.is_valid_category(required_id) or not has_schema(required_id):
			return false
		if expanded.has(required_id):
			matches += 1
		elif require_all:
			return false
	if require_all:
		return matches == required_category_ids.size()
	return matches > 0


func _validate_references(failures: Array[String]) -> void:
	for schema_id in schema_ids():
		var schema = _schemas_by_id[schema_id]
		var ordered_parents: Array[String] = []
		ordered_parents.append_array(schema.parent_ids)
		ordered_parents.sort()
		for parent_id in ordered_parents:
			if not _schemas_by_id.has(parent_id):
				failures.append("unknown category parent reference: %s -> %s" % [schema_id, parent_id])


func _detect_cycles(failures: Array[String]) -> void:
	var state: Dictionary = {}
	for schema_id in schema_ids():
		if int(state.get(schema_id, 0)) == 0:
			_visit_cycle(schema_id, state, [], failures)


func _visit_cycle(
	schema_id: String,
	state: Dictionary,
	path: Array[String],
	failures: Array[String]
) -> void:
	state[schema_id] = 1
	path.append(schema_id)
	var schema = _schemas_by_id[schema_id]
	var ordered_parents: Array[String] = []
	ordered_parents.append_array(schema.parent_ids)
	ordered_parents.sort()
	for parent_id in ordered_parents:
		if not _schemas_by_id.has(parent_id):
			continue
		var parent_state: int = int(state.get(parent_id, 0))
		if parent_state == 0:
			_visit_cycle(parent_id, state, path, failures)
		elif parent_state == 1:
			var start_index: int = path.find(parent_id)
			var cycle: Array[String] = []
			if start_index >= 0:
				for index in range(start_index, path.size()):
					cycle.append(path[index])
			cycle.append(parent_id)
			failures.append("category ancestry cycle: %s" % " -> ".join(cycle))
	path.pop_back()
	state[schema_id] = 2


func _collect_category_and_parents(category_id: String, expanded: Dictionary) -> void:
	if expanded.has(category_id):
		return
	expanded[category_id] = true
	var schema = _schemas_by_id[category_id]
	for parent_id in schema.parent_ids:
		_collect_category_and_parents(str(parent_id), expanded)
