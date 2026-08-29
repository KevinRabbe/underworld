extends RefCounted

const CueDefinition := preload("res://presentation/audio/audio_cue_definition.gd")
const CueCatalog := preload("res://presentation/audio/audio_cue_catalog.gd")
const AudioController := preload("res://presentation/audio/audio_presentation_controller.gd")

const CATALOG_PATH := "res://content/presentation/audio/prototype_audio_cue_catalog.tres"
const PRODUCTION_PATHS: Array[String] = [
	"res://presentation/audio/audio_cue_definition.gd",
	"res://presentation/audio/audio_cue_catalog.gd",
	"res://presentation/audio/audio_presentation_controller.gd",
]


static func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog = ResourceLoader.load(CATALOG_PATH)
	if catalog == null or not catalog is CueCatalog:
		failures.append("prototype audio cue catalog did not load as AudioCueCatalog")
		return failures
	for failure in catalog.validate_catalog():
		failures.append("catalog validation: %s" % failure)
	if not failures.is_empty():
		return failures

	_test_complete_exact_vocabulary(catalog, failures)
	_test_unknown_cue_is_fail_closed(catalog, failures)
	_test_valid_global_dispatch_without_gameplay_owner(catalog, failures)
	_test_spatial_request_is_value_only(catalog, failures)
	_test_muted_and_no_stream_are_safe(catalog, failures)
	_test_ambience_transitions_reuse_one_player(catalog, failures)
	_test_asset_replacement_preserves_semantic_identity(catalog, failures)
	_test_catalog_rejects_duplicate_or_missing_entries(catalog, failures)
	_test_presentation_scope_has_no_gameplay_authority_imports(failures)
	return failures


static func _test_complete_exact_vocabulary(catalog, failures: Array[String]) -> void:
	var registered: Array[String] = catalog.registered_cue_ids()
	var supported: Array[String] = CueCatalog.supported_cue_ids()
	if registered != supported:
		failures.append("prototype audio cue catalog does not exactly match the controlled M3 cue vocabulary")
	for cue_id in supported:
		var resolved: Dictionary = catalog.resolve(cue_id)
		if not resolved.get("diagnostics", []).is_empty() or resolved.get("definition", null) == null:
			failures.append("registered audio cue did not resolve: %s" % cue_id)
	var prefix_only: Dictionary = catalog.resolve("audio_cue.player.attack")
	if prefix_only.get("diagnostics", []).is_empty():
		failures.append("audio cue hierarchy was inferred from dotted prefix instead of exact vocabulary membership")


static func _test_unknown_cue_is_fail_closed(catalog, failures: Array[String]) -> void:
	var controller = AudioController.new()
	var configure_failures: Array[String] = controller.configure(catalog)
	if not configure_failures.is_empty():
		failures.append("audio controller rejected valid catalog: %s" % [configure_failures])
		controller.free()
		return
	var before: Dictionary = controller.presentation_state()
	var result: Dictionary = controller.dispatch("audio_cue.player.attack.combo_99")
	if bool(result.get("success", true)):
		failures.append("unknown audio cue unexpectedly succeeded")
	if not _has_fragment(result.get("diagnostics", []), "unknown audio cue id"):
		failures.append("unknown audio cue did not return deterministic vocabulary diagnostic")
	if controller.presentation_state() != before:
		failures.append("unknown audio cue mutated presentation playback state")
	controller.free()


static func _test_valid_global_dispatch_without_gameplay_owner(catalog, failures: Array[String]) -> void:
	var clone = _clone_catalog(catalog)
	_set_stream(clone, "audio_cue.player.attack.light", AudioStreamGenerator.new(), failures)
	var controller = AudioController.new()
	var configure_failures: Array[String] = controller.configure(clone)
	if not configure_failures.is_empty():
		failures.append("global dispatch clone did not configure: %s" % [configure_failures])
		controller.free()
		return
	var result: Dictionary = controller.dispatch("audio_cue.player.attack.light", {"intensity": 0.75})
	if not bool(result.get("success", false)):
		failures.append("valid global cue could not be dispatched without gameplay Node owner")
	if bool(result.get("played", true)):
		failures.append("off-tree global cue claimed physical playback")
	if not _has_fragment(result.get("diagnostics", []), "not inside SceneTree"):
		failures.append("off-tree global cue did not report deterministic presentation-only skip")
	if controller.active_one_shot_count() != 0:
		failures.append("off-tree global dispatch leaked an unplayed one-shot node")
	var request: Dictionary = result.get("request", {})
	if request.get("cue_id", "") != "audio_cue.player.attack.light":
		failures.append("global dispatch request lost semantic cue identity")
	controller.free()


