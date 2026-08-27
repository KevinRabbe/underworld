extends RefCounted

const StaminaScript := preload("res://player/stamina_component.gd")
const ActionControllerScript := preload("res://player/player_action_controller.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_stamina(failures)
	_test_dodge_contract(failures)
	_test_parry_contract(failures)
	_test_block_contract(failures)
	_test_tool_action_contract(failures)
	return failures


static func _test_stamina(failures: Array[String]) -> void:
	var stamina = StaminaScript.new(100.0, 0.75, 20.0)
	_expect_close(failures, "stamina starts full", stamina.current_stamina, 100.0)
	_expect_true(failures, "stamina can spend 25", stamina.spend(25.0))
	_expect_close(failures, "stamina spends exact amount", stamina.current_stamina, 75.0)
	stamina.tick(0.50)
	_expect_close(failures, "stamina respects regen delay", stamina.current_stamina, 75.0)
	stamina.tick(0.30)
	_expect_close(failures, "regen does not leak through lock-clearing tick", stamina.current_stamina, 75.0)
	stamina.tick(0.50)
	_expect_close(failures, "stamina regens at configured rate", stamina.current_stamina, 85.0)
	stamina.reset()
	_expect_close(failures, "stamina reset restores full", stamina.current_stamina, 100.0)


static func _test_dodge_contract(failures: Array[String]) -> void:
	var stamina = StaminaScript.new()
	var actions = ActionControllerScript.new(stamina)
	_expect_true(failures, "zero-direction dodge is rejected", not actions.try_start_dodge(Vector3.ZERO))
	_expect_true(failures, "directional dodge starts", actions.try_start_dodge(Vector3(1.0, 0.0, 0.0)))
	_expect_true(failures, "dodge enters dodge state", actions.is_dodging())
	_expect_close(failures, "dodge spends stamina", stamina.current_stamina, 75.0)
	_expect_true(failures, "dodge has startup before iframes", not actions.is_dodge_iframe_active())
	_expect_true(failures, "cannot parry during dodge", not actions.try_start_parry())
	_expect_true(failures, "cannot block during dodge", not actions.try_start_block())
	_expect_true(failures, "cannot use tool during dodge", not actions.try_start_tool_action(0.38))
	actions.tick(0.10)
	_expect_true(failures, "dodge iframes become active", actions.is_dodge_iframe_active())
	_expect_true(failures, "dodge curve produces movement", actions.get_dodge_speed() > 0.0)
	actions.tick(0.21)
	_expect_true(failures, "dodge iframes end before full recovery", not actions.is_dodge_iframe_active())
	_expect_true(failures, "dodge still committed after iframe window", actions.is_dodging())
	actions.tick(0.20)
	_expect_true(failures, "dodge returns to free", actions.is_free())


static func _test_parry_contract(failures: Array[String]) -> void:
	var stamina = StaminaScript.new()
	var actions = ActionControllerScript.new(stamina)
	_expect_true(failures, "parry starts", actions.try_start_parry())
	_expect_close(failures, "parry spends stamina", stamina.current_stamina, 85.0)
	_expect_true(failures, "parry startup is not active", not actions.is_parry_active())
	_expect_true(failures, "cannot block during parry", not actions.try_start_block())
	_expect_true(failures, "cannot use tool during parry", not actions.try_start_tool_action(0.38))
	actions.tick(0.07)
	_expect_true(failures, "parry active window opens", actions.is_parry_active())
	actions.tick(0.12)
	_expect_true(failures, "parry active window closes", not actions.is_parry_active())
	_expect_true(failures, "parry recovery remains committed", actions.is_parrying())
	actions.tick(0.31)
	_expect_true(failures, "parry returns to free", actions.is_free())

	stamina.current_stamina = 10.0
	_expect_true(failures, "parry rejects insufficient stamina", not actions.try_start_parry())


static func _test_block_contract(failures: Array[String]) -> void:
	var stamina = StaminaScript.new()
	var actions = ActionControllerScript.new(stamina)
	_expect_true(failures, "block starts", actions.try_start_block())
	_expect_true(failures, "block enters held state", actions.is_blocking())
	_expect_close(failures, "raising guard has no upfront cost", stamina.current_stamina, 100.0)
	_expect_true(failures, "cannot dodge while blocking", not actions.try_start_dodge(Vector3.RIGHT))
	_expect_true(failures, "cannot parry while blocking", not actions.try_start_parry())
	_expect_true(failures, "cannot use tool while blocking", not actions.try_start_tool_action(0.38))
	_expect_true(failures, "block absorbs affordable impact", actions.try_absorb_block(17.5))
	_expect_close(failures, "block spends impact stamina", stamina.current_stamina, 82.5)
	actions.stop_block()
	_expect_true(failures, "releasing block returns to free", actions.is_free())

	stamina.current_stamina = 4.0
	_expect_true(failures, "low-stamina guard can still be raised", actions.try_start_block())
	_expect_true(failures, "unaffordable impact breaks guard", not actions.try_absorb_block(10.0))
	_expect_true(failures, "guard break returns action controller to free", actions.is_free())
	_expect_close(failures, "guard break drains remaining stamina", stamina.current_stamina, 0.0)
	_expect_true(failures, "zero-stamina guard cannot be raised", not actions.try_start_block())


static func _test_tool_action_contract(failures: Array[String]) -> void:
	var stamina = StaminaScript.new()
	var actions = ActionControllerScript.new(stamina)
	_expect_true(failures, "tool action starts", actions.try_start_tool_action(0.38))
	_expect_true(failures, "tool action enters committed state", actions.is_using_tool())
	_expect_close(failures, "tool action has no automatic stamina cost", stamina.current_stamina, 100.0)
	_expect_true(failures, "cannot dodge during tool action", not actions.try_start_dodge(Vector3.RIGHT))
	_expect_true(failures, "cannot parry during tool action", not actions.try_start_parry())
	_expect_true(failures, "cannot block during tool action", not actions.try_start_block())
	_expect_true(failures, "cannot overlap another tool action", not actions.try_start_tool_action(0.20))
	actions.tick(0.20)
	_expect_true(failures, "tool action remains committed before duration", actions.is_using_tool())
	actions.tick(0.18)
	_expect_true(failures, "tool action returns to free at duration", actions.is_free())


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_close(
	failures: Array[String],
	label: String,
	actual: float,
	expected: float
) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s — expected %.4f, got %.4f" % [label, expected, actual])
