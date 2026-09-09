extends RefCounted

const InventoryStateCodec := preload("res://gameplay/items/inventory/inventory_state_codec.gd")
const InventoryTransactionPlan := preload("res://gameplay/items/inventory/inventory_transaction_plan.gd")
const InventoryTransactionCheckpoint := preload("res://gameplay/items/inventory/inventory_transaction_checkpoint.gd")
const InventoryTransactionPreflight := preload("res://gameplay/items/inventory/transactions/inventory_transaction_preflight.gd")

var _test_commit_failure_index: int = -1
var _test_rollback_failure_container_key: String = ""


func set_test_commit_failure_index(operation_index: int) -> void:
	_test_commit_failure_index = operation_index


func set_test_rollback_failure_container_key(container_key: String) -> void:
	_test_rollback_failure_container_key = container_key


func execute(preflight: Dictionary) -> Dictionary:
	if not bool(preflight.get("success", false)):
		return preflight

	var containers: Dictionary = preflight.get("_containers", {})
	var baselines: Dictionary = preflight.get("_baselines", {})
	var container_keys: Array[String] = []
	for raw_key in containers.keys():
		container_keys.append(str(raw_key))
	container_keys.sort()
	for container_key in container_keys:
		var container = containers[container_key]
		if container.canonical_json() != str(baselines.get(container_key, "")):
			return _failure(
				["transaction participant changed after preflight: %s" % container_key],
				str(preflight.get("transaction_fingerprint", ""))
			)

	var checkpoints: Dictionary = {}
	for container_key in container_keys:
		var checkpoint: Dictionary = InventoryTransactionCheckpoint.capture(containers[container_key])
		if checkpoint.is_empty():
			return _failure(
				["transaction could not capture rollback checkpoint for %s" % container_key],
				str(preflight.get("transaction_fingerprint", ""))
			)
		checkpoints[container_key] = checkpoint

	var events: Array = []
	var ordered_operations: Array = preflight.get("_ordered_operations", [])
	for operation_index in range(ordered_operations.size()):
		var operation: Dictionary = ordered_operations[operation_index]
		var container_key: String = str(operation.get("container", ""))
		var container = containers.get(container_key, null)
		var result: Dictionary
		if operation_index == _test_commit_failure_index:
			result = {
				"success": false,
				"diagnostics": ["injected deterministic transaction commit failure"],
			}
		else:
			result = _commit_operation(container, operation)
		if not bool(result.get("success", false)):
			var diagnostics: Array[String] = [
				"validated transaction commit failed unexpectedly at %s: %s" % [
					_operation_label(operation),
					str(result.get("diagnostics", [])),
				]
			]
			return _rollback_after_commit_failure(
				containers,
				checkpoints,
				diagnostics,
				str(preflight.get("transaction_fingerprint", ""))
			)
		events.append(_event_descriptor(operation, result))

	return {
		"success": true,
		"diagnostics": [],
		"transaction_fingerprint": str(preflight.get("transaction_fingerprint", "")),
		"operation_count": ordered_operations.size(),
		"events": events,
	}


func _rollback_after_commit_failure(
	containers: Dictionary,
	checkpoints: Dictionary,
	commit_diagnostics: Array[String],
	fingerprint: String
) -> Dictionary:
	var rollback_failures: Array[String] = []
	var container_keys: Array[String] = []
	for raw_key in containers.keys():
		container_keys.append(str(raw_key))
	container_keys.sort()
	for container_key in container_keys:
		if container_key == _test_rollback_failure_container_key:
			rollback_failures.append("%s: injected deterministic rollback failure" % container_key)
			continue
		var container = containers.get(container_key, null)
		var checkpoint_variant = checkpoints.get(container_key, null)
		if not checkpoint_variant is Dictionary:
			rollback_failures.append("%s: rollback checkpoint is missing" % container_key)
			continue
		for failure in InventoryTransactionCheckpoint.restore(container, checkpoint_variant):
			rollback_failures.append("%s: %s" % [container_key, failure])

	var result_diagnostics: Array[String] = commit_diagnostics.duplicate()
	if not rollback_failures.is_empty():
		rollback_failures.sort()
		for failure in rollback_failures:
			result_diagnostics.append(
				"HARD TRANSACTION ROLLBACK INVARIANT FAILURE — %s" % failure
			)
	var result: Dictionary = _failure(result_diagnostics, fingerprint)
	result["rollback_restored"] = rollback_failures.is_empty()
	return result


static func _commit_operation(container, operation: Dictionary) -> Dictionary:
	var definition = operation.get("definition", null)
	match str(operation.get("kind", "")):
		InventoryTransactionPlan.KIND_REMOVE_STACK:
			return container.remove_stack(
				str(definition.content_id),
				int(operation.get("quantity", 0)),
				operation.get("state", {})
			)
		InventoryTransactionPlan.KIND_REMOVE_INSTANCE:
			return container.remove_instance_at(int(operation.get("slot", -1)))
		InventoryTransactionPlan.KIND_ADD_STACK:
			return container.add_stack(
				definition,
				int(operation.get("quantity", 0)),
				operation.get("state", {})
			)
		InventoryTransactionPlan.KIND_ADD_INSTANCE:
			return container.add_instance(definition, operation.get("state", {}))
		_:
			return {"success": false, "diagnostics": ["unknown transaction operation kind"]}


static func _event_descriptor(operation: Dictionary, result: Dictionary) -> Dictionary:
	return {
		"operation": InventoryTransactionPreflight.operation_descriptor(operation),
		"result": InventoryStateCodec.canonicalize(result),
	}


static func _operation_label(operation: Dictionary) -> String:
	var descriptor: Dictionary = InventoryTransactionPreflight.operation_descriptor(operation)
	return "%s[%s:%s]" % [
		descriptor.get("kind", ""),
		descriptor.get("container", ""),
		descriptor.get("item_id", ""),
	]


static func _failure(messages: Array, fingerprint: String = "") -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {
		"success": false,
		"diagnostics": diagnostics,
		"transaction_fingerprint": fingerprint,
		"operation_count": 0,
		"events": [],
	}
