extends RefCounted
class_name UnderworldVoxelAnimationRuntimeFactory

const CharacterAnimationRuntimeFactory := preload("res://presentation/characters/runtime/character_animation_runtime_factory.gd")
const VoxelAdapter := preload("res://presentation/characters/voxel/voxel_character_presentation_adapter.gd")

const ANIMATION_SET_ID := "animation_set.humanoid.prototype"
const CONTENT_PATHS: Array[String] = [
	"res://content/characters/animation_sets/prototype_humanoid_animation_set.tres",
	"res://content/characters/rig_profiles/prototype_humanoid_rig_profile.tres",
]


static func build(character) -> Dictionary:
	return CharacterAnimationRuntimeFactory.build(ANIMATION_SET_ID, CONTENT_PATHS, VoxelAdapter.new(character))
