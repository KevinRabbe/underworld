extends "res://gameplay/creatures/underworld/burrower/burrower.gd"

var attack_path_clear: bool = true
var attack_path_query_calls: int = 0


func set_attack_path_clear(value: bool) -> void:
	attack_path_clear = value


func _attack_path_is_clear() -> bool:
	attack_path_query_calls += 1
	return attack_path_clear
