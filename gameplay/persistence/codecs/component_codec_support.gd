extends RefCounted

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const InventoryStateCodec := preload("res://gameplay/items/inventory/inventory_state_codec.gd")
const LootProfileDefinition := preload("res://gameplay/loot/definitions/loot_profile_definition.gd")

const ITEM_FAMILY := "item"
const LOOT_PROFILE_FAMILY := "loot_profile"


static func require_snapshot(
	snapshot: Variant,
	expected_schema: String,
	label: String,
	expected_keys: Array,
	failures: Array[String]
) -> Dictionary:
	if not snapshot is Dictionary:
		failures.append("%s snapshot must be Dictionary" % label)
		return {}
	for failure in InventoryStateCodec.validate_state(snapshot, "%s_snapshot" % label):
		failures.append(failure)
	validate_json_safe(snapshot, "%s_snapshot" % label, failures)
	var source: Dictionary = snapshot
	validate_exact_keys(source, expected_keys, "%s snapshot" % label, failures)
	var raw_schema = source.get("schema", null)
	if typeof(raw_schema) != TYPE_STRING:
		failures.append("%s snapshot schema must be String" % label)
	elif str(raw_schema) != expected_schema:
		failures.append("%s snapshot schema mismatch: %s" % [label, str(raw_schema)])
	return source


static func validate_exact_keys(
	source: Dictionary,
	expected_keys: Array,
	label: String,
	failures: Array[String]
) -> void:
	for expected_key in expected_keys:
		if not source.has(expected_key):
			failures.append("%s missing structural field: %s" % [label, str(expected_key)])
	for raw_key in source.keys():
		var key: String = str(raw_key)
		if not expected_keys.has(key):
			failures.append("%s contains unknown structural field: %s" % [label, key])


static func validate_json_safe(value: Variant, path: String, failures: Array[String]) -> void:
	match typeof(value):
		TYPE_FLOAT:
			var number: float = float(value)
			if is_nan(number) or is_inf(number):
				failures.append("%s contains non-finite float" % path)
		TYPE_ARRAY:
			var index: int = 0
			for entry in value:
				validate_json_safe(entry, "%s[%d]" % [path, index], failures)
				index += 1
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			for raw_key in dictionary.keys():
				if typeof(raw_key) != TYPE_STRING:
					continue
				validate_json_safe(
					dictionary[raw_key],
					"%s.%s" % [path, str(raw_key)],
					failures
				)


static func validate_registry(content_registry, failures: Array[String]) -> void:
	if content_registry == null or not content_registry is ContentRegistry:
		failures.append("persistence codec requires ContentRegistry")
		return
	if not content_registry.is_valid():
		for diagnostic in content_registry.diagnostics():
			failures.append("content registry: %s" % diagnostic)


static func resolve_item(
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


static func resolve_loot_profile(
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


static func definition_contract(definition) -> String:
	return InventoryStateCodec.canonical_json(definition.canonical_descriptor())


static func encoded(snapshot: Dictionary, label: String) -> Dictionary:
	var failures: Array[String] = []
	for failure in InventoryStateCodec.validate_state(snapshot, label):
		failures.append(failure)
	validate_json_safe(snapshot, label, failures)
	if not failures.is_empty():
		return failure(failures)
	var canonical_snapshot: Dictionary = InventoryStateCodec.canonicalize(snapshot)
	var canonical_json: String = InventoryStateCodec.canonical_json(canonical_snapshot)
	return success({
		"snapshot": canonical_snapshot,
		"canonical_json": canonical_json,
		"fingerprint": canonical_json.sha256_text(),
	})


static func failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {"success": false, "diagnostics": diagnostics}


static func success(extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"success": true, "diagnostics": []}
	for key in extra.keys():
		result[key] = extra[key]
	return result
