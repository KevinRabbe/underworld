extends SceneTree

const ContentRegistryTests := preload("res://tests/content/test_content_registry.gd")
const ContentSchemaRegistryTests := preload("res://tests/content/test_content_schema_registries.gd")
const ContentValidationPipelineTests := preload("res://tests/content/test_content_validation_pipeline.gd")
const ArchetypeContractTests := preload("res://tests/content/test_archetype_contract.gd")
const ArchetypeRealizationTests := preload("res://tests/content/test_archetype_realization.gd")
const ItemContractTests := preload("res://tests/content/test_item_contract.gd")
const ResourceContractTests := preload("res://tests/content/test_resource_contract.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(ContentRegistryTests.run())
	failures.append_array(ContentSchemaRegistryTests.run())
	failures.append_array(ContentValidationPipelineTests.run())
	failures.append_array(ArchetypeContractTests.run())
	failures.append_array(ArchetypeRealizationTests.run())
	failures.append_array(ItemContractTests.run())
	failures.append_array(ResourceContractTests.run())
	if failures.is_empty():
		print("[VALIDATION] PASS content")
		print("  semantic content ids / deterministic registry / category-capability schemas / headless validation / archetype realization / item + resource rulebook contracts passed")
		quit(0)
		return

	printerr("[VALIDATION] FAIL content — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
