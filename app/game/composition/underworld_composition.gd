extends RefCounted

const UnderworldRuntimeControllerScript := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const CavePresentationControllerScript := preload("res://presentation/world/caves/cave_presentation_controller.gd")
const PrototypeCavePresentationCatalog := preload("res://content/presentation/caves/prototype_cave_presentation_catalog.tres")


static func compose(root: Node3D, session_world_context, player) -> Dictionary:
	var runtime = UnderworldRuntimeControllerScript.new()
	runtime.name = "UnderworldRuntime"
	root.add_child(runtime)
	if session_world_context == null:
		return {
			"success": false,
			"underworld_runtime": runtime,
			"cave_presentation": null,
			"diagnostics": ["Underworld runtime requires retained exact session root context"],
			"presentation_diagnostics": [],
		}

	runtime.configure(
		str(session_world_context.world_id),
		str(session_world_context.generator_manifest_id),
		player
	)

	var cave_presentation = CavePresentationControllerScript.new()
	cave_presentation.name = "CavePresentation"
	root.add_child(cave_presentation)
	var presentation_failures: Array[String] = cave_presentation.configure(
		runtime,
		PrototypeCavePresentationCatalog
	)
	return {
		"success": true,
		"underworld_runtime": runtime,
		"cave_presentation": cave_presentation,
		"diagnostics": [],
		"presentation_diagnostics": presentation_failures,
	}
