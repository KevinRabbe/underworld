extends "res://app/game/game.gd"

const RouteSelector := preload("res://worldgen/surface/natural_entrance_route_selector.gd")
const GeneratedBootstrap := preload("res://worldgen/runtime/generated_entrance_bootstrap_adapter.gd")
const NaturalWorldSettings := preload("res://world/runtime/config/world_settings.gd")
const NaturalSurvivalSettings := preload("res://gameplay/survival/prototype_survival_settings.gd")
const NaturalWaterSettings := preload("res://presentation/world/environment/prototype_water_settings.gd")
const NaturalWorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const NaturalSurfaceWorld := preload("res://world/runtime/streaming/surface_chunk_streamer.gd")
const NaturalSurvivalController := preload("res://gameplay/survival/integrated_survival_controller.gd")

var _selected_entrance_route: Dictionary = {}
var _natural_route_diagnostics: Array[String] = []
var _surface_initial_bootstrap_count: int = 0
var _natural_route_runtime_bootstrapped: bool = false


func selected_entrance_route_snapshot() -> Dictionary:
	return _selected_entrance_route.duplicate(true)


func natural_entrance_route_ready() -> bool:
	return not _selected_entrance_route.is_empty() and _natural_route_runtime_bootstrapped


func natural_entrance_route_diagnostics() -> Array[String]:
	return _natural_route_diagnostics.duplicate()


func initial_surface_bootstrap_count() -> int:
	return _surface_initial_bootstrap_count


func _create_world() -> void:
	world_settings = NaturalWorldSettings.new()
	if startup_mode() == &"continue":
		world_settings.world_seed = int(_startup_candidate.get("world_seed", 0))
	elif enable_map015_fixture:
		world_settings.world_seed = 1
	survival_settings = NaturalSurvivalSettings.new()
	water_settings = NaturalWaterSettings.new()

	if startup_mode() == &"continue":
		world_delta_store = _startup_candidate.get("delta_store", null)
	else:
		world_delta_store = NaturalWorldDeltaStore.new()
	if world_delta_store == null or not world_delta_store is NaturalWorldDeltaStore:
		push_error("Game startup is missing valid WorldDeltaStore authority")
		world_delta_store = NaturalWorldDeltaStore.new()

	world = NaturalSurfaceWorld.new()
	world.name = "SurfaceWorld"
	if not world.bind_world_delta_store(world_delta_store):
		push_error("Surface world rejected WorldDeltaStore authority")
	world.configure(world_settings)
	add_child(world)

	survival = NaturalSurvivalController.new()
	survival.name = "PrototypeSurvival"
	add_child(survival)
	survival.configure_integrated(world, survival_settings, world_settings.world_seed)
	if startup_mode() == &"continue":
		var restore_failures: Array[String] = survival.activate_restored_state(
			_startup_candidate.get("inventory_state", null),
			_startup_candidate.get("equipment_state", null)
		)
		if not restore_failures.is_empty():
			push_error("Detached Continue state failed during activation: %s" % [restore_failures])

	_resolve_natural_route()
	if startup_mode() == &"continue":
		var resume_position: Vector3 = _startup_candidate.get("resume_position", Vector3.ZERO)
		spawn_xz = Vector3(resume_position.x, 0.0, resume_position.z)
	elif enable_map015_fixture:
		var fixture_preferred: Vector3 = Vector3(
			world_settings.chunk_size * 0.5,
			0.0,
			world_settings.chunk_size * 0.5
		)
		spawn_xz = world.find_spawn_xz(fixture_preferred)
	elif not _selected_entrance_route.is_empty():
		spawn_xz = _selected_entrance_route.get("recommended_spawn_xz", Vector3.ZERO)
	else:
		var preferred_spawn: Vector3 = Vector3(
			world_settings.chunk_size * 0.5,
			0.0,
			world_settings.chunk_size * 0.5
		)
		spawn_xz = world.find_spawn_xz(preferred_spawn)

	world.generate_initial(spawn_xz)
	_surface_initial_bootstrap_count += 1
	_create_water_surface()


func _create_underworld_runtime() -> void:
	super._create_underworld_runtime()
	if enable_map015_fixture or _selected_entrance_route.is_empty():
		return
	var region_variant: Variant = _selected_entrance_route.get("region_coord", null)
	var entrance_id: String = str(_selected_entrance_route.get("entrance_id", ""))
	if not region_variant is Vector2i or entrance_id.is_empty():
		_record_route_failure(["Natural entrance route has malformed generated identity"])
		return
	var diagnostics: Array[String] = GeneratedBootstrap.bootstrap(
		underworld_runtime,
		int(world_settings.world_seed),
		region_variant,
		entrance_id
	)
	if not diagnostics.is_empty():
		_record_route_failure(diagnostics)
		return
	var expected_surface_variant: Variant = _selected_entrance_route.get("surface_world_position", null)
	if not expected_surface_variant is Vector3:
		_record_route_failure(["Natural entrance route is missing generated surface position"])
		return
	var expected_surface: Vector3 = expected_surface_variant
	if not underworld_runtime.last_bootstrap_surface_position.is_equal_approx(expected_surface):
		_record_route_failure(["Natural entrance runtime bootstrap changed selected surface position"])
		return
	underworld_runtime.update_player_position(player.global_position)
	if startup_mode() == &"new" and not underworld_runtime.gate_is_open(entrance_id):
		_record_route_failure(["Natural entrance approach spawn fell outside traversal readiness window"])
		return
	_natural_route_runtime_bootstrapped = true


func _resolve_natural_route() -> void:
	_selected_entrance_route = {}
	_natural_route_diagnostics.clear()
	_natural_route_runtime_bootstrapped = false
	if enable_map015_fixture:
		return
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
		_record_route_failure(selection.get("diagnostics", []))
		return
	var route_variant: Variant = selection.get("route", null)
	if not route_variant is Dictionary:
		_record_route_failure(["Natural entrance selector did not return a route Dictionary"])
		return
	_selected_entrance_route = route_variant.duplicate(true)
	_selected_entrance_route.make_read_only()


func _record_route_failure(raw_diagnostics: Array) -> void:
	_natural_route_diagnostics.clear()
	for diagnostic in raw_diagnostics:
		_natural_route_diagnostics.append(str(diagnostic))
	_natural_route_diagnostics.sort()
	if _natural_route_diagnostics.is_empty():
		_natural_route_diagnostics.append("Natural entrance route failed without diagnostics")
	push_error("Natural entrance route failed: %s" % [_natural_route_diagnostics])