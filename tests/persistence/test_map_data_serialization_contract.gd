extends RefCounted

const SerializationContract := preload("res://worldgen/persistence/map_data_serialization_contract.gd")
const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_round_trip(failures)
	_test_deterministic_json(failures)
	_test_corrupt_headers(failures)
	_test_schema_boundary(failures)
	_test_json_safe_delta_boundary(failures)
	return failures


static func _test_round_trip(failures: Array[String]) -> void:
	var world_seed: int = 9007199254740997
	var context = WorldGenerationContext.new(world_seed)
	var ids: Array[String] = _sample_ids()
	var store = WorldDeltaStore.new()
	var payload: Dictionary = {
		"destroyed_objects": [ids[1], ids[0]],
		"object_state": {
			ids[0]: {"health": 2, "opened": true, "nested": {"b": 2, "a": 1}},
		},
		"special_location_state": {
			ids[1]: {"cleared": true},
		},
		"terrain_delta_index": {
			"cell:-2:7": {"revision": 3, "shard": "terrain/-2/7"},
		},
		"player_created_objects": {
			"build-0001": {"kind": "wall", "integrity": 100},
		},
	}
	_expect_equal(failures, "sample delta payload loads", store.load_modern_delta_payload(payload), [])

	var encoded: Dictionary = SerializationContract.encode(context, store)
	_expect_true(failures, "map save encodes", bool(encoded.get("success", false)))
	if not bool(encoded.get("success", false)):
		return
	var envelope: Dictionary = encoded["envelope"]
	_expect_equal(failures, "schema version", int(envelope.get("save_schema_version", -1)), 3)
	_expect_equal(failures, "world seed preserved before JSON", int(envelope["world"]["world_seed"]), world_seed)
	_expect_true(failures, "full topology is not serialized", not envelope.has("topology"))
	_expect_true(failures, "full region graph is not serialized", not envelope.has("region_graph"))
	_expect_equal(failures, "top-level envelope keys stay bounded", _sorted_keys(envelope), ["deltas", "save_schema_version", "schema", "world"])

	var decoded: Dictionary = SerializationContract.decode(str(encoded["json"]))
	_expect_true(failures, "map save decodes", bool(decoded.get("success", false)))
	if not bool(decoded.get("success", false)):
		return
	var decoded_envelope: Dictionary = decoded["envelope"]
	_expect_equal(failures, "large world seed survives JSON exactly", int(decoded_envelope["world"]["world_seed"]), world_seed)
	_expect_equal(failures, "WorldId survives JSON", decoded_envelope["world"]["world_id"], envelope["world"]["world_id"])
	_expect_equal(failures, "manifest id survives JSON", decoded_envelope["world"]["generator_manifest_id"], envelope["world"]["generator_manifest_id"])
	_expect_equal(failures, "manifest contract survives JSON", decoded_envelope["world"]["generator_manifest_canonical"], envelope["world"]["generator_manifest_canonical"])
	_expect_equal(failures, "delta payload survives JSON", decoded_envelope["deltas"], envelope["deltas"])

	var loaded: Dictionary = SerializationContract.load_delta_store(decoded_envelope)
	_expect_true(failures, "decoded deltas load into WorldDeltaStore", bool(loaded.get("success", false)))
	if bool(loaded.get("success", false)):
		_expect_equal(failures, "loaded delta snapshot reproduces", loaded["delta_store"].snapshot(), envelope["deltas"])

	var reencoded: Dictionary = SerializationContract.canonical_json(decoded_envelope)
	_expect_true(failures, "decoded envelope re-encodes", bool(reencoded.get("success", false)))
	if bool(reencoded.get("success", false)):
		_expect_equal(failures, "canonical JSON round-trips byte-identically", reencoded["json"], encoded["json"])


