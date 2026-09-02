extends RefCounted

const PlayerScript := preload("res://gameplay/player/player.gd")
const PlayerPlacementProfileScript := preload("res://gameplay/player/player_placement_profile.gd")
const DeathRecoveryControllerScript := preload("res://gameplay/player/lifecycle/player_death_recovery_controller.gd")
const SurfaceChunkStreamerScript := preload("res://world/runtime/streaming/surface_chunk_streamer.gd")
const WorldSettingsScript := preload("res://world/runtime/config/world_settings.gd")

const PHYSICS_STEP: float = 1.0 / 60.0
const MAX_SETTLE_STEPS: int = 240


static func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	if tree == null or tree.root == null:
		return ["death recovery physics proof requires SceneTree root"]

	var fixture_root := Node3D.new()
	fixture_root.name = "DeathRecoveryPhysicsFixture"
	tree.root.add_child(fixture_root)

	var settings = WorldSettingsScript.new()
	var world = SurfaceChunkStreamerScript.new()
	world.name = "SurfaceWorld"
	world.configure(settings)
	fixture_root.add_child(world)

	var preferred := Vector3(settings.chunk_size * 0.5, 0.0, settings.chunk_size * 0.5)
	var placement: Dictionary = world.resolve_spawn_xz(preferred)
	if not bool(placement.get("success", false)):
		failures.append("real surface placement authority could not resolve physics fixture target: %s" % [
			placement.get("diagnostics", []),
		])
		fixture_root.free()
		return failures
	var xz: Vector3 = placement.get("xz", Vector3.ZERO)
	var surface_height: float = float(placement.get("surface_height", NAN))
	if not _is_finite_vector3(xz) or is_nan(surface_height) or is_inf(surface_height):
		failures.append("real surface placement authority returned non-finite physics target")
		fixture_root.free()
		return failures

	# Real terrain is present before defeat. Recovery itself must still prepare the
	# eventual target-local collision/proxies without relying on Player movement.
	world.generate_initial(xz)
	var player = PlayerScript.new()
	player.name = "Player"
	fixture_root.add_child(player)
	player.global_position = Vector3(xz.x, surface_height + 3.0, xz.z)
	world.set_player(player)

	var profile = PlayerPlacementProfileScript.new()
	var profile_failures: Array[String] = profile.configure_from_player(player)
	if not profile_failures.is_empty():
		failures.append("real physics proof could not derive live Player placement profile: %s" % [profile_failures])
		fixture_root.free()
		return failures

	var recovery = DeathRecoveryControllerScript.new()
	recovery.name = "DeathRecovery"
	fixture_root.add_child(recovery)
	var config_failures: Array[String] = recovery.configure(player, world, settings)
	if not config_failures.is_empty():
		failures.append("real death recovery physics fixture rejected production authorities: %s" % [config_failures])
		fixture_root.free()
		return failures

	if not bool(player.call("_enter_defeated", &"damage")):
		failures.append("real Player could not enter defeated state for physics recovery proof")
		fixture_root.free()
		return failures
	var defeated_position: Vector3 = player.global_position
	var resolved_only: Dictionary = recovery.resolve_safe_target(defeated_position)
	if not bool(resolved_only.get("success", false)):
		failures.append("real recovery target resolution failed before readiness proof: %s" % [
			resolved_only.get("diagnostics", []),
		])
	elif player.global_position != defeated_position or not bool(player.call("is_defeated")):
		failures.append("real target resolution mutated defeated Player before readiness")

	if not recovery.request_recovery(&"damage"):
		failures.append("real recovery controller rejected physics proof request")
		fixture_root.free()
		return failures
	var committed: Dictionary = recovery.try_commit_recovery()
	if not bool(committed.get("success", false)):
		failures.append("real recovery controller could not commit prepared deterministic physics target: %s" % [
			committed.get("diagnostics", []),
		])
		fixture_root.free()
		return failures
	var committed_target: Vector3 = committed.get("target", Vector3.ZERO)
	if not committed_target.is_equal_approx(player.global_position):
		failures.append("real recovery result target differs from committed Player target")

	# Keep the existing one-frame CI contract while exercising production
	# CharacterBody3D physics. The prepared target starts only a small profile-owned
	# settlement margin above support and must remain stable through multiple steps.
	var supported_steps: int = 0
	for _step in range(MAX_SETTLE_STEPS):
		player.call("_physics_process", PHYSICS_STEP)
		if player.is_on_floor():
			supported_steps += 1
			if supported_steps >= 3:
				break
		else:
			supported_steps = 0

	if supported_steps < 3 or not player.is_on_floor():
		failures.append("recovered real Player did not settle onto valid terrain support")
	if bool(player.call("is_defeated")):
		failures.append("recovered real Player re-entered defeated state during physics settlement")
	if String(player.call("get_action_state_name")) != "FREE":
		failures.append("recovered real Player is not gameplay-capable after physics settlement")
	if int(player.call("get_health")) != int(player.call("get_max_health")):
		failures.append("recovered real Player did not retain restored health through physics settlement")
	if absf(player.global_position.y - committed_target.y) > profile.floor_snap_length() + profile.settlement_margin():
		failures.append("recovered real Player settled outside profile-owned snap envelope")

	# Refresh production proxy realization at the settled position, then inspect the
	# live physics space with a slightly shrunken copy of the actual Player capsule.
	world.call("_update_world_object_physics")
	if _world_object_overlap_count(player, profile) != 0:
		failures.append("recovered real Player intersects a realized tree/rock world-object collider")
	var final_placement: Dictionary = world.query_player_placement_xz(
		Vector3(player.global_position.x, 0.0, player.global_position.z),
		profile
	)
	if not bool(final_placement.get("success", false)):
		failures.append("settled real Player no longer satisfies live-profile deterministic placement viability")

	fixture_root.free()
	return failures


static func _world_object_overlap_count(player: CharacterBody3D, profile) -> int:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = profile.make_capsule_shape(0.01)
	query.transform = Transform3D(
		Basis.IDENTITY,
		player.global_position + Vector3(0.0, profile.capsule_center_y(), 0.0)
	)
	query.collision_mask = profile.collision_mask()
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	var hits: Array[Dictionary] = player.get_world_3d().direct_space_state.intersect_shape(query, 32)
	var world_object_hits: int = 0
	for hit in hits:
		var collider = hit.get("collider", null)
		if collider != null and collider.has_meta("world_object_type"):
			world_object_hits += 1
	return world_object_hits


static func _is_finite_vector3(value: Vector3) -> bool:
	return (
		not is_nan(value.x) and not is_inf(value.x)
		and not is_nan(value.y) and not is_inf(value.y)
		and not is_nan(value.z) and not is_inf(value.z)
	)
