extends RefCounted

const Controller := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const WorldId := preload("res://worldgen/identity/world_id.gd")
const Manifest := preload("res://worldgen/versioning/generator_manifest.gd")
const WorldContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const DefinitionService := preload("res://worldgen/runtime/underworld_runtime_cell_definition_service.gd")
const Fixture := preload("res://worldgen/validation/map015_fixture.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	var pinned_context := WorldContext.new(1)
	var context_failures: Array[String] = pinned_context.validate()
	if not context_failures.is_empty():
		failures.append_array(context_failures)
		return failures

	var seed_mismatch_service := DefinitionService.new()
	var seed_mismatch: Array[String] = seed_mismatch_service.configure(2, pinned_context)
	if seed_mismatch.is_empty():
		failures.append("runtime definition service accepted a supplied context with the wrong world seed")

	var controller := Controller.new()
	controller.configure(pinned_context.world_id, pinned_context.generator_manifest_id)
	var entrance_id := Fixture.ENTRANCE_ID
	var diagnostics: Array[String] = controller.bootstrap_generated_entrance(
		1,
		Fixture.REGION,
		entrance_id,
		pinned_context
	)
	if not diagnostics.is_empty():
		failures.append_array(diagnostics)
	else:
		if controller._definition_service == null or controller._definition_service.context != pinned_context:
			failures.append("MAP-015 runtime did not consume the supplied root WorldGenerationContext")
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
			failures.append("MAP-015 explicit pinned context does not reproduce legacy matching bootstrap fingerprint")
		second.free()

	var mismatch := Controller.new()
	mismatch.configure(pinned_context.world_id, "manifest:runtime-mismatch")
	var mismatch_diagnostics: Array[String] = mismatch.bootstrap_generated_entrance(
		1,
		Fixture.REGION,
		entrance_id,
		pinned_context
	)
	if mismatch_diagnostics.is_empty():
		failures.append("MAP-015 runtime accepted a definition producer/runtime manifest mismatch")
	elif not _contains(mismatch_diagnostics, "GeneratorManifestId does not match controller runtime identity"):
		failures.append("MAP-015 manifest mismatch did not report the producer/runtime identity diagnostic")
	if mismatch._definition_service == null:
		failures.append("MAP-015 manifest mismatch did not retain definition service for pre-generation inspection")
	else:
		if mismatch._definition_service.cached_cell_count() != 0:
			failures.append("MAP-015 manifest mismatch generated cell definitions before rejection")
		if mismatch._definition_service.cached_region_count() != 0 or not mismatch._definition_service._base_regions.is_empty():
			failures.append("MAP-015 manifest mismatch generated region definitions before rejection")
	mismatch.update_player_position(Vector3(0.5, -31.5, 0.5))
	if not mismatch.streamer.records.is_empty():
		failures.append("MAP-015 manifest mismatch admitted observer demand after rejection")
	if not mismatch.render_nodes.is_empty() or not mismatch.collision_nodes.is_empty():
		failures.append("MAP-015 manifest mismatch attached render/collision nodes")
	if not mismatch.entrance_plans.is_empty() or not mismatch.gates.is_empty():
		failures.append("MAP-015 manifest mismatch registered entrance runtime state")
	mismatch.free()
	controller.free()
	return failures


static func _contains(values: Array[String], needle: String) -> bool:
	for value in values:
		if value.contains(needle):
			return true
	return false
