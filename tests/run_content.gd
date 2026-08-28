extends SceneTree

const ContentRegistryTests := preload("res://tests/content/test_content_registry.gd")
const ReservedSiteAssignmentTests := preload("res://tests/content/test_reserved_site_assignment.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(ContentRegistryTests.run())
	failures.append_array(ReservedSiteAssignmentTests.run())
	if failures.is_empty():
		print("[VALIDATION] PASS content")
		print("  semantic ids / registry / typed references / reserved-site assignment passed")
		quit(0)
		return

	printerr("[VALIDATION] FAIL content — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
