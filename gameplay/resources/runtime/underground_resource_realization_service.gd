extends RefCounted
class_name UndergroundResourceRealizationService

const StableAddress := preload("res://worldgen/identity/stable_address.gd")
const StableId := preload("res://worldgen/identity/stable_id.gd")
const UndergroundPlacementRecord := preload("res://content/placement/underground_placement_record.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")
const ResidencyService := preload("res://gameplay/resources/runtime/underground_resource_residency_service.gd")
const ActionService := preload("res://gameplay/resources/runtime/underground_resource_action_service.gd")
const RuntimeService := preload("res://gameplay/resources/runtime/underground_resource_runtime_service.gd")
const TicketService := preload("res://gameplay/resources/runtime/underground_resource_mining_ticket_service.gd")
const ContentEvidence := preload("res://gameplay/resources/runtime/underground_resource_content_evidence.gd")
const SupportResolver := preload("res://gameplay/resources/runtime/underground_resource_support_resolver.gd")

signal placement_realized(placement_stable_id: String)
signal placement_retired(placement_stable_id: String)

var _realization_parent = null
var _residency = null
var _action_service = null
var _content_authority: Dictionary = {}
var _delta_store = null
var _archetype_realizer = null
var _support_resolver = SupportResolver.new()
var _ticket_service = TicketService.new()
var _activation_enabled: bool = false
var _live_by_placement: Dictionary = {}
var _pending_physics_retry: Dictionary = {}
var _last_async_diagnostics: Array[String] = []


## Realization remains inert until an external composition owner explicitly
## enables it. Final #404 domain authority owns that decision; this service does
## not inspect active_domain, Player position, cave presence, or world Y.
func configure(
	realization_parent,
	residency,
	content_authority: Dictionary,
	delta_store,
	archetype_realizer,
	action_service = null,
	support_resolver = null
) -> Array[String]:
	dispose()
	var failures: Array[String] = []
	if realization_parent == null or not realization_parent is Node3D:
		failures.append("resource realization requires Node3D realization parent")
	if residency == null or not residency is ResidencyService:
		failures.append("resource realization requires UndergroundResourceResidencyService")
	for failure in ContentEvidence.verification_failures(content_authority):
		failures.append("content authority: %s" % failure)
	if delta_store == null or not delta_store is WorldDeltaStore:
		failures.append("resource realization requires WorldDeltaStore")
	if archetype_realizer == null or not archetype_realizer.has_method("realize"):
		failures.append("resource realization requires ArchetypeRealizer-compatible service")
	if action_service != null and not action_service is ActionService:
		failures.append("resource realization action lifecycle requires UndergroundResourceActionService")
	if support_resolver != null and not support_resolver.has_method("resolve"):
		failures.append("resource realization support resolver must expose resolve()")
	if not failures.is_empty():
		failures.sort()
		return failures

	_realization_parent = realization_parent
	_residency = residency
	_content_authority = content_authority
	_delta_store = delta_store
	_archetype_realizer = archetype_realizer
	_action_service = action_service
	_support_resolver = support_resolver if support_resolver != null else SupportResolver.new()

	var prepared_callback := Callable(self, "_on_semantic_cell_prepared")
	if not _residency.is_connected("semantic_cell_prepared", prepared_callback):
		_residency.connect("semantic_cell_prepared", prepared_callback)
	var collision_callback := Callable(self, "_on_collision_readiness_changed")
	if not _residency.is_connected("collision_readiness_changed", collision_callback):
		_residency.connect("collision_readiness_changed", collision_callback)
	var retired_callback := Callable(self, "_on_semantic_cell_retired")
	if not _residency.is_connected("semantic_cell_retired", retired_callback):
		_residency.connect("semantic_cell_retired", retired_callback)
	if _action_service != null:
		var mined_callback := Callable(self, "_on_mining_committed")
		if not _action_service.is_connected("mining_committed", mined_callback):
			_action_service.connect("mining_committed", mined_callback)
	return []


