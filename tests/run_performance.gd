extends SceneTree

const PerformanceContractTests := preload("res://tests/geometry/test_runtime_performance_contract.gd")
const Profiler := preload("res://worldgen/runtime/runtime_cave_profiler.gd")


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
	_finish(failures)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("[PERF-001] PASS")
		quit(0)
		return
	printerr("[PERF-001] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
