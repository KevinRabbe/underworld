extends RefCounted

const ContentRegistry := preload("res://core/content/registry/content_registry.gd")
const ArchetypeRealizer := preload("res://core/content/archetypes/archetype_realizer.gd")
const PackedSceneArchetypeAdapter := preload("res://core/content/archetypes/packed_scene_archetype_adapter.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const EquippedItemResolver := preload("res://gameplay/items/equipment/equipped_item_resolver.gd")
const WeaponDefinition := preload("res://gameplay/items/weapons/definitions/weapon_definition.gd")
const SelectedWeaponAttackSourceService := preload("res://gameplay/items/weapons/runtime/selected_weapon_attack_source_service.gd")

var _attack_source_service = SelectedWeaponAttackSourceService.new()
var _resolver = EquippedItemResolver.new()
var _presented_instance: Node = null


func sync_selected(
	equipment_state,
	content_registry,
	validation: Dictionary,
	player
) -> Dictionary:
	var failures: Array[String] = []
	if equipment_state == null or not equipment_state is EquipmentHotbarState:
		failures.append("selected-equipment composition requires EquipmentHotbarState")
	if content_registry == null or not content_registry is ContentRegistry:
		failures.append("selected-equipment composition requires ContentRegistry")
	elif not content_registry.is_valid():
		for diagnostic in content_registry.diagnostics():
			failures.append("content registry: %s" % diagnostic)
	if not bool(validation.get("success", false)):
		failures.append("selected-equipment presentation requires successful content validation evidence")
	if player == null or not is_instance_valid(player):
		failures.append("selected-equipment composition requires live Player")
	if not failures.is_empty():
		_release_presentation()
		return _failure(failures)

	var selected: Dictionary = _resolver.resolve_selected(equipment_state)
	if not bool(selected.get("success", false)):
		_release_presentation()
		var selection_failure: Dictionary = _failure(selected.get("diagnostics", []))
		selection_failure["stage"] = "selection"
		return selection_failure
	var definition = selected.get("definition", null)

	# A canonical weapon selection must not inherit a stale legacy axe/pickaxe
	# presentation. This is presentation compatibility only: equipment remains the
	# sole selection authority, and the semantic weapon source is rebound below.
	if definition != null and definition is WeaponDefinition and player.has_method("set_equipped_tool"):
		player.call("set_equipped_tool", "hands")

	var source_result: Dictionary = _attack_source_service.bind_selected(
		equipment_state,
		content_registry,
		player
	)
	if not bool(source_result.get("success", false)):
		_release_presentation()
		var source_failures: Array = source_result.get("diagnostics", []).duplicate()
		if source_failures.is_empty():
			source_failures.append("selected weapon source binding failed without diagnostics")
		var failed_source: Dictionary = _failure(source_failures)
		failed_source["stage"] = "weapon_source"
		return failed_source

	if definition == null or not definition is WeaponDefinition:
		_release_presentation()
		return {
			"success": true,
			"stage": "complete",
			"diagnostics": [],
			"selection_kind": str(selected.get("selection_kind", "hands")),
			"item_id": str(selected.get("item_id", "")),
			"slot_key": str(selected.get("slot_key", "")),
			"weapon_bound": false,
			"presentation_bound": false,
			"archetype_id": "",
			"grip_rig_role": "",
		}

	_release_presentation()
	var archetype_id: String = str(definition.archetype_id)
	var grip_rig_role: String = str(definition.grip_rig_role)
	if archetype_id.is_empty() or grip_rig_role.is_empty():
		var semantic_failure: Dictionary = _failure([
			"selected weapon requires archetype_id and semantic grip_rig_role"
		])
		semantic_failure["stage"] = "presentation"
		semantic_failure["weapon_bound"] = bool(source_result.get("weapon_bound", false))
		return semantic_failure

	var attachment_root = _resolve_attachment_root(player, grip_rig_role)
	if attachment_root == null:
		var attachment_failure: Dictionary = _failure([
			"Player presentation does not expose selected weapon grip role: %s" % grip_rig_role
		])
		attachment_failure["stage"] = "presentation"
		attachment_failure["weapon_bound"] = bool(source_result.get("weapon_bound", false))
		return attachment_failure

	var realizer = ArchetypeRealizer.new()
	var adapter_failures: Array[String] = realizer.register_adapter(PackedSceneArchetypeAdapter.new())
	if not adapter_failures.is_empty():
		var adapter_failure: Dictionary = _failure(adapter_failures)
		adapter_failure["stage"] = "presentation"
		adapter_failure["weapon_bound"] = bool(source_result.get("weapon_bound", false))
		return adapter_failure
	var realized: Dictionary = realizer.realize(content_registry, validation, archetype_id)
	if not bool(realized.get("success", false)):
		var realization_failure: Dictionary = _failure(realized.get("diagnostics", []))
		realization_failure["stage"] = "presentation"
		realization_failure["weapon_bound"] = bool(source_result.get("weapon_bound", false))
		return realization_failure
	var instance = realized.get("instance", null)
	if instance == null or not instance is Node:
		if instance != null and is_instance_valid(instance):
			instance.free()
		var instance_failure: Dictionary = _failure([
			"selected weapon archetype did not realize a Node presentation"
		])
		instance_failure["stage"] = "presentation"
		instance_failure["weapon_bound"] = bool(source_result.get("weapon_bound", false))
		return instance_failure

	attachment_root.add_child(instance)
	_presented_instance = instance
	var result: Dictionary = source_result.duplicate(true)
	result["success"] = true
	result["stage"] = "complete"
	result["presentation_bound"] = true
	result["archetype_id"] = archetype_id
	result["grip_rig_role"] = grip_rig_role
	result["diagnostics"] = []
	return result


func clear() -> void:
	_release_presentation()


func presented_instance():
	if _presented_instance == null or not is_instance_valid(_presented_instance):
		return null
	return _presented_instance


func _resolve_attachment_root(player, rig_role: String):
	var animation_runtime = player.get("animation_controller")
	if animation_runtime != null and animation_runtime.has_method("attachment_root"):
		var semantic_root = animation_runtime.call("attachment_root", rig_role)
		if semantic_root != null and semantic_root is Node3D:
			return semantic_root
	var fallback = player.get("tool_visual_root")
	if fallback != null and fallback is Node3D:
		return fallback
	return null


func _release_presentation() -> void:
	if _presented_instance != null and is_instance_valid(_presented_instance):
		_presented_instance.free()
	_presented_instance = null


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {
		"success": false,
		"stage": "preflight",
		"diagnostics": diagnostics,
		"selection_kind": "invalid",
		"item_id": "",
		"slot_key": "",
		"weapon_bound": false,
		"presentation_bound": false,
		"archetype_id": "",
		"grip_rig_role": "",
	}
