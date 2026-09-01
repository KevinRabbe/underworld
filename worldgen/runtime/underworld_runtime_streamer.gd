extends RefCounted
class_name UnderworldRuntimeStreamer

const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")
const Record := preload("res://worldgen/runtime/runtime_cell_record.gd")
const Request := preload("res://worldgen/runtime/runtime_cell_request.gd")
const Result := preload("res://worldgen/runtime/runtime_cell_result.gd")

const TIERS: Array[String] = ["definition", "fragment_plan", "voxel_geometry", "render", "collision", "simulation"]

signal tier_retired(address, tier: String)

var cell_size: Vector3 = Vector3(32, 32, 32)
var definition_activate_radius: int = 3
var definition_release_radius: int = 4
var geometry_activate_radius: int = 2
var geometry_release_radius: int = 3
var render_activate_radius: int = 1
var render_release_radius: int = 2
var collision_activate_radius: int = 1
var collision_release_radius: int = 2
var max_active_voxel_workers: int = 2
var world_id: String = ""
var generator_manifest_id: String = ""
# Runtime-only current relevance. Fully retired cells are erased; deterministic
# generation/persistence remains the authority for reconstructing them later.
var records: Dictionary = {}
# The executor strongly retains this streamer while it is active. Keep the
# reverse edge weak so controller-owned runtime objects cannot form a RefCounted
# cycle across teardown/reconfigure.
var _executor_ref: WeakRef = null
var executor:
	get:
		return _executor_ref.get_ref() if _executor_ref != null else null
	set(value):
		_executor_ref = weakref(value) if value != null else null
var stale_result_count: int = 0
var released_count: int = 0
var queued_count: int = 0
var last_observer_record_scan_count: int = 0
var _next_generation_token: int = 1


func _init(world_id_value: String = "", manifest_id_value: String = "", executor_value = null) -> void:
	world_id = world_id_value
	generator_manifest_id = manifest_id_value
	executor = executor_value


func demand_cell(address, source: String, tiers: Array, source_fingerprint: String = "", provenance_fingerprint: String = ""):
	var record = _ensure_record(address)
	var identity_changed: bool = (not source_fingerprint.is_empty() and not record.source_fingerprint.is_empty() and source_fingerprint != record.source_fingerprint) or (not provenance_fingerprint.is_empty() and not record.provenance_fingerprint.is_empty() and provenance_fingerprint != record.provenance_fingerprint)
	if identity_changed:
		_invalidate_generation(record)
	var lease: Dictionary = record.demands.get(source, {})
	for tier in tiers:
		var tier_name := str(tier)
		if not TIERS.has(tier_name):
			continue
		lease[tier_name] = int(lease.get(tier_name, 0)) + 1
	if lease.is_empty():
		record.demands.erase(source)
	else:
		record.demands[source] = lease
	record.release_pending = false
	if not source_fingerprint.is_empty():
		record.source_fingerprint = source_fingerprint
	if not provenance_fingerprint.is_empty():
		record.provenance_fingerprint = provenance_fingerprint
	if record.state == "dormant":
		record.state = "requested"
	_queue_if_needed(record)
	return record


func set_demand(address, source: String, tiers: Array, source_fingerprint: String = "", provenance_fingerprint: String = ""):
	# Normalize the desired lease before acquiring runtime ownership. An empty
	# desired state is a release/no-op and must never recreate an evicted record.
	var lease: Dictionary = {}
	for tier in tiers:
		var tier_name := str(tier)
		if TIERS.has(tier_name):
			lease[tier_name] = 1
	var record = _lookup_record(address)
	if lease.is_empty():
		if record == null:
			return null
		if record.demands.has(source):
			record.demands.erase(source)
			_retire_undemanded_tiers(record)
		if record.demands.is_empty():
			record.release_pending = true
			record.state = "release_pending"
			release_cell(record.cell_address)
			return record
		record.release_pending = false
		_queue_if_needed(record)
		return record
	if record == null:
		record = _ensure_record(address)
	var identity_changed: bool = (not source_fingerprint.is_empty() and not record.source_fingerprint.is_empty() and source_fingerprint != record.source_fingerprint) or (not provenance_fingerprint.is_empty() and not record.provenance_fingerprint.is_empty() and provenance_fingerprint != record.provenance_fingerprint)
	if identity_changed:
		_invalidate_generation(record)
	record.demands[source] = lease
	record.release_pending = false
	if not source_fingerprint.is_empty():
		record.source_fingerprint = source_fingerprint
	if not provenance_fingerprint.is_empty():
		record.provenance_fingerprint = provenance_fingerprint
	if record.state == "dormant":
		record.state = "requested"
	if not identity_changed:
		_retire_undemanded_tiers(record)
	_queue_if_needed(record)
	return record


