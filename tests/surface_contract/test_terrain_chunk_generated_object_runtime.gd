extends RefCounted

const TerrainChunk := preload("res://world/terrain_chunk.gd")
const WorldSettings := preload("res://world/runtime/config/world_settings.gd")
const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_generated_object_facade_contract(failures)
	return failures


static func _test_generated_object_facade_contract(failures: Array[String]) -> void:
	var tree_a: String = _surface_id("tree", 8, -4)
	var tree_b: String = _surface_id("tree", 9, -4)
	var rock_a: String = _surface_id("rock", 8, -4)
	var branch_a: String = _surface_id("branch", 8, -4)
	var branch_b: String = _surface_id("branch", 9, -4)
	var stone_a: String = _surface_id("loose-stone", 8, -4)

	var data: Dictionary = _terrain_chunk_data()
	data["tree_transforms"] = [
		Transform3D(Basis.IDENTITY, Vector3(0.5, 0.0, 0.5)),
		Transform3D(Basis.IDENTITY, Vector3(6.0, 0.0, 6.0)),
	]
	data["tree_stable_ids"] = [tree_a, tree_b]
	data["rock_transforms"] = [
		Transform3D(Basis.IDENTITY.scaled(Vector3(1.5, 1.0, 0.75)), Vector3(1.0, 0.0, 0.5)),
	]
	data["rock_stable_ids"] = [rock_a]
	data["branch_transforms"] = [
		Transform3D(Basis.IDENTITY, Vector3(0.25, 0.0, 0.25)),
		Transform3D(Basis.IDENTITY, Vector3(4.0, 0.0, 0.0)),
	]
	data["branch_stable_ids"] = [branch_a, branch_b]
	data["loose_stone_transforms"] = [
		Transform3D(Basis.IDENTITY, Vector3(0.75, 0.0, 0.25)),
	]
	data["loose_stone_stable_ids"] = [stone_a]

	var chunk = TerrainChunk.new()
	chunk.build(
		Vector2i(2, -1),
		data,
		StandardMaterial3D.new(),
		_decoration_assets(),
		WorldSettings.new(),
		{tree_b: true},
		false
	)

	_expect_equal(failures, "pre-destroyed tree is suppressed", chunk.tree_instance_count, 1)
	_expect_equal(failures, "rock visible count", chunk.rock_instance_count, 1)
	_expect_equal(failures, "branch visible count", chunk.branch_instance_count, 2)
	_expect_equal(failures, "loose-stone visible count", chunk.loose_stone_instance_count, 1)
	_expect_equal(failures, "pickup counts facade", chunk.get_pickup_counts(), Vector2i(2, 1))

	for child_name in ["Trees", "Rocks", "LooseBranches", "LooseStones", "NearWorldObjects"]:
		if chunk.get_node_or_null(NodePath(child_name)) == null:
			failures.append("generated-object runtime changed TerrainChunk child placement: %s" % child_name)

	_expect_equal(failures, "tree StableId facade", chunk._make_object_id("tree", 0), tree_a)
	_expect_equal(failures, "rock StableId facade", chunk._make_object_id("rock", 0), rock_a)
	_expect_equal(failures, "branch StableId facade", chunk._make_object_id("branch", 0), branch_a)
	_expect_equal(failures, "stone StableId facade", chunk._make_object_id("loose_stone", 0), stone_a)
	_expect_equal(failures, "out-of-range StableId remains rejected", chunk._make_object_id("tree", 99), "")

	var pickups_before: Array = chunk.find_nearby_pickups(Vector3.ZERO, 2.0)
	var pickups_again: Array = chunk.find_nearby_pickups(Vector3.ZERO, 2.0)
	_expect_equal(failures, "pickup discovery remains non-mutating", pickups_again, pickups_before)
	var expected_pickup_ids: Array[String] = [branch_a, stone_a]
	expected_pickup_ids.sort()
	_expect_equal(failures, "pickup discovery count", pickups_before.size(), 2)
	if pickups_before.size() == 2:
		var actual_pickup_ids: Array[String] = [
			str(pickups_before[0].get("object_id", "")),
			str(pickups_before[1].get("object_id", "")),
		]
		_expect_equal(failures, "pickup discovery StableId ordering", actual_pickup_ids, expected_pickup_ids)

	chunk.update_world_object_physics(Vector3.ZERO, 2.0, 3.0)
	_expect_equal(failures, "near tree/rock proxies activate", chunk.get_active_world_object_count(), 2)

	if not chunk.destroy_world_object("tree", 0):
		failures.append("generated tree destruction was rejected")
	_expect_equal(failures, "tree destruction updates direct visible count", chunk.tree_instance_count, 0)
	_expect_equal(failures, "tree destruction retires active proxy", chunk.get_active_world_object_count(), 1)
	if chunk.destroy_world_object("tree", 0):
		failures.append("duplicate generated tree destruction succeeded")
	if chunk.destroy_world_object("rock", 99):
		failures.append("out-of-range generated rock destruction succeeded")

	if not chunk.destroy_world_object("branch", 0):
		failures.append("generated branch destruction was rejected")
	_expect_equal(failures, "branch destruction updates pickup counts", chunk.get_pickup_counts(), Vector2i(1, 1))
	var pickups_after: Array = chunk.find_nearby_pickups(Vector3.ZERO, 2.0)
	_expect_equal(failures, "destroyed branch no longer appears in pickup query", pickups_after.size(), 1)
	if pickups_after.size() == 1:
		_expect_equal(
			failures,
			"surviving pickup identity remains exact",
			str(pickups_after[0].get("object_id", "")),
			stone_a
		)

	chunk.update_world_object_physics(Vector3(20.0, 0.0, 20.0), 2.0, 3.0)
	_expect_equal(failures, "far world-object proxy releases", chunk.get_active_world_object_count(), 0)

	if chunk._collision_body != null:
		failures.append("TerrainChunk unexpectedly built collision when disabled")
	chunk.set_collision_enabled(true)
	if chunk._collision_body == null:
		failures.append("TerrainChunk collision did not enable independently of generated-object state")
	chunk.set_collision_enabled(false)
	if chunk._collision_body != null:
		failures.append("TerrainChunk collision did not disable independently of generated-object state")

	chunk.free()


