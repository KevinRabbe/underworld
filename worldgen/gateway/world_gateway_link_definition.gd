extends RefCounted
class_name UnderworldWorldGatewayLinkDefinition

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")

const STAGE_ID: String = "gateway.link"

var _stable_address
var _stable_id: String = ""
var _source_endpoint_id: String = ""
var _source_domain_id: String = ""
var _destination_endpoint_id: String = ""
var _destination_domain_id: String = ""
var _policy_id: String = ""
var _policy_revision: int = 0
var _bidirectional: bool = true
var _semantic_revision: int = 0
var _pairing_variant: int = 0
var _world_id: String = ""
var _generator_manifest_id: String = ""
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

var source_endpoint_id: String:
	get:
		return _source_endpoint_id
	set(_value):
		pass

var source_domain_id: String:
	get:
		return _source_domain_id
	set(_value):
		pass

var destination_endpoint_id: String:
	get:
		return _destination_endpoint_id
	set(_value):
		pass

var destination_domain_id: String:
	get:
		return _destination_domain_id
	set(_value):
		pass

var policy_id: String:
	get:
		return _policy_id
	set(_value):
		pass

var policy_revision: int:
	get:
		return _policy_revision
	set(_value):
		pass

var bidirectional: bool:
	get:
		return _bidirectional
	set(_value):
		pass

var semantic_revision: int:
	get:
		return _semantic_revision
	set(_value):
		pass

var pairing_variant: int:
	get:
		return _pairing_variant
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
	source_endpoint_id_value: String,
	source_domain_id_value: String,
	destination_endpoint_id_value: String,
	destination_domain_id_value: String,
	policy_id_value: String,
	policy_revision_value: int,
	bidirectional_value: bool,
	semantic_revision_value: int,
	pairing_variant_value: int,
	world_id_value: String,
	generator_manifest_id_value: String,
	provenance_value
) -> void:
	_stable_address = _copy_address(address_value)
	var stable = StableId.from_address(_stable_address)
	_stable_id = "" if stable == null else stable.value()
	_source_endpoint_id = source_endpoint_id_value
	_source_domain_id = source_domain_id_value
	_destination_endpoint_id = destination_endpoint_id_value
	_destination_domain_id = destination_domain_id_value
	_policy_id = policy_id_value
	_policy_revision = policy_revision_value
	_bidirectional = bidirectional_value
	_semantic_revision = semantic_revision_value
	_pairing_variant = pairing_variant_value
	_world_id = world_id_value
	_generator_manifest_id = generator_manifest_id_value
	if provenance_value != null and provenance_value.has_method("canonical_data"):
		_provenance_data = provenance_value.canonical_data().duplicate(true)
		_provenance_fingerprint = str(provenance_value.fingerprint)
	_fingerprint = _compute_fingerprint()


func provenance_snapshot() -> Dictionary:
	return _provenance_data.duplicate(true)


func canonical_data() -> Dictionary:
	return {
		"stable_address": "" if _stable_address == null else _stable_address.canonical_text(),
		"stable_id": _stable_id,
		"source_endpoint_id": _source_endpoint_id,
		"source_domain_id": _source_domain_id,
		"destination_endpoint_id": _destination_endpoint_id,
		"destination_domain_id": _destination_domain_id,
		"policy_id": _policy_id,
		"policy_revision": _policy_revision,
		"bidirectional": _bidirectional,
		"semantic_revision": _semantic_revision,
		"pairing_variant": _pairing_variant,
		"world_id": _world_id,
		"generator_manifest_id": _generator_manifest_id,
		"provenance": _provenance_data.duplicate(true),
		"provenance_fingerprint": _provenance_fingerprint,
	}


func canonical_text() -> String:
	return CanonicalValue.encode(canonical_data())


