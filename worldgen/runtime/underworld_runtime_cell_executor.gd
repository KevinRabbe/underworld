extends RefCounted
class_name UnderworldRuntimeCellExecutor

const Result := preload("res://worldgen/runtime/runtime_cell_result.gd")
const VoxelRequest := preload("res://worldgen/geometry/cave_voxel_field_request.gd")
const VoxelMesher := preload("res://worldgen/geometry/cave_voxel_mesher.gd")
const CollisionBuilder := preload("res://worldgen/runtime/cave_collision_builder.gd")
const CollisionBoundary := preload("res://worldgen/runtime/cave_collision_realization_boundary.gd")

const TIER_PRIORITY: Dictionary = {
	"definition": 0,
	"fragment_plan": 1,
	"voxel_geometry": 2,
	"render": 3,
	"collision": 4,
	"simulation": 5,
}

var streamer
var definition_service
var controller
var observer_position: Vector3 = Vector3.ZERO
var _jobs: Array[Dictionary] = []
var _job_keys: Dictionary = {}
var _mesh_cache: Dictionary = {}


func configure(streamer_value, definition_service_value, controller_value) -> Array[String]:
	streamer = streamer_value
	definition_service = definition_service_value
	controller = controller_value
	_jobs.clear()
	_job_keys.clear()
	_mesh_cache.clear()
	var failures: Array[String] = []
	if streamer == null:
		failures.append("Runtime cell executor requires UnderworldRuntimeStreamer")
	if definition_service == null:
		failures.append("Runtime cell executor requires cell definition service")
	if controller == null:
		failures.append("Runtime cell executor requires cave runtime controller")
	return failures


func submit(request, tier: String) -> void:
	if request == null or streamer == null or definition_service == null or controller == null:
		return
	if not TIER_PRIORITY.has(tier):
		return
	var key := _job_key(request, tier)
	if _job_keys.has(key):
		return
	_jobs.append({"request": request, "tier": tier, "key": key})
	_job_keys[key] = true


func set_observer_position(position: Vector3) -> void:
	observer_position = position


func pump(max_expensive_jobs: int = 1, max_total_jobs: int = 16) -> int:
	if streamer == null or definition_service == null or controller == null:
		return 0
	_jobs.sort_custom(Callable(self, "_job_less"))
	var processed := 0
	var expensive := 0
	var index := 0
	while index < _jobs.size() and processed < maxi(max_total_jobs, 1):
		var job: Dictionary = _jobs[index]
		var request = job["request"]
		var tier: String = str(job["tier"])
		if not _job_is_current(request, tier):
			_remove_job(index)
			continue
		if not _dependencies_ready(request, tier):
			index += 1
			continue
		if tier == "voxel_geometry" and expensive >= maxi(max_expensive_jobs, 0):
			index += 1
			continue
		var consumed: bool = _execute_job(request, tier)
		if not consumed:
			index += 1
			continue
		if tier == "voxel_geometry":
			expensive += 1
		processed += 1
		_remove_job(index)
	_settle_release_pending_cells()
	return processed


func prune_runtime_cache() -> void:
	if streamer == null:
		_mesh_cache.clear()
		return
	for key in _mesh_cache.keys().duplicate():
		var record = streamer.records.get(str(key).get_slice("|", 0), null)
		if record == null or record.release_pending or record.demand_count("voxel_geometry") <= 0:
			_mesh_cache.erase(key)


func queued_job_count() -> int:
	return _jobs.size()


func _execute_job(request, tier: String) -> bool:
	var definition_stage = definition_service.cell_definition(request.cell_address)
	if not definition_stage.success:
		_accept_failure(request, tier, definition_stage.diagnostics)
		return true
	var definition: Dictionary = definition_stage.data
	if str(definition.get("source_fingerprint", "")) != request.source_fingerprint or str(definition.get("provenance_fingerprint", "")) != request.provenance_fingerprint:
		_accept_failure(
			request,
			tier,
			["Runtime cell definition identity drifted for " + request.cell_address.canonical_text()]
		)
		return true
	match tier:
		"definition":
			_accept_success(request, tier, definition)
			return true
		"fragment_plan":
			_accept_success(request, tier, definition["cell_plan"])
			return true
		"voxel_geometry":
			var voxel_request := VoxelRequest.new(
				definition["cell_plan"],
				definition_service.cell_config,
				definition["provenance"],
				0.0,
				definition["partition_result"],
				definition_service.context
			)
			var mesh_stage = VoxelMesher.build(voxel_request)
			if not mesh_stage.success:
				_accept_failure(request, tier, mesh_stage.diagnostics)
				return true
			_mesh_cache[_mesh_key(request)] = mesh_stage.data
			_accept_success(request, tier, mesh_stage.data)
			return true
		"render":
			var mesh_data = _mesh_cache.get(_mesh_key(request), null)
			if mesh_data == null:
				return false
			var snapshot: Dictionary = controller.build_cell_semantic_snapshot(definition["cell_plan"])
			if not controller.accept_mesh_data(mesh_data, null, snapshot):
				_accept_failure(request, tier, ["Runtime render realization failed for " + request.cell_address.canonical_text()])
			return true
		"collision":
			var mesh_data = _mesh_cache.get(_mesh_key(request), null)
			if mesh_data == null:
				return false
			var collision_stage = CollisionBuilder.prepare(mesh_data, request.provenance_fingerprint)
			if not collision_stage.success:
				_accept_failure(request, tier, collision_stage.diagnostics)
				return true
			var realized: Dictionary = CollisionBoundary.realize_main_thread(
				collision_stage.data,
				mesh_data.output_fingerprint
			)
			if not bool(realized.get("success", false)) or not controller.accept_collision_shape(
				request.cell_address,
				realized.get("shape", null),
				request.source_fingerprint,
				request.provenance_fingerprint
			):
				_accept_failure(request, tier, ["Runtime collision realization failed for " + request.cell_address.canonical_text()])
			return true
		"simulation":
			_accept_failure(request, tier, ["Runtime simulation tier has no production executor in CAVE-STREAM-002"])
			return true
	return false


