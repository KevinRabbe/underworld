extends RefCounted
class_name UnderworldGeometryCellReproductionProbe

const GeometryProbe := preload("res://worldgen/validation/cave_geometry_reproduction_probe.gd")
const GeometryGenerator := preload("res://worldgen/underworld/cave_geometry_generator.gd")
const Partitioner := preload("res://worldgen/geometry/geometry_cell_partitioner.gd")
const Config := preload("res://worldgen/geometry/geometry_cell_partition_config.gd")


static func build(world_seed: int, region_coord: Vector2i) -> Dictionary:
	var inputs: Dictionary = GeometryProbe._build_inputs(world_seed, region_coord)
	if not bool(inputs.get("success", false)):
		return inputs
	var geometry = GeometryGenerator.generate(
		inputs["context"], inputs["macro"], inputs["finalized"], inputs["neighbor_views"]
	)
	if not geometry.success:
		return {
			"success": false,
			"stage": "cave_geometry",
			"diagnostics": geometry.diagnostics,
		}
	var partition = Partitioner.partition(geometry.data, inputs["finalized"], Config.new())
	if not partition.success:
		return {
			"success": false,
			"stage": "geometry_cell_partition",
			"diagnostics": partition.diagnostics,
		}
	return {
		"success": true,
		"fingerprint": partition.fingerprint,
		"geometry_fingerprint": geometry.fingerprint,
		"finalization_fingerprint": inputs["finalization_fingerprint"],
		"configuration_fingerprint": partition.data.configuration_fingerprint,
		"metrics": partition.data.metrics,
		"diagnostics": [],
	}

