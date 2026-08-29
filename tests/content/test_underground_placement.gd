extends RefCounted

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const ReservedSiteAssignment := preload("res://content/reserved_sites/reserved_site_assignment.gd")
const Candidate := preload("res://content/placement/underground_placement_candidate.gd")
const Policy := preload("res://content/placement/underground_placement_policy.gd")
const Service := preload("res://content/placement/underground_placement_service.gd")
const CreatureDefinition := preload("res://gameplay/creatures/definitions/creature_definition.gd")
const ResourceDefinition := preload("res://gameplay/resources/definitions/resource_definition.gd")
const ResourceYieldRule := preload("res://gameplay/resources/definitions/resource_yield_rule.gd")

const CATEGORY_SITE_ENCOUNTER := "category.structure.underworld.encounter"
const CATEGORY_SITE_RESOURCE := "category.structure.underworld.resource"
const CATEGORY_SITE_UNUSED := "category.structure.underworld.unused"
const CATEGORY_CREATURE_ENEMY := "category.creature.enemy"
const CATEGORY_RESOURCE_DEPOSIT := "category.resource.deposit"
const TRAIT_PRIMARY := "trait.network.primary"
const TRAIT_DEEP := "trait.network.deep"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_reserved_site_adapter_is_pure(failures)
	_test_order_and_request_independence(failures)
	_test_slot_identity_is_stable_across_rulebook_revision(failures)
	_test_eligibility_capacity_and_empty_result(failures)
	_test_invalid_candidates_and_targets_fail_closed(failures)
	_test_records_do_not_own_world_delta_state(failures)
	return failures


static func _test_reserved_site_adapter_is_pure(failures: Array[String]) -> void:
	var assignment = _assignment(2, [CATEGORY_SITE_ENCOUNTER])
	var before: Dictionary = assignment.canonical_data()
	var candidate = Candidate.from_reserved_site_assignment(
		assignment,
		Vector2i(-3, 4),
		3,
		[TRAIT_PRIMARY],
		2
	)
	_expect_true(failures, "reserved-site assignment adapts to a placement candidate", candidate != null)
	if candidate == null:
		return
	_expect_equal(failures, "reserved-site adapter preserves procedural StableId", candidate.stable_id, assignment.site_stable_id)
	_expect_equal(failures, "reserved-site adapter consumes inherited category_ids", candidate.category_ids, assignment.category_ids)
	_expect_equal(failures, "negative region coordinates remain valid candidate metadata", candidate.region_coord, Vector2i(-3, 4))
	_expect_equal(failures, "reserved-site adapter does not mutate CONTENT-001 overlay", assignment.canonical_data(), before)
	_expect_true(failures, "adapted candidate validates", candidate.validate_candidate().is_empty())


static func _test_order_and_request_independence(failures: Array[String]) -> void:
	var registry = _registry()
	_expect_true(failures, "placement proof registry is valid", registry.is_valid())
	if not registry.is_valid():
		return
	var encounter = _candidate(3, CATEGORY_SITE_ENCOUNTER, Vector2i(-3, 4), 3, [TRAIT_PRIMARY], 2)
	var resource = _candidate(4, CATEGORY_SITE_RESOURCE, Vector2i(-3, 4), 5, [TRAIT_DEEP], 2)
	var policies: Array = [_burrower_policy(), _scout_policy(), _resource_policy()]

	var forward: Dictionary = Service.plan([encounter, resource], policies, registry, 7)
	var reversed_candidates: Array = [resource, encounter]
	var reversed_policies: Array = policies.duplicate()
	reversed_policies.reverse()
	var reverse: Dictionary = Service.plan(reversed_candidates, reversed_policies, registry, 7)
	_expect_true(failures, "forward underground placement succeeds", bool(forward.get("success", false)))
	_expect_true(failures, "reversed underground placement succeeds", bool(reverse.get("success", false)))
	if not bool(forward.get("success", false)) or not bool(reverse.get("success", false)):
		return
	_expect_equal(
		failures,
		"candidate/policy request order cannot change placement output",
		_records_data(forward.get("placements", [])),
		_records_data(reverse.get("placements", []))
	)
	_expect_equal(failures, "encounter/resource proof fills four deterministic slots", forward.get("placements", []).size(), 4)

	var encounter_only: Dictionary = Service.plan([encounter], policies, registry, 7)
	_expect_true(failures, "single-candidate request succeeds", bool(encounter_only.get("success", false)))
	if bool(encounter_only.get("success", false)):
		_expect_equal(
			failures,
			"requesting unrelated candidates cannot change persistent encounter placement",
			_records_for_candidate(forward.get("placements", []), encounter.stable_id),
			_records_data(encounter_only.get("placements", []))
		)

	for placement in forward.get("placements", []):
		var candidate_id = StableId.parse(placement.candidate_stable_id)
		var expected_address = candidate_id.address().child(["placement", "slot", str(placement.slot_index)])
		var expected_id = StableId.from_address(expected_address)
		_expect_equal(
			failures,
			"placement identity is a deterministic child of candidate identity",
			placement.placement_stable_id,
			expected_id.value()
		)


