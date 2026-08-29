extends RefCounted

const SurvivalScript := preload("res://gameplay/survival/prototype_survival_controller.gd")
const ItemDefinition := preload("res://gameplay/items/definitions/item_definition.gd")
const EquipmentService := preload("res://gameplay/items/equipment/equipment_service.gd")

const WOOD_ID := "item.resource.wood"
const STONE_ID := "item.resource.stone"
const AXE_ID := "item.tool.stone_axe"
const PICKAXE_ID := "item.tool.stone_pickaxe"
const SLOT_AXE := "equipment_slot.hotbar.axe"
const SLOT_PICKAXE := "equipment_slot.hotbar.pickaxe"


class FakeSettings:
	extends RefCounted
	var pickup_collect_radius: float = 1.5
	var pickup_collect_interval: float = 0.15
	var tree_hits_with_axe: int = 3
	var rock_hits_with_pickaxe: int = 4
	var tree_wood_yield: int = 4
	var rock_stone_yield: int = 3
	var stone_axe_wood_cost: int = 4
	var stone_axe_stone_cost: int = 3
	var stone_pickaxe_wood_cost: int = 3
	var stone_pickaxe_stone_cost: int = 4


class FakeWorld:
	extends RefCounted
	var destroyed: Dictionary = {}
	var pickup_candidates: Array = []
	var destroy_calls: int = 0
	var fail_next_destroy: bool = false

	func load_destroyed_object_ids(object_ids: Array) -> void:
		destroyed.clear()
		for object_id_variant in object_ids:
			destroyed[str(object_id_variant)] = true

	func get_destroyed_object_ids() -> Array:
		var result: Array = destroyed.keys()
		result.sort()
		return result

	func get_destroyed_object_count() -> int:
		return destroyed.size()

	func is_world_object_destroyed(object_id: String) -> bool:
		return destroyed.has(object_id)

	func find_nearby_pickups(_position: Vector3, _radius: float) -> Array:
		var result: Array = []
		for candidate_variant in pickup_candidates:
			var candidate: Dictionary = candidate_variant
			if not destroyed.has(str(candidate.get("object_id", ""))):
				result.append(candidate.duplicate(true))
		result.sort_custom(func(a, b): return str(a.get("object_id", "")) < str(b.get("object_id", "")))
		return result

	func destroy_world_object(
		object_id: String,
		_object_type: String,
		_object_index: int,
		_object_chunk: Vector2i
	) -> bool:
		if fail_next_destroy:
			fail_next_destroy = false
			return false
		if object_id.is_empty() or destroyed.has(object_id):
			return false
		destroyed[object_id] = true
		destroy_calls += 1
		return true


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_loose_pickups_commit_inventory_before_world_consumption(failures)
	_test_full_inventory_preserves_loose_pickup(failures)
	_test_wrong_tool_cannot_advance_or_deplete(failures)
	_test_tree_and_rock_preserve_hit_and_yield_tuning(failures)
	_test_final_capacity_failure_preserves_world_and_progress(failures)
	_test_world_depletion_failure_rolls_back_inventory(failures)
	_test_legacy_mirrors_are_not_authority(failures)
	return failures


static func _test_loose_pickups_commit_inventory_before_world_consumption(failures: Array[String]) -> void:
	var seed := 820001
	var world = FakeWorld.new()
	world.pickup_candidates = [
		{"object_id": "0:0:branch:1", "object_type": "branch", "index": 1, "object_chunk": Vector2i.ZERO},
		{"object_id": "0:0:loose_stone:2", "object_type": "loose_stone", "index": 2, "object_chunk": Vector2i.ZERO},
	]
	var survival = _new_survival(world, seed)
	var result: Dictionary = survival.collect_nearby_pickups_at(Vector3.ZERO)
	_expect_true(failures, "loose pickup transaction succeeded", bool(result.get("success", false)))
	_expect_equal(failures, "branch entered semantic inventory", survival.get_resource_counts().x, 1)
	_expect_equal(failures, "loose stone entered semantic inventory", survival.get_resource_counts().y, 1)
	_expect_equal(failures, "pickup StableIds consumed after transfer", world.destroy_calls, 2)
	var event_text: String = str(result.get("events", []))
	_expect_true(failures, "pickup events expose semantic item ids", event_text.contains(WOOD_ID) and event_text.contains(STONE_ID))
	_expect_true(failures, "pickup events do not leak resource paths", not event_text.contains("res://") and not event_text.contains("ui_slot"))

	var inventory_after: String = survival.get_inventory_state().canonical_json()
	var repeat: Dictionary = survival.collect_nearby_pickups_at(Vector3.ZERO)
	_expect_equal(failures, "repeated pickup scan consumes nothing", repeat.get("events", []).size(), 0)
	_expect_equal(failures, "repeated pickup scan preserves inventory", survival.get_inventory_state().canonical_json(), inventory_after)
	_expect_equal(failures, "repeated pickup scan preserves StableId count", world.destroy_calls, 2)
	_cleanup(survival, seed)