static func _test_spatial_request_is_value_only(catalog, failures: Array[String]) -> void:
	var clone = _clone_catalog(catalog)
	_set_stream(clone, "audio_cue.resource.mine.impact", AudioStreamGenerator.new(), failures)
	var controller = AudioController.new()
	var configure_failures: Array[String] = controller.configure(clone)
	if not configure_failures.is_empty():
		failures.append("spatial dispatch clone did not configure: %s" % [configure_failures])
		controller.free()
		return
	var result: Dictionary = controller.dispatch(
		"audio_cue.resource.mine.impact",
		{"position": Vector3(3.0, -2.0, 8.5), "intensity": 0.5}
	)
	if not bool(result.get("success", false)):
		failures.append("valid spatial cue request was rejected: %s" % [result.get("diagnostics", [])])
	var request: Dictionary = result.get("request", {})
	if request.get("position", []) != [3.0, -2.0, 8.5]:
		failures.append("spatial audio request did not preserve value position")
	if not _value_tree_is_serialization_safe(request):
		failures.append("spatial audio request retained Node/Object/runtime identity")
	for forbidden_key in ["node_id", "instance_id", "node_path", "stable_id", "stable_address"]:
		if request.has(forbidden_key):
			failures.append("spatial audio request exposed forbidden identity key: %s" % forbidden_key)
	var missing_position: Dictionary = controller.dispatch("audio_cue.resource.mine.impact")
	if bool(missing_position.get("success", true)):
		failures.append("spatial audio cue accepted a missing world position")
	controller.free()


static func _test_muted_and_no_stream_are_safe(catalog, failures: Array[String]) -> void:
	var no_stream_controller = AudioController.new()
	var no_stream_failures: Array[String] = no_stream_controller.configure(catalog)
	if not no_stream_failures.is_empty():
		failures.append("no-stream controller setup failed: %s" % [no_stream_failures])
	else:
		var no_stream: Dictionary = no_stream_controller.dispatch("audio_cue.player.attack.heavy")
		if not bool(no_stream.get("success", false)) or bool(no_stream.get("played", true)):
			failures.append("valid no-stream cue was not a safe presentation no-op")
		if not _has_fragment(no_stream.get("diagnostics", []), "no presentation stream"):
			failures.append("no-stream cue omitted deterministic presentation diagnostic")
	no_stream_controller.free()

	var clone = _clone_catalog(catalog)
	_set_stream(clone, "audio_cue.player.attack.heavy", AudioStreamGenerator.new(), failures)
	var muted_controller = AudioController.new()
	var muted_failures: Array[String] = muted_controller.configure(clone, true)
	if not muted_failures.is_empty():
		failures.append("muted controller setup failed: %s" % [muted_failures])
	else:
		var muted_result: Dictionary = muted_controller.dispatch("audio_cue.player.attack.heavy")
		if not bool(muted_result.get("success", false)) or bool(muted_result.get("played", true)):
			failures.append("muted audio dispatch was not a safe no-op")
		if not _has_fragment(muted_result.get("diagnostics", []), "is muted"):
			failures.append("muted audio dispatch omitted deterministic diagnostic")
		if muted_controller.active_one_shot_count() != 0:
			failures.append("muted audio dispatch created a one-shot player")
	muted_controller.free()


static func _test_ambience_transitions_reuse_one_player(catalog, failures: Array[String]) -> void:
	var clone = _clone_catalog(catalog)
	_set_stream(clone, "audio_cue.ambience.surface", AudioStreamGenerator.new(), failures)
	_set_stream(clone, "audio_cue.ambience.cave", AudioStreamGenerator.new(), failures)
	var controller = AudioController.new()
	var configure_failures: Array[String] = controller.configure(clone)
	if not configure_failures.is_empty():
		failures.append("ambience controller setup failed: %s" % [configure_failures])
		controller.free()
		return

	var surface: Dictionary = controller.set_ambience_role(CueCatalog.AMBIENCE_SURFACE)
	if not bool(surface.get("success", false)) or not bool(surface.get("changed", false)):
		failures.append("surface ambience transition failed")
	if controller.ambience_player_count() != 1:
		failures.append("surface ambience did not create exactly one reusable player")
	var repeated: Dictionary = controller.set_ambience_role(CueCatalog.AMBIENCE_SURFACE)
	if not bool(repeated.get("success", false)) or bool(repeated.get("changed", true)):
		failures.append("repeated surface ambience transition was not idempotent")
	if controller.ambience_player_count() != 1:
		failures.append("repeated ambience role created duplicate players")
	var cave: Dictionary = controller.set_ambience_role(CueCatalog.AMBIENCE_CAVE)
	if not bool(cave.get("success", false)) or not bool(cave.get("changed", false)):
		failures.append("cave ambience transition failed")
	if controller.ambience_player_count() != 1:
		failures.append("surface-to-cave ambience transition did not reuse the same player")
	if controller.ambience_role() != CueCatalog.AMBIENCE_CAVE:
		failures.append("ambience controller did not retain semantic cave role")
	var none: Dictionary = controller.set_ambience_role(CueCatalog.AMBIENCE_NONE)
	if not bool(none.get("success", false)) or controller.ambience_role() != CueCatalog.AMBIENCE_NONE:
		failures.append("ambience none transition failed")
	if controller.ambience_player_count() != 1:
		failures.append("stopping ambience changed reusable-player cardinality")
	controller.free()


