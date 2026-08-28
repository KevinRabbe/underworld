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
	var accepted := Result.new(address, record.generation, "definition", "plan:a", "prov:a", null)
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
	return failures


static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
