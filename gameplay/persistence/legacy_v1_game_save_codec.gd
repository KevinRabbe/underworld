extends RefCounted

const MapSerializationContract := preload("res://worldgen/persistence/map_data_serialization_contract.gd")
const TypedJsonWire := preload("res://worldgen/persistence/typed_json_wire.gd")
const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const GeneratorManifest := preload("res://worldgen/versioning/generator_manifest.gd")
const GameplayStateCodec := preload("res://gameplay/persistence/gameplay_state_codec.gd")
const GameplaySaveCatalog := preload("res://gameplay/persistence/gameplay_save_catalog.gd")

const SAVE_SCHEMA_VERSION: int = 1
const SCHEMA_NAME: String = "underworld-game-save-v1"
const ROOT_KEYS: Array[String] = [
	"equipment_json",
	"inventory_json",
	"map_json",
	"pending_loot_jsons",
	"player_resume",
	"save_schema_version",
	"schema",
]
const RESUME_KEYS: Array[String] = ["x", "y", "z"]
const GATEWAY_AWARE_MANIFEST_ID: String = "gm-sha256:cb5674049cfdb0c0f6291c35fbc85382cddf4707bfbd2531d669f78b6e35471e"
const GATEWAY_AWARE_MANIFEST_CANONICAL: String = "gm1|15:manifest-schema|1:1|11:seed-schema|1:1|21:stable-address-schema|1:1|16:surface-contract|1:2|19:underworld-contract|1:1|19:provenance-contract|1:1|11:stage-count|2:10|5:stage|18:entrance_selection|1:1|5:stage|24:gateway.destination_site|1:1|5:stage|12:gateway.link|1:1|5:stage|19:gateway.source_site|1:1|5:stage|20:geometry_description|1:1|5:stage|12:macro_region|1:1|5:stage|16:primary_topology|1:1|5:stage|19:region_finalization|1:1|5:stage|22:secondary_connectivity|1:1|5:stage|22:special_location_hooks|1:1|13:profile-count|1:1|7:profile|13:depth_grammar|1:1|12:domain-count|2:29|6:domain|8:00010001|1:1|19:surface.tree.exists|6:domain|8:00010002|1:1|19:surface.tree.offset|6:domain|8:00010003|1:1|18:surface.tree.shape|6:domain|8:00010101|1:1|19:surface.rock.exists|6:domain|8:00010102|1:1|19:surface.rock.offset|6:domain|8:00010103|1:1|18:surface.rock.shape|6:domain|8:00010201|1:1|28:surface.pickup.branch.exists|6:domain|8:00010202|1:1|27:surface.pickup.branch.shape|6:domain|8:00010211|1:1|33:surface.pickup.loose_stone.exists|6:domain|8:00010212|1:1|32:surface.pickup.loose_stone.shape|6:domain|8:00020001|1:1|16:ug.region.layout|6:domain|8:00020101|1:1|17:ug.network.exists|6:domain|8:00020102|1:1|19:ug.network.topology|6:domain|8:00020200|1:1|14:ug.node.exists|6:domain|8:00020201|1:1|16:ug.node.position|6:domain|8:00020202|1:1|13:ug.node.shape|6:domain|8:00020203|1:1|15:ug.node.profile|6:domain|8:00020211|1:1|24:ug.primary_edge.topology|6:domain|8:00020301|1:1|21:ug.entrance.selection|6:domain|8:00020302|1:1|19:ug.entrance.profile|6:domain|8:00020303|1:1|19:ug.entrance.surface|6:domain|8:00020304|1:1|20:ug.entrance.geometry|6:domain|8:00020401|1:1|19:ug.secondary.exists|6:domain|8:00020402|1:1|18:ug.secondary.shape|6:domain|8:00020501|1:1|17:ug.special.exists|6:domain|8:00020601|1:1|17:ug.geometry.shape|6:domain|8:00030001|1:1|29:gateway.overworld.source_site|6:domain|8:00030101|1:1|35:gateway.underworld.destination_site|6:domain|8:00030201|1:1|20:gateway.link.pairing"
const PRE_GATEWAY_MANIFEST_ID: String = "gm-sha256:c3fb0a2e53be0593b588a6f9b375d087886ab55111b9ca1a78a5c09bf99a302f"
const PRE_GATEWAY_MANIFEST_CANONICAL: String = "gm1|15:manifest-schema|1:1|11:seed-schema|1:1|21:stable-address-schema|1:1|16:surface-contract|1:2|19:underworld-contract|1:1|19:provenance-contract|1:1|11:stage-count|1:7|5:stage|18:entrance_selection|1:1|5:stage|20:geometry_description|1:1|5:stage|12:macro_region|1:1|5:stage|16:primary_topology|1:1|5:stage|19:region_finalization|1:1|5:stage|22:secondary_connectivity|1:1|5:stage|22:special_location_hooks|1:1|13:profile-count|1:1|7:profile|13:depth_grammar|1:1|12:domain-count|2:26|6:domain|8:00010001|1:1|19:surface.tree.exists|6:domain|8:00010002|1:1|19:surface.tree.offset|6:domain|8:00010003|1:1|18:surface.tree.shape|6:domain|8:00010101|1:1|19:surface.rock.exists|6:domain|8:00010102|1:1|19:surface.rock.offset|6:domain|8:00010103|1:1|18:surface.rock.shape|6:domain|8:00010201|1:1|28:surface.pickup.branch.exists|6:domain|8:00010202|1:1|27:surface.pickup.branch.shape|6:domain|8:00010211|1:1|33:surface.pickup.loose_stone.exists|6:domain|8:00010212|1:1|32:surface.pickup.loose_stone.shape|6:domain|8:00020001|1:1|16:ug.region.layout|6:domain|8:00020101|1:1|17:ug.network.exists|6:domain|8:00020102|1:1|19:ug.network.topology|6:domain|8:00020200|1:1|14:ug.node.exists|6:domain|8:00020201|1:1|16:ug.node.position|6:domain|8:00020202|1:1|13:ug.node.shape|6:domain|8:00020203|1:1|15:ug.node.profile|6:domain|8:00020211|1:1|24:ug.primary_edge.topology|6:domain|8:00020301|1:1|21:ug.entrance.selection|6:domain|8:00020302|1:1|19:ug.entrance.profile|6:domain|8:00020303|1:1|19:ug.entrance.surface|6:domain|8:00020304|1:1|20:ug.entrance.geometry|6:domain|8:00020401|1:1|19:ug.secondary.exists|6:domain|8:00020402|1:1|18:ug.secondary.shape|6:domain|8:00020501|1:1|17:ug.special.exists|6:domain|8:00020601|1:1|17:ug.geometry.shape"

