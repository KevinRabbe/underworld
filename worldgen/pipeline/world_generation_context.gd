extends RefCounted
class_name UnderworldWorldGenerationContext

const GeneratorManifestScript := preload("res://worldgen/versioning/generator_manifest.gd")
const WorldIdScript := preload("res://worldgen/identity/world_id.gd")
const Provenance := preload("res://worldgen/pipeline/generation_provenance.gd")

var world_seed: int
var world_id: String
var generator_manifest
var generator_manifest_id: String


func _init(seed_value: int, manifest_value = null) -> void:
	world_seed = seed_value
	generator_manifest = manifest_value
	if generator_manifest == null:
		generator_manifest = GeneratorManifestScript.foundation_default()
	world_id = WorldIdScript.from_seed(world_seed).value()
	generator_manifest_id = generator_manifest.manifest_id()


func validate() -> Array[String]:
	var failures: Array[String] = []
	if WorldIdScript.parse(world_id) == null:
		failures.append("WorldGenerationContext has invalid WorldId")
	if generator_manifest == null:
		failures.append("WorldGenerationContext is missing GeneratorManifest")
		return failures
	failures.append_array(generator_manifest.validate())
	if generator_manifest.manifest_id() != generator_manifest_id:
		failures.append("WorldGenerationContext manifest fingerprint changed after construction")
	return failures


func canonical_header() -> Dictionary:
	return {
		"world_seed": world_seed,
		"world_id": world_id,
		"generator_manifest_id": generator_manifest_id,
		"generator_manifest_canonical": generator_manifest.canonical_text(),
	}


func stage_contract_revision(stage_id: String, fallback: int = 1) -> int:
	if generator_manifest == null:
		return fallback
	return int(generator_manifest.stage_revisions().get(stage_id, fallback))


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


func validate_provenance(provenance, expected_stage: String = "", expected_region: String = "", expected_sources = null) -> Array[String]:
	if provenance == null or not (provenance is Provenance):
		return ["GenerationProvenance is missing or has the wrong type"]
	var failures: Array[String] = provenance.validate_against(self, expected_stage, expected_region, expected_sources)
	if provenance.stage_contract_revision != stage_contract_revision(provenance.stage_id):
		failures.append("GenerationProvenance stage revision does not match current manifest")
	return failures
