extends RefCounted
class_name UnderworldCharacterPresentationProvider


func create_presentation():
	return null


func build_animation_runtime(_presentation) -> Dictionary:
	return {"success": false, "diagnostics": ["character presentation provider has no animation runtime"]}


func realize_held_item(_presentation, _attachment_root: Node3D, _tool_id: String) -> bool:
	return false
