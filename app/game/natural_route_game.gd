extends "res://app/game/game.gd"

const NaturalEntranceRouteSelector := preload("res://worldgen/runtime/natural_entrance_route_selector.gd")
const SelectedEntranceBootstrap := preload("res://worldgen/runtime/selected_entrance_bootstrap.gd")

var _selected_entrance_route: Dictionary = {}


func _create_underworld_runtime() -> void:
	super._create_underworld_runtime()
	if enable_map015_fixture or startup_mode() != STARTUP_NEW:
		return
	_initialize_natural_entrance_route()


func selected_entrance_route_snapshot() -> Dictionary:
	return _selected_entrance_route.duplicate(true)


func _initialize_natural_entrance_route() -> void:
	if underworld_runtime == null or world == null or player == null or world_settings == null:
		push_error("Natural entrance route requires initialized Game authorities")
		return
	var selection: Dictionary = NaturalEntranceRouteSelector.select_route(
		int(world_settings.world_seed),
		spawn_xz
	)
	if not bool(selection.get("success", false)):
		push_error("Natural entrance selection failed: %s" % [selection.get("diagnostics", [])])
		return
	var bootstrap: Dictionary = SelectedEntranceBootstrap.bootstrap(
		underworld_runtime,
		int(world_settings.world_seed),
		selection
	)
	if not bool(bootstrap.get("success", false)):
		push_error("Natural entrance bootstrap failed: %s" % [bootstrap.get("diagnostics", [])])
		return

	var surface_position: Vector3 = selection.get("surface_world_position", Vector3.ZERO)
	if not _finite_route_vector(surface_position):
		push_error("Natural entrance selection returned non-finite surface position")
		return
	spawn_xz = Vector3(surface_position.x, 0.0, surface_position.z)
	world.generate_initial(spawn_xz)
	var surface_height: float = world.get_height_at_world(spawn_xz.x, spawn_xz.z)
	if is_nan(surface_height) or is_inf(surface_height):
		push_error("Natural entrance surface height is non-finite")
		return
	var clearance := maxf(3.0, float(selection.get("clearance", 0.0)) + 0.65)
	player.global_position = Vector3(spawn_xz.x, surface_height + clearance, spawn_xz.z)
	world.set_player(player)
	if water_surface != null:
		water_surface.position.x = spawn_xz.x
		water_surface.position.z = spawn_xz.z

	_selected_entrance_route = {
		"entrance_id": str(selection.get("entrance_id", "")),
		"region": selection.get("region", Vector2i.ZERO),
		"slot": int(selection.get("slot", -1)),
		"surface_world_position": surface_position,
		"spawn_position": player.global_position,
		"distance_squared": float(selection.get("distance_squared", 0.0)),
		"descriptor_data": selection.get("descriptor_data", {}).duplicate(true),
		"entrance_stage_fingerprint": str(selection.get("entrance_stage_fingerprint", "")),
		"bootstrap_fingerprint": str(bootstrap.get("bootstrap_fingerprint", "")),
		"scanned_regions": int(selection.get("scanned_regions", 0)),
	}


static func _finite_route_vector(value: Vector3) -> bool:
	return (
		not is_nan(value.x) and not is_inf(value.x)
		and not is_nan(value.y) and not is_inf(value.y)
		and not is_nan(value.z) and not is_inf(value.z)
	)
