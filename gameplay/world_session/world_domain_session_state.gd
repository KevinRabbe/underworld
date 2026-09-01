extends RefCounted
class_name WorldDomainSessionState

const DOMAIN_OVERWORLD: String = "OVERWORLD"
const DOMAIN_UNDERWORLD: String = "UNDERWORLD"

const PHASE_ACTIVE: String = "ACTIVE"
const PHASE_PREPARING: String = "DESTINATION_PREPARING"
const PHASE_READY: String = "DESTINATION_READY"

const _REQUEST_KEYS: Array[String] = [
	"source_domain",
	"destination_domain",
	"gateway_identity",
	"arrival_locator",
	"return_context",
]
const _DURABLE_KEYS: Array[String] = [
	"active_domain",
	"committed_return_context",
]

var _active_domain: String = DOMAIN_OVERWORLD
var _attempt: Dictionary = {}
var _committed_return_context: Dictionary = {}
var _next_attempt_token: int = 1


func _init(
	active_domain_value: String = DOMAIN_OVERWORLD,
	committed_return_context_value: Dictionary = {}
) -> void:
	if not _is_domain(active_domain_value):
		push_error("WorldDomainSessionState requires a canonical initial domain")
		return
	var failures: Array[String] = []
	_append_semantic_failures(
		failures,
		committed_return_context_value,
		"committed_return_context",
		false
	)
	if not failures.is_empty():
		push_error("WorldDomainSessionState requires semantic committed return context")
		return
	_active_domain = active_domain_value
	_committed_return_context = _canonicalize_semantic(committed_return_context_value)


func active_domain() -> String:
	return _active_domain


func transition_phase() -> String:
	if _attempt.is_empty():
		return PHASE_ACTIVE
	return str(_attempt.get("phase", PHASE_PREPARING))


func has_active_attempt() -> bool:
	return not _attempt.is_empty()


func current_attempt_token() -> int:
	if _attempt.is_empty():
		return 0
	return int(_attempt.get("token", 0))


func committed_return_context_snapshot() -> Dictionary:
	return _canonicalize_semantic(_committed_return_context)


func begin_transition(request: Dictionary) -> Dictionary:
	var failures: Array[String] = []
	if not _attempt.is_empty():
		failures.append("World session rejects nested transition while an attempt is active")
	failures.append_array(_validate_transition_request(request))
	if not failures.is_empty():
		return _failure(failures, {"did_begin": false, "token": 0})

	var token: int = _allocate_attempt_token()
	if token <= 0:
		return _failure(
			["World session exhausted its non-reused attempt-token space"],
			{"did_begin": false, "token": 0}
		)

	_attempt = {
		"token": token,
		"phase": PHASE_PREPARING,
		"source_domain": str(request.get("source_domain", "")),
		"destination_domain": str(request.get("destination_domain", "")),
		"gateway_identity": _canonicalize_semantic(request.get("gateway_identity", null)),
		"arrival_locator": _canonicalize_semantic(request.get("arrival_locator", null)),
		"return_context": _canonicalize_semantic(request.get("return_context", {})),
	}
	return _success({
		"did_begin": true,
		"token": token,
		"phase": PHASE_PREPARING,
		"active_domain": _active_domain,
	})


func mark_destination_ready(token: int) -> Dictionary:
	var ownership_failure: Dictionary = _attempt_ownership_failure(token, "mark destination ready")
	if not ownership_failure.is_empty():
		ownership_failure["did_mark_ready"] = false
		return ownership_failure
	if str(_attempt.get("phase", "")) != PHASE_PREPARING:
		return _failure(
			["World session destination readiness may only be marked from PREPARING"],
			{"did_mark_ready": false}
		)
	_attempt["phase"] = PHASE_READY
	return _success({
		"did_mark_ready": true,
		"token": token,
		"phase": PHASE_READY,
		"active_domain": _active_domain,
	})


func commit_transition(token: int) -> Dictionary:
	var ownership_failure: Dictionary = _attempt_ownership_failure(token, "commit transition")
	if not ownership_failure.is_empty():
		ownership_failure["did_commit"] = false
		return ownership_failure
	if str(_attempt.get("phase", "")) != PHASE_READY:
		return _failure(
			["World session commit requires destination readiness"],
			{"did_commit": false, "active_domain": _active_domain}
		)

	var destination_domain: String = str(_attempt.get("destination_domain", ""))
	var committed_return_context: Dictionary = _canonicalize_semantic(
		_attempt.get("return_context", {})
	)
	_active_domain = destination_domain
	_committed_return_context = committed_return_context
	_attempt.clear()
	return _success({
		"did_commit": true,
		"token": token,
		"active_domain": _active_domain,
		"phase": PHASE_ACTIVE,
		"committed_return_context": _canonicalize_semantic(_committed_return_context),
	})


