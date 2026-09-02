extends RefCounted
class_name UnderworldWorldGatewayDefinitionService

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const SeedDeriver := preload("res://worldgen/random/seed_deriver.gd")
const SeedDomains := preload("res://worldgen/random/seed_domains.gd")
const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")
const StageResult := preload("res://worldgen/pipeline/generation_stage_result.gd")
const EndpointDefinition := preload("res://worldgen/gateway/gateway_endpoint_definition.gd")
const LinkDefinition := preload("res://worldgen/gateway/world_gateway_link_definition.gd")

const STAGE_SOURCE: String = "gateway.source_site"
const STAGE_DESTINATION: String = "gateway.destination_site"
const STAGE_LINK: String = "gateway.link"
const CONTRACT_REVISION: int = 1
const DEFAULT_POLICY_ID: String = "paired"
const DEFAULT_POLICY_REVISION: int = 1


static func define_source_site(
	context,
	source_domain_id: String,
	candidates: Array
):
	return _define_endpoint(
		context,
		EndpointDefinition.KIND_SOURCE,
		source_domain_id,
		candidates,
		STAGE_SOURCE,
		SeedDomains.GATEWAY_OVERWORLD_SOURCE_SITE
	)


static func define_destination_site(
	context,
	destination_domain_id: String,
	candidates: Array
):
	return _define_endpoint(
		context,
		EndpointDefinition.KIND_DESTINATION,
		destination_domain_id,
		candidates,
		STAGE_DESTINATION,
		SeedDomains.GATEWAY_UNDERWORLD_DESTINATION_SITE
	)


static func define_paired_link(
	context,
	source_endpoint,
	destination_endpoint,
	policy_id: String = DEFAULT_POLICY_ID,
	policy_revision: int = DEFAULT_POLICY_REVISION
):
	var failures: Array[String] = _feature_contract_failures(
		context,
		STAGE_LINK,
		SeedDomains.GATEWAY_LINK_PAIRING
	)
	if not _is_semantic_token(policy_id, 64):
		failures.append("Gateway link policy id must be a bounded semantic token")
	if policy_revision <= 0:
		failures.append("Gateway link policy revision must be positive")
	if source_endpoint == null or not source_endpoint.has_method("validate"):
		failures.append("Gateway link requires a source endpoint definition")
	if destination_endpoint == null or not destination_endpoint.has_method("validate"):
		failures.append("Gateway link requires a destination endpoint definition")
	if not failures.is_empty():
		return StageResult.fail(STAGE_LINK, failures)

	failures.append_array(source_endpoint.validate())
	failures.append_array(destination_endpoint.validate())
	if source_endpoint.endpoint_kind != EndpointDefinition.KIND_SOURCE:
		failures.append("Gateway link source endpoint has the wrong semantic kind")
	if destination_endpoint.endpoint_kind != EndpointDefinition.KIND_DESTINATION:
		failures.append("Gateway link destination endpoint has the wrong semantic kind")
	if source_endpoint.domain_id == destination_endpoint.domain_id:
		failures.append("Gateway paired link requires distinct semantic domains")
	if source_endpoint.world_id != context.world_id or destination_endpoint.world_id != context.world_id:
		failures.append("Gateway link rejects cross-root endpoint world splice")
	if (
		source_endpoint.generator_manifest_id != context.generator_manifest_id
		or destination_endpoint.generator_manifest_id != context.generator_manifest_id
	):
		failures.append("Gateway link rejects cross-root endpoint manifest splice")
	if StableId.parse(source_endpoint.stable_id) == null:
		failures.append("Gateway link source endpoint StableId is malformed")
	if StableId.parse(destination_endpoint.stable_id) == null:
		failures.append("Gateway link destination endpoint StableId is malformed")
	if not failures.is_empty():
		return StageResult.fail(STAGE_LINK, failures)

	var stage_revision: int = _captured_stage_revision(context, STAGE_LINK)
	var endpoint_ids: Array[String] = [
		source_endpoint.stable_id,
		destination_endpoint.stable_id,
	]
	endpoint_ids.sort()
	var address = StableAddress.from_segments([
		"gateway",
		"link",
		"policy",
		policy_id,
		"policy-revision",
		str(policy_revision),
		"stage-revision",
		str(stage_revision),
		"endpoint-a",
		endpoint_ids[0],
		"endpoint-b",
		endpoint_ids[1],
	])
	if address == null:
		return StageResult.fail(STAGE_LINK, ["Gateway link StableAddress construction failed"])

	var seed_domain = SeedDomains.get_domain(SeedDomains.GATEWAY_LINK_PAIRING)
	var pairing_variant: int = SeedDeriver.derive_u32(
		context.world_seed,
		address,
		seed_domain,
		"pairing-variant"
	)
	var provenance = context.make_provenance(
		STAGE_LINK,
		"",
		"",
		[source_endpoint.fingerprint, destination_endpoint.fingerprint]
	)
	if provenance == null:
		return StageResult.fail(STAGE_LINK, ["Gateway link provenance construction failed"])

	var link = LinkDefinition.new(
		address,
		source_endpoint.stable_id,
		source_endpoint.domain_id,
		destination_endpoint.stable_id,
		destination_endpoint.domain_id,
		policy_id,
		policy_revision,
		true,
		stage_revision,
		pairing_variant,
		context.world_id,
		context.generator_manifest_id,
		provenance
	)
	failures.append_array(link.validate())
	if not failures.is_empty():
		return StageResult.fail(STAGE_LINK, failures)
	return StageResult.ok(STAGE_LINK, link, link.fingerprint, provenance)


