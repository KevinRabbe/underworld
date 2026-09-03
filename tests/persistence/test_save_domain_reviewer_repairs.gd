extends RefCounted

const TypedJsonWire := preload("res://worldgen/persistence/typed_json_wire.gd")
const MapSerializationContract := preload("res://worldgen/persistence/map_data_serialization_contract.gd")
const IntegratedGameSaveContract := preload("res://gameplay/persistence/integrated_game_save_contract.gd")
const GameSaveSlotService := preload("res://gameplay/persistence/game_save_slot_service.gd")
const WorldDomainSessionState := preload("res://gameplay/world_session/world_domain_session_state.gd")
const SlotServiceTests := preload("res://tests/persistence/test_game_save_slot_service.gd")
const SaveSlotPreconditionRaceService := preload("res://tests/persistence/save_slot_precondition_race_service.gd")

const TEST_SLOT := "user://save_domain_reviewer_repair.json"
const GOLDEN_PRIMITIVE_WIRE := "{\"array\":[true,{\"$underworld_int64\":\"7\"},2.5,\"text\"],\"dict\":{\"a\":{\"$underworld_int64\":\"-3\"},\"z\":null},\"large\":{\"$underworld_int64\":\"9007199254740997\"}}"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_cleanup()
	_test_final_cas_rejects_replaced_protected_slot(failures)
	_test_final_no_protected_check_rejects_new_target(failures)
	_test_typed_wire_legacy_golden_and_vectors(failures)
	_test_typed_wire_rejects_invalid_vectors_and_reserved_collisions(failures)
	_test_vector_return_context_v2_round_trip(failures)
	_cleanup()
	return failures


static func _test_final_cas_rejects_replaced_protected_slot(failures: Array[String]) -> void:
	_cleanup()
	var fixture: Dictionary = SlotServiceTests._fixture(failures)
	if fixture.is_empty():
		return
	var baseline_service = GameSaveSlotService.new()
	var baseline_saved: Dictionary = baseline_service.save_slot(fixture["request_object"], TEST_SLOT)
	if not _require_success(baseline_saved, "reviewer CAS baseline SAVE", failures):
		return
	var baseline_text: String = _read_text(TEST_SLOT)
	var baseline_fingerprint: String = baseline_text.sha256_text()

	var competing_request: Dictionary = fixture["request"].duplicate(true)
	competing_request["player_resume"]["x"] = float(competing_request["player_resume"]["x"]) + 17.0
	var competing_encoded: Dictionary = IntegratedGameSaveContract.encode_v2_request(competing_request)
	if not _require_success(competing_encoded, "reviewer CAS competing encode", failures):
		return
	var competing_json: String = str(competing_encoded.get("json", ""))

	var candidate_request: Dictionary = fixture["request"].duplicate(true)
	candidate_request["player_resume"]["z"] = float(candidate_request["player_resume"]["z"]) - 23.0
	var candidate_encoded: Dictionary = IntegratedGameSaveContract.encode_v2_request(candidate_request)
	if not _require_success(candidate_encoded, "reviewer CAS candidate encode", failures):
		return
	var candidate_json: String = str(candidate_encoded.get("json", ""))
	if competing_json == baseline_text or candidate_json == baseline_text or candidate_json == competing_json:
		failures.append("reviewer CAS fixtures did not produce three distinct canonical byte streams")
		return

	var previous_path: String = TEST_SLOT + GameSaveSlotService.BACKUP_SUFFIX
	var previous_bytes := "preexisting-previous-must-survive-byte-identically"
	_write_text(previous_path, previous_bytes, failures)
	var rename_calls: Array[String] = []
	var service = SaveSlotPreconditionRaceService.new().configure_replacement(competing_json)
	service.configure_rename_operation(
		func(from_path: String, to_path: String) -> int:
			rename_calls.append("%s->%s" % [from_path, to_path])
			return int(DirAccess.rename_absolute(
				ProjectSettings.globalize_path(from_path),
				ProjectSettings.globalize_path(to_path)
			))
	)
	var result: Dictionary = service.persist_candidate_json(
		candidate_json,
		TEST_SLOT,
		{
			"mode": GameSaveSlotService.SAVE_CONDITION_REPLACE_EXACT_PROTECTED,
			"expected_content_fingerprint": baseline_fingerprint,
		}
	)
	if bool(result.get("success", true)) or not bool(result.get("precondition_stale", false)):
		failures.append("final CAS did not reject canonical replacement after candidate staging")
	if not bool(service.get("saw_candidate_before_replacement")):
		failures.append("CAS race fixture replaced canonical slot before candidate staging completed")
	if bool(service.get("replacement_failed")):
		failures.append("CAS race fixture could not replace canonical slot at final precondition boundary")
	if _read_text(TEST_SLOT) != competing_json:
		failures.append("stale final CAS did not preserve competing canonical slot byte-identically")
	if _read_text(previous_path) != previous_bytes:
		failures.append("stale final CAS changed pre-existing .previous bytes")
	if FileAccess.file_exists(TEST_SLOT + GameSaveSlotService.CANDIDATE_SUFFIX):
		failures.append("stale final CAS did not delete only its candidate scratch file")
	if not rename_calls.is_empty():
		failures.append("stale final CAS reached backup/promotion mutation: %s" % [rename_calls])
	var probe: Dictionary = GameSaveSlotService.new().probe_slot(TEST_SLOT)
	if str(probe.get("classification", "")) != GameSaveSlotService.CLASS_AVAILABLE:
		failures.append("competing canonical slot was not AVAILABLE after stale final CAS")
	elif str(probe.get("content_fingerprint", "")) != competing_json.sha256_text():
		failures.append("competing canonical slot fingerprint changed after stale final CAS")


