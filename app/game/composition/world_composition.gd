extends RefCounted

const WorldSettingsScript := preload("res://world/runtime/config/world_settings.gd")
const SurvivalSettingsScript := preload("res://gameplay/survival/prototype_survival_settings.gd")
const WaterSettingsScript := preload("res://presentation/world/environment/prototype_water_settings.gd")
const SurfaceChunkStreamerScript := preload("res://world/runtime/streaming/surface_chunk_streamer.gd")
const WorldDeltaStoreScript := preload("res://worldgen/persistence/world_delta_store.gd")
const IntegratedSurvivalControllerScript := preload("res://gameplay/survival/integrated_survival_controller.gd")


static func compose(
	root: Node3D,
	session_world_context,
	startup_candidate: Dictionary,
	is_continue: bool,
	enable_map015_fixture: bool
) -> Dictionary:
	var diagnostics: Array[String] = []
	var world_settings = WorldSettingsScript.new()
	if session_world_context != null:
		world_settings.world_seed = int(session_world_context.world_seed)
	elif enable_map015_fixture:
		world_settings.world_seed = 1
	var survival_settings = SurvivalSettingsScript.new()
	var water_settings = WaterSettingsScript.new()

	var world_delta_store
	if is_continue:
		world_delta_store = startup_candidate.get("delta_store", null)
	else:
		world_delta_store = WorldDeltaStoreScript.new()
	if world_delta_store == null or not world_delta_store is WorldDeltaStoreScript:
		diagnostics.append("Game startup is missing valid WorldDeltaStore authority")
		world_delta_store = WorldDeltaStoreScript.new()

	var world = SurfaceChunkStreamerScript.new()
	world.name = "SurfaceWorld"
	if not world.bind_world_delta_store(world_delta_store):
		diagnostics.append("Surface world rejected WorldDeltaStore authority")
	world.configure(world_settings)
	root.add_child(world)

	var survival = IntegratedSurvivalControllerScript.new()
	survival.name = "PrototypeSurvival"
	root.add_child(survival)
	survival.configure_integrated(world, survival_settings, world_settings.world_seed)
	if is_continue:
		var restore_failures: Array[String] = survival.activate_restored_state(
			startup_candidate.get("inventory_state", null),
			startup_candidate.get("equipment_state", null)
		)
		if not restore_failures.is_empty():
			diagnostics.append("Detached Continue state failed during activation: %s" % [restore_failures])

	return {
		"success": diagnostics.is_empty(),
		"diagnostics": diagnostics,
		"world_settings": world_settings,
		"survival_settings": survival_settings,
		"water_settings": water_settings,
		"world_delta_store": world_delta_store,
		"world": world,
		"survival": survival,
	}