func fail_transition(token: int) -> Dictionary:
	var ownership_failure: Dictionary = _attempt_ownership_failure(token, "fail transition")
	if not ownership_failure.is_empty():
		ownership_failure["did_rollback"] = false
		return ownership_failure
	var source_domain: String = str(_attempt.get("source_domain", ""))
	_attempt.clear()
	return _success({
		"did_rollback": true,
		"token": token,
		"active_domain": _active_domain,
		"source_domain": source_domain,
		"phase": PHASE_ACTIVE,
	})


func runtime_snapshot() -> Dictionary:
	return {
		"active_domain": _active_domain,
		"phase": transition_phase(),
		"attempt": _canonicalize_semantic(_attempt),
		"committed_return_context": _canonicalize_semantic(_committed_return_context),
	}


func durable_snapshot() -> Dictionary:
	return {
		"active_domain": _active_domain,
		"committed_return_context": _canonicalize_semantic(_committed_return_context),
	}


static func restore_from_durable(snapshot: Dictionary) -> Dictionary:
	var failures: Array[String] = []
	for raw_key in snapshot.keys():
		var key: String = str(raw_key)
		if not _DURABLE_KEYS.has(key):
			failures.append("Durable world-session snapshot contains unsupported key: " + key)
	var restored_domain: String = str(snapshot.get("active_domain", ""))
	if not _is_domain(restored_domain):
		failures.append("Durable world-session snapshot requires canonical active_domain")
	var return_context_variant: Variant = snapshot.get("committed_return_context", {})
	if not return_context_variant is Dictionary:
		failures.append("Durable world-session committed_return_context must be a Dictionary")
	else:
		_append_semantic_failures(
			failures,
			return_context_variant,
			"committed_return_context",
			false
		)
	if not failures.is_empty():
		return {
			"success": false,
			"did_restore": false,
			"active_domain": "",
			"committed_return_context": {},
			"diagnostics": failures.duplicate(),
		}

	return {
		"success": true,
		"did_restore": true,
		"active_domain": restored_domain,
		"committed_return_context": _canonicalize_semantic(return_context_variant),
		"phase": PHASE_ACTIVE,
		"diagnostics": [],
	}