static func _test_final_no_protected_check_rejects_new_target(failures: Array[String]) -> void:
	_cleanup()
	var fixture: Dictionary = SlotServiceTests._fixture(failures)
	if fixture.is_empty():
		return
	var candidate_encoded: Dictionary = IntegratedGameSaveContract.encode_v2_request(fixture["request"])
	if not _require_success(candidate_encoded, "reviewer no-protected candidate encode", failures):
		return
	var competing_request: Dictionary = fixture["request"].duplicate(true)
	competing_request["player_resume"]["x"] = float(competing_request["player_resume"]["x"]) + 31.0
	var competing_encoded: Dictionary = IntegratedGameSaveContract.encode_v2_request(competing_request)
	if not _require_success(competing_encoded, "reviewer no-protected competing encode", failures):
		return
	var competing_json: String = str(competing_encoded.get("json", ""))
	var service = SaveSlotPreconditionRaceService.new().configure_replacement(competing_json)
	var result: Dictionary = service.persist_candidate_json(
		str(candidate_encoded.get("json", "")),
		TEST_SLOT,
		{"mode": GameSaveSlotService.SAVE_CONDITION_REQUIRE_NO_PROTECTED_TARGET}
	)
	if bool(result.get("success", true)) or not bool(result.get("precondition_stale", false)):
		failures.append("final require-no-protected check did not reject target created after candidate staging")
	if not bool(service.get("saw_candidate_before_replacement")):
		failures.append("no-protected race fixture did not observe staged candidate before competing target creation")
	if _read_text(TEST_SLOT) != competing_json:
		failures.append("no-protected final rejection changed competing canonical slot bytes")
	if FileAccess.file_exists(TEST_SLOT + GameSaveSlotService.CANDIDATE_SUFFIX):
		failures.append("no-protected final rejection left candidate scratch file")