func dispose() -> void:
	_activation_enabled = false
	_retire_all()
	if _residency != null:
		var prepared_callback := Callable(self, "_on_semantic_cell_prepared")
		if _residency.is_connected("semantic_cell_prepared", prepared_callback):
			_residency.disconnect("semantic_cell_prepared", prepared_callback)
		var collision_callback := Callable(self, "_on_collision_readiness_changed")
		if _residency.is_connected("collision_readiness_changed", collision_callback):
			_residency.disconnect("collision_readiness_changed", collision_callback)
		var retired_callback := Callable(self, "_on_semantic_cell_retired")
		if _residency.is_connected("semantic_cell_retired", retired_callback):
			_residency.disconnect("semantic_cell_retired", retired_callback)
	if _action_service != null:
		var mined_callback := Callable(self, "_on_mining_committed")
		if _action_service.is_connected("mining_committed", mined_callback):
			_action_service.disconnect("mining_committed", mined_callback)
	_realization_parent = null
	_residency = null
	_action_service = null
	_content_authority.clear()
	_delta_store = null
	_archetype_realizer = null
	_support_resolver = SupportResolver.new()
	_pending_physics_retry.clear()
	_last_async_diagnostics.clear()


func set_activation_enabled(enabled: bool) -> Array[String]:
	if _activation_enabled == enabled:
		return []
	_activation_enabled = enabled
	if not enabled:
		_retire_all()
		_pending_physics_retry.clear()
		return []
	if _residency == null:
		_activation_enabled = false
		return ["resource realization service is not configured"]

	var failures: Array[String] = []
	for entry in _residency.semantic_entries():
		var cell_address: String = str(entry.get("cell_address", ""))
		if cell_address.is_empty():
			continue
		failures.append_array(synchronize_cell(cell_address))
		if bool(entry.get("collision_ready", false)):
			_schedule_physics_retry(cell_address)
	failures.sort()
	return failures


func activation_enabled() -> bool:
	return _activation_enabled