static func _test_full_inventory_preserves_loose_pickup(failures: Array[String]) -> void:
	var seed := 820002
	var world = FakeWorld.new()
	world.pickup_candidates = [
		{"object_id": "1:0:branch:0", "object_type": "branch", "index": 0, "object_chunk": Vector2i(1, 0)},
	]
	var survival = _new_survival(world, seed, 1)
	var blocker = ItemDefinition.new()
	blocker.configure_item("item.resource.inventory_blocker", 1, 0.0, 1)
	blocker.configure_schema_declarations(["category.item.resource"], [])
	var prepared: Dictionary = survival.get_inventory_state().add_instance(blocker)
	_expect_true(failures, "capacity test fills destination inventory", bool(prepared.get("success", false)))
	var inventory_before: String = survival.get_inventory_state().canonical_json()
	var result: Dictionary = survival.collect_nearby_pickups_at(Vector3.ZERO)
	_expect_true(failures, "full inventory rejects loose pickup", not bool(result.get("success", false)))
	_expect_equal(failures, "capacity rejection preserves inventory", survival.get_inventory_state().canonical_json(), inventory_before)
	_expect_true(failures, "capacity rejection preserves loose pickup StableId", not world.is_world_object_destroyed("1:0:branch:0"))
	_expect_equal(failures, "capacity rejection performs no world mutation", world.destroy_calls, 0)
	_cleanup(survival, seed)


static func _test_wrong_tool_cannot_advance_or_deplete(failures: Array[String]) -> void:
	var seed := 820003
	var world = FakeWorld.new()
	var survival = _new_survival(world, seed)
	var inventory_before: String = survival.get_inventory_state().canonical_json()
	var result: Dictionary = survival.harvest_world_object("0:0:tree:3", "tree", 3, Vector2i.ZERO)
	_expect_true(failures, "tree rejects hands through EQUIP semantics", not bool(result.get("success", false)))
	_expect_equal(failures, "wrong tool does not advance hit progress", survival.get_object_hit_progress("0:0:tree:3"), 0)
	_expect_equal(failures, "wrong tool does not mutate inventory", survival.get_inventory_state().canonical_json(), inventory_before)
	_expect_true(failures, "wrong tool does not deplete tree", not world.is_world_object_destroyed("0:0:tree:3"))
	_cleanup(survival, seed)


