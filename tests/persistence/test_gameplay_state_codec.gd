extends RefCounted

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const ContentDefinition := preload("res://core/content/registry/content_definition.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const EquipmentSlotRule := preload("res://gameplay/items/equipment/equipment_slot_rule.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const EquipmentService := preload("res://gameplay/items/equipment/equipment_service.gd")
const InventoryStateCodec := preload("res://gameplay/items/inventory/inventory_state_codec.gd")
const LootProfileDefinition := preload("res://gameplay/loot/definitions/loot_profile_definition.gd")
const PendingLootState := preload("res://gameplay/loot/runtime/pending_loot_state.gd")
const GameplayStateCodec := preload("res://gameplay/persistence/gameplay_state_codec.gd")

const EQUIPMENT_ROOT := "category.item.equipment"
const EQUIPABLE := "capability.equipable"
const MAGIC_ONLY := "capability.magic_only"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_inventory_exact_slot_and_mutable_state_round_trip(failures)
	_test_inventory_malformed_records_fail_closed(failures)
	_test_inventory_structural_and_non_finite_fail_closed(failures)
	_test_inventory_missing_and_drifted_definition_fail_closed(failures)
	_test_equipment_round_trip_uses_current_authored_rules(failures)
	_test_equipment_incompatible_current_rule_fails_closed(failures)
	_test_equipment_selected_binding_compatibility(failures)
	_test_pending_and_consumed_loot_round_trip(failures)
	_test_malformed_pending_reward_never_reconstructs(failures)
	_test_pending_loot_structural_keys_fail_closed(failures)
	_test_canonical_evidence_is_order_independent(failures)
	return failures


static func _test_inventory_exact_slot_and_mutable_state_round_trip(
	failures: Array[String]
) -> void:
	var authored = _definitions()
	var registry = _registry(authored.values())
	var inventory = _inventory_with_gap(authored)
	var original_json: String = inventory.canonical_json()

	var encoded: Dictionary = GameplayStateCodec.encode_inventory(inventory, registry)
	if not _require_success(encoded, "inventory encode", failures):
		return
	var snapshot: Dictionary = encoded.get("snapshot", {})
	var slots: Array = snapshot.get("slots", [])
	if slots.size() != 2:
		failures.append("inventory persistence snapshot did not retain exactly two occupied slots")
		return
	if int(slots[0].get("slot", -1)) != 0 or int(slots[1].get("slot", -1)) != 3:
		failures.append("inventory persistence snapshot lost exact occupied slot indexes")
	if str(slots[0].get("definition_contract", "")).is_empty():
		failures.append("inventory persistence snapshot omitted authored definition contract")

	var fresh_authored = _definitions()
	var fresh_registry = _registry(fresh_authored.values())
	var decoded: Dictionary = GameplayStateCodec.decode_inventory(snapshot, fresh_registry)
	if not _require_success(decoded, "inventory decode", failures):
		return
	var restored = decoded.get("state", null)
	if restored == null or restored.canonical_json() != original_json:
		failures.append("inventory exact-slot round-trip changed canonical container state")
		return
	var instance_state: Dictionary = restored.state_at(0).get("state", {}).get("per_copy_state", {})
	if int(instance_state.get("durability", 0)) != 73:
		failures.append("inventory round-trip lost per-copy mutable state")
	var stack_record: Dictionary = restored.state_at(3).get("state", {})
	if int(stack_record.get("quantity", 0)) != 4:
		failures.append("inventory round-trip lost stack quantity")
	var stack_state: Dictionary = stack_record.get("stack_state", {})
	if str(stack_state.get("grade", "")) != "rich" or int(stack_state.get("seed", 0)) != 4:
		failures.append("inventory round-trip lost stack mutable state")


static func _test_inventory_malformed_records_fail_closed(failures: Array[String]) -> void:
	var authored = _definitions()
	var registry = _registry(authored.values())
	var live = _inventory_with_gap(authored)
	var live_before: String = live.canonical_json()
	var encoded: Dictionary = GameplayStateCodec.encode_inventory(live, registry)
	if not bool(encoded.get("success", false)):
		failures.append("malformed inventory regression setup failed")
		return

	var duplicate_snapshot: Dictionary = encoded.get("snapshot", {}).duplicate(true)
	duplicate_snapshot["slots"].append(duplicate_snapshot["slots"][0].duplicate(true))
	var duplicate_result: Dictionary = GameplayStateCodec.decode_inventory(duplicate_snapshot, registry)
	if bool(duplicate_result.get("success", false)):
		failures.append("duplicate saved inventory slot unexpectedly reconstructed")
	if duplicate_result.has("state"):
		failures.append("failed duplicate-slot decode exposed partially reconstructed inventory")

	var range_snapshot: Dictionary = encoded.get("snapshot", {}).duplicate(true)
	range_snapshot["slots"][0]["slot"] = 99
	var range_result: Dictionary = GameplayStateCodec.decode_inventory(range_snapshot, registry)
	if bool(range_result.get("success", false)):
		failures.append("out-of-range saved inventory slot unexpectedly reconstructed")
	if live.canonical_json() != live_before:
		failures.append("failed inventory decode mutated supplied live inventory state")

	var schema_snapshot: Dictionary = encoded.get("snapshot", {}).duplicate(true)
	schema_snapshot["schema"] = "persistence.inventory.v999"
	if bool(GameplayStateCodec.decode_inventory(schema_snapshot, registry).get("success", false)):
		failures.append("unknown inventory persistence schema unexpectedly decoded")


static func _test_inventory_structural_and_non_finite_fail_closed(
	failures: Array[String]
) -> void:
	var authored = _definitions()
	var registry = _registry(authored.values())
	var encoded: Dictionary = GameplayStateCodec.encode_inventory(
		_inventory_with_gap(authored),
		registry
	)
	if not bool(encoded.get("success", false)):
		failures.append("strict inventory schema regression setup failed")
		return
	var snapshot: Dictionary = encoded.get("snapshot", {})

	var unknown_root: Dictionary = snapshot.duplicate(true)
	unknown_root["future_field"] = true
	if bool(GameplayStateCodec.decode_inventory(unknown_root, registry).get("success", false)):
		failures.append("unknown inventory root field did not fail closed")

	var unknown_record: Dictionary = snapshot.duplicate(true)
	unknown_record["slots"][0]["future_field"] = true
	if bool(GameplayStateCodec.decode_inventory(unknown_record, registry).get("success", false)):
		failures.append("unknown inventory occupied-record field did not fail closed")

	var nan_copy: Dictionary = snapshot.duplicate(true)
	nan_copy["slots"][0]["state"]["per_copy_state"]["temperature"] = NAN
	var nan_result: Dictionary = GameplayStateCodec.decode_inventory(nan_copy, registry)
	if bool(nan_result.get("success", false)):
		failures.append("NaN per-copy durable state unexpectedly decoded")
	if nan_result.has("state"):
		failures.append("NaN durable-state failure exposed partial inventory")

	var infinite_stack: Dictionary = snapshot.duplicate(true)
	infinite_stack["slots"][1]["state"]["stack_state"]["quality"] = INF
	if bool(GameplayStateCodec.decode_inventory(infinite_stack, registry).get("success", false)):
		failures.append("infinite stack durable state unexpectedly decoded")

	var infinite_weight: Dictionary = snapshot.duplicate(true)
	infinite_weight["max_weight"] = INF
	if bool(GameplayStateCodec.decode_inventory(infinite_weight, registry).get("success", false)):
		failures.append("infinite max_weight unexpectedly decoded")

	var unsafe_inventory = ItemContainerState.new().configure(1, 20.0)
	var unsafe_add: Dictionary = unsafe_inventory.add_instance(
		authored["tool"],
		{"temperature": NAN}
	)
	if not bool(unsafe_add.get("success", false)):
		failures.append("non-finite encode regression setup could not create runtime state")
	elif bool(GameplayStateCodec.encode_inventory(unsafe_inventory, registry).get("success", false)):
		failures.append("NaN runtime state unexpectedly produced durable inventory evidence")


static func _test_inventory_missing_and_drifted_definition_fail_closed(
	failures: Array[String]
) -> void:
	var authored = _definitions()
	var source_registry = _registry(authored.values())
	var inventory = _inventory_with_gap(authored)
	var encoded: Dictionary = GameplayStateCodec.encode_inventory(inventory, source_registry)
	if not bool(encoded.get("success", false)):
		failures.append("definition-drift regression setup failed")
		return
	var snapshot: Dictionary = encoded.get("snapshot", {})

	var missing_authored = _definitions()
	var missing_values: Array = [
		missing_authored["tool"],
		missing_authored["filler_a"],
		missing_authored["filler_b"],
		missing_authored["profile"],
	]
	var missing_result: Dictionary = GameplayStateCodec.decode_inventory(
		snapshot,
		_registry(missing_values)
	)
	if bool(missing_result.get("success", false)):
		failures.append("missing saved ItemDefinition did not fail closed")

	var drifted = _definitions()
	drifted["ore"].stack_limit = 20
	var drift_result: Dictionary = GameplayStateCodec.decode_inventory(
		snapshot,
		_registry(drifted.values())
	)
	if bool(drift_result.get("success", false)):
		failures.append("drifted saved ItemDefinition contract did not fail closed")

	var wrong_subtype = ContentDefinition.new().configure("item.persistence_ore", "item", 1)
	var wrong_values: Array = [
		drifted["tool"],
		drifted["filler_a"],
		drifted["filler_b"],
		drifted["profile"],
		wrong_subtype,
	]
	var subtype_result: Dictionary = GameplayStateCodec.decode_inventory(
		snapshot,
		_registry(wrong_values)
	)
	if bool(subtype_result.get("success", false)):
		failures.append("generic ContentDefinition masquerading as saved ItemDefinition did not fail closed")


static func _test_equipment_round_trip_uses_current_authored_rules(
	failures: Array[String]
) -> void:
	var authored = _definitions()
	var registry = _registry(authored.values())
	var rules_and_bindings: Dictionary = _equipment_config([EQUIPABLE])
	var equipment = EquipmentHotbarState.new().configure(
		rules_and_bindings["rules"],
		rules_and_bindings["bindings"]
	)
	var source_inventory = ItemContainerState.new().configure(2, 20.0)
	source_inventory.add_instance(authored["tool"], {"durability": 61})
	var equip_result: Dictionary = EquipmentService.new().equip_from_inventory(
		equipment,
		source_inventory,
		0,
		authored["tool"],
		"equipment_slot.hotbar.2"
	)
	if not bool(equip_result.get("success", false)):
		failures.append("equipment persistence regression setup failed")
		return
	equipment.select_hotbar(2)

	var encoded: Dictionary = GameplayStateCodec.encode_equipment(equipment, registry)
	if not _require_success(encoded, "equipment encode", failures):
		return
	var snapshot: Dictionary = encoded.get("snapshot", {})
	if snapshot.has("hotbar_bindings"):
		failures.append("equipment persistence snapshot captured authored hotbar configuration")
	if str(snapshot.get("selected_slot_key", "")) != "equipment_slot.hotbar.2":
		failures.append("equipment snapshot omitted selected-slot compatibility evidence")
	var saved_slots: Array = snapshot.get("slots", [])
	if saved_slots.size() != 1:
		failures.append("equipment persistence snapshot did not retain exactly one occupied slot")
		return
	if saved_slots[0].has("rule"):
		failures.append("equipment persistence snapshot captured authored slot rule as mutable state")

	var fresh_authored = _definitions()
	var fresh_registry = _registry(fresh_authored.values())
	var current_config: Dictionary = _equipment_config([EQUIPABLE])
	var decoded: Dictionary = GameplayStateCodec.decode_equipment(
		snapshot,
		fresh_registry,
		current_config["rules"],
		current_config["bindings"]
	)
	if not _require_success(decoded, "equipment decode", failures):
		return
	var restored = decoded.get("state", null)
	if restored == null:
		failures.append("equipment decode returned no detached state")
		return
	if restored.selected_hotbar() != 2:
		failures.append("equipment round-trip lost selected hotbar")
	if restored.selected_slot_key() != "equipment_slot.hotbar.2":
		failures.append("equipment round-trip changed selected semantic slot")
	var restored_state: Dictionary = restored.state_at("equipment_slot.hotbar.2")
	if str(restored_state.get("state", {}).get("item_id", "")) != "item.persistence_tool":
		failures.append("equipment round-trip lost semantic equipped item identity")
	if int(restored_state.get("state", {}).get("per_copy_state", {}).get("durability", 0)) != 61:
		failures.append("equipment round-trip lost per-copy equipped state")

	var tampered: Dictionary = snapshot.duplicate(true)
	tampered["slots"][0]["rule"] = {
		"slot_key": "equipment_slot.hotbar.2",
		"required_capabilities": [],
	}
	var tampered_result: Dictionary = GameplayStateCodec.decode_equipment(
		tampered,
		fresh_registry,
		current_config["rules"],
		current_config["bindings"]
	)
	if bool(tampered_result.get("success", false)):
		failures.append("injected saved equipment rule unexpectedly bypassed strict schema")
	if tampered_result.has("state"):
		failures.append("unknown equipment structural field exposed partial state")


static func _test_equipment_incompatible_current_rule_fails_closed(
	failures: Array[String]
) -> void:
	var authored = _definitions()
	var registry = _registry(authored.values())
	var source_config: Dictionary = _equipment_config([EQUIPABLE])
	var equipment = EquipmentHotbarState.new().configure(
		source_config["rules"],
		source_config["bindings"]
	)
	var inventory = ItemContainerState.new().configure(1, 20.0)
	inventory.add_instance(authored["tool"], {"durability": 55})
	EquipmentService.new().equip_from_inventory(
		equipment,
		inventory,
		0,
		authored["tool"],
		"equipment_slot.hotbar.1"
	)
	var encoded: Dictionary = GameplayStateCodec.encode_equipment(equipment, registry)
	if not bool(encoded.get("success", false)):
		failures.append("incompatible-rule regression setup failed")
		return

	var restrictive: Dictionary = _equipment_config([EQUIPABLE, MAGIC_ONLY])
	var decoded: Dictionary = GameplayStateCodec.decode_equipment(
		encoded.get("snapshot", {}),
		registry,
		restrictive["rules"],
		restrictive["bindings"]
	)
	if bool(decoded.get("success", false)):
		failures.append("saved equipped item bypassed incompatible current authored slot rule")
	if decoded.has("state"):
		failures.append("failed equipment reconstruction exposed partially restored state")


static func _test_equipment_selected_binding_compatibility(failures: Array[String]) -> void:
	var authored = _definitions()
	var registry = _registry(authored.values())
	var source_config: Dictionary = _equipment_config([EQUIPABLE])
	var equipment = EquipmentHotbarState.new().configure(
		source_config["rules"],
		source_config["bindings"]
	)
	equipment.select_hotbar(2)
	var encoded: Dictionary = GameplayStateCodec.encode_equipment(equipment, registry)
	if not bool(encoded.get("success", false)):
		failures.append("selected-binding regression setup failed")
		return
	var snapshot: Dictionary = encoded.get("snapshot", {})

	var missing_config: Dictionary = _equipment_config([EQUIPABLE])
	missing_config["bindings"].erase(2)
	var missing_result: Dictionary = GameplayStateCodec.decode_equipment(
		snapshot,
		registry,
		missing_config["rules"],
		missing_config["bindings"]
	)
	if bool(missing_result.get("success", false)):
		failures.append("missing current selected-hotbar binding silently decoded as hands")
	if missing_result.has("state"):
		failures.append("missing selected binding exposed partial equipment state")

	var changed_config: Dictionary = _equipment_config([EQUIPABLE])
	changed_config["bindings"][2] = "equipment_slot.hotbar.3"
	var changed_result: Dictionary = GameplayStateCodec.decode_equipment(
		snapshot,
		registry,
		changed_config["rules"],
		changed_config["bindings"]
	)
	if bool(changed_result.get("success", false)):
		failures.append("changed current selected-hotbar binding reinterpreted saved selection")
	if changed_result.has("state"):
		failures.append("changed selected binding exposed partial equipment state")


static func _test_pending_and_consumed_loot_round_trip(failures: Array[String]) -> void:
	var authored = _definitions()
	var registry = _registry(authored.values())
	var contract: String = InventoryStateCodec.canonical_json(authored["ore"].canonical_descriptor())
	var pending = PendingLootState.new().configure(
		"occurrence.persistence.001",
		"loot_profile.persistence_test",
		[{
			"item_id": "item.persistence_ore",
			"quantity": 3,
			"definition_contract": contract,
		}]
	)

	var pending_encoded: Dictionary = GameplayStateCodec.encode_pending_loot(pending, registry)
	if not _require_success(pending_encoded, "pending loot encode", failures):
		return
	var pending_decoded: Dictionary = GameplayStateCodec.decode_pending_loot(
		pending_encoded.get("snapshot", {}),
		_registry(_definitions().values())
	)
	if not _require_success(pending_decoded, "pending loot decode", failures):
		return
	var restored_pending = pending_decoded.get("state", null)
	if restored_pending == null or not restored_pending.is_pending():
		failures.append("unresolved pending loot did not reconstruct as pending")
	elif restored_pending.canonical_snapshot()["rewards"] != pending.canonical_snapshot()["rewards"]:
		failures.append("pending loot round-trip changed semantic rewards")

	if not pending.consume_after_commit():
		failures.append("consumed-loot regression setup could not consume pending state")
		return
	var consumed_encoded: Dictionary = GameplayStateCodec.encode_pending_loot(pending, registry)
	if not _require_success(consumed_encoded, "consumed loot encode", failures):
		return
	var consumed_decoded: Dictionary = GameplayStateCodec.decode_pending_loot(
		consumed_encoded.get("snapshot", {}),
		registry
	)
	if not _require_success(consumed_decoded, "consumed loot decode", failures):
		return
	var restored_consumed = consumed_decoded.get("state", null)
	if restored_consumed == null or restored_consumed.is_pending():
		failures.append("consumed pending-loot state reconstructed as collectible")
	elif restored_consumed.consume_after_commit():
		failures.append("consumed pending-loot state became collectible twice")


static func _test_malformed_pending_reward_never_reconstructs(
	failures: Array[String]
) -> void:
	var authored = _definitions()
	var registry = _registry(authored.values())
	var contract: String = InventoryStateCodec.canonical_json(authored["ore"].canonical_descriptor())
	var pending = PendingLootState.new().configure(
		"occurrence.persistence.002",
		"loot_profile.persistence_test",
		[{
			"item_id": "item.persistence_ore",
			"quantity": 2,
			"definition_contract": contract,
		}]
	)
	var encoded: Dictionary = GameplayStateCodec.encode_pending_loot(pending, registry)
	if not bool(encoded.get("success", false)):
		failures.append("malformed pending-loot regression setup failed")
		return
	var malformed: Dictionary = encoded.get("snapshot", {}).duplicate(true)
	malformed["rewards"][0]["quantity"] = 0
	var result: Dictionary = GameplayStateCodec.decode_pending_loot(malformed, registry)
	if bool(result.get("success", false)):
		failures.append("malformed pending reward unexpectedly reconstructed")
	if result.has("state"):
		failures.append("malformed pending reward exposed collectible partial state")


static func _test_pending_loot_structural_keys_fail_closed(failures: Array[String]) -> void:
	var authored = _definitions()
	var registry = _registry(authored.values())
	var contract: String = InventoryStateCodec.canonical_json(authored["ore"].canonical_descriptor())
	var pending = PendingLootState.new().configure(
		"occurrence.persistence.003",
		"loot_profile.persistence_test",
		[{
			"item_id": "item.persistence_ore",
			"quantity": 1,
			"definition_contract": contract,
		}]
	)
	var encoded: Dictionary = GameplayStateCodec.encode_pending_loot(pending, registry)
	if not bool(encoded.get("success", false)):
		failures.append("strict pending-loot schema regression setup failed")
		return

	var unknown_root: Dictionary = encoded.get("snapshot", {}).duplicate(true)
	unknown_root["future_field"] = 1
	if bool(GameplayStateCodec.decode_pending_loot(unknown_root, registry).get("success", false)):
		failures.append("unknown pending-loot root field did not fail closed")

	var unknown_reward: Dictionary = encoded.get("snapshot", {}).duplicate(true)
	unknown_reward["rewards"][0]["future_field"] = 1
	var reward_result: Dictionary = GameplayStateCodec.decode_pending_loot(unknown_reward, registry)
	if bool(reward_result.get("success", false)):
		failures.append("unknown pending-loot reward field did not fail closed")
	if reward_result.has("state"):
		failures.append("unknown pending-loot reward field exposed collectible partial state")


static func _test_canonical_evidence_is_order_independent(failures: Array[String]) -> void:
	var authored_a = _definitions()
	var authored_b = _definitions()
	var inventory_a = _inventory_with_gap(authored_a)
	var inventory_b = _inventory_with_gap(authored_b)
	var values_a: Array = authored_a.values()
	var values_b: Array = authored_b.values()
	values_b.reverse()
	var encoded_a: Dictionary = GameplayStateCodec.encode_inventory(inventory_a, _registry(values_a))
	var encoded_b: Dictionary = GameplayStateCodec.encode_inventory(inventory_b, _registry(values_b))
	if not bool(encoded_a.get("success", false)) or not bool(encoded_b.get("success", false)):
		failures.append("canonical evidence regression setup failed")
		return
	if str(encoded_a.get("canonical_json", "")) != str(encoded_b.get("canonical_json", "")):
		failures.append("equivalent registry/input ordering changed persistence canonical JSON")
	if str(encoded_a.get("fingerprint", "")) != str(encoded_b.get("fingerprint", "")):
		failures.append("equivalent registry/input ordering changed persistence fingerprint")


static func _inventory_with_gap(authored: Dictionary):
	var inventory = ItemContainerState.new().configure(5, 50.0)
	inventory.add_instance(authored["tool"], {"durability": 73})
	inventory.add_instance(authored["filler_a"], {})
	inventory.add_instance(authored["filler_b"], {})
	inventory.add_stack(authored["ore"], 4, {"seed": 4, "grade": "rich"})
	inventory.remove_instance_at(1)
	inventory.remove_instance_at(2)
	return inventory


static func _definitions() -> Dictionary:
	var tool = _item(
		"item.persistence_tool",
		1,
		2.0,
		[EQUIPMENT_ROOT + ".tool"],
		[EQUIPABLE]
	)
	var filler_a = _item("item.persistence_filler_a", 1, 0.1, ["category.item.misc"], [])
	var filler_b = _item("item.persistence_filler_b", 1, 0.1, ["category.item.misc"], [])
	var ore = _item("item.persistence_ore", 10, 0.5, ["category.item.resource.ore"], [])
	var profile = LootProfileDefinition.new()
	profile.configure_profile(
		"loot_profile.persistence_test",
		"creature.persistence_source",
		["item.persistence_ore"],
		[3]
	)
	return {
		"tool": tool,
		"filler_a": filler_a,
		"filler_b": filler_b,
		"ore": ore,
		"profile": profile,
	}


static func _item(
	content_id: String,
	stack_limit: int,
	unit_weight: float,
	categories: Array,
	capabilities: Array
):
	var item = ItemDefinition.new()
	item.configure_item(content_id, stack_limit, unit_weight)
	item.configure_schema_declarations(categories, capabilities)
	return item


static func _registry(definitions: Array):
	var registry = ContentRegistry.new()
	var diagnostics: Array[String] = registry.index_definitions(definitions)
	if not diagnostics.is_empty():
		push_error("persistence test registry invalid: %s" % [diagnostics])
	return registry


static func _equipment_config(required_capabilities: Array) -> Dictionary:
	var rules: Array = []
	var bindings: Dictionary = {}
	for index in range(1, 5):
		var key: String = "equipment_slot.hotbar.%d" % index
		rules.append(EquipmentSlotRule.new().configure(
			key,
			[EQUIPMENT_ROOT],
			required_capabilities
		))
		bindings[index] = key
	return {"rules": rules, "bindings": bindings}


static func _require_success(
	result: Dictionary,
	label: String,
	failures: Array[String]
) -> bool:
	if bool(result.get("success", false)):
		return true
	failures.append("%s failed: %s" % [label, result.get("diagnostics", [])])
	return false