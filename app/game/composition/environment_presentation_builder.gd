extends RefCounted


static func build_environment(parent: Node3D) -> Dictionary:
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.56, 0.72, 0.86)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.76, 0.82)
	environment.ambient_light_energy = 0.8
	world_environment.environment = environment
	parent.add_child(world_environment)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	parent.add_child(sun)

	return {
		"success": true,
		"world_environment": world_environment,
		"sun": sun,
		"diagnostics": [],
	}


static func build_water_surface(
	parent: Node3D,
	water_settings,
	world_settings,
	spawn_xz: Vector3
) -> Dictionary:
	var water_surface: MeshInstance3D = MeshInstance3D.new()
	water_surface.name = "PrototypeSea"
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(water_settings.water_plane_size, water_settings.water_plane_size)
	water_surface.mesh = plane
	var water_material: StandardMaterial3D = StandardMaterial3D.new()
	water_material.albedo_color = Color(0.08, 0.30, 0.48, 0.72)
	water_material.roughness = 0.18
	water_material.metallic = 0.05
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_surface.material_override = water_material
	water_surface.position = Vector3(spawn_xz.x, world_settings.sea_level + 0.03, spawn_xz.z)
	parent.add_child(water_surface)

	return {
		"success": true,
		"water_surface": water_surface,
		"diagnostics": [],
	}
