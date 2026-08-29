extends RefCounted
class_name UnderworldStableIdAudit

const Config := preload("res://tools/stable_id_audit/audit_config.gd")
const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")

var _failures: Array[String] = []
var _family_counts: Dictionary = {}
var _canonical_addresses: Dictionary = {}
var _stable_ids: Dictionary = {}
var _reproduction_checks: int = 0
var _endpoint_order_checks: int = 0


func run() -> Dictionary:
	_build_corpus()
	var total_cases: int = _canonical_addresses.size()
	var expected_cases: int = Config.expected_unique_case_count()
	if total_cases != expected_cases:
		_failures.append("case-count mismatch expected=%d actual=%d" % [expected_cases, total_cases])
	return {
		"success": _failures.is_empty(),
		"schema": "underworld-stable-id-audit-v1",
		"corpus_revision": Config.CORPUS_REVISION,
		"expected_case_count": expected_cases,
		"case_count": total_cases,
		"family_counts": _sorted_dictionary(_family_counts),
		"reproduction_checks": _reproduction_checks,
		"endpoint_order_checks": _endpoint_order_checks,
		"collision_count": _collision_failure_count(),
		"failure_count": _failures.size(),
		"failures": _failures.duplicate(),
	}


func _build_corpus() -> void:
	for region_x in Config.COORDINATES:
		for region_z in Config.COORDINATES:
			var region = StableAddress.underground_region(int(region_x), int(region_z))
			_record("underground_region", region)

			var network_roots: Array = []
			for network_slot in Config.SLOTS:
				var network = StableAddress.network(region, int(network_slot))
				_record("network", network)
				var root = StableAddress.node(network)
				_record("node", root)
				network_roots.append(root)

				for child_slot in Config.SLOTS:
					var child_node = StableAddress.node(network, [int(child_slot)])
					_record("node", child_node)
					var edge = StableAddress.primary_edge(
						network,
						root,
						child_node,
						int(child_slot)
					)
					_record("primary_edge", edge)
					_check_endpoint_order(
						"primary_edge",
						edge,
						StableAddress.primary_edge(
							network,
							child_node,
							root,
							int(child_slot)
						)
					)

				for lineage_a in Config.LINEAGE_SLOTS:
					for lineage_b in Config.LINEAGE_SLOTS:
						_record(
							"node",
							StableAddress.node(network, [int(lineage_a), int(lineage_b)])
						)

			var connector_a = network_roots[0]
			var connector_b = network_roots[1]
			for slot in Config.SLOTS:
				var entrance = StableAddress.entrance(region, int(slot))
				_record("entrance", entrance)
				_record("entrance_anchor", StableAddress.entrance_anchor(entrance))
				_record(
					"entrance_path_edge",
					StableAddress.entrance_path(entrance, connector_a)
				)

				var connector = StableAddress.secondary_connector(
					region,
					connector_a,
					connector_b,
					Config.CONNECTOR_CLASS,
					int(slot)
				)
				_record("secondary_connector", connector)
				_check_endpoint_order(
					"secondary_connector",
					connector,
					StableAddress.secondary_connector(
						region,
						connector_b,
						connector_a,
						Config.CONNECTOR_CLASS,
						int(slot)
					)
				)

				_record(
					"special_location",
					StableAddress.special_location(region, Config.SPECIAL_KIND, int(slot))
				)
				_record(
					"generated_child",
					StableAddress.generated_child(region, Config.CHILD_KIND, int(slot))
				)

			for domain in Config.SURFACE_DOMAINS:
				for slot in Config.SLOTS:
					_record(
						"surface_candidate",
						StableAddress.surface_candidate(
							str(domain),
							int(region_x),
							int(region_z),
							str(slot)
						)
					)


func _record(family: String, address) -> void:
	if address == null:
		_failures.append("%s factory returned null" % family)
		return
	var canonical: String = address.canonical_text()
	if canonical.is_empty():
		_failures.append("%s produced empty canonical text" % family)
		return
	if _canonical_addresses.has(canonical):
		_failures.append("duplicate canonical address generated family=%s canonical=%s" % [family, canonical])
		return

	var parsed = StableAddress.parse(canonical)
	if parsed == null or parsed.canonical_text() != canonical or not address.equals(parsed):
		_failures.append("address round-trip failed family=%s canonical=%s" % [family, canonical])
		return

	var stable_id = StableId.from_address(address)
	if stable_id == null:
		_failures.append("StableId derivation failed family=%s canonical=%s" % [family, canonical])
		return
	var stable_value: String = stable_id.value()
	var repeated_id = StableId.from_address(parsed)
	if repeated_id == null or repeated_id.value() != stable_value:
		_failures.append("StableId reproduction failed family=%s canonical=%s" % [family, canonical])
		return

	var parsed_id = StableId.parse(stable_value)
	if parsed_id == null or parsed_id.value() != stable_value:
		_failures.append("StableId parse round-trip failed family=%s id=%s" % [family, stable_value])
		return
	var recovered_address = parsed_id.address()
	if recovered_address == null or recovered_address.canonical_text() != canonical:
		_failures.append("StableId address round-trip failed family=%s id=%s" % [family, stable_value])
		return

	if _stable_ids.has(stable_value):
		var previous_canonical: String = str(_stable_ids[stable_value])
		if previous_canonical != canonical:
			_failures.append("StableId collision id=%s a=%s b=%s" % [
				stable_value,
				previous_canonical,
				canonical,
			])
			return

	_canonical_addresses[canonical] = family
	_stable_ids[stable_value] = canonical
	_family_counts[family] = int(_family_counts.get(family, 0)) + 1
	_reproduction_checks += 1


func _check_endpoint_order(family: String, canonical_address, reversed_address) -> void:
	_endpoint_order_checks += 1
	if canonical_address == null or reversed_address == null:
		_failures.append("%s endpoint-order factory returned null" % family)
		return
	if canonical_address.canonical_text() != reversed_address.canonical_text():
		_failures.append("%s endpoint order changed canonical address" % family)
		return
	var canonical_id = StableId.from_address(canonical_address)
	var reversed_id = StableId.from_address(reversed_address)
	if canonical_id == null or reversed_id == null or canonical_id.value() != reversed_id.value():
		_failures.append("%s endpoint order changed StableId" % family)


func _collision_failure_count() -> int:
	var count: int = 0
	for failure in _failures:
		if str(failure).contains("StableId collision"):
			count += 1
	return count


static func _sorted_dictionary(source: Dictionary) -> Dictionary:
	var keys: Array[String] = []
	for key in source.keys():
		keys.append(str(key))
	keys.sort()
	var result: Dictionary = {}
	for key in keys:
		result[key] = source[key]
	return result