static func _test_typed_wire_legacy_golden_and_vectors(failures: Array[String]) -> void:
	var legacy_fixture: Dictionary = {
		"array": [true, 7, 2.5, "text"],
		"dict": {"z": null, "a": -3},
		"large": 9007199254740997,
	}
	var legacy_encoded: Dictionary = TypedJsonWire.encode(legacy_fixture, "legacy-compatible typed fixture")
	if not _require_success(legacy_encoded, "legacy-compatible typed encode", failures):
		return
	if str(legacy_encoded.get("json", "")) != GOLDEN_PRIMITIVE_WIRE:
		failures.append("TypedJsonWire changed byte-identical primitive/int64/Array/Dictionary golden output")
	var legacy_decoded: Dictionary = TypedJsonWire.decode(GOLDEN_PRIMITIVE_WIRE, "legacy-compatible typed fixture")
	if not _require_success(legacy_decoded, "legacy-compatible typed golden decode", failures):
		return
	if legacy_decoded.get("value", {}) != legacy_fixture:
		failures.append("TypedJsonWire changed legacy-compatible primitive/int64 logical values")

	var vector_fixture: Dictionary = {
		"v2": Vector2(1.25, -2.5),
		"nested": [
			Vector3(-3.5, 4.25, 5.75),
			{
				"v2i": Vector2i(-7, 9),
				"v3i": Vector3i(11, -13, 17),
				"semantic_name": StringName("return.marker"),
			},
		],
	}
	var vector_encoded: Dictionary = TypedJsonWire.encode(vector_fixture, "nested vector fixture")
	if not _require_success(vector_encoded, "nested vector encode", failures):
		return
	var vector_decoded: Dictionary = TypedJsonWire.decode(
		str(vector_encoded.get("json", "")),
		"nested vector fixture"
	)
	if not _require_success(vector_decoded, "nested vector decode", failures):
		return
	var restored: Dictionary = vector_decoded.get("value", {})
	if typeof(restored.get("v2")) != TYPE_VECTOR2 or restored.get("v2") != vector_fixture["v2"]:
		failures.append("TypedJsonWire did not round-trip Vector2 exactly")
	var nested: Array = restored.get("nested", [])
	if nested.size() != 2 or typeof(nested[0]) != TYPE_VECTOR3 or nested[0] != vector_fixture["nested"][0]:
		failures.append("TypedJsonWire did not round-trip nested Vector3 exactly")
	elif not nested[1] is Dictionary:
		failures.append("TypedJsonWire changed nested vector Dictionary shape")
	else:
		var nested_dict: Dictionary = nested[1]
		if typeof(nested_dict.get("v2i")) != TYPE_VECTOR2I or nested_dict.get("v2i") != Vector2i(-7, 9):
			failures.append("TypedJsonWire did not round-trip Vector2i exactly")
		if typeof(nested_dict.get("v3i")) != TYPE_VECTOR3I or nested_dict.get("v3i") != Vector3i(11, -13, 17):
			failures.append("TypedJsonWire did not round-trip Vector3i exactly")
		if typeof(nested_dict.get("semantic_name")) != TYPE_STRING or str(nested_dict.get("semantic_name", "")) != "return.marker":
			failures.append("TypedJsonWire did not canonicalize StringName to a real String value")

	var string_name_encoded: Dictionary = TypedJsonWire.encode(StringName("semantic.value"), "StringName fixture")
	if not _require_success(string_name_encoded, "StringName typed encode", failures):
		return
	if str(string_name_encoded.get("json", "")) != "\"semantic.value\"":
		failures.append("StringName validate-success path serialized anything other than its String value")
	var string_name_decoded: Dictionary = TypedJsonWire.decode(
		str(string_name_encoded.get("json", "")),
		"StringName fixture"
	)
	if not _require_success(string_name_decoded, "StringName typed decode", failures):
		return
	if typeof(string_name_decoded.get("value")) != TYPE_STRING or str(string_name_decoded.get("value", "")) != "semantic.value":
		failures.append("StringName typed roundtrip did not return canonical String")


static func _test_typed_wire_rejects_invalid_vectors_and_reserved_collisions(failures: Array[String]) -> void:
	for invalid_value in [Vector2(NAN, 1.0), Vector2(INF, 1.0), Vector3(1.0, NAN, 3.0), Vector3(1.0, -INF, 3.0)]:
		var encoded: Dictionary = TypedJsonWire.encode(invalid_value, "invalid vector")
		if bool(encoded.get("success", false)):
			failures.append("TypedJsonWire accepted non-finite vector value: %s" % [invalid_value])

	var malformed_jsons: Array[String] = [
		'{"$underworld_vector2":[1]}',
		'{"$underworld_vector3":"wrong-type"}',
		'{"$underworld_vector2":[1,2],"extra":0}',
		'{"$underworld_vector2i":[1,2]}',
		'{"$underworld_vector3i":[{"$underworld_int64":"1"},{"$underworld_int64":"2"}]}',
		'{"$underworld_int64":"01"}',
	]
	for malformed_json in malformed_jsons:
		var decoded: Dictionary = TypedJsonWire.decode(malformed_json, "malformed reserved tag")
		if bool(decoded.get("success", false)):
			failures.append("TypedJsonWire accepted malformed reserved-tag payload: %s" % malformed_json)

	for reserved_key in [
		TypedJsonWire.INT64_WIRE_TAG,
		TypedJsonWire.VECTOR2_WIRE_TAG,
		TypedJsonWire.VECTOR2I_WIRE_TAG,
		TypedJsonWire.VECTOR3_WIRE_TAG,
		TypedJsonWire.VECTOR3I_WIRE_TAG,
	]:
		var collision: Dictionary = TypedJsonWire.encode(
			{reserved_key: [1.0, 2.0]},
			"reserved logical key"
		)
		if bool(collision.get("success", false)):
			failures.append("TypedJsonWire accepted logical Dictionary collision with reserved key %s" % reserved_key)


