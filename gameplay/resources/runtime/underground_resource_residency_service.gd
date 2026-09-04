extends RefCounted
class_name UndergroundResourceResidencyService

const CaveRuntimeController := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const CellAddress := preload("res://worldgen/geometry/geometry_cell_address.gd")
const LifecycleRelay := preload("res://worldgen/runtime/underworld_runtime_cell_lifecycle_relay.gd")
const CellObserver := preload("res://gameplay/resources/runtime/underworld_resource_cell_observer.gd")
const CompositionService := preload("res://gameplay/resources/runtime/underground_resource_composition_service.gd")
const ContentEvidence := preload("res://gameplay/resources/runtime/underground_resource_content_evidence.gd")

signal semantic_cell_prepared(cell_address: String)
signal semantic_cell_retired(cell_address: String)
signal collision_readiness_changed(cell_address: String, ready: bool)

var _controller = null
var _content_authority: Dictionary = {}
var _lifecycle_relay = null
var _entries_by_cell: Dictionary = {}


## Bounded semantic residency only. This service never realizes Nodes, owns cave
## demand/readiness, mutates WorldDelta, or decides active domain authority.
func configure(controller, content_authority: Dictionary) -> Array[String]:
	dispose()
	var failures: Array[String] = []
	if controller == null or not controller is CaveRuntimeController:
		failures.append("resource residency requires UnderworldCaveRuntimeController")
	for failure in ContentEvidence.verification_failures(content_authority):
		failures.append("content authority: %s" % failure)
	if not failures.is_empty():
		failures.sort()
		return failures

	_controller = controller
	_content_authority = content_authority
	var attached_callback := Callable(self, "_on_cell_attached")
	if not _controller.is_connected("cell_attached", attached_callback):
		_controller.connect("cell_attached", attached_callback)

	_lifecycle_relay = LifecycleRelay.new()
	for failure in _lifecycle_relay.configure(_controller):
		failures.append(str(failure))
	if not failures.is_empty():
		dispose()
		failures.sort()
		return failures
	var retired_callback := Callable(self, "_on_tier_retired")
	if not _lifecycle_relay.is_connected("tier_retired", retired_callback):
		_lifecycle_relay.connect("tier_retired", retired_callback)

	# Late binding must reconstruct only currently relevant render-ready owner
	# cells; there is no historical placement scan.
	for snapshot in CellObserver.current_snapshots(_controller):
		var coordinate_variant = snapshot.get("cell_coordinate", null)
		if not coordinate_variant is Vector3i:
			continue
		var address = CellAddress.new(coordinate_variant)
		var prepared: Dictionary = prepare_current_cell(address)
		if not bool(prepared.get("success", false)):
			failures.append_array(_prefixed_diagnostics(
				"initial semantic residency",
				prepared.get("diagnostics", [])
			))
	if not failures.is_empty():
		dispose()
	failures.sort()
	return failures


func dispose() -> void:
	if _controller != null and is_instance_valid(_controller):
		var attached_callback := Callable(self, "_on_cell_attached")
		if _controller.is_connected("cell_attached", attached_callback):
			_controller.disconnect("cell_attached", attached_callback)
	if _lifecycle_relay != null:
		var retired_callback := Callable(self, "_on_tier_retired")
		if _lifecycle_relay.is_connected("tier_retired", retired_callback):
			_lifecycle_relay.disconnect("tier_retired", retired_callback)
		_lifecycle_relay.dispose()
	_lifecycle_relay = null
	_controller = null
	_content_authority.clear()
	_entries_by_cell.clear()


func prepare_current_cell(address) -> Dictionary:
	if _controller == null or address == null or not address is CellAddress:
		return _failure(["resource residency requires configured controller and CellAddress"])
	var composition: Dictionary = CompositionService.plan_current_cell(
		_controller,
		address,
		_content_authority
	)
	if not bool(composition.get("success", false)):
		return composition
	var snapshot_variant = composition.get("snapshot", null)
	if not snapshot_variant is Dictionary:
		return _failure(["resource composition did not return detached current snapshot"])
	var snapshot: Dictionary = snapshot_variant
	var key: String = str(snapshot.get("cell_address", ""))
	if key.is_empty():
		return _failure(["resource residency snapshot is missing cell_address"])

	var entry: Dictionary = {
		"cell_address": key,
		"cell_coordinate": snapshot.get("cell_coordinate"),
		"generation": int(snapshot.get("generation", -1)),
		"source_fingerprint": str(snapshot.get("source_fingerprint", "")),
		"provenance_fingerprint": str(snapshot.get("provenance_fingerprint", "")),
		"snapshot": snapshot.duplicate(true),
		"hooks": composition.get("hooks", []).duplicate(true),
		"placements": composition.get("placements", []).duplicate(),
		"collision_ready": CellObserver.collision_is_current(_controller, snapshot),
	}
	var previous_variant = _entries_by_cell.get(key, null)
	var previous_collision_ready: bool = false
	if previous_variant is Dictionary:
		previous_collision_ready = bool(previous_variant.get("collision_ready", false))
	_entries_by_cell[key] = entry
	semantic_cell_prepared.emit(key)
	if previous_variant == null or previous_collision_ready != bool(entry["collision_ready"]):
		collision_readiness_changed.emit(key, bool(entry["collision_ready"]))
	return {
		"success": true,
		"entry": _entry_copy(entry),
		"diagnostics": [],
	}


