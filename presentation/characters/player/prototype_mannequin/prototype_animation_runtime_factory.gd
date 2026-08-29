extends RefCounted

const CharacterAnimationRuntimeFactory := preload("res://presentation/characters/runtime/character_animation_runtime_factory.gd")
const PrototypeMannequinPresentationAdapter := preload("res://presentation/characters/player/prototype_mannequin/prototype_mannequin_presentation_adapter.gd")

const ANIMATION_SET_ID := "animation_set.humanoid.prototype"
const CONTENT_PATHS: Array[String] = [
	"res://content/characters/animation_sets/prototype_humanoid_animation_set.tres",
	"res://content/characters/rig_profiles/prototype_humanoid_rig_profile.tres",
]


static func build(mannequin) -> Dictionary:
	return CharacterAnimationRuntimeFactory.build(ANIMATION_SET_ID, CONTENT_PATHS, PrototypeMannequinPresentationAdapter.new(mannequin))
