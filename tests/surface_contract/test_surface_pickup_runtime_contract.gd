extends RefCounted

const TerrainChunk := preload("res://world/terrain_chunk.gd")
const TerrainGenerator := preload("res://worldgen/surface/terrain_generator.gd")
const PickupGenerator := preload("res://worldgen/surface/pickup_generator.gd")
const SurfaceSettings := preload("res://worldgen/surface/prototype_surface_settings.gd")
const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const SurfaceChunkStreamer := preload("res://world/runtime/streaming/surface_chunk_streamer.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_non_mutating_pickup_discovery(failures)
	_test_destroyed_pickups_are_excluded(failures)
	_test_generators_emit_semantic_stable_ids(failures)
	_test_world_delta_and_streamer_reject_legacy_ids(failures)
	_test_reload_suppresses_same_semantic_candidate(failures)
	return failures


static func _test_non_mutating_pickup_discovery(failures: Array[String]) -> void:
	var chunk = TerrainChunk.new()
	chunk.chunk_coord = Vector2i(-2, 3)
	chunk._branch_transforms = [
		Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 0.5)),
		Transform3D(Basis.IDENTITY, Vector3(8.0, 0.0, 0.0)),
	]
	chunk._branch_stable_ids = [
		_surface_id("branch", -8, 12),
		_surface_id("branch", -6, 12),
	]
	chunk._loose_stone_transforms = [
		Transform3D(Basis.IDENTITY, Vector3(0.5, 0.0, 1.0)),
	]
	chunk._loose_stone_stable_ids = [
		_surface_id("loose-stone", -8, 12),
	]

	var branch_destroyed_before: Dictionary = chunk._destroyed_branch_indices.duplicate(true)
	var stone_destroyed_before: Dictionary = chunk._destroyed_loose_stone_indices.duplicate(true)
	var first: Array = chunk.find_nearby_pickups(Vector3.ZERO, 2.0)
	var second: Array = chunk.find_nearby_pickups(Vector3.ZERO, 2.0)

	if first != second:
		failures.append("surface pickup discovery changed across repeated identical queries")
	if chunk._destroyed_branch_indices != branch_destroyed_before:
		failures.append("surface branch discovery mutated destroyed-index world state")
	if chunk._destroyed_loose_stone_indices != stone_destroyed_before:
		failures.append("surface loose-stone discovery mutated destroyed-index world state")
	if first.size() != 2:
		failures.append("surface pickup discovery returned unexpected nearby candidate count: %d" % first.size())
	else:
		var ids: Array[String] = []
		for candidate_variant in first:
			var candidate: Dictionary = candidate_variant
			ids.append(str(candidate.get("object_id", "")))
		var expected: Array[String] = [
			_surface_id("branch", -8, 12),
			_surface_id("loose-stone", -8, 12),
		]
		expected.sort()
		if ids != expected:
			failures.append("surface pickup discovery changed canonical StableId identity/order: %s" % [ids])
		for candidate_variant in first:
			var candidate: Dictionary = candidate_variant
			var object_id: String = str(candidate.get("object_id", ""))
			if StableId.parse(object_id) == null:
				failures.append("surface pickup discovery exposed a noncanonical StableId: %s" % object_id)
				break
			if not candidate.has("object_type") or not candidate.has("index"):
				failures.append("surface pickup discovery omitted world mutation locator fields")
				break
	chunk.free()


static func _test_destroyed_pickups_are_excluded(failures: Array[String]) -> void:
	var chunk = TerrainChunk.new()
	chunk.chunk_coord = Vector2i(4, -5)
	chunk._branch_transforms = [Transform3D(Basis.IDENTITY, Vector3.ZERO)]
	chunk._branch_stable_ids = [_surface_id("branch", 16, -20)]
	chunk._loose_stone_transforms = [Transform3D(Basis.IDENTITY, Vector3(0.25, 0.0, 0.25))]
	chunk._loose_stone_stable_ids = [_surface_id("loose-stone", 16, -20)]
	chunk._destroyed_branch_indices[0] = true
	var before: Dictionary = chunk._destroyed_branch_indices.duplicate(true)

	var found: Array = chunk.find_nearby_pickups(Vector3.ZERO, 2.0)
	if found.size() != 1:
		failures.append("surface pickup discovery did not exclude pre-destroyed candidate")
	elif str(found[0].get("object_id", "")) != _surface_id("loose-stone", 16, -20):
		failures.append("surface pickup discovery returned wrong surviving canonical StableId")
	if chunk._destroyed_branch_indices != before:
		failures.append("surface pickup discovery changed pre-existing destroyed-index state")
	chunk.free()


