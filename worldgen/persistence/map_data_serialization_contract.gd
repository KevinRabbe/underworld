extends RefCounted
class_name UnderworldMapDataSerializationContract

const WorldIdScript := preload("res://worldgen/identity/world_id.gd")
const WorldDeltaStoreScript := preload("res://worldgen/persistence/world_delta_store.gd")

const SAVE_SCHEMA_VERSION: int = 3
const SCHEMA_NAME: String = "underworld-map-save-v3"
const INT64_WIRE_TAG: String = "$underworld_int64"
const REQUIRED_TOP_LEVEL_KEYS: Array[String] = ["deltas", "save_schema_version", "schema", "world"]
const REQUIRED_WORLD_KEYS: Array[String] = [
	"generator_manifest_canonical",
	"generator_manifest_id",
	"world_id",
	"world_seed",
]
const REQUIRED_DELTA_KEYS: Array[String] = [
	"destroyed_objects",
	"object_state",
	"player_created_objects",
	"special_location_state",
	"terrain_delta_index",
]


static func build_envelope(context, delta_store) -> Dictionary:
	var failures: Array[String] = []
	if context == null:
		failures.append("Map serialization requires WorldGenerationContext")
	if delta_store == null:
		failures.append("Map serialization requires WorldDeltaStore")
	if not failures.is_empty():
		return _failure(failures)

	failures.append_array(context.validate())
	if not failures.is_empty():
		return _failure(failures)

	var header: Dictionary = context.canonical_header()
	var envelope: Dictionary = {
		"schema": SCHEMA_NAME,
		"save_schema_version": SAVE_SCHEMA_VERSION,
		"world": {
			# Identity-critical 64-bit seeds are serialized as canonical decimal
			# strings so JSON consumers cannot round them through IEEE-754 doubles.
			"world_seed": str(int(header.get("world_seed", 0))),
			"world_id": str(header.get("world_id", "")),
			"generator_manifest_id": str(header.get("generator_manifest_id", "")),
			"generator_manifest_canonical": str(
				header.get("generator_manifest_canonical", "")
			),
		},
		"deltas": delta_store.snapshot(),
	}
	failures.append_array(validate_envelope(envelope))
	if not failures.is_empty():
		return _failure(failures)
	return {
		"success": true,
		"envelope": envelope,
		"diagnostics": [],
	}


