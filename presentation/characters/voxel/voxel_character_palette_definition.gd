extends Resource
class_name UnderworldVoxelCharacterPaletteDefinition

@export var presentation_id: String = ""
@export var revision: int = 1
@export var entries: Array[Dictionary] = []


func configure(id_value: String, entry_values: Array[Dictionary]) -> Resource:
	presentation_id = id_value
	entries = entry_values.duplicate(true)
	return self


func validate_definition() -> Array[String]:
	var failures: Array[String] = []
	if presentation_id.strip_edges() != presentation_id or presentation_id.is_empty():
		failures.append("palette presentation_id must be non-empty and trimmed")
	if revision <= 0:
		failures.append("palette revision must be positive")
	if entries.is_empty():
		failures.append("palette must contain at least one entry")
	var seen: Dictionary = {}
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var slot: String = str(entry.get("slot", ""))
		if slot.is_empty() or slot != slot.strip_edges():
			failures.append("palette entry %d has invalid slot" % index)
		elif seen.has(slot):
			failures.append("duplicate palette slot: %s" % slot)
		else:
			seen[slot] = true
		if not entry.get("color", null) is Color:
			failures.append("palette entry %d requires Color" % index)
		for property_name in ["roughness", "metallic", "emission"]:
			var value: float = float(entry.get(property_name, 0.0))
			if not is_finite(value) or value < 0.0 or value > 1.0:
				failures.append("palette entry %d %s must be finite in [0,1]" % [index, property_name])
	failures.sort()
	return failures


func entry(index: int) -> Dictionary:
	return entries[index].duplicate(true) if index >= 0 and index < entries.size() else {}


func canonical_fingerprint() -> String:
	var lines: Array[String] = ["voxel-palette-v1", presentation_id, str(revision)]
	for entry_value in entries:
		var entry_data: Dictionary = entry_value
		var color: Color = entry_data.get("color", Color.WHITE)
		lines.append("%s|%.6f,%.6f,%.6f,%.6f|%.6f|%.6f|%.6f" % [
			str(entry_data.get("slot", "")), color.r, color.g, color.b, color.a,
			float(entry_data.get("roughness", 0.0)), float(entry_data.get("metallic", 0.0)),
			float(entry_data.get("emission", 0.0)),
		])
	return "vpalette1:sha256:" + "\n".join(lines).sha256_text()
