extends RefCounted

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const InventoryStateCodec := preload("res://gameplay/items/inventory/inventory_state_codec.gd")
const LootProfileDefinition := preload("res://gameplay/loot/definitions/loot_profile_definition.gd")
const PendingLootState := preload("res://gameplay/loot/runtime/pending_loot_state.gd")
const RestoredItemContainerState := preload("res://gameplay/persistence/restored_item_container_state.gd")
const RestoredEquipmentHotbarState := preload("res://gameplay/persistence/restored_equipment_hotbar_state.gd")

const INVENTORY_SCHEMA := "persistence.inventory.v1"
const EQUIPMENT_SCHEMA := "persistence.equipment.v1"
const PENDING_LOOT_SCHEMA := "persistence.pending_loot.v1"
const ITEM_FAMILY := "item"
const LOOT_PROFILE_FAMILY := "loot_profile"


static func encode_inventory(container, content_registry) -> Dictionary:
	var failures: Array[String] = []
	_validate_registry(content_registry, failures)
	if container == null or not container is ItemContainerState:
		failures.append("inventory encode requires ItemContainerState")
	else:
		for failure in container.validate_container():
			failures.append("inventory encode: %s" % failure)
	if not failures.is_empty():
		return _failure(failures)

	var native_snapshot: Dictionary = container.canonical_snapshot()
	var records: Array[Dictionary] = []
	for raw_record in native_snapshot.get("slots", []):
		if not raw_record is Dictionary:
			failures.append("inventory encode encountered malformed occupied slot")
			continue
		var record: Dictionary = raw_record.duplicate(true)
		var state = record.get("state", null)
		if not state is Dictionary:
			failures.append("inventory encode slot state must be Dictionary")
			continue
		var item_id: String = str(state.get("item_id", ""))
		var definition = _resolve_item(content_registry, item_id, "inventory encode", failures)
		if definition != null:
			record["definition_contract"] = _definition_contract(definition)
		records.append(record)

	if not failures.is_empty():
		return _failure(failures)

	var snapshot: Dictionary = {
		"schema": INVENTORY_SCHEMA,
		"slot_capacity": int(native_snapshot.get("slot_capacity", 0)),
		"max_weight": float(native_snapshot.get("max_weight", 0.0)),
		"slots": records,
	}
	return _encoded(snapshot)