static func validate_envelope(envelope: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	_validate_exact_keys("root", envelope, REQUIRED_TOP_LEVEL_KEYS, failures)
	if str(envelope.get("schema", "")) != SCHEMA_NAME:
		failures.append("Unsupported map save schema name")
	var schema_version_variant = envelope.get("save_schema_version", null)
	if not schema_version_variant is int:
		failures.append("save_schema_version must be an integer")
	elif int(schema_version_variant) != SAVE_SCHEMA_VERSION:
		failures.append(
			"Unsupported save_schema_version: %s" % str(schema_version_variant)
		)

	var world_variant = envelope.get("world", null)
	if not world_variant is Dictionary:
		failures.append("Map save world header must be a Dictionary")
	else:
		_validate_world_header(world_variant, failures)

	var deltas_variant = envelope.get("deltas", null)
	if not deltas_variant is Dictionary:
		failures.append("Map save deltas must be a Dictionary")
	else:
		_validate_exact_keys("deltas", deltas_variant, REQUIRED_DELTA_KEYS, failures)
		_validate_json_value(deltas_variant, "deltas", failures)

	return failures


static func canonical_json(envelope: Dictionary) -> Dictionary:
	var failures: Array[String] = validate_envelope(envelope)
	if not failures.is_empty():
		return _failure(failures)

	# Godot's JSON parser materializes JSON numbers as floats. Preserve the
	# logical int/float distinction inside durable deltas with a small typed
	# wire representation, while keeping the in-memory envelope ergonomic.
	var wire_envelope: Dictionary = envelope.duplicate(true)
	wire_envelope["deltas"] = _to_wire_value(envelope["deltas"])
	return {
		"success": true,
		"json": _encode_json_value(wire_envelope),
		"diagnostics": [],
	}


static func encode(context, delta_store) -> Dictionary:
	var built: Dictionary = build_envelope(context, delta_store)
	if not bool(built.get("success", false)):
		return built
	var encoded: Dictionary = canonical_json(built["envelope"])
	if not bool(encoded.get("success", false)):
		return encoded
	return {
		"success": true,
		"envelope": built["envelope"],
		"json": encoded["json"],
		"diagnostics": [],
	}


static func decode(json_text: String) -> Dictionary:
	if json_text.is_empty():
		return _failure(["Map save JSON is empty"])
	var json := JSON.new()
	var error: Error = json.parse(json_text)
	if error != OK:
		return _failure([
			"Map save JSON parse failed at line %d: %s" % [
				json.get_error_line(),
				json.get_error_message(),
			]
		])
	if not json.data is Dictionary:
		return _failure(["Map save JSON root must be an object"])

	var envelope: Dictionary = json.data.duplicate(true)
	var failures: Array[String] = []
	_normalize_wire_schema_version(envelope, failures)
	if envelope.get("deltas", null) is Dictionary:
		envelope["deltas"] = _from_wire_value(envelope["deltas"], "deltas", failures)
	if not failures.is_empty():
		return _failure(failures)

	failures.append_array(validate_envelope(envelope))
	if not failures.is_empty():
		return _failure(failures)
	return {
		"success": true,
		"envelope": envelope,
		"diagnostics": [],
	}


static func load_delta_store(envelope: Dictionary) -> Dictionary:
	var failures: Array[String] = validate_envelope(envelope)
	if not failures.is_empty():
		return _failure(failures)
	var delta_store = WorldDeltaStoreScript.new()
	failures.append_array(delta_store.load_modern_delta_payload(envelope["deltas"]))
	if not failures.is_empty():
		return _failure(failures)
	return {
		"success": true,
		"delta_store": delta_store,
		"world": envelope["world"].duplicate(true),
		"diagnostics": [],
	}


static func _validate_world_header(world: Dictionary, failures: Array[String]) -> void:
	_validate_exact_keys("world", world, REQUIRED_WORLD_KEYS, failures)
	var world_seed_variant = world.get("world_seed", null)
	if not world_seed_variant is String:
		failures.append("world.world_seed must be a canonical decimal string")
		return
	var world_seed_text: String = str(world_seed_variant)
	if world_seed_text.is_empty() or not world_seed_text.is_valid_int():
		failures.append("world.world_seed is not a valid 64-bit decimal integer")
		return
	var world_seed: int = int(world_seed_text)
	if str(world_seed) != world_seed_text:
		failures.append("world.world_seed is not in canonical decimal form")
		return

	var world_id: String = str(world.get("world_id", ""))
	if WorldIdScript.parse(world_id) == null:
		failures.append("world.world_id is invalid")
	elif WorldIdScript.from_seed(world_seed).value() != world_id:
		failures.append("world.world_id does not match world_seed")

	var manifest_canonical: String = str(world.get("generator_manifest_canonical", ""))
	var manifest_id: String = str(world.get("generator_manifest_id", ""))
	if manifest_canonical.is_empty() or not manifest_canonical.begins_with("gm1|"):
		failures.append("world.generator_manifest_canonical is missing or unsupported")
	else:
		var expected_manifest_id: String = "gm-sha256:" + manifest_canonical.sha256_text()
		if manifest_id != expected_manifest_id:
			failures.append("world.generator_manifest_id does not match manifest contents")


static func _validate_exact_keys(
	label: String,
	value: Dictionary,
	required_keys: Array[String],
	failures: Array[String]
) -> void:
	var actual: Array[String] = []
	for key_variant in value.keys():
		if not key_variant is String:
			failures.append("%s contains a non-string key" % label)
			continue
		actual.append(str(key_variant))
	actual.sort()
	var expected: Array[String] = required_keys.duplicate()
	expected.sort()
	if actual != expected:
		failures.append("%s keys do not match schema expected=%s actual=%s" % [
			label,
			str(expected),
			str(actual),
		])


static func _validate_json_value(value, path: String, failures: Array[String]) -> void:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return
		TYPE_ARRAY:
			for index in range(value.size()):
				_validate_json_value(value[index], "%s[%d]" % [path, index], failures)
		TYPE_DICTIONARY:
			for key_variant in value.keys():
				if not key_variant is String:
					failures.append("%s contains non-string JSON key" % path)
					continue
				var key: String = str(key_variant)
				if key == INT64_WIRE_TAG:
					failures.append("%s uses reserved serialization key %s" % [path, INT64_WIRE_TAG])
					continue
				_validate_json_value(value[key_variant], "%s.%s" % [path, key], failures)
		_:
			failures.append("%s contains unsupported JSON Variant type %d" % [path, typeof(value)])


static func _to_wire_value(value):
	match typeof(value):
		TYPE_INT:
			return {INT64_WIRE_TAG: str(int(value))}
		TYPE_ARRAY:
			var result: Array = []
			for item in value:
				result.append(_to_wire_value(item))
			return result
		TYPE_DICTIONARY:
			var result: Dictionary = {}
			for key_variant in value.keys():
				var key: String = str(key_variant)
				result[key] = _to_wire_value(value[key_variant])
			return result
		_:
			return value


static func _from_wire_value(value, path: String, failures: Array[String]):
	match typeof(value):
		TYPE_ARRAY:
			var result: Array = []
			for index in range(value.size()):
				result.append(_from_wire_value(value[index], "%s[%d]" % [path, index], failures))
			return result
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			if dictionary.has(INT64_WIRE_TAG):
				if dictionary.size() != 1:
					failures.append("%s has malformed %s integer tag" % [path, INT64_WIRE_TAG])
					return null
				var integer_variant = dictionary[INT64_WIRE_TAG]
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
				result[key] = _from_wire_value(
					dictionary[key_variant],
					"%s.%s" % [path, key],
					failures
				)
			return result
		_:
			return value


static func _normalize_wire_schema_version(envelope: Dictionary, failures: Array[String]) -> void:
	var version_variant = envelope.get("save_schema_version", null)
	if version_variant is int:
		return
	if version_variant is float:
		var version_float: float = float(version_variant)
		var version_int: int = int(version_float)
		if version_float == float(version_int):
			envelope["save_schema_version"] = version_int
			return
	failures.append("save_schema_version is not an exact integer")


static func _encode_json_value(value) -> String:
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
				array_parts.append(_encode_json_value(item))
			return "[" + ",".join(array_parts) + "]"
		TYPE_DICTIONARY:
			var keys: Array[String] = []
			for key_variant in value.keys():
				keys.append(str(key_variant))
			keys.sort()
			var object_parts := PackedStringArray()
			for key in keys:
				object_parts.append(JSON.stringify(key) + ":" + _encode_json_value(value[key]))
			return "{" + ",".join(object_parts) + "}"
		_:
			return "null"


static func _failure(failures: Array[String]) -> Dictionary:
	return {
		"success": false,
		"diagnostics": failures.duplicate(),
	}
