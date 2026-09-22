extends RefCounted
class_name UnderworldGatewayEndpointDefinition

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")
const Provenance := preload("res://worldgen/pipeline/generation_provenance.gd")

const KIND_SOURCE: String = "source"
const KIND_DESTINATION: String = "destination"
const STAGE_SOURCE: String = "gateway.source_site"
const STAGE_DESTINATION: String = "gateway.destination_site"
const SOURCE_SEMANTIC_REVISION: int = 1
const DESTINATION_SEMANTIC_REVISION: int = 1

var _stable_address
var _stable_id: String = ""
var _endpoint_kind: String = ""
var _domain_id: String = ""
var _candidate_key: String = ""
var _locator: Dictionary = {}
var _semantic_revision: int = 0
var _world_id: String = ""
var _generator_manifest_id: String = ""
var _provenance_type_accepted: bool = false
var _provenance_data: Dictionary = {}
var _provenance_fingerprint: String = ""
var _fingerprint: String = ""

var stable_address:
	get:
		return _copy_address(_stable_address)
	set(_value):
		pass

var stable_id: String:
	get:
		return _stable_id
	set(_value):
		pass

var endpoint_kind: String:
	get:
		return _endpoint_kind
	set(_value):
		pass

var domain_id: String:
	get:
		return _domain_id
	set(_value):
		pass

var candidate_key: String:
	get:
		return _candidate_key
	set(_value):
		pass

var semantic_revision: int:
	get:
		return _semantic_revision
	set(_value):
		pass

var world_id: String:
	get:
		return _world_id
	set(_value):
		pass

var generator_manifest_id: String:
	get:
		return _generator_manifest_id
	set(_value):
		pass

var provenance_fingerprint: String:
	get:
		return _provenance_fingerprint
	set(_value):
		pass

var fingerprint: String:
	get:
		return _fingerprint
	set(_value):
		pass


func _init(
	address_value,
	endpoint_kind_value: String,
	domain_id_value: String,
	candidate_key_value: String,
	locator_value: Dictionary,
	semantic_revision_value: int,
	world_id_value: String,
	generator_manifest_id_value: String,
	provenance_value
) -> void:
	_stable_address = _copy_address(address_value)
	var stable = StableId.from_address(_stable_address)
	_stable_id = "" if stable == null else stable.value()
	_endpoint_kind = endpoint_kind_value
	_domain_id = domain_id_value
	_candidate_key = candidate_key_value
	_locator = locator_value.duplicate(true)
	_semantic_revision = semantic_revision_value
	_world_id = world_id_value
	_generator_manifest_id = generator_manifest_id_value
	_provenance_type_accepted = _is_exact_script_instance(provenance_value, Provenance)
	if _provenance_type_accepted:
		_provenance_data = provenance_value.canonical_data().duplicate(true)
		_provenance_fingerprint = str(provenance_value.fingerprint)
	_fingerprint = _compute_fingerprint()


func locator_snapshot() -> Dictionary:
	return _locator.duplicate(true)


func provenance_snapshot() -> Dictionary:
	return _provenance_data.duplicate(true)


func canonical_data() -> Dictionary:
	return {
		"stable_address": "" if _stable_address == null else _stable_address.canonical_text(),
		"stable_id": _stable_id,
		"endpoint_kind": _endpoint_kind,
		"domain_id": _domain_id,
		"candidate_key": _candidate_key,
		"locator": _locator.duplicate(true),
		"semantic_revision": _semantic_revision,
		"world_id": _world_id,
		"generator_manifest_id": _generator_manifest_id,
		"provenance": _provenance_data.duplicate(true),
		"provenance_fingerprint": _provenance_fingerprint,
	}


func canonical_text() -> String:
	return CanonicalValue.encode(canonical_data())


