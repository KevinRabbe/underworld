extends SceneTree

const GeneratorManifestMutationTests := preload(
	"res://tests/generator_manifest/test_generator_manifest_mutations.gd"
)
const RootIdentityPackageTests := preload(
	"res://tests/generator_manifest/test_root_identity_package.gd"
)


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(GeneratorManifestMutationTests.run())
	failures.append_array(RootIdentityPackageTests.run())
	if failures.is_empty():
		print("[GENERATOR MANIFEST VALIDATION] PASS")
		print("  revision dictionary insertion order is canonical")
		print("  snapshot-backed manifest identity is immutable and alias-safe")
		print("  root identity package round-trips exact gm1/wid1 identity")
		print("  structural validation is separated from runtime compatibility")
		print("  exact historical WorldId and manifest identity never rewrite on incompatibility")
		quit(0)
		return

	printerr("[GENERATOR MANIFEST VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
