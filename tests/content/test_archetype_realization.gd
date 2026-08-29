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
const ArchetypeRealizer := preload("res://core/content/archetypes/archetype_realizer.gd")
const PackedSceneArchetypeAdapter := preload("res://core/content/archetypes/packed_scene_archetype_adapter.gd")
const TaggedArchetypeAdapter := preload("res://tests/content/fixtures/archetypes/tagged_archetype_adapter.gd")

const ALPHA_SCENE := "res://tests/content/fixtures/archetypes/variant_alpha.tscn"
const BETA_SCENE := "res://tests/content/fixtures/archetypes/variant_beta.tscn"
const SPAWNABLE := "capability.realization.spawnable"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_two_variants_through_generic_realizer(failures)
	_test_binding_swap_and_runtime_state_separation(failures)
	_test_content005_boundary_blocks_invalid_definitions(failures)
	_test_explicit_realization_failures_and_adapter_extension(failures)
	return failures


static func _test_two_variants_through_generic_realizer(failures: Array[String]) -> void:
	var alpha = _definition("archetype.proof.alpha", ResourceLoader.load(ALPHA_SCENE), "packed.scene")
	var beta = _definition("archetype.proof.beta", ResourceLoader.load(BETA_SCENE), "packed.scene")
	var validation: Dictionary = _validation_result([beta, alpha])
	if not bool(validation.get("success", false)):
		failures.append("runtime proof definitions failed CONTENT-005 validation: %s" % [validation.get("diagnostics", [])])
		return

	var registry = ContentRegistry.new()
	var registry_failures: Array[String] = registry.index_definitions([beta, alpha])
	if not registry_failures.is_empty():
		failures.append("runtime proof registry rejected valid archetypes: %s" % [registry_failures])
		return

	var realizer = ArchetypeRealizer.new()
	var adapter_failures: Array[String] = realizer.register_adapter(PackedSceneArchetypeAdapter.new())
	if not adapter_failures.is_empty():
		failures.append("generic realizer rejected PackedScene adapter: %s" % [adapter_failures])
		return

	var alpha_result: Dictionary = realizer.realize(registry, validation, alpha.content_id)
	var beta_result: Dictionary = realizer.realize(registry, validation, beta.content_id)
	if not bool(alpha_result.get("success", false)):
		failures.append("generic realizer failed alpha archetype: %s" % [alpha_result.get("diagnostics", [])])
	if not bool(beta_result.get("success", false)):
		failures.append("generic realizer failed beta archetype: %s" % [beta_result.get("diagnostics", [])])
	if str(alpha_result.get("adapter_id", "")) != "packed.scene" or str(beta_result.get("adapter_id", "")) != "packed.scene":
		failures.append("two archetype variants did not route through the same generic realization adapter")

	var alpha_instance = alpha_result.get("instance", null)
	var beta_instance = beta_result.get("instance", null)
	if alpha_instance == null or beta_instance == null:
		failures.append("valid archetype realization did not produce runtime instances")
	else:
		if str(alpha_instance.name) == str(beta_instance.name):
			failures.append("fixture proof expected different node names to demonstrate name-independent roles")
		if not alpha_instance.is_in_group(ArchetypeComposition.role_group_name("root")):
			failures.append("alpha realized root does not expose semantic root role")
		if not beta_instance.is_in_group(ArchetypeComposition.role_group_name("root")):
			failures.append("beta realized root does not expose semantic root role")
	_free_result_instance(alpha_result)
	_free_result_instance(beta_result)


static func _test_binding_swap_and_runtime_state_separation(failures: Array[String]) -> void:
	var original = _definition("archetype.proof.rebind", ResourceLoader.load(ALPHA_SCENE), "packed.scene")
	var rebound = _definition("archetype.proof.rebind", ResourceLoader.load(BETA_SCENE), "packed.scene")
	if original.content_id != rebound.content_id:
		failures.append("backing scene replacement changed semantic archetype ContentId")

	var validation: Dictionary = _validation_result([rebound])
	if not bool(validation.get("success", false)):
		failures.append("rebound archetype failed CONTENT-005 validation: %s" % [validation.get("diagnostics", [])])
		return
	var registry = ContentRegistry.new()
	var registry_failures: Array[String] = registry.index_definitions([rebound])
	if not registry_failures.is_empty():
		failures.append("rebound archetype failed registry indexing: %s" % [registry_failures])
		return
	var realizer = ArchetypeRealizer.new()
	realizer.register_adapter(PackedSceneArchetypeAdapter.new())
	var result: Dictionary = realizer.realize(registry, validation, rebound.content_id)
	if not bool(result.get("success", false)):
		failures.append("rebound archetype failed realization without central-manager change: %s" % [result.get("diagnostics", [])])
		return

	var before_definition: Dictionary = rebound.canonical_descriptor().duplicate(true)
	var instance = result.get("instance", null)
	instance.set_meta("runtime_health", 7)
	instance.set_meta("runtime_instance_state", {"temporary": true})
	if rebound.canonical_descriptor() != before_definition:
		failures.append("mutable runtime instance state leaked into shared archetype definition")
	_free_result_instance(result)


