extends RefCounted

const INT64_WIRE_TAG: String = "$underworld_int64"
const VECTOR2_WIRE_TAG: String = "$underworld_vector2"
const VECTOR2I_WIRE_TAG: String = "$underworld_vector2i"
const VECTOR3_WIRE_TAG: String = "$underworld_vector3"
const VECTOR3I_WIRE_TAG: String = "$underworld_vector3i"
const _RESERVED_WIRE_TAGS: Array[String] = [
	INT64_WIRE_TAG,
	VECTOR2_WIRE_TAG,
	VECTOR2I_WIRE_TAG,
	VECTOR3_WIRE_TAG,
	VECTOR3I_WIRE_TAG,
]


static func encode(value: Variant, label: String = "value") -> Dictionary:
	var failures: Array[String] = []
	_validate_logical_value(value, label, failures)
	if not failures.is_empty():
		return _failure(failures)
	return {
		"success": true,
		"json": encode_json_value(to_wire_value(value)),
		"diagnostics": [],
	}


static func decode(json_text: String, label: String = "value") -> Dictionary:
	if json_text.is_empty():
		return _failure(["%s typed JSON is empty" % label])
	var json := JSON.new()
	var error: Error = json.parse(json_text)
	if error != OK:
		return _failure([
			"%s typed JSON parse failed at line %d: %s" % [
				label,
				json.get_error_line(),
				json.get_error_message(),
			]
		])
	var failures: Array[String] = []
	var value: Variant = from_wire_value(json.data, label, failures)
	if not failures.is_empty():
		return _failure(failures)
	_validate_logical_value(value, label, failures)
	if not failures.is_empty():
		return _failure(failures)
	return {
		"success": true,
		"value": value,
		"diagnostics": [],
	}


static func to_wire_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT:
			return {INT64_WIRE_TAG: str(int(value))}
		TYPE_STRING_NAME:
			return str(value)
		TYPE_VECTOR2:
			var vector: Vector2 = value
			return {VECTOR2_WIRE_TAG: [vector.x, vector.y]}
		TYPE_VECTOR2I:
			var vector: Vector2i = value
			return {VECTOR2I_WIRE_TAG: [to_wire_value(vector.x), to_wire_value(vector.y)]}
		TYPE_VECTOR3:
			var vector: Vector3 = value
			return {VECTOR3_WIRE_TAG: [vector.x, vector.y, vector.z]}
		TYPE_VECTOR3I:
			var vector: Vector3i = value
			return {
				VECTOR3I_WIRE_TAG: [
					to_wire_value(vector.x),
					to_wire_value(vector.y),
					to_wire_value(vector.z),
				]
			}
		TYPE_ARRAY:
			var result: Array = []
			for item in value:
				result.append(to_wire_value(item))
			return result
		TYPE_DICTIONARY:
			var result: Dictionary = {}
			for key_variant in value.keys():
				var key: String = str(key_variant)
				result[key] = to_wire_value(value[key_variant])
			return result
		_:
			return value


static func from_wire_value(
	value: Variant,
	path: String,
	failures: Array[String]
) -> Variant:
	match typeof(value):
		TYPE_ARRAY:
			var result: Array = []
			for index in range(value.size()):
				result.append(from_wire_value(value[index], "%s[%d]" % [path, index], failures))
			return result
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			var reserved_tag: String = _present_reserved_tag(dictionary)
			if not reserved_tag.is_empty():
				if dictionary.size() != 1:
					failures.append("%s has malformed reserved serialization tag %s" % [path, reserved_tag])
					return null
				match reserved_tag:
					INT64_WIRE_TAG:
						return _decode_int64_tag(dictionary[reserved_tag], path, failures)
					VECTOR2_WIRE_TAG:
						return _decode_vector2_tag(dictionary[reserved_tag], path, failures)
					VECTOR2I_WIRE_TAG:
						return _decode_vector2i_tag(dictionary[reserved_tag], path, failures)
					VECTOR3_WIRE_TAG:
						return _decode_vector3_tag(dictionary[reserved_tag], path, failures)
					VECTOR3I_WIRE_TAG:
						return _decode_vector3i_tag(dictionary[reserved_tag], path, failures)
			var result: Dictionary = {}
			for key_variant in dictionary.keys():
				if not key_variant is String:
					failures.append("%s contains non-string JSON key" % path)
					continue
				var key: String = str(key_variant)
				result[key] = from_wire_value(
					dictionary[key_variant],
					"%s.%s" % [path, key],
					failures
				)
			return result
		_:
			return value


