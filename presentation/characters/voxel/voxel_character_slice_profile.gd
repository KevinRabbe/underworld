extends Resource
class_name UnderworldVoxelCharacterSliceProfile

## Deterministic bottom-to-top authoring contract. A row contains rectangular
## ASCII masks (one string per Z line, one character per X cell). Higher
## priority layers overlay lower layers at the same grid cell.

@export var profile_id: String = ""
@export var revision: int = 1
@export var row_count: int = 56
@export var voxel_size: float = 0.032142857
@export var rows: Array[Dictionary] = []


func configure(id_value: String, row_values: Array[Dictionary], pitch: float = voxel_size) -> Resource:
	profile_id = id_value
	rows = row_values.duplicate(true)
	voxel_size = pitch
	row_count = rows.size()
	return self


func validate(palette_size: int) -> Array[String]:
	var failures: Array[String] = []
	if profile_id.is_empty() or profile_id != profile_id.strip_edges():
		failures.append("slice profile_id must be non-empty and trimmed")
	if revision <= 0:
		failures.append("slice revision must be positive")
	if not is_finite(voxel_size) or voxel_size <= 0.0:
		failures.append("slice voxel_size must be finite and positive")
	if row_count <= 0 or rows.size() != row_count:
		failures.append("slice row_count must match non-empty rows")
	var seen_rows: Dictionary = {}
	for row_value in rows:
		var row: Dictionary = row_value
		var y: int = int(row.get("y", -1))
		if y < 0 or y >= row_count or seen_rows.has(y):
			failures.append("slice row y must be unique and within row_count: %d" % y)
		seen_rows[y] = true
		var layers: Array = row.get("layers", [])
		if layers.is_empty():
			failures.append("slice row %d requires at least one layer" % y)
		var layer_ids: Dictionary = {}
		for layer_value in layers:
			var layer: Dictionary = layer_value
			var layer_id := str(layer.get("layer_id", ""))
			if layer_id.is_empty() or layer_ids.has(layer_id):
				failures.append("slice row %d layer id must be non-empty and unique" % y)
			layer_ids[layer_id] = true
			var mask: Array = layer.get("mask", [])
			if mask.is_empty():
				failures.append("slice row %d layer %s requires a mask" % [y, layer_id])
				continue
			var width := -1
			for line_value in mask:
				var line := str(line_value)
				if line.is_empty() or (width >= 0 and line.length() != width):
					failures.append("slice row %d layer %s mask must be rectangular" % [y, layer_id])
				width = line.length()
			var palette_index := int(layer.get("palette_index", -1))
			if palette_index < 0 or palette_index >= palette_size:
				failures.append("slice row %d layer %s has invalid palette index" % [y, layer_id])
	failures.sort()
	return failures


func resolved_cells() -> Array[Dictionary]:
	var cells_by_key: Dictionary = {}
	var ordered_rows := rows.duplicate(true)
	ordered_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("y", 0)) < int(b.get("y", 0)))
	for row_value in ordered_rows:
		var row: Dictionary = row_value
		var layers: Array = row.get("layers", []).duplicate(true)
		layers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var priority_a := int(a.get("priority", 0))
			var priority_b := int(b.get("priority", 0))
			return priority_a < priority_b or (priority_a == priority_b and str(a.get("layer_id", "")) < str(b.get("layer_id", "")))
		)
		for layer_value in layers:
			var layer: Dictionary = layer_value
			var mask: Array = layer.get("mask", [])
			for z in range(mask.size()):
				var line := str(mask[z])
				for x in range(line.length()):
					if line[x] == ".":
						continue
					var key := "%d,%d,%d" % [x, int(row.get("y", 0)), z]
					cells_by_key[key] = {"position": Vector3i(x, int(row.get("y", 0)), z), "palette_index": int(layer.get("palette_index", -1)), "layer_id": str(layer.get("layer_id", "")), "semantic": str(layer.get("semantic", "body"))}
	var keys: Array[String] = []
	for key in cells_by_key.keys(): keys.append(str(key))
	keys.sort()
	var result: Array[Dictionary] = []
	for key in keys: result.append(cells_by_key[key])
	return result


func canonical_fingerprint() -> String:
	var lines: Array[String] = ["voxel-slice-profile-v1", profile_id, str(revision), str(row_count), "%.9f" % voxel_size]
	var canonical_rows: Array[String] = []
	for row_value in rows:
		var row: Dictionary = row_value
		var layers: Array[String] = []
		for layer_value in row.get("layers", []):
			var layer: Dictionary = layer_value
			layers.append("%s|%d|%d|%s|%s" % [str(layer.get("layer_id", "")), int(layer.get("priority", 0)), int(layer.get("palette_index", -1)), str(layer.get("semantic", "body")), ";".join(Array(layer.get("mask", [])))])
		layers.sort()
		canonical_rows.append("%d:%s" % [int(row.get("y", -1)), ";".join(layers)])
	canonical_rows.sort()
	lines.append_array(canonical_rows)
	return "vslice1:sha256:" + "\n".join(lines).sha256_text()
