extends RefCounted

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const SurfaceChunkStreamer := preload("res://world/runtime/streaming/surface_chunk_streamer.gd")


class RejectingWorldDeltaStore:
	extends RefCounted
	var destroyed: Dictionary = {}

	func replace_destroyed_object_ids(_object_ids: Array) -> Array[String]:
		destroyed.clear()
		return []

	func mark_generated_object_destroyed(_stable_id: String) -> bool:
		return false

	func is_generated_object_destroyed(stable_id: String) -> bool:
		return destroyed.has(stable_id)

	func snapshot() -> Dictionary:
		var ids: Array = destroyed.keys()
		ids.sort()
		return {"destroyed_objects": ids}


class FakeChunk:
	extends RefCounted
	var expected_id: String = ""
	var destroy_calls: int = 0

	func _make_object_id(_object_type: String, index: int) -> String:
		return expected_id if index == 0 else ""

	func destroy_world_object(_object_type: String, _index: int) -> bool:
		destroy_calls += 1
		return true


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_world_delta_store_is_surface_authority(failures)
	_test_store_rejection_prevents_local_mutation(failures)
	return failures


static func _test_world_delta_store_is_surface_authority(failures: Array[String]) -> void:
	var store = WorldDeltaStore.new()
	var streamer = SurfaceChunkStreamer.new()
	if not streamer.bind_world_delta_store(store):
		failures.append("surface streamer rejected accepted WorldDeltaStore authority")
		streamer.free()
		return

	var entries: Array = [
		[_surface_id("tree", -8, 12), "tree"],
		[_surface_id("rock", -7, 12), "rock"],
		[_surface_id("branch", -6, 12), "branch"],
		[_surface_id("loose-stone", -5, 12), "loose_stone"],
	]
	var expected: Array[String] = []
	for entry_variant in entries:
		var entry: Array = entry_variant
		var object_id: String = str(entry[0])
		var object_type: String = str(entry[1])
		if not streamer.destroy_world_object(object_id, object_type, 0, Vector2i(99, 99)):
			failures.append("surface destruction did not commit through WorldDeltaStore: %s" % object_type)
		expected.append(object_id)
	expected.sort()

	var snapshot: Dictionary = store.snapshot()
	if snapshot.get("destroyed_objects", []) != expected:
		failures.append("WorldDeltaStore snapshot did not own all four surface destruction types")

	# A local cache edit cannot change durable truth; the next read must rebuild
	# from the bound store snapshot.
	streamer.destroyed_object_ids.clear()
	if streamer.get_destroyed_object_ids() != expected:
		failures.append("surface destruction cache became authoritative over WorldDeltaStore")

	var retained_id: String = str(expected[0])
	streamer.load_destroyed_object_ids([retained_id, "sid1:garbage", "legacy:tree:0"])
	if store.snapshot().get("destroyed_objects", []) != [retained_id]:
		failures.append("surface persisted destruction load did not replace state through WorldDeltaStore")
	if streamer._destroyed_object_lookup() != {retained_id: true}:
		failures.append("chunk reload lookup did not derive destroyed StableIds from WorldDeltaStore")
	streamer.free()


static func _test_store_rejection_prevents_local_mutation(failures: Array[String]) -> void:
	var object_id: String = _surface_id("tree", 4, -9)
	var store = RejectingWorldDeltaStore.new()
	var streamer = SurfaceChunkStreamer.new()
	if not streamer.bind_world_delta_store(store):
		failures.append("surface streamer rejected exact WorldDeltaStore adapter API")
		streamer.free()
		return

	var coord: Vector2i = Vector2i(1, -2)
	var chunk = FakeChunk.new()
	chunk.expected_id = object_id
	streamer.chunks[coord] = chunk
	streamer.destroyed_object_ids[object_id] = true

	if streamer.is_world_object_destroyed(object_id):
		failures.append("surface cache overrode rejecting durable store authority")
	if streamer.destroy_world_object(object_id, "tree", 0, coord):
		failures.append("surface destruction succeeded after durable store rejection")
	if chunk.destroy_calls != 0:
		failures.append("local surface realization mutated before durable store acceptance")
	if not streamer.get_destroyed_object_ids().is_empty():
		failures.append("rejected durable mutation leaked into surface destruction snapshot")
	streamer.free()


static func _surface_id(domain: String, global_cell_x: int, global_cell_z: int) -> String:
	return StableId.from_address(
		StableAddress.surface_candidate(domain, global_cell_x, global_cell_z, "0")
	).value()
