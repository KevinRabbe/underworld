extends RefCounted

const SerializationContract := preload("res://worldgen/persistence/map_data_serialization_contract.gd")
const IntegratedGameSaveContract := preload("res://gameplay/persistence/integrated_game_save_contract.gd")
const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const WorldId := preload("res://worldgen/identity/world_id.gd")
const GeneratorManifest := preload("res://worldgen/versioning/generator_manifest.gd")
const RootGenerationIdentityPackage := preload("res://worldgen/versioning/root_generation_identity_package.gd")
const WorldDomainSessionState := preload("res://gameplay/world_session/world_domain_session_state.gd")
const SlotServiceTests := preload("res://tests/persistence/test_game_save_slot_service.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_current_context_exact_encode_is_byte_identical(failures)
	_test_supplied_exact_context_owns_build_and_header_validation(failures)
	_test_supported_historical_v2_decode_then_save_preserves_root_identity(failures)
	return failures


static func _test_current_context_exact_encode_is_byte_identical(failures: Array[String]) -> void:
	var context = WorldGenerationContext.new(424242)
	var delta_store = WorldDeltaStore.new()
	var standalone: Dictionary = SerializationContract.encode(context, delta_store)
	var exact: Dictionary = SerializationContract.encode_against_context(context, delta_store)
	_expect_true(failures, "current standalone MAP encode succeeds", bool(standalone.get("success", false)))
	_expect_true(failures, "current exact-context MAP encode succeeds", bool(exact.get("success", false)))
	if not bool(standalone.get("success", false)) or not bool(exact.get("success", false)):
		return
	_expect_equal(
		failures,
		"current exact-context MAP envelope is byte-semantically identical",
		exact.get("envelope", {}),
		standalone.get("envelope", {})
	)
	_expect_equal(
		failures,
		"current exact-context MAP JSON is byte-identical",
		str(exact.get("json", "")),
		str(standalone.get("json", ""))
	)


static func _test_supplied_exact_context_owns_build_and_header_validation(
	failures: Array[String]
) -> void:
	var seed: int = 424242
	var historical_context = _explicitly_supported_non_current_context(seed, failures)
	if historical_context == null:
		return
	var expected_header: Dictionary = historical_context.canonical_header()
	var delta_store = WorldDeltaStore.new()

	var exact_encoded: Dictionary = SerializationContract.encode_against_context(
		historical_context,
		delta_store
	)
	_expect_true(
		failures,
		"historical exact-context MAP encode succeeds",
		bool(exact_encoded.get("success", false))
	)
	if not bool(exact_encoded.get("success", false)):
		return
	var exact_envelope: Dictionary = exact_encoded.get("envelope", {})
	_expect_equal(
		failures,
		"historical exact-context MAP encode preserves supplied header",
		exact_envelope.get("world", {}),
		_wire_header(expected_header)
	)

	_expect_true(
		failures,
		"ordinary MAP encode keeps current-default historical strictness",
		not bool(SerializationContract.encode(historical_context, delta_store).get("success", true))
	)
	_expect_true(
		failures,
		"ordinary MAP decode keeps current-default historical strictness",
		not bool(
			SerializationContract.decode(str(exact_encoded.get("json", ""))).get(
				"success",
				true
			)
		)
	)

	var exact_decoded: Dictionary = SerializationContract.decode_against_context(
		str(exact_encoded.get("json", "")),
		historical_context
	)
	_expect_true(
		failures,
		"historical MAP bytes decode against their exact context",
		bool(exact_decoded.get("success", false))
	)
	if not bool(exact_decoded.get("success", false)):
		return
	_expect_equal(
		failures,
		"historical exact-context decode preserves exact WorldId",
		str(exact_decoded["envelope"]["world"]["world_id"]),
		str(expected_header.get("world_id", ""))
	)

	var loaded: Dictionary = SerializationContract.load_delta_store_against_context(
		exact_decoded["envelope"],
		historical_context
	)
	_expect_true(
		failures,
		"historical supplied exact context loads validated deltas",
		bool(loaded.get("success", false))
	)

	var foreign_context = WorldGenerationContext.new(seed + 2)
	_expect_true(
		failures,
		"foreign exact context rejects historical MAP decode",
		not bool(
			SerializationContract.decode_against_context(
				str(exact_encoded.get("json", "")),
				foreign_context
			).get("success", true)
		)
	)
	_expect_true(
		failures,
		"foreign exact context rejects historical MAP canonicalization",
		not bool(
			SerializationContract.canonical_json_against_context(
				exact_envelope,
				foreign_context
			).get("success", true)
		)
	)
	_expect_true(
		failures,
		"missing exact context fails closed",
		not bool(
			SerializationContract.encode_against_context(null, delta_store).get(
				"success",
				true
			)
		)
	)


static func _test_supported_historical_v2_decode_then_save_preserves_root_identity(
	failures: Array[String]
) -> void:
	var fixture: Dictionary = SlotServiceTests._fixture(failures)
	if fixture.is_empty():
		return
	var seed: int = int(fixture["context"].world_seed)
	var historical_context = _runtime_supported_prior_manifest_context(seed, failures)
	if historical_context == null:
		return
	var historical_header: Dictionary = historical_context.canonical_header()
	_expect_true(
		failures,
		"supported historical context differs from current authored root header",
		historical_header != WorldGenerationContext.new(seed).canonical_header()
	)

	var session = WorldDomainSessionState.new(WorldDomainSessionState.DOMAIN_OVERWORLD, {})
	var first_capture: Dictionary = IntegratedGameSaveContract.capture_v2_request({
		"world_context": historical_context,
		"world_session_state": session,
		"delta_store": fixture["delta_store"],
		"inventory_state": fixture["inventory"],
		"equipment_state": fixture["equipment"],
		"pending_loot_states": [],
		"resume_position": fixture["resume_position"],
		"current_health": 83,
		"current_stamina": 47.25,
	})
	_expect_true(
		failures,
		"production V2 capture accepts supported historical context",
		bool(first_capture.get("success", false))
	)
	if not bool(first_capture.get("success", false)):
		return
	var first_request: Dictionary = first_capture.get("request", {})
	var first_map: Dictionary = SerializationContract.decode_against_context(
		str(first_request.get("map_json", "")),
		historical_context
	)
	_expect_true(
		failures,
		"production V2 capture emits exact historical MAP bytes",
		bool(first_map.get("success", false))
	)
	if bool(first_map.get("success", false)):
		_expect_equal(
			failures,
			"first V2 SAVE MAP header preserves historical root",
			first_map["envelope"].get("world", {}),
			_wire_header(historical_header)
		)

	var encoded: Dictionary = IntegratedGameSaveContract.encode_v2_request(first_request)
	_expect_true(failures, "historical V2 fixture encodes", bool(encoded.get("success", false)))
	if not bool(encoded.get("success", false)):
		return
	var decoded: Dictionary = IntegratedGameSaveContract.decode_v2_classified(
		str(encoded.get("json", ""))
	)
	_expect_true(
		failures,
		"supported historical V2 fixture decodes AVAILABLE",
		bool(decoded.get("success", false))
		and str(decoded.get("classification", "")) == IntegratedGameSaveContract.CLASS_AVAILABLE
	)
	if not bool(decoded.get("success", false)):
		return
	var candidate: Dictionary = decoded.get("candidate", {})
	var loaded_context = candidate.get("world_context", null)
	if loaded_context == null:
		failures.append("historical V2 decode omitted exact world_context")
		return
	_expect_equal(
		failures,
		"historical V2 decode preserves exact loaded root header",
		loaded_context.canonical_header(),
		historical_header
	)

	var vitals: Dictionary = candidate.get("player_vitals", {})
	var recaptured: Dictionary = IntegratedGameSaveContract.capture_v2_request({
		"world_context": loaded_context,
		"world_session_state": candidate.get("world_session_state", null),
		"delta_store": candidate.get("delta_store", null),
		"inventory_state": candidate.get("inventory_state", null),
		"equipment_state": candidate.get("equipment_state", null),
		"pending_loot_states": candidate.get("pending_loot_states", []),
		"resume_position": candidate.get("resume_position", Vector3.ZERO),
		"current_health": vitals.get("current_health", null),
		"current_stamina": vitals.get("current_stamina", null),
	})
	_expect_true(
		failures,
		"V2 Continue candidate can be saved again through production capture",
		bool(recaptured.get("success", false))
	)
	if not bool(recaptured.get("success", false)):
		return
	var second_request: Dictionary = recaptured.get("request", {})
	var second_map: Dictionary = SerializationContract.decode_against_context(
		str(second_request.get("map_json", "")),
		loaded_context
	)
	_expect_true(
		failures,
		"post-Continue V2 SAVE MAP decodes against retained exact context",
		bool(second_map.get("success", false))
	)
	if bool(second_map.get("success", false)):
		_expect_equal(
			failures,
			"post-Continue V2 SAVE re-emits exact historical MAP header",
			second_map["envelope"].get("world", {}),
			_wire_header(historical_header)
		)
	_expect_equal(
		failures,
		"post-Continue V2 SAVE preserves exact root package",
		second_request.get("root_identity", {}),
		first_request.get("root_identity", {})
	)


static func _explicitly_supported_non_current_context(seed: int, failures: Array[String]):
	var snapshot: Dictionary = GeneratorManifest.foundation_default().snapshot()
	snapshot["manifest_schema_version"] = 7
	snapshot["manifest_schema_prefix"] = "gm7"
	var historical_manifest = GeneratorManifest.from_snapshot(snapshot)
	var historical_contract: Dictionary = {
		"revision": 2,
		"prefix": "wid2:",
		"contract_tag": "underworld-world-id-v2",
	}
	var derived = WorldId.from_seed_with_contract(seed, historical_contract, [historical_contract])
	if derived == null:
		failures.append("could not derive explicitly-supported historical WorldId fixture")
		return null
	var context = WorldGenerationContext.from_exact_identity(
		seed,
		derived.value(),
		historical_contract,
		historical_manifest
	)
	_expect_equal(
		failures,
		"explicit historical context is structurally valid",
		context.validate_structure(),
		[]
	)
	var manifest_support: Dictionary = GeneratorManifest.current_runtime_support()
	manifest_support["manifest_schema_version"] = 7
	manifest_support["manifest_schema_prefix"] = "gm7"
	var package: Dictionary = RootGenerationIdentityPackage.encode(context)
	var rehydrated: Dictionary = RootGenerationIdentityPackage.rehydrate(
		seed,
		package,
		manifest_support,
		[historical_contract]
	)
	_expect_true(
		failures,
		"historical #430 fixture is compatible when its captured contracts are explicitly supported",
		bool(rehydrated.get("success", false)) and bool(rehydrated.get("compatible", false))
	)
	if not bool(rehydrated.get("success", false)) or not bool(rehydrated.get("compatible", false)):
		return null
	return rehydrated.get("context", null)


static func _runtime_supported_prior_manifest_context(seed: int, failures: Array[String]):
	var snapshot: Dictionary = GeneratorManifest.foundation_default().snapshot()
	var domains: Array = snapshot.get("seed_domain_descriptors", [])
	if domains.size() < 2:
		failures.append("historical manifest fixture requires at least two current seed domains")
		return null
	domains.pop_back()
	snapshot["seed_domain_descriptors"] = domains
	var historical_manifest = GeneratorManifest.from_snapshot(snapshot)
	var context = WorldGenerationContext.new(seed, historical_manifest)
	_expect_equal(
		failures,
		"prior captured manifest remains supported by current runtime superset",
		context.validate(),
		[]
	)
	var package: Dictionary = RootGenerationIdentityPackage.encode(context)
	var rehydrated: Dictionary = RootGenerationIdentityPackage.rehydrate(seed, package)
	_expect_true(
		failures,
		"prior captured manifest rehydrates as currently supported #430 root",
		bool(rehydrated.get("success", false)) and bool(rehydrated.get("compatible", false))
	)
	if not bool(rehydrated.get("success", false)) or not bool(rehydrated.get("compatible", false)):
		return null
	return rehydrated.get("context", null)


static func _wire_header(header: Dictionary) -> Dictionary:
	return {
		"world_seed": str(int(header.get("world_seed", 0))),
		"world_id": str(header.get("world_id", "")),
		"generator_manifest_id": str(header.get("generator_manifest_id", "")),
		"generator_manifest_canonical": str(
			header.get("generator_manifest_canonical", "")
		),
	}


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(
	failures: Array[String],
	label: String,
	actual: Variant,
	expected: Variant
) -> void:
	if actual != expected:
		failures.append("%s expected=%s actual=%s" % [label, str(expected), str(actual)])
