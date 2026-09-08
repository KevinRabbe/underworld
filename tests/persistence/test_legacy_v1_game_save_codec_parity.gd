extends RefCounted

const IntegratedGameSaveContract := preload("res://gameplay/persistence/integrated_game_save_contract.gd")
const LegacyV1GameSaveCodec := preload("res://gameplay/persistence/legacy_v1_game_save_codec.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_compare_public_constants(failures)
	_compare_validation_diagnostics(failures)
	_compare_invalid_decode(failures)
	_compare_invalid_clone(failures)
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


static func _expect_equal(
	failures: Array[String],
	label: String,
	actual: Variant,
	expected: Variant
) -> void:
	if actual != expected:
		failures.append("%s expected=%s actual=%s" % [label, expected, actual])
