extends RefCounted
class_name UnderworldWorldDefinitionIndex

const SCHEMA_VERSION: int = 1

var world_seed: int
var schema_version: int
var generator_manifest_id: String
var seed_schema_version: int
var world_id: String
var surface_definition_address: String
var underground_region_addressing: Dictionary


func _init(
	world_seed_value: int,
	generator_manifest_id_value: String,
	seed_schema_version_value: int,
	world_id_value: String,
	surface_definition_address_value: String = "",
	underground_region_addressing_value: Dictionary = {}
) -> void:
	world_seed = world_seed_value
	schema_version = SCHEMA_VERSION
	generator_manifest_id = generator_manifest_id_value
	seed_schema_version = seed_schema_version_value
	world_id = world_id_value
	surface_definition_address = surface_definition_address_value
	underground_region_addressing = underground_region_addressing_value.duplicate(true)