static func _test_vector_return_context_v2_round_trip(failures: Array[String]) -> void:
	var fixture: Dictionary = SlotServiceTests._fixture(failures)
	if fixture.is_empty():
		return
	var return_context: Dictionary = {
		"surface_anchor": Vector3(41.5, 7.25, -13.75),
		"map_hint": Vector2(-2.5, 9.75),
		"region": Vector2i(-4, 12),
		"cell": Vector3i(7, -3, 19),
		"marker": StringName("gateway.return.marker"),
	}
	var expected_return_context: Dictionary = return_context.duplicate(true)
	expected_return_context["marker"] = "gateway.return.marker"
	var session = WorldDomainSessionState.new(WorldDomainSessionState.DOMAIN_OVERWORLD, {})
	var begun: Dictionary = session.begin_transition({
		"source_domain": WorldDomainSessionState.DOMAIN_OVERWORLD,
		"destination_domain": WorldDomainSessionState.DOMAIN_UNDERWORLD,
		"gateway_identity": "gateway.reviewer.vector",
		"arrival_locator": Vector3(3.0, -80.0, 5.0),
		"return_context": return_context,
	})
	if not _require_success(begun, "vector return-context transition begin", failures):
		return
	var token: int = int(begun.get("token", 0))
	var ready: Dictionary = session.mark_destination_ready(token)
	if not _require_success(ready, "vector return-context destination ready", failures):
		return
	var committed: Dictionary = session.commit_transition(token)
	if not _require_success(committed, "vector return-context transition commit", failures):
		return
	if session.active_domain() != WorldDomainSessionState.DOMAIN_UNDERWORLD:
		failures.append("vector return-context fixture did not commit UNDERWORLD")
	if session.committed_return_context_snapshot() != expected_return_context:
		failures.append("#432 did not canonicalize vector-bearing committed return context as expected")

	var captured: Dictionary = IntegratedGameSaveContract.capture_v2_request({
		"world_context": fixture["context"],
		"world_session_state": session,
		"delta_store": fixture["delta_store"],
		"inventory_state": fixture["inventory"],
		"equipment_state": fixture["equipment"],
		"pending_loot_states": [],
		"resume_position": Vector3(3.0, -80.0, 5.0),
		"current_health": 71,
		"current_stamina": 33.5,
	})
	if not _require_success(captured, "vector return-context v2 capture", failures):
		return
	var request: Dictionary = captured.get("request", {})
	var direct_map: Dictionary = MapSerializationContract.encode(fixture["context"], fixture["delta_store"])
	if not _require_success(direct_map, "vector return-context direct MAP encode", failures):
		return
	if str(request.get("map_json", "")) != str(direct_map.get("json", "")):
		failures.append("V2 typed-wire extension changed embedded MAP canonical bytes")
	var encoded: Dictionary = IntegratedGameSaveContract.encode_v2_request(request)
	if not _require_success(encoded, "vector return-context v2 encode", failures):
		return
	var decoded: Dictionary = IntegratedGameSaveContract.decode_v2_classified(
		str(encoded.get("json", ""))
	)
	if not _require_success(decoded, "vector return-context v2 decode", failures):
		return
	if str(decoded.get("classification", "")) != IntegratedGameSaveContract.CLASS_AVAILABLE:
		failures.append("vector return-context V2 decode was not AVAILABLE")
		return
	var candidate: Dictionary = decoded.get("candidate", {})
	var restored_session = candidate.get("world_session_state", null)
	if restored_session == null:
		failures.append("vector return-context V2 decode did not restore #432 session state")
		return
	if restored_session.active_domain() != WorldDomainSessionState.DOMAIN_UNDERWORLD:
		failures.append("vector return-context V2 restore changed committed active domain")
	if restored_session.transition_phase() != WorldDomainSessionState.PHASE_ACTIVE or restored_session.has_active_attempt():
		failures.append("vector return-context V2 restore did not reconstruct clean ACTIVE session")
	if restored_session.committed_return_context_snapshot() != expected_return_context:
		failures.append("vector-bearing committed return context changed through #432 -> V2 -> decode -> #432 restore")


static func _cleanup() -> void:
	for path in [
		TEST_SLOT,
		TEST_SLOT + GameSaveSlotService.CANDIDATE_SUFFIX,
		TEST_SLOT + GameSaveSlotService.BACKUP_SUFFIX,
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var value: String = file.get_as_text()
	file = null
	return value


static func _write_text(path: String, text: String, failures: Array[String]) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("reviewer repair fixture could not open file for write: %s" % path)
		return
	file.store_string(text)
	file.flush()
	file = null


static func _require_success(result: Dictionary, label: String, failures: Array[String]) -> bool:
	if bool(result.get("success", false)):
		return true
	failures.append("%s failed diagnostics=%s" % [label, result.get("diagnostics", [])])
	return false