func resolve_other_endpoint(current_endpoint_id: String, current_domain_id: String) -> Dictionary:
	if StableId.parse(current_endpoint_id) == null:
		return {}
	if (
		current_endpoint_id == _source_endpoint_id
		and current_domain_id == _source_domain_id
	):
		return {
			"endpoint_id": _destination_endpoint_id,
			"domain_id": _destination_domain_id,
		}
	if (
		_bidirectional
		and current_endpoint_id == _destination_endpoint_id
		and current_domain_id == _destination_domain_id
	):
		return {
			"endpoint_id": _source_endpoint_id,
			"domain_id": _source_domain_id,
		}
	return {}


func validate() -> Array[String]:
	var failures: Array[String] = []
	if StableId.parse(_source_endpoint_id) == null:
		failures.append("Gateway link source endpoint StableId is not canonical")
	if StableId.parse(_destination_endpoint_id) == null:
		failures.append("Gateway link destination endpoint StableId is not canonical")
	if _source_endpoint_id == _destination_endpoint_id:
		failures.append("Gateway link endpoints must be distinct identities")
	if not _is_semantic_token(_source_domain_id, 64):
		failures.append("Gateway link requires bounded source domain id")
	if not _is_semantic_token(_destination_domain_id, 64):
		failures.append("Gateway link requires bounded destination domain id")
	if _source_domain_id == _destination_domain_id:
		failures.append("Gateway paired link requires distinct source/destination domains")
	if not _is_semantic_token(_policy_id, 64):
		failures.append("Gateway link requires bounded policy id")
	if _policy_revision <= 0:
		failures.append("Gateway link policy revision must be positive")
	if _semantic_revision <= 0:
		failures.append("Gateway link semantic revision must be positive")
	if _pairing_variant < 0 or _pairing_variant > 0xFFFFFFFF:
		failures.append("Gateway link pairing variant must fit u32")
	if _world_id.is_empty():
		failures.append("Gateway link requires world_id")
	if _generator_manifest_id.is_empty():
		failures.append("Gateway link requires generator_manifest_id")
	if _stable_address == null:
		failures.append("Gateway link requires StableAddress")
	else:
		var segments: Array[String] = _stable_address.segments()
		if segments.size() < 4 or segments[0] != "gateway" or segments[1] != "link":
			failures.append("Gateway link StableAddress namespace mismatch")
	var parsed_id = StableId.parse(_stable_id)
	if parsed_id == null:
		failures.append("Gateway link StableId is not canonical")
	elif _stable_address == null or not parsed_id.address().equals(_stable_address):
		failures.append("Gateway link StableId/address mismatch")
	if _provenance_data.is_empty():
		failures.append("Gateway link requires generation provenance")
	else:
		if str(_provenance_data.get("world_id", "")) != _world_id:
			failures.append("Gateway link provenance world mismatch")
		if str(_provenance_data.get("generator_manifest_id", "")) != _generator_manifest_id:
			failures.append("Gateway link provenance manifest mismatch")
		if str(_provenance_data.get("stage_id", "")) != STAGE_ID:
			failures.append("Gateway link provenance stage mismatch")
		if int(_provenance_data.get("stage_contract_revision", 0)) != _semantic_revision:
			failures.append("Gateway link provenance revision mismatch")
		var expected_provenance := "provenance1:" + CanonicalValue.fingerprint(_provenance_data)
		if _provenance_fingerprint != expected_provenance:
			failures.append("Gateway link provenance fingerprint mismatch")
	var expected_fingerprint: String = _compute_fingerprint()
	if _fingerprint.is_empty() or _fingerprint != expected_fingerprint:
		failures.append("Gateway link fingerprint is invalid")
	return failures


func _compute_fingerprint() -> String:
	var canonical: String = CanonicalValue.fingerprint(canonical_data())
	if canonical.is_empty():
		return ""
	return "gateway-link1:" + canonical


static func _copy_address(address):
	if address == null:
		return null
	return StableAddress.parse(address.canonical_text())


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
