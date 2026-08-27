extends RefCounted
class_name UnderworldCanonicalValue

## Project-owned canonical serialization used for deterministic fingerprints.
## It is intentionally not a save-file format.


static func encode(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return _frame("n", "")
		TYPE_BOOL:
			return _frame("b", "1" if bool(value) else "0")
		TYPE_INT:
			return _frame("i64", _int64_hex(int(value)))
		TYPE_FLOAT:
			return _encode_float(float(value))
		TYPE_STRING:
			return _frame("s", str(value).to_utf8_buffer().hex_encode())
		TYPE_VECTOR2I:
			var v2i: Vector2i = value
			return _frame("v2i", encode(v2i.x) + encode(v2i.y))
		TYPE_VECTOR3I:
			var v3i: Vector3i = value
			return _frame("v3i", encode(v3i.x) + encode(v3i.y) + encode(v3i.z))
		TYPE_VECTOR2:
			var v2: Vector2 = value
			return _frame("v2", _encode_float(v2.x) + _encode_float(v2.y))
		TYPE_VECTOR3:
			var v3: Vector3 = value
			return _frame(
				"v3",
				_encode_float(v3.x) + _encode_float(v3.y) + _encode_float(v3.z)
			)
		TYPE_AABB:
			var bounds: AABB = value
			return _frame("aabb", encode(bounds.position) + encode(bounds.size))
		TYPE_ARRAY:
			return _encode_array(value)
		TYPE_DICTIONARY:
			return _encode_dictionary(value)
		_:
			return ""


static func fingerprint(value: Variant) -> String:
	var canonical: String = encode(value)
	if canonical.is_empty():
		return ""
	return "sha256:" + canonical.sha256_text()


static func _encode_array(values: Array) -> String:
	var payload: String = _frame("count", _int64_hex(values.size()))
	for value in values:
		var encoded: String = encode(value)
		if encoded.is_empty():
			return ""
		payload += _frame("item", encoded)
	return _frame("a", payload)


static func _encode_dictionary(values: Dictionary) -> String:
	var encoded_keys: Array[String] = []
	var key_lookup: Dictionary = {}

	for key in values.keys():
		var encoded_key: String = encode(key)
		if encoded_key.is_empty() or key_lookup.has(encoded_key):
			return ""
		encoded_keys.append(encoded_key)
		key_lookup[encoded_key] = key

	encoded_keys.sort()
	var payload: String = _frame("count", _int64_hex(encoded_keys.size()))
	for encoded_key in encoded_keys:
		var encoded_value: String = encode(values[key_lookup[encoded_key]])
		if encoded_value.is_empty():
			return ""
		payload += _frame("key", encoded_key)
		payload += _frame("value", encoded_value)
	return _frame("d", payload)


static func _encode_float(value: float) -> String:
	if not is_finite(value):
		return ""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return _frame("f64", bytes.hex_encode())


static func _int64_hex(value: int) -> String:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	bytes.encode_s64(0, value)
	return bytes.hex_encode()


static func _frame(tag: String, payload: String) -> String:
	return "%s%d:%s" % [tag, payload.length(), payload]
