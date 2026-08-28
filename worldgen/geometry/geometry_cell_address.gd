extends RefCounted
class_name UnderworldGeometryCellAddress

const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")

const ADDRESS_REVISION: int = 1
var coordinate: Vector3i
var cell_coord: Vector3i


func _init(coordinate_value: Vector3i = Vector3i.ZERO) -> void:
	coordinate = coordinate_value
	cell_coord = coordinate_value


static func from_world_position(position: Vector3, configuration = null):
	var Config = preload("res://worldgen/geometry/geometry_cell_partition_config.gd")
	var policy = configuration if configuration != null else Config.new()
	return load("res://worldgen/geometry/geometry_cell_address.gd").new(Vector3i(
		floori(position.x / policy.cell_size.x), floori(position.y / policy.cell_size.y), floori(position.z / policy.cell_size.z)
	))


func canonical_text() -> String:
	return "gcell1:r%d:x%d:y%d:z%d" % [
		ADDRESS_REVISION, coordinate.x, coordinate.y, coordinate.z,
	]


func canonical_data() -> Dictionary:
	return {
		"address_revision": ADDRESS_REVISION,
		"coordinate": coordinate,
	}


func fingerprint() -> String:
	return "gcell1:" + CanonicalValue.fingerprint(canonical_data())


func is_equal(other) -> bool:
	return other != null and other is UnderworldGeometryCellAddress and coordinate == other.coordinate
