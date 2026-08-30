extends RefCounted

const ContentReference := preload("res://core/content/references/content_reference.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const WeaponDefinition := preload("res://gameplay/items/weapons/definitions/weapon_definition.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_equivalent_independent_definitions(failures)
	_test_canonical_ordering_equivalence(failures)
	_test_item_authored_drift_is_atomic(failures)
	_test_weapon_authored_drift_is_atomic(failures)
	_test_wrong_subtype_same_content_id_is_atomic(failures)
	_test_mutable_stack_state_is_not_authored_identity(failures)
	return failures


static func _test_equivalent_independent_definitions(failures: Array[String]) -> void:
	var item_id := "item.resource.identity_equivalent"
	var first = _item(item_id)
	var second = _item(item_id)
	var container = ItemContainerState.new().configure(3)
	_expect_success(failures, "equivalent setup", container.add_stack(first, 2))
	_expect_success(failures, "equivalent independent definition", container.add_stack(second, 1))
	if container.quantity_of(item_id) != 3:
		failures.append("equivalent independent definitions did not share authored identity")


static func _test_canonical_ordering_equivalence(failures: Array[String]) -> void:
	var item_id := "item.resource.identity_ordering"
	var first = _item(item_id)
	first.configure_schema_declarations(
		["category.item.identity.alpha", "category.item.identity.beta"],
		["capability.identity.alpha", "capability.identity.beta"]
	)
	first.configure_semantic_references([
		_ref(item_id, "identity.first", "item.resource.wood"),
		_ref(item_id, "identity.second", "item.resource.stone"),
	])
	var second = _item(item_id)
	second.configure_schema_declarations(
		["category.item.identity.beta", "category.item.identity.alpha"],
		["capability.identity.beta", "capability.identity.alpha"]
	)
	second.configure_semantic_references([
		_ref(item_id, "identity.second", "item.resource.stone"),
		_ref(item_id, "identity.first", "item.resource.wood"),
	])
	var container = ItemContainerState.new().configure(3)
	_expect_success(failures, "ordering setup", container.add_stack(first, 1))
	_expect_success(failures, "canonical ordering equivalent definition", container.add_stack(second, 1))
	if container.quantity_of(item_id) != 2:
		failures.append("canonical ordering equivalence did not preserve compatibility")


static func _test_item_authored_drift_is_atomic(failures: Array[String]) -> void:
	var item_id := "item.resource.identity_item_drift"
	var stored = _item(item_id)
	stored.configure_schema_declarations(
		["category.item.identity.alpha"],
		["capability.identity.alpha"]
	)
	stored.configure_semantic_references([
		_ref(item_id, "identity.material", "item.resource.wood"),
	])
	var container = ItemContainerState.new().configure(4)
	_expect_success(failures, "item drift setup", container.add_stack(stored, 2))

	var category_drift = _item(item_id)
	category_drift.configure_schema_declarations(
		["category.item.identity.beta"],
		["capability.identity.alpha"]
	)
	category_drift.configure_semantic_references([
		_ref(item_id, "identity.material", "item.resource.wood"),
	])
	_expect_atomic_mismatch(failures, "category drift", container, category_drift, true)

	var capability_drift = _item(item_id)
	capability_drift.configure_schema_declarations(
		["category.item.identity.alpha"],
		["capability.identity.beta"]
	)
	capability_drift.configure_semantic_references([
		_ref(item_id, "identity.material", "item.resource.wood"),
	])
	_expect_atomic_mismatch(failures, "capability drift", container, capability_drift, true)

	var reference_drift = _item(item_id)
	reference_drift.configure_schema_declarations(
		["category.item.identity.alpha"],
		["capability.identity.alpha"]
	)
	reference_drift.configure_semantic_references([
		_ref(item_id, "identity.material", "item.resource.stone"),
	])
	_expect_atomic_mismatch(failures, "semantic reference drift", container, reference_drift, true)


static func _test_weapon_authored_drift_is_atomic(failures: Array[String]) -> void:
	var item_id := "item.weapon.identity_weapon_drift"
	var stored = _weapon(item_id)
	var container = ItemContainerState.new().configure(8)
	_expect_success(failures, "weapon drift setup", container.add_instance(stored, {"durability": 90}))

	var attack_set_drift = _weapon(item_id)
	attack_set_drift.attack_set_id = "attack_set.identity.alternate"
	_expect_atomic_mismatch(failures, "weapon attack-set drift", container, attack_set_drift, false)

	var archetype_drift = _weapon(item_id)
	archetype_drift.archetype_id = "archetype.identity.alternate"
	_expect_atomic_mismatch(failures, "weapon archetype drift", container, archetype_drift, false)

	var technique_drift = _weapon(item_id)
	technique_drift.primary_technique_role = "weapon_technique.heavy.primary"
	_expect_atomic_mismatch(failures, "weapon technique-role drift", container, technique_drift, false)

	var animation_drift = _weapon(item_id)
	animation_drift.attack_animation_role = "animation_role.action.attack.heavy_01"
	_expect_atomic_mismatch(failures, "weapon animation-role drift", container, animation_drift, false)

	var grip_drift = _weapon(item_id)
	grip_drift.grip_rig_role = "rig_role.socket.hand.left"
	_expect_atomic_mismatch(failures, "weapon grip-role drift", container, grip_drift, false)


static func _test_wrong_subtype_same_content_id_is_atomic(failures: Array[String]) -> void:
	var item_id := "item.weapon.identity_subtype"
	var generic = ItemDefinition.new().configure_item(item_id, 1, 2.0, 1)
	var container = ItemContainerState.new().configure(3)
	_expect_success(failures, "wrong-subtype setup", container.add_instance(generic, {"durability": 50}))
	var weapon = _weapon(item_id)
	_expect_atomic_mismatch(failures, "generic ItemDefinition vs WeaponDefinition", container, weapon, false)


static func _test_mutable_stack_state_is_not_authored_identity(failures: Array[String]) -> void:
	var item_id := "item.resource.identity_mutable_state"
	var first = _item(item_id)
	var second = _item(item_id)
	var container = ItemContainerState.new().configure(4)
	_expect_success(failures, "mutable-state setup", container.add_stack(first, 1, {"grade": "dry"}))
	var result: Dictionary = container.add_stack(second, 1, {"grade": "wet"})
	_expect_success(failures, "mutable stack state stays outside authored identity", result)
	if container.quantity_of(item_id) != 2 or container.occupied_slot_count() != 2:
		failures.append("mutable stack-state compatibility was confused with authored-definition identity")


static func _item(content_id: String):
	return ItemDefinition.new().configure_item(content_id, 8, 0.25, 1)


static func _weapon(content_id: String):
	return WeaponDefinition.new().configure_weapon(
		content_id,
		"attack_set.identity.primary",
		"archetype.identity.primary",
		"weapon_technique.light.primary",
		"animation_role.action.attack.light_01",
		"rig_role.socket.hand.right",
		2.0,
		1
	)


static func _ref(source_id: String, role: String, target_id: String):
	return ContentReference.new(source_id, role, target_id, "item", true)


static func _expect_atomic_mismatch(
	failures: Array[String],
	label: String,
	container,
	definition,
	use_stack: bool
) -> void:
	var before: String = container.canonical_json()
	var result: Dictionary = (
		container.add_stack(definition, 1)
		if use_stack
		else container.add_instance(definition, {"durability": 1})
	)
	if bool(result.get("success", false)):
		failures.append("%s was accepted despite authored-definition drift" % label)
	elif not _result_has_fragment(result, "authored item definition mismatch"):
		failures.append("%s did not report authored-definition mismatch: %s" % [label, result.get("diagnostics", [])])
	elif not _result_has_fragment(result, str(definition.content_id)):
		failures.append("%s diagnostic omitted conflicting ContentId" % label)
	if container.canonical_json() != before:
		failures.append("%s mutated canonical inventory state on rejection" % label)


static func _expect_success(failures: Array[String], label: String, result: Dictionary) -> void:
	if not bool(result.get("success", false)):
		failures.append("%s failed: %s" % [label, result.get("diagnostics", [])])


static func _result_has_fragment(result: Dictionary, fragment: String) -> bool:
	for value in result.get("diagnostics", []):
		if str(value).contains(fragment):
			return true
	return false
