extends Node3D

const WorldSettingsScript := preload("res://world/runtime/config/world_settings.gd")
const SurvivalSettingsScript := preload("res://gameplay/survival/prototype_survival_settings.gd")
const WaterSettingsScript := preload("res://presentation/world/environment/prototype_water_settings.gd")
const CavePresentationControllerScript := preload("res://presentation/world/caves/cave_presentation_controller.gd")
const PrototypeCavePresentationCatalog := preload("res://content/presentation/caves/prototype_cave_presentation_catalog.tres")
const SurfaceChunkStreamerScript := preload("res://world/runtime/streaming/surface_chunk_streamer.gd")
const WorldDeltaStoreScript := preload("res://worldgen/persistence/world_delta_store.gd")
const PrototypeSurvivalControllerScript := preload("res://gameplay/survival/prototype_survival_controller.gd")
const PlayerScript := preload("res://gameplay/player/player.gd")
const VoxelCharacterPresentationProviderScript := preload("res://presentation/characters/voxel/voxel_character_presentation_provider.gd")
const CombatResolverScript := preload("res://gameplay/combat/resolution/combat_resolver.gd")
const BurrowerEncounterControllerScript := preload("res://gameplay/creatures/spawning/prototype_burrower_encounter_controller.gd")
const GameplayHudScript := preload("res://presentation/ui/hud/gameplay_hud.gd")
const DebugHudScript := preload("res://presentation/ui/debug/debug_hud.gd")
const UnderworldRuntimeControllerScript := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const WorldIdScript := preload("res://worldgen/identity/world_id.gd")
const GeneratorManifestScript := preload("res://worldgen/versioning/generator_manifest.gd")
const Map015FixtureScript := preload("res://worldgen/validation/map015_fixture.gd")

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


func _ready() -> void:
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
	if enable_map015_fixture:
		world_settings.world_seed = 1
	survival_settings = SurvivalSettingsScript.new()
	water_settings = WaterSettingsScript.new()

	world_delta_store = WorldDeltaStoreScript.new()
	world = SurfaceChunkStreamerScript.new()
	world.name = "SurfaceWorld"
	if not world.bind_world_delta_store(world_delta_store):
		push_error("Surface world rejected WorldDeltaStore authority")
	world.configure(world_settings)
	add_child(world)

	# Prototype survival keeps version-2 file orchestration, while the streamer
	# delegates generated-world destruction authority to WorldDeltaStore.
	survival = PrototypeSurvivalControllerScript.new()
	survival.name = "PrototypeSurvival"
	add_child(survival)
	survival.configure(world, survival_settings, world_settings.world_seed)

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
	player.character_presentation_provider = VoxelCharacterPresentationProviderScript.new()
	add_child(player)

	var spawn_height: float = world.get_height_at_world(spawn_xz.x, spawn_xz.z)
	var spawn_position: Vector3 = Vector3(spawn_xz.x, spawn_height + 3.0, spawn_xz.z)
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
