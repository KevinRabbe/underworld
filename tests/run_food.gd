extends SceneTree

const FoodConsumptionTests := preload("res://tests/survival/test_food_consumption.gd")


func _init() -> void:
	var failures: Array[String] = FoodConsumptionTests.run(self)
	if failures.is_empty():
		print("[FOOD SURVIVAL VALIDATION] PASS")
		quit(0)
		return
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
