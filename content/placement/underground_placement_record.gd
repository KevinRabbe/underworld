extends RefCounted
class_name UndergroundPlacementRecord

var placement_stable_id: String = ""
var candidate_stable_id: String = ""
var slot_index: int = -1
var policy_id: String = ""
var target_content_id: String = ""
var target_family: String = ""
var placement_fingerprint: String = ""


func _init(
	p_placement_stable_id: String = "",
	p_candidate_stable_id: String = "",
	p_slot_index: int = -1,
	p_policy_id: String = "",
	p_target_content_id: String = "",
	p_target_family: String = "",
	p_placement_fingerprint: String = ""
) -> void:
	placement_stable_id = p_placement_stable_id
	candidate_stable_id = p_candidate_stable_id
	slot_index = p_slot_index
	policy_id = p_policy_id
	target_content_id = p_target_content_id
	target_family = p_target_family
	placement_fingerprint = p_placement_fingerprint


func canonical_data() -> Dictionary:
	return {
		"placement_stable_id": placement_stable_id,
		"candidate_stable_id": candidate_stable_id,
		"slot_index": slot_index,
		"policy_id": policy_id,
		"target_content_id": target_content_id,
		"target_family": target_family,
		"placement_fingerprint": placement_fingerprint,
	}
