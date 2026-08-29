extends RefCounted
class_name UndergroundPlacementService

const Candidate := preload("res://content/placement/underground_placement_candidate.gd")
const Policy := preload("res://content/placement/underground_placement_policy.gd")
const PlacementRecord := preload("res://content/placement/underground_placement_record.gd")
const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")

const CONTRACT_REVISION: int = 1


static func plan(
	candidates: Array,
	policies: Array,
	registry,
	rulebook_revision: int = 1
) -> Dictionary:
	var failures: Array[String] = []
	if rulebook_revision <= 0:
		failures.append("underground placement rulebook_revision must be positive")
	if registry == null or not registry is ContentRegistry:
		failures.append("underground placement requires an accepted ContentRegistry")
	elif not registry.is_valid():
		for diagnostic in registry.diagnostics():
			failures.append("content registry: %s" % diagnostic)

	var normalized_candidates: Array = []
	var candidate_ids: Dictionary = {}
	for candidate in candidates:
		if candidate == null or not candidate is Candidate:
			failures.append("underground placement received a non-candidate value")
			continue
		for failure in candidate.validate_candidate():
			failures.append("candidate %s: %s" % [_candidate_label(candidate), failure])
		if candidate_ids.has(candidate.stable_id):
			failures.append("duplicate underground placement candidate StableId: %s" % candidate.stable_id)
		else:
			candidate_ids[candidate.stable_id] = true
		normalized_candidates.append(candidate)
	normalized_candidates.sort_custom(_candidate_less)

	var normalized_policies: Array = []
	var policy_ids: Dictionary = {}
	for policy in policies:
		if policy == null or not policy is Policy:
			failures.append("underground placement received a non-policy value")
			continue
		for failure in policy.validate_policy():
			failures.append("policy %s: %s" % [_policy_label(policy), failure])
		if policy_ids.has(policy.policy_id):
			failures.append("duplicate underground placement policy_id: %s" % policy.policy_id)
		else:
			policy_ids[policy.policy_id] = true
		normalized_policies.append(policy)
	normalized_policies.sort_custom(_policy_less)

	var target_definitions: Dictionary = {}
	if registry != null and registry is ContentRegistry and registry.is_valid():
		for policy in normalized_policies:
			if policy.target_reference == null:
				continue
			var resolved: Dictionary = registry.resolve_reference(policy.target_reference)
			var diagnostics: Array = resolved.get("diagnostics", [])
			if not diagnostics.is_empty():
				for diagnostic in diagnostics:
					failures.append("policy %s target: %s" % [_policy_label(policy), diagnostic])
				continue
			var definition = resolved.get("definition", null)
			if definition == null:
				failures.append("policy %s target resolved without a definition" % _policy_label(policy))
				continue
			for category_id in policy.required_target_category_ids:
				if not definition.category_ids.has(category_id):
					failures.append(
						"policy %s target %s lacks required category %s" % [
							_policy_label(policy),
							definition.content_id,
							category_id,
						]
					)
			target_definitions[policy.policy_id] = definition

	if not failures.is_empty():
		return _failure(failures, rulebook_revision)

	var placements: Array = []
	for candidate in normalized_candidates:
		var counts_by_policy: Dictionary = {}
		for slot_index in range(candidate.local_capacity):
			var eligible: Array = []
			for policy in normalized_policies:
				if not policy.matches_candidate(candidate):
					continue
				if int(counts_by_policy.get(policy.policy_id, 0)) >= policy.max_per_candidate:
					continue
				eligible.append(policy)
			if eligible.is_empty():
				break

			var selected = _select_policy(candidate, slot_index, eligible, rulebook_revision)
			if selected == null:
				failures.append("deterministic placement selection failed for %s slot %d" % [candidate.stable_id, slot_index])
				break
			var target_definition = target_definitions.get(selected.policy_id, null)
			if target_definition == null:
				failures.append("resolved target disappeared for placement policy %s" % selected.policy_id)
				break
			var placement_stable_id := _placement_stable_id(candidate.stable_id, slot_index)
			if placement_stable_id.is_empty():
				failures.append("failed to derive persistent placement StableId for %s slot %d" % [candidate.stable_id, slot_index])
				break
			var fingerprint := _placement_fingerprint(
				candidate,
				selected,
				target_definition,
				placement_stable_id,
				slot_index,
				rulebook_revision
			)
			if fingerprint.is_empty():
				failures.append("failed to fingerprint placement %s" % placement_stable_id)
				break

			placements.append(PlacementRecord.new(
				placement_stable_id,
				candidate.stable_id,
				slot_index,
				selected.policy_id,
				target_definition.content_id,
				target_definition.definition_family,
				fingerprint
			))
			counts_by_policy[selected.policy_id] = int(counts_by_policy.get(selected.policy_id, 0)) + 1

	if not failures.is_empty():
		return _failure(failures, rulebook_revision)
	placements.sort_custom(_record_less)
	return {
		"success": true,
		"placements": placements,
		"diagnostics": [],
		"rulebook_revision": rulebook_revision,
		"contract_revision": CONTRACT_REVISION,
	}


