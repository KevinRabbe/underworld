extends Node
class_name UnderworldCavePresentationController

const CatalogScript := preload("res://presentation/world/caves/cave_presentation_catalog.gd")
const ContextBuilder := preload("res://presentation/world/caves/cave_presentation_context.gd")
const Realizer := preload("res://presentation/world/caves/cave_presentation_realizer.gd")

var runtime_controller
var catalog
var biome_id: String = ""
var last_diagnostics: Array[String] = []


func configure(runtime_controller_value, catalog_value, biome_id_value: String = "") -> Array[String]:
	last_diagnostics.clear()
	runtime_controller = runtime_controller_value
	catalog = catalog_value
	biome_id = biome_id_value
	if catalog == null or not catalog is CatalogScript:
		last_diagnostics.append("CavePresentationCatalog is required")
		return last_diagnostics.duplicate()
	last_diagnostics.append_array(catalog.validate_catalog())
	if not last_diagnostics.is_empty():
		return last_diagnostics.duplicate()

	if runtime_controller != null:
		if runtime_controller.has_method("set_cave_material"):
			var default_result: Dictionary = catalog.resolve(ContextBuilder.default_context(biome_id))
			var material_result: Dictionary = Realizer.build_material(default_result.get("profile"))
			if material_result.get("diagnostics", []).is_empty():
				runtime_controller.set_cave_material(material_result.get("material"))
			else:
				last_diagnostics.append_array(material_result.get("diagnostics", []))
		if runtime_controller.has_signal("cell_attached"):
			var callback := Callable(self, "_on_cell_attached")
			if not runtime_controller.is_connected("cell_attached", callback):
				runtime_controller.connect("cell_attached", callback)
		var existing_render_nodes = runtime_controller.get("render_nodes")
		if existing_render_nodes is Dictionary:
			for node in existing_render_nodes.values():
				if node != null:
					apply_to_render_node(node, node.get_meta("cell_semantic_snapshot", {}))
	return last_diagnostics.duplicate()


func apply_to_render_node(mesh_node, cell_semantic_snapshot: Dictionary = {}) -> Dictionary:
	if catalog == null or not catalog is CatalogScript:
		return {"attachment": null, "material": null, "profile_id": "", "diagnostics": ["CavePresentationCatalog is not configured"]}
	var context: Dictionary = ContextBuilder.from_runtime_snapshot(cell_semantic_snapshot, biome_id)
	var resolved: Dictionary = catalog.resolve(context)
	if not resolved.get("diagnostics", []).is_empty():
		return {"attachment": null, "material": null, "profile_id": "", "diagnostics": resolved.get("diagnostics", [])}
	return Realizer.realize(mesh_node, resolved.get("profile"), context)


func _on_cell_attached(address, tier: String) -> void:
	if tier != "render" or runtime_controller == null:
		return
	var render_nodes = runtime_controller.get("render_nodes")
	if not render_nodes is Dictionary:
		return
	var key: String = address.canonical_text() if address != null and address.has_method("canonical_text") else str(address)
	var mesh_node = render_nodes.get(key, null)
	if mesh_node == null:
		return
	var snapshot: Dictionary = mesh_node.get_meta("cell_semantic_snapshot", {})
	var result: Dictionary = apply_to_render_node(mesh_node, snapshot)
	for failure in result.get("diagnostics", []):
		last_diagnostics.append(str(failure))
