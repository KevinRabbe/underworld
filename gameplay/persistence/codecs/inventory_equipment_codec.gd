extends RefCounted

const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const RestoredItemContainerState := preload("res://gameplay/persistence/restored_item_container_state.gd")
const RestoredEquipmentHotbarState := preload("res://gameplay/persistence/restored_equipment_hotbar_state.gd")
const Support := preload("res://gameplay/persistence/codecs/component_codec_support.gd")

const INVENTORY_SCHEMA := "persistence.inventory.v1"
const EQUIPMENT_SCHEMA := "persistence.equipment.v1"

const INVENTORY_ROOT_KEYS := ["schema", "slot_capacity", "max_weight", "slots"]
const INVENTORY_RECORD_KEYS := ["slot", "kind", "state", "definition_contract"]
const EQUIPMENT_ROOT_KEYS := ["schema", "selected_hotbar", "selected_slot_key", "slots"]
const EQUIPMENT_RECORD_KEYS := ["slot_key", "kind", "state", "definition_contract"]


static func encode_inventory(container, content_registry) -> Dictionary:
	var failures: Array[String] = []
	Support.validate_registry(content_registry, failures)
	if container == null or not container is ItemContainerState:
		failures.append("inventory encode requires ItemContainerState")
	else:
		for failure in container.validate_container():
			failures.append("inventory encode: %s" % failure)
	if not failures.is_empty():
		return Support.failure(failures)

	var native_snapshot: Dictionary = container.canonical_snapshot()
	var native_max_weight: float = float(native_snapshot.get("max_weight", 0.0))
	if is_nan(native_max_weight) or is_inf(native_max_weight):
		failures.append("inventory encode max_weight must be finite")
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
		var definition = Support.resolve_item(content_registry, item_id, "inventory encode", failures)
		if definition != null:
			record["definition_contract"] = Support.definition_contract(definition)
		records.append(record)

	if not failures.is_empty():
		return Support.failure(failures)
	return Support.encoded({
		"schema": INVENTORY_SCHEMA,
		"slot_capacity": int(native_snapshot.get("slot_capacity", 0)),
		"max_weight": native_max_weight,
		"slots": records,
	}, "inventory snapshot")


static func decode_inventory(snapshot: Variant, content_registry) -> Dictionary:
	var failures: Array[String] = []
	Support.validate_registry(content_registry, failures)
	var source: Dictionary = Support.require_snapshot(
		snapshot,
		INVENTORY_SCHEMA,
		"inventory",
		INVENTORY_ROOT_KEYS,
		failures
	)
	if source.is_empty() and not failures.is_empty():
		return Support.failure(failures)

	var raw_capacity = source.get("slot_capacity", null)
	var raw_max_weight = source.get("max_weight", null)
	var raw_slots = source.get("slots", null)
	if typeof(raw_capacity) != TYPE_INT:
		failures.append("inventory snapshot slot_capacity must be int")
	elif int(raw_capacity) < 1:
		failures.append("inventory snapshot slot_capacity must be >= 1")
	if typeof(raw_max_weight) != TYPE_INT and typeof(raw_max_weight) != TYPE_FLOAT:
		failures.append("inventory snapshot max_weight must be numeric")
	else:
		var max_weight: float = float(raw_max_weight)
		if is_nan(max_weight) or is_inf(max_weight):
			failures.append("inventory snapshot max_weight must be finite")
		elif max_weight < 0.0 and not is_equal_approx(max_weight, -1.0):
			failures.append("inventory snapshot max_weight must be -1 or >= 0")
	if not raw_slots is Array:
		failures.append("inventory snapshot slots must be Array")
	if not failures.is_empty():
		return Support.failure(failures)

	var restored = RestoredItemContainerState.new().configure(int(raw_capacity), float(raw_max_weight))
	var seen_slots: Dictionary = {}
	for raw_record in raw_slots:
		if not raw_record is Dictionary:
			failures.append("inventory snapshot occupied slot must be Dictionary")
			continue
		var record: Dictionary = raw_record
		Support.validate_exact_keys(
			record,
			INVENTORY_RECORD_KEYS,
			"inventory snapshot occupied slot",
			failures
		)
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
		var definition = Support.resolve_item(
			content_registry,
			item_id,
			"inventory snapshot slot %d" % slot_index,
			failures
		)
		if definition == null:
			continue
		if Support.definition_contract(definition) != str(raw_contract):
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
		return Support.failure(failures)
	for failure in restored.validate_container():
		failures.append("restored inventory: %s" % failure)
	if not failures.is_empty():
		return Support.failure(failures)
	return Support.success({"state": restored})


