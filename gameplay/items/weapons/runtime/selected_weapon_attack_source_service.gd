extends RefCounted

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const ArchetypeDefinition := preload("res://core/content/archetypes/archetype_definition.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const EquippedItemResolver := preload("res://gameplay/items/equipment/equipped_item_resolver.gd")
const WeaponDefinition := preload("res://gameplay/items/weapons/definitions/weapon_definition.gd")
const WeaponAttackSetDefinition := preload("res://gameplay/items/weapons/definitions/weapon_attack_set_definition.gd")
const WeaponAttackResolver := preload("res://gameplay/items/weapons/runtime/weapon_attack_resolver.gd")
const ProgressionCraftEquipService := preload("res://gameplay/crafting/runtime/progression_craft_equip_service.gd")
const PlayerAttackCatalog := preload("res://gameplay/combat/attacks/player_attack_catalog.gd")

const LIGHT_TECHNIQUE := "weapon_technique.light.primary"
const HEAVY_TECHNIQUE := "weapon_technique.heavy.primary"


func craft_equip_and_bind(
	progression_service,
	recipe_content_id: String,
	context,
	inventory,
	equipment_state,
	content_registry,
	player,
	output_item_id: String,
	target_slot_key: String,
	preferred_hotbar: int = 0
) -> Dictionary:
	if progression_service == null or not progression_service is ProgressionCraftEquipService:
		return _progression_failure(
			"preflight",
			["weapon progression requires accepted ProgressionCraftEquipService"]
		)

	var progressed: Dictionary = progression_service.craft_and_equip(
		recipe_content_id,
		context,
		inventory,
		equipment_state,
		output_item_id,
		target_slot_key,
		preferred_hotbar
	)
	if not bool(progressed.get("success", false)):
		var failed_progression: Dictionary = progressed.duplicate(true)
		failed_progression["source_binding_attempted"] = false
		return failed_progression

	var bound: Dictionary = bind_selected(equipment_state, content_registry, player)
	if not bool(bound.get("success", false)) or not bool(bound.get("weapon_bound", false)):
		var failures: Array = bound.get("diagnostics", []).duplicate()
		if failures.is_empty():
			failures.append("progression output did not resolve a selected WeaponDefinition")
		var failed_binding: Dictionary = _progression_failure("weapon_source", failures)
		failed_binding["progression_succeeded"] = true
		failed_binding["source_binding_attempted"] = true
		failed_binding["events"] = progressed.get("events", []).duplicate(true)
		failed_binding["craft_transaction_fingerprint"] = str(
			progressed.get("craft_transaction_fingerprint", "")
		)
		failed_binding["equip_transaction_fingerprint"] = str(
			progressed.get("equip_transaction_fingerprint", "")
		)
		failed_binding["selected_item"] = progressed.get("selected_item", {}).duplicate(true)
		return failed_binding

	var events: Array = progressed.get("events", []).duplicate(true)
	events.append({
		"type": "weapon.source_bound",
		"item_id": str(bound.get("item_id", "")),
		"attack_set_id": str(bound.get("attack_set_id", "")),
		"slot_key": str(bound.get("slot_key", "")),
	})
	return {
		"success": true,
		"stage": "complete",
		"diagnostics": [],
		"progression_succeeded": true,
		"source_binding_attempted": true,
		"weapon_bound": true,
		"item_id": str(bound.get("item_id", "")),
		"slot_key": str(bound.get("slot_key", "")),
		"attack_set_id": str(bound.get("attack_set_id", "")),
		"archetype_id": str(bound.get("archetype_id", "")),
		"light_attack_id": str(bound.get("light_attack_id", "")),
		"heavy_attack_id": str(bound.get("heavy_attack_id", "")),
		"selected_item": progressed.get("selected_item", {}).duplicate(true),
		"events": events,
		"craft_transaction_fingerprint": str(
			progressed.get("craft_transaction_fingerprint", "")
		),
		"equip_transaction_fingerprint": str(
			progressed.get("equip_transaction_fingerprint", "")
		),
	}


func bind_selected(
	equipment_state,
	content_registry,
	player,
	resolver = null
) -> Dictionary:
	var failures: Array[String] = []
	if equipment_state == null or not equipment_state is EquipmentHotbarState:
		failures.append("weapon source binding requires EquipmentHotbarState")
	if content_registry == null or not content_registry is ContentRegistry:
		failures.append("weapon source binding requires ContentRegistry")
	elif not content_registry.is_valid():
		for failure in content_registry.diagnostics():
			failures.append("content registry: %s" % failure)
	if player == null or not player.has_method("configure_equipped_weapon_attack_source"):
		failures.append("weapon source binding requires Player weapon-source seam")
	if resolver != null and not resolver is WeaponAttackResolver:
		failures.append("weapon source binding resolver must be WeaponAttackResolver")

	if player != null and player.has_method("configure_equipped_weapon_attack_source"):
		player.configure_equipped_weapon_attack_source(null, null, null)
	if not failures.is_empty():
		return _failure(failures)

	var selected: Dictionary = EquippedItemResolver.new().resolve_selected(equipment_state)
	if not bool(selected.get("success", false)):
		return _failure(selected.get("diagnostics", []))
	var definition = selected.get("definition", null)
	if definition == null or not definition is WeaponDefinition:
		return {
			"success": true,
			"diagnostics": [],
			"selection_kind": str(selected.get("selection_kind", "hands")),
			"item_id": str(selected.get("item_id", "")),
			"slot_key": str(selected.get("slot_key", "")),
			"weapon_bound": false,
		}

	var attack_set_resolution: Dictionary = content_registry.resolve(
		str(definition.attack_set_id),
		"attack_set"
	)
	for failure in attack_set_resolution.get("diagnostics", []):
		failures.append("weapon attack-set resolution: %s" % failure)
	var attack_set = attack_set_resolution.get("definition", null)
	if attack_set == null or not attack_set is WeaponAttackSetDefinition:
		failures.append(
			"weapon attack-set target must inherit WeaponAttackSetDefinition: %s" % str(definition.attack_set_id)
		)

	var archetype_resolution: Dictionary = content_registry.resolve(
		str(definition.archetype_id),
		"archetype"
	)
	for failure in archetype_resolution.get("diagnostics", []):
		failures.append("weapon archetype resolution: %s" % failure)
	var archetype = archetype_resolution.get("definition", null)
	if archetype == null or not archetype is ArchetypeDefinition:
		failures.append(
			"weapon archetype target must inherit ArchetypeDefinition: %s" % str(definition.archetype_id)
		)
	if not failures.is_empty():
		return _failure(failures)

	var attack_definitions: Array = []
	for technique_role in [LIGHT_TECHNIQUE, HEAVY_TECHNIQUE]:
		var attack_id: StringName = attack_set.attack_id_for(technique_role)
		if attack_id.is_empty():
			failures.append("weapon attack set is missing required technique: %s" % technique_role)
			continue
		var attack_definition = PlayerAttackCatalog.for_attack_id(attack_id)
		if attack_definition == null:
			failures.append("gameplay attack catalog does not provide semantic attack id: %s" % str(attack_id))
			continue
		attack_definitions.append(attack_definition)
	if not failures.is_empty():
		return _failure(failures)

	var weapon_resolver = resolver if resolver != null else WeaponAttackResolver.new()
	weapon_resolver.configure_attack_definitions(attack_definitions)
	if not weapon_resolver.is_valid():
		return _failure(weapon_resolver.diagnostics())
	for technique_role in [LIGHT_TECHNIQUE, HEAVY_TECHNIQUE]:
		var resolved: Dictionary = weapon_resolver.resolve_attack(
			definition,
			attack_set,
			technique_role
		)
		for failure in resolved.get("diagnostics", []):
			failures.append("%s: %s" % [technique_role, failure])
	if not failures.is_empty():
		return _failure(failures)

	player.configure_equipped_weapon_attack_source(definition, attack_set, weapon_resolver)
	return {
		"success": true,
		"diagnostics": [],
		"selection_kind": "weapon",
		"weapon_bound": true,
		"item_id": str(definition.content_id),
		"slot_key": str(selected.get("slot_key", "")),
		"attack_set_id": str(attack_set.content_id),
		"light_attack_id": str(attack_set.attack_id_for(LIGHT_TECHNIQUE)),
		"heavy_attack_id": str(attack_set.attack_id_for(HEAVY_TECHNIQUE)),
		"archetype_id": str(archetype.content_id),
	}


static func _progression_failure(stage: String, messages: Array) -> Dictionary:
	var result: Dictionary = _failure(messages)
	result["stage"] = stage
	result["progression_succeeded"] = false
	result["source_binding_attempted"] = false
	result["events"] = []
	result["craft_transaction_fingerprint"] = ""
	result["equip_transaction_fingerprint"] = ""
	return result


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {
		"success": false,
		"diagnostics": diagnostics,
		"selection_kind": "invalid",
		"weapon_bound": false,
		"item_id": "",
		"slot_key": "",
	}
