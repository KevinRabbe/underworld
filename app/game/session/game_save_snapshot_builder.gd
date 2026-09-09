extends RefCounted

const IntegratedGameSaveContract := preload("res://gameplay/persistence/integrated_game_save_contract.gd")
const GameplayStateCodec := preload("res://gameplay/persistence/gameplay_state_codec.gd")
const GameplaySaveCatalog := preload("res://gameplay/persistence/gameplay_save_catalog.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const WorldDomainSessionState := preload("res://gameplay/world_session/world_domain_session_state.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const PendingLootState := preload("res://gameplay/loot/runtime/pending_loot_state.gd")


static func capture(
	world_settings,
	session_world_context,
	world_session_state,
	world_delta_store,
	survival,
	player,
	encounter_controller
) -> Dictionary:
	var failures: Array[String] = []
	if world_settings == null:
		failures.append("SAVE runtime snapshot requires WorldSettings")
	if session_world_context == null or not session_world_context.has_method("validate"):
		failures.append("SAVE runtime snapshot requires exact session root context")
	elif not session_world_context.validate().is_empty():
		failures.append("SAVE runtime session root context is invalid")
	elif world_settings != null and int(world_settings.world_seed) != int(session_world_context.world_seed):
		failures.append("SAVE runtime WorldSettings seed drifted from session root context")
	if world_session_state == null or not world_session_state is WorldDomainSessionState:
		failures.append("SAVE runtime snapshot requires WorldDomainSessionState authority")
	if world_delta_store == null or not world_delta_store is WorldDeltaStore:
		failures.append("SAVE runtime snapshot requires WorldDeltaStore")
	if survival == null:
		failures.append("SAVE runtime snapshot requires Survival")
	if player == null or not is_instance_valid(player):
		failures.append("SAVE runtime snapshot requires live Player")
	elif player.has_method("is_defeated") and bool(player.call("is_defeated")):
		failures.append("SAVE runtime snapshot rejects defeated Player")
	elif not player.has_method("get_health") or not player.has_method("get_stamina"):
		failures.append("SAVE runtime Player does not expose current vitals")
	if not failures.is_empty():
		return _failure(failures)

	var pending_result: Dictionary = _capture_pending_loot_states(encounter_controller)
	if not bool(pending_result.get("success", false)):
		return pending_result
	var inventory_state = survival.get_inventory_state()
	var equipment_state = survival.get_equipment_state()
	if inventory_state == null or not inventory_state is ItemContainerState:
		failures.append("SAVE runtime snapshot requires ItemContainerState")
	if equipment_state == null or not equipment_state is EquipmentHotbarState:
		failures.append("SAVE runtime snapshot requires EquipmentHotbarState")
	var resume_position: Vector3 = player.global_position
	if not _is_finite_vector3(resume_position):
		failures.append("SAVE runtime Player resume position must be finite")
	if not failures.is_empty():
		return _failure(failures)
	return IntegratedGameSaveContract.capture_v2_request({
		"world_context": session_world_context,
		"world_session_state": world_session_state,
		"delta_store": world_delta_store,
		"inventory_state": inventory_state,
		"equipment_state": equipment_state,
		"pending_loot_states": pending_result.get("states", []).duplicate(),
		"resume_position": resume_position,
		"current_health": int(player.call("get_health")),
		"current_stamina": float(player.call("get_stamina")),
	})


static func _capture_pending_loot_states(encounter_controller) -> Dictionary:
	if encounter_controller == null:
		return {"success": true, "states": [], "diagnostics": []}
	var catalog_result: Dictionary = GameplaySaveCatalog.build_registry()
	if not bool(catalog_result.get("success", false)):
		return _failure(catalog_result.get("diagnostics", []))
	var registry = catalog_result.get("registry", null)
	var occurrence_ids: Array[String] = []
	for raw_id in encounter_controller.get_pending_loot_occurrence_ids():
		occurrence_ids.append(str(raw_id))
	occurrence_ids.sort()
	var states: Array = []
	for occurrence_id in occurrence_ids:
		var snapshot: Dictionary = encounter_controller.get_pending_loot_snapshot(occurrence_id)
		if str(snapshot.get("schema", "")) != PendingLootState.SNAPSHOT_SCHEMA:
			return _failure(["SAVE runtime pending loot has unexpected native schema: %s" % occurrence_id])
		if str(snapshot.get("occurrence_id", "")) != occurrence_id:
			return _failure(["SAVE runtime pending loot occurrence mismatch: %s" % occurrence_id])
		if bool(snapshot.get("consumed", true)):
			return _failure(["SAVE runtime pending loot is not unresolved: %s" % occurrence_id])
		var rewards_variant: Variant = snapshot.get("rewards", null)
		if not rewards_variant is Array:
			return _failure(["SAVE runtime pending loot rewards are malformed: %s" % occurrence_id])
		var state = PendingLootState.new().configure(
			occurrence_id,
			str(snapshot.get("profile_id", "")),
			rewards_variant
		)
		var state_failures: Array[String] = state.validate_state()
		if not state_failures.is_empty():
			return _prefixed_failure("SAVE runtime pending loot %s" % occurrence_id, state_failures)
		var durable_validation: Dictionary = GameplayStateCodec.encode_pending_loot(state, registry)
		if not bool(durable_validation.get("success", false)):
			return _prefixed_failure(
				"SAVE runtime pending loot %s" % occurrence_id,
				durable_validation.get("diagnostics", [])
			)
		states.append(state)
	return {"success": true, "states": states, "diagnostics": []}


static func _is_finite_vector3(value: Vector3) -> bool:
	return (
		not is_nan(value.x) and not is_inf(value.x)
		and not is_nan(value.y) and not is_inf(value.y)
		and not is_nan(value.z) and not is_inf(value.z)
	)


static func _prefixed_failure(prefix: String, messages: Array) -> Dictionary:
	var failures: Array[String] = []
	for message in messages:
		failures.append("%s: %s" % [prefix, str(message)])
	return _failure(failures)


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {"success": false, "diagnostics": diagnostics}
