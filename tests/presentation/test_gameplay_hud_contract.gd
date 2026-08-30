extends RefCounted

const GameplayHudReadModel := preload("res://presentation/ui/hud/gameplay_hud_read_model.gd")
const GameplayHud := preload("res://presentation/ui/hud/gameplay_hud.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const EquipmentSlotRule := preload("res://gameplay/items/equipment/equipment_slot_rule.gd")
const EquipmentHotbarState := preload("res://gameplay/items/equipment/equipment_hotbar_state.gd")
const EquipmentService := preload("res://gameplay/items/equipment/equipment_service.gd")

const EQUIPMENT_ROOT := "category.item.equipment"
const EQUIPABLE := "capability.equipable"
const SLOT_HANDS := "equipment_slot.hotbar.hands"
const SLOT_AXE := "equipment_slot.hotbar.axe"
const SLOT_PICKAXE := "equipment_slot.hotbar.pickaxe"
const SLOT_UTILITY := "equipment_slot.hotbar.utility"


class FakePlayer:
	extends RefCounted
	var health: int = 65
	var max_health: int = 100
	var stamina: float = 37.5
	var max_stamina: float = 100.0
	var action_state: String = "block"

	func get_health() -> int:
		return health

	func get_max_health() -> int:
		return max_health

	func get_stamina() -> float:
		return stamina

	func get_max_stamina() -> float:
		return max_stamina

	func get_action_state_name() -> String:
		return action_state


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_authoritative_sampling_is_read_only(failures)
	_test_hands_empty_and_selected_item_semantics(failures)
	_test_malformed_equipment_is_visible_and_safe(failures)
	_test_semantic_feedback_is_presentation_only(failures)
	_test_renderer_remains_useful_without_debug_hud(failures)
	return failures


static func _test_authoritative_sampling_is_read_only(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(failures)
	if fixture.is_empty():
		return
	var player = fixture["player"]
	var inventory = fixture["inventory"]
	var equipment = fixture["equipment"]
	var inventory_before: String = inventory.canonical_json()
	var equipment_before: String = equipment.canonical_json()

	var model: Dictionary = GameplayHudReadModel.new().sample(
		player,
		inventory,
		equipment,
		["item.resource.wood", "item.resource.stone", "item.resource.burrower_chitin"]
	)
	_expect(failures, "HUD read model samples valid authoritative state", bool(model.get("success", false)))
	_expect(failures, "HUD health uses accepted player getter", int(model.get("health", 0)) == 65 and int(model.get("max_health", 0)) == 100)
	_expect(failures, "HUD stamina uses accepted player getter", is_equal_approx(float(model.get("stamina", 0.0)), 37.5) and is_equal_approx(float(model.get("max_stamina", 0.0)), 100.0))
	_expect(failures, "HUD action state is presentation sampling only", str(model.get("action_state", "")) == "block")
	var quantities: Dictionary = _material_quantities(model.get("materials", []))
	_expect(failures, "HUD wood quantity comes from ItemContainerState", int(quantities.get("item.resource.wood", -1)) == 7)
	_expect(failures, "HUD stone quantity comes from ItemContainerState", int(quantities.get("item.resource.stone", -1)) == 4)
	_expect(failures, "HUD absent accepted material remains semantic zero", int(quantities.get("item.resource.burrower_chitin", -1)) == 0)
	_expect(failures, "HUD sampling does not mutate inventory canonical state", inventory.canonical_json() == inventory_before)
	_expect(failures, "HUD sampling does not mutate equipment canonical state", equipment.canonical_json() == equipment_before)


static func _test_hands_empty_and_selected_item_semantics(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(failures)
	if fixture.is_empty():
		return
	var model: Dictionary = GameplayHudReadModel.new().sample(
		fixture["player"],
		fixture["inventory"],
		fixture["equipment"]
	)
	var hotbar: Array = model.get("hotbar", [])
	_expect(failures, "HUD always exposes four semantic hotbar slots", hotbar.size() == 4)
	if hotbar.size() != 4:
		return
	_expect(failures, "hands slot carries no invented item identity", str(hotbar[0].get("kind", "")) == "hands" and str(hotbar[0].get("item_id", "")).is_empty())
	_expect(failures, "selected equipped item uses semantic content id", bool(hotbar[1].get("selected", false)) and str(hotbar[1].get("kind", "")) == "item" and str(hotbar[1].get("item_id", "")) == "item.tool.hud_axe")
	_expect(failures, "ordinary unoccupied equipment slots are empty not hands", str(hotbar[2].get("kind", "")) == "empty" and str(hotbar[3].get("kind", "")) == "empty")
	_expect(failures, "empty slots do not invent item identity", str(hotbar[2].get("item_id", "")).is_empty() and str(hotbar[3].get("item_id", "")).is_empty())


static func _test_malformed_equipment_is_visible_and_safe(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(failures)
	if fixture.is_empty():
		return
	var equipment = fixture["equipment"]
	var inventory = fixture["inventory"]
	var inventory_before: String = inventory.canonical_json()
	# Test-only corruption: leave an authored definition attached to an empty semantic slot.
	equipment._commit_definition(SLOT_UTILITY, fixture["axe_definition"])
	var malformed_before: String = equipment.canonical_json()
	var model: Dictionary = GameplayHudReadModel.new().sample(
		fixture["player"],
		inventory,
		equipment
	)
	_expect(failures, "malformed equipment does not masquerade as valid HUD state", bool(model.get("success", false)) and not bool(model.get("equipment_valid", true)))
	var hotbar: Array = model.get("hotbar", [])
	_expect(failures, "malformed equipment renders a four-slot invalid state", hotbar.size() == 4)
	for entry in hotbar:
		_expect(failures, "malformed equipment slot is explicitly invalid", str(entry.get("kind", "")) == "invalid" and str(entry.get("item_id", "")).is_empty())
	_expect(failures, "malformed HUD sampling does not repair or mutate gameplay state", equipment.canonical_json() == malformed_before and inventory.canonical_json() == inventory_before)


static func _test_semantic_feedback_is_presentation_only(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(failures)
	if fixture.is_empty():
		return
	var inventory = fixture["inventory"]
	var equipment = fixture["equipment"]
	var inventory_before: String = inventory.canonical_json()
	var equipment_before: String = equipment.canonical_json()
	var read_model := GameplayHudReadModel.new()
	_expect(failures, "harvest feedback derives human copy from semantic event", read_model.feedback_text({"type": "harvest.completed", "item_id": "item.resource.wood", "quantity": 3}) == "+3 Wood")
	_expect(failures, "parry feedback consumes semantic event", read_model.feedback_text({"type": "combat.parry_succeeded"}) == "Parry!")
	_expect(failures, "unknown feedback does not invent gameplay meaning", read_model.feedback_text({"type": "prototype.freeform"}).is_empty())
	_expect(failures, "feedback adaptation cannot mutate authoritative state", inventory.canonical_json() == inventory_before and equipment.canonical_json() == equipment_before)


static func _test_renderer_remains_useful_without_debug_hud(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(failures)
	if fixture.is_empty():
		return
	var inventory = fixture["inventory"]
	var equipment = fixture["equipment"]
	var inventory_before: String = inventory.canonical_json()
	var equipment_before: String = equipment.canonical_json()
	var hud := GameplayHud.new()
	var configure_failures: Array[String] = hud.configure(
		fixture["player"],
		inventory,
		equipment,
		["item.resource.wood", "item.resource.stone"]
	)
	for diagnostic in configure_failures:
		failures.append("HUD renderer configure: %s" % diagnostic)
	hud.present_feedback({"type": "harvest.pickup_collected", "item_id": "item.resource.stone", "quantity": 1})
	var rendered: Dictionary = hud.render_snapshot()
	_expect(failures, "normal HUD renderer provides health without DebugHUD", str(rendered.get("health", "")) == "Health 65 / 100")
	_expect(failures, "normal HUD renderer provides stamina without DebugHUD", str(rendered.get("stamina", "")) == "Stamina 38 / 100")
	_expect(failures, "normal HUD renderer provides four hotbar displays", rendered.get("hotbar", []).size() == 4)
	_expect(failures, "normal HUD renderer marks selected semantic item", str(rendered.get("hotbar", ["", ""])[1]).begins_with(">2") and str(rendered.get("hotbar", ["", ""])[1]).contains("Hud Axe"))
	_expect(failures, "normal HUD renderer shows semantic feedback", str(rendered.get("feedback", "")) == "+1 Stone")
	_expect(failures, "renderer never mutates inventory/equipment", inventory.canonical_json() == inventory_before and equipment.canonical_json() == equipment_before)
	hud.free()


static func _fixture(failures: Array[String]) -> Dictionary:
	var player := FakePlayer.new()
	var inventory := ItemContainerState.new().configure(8, 100.0)
	var wood = _item("item.resource.wood", 50, 0.1, ["category.item.resource.wood"], [])
	var stone = _item("item.resource.stone", 50, 0.2, ["category.item.resource.stone"], [])
	var axe = _item("item.tool.hud_axe", 1, 1.5, ["category.item.equipment.tool"], [EQUIPABLE])
	var wood_add: Dictionary = inventory.add_stack(wood, 7)
	var stone_add: Dictionary = inventory.add_stack(stone, 4)
	if not bool(wood_add.get("success", false)) or not bool(stone_add.get("success", false)):
		failures.append("HUD fixture could not populate authoritative material inventory")
		return {}

	var rules: Array = [
		EquipmentSlotRule.new().configure(SLOT_HANDS),
		EquipmentSlotRule.new().configure(SLOT_AXE, [EQUIPMENT_ROOT], [EQUIPABLE]),
		EquipmentSlotRule.new().configure(SLOT_PICKAXE, [EQUIPMENT_ROOT], [EQUIPABLE]),
		EquipmentSlotRule.new().configure(SLOT_UTILITY, [EQUIPMENT_ROOT], [EQUIPABLE]),
	]
	var equipment := EquipmentHotbarState.new().configure(rules, {
		1: SLOT_HANDS,
		2: SLOT_AXE,
		3: SLOT_PICKAXE,
		4: SLOT_UTILITY,
	})
	var equipment_source := ItemContainerState.new().configure(1, 20.0)
	var axe_add: Dictionary = equipment_source.add_instance(axe, {"durability": 81})
	if not bool(axe_add.get("success", false)):
		failures.append("HUD fixture could not create equipped item source")
		return {}
	var equipped: Dictionary = EquipmentService.new().equip_from_inventory(
		equipment,
		equipment_source,
		0,
		axe,
		SLOT_AXE
	)
	if not bool(equipped.get("success", false)):
		failures.append("HUD fixture could not equip semantic item: %s" % [equipped.get("diagnostics", [])])
		return {}
	var selected: Dictionary = equipment.select_hotbar(2)
	if not bool(selected.get("success", false)):
		failures.append("HUD fixture could not select semantic hotbar slot")
		return {}
	return {
		"player": player,
		"inventory": inventory,
		"equipment": equipment,
		"axe_definition": axe,
	}


static func _item(
	content_id: String,
	stack_limit: int,
	unit_weight: float,
	categories: Array,
	capabilities: Array
):
	var item = ItemDefinition.new()
	item.configure_item(content_id, stack_limit, unit_weight)
	item.configure_schema_declarations(categories, capabilities)
	return item


static func _material_quantities(records: Array) -> Dictionary:
	var result: Dictionary = {}
	for record in records:
		if not record is Dictionary:
			continue
		result[str(record.get("item_id", ""))] = int(record.get("quantity", 0))
	return result


static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
