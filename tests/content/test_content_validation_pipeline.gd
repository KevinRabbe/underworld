extends RefCounted

const ContentDefinition := preload("res://core/content/registry/content_definition.gd")
const ContentReference := preload("res://core/content/references/content_reference.gd")
const CategorySchema := preload("res://core/content/schema/category_schema.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchema := preload("res://core/content/schema/capability_schema.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")
const ContentValidationPipeline := preload("res://core/content/validation/content_validation_pipeline.gd")
const ReferenceCyclePolicy := preload("res://core/content/validation/content_reference_cycle_policy.gd")
const ReferenceContentDefinition := preload("res://tests/content/fixtures/reference_content_definition.gd")
const MinRevisionFamilyValidator := preload("res://tests/content/fixtures/min_revision_family_validator.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_valid_project_and_read_only_boundary(failures)
	_test_invalid_ids_and_schema_declarations(failures)
	_test_typed_reference_resolution(failures)
	_test_reference_cycle_policy(failures)
	_test_family_validator_extension(failures)
	_test_targeted_validation_and_order_independence(failures)
	return failures


static func _test_valid_project_and_read_only_boundary(failures: Array[String]) -> void:
	var categories = _categories()
	var capabilities = _capabilities()
	var item = _definition(
		"item.weapon.iron_sword",
		"item",
		2,
		["category.weapon.melee"],
		["capability.attack.melee"]
	)
	var enemy = _definition(
		"enemy.skeleton.basic",
		"enemy",
		1,
		["category.entity.enemy"],
		[]
	)
	var definitions: Array = [item, enemy]
	var before_definition_descriptors: Array = [
		item.canonical_descriptor().duplicate(true),
		enemy.canonical_descriptor().duplicate(true),
	]
	var before_category_manifest: Array = categories.canonical_manifest().duplicate(true)
	var before_capability_manifest: Array = capabilities.canonical_manifest().duplicate(true)

	var pipeline = ContentValidationPipeline.new()
	if pipeline is Node:
		failures.append("ContentValidationPipeline is a runtime Node instead of a headless authoring validator")
	var result: Dictionary = pipeline.validate_all(definitions, categories, capabilities)
	if not bool(result.get("success", false)):
		failures.append("ContentValidationPipeline rejected a valid authored project: %s" % [result.get("diagnostics", [])])
	var expected_ids: Array[String] = ["enemy.skeleton.basic", "item.weapon.iron_sword"]
	if result.get("validated_definition_ids", []) != expected_ids:
		failures.append("ContentValidationPipeline returned non-canonical validated ids: %s" % [result.get("validated_definition_ids", [])])

	if item.canonical_descriptor() != before_definition_descriptors[0]:
		failures.append("ContentValidationPipeline mutated the item definition while validating")
	if enemy.canonical_descriptor() != before_definition_descriptors[1]:
		failures.append("ContentValidationPipeline mutated the enemy definition while validating")
	if categories.canonical_manifest() != before_category_manifest:
		failures.append("ContentValidationPipeline mutated the category registry while validating")
	if capabilities.canonical_manifest() != before_capability_manifest:
		failures.append("ContentValidationPipeline mutated the capability registry while validating")


static func _test_invalid_ids_and_schema_declarations(failures: Array[String]) -> void:
	var categories = _categories()
	var capabilities = _capabilities()
	var invalid_id = ContentDefinition.new()
	invalid_id.configure("Item.Bad", "item")

	var unknown_schema = _definition(
		"item.tool.unknown_schema",
		"item",
		1,
		["category.tool.unknown"],
		["capability.tool.unknown"]
	)
	var result: Dictionary = ContentValidationPipeline.new().validate_all(
		[unknown_schema, invalid_id],
		categories,
		capabilities
	)
	if bool(result.get("success", true)):
		failures.append("ContentValidationPipeline accepted invalid authored ids/schema declarations")
	if not _has_code_fragment(result, "definition_invalid", "content id"):
		failures.append("ContentValidationPipeline did not route invalid ContentId diagnostics actionably")
	if not _has_code_fragment(result, "category_unknown", "unknown category schema id"):
		failures.append("ContentValidationPipeline did not report an unknown category declaration")
	if not _has_code_fragment(result, "capability_unknown", "unknown capability schema id"):
		failures.append("ContentValidationPipeline did not report an unknown capability declaration")


static func _test_typed_reference_resolution(failures: Array[String]) -> void:
	var categories = _categories()
	var capabilities = _capabilities()
	var enemy = _definition("enemy.skeleton.basic", "enemy")

	var source = ReferenceContentDefinition.new()
	source.configure("item.reference.source", "item")
	source.configure_references([
		ContentReference.new(
			"item.reference.source",
			"wrong_family",
			"enemy.skeleton.basic",
			"item",
			true
		),
		ContentReference.new(
			"item.reference.source",
			"missing_target",
			"item.reference.missing",
			"item",
			true
		),
	])

	var result: Dictionary = ContentValidationPipeline.new().validate_all(
		[enemy, source],
		categories,
		capabilities
	)
	if not _has_code_fragment(result, "reference_resolution", "expected 'item'"):
		failures.append("ContentValidationPipeline did not report wrong-family typed reference semantics")
	if not _has_code_fragment(result, "reference_resolution", "missing content definition"):
		failures.append("ContentValidationPipeline did not report a missing reference target")

	var bad_owner = ReferenceContentDefinition.new()
	bad_owner.configure("item.reference.owner", "item")
	bad_owner.configure_references([
		ContentReference.new(
			"item.reference.someone_else",
			"owner",
			"enemy.skeleton.basic",
			"enemy",
			true
		),
	])
	var owner_result: Dictionary = ContentValidationPipeline.new().validate_all(
		[enemy, bad_owner],
		categories,
		capabilities
	)
	if not _has_code_fragment(owner_result, "reference_invalid", "does not match owning definition"):
		failures.append("ContentValidationPipeline did not reject a reference with the wrong source owner")


static func _test_reference_cycle_policy(failures: Array[String]) -> void:
	var categories = _categories()
	var capabilities = _capabilities()
	var a = _reference_definition(
		"item.link.a",
		"item.link.b",
		"peer"
	)
	var b = _reference_definition(
		"item.link.b",
		"item.link.a",
		"peer"
	)
	var definitions: Array = [a, b]

	var denied: Dictionary = ContentValidationPipeline.new().validate_all(
		definitions,
		categories,
		capabilities
	)
	if not _has_code_fragment(denied, "reference_cycle", "disallowed reference cycle"):
		failures.append("ContentValidationPipeline did not default-deny an authored reference cycle")
	if _count_code(denied, "reference_cycle") != 2:
		failures.append("ContentValidationPipeline did not route a denied cycle deterministically to both owning definitions")

	var policy = ReferenceCyclePolicy.new()
	policy.configure(["peer"])
	var allowed: Dictionary = ContentValidationPipeline.new().validate_all(
		definitions,
		categories,
		capabilities,
		[],
		policy
	)
	if not bool(allowed.get("success", false)):
		failures.append("ContentValidationPipeline rejected an explicitly allowed reference cycle: %s" % [allowed.get("diagnostics", [])])


static func _test_family_validator_extension(failures: Array[String]) -> void:
	var categories = _categories()
	var capabilities = _capabilities()
	var item_old = _definition("item.tool.old", "item", 1)
	var item_new = _definition("item.tool.new", "item", 2)
	var enemy = _definition("enemy.skeleton.basic", "enemy", 1)
	var validator = MinRevisionFamilyValidator.new()
	validator.configure_rule("item", "item rulebook", 2)

	var result: Dictionary = ContentValidationPipeline.new().validate_all(
		[item_new, enemy, item_old],
		categories,
		capabilities,
		[validator]
	)
	if _count_code(result, "family_rule") != 1:
		failures.append("family validator extension did not apply exactly to the matching invalid family member: %s" % [result.get("diagnostics", [])])
	if not _has_source_code(result, "item.tool.old", "family_rule"):
		failures.append("family validator diagnostic was not attributed to its matching definition")
	if _has_source_code(result, "enemy.skeleton.basic", "family_rule"):
		failures.append("family validator leaked into an unrelated content family")

	var reverse_result: Dictionary = ContentValidationPipeline.new().validate_all(
		[item_old, enemy, item_new],
		categories,
		capabilities,
		[validator]
	)
	if result.get("diagnostics", []) != reverse_result.get("diagnostics", []):
		failures.append("family validation diagnostics depend on definition discovery order")


static func _test_targeted_validation_and_order_independence(failures: Array[String]) -> void:
	var categories = _categories()
	var capabilities = _capabilities()
	var validator = MinRevisionFamilyValidator.new()
	validator.configure_rule("item", "item rulebook", 2)

	var item_bad = _definition(
		"item.tool.bad",
		"item",
		1,
		["category.tool.unknown"],
		[]
	)
	var item_good = _definition("item.tool.good", "item", 2)
	var enemy = _definition("enemy.skeleton.basic", "enemy", 1)
	var definitions_a: Array = [item_good, enemy, item_bad]
	var definitions_b: Array = [item_bad, item_good, enemy]
	var pipeline = ContentValidationPipeline.new()

	var full_a: Dictionary = pipeline.validate_all(
		definitions_a,
		categories,
		capabilities,
		[validator]
	)
	var full_b: Dictionary = pipeline.validate_all(
		definitions_b,
		categories,
		capabilities,
		[validator]
	)
	if full_a.get("diagnostics", []) != full_b.get("diagnostics", []):
		failures.append("complete validation diagnostics depend on discovery order")

	var targeted: Dictionary = pipeline.validate_ids(
		definitions_b,
		["item.tool.bad"],
		categories,
		capabilities,
		[validator]
	)
	var projected: Array = _diagnostics_for_source(full_a, "item.tool.bad")
	if targeted.get("diagnostics", []) != projected:
		failures.append("targeted validation disagrees with complete validation for the same definition: %s vs %s" % [targeted.get("diagnostics", []), projected])
	if targeted.get("validated_definition_ids", []) != ["item.tool.bad"]:
		failures.append("targeted validation returned unexpected definition ids: %s" % [targeted.get("validated_definition_ids", [])])

	var family_result: Dictionary = pipeline.validate_family(
		definitions_a,
		"item",
		categories,
		capabilities,
		[validator]
	)
	var full_item_diagnostics: Array = _diagnostics_for_family_sources(
		full_a,
		["item.tool.bad", "item.tool.good"]
	)
	if family_result.get("diagnostics", []) != full_item_diagnostics:
		failures.append("family-targeted validation disagrees with complete validation projection")
	var expected_item_ids: Array[String] = ["item.tool.bad", "item.tool.good"]
	if family_result.get("validated_definition_ids", []) != expected_item_ids:
		failures.append("family-targeted validation returned non-canonical ids: %s" % [family_result.get("validated_definition_ids", [])])

	var missing_target: Dictionary = pipeline.validate_ids(
		definitions_a,
		["item.tool.not_present"],
		categories,
		capabilities,
		[validator]
	)
	if not _has_code_fragment(missing_target, "target_missing", "not present"):
		failures.append("targeted validation did not report a missing requested definition")


static func _categories():
	var registry = CategorySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CategorySchema.new().configure("category.entity"),
		CategorySchema.new().configure("category.entity.enemy", ["category.entity"]),
		CategorySchema.new().configure("category.equipment", ["category.entity"]),
		CategorySchema.new().configure("category.weapon", ["category.equipment"]),
		CategorySchema.new().configure("category.weapon.melee", ["category.weapon"]),
	])
	assert(diagnostics.is_empty())
	return registry


