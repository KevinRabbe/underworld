extends "res://core/content/validation/content_family_validator.gd"

const ArchetypeDefinition := preload("res://core/content/archetypes/archetype_definition.gd")
const ArchetypeComposition := preload("res://core/content/archetypes/archetype_composition.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")


func applies_to(definition) -> bool:
	return (
		definition != null
		and definition is ArchetypeDefinition
		and str(definition.definition_family) == definition_family
	)


func validate_definition(definition, context: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	if definition == null or not definition is ArchetypeDefinition:
		return failures
	if definition.composition == null or not definition.composition is ArchetypeComposition:
		return failures

	var capability_registry = context.get("capability_registry", null)
	if (
		capability_registry == null
		or not capability_registry is CapabilitySchemaRegistry
		or not capability_registry.is_valid()
	):
		return failures

	for required_capability_id in definition.composition.required_capability_ids:
		if not capability_registry.provides_capability(
			definition.capability_ids,
			required_capability_id
		):
			failures.append(
				"archetype '%s' does not provide required realization capability: %s" % [
					definition.content_id,
					required_capability_id,
				]
			)
	failures.sort()
	return failures
