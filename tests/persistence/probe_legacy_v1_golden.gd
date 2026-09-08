extends RefCounted

const IntegratedGameSaveContract := preload("res://gameplay/persistence/integrated_game_save_contract.gd")
const LegacyV1FixtureSource := preload("res://tests/persistence/test_integrated_game_save_contract.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var fixture: Dictionary = LegacyV1FixtureSource._fixture(failures)
	if not failures.is_empty() or fixture.is_empty():
		return failures
	var encoded: Dictionary = IntegratedGameSaveContract.encode(
		fixture["context"],
		fixture["delta_store"],
		fixture["inventory"],
		fixture["equipment"],
		[fixture["pending_b"], fixture["pending_a"]],
		fixture["resume_position"]
	)
	if not bool(encoded.get("success", false)):
		failures.append("legacy v1 base probe encode failed: %s" % [encoded.get("diagnostics", [])])
		return failures
	print("LEGACY_V1_BASE_GOLDEN=" + str(encoded.get("json", "")))
	return failures
