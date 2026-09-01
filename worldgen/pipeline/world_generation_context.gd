extends RefCounted
class_name UnderworldWorldGenerationContext

const GeneratorManifestScript := preload("res://worldgen/versioning/generator_manifest.gd")
const WorldIdScript := preload("res://worldgen/identity/world_id.gd")
const Provenance := preload("res://worldgen/pipeline/generation_provenance.gd")
const SCRIPT_PATH: String = "res://worldgen/pipeline/world_generation_context.gd"

var _world_seed: int
var _world_id: String
var _world_id_contract: Dictionary = {}
var _generator_manifest
var _generator_manifest_id: String

var world_seed: int:
	get:
		return _world_seed
	set(_value):
		pass

var world_id: String:
	get:
		return _world_id
	set(_value):
		pass

var generator_manifest:
	get:
		return _generator_manifest
	set(_value):
		pass

var generator_manifest_id: String:
	get:
		return _generator_manifest_id
	set(_value):
		pass


func _init(
	seed_value: int,
	manifest_value = null,
	exact_world_id: String = "",
	world_id_contract_value: Dictionary = {}
) -> void:
	_world_seed = seed_value

	var source_manifest = manifest_value
	if source_manifest == null:
		source_manifest = GeneratorManifestScript.foundation_default()

	if source_manifest != null and source_manifest.has_method("snapshot"):
		_generator_manifest = GeneratorManifestScript.from_snapshot(
			source_manifest.snapshot()
		)
	else:
		_generator_manifest = source_manifest

	if world_id_contract_value.is_empty():
		_world_id_contract = WorldIdScript.current_contract_descriptor()
	else:
		_world_id_contract = world_id_contract_value.duplicate(true)

	if exact_world_id.is_empty():
		var derived = WorldIdScript.from_seed_with_contract(
			_world_seed, _world_id_contract
		)
		_world_id = "" if derived == null else derived.value()
	else:
		_world_id = exact_world_id

	_generator_manifest_id = (
		""
		if _generator_manifest == null
		else _generator_manifest.manifest_id()
	)


static func from_exact_identity(
	seed_value: int,
	exact_world_id: String,
	world_id_contract_value: Dictionary,
	manifest_value
):
	return load(SCRIPT_PATH).new(
		seed_value,
		manifest_value,
		exact_world_id,
		world_id_contract_value.duplicate(true)
	)


func world_id_contract() -> Dictionary:
	return _world_id_contract.duplicate(true)


func manifest_snapshot() -> Dictionary:
	if _generator_manifest == null or not _generator_manifest.has_method("snapshot"):
		return {}
	return _generator_manifest.snapshot()


func validate_structure() -> Array[String]:
	var failures: Array[String] = []
	if WorldIdScript.parse_with_contract(_world_id, _world_id_contract) == null:
		failures.append("WorldGenerationContext has invalid WorldId for captured contract")
	if _generator_manifest == null:
		failures.append("WorldGenerationContext is missing GeneratorManifest")
		return failures
	failures.append_array(_generator_manifest.validate())
	if _generator_manifest.manifest_id() != _generator_manifest_id:
		failures.append("WorldGenerationContext manifest fingerprint changed after construction")
	return failures


func runtime_compatibility_failures(
	manifest_runtime_support: Dictionary = {},
	supported_world_id_contracts: Array = []
) -> Array[String]:
	var failures: Array[String] = []
	if _generator_manifest == null:
		return ["WorldGenerationContext is missing GeneratorManifest"]

	failures.append_array(
		_generator_manifest.runtime_compatibility_failures(manifest_runtime_support)
	)
	failures.append_array(
		WorldIdScript.runtime_compatibility_failures(
			_world_id_contract,
			supported_world_id_contracts
		)
	)
	if failures.is_empty():
		failures.append_array(
			WorldIdScript.validate_exact_for_seed(
				_world_seed,
				_world_id,
				_world_id_contract,
				supported_world_id_contracts
			)
		)
	return failures


func validate() -> Array[String]:
	var failures: Array[String] = validate_structure()
	if failures.is_empty():
		failures.append_array(runtime_compatibility_failures())
	return failures


func canonical_header() -> Dictionary:
	return {
		"world_seed": _world_seed,
		"world_id": _world_id,
		"generator_manifest_id": _generator_manifest_id,
		"generator_manifest_canonical": (
			""
			if _generator_manifest == null
			else _generator_manifest.canonical_text()
		),
	}


func stage_contract_revision(stage_id: String, fallback: int = 1) -> int:
	if _generator_manifest == null:
		return fallback
	return int(_generator_manifest.stage_revisions().get(stage_id, fallback))


func make_provenance(
	stage_id: String,
	region_id: String = "",
	region_address: String = "",
	source_fingerprints: Array = []
):
	return Provenance.from_context(
		self,
		stage_id,
		stage_contract_revision(stage_id),
		region_id,
		region_address,
		source_fingerprints
	)


func validate_provenance(
	provenance,
	expected_stage: String = "",
	expected_region: String = "",
	expected_sources = null
) -> Array[String]:
	if provenance == null or not (provenance is Provenance):
		return ["GenerationProvenance is missing or has the wrong type"]
	var failures: Array[String] = provenance.validate_against(
		self, expected_stage, expected_region, expected_sources
	)
	if provenance.stage_contract_revision != stage_contract_revision(provenance.stage_id):
		failures.append("GenerationProvenance stage revision does not match current manifest")
	return failures


func validate_required_sources(provenance, expected_sources: Array) -> Array[String]:
	if provenance == null or not (provenance is Provenance):
		return ["GenerationProvenance is missing or has the wrong type"]
	return provenance.requires_sources(expected_sources)


func validate_exact_sources(provenance, expected_sources: Array) -> Array[String]:
	if provenance == null or not (provenance is Provenance):
		return ["GenerationProvenance is missing or has the wrong type"]
	return provenance.validate_exact_sources(expected_sources)
