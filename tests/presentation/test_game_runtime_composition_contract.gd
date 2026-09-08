extends RefCounted

const EnvironmentPresentationBuilderScript := preload("res://app/game/composition/environment_presentation_builder.gd")
const WorldCompositionScript := preload("res://app/game/composition/world_composition.gd")
const PlayerCompositionScript := preload("res://app/game/composition/player_composition.gd")
const CombatCompositionScript := preload("res://app/game/composition/combat_composition.gd")
const InterfaceCompositionScript := preload("res://app/game/composition/interface_composition.gd")
const UnderworldCompositionScript := preload("res://app/game/composition/underworld_composition.gd")
const WorldDeltaStoreScript := preload("res://worldgen/persistence/world_delta_store.gd")
const WorldGenerationContextScript := preload("res://worldgen/pipeline/world_generation_context.gd")
const WaterSettingsScript := preload("res://presentation/world/environment/prototype_water_settings.gd")
const WorldSettingsScript := preload("res://world/runtime/config/world_settings.gd")


class AudioBindingProbe:
	extends Node
	var bound_game: Node = null
	var injected_failures: Array[String] = []

	func bind_game(game: Node) -> Array[String]:
		bound_game = game
		return injected_failures.duplicate()


class PreparedPlayerProbe:
	extends Node3D
	signal harvest_requested
	signal hotbar_slot_requested
	signal craft_requested
	var _gameplay_input_gate: Node = null
	var character_presentation_provider = null
	var harvest_range: float = 0.0
	var tool_use_cooldown: float = 0.0
	var equipped_tool = null

	func set_harvest_range(value: float) -> void:
		harvest_range = value

	func set_tool_use_cooldown(value: float) -> void:
		tool_use_cooldown = value

	func set_equipped_tool(value) -> void:
		equipped_tool = value


class PlayerWorldProbe:
	extends RefCounted
	var bound_player = null

	func get_height_at_world(_x: float, _z: float) -> float:
		return 10.0

	func set_player(value) -> void:
		bound_player = value


class PlayerSurvivalProbe:
	extends RefCounted
	signal equipped_tool_changed(tool)
	var bound_player = null
	var equipped_tool: StringName = &"probe_tool"

	func try_harvest(_world_position = Vector3.ZERO) -> void:
		pass

	func select_hotbar_slot(_slot: int = 0) -> void:
		pass

	func request_craft(_recipe_id: StringName = &"") -> void:
		pass

	func set_player(value) -> void:
		bound_player = value

	func get_equipped_tool() -> StringName:
		return equipped_tool


class PlayerSettingsProbe:
	extends RefCounted
	var harvest_range: float = 6.5
	var tool_use_cooldown: float = 0.35