static func _test_content005_boundary_blocks_invalid_definitions(failures: Array[String]) -> void:
	var realizer = ArchetypeRealizer.new()
	realizer.register_adapter(PackedSceneArchetypeAdapter.new())

	var missing_capability = _definition(
		"archetype.invalid.runtime_capability",
		ResourceLoader.load(ALPHA_SCENE),
		"packed.scene",
		[],
		[SPAWNABLE]
	)
	var capability_registry = ContentRegistry.new()
	var capability_index_failures: Array[String] = capability_registry.index_definitions([missing_capability])
	if not capability_index_failures.is_empty():
		failures.append("base ContentRegistry unexpectedly rejected missing-capability proof: %s" % [capability_index_failures])
	else:
		var capability_validation: Dictionary = _validation_result([missing_capability])
		if bool(capability_validation.get("success", false)):
			failures.append("CONTENT-005 unexpectedly accepted missing required realization capability")
		var capability_result: Dictionary = realizer.realize(
			capability_registry,
			capability_validation,
			missing_capability.content_id
		)
		if bool(capability_result.get("success", false)) or capability_result.get("instance", null) != null:
			failures.append("realizer instantiated definition rejected by CONTENT-005 capability rules")
		if not _contains_fragment(capability_result.get("diagnostics", []), "CONTENT-005 family_rule"):
			failures.append("runtime capability rejection did not surface CONTENT-005 family-rule evidence")

	var missing_reference = _definition(
		"archetype.invalid.runtime_reference",
		ResourceLoader.load(ALPHA_SCENE),
		"packed.scene"
	)
	missing_reference.configure_semantic_references([
		ContentReference.new(
			missing_reference.content_id,
			"dependency.required",
			"archetype.missing.target",
			"archetype",
			true
		),
	])
	var reference_registry = ContentRegistry.new()
	var reference_index_failures: Array[String] = reference_registry.index_definitions([missing_reference])
	if not reference_index_failures.is_empty():
		failures.append("base ContentRegistry unexpectedly rejected missing-reference proof: %s" % [reference_index_failures])
	else:
		var reference_validation: Dictionary = _validation_result([missing_reference])
		if bool(reference_validation.get("success", false)):
			failures.append("CONTENT-005 unexpectedly accepted missing semantic reference")
		var reference_result: Dictionary = realizer.realize(
			reference_registry,
			reference_validation,
			missing_reference.content_id
		)
		if bool(reference_result.get("success", false)) or reference_result.get("instance", null) != null:
			failures.append("realizer instantiated definition rejected by CONTENT-005 reference resolution")
		if not _contains_fragment(reference_result.get("diagnostics", []), "CONTENT-005 reference_resolution"):
			failures.append("runtime reference rejection did not surface CONTENT-005 resolution evidence")

	var valid = _definition("archetype.proof.validation_required", ResourceLoader.load(ALPHA_SCENE), "packed.scene")
	var valid_registry = ContentRegistry.new()
	valid_registry.index_definitions([valid])
	var missing_evidence_result: Dictionary = realizer.realize(valid_registry, {}, valid.content_id)
	if bool(missing_evidence_result.get("success", false)):
		failures.append("realizer accepted an archetype without explicit CONTENT-005 validation evidence")
	if not _contains_fragment(missing_evidence_result.get("diagnostics", []), "expected CONTENT-005 validation result"):
		failures.append("missing CONTENT-005 prerequisite did not fail explicitly")

	var uncovered_result: Dictionary = realizer.realize(
		valid_registry,
		{"success": true, "validated_definition_ids": [], "diagnostics": []},
		valid.content_id
	)
	if bool(uncovered_result.get("success", false)):
		failures.append("realizer accepted validation evidence that did not cover the requested ContentId")
	if not _contains_fragment(uncovered_result.get("diagnostics", []), "does not cover content id"):
		failures.append("uncovered CONTENT-005 validation result did not fail explicitly")