static func decode_inventory(snapshot: Variant, content_registry) -> Dictionary:
	var failures: Array[String] = []
	_validate_registry(content_registry, failures)
	var source: Dictionary = _require_snapshot(snapshot, INVENTORY_SCHEMA, "inventory", failures)
	if source.is_empty() and not failures.is_empty():
		return _failure(failures)

	var raw_capacity = source.get("slot_capacity", null)
	var raw_max_weight = source.get("max_weight", null)
	var raw_slots = source.get("slots", null)
	if typeof(raw_capacity) != TYPE_INT:
		failures.append("inventory snapshot slot_capacity must be int")
	elif int(raw_capacity) < 1:
		failures.append("inventory snapshot slot_capacity must be >= 1")
	if typeof(raw_max_weight) != TYPE_INT and typeof(raw_max_weight) != TYPE_FLOAT:
		failures.append("inventory snapshot max_weight must be numeric")
	elif float(raw_max_weight) < 0.0 and not is_equal_approx(float(raw_max_weight), -1.0):
		failures.append("inventory snapshot max_weight must be -1 or >= 0")
	if not raw_slots is Array:
		failures.append("inventory snapshot slots must be Array")
	if not failures.is_empty():
		return _failure(failures)

	var restored = RestoredItemContainerState.new().configure(
		int(raw_capacity),
		float(raw_max_weight)
	)
	var seen_slots: Dictionary = {}
	for raw_record in raw_slots:
		if not raw_record is Dictionary:
			failures.append("inventory snapshot occupied slot must be Dictionary")
			continue
		var record: Dictionary = raw_record
		var raw_slot = record.get("slot", null)
		var raw_kind = record.get("kind", null)
		var raw_state = record.get("state", null)
		var raw_contract = record.get("definition_contract", null)
		if typeof(raw_slot) != TYPE_INT:
			failures.append("inventory snapshot occupied slot index must be int")
			continue
		var slot_index: int = int(raw_slot)
		if slot_index < 0 or slot_index >= int(raw_capacity):
			failures.append("inventory snapshot occupied slot is outside capacity: %d" % slot_index)
		if seen_slots.has(slot_index):
			failures.append("inventory snapshot contains duplicate occupied slot: %d" % slot_index)
		seen_slots[slot_index] = true
		if typeof(raw_kind) != TYPE_STRING:
			failures.append("inventory snapshot slot %d kind must be String" % slot_index)
		if not raw_state is Dictionary:
			failures.append("inventory snapshot slot %d state must be Dictionary" % slot_index)
		if typeof(raw_contract) != TYPE_STRING or str(raw_contract).is_empty():
			failures.append("inventory snapshot slot %d requires definition_contract" % slot_index)
		if typeof(raw_kind) != TYPE_STRING or not raw_state is Dictionary:
			continue

		var item_id: String = str(raw_state.get("item_id", ""))
		var definition = _resolve_item(
			content_registry,
			item_id,
			"inventory snapshot slot %d" % slot_index,
			failures
		)
		if definition == null:
			continue
		if _definition_contract(definition) != str(raw_contract):
			failures.append("inventory saved authored definition changed: %s" % item_id)
			continue
		if slot_index < 0 or slot_index >= int(raw_capacity):
			continue
		var restore_result: Dictionary = restored.restore_record_at(
			slot_index,
			definition,
			str(raw_kind),
			raw_state
		)
		if not bool(restore_result.get("success", false)):
			for diagnostic in restore_result.get("diagnostics", []):
				failures.append("inventory snapshot slot %d: %s" % [slot_index, diagnostic])

	if not failures.is_empty():
		return _failure(failures)
	for failure in restored.validate_container():
		failures.append("restored inventory: %s" % failure)
	if not failures.is_empty():
		return _failure(failures)
	return _success({"state": restored})


static func encode_equipment(equipment, content_registry) -> Dictionary:
	var failures: Array[String] = []
	_validate_registry(content_registry, failures)
	if equipment == null or not equipment is EquipmentHotbarState:
		failures.append("equipment encode requires EquipmentHotbarState")
	else:
		for failure in equipment.validate_state():
			failures.append("equipment encode: %s" % failure)
	if not failures.is_empty():
		return _failure(failures)

	var native_snapshot: Dictionary = equipment.canonical_snapshot()
	var records: Array[Dictionary] = []
	for raw_slot in native_snapshot.get("slots", []):
		if not raw_slot is Dictionary:
			failures.append("equipment encode encountered malformed authored slot")
			continue
		var slot_key: String = str(raw_slot.get("slot_key", ""))
		var container_snapshot = raw_slot.get("container", null)
		if not container_snapshot is Dictionary:
			failures.append("equipment encode slot container must be Dictionary: %s" % slot_key)
			continue
		var occupied_records = container_snapshot.get("slots", [])
		if not occupied_records is Array:
			failures.append("equipment encode slot records must be Array: %s" % slot_key)
			continue
		if occupied_records.is_empty():
			continue
		if occupied_records.size() != 1 or not occupied_records[0] is Dictionary:
			failures.append("equipment encode slot must contain at most one item: %s" % slot_key)
			continue
		var native_record: Dictionary = occupied_records[0]
		var state = native_record.get("state", null)
		if not state is Dictionary:
			failures.append("equipment encode item state must be Dictionary: %s" % slot_key)
			continue
		var item_id: String = str(state.get("item_id", ""))
		var registry_definition = _resolve_item(
			content_registry,
			item_id,
			"equipment encode %s" % slot_key,
			failures
		)
		var stored_definition = equipment.definition_at(slot_key)
		if registry_definition != null:
			if stored_definition == null or not stored_definition is ItemDefinition:
				failures.append("equipment encode occupied slot lacks ItemDefinition: %s" % slot_key)
			elif _definition_contract(stored_definition) != _definition_contract(registry_definition):
				failures.append("equipment encode definition differs from registry authority: %s" % item_id)
			else:
				records.append({
					"slot_key": slot_key,
					"kind": str(native_record.get("kind", "")),
					"state": state.duplicate(true),
					"definition_contract": _definition_contract(registry_definition),
				})

	if not failures.is_empty():
		return _failure(failures)
	records.sort_custom(func(a, b): return str(a.get("slot_key", "")) < str(b.get("slot_key", "")))
	var snapshot: Dictionary = {
		"schema": EQUIPMENT_SCHEMA,
		"selected_hotbar": equipment.selected_hotbar(),
		"slots": records,
	}
	return _encoded(snapshot)


