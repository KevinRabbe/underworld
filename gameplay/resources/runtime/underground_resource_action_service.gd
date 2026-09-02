extends RefCounted
class_name UndergroundResourceActionService

const UndergroundPlacementRecord := preload("res://content/placement/underground_placement_record.gd")
const ResidencyService := preload("res://gameplay/resources/runtime/underground_resource_residency_service.gd")
const MiningTicket := preload("res://gameplay/resources/runtime/underground_resource_mining_ticket.gd")
const MiningTicketService := preload("res://gameplay/resources/runtime/underground_resource_mining_ticket_service.gd")

var _residency = null
var _ticket_service = MiningTicketService.new()


## Resource-side action seam only. Parent Game/#404 remains responsible for
## choosing the Underworld action sink; this service never subscribes to Player
## input and never infers active domain from coordinates or Nodes.
func configure(residency) -> Array[String]:
	_residency = null
	var failures: Array[String] = []
	if residency == null or not residency is ResidencyService:
		failures.append("resource action service requires UndergroundResourceResidencyService")
		return failures
	_residency = residency
	return failures


func prepare_mining(
	cell_address: String,
	placement_stable_id: String,
	content_registry,
	delta_store
) -> Dictionary:
	var target: Dictionary = _current_target(cell_address, placement_stable_id, true)
	if not bool(target.get("success", false)):
		return target
	return _ticket_service.prepare_ticket(
		target.get("placement", null),
		content_registry,
		delta_store,
		target.get("entry", {})
	)


func execute_mining(
	ticket,
	content_registry,
	equipment_state,
	inventory,
	delta_store
) -> Dictionary:
	if ticket == null or not ticket is MiningTicket:
		return _failure(["resource action execution requires UndergroundResourceMiningTicket"])
	var target: Dictionary = _current_target(
		ticket.cell_address(),
		ticket.placement_stable_id(),
		true
	)
	if not bool(target.get("success", false)):
		return target
	return _ticket_service.execute_ticket(
		ticket,
		target.get("placement", null),
		content_registry,
		equipment_state,
		inventory,
		delta_store,
		target.get("entry", {})
	)


## Depletion is restored before later realization composition can create a Node.
## This result is not domain authority: callers still require current collision
## and final committed active-domain permission before interactive realization.
func inspect_current_placement_state(
	cell_address: String,
	placement_stable_id: String,
	content_registry,
	delta_store
) -> Dictionary:
	var target: Dictionary = _current_target(cell_address, placement_stable_id, false)
	if not bool(target.get("success", false)):
		return target
	var inspected: Dictionary = _ticket_service.inspect_realization_state(
		target.get("placement", null),
		content_registry,
		delta_store
	)
	if not bool(inspected.get("success", false)):
		return inspected
	var entry: Dictionary = target.get("entry", {})
	inspected["collision_ready"] = bool(entry.get("collision_ready", false))
	inspected["cell_generation"] = int(entry.get("generation", 0))
	return inspected


func _current_target(
	cell_address: String,
	placement_stable_id: String,
	require_collision: bool
) -> Dictionary:
	if _residency == null:
		return _failure(["resource action service is not configured"])
	if cell_address.is_empty() or cell_address != cell_address.strip_edges():
		return _failure(["resource action requires canonical current cell address"])
	if placement_stable_id.is_empty() or placement_stable_id != placement_stable_id.strip_edges():
		return _failure(["resource action requires exact placement StableId"])
	var entry: Dictionary = _residency.semantic_entry(cell_address)
	if entry.is_empty():
		return _failure(["resource action owner cell is not currently resident"])
	if require_collision and not bool(entry.get("collision_ready", false)):
		return _failure(["resource action owner cell collision is not current"])
	var placements_variant = entry.get("placements", null)
	if not placements_variant is Array:
		return _failure(["resource action current cell has no semantic placement list"])
	for candidate in placements_variant:
		if candidate == null or not candidate is UndergroundPlacementRecord:
			continue
		if candidate.placement_stable_id == placement_stable_id:
			return {
				"success": true,
				"entry": entry,
				"placement": candidate,
				"diagnostics": [],
			}
	return _failure(["resource action placement is not current in owner cell"])


static func _failure(failures: Array) -> Dictionary:
	var diagnostics: Array[String] = []
	for failure in failures:
		diagnostics.append(str(failure))
	diagnostics.sort()
	return {
		"success": false,
		"entry": {},
		"placement": null,
		"diagnostics": diagnostics,
	}
