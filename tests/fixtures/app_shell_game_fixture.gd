extends Node

@export var reject_new_preparation: bool = false
@export var reject_continue_preparation: bool = false

var prepared_mode: StringName = &""
var prepared_candidate: Dictionary = {}


func prepare_new_game() -> bool:
	if is_inside_tree() or reject_new_preparation:
		return false
	prepared_mode = &"new"
	prepared_candidate.clear()
	return true


func prepare_continue(candidate: Dictionary) -> bool:
	if is_inside_tree() or reject_continue_preparation:
		return false
	prepared_mode = &"continue"
	prepared_candidate = candidate.duplicate(true)
	return true