static func _test_generators_emit_semantic_stable_ids(failures: Array[String]) -> void:
	var settings = SurfaceSettings.new()
	settings.world_seed = 77123
	settings.sea_level = 0.0
	settings.decoration_vertex_step = 2
	settings.tree_threshold = 0.0
	settings.tree_density = 1.0
	settings.rock_threshold = 0.0
	settings.rock_density = 1.0
	settings.pickup_vertex_step = 2
	settings.branch_pickup_density = 1.0
	settings.loose_stone_pickup_density = 1.0

	var terrain = TerrainGenerator.new()
	terrain.configure(settings)
	var pickup = PickupGenerator.new()
	pickup.configure(settings)

	var resolution: int = 5
	var heights: PackedFloat32Array = PackedFloat32Array()
	var masks: PackedFloat32Array = PackedFloat32Array()
	for _index in range(resolution * resolution):
		heights.append(10.0)
		masks.append(1.0)

	var coord: Vector2i = Vector2i(-2, 3)
	var first_decoration: Dictionary = terrain._generate_decorations(
		coord,
		resolution,
		1.0,
		heights,
		masks,
		masks,
		masks
	)
	var second_decoration: Dictionary = terrain._generate_decorations(
		coord,
		resolution,
		1.0,
		heights,
		masks,
		masks,
		masks
	)
	_assert_identity_set(
		"tree",
		first_decoration["tree_transforms"],
		first_decoration["tree_stable_ids"],
		second_decoration["tree_stable_ids"],
		failures
	)
	_assert_identity_set(
		"rock",
		first_decoration["rock_transforms"],
		first_decoration["rock_stable_ids"],
		second_decoration["rock_stable_ids"],
		failures
	)

	var first_pickup_data: Dictionary = _pickup_fixture_data(resolution, heights, masks)
	var second_pickup_data: Dictionary = _pickup_fixture_data(resolution, heights, masks)
	pickup.add_pickups_to_chunk_data(coord, first_pickup_data)
	pickup.add_pickups_to_chunk_data(coord, second_pickup_data)
	_assert_identity_set(
		"branch",
		first_pickup_data["branch_transforms"],
		first_pickup_data["branch_stable_ids"],
		second_pickup_data["branch_stable_ids"],
		failures
	)
	_assert_identity_set(
		"loose-stone",
		first_pickup_data["loose_stone_transforms"],
		first_pickup_data["loose_stone_stable_ids"],
		second_pickup_data["loose_stone_stable_ids"],
		failures
	)

	var all_ids: Dictionary = {}
	for key in ["tree_stable_ids", "rock_stable_ids"]:
		for id_variant in first_decoration[key]:
			var stable_id: String = str(id_variant)
			if all_ids.has(stable_id):
				failures.append("surface decoration StableId alias detected: %s" % stable_id)
			all_ids[stable_id] = true
	for key in ["branch_stable_ids", "loose_stone_stable_ids"]:
		for id_variant in first_pickup_data[key]:
			var stable_id: String = str(id_variant)
			if all_ids.has(stable_id):
				failures.append("surface pickup StableId alias detected: %s" % stable_id)
			all_ids[stable_id] = true

	var negative_id: String = _surface_id("tree", -1, -1)
	var neighboring_id: String = _surface_id("tree", 0, -1)
	if negative_id == neighboring_id:
		failures.append("negative-coordinate surface candidates aliased a neighboring StableId")


