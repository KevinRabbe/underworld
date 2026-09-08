extends RefCounted

const CellAddress := preload("res://worldgen/geometry/geometry_cell_address.gd")
const ResidencyService := preload("res://gameplay/resources/runtime/underground_resource_residency_service.gd")
const ActionService := preload("res://gameplay/resources/runtime/underground_resource_action_service.gd")
const HarvestSink := preload("res://gameplay/resources/runtime/underground_resource_harvest_sink.gd")
const MiningTicket := preload("res://gameplay/resources/runtime/underground_resource_mining_ticket.gd")
const ItemContainerState := preload("res://gameplay/items/inventory/item_container_state.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const RuntimeTests := preload("res://tests/resources/test_underground_resource_runtime.gd")

const OUTCROP_SCENE := preload("res://presentation/world/resources/iron_outcrop.tscn")
const SOURCE_FINGERPRINT := "source:harvest-sink"
const PROVENANCE_FINGERPRINT := "provenance:harvest-sink"
const RAY_ORIGIN := Vector3(0.0, 0.55, -3.0)
const RAY_DIRECTION := Vector3(0.0, 0.0, 1.0)
const RAY_DISTANCE := 5.0


class FakeResidency extends ResidencyService:
	var current_entry: Dictionary = {}

	func semantic_entry(cell_address: String) -> Dictionary:
		if str(current_entry.get("cell_address", "")) != cell_address:
			return {}
		return current_entry.duplicate(true)


static func run(physics_parent: Node3D) -> Array[String]:
	var failures: Array[String] = []
	var fixture: Dictionary = RuntimeTests._content_fixture(failures)
	if fixture.is_empty():
		return failures
	var equipment_fixture: Dictionary = RuntimeTests._pickaxe_equipment(fixture["pickaxe"], failures)
	if equipment_fixture.is_empty():
		return failures

	var placement = RuntimeTests._placement("upf1:harvest-sink-current")
	var cell_address: String = CellAddress.new(Vector3i(2, -3, 1)).canonical_text()
	var residency = FakeResidency.new()
	residency.current_entry = _entry(cell_address, placement, 7)
	var action = ActionService.new()
	var action_failures: Array[String] = action.configure(residency)
	for failure in action_failures:
		failures.append("harvest sink action configure: %s" % failure)
	if not action_failures.is_empty():
		return failures

	var store = WorldDeltaStore.new()
	var inventory = ItemContainerState.new().configure(4)
	var sink = HarvestSink.new()
	var sink_failures: Array[String] = sink.configure(
		physics_parent,
		residency,
		action,
		fixture["registry"],
		store
	)
	for failure in sink_failures:
		failures.append("harvest sink configure: %s" % failure)
	if not sink_failures.is_empty():
		return failures

	var outcrop = OUTCROP_SCENE.instantiate()
	physics_parent.add_child(outcrop)
	outcrop.global_position = Vector3.ZERO
	var interaction = _interaction_node(outcrop)
	_expect_true(failures, "harvest sink fixture exposes interaction.primary", interaction != null)
	if interaction == null:
		_cleanup(sink, outcrop, null)
		return failures
	_stamp(interaction, placement, cell_address, 7)
	await physics_parent.get_tree().physics_frame
	await physics_parent.get_tree().physics_frame

	var inactive: Dictionary = sink.prepare_harvest(RAY_ORIGIN, RAY_DIRECTION, RAY_DISTANCE)
	_expect_true(failures, "inactive underworld harvest sink rejects Player ray", not bool(inactive.get("success", true)))
	_expect_equal(failures, "inactive sink yields no iron", inventory.quantity_of("item.resource.iron_chunk"), 0)
	for failure in sink.set_activation_enabled(true):
		failures.append("harvest sink activation: %s" % failure)

	# Current stable world obstruction wins the same first-hit query and therefore
	# cannot be bypassed to mine the resource behind it.
	var blocker: StaticBody3D = _blocker()
	physics_parent.add_child(blocker)
	await physics_parent.get_tree().physics_frame
	var occluded: Dictionary = sink.prepare_harvest(RAY_ORIGIN, RAY_DIRECTION, RAY_DISTANCE)
	_expect_true(failures, "stable world first hit occludes underworld resource", not bool(occluded.get("success", true)))
	_expect_true(failures, "non-resource occluder is not claimed as handled resource", not bool(occluded.get("handled", true)))
	physics_parent.remove_child(blocker)
	blocker.free()
	await physics_parent.get_tree().physics_frame

	var prepared: Dictionary = sink.prepare_harvest(RAY_ORIGIN, RAY_DIRECTION, RAY_DISTANCE)
	_expect_true(failures, "clear current resource ray prepares mining ticket", bool(prepared.get("success", false)))
	var ticket = prepared.get("ticket", null)
	_expect_true(failures, "harvest preparation returns immutable mining ticket", ticket != null and ticket is MiningTicket)
	if ticket != null and ticket is MiningTicket:
		_expect_equal(failures, "harvest ticket binds exact placement", ticket.placement_stable_id(), placement.placement_stable_id)
		_expect_equal(failures, "harvest ticket binds current owner generation", ticket.cell_generation(), 7)

	# A generation change between aim/prepare and commit cannot be hidden by the
	# still-existing old interaction body. ActionService revalidates the ticket.
	residency.current_entry = _entry(cell_address, placement, 8)
	var stale_commit: Dictionary = sink.execute_prepared(
		ticket,
		equipment_fixture["equipment"],
		inventory
	)
	_expect_true(failures, "stale prepared mining ticket rejects after owner generation changes", not bool(stale_commit.get("success", true)))
	_expect_equal(failures, "stale ticket mutates no inventory", inventory.quantity_of("item.resource.iron_chunk"), 0)
	_expect_true(failures, "stale ticket mutates no WorldDelta", store.get_object_state(placement.placement_stable_id).is_empty())

	# Until the realization body itself carries the new current identity, even a
	# fresh ray fails closed before ticket preparation.
	var stale_body: Dictionary = sink.prepare_harvest(RAY_ORIGIN, RAY_DIRECTION, RAY_DISTANCE)
	_expect_true(failures, "old-generation interaction body cannot prepare against new residency", not bool(stale_body.get("success", true)))
	_expect_true(failures, "stale resource body remains a handled resource rejection", bool(stale_body.get("handled", false)))

	_stamp(interaction, placement, cell_address, 8)
	var committed: Dictionary = sink.try_harvest(
		RAY_ORIGIN,
		RAY_DIRECTION,
		RAY_DISTANCE,
		equipment_fixture["equipment"],
		inventory
	)
	_expect_true(failures, "current clear Player ray mines through immutable ticket route", bool(committed.get("success", false)))
	_expect_equal(failures, "one current Player ray yields exactly one iron chunk", inventory.quantity_of("item.resource.iron_chunk"), 1)
	_expect_equal(failures, "one current Player ray consumes exactly one capacity", float(committed.get("remaining_capacity_units", -1.0)), 3.0)

	var second_prepared: Dictionary = sink.prepare_harvest(RAY_ORIGIN, RAY_DIRECTION, RAY_DISTANCE)
	_expect_true(failures, "second current interaction can prepare", bool(second_prepared.get("success", false)))
	var second_ticket = second_prepared.get("ticket", null)
	sink.set_activation_enabled(false)
	var disabled_commit: Dictionary = sink.execute_prepared(
		second_ticket,
		equipment_fixture["equipment"],
		inventory
	)
	_expect_true(failures, "domain-side disable between prepare and commit fails closed", not bool(disabled_commit.get("success", true)))
	_expect_equal(failures, "disabled commit grants no second iron", inventory.quantity_of("item.resource.iron_chunk"), 1)

	_cleanup(sink, outcrop, null)
	return failures


static func _entry(cell_address: String, placement, generation: int) -> Dictionary:
	return {
		"cell_address": cell_address,
		"generation": generation,
		"source_fingerprint": SOURCE_FINGERPRINT,
		"provenance_fingerprint": PROVENANCE_FINGERPRINT,
		"collision_ready": true,
		"placements": [placement],
	}


static func _stamp(interaction: CollisionObject3D, placement, cell_address: String, generation: int) -> void:
	interaction.set_meta("placement_stable_id", placement.placement_stable_id)
	interaction.set_meta("placement_fingerprint", placement.placement_fingerprint)
	interaction.set_meta("resource_content_id", placement.target_content_id)
	interaction.set_meta("resource_cell_address", cell_address)
	interaction.set_meta("resource_cell_generation", generation)
	interaction.set_meta("resource_source_fingerprint", SOURCE_FINGERPRINT)
	interaction.set_meta("resource_provenance_fingerprint", PROVENANCE_FINGERPRINT)


static func _interaction_node(root: Node):
	var stack: Array = [root]
	while not stack.is_empty():
		var current = stack.pop_back()
		if current != root and current is CollisionObject3D and current.is_in_group("archetype_role:interaction.primary"):
			return current
		if current is Node:
			for child in current.get_children():
				stack.append(child)
	return null


static func _blocker() -> StaticBody3D:
	var blocker = StaticBody3D.new()
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	blocker.position = Vector3(0.0, 0.55, -1.5)
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.2, 1.2, 0.2)
	collision.shape = shape
	blocker.add_child(collision)
	return blocker


static func _cleanup(sink, outcrop, blocker) -> void:
	if sink != null:
		sink.dispose()
	for node in [blocker, outcrop]:
		if node == null or not node is Node or not is_instance_valid(node):
			continue
		var parent = node.get_parent()
		if parent != null:
			parent.remove_child(node)
		node.free()


static func _expect_true(failures: Array[String], label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


static func _expect_equal(failures: Array[String], label: String, actual, expected) -> void:
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [label, expected, actual])
