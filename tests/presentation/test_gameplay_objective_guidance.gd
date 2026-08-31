extends RefCounted

const GameplayObjectiveReadModel := preload("res://presentation/ui/hud/gameplay_objective_read_model.gd")
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
	extends Node3D
	var health := 100
	var stamina := 100.0

	func get_health() -> int:
		return health

	func get_max_health() -> int:
		return 100

	func get_stamina() -> float:
		return stamina

	func get_max_stamina() -> float:
		return 100.0

	func get_action_state_name() -> String:
		return "idle"


class FakeRuntime:
	extends Node
	var in_cave := false

	func player_is_in_realized_cave() -> bool:
		return in_cave


class FakeEncounter:
	extends Node
	var pending_count := 0

	func get_pending_loot_count() -> int:
		return pending_count


class FakeGame:
	extends Node
	var route: Dictionary = {
		"surface_world_position": Vector3(100.0, 20.0, 0.0),
		"entrance_id": "sid1:must-never-render",
		"selection_fingerprint": "entrance-route-test",
	}
	var route_ready := true
	var mode: StringName = &"new"
	var underworld_runtime := FakeRuntime.new()
	var encounter_controller := FakeEncounter.new()
	var survival = null

	func _init() -> void:
		add_child(underworld_runtime)
		add_child(encounter_controller)

	func selected_entrance_route_snapshot() -> Dictionary:
		return route.duplicate(true)

	func natural_entrance_route_ready() -> bool:
		return route_ready

	func natural_entrance_route_diagnostics() -> Array[String]:
		return [] if route_ready else ["route intentionally unavailable"]

	func startup_mode() -> StringName:
		return mode


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_reconstructive_objective_chain(failures)
	_test_route_failure_is_visible_and_safe(failures)
	_test_hud_renders_guidance_without_debug_authority(failures)
	return failures


static func _test_reconstructive_objective_chain(failures: Array[String]) -> void:
	var fixture := _fixture(failures)
	if fixture.is_empty():
		return
	var game: FakeGame = fixture["game"]
	var player: FakePlayer = fixture["player"]
	var inventory = fixture["inventory"]
	var equipment = fixture["equipment"]
	var model := GameplayObjectiveReadModel.new()

	var initial_inventory: String = inventory.canonical_json()
	var initial_equipment: String = equipment.canonical_json()
	var initial_route: Dictionary = game.route.duplicate(true)
	var objective: Dictionary = model.sample(game, player, inventory, equipment)
	_expect(failures, "UX initial objective derives gather state", _objective_is(objective, "gather_surface_materials"))
	_expect(failures, "UX recipe-derived initial wood requirement is 8", int(objective.get("wood_required", 0)) == 8)
	_expect(failures, "UX recipe-derived initial stone requirement is 7", int(objective.get("stone_required", 0)) == 7)
	_expect(failures, "UX objective sampling does not mutate inventory", inventory.canonical_json() == initial_inventory)
	_expect(failures, "UX objective sampling does not mutate equipment", equipment.canonical_json() == initial_equipment)
	_expect(failures, "UX objective sampling does not mutate selected route", game.route == initial_route)

	_add_stack(failures, inventory, fixture["wood"], 8, "UX fixture wood")
	_add_stack(failures, inventory, fixture["stone"], 7, "UX fixture stone")
	_add_instance(failures, inventory, fixture["axe"], "UX inventory-only axe")
	_remove_stack(failures, inventory, "item.resource.wood", 4, "UX crafted axe wood")
	_remove_stack(failures, inventory, "item.resource.stone", 3, "UX crafted axe stone")
	objective = model.sample(game, player, inventory, equipment)
	_expect(failures, "crafted inventory-only tool does not send player back to gather", _objective_is(objective, "craft_equip_stone_tools"))

	_equip(failures, equipment, fixture["equip_source"], fixture["axe"], SLOT_AXE, "UX equip axe")
	_equip(failures, equipment, fixture["equip_source"], fixture["pickaxe"], SLOT_PICKAXE, "UX equip pickaxe")
	player.global_position = Vector3(60.0, 20.0, 0.0)
	objective = model.sample(game, player, inventory, equipment)
	_expect(failures, "accepted stone tool equipment advances to natural route", _objective_is(objective, "reach_natural_cave"))
	_expect(failures, "natural route guidance uses finite distance", is_equal_approx(float(objective.get("distance", -1.0)), 40.0))
	_expect(failures, "natural route guidance never exposes raw entrance identity", not JSON.stringify(objective).contains("sid1:must-never-render"))

	game.underworld_runtime.in_cave = true
	objective = model.sample(game, player, inventory, equipment)
	_expect(failures, "accepted cave presence advances to iron mining", _objective_is(objective, "mine_iron"))
	_expect(failures, "iron objective uses authored recipe requirement", int(objective.get("iron_required", 0)) == 4)

	_add_stack(failures, inventory, fixture["iron"], 4, "UX fixture iron")
	_add_instance(failures, inventory, fixture["sword"], "UX inventory-only sword")
	_remove_stack(failures, inventory, "item.resource.iron_chunk", 4, "UX crafted sword iron")
	objective = model.sample(game, player, inventory, equipment)
	_expect(failures, "crafted inventory-only sword does not send player back to mine", _objective_is(objective, "craft_equip_iron_sword") and bool(objective.get("sword_owned", false)))

	_equip(failures, equipment, fixture["equip_source"], fixture["sword"], SLOT_UTILITY, "UX equip sword")
	objective = model.sample(game, player, inventory, equipment)
	_expect(failures, "equipped production sword advances to Burrower defeat", _objective_is(objective, "defeat_burrower"))

	game.encounter_controller.pending_count = 1
	objective = model.sample(game, player, inventory, equipment)
	_expect(failures, "enemy reward pending does not count as collected", _objective_is(objective, "collect_burrower_reward"))

	game.encounter_controller.pending_count = 0
	_add_stack(failures, inventory, fixture["chitin"], 1, "UX fixture collected reward")
	objective = model.sample(game, player, inventory, equipment)
	_expect(failures, "accepted reward inventory advances to Save and Continue", _objective_is(objective, "save_quit_continue"))
	_expect(failures, "failed or not-yet-completed Save cannot mark route complete", not bool(objective.get("complete", true)))

	game.mode = &"continue"
	objective = model.sample(game, player, inventory, equipment)
	_expect(failures, "Continue reconstructs complete state without UX flag", _objective_is(objective, "m3_route_complete") and bool(objective.get("complete", false)))
	_cleanup_fixture(fixture)


