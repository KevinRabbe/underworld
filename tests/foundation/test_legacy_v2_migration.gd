extends RefCounted

const SurfaceSettingsScript := preload("res://worldgen/surface/prototype_surface_settings.gd")
const LegacyResolverScript := preload("res://worldgen/migration/legacy_v2_surface_resolver.gd")
const MigratorScript := preload("res://worldgen/migration/prototype_v2_save_migrator.gd")
const StableIdScript := preload("res://worldgen/identity/stable_id.gd")
const WorldIdScript := preload("res://worldgen/identity/world_id.gd")

const FIXTURE_PATH: String = "res://tests/fixtures/prototype_v2_state.json"


static func run() -> Array[String]:
	var failures: Array[String] = []
	var fixture: Dictionary = _load_fixture(failures)
	if fixture.is_empty():
		return failures

	var settings = SurfaceSettingsScript.new()
	settings.world_seed = int(fixture["world_seed"])

	var resolver = LegacyResolverScript.new()
	resolver.configure(settings)

	var selected_legacy_ids: Array[String] = []
	_collect_chunk_ids(resolver, Vector2i.ZERO, 4, selected_legacy_ids, failures)
	_collect_chunk_ids(resolver, Vector2i(-1, 0), 4, selected_legacy_ids, failures)

	if selected_legacy_ids.size() < 4:
		failures.append(
			"legacy migration fixture could not find enough generated v2 objects; got %d" %
			selected_legacy_ids.size()
		)
		return failures

	var saw_negative_chunk: bool = false
	for legacy_id in selected_legacy_ids:
		var parsed: Dictionary = LegacyResolverScript.parse_legacy_id(legacy_id)
		if not parsed.is_empty() and int(parsed["chunk_x"]) < 0:
			saw_negative_chunk = true
			break
	if not saw_negative_chunk:
		failures.append("legacy migration fixture did not exercise negative chunk coordinates")

	var legacy_save: Dictionary = fixture.duplicate(true)
	var destroyed: Array = []
	for legacy_id in selected_legacy_ids:
		destroyed.append(legacy_id)
	# Duplicate input must not create duplicate modern deltas.
	destroyed.append(selected_legacy_ids[0])
	# Mathematically impossible accepted index is quarantined before terrain replay.
	destroyed.append("999:999:tree:999999")
	legacy_save["destroyed_objects"] = destroyed

	var migrator = MigratorScript.new()
	var first: Dictionary = migrator.migrate(legacy_save, settings)
	var second: Dictionary = migrator.migrate(legacy_save, settings)

	if not bool(first.get("success", false)):
		failures.append("prototype-v2 migration failed: %s" % first.get("diagnostics", []))
		return failures
	if not bool(second.get("success", false)):
		failures.append("prototype-v2 repeat migration failed")
		return failures

	var modern: Dictionary = first["save"]
	if int(modern.get("save_schema_version", -1)) != 3:
		failures.append("prototype-v2 migration did not produce save schema 3")

	var player: Dictionary = modern.get("player", {})
	for key in ["wood", "stone", "stone_axe", "stone_pickaxe", "selected_slot"]:
		if player.get(key) != fixture.get(key):
			failures.append(
				"prototype-v2 migration changed player field %s: expected=%s actual=%s" % [
					key,
					fixture.get(key),
					player.get(key),
				]
			)

	var world: Dictionary = modern.get("world", {})
	if WorldIdScript.parse(str(world.get("world_id", ""))) == null:
		failures.append("prototype-v2 migration produced invalid WorldId")
	if not str(world.get("generator_manifest_id", "")).begins_with("gm-sha256:"):
		failures.append("prototype-v2 migration did not pin a generator manifest")

	var migrated_ids: Array = modern.get("deltas", {}).get("destroyed_objects", [])
	if migrated_ids.size() != selected_legacy_ids.size():
		failures.append(
			"prototype-v2 migration resolved count mismatch: expected=%d actual=%d" % [
				selected_legacy_ids.size(),
				migrated_ids.size(),
			]
		)
	for stable_id_variant in migrated_ids:
		if StableIdScript.parse(str(stable_id_variant)) == null:
			failures.append("prototype-v2 migration emitted invalid StableId: %s" % stable_id_variant)

	var unresolved: Array = first.get("unresolved_legacy_ids", [])
	if unresolved.size() != 1:
		failures.append(
			"prototype-v2 migration quarantine count mismatch: expected=1 actual=%d" % unresolved.size()
		)
	elif str(unresolved[0].get("legacy_id", "")) != "999:999:tree:999999":
		failures.append("prototype-v2 migration quarantined the wrong legacy ID")

	if first["save"] != second["save"]:
		failures.append("prototype-v2 migration is not repeatable for identical input")

	var bad_version: Dictionary = fixture.duplicate(true)
	bad_version["version"] = 1
	if bool(migrator.migrate(bad_version, settings).get("success", true)):
		failures.append("prototype-v2 migrator accepted an unsupported save version")

	return failures


static func _collect_chunk_ids(
	resolver,
	coord: Vector2i,
	limit: int,
	target: Array[String],
	failures: Array[String]
) -> void:
	var result: Dictionary = resolver.build_chunk_index_map(coord)
	var diagnostics: Array = result.get("diagnostics", [])
	if not diagnostics.is_empty():
		failures.append("legacy resolver replay diagnostics for chunk %s: %s" % [coord, diagnostics])
		return

	var legacy_keys: Array = result["mapping"].keys()
	legacy_keys.sort()
	var take_count: int = mini(limit, legacy_keys.size())
	for index in range(take_count):
		target.append(str(legacy_keys[index]))


static func _load_fixture(failures: Array[String]) -> Dictionary:
	var file: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	if file == null:
		failures.append("could not open migration fixture: %s" % FIXTURE_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		failures.append("migration fixture is not valid JSON dictionary")
		return {}
	return parsed
