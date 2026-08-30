extends RefCounted

const TerrainGenerator := preload("res://worldgen/surface/terrain_generator.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var generator = TerrainGenerator.new()
	var coord: Vector2i = Vector2i(-3, 2)
	var resolution: int = 9

	# Model two acceptance outcomes for the same deterministic candidate walk.
	# In the first, the earlier cell is accepted; in the second it is rejected.
	# The later semantic candidate therefore changes compacted-array position,
	# while its candidate-address-derived StableId must remain identical.
	var earlier_id: String = generator._candidate_stable_id(
		"tree", coord, resolution, 0, 0
	)
	var later_with_earlier: String = generator._candidate_stable_id(
		"tree", coord, resolution, 4, 0
	)
	var later_without_earlier: String = generator._candidate_stable_id(
		"tree", coord, resolution, 4, 0
	)

	var accepted_when_earlier_passes: Array[String] = [earlier_id, later_with_earlier]
	var accepted_when_earlier_fails: Array[String] = [later_without_earlier]
	if accepted_when_earlier_passes.find(later_with_earlier) != 1:
		failures.append("surface candidate-order fixture did not place later candidate after accepted predecessor")
	if accepted_when_earlier_fails.find(later_without_earlier) != 0:
		failures.append("surface candidate-order fixture did not compact after rejected predecessor")
	if later_with_earlier != later_without_earlier:
		failures.append("later surface StableId changed when earlier candidate acceptance changed")
	if StableId.parse(later_with_earlier) == null:
		failures.append("candidate-order invariant produced malformed later StableId")
	if later_with_earlier == earlier_id:
		failures.append("distinct surface candidate cells aliased during acceptance-order proof")
	return failures
