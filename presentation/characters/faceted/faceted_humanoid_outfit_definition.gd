extends Resource
class_name UnderworldFacetedHumanoidOutfitDefinition

## Presentation-only shell and coverage contract for a faceted humanoid. The
## compiler uses semantic zones instead of gameplay hitboxes or voxel cells.

const CONTRACT_REVISION := 1
const KNOWN_COVERAGE_ZONES: Array[StringName] = [
	&"torso", &"upper_arm_l", &"upper_arm_r", &"thigh_l", &"thigh_r",
	&"calf_l", &"calf_r", &"foot_l", &"foot_r",
]

@export var outfit_id: String = ""
@export var revision: int = CONTRACT_REVISION
@export var coverage_zones: Array[StringName] = []
@export var shell_offsets: Dictionary = {}


func configure(id_value: String, zones: Array[StringName], offsets: Dictionary = {}) -> Resource:
	outfit_id = id_value
	coverage_zones = zones.duplicate()
	shell_offsets = offsets.duplicate(true)
	return self


func validate() -> Array[String]:
	var failures: Array[String] = []
	if outfit_id.is_empty() or outfit_id != outfit_id.strip_edges():
		failures.append("faceted outfit_id must be non-empty and trimmed")
	if revision <= 0:
		failures.append("faceted outfit revision must be positive")
	var seen: Dictionary = {}
	for zone in coverage_zones:
		if not zone in KNOWN_COVERAGE_ZONES:
			failures.append("faceted outfit has unknown coverage zone: %s" % zone)
		elif seen.has(zone):
			failures.append("faceted outfit has duplicate coverage zone: %s" % zone)
		seen[zone] = true
	for key_value in shell_offsets.keys():
		var zone := StringName(str(key_value))
		var offset: float = float(shell_offsets[key_value])
		if not zone in KNOWN_COVERAGE_ZONES:
			failures.append("faceted outfit has unknown shell zone: %s" % zone)
		if not is_finite(offset) or offset < 0.001 or offset > 0.05:
			failures.append("faceted outfit shell offset for %s must be finite in [0.001,0.05]" % zone)
	for required_zone in KNOWN_COVERAGE_ZONES:
		if not coverage_zones.has(required_zone):
			failures.append("faceted outfit baseline must cover zone: %s" % required_zone)
	failures.sort()
	return failures


func shell_offset(zone: StringName, fallback: float) -> float:
	return float(shell_offsets.get(zone, fallback))


func canonical_fingerprint() -> String:
	var zones: Array[String] = []
	for zone in coverage_zones:
		zones.append(str(zone))
	zones.sort()
	var offsets: Array[String] = []
	for key_value in shell_offsets.keys():
		offsets.append("%s=%.6f" % [str(key_value), float(shell_offsets[key_value])])
	offsets.sort()
	return "foutfit1:sha256:" + "\n".join([
		"faceted-outfit-v1", outfit_id, str(revision), ";".join(zones), ";".join(offsets),
	]).sha256_text()
