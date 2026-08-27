extends SceneTree

const MannequinTests := preload("res://tests/character/test_prototype_mannequin.gd")
const CharacterActionTests := preload("res://tests/character/test_character_actions.gd")
const PlayerIntegrationTests := preload("res://tests/character/test_player_integration.gd")
const BurrowerDefenseTests := preload("res://tests/character/test_burrower_defense.gd")
const AttackContractTests := preload("res://tests/character/test_attack_contract.gd")
const InputBufferTests := preload("res://tests/character/test_input_buffer.gd")


func _init() -> void:
	# Spatial contracts need Node3D.global_position to be valid, which is only true
	# after the SceneTree has completed its own initialization.
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failures: Array[String] = []
	failures.append_array(MannequinTests.run())
	failures.append_array(CharacterActionTests.run())
	failures.append_array(PlayerIntegrationTests.run(self))
	failures.append_array(BurrowerDefenseTests.run(self))
	failures.append_array(AttackContractTests.run(self))
	failures.append_array(InputBufferTests.run(self))

	if failures.is_empty():
		print("[CHARACTER VALIDATION] PASS")
		print("  articulated mannequin rig / sockets / placeholder poses passed")
		print("  stamina / dodge / parry / block action contracts passed")
		print("  player defensive melee / frontal block / guard-break integration passed")
		print("  Burrower parry stagger / dodge / block distinction passed")
		print("  phased attack definition / startup-active-recovery contracts passed")
		print("  one-slot expiring combat input buffer contracts passed")
		quit(0)
		return

	printerr("[CHARACTER VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)
