extends RefCounted


static func create_environment(root: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.56, 0.72, 0.86)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.76, 0.82)
	environment.ambient_light_energy = 0.8
	world_environment.environment = environment
	root.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	root.add_child(sun)


static func create_water_surface(
	root: Node3D,
	water_settings,
	world_settings,
	spawn_xz: Vector3
) -> MeshInstance3D:
	var water_surface := MeshInstance3D.new()
	water_surface.name = "PrototypeSea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(water_settings.water_plane_size, water_settings.water_plane_size)
	water_surface.mesh = plane
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color(0.08, 0.30, 0.48, 0.72)
	water_material.roughness = 0.18
	water_material.metallic = 0.05
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_surface.material_override = water_material
	water_surface.position = Vector3(spawn_xz.x, world_settings.sea_level + 0.03, spawn_xz.z)
	root.add_child(water_surface)
	return water_surface
