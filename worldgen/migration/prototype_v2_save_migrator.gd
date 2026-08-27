extends RefCounted
class_name UnderworldPrototypeV2SaveMigrator

const LegacyResolverScript := preload("res://worldgen/migration/legacy_v2_surface_resolver.gd")
const GeneratorManifestScript := preload("res://worldgen/versioning/generator_manifest.gd")
const WorldIdScript := preload("res://worldgen/identity/world_id.gd")

const LEGACY_SAVE_VERSION: int = 2
const MODERN_SAVE_SCHEMA_VERSION: int = 3


func migrate(
	legacy_save: Dictionary,
	world_settings: UnderworldWorldSettings,
	generator_manifest = null
) -> Dictionary:
	var diagnostics: Array[String] = []
	var unresolved: Array[Dictionary] = []

	if int(legacy_save.get("version", -1)) != LEGACY_SAVE_VERSION:
		return _failure("input is not a prototype-v2 save")
	if world_settings == null:
		return _failure("world settings are required for legacy generation replay")

	var world_seed: int = int(legacy_save.get("world_seed", -1))
	if world_seed != world_settings.world_seed:
		return _failure(
			"save seed %d does not match configured legacy generator seed %d" % [
				world_seed,
				world_settings.world_seed,
			]
		)

	var manifest = generator_manifest
	if manifest == null:
		manifest = GeneratorManifestScript.foundation_default()
	var manifest_failures: Array[String] = manifest.validate()
	if not manifest_failures.is_empty():
		return {
			"success": false,
			"save": {},
			"unresolved_legacy_ids": [],
			"diagnostics": manifest_failures,
		}

	var resolver = LegacyResolverScript.new()
	resolver.configure(world_settings)

	var destroyed_list: Array = legacy_save.get("destroyed_objects", [])
	var ids_by_chunk: Dictionary = {}
	for id_variant in destroyed_list:
		var legacy_id: String = str(id_variant)
		var parsed: Dictionary = LegacyResolverScript.parse_legacy_id(legacy_id)
		if parsed.is_empty():
			unresolved.append({
				"legacy_id": legacy_id,
				"reason": "invalid legacy v2 object ID",
			})
			continue
		var chunk_key: String = "%d:%d" % [int(parsed["chunk_x"]), int(parsed["chunk_z"])]
		if not ids_by_chunk.has(chunk_key):
			ids_by_chunk[chunk_key] = {
				"coord": Vector2i(int(parsed["chunk_x"]), int(parsed["chunk_z"])),
				"ids": [],
			}
		ids_by_chunk[chunk_key]["ids"].append(legacy_id)

	var migrated_ids: Array[String] = []
	var chunk_keys: Array = ids_by_chunk.keys()
	chunk_keys.sort()
	for chunk_key_variant in chunk_keys:
		var chunk_key: String = str(chunk_key_variant)
		var group: Dictionary = ids_by_chunk[chunk_key]
		var chunk_map_result: Dictionary = resolver.build_chunk_index_map(group["coord"])
		var chunk_diagnostics: Array = chunk_map_result.get("diagnostics", [])
		if not chunk_diagnostics.is_empty():
			for diagnostic_variant in chunk_diagnostics:
				diagnostics.append(str(diagnostic_variant))
			for legacy_id_variant in group["ids"]:
				unresolved.append({
					"legacy_id": str(legacy_id_variant),
					"reason": "legacy generation replay mismatch; migration refused for chunk",
				})
			continue

		var mapping: Dictionary = chunk_map_result["mapping"]
		for legacy_id_variant in group["ids"]:
			var legacy_id: String = str(legacy_id_variant)
			if mapping.has(legacy_id):
				migrated_ids.append(str(mapping[legacy_id]))
			else:
				unresolved.append({
					"legacy_id": legacy_id,
					"reason": "accepted index does not resolve under frozen legacy-v2 generation",
				})

	migrated_ids.sort()
	migrated_ids = _deduplicate_sorted(migrated_ids)

	var world_id = WorldIdScript.from_seed(world_seed)
	var modern_save: Dictionary = {
		"save_schema_version": MODERN_SAVE_SCHEMA_VERSION,
		"world": {
			"world_seed": world_seed,
			"world_id": world_id.value(),
			"generator_manifest_id": manifest.manifest_id(),
			"generator_manifest_canonical": manifest.canonical_text(),
		},
		"player": {
			"wood": int(legacy_save.get("wood", 0)),
			"stone": int(legacy_save.get("stone", 0)),
			"stone_axe": bool(legacy_save.get("stone_axe", false)),
			"stone_pickaxe": bool(legacy_save.get("stone_pickaxe", false)),
			"selected_slot": clampi(int(legacy_save.get("selected_slot", 1)), 1, 3),
		},
		"deltas": {
			"destroyed_objects": migrated_ids,
			"object_state": {},
			"special_location_state": {},
			"terrain_delta_index": {},
			"player_created_objects": {},
		},
		"migration": {
			"from_save_version": LEGACY_SAVE_VERSION,
			"unresolved_legacy_objects": unresolved,
		},
	}

	return {
		"success": true,
		"save": modern_save,
		"unresolved_legacy_ids": unresolved,
		"diagnostics": diagnostics,
	}


static func _deduplicate_sorted(values: Array[String]) -> Array[String]:
	var unique: Array[String] = []
	var previous: String = ""
	var has_previous: bool = false
	for value in values:
		if not has_previous or value != previous:
			unique.append(value)
			previous = value
			has_previous = true
	return unique


static func _failure(reason: String) -> Dictionary:
	return {
		"success": false,
		"save": {},
		"unresolved_legacy_ids": [],
		"diagnostics": [reason],
	}
