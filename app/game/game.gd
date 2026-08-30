extends Node3D

const WorldSettingsScript := preload("res://world/runtime/config/world_settings.gd")
const SurvivalSettingsScript := preload("res://gameplay/survival/prototype_survival_settings.gd")
const WaterSettingsScript := preload("res://presentation/world/environment/prototype_water_settings.gd")
const CavePresentationControllerScript := preload("res://presentation/world/caves/cave_presentation_controller.gd")
const PrototypeCavePresentationCatalog := preload("res://content/presentation/caves/prototype_cave_presentation_catalog.tres")
const SurfaceChunkStreamerScript := preload("res://world/runtime/streaming/surface_chunk_streamer.gd")
const WorldDeltaStoreScript := preload("res://worldgen/persistence/world_delta_store.gd")
const IntegratedGameSaveContractScript := preload("res://gameplay/persistence/integrated_game_save_contract.gd")
const IntegratedSurvivalControllerScript := preload("res://gameplay/survival/integrated_survival_controller.gd")
const ItemContainerStateScript := preload("res://gameplay/items/inventory/item_container_state.gd")
const EquipmentHotbarStateScript := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const PendingLootStateScript := preload("res://gameplay/loot/runtime/pending_loot_state.gd")
const PlayerScript := preload("res://gameplay/player/player.gd")
const CombatResolverScript := preload("res://gameplay/combat/resolution/combat_resolver.gd")
const BurrowerEncounterControllerScript := preload("res://gameplay/creatures/spawning/prototype_burrower_encounter_controller.gd")
const GameplayHudScript := preload("res://presentation/ui/hud/gameplay_hud.gd")
const DebugHudScript := preload("res://presentation/ui/debug/debug_hud.gd")
const UnderworldRuntimeControllerScript := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const WorldIdScript := preload("res://worldgen/identity/world_id.gd")
const GeneratorManifestScript := preload("res://worldgen/versioning/generator_manifest.gd")
const Map015FixtureScript := preload("res://worldgen/validation/map015_fixture.gd")

const STARTUP_NEW: StringName = &"new"
const STARTUP_CONTINUE: StringName = &"continue"
const LOOT_COLLECTION_POLL_INTERVAL := 0.1

var world_settings
var survival_settings
var water_settings
var world
var world_delta_store
var survival
var player
var combat_resolver
var encounter_controller
var gameplay_hud
var debug_hud
var water_surface: MeshInstance3D
var underworld_runtime
var cave_presentation
var spawn_xz: Vector3 = Vector3.ZERO
var loot_collection_poll_timer: float = 0.0
@export var enable_map015_fixture: bool = false
@export var enable_debug_hud: bool = true

var _startup_prepared: bool = false
var _startup_mode: StringName = STARTUP_NEW
var _startup_candidate: Dictionary = {}
var _restored_pending_loot_state = null


func prepare_new_game() -> bool:
	if is_inside_tree():
		push_error("Game startup must be prepared before entering the SceneTree")
		return false
	_startup_mode = STARTUP_NEW
	_startup_candidate.clear()
	_restored_pending_loot_state = null
	_startup_prepared = true
	return true


func prepare_continue(candidate: Dictionary) -> bool:
	if is_inside_tree():
		push_error("Continue startup must be prepared before Game enters the SceneTree")
		return false
	if enable_map015_fixture:
		push_error("MAP-015 developer fixture cannot be combined with durable Continue state")
		return false

	# AppRoot supplies a detached decoded candidate, but Game is a second durable
	# ownership boundary. Clone through the strict SAVE contract before retaining
	# anything so caller mutation after preparation cannot alias live runtime.
	var clone_result: Dictionary = IntegratedGameSaveContractScript.clone_candidate(candidate)
	if not bool(clone_result.get("success", false)):
		for diagnostic in clone_result.get("diagnostics", []):
			push_error("Continue preparation clone rejected: %s" % diagnostic)
		return false
	var owned_candidate_variant: Variant = clone_result.get("candidate", null)
	if not owned_candidate_variant is Dictionary:
		push_error("Continue preparation clone did not return a candidate Dictionary")
		return false
	var owned_candidate: Dictionary = owned_candidate_variant
	var failures: Array[String] = _validate_continue_candidate(owned_candidate)
	failures.append_array(_preflight_pending_loot_restore(owned_candidate))
	if not failures.is_empty():
		for failure in failures:
			push_error("Continue preparation rejected: %s" % failure)
		return false
	_startup_mode = STARTUP_CONTINUE
	_startup_candidate = owned_candidate
	_restored_pending_loot_state = _startup_candidate.get("pending_loot_state", null)
	_startup_prepared = true
	return true


