extends RefCounted

const WeaponRuntimeSessionService := preload("res://gameplay/items/weapons/runtime/weapon_runtime_session_service.gd")
const GameplaySaveCatalog := preload("res://gameplay/persistence/gameplay_save_catalog.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const EquipmentService := preload("res://gameplay/items/equipment/equipment_service.gd")

const SWORD_ID := "item.weapon.iron_sword"
const SLOT_UTILITY := "equipment_slot.hotbar.utility"


class FakeAnimationRuntime:
	extends RefCounted
	var hand_root := Node3D.new()
	func attachment_root(role: String):
		return hand_root if role == "rig_role.socket.hand.right" else null


class RestoredPlayer:
	extends Node
	var animation_controller = FakeAnimationRuntime.new()
	var equipped_weapon_definition = null
	var equipped_weapon_attack_set = null
	var equipped_weapon_attack_resolver = null
	var legacy_tool_visual: String = "hands"

	func set_equipped_tool(tool_id: String) -> void:
		legacy_tool_visual = tool_id
		configure_equipped_weapon_attack_source(null, null, null)

	func configure_equipped_weapon_attack_source(weapon, attack_set, resolver) -> void:
		equipped_weapon_definition = weapon
		equipped_weapon_attack_set = attack_set
		equipped_weapon_attack_resolver = resolver


static func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog: Dictionary = GameplaySaveCatalog.build_registry()
	if not bool(catalog.get("success", false)):
		return ["weapon restore fixture catalog failed"]
	var registry = catalog.get("registry", null)
	var sword = registry.get_definition(SWORD_ID)
	if sword == null:
		return ["weapon restore fixture could not resolve durable sword definition"]

	var inventory = ItemContainerState.new().configure(8, 80.0)
	var added: Dictionary = inventory.add_instance(sword, {})
	if not bool(added.get("success", false)):
		return ["weapon restore fixture could not seed existing sword instance"]
	var source_slot: int = -1
	for index in range(inventory.slot_capacity()):
		var record: Dictionary = inventory.state_at(index)
		if str(record.get("state", {}).get("item_id", "")) == SWORD_ID:
			source_slot = index
			break
	if source_slot < 0:
		return ["weapon restore fixture could not locate existing sword instance"]

	var equipment = EquipmentHotbarState.new().configure(
		GameplaySaveCatalog.equipment_rules(),
		GameplaySaveCatalog.hotbar_bindings()
	)
	var equipped: Dictionary = EquipmentService.new().equip_from_inventory(
		equipment,
		inventory,
		source_slot,
		sword,
		SLOT_UTILITY
	)
	if not bool(equipped.get("success", false)):
		return ["weapon restore fixture could not establish canonical loaded equipment: %s" % [equipped.get("diagnostics", [])]]
	equipment.select_hotbar(4)

	var player = RestoredPlayer.new()
	var session = WeaponRuntimeSessionService.new()
	var configured: Dictionary = session.configure(player, inventory, equipment)
	if not bool(configured.get("success", false)):
		failures.append("fresh session failed to reconstruct restored selected sword: %s" % [configured.get("diagnostics", [])])
	else:
		if equipment.selected_hotbar() != 4 or str(equipment.selected_definition().content_id) != SWORD_ID:
			failures.append("session reconstruction changed restored canonical equipment selection")
		if player.equipped_weapon_definition == null or str(player.equipped_weapon_definition.content_id) != SWORD_ID:
			failures.append("session reconstruction did not bind restored sword gameplay source")
		if session.presented_weapon_instance() == null or player.animation_controller.hand_root.get_child_count() != 1:
			failures.append("session reconstruction did not realize restored sword presentation")
		if inventory.quantity_of(SWORD_ID) != 0:
			failures.append("session reconstruction duplicated equipped sword back into inventory")

	session.clear()
	player.animation_controller.hand_root.free()
	player.free()
	failures.sort()
	return failures
