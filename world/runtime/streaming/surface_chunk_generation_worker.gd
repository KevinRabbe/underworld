extends RefCounted

const TerrainGeneratorScript := preload("res://worldgen/surface/terrain_generator.gd")
const PickupGeneratorScript := preload("res://worldgen/surface/pickup_generator.gd")

var _generator
var _pickup_generator
var _task_id: int = -1
var _task_coord: Vector2i = Vector2i.ZERO
var _result_mutex: Mutex = Mutex.new()
var _result_coord: Vector2i = Vector2i.ZERO
var _result_data: Dictionary = {}
var _result_ms: float = 0.0


func configure(settings) -> void:
	_generator = TerrainGeneratorScript.new()
	_generator.configure(settings)
	_pickup_generator = PickupGeneratorScript.new()
	_pickup_generator.configure(settings)


func is_busy() -> bool:
	return _task_id != -1


func active_coord() -> Vector2i:
	return _task_coord


func start(coord: Vector2i) -> bool:
	if is_busy() or _generator == null or _pickup_generator == null:
		return false

	_task_coord = coord
	var task_callable: Callable = Callable(self, "_generate_chunk").bind(coord)
	_task_id = WorkerThreadPool.add_task(
		task_callable,
		false,
		"Underworld terrain %d,%d" % [coord.x, coord.y]
	)
	if _task_id < 0:
		_task_id = -1
		return false
	return true


func collect_completed() -> Dictionary:
	if not is_busy() or not WorkerThreadPool.is_task_completed(_task_id):
		return {"completed": false}

	var finished_task_id: int = _task_id
	WorkerThreadPool.wait_for_task_completion(finished_task_id)
	_task_id = -1

	_result_mutex.lock()
	var coord: Vector2i = _result_coord
	var data: Dictionary = _result_data
	var data_ms: float = _result_ms
	_result_data = {}
	_result_ms = 0.0
	_result_mutex.unlock()

	return {
		"completed": true,
		"coord": coord,
		"data": data,
		"data_ms": data_ms,
	}


func shutdown() -> void:
	if _task_id != -1:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1


func _generate_chunk(coord: Vector2i) -> void:
	var started_usec: int = Time.get_ticks_usec()
	var data: Dictionary = _generator.generate_chunk_data(coord)
	_pickup_generator.add_pickups_to_chunk_data(coord, data)
	var elapsed_ms: float = float(Time.get_ticks_usec() - started_usec) / 1000.0

	_result_mutex.lock()
	_result_coord = coord
	_result_data = data
	_result_ms = elapsed_ms
	_result_mutex.unlock()
