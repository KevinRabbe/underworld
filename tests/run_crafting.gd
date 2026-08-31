extends SceneTree

const CraftingContractTests := preload("res://tests/crafting/test_crafting_contract.gd")
const ProgressionCraftEquipTests := preload("res://tests/crafting/test_progression_craft_equip.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(CraftingContractTests.run())
	failures.append_array(ProgressionCraftEquipTests.run())
	if failures.is_empty():
		print("[CRAFTING VALIDATION] PASS")
		print("  authored recipe / CONTENT-005 / context / INV-002 atomic crafting / semantic progression equip contracts passed")
		quit(0)
		return

	printerr("[CRAFTING VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
