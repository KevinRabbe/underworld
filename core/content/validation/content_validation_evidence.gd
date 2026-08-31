extends RefCounted

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ContentFamilyValidator := preload("res://core/content/validation/content_family_validator.gd")
const ReferenceCyclePolicy := preload("res://core/content/validation/content_reference_cycle_policy.gd")

const EVIDENCE_REVISION := 1

var _success: bool = false
var _diagnostics: Array = []
var _validated_definition_ids: Array[String] = []
var _snapshot_descriptor: Dictionary = {}
var _snapshot_fingerprint: String = ""

# These are verification sources, not mutation authority. The evidence owns a
# canonical snapshot copy while retaining the exact validation authorities so
# later consumers can detect semantic changes made underneath the proof.
var _category_registry_source
var _capability_registry_source
var _family_validator_sources: Array = []
var _cycle_policy_source
var _semantic_context_source


func _init(
	p_success: bool,
	p_diagnostics: Array,
	p_validated_definition_ids: Array,
	p_snapshot_descriptor: Dictionary,
	p_category_registry = null,
	p_capability_registry = null,
	p_family_validators: Array = [],
	p_cycle_policy = null,
	p_semantic_context = null
) -> void:
	_success = p_success
	_diagnostics = p_diagnostics.duplicate(true)
	for raw_id in p_validated_definition_ids:
		_validated_definition_ids.append(str(raw_id))
	_validated_definition_ids.sort()
	_snapshot_descriptor = p_snapshot_descriptor.duplicate(true)
	_snapshot_fingerprint = fingerprint_for_descriptor(_snapshot_descriptor)
	_category_registry_source = p_category_registry
	_capability_registry_source = p_capability_registry
	_family_validator_sources.append_array(p_family_validators)
	_cycle_policy_source = p_cycle_policy
	_semantic_context_source = p_semantic_context


func succeeded() -> bool:
	return _success


func diagnostics() -> Array:
	return _diagnostics.duplicate(true)


func validated_definition_ids() -> Array[String]:
	var result: Array[String] = []
	result.append_array(_validated_definition_ids)
	return result


func covers(content_id: String) -> bool:
	return _success and _validated_definition_ids.has(content_id)


func snapshot_descriptor() -> Dictionary:
	return _snapshot_descriptor.duplicate(true)


func fingerprint() -> String:
	return _snapshot_fingerprint


func verification_failures(
	content_registry,
	required_content_id: String = "",
	current_context: Dictionary = {}
) -> Array[String]:
	var failures: Array[String] = []
	if not _success:
		failures.append("validation evidence is not successful authority")
		return failures
	if content_registry == null or not content_registry is ContentRegistry:
		failures.append("validation evidence verification requires ContentRegistry")
		return failures
	if not content_registry.is_valid():
		for failure in content_registry.diagnostics():
			failures.append("content registry: %s" % failure)
		failures.sort()
		return failures
	if not required_content_id.is_empty() and not covers(required_content_id):
		failures.append(
			"validation evidence does not cover content id: %s" % required_content_id
		)
		return failures

	var category_registry = current_context.get(
		"category_registry",
		_category_registry_source
	)
	var capability_registry = current_context.get(
		"capability_registry",
		_capability_registry_source
	)
	var family_validators = current_context.get(
		"family_validators",
		_family_validator_sources
	)
	var cycle_policy = current_context.get("cycle_policy", _cycle_policy_source)
	var semantic_context = current_context.get(
		"semantic_context",
		_semantic_context_source
	)

	if category_registry == null or not category_registry is CategorySchemaRegistry:
		failures.append("validation evidence verification requires CategorySchemaRegistry")
	if capability_registry == null or not capability_registry is CapabilitySchemaRegistry:
		failures.append("validation evidence verification requires CapabilitySchemaRegistry")
	if not family_validators is Array:
		failures.append("validation evidence verification requires family validator array")
	if cycle_policy == null or not cycle_policy is ReferenceCyclePolicy:
		failures.append("validation evidence verification requires ContentReferenceCyclePolicy")
	if not failures.is_empty():
		failures.sort()
		return failures

	var current_snapshot: Dictionary = _snapshot_descriptor.duplicate(true)
	current_snapshot["definitions"] = content_registry.canonical_manifest()
	current_snapshot["category_schema_manifest"] = category_registry.canonical_manifest()
	current_snapshot["capability_schema_manifest"] = capability_registry.canonical_manifest()
	current_snapshot["family_validators"] = family_validator_descriptors(family_validators)
	current_snapshot["cycle_policy"] = cycle_policy.canonical_descriptor()
	current_snapshot["semantic_context"] = semantic_context_descriptor(semantic_context)

	var current_fingerprint: String = fingerprint_for_descriptor(current_snapshot)
	if current_fingerprint != _snapshot_fingerprint:
		failures.append(
			"validation evidence snapshot mismatch: expected %s, got %s" % [
				_snapshot_fingerprint,
				current_fingerprint,
			]
		)
	return failures


static func definition_descriptors(definitions: Array) -> Array:
	var descriptors: Array = []
	for candidate in definitions:
		if candidate == null or typeof(candidate) != TYPE_OBJECT:
			descriptors.append({"invalid_definition": true})
			continue
		if not candidate.has_method("canonical_descriptor"):
			descriptors.append({"invalid_definition": true})
			continue
		descriptors.append(candidate.canonical_descriptor().duplicate(true))
	descriptors.sort_custom(func(a, b): return canonical_text(a) < canonical_text(b))
	return descriptors


static func family_validator_descriptors(validators: Array) -> Array:
	var descriptors: Array = []
	for validator in validators:
		if validator == null or not validator is ContentFamilyValidator:
			descriptors.append({"invalid_family_validator": true})
			continue
		if not validator.has_method("canonical_evidence_descriptor"):
			descriptors.append({
				"definition_family": str(validator.definition_family),
				"missing_evidence_descriptor": true,
			})
			continue
		descriptors.append(validator.canonical_evidence_descriptor().duplicate(true))
	descriptors.sort_custom(func(a, b): return canonical_text(a) < canonical_text(b))
	return descriptors


static func semantic_context_descriptor(context) -> Variant:
	if context == null:
		return null
	if context is Dictionary or context is Array:
		return _canonical_variant(context)
	if typeof(context) != TYPE_OBJECT:
		return {"unsupported_semantic_context_type": str(typeof(context))}
	if context.has_method("canonical_manifest"):
		return context.canonical_manifest().duplicate(true)
	if context.has_method("canonical_descriptor"):
		return context.canonical_descriptor().duplicate(true)
	return {"unsupported_semantic_context_type": str(typeof(context))}


static func fingerprint_for_descriptor(descriptor: Dictionary) -> String:
	return canonical_text(descriptor).sha256_text()


static func canonical_text(value: Variant) -> String:
	return JSON.stringify(_canonical_variant(value))


static func _canonical_variant(value: Variant) -> Variant:
	if value is Dictionary:
		var by_key: Dictionary = {}
		for raw_key in value.keys():
			by_key[str(raw_key)] = value[raw_key]
		var keys: Array[String] = []
		for key in by_key.keys():
			keys.append(str(key))
		keys.sort()
		var result: Dictionary = {}
		for key in keys:
			result[key] = _canonical_variant(by_key[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_canonical_variant(item))
		return result
	if typeof(value) == TYPE_STRING_NAME:
		return str(value)
	return value
