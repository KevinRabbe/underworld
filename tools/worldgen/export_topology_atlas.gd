extends SceneTree

const AtlasBuilder := preload("res://tools/worldgen/topology_atlas_builder.gd")
const AtlasSvg := preload("res://tools/worldgen/topology_atlas_svg.gd")
const ElevationSvg := preload("res://tools/worldgen/topology_elevation_svg.gd")


func _init() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	if args.has("help"):
		_print_usage()
		quit(0)
		return

	var world_seed: int = int(args.get("seed", "12345"))
	var center_x: int = int(args.get("center-x", "0"))
	var center_z: int = int(args.get("center-z", "0"))
	var radius: int = int(args.get("radius", "1"))
	var out_dir: String = str(args.get("out-dir", "user://worldgen_snapshots"))
	var basename: String = str(args.get(
		"basename",
		"topology_atlas_seed_%d_center_%d_%d_r%d" % [world_seed, center_x, center_z, radius]
	))

	if not _valid_basename(basename):
		printerr("[WORLDGEN ATLAS] invalid basename: %s" % basename)
		quit(2)
		return

	var built: Dictionary = AtlasBuilder.build(world_seed, Vector2i(center_x, center_z), radius)
	if not bool(built.get("success", false)):
		printerr("[WORLDGEN ATLAS] generation failed diagnostics=%s" % str(built.get("diagnostics", [])))
		quit(1)
		return

	var directory_error: Error = _ensure_directory(out_dir)
	if directory_error != OK:
		printerr("[WORLDGEN ATLAS] cannot create output directory: %s error=%d" % [out_dir, directory_error])
		quit(1)
		return

	var atlas: Dictionary = built["atlas"]
	var json_text: String = JSON.stringify(atlas, "\t", true, true) + "\n"
	var svg_text: String = AtlasSvg.render(atlas)
	var elevation_x_text: String = ElevationSvg.render(atlas, "x")
	var elevation_z_text: String = ElevationSvg.render(atlas, "z")
	var json_path: String = _join(out_dir, basename + ".json")
	var svg_path: String = _join(out_dir, basename + ".svg")
	var elevation_x_path: String = _join(out_dir, basename + ".elevation_x.svg")
	var elevation_z_path: String = _join(out_dir, basename + ".elevation_z.svg")

	var json_error: Error = _write_text(json_path, json_text)
	if json_error != OK:
		printerr("[WORLDGEN ATLAS] cannot write JSON: %s error=%d" % [json_path, json_error])
		quit(1)
		return
	var svg_error: Error = _write_text(svg_path, svg_text)
	if svg_error != OK:
		printerr("[WORLDGEN ATLAS] cannot write top-down SVG: %s error=%d" % [svg_path, svg_error])
		quit(1)
		return
	var elevation_x_error: Error = _write_text(elevation_x_path, elevation_x_text)
	if elevation_x_error != OK:
		printerr("[WORLDGEN ATLAS] cannot write X/depth SVG: %s error=%d" % [elevation_x_path, elevation_x_error])
		quit(1)
		return
	var elevation_z_error: Error = _write_text(elevation_z_path, elevation_z_text)
	if elevation_z_error != OK:
		printerr("[WORLDGEN ATLAS] cannot write Z/depth SVG: %s error=%d" % [elevation_z_path, elevation_z_error])
		quit(1)
		return

	var totals: Dictionary = atlas.get("totals", {})
	print("[WORLDGEN ATLAS] PASS")
	print("  seed=%d center=(%d,%d) radius=%d" % [world_seed, center_x, center_z, radius])
	print("  regions=%s networks=%s nodes=%s edges=%s boundary_candidates=%s" % [
		str(totals.get("region_count", 0)),
		str(totals.get("network_count", 0)),
		str(totals.get("node_count", 0)),
		str(totals.get("edge_count", 0)),
		str(totals.get("boundary_candidate_count", 0)),
	])
	print("  json=%s" % ProjectSettings.globalize_path(json_path))
	print("  top_down_svg=%s" % ProjectSettings.globalize_path(svg_path))
	print("  elevation_x_svg=%s" % ProjectSettings.globalize_path(elevation_x_path))
	print("  elevation_z_svg=%s" % ProjectSettings.globalize_path(elevation_z_path))
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
	print("Underworld topology atlas exporter")
	print("  godot --headless --path . --script res://tools/worldgen/export_topology_atlas.gd -- \\")
	print("    --seed=12345 --center-x=0 --center-z=0 --radius=1 [--out-dir=user://worldgen_snapshots] [--basename=name]")
	print("  radius=0 renders one region; radius=1 renders 3x3; maximum radius=4 renders 9x9")
	print("  outputs: JSON, top-down SVG, X/depth SVG, Z/depth SVG")