static func run_runtime(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var host := Node3D.new()
	host.name = "CompositionHost"
	tree.root.add_child(host)

	_test_environment_and_water(host, failures)
	_test_audio_identity(host, failures)
	_test_world_identity_and_failure_propagation(failures)
	_test_prepared_player_identity(tree, failures)
	_test_leaf_failure_propagation(failures)

	host.free()
	return failures


static func _test_environment_and_water(host: Node3D, failures: Array[String]) -> void:
	var environment_result: Dictionary = EnvironmentPresentationBuilderScript.build_environment(host)
	if not bool(environment_result.get("success", false)):
		failures.append("environment builder did not report success")
	var world_environment = environment_result.get("world_environment", null)
	var sun = environment_result.get("sun", null)
	if world_environment == null or not world_environment is WorldEnvironment:
		failures.append("environment builder did not return WorldEnvironment")
	elif world_environment.get_parent() != host or host.get_child(0) != world_environment:
		failures.append("environment builder changed WorldEnvironment parent/order")
	elif world_environment.name != "WorldEnvironment":
		failures.append("environment builder changed WorldEnvironment node name")
	else:
		var environment: Environment = world_environment.environment
		if environment == null:
			failures.append("environment builder did not attach Environment resource")
		else:
			if environment.background_mode != Environment.BG_COLOR:
				failures.append("environment builder changed background mode")
			if environment.background_color != Color(0.56, 0.72, 0.86):
				failures.append("environment builder changed background color")
			if environment.ambient_light_source != Environment.AMBIENT_SOURCE_COLOR:
				failures.append("environment builder changed ambient light source")
			if environment.ambient_light_color != Color(0.72, 0.76, 0.82):
				failures.append("environment builder changed ambient light color")
			if not is_equal_approx(environment.ambient_light_energy, 0.8):
				failures.append("environment builder changed ambient light energy")
	if sun == null or not sun is DirectionalLight3D:
		failures.append("environment builder did not return DirectionalLight3D")
	elif sun.get_parent() != host or host.get_child(1) != sun:
		failures.append("environment builder changed Sun parent/order")
	else:
		if sun.name != "Sun":
			failures.append("environment builder changed Sun node name")
		if not sun.rotation_degrees.is_equal_approx(Vector3(-55.0, -30.0, 0.0)):
			failures.append("environment builder changed Sun rotation")
		if not is_equal_approx(sun.light_energy, 1.1):
			failures.append("environment builder changed Sun energy")
		if not sun.shadow_enabled:
			failures.append("environment builder disabled Sun shadows")

	var water_settings = WaterSettingsScript.new()
	var world_settings = WorldSettingsScript.new()
	var spawn_xz := Vector3(12.0, 0.0, -8.0)
	var water_result: Dictionary = EnvironmentPresentationBuilderScript.build_water_surface(
		host,
		water_settings,
		world_settings,
		spawn_xz
	)
	if not bool(water_result.get("success", false)):
		failures.append("water builder did not report success")
	var water_surface = water_result.get("water_surface", null)
	if water_surface == null or not water_surface is MeshInstance3D:
		failures.append("water builder did not return MeshInstance3D")
	else:
		if water_surface.get_parent() != host or host.get_child(2) != water_surface:
			failures.append("water builder changed PrototypeSea parent/order")
		if water_surface.name != "PrototypeSea":
			failures.append("water builder changed PrototypeSea node name")
		var expected_position := Vector3(spawn_xz.x, world_settings.sea_level + 0.03, spawn_xz.z)
		if not water_surface.position.is_equal_approx(expected_position):
			failures.append("water builder changed PrototypeSea placement")
		if water_surface.mesh == null or not water_surface.mesh is PlaneMesh:
			failures.append("water builder did not retain PlaneMesh presentation")
		elif water_surface.mesh.size != Vector2(water_settings.water_plane_size, water_settings.water_plane_size):
			failures.append("water builder changed configured plane size")
		var material = water_surface.material_override
		if material == null or not material is StandardMaterial3D:
			failures.append("water builder did not retain StandardMaterial3D")
		else:
			if material.albedo_color != Color(0.08, 0.30, 0.48, 0.72):
				failures.append("water builder changed water albedo")
			if not is_equal_approx(material.roughness, 0.18):
				failures.append("water builder changed water roughness")
			if not is_equal_approx(material.metallic, 0.05):
				failures.append("water builder changed water metallic")
			if material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
				failures.append("water builder changed alpha transparency mode")


static func _test_audio_identity(host: Node3D, failures: Array[String]) -> void:
	var audio := AudioBindingProbe.new()
	audio.name = "GameplayAudio"
	host.add_child(audio)
	var result: Dictionary = InterfaceCompositionScript.bind_gameplay_audio(host)
	if not bool(result.get("success", false)):
		failures.append("audio composition unexpectedly failed")
	if result.get("binding", null) != audio or audio.bound_game != host:
		failures.append("audio composition did not preserve exact Game/binding identity")

	audio.injected_failures = ["injected audio failure"]
	var rejected: Dictionary = InterfaceCompositionScript.bind_gameplay_audio(host)
	if bool(rejected.get("success", true)):
		failures.append("audio composition did not propagate binding failure")
	elif rejected.get("diagnostics", []) != ["injected audio failure"]:
		failures.append("audio composition changed binding diagnostics")


static func _test_world_identity_and_failure_propagation(failures: Array[String]) -> void:
	var host := Node3D.new()
	var context = WorldGenerationContextScript.new(73)
	var delta_store = WorldDeltaStoreScript.new()
	var result: Dictionary = WorldCompositionScript.compose(
		host,
		context,
		{"delta_store": delta_store},
		true,
		false
	)
	if result.get("world_delta_store", null) != delta_store:
		failures.append("world composition replaced exact Continue WorldDeltaStore identity")
	var world = result.get("world", null)
	var survival = result.get("survival", null)
	if world == null or survival == null:
		failures.append("world composition did not return Surface/Survival graph")
	elif host.get_child_count() != 2 or host.get_child(0) != world or host.get_child(1) != survival:
		failures.append("world composition changed Surface/Survival construction order")
	var diagnostics: Array = result.get("diagnostics", [])
	if bool(result.get("success", true)):
		failures.append("world composition reported success despite Continue activation diagnostics")
	if diagnostics.is_empty() or not str(diagnostics[0]).begins_with("Detached Continue state failed during activation:"):
		failures.append("world composition did not return Continue activation failure to Game")
	host.free()


static func _test_prepared_player_identity(tree: SceneTree, failures: Array[String]) -> void:
	var host := Node3D.new()
	tree.root.add_child(host)
	var gate := Node.new()
	var prepared := PreparedPlayerProbe.new()
	prepared._gameplay_input_gate = gate
	var world := PlayerWorldProbe.new()
	var survival := PlayerSurvivalProbe.new()
	var settings := PlayerSettingsProbe.new()
	var result: Dictionary = PlayerCompositionScript.compose(
		host,
		prepared,
		gate,
		world,
		survival,
		settings,
		Vector3(2.0, 0.0, 3.0),
		false,
		{}
	)
	if not bool(result.get("success", false)):
		failures.append("prepared Player composition unexpectedly failed: %s" % [result.get("diagnostics", [])])
	elif result.get("player", null) != prepared:
		failures.append("Player composition replaced the exact prepared Player instance")
	elif prepared.get_parent() != host or world.bound_player != prepared or survival.bound_player != prepared:
		failures.append("Player composition changed exact Player dependency binding")
	elif not prepared.global_position.is_equal_approx(Vector3(2.0, 13.0, 3.0)):
		failures.append("Player composition changed post-add spawn placement")

	var mismatched := PreparedPlayerProbe.new()
	var wrong_gate := Node.new()
	mismatched._gameplay_input_gate = wrong_gate
	var rejected: Dictionary = PlayerCompositionScript.compose(
		host,
		mismatched,
		gate,
		null,
		null,
		null,
		Vector3.ZERO,
		false,
		{}
	)
	if bool(rejected.get("success", true)):
		failures.append("Player composition accepted mismatched pre-tree input authority")
	elif rejected.get("diagnostics", []) != ["Prepared Player does not retain exact Game gameplay-input authority"]:
		failures.append("Player composition changed pre-tree authority failure diagnostics")
	elif is_instance_valid(mismatched):
		failures.append("Player composition did not fail closed before tree entry on authority mismatch")

	host.free()
	gate.free()
	wrong_gate.free()


static func _test_leaf_failure_propagation(failures: Array[String]) -> void:
	var combat_host := Node3D.new()
	var death_result: Dictionary = CombatCompositionScript.compose_death_recovery(
		combat_host,
		null,
		null,
		null
	)
	if bool(death_result.get("success", true)):
		failures.append("death-recovery composition accepted missing authorities")
	var death_diagnostics: Array = death_result.get("diagnostics", [])
	if death_diagnostics.size() != 3:
		failures.append("death-recovery composition did not propagate configure diagnostics")
	combat_host.free()

	var underworld_host := Node3D.new()
	var underworld_result: Dictionary = UnderworldCompositionScript.compose(
		underworld_host,
		null,
		null
	)
	if bool(underworld_result.get("success", true)):
		failures.append("Underworld composition accepted missing session context")
	elif underworld_result.get("diagnostics", []) != ["Underworld runtime requires retained exact session root context"]:
		failures.append("Underworld composition changed missing-context diagnostic")
	var runtime = underworld_result.get("underworld_runtime", null)
	if runtime == null or runtime.get_parent() != underworld_host:
		failures.append("Underworld composition changed runtime construction-before-context-check order")
	if underworld_result.get("cave_presentation", null) != null:
		failures.append("Underworld composition created cave presentation after context failure")
	underworld_host.free()
