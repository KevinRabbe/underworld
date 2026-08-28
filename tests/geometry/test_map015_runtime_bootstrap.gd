extends RefCounted

const Controller := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const WorldId := preload("res://worldgen/identity/world_id.gd")
const Manifest := preload("res://worldgen/versioning/generator_manifest.gd")

static func run() -> Array[String]:
	var failures: Array[String] = []
	var controller := Controller.new()
	controller.configure(WorldId.from_seed(1).value(), Manifest.foundation_default().manifest_id())
	var entrance_id := "sid1:sa1|2:ug|6:region|1:0|1:0|8:entrance|4:slot|1:0"
	var diagnostics: Array[String] = controller.bootstrap_fixture(1, Vector2i.ZERO, entrance_id)
	if not diagnostics.is_empty():
		failures.append_array(diagnostics)
	else:
		if controller.render_nodes.size() < 4: failures.append("MAP-015 bootstrap produced too few render cells")
		if controller.collision_nodes.size() < 4: failures.append("MAP-015 bootstrap produced too few collision cells")
		if not controller.gate_is_open(entrance_id): failures.append("MAP-015 bootstrap gate did not open")
		if controller.last_bootstrap_fingerprint.is_empty(): failures.append("MAP-015 bootstrap fingerprint missing")
	controller.free()
	return failures
