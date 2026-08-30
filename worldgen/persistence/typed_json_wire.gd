extends RefCounted

const INT64_WIRE_TAG: String = "$underworld_int64"


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
			if dictionary.has(INT64_WIRE_TAG):
				if dictionary.size() != 1:
					failures.append("%s has malformed %s integer tag" % [path, INT64_WIRE_TAG])
					return null
				var integer_variant: Variant = dictionary[INT64_WIRE_TAG]
				if not integer_variant is String:
					failures.append("%s integer tag must contain a decimal string" % path)
					return null
				var integer_text: String = str(integer_variant)
				if integer_text.is_empty() or not integer_text.is_valid_int():
					failures.append("%s integer tag is not a valid 64-bit decimal integer" % path)
					return null
				var integer_value: int = int(integer_text)
				if str(integer_value) != integer_text:
					failures.append("%s integer tag is not in canonical decimal form" % path)
					return null
				return integer_value
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
		TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return JSON.stringify(value)
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
				if key == INT64_WIRE_TAG:
					failures.append("%s uses reserved serialization key %s" % [path, INT64_WIRE_TAG])
					continue
				_validate_logical_value(dictionary[key_variant], "%s.%s" % [path, key], failures)
		_:
			failures.append("%s contains unsupported JSON Variant type %d" % [path, typeof(value)])


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {
		"success": false,
		"diagnostics": diagnostics,
	}