static func _define_endpoint(
	context,
	endpoint_kind: String,
	semantic_domain_id: String,
	candidates: Array,
	stage_id: String,
	seed_domain_id: int
):
	var failures: Array[String] = _feature_contract_failures(
		context,
		stage_id,
		seed_domain_id
	)
	if not _is_semantic_token(semantic_domain_id, 64):
		failures.append("Gateway endpoint domain id must be a bounded semantic token")
	if candidates.is_empty():
		failures.append("Gateway endpoint selection requires at least one candidate")
	if not failures.is_empty():
		return StageResult.fail(stage_id, failures)

	var stage_revision: int = _captured_stage_revision(context, stage_id)
	var seed_domain = SeedDomains.get_domain(seed_domain_id)
	var ranked: Array = []
	var seen_keys: Dictionary = {}
	for candidate_variant in candidates:
		if typeof(candidate_variant) != TYPE_DICTIONARY:
			failures.append("Gateway endpoint candidate must be a Dictionary")
			continue
		var candidate: Dictionary = candidate_variant
		var candidate_key: String = str(candidate.get("candidate_key", ""))
		var locator_variant = candidate.get("locator", {})
		if not _is_semantic_token(candidate_key, 96):
			failures.append("Gateway endpoint candidate key must be a bounded semantic token")
			continue
		if seen_keys.has(candidate_key):
			failures.append("Gateway endpoint candidate keys must be unique: " + candidate_key)
			continue
		seen_keys[candidate_key] = true
		if typeof(locator_variant) != TYPE_DICTIONARY:
			failures.append("Gateway endpoint candidate locator must be a Dictionary: " + candidate_key)
			continue
		var locator: Dictionary = locator_variant
		if locator.is_empty() or CanonicalValue.encode(locator).is_empty():
			failures.append("Gateway endpoint candidate locator must be non-empty canonical data: " + candidate_key)
			continue

		var address = _endpoint_address(
			endpoint_kind,
			semantic_domain_id,
			candidate_key,
			stage_revision
		)
		if address == null:
			failures.append("Gateway endpoint candidate StableAddress construction failed: " + candidate_key)
			continue
		var score: int = SeedDeriver.derive_u32(
			context.world_seed,
			address,
			seed_domain,
			"candidate-rank"
		)
		ranked.append({
			"candidate_key": candidate_key,
			"locator": locator.duplicate(true),
			"address": address,
			"score": score,
		})

	if not failures.is_empty():
		return StageResult.fail(stage_id, failures)
	if ranked.is_empty():
		return StageResult.fail(stage_id, ["Gateway endpoint selection has no valid candidates"])

	ranked.sort_custom(func(a, b):
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) < int(b["score"])
		return str(a["candidate_key"]) < str(b["candidate_key"])
	)
	var selected: Dictionary = ranked[0]
	var provenance = context.make_provenance(stage_id)
	if provenance == null:
		return StageResult.fail(stage_id, ["Gateway endpoint provenance construction failed"])
	var endpoint = EndpointDefinition.new(
		selected["address"],
		endpoint_kind,
		semantic_domain_id,
		str(selected["candidate_key"]),
		selected["locator"],
		stage_revision,
		context.world_id,
		context.generator_manifest_id,
		provenance
	)
	failures.append_array(endpoint.validate())
	if not failures.is_empty():
		return StageResult.fail(stage_id, failures)
	return StageResult.ok(stage_id, endpoint, endpoint.fingerprint, provenance)


