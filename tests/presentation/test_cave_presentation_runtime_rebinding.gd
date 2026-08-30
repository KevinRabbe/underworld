extends RefCounted

const PresentationController := preload("res://presentation/world/caves/cave_presentation_controller.gd")
const RuntimeController := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")

const CATALOG_PATH := "res://content/presentation/caves/prototype_cave_presentation_catalog.tres"


static func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog = ResourceLoader.load(CATALOG_PATH)
	if catalog == null:
		failures.append("prototype cave presentation catalog did not load")
		return failures
	var old_runtime := RuntimeController.new()
	var new_runtime := RuntimeController.new()
	old_runtime.configure("world:old", "manifest:old")
	new_runtime.configure("world:new", "manifest:new")
	var controller := PresentationController.new()
	var configure_failures: Array[String] = controller.configure(old_runtime, catalog)
	if not configure_failures.is_empty():
		failures.append("initial presentation runtime binding failed: %s" % [configure_failures])
		_cleanup(controller, old_runtime, new_runtime, [])
		return failures
	_expect(failures, "old runtime has exactly one presentation callback", old_runtime.get_signal_connection_list("cell_attached").size() == 1)

	var address := Address.new(Vector3i(9, -2, 1))
	var key: String = address.canonical_text()
	var old_node := _render_node(key)
	old_runtime.render_nodes[key] = old_node
	old_runtime.cell_attached.emit(address, "render")
	_expect(failures, "old runtime emission reaches presentation before rebind", old_node.get_child_count() == 1)

	configure_failures = controller.configure(new_runtime, catalog)
	if not configure_failures.is_empty():
		failures.append("new presentation runtime binding failed: %s" % [configure_failures])
	_expect(failures, "old runtime callback disconnected on rebind", old_runtime.get_signal_connection_list("cell_attached").is_empty())
	_expect(failures, "new runtime has exactly one presentation callback", new_runtime.get_signal_connection_list("cell_attached").size() == 1)

	var stale_old_node := _render_node(key)
	old_runtime.render_nodes[key] = stale_old_node
	old_runtime.cell_attached.emit(address, "render")
	_expect(failures, "old runtime emission ignored after rebind", stale_old_node.get_child_count() == 0)

	var new_node := _render_node(key)
	new_runtime.render_nodes[key] = new_node
	new_runtime.cell_attached.emit(address, "render")
	_expect(failures, "new runtime emission accepted after rebind", new_node.get_child_count() == 1)

	configure_failures = controller.configure(new_runtime, catalog)
	if not configure_failures.is_empty():
		failures.append("same-runtime presentation rebind failed: %s" % [configure_failures])
	_expect(failures, "same runtime rebind does not duplicate callback", new_runtime.get_signal_connection_list("cell_attached").size() == 1)
	_cleanup(controller, old_runtime, new_runtime, [old_node, stale_old_node, new_node])
	return failures


static func _render_node(key: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = ArrayMesh.new()
	node.set_meta("cell_address", key)
	var snapshot: Dictionary = {}
	snapshot.make_read_only()
	node.set_meta("cell_semantic_snapshot", snapshot)
	return node


static func _cleanup(controller, old_runtime, new_runtime, nodes: Array) -> void:
	for node in nodes:
		if node != null and is_instance_valid(node):
			node.free()
	if controller != null and is_instance_valid(controller):
		controller.free()
	if old_runtime != null and is_instance_valid(old_runtime):
		old_runtime.free()
	if new_runtime != null and is_instance_valid(new_runtime):
		new_runtime.free()


static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
