extends RefCounted

const TypedJsonWire := preload("res://worldgen/persistence/typed_json_wire.gd")
const IntegratedGameSaveContract := preload("res://gameplay/persistence/integrated_game_save_contract.gd")
const LegacyV1GameSaveCodec := preload("res://gameplay/persistence/legacy_v1_game_save_codec.gd")
const LegacyV1FixtureSource := preload("res://tests/persistence/test_integrated_game_save_contract.gd")

const GOLDEN_PATH := "res://tests/persistence/fixtures/legacy_v1_valid_golden.json"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_compare_public_constants(failures)
	_compare_validation_diagnostics(failures)
	_compare_invalid_decode(failures)
	_compare_invalid_clone(failures)
	_compare_valid_golden_and_clone(failures)
	_verify_v2_legacy_classification(failures)
	return failures


static func _compare_public_constants(failures: Array[String]) -> void:
	_expect_equal(
		failures,
		"legacy schema version remains identical",
		LegacyV1GameSaveCodec.SAVE_SCHEMA_VERSION,
		IntegratedGameSaveContract.SAVE_SCHEMA_VERSION
	)
	_expect_equal(
		failures,
		"legacy schema name remains identical",
		LegacyV1GameSaveCodec.SCHEMA_NAME,
		IntegratedGameSaveContract.SCHEMA_NAME
	)
	_expect_equal(
		failures,
		"legacy root-key contract remains identical",
		LegacyV1GameSaveCodec.ROOT_KEYS,
		IntegratedGameSaveContract.ROOT_KEYS
	)
	_expect_equal(
		failures,
		"legacy resume-key contract remains identical",
		LegacyV1GameSaveCodec.RESUME_KEYS,
		IntegratedGameSaveContract.RESUME_KEYS
	)


static func _compare_validation_diagnostics(failures: Array[String]) -> void:
	for envelope in [
		{},
		{
			"schema": "wrong-schema",
			"save_schema_version": 7,
			"map_json": "",
			"inventory_json": 1,
			"equipment_json": "",
			"pending_loot_jsons": ["", 3],
			"player_resume": {"x": 1.0, "y": NAN, "z": "bad"},
		},
	]:
		_expect_equal(
			failures,
			"legacy envelope diagnostics remain byte-for-byte equivalent",
			LegacyV1GameSaveCodec.validate_envelope(envelope),
			IntegratedGameSaveContract.validate_envelope(envelope)
		)


static func _compare_invalid_decode(failures: Array[String]) -> void:
	for json_text in ["", "[]", "{not-json}"]:
		_expect_equal(
			failures,
			"legacy invalid decode remains result-equivalent",
			LegacyV1GameSaveCodec.decode(json_text),
			IntegratedGameSaveContract.decode(json_text)
		)


static func _compare_invalid_clone(failures: Array[String]) -> void:
	for candidate in [
		{},
		{"resume_position": Vector3.ZERO},
		{"resume_position": Vector3.ZERO, "pending_loot_states": null},
	]:
		_expect_equal(
			failures,
			"legacy invalid clone remains result-equivalent",
			LegacyV1GameSaveCodec.clone_candidate(candidate),
			IntegratedGameSaveContract.clone_candidate(candidate)
		)


static func _compare_valid_golden_and_clone(failures: Array[String]) -> void:
	var expected_json: String = FileAccess.get_file_as_string(GOLDEN_PATH)
	if expected_json.is_empty():
		failures.append("legacy v1 golden fixture could not be read")
		return

	var fixture_failures: Array[String] = []
	var fixture: Dictionary = LegacyV1FixtureSource._fixture(fixture_failures)
	if not fixture_failures.is_empty() or fixture.is_empty():
		failures.append("legacy v1 golden fixture setup failed: %s" % [fixture_failures])
		return

	# Reverse the input order deliberately: accepted v1 canonicalization sorts
	# pending loot by occurrence id before writing the outer wire.
	var encoded: Dictionary = LegacyV1GameSaveCodec.encode(
		fixture["context"],
		fixture["delta_store"],
		fixture["inventory"],
		fixture["equipment"],
		[fixture["pending_b"], fixture["pending_a"]],
		fixture["resume_position"]
	)
	if not bool(encoded.get("success", false)):
		failures.append(
			"legacy v1 golden fixture encode failed: %s" % [encoded.get("diagnostics", [])]
		)
		return
	_expect_equal(
		failures,
		"valid legacy v1 canonical JSON remains byte-identical to accepted pre-extraction golden",
		str(encoded.get("json", "")),
		expected_json
	)

	var decoded: Dictionary = LegacyV1GameSaveCodec.decode(expected_json)
	if not bool(decoded.get("success", false)):
		failures.append(
			"accepted pre-extraction legacy v1 golden did not decode: %s"
			% [decoded.get("diagnostics", [])]
		)
		return
	var candidate_variant: Variant = decoded.get("candidate", null)
	if not candidate_variant is Dictionary:
		failures.append("valid legacy v1 golden decode did not return a Dictionary candidate")
		return
	var candidate: Dictionary = candidate_variant
	_expect_equal(
		failures,
		"valid legacy v1 golden keeps resume position",
		candidate.get("resume_position", Vector3.ZERO),
		fixture["resume_position"]
	)
	_expect_pending_order(failures, candidate.get("pending_loot_states", []))
	_expect_candidate_reencodes_to_golden(
		failures,
		"valid legacy v1 golden decode",
		candidate,
		expected_json
	)

	var legacy_clone: Dictionary = LegacyV1GameSaveCodec.clone_candidate(candidate)
	if not bool(legacy_clone.get("success", false)):
		failures.append(
			"valid legacy v1 codec clone failed: %s" % [legacy_clone.get("diagnostics", [])]
		)
	else:
		var legacy_clone_candidate: Variant = legacy_clone.get("candidate", null)
		if not legacy_clone_candidate is Dictionary:
			failures.append("valid legacy v1 codec clone did not return a Dictionary candidate")
		else:
			_expect_candidate_reencodes_to_golden(
				failures,
				"valid legacy v1 codec clone",
				legacy_clone_candidate,
				expected_json
			)

	var facade_clone: Dictionary = IntegratedGameSaveContract.clone_candidate(candidate)
	if not bool(facade_clone.get("success", false)):
		failures.append(
			"valid legacy v1 facade clone failed: %s" % [facade_clone.get("diagnostics", [])]
		)
	else:
		var facade_clone_candidate: Variant = facade_clone.get("candidate", null)
		if not facade_clone_candidate is Dictionary:
			failures.append("valid legacy v1 facade clone did not return a Dictionary candidate")
		else:
			_expect_candidate_reencodes_to_golden(
				failures,
				"valid legacy v1 facade clone",
				facade_clone_candidate,
				expected_json
			)


