extends RefCounted

const MapSerializationContract := preload("res://worldgen/persistence/map_data_serialization_contract.gd")
const TypedJsonWire := preload("res://worldgen/persistence/typed_json_wire.gd")
const WorldGenerationContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const RootGenerationIdentityPackage := preload("res://worldgen/versioning/root_generation_identity_package.gd")
const WorldDomainSessionState := preload("res://gameplay/world_session/world_domain_session_state.gd")
const GameplayStateCodec := preload("res://gameplay/persistence/gameplay_state_codec.gd")
const GameplaySaveCatalog := preload("res://gameplay/persistence/gameplay_save_catalog.gd")

# Legacy v1 remains temporarily callable while #431 migrates the production slot
# ingress. Normal v2 compatibility classification treats a valid v1 as
# INCOMPATIBLE because it lacks authoritative world-domain identity.
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

const V2_SAVE_SCHEMA_VERSION: int = 2
const V2_SCHEMA_NAME: String = "underworld-game-save-v2"
const CLASS_NONE: String = "NONE"
const CLASS_AVAILABLE: String = "AVAILABLE"
const CLASS_INCOMPATIBLE: String = "INCOMPATIBLE"
const CLASS_INVALID: String = "INVALID"
const LEGACY_DOMAIN_MISSING_DIAGNOSTIC: String = "legacy v1 save lacks explicit world-domain identity"
const V2_CAPTURE_SOURCE_KEYS: Array[String] = [
	"current_health",
	"current_stamina",
	"delta_store",
	"equipment_state",
	"inventory_state",
	"pending_loot_states",
	"resume_position",
	"world_context",
	"world_session_state",
]
const V2_REQUEST_KEYS: Array[String] = [
	"equipment_json",
	"inventory_json",
	"map_json",
	"pending_loot_jsons",
	"player_resume",
	"player_vitals",
	"root_identity",
	"world_seed",
	"world_session",
]
const V2_ROOT_KEYS: Array[String] = [
	"equipment_json",
	"inventory_json",
	"map_json",
	"pending_loot_jsons",
	"player_resume",
	"player_vitals",
	"root_identity",
	"save_schema_version",
	"schema",
	"world_seed",
	"world_session",
]
const V2_RESUME_KEYS: Array[String] = ["domain", "x", "y", "z"]


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
	var current_context = WorldGenerationContext.new(world_seed)
	return {
		"success": true,
		"envelope": envelope.duplicate(true),
		"candidate": {
			"world_context": current_context,
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


# V2 capture is the point-in-time detached SAVE-request boundary. The live #430
# root context, #432 session authority and gameplay authorities are consumed here;
# only value-owned snapshots/canonical component JSON leave this function.
static func capture_v2_request(source: Dictionary) -> Dictionary:
	var failures: Array[String] = []
	_validate_exact_keys(source, V2_CAPTURE_SOURCE_KEYS, "v2 SAVE capture source", failures)
	if not failures.is_empty():
		return _failure(failures)

	var context = source.get("world_context", null)
	if context == null or not context.has_method("validate"):
		failures.append("v2 SAVE capture requires exact WorldGenerationContext")
	else:
		for diagnostic in context.validate():
			failures.append("v2 SAVE root context: %s" % diagnostic)

	var world_session = source.get("world_session_state", null)
	if (
		world_session == null
		or not world_session.has_method("has_active_attempt")
		or not world_session.has_method("transition_phase")
		or not world_session.has_method("durable_snapshot")
	):
		failures.append("v2 SAVE capture requires WorldDomainSessionState authority")
	elif bool(world_session.call("has_active_attempt")):
		failures.append("v2 SAVE capture rejects in-flight world-domain transition")
	elif str(world_session.call("transition_phase")) != WorldDomainSessionState.PHASE_ACTIVE:
		failures.append("v2 SAVE capture requires ACTIVE world-domain phase")

	var resume_variant: Variant = source.get("resume_position", null)
	if not resume_variant is Vector3:
		failures.append("v2 SAVE capture resume_position must be Vector3")
	else:
		failures.append_array(_validate_resume_position(resume_variant))

	var pending_variant: Variant = source.get("pending_loot_states", null)
	if not pending_variant is Array:
		failures.append("v2 SAVE capture pending_loot_states must be Array")
	if not failures.is_empty():
		return _failure(failures)

	var root_identity: Dictionary = RootGenerationIdentityPackage.encode(context)
	var root_decode: Dictionary = RootGenerationIdentityPackage.decode(root_identity)
	if not bool(root_decode.get("success", false)):
		return _prefixed_failure("v2 SAVE root identity", root_decode.get("failures", []))

	var durable_session_variant: Variant = world_session.call("durable_snapshot")
	if not durable_session_variant is Dictionary:
		return _failure(["v2 SAVE world session did not expose durable Dictionary"])
	var durable_session: Dictionary = durable_session_variant.duplicate(true)
	var restored_session: Dictionary = WorldDomainSessionState.restore_from_durable(durable_session)
	if not bool(restored_session.get("success", false)):
		return _prefixed_failure("v2 SAVE world session", restored_session.get("diagnostics", []))
	var active_domain: String = str(restored_session.get("active_domain", ""))
	var canonical_session: Dictionary = {
		"active_domain": active_domain,
		"committed_return_context": restored_session.get(
			"committed_return_context",
			{}
		).duplicate(true),
	}

	var catalog_result: Dictionary = GameplaySaveCatalog.build_registry()
	if not bool(catalog_result.get("success", false)):
		return _failure(catalog_result.get("diagnostics", []))
	var registry = catalog_result.get("registry", null)

	var map_result: Dictionary = MapSerializationContract.encode_against_context(
		context,
		source.get("delta_store", null)
	)
	if not bool(map_result.get("success", false)):
		return _prefixed_failure("v2 SAVE map", map_result.get("diagnostics", []))

	var inventory_result: Dictionary = GameplayStateCodec.encode_inventory(
		source.get("inventory_state", null),
		registry
	)
	if not bool(inventory_result.get("success", false)):
		return _prefixed_failure("v2 SAVE inventory", inventory_result.get("diagnostics", []))
	var inventory_wire: Dictionary = TypedJsonWire.encode(
		inventory_result.get("snapshot", {}),
		"v2 SAVE inventory"
	)
	if not bool(inventory_wire.get("success", false)):
		return _prefixed_failure("v2 SAVE inventory wire", inventory_wire.get("diagnostics", []))

	var equipment_result: Dictionary = GameplayStateCodec.encode_equipment(
		source.get("equipment_state", null),
		registry
	)
	if not bool(equipment_result.get("success", false)):
		return _prefixed_failure("v2 SAVE equipment", equipment_result.get("diagnostics", []))
	var equipment_wire: Dictionary = TypedJsonWire.encode(
		equipment_result.get("snapshot", {}),
		"v2 SAVE equipment"
	)
	if not bool(equipment_wire.get("success", false)):
		return _prefixed_failure("v2 SAVE equipment wire", equipment_wire.get("diagnostics", []))

	var pending_capture: Dictionary = _capture_pending_loot_jsons(pending_variant, registry)
	if not bool(pending_capture.get("success", false)):
		return pending_capture

	var vitals_result: Dictionary = GameplayStateCodec.encode_player_vitals(
		source.get("current_health", null),
		source.get("current_stamina", null)
	)
	if not bool(vitals_result.get("success", false)):
		return _prefixed_failure("v2 SAVE player vitals", vitals_result.get("diagnostics", []))

	var resume_position: Vector3 = resume_variant
	var request: Dictionary = {
		"world_seed": int(context.world_seed),
		"root_identity": root_identity.duplicate(true),
		"world_session": canonical_session,
		"map_json": str(map_result.get("json", "")),
		"inventory_json": str(inventory_wire.get("json", "")),
		"equipment_json": str(equipment_wire.get("json", "")),
		"pending_loot_jsons": pending_capture.get("jsons", []).duplicate(),
		"player_resume": {
			"domain": active_domain,
			"x": resume_position.x,
			"y": resume_position.y,
			"z": resume_position.z,
		},
		"player_vitals": vitals_result.get("snapshot", {}).duplicate(true),
	}
	failures.append_array(validate_v2_request(request))
	if not failures.is_empty():
		return _failure(failures)
	return {
		"success": true,
		"request": request.duplicate(true),
		"diagnostics": [],
	}


static func encode_v2_request(request_snapshot: Dictionary) -> Dictionary:
	var failures: Array[String] = validate_v2_request(request_snapshot)
	if not failures.is_empty():
		return _failure(failures)
	var envelope: Dictionary = request_snapshot.duplicate(true)
	envelope["schema"] = V2_SCHEMA_NAME
	envelope["save_schema_version"] = V2_SAVE_SCHEMA_VERSION
	failures.append_array(validate_v2_envelope(envelope))
	if not failures.is_empty():
		return _failure(failures)
	var encoded: Dictionary = TypedJsonWire.encode(envelope, "integrated save v2")
	if not bool(encoded.get("success", false)):
		return _prefixed_failure("integrated save v2 outer wire", encoded.get("diagnostics", []))
	return {
		"success": true,
		"classification": CLASS_AVAILABLE,
		"envelope": envelope.duplicate(true),
		"json": str(encoded.get("json", "")),
		"diagnostics": [],
	}


static func decode_v2_classified(json_text: String) -> Dictionary:
	var outer: Dictionary = TypedJsonWire.decode(json_text, "integrated save")
	if not bool(outer.get("success", false)):
		return _classified_failure(
			CLASS_INVALID,
			_prefixed_messages("outer wire", outer.get("diagnostics", []))
		)
	var value: Variant = outer.get("value", null)
	if not value is Dictionary:
		return _classified_failure(CLASS_INVALID, ["integrated save root must be a Dictionary"])
	var envelope: Dictionary = value
	var schema_variant: Variant = envelope.get("schema", null)
	var version_variant: Variant = envelope.get("save_schema_version", null)
	if typeof(schema_variant) != TYPE_STRING or typeof(version_variant) != TYPE_INT:
		return _classified_failure(
			CLASS_INVALID,
			["integrated save requires typed schema and save_schema_version"]
		)

	var schema: String = str(schema_variant)
	var version: int = int(version_variant)
	if schema == SCHEMA_NAME and version == SAVE_SCHEMA_VERSION:
		var legacy_failures: Array[String] = validate_envelope(envelope)
		if not legacy_failures.is_empty():
			return _classified_failure(CLASS_INVALID, legacy_failures)
		return _classified_failure(CLASS_INCOMPATIBLE, [LEGACY_DOMAIN_MISSING_DIAGNOSTIC])
	if schema != V2_SCHEMA_NAME or version != V2_SAVE_SCHEMA_VERSION:
		return _classified_failure(
			CLASS_INCOMPATIBLE,
			["unsupported integrated save schema/version: %s/%d" % [schema, version]]
		)

	var failures: Array[String] = validate_v2_envelope(envelope)
	if not failures.is_empty():
		return _classified_failure(CLASS_INVALID, failures)

	var world_seed: int = int(envelope.get("world_seed", 0))
	var root_identity: Dictionary = envelope.get("root_identity", {}).duplicate(true)
	var rehydrated: Dictionary = RootGenerationIdentityPackage.rehydrate(world_seed, root_identity)
	if not bool(rehydrated.get("success", false)):
		return _classified_failure(
			CLASS_INVALID,
			_prefixed_messages("root identity", rehydrated.get("failures", []))
		)
	if not bool(rehydrated.get("compatible", false)):
		return _classified_failure(
			CLASS_INCOMPATIBLE,
			_prefixed_messages(
				"root identity compatibility",
				rehydrated.get("compatibility_failures", [])
			)
		)
	var exact_context = rehydrated.get("context", null)
	if exact_context == null:
		return _classified_failure(CLASS_INVALID, ["root identity rehydrate returned no context"])

	var map_result: Dictionary = MapSerializationContract.decode_against_context(
		str(envelope.get("map_json", "")),
		exact_context
	)
	if not bool(map_result.get("success", false)):
		return _classified_failure(
			CLASS_INVALID,
			_prefixed_messages("map", map_result.get("diagnostics", []))
		)
	var loaded_map: Dictionary = MapSerializationContract.load_delta_store_against_context(
		map_result.get("envelope", {}),
		exact_context
	)
	if not bool(loaded_map.get("success", false)):
		return _classified_failure(
			CLASS_INVALID,
			_prefixed_messages("map state", loaded_map.get("diagnostics", []))
		)

	var restored_session: Dictionary = WorldDomainSessionState.restore_from_durable(
		envelope.get("world_session", {})
	)
	if not bool(restored_session.get("success", false)):
		return _classified_failure(
			CLASS_INVALID,
			_prefixed_messages("world session", restored_session.get("diagnostics", []))
		)
	var active_domain: String = str(restored_session.get("active_domain", ""))

	var resume_result: Dictionary = _v2_resume_from_envelope(envelope.get("player_resume", null))
	if not bool(resume_result.get("success", false)):
		return _classified_failure(CLASS_INVALID, resume_result.get("diagnostics", []))
	if str(resume_result.get("domain", "")) != active_domain:
		return _classified_failure(
			CLASS_INVALID,
			["player resume domain does not match durable active_domain"]
		)

	var catalog_result: Dictionary = GameplaySaveCatalog.build_registry()
	if not bool(catalog_result.get("success", false)):
		return _classified_failure(CLASS_INVALID, catalog_result.get("diagnostics", []))
	var registry = catalog_result.get("registry", null)

	failures.clear()
	var inventory_snapshot: Dictionary = _decode_component_snapshot(
		str(envelope.get("inventory_json", "")),
		"inventory",
		failures
	)
	var equipment_snapshot: Dictionary = _decode_component_snapshot(
		str(envelope.get("equipment_json", "")),
		"equipment",
		failures
	)
	if not failures.is_empty():
		return _classified_failure(CLASS_INVALID, failures)
	var inventory_result: Dictionary = GameplayStateCodec.decode_inventory(inventory_snapshot, registry)
	if not bool(inventory_result.get("success", false)):
		return _classified_failure(
			CLASS_INVALID,
			_prefixed_messages("inventory", inventory_result.get("diagnostics", []))
		)
	var equipment_result: Dictionary = GameplayStateCodec.decode_equipment(
		equipment_snapshot,
		registry,
		GameplaySaveCatalog.equipment_rules(),
		GameplaySaveCatalog.hotbar_bindings()
	)
	if not bool(equipment_result.get("success", false)):
		return _classified_failure(
			CLASS_INVALID,
			_prefixed_messages("equipment", equipment_result.get("diagnostics", []))
		)

	var pending_result: Dictionary = _decode_pending_loot_jsons(
		envelope.get("pending_loot_jsons", []),
		registry
	)
	if not bool(pending_result.get("success", false)):
		return _classified_failure(CLASS_INVALID, pending_result.get("diagnostics", []))

	var vitals_result: Dictionary = GameplayStateCodec.decode_player_vitals(
		envelope.get("player_vitals", {})
	)
	if not bool(vitals_result.get("success", false)):
		return _classified_failure(
			CLASS_INVALID,
			_prefixed_messages("player vitals", vitals_result.get("diagnostics", []))
		)

	var committed_context: Dictionary = restored_session.get(
		"committed_return_context",
		{}
	).duplicate(true)
	var detached_session = WorldDomainSessionState.new(active_domain, committed_context)
	return {
		"success": true,
		"classification": CLASS_AVAILABLE,
		"envelope": envelope.duplicate(true),
		"candidate": {
			"world_context": exact_context,
			"world_seed": world_seed,
			"world_id": str(exact_context.world_id),
			"world_session_state": detached_session,
			"active_domain": active_domain,
			"delta_store": loaded_map.get("delta_store", null),
			"inventory_state": inventory_result.get("state", null),
			"equipment_state": equipment_result.get("state", null),
			"pending_loot_states": pending_result.get("states", []).duplicate(),
			"resume_position": resume_result.get("position", Vector3.ZERO),
			"player_vitals": vitals_result.get("state", {}).duplicate(true),
		},
		"diagnostics": [],
	}


static func clone_v2_candidate(candidate: Dictionary) -> Dictionary:
	var session = candidate.get("world_session_state", null)
	var vitals_variant: Variant = candidate.get("player_vitals", null)
	var pending_variant: Variant = candidate.get("pending_loot_states", null)
	var resume_variant: Variant = candidate.get("resume_position", null)
	if session == null or not session.has_method("durable_snapshot"):
		return _failure(["v2 candidate clone requires WorldDomainSessionState"])
	if not vitals_variant is Dictionary:
		return _failure(["v2 candidate clone requires player_vitals Dictionary"])
	if not pending_variant is Array:
		return _failure(["v2 candidate clone requires pending_loot_states Array"])
	if not resume_variant is Vector3:
		return _failure(["v2 candidate clone requires resume_position Vector3"])
	var captured: Dictionary = capture_v2_request({
		"world_context": candidate.get("world_context", null),
		"delta_store": candidate.get("delta_store", null),
		"inventory_state": candidate.get("inventory_state", null),
		"equipment_state": candidate.get("equipment_state", null),
		"pending_loot_states": pending_variant,
		"world_session_state": session,
		"resume_position": resume_variant,
		"current_health": vitals_variant.get("current_health", null),
		"current_stamina": vitals_variant.get("current_stamina", null),
	})
	if not bool(captured.get("success", false)):
		return _prefixed_failure("v2 candidate clone capture", captured.get("diagnostics", []))
	var encoded: Dictionary = encode_v2_request(captured.get("request", {}))
	if not bool(encoded.get("success", false)):
		return _prefixed_failure("v2 candidate clone encode", encoded.get("diagnostics", []))
	var decoded: Dictionary = decode_v2_classified(str(encoded.get("json", "")))
	if not bool(decoded.get("success", false)):
		return _prefixed_failure("v2 candidate clone decode", decoded.get("diagnostics", []))
	return {
		"success": true,
		"candidate": decoded.get("candidate", {}),
		"diagnostics": [],
	}


static func validate_v2_request(request: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	_validate_exact_keys(request, V2_REQUEST_KEYS, "integrated save v2 request", failures)
	if typeof(request.get("world_seed", null)) != TYPE_INT:
		failures.append("integrated save v2 world_seed must be int")
	for field in ["root_identity", "world_session", "player_resume", "player_vitals"]:
		if not request.get(field, null) is Dictionary:
			failures.append("integrated save v2 %s must be Dictionary" % field)
	for field in ["map_json", "inventory_json", "equipment_json"]:
		var value: Variant = request.get(field, null)
		if typeof(value) != TYPE_STRING or str(value).is_empty():
			failures.append("integrated save v2 %s must be non-empty String" % field)
	var raw_pending: Variant = request.get("pending_loot_jsons", null)
	if not raw_pending is Array:
		failures.append("integrated save v2 pending_loot_jsons must be Array")
	else:
		for index in range(raw_pending.size()):
			if typeof(raw_pending[index]) != TYPE_STRING or str(raw_pending[index]).is_empty():
				failures.append("integrated save v2 pending_loot_jsons[%d] must be non-empty String" % index)
	if not failures.is_empty():
		failures.sort()
		return failures

	var root_identity: Dictionary = request["root_identity"]
	var rehydrated: Dictionary = RootGenerationIdentityPackage.rehydrate(
		int(request["world_seed"]),
		root_identity
	)
	if not bool(rehydrated.get("success", false)):
		for diagnostic in rehydrated.get("failures", []):
			failures.append("integrated save v2 root identity: %s" % diagnostic)
	elif not bool(rehydrated.get("compatible", false)):
		for diagnostic in rehydrated.get("compatibility_failures", []):
			failures.append("integrated save v2 root identity incompatible: %s" % diagnostic)
	else:
		var map_check: Dictionary = MapSerializationContract.decode_against_context(
			str(request["map_json"]),
			rehydrated.get("context", null)
		)
		if not bool(map_check.get("success", false)):
			for diagnostic in map_check.get("diagnostics", []):
				failures.append("integrated save v2 map: %s" % diagnostic)

	var session_result: Dictionary = WorldDomainSessionState.restore_from_durable(
		request["world_session"]
	)
	if not bool(session_result.get("success", false)):
		for diagnostic in session_result.get("diagnostics", []):
			failures.append("integrated save v2 world session: %s" % diagnostic)
	var resume_result: Dictionary = _v2_resume_from_envelope(request["player_resume"])
	if not bool(resume_result.get("success", false)):
		failures.append_array(resume_result.get("diagnostics", []))
	elif (
		bool(session_result.get("success", false))
		and str(resume_result.get("domain", "")) != str(session_result.get("active_domain", ""))
	):
		failures.append("player resume domain does not match durable active_domain")
	var vitals_result: Dictionary = GameplayStateCodec.decode_player_vitals(request["player_vitals"])
	if not bool(vitals_result.get("success", false)):
		for diagnostic in vitals_result.get("diagnostics", []):
			failures.append("integrated save v2 player vitals: %s" % diagnostic)
	failures.sort()
	return failures


static func validate_v2_envelope(envelope: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	_validate_exact_keys(envelope, V2_ROOT_KEYS, "integrated save v2", failures)
	if str(envelope.get("schema", "")) != V2_SCHEMA_NAME:
		failures.append("unsupported integrated save v2 schema: %s" % str(envelope.get("schema", "")))
	if typeof(envelope.get("save_schema_version", null)) != TYPE_INT:
		failures.append("integrated save v2 schema version must be int")
	elif int(envelope.get("save_schema_version", 0)) != V2_SAVE_SCHEMA_VERSION:
		failures.append("unsupported integrated save v2 schema version")
	if not failures.is_empty():
		failures.sort()
		return failures
	var request: Dictionary = envelope.duplicate(true)
	request.erase("schema")
	request.erase("save_schema_version")
	failures.append_array(validate_v2_request(request))
	failures.sort()
	return failures


static func _capture_pending_loot_jsons(pending_states: Array, registry) -> Dictionary:
	var failures: Array[String] = []
	var records: Array[Dictionary] = []
	var seen: Dictionary = {}
	for index in range(pending_states.size()):
		var pending = pending_states[index]
		var encoded: Dictionary = GameplayStateCodec.encode_pending_loot(pending, registry)
		if not bool(encoded.get("success", false)):
			for diagnostic in encoded.get("diagnostics", []):
				failures.append("pending loot %d: %s" % [index, diagnostic])
			continue
		if not pending.has_method("is_pending") or not bool(pending.call("is_pending")):
			failures.append("pending loot durable set requires unresolved state at index %d" % index)
			continue
		var snapshot: Dictionary = encoded.get("snapshot", {})
		var occurrence_id: String = str(snapshot.get("occurrence_id", ""))
		if seen.has(occurrence_id):
			failures.append("integrated save contains duplicate pending loot occurrence: %s" % occurrence_id)
			continue
		seen[occurrence_id] = true
		var wire: Dictionary = TypedJsonWire.encode(snapshot, "pending loot %s" % occurrence_id)
		if not bool(wire.get("success", false)):
			for diagnostic in wire.get("diagnostics", []):
				failures.append("pending loot wire %s: %s" % [occurrence_id, diagnostic])
			continue
		records.append({"occurrence_id": occurrence_id, "json": str(wire.get("json", ""))})
	if not failures.is_empty():
		return _failure(failures)
	records.sort_custom(func(a, b): return str(a["occurrence_id"]) < str(b["occurrence_id"]))
	var jsons: Array[String] = []
	for record in records:
		jsons.append(str(record["json"]))
	return {"success": true, "jsons": jsons, "diagnostics": []}


static func _decode_pending_loot_jsons(raw_jsons: Variant, registry) -> Dictionary:
	if not raw_jsons is Array:
		return _failure(["integrated save pending_loot_jsons must be Array"])
	var failures: Array[String] = []
	var states: Array = []
	var seen: Dictionary = {}
	for index in range(raw_jsons.size()):
		var snapshot: Dictionary = _decode_component_snapshot(
			str(raw_jsons[index]),
			"pending loot %d" % index,
			failures
		)
		if not failures.is_empty():
			return _failure(failures)
		var decoded: Dictionary = GameplayStateCodec.decode_pending_loot(snapshot, registry)
		if not bool(decoded.get("success", false)):
			return _prefixed_failure("pending loot %d" % index, decoded.get("diagnostics", []))
		var pending = decoded.get("state", null)
		if pending == null or not pending.has_method("is_pending") or not bool(pending.call("is_pending")):
			return _failure(["integrated save pending loot must be unresolved at index %d" % index])
		var occurrence_id: String = str(pending.get("occurrence_id"))
		if seen.has(occurrence_id):
			return _failure(["integrated save contains duplicate pending loot occurrence: %s" % occurrence_id])
		seen[occurrence_id] = true
		states.append(pending)
	states.sort_custom(func(a, b): return str(a.occurrence_id) < str(b.occurrence_id))
	return {"success": true, "states": states, "diagnostics": []}


static func _v2_resume_from_envelope(raw_resume: Variant) -> Dictionary:
	var failures: Array[String] = []
	if not raw_resume is Dictionary:
		return _failure(["integrated save v2 player_resume must be Dictionary"])
	_validate_exact_keys(raw_resume, V2_RESUME_KEYS, "player_resume", failures)
	var domain_variant: Variant = raw_resume.get("domain", null)
	if typeof(domain_variant) != TYPE_STRING:
		failures.append("player resume domain must be String")
	elif (
		str(domain_variant) != WorldDomainSessionState.DOMAIN_OVERWORLD
		and str(domain_variant) != WorldDomainSessionState.DOMAIN_UNDERWORLD
	):
		failures.append("player resume domain must be canonical")
	for axis in ["x", "y", "z"]:
		var value: Variant = raw_resume.get(axis, null)
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			failures.append("player resume %s must be numeric" % axis)
			continue
		if not is_finite(float(value)):
			failures.append("player resume %s must be finite" % axis)
	if not failures.is_empty():
		return _failure(failures)
	return {
		"success": true,
		"domain": str(domain_variant),
		"position": Vector3(
			float(raw_resume["x"]),
			float(raw_resume["y"]),
			float(raw_resume["z"])
		),
		"diagnostics": [],
	}


static func _classified_failure(classification: String, messages: Array) -> Dictionary:
	var result: Dictionary = _failure(messages)
	result["classification"] = classification
	return result


static func _prefixed_messages(prefix: String, messages: Array) -> Array[String]:
	var result: Array[String] = []
	for message in messages:
		result.append("%s: %s" % [prefix, str(message)])
	return result


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
	if str(world_header.get("generator_manifest_id", "")) != str(current_header.get("generator_manifest_id", "")):
		failures.append("integrated save generator manifest id is incompatible with current runtime")
	if str(world_header.get("generator_manifest_canonical", "")) != str(current_header.get("generator_manifest_canonical", "")):
		failures.append("integrated save generator manifest contract is incompatible with current runtime")
	failures.sort()
	return failures


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
