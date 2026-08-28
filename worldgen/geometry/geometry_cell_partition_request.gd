extends RefCounted
class_name UnderworldGeometryCellPartitionRequest

const CaveGeometryResult := preload("res://worldgen/underworld/cave_geometry_result.gd")
const FinalizationResult := preload("res://worldgen/underworld/region_finalization_result.gd")
const Config := preload("res://worldgen/geometry/geometry_cell_partition_config.gd")
const CellAddress := preload("res://worldgen/geometry/geometry_cell_address.gd")

var cave_geometry_result
var region_finalization_result
var configuration
var requested_cells: Array


func _init(
	geometry_result_value,
	finalization_result_value,
	configuration_value = null,
	requested_cells_value: Array = []
) -> void:
	cave_geometry_result = geometry_result_value
	region_finalization_result = finalization_result_value
	configuration = configuration_value if configuration_value != null else Config.new()
	requested_cells = requested_cells_value.duplicate(true)


func validate() -> Array[String]:
	var failures: Array[String] = []
	if cave_geometry_result == null or not (cave_geometry_result is CaveGeometryResult):
		failures.append("GeometryCellPartitionRequest requires CaveGeometryResult")
	if region_finalization_result == null or not (region_finalization_result is FinalizationResult):
		failures.append("GeometryCellPartitionRequest requires RegionFinalizationResult")
	if configuration == null or not (configuration is Config):
		failures.append("GeometryCellPartitionRequest requires GeometryCellPartitionConfig")
	elif not configuration.validate().is_empty():
		failures.append_array(configuration.validate())
	for cell in requested_cells:
		if not (cell is Vector3i) and not (cell is CellAddress):
			failures.append("Requested geometry cells must be Vector3i or GeometryCellAddress")
			break
	return failures

