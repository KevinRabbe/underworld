extends SceneTree

const MannequinTests := preload("res://tests/character/test_prototype_mannequin.gd")
const SemanticAnimationTests := preload("res://tests/character/test_semantic_animation_layer.gd")
const CharacterActionTests := preload("res://tests/character/test_character_actions.gd")
const PlayerIntegrationTests := preload("res://tests/character/test_player_integration.gd")
const BurrowerDefenseTests := preload("res://tests/character/test_burrower_defense.gd")
const AttackContractTests := preload("res://tests/character/test_attack_contract.gd")
const InputBufferTests := preload("res://tests/character/test_input_buffer.gd")
const DeathRecoveryTests := preload("res://tests/character/test_death_recovery.gd")
const CombatArchitectureTests := preload("res://tests/character/test_combat_architecture.gd")
const WorldSurvivalArchitectureTests := preload("res://tests/character/test_world_survival_architecture.gd")
const PlayerFeelTests := preload("res://tests/character/test_player_feel.gd")
const VoxelCharacterTests := preload("res://tests/character/test_voxel_character.gd")
const UnsupportedHeldItemPresentationTests := preload("res://tests/character/test_unsupported_held_item_presentation.gd")
const BaselineFactory := preload("res://presentation/characters/voxel/baseline_survivor_factory.gd")
const FacetedCompiler := preload("res://presentation/characters/faceted/faceted_body_compiler.gd")
const VoxelPresentation := preload("res://presentation/characters/voxel/voxel_character_presentation.gd")


func _init() -> void:
	# Spatial contracts need Node3D.global_position to be valid, which is only true
	# after the SceneTree has completed its own initialization.
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failures: Array[String] = []
	failures.append_array(MannequinTests.run())
	failures.append_array(SemanticAnimationTests.run())
	failures.append_array(CharacterActionTests.run())
	failures.append_array(PlayerIntegrationTests.run(self))
	failures.append_array(BurrowerDefenseTests.run(self))
	failures.append_array(AttackContractTests.run(self))
	failures.append_array(InputBufferTests.run(self))
	failures.append_array(DeathRecoveryTests.run(self))
	failures.append_array(CombatArchitectureTests.run())
	failures.append_array(WorldSurvivalArchitectureTests.run())
	failures.append_array(PlayerFeelTests.run(self))
	failures.append_array(VoxelCharacterTests.run(self))
	failures.append_array(UnsupportedHeldItemPresentationTests.run(self))

	if failures.is_empty():
		print("[CHARACTER VALIDATION] PASS")
		print("  articulated mannequin rig / sockets / placeholder poses passed")
		print("  semantic animation-set / rig-profile runtime binding contracts passed")
		print("  stamina / dodge / parry / block action contracts passed")
		print("  player defensive melee / frontal block / guard-break integration passed")
		print("  Burrower parry stagger / dodge / block distinction passed")
		print("  phased attack definition / startup-active-recovery contracts passed")
		print("  one-slot expiring combat input buffer contracts passed")
		print("  combat resolution / encounter ownership split contracts passed")
		print("  surface streaming / prototype survival ownership split contracts passed")
		print("  responsive light/heavy action, buffering, stamina, and transition contracts passed")
		print("  faceted skinned survivor, legacy voxel fixture, runtime, and gameplay-boundary contracts passed")
		print("  unsupported held-item presentation fails to explicit hidden fallback without gameplay mutation")
		_print_faceted_metrics()
		quit(0)
		return

	printerr("[CHARACTER VALIDATION] FAIL — %d failure(s)" % failures.size())
	for failure in failures:
		printerr("  - " + failure)
	quit(1)


func _print_faceted_metrics() -> void:
	var definition = BaselineFactory.build()
	var mesh_data = FacetedCompiler.compile(definition.faceted_body_profile, definition.palette, definition.faceted_outfit_definition)
	var presentation = VoxelPresentation.new(definition)
	presentation.build()
	print("  faceted fingerprint=%s" % mesh_data.source_fingerprint)
	print("  presentation fingerprint=%s" % presentation.presentation_fingerprint())
	print("  faceted metrics: surfaces=%d vertices=%d triangles=%d weights=%d memory=%dB compile=%dus main-thread=%dus" % [
		mesh_data.surfaces.size(), int(mesh_data.metrics.get("vertices", 0)),
		int(mesh_data.metrics.get("triangles", 0)), int(mesh_data.metrics.get("skin_weight_values", 0)),
		int(mesh_data.metrics.get("estimated_bytes", 0)), int(mesh_data.metrics.get("compilation_usec", 0)),
		int(presentation.mesh_metrics.get("resource_creation_usec", 0)),
	])
	presentation.free()
