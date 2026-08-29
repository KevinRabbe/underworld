extends "res://presentation/characters/runtime/character_presentation_provider.gd"
class_name UnderworldVoxelCharacterPresentationProvider

const VoxelCharacter := preload("res://presentation/characters/voxel/voxel_character_presentation.gd")
const VoxelAnimationRuntimeFactory := preload("res://presentation/characters/voxel/voxel_animation_runtime_factory.gd")


func create_presentation():
	var character = VoxelCharacter.new()
	character.name = "VoxelSurvivor"
	return character


func build_animation_runtime(presentation) -> Dictionary:
	return VoxelAnimationRuntimeFactory.build(presentation)


func realize_held_item(presentation, _attachment_root: Node3D, tool_id: String) -> bool:
	if presentation == null or not presentation.has_method("set_held_item"):
		return false
	presentation.set_held_item(tool_id)
	return true
