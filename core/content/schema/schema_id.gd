extends RefCounted

const CATEGORY_NAMESPACE := "category"
const CAPABILITY_NAMESPACE := "capability"
const ANIMATION_ROLE_NAMESPACE := "animation_role"
const RIG_ROLE_NAMESPACE := "rig_role"
const _LOWER := "abcdefghijklmnopqrstuvwxyz"
const _TOKEN_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_"


static func validate_category(value: String) -> Array[String]:
	return _validate(value, CATEGORY_NAMESPACE)


static func validate_capability(value: String) -> Array[String]:
	return _validate(value, CAPABILITY_NAMESPACE)


static func validate_animation_role(value: String) -> Array[String]:
	return _validate(value, ANIMATION_ROLE_NAMESPACE)


static func validate_rig_role(value: String) -> Array[String]:
	return _validate(value, RIG_ROLE_NAMESPACE)


static func validate_semantic_role(value: String) -> Array[String]:
	var namespace: String = _raw_namespace(value)
	if namespace == ANIMATION_ROLE_NAMESPACE:
		return validate_animation_role(value)
	if namespace == RIG_ROLE_NAMESPACE:
		return validate_rig_role(value)
	return ["semantic role id must use 'animation_role.' or 'rig_role.' namespace: %s" % value]


static func is_valid_category(value: String) -> bool:
	return validate_category(value).is_empty()


static func is_valid_capability(value: String) -> bool:
	return validate_capability(value).is_empty()


static func is_valid_animation_role(value: String) -> bool:
	return validate_animation_role(value).is_empty()


static func is_valid_rig_role(value: String) -> bool:
	return validate_rig_role(value).is_empty()


static func is_valid_semantic_role(value: String) -> bool:
	return validate_semantic_role(value).is_empty()


static func namespace_of(value: String) -> String:
	if is_valid_category(value):
		return CATEGORY_NAMESPACE
	if is_valid_capability(value):
		return CAPABILITY_NAMESPACE
	if is_valid_animation_role(value):
		return ANIMATION_ROLE_NAMESPACE
	if is_valid_rig_role(value):
		return RIG_ROLE_NAMESPACE
	return ""


static func _raw_namespace(value: String) -> String:
	if value.is_empty() or not value.contains("."):
		return ""
	return value.get_slice(".", 0)


static func _validate(value: String, expected_namespace: String) -> Array[String]:
	var failures: Array[String] = []
	if value.is_empty():
		failures.append("%s schema id is empty" % expected_namespace)
		return failures
	if value != value.strip_edges():
		failures.append("%s schema id must not contain leading/trailing whitespace: %s" % [expected_namespace, value])
		return failures
	if value.begins_with(".") or value.ends_with(".") or value.contains(".."):
		failures.append("%s schema id must not contain empty semantic tokens: %s" % [expected_namespace, value])
		return failures

	var tokens: PackedStringArray = value.split(".", false)
	if tokens.size() < 2:
		failures.append("%s schema id must contain namespace and member tokens: %s" % [expected_namespace, value])
		return failures
	if tokens[0] != expected_namespace:
		failures.append("schema id must use '%s.' namespace: %s" % [expected_namespace, value])
		return failures

	for token in tokens:
		if not _is_ascii_token(token):
			failures.append("%s schema id contains invalid token '%s': %s" % [expected_namespace, token, value])
	return failures


static func _is_ascii_token(token: String) -> bool:
	if token.is_empty():
		return false
	if _LOWER.find(token.substr(0, 1)) < 0:
		return false
	for index in range(token.length()):
		if _TOKEN_CHARS.find(token.substr(index, 1)) < 0:
			return false
	return true
