extends RefCounted

const Harness := preload("res://worldgen/runtime/runtime_validation_harness.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var first = Harness.run()
	var second = Harness.run()
	for failure in first.failures:
		failures.append(failure)
	_expect(failures, "harness fingerprint reproduces", first.fingerprint == second.fingerprint)
	_expect(failures, "harness reports queued work", int(first.counters["queued"]) > 0)
	_expect(failures, "harness reports accepted readiness", int(first.counters["ready"]) > 0)
	_expect(failures, "harness reports stale discard", int(first.counters["stale_discarded"]) >= 3)
	_expect(failures, "harness reports releases", int(first.counters["released"]) >= 2)
	return failures


static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
