extends Resource
class_name UnderworldFacetedHumanoidBodyProfile

## Presentation-only anatomy profile for the skinned faceted survivor. Values
## are metres in the shared humanoid bind space; gameplay never reads them.

const CONTRACT_REVISION := 1
const ROW_COUNT := 56

@export var profile_id: String = ""
@export var revision: int = CONTRACT_REVISION
@export var height: float = 1.80
# Preserve the accepted broad-neutral width controls while converging the
# vertical silhouette on the locked turnaround: roughly 7.2 heads tall,
# longer legs, a more compact torso, and less mannequin-like limb/head mass.
@export var shoulder_width: float = 0.62
@export var chest_width: float = 0.515
@export var chest_depth: float = 0.31
@export var waist_width: float = 0.385
@export var pelvis_width: float = 0.45
@export var thigh_diameter: float = 0.225
@export var calf_diameter: float = 0.18
@export var ankle_width: float = 0.105
@export var foot_length: float = 0.285
@export var foot_width: float = 0.125
@export var head_width: float = 0.218
@export var head_depth: float = 0.232
@export var head_height: float = 0.255
@export var torso_length: float = 0.665
@export var leg_length: float = 0.880
@export var arm_length: float = 0.705
@export var arm_mass: float = 1.06
@export var outfit_shell_offset: float = 0.020


func configure(id_value: String, values: Dictionary = {}) -> Resource:
	profile_id = id_value
	for key_value in values.keys():
		var key := str(key_value)
		if key in [
			"height", "shoulder_width", "chest_width", "chest_depth",
			"waist_width", "pelvis_width", "thigh_diameter", "calf_diameter",
			"ankle_width", "foot_length", "foot_width", "head_width",
			"head_depth", "head_height", "torso_length", "leg_length",
			"arm_length", "arm_mass", "outfit_shell_offset",
		]:
			set(key, float(values[key_value]))
	return self


func validate() -> Array[String]:
	var failures: Array[String] = []
	if profile_id.is_empty() or profile_id != profile_id.strip_edges():
		failures.append("faceted body profile_id must be non-empty and trimmed")
	if revision <= 0:
		failures.append("faceted body revision must be positive")
	for field_name in _dimension_fields():
		var value: float = float(get(field_name))
		if not is_finite(value) or value <= 0.0:
			failures.append("faceted body %s must be finite and positive" % field_name)
	if height < 1.2 or height > 2.4:
		failures.append("faceted body height must stay within presentation limits")
	if shoulder_width <= chest_width:
		failures.append("faceted body shoulders must be wider than chest")
	if chest_width <= waist_width:
		failures.append("faceted body chest must be wider than waist")
	if pelvis_width < waist_width * 0.90 or pelvis_width > shoulder_width:
		failures.append("faceted body pelvis must remain between waist and shoulder proportions")
	if thigh_diameter <= calf_diameter or calf_diameter <= ankle_width:
		failures.append("faceted body leg diameters must taper thigh > calf > ankle")
	if foot_width < ankle_width or foot_length <= foot_width:
		failures.append("faceted body foot must be wider than ankle and longer than wide")
	if arm_length < 0.45 or arm_length > 0.90:
		failures.append("faceted body arm_length must stay within presentation limits")
	if leg_length < 0.55 or leg_length > 1.15:
		failures.append("faceted body leg_length must stay within presentation limits")
	if torso_length < 0.45 or torso_length > 0.90:
		failures.append("faceted body torso_length must stay within presentation limits")
	if head_height < 0.20 or head_height > 0.40:
		failures.append("faceted body head_height must stay within presentation limits")
	if outfit_shell_offset > 0.05:
		failures.append("faceted body outfit shell offset must not exceed 0.05 m")
	failures.sort()
	return failures


func derived_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for y in range(ROW_COUNT):
		var normalized := float(y) / float(ROW_COUNT - 1)
		result.append({
			"y": y,
			"height_m": normalized * height,
			"half_width": _sample_half_width(normalized),
			"half_depth": _sample_half_depth(normalized),
			"semantic": _semantic_for_height(normalized),
		})
	return result


