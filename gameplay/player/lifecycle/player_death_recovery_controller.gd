extends Node
class_name UnderworldPlayerDeathRecoveryController

signal recovery_committed(reason: StringName, target: Vector3)
signal recovery_failed(reason: StringName, diagnostics: Array[String])

const REASON_DAMAGE: StringName = &"damage"
const REASON_FALL: StringName = &"fall"
const BODY_CLEARANCE: float = 3.0

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
	if (
		surface_world == null
		or not surface_world.has_method("query_player_placement_xz")
		or not surface_world.has_method("resolve_spawn_xz")
		or not surface_world.has_method("generate_initial")
	):
		failures.append("death recovery requires safe surface placement/realization authority")
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
	# target chunk before teleport prevents a valid deterministic placement from
	# being committed ahead of its terrain collision realization.
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
	var primary_variant: Variant = _world.call("query_player_placement_xz", primary_preferred)
	if primary_variant is Dictionary:
		var primary: Dictionary = primary_variant
		if bool(primary.get("success", false)):
			return _target_from_placement(primary, false)

	var failures: Array[String] = []
	_append_attempt_diagnostics(failures, "current-xz", primary_variant)
	var fallback_preferred := Vector3(
		float(_world_settings.get("chunk_size")) * 0.5,
		0.0,
		float(_world_settings.get("chunk_size")) * 0.5
	)
	var fallback_variant: Variant = _world.call("resolve_spawn_xz", fallback_preferred)
	if fallback_variant is Dictionary:
		var fallback: Dictionary = fallback_variant
		if bool(fallback.get("success", false)):
			return _target_from_placement(fallback, true)
	_append_attempt_diagnostics(failures, "initial-spawn", fallback_variant)
	failures.sort()
	return _failure(failures)


func _target_from_placement(placement: Dictionary, fallback_used: bool) -> Dictionary:
	var candidate_variant: Variant = placement.get("xz", null)
	var height_variant: Variant = placement.get("surface_height", null)
	if not candidate_variant is Vector3:
		return _failure(["death recovery safe placement returned non-Vector3 XZ"])
	var candidate: Vector3 = candidate_variant
	if (
		not _is_finite_number(candidate.x)
		or not _is_finite_number(candidate.z)
		or not _is_finite_number(height_variant)
	):
		return _failure(["death recovery safe placement returned non-finite target data"])
	var target := Vector3(candidate.x, float(height_variant) + BODY_CLEARANCE, candidate.z)
	if not _is_finite_vector3(target):
		return _failure(["death recovery safe placement produced non-finite target"])
	return {
		"success": true,
		"target": target,
		"fallback_used": fallback_used,
		"diagnostics": [],
	}


func _append_attempt_diagnostics(failures: Array[String], label: String, result: Variant) -> void:
	if not result is Dictionary:
		failures.append("%s surface placement returned invalid result" % label)
		return
	var diagnostics_variant: Variant = result.get("diagnostics", [])
	if not diagnostics_variant is Array or diagnostics_variant.is_empty():
		failures.append("%s surface placement failed without diagnostics" % label)
		return
	for diagnostic in diagnostics_variant:
		failures.append("%s: %s" % [label, str(diagnostic)])


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
