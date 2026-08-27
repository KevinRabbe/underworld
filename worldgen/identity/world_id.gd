extends RefCounted
class_name UnderworldWorldId

const PREFIX: String = "wid1:"
const CONTRACT_TAG: String = "underworld-world-id-v1"
const LOWER_HEX: String = "0123456789abcdef"
const SCRIPT_PATH: String = "res://worldgen/identity/world_id.gd"

var _value: String


func _init(value: String) -> void:
	_value = value


static func from_seed(world_seed: int):
	var canonical_source: String = "%s|seed|%d" % [CONTRACT_TAG, world_seed]
	return load(SCRIPT_PATH).new(PREFIX + canonical_source.sha256_text())


static func parse(value: String):
	if not value.begins_with(PREFIX):
		return null
	var digest: String = value.substr(PREFIX.length())
	if digest.length() != 64:
		return null
	for index in range(digest.length()):
		var c: String = digest.substr(index, 1)
		if LOWER_HEX.find(c) < 0:
			return null
	return load(SCRIPT_PATH).new(value)


func value() -> String:
	return _value


func equals(other) -> bool:
	return other != null and _value == other.value()
