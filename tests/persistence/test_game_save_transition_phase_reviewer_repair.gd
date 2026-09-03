extends RefCounted

const GAME_SCENE_PATH := "res://app/game/game.tscn"
const WorldDomainSessionState := preload("res://gameplay/world_session/world_domain_session_state.gd")


static func run_runtime(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var packed = ResourceLoader.load(GAME_SCENE_PATH)
	if packed == null or not packed is PackedScene:
		return ["transition-phase SAVE reviewer proof could not load game.tscn"]
	var game: Node = packed.instantiate()
	game.set("enable_debug_hud", false)
	if not bool(game.call("prepare_new_game")):
		game.free()
		return ["transition-phase SAVE reviewer proof could not prepare NEW Game"]
	tree.root.add_child(game)

	var initial: Dictionary = game.call("build_save_request")
	_require_success(initial, "initial ACTIVE Game SAVE capture", failures)
	var session = game.get("_world_session_state")
	if session == null or not session is WorldDomainSessionState:
		failures.append("real Game did not retain WorldDomainSessionState authority")
		_free_attached(game)
		return failures

	var begun: Dictionary = session.begin_transition(_transition_request())
	if not _require_success(begun, "PREPARING transition begin", failures):
		_free_attached(game)
		return failures
	var token: int = int(begun.get("token", 0))
	var preparing_capture: Dictionary = game.call("build_save_request")
	_assert_transition_capture_rejected(preparing_capture, "PREPARING", failures)

	var ready: Dictionary = session.mark_destination_ready(token)
	if not _require_success(ready, "READY transition mark", failures):
		_free_attached(game)
		return failures
	var ready_capture: Dictionary = game.call("build_save_request")
	_assert_transition_capture_rejected(ready_capture, "READY", failures)

	var rolled_back: Dictionary = session.fail_transition(token)
	if not _require_success(rolled_back, "READY transition rollback", failures):
		_free_attached(game)
		return failures
	if not bool(rolled_back.get("did_rollback", false)):
		failures.append("READY rollback did not report did_rollback ownership")
	var after_rollback: Dictionary = game.call("build_save_request")
	if _require_success(after_rollback, "post-rollback ACTIVE Game SAVE capture", failures):
		_assert_request_contains_only_committed_session(after_rollback, WorldDomainSessionState.DOMAIN_OVERWORLD, failures)

	var begun_commit: Dictionary = session.begin_transition(_transition_request())
	if not _require_success(begun_commit, "committed transition begin", failures):
		_free_attached(game)
		return failures
	var commit_token: int = int(begun_commit.get("token", 0))
	var commit_ready: Dictionary = session.mark_destination_ready(commit_token)
	if not _require_success(commit_ready, "committed transition ready", failures):
		_free_attached(game)
		return failures
	var committed: Dictionary = session.commit_transition(commit_token)
	if not _require_success(committed, "committed transition commit", failures):
		_free_attached(game)
		return failures
	if not bool(committed.get("did_commit", false)):
		failures.append("successful semantic transition did not report did_commit ownership")
	var after_commit: Dictionary = game.call("build_save_request")
	if _require_success(after_commit, "post-commit ACTIVE Game SAVE capture", failures):
		_assert_request_contains_only_committed_session(after_commit, WorldDomainSessionState.DOMAIN_UNDERWORLD, failures)

	_free_attached(game)
	return failures


static func _transition_request() -> Dictionary:
	return {
		"source_domain": WorldDomainSessionState.DOMAIN_OVERWORLD,
		"destination_domain": WorldDomainSessionState.DOMAIN_UNDERWORLD,
		"gateway_identity": "gateway.reviewer.phase",
		"arrival_locator": Vector3(12.0, -72.0, -5.0),
		"return_context": {
			"gateway_link_id": "gateway.reviewer.phase",
			"source_site_id": "surface.reviewer.phase",
		},
	}


static func _assert_transition_capture_rejected(
	result: Dictionary,
	phase_label: String,
	failures: Array[String]
) -> void:
	if bool(result.get("success", false)):
		failures.append("Game.build_save_request unexpectedly succeeded during %s" % phase_label)
	if result.has("request"):
		failures.append("Game.build_save_request exposed a detached request during %s" % phase_label)
	var found_transition_diagnostic: bool = false
	for diagnostic in result.get("diagnostics", []):
		var text: String = str(diagnostic)
		if text.contains("in-flight world-domain transition") or text.contains("ACTIVE world-domain phase"):
			found_transition_diagnostic = true
			break
	if not found_transition_diagnostic:
		failures.append("%s SAVE rejection did not identify world-domain transition state: %s" % [
			phase_label,
			result.get("diagnostics", []),
		])


static func _assert_request_contains_only_committed_session(
	request_object: Dictionary,
	expected_domain: String,
	failures: Array[String]
) -> void:
	var request_variant: Variant = request_object.get("request", null)
	if not request_variant is Dictionary:
		failures.append("ACTIVE SAVE capture omitted detached request Dictionary")
		return
	var request: Dictionary = request_variant
	var session_variant: Variant = request.get("world_session", null)
	if not session_variant is Dictionary:
		failures.append("ACTIVE SAVE capture omitted durable world_session Dictionary")
		return
	var durable_session: Dictionary = session_variant
	if str(durable_session.get("active_domain", "")) != expected_domain:
		failures.append("ACTIVE SAVE capture persisted wrong active domain: %s" % durable_session.get("active_domain", ""))
	var keys: Array[String] = []
	for raw_key in durable_session.keys():
		keys.append(str(raw_key))
	keys.sort()
	if keys != ["active_domain", "committed_return_context"]:
		failures.append("ACTIVE SAVE capture leaked transient world-session keys: %s" % [keys])
	for forbidden in ["attempt", "token", "phase", "readiness", "destination_ready"]:
		if durable_session.has(forbidden):
			failures.append("ACTIVE SAVE capture persisted transient world-session field: %s" % forbidden)
	var resume: Dictionary = request.get("player_resume", {})
	if str(resume.get("domain", "")) != expected_domain:
		failures.append("ACTIVE SAVE capture did not scope Player resume to committed domain")


static func _free_attached(node: Node) -> void:
	if node == null:
		return
	if node.is_inside_tree():
		var parent: Node = node.get_parent()
		if parent != null:
			parent.remove_child(node)
	node.free()


static func _require_success(result: Dictionary, label: String, failures: Array[String]) -> bool:
	if bool(result.get("success", false)):
		return true
	failures.append("%s failed diagnostics=%s" % [label, result.get("diagnostics", [])])
	return false
