extends RefCounted
class_name UnderworldWorldgenBenchmarkConfig

# This corpus is intentionally explicit and versioned. Changing it changes the
# benchmark comparison basis and therefore requires a corpus revision bump.
const CORPUS_REVISION := "worldgen-benchmark-corpus-v1"
const SEEDS := [1, 17, 12345, 24681357]
const REGIONS := [
	Vector2i(0, 0),
	Vector2i(1, -1),
	Vector2i(-2, 3),
	Vector2i(4, -3),
	Vector2i(-5, -4),
]
const NEIGHBOR_OFFSETS := [
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(0, -1),
	Vector2i(0, 1),
]


static func benchmark_cases() -> Array:
	var result: Array = []
	for seed in SEEDS:
		for region in REGIONS:
			result.append({
				"seed": int(seed),
				"region": region,
			})
	return result


static func neighbor_offsets() -> Array:
	return NEIGHBOR_OFFSETS.duplicate()
