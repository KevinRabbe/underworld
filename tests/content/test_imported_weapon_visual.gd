extends RefCounted

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

const IMPORTED_GLB := "res://tests/content/fixtures/archetypes/imported_weapon_smoke.glb"
const IMPORTED_WRAPPER := "res://tests/content/fixtures/archetypes/imported_weapon_smoke.tscn"
const SPAWNABLE := "capability.realization.spawnable"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_imported_resource_and_wrapper(failures)
	_test_generic_archetype_realization(failures)
	return failures


static func _test_imported_resource_and_wrapper(failures: Array[String]) -> void:
	var imported = ResourceLoader.load(IMPORTED_GLB)
	if imported == null or not imported is PackedScene:
		failures.append("imported weapon GLB did not load as PackedScene")
		return
	var wrapper = ResourceLoader.load(IMPORTED_WRAPPER)
	if wrapper == null or not wrapper is PackedScene:
		failures.append("imported weapon wrapper did not load as PackedScene")
		return
	var instance: Node = wrapper.instantiate()
	if instance == null:
		failures.append("imported weapon wrapper failed to instantiate")
		return
	if not instance.is_in_group(ArchetypeComposition.role_group_name("root")):
		failures.append("imported weapon wrapper root is missing semantic root role")
	if not _tree_has_group(instance, ArchetypeComposition.role_group_name("interaction.primary")):
		failures.append("imported weapon wrapper is missing semantic interaction.primary role")
	if not _tree_has_mesh_instance(instance):
		failures.append("imported weapon wrapper contains no MeshInstance3D after GLB import")
	instance.free()


static func _test_generic_archetype_realization(failures: Array[String]) -> void:
	var wrapper = ResourceLoader.load(IMPORTED_WRAPPER)
	if wrapper == null or not wrapper is PackedScene:
		failures.append("generic imported-weapon realization has no valid wrapper PackedScene")
		return

	var composition = ArchetypeComposition.new()
	composition.configure(
		"packed.scene",
		wrapper,
		["root", "interaction.primary"],
		[SPAWNABLE]
	)
	var definition = ArchetypeDefinition.new()
	definition.configure_archetype(
		"archetype.proof.imported_weapon",
		"archetype",
		composition,
		1
	)
	definition.configure_schema_declarations([], [SPAWNABLE])

	var categories = CategorySchemaRegistry.new()
	var category_failures: Array[String] = categories.index_schemas([])
	if not category_failures.is_empty():
		failures.append("imported weapon proof category registry failed: %s" % [category_failures])
		return
	var capabilities = CapabilitySchemaRegistry.new()
	var capability_failures: Array[String] = capabilities.index_schemas([
		CapabilitySchema.new().configure(SPAWNABLE),
	])
	if not capability_failures.is_empty():
		failures.append("imported weapon proof capability registry failed: %s" % [capability_failures])
		return
	var validator = ArchetypeFamilyValidator.new()
	validator.configure("archetype")
	var validation: Dictionary = ContentValidationPipeline.new().validate_all(
		[definition],
		categories,
		capabilities,
		[validator]
	)
	if not bool(validation.get("success", false)):
		failures.append("imported weapon proof failed CONTENT validation: %s" % [validation.get("diagnostics", [])])
		return

	var registry = ContentRegistry.new()
	var registry_failures: Array[String] = registry.index_definitions([definition])
	if not registry_failures.is_empty() or not registry.is_valid():
		failures.append("imported weapon proof registry rejected valid archetype: %s" % [registry_failures])
		return
	var realizer = ArchetypeRealizer.new()
	var adapter_failures: Array[String] = realizer.register_adapter(PackedSceneArchetypeAdapter.new())
	if not adapter_failures.is_empty():
		failures.append("imported weapon proof could not register PackedScene adapter: %s" % [adapter_failures])
		return
	var result: Dictionary = realizer.realize(registry, validation, definition.content_id)
	if not bool(result.get("success", false)):
		failures.append("generic realizer failed imported weapon GLB wrapper: %s" % [result.get("diagnostics", [])])
		return
	var instance = result.get("instance", null)
	if instance == null or not instance is Node:
		failures.append("generic imported weapon realization produced no Node instance")
	elif not _tree_has_mesh_instance(instance):
		failures.append("generic imported weapon realization produced no MeshInstance3D")
	if instance != null and instance is Node and is_instance_valid(instance):
		instance.free()


static func _tree_has_mesh_instance(node: Node) -> bool:
	if node is MeshInstance3D:
		return true
	for child in node.get_children():
		if child is Node and _tree_has_mesh_instance(child):
			return true
	return false


static func _tree_has_group(node: Node, group_name: String) -> bool:
	if node.is_in_group(group_name):
		return true
	for child in node.get_children():
		if child is Node and _tree_has_group(child, group_name):
			return true
	return false
