extends RefCounted

const ContentId := preload("res://core/content/identity/content_id.gd")
const ContentDefinition := preload("res://core/content/registry/content_definition.gd")
const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const SchemaId := preload("res://core/content/schema/schema_id.gd")
const CategorySchema := preload("res://core/content/schema/category_schema.gd")
const CategorySchemaRegistry := preload("res://core/content/schema/category_schema_registry.gd")
const CapabilitySchema := preload("res://core/content/schema/capability_schema.gd")
const CapabilitySchemaRegistry := preload("res://core/content/schema/capability_schema_registry.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_schema_identity_separation(failures)
	_test_category_hierarchy_and_order_independence(failures)
	_test_category_failures(failures)
	_test_capability_composition_and_order_independence(failures)
	_test_capability_failures(failures)
	_test_content_definition_schema_declarations(failures)
	return failures


static func _test_schema_identity_separation(failures: Array[String]) -> void:
	if not SchemaId.is_valid_category("category.weapon.melee"):
		failures.append("SchemaId rejected a valid category id")
	if not SchemaId.is_valid_capability("capability.attack.melee"):
		failures.append("SchemaId rejected a valid capability id")

	var invalid_categories: Array[String] = [
		"category",
		"Category.weapon",
		"capability.weapon",
		"category.weapon-heavy",
		"sid1:category.weapon",
		"res://category/weapon.tres",
	]
	for schema_id in invalid_categories:
		if SchemaId.is_valid_category(schema_id):
			failures.append("SchemaId accepted invalid category identity: %s" % schema_id)

	var invalid_capabilities: Array[String] = [
		"capability",
		"Capability.attack",
		"category.attack",
		"capability.attack-heavy",
		"sid1:capability.attack",
	]
	for schema_id in invalid_capabilities:
		if SchemaId.is_valid_capability(schema_id):
			failures.append("SchemaId accepted invalid capability identity: %s" % schema_id)

	if ContentId.is_valid("category.weapon.melee"):
		failures.append("ContentId accepted reserved category schema namespace")
	if ContentId.is_valid("capability.attack.melee"):
		failures.append("ContentId accepted reserved capability schema namespace")
	if ContentId.is_valid_family("category") or ContentId.is_valid_family("capability"):
		failures.append("ContentId accepted a reserved schema namespace as an authored family")

	var schema_as_content = ContentDefinition.new()
	schema_as_content.configure("category.weapon.melee", "category")
	if schema_as_content.validate_definition().is_empty():
		failures.append("ContentDefinition accepted a schema id as ordinary authored content")

	if _category("category.weapon", [], 0).validate_schema().is_empty():
		failures.append("CategorySchema accepted schema revision 0")
	if _capability("capability.attack", [], 0).validate_schema().is_empty():
		failures.append("CapabilitySchema accepted schema revision 0")


static func _test_category_hierarchy_and_order_independence(failures: Array[String]) -> void:
	var schemas_a: Array = [
		_category("category.entity"),
		_category("category.equipment", ["category.entity"]),
		_category("category.weapon", ["category.equipment"]),
		_category("category.weapon.melee", ["category.weapon"]),
		_category("category.weapon.ranged", ["category.weapon"]),
	]
	var schemas_b: Array = [
		_category("category.weapon.ranged", ["category.weapon"]),
		_category("category.weapon.melee", ["category.weapon"]),
		_category("category.weapon", ["category.equipment"]),
		_category("category.equipment", ["category.entity"]),
		_category("category.entity"),
	]

	var registry_a = CategorySchemaRegistry.new()
	var diagnostics_a: Array[String] = registry_a.index_schemas(schemas_a)
	var registry_b = CategorySchemaRegistry.new()
	var diagnostics_b: Array[String] = registry_b.index_schemas(schemas_b)
	if not diagnostics_a.is_empty() or not diagnostics_b.is_empty():
		failures.append("CategorySchemaRegistry rejected valid hierarchy: %s / %s" % [diagnostics_a, diagnostics_b])
		return
	if registry_a.canonical_manifest() != registry_b.canonical_manifest():
		failures.append("CategorySchemaRegistry canonical manifest depends on registration order")

	var expanded: Array[String] = registry_a.expanded_categories(["category.weapon.melee"])
	var expected: Array[String] = [
		"category.entity",
		"category.equipment",
		"category.weapon",
		"category.weapon.melee",
	]
	if expanded != expected:
		failures.append("CategorySchemaRegistry returned wrong explicit ancestry closure: %s" % [expanded])
	if not registry_a.is_category_or_descendant("category.weapon.melee", "category.equipment"):
		failures.append("CategorySchemaRegistry failed transitive descendant query")
	if registry_a.is_category_or_descendant("category.weapon.melee", "category.weapon.ranged"):
		failures.append("CategorySchemaRegistry treated a sibling category as an ancestor")
	if not registry_a.matches_required_categories(
		["category.weapon.melee"],
		["category.entity", "category.weapon"],
		true
	):
		failures.append("CategorySchemaRegistry rejected valid all-of category eligibility")
	if registry_a.matches_required_categories(
		["category.weapon.melee"],
		["category.weapon.ranged"],
		true
	):
		failures.append("CategorySchemaRegistry accepted incompatible category eligibility")
	if not registry_a.matches_required_categories(
		["category.weapon.melee"],
		["category.weapon.ranged", "category.equipment"],
		false
	):
		failures.append("CategorySchemaRegistry rejected valid any-of category eligibility")
	if registry_a.matches_required_categories(
		["category.weapon.melee"],
		["category.unknown"],
		true
	):
		failures.append("CategorySchemaRegistry accepted unknown required category")


static func _test_category_failures(failures: Array[String]) -> void:
	var unknown_registry = CategorySchemaRegistry.new()
	var unknown_diagnostics: Array[String] = unknown_registry.index_schemas([
		_category("category.weapon", ["category.equipment"]),
	])
	if not _has_fragment(unknown_diagnostics, "unknown category parent reference"):
		failures.append("CategorySchemaRegistry did not report unknown ancestry reference clearly")

	var duplicate_parent = _category(
		"category.weapon",
		["category.entity", "category.entity"]
	)
	if not _has_fragment(duplicate_parent.validate_schema(), "duplicate category parent reference"):
		failures.append("CategorySchema did not reject duplicate parent references")

	var duplicate_a = _category("category.weapon", [], 1)
	var duplicate_b = _category("category.weapon", [], 2)
	var duplicate_registry_a = CategorySchemaRegistry.new()
	var duplicate_diagnostics_a: Array[String] = duplicate_registry_a.index_schemas([duplicate_a, duplicate_b])
	var duplicate_registry_b = CategorySchemaRegistry.new()
	var duplicate_diagnostics_b: Array[String] = duplicate_registry_b.index_schemas([duplicate_b, duplicate_a])
	if duplicate_diagnostics_a != duplicate_diagnostics_b:
		failures.append("CategorySchemaRegistry duplicate diagnostics depend on registration order")
	if not _has_fragment(duplicate_diagnostics_a, "duplicate category schema id"):
		failures.append("CategorySchemaRegistry did not reject duplicate schema ids clearly")
	if duplicate_registry_a.has_schema("category.weapon"):
		failures.append("CategorySchemaRegistry used first/last-wins behavior for duplicate schema id")

	var cycle_registry = CategorySchemaRegistry.new()
	var cycle_diagnostics: Array[String] = cycle_registry.index_schemas([
		_category("category.a", ["category.b"]),
		_category("category.b", ["category.c"]),
		_category("category.c", ["category.a"]),
	])
	if not _has_fragment(cycle_diagnostics, "category ancestry cycle"):
		failures.append("CategorySchemaRegistry did not reject ancestry cycle clearly")
	if cycle_registry.is_valid():
		failures.append("CategorySchemaRegistry reported cyclic hierarchy as valid")


static func _test_capability_composition_and_order_independence(failures: Array[String]) -> void:
	var schemas_a: Array = [
		_capability("capability.action"),
		_capability("capability.attack", ["capability.action"]),
		_capability("capability.attack.melee", ["capability.attack"]),
		_capability("capability.defense.block", ["capability.action"]),
		_capability(
			"capability.combat.basic",
			["capability.attack.melee", "capability.defense.block"]
		),
		_capability("capability.magic.fire"),
	]
	var schemas_b: Array = [
		_capability("capability.magic.fire"),
		_capability(
			"capability.combat.basic",
			["capability.defense.block", "capability.attack.melee"]
		),
		_capability("capability.defense.block", ["capability.action"]),
		_capability("capability.attack.melee", ["capability.attack"]),
		_capability("capability.attack", ["capability.action"]),
		_capability("capability.action"),
	]

	var registry_a = CapabilitySchemaRegistry.new()
	var diagnostics_a: Array[String] = registry_a.index_schemas(schemas_a)
	var registry_b = CapabilitySchemaRegistry.new()
	var diagnostics_b: Array[String] = registry_b.index_schemas(schemas_b)
	if not diagnostics_a.is_empty() or not diagnostics_b.is_empty():
		failures.append("CapabilitySchemaRegistry rejected valid composition: %s / %s" % [diagnostics_a, diagnostics_b])
		return
	if registry_a.canonical_manifest() != registry_b.canonical_manifest():
		failures.append("CapabilitySchemaRegistry canonical manifest depends on registration/composition order")

	var expanded: Array[String] = registry_a.expanded_capabilities(["capability.combat.basic"])
	var expected: Array[String] = [
		"capability.action",
		"capability.attack",
		"capability.attack.melee",
		"capability.combat.basic",
		"capability.defense.block",
	]
	if expanded != expected:
		failures.append("CapabilitySchemaRegistry returned wrong composition closure: %s" % [expanded])
	if not registry_a.provides_capability(["capability.combat.basic"], "capability.attack"):
		failures.append("CapabilitySchemaRegistry failed transitive provided-capability query")
	if not registry_a.matches_required_capabilities(
		["capability.combat.basic"],
		["capability.attack.melee", "capability.defense.block"],
		true
	):
		failures.append("CapabilitySchemaRegistry rejected valid all-of capability eligibility")
	if registry_a.provides_capability(["capability.magic.fire"], "capability.attack"):
		failures.append("CapabilitySchemaRegistry inferred capability hierarchy from semantic name")
	if registry_a.matches_required_capabilities(
		["capability.combat.basic"],
		["capability.unknown"],
		true
	):
		failures.append("CapabilitySchemaRegistry accepted unknown required capability")


static func _test_capability_failures(failures: Array[String]) -> void:
	var unknown_registry = CapabilitySchemaRegistry.new()
	var unknown_diagnostics: Array[String] = unknown_registry.index_schemas([
		_capability("capability.attack.melee", ["capability.attack"]),
	])
	if not _has_fragment(unknown_diagnostics, "unknown capability composition reference"):
		failures.append("CapabilitySchemaRegistry did not report unknown composition reference clearly")

	var duplicate_composition = _capability(
		"capability.combat.basic",
		["capability.action", "capability.action"]
	)
	if not _has_fragment(duplicate_composition.validate_schema(), "duplicate capability composition reference"):
		failures.append("CapabilitySchema did not reject duplicate composition references")

	var duplicate_a = _capability("capability.attack", [], 1)
	var duplicate_b = _capability("capability.attack", [], 2)
	var duplicate_registry_a = CapabilitySchemaRegistry.new()
	var duplicate_diagnostics_a: Array[String] = duplicate_registry_a.index_schemas([duplicate_a, duplicate_b])
	var duplicate_registry_b = CapabilitySchemaRegistry.new()
	var duplicate_diagnostics_b: Array[String] = duplicate_registry_b.index_schemas([duplicate_b, duplicate_a])
	if duplicate_diagnostics_a != duplicate_diagnostics_b:
		failures.append("CapabilitySchemaRegistry duplicate diagnostics depend on registration order")
	if not _has_fragment(duplicate_diagnostics_a, "duplicate capability schema id"):
		failures.append("CapabilitySchemaRegistry did not reject duplicate schema ids clearly")
	if duplicate_registry_a.has_schema("capability.attack"):
		failures.append("CapabilitySchemaRegistry used first/last-wins behavior for duplicate schema id")

	var cycle_registry = CapabilitySchemaRegistry.new()
	var cycle_diagnostics: Array[String] = cycle_registry.index_schemas([
		_capability("capability.a", ["capability.b"]),
		_capability("capability.b", ["capability.c"]),
		_capability("capability.c", ["capability.a"]),
	])
	if not _has_fragment(cycle_diagnostics, "capability composition cycle"):
		failures.append("CapabilitySchemaRegistry did not reject composition cycle clearly")
	if cycle_registry.is_valid():
		failures.append("CapabilitySchemaRegistry reported cyclic composition as valid")


static func _test_content_definition_schema_declarations(failures: Array[String]) -> void:
	var categories = CategorySchemaRegistry.new()
	var category_diagnostics: Array[String] = categories.index_schemas([
		_category("category.equipment"),
		_category("category.weapon", ["category.equipment"]),
		_category("category.weapon.melee", ["category.weapon"]),
	])
	var capabilities = CapabilitySchemaRegistry.new()
	var capability_diagnostics: Array[String] = capabilities.index_schemas([
		_capability("capability.action"),
		_capability("capability.attack", ["capability.action"]),
		_capability("capability.attack.melee", ["capability.attack"]),
	])
	if not category_diagnostics.is_empty() or not capability_diagnostics.is_empty():
		failures.append("schema declaration fixture registries are invalid")
		return

	var definition_a = ContentDefinition.new()
	definition_a.configure("item.weapon.iron_sword", "item", 2)
	definition_a.configure_schema_declarations(
		["category.weapon.melee", "category.weapon"],
		["capability.attack.melee", "capability.action"]
	)
	var definition_b = ContentDefinition.new()
	definition_b.configure("item.weapon.iron_sword", "item", 2)
	definition_b.configure_schema_declarations(
		["category.weapon", "category.weapon.melee"],
		["capability.action", "capability.attack.melee"]
	)
	if not definition_a.validate_definition().is_empty():
		failures.append("ContentDefinition rejected valid category/capability declarations")
	if definition_a.canonical_descriptor() != definition_b.canonical_descriptor():
		failures.append("ContentDefinition schema declaration descriptor depends on declaration order")

	var content_registry = ContentRegistry.new()
	var content_diagnostics: Array[String] = content_registry.index_definitions([definition_a])
	if not content_diagnostics.is_empty():
		failures.append("ContentRegistry rejected a definition carrying generic schema declarations: %s" % content_diagnostics)
		return
	var resolved = content_registry.get_definition("item.weapon.iron_sword")
	if resolved == null:
		failures.append("ContentRegistry lost a definition carrying schema declarations")
		return
	if not categories.matches_required_categories(resolved.category_ids, ["category.equipment"], true):
		failures.append("generic category eligibility could not consume ContentDefinition declarations")
	if not capabilities.matches_required_capabilities(resolved.capability_ids, ["capability.attack"], true):
		failures.append("generic capability eligibility could not consume ContentDefinition declarations")

	var invalid_definition = ContentDefinition.new()
	invalid_definition.configure("item.weapon.broken", "item")
	invalid_definition.configure_schema_declarations(
		["capability.attack"],
		["category.weapon"]
	)
	if invalid_definition.validate_definition().is_empty():
		failures.append("ContentDefinition accepted swapped category/capability namespaces")

	var duplicate_definition = ContentDefinition.new()
	duplicate_definition.configure("item.weapon.duplicate", "item")
	duplicate_definition.configure_schema_declarations(
		["category.weapon", "category.weapon"],
		["capability.attack", "capability.attack"]
	)
	var duplicate_failures: Array[String] = duplicate_definition.validate_definition()
	if not _has_fragment(duplicate_failures, "duplicate declared category schema id"):
		failures.append("ContentDefinition did not reject duplicate category declarations")
	if not _has_fragment(duplicate_failures, "duplicate declared capability schema id"):
		failures.append("ContentDefinition did not reject duplicate capability declarations")


static func _category(schema_id: String, parents: Array = [], revision: int = 1):
	var schema = CategorySchema.new()
	schema.configure(schema_id, parents, revision)
	return schema


static func _capability(schema_id: String, composed: Array = [], revision: int = 1):
	var schema = CapabilitySchema.new()
	schema.configure(schema_id, composed, revision)
	return schema


static func _has_fragment(diagnostics: Array, fragment: String) -> bool:
	for diagnostic in diagnostics:
		if str(diagnostic).contains(fragment):
			return true
	return false
