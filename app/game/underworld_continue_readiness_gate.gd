extends Node
class_name UnderworldContinueReadinessGate

const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")
const PlayerSupportBounds := preload("res://gameplay/player/player_collision_support_bounds.gd")
const MAX_RESUME_PUMPS: int = 96
const MAX_SUPPORT_CELLS: int = 8
const SUPPORT_EDGE_EPSILON: float = 0.0001

var _holding: bool = false
var _resolved: bool = false
var _resume_cell_key: String = ""
var _resume_support_cell_keys: Array[String] = []
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
	if not player_variant is CharacterBody3D:
		return _fail(["Deep Continue readiness gate requires restored CharacterBody3D Player"])
	if runtime_variant == null or not runtime_variant.has_method("update_player_position"):
		return _fail(["Deep Continue readiness gate requires configured Underworld runtime"])
	var player: CharacterBody3D = player_variant
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
	_resume_cell_key = Address.new(coordinate).canonical_text()

	var support_result: Dictionary = PlayerSupportBounds.bounds_at(player, resume_position)
	if not bool(support_result.get("success", false)):
		return _fail(support_result.get("diagnostics", []))
	var bounds_variant: Variant = support_result.get("bounds", null)
	if not bounds_variant is AABB:
		return _fail(["Deep Continue Player support query did not return AABB"])
	var key_result: Dictionary = _support_cell_keys(bounds_variant, cell_size)
	if not bool(key_result.get("success", false)):
		return _fail(key_result.get("diagnostics", []))
	_resume_support_cell_keys.clear()
	for raw_key in key_result.get("keys", []):
		_resume_support_cell_keys.append(str(raw_key))
	_resume_support_cell_keys.sort()
	if _resume_support_cell_keys.is_empty():
		return _fail(["Deep Continue Player support envelope resolved no runtime cells"])
	if not _resume_support_cell_keys.has(_resume_cell_key):
		return _fail([
			"Deep Continue Player support envelope does not include containing cell: %s" % _resume_cell_key,
		])

	for _step in range(MAX_RESUME_PUMPS):
		runtime_variant.call("update_player_position", resume_position)
		var failed_diagnostics: Array[String] = _failed_support_diagnostics(
			runtime_variant,
			streamer_variant
		)
		if not failed_diagnostics.is_empty():
			return _fail(failed_diagnostics)
		if _all_support_ready(runtime_variant):
			_resolved = true
			_holding = false
			game.process_mode = Node.PROCESS_MODE_INHERIT
			return []

	return _fail([
		"Deep Continue support cells did not reach render/collision readiness within bounded startup pumps: %s" % [_resume_support_cell_keys],
	])


func is_holding() -> bool:
	return _holding


func resume_ready() -> bool:
	return _resolved or not _holding


func resume_cell_key() -> String:
	# Compatibility diagnostic only. Readiness authority is the support set.
	return _resume_cell_key


func resume_support_cell_keys() -> Array[String]:
	var result: Array[String] = []
	result.append_array(_resume_support_cell_keys)
	return result


func last_diagnostics() -> Array[String]:
	return _last_diagnostics.duplicate()


func _support_cell_keys(bounds: AABB, cell_size: Vector3) -> Dictionary:
	var maximum: Vector3 = bounds.end - Vector3.ONE * SUPPORT_EDGE_EPSILON
	var minimum_coordinate := Vector3i(
		floori(bounds.position.x / cell_size.x),
		floori(bounds.position.y / cell_size.y),
		floori(bounds.position.z / cell_size.z)
	)
	var maximum_coordinate := Vector3i(
		floori(maximum.x / cell_size.x),
		floori(maximum.y / cell_size.y),
		floori(maximum.z / cell_size.z)
	)
	var count: int = (
		(maximum_coordinate.x - minimum_coordinate.x + 1)
		* (maximum_coordinate.y - minimum_coordinate.y + 1)
		* (maximum_coordinate.z - minimum_coordinate.z + 1)
	)
	if count <= 0 or count > MAX_SUPPORT_CELLS:
		return {
			"success": false,
			"keys": [],
			"diagnostics": [
				"Deep Continue Player support envelope resolved invalid/broad cell count: %d" % count,
			],
		}
	var keys: Array[String] = []
	for x in range(minimum_coordinate.x, maximum_coordinate.x + 1):
		for y in range(minimum_coordinate.y, maximum_coordinate.y + 1):
			for z in range(minimum_coordinate.z, maximum_coordinate.z + 1):
				keys.append(Address.new(Vector3i(x, y, z)).canonical_text())
	keys.sort()
	return {
		"success": true,
		"keys": keys,
		"diagnostics": [],
	}


func _all_support_ready(runtime) -> bool:
	for key in _resume_support_cell_keys:
		if not _cell_ready(runtime, key):
			return false
	return true


func _failed_support_diagnostics(runtime, streamer_variant) -> Array[String]:
	var failures: Array[String] = []
	var records_variant: Variant = streamer_variant.get("records")
	if not records_variant is Dictionary:
		return ["Deep Continue readiness gate requires runtime record Dictionary"]
	for key in _resume_support_cell_keys:
		var record = records_variant.get(key, null)
		if record == null or str(record.state) != "failed":
			continue
		failures.append("Deep Continue support cell failed runtime reconstruction: %s" % key)
		for diagnostic in record.diagnostics:
			failures.append("%s: %s" % [key, str(diagnostic)])
	failures.sort()
	return failures


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
