extends RefCounted
class_name UnderworldGeometryCellAddress

const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")

const ADDRESS_REVISION: int = 1
var coordinate: Vector3i
var cell_coord: Vector3i


func _init(coordinate_value: Vector3i = Vector3i.ZERO) -> void:
	coordinate = coordinate_value
	cell_coord = coordinate_value


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