static func _capabilities():
	var registry = CapabilitySchemaRegistry.new()
	var diagnostics: Array[String] = registry.index_schemas([
		CapabilitySchema.new().configure("capability.action"),
		CapabilitySchema.new().configure("capability.attack", ["capability.action"]),
		CapabilitySchema.new().configure("capability.attack.melee", ["capability.attack"]),
	])
	assert(diagnostics.is_empty())
	return registry


static func _definition(
	content_id: String,
	family: String,
	revision: int = 1,
	categories: Array = [],
	capabilities: Array = []
):
	var definition = ContentDefinition.new()
	definition.configure(content_id, family, revision)
	definition.configure_schema_declarations(categories, capabilities)
	return definition


static func _reference_definition(
	content_id: String,
	target_id: String,
	role: String
):
	var definition = ReferenceContentDefinition.new()
	definition.configure(content_id, "item", 1)
	definition.configure_references([
		ContentReference.new(content_id, role, target_id, "item", true),
	])
	return definition


static func _has_code_fragment(result: Dictionary, code: String, fragment: String) -> bool:
	for diagnostic in result.get("diagnostics", []):
		if str(diagnostic.get("code", "")) == code and str(diagnostic.get("message", "")).contains(fragment):
			return true
	return false


static func _has_source_code(result: Dictionary, source_id: String, code: String) -> bool:
	for diagnostic in result.get("diagnostics", []):
		if str(diagnostic.get("source_id", "")) == source_id and str(diagnostic.get("code", "")) == code:
			return true
	return false


static func _count_code(result: Dictionary, code: String) -> int:
	var count: int = 0
	for diagnostic in result.get("diagnostics", []):
		if str(diagnostic.get("code", "")) == code:
			count += 1
	return count


static func _diagnostics_for_source(result: Dictionary, source_id: String) -> Array:
	var selected: Array = []
	for diagnostic in result.get("diagnostics", []):
		if str(diagnostic.get("source_id", "")) == source_id:
			selected.append(diagnostic)
	return selected


static func _diagnostics_for_family_sources(result: Dictionary, source_ids: Array) -> Array:
	var selected: Array = []
	for diagnostic in result.get("diagnostics", []):
		if source_ids.has(str(diagnostic.get("source_id", ""))):
			selected.append(diagnostic)
	return selected
