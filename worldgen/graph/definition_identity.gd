extends RefCounted
class_name UnderworldDefinitionIdentity

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")


static func copy_address(address):
	if address == null:
		return null
	return StableAddress.parse(address.canonical_text())


static func id_value(address) -> String:
	var stable_id = StableId.from_address(address)
	return stable_id.value() if stable_id != null else ""


static func copy_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


static func copy_dictionary(values: Dictionary) -> Dictionary:
	return values.duplicate(true)