func startup_mode() -> StringName:
	return _startup_mode


func restored_pending_loot_state():
	return _restored_pending_loot_state


func _ready() -> void:
	# Direct developer/test loading of game.tscn retains clean NEW semantics. The
	# production AppRoot path always calls prepare_new_game()/prepare_continue()
	# while Game is detached, before this method can execute.
	if not _startup_prepared:
		_startup_mode = STARTUP_NEW
		_startup_candidate.clear()
		_restored_pending_loot_state = null
		_startup_prepared = true
	_setup_environment()
	_create_world()
	_create_player()
	_create_underworld_runtime()
	_create_combat()
	_create_gameplay_hud()
	_create_debug_hud()


func _process(delta: float) -> void:
	if water_surface != null and player != null:
		water_surface.global_position.x = player.global_position.x
		water_surface.global_position.z = player.global_position.z
	if underworld_runtime != null and player != null:
		underworld_runtime.update_player_position(player.global_position)
	loot_collection_poll_timer = maxf(0.0, loot_collection_poll_timer - delta)
	if loot_collection_poll_timer <= 0.0:
		loot_collection_poll_timer = LOOT_COLLECTION_POLL_INTERVAL
		_collect_nearby_pending_loot()


func _collect_nearby_pending_loot() -> void:
	if encounter_controller == null or survival == null:
		return
	if encounter_controller.get_pending_loot_count() <= 0:
		return
	var inventory_state = survival.get_inventory_state()
	if inventory_state == null:
		return
	encounter_controller.collect_nearby_pending_loot(inventory_state)


func _create_underworld_runtime() -> void:
	underworld_runtime = UnderworldRuntimeControllerScript.new()
	underworld_runtime.name = "UnderworldRuntime"
	add_child(underworld_runtime)
	var world_id: String = WorldIdScript.from_seed(world_settings.world_seed).value()
	var manifest_id: String = GeneratorManifestScript.foundation_default().manifest_id()
	underworld_runtime.configure(world_id, manifest_id, player)

	cave_presentation = CavePresentationControllerScript.new()
	cave_presentation.name = "CavePresentation"
	add_child(cave_presentation)
	var presentation_failures: Array[String] = cave_presentation.configure(
		underworld_runtime,
		PrototypeCavePresentationCatalog
	)
	if not presentation_failures.is_empty():
		push_error("Cave presentation configuration failed: %s" % [presentation_failures])

	if enable_map015_fixture:
		var entrance_id: String = Map015FixtureScript.ENTRANCE_ID
		var diagnostics: Array[String] = underworld_runtime.bootstrap_fixture(1, Map015FixtureScript.REGION, entrance_id)
		if diagnostics.is_empty():
			spawn_xz = underworld_runtime.last_bootstrap_surface_position
			world.generate_initial(spawn_xz)
			var surface_height: float = world.get_height_at_world(spawn_xz.x, spawn_xz.z)
			player.global_position = Vector3(spawn_xz.x, surface_height + 3.0, spawn_xz.z)
			player.set_respawn_position(player.global_position)
			if water_surface != null:
				water_surface.position.x = spawn_xz.x
				water_surface.position.z = spawn_xz.z


func _setup_environment() -> void:
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"

	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.56, 0.72, 0.86)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.76, 0.82)
	environment.ambient_light_energy = 0.8
	world_environment.environment = environment
	add_child(world_environment)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)


