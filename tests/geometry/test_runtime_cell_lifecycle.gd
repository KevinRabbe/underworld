extends RefCounted

const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")
const Streamer := preload("res://worldgen/runtime/underworld_runtime_streamer.gd")
const Result := preload("res://worldgen/runtime/runtime_cell_result.gd")


class ManualExecutor extends RefCounted:
	var requests: Array = []

	func submit(request, tier: String) -> void:
		requests.append({"request": request, "tier": tier})


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
	streamer.update_observer(Vector3.ZERO)
	_expect(failures, "observer demand uses hysteresis tiers", streamer.active_owner_count() > 0)
	var stale := Result.new(address, record.generation - 1, "render", "plan:a", "prov:a", null)
	_expect(failures, "stale generation rejected", not streamer.accept_result(stale))
	var accepted := Result.new(address, record.generation, "definition", "plan:a", "prov:a", null, true, [], "world:a", "manifest:a")
	_expect(failures, "matching definition accepted", streamer.accept_result(accepted))
	var wrong_source := Result.new(address, record.generation, "render", "plan:old", "prov:a", null, true, [], "world:a", "manifest:a")
	_expect(failures, "mismatched source rejected", not streamer.accept_result(wrong_source))
	streamer.release_demand(address, "player")
	_expect(failures, "entrance pin prevents premature release", record.demand_count("collision") == 1 and record.state != "dormant")
	streamer.release_entrance(address, "entrance-a")
	_expect(failures, "release reaches dormant", record.state == "release_pending")
	var old_generation: int = record.generation
	streamer.release_cell(address)
	_expect(failures, "release advances generation", record.generation > old_generation and record.state == "dormant")
	streamer.demand_cell(address, "debug", ["definition"], "plan:b", "prov:b")
	_expect(failures, "re-request creates newer generation", record.generation > old_generation)
	var old_result := Result.new(address, old_generation, "definition", "plan:a", "prov:a", null)
	_expect(failures, "stale result cannot resurrect", not streamer.accept_result(old_result))
	streamer.reconfigure("world:b", "manifest:b")
	_expect(failures, "reconfigure invalidates readiness", not record.readiness["definition"])
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
	return failures


static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
