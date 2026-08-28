extends RefCounted
class_name UnderworldGenerationProvenance

const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")
const SCRIPT_PATH: String = "res://worldgen/pipeline/generation_provenance.gd"

const CONTRACT_REVISION: int = 1
var world_id: String
var generator_manifest_id: String
var region_id: String
var region_address: String
var stage_id: String
var stage_contract_revision: int
var source_stage_fingerprints: Array[String]
var fingerprint: String


func _init(
	world_id_value: String,
	manifest_id_value: String,
	stage_id_value: String,
	stage_revision_value: int,
	region_id_value: String = "",
	region_address_value: String = "",
	source_fingerprints_value: Array = []
) -> void:
	world_id = world_id_value
	generator_manifest_id = manifest_id_value
	region_id = region_id_value
	region_address = region_address_value
	stage_id = stage_id_value
	stage_contract_revision = stage_revision_value
	source_stage_fingerprints = []
	for value in source_fingerprints_value:
		source_stage_fingerprints.append(str(value))
	source_stage_fingerprints.sort()
	fingerprint = ""
	if validate().is_empty():
		fingerprint = "provenance1:" + CanonicalValue.fingerprint(canonical_data())


static func from_context(
	context,
	stage_id_value: String,
	stage_revision_value: int,
	region_id_value: String = "",
	region_address_value: String = "",
	source_fingerprints_value: Array = []
):
	if context == null:
		return null
	return load(SCRIPT_PATH).new(
		context.world_id,
		context.generator_manifest_id,
		stage_id_value,
		stage_revision_value,
		region_id_value,
		region_address_value,
		source_fingerprints_value
	)


func validate() -> Array[String]:
	var failures: Array[String] = []
	if world_id.is_empty():
		failures.append("GenerationProvenance requires world_id")
	if generator_manifest_id.is_empty():
		failures.append("GenerationProvenance requires generator_manifest_id")
	if stage_id.is_empty():
		failures.append("GenerationProvenance requires stage_id")
	if stage_contract_revision <= 0:
		failures.append("GenerationProvenance stage contract revision must be positive")
	if not region_id.is_empty() and region_address.is_empty():
		failures.append("Regional GenerationProvenance requires region_address")
	var seen: Dictionary = {}
	for source in source_stage_fingerprints:
		if source.is_empty():
			failures.append("GenerationProvenance source fingerprints cannot be empty")
		if seen.has(source):
			failures.append("GenerationProvenance source fingerprints must be unique")
		seen[source] = true
	var expected_fingerprint := "provenance1:" + CanonicalValue.fingerprint(canonical_data())
	if not fingerprint.is_empty() and fingerprint != expected_fingerprint:
		failures.append("GenerationProvenance fingerprint is stale after identity mutation")
	return failures


func validate_against(
	context,
	expected_stage_id: String = "",
	expected_region_id: String = "",
	expected_sources = null
) -> Array[String]:
	var failures: Array[String] = validate()
	if context == null:
		failures.append("GenerationProvenance validation requires WorldGenerationContext")
		return failures
	if world_id != context.world_id:
		failures.append("GenerationProvenance world_id does not match context")
	if generator_manifest_id != context.generator_manifest_id:
		failures.append("GenerationProvenance generator manifest does not match context")
	if not expected_stage_id.is_empty() and stage_id != expected_stage_id:
		failures.append("GenerationProvenance stage mismatch: expected %s got %s" % [expected_stage_id, stage_id])
	if not expected_region_id.is_empty() and region_id != expected_region_id:
		failures.append("GenerationProvenance region mismatch")
	if expected_sources != null:
		var expected: Array[String] = []
		for value in expected_sources:
			expected.append(str(value))
		expected.sort()
		if expected != source_stage_fingerprints:
			failures.append("GenerationProvenance source fingerprint ancestry mismatch")
	return failures


func requires_sources(expected_sources: Array) -> Array[String]:
	var failures: Array[String] = []
	var available: Dictionary = {}
	for source in source_stage_fingerprints:
		available[str(source)] = true
	for value in expected_sources:
		if not available.has(str(value)):
			failures.append("GenerationProvenance missing required source fingerprint: " + str(value))
	return failures


func validate_exact_sources(expected_sources: Array) -> Array[String]:
	var expected: Array[String] = []
	for value in expected_sources:
		expected.append(str(value))
	expected.sort()
	var actual: Array[String] = source_stage_fingerprints.duplicate()
	actual.sort()
	if actual != expected:
		return ["GenerationProvenance source fingerprint set mismatch"]
	return []


func canonical_data() -> Dictionary:
	return {
		"contract_revision": CONTRACT_REVISION,
		"world_id": world_id,
		"generator_manifest_id": generator_manifest_id,
		"region_id": region_id,
		"region_address": region_address,
		"stage_id": stage_id,
		"stage_contract_revision": stage_contract_revision,
		"source_stage_fingerprints": source_stage_fingerprints,
	}


func canonical_text() -> String:
	return CanonicalValue.encode(canonical_data())
