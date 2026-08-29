extends RefCounted

const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")


static func run(failures: Array[String]) -> void:
	var large_vectors := PackedVector3Array()
	for index in range(1024):
		large_vectors.append(Vector3(
			float(index) * 0.125 - 32.0,
			float((index * 17) % 97) * 0.03125,
			-float(index % 43) * 0.0625
		))

	var large_ints := PackedInt32Array()
	for index in range(2048):
		large_ints.append(index * 37 - 4096)

	var corpus: Array = [
		null,
		true,
		false,
		0,
		-9223372036854775807,
		3.141592653589793,
		"PERF-002 canonical parity ✓",
		Vector2(-3.25, 9.5),
		Vector3(1.25, -2.5, 7.75),
		Vector2i(-17, 42),
		Vector3i(99, -7, 13),
		AABB(Vector3(-4.0, 2.0, 8.0), Vector3(16.0, 32.0, 64.0)),
		[1, "nested", Vector3(2.0, 4.0, 8.0), [false, -7, 0.125]],
		{
			"zeta": [Vector2i(3, 4), PackedInt32Array([5, 4, 3, 2, 1])],
			"alpha": {
				"bounds": AABB(Vector3(-1, -2, -3), Vector3(2, 4, 6)),
				"vectors": PackedVector3Array([Vector3.ZERO, Vector3.ONE, Vector3(-1, 2, -3)]),
			},
			"middle": PackedFloat64Array([0.0, -0.0, 0.5, -12.75, 1024.125]),
		},
		large_vectors,
		large_ints,
		{
			"large_vectors": large_vectors,
			"large_ints": large_ints,
			"nested": [
				{"b": 2, "a": 1},
				PackedVector2Array([Vector2(-1, 2), Vector2(3, -4)]),
				PackedByteArray([0, 1, 2, 127, 128, 255]),
			],
		},
	]

	for index in range(corpus.size()):
		var value = corpus[index]
		var reference: String = _legacy_encode(value)
		var optimized: String = CanonicalValue.encode(value)
		if reference != optimized:
			failures.append("PERF-002 canonical byte parity failed for corpus item %d" % index)
			continue
		var reference_fingerprint: String = "" if reference.is_empty() else "sha256:" + reference.sha256_text()
		if CanonicalValue.fingerprint(value) != reference_fingerprint:
			failures.append("PERF-002 canonical fingerprint parity failed for corpus item %d" % index)


## Exact pre-PERF-002 reference serializer. Its deliberately repeated String +=
## array accumulation is retained here only as a regression oracle.
static func _legacy_encode(value: Variant) -> String:
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
			return _frame("v2i", _legacy_encode(v2i.x) + _legacy_encode(v2i.y))
		TYPE_VECTOR3I:
			var v3i: Vector3i = value
			return _frame("v3i", _legacy_encode(v3i.x) + _legacy_encode(v3i.y) + _legacy_encode(v3i.z))
		TYPE_VECTOR2:
			var v2: Vector2 = value
			return _frame("v2", _encode_float(v2.x) + _encode_float(v2.y))
		TYPE_VECTOR3:
			var v3: Vector3 = value
			return _frame("v3", _encode_float(v3.x) + _encode_float(v3.y) + _encode_float(v3.z))
		TYPE_AABB:
			var bounds: AABB = value
			return _frame("aabb", _legacy_encode(bounds.position) + _legacy_encode(bounds.size))
		TYPE_ARRAY:
			return _legacy_encode_array(value)
		TYPE_DICTIONARY:
			return _legacy_encode_dictionary(value)
		TYPE_PACKED_VECTOR2_ARRAY:
			return _legacy_encode_array(Array(value))
		TYPE_PACKED_VECTOR3_ARRAY:
			return _legacy_encode_array(Array(value))
		TYPE_PACKED_INT32_ARRAY:
			return _legacy_encode_array(Array(value))
		TYPE_PACKED_FLOAT32_ARRAY:
			return _legacy_encode_array(Array(value))
		TYPE_PACKED_FLOAT64_ARRAY:
			return _legacy_encode_array(Array(value))
		TYPE_PACKED_BYTE_ARRAY:
			return _legacy_encode_array(Array(value))
		_:
			return ""


static func _legacy_encode_array(values: Array) -> String:
	var payload: String = _frame("count", _int64_hex(values.size()))
	for value in values:
		var encoded: String = _legacy_encode(value)
		if encoded.is_empty():
			return ""
		payload += _frame("item", encoded)
	return _frame("a", payload)


static func _legacy_encode_dictionary(values: Dictionary) -> String:
	var encoded_keys: Array[String] = []
	var key_lookup: Dictionary = {}
	for key in values.keys():
		var encoded_key: String = _legacy_encode(key)
		if encoded_key.is_empty() or key_lookup.has(encoded_key):
			return ""
		encoded_keys.append(encoded_key)
		key_lookup[encoded_key] = key
	encoded_keys.sort()
	var payload: String = _frame("count", _int64_hex(encoded_keys.size()))
	for encoded_key in encoded_keys:
		var encoded_value: String = _legacy_encode(values[key_lookup[encoded_key]])
		if encoded_value.is_empty():
			return ""
		payload += _frame("key", encoded_key)
		payload += _frame("value", encoded_value)
	return _frame("d", payload)


static func _encode_float(value: float) -> String:
	if not is_finite(value):
		return ""
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return _frame("f64", bytes.hex_encode())


static func _int64_hex(value: int) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_s64(0, value)
	return bytes.hex_encode()


static func _frame(tag: String, payload: String) -> String:
	return "%s%d:%s" % [tag, payload.length(), payload]
