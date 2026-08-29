extends RefCounted

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const SurfaceChunkStreamer := preload("res://world/runtime/streaming/surface_chunk_streamer.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var tree_id: String = _surface_id("tree", -8, 12)
	var foreign_region_id: String = StableId.from_address(
		StableAddress.underground_region(-2, 3)
	).value()
	var foreign_surface_id: String = _surface_id("ore", -8, 12)

	var streamer = SurfaceChunkStreamer.new()
	streamer.load_destroyed_object_ids([
		tree_id,
		foreign_region_id,
		foreign_surface_id,
		"-2:3:tree:0",
		"sid1:garbage",
	])

	if streamer.get_destroyed_object_ids() != [tree_id]:
		failures.append("surface streamer admitted malformed, legacy, or foreign StableId state")
	if streamer.is_world_object_destroyed(foreign_region_id):
		failures.append("surface streamer treated underground StableId as surface destruction state")
	if streamer.is_world_object_destroyed(foreign_surface_id):
		failures.append("surface streamer accepted unknown surface candidate domain")
	if streamer.destroy_world_object(tree_id, "rock", 0, Vector2i.ZERO):
		failures.append("surface streamer accepted StableId whose semantic domain mismatched object type")
	if streamer.destroy_world_object(foreign_region_id, "tree", 0, Vector2i.ZERO):
		failures.append("surface streamer accepted foreign StableId for a surface mutation")

	streamer.free()
	return failures


static func _surface_id(domain: String, global_cell_x: int, global_cell_z: int) -> String:
	return StableId.from_address(
		StableAddress.surface_candidate(domain, global_cell_x, global_cell_z, "0")
	).value()
