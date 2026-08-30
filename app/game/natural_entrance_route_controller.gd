extends Node
class_name UnderworldNaturalEntranceRouteController

const RouteSelector := preload("res://worldgen/surface/natural_entrance_route_selector.gd")
const GeneratedBootstrap := preload("res://worldgen/runtime/generated_entrance_bootstrap_adapter.gd")

signal route_ready(route: Dictionary)
signal route_failed(diagnostics: Array[String])

var _route: Dictionary = {}
var _diagnostics: Array[String] = []
var _activation_complete: bool = false


func _ready() -> void:
	var game := get_parent()
	if game != null and not game.is_node_ready():
		game.ready.connect(_activate, CONNECT_ONE_SHOT)
	else:
		call_deferred("_activate")


func route_is_ready() -> bool:
	return _activation_complete and not _route.is_empty()


func route_snapshot() -> Dictionary:
	return _route.duplicate(true)


func diagnostics() -> Array[String]:
	return _diagnostics.duplicate()


func _activate() -> void:
	if _activation_complete:
		return
	_activation_complete = true
	var game := get_parent()
	if game == null:
		_fail(["Natural entrance route requires Game parent"])
		return
	if bool(game.get("enable_map015_fixture")):
		# Developer fixture observation remains explicitly separate from the
		# ordinary production route and never contributes player-facing guidance.
		return
	var world_settings = game.get("world_settings")
	var world = game.get("world")
	var player = game.get("player")
	var underworld_runtime = game.get("underworld_runtime")
	if world_settings == null or world == null or player == null or underworld_runtime == null:
		_fail(["Natural entrance route requires initialized world, player and cave runtime"])
		return

	# Route selection is anchored to the deterministic NEW-world start policy,
	# not the current/resumed Player position. Continue therefore reconstructs
	# the same generated entrance without persisting a second route identity.
	var preferred_start := Vector3(
		float(world_settings.chunk_size) * 0.5,
		0.0,
		float(world_settings.chunk_size) * 0.5
	)
	var selection: Dictionary = RouteSelector.select(
		int(world_settings.world_seed),
		preferred_start
	)
	if not bool(selection.get("success", false)):
		_fail(selection.get("diagnostics", []))
		return
	var selected_variant: Variant = selection.get("route", null)
	if not selected_variant is Dictionary:
		_fail(["Natural entrance selector did not return a route Dictionary"])
		return
	var selected: Dictionary = selected_variant
	var region_variant: Variant = selected.get("region_coord", null)
	var entrance_id: String = str(selected.get("entrance_id", ""))
	if not region_variant is Vector2i or entrance_id.is_empty():
		_fail(["Natural entrance route has malformed generated identity"])
		return
	var bootstrap_failures: Array[String] = GeneratedBootstrap.bootstrap(
		underworld_runtime,
		int(world_settings.world_seed),
		region_variant,
		entrance_id
	)
	if not bootstrap_failures.is_empty():
		_fail(bootstrap_failures)
		return
	var expected_surface_variant: Variant = selected.get("surface_world_position", null)
	if not expected_surface_variant is Vector3:
		_fail(["Natural entrance route is missing generated surface position"])
		return
	var expected_surface: Vector3 = expected_surface_variant
	if not underworld_runtime.last_bootstrap_surface_position.is_equal_approx(expected_surface):
		_fail(["Natural entrance runtime bootstrap changed selected surface position"])
		return
	if not underworld_runtime.gate_is_open(entrance_id):
		_fail(["Natural entrance runtime bootstrap did not open traversal gate"])
		return

	_route = selected.duplicate(true)
	_route.make_read_only()

	if str(game.call("startup_mode")) == "new":
		var spawn_variant: Variant = selected.get("recommended_spawn_xz", null)
		if not spawn_variant is Vector3:
			_fail(["Natural entrance route is missing bounded approach spawn"])
			return
		var spawn_xz: Vector3 = spawn_variant
		world.generate_initial(spawn_xz)
		var surface_height: float = world.get_height_at_world(spawn_xz.x, spawn_xz.z)
		player.global_position = Vector3(spawn_xz.x, surface_height + 3.0, spawn_xz.z)
		game.set("spawn_xz", spawn_xz)
		var water_surface = game.get("water_surface")
		if water_surface != null:
			water_surface.global_position.x = spawn_xz.x
			water_surface.global_position.z = spawn_xz.z

	# Refresh the accepted runtime demand against the actual Player position.
	underworld_runtime.update_player_position(player.global_position)
	route_ready.emit(route_snapshot())


func _fail(raw_diagnostics: Array) -> void:
	_route.clear()
	_diagnostics.clear()
	for diagnostic in raw_diagnostics:
		_diagnostics.append(str(diagnostic))
	_diagnostics.sort()
	if _diagnostics.is_empty():
		_diagnostics.append("Natural entrance route failed without diagnostics")
	push_error("Natural entrance route failed: %s" % [_diagnostics])
	route_failed.emit(_diagnostics.duplicate())