static func _test_slot_identity_is_stable_across_rulebook_revision(failures: Array[String]) -> void:
	var registry = _registry()
	if not registry.is_valid():
		failures.append("rulebook revision proof registry is invalid")
		return
	var candidate = _candidate(5, CATEGORY_SITE_RESOURCE, Vector2i(-5, -2), 6, [TRAIT_DEEP], 2)
	var first: Dictionary = Service.plan([candidate], [_resource_policy()], registry, 1)
	var revised: Dictionary = Service.plan([candidate], [_resource_policy()], registry, 2)
	_expect_true(failures, "rulebook revision baseline plan succeeds", bool(first.get("success", false)))
	_expect_true(failures, "rulebook revision revised plan succeeds", bool(revised.get("success", false)))
	if not bool(first.get("success", false)) or not bool(revised.get("success", false)):
		return
	_expect_equal(
		failures,
		"rulebook revision does not rewrite persistent placement slot addresses",
		_placement_ids(first.get("placements", [])),
		_placement_ids(revised.get("placements", []))
	)
	_expect_true(
		failures,
		"rulebook revision participates in compatibility fingerprints",
		_fingerprints(first.get("placements", [])) != _fingerprints(revised.get("placements", []))
	)


static func _test_eligibility_capacity_and_empty_result(failures: Array[String]) -> void:
	var registry = _registry()
	if not registry.is_valid():
		failures.append("eligibility proof registry is invalid")
		return
	var shallow = _candidate(6, CATEGORY_SITE_RESOURCE, Vector2i(1, -7), 1, [TRAIT_DEEP], 4)
	var shallow_result: Dictionary = Service.plan([shallow], [_resource_policy()], registry, 3)
	_expect_true(failures, "ineligible depth returns a valid plan", bool(shallow_result.get("success", false)))
	_expect_equal(failures, "ineligible depth yields deterministic empty placement", shallow_result.get("placements", []).size(), 0)

	var unused = _candidate(7, CATEGORY_SITE_UNUSED, Vector2i(1, -7), 5, [TRAIT_DEEP], 3)
	var unused_result: Dictionary = Service.plan([unused], [_resource_policy()], registry, 3)
	_expect_true(failures, "no matching authored category is a valid empty result", bool(unused_result.get("success", false)))
	_expect_equal(failures, "no matching authored category produces no placements", unused_result.get("placements", []).size(), 0)

	var resource = _candidate(8, CATEGORY_SITE_RESOURCE, Vector2i(1, -7), 5, [TRAIT_DEEP], 5)
	var capped_result: Dictionary = Service.plan([resource], [_resource_policy()], registry, 3)
	_expect_true(failures, "capacity-capped resource plan succeeds", bool(capped_result.get("success", false)))
	_expect_equal(failures, "policy max_per_candidate caps local candidate capacity", capped_result.get("placements", []).size(), 2)


