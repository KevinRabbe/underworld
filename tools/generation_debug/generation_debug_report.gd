extends RefCounted
class_name UnderworldGenerationDebugReport

const SCHEMA: String = "underworld-generation-debug-report-v1"

var world_seed: int
var world_id: String
var generator_manifest_id: String
var region_coord: Vector2i
var parameters: Dictionary = {}
var stages: Array[Dictionary] = []


func _init(context, region_coord_value: Vector2i, parameters_value: Dictionary = {}) -> void:
	world_seed = int(context.world_seed)
	world_id = str(context.world_id)
	generator_manifest_id = str(context.generator_manifest_id)
	region_coord = region_coord_value
	parameters = parameters_value.duplicate(true)


func record_stage(stage_result, retry_count: int = 0, important_parameters: Dictionary = {}) -> void:
	var diagnostics: Array[String] = []
	for diagnostic in stage_result.diagnostics:
		diagnostics.append(str(diagnostic))
	stages.append({
		"index": stages.size(),
		"stage": str(stage_result.stage_name),
		"success": bool(stage_result.success),
		"retry_count": maxi(retry_count, 0),
		"fingerprint": str(stage_result.fingerprint),
		"diagnostics": diagnostics,
		"parameters": important_parameters.duplicate(true),
	})


func is_success() -> bool:
	if stages.is_empty():
		return false
	for stage in stages:
		if not bool(stage.get("success", false)):
			return false
	return true


func failure_stage() -> String:
	for stage in stages:
		if not bool(stage.get("success", false)):
			return str(stage.get("stage", ""))
	return ""


func total_retries() -> int:
	var result: int = 0
	for stage in stages:
		result += int(stage.get("retry_count", 0))
	return result


func to_dictionary() -> Dictionary:
	return {
		"schema": SCHEMA,
		"world_seed": world_seed,
		"world_id": world_id,
		"generator_manifest_id": generator_manifest_id,
		"region_coord": [region_coord.x, region_coord.y],
		"success": is_success(),
		"failure_stage": failure_stage(),
		"total_retries": total_retries(),
		"parameters": parameters.duplicate(true),
		"stages": stages.duplicate(true),
	}


func to_json() -> String:
	return JSON.stringify(to_dictionary(), "\t", true, true) + "\n"


func to_text() -> String:
	var lines := PackedStringArray()
	lines.append("Underworld Generation Debug Report")
	lines.append("seed=%d world_id=%s region=(%d,%d)" % [
		world_seed, world_id, region_coord.x, region_coord.y,
	])
	lines.append("manifest=%s success=%s retries=%d failure_stage=%s" % [
		generator_manifest_id,
		str(is_success()),
		total_retries(),
		failure_stage() if not failure_stage().is_empty() else "none",
	])
	lines.append("parameters=%s" % JSON.stringify(parameters, "", true, true))
	for stage in stages:
		lines.append("[%d] %s success=%s retries=%d fingerprint=%s" % [
			int(stage.get("index", -1)),
			str(stage.get("stage", "")),
			str(stage.get("success", false)),
			int(stage.get("retry_count", 0)),
			str(stage.get("fingerprint", "")),
		])
		var stage_parameters: Dictionary = stage.get("parameters", {})
		if not stage_parameters.is_empty():
			lines.append("    parameters=%s" % JSON.stringify(stage_parameters, "", true, true))
		for diagnostic in stage.get("diagnostics", []):
			lines.append("    diagnostic=%s" % str(diagnostic))
	return "\n".join(lines) + "\n"
