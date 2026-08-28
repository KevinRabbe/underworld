extends SceneTree

const AtlasBuilder := preload("res://tools/worldgen/topology_atlas_builder.gd")
const AtlasSvg := preload("res://tools/worldgen/topology_atlas_svg.gd")


func _init() -> void:
	var failures: Array[String] = []
	_test_default_atlas(failures)
	_test_deterministic_atlas(failures)
	_test_negative_center(failures)
	_test_radius_contract(failures)
	_finish(failures)


static func _test_default_atlas(failures: Array[String]) -> void:
	var built: Dictionary = AtlasBuilder.build(424242, Vector2i.ZERO, 1)
	_expect_true(failures, "3x3 atlas builds", bool(built.get("success", false)))
	if not bool(built.get("success", false)):
		return

	var atlas: Dictionary = built["atlas"]
	var regions: Array = atlas.get("regions", [])
	var totals: Dictionary = atlas.get("totals", {})
	_expect_equal(failures, "atlas schema", str(atlas.get("schema", "")), "underworld-topology-atlas-v1")
	_expect_equal(failures, "default grid size", atlas.get("grid_size", []), [3, 3])
	_expect_equal(failures, "default atlas region count", regions.size(), 9)
	_expect_equal(failures, "total region count", int(totals.get("region_count", -1)), 9)
	_expect_equal(failures, "fingerprint count", atlas.get("topology_fingerprints", []).size(), 9)

	var expected_coords: Array = [
		[-1, -1], [0, -1], [1, -1],
		[-1, 0], [0, 0], [1, 0],
		[-1, 1], [0, 1], [1, 1],
	]
	var actual_coords: Array = []
	var network_total: int = 0
	var node_total: int = 0
	var edge_total: int = 0
	var boundary_total: int = 0
	for region in regions:
		actual_coords.append(region.get("region", {}).get("coord", []))
		network_total += region.get("networks", []).size()
		node_total += region.get("nodes", []).size()
		edge_total += region.get("edges", []).size()
		boundary_total += region.get("boundary_candidates", []).size()
	_expect_equal(failures, "regions use canonical row-major coordinate order", actual_coords, expected_coords)
	_expect_equal(failures, "network aggregate", int(totals.get("network_count", -1)), network_total)
	_expect_equal(failures, "node aggregate", int(totals.get("node_count", -1)), node_total)
	_expect_equal(failures, "edge aggregate", int(totals.get("edge_count", -1)), edge_total)
	_expect_equal(failures, "boundary aggregate", int(totals.get("boundary_candidate_count", -1)), boundary_total)

	var svg: String = AtlasSvg.render(atlas)
	_expect_equal(failures, "SVG has nine region frames", svg.count("class=\"region-frame\""), 9)
	_expect_equal(failures, "SVG has nine region groups", svg.count("class=\"region-cell\""), 9)
	_expect_true(failures, "SVG names atlas", svg.contains("Underworld topology atlas"))
	_expect_true(failures, "SVG carries seed", svg.contains("seed=424242"))
	_expect_true(failures, "SVG carries center", svg.contains("center=(0,0)"))


static func _test_deterministic_atlas(failures: Array[String]) -> void:
	var first: Dictionary = AtlasBuilder.build(808080, Vector2i(3, -2), 1)
	var second: Dictionary = AtlasBuilder.build(808080, Vector2i(3, -2), 1)
	_expect_true(failures, "first deterministic atlas builds", bool(first.get("success", false)))
	_expect_true(failures, "second deterministic atlas builds", bool(second.get("success", false)))
	if not bool(first.get("success", false)) or not bool(second.get("success", false)):
		return
	var first_json: String = JSON.stringify(first["atlas"], "", true, true)
	var second_json: String = JSON.stringify(second["atlas"], "", true, true)
	_expect_equal(failures, "atlas JSON reproduces exactly", first_json, second_json)
	_expect_equal(
		failures,
		"atlas SVG reproduces exactly",
		AtlasSvg.render(first["atlas"]),
		AtlasSvg.render(second["atlas"])
	)


static func _test_negative_center(failures: Array[String]) -> void:
	var built: Dictionary = AtlasBuilder.build(-515151, Vector2i(-4, -6), 1)
	_expect_true(failures, "negative-center atlas builds", bool(built.get("success", false)))
	if not bool(built.get("success", false)):
		return
	var atlas: Dictionary = built["atlas"]
	_expect_equal(failures, "negative seed preserved", int(atlas.get("world_seed", 0)), -515151)
	_expect_equal(failures, "negative center preserved", atlas.get("center_region", []), [-4, -6])
	var regions: Array = atlas.get("regions", [])
	_expect_equal(failures, "negative atlas region count", regions.size(), 9)
	if regions.size() == 9:
		_expect_equal(failures, "negative atlas first coord", regions[0]["region"]["coord"], [-5, -7])
		_expect_equal(failures, "negative atlas last coord", regions[8]["region"]["coord"], [-3, -5])
	_expect_true(failures, "negative atlas SVG renders", AtlasSvg.render(atlas).contains("center=(-4,-6)"))


static func _test_radius_contract(failures: Array[String]) -> void:
	var single: Dictionary = AtlasBuilder.build(12, Vector2i(7, 9), 0)
	_expect_true(failures, "radius zero builds one-region atlas", bool(single.get("success", false)))
	if bool(single.get("success", false)):
		_expect_equal(failures, "radius zero grid", single["atlas"]["grid_size"], [1, 1])
		_expect_equal(failures, "radius zero region count", single["atlas"]["regions"].size(), 1)

	var negative_radius: Dictionary = AtlasBuilder.build(12, Vector2i.ZERO, -1)
	_expect_true(failures, "negative radius is rejected", not bool(negative_radius.get("success", true)))
	var excessive_radius: Dictionary = AtlasBuilder.build(12, Vector2i.ZERO, 5)
	_expect_true(failures, "radius above maximum is rejected", not bool(excessive_radius.get("success", true)))


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s expected=%s actual=%s" % [label, str(expected), str(actual)])


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("[WORLDGEN ATLAS] PASS")
		quit(0)
		return
	printerr("[WORLDGEN ATLAS] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