func synchronize_cell(cell_address: String) -> Array[String]:
	var failures: Array[String] = []
	if not _activation_enabled:
		return failures
	if _residency == null:
		return ["resource realization service is not configured"]
	var entry: Dictionary = _residency.semantic_entry(cell_address)
	if entry.is_empty() or not bool(entry.get("collision_ready", false)):
		_retire_cell(cell_address)
		return failures

	var placements_variant = entry.get("placements", null)
	if not placements_variant is Array:
		_retire_cell(cell_address)
		return ["resource realization current cell has no semantic placement list"]
	var placements: Array = placements_variant.duplicate()
	placements.sort_custom(func(a, b) -> bool:
		if a == null:
			return b != null
		if b == null:
			return false
		return str(a.placement_stable_id) < str(b.placement_stable_id)
	)

	var current_ids: Dictionary = {}
	for placement in placements:
		if placement == null or not placement is UndergroundPlacementRecord:
			failures.append("resource realization encountered invalid placement record")
			continue
		current_ids[placement.placement_stable_id] = true

		var inspected: Dictionary = _ticket_service.inspect_realization_state(
			placement,
			_content_authority.get("content_registry", null),
			_delta_store
		)
		if not bool(inspected.get("success", false)):
			_retire_placement(placement.placement_stable_id)
			failures.append_array(_prefixed(
				"depletion restore %s" % placement.placement_stable_id,
				inspected.get("diagnostics", [])
			))
			continue
		if not bool(inspected.get("depletion_allows_realization", false)):
			_retire_placement(placement.placement_stable_id)
			continue

		var hook_result: Dictionary = _hook_for_placement(entry, placement)
		if not bool(hook_result.get("success", false)):
			_retire_placement(placement.placement_stable_id)
			failures.append_array(hook_result.get("diagnostics", []))
			continue
		var support: Dictionary = _support_resolver.resolve(
			_realization_parent,
			entry,
			hook_result.get("hook", {})
		)
		if not bool(support.get("success", false)):
			_retire_placement(placement.placement_stable_id)
			failures.append_array(_prefixed(
				"support %s" % placement.placement_stable_id,
				support.get("diagnostics", [])
			))
			continue

		var current_entry: Dictionary = _residency.semantic_entry(cell_address)
		if not _same_current_entry(entry, current_entry):
			_retire_placement(placement.placement_stable_id)
			failures.append("resource realization owner cell changed during support resolution")
			continue
		if not _entry_contains_placement(current_entry, placement):
			_retire_placement(placement.placement_stable_id)
			failures.append("resource realization placement changed during support resolution")
			continue

		var support_position_variant = support.get("world_position", null)
		if typeof(support_position_variant) != TYPE_VECTOR3:
			_retire_placement(placement.placement_stable_id)
			failures.append("resource realization support resolver returned no world position")
			continue
		var support_position: Vector3 = support_position_variant
		if _live_matches(placement, current_entry, support_position):
			continue
		_retire_placement(placement.placement_stable_id)

		var realized: Dictionary = RuntimeService.new().realize_placement(
			placement,
			_content_authority.get("content_registry", null),
			_content_authority.get("validation_result", {}),
			_archetype_realizer
		)
		if not bool(realized.get("success", false)):
			failures.append_array(_prefixed(
				"realize %s" % placement.placement_stable_id,
				realized.get("diagnostics", [])
			))
			continue
		var instance = realized.get("instance", null)
		if instance == null or not instance is Node3D:
			if instance != null and instance is Node:
				instance.free()
			failures.append("resource realization archetype root must be Node3D")
			continue

		# Revalidate after archetype construction but before any gameplay Node enters
		# the tree. A stale realization is discarded off-tree.
		var final_entry: Dictionary = _residency.semantic_entry(cell_address)
		if not _same_current_entry(current_entry, final_entry) or not _entry_contains_placement(final_entry, placement):
			instance.free()
			failures.append("resource realization owner cell changed before publication")
			continue

		_stamp_runtime_identity(instance, placement, final_entry)
		var world_transform := Transform3D(Basis.IDENTITY, support_position)
		instance.transform = _realization_parent.global_transform.affine_inverse() * world_transform
		_realization_parent.add_child(instance)
		_live_by_placement[placement.placement_stable_id] = {
			"node": instance,
			"cell_address": cell_address,
			"generation": int(final_entry.get("generation", -1)),
			"source_fingerprint": str(final_entry.get("source_fingerprint", "")),
			"provenance_fingerprint": str(final_entry.get("provenance_fingerprint", "")),
			"placement_fingerprint": placement.placement_fingerprint,
			"world_position": support_position,
		}
		placement_realized.emit(placement.placement_stable_id)

	# Retire any live realization that belonged to this cell but is no longer in
	# the current deterministic placement set.
	for raw_id in _live_by_placement.keys().duplicate():
		var placement_id: String = str(raw_id)
		var live_variant = _live_by_placement.get(placement_id, null)
		if not live_variant is Dictionary:
			continue
		if str(live_variant.get("cell_address", "")) == cell_address and not current_ids.has(placement_id):
			_retire_placement(placement_id)
	failures.sort()
	return failures


func live_placement_count() -> int:
	_prune_invalid_live_nodes()
	return _live_by_placement.size()


func live_instance(placement_stable_id: String):
	_prune_invalid_live_nodes()
	var live_variant = _live_by_placement.get(placement_stable_id, null)
	if not live_variant is Dictionary:
		return null
	return live_variant.get("node", null)


func last_async_diagnostics() -> Array[String]:
	return _last_async_diagnostics.duplicate()


func retire_placement(placement_stable_id: String) -> void:
	_retire_placement(placement_stable_id)


func _on_semantic_cell_prepared(cell_address: String) -> void:
	if not _activation_enabled:
		return
	_last_async_diagnostics = synchronize_cell(cell_address)
	var entry: Dictionary = _residency.semantic_entry(cell_address)
	if bool(entry.get("collision_ready", false)):
		_schedule_physics_retry(cell_address)


