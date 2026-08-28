extends RefCounted
class_name UnderworldEntranceTraversalGate

var entrance_id: String
var required_cells: Array
var open: bool = false
var diagnostics: Array[String] = []


func _init(entrance_id_value: String, required_cells_value: Array = []) -> void:
	entrance_id = entrance_id_value
	required_cells = required_cells_value.duplicate()
	required_cells.sort_custom(func(a, b): return a.canonical_text() < b.canonical_text())


func update(streamer) -> bool:
	diagnostics.clear()
	var ready := not required_cells.is_empty()
	if required_cells.is_empty():
		diagnostics.append("no validated destination collision cells")
	for address in required_cells:
		var key: String = address.canonical_text()
		var record = streamer.records.get(key)
		if record == null or bool(record.release_pending) or not bool(record.readiness.get("collision", false)) or record.collision_handle == null:
			ready = false
			diagnostics.append("collision not ready: " + key)
	open = ready
	return open


func close() -> void:
	open = false


func is_open() -> bool:
	return open