static func _test_tree_and_rock_preserve_hit_and_yield_tuning(failures: Array[String]) -> void:
	var tree_seed := 820004
	var tree_world = FakeWorld.new()
	var tree_survival = _new_survival(tree_world, tree_seed)
	_seed_stack(tree_survival, WOOD_ID, 4)
	_seed_stack(tree_survival, STONE_ID, 3)
	tree_survival.request_craft("stone_axe")
	_expect_true(failures, "legacy craft bridge creates semantic axe ownership", tree_survival.has_tool("stone_axe"))
	_expect_equal(failures, "axe is selected through EQUIP hotbar", tree_survival.get_selected_hotbar_slot(), 2)
	var tree_id := "0:0:tree:4"
	for hit in range(1, 3):
		var partial: Dictionary = tree_survival.harvest_world_object(tree_id, "tree", 4, Vector2i.ZERO)
		_expect_true(failures, "tree partial hit succeeds", bool(partial.get("success", false)))
		_expect_true(failures, "tree partial hit does not complete", not bool(partial.get("completed", false)))
		_expect_equal(failures, "tree partial hit count preserved", tree_survival.get_object_hit_progress(tree_id), hit)
		_expect_true(failures, "tree partial hit does not deplete world", not tree_world.is_world_object_destroyed(tree_id))
	var final_tree: Dictionary = tree_survival.harvest_world_object(tree_id, "tree", 4, Vector2i.ZERO)
	_expect_true(failures, "third axe hit completes tree", bool(final_tree.get("completed", false)))
	_expect_equal(failures, "tree yield remains four wood", tree_survival.get_resource_counts().x, 4)
	_expect_equal(failures, "tree depletes exactly once", tree_world.destroy_calls, 1)
	var tree_inventory_after: String = tree_survival.get_inventory_state().canonical_json()
	var repeated_tree: Dictionary = tree_survival.harvest_world_object(tree_id, "tree", 4, Vector2i.ZERO)
	_expect_true(failures, "repeated final tree callback fails closed", not bool(repeated_tree.get("success", false)))
	_expect_equal(failures, "repeated final tree callback cannot duplicate yield", tree_survival.get_inventory_state().canonical_json(), tree_inventory_after)
	_expect_equal(failures, "repeated final tree callback cannot duplicate world mutation", tree_world.destroy_calls, 1)
	_cleanup(tree_survival, tree_seed)

	var rock_seed := 820005
	var rock_world = FakeWorld.new()
	var rock_survival = _new_survival(rock_world, rock_seed)
	_seed_stack(rock_survival, WOOD_ID, 3)
	_seed_stack(rock_survival, STONE_ID, 4)
	rock_survival.request_craft("stone_pickaxe")
	_expect_true(failures, "legacy craft bridge creates semantic pickaxe ownership", rock_survival.has_tool("stone_pickaxe"))
	_expect_equal(failures, "pickaxe is selected through EQUIP hotbar", rock_survival.get_selected_hotbar_slot(), 3)
	var rock_id := "0:0:rock:2"
	for hit in range(1, 4):
		var partial: Dictionary = rock_survival.harvest_world_object(rock_id, "rock", 2, Vector2i.ZERO)
		_expect_true(failures, "rock partial hit succeeds", bool(partial.get("success", false)))
		_expect_equal(failures, "rock partial hit count preserved", rock_survival.get_object_hit_progress(rock_id), hit)
	var final_rock: Dictionary = rock_survival.harvest_world_object(rock_id, "rock", 2, Vector2i.ZERO)
	_expect_true(failures, "fourth pickaxe hit completes rock", bool(final_rock.get("completed", false)))
	_expect_equal(failures, "rock yield remains three stone", rock_survival.get_resource_counts().y, 3)
	_expect_equal(failures, "rock depletes exactly once", rock_world.destroy_calls, 1)
	_cleanup(rock_survival, rock_seed)


static func _test_final_capacity_failure_preserves_world_and_progress(failures: Array[String]) -> void:
	var seed := 820006
	var world = FakeWorld.new()
	var survival = _new_survival(world, seed, 1)
	_equip_definition(failures, survival, AXE_ID, SLOT_AXE, 2)
	var blocker = ItemDefinition.new()
	blocker.configure_item("item.resource.final_blocker", 1, 0.0, 1)
	blocker.configure_schema_declarations(["category.item.resource"], [])
	var prepared: Dictionary = survival.get_inventory_state().add_instance(blocker)
	_expect_true(failures, "final capacity test fills inventory after equipping axe", bool(prepared.get("success", false)))
	var tree_id := "2:0:tree:1"
	survival.harvest_world_object(tree_id, "tree", 1, Vector2i(2, 0))
	survival.harvest_world_object(tree_id, "tree", 1, Vector2i(2, 0))
	var before: String = survival.get_inventory_state().canonical_json()
	var final_attempt: Dictionary = survival.harvest_world_object(tree_id, "tree", 1, Vector2i(2, 0))
	_expect_true(failures, "final hit fails when inventory cannot accept yield", not bool(final_attempt.get("success", false)))
	_expect_equal(failures, "failed final hit preserves pre-final progress", survival.get_object_hit_progress(tree_id), 2)
	_expect_equal(failures, "failed final hit preserves inventory", survival.get_inventory_state().canonical_json(), before)
	_expect_true(failures, "failed final hit leaves tree undepleted", not world.is_world_object_destroyed(tree_id))
	_cleanup(survival, seed)