static func _test_route_failure_is_visible_and_safe(failures: Array[String]) -> void:
	var fixture := _fixture(failures)
	if fixture.is_empty():
		return
	var game: FakeGame = fixture["game"]
	var inventory = fixture["inventory"]
	var equipment = fixture["equipment"]
	_add_stack(failures, inventory, fixture["wood"], 8, "UX failure fixture wood")
	_add_stack(failures, inventory, fixture["stone"], 7, "UX failure fixture stone")
	_equip(failures, equipment, fixture["equip_source"], fixture["axe"], SLOT_AXE, "UX failure equip axe")
	_equip(failures, equipment, fixture["equip_source"], fixture["pickaxe"], SLOT_PICKAXE, "UX failure equip pickaxe")
	var inventory_before: String = inventory.canonical_json()
	var equipment_before: String = equipment.canonical_json()
	game.route_ready = false
	var objective: Dictionary = GameplayObjectiveReadModel.new().sample(
		game,
		fixture["player"],
		inventory,
		equipment
	)
	_expect(failures, "unready route fails visibly instead of inventing guidance", not bool(objective.get("success", true)) and objective.get("diagnostics", []).size() > 0)
	_expect(failures, "unready route sampling cannot alter inventory", inventory.canonical_json() == inventory_before)
	_expect(failures, "unready route sampling cannot alter equipment", equipment.canonical_json() == equipment_before)

	game.route_ready = true
	game.route["surface_world_position"] = Vector3(INF, 0.0, 0.0)
	objective = GameplayObjectiveReadModel.new().sample(game, fixture["player"], inventory, equipment)
	_expect(failures, "malformed route target fails closed", not bool(objective.get("success", true)))
	_cleanup_fixture(fixture)


static func _test_hud_renders_guidance_without_debug_authority(failures: Array[String]) -> void:
	var fixture := _fixture(failures)
	if fixture.is_empty():
		return
	var game: FakeGame = fixture["game"]
	var hud := GameplayHud.new()
	game.add_child(hud)
	var configure_failures: Array[String] = hud.configure(
		fixture["player"],
		fixture["inventory"],
		fixture["equipment"]
	)
	for diagnostic in configure_failures:
		failures.append("UX HUD configure: %s" % diagnostic)
	var snapshot: Dictionary = hud.render_snapshot()
	_expect(failures, "GameplayHUD renders current objective without DebugHUD", str(snapshot.get("objective", "")).begins_with("Objective: Gather resources"))
	_expect(failures, "GameplayHUD objective snapshot exposes semantic objective id", str(snapshot.get("objective_model", {}).get("objective_id", "")) == "gather_surface_materials")
	_expect(failures, "GameplayHUD objective controls remain mouse passthrough", hud.controls_are_mouse_passthrough())
	_cleanup_fixture(fixture)


