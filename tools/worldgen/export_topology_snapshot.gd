extends SceneTree

const SnapshotBuilder := preload("res://tools/worldgen/topology_snapshot_builder.gd")
const SnapshotSvg := preload("res://tools/worldgen/topology_snapshot_svg.gd")


func _init() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	if args.has("help"):
		_print_usage()
		quit(0)
		return

	var world_seed: int = int(args.get("seed", "12345"))
	var region_x: int = int(args.get("region-x", "0"))
	var region_z: int = int(args.get("region-z", "0"))
	var out_dir: String = str(args.get("out-dir", "user://worldgen_snapshots"))
	var basename: String = str(args.get(
		"basename",
		"topology_seed_%d_region_%d_%d" % [world_seed, region_x, region_z]
	))

	if not _valid_basename(basename):
		printerr("[WORLDGEN SNAPSHOT] invalid basename: %s" % basename)
		quit(2)
		return

	var built: Dictionary = SnapshotBuilder.build(world_seed, Vector2i(region_x, region_z))
	if not bool(built.get("success", false)):
		printerr("[WORLDGEN SNAPSHOT] generation failed stage=%s diagnostics=%s" % [
			str(built.get("stage", "unknown")),
			str(built.get("diagnostics", [])),
		])
		quit(1)
		return

	var directory_error: Error = _ensure_directory(out_dir)
	if directory_error != OK:
		printerr("[WORLDGEN SNAPSHOT] cannot create output directory: %s error=%d" % [out_dir, directory_error])
		quit(1)
		return

	var snapshot: Dictionary = built["snapshot"]
	var json_text: String = JSON.stringify(snapshot, "\t", true, true) + "\n"
	var svg_text: String = SnapshotSvg.render(snapshot)
	var json_path: String = _join(out_dir, basename + ".json")
	var svg_path: String = _join(out_dir, basename + ".svg")

	var json_error: Error = _write_text(json_path, json_text)
	if json_error != OK:
		printerr("[WORLDGEN SNAPSHOT] cannot write JSON: %s error=%d" % [json_path, json_error])
		quit(1)
		return
	var svg_error: Error = _write_text(svg_path, svg_text)
	if svg_error != OK:
		printerr("[WORLDGEN SNAPSHOT] cannot write SVG: %s error=%d" % [svg_path, svg_error])
		quit(1)
		return

	print("[WORLDGEN SNAPSHOT] PASS")
	print("  seed=%d region=(%d,%d)" % [world_seed, region_x, region_z])
	print("  topology_fingerprint=%s" % str(built["topology_fingerprint"]))
	print("  json=%s" % ProjectSettings.globalize_path(json_path))
	print("  svg=%s" % ProjectSettings.globalize_path(svg_path))
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
	var absolute: String = ProjectSettings.globalize_path(path)
	return DirAccess.make_dir_recursive_absolute(absolute)


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
	if value.contains("/") or value.contains("\\"):
		return false
	return true


static func _print_usage() -> void:
	print("Underworld topology snapshot exporter")
	print("  godot --headless --path . --script res://tools/worldgen/export_topology_snapshot.gd -- \\")
	print("    --seed=12345 --region-x=0 --region-z=0 [--out-dir=user://worldgen_snapshots] [--basename=name]")
