extends RefCounted
class_name UnderworldGeometryCellPartitionResult

const CanonicalValue := preload("res://worldgen/validation/canonical_value.gd")
const Plan := preload("res://worldgen/geometry/geometry_cell_plan.gd")

var plans: Array
var cell_plans: Array
var configuration_fingerprint: String
var source_geometry_fingerprint: String
var source_finalization_fingerprint: String
var metrics: Dictionary
var diagnostics: Array[String]
var fingerprint: String
var provenance


func _init(
	plans_value: Array,
	configuration_fingerprint_value: String,
	geometry_fingerprint_value: String,
	finalization_fingerprint_value: String,
	metrics_value: Dictionary = {},
	diagnostics_value: Array[String] = [],
	provenance_value = null
) -> void:
	plans = plans_value.duplicate()
	cell_plans = plans
	configuration_fingerprint = configuration_fingerprint_value
	source_geometry_fingerprint = geometry_fingerprint_value
	source_finalization_fingerprint = finalization_fingerprint_value
	metrics = metrics_value.duplicate(true)
	diagnostics = diagnostics_value.duplicate()
	provenance = provenance_value
	var plan_data: Array = []
	for plan in plans:
		if plan is Plan:
			plan_data.append(plan.canonical_data())
	fingerprint = "gpartition-result1:" + CanonicalValue.fingerprint({
		"configuration_fingerprint": configuration_fingerprint,
		"source_geometry_fingerprint": source_geometry_fingerprint,
		"source_finalization_fingerprint": source_finalization_fingerprint,
		"plans": plan_data,
		"metrics": metrics,
	})


func canonical_data() -> Dictionary:
	var plan_data: Array = []
	for plan in plans:
		plan_data.append(plan.canonical_data())
	return {
		"configuration_fingerprint": configuration_fingerprint,
		"source_geometry_fingerprint": source_geometry_fingerprint,
		"source_finalization_fingerprint": source_finalization_fingerprint,
		"plans": plan_data,
		"metrics": metrics,
	}
