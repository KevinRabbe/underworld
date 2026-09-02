extends RefCounted
class_name UndergroundResourceMiningTicketService

const StableId := preload("res://worldgen/identity/stable_id.gd")
const UndergroundPlacementRecord := preload("res://content/placement/underground_placement_record.gd")
const ResourceDepletionState := preload("res://gameplay/resources/state/resource_depletion_state.gd")
const Ticket := preload("res://gameplay/resources/runtime/underground_resource_mining_ticket.gd")
const RuntimeService := preload("res://gameplay/resources/runtime/underground_resource_runtime_service.gd")


## Restores durable depletion before any caller may consider creating a live
## resource Node. This is only the depletion gate: current cave collision/support
## and final committed-domain authority remain separate mandatory gates.
func inspect_realization_state(placement, content_registry, delta_store) -> Dictionary:
	var restored: Dictionary = RuntimeService.new().restore_state(
		placement,
		content_registry,
		delta_store
	)
	if not bool(restored.get("success", false)):
		return restored
	var state = restored.get("state", null)
	if state == null or not state is ResourceDepletionState:
		return _failure(["resource realization preparation did not restore depletion state"])
	return {
		"success": true,
		"depletion_allows_realization": state.remaining_capacity_units > 0.0,
		"remaining_capacity_units": state.remaining_capacity_units,
		"fresh": bool(restored.get("fresh", false)),
		"diagnostics": [],
	}


func prepare_ticket(
	placement,
	content_registry,
	delta_store,
	current_cell_entry: Dictionary
) -> Dictionary:
	if placement == null or not placement is UndergroundPlacementRecord:
		return _failure(["resource mining ticket preparation requires UndergroundPlacementRecord"])
	var freshness_failures: Array[String] = _cell_entry_failures(current_cell_entry, placement)
	if not freshness_failures.is_empty():
		return _failure(freshness_failures)

	var restored: Dictionary = RuntimeService.new().restore_state(
		placement,
		content_registry,
		delta_store
	)
	if not bool(restored.get("success", false)):
		return restored
	var state = restored.get("state", null)
	if state == null or not state is ResourceDepletionState:
		return _failure(["resource mining ticket preparation did not restore depletion state"])
	if state.remaining_capacity_units < RuntimeService.CAPACITY_PER_OPERATION:
		return _failure(["resource mining ticket cannot target depleted or insufficient-capacity resource"])

	var completed_variant = state.get_delta_value("completed_operation_ids", [])
	if not completed_variant is Array:
		return _failure(["resource mining ticket preparation requires validated completed operation ids"])
	var ordinal: int = completed_variant.size() + 1
	var operation_id: String = _operation_id(placement.placement_stable_id, ordinal)
	if operation_id.is_empty():
		return _failure(["resource mining ticket could not derive canonical operation identity"])
	var ticket = Ticket.new(
		placement.placement_stable_id,
		placement.placement_fingerprint,
		placement.target_content_id,
		operation_id,
		ordinal,
		str(current_cell_entry.get("cell_address", "")),
		int(current_cell_entry.get("generation", 0)),
		str(current_cell_entry.get("source_fingerprint", "")),
		str(current_cell_entry.get("provenance_fingerprint", ""))
	)
	var ticket_failures: Array[String] = ticket.validate_ticket()
	if not ticket_failures.is_empty():
		return _failure(ticket_failures)
	return {
		"success": true,
		"ticket": ticket,
		"remaining_capacity_units": state.remaining_capacity_units,
		"diagnostics": [],
	}


