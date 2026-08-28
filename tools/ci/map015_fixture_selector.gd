extends SceneTree

const Context := preload("res://worldgen/pipeline/world_generation_context.gd")
const Sampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const Macro := preload("res://worldgen/underworld/macro_region_generator.gd")
const Topology := preload("res://worldgen/underworld/primary_topology_generator.gd")
const Entrances := preload("res://worldgen/underworld/entrance_generator.gd")
const SurfacePlan := preload("res://worldgen/surface/surface_entrance_chunk_plan.gd")
const GeometryProbe := preload("res://worldgen/validation/cave_geometry_reproduction_probe.gd")

func _init() -> void:
	for seed in range(1, 257):
		for z in range(-1, 2):
			for x in range(-1, 2):
				var region := Vector2i(x, z)
				var context := Context.new(seed)
				var sampler := Sampler.new(seed)
				var macro = Macro.generate(context, region)
				if not macro.success: continue
				var topology = Topology.generate(context, macro.data, sampler)
				if not topology.success: continue
				var entrances = Entrances.generate(context, macro.data, topology.data, sampler)
				if not entrances.success: continue
				var descriptors: Array = entrances.data.surface_integration_descriptors.duplicate()
				descriptors.sort_custom(func(a, b): return str(a.entrance_id) < str(b.entrance_id))
				for descriptor in descriptors:
					var plan_result = SurfacePlan.build(AABB(descriptor.surface_world_position - Vector3(32, 32, 32), Vector3(64, 64, 64)), [descriptor], Vector2i(16, 16), entrances.fingerprint)
					if not plan_result.success: continue
					var plan = plan_result.data
					var geometry = GeometryProbe.build(seed, region)
					var nonempty := int(geometry.get("metrics", {}).get("chamber_count", 0)) + int(geometry.get("metrics", {}).get("tunnel_count", 0)) > 0
					if plan.underground_cells.size() >= 4 and nonempty:
						print("MAP015 fixture seed=%d region=(%d,%d) entrance=%s entrance_fp=%s geometry_fp=%s cells=%d" % [seed, x, z, descriptor.entrance_id, entrances.fingerprint, geometry.get("fingerprint", ""), plan.underground_cells.size()])
						quit(0); return
	print("MAP015 fixture not found"); quit(1)
