extends RefCounted
class_name UnderworldCaveMeshBuilder

const Mesher := preload("res://worldgen/geometry/cave_voxel_mesher_cached.gd")


static func prepare(request):
	return _profiled_build(request)


static func build(request):
	return _profiled_build(request)


static func _profiled_build(request):
	var started: int = Time.get_ticks_usec()
	var result = Mesher.build(request)
	var wall_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	if result != null and result.success and result.data != null:
		print(
			"[PERF-002] production extraction cell=%s wall_ms=%.3f extraction_ms=%.3f logical_samples=%d unique_samples=%d cubes=%d" % [
				str(result.data.cell_address.canonical_text() if result.data.cell_address != null else ""),
				wall_ms,
				float(result.data.metrics.get("extraction_ms", wall_ms)),
				int(result.data.metrics.get("sample_count", 0)),
				int(result.data.metrics.get("unique_sample_count", 0)),
				int(result.data.metrics.get("cube_count", 0)),
			]
		)
	return result
