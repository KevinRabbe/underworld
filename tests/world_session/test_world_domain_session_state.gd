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
		str(owned_attempt.get("source_domain", "")) == State.DOMAIN_OVERWORLD
		and str(owned_attempt.get("destination_domain", "")) == State.DOMAIN_UNDERWORLD
		and str(owned_attempt.get("gateway_identity", {}).get("link_id", "")) == "gateway:pair:a"
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
		"gateway_identity": false,
		"arrival_locator": {},
	})
	var caller_token: Dictionary = session.begin_transition({
		"source_domain": State.DOMAIN_UNDERWORLD,
		"destination_domain": State.DOMAIN_OVERWORLD,
		"gateway_identity": "gateway:caller-token",
		"arrival_locator": "overworld:site:a",
		"token": 999,
	})
	_expect(
		failures,
		"wrong-source same-domain malformed and caller-token requests fail closed",
		not bool(wrong_source.get("success", false))
		and not bool(same_domain.get("success", false))
		and not bool(malformed.get("success", false))
		and not bool(caller_token.get("success", false))
		and session.active_domain() == State.DOMAIN_UNDERWORLD
		and not session.has_active_attempt()
	)

	var canonical_session := State.new()
	var key_equivalence_probe: Dictionary = {}
	key_equivalence_probe[StringName("site_id")] = StringName("underworld:site:from-string-name")
	key_equivalence_probe["site_id"] = StringName("underworld:site:canonical")
	var key_equivalence_keys: Array = key_equivalence_probe.keys()
	_expect(
		failures,
		"equal StringName and String Dictionary keys coalesce while preserving the original raw key Variant",
		key_equivalence_probe.size() == 1
		and key_equivalence_keys.size() == 1
		and typeof(key_equivalence_keys[0]) == TYPE_STRING_NAME
		and key_equivalence_probe.has(StringName("site_id"))
		and key_equivalence_probe.has("site_id")
		and str(key_equivalence_probe.get("site_id", "")) == "underworld:site:canonical"
	)
	var canonical_arrival: Dictionary = key_equivalence_probe.duplicate(true)
	canonical_arrival["path"] = [StringName("entrance"), {StringName("segment"): StringName("a")}]
	var canonical_return_context: Dictionary = {}
	canonical_return_context[StringName("gateway_identity")] = StringName("gateway:canonical")
	canonical_return_context["source_site"] = StringName("overworld:site:canonical")
	var canonical_begin: Dictionary = canonical_session.begin_transition({
		"source_domain": State.DOMAIN_OVERWORLD,
		"destination_domain": State.DOMAIN_UNDERWORLD,
		"gateway_identity": StringName("gateway:canonical"),
		"arrival_locator": canonical_arrival,
		"return_context": canonical_return_context,
	})
	var canonical_token: int = int(canonical_begin.get("token", 0))
	var canonical_attempt: Dictionary = canonical_session.runtime_snapshot().get("attempt", {})
	_expect(
		failures,
		"surviving StringName Dictionary keys and values are recursively normalized into canonical String-owned attempt data",
		bool(canonical_begin.get("success", false))
		and bool(canonical_begin.get("did_begin", false))
		and canonical_token == 1
		and typeof(canonical_attempt.get("gateway_identity")) == TYPE_STRING
		and _is_canonical_semantic(canonical_attempt.get("arrival_locator", {}))
		and _is_canonical_semantic(canonical_attempt.get("return_context", {}))
	)
	canonical_session.mark_destination_ready(canonical_token)
	var canonical_commit: Dictionary = canonical_session.commit_transition(canonical_token)
	var canonical_durable: Dictionary = canonical_session.durable_snapshot()
	_expect(
		failures,
		"durable snapshot exposes canonical String domain and recursively canonical transport-safe committed values",
		bool(canonical_commit.get("success", false))
		and bool(canonical_commit.get("did_commit", false))
		and typeof(canonical_durable.get("active_domain")) == TYPE_STRING
		and _is_canonical_semantic(canonical_durable.get("committed_return_context", {}))
		and typeof(canonical_durable.get("committed_return_context", {}).get("gateway_identity")) == TYPE_STRING
	)

	var validation_session := State.new()
	var runtime_node := Node.new()
	var invalid_node: Dictionary = validation_session.begin_transition({
		"source_domain": State.DOMAIN_OVERWORLD,
		"destination_domain": State.DOMAIN_UNDERWORLD,
		"gateway_identity": runtime_node,
		"arrival_locator": "underworld:site:validation",
	})
	var invalid_rid: Dictionary = validation_session.begin_transition({
		"source_domain": State.DOMAIN_OVERWORLD,
		"destination_domain": State.DOMAIN_UNDERWORLD,
		"gateway_identity": RID(),
		"arrival_locator": "underworld:site:validation",
	})
	var invalid_callable: Dictionary = validation_session.begin_transition({
		"source_domain": State.DOMAIN_OVERWORLD,
		"destination_domain": State.DOMAIN_UNDERWORLD,
		"gateway_identity": Callable(),
		"arrival_locator": "underworld:site:validation",
	})
	var invalid_non_finite: Dictionary = validation_session.begin_transition({
		"source_domain": State.DOMAIN_OVERWORLD,
		"destination_domain": State.DOMAIN_UNDERWORLD,
		"gateway_identity": "gateway:validation",
		"arrival_locator": {"position": Vector3(INF, 0.0, 0.0)},
	})
	var invalid_key_context: Dictionary = {}
	invalid_key_context[7] = "not-a-string-key"
	var invalid_key: Dictionary = validation_session.begin_transition({
		"source_domain": State.DOMAIN_OVERWORLD,
		"destination_domain": State.DOMAIN_UNDERWORLD,
		"gateway_identity": "gateway:validation",
		"arrival_locator": "underworld:site:validation",
		"return_context": invalid_key_context,
	})
	_expect(
		failures,
		"runtime references non-finite values and non-string-key containers fail closed without session mutation",
		not bool(invalid_node.get("success", false))
		and not bool(invalid_rid.get("success", false))
		and not bool(invalid_callable.get("success", false))
		and not bool(invalid_non_finite.get("success", false))
		and not bool(invalid_key.get("success", false))
		and validation_session.active_domain() == State.DOMAIN_OVERWORLD
		and validation_session.transition_phase() == State.PHASE_ACTIVE
		and not validation_session.has_active_attempt()
	)
	runtime_node.free()
	var valid_after_rejections: Dictionary = validation_session.begin_transition({
		"source_domain": State.DOMAIN_OVERWORLD,
		"destination_domain": State.DOMAIN_UNDERWORLD,
		"gateway_identity": "gateway:first-valid",
		"arrival_locator": "underworld:site:first-valid",
	})
	_expect(
		failures,
		"rejected malformed payloads do not consume the service-owned attempt-token sequence",
		bool(valid_after_rejections.get("success", false))
		and bool(valid_after_rejections.get("did_begin", false))
		and int(valid_after_rejections.get("token", 0)) == 1
	)
	validation_session.fail_transition(int(valid_after_rejections.get("token", 0)))

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
		and typeof(authoritative_durable.get("active_domain")) == TYPE_STRING
		and _is_canonical_semantic(authoritative_durable.get("committed_return_context", {}))
	)
	_expect(
		failures,
		"live session exposes no in-place durable restore mutation path",
		not session.has_method("restore_durable")
	)

	var restore_result: Dictionary = State.restore_from_durable(authoritative_durable)
	var restored = null
	if bool(restore_result.get("success", false)):
		restored = State.new(
			str(restore_result.get("active_domain", "")),
			restore_result.get("committed_return_context", {})
		)
	authoritative_durable["active_domain"] = State.DOMAIN_OVERWORLD
	authoritative_durable["committed_return_context"]["source_site"] = "mutated:restore-input"
	restore_result["committed_return_context"]["source_site"] = "mutated:validated-output"
	_expect(
		failures,
		"durable restore validates then constructs one fresh clean ACTIVE state with deep ownership",
		bool(restore_result.get("success", false))
		and bool(restore_result.get("did_restore", false))
		and restored != null
		and restored.active_domain() == State.DOMAIN_UNDERWORLD
		and restored.transition_phase() == State.PHASE_ACTIVE
		and not restored.has_active_attempt()
		and str(restored.committed_return_context_snapshot().get("source_site", "")) == "overworld:site:a"
	)

	var same_position := Vector3(7.0, 8.0, 9.0)
	var overworld_result: Dictionary = State.restore_from_durable({
		"active_domain": State.DOMAIN_OVERWORLD,
		"committed_return_context": {"position": same_position},
	})
	var underworld_result: Dictionary = State.restore_from_durable({
		"active_domain": State.DOMAIN_UNDERWORLD,
		"committed_return_context": {"position": same_position},
	})
	var overworld_restore = null
	var underworld_restore = null
	if bool(overworld_result.get("success", false)):
		overworld_restore = State.new(
			str(overworld_result.get("active_domain", "")),
			overworld_result.get("committed_return_context", {})
		)
	if bool(underworld_result.get("success", false)):
		underworld_restore = State.new(
			str(underworld_result.get("active_domain", "")),
			underworld_result.get("committed_return_context", {})
		)
	_expect(
		failures,
		"identical numeric positions do not determine world-domain truth",
		bool(overworld_result.get("success", false))
		and bool(underworld_result.get("success", false))
		and overworld_restore != null
		and underworld_restore != null
		and overworld_restore.active_domain() == State.DOMAIN_OVERWORLD
		and underworld_restore.active_domain() == State.DOMAIN_UNDERWORLD
		and overworld_restore.committed_return_context_snapshot().get("position")
			== underworld_restore.committed_return_context_snapshot().get("position")
	)

	var transient_restore: Dictionary = State.restore_from_durable({
		"active_domain": State.DOMAIN_OVERWORLD,
		"committed_return_context": {},
		"phase": State.PHASE_READY,
	})
	_expect(
		failures,
		"restore rejects persisted transient attempt state before construction",
		not bool(transient_restore.get("success", false))
		and not bool(transient_restore.get("did_restore", true))
		and str(transient_restore.get("active_domain", "")).is_empty()
		and transient_restore.get("committed_return_context", {}) == {}
	)

	return failures


static func _is_canonical_semantic(value: Variant) -> bool:
	match typeof(value):
		TYPE_STRING:
			return not str(value).strip_edges().is_empty()
		TYPE_INT, TYPE_BOOL, TYPE_VECTOR2I, TYPE_VECTOR3I:
			return true
		TYPE_FLOAT:
			return is_finite(float(value))
		TYPE_VECTOR2:
			var vector2_value: Vector2 = value
			return is_finite(vector2_value.x) and is_finite(vector2_value.y)
		TYPE_VECTOR3:
			var vector3_value: Vector3 = value
			return is_finite(vector3_value.x) and is_finite(vector3_value.y) and is_finite(vector3_value.z)
		TYPE_ARRAY:
			for entry in value:
				if not _is_canonical_semantic(entry):
					return false
			return true
		TYPE_DICTIONARY:
			for raw_key in value.keys():
				if typeof(raw_key) != TYPE_STRING or str(raw_key).strip_edges().is_empty():
					return false
				if not _is_canonical_semantic(value[raw_key]):
					return false
			return true
		_:
			return false


static func _expect(
	failures: Array[String],
	label: String,
	condition: bool
) -> void:
	if not condition:
		failures.append(label)