func _on_collision_readiness_changed(cell_address: String, ready: bool) -> void:
	if not ready:
		_retire_cell(cell_address)
		_pending_physics_retry.erase(cell_address)
		return
	if not _activation_enabled:
		return
	_last_async_diagnostics = synchronize_cell(cell_address)
	_schedule_physics_retry(cell_address)


func _on_semantic_cell_retired(cell_address: String) -> void:
	_retire_cell(cell_address)
	_pending_physics_retry.erase(cell_address)


func _on_mining_committed(
	_cell_address: String,
	placement_stable_id: String,
	depleted: bool
) -> void:
	if depleted:
		# Removing from the SceneTree synchronously disables interaction authority;
		# queue_free then handles final object destruction safely.
		_retire_placement(placement_stable_id)


func _schedule_physics_retry(cell_address: String) -> void:
	if (
		not _activation_enabled
		or _realization_parent == null
		or _pending_physics_retry.has(cell_address)
	):
		return
	var tree = _realization_parent.get_tree()
	if tree == null:
		return
	_pending_physics_retry[cell_address] = true
	var callback := Callable(self, "_on_physics_retry").bind(cell_address)
	tree.physics_frame.connect(callback, CONNECT_ONE_SHOT)


func _on_physics_retry(cell_address: String) -> void:
	_pending_physics_retry.erase(cell_address)
	if not _activation_enabled or _residency == null:
		return
	_last_async_diagnostics = synchronize_cell(cell_address)


func _hook_for_placement(entry: Dictionary, placement) -> Dictionary:
	var candidate_id = StableId.parse(placement.candidate_stable_id)
	if candidate_id == null:
		return _failure(["resource realization placement candidate StableId is invalid"])
	var segments: Array[String] = candidate_id.address().segments()
	if segments.size() < 2:
		return _failure(["resource realization candidate StableAddress is not channel-scoped"])
	if segments[segments.size() - 2] != "channel" or segments[segments.size() - 1] != "resource":
		return _failure(["resource realization candidate is not in resource channel"])
	var site_segments: Array[String] = []
	for index in range(segments.size() - 2):
		site_segments.append(segments[index])
	var site_address = StableAddress.from_segments(site_segments)
	var site_id = StableId.from_address(site_address) if site_address != null else null
	if site_id == null:
		return _failure(["resource realization could not reconstruct generated site identity"])

	var matches: Array = []
	var hooks_variant = entry.get("hooks", null)
	if not hooks_variant is Array:
		return _failure(["resource realization current cell has no generated hook list"])
	for hook_variant in hooks_variant:
		if not hook_variant is Dictionary:
			continue
		var hook: Dictionary = hook_variant
		if str(hook.get("stable_id", "")) == site_id.value():
			matches.append(hook.duplicate(true))
	if matches.size() != 1:
		return _failure([
			"resource realization requires exactly one generated owner hook for placement: %s" % placement.placement_stable_id
		])
	return {
		"success": true,
		"hook": matches[0],
		"diagnostics": [],
	}


func _live_matches(placement, entry: Dictionary, world_position: Vector3) -> bool:
	var live_variant = _live_by_placement.get(placement.placement_stable_id, null)
	if not live_variant is Dictionary:
		return false
	var live: Dictionary = live_variant
	var node = live.get("node", null)
	if node == null or not node is Node3D or not is_instance_valid(node) or node.get_parent() == null:
		return false
	return (
		str(live.get("cell_address", "")) == str(entry.get("cell_address", ""))
		and int(live.get("generation", -1)) == int(entry.get("generation", -2))
		and str(live.get("source_fingerprint", "")) == str(entry.get("source_fingerprint", ""))
		and str(live.get("provenance_fingerprint", "")) == str(entry.get("provenance_fingerprint", ""))
		and str(live.get("placement_fingerprint", "")) == placement.placement_fingerprint
		and Vector3(live.get("world_position", Vector3.ZERO)).is_equal_approx(world_position)
	)


