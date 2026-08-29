extends RefCounted


static func validate_state(value: Variant, path: String = "state") -> Array[String]:
	var failures: Array[String] = []
	_validate_value(value, path, failures)
	failures.sort()
	return failures


static func canonicalize(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var source: Dictionary = value
			var keys: Array[String] = []
			for raw_key in source.keys():
				keys.append(str(raw_key))
			keys.sort()
			var result: Dictionary = {}
			for key in keys:
				result[key] = canonicalize(source[key])
			return result
		TYPE_ARRAY:
			var result: Array = []
			for entry in value:
				result.append(canonicalize(entry))
			return result
		TYPE_STRING_NAME:
			return str(value)
		_:
			return value


static func canonical_json(value: Variant) -> String:
	return JSON.stringify(canonicalize(value), "", true, true)


static func _validate_value(value: Variant, path: String, failures: Array[String]) -> void:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return
		TYPE_ARRAY:
			var index: int = 0
			for entry in value:
				_validate_value(entry, "%s[%d]" % [path, index], failures)
				index += 1
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			for raw_key in dictionary.keys():
				if typeof(raw_key) != TYPE_STRING:
					failures.append("%s dictionary keys must be String values: %s" % [path, str(raw_key)])
					continue
				var key: String = str(raw_key)
				if key.is_empty() or key != key.strip_edges():
					failures.append("%s dictionary key must be non-empty and trimmed: %s" % [path, key])
					continue
				_validate_value(dictionary[raw_key], "%s.%s" % [path, key], failures)
		_:
			failures.append(
				"%s contains unsupported serialization type %s" % [path, type_string(typeof(value))]
			)