static func _select_policy(candidate, slot_index: int, eligible: Array, rulebook_revision: int):
	eligible.sort_custom(_policy_less)
	var total_weight := 0
	var manifest: Array[String] = []
	for policy in eligible:
		total_weight += policy.selection_weight
		manifest.append("%s@%d@%s" % [
			policy.policy_id,
			policy.selection_weight,
			CanonicalValue.fingerprint(policy.canonical_descriptor()),
		])
	if total_weight <= 0:
		return null
	var selection_payload := {
		"contract_revision": CONTRACT_REVISION,
		"rulebook_revision": rulebook_revision,
		"candidate": candidate.canonical_data(),
		"slot_index": slot_index,
		"eligible_policy_manifest": manifest,
	}
	var encoded: String = CanonicalValue.encode(selection_payload)
	if encoded.is_empty():
		return null
	var roll := _hex_prefix_value(encoded.sha256_text(), 8) % total_weight
	var cursor := 0
	for policy in eligible:
		cursor += policy.selection_weight
		if roll < cursor:
			return policy
	return eligible[eligible.size() - 1]


static func _placement_stable_id(candidate_stable_id: String, slot_index: int) -> String:
	var candidate_id = StableId.parse(candidate_stable_id)
	if candidate_id == null or slot_index < 0:
		return ""
	var placement_address = candidate_id.address().child(["placement", "slot", str(slot_index)])
	if placement_address == null:
		return ""
	var placement_id = StableId.from_address(placement_address)
	return "" if placement_id == null else placement_id.value()


static func _placement_fingerprint(
	candidate,
	policy,
	target_definition,
	placement_stable_id: String,
	slot_index: int,
	rulebook_revision: int
) -> String:
	var payload := {
		"contract_revision": CONTRACT_REVISION,
		"rulebook_revision": rulebook_revision,
		"placement_stable_id": placement_stable_id,
		"slot_index": slot_index,
		"candidate": candidate.canonical_data(),
		"policy": policy.canonical_descriptor(),
		"target_definition": target_definition.canonical_descriptor(),
	}
	var encoded: String = CanonicalValue.encode(payload)
	if encoded.is_empty():
		return ""
	return "upf1:" + encoded.sha256_text()


static func _failure(failures: Array[String], rulebook_revision: int) -> Dictionary:
	failures.sort()
	return {
		"success": false,
		"placements": [],
		"diagnostics": failures,
		"rulebook_revision": rulebook_revision,
		"contract_revision": CONTRACT_REVISION,
	}


static func _candidate_less(a, b) -> bool:
	return str(a.stable_id) < str(b.stable_id)


static func _policy_less(a, b) -> bool:
	return str(a.policy_id) < str(b.policy_id)


static func _record_less(a, b) -> bool:
	return str(a.placement_stable_id) < str(b.placement_stable_id)


static func _candidate_label(candidate) -> String:
	return candidate.stable_id if not str(candidate.stable_id).is_empty() else "<unidentified-candidate>"


static func _policy_label(policy) -> String:
	return policy.policy_id if not str(policy.policy_id).is_empty() else "<unidentified-policy>"


static func _hex_prefix_value(value: String, digits: int) -> int:
	var result := 0
	var count := mini(digits, value.length())
	for index in range(count):
		var codepoint := value.unicode_at(index)
		var digit := 0
		if codepoint >= 48 and codepoint <= 57:
			digit = codepoint - 48
		elif codepoint >= 97 and codepoint <= 102:
			digit = codepoint - 87
		else:
			continue
		result = result * 16 + digit
	return result
