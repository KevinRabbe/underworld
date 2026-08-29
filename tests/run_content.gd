extends SceneTree

const ContentRegistryTests := preload("res://tests/content/test_content_registry.gd")
const ContentSchemaRegistryTests := preload("res://tests/content/test_content_schema_registries.gd")
const SemanticRoleSchemaRegistryTests := preload("res://tests/content/test_semantic_role_schema_registry.gd")
const ContentValidationPipelineTests := preload("res://tests/content/test_content_validation_pipeline.gd")
const ArchetypeContractTests := preload("res://tests/content/test_archetype_contract.gd")
const ArchetypeRealizationTests := preload("res://tests/content/test_archetype_realization.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(ContentRegistryTests.run())
	failures.append_array(ContentSchemaRegistryTests.run())
	failures.append_array(SemanticRoleSchemaRegistryTests.run())
	failures.append_array(ContentValidationPipelineTests.run())
	failures.append_array(ArchetypeContractTests.run())
	failures.append_array(ArchetypeRealizationTests.run())
	if failures.is_empty():
		print("[VALIDATION] PASS content")
		print("  semantic content ids / deterministic registry / category-capability-role schemas / headless validation / archetype realization contracts passed")
		quit(0)
		return

	printerr("[VALIDATION] FAIL content — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
