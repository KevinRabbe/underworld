extends RefCounted
class_name UnderworldCaveVoxelFieldRequest

const Plan := preload("res://worldgen/geometry/geometry_cell_plan.gd")
const Config := preload("res://worldgen/geometry/geometry_cell_partition_config.gd")
const Provenance := preload("res://worldgen/pipeline/generation_provenance.gd")
const PartitionResult := preload("res://worldgen/geometry/geometry_cell_partition_result.gd")

var geometry_cell_plan
var partition_configuration
var provenance
var geometry_cell_partition_result
var world_context
var iso_level: float
var input_fingerprint: String


func _init(
	plan_value = null,
	configuration_value = null,
	provenance_value = null,
	iso_level_value: float = 0.0,
	partition_result_value = null,
	world_context_value = null
) -> void:
	geometry_cell_plan = plan_value
	partition_configuration = configuration_value
	provenance = provenance_value
	geometry_cell_partition_result = partition_result_value
	world_context = world_context_value
	iso_level = iso_level_value
	input_fingerprint = ""
	if geometry_cell_plan != null and geometry_cell_plan is Plan:
		input_fingerprint = geometry_cell_plan.fingerprint + ":" + (geometry_cell_partition_result.fingerprint if geometry_cell_partition_result != null and geometry_cell_partition_result is PartitionResult else "") + ":" + (provenance.fingerprint if provenance != null and provenance is Provenance else "")


func validate() -> Array[String]:
	var failures: Array[String] = []
	if geometry_cell_plan == null or not (geometry_cell_plan is Plan):
		failures.append("CaveVoxelFieldRequest requires a GeometryCellPlan")
	if partition_configuration == null or not (partition_configuration is Config):
		failures.append("CaveVoxelFieldRequest requires GeometryCellPartitionConfig")
	if geometry_cell_partition_result == null or not (geometry_cell_partition_result is PartitionResult):
		failures.append("CaveVoxelFieldRequest requires GeometryCellPartitionResult")
	if world_context == null:
		failures.append("CaveVoxelFieldRequest requires WorldGenerationContext")
	if not is_finite(iso_level):
		failures.append("CaveVoxelFieldRequest iso_level must be finite")
	if geometry_cell_plan != null and geometry_cell_plan is Plan:
		if geometry_cell_plan.cell_address == null:
			failures.append("CaveVoxelFieldRequest plan has no cell address")
		if geometry_cell_plan.fingerprint.is_empty():
			failures.append("CaveVoxelFieldRequest plan fingerprint is empty")
	if provenance == null or not (provenance is Provenance):
		failures.append("CaveVoxelFieldRequest requires GenerationProvenance")
	elif provenance.fingerprint.is_empty():
		failures.append("CaveVoxelFieldRequest provenance fingerprint is empty")
	if geometry_cell_partition_result is PartitionResult and world_context != null:
		var result_provenance = geometry_cell_partition_result.provenance
		if result_provenance == null or not (result_provenance is Provenance):
			failures.append("CaveVoxelFieldRequest partition result requires GenerationProvenance")
		else:
			var expected_region := ""
			if geometry_cell_plan is Plan and geometry_cell_plan.cell_address != null:
				expected_region = result_provenance.region_id
			failures.append_array(world_context.validate_provenance(result_provenance, "geometry_cell_partition", expected_region))
			if provenance is Provenance:
				failures.append_array(world_context.validate_provenance(provenance, "geometry_cell_partition", expected_region))
				if provenance.fingerprint != result_provenance.fingerprint:
					failures.append("CaveVoxelFieldRequest provenance does not match partition result provenance")
		if partition_configuration is Config and geometry_cell_partition_result.configuration_fingerprint != partition_configuration.fingerprint:
			failures.append("CaveVoxelFieldRequest configuration does not match partition result")
		var matching_plan = false
		for candidate in geometry_cell_partition_result.plans:
			if candidate is Plan and geometry_cell_plan is Plan and candidate.cell_address.canonical_text() == geometry_cell_plan.cell_address.canonical_text() and candidate.fingerprint == geometry_cell_plan.fingerprint:
				matching_plan = true
				break
		if not matching_plan:
			failures.append("CaveVoxelFieldRequest plan is not owned by partition result")
		if geometry_cell_plan is Plan:
			if geometry_cell_plan.source_geometry_fingerprint != geometry_cell_partition_result.source_geometry_fingerprint:
				failures.append("CaveVoxelFieldRequest plan geometry source does not match partition result")
			if geometry_cell_plan.source_finalization_fingerprint != geometry_cell_partition_result.source_finalization_fingerprint:
				failures.append("CaveVoxelFieldRequest plan finalization source does not match partition result")
	return failures
