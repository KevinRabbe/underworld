extends RefCounted

const Descriptor := preload("res://worldgen/graph/surface_entrance_integration_descriptor.gd")
const Plan := preload("res://worldgen/surface/surface_entrance_chunk_plan.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var descriptor := Descriptor.new(
		"entrance:test", "region:test", Vector3(-2, 8, -2), Vector3(0, -1, 0),
		AABB(Vector3(-6, 0, -6), Vector3(8, 4, 8)), 1.0, "network:test", "node:test",
		Vector3(-2, -8, -2), "gradual"
	)
	var chunk_a := AABB(Vector3(-16, 0, -16), Vector3(16, 32, 16))
	var chunk_b := AABB(Vector3(0, 0, -16), Vector3(16, 32, 16))
	var first = Plan.build(chunk_a, [descriptor], Vector2i(8, 8), "prov:test")
	var reordered = Plan.build(chunk_a, [descriptor], Vector2i(8, 8), "prov:test")
	_expect(failures, "single chunk entrance plan succeeds", first.success)
	if first.success:
		_expect(failures, "opening mask is non-empty", true in first.data.opening_mask)
		_expect(failures, "immediate underground cell is identified", first.data.underground_cells.size() == 1)
		_expect(failures, "plan reproduces after reload", first.fingerprint == reordered.fingerprint)
	var cross_a = Plan.build(chunk_b, [descriptor], Vector2i(8, 8), "prov:test")
	_expect(failures, "boundary chunk plan succeeds", cross_a.success)
	if cross_a.success:
		var reverse = Plan.build(chunk_b, [descriptor], Vector2i(8, 8), "prov:test")
		_expect(failures, "boundary plan is order independent", cross_a.fingerprint == reverse.fingerprint)
	return failures


static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