const GATEWAY_STAGE_REVISIONS: Dictionary = {
	"gateway.source_site": 1,
	"gateway.destination_site": 1,
	"gateway.link": 1,
}
const GATEWAY_SEED_DOMAINS: Array[Dictionary] = [
	{
		"domain_id": 0x030001,
		"revision": 1,
		"readable_name": "gateway.overworld.source_site",
	},
	{
		"domain_id": 0x030101,
		"revision": 1,
		"readable_name": "gateway.underworld.destination_site",
	},
	{
		"domain_id": 0x030201,
		"revision": 1,
		"readable_name": "gateway.link.pairing",
	},
]


static func encode(
	context,
	delta_store,
	inventory_state,
	equipment_state,
	pending_loot_states: Array,
	resume_position: Vector3
) -> Dictionary:
	var failures: Array[String] = GameplaySaveCatalog.validate_catalog()
	failures.append_array(_validate_resume_position(resume_position))
	if not failures.is_empty():
		return _failure(failures)

	var catalog_result: Dictionary = GameplaySaveCatalog.build_registry()
	if not bool(catalog_result.get("success", false)):
		return _failure(catalog_result.get("diagnostics", []))
	var registry = catalog_result.get("registry", null)

	var map_result: Dictionary = MapSerializationContract.encode(context, delta_store)
	if not bool(map_result.get("success", false)):
		return _prefixed_failure("map", map_result.get("diagnostics", []))

	var inventory_result: Dictionary = GameplayStateCodec.encode_inventory(inventory_state, registry)
	if not bool(inventory_result.get("success", false)):
		return _prefixed_failure("inventory", inventory_result.get("diagnostics", []))
	var inventory_wire: Dictionary = TypedJsonWire.encode(
		inventory_result.get("snapshot", {}),
		"inventory"
	)
	if not bool(inventory_wire.get("success", false)):
		return _prefixed_failure("inventory wire", inventory_wire.get("diagnostics", []))

	var equipment_result: Dictionary = GameplayStateCodec.encode_equipment(equipment_state, registry)
	if not bool(equipment_result.get("success", false)):
		return _prefixed_failure("equipment", equipment_result.get("diagnostics", []))
	var equipment_wire: Dictionary = TypedJsonWire.encode(
		equipment_result.get("snapshot", {}),
		"equipment"
	)
	if not bool(equipment_wire.get("success", false)):
		return _prefixed_failure("equipment wire", equipment_wire.get("diagnostics", []))

	var pending_records: Array[Dictionary] = []
	var seen_occurrences: Dictionary = {}
	for index in range(pending_loot_states.size()):
		var pending = pending_loot_states[index]
		var pending_result: Dictionary = GameplayStateCodec.encode_pending_loot(pending, registry)
		if not bool(pending_result.get("success", false)):
			for diagnostic in pending_result.get("diagnostics", []):
				failures.append("pending loot %d: %s" % [index, diagnostic])
			continue
		if not pending.has_method("is_pending") or not bool(pending.call("is_pending")):
			failures.append("pending loot durable set requires unresolved state at index %d" % index)
			continue
		var snapshot: Dictionary = pending_result.get("snapshot", {})
		var occurrence_id: String = str(snapshot.get("occurrence_id", ""))
		if seen_occurrences.has(occurrence_id):
			failures.append("integrated save contains duplicate pending loot occurrence: %s" % occurrence_id)
			continue
		seen_occurrences[occurrence_id] = true
		var pending_wire: Dictionary = TypedJsonWire.encode(snapshot, "pending loot %s" % occurrence_id)
		if not bool(pending_wire.get("success", false)):
			for diagnostic in pending_wire.get("diagnostics", []):
				failures.append("pending loot wire %s: %s" % [occurrence_id, diagnostic])
			continue
		pending_records.append({
			"occurrence_id": occurrence_id,
			"json": str(pending_wire.get("json", "")),
		})
	if not failures.is_empty():
		return _failure(failures)
	pending_records.sort_custom(func(a, b): return str(a["occurrence_id"]) < str(b["occurrence_id"]))
	var pending_loot_jsons: Array[String] = []
	for record in pending_records:
		pending_loot_jsons.append(str(record["json"]))

	var envelope: Dictionary = {
		"schema": SCHEMA_NAME,
		"save_schema_version": SAVE_SCHEMA_VERSION,
		"map_json": str(map_result.get("json", "")),
		"inventory_json": str(inventory_wire.get("json", "")),
		"equipment_json": str(equipment_wire.get("json", "")),
		"pending_loot_jsons": pending_loot_jsons,
		"player_resume": {
			"x": resume_position.x,
			"y": resume_position.y,
			"z": resume_position.z,
		},
	}
	failures.append_array(validate_envelope(envelope))
	if not failures.is_empty():
		return _failure(failures)

	var outer_wire: Dictionary = TypedJsonWire.encode(envelope, "integrated save")
	if not bool(outer_wire.get("success", false)):
		return _prefixed_failure("outer wire", outer_wire.get("diagnostics", []))
	return {
		"success": true,
		"envelope": envelope,
		"json": str(outer_wire.get("json", "")),
		"diagnostics": [],
	}


