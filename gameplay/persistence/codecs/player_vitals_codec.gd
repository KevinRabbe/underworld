extends RefCounted

const Support := preload("res://gameplay/persistence/codecs/component_codec_support.gd")

const PLAYER_VITALS_SCHEMA := "persistence.player_vitals.v1"
const PLAYER_VITALS_ROOT_KEYS := ["schema", "current_health", "current_stamina"]


static func encode(current_health: Variant, current_stamina: Variant) -> Dictionary:
	var failures: Array[String] = []
	if typeof(current_health) != TYPE_INT:
		failures.append("player-vitals current_health must be int")
	elif int(current_health) <= 0:
		failures.append("player-vitals current_health must be > 0 for an alive save")
	if typeof(current_stamina) != TYPE_INT and typeof(current_stamina) != TYPE_FLOAT:
		failures.append("player-vitals current_stamina must be numeric")
	else:
		var stamina_value: float = float(current_stamina)
		if is_nan(stamina_value) or is_inf(stamina_value):
			failures.append("player-vitals current_stamina must be finite")
		elif stamina_value < 0.0:
			failures.append("player-vitals current_stamina must be >= 0")
	if not failures.is_empty():
		return Support.failure(failures)
	return Support.encoded({
		"schema": PLAYER_VITALS_SCHEMA,
		"current_health": int(current_health),
		"current_stamina": float(current_stamina),
	}, "player-vitals snapshot")


static func decode(snapshot: Variant) -> Dictionary:
	var failures: Array[String] = []
	var source: Dictionary = Support.require_snapshot(
		snapshot,
		PLAYER_VITALS_SCHEMA,
		"player-vitals",
		PLAYER_VITALS_ROOT_KEYS,
		failures
	)
	if source.is_empty() and not failures.is_empty():
		return Support.failure(failures)
	var raw_health: Variant = source.get("current_health", null)
	var raw_stamina: Variant = source.get("current_stamina", null)
	if typeof(raw_health) != TYPE_INT:
		failures.append("player-vitals snapshot current_health must be int")
	elif int(raw_health) <= 0:
		failures.append("player-vitals snapshot current_health must be > 0 for an alive save")
	if typeof(raw_stamina) != TYPE_INT and typeof(raw_stamina) != TYPE_FLOAT:
		failures.append("player-vitals snapshot current_stamina must be numeric")
	else:
		var stamina_value: float = float(raw_stamina)
		if is_nan(stamina_value) or is_inf(stamina_value):
			failures.append("player-vitals snapshot current_stamina must be finite")
		elif stamina_value < 0.0:
			failures.append("player-vitals snapshot current_stamina must be >= 0")
	if not failures.is_empty():
		return Support.failure(failures)
	return Support.success({
		"state": {
			"current_health": int(raw_health),
			"current_stamina": float(raw_stamina),
		},
	})
