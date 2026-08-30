extends RefCounted
class_name UnderworldSelectedEntranceBootstrap


static func bootstrap(runtime, world_seed: int, selection: Dictionary) -> Dictionary:
	if runtime == null or not is_instance_valid(runtime):
		return _failure(["Selected entrance bootstrap requires live runtime controller"])
	if not bool(selection.get("success", false)):
		return _failure(["Selected entrance bootstrap requires successful route selection"])
	var entrance_id := str(selection.get("entrance_id", ""))
	var region_variant = selection.get("region", null)
	var expected_position_variant = selection.get("surface_world_position", null)
	if entrance_id.is_empty() or not region_variant is Vector2i or not expected_position_variant is Vector3:
		return _failure(["Selected entrance bootstrap route identity is incomplete"])
	var region: Vector2i = region_variant
	var expected_position: Vector3 = expected_position_variant
	if not _finite_vec3(expected_position):
		return _failure(["Selected entrance bootstrap surface position must be finite"])

	# The accepted runtime bootstrap is parameterized by seed/region/entrance identity;
	# this adapter is the ordinary production entrypoint. It deliberately supplies
	# only generated selection values and never fixture IDs, coordinates or topology.
	var diagnostics: Array[String] = runtime.bootstrap_fixture(world_seed, region, entrance_id)
	if not diagnostics.is_empty():
		return _failure(diagnostics)
	if not _finite_vec3(runtime.last_bootstrap_surface_position):
		return _failure(["Selected entrance runtime returned non-finite surface position"])
	if not runtime.last_bootstrap_surface_position.is_equal_approx(expected_position):
		return _failure(["Selected entrance runtime regenerated a different surface position"])
	if not runtime.gate_is_open(entrance_id):
		return _failure(["Selected entrance traversal gate is not ready after bootstrap"])
	return {
		"success": true,
		"entrance_id": entrance_id,
		"region": region,
		"surface_world_position": runtime.last_bootstrap_surface_position,
		"bootstrap_fingerprint": str(runtime.last_bootstrap_fingerprint),
		"diagnostics": [],
	}


static func _failure(raw: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for value in raw:
		diagnostics.append(str(value))
	return {"success": false, "diagnostics": diagnostics}


static func _finite_vec3(value: Vector3) -> bool:
	return (
		not is_nan(value.x) and not is_inf(value.x)
		and not is_nan(value.y) and not is_inf(value.y)
		and not is_nan(value.z) and not is_inf(value.z)
	)