static func _expect_pending_order(failures: Array[String], pending_variant: Variant) -> void:
	if not pending_variant is Array:
		failures.append("valid legacy v1 golden pending-loot candidate is not an Array")
		return
	var pending_states: Array = pending_variant
	_expect_equal(
		failures,
		"valid legacy v1 golden keeps pending-loot count",
		pending_states.size(),
		2
	)
	if pending_states.size() != 2:
		return
	_expect_equal(
		failures,
		"valid legacy v1 golden canonicalizes first pending occurrence",
		str(pending_states[0].occurrence_id),
		"burrower_41"
	)
	_expect_equal(
		failures,
		"valid legacy v1 golden canonicalizes second pending occurrence",
		str(pending_states[1].occurrence_id),
		"burrower_43"
	)


static func _expect_candidate_reencodes_to_golden(
	failures: Array[String],
	label: String,
	candidate: Dictionary,
	expected_json: String
) -> void:
	var pending_variant: Variant = candidate.get("pending_loot_states", null)
	if not pending_variant is Array:
		failures.append("%s pending_loot_states is not an Array" % label)
		return
	var resume_variant: Variant = candidate.get("resume_position", null)
	if not resume_variant is Vector3:
		failures.append("%s resume_position is not Vector3" % label)
		return
	var encoded: Dictionary = LegacyV1GameSaveCodec.encode(
		candidate.get("world_context", null),
		candidate.get("delta_store", null),
		candidate.get("inventory_state", null),
		candidate.get("equipment_state", null),
		pending_variant,
		resume_variant
	)
	if not bool(encoded.get("success", false)):
		failures.append("%s re-encode failed: %s" % [label, encoded.get("diagnostics", [])])
		return
	_expect_equal(
		failures,
		"%s preserves the accepted pre-extraction canonical JSON" % label,
		str(encoded.get("json", "")),
		expected_json
	)


static func _verify_v2_legacy_classification(failures: Array[String]) -> void:
	var envelope: Dictionary = {
		"schema": LegacyV1GameSaveCodec.SCHEMA_NAME,
		"save_schema_version": LegacyV1GameSaveCodec.SAVE_SCHEMA_VERSION,
		"map_json": "{}",
		"inventory_json": "{}",
		"equipment_json": "{}",
		"pending_loot_jsons": [],
		"player_resume": {"x": 1.0, "y": 2.0, "z": 3.0},
	}
	var encoded: Dictionary = TypedJsonWire.encode(envelope, "legacy v1 classification fixture")
	if not bool(encoded.get("success", false)):
		failures.append("legacy v1 classification fixture did not encode")
		return
	var classified: Dictionary = IntegratedGameSaveContract.decode_v2_classified(
		str(encoded.get("json", ""))
	)
	_expect_equal(
		failures,
		"valid legacy v1 remains classified incompatible",
		classified.get("classification", ""),
		IntegratedGameSaveContract.CLASS_INCOMPATIBLE
	)
	_expect_equal(
		failures,
		"valid legacy v1 classification remains unsuccessful",
		bool(classified.get("success", true)),
		false
	)
	_expect_equal(
		failures,
		"valid legacy v1 keeps domain-missing compatibility diagnostic",
		classified.get("diagnostics", []),
		[IntegratedGameSaveContract.LEGACY_DOMAIN_MISSING_DIAGNOSTIC]
	)


static func _expect_equal(
	failures: Array[String],
	label: String,
	actual: Variant,
	expected: Variant
) -> void:
	if actual != expected:
		failures.append("%s expected=%s actual=%s" % [label, expected, actual])