func execute_ticket(
	ticket,
	placement,
	content_registry,
	equipment_state,
	inventory,
	delta_store,
	current_cell_entry: Dictionary
) -> Dictionary:
	var failures: Array[String] = []
	if ticket == null or not ticket is Ticket:
		failures.append("resource mining execution requires UndergroundResourceMiningTicket")
	else:
		failures.append_array(ticket.validate_ticket())
	if placement == null or not placement is UndergroundPlacementRecord:
		failures.append("resource mining execution requires UndergroundPlacementRecord")
	elif ticket != null and ticket is Ticket:
		if ticket.placement_stable_id() != placement.placement_stable_id:
			failures.append("resource mining ticket placement StableId is stale or mismatched")
		if ticket.placement_fingerprint() != placement.placement_fingerprint:
			failures.append("resource mining ticket placement fingerprint is stale or mismatched")
		if ticket.resource_content_id() != placement.target_content_id:
			failures.append("resource mining ticket resource ContentId is stale or mismatched")
		for freshness_failure in _cell_entry_failures(current_cell_entry, placement):
			failures.append(freshness_failure)
		if str(current_cell_entry.get("cell_address", "")) != ticket.cell_address():
			failures.append("resource mining ticket owner cell address is stale")
		if int(current_cell_entry.get("generation", 0)) != ticket.cell_generation():
			failures.append("resource mining ticket owner cell generation is stale")
		if str(current_cell_entry.get("source_fingerprint", "")) != ticket.cell_source_fingerprint():
			failures.append("resource mining ticket owner cell source fingerprint is stale")
		if str(current_cell_entry.get("provenance_fingerprint", "")) != ticket.cell_provenance_fingerprint():
			failures.append("resource mining ticket owner cell provenance fingerprint is stale")
	if not failures.is_empty():
		return _failure(failures)

	return RuntimeService.new().mine(
		placement,
		content_registry,
		equipment_state,
		inventory,
		delta_store,
		ticket.operation_id()
	)


static func _cell_entry_failures(entry: Dictionary, placement) -> Array[String]:
	var failures: Array[String] = []
	var cell_address_variant = entry.get("cell_address", null)
	if not cell_address_variant is String or cell_address_variant.is_empty() or not cell_address_variant.begins_with("gcell1:"):
		failures.append("resource mining requires current owner cell address")
	var generation_variant = entry.get("generation", null)
	if typeof(generation_variant) != TYPE_INT or int(generation_variant) <= 0:
		failures.append("resource mining requires positive current owner cell generation")
	for fingerprint_key in ["source_fingerprint", "provenance_fingerprint"]:
		var fingerprint_variant = entry.get(fingerprint_key, null)
		if not fingerprint_variant is String or fingerprint_variant.is_empty() or fingerprint_variant != fingerprint_variant.strip_edges():
			failures.append("resource mining requires current owner cell %s" % fingerprint_key)
	if not bool(entry.get("collision_ready", false)):
		failures.append("resource mining requires current owner cell collision readiness")

	var placements_variant = entry.get("placements", null)
	if not placements_variant is Array:
		failures.append("resource mining requires current owner cell placements")
		return failures
	var matched: bool = false
	for candidate in placements_variant:
		if candidate == null or not candidate is UndergroundPlacementRecord:
			continue
		if placement == null or not placement is UndergroundPlacementRecord:
			continue
		if candidate.placement_stable_id != placement.placement_stable_id:
			continue
		matched = true
		if candidate.placement_fingerprint != placement.placement_fingerprint:
			failures.append("current owner cell placement fingerprint does not match mining placement")
		if candidate.target_content_id != placement.target_content_id:
			failures.append("current owner cell resource ContentId does not match mining placement")
		break
	if not matched:
		failures.append("resource mining placement is not resident in current owner cell")
	failures.sort()
	return failures


static func _operation_id(placement_stable_id: String, ordinal: int) -> String:
	var placement_id = StableId.parse(placement_stable_id)
	if placement_id == null or ordinal <= 0:
		return ""
	var operation_address = placement_id.address().child([
		"operation",
		"resource.mine",
		"ordinal",
		str(ordinal),
	])
	var operation_id = StableId.from_address(operation_address)
	return "" if operation_id == null else operation_id.value()


static func _failure(failures: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for failure in failures:
		diagnostics.append(str(failure))
	diagnostics.sort()
	return {
		"success": false,
		"ticket": null,
		"diagnostics": diagnostics,
	}