static func _test_deterministic_json(failures: Array[String]) -> void:
	var context = WorldGenerationContext.new(-808080)
	var ids: Array[String] = _sample_ids()
	var first_store = WorldDeltaStore.new()
	var second_store = WorldDeltaStore.new()
	var first_payload: Dictionary = {
		"destroyed_objects": [ids[1], ids[0]],
		"object_state": {
			ids[0]: {"z": 3, "a": 1},
			ids[1]: {"nested": {"right": false, "left": true}},
		},
		"special_location_state": {},
		"terrain_delta_index": {"z-cell": {"v": 2}, "a-cell": {"v": 1}},
		"player_created_objects": {},
	}
	var second_payload: Dictionary = {
		"player_created_objects": {},
		"terrain_delta_index": {"a-cell": {"v": 1}, "z-cell": {"v": 2}},
		"special_location_state": {},
		"object_state": {
			ids[1]: {"nested": {"left": true, "right": false}},
			ids[0]: {"a": 1, "z": 3},
		},
		"destroyed_objects": [ids[0], ids[1]],
	}
	first_store.load_modern_delta_payload(first_payload)
	second_store.load_modern_delta_payload(second_payload)
	var first: Dictionary = SerializationContract.encode(context, first_store)
	var second: Dictionary = SerializationContract.encode(context, second_store)
	_expect_true(failures, "first deterministic envelope encodes", bool(first.get("success", false)))
	_expect_true(failures, "second deterministic envelope encodes", bool(second.get("success", false)))
	if bool(first.get("success", false)) and bool(second.get("success", false)):
		_expect_equal(failures, "equivalent map state has byte-identical JSON", first["json"], second["json"])


static func _test_corrupt_headers(failures: Array[String]) -> void:
	var context = WorldGenerationContext.new(12345)
	var store = WorldDeltaStore.new()
	var built: Dictionary = SerializationContract.build_envelope(context, store)
	_expect_true(failures, "corrupt-header fixture builds", bool(built.get("success", false)))
	if not bool(built.get("success", false)):
		return

	var bad_world_id: Dictionary = built["envelope"].duplicate(true)
	bad_world_id["world"]["world_id"] = "not-a-world-id"
	_expect_true(failures, "invalid WorldId rejected", not SerializationContract.validate_envelope(bad_world_id).is_empty())

	var wrong_seed_identity: Dictionary = built["envelope"].duplicate(true)
	wrong_seed_identity["world"]["world_seed"] = 12346
	_expect_true(failures, "WorldId/seed mismatch rejected", not SerializationContract.validate_envelope(wrong_seed_identity).is_empty())

	var bad_manifest: Dictionary = built["envelope"].duplicate(true)
	bad_manifest["world"]["generator_manifest_id"] = "gm-sha256:deadbeef"
	_expect_true(failures, "manifest fingerprint mismatch rejected", not SerializationContract.validate_envelope(bad_manifest).is_empty())

	var leaked_topology: Dictionary = built["envelope"].duplicate(true)
	leaked_topology["topology"] = {"nodes": []}
	_expect_true(failures, "unexpected full-topology field rejected", not SerializationContract.validate_envelope(leaked_topology).is_empty())


static func _test_schema_boundary(failures: Array[String]) -> void:
	var context = WorldGenerationContext.new(777)
	var store = WorldDeltaStore.new()
	var built: Dictionary = SerializationContract.build_envelope(context, store)
	if not bool(built.get("success", false)):
		failures.append("schema-boundary fixture failed")
		return
	var future: Dictionary = built["envelope"].duplicate(true)
	future["save_schema_version"] = 4
	_expect_true(failures, "future save schema rejected explicitly", not SerializationContract.validate_envelope(future).is_empty())
	var old_name: Dictionary = built["envelope"].duplicate(true)
	old_name["schema"] = "underworld-map-save-v2"
	_expect_true(failures, "wrong schema name rejected explicitly", not SerializationContract.validate_envelope(old_name).is_empty())


static func _test_json_safe_delta_boundary(failures: Array[String]) -> void:
	var context = WorldGenerationContext.new(42)
	var ids: Array[String] = _sample_ids()
	var store = WorldDeltaStore.new()
	store.load_modern_delta_payload({
		"destroyed_objects": [],
		"object_state": {ids[0]: {"runtime_vector": Vector3(1.0, 2.0, 3.0)}},
		"special_location_state": {},
		"terrain_delta_index": {},
		"player_created_objects": {},
	})
	var built: Dictionary = SerializationContract.build_envelope(context, store)
	_expect_true(failures, "unsupported non-JSON Variant is rejected", not bool(built.get("success", true)))


static func _sample_ids() -> Array[String]:
	var first_address = StableAddress.generated_child(StableAddress.underground_region(0, 0), "test-object", 0)
	var second_address = StableAddress.generated_child(StableAddress.underground_region(0, 0), "test-object", 1)
	return [
		StableId.from_address(first_address).value(),
		StableId.from_address(second_address).value(),
	]


static func _sorted_keys(value: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in value.keys():
		result.append(str(key))
	result.sort()
	return result


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s expected=%s actual=%s" % [label, str(expected), str(actual)])
