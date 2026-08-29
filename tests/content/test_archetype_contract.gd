extends RefCounted

const ContentReference := preload("res://core/content/references/content_reference.gd")
const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchema := preload("res://core/content/schema/capability_schema.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ContentValidationPipeline := preload("res://core/content/validation/content_validation_pipeline.gd")
const ArchetypeComposition := preload("res://core/content/archetypes/archetype_composition.gd")
const ArchetypeDefinition := preload("res://core/content/archetypes/archetype_definition.gd")
const ArchetypeFamilyValidator := preload("res://core/content/archetypes/archetype_family_validator.gd")

const ALPHA_SCENE := "res://tests/content/fixtures/archetypes/variant_alpha.tscn"
const BETA_SCENE := "res://tests/content/fixtures/archetypes/variant_beta.tscn"
const SPAWNABLE := "capability.realization.spawnable"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_valid_headless_definitions(failures)
	_test_binding_is_not_semantic_identity(failures)
	_test_adapter_neutral_binding_contract(failures)
	_test_static_failures_route_through_content_validation(failures)
	return failures


static func _test_valid_headless_definitions(failures: Array[String]) -> void:
	var categories = _categories()
	var capabilities = _capabilities()
	var alpha = _definition("archetype.proof.alpha", ALPHA_SCENE)
	var beta = _definition("archetype.proof.beta", BETA_SCENE)
	alpha.configure_semantic_references([
		ContentReference.new(
			"archetype.proof.alpha",
			"variant.peer",
			"archetype.proof.beta",
			"archetype",
			true
		),
	])

	var validator = ArchetypeFamilyValidator.new()
	validator.configure("archetype")
	var pipeline = ContentValidationPipeline.new()
	var result: Dictionary = pipeline.validate_all(
		[beta, alpha],
		categories,
		capabilities,
		[validator]
	)
	if not bool(result.get("success", false)):
		failures.append("valid archetype definitions failed CONTENT-005 validation: %s" % [result.get("diagnostics", [])])
	var expected_ids: Array[String] = ["archetype.proof.alpha", "archetype.proof.beta"]
	if result.get("validated_definition_ids", []) != expected_ids:
		failures.append("archetype validation returned non-canonical ids: %s" % [result.get("validated_definition_ids", [])])

	var registry = ContentRegistry.new()
	var registry_failures: Array[String] = registry.index_definitions([alpha, beta])
	if not registry_failures.is_empty():
		failures.append("valid archetypes failed accepted ContentRegistry indexing: %s" % [registry_failures])
	if registry.definition_ids() != expected_ids:
		failures.append("accepted ContentRegistry did not retain semantic archetype ids")

	if alpha is Node or alpha.composition is Node or validator is Node or pipeline is Node:
		failures.append("headless archetype definition/validation contracts unexpectedly own runtime Nodes")
	if alpha.composition.resource_binding == null or not alpha.composition.resource_binding is PackedScene:
		failures.append("headless archetype proof did not retain its replaceable PackedScene Resource binding")


static func _test_binding_is_not_semantic_identity(failures: Array[String]) -> void:
	var alpha = _definition("archetype.proof.alpha", ALPHA_SCENE)
	var rebound = _definition("archetype.proof.alpha", BETA_SCENE)
	if alpha.content_id != rebound.content_id:
		failures.append("changing backing scene changed semantic archetype identity")
	var alpha_path: String = str(alpha.composition.canonical_descriptor().get("resource_binding_path", ""))
	var rebound_path: String = str(rebound.composition.canonical_descriptor().get("resource_binding_path", ""))
	if alpha_path == rebound_path or alpha_path.is_empty() or rebound_path.is_empty():
		failures.append("binding-swap proof did not use two distinct PackedScene resource paths")
	if alpha.canonical_descriptor().get("content_id", "") != rebound.canonical_descriptor().get("content_id", ""):
		failures.append("canonical archetype descriptor does not preserve ContentId across binding replacement")


static func _test_adapter_neutral_binding_contract(failures: Array[String]) -> void:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(1.0, 1.0))
	var tagged = _definition_with_binding(
		"archetype.proof.curve_binding",
		curve,
		"test.tagged",
		[SPAWNABLE],
		[SPAWNABLE]
	)
	var validator = ArchetypeFamilyValidator.new()
	validator.configure("archetype")
	var result: Dictionary = ContentValidationPipeline.new().validate_all(
		[tagged],
		_categories(),
		_capabilities(),
		[validator]
	)
	if not bool(result.get("success", false)):
		failures.append(
			"shared archetype definition contract rejected adapter-specific non-PackedScene Resource: %s" % [
				result.get("diagnostics", []),
			]
		)