static func _test_world_depletion_failure_rolls_back_inventory(failures: Array[String]) -> void:
	var seed := 820007
	var world = FakeWorld.new()
	var survival = _new_survival(world, seed)
	_equip_definition(failures, survival, AXE_ID, SLOT_AXE, 2)
	var tree_id := "3:0:tree:0"
	survival.harvest_world_object(tree_id, "tree", 0, Vector2i(3, 0))
	survival.harvest_world_object(tree_id, "tree", 0, Vector2i(3, 0))
	var inventory_before: String = survival.get_inventory_state().canonical_json()
	world.fail_next_destroy = true
	var failed: Dictionary = survival.harvest_world_object(tree_id, "tree", 0, Vector2i(3, 0))
	_expect_true(failures, "world mutation failure rejects final harvest", not bool(failed.get("success", false)))
	_expect_equal(failures, "world mutation failure rolls inventory back exactly", survival.get_inventory_state().canonical_json(), inventory_before)
	_expect_equal(failures, "world mutation failure preserves pre-final progress", survival.get_object_hit_progress(tree_id), 2)
	_expect_true(failures, "world mutation failure leaves StableId live", not world.is_world_object_destroyed(tree_id))
	_cleanup(survival, seed)


static func _test_legacy_mirrors_are_not_authority(failures: Array[String]) -> void:
	var seed := 820008
	var world = FakeWorld.new()
	var survival = _new_survival(world, seed)
	survival.gathered_wood = 999
	survival.gathered_stone = 999
	survival.has_stone_axe = true
	survival.has_stone_pickaxe = true
	survival.selected_hotbar_slot = 2
	survival.equipped_tool = "stone_axe"
	_expect_equal(failures, "legacy wood mirror cannot create inventory", survival.get_resource_counts().x, 0)
	_expect_equal(failures, "legacy stone mirror cannot create inventory", survival.get_resource_counts().y, 0)
	_expect_true(failures, "legacy axe boolean cannot create semantic ownership", not survival.has_tool("stone_axe"))
	_expect_true(failures, "legacy pickaxe boolean cannot create semantic ownership", not survival.has_tool("stone_pickaxe"))
	_expect_equal(failures, "legacy equipped string cannot select harvest tool", survival.get_equipped_tool(), "hands")
	_cleanup(survival, seed)


static func _new_survival(
	world,
	seed: int,
	slots: int = 16,
	max_weight: float = -1.0
):
	_cleanup_test_save(seed)
	var survival = SurvivalScript.new()
	survival.configure(world, FakeSettings.new(), seed, slots, max_weight)
	return survival


static func _seed_stack(survival, item_id: String, quantity: int) -> void:
	var definition = survival.get_item_definition(item_id)
	assert(definition != null)
	var result: Dictionary = survival.get_inventory_state().add_stack(definition, quantity)
	assert(bool(result.get("success", false)))


static func _equip_definition(
	failures: Array[String],
	survival,
	item_id: String,
	target_slot: String,
	hotbar: int
) -> void:
	var definition = survival.get_item_definition(item_id)
	var inventory = survival.get_inventory_state()
	var added: Dictionary = inventory.add_instance(definition)
	_expect_true(failures, "equipment setup adds semantic tool instance", bool(added.get("success", false)))
	if not bool(added.get("success", false)):
		return
	var source_slot: int = int(added.get("slot", -1))
	var equipped: Dictionary = EquipmentService.new().equip_from_inventory(
		survival.get_equipment_state(),
		inventory,
		source_slot,
		definition,
		target_slot
	)
	_expect_true(failures, "equipment setup uses accepted EQUIP service", bool(equipped.get("success", false)))
	if bool(equipped.get("success", false)):
		survival.select_hotbar_slot(hotbar)


static func _cleanup(survival, seed: int) -> void:
	_cleanup_test_save(seed)
	survival.free()


static func _cleanup_test_save(seed: int) -> void:
	var path: String = "user://underworld_seed_%d.json" % seed
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s: expected=%s actual=%s" % [label, expected, actual])
