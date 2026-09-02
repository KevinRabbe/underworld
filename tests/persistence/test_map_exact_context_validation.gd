extends RefCounted

const SerializationContract := preload("res://worldgen/persistence/map_data_serialization_contract.gd")
const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const WorldId := preload("res://worldgen/identity/world_id.gd")
const GeneratorManifest := preload("res://worldgen/versioning/generator_manifest.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_supplied_exact_context_owns_header_validation(failures)
	return failures


static func _test_supplied_exact_context_owns_header_validation(failures: Array[String]) -> void:
	var seed: int = 424242
	var current_context = WorldGenerationContext.new(seed)
	var encoded: Dictionary = SerializationContract.encode(current_context, WorldDeltaStore.new())
	_expect_true(failures, "exact-context fixture encodes", bool(encoded.get("success", false)))
	if not bool(encoded.get("success", false)):
		return

	var alternate_world_id: String = WorldId.from_seed(seed + 1).value()
	var exact_context = WorldGenerationContext.from_exact_identity(
		seed,
		alternate_world_id,
		WorldId.current_contract_descriptor(),
		GeneratorManifest.foundation_default()
	)
	_expect_equal(
		failures,
		"alternate exact context is structurally valid",
		exact_context.validate_structure(),
		[]
	)

	var current_world_id: String = str(current_context.world_id)
	var exact_json: String = str(encoded.get("json", "")).replace(
		current_world_id,
		alternate_world_id
	)
	_expect_true(
		failures,
		"legacy MAP decode still rejects non-current seed-derived WorldId",
		not bool(SerializationContract.decode(exact_json).get("success", true))
	)

	var decoded: Dictionary = SerializationContract.decode_against_context(
		exact_json,
		exact_context
	)
	_expect_true(
		failures,
		"supplied exact context accepts its byte-matching MAP header",
		bool(decoded.get("success", false))
	)
	if not bool(decoded.get("success", false)):
		return
	_expect_equal(
		failures,
		"supplied exact context preserves exact WorldId",
		str(decoded["envelope"]["world"]["world_id"]),
		alternate_world_id
	)

	var loaded: Dictionary = SerializationContract.load_delta_store_against_context(
		decoded["envelope"],
		exact_context
	)
	_expect_true(
		failures,
		"supplied exact context loads validated deltas",
		bool(loaded.get("success", false))
	)

	var foreign_context = WorldGenerationContext.new(seed + 2)
	_expect_true(
		failures,
		"spliced exact context rejects otherwise valid MAP bytes",
		not bool(
			SerializationContract.decode_against_context(exact_json, foreign_context).get(
				"success",
				true
			)
		)
	)
	_expect_true(
		failures,
		"missing supplied context fails closed",
		not bool(SerializationContract.decode_against_context(exact_json, null).get("success", true))
	)


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
