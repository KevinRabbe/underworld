extends RefCounted
class_name UnderworldCaveVoxelFieldRequest

const Plan := preload("res://worldgen/geometry/geometry_cell_plan.gd")
const Config := preload("res://worldgen/geometry/geometry_cell_partition_config.gd")

var geometry_cell_plan
var partition_configuration
var provenance
var iso_level: float
var input_fingerprint: String


func _init(
	plan_value = null,
	configuration_value = null,
	provenance_value = null,
	iso_level_value: float = 0.0
) -> void:
	geometry_cell_plan = plan_value
	partition_configuration = configuration_value
	provenance = provenance_value
	iso_level = iso_level_value
	input_fingerprint = ""
	if geometry_cell_plan != null and geometry_cell_plan is Plan:
		input_fingerprint = geometry_cell_plan.fingerprint


func validate() -> Array[String]:
	var failures: Array[String] = []
	if geometry_cell_plan == null or not (geometry_cell_plan is Plan):
		failures.append("CaveVoxelFieldRequest requires a GeometryCellPlan")
	if partition_configuration == null or not (partition_configuration is Config):
		failures.append("CaveVoxelFieldRequest requires GeometryCellPartitionConfig")
	if not is_finite(iso_level):
		failures.append("CaveVoxelFieldRequest iso_level must be finite")
	if geometry_cell_plan != null and geometry_cell_plan is Plan:
		if geometry_cell_plan.cell_address == null:
			failures.append("CaveVoxelFieldRequest plan has no cell address")
		if geometry_cell_plan.fingerprint.is_empty():
			failures.append("CaveVoxelFieldRequest plan fingerprint is empty")
	return failures
