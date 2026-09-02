extends RefCounted

const CaveRuntimeController := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const CellAddress := preload("res://worldgen/geometry/geometry_cell_address.gd")
const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const ResidencyService := preload("res://gameplay/resources/runtime/underground_resource_residency_service.gd")
const ActionService := preload("res://gameplay/resources/runtime/underground_resource_action_service.gd")
const RealizationService := preload("res://gameplay/resources/runtime/underground_resource_realization_service.gd")
const ContentEvidence := preload("res://gameplay/resources/runtime/underground_resource_content_evidence.gd")
const ArchetypeRealizer := preload("res://core/content/archetypes/archetype_realizer.gd")
const PackedSceneArchetypeAdapter := preload("res://core/content/archetypes/packed_scene_archetype_adapter.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const RuntimeTests := preload("res://tests/resources/test_underground_resource_runtime.gd")

const FLOOR_Y: float = -22.0


class FakeFragment extends RefCounted:
	var fragment_id: String
	var source_descriptor_id: String
	var source_kind: String
	var cell_bounds: AABB
	var clipped_source_bounds: AABB
	var is_owner: bool
	var source_fingerprint: String
	var metadata: Dictionary

	func _init(metadata_value: Dictionary) -> void:
		fragment_id = "fragment-owner-realization"
		source_descriptor_id = "site-owner-realization"
		source_kind = "reserved_site"
		cell_bounds = AABB(Vector3(-8, -28, -8), Vector3(16, 16, 16))
		clipped_source_bounds = cell_bounds
		is_owner = true
		source_fingerprint = "fragment:site-owner-realization"
		metadata = metadata_value.duplicate(true)


class FakePlan extends RefCounted:
	var fragments: Array = []


class FakeStage extends RefCounted:
	var success: bool = true
	var data: Dictionary = {}

	func _init(data_value: Dictionary) -> void:
		data = data_value


class FakeDefinitionService extends RefCounted:
	var definitions: Dictionary = {}

	func cell_definition(address):
		return FakeStage.new(definitions.get(address.canonical_text(), {}))


static func run(realization_parent: Node3D) -> Array[String]:
	var failures: Array[String] = []
	await _test_collision_gated_realization_depletion_and_reentry(realization_parent, failures)
	return failures


static func _test_collision_gated_realization_depletion_and_reentry(
	realization_parent: Node3D,
	failures: Array[String]
) -> void:
	var controller = CaveRuntimeController.new()
	realization_parent.add_child(controller)
	controller.configure("world:realization", "manifest:realization")
	var address = CellAddress.new(Vector3i(1, -2, 1))
	var source := "resource-realization-test"
	var source_fingerprint := "source:realization"
	var provenance_fingerprint := "provenance:realization"
	var record = controller.streamer.demand_cell(
		address,
		source,
		["render", "collision"],
		source_fingerprint,
		provenance_fingerprint
	)
	record.readiness["render"] = true
	record.readiness["collision"] = false

	var plan = FakePlan.new()
	plan.fragments = [FakeFragment.new(_owner_metadata())]
	var definitions = FakeDefinitionService.new()
	definitions.definitions[address.canonical_text()] = {
		"region": Vector2i(0, 0),
		"cell_plan": plan,
		"source_fingerprint": source_fingerprint,
		"provenance_fingerprint": provenance_fingerprint,
	}
	controller._definition_service = definitions

	var authority: Dictionary = ContentEvidence.build_first_iron_authority()
	var residency = ResidencyService.new()
	var residency_failures: Array[String] = residency.configure(controller, authority)
	for failure in residency_failures:
		failures.append("realization residency configure: %s" % failure)
	if not residency_failures.is_empty():
		_cleanup(null, residency, controller)
		return

	var initial_entry: Dictionary = residency.semantic_entry(address.canonical_text())
	if initial_entry.get("placements", []).is_empty():
		failures.append("realization fixture produced no semantic iron placement")
		_cleanup(null, residency, controller)
		return
	var placement = initial_entry["placements"][0]
	var placement_id: String = str(placement.placement_stable_id)

	var action = ActionService.new()
	var action_failures: Array[String] = action.configure(residency)
	for failure in action_failures:
		failures.append("realization action configure: %s" % failure)
	if not action_failures.is_empty():
		_cleanup(null, residency, controller)
		return

	var realizer = ArchetypeRealizer.new()
	var adapter_failures: Array[String] = realizer.register_adapter(PackedSceneArchetypeAdapter.new())
	for failure in adapter_failures:
		failures.append("realization archetype adapter: %s" % failure)
	if not adapter_failures.is_empty():
		_cleanup(null, residency, controller)
		return

	var store = WorldDeltaStore.new()
	var realization = RealizationService.new()
	var realization_failures: Array[String] = realization.configure(
		realization_parent,
		residency,
		authority,
		store,
		realizer,
		action
	)
	for failure in realization_failures:
		failures.append("realization service configure: %s" % failure)
	if not realization_failures.is_empty():
		_cleanup(realization, residency, controller)
		return

	_expect_true(failures, "resource realization is inactive by default", not realization.activation_enabled())
	_expect_equal(failures, "inactive realization publishes zero resource Nodes", realization.live_placement_count(), 0)
	var enable_failures: Array[String] = realization.set_activation_enabled(true)
	for failure in enable_failures:
		failures.append("realization activation: %s" % failure)
	_expect_equal(failures, "render-only semantic placement remains noninteractive", realization.live_placement_count(), 0)

	var floor_shape := _floor_shape()
	_expect_true(
		failures,
		"real cave collision acceptance succeeds",
		controller.accept_collision_shape(
			address,
			floor_shape,
			source_fingerprint,
			provenance_fingerprint
		)
	)
	# Collision attach is sufficient: one bounded physics retry handles the
	# PhysicsServer publication edge without Player/observer movement.
	await realization_parent.get_tree().physics_frame
	await realization_parent.get_tree().physics_frame
	_expect_equal(failures, "collision-ready placement realizes exactly once", realization.live_placement_count(), 1)
	var live = realization.live_instance(placement_id)
	_expect_true(failures, "realized iron root is a live Node3D", live != null and live is Node3D)
	if live != null and live is Node3D:
		_expect_true(
			failures,
			"generated free-space anchor projects down to cave support",
			absf(live.global_position.y - (FLOOR_Y + 0.02)) <= 0.05
		)
		_expect_true(failures, "support projection preserves generated anchor X", absf(live.global_position.x - 1.5) <= 0.01)
		_expect_true(failures, "support projection preserves generated anchor Z", absf(live.global_position.z - 3.0) <= 0.01)
		var interaction = _interaction_node(live)
		_expect_true(failures, "realized iron exposes interaction.primary role", interaction != null)
		if interaction != null:
			_expect_equal(failures, "interaction body carries exact placement identity", str(interaction.get_meta("placement_stable_id", "")), placement_id)
			_expect_equal(failures, "interaction body carries exact owner cell", str(interaction.get_meta("resource_cell_address", "")), address.canonical_text())
			_expect_equal(failures, "interaction body carries current source fingerprint", str(interaction.get_meta("resource_source_fingerprint", "")), source_fingerprint)

	# Removing cave collision immediately removes interaction authority even while
	# semantic render residency remains.
	_expect_true(
		failures,
		"collision-only retirement succeeds for realized resource",
		controller.streamer.release_demand(address, source, ["collision"])
	)
	_expect_equal(failures, "collision retirement synchronously removes live resource", realization.live_placement_count(), 0)

	# Current-generation collision reacquisition reconstructs exactly one Node with
	# the same durable placement identity.
	record = controller.streamer.set_demand(
		address,
		source,
		["render", "collision"],
		source_fingerprint,
		provenance_fingerprint
	)
	_expect_true(
		failures,
		"reacquired current cave collision is accepted",
		controller.accept_collision_shape(
			address,
			_floor_shape(),
			source_fingerprint,
			provenance_fingerprint
		)
	)
	await realization_parent.get_tree().physics_frame
	await realization_parent.get_tree().physics_frame
	_expect_equal(failures, "collision reacquisition realizes one current resource", realization.live_placement_count(), 1)
	var reacquired_live = realization.live_instance(placement_id)
	_expect_true(failures, "reacquired realization preserves placement StableId", reacquired_live != null and str(reacquired_live.get_meta("placement_stable_id", "")) == placement_id)

	var runtime_fixture: Dictionary = RuntimeTests._content_fixture(failures)
	if runtime_fixture.is_empty():
		_cleanup(realization, residency, controller)
		return
	var equipment_fixture: Dictionary = RuntimeTests._pickaxe_equipment(runtime_fixture["pickaxe"], failures)
	if equipment_fixture.is_empty():
		_cleanup(realization, residency, controller)
		return
	var inventory = ItemContainerState.new().configure(4)
	var content_registry = authority.get("content_registry", null)

	for ordinal in range(1, 5):
		var prepared: Dictionary = action.prepare_mining(
			address.canonical_text(),
			placement_id,
			content_registry,
			store
		)
		if not bool(prepared.get("success", false)):
			failures.append("realization mine %d ticket preparation failed: %s" % [ordinal, prepared.get("diagnostics", [])])
			break
		var mined: Dictionary = action.execute_mining(
			prepared.get("ticket", null),
			content_registry,
			equipment_fixture["equipment"],
			inventory,
			store
		)
		if not bool(mined.get("success", false)):
			failures.append("realization mine %d execution failed: %s" % [ordinal, mined.get("diagnostics", [])])
			break
		_expect_equal(failures, "each committed mine yields exactly one iron chunk", inventory.quantity_of("item.resource.iron_chunk"), ordinal)
		if ordinal < 4:
			_expect_equal(failures, "partially depleted resource remains realized", realization.live_placement_count(), 1)
		else:
			# mining_committed is synchronous; final depletion removes the Node from
			# SceneTree before execute_mining returns.
			_expect_true(failures, "final mine reports depleted", bool(mined.get("depleted", false)))
			_expect_equal(failures, "final depletion synchronously removes live resource", realization.live_placement_count(), 0)

	# Full eviction/re-entry reconstructs semantic placement from generated truth,
	# but restored zero depletion suppresses Node creation before archetype publish.
	_expect_true(failures, "fully depleted owner cell evicts", controller.streamer.release_demand(address, source))
	record = controller.streamer.demand_cell(
		address,
		source,
		["render", "collision"],
		source_fingerprint,
		provenance_fingerprint
	)
	record.readiness["render"] = true
	controller.cell_attached.emit(address, "render")
	_expect_true(
		failures,
		"depleted re-entry cave collision is accepted",
		controller.accept_collision_shape(
			address,
			_floor_shape(),
			source_fingerprint,
			provenance_fingerprint
		)
	)
	await realization_parent.get_tree().physics_frame
	await realization_parent.get_tree().physics_frame
	_expect_equal(failures, "fully depleted re-entry creates no interactive resource Node", realization.live_placement_count(), 0)
	var restored: Dictionary = action.inspect_current_placement_state(
		address.canonical_text(),
		placement_id,
		content_registry,
		store
	)
	_expect_true(failures, "fully depleted re-entry still restores semantic depletion state", bool(restored.get("success", false)))
	_expect_equal(failures, "fully depleted re-entry restores zero remaining capacity", float(restored.get("remaining_capacity_units", -1.0)), 0.0)
	_expect_true(failures, "zero depletion forbids later realization", not bool(restored.get("depletion_allows_realization", true)))

	var disable_failures: Array[String] = realization.set_activation_enabled(false)
	for failure in disable_failures:
		failures.append("realization disable: %s" % failure)
	_expect_equal(failures, "explicit domain-authority disable leaves zero live resources", realization.live_placement_count(), 0)
	_cleanup(realization, residency, controller)


static func _owner_metadata() -> Dictionary:
	var region_address = StableAddress.underground_region(0, 0)
	var site_address = StableAddress.special_location(region_address, "reserved_site", 0)
	var stable_id = StableId.from_address(site_address)
	return {
		"stable_id": "" if stable_id == null else stable_id.value(),
		"free_world_anchor": Vector3(1.5, -20.0, 3.0),
		"semantic_category": "reserved_site",
		"reserved_bounds": AABB(Vector3(-2.0, -24.0, -2.0), Vector3(8.0, 8.0, 8.0)),
		"profile_blend": Vector3(0.2, 0.5, 0.3),
		"generation_metadata": {"candidate_slot": 0},
	}


static func _floor_shape():
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(PackedVector3Array([
		Vector3(-4.5, FLOOR_Y, -3.0),
		Vector3(7.5, FLOOR_Y, 9.0),
		Vector3(7.5, FLOOR_Y, -3.0),
		Vector3(-4.5, FLOOR_Y, -3.0),
		Vector3(-4.5, FLOOR_Y, 9.0),
		Vector3(7.5, FLOOR_Y, 9.0),
	]))
	return shape


static func _interaction_node(root: Node):
	var stack: Array = [root]
	while not stack.is_empty():
		var current = stack.pop_back()
		if current != root and current is Node and current.is_in_group("archetype_role:interaction.primary"):
			return current
		if current is Node:
			for child in current.get_children():
				stack.append(child)
	return null


static func _cleanup(realization, residency, controller) -> void:
	if realization != null:
		realization.dispose()
	if residency != null:
		residency.dispose()
	if controller != null and is_instance_valid(controller):
		var parent = controller.get_parent()
		if parent != null:
			parent.remove_child(controller)
		controller.free()


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, expected, actual])
