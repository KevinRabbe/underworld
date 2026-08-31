extends Node
class_name UnderworldContinueReadinessGate

const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")
const MAX_RESUME_PUMPS: int = 96

var _holding: bool = false
var _resolved: bool = false
var _resume_cell_key: String = ""
var _last_diagnostics: Array[String] = []


func _ready() -> void:
	# This node must remain able to run its deferred readiness resolution while the
	# Game subtree is deliberately held with inherited processing disabled.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var game := get_parent()
	if game == null or not game.has_method("startup_mode"):
		return
	if str(game.call("startup_mode")) != "continue":
		return
	var candidate_variant: Variant = game.get("_startup_candidate")
	if not candidate_variant is Dictionary:
		return
	var candidate: Dictionary = candidate_variant
	var resume_variant: Variant = candidate.get("resume_position", null)
	if not resume_variant is Vector3:
		return
	var resume_position: Vector3 = resume_variant
	if resume_position.y >= 0.0:
		return

	# Child _ready() runs before Game._ready(). Holding the parent here therefore
	# guarantees that the restored Player cannot receive a physics/process frame
	# before the normal underworld runtime has reconstructed local collision.
	_holding = true
	game.process_mode = Node.PROCESS_MODE_DISABLED
	call_deferred("resolve_now")


func resolve_now() -> Array[String]:
	if _resolved or not _holding:
		return []
	_last_diagnostics.clear()
	var game := get_parent()
	if game == null:
		return _fail(["Deep Continue readiness gate lost Game parent"])
	var player_variant: Variant = game.get("player")
	var runtime_variant: Variant = game.get("underworld_runtime")
	if not player_variant is Node3D:
		return _fail(["Deep Continue readiness gate requires restored Player"])
	if runtime_variant == null or not runtime_variant.has_method("update_player_position"):
		return _fail(["Deep Continue readiness gate requires configured Underworld runtime"])
	var player: Node3D = player_variant
	var resume_position: Vector3 = player.global_position
	if resume_position.y >= 0.0:
		return _fail(["Deep Continue readiness gate received non-underground Player position"])
	var streamer_variant: Variant = runtime_variant.get("streamer")
	if streamer_variant == null:
		return _fail(["Deep Continue readiness gate requires UnderworldRuntimeStreamer"])
	var cell_size: Vector3 = streamer_variant.get("cell_size")
	if cell_size.x <= 0.0 or cell_size.y <= 0.0 or cell_size.z <= 0.0:
		return _fail(["Deep Continue readiness gate received invalid runtime cell size"])
	var coordinate := Vector3i(
		floori(resume_position.x / cell_size.x),
		floori(resume_position.y / cell_size.y),
		floori(resume_position.z / cell_size.z)
	)
	var address := Address.new(coordinate)
	_resume_cell_key = address.canonical_text()

	for _step in range(MAX_RESUME_PUMPS):
		runtime_variant.call("update_player_position", resume_position)
		if _cell_ready(runtime_variant, _resume_cell_key):
			_resolved = true
			_holding = false
			game.process_mode = Node.PROCESS_MODE_INHERIT
			return []
		var record = streamer_variant.get("records").get(_resume_cell_key, null)
		if record != null and str(record.state) == "failed":
			var diagnostics: Array[String] = [
				"Deep Continue resume cell failed runtime reconstruction: %s" % _resume_cell_key,
			]
			for diagnostic in record.diagnostics:
				diagnostics.append(str(diagnostic))
			return _fail(diagnostics)

	return _fail([
		"Deep Continue resume cell did not reach render/collision readiness within bounded startup pumps: %s" % _resume_cell_key,
	])


func is_holding() -> bool:
	return _holding


func resume_ready() -> bool:
	return _resolved or not _holding


func resume_cell_key() -> String:
	return _resume_cell_key


func last_diagnostics() -> Array[String]:
	return _last_diagnostics.duplicate()


func _cell_ready(runtime, key: String) -> bool:
	var streamer_variant: Variant = runtime.get("streamer")
	if streamer_variant == null:
		return false
	var record = streamer_variant.get("records").get(key, null)
	if record == null or bool(record.release_pending) or str(record.state) == "failed":
		return false
	if record.source_fingerprint.is_empty() or record.provenance_fingerprint.is_empty():
		return false
	for tier in ["definition", "fragment_plan", "voxel_geometry", "render", "collision"]:
		if not bool(record.readiness.get(tier, false)):
			return false
	var render_nodes_variant: Variant = runtime.get("render_nodes")
	var collision_nodes_variant: Variant = runtime.get("collision_nodes")
	return (
		render_nodes_variant is Dictionary
		and collision_nodes_variant is Dictionary
		and render_nodes_variant.has(key)
		and collision_nodes_variant.has(key)
	)


func _fail(messages: Array) -> Array[String]:
	_last_diagnostics.clear()
	for message in messages:
		_last_diagnostics.append(str(message))
	_last_diagnostics.sort()
	for diagnostic in _last_diagnostics:
		push_error(diagnostic)
	# Fail closed: the Game remains PROCESS_MODE_DISABLED until a future explicit
	# successful resolution instead of allowing Player physics into empty space.
	return _last_diagnostics.duplicate()
