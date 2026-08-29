extends "res://core/content/registry/content_definition.gd"

const ContentReference := preload("res://core/content/references/content_reference.gd")
const ResourceYieldEntry := preload("res://gameplay/resources/definitions/resource_yield_entry.gd")

const NODE_FAMILY := "resource_node"
const DEPOSIT_FAMILY := "resource_deposit"
const ALLOWED_FAMILIES := [NODE_FAMILY, DEPOSIT_FAMILY]

@export var capacity_units: float = 1.0
@export var yield_entries: Array[Resource] = []
@export var presentation_content_id: String = ""
@export var presentation_expected_family: String = "archetype"


func configure_resource(
	p_content_id: String,
	p_definition_family: String,
	p_capacity_units: float = 1.0,
	p_schema_revision: int = 1
) -> Resource:
	configure(p_content_id, p_definition_family, p_schema_revision)
	capacity_units = p_capacity_units
	return self


func configure_yields(entries: Array = []) -> Resource:
	yield_entries.clear()
	for entry in entries:
		yield_entries.append(entry)
	return self


func configure_presentation(
	p_content_id: String,
	p_expected_family: String = "archetype"
) -> Resource:
	presentation_content_id = p_content_id
	presentation_expected_family = p_expected_family
	return self


func validation_references() -> Array:
	var references: Array = []
	for index in range(yield_entries.size()):
		var entry = yield_entries[index]
		if entry != null and entry is ResourceYieldEntry:
			references.append(entry.content_reference(content_id, index))
	if not presentation_content_id.is_empty():
		references.append(ContentReference.new(
			content_id,
			"presentation.archetype",
			presentation_content_id,
			presentation_expected_family,
			true
		))
	return references


func validate_definition() -> Array[String]:
	var failures: Array[String] = super.validate_definition()
	if not ALLOWED_FAMILIES.has(definition_family):
		failures.append("resource definition family must be resource_node or resource_deposit: %s" % definition_family)
	if capacity_units <= 0.0:
		failures.append("resource capacity_units must be > 0 for %s" % content_id)
	if yield_entries.is_empty():
		failures.append("resource definition must declare at least one item yield: %s" % content_id)

	var yielded_items: Dictionary = {}
	for index in range(yield_entries.size()):
		var entry = yield_entries[index]
		if entry == null or not entry is ResourceYieldEntry:
			failures.append("resource yield entry %d must be ResourceYieldEntry" % index)
			continue
		for failure in entry.validate_yield():
			failures.append("yield %d: %s" % [index, failure])
		if yielded_items.has(entry.item_content_id):
			failures.append("resource definition declares duplicate item yield: %s" % entry.item_content_id)
		yielded_items[entry.item_content_id] = true

	if not presentation_content_id.is_empty():
		for failure in ContentId.validate(presentation_content_id):
			failures.append("presentation content id: %s" % failure)
		for failure in ContentId.validate_family(presentation_expected_family):
			failures.append("presentation expected family: %s" % failure)
	failures.sort()
	return failures


func canonical_descriptor() -> Dictionary:
	var descriptor: Dictionary = super.canonical_descriptor()
	descriptor["capacity_units"] = capacity_units
	var yields: Array[Dictionary] = []
	for entry in yield_entries:
		if entry == null or not entry is ResourceYieldEntry:
			yields.append({"invalid": true})
		else:
			yields.append(entry.canonical_descriptor())
	yields.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("item_content_id", "")) < str(b.get("item_content_id", ""))
	)
	descriptor["yield_entries"] = yields
	descriptor["presentation_content_id"] = presentation_content_id
	descriptor["presentation_expected_family"] = presentation_expected_family
	return descriptor
