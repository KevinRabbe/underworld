extends Node

const ROUTE_NONE: StringName = &""
const ROUTE_TITLE: StringName = &"title"
const ROUTE_GAME: StringName = &"game"

const GAME_SCENE: PackedScene = preload("res://app/game/game.tscn")
const TITLE_SCREEN_SCENE: PackedScene = preload("res://presentation/ui/screens/title/title_screen.tscn")

@onready var scene_host: Node = $SceneHost

var current_scene: Node = null
var _current_route: StringName = ROUTE_NONE
var _transition_in_progress: bool = false
var _title_scene: PackedScene = TITLE_SCREEN_SCENE
var _game_scene: PackedScene = GAME_SCENE


func configure_route_scenes(title_scene: PackedScene, game_scene: PackedScene) -> bool:
	# Test/application composition may replace route resources before AppRoot enters
	# the SceneTree. Runtime screens never receive ownership of this route catalog.
	if is_inside_tree():
		push_error("Application route scenes must be configured before AppRoot enters the SceneTree")
		return false
	if title_scene == null or game_scene == null:
		push_error("Application route scenes must be non-null PackedScenes")
		return false
	_title_scene = title_scene
	_game_scene = game_scene
	return true


func _ready() -> void:
	show_title()


func current_route_id() -> StringName:
	return _current_route


func show_title() -> bool:
	if _current_route == ROUTE_TITLE and current_scene != null and is_instance_valid(current_scene):
		return false
	if not _replace_scene(_title_scene, ROUTE_TITLE):
		return false
	if current_scene == null:
		return false
	current_scene.connect("new_game_requested", Callable(self, "_on_new_game_requested"))
	current_scene.connect("continue_requested", Callable(self, "_on_continue_requested"))
	current_scene.connect("quit_requested", Callable(self, "_on_quit_requested"))
	if current_scene.has_method("set_continue_available"):
		current_scene.call("set_continue_available", false)
	return true


func start_new_game() -> bool:
	if _current_route == ROUTE_GAME and current_scene != null and is_instance_valid(current_scene):
		return false
	return _replace_scene(_game_scene, ROUTE_GAME)


func _replace_scene(scene: PackedScene, route_id: StringName) -> bool:
	if _transition_in_progress or scene == null or route_id == ROUTE_NONE:
		return false
	if route_id == _current_route and current_scene != null and is_instance_valid(current_scene):
		return false
	if not scene.can_instantiate():
		return false
	_transition_in_progress = true

	# Prepare the replacement before mutating the active scene. A broken future
	# route therefore fails closed and leaves the current application surface live.
	var next_scene: Node = scene.instantiate()
	if next_scene == null:
		_transition_in_progress = false
		push_error("Application scene router could not instantiate requested scene")
		return false

	var previous_scene: Node = current_scene
	if previous_scene != null and is_instance_valid(previous_scene):
		if previous_scene.get_parent() == scene_host:
			scene_host.remove_child(previous_scene)

	scene_host.add_child(next_scene)
	current_scene = next_scene
	_current_route = route_id

	if previous_scene != null and is_instance_valid(previous_scene):
		previous_scene.queue_free()

	_transition_in_progress = false
	return true


func _on_new_game_requested() -> void:
	start_new_game()


func _on_continue_requested() -> void:
	# Continue remains fail-closed until SAVE-001 integrates durable load availability
	# and supplies the actual reconstruction path. The title button is disabled now.
	push_warning("Continue requested before persistence integration")


func _on_quit_requested() -> void:
	get_tree().quit()
