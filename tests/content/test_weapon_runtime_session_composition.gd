extends RefCounted

const WeaponRuntimeSessionService := preload("res://gameplay/items/weapons/runtime/weapon_runtime_session_service.gd")
const GameplaySaveCatalog := preload("res://gameplay/persistence/gameplay_save_catalog.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")

const RECIPE_ID := "recipe.hand.iron_sword"
const SWORD_ID := "item.weapon.iron_sword"
const WOOD_ID := "item.resource.wood"
const IRON_ID := "item.resource.iron_chunk"


class FakeAnimationRuntime:
	extends RefCounted
	var hand_root := Node3D.new()

	func attachment_root(role: String):
		return hand_root if role == "rig_role.socket.hand.right" else null


class FakePlayer:
	extends Node
	var animation_controller = FakeAnimationRuntime.new()
	var equipped_weapon_definition = null
	var equipped_weapon_attack_set = null
	var equipped_weapon_attack_resolver = null

	func configure_equipped_weapon_attack_source(weapon, attack_set, resolver) -> void:
		equipped_weapon_definition = weapon
		equipped_weapon_attack_set = attack_set
		equipped_weapon_attack_resolver = resolver


static func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog: Dictionary = GameplaySaveCatalog.build_registry()
	if not bool(catalog.get("success", false)):
		return ["weapon session fixture catalog failed: %s" % [catalog.get("diagnostics", [])]]
	var durable_registry = catalog.get("registry", null)
	var wood = durable_registry.get_definition(WOOD_ID)
	var iron = durable_registry.get_definition(IRON_ID)
	if wood == null or iron == null:
		return ["weapon session fixture could not resolve authored ingredients"]

	var inventory = ItemContainerState.new().configure(8, 80.0)
	if not bool(inventory.add_stack(wood, 1).get("success", false)):
		failures.append("weapon session fixture could not add wood")
	if not bool(inventory.add_stack(iron, 4).get("success", false)):
		failures.append("weapon session fixture could not add iron")
	var equipment = EquipmentHotbarState.new().configure(
		GameplaySaveCatalog.equipment_rules(),
		GameplaySaveCatalog.hotbar_bindings()
	)
	equipment.select_hotbar(1)
	var player = FakePlayer.new()
	var session = WeaponRuntimeSessionService.new()
	var configured: Dictionary = session.configure(player, inventory, equipment)
	if not bool(configured.get("success", false)):
		failures.append("weapon runtime session failed clean hands startup: %s" % [configured.get("diagnostics", [])])
		player.free()
		return failures

	var capabilities: Array = session.craft_capabilities()
	if capabilities.size() != 1 or str(capabilities[0].get("recipe_id", "")) != RECIPE_ID:
		failures.append("weapon runtime did not expose authored sword craft capability")
	var progressed: Dictionary = session.craft_and_equip(RECIPE_ID)
	if not bool(progressed.get("success", false)):
		failures.append("weapon runtime craft/equip failed: %s" % [progressed.get("diagnostics", [])])
	else:
		if inventory.quantity_of(WOOD_ID) != 0 or inventory.quantity_of(IRON_ID) != 0:
			failures.append("weapon runtime craft/equip did not consume authored ingredients")
		if equipment.selected_hotbar() != 4 or str(equipment.selected_definition().content_id) != SWORD_ID:
			failures.append("weapon runtime craft/equip did not select canonical hotbar-4 sword")
		if player.equipped_weapon_definition == null or str(player.equipped_weapon_definition.content_id) != SWORD_ID:
			failures.append("weapon runtime did not bind canonical sword attack source")
		if session.presented_weapon_instance() == null:
			failures.append("weapon runtime did not realize authored sword presentation")
		if player.animation_controller.hand_root.get_child_count() != 1:
			failures.append("weapon runtime did not own exactly one hand presentation")

	var to_hands: Dictionary = equipment.select_hotbar(1)
	if not bool(to_hands.get("success", false)):
		failures.append("weapon runtime fixture could not switch to hands")
	else:
		var cleared: Dictionary = session.sync_selected()
		if not bool(cleared.get("success", false)):
			failures.append("weapon runtime failed hands resync: %s" % [cleared.get("diagnostics", [])])
		if player.equipped_weapon_definition != null:
			failures.append("weapon runtime retained stale sword source after switch-away")
		if session.presented_weapon_instance() != null or player.animation_controller.hand_root.get_child_count() != 0:
			failures.append("weapon runtime retained stale sword presentation after switch-away")

	equipment.select_hotbar(4)
	var rebound: Dictionary = session.sync_selected()
	if not bool(rebound.get("success", false)):
		failures.append("weapon runtime failed sword rebound: %s" % [rebound.get("diagnostics", [])])
	var first_instance = session.presented_weapon_instance()
	var repeated: Dictionary = session.sync_selected()
	if not bool(repeated.get("success", false)):
		failures.append("weapon runtime failed repeated canonical resync")
	if session.presented_weapon_instance() == first_instance:
		failures.append("weapon runtime repeated resync did not replace presentation instance")
	if player.animation_controller.hand_root.get_child_count() != 1:
		failures.append("weapon runtime repeated resync created duplicate hand presentations")

	session.clear()
	if player.animation_controller.hand_root.get_child_count() != 0:
		failures.append("weapon runtime teardown retained hand presentation")
	player.animation_controller.hand_root.free()
	player.free()
	failures.sort()
	return failures
