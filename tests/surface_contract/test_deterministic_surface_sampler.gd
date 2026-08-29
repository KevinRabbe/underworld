extends RefCounted

const SurfaceSampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const SurfaceSettings := preload("res://worldgen/surface/prototype_surface_settings.gd")

const EPSILON: float = 0.000001


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_repeated_samples_are_identical(failures)
	_test_neighbor_order_independence(failures)
	_test_negative_coordinates(failures)
	_test_chunk_boundary_samples(failures)
	_test_sample_invariants(failures)
	_test_pure_data_base_type(failures)
	return failures


static func _test_repeated_samples_are_identical(failures: Array[String]) -> void:
	var sampler = SurfaceSampler.new(123456789)
	var positions: Array[Vector2] = [
		Vector2(0.0, 0.0),
		Vector2(17.25, 93.75),
		Vector2(-41.5, 28.125),
		Vector2(2048.75, -4096.5),
	]
	for position in positions:
		var first = sampler.sample(position.x, position.y)
		var second = sampler.sample(position.x, position.y)
		_expect_equal(
			failures,
			"repeated sample is identical at %s" % str(position),
			first.canonical_data(),
			second.canonical_data()
		)

	var second_sampler = SurfaceSampler.new(123456789)
	for position in positions:
		_expect_equal(
			failures,
			"same seed reproduces sample at %s" % str(position),
			sampler.sample(position.x, position.y).canonical_data(),
			second_sampler.sample(position.x, position.y).canonical_data()
		)


static func _test_neighbor_order_independence(failures: Array[String]) -> void:
	var positions: Array[Vector2] = [
		Vector2(-2.0, -2.0),
		Vector2(0.0, 0.0),
		Vector2(2.0, 0.0),
		Vector2(0.0, 2.0),
		Vector2(130.0, 126.0),
	]
	var forward_sampler = SurfaceSampler.new(-987654321)
	var reverse_sampler = SurfaceSampler.new(-987654321)
	var forward: Dictionary = {}
	var reverse: Dictionary = {}

	for position in positions:
		forward[_position_key(position)] = forward_sampler.sample(position.x, position.y).canonical_data()

	var reversed_positions: Array[Vector2] = positions.duplicate()
	reversed_positions.reverse()
	for position in reversed_positions:
		reverse[_position_key(position)] = reverse_sampler.sample(position.x, position.y).canonical_data()

	for position in positions:
		var key: String = _position_key(position)
		_expect_equal(
			failures,
			"neighbor query order does not affect %s" % key,
			forward.get(key),
			reverse.get(key)
		)


static func _test_negative_coordinates(failures: Array[String]) -> void:
	var sampler = SurfaceSampler.new(424242)
	var positions: Array[Vector2] = [
		Vector2(-0.001, -0.001),
		Vector2(-128.0, -128.0),
		Vector2(-1024.5, -2048.25),
		Vector2(-32768.75, 8192.125),
	]
	for position in positions:
		var sample = sampler.sample(position.x, position.y)
		_validate_sample(failures, "negative-coordinate %s" % str(position), sample, position)


static func _test_chunk_boundary_samples(failures: Array[String]) -> void:
	var settings = SurfaceSettings.new()
	var chunk_size: float = settings.chunk_size
	var offset: float = 0.001
	var sampler = SurfaceSampler.new(7777777)
	var second_sampler = SurfaceSampler.new(7777777)
	var positions: Array[Vector2] = [
		Vector2(chunk_size - offset, 31.25),
		Vector2(chunk_size + offset, 31.25),
		Vector2(-chunk_size - offset, -47.5),
		Vector2(-chunk_size + offset, -47.5),
		Vector2(19.75, chunk_size - offset),
		Vector2(19.75, chunk_size + offset),
		Vector2(-23.5, -chunk_size - offset),
		Vector2(-23.5, -chunk_size + offset),
	]

	for position in positions:
		var first = sampler.sample(position.x, position.y)
		var reproduced = second_sampler.sample(position.x, position.y)
		_validate_sample(failures, "chunk-boundary %s" % str(position), first, position)
		_expect_equal(
			failures,
			"chunk-boundary sample reproduces at %s" % str(position),
			first.canonical_data(),
			reproduced.canonical_data()
		)


