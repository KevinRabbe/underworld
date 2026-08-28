extends RefCounted

const ContentId := preload("res://core/content/identity/content_id.gd")
const ContentDefinition := preload("res://core/content/registry/content_definition.gd")
const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const ContentReference := preload("res://core/content/references/content_reference.gd")

const ITEM_PATH_A := "res://tests/fixtures/content/path_a/iron_sword.tres"
const ITEM_PATH_B := "res://tests/fixtures/content/path_b/renamed_weapon_definition.tres"
const ATTACK_SET_PATH := "res://tests/fixtures/content/attack_set_basic.tres"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_content_id_contract(failures)
	_test_path_and_order_independence(failures)
	_test_duplicate_rejection_is_deterministic(failures)
	_test_incompatible_definition_rejection(failures)
	_test_typed_resolution_and_references(failures)
	_test_generic_family_extension(failures)
	return failures


static func _test_content_id_contract(failures: Array[String]) -> void:
	if not ContentId.is_valid("item.weapon.iron_sword"):
		failures.append("ContentId rejected a valid authored semantic id")
	if ContentId.family_of("item.weapon.iron_sword") != "item":
		failures.append("ContentId returned the wrong leading semantic family")

	var invalid_ids: Array[String] = [
		"Item.weapon.iron_sword",
		"item",
		"item..broken",
		"res://content/item.tres",
		"sid1:procedural-instance",
		"item.weapon.iron-sword",
	]
	for invalid_id in invalid_ids:
		if ContentId.is_valid(invalid_id):
			failures.append("ContentId accepted invalid identity: %s" % invalid_id)

	var family_mismatch = _definition("item.weapon.iron_sword", "creature")
	if family_mismatch.validate_definition().is_empty():
		failures.append("ContentDefinition accepted a family/id namespace mismatch")
	var invalid_revision = _definition("item.weapon.iron_sword", "item", 0)
	if invalid_revision.validate_definition().is_empty():
		failures.append("ContentDefinition accepted schema revision 0")


static func _test_path_and_order_independence(failures: Array[String]) -> void:
	var registry_a = ContentRegistry.new()
	var errors_a: Array[String] = registry_a.load_resource_paths([ITEM_PATH_A, ATTACK_SET_PATH])
	if not errors_a.is_empty():
		failures.append("ContentRegistry path-A load failed: %s" % errors_a)
		return

	var registry_b = ContentRegistry.new()
	var errors_b: Array[String] = registry_b.load_resource_paths([ATTACK_SET_PATH, ITEM_PATH_B])
	if not errors_b.is_empty():
		failures.append("ContentRegistry path-B/reordered load failed: %s" % errors_b)
		return

	if registry_a.canonical_manifest() != registry_b.canonical_manifest():
		failures.append("ContentRegistry manifest changed after physical path move/reordered loading")
	var expected_ids: Array[String] = ["attack_set.sword.basic", "item.weapon.iron_sword"]
	if registry_a.definition_ids() != expected_ids or registry_b.definition_ids() != expected_ids:
		failures.append("ContentRegistry logical ordering is not canonical by semantic id")

	var item_a = registry_a.get_definition("item.weapon.iron_sword")
	var item_b = registry_b.get_definition("item.weapon.iron_sword")
	if item_a == null or item_b == null:
		failures.append("ContentRegistry failed semantic lookup after path-independent loading")
	elif str(item_a.resource_path) == str(item_b.resource_path):
		failures.append("ContentRegistry path-independence fixture did not use distinct physical paths")


static func _test_duplicate_rejection_is_deterministic(failures: Array[String]) -> void:
	var first = _definition("item.resource.wood", "item", 1)
	var second = _definition("item.resource.wood", "item", 2)

	var registry_a = ContentRegistry.new()
	var diagnostics_a: Array[String] = registry_a.index_definitions([first, second])
	var registry_b = ContentRegistry.new()
	var diagnostics_b: Array[String] = registry_b.index_definitions([second, first])

	if diagnostics_a != diagnostics_b:
		failures.append("ContentRegistry duplicate diagnostics depend on registration order")
	if not _has_fragment(diagnostics_a, "duplicate semantic content id: item.resource.wood"):
		failures.append("ContentRegistry did not report duplicate semantic id clearly")
	if registry_a.has_definition("item.resource.wood") or registry_b.has_definition("item.resource.wood"):
		failures.append("ContentRegistry used first/last-wins behavior for duplicate semantic id")


