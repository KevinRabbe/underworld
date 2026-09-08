extends RefCounted

const EnvironmentPresentationBuilderScript := preload("res://app/game/composition/environment_presentation_builder.gd")
const WaterSettingsScript := preload("res://presentation/world/environment/prototype_water_settings.gd")
const WorldSettingsScript := preload("res://world/runtime/config/world_settings.gd")


static func run_runtime(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var host := Node3D.new()
	host.name = "CompositionHost"
	tree.root.add_child(host)

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
		if sun.rotation_degrees != Vector3(-55.0, -30.0, 0.0):
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
		if water_surface.position != expected_position:
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

	host.queue_free()
	await tree.process_frame
	return failures