func _validate_transition_request(request: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	for raw_key in request.keys():
		var key: String = str(raw_key)
		if not _REQUEST_KEYS.has(key):
			failures.append("World-session transition request contains unsupported key: " + key)

	var source_domain: String = str(request.get("source_domain", ""))
	var destination_domain: String = str(request.get("destination_domain", ""))
	if not _is_domain(source_domain):
		failures.append("Transition source_domain must be canonical")
	elif source_domain != _active_domain:
		failures.append("Transition source_domain must equal current active domain")
	if not _is_domain(destination_domain):
		failures.append("Transition destination_domain must be canonical")
	elif destination_domain == source_domain:
		failures.append("Transition destination_domain must differ from source_domain")

	if not request.has("gateway_identity"):
		failures.append("Transition requires gateway_identity")
	else:
		_append_identity_failures(
			failures,
			request.get("gateway_identity"),
			"gateway_identity"
		)
	if not request.has("arrival_locator"):
		failures.append("Transition requires arrival_locator")
	else:
		_append_locator_failures(
			failures,
			request.get("arrival_locator"),
			"arrival_locator"
		)

	var return_context_variant: Variant = request.get("return_context", {})
	if not return_context_variant is Dictionary:
		failures.append("Transition return_context must be a Dictionary when supplied")
	else:
		_append_semantic_failures(
			failures,
			return_context_variant,
			"return_context",
			false
		)
	return failures


func _attempt_ownership_failure(token: int, operation: String) -> Dictionary:
	if _attempt.is_empty():
		return _failure(
			["World session cannot %s without an active attempt" % operation],
			{}
		)
	if token <= 0 or token != int(_attempt.get("token", 0)):
		return _failure(
			["World session rejects stale or foreign attempt token for " + operation],
			{}
		)
	return {}


func _allocate_attempt_token() -> int:
	var token: int = _next_attempt_token
	if token <= 0:
		return 0
	_next_attempt_token += 1
	return token


static func _is_domain(value: String) -> bool:
	return value == DOMAIN_OVERWORLD or value == DOMAIN_UNDERWORLD


static func _canonicalize_semantic(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING_NAME:
			return str(value)
		TYPE_ARRAY:
			var result: Array = []
			for entry in value:
				result.append(_canonicalize_semantic(entry))
			return result
		TYPE_DICTIONARY:
			var result: Dictionary = {}
			for raw_key in value.keys():
				result[str(raw_key)] = _canonicalize_semantic(value[raw_key])
			return result
		_:
			return value


static func _append_identity_failures(
	failures: Array[String],
	value: Variant,
	path: String
) -> void:
	match typeof(value):
		TYPE_STRING, TYPE_STRING_NAME:
			if str(value).strip_edges().is_empty():
				failures.append(path + " must not be empty")
		TYPE_INT:
			if int(value) == 0:
				failures.append(path + " numeric identity must be non-zero")
		TYPE_ARRAY, TYPE_DICTIONARY:
			_append_semantic_failures(failures, value, path, true)
		_:
			failures.append(path + " must be a non-empty semantic identity scalar or container")


static func _append_locator_failures(
	failures: Array[String],
	value: Variant,
	path: String
) -> void:
	match typeof(value):
		TYPE_STRING, TYPE_STRING_NAME:
			if str(value).strip_edges().is_empty():
				failures.append(path + " must not be empty")
		TYPE_INT:
			pass
		TYPE_VECTOR2:
			var vector2_value: Vector2 = value
			if not is_finite(vector2_value.x) or not is_finite(vector2_value.y):
				failures.append(path + " must contain only finite Vector2 values")
		TYPE_VECTOR2I:
			pass
		TYPE_VECTOR3:
			var vector3_value: Vector3 = value
			if not is_finite(vector3_value.x) or not is_finite(vector3_value.y) or not is_finite(vector3_value.z):
				failures.append(path + " must contain only finite Vector3 values")
		TYPE_VECTOR3I:
			pass
		TYPE_ARRAY, TYPE_DICTIONARY:
			_append_semantic_failures(failures, value, path, true)
		_:
			failures.append(path + " must be a semantic site locator scalar, vector, or container")


static func _append_semantic_failures(
	failures: Array[String],
	value: Variant,
	path: String,
	require_non_empty: bool
) -> void:
	match typeof(value):
		TYPE_STRING, TYPE_STRING_NAME:
			if str(value).strip_edges().is_empty():
				failures.append(path + " must not contain an empty semantic string")
		TYPE_INT, TYPE_BOOL:
			pass
		TYPE_FLOAT:
			if not is_finite(float(value)):
				failures.append(path + " must contain only finite numeric values")
		TYPE_VECTOR2:
			var vector2_value: Vector2 = value
			if not is_finite(vector2_value.x) or not is_finite(vector2_value.y):
				failures.append(path + " must contain only finite Vector2 values")
		TYPE_VECTOR2I:
			pass
		TYPE_VECTOR3:
			var vector3_value: Vector3 = value
			if not is_finite(vector3_value.x) or not is_finite(vector3_value.y) or not is_finite(vector3_value.z):
				failures.append(path + " must contain only finite Vector3 values")
		TYPE_VECTOR3I:
			pass
		TYPE_ARRAY:
			var array_value: Array = value
			if require_non_empty and array_value.is_empty():
				failures.append(path + " must not be an empty semantic container")
			for index in range(array_value.size()):
				_append_semantic_failures(
					failures,
					array_value[index],
					"%s[%d]" % [path, index],
					false
				)
		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = value
			if require_non_empty and dictionary_value.is_empty():
				failures.append(path + " must not be an empty semantic container")
			# Godot Dictionary equality coalesces equal String/StringName spellings into
			# one entry while preserving the surviving raw key Variant. Distinct raw keys
			# that canonicalize to the same String therefore cannot coexist here.
			for raw_key in dictionary_value.keys():
				if not (raw_key is String or raw_key is StringName):
					failures.append(path + " Dictionary keys must be semantic strings")
					continue
				var key: String = str(raw_key)
				if key.strip_edges().is_empty():
					failures.append(path + " Dictionary keys must not be empty")
					continue
				_append_semantic_failures(
					failures,
					dictionary_value[raw_key],
					path + "." + key,
					false
				)
		_:
			failures.append(path + " contains unsupported runtime/non-semantic value type")


static func _success(extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"success": true,
		"diagnostics": [],
	}
	for key in extra.keys():
		result[key] = _canonicalize_semantic(extra[key])
	return result


static func _failure(failures: Array[String], extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"diagnostics": failures.duplicate(),
	}
	for key in extra.keys():
		result[key] = _canonicalize_semantic(extra[key])
	return result