func validate() -> Array[String]:
	var failures: Array[String] = []
	if _endpoint_kind != KIND_SOURCE and _endpoint_kind != KIND_DESTINATION:
		failures.append("Gateway endpoint kind must be source or destination")
	if not _is_semantic_token(_domain_id, 64):
		failures.append("Gateway endpoint requires a bounded semantic domain id")
	if not _is_semantic_token(_candidate_key, 96):
		failures.append("Gateway endpoint requires a bounded semantic candidate key")
	var expected_revision: int = (
		SOURCE_SEMANTIC_REVISION
		if _endpoint_kind == KIND_SOURCE
		else DESTINATION_SEMANTIC_REVISION
	)
	if _semantic_revision != expected_revision:
		failures.append("Gateway endpoint semantic revision is unsupported")
	if _world_id.is_empty():
		failures.append("Gateway endpoint requires world_id")
	if _generator_manifest_id.is_empty():
		failures.append("Gateway endpoint requires generator_manifest_id")
	if _stable_address == null:
		failures.append("Gateway endpoint requires StableAddress")
	else:
		var segments: Array[String] = _stable_address.segments()
		if segments.size() != 8:
			failures.append("Gateway endpoint StableAddress must have the exact semantic shape")
		elif (
			segments[0] != "gateway"
			or segments[1] != _endpoint_kind
			or segments[2] != "domain"
			or segments[3] != _domain_id
			or segments[4] != "candidate"
			or segments[5] != _candidate_key
			or segments[6] != "revision"
			or segments[7] != str(_semantic_revision)
		):
			failures.append("Gateway endpoint StableAddress semantic payload mismatch")
	var parsed_id = StableId.parse(_stable_id)
	if parsed_id == null:
		failures.append("Gateway endpoint StableId is not canonical")
	elif _stable_address == null or not parsed_id.address().equals(_stable_address):
		failures.append("Gateway endpoint StableId/address mismatch")
	if _locator.is_empty() or CanonicalValue.encode(_locator).is_empty():
		failures.append("Gateway endpoint locator must be non-empty canonical data")
	var expected_stage: String = (
		STAGE_SOURCE if _endpoint_kind == KIND_SOURCE else STAGE_DESTINATION
	)
	if not _provenance_type_accepted:
		failures.append("Gateway endpoint requires exact GenerationProvenance")
	if _provenance_data.is_empty():
		failures.append("Gateway endpoint requires generation provenance")
	else:
		failures.append_array(_provenance_schema_failures(expected_stage))
		if str(_provenance_data.get("world_id", "")) != _world_id:
			failures.append("Gateway endpoint provenance world mismatch")
		if str(_provenance_data.get("generator_manifest_id", "")) != _generator_manifest_id:
			failures.append("Gateway endpoint provenance manifest mismatch")
		if str(_provenance_data.get("stage_id", "")) != expected_stage:
			failures.append("Gateway endpoint provenance stage mismatch")
		if int(_provenance_data.get("stage_contract_revision", 0)) != _semantic_revision:
			failures.append("Gateway endpoint provenance revision mismatch")
		var expected_provenance := "provenance1:" + CanonicalValue.fingerprint(_provenance_data)
		if _provenance_fingerprint != expected_provenance:
			failures.append("Gateway endpoint provenance fingerprint mismatch")
	var expected_fingerprint: String = _compute_fingerprint()
	if _fingerprint.is_empty() or _fingerprint != expected_fingerprint:
		failures.append("Gateway endpoint fingerprint is invalid")
	return failures


func _provenance_schema_failures(expected_stage: String) -> Array[String]:
	var failures: Array[String] = []
	var expected_keys: Array[String] = [
		"contract_revision",
		"world_id",
		"generator_manifest_id",
		"region_id",
		"region_address",
		"stage_id",
		"stage_contract_revision",
		"source_stage_fingerprints",
	]
	if _provenance_data.size() != expected_keys.size():
		failures.append("Gateway endpoint provenance schema mismatch")
	for key in expected_keys:
		if not _provenance_data.has(key):
			failures.append("Gateway endpoint provenance missing field: " + key)
	if int(_provenance_data.get("contract_revision", 0)) != Provenance.CONTRACT_REVISION:
		failures.append("Gateway endpoint provenance contract revision mismatch")
	if str(_provenance_data.get("stage_id", "")) != expected_stage:
		failures.append("Gateway endpoint provenance stage mismatch")
	if not str(_provenance_data.get("region_id", "")).is_empty():
		failures.append("Gateway endpoint provenance must be root-scoped")
	if not str(_provenance_data.get("region_address", "")).is_empty():
		failures.append("Gateway endpoint provenance must not carry a region address")
	var sources_variant = _provenance_data.get("source_stage_fingerprints", null)
	if typeof(sources_variant) != TYPE_ARRAY or not sources_variant.is_empty():
		failures.append("Gateway endpoint provenance ancestry must be empty")
	return failures


func _compute_fingerprint() -> String:
	var canonical: String = CanonicalValue.fingerprint(canonical_data())
	if canonical.is_empty():
		return ""
	return "gateway-endpoint1:" + canonical


static func _copy_address(address):
	if not _is_exact_script_instance(address, StableAddress):
		return null
	return StableAddress.parse(address.canonical_text())


static func _is_exact_script_instance(value, script) -> bool:
	return (
		typeof(value) == TYPE_OBJECT
		and value != null
		and value.get_script() == script
	)


static func _is_semantic_token(value: String, max_length: int) -> bool:
	if value.is_empty() or value.length() > max_length:
		return false
	for index in range(value.length()):
		var code: int = value.unicode_at(index)
		var allowed := (
			(code >= 48 and code <= 57)
			or (code >= 65 and code <= 90)
			or (code >= 97 and code <= 122)
			or code == 45
			or code == 46
			or code == 95
		)
		if not allowed:
			return false
	return true
