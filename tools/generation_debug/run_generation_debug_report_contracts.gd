extends SceneTree

const Report := preload("res://tools/generation_debug/generation_debug_report.gd")
const ReportBuilder := preload("res://tools/generation_debug/generation_debug_report_builder.gd")
const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const StageResult := preload("res://worldgen/pipeline/generation_stage_result.gd")


func _init() -> void:
	var failures: Array[String] = []
	_test_success_report(failures)
	_test_exact_reproduction(failures)
	_test_failure_and_retry_capture(failures)
	_test_negative_coordinates(failures)
	_finish(failures)


static func _test_success_report(failures: Array[String]) -> void:
	var built: Dictionary = ReportBuilder.build(12345, Vector2i.ZERO)
	_expect_true(failures, "debug report builds", bool(built.get("success", false)))
	var report: Dictionary = built.get("report", {})
	_expect_equal(failures, "report schema", report.get("schema", ""), "underworld-generation-debug-report-v1")
	_expect_equal(failures, "seed preserved", int(report.get("world_seed", 0)), 12345)
	_expect_equal(failures, "region preserved", report.get("region_coord", []), [0, 0])
	_expect_equal(failures, "merged stage count", report.get("stages", []).size(), 2)
	if report.get("stages", []).size() == 2:
		_expect_equal(failures, "macro stage first", report["stages"][0]["stage"], "macro_region")
		_expect_equal(failures, "topology stage second", report["stages"][1]["stage"], "primary_topology")
		_expect_true(failures, "macro fingerprint captured", not str(report["stages"][0]["fingerprint"]).is_empty())
		_expect_true(failures, "topology fingerprint captured", not str(report["stages"][1]["fingerprint"]).is_empty())
		_expect_true(failures, "topology metrics captured", not report["stages"][1]["parameters"].is_empty())
	_expect_equal(failures, "successful run has zero retries", int(report.get("total_retries", -1)), 0)
	_expect_equal(failures, "successful run has no failure stage", str(report.get("failure_stage", "missing")), "")
	_expect_true(failures, "global parameters captured", report.get("parameters", {}).has("macro_region_size"))
	_expect_true(failures, "JSON output names schema", str(built.get("json", "")).contains("underworld-generation-debug-report-v1"))
	_expect_true(failures, "text output names stages", str(built.get("text", "")).contains("primary_topology"))


static func _test_exact_reproduction(failures: Array[String]) -> void:
	var first: Dictionary = ReportBuilder.build(808080, Vector2i(3, -2))
	var second: Dictionary = ReportBuilder.build(808080, Vector2i(3, -2))
	_expect_equal(failures, "debug JSON reproduces exactly", first.get("json", ""), second.get("json", ""))
	_expect_equal(failures, "debug text reproduces exactly", first.get("text", ""), second.get("text", ""))


static func _test_failure_and_retry_capture(failures: Array[String]) -> void:
	var context = WorldGenerationContext.new(77)
	var report = Report.new(context, Vector2i(4, 5), {"test_parameter": 9})
	report.record_stage(StageResult.ok("stage_a", null, "fingerprint-a"), 1, {"attempt_limit": 3})
	report.record_stage(StageResult.fail("stage_b", ["synthetic failure"]), 2, {"attempt_limit": 3})
	var data: Dictionary = report.to_dictionary()
	_expect_true(failures, "synthetic report fails", not bool(data.get("success", true)))
	_expect_equal(failures, "first failing stage captured", str(data.get("failure_stage", "")), "stage_b")
	_expect_equal(failures, "retries aggregate", int(data.get("total_retries", 0)), 3)
	_expect_equal(failures, "per-stage retry captured", int(data["stages"][1]["retry_count"]), 2)
	_expect_equal(failures, "failure diagnostic captured", data["stages"][1]["diagnostics"], ["synthetic failure"])
	_expect_equal(failures, "stage parameter captured", int(data["stages"][1]["parameters"]["attempt_limit"]), 3)
	_expect_true(failures, "human report includes diagnostic", report.to_text().contains("diagnostic=synthetic failure"))


static func _test_negative_coordinates(failures: Array[String]) -> void:
	var built: Dictionary = ReportBuilder.build(-998877, Vector2i(-5, -4))
	_expect_true(failures, "negative coordinate report builds", bool(built.get("success", false)))
	var report: Dictionary = built.get("report", {})
	_expect_equal(failures, "negative seed preserved", int(report.get("world_seed", 0)), -998877)
	_expect_equal(failures, "negative region preserved", report.get("region_coord", []), [-5, -4])


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s expected=%s actual=%s" % [label, str(expected), str(actual)])


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("[GENERATION DEBUG CONTRACTS] PASS")
		quit(0)
		return
	printerr("[GENERATION DEBUG CONTRACTS] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
