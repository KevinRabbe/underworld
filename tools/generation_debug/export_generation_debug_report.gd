extends SceneTree

const ReportBuilder := preload("res://tools/generation_debug/generation_debug_report_builder.gd")


func _init() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	if args.has("help"):
		_print_usage()
		quit(0)
		return

	var world_seed: int = int(args.get("seed", "12345"))
	var region_x: int = int(args.get("region-x", "0"))
	var region_z: int = int(args.get("region-z", "0"))
	var out_dir: String = str(args.get("out-dir", "user://generation_debug_reports"))
	var basename: String = str(args.get(
		"basename",
		"generation_debug_seed_%d_region_%d_%d" % [world_seed, region_x, region_z]
	))

	if not _valid_basename(basename):
		printerr("[GENERATION DEBUG] invalid basename: %s" % basename)
		quit(2)
		return

	var built: Dictionary = ReportBuilder.build(world_seed, Vector2i(region_x, region_z))
	var directory_error: Error = _ensure_directory(out_dir)
	if directory_error != OK:
		printerr("[GENERATION DEBUG] cannot create output directory: %s error=%d" % [out_dir, directory_error])
		quit(1)
		return

	var json_path: String = _join(out_dir, basename + ".json")
	var text_path: String = _join(out_dir, basename + ".txt")
	var json_error: Error = _write_text(json_path, str(built.get("json", "")))
	if json_error != OK:
		printerr("[GENERATION DEBUG] cannot write JSON: %s error=%d" % [json_path, json_error])
		quit(1)
		return
	var text_error: Error = _write_text(text_path, str(built.get("text", "")))
	if text_error != OK:
		printerr("[GENERATION DEBUG] cannot write text report: %s error=%d" % [text_path, text_error])
		quit(1)
		return

	var report: Dictionary = built.get("report", {})
	print("[GENERATION DEBUG] PASS")
	print("  seed=%d region=(%d,%d) success=%s retries=%s failure_stage=%s" % [
		world_seed,
		region_x,
		region_z,
		str(report.get("success", false)),
		str(report.get("total_retries", 0)),
		str(report.get("failure_stage", "")),
	])
	print("  json=%s" % ProjectSettings.globalize_path(json_path))
	print("  text=%s" % ProjectSettings.globalize_path(text_path))
	quit(0 if bool(built.get("success", false)) else 1)


static func _parse_args(raw_args: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for raw_value in raw_args:
		var value: String = str(raw_value)
		if not value.begins_with("--"):
			continue
		value = value.substr(2)
		var equals_index: int = value.find("=")
		if equals_index < 0:
			result[value] = "true"
		else:
			result[value.substr(0, equals_index)] = value.substr(equals_index + 1)
	return result


static func _ensure_directory(path: String) -> Error:
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


static func _write_text(path: String, text: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK


static func _join(root: String, filename: String) -> String:
	return root.trim_suffix("/") + "/" + filename


static func _valid_basename(value: String) -> bool:
	return not value.is_empty() and value != "." and value != ".." and not value.contains("/") and not value.contains("\\")


static func _print_usage() -> void:
	print("Underworld generation debug report exporter")
	print("  godot --headless --path . --script res://tools/generation_debug/export_generation_debug_report.gd -- \\")
	print("    --seed=12345 --region-x=0 --region-z=0 [--out-dir=user://generation_debug_reports] [--basename=name]")
