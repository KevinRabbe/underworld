extends RefCounted

const GAME_SCENE_PATH := "res://app/game/game.tscn"
const Selector := preload("res://worldgen/surface/natural_entrance_route_selector.gd")
const GeneratedBootstrap := preload("res://worldgen/runtime/generated_entrance_bootstrap_adapter.gd")
const Controller := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const WorldId := preload("res://worldgen/identity/world_id.gd")
const Manifest := preload("res://worldgen/versioning/generator_manifest.gd")
const WorldContext := preload("res://worldgen/pipeline/world_generation_context.gd")
const SurfaceSampler := preload("res://worldgen/surface/deterministic_surface_sampler.gd")
const MacroGenerator := preload("res://worldgen/underworld/macro_region_generator.gd")
const TopologyGenerator := preload("res://worldgen/underworld/primary_topology_generator.gd")
const EntranceGenerator := preload("res://worldgen/underworld/entrance_generator.gd")

const START_ANCHOR := Vector3(64.0, 0.0, 64.0)


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_game_scene_composition(failures)
	_test_selection(12345, failures)
	_test_selection(1, failures)
	_test_generated_runtime_route(12345, failures)
	return failures


static func _test_game_scene_composition(failures: Array[String]) -> void:
	var packed = ResourceLoader.load(GAME_SCENE_PATH)
	_expect(failures, "production Game scene loads", packed != null and packed is PackedScene)
	if packed == null or not packed is PackedScene:
		return
	var game: Node = packed.instantiate()
	_expect(failures, "production Game scene instantiates", game != null)
	if game == null:
		return
	var route_controller := game.get_node_or_null("NaturalEntranceRoute")
	_expect(failures, "production Game mounts natural entrance route coordinator", route_controller != null)
	if route_controller != null:
		_expect(failures, "route coordinator exposes semantic readiness", route_controller.has_method("route_is_ready"))
		_expect(failures, "route coordinator exposes value-copy route snapshot", route_controller.has_method("route_snapshot"))
		_expect(failures, "off-tree route coordinator has no fabricated route", not bool(route_controller.call("route_is_ready")))
	game.free()


static func _test_selection(world_seed: int, failures: Array[String]) -> void:
	var first: Dictionary = Selector.select(world_seed, START_ANCHOR)
	var second: Dictionary = Selector.select(world_seed, START_ANCHOR)
	_expect(failures, "natural route selects seed %d" % world_seed, bool(first.get("success", false)))
	_expect(failures, "natural route repeats seed %d" % world_seed, bool(second.get("success", false)))
	if not bool(first.get("success", false)) or not bool(second.get("success", false)):
		return
	var route: Dictionary = first.get("route", {})
	var repeated: Dictionary = second.get("route", {})
	_expect(
		failures,
		"natural route fingerprint is deterministic seed %d" % world_seed,
		str(route.get("selection_fingerprint", "")) == str(repeated.get("selection_fingerprint", ""))
	)
	_expect(
		failures,
		"natural route identity is deterministic seed %d" % world_seed,
		str(route.get("entrance_id", "")) == str(repeated.get("entrance_id", ""))
		and route.get("region_coord", Vector2i(999, 999)) == repeated.get("region_coord", Vector2i(-999, -999))
	)
	var spawn_variant: Variant = route.get("recommended_spawn_xz", null)
	var surface_variant: Variant = route.get("surface_world_position", null)
	var opening_variant: Variant = route.get("required_opening_bounds", null)
	_expect(failures, "natural route exposes bounded spawn seed %d" % world_seed, spawn_variant is Vector3)
	_expect(failures, "natural route exposes surface position seed %d" % world_seed, surface_variant is Vector3)
	_expect(failures, "natural route exposes opening bounds seed %d" % world_seed, opening_variant is AABB)
	if spawn_variant is Vector3 and surface_variant is Vector3 and opening_variant is AABB:
		var spawn: Vector3 = spawn_variant
		var surface: Vector3 = surface_variant
		var opening: AABB = opening_variant
		var distance: float = Vector2(spawn.x - surface.x, spawn.z - surface.z).length()
		_expect(
			failures,
			"natural route spawn stays near visible entrance seed %d" % world_seed,
			distance >= 24.0 and distance <= 64.0
		)
		_expect(
			failures,
			"natural route spawn stays outside opening seed %d" % world_seed,
			not _contains_xz(opening.grow(float(route.get("clearance_radius", 0.0))), spawn)
		)
		var sample = SurfaceSampler.new(world_seed).sample(spawn.x, spawn.z)
		_expect(
			failures,
			"natural route spawn is dry and traversable seed %d" % world_seed,
			sample != null and not sample.is_submerged() and sample.slope <= Selector.MAX_SPAWN_SLOPE
		)
	_verify_selected_descriptor(world_seed, route, failures)


