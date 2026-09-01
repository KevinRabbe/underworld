extends RefCounted

const PlayerScript := preload("res://gameplay/player/player.gd")
const PlayerPlacementProfileScript := preload("res://gameplay/player/player_placement_profile.gd")
const SurfaceChunkStreamerScript := preload("res://world/runtime/streaming/surface_chunk_streamer.gd")
const WorldSettingsScript := preload("res://world/runtime/config/world_settings.gd")
const WorldDeltaStoreScript := preload("res://worldgen/persistence/world_delta_store.gd")


class FakePlacementGenerator:
	extends RefCounted
	var sample: Dictionary = {
		"height": 10.0,
		"slope": 0.0,
		"buildability": 1.0,
		"rockiness": 0.0,
		"moisture": 0.4,
		"forest_density": 0.0,
	}

	func get_surface_sample(_x: float, _z: float) -> Dictionary:
		return sample.duplicate(true)

	func generate_chunk_data(_coord: Vector2i) -> Dictionary:
		return {
			"tree_transforms": [],
			"tree_stable_ids": [],
			"rock_transforms": [],
			"rock_stable_ids": [],
		}


static func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_malformed_profiles_fail_closed(failures)
	_test_live_floor_angle_changes_surface_viability(tree, failures)
	return failures


static func _test_malformed_profiles_fail_closed(failures: Array[String]) -> void:
	var fixture: Dictionary = _make_world()
	var world = fixture["world"]
	var candidate := Vector3(32.0, 0.0, 32.0)

	var radius_nan = PlayerPlacementProfileScript.new()
	radius_nan.set("_capsule_radius", NAN)
	_expect_profile_rejected(failures, "NaN capsule radius", world, candidate, radius_nan)

	var height_inf = PlayerPlacementProfileScript.new()
	height_inf.set("_capsule_height", INF)
	_expect_profile_rejected(failures, "INF capsule height", world, candidate, height_inf)

	var center_nan = PlayerPlacementProfileScript.new()
	center_nan.set("_capsule_center_y", NAN)
	_expect_profile_rejected(failures, "NaN capsule center", world, candidate, center_nan)

	var floor_angle_nan = PlayerPlacementProfileScript.new()
	floor_angle_nan.set("_floor_max_angle", NAN)
	_expect_profile_rejected(failures, "NaN floor angle", world, candidate, floor_angle_nan)

	var floor_snap_inf = PlayerPlacementProfileScript.new()
	floor_snap_inf.set("_floor_snap_length", INF)
	_expect_profile_rejected(failures, "INF floor snap", world, candidate, floor_snap_inf)

	var zero_mask = PlayerPlacementProfileScript.new()
	zero_mask.set("_collision_mask", 0)
	_expect_profile_rejected(failures, "zero collision mask", world, candidate, zero_mask)

	var non_surface_mask = PlayerPlacementProfileScript.new()
	non_surface_mask.set("_collision_mask", 2)
	_expect_profile_rejected(failures, "non-surface collision mask", world, candidate, non_surface_mask)

	world.free()


static func _test_live_floor_angle_changes_surface_viability(tree: SceneTree, failures: Array[String]) -> void:
	if tree == null or tree.root == null:
		failures.append("live placement-profile discrimination requires SceneTree root")
		return

	var fixture_root := Node3D.new()
	tree.root.add_child(fixture_root)
	var player = PlayerScript.new()
	fixture_root.add_child(player)

	var default_profile = PlayerPlacementProfileScript.new()
	player.floor_max_angle = deg_to_rad(20.0)
	var live_profile = PlayerPlacementProfileScript.new()
	var profile_failures: Array[String] = live_profile.configure_from_player(player)
	if not profile_failures.is_empty():
		failures.append("non-default live Player profile failed to configure: %s" % [profile_failures])
		fixture_root.free()
		return

	var fixture: Dictionary = _make_world()
	var world = fixture["world"]
	var generator: FakePlacementGenerator = fixture["generator"]
	generator.sample["slope"] = 0.15
	var candidate := Vector3(32.0, 0.0, 32.0)

	var default_result: Dictionary = world.query_player_placement_xz(candidate, default_profile)
	var live_result: Dictionary = world.query_player_placement_xz(candidate, live_profile)
	if not bool(default_result.get("success", false)):
		failures.append("default 50-degree placement profile did not accept discrimination slope")
	if bool(live_result.get("success", false)):
		failures.append("production surface placement ignored non-default live Player floor angle")
	if not is_equal_approx(float(live_profile.floor_max_angle()), deg_to_rad(20.0)):
		failures.append("live placement profile did not retain modified real Player floor angle")

	world.free()
	fixture_root.free()


static func _make_world() -> Dictionary:
	var settings = WorldSettingsScript.new()
	settings.chunk_size = 64.0
	settings.sea_level = 0.0
	var world = SurfaceChunkStreamerScript.new()
	world.configure(settings)
	var generator := FakePlacementGenerator.new()
	world.set("main_generator", generator)
	world.bind_world_delta_store(WorldDeltaStoreScript.new())
	return {"world": world, "generator": generator}


static func _expect_profile_rejected(
	failures: Array[String],
	label: String,
	world,
	candidate: Vector3,
	profile
) -> void:
	var validation: Array[String] = profile.validate()
	if validation.is_empty():
		failures.append("%s profile validation unexpectedly passed" % label)
	var placement: Dictionary = world.query_player_placement_xz(candidate, profile)
	if bool(placement.get("success", false)):
		failures.append("%s reached semantic surface placement" % label)