static func _terrain_chunk_data() -> Dictionary:
	return {
		"resolution": 2,
		"spacing": 1.0,
		"vertices": PackedVector3Array([
			Vector3(0.0, 0.0, 0.0),
			Vector3(1.0, 0.0, 0.0),
			Vector3(0.0, 0.0, 1.0),
			Vector3(1.0, 0.0, 1.0),
		]),
		"normals": PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]),
		"uvs": PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, Vector2.ONE]),
		"colors": PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]),
		"indices": PackedInt32Array([0, 2, 1, 1, 2, 3]),
		"collision_heights": PackedFloat32Array([0.0, 0.0, 0.0, 0.0]),
		"moisture": PackedFloat32Array([0.0, 0.0, 0.0, 0.0]),
		"forest_density": PackedFloat32Array([0.0, 0.0, 0.0, 0.0]),
		"rockiness": PackedFloat32Array([0.0, 0.0, 0.0, 0.0]),
		"buildability": PackedFloat32Array([1.0, 1.0, 1.0, 1.0]),
		"tree_transforms": [],
		"tree_stable_ids": [],
		"rock_transforms": [],
		"rock_stable_ids": [],
		"branch_transforms": [],
		"branch_stable_ids": [],
		"loose_stone_transforms": [],
		"loose_stone_stable_ids": [],
	}


static func _decoration_assets() -> Dictionary:
	var mesh: BoxMesh = BoxMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	return {
		"tree_mesh": mesh,
		"tree_material": material,
		"rock_mesh": mesh,
		"rock_material": material,
		"branch_mesh": mesh,
		"branch_material": material,
		"loose_stone_mesh": mesh,
		"loose_stone_material": material,
	}


static func _surface_id(domain: String, global_cell_x: int, global_cell_z: int) -> String:
	return StableId.from_address(
		StableAddress.surface_candidate(domain, global_cell_x, global_cell_z, "0")
	).value()


static func _expect_equal(
	failures: Array[String],
	label: String,
	actual: Variant,
	expected: Variant
) -> void:
	if actual != expected:
		failures.append("%s expected=%s actual=%s" % [label, expected, actual])
