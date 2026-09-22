extends RefCounted

const Player := preload("res://gameplay/player/player.gd")
const Survival := preload("res://gameplay/survival/integrated_survival_controller.gd")
const GameplayStateCodec := preload("res://gameplay/persistence/gameplay_state_codec.gd")
const FoodDefinition := preload("res://gameplay/items/definitions/food_item_definition.gd")


static func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_test_input_consumes_food_and_persists_state(tree, failures)
	_test_starvation_is_authoritative(tree, failures)
	return failures


static func _test_input_consumes_food_and_persists_state(tree: SceneTree, failures: Array[String]) -> void:
	var survival = Survival.new()
	survival.configure_integrated(null, null, 991701)
	var player = Player.new()
	player.food = 75.0
	survival.player = player
	var food = survival.get_item_definition("item.food.berries")
	if food == null or not food is FoodDefinition:
		failures.append("food catalog does not resolve authored berry definition")
		_survival_cleanup(survival, player)
		return
	var added: Dictionary = survival.get_inventory_state().add_stack(food, 2)
	if not bool(added.get("success", false)):
		failures.append("berry stack could not enter canonical inventory: %s" % added.get("diagnostics", []))
		_survival_cleanup(survival, player)
		return
	player._ensure_default_input_actions()
	player.food_requested.connect(survival.consume_food)
	var berries_before: int = survival.get_inventory_state().quantity_of("item.food.berries")
	var input := InputEventAction.new()
	input.action = &"eat_food"
	input.pressed = true
	input.strength = 1.0
	player._unhandled_input(input)
	if not is_equal_approx(player.get_food(), 100.0):
		failures.append("normal Z input did not restore Player food from berry nutrition")
	if survival.get_inventory_state().quantity_of("item.food.berries") != berries_before - 1:
		failures.append("food consumption did not canonically remove exactly one berry")
	var encoded: Dictionary = GameplayStateCodec.encode_player_vitals(81, 35.0, player.get_food())
	var decoded: Dictionary = GameplayStateCodec.decode_player_vitals(encoded.get("snapshot", {}))
	if not bool(decoded.get("success", false)) or not is_equal_approx(
		float(decoded.get("state", {}).get("current_food", -1.0)), player.get_food()
	):
		failures.append("food state did not survive player-vitals save/continue codec")
	_survival_cleanup(survival, player)


static func _test_starvation_is_authoritative(tree: SceneTree, failures: Array[String]) -> void:
	var player = Player.new()
	player.food = 0.0
	player.health = 100
	player._tick_food(8.0)
	if player.get_health() != 99:
		failures.append("empty food did not apply authoritative starvation damage")
	player.free()


static func _survival_cleanup(survival, player) -> void:
	survival.free()
	player.free()
