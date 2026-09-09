extends RefCounted

const PRESENTATION_ARCHETYPE_ROLE := "presentation.archetype"


func realize(
	placement,
	definition,
	content_registry,
	validation_result: Dictionary,
	archetype_realizer
) -> Dictionary:
	var archetype_id: String = ""
	for reference in definition.validation_references():
		if reference != null and str(reference.role) == PRESENTATION_ARCHETYPE_ROLE:
			var reference_result: Dictionary = content_registry.resolve_reference(reference)
			if not reference_result.get("diagnostics", []).is_empty():
				return _failure(reference_result.get("diagnostics", []))
			archetype_id = str(reference.target_id)
			break
	if archetype_id.is_empty():
		return _failure([
			"resource is missing required presentation.archetype reference: %s" % definition.content_id,
		])
	if archetype_realizer == null or not archetype_realizer.has_method("realize"):
		return _failure(["resource realization requires ArchetypeRealizer-compatible service"])
	var realized: Dictionary = archetype_realizer.realize(
		content_registry,
		validation_result,
		archetype_id
	)
	if not bool(realized.get("success", false)):
		return realized
	var instance = realized.get("instance", null)
	if instance == null or not instance is Node:
		return _failure(["resource archetype realization returned no Node instance"])
	instance.set_meta("placement_stable_id", placement.placement_stable_id)
	instance.set_meta("placement_fingerprint", placement.placement_fingerprint)
	instance.set_meta("resource_content_id", placement.target_content_id)
	realized["placement_stable_id"] = placement.placement_stable_id
	realized["resource_content_id"] = placement.target_content_id
	return realized


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {"success": false, "diagnostics": diagnostics, "events": []}