static func decode(json_text: String) -> Dictionary:
	var outer_wire: Dictionary = TypedJsonWire.decode(json_text, "integrated save")
	if not bool(outer_wire.get("success", false)):
		return _prefixed_failure("outer wire", outer_wire.get("diagnostics", []))
	var outer_value: Variant = outer_wire.get("value", null)
	if not outer_value is Dictionary:
		return _failure(["integrated save root must be a Dictionary"])
	var envelope: Dictionary = outer_value
	var failures: Array[String] = validate_envelope(envelope)
	if not failures.is_empty():
		return _failure(failures)

	var catalog_result: Dictionary = GameplaySaveCatalog.build_registry()
	if not bool(catalog_result.get("success", false)):
		return _failure(catalog_result.get("diagnostics", []))
	var registry = catalog_result.get("registry", null)

	var map_result: Dictionary = MapSerializationContract.decode(str(envelope["map_json"]))
	if not bool(map_result.get("success", false)):
		return _prefixed_failure("map", map_result.get("diagnostics", []))
	var map_envelope: Dictionary = map_result.get("envelope", {})
	var loaded_map: Dictionary = MapSerializationContract.load_delta_store(map_envelope)
	if not bool(loaded_map.get("success", false)):
		return _prefixed_failure("map state", loaded_map.get("diagnostics", []))
	var world_header: Dictionary = loaded_map.get("world", {})
	failures.append_array(_validate_current_world_compatibility(world_header))
	if not failures.is_empty():
		return _failure(failures)

	var inventory_snapshot: Dictionary = _decode_component_snapshot(
		str(envelope["inventory_json"]),
		"inventory",
		failures
	)
	var equipment_snapshot: Dictionary = _decode_component_snapshot(
		str(envelope["equipment_json"]),
		"equipment",
		failures
	)
	if not failures.is_empty():
		return _failure(failures)

	var inventory_result: Dictionary = GameplayStateCodec.decode_inventory(inventory_snapshot, registry)
	if not bool(inventory_result.get("success", false)):
		return _prefixed_failure("inventory", inventory_result.get("diagnostics", []))
	var equipment_result: Dictionary = GameplayStateCodec.decode_equipment(
		equipment_snapshot,
		registry,
		GameplaySaveCatalog.equipment_rules(),
		GameplaySaveCatalog.hotbar_bindings()
	)
	if not bool(equipment_result.get("success", false)):
		return _prefixed_failure("equipment", equipment_result.get("diagnostics", []))

	var pending_loot_states: Array = []
	var seen_occurrences: Dictionary = {}
	for index in range(envelope["pending_loot_jsons"].size()):
		var pending_snapshot: Dictionary = _decode_component_snapshot(
			str(envelope["pending_loot_jsons"][index]),
			"pending loot %d" % index,
			failures
		)
		if not failures.is_empty():
			return _failure(failures)
		var pending_result: Dictionary = GameplayStateCodec.decode_pending_loot(pending_snapshot, registry)
		if not bool(pending_result.get("success", false)):
			return _prefixed_failure("pending loot %d" % index, pending_result.get("diagnostics", []))
		var pending = pending_result.get("state", null)
		if pending == null or not pending.has_method("is_pending") or not bool(pending.call("is_pending")):
			return _failure(["integrated save pending loot must be unresolved at index %d" % index])
		var occurrence_id: String = str(pending.get("occurrence_id"))
		if seen_occurrences.has(occurrence_id):
			return _failure(["integrated save contains duplicate pending loot occurrence: %s" % occurrence_id])
		seen_occurrences[occurrence_id] = true
		pending_loot_states.append(pending)
	pending_loot_states.sort_custom(func(a, b): return str(a.occurrence_id) < str(b.occurrence_id))

	var resume_result: Dictionary = _resume_from_envelope(envelope["player_resume"])
	if not bool(resume_result.get("success", false)):
		return resume_result
	var world_seed: int = int(str(world_header.get("world_seed", "0")))
	var compatible_context = _world_context_for_supported_header(world_header)
	if compatible_context == null:
		return _failure(["integrated save world header lost compatibility after validation"])
	return {
		"success": true,
		"envelope": envelope.duplicate(true),
		"candidate": {
			"world_context": compatible_context,
			"world_seed": world_seed,
			"world_id": str(world_header.get("world_id", "")),
			"delta_store": loaded_map.get("delta_store", null),
			"inventory_state": inventory_result.get("state", null),
			"equipment_state": equipment_result.get("state", null),
			"pending_loot_states": pending_loot_states,
			"resume_position": resume_result.get("position", Vector3.ZERO),
		},
		"diagnostics": [],
	}


