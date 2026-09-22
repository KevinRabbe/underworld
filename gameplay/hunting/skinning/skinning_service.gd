extends RefCounted

## Production skinning transaction authority.  The service is deliberately
## detached from presentation and carcass nodes so the same transaction is used
## by the real player route and by persistence/replay validation.

const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const InventoryTransactionPlan := preload("res://gameplay/items/inventory/inventory_transaction_plan.gd")
const InventoryTransactionService := preload("res://gameplay/items/inventory/inventory_transaction_service.gd")
const EquippedItemResolver := preload("res://gameplay/items/equipment/equipped_item_resolver.gd")

const KNIFE_ID := "item.tool.skinning_knife"
const KNIFE_CATEGORY := "category.item.equipment.tool.knife"
const SKINNING_CAPABILITY := "capability.skinning"
const MEAT_ID := "item.resource.raw_meat"
const HIDE_ID := "item.resource.boar_hide"
const PROFESSION := "skinning"
const OUTPUT_MEAT := 2
const OUTPUT_HIDE := 1

var _inventory = null
var _equipment = null
var _definitions: Dictionary = {}
var _transactions := InventoryTransactionService.new()
var _resolver := EquippedItemResolver.new()
var _progression: Dictionary = {"skinning": 0, "last_carcass_id": ""}


func configure(inventory_state, equipment_state, definitions: Array, progression: Dictionary = {}) -> RefCounted:
	_inventory = inventory_state
	_equipment = equipment_state
	_definitions.clear()
	for candidate in definitions:
		if candidate != null and candidate is ItemDefinition:
			_definitions[str(candidate.content_id)] = candidate
	for key in ["skinning", "last_carcass_id"]:
		if progression.has(key):
			_progression[key] = progression[key]
	return self


func validate_runtime() -> Array[String]:
	var failures: Array[String] = []
	if _inventory == null or not _inventory is ItemContainerState:
		failures.append("skinning requires ItemContainerState")
	if _equipment == null or not _equipment is EquipmentHotbarState:
		failures.append("skinning requires EquipmentHotbarState")
	for item_id in [KNIFE_ID, MEAT_ID, HIDE_ID]:
		var definition = _definitions.get(item_id, null)
		if definition == null or not definition is ItemDefinition:
			failures.append("skinning is missing ItemDefinition: %s" % item_id)
			continue
		for diagnostic in definition.validate_definition():
			failures.append("%s: %s" % [item_id, diagnostic])
	return failures


func knife_eligibility() -> Dictionary:
	if _equipment == null or not _equipment is EquipmentHotbarState:
		return _failure(["skinning equipment state is unavailable"])
	var selected := _resolver.resolve_selected(_equipment)
	if not bool(selected.get("success", false)):
		return selected
	if not _resolver.selected_matches_category_root(_equipment, KNIFE_CATEGORY):
		return _failure(["selected item does not satisfy skinning knife category"])
	if not _resolver.selected_has_capability(_equipment, SKINNING_CAPABILITY):
		return _failure(["selected item lacks skinning capability"])
	return _success({"item_id": str(selected.get("item_id", ""))})


func skin_carcass(carcass_id: String, consumed: bool = false) -> Dictionary:
	if carcass_id.is_empty():
		return _failure(["carcass id is required"])
	if consumed:
		return _failure(["carcass has already been skinned: %s" % carcass_id])
	var knife := knife_eligibility()
	if not bool(knife.get("success", false)):
		return knife
	if _inventory == null or not _inventory is ItemContainerState:
		return _failure(["skinning inventory state is unavailable"])
	var meat = _definitions.get(MEAT_ID, null)
	var hide = _definitions.get(HIDE_ID, null)
	if meat == null or hide == null:
		return _failure(["skinning output definitions are unavailable"])
	var plan := InventoryTransactionPlan.new().bind_container("skinning_inventory", _inventory)
	plan.add_stack("skinning_inventory", meat, OUTPUT_MEAT)
	plan.add_stack("skinning_inventory", hide, OUTPUT_HIDE)
	var validation := _transactions.validate(plan)
	if not bool(validation.get("success", false)):
		return validation
	var committed := _transactions.commit(plan)
	if not bool(committed.get("success", false)):
		return committed
	_progression[PROFESSION] = int(_progression.get(PROFESSION, 0)) + 1
	_progression["last_carcass_id"] = carcass_id
	var events: Array = committed.get("events", []).duplicate(true)
	events.append({"type": "skinning.completed", "carcass_id": carcass_id, "meat": OUTPUT_MEAT, "hide": OUTPUT_HIDE})
	committed["events"] = events
	committed["carcass_id"] = carcass_id
	committed["progression"] = _progression.duplicate(true)
	return committed


func progression_snapshot() -> Dictionary:
	return _progression.duplicate(true)


func restore_progression(snapshot: Dictionary) -> Dictionary:
	var value := int(snapshot.get(PROFESSION, 0))
	if value < 0:
		return _failure(["skinning progression must be >= 0"])
	_progression[PROFESSION] = value
	_progression["last_carcass_id"] = str(snapshot.get("last_carcass_id", ""))
	return _success()


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {"success": false, "diagnostics": diagnostics, "events": []}


static func _success(extra: Dictionary = {}) -> Dictionary:
	var result := {"success": true, "diagnostics": [], "events": []}
	for key in extra.keys():
		result[key] = extra[key]
	return result
