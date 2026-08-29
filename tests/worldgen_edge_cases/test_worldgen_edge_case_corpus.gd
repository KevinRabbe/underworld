extends RefCounted

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const SurfaceSampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const MacroRegionGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const PrimaryTopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")
const EntranceGenerator := preload("res://worldgen/underworld/entrance_generator.gd")
const ConnectivityGenerator := preload("res://worldgen/underworld/secondary_connectivity_generator.gd")

const LARGE_POSITIVE_SEED: int = 4611686018427387903
const LARGE_NEGATIVE_SEED: int = -4611686018427387904
const LARGE_COORD: int = 32768
const STAGE_FINGERPRINT_KEYS: Array[String] = [
	"macro_fingerprint",
	"topology_fingerprint",
	"entrance_fingerprint",
	"fingerprint",
]
const CARDINAL_NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(0, -1),
	Vector2i(0, 1),
]


static func run() -> Array[String]:
	var failures: Array[String] = []
	var corpus: Array[Dictionary] = _build_corpus()
	var forward_results: Dictionary = _run_corpus(corpus, true, failures, "forward")

	var reverse_corpus: Array[Dictionary] = corpus.duplicate(true)
	reverse_corpus.reverse()
	var reverse_results: Dictionary = _run_corpus(reverse_corpus, false, failures, "reverse")
	_assert_order_independence(forward_results, reverse_results, failures)
	return failures


static func _build_corpus() -> Array[Dictionary]:
	return [
		_case("origin-zero", 0, Vector2i(0, 0)),
		_case("x-transition", 1, Vector2i(-1, 0)),
		_case("z-transition", -1, Vector2i(0, -1)),
		_case("negative-transition", 0, Vector2i(-1, -1)),
		_case("positive-neighbor", 1, Vector2i(1, 1)),
		_case("mixed-sign-neighbor", -1, Vector2i(-1, 1)),
		_case("large-positive", LARGE_POSITIVE_SEED, Vector2i(LARGE_COORD, LARGE_COORD)),
		_case("large-negative", LARGE_NEGATIVE_SEED, Vector2i(-LARGE_COORD, -LARGE_COORD)),
		_case("large-mixed-a", LARGE_POSITIVE_SEED, Vector2i(-LARGE_COORD, LARGE_COORD)),
		_case("large-mixed-b", LARGE_NEGATIVE_SEED, Vector2i(LARGE_COORD, -LARGE_COORD)),
	]


static func _case(label: String, world_seed: int, region: Vector2i) -> Dictionary:
	return {
		"label": label,
		"seed": world_seed,
		"region": region,
	}


static func _run_corpus(
	corpus: Array[Dictionary],
	repeat_each: bool,
	failures: Array[String],
	pass_label: String
) -> Dictionary:
	var results: Dictionary = {}
	for case_data in corpus:
		var world_seed: int = int(case_data["seed"])
		var region: Vector2i = case_data["region"]
		var label: String = str(case_data["label"])
		var case_key := _case_key(world_seed, region)

		var identity_snapshot := _validate_identity(label, region, failures)
		var first: Dictionary = _build_fresh_stage_1_to_4(world_seed, region)
		if not bool(first.get("success", false)):
			failures.append(
				"%s corpus case %s failed at %s: %s" % [
					pass_label,
					label,
					first.get("stage", "unknown"),
					first.get("diagnostics", []),
				]
			)
			continue

		_validate_stage_fingerprints(label, first, failures)
		if repeat_each:
			var second: Dictionary = _build_fresh_stage_1_to_4(world_seed, region)
			if not bool(second.get("success", false)):
				failures.append(
					"fresh replay corpus case %s failed at %s: %s" % [
						label,
						second.get("stage", "unknown"),
						second.get("diagnostics", []),
					]
				)
			else:
				_assert_same_stage_fingerprints(label, first, second, failures)

		var snapshot: Dictionary = {
			"region_address": identity_snapshot.get("region_address", ""),
			"region_id": identity_snapshot.get("region_id", ""),
		}
		for fingerprint_key in STAGE_FINGERPRINT_KEYS:
			snapshot[fingerprint_key] = str(first.get(fingerprint_key, ""))
		results[case_key] = snapshot
	return results


