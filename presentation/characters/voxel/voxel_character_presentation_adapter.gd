extends "res://presentation/characters/player/prototype_mannequin/prototype_mannequin_presentation_adapter.gd"
class_name UnderworldVoxelCharacterPresentationAdapter


func _init(character = null) -> void:
	super(character)


func presentation_kind() -> StringName:
	return &"voxel_character"


func play_animation(binding: String, parameters: Dictionary = {}) -> void:
	if mannequin != null and binding == "prototype.attack.light_01" and str(parameters.get("presentation_action", "")) == "tool_use":
		mannequin.play_tool_use(float(parameters.get("duration", 0.42)))
		return
	super.play_animation(binding, parameters)
