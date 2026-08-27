extends RefCounted
class_name UnderworldStableId

const StableAddressScript := preload("res://worldgen/identity/stable_address.gd")

const SCHEMA_VERSION: int = 1
const PREFIX: String = "sid1:"

var _address


func _init(address) -> void:
	_address = address


static func from_address(address):
	if address == null:
		return null
	# Reparse the canonical address so StableId never keeps a mutable/transient
	# reference supplied by caller code.
	var canonical_address = StableAddressScript.parse(address.canonical_text())
	if canonical_address == null:
		return null
	return UnderworldStableId.new(canonical_address)


static func parse(value: String):
	if not value.begins_with(PREFIX):
		return null
	var address_text: String = value.substr(PREFIX.length())
	var address = StableAddressScript.parse(address_text)
	if address == null:
		return null
	var stable_id = UnderworldStableId.new(address)
	if stable_id.value() != value:
		return null
	return stable_id


func value() -> String:
	return PREFIX + _address.canonical_text()


func debug_text() -> String:
	return value()


func address():
	return StableAddressScript.parse(_address.canonical_text())


func equals(other) -> bool:
	return other != null and value() == other.value()


func less_than(other) -> bool:
	if other == null:
		return false
	return value() < other.value()


static func canonical_pair(id_a, id_b) -> Array[String]:
	if id_a == null or id_b == null:
		return []
	var a: String = id_a.value()
	var b: String = id_b.value()
	if a <= b:
		return [a, b]
	return [b, a]
