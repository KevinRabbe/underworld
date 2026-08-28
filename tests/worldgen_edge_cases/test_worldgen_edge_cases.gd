extends RefCounted

const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const SurfaceSampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const MacroRegionGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const PrimaryTopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")
const EntranceGenerator := preload("res://worldgen/underworld/entrance_generator.gd")
const ConnectivityGenerator := preload("res://worldgen/underworld/secondary_connectivity_generator.gd")
const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")

const LARGE_POSITIVE_SEED: int = 4611686018427387903
const LARGE_NEGATIVE_SEED: int = -4611686018427387903
const LARGE_REGION_COORD: int = 1000000


static func run(failures: Array[String]) -> void:
	var corpus: Array[Dictionary] = _corpus()
	var forward: Dictionary = {}
	for case in corpus:
		var snapshot: Dictionary = _run_case(case, failures)
		forward[_case_key(case)] = snapshot

	var reversed: Array[Dictionary] = corpus.duplicate(true)
	reversed.reverse()
	for case in reversed:
		var key: String = _case_key(case)
		var repeated: Dictionary = _run_case(case, failures)
		if not forward.has(key):
			failures.append("missing forward result for " + key)
			continue
		if forward[key] != repeated:
			failures.append("corpus order/reproduction mismatch for " + key)

	_expect_equal(failures, "corpus case count", corpus.size(), 8)
	_expect_true(
		failures,
		"corpus contains >53-bit positive seed",
		_abs_int(LARGE_POSITIVE_SEED) > 9007199254740991
	)
	_expect_true(
		failures,
		"corpus contains >53-bit negative seed",
		_abs_int(LARGE_NEGATIVE_SEED) > 9007199254740991
	)


static func _corpus() -> Array[Dictionary]:
	return [
		{"label": "zero-origin", "seed": 0, "coord": Vector2i(0, 0)},
		{"label": "one-x-negative-boundary", "seed": 1, "coord": Vector2i(-1, 0)},
		{"label": "minus-one-z-negative-boundary", "seed": -1, "coord": Vector2i(0, -1)},
		{
			"label": "large-positive-seed-negative-quadrant",
			"seed": LARGE_POSITIVE_SEED,
			"coord": Vector2i(-1, -1),
		},
		{
			"label": "large-negative-seed-positive-quadrant",
			"seed": LARGE_NEGATIVE_SEED,
			"coord": Vector2i(1, 1),
		},
		{
			"label": "large-positive-coordinate",
			"seed": 123456789,
			"coord": Vector2i(LARGE_REGION_COORD, LARGE_REGION_COORD),
		},
		{
			"label": "large-negative-coordinate",
			"seed": -123456789,
			"coord": Vector2i(-LARGE_REGION_COORD, -LARGE_REGION_COORD),
		},
		{
			"label": "large-mixed-coordinate",
			"seed": 3141592653589793,
			"coord": Vector2i(-LARGE_REGION_COORD, LARGE_REGION_COORD),
		},
	]


static func _run_case(case: Dictionary, failures: Array[String]) -> Dictionary:
	var label: String = str(case["label"])
	var seed: int = int(case["seed"])
	var coord: Vector2i = case["coord"]
	var context = WorldGenerationContext.new(seed)
	var surface_sampler = SurfaceSampler.new(seed)

	var macro_stage = MacroRegionGenerator.generate(context, coord)
	if not _require_stage_success(label, "macro_region", macro_stage, failures):
		return {"success": false, "stage": "macro_region"}
	var expected_region_address = StableAddress.underground_region(coord.x, coord.y)
	_expect_true(failures, label + " expected region address exists", expected_region_address != null)
	if expected_region_address != null:
		_expect_equal(
			failures,
			label + " region canonical address",
			macro_stage.data.stable_address.canonical_text(),
			expected_region_address.canonical_text()
		)
	_validate_definition_identity(macro_stage.data, label + " macro region", failures)

	var topology_stage = PrimaryTopologyGenerator.generate(
		context,
		macro_stage.data,
		surface_sampler
	)
	if not _require_stage_success(label, "primary_topology", topology_stage, failures):
		return {"success": false, "stage": "primary_topology"}

	var entrance_stage = EntranceGenerator.generate(
		context,
		macro_stage.data,
		topology_stage.data,
		surface_sampler
	)
	if not _require_stage_success(label, "entrance_generation", entrance_stage, failures):
		return {"success": false, "stage": "entrance_generation"}

	var neighbor_build: Dictionary = _build_neighbor_views(
		context,
		surface_sampler,
		coord,
		label,
		failures
	)
	if not bool(neighbor_build.get("success", false)):
		return {"success": false, "stage": "neighbor_views"}

	var connectivity_stage = ConnectivityGenerator.generate(
		context,
		macro_stage.data,
		topology_stage.data,
		entrance_stage.data,
		neighbor_build["views"]
	)
	if not _require_stage_success(label, "secondary_connectivity", connectivity_stage, failures):
		return {"success": false, "stage": "secondary_connectivity"}

	var bundle = connectivity_stage.data.bundle
	_validate_bundle_identity(bundle, coord, label, failures)
	_validate_external_reference_identity(
		connectivity_stage.data.external_edge_references,
		label,
		failures
	)

	return {
		"success": true,
		"seed": seed,
		"coord": [coord.x, coord.y],
		"world_id": str(context.world_id),
		"manifest": str(context.generator_manifest_id),
		"fingerprints": [
			str(macro_stage.fingerprint),
			str(topology_stage.fingerprint),
			str(entrance_stage.fingerprint),
			str(connectivity_stage.fingerprint),
		],
		"identity": _identity_snapshot(bundle, connectivity_stage.data.external_edge_references),
	}


