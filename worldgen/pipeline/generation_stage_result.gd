extends RefCounted
class_name UnderworldGenerationStageResult

var stage_name: String
var success: bool
var data
var diagnostics: Array[String] = []
var fingerprint: String


func _init(
	stage_name_value: String,
	success_value: bool,
	data_value = null,
	diagnostics_value: Array[String] = [],
	fingerprint_value: String = ""
) -> void:
	stage_name = stage_name_value
	success = success_value
	data = data_value
	diagnostics = diagnostics_value.duplicate()
	fingerprint = fingerprint_value


static func ok(stage_name_value: String, data_value = null, fingerprint_value: String = ""):
	return UnderworldGenerationStageResult.new(
		stage_name_value,
		true,
		data_value,
		[],
		fingerprint_value
	)


static func fail(stage_name_value: String, diagnostics_value: Array[String]):
	return UnderworldGenerationStageResult.new(
		stage_name_value,
		false,
		null,
		diagnostics_value,
		""
	)