static func _test_sample_invariants(failures: Array[String]) -> void:
	var sampler = SurfaceSampler.new(13579)
	var positions: Array[Vector2] = [
		Vector2(0.0, 0.0),
		Vector2(64.0, 64.0),
		Vector2(128.0, 128.0),
		Vector2(-64.0, 192.0),
		Vector2(10000.0, -10000.0),
	]
	for position in positions:
		_validate_sample(failures, "invariant %s" % str(position), sampler.sample(position.x, position.y), position)


static func _test_pure_data_base_type(failures: Array[String]) -> void:
	var sampler = SurfaceSampler.new(1)
	_expect_true(failures, "surface sampler is RefCounted", sampler is RefCounted)
	_expect_true(failures, "surface sampler is not Node-owned", not (sampler is Node))
	var sampler_script: Script = load("res://worldgen/surface/deterministic_surface_sampler.gd")
	_expect_equal(
		failures,
		"surface sampler script base type remains RefCounted",
		sampler_script.get_instance_base_type(),
		"RefCounted"
	)


static func _validate_sample(
	failures: Array[String],
	label: String,
	sample,
	expected_xz: Vector2
) -> void:
	if sample == null:
		failures.append("%s — sampler returned null" % label)
		return

	_expect_close(failures, "%s world X" % label, sample.world_position.x, expected_xz.x)
	_expect_close(failures, "%s world Z" % label, sample.world_position.z, expected_xz.y)
	_expect_finite(failures, "%s height" % label, sample.world_position.y)
	_expect_finite(failures, "%s normal.x" % label, sample.normal.x)
	_expect_finite(failures, "%s normal.y" % label, sample.normal.y)
	_expect_finite(failures, "%s normal.z" % label, sample.normal.z)
	_expect_close(failures, "%s normal is normalized" % label, sample.normal.length(), 1.0, 0.00001)
	_expect_true(failures, "%s normal faces upward" % label, sample.normal.y > 0.0)

	_validate_unit_interval(failures, "%s slope" % label, sample.slope)
	_validate_unit_interval(failures, "%s moisture" % label, sample.moisture)
	_validate_unit_interval(failures, "%s forest density" % label, sample.forest_density)
	_validate_unit_interval(failures, "%s rockiness" % label, sample.rockiness)
	_validate_unit_interval(failures, "%s buildability" % label, sample.buildability)
	_expect_finite(failures, "%s sea level" % label, sample.sea_level)
	_expect_equal(
		failures,
		"%s submerged predicate matches height/sea-level relation" % label,
		sample.is_submerged(),
		sample.world_position.y < sample.sea_level
	)

	var canonical: Dictionary = sample.canonical_data()
	for required_key in [
		"world_position",
		"normal",
		"slope",
		"moisture",
		"forest_density",
		"rockiness",
		"buildability",
		"sea_level",
	]:
		_expect_true(failures, "%s canonical field %s" % [label, required_key], canonical.has(required_key))


static func _validate_unit_interval(failures: Array[String], label: String, value: float) -> void:
	_expect_finite(failures, label, value)
	_expect_true(failures, "%s is within [0, 1]" % label, value >= 0.0 and value <= 1.0)


static func _expect_finite(failures: Array[String], label: String, value: float) -> void:
	if not is_finite(value):
		failures.append("%s — expected finite value, got %s" % [label, str(value)])


static func _expect_close(
	failures: Array[String],
	label: String,
	actual: float,
	expected: float,
	tolerance: float = EPSILON
) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(
	failures: Array[String],
	label: String,
	actual: Variant,
	expected: Variant
) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, str(expected), str(actual)])


static func _position_key(position: Vector2) -> String:
	return "%.9f,%.9f" % [position.x, position.y]