func anatomy_landmarks() -> Dictionary:
	# Component lengths determine relative anatomy while height provides the
	# presentation scale. This allows a character editor to change one section
	# without introducing detached hard-coded mesh offsets.
	var authored_total := leg_length + torso_length + head_height
	var scale_factor := height / authored_total
	var leg := leg_length * scale_factor
	var torso := torso_length * scale_factor
	var head := head_height * scale_factor
	var shoulder_y := leg + torso
	return {
		"sole_y": 0.0,
		"foot_top_y": leg * 0.155,
		"ankle_y": leg * 0.105,
		"calf_low_y": leg * 0.22,
		"calf_mass_y": leg * 0.37,
		"knee_y": leg * 0.55,
		"thigh_mass_y": leg * 0.79,
		"hip_y": leg,
		"pelvis_y": leg + torso * 0.15,
		"waist_y": leg + torso * 0.32,
		"lower_chest_y": leg + torso * 0.55,
		"chest_y": leg + torso * 0.78,
		"shoulder_y": shoulder_y,
		"neck_y": shoulder_y + head * 0.06,
		"jaw_y": shoulder_y + head * 0.34,
		"brow_y": shoulder_y + head * 0.71,
		"crown_y": height,
		"arm_length": arm_length * scale_factor,
	}


func canonical_fingerprint() -> String:
	var values: Array[String] = ["faceted-body-v1", profile_id, str(revision)]
	for field_name in _dimension_fields():
		values.append("%s=%.6f" % [field_name, float(get(field_name))])
	var landmarks := anatomy_landmarks()
	var landmark_names: Array[String] = []
	for key_value in landmarks.keys():
		landmark_names.append(str(key_value))
	landmark_names.sort()
	for landmark_name in landmark_names:
		values.append("landmark.%s=%.6f" % [landmark_name, float(landmarks[landmark_name])])
	for row in derived_rows():
		values.append("%d|%.6f|%.6f|%.6f|%s" % [
			int(row["y"]), float(row["height_m"]), float(row["half_width"]),
			float(row["half_depth"]), str(row["semantic"]),
		])
	return "fbody1:sha256:" + "\n".join(values).sha256_text()


func _sample_half_width(t: float) -> float:
	var landmark := anatomy_landmarks()
	var height_m := clampf(t, 0.0, 1.0) * height
	var foot_top := float(landmark["foot_top_y"])
	var calf_mass := float(landmark["calf_mass_y"])
	var knee := float(landmark["knee_y"])
	var hip := float(landmark["hip_y"])
	var waist := float(landmark["waist_y"])
	var shoulder := float(landmark["shoulder_y"])
	if height_m < foot_top:
		return foot_width * 0.5
	if height_m < calf_mass:
		return lerpf(ankle_width * 0.5, calf_diameter * 0.5, inverse_lerp(foot_top, calf_mass, height_m))
	if height_m < knee:
		return lerpf(calf_diameter * 0.5, thigh_diameter * 0.48, inverse_lerp(calf_mass, knee, height_m))
	if height_m < hip:
		return lerpf(thigh_diameter * 0.48, pelvis_width * 0.5, inverse_lerp(knee, hip, height_m))
	if height_m < waist:
		return lerpf(pelvis_width * 0.5, waist_width * 0.5, inverse_lerp(hip, waist, height_m))
	if height_m < shoulder:
		return lerpf(waist_width * 0.5, shoulder_width * 0.5, inverse_lerp(waist, shoulder, height_m))
	return head_width * 0.5


func _sample_half_depth(t: float) -> float:
	var landmark := anatomy_landmarks()
	var height_m := clampf(t, 0.0, 1.0) * height
	var foot_top := float(landmark["foot_top_y"])
	var hip := float(landmark["hip_y"])
	var shoulder := float(landmark["shoulder_y"])
	if height_m < foot_top:
		return foot_length * 0.5
	if height_m < hip:
		return lerpf(ankle_width * 0.55, thigh_diameter * 0.55, inverse_lerp(foot_top, hip, height_m))
	if height_m < shoulder:
		return chest_depth * 0.5
	return head_depth * 0.5


func _semantic_for_height(t: float) -> String:
	var landmark := anatomy_landmarks()
	var height_m := clampf(t, 0.0, 1.0) * height
	if height_m < float(landmark["foot_top_y"]): return "feet"
	if height_m < float(landmark["hip_y"]): return "legs"
	if height_m < float(landmark["shoulder_y"]): return "torso"
	return "head"


func _dimension_fields() -> Array[String]:
	return [
		"height", "shoulder_width", "chest_width", "chest_depth",
		"waist_width", "pelvis_width", "thigh_diameter", "calf_diameter",
		"ankle_width", "foot_length", "foot_width", "head_width",
		"head_depth", "head_height", "torso_length", "leg_length",
		"arm_length", "arm_mass", "outfit_shell_offset",
	]
