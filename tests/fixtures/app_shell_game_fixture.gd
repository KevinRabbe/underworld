extends Node

@export var reject_new_preparation: bool = false
@export var reject_continue_preparation: bool = false

var prepared_mode: StringName = &""
var prepared_candidate: Dictionary = {}
var gameplay_input_gate: Node = null
var gate_configured_inside_tree: bool = false


func configure_gameplay_input_gate(gate: Node) -> bool:
	gate_configured_inside_tree = is_inside_tree()
	if gate_configured_inside_tree or gameplay_input_gate != null:
		return false
	if gate == null or not is_instance_valid(gate) or not gate.has_method("allows_player_input"):
		return false
	gameplay_input_gate = gate
	return true


func prepare_new_game() -> bool:
	if is_inside_tree() or gameplay_input_gate == null or reject_new_preparation:
		return false
	prepared_mode = &"new"
	prepared_candidate.clear()
	return true


func prepare_continue(candidate: Dictionary) -> bool:
	if is_inside_tree() or gameplay_input_gate == null or reject_continue_preparation:
		return false
	prepared_mode = &"continue"
	prepared_candidate = candidate.duplicate(true)
	return true