static func _build_fresh_stage_1_to_4(
	world_seed: int,
	region_coord: Vector2i
) -> Dictionary:
	# Intentionally bypass SecondaryConnectivityReproductionProbe here. That
	# production validation helper caches immutable Stage-1/2/3 inputs for an
	# immediate replay so the broad campaign can rerun Stage 4 cheaply. TEST-056
	# must instead prove that the complete upstream pipeline reproduces from a
	# fresh context and surface sampler on every invocation.
	var context = WorldGenerationContext.new(world_seed)
	var sampler = SurfaceSampler.new(world_seed)

	var macro = MacroRegionGenerator.generate(context, region_coord)
	if not macro.success:
		return _failure("macro_region", macro.diagnostics)

	var topology = PrimaryTopologyGenerator.generate(context, macro.data, sampler)
	if not topology.success:
		return _failure("primary_topology", topology.diagnostics)

	var entrances = EntranceGenerator.generate(context, macro.data, topology.data, sampler)
	if not entrances.success:
		return _failure("entrance_generation", entrances.diagnostics)

	var neighbor_views: Array = []
	for offset in CARDINAL_NEIGHBOR_OFFSETS:
		var neighbor_macro = MacroRegionGenerator.generate(context, region_coord + offset)
		if not neighbor_macro.success:
			return _failure("neighbor_macro_region", neighbor_macro.diagnostics)
		var neighbor_topology = PrimaryTopologyGenerator.generate(
			context,
			neighbor_macro.data,
			sampler
		)
		if not neighbor_topology.success:
			return _failure("neighbor_primary_topology", neighbor_topology.diagnostics)
		neighbor_views.append({
			"region_plan": neighbor_macro.data,
			"primary_topology": neighbor_topology.data,
		})

	var connectivity = ConnectivityGenerator.generate(
		context,
		macro.data,
		topology.data,
		entrances.data,
		neighbor_views
	)
	if not connectivity.success:
		return _failure("secondary_connectivity", connectivity.diagnostics)

	return {
		"success": true,
		"macro_fingerprint": macro.fingerprint,
		"topology_fingerprint": topology.fingerprint,
		"entrance_fingerprint": entrances.fingerprint,
		"fingerprint": connectivity.fingerprint,
		"diagnostics": [],
	}


static func _failure(stage: String, diagnostics: Array) -> Dictionary:
	return {
		"success": false,
		"fingerprint": "",
		"stage": stage,
		"diagnostics": diagnostics,
	}


static func _validate_identity(
	label: String,
	region: Vector2i,
	failures: Array[String]
) -> Dictionary:
	var address = StableAddress.underground_region(region.x, region.y)
	if address == null:
		failures.append("%s produced null underground-region StableAddress" % label)
		return {}

	var canonical_text: String = address.canonical_text()
	var parsed_address = StableAddress.parse(canonical_text)
	if parsed_address == null or parsed_address.canonical_text() != canonical_text:
		failures.append("%s StableAddress canonical round-trip failed" % label)

	var stable_id = StableId.from_address(address)
	if stable_id == null:
		failures.append("%s produced null StableId" % label)
		return {"region_address": canonical_text}

	var stable_id_text: String = stable_id.value()
	var parsed_id = StableId.parse(stable_id_text)
	if parsed_id == null or parsed_id.value() != stable_id_text:
		failures.append("%s StableId canonical round-trip failed" % label)
	if parsed_address != null:
		var reparsed_id = StableId.from_address(parsed_address)
		if reparsed_id == null or reparsed_id.value() != stable_id_text:
			failures.append("%s StableAddress/StableId reproduction mismatch" % label)

	return {
		"region_address": canonical_text,
		"region_id": stable_id_text,
	}


static func _validate_stage_fingerprints(
	label: String,
	build_snapshot: Dictionary,
	failures: Array[String]
) -> void:
	for fingerprint_key in STAGE_FINGERPRINT_KEYS:
		if str(build_snapshot.get(fingerprint_key, "")).is_empty():
			failures.append("%s missing %s" % [label, fingerprint_key])


static func _assert_same_stage_fingerprints(
	label: String,
	first: Dictionary,
	second: Dictionary,
	failures: Array[String]
) -> void:
	for fingerprint_key in STAGE_FINGERPRINT_KEYS:
		var first_value: String = str(first.get(fingerprint_key, ""))
		var second_value: String = str(second.get(fingerprint_key, ""))
		if first_value != second_value:
			failures.append(
				"%s non-deterministic fresh replay %s: first=%s second=%s" % [
					label,
					fingerprint_key,
					first_value,
					second_value,
				]
			)


static func _assert_order_independence(
	forward_results: Dictionary,
	reverse_results: Dictionary,
	failures: Array[String]
) -> void:
	if forward_results.size() != reverse_results.size():
		failures.append(
			"corpus order changed completed case count: forward=%d reverse=%d" % [
				forward_results.size(),
				reverse_results.size(),
			]
		)

	for case_key_variant in forward_results.keys():
		var case_key: String = str(case_key_variant)
		if not reverse_results.has(case_key):
			failures.append("reverse corpus missing case %s" % case_key)
			continue
		var forward_snapshot: Dictionary = forward_results[case_key]
		var reverse_snapshot: Dictionary = reverse_results[case_key]
		for key in [
			"region_address",
			"region_id",
			"macro_fingerprint",
			"topology_fingerprint",
			"entrance_fingerprint",
			"fingerprint",
		]:
			if str(forward_snapshot.get(key, "")) != str(reverse_snapshot.get(key, "")):
				failures.append(
					"corpus order changed %s for case %s" % [key, case_key]
				)


static func _case_key(world_seed: int, region: Vector2i) -> String:
	return "%d:%d:%d" % [world_seed, region.x, region.y]