static func _test_asset_replacement_preserves_semantic_identity(catalog, failures: Array[String]) -> void:
	var first = _clone_catalog(catalog)
	var second = _clone_catalog(catalog)
	var first_stream := AudioStreamGenerator.new()
	first_stream.mix_rate = 22050.0
	var second_stream := AudioStreamGenerator.new()
	second_stream.mix_rate = 44100.0
	_set_stream(first, "audio_cue.inventory.pickup", first_stream, failures)
	_set_stream(second, "audio_cue.inventory.pickup", second_stream, failures)
	var first_definition = first.cue_by_id("audio_cue.inventory.pickup")
	var second_definition = second.cue_by_id("audio_cue.inventory.pickup")
	if first_definition == null or second_definition == null:
		failures.append("asset replacement proof could not resolve pickup cue")
		return
	if first_definition.stream == second_definition.stream:
		failures.append("asset replacement proof did not use distinct presentation assets")
	if first_definition.cue_id != second_definition.cue_id:
		failures.append("replacing presentation asset changed semantic cue id")
	if first.canonical_descriptor() != second.canonical_descriptor():
		failures.append("semantic audio catalog descriptor depends on replaceable stream asset identity")


static func _test_catalog_rejects_duplicate_or_missing_entries(catalog, failures: Array[String]) -> void:
	var duplicate = _clone_catalog(catalog)
	var first = duplicate.cues[0]
	duplicate.cues.append(CueDefinition.new().configure(
		first.cue_id,
		first.playback_space,
		first.stream,
		first.looping,
		first.volume_db
	))
	if not _has_fragment(duplicate.validate_catalog(), "duplicate audio cue id"):
		failures.append("audio cue catalog accepted duplicate semantic cue id")

	var missing = _clone_catalog(catalog)
	missing.cues.remove_at(0)
	if not _has_fragment(missing.validate_catalog(), "missing required M3 cue"):
		failures.append("audio cue catalog accepted incomplete controlled vocabulary")


static func _test_presentation_scope_has_no_gameplay_authority_imports(failures: Array[String]) -> void:
	var forbidden_fragments: Array[String] = [
		"res://app/",
		"res://gameplay/",
		"res://world/",
		"res://worldgen/",
		"get_instance_id(",
	]
	for path in PRODUCTION_PATHS:
		var source: String = FileAccess.get_file_as_string(path)
		if source.is_empty():
			failures.append("audio presentation source could not be read for scope audit: %s" % path)
			continue
		for fragment in forbidden_fragments:
			if source.contains(fragment):
				failures.append("audio presentation source crossed gameplay/runtime authority boundary: %s -> %s" % [path, fragment])


static func _clone_catalog(source):
	var clone = CueCatalog.new()
	for candidate in source.cues:
		if candidate == null or not candidate is CueDefinition:
			continue
		clone.cues.append(CueDefinition.new().configure(
			candidate.cue_id,
			candidate.playback_space,
			candidate.stream,
			candidate.looping,
			candidate.volume_db
		))
	return clone


static func _set_stream(catalog, cue_id: String, stream: AudioStream, failures: Array[String]) -> void:
	var definition = catalog.cue_by_id(cue_id)
	if definition == null:
		failures.append("test could not resolve audio cue for stream replacement: %s" % cue_id)
		return
	definition.stream = stream


static func _has_fragment(values: Array, fragment: String) -> bool:
	for value in values:
		if str(value).contains(fragment):
			return true
	return false


static func _value_tree_is_serialization_safe(value) -> bool:
	var value_type: int = typeof(value)
	if value_type == TYPE_OBJECT or value_type == TYPE_RID or value_type == TYPE_CALLABLE or value_type == TYPE_SIGNAL:
		return false
	if value_type == TYPE_DICTIONARY:
		for key in value.keys():
			if not _value_tree_is_serialization_safe(key) or not _value_tree_is_serialization_safe(value[key]):
				return false
	elif value_type == TYPE_ARRAY:
		for entry in value:
			if not _value_tree_is_serialization_safe(entry):
				return false
	return true
