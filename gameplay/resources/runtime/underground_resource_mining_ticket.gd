extends RefCounted
class_name UndergroundResourceMiningTicket

const StableId := preload("res://worldgen/identity/stable_id.gd")

var _placement_stable_id: String = ""
var _placement_fingerprint: String = ""
var _resource_content_id: String = ""
var _operation_id: String = ""
var _operation_ordinal: int = 0
var _cell_address: String = ""
var _cell_generation: int = 0
var _cell_source_fingerprint: String = ""
var _cell_provenance_fingerprint: String = ""


func _init(
	placement_stable_id_value: String,
	placement_fingerprint_value: String,
	resource_content_id_value: String,
	operation_id_value: String,
	operation_ordinal_value: int,
	cell_address_value: String,
	cell_generation_value: int,
	cell_source_fingerprint_value: String,
	cell_provenance_fingerprint_value: String
) -> void:
	_placement_stable_id = placement_stable_id_value
	_placement_fingerprint = placement_fingerprint_value
	_resource_content_id = resource_content_id_value
	_operation_id = operation_id_value
	_operation_ordinal = operation_ordinal_value
	_cell_address = cell_address_value
	_cell_generation = cell_generation_value
	_cell_source_fingerprint = cell_source_fingerprint_value
	_cell_provenance_fingerprint = cell_provenance_fingerprint_value


func placement_stable_id() -> String:
	return _placement_stable_id


func placement_fingerprint() -> String:
	return _placement_fingerprint


func resource_content_id() -> String:
	return _resource_content_id


func operation_id() -> String:
	return _operation_id


func operation_ordinal() -> int:
	return _operation_ordinal


func cell_address() -> String:
	return _cell_address


func cell_generation() -> int:
	return _cell_generation


func cell_source_fingerprint() -> String:
	return _cell_source_fingerprint


func cell_provenance_fingerprint() -> String:
	return _cell_provenance_fingerprint


func validate_ticket() -> Array[String]:
	var failures: Array[String] = []
	var placement_id = StableId.parse(_placement_stable_id)
	if placement_id == null:
		failures.append("resource mining ticket requires canonical placement StableId")
	if _placement_fingerprint.is_empty() or _placement_fingerprint != _placement_fingerprint.strip_edges():
		failures.append("resource mining ticket requires non-empty trimmed placement fingerprint")
	if _resource_content_id.is_empty() or _resource_content_id != _resource_content_id.strip_edges():
		failures.append("resource mining ticket requires non-empty trimmed resource ContentId")
	if _operation_ordinal <= 0:
		failures.append("resource mining ticket operation ordinal must be positive")
	var operation_id = StableId.parse(_operation_id)
	if operation_id == null:
		failures.append("resource mining ticket requires canonical operation StableId")
	elif placement_id != null:
		var expected_address = placement_id.address().child([
			"operation",
			"resource.mine",
			"ordinal",
			str(_operation_ordinal),
		])
		var expected_id = StableId.from_address(expected_address)
		if expected_id == null or expected_id.value() != _operation_id:
			failures.append("resource mining ticket operation identity does not match placement ordinal")
	if _cell_address.is_empty() or _cell_address != _cell_address.strip_edges() or not _cell_address.begins_with("gcell1:"):
		failures.append("resource mining ticket requires canonical current cell address text")
	if _cell_generation <= 0:
		failures.append("resource mining ticket cell generation must be positive")
	if _cell_source_fingerprint.is_empty() or _cell_source_fingerprint != _cell_source_fingerprint.strip_edges():
		failures.append("resource mining ticket requires current cell source fingerprint")
	if _cell_provenance_fingerprint.is_empty() or _cell_provenance_fingerprint != _cell_provenance_fingerprint.strip_edges():
		failures.append("resource mining ticket requires current cell provenance fingerprint")
	failures.sort()
	return failures


func canonical_data() -> Dictionary:
	return {
		"placement_stable_id": _placement_stable_id,
		"placement_fingerprint": _placement_fingerprint,
		"resource_content_id": _resource_content_id,
		"operation_id": _operation_id,
		"operation_ordinal": _operation_ordinal,
		"cell_address": _cell_address,
		"cell_generation": _cell_generation,
		"cell_source_fingerprint": _cell_source_fingerprint,
		"cell_provenance_fingerprint": _cell_provenance_fingerprint,
	}