static func _endpoint_address(
	endpoint_kind: String,
	semantic_domain_id: String,
	candidate_key: String,
	stage_revision: int
):
	return StableAddress.from_segments([
		"gateway",
		endpoint_kind,
		"domain",
		semantic_domain_id,
		"candidate",
		candidate_key,
		"revision",
		str(stage_revision),
	])


static func _feature_contract_failures(
	context,
	stage_id: String,
	seed_domain_id: int
) -> Array[String]:
	var failures: Array[String] = []
	if context == null:
		return ["Gateway definition requires a supplied WorldGenerationContext"]
	failures.append_array(context.validate_structure())
	if not failures.is_empty():
		return failures

	var snapshot: Dictionary = context.manifest_snapshot()
	var expected_stage_revision: int = CONTRACT_REVISION
	var captured_stage_revision: int = _stage_revision_from_snapshot(snapshot, stage_id)
	if captured_stage_revision != expected_stage_revision:
		failures.append(
			"Gateway feature unavailable: pinned manifest lacks exact stage %s@%d"
			% [stage_id, expected_stage_revision]
		)

	var expected_domain = SeedDomains.get_domain(seed_domain_id)
	if expected_domain == null:
		failures.append("Gateway runtime seed-domain support is missing: %08x" % seed_domain_id)
		return failures
	var captured_descriptor: Dictionary = _domain_descriptor_from_snapshot(
		snapshot,
		seed_domain_id
	)
	if captured_descriptor.is_empty():
		failures.append(
			"Gateway feature unavailable: pinned manifest lacks seed-domain %08x"
			% seed_domain_id
		)
	elif (
		int(captured_descriptor.get("revision", 0)) != int(expected_domain.revision)
		or str(captured_descriptor.get("readable_name", "")) != str(expected_domain.readable_name)
	):
		failures.append(
			"Gateway feature unavailable: pinned seed-domain descriptor mismatch %08x"
			% seed_domain_id
		)
	return failures


static func _captured_stage_revision(context, stage_id: String) -> int:
	if context == null:
		return 0
	return _stage_revision_from_snapshot(context.manifest_snapshot(), stage_id)


static func _stage_revision_from_snapshot(snapshot: Dictionary, stage_id: String) -> int:
	var entries_variant = snapshot.get("stage_entries", [])
	if typeof(entries_variant) != TYPE_ARRAY:
		return 0
	for entry_variant in entries_variant:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		if str(entry.get("id", "")) == stage_id:
			return int(entry.get("revision", 0))
	return 0


static func _domain_descriptor_from_snapshot(
	snapshot: Dictionary,
	seed_domain_id: int
) -> Dictionary:
	var descriptors_variant = snapshot.get("seed_domain_descriptors", [])
	if typeof(descriptors_variant) != TYPE_ARRAY:
		return {}
	for descriptor_variant in descriptors_variant:
		if typeof(descriptor_variant) != TYPE_DICTIONARY:
			continue
		var descriptor: Dictionary = descriptor_variant
		if int(descriptor.get("domain_id", 0)) == seed_domain_id:
			return descriptor.duplicate(true)
	return {}


static func _is_semantic_token(value: String, max_length: int) -> bool:
	if value.is_empty() or value.length() > max_length:
		return false
	for index in range(value.length()):
		var code: int = value.unicode_at(index)
		var allowed := (
			(code >= 48 and code <= 57)
			or (code >= 65 and code <= 90)
			or (code >= 97 and code <= 122)
			or code == 45
			or code == 46
			or code == 95
		)
		if not allowed:
			return false
	return true
