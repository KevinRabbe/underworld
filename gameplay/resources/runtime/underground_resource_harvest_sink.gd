extends RefCounted
class_name UndergroundResourceHarvestSink

const UndergroundPlacementRecord := preload("res://content/placement/underground_placement_record.gd")
const ResidencyService := preload("res://gameplay/resources/runtime/underground_resource_residency_service.gd")
const ActionService := preload("res://gameplay/resources/runtime/underground_resource_action_service.gd")
const MiningTicket := preload("res://gameplay/resources/runtime/underground_resource_mining_ticket.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")

const INTERACTION_GROUP: StringName = &"archetype_role:interaction.primary"
# Current accepted physical compatibility only. #509 owns the later semantic
# query-mask migration; this sink intentionally performs one target-aware first
# hit through current world + resource bodies instead of inventing another mask
# authority inside #374.
const CURRENT_WORLD_LAYER: int = 1
const CURRENT_RESOURCE_LAYER: int = 2
const HARVEST_QUERY_MASK: int = CURRENT_WORLD_LAYER | CURRENT_RESOURCE_LAYER

var _query_owner: Node3D = null
var _self_exclusion: CollisionObject3D = null
var _residency = null
var _action_service = null
var _content_registry = null
var _delta_store = null
var _activation_enabled: bool = false


## Domain-internal action sink only. A final composition owner (#404) decides
## when this sink is enabled and whether Player.harvest_requested routes here.
## The sink never subscribes to Player, inspects active_domain, or infers domain
## authority from coordinates/runtime presence.
func configure(
	query_owner,
	residency,
	action_service,
	content_registry,
	delta_store,
	self_exclusion = null
) -> Array[String]:
	dispose()
	var failures: Array[String] = []
	if query_owner == null or not query_owner is Node3D:
		failures.append("resource harvest sink requires Node3D physics query owner")
	if residency == null or not residency is ResidencyService:
		failures.append("resource harvest sink requires UndergroundResourceResidencyService")
	if action_service == null or not action_service is ActionService:
		failures.append("resource harvest sink requires UndergroundResourceActionService")
	if content_registry == null or not content_registry.has_method("resolve"):
		failures.append("resource harvest sink requires ContentRegistry-compatible resolver")
	if delta_store == null or not delta_store is WorldDeltaStore:
		failures.append("resource harvest sink requires WorldDeltaStore")
	if self_exclusion != null and not self_exclusion is CollisionObject3D:
		failures.append("resource harvest sink self exclusion must be CollisionObject3D")
	if not failures.is_empty():
		failures.sort()
		return failures

	_query_owner = query_owner
	_self_exclusion = self_exclusion
	_residency = residency
	_action_service = action_service
	_content_registry = content_registry
	_delta_store = delta_store
	return []


func dispose() -> void:
	_activation_enabled = false
	_query_owner = null
	_self_exclusion = null
	_residency = null
	_action_service = null
	_content_registry = null
	_delta_store = null


func set_activation_enabled(enabled: bool) -> Array[String]:
	if enabled and (
		_query_owner == null
		or _residency == null
		or _action_service == null
		or _content_registry == null
		or _delta_store == null
	):
		_activation_enabled = false
		return ["resource harvest sink cannot activate before valid configuration"]
	_activation_enabled = enabled
	return []


func activation_enabled() -> bool:
	return _activation_enabled


## Resolves the supplied Player/camera action ray into one immutable mining
## ticket. The first hit must itself be the current resource interaction body;
## stable world collision in front therefore occludes the resource naturally.
func prepare_harvest(origin: Vector3, direction: Vector3, max_distance: float) -> Dictionary:
	if not _activation_enabled:
		return _failure(["resource harvest sink is inactive"], false)
	if _query_owner == null or not is_instance_valid(_query_owner):
		return _failure(["resource harvest sink query owner is unavailable"], false)
	if not _finite_vector3(origin) or not _finite_vector3(direction):
		return _failure(["resource harvest ray requires finite origin and direction"], false)
	if direction.is_zero_approx():
		return _failure(["resource harvest ray direction must be non-zero"], false)
	if not is_finite(max_distance) or max_distance <= 0.0:
		return _failure(["resource harvest ray distance must be finite and positive"], false)
	var world = _query_owner.get_world_3d()
	if world == null:
		return _failure(["resource harvest sink has no current World3D"], false)

	var ray_end: Vector3 = origin + direction.normalized() * max_distance
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin,
		ray_end,
		HARVEST_QUERY_MASK
	)
	if _self_exclusion != null and is_instance_valid(_self_exclusion):
		query.exclude = [_self_exclusion.get_rid()]
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return _failure(["resource harvest ray missed"], false)
	var collider = hit.get("collider", null)
	if collider == null or not collider is CollisionObject3D:
		return _failure(["resource harvest ray first hit is not CollisionObject3D"], false)
	if not collider.is_in_group(INTERACTION_GROUP):
		return _failure(["resource harvest ray first hit is not resource interaction.primary"], false)

	var target: Dictionary = _current_target_from_collider(collider)
	if not bool(target.get("success", false)):
		return target
	var prepared: Dictionary = _action_service.prepare_mining(
		str(target.get("cell_address", "")),
		str(target.get("placement_stable_id", "")),
		_content_registry,
		_delta_store
	)
	if not bool(prepared.get("success", false)):
		return _failure(prepared.get("diagnostics", []), true)
	var ticket = prepared.get("ticket", null)
	if ticket == null or not ticket is MiningTicket:
		return _failure(["resource harvest preparation returned no immutable mining ticket"], true)
	return {
		"success": true,
		"handled": true,
		"ticket": ticket,
		"placement_stable_id": ticket.placement_stable_id(),
		"cell_address": ticket.cell_address(),
		"diagnostics": [],
	}