static func decode_equipment(
	snapshot: Variant,
	content_registry,
	current_rules: Array,
	current_hotbar_bindings: Dictionary = {}
) -> Dictionary:
	var failures: Array[String] = []
	_validate_registry(content_registry, failures)
	var source: Dictionary = _require_snapshot(snapshot, EQUIPMENT_SCHEMA, "equipment", failures)
	if source.is_empty() and not failures.is_empty():
		return _failure(failures)

	var raw_selected = source.get("selected_hotbar", null)
	var raw_slots = source.get("slots", null)
	if typeof(raw_selected) != TYPE_INT:
		failures.append("equipment snapshot selected_hotbar must be int")
	elif int(raw_selected) < 1 or int(raw_selected) > 4:
		failures.append("equipment snapshot selected_hotbar must be between 1 and 4")
	if not raw_slots is Array:
		failures.append("equipment snapshot slots must be Array")
	if not failures.is_empty():
		return _failure(failures)

	var restored = RestoredEquipmentHotbarState.new().configure(
		current_rules,
		current_hotbar_bindings
	)
	for failure in restored.validate_state():
		failures.append("current authored equipment config: %s" % failure)
	if not failures.is_empty():
		return _failure(failures)

	var seen_slots: Dictionary = {}
	for raw_record in raw_slots:
		if not raw_record is Dictionary:
			failures.append("equipment snapshot occupied slot must be Dictionary")
			continue
		var record: Dictionary = raw_record
		var raw_slot_key = record.get("slot_key", null)
		var raw_kind = record.get("kind", null)
		var raw_state = record.get("state", null)
		var raw_contract = record.get("definition_contract", null)
		if typeof(raw_slot_key) != TYPE_STRING:
			failures.append("equipment snapshot slot_key must be String")
			continue
		var slot_key: String = str(raw_slot_key)
		if slot_key.is_empty() or slot_key != slot_key.strip_edges():
			failures.append("equipment snapshot slot_key must be non-empty and trimmed")
		if seen_slots.has(slot_key):
			failures.append("equipment snapshot contains duplicate slot: %s" % slot_key)
		seen_slots[slot_key] = true
		if typeof(raw_kind) != TYPE_STRING:
			failures.append("equipment snapshot kind must be String: %s" % slot_key)
		if not raw_state is Dictionary:
			failures.append("equipment snapshot state must be Dictionary: %s" % slot_key)
		if typeof(raw_contract) != TYPE_STRING or str(raw_contract).is_empty():
			failures.append("equipment snapshot requires definition_contract: %s" % slot_key)
		if typeof(raw_kind) != TYPE_STRING or not raw_state is Dictionary:
			continue

		var item_id: String = str(raw_state.get("item_id", ""))
		var definition = _resolve_item(
			content_registry,
			item_id,
			"equipment snapshot %s" % slot_key,
			failures
		)
		if definition == null:
			continue
		if _definition_contract(definition) != str(raw_contract):
			failures.append("equipment saved authored definition changed: %s" % item_id)
			continue
		var restore_result: Dictionary = restored.restore_owned_slot(
			slot_key,
			definition,
			str(raw_kind),
			raw_state
		)
		if not bool(restore_result.get("success", false)):
			for diagnostic in restore_result.get("diagnostics", []):
				failures.append(diagnostic)

	if not failures.is_empty():
		return _failure(failures)
	var selection_result: Dictionary = restored.select_hotbar(int(raw_selected))
	if not bool(selection_result.get("success", false)):
		for diagnostic in selection_result.get("diagnostics", []):
			failures.append("equipment selection restore: %s" % diagnostic)
	for failure in restored.validate_state():
		failures.append("restored equipment: %s" % failure)
	if not failures.is_empty():
		return _failure(failures)
	return _success({"state": restored})


