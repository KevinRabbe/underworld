extends RefCounted

const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const EquippedItemResolver := preload("res://gameplay/items/equipment/equipped_item_resolver.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")

const DEFAULT_MATERIAL_IDS: Array[String] = [
	"item.resource.wood",
	"item.resource.stone",
	"item.resource.burrower_chitin",
]
const HOTBAR_MIN := 1
const HOTBAR_MAX := 4

var _equipped_item_resolver := EquippedItemResolver.new()


func sample(
	player,
	inventory_state,
	equipment_state,
	material_ids: Array[String] = DEFAULT_MATERIAL_IDS
) -> Dictionary:
	var failures: Array[String] = []
	_validate_player(player, failures)
	if inventory_state == null or not inventory_state is ItemContainerState:
		failures.append("HUD inventory source must be ItemContainerState")
	else:
		for failure in inventory_state.validate_container():
			failures.append("HUD inventory source: %s" % failure)
	if equipment_state == null or not equipment_state is EquipmentHotbarState:
		failures.append("HUD equipment source must be EquipmentHotbarState")
	if not failures.is_empty():
		return _failure(failures)

	var health: int = int(player.call("get_health"))
	var max_health: int = int(player.call("get_max_health"))
	var stamina: float = float(player.call("get_stamina"))
	var max_stamina: float = float(player.call("get_max_stamina"))
	if max_health <= 0:
		failures.append("HUD player max health must be > 0")
	if is_nan(stamina) or is_inf(stamina) or is_nan(max_stamina) or is_inf(max_stamina):
		failures.append("HUD player stamina values must be finite")
	elif max_stamina <= 0.0:
		failures.append("HUD player max stamina must be > 0")
	if not failures.is_empty():
		return _failure(failures)

	var equipment_diagnostics: Array[String] = []
	for failure in equipment_state.validate_state():
		equipment_diagnostics.append("HUD equipment source: %s" % failure)
	var hotbar: Array[Dictionary] = _invalid_hotbar(equipment_state.selected_hotbar())
	var equipment_valid: bool = equipment_diagnostics.is_empty()
	if equipment_valid:
		hotbar = _build_hotbar(equipment_state, equipment_diagnostics)
		equipment_valid = equipment_diagnostics.is_empty()
		if not equipment_valid:
			hotbar = _invalid_hotbar(equipment_state.selected_hotbar())

	var materials: Array[Dictionary] = []
	var seen_materials: Dictionary = {}
	for item_id in material_ids:
		var semantic_id: String = str(item_id).strip_edges()
		if semantic_id.is_empty() or seen_materials.has(semantic_id):
			continue
		seen_materials[semantic_id] = true
		materials.append({
			"item_id": semantic_id,
			"quantity": inventory_state.quantity_of(semantic_id),
		})

	return {
		"success": true,
		"diagnostics": equipment_diagnostics,
		"health": health,
		"max_health": max_health,
		"health_ratio": clampf(float(health) / float(max_health), 0.0, 1.0),
		"stamina": stamina,
		"max_stamina": max_stamina,
		"stamina_ratio": clampf(stamina / max_stamina, 0.0, 1.0),
		"action_state": str(player.call("get_action_state_name")),
		"equipment_valid": equipment_valid,
		"hotbar": hotbar,
		"selected_hotbar": equipment_state.selected_hotbar(),
		"materials": materials,
	}


func feedback_text(event: Dictionary) -> String:
	var event_type: String = str(event.get("type", "")).strip_edges()
	if event_type.is_empty():
		return ""
	match event_type:
		"harvest.completed", "harvest.pickup_collected":
			var quantity: int = maxi(int(event.get("quantity", 0)), 0)
			var item_id: String = str(event.get("item_id", ""))
			if quantity <= 0 or item_id.is_empty():
				return ""
			return "+%d %s" % [quantity, display_name_for_id(item_id)]
		"harvest.hit_registered":
			var object_type: String = str(event.get("object_type", "resource"))
			var hits: int = maxi(int(event.get("hits", 0)), 0)
			var required_hits: int = maxi(int(event.get("required_hits", 0)), 0)
			if required_hits <= 0:
				return ""
			return "%s %d/%d" % [object_type.capitalize(), hits, required_hits]
		"combat.parry_succeeded":
			return "Parry!"
		"craft.completed":
			var crafted_item: String = str(event.get("item_id", ""))
			return "Crafted %s" % display_name_for_id(crafted_item) if not crafted_item.is_empty() else "Craft complete"
		"equipment.hotbar_selected":
			var slot_key: String = str(event.get("slot_key", ""))
			return "Selected %s" % display_name_for_id(slot_key) if not slot_key.is_empty() else "Selection changed"
		_:
			return ""


