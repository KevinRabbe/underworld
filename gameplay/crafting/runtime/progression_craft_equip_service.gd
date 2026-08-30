extends RefCounted

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const RecipeDefinition := preload("res://gameplay/crafting/definitions/recipe_definition.gd")
const CraftingService := preload("res://gameplay/crafting/runtime/crafting_service.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const EquipmentService := preload("res://gameplay/items/equipment/equipment_service.gd")
const EquippedItemResolver := preload("res://gameplay/items/equipment/equipped_item_resolver.gd")

var _crafting_service
var _content_registry
var _equipment_service
var _resolver
var _configuration_failures: Array[String] = []


func configure(
	crafting_service,
	content_registry,
	equipment_service = null,
	resolver = null
) -> RefCounted:
	_crafting_service = crafting_service
	_content_registry = content_registry
	_equipment_service = EquipmentService.new() if equipment_service == null else equipment_service
	_resolver = EquippedItemResolver.new() if resolver == null else resolver
	_configuration_failures.clear()
	if _crafting_service == null or not _crafting_service is CraftingService:
		_configuration_failures.append("progression bridge requires accepted CraftingService")
	if _content_registry == null or not _content_registry is ContentRegistry:
		_configuration_failures.append("progression bridge requires accepted ContentRegistry")
	elif not _content_registry.is_valid():
		for failure in _content_registry.diagnostics():
			_configuration_failures.append("content registry: %s" % failure)
	if _equipment_service == null or not _equipment_service is EquipmentService:
		_configuration_failures.append("progression bridge requires EquipmentService")
	if _resolver == null or not _resolver is EquippedItemResolver:
		_configuration_failures.append("progression bridge requires EquippedItemResolver")
	_configuration_failures.sort()
	return self


func craft_and_equip(
	recipe_content_id: String,
	context,
	inventory,
	equipment_state,
	output_item_id: String,
	target_slot_key: String,
	preferred_hotbar: int = 0
) -> Dictionary:
	var failures: Array[String] = _configuration_failures.duplicate()
	failures.append_array(_runtime_state_failures(inventory, equipment_state))
	var recipe = _resolve_recipe(recipe_content_id, failures)
	var output_definition = _resolve_single_equip_output(recipe, output_item_id, failures)
	if output_definition != null:
		failures.append_array(_target_failures(
			equipment_state,
			output_definition,
			target_slot_key,
			preferred_hotbar
		))
	if not failures.is_empty():
		return _failure(
			"preflight",
			recipe_content_id,
			output_item_id,
			target_slot_key,
			preferred_hotbar,
			failures
		)

	var before_output_slots: Array[int] = _matching_instance_slots(inventory, output_item_id)
	var crafted: Dictionary = _crafting_service.craft(
		recipe_content_id,
		context,
		inventory
	)
	if not bool(crafted.get("success", false)):
		var result: Dictionary = _failure(
			"craft",
			recipe_content_id,
			output_item_id,
			target_slot_key,
			preferred_hotbar,
			crafted.get("diagnostics", [])
		)
		result["events"] = crafted.get("events", []).duplicate(true)
		result["craft_transaction_fingerprint"] = str(
			crafted.get("transaction_fingerprint", "")
		)
		return result

	var source_slot: int = _new_instance_slot(inventory, output_item_id, before_output_slots)
	if source_slot < 0:
		var unresolved: Dictionary = _failure(
			"resolve_output",
			recipe_content_id,
			output_item_id,
			target_slot_key,
			preferred_hotbar,
			["successful craft did not expose one newly produced item instance: %s" % output_item_id]
		)
		unresolved["craft_succeeded"] = true
		unresolved["events"] = crafted.get("events", []).duplicate(true)
		unresolved["craft_transaction_fingerprint"] = str(
			crafted.get("transaction_fingerprint", "")
		)
		return unresolved

	var equipped: Dictionary = equip_existing(
		inventory,
		equipment_state,
		source_slot,
		output_item_id,
		target_slot_key,
		preferred_hotbar
	)
	var events: Array = crafted.get("events", []).duplicate(true)
	events.append_array(equipped.get("events", []).duplicate(true))
	if not bool(equipped.get("success", false)):
		var failed_equip: Dictionary = _failure(
			"equip",
			recipe_content_id,
			output_item_id,
			target_slot_key,
			preferred_hotbar,
			equipped.get("diagnostics", [])
		)
		failed_equip["craft_succeeded"] = true
		failed_equip["equip_attempted"] = bool(equipped.get("equip_attempted", false))
		failed_equip["events"] = events
		failed_equip["craft_transaction_fingerprint"] = str(
			crafted.get("transaction_fingerprint", "")
		)
		failed_equip["equip_transaction_fingerprint"] = str(
			equipped.get("equip_transaction_fingerprint", "")
		)
		return failed_equip

	events.append({
		"type": "progression.craft_equip_completed",
		"recipe_id": recipe_content_id,
		"item_id": output_item_id,
		"slot_key": target_slot_key,
		"hotbar": preferred_hotbar,
	})
	return {
		"success": true,
		"stage": "complete",
		"diagnostics": [],
		"recipe_id": recipe_content_id,
		"output_item_id": output_item_id,
		"target_slot_key": target_slot_key,
		"preferred_hotbar": preferred_hotbar,
		"craft_succeeded": true,
		"equip_attempted": true,
		"equip_succeeded": true,
		"source_slot": source_slot,
		"selected_item": equipped.get("selected_item", {}).duplicate(true),
		"events": events,
		"craft_transaction_fingerprint": str(crafted.get("transaction_fingerprint", "")),
		"equip_transaction_fingerprint": str(
			equipped.get("equip_transaction_fingerprint", "")
		),
	}


func equip_existing(
	inventory,
	equipment_state,
	source_slot: int,
	item_content_id: String,
	target_slot_key: String,
	preferred_hotbar: int = 0
) -> Dictionary:
	var failures: Array[String] = _configuration_failures.duplicate()
	failures.append_array(_runtime_state_failures(inventory, equipment_state))
	var definition = _resolve_item(item_content_id, failures)
	if definition != null:
		failures.append_array(_target_failures(
			equipment_state,
			definition,
			target_slot_key,
			preferred_hotbar
		))
	if inventory != null and inventory is ItemContainerState:
		var source_record: Dictionary = inventory.state_at(source_slot)
		if source_record.is_empty():
			failures.append("progression equip source slot is empty or outside inventory: %d" % source_slot)
		elif str(source_record.get("state", {}).get("item_id", "")) != item_content_id:
			failures.append(
				"progression equip source item does not match requested item: %s" % item_content_id
			)
	if not failures.is_empty():
		var rejected: Dictionary = _equip_failure(failures)
		rejected["source_slot"] = source_slot
		return rejected

	var equipped: Dictionary = _equipment_service.equip_from_inventory(
		equipment_state,
		inventory,
		source_slot,
		definition,
		target_slot_key
	)
	if not bool(equipped.get("success", false)):
		var failed: Dictionary = _equip_failure(equipped.get("diagnostics", []))
		failed["equip_attempted"] = true
		failed["events"] = equipped.get("events", []).duplicate(true)
		failed["equip_transaction_fingerprint"] = str(
			equipped.get("transaction_fingerprint", "")
		)
		failed["source_slot"] = source_slot
		return failed

	var events: Array = equipped.get("events", []).duplicate(true)
	if preferred_hotbar > 0:
		var selection: Dictionary = equipment_state.select_hotbar(preferred_hotbar)
		if not bool(selection.get("success", false)):
			var selection_failed: Dictionary = _equip_failure(selection.get("diagnostics", []))
			selection_failed["equip_attempted"] = true
			selection_failed["equip_succeeded"] = true
			selection_failed["events"] = events
			selection_failed["equip_transaction_fingerprint"] = str(
				equipped.get("transaction_fingerprint", "")
			)
			selection_failed["source_slot"] = source_slot
			return selection_failed
		events.append_array(selection.get("events", []).duplicate(true))

	var selected: Dictionary = _resolver.resolve_selected(equipment_state)
	if preferred_hotbar > 0 and not bool(selected.get("success", false)):
		var resolution_failed: Dictionary = _equip_failure(selected.get("diagnostics", []))
		resolution_failed["equip_attempted"] = true
		resolution_failed["equip_succeeded"] = true
		resolution_failed["events"] = events
		resolution_failed["equip_transaction_fingerprint"] = str(
			equipped.get("transaction_fingerprint", "")
		)
		resolution_failed["source_slot"] = source_slot
		return resolution_failed

	var semantic_selected: Dictionary = _semantic_selected(selected)
	events.append({
		"type": "progression.equip_completed",
		"item_id": item_content_id,
		"slot_key": target_slot_key,
		"hotbar": preferred_hotbar,
	})
	return {
		"success": true,
		"diagnostics": [],
		"equip_attempted": true,
		"equip_succeeded": true,
		"source_slot": source_slot,
		"item_id": item_content_id,
		"target_slot_key": target_slot_key,
		"preferred_hotbar": preferred_hotbar,
		"selected_item": semantic_selected,
		"events": events,
		"equip_transaction_fingerprint": str(equipped.get("transaction_fingerprint", "")),
	}


func _resolve_recipe(recipe_content_id: String, failures: Array[String]):
	if _content_registry == null or not _content_registry is ContentRegistry:
		return null
	var resolution: Dictionary = _content_registry.resolve(recipe_content_id, "recipe")
	for failure in resolution.get("diagnostics", []):
		failures.append("progression recipe resolution: %s" % failure)
	var recipe = resolution.get("definition", null)
	if recipe != null and not recipe is RecipeDefinition:
		failures.append("progression recipe must inherit RecipeDefinition: %s" % recipe_content_id)
		return null
	return recipe


func _resolve_single_equip_output(recipe, output_item_id: String, failures: Array[String]):
	if recipe == null or not recipe is RecipeDefinition:
		return null
	var quantity: int = 0
	for descriptor in recipe.aggregated_outputs():
		if str(descriptor.get("item_id", "")) == output_item_id:
			quantity += int(descriptor.get("quantity", 0))
	if quantity != 1:
		failures.append(
			"progression auto-equip requires exactly one declared recipe output for %s, got %d" % [
				output_item_id,
				quantity,
			]
		)
	var definition = _resolve_item(output_item_id, failures)
	if definition != null and definition is ItemDefinition and definition.stack_limit != 1:
		failures.append(
			"progression auto-equip output must be a non-stackable item instance: %s" % output_item_id
		)
	return definition


func _resolve_item(item_content_id: String, failures: Array[String]):
	if _content_registry == null or not _content_registry is ContentRegistry:
		return null
	var resolution: Dictionary = _content_registry.resolve(item_content_id, "item")
	for failure in resolution.get("diagnostics", []):
		failures.append("progression item resolution: %s" % failure)
	var definition = resolution.get("definition", null)
	if definition != null and not definition is ItemDefinition:
		failures.append("progression item must inherit ItemDefinition: %s" % item_content_id)
		return null
	return definition


static func _runtime_state_failures(inventory, equipment_state) -> Array[String]:
	var failures: Array[String] = []
	if inventory == null or not inventory is ItemContainerState:
		failures.append("progression bridge requires ItemContainerState")
	else:
		for failure in inventory.validate_container():
			failures.append("inventory state: %s" % failure)
	if equipment_state == null or not equipment_state is EquipmentHotbarState:
		failures.append("progression bridge requires EquipmentHotbarState")
	else:
		for failure in equipment_state.validate_state():
			failures.append("equipment state: %s" % failure)
	failures.sort()
	return failures


static func _target_failures(
	equipment_state,
	definition,
	target_slot_key: String,
	preferred_hotbar: int
) -> Array[String]:
	var failures: Array[String] = []
	if equipment_state == null or not equipment_state is EquipmentHotbarState:
		return failures
	var rule = equipment_state.slot_rule(target_slot_key)
	if rule == null:
		failures.append("progression target requires known semantic equipment slot: %s" % target_slot_key)
	elif definition != null and definition is ItemDefinition:
		for failure in rule.compatibility_failures(definition):
			failures.append("progression target: %s" % failure)
	if preferred_hotbar < 0 or preferred_hotbar > EquipmentHotbarState.HOTBAR_MAX:
		failures.append("preferred hotbar must be 0 (no selection) or 1..4: %d" % preferred_hotbar)
	elif preferred_hotbar > 0:
		var bound_slot: String = _bound_slot(equipment_state, preferred_hotbar)
		if bound_slot != target_slot_key:
			failures.append(
				"preferred hotbar %d must already bind semantic slot %s, got %s" % [
					preferred_hotbar,
					target_slot_key,
					bound_slot,
				]
			)
	failures.sort()
	return failures


static func _bound_slot(equipment_state, hotbar: int) -> String:
	for descriptor in equipment_state.canonical_snapshot().get("hotbar_bindings", []):
		if int(descriptor.get("hotbar", 0)) == hotbar:
			return str(descriptor.get("slot_key", ""))
	return ""


static func _matching_instance_slots(inventory, item_content_id: String) -> Array[int]:
	var result: Array[int] = []
	if inventory == null or not inventory is ItemContainerState:
		return result
	for slot_index in range(inventory.slot_capacity()):
		var record: Dictionary = inventory.state_at(slot_index)
		if (
			str(record.get("kind", "")) == "instance"
			and str(record.get("state", {}).get("item_id", "")) == item_content_id
		):
			result.append(slot_index)
	return result


static func _new_instance_slot(
	inventory,
	item_content_id: String,
	before_slots: Array[int]
) -> int:
	for slot_index in _matching_instance_slots(inventory, item_content_id):
		if not before_slots.has(slot_index):
			return slot_index
	return -1


static func _semantic_selected(selected: Dictionary) -> Dictionary:
	if selected.is_empty():
		return {}
	return {
		"success": bool(selected.get("success", false)),
		"selection_kind": str(selected.get("selection_kind", "")),
		"hotbar": int(selected.get("hotbar", 0)),
		"slot_key": str(selected.get("slot_key", "")),
		"item_id": str(selected.get("item_id", "")),
		"categories": selected.get("categories", []).duplicate(),
		"capabilities": selected.get("capabilities", []).duplicate(),
		"can_equip": bool(selected.get("can_equip", false)),
		"can_harvest": bool(selected.get("can_harvest", false)),
		"can_deal_damage": bool(selected.get("can_deal_damage", false)),
	}


static func _equip_failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {
		"success": false,
		"diagnostics": diagnostics,
		"equip_attempted": false,
		"equip_succeeded": false,
		"events": [],
		"equip_transaction_fingerprint": "",
		"selected_item": {},
	}


static func _failure(
	stage: String,
	recipe_content_id: String,
	output_item_id: String,
	target_slot_key: String,
	preferred_hotbar: int,
	messages: Array
) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {
		"success": false,
		"stage": stage,
		"diagnostics": diagnostics,
		"recipe_id": recipe_content_id,
		"output_item_id": output_item_id,
		"target_slot_key": target_slot_key,
		"preferred_hotbar": preferred_hotbar,
		"craft_succeeded": false,
		"equip_attempted": false,
		"equip_succeeded": false,
		"selected_item": {},
		"events": [],
		"craft_transaction_fingerprint": "",
		"equip_transaction_fingerprint": "",
	}
