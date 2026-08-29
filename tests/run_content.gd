extends SceneTree

const ContentRegistryTests := preload("res://tests/content/test_content_registry.gd")
const ContentSchemaRegistryTests := preload("res://tests/content/test_content_schema_registries.gd")
const SemanticRoleSchemaRegistryTests := preload("res://tests/content/test_semantic_role_schema_registry.gd")
const ContentValidationPipelineTests := preload("res://tests/content/test_content_validation_pipeline.gd")
const ArchetypeContractTests := preload("res://tests/content/test_archetype_contract.gd")
const ArchetypeRealizationTests := preload("res://tests/content/test_archetype_realization.gd")
const ItemContractTests := preload("res://tests/content/test_item_contract.gd")
const ResourceContractTests := preload("res://tests/content/test_resource_contract.gd")
const CreatureContractTests := preload("res://tests/content/test_creature_contract.gd")
const WeaponContractTests := preload("res://tests/content/test_weapon_contract.gd")
const ReservedSiteAssignmentTests := preload("res://tests/content/test_reserved_site_assignment.gd")
const UndergroundPlacementTests := preload("res://tests/content/test_underground_placement.gd")
const CraftingContractTests := preload("res://tests/crafting/test_crafting_contract.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(ContentRegistryTests.run())
	failures.append_array(ContentSchemaRegistryTests.run())
	failures.append_array(SemanticRoleSchemaRegistryTests.run())
	failures.append_array(ContentValidationPipelineTests.run())
	failures.append_array(ArchetypeContractTests.run())
	failures.append_array(ArchetypeRealizationTests.run())
	failures.append_array(ItemContractTests.run())
	failures.append_array(ResourceContractTests.run())
	failures.append_array(CreatureContractTests.run())
	failures.append_array(WeaponContractTests.run())
	failures.append_array(ReservedSiteAssignmentTests.run())
	failures.append_array(UndergroundPlacementTests.run())
	failures.append_array(CraftingContractTests.run())
	if failures.is_empty():
		print("[VALIDATION] PASS content")
		print("  semantic content ids / deterministic registry / category-capability-role schemas / headless validation / archetype realization / item / resource / creature / weapon / reserved-site assignment / underground placement / crafting rulebook contracts passed")
		quit(0)
		return

	printerr("[VALIDATION] FAIL content — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
