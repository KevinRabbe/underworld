extends RefCounted

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const EquippedItemResolver := preload("res://gameplay/items/equipment/equipped_item_resolver.gd")
const WeaponDefinition := preload("res://gameplay/items/weapons/definitions/weapon_definition.gd")
const WeaponAttackSetDefinition := preload("res://gameplay/items/weapons/definitions/weapon_attack_set_definition.gd")
const WeaponAttackResolver := preload("res://gameplay/items/weapons/runtime/weapon_attack_resolver.gd")
const PlayerAttackCatalog := preload("res://gameplay/combat/attacks/player_attack_catalog.gd")

const LIGHT_TECHNIQUE := "weapon_technique.light.primary"
const HEAVY_TECHNIQUE := "weapon_technique.heavy.primary"


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
		"archetype_id": str(definition.archetype_id),
	}


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