static func _fixture(failures: Array[String]) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		failures.append("UX fixture requires live SceneTree root")
		return {}
	var game := FakeGame.new()
	tree.root.add_child(game)
	var player := FakePlayer.new()
	game.add_child(player)
	player.global_position = Vector3.ZERO
	var inventory := ItemContainerState.new().configure(16, 200.0)
	var equipment := EquipmentHotbarState.new().configure([
		EquipmentSlotRule.new().configure(SLOT_HANDS),
		EquipmentSlotRule.new().configure(SLOT_AXE, [EQUIPMENT_ROOT], [EQUIPABLE]),
		EquipmentSlotRule.new().configure(SLOT_PICKAXE, [EQUIPMENT_ROOT], [EQUIPABLE]),
		EquipmentSlotRule.new().configure(SLOT_UTILITY, [EQUIPMENT_ROOT], [EQUIPABLE]),
	], {
		1: SLOT_HANDS,
		2: SLOT_AXE,
		3: SLOT_PICKAXE,
		4: SLOT_UTILITY,
	})
	var equip_source := ItemContainerState.new().configure(4, 100.0)
	var fixture: Dictionary = {
		"game": game,
		"player": player,
		"inventory": inventory,
		"equipment": equipment,
		"equip_source": equip_source,
		"wood": _item("item.resource.wood", 50, 0.1, ["category.item.resource.wood"], []),
		"stone": _item("item.resource.stone", 50, 0.2, ["category.item.resource.stone"], []),
		"iron": _item("item.resource.iron_chunk", 50, 0.5, ["category.item.resource.iron"], []),
		"chitin": _item("item.resource.burrower_chitin", 50, 0.2, ["category.item.resource.creature"], []),
		"axe": _item("item.tool.stone_axe", 1, 1.5, ["category.item.equipment.tool"], [EQUIPABLE]),
		"pickaxe": _item("item.tool.stone_pickaxe", 1, 1.7, ["category.item.equipment.tool"], [EQUIPABLE]),
		"sword": _item("item.weapon.iron_sword", 1, 3.0, ["category.item.equipment.weapon.melee.sword"], [EQUIPABLE]),
	}
	for failure in inventory.validate_container():
		failures.append("UX fixture inventory: %s" % failure)
	for failure in equipment.validate_state():
		failures.append("UX fixture equipment: %s" % failure)
	return fixture


static func _cleanup_fixture(fixture: Dictionary) -> void:
	var game = fixture.get("game", null)
	if game != null and is_instance_valid(game):
		game.free()


static func _equip(
	failures: Array[String],
	equipment,
	source,
	definition,
	slot_key: String,
	label: String
) -> void:
	var add_result: Dictionary = source.add_instance(definition, {})
	if not bool(add_result.get("success", false)):
		failures.append("%s source add failed: %s" % [label, add_result.get("diagnostics", [])])
		return
	var slot_index: int = int(add_result.get("slot", 0))
	var equip_result: Dictionary = EquipmentService.new().equip_from_inventory(
		equipment,
		source,
		slot_index,
		definition,
		slot_key
	)
	if not bool(equip_result.get("success", false)):
		failures.append("%s failed: %s" % [label, equip_result.get("diagnostics", [])])


static func _add_stack(
	failures: Array[String],
	inventory,
	definition,
	quantity: int,
	label: String
) -> void:
	var result: Dictionary = inventory.add_stack(definition, quantity)
	if not bool(result.get("success", false)):
		failures.append("%s failed: %s" % [label, result.get("diagnostics", [])])


static func _remove_stack(
	failures: Array[String],
	inventory,
	item_id: String,
	quantity: int,
	label: String
) -> void:
	var result: Dictionary = inventory.remove_stack(item_id, quantity)
	if not bool(result.get("success", false)):
		failures.append("%s failed: %s" % [label, result.get("diagnostics", [])])


static func _add_instance(
	failures: Array[String],
	inventory,
	definition,
	label: String
) -> void:
	var result: Dictionary = inventory.add_instance(definition, {})
	if not bool(result.get("success", false)):
		failures.append("%s failed: %s" % [label, result.get("diagnostics", [])])


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


static func _objective_is(objective: Dictionary, objective_id: String) -> bool:
	return bool(objective.get("success", false)) and str(objective.get("objective_id", "")) == objective_id


static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