static func clone_candidate(candidate: Dictionary) -> Dictionary:
	var resume_variant: Variant = candidate.get("resume_position", null)
	if not resume_variant is Vector3:
		return _failure(["integrated save candidate resume_position must be Vector3"])
	var pending_variant: Variant = candidate.get("pending_loot_states", null)
	if not pending_variant is Array:
		return _failure(["integrated save candidate pending_loot_states must be Array"])
	var encoded: Dictionary = encode(
		candidate.get("world_context", null),
		candidate.get("delta_store", null),
		candidate.get("inventory_state", null),
		candidate.get("equipment_state", null),
		pending_variant,
		resume_variant
	)
	if not bool(encoded.get("success", false)):
		return _prefixed_failure("candidate clone encode", encoded.get("diagnostics", []))
	var decoded: Dictionary = decode(str(encoded.get("json", "")))
	if not bool(decoded.get("success", false)):
		return _prefixed_failure("candidate clone decode", decoded.get("diagnostics", []))
	return {
		"success": true,
		"candidate": decoded.get("candidate", {}),
		"diagnostics": [],
	}


static func validate_envelope(envelope: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	_validate_exact_keys(envelope, ROOT_KEYS, "integrated save", failures)
	if str(envelope.get("schema", "")) != SCHEMA_NAME:
		failures.append("unsupported integrated save schema: %s" % str(envelope.get("schema", "")))
	var raw_version: Variant = envelope.get("save_schema_version", null)
	if typeof(raw_version) != TYPE_INT:
		failures.append("integrated save schema version must be int")
	elif int(raw_version) != SAVE_SCHEMA_VERSION:
		failures.append("unsupported integrated save schema version: %s" % str(raw_version))
	for field in ["map_json", "inventory_json", "equipment_json"]:
		var value: Variant = envelope.get(field, null)
		if typeof(value) != TYPE_STRING or str(value).is_empty():
			failures.append("integrated save %s must be non-empty String" % field)
	var raw_pending: Variant = envelope.get("pending_loot_jsons", null)
	if not raw_pending is Array:
		failures.append("integrated save pending_loot_jsons must be Array")
	else:
		for index in range(raw_pending.size()):
			if typeof(raw_pending[index]) != TYPE_STRING or str(raw_pending[index]).is_empty():
				failures.append("integrated save pending_loot_jsons[%d] must be non-empty String" % index)
	var raw_resume: Variant = envelope.get("player_resume", null)
	if not raw_resume is Dictionary:
		failures.append("integrated save player_resume must be Dictionary")
	else:
		_validate_resume_dictionary(raw_resume, failures)
	failures.sort()
	return failures


static func _validate_current_world_compatibility(world_header: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var seed_text: String = str(world_header.get("world_seed", ""))
	if seed_text.is_empty() or not seed_text.is_valid_int():
		return ["integrated save world seed cannot construct current context"]
	var context = WorldGenerationContext.new(int(seed_text))
	for diagnostic in context.validate():
		failures.append("current world context: %s" % diagnostic)
	var current_header: Dictionary = context.canonical_header()
	if str(world_header.get("world_id", "")) != str(current_header.get("world_id", "")):
		failures.append("integrated save WorldId is incompatible with current world context")
	if _world_context_for_supported_header(world_header, false) == null:
		failures.append("integrated save generator manifest id is incompatible with current runtime")
		failures.append("integrated save generator manifest contract is incompatible with current runtime")
	failures.sort()
	return failures


static func _world_context_for_supported_header(
	world_header: Dictionary,
	require_world_id_match: bool = true
):
	var seed_text: String = str(world_header.get("world_seed", ""))
	if seed_text.is_empty() or not seed_text.is_valid_int():
		return null
	var world_seed: int = int(seed_text)
	var current_context = WorldGenerationContext.new(world_seed)
	if not current_context.validate().is_empty():
		return null
	if (
		require_world_id_match
		and str(world_header.get("world_id", "")) != current_context.world_id
	):
		return null

	var manifest_id: String = str(world_header.get("generator_manifest_id", ""))
	var manifest_canonical: String = str(
		world_header.get("generator_manifest_canonical", "")
	)
	var include_gateway: bool
	if (
		manifest_id == GATEWAY_AWARE_MANIFEST_ID
		and manifest_canonical == GATEWAY_AWARE_MANIFEST_CANONICAL
	):
		include_gateway = true
	elif (
		manifest_id == PRE_GATEWAY_MANIFEST_ID
		and manifest_canonical == PRE_GATEWAY_MANIFEST_CANONICAL
	):
		include_gateway = false
	else:
		return null

	# This is an explicit two-vector compatibility path, not general manifest
	# rehydration. Normalize only the three Gateway additions, then require the
	# complete canonical payload and digest to match the selected frozen vector.
	var snapshot: Dictionary = current_context.manifest_snapshot()
	var retained_stages: Array = []
	for entry_variant in snapshot.get("stage_entries", []):
		if not entry_variant is Dictionary:
			continue
		var entry: Dictionary = entry_variant
		if GATEWAY_STAGE_REVISIONS.has(str(entry.get("id", ""))):
			continue
		retained_stages.append(entry.duplicate(true))
	if include_gateway:
		for stage_id in GATEWAY_STAGE_REVISIONS:
			retained_stages.append({
				"id": stage_id,
				"revision": int(GATEWAY_STAGE_REVISIONS[stage_id]),
			})
	snapshot["stage_entries"] = retained_stages

	var gateway_domain_ids: Dictionary = {}
	for descriptor in GATEWAY_SEED_DOMAINS:
		gateway_domain_ids[int(descriptor["domain_id"])] = true
	var retained_domains: Array = []
	for descriptor_variant in snapshot.get("seed_domain_descriptors", []):
		if not descriptor_variant is Dictionary:
			continue
		var descriptor: Dictionary = descriptor_variant
		if gateway_domain_ids.has(int(descriptor.get("domain_id", 0))):
			continue
		retained_domains.append(descriptor.duplicate(true))
	if include_gateway:
		for descriptor in GATEWAY_SEED_DOMAINS:
			retained_domains.append(descriptor.duplicate(true))
	snapshot["seed_domain_descriptors"] = retained_domains

	var manifest = GeneratorManifest.from_snapshot(snapshot)
	if manifest.manifest_id() != manifest_id:
		return null
	if manifest.canonical_text() != manifest_canonical:
		return null
	var compatible_context = WorldGenerationContext.from_exact_identity(
		world_seed,
		current_context.world_id,
		current_context.world_id_contract(),
		manifest
	)
	if not compatible_context.validate_structure().is_empty():
		return null
	return compatible_context


static func _decode_component_snapshot(json_text: String, label: String, failures: Array[String]) -> Dictionary:
	var decoded: Dictionary = TypedJsonWire.decode(json_text, label)
	if not bool(decoded.get("success", false)):
		for diagnostic in decoded.get("diagnostics", []):
			failures.append("%s: %s" % [label, diagnostic])
		return {}
	var value: Variant = decoded.get("value", null)
	if not value is Dictionary:
		failures.append("%s durable payload must decode to Dictionary" % label)
		return {}
	return value


static func _resume_from_envelope(raw_resume: Variant) -> Dictionary:
	var failures: Array[String] = []
	if not raw_resume is Dictionary:
		return _failure(["integrated save player_resume must be Dictionary"])
	_validate_resume_dictionary(raw_resume, failures)
	if not failures.is_empty():
		return _failure(failures)
	return {
		"success": true,
		"position": Vector3(
			float(raw_resume["x"]),
			float(raw_resume["y"]),
			float(raw_resume["z"])
		),
		"diagnostics": [],
	}


static func _validate_resume_position(position: Vector3) -> Array[String]:
	for axis in [position.x, position.y, position.z]:
		if is_nan(float(axis)) or is_inf(float(axis)):
			return ["player resume position must contain only finite coordinates"]
	return []


static func _validate_resume_dictionary(resume: Dictionary, failures: Array[String]) -> void:
	_validate_exact_keys(resume, RESUME_KEYS, "player_resume", failures)
	for axis in RESUME_KEYS:
		var value: Variant = resume.get(axis, null)
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			failures.append("player resume %s must be numeric" % axis)
			continue
		var number: float = float(value)
		if is_nan(number) or is_inf(number):
			failures.append("player resume %s must be finite" % axis)


static func _validate_exact_keys(
	source: Dictionary,
	expected_keys: Array[String],
	label: String,
	failures: Array[String]
) -> void:
	var actual: Array[String] = []
	for raw_key in source.keys():
		actual.append(str(raw_key))
	actual.sort()
	var expected: Array[String] = expected_keys.duplicate()
	expected.sort()
	if actual != expected:
		failures.append("%s keys must be exact expected=%s actual=%s" % [label, expected, actual])


static func _prefixed_messages(prefix: String, messages: Array) -> Array[String]:
	var result: Array[String] = []
	for message in messages:
		result.append("%s: %s" % [prefix, str(message)])
	return result


static func _prefixed_failure(prefix: String, messages: Array) -> Dictionary:
	return _failure(_prefixed_messages(prefix, messages))


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {
		"success": false,
		"diagnostics": diagnostics,
	}