static func _test_static_failures_route_through_content_validation(failures: Array[String]) -> void:
	var categories = _categories()
	var capabilities = _capabilities()
	var validator = ArchetypeFamilyValidator.new()
	validator.configure("archetype")
	var pipeline = ContentValidationPipeline.new()

	var missing_binding = _definition_with_binding(
		"archetype.invalid.binding",
		null,
		"packed.scene",
		[SPAWNABLE],
		[SPAWNABLE]
	)
	var binding_result: Dictionary = pipeline.validate_all(
		[missing_binding],
		categories,
		capabilities,
		[validator]
	)
	if not _has_code_fragment(binding_result, "definition_invalid", "realization resource binding is required"):
		failures.append("missing generic archetype resource binding did not fail before runtime")

	var missing_capability = _definition_with_binding(
		"archetype.invalid.capability",
		ResourceLoader.load(ALPHA_SCENE),
		"packed.scene",
		[SPAWNABLE],
		[]
	)
	var capability_result: Dictionary = pipeline.validate_all(
		[missing_capability],
		categories,
		capabilities,
		[validator]
	)
	if not _has_code_fragment(capability_result, "family_rule", "does not provide required realization capability"):
		failures.append("archetype family validator did not enforce required realization capabilities")

	var missing_reference = _definition("archetype.invalid.reference", ALPHA_SCENE)
	missing_reference.configure_semantic_references([
		ContentReference.new(
			"archetype.invalid.reference",
			"dependency.required",
			"archetype.missing.target",
			"archetype",
			true
		),
	])
	var reference_result: Dictionary = pipeline.validate_all(
		[missing_reference],
		categories,
		capabilities,
		[validator]
	)
	if not _has_code_fragment(reference_result, "reference_resolution", "missing content definition"):
		failures.append("archetype typed semantic reference did not use CONTENT-005 resolution diagnostics")


static func _definition(content_id: String, scene_path: String):
	return _definition_with_binding(
		content_id,
		ResourceLoader.load(scene_path),
		"packed.scene",
		[SPAWNABLE],
		[SPAWNABLE]
	)


static func _definition_with_binding(
	content_id: String,
	binding: Resource,
	adapter_id: String,
	required_capabilities: Array,
	declared_capabilities: Array
):
	var composition = ArchetypeComposition.new()
	composition.configure(
		adapter_id,
		binding,
		["root", "interaction.primary"],
		required_capabilities
	)
	var definition = ArchetypeDefinition.new()
	definition.configure_archetype(content_id, "archetype", composition, 1)
	definition.configure_schema_declarations([], declared_capabilities)
	return definition


static func _categories():
	var registry = CategorySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([])
	assert(diagnostics.is_empty())
	return registry


static func _capabilities():
	var registry = CapabilitySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CapabilitySchema.new().configure(SPAWNABLE),
	])
	assert(diagnostics.is_empty())
	return registry


static func _has_code_fragment(result: Dictionary, code: String, fragment: String) -> bool:
	for diagnostic in result.get("diagnostics", []):
		if (
			str(diagnostic.get("code", "")) == code
			and str(diagnostic.get("message", "")).contains(fragment)
		):
			return true
	return false
