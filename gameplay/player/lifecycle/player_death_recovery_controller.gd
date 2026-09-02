extends Node
class_name UnderworldPlayerDeathRecoveryController

signal recovery_committed(reason: StringName, target: Vector3)
signal recovery_failed(reason: StringName, diagnostics: Array[String])

const PlayerPlacementProfileScript := preload("res://gameplay/player/player_placement_profile.gd")

const REASON_DAMAGE: StringName = &"damage"
const REASON_FALL: StringName = &"fall"

var _player
var _world
var _world_settings
var _placement_profile
var _pending: bool = false
var _pending_reason: StringName = &""
var _last_diagnostics: Array[String] = []


func configure(player_node, surface_world, world_settings) -> Array[String]:
	var failures: Array[String] = []
	if player_node == null or not player_node.has_method("is_defeated") or not player_node.has_method("commit_respawn"):
		failures.append("death recovery requires Player defeat/respawn authority")
	if (
		surface_world == null
		or not surface_world.has_method("resolve_spawn_xz")
		or not surface_world.has_method("prepare_player_placement")
	):
		failures.append("death recovery requires safe surface placement/readiness authority")
	if world_settings == null:
		failures.append("death recovery requires WorldSettings")
	elif not _is_finite_number(world_settings.get("sea_level")) or not _is_finite_number(world_settings.get("chunk_size")):
		failures.append("death recovery requires finite world settings")
	elif float(world_settings.get("chunk_size")) <= 0.0:
		failures.append("death recovery requires positive chunk size")

	var placement_profile = PlayerPlacementProfileScript.new()
	if player_node != null:
		failures.append_array(placement_profile.configure_from_player(player_node))
	else:
		failures.append("death recovery cannot derive Player placement profile")
	if not failures.is_empty():
		return failures

	_player = player_node
	_world = surface_world
	_world_settings = world_settings
	_placement_profile = placement_profile
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
	var target_variant: Variant = resolved.get("target", null)
	if not target_variant is Vector3 or not _is_finite_vector3(target_variant):
		return _record_failure(["death recovery resolved invalid target before readiness"])
	var target: Vector3 = target_variant

	# Readiness must be established against realized target-local terrain and solid
	# object collision before Player state is cleared. This seam is also consumable
	# by #404 without moving/healing the defeated Player during domain preparation.
	var readiness_variant: Variant = _world.call(
		"prepare_player_placement",
		target,
		_placement_profile
	)
	if not readiness_variant is Dictionary:
		return _record_failure(["death recovery surface readiness returned invalid result"])
	var readiness: Dictionary = readiness_variant
	if not bool(readiness.get("success", false)) or not bool(readiness.get("ready", false)):
		var readiness_failures: Array[String] = []
		_append_attempt_diagnostics(readiness_failures, "target-readiness", readiness)
		return _record_failure(readiness_failures)
	var prepared_target_variant: Variant = readiness.get("target", null)
	if not prepared_target_variant is Vector3 or not _is_finite_vector3(prepared_target_variant):
		return _record_failure(["death recovery readiness returned invalid prepared target"])
	var prepared_target: Vector3 = prepared_target_variant

	if not bool(_player.call("commit_respawn", prepared_target)):
		return _record_failure(["Player rejected validated death recovery target"])

	var reason: StringName = _pending_reason
	_pending = false
	_pending_reason = &""
	_last_diagnostics.clear()
	recovery_committed.emit(reason, prepared_target)
	return {
		"success": true,
		"reason": reason,
		"target": prepared_target,
		"fallback_used": bool(resolved.get("fallback_used", false)),
		"diagnostics": [],
	}


func resolve_safe_target(current_position: Vector3) -> Dictionary:
	if _world == null or _world_settings == null or _placement_profile == null:
		return _failure(["death recovery is not configured"])
	if not _is_finite_vector3(current_position):
		return _failure(["death recovery current Player position must be finite"])

	# Both attempts use the same bounded placement search and the same live-derived
	# Player profile. The first search is centered on the defeated Player's current
	# Overworld XZ; only if that bounded region has no viable point do we search the
	# ordinary initial-spawn region.
	var primary_preferred := Vector3(current_position.x, 0.0, current_position.z)
	var primary_variant: Variant = _world.call(
		"resolve_spawn_xz",
		primary_preferred,
		_placement_profile
	)
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
	var fallback_variant: Variant = _world.call(
		"resolve_spawn_xz",
		fallback_preferred,
		_placement_profile
	)
	if fallback_variant is Dictionary:
		var fallback: Dictionary = fallback_variant
		if bool(fallback.get("success", false)):
			return _target_from_placement(fallback, true)
	_append_attempt_diagnostics(failures, "initial-spawn", fallback_variant)
	failures.sort()
	return _failure(failures)


func placement_profile():
	return _placement_profile


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
	var target := Vector3(
		candidate.x,
		float(_placement_profile.body_origin_y_for_support(float(height_variant))),
		candidate.z
	)
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
