extends RefCounted

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const ArchetypeComposition := preload("res://core/content/archetypes/archetype_composition.gd")
const ArchetypeDefinition := preload("res://core/content/archetypes/archetype_definition.gd")
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
	_test_explicit_realization_failures_and_adapter_extension(failures)
	return failures


static func _test_two_variants_through_generic_realizer(failures: Array[String]) -> void:
	var alpha = _definition("archetype.proof.alpha", ALPHA_SCENE, "packed.scene")
	var beta = _definition("archetype.proof.beta", BETA_SCENE, "packed.scene")
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

	var alpha_result: Dictionary = realizer.realize(registry, alpha.content_id)
	var beta_result: Dictionary = realizer.realize(registry, beta.content_id)
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
	var original = _definition("archetype.proof.rebind", ALPHA_SCENE, "packed.scene")
	var rebound = _definition("archetype.proof.rebind", BETA_SCENE, "packed.scene")
	if original.content_id != rebound.content_id:
		failures.append("backing scene replacement changed semantic archetype ContentId")

	var registry = ContentRegistry.new()
	var registry_failures: Array[String] = registry.index_definitions([rebound])
	if not registry_failures.is_empty():
		failures.append("rebound archetype failed registry indexing: %s" % [registry_failures])
		return
	var realizer = ArchetypeRealizer.new()
	realizer.register_adapter(PackedSceneArchetypeAdapter.new())
	var result: Dictionary = realizer.realize(registry, rebound.content_id)
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

	var missing_role = _definition("archetype.invalid.role", ALPHA_SCENE, "packed.scene")
	missing_role.composition.required_roles.append("socket.missing")
	var missing_role_registry = ContentRegistry.new()
	missing_role_registry.index_definitions([missing_role])
	var missing_role_result: Dictionary = realizer.realize(missing_role_registry, missing_role.content_id)
	if bool(missing_role_result.get("success", false)):
		failures.append("realizer accepted a PackedScene missing a required semantic role")
	if not _contains_fragment(missing_role_result.get("diagnostics", []), "missing required role 'socket.missing'"):
		failures.append("missing runtime role did not produce an actionable realization diagnostic")

	var missing_adapter = _definition("archetype.invalid.adapter", ALPHA_SCENE, "unregistered.adapter")
	var missing_adapter_registry = ContentRegistry.new()
	missing_adapter_registry.index_definitions([missing_adapter])
	var missing_adapter_result: Dictionary = realizer.realize(missing_adapter_registry, missing_adapter.content_id)
	if not _contains_fragment(missing_adapter_result.get("diagnostics", []), "no realization adapter registered"):
		failures.append("unregistered realization adapter did not fail explicitly")

	var tagged = _definition("archetype.proof.tagged", ALPHA_SCENE, "test.tagged")
	var tagged_registry = ContentRegistry.new()
	tagged_registry.index_definitions([tagged])
	var tagged_result: Dictionary = realizer.realize(tagged_registry, tagged.content_id)
	if not bool(tagged_result.get("success", false)):
		failures.append("second adapter could not realize through unchanged generic realizer: %s" % [tagged_result.get("diagnostics", [])])
	else:
		var tagged_instance = tagged_result.get("instance", null)
		if str(tagged_instance.get_meta("test_adapter", "")) != "test.tagged":
			failures.append("second realization adapter did not own its family-specific construction behavior")
	_free_result_instance(tagged_result)


static func _definition(content_id: String, scene_path: String, adapter_id: String):
	var composition = ArchetypeComposition.new()
	composition.configure(
		adapter_id,
		ResourceLoader.load(scene_path),
		["root", "interaction.primary"],
		[SPAWNABLE]
	)
	var definition = ArchetypeDefinition.new()
	definition.configure_archetype(content_id, "archetype", composition, 1)
	definition.configure_schema_declarations([], [SPAWNABLE])
	return definition


static func _contains_fragment(values: Array, fragment: String) -> bool:
	for value in values:
		if str(value).contains(fragment):
			return true
	return false


static func _free_result_instance(result: Dictionary) -> void:
	var instance = result.get("instance", null)
	if instance != null and instance is Node and is_instance_valid(instance):
		instance.free()
