extends RefCounted
class_name UndergroundResourceRuntimeComposition

const CaveRuntimeController := preload("res://worldgen/runtime/underworld_cave_runtime_controller.gd")
const ResidencyService := preload("res://gameplay/resources/runtime/underground_resource_residency_service.gd")
const ActionService := preload("res://gameplay/resources/runtime/underground_resource_action_service.gd")
const RealizationService := preload("res://gameplay/resources/runtime/underground_resource_realization_service.gd")
const HarvestSink := preload("res://gameplay/resources/runtime/underground_resource_harvest_sink.gd")
const ContentEvidence := preload("res://gameplay/resources/runtime/underground_resource_content_evidence.gd")
const WorldDeltaStore := preload("res://worldgen/persistence/world_delta_store.gd")

var _residency = null
var _action_service = null
var _realization = null
var _harvest_sink = null
var _configured: bool = false
var _activation_enabled: bool = false


## Domain-internal composition only. This object owns the dependency/lifetime
## order between #374 services, but it has deliberately zero authority to decide
## which world domain is committed. Final Game/#404 composition supplies that
## decision by calling set_activation_enabled() and choosing whether the Player
## harvest signal routes to harvest_sink().
func configure(
	controller,
	realization_parent,
	query_owner,
	content_authority: Dictionary,
	delta_store,
	archetype_realizer,
	self_exclusion = null
) -> Array[String]:
	dispose()
	var failures: Array[String] = []
	if controller == null or not controller is CaveRuntimeController:
		failures.append("resource runtime composition requires UnderworldCaveRuntimeController")
	if realization_parent == null or not realization_parent is Node3D:
		failures.append("resource runtime composition requires Node3D realization parent")
	if query_owner == null or not query_owner is Node3D:
		failures.append("resource runtime composition requires Node3D physics query owner")
	for failure in ContentEvidence.verification_failures(content_authority):
		failures.append("content authority: %s" % failure)
	if delta_store == null or not delta_store is WorldDeltaStore:
		failures.append("resource runtime composition requires WorldDeltaStore")
	if archetype_realizer == null or not archetype_realizer.has_method("realize"):
		failures.append("resource runtime composition requires ArchetypeRealizer-compatible service")
	if self_exclusion != null and not self_exclusion is CollisionObject3D:
		failures.append("resource runtime composition self exclusion must be CollisionObject3D")
	if not failures.is_empty():
		failures.sort()
		return failures

	var residency = ResidencyService.new()
	var residency_failures: Array[String] = residency.configure(controller, content_authority)
	for failure in residency_failures:
		failures.append("residency: %s" % failure)
	if not failures.is_empty():
		residency.dispose()
		failures.sort()
		return failures

	var action_service = ActionService.new()
	var action_failures: Array[String] = action_service.configure(residency)
	for failure in action_failures:
		failures.append("action: %s" % failure)
	if not failures.is_empty():
		residency.dispose()
		failures.sort()
		return failures

	var realization = RealizationService.new()
	var realization_failures: Array[String] = realization.configure(
		realization_parent,
		residency,
		content_authority,
		delta_store,
		archetype_realizer,
		action_service
	)
	for failure in realization_failures:
		failures.append("realization: %s" % failure)
	if not failures.is_empty():
		realization.dispose()
		residency.dispose()
		failures.sort()
		return failures

	var harvest_sink = HarvestSink.new()
	var harvest_failures: Array[String] = harvest_sink.configure(
		query_owner,
		residency,
		action_service,
		content_authority.get("content_registry", null),
		delta_store,
		self_exclusion
	)
	for failure in harvest_failures:
		failures.append("harvest sink: %s" % failure)
	if not failures.is_empty():
		harvest_sink.dispose()
		realization.dispose()
		residency.dispose()
		failures.sort()
		return failures

	_residency = residency
	_action_service = action_service
	_realization = realization
	_harvest_sink = harvest_sink
	_configured = true
	_activation_enabled = false
	return []


## Enabling exposes collision-ready realizations before the harvest sink accepts
## a Player ray. Disabling does the inverse: action ingress closes first, then
## live resource Nodes retire. If sink activation ever fails, realization is
## rolled back immediately so there is no half-active gameplay state.
func set_activation_enabled(enabled: bool) -> Array[String]:
	if not _configured:
		return ["resource runtime composition is not configured"]
	if _activation_enabled == enabled:
		return []
	var failures: Array[String] = []
	if enabled:
		var realization_failures: Array[String] = _realization.set_activation_enabled(true)
		for failure in realization_failures:
			failures.append("realization enable: %s" % failure)
		if not failures.is_empty():
			_realization.set_activation_enabled(false)
			failures.sort()
			return failures

		var harvest_failures: Array[String] = _harvest_sink.set_activation_enabled(true)
		for failure in harvest_failures:
			failures.append("harvest sink enable: %s" % failure)
		if not failures.is_empty():
			_harvest_sink.set_activation_enabled(false)
			_realization.set_activation_enabled(false)
			failures.sort()
			return failures
		_activation_enabled = true
		return []

	var harvest_disable_failures: Array[String] = _harvest_sink.set_activation_enabled(false)
	for failure in harvest_disable_failures:
		failures.append("harvest sink disable: %s" % failure)
	var realization_disable_failures: Array[String] = _realization.set_activation_enabled(false)
	for failure in realization_disable_failures:
		failures.append("realization disable: %s" % failure)
	_activation_enabled = false
	failures.sort()
	return failures


func dispose() -> void:
	# Close ingress before retiring interaction Nodes, then disconnect semantic
	# residency last so callbacks cannot retain a retired runtime graph.
	if _harvest_sink != null:
		_harvest_sink.set_activation_enabled(false)
		_harvest_sink.dispose()
	if _realization != null:
		_realization.set_activation_enabled(false)
		_realization.dispose()
	if _residency != null:
		_residency.dispose()
	_harvest_sink = null
	_realization = null
	_action_service = null
	_residency = null
	_activation_enabled = false
	_configured = false


func configured() -> bool:
	return _configured


func activation_enabled() -> bool:
	return _activation_enabled


func residency():
	return _residency


func action_service():
	return _action_service


func realization():
	return _realization


func harvest_sink():
	return _harvest_sink
