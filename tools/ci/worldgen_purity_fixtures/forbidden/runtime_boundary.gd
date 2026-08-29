extends Node3D

const Player := preload("res://gameplay/player/player.gd")


func attach_runtime_state() -> Variant:
	var mesh := MeshInstance3D.new()
	add_child(mesh)
	get_tree().process_frame
	return $RuntimeRoot