func _same_current_entry(expected: Dictionary, current: Dictionary) -> bool:
	return (
		not current.is_empty()
		and bool(current.get("collision_ready", false))
		and str(current.get("cell_address", "")) == str(expected.get("cell_address", ""))
		and int(current.get("generation", -1)) == int(expected.get("generation", -2))
		and str(current.get("source_fingerprint", "")) == str(expected.get("source_fingerprint", ""))
		and str(current.get("provenance_fingerprint", "")) == str(expected.get("provenance_fingerprint", ""))
	)


static func _entry_contains_placement(entry: Dictionary, placement) -> bool:
	var placements_variant = entry.get("placements", null)
	if not placements_variant is Array:
		return false
	for candidate in placements_variant:
		if candidate == null or not candidate is UndergroundPlacementRecord:
			continue
		if (
			candidate.placement_stable_id == placement.placement_stable_id
			and candidate.placement_fingerprint == placement.placement_fingerprint
			and candidate.target_content_id == placement.target_content_id
		):
			return true
	return false


static func _stamp_runtime_identity(instance: Node, placement, entry: Dictionary) -> void:
	var stack: Array = [instance]
	while not stack.is_empty():
		var current = stack.pop_back()
		if current == null or not current is Node:
			continue
		if current == instance or current.is_in_group("archetype_role:interaction.primary"):
			current.set_meta("placement_stable_id", placement.placement_stable_id)
			current.set_meta("placement_fingerprint", placement.placement_fingerprint)
			current.set_meta("resource_content_id", placement.target_content_id)
			current.set_meta("resource_cell_address", str(entry.get("cell_address", "")))
			current.set_meta("resource_cell_generation", int(entry.get("generation", -1)))
			current.set_meta("resource_source_fingerprint", str(entry.get("source_fingerprint", "")))
			current.set_meta("resource_provenance_fingerprint", str(entry.get("provenance_fingerprint", "")))
		for child in current.get_children():
			stack.append(child)


func _retire_cell(cell_address: String) -> void:
	for raw_id in _live_by_placement.keys().duplicate():
		var placement_id: String = str(raw_id)
		var live_variant = _live_by_placement.get(placement_id, null)
		if live_variant is Dictionary and str(live_variant.get("cell_address", "")) == cell_address:
			_retire_placement(placement_id)


func _retire_all() -> void:
	for raw_id in _live_by_placement.keys().duplicate():
		_retire_placement(str(raw_id))


func _retire_placement(placement_stable_id: String) -> void:
	if not _live_by_placement.has(placement_stable_id):
		return
	var live_variant = _live_by_placement.get(placement_stable_id, null)
	_live_by_placement.erase(placement_stable_id)
	if live_variant is Dictionary:
		var node = live_variant.get("node", null)
		if node != null and node is Node and is_instance_valid(node):
			var parent = node.get_parent()
			if parent != null:
				parent.remove_child(node)
			if not node.is_queued_for_deletion():
				node.queue_free()
	placement_retired.emit(placement_stable_id)


func _prune_invalid_live_nodes() -> void:
	for raw_id in _live_by_placement.keys().duplicate():
		var placement_id: String = str(raw_id)
		var live_variant = _live_by_placement.get(placement_id, null)
		if not live_variant is Dictionary:
			_live_by_placement.erase(placement_id)
			continue
		var node = live_variant.get("node", null)
		if node == null or not node is Node or not is_instance_valid(node) or node.get_parent() == null:
			_live_by_placement.erase(placement_id)


static func _prefixed(prefix: String, diagnostics: Array) -> Array[String]:
	var result: Array[String] = []
	for diagnostic in diagnostics:
		result.append("%s: %s" % [prefix, str(diagnostic)])
	return result


static func _failure(failures: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for failure in failures:
		diagnostics.append(str(failure))
	diagnostics.sort()
	return {
		"success": false,
		"hook": {},
		"diagnostics": diagnostics,
	}
