extends RefCounted
class_name UnderworldRuntimeStreamer

const Address := preload("res://worldgen/geometry/geometry_cell_address.gd")
const Record := preload("res://worldgen/runtime/runtime_cell_record.gd")
const Request := preload("res://worldgen/runtime/runtime_cell_request.gd")
const Result := preload("res://worldgen/runtime/runtime_cell_result.gd")

const TIERS: Array[String] = ["definition", "fragment_plan", "voxel_geometry", "render", "collision", "simulation"]

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
var records: Dictionary = {}
var executor = null
var stale_result_count: int = 0
var released_count: int = 0
var queued_count: int = 0


func _init(world_id_value: String = "", manifest_id_value: String = "", executor_value = null) -> void:
	world_id = world_id_value
	generator_manifest_id = manifest_id_value
	executor = executor_value


func demand_cell(address, source: String, tiers: Array, source_fingerprint: String = "", provenance_fingerprint: String = ""):
	var record = _record(address)
	var identity_changed: bool = (not source_fingerprint.is_empty() and not record.source_fingerprint.is_empty() and source_fingerprint != record.source_fingerprint) or (not provenance_fingerprint.is_empty() and not record.provenance_fingerprint.is_empty() and provenance_fingerprint != record.provenance_fingerprint)
	if identity_changed:
		_invalidate_generation(record)
	var lease: Dictionary = record.demands.get(source, {})
	for tier in tiers:
		var tier_name := str(tier)
		if not TIERS.has(tier_name):
			continue
		lease[tier_name] = int(lease.get(tier_name, 0)) + 1
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
	var record = _record(address)
	var identity_changed: bool = (not source_fingerprint.is_empty() and not record.source_fingerprint.is_empty() and source_fingerprint != record.source_fingerprint) or (not provenance_fingerprint.is_empty() and not record.provenance_fingerprint.is_empty() and provenance_fingerprint != record.provenance_fingerprint)
	if identity_changed:
		_invalidate_generation(record)
	var lease: Dictionary = {}
	for tier in tiers:
		var tier_name := str(tier)
		if TIERS.has(tier_name):
			lease[tier_name] = 1
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


func release_demand(address, source: String, tiers: Array = []) -> bool:
	var record = _record(address)
	if not record.demands.has(source):
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
	if record.demands.is_empty():
		record.release_pending = true
		record.generation += 1
		record.state = "release_pending"
		record.queued.clear()
	else:
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
				var tiers: Array[String] = ["definition"]
				if distance <= geometry_activate_radius:
					tiers.append("fragment_plan")
					tiers.append("voxel_geometry")
				if distance <= render_activate_radius:
					tiers.append("render")
				if distance <= collision_activate_radius:
					tiers.append("collision")
				set_demand(Address.new(coordinate), source, tiers)
	for record in records.values():
		if not record.demands.has(source):
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
	var record = _record(result.cell_address)
	if result.world_id.is_empty() or result.generator_manifest_id.is_empty() or result.source_fingerprint.is_empty() or result.provenance_fingerprint.is_empty():
		stale_result_count += 1
		return false
	if result.generation != record.generation or record.release_pending:
		stale_result_count += 1
		return false
	if result.world_id != world_id or result.generator_manifest_id != generator_manifest_id:
		stale_result_count += 1
		return false
	if record.demands.is_empty() or record.demand_count(result.tier) <= 0:
		stale_result_count += 1
		return false
	if not record.source_fingerprint.is_empty() and result.source_fingerprint != record.source_fingerprint:
		stale_result_count += 1
		return false
	if not record.provenance_fingerprint.is_empty() and result.provenance_fingerprint != record.provenance_fingerprint:
		stale_result_count += 1
		return false
	if not TIERS.has(result.tier):
		stale_result_count += 1
		return false
	if result.tier == "collision" and result.payload == null:
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
	return true


func release_cell(address) -> bool:
	var record = _record(address)
	if not record.demands.is_empty():
		return false
	record.generation += 1
	record.release_pending = true
	record.runtime_handle = null
	record.collision_handle = null
	record.readiness = {"definition": false, "fragment_plan": false, "voxel_geometry": false, "render": false, "collision": false, "simulation": false}
	record.queued.clear()
	record.state = "dormant"
	released_count += 1
	return true


func reconfigure(world_id_value: String, manifest_id_value: String) -> void:
	world_id = world_id_value
	generator_manifest_id = manifest_id_value
	for record in records.values():
		record.generation += 1
		record.runtime_handle = null
		record.collision_handle = null
		record.readiness = {"definition": false, "fragment_plan": false, "voxel_geometry": false, "render": false, "collision": false, "simulation": false}
		record.queued.clear()
		record.state = "requested" if not record.demands.is_empty() else "dormant"
		_queue_if_needed(record)


func observer_cell(position: Vector3) -> Vector3i:
	return Vector3i(floori(position.x / cell_size.x), floori(position.y / cell_size.y), floori(position.z / cell_size.z))


func active_owner_count() -> int:
	var count := 0
	for record in records.values():
		if not record.demands.is_empty() or record.state != "dormant":
			count += 1
	return count


func _record(address):
	var key: String = address.canonical_text()
	if not records.has(key):
		records[key] = Record.new(address)
	return records[key]


func _invalidate_generation(record) -> void:
	record.generation += 1
	record.readiness = {"definition": false, "fragment_plan": false, "voxel_geometry": false, "render": false, "collision": false, "simulation": false}
	record.queued.clear()
	record.runtime_handle = null
	record.collision_handle = null
	record.release_pending = false
	record.state = "requested"


func _queue_if_needed(record) -> void:
	var tiers: Array = record.demanded_tiers()
	if tiers.is_empty():
		return
	var request := Request.new(record.cell_address, record.generation, tiers, record.source_fingerprint, record.provenance_fingerprint, world_id, generator_manifest_id)
	for tier in tiers:
		if record.readiness.get(tier, false) or record.queued.get(tier, false):
			continue
		record.queued[tier] = true
		queued_count += 1
		if executor != null and executor.has_method("submit"):
			executor.submit(request, tier)


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
