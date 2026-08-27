extends SceneTree

const MannequinTests := preload("res://tests/character/test_prototype_mannequin.gd")
const CharacterActionTests := preload("res://tests/character/test_character_actions.gd")
const PlayerIntegrationTests := preload("res://tests/character/test_player_integration.gd")
const BurrowerDefenseTests := preload("res://tests/character/test_burrower_defense.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(MannequinTests.run())
	failures.append_array(CharacterActionTests.run())
	failures.append_array(PlayerIntegrationTests.run())
	failures.append_array(BurrowerDefenseTests.run(self))

	if failures.is_empty():
		print("[CHARACTER VALIDATION] PASS")
		print("  articulated mannequin rig / sockets / placeholder poses passed")
		print("  stamina / dodge / parry timing contracts passed")
		print("  player integration / defensive melee resolution passed")
		print("  Burrower parry stagger / dodge miss distinction passed")
		quit(0)
		return

	printerr("[CHARACTER VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
