extends RefCounted
class_name UnderworldRuntimePerformanceBudget

## PERF-001 prototype warning budgets.
##
## These are observational thresholds, not deterministic generation inputs and
## not hard correctness gates. PERF-002 may revise them only from measured
## evidence. Timing thresholds intentionally remain outside fingerprints.
const REVISION: int = 3
const MIB: int = 1024 * 1024

const DEFAULT_THRESHOLDS: Dictionary = {
	"controller_bootstrap_ms": 2000.0,
	"deterministic_generation_ms": 500.0,
	"surface_partition_ms": 150.0,
	"mesh_extraction_total_ms": 1200.0,
	"mesh_extraction_cell_max_ms": 250.0,
	"mesh_realization_cell_max_ms": 8.0,
	"collision_prepare_cell_max_ms": 8.0,
	"collision_realization_cell_max_ms": 8.0,
	"observer_update_max_ms": 4.0,
	"mesh_memory_total_bytes": 256 * MIB,
	"mesh_memory_cell_max_bytes": 8 * MIB,
	# Streaming uses hysteresis. Budget logical residency against the accepted
	# release envelopes, not the smaller activation cubes: geometry release=3
	# -> 7^3=343; render/collision release=2 -> 5^3=125.
	"resident_geometry_cells": 343,
	"resident_render_cells": 125,
	"resident_collision_cells": 125,
}


static func default_thresholds() -> Dictionary:
	return DEFAULT_THRESHOLDS.duplicate(true)


static func evaluate(metrics: Dictionary, thresholds: Dictionary = {}) -> Array[String]:
	var limits := default_thresholds()
	for key in thresholds.keys():
		limits[key] = thresholds[key]
	var warnings: Array[String] = []
	for key in limits.keys():
		if not metrics.has(key):
			continue
		var value = metrics[key]
		var limit = limits[key]
		var value_type := typeof(value)
		var limit_type := typeof(limit)
		var value_numeric := value_type == TYPE_INT or value_type == TYPE_FLOAT
		var limit_numeric := limit_type == TYPE_INT or limit_type == TYPE_FLOAT
		if value_numeric and limit_numeric and float(value) > float(limit):
			warnings.append(
				"%s exceeded prototype warning budget: value=%s limit=%s" % [
					str(key),
					str(value),
					str(limit),
				]
			)
	warnings.sort()
	return warnings


static func descriptor() -> Dictionary:
	return {
		"revision": REVISION,
		"policy": "warning_only",
		"thresholds": default_thresholds(),
		"timings_affect_determinism": false,
		"measurement_semantics": {
			"mesh_extraction": "synchronous staged VoxelMesher.build extraction cost; worker-eligible CPU/wall work only; excludes production executor queueing, worker scheduling, contention, and handoff latency",
			"staged_processing_total_ms": "mesh extraction plus collision-face preparation in the synchronous profiling path; not production worker-thread latency",
			"controller_route_observer_update": "demand/gate update cost only; bootstrap_fixture pre-realizes the fixture and update_player_position does not dynamically realize newly demanded cave cells",
		},
	}
