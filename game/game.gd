extends Node3D

const WorldSettingsScript := preload("res://data/world_settings.gd")
const ChunkManagerScript := preload("res://world/chunk_manager.gd")
const PlayerScript := preload("res://player/player.gd")
const DebugHudScript := preload("res://game/debug_hud.gd")

var settings: UnderworldWorldSettings
var world
var player
var debug_hud
var spawn_xz: Vector3 = Vector3.ZERO


func _ready() -> void:
	_setup_environment()
	_create_world()
	_create_player()
	_create_debug_hud()


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
	settings = WorldSettingsScript.new()
	spawn_xz = Vector3(settings.chunk_size * 0.5, 0.0, settings.chunk_size * 0.5)

	world = ChunkManagerScript.new()
	world.name = "World"
	world.configure(settings)
	add_child(world)
	world.generate_initial(spawn_xz)


func _create_player() -> void:
	player = PlayerScript.new()
	player.name = "Player"
	add_child(player)

	var spawn_height: float = world.get_height_at_world(spawn_xz.x, spawn_xz.z)
	var spawn_position: Vector3 = Vector3(spawn_xz.x, spawn_height + 3.0, spawn_xz.z)
	player.global_position = spawn_position
	player.set_respawn_position(spawn_position)
	world.set_player(player)


func _create_debug_hud() -> void:
	debug_hud = DebugHudScript.new()
	debug_hud.name = "DebugHUD"
	debug_hud.configure(world, player, settings)
	add_child(debug_hud)
