extends RefCounted

const CaveRuntimeController := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const CellAddress := preload("res://worldgen/geometry/geometry_cell_address.gd")
const SupportResolver := preload("res://gameplay/resources/runtime/underground_resource_support_resolver.gd")

const FLOOR_Y: float = -22.0


static func run(realization_parent: Node3D) -> Array[String]:
	var failures: Array[String] = []
	var controller = CaveRuntimeController.new()
	realization_parent.add_child(controller)
	controller.configure("world:support-probe", "manifest:support-probe")
	var address = CellAddress.new(Vector3i(1, -2, 1))
	var source_fingerprint := "source:support-probe"
	var provenance_fingerprint := "provenance:support-probe"
	controller.streamer.demand_cell(
		address,
		"resource-support-probe",
		["collision"],
		source_fingerprint,
		provenance_fingerprint
	)
	if not controller.accept_collision_shape(
		address,
		_floor_shape(),
		source_fingerprint,
		provenance_fingerprint
	):
		failures.append("support probe could not publish current cave collision")
		_cleanup(controller)
		return failures

	await realization_parent.get_tree().physics_frame
	await realization_parent.get_tree().physics_frame
	var entry := {
		"cell_address": address.canonical_text(),
		"collision_ready": true,
		"source_fingerprint": source_fingerprint,
	}
	var hook := {
		"free_world_anchor": Vector3(1.5, -20.0, 3.0),
		"reserved_bounds": AABB(Vector3(-2.0, -24.0, -2.0), Vector3(8.0, 8.0, 8.0)),
	}
	var result: Dictionary = SupportResolver.new().resolve(realization_parent, entry, hook)
	if not bool(result.get("success", false)):
		failures.append("direct cave support probe failed: %s" % [result.get("diagnostics", [])])
	else:
		var position_variant = result.get("world_position", null)
		if typeof(position_variant) != TYPE_VECTOR3:
			failures.append("direct cave support probe returned no Vector3 position")
		else:
			var position: Vector3 = position_variant
			if absf(position.y - (FLOOR_Y + 0.02)) > 0.05:
				failures.append(
					"direct cave support probe projected to wrong Y — expected %.3f, got %.3f"
					% [FLOOR_Y + 0.02, position.y]
				)
	_cleanup(controller)
	return failures


static func _floor_shape() -> ConcavePolygonShape3D:
	var shape := ConcavePolygonShape3D.new()
	# Godot uses clockwise front-face winding for triangle collision. These two
	# triangles deliberately face upward so a downward support ray hits the floor
	# front face without enabling backface collision on the production cave shape.
	shape.set_faces(PackedVector3Array([
		Vector3(-4.5, FLOOR_Y, -3.0),
		Vector3(7.5, FLOOR_Y, -3.0),
		Vector3(7.5, FLOOR_Y, 9.0),
		Vector3(-4.5, FLOOR_Y, -3.0),
		Vector3(7.5, FLOOR_Y, 9.0),
		Vector3(-4.5, FLOOR_Y, 9.0),
	]))
	return shape


static func _cleanup(controller) -> void:
	if controller == null or not is_instance_valid(controller):
		return
	var parent = controller.get_parent()
	if parent != null:
		parent.remove_child(controller)
	controller.free()
