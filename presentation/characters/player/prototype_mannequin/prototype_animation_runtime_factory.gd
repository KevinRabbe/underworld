extends RefCounted

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ContentValidationPipeline := preload("res://core/content/validation/content_validation_pipeline.gd")
const CharacterSemanticSchemaCatalog := preload("res://presentation/characters/animation/character_semantic_schema_catalog.gd")
const CharacterAnimationController := preload("res://presentation/characters/animation/character_animation_controller.gd")
const PrototypeMannequinPresentationAdapter := preload("res://presentation/characters/player/prototype_mannequin/prototype_mannequin_presentation_adapter.gd")

const ANIMATION_SET_ID := "animation_set.humanoid.prototype"
const ANIMATION_SET_PATH := "res://content/characters/animation_sets/prototype_humanoid_animation_set.tres"
const RIG_PROFILE_PATH := "res://content/characters/rig_profiles/prototype_humanoid_rig_profile.tres"


static func build(mannequin, supplied_adapter = null) -> Dictionary:
	var failures: Array[String] = []
	var content_registry = ContentRegistry.new()
	for failure in content_registry.load_resource_paths([
		ANIMATION_SET_PATH,
		RIG_PROFILE_PATH,
	]):
		failures.append("content load: %s" % failure)

	var definitions: Array = []
	for content_id in content_registry.definition_ids():
		definitions.append(content_registry.get_definition(content_id))

	var category_registry = CategorySchemaRegistry.new()
	category_registry.index_schemas([])
	var capability_registry = CapabilitySchemaRegistry.new()
	capability_registry.index_schemas([])
	var validation_result: Dictionary = ContentValidationPipeline.new().validate_all(
		definitions,
		category_registry,
		capability_registry
	)
	if not bool(validation_result.get("success", false)):
		for diagnostic in validation_result.get("diagnostics", []):
			if diagnostic is Dictionary:
				failures.append("CONTENT-005 %s: %s" % [
					str(diagnostic.get("code", "diagnostic")),
					str(diagnostic.get("message", "")),
				])

	var role_registry = CharacterSemanticSchemaCatalog.build_registry()
	for failure in role_registry.diagnostics():
		failures.append("semantic role registry: %s" % failure)

	var presentation_adapter = supplied_adapter if supplied_adapter != null else PrototypeMannequinPresentationAdapter.new(mannequin)
	var controller = CharacterAnimationController.new()
	for failure in controller.configure(
		content_registry,
		validation_result,
		role_registry,
		ANIMATION_SET_ID,
		presentation_adapter
	):
		failures.append("animation controller: %s" % failure)

	failures.sort()
	return {
		"success": failures.is_empty() and controller.is_ready(),
		"controller": controller,
		"content_registry": content_registry,
		"content_validation": validation_result,
		"role_registry": role_registry,
		"diagnostics": failures,
	}