func _create_world() -> void:
	world_settings = WorldSettingsScript.new()
	if _startup_mode == STARTUP_CONTINUE:
		world_settings.world_seed = int(_startup_candidate.get("world_seed", 0))
	elif enable_map015_fixture:
		world_settings.world_seed = 1
	survival_settings = SurvivalSettingsScript.new()
	water_settings = WaterSettingsScript.new()

	if _startup_mode == STARTUP_CONTINUE:
		world_delta_store = _startup_candidate.get("delta_store", null)
	else:
		world_delta_store = WorldDeltaStoreScript.new()
	if world_delta_store == null or not world_delta_store is WorldDeltaStoreScript:
		push_error("Game startup is missing valid WorldDeltaStore authority")
		world_delta_store = WorldDeltaStoreScript.new()

	world = SurfaceChunkStreamerScript.new()
	world.name = "SurfaceWorld"
	if not world.bind_world_delta_store(world_delta_store):
		push_error("Surface world rejected WorldDeltaStore authority")
	world.configure(world_settings)
	add_child(world)

	# Gameplay uses the integrated adapter only for detached restore activation;
	# the inherited prototype gameplay controller itself has no file authority.
	survival = IntegratedSurvivalControllerScript.new()
	survival.name = "PrototypeSurvival"
	add_child(survival)
	survival.configure_integrated(world, survival_settings, world_settings.world_seed)
	if _startup_mode == STARTUP_CONTINUE:
		var restore_failures: Array[String] = survival.activate_restored_state(
			_startup_candidate.get("inventory_state", null),
			_startup_candidate.get("equipment_state", null)
		)
		if not restore_failures.is_empty():
			push_error("Detached Continue state failed during activation: %s" % [restore_failures])

	if _startup_mode == STARTUP_CONTINUE:
		var resume_position: Vector3 = _startup_candidate.get("resume_position", Vector3.ZERO)
		spawn_xz = Vector3(resume_position.x, 0.0, resume_position.z)
	else:
		var preferred_spawn: Vector3 = Vector3(
			world_settings.chunk_size * 0.5,
			0.0,
			world_settings.chunk_size * 0.5
		)
		spawn_xz = world.find_spawn_xz(preferred_spawn)
	world.generate_initial(spawn_xz)
	_create_water_surface()


func _create_water_surface() -> void:
	water_surface = MeshInstance3D.new()
	water_surface.name = "PrototypeSea"

	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(water_settings.water_plane_size, water_settings.water_plane_size)
	water_surface.mesh = plane

	var water_material: StandardMaterial3D = StandardMaterial3D.new()
	water_material.albedo_color = Color(0.08, 0.30, 0.48, 0.72)
	water_material.roughness = 0.18
	water_material.metallic = 0.05
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_surface.material_override = water_material
	water_surface.position = Vector3(
		spawn_xz.x,
		world_settings.sea_level + 0.03,
		spawn_xz.z
	)
	add_child(water_surface)


func _create_player() -> void:
	player = PlayerScript.new()
	player.name = "Player"
	add_child(player)

	var spawn_position: Vector3
	if _startup_mode == STARTUP_CONTINUE:
		spawn_position = _startup_candidate.get("resume_position", Vector3.ZERO)
	else:
		var spawn_height: float = world.get_height_at_world(spawn_xz.x, spawn_xz.z)
		spawn_position = Vector3(spawn_xz.x, spawn_height + 3.0, spawn_xz.z)
	player.global_position = spawn_position
	player.set_respawn_position(spawn_position)
	player.set_harvest_range(survival_settings.harvest_range)
	player.set_tool_use_cooldown(survival_settings.tool_use_cooldown)
	player.harvest_requested.connect(survival.try_harvest)
	player.hotbar_slot_requested.connect(survival.select_hotbar_slot)
	player.craft_requested.connect(survival.request_craft)
	survival.equipped_tool_changed.connect(player.set_equipped_tool)
	world.set_player(player)
	survival.set_player(player)
	player.set_equipped_tool(survival.get_equipped_tool())


func _create_combat() -> void:
	combat_resolver = CombatResolverScript.new()
	combat_resolver.name = "CombatResolver"
	add_child(combat_resolver)
	combat_resolver.configure(player)
	player.attack_requested.connect(combat_resolver.try_attack)

	encounter_controller = BurrowerEncounterControllerScript.new()
	encounter_controller.name = "BurrowerEncounters"
	add_child(encounter_controller)
	encounter_controller.configure(world, player, world_settings)
	if _startup_mode == STARTUP_CONTINUE and _restored_pending_loot_state != null:
		var import_result: Dictionary = encounter_controller.import_pending_loot_states(
			[_restored_pending_loot_state],
			_startup_candidate.get("resume_position", Vector3.ZERO)
		)
		if not bool(import_result.get("success", false)):
			push_error("SAVE hard invariant: preflighted pending loot failed live import: %s" % [
				import_result.get("diagnostics", []),
			])


func _create_gameplay_hud() -> void:
	gameplay_hud = GameplayHudScript.new()
	gameplay_hud.name = "GameplayHUD"
	add_child(gameplay_hud)
	var hud_failures: Array[String] = gameplay_hud.configure(
		player,
		survival.get_inventory_state(),
		survival.get_equipment_state()
	)
	if not hud_failures.is_empty():
		push_error("Gameplay HUD configuration failed: %s" % [hud_failures])
	survival.harvest_result.connect(gameplay_hud.present_feedback)
	player.parry_succeeded.connect(_on_player_parry_succeeded)


