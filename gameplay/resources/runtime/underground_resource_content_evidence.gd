extends RefCounted
class_name UndergroundResourceContentEvidence

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const CategorySchema := preload("res://core/content/schema/category_schema.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchema := preload("res://core/content/schema/capability_schema.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ContentValidationPipeline := preload("res://core/content/validation/content_validation_pipeline.gd")

const IRON_RESOURCE_CONTENT_ID := "resource.deposit.iron_outcrop"
const IRON_ARCHETYPE_CONTENT_ID := "archetype.resource.iron_outcrop.prototype"
const IRON_RESOURCE_CATEGORY_ID := "category.resource.deposit"
const IRON_ITEM_CATEGORY_ID := "category.item.resource"
const EXCAVATABLE_CAPABILITY_ID := "capability.excavatable"

const IRON_RESOURCE_PATH := "res://content/resources/iron_outcrop_definition.tres"
const IRON_ITEM_PATH := "res://content/items/resources/iron_chunk_definition.tres"
const IRON_ARCHETYPE_PATH := "res://content/resources/archetypes/iron_outcrop_archetype.tres"
const IRON_CONTENT_PATHS: Array[String] = [
	IRON_RESOURCE_PATH,
	IRON_ITEM_PATH,
	IRON_ARCHETYPE_PATH,
]


# CONTENT-006 authority for the first production iron closure. This deliberately
# does not become a second gameplay content registry: the returned registries
# exist only to create and later freshness-check the accepted validation proof.
static func build_first_iron_authority() -> Dictionary:
	var setup_failures: Array[String] = []
	var definitions: Array = []
	for path in IRON_CONTENT_PATHS:
		if not ResourceLoader.exists(path):
			setup_failures.append("iron validation content resource does not exist: %s" % path)
			continue
		var definition = ResourceLoader.load(path)
		if definition == null:
			setup_failures.append("iron validation content resource failed to load: %s" % path)
			continue
		definitions.append(definition)

	var content_registry = ContentRegistry.new()
	for failure in content_registry.index_definitions(definitions):
		setup_failures.append("content registry: %s" % failure)

	var category_registry = CategorySchemaRegistry.new()
	var category_schemas: Array = [
		CategorySchema.new().configure(IRON_RESOURCE_CATEGORY_ID),
		CategorySchema.new().configure(IRON_ITEM_CATEGORY_ID),
	]
	for failure in category_registry.index_schemas(category_schemas):
		setup_failures.append("category registry: %s" % failure)

	var capability_registry = CapabilitySchemaRegistry.new()
	var capability_schemas: Array = [
		CapabilitySchema.new().configure(EXCAVATABLE_CAPABILITY_ID),
	]
	for failure in capability_registry.index_schemas(capability_schemas):
		setup_failures.append("capability registry: %s" % failure)

	var validation_result: Dictionary = ContentValidationPipeline.new().validate_ids(
		definitions,
		[IRON_RESOURCE_CONTENT_ID, IRON_ARCHETYPE_CONTENT_ID],
		category_registry,
		capability_registry
	)
	setup_failures.sort()
	return {
		"definitions": definitions,
		"content_registry": content_registry,
		"category_registry": category_registry,
		"capability_registry": capability_registry,
		"validation_result": validation_result,
		"setup_failures": setup_failures,
	}


static func verification_failures(
	authority: Dictionary,
	required_content_id: String = IRON_RESOURCE_CONTENT_ID
) -> Array[String]:
	var failures: Array[String] = []
	for failure in authority.get("setup_failures", []):
		failures.append(str(failure))

	var validation_variant = authority.get("validation_result", null)
	if not validation_variant is Dictionary:
		failures.append("iron validation authority is missing validation_result")
		failures.sort()
		return failures
	var validation_result: Dictionary = validation_variant
	if not bool(validation_result.get("success", false)):
		for diagnostic in validation_result.get("diagnostics", []):
			failures.append("validation: %s" % str(diagnostic))

	var content_registry = authority.get("content_registry", null)
	var current_context := {
		"category_registry": authority.get("category_registry", null),
		"capability_registry": authority.get("capability_registry", null),
	}
	for failure in ContentValidationPipeline.evidence_failures(
		validation_result,
		content_registry,
		required_content_id,
		current_context
	):
		failures.append(str(failure))
	failures.sort()
	return failures
