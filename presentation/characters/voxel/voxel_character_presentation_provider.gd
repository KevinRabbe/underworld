extends "res://presentation/characters/runtime/character_presentation_provider.gd"
class_name UnderworldVoxelCharacterPresentationProvider

const VoxelCharacter := preload("res://presentation/characters/voxel/voxel_character_presentation.gd")
const VoxelAnimationRuntimeFactory := preload("res://presentation/characters/voxel/voxel_animation_runtime_factory.gd")
const HELD_ITEM_FALLBACK_MODE: StringName = &"hidden"

var character_definition: Resource
var _last_held_item_diagnostic: String = ""


func _init(definition: Resource = null) -> void:
	character_definition = definition


func create_presentation():
	var character = VoxelCharacter.new(character_definition)
	character.name = "VoxelSurvivor"
	return character


func build_animation_runtime(presentation) -> Dictionary:
	return VoxelAnimationRuntimeFactory.build(presentation)


func realize_held_item(presentation, attachment_root: Node3D, tool_id: String) -> bool:
	_last_held_item_diagnostic = ""
	if presentation == null or not presentation.has_method("set_held_item"):
		_last_held_item_diagnostic = "held-item presentation is unavailable"
		return false
	if not presentation.has_method("get_tool_visual_root") or attachment_root != presentation.get_tool_visual_root():
		_last_held_item_diagnostic = "held-item presentation requires the semantic hand attachment root"
		return false
	if presentation.set_held_item(tool_id, attachment_root):
		return true

	# Unsupported gameplay equipment must never be guessed into a concrete axe,
	# pickaxe, sword, or other tool. Normalize presentation only to the explicit
	# hidden/hands fallback; the Player's gameplay equipment identity is untouched.
	presentation.set_held_item("hands", attachment_root)
	_last_held_item_diagnostic = "unsupported held-item presentation hidden: %s" % tool_id
	return false


func held_item_fallback_mode() -> StringName:
	return HELD_ITEM_FALLBACK_MODE


func last_held_item_diagnostic() -> String:
	return _last_held_item_diagnostic
