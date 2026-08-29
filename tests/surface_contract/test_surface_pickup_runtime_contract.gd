extends RefCounted

const TerrainChunk := preload("res://world/terrain_chunk.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_non_mutating_pickup_discovery(failures)
	_test_destroyed_pickups_are_excluded(failures)
	return failures


static func _test_non_mutating_pickup_discovery(failures: Array[String]) -> void:
	var chunk = TerrainChunk.new()
	chunk.chunk_coord = Vector2i(-2, 3)
	chunk._branch_transforms = [
		Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 0.5)),
		Transform3D(Basis.IDENTITY, Vector3(8.0, 0.0, 0.0)),
	]
	chunk._loose_stone_transforms = [
		Transform3D(Basis.IDENTITY, Vector3(0.5, 0.0, 1.0)),
	]

	var branch_destroyed_before: Dictionary = chunk._destroyed_branch_indices.duplicate(true)
	var stone_destroyed_before: Dictionary = chunk._destroyed_loose_stone_indices.duplicate(true)
	var first: Array = chunk.find_nearby_pickups(Vector3.ZERO, 2.0)
	var second: Array = chunk.find_nearby_pickups(Vector3.ZERO, 2.0)

	if first != second:
		failures.append("surface pickup discovery changed across repeated identical queries")
	if chunk._destroyed_branch_indices != branch_destroyed_before:
		failures.append("surface branch discovery mutated destroyed-index world state")
	if chunk._destroyed_loose_stone_indices != stone_destroyed_before:
		failures.append("surface loose-stone discovery mutated destroyed-index world state")
	if first.size() != 2:
		failures.append("surface pickup discovery returned unexpected nearby candidate count: %d" % first.size())
	else:
		var ids: Array[String] = []
		for candidate_variant in first:
			var candidate: Dictionary = candidate_variant
			ids.append(str(candidate.get("object_id", "")))
		var expected: Array[String] = [
			"-2:3:branch:0",
			"-2:3:loose_stone:0",
		]
		if ids != expected:
			failures.append("surface pickup discovery changed StableId-compatible object identity/order: %s" % [ids])
		for candidate_variant in first:
			var candidate: Dictionary = candidate_variant
			if not candidate.has("object_type") or not candidate.has("index"):
				failures.append("surface pickup discovery omitted world mutation locator fields")
				break
	chunk.free()


static func _test_destroyed_pickups_are_excluded(failures: Array[String]) -> void:
	var chunk = TerrainChunk.new()
	chunk.chunk_coord = Vector2i(4, -5)
	chunk._branch_transforms = [Transform3D(Basis.IDENTITY, Vector3.ZERO)]
	chunk._loose_stone_transforms = [Transform3D(Basis.IDENTITY, Vector3(0.25, 0.0, 0.25))]
	chunk._destroyed_branch_indices[0] = true
	var before: Dictionary = chunk._destroyed_branch_indices.duplicate(true)

	var found: Array = chunk.find_nearby_pickups(Vector3.ZERO, 2.0)
	if found.size() != 1:
		failures.append("surface pickup discovery did not exclude pre-destroyed candidate")
	elif str(found[0].get("object_id", "")) != "4:-5:loose_stone:0":
		failures.append("surface pickup discovery returned wrong surviving StableId-compatible object")
	if chunk._destroyed_branch_indices != before:
		failures.append("surface pickup discovery changed pre-existing destroyed-index state")
	chunk.free()
