extends SceneTree

const GeneratorManifestMutationTests := preload(
	"res://tests/generator_manifest/test_generator_manifest_mutations.gd"
)


func _init() -> void:
	var failures: Array[String] = GeneratorManifestMutationTests.run()
	if failures.is_empty():
		print("[GENERATOR MANIFEST VALIDATION] PASS")
		print("  revision dictionary insertion order is canonical")
		print("  stage/profile/contract revision mutations change manifest identity")
		print("  invalid revisions and mutable-copy leakage are rejected")
		quit(0)
		return

	printerr("[GENERATOR MANIFEST VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
