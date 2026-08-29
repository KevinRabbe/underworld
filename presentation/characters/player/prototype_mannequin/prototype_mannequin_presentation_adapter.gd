extends "res://presentation/characters/runtime/humanoid_character_presentation_adapter.gd"
class_name UnderworldPrototypeMannequinPresentationAdapter


func _init(mannequin = null) -> void:
	super(mannequin)


func presentation_kind() -> StringName:
	return &"prototype_mannequin"
