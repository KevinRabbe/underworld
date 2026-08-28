extends RefCounted
class_name UnderworldWorldgenBenchmark

const Config := preload("res://tools/worldgen_benchmark/benchmark_config.gd")
const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const SurfaceSampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const MacroRegionGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const PrimaryTopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")
const EntranceGenerator := preload("res://worldgen/underworld/entrance_generator.gd")
const ConnectivityGenerator := preload("res://worldgen/underworld/secondary_connectivity_generator.gd")

const STAGES := [
	"macro_region",
	"primary_topology",
	"entrance_generation",
	"secondary_connectivity",
]


static func run() -> Dictionary:
	var cases: Array = []
	for spec in Config.benchmark_cases():
		var case_result: Dictionary = _run_case(int(spec["seed"]), spec["region"])
		if not bool(case_result.get("success", false)):
			return {
				"success": false,
				"schema": "underworld-worldgen-benchmark-v1",
				"corpus_revision": Config.CORPUS_REVISION,
				"failed_case": case_result,
				"completed_cases": cases,
			}
		cases.append(case_result)

	var report := {
		"success": true,
		"schema": "underworld-worldgen-benchmark-v1",
		"corpus_revision": Config.CORPUS_REVISION,
		"engine_version": Engine.get_version_info().get("string", "unknown"),
		"seed_count": Config.SEEDS.size(),
		"region_count": Config.REGIONS.size(),
		"case_count": cases.size(),
		"stages": _stage_summaries(cases),
		"count_totals": _count_totals(cases),
		"cases": cases,
	}
	report["text_summary"] = text_summary(report)
	return report


static func _run_case(seed: int, region: Vector2i) -> Dictionary:
	var context = WorldGenerationContext.new(seed)
	var sampler = SurfaceSampler.new(seed)
	var timings_ms: Dictionary = {}

	var started_us: int = Time.get_ticks_usec()
	var macro_stage = MacroRegionGenerator.generate(context, region)
	timings_ms["macro_region"] = _elapsed_ms(started_us)
	if not macro_stage.success:
		return _failure(seed, region, "macro_region", macro_stage.diagnostics)

	started_us = Time.get_ticks_usec()
	var topology_stage = PrimaryTopologyGenerator.generate(context, macro_stage.data, sampler)
	timings_ms["primary_topology"] = _elapsed_ms(started_us)
	if not topology_stage.success:
		return _failure(seed, region, "primary_topology", topology_stage.diagnostics)

	started_us = Time.get_ticks_usec()
	var entrance_stage = EntranceGenerator.generate(
		context,
		macro_stage.data,
		topology_stage.data,
		sampler
	)
	timings_ms["entrance_generation"] = _elapsed_ms(started_us)
	if not entrance_stage.success:
		return _failure(seed, region, "entrance_generation", entrance_stage.diagnostics)

	# Neighbor preparation is deliberately outside the timed connectivity call.
	# The connectivity stage still receives the same four cardinal region views
	# used by the production contracts, so cross-region candidate work is covered.
	var neighbor_views: Array = []
	for offset in Config.neighbor_offsets():
		var neighbor: Dictionary = _build_neighbor(context, sampler, region + offset)
		if not bool(neighbor.get("success", false)):
			return _failure(
				seed,
				region,
				"neighbor_" + str(neighbor.get("stage", "unknown")),
				neighbor.get("diagnostics", [])
			)
		neighbor_views.append({
			"region_plan": neighbor["macro"],
			"primary_topology": neighbor["topology"],
		})

	started_us = Time.get_ticks_usec()
	var connectivity_stage = ConnectivityGenerator.generate(
		context,
		macro_stage.data,
		topology_stage.data,
		entrance_stage.data,
		neighbor_views
	)
	timings_ms["secondary_connectivity"] = _elapsed_ms(started_us)
	if not connectivity_stage.success:
		return _failure(seed, region, "secondary_connectivity", connectivity_stage.diagnostics)

	var topology_bundle = topology_stage.data.bundle
	var connectivity_result = connectivity_stage.data
	var owned_secondary_count: int = connectivity_result.bundle.region_definition.secondary_edge_ids.size()
	var external_secondary_count: int = connectivity_result.external_edge_references.size()
	return {
		"success": true,
		"seed": seed,
		"region": [region.x, region.y],
		"timings_ms": timings_ms,
		"counts": {
			"network_count": topology_bundle.networks.size(),
			"node_count": topology_bundle.nodes.size(),
			"primary_edge_count": topology_bundle.edges.size(),
			"entrance_count": entrance_stage.data.bundle.entrances.size(),
			"owned_secondary_edge_count": owned_secondary_count,
			"external_secondary_reference_count": external_secondary_count,
			"connectivity_count": owned_secondary_count + external_secondary_count,
		},
		"fingerprints": {
			"macro_region": macro_stage.fingerprint,
			"primary_topology": topology_stage.fingerprint,
			"entrance_generation": entrance_stage.fingerprint,
			"secondary_connectivity": connectivity_stage.fingerprint,
		},
	}