static func _test_invalid_candidates_and_targets_fail_closed(failures: Array[String]) -> void:
	var registry = _registry()
	if not registry.is_valid():
		failures.append("failure-semantics proof registry is invalid")
		return
	var valid_candidate = _candidate(9, CATEGORY_SITE_RESOURCE, Vector2i(-1, -1), 5, [TRAIT_DEEP], 1)
	var invalid_candidate = Candidate.new().configure(
		"not-a-stable-id",
		"reserved_site",
		Vector2i(-1, -1),
		5,
		[CATEGORY_SITE_RESOURCE],
		[TRAIT_DEEP],
		1
	)
	var invalid_result: Dictionary = Service.plan([valid_candidate, invalid_candidate], [_resource_policy()], registry, 1)
	_expect_true(failures, "invalid candidate fails the whole authored plan", not bool(invalid_result.get("success", true)))
	_expect_equal(failures, "invalid candidate failure emits no partial placements", invalid_result.get("placements", []).size(), 0)

	var missing = _resource_policy()
	missing.configure(
		"placement_policy.resource.missing",
		"resource.deposit.missing",
		"resource",
		["reserved_site"],
		[CATEGORY_SITE_RESOURCE],
		[TRAIT_DEEP],
		[CATEGORY_RESOURCE_DEPOSIT],
		4,
		9,
		2,
		1
	)
	var missing_result: Dictionary = Service.plan([valid_candidate], [missing], registry, 1)
	_expect_true(failures, "missing semantic target fails closed", not bool(missing_result.get("success", true)))
	_expect_equal(failures, "missing target emits no placements", missing_result.get("placements", []).size(), 0)

	var wrong_family = _resource_policy()
	wrong_family.configure(
		"placement_policy.resource.wrong_family",
		"creature.enemy.burrower",
		"resource",
		["reserved_site"],
		[CATEGORY_SITE_RESOURCE],
		[TRAIT_DEEP],
		[],
		4,
		9,
		1,
		1
	)
	var wrong_family_result: Dictionary = Service.plan([valid_candidate], [wrong_family], registry, 1)
	_expect_true(failures, "wrong target family fails through ContentRegistry", not bool(wrong_family_result.get("success", true)))
	_expect_equal(failures, "wrong target family emits no placements", wrong_family_result.get("placements", []).size(), 0)

	var wrong_category = _burrower_policy()
	wrong_category.required_target_category_ids = [CATEGORY_RESOURCE_DEPOSIT]
	var encounter_candidate = _candidate(10, CATEGORY_SITE_ENCOUNTER, Vector2i(-1, -1), 4, [TRAIT_PRIMARY], 1)
	var wrong_category_result: Dictionary = Service.plan([encounter_candidate], [wrong_category], registry, 1)
	_expect_true(failures, "incompatible authored target category fails closed", not bool(wrong_category_result.get("success", true)))
	_expect_equal(failures, "incompatible target category emits no placements", wrong_category_result.get("placements", []).size(), 0)


static func _test_records_do_not_own_world_delta_state(failures: Array[String]) -> void:
	var registry = _registry()
	if not registry.is_valid():
		failures.append("world-delta ownership proof registry is invalid")
		return
	var candidate = _candidate(11, CATEGORY_SITE_ENCOUNTER, Vector2i(2, -3), 4, [TRAIT_PRIMARY], 1)
	var result: Dictionary = Service.plan([candidate], [_burrower_policy()], registry, 9)
	_expect_true(failures, "world-delta ownership proof placement succeeds", bool(result.get("success", false)))
	if not bool(result.get("success", false)) or result.get("placements", []).is_empty():
		return
	var canonical: Dictionary = result["placements"][0].canonical_data()
	for mutable_key in ["defeated", "depleted", "consumed", "remaining_capacity", "runtime_state"]:
		_expect_true(
			failures,
			"base placement record excludes mutable delta key '%s'" % mutable_key,
			not canonical.has(mutable_key)
		)
	_expect_true(failures, "placement fingerprint has CONTENT-002 namespace", str(canonical.get("placement_fingerprint", "")).begins_with("upf1:"))