static func _build_neighbor_views(
	context,
	surface_sampler,
	coord: Vector2i,
	label: String,
	failures: Array[String]
) -> Dictionary:
	var views: Array = []
	for offset in [
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(0, -1),
		Vector2i(0, 1),
	]:
		var neighbor_coord: Vector2i = coord + offset
		var macro_stage = MacroRegionGenerator.generate(context, neighbor_coord)
		if not _require_stage_success(
			label,
			"neighbor macro_region (%d,%d)" % [neighbor_coord.x, neighbor_coord.y],
			macro_stage,
			failures
		):
			return {"success": false, "views": views}
		var topology_stage = PrimaryTopologyGenerator.generate(
			context,
			macro_stage.data,
			surface_sampler
		)
		if not _require_stage_success(
			label,
			"neighbor primary_topology (%d,%d)" % [neighbor_coord.x, neighbor_coord.y],
			topology_stage,
			failures
		):
			return {"success": false, "views": views}
		views.append({
			"region_plan": macro_stage.data,
			"primary_topology": topology_stage.data,
		})
	return {"success": true, "views": views}


static func _validate_bundle_identity(
	bundle,
	coord: Vector2i,
	label: String,
	failures: Array[String]
) -> void:
	_expect_true(failures, label + " connectivity bundle exists", bundle != null)
	if bundle == null:
		return
	var expected_region_address = StableAddress.underground_region(coord.x, coord.y)
	if bundle.region_definition == null:
		failures.append(label + " bundle has null region definition")
	else:
		_validate_definition_identity(bundle.region_definition, label + " region", failures)
		if expected_region_address != null:
			_expect_equal(
				failures,
				label + " final region canonical address",
				bundle.region_definition.stable_address.canonical_text(),
				expected_region_address.canonical_text()
			)
	for network in bundle.networks:
		_validate_definition_identity(network, label + " network", failures)
	for node in bundle.nodes:
		_validate_definition_identity(node, label + " node", failures)
	for edge in bundle.edges:
		_validate_definition_identity(edge, label + " edge", failures)
	for entrance in bundle.entrances:
		_validate_definition_identity(entrance, label + " entrance", failures)


static func _validate_definition_identity(definition, label: String, failures: Array[String]) -> void:
	if definition == null:
		failures.append(label + " is null")
		return
	if definition.stable_address == null:
		failures.append(label + " has null StableAddress")
		return
	var canonical: String = definition.stable_address.canonical_text()
	var parsed_address = StableAddress.parse(canonical)
	if parsed_address == null:
		failures.append(label + " StableAddress canonical parse failed")
		return
	_expect_equal(failures, label + " StableAddress round-trip", parsed_address.canonical_text(), canonical)
	var derived = StableId.from_address(parsed_address)
	if derived == null:
		failures.append(label + " StableId derivation failed")
		return
	_expect_equal(failures, label + " StableId matches address", str(definition.stable_id), derived.value())
	var parsed_id = StableId.parse(str(definition.stable_id))
	if parsed_id == null:
		failures.append(label + " StableId parse failed")
	else:
		_expect_equal(failures, label + " StableId round-trip", parsed_id.value(), str(definition.stable_id))


static func _validate_external_reference_identity(
	references: Array,
	label: String,
	failures: Array[String]
) -> void:
	for reference in references:
		if reference == null:
			failures.append(label + " external reference is null")
			continue
		if reference.edge_stable_address == null:
			failures.append(label + " external reference has null StableAddress")
			continue
		var canonical: String = reference.edge_stable_address.canonical_text()
		var parsed_address = StableAddress.parse(canonical)
		if parsed_address == null:
			failures.append(label + " external reference address parse failed")
			continue
		var derived = StableId.from_address(parsed_address)
		if derived == null:
			failures.append(label + " external reference StableId derivation failed")
			continue
		_expect_equal(
			failures,
			label + " external reference StableId matches address",
			str(reference.edge_stable_id),
			derived.value()
		)


static func _identity_snapshot(bundle, references: Array) -> Dictionary:
	var result := {
		"region": _definition_identity_text(bundle.region_definition),
		"networks": [],
		"nodes": [],
		"edges": [],
		"entrances": [],
		"external_refs": [],
	}
	for network in bundle.networks:
		result["networks"].append(_definition_identity_text(network))
	for node in bundle.nodes:
		result["nodes"].append(_definition_identity_text(node))
	for edge in bundle.edges:
		result["edges"].append(_definition_identity_text(edge))
	for entrance in bundle.entrances:
		result["entrances"].append(_definition_identity_text(entrance))
	for reference in references:
		result["external_refs"].append(
			str(reference.edge_stable_id) + "|" + reference.edge_stable_address.canonical_text()
		)
	for key in ["networks", "nodes", "edges", "entrances", "external_refs"]:
		result[key].sort()
	return result


static func _definition_identity_text(definition) -> String:
	return str(definition.stable_id) + "|" + definition.stable_address.canonical_text()


static func _require_stage_success(
	label: String,
	stage_label: String,
	stage_result,
	failures: Array[String]
) -> bool:
	if stage_result == null:
		failures.append(label + " " + stage_label + " returned null")
		return false
	if not bool(stage_result.success):
		failures.append(
			"%s %s failed diagnostics=%s" % [label, stage_label, str(stage_result.diagnostics)]
		)
		return false
	if str(stage_result.fingerprint).is_empty():
		failures.append(label + " " + stage_label + " has empty fingerprint")
		return false
	return true


static func _case_key(case: Dictionary) -> String:
	var coord: Vector2i = case["coord"]
	return "%s|%d|%d|%d" % [str(case["label"]), int(case["seed"]), coord.x, coord.y]


static func _abs_int(value: int) -> int:
	return -value if value < 0 else value


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s expected=%s actual=%s" % [label, str(expected), str(actual)])
