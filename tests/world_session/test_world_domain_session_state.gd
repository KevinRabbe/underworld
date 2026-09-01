extends RefCounted

const State := preload("res://gameplay/world_session/world_domain_session_state.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var session := State.new()

	_expect(
		failures,
		"default session is one clean OVERWORLD ACTIVE state",
		session.active_domain() == State.DOMAIN_OVERWORLD
		and session.transition_phase() == State.PHASE_ACTIVE
		and not session.has_active_attempt()
		and session.current_attempt_token() == 0
	)

	var gateway_identity := {
		"link_id": "gateway:pair:a",
		"revision": 1,
	}
	var arrival_locator := {
		"site_id": "underworld:site:a",
		"position": Vector3(12.0, 4.0, -8.0),
	}
	var first_return_context := {
		"gateway_identity": "gateway:pair:a",
		"source_site": "overworld:site:a",
		"position": Vector3(3.0, 2.0, 1.0),
	}
	var first_request := {
		"source_domain": State.DOMAIN_OVERWORLD,
		"destination_domain": State.DOMAIN_UNDERWORLD,
		"gateway_identity": gateway_identity,
		"arrival_locator": arrival_locator,
		"return_context": first_return_context,
	}
	var begin_first: Dictionary = session.begin_transition(first_request)
	var first_token: int = int(begin_first.get("token", 0))
	_expect(
		failures,
		"valid transition allocates one service-owned non-zero token without changing active domain",
		bool(begin_first.get("success", false))
		and bool(begin_first.get("did_begin", false))
		and first_token > 0
		and session.active_domain() == State.DOMAIN_OVERWORLD
		and session.transition_phase() == State.PHASE_PREPARING
		and session.current_attempt_token() == first_token
	)

	gateway_identity["link_id"] = "mutated:gateway"
	arrival_locator["site_id"] = "mutated:arrival"
	first_return_context["source_site"] = "mutated:return"
	var owned_attempt: Dictionary = session.runtime_snapshot().get("attempt", {})
	_expect(
		failures,
		"begin deep-owns request semantic values against caller mutation",
		str(owned_attempt.get("gateway_identity", {}).get("link_id", "")) == "gateway:pair:a"
		and str(owned_attempt.get("arrival_locator", {}).get("site_id", "")) == "underworld:site:a"
		and str(owned_attempt.get("return_context", {}).get("source_site", "")) == "overworld:site:a"
	)

	var premature_commit: Dictionary = session.commit_transition(first_token)
	_expect(
		failures,
		"commit before destination readiness fails closed without mutation",
		not bool(premature_commit.get("success", false))
		and not bool(premature_commit.get("did_commit", true))
		and session.active_domain() == State.DOMAIN_OVERWORLD
		and session.transition_phase() == State.PHASE_PREPARING
	)

	var first_ready: Dictionary = session.mark_destination_ready(first_token)
	_expect(
		failures,
		"current-token readiness changes only attempt phase",
		bool(first_ready.get("success", false))
		and bool(first_ready.get("did_mark_ready", false))
		and session.active_domain() == State.DOMAIN_OVERWORLD
		and session.transition_phase() == State.PHASE_READY
	)
	var duplicate_ready: Dictionary = session.mark_destination_ready(first_token)
	_expect(
		failures,
		"duplicate readiness is rejected without committing",
		not bool(duplicate_ready.get("success", false))
		and not bool(duplicate_ready.get("did_mark_ready", true))
		and session.active_domain() == State.DOMAIN_OVERWORLD
		and session.transition_phase() == State.PHASE_READY
	)

	var first_commit: Dictionary = session.commit_transition(first_token)
	var committed_return_context: Dictionary = session.committed_return_context_snapshot()
	_expect(
		failures,
		"first ready commit mutates active domain exactly once and retires transient attempt",
		bool(first_commit.get("success", false))
		and bool(first_commit.get("did_commit", false))
		and session.active_domain() == State.DOMAIN_UNDERWORLD
		and session.transition_phase() == State.PHASE_ACTIVE
		and not session.has_active_attempt()
		and session.current_attempt_token() == 0
	)
	_expect(
		failures,
		"commit copies the pre-mutation return context only at the commit point",
		str(committed_return_context.get("gateway_identity", "")) == "gateway:pair:a"
		and str(committed_return_context.get("source_site", "")) == "overworld:site:a"
		and committed_return_context.get("position", Vector3.ZERO) == Vector3(3.0, 2.0, 1.0)
	)
	var duplicate_commit: Dictionary = session.commit_transition(first_token)
	_expect(
		failures,
		"duplicate commit cannot produce a second mutation",
		not bool(duplicate_commit.get("success", false))
		and not bool(duplicate_commit.get("did_commit", true))
		and session.active_domain() == State.DOMAIN_UNDERWORLD
	)

	var second_request := {
		"source_domain": State.DOMAIN_UNDERWORLD,
		"destination_domain": State.DOMAIN_OVERWORLD,
		"gateway_identity": "gateway:pair:a",
		"arrival_locator": {
			"site_id": "overworld:site:a",
			"position": Vector3(12.0, 4.0, -8.0),
		},
		"return_context": {
			"gateway_identity": "gateway:pair:a",
			"source_site": "underworld:site:a",
		},
	}
	var begin_second: Dictionary = session.begin_transition(second_request)
	var second_token: int = int(begin_second.get("token", 0))
	_expect(
		failures,
		"fresh attempt receives a strictly newer token",
		bool(begin_second.get("success", false)) and second_token > first_token
	)
	var stale_ready: Dictionary = session.mark_destination_ready(first_token)
	var stale_fail: Dictionary = session.fail_transition(first_token)
	var stale_commit: Dictionary = session.commit_transition(first_token)
	_expect(
		failures,
		"stale old-token ready fail and commit cannot affect the current attempt",
		not bool(stale_ready.get("success", false))
		and not bool(stale_fail.get("success", false))
		and not bool(stale_commit.get("success", false))
		and session.current_attempt_token() == second_token
		and session.transition_phase() == State.PHASE_PREPARING
		and session.active_domain() == State.DOMAIN_UNDERWORLD
	)

	var second_ready: Dictionary = session.mark_destination_ready(second_token)
	var second_fail: Dictionary = session.fail_transition(second_token)
	_expect(
		failures,
		"ready-then-fail rolls back to source ACTIVE without changing prior committed return context",
		bool(second_ready.get("success", false))
		and bool(second_fail.get("success", false))
		and bool(second_fail.get("did_rollback", false))
		and session.active_domain() == State.DOMAIN_UNDERWORLD
		and session.transition_phase() == State.PHASE_ACTIVE
		and session.committed_return_context_snapshot() == committed_return_context
	)

	var begin_third: Dictionary = session.begin_transition(second_request)
	var third_token: int = int(begin_third.get("token", 0))
	_expect(
		failures,
		"failed attempt permits a fresh non-reused token",
		bool(begin_third.get("success", false)) and third_token > second_token
	)
	var nested: Dictionary = session.begin_transition(second_request)
	_expect(
		failures,
		"nested attempt fails closed and preserves current ownership",
		not bool(nested.get("success", false))
		and session.current_attempt_token() == third_token
		and session.transition_phase() == State.PHASE_PREPARING
	)
	session.fail_transition(third_token)

	var wrong_source: Dictionary = session.begin_transition({
		"source_domain": State.DOMAIN_OVERWORLD,
		"destination_domain": State.DOMAIN_UNDERWORLD,
		"gateway_identity": "gateway:wrong-source",
		"arrival_locator": "underworld:site:a",
	})
	var same_domain: Dictionary = session.begin_transition({
		"source_domain": State.DOMAIN_UNDERWORLD,
		"destination_domain": State.DOMAIN_UNDERWORLD,
		"gateway_identity": "gateway:same-domain",
		"arrival_locator": "underworld:site:a",
	})
	var malformed: Dictionary = session.begin_transition({
		"source_domain": State.DOMAIN_UNDERWORLD,
		"destination_domain": State.DOMAIN_OVERWORLD,
		"gateway_identity": "",
		"arrival_locator": {},
	})
	_expect(
		failures,
		"wrong-source same-domain and malformed transition requests fail closed",
		not bool(wrong_source.get("success", false))
		and not bool(same_domain.get("success", false))
		and not bool(malformed.get("success", false))
		and session.active_domain() == State.DOMAIN_UNDERWORLD
		and not session.has_active_attempt()
	)

	var runtime_snapshot: Dictionary = session.runtime_snapshot()
	runtime_snapshot["active_domain"] = State.DOMAIN_OVERWORLD
	runtime_snapshot["committed_return_context"]["source_site"] = "mutated:snapshot"
	var durable_snapshot: Dictionary = session.durable_snapshot()
	durable_snapshot["active_domain"] = State.DOMAIN_OVERWORLD
	durable_snapshot["committed_return_context"]["source_site"] = "mutated:durable"
	_expect(
		failures,
		"returned runtime and durable snapshots cannot mutate service authority",
		session.active_domain() == State.DOMAIN_UNDERWORLD
		and str(session.committed_return_context_snapshot().get("source_site", "")) == "overworld:site:a"
	)

	var authoritative_durable: Dictionary = session.durable_snapshot()
	_expect(
		failures,
		"durable snapshot contains committed truth only",
		authoritative_durable.size() == 2
		and authoritative_durable.has("active_domain")
		and authoritative_durable.has("committed_return_context")
		and not authoritative_durable.has("phase")
		and not authoritative_durable.has("token")
		and not authoritative_durable.has("readiness")
		and not authoritative_durable.has("attempt")
	)

	var restored := State.new(State.DOMAIN_OVERWORLD)
	var restore_result: Dictionary = restored.restore_durable(authoritative_durable)
	authoritative_durable["active_domain"] = State.DOMAIN_OVERWORLD
	authoritative_durable["committed_return_context"]["source_site"] = "mutated:restore-input"
	_expect(
		failures,
		"durable restore creates one clean ACTIVE state and deep-owns restored data",
		bool(restore_result.get("success", false))
		and bool(restore_result.get("did_restore", false))
		and restored.active_domain() == State.DOMAIN_UNDERWORLD
		and restored.transition_phase() == State.PHASE_ACTIVE
		and not restored.has_active_attempt()
		and str(restored.committed_return_context_snapshot().get("source_site", "")) == "overworld:site:a"
	)

	var same_position := Vector3(7.0, 8.0, 9.0)
	var overworld_restore := State.new()
	var underworld_restore := State.new()
	var overworld_result: Dictionary = overworld_restore.restore_durable({
		"active_domain": State.DOMAIN_OVERWORLD,
		"committed_return_context": {"position": same_position},
	})
	var underworld_result: Dictionary = underworld_restore.restore_durable({
		"active_domain": State.DOMAIN_UNDERWORLD,
		"committed_return_context": {"position": same_position},
	})
	_expect(
		failures,
		"identical numeric positions do not determine world-domain truth",
		bool(overworld_result.get("success", false))
		and bool(underworld_result.get("success", false))
		and overworld_restore.active_domain() == State.DOMAIN_OVERWORLD
		and underworld_restore.active_domain() == State.DOMAIN_UNDERWORLD
		and overworld_restore.committed_return_context_snapshot().get("position")
			== underworld_restore.committed_return_context_snapshot().get("position")
	)

	var transient_restore: Dictionary = restored.restore_durable({
		"active_domain": State.DOMAIN_OVERWORLD,
		"committed_return_context": {},
		"phase": State.PHASE_READY,
	})
	_expect(
		failures,
		"restore rejects persisted transient attempt state without mutating committed truth",
		not bool(transient_restore.get("success", false))
		and restored.active_domain() == State.DOMAIN_UNDERWORLD
		and restored.transition_phase() == State.PHASE_ACTIVE
	)

	return failures


static func _expect(
	failures: Array[String],
	label: String,
	condition: bool
) -> void:
	if not condition:
		failures.append(label)