static func _test_incompatible_definition_rejection(failures: Array[String]) -> void:
	var registry = ContentRegistry.new()
	var diagnostics: Array[String] = registry.index_definitions([Resource.new()])
	if diagnostics.is_empty():
		failures.append("ContentRegistry accepted an incompatible Resource type")
	if registry.definition_count() != 0:
		failures.append("ContentRegistry indexed an incompatible Resource type")


static func _test_typed_resolution_and_references(failures: Array[String]) -> void:
	var registry = ContentRegistry.new()
	var diagnostics: Array[String] = registry.index_definitions([
		_definition("item.weapon.iron_sword", "item", 3),
		_definition("attack_set.sword.basic", "attack_set", 2),
	])
	if not diagnostics.is_empty():
		failures.append("ContentRegistry typed-resolution fixture failed to index: %s" % diagnostics)
		return

	var item_lookup: Dictionary = registry.resolve("item.weapon.iron_sword", "item")
	if item_lookup.get("definition") == null or not item_lookup.get("diagnostics", []).is_empty():
		failures.append("ContentRegistry rejected a compatible typed lookup")

	var wrong_family: Dictionary = registry.resolve("item.weapon.iron_sword", "attack_set")
	if wrong_family.get("definition") != null or wrong_family.get("diagnostics", []).is_empty():
		failures.append("ContentRegistry accepted an incompatible typed lookup")

	var missing: Dictionary = registry.resolve("item.weapon.missing", "item")
	if missing.get("definition") != null or not _has_fragment(missing.get("diagnostics", []), "missing content definition"):
		failures.append("ContentRegistry missing-definition diagnostics are not explicit")

	var good_reference = ContentReference.new(
		"item.weapon.iron_sword",
		"attack_set",
		"attack_set.sword.basic",
		"attack_set",
		true
	)
	var resolved_reference: Dictionary = registry.resolve_reference(good_reference)
	if resolved_reference.get("definition") == null or not resolved_reference.get("diagnostics", []).is_empty():
		failures.append("ContentRegistry rejected a compatible typed content reference")

	var wrong_reference = ContentReference.new(
		"item.weapon.iron_sword",
		"attack_set",
		"attack_set.sword.basic",
		"item",
		true
	)
	var wrong_reference_result: Dictionary = registry.resolve_reference(wrong_reference)
	if wrong_reference_result.get("definition") != null or wrong_reference_result.get("diagnostics", []).is_empty():
		failures.append("ContentRegistry accepted a reference to an incompatible definition family")

	var optional_reference = ContentReference.new(
		"item.weapon.iron_sword",
		"optional.visual",
		"",
		"visual",
		false
	)
	var optional_result: Dictionary = registry.resolve_reference(optional_reference)
	if optional_result.get("definition") != null or not optional_result.get("diagnostics", []).is_empty():
		failures.append("ContentRegistry rejected an explicitly optional empty reference")


static func _test_generic_family_extension(failures: Array[String]) -> void:
	var registry = ContentRegistry.new()
	var diagnostics: Array[String] = registry.index_definitions([
		_definition("recipe.weapon.iron_sword", "recipe"),
		_definition("creature.underworld.burrower", "creature"),
	])
	if not diagnostics.is_empty():
		failures.append("ContentRegistry generic family extension failed: %s" % diagnostics)
		return
	var creature: Dictionary = registry.resolve("creature.underworld.burrower", "creature")
	if creature.get("definition") == null:
		failures.append("ContentRegistry requires a special-case branch for a generic content family")
	var creature_ids: Array[String] = registry.definition_ids_for_family("creature")
	if creature_ids != ["creature.underworld.burrower"]:
		failures.append("ContentRegistry generic family index returned wrong semantic ids")


static func _definition(content_id: String, family: String, revision: int = 1):
	var definition = ContentDefinition.new()
	definition.configure(content_id, family, revision)
	return definition


static func _has_fragment(diagnostics: Array, fragment: String) -> bool:
	for diagnostic in diagnostics:
		if str(diagnostic).contains(fragment):
			return true
	return false