func release_demand(address, source: String, tiers: Array = []) -> bool:
	# Release is deliberately non-creating. A stale/duplicate release for an
	# already-evicted cell must not manufacture historical runtime state.
	var record = _lookup_record(address)
	if record == null or not record.demands.has(source):
		return false
	var lease: Dictionary = record.demands[source]
	if tiers.is_empty():
		record.demands.erase(source)
	else:
		for tier in tiers:
			var tier_name := str(tier)
			if lease.has(tier_name):
				lease[tier_name] = maxi(0, int(lease[tier_name]) - 1)
				if lease[tier_name] == 0:
					lease.erase(tier_name)
		if lease.is_empty():
			record.demands.erase(source)
	_retire_undemanded_tiers(record)
	if record.demands.is_empty():
		record.release_pending = true
		record.state = "release_pending"
		# Generation invalidation above makes old work stale. Retire immediately;
		# tier_retired signals synchronously dispose realized Nodes/RIDs.
		return release_cell(record.cell_address)
	record.release_pending = false
	_queue_if_needed(record)
	return true


func pin_entrance(address, pin_id: String, tiers: Array, source_fingerprint: String = "", provenance_fingerprint: String = ""):
	return demand_cell(address, "entrance:" + pin_id, tiers, source_fingerprint, provenance_fingerprint)


func release_entrance(address, pin_id: String, tiers: Array = []) -> bool:
	return release_demand(address, "entrance:" + pin_id, tiers)


func update_observer(position: Vector3, source: String = "player") -> void:
	var center := observer_cell(position)
	for x in range(center.x - definition_activate_radius, center.x + definition_activate_radius + 1):
		for y in range(center.y - definition_activate_radius, center.y + definition_activate_radius + 1):
			for z in range(center.z - definition_activate_radius, center.z + definition_activate_radius + 1):
				var coordinate := Vector3i(x, y, z)
				var distance := _cell_distance(center, coordinate)
				var address := Address.new(coordinate)
				var record = records.get(address.canonical_text())
				var tiers: Array[String] = _observer_tiers(record, distance)
				set_demand(address, source, tiers)

	# records is a bounded current-relevance table. Duplicate the current values
	# because release may evict entries synchronously during this pass.
	var current_records: Array = records.values().duplicate()
	last_observer_record_scan_count = current_records.size()
	for record in current_records:
		if record == null or not records.has(record.key) or not record.demands.has(source):
			continue
		var distance := _cell_distance(center, record.cell_address.coordinate)
		var release_tiers: Array[String] = []
		if distance > render_release_radius:
			release_tiers.append("render")
		if distance > collision_release_radius:
			release_tiers.append("collision")
		if distance > geometry_release_radius:
			release_tiers.append_array(["fragment_plan", "voxel_geometry"])
		if distance > definition_release_radius:
			release_tiers.append("definition")
		if not release_tiers.is_empty():
			release_demand(record.cell_address, source, release_tiers)


func accept_result(result) -> bool:
	if result == null or not (result is Result):
		stale_result_count += 1
		return false
	# Result acceptance is deliberately non-creating. Late work for an evicted
	# incarnation is stale and cannot resurrect the record table.
	var record = _lookup_record(result.cell_address)
	if record == null:
		stale_result_count += 1
		return false
	if result.world_id.is_empty() or result.generator_manifest_id.is_empty() or result.source_fingerprint.is_empty() or result.provenance_fingerprint.is_empty():
		stale_result_count += 1
		return false
	if result.generation != record.generation or record.release_pending:
		stale_result_count += 1
		return false
	if result.world_id != world_id or result.generator_manifest_id != generator_manifest_id:
		stale_result_count += 1
		return false
	if record.source_fingerprint.is_empty() or record.provenance_fingerprint.is_empty():
		stale_result_count += 1
		return false
	if record.demands.is_empty() or record.demand_count(result.tier) <= 0:
		stale_result_count += 1
		return false
	if result.source_fingerprint != record.source_fingerprint:
		stale_result_count += 1
		return false
	if result.provenance_fingerprint != record.provenance_fingerprint:
		stale_result_count += 1
		return false
	if not TIERS.has(result.tier):
		stale_result_count += 1
		return false
	if result.tier == "collision" and result.payload == null:
		stale_result_count += 1
		return false
	if result.tier == "collision" and not (result.payload is ConcavePolygonShape3D):
		stale_result_count += 1
		return false
	record.queued[result.tier] = false
	if not result.success:
		record.diagnostics.append_array(result.diagnostics)
		record.state = "failed"
		return false
	record.readiness[result.tier] = true
	if result.tier == "collision":
		record.collision_handle = result.payload
	_update_state(record)
	# Frontier scheduling: accepting one dependency exposes only the newly-ready
	# next tier(s), rather than retaining blocked jobs in a historical backlog.
	_queue_if_needed(record)
	return true


