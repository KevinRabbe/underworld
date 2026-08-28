extends SceneTree

const ContentRegistryTests := preload("res://tests/content/test_content_registry.gd")
const ContentSchemaRegistryTests := preload("res://tests/content/test_content_schema_registries.gd")
const ContentValidationPipelineTests := preload("res://tests/content/test_content_validation_pipeline.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(ContentRegistryTests.run())
	failures.append_array(ContentSchemaRegistryTests.run())
	failures.append_array(ContentValidationPipelineTests.run())
	if failures.is_empty():
		print("[VALIDATION] PASS content")
		print("  semantic content ids / deterministic registry / category-capability schemas / headless validation pipeline passed")
		quit(0)
		return

	printerr("[VALIDATION] FAIL content — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
