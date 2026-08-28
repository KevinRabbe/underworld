extends RefCounted
class_name UnderworldGeometryCellPartitionConfig

const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")

const CONTRACT_REVISION: int = 1
const DEFAULT_CELL_SIZE := Vector3(32.0, 32.0, 32.0)
const DEFAULT_VOXEL_PITCH: float = 0.5
const DEFAULT_CUBES_PER_AXIS: int = 64
const DEFAULT_SAMPLE_HALO: int = 1

var contract_revision: int
var cell_size: Vector3
var voxel_pitch: float
var cubes_per_axis: int
var sample_halo: int
var fingerprint: String


func _init(
	cell_size_value: Vector3 = DEFAULT_CELL_SIZE,
	voxel_pitch_value: float = DEFAULT_VOXEL_PITCH,
	cubes_per_axis_value: int = DEFAULT_CUBES_PER_AXIS,
	sample_halo_value: int = DEFAULT_SAMPLE_HALO,
	contract_revision_value: int = CONTRACT_REVISION
) -> void:
	contract_revision = contract_revision_value
	cell_size = cell_size_value
	voxel_pitch = voxel_pitch_value
	cubes_per_axis = cubes_per_axis_value
	sample_halo = sample_halo_value
	fingerprint = ""
	var failures := validate()
	if failures.is_empty():
		fingerprint = "gpartition-config1:" + CanonicalValue.fingerprint(canonical_data())


func validate() -> Array[String]:
	var failures: Array[String] = []
	if contract_revision != CONTRACT_REVISION:
		failures.append("GeometryCellPartitionConfig contract revision must be %d" % CONTRACT_REVISION)
	for component in [cell_size.x, cell_size.y, cell_size.z, voxel_pitch]:
		if not is_finite(float(component)) or float(component) <= 0.0:
			failures.append("Geometry cell dimensions and voxel pitch must be finite and positive")
			break
	if cubes_per_axis <= 0:
		failures.append("Geometry cell cube count must be positive")
	if sample_halo < 0:
		failures.append("Geometry cell sample halo cannot be negative")
	if failures.is_empty():
		for component in [cell_size.x, cell_size.y, cell_size.z]:
			var cubes: float = float(component) / voxel_pitch
			if absf(cubes - round(cubes)) > 0.000001:
				failures.append("Cell dimensions must be evenly divisible by voxel pitch")
				break
		if absf(float(cubes_per_axis) - (cell_size.x / voxel_pitch)) > 0.000001 \
				or absf(float(cubes_per_axis) - (cell_size.y / voxel_pitch)) > 0.000001 \
				or absf(float(cubes_per_axis) - (cell_size.z / voxel_pitch)) > 0.000001:
			failures.append("Cell dimensions must match cubes_per_axis * voxel_pitch")
	return failures


func canonical_data() -> Dictionary:
	return {
		"contract_revision": contract_revision,
		"cell_size": cell_size,
		"voxel_pitch": voxel_pitch,
		"cubes_per_axis": cubes_per_axis,
		"sample_halo": sample_halo,
	}


func canonical_text() -> String:
	return CanonicalValue.encode(canonical_data())

