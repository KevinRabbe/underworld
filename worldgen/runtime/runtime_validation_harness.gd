extends RefCounted
class_name UnderworldRuntimeValidationHarness

const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")
const Streamer := preload("res://worldgen/runtime/underworld_runtime_streamer.gd")
const Result := preload("res://worldgen/runtime/runtime_cell_result.gd")
const Gate := preload("res://worldgen/runtime/entrance_traversal_gate.gd")
const Descriptor := preload("res://worldgen/graph/surface_entrance_integration_descriptor.gd")
const SurfacePlan := preload("res://worldgen/surface/surface_entrance_chunk_plan.gd")
const Demand := preload("res://worldgen/surface/entrance_runtime_demand.gd")
const MeshData := preload("res://worldgen/geometry/cave_mesh_data.gd")
const CollisionBuilder := preload("res://worldgen/runtime/cave_collision_builder.gd")
const CollisionBoundary := preload("res://worldgen/runtime/cave_collision_realization_boundary.gd")

class ManualExecutor extends RefCounted:
	var requests: Array = []
	var queued: int = 0
	func submit(request, tier: String) -> void:
		requests.append({"request": request, "tier": tier})
		queued += 1
	func take_reversed() -> Array:
		var result := requests.duplicate(); result.reverse(); requests.clear(); return result

class Report extends RefCounted:
	var counters: Dictionary = {"demanded": 0, "queued": 0, "ready": 0, "attached": 0, "stale_discarded": 0, "released": 0}
	var fingerprint: String = ""
	var failures: Array[String] = []
	var events: Array[String] = []

