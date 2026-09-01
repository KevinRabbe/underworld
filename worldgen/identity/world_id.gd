extends RefCounted
class_name UnderworldWorldId

const PREFIX: String = "wid1:"
const CONTRACT_TAG: String = "underworld-world-id-v1"
const CONTRACT_REVISION: int = 1
const LOWER_HEX: String = "0123456789abcdef"
const SCRIPT_PATH: String = "res://worldgen/identity/world_id.gd"

var _value: String


func _init(value: String) -> void:
	_value = value


static func from_seed(world_seed: int):
	return from_seed_with_contract(world_seed, current_contract_descriptor())


static func from_seed_with_contract(world_seed: int, contract_descriptor: Dictionary):
	if not runtime_compatibility_failures(contract_descriptor).is_empty():
		return null
	var canonical_source: String = "%s|seed|%d" % [
		str(contract_descriptor["contract_tag"]),
		world_seed,
	]
	return load(SCRIPT_PATH).new(
		str(contract_descriptor["prefix"]) + canonical_source.sha256_text()
	)


static func parse(value: String):
	return parse_with_contract(value, current_contract_descriptor())


static func parse_with_contract(value: String, contract_descriptor: Dictionary):
	if not validate_contract_descriptor_structure(contract_descriptor).is_empty():
		return null
	var prefix: String = str(contract_descriptor["prefix"])
	if not value.begins_with(prefix):
		return null
	var digest: String = value.substr(prefix.length())
	if digest.length() != 64:
		return null
	for index in range(digest.length()):
		var c: String = digest.substr(index, 1)
		if LOWER_HEX.find(c) < 0:
			return null
	return load(SCRIPT_PATH).new(value)


static func current_contract_descriptor() -> Dictionary:
	return {
		"revision": CONTRACT_REVISION,
		"prefix": PREFIX,
		"contract_tag": CONTRACT_TAG,
	}


static func supported_contract_descriptors() -> Array:
	return [current_contract_descriptor()]


static func validate_contract_descriptor_structure(contract_descriptor: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var required: Array[String] = ["revision", "prefix", "contract_tag"]
	for field in required:
		if not contract_descriptor.has(field):
			failures.append("WorldId contract is missing field: " + field)
	if not failures.is_empty():
		return failures

	if typeof(contract_descriptor["revision"]) != TYPE_INT or int(contract_descriptor["revision"]) <= 0:
		failures.append("WorldId contract revision must be a positive integer")
	if typeof(contract_descriptor["prefix"]) != TYPE_STRING or str(contract_descriptor["prefix"]).is_empty():
		failures.append("WorldId contract prefix must be non-empty")
	if typeof(contract_descriptor["contract_tag"]) != TYPE_STRING or str(contract_descriptor["contract_tag"]).is_empty():
		failures.append("WorldId contract tag must be non-empty")
	return failures


static func runtime_compatibility_failures(
	contract_descriptor: Dictionary,
	supported_contracts: Array = []
) -> Array[String]:
	var failures: Array[String] = validate_contract_descriptor_structure(contract_descriptor)
	if not failures.is_empty():
		return failures

	var support: Array = supported_contracts.duplicate(true)
	if support.is_empty():
		support = supported_contract_descriptors()

	for supported_variant in support:
		if typeof(supported_variant) != TYPE_DICTIONARY:
			continue
		var supported: Dictionary = supported_variant
		if (
			int(supported.get("revision", 0)) == int(contract_descriptor["revision"])
			and str(supported.get("prefix", "")) == str(contract_descriptor["prefix"])
			and str(supported.get("contract_tag", "")) == str(contract_descriptor["contract_tag"])
		):
			return []
	return [
		"WorldId runtime does not support captured contract revision=%s prefix=%s tag=%s"
		% [
			str(contract_descriptor["revision"]),
			str(contract_descriptor["prefix"]),
			str(contract_descriptor["contract_tag"]),
		]
	]


static func validate_exact_for_seed(
	world_seed: int,
	exact_world_id: String,
	contract_descriptor: Dictionary,
	supported_contracts: Array = []
) -> Array[String]:
	var failures: Array[String] = []
	if parse_with_contract(exact_world_id, contract_descriptor) == null:
		failures.append("WorldId value is malformed for captured contract")
		return failures

	failures.append_array(
		runtime_compatibility_failures(contract_descriptor, supported_contracts)
	)
	if not failures.is_empty():
		return failures

	var expected = from_seed_with_contract(world_seed, contract_descriptor)
	if expected == null or expected.value() != exact_world_id:
		failures.append("WorldId value does not match world_seed under captured contract")
	return failures


func value() -> String:
	return _value


func equals(other) -> bool:
	return other != null and _value == other.value()
