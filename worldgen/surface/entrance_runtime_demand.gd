extends RefCounted
class_name UnderworldEntranceRuntimeDemand

var entrance_id: String
var cell_addresses: Array
var source_provenance: String
var fingerprint: String


func _init(entrance_id_value: String, cells_value: Array, provenance_value: String = "") -> void:
	entrance_id = entrance_id_value
	cell_addresses = cells_value.duplicate()
	cell_addresses.sort_custom(func(a, b): return a.canonical_text() < b.canonical_text())
	source_provenance = provenance_value
	fingerprint = "entrance-demand1:" + entrance_id + ":" + str(cell_addresses.size()) + ":" + source_provenance


func canonical_data() -> Dictionary:
	var cells: Array = []
	for cell in cell_addresses:
		cells.append(cell.canonical_text())
	return {"entrance_id": entrance_id, "cells": cells, "source_provenance": source_provenance}