static func _test_explicit_realization_failures_and_adapter_extension(failures: Array[String]) -> void:
	var realizer = ArchetypeRealizer.new()
	var packed_failures: Array[String] = realizer.register_adapter(PackedSceneArchetypeAdapter.new())
	var tagged_failures: Array[String] = realizer.register_adapter(TaggedArchetypeAdapter.new())
	if not packed_failures.is_empty() or not tagged_failures.is_empty():
		failures.append("realizer could not register independent adapters: %s / %s" % [packed_failures, tagged_failures])
		return
	var expected_adapter_ids: Array[String] = ["packed.scene", "test.tagged"]
	if realizer.adapter_ids() != expected_adapter_ids:
		failures.append("adapter registration is not canonical/extension-safe: %s" % [realizer.adapter_ids()])

	var missing_role = _definition("archetype.invalid.role", ResourceLoader.load(ALPHA_SCENE), "packed.scene")
	missing_role.composition.required_roles.append("socket.missing")
	var missing_role_validation: Dictionary = _validation_result([missing_role])
	var missing_role_registry = ContentRegistry.new()
	missing_role_registry.index_definitions([missing_role])
	var missing_role_result: Dictionary = realizer.realize(
		missing_role_registry,
		missing_role_validation,
		missing_role.content_id
	)
	if bool(missing_role_result.get("success", false)):
		failures.append("realizer accepted a PackedScene missing a required semantic role")
	if not _contains_fragment(missing_role_result.get("diagnostics", []), "missing required role 'socket.missing'"):
		failures.append("missing runtime role did not produce an actionable realization diagnostic")

	var missing_adapter = _definition("archetype.invalid.adapter", ResourceLoader.load(ALPHA_SCENE), "unregistered.adapter")
	var missing_adapter_validation: Dictionary = _validation_result([missing_adapter])
	var missing_adapter_registry = ContentRegistry.new()
	missing_adapter_registry.index_definitions([missing_adapter])
	var missing_adapter_result: Dictionary = realizer.realize(
		missing_adapter_registry,
		missing_adapter_validation,
		missing_adapter.content_id
	)
	if not _contains_fragment(missing_adapter_result.get("diagnostics", []), "no realization adapter registered"):
		failures.append("unregistered realization adapter did not fail explicitly")

	var wrong_packed_binding := Curve.new()
	wrong_packed_binding.add_point(Vector2(0.0, 0.0))
	var wrong_packed = _definition(
		"archetype.invalid.packed_binding",
		wrong_packed_binding,
		"packed.scene"
	)
	var wrong_packed_validation: Dictionary = _validation_result([wrong_packed])
	if not bool(wrong_packed_validation.get("success", false)):
		failures.append("generic CONTENT-005 contract should not own PackedScene adapter typing")
	var wrong_packed_registry = ContentRegistry.new()
	wrong_packed_registry.index_definitions([wrong_packed])
	var wrong_packed_result: Dictionary = realizer.realize(
		wrong_packed_registry,
		wrong_packed_validation,
		wrong_packed.content_id
	)
	if bool(wrong_packed_result.get("success", false)):
		failures.append("PackedScene adapter accepted a non-PackedScene binding")
	if not _contains_fragment(wrong_packed_result.get("diagnostics", []), "expected PackedScene resource binding"):
		failures.append("PackedScene adapter did not own its resource-type diagnostic")

	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(1.0, 1.0))
	var tagged = _definition("archetype.proof.tagged", curve, "test.tagged")
	var tagged_validation: Dictionary = _validation_result([tagged])
	if not bool(tagged_validation.get("success", false)):
		failures.append("non-PackedScene tagged archetype failed generic CONTENT-005 validation: %s" % [tagged_validation.get("diagnostics", [])])
	var tagged_registry = ContentRegistry.new()
	tagged_registry.index_definitions([tagged])
	var tagged_result: Dictionary = realizer.realize(tagged_registry, tagged_validation, tagged.content_id)
	if not bool(tagged_result.get("success", false)):
		failures.append("second adapter could not realize through unchanged generic realizer: %s" % [tagged_result.get("diagnostics", [])])
	else:
		var tagged_instance = tagged_result.get("instance", null)
		if str(tagged_instance.get_meta("test_adapter", "")) != "test.tagged":
			failures.append("second realization adapter did not own its family-specific construction behavior")
		if int(tagged_instance.get_meta("test_binding_point_count", -1)) != 2:
			failures.append("second realization adapter did not consume its Curve resource binding")
	_free_result_instance(tagged_result)


static func _definition(
	content_id: String,
	binding: Resource,
	adapter_id: String,
	declared_capabilities: Array = [SPAWNABLE],
	required_capabilities: Array = [SPAWNABLE]
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


static func _validation_result(definitions: Array) -> Dictionary:
	var categories = CategorySchemaRegistry.new()
	var category_failures: Array[String] = categories.index_schemas([])
	assert(category_failures.is_empty())
	var capabilities = CapabilitySchemaRegistry.new()
	var capability_failures: Array[String] = capabilities.index_schemas([
		CapabilitySchema.new().configure(SPAWNABLE),
	])
	assert(capability_failures.is_empty())
	var validator = ArchetypeFamilyValidator.new()
	validator.configure("archetype")
	return ContentValidationPipeline.new().validate_all(
		definitions,
		categories,
		capabilities,
		[validator]
	)


static func _contains_fragment(values: Array, fragment: String) -> bool:
	for value in values:
		if str(value).contains(fragment):
			return true
	return false


static func _free_result_instance(result: Dictionary) -> void:
	var instance = result.get("instance", null)
	if instance != null and instance is Node and is_instance_valid(instance):
		instance.free()