static func _registry():
	var registry = ContentRegistry.new()
	registry.index_definitions([
		_creature("creature.enemy.burrower", "Burrower"),
		_creature("creature.enemy.burrower_scout", "Burrower Scout"),
		_resource(),
	])
	return registry


static func _creature(content_id: String, display_name: String):
	var definition = CreatureDefinition.new()
	definition.configure_creature(content_id, display_name, 36, 3.3, 16.0, 1.8, 10, 1.2, 0.42, 1)
	definition.configure_schema_declarations([CATEGORY_CREATURE_ENEMY], ["capability.movement"])
	definition.configure_semantic_bindings("", "archetype.creature.burrower.prototype", "", "")
	return definition


static func _resource():
	var definition = ResourceDefinition.new()
	definition.configure_resource("resource.deposit.underworld_ore", 12.0, 1)
	definition.configure_schema_declarations([CATEGORY_RESOURCE_DEPOSIT], ["capability.excavatable"])
	var yield_rule = ResourceYieldRule.new()
	yield_rule.configure(
		definition.content_id,
		"yield.primary",
		"item.resource.underworld_ore",
		1.0
	)
	definition.configure_yield_rules([yield_rule])
	return definition


static func _burrower_policy():
	return Policy.new().configure(
		"placement_policy.encounter.burrower",
		"creature.enemy.burrower",
		"creature",
		["reserved_site"],
		[CATEGORY_SITE_ENCOUNTER],
		[TRAIT_PRIMARY],
		[CATEGORY_CREATURE_ENEMY],
		2,
		6,
		1,
		3
	)


static func _scout_policy():
	return Policy.new().configure(
		"placement_policy.encounter.burrower_scout",
		"creature.enemy.burrower_scout",
		"creature",
		["reserved_site"],
		[CATEGORY_SITE_ENCOUNTER],
		[TRAIT_PRIMARY],
		[CATEGORY_CREATURE_ENEMY],
		2,
		6,
		1,
		1
	)


static func _resource_policy():
	return Policy.new().configure(
		"placement_policy.resource.underworld_ore",
		"resource.deposit.underworld_ore",
		"resource",
		["reserved_site"],
		[CATEGORY_SITE_RESOURCE],
		[TRAIT_DEEP],
		[CATEGORY_RESOURCE_DEPOSIT],
		4,
		9,
		2,
		1
	)


static func _candidate(
	slot: int,
	category_id: String,
	region_coord: Vector2i,
	depth_band: int,
	traits: Array,
	capacity: int
):
	var assignment = _assignment(slot, [category_id])
	return Candidate.from_reserved_site_assignment(
		assignment,
		region_coord,
		depth_band,
		traits,
		capacity
	)


static func _assignment(slot: int, category_ids: Array):
	var region_address = StableAddress.underground_region(-4, 2)
	var site_address = StableAddress.special_location(region_address, "reserved_site", slot)
	var site_id = StableId.from_address(site_address)
	return ReservedSiteAssignment.new(
		site_id.value(),
		AABB(Vector3(slot * 3.0, -12.0, -8.0), Vector3(2.0, 2.0, 2.0)),
		"structure.underworld.site_%d" % slot,
		category_ids,
		1,
		1,
		"rsa1:test_%d" % slot,
		{}
	)


static func _records_data(records: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record in records:
		result.append(record.canonical_data())
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("placement_stable_id", "")) < str(b.get("placement_stable_id", ""))
	)
	return result


static func _records_for_candidate(records: Array, candidate_stable_id: String) -> Array[Dictionary]:
	var filtered: Array = []
	for record in records:
		if record.candidate_stable_id == candidate_stable_id:
			filtered.append(record)
	return _records_data(filtered)


static func _placement_ids(records: Array) -> Array[String]:
	var result: Array[String] = []
	for record in records:
		result.append(record.placement_stable_id)
	result.sort()
	return result


static func _fingerprints(records: Array) -> Array[String]:
	var result: Array[String] = []
	for record in records:
		result.append(record.placement_fingerprint)
	result.sort()
	return result


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
