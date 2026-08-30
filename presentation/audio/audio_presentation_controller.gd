extends Node
class_name UnderworldAudioPresentationController

const CueCatalog := preload("res://presentation/audio/audio_cue_catalog.gd")
const CueDefinition := preload("res://presentation/audio/audio_cue_definition.gd")
const REQUEST_KEYS: Array[String] = ["intensity", "position"]

var catalog
var muted: bool = false
var last_diagnostics: Array[String] = []
var _ambience_role: String = CueCatalog.AMBIENCE_NONE
var _ambience_player: AudioStreamPlayer = null


func configure(catalog_value, muted_value: bool = false) -> Array[String]:
	_clear_players()
	catalog = catalog_value
	muted = muted_value
	_ambience_role = CueCatalog.AMBIENCE_NONE
	last_diagnostics.clear()
	if catalog == null or not catalog is CueCatalog:
		last_diagnostics.append("AudioCueCatalog is required")
		return last_diagnostics.duplicate()
	last_diagnostics.append_array(catalog.validate_catalog())
	last_diagnostics.sort()
	return last_diagnostics.duplicate()


func set_muted(value: bool) -> void:
	if muted == value:
		return
	muted = value
	if muted:
		for child in get_children():
			if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
				child.stop()
		return
	_resume_selected_ambience()


func dispatch(cue_id: String, payload: Dictionary = {}) -> Dictionary:
	if catalog == null or not catalog is CueCatalog:
		return _record(_dispatch_result(false, cue_id, "", false, ["AudioCueCatalog is not configured"], {}))
	var resolved: Dictionary = catalog.resolve(cue_id)
	var diagnostics: Array[String] = _strings(resolved.get("diagnostics", []))
	var definition = resolved.get("definition", null)
	if not diagnostics.is_empty() or definition == null or not definition is CueDefinition:
		if diagnostics.is_empty():
			diagnostics.append("audio cue did not resolve to AudioCueDefinition: %s" % cue_id)
		return _record(_dispatch_result(false, cue_id, "", false, diagnostics, {}))

	diagnostics = _validate_payload(definition, payload)
	if not diagnostics.is_empty():
		return _record(_dispatch_result(false, cue_id, definition.playback_space, false, diagnostics, {}))
	var request: Dictionary = _request_descriptor(definition, payload)
	if muted:
		return _record(_dispatch_result(true, cue_id, definition.playback_space, false, ["audio presentation is muted: %s" % cue_id], request))
	if definition.stream == null:
		return _record(_dispatch_result(true, cue_id, definition.playback_space, false, ["audio cue has no presentation stream: %s" % cue_id], request))
	if not is_inside_tree():
		return _record(_dispatch_result(true, cue_id, definition.playback_space, false, ["audio controller is not inside SceneTree; playback skipped: %s" % cue_id], request))

	var intensity := float(payload.get("intensity", 1.0))
	var player
	if definition.playback_space == CueDefinition.PLAYBACK_SPATIAL:
		player = AudioStreamPlayer3D.new()
		player.position = payload.get("position", Vector3.ZERO)
	else:
		player = AudioStreamPlayer.new()
	player.name = "AudioOneShot"
	player.stream = definition.stream
	player.volume_db = definition.volume_db + lerpf(-6.0, 0.0, clampf(intensity, 0.0, 1.0))
	add_child(player)
	player.finished.connect(Callable(self, "_on_one_shot_finished").bind(player))
	player.play()
	return _record(_dispatch_result(true, cue_id, definition.playback_space, true, [], request))


func set_ambience_role(role: String) -> Dictionary:
	if catalog == null or not catalog is CueCatalog:
		return _record(_ambience_result(false, role, "", false, false, ["AudioCueCatalog is not configured"]))
	var diagnostics: Array[String] = catalog.validate_ambience_role(role)
	if not diagnostics.is_empty():
		return _record(_ambience_result(false, role, "", false, false, diagnostics))

	if role == CueCatalog.AMBIENCE_NONE:
		if role == _ambience_role:
			return _record(_ambience_result(true, role, "", false, false, []))
		_stop_ambience()
		_ambience_role = role
		return _record(_ambience_result(true, role, "", true, false, []))

	var cue_id: String = catalog.ambience_cue_id(role)
	var resolved: Dictionary = catalog.resolve(cue_id)
	diagnostics = _strings(resolved.get("diagnostics", []))
	var definition = resolved.get("definition", null)
	if not diagnostics.is_empty() or definition == null or not definition is CueDefinition:
		if diagnostics.is_empty():
			diagnostics.append("ambience cue did not resolve to AudioCueDefinition: %s" % cue_id)
		return _record(_ambience_result(false, role, cue_id, false, ambience_is_playing(), diagnostics))
	if definition.playback_space != CueDefinition.PLAYBACK_AMBIENCE:
		return _record(_ambience_result(false, role, cue_id, false, ambience_is_playing(), ["resolved ambience cue is not ambience playback: %s" % cue_id]))

	if role == _ambience_role:
		if not muted and definition.stream != null and not ambience_is_playing():
			_apply_ambience_definition(definition)
		return _record(_ambience_result(true, role, cue_id, false, ambience_is_playing(), []))

	_ambience_role = role
	if muted:
		_stop_ambience()
		return _record(_ambience_result(true, role, cue_id, true, false, ["audio presentation is muted: %s" % cue_id]))
	if definition.stream == null:
		_stop_ambience()
		return _record(_ambience_result(true, role, cue_id, true, false, ["audio cue has no presentation stream: %s" % cue_id]))

	_apply_ambience_definition(definition)
	if not is_inside_tree():
		return _record(_ambience_result(true, role, cue_id, true, false, ["audio controller is not inside SceneTree; playback skipped: %s" % cue_id]))
	return _record(_ambience_result(true, role, cue_id, true, ambience_is_playing(), []))


