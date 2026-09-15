extends RefCounted

const Context := preload("res://worldgen/pipeline/world_generation_context.gd")
const GeneratorManifest := preload("res://worldgen/versioning/generator_manifest.gd")
const RootPackage := preload("res://worldgen/versioning/root_generation_identity_package.gd")
const SeedDomains := preload("res://worldgen/random/seed_domains.gd")
const GatewayService := preload("res://worldgen/gateway/world_gateway_definition_service.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_current_manifest_contract(failures)
	_test_deterministic_independent_endpoints_and_link(failures)
	_test_bidirectional_resolution(failures)
	_test_detached_input_boundaries(failures)
	_test_cross_root_splice_rejected(failures)
	_test_historical_context_is_compatible_but_gateway_unavailable(failures)
	_test_root_package_round_trip(failures)
	return failures


static func _test_current_manifest_contract(failures: Array[String]) -> void:
	_expect_empty(failures, "gateway seed registry validates", SeedDomains.validate_registry())
	var source = SeedDomains.get_domain(SeedDomains.GATEWAY_OVERWORLD_SOURCE_SITE)
	var destination = SeedDomains.get_domain(SeedDomains.GATEWAY_UNDERWORLD_DESTINATION_SITE)
	var link = SeedDomains.get_domain(SeedDomains.GATEWAY_LINK_PAIRING)
	_expect_true(failures, "gateway source seed domain exists", source != null)
	_expect_true(failures, "gateway destination seed domain exists", destination != null)
	_expect_true(failures, "gateway link seed domain exists", link != null)
	if source != null:
		_expect_equal(failures, "gateway source seed id frozen", source.domain_id, 0x030001)
		_expect_equal(failures, "gateway source seed name frozen", source.readable_name, "gateway.overworld.source_site")
		_expect_equal(failures, "gateway source seed revision frozen", source.revision, 1)
	if destination != null:
		_expect_equal(failures, "gateway destination seed id frozen", destination.domain_id, 0x030101)
		_expect_equal(failures, "gateway destination seed name frozen", destination.readable_name, "gateway.underworld.destination_site")
		_expect_equal(failures, "gateway destination seed revision frozen", destination.revision, 1)
	if link != null:
		_expect_equal(failures, "gateway link seed id frozen", link.domain_id, 0x030201)
		_expect_equal(failures, "gateway link seed name frozen", link.readable_name, "gateway.link.pairing")
		_expect_equal(failures, "gateway link seed revision frozen", link.revision, 1)

	var context = Context.new(424242)
	var stages: Dictionary = context.generator_manifest.stage_revisions()
	_expect_equal(failures, "gateway source stage revision", int(stages.get("gateway.source_site", 0)), 1)
	_expect_equal(failures, "gateway destination stage revision", int(stages.get("gateway.destination_site", 0)), 1)
	_expect_equal(failures, "gateway link stage revision", int(stages.get("gateway.link", 0)), 1)


static func _test_deterministic_independent_endpoints_and_link(failures: Array[String]) -> void:
	var context = Context.new(424242)
	var source_candidates: Array = _source_candidates(0)
	var destination_candidates: Array = _destination_candidates(0)

	var source_a = GatewayService.define_source_site(context, "DOMAIN_A", source_candidates)
	var destination_a = GatewayService.define_destination_site(context, "DOMAIN_B", destination_candidates)
	_expect_success(failures, "source selection succeeds", source_a)
	_expect_success(failures, "destination selection succeeds", destination_a)
	if not source_a.success or not destination_a.success:
		return
	var link_a = GatewayService.define_paired_link(context, source_a.data, destination_a.data)
	_expect_success(failures, "paired link succeeds", link_a)
	if not link_a.success:
		return

	var destination_first = GatewayService.define_destination_site(context, "DOMAIN_B", destination_candidates)
	var source_second = GatewayService.define_source_site(context, "DOMAIN_A", source_candidates)
	var link_second = GatewayService.define_paired_link(context, source_second.data, destination_first.data)
	_expect_success(failures, "destination-first selection succeeds", destination_first)
	_expect_success(failures, "source-second selection succeeds", source_second)
	_expect_success(failures, "destination-first link succeeds", link_second)
	if destination_first.success and source_second.success and link_second.success:
		_expect_equal(failures, "source is order-independent", source_second.data.canonical_text(), source_a.data.canonical_text())
		_expect_equal(failures, "destination is order-independent", destination_first.data.canonical_text(), destination_a.data.canonical_text())
		_expect_equal(failures, "link is order-independent", link_second.data.canonical_text(), link_a.data.canonical_text())

	# A source-local semantic candidate perturbation must change the source identity
	# and therefore the link, while the independently generated destination remains exact.
	var changed_source = GatewayService.define_source_site(context, "DOMAIN_A", _source_identity_variant_candidates())
	var unchanged_destination = GatewayService.define_destination_site(context, "DOMAIN_B", destination_candidates)
	_expect_success(failures, "changed source identity fixture succeeds", changed_source)
	_expect_success(failures, "destination after source identity perturbation succeeds", unchanged_destination)
	if changed_source.success and unchanged_destination.success:
		_expect_true(failures, "source semantic perturbation changes source StableId", changed_source.data.stable_id != source_a.data.stable_id)
		_expect_equal(
			failures,
			"source-only identity perturbation cannot rewrite destination",
			unchanged_destination.data.canonical_text(),
			destination_a.data.canonical_text()
		)
		var changed_source_link = GatewayService.define_paired_link(context, changed_source.data, unchanged_destination.data)
		_expect_success(failures, "link after source identity perturbation succeeds", changed_source_link)
		if changed_source_link.success:
			_expect_true(failures, "link identity changes only after explicit source endpoint identity changes", changed_source_link.data.stable_id != link_a.data.stable_id)

	# Mirror the contract for a destination-local semantic perturbation.
	var unchanged_source = GatewayService.define_source_site(context, "DOMAIN_A", source_candidates)
	var changed_destination = GatewayService.define_destination_site(context, "DOMAIN_B", _destination_identity_variant_candidates())
	_expect_success(failures, "source after destination identity perturbation succeeds", unchanged_source)
	_expect_success(failures, "changed destination identity fixture succeeds", changed_destination)
	if unchanged_source.success and changed_destination.success:
		_expect_true(failures, "destination semantic perturbation changes destination StableId", changed_destination.data.stable_id != destination_a.data.stable_id)
		_expect_equal(
			failures,
			"destination-only identity perturbation cannot rewrite source",
			unchanged_source.data.canonical_text(),
			source_a.data.canonical_text()
		)
		var changed_destination_link = GatewayService.define_paired_link(context, unchanged_source.data, changed_destination.data)
		_expect_success(failures, "link after destination identity perturbation succeeds", changed_destination_link)
		if changed_destination_link.success:
			_expect_true(failures, "link identity changes only after explicit destination endpoint identity changes", changed_destination_link.data.stable_id != link_a.data.stable_id)

	# Locator-only changes are domain-local data changes. They may change endpoint
	# canonical bytes/fingerprint, but must never influence the opposite endpoint.
	var relocated_source = GatewayService.define_source_site(context, "DOMAIN_A", _source_candidates(700))
	var destination_after_relocation = GatewayService.define_destination_site(context, "DOMAIN_B", destination_candidates)
	_expect_success(failures, "source locator perturbation succeeds", relocated_source)
	_expect_success(failures, "destination after source locator perturbation succeeds", destination_after_relocation)
	if relocated_source.success and destination_after_relocation.success:
		_expect_equal(failures, "source locator perturbation cannot rewrite destination", destination_after_relocation.data.canonical_text(), destination_a.data.canonical_text())

	var identical_locator: Dictionary = {"anchor": Vector3(12.0, 4.0, -8.0), "radius": 2.0}
	var same_source = GatewayService.define_source_site(context, "DOMAIN_A", [{"candidate_key": "same", "locator": identical_locator}])
	var same_destination = GatewayService.define_destination_site(context, "DOMAIN_B", [{"candidate_key": "same", "locator": identical_locator}])
	_expect_success(failures, "identical source locator succeeds", same_source)
	_expect_success(failures, "identical destination locator succeeds", same_destination)
	if same_source.success and same_destination.success:
		_expect_true(failures, "identical numeric locator cannot collapse cross-domain identity", same_source.data.stable_id != same_destination.data.stable_id)


static func _test_bidirectional_resolution(failures: Array[String]) -> void:
	var context = Context.new(918273)
	var source = GatewayService.define_source_site(context, "DOMAIN_A", _source_candidates(0))
	var destination = GatewayService.define_destination_site(context, "DOMAIN_B", _destination_candidates(0))
	if not source.success or not destination.success:
		failures.append("bidirectional fixture endpoints failed")
		return
	var link = GatewayService.define_paired_link(context, source.data, destination.data)
	_expect_success(failures, "bidirectional fixture link succeeds", link)
	if not link.success:
		return
	var forward: Dictionary = link.data.resolve_other_endpoint(source.data.stable_id, "DOMAIN_A")
	var reverse: Dictionary = link.data.resolve_other_endpoint(destination.data.stable_id, "DOMAIN_B")
	_expect_equal(failures, "forward traversal resolves destination id", str(forward.get("endpoint_id", "")), destination.data.stable_id)
	_expect_equal(failures, "forward traversal resolves destination domain", str(forward.get("domain_id", "")), "DOMAIN_B")
	_expect_equal(failures, "reverse traversal resolves source id", str(reverse.get("endpoint_id", "")), source.data.stable_id)
	_expect_equal(failures, "reverse traversal resolves source domain", str(reverse.get("domain_id", "")), "DOMAIN_A")
	_expect_true(failures, "wrong-domain traversal fails closed", link.data.resolve_other_endpoint(source.data.stable_id, "DOMAIN_B").is_empty())
	_expect_true(failures, "malformed endpoint traversal fails closed", link.data.resolve_other_endpoint("sid1:not-canonical", "DOMAIN_A").is_empty())


static func _test_detached_input_boundaries(failures: Array[String]) -> void:
	var context = Context.new(777)
	var candidates: Array = _source_candidates(0)
	var result = GatewayService.define_source_site(context, "DOMAIN_A", candidates)
	_expect_success(failures, "detached source fixture succeeds", result)
	if not result.success:
		return
	var baseline: String = result.data.canonical_text()
	candidates[0]["candidate_key"] = "mutated"
	candidates[0]["locator"]["anchor"] = Vector3(999.0, 999.0, 999.0)
	var locator_copy: Dictionary = result.data.locator_snapshot()
	locator_copy["anchor"] = Vector3(-999.0, -999.0, -999.0)
	_expect_equal(failures, "caller mutation cannot rewrite accepted endpoint", result.data.canonical_text(), baseline)
	_expect_empty(failures, "accepted endpoint remains valid after caller mutation", result.data.validate())

	var malformed_domain = GatewayService.define_source_site(context, "BAD DOMAIN", _source_candidates(0))
	_expect_true(failures, "space-containing semantic domain rejects", not malformed_domain.success)
	var malformed_candidate = GatewayService.define_source_site(context, "DOMAIN_A", [{"candidate_key": "bad key", "locator": {"anchor": Vector3.ZERO}}])
	_expect_true(failures, "space-containing candidate key rejects", not malformed_candidate.success)


static func _test_cross_root_splice_rejected(failures: Array[String]) -> void:
	var context_a = Context.new(111)
	var context_b = Context.new(222)
	var source = GatewayService.define_source_site(context_a, "DOMAIN_A", _source_candidates(0))
	var destination = GatewayService.define_destination_site(context_b, "DOMAIN_B", _destination_candidates(0))
	if not source.success or not destination.success:
		failures.append("cross-root fixture endpoints failed")
		return
	var under_a = GatewayService.define_paired_link(context_a, source.data, destination.data)
	var under_b = GatewayService.define_paired_link(context_b, source.data, destination.data)
	_expect_true(failures, "cross-root splice rejects under source context", not under_a.success)
	_expect_true(failures, "cross-root splice rejects under destination context", not under_b.success)


static func _test_historical_context_is_compatible_but_gateway_unavailable(failures: Array[String]) -> void:
	var current = Context.new(424242)
	var snapshot: Dictionary = current.manifest_snapshot()
	var historical_stages: Array = []
	for entry_variant in snapshot["stage_entries"]:
		var entry: Dictionary = entry_variant
		if not str(entry.get("id", "")).begins_with("gateway."):
			historical_stages.append(entry.duplicate(true))
	snapshot["stage_entries"] = historical_stages

	var historical_domains: Array = []
	for descriptor_variant in snapshot["seed_domain_descriptors"]:
		var descriptor: Dictionary = descriptor_variant
		var domain_id: int = int(descriptor.get("domain_id", 0))
		if domain_id not in [
			SeedDomains.GATEWAY_OVERWORLD_SOURCE_SITE,
			SeedDomains.GATEWAY_UNDERWORLD_DESTINATION_SITE,
			SeedDomains.GATEWAY_LINK_PAIRING,
		]:
			historical_domains.append(descriptor.duplicate(true))
	snapshot["seed_domain_descriptors"] = historical_domains

	var historical_manifest = GeneratorManifest.from_snapshot(snapshot)
	_expect_empty(failures, "pre-gateway manifest remains runtime compatible", historical_manifest.runtime_compatibility_failures())
	var historical_context = Context.from_exact_identity(
		424242,
		current.world_id,
		current.world_id_contract(),
		historical_manifest
	)
	_expect_empty(failures, "pre-gateway context remains structurally valid", historical_context.validate_structure())
	var before_id: String = historical_context.generator_manifest_id
	var before_text: String = historical_context.generator_manifest.canonical_text()
	var source = GatewayService.define_source_site(historical_context, "DOMAIN_A", _source_candidates(0))
	_expect_true(failures, "pre-gateway compatible context cannot fabricate gateway source", not source.success)
	_expect_equal(failures, "failed gateway attempt cannot rewrite historical manifest id", historical_context.generator_manifest_id, before_id)
	_expect_equal(failures, "failed gateway attempt cannot rewrite historical manifest bytes", historical_context.generator_manifest.canonical_text(), before_text)


static func _test_root_package_round_trip(failures: Array[String]) -> void:
	var context = Context.new(13579)
	var source = GatewayService.define_source_site(context, "DOMAIN_A", _source_candidates(0))
	var destination = GatewayService.define_destination_site(context, "DOMAIN_B", _destination_candidates(0))
	if not source.success or not destination.success:
		failures.append("package round-trip source fixture failed")
		return
	var link = GatewayService.define_paired_link(context, source.data, destination.data)
	if not link.success:
		failures.append("package round-trip link fixture failed")
		return
	var package: Dictionary = RootPackage.encode(context)
	var restored: Dictionary = RootPackage.rehydrate(13579, package)
	_expect_true(failures, "gateway-aware package structurally rehydrates", bool(restored.get("success", false)))
	_expect_true(failures, "gateway-aware package is runtime compatible", bool(restored.get("compatible", false)))
	if not bool(restored.get("success", false)):
		return
	var restored_context = restored["context"]
	var source_again = GatewayService.define_source_site(restored_context, "DOMAIN_A", _source_candidates(0))
	var destination_again = GatewayService.define_destination_site(restored_context, "DOMAIN_B", _destination_candidates(0))
	var link_again = GatewayService.define_paired_link(restored_context, source_again.data, destination_again.data)
	_expect_success(failures, "rehydrated source generation succeeds", source_again)
	_expect_success(failures, "rehydrated destination generation succeeds", destination_again)
	_expect_success(failures, "rehydrated link generation succeeds", link_again)
	if source_again.success and destination_again.success and link_again.success:
		_expect_equal(failures, "package round-trip preserves source definition", source_again.data.canonical_text(), source.data.canonical_text())
		_expect_equal(failures, "package round-trip preserves destination definition", destination_again.data.canonical_text(), destination.data.canonical_text())
		_expect_equal(failures, "package round-trip preserves link definition", link_again.data.canonical_text(), link.data.canonical_text())


static func _source_candidates(offset: int) -> Array:
	return [
		{"candidate_key": "source-alpha", "locator": {"anchor": Vector3(10.0 + offset, 1.0, 20.0), "radius": 2.0}},
		{"candidate_key": "source-beta", "locator": {"anchor": Vector3(40.0 + offset, 2.0, 60.0), "radius": 3.0}},
	]


static func _source_identity_variant_candidates() -> Array:
	return [
		{"candidate_key": "source-gamma", "locator": {"anchor": Vector3(10.0, 1.0, 20.0), "radius": 2.0}},
		{"candidate_key": "source-delta", "locator": {"anchor": Vector3(40.0, 2.0, 60.0), "radius": 3.0}},
	]


static func _destination_candidates(offset: int) -> Array:
	return [
		{"candidate_key": "destination-alpha", "locator": {"anchor": Vector3(-80.0, -20.0 + offset, 14.0), "radius": 4.0}},
		{"candidate_key": "destination-beta", "locator": {"anchor": Vector3(-30.0, -45.0 + offset, 90.0), "radius": 5.0}},
	]


static func _destination_identity_variant_candidates() -> Array:
	return [
		{"candidate_key": "destination-gamma", "locator": {"anchor": Vector3(-80.0, -20.0, 14.0), "radius": 4.0}},
		{"candidate_key": "destination-delta", "locator": {"anchor": Vector3(-30.0, -45.0, 90.0), "radius": 5.0}},
	]


static func _expect_success(failures: Array[String], label: String, result) -> void:
	if result == null or not bool(result.success):
		failures.append("%s — diagnostics=%s" % [label, str([] if result == null else result.diagnostics)])


static func _expect_empty(failures: Array[String], label: String, values: Array) -> void:
	if not values.is_empty():
		failures.append("%s — %s" % [label, str(values)])


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(
	failures: Array[String],
	label: String,
	actual: Variant,
	expected: Variant
) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])
