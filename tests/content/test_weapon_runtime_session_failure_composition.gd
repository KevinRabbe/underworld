extends RefCounted

const WeaponRuntimeSessionService := preload("res://gameplay/items/weapons/runtime/weapon_runtime_session_service.gd")
const GameplaySaveCatalog := preload("res://gameplay/persistence/gameplay_save_catalog.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")

const RECIPE_ID := "recipe.hand.iron_sword"
const SWORD_ID := "item.weapon.iron_sword"
const WOOD_ID := "item.resource.wood"
const IRON_ID := "item.resource.iron_chunk"


class NoPresentationPlayer:
	extends Node
	var equipped_weapon_definition = null
	var equipped_weapon_attack_set = null
	var equipped_weapon_attack_resolver = null
	var legacy_tool_visual: String = "stone_axe"

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
		return ["weapon failure fixture catalog failed: %s" % [catalog.get("diagnostics", [])]]
	var registry = catalog.get("registry", null)
	var inventory = ItemContainerState.new().configure(8, 80.0)
	inventory.add_stack(registry.get_definition(WOOD_ID), 1)
	inventory.add_stack(registry.get_definition(IRON_ID), 4)
	var equipment = EquipmentHotbarState.new().configure(
		GameplaySaveCatalog.equipment_rules(),
		GameplaySaveCatalog.hotbar_bindings()
	)
	equipment.select_hotbar(1)
	var player = NoPresentationPlayer.new()
	var session = WeaponRuntimeSessionService.new()
	var configured: Dictionary = session.configure(player, inventory, equipment)
	if not bool(configured.get("success", false)):
		failures.append("weapon failure fixture could not configure hands state")
		player.free()
		return failures

	var result: Dictionary = session.craft_and_equip(RECIPE_ID)
	if bool(result.get("success", true)):
		failures.append("missing semantic hand attachment unexpectedly accepted weapon presentation")
	if str(result.get("stage", "")) != "presentation":
		failures.append("presentation failure was not classified at presentation stage")
	if equipment.selected_hotbar() != 4 or equipment.selected_definition() == null:
		failures.append("presentation failure rolled back committed canonical equipment selection")
	elif str(equipment.selected_definition().content_id) != SWORD_ID:
		failures.append("presentation failure changed committed sword equipment identity")
	if inventory.quantity_of(WOOD_ID) != 0 or inventory.quantity_of(IRON_ID) != 0:
		failures.append("presentation failure rolled back already-committed crafting transaction")
	if player.equipped_weapon_definition == null or str(player.equipped_weapon_definition.content_id) != SWORD_ID:
		failures.append("presentation failure incorrectly cleared valid gameplay weapon source")
	if session.presented_weapon_instance() != null:
		failures.append("presentation failure retained a partial weapon presentation node")

	session.clear()
	player.free()
	failures.sort()
	return failures
