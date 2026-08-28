extends RefCounted

const Controller := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const WorldId := preload("res://worldgen/identity/world_id.gd")
const Manifest := preload("res://worldgen/versioning/generator_manifest.gd")
const Fixture := preload("res://worldgen/validation/map015_fixture.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	var controller := Controller.new()
	controller.configure(WorldId.from_seed(1).value(), Manifest.foundation_default().manifest_id())
	var entrance_id := Fixture.ENTRANCE_ID
	var diagnostics: Array[String] = controller.bootstrap_fixture(1, Fixture.REGION, entrance_id)
	if not diagnostics.is_empty():
		failures.append_array(diagnostics)
	else:
		if controller.render_nodes.size() < 4: failures.append("MAP-015 bootstrap produced too few render cells")
		if controller.collision_nodes.size() < 4: failures.append("MAP-015 bootstrap produced too few collision cells")
		if not controller.gate_is_open(entrance_id): failures.append("MAP-015 bootstrap gate did not open")
		if controller.last_bootstrap_fingerprint.is_empty(): failures.append("MAP-015 bootstrap fingerprint missing")
		var route: Array[Vector3] = [controller.last_bootstrap_surface_position + Vector3.UP * 3.0]
		var required_cells: Array = controller.entrance_plans[entrance_id].cell_addresses
		for address in required_cells:
			route.append(Vector3(address.coordinate) * 32.0 + Vector3(16.0, 16.0, 16.0))
		route.append(controller.last_bootstrap_surface_position + Vector3.UP * 3.0)
		for position in route:
			controller.update_player_position(position)
			if not controller.gate_is_open(entrance_id):
				failures.append("MAP-015 traversal route lost collision gate readiness: " + ",".join(controller.gates[entrance_id].diagnostics))
				break
		if controller.streamer.stale_result_count != 0: failures.append("MAP-015 route produced stale result resurrection")
		if controller.streamer.active_owner_count() < 4: failures.append("MAP-015 route lost runtime cell ownership")
		var first_fingerprint := controller.last_bootstrap_fingerprint
		var second := Controller.new()
		second.configure(WorldId.from_seed(1).value(), Manifest.foundation_default().manifest_id())
		var second_diagnostics: Array[String] = second.bootstrap_fixture(1, Fixture.REGION, entrance_id)
		if not second_diagnostics.is_empty() or second.last_bootstrap_fingerprint != first_fingerprint:
			failures.append("MAP-015 rebuild does not reproduce bootstrap fingerprint")
		second.free()
	controller.free()
	return failures