func _on_player_parry_succeeded(_source_position: Vector3) -> void:
	if gameplay_hud == null:
		return
	gameplay_hud.present_feedback({"type": "combat.parry_succeeded"})


func _create_debug_hud() -> void:
	if not enable_debug_hud:
		return
	debug_hud = DebugHudScript.new()
	debug_hud.name = "DebugHUD"
	debug_hud.configure(
		world,
		player,
		world_settings,
		survival,
		combat_resolver,
		encounter_controller,
		underworld_runtime
	)
	add_child(debug_hud)


func _preflight_pending_loot_restore(candidate: Dictionary) -> Array[String]:
	var pending_loot_state = candidate.get("pending_loot_state", null)
	if pending_loot_state == null:
		return []
	var recovery_anchor_variant: Variant = candidate.get("resume_position", null)
	if not recovery_anchor_variant is Vector3:
		return ["pending loot restore requires Vector3 recovery anchor"]

	# Run the accepted #272 import semantics on a detached temporary controller.
	# This validates canonical Burrower occurrence identity, finite recovery anchor,
	# authored loot registry compatibility and deep-owned import before AppRoot is
	# allowed to detach Title and attach the real Game scene.
	var preflight_settings = WorldSettingsScript.new()
	preflight_settings.world_seed = int(candidate.get("world_seed", 0))
	var preflight_controller = BurrowerEncounterControllerScript.new()
	preflight_controller.configure(null, null, preflight_settings)
	var result: Dictionary = preflight_controller.import_pending_loot_states(
		[pending_loot_state],
		recovery_anchor_variant
	)
	preflight_controller.free()
	if bool(result.get("success", false)):
		return []
	var failures: Array[String] = []
	for diagnostic in result.get("diagnostics", []):
		failures.append("pending loot restore: %s" % diagnostic)
	failures.sort()
	return failures


func _validate_continue_candidate(candidate: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var world_context = candidate.get("world_context", null)
	var world_seed_variant: Variant = candidate.get("world_seed", null)
	var world_id: String = str(candidate.get("world_id", ""))
	var delta_store = candidate.get("delta_store", null)
	var inventory_state = candidate.get("inventory_state", null)
	var equipment_state = candidate.get("equipment_state", null)
	var pending_loot_state = candidate.get("pending_loot_state", null)
	var resume_variant: Variant = candidate.get("resume_position", null)

	if world_context == null or not world_context.has_method("validate"):
		failures.append("candidate world context is missing")
	elif not world_context.validate().is_empty():
		failures.append("candidate world context is invalid")
	if typeof(world_seed_variant) != TYPE_INT:
		failures.append("candidate world seed must be exact int")
	elif world_context != null and int(world_seed_variant) != int(world_context.world_seed):
		failures.append("candidate world seed does not match world context")
	if world_id.is_empty() or WorldIdScript.parse(world_id) == null:
		failures.append("candidate WorldId is invalid")
	elif typeof(world_seed_variant) == TYPE_INT and WorldIdScript.from_seed(int(world_seed_variant)).value() != world_id:
		failures.append("candidate WorldId does not match world seed")
	if delta_store == null or not delta_store is WorldDeltaStoreScript:
		failures.append("candidate WorldDeltaStore is invalid")
	if inventory_state == null or not inventory_state is ItemContainerStateScript:
		failures.append("candidate inventory state is invalid")
	elif not inventory_state.validate_container().is_empty():
		failures.append("candidate inventory state failed validation")
	if equipment_state == null or not equipment_state is EquipmentHotbarStateScript:
		failures.append("candidate equipment state is invalid")
	elif not equipment_state.validate_state().is_empty():
		failures.append("candidate equipment state failed validation")
	if pending_loot_state != null:
		if not pending_loot_state is PendingLootStateScript:
			failures.append("candidate pending loot state has wrong type")
		elif not pending_loot_state.validate_state().is_empty():
			failures.append("candidate pending loot state failed validation")
	if not resume_variant is Vector3:
		failures.append("candidate resume position must be Vector3")
	else:
		var resume: Vector3 = resume_variant
		if is_nan(resume.x) or is_inf(resume.x) or is_nan(resume.y) or is_inf(resume.y) or is_nan(resume.z) or is_inf(resume.z):
			failures.append("candidate resume position must be finite")
	failures.sort()
	return failures
