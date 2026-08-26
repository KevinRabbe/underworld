extends Node3D

const WorldSettingsScript := preload("res://data/world_settings.gd")
const ChunkManagerScript := preload("res://world/chunk_manager.gd")
const PlayerScript := preload("res://player/player.gd")

var settings
var world
var player


func _ready() -> void:
	_setup_environment()
	_create_world()
	_create_player()


func _setup_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.56, 0.72, 0.86)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.76, 0.82)
	environment.ambient_light_energy = 0.8
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)


func _create_world() -> void:
	settings = WorldSettingsScript.new()
	world = ChunkManagerScript.new()
	world.name = "World"
	world.configure(settings)
	add_child(world)
	world.generate_initial(Vector3.ZERO)


func _create_player() -> void:
	player = PlayerScript.new()
	player.name = "Player"
	add_child(player)

	var spawn_height: float = world.get_height_at_world(0.0, 0.0)
	player.global_position = Vector3(0.0, spawn_height + 3.0, 0.0)
	world.set_player(player)
