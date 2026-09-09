extends RefCounted

const InventoryTransactionPreflight := preload("res://gameplay/items/inventory/transactions/inventory_transaction_preflight.gd")
const InventoryTransactionCommitExecutor := preload("res://gameplay/items/inventory/transactions/inventory_transaction_commit_executor.gd")

var _preflight = InventoryTransactionPreflight.new()
var _commit_executor = InventoryTransactionCommitExecutor.new()


func _set_test_commit_failure_index(operation_index: int) -> void:
	_commit_executor.set_test_commit_failure_index(operation_index)


func _set_test_rollback_failure_container_key(container_key: String) -> void:
	_commit_executor.set_test_rollback_failure_container_key(container_key)


func validate(plan) -> Dictionary:
	var preflight: Dictionary = _preflight.analyze(plan)
	return {
		"success": bool(preflight.get("success", false)),
		"diagnostics": preflight.get("diagnostics", []).duplicate(),
		"transaction_fingerprint": str(preflight.get("transaction_fingerprint", "")),
		"operation_count": int(preflight.get("operation_count", 0)),
		"events": [],
	}


func commit(plan) -> Dictionary:
	var preflight: Dictionary = _preflight.analyze(plan)
	if not bool(preflight.get("success", false)):
		return preflight
	return _commit_executor.execute(preflight)
