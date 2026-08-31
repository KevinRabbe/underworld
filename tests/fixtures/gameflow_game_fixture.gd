extends Node

var prepared_mode: StringName = &""
var prepared_candidate: Dictionary = {}
var process_ticks: int = 0
var unhandled_cancel_count: int = 0
var save_request_count: int = 0


func prepare_new_game() -> bool:
	if is_inside_tree():
		return false
	prepared_mode = &"new"
	prepared_candidate.clear()
	return true


func prepare_continue(candidate: Dictionary) -> bool:
	if is_inside_tree():
		return false
	prepared_mode = &"continue"
	prepared_candidate = candidate.duplicate(true)
	return true


func _process(_delta: float) -> void:
	process_ticks += 1


func _unhandled_input(event: InputEvent) -> void:
	if event != null and event.is_action_pressed("ui_cancel"):
		unhandled_cancel_count += 1


func build_save_request() -> Dictionary:
	save_request_count += 1
	return {
		"success": true,
		"context": null,
		"delta_store": null,
		"inventory_state": null,
		"equipment_state": null,
		"pending_loot_states": [],
		"resume_position": Vector3(4.0, 8.0, 12.0),
		"diagnostics": [],
	}
