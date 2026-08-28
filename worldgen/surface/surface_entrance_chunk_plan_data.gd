extends RefCounted
class_name UnderworldSurfaceEntranceChunkPlanData

const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")

var chunk_bounds: AABB
var entrance_ids: Array = []
var opening_mask: Array = []
var omitted_triangle_indices: PackedInt32Array
var collision_hole_indices: Array = []
var rim_bounds: AABB
var underground_cells: Array = []
var demand_handoffs: Array = []
var fingerprint: String


func canonical_data() -> Dictionary:
	var cells: Array = []
	for cell in underground_cells:
		cells.append(cell.canonical_text())
	return {
		"chunk_bounds": chunk_bounds,
		"entrance_ids": entrance_ids,
		"opening_mask": opening_mask,
		"omitted_triangle_indices": omitted_triangle_indices,
		"collision_hole_indices": collision_hole_indices,
		"rim_bounds": rim_bounds,
		"underground_cells": cells,
		"demand_handoffs": _canonical_demands(),
	}


func _canonical_demands() -> Array:
	var result: Array = []
	for demand in demand_handoffs:
		result.append(demand.canonical_data() if demand != null and demand.has_method("canonical_data") else demand)
	return result


func finalize_fingerprint() -> void:
	fingerprint = "surface-entrance-chunk1:" + CanonicalValue.fingerprint(canonical_data())