func release_cell(address) -> bool:
	# Release is deliberately non-creating.
	var record = _lookup_record(address)
	if record == null:
		return false
	if not record.demands.is_empty():
		return false
	_advance_generation(record)
	_cancel_record_work(record)
	_emit_realized_tier_retirements(record, true)
	record.release_pending = false
	record.runtime_handle = null
	record.collision_handle = null
	record.readiness = _empty_readiness()
	record.queued.clear()
	record.state = "dormant"
	released_count += 1
	# The record has no durable authority. Remove it so ordinary work remains
	# proportional to current relevance; deterministic truth reconstructs it.
	records.erase(record.key)
	return true


func reconfigure(world_id_value: String, manifest_id_value: String) -> void:
	world_id = world_id_value
	generator_manifest_id = manifest_id_value
	for record in records.values():
		_advance_generation(record)
		_cancel_record_work(record)
		_emit_realized_tier_retirements(record, true)
		record.runtime_handle = null
		record.collision_handle = null
		record.readiness = _empty_readiness()
		record.queued.clear()
		record.release_pending = false
		record.state = "requested" if not record.demands.is_empty() else "dormant"
		_queue_if_needed(record)
	# Defensive cleanup for any record that was already fully unowned.
	for key in current_record_keys():
		var record = records.get(key, null)
		if record != null and record.demands.is_empty():
			release_cell(record.cell_address)


func observer_cell(position: Vector3) -> Vector3i:
	return Vector3i(floori(position.x / cell_size.x), floori(position.y / cell_size.y), floori(position.z / cell_size.z))


func active_owner_count() -> int:
	# records contains only current-relevance ownership after dormant eviction.
	return records.size()


func current_record_keys() -> Array[String]:
	var result: Array[String] = []
	for raw_key in records.keys():
		result.append(str(raw_key))
	result.sort()
	return result


func current_record_addresses() -> Array:
	var result: Array = []
	for key in current_record_keys():
		var record = records.get(key, null)
		if record != null:
			result.append(record.cell_address)
	return result


func release_pending_record_keys() -> Array[String]:
	var result: Array[String] = []
	for key in current_record_keys():
		var record = records.get(key, null)
		if record != null and record.release_pending:
			result.append(key)
	return result


func _ensure_record(address):
	if address == null:
		return null
	var key: String = address.canonical_text()
	if not records.has(key):
		var record = Record.new(address)
		record.generation = _allocate_generation_token()
		records[key] = record
	return records[key]


func _lookup_record(address):
	if address == null:
		return null
	return records.get(address.canonical_text(), null)


func _allocate_generation_token() -> int:
	var token: int = _next_generation_token
	_next_generation_token += 1
	if _next_generation_token <= 0:
		# Runtime sessions will never realistically approach int64 exhaustion, but
		# fail closed instead of silently reusing an old token after overflow.
		push_error("Underworld runtime generation token allocator overflowed")
		_next_generation_token = 1
	return token


func _advance_generation(record) -> void:
	record.generation = _allocate_generation_token()


func _invalidate_generation(record) -> void:
	_advance_generation(record)
	_cancel_record_work(record)
	_emit_realized_tier_retirements(record, false)
	record.readiness = _empty_readiness()
	record.queued.clear()
	record.runtime_handle = null
	record.collision_handle = null
	record.release_pending = false
	record.state = "requested"