static func _verify_selected_descriptor(
	world_seed: int,
	route: Dictionary,
	failures: Array[String]
) -> void:
	var region_variant: Variant = route.get("region_coord", null)
	if not region_variant is Vector2i:
		failures.append("natural route selected region is malformed seed %d" % world_seed)
		return
	var region: Vector2i = region_variant
	var context = WorldContext.new(world_seed)
	var sampler = SurfaceSampler.new(world_seed)
	var macro = MacroGenerator.generate(context, region)
	var topology = TopologyGenerator.generate(context, macro.data, sampler) if macro.success else null
	var entrances = EntranceGenerator.generate(context, macro.data, topology.data, sampler) if topology != null and topology.success else null
	_expect(
		failures,
		"natural route source generation remains valid seed %d" % world_seed,
		macro.success and topology != null and topology.success and entrances != null and entrances.success
	)
	if not macro.success or topology == null or not topology.success or entrances == null or not entrances.success:
		return
	var selected = null
	for descriptor in entrances.data.surface_integration_descriptors:
		if str(descriptor.entrance_id) == str(route.get("entrance_id", "")):
			selected = descriptor
			break
	_expect(failures, "natural route selects an authored/generated descriptor seed %d" % world_seed, selected != null)
	if selected == null:
		return
	_expect(
		failures,
		"natural route does not rewrite entrance surface position seed %d" % world_seed,
		selected.surface_world_position == route.get("surface_world_position", Vector3.INF)
	)
	_expect(
		failures,
		"natural route does not rewrite entrance opening seed %d" % world_seed,
		selected.required_opening_bounds == route.get("required_opening_bounds", AABB())
	)
	_expect(
		failures,
		"natural route retains entrance generation fingerprint seed %d" % world_seed,
		str(entrances.fingerprint) == str(route.get("source_entrance_fingerprint", ""))
	)


static func _test_generated_runtime_route(world_seed: int, failures: Array[String]) -> void:
	var selection: Dictionary = Selector.select(world_seed, START_ANCHOR)
	if not bool(selection.get("success", false)):
		failures.append("generated runtime route could not select entrance: %s" % [selection.get("diagnostics", [])])
		return
	var route: Dictionary = selection.get("route", {})
	var region_variant: Variant = route.get("region_coord", null)
	if not region_variant is Vector2i:
		failures.append("generated runtime route selected malformed region")
		return
	var region: Vector2i = region_variant
	var entrance_id: String = str(route.get("entrance_id", ""))
	var controller := Controller.new()
	controller.configure(
		WorldId.from_seed(world_seed).value(),
		Manifest.foundation_default().manifest_id()
	)
	var diagnostics: Array[String] = GeneratedBootstrap.bootstrap(
		controller,
		world_seed,
		region,
		entrance_id
	)
	_expect(failures, "ordinary generated entrance bootstraps without fixture constants", diagnostics.is_empty())
	if diagnostics.is_empty():
		var required_cells: Array = []
		if controller.entrance_plans.has(entrance_id):
			required_cells = controller.entrance_plans[entrance_id].cell_addresses
		_expect(failures, "ordinary generated entrance has required runtime cells", not required_cells.is_empty())
		_expect(failures, "ordinary generated entrance realizes required render cells", controller.render_nodes.size() >= required_cells.size())
		_expect(failures, "ordinary generated entrance realizes required collision cells", controller.collision_nodes.size() >= required_cells.size())
		_expect(failures, "ordinary generated entrance opens traversal gate", controller.gate_is_open(entrance_id))
		_expect(
			failures,
			"ordinary generated bootstrap preserves selected surface position",
			controller.last_bootstrap_surface_position == route.get("surface_world_position", Vector3.INF)
		)
		if not required_cells.is_empty():
			var surface: Vector3 = route.get("surface_world_position", Vector3.ZERO)
			var forward_cells: Array[Vector3] = []
			for address in required_cells:
				forward_cells.append(Vector3(address.coordinate) * 32.0 + Vector3(16.0, 16.0, 16.0))
			var backtrack_cells: Array[Vector3] = forward_cells.duplicate()
			backtrack_cells.reverse()
			var positions: Array[Vector3] = [surface + Vector3.UP * 3.0]
			positions.append_array(forward_cells)
			positions.append_array(backtrack_cells)
			positions.append(surface + Vector3.UP * 3.0)
			for position in positions:
				controller.update_player_position(position)
				if not controller.gate_is_open(entrance_id):
					failures.append("ordinary generated route lost gate readiness during surface-to-cave backtrack")
					break
			_expect(failures, "ordinary generated backtrack has no stale resurrection", controller.streamer.stale_result_count == 0)
	controller.free()


static func _contains_xz(bounds: AABB, point: Vector3) -> bool:
	return (
		point.x >= bounds.position.x
		and point.x <= bounds.end.x
		and point.z >= bounds.position.z
		and point.z <= bounds.end.z
	)


static func _expect(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)
