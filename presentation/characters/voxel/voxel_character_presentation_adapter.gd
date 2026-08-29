extends "res://presentation/characters/runtime/humanoid_character_presentation_adapter.gd"
class_name UnderworldVoxelCharacterPresentationAdapter


func _init(character = null) -> void:
	super(character)


func presentation_kind() -> StringName:
	return &"voxel_character"


func update_locomotion(_binding: String, context: Dictionary) -> void:
	if presentation == null:
		return
	presentation.update_voxel_visual(
		float(context.get("delta", 0.0)),
		context.get("local_velocity", Vector3.ZERO),
		float(context.get("vertical_velocity", 0.0)),
		bool(context.get("grounded", false)),
		bool(context.get("sprinting", false))
	)


func play_animation(binding: String, parameters: Dictionary = {}) -> void:
	if presentation != null and str(parameters.get("presentation_action", "")) == "death":
		presentation.play_death()
		return
	if presentation != null and binding == "prototype.attack.light_01" and str(parameters.get("presentation_action", "")) == "tool_use":
		presentation.play_tool_use(float(parameters.get("duration", 0.42)))
		return
	super.play_animation(binding, parameters)
