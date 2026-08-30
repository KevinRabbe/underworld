extends RefCounted

const ContentDefinition := preload("res://core/content/registry/content_definition.gd")
const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const CategorySchema := preload("res://core/content/schema/category_schema.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchema := preload("res://core/content/schema/capability_schema.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ContentValidationPipeline := preload("res://core/content/validation/content_validation_pipeline.gd")
const ReferenceCyclePolicy := preload("res://core/content/validation/content_reference_cycle_policy.gd")
const MinRevisionFamilyValidator := preload("res://tests/content/fixtures/min_revision_family_validator.gd")

const ITEM_CATEGORY := "category.item"
const TEST_CAPABILITY := "capability.test"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_immutable_success_and_order(failures)
	_test_failure_has_no_authority(failures)
	_test_definition_and_schema_staleness(failures)
	_test_validator_and_policy_staleness(failures)
	return failures


static func _test_immutable_success_and_order(failures: Array[String]) -> void:
	var categories = _categories()
	var capabilities = _capabilities()
	var validator = MinRevisionFamilyValidator.new().configure_rule("item", "revision", 1)
	var alpha = _definition("item.test.alpha", 1)
	var beta = _definition("item.test.beta", 1)
	var first: Dictionary = ContentValidationPipeline.new().validate_all(
		[beta, alpha], categories, capabilities, [validator]
	)
	var second: Dictionary = ContentValidationPipeline.new().validate_all(
		[alpha, beta], categories, capabilities, [validator]
	)
	if not bool(first.get("success", false)) or not bool(second.get("success", false)):
		failures.append("CONTENT-006 ordering proof did not produce successful validation")
		return
	for key in ["success", "diagnostics", "validated_definition_ids", "evidence"]:
		if not first.has(key):
			failures.append("CONTENT-006 result lost compatibility/evidence key: %s" % key)

	var evidence = first.get("evidence", null)
	var second_evidence = second.get("evidence", null)
	if evidence == null or second_evidence == null:
		failures.append("CONTENT-006 successful validation omitted typed evidence")
		return
	if str(evidence.fingerprint()).is_empty():
		failures.append("CONTENT-006 successful evidence omitted snapshot fingerprint")
	if evidence.fingerprint() != second_evidence.fingerprint():
		failures.append("equivalent definition ordering changed validation evidence fingerprint")
	var expected_ids: Array[String] = ["item.test.alpha", "item.test.beta"]
	if evidence.validated_definition_ids() != expected_ids:
		failures.append("typed evidence did not expose exact canonical validated ContentIds")

	var registry = _registry([alpha, beta], failures)
	if registry == null:
		return
	if not evidence.verification_failures(registry, alpha.content_id).is_empty():
		failures.append("unchanged canonical snapshot did not verify against typed evidence")

	var ids_copy: Array[String] = evidence.validated_definition_ids()
	ids_copy.clear()
	var diagnostics_copy: Array = evidence.diagnostics()
	diagnostics_copy.append({"message": "caller mutation"})
	var snapshot_copy: Dictionary = evidence.snapshot_descriptor()
	snapshot_copy["definitions"] = []
	if evidence.validated_definition_ids() != expected_ids:
		failures.append("caller mutation changed evidence-owned validated ContentIds")
	if not evidence.diagnostics().is_empty():
		failures.append("caller mutation changed evidence-owned diagnostics")
	if evidence.snapshot_descriptor().get("definitions", []).is_empty():
		failures.append("caller mutation changed evidence-owned snapshot descriptor")


static func _test_failure_has_no_authority(failures: Array[String]) -> void:
	var categories = _categories()
	var capabilities = _capabilities()
	var validator = MinRevisionFamilyValidator.new().configure_rule("item", "revision", 2)
	var definition = _definition("item.test.old", 1)
	var result: Dictionary = ContentValidationPipeline.new().validate_all(
		[definition], categories, capabilities, [validator]
	)
	if bool(result.get("success", true)):
		failures.append("CONTENT-006 failure proof unexpectedly succeeded")
	var evidence = result.get("evidence", null)
	if evidence == null:
		failures.append("failed CONTENT-005 result omitted typed diagnostic evidence")
		return
	if evidence.succeeded():
		failures.append("failed validation evidence exposed success authority")
	if not evidence.validated_definition_ids().is_empty():
		failures.append("failed validation evidence exposed validated-ID authority")
	if not result.get("validated_definition_ids", []).is_empty():
		failures.append("failed compatibility result exposed validated-ID authority")
	var registry = _registry([definition], failures)
	if registry != null and evidence.verification_failures(registry, definition.content_id).is_empty():
		failures.append("failed validation evidence verified as usable runtime authority")


static func _test_definition_and_schema_staleness(failures: Array[String]) -> void:
	var categories = _categories()
	var capabilities = _capabilities()
	var validator = MinRevisionFamilyValidator.new().configure_rule("item", "revision", 1)
	var definition = _definition("item.test.mutable", 1)
	var result: Dictionary = ContentValidationPipeline.new().validate_all(
		[definition], categories, capabilities, [validator]
	)
	var evidence = result.get("evidence", null)
	var registry = _registry([definition], failures)
	if evidence == null or registry == null or not bool(result.get("success", false)):
		failures.append("definition-staleness setup failed")
		return
	definition.schema_revision = 2
	registry.index_definitions([definition])
	if evidence.verification_failures(registry, definition.content_id).is_empty():
		failures.append("canonical definition mutation under the same ContentId did not stale evidence")

	categories = _categories()
	capabilities = _capabilities()
	definition = _definition("item.test.category_schema", 1)
	result = ContentValidationPipeline.new().validate_all(
		[definition], categories, capabilities, [validator]
	)
	evidence = result.get("evidence", null)
	registry = _registry([definition], failures)
	categories.index_schemas([
		CategorySchema.new().configure(ITEM_CATEGORY),
		CategorySchema.new().configure("category.item.extra", [ITEM_CATEGORY]),
	])
	if evidence != null and registry != null and evidence.verification_failures(registry).is_empty():
		failures.append("category-schema manifest change did not stale validation evidence")

	categories = _categories()
	capabilities = _capabilities()
	definition = _definition("item.test.capability_schema", 1)
	result = ContentValidationPipeline.new().validate_all(
		[definition], categories, capabilities, [validator]
	)
	evidence = result.get("evidence", null)
	registry = _registry([definition], failures)
	capabilities.index_schemas([
		CapabilitySchema.new().configure(TEST_CAPABILITY),
		CapabilitySchema.new().configure("capability.test.extra", [TEST_CAPABILITY]),
	])
	if evidence != null and registry != null and evidence.verification_failures(registry).is_empty():
		failures.append("capability-schema manifest change did not stale validation evidence")


static func _test_validator_and_policy_staleness(failures: Array[String]) -> void:
	var categories = _categories()
	var capabilities = _capabilities()
	var validator = MinRevisionFamilyValidator.new().configure_rule("item", "revision", 1)
	var policy = ReferenceCyclePolicy.new().configure([])
	var definition = _definition("item.test.validator", 2)
	var result: Dictionary = ContentValidationPipeline.new().validate_all(
		[definition], categories, capabilities, [validator], policy
	)
	var evidence = result.get("evidence", null)
	var registry = _registry([definition], failures)
	if evidence == null or registry == null or not bool(result.get("success", false)):
		failures.append("validator-staleness setup failed")
		return
	validator.minimum_revision = 2
	validator.rule_label = "changed revision rule"
	if evidence.verification_failures(registry).is_empty():
		failures.append("family-validator configuration change did not stale evidence")

	validator.rule_label = "revision"
	var refreshed: Dictionary = ContentValidationPipeline.new().validate_all(
		[definition], categories, capabilities, [validator], policy
	)
	var policy_evidence = refreshed.get("evidence", null)
	policy.allowed_roles.append("peer")
	if policy_evidence != null and policy_evidence.verification_failures(registry).is_empty():
		failures.append("cycle-policy semantic change did not stale evidence")


static func _definition(content_id: String, revision: int):
	var definition = ContentDefinition.new()
	definition.configure(content_id, "item", revision)
	definition.configure_schema_declarations([ITEM_CATEGORY], [TEST_CAPABILITY])
	return definition


static func _categories():
	var registry = CategorySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CategorySchema.new().configure(ITEM_CATEGORY),
	])
	assert(diagnostics.is_empty())
	return registry


static func _capabilities():
	var registry = CapabilitySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CapabilitySchema.new().configure(TEST_CAPABILITY),
	])
	assert(diagnostics.is_empty())
	return registry


static func _registry(definitions: Array, failures: Array[String]):
	var registry = ContentRegistry.new()
	var diagnostics: Array[String] = registry.index_definitions(definitions)
	if not diagnostics.is_empty():
		failures.append("CONTENT-006 registry setup failed: %s" % [diagnostics])
		return null
	return registry