static func display_name_for_id(semantic_id: String) -> String:
	var value: String = semantic_id.strip_edges()
	if value.is_empty():
		return ""
	var parts: PackedStringArray = value.split(".")
	var suffix: String = parts[parts.size() - 1] if not parts.is_empty() else value
	return suffix.replace("_", " ").capitalize()


func _build_hotbar(equipment_state, failures: Array[String]) -> Array[Dictionary]:
	var snapshot: Dictionary = equipment_state.canonical_snapshot()
	var bindings: Dictionary = {}
	for raw_binding in snapshot.get("hotbar_bindings", []):
		if not raw_binding is Dictionary:
			failures.append("HUD equipment binding snapshot is malformed")
			continue
		var binding: Dictionary = raw_binding
		var index: int = int(binding.get("hotbar", 0))
		var slot_key: String = str(binding.get("slot_key", ""))
		if index < HOTBAR_MIN or index > HOTBAR_MAX or slot_key.is_empty():
			failures.append("HUD equipment binding is outside four-slot semantic hotbar")
			continue
		bindings[index] = slot_key

	var selected_index: int = equipment_state.selected_hotbar()
	var selected_resolution: Dictionary = _equipped_item_resolver.resolve_selected(equipment_state)
	if not bool(selected_resolution.get("success", false)):
		for diagnostic in selected_resolution.get("diagnostics", []):
			failures.append("HUD selected equipment: %s" % diagnostic)

	var hotbar: Array[Dictionary] = []
	for index in range(HOTBAR_MIN, HOTBAR_MAX + 1):
		var slot_key: String = str(bindings.get(index, ""))
		if slot_key.is_empty():
			hotbar.append(_hotbar_entry(index, "unbound", "", "", index == selected_index))
			continue

		var definition = equipment_state.definition_at(slot_key)
		var stored_state: Dictionary = equipment_state.state_at(slot_key)
		if definition == null and stored_state.is_empty():
			var empty_kind: String = "hands" if slot_key.ends_with(".hands") else "empty"
			hotbar.append(_hotbar_entry(index, empty_kind, slot_key, "", index == selected_index))
			continue
		if definition == null or not definition is ItemDefinition or stored_state.is_empty():
			failures.append("HUD equipment slot is structurally inconsistent: %s" % slot_key)
			hotbar.append(_hotbar_entry(index, "invalid", slot_key, "", index == selected_index))
			continue
		var stored_item_id: String = str(stored_state.get("state", {}).get("item_id", ""))
		if stored_item_id != str(definition.content_id):
			failures.append("HUD equipment slot definition does not match stored item: %s" % slot_key)
			hotbar.append(_hotbar_entry(index, "invalid", slot_key, "", index == selected_index))
			continue
		hotbar.append(_hotbar_entry(
			index,
			"item",
			slot_key,
			str(definition.content_id),
			index == selected_index
		))

	if bool(selected_resolution.get("success", false)):
		var selected_kind: String = str(selected_resolution.get("selection_kind", ""))
		var selected_slot_key: String = str(selected_resolution.get("slot_key", ""))
		var selected_item_id: String = str(selected_resolution.get("item_id", ""))
		if selected_kind == "hands" and not selected_slot_key.ends_with(".hands"):
			selected_kind = "empty"
		for entry in hotbar:
			if int(entry.get("hotbar", 0)) != selected_index:
				continue
			if str(entry.get("slot_key", "")) != selected_slot_key:
				failures.append("HUD selected hotbar binding disagrees with resolver")
				break
			if selected_kind == "item" and str(entry.get("item_id", "")) != selected_item_id:
				failures.append("HUD selected item disagrees with resolver")
			break
	return hotbar


static func _hotbar_entry(
	hotbar: int,
	kind: String,
	slot_key: String,
	item_id: String,
	selected: bool
) -> Dictionary:
	return {
		"hotbar": hotbar,
		"kind": kind,
		"slot_key": slot_key,
		"item_id": item_id,
		"selected": selected,
	}


static func _invalid_hotbar(selected_hotbar: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(HOTBAR_MIN, HOTBAR_MAX + 1):
		result.append(_hotbar_entry(index, "invalid", "", "", index == selected_hotbar))
	return result


static func _validate_player(player, failures: Array[String]) -> void:
	if player == null:
		failures.append("HUD player source is required")
		return
	for method_name in [
		"get_health",
		"get_max_health",
		"get_stamina",
		"get_max_stamina",
		"get_action_state_name",
	]:
		if not player.has_method(method_name):
			failures.append("HUD player source lacks read API: %s" % method_name)


static func _failure(messages: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for message in messages:
		diagnostics.append(str(message))
	diagnostics.sort()
	return {
		"success": false,
		"diagnostics": diagnostics,
		"equipment_valid": false,
		"hotbar": _invalid_hotbar(HOTBAR_MIN),
		"materials": [],
	}
