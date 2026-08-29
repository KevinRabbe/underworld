extends RefCounted

const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const InventoryTransactionPlan := preload("res://gameplay/items/inventory/inventory_transaction_plan.gd")
const InventoryTransactionService := preload("res://gameplay/items/inventory/inventory_transaction_service.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const EquippedItemResolver := preload("res://gameplay/items/equipment/equipped_item_resolver.gd")

const INVENTORY_KEY := "surface_inventory"
const WOOD_ID := "item.resource.wood"
const STONE_ID := "item.resource.stone"
const AXE_ID := "item.tool.stone_axe"
const PICKAXE_ID := "item.tool.stone_pickaxe"
const AXE_CATEGORY_ROOT := "category.item.equipment.tool.axe"
const PICKAXE_CATEGORY_ROOT := "category.item.equipment.tool.pickaxe"
const HARVEST_TOOL := "capability.harvest_tool"

var _inventory = null
var _equipment = null
var _definitions: Dictionary = {}
var _transactions = InventoryTransactionService.new()
var _resolver = EquippedItemResolver.new()


func configure(inventory_state, equipment_state, definitions: Array) -> RefCounted:
	_inventory = inventory_state
	_equipment = equipment_state
	_definitions.clear()
	for candidate in definitions:
		if candidate == null or not candidate is ItemDefinition:
			continue
		_definitions[str(candidate.content_id)] = candidate
	return self


func validate_runtime() -> Array[String]:
	var failures: Array[String] = []
	if _inventory == null or not _inventory is ItemContainerState:
		failures.append("surface harvest requires ItemContainerState")
	if _equipment == null or not _equipment is EquipmentHotbarState:
		failures.append("surface harvest requires EquipmentHotbarState")
	for required_id in [WOOD_ID, STONE_ID, AXE_ID, PICKAXE_ID]:
		var definition = _definitions.get(required_id, null)
		if definition == null or not definition is ItemDefinition:
			failures.append("surface harvest is missing ItemDefinition: %s" % required_id)
			continue
		for failure in definition.validate_definition():
			failures.append("%s: %s" % [required_id, failure])
	failures.sort()
	return failures


func definition(item_id: String):
	return _definitions.get(item_id, null)


func item_id_for_world_object(object_type: String) -> String:
	if object_type == "branch" or object_type == "tree":
		return WOOD_ID
	if object_type == "loose_stone" or object_type == "rock":
		return STONE_ID
	return ""


func tool_eligibility(object_type: String) -> Dictionary:
	var category_root: String = ""
	if object_type == "tree":
		category_root = AXE_CATEGORY_ROOT
	elif object_type == "rock":
		category_root = PICKAXE_CATEGORY_ROOT
	else:
		return _failure(["unsupported harvest object type: %s" % object_type])

	if _equipment == null or not _equipment is EquipmentHotbarState:
		return _failure(["surface harvest equipment state is unavailable"])
	var selected: Dictionary = _resolver.resolve_selected(_equipment)
	if not bool(selected.get("success", false)):
		return _failure(selected.get("diagnostics", []))
	if not _resolver.selected_matches_category_root(_equipment, category_root):
		return _failure([
			"selected item does not satisfy harvest category %s" % category_root,
		])
	if not _resolver.selected_has_capability(_equipment, HARVEST_TOOL):
		return _failure([
			"selected item lacks harvest capability %s" % HARVEST_TOOL,
		])
	return _success({
		"object_type": object_type,
		"item_id": str(selected.get("item_id", "")),
		"slot_key": str(selected.get("slot_key", "")),
		"category_root": category_root,
		"capability": HARVEST_TOOL,
	})


func preflight_yield(item_id: String, quantity: int) -> Dictionary:
	var plan_result: Dictionary = _yield_plan(item_id, quantity, false)
	if not bool(plan_result.get("success", false)):
		return plan_result
	return _transactions.validate(plan_result.get("plan"))


func commit_yield(item_id: String, quantity: int, source_object_id: String = "") -> Dictionary:
	var plan_result: Dictionary = _yield_plan(item_id, quantity, false)
	if not bool(plan_result.get("success", false)):
		return plan_result
	var result: Dictionary = _transactions.commit(plan_result.get("plan"))
	if not bool(result.get("success", false)):
		return result
	var events: Array = result.get("events", []).duplicate(true)
	events.append({
		"type": "harvest.inventory_committed",
		"object_id": source_object_id,
		"item_id": item_id,
		"quantity": quantity,
	})
	result["events"] = events
	result["item_id"] = item_id
	result["quantity"] = quantity
	return result


func rollback_yield(item_id: String, quantity: int, source_object_id: String = "") -> Dictionary:
	var plan_result: Dictionary = _yield_plan(item_id, quantity, true)
	if not bool(plan_result.get("success", false)):
		return plan_result
	var result: Dictionary = _transactions.commit(plan_result.get("plan"))
	if not bool(result.get("success", false)):
		var diagnostics: Array = result.get("diagnostics", []).duplicate()
		diagnostics.append("HARD INVARIANT: failed to rollback committed harvest yield for %s" % source_object_id)
		return _failure(diagnostics)
	return result


func resource_counts() -> Vector2i:
	if _inventory == null or not _inventory is ItemContainerState:
		return Vector2i.ZERO
	return Vector2i(
		_inventory.quantity_of(WOOD_ID),
		_inventory.quantity_of(STONE_ID)
	)


func selected_descriptor() -> Dictionary:
	if _equipment == null or not _equipment is EquipmentHotbarState:
		return _failure(["surface harvest equipment state is unavailable"])
	return _resolver.resolve_selected(_equipment)


func _yield_plan(item_id: String, quantity: int, remove: bool) -> Dictionary:
	if _inventory == null or not _inventory is ItemContainerState:
		return _failure(["surface harvest inventory state is unavailable"])
	if quantity <= 0:
		return _failure(["surface harvest quantity must be > 0"])
	var definition = _definitions.get(item_id, null)
	if definition == null or not definition is ItemDefinition:
		return _failure(["surface harvest output is missing ItemDefinition: %s" % item_id])
	if definition.stack_limit <= 1:
		return _failure(["surface harvest output must be stackable: %s" % item_id])
	var plan = InventoryTransactionPlan.new().bind_container(INVENTORY_KEY, _inventory)
	if remove:
		plan.remove_stack(INVENTORY_KEY, definition, quantity)
	else:
		plan.add_stack(INVENTORY_KEY, definition, quantity)
	if not plan.failures().is_empty():
		return _failure(plan.failures())
	return _success({"plan": plan})


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {"success": false, "diagnostics": diagnostics, "events": []}


static func _success(extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"success": true, "diagnostics": [], "events": []}
	for key in extra.keys():
		result[key] = extra[key]
	return result
