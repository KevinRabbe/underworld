extends RefCounted
class_name UnderworldCaveVoxelFieldRequest

const Plan := preload("res://worldgen/geometry/geometry_cell_plan.gd")
const Config := preload("res://worldgen/geometry/geometry_cell_partition_config.gd")
const Provenance := preload("res://worldgen/pipeline/generation_provenance.gd")
const PartitionResult := preload("res://worldgen/geometry/geometry_cell_partition_result.gd")
const GeometryResult := preload("res://worldgen/underworld/cave_geometry_result.gd")
const FinalizationResult := preload("res://worldgen/underworld/region_finalization_result.gd")
const GraphBundle := preload("res://worldgen/graph/region_graph_bundle.gd")
const RegionDefinition := preload("res://worldgen/graph/underground_region_definition.gd")
const StableAddress := preload("res://worldgen/identity/stable_address.gd")

var geometry_cell_plan
var partition_configuration
var provenance
var geometry_cell_partition_result
var world_context
var source_geometry_result
var source_finalization_result
var iso_level: float
var input_fingerprint: String


func _init(
	plan_value = null,
	configuration_value = null,
	provenance_value = null,
	iso_level_value: float = 0.0,
	partition_result_value = null,
	world_context_value = null,
	geometry_result_value = null,
	finalization_result_value = null
) -> void:
	geometry_cell_plan = plan_value
	partition_configuration = configuration_value
	provenance = provenance_value
	geometry_cell_partition_result = partition_result_value
	world_context = world_context_value
	source_geometry_result = geometry_result_value
	source_finalization_result = finalization_result_value
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
	if source_geometry_result == null or not (source_geometry_result is GeometryResult):
		failures.append("CaveVoxelFieldRequest requires its source CaveGeometryResult")
	if source_finalization_result == null or not (source_finalization_result is FinalizationResult):
		failures.append("CaveVoxelFieldRequest requires its source RegionFinalizationResult")
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
			var expected_region_address := ""
			var expected_sources: Array[String] = []
			if source_geometry_result is GeometryResult and source_finalization_result is FinalizationResult:
				var geometry_region = _source_region_definition(source_geometry_result, "geometry", failures)
				var finalization_region = _source_region_definition(source_finalization_result, "finalization", failures)
				if geometry_region != null:
					expected_region = str(geometry_region.stable_id)
					expected_region_address = geometry_region.stable_address.canonical_text()
				if geometry_region != null and finalization_region != null:
					if str(finalization_region.stable_id) != expected_region or finalization_region.stable_address.canonical_text() != expected_region_address:
						failures.append("CaveVoxelFieldRequest source Geometry and Finalization regions do not match")
				if source_geometry_result.fingerprint != geometry_cell_partition_result.source_geometry_fingerprint:
					failures.append("CaveVoxelFieldRequest source geometry does not match partition result")
				if source_finalization_result.fingerprint != geometry_cell_partition_result.source_finalization_fingerprint:
					failures.append("CaveVoxelFieldRequest source finalization does not match partition result")
				if source_geometry_result.provenance == null or not (source_geometry_result.provenance is Provenance):
					failures.append("CaveVoxelFieldRequest source geometry requires GenerationProvenance")
				else:
					failures.append_array(world_context.validate_provenance(source_geometry_result.provenance, "geometry_description", expected_region))
					if not expected_region_address.is_empty() and source_geometry_result.provenance.region_address != expected_region_address:
						failures.append("CaveVoxelFieldRequest source geometry provenance address does not match its region")
				if source_finalization_result.provenance == null or not (source_finalization_result.provenance is Provenance):
					failures.append("CaveVoxelFieldRequest source finalization requires GenerationProvenance")
				else:
					failures.append_array(world_context.validate_provenance(source_finalization_result.provenance, "region_finalization", expected_region))
					if not expected_region_address.is_empty() and source_finalization_result.provenance.region_address != expected_region_address:
						failures.append("CaveVoxelFieldRequest source finalization provenance address does not match its region")
				if source_geometry_result.provenance is Provenance and source_finalization_result.provenance is Provenance:
					expected_sources = [source_geometry_result.provenance.fingerprint, source_finalization_result.provenance.fingerprint]
					expected_sources.sort()
			if not expected_region_address.is_empty() and result_provenance.region_address != expected_region_address:
				failures.append("CaveVoxelFieldRequest partition result provenance region address does not match source parents")
			if provenance is Provenance and not expected_region_address.is_empty() and provenance.region_address != expected_region_address:
				failures.append("CaveVoxelFieldRequest provenance region address does not match source parents")
			failures.append_array(world_context.validate_provenance(result_provenance, "geometry_cell_partition", expected_region, expected_sources))
			if provenance is Provenance:
				failures.append_array(world_context.validate_provenance(provenance, "geometry_cell_partition", expected_region, expected_sources))
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


func _source_region_definition(source_result, source_label: String, failures: Array[String]):
	if source_result.bundle == null or not (source_result.bundle is GraphBundle):
		failures.append("CaveVoxelFieldRequest source %s requires a RegionGraphBundle" % source_label)
		return null
	var region_definition = source_result.bundle.region_definition
	if region_definition == null or not (region_definition is RegionDefinition):
		failures.append("CaveVoxelFieldRequest source %s requires a region definition" % source_label)
		return null
	if region_definition.stable_address == null or not (region_definition.stable_address is StableAddress):
		failures.append("CaveVoxelFieldRequest source %s region requires a StableAddress" % source_label)
		return null
	return region_definition
