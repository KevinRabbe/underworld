extends SceneTree

const StableIdAudit := preload("res://tools/stable_id_audit/stable_id_audit.gd")


func _init() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	if args.has("help"):
		_print_usage()
		quit(0)
		return

	var out_dir: String = str(args.get("out-dir", "user://stable_id_audit"))
	var basename: String = str(args.get("basename", "stable_id_audit"))
	if not _valid_basename(basename):
		printerr("[STABLE ID AUDIT] invalid basename: %s" % basename)
		quit(2)
		return

	var report: Dictionary = StableIdAudit.new().run()
	var text_summary: String = _text_summary(report)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(out_dir)
	)
	if directory_error != OK:
		printerr("[STABLE ID AUDIT] cannot create output directory: %s error=%d" % [out_dir, directory_error])
		quit(1)
		return

	var json_path: String = _join(out_dir, basename + ".json")
	var text_path: String = _join(out_dir, basename + ".txt")
	var json_error: Error = _write_text(
		json_path,
		JSON.stringify(report, "\t", true, true) + "\n"
	)
	if json_error != OK:
		printerr("[STABLE ID AUDIT] cannot write JSON: %s error=%d" % [json_path, json_error])
		quit(1)
		return
	var text_error: Error = _write_text(text_path, text_summary)
	if text_error != OK:
		printerr("[STABLE ID AUDIT] cannot write text summary: %s error=%d" % [text_path, text_error])
		quit(1)
		return

	if not bool(report.get("success", false)):
		printerr("[STABLE ID AUDIT] FAIL")
		printerr(text_summary.trim_suffix("\n"))
		quit(1)
		return

	print("[STABLE ID AUDIT] PASS")
	print(text_summary.trim_suffix("\n"))
	print("json=%s" % ProjectSettings.globalize_path(json_path))
	print("text=%s" % ProjectSettings.globalize_path(text_path))
	quit(0)


static func _text_summary(report: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("Underworld StableAddress / StableId large-corpus audit")
	lines.append("corpus=%s cases=%d expected=%d reproduction_checks=%d endpoint_order_checks=%d" % [
		str(report.get("corpus_revision", "unknown")),
		int(report.get("case_count", 0)),
		int(report.get("expected_case_count", 0)),
		int(report.get("reproduction_checks", 0)),
		int(report.get("endpoint_order_checks", 0)),
	])
	var family_counts: Dictionary = report.get("family_counts", {})
	for family in family_counts.keys():
		lines.append("%s=%d" % [str(family), int(family_counts[family])])
	lines.append("collisions=%d failures=%d" % [
		int(report.get("collision_count", 0)),
		int(report.get("failure_count", 0)),
	])
	var failures: Array = report.get("failures", [])
	for failure in failures:
		lines.append("FAIL: %s" % str(failure))
	return "\n".join(lines) + "\n"


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
	print("Underworld StableAddress / StableId large-corpus audit")
	print("  godot --headless --path . --script res://tools/stable_id_audit/run_stable_id_audit.gd -- \\")
	print("    [--out-dir=user://stable_id_audit] [--basename=stable_id_audit]")
