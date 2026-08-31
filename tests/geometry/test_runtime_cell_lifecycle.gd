extends RefCounted

const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")
const Streamer := preload("res://worldgen/runtime/underworld_runtime_streamer.gd")
const Result := preload("res://worldgen/runtime/runtime_cell_result.gd")


class ManualExecutor extends RefCounted:
	var requests: Array = []

	func submit(request, tier: String) -> bool:
		requests.append({"request": request, "tier": tier})
		return true


static func run() -> Array[String]:
	var failures: Array[String] = []
	var executor := ManualExecutor.new()
	var streamer := Streamer.new("world:a", "manifest:a", executor)
	var address := Address.new(Vector3i(-2, 3, -4))
	var record = streamer.demand_cell(address, "player", ["definition", "fragment_plan", "voxel_geometry", "render"], "plan:a", "prov:a")
	streamer.pin_entrance(address, "entrance-a", ["collision"], "plan:a", "prov:a")
	_expect(failures, "one owner for composed demand", streamer.active_owner_count() == 1)
	_expect(failures, "independent tier demand observable", record.demand_count("render") == 1 and record.demand_count("collision") == 1)
	_expect(failures, "negative observer cell", streamer.observer_cell(Vector3(-64.1, 96.0, -128.1)) == Vector3i(-3, 3, -5))
	_expect(failures, "frontier queues definition before blocked tiers", _request_count(executor.requests, "definition") == 1 and _request_count(executor.requests, "render") == 0)
	var stale := Result.new(address, record.generation - 1, "render", "plan:a", "prov:a", null)
	_expect(failures, "stale generation rejected", not streamer.accept_result(stale))
	var accepted := Result.new(address, record.generation, "definition", "plan:a", "prov:a", null, true, [], "world:a", "manifest:a")
	_expect(failures, "matching definition accepted", streamer.accept_result(accepted))
	_expect(failures, "definition acceptance exposes fragment frontier", _request_count(executor.requests, "fragment_plan") == 1)
	# Observer movement may legitimately retire the far test cell's geometry tiers;
	# verify the dependency frontier before that movement mutates its lease set.
	streamer.update_observer(Vector3.ZERO)
	_expect(failures, "observer demand uses hysteresis tiers", streamer.active_owner_count() > 0)
	var wrong_source := Result.new(address, record.generation, "render", "plan:old", "prov:a", null, true, [], "world:a", "manifest:a")
	_expect(failures, "mismatched source rejected", not streamer.accept_result(wrong_source))
	streamer.release_demand(address, "player")
	_expect(failures, "entrance pin prevents premature release", record.demand_count("collision") == 1 and streamer.records.has(address.canonical_text()))
	var pre_release_generation: int = record.generation
	streamer.release_entrance(address, "entrance-a")
	_expect(failures, "fully released runtime record is evicted", not streamer.records.has(address.canonical_text()))
	_expect(failures, "release advances historical incarnation token", record.generation > pre_release_generation and record.state == "dormant")
	var old_result := Result.new(address, pre_release_generation, "definition", "plan:a", "prov:a", null, true, [], "world:a", "manifest:a")
	var count_before_stale: int = streamer.records.size()
	_expect(failures, "stale result cannot recreate evicted record", not streamer.accept_result(old_result) and streamer.records.size() == count_before_stale)
	var reincarnated = streamer.demand_cell(address, "debug", ["definition"], "plan:a", "prov:a")
	_expect(failures, "re-entry allocates a non-reused incarnation", reincarnated.generation > record.generation and reincarnated.generation != pre_release_generation)
	_expect(failures, "re-entry preserves canonical bound identity", reincarnated.source_fingerprint == "plan:a" and reincarnated.provenance_fingerprint == "prov:a")
	streamer.reconfigure("world:b", "manifest:b")
	_expect(failures, "reconfigure invalidates readiness", not reincarnated.readiness["definition"])

	var stable := Streamer.new("world:c", "manifest:c")
	var stable_address := Address.new(Vector3i(4, 0, 0))
	var stable_record = stable.demand_cell(stable_address, "player", ["definition"], "plan:one", "prov:one")
	stable.update_observer(Vector3(0.1, 0.1, 0.1), "poll")
	stable.update_observer(Vector3(0.1, 0.1, 0.1), "poll")
	var poll_record = stable.records[Address.new(Vector3i(0, 0, 0)).canonical_text()]
	_expect(failures, "observer polling is idempotent", poll_record.demand_count("definition") == 1)
	var changed_generation: int = stable_record.generation
	stable.demand_cell(stable_address, "player", ["definition"], "plan:two", "prov:two")
	_expect(failures, "source identity change advances generation", stable_record.generation > changed_generation and not stable_record.readiness["definition"])
	var undemanded := Result.new(stable_address, stable_record.generation, "render", "plan:two", "prov:two", null, true, [], "world:c", "manifest:c")
	_expect(failures, "undemanded tier result is rejected", not stable.accept_result(undemanded) and not stable_record.readiness["render"])

	var hysteresis := Streamer.new("world:h", "manifest:h")
	var render_address := Address.new(Vector3i(3, 0, 0))
	hysteresis.update_observer(Vector3(64.1, 0.1, 0.1), "route")
	var render_record = hysteresis.records[render_address.canonical_text()]
	_expect(failures, "render acquired at activation radius", render_record != null and render_record.demand_count("render") == 1)
	hysteresis.update_observer(Vector3(32.1, 0.1, 0.1), "route")
	_expect(failures, "render retained at release-only distance", render_record.demand_count("render") == 1)
	hysteresis.update_observer(Vector3(0.1, 0.1, 0.1), "route")
	_expect(failures, "render released beyond release radius", render_record.demand_count("render") == 0)
	var geometry_address := Address.new(Vector3i(4, 0, 0))
	hysteresis.update_observer(Vector3(64.1, 0.1, 0.1), "geometry-route")
	var geometry_record = hysteresis.records[geometry_address.canonical_text()]
	_expect(failures, "geometry acquired at activation radius", geometry_record != null and geometry_record.demand_count("voxel_geometry") == 1)
	hysteresis.update_observer(Vector3(32.1, 0.1, 0.1), "geometry-route")
	_expect(failures, "geometry retained at release-only distance", geometry_record.demand_count("voxel_geometry") == 1)
	hysteresis.update_observer(Vector3(64.1, 0.1, 0.1), "geometry-route")
	_expect(failures, "rapid geometry reversal retains demand", geometry_record.demand_count("voxel_geometry") == 1)
	hysteresis.update_observer(Vector3(0.1, 0.1, 0.1), "geometry-route")
	_expect(failures, "geometry released beyond release radius", geometry_record.demand_count("voxel_geometry") == 0)
	_expect(failures, "unbound observer demand does not queue work", hysteresis.queued_count == 0)

	var bound_executor := ManualExecutor.new()
	var bound_streamer := Streamer.new("world:bound", "manifest:bound", bound_executor)
	var bound_address := Address.new(Vector3i.ZERO)
	bound_streamer.update_observer(Vector3.ZERO, "observer")
	_expect(failures, "observer-only demand has no queued job", bound_executor.requests.is_empty())
	var bound_record = bound_streamer.set_demand(bound_address, "observer", ["definition"], "source:accepted", "provenance:accepted")
	_expect(failures, "binding identity queues authoritative job", bound_executor.requests.size() == 1)
	if bound_executor.requests.size() == 1:
		var queued_request = bound_executor.requests[0].request
		_expect(failures, "queued request carries bound source", queued_request.source_fingerprint == "source:accepted" and queued_request.provenance_fingerprint == "provenance:accepted")
	var bound_result := Result.new(bound_address, bound_record.generation, "definition", "source:accepted", "provenance:accepted", null, true, [], "world:bound", "manifest:bound")
	_expect(failures, "matching bound result accepted", bound_streamer.accept_result(bound_result))
	var wrong_bound_result := Result.new(bound_address, bound_record.generation, "render", "source:wrong", "provenance:accepted", null, true, [], "world:bound", "manifest:bound")
	_expect(failures, "wrong bound identity rejected", not bound_streamer.accept_result(wrong_bound_result))

	var retirement_executor := ManualExecutor.new()
	var retirement_streamer := Streamer.new("world:retire", "manifest:retire", retirement_executor)
	var retirement_address := Address.new(Vector3i(7, 0, 0))
	var retirement_record = retirement_streamer.set_demand(
		retirement_address,
		"route",
		["definition", "fragment_plan", "voxel_geometry", "render"],
		"source:retire",
		"provenance:retire"
	)
	_expect(failures, "frontier keeps render out of initial backlog", _request_count(retirement_executor.requests, "render") == 0)
	var definition_result := Result.new(retirement_address, retirement_record.generation, "definition", "source:retire", "provenance:retire", null, true, [], "world:retire", "manifest:retire")
	retirement_streamer.accept_result(definition_result)
	var fragment_result := Result.new(retirement_address, retirement_record.generation, "fragment_plan", "source:retire", "provenance:retire", null, true, [], "world:retire", "manifest:retire")
	retirement_streamer.accept_result(fragment_result)
	var voxel_result := Result.new(retirement_address, retirement_record.generation, "voxel_geometry", "source:retire", "provenance:retire", null, true, [], "world:retire", "manifest:retire")
	retirement_streamer.accept_result(voxel_result)
	_expect(failures, "voxel readiness exposes render frontier", _request_count(retirement_executor.requests, "render") == 1)
	var pre_retire_generation: int = retirement_record.generation
	retirement_streamer.release_demand(retirement_address, "route", ["render"])
	_expect(failures, "retiring queued render advances generation", retirement_record.generation > pre_retire_generation and retirement_record.demand_count("render") == 0)
	var stale_retired_render := Result.new(retirement_address, pre_retire_generation, "render", "source:retire", "provenance:retire", null, true, [], "world:retire", "manifest:retire")
	_expect(failures, "retired generation cannot resurrect after renewal", not retirement_streamer.accept_result(stale_retired_render))

	# SCALE-001 regression: records is current relevance, not explored history.
	var traversal := Streamer.new("world:scale", "manifest:scale")
	var count_after_short_route: int = 0
	var max_record_count: int = 0
	var max_scan_count: int = 0
	for step in range(200):
		traversal.update_observer(Vector3(float(step * 32) + 0.25, 0.25, 0.25), "walker")
		max_record_count = maxi(max_record_count, traversal.records.size())
		max_scan_count = maxi(max_scan_count, traversal.last_observer_record_scan_count)
		if step == 19:
			count_after_short_route = traversal.records.size()
	var count_after_long_route: int = traversal.records.size()
	_expect(failures, "long exploration record table plateaus", max_record_count <= 800 and count_after_long_route <= 800)
	_expect(failures, "ordinary observer scan is bounded by current relevance", max_scan_count <= 800)
	_expect(failures, "record residency does not grow with visited distance", abs(count_after_long_route - count_after_short_route) <= 100)
	_expect(failures, "early traversal cells are evicted", not traversal.records.has(Address.new(Vector3i(0, 0, 0)).canonical_text()))

	var incarnation_executor := ManualExecutor.new()
	var incarnations := Streamer.new("world:incarnation", "manifest:incarnation", incarnation_executor)
	var incarnation_address := Address.new(Vector3i(-9, -2, 11))
	var first = incarnations.set_demand(incarnation_address, "walker", ["definition"], "source:same", "prov:same")
	var first_generation: int = first.generation
	var delayed := Result.new(incarnation_address, first_generation, "definition", "source:same", "prov:same", null, true, [], "world:incarnation", "manifest:incarnation")
	incarnations.release_demand(incarnation_address, "walker")
	_expect(failures, "released incarnation is erased", not incarnations.records.has(incarnation_address.canonical_text()))
	var before_late_result: int = incarnations.records.size()
	_expect(failures, "late result for evicted incarnation is rejected without resurrection", not incarnations.accept_result(delayed) and incarnations.records.size() == before_late_result)
	var second = incarnations.set_demand(incarnation_address, "walker", ["definition"], "source:same", "prov:same")
	_expect(failures, "re-entry reproduces canonical identity", second.source_fingerprint == first.source_fingerprint and second.provenance_fingerprint == first.provenance_fingerprint)
	_expect(failures, "re-entry uses a new opaque generation token", second.generation > first_generation)
	_expect(failures, "old delayed result cannot mutate new incarnation", not incarnations.accept_result(delayed) and not bool(second.readiness.get("definition", false)))
	return failures


static func _request_count(requests: Array, tier: String) -> int:
	var count := 0
	for entry in requests:
		if str(entry.get("tier", "")) == tier:
			count += 1
	return count


static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
