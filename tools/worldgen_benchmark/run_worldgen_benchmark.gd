extends SceneTree

const Benchmark := preload("res://tools/worldgen_benchmark/worldgen_benchmark.gd")


func _init() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	if args.has("help"):
		_print_usage()
		quit(0)
		return

	var out_dir: String = str(args.get("out-dir", "user://worldgen_benchmark"))
	var basename: String = str(args.get("basename", "worldgen_benchmark"))
	if not _valid_basename(basename):
		printerr("[WORLDGEN BENCHMARK] invalid basename: %s" % basename)
		quit(2)
		return

	var report: Dictionary = Benchmark.run()
	if not bool(report.get("success", false)):
		var failed: Dictionary = report.get("failed_case", {})
		printerr("[WORLDGEN BENCHMARK] generation failed seed=%s region=%s stage=%s diagnostics=%s" % [
			str(failed.get("seed", "unknown")),
			str(failed.get("region", [])),
			str(failed.get("stage", "unknown")),
			str(failed.get("diagnostics", [])),
		])
		quit(1)
		return

	var directory_error: Error = _ensure_directory(out_dir)
	if directory_error != OK:
		printerr("[WORLDGEN BENCHMARK] cannot create output directory: %s error=%d" % [out_dir, directory_error])
		quit(1)
		return

	var json_path: String = _join(out_dir, basename + ".json")
	var text_path: String = _join(out_dir, basename + ".txt")
	var json_report: Dictionary = report.duplicate(true)
	json_report.erase("text_summary")
	var json_text: String = JSON.stringify(json_report, "\t", true, true) + "\n"
	var text_summary: String = str(report.get("text_summary", ""))

	var json_error: Error = _write_text(json_path, json_text)
	if json_error != OK:
		printerr("[WORLDGEN BENCHMARK] cannot write JSON: %s error=%d" % [json_path, json_error])
		quit(1)
		return
	var text_error: Error = _write_text(text_path, text_summary)
	if text_error != OK:
		printerr("[WORLDGEN BENCHMARK] cannot write text summary: %s error=%d" % [text_path, text_error])
		quit(1)
		return

	print("[WORLDGEN BENCHMARK] PASS")
	print(text_summary.trim_suffix("\n"))
	print("json=%s" % ProjectSettings.globalize_path(json_path))
	print("text=%s" % ProjectSettings.globalize_path(text_path))
	quit(0)


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
	if value.is_empty() or value == "." or value == "..":
		return false
	return not value.contains("/") and not value.contains("\\")


static func _print_usage() -> void:
	print("Underworld deterministic worldgen benchmark")
	print("  godot --headless --path . --script res://tools/worldgen_benchmark/run_worldgen_benchmark.gd -- \\")
	print("    [--out-dir=user://worldgen_benchmark] [--basename=worldgen_benchmark]")