static func encode_json_value(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if bool(value) else "false"
		TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return JSON.stringify(str(value) if value is StringName else value)
		TYPE_ARRAY:
			var array_parts := PackedStringArray()
			for item in value:
				array_parts.append(encode_json_value(item))
			return "[" + ",".join(array_parts) + "]"
		TYPE_DICTIONARY:
			var keys: Array[String] = []
			for key_variant in value.keys():
				keys.append(str(key_variant))
			keys.sort()
			var object_parts := PackedStringArray()
			for key in keys:
				object_parts.append(JSON.stringify(key) + ":" + encode_json_value(value[key]))
			return "{" + ",".join(object_parts) + "}"
		_:
			return "null"


static func _validate_logical_value(
	value: Variant,
	path: String,
	failures: Array[String]
) -> void:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME:
			return
		TYPE_FLOAT:
			var number: float = float(value)
			if is_nan(number) or is_inf(number):
				failures.append("%s contains non-finite float" % path)
		TYPE_VECTOR2:
			var vector2_value: Vector2 = value
			if not is_finite(vector2_value.x) or not is_finite(vector2_value.y):
				failures.append("%s contains non-finite Vector2 component" % path)
		TYPE_VECTOR2I:
			return
		TYPE_VECTOR3:
			var vector3_value: Vector3 = value
			if (
				not is_finite(vector3_value.x)
				or not is_finite(vector3_value.y)
				or not is_finite(vector3_value.z)
			):
				failures.append("%s contains non-finite Vector3 component" % path)
		TYPE_VECTOR3I:
			return
		TYPE_ARRAY:
			for index in range(value.size()):
				_validate_logical_value(value[index], "%s[%d]" % [path, index], failures)
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			for key_variant in dictionary.keys():
				if not key_variant is String:
					failures.append("%s contains non-string JSON key" % path)
					continue
				var key: String = str(key_variant)
				if _RESERVED_WIRE_TAGS.has(key):
					failures.append("%s uses reserved serialization key %s" % [path, key])
					continue
				_validate_logical_value(dictionary[key_variant], "%s.%s" % [path, key], failures)
		_:
			failures.append("%s contains unsupported JSON Variant type %d" % [path, typeof(value)])


static func _present_reserved_tag(dictionary: Dictionary) -> String:
	for tag in _RESERVED_WIRE_TAGS:
		if dictionary.has(tag):
			return tag
	return ""


static func _decode_int64_tag(value: Variant, path: String, failures: Array[String]) -> Variant:
	if not value is String:
		failures.append("%s integer tag must contain a decimal string" % path)
		return null
	var integer_text: String = str(value)
	if integer_text.is_empty() or not integer_text.is_valid_int():
		failures.append("%s integer tag is not a valid 64-bit decimal integer" % path)
		return null
	var integer_value: int = int(integer_text)
	if str(integer_value) != integer_text:
		failures.append("%s integer tag is not in canonical decimal form" % path)
		return null
	return integer_value


static func _decode_vector2_tag(value: Variant, path: String, failures: Array[String]) -> Variant:
	var components: Array = _decode_vector_components(value, 2, path, failures, false)
	if components.size() != 2:
		return null
	return Vector2(float(components[0]), float(components[1]))


static func _decode_vector2i_tag(value: Variant, path: String, failures: Array[String]) -> Variant:
	var components: Array = _decode_vector_components(value, 2, path, failures, true)
	if components.size() != 2:
		return null
	return Vector2i(int(components[0]), int(components[1]))


static func _decode_vector3_tag(value: Variant, path: String, failures: Array[String]) -> Variant:
	var components: Array = _decode_vector_components(value, 3, path, failures, false)
	if components.size() != 3:
		return null
	return Vector3(float(components[0]), float(components[1]), float(components[2]))


static func _decode_vector3i_tag(value: Variant, path: String, failures: Array[String]) -> Variant:
	var components: Array = _decode_vector_components(value, 3, path, failures, true)
	if components.size() != 3:
		return null
	return Vector3i(int(components[0]), int(components[1]), int(components[2]))


static func _decode_vector_components(
	value: Variant,
	expected_size: int,
	path: String,
	failures: Array[String],
	require_int: bool
) -> Array:
	if not value is Array or value.size() != expected_size:
		failures.append("%s vector tag requires exactly %d components" % [path, expected_size])
		return []
	var components: Array = []
	for index in range(expected_size):
		var component: Variant = from_wire_value(value[index], "%s[%d]" % [path, index], failures)
		if require_int:
			if typeof(component) != TYPE_INT:
				failures.append("%s vector integer component %d must be int" % [path, index])
				continue
			components.append(component)
			continue
		if typeof(component) != TYPE_INT and typeof(component) != TYPE_FLOAT:
			failures.append("%s vector component %d must be numeric" % [path, index])
			continue
		var number: float = float(component)
		if not is_finite(number):
			failures.append("%s vector component %d must be finite" % [path, index])
			continue
		components.append(number)
	return components


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {
		"success": false,
		"diagnostics": diagnostics,
	}