## Commit revalidates the immutable ticket against current residency through the
## existing ActionService/TicketService before RuntimeService may mutate either
## Inventory or WorldDelta. Disabling the sink between prepare and execute also
## fails closed, which is the domain-transition seam final #404 can own.
func execute_prepared(ticket, equipment_state, inventory) -> Dictionary:
	if not _activation_enabled:
		return _failure(["resource harvest sink became inactive before commit"], true)
	var result: Dictionary = _action_service.execute_mining(
		ticket,
		_content_registry,
		equipment_state,
		inventory,
		_delta_store
	)
	var response: Dictionary = result.duplicate(true)
	response["handled"] = true
	if not response.has("diagnostics"):
		response["diagnostics"] = []
	return response


func try_harvest(
	origin: Vector3,
	direction: Vector3,
	max_distance: float,
	equipment_state,
	inventory
) -> Dictionary:
	var prepared: Dictionary = prepare_harvest(origin, direction, max_distance)
	if not bool(prepared.get("success", false)):
		return prepared
	return execute_prepared(prepared.get("ticket", null), equipment_state, inventory)


func _current_target_from_collider(collider: CollisionObject3D) -> Dictionary:
	var required_meta: Array[String] = [
		"placement_stable_id",
		"placement_fingerprint",
		"resource_content_id",
		"resource_cell_address",
		"resource_cell_generation",
		"resource_source_fingerprint",
		"resource_provenance_fingerprint",
	]
	for key in required_meta:
		if not collider.has_meta(key):
			return _failure(["resource interaction body is missing runtime identity metadata: %s" % key], true)

	var placement_stable_id: String = str(collider.get_meta("placement_stable_id", ""))
	var placement_fingerprint: String = str(collider.get_meta("placement_fingerprint", ""))
	var resource_content_id: String = str(collider.get_meta("resource_content_id", ""))
	var cell_address: String = str(collider.get_meta("resource_cell_address", ""))
	var cell_generation: int = int(collider.get_meta("resource_cell_generation", 0))
	var source_fingerprint: String = str(collider.get_meta("resource_source_fingerprint", ""))
	var provenance_fingerprint: String = str(collider.get_meta("resource_provenance_fingerprint", ""))
	if (
		placement_stable_id.is_empty()
		or placement_fingerprint.is_empty()
		or resource_content_id.is_empty()
		or cell_address.is_empty()
		or cell_generation <= 0
		or source_fingerprint.is_empty()
		or provenance_fingerprint.is_empty()
	):
		return _failure(["resource interaction body has malformed runtime identity metadata"], true)

	var entry: Dictionary = _residency.semantic_entry(cell_address)
	if entry.is_empty():
		return _failure(["resource interaction owner cell is no longer resident"], true)
	if not bool(entry.get("collision_ready", false)):
		return _failure(["resource interaction owner cell collision is no longer current"], true)
	if int(entry.get("generation", 0)) != cell_generation:
		return _failure(["resource interaction body cell generation is stale"], true)
	if str(entry.get("source_fingerprint", "")) != source_fingerprint:
		return _failure(["resource interaction body source fingerprint is stale"], true)
	if str(entry.get("provenance_fingerprint", "")) != provenance_fingerprint:
		return _failure(["resource interaction body provenance fingerprint is stale"], true)

	var placements_variant = entry.get("placements", null)
	if not placements_variant is Array:
		return _failure(["resource interaction owner cell has no current placement list"], true)
	var matched = null
	for placement in placements_variant:
		if placement == null or not placement is UndergroundPlacementRecord:
			continue
		if placement.placement_stable_id == placement_stable_id:
			matched = placement
			break
	if matched == null:
		return _failure(["resource interaction placement is no longer current"], true)
	if matched.placement_fingerprint != placement_fingerprint:
		return _failure(["resource interaction placement fingerprint is stale"], true)
	if matched.target_content_id != resource_content_id:
		return _failure(["resource interaction ContentId is stale"], true)

	return {
		"success": true,
		"handled": true,
		"placement_stable_id": placement_stable_id,
		"cell_address": cell_address,
		"diagnostics": [],
	}


static func _finite_vector3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


static func _failure(failures: Array, handled: bool) -> Dictionary:
	var diagnostics: Array[String] = []
	for failure in failures:
		diagnostics.append(str(failure))
	diagnostics.sort()
	return {
		"success": false,
		"handled": handled,
		"ticket": null,
		"diagnostics": diagnostics,
	}
