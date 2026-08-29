extends Node

const GAME_SCENE: PackedScene = preload("res://app/game/game.tscn")
const TITLE_SCREEN_SCENE: PackedScene = preload("res://presentation/ui/screens/title/title_screen.tscn")

@onready var scene_host: Node = $SceneHost

var current_scene: Node = null
var _transition_in_progress: bool = false


func _ready() -> void:
	show_title()


func show_title() -> void:
	if not _replace_scene(TITLE_SCREEN_SCENE):
		return
	if current_scene == null:
		return
	current_scene.connect("new_game_requested", Callable(self, "_on_new_game_requested"))
	current_scene.connect("continue_requested", Callable(self, "_on_continue_requested"))
	current_scene.connect("quit_requested", Callable(self, "_on_quit_requested"))
	if current_scene.has_method("set_continue_available"):
		current_scene.call("set_continue_available", false)


func start_new_game() -> void:
	_replace_scene(GAME_SCENE)


func _replace_scene(scene: PackedScene) -> bool:
	if _transition_in_progress or scene == null:
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
	scene_host.add_child(next_scene)
	current_scene = next_scene

	if previous_scene != null and is_instance_valid(previous_scene):
		if previous_scene.get_parent() == scene_host:
			scene_host.remove_child(previous_scene)
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