static func run() -> Report:
	var report := Report.new()
	var executor := ManualExecutor.new()
	var streamer := Streamer.new("world:map014", "manifest:map014", executor)
	streamer.definition_activate_radius = 0; streamer.definition_release_radius = 1
	streamer.geometry_activate_radius = 0; streamer.geometry_release_radius = 1
	streamer.render_activate_radius = 0; streamer.render_release_radius = 1
	streamer.collision_activate_radius = 0; streamer.collision_release_radius = 1
	var source := "fixture:map014:A"; var provenance := "provenance:map014:A"
	var descriptor := Descriptor.new("entrance:fixture", "region:map014", Vector3(8, 8, 8), Vector3(0, -1, 0), AABB(Vector3(7, 7, 7), Vector3(2, 2, 2)), 1.0, "network:fixture", "node:fixture", Vector3(40, -8, 8), "gradual")
	var plan_result = SurfacePlan.build(AABB(Vector3.ZERO, Vector3(64, 32, 64)), [descriptor], Vector2i(8, 8), provenance)
	_expect(report, "surface plan succeeds", bool(plan_result.get("success", false)))
	var plan = plan_result.get("data"); var handoff: Demand = plan.demand_handoffs[0]; var cells: Array = handoff.cell_addresses
	_expect(report, "surface handoff has destination cells", cells.size() >= 2)
	var gate := Gate.new(handoff.entrance_id, cells)
	for address in cells:
		streamer.demand_cell(address, "fixture", ["definition", "fragment_plan", "voxel_geometry", "render", "collision"], source, provenance)
		report.counters["demanded"] += 1; report.events.append("demand|" + address.canonical_text() + "|" + str(streamer.records[address.canonical_text()].generation))
	streamer.update_observer(Vector3(0.25, 0.25, 0.25), "route")
	var repeated_count: int = streamer.records[Address.new(Vector3i(0, 0, 0)).canonical_text()].demand_count("definition")
	streamer.update_observer(Vector3(0.25, 0.25, 0.25), "route")
	_expect(report, "repeated observer polling does not accumulate leases", streamer.records[Address.new(Vector3i(0, 0, 0)).canonical_text()].demand_count("definition") == repeated_count)
	streamer.update_observer(Vector3(64.25, 0.25, 64.25), "route")
	_expect(report, "negative observer coordinate is addressed", streamer.observer_cell(Vector3(-32.25, 0.25, -32.25)) == Vector3i(-2, 0, -2))
	_expect(report, "gate starts closed", not gate.update(streamer)); report.counters["queued"] = executor.queued
	var mesh := MeshData.new(cells[0], AABB(Vector3.ZERO, Vector3.ONE), PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD]), PackedInt32Array([0, 1, 2]), PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP]), PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN]), ["descriptor:fixture"], [], "mesh-input:map014")
	var collision_stage = CollisionBuilder.prepare(mesh, provenance); var realized := CollisionBoundary.realize_main_thread(collision_stage.data, mesh.output_fingerprint); var collision_payload = realized.shape if realized.success else null
	for item in executor.take_reversed():
		var request = item["request"]; var tier: String = item["tier"]; var payload = collision_payload if tier == "collision" else {"tier": tier, "event": "ready"}
		var result := Result.new(request.cell_address, request.generation, tier, source, provenance, payload, true, [], "world:map014", "manifest:map014")
		if streamer.accept_result(result):
			report.counters["ready"] += 1; report.events.append("ready|" + request.cell_address.canonical_text() + "|" + tier + "|" + str(request.generation)); if tier == "render": report.counters["attached"] += 1
	_expect(report, "gate opens only after realized collision readiness", gate.update(streamer))
	var stale := Result.new(cells[0], streamer.records[cells[0].canonical_text()].generation - 1, "collision", source, provenance, collision_payload, true, [], "world:map014", "manifest:map014")
	_expect(report, "stale completion is rejected", not streamer.accept_result(stale))
	var undemanded := Result.new(cells[0], streamer.records[cells[0].canonical_text()].generation, "simulation", source, provenance, {"sim": true}, true, [], "world:map014", "manifest:map014")
	_expect(report, "undemanded tier is rejected", not streamer.accept_result(undemanded))
	var old_generation: int = streamer.records[cells[0].canonical_text()].generation
	streamer.set_demand(cells[0], "fixture", ["collision"], "fixture:map014:B", "provenance:map014:B")
	_expect(report, "source change clears collision readiness", not streamer.records[cells[0].canonical_text()].readiness["collision"] and streamer.records[cells[0].canonical_text()].collision_handle == null)
	var old_result := Result.new(cells[0], old_generation, "collision", source, provenance, collision_payload, true, [], "world:map014", "manifest:map014")
	_expect(report, "old source completion is rejected", not streamer.accept_result(old_result)); report.counters["stale_discarded"] = streamer.stale_result_count
	for address in cells:
		streamer.release_demand(address, "fixture")
		streamer.set_demand(address, "route", [])
		streamer.release_cell(address)
	report.counters["released"] = streamer.released_count
	var fixture_released := true
	for address in cells:
		var fixture_record = streamer.records.get(address.canonical_text())
		fixture_released = fixture_released and fixture_record != null and fixture_record.demands.is_empty() and fixture_record.state == "dormant"
	_expect(report, "fixture cells release after normal demand transition", fixture_released)
	var movement := Streamer.new("world:movement", "manifest:movement")
	movement.collision_activate_radius = 1
	movement.collision_release_radius = 2
	var next_cell := Address.new(Vector3i(1, 0, 0))
	movement.update_observer(Vector3(0.25, 0.25, 0.25), "movement")
	var next_record = movement.records.get(next_cell.canonical_text())
	_expect(report, "normal observer prefetches next-cell collision", next_record != null and next_record.demand_count("collision") == 1)
	movement.update_observer(Vector3(32.25, 0.25, 0.25), "movement")
	_expect(report, "normal movement keeps destination collision demanded", next_record.demand_count("collision") == 1)
	report.events.append("movement-collision|" + str(next_record.demand_count("collision")))
	report.events.append("gate|" + str(gate.is_open())); report.fingerprint = _fingerprint({"counters": report.counters, "events": report.events}); return report

static func _fingerprint(value: Dictionary) -> String:
	var CanonicalValue = preload("res://worldgen/validation/canonical_value.gd"); return "runtime-harness2:" + CanonicalValue.fingerprint(value)

static func _expect(report: Report, label: String, condition: bool) -> void:
	if not condition: report.failures.append(label)