func ambience_role() -> String:
	return _ambience_role


func ambience_is_playing() -> bool:
	return _ambience_player != null and is_instance_valid(_ambience_player) and _ambience_player.playing


func ambience_player_count() -> int:
	var count := 0
	for child in get_children():
		if child is AudioStreamPlayer and child.name == "AudioAmbience":
			count += 1
	return count


func active_one_shot_count() -> int:
	var count := 0
	for child in get_children():
		if (child is AudioStreamPlayer or child is AudioStreamPlayer3D) and child.name == "AudioOneShot":
			count += 1
	return count


func presentation_state() -> Dictionary:
	return {
		"muted": muted,
		"ambience_role": _ambience_role,
		"ambience_cue_id": catalog.ambience_cue_id(_ambience_role) if catalog != null and catalog is CueCatalog else "",
		"ambience_player_count": ambience_player_count(),
		"ambience_playing": ambience_is_playing(),
		"ambience_stream_configured": _ambience_player != null and is_instance_valid(_ambience_player) and _ambience_player.stream != null,
		"one_shot_player_count": active_one_shot_count(),
	}


func _resume_selected_ambience() -> void:
	if catalog == null or not catalog is CueCatalog or _ambience_role == CueCatalog.AMBIENCE_NONE:
		return
	var cue_id: String = catalog.ambience_cue_id(_ambience_role)
	var resolved: Dictionary = catalog.resolve(cue_id)
	if not resolved.get("diagnostics", []).is_empty():
		return
	var definition = resolved.get("definition", null)
	if definition == null or not definition is CueDefinition:
		return
	if definition.playback_space != CueDefinition.PLAYBACK_AMBIENCE or definition.stream == null:
		return
	_apply_ambience_definition(definition)


func _apply_ambience_definition(definition) -> void:
	var player := _ensure_ambience_player()
	player.stop()
	player.stream = definition.stream
	player.volume_db = definition.volume_db
	if is_inside_tree():
		player.play()


func _ensure_ambience_player() -> AudioStreamPlayer:
	if _ambience_player != null and is_instance_valid(_ambience_player):
		return _ambience_player
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "AudioAmbience"
	add_child(_ambience_player)
	_ambience_player.finished.connect(Callable(self, "_on_ambience_finished"))
	return _ambience_player


func _stop_ambience() -> void:
	if _ambience_player != null and is_instance_valid(_ambience_player):
		_ambience_player.stop()
		_ambience_player.stream = null


func _on_ambience_finished() -> void:
	if muted or _ambience_role == CueCatalog.AMBIENCE_NONE or not is_inside_tree():
		return
	if _ambience_player != null and is_instance_valid(_ambience_player) and _ambience_player.stream != null:
		_ambience_player.play()


func _on_one_shot_finished(player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.get_parent() == self:
		remove_child(player)
	player.free()


func _clear_players() -> void:
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			remove_child(child)
			child.free()
	_ambience_player = null


static func _validate_payload(definition, payload: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	for raw_key in payload.keys():
		var key := str(raw_key)
		if not REQUEST_KEYS.has(key):
			failures.append("unsupported audio presentation request field: %s" % key)
	if payload.has("intensity"):
		var raw_intensity = payload.get("intensity")
		if typeof(raw_intensity) != TYPE_INT and typeof(raw_intensity) != TYPE_FLOAT:
			failures.append("audio presentation intensity must be numeric")
		else:
			var intensity := float(raw_intensity)
			if not is_finite(intensity) or intensity < 0.0 or intensity > 1.0:
				failures.append("audio presentation intensity must be finite in [0, 1]")
	if definition.playback_space == CueDefinition.PLAYBACK_SPATIAL:
		if not payload.has("position") or not payload.get("position") is Vector3:
			failures.append("spatial audio cue requires Vector3 position: %s" % definition.cue_id)
		else:
			var position: Vector3 = payload.get("position")
			if not is_finite(position.x) or not is_finite(position.y) or not is_finite(position.z):
				failures.append("spatial audio position must be finite: %s" % definition.cue_id)
	elif payload.has("position"):
		failures.append("audio position is only valid for spatial cue: %s" % definition.cue_id)
	failures.sort()
	return failures


static func _request_descriptor(definition, payload: Dictionary) -> Dictionary:
	var result := {
		"cue_id": definition.cue_id,
		"playback_space": definition.playback_space,
		"intensity": float(payload.get("intensity", 1.0)),
	}
	if definition.playback_space == CueDefinition.PLAYBACK_SPATIAL:
		var position: Vector3 = payload.get("position", Vector3.ZERO)
		result["position"] = [position.x, position.y, position.z]
	return result


static func _dispatch_result(success: bool, cue_id: String, playback_space: String, played: bool, diagnostics: Array, request: Dictionary) -> Dictionary:
	return {
		"success": success,
		"cue_id": cue_id,
		"playback_space": playback_space,
		"played": played,
		"diagnostics": diagnostics,
		"request": request,
	}


static func _ambience_result(success: bool, role: String, cue_id: String, changed: bool, played: bool, diagnostics: Array) -> Dictionary:
	return {
		"success": success,
		"role": role,
		"cue_id": cue_id,
		"changed": changed,
		"played": played,
		"diagnostics": diagnostics,
	}


func _record(result: Dictionary) -> Dictionary:
	last_diagnostics = _strings(result.get("diagnostics", []))
	last_diagnostics.sort()
	result["diagnostics"] = last_diagnostics.duplicate()
	return result


static func _strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
