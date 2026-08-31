extends SceneTree

const PerformanceContractTests := preload("res://tests/geometry/test_runtime_performance_contract.gd")
const Profiler := preload("res://worldgen/runtime/runtime_cave_profiler.gd")
const ProductionTransitionProfiler := preload("res://worldgen/runtime/production_cave_transition_profiler.gd")

const PRODUCTION_SEEDS: Array[int] = [12345, 1]


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(PerformanceContractTests.run())
	if not failures.is_empty():
		_finish(failures)
		return

	var report = Profiler.run_map015()
	print("[PERF-001 PROFILE]")
	print("  fixture=seed:1 region:(0,-1) entrance-slot:2")
	print("  deterministic_fingerprint=%s" % report.deterministic_fingerprint)
	print("  budget=%s" % report.budget)
	var metric_keys: Array = report.metrics.keys()
	metric_keys.sort()
	for key in metric_keys:
		print("  metric.%s=%s" % [str(key), str(report.metrics[key])])
	for scenario in report.scenarios:
		print("  scenario=%s" % scenario)
	for warning in report.warnings:
		print("  [PERF WARNING] %s" % warning)
	for failure in report.failures:
		failures.append(str(failure))

	for world_seed in PRODUCTION_SEEDS:
		var production: Dictionary = ProductionTransitionProfiler.run(world_seed)
		_print_production_profile(world_seed, production)
		for failure in production.get("failures", []):
			failures.append("PERF-003 seed %d: %s" % [world_seed, str(failure)])
		if bool(production.get("success", false)):
			print("[PERF-003] PASS seed=%d" % world_seed)
	if failures.is_empty():
		print("[PERF-003] PASS")
	_finish(failures)


func _print_production_profile(world_seed: int, production: Dictionary) -> void:
	print("[PERF-003 PRODUCTION PROFILE]")
	var route: Dictionary = production.get("route", {})
	print("  seed=%d" % world_seed)
	print("  route.entrance_id=%s" % str(route.get("entrance_id", "")))
	print("  route.region_coord=%s" % str(route.get("region_coord", Vector2i.ZERO)))
	print("  route.selection_fingerprint=%s" % str(route.get("selection_fingerprint", "")))
	print("  budget_state=%s" % str(production.get("budget_state", "")))
	print("  measurement_semantics=%s" % production.get("measurement_semantics", {}))
	var production_metrics: Dictionary = production.get("metrics", {})
	var production_metric_keys: Array = production_metrics.keys()
	production_metric_keys.sort()
	for key in production_metric_keys:
		print("  metric.%s=%s" % [str(key), str(production_metrics[key])])
	for scenario in production.get("scenarios", []):
		print("  scenario=%s" % scenario)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("[PERF-001] PASS")
		quit(0)
		return
	printerr("[PERF-001] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
