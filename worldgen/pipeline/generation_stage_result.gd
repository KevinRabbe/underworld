extends RefCounted
class_name UnderworldGenerationStageResult

const SCRIPT_PATH: String = "res://worldgen/pipeline/generation_stage_result.gd"

var stage_name: String
var success: bool
var data
var diagnostics: Array[String] = []
var fingerprint: String
var provenance


func _init(
	stage_name_value: String,
	success_value: bool,
	data_value = null,
	diagnostics_value: Array[String] = [],
	fingerprint_value: String = "",
	provenance_value = null
) -> void:
	stage_name = stage_name_value
	success = success_value
	data = data_value
	diagnostics = diagnostics_value.duplicate()
	fingerprint = fingerprint_value
	provenance = provenance_value


static func ok(stage_name_value: String, data_value = null, fingerprint_value: String = "", provenance_value = null):
	var no_diagnostics: Array[String] = []
	return load(SCRIPT_PATH).new(
		stage_name_value,
		true,
		data_value,
		no_diagnostics,
		fingerprint_value,
		provenance_value
	)


static func fail(stage_name_value: String, diagnostics_value: Array[String]):
	return load(SCRIPT_PATH).new(
		stage_name_value,
		false,
		null,
		diagnostics_value,
		""
	)
