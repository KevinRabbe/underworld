extends RefCounted

const SurvivalScript := preload("res://gameplay/survival/prototype_survival_controller.gd")
const BoarEncounterControllerScript := preload("res://gameplay/hunting/boar_encounter_controller.gd")


class FakeSettings:
	extends RefCounted
	var pickup_collect_radius := 1.5
	var pickup_collect_interval := 0.15
	var tree_hits_with_axe := 3
	var rock_hits_with_pickaxe := 4
	var tree_wood_yield := 4
	var rock_stone_yield := 3
	var stone_axe_wood_cost := 4
	var stone_axe_stone_cost := 3
	var stone_pickaxe_wood_cost := 3
	var stone_pickaxe_stone_cost := 4


static func run() -> Array[String]:
	var failures: Array[String] = []
	var survival = SurvivalScript.new()
	survival.configure(null, FakeSettings.new(), 99001)
	var inventory = survival.get_inventory_state()
	var wood = survival.get_item_definition("item.resource.wood")
	var stone = survival.get_item_definition("item.resource.stone")
	if wood == null or stone == null:
		return ["skinning test could not load basic material definitions"]
	inventory.add_stack(wood, 2)
	inventory.add_stack(stone, 1)
	survival.request_craft("skinning_knife")
	if not survival.has_tool("skinning_knife"):
		failures.append("normal craft path did not create the Skinning Knife")
	if survival.get_selected_hotbar_slot() != 4:
		failures.append("crafted Skinning Knife was not selected on utility hotbar")
	var service = survival.get_skinning_service()
	var first: Dictionary = service.skin_carcass("carcass.boar_1", false)
	if not bool(first.get("success", false)):
		failures.append("knife could not skin a live carcass: %s" % first.get("diagnostics", []))
	if inventory.quantity_of("item.resource.raw_meat") != 2:
		failures.append("skinning did not add exactly two raw meat")
	if inventory.quantity_of("item.resource.boar_hide") != 1:
		failures.append("skinning did not add exactly one boar hide")
	if int(service.progression_snapshot().get("skinning", 0)) != 1:
		failures.append("skinning did not advance profession progression")
	var before: String = inventory.canonical_json()
	var repeat: Dictionary = service.skin_carcass("carcass.boar_1", true)
	if bool(repeat.get("success", false)):
		failures.append("consumed carcass could be skinned twice")
	if inventory.canonical_json() != before:
		failures.append("replayed skinning mutated inventory")
	survival.free()
	_run_boar_death_contract(failures)
	return failures


static func _run_boar_death_contract(failures: Array[String]) -> void:
	var controller = BoarEncounterControllerScript.new()
	var world := Node3D.new()
	var player := Node3D.new()
	controller.configure(world, player, FakeSettings.new())
	var boar = controller.active_boar
	if boar == null or not is_instance_valid(boar):
		failures.append("boar encounter did not spawn a boar for death contract")
		controller.free()
		world.free()
		player.free()
		return
	var expected_position: Vector3 = boar.global_position
	boar.apply_damage(999, expected_position + Vector3.RIGHT)
	var carcass = controller.get_carcass("carcass.boar_1")
	if carcass == null or not is_instance_valid(carcass):
		failures.append("boar death did not create a carcass")
	elif not carcass.global_position.is_equal_approx(expected_position):
		failures.append("boar carcass did not preserve the death position")
	controller.free()
	world.free()
	player.free()
