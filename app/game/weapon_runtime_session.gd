extends Node

const WeaponRuntimeSessionService := preload("res://gameplay/items/weapons/runtime/weapon_runtime_session_service.gd")

var _service = WeaponRuntimeSessionService.new()
var _game: Node = null
var _bound: bool = false
var _sync_pending: bool = false
var _last_result: Dictionary = {}


func _ready() -> void:
	call_deferred("_bind_after_game_ready")


func _exit_tree() -> void:
	_service.clear()
	_game = null
	_bound = false
	_sync_pending = false
	_last_result.clear()


func is_configured() -> bool:
	return _bound and _service.is_configured()


func craft_capabilities() -> Array:
	return _service.craft_capabilities()


func craft(recipe_id: String) -> Dictionary:
	if not is_configured():
		return _failure("craft", ["weapon runtime session is not configured"])
	return _service.craft(recipe_id)


func craft_and_equip(recipe_id: String) -> Dictionary:
	if not is_configured():
		return _failure("craft_and_equip", ["weapon runtime session is not configured"])
	var result: Dictionary = _service.craft_and_equip(recipe_id)
	_last_result = result.duplicate(true)
	return result


func sync_selected() -> Dictionary:
	if not is_configured():
		return _failure("sync", ["weapon runtime session is not configured"])
	var result: Dictionary = _service.sync_selected()
	_last_result = result.duplicate(true)
	return result


func last_result() -> Dictionary:
	return _last_result.duplicate(true)


func presented_weapon_instance():
	return _service.presented_weapon_instance()


func _bind_after_game_ready() -> void:
	_game = get_parent()
	if _game == null or not is_instance_valid(_game):
		_last_result = _failure("configure", ["weapon runtime session requires Game parent"])
		return
	var player = _game.get("player")
	var survival = _game.get("survival")
	if player == null or not is_instance_valid(player) or survival == null:
		_last_result = _failure("configure", ["Game did not expose live Player and Survival after startup"])
		return
	if not survival.has_method("get_inventory_state") or not survival.has_method("get_equipment_state"):
		_last_result = _failure("configure", ["Survival does not expose canonical inventory/equipment state"])
		return
	var configured: Dictionary = _service.configure(
		player,
		survival.call("get_inventory_state"),
		survival.call("get_equipment_state")
	)
	_last_result = configured.duplicate(true)
	if not bool(configured.get("success", false)):
		return
	_bound = true
	if survival.has_signal("equipped_tool_changed"):
		var callable := Callable(self, "_on_legacy_equipped_tool_changed")
		if not survival.is_connected("equipped_tool_changed", callable):
			survival.connect("equipped_tool_changed", callable)
	# Explicit canonical resync after Game's startup composition means correctness
	# does not depend on the order of pre-existing legacy signal connections.
	_request_deferred_sync()


func _on_legacy_equipped_tool_changed(_tool_id: String) -> void:
	_request_deferred_sync()


func _request_deferred_sync() -> void:
	if _sync_pending or not _bound:
		return
	_sync_pending = true
	call_deferred("_commit_deferred_sync")


func _commit_deferred_sync() -> void:
	_sync_pending = false
	if not _bound or not is_inside_tree():
		return
	_last_result = _service.sync_selected().duplicate(true)


static func _failure(stage: String, messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {
		"success": false,
		"stage": stage,
		"diagnostics": diagnostics,
	}
