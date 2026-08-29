extends RefCounted
class_name UnderworldCavePresentationRealizer

const ProfileScript := preload("res://presentation/world/caves/cave_presentation_profile.gd")
const ATTACHMENT_NAME := "CavePresentationAttachment"


static func build_material(profile) -> Dictionary:
	if profile == null or not profile is ProfileScript:
		return {"material": null, "diagnostics": ["CavePresentationProfile is required"]}
	var failures: Array[String] = profile.validate_profile()
	if not failures.is_empty():
		return {"material": null, "diagnostics": failures}
	var material := StandardMaterial3D.new()
	material.albedo_color = profile.albedo_color
	material.roughness = profile.roughness
	material.metallic = profile.metallic
	# MAP-016 deliberately emits an interior-facing shell. Presentation owns
	# exterior/backside readability, so culling is disabled here rather than by
	# duplicating/reversing deterministic geometry.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if profile.emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = profile.emission_color
		material.emission_energy_multiplier = profile.emission_energy
	material.set_meta("presentation_profile_id", profile.profile_id)
	material.set_meta("presentation_only", true)
	return {"material": material, "diagnostics": []}


static func realize(mesh_node, profile, context: Dictionary = {}) -> Dictionary:
	if mesh_node == null or not mesh_node is MeshInstance3D:
		return {"attachment": null, "material": null, "profile_id": "", "diagnostics": ["MeshInstance3D is required"]}
	var material_result: Dictionary = build_material(profile)
	if not material_result.get("diagnostics", []).is_empty():
		return {
			"attachment": null,
			"material": null,
			"profile_id": "",
			"diagnostics": material_result.get("diagnostics", []),
		}
	var material = material_result.get("material")
	mesh_node.material_override = material

	var existing := mesh_node.get_node_or_null(ATTACHMENT_NAME)
	if existing != null:
		mesh_node.remove_child(existing)
		existing.free()

	var attachment := Node3D.new()
	attachment.name = ATTACHMENT_NAME
	attachment.set_meta("presentation_only", true)
	attachment.set_meta("presentation_profile_id", profile.profile_id)
	attachment.set_meta("ambience_id", profile.ambience_id)
	attachment.set_meta("fog_color", profile.fog_color)
	attachment.set_meta("fog_density", profile.fog_density)
	attachment.set_meta("volume_kind", str(context.get("volume_kind", "default")))
	var bounds: AABB = context.get("world_bounds", AABB())
	if bounds.size.length_squared() > 0.0:
		attachment.position = bounds.get_center()
	mesh_node.add_child(attachment)

	if profile.local_light_energy > 0.0:
		var light := OmniLight3D.new()
		light.name = "CaveProfileLight"
		light.light_color = profile.local_light_color
		light.light_energy = profile.local_light_energy
		light.omni_range = profile.local_light_range
		light.shadow_enabled = false
		light.set_meta("presentation_only", true)
		attachment.add_child(light)

	for index in range(profile.dressing_hooks.size()):
		var marker := Marker3D.new()
		marker.name = "DressingHook_%02d" % index
		marker.set_meta("presentation_only", true)
		marker.set_meta("dressing_hook_id", profile.dressing_hooks[index])
		attachment.add_child(marker)

	return {
		"attachment": attachment,
		"material": material,
		"profile_id": profile.profile_id,
		"diagnostics": [],
	}
