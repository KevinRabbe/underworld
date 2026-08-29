extends RefCounted
class_name UnderworldVoxelAnimationRuntimeFactory

const PrototypeRuntimeFactory := preload("res://presentation/characters/player/prototype_mannequin/prototype_animation_runtime_factory.gd")
const VoxelAdapter := preload("res://presentation/characters/voxel/voxel_character_presentation_adapter.gd")


static func build(character) -> Dictionary:
	return PrototypeRuntimeFactory.build(character, VoxelAdapter.new(character))