static func encode_pending_loot(pending, content_registry) -> Dictionary:
	var failures: Array[String] = []
	_validate_registry(content_registry, failures)
	if pending == null or not pending is PendingLootState:
		failures.append("pending-loot encode requires PendingLootState")
	else:
		for failure in pending.validate_state():
			failures.append("pending-loot encode: %s" % failure)
	if not failures.is_empty():
		return _failure(failures)

	_resolve_loot_profile(
		content_registry,
		pending.profile_id,
		"pending-loot encode",
		failures
	)
	var rewards: Array[Dictionary] = []
	for reward in pending.rewards:
		var item_id: String = str(reward.get("item_id", ""))
		var definition = _resolve_item(
			content_registry,
			item_id,
			"pending-loot encode",
			failures
		)
		if definition == null:
			continue
		var saved_contract: String = str(reward.get("definition_contract", ""))
		if _definition_contract(definition) != saved_contract:
			failures.append("pending-loot reward authored definition changed: %s" % item_id)
			continue
		rewards.append(reward.duplicate(true))
	if not failures.is_empty():
		return _failure(failures)

	rewards.sort_custom(func(a, b): return str(a.get("item_id", "")) < str(b.get("item_id", "")))
	return _encoded({
		"schema": PENDING_LOOT_SCHEMA,
		"occurrence_id": pending.occurrence_id,
		"profile_id": pending.profile_id,
		"rewards": rewards,
		"consumed": pending.consumed,
	})


static func decode_pending_loot(snapshot: Variant, content_registry) -> Dictionary:
	var failures: Array[String] = []
	_validate_registry(content_registry, failures)
	var source: Dictionary = _require_snapshot(snapshot, PENDING_LOOT_SCHEMA, "pending-loot", failures)
	if source.is_empty() and not failures.is_empty():
		return _failure(failures)

	var raw_occurrence = source.get("occurrence_id", null)
	var raw_profile = source.get("profile_id", null)
	var raw_rewards = source.get("rewards", null)
	var raw_consumed = source.get("consumed", null)
	if typeof(raw_occurrence) != TYPE_STRING:
		failures.append("pending-loot snapshot occurrence_id must be String")
	if typeof(raw_profile) != TYPE_STRING:
		failures.append("pending-loot snapshot profile_id must be String")
	if not raw_rewards is Array:
		failures.append("pending-loot snapshot rewards must be Array")
	if typeof(raw_consumed) != TYPE_BOOL:
		failures.append("pending-loot snapshot consumed must be bool")
	if not failures.is_empty():
		return _failure(failures)

	_resolve_loot_profile(
		content_registry,
		str(raw_profile),
		"pending-loot snapshot",
		failures
	)
	var rewards: Array[Dictionary] = []
	for raw_reward in raw_rewards:
		if not raw_reward is Dictionary:
			failures.append("pending-loot snapshot reward must be Dictionary")
			continue
		var raw_item_id = raw_reward.get("item_id", null)
		var raw_quantity = raw_reward.get("quantity", null)
		var raw_contract = raw_reward.get("definition_contract", null)
		if typeof(raw_item_id) != TYPE_STRING:
			failures.append("pending-loot snapshot reward item_id must be String")
		if typeof(raw_quantity) != TYPE_INT:
			failures.append("pending-loot snapshot reward quantity must be int")
		if typeof(raw_contract) != TYPE_STRING or str(raw_contract).is_empty():
			failures.append("pending-loot snapshot reward requires definition_contract")
		if typeof(raw_item_id) != TYPE_STRING or typeof(raw_quantity) != TYPE_INT:
			continue
		var item_id: String = str(raw_item_id)
		var definition = _resolve_item(
			content_registry,
			item_id,
			"pending-loot snapshot reward",
			failures
		)
		if definition == null:
			continue
		if _definition_contract(definition) != str(raw_contract):
			failures.append("pending-loot saved authored definition changed: %s" % item_id)
			continue
		rewards.append({
			"item_id": item_id,
			"quantity": int(raw_quantity),
			"definition_contract": str(raw_contract),
		})

	if not failures.is_empty():
		return _failure(failures)
	var restored = PendingLootState.new().configure(
		str(raw_occurrence),
		str(raw_profile),
		rewards
	)
	if bool(raw_consumed):
		if not restored.consume_after_commit():
			failures.append("pending-loot consumed state could not be reconstructed")
	for failure in restored.validate_state():
		failures.append("restored pending-loot: %s" % failure)
	if not failures.is_empty():
		return _failure(failures)
	return _success({"state": restored})


