extends RefCounted

const SurfaceSettings := preload("res://worldgen/surface/prototype_surface_settings.gd")
const TerrainGenerator := preload("res://worldgen/surface/terrain_generator.gd")
const PickupGenerator := preload("res://worldgen/surface/pickup_generator.gd")
const SurfaceChunkGenerationWorker := preload("res://world/runtime/streaming/surface_chunk_generation_worker.gd")

const COMPLETION_TIMEOUT_MSEC: int = 10000


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_value_only_worker_boundary(failures)
	_test_single_worker_and_candidate_equivalence(failures)
	_test_teardown_waits_for_active_work(failures)
	return failures


static func _test_value_only_worker_boundary(failures: Array[String]) -> void:
	var worker = SurfaceChunkGenerationWorker.new()
	if not worker is RefCounted:
		failures.append("surface chunk generation worker is not RefCounted")
	if worker is Node:
		failures.append("surface chunk generation worker unexpectedly owns SceneTree state")
	var worker_script: Script = load("res://world/runtime/streaming/surface_chunk_generation_worker.gd")
	if worker_script.get_instance_base_type() != "RefCounted":
		failures.append("surface chunk generation worker script base type is not RefCounted")


static func _test_single_worker_and_candidate_equivalence(failures: Array[String]) -> void:
	var settings = SurfaceSettings.new()
	settings.world_seed = 77123
	var worker = SurfaceChunkGenerationWorker.new()
	worker.configure(settings)

	var coord := Vector2i(-2, 3)
	if not worker.start(coord):
		failures.append("surface chunk generation worker could not start eligible task")
		return
	if not worker.is_busy():
		failures.append("surface chunk generation worker did not report active task")
	if worker.active_coord() != coord:
		failures.append("surface chunk generation worker changed active coordinate identity")
	if worker.start(Vector2i(9, 9)):
		failures.append("surface chunk generation worker accepted a second concurrent task")

	var result: Dictionary = _await_result(worker)
	if not bool(result.get("completed", false)):
		failures.append("surface chunk generation worker did not complete within bounded test window")
		worker.shutdown()
		return
	if result.get("coord", Vector2i.ZERO) != coord:
		failures.append("surface chunk generation worker returned the wrong coordinate")
	if float(result.get("data_ms", -1.0)) < 0.0:
		failures.append("surface chunk generation worker returned invalid generation timing")
	if worker.is_busy():
		failures.append("surface chunk generation worker remained busy after result collection")

	var main_generator = TerrainGenerator.new()
	main_generator.configure(settings)
	var main_pickup_generator = PickupGenerator.new()
	main_pickup_generator.configure(settings)
	var expected: Dictionary = main_generator.generate_chunk_data(coord)
	main_pickup_generator.add_pickups_to_chunk_data(coord, expected)
	var actual_variant: Variant = result.get("data", null)
	if not actual_variant is Dictionary:
		failures.append("surface chunk generation worker did not return Dictionary data")
		return
	var actual: Dictionary = actual_variant
	if actual != expected:
		failures.append("surface background candidate data differs from equivalent main-thread generation")
	if _contains_object(actual):
		failures.append("surface background result contains Object/SceneTree-owned data")


static func _test_teardown_waits_for_active_work(failures: Array[String]) -> void:
	var settings = SurfaceSettings.new()
	settings.world_seed = -918273
	var worker = SurfaceChunkGenerationWorker.new()
	worker.configure(settings)
	if not worker.start(Vector2i(4, -5)):
		failures.append("surface worker teardown fixture could not start task")
		return
	worker.shutdown()
	if worker.is_busy():
		failures.append("surface worker teardown left an active task")


static func _await_result(worker) -> Dictionary:
	var deadline_msec: int = Time.get_ticks_msec() + COMPLETION_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline_msec:
		var result: Dictionary = worker.collect_completed()
		if bool(result.get("completed", false)):
			return result
		OS.delay_msec(1)
	return {"completed": false}


static func _contains_object(value: Variant) -> bool:
	if typeof(value) == TYPE_OBJECT:
		return true
	if value is Dictionary:
		for nested in value.values():
			if _contains_object(nested):
				return true
		return false
	if value is Array:
		for nested in value:
			if _contains_object(nested):
				return true
	return false
