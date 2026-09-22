extends "res://gameplay/creatures/underworld/burrower/burrower.gd"

func get_display_name() -> String:
	return "Boar"


func _build_placeholder_visual() -> void:
	super._build_placeholder_visual()
	if body_material != null:
		body_material.albedo_color = Color(0.30, 0.18, 0.10)
