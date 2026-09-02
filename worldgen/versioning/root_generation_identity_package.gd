extends RefCounted
class_name UnderworldRootGenerationIdentityPackage

const GeneratorManifest := preload("res://worldgen/versioning/generator_manifest.gd")
const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const WorldId := preload("res://worldgen/identity/world_id.gd")

const PACKAGE_SCHEMA_VERSION: int = 1


static func encode(context) -> Dictionary:
	if context == null:
		return {}
	return {
		"package_schema_version": PACKAGE_SCHEMA_VERSION,
		"world_id": str(context.world_id),
		"world_id_contract": context.world_id_contract(),
		"manifest_snapshot": context.manifest_snapshot(),
	}


static func decode(package_value: Dictionary) -> Dictionary:
	var failures: Array[String] = _validate_package_structure(package_value)
	if not failures.is_empty():
		return {
			"success": false,
			"failures": failures,
		}

	var manifest_snapshot: Dictionary = package_value["manifest_snapshot"].duplicate(true)
	var manifest = GeneratorManifest.from_snapshot(manifest_snapshot)
	failures.append_array(manifest.validate())
	if not failures.is_empty():
		return {
			"success": false,
			"failures": failures,
		}

	return {
		"success": true,
		"failures": [],
		"world_id": str(package_value["world_id"]),
		"world_id_contract": package_value["world_id_contract"].duplicate(true),
		"manifest": manifest,
		"manifest_snapshot": manifest_snapshot,
	}


static func rehydrate(
	world_seed: int,
	package_value: Dictionary,
	manifest_runtime_support: Dictionary = {},
	supported_world_id_contracts: Array = []
) -> Dictionary:
	var decoded: Dictionary = decode(package_value)
	if not bool(decoded.get("success", false)):
		return {
			"success": false,
			"compatible": false,
			"failures": decoded.get("failures", []),
			"compatibility_failures": [],
			"context": null,
		}

	var context = WorldGenerationContext.from_exact_identity(
		world_seed,
		str(decoded["world_id"]),
		decoded["world_id_contract"],
		decoded["manifest"]
	)
	var structural_failures: Array[String] = context.validate_structure()
	if not structural_failures.is_empty():
		return {
			"success": false,
			"compatible": false,
			"failures": structural_failures,
			"compatibility_failures": [],
			"context": context,
		}

	var compatibility_failures: Array[String] = context.runtime_compatibility_failures(
		manifest_runtime_support,
		supported_world_id_contracts
	)
	return {
		"success": true,
		"compatible": compatibility_failures.is_empty(),
		"failures": [],
		"compatibility_failures": compatibility_failures,
		"context": context,
	}


static func _validate_package_structure(package_value: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var required_fields: Array[String] = [
		"package_schema_version",
		"world_id",
		"world_id_contract",
		"manifest_snapshot",
	]
	for field in required_fields:
		if not package_value.has(field):
			failures.append("Root generation identity package is missing field: " + field)
	if not failures.is_empty():
		return failures

	if (
		typeof(package_value["package_schema_version"]) != TYPE_INT
		or int(package_value["package_schema_version"]) != PACKAGE_SCHEMA_VERSION
	):
		failures.append(
			"Root generation identity package schema is unsupported: %s"
			% str(package_value["package_schema_version"])
		)

	if typeof(package_value["world_id"]) != TYPE_STRING:
		failures.append("Root generation identity package world_id must be a String")
	if typeof(package_value["world_id_contract"]) != TYPE_DICTIONARY:
		failures.append("Root generation identity package world_id_contract must be a Dictionary")
	if typeof(package_value["manifest_snapshot"]) != TYPE_DICTIONARY:
		failures.append("Root generation identity package manifest_snapshot must be a Dictionary")
	if not failures.is_empty():
		return failures

	var contract: Dictionary = package_value["world_id_contract"]
	failures.append_array(WorldId.validate_contract_descriptor_structure(contract))
	if WorldId.parse_with_contract(str(package_value["world_id"]), contract) == null:
		failures.append("Root generation identity package WorldId is malformed for captured contract")
	failures.append_array(
		GeneratorManifest.validate_snapshot(package_value["manifest_snapshot"])
	)
	return failures
