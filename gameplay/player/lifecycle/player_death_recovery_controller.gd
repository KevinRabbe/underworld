extends Node
class_name UnderworldPlayerDeathRecoveryController

signal recovery_committed(reason: StringName, target: Vector3)
signal recovery_failed(reason: StringName, diagnostics: Array[String])

const REASON_DAMAGE: StringName = &"damage"
const REASON_FALL: StringName = &"fall"
const BODY_CLEARANCE: float = 3.0
const WATER_CLEARANCE: float = 1.5

var _player
var _world
var _world_settings
var _pending: bool = false
var _pending_reason: StringName = &""
var _last_diagnostics: Array[String] = []


func configure(player_node, surface_world, world_settings) -> Array[String]:
	var failures: Array[String] = []
	if player_node == null or not player_node.has_method("is_defeated") or not player_node.has_method("commit_respawn"):
		failures.append("death recovery requires Player defeat/respawn authority")
	if surface_world == null or not surface_world.has_method("find_spawn_xz") or not surface_world.has_method("get_height_at_world"):
		failures.append("death recovery requires surface spawn/height authority")
	if world_settings == null:
		failures.append("death recovery requires WorldSettings")
	elif not _is_finite_number(world_settings.get("sea_level")) or not _is_finite_number(world_settings.get("chunk_size")):
		failures.append("death recovery requires finite world settings")
	elif float(world_settings.get("chunk_size")) <= 0.0:
		failures.append("death recovery requires positive chunk size")
	if not failures.is_empty():
		return failures
	_player = player_node
	_world = surface_world
	_world_settings = world_settings
	return []


func request_recovery(reason: StringName) -> bool:
	if _pending or _player == null or not bool(_player.call("is_defeated")):
		return false
	if reason != REASON_DAMAGE and reason != REASON_FALL:
		return false
	_pending = true
	_pending_reason = reason
	_last_diagnostics.clear()
	call_deferred("try_commit_recovery")
	return true


func try_commit_recovery() -> Dictionary:
	if not _pending:
		return _failure(["death recovery has no pending request"])
	if _player == null or not bool(_player.call("is_defeated")):
		return _record_failure(["death recovery lost defeated Player authority"])

	var resolved: Dictionary = resolve_safe_target(_player.get("global_position"))
	if not bool(resolved.get("success", false)):
		return _record_failure(resolved.get("diagnostics", []))
	var target: Vector3 = resolved.get("target", Vector3.ZERO)

	# Surface streaming remains the geometry realization authority. Generating the
	# target chunk before teleport prevents a valid deterministic height from being
	# committed ahead of its collision realization.
	if _world.has_method("generate_initial"):
		_world.call("generate_initial", Vector3(target.x, 0.0, target.z))
	if not bool(_player.call("commit_respawn", target)):
		return _record_failure(["Player rejected validated death recovery target"])

	var reason: StringName = _pending_reason
	_pending = false
	_pending_reason = &""
	_last_diagnostics.clear()
	recovery_committed.emit(reason, target)
	return {
		"success": true,
		"reason": reason,
		"target": target,
		"fallback_used": bool(resolved.get("fallback_used", false)),
		"diagnostics": [],
	}


func resolve_safe_target(current_position: Vector3) -> Dictionary:
	if _world == null or _world_settings == null:
		return _failure(["death recovery is not configured"])
	if not _is_finite_vector3(current_position):
		return _failure(["death recovery current Player position must be finite"])

	var primary_preferred := Vector3(current_position.x, 0.0, current_position.z)
	var fallback_preferred := Vector3(
		float(_world_settings.get("chunk_size")) * 0.5,
		0.0,
		float(_world_settings.get("chunk_size")) * 0.5
	)
	var attempts: Array[Dictionary] = [
		{"label": "current-xz", "preferred": primary_preferred, "fallback": false},
		{"label": "initial-spawn", "preferred": fallback_preferred, "fallback": true},
	]
	var failures: Array[String] = []
	for attempt in attempts:
		var candidate_variant: Variant = _world.call("find_spawn_xz", attempt["preferred"])
		if not candidate_variant is Vector3:
			failures.append("%s surface search returned non-Vector3 target" % attempt["label"])
			continue
		var candidate: Vector3 = candidate_variant
		if not _is_finite_number(candidate.x) or not _is_finite_number(candidate.z):
			failures.append("%s surface search returned non-finite XZ" % attempt["label"])
			continue
		var height_variant: Variant = _world.call("get_height_at_world", candidate.x, candidate.z)
		if not _is_finite_number(height_variant):
			failures.append("%s surface height is non-finite" % attempt["label"])
			continue
		var height: float = float(height_variant)
		var sea_level: float = float(_world_settings.get("sea_level"))
		if height <= sea_level + WATER_CLEARANCE:
			failures.append("%s surface target is not safely above water" % attempt["label"])
			continue
		var target := Vector3(candidate.x, height + BODY_CLEARANCE, candidate.z)
		if not _is_finite_vector3(target):
			failures.append("%s surface target is non-finite" % attempt["label"])
			continue
		return {
			"success": true,
			"target": target,
			"fallback_used": bool(attempt["fallback"]),
			"diagnostics": [],
		}
	failures.sort()
	return _failure(failures)


func is_recovery_pending() -> bool:
	return _pending


func pending_reason() -> StringName:
	return _pending_reason


func last_diagnostics() -> Array[String]:
	return _last_diagnostics.duplicate()


func _record_failure(messages: Array) -> Dictionary:
	_last_diagnostics.clear()
	for message in messages:
		_last_diagnostics.append(str(message))
	_last_diagnostics.sort()
	recovery_failed.emit(_pending_reason, _last_diagnostics.duplicate())
	return _failure(_last_diagnostics)


static func _is_finite_number(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number: float = float(value)
	return not is_nan(number) and not is_inf(number)


static func _is_finite_vector3(value: Vector3) -> bool:
	return (
		_is_finite_number(value.x)
		and _is_finite_number(value.y)
		and _is_finite_number(value.z)
	)


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {"success": false, "diagnostics": diagnostics}