static func _test_world_delta_and_streamer_reject_legacy_ids(failures: Array[String]) -> void:
	var canonical_ids: Array[String] = [
		_surface_id("tree", -8, 12),
		_surface_id("rock", -8, 12),
		_surface_id("branch", -8, 12),
		_surface_id("loose-stone", -8, 12),
	]
	var store = WorldDeltaStore.new()
	for stable_id in canonical_ids:
		if not store.mark_generated_object_destroyed(stable_id):
			failures.append("WorldDeltaStore rejected canonical surface StableId: %s" % stable_id)
	if store.mark_generated_object_destroyed("-2:3:tree:0"):
		failures.append("WorldDeltaStore accepted legacy accepted-index surface identity")
	if store.mark_generated_object_destroyed("sid1:garbage"):
		failures.append("WorldDeltaStore accepted malformed StableId payload")
	var snapshot: Dictionary = store.snapshot()
	if snapshot.get("destroyed_objects", []) != canonical_ids:
		var expected: Array[String] = canonical_ids.duplicate()
		expected.sort()
		if snapshot.get("destroyed_objects", []) != expected:
			failures.append("WorldDeltaStore changed canonical surface destruction snapshot")

	var streamer = SurfaceChunkStreamer.new()
	streamer.load_destroyed_object_ids([
		canonical_ids[0],
		"-2:3:tree:0",
		"sid1:garbage",
	])
	if streamer.get_destroyed_object_ids() != [canonical_ids[0]]:
		failures.append("surface streamer admitted legacy or malformed persisted identity")
	if streamer.is_world_object_destroyed("-2:3:tree:0"):
		failures.append("surface streamer treated legacy identity as destroyed modern state")
	if streamer.destroy_world_object("-2:3:rock:0", "rock", 0, Vector2i.ZERO):
		failures.append("surface streamer mutated world state for legacy object identity")
	streamer.free()


static func _test_reload_suppresses_same_semantic_candidate(failures: Array[String]) -> void:
	var stable_id: String = _surface_id("branch", -8, 12)
	var reloaded = TerrainChunk.new()
	reloaded._branch_transforms = [Transform3D(Basis.IDENTITY, Vector3.ZERO)]
	reloaded._branch_stable_ids = [stable_id]
	var destroyed_indices: Dictionary = {}
	reloaded._load_destroyed_indices(
		"branch",
		reloaded._branch_transforms,
		destroyed_indices,
		{stable_id: true}
	)
	if not destroyed_indices.has(0):
		failures.append("surface reload did not suppress destroyed semantic candidate")
	reloaded._destroyed_branch_indices = destroyed_indices
	if not reloaded.find_nearby_pickups(Vector3.ZERO, 2.0).is_empty():
		failures.append("surface reload re-exposed destroyed pickup candidate")

	reloaded._branch_stable_ids = ["sid1:garbage"]
	if not reloaded._make_object_id("branch", 0).is_empty():
		failures.append("TerrainChunk exposed malformed StableId as runtime object identity")
	reloaded.free()


static func _assert_identity_set(
	domain: String,
	transforms: Array,
	first_ids: Array,
	second_ids: Array,
	failures: Array[String]
) -> void:
	if transforms.is_empty():
		failures.append("surface %s fixture unexpectedly emitted no accepted candidates" % domain)
		return
	if transforms.size() != first_ids.size():
		failures.append("surface %s StableId count diverged from accepted transforms" % domain)
	if first_ids != second_ids:
		failures.append("surface %s StableIds changed across deterministic regeneration" % domain)
	for id_variant in first_ids:
		var stable_id: String = str(id_variant)
		var parsed = StableId.parse(stable_id)
		if parsed == null:
			failures.append("surface %s generator emitted malformed StableId: %s" % [domain, stable_id])
			continue
		var segments: Array[String] = parsed.address().segments()
		if segments.size() < 3 or segments[0] != "surface" or segments[1] != "candidate" or segments[2] != domain:
			failures.append("surface %s generator emitted foreign semantic address: %s" % [domain, stable_id])


static func _pickup_fixture_data(
	resolution: int,
	heights: PackedFloat32Array,
	masks: PackedFloat32Array
) -> Dictionary:
	return {
		"resolution": resolution,
		"spacing": 1.0,
		"collision_heights": heights.duplicate(),
		"forest_density": masks.duplicate(),
		"rockiness": masks.duplicate(),
		"buildability": masks.duplicate(),
	}


static func _surface_id(domain: String, global_cell_x: int, global_cell_z: int) -> String:
	return StableId.from_address(
		StableAddress.surface_candidate(domain, global_cell_x, global_cell_z, "0")
	).value()
