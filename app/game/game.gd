extends Node3D

const WorldSettingsScript := preload("res://world/runtime/config/world_settings.gd")
const SurvivalSettingsScript := preload("res://gameplay/survival/prototype_survival_settings.gd")
const WaterSettingsScript := preload("res://presentation/world/environment/prototype_water_settings.gd")
const SurfaceChunkStreamerScript := preload("res://world/runtime/streaming/surface_chunk_streamer.gd")
const PrototypeSurvivalControllerScript := preload("res://gameplay/survival/prototype_survival_controller.gd")
const PlayerScript := preload("res://gameplay/player/player.gd")
const CombatResolverScript := preload("res://gameplay/combat/resolution/combat_resolver.gd")
const BurrowerEncounterControllerScript := preload("res://gameplay/creatures/spawning/prototype_burrower_encounter_controller.gd")
const DebugHudScript := preload("res://presentation/ui/debug/debug_hud.gd")

var world_settings
var survival_settings
var water_settings
var world
var survival
var player
var combat_resolver
var encounter_controller
var debug_hud
var water_surface: MeshInstance3D
var spawn_xz: Vector3 = Vector3.ZERO


func _ready() -> void:
	_setup_environment()
	_create_world()
	_create_player()
	_create_combat()
	_create_debug_hud()


func _process(_delta: float) -> void:
	if water_surface != null and player != null:
		water_surface.global_position.x = player.global_position.x
		water_surface.global_position.z = player.global_position.z


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
	survival_settings = SurvivalSettingsScript.new()
	water_settings = WaterSettingsScript.new()

	world = SurfaceChunkStreamerScript.new()
	world.name = "SurfaceWorld"
	world.configure(world_settings)
	add_child(world)

	# Prototype survival currently owns the version-2 save orchestration. It loads
	# generated-world deltas into the streamer before initial chunk construction.
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


func _create_debug_hud() -> void:
	debug_hud = DebugHudScript.new()
	debug_hud.name = "DebugHUD"
	debug_hud.configure(
		world,
		player,
		world_settings,
		survival,
		combat_resolver,
		encounter_controller
	)
	add_child(debug_hud)
