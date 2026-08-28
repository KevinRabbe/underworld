extends RefCounted
class_name UnderworldRuntimeValidationHarness

const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")
const Streamer := preload("res://worldgen/runtime/underworld_runtime_streamer.gd")
const Result := preload("res://worldgen/runtime/runtime_cell_result.gd")
const Gate := preload("res://worldgen/runtime/entrance_traversal_gate.gd")


class ManualExecutor extends RefCounted:
	var requests: Array = []
	var queued: int = 0

	func submit(request, tier: String) -> void:
		requests.append({"request": request, "tier": tier})
		queued += 1

	func take_reversed() -> Array:
		var result := requests.duplicate()
		result.reverse()
		requests.clear()
		return result


class Report extends RefCounted:
	var counters: Dictionary = {
		"demanded": 0,
		"queued": 0,
		"ready": 0,
		"attached": 0,
		"stale_discarded": 0,
		"released": 0,
	}
	var fingerprint: String = ""
	var failures: Array[String] = []


static func run() -> Report:
	var report := Report.new()
	var executor := ManualExecutor.new()
	var streamer := Streamer.new("world:map014", "manifest:map014", executor)
	var cells: Array = [
		Address.new(Vector3i(-1, 0, -1)),
		Address.new(Vector3i(0, 0, -1)),
		Address.new(Vector3i(0, 0, 0)),
		Address.new(Vector3i(1, 0, 0)),
	]
	var source := "fixture:map014"
	var provenance := "provenance:map014"
	for address in cells:
		streamer.demand_cell(address, "fixture", ["definition", "fragment_plan", "voxel_geometry", "render", "collision"], source, provenance)
		report.counters["demanded"] += 1
	report.counters["demanded"] += 0
	report.counters["queued"] = executor.queued
	_expect(report, "one owner per fixture cell", streamer.active_owner_count() == cells.size())

	# Simulate a positive route and a negative-coordinate route without scene queries.
	streamer.update_observer(Vector3(0.25, 0.25, 0.25), "route-positive")
	streamer.update_observer(Vector3(-32.25, 0.25, -32.25), "route-negative")
	_expect(report, "negative observer coordinate is addressed", streamer.observer_cell(Vector3(-32.25, 0.25, -32.25)) == Vector3i(-2, 0, -2))

	var gate := Gate.new("entrance:fixture", [cells[2], cells[3]])
	_expect(report, "gate starts closed", not gate.update(streamer))

	# Deliberately complete requests in reverse order. The first generation result is stale.
	var reversed_requests := executor.take_reversed()
	for item in reversed_requests:
		var request = item["request"]
		var tier: String = item["tier"]
		var result := Result.new(request.cell_address, request.generation, tier, source, provenance, null, true, [], "world:map014", "manifest:map014")
		if streamer.accept_result(result):
			report.counters["ready"] += 1
			if tier == "render":
				report.counters["attached"] += 1
	_expect(report, "gate opens only after collision readiness", gate.update(streamer))
	var stale := Result.new(cells[2], streamer.records[cells[2].canonical_text()].generation - 1, "collision", source, provenance, null, true, [], "world:map014", "manifest:map014")
	_expect(report, "stale completion is rejected", not streamer.accept_result(stale))
	report.counters["stale_discarded"] = streamer.stale_result_count

	for address in cells:
		streamer.release_demand(address, "fixture")
		streamer.release_demand(address, "route-positive")
		streamer.release_demand(address, "route-negative")
		streamer.release_cell(address)
		report.counters["released"] = streamer.released_count
	# Drain observer-route leases as well; this models a complete backtrack/unload.
	for record in streamer.records.values():
		for source_name in record.demands.keys():
			streamer.release_demand(record.cell_address, str(source_name))
		if record.demands.is_empty():
			streamer.release_cell(record.cell_address)
	report.counters["released"] = streamer.released_count
	gate.close()
	_expect(report, "all fixture cells release", streamer.active_owner_count() == 0)
	report.fingerprint = _fingerprint(report.counters)
	return report


static func _fingerprint(counters: Dictionary) -> String:
	var CanonicalValue = preload("res://worldgen/validation/canonical_value.gd")
	return "runtime-harness1:" + CanonicalValue.fingerprint(counters)


static func _expect(report: Report, label: String, condition: bool) -> void:
	if not condition:
		report.failures.append(label)
