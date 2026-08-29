extends RefCounted

const ContentId := preload("res://core/content/identity/content_id.gd")
const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const InventoryTransactionPlan := preload("res://gameplay/items/inventory/inventory_transaction_plan.gd")
const InventoryTransactionService := preload("res://gameplay/items/inventory/inventory_transaction_service.gd")
const RecipeDefinition := preload("res://gameplay/crafting/definitions/recipe_definition.gd")
const CraftingContext := preload("res://gameplay/crafting/runtime/crafting_context.gd")

var _content_registry
var _content_validation_result: Dictionary = {}
var _validated_ids: Dictionary = {}
var _transaction_service
var _configuration_failures: Array[String] = []


func configure(
	content_registry,
	content_validation_result: Dictionary,
	transaction_service = null
) -> RefCounted:
	_content_registry = content_registry
	_content_validation_result = content_validation_result.duplicate(true)
	_validated_ids.clear()
	_configuration_failures.clear()

	if content_registry == null or not content_registry is ContentRegistry:
		_configuration_failures.append("crafting service requires accepted ContentRegistry")
	elif not content_registry.is_valid():
		for failure in content_registry.diagnostics():
			_configuration_failures.append("content registry: %s" % failure)

	if not bool(content_validation_result.get("success", false)):
		_configuration_failures.append("crafting service requires successful CONTENT-005 validation evidence")
	for raw_id in content_validation_result.get("validated_definition_ids", []):
		_validated_ids[str(raw_id)] = true

	if transaction_service == null:
		_transaction_service = InventoryTransactionService.new()
	elif transaction_service is InventoryTransactionService:
		_transaction_service = transaction_service
	else:
		_transaction_service = null
		_configuration_failures.append("crafting service requires InventoryTransactionService")
	_configuration_failures.sort()
	return self


func build_plan(
	recipe_content_id: String,
	context,
	container,
	container_key: String = "player"
) -> Dictionary:
	var failures: Array[String] = _configuration_failures.duplicate()
	for failure in ContentId.validate(recipe_content_id):
		failures.append("craft recipe id: %s" % failure)
	if ContentId.is_valid(recipe_content_id) and ContentId.family_of(recipe_content_id) != "recipe":
		failures.append("craft recipe id must use recipe.* family: %s" % recipe_content_id)
	if not _validated_ids.has(recipe_content_id):
		failures.append("recipe lacks successful CONTENT-005 validation evidence: %s" % recipe_content_id)
	if context == null or not context is CraftingContext:
		failures.append("crafting requires CraftingContext")
	else:
		failures.append_array(context.validate_context())
	if container == null or not container is ItemContainerState:
		failures.append("crafting target must be ItemContainerState")
	if container_key.strip_edges().is_empty():
		failures.append("crafting container key must be non-empty")
	if not failures.is_empty():
		return _failure(recipe_content_id, failures)

	var recipe_resolution: Dictionary = _content_registry.resolve(recipe_content_id, "recipe")
	for failure in recipe_resolution.get("diagnostics", []):
		failures.append("recipe resolution: %s" % failure)
	var recipe = recipe_resolution.get("definition", null)
	if recipe == null or not recipe is RecipeDefinition:
		failures.append("resolved recipe must inherit RecipeDefinition: %s" % recipe_content_id)
	if not failures.is_empty():
		return _failure(recipe_content_id, failures)

	for capability_id in recipe.required_context_capabilities:
		if not context.has_capability(capability_id):
			failures.append("crafting context lacks required capability: %s" % capability_id)
	if not failures.is_empty():
		return _failure(recipe_content_id, failures)

	var plan = InventoryTransactionPlan.new()
	plan.bind_container(container_key, container)
	for descriptor in recipe.aggregated_ingredients():
		var item_definition = _resolve_item_definition(descriptor, failures)
		if item_definition == null:
			continue
		if item_definition.stack_limit <= 1:
			failures.append(
				"M3 crafting ingredient must be stackable item content: %s" % item_definition.content_id
			)
			continue
		plan.remove_stack(
			container_key,
			item_definition,
			int(descriptor.get("quantity", 0))
		)

	for descriptor in recipe.aggregated_outputs():
		var item_definition = _resolve_item_definition(descriptor, failures)
		if item_definition == null:
			continue
		var quantity: int = int(descriptor.get("quantity", 0))
		if item_definition.stack_limit > 1:
			plan.add_stack(container_key, item_definition, quantity)
		else:
			for _index in range(quantity):
				plan.add_instance(container_key, item_definition, {})

	if not failures.is_empty():
		return _failure(recipe_content_id, failures)
	return {
		"success": true,
		"recipe_id": recipe_content_id,
		"diagnostics": [],
		"plan": plan,
		"plan_descriptor": plan.canonical_descriptor(),
		"context": context.canonical_descriptor(),
	}


func craft(
	recipe_content_id: String,
	context,
	container,
	container_key: String = "player"
) -> Dictionary:
	var built: Dictionary = build_plan(recipe_content_id, context, container, container_key)
	if not bool(built.get("success", false)):
		return built
	var result: Dictionary = _transaction_service.commit(built.get("plan"))
	var diagnostics: Array = result.get("diagnostics", []).duplicate()
	diagnostics.sort()
	return {
		"success": bool(result.get("success", false)),
		"recipe_id": recipe_content_id,
		"diagnostics": diagnostics,
		"transaction_fingerprint": str(result.get("transaction_fingerprint", "")),
		"operation_count": int(result.get("operation_count", 0)),
		"events": result.get("events", []).duplicate(true),
		"plan_descriptor": built.get("plan_descriptor", {}).duplicate(true),
	}


func _resolve_item_definition(descriptor: Dictionary, failures: Array[String]):
	var item_id: String = str(descriptor.get("item_id", ""))
	var resolved: Dictionary = _content_registry.resolve(item_id, "item")
	for failure in resolved.get("diagnostics", []):
		failures.append("craft item resolution %s: %s" % [item_id, failure])
	var definition = resolved.get("definition", null)
	if definition != null and not definition is ItemDefinition:
		failures.append("craft item target must inherit ItemDefinition: %s" % item_id)
		return null
	return definition


static func _failure(recipe_content_id: String, failures: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for failure in failures:
		diagnostics.append(str(failure))
	diagnostics.sort()
	return {
		"success": false,
		"recipe_id": recipe_content_id,
		"diagnostics": diagnostics,
		"transaction_fingerprint": "",
		"operation_count": 0,
		"events": [],
	}
