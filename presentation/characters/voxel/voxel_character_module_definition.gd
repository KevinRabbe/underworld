extends Resource
class_name UnderworldVoxelCharacterModuleDefinition

const CharacterSemanticSchemaCatalog := preload("res://presentation/characters/animation/character_semantic_schema_catalog.gd")

@export var presentation_id: String = ""
@export var revision: int = 1
@export var slot_id: StringName = &""
@export var parts: Array[Dictionary] = []


func configure(id_value: String, slot_value: StringName, part_values: Array[Dictionary]) -> Resource:
	presentation_id = id_value
	slot_id = slot_value
	parts = part_values.duplicate(true)
	return self


func validate_definition(palette_size: int) -> Array[String]:
	var failures: Array[String] = []
	if presentation_id.is_empty() or presentation_id != presentation_id.strip_edges():
		failures.append("module presentation_id must be non-empty and trimmed")
	if revision <= 0:
		failures.append("module revision must be positive")
	if slot_id == &"":
		failures.append("module slot_id must be non-empty")
	if parts.is_empty():
		failures.append("module must contain at least one rigid part")
	var role_registry = CharacterSemanticSchemaCatalog.build_registry()
	var part_ids: Dictionary = {}
	for part_index in range(parts.size()):
		var part: Dictionary = parts[part_index]
		var part_id: String = str(part.get("part_id", ""))
		if part_id.is_empty() or part_ids.has(part_id):
			failures.append("module part id must be non-empty and unique: %s" % part_id)
		part_ids[part_id] = true
		var rig_role: String = str(part.get("rig_role", ""))
		if not role_registry.has_rig_role(rig_role):
			failures.append("module part has unknown rig role: %s" % rig_role)
		if not part.get("pivot", null) is Vector3i:
			failures.append("module part %s requires integer pivot" % part_id)
		if not part.get("attachment_offset", Vector3.ZERO) is Vector3:
			failures.append("module part %s requires Vector3 attachment_offset" % part_id)
		var cells: Array = part.get("cells", [])
		if cells.is_empty():
			failures.append("module part %s must contain cells" % part_id)
		var occupied: Dictionary = {}
		for cell_index in range(cells.size()):
			var cell: Dictionary = cells[cell_index]
			if not cell.get("position", null) is Vector3i:
				failures.append("module part %s cell %d requires Vector3i position" % [part_id, cell_index])
				continue
			var position: Vector3i = cell["position"]
			var key: String = "%d,%d,%d" % [position.x, position.y, position.z]
			if occupied.has(key):
				failures.append("module part %s contains duplicate cell %s" % [part_id, key])
			occupied[key] = true
			var palette_index: int = int(cell.get("palette_index", -1))
			if palette_index < 0 or palette_index >= palette_size:
				failures.append("module part %s cell %s has invalid palette index %d" % [part_id, key, palette_index])
	failures.sort()
	return failures


func canonical_fingerprint() -> String:
	var lines: Array[String] = ["voxel-module-v1", presentation_id, str(revision), str(slot_id)]
	var part_lines: Array[String] = []
	for part_value in parts:
		var part: Dictionary = part_value
		var pivot: Vector3i = part.get("pivot", Vector3i.ZERO)
		var offset: Vector3 = part.get("attachment_offset", Vector3.ZERO)
		var header := "%s|%s|%d,%d,%d|%.6f,%.6f,%.6f" % [
			str(part.get("part_id", "")), str(part.get("rig_role", "")),
			pivot.x, pivot.y, pivot.z, offset.x, offset.y, offset.z,
		]
		var cell_lines: Array[String] = []
		for cell_value in part.get("cells", []):
			var cell: Dictionary = cell_value
			var position: Vector3i = cell.get("position", Vector3i.ZERO)
			cell_lines.append("%d,%d,%d:%d" % [position.x, position.y, position.z, int(cell.get("palette_index", -1))])
		cell_lines.sort()
		part_lines.append(header + "|" + ";".join(cell_lines))
	part_lines.sort()
	lines.append_array(part_lines)
	return "vmodule1:sha256:" + "\n".join(lines).sha256_text()
