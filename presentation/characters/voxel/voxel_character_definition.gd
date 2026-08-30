extends Resource
class_name UnderworldVoxelCharacterDefinition

const REQUIRED_SLOTS: Array[StringName] = [
	&"body_base", &"head_hair", &"torso_outfit", &"leg_outfit", &"hands", &"feet",
]

@export var presentation_id: String = ""
@export var revision: int = 1
@export var rig_profile_id: String = "rig_profile.humanoid.prototype"
@export var voxel_size: float = 0.05
@export var presentation_scale: float = 1.0
@export var presentation_bounds: AABB = AABB(Vector3(-0.45, 0.0, -0.30), Vector3(0.90, 1.80, 0.60))
@export var palette: Resource
@export var modules: Array[Resource] = []
@export var slice_profile: Resource


func validate_definition() -> Array[String]:
	var failures: Array[String] = []
	if presentation_id.is_empty() or presentation_id != presentation_id.strip_edges():
		failures.append("character presentation_id must be non-empty and trimmed")
	if revision <= 0:
		failures.append("character revision must be positive")
	if rig_profile_id.is_empty():
		failures.append("character rig_profile_id must be non-empty")
	if not is_finite(voxel_size) or voxel_size <= 0.0:
		failures.append("character voxel_size must be finite and positive")
	if not is_finite(presentation_scale) or presentation_scale <= 0.0:
		failures.append("character presentation_scale must be finite and positive")
	if not presentation_bounds.position.is_finite() or not presentation_bounds.size.is_finite() or presentation_bounds.size.x <= 0.0 or presentation_bounds.size.y <= 0.0 or presentation_bounds.size.z <= 0.0:
		failures.append("character presentation_bounds must be finite with positive size")
	if palette == null or not palette.has_method("validate_definition"):
		failures.append("character requires voxel palette definition")
		return failures
	for failure in palette.validate_definition():
		failures.append("palette: %s" % failure)
	if slice_profile != null and not slice_profile.has_method("validate"):
		failures.append("character slice_profile is incompatible")
	elif slice_profile != null:
		for failure in slice_profile.validate(palette.entries.size()):
			failures.append("slice profile: %s" % failure)
	var slots: Dictionary = {}
	for module in modules:
		if module == null or not module.has_method("validate_definition"):
			failures.append("character contains incompatible module")
			continue
		var slot: StringName = module.slot_id
		if slots.has(slot):
			failures.append("character contains duplicate module slot: %s" % slot)
		slots[slot] = true
		for failure in module.validate_definition(palette.entries.size()):
			failures.append("module %s: %s" % [module.presentation_id, failure])
	for slot in REQUIRED_SLOTS:
		if not slots.has(slot):
			failures.append("character missing required module slot: %s" % slot)
	failures.sort()
	return failures


func canonical_fingerprint() -> String:
	var module_fingerprints: Array[String] = []
	for module in modules:
		if module != null and module.has_method("canonical_fingerprint"):
			module_fingerprints.append(module.canonical_fingerprint())
	module_fingerprints.sort()
	var descriptor := "\n".join([
		"voxel-character-v1", presentation_id, str(revision), rig_profile_id,
		"%.6f" % voxel_size, "%.6f" % presentation_scale,
		"%.6f,%.6f,%.6f|%.6f,%.6f,%.6f" % [presentation_bounds.position.x, presentation_bounds.position.y, presentation_bounds.position.z, presentation_bounds.size.x, presentation_bounds.size.y, presentation_bounds.size.z],
		palette.canonical_fingerprint() if palette != null else "<missing-palette>",
		slice_profile.canonical_fingerprint() if slice_profile != null else "<no-slice-profile>",
		";".join(module_fingerprints),
	])
	return "vcharacter1:sha256:" + descriptor.sha256_text()


func module_for_slot(slot: StringName):
	for module in modules:
		if module != null and module.slot_id == slot:
			return module
	return null