static func encode_equipment(equipment, content_registry) -> Dictionary:
	var failures: Array[String] = []
	Support.validate_registry(content_registry, failures)
	if equipment == null or not equipment is EquipmentHotbarState:
		failures.append("equipment encode requires EquipmentHotbarState")
	else:
		for failure in equipment.validate_state():
			failures.append("equipment encode: %s" % failure)
	if not failures.is_empty():
		return Support.failure(failures)

	var native_snapshot: Dictionary = equipment.canonical_snapshot()
	var selected_slot_key: String = equipment.selected_slot_key()
	if selected_slot_key.is_empty():
		failures.append("equipment encode selected hotbar requires authored slot binding")
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
		var registry_definition = Support.resolve_item(
			content_registry,
			item_id,
			"equipment encode %s" % slot_key,
			failures
		)
		var stored_definition = equipment.definition_at(slot_key)
		if registry_definition != null:
			if stored_definition == null or not stored_definition is ItemDefinition:
				failures.append("equipment encode occupied slot lacks ItemDefinition: %s" % slot_key)
			elif Support.definition_contract(stored_definition) != Support.definition_contract(registry_definition):
				failures.append("equipment encode definition differs from registry authority: %s" % item_id)
			else:
				records.append({
					"slot_key": slot_key,
					"kind": str(native_record.get("kind", "")),
					"state": state.duplicate(true),
					"definition_contract": Support.definition_contract(registry_definition),
				})

	if not failures.is_empty():
		return Support.failure(failures)
	records.sort_custom(func(a, b): return str(a.get("slot_key", "")) < str(b.get("slot_key", "")))
	return Support.encoded({
		"schema": EQUIPMENT_SCHEMA,
		"selected_hotbar": equipment.selected_hotbar(),
		"selected_slot_key": selected_slot_key,
		"slots": records,
	}, "equipment snapshot")


static func decode_equipment(
	snapshot: Variant,
	content_registry,
	current_rules: Array,
	current_hotbar_bindings: Dictionary
) -> Dictionary:
	var failures: Array[String] = []
	Support.validate_registry(content_registry, failures)
	var source: Dictionary = Support.require_snapshot(
		snapshot,
		EQUIPMENT_SCHEMA,
		"equipment",
		EQUIPMENT_ROOT_KEYS,
		failures
	)
	if source.is_empty() and not failures.is_empty():
		return Support.failure(failures)

	var raw_selected = source.get("selected_hotbar", null)
	var raw_selected_slot_key = source.get("selected_slot_key", null)
	var raw_slots = source.get("slots", null)
	if typeof(raw_selected) != TYPE_INT:
		failures.append("equipment snapshot selected_hotbar must be int")
	elif int(raw_selected) < 1 or int(raw_selected) > 4:
		failures.append("equipment snapshot selected_hotbar must be between 1 and 4")
	if typeof(raw_selected_slot_key) != TYPE_STRING:
		failures.append("equipment snapshot selected_slot_key must be String")
	elif str(raw_selected_slot_key).is_empty() or str(raw_selected_slot_key) != str(raw_selected_slot_key).strip_edges():
		failures.append("equipment snapshot selected_slot_key must be non-empty and trimmed")
	if not raw_slots is Array:
		failures.append("equipment snapshot slots must be Array")
	if not failures.is_empty():
		return Support.failure(failures)

	var selected_index: int = int(raw_selected)
	if not current_hotbar_bindings.has(selected_index):
		failures.append("current authored hotbar binding is missing saved selection: %d" % selected_index)
	else:
		var current_selected_slot_key: String = str(current_hotbar_bindings[selected_index])
		if current_selected_slot_key != str(raw_selected_slot_key):
			failures.append(
				"current authored hotbar binding changed saved selection: %s != %s" % [
					current_selected_slot_key,
					str(raw_selected_slot_key),
				]
			)
	if not failures.is_empty():
		return Support.failure(failures)

	var restored = RestoredEquipmentHotbarState.new().configure(current_rules, current_hotbar_bindings)
	for failure in restored.validate_state():
		failures.append("current authored equipment config: %s" % failure)
	if not failures.is_empty():
		return Support.failure(failures)

	var seen_slots: Dictionary = {}
	for raw_record in raw_slots:
		if not raw_record is Dictionary:
			failures.append("equipment snapshot occupied slot must be Dictionary")
			continue
		var record: Dictionary = raw_record
		Support.validate_exact_keys(
			record,
			EQUIPMENT_RECORD_KEYS,
			"equipment snapshot occupied slot",
			failures
		)
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
		var definition = Support.resolve_item(
			content_registry,
			item_id,
			"equipment snapshot %s" % slot_key,
			failures
		)
		if definition == null:
			continue
		if Support.definition_contract(definition) != str(raw_contract):
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
		return Support.failure(failures)
	var selection_result: Dictionary = restored.select_hotbar(selected_index)
	if not bool(selection_result.get("success", false)):
		for diagnostic in selection_result.get("diagnostics", []):
			failures.append("equipment selection restore: %s" % diagnostic)
	elif restored.selected_slot_key() != str(raw_selected_slot_key):
		failures.append("restored equipment selected slot does not match saved semantic selection")
	for failure in restored.validate_state():
		failures.append("restored equipment: %s" % failure)
	if not failures.is_empty():
		return Support.failure(failures)
	return Support.success({"state": restored})