static func _build_neighbor(context, sampler, region: Vector2i) -> Dictionary:
	var macro_stage = MacroRegionGenerator.generate(context, region)
	if not macro_stage.success:
		return {
			"success": false,
			"stage": "macro_region",
			"diagnostics": macro_stage.diagnostics,
		}
	var topology_stage = PrimaryTopologyGenerator.generate(context, macro_stage.data, sampler)
	if not topology_stage.success:
		return {
			"success": false,
			"stage": "primary_topology",
			"diagnostics": topology_stage.diagnostics,
		}
	return {
		"success": true,
		"macro": macro_stage.data,
		"topology": topology_stage.data,
		"diagnostics": [],
	}


static func _stage_summaries(cases: Array) -> Dictionary:
	var result: Dictionary = {}
	for stage in STAGES:
		var samples: Array[float] = []
		for case_result in cases:
			samples.append(float(case_result["timings_ms"][stage]))
		result[stage] = _summarize_samples(samples)
	return result


static func _summarize_samples(samples: Array[float]) -> Dictionary:
	var sorted: Array[float] = []
	for value in samples:
		sorted.append(float(value))
	sorted.sort()
	var total: float = 0.0
	for value in sorted:
		total += value
	var count: int = sorted.size()
	var median: float = 0.0
	var p95: float = 0.0
	var minimum: float = 0.0
	var maximum: float = 0.0
	if count > 0:
		minimum = sorted[0]
		maximum = sorted[count - 1]
		var midpoint: int = floori(float(count) / 2.0)
		if count % 2 == 1:
			median = sorted[midpoint]
		else:
			median = (sorted[midpoint - 1] + sorted[midpoint]) * 0.5
		var p95_index: int = clampi(int(ceil(float(count) * 0.95)) - 1, 0, count - 1)
		p95 = sorted[p95_index]
	return {
		"sample_count": count,
		"median_ms": median,
		"p95_ms": p95,
		"min_ms": minimum,
		"max_ms": maximum,
		"total_ms": total,
		"samples_ms": sorted,
	}


static func _count_totals(cases: Array) -> Dictionary:
	var totals := {
		"network_count": 0,
		"node_count": 0,
		"primary_edge_count": 0,
		"entrance_count": 0,
		"owned_secondary_edge_count": 0,
		"external_secondary_reference_count": 0,
		"connectivity_count": 0,
	}
	for case_result in cases:
		for key in totals.keys():
			totals[key] = int(totals[key]) + int(case_result["counts"].get(key, 0))
	return totals


static func text_summary(report: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("Underworld deterministic worldgen benchmark")
	lines.append("corpus=%s cases=%d seeds=%d regions=%d" % [
		str(report.get("corpus_revision", "unknown")),
		int(report.get("case_count", 0)),
		int(report.get("seed_count", 0)),
		int(report.get("region_count", 0)),
	])
	lines.append("timings are diagnostic only; no performance budget is enforced")
	for stage in STAGES:
		var summary: Dictionary = report.get("stages", {}).get(stage, {})
		lines.append("%s: median=%.3f ms p95=%.3f ms min=%.3f ms max=%.3f ms total=%.3f ms" % [
			stage,
			float(summary.get("median_ms", 0.0)),
			float(summary.get("p95_ms", 0.0)),
			float(summary.get("min_ms", 0.0)),
			float(summary.get("max_ms", 0.0)),
			float(summary.get("total_ms", 0.0)),
		])
	var counts: Dictionary = report.get("count_totals", {})
	lines.append("counts: networks=%d nodes=%d primary_edges=%d entrances=%d owned_secondary=%d external_secondary=%d connectivity=%d" % [
		int(counts.get("network_count", 0)),
		int(counts.get("node_count", 0)),
		int(counts.get("primary_edge_count", 0)),
		int(counts.get("entrance_count", 0)),
		int(counts.get("owned_secondary_edge_count", 0)),
		int(counts.get("external_secondary_reference_count", 0)),
		int(counts.get("connectivity_count", 0)),
	])
	return "\n".join(lines) + "\n"


static func _elapsed_ms(started_us: int) -> float:
	return float(Time.get_ticks_usec() - started_us) / 1000.0


static func _failure(seed: int, region: Vector2i, stage: String, diagnostics: Array) -> Dictionary:
	return {
		"success": false,
		"seed": seed,
		"region": [region.x, region.y],
		"stage": stage,
		"diagnostics": diagnostics.duplicate(true),
	}