static func _require_snapshot(
	snapshot: Variant,
	expected_schema: String,
	label: String,
	failures: Array[String]
) -> Dictionary:
	if not snapshot is Dictionary:
		failures.append("%s snapshot must be Dictionary" % label)
		return {}
	for failure in InventoryStateCodec.validate_state(snapshot, "%s_snapshot" % label):
		failures.append(failure)
	var source: Dictionary = snapshot
	var raw_schema = source.get("schema", null)
	if typeof(raw_schema) != TYPE_STRING:
		failures.append("%s snapshot schema must be String" % label)
	elif str(raw_schema) != expected_schema:
		failures.append("%s snapshot schema mismatch: %s" % [label, str(raw_schema)])
	return source


static func _validate_registry(content_registry, failures: Array[String]) -> void:
	if content_registry == null or not content_registry is ContentRegistry:
		failures.append("persistence codec requires ContentRegistry")
		return
	if not content_registry.is_valid():
		for diagnostic in content_registry.diagnostics():
			failures.append("content registry: %s" % diagnostic)


static func _resolve_item(
	content_registry,
	item_id: String,
	label: String,
	failures: Array[String]
):
	if content_registry == null or not content_registry is ContentRegistry:
		return null
	var resolution: Dictionary = content_registry.resolve(item_id, ITEM_FAMILY)
	for diagnostic in resolution.get("diagnostics", []):
		failures.append("%s item resolution %s: %s" % [label, item_id, diagnostic])
	var definition = resolution.get("definition", null)
	if definition != null and not definition is ItemDefinition:
		failures.append("%s item resolution did not return ItemDefinition: %s" % [label, item_id])
		return null
	return definition


static func _resolve_loot_profile(
	content_registry,
	profile_id: String,
	label: String,
	failures: Array[String]
):
	if content_registry == null or not content_registry is ContentRegistry:
		return null
	var resolution: Dictionary = content_registry.resolve(profile_id, LOOT_PROFILE_FAMILY)
	for diagnostic in resolution.get("diagnostics", []):
		failures.append("%s profile resolution %s: %s" % [label, profile_id, diagnostic])
	var definition = resolution.get("definition", null)
	if definition != null and not definition is LootProfileDefinition:
		failures.append("%s profile resolution did not return LootProfileDefinition: %s" % [
			label,
			profile_id,
		])
		return null
	return definition


static func _definition_contract(definition) -> String:
	return InventoryStateCodec.canonical_json(definition.canonical_descriptor())


static func _encoded(snapshot: Dictionary) -> Dictionary:
	var canonical_snapshot: Dictionary = InventoryStateCodec.canonicalize(snapshot)
	var canonical_json: String = InventoryStateCodec.canonical_json(canonical_snapshot)
	return _success({
		"snapshot": canonical_snapshot,
		"canonical_json": canonical_json,
		"fingerprint": canonical_json.sha256_text(),
	})


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {"success": false, "diagnostics": diagnostics}


static func _success(extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"success": true, "diagnostics": []}
	for key in extra.keys():
		result[key] = extra[key]
	return result
