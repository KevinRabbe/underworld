extends RefCounted

const _LOWER := "abcdefghijklmnopqrstuvwxyz"
const _TOKEN_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_"


static func validate(value: String) -> Array[String]:
	var failures: Array[String] = []
	if value.is_empty():
		failures.append("content id is empty")
		return failures
	if value != value.strip_edges():
		failures.append("content id must not contain leading/trailing whitespace: %s" % value)
		return failures

	var tokens: PackedStringArray = value.split(".", false)
	if tokens.size() < 2:
		failures.append("content id must contain at least family and member tokens: %s" % value)
		return failures

	for token in tokens:
		if not _is_ascii_token(token):
			failures.append("content id contains invalid token '%s': %s" % [token, value])
	return failures


static func is_valid(value: String) -> bool:
	return validate(value).is_empty()


static func family_of(value: String) -> String:
	if not is_valid(value):
		return ""
	return value.get_slice(".", 0)


static func validate_family(value: String) -> Array[String]:
	var failures: Array[String] = []
	if value.is_empty():
		failures.append("definition family is empty")
		return failures
	if not _is_ascii_token(value):
		failures.append("definition family must be one lowercase ASCII semantic token: %s" % value)
	return failures


static func is_valid_family(value: String) -> bool:
	return validate_family(value).is_empty()


static func _is_ascii_token(token: String) -> bool:
	if token.is_empty():
		return false
	if _LOWER.find(token.substr(0, 1)) < 0:
		return false
	for index in range(token.length()):
		if _TOKEN_CHARS.find(token.substr(index, 1)) < 0:
			return false
	return true
