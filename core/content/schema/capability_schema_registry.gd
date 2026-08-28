extends RefCounted

const CapabilitySchema := preload("res://core/content/schema/capability_schema.gd")
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
		if candidate == null or not candidate is CapabilitySchema:
			failures.append("incompatible capability schema type: expected CapabilitySchema Resource")
			continue
		var schema_failures: Array[String] = candidate.validate_schema()
		if not schema_failures.is_empty():
			var label: String = str(candidate.schema_id)
			if label.is_empty():
				label = "<unidentified-capability-schema>"
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
			failures.append("duplicate capability schema id: %s" % schema_id)
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


func expanded_capabilities(capability_ids: Array) -> Array[String]:
	if not is_valid():
		return []
	var expanded: Dictionary = {}
	for raw_id in capability_ids:
		var capability_id: String = str(raw_id)
		if not SchemaId.is_valid_capability(capability_id) or not has_schema(capability_id):
			return []
		_collect_capability_and_composition(capability_id, expanded)
	var result: Array[String] = []
	for key in expanded.keys():
		result.append(str(key))
	result.sort()
	return result


func provides_capability(declared_capability_ids: Array, required_capability_id: String) -> bool:
	if not has_schema(required_capability_id):
		return false
	return expanded_capabilities(declared_capability_ids).has(required_capability_id)


func matches_required_capabilities(
	declared_capability_ids: Array,
	required_capability_ids: Array,
	require_all: bool = true
) -> bool:
	if not is_valid():
		return false
	if required_capability_ids.is_empty():
		return true
	var expanded: Array[String] = expanded_capabilities(declared_capability_ids)
	if expanded.is_empty() and not declared_capability_ids.is_empty():
		return false

	var matches: int = 0
	for raw_required in required_capability_ids:
		var required_id: String = str(raw_required)
		if not SchemaId.is_valid_capability(required_id) or not has_schema(required_id):
			return false
		if expanded.has(required_id):
			matches += 1
		elif require_all:
			return false
	if require_all:
		return matches == required_capability_ids.size()
	return matches > 0


func _validate_references(failures: Array[String]) -> void:
	for schema_id in schema_ids():
		var schema = _schemas_by_id[schema_id]
		var ordered_composition: Array[String] = []
		ordered_composition.append_array(schema.composed_capability_ids)
		ordered_composition.sort()
		for capability_id in ordered_composition:
			if not _schemas_by_id.has(capability_id):
				failures.append("unknown capability composition reference: %s -> %s" % [schema_id, capability_id])


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
	var ordered_composition: Array[String] = []
	ordered_composition.append_array(schema.composed_capability_ids)
	ordered_composition.sort()
	for capability_id in ordered_composition:
		if not _schemas_by_id.has(capability_id):
			continue
		var child_state: int = int(state.get(capability_id, 0))
		if child_state == 0:
			_visit_cycle(capability_id, state, path, failures)
		elif child_state == 1:
			var start_index: int = path.find(capability_id)
			var cycle: Array[String] = []
			if start_index >= 0:
				for index in range(start_index, path.size()):
					cycle.append(path[index])
			cycle.append(capability_id)
			failures.append("capability composition cycle: %s" % " -> ".join(cycle))
	path.pop_back()
	state[schema_id] = 2


func _collect_capability_and_composition(capability_id: String, expanded: Dictionary) -> void:
	if expanded.has(capability_id):
		return
	expanded[capability_id] = true
	var schema = _schemas_by_id[capability_id]
	for composed_id in schema.composed_capability_ids:
		_collect_capability_and_composition(str(composed_id), expanded)
