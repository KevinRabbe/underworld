extends "res://core/content/registry/content_definition.gd"

const ContentReference := preload("res://core/content/references/content_reference.gd")
const RecipeItemAmount := preload("res://gameplay/crafting/definitions/recipe_item_amount.gd")

const RECIPE_FAMILY := "recipe"

@export var ingredients: Array[Resource] = []
@export var outputs: Array[Resource] = []
@export var required_context_capabilities: Array[String] = []


func configure_recipe(
	p_content_id: String,
	p_ingredients: Array = [],
	p_outputs: Array = [],
	p_required_context_capabilities: Array = [],
	p_schema_revision: int = 1
) -> Resource:
	configure(p_content_id, RECIPE_FAMILY, p_schema_revision)
	ingredients.clear()
	outputs.clear()
	required_context_capabilities.clear()
	for candidate in p_ingredients:
		if candidate is Resource:
			ingredients.append(candidate)
	for candidate in p_outputs:
		if candidate is Resource:
			outputs.append(candidate)
	for capability_id in p_required_context_capabilities:
		required_context_capabilities.append(str(capability_id))
	return self


func validation_references() -> Array:
	var result: Array = []
	var canonical_inputs: Array[Dictionary] = aggregated_ingredients()
	for index in range(canonical_inputs.size()):
		var descriptor: Dictionary = canonical_inputs[index]
		result.append(ContentReference.new(
			content_id,
			"ingredient.%03d" % index,
			str(descriptor.get("item_id", "")),
			"item",
			true
		))
	var canonical_outputs: Array[Dictionary] = aggregated_outputs()
	for index in range(canonical_outputs.size()):
		var descriptor: Dictionary = canonical_outputs[index]
		result.append(ContentReference.new(
			content_id,
			"output.%03d" % index,
			str(descriptor.get("item_id", "")),
			"item",
			true
		))
	return result


func validate_definition() -> Array[String]:
	var failures: Array[String] = super.validate_definition()
	if definition_family != RECIPE_FAMILY:
		failures.append("recipe definition family must be '%s': %s" % [
			RECIPE_FAMILY,
			definition_family,
		])
	if ingredients.is_empty():
		failures.append("recipe must declare at least one ingredient: %s" % content_id)
	if outputs.is_empty():
		failures.append("recipe must declare at least one output: %s" % content_id)
	_validate_amounts(ingredients, "ingredient", failures)
	_validate_amounts(outputs, "output", failures)

	var seen_capabilities: Dictionary = {}
	for capability_id in required_context_capabilities:
		for failure in SchemaId.validate_capability(capability_id):
			failures.append("required crafting context capability: %s" % failure)
		if seen_capabilities.has(capability_id):
			failures.append("duplicate required crafting context capability: %s" % capability_id)
		seen_capabilities[capability_id] = true
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	var descriptor: Dictionary = super.canonical_descriptor()
	descriptor["ingredients"] = aggregated_ingredients()
	descriptor["outputs"] = aggregated_outputs()
	var capabilities: Array[String] = []
	capabilities.append_array(required_context_capabilities)
	capabilities.sort()
	descriptor["required_context_capabilities"] = capabilities
	return descriptor


func aggregated_ingredients() -> Array[Dictionary]:
	return _aggregate_amounts(ingredients)


func aggregated_outputs() -> Array[Dictionary]:
	return _aggregate_amounts(outputs)


func referenced_item_ids() -> Array[String]:
	var ids: Array[String] = []
	for descriptor in aggregated_ingredients() + aggregated_outputs():
		var item_id: String = str(descriptor.get("item_id", ""))
		if not ids.has(item_id):
			ids.append(item_id)
	ids.sort()
	return ids


static func _validate_amounts(
	amounts: Array[Resource],
	label: String,
	failures: Array[String]
) -> void:
	for index in range(amounts.size()):
		var candidate = amounts[index]
		if candidate == null or not candidate is RecipeItemAmount:
			failures.append("recipe %s %d must inherit RecipeItemAmount" % [label, index])
			continue
		for failure in candidate.validate_amount("recipe %s %d" % [label, index]):
			failures.append(failure)


static func _aggregate_amounts(amounts: Array[Resource]) -> Array[Dictionary]:
	var totals: Dictionary = {}
	for candidate in amounts:
		if candidate == null or not candidate is RecipeItemAmount:
			continue
		var item_id: String = str(candidate.item_content_id)
		totals[item_id] = int(totals.get(item_id, 0)) + int(candidate.quantity)
	var ids: Array[String] = []
	for raw_id in totals.keys():
		ids.append(str(raw_id))
	ids.sort()
	var result: Array[Dictionary] = []
	for item_id in ids:
		result.append({
			"item_id": item_id,
			"quantity": int(totals[item_id]),
		})
	return result