func semantic_entry(cell_address: String) -> Dictionary:
	var entry_variant = _entries_by_cell.get(cell_address, null)
	if not entry_variant is Dictionary:
		return {}
	var entry: Dictionary = entry_variant
	if CellObserver.snapshot_is_current(_controller, entry.get("snapshot", {})):
		return _entry_copy(entry)

	# A partial-tier retirement advances #372's cell generation token even when
	# render remains relevant. Refresh from current render truth on demand rather
	# than keeping stale generation authority or scanning historical placements.
	var coordinate_variant = entry.get("cell_coordinate", null)
	if coordinate_variant is Vector3i:
		var refreshed: Dictionary = prepare_current_cell(CellAddress.new(coordinate_variant))
		if bool(refreshed.get("success", false)):
			return refreshed.get("entry", {}).duplicate(true)
	_entries_by_cell.erase(cell_address)
	return {}


func semantic_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_key in _entries_by_cell.keys().duplicate():
		var key: String = str(raw_key)
		var entry: Dictionary = semantic_entry(key)
		if not entry.is_empty():
			result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("cell_address", "")) < str(b.get("cell_address", ""))
	)
	return result


func semantic_cell_count() -> int:
	return semantic_entries().size()


func _on_cell_attached(address, tier: String) -> void:
	if tier == "render":
		prepare_current_cell(address)
		return
	if tier != "collision" or address == null or not address is CellAddress:
		return
	var key: String = address.canonical_text()
	var entry_variant = _entries_by_cell.get(key, null)
	if not entry_variant is Dictionary:
		# A service may bind after render but before collision. Preparing here keeps
		# collision attach sufficient to complete semantic readiness without Player
		# movement or another observer tick.
		prepare_current_cell(address)
		return

	var entry: Dictionary = entry_variant
	if not CellObserver.snapshot_is_current(_controller, entry.get("snapshot", {})):
		# Partial-tier retirement advances the cell-scoped generation. A later
		# collision attach must refresh that old semantic snapshot immediately;
		# otherwise reacquisition would remain falsely unready until some unrelated
		# semantic_entry() caller happened to poll it.
		prepare_current_cell(address)
		return

	var ready: bool = CellObserver.collision_is_current(_controller, entry.get("snapshot", {}))
	if bool(entry.get("collision_ready", false)) == ready:
		return
	entry["collision_ready"] = ready
	_entries_by_cell[key] = entry
	collision_readiness_changed.emit(key, ready)


func _on_tier_retired(address, tier: String) -> void:
	if address == null or not address.has_method("canonical_text"):
		return
	var key: String = address.canonical_text()
	if not _entries_by_cell.has(key):
		return
	if tier == "collision":
		var entry_variant = _entries_by_cell.get(key, null)
		if entry_variant is Dictionary:
			var entry: Dictionary = entry_variant
			if bool(entry.get("collision_ready", false)):
				entry["collision_ready"] = false
				_entries_by_cell[key] = entry
				collision_readiness_changed.emit(key, false)
		return
	if tier == "render":
		_entries_by_cell.erase(key)
		semantic_cell_retired.emit(key)


static func _entry_copy(entry: Dictionary) -> Dictionary:
	var copy: Dictionary = entry.duplicate(true)
	# Placement records are immutable semantic value objects by contract; retain
	# their references rather than fabricating a second placement representation.
	copy["placements"] = entry.get("placements", []).duplicate()
	return copy


static func _prefixed_diagnostics(prefix: String, diagnostics: Array) -> Array[String]:
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
		"entry": {},
		"diagnostics": diagnostics,
	}
