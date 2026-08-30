extends Node

const GameSaveSlotService := preload("res://gameplay/persistence/game_save_slot_service.gd")

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
var _save_slot_service = GameSaveSlotService.new()
var _save_slot_path: String = GameSaveSlotService.DEFAULT_SLOT_PATH


func configure_route_scenes(title_scene: PackedScene, game_scene: PackedScene) -> bool:
	if is_inside_tree():
		push_error("Application route scenes must be configured before AppRoot enters the SceneTree")
		return false
	if title_scene == null or game_scene == null:
		push_error("Application route scenes must be non-null PackedScenes")
		return false
	_title_scene = title_scene
	_game_scene = game_scene
	return true


func configure_save_slot_path(slot_path: String) -> bool:
	if is_inside_tree():
		push_error("SAVE slot path must be configured before AppRoot enters the SceneTree")
		return false
	if slot_path.is_empty() or slot_path != slot_path.strip_edges():
		return false
	if not slot_path.begins_with("user://"):
		return false
	if slot_path.ends_with(GameSaveSlotService.CANDIDATE_SUFFIX) or slot_path.ends_with(GameSaveSlotService.BACKUP_SUFFIX):
		return false
	_save_slot_path = slot_path
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
		var probe: Dictionary = _save_slot_service.probe_slot(_save_slot_path)
		current_scene.call(
			"set_continue_available",
			bool(probe.get("success", false)) and bool(probe.get("available", false))
		)
	return true


func start_new_game() -> bool:
	if _current_route == ROUTE_GAME and current_scene != null and is_instance_valid(current_scene):
		return false
	return _replace_game_scene(false, {})


func save_current_game() -> Dictionary:
	if _transition_in_progress:
		return _failure(["SAVE cannot run during application route transition"])
	if _current_route != ROUTE_GAME or current_scene == null or not is_instance_valid(current_scene):
		return _failure(["SAVE requires active game route"])
	if not current_scene.has_method("build_save_request"):
		return _failure(["active game route does not expose SAVE snapshot request"])
	var request_variant: Variant = current_scene.call("build_save_request")
	if not request_variant is Dictionary:
		return _failure(["active game route returned incompatible SAVE snapshot request"])
	var request: Dictionary = request_variant
	if not bool(request.get("success", false)):
		return request
	return _save_slot_service.save_slot(
		request.get("context", null),
		request.get("delta_store", null),
		request.get("inventory_state", null),
		request.get("equipment_state", null),
		request.get("pending_loot_states", []),
		request.get("resume_position", Vector3.ZERO),
		_save_slot_path
	)


func continue_game() -> bool:
	if _current_route == ROUTE_GAME and current_scene != null and is_instance_valid(current_scene):
		return false
	if _transition_in_progress:
		return false
	var loaded: Dictionary = _save_slot_service.load_slot(_save_slot_path)
	if not bool(loaded.get("success", false)):
		return false
	var candidate_variant: Variant = loaded.get("candidate", null)
	if not candidate_variant is Dictionary:
		return false
	return _replace_game_scene(true, candidate_variant)


func _replace_game_scene(is_continue: bool, candidate: Dictionary) -> bool:
	if _transition_in_progress or _game_scene == null:
		return false
	if _current_route == ROUTE_GAME and current_scene != null and is_instance_valid(current_scene):
		return false
	if not _game_scene.can_instantiate():
		return false
	_transition_in_progress = true
	var next_scene: Node = _game_scene.instantiate()
	if next_scene == null:
		_transition_in_progress = false
		push_error("Application scene router could not instantiate requested game scene")
		return false

	var preparation_method: StringName = &"prepare_continue" if is_continue else &"prepare_new_game"
	if not next_scene.has_method(preparation_method):
		next_scene.free()
		_transition_in_progress = false
		push_error("Game route does not expose required off-tree startup preparation: %s" % preparation_method)
		return false
	var prepared: bool
	if is_continue:
		prepared = bool(next_scene.call(preparation_method, candidate))
	else:
		prepared = bool(next_scene.call(preparation_method))
	if not prepared:
		next_scene.free()
		_transition_in_progress = false
		return false
	return _commit_prepared_scene(next_scene, ROUTE_GAME)


func _replace_scene(scene: PackedScene, route_id: StringName) -> bool:
	if _transition_in_progress or scene == null or route_id == ROUTE_NONE:
		return false
	if route_id == _current_route and current_scene != null and is_instance_valid(current_scene):
		return false
	if not scene.can_instantiate():
		return false
	_transition_in_progress = true
	var next_scene: Node = scene.instantiate()
	if next_scene == null:
		_transition_in_progress = false
		push_error("Application scene router could not instantiate requested scene")
		return false
	return _commit_prepared_scene(next_scene, route_id)


func _commit_prepared_scene(next_scene: Node, route_id: StringName) -> bool:
	if not _transition_in_progress or next_scene == null or route_id == ROUTE_NONE:
		if next_scene != null and not next_scene.is_inside_tree():
			next_scene.free()
		_transition_in_progress = false
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
	continue_game()


func _on_quit_requested() -> void:
	get_tree().quit()


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {"success": false, "diagnostics": diagnostics}
