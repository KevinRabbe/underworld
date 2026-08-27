extends RefCounted
class_name UnderworldWorldGenerationContext

const GeneratorManifestScript := preload("res://worldgen/versioning/generator_manifest.gd")
const WorldIdScript := preload("res://worldgen/identity/world_id.gd")

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