func _retire_undemanded_tiers(record) -> void:
	var retired: Array[String] = []
	for tier in TIERS:
		if record.demand_count(tier) > 0:
			continue
		if bool(record.readiness.get(tier, false)) or bool(record.queued.get(tier, false)) or (tier == "render" and record.runtime_handle != null) or (tier == "collision" and record.collision_handle != null):
			retired.append(tier)
	if retired.is_empty():
		return
	# Generation is cell-scoped. A new opaque incarnation token invalidates all
	# in-flight work without retaining per-address tombstones after eviction.
	# Executor cancellation also drops generation-keyed mesh artifacts. If the
	# cell still demands voxel geometry, invalidate that readiness so the normal
	# dependency frontier rebuilds a mesh for this new generation before a later
	# render/collision reacquisition can run.
	var rebuild_voxel_artifact: bool = (
		record.demand_count("voxel_geometry") > 0
		and bool(record.readiness.get("voxel_geometry", false))
	)
	_advance_generation(record)
	_cancel_record_work(record)
	record.queued.clear()
	if rebuild_voxel_artifact:
		record.readiness["voxel_geometry"] = false
	for tier in retired:
		var was_realized: bool = bool(record.readiness.get(tier, false)) or (tier == "render" and record.runtime_handle != null) or (tier == "collision" and record.collision_handle != null)
		record.readiness[tier] = false
		if tier == "render":
			record.runtime_handle = null
		elif tier == "collision":
			record.collision_handle = null
		if was_realized and tier in ["render", "collision"]:
			tier_retired.emit(record.cell_address, tier)
	_update_state(record)
	_queue_if_needed(record)


func _cancel_record_work(record) -> void:
	if executor != null and executor.has_method("cancel_record"):
		executor.call("cancel_record", record.key)


func _emit_realized_tier_retirements(record, emit_even_if_not_ready: bool) -> void:
	for tier in ["render", "collision"]:
		var realized: bool = bool(record.readiness.get(tier, false)) or (tier == "render" and record.runtime_handle != null) or (tier == "collision" and record.collision_handle != null)
		if realized or emit_even_if_not_ready:
			tier_retired.emit(record.cell_address, tier)


func _empty_readiness() -> Dictionary:
	return {"definition": false, "fragment_plan": false, "voxel_geometry": false, "render": false, "collision": false, "simulation": false}


func _queue_if_needed(record) -> void:
	var tiers: Array = record.demanded_tiers()
	if tiers.is_empty():
		return
	# Observer demand may establish desired tiers before the definition service
	# binds authoritative source/provenance identity. Never queue unbound work.
	if record.source_fingerprint.is_empty() or record.provenance_fingerprint.is_empty():
		return
	if executor == null or not executor.has_method("submit"):
		return
	var request := Request.new(record.cell_address, record.generation, tiers, record.source_fingerprint, record.provenance_fingerprint, world_id, generator_manifest_id)
	for tier in tiers:
		if record.readiness.get(tier, false) or record.queued.get(tier, false):
			continue
		if not _tier_dependencies_ready(record, tier):
			continue
		var submit_result: Variant = executor.call("submit", request, tier)
		if submit_result is bool and not bool(submit_result):
			continue
		record.queued[tier] = true
		queued_count += 1


func _tier_dependencies_ready(record, tier: String) -> bool:
	match tier:
		"definition":
			return true
		"fragment_plan":
			return bool(record.readiness.get("definition", false))
		"voxel_geometry":
			return bool(record.readiness.get("definition", false)) and bool(record.readiness.get("fragment_plan", false))
		"render", "collision":
			return bool(record.readiness.get("voxel_geometry", false))
		"simulation":
			return false
	return false


func _update_state(record) -> void:
	if record.state == "failed":
		return
	if record.readiness.get("render", false):
		record.state = "render_ready"
	elif record.readiness.get("voxel_geometry", false):
		record.state = "geometry_ready"
	elif record.readiness.get("fragment_plan", false):
		record.state = "fragment_plan_ready"
	elif record.readiness.get("definition", false):
		record.state = "definition_ready"
	else:
		record.state = "requested"


func _cell_distance(a: Vector3i, b: Vector3i) -> int:
	return maxi(abs(a.x - b.x), maxi(abs(a.y - b.y), abs(a.z - b.z)))


func _observer_tiers(record, distance: int) -> Array[String]:
	var tiers: Array[String] = ["definition"]
	if distance <= geometry_activate_radius:
		tiers.append("fragment_plan")
		tiers.append("voxel_geometry")
	if distance <= render_activate_radius:
		tiers.append("render")
	if distance <= collision_activate_radius:
		tiers.append("collision")
	if record != null:
		if distance <= geometry_release_radius and record.demand_count("fragment_plan") > 0:
			tiers.append("fragment_plan")
		if distance <= geometry_release_radius and record.demand_count("voxel_geometry") > 0:
			tiers.append("voxel_geometry")
		if distance <= render_release_radius and record.demand_count("render") > 0:
			tiers.append("render")
		if distance <= collision_release_radius and record.demand_count("collision") > 0:
			tiers.append("collision")
		if distance <= definition_release_radius and record.demand_count("definition") > 0:
			tiers.append("definition")
	var unique: Dictionary = {}
	var result: Array[String] = []
	for tier in tiers:
		if not unique.has(tier):
			unique[tier] = true
			result.append(tier)
	return result