func _dependencies_ready(request, tier: String) -> bool:
	var record = streamer.records.get(request.cell_address.canonical_text(), null)
	if record == null:
		return false
	match tier:
		"definition":
			return true
		"fragment_plan":
			return bool(record.readiness.get("definition", false))
		"voxel_geometry":
			return bool(record.readiness.get("definition", false)) and bool(record.readiness.get("fragment_plan", false))
		"render", "collision":
			return bool(record.readiness.get("voxel_geometry", false))
		"simulation":
			return false
	return false


func _job_is_current(request, tier: String) -> bool:
	if request == null or request.cell_address == null:
		return false
	var record = streamer.records.get(request.cell_address.canonical_text(), null)
	if record == null or record.release_pending:
		return false
	if request.generation != record.generation:
		return false
	if request.world_id != streamer.world_id or request.generator_manifest_id != streamer.generator_manifest_id:
		return false
	if request.source_fingerprint != record.source_fingerprint or request.provenance_fingerprint != record.provenance_fingerprint:
		return false
	return record.demand_count(tier) > 0


func _accept_success(request, tier: String, payload) -> bool:
	var result := Result.new(
		request.cell_address,
		request.generation,
		tier,
		request.source_fingerprint,
		request.provenance_fingerprint,
		payload,
		true,
		[],
		request.world_id,
		request.generator_manifest_id
	)
	return streamer.accept_result(result)


func _accept_failure(request, tier: String, diagnostics: Array) -> void:
	var normalized: Array[String] = []
	for diagnostic in diagnostics:
		normalized.append(str(diagnostic))
	var result := Result.new(
		request.cell_address,
		request.generation,
		tier,
		request.source_fingerprint,
		request.provenance_fingerprint,
		null,
		false,
		normalized,
		request.world_id,
		request.generator_manifest_id
	)
	streamer.accept_result(result)


func _settle_release_pending_cells() -> void:
	for record in streamer.records.values():
		if record == null or not record.release_pending or not record.demands.is_empty():
			continue
		streamer.release_cell(record.cell_address)


func _job_less(a: Dictionary, b: Dictionary) -> bool:
	var request_a = a["request"]
	var request_b = b["request"]
	var distance_a := _distance_to_observer(request_a.cell_address)
	var distance_b := _distance_to_observer(request_b.cell_address)
	if not is_equal_approx(distance_a, distance_b):
		return distance_a < distance_b
	var priority_a: int = int(TIER_PRIORITY.get(str(a["tier"]), 999))
	var priority_b: int = int(TIER_PRIORITY.get(str(b["tier"]), 999))
	if priority_a != priority_b:
		return priority_a < priority_b
	return request_a.cell_address.canonical_text() < request_b.cell_address.canonical_text()


func _distance_to_observer(address) -> float:
	var cell_size: Vector3 = streamer.cell_size if streamer != null else Vector3(32, 32, 32)
	var center := Vector3(address.coordinate) * cell_size + cell_size * 0.5
	return center.distance_squared_to(observer_position)


func _mesh_key(request) -> String:
	return "%s|%d|%s|%s" % [
		request.cell_address.canonical_text(),
		request.generation,
		request.source_fingerprint,
		request.provenance_fingerprint,
	]


func _job_key(request, tier: String) -> String:
	return "%s|%d|%s|%s|%s" % [
		request.cell_address.canonical_text(),
		request.generation,
		tier,
		request.source_fingerprint,
		request.provenance_fingerprint,
	]


func _remove_job(index: int) -> void:
	var key: String = str(_jobs[index].get("key", ""))
	_jobs.remove_at(index)
	if not key.is_empty():
		_job_keys.erase(